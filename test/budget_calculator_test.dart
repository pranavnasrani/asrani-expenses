import 'package:asrani_expenses/logic/budget_calculator.dart';
import 'package:asrani_expenses/models/budget.dart';
import 'package:asrani_expenses/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';

const jan = MonthKey(2026, 1);
const feb = MonthKey(2026, 2);
const mar = MonthKey(2026, 3);
const apr = MonthKey(2026, 4);

var _id = 0;
Expense spend(
  double amount,
  MonthKey month, {
  int day = 10,
  String method = 'Cash',
  String category = 'Food',
}) => Expense(
  id: '${_id++}',
  title: 'x',
  amount: amount,
  date: DateTime(month.year, month.month, day),
  paymentMethod: method,
  category: category,
);

BudgetPrefs rollover(MonthKey start, {BudgetView view = BudgetView.overall}) =>
    BudgetPrefs(rolloverEnabled: true, rolloverStart: start, view: view);

MonthBudgetSummary run(
  MonthKey month, {
  List<MonthBudgetDoc> docs = const [],
  List<Expense> expenses = const [],
  BudgetPrefs prefs = const BudgetPrefs(view: BudgetView.overall),
}) => BudgetCalculator.compute(
  month: month,
  docs: docs,
  expenses: expenses,
  prefs: prefs,
);

