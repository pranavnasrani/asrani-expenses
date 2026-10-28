import '../models/budget.dart';
import '../models/expense.dart';

/// One month of history for a bucket, used to explain where carried money
/// came from.
class CarryStep {
  final MonthKey month;
  final double base;
  final double carriedIn;
  final double spent;

  /// Surplus handed to the next month. Never negative: overspending is
  /// forgiven at month end rather than carried as a deficit.
  final double carriedOut;

  const CarryStep({
    required this.month,
    required this.base,
    required this.carriedIn,
    required this.spent,
    required this.carriedOut,
  });
}

/// A single budget line: overall, cash, card, or one category.
class BucketResult {
  final String id;
  final String label;

  /// The recurring budget in force this month (0 when none is set).
  final double base;

  /// Compounded surplus carried into this month from earlier months.
  final double carriedIn;
  final double spent;

  /// Month-by-month carry history from the rollover start up to, but not
  /// including, the month being viewed.
  final List<CarryStep> history;

  const BucketResult({
    required this.id,
    required this.label,
    required this.base,
    required this.carriedIn,
    required this.spent,
    this.history = const [],
  });

  double get budget => base + carriedIn;
  double get remaining => budget - spent;
  bool get hasBudget => budget > 0;
  bool get isOver => hasBudget && spent > budget;

  /// Fraction of the budget spent, clamped to 0..1 for progress bars.
  double get progress => hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
}

class MonthBudgetSummary {
  final MonthKey month;
  final BudgetView view;
  final bool rolloverActive;
  final BucketResult overall;
  final BucketResult cash;
  final BucketResult card;
  final List<BucketResult> categories;

  const MonthBudgetSummary({
    required this.month,
    required this.view,
    required this.rolloverActive,
    required this.overall,
    required this.cash,
    required this.card,
    required this.categories,
  });

  double get totalSpent => overall.spent;

  /// The buckets the chosen [view] budgets against.
  List<BucketResult> get buckets => switch (view) {
    BudgetView.overall => [overall],
    BudgetView.method => [cash, card],
    BudgetView.category => categories,
  };

  List<BucketResult> get budgetedBuckets =>
      buckets.where((b) => b.hasBudget).toList();

  bool get hasAnyBudget => budgetedBuckets.isNotEmpty;

  /// Money left across every budgeted bucket in the current view, or null
  /// when nothing is budgeted. Negative when overspent overall.
  double? get leftToSpend {
    final budgeted = budgetedBuckets;
    if (budgeted.isEmpty) return null;
    return budgeted.fold<double>(0, (sum, b) => sum + b.remaining);
  }

  double get totalBudget =>
      budgetedBuckets.fold<double>(0, (sum, b) => sum + b.budget);

  double get totalCarriedIn =>
      budgetedBuckets.fold<double>(0, (sum, b) => sum + b.carriedIn);
}

/// Pure budgeting rules, kept free of Flutter and Firestore so they can be
/// unit tested.
///
/// Rules:
/// * Budgets recur: a month uses the most recent value saved at or before it,
///   field by field, until a later month changes it.
/// * Rollover compounds from [BudgetPrefs.rolloverStart]: each month's
///   surplus (budget including carried money, minus spending) carries into
///   the next month, and so on.
/// * Only surplus carries. An overspent month hands on nothing, and the
///   deficit is not taken out of the next month.
class BudgetCalculator {
  static const overallId = 'overall';
  static const cashId = 'cash';
  static const cardId = 'card';
  static String categoryId(String name) => 'cat:$name';

  /// The recurring budget amounts in force for [month].
  static ResolvedPlan resolvePlan(Iterable<MonthBudgetDoc> docs, MonthKey month) {
    final sorted = docs.where((d) => d.month <= month).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
    double? pick(double? Function(MonthBudgetDoc d) field) {
      for (final doc in sorted) {
        final value = field(doc);
        if (value != null) return value;
      }
      return null;
    }

    Map<String, double> categories = const {};
    for (final doc in sorted) {
      if (doc.categories != null) {
        categories = doc.categories!;
        break;
      }
    }
    return ResolvedPlan(
      overall: pick((d) => d.overall) ?? 0,
      cash: pick((d) => d.cash) ?? 0,
      card: pick((d) => d.card) ?? 0,
      categories: {
        for (final e in categories.entries)
          if (e.value > 0) e.key: e.value,
      },
    );
  }

