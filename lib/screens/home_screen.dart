import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/expense_repository.dart';
import '../logic/budget_calculator.dart';
import '../logic/budget_stream.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import '../widgets/tier.dart';
import 'expense_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final VoidCallback onSeeAllExpenses;
  final VoidCallback onOpenBudget;

  const HomeScreen({
    super.key,
    required this.onAdd,
    required this.onScan,
    required this.onSeeAllExpenses,
    required this.onOpenBudget,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<BudgetSnapshot>? _stream;
  MonthKey? _month;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final month = MonthKey.of(DateTime.now());
    if (_stream == null || month != _month) {
      _month = month;
      _stream = watchBudget(context.repo, month);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BudgetSnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load your budget",
            message: 'Check your connection and try again.\n${snap.error}',
          );
        }
        final data = snap.data;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Hero(data: data, onScan: widget.onScan, onSetBudget: widget.onOpenBudget)),
            if (data == null)
              const SliverToBoxAdapter(child: _TierSkeleton())
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList.list(
                  children: [
                    for (final b in _homeBuckets(data))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TierCard(
                          bucket: b,
                          color: bucketColor(context, b),
                          icon: bucketIcon(b),
                          onTap: widget.onOpenBudget,
                        ),
                      ),
                    if (!data.summary.hasAnyBudget)
                      _SetBudgetPrompt(onTap: widget.onOpenBudget),
                    SavedTier(
                      summary: data.summary,
                      prefs: data.state.prefs,
                      onTap: widget.onOpenBudget,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recent',
                  actionLabel: data.monthExpenses.isEmpty ? null : 'See all',
                  onAction: widget.onSeeAllExpenses,
                ),
              ),
              if (data.monthExpenses.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Nothing logged this month',
                    message: 'Tap Add after a purchase, or scan the receipt.',
                    action: OutlinedButton.icon(
                      onPressed: widget.onScan,
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Scan a receipt'),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: data.monthExpenses.length.clamp(0, 6),
                  itemBuilder: (context, i) {
                    final e = data.monthExpenses[i];
                    return ExpenseTile(
                      expense: e,
                      onTap: () => openExpenseEditor(context, e),
                    );
                  },
                ),
              // Clearance for the FAB.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        );
      },
    );
  }

  /// On Home, category view shows the four tiers with the most spending.
  List<BucketResult> _homeBuckets(BudgetSnapshot data) {
    final s = data.summary;
    if (s.view != BudgetView.category) return s.buckets;
    return s.budgetedBuckets.take(4).toList();
  }
}

class _Hero extends StatelessWidget {
  final BudgetSnapshot? data;
  final VoidCallback onScan;
  final VoidCallback onSetBudget;

  const _Hero({required this.data, required this.onScan, required this.onSetBudget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enamel = context.enamel;
    final repo = context.repo;
    final name = (repo.displayName ?? repo.email ?? '').split(RegExp(r'[ @]')).first;
    final summary = data?.summary;
    final left = summary?.leftToSpend;
    final monthName = DateFormat('MMMM').format(DateTime.now());

    String headline;
    String label;
    String? sub;
    if (summary == null) {
      label = 'Left to spend in $monthName';
      headline = ' ';
    } else if (left == null) {
      label = 'Spent in $monthName';
      headline = Money.format(summary.totalSpent);
      sub = 'Set a budget to see what is left';
    } else if (left < 0) {
      label = 'Over budget in $monthName';
      headline = Money.format(-left);
      sub = 'Budget ${Money.format(summary.totalBudget)} · spent ${Money.format(summary.budgetedBuckets.fold<double>(0, (s, b) => s + b.spent))}';
    } else {
      label = 'Left to spend in $monthName';
      headline = Money.format(left);
      final saved = summary.totalCarriedIn;
      sub = 'of ${Money.format(summary.totalBudget)}'
          '${saved > 0.005 ? ' · incl. ${Money.format(saved)} saved' : ''}';
    }

    return Container(
      color: enamel.field,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'Asrani Expenses' : 'Hi, $name',
                      style: theme.textTheme.titleLarge?.copyWith(color: enamel.onField),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Scan a receipt',
                    onPressed: onScan,
                    icon: Icon(Icons.document_scanner_rounded, color: enamel.onField),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    icon: Icon(Icons.settings_rounded, color: enamel.onField),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(color: enamel.onFieldMuted),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  headline,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: left != null && left < 0 ? const Color(0xFFFFD2CC) : enamel.onField,
                  ),
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    sub,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: enamel.onFieldMuted,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SetBudgetPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _SetBudgetPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.layers_rounded, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set a monthly budget. It repeats every month until you change it.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TierSkeleton extends StatelessWidget {
  const _TierSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          SkeletonBox(height: 92, radius: 16),
          SizedBox(height: 8),
          SkeletonBox(height: 92, radius: 16),
          SizedBox(height: 8),
          SkeletonBox(height: 72, radius: 16),
        ],
      ),
    );
  }
}
