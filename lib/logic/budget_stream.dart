import 'dart:async';

import '../data/expense_repository.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import 'budget_calculator.dart';

class BudgetSnapshot {
  final MonthBudgetSummary summary;
  final BudgetState state;

  /// Expenses in the viewed month only, newest first.
  final List<Expense> monthExpenses;

  const BudgetSnapshot({
    required this.summary,
    required this.state,
    required this.monthExpenses,
  });
}

/// Live budget summary for [month]. Expenses are loaded from the rollover
/// start (when rollover is on) so surplus can compound, and the expense
/// query is only re-issued when that start changes.
Stream<BudgetSnapshot> watchBudget(ExpenseRepository repo, MonthKey month) {
  late StreamController<BudgetSnapshot> controller;
  StreamSubscription<BudgetState>? budgetSub;
  StreamSubscription<List<Expense>>? expenseSub;
  DateTime? loadedFrom;
  BudgetState? state;
  List<Expense>? expenses;

  void emit() {
    final s = state, e = expenses;
    if (s == null || e == null) return;
    controller.add(BudgetSnapshot(
      state: s,
      summary: BudgetCalculator.compute(
        month: month,
        docs: s.docs,
        expenses: e,
        prefs: s.prefs,
      ),
      monthExpenses: e.where((x) => month.contains(x.date)).toList(),
    ));
  }

  controller = StreamController<BudgetSnapshot>(
    onListen: () {
      budgetSub = repo.watchBudgetState().listen((s) {
        state = s;
        final start = s.prefs.rolloverStart;
        final from = s.prefs.rolloverEnabled && start != null && start < month
            ? start.start
            : month.start;
        if (from != loadedFrom) {
          loadedFrom = from;
          expenses = null;
          expenseSub?.cancel();
          expenseSub = repo
              .watchExpenses(from: from, to: month.end)
              .listen((e) {
                expenses = e;
                emit();
              }, onError: controller.addError);
        } else {
          emit();
        }
      }, onError: controller.addError);
    },
    onCancel: () async {
      await budgetSub?.cancel();
      await expenseSub?.cancel();
    },
  );
  return controller.stream;
}
