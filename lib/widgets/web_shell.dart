import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../providers/app_provider.dart';
import '../screens/bank_reconciliation_screen.dart';
import '../screens/bulk_generate_screen.dart';
import '../screens/time_tracking_screen.dart';
import '../screens/client_list_screen.dart';
import '../screens/client_segmentation_screen.dart';
import '../screens/recurring_invoices_screen.dart';
import '../screens/create_invoice_screen.dart';
import '../screens/web_dashboard_screen.dart';
import '../screens/gst_report_screen.dart';
import '../screens/invoice_list_screen.dart';
import '../screens/settings_screen.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/sync_status_badge.dart';
import '../screens/daily_sales_screen.dart';
import '../screens/inventory_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Breakpoints
// ─────────────────────────────────────────────────────────────────────────────
const double _kDesktop = 1100; // full sidebar
const double _kTablet = 600;   // icon rail; below = drawer

// ─────────────────────────────────────────────────────────────────────────────
// WebShell — responsive root layout: sidebar + content.
//   ≥ 1100 px  → full 256 px sidebar (default expanded)
//   600–1099   → 72 px icon rail (default collapsed)
//   < 600      → top bar + drawer
// ─────────────────────────────────────────────────────────────────────────────

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _selectedIndex = 0;
  bool? _expandedOverride; // null = auto from width
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _invoiceScreens = [
    WebDashboardHome(),
    InvoiceListScreen(),
    ClientListScreen(),
    ClientSegmentationScreen(),
    GstReportScreen(),
    BankReconciliationScreen(),
    RecurringInvoicesScreen(),
    TimeTrackingScreen(),
    BulkGenerateScreen(),
    SettingsScreen(),
  ];

  static const _stockScreens = [
    WebDashboardHome(),
    DailySalesScreen(),
    InventoryScreen(),
    SettingsScreen(),
  ];

  Future<void> _createInvoice() async {
    final provider = context.read<AppProvider>();
    final limit = provider.checkInvoiceLimit();
    if (limit != null) {
      if (!mounted) return;
      final upgrade = await showPaywallSheet(context, limit);
      if (upgrade && mounted) Navigator.pushNamed(context, '/plans');
      return;
    }
    if (!mounted) return;
    final invoice = provider.buildNewInvoice();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: invoice)),
    );
  }

  bool _isSidebarExpanded(double width) =>
      _expandedOverride ?? (width >= _kDesktop);

  void _toggleSidebar() {
    final w = MediaQuery.sizeOf(context).width;
    setState(() => _expandedOverride = !_isSidebarExpanded(w));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.profile;
    final isStockMode = profile.businessMode == BusinessMode.stockBased;
    final activeScreens =
        isStockMode ? _stockScreens : _invoiceScreens;

    final width = MediaQuery.sizeOf(context).width;
    final bool useDrawer = width < _kTablet;
    final bool expanded = _isSidebarExpanded(width);

    // Clamp so toggling mode doesn't leave an out-of-range index.
    final safeIndex = _selectedIndex.clamp(0, activeScreens.length - 1);

    void selectIndex(int i) {
      setState(() => _selectedIndex = i);
      if (useDrawer) _scaffoldKey.currentState?.closeDrawer();
    }

    final sidebar = _WebSidebar(
      selectedIndex: safeIndex,
      onIndexChanged: selectIndex,
      onNewInvoice: isStockMode ? null : _createInvoice,
      profile: profile,
      compact: !expanded,
      onToggle: _toggleSidebar,
      isStockMode: isStockMode,
    );

    final screens = _TabTransition(
      index: safeIndex,
      screens: activeScreens,
    );

    if (useDrawer) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: _MobileTopBar(
          onMenu: () => _scaffoldKey.currentState?.openDrawer(),
          selectedIndex: safeIndex,
          onNewInvoice: isStockMode ? null : _createInvoice,
          isStockMode: isStockMode,
        ),
        drawer: Drawer(
          width: 280,
          child: SafeArea(child: sidebar),
        ),
        body: screens,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Container(width: 1, color: AppTheme.divider),
          Expanded(child: screens),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile top bar  (width < 600 px)
// ─────────────────────────────────────────────────────────────────────────────

class _MobileTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenu;
  final int selectedIndex;
  final VoidCallback? onNewInvoice;
  final bool isStockMode;

  const _MobileTopBar({
    required this.onMenu,
    required this.selectedIndex,
    required this.onNewInvoice,
    this.isStockMode = false,
  });

  static const _invoiceTitles = [
    'Dashboard',
    'Invoices',
    'Clients',
    'Segments',
    'GST Reports',
    'Bank Recon',
    'Recurring',
    'Time Tracking',
    'Bulk Generate',
    'Settings',
  ];

  static const _stockTitles = [
    'Dashboard',
    'Daily Sales',
    'Stock',
    'Settings',
  ];

  @override
  Size get preferredSize => const Size.fromHeight(57);

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          color: AppTheme.card(context),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: isDark ? Colors.white70 : AppTheme.textPrimary,
                ),
                onPressed: onMenu,
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Center(
                  child: Text(
                    'BB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                (isStockMode ? _stockTitles : _invoiceTitles)[selectedIndex],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (onNewInvoice != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: onNewInvoice,
                  tooltip: 'New Invoice',
                  color: AppTheme.primary,
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        Container(height: 1, color: AppTheme.divider),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback? onNewInvoice;
  final BusinessProfile profile;
  final bool compact;
  final VoidCallback onToggle;
  final bool isStockMode;

  const _WebSidebar({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onNewInvoice,
    required this.profile,
    required this.compact,
    required this.onToggle,
    this.isStockMode = false,
  });

  static const _invoiceNavItems = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices'),
    (Icons.people_outline, Icons.people, 'Clients'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Segments'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'GST Reports'),
    (Icons.account_balance_outlined, Icons.account_balance, 'Bank Recon'),
    (Icons.repeat_outlined, Icons.repeat, 'Recurring'),
    (Icons.timer_outlined, Icons.timer, 'Time Tracking'),
    (Icons.bolt_outlined, Icons.bolt, 'Bulk Generate'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  static const _stockNavItems = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.storefront_outlined, Icons.storefront, 'Daily Sales'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Stock'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final navItems = isStockMode ? _stockNavItems : _invoiceNavItems;

    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: compact ? 72.0 : 256.0,
        color: AppTheme.card(context),
        child: Column(
          children: [
            _SidebarHeader(profile: profile, compact: compact),
            Divider(height: 1, color: AppTheme.outline(context)),
            const SizedBox(height: 8),

            // New Invoice button (invoice mode only)
            if (onNewInvoice != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 14,
                  vertical: 4,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: compact
                      ? Tooltip(
                          message: 'New Invoice',
                          preferBelow: false,
                          child: ElevatedButton(
                            onPressed: onNewInvoice,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Icon(Icons.add, size: 20),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: onNewInvoice,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Invoice'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Nav items
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: 4,
                ),
                itemCount: navItems.length,
                itemBuilder: (_, i) {
                  final item = navItems[i];
                  final selected = selectedIndex == i;
                  return _NavTile(
                    icon: selected ? item.$2 : item.$1,
                    label: item.$3,
                    selected: selected,
                    onTap: () => onIndexChanged(i),
                    compact: compact,
                  );
                },
              ),
            ),

            // Collapse / expand toggle
            _CollapseToggle(compact: compact, onToggle: onToggle),

            Divider(height: 1, color: AppTheme.outline(context)),
            _SidebarFooter(profile: profile, compact: compact),
          ],
        ),
      ),
    );
  }
}

