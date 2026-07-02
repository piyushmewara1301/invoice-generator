import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/payment_method.dart';
import '../models/stock_transfer.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/employee_service.dart';
import '../utils/app_theme.dart';
import 'employees/owner_pairing_screen.dart';

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  List<ShopInfo>? _shops;
  List<Employee> _employees = [];
  String? _myShopId;
  String? _ownerEmail;
  bool _loading = true;
  String? _error;

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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<AppProvider>();
      await provider.registerShop();
      final myId = await provider.getOrCreateShopId();
      final others = await provider.getLinkedShops();
      final allShops = [
        ShopInfo(shopId: myId, shopName: provider.currentShopName),
        ...others,
      ];

      List<Employee> employees = [];
      final email = _ownerEmail;
      if (email != null) {
        employees = await EmployeeService.fetchEmployees(email);
      }

      if (!mounted) return;
      setState(() {
        _myShopId = myId;
        _shops = allShops;
        _employees = employees;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final activeFilter = provider.ownerShopFilter;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text('My Shops'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _CentreError(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── View filter ─────────────────────────────────────────
                    const _SectionLabel('View Filter'),
                    const SizedBox(height: 8),
                    _FilterBar(
                      shops: _shops ?? [],
                      activeFilter: activeFilter,
                      myShopId: _myShopId ?? '',
                      onChanged: provider.setOwnerShopFilter,
                    ),
                    const SizedBox(height: 24),

                    // ── Shops ───────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel('Registered Shops'),
                        TextButton.icon(
                          onPressed: _addShop,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Shop'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if ((_shops ?? []).isEmpty)
                      const _InfoCard(
                        message:
                            'No shops found. Log in with the same email on your other device — it appears here automatically.',
                      )
                    else
                      ...(_shops ?? []).map((shop) {
                        final isMine = shop.shopId == _myShopId;
                        final assigned = _employees
                            .where((e) =>
                                e.shopId == shop.shopId && e.isActive)
                            .map((e) => e.name)
                            .toList();
                        return _ShopCard(
                          shop: shop,
                          isMine: isMine,
                          assignedEmployeeNames: assigned,
                          onShareAccess: () => _shareAccess(shop),
                          onRename: () => _renameShop(shop),
                          onRemove: (!isMine && shop.lastSeen == null)
                              ? () => _removeShop(shop)
                              : null,
                          onConfigurePaymentMethods: () =>
                              _configurePaymentMethods(shop),
                        );
                      }),

                    const SizedBox(height: 24),

                    // ── Employee access ─────────────────────────────────────
                    const _SectionLabel('Employee Shop Access'),
                    const SizedBox(height: 8),
                    if (_employees.where((e) => e.isActive).isEmpty)
                      const _InfoCard(
                        message:
                            'No active employees yet. Add employees in Settings → Manage Team.',
                      )
                    else
                      ..._employees
                          .where((e) => e.isActive)
                          .map((e) => _EmployeeShopRow(
                                employee: e,
                                shops: _shops ?? [],
                                myShopId: _myShopId ?? '',
                                onGrantAllShops: () =>
                                    _toggleAllShops(e, true),
                                onRevokeAllShops: () =>
                                    _toggleAllShops(e, false),
                              )),
                  ],
                ),
    );
  }

  Future<void> _shareAccess(ShopInfo shop) async {
    final activeEmployees =
        _employees.where((e) => e.isActive).toList();
    if (activeEmployees.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Add employees first in Settings → Manage Team')));
      return;
    }

    if (!mounted) return;
    final pickedEmail = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _PickEmployeeSheet(employees: activeEmployees),
    );
    if (pickedEmail == null || !mounted) return;
    final emp =
        activeEmployees.firstWhere((e) => e.email == pickedEmail);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerPairingScreen(
          employeeName: emp.name,
          employeeEmail: emp.email,
          shopId: shop.shopId,
          shopName: shop.shopName,
        ),
      ),
    );
  }

  Future<void> _toggleAllShops(Employee emp, bool grant) async {
    final email = _ownerEmail;
    if (email == null) return;
    final updated = emp.copyWith(accessAllShops: grant);
    final err = await EmployeeService.updateEmployee(email, updated);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.error));
      return;
    }
    setState(() {
      _employees = [
        for (final e in _employees) e.id == emp.id ? updated : e
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(grant
          ? '${emp.name} can now see all shops'
          : '${emp.name} restricted to assigned shop'),
      backgroundColor: AppTheme.success,
    ));
  }

  Future<void> _addShop() async {
    final name = await _promptShopName(title: 'Add Shop / Branch');
    if (name == null || name.trim().isEmpty || !mounted) return;
    await context.read<AppProvider>().addShop(name);
    await _load();
  }

  Future<void> _renameShop(ShopInfo shop) async {
    final name = await _promptShopName(
      title: 'Rename Shop',
      initial: shop.shopName,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await context.read<AppProvider>().renameShop(shop.shopId, name);
    await _load();
  }

  Future<void> _configurePaymentMethods(ShopInfo shop) async {
    final provider = context.read<AppProvider>();
    final allMethods = provider.profile.allPaymentMethods;
    final currentIds = List<String>.from(
        provider.profile.shopPaymentMethodIds[shop.shopId] ??
            allMethods.map((m) => m.id));

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _PaymentMethodPickerDialog(
        shopName: shop.shopName,
        allMethods: allMethods,
        selectedIds: currentIds,
      ),
    );
    if (selected == null || !mounted) return;

    final isDefault = selected.length == allMethods.length &&
        allMethods.every((m) => selected.contains(m.id));
    await provider.setShopPaymentMethods(
        shop.shopId, isDefault ? [] : selected);
  }

  Future<String?> _promptShopName({required String title, String? initial}) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Shop / Branch Name',
            hintText: 'e.g. Main Branch, City Mall, Warehouse',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
      return value;
    });
  }

  Future<void> _removeShop(ShopInfo shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Shop?'),
        content: Text(
            'Remove "${shop.shopName}"? This only removes the pre-registered '
            'entry — it has no effect if a device has already claimed it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppProvider>().removeShop(shop.shopId);
    await _load();
  }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<ShopInfo> shops;
  final String? activeFilter;
  final String myShopId;
  final ValueChanged<String?> onChanged;

  const _FilterBar({
    required this.shops,
    required this.activeFilter,
    required this.myShopId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are currently viewing:',
            style:
                TextStyle(fontSize: 12, color: AppTheme.subtext(context)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All Shops',
                selected: activeFilter == null,
                onTap: () => onChanged(null),
              ),
              ...shops.map((s) => _FilterChip(
                    label: s.shopId == myShopId
                        ? '${s.shopName} (This Device)'
                        : s.shopName,
                    selected: activeFilter == s.shopId,
                    onTap: () => onChanged(s.shopId),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.primary),
        ),
      ),
    );
  }
}

