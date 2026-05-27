import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../providers/app_provider.dart';
import '../screens/client_list_screen.dart';
import '../screens/create_invoice_screen.dart';
import '../screens/web_dashboard_screen.dart';
import '../screens/gst_report_screen.dart';
import '../screens/invoice_list_screen.dart';
import '../screens/settings_screen.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/paywall_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WebShell — root layout for web: left sidebar + content area.
// Shown for all authenticated web users; premium gating is inside the screens.
// ─────────────────────────────────────────────────────────────────────────────

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    WebDashboardHome(),
    InvoiceListScreen(),
    ClientListScreen(),
    GstReportScreen(),
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

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Row(
        children: [
          _WebSidebar(
            selectedIndex: _selectedIndex,
            onIndexChanged: (i) => setState(() => _selectedIndex = i),
            onNewInvoice: _createInvoice,
            profile: profile,
          ),
          Container(width: 1, color: AppTheme.divider),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onNewInvoice;
  final BusinessProfile profile;

  const _WebSidebar({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onNewInvoice,
    required this.profile,
  });

  static const _navItems = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices'),
    (Icons.people_outline, Icons.people, 'Clients'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'GST Reports'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      color: Colors.white,
      child: Column(
        children: [
          _SidebarHeader(profile: profile),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // New Invoice CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
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

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (_, i) {
                final item = _navItems[i];
                final selected = selectedIndex == i;
                return _NavTile(
                  icon: selected ? item.$2 : item.$1,
                  label: item.$3,
                  selected: selected,
                  onTap: () => onIndexChanged(i),
                );
              },
            ),
          ),

          const Divider(height: 1),
          _SidebarFooter(profile: profile),
        ],
      ),
    );
  }
}

// ── Sidebar header ────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final BusinessProfile profile;
  const _SidebarHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          Container(
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
          ),
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

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.09)
            : Colors.transparent,
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
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.textPrimary,
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

// ── Sidebar footer ────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  final BusinessProfile profile;
  const _SidebarFooter({required this.profile});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: user == null
          ? const SizedBox.shrink()
          : Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.15),
                    backgroundImage: user.photoUrl != null
                        ? NetworkImage(user.photoUrl!)
                        : null,
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
                  ),
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
                              fontSize: 10,
                              color: AppTheme.textSecondary),
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
            ),
    );
  }

  Future<void> _confirmSignOut(
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
    // Capture provider before any async call — context will be unmounted
    // as soon as signOut() fires notifyListeners() and _AuthGate rebuilds.
    final appProvider = context.read<AppProvider>();
    await Future.wait([
      auth.signOut(),
      appProvider.detachDriveAndClear(),
    ]);
  }
}