  static MonthBudgetSummary compute({
    required MonthKey month,
    required Iterable<MonthBudgetDoc> docs,
    required Iterable<Expense> expenses,
    required BudgetPrefs prefs,
  }) {
    final docList = docs.toList();
    final spentByMonth = <MonthKey, _Spend>{};
    for (final e in expenses) {
      spentByMonth.putIfAbsent(MonthKey.of(e.date), _Spend.new).add(e);
    }

    final start = prefs.rolloverStart;
    final rolloverActive =
        prefs.rolloverEnabled && start != null && start < month;

    // Walk every month from the rollover start up to the viewed month,
    // carrying surplus forward per bucket.
    final carry = <String, double>{};
    final history = <String, List<CarryStep>>{};
    if (rolloverActive) {
      for (var m = start; m < month; m = m.next) {
        final plan = resolvePlan(docList, m);
        final spend = spentByMonth[m] ?? _Spend();
        final bucketIds = {
          overallId,
          cashId,
          cardId,
          for (final c in plan.categories.keys) categoryId(c),
          ...carry.keys,
        };
        for (final id in bucketIds) {
          final base = plan.baseFor(id);
          final carriedIn = carry[id] ?? 0;
          final spent = spend.forBucket(id);
          final budget = base + carriedIn;
          final carriedOut = budget > spent ? budget - spent : 0.0;
          history.putIfAbsent(id, () => []).add(CarryStep(
            month: m,
            base: base,
            carriedIn: carriedIn,
            spent: spent,
            carriedOut: carriedOut,
          ));
          carry[id] = carriedOut;
        }
      }
    }

    final plan = resolvePlan(docList, month);
    final spend = spentByMonth[month] ?? _Spend();

    BucketResult bucket(String id, String label) => BucketResult(
      id: id,
      label: label,
      base: plan.baseFor(id),
      carriedIn: carry[id] ?? 0,
      spent: spend.forBucket(id),
      history: history[id] ?? const [],
    );

    final categoryNames = <String>{
      ...plan.categories.keys,
      ...spend.byCategory.keys,
      for (final id in carry.keys)
        if (id.startsWith('cat:') && (carry[id] ?? 0) > 0) id.substring(4),
    }.toList();

    final categoryBuckets =
        categoryNames.map((c) => bucket(categoryId(c), c)).toList()
          ..sort((a, b) {
            // Budgeted categories first, then by spending.
            if (a.hasBudget != b.hasBudget) return a.hasBudget ? -1 : 1;
            return b.spent.compareTo(a.spent);
          });

    return MonthBudgetSummary(
      month: month,
      view: prefs.view,
      rolloverActive: rolloverActive,
      overall: bucket(overallId, 'Overall'),
      cash: bucket(cashId, 'Cash'),
      card: bucket(cardId, 'Card / Digital'),
      categories: categoryBuckets,
    );
  }
}

class ResolvedPlan {
  final double overall;
  final double cash;
  final double card;
  final Map<String, double> categories;

  const ResolvedPlan({
    required this.overall,
    required this.cash,
    required this.card,
    required this.categories,
  });

  double baseFor(String bucketId) {
    if (bucketId == BudgetCalculator.overallId) return overall;
    if (bucketId == BudgetCalculator.cashId) return cash;
    if (bucketId == BudgetCalculator.cardId) return card;
    return categories[bucketId.substring(4)] ?? 0;
  }
}

class _Spend {
  double total = 0;
  double cash = 0;
  double card = 0;
  final Map<String, double> byCategory = {};

  void add(Expense e) {
    total += e.amount;
    if (e.isCash) {
      cash += e.amount;
    } else {
      card += e.amount;
    }
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
  }

  double forBucket(String id) {
    if (id == BudgetCalculator.overallId) return total;
    if (id == BudgetCalculator.cashId) return cash;
    if (id == BudgetCalculator.cardId) return card;
    return byCategory[id.substring(4)] ?? 0;
  }
}
