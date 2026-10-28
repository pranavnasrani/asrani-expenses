import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/expense_repository.dart';
import '../logic/budget_calculator.dart';
import '../logic/budget_stream.dart';
import '../models/budget.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import '../widgets/tier.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  MonthKey _month = MonthKey.of(DateTime.now());
  Stream<BudgetSnapshot>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= watchBudget(context.repo, _month);
  }

  void _setMonth(MonthKey m) {
    setState(() {
      _month = m;
      _stream = watchBudget(context.repo, m);
    });
  }

  Future<void> _savePrefs(BudgetPrefs prefs) =>
      context.repo.saveBudgetPrefs(prefs);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: MonthSwitcher(month: _month, onChanged: _setMonth),
          ),
        ],
      ),
      body: StreamBuilder<BudgetSnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your budget",
              message: '${snap.error}',
            );
          }
          final data = snap.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final s = data.summary;
          final prefs = data.state.prefs;
          final current = MonthKey.of(DateTime.now());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
            children: [
              SegmentedButton<BudgetView>(
                segments: const [
                  ButtonSegment(value: BudgetView.overall, label: Text('Overall')),
                  ButtonSegment(value: BudgetView.method, label: Text('Cash / Card')),
                  ButtonSegment(value: BudgetView.category, label: Text('Category')),
                ],
                selected: {prefs.view},
                showSelectedIcon: false,
                onSelectionChanged: (v) {
                  FeedbackService().selectionClick();
                  _savePrefs(prefs.copyWith(view: v.first));
                },
              ),
              const SizedBox(height: 20),
              _SummaryRow(summary: s, isPast: _month < current),
              const SizedBox(height: 16),
              if (s.buckets.isEmpty)
                const EmptyState(
                  icon: Icons.category_rounded,
                  title: 'No category budgets yet',
                  message: 'Set an amount for the categories you want to watch.',
                ),
              for (final b in s.buckets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TierCard(
                    bucket: b,
                    color: bucketColor(context, b),
                    icon: bucketIcon(b),
                    onTap: () => _showHistory(context, b, prefs),
                  ),
                ),
              SavedTier(summary: s, prefs: prefs),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _editBudget(context, data),
                icon: const Icon(Icons.edit_rounded),
                label: Text('Edit ${prefs.view.label.toLowerCase()} budget'),
              ),
              const SizedBox(height: 4),
              Text(
                'Budgets repeat every month until you change them. Editing here applies from ${DateFormat('MMMM y').format(_month.start)} onwards.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SectionHeader(title: 'Rollover', padding: const EdgeInsets.fromLTRB(4, 28, 0, 8)),
              _RolloverCard(
                prefs: prefs,
                viewedMonth: _month,
                onChanged: _savePrefs,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHistory(BuildContext context, BucketResult b, BudgetPrefs prefs) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(b.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _kv(context, 'Monthly budget', Money.format(b.base)),
            _kv(context, 'Saved from earlier months', Money.format(b.carriedIn)),
            _kv(context, 'Available this month', Money.format(b.budget), bold: true),
            _kv(context, 'Spent', Money.format(b.spent)),
            _kv(context, b.remaining >= 0 ? 'Left' : 'Over', Money.format(b.remaining.abs()), bold: true),
            const SizedBox(height: 16),
            if (!prefs.rolloverEnabled)
              Text('Rollover is off, so nothing carries between months.', style: theme.textTheme.bodyMedium)
            else if (b.history.isEmpty)
              Text('No earlier months counted yet.', style: theme.textTheme.bodyMedium)
            else ...[
              Text('How the saved amount built up', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final h in b.history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(DateFormat('MMM').format(h.month.start), style: theme.textTheme.labelLarge),
                      ),
                      Expanded(
                        child: Text(
                          '${Money.whole(h.base + h.carriedIn)} available, ${Money.whole(h.spent)} spent',
                          style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: tabular),
                        ),
                      ),
                      Text(
                        h.carriedOut > 0 ? '→ ${Money.whole(h.carriedOut)}' : '→ S\$ 0',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: h.carriedOut > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          fontFeatures: tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Each month passes on what was left. Overspending passes on nothing, and is not taken from the next month.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool bold = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: theme.textTheme.bodyLarge)),
          Text(
            v,
            style: (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
                ?.copyWith(fontFeatures: tabular),
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, BudgetSnapshot data) async {
    final repo = context.repo;
    final view = data.state.prefs.view;
    final plan = BudgetCalculator.resolvePlan(data.state.docs, _month);
    final categories = view == BudgetView.category
        ? await repo.watchCategories().first
        : const <String>[];
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetEditor(
        month: _month,
        view: view,
        plan: plan,
        categories: {...categories, ...plan.categories.keys}.toList(),
        repo: repo,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final MonthBudgetSummary summary;
  final bool isPast;

  const _SummaryRow({required this.summary, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = summary.leftToSpend;
    final over = left != null && left < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPast)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Chip(
              avatar: const Icon(Icons.lock_clock_rounded, size: 18),
              label: Text(
                left == null
                    ? 'Closed month'
                    : over
                    ? 'Closed · ${Money.format(-left)} over'
                    : 'Closed · ${Money.format(left)} unspent',
              ),
            ),
          ),
        Text(
          left == null ? 'Spent' : over ? 'Over budget by' : 'Left to spend',
          style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Text(
          Money.format(left == null ? summary.totalSpent : left.abs()),
          style: theme.textTheme.displaySmall?.copyWith(
            color: over ? context.enamel.over : scheme.onSurface,
          ),
        ),
        if (left != null)
          Text(
            '${Money.format(summary.totalBudget)} available · ${Money.format(summary.totalSpent)} spent in total',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: tabular,
            ),
          ),
      ],
    );
  }
}

class _RolloverCard extends StatelessWidget {
  final BudgetPrefs prefs;
  final MonthKey viewedMonth;
  final ValueChanged<BudgetPrefs> onChanged;

  const _RolloverCard({
    required this.prefs,
    required this.viewedMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = prefs.rolloverStart;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: prefs.rolloverEnabled,
            title: const Text('Keep unspent money'),
            subtitle: const Text(
              'Whatever is left at month end adds to next month, and keeps adding up. Overspending is not carried.',
            ),
            onChanged: (on) {
              FeedbackService().selectionClick();
              onChanged(BudgetPrefs(
                rolloverEnabled: on,
                rolloverStart: on ? MonthKey.of(DateTime.now()) : start,
                view: prefs.view,
              ));
            },
          ),
          if (prefs.rolloverEnabled) ...[
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(Icons.event_repeat_rounded, color: theme.colorScheme.primary),
              title: const Text('Counting from'),
              subtitle: Text(start == null ? 'Not set' : DateFormat('MMMM y').format(start.start)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await _pickStart(context, start);
                if (picked != null) onChanged(prefs.copyWith(rolloverStart: picked));
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<MonthKey?> _pickStart(BuildContext context, MonthKey? current) {
    final now = MonthKey.of(DateTime.now());
    final months = <MonthKey>[];
    for (var m = now, i = 0; i < 24; m = m.previous, i++) {
      months.add(m);
    }
    return showModalBottomSheet<MonthKey>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Count unspent money from',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Months before this never carry anything forward.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            for (final m in months)
              ListTile(
                title: Text(DateFormat('MMMM y').format(m.start)),
                trailing: m == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetEditor extends StatefulWidget {
  final MonthKey month;
  final BudgetView view;
  final ResolvedPlan plan;
  final List<String> categories;
  final ExpenseRepository repo;

  const _BudgetEditor({
    required this.month,
    required this.view,
    required this.plan,
    required this.categories,
    required this.repo,
  });

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    String fmt(double v) => v > 0 ? v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2) : '';
    final p = widget.plan;
    switch (widget.view) {
      case BudgetView.overall:
        _fields['overall'] = TextEditingController(text: fmt(p.overall));
      case BudgetView.method:
        _fields['cash'] = TextEditingController(text: fmt(p.cash));
        _fields['card'] = TextEditingController(text: fmt(p.card));
      case BudgetView.category:
        for (final c in widget.categories) {
          _fields[c] = TextEditingController(text: fmt(p.categories[c] ?? 0));
        }
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _value(String key) => Money.parse(_fields[key]!.text) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = widget.repo;
    try {
      switch (widget.view) {
        case BudgetView.overall:
          await repo.saveBudget(widget.month, overall: _value('overall'));
        case BudgetView.method:
          await repo.saveBudget(widget.month, cash: _value('cash'), card: _value('card'));
        case BudgetView.category:
          await repo.saveBudget(widget.month, categories: {
            for (final c in widget.categories) c: _value(c),
          });
      }
      FeedbackService().success();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, "Couldn't save the budget: $e", error: true);
      }
    }
  }

  String _label(String key) => switch (key) {
    'overall' => 'Monthly budget',
    'cash' => 'Cash',
    'card' => 'Card / Digital (cards, PayNow, other)',
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _fields.keys.fold<double>(0, (s, k) => s + _value(k));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text('${widget.view.label} budget', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Applies from ${DateFormat('MMMM y').format(widget.month.start)} and every month after, until you change it. Leave blank for no budget.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final key in _fields.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _fields[key],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: _label(key), prefixText: r'S$ '),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = Money.parse(v);
                      if (n == null || n < 0) return 'Enter an amount, or leave blank';
                      return null;
                    },
                  ),
                ),
              if (_fields.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Total ${Money.format(total)} a month',
                    style: theme.textTheme.titleSmall?.copyWith(fontFeatures: tabular),
                  ),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
