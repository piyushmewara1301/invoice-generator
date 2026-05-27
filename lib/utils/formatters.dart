import 'package:intl/intl.dart';

class Fmt {
  static String currency(double amount, {String symbol = '₹'}) {
    final f = NumberFormat('#,##,##0.00', 'en_IN');
    return '$symbol${f.format(amount)}';
  }

  static String date(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  static String shortDate(DateTime d) => DateFormat('dd/MM/yy').format(d);

  static String currencySymbol(String code) {
    const map = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'AED ',
      'SGD': 'S\$',
    };
    return map[code] ?? code;
  }

  static String currencyAmount(double amount, String currencyCode) {
    return currency(amount, symbol: currencySymbol(currencyCode));
  }

  /// Compact number: 1,23,456 → "1.23L", 12,34,56,789 → "12.35Cr", else normal 2-dp.
  static String compact(double amount) {
    if (amount >= 1e7) {
      return '${(amount / 1e7).toStringAsFixed(2)}Cr';
    } else if (amount >= 1e5) {
      return '${(amount / 1e5).toStringAsFixed(2)}L';
    } else if (amount >= 1e3) {
      final f = NumberFormat('#,##,##0.##', 'en_IN');
      return f.format(amount);
    }
    return amount.toStringAsFixed(2);
  }
}
