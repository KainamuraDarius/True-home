import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###');
  static final RegExp _currencyPrefixPattern = RegExp(
    r'^(?:UGX|USD|EUR|GBP|ZAR|KES)\s*',
  );
  static final RegExp _compactAmountPattern = RegExp(
    r'^([+-]?\d+(?:\.\d+)?)([KMB])?\+?$',
  );

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

  /// Parses amounts like `50,000,000`, `50M`, `1.5B`, or `UGX 500M`.
  static double? tryParse(String value) {
    final normalized = value.replaceAll(',', '').trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final withoutPrefix = normalized.replaceFirst(_currencyPrefixPattern, '');
    final compactValue = withoutPrefix.replaceAll(RegExp(r'\s+'), '');
    final match = _compactAmountPattern.firstMatch(compactValue);
    if (match == null) return null;

    final baseValue = double.tryParse(match.group(1)!);
    if (baseValue == null) return null;

    final suffix = match.group(2);
    final multiplier = switch (suffix) {
      'K' => 1000,
      'M' => 1000000,
      'B' => 1000000000,
      _ => 1,
    };

    return baseValue * multiplier;
  }

  /// Parses a formatted string back to double.
  static double parse(String value) {
    return tryParse(value) ?? 0;
  }

  /// Formats a number in compact form (e.g., 10M, 500K, 1.5B)
  static String formatCompact(double value) {
    final absValue = value.abs();
    
    if (absValue >= 1000000000) {
      final billions = value / 1000000000;
      return billions % 1 == 0 
          ? '${billions.toInt()}B' 
          : '${billions.toStringAsFixed(1).replaceAll(RegExp(r'\.0+$'), '')}B';
    } else if (absValue >= 1000000) {
      final millions = value / 1000000;
      return millions % 1 == 0 
          ? '${millions.toInt()}M' 
          : '${millions.toStringAsFixed(1).replaceAll(RegExp(r'\.0+$'), '')}M';
    } else if (absValue >= 1000) {
      final thousands = value / 1000;
      return thousands % 1 == 0 
          ? '${thousands.toInt()}K' 
          : '${thousands.toStringAsFixed(1).replaceAll(RegExp(r'\.0+$'), '')}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}
