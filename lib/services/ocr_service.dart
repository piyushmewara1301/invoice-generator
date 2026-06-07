import 'dart:convert';
import 'dart:io';

// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

// ── Result types ──────────────────────────────────────────────────────────────

class OcrExpenseResult {
  final double? amount;
  final DateTime? date;
  final String? vendorName;

  const OcrExpenseResult({this.amount, this.date, this.vendorName});

  bool get hasData => amount != null || date != null || vendorName != null;
}

class OcrBillResult {
  final String? vendorName;
  final String? billNumber;
  final DateTime? date;
  final double? total;
  final String? gstin;

  const OcrBillResult({
    this.vendorName,
    this.billNumber,
    this.date,
    this.total,
    this.gstin,
  });

  bool get hasData =>
      vendorName != null || billNumber != null || date != null || total != null;
}

// ── Service ───────────────────────────────────────────────────────────────────

class OcrService {
  static final _gstinRe =
      RegExp(r'[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]');

  /// Extract raw text from a base64-encoded JPEG image.
  // static Future<String?> extractTextFromBase64(String base64Image) async {
  //   File? tmp;
  //   try {
  //     final bytes = base64Decode(base64Image);
  //     final dir = await getTemporaryDirectory();
  //     tmp = File(
  //         '${dir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
  //     await tmp.writeAsBytes(bytes);
  //     return await _runOcr(tmp);
  //   } catch (_) {
  //     return null;
  //   } finally {
  //     try {
  //       tmp?.deleteSync();
  //     } catch (_) {}
  //   }
  // }

  /// Extract raw text directly from a [File].
  // static Future<String?> extractTextFromFile(File file) async {
  //   try {
  //     return await _runOcr(file);
  //   } catch (_) {
  //     return null;
  //   }
  // }

  // static Future<String?> _runOcr(File file) async {
  //   final recognizer =
  //       TextRecognizer(script: TextRecognitionScript.latin);
  //   try {
  //     final result =
  //         await recognizer.processImage(InputImage.fromFile(file));
  //     return result.text.isEmpty ? null : result.text;
  //   } finally {
  //     await recognizer.close();
  //   }
  // }

  // ── Public parsers ──────────────────────────────────────────────────────

  static OcrExpenseResult parseExpense(String text) => OcrExpenseResult(
        amount: _extractTotal(text),
        date: _extractDate(text),
        vendorName: _extractVendorName(text),
      );

  static OcrBillResult parseBill(String text) => OcrBillResult(
        vendorName: _extractVendorName(text),
        billNumber: _extractBillNumber(text),
        date: _extractDate(text),
        total: _extractTotal(text),
        gstin: _extractGstin(text),
      );

  // ── Amount extraction ───────────────────────────────────────────────────

  static double? _extractTotal(String text) {
    final lines = text.split('\n');

    // 1. Look for lines containing total-related keywords (scan bottom-up
    //    since grand total usually appears near the end of a receipt).
    final totalRe = RegExp(
      r'(?:grand\s*total|total\s*amount|net\s*payable|amount\s*payable|'
      r'net\s*total|amount\s*due|total|payable)',
      caseSensitive: false,
    );
    for (final line in lines.reversed) {
      if (totalRe.hasMatch(line)) {
        final amt = _rightmostAmount(line);
        if (amt != null && amt > 0) return amt;
      }
    }

    // 2. Fallback: last occurrence of a ₹ / Rs. followed by a number.
    final rupeeRe = RegExp(
        r'(?:₹|Rs\.?)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false);
    double? last;
    for (final m in rupeeRe.allMatches(text)) {
      final v = _parseAmount(m.group(1) ?? '');
      if (v != null && v > 0) last = v;
    }
    return last;
  }

  static double? _rightmostAmount(String line) {
    final re = RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)');
    for (final m in re.allMatches(line).toList().reversed) {
      final v = _parseAmount(m.group(1) ?? '');
      if (v != null && v > 0) return v;
    }
    return null;
  }

  static double? _parseAmount(String s) =>
      double.tryParse(s.replaceAll(',', ''));

