import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../services/feedback_service.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../utils/category_utils.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

/// Opens the editor for an existing expense.
Future<void> openExpenseEditor(BuildContext context, Expense expense) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExpenseFormScreen(existing: expense),
      ),
    );

/// Deletes [expense] and offers Undo, so nothing disappears silently.
Future<void> deleteWithUndo(BuildContext context, Expense expense) async {
  final repo = context.repo;
  final messenger = ScaffoldMessenger.of(context);
  await repo.deleteExpense(expense.id);
  FeedbackService().lightTap();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Deleted "${expense.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.restoreExpense(expense),
        ),
      ),
    );
}

class ExpenseFormScreen extends StatefulWidget {
  final Expense? existing;
  final bool startWithScan;

  const ExpenseFormScreen({super.key, this.existing, this.startWithScan = false});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _place;
  final _amountFocus = FocusNode();

  late DateTime _date;
  late String _category;
  late String _method;
  Uint8List? _receiptBytes;
  String? _existingImageUrl;

  List<String> _categories = List.of(kDefaultCategories);
  List<String> _places = [];
  StreamSubscription<List<String>>? _categorySub;
  bool _saving = false;
  bool _scanning = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _title = TextEditingController(text: e?.title ?? '');
    _place = TextEditingController(text: e?.place ?? '');
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? kDefaultCategories.first;
    _method = e?.paymentMethod ?? kPaymentMethods.first;
    _existingImageUrl = e?.imageUrl;
    if (widget.startWithScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseScanSource());
    } else if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _amountFocus.requestFocus());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categorySub != null) return;
    final repo = context.repo;
    _categorySub = repo.watchCategories().listen((list) {
      if (!mounted) return;
      setState(() {
        _categories = list;
        if (!_categories.contains(_category)) {
          // Keep an edited expense's old category selectable.
          if (_isEdit) {
            _categories = [..._categories, _category];
          } else {
            _category = _categories.first;
          }
        }
      });
    });
    repo.fetchPlaces().then((p) {
      if (mounted) setState(() => _places = p);
    });
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    _amount.dispose();
    _title.dispose();
    _place.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _chooseScanSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                GeminiService.isConfigured
                    ? 'Scan a receipt and the details fill in for you.'
                    : 'Attach a receipt photo. (Auto-fill needs the Gemini API key.)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) await _pickReceipt(source, scan: true);
  }

  Future<void> _pickReceipt(ImageSource source, {required bool scan}) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 60,
      );
    } catch (e) {
      if (mounted) showMessage(context, "Couldn't open the camera or gallery: $e", error: true);
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _receiptBytes = bytes);
    if (!scan || !GeminiService.isConfigured) return;

    setState(() => _scanning = true);
    try {
      final result = await GeminiService().analyzeReceipt(
        bytes,
        categories: _categories,
        mimeType: StorageService.detectContentType(bytes),
      );
      if (!mounted) return;
      if (result == null) {
        showMessage(context, "Couldn't read that receipt. Fill in the details yourself.");
        return;
      }
      setState(() {
        _title.text = result.title;
        if (result.amount != null) _amount.text = result.amount!.toStringAsFixed(2);
        if (result.place.isNotEmpty) _place.text = result.place;
        if (result.category != null) _category = result.category!;
        if (result.date != null) {
          final now = DateTime.now();
          _date = DateTime(result.date!.year, result.date!.month, result.date!.day, now.hour, now.minute);
        }
      });
      FeedbackService().success();
      showMessage(context, 'Receipt read. Check the details, then save.');
    } catch (e) {
      if (mounted) showMessage(context, 'Receipt scan failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
  }

  void _setDay(int daysAgo) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day - daysAgo, now.hour, now.minute);
    setState(() => _date = d);
  }

  bool _isDaysAgo(int n) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day - n);
    return _date.year == d.year && _date.month == d.month && _date.day == d.day;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.repo;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    var imageUrl = _existingImageUrl;
    var receiptDropped = false;
    if (_receiptBytes != null) {
      imageUrl = StorageService.toDataUrl(_receiptBytes!);
      receiptDropped = imageUrl == null;
    }
    final title = _title.text.trim().isEmpty ? _category : _title.text.trim();
    final expense = Expense(
      id: widget.existing?.id ?? '',
      title: title,
      amount: Money.parse(_amount.text)!,
      date: _date,
      place: _place.text.trim(),
      category: _category,
      paymentMethod: _method,
      imageUrl: imageUrl,
    );
    try {
      if (_isEdit) {
        await repo.updateExpense(expense);
      } else {
        await repo.addExpense(expense);
      }
      unawaited(repo.rememberPlace(expense.place));
      FeedbackService().success();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(receiptDropped
              ? 'Saved, but the receipt photo was too large to keep.'
              : _isEdit
              ? 'Changes saved'
              : 'Added ${Money.format(expense.amount)} · ${expense.category}'),
        ));
    } catch (e) {
      FeedbackService().error();
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, "Couldn't save: $e", error: true);
      }
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await deleteWithUndo(context, widget.existing!);
    navigator.pop();
  }

  void _viewReceipt() {
    final bytes = _receiptBytes ??
        (_existingImageUrl != null ? StorageService.decodeDataUrl(_existingImageUrl!) : null);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.contain)
                    : Image.network(
                        _existingImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(40),
                          child: Icon(Icons.broken_image_rounded, size: 48),
                        ),
                      ),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasReceipt = _receiptBytes != null || _existingImageUrl != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEdit ? 'Edit expense' : 'New expense'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_scanning) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text('Reading the receipt…', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _amount,
              focusNode: _amountFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              style: theme.textTheme.displaySmall,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: r'S$ ',
                prefixStyle: theme.textTheme.headlineSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              validator: (v) {
                final value = Money.parse(v ?? '');
                if (value == null) return 'Enter the amount, e.g. 12.50';
                if (value <= 0) return 'Amount must be more than zero';
                if (value > 1000000) return 'That looks too large';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'What was it?',
                hintText: 'e.g. Chicken rice (optional)',
                helperText: 'Left blank, the category name is used',
                helperStyle: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 14),
            _PlaceField(controller: _place, history: _places),
            _Label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    label: Text(c),
                    avatar: Icon(
                      CategoryUtils.iconFor(c),
                      size: 18,
                      color: _category == c ? null : CategoryUtils.colorFor(context, c),
                    ),
                    selected: _category == c,
                    showCheckmark: false,
                    onSelected: (_) {
                      FeedbackService().selectionClick();
                      setState(() => _category = c);
                    },
                  ),
              ],
            ),
            _Label('Paid with'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in kPaymentMethods)
                  ChoiceChip(
                    label: Text(m),
                    avatar: Icon(CategoryUtils.iconForMethod(m), size: 18),
                    selected: _method == m,
                    showCheckmark: false,
                    onSelected: (_) {
                      FeedbackService().selectionClick();
                      setState(() => _method = m);
                    },
                  ),
              ],
            ),
            _Label('Date'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _isDaysAgo(0),
                  showCheckmark: false,
                  onSelected: (_) => _setDay(0),
                ),
                ChoiceChip(
                  label: const Text('Yesterday'),
                  selected: _isDaysAgo(1),
                  showCheckmark: false,
                  onSelected: (_) => _setDay(1),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(
                    _isDaysAgo(0) || _isDaysAgo(1)
                        ? 'Pick a date'
                        : DateFormat('EEE, d MMM y').format(_date),
                  ),
                  onPressed: _pickDate,
                ),
              ],
            ),
            _Label('Receipt'),
            if (hasReceipt)
              Material(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  leading: Icon(Icons.receipt_rounded, color: scheme.primary),
                  title: const Text('Receipt attached'),
                  subtitle: const Text('Tap to view'),
                  onTap: _viewReceipt,
                  trailing: IconButton(
                    tooltip: 'Remove receipt',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _receiptBytes = null;
                      _existingImageUrl = null;
                    }),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : _chooseScanSource,
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Scan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : () => _pickReceipt(ImageSource.gallery, scan: false),
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Attach photo'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving || _scanning ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(_isEdit ? 'Save changes' : 'Save expense'),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _PlaceField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> history;

  const _PlaceField({required this.controller, required this.history});

  @override
  State<_PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<_PlaceField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.history;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return history.where((p) => p.toLowerCase().contains(q) && p.toLowerCase() != q).take(5);
      },
      fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextFormField(
        controller: ctrl,
        focusNode: focus,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Where?',
          hintText: 'Shop or hawker centre (optional)',
          prefixIcon: Icon(Icons.place_outlined),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 240,
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final o in options)
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(o),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
