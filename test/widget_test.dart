import 'package:asrani_expenses/data/demo_repository.dart';
import 'package:asrani_expenses/logic/budget_calculator.dart';
import 'package:asrani_expenses/main.dart';
import 'package:asrani_expenses/models/budget.dart';
import 'package:asrani_expenses/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DemoRepository> pumpApp(WidgetTester tester, {bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({'onboarding_complete': onboarded});
  final prefs = await SharedPreferences.getInstance();
  final repo = DemoRepository();
  // Phone-sized surface.
  tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MyApp(settings: AppSettings(prefs), repositoryOverride: repo));
  await tester.pumpAndSettle();
  return repo;
}

Future<MonthBudgetSummary> currentSummary(DemoRepository repo) async {
  final state = await repo.watchBudgetState().first;
  final month = MonthKey.of(DateTime.now());
  return BudgetCalculator.compute(
    month: month,
    docs: state.docs,
    expenses: await repo.fetchExpenses(),
    prefs: state.prefs,
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('onboarding leads to the app', (tester) async {
    await pumpApp(tester, onboarded: false);
    expect(find.text('Log it in seconds'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Left to spend'), findsWidgets);
  });

  testWidgets('home shows left to spend including rolled-over savings', (tester) async {
    final repo = await pumpApp(tester);
    final s = await currentSummary(repo);
    expect(s.rolloverActive, isTrue);
    expect(find.text(Money.format(s.leftToSpend!)), findsOneWidget);
    expect(find.text('Saved tier'), findsOneWidget);
    expect(find.text('+ ${Money.format(s.totalCarriedIn)}'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Card / Digital'), findsOneWidget);
  });

  testWidgets('adding an expense lowers what is left', (tester) async {
    final repo = await pumpApp(tester);
    final before = (await currentSummary(repo)).leftToSpend!;

    await tester.tap(find.byTooltip('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '12.50');
    await tester.enterText(find.widgetWithText(TextFormField, 'What was it?'), 'Test laksa');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
    await tester.pump();
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final after = (await currentSummary(repo)).leftToSpend!;
    expect(before - after, closeTo(12.5, 0.001));
    expect(find.text(Money.format(after)), findsOneWidget);
    expect(find.text('Test laksa'), findsOneWidget);
  });

  testWidgets('amount is validated', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Add expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the amount, e.g. 12.50'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '0');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Amount must be more than zero'), findsOneWidget);
  });

  testWidgets('editing and deleting with undo', (tester) async {
    final repo = await pumpApp(tester);
    final newest = (await repo.fetchExpenses()).first;
    await tester.tap(find.text(newest.title).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '99.99');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect((await repo.fetchExpenses()).firstWhere((e) => e.id == newest.id).amount, 99.99);

    final count = (await repo.fetchExpenses()).length;
    // Let the "Changes saved" snackbar clear first.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(newest.title).first);
    await tester.tap(find.text(newest.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect((await repo.fetchExpenses()).length, count - 1);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await repo.fetchExpenses()).length, count);
  });

  testWidgets('budget: switch view, edit, and toggle rollover', (tester) async {
    final repo = await pumpApp(tester);
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Overall'));
    await tester.pumpAndSettle();
    expect((await repo.watchBudgetState().first).prefs.view, BudgetView.overall);

    await tester.tap(find.text('Edit overall budget'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monthly budget'), '3000');
    await tester.tap(find.text('Save budget'));
    await tester.pumpAndSettle();
    final s = await currentSummary(repo);
    expect(s.overall.base, 3000);
    // A later month inherits the edited budget.
    final state = await repo.watchBudgetState().first;
    final nextMonth = MonthKey.of(DateTime.now()).next;
    expect(BudgetCalculator.resolvePlan(state.docs, nextMonth).overall, 3000);

    await tester.scrollUntilVisible(find.text('Keep unspent money'), 200);
    await tester.tap(find.text('Keep unspent money'));
    await tester.pumpAndSettle();
    expect((await repo.watchBudgetState().first).prefs.rolloverEnabled, isFalse);
    expect((await currentSummary(repo)).totalCarriedIn, 0);
  });

  testWidgets('expenses: search, filter and empty result', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'laksa-that-does-not-exist');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsNothing);
  });

  testWidgets('every tab renders in dark mode', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'theme_mode': 'dark'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MyApp(settings: AppSettings(prefs), repositoryOverride: DemoRepository()));
    await tester.pumpAndSettle();
    for (final tab in ['Expenses', 'Budget', 'Insights', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
