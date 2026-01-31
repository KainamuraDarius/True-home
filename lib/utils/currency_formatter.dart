import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###');

  /// Formats a number with comma separators (e.g., 1,000,000)
  static String format(double value) {
    return _formatter.format(value.round());
  }

  /// Formats with currency symbol (e.g., UGX 1,000,000)
  static String formatWithCurrency(double value, {String currency = 'UGX'}) {
    return '$currency ${format(value)}';
  }

  /// Formats price for text field input (removes commas for editing)
  static String formatForInput(double value) {
    return value.toStringAsFixed(0);
  }

  /// Parses a formatted string back to double (handles commas)
  static double parse(String value) {
    // Remove commas and parse
    final cleanValue = value.replaceAll(',', '').trim();
    return double.tryParse(cleanValue) ?? 0;
  }
}
