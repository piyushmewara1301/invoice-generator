import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_pairing.dart';

/// Persists an [EmployeePairing] in SharedPreferences.
/// Used only by employees who have scanned an owner's QR code.
class PairingService {
  static const _key = 'employee_pairing_v1';

  static Future<EmployeePairing?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return EmployeePairing.fromJsonString(raw);
  }

  static Future<void> save(EmployeePairing pairing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pairing.toJsonString());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
