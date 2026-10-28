import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/expense.dart';
import '../utils/money.dart';

class ReceiptScan {
  final String title;
  final double? amount;
  final String? category;
  final String place;
  final DateTime? date;

  const ReceiptScan({
    required this.title,
    this.amount,
    this.category,
    this.place = '',
    this.date,
  });
}

class ExpenseQuery {
  final DateTime? start;

  /// Inclusive last day of the range.
  final DateTime? end;
  final String? category;
  final String? paymentMethod;

  const ExpenseQuery({this.start, this.end, this.category, this.paymentMethod});
}

class GeminiNotConfigured implements Exception {
  @override
  String toString() =>
      'AI features need a Gemini API key. Build with --dart-define=GEMINI_API_KEY=...';
}

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _modelName = 'gemini-3.1-flash-lite';

  static bool get isConfigured => _apiKey.isNotEmpty;

  GenerativeModel _model({bool json = false}) {
    if (!isConfigured) throw GeminiNotConfigured();
    return GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: json
          ? GenerationConfig(responseMimeType: 'application/json')
          : null,
    );
  }

  static Map<String, dynamic>? _decodeJson(String? text) {
    if (text == null) return null;
    var s = text.trim();
    // Tolerate fenced output even in JSON mode.
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    try {
      final decoded = jsonDecode(s);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty || value == 'null') return null;
    return DateTime.tryParse(value);
  }

  static String _isoDay(DateTime d) => d.toIso8601String().split('T').first;

  /// Reads a receipt photo. Returns null when nothing useful was found.
  Future<ReceiptScan?> analyzeReceipt(
    Uint8List imageBytes, {
    required List<String> categories,
    String mimeType = 'image/jpeg',
  }) async {
    final today = _isoDay(DateTime.now());
    final prompt = '''
You read shop receipts from Singapore. Return JSON only:
{"title": string, "amount": number, "category": string, "place": string, "date": "YYYY-MM-DD" or null}
- title: short description of the purchase, e.g. "Weekly groceries".
- amount: the final total paid in SGD, digits only.
- category: exactly one of: ${categories.join(', ')}.
- place: merchant or store name.
- date: the purchase date printed on the receipt, or null if none. Today is $today.
''';
    final response = await _model(json: true).generateContent([
      Content.multi([TextPart(prompt), DataPart(mimeType, imageBytes)]),
    ]);
    final data = _decodeJson(response.text);
    if (data == null) {
      debugPrint('Receipt scan: unparseable response ${response.text}');
      return null;
    }
    final amountRaw = data['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : Money.parse(amountRaw?.toString() ?? '');
    final title = (data['title'] ?? '').toString().trim();
    if (title.isEmpty && amount == null) return null;

    String? category = data['category']?.toString();
    if (category != null) {
      final match = categories.where(
        (c) => c.toLowerCase() == category!.toLowerCase(),
      );
      category = match.isEmpty ? null : match.first;
    }
    var date = _date(data['date']);
    // Ignore implausible dates (future, or older than a year).
    if (date != null &&
        (date.isAfter(DateTime.now()) ||
            DateTime.now().difference(date).inDays > 366)) {
      date = null;
    }
    return ReceiptScan(
      title: title.isEmpty ? 'Receipt' : title,
      amount: amount,
      category: category,
      place: (data['place'] ?? '').toString().trim(),
      date: date,
    );
  }

  /// Turns a question into filters for the expense search.
  Future<ExpenseQuery> parseQuery(
    String query, {
    required List<String> categories,
  }) async {
    final now = DateTime.now();
    final prompt = '''
Today is ${_isoDay(now)}. A user asks about their own expenses: "$query"
Return JSON only:
{"startDate": "YYYY-MM-DD", "endDate": "YYYY-MM-DD", "category": string or null, "paymentMethod": string or null}
- Work out exact dates from today. "This month" starts on the 1st. If no period is given, use the last 90 days ending today.
- category: one of ${categories.join(', ')}, or null if not specified.
- paymentMethod: one of ${kPaymentMethods.join(', ')}, or null if not specified.
''';
    final response = await _model(json: true).generateContent([
      Content.text(prompt),
    ]);
    final data = _decodeJson(response.text) ?? const {};
    String? pick(String key, List<String> allowed) {
      final v = data[key]?.toString();
      if (v == null) return null;
      final match = allowed.where((a) => a.toLowerCase() == v.toLowerCase());
      return match.isEmpty ? null : match.first;
    }

    return ExpenseQuery(
      start: _date(data['startDate']),
      end: _date(data['endDate']),
      category: pick('category', categories),
      paymentMethod: pick('paymentMethod', kPaymentMethods),
    );
  }

  /// Answers [question] from the expense rows found for it.
  Future<String> answer(String question, String dataSummary) async {
    final prompt = '''
You are a friendly, non-judgemental assistant inside a family expense app. Amounts are Singapore dollars (S\$).
Question: "$question"
Matching expenses:
$dataSummary

Answer briefly from this data only. Lead with the number they asked for. Use a short list only when comparing several items.
If there is no data, say you couldn't find matching expenses and suggest rephrasing the period or category.
''';
    final response = await _model().generateContent([Content.text(prompt)]);
    return response.text?.trim().isNotEmpty == true
        ? response.text!.trim()
        : "I couldn't come up with an answer. Try asking another way.";
  }

  /// A two-sentence weekly spending note.
  Future<String> weeklyInsight({
    required double totalSpent,
    required int transactionCount,
    required Map<String, double> categoryBreakdown,
    double? leftToSpend,
  }) async {
    final breakdown = categoryBreakdown.entries
        .map((e) => '${e.key}: ${Money.format(e.value)}')
        .join(', ');
    final prompt = '''
Write one or two short, warm sentences about this person's last 7 days of spending in Singapore. No emojis, no judgement, at most one practical tip.
Total: ${Money.format(totalSpent)} across $transactionCount purchases.
By category: $breakdown.
${leftToSpend != null ? 'Left to spend this month: ${Money.format(leftToSpend)}.' : ''}
''';
    final response = await _model().generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? '';
  }
}
