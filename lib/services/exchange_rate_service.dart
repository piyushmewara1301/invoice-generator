import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExchangeRateService extends ChangeNotifier {
  // rates[FROM_CURRENCY] = how many units of FROM per 1 unit of _base
  // e.g. base=USD, rates[INR]=83.5 means 1 USD = 83.5 INR
  Map<String, double> _rates = {};
  String _base = '';
  DateTime? _fetchedAt;
  bool _loading = false;

  bool get loading => _loading;
  bool get hasRates => _rates.isNotEmpty;
  String get base => _base;
  DateTime? get lastUpdated => _fetchedAt;

  static const _ttl = Duration(hours: 1);

  bool _isStale(String currency) {
    if (_base.toUpperCase() != currency.toUpperCase()) return true;
    if (_fetchedAt == null) return true;
    return DateTime.now().difference(_fetchedAt!) > _ttl;
  }

  Future<void> fetchIfNeeded(String baseCurrency) async {
    if (baseCurrency.isEmpty) return;
    if (!_isStale(baseCurrency)) return;
    if (_loading) return;

    _loading = true;
    notifyListeners();
    try {
      final code = baseCurrency.toLowerCase();
      // Free CDN-backed API — no key required, updated daily
      final uri = Uri.parse(
          'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/$code.json');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawRates = data[code] as Map<String, dynamic>;
        _rates = rawRates.map(
            (k, v) => MapEntry(k.toUpperCase(), (v as num).toDouble()));
        _rates[baseCurrency.toUpperCase()] = 1.0;
        _base = baseCurrency.toUpperCase();
        _fetchedAt = DateTime.now();
      }
    } catch (_) {
      // Network unavailable — keep using cached rates or raw amounts
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Converts [amount] from [fromCurrency] into the cached [base] currency.
  /// Returns the original amount unchanged when rates are unavailable.
  double toBase(double amount, String fromCurrency) {
    final from = fromCurrency.toUpperCase();
    if (from == _base) return amount;
    if (_rates.isEmpty) return amount;
    final rate = _rates[from];
    if (rate == null || rate == 0) return amount;
    // rate = units of `from` per 1 unit of base  →  base = from / rate
    return amount / rate;
  }

  /// Returns the rate to convert 1 unit of [from] into [to].
  /// Requires [fetchIfNeeded] to have been called first.
  /// Uses cross-rate arithmetic when [from] and [to] are both non-base currencies.
  /// Returns 1.0 when rates are unavailable or the currencies are the same.
  double getRate(String from, String to) {
    final f = from.toUpperCase();
    final t = to.toUpperCase();
    if (f == t) return 1.0;
    if (_rates.isEmpty) return 1.0;
    // f is the cached base: rates[to] = units of TO per 1 unit of BASE(=f)
    if (f == _base) return _rates[t] ?? 1.0;
    // t is the cached base: rates[f] = units of FROM per 1 unit of BASE(=t)
    if (t == _base) {
      final rF = _rates[f];
      return (rF != null && rF != 0) ? 1.0 / rF : 1.0;
    }
    // Cross-rate through base: rate(f→t) = rates[t] / rates[f]
    final rF = _rates[f];
    final rT = _rates[t];
    return (rF != null && rT != null && rF != 0) ? rT / rF : 1.0;
  }

  /// True when at least one of [currencies] differs from [base],
  /// meaning the dashboard is showing converted totals.
  bool isConverting(Iterable<String> currencies) {
    if (_rates.isEmpty) return false;
    return currencies.any((c) => c.toUpperCase() != _base);
  }
}