// ─── Shop card ────────────────────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final ShopInfo shop;
  final bool isMine;
  final List<String> assignedEmployeeNames;
  final VoidCallback? onShareAccess;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;
  final VoidCallback? onConfigurePaymentMethods;

  const _ShopCard({
    required this.shop,
    required this.isMine,
    required this.assignedEmployeeNames,
    this.onShareAccess,
    this.onRename,
    this.onRemove,
    this.onConfigurePaymentMethods,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? AppTheme.primary.withValues(alpha: 0.4)
              : AppTheme.outline(context),
          width: isMine ? 1.4 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront,
                  size: 18,
                  color:
                      isMine ? AppTheme.primary : AppTheme.subtext(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shop.shopName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (isMine)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('This Device',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                )
              else if (shop.lastSeen == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.subtext(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Not yet active',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.subtext(context))),
                ),
              if (onRename != null || onRemove != null || onConfigurePaymentMethods != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) {
                    if (v == 'rename') onRename?.call();
                    if (v == 'remove') onRemove?.call();
                    if (v == 'payment') onConfigurePaymentMethods?.call();
                  },
                  itemBuilder: (_) => [
                    if (onConfigurePaymentMethods != null)
                      const PopupMenuItem(
                          value: 'payment',
                          child: ListTile(
                            leading: Icon(Icons.payments_outlined, size: 18),
                            title: Text('Payment Methods'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )),
                    if (onRename != null)
                      const PopupMenuItem(
                          value: 'rename', child: Text('Rename')),
                    if (onRemove != null)
                      const PopupMenuItem(
                          value: 'remove', child: Text('Remove')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (assignedEmployeeNames.isNotEmpty)
            Wrap(
              spacing: 6,
              children: assignedEmployeeNames
                  .map((n) => Chip(
                        label: Text(n,
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            )
          else
            Text('No employees assigned',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.subtext(context))),
          if (onShareAccess != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShareAccess,
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('Share Access for This Shop'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Employee shop access row ─────────────────────────────────────────────────

class _EmployeeShopRow extends StatelessWidget {
  final Employee employee;
  final List<ShopInfo> shops;
  final String myShopId;
  final VoidCallback onGrantAllShops;
  final VoidCallback onRevokeAllShops;

  const _EmployeeShopRow({
    required this.employee,
    required this.shops,
    required this.myShopId,
    required this.onGrantAllShops,
    required this.onRevokeAllShops,
  });

  @override
  Widget build(BuildContext context) {
    final allShops = employee.accessAllShops;
    final assignedShop = employee.shopId != null
        ? shops.firstWhere((s) => s.shopId == employee.shopId,
            orElse: () =>
                ShopInfo(shopId: employee.shopId!, shopName: 'Unknown Shop'))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(
              employee.name.isNotEmpty
                  ? employee.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  allShops
                      ? 'Access: All shops'
                      : assignedShop != null
                          ? 'Shop: ${assignedShop.shopName}'
                          : 'Shop: Unassigned',
                  style: TextStyle(
                      fontSize: 11,
                      color: allShops
                          ? AppTheme.success
                          : AppTheme.subtext(context)),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) {
              if (v == 'all') onGrantAllShops();
              if (v == 'restrict') onRevokeAllShops();
            },
            itemBuilder: (_) => [
              if (!allShops)
                const PopupMenuItem(
                    value: 'all',
                    child: Text('Grant all-shop access')),
              if (allShops)
                const PopupMenuItem(
                    value: 'restrict',
                    child: Text('Restrict to assigned shop')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pick employee sheet ──────────────────────────────────────────────────────

class _PickEmployeeSheet extends StatelessWidget {
  final List<Employee> employees;
  const _PickEmployeeSheet({required this.employees});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select Employee',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          ...employees.map((e) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(e.name),
                subtitle: Text(e.email,
                    style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(context, e.email),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2));
  }
}

class _InfoCard extends StatelessWidget {
  final String message;
  const _InfoCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Text(message,
          style: TextStyle(
              fontSize: 12, color: AppTheme.subtext(context))),
    );
  }
}

// ─── Payment method picker dialog ─────────────────────────────────────────────

class _PaymentMethodPickerDialog extends StatefulWidget {
  final String shopName;
  final List<PaymentMethod> allMethods;
  final List<String> selectedIds;

  const _PaymentMethodPickerDialog({
    required this.shopName,
    required this.allMethods,
    required this.selectedIds,
  });

  @override
  State<_PaymentMethodPickerDialog> createState() =>
      _PaymentMethodPickerDialogState();
}

class _PaymentMethodPickerDialogState
    extends State<_PaymentMethodPickerDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Payment Methods\n${widget.shopName}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.allMethods
              .map((m) => CheckboxListTile(
                    value: _selected.contains(m.id),
                    title: Text(m.name,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: m.subtitle.isNotEmpty
                        ? Text(m.subtitle,
                            style: const TextStyle(fontSize: 11))
                        : null,
                    dense: true,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(m.id);
                      } else if (_selected.length > 1) {
                        _selected.remove(m.id);
                      }
                    }),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            child: const Text('Save')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CentreError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _CentreError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.subtext(context))),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
