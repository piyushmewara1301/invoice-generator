import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../firebase_config.dart';
import '../models/business_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firestore document helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _strField(String v) => {'stringValue': v};
Map<String, dynamic> _intField(int v) => {'integerValue': '$v'};
Map<String, dynamic> _tsField(DateTime dt) =>
    {'timestampValue': dt.toUtc().toIso8601String()};
Map<String, dynamic> _arrField(List<String> items) => {
      'arrayValue': {
        'values': items.map((s) => {'stringValue': s}).toList()
      }
    };

String? _readStr(Map<String, dynamic> fields, String key) =>
    (fields[key] as Map?)?.entries.first.value as String?;

// ─────────────────────────────────────────────────────────────────────────────
// VerificationService
// ─────────────────────────────────────────────────────────────────────────────

class VerificationService {
  static const String _secret = 'INVOICE_APP_ADMIN_SECRET_V1';
  static const int _validDays = 7;
  static const String _actionVerify = 'verify';
  static const String _actionReject = 'reject';

  // ── HMAC code helpers (fallback when Firestore not configured) ────────────

  static String _dateStr(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static String _computeCode(String email, String action, DateTime date) {
    final msg = '${email.toLowerCase()}|$action|${_dateStr(date)}';
    final digest = Hmac(sha256, utf8.encode(_secret)).convert(utf8.encode(msg));
    return base64Url.encode(digest.bytes).replaceAll('=', '').substring(0, 16).toUpperCase();
  }

  static String generateVerifyCode(String email) =>
      _computeCode(email, _actionVerify, DateTime.now());

  static String generateRejectCode(String email) =>
      _computeCode(email, _actionReject, DateTime.now());

  static VerificationStatus? validateCode(String code, String email) {
    final trimmed = code.trim().toUpperCase();
    final now = DateTime.now();
    for (int i = 0; i < _validDays; i++) {
      final d = now.subtract(Duration(days: i));
      if (trimmed == _computeCode(email, _actionVerify, d)) return VerificationStatus.verified;
      if (trimmed == _computeCode(email, _actionReject, d)) return VerificationStatus.rejected;
    }
    return null;
  }

  // ── Firestore REST helpers ─────────────────────────────────────────────────

  static String get _base =>
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}'
      '/databases/(default)/documents';

  static String _verDoc(String email) =>
      '$_base/verifications/${Uri.encodeComponent(email)}?key=${FirebaseConfig.apiKey}';

  static String _statsDoc(String email) =>
      '$_base/stats/${Uri.encodeComponent(email)}?key=${FirebaseConfig.apiKey}';

  // ── Verification request ───────────────────────────────────────────────────

  /// Submits (or updates) a verification request in Firestore.
  /// Returns null on success, or an error string describing what went wrong.
  static Future<String?> submitRequest({
    required String userEmail,
    required String businessName,
    required List<String> driveLinks,
    String? notes,
  }) async {
    if (!FirebaseConfig.isConfigured) return 'Firebase not configured';
    try {
      final body = jsonEncode({
        'fields': {
          'userEmail': _strField(userEmail),
          'businessName': _strField(businessName),
          'status': _strField(VerificationStatus.pending.name),
          'driveLinks': _arrField(driveLinks),
          'notes': _strField(notes ?? ''),
          'submittedAt': _tsField(DateTime.now()),
        }
      });
      final res = await http
          .patch(Uri.parse(_verDoc(userEmail)),
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      return 'Firestore error ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }

  /// Reads the current verification status from Firestore.
  /// Returns null if not configured or request fails.
  static Future<VerificationStatus?> fetchStatus(String userEmail) async {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      final res = await http
          .get(Uri.parse(_verDoc(userEmail)))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 404) return VerificationStatus.unverified;
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>?;
      if (fields == null) return null;
      final statusStr = _readStr(fields, 'status');
      return VerificationStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => VerificationStatus.unverified,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Subscription tier ─────────────────────────────────────────────────────

  /// Reads the subscription tier set by the admin from the verifications doc.
  /// Returns null if not configured, not set, or request fails.
  static Future<SubscriptionTier?> fetchSubscriptionTier(String email) async {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      final res = await http
          .get(Uri.parse(_verDoc(email)))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>?;
      if (fields == null) return null;
      final tierStr = _readStr(fields, 'subscriptionTier');
      if (tierStr == null) return null;
      return SubscriptionTier.values.firstWhere(
        (e) => e.name == tierStr,
        orElse: () => SubscriptionTier.free,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Stats push ─────────────────────────────────────────────────────────────

  /// Pushes anonymised usage stats so the admin dashboard can display them.
  static Future<void> pushStats({
    required String userEmail,
    required String businessName,
    required int invoiceCount,
    required int clientCount,
  }) async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      final body = jsonEncode({
        'fields': {
          'userEmail': _strField(userEmail),
          'businessName': _strField(businessName),
          'invoiceCount': _intField(invoiceCount),
          'clientCount': _intField(clientCount),
          'lastActive': _tsField(DateTime.now()),
        }
      });
      await http
          .patch(Uri.parse(_statsDoc(userEmail)),
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Stats push is best-effort; ignore failures.
    }
  }
}
