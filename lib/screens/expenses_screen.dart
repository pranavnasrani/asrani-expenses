import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/expense_repository.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../services/export_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'expense_form_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  Stream<List<Expense>>? _stream;
  Stream<List<String>>? _categories;
  List<Expense> _visible = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= context.repo.watchExpenses();
    _categories ??= context.repo.watchCategories();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Expense e) {
    if (_category != null && e.category != _category) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return e.title.toLowerCase().contains(q) ||
        e.place.toLowerCase().contains(q) ||
        e.category.toLowerCase().contains(q) ||
        e.paymentMethod.toLowerCase().contains(q) ||
        e.amount.toStringAsFixed(2).contains(q);
  }

  String get _filterLabel {
    final parts = [
      if (_category != null) _category!,
      if (_query.isNotEmpty) '"$_query"',
    ];
    return parts.isEmpty ? 'All expenses' : parts.join(' ');
  }

  Future<void> _export(bool pdf) async {
    final list = _visible;
    try {
      if (pdf) {
        await ExportService().exportPdf(list, label: _filterLabel);
      } else {
        await ExportService().exportCsv(list, label: _filterLabel);
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Export failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('Export shown as CSV')),
              PopupMenuItem(value: true, child: Text('Export shown as PDF')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  controller: _search,
                  hintText: 'Search title, place, amount…',
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHigh),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              SizedBox(
                height: 48,
                child: StreamBuilder<List<String>>(
                  stream: _categories,
                  builder: (context, snap) {
                    final cats = snap.data ?? kDefaultCategories;
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final c in [null, ...cats])
                          Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 8),
                            child: ChoiceChip(
                              label: Text(c ?? 'All'),
                              selected: _category == c,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _category = c),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load expenses",
              message: '${snap.error}',
            );
          }
          if (!snap.hasData) return const ExpenseListSkeleton();
          final all = snap.data!;
          final list = all.where(_matches).toList();
          _visible = list;

          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No expenses yet',
              message: 'Everything you log appears here, newest first.',
            );
          }
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              message: 'Nothing matches $_filterLabel.',
              action: GeminiService.isConfigured && _query.isNotEmpty
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Ask the assistant'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(initialQuery: 'Find expenses related to "$_query"'),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {
                          _query = '';
                          _category = null;
                        });
                      },
                      child: const Text('Clear filters'),
                    ),
            );
          }

          final groups = <MonthKey, List<Expense>>{};
          for (final e in list) {
            groups.putIfAbsent(MonthKey.of(e.date), () => []).add(e);
          }
          return CustomScrollView(
            slivers: [
              for (final entry in groups.entries)
                SliverMainAxisGroup(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MonthHeader(entry.key, entry.value),
                    ),
                    SliverList.builder(
                      itemCount: entry.value.length,
                      itemBuilder: (context, i) {
                        final e = entry.value[i];
                        return Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: theme.colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Icon(Icons.delete_rounded, color: theme.colorScheme.onErrorContainer),
                          ),
                          onDismissed: (_) => deleteWithUndo(context, e),
                          child: ExpenseTile(expense: e, onTap: () => openExpenseEditor(context, e)),
                        );
                      },
                    ),
                  ],
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }
}

/// Sticky guide header naming the month in view and its total.
class _MonthHeader extends SliverPersistentHeaderDelegate {
  final MonthKey month;
  final List<Expense> expenses;

  _MonthHeader(this.month, this.expenses);

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final now = DateTime.now();
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Flexible(
            child: Text(
              DateFormat(month.year == now.year ? 'MMMM' : 'MMMM y').format(month.start),
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(Money.format(total), style: theme.textTheme.titleSmall?.copyWith(fontFeatures: tabular)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeader old) =>
      old.month != month || old.expenses != expenses;
}