  // ── Date extraction ─────────────────────────────────────────────────────

  static final _monthMap = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5,  'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10,'nov': 11, 'dec': 12,
  };

  static DateTime? _extractDate(String text) {
    // Priority 1: DD Mon(th) YYYY — unambiguous month name.
    final wordRe = RegExp(
      r'\b(\d{1,2})[\s\-/]'
      r'(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|'
      r'Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|'
      r'Nov(?:ember)?|Dec(?:ember)?)[\s\-/](\d{4})\b',
      caseSensitive: false,
    );
    for (final m in wordRe.allMatches(text)) {
      final day = int.tryParse(m.group(1) ?? '');
      final month = _monthMap[m.group(2)!.toLowerCase().substring(0, 3)];
      final year = int.tryParse(m.group(3) ?? '');
      if (_validDate(day, month, year)) {
        try {
          return DateTime(year!, month!, day!);
        } catch (_) {}
      }
    }

    // Priority 2: DD/MM/YYYY or DD-MM-YYYY (standard Indian format).
    final dmyRe = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b');
    for (final m in dmyRe.allMatches(text)) {
      final d = int.tryParse(m.group(1) ?? '');
      final mo = int.tryParse(m.group(2) ?? '');
      final y = int.tryParse(m.group(3) ?? '');
      if (_validDate(d, mo, y)) {
        try {
          return DateTime(y!, mo!, d!);
        } catch (_) {}
      }
    }

    // Priority 3: ISO YYYY-MM-DD.
    final isoRe = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
    for (final m in isoRe.allMatches(text)) {
      final y = int.tryParse(m.group(1) ?? '');
      final mo = int.tryParse(m.group(2) ?? '');
      final d = int.tryParse(m.group(3) ?? '');
      if (_validDate(d, mo, y)) {
        try {
          return DateTime(y!, mo!, d!);
        } catch (_) {}
      }
    }

    return null;
  }

  static bool _validDate(int? d, int? m, int? y) =>
      d != null &&
      m != null &&
      y != null &&
      d >= 1 &&
      d <= 31 &&
      m >= 1 &&
      m <= 12 &&
      y >= 2000 &&
      y <= 2100;

  // ── Vendor name extraction ──────────────────────────────────────────────

  static String? _extractVendorName(String text) {
    final skip = RegExp(
      r'^(?:gstin|gst|pan|cin|bill|invoice|receipt|date|phone|'
      r'tel|mob|address|email|www\.|http)',
      caseSensitive: false,
    );
    for (final raw in text.split('\n').take(8)) {
      final t = raw.trim();
      if (t.length < 3 || t.length > 70) continue;
      final digits =
          t.runes.where((c) => c >= 48 && c <= 57).length;
      if (digits / t.length > 0.5) continue;
      if (RegExp(r'^\+?[\d\s\-()]{8,}$').hasMatch(t)) continue;
      if (RegExp(r'\d[/\-.]\d[/\-.]\d').hasMatch(t)) continue;
      if (RegExp(r'^[₹Rs.\s\d,]+$').hasMatch(t)) continue;
      if (skip.hasMatch(t)) continue;
      return t;
    }
    return null;
  }

  // ── Bill number extraction ──────────────────────────────────────────────

  static String? _extractBillNumber(String text) {
    final re = RegExp(
      r'(?:bill\s*(?:no\.?|number|#)|invoice\s*(?:no\.?|number|#)|'
      r'receipt\s*(?:no\.?|number|#)|ref(?:erence)?\s*(?:no\.?|#)|'
      r'voucher\s*(?:no\.?|#))[:\s]*([A-Z0-9/\-]+)',
      caseSensitive: false,
    );
    final m = re.firstMatch(text);
    final val = m?.group(1)?.trim();
    return (val != null && val.isNotEmpty) ? val : null;
  }

  // ── GSTIN extraction ────────────────────────────────────────────────────

  static String? _extractGstin(String text) {
    final m =
        _gstinRe.firstMatch(text.toUpperCase().replaceAll(' ', ''));
    return m?.group(0);
  }
}
