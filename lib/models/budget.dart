/// A calendar month, used to key budget documents (`budgets_yyyy_MM`).
class MonthKey implements Comparable<MonthKey> {
  final int year;
  final int month;

  const MonthKey(this.year, this.month);

  factory MonthKey.of(DateTime date) => MonthKey(date.year, date.month);

  /// Parses `yyyy_MM` (also accepts a `budgets_` prefix). Returns null when
  /// the string is not a month key.
  static MonthKey? tryParse(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d{4})_(\d{2})$').firstMatch(raw);
    if (match == null) return null;
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) return null;
    return MonthKey(int.parse(match.group(1)!), month);
  }

  DateTime get start => DateTime(year, month, 1);

  /// Exclusive end: the first instant of the following month.
  DateTime get end => DateTime(year, month + 1, 1);

  MonthKey get next => MonthKey.of(DateTime(year, month + 1, 1));
  MonthKey get previous => MonthKey.of(DateTime(year, month - 1, 1));

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  String get id => '${year.toString().padLeft(4, '0')}_${month.toString().padLeft(2, '0')}';
  String get docId => 'budgets_$id';

  bool operator <(MonthKey other) => compareTo(other) < 0;
  bool operator <=(MonthKey other) => compareTo(other) <= 0;
  bool operator >(MonthKey other) => compareTo(other) > 0;

  @override
  int compareTo(MonthKey other) =>
      year != other.year ? year - other.year : month - other.month;

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => year * 100 + month;

  @override
  String toString() => id;
}

/// What a budget is split by. Stored as a string so older builds' values
/// ('overall', 'method', 'category') keep working.
enum BudgetView {
  overall('overall', 'Overall'),
  method('method', 'Cash vs Card'),
  category('category', 'By category');

  final String key;
  final String label;
  const BudgetView(this.key, this.label);

  static BudgetView fromKey(String? key) =>
      BudgetView.values.firstWhere((v) => v.key == key, orElse: () => method);
}

/// The budget amounts saved for one month. A null field means "not set in
/// this month", so the most recent earlier month's value applies.
class MonthBudgetDoc {
  final MonthKey month;
  final double? overall;
  final double? cash;
  final double? card;
  final Map<String, double>? categories;

  /// Legacy per-month rollover flag from earlier builds; only read to
  /// migrate into [BudgetPrefs].
  final bool? legacyRollover;

  const MonthBudgetDoc({
    required this.month,
    this.overall,
    this.cash,
    this.card,
    this.categories,
    this.legacyRollover,
  });

  factory MonthBudgetDoc.fromMap(MonthKey month, Map<String, dynamic> data) {
    Map<String, double>? categories;
    final rawCategories = data['categories'];
    if (rawCategories is Map) {
      categories = {
        for (final entry in rawCategories.entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toDouble(),
      };
    }
    return MonthBudgetDoc(
      month: month,
      overall: (data['overallLimit'] as num?)?.toDouble(),
      cash: (data['cash'] as num?)?.toDouble(),
      card: (data['card'] as num?)?.toDouble(),
      categories: categories,
      legacyRollover: data['enableRollover'] as bool?,
    );
  }
}

/// User-wide budget preferences (`settings/budgetPrefs`).
class BudgetPrefs {
  final bool rolloverEnabled;

  /// First month that can produce a surplus. Earlier months never carry.
  final MonthKey? rolloverStart;
  final BudgetView view;

  const BudgetPrefs({
    this.rolloverEnabled = false,
    this.rolloverStart,
    this.view = BudgetView.method,
  });

  factory BudgetPrefs.fromMap(Map<String, dynamic> data) => BudgetPrefs(
    rolloverEnabled: data['rolloverEnabled'] == true,
    rolloverStart: MonthKey.tryParse(data['rolloverStart'] as String?),
    view: BudgetView.fromKey(data['view'] as String?),
  );

  Map<String, dynamic> toMap() => {
    'rolloverEnabled': rolloverEnabled,
    'rolloverStart': rolloverStart?.id,
    'view': view.key,
  };

  /// Earlier builds stored `enableRollover` on each month's document. When
  /// no prefs document exists yet, treat rollover as on from the earliest
  /// month that had it switched on.
  static BudgetPrefs migrateFromLegacy(Iterable<MonthBudgetDoc> docs) {
    final enabledMonths =
        docs.where((d) => d.legacyRollover == true).map((d) => d.month).toList()
          ..sort();
    if (enabledMonths.isEmpty) return const BudgetPrefs();
    return BudgetPrefs(rolloverEnabled: true, rolloverStart: enabledMonths.first);
  }

  BudgetPrefs copyWith({
    bool? rolloverEnabled,
    MonthKey? rolloverStart,
    BudgetView? view,
  }) => BudgetPrefs(
    rolloverEnabled: rolloverEnabled ?? this.rolloverEnabled,
    rolloverStart: rolloverStart ?? this.rolloverStart,
    view: view ?? this.view,
  );
}