// ── Collapse toggle ────────────────────────────────────────────────────────────

class _CollapseToggle extends StatelessWidget {
  final bool compact;
  final VoidCallback onToggle;

  const _CollapseToggle({required this.compact, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: compact ? 'Expand sidebar' : 'Collapse sidebar',
      preferBelow: false,
      child: InkWell(
        onTap: onToggle,
        hoverColor: AppTheme.primary.withValues(alpha: 0.05),
        child: SizedBox(
          height: 40,
          child: Align(
            alignment: compact ? Alignment.center : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: compact ? 0 : 14),
              child: Icon(
                compact
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sidebar header ─────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final BusinessProfile profile;
  final bool compact;

  const _SidebarHeader({required this.profile, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final logoBox = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'BB',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
        child: Center(child: logoBox),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          logoBox,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BillBook',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (profile.name.isNotEmpty)
                  Text(
                    profile.name,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav tile ───────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = selected
        ? AppTheme.primary.withValues(alpha: 0.09)
        : Colors.transparent;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Tooltip(
          message: label,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 400),
          child: Material(
            color: tileColor,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(9),
              hoverColor: AppTheme.primary.withValues(alpha: 0.05),
              splashColor: AppTheme.primary.withValues(alpha: 0.1),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Icon(
                    icon,
                    size: 22,
                    color:
                        selected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          hoverColor: AppTheme.primary.withValues(alpha: 0.05),
          splashColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      selected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        selected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sidebar footer ─────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  final BusinessProfile profile;
  final bool compact;

  const _SidebarFooter({required this.profile, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;

    if (user == null) return const SizedBox.shrink();

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
      backgroundImage:
          user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
      child: user.photoUrl == null
          ? Text(
              user.displayName?.isNotEmpty == true
                  ? user.displayName![0].toUpperCase()
                  : 'G',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            )
          : null,
    );

    if (compact) {
      final provider = context.watch<AppProvider>();
      Color? dotColor;
      if (provider.hasDrive) {
        dotColor = provider.syncing || provider.pendingUpload
            ? AppTheme.warning
            : null;
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Tooltip(
            message: 'Sign out',
            child: GestureDetector(
              onTap: () => _confirmSignOut(context, auth),
              child: dotColor == null
                  ? avatar
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        avatar,
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.surface, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout,
                      size: 16, color: AppTheme.textSecondary),
                  tooltip: 'Sign out',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => _confirmSignOut(context, auth),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const SyncStatusBadge(),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmSignOut(
      BuildContext context, AuthService auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Your data stays safe in Google Drive. Sign in again anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final appProvider = context.read<AppProvider>();
    await Future.wait([
      auth.signOut(),
      appProvider.detachDriveAndClear(),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab transition — fade + micro-slide on every tab switch.
// Wraps IndexedStack so all tab states are preserved.
// ─────────────────────────────────────────────────────────────────────────────

class _TabTransition extends StatefulWidget {
  final int index;
  final List<Widget> screens;

  const _TabTransition({required this.index, required this.screens});

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.index;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..value = 1.0; // start fully visible

    final curved =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _opacity = curved;
    _position = Tween<Offset>(
      begin: const Offset(0, 0.018),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didUpdateWidget(_TabTransition old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _activeIndex = widget.index;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: IndexedStack(
          index: _activeIndex,
          children: widget.screens,
        ),
      ),
    );
  }
}
