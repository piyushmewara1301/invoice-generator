import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import 'add_employee_screen.dart';
import 'owner_pairing_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Employee> _employees = [];
  bool _loading = true;
  String? _error;
  String? _ownerEmail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final email = context.read<AuthService>().user?.email;
    if (email != _ownerEmail) {
      _ownerEmail = email;
      _load();
    }
  }

  Future<void> _load() async {
    final email = _ownerEmail;
    if (email == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    setState(() => _loading = true);
    final list = await EmployeeService.fetchEmployees(email);
    if (mounted) {
      setState(() {
        _employees = list;
        _loading = false;
        _error = null;
      });
    }
  }

  Future<void> _openAdd() async {
    final result = await Navigator.push<Employee>(
      context,
      MaterialPageRoute(builder: (_) => const AddEmployeeScreen()),
    );
    if (result != null && _ownerEmail != null) {
      if (result.email.toLowerCase() == _ownerEmail!.toLowerCase()) {
        _showSnack('You cannot add yourself as a team member', isError: true);
        return;
      }
      final err = await EmployeeService.addEmployee(_ownerEmail!, result);
      if (!mounted) return;
      if (err != null) {
        _showSnack('Failed to add employee: $err', isError: true);
      } else {
        setState(() => _employees = [..._employees, result]);
        _showSnack('${result.name} added to your team');
      }
    }
  }

  Future<void> _openEdit(Employee emp) async {
    final result = await Navigator.push<Employee>(
      context,
      MaterialPageRoute(builder: (_) => AddEmployeeScreen(existing: emp)),
    );
    if (result != null && _ownerEmail != null) {
      final err = await EmployeeService.updateEmployee(_ownerEmail!, result);
      if (!mounted) return;
      if (err != null) {
        _showSnack('Failed to update: $err', isError: true);
      } else {
        setState(() {
          _employees = [
            for (final e in _employees) e.id == result.id ? result : e
          ];
        });
        _showSnack('${result.name} updated');
      }
    }
  }

  Future<void> _toggleActive(Employee emp) async {
    final updated = emp.copyWith(isActive: !emp.isActive);
    final err =
        await EmployeeService.updateEmployee(_ownerEmail!, updated);
    if (!mounted) return;
    if (err != null) {
      _showSnack('Could not update: $err', isError: true);
    } else {
      setState(() {
        _employees = [
          for (final e in _employees) e.id == emp.id ? updated : e
        ];
      });
    }
  }

  Future<void> _openShareAccess(Employee emp) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerPairingScreen(
          employeeName: emp.name,
          employeeEmail: emp.email,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Employee emp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove employee?'),
        content: Text(
            '${emp.name} will lose access to this business immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || _ownerEmail == null) return;
    final err = await EmployeeService.deleteEmployee(_ownerEmail!, emp);
    if (!mounted) return;
    if (err != null) {
      _showSnack('Could not remove: $err', isError: true);
    } else {
      setState(
          () => _employees = _employees.where((e) => e.id != emp.id).toList());
      _showSnack('${emp.name} removed');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : null,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Employee'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _employees.isEmpty
                  ? _EmptyView(onAdd: _openAdd)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          _InfoBanner(),
                          const SizedBox(height: 16),
                          for (final emp in _employees) ...[
                            _EmployeeCard(
                              employee: emp,
                              onEdit: () => _openEdit(emp),
                              onToggle: () => _toggleActive(emp),
                              onDelete: () => _confirmDelete(emp),
                              onShare: () => _openShareAccess(emp),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee card
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _EmployeeCard({
    required this.employee,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(employee.role);
    final isActive = employee.isActive;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  child: Text(
                    employee.name.isNotEmpty
                        ? employee.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: roleColor),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employee.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _RoleBadge(role: employee.role, color: roleColor),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        employee.email,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.subtext(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _PermissionChips(employee: employee),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                // Active toggle
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.toggle_on_outlined
                                : Icons.toggle_off_outlined,
                            size: 18,
                            color: isActive
                                ? const Color(0xFF16A34A)
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? const Color(0xFF16A34A)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Share access
                IconButton(
                  icon: const Icon(Icons.qr_code_outlined, size: 18),
                  color: const Color(0xFF0369A1),
                  tooltip: 'Share Access',
                  onPressed: onShare,
                  visualDensity: VisualDensity.compact,
                ),
                // Edit
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppTheme.primary,
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red,
                  tooltip: 'Remove',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.manager:
        return const Color(0xFF7C3AED);
      case EmployeeRole.staff:
        return const Color(0xFF0369A1);
      case EmployeeRole.viewer:
        return const Color(0xFF64748B);
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final EmployeeRole role;
  final Color color;
  const _RoleBadge({required this.role, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _PermissionChips extends StatelessWidget {
  final Employee employee;
  const _PermissionChips({required this.employee});

  @override
  Widget build(BuildContext context) {
    // Show a short summary of what this employee can do
    final perms = employee.effectivePermissions;
    final tags = <String>[];
    if (perms.contains(AppPermission.createInvoice)) tags.add('Create invoices');
    if (perms.contains(AppPermission.deleteInvoice)) tags.add('Delete');
    if (perms.contains(AppPermission.recordPayment)) tags.add('Payments');
    if (perms.contains(AppPermission.viewReports)) tags.add('Reports');
    if (perms.contains(AppPermission.manageItems)) tags.add('Items');
    if (!perms.contains(AppPermission.viewInvoices)) tags.insert(0, 'Read-only');

    final isCustom = employee.customPermissions != null;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        if (isCustom)
          _chip('Custom', const Color(0xFFE65100)),
        for (final t in tags.take(4)) _chip(t, AppTheme.textSecondary),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info banner
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Employees sign in with their Google account. The app '
              'automatically detects their role and restricts access accordingly.',
              style: TextStyle(fontSize: 12, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty & error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_outlined,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('No team members yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'Add employees and control exactly what\neach person can do in the app.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppTheme.subtext(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add First Employee'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
