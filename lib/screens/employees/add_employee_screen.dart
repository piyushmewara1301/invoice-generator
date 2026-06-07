import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../../utils/app_theme.dart';

class AddEmployeeScreen extends StatefulWidget {
  final Employee? existing;
  const AddEmployeeScreen({super.key, this.existing});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late EmployeeRole _role;
  late Set<AppPermission> _permissions;
  bool _useCustomPermissions = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _role = e?.role ?? EmployeeRole.staff;
    _useCustomPermissions = e?.customPermissions != null;
    _permissions = Set.from(
      e?.customPermissions ?? roleDefaultPermissions[_role] ?? {},
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _onRoleChanged(EmployeeRole role) {
    setState(() {
      _role = role;
      if (!_useCustomPermissions) {
        _permissions = Set.from(roleDefaultPermissions[role] ?? {});
      }
    });
  }

  void _onCustomToggle(bool val) {
    setState(() {
      _useCustomPermissions = val;
      if (!val) {
        // Reset to role defaults when custom is turned off
        _permissions = Set.from(roleDefaultPermissions[_role] ?? {});
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final id = _isEdit ? widget.existing!.id : EmployeeService.generateId();
    final employee = Employee(
      id: id,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().toLowerCase(),
      role: _role,
      isActive: widget.existing?.isActive ?? true,
      addedAt: widget.existing?.addedAt ?? DateTime.now(),
      customPermissions: _useCustomPermissions ? Set.from(_permissions) : null,
    );

    Navigator.pop(context, employee);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Employee' : 'Add Employee'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Basic info ─────────────────────────────────────────────────
            _SectionHeader(title: 'Basic Info'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Google Account Email',
                prefixIcon: Icon(Icons.email_outlined),
                helperText: 'Employee must sign in with this Google account',
              ),
              keyboardType: TextInputType.emailAddress,
              readOnly: _isEdit, // email is the identity key — don't change it
              style: _isEdit
                  ? TextStyle(color: AppTheme.subtext(context))
                  : null,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Role picker ────────────────────────────────────────────────
            _SectionHeader(title: 'Role'),
            const SizedBox(height: 12),
            ...EmployeeRole.values.map((role) => _RoleTile(
                  role: role,
                  selected: _role == role,
                  onTap: () => _onRoleChanged(role),
                )),
            const SizedBox(height: 24),

            // ── Permissions ────────────────────────────────────────────────
            _SectionHeader(
              title: 'Permissions',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _useCustomPermissions ? 'Custom' : 'Role default',
                    style: TextStyle(
                      fontSize: 12,
                      color: _useCustomPermissions
                          ? const Color(0xFFE65100)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch.adaptive(
                    value: _useCustomPermissions,
                    onChanged: _onCustomToggle,
                    activeTrackColor: AppTheme.primary,
                  ),
                ],
              ),
            ),
            if (!_useCustomPermissions) ...[
              const SizedBox(height: 8),
              _DefaultPermissionsPreview(role: _role),
            ] else ...[
              const SizedBox(height: 8),
              _CustomPermissionsEditor(
                permissions: _permissions,
                onChanged: (p) => setState(() => _permissions = p),
              ),
            ],
            const SizedBox(height: 32),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Add Employee'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role tile
// ─────────────────────────────────────────────────────────────────────────────

class _RoleTile extends StatelessWidget {
  final EmployeeRole role;
  final bool selected;
  final VoidCallback onTap;
  const _RoleTile(
      {required this.role, required this.selected, required this.onTap});

  Color get _color {
    switch (role) {
      case EmployeeRole.manager:
        return const Color(0xFF7C3AED);
      case EmployeeRole.staff:
        return const Color(0xFF0369A1);
      case EmployeeRole.viewer:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _color.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _color : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_roleIcon(role), color: _color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.displayName,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? _color : null)),
                  const SizedBox(height: 2),
                  Text(role.description,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.subtext(context))),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: _color, size: 20)
            else
              Icon(Icons.circle_outlined,
                  color: AppTheme.outline(context), size: 20),
          ],
        ),
      ),
    );
  }

  IconData _roleIcon(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.manager:
        return Icons.manage_accounts_outlined;
      case EmployeeRole.staff:
        return Icons.badge_outlined;
      case EmployeeRole.viewer:
        return Icons.visibility_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default permissions preview (read-only chips)
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultPermissionsPreview extends StatelessWidget {
  final EmployeeRole role;
  const _DefaultPermissionsPreview({required this.role});

  @override
  Widget build(BuildContext context) {
    final perms = roleDefaultPermissions[role] ?? {};
    final groups = <String, List<AppPermission>>{};
    for (final p in AppPermission.values) {
      if (perms.contains(p)) {
        groups.putIfAbsent(p.groupName, () => []).add(p);
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in groups.entries) ...[
            Text(entry.key,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.subtext(context),
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.value
                  .map((p) => _PermChip(label: p.displayName, enabled: true))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Toggle "Custom" above to override these permissions.',
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom permissions editor (grouped toggles)
// ─────────────────────────────────────────────────────────────────────────────

class _CustomPermissionsEditor extends StatelessWidget {
  final Set<AppPermission> permissions;
  final ValueChanged<Set<AppPermission>> onChanged;
  const _CustomPermissionsEditor(
      {required this.permissions, required this.onChanged});

  // Admin permissions are always locked off for employees
  static const _locked = {
    AppPermission.editBusinessProfile,
    AppPermission.manageBilling,
    AppPermission.manageEmployees,
  };

  @override
  Widget build(BuildContext context) {
    // Group permissions
    final groups = <String, List<AppPermission>>{};
    for (final p in AppPermission.values) {
      if (_locked.contains(p)) continue;
      groups.putIfAbsent(p.groupName, () => []).add(p);
    }

    return Column(
      children: [
        for (final entry in groups.entries)
          _PermissionGroup(
            groupName: entry.key,
            permissions: entry.value,
            enabled: permissions,
            onToggle: (p, val) {
              final next = Set<AppPermission>.from(permissions);
              val ? next.add(p) : next.remove(p);
              onChanged(next);
            },
          ),
        // Locked admin section
        _LockedAdminSection(),
      ],
    );
  }
}

class _PermissionGroup extends StatelessWidget {
  final String groupName;
  final List<AppPermission> permissions;
  final Set<AppPermission> enabled;
  final void Function(AppPermission, bool) onToggle;

  const _PermissionGroup({
    required this.groupName,
    required this.permissions,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(groupName,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.subtext(context),
                    letterSpacing: 0.5)),
          ),
          for (int i = 0; i < permissions.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 14),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              title: Text(permissions[i].displayName,
                  style: const TextStyle(fontSize: 13)),
              value: enabled.contains(permissions[i]),
              onChanged: (v) => onToggle(permissions[i], v),
              activeTrackColor: AppTheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedAdminSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Admin permissions (edit business profile, manage billing, '
              'manage team) are always restricted to the account owner.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.subtext(context),
                letterSpacing: 0.3)),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}

class _PermChip extends StatelessWidget {
  final String label;
  final bool enabled;
  const _PermChip({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? AppTheme.primary.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: enabled
                ? AppTheme.primary.withValues(alpha: 0.25)
                : AppTheme.divider),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            color: enabled ? AppTheme.primary : AppTheme.textSecondary),
      ),
    );
  }
}
