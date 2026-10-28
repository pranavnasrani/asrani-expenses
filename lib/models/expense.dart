import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment methods offered when logging an expense.
const List<String> kPaymentMethods = [
  'Cash',
  'Credit Card',
  'Debit Card',
  'PayNow',
  'Other',
];

const List<String> kDefaultCategories = [
  'Food',
  'Groceries',
  'Transport',
  'Shopping',
  'Bills',
  'Entertainment',
  'Health',
  'Other',
];

/// Budgets split spending into "Cash" and "Card / Digital"; every non-cash
/// method (cards, PayNow, other) counts as Card / Digital.
bool isCashMethod(String? method) => (method ?? '').toLowerCase() == 'cash';

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String place;
  final String category;
  final String paymentMethod;
  final String? imageUrl;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.place = '',
    this.category = 'Other',
    this.paymentMethod = 'Cash',
    this.imageUrl,
  });

  bool get isCash => isCashMethod(paymentMethod);

  factory Expense.fromMap(String id, Map<String, dynamic> data) {
    return Expense(
      id: id,
      title: (data['title'] ?? '').toString().trim().isEmpty
          ? 'Untitled'
          : data['title'].toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: parseDate(data['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      place: (data['place'] ?? '').toString(),
      category: (data['category'] ?? 'Other').toString(),
      paymentMethod: (data['paymentMethod'] ?? 'Cash').toString(),
      imageUrl: (data['imageUrl'] as String?)?.isNotEmpty == true
          ? data['imageUrl'] as String
          : null,
    );
  }

  /// Firestore representation. `date` stays a [DateTime] so the Firestore
  /// SDK stores it as a Timestamp, which range queries rely on.
  Map<String, dynamic> toMap() => {
    'title': title,
    'amount': amount,
    'date': date,
    'place': place,
    'category': category,
    'paymentMethod': paymentMethod,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? place,
    String? category,
    String? paymentMethod,
    String? imageUrl,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      place: place ?? this.place,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Dates were historically stored both as Timestamps and ISO strings.
DateTime? parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
