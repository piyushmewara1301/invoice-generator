import 'dart:convert';
import 'package:http/http.dart' as http;
import '../firebase_config.dart';
import '../models/employee.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployeeService — Firestore REST CRUD for team members
//
// Firestore path:
//   businesses/{ownerEmail}/employees/{employeeId}
//
// A separate flat index at:
//   employeeIndex/{employeeEmail}  →  { ownerEmail }
// is used to quickly look up which business an email belongs to.
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeService {
  static const _uuid = Uuid();

  static String get _base =>
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}'
      '/databases/(default)/documents';

  static String _empCol(String ownerEmail) =>
      '$_base/businesses/${Uri.encodeComponent(ownerEmail)}/employees'
      '?key=${FirebaseConfig.apiKey}';

  static String _empDoc(String ownerEmail, String employeeId) =>
      '$_base/businesses/${Uri.encodeComponent(ownerEmail)}/employees/$employeeId'
      '?key=${FirebaseConfig.apiKey}';

  static String _indexDoc(String employeeEmail) =>
      '$_base/employeeIndex/${Uri.encodeComponent(employeeEmail)}'
      '?key=${FirebaseConfig.apiKey}';

  // ── Fetch all employees for a business ────────────────────────────────────

  static Future<List<Employee>> fetchEmployees(String ownerEmail) async {
    if (!FirebaseConfig.isConfigured) return [];
    try {
      final res = await http
          .get(Uri.parse(_empCol(ownerEmail)))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 404 || res.statusCode == 200 && res.body.isEmpty) {
        return [];
      }
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final docs = data['documents'] as List? ?? [];
      return docs
          .map((d) {
            final fields = d['fields'] as Map<String, dynamic>?;
            if (fields == null) return null;
            return Employee.fromFirestoreFields(fields);
          })
          .whereType<Employee>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Add a new employee ────────────────────────────────────────────────────

  static Future<String?> addEmployee(
      String ownerEmail, Employee employee) async {
    if (!FirebaseConfig.isConfigured) return 'Firebase not configured';
    try {
      final body = jsonEncode({'fields': employee.toFirestoreFields()});

      // Write employee doc
      final res = await http
          .patch(
            Uri.parse(_empDoc(ownerEmail, employee.id)),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return 'Firestore error ${res.statusCode}';
      }

      // Write index doc so we can reverse-look up the owner by employee email
      await _writeIndex(employee.email, ownerEmail);
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  // ── Update an existing employee ───────────────────────────────────────────

  static Future<String?> updateEmployee(
      String ownerEmail, Employee employee) async {
    if (!FirebaseConfig.isConfigured) return 'Firebase not configured';
    try {
      final body = jsonEncode({'fields': employee.toFirestoreFields()});
      final res = await http
          .patch(
            Uri.parse(_empDoc(ownerEmail, employee.id)),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return 'Firestore error ${res.statusCode}';
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Delete an employee ────────────────────────────────────────────────────

  static Future<String?> deleteEmployee(
      String ownerEmail, Employee employee) async {
    if (!FirebaseConfig.isConfigured) return 'Firebase not configured';
    try {
      final res = await http
          .delete(Uri.parse(_empDoc(ownerEmail, employee.id)))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 && res.statusCode != 204) {
        return 'Firestore error ${res.statusCode}';
      }
      // Remove index entry
      await http
          .delete(Uri.parse(_indexDoc(employee.email)))
          .timeout(const Duration(seconds: 10));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Look up which business owns a given employee email ────────────────────

  /// Returns the owner's email if the given email is a registered employee,
  /// or null otherwise.
  static Future<String?> findOwnerEmail(String employeeEmail) async {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      final res = await http
          .get(Uri.parse(_indexDoc(employeeEmail)))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>?;
      if (fields == null) return null;
      return (fields['ownerEmail'] as Map?)?.entries.first.value as String?;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the employee record for a specific employee email within a business.
  static Future<Employee?> fetchEmployee(
      String ownerEmail, String employeeEmail) async {
    if (!FirebaseConfig.isConfigured) return null;
    final all = await fetchEmployees(ownerEmail);
    try {
      return all.firstWhere((e) => e.email == employeeEmail);
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String generateId() => _uuid.v4();

  static Future<void> _writeIndex(
      String employeeEmail, String ownerEmail) async {
    try {
      final body = jsonEncode({
        'fields': {
          'ownerEmail': {'stringValue': ownerEmail},
          'employeeEmail': {'stringValue': employeeEmail},
        }
      });
      await http
          .patch(
            Uri.parse(_indexDoc(employeeEmail)),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
