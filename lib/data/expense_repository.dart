import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/budget.dart';
import '../models/expense.dart';

/// Budget documents and preferences, read together because both live in the
/// user's `settings` collection.
class BudgetState {
  final List<MonthBudgetDoc> docs;
  final BudgetPrefs prefs;

  const BudgetState({this.docs = const [], this.prefs = const BudgetPrefs()});
}

/// Everything the UI reads and writes. Screens never talk to Firestore
/// directly, so the whole app can also run against [DemoRepository].
abstract class ExpenseRepository {
  String? get displayName;
  String? get email;

  /// Expenses newest first. [from] is inclusive, [to] exclusive.
  Stream<List<Expense>> watchExpenses({DateTime? from, DateTime? to});
  Future<List<Expense>> fetchExpenses({DateTime? from, DateTime? to});

  Future<String> addExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String id);

  /// Re-creates a deleted expense with its original id (used by Undo).
  Future<void> restoreExpense(Expense expense);

  Stream<List<String>> watchCategories();
  Future<void> saveCategories(List<String> categories);

  Future<List<String>> fetchPlaces();
  Future<void> rememberPlace(String place);

  Stream<BudgetState> watchBudgetState();

  /// Saves the given budget fields for [month]; they apply from that month
  /// until a later month changes them. Fields left null are untouched.
  Future<void> saveBudget(
    MonthKey month, {
    double? overall,
    double? cash,
    double? card,
    Map<String, double>? categories,
  });
  Future<void> saveBudgetPrefs(BudgetPrefs prefs);

  Future<void> signOut();
}

/// Makes the repository available to every screen.
class RepositoryScope extends InheritedWidget {
  final ExpenseRepository repository;

  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  static ExpenseRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No RepositoryScope above this widget');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      oldWidget.repository != repository;
}

extension RepositoryContext on BuildContext {
  ExpenseRepository get repo => RepositoryScope.of(this);
}

/// Emits a pair whenever either source emits, once both have emitted.
Stream<(A, B)> combineLatest2<A, B>(Stream<A> a, Stream<B> b) {
  late StreamController<(A, B)> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? lastA;
  B? lastB;
  var hasA = false, hasB = false;

  void emit() {
    if (hasA && hasB) controller.add((lastA as A, lastB as B));
  }

  controller = StreamController<(A, B)>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
