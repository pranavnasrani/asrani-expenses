import 'dart:async';
import 'dart:math';

import '../models/budget.dart';
import '../models/expense.dart';
import 'expense_repository.dart';

/// In-memory repository with sample data. Used by debug demo mode
/// (`--dart-define=DEMO_MODE=true`) and by widget tests, so every screen can
/// be exercised without signing in or touching Firestore.
class DemoRepository implements ExpenseRepository {
  final Map<String, Expense> _expenses = {};
  List<String> _categories = List.of(kDefaultCategories);
  final List<String> _places = [];
  final Map<MonthKey, MonthBudgetDoc> _budgets = {};
  BudgetPrefs _prefs = const BudgetPrefs();
  final _changes = StreamController<void>.broadcast();
  var _nextId = 0;

  DemoRepository({bool seed = true, DateTime? now}) {
    if (seed) _seed(now ?? DateTime.now());
  }

  @override
  String? get displayName => 'Pranav Asrani';
  @override
  String? get email => 'demo@example.com';

  void _notify() => _changes.add(null);

  /// Emits the current value immediately, then again after every change.
  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  List<Expense> _query(DateTime? from, DateTime? to) {
    final list = _expenses.values.where((e) {
      if (from != null && e.date.isBefore(from)) return false;
      if (to != null && !e.date.isBefore(to)) return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Stream<List<Expense>> watchExpenses({DateTime? from, DateTime? to}) =>
      _watch(() => _query(from, to));

  @override
  Future<List<Expense>> fetchExpenses({DateTime? from, DateTime? to}) async =>
      _query(from, to);

  @override
  Future<String> addExpense(Expense expense) async {
    final id = 'demo-${_nextId++}';
    _expenses[id] = expense.copyWith(id: id);
    _notify();
    return id;
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    _expenses[expense.id] = expense;
    _notify();
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.remove(id);
    _notify();
  }

  @override
  Future<void> restoreExpense(Expense expense) async {
    _expenses[expense.id] = expense;
    _notify();
  }

  @override
  Stream<List<String>> watchCategories() => _watch(() => List.of(_categories));

  @override
  Future<void> saveCategories(List<String> categories) async {
    _categories = List.of(categories);
    _notify();
  }

  @override
  Future<List<String>> fetchPlaces() async => List.of(_places);

  @override
  Future<void> rememberPlace(String place) async {
    final trimmed = place.trim();
    if (trimmed.isEmpty) return;
    _places.removeWhere((p) => p.toLowerCase() == trimmed.toLowerCase());
    _places.insert(0, trimmed);
  }

  @override
  Stream<BudgetState> watchBudgetState() => _watch(
    () => BudgetState(docs: _budgets.values.toList(), prefs: _prefs),
  );

  @override
  Future<void> saveBudget(
    MonthKey month, {
    double? overall,
    double? cash,
    double? card,
    Map<String, double>? categories,
  }) async {
    final old = _budgets[month];
    _budgets[month] = MonthBudgetDoc(
      month: month,
      overall: overall ?? old?.overall,
      cash: cash ?? old?.cash,
      card: card ?? old?.card,
      categories: categories ?? old?.categories,
    );
    _notify();
  }

  @override
  Future<void> saveBudgetPrefs(BudgetPrefs prefs) async {
    _prefs = prefs;
    _notify();
  }

  @override
  Future<void> signOut() async {}

  void _seed(DateTime now) {
    final rng = Random(7);
    final thisMonth = MonthKey.of(now);
    final start = MonthKey.of(DateTime(now.year, now.month - 3, 1));

    _budgets[start] = MonthBudgetDoc(
      month: start,
      overall: 2200,
      cash: 600,
      card: 1600,
      categories: const {
        'Food': 650,
        'Groceries': 400,
        'Transport': 180,
        'Bills': 450,
        'Shopping': 250,
        'Entertainment': 120,
      },
    );
    _prefs = BudgetPrefs(
      rolloverEnabled: true,
      rolloverStart: start,
      view: BudgetView.method,
    );

    const templates = [
      ('Chicken rice', 'Food', 'Maxwell Food Centre', 'Cash', 5.5),
      ('Kopi & kaya toast', 'Food', 'Ya Kun, Tanjong Pagar', 'Cash', 6.2),
      ('Lunch with team', 'Food', 'Lau Pa Sat', 'PayNow', 18.0),
      ('Dinner', 'Food', 'Din Tai Fung, Raffles City', 'Credit Card', 64.8),
      ('Weekly groceries', 'Groceries', 'FairPrice Finest', 'Debit Card', 92.35),
      ('Fruit', 'Groceries', 'Tekka Market', 'Cash', 14.0),
      ('MRT top-up', 'Transport', 'EZ-Link', 'PayNow', 20.0),
      ('Grab to Changi', 'Transport', 'Grab', 'Credit Card', 28.4),
      ('Mobile plan', 'Bills', 'Singtel', 'Credit Card', 38.0),
      ('Electricity', 'Bills', 'SP Group', 'Debit Card', 112.6),
      ('Running shoes', 'Shopping', 'Decathlon', 'Credit Card', 89.0),
      ('Movie tickets', 'Entertainment', 'Golden Village', 'PayNow', 27.0),
      ('Pharmacy', 'Health', 'Guardian', 'Cash', 16.9),
    ];

    for (var m = start; m <= thisMonth; m = m.next) {
      final lastDay = m == thisMonth
          ? now.day
          : DateTime(m.year, m.month + 1, 0).day;
      // Fewer, smaller purchases in the second month so it leaves a surplus.
      final count = m == start.next ? 22 : 34;
      for (var i = 0; i < count; i++) {
        final t = templates[rng.nextInt(templates.length)];
        final day = 1 + rng.nextInt(lastDay);
        final jitter = 0.85 + rng.nextDouble() * 0.3;
        final id = 'seed-${_nextId++}';
        var date = DateTime(m.year, m.month, day, 8 + rng.nextInt(13), rng.nextInt(60));
        if (date.isAfter(now)) date = now;
        _expenses[id] = Expense(
          id: id,
          title: t.$1,
          category: t.$2,
          place: t.$3,
          paymentMethod: t.$4,
          amount: double.parse((t.$5 * jitter).toStringAsFixed(2)),
          date: date,
        );
      }
    }
    for (final t in templates) {
      if (!_places.contains(t.$3)) _places.add(t.$3);
    }
  }
}
