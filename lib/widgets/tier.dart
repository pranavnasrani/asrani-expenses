import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/budget_calculator.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../utils/category_utils.dart';
import '../utils/money.dart';

/// The enamel colour for a budget line.
Color bucketColor(BuildContext context, BucketResult b) {
  final e = context.enamel;
  if (b.id == BudgetCalculator.overallId) return e.ochre;
  if (b.id == BudgetCalculator.cashId) return e.cash;
  if (b.id == BudgetCalculator.cardId) return e.card;
  return CategoryUtils.colorFor(context, b.label);
}

IconData bucketIcon(BucketResult b) {
  if (b.id == BudgetCalculator.overallId) return Icons.account_balance_wallet_rounded;
  if (b.id == BudgetCalculator.cashId) return Icons.payments_rounded;
  if (b.id == BudgetCalculator.cardId) return Icons.credit_card_rounded;
  return CategoryUtils.iconFor(b.label);
}

/// One budget as a tier of the tingkat: a rounded enamel band with a painted
/// rim, filling as money is spent.
class TierCard extends StatelessWidget {
  final BucketResult bucket;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  const TierCard({
    super.key,
    required this.bucket,
    required this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enamel = context.enamel;
    final b = bucket;
    final over = b.isOver;

    final String status;
    if (!b.hasBudget) {
      status = 'No budget set';
    } else if (over) {
      status = '${Money.format(-b.remaining)} over';
    } else {
      status = '${Money.format(b.remaining)} left';
    }

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: color),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          b.label,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          status,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: over
                                ? enamel.over
                                : b.hasBudget
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FillBar(
                    value: b.hasBudget ? b.progress : 0,
                    color: over ? enamel.over : color,
                    track: enamel.track,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text(
                        b.hasBudget
                            ? '${Money.format(b.spent)} spent of ${Money.format(b.budget)}'
                            : '${Money.format(b.spent)} spent',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: tabular,
                        ),
                      ),
                      if (b.carriedIn > 0.005)
                        Text(
                          'incl. ${Money.format(b.carriedIn)} saved',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontFeatures: tabular,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color track;

  const _FillBar({required this.value, required this.color, required this.track});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      value: '${(value * 100).round()}% spent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: ColoredBox(
            color: track,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 520),
              curve: Curves.easeOutQuart,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Net carry added by each month, summed across [buckets].
List<(MonthKey, double)> carryByMonth(List<BucketResult> buckets) {
  final totals = <MonthKey, double>{};
  for (final b in buckets) {
    for (final step in b.history) {
      totals[step.month] =
          (totals[step.month] ?? 0) + (step.carriedOut - step.carriedIn);
    }
  }
  final list = totals.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));
  return list;
}

/// The jade base tier holding compounded surplus from earlier months.
class SavedTier extends StatelessWidget {
  final MonthBudgetSummary summary;
  final BudgetPrefs prefs;
  final VoidCallback? onTap;

  const SavedTier({
    super.key,
    required this.summary,
    required this.prefs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enamel = context.enamel;
    final saved = summary.totalCarriedIn;
    final months = carryByMonth(summary.budgetedBuckets)
        .where((m) => m.$2.abs() > 0.005)
        .toList();
    final fmt = DateFormat('MMM');
    final start = prefs.rolloverStart;

    final String detail;
    if (!prefs.rolloverEnabled) {
      detail = 'Rollover is off. Turn it on to keep unspent money.';
    } else if (start != null && summary.month <= start) {
      detail =
          'Counting from ${DateFormat('MMMM').format(start.start)}. Unspent money moves here next month.';
    } else if (months.isEmpty) {
      detail = 'Nothing carried yet. Unspent money moves here next month.';
    } else {
      detail = months
          .map((m) => '${fmt.format(m.$1.start)} ${m.$2 >= 0 ? '+' : '−'}${Money.whole(m.$2.abs()).replaceFirst(r'S$ ', '')}')
          .join('  ·  ');
    }

    return Material(
      color: enamel.saved,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.savings_rounded, color: enamel.onSaved, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved tier',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: enamel.onSaved,
                      ),
                    ),
                  ),
                  Text(
                    prefs.rolloverEnabled ? '+ ${Money.format(saved)}' : 'Off',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: enamel.onSaved,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: enamel.onSaved.withValues(alpha: 0.86),
                  fontFeatures: tabular,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
