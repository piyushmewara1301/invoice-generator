// ─────────────────────────────────────────────────────────────────────────────
// Roles
// ─────────────────────────────────────────────────────────────────────────────

enum EmployeeRole { manager, staff, viewer }

extension EmployeeRoleX on EmployeeRole {
  String get displayName {
    switch (this) {
      case EmployeeRole.manager:
        return 'Manager';
      case EmployeeRole.staff:
        return 'Staff';
      case EmployeeRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case EmployeeRole.manager:
        return 'Full access except billing, business settings & team management';
      case EmployeeRole.staff:
        return 'Create & edit invoices and clients, record payments';
      case EmployeeRole.viewer:
        return 'View-only access to invoices, clients & dashboard';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permissions
// ─────────────────────────────────────────────────────────────────────────────

enum AppPermission {
  // Invoices
  viewInvoices,
  createInvoice,
  editInvoice,
  deleteInvoice,
  sendInvoice,
  approveInvoice,
  markInvoicePaid,
  recordPayment,
  // Clients
  viewClients,
  createClient,
  editClient,
  deleteClient,
  // Other sections
  viewDashboard,
  viewReports,
  manageItems,
  managePaymentMethods,
  // Owner-only
  editBusinessProfile,
  manageBilling,
  manageEmployees,
}

extension AppPermissionX on AppPermission {
  String get displayName {
    switch (this) {
      case AppPermission.viewInvoices:
        return 'View invoices';
      case AppPermission.createInvoice:
        return 'Create invoices';
      case AppPermission.editInvoice:
        return 'Edit invoices';
      case AppPermission.deleteInvoice:
        return 'Delete invoices';
      case AppPermission.sendInvoice:
        return 'Send invoices';
      case AppPermission.approveInvoice:
        return 'Approve invoices';
      case AppPermission.markInvoicePaid:
        return 'Mark invoices as paid';
      case AppPermission.recordPayment:
        return 'Record partial payments';
      case AppPermission.viewClients:
        return 'View clients';
      case AppPermission.createClient:
        return 'Add clients';
      case AppPermission.editClient:
        return 'Edit clients';
      case AppPermission.deleteClient:
        return 'Delete clients';
      case AppPermission.viewDashboard:
        return 'View dashboard';
      case AppPermission.viewReports:
        return 'View GST reports';
      case AppPermission.manageItems:
        return 'Manage items & services';
      case AppPermission.managePaymentMethods:
        return 'Manage payment methods';
      case AppPermission.editBusinessProfile:
        return 'Edit business profile';
      case AppPermission.manageBilling:
        return 'Manage billing & subscription';
      case AppPermission.manageEmployees:
        return 'Manage team members';
    }
  }

  String get groupName {
    switch (this) {
      case AppPermission.viewInvoices:
      case AppPermission.createInvoice:
      case AppPermission.editInvoice:
      case AppPermission.deleteInvoice:
      case AppPermission.sendInvoice:
      case AppPermission.approveInvoice:
      case AppPermission.markInvoicePaid:
      case AppPermission.recordPayment:
        return 'Invoices';
      case AppPermission.viewClients:
      case AppPermission.createClient:
      case AppPermission.editClient:
      case AppPermission.deleteClient:
        return 'Clients';
      case AppPermission.viewDashboard:
      case AppPermission.viewReports:
      case AppPermission.manageItems:
      case AppPermission.managePaymentMethods:
        return 'Other';
      case AppPermission.editBusinessProfile:
      case AppPermission.manageBilling:
      case AppPermission.manageEmployees:
        return 'Admin';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role defaults
// ─────────────────────────────────────────────────────────────────────────────

const Map<EmployeeRole, Set<AppPermission>> roleDefaultPermissions = {
  EmployeeRole.manager: {
    AppPermission.viewInvoices,
    AppPermission.createInvoice,
    AppPermission.editInvoice,
    AppPermission.deleteInvoice,
    AppPermission.sendInvoice,
    AppPermission.approveInvoice,
    AppPermission.markInvoicePaid,
    AppPermission.recordPayment,
    AppPermission.viewClients,
    AppPermission.createClient,
    AppPermission.editClient,
    AppPermission.deleteClient,
    AppPermission.viewDashboard,
    AppPermission.viewReports,
    AppPermission.manageItems,
  },
  EmployeeRole.staff: {
    AppPermission.viewInvoices,
    AppPermission.createInvoice,
    AppPermission.editInvoice,
    AppPermission.sendInvoice,
    AppPermission.markInvoicePaid,
    AppPermission.recordPayment,
    AppPermission.viewClients,
    AppPermission.createClient,
    AppPermission.editClient,
  },
  EmployeeRole.viewer: {
    AppPermission.viewInvoices,
    AppPermission.viewClients,
    AppPermission.viewDashboard,
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Employee
// ─────────────────────────────────────────────────────────────────────────────

class Employee {
  final String id;
  final String name;
  final String email;
  final EmployeeRole role;
  final bool isActive;
  final DateTime addedAt;

  /// null → use role defaults; non-null → fully custom permission set
  final Set<AppPermission>? customPermissions;

  /// Which shop this employee is assigned to.
  /// null / empty = not yet assigned (defaults to single-shop behaviour).
  final String? shopId;

  /// When true this employee can see all shops regardless of [shopId].
  /// Only the owner can grant this.
  final bool accessAllShops;

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    required this.addedAt,
    this.customPermissions,
    this.shopId,
    this.accessAllShops = false,
  });

  Set<AppPermission> get effectivePermissions =>
      customPermissions ?? roleDefaultPermissions[role] ?? {};

  bool can(AppPermission p) => effectivePermissions.contains(p);

  Employee copyWith({
    String? name,
    String? email,
    EmployeeRole? role,
    bool? isActive,
    Set<AppPermission>? customPermissions,
    bool clearCustomPermissions = false,
    String? shopId,
    bool? accessAllShops,
  }) {
    return Employee(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      addedAt: addedAt,
      customPermissions:
          clearCustomPermissions ? null : customPermissions ?? this.customPermissions,
      shopId: shopId ?? this.shopId,
      accessAllShops: accessAllShops ?? this.accessAllShops,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'isActive': isActive,
        'addedAt': addedAt.toIso8601String(),
        if (customPermissions != null)
          'customPermissions':
              customPermissions!.map((p) => p.name).toList(),
        if (shopId != null) 'shopId': shopId,
        'accessAllShops': accessAllShops,
      };

  factory Employee.fromJson(Map<String, dynamic> j) {
    final roleStr = j['role'] as String? ?? 'staff';
    final role = EmployeeRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => EmployeeRole.staff,
    );

    Set<AppPermission>? custom;
    if (j['customPermissions'] != null) {
      final list = (j['customPermissions'] as List).cast<String>();
      custom = list
          .map((s) => AppPermission.values.firstWhere(
                (p) => p.name == s,
                orElse: () => AppPermission.viewInvoices,
              ))
          .toSet();
    }

    return Employee(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      email: j['email'] as String? ?? '',
      role: role,
      isActive: j['isActive'] as bool? ?? true,
      addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
      customPermissions: custom,
      shopId: j['shopId'] as String?,
      accessAllShops: j['accessAllShops'] as bool? ?? false,
    );
  }

  // Firestore field helpers
  static Map<String, dynamic> _strField(String v) => {'stringValue': v};
  static Map<String, dynamic> _boolField(bool v) => {'booleanValue': v};
  static Map<String, dynamic> _tsField(DateTime dt) =>
      {'timestampValue': dt.toUtc().toIso8601String()};
  static Map<String, dynamic> _arrField(List<String> items) => {
        'arrayValue': {
          'values': items.map((s) => {'stringValue': s}).toList()
        }
      };

  Map<String, dynamic> toFirestoreFields() {
    return {
      'id': _strField(id),
      'name': _strField(name),
      'email': _strField(email),
      'role': _strField(role.name),
      'isActive': _boolField(isActive),
      'addedAt': _tsField(addedAt),
      if (customPermissions != null)
        'customPermissions':
            _arrField(customPermissions!.map((p) => p.name).toList()),
      if (shopId != null) 'shopId': _strField(shopId!),
      'accessAllShops': _boolField(accessAllShops),
    };
  }

  static String? _str(Map<String, dynamic> fields, String key) =>
      (fields[key] as Map?)?.entries.first.value as String?;
  static bool? _bool(Map<String, dynamic> fields, String key) =>
      (fields[key] as Map?)?['booleanValue'] as bool?;
  static List<String>? _arr(Map<String, dynamic> fields, String key) {
    final av = (fields[key] as Map?)?['arrayValue'] as Map?;
    if (av == null) return null;
    final vals = av['values'] as List?;
    if (vals == null) return null;
    return vals.map((v) => (v as Map)['stringValue'] as String).toList();
  }

  factory Employee.fromFirestoreFields(Map<String, dynamic> fields) {
    final roleStr = _str(fields, 'role') ?? 'staff';
    final role = EmployeeRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => EmployeeRole.staff,
    );

    Set<AppPermission>? custom;
    final customList = _arr(fields, 'customPermissions');
    if (customList != null) {
      custom = customList
          .map((s) => AppPermission.values.firstWhere(
                (p) => p.name == s,
                orElse: () => AppPermission.viewInvoices,
              ))
          .toSet();
    }

    return Employee(
      id: _str(fields, 'id') ?? '',
      name: _str(fields, 'name') ?? '',
      email: _str(fields, 'email') ?? '',
      role: role,
      isActive: _bool(fields, 'isActive') ?? true,
      addedAt: DateTime.tryParse(_str(fields, 'addedAt') ?? '') ?? DateTime.now(),
      customPermissions: custom,
      shopId: _str(fields, 'shopId'),
      accessAllShops: _bool(fields, 'accessAllShops') ?? false,
    );
  }
}
