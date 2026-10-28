import 'package:intl/intl.dart';

/// All amounts are Singapore dollars.
class Money {
  static final _full = NumberFormat.currency(
    locale: 'en_SG',
    symbol: r'S$ ',
    decimalDigits: 2,
  );
  static final _whole = NumberFormat.currency(
    locale: 'en_SG',
    symbol: r'S$ ',
    decimalDigits: 0,
  );
  static final _plain = NumberFormat('#,##0.00', 'en_SG');

  /// `S$ 1,284.60`. Negative values keep their sign.
  static String format(double value) => _full.format(value);

  /// `S$ 1,285`, for chart labels and tight spaces.
  static String whole(double value) => _whole.format(value);

  /// `1,284.60` without the symbol.
  static String plain(double value) => _plain.format(value);

  /// Parses user input like `12`, `12.5`, `1,200.00`, `S$ 4.20`.
  static double? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
