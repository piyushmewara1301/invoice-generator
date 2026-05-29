import 'dart:convert';

/// Holds the data an employee needs to access the owner's Drive file.
/// The owner generates this via QR; the employee scans it once and it's
/// persisted locally. No sensitive data ever goes to our backend.
class EmployeePairing {
  final String ownerEmail;
  final String fileId;   // Google Drive file ID of the owner's data file
  final String encKey;   // base64-encoded AES-256 key matching that file

  const EmployeePairing({
    required this.ownerEmail,
    required this.fileId,
    required this.encKey,
  });

  // QR wire format: "bbpairing1:{ownerEmail}|{fileId}|{encKey}"
  static const _prefix = 'bbpairing1:';

  String toQrString() => '$_prefix$ownerEmail|$fileId|$encKey';

  static EmployeePairing? fromQrString(String qr) {
    if (!qr.startsWith(_prefix)) return null;
    final parts = qr.substring(_prefix.length).split('|');
    if (parts.length != 3) return null;
    if (parts[0].isEmpty || parts[1].isEmpty || parts[2].isEmpty) return null;
    return EmployeePairing(
      ownerEmail: parts[0],
      fileId: parts[1],
      encKey: parts[2],
    );
  }

  Map<String, String> toJson() => {
        'ownerEmail': ownerEmail,
        'fileId': fileId,
        'encKey': encKey,
      };

  factory EmployeePairing.fromJson(Map<String, dynamic> json) =>
      EmployeePairing(
        ownerEmail: json['ownerEmail'] as String,
        fileId: json['fileId'] as String,
        encKey: json['encKey'] as String,
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
