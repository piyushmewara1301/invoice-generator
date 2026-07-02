import 'dart:convert';

/// Holds the data an employee needs to access the owner's Drive file.
/// The owner generates this via QR; the employee scans it once and it's
/// persisted locally. No sensitive data ever goes to our backend.
class EmployeePairing {
  final String ownerEmail;
  final String fileId;   // Google Drive file ID of the owner's data file
  final String encKey;   // base64-encoded AES-256 key matching that file

  /// Which shop this employee is restricted to (null = all shops).
  final String? shopId;

  /// Human-readable shop name shown on the employee's home screen.
  final String? shopName;

  const EmployeePairing({
    required this.ownerEmail,
    required this.fileId,
    required this.encKey,
    this.shopId,
    this.shopName,
  });

  // QR wire format v1 (legacy): "bbpairing1:{ownerEmail}|{fileId}|{encKey}"
  // QR wire format v2 (shop):   "bbpairing2:{ownerEmail}|{fileId}|{encKey}|{shopId}|{shopName}"
  static const _prefixV1 = 'bbpairing1:';
  static const _prefixV2 = 'bbpairing2:';

  String toQrString() {
    if (shopId != null && shopId!.isNotEmpty) {
      final name = (shopName ?? '').replaceAll('|', '-');
      return '$_prefixV2$ownerEmail|$fileId|$encKey|$shopId|$name';
    }
    return '$_prefixV1$ownerEmail|$fileId|$encKey';
  }

  static EmployeePairing? fromQrString(String qr) {
    if (qr.startsWith(_prefixV2)) {
      final parts = qr.substring(_prefixV2.length).split('|');
      if (parts.length < 4) return null;
      return EmployeePairing(
        ownerEmail: parts[0],
        fileId: parts[1],
        encKey: parts[2],
        shopId: parts[3].isEmpty ? null : parts[3],
        shopName: parts.length >= 5 ? parts[4] : null,
      );
    }
    if (qr.startsWith(_prefixV1)) {
      final parts = qr.substring(_prefixV1.length).split('|');
      if (parts.length != 3) return null;
      if (parts[0].isEmpty || parts[1].isEmpty || parts[2].isEmpty) return null;
      return EmployeePairing(
        ownerEmail: parts[0],
        fileId: parts[1],
        encKey: parts[2],
      );
    }
    return null;
  }

  Map<String, String?> toJson() => {
        'ownerEmail': ownerEmail,
        'fileId': fileId,
        'encKey': encKey,
        'shopId': shopId,
        'shopName': shopName,
      };

  factory EmployeePairing.fromJson(Map<String, dynamic> json) =>
      EmployeePairing(
        ownerEmail: json['ownerEmail'] as String,
        fileId: json['fileId'] as String,
        encKey: json['encKey'] as String,
        shopId: json['shopId'] as String?,
        shopName: json['shopName'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  static EmployeePairing? fromJsonString(String s) {
    try {
      return EmployeePairing.fromJson(
          jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