void main() {
  group('recurring budgets', () {
    test('a budget set once applies to later months until changed', () {
      final docs = [
        const MonthBudgetDoc(month: jan, overall: 1000),
        const MonthBudgetDoc(month: mar, overall: 800),
      ];
      expect(run(jan, docs: docs).overall.base, 1000);
      expect(run(feb, docs: docs).overall.base, 1000);
      expect(run(mar, docs: docs).overall.base, 800);
      expect(run(apr, docs: docs).overall.base, 800);
    });

    test('months before the first budget have none', () {
      final docs = [const MonthBudgetDoc(month: feb, overall: 500)];
      expect(run(jan, docs: docs).overall.base, 0);
      expect(run(jan, docs: docs).leftToSpend, isNull);
    });

    test('fields resolve independently', () {
      final docs = [
        const MonthBudgetDoc(month: jan, cash: 200, card: 300),
        const MonthBudgetDoc(month: feb, cash: 250),
      ];
      final s = run(feb, docs: docs);
      expect(s.cash.base, 250);
      expect(s.card.base, 300);
    });

    test('category map is replaced as a whole and zero means no budget', () {
      final docs = [
        const MonthBudgetDoc(month: jan, categories: {'Food': 300, 'Bills': 100}),
        const MonthBudgetDoc(month: feb, categories: {'Food': 350, 'Bills': 0}),
      ];
      final plan = BudgetCalculator.resolvePlan(docs, feb);
      expect(plan.categories, {'Food': 350});
    });
  });

  group('spending', () {
    test('only counts the viewed month, including the 1st at midnight', () {
      final expenses = [
        Expense(id: 'a', title: 'a', amount: 10, date: DateTime(2026, 2, 1)),
        Expense(id: 'b', title: 'b', amount: 5, date: DateTime(2026, 1, 31, 23, 59)),
        Expense(id: 'c', title: 'c', amount: 7, date: DateTime(2026, 3, 1)),
      ];
      expect(run(feb, expenses: expenses).totalSpent, 10);
    });

    test('every non-cash method counts as Card / Digital', () {
      final expenses = [
        spend(10, jan, method: 'Cash'),
        spend(20, jan, method: 'Credit Card'),
        spend(30, jan, method: 'PayNow'),
        spend(40, jan, method: 'Other'),
      ];
      final s = run(jan, expenses: expenses);
      expect(s.cash.spent, 10);
      expect(s.card.spent, 90);
      expect(s.overall.spent, 100);
    });
  });

  group('rollover', () {
    final docs = [const MonthBudgetDoc(month: jan, overall: 1000)];

    test('off: no carry even with surplus', () {
      final s = run(feb, docs: docs, expenses: [spend(400, jan)]);
      expect(s.overall.carriedIn, 0);
      expect(s.overall.budget, 1000);
      expect(s.rolloverActive, isFalse);
    });

    test('surplus carries into the next month', () {
      final s = run(
        feb,
        docs: docs,
        expenses: [spend(400, jan), spend(100, feb)],
        prefs: rollover(jan),
      );
      expect(s.overall.carriedIn, 600);
      expect(s.overall.budget, 1600);
      expect(s.overall.remaining, 1500);
      expect(s.leftToSpend, 1500);
    });

    test('compounds across several months', () {
      // Jan: 1000 - 400 = 600 surplus.
      // Feb: 1000 + 600 - 900 = 700 surplus.
      // Mar: 1000 + 700 - 1000 = 700 surplus.
      final s = run(
        apr,
        docs: docs,
        expenses: [spend(400, jan), spend(900, feb), spend(1000, mar)],
        prefs: rollover(jan),
      );
      expect(s.overall.carriedIn, 700);
      expect(s.overall.history.map((h) => h.carriedOut), [600, 700, 700]);
    });

    test('overspending is forgiven: no deficit carries', () {
      // Jan: 1000 - 1500 overspent, carries 0.
      // Feb: 1000 - 200 = 800 surplus.
      final s = run(
        mar,
        docs: docs,
        expenses: [spend(1500, jan), spend(200, feb)],
        prefs: rollover(jan),
      );
      expect(s.overall.carriedIn, 800);
      final febOnly = run(
        feb,
        docs: docs,
        expenses: [spend(1500, jan)],
        prefs: rollover(jan),
      );
      expect(febOnly.overall.carriedIn, 0);
      expect(febOnly.overall.budget, 1000);
    });

    test('overspending eats into carried money but never below zero', () {
      // Jan: 1000 - 0 = 1000. Feb: 1000 + 1000 - 1800 = 200. Mar gets 200.
      final s = run(
        mar,
        docs: docs,
        expenses: [spend(1800, feb)],
        prefs: rollover(jan),
      );
      expect(s.overall.carriedIn, 200);
    });

    test('months before the rollover start never carry', () {
      final s = run(
        mar,
        docs: docs,
        expenses: [spend(100, jan), spend(300, feb)],
        prefs: rollover(feb),
      );
      expect(s.overall.carriedIn, 700); // Feb only: 1000 - 300.
    });

    test('the start month itself receives nothing', () {
      final s = run(jan, docs: docs, prefs: rollover(jan));
      expect(s.overall.carriedIn, 0);
      expect(s.rolloverActive, isFalse);
    });

    test('a start month after the viewed month has no effect', () {
      final s = run(feb, docs: docs, expenses: [spend(1, jan)], prefs: rollover(mar));
      expect(s.overall.carriedIn, 0);
    });

    test('months with no budget do not create negative carry', () {
      // Old bug: an unset previous month carried -spent.
      final docsFromFeb = [const MonthBudgetDoc(month: feb, overall: 500)];
      final s = run(
        feb,
        docs: docsFromFeb,
        expenses: [spend(300, jan)],
        prefs: rollover(jan),
      );
      expect(s.overall.carriedIn, 0);
      expect(s.overall.budget, 500);
    });

    test('carry follows a budget change', () {
      final changing = [
        const MonthBudgetDoc(month: jan, overall: 1000),
        const MonthBudgetDoc(month: feb, overall: 500),
      ];
      // Jan surplus 1000 - 200 = 800. Feb: 500 + 800 - 100 = 1200.
      final s = run(
        mar,
        docs: changing,
        expenses: [spend(200, jan), spend(100, feb)],
        prefs: rollover(jan),
      );
      expect(s.overall.base, 500);
      expect(s.overall.carriedIn, 1200);
    });

    test('cash and card carry separately', () {
      final methodDocs = [const MonthBudgetDoc(month: jan, cash: 300, card: 500)];
      final s = run(
        feb,
        docs: methodDocs,
        expenses: [
          spend(100, jan, method: 'Cash'),
          spend(600, jan, method: 'Debit Card'),
        ],
        prefs: rollover(jan, view: BudgetView.method),
      );
      expect(s.cash.carriedIn, 200);
      expect(s.card.carriedIn, 0); // Overspent, forgiven.
      expect(s.leftToSpend, (300 + 200) + 500);
    });

    test('category surplus carries per category', () {
      final catDocs = [
        const MonthBudgetDoc(month: jan, categories: {'Food': 300, 'Transport': 100}),
      ];
      final s = run(
        feb,
        docs: catDocs,
        expenses: [
          spend(120, jan, category: 'Food'),
          spend(100, jan, category: 'Transport'),
          spend(50, feb, category: 'Shopping'),
        ],
        prefs: rollover(jan, view: BudgetView.category),
      );
      final byName = {for (final b in s.categories) b.label: b};
      expect(byName['Food']!.carriedIn, 180);
      expect(byName['Food']!.budget, 480);
      expect(byName['Transport']!.carriedIn, 0);
      expect(byName['Shopping']!.hasBudget, isFalse);
      expect(byName['Shopping']!.spent, 50);
      // Unbudgeted categories are listed but not counted in left-to-spend.
      expect(s.leftToSpend, 480 + 100 - 0);
      expect(s.categories.first.hasBudget, isTrue);
    });

    test('a removed category budget keeps its carried surplus visible', () {
      final catDocs = [
        const MonthBudgetDoc(month: jan, categories: {'Food': 300}),
        const MonthBudgetDoc(month: feb, categories: {}),
      ];
      final s = run(
        feb,
        docs: catDocs,
        expenses: [spend(100, jan, category: 'Food')],
        prefs: rollover(jan, view: BudgetView.category),
      );
      final food = s.categories.singleWhere((b) => b.label == 'Food');
      expect(food.base, 0);
      expect(food.carriedIn, 200);
      expect(food.hasBudget, isTrue);
    });

    test('spans a year boundary', () {
      const nov = MonthKey(2025, 11);
      const dec = MonthKey(2025, 12);
      final yearDocs = [const MonthBudgetDoc(month: nov, overall: 100)];
      final s = run(
        jan,
        docs: yearDocs,
        expenses: [spend(50, nov), spend(20, dec)],
        prefs: rollover(nov),
      );
      // Nov: 100 - 50 = 50. Dec: 100 + 50 - 20 = 130.
      expect(s.overall.carriedIn, 130);
    });
  });

  group('prefs migration', () {
    test('uses the earliest month that had the legacy flag on', () {
      final prefs = BudgetPrefs.migrateFromLegacy([
        const MonthBudgetDoc(month: mar, legacyRollover: true),
        const MonthBudgetDoc(month: feb, legacyRollover: true),
        const MonthBudgetDoc(month: jan, legacyRollover: false),
      ]);
      expect(prefs.rolloverEnabled, isTrue);
      expect(prefs.rolloverStart, feb);
    });

    test('defaults to off', () {
      expect(BudgetPrefs.migrateFromLegacy([]).rolloverEnabled, isFalse);
    });
  });

  group('MonthKey', () {
    test('parses doc ids and rolls over years', () {
      expect(MonthKey.tryParse('budgets_2025_12'), const MonthKey(2025, 12));
      expect(MonthKey.tryParse('categories'), isNull);
      expect(const MonthKey(2025, 12).next, const MonthKey(2026, 1));
      expect(const MonthKey(2026, 1).previous, const MonthKey(2025, 12));
      expect(const MonthKey(2026, 3).docId, 'budgets_2026_03');
    });
  });
}
