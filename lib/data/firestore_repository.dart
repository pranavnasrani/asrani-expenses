import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/expense.dart';
import '../services/auth_service.dart';
import 'expense_repository.dart';

class FirestoreRepository implements ExpenseRepository {
  final User user;
  final FirebaseFirestore _db;

  FirestoreRepository(this.user, {FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance {
    _migrateStringDates();
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(user.uid);
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _userDoc.collection('expenses');
  CollectionReference<Map<String, dynamic>> get _settings =>
      _userDoc.collection('settings');

  @override
  String? get displayName => user.displayName;
  @override
  String? get email => user.email;

  Query<Map<String, dynamic>> _range(DateTime? from, DateTime? to) {
    Query<Map<String, dynamic>> q = _expenses;
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: from);
    if (to != null) q = q.where('date', isLessThan: to);
    return q.orderBy('date', descending: true);
  }

  List<Expense> _toExpenses(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => Expense.fromMap(d.id, d.data())).toList();

  @override
  Stream<List<Expense>> watchExpenses({DateTime? from, DateTime? to}) =>
      _range(from, to).snapshots().map(_toExpenses);

  @override
  Future<List<Expense>> fetchExpenses({DateTime? from, DateTime? to}) async =>
      _toExpenses(await _range(from, to).get());

  @override
  Future<String> addExpense(Expense expense) async =>
      (await _expenses.add(expense.toMap())).id;

  @override
  Future<void> updateExpense(Expense expense) {
    final data = expense.toMap();
    if (expense.imageUrl == null) data['imageUrl'] = FieldValue.delete();
    return _expenses.doc(expense.id).update(data);
  }

  @override
  Future<void> deleteExpense(String id) => _expenses.doc(id).delete();

  @override
  Future<void> restoreExpense(Expense expense) =>
      _expenses.doc(expense.id).set(expense.toMap());

  @override
  Stream<List<String>> watchCategories() =>
      _settings.doc('categories').snapshots().map((snap) {
        final list = snap.data()?['list'];
        if (list is List && list.isNotEmpty) {
          return list.map((e) => e.toString()).toList();
        }
        return List.of(kDefaultCategories);
      });

  @override
  Future<void> saveCategories(List<String> categories) =>
      _settings.doc('categories').set({'list': categories});

  @override
  Future<List<String>> fetchPlaces() async {
    final snap = await _settings.doc('locationHistory').get();
    final places = snap.data()?['places'];
    return places is List ? places.map((e) => e.toString()).toList() : [];
  }

  @override
  Future<void> rememberPlace(String place) async {
    final trimmed = place.trim();
    if (trimmed.isEmpty) return;
    final places = await fetchPlaces();
    places.removeWhere((p) => p.toLowerCase() == trimmed.toLowerCase());
    places.insert(0, trimmed);
    await _settings.doc('locationHistory').set({
      'places': places.take(30).toList(),
    });
  }

  @override
  Stream<BudgetState> watchBudgetState() => _settings.snapshots().map((snap) {
    final docs = <MonthBudgetDoc>[];
    Map<String, dynamic>? prefsData;
    for (final doc in snap.docs) {
      if (doc.id == 'budgetPrefs') {
        prefsData = doc.data();
        continue;
      }
      if (!doc.id.startsWith('budgets_')) continue;
      final month = MonthKey.tryParse(doc.id);
      if (month != null) docs.add(MonthBudgetDoc.fromMap(month, doc.data()));
    }
    final prefs = prefsData != null
        ? BudgetPrefs.fromMap(prefsData)
        : BudgetPrefs.migrateFromLegacy(docs);
    return BudgetState(docs: docs, prefs: prefs);
  });

  @override
  Future<void> saveBudget(
    MonthKey month, {
    double? overall,
    double? cash,
    double? card,
    Map<String, double>? categories,
  }) {
    final data = <String, dynamic>{
      'overallLimit': ?overall,
      'cash': ?cash,
      'card': ?card,
      'categories': ?categories,
    };
    if (data.isEmpty) return Future.value();
    // mergeFields replaces each written field whole, so a category removed
    // from the map is really removed instead of deep-merged back in.
    return _settings
        .doc(month.docId)
        .set(data, SetOptions(mergeFields: data.keys.toList()));
  }

  @override
  Future<void> saveBudgetPrefs(BudgetPrefs prefs) =>
      _settings.doc('budgetPrefs').set(prefs.toMap());

  @override
  Future<void> signOut() => AuthService().signOut();

  /// Early builds stored `date` as an ISO string, which Timestamp range
  /// queries never match. Firestore orders values by type, so a string range
  /// finds exactly those documents; rewrite them as Timestamps once.
  Future<void> _migrateStringDates() async {
    try {
      final snap = await _expenses
          .where('date', isGreaterThanOrEqualTo: '')
          .where('date', isLessThan: '')
          .get();
      for (final doc in snap.docs) {
        final parsed = parseDate(doc.data()['date']);
        if (parsed != null) await doc.reference.update({'date': parsed});
      }
      if (snap.docs.isNotEmpty) {
        debugPrint('Migrated ${snap.docs.length} string dates to Timestamps');
      }
    } catch (e) {
      debugPrint('String date migration skipped: $e');
    }
  }
}
