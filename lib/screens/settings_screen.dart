import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../models/business_profile.dart';
import '../models/subscription_limits.dart';
import 'settings/business_profile_screen.dart';
import 'settings/invoice_settings_screen.dart';
import 'settings/payment_methods_screen.dart';
import 'settings/services_screen.dart';
import 'settings/message_templates_screen.dart';
import 'settings/gst_setup_screen.dart';
import 'settings/reminder_settings_screen.dart';
import 'gst_report_screen.dart';
import 'settings/verification_screen.dart';
import 'employees/employees_screen.dart';
import 'businesses/businesses_screen.dart';
import '../widgets/paywall_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _refreshingVerification = false;

  Future<void> _requireFeature(LimitType feature, VoidCallback onAllowed) async {
    final info = context.read<AppProvider>().checkFeature(feature);
    if (info == null) {
      onAllowed();
      return;
    }
    final upgrade = await showPaywallSheet(context, info);
    if (upgrade && mounted) Navigator.pushNamed(context, '/plans');
  }

  Future<void> _refreshVerification() async {
    if (_refreshingVerification) return;
    setState(() => _refreshingVerification = true);
    final email = context.read<AuthService>().user?.email;
    final ok = await context
        .read<AppProvider>()
        .refreshVerificationStatus(emailOverride: email);
    if (!mounted) return;
    setState(() => _refreshingVerification = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Verification status updated.'
          : 'Could not reach server. Check your connection.'),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profile = context.watch<AppProvider>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.user != null) ...[
            _accountCard(context, auth),
            const SizedBox(height: 16),
          ],

          _subscriptionBanner(context, profile.subscriptionTier),
          const SizedBox(height: 16),
          _navGroup([
            _NavItem(
              icon: Icons.business_outlined,
              color: const Color(0xFF1565C0),
              title: 'Business Profile',
              subtitle: profile.name.isNotEmpty
                  ? profile.name
                  : 'Name, logo, address & contact',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BusinessProfileScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF00897B),
              title: 'Invoice Settings',
              subtitle: 'Template, numbering, tax & more',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InvoiceSettingsScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.account_balance_outlined,
              color: const Color(0xFFE65100),
              title: 'GST Setup',
              subtitle: _gstSubtitle(profile),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const GstSetupScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFFBF360C),
              title: 'GST Reports',
              subtitle: 'GSTR-1 style · CGST/SGST/IGST · HSN summary',
              onTap: () => openGstReport(context),
            ),
            _NavItem(
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF6A1B9A),
              title: '${profile.itemLabel}s & Services',
              subtitle: profile.serviceItems.isEmpty
                  ? 'Build your product/service catalog'
                  : '${profile.serviceItems.length} ${profile.itemLabel.toLowerCase()}${profile.serviceItems.length == 1 ? '' : 's'} saved',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ServicesScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFFBF360C),
              title: 'Payment Methods',
              subtitle: profile.paymentMethods.isEmpty
                  ? 'Bank accounts, UPI & cash'
                  : '${profile.paymentMethods.length + 1} method${profile.paymentMethods.length + 1 == 1 ? '' : 's'} configured',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PaymentMethodsScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.store_outlined,
              color: const Color(0xFF7E22CE),
              title: 'My Businesses',
              subtitle: _businessSubtitle(profile),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessesScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.group_outlined,
              color: const Color(0xFF0F766E),
              title: 'Manage Team',
              subtitle: 'Add employees & set access permissions',
              onTap: () => _requireFeature(
                LimitType.manageTeam,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmployeesScreen()),
                ),
              ),
            ),
            _NavItem(
              icon: Icons.chat_outlined,
              color: const Color(0xFF0277BD),
              title: 'Message Templates',
              subtitle: 'Customise WhatsApp & email messages',
              onTap: () => _requireFeature(
                LimitType.messageTemplates,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MessageTemplatesScreen()),
                ),
              ),
            ),
            if (!kIsWeb)
            _NavItem(
              icon: Icons.notifications_outlined,
              color: const Color(0xFF2E7D32),
              title: 'Payment Reminders',
              subtitle: _reminderSubtitle(context),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReminderSettingsScreen()),
              ),
            ),
            _NavItem(
              icon: _verificationIcon(profile.verificationStatus),
              color: _verificationColor(profile.verificationStatus),
              title: 'Business Verification',
              subtitle: _verificationSubtitle(profile.verificationStatus),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VerificationScreen()),
              ),
              trailing: _refreshingVerification
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh,
                          size: 18, color: AppTheme.textSecondary),
                      tooltip: 'Refresh verification status',
                      onPressed: _refreshVerification,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
            ),
          ]),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Invoice Generator v1.0.0',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _businessSubtitle(BusinessProfile profile) {
    final provider = context.read<AppProvider>();
    final count = provider.businesses.length;
    if (count <= 1) return 'Run multiple businesses from one account';
    return '$count businesses · tap to switch or add';
  }

  String _gstSubtitle(BusinessProfile profile) {
    if (!profile.isGstRegistered) return 'Not configured · Tap to set up GST';
    final state = profile.gstStateCode != null
        ? ' · ${profile.gstStateCode}'
        : '';
    final comp = profile.isCompositionDealer ? ' · Composition' : '';
    return 'GSTIN: ${profile.gstin}$state$comp';
  }

  String _reminderSubtitle(BuildContext context) {
    final settings = context.watch<AppProvider>().reminderSettings;
    if (!settings.enabled) return 'Reminders disabled';
    if (!settings.hasAnyTrigger) return 'No triggers configured';
    final count = settings.beforeDueDays.length +
        (settings.onDueDate ? 1 : 0) +
        settings.afterDueDays.length;
    return '$count reminder${count == 1 ? '' : 's'} per invoice · ${settings.notificationTimeLabel}';
  }

  IconData _verificationIcon(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.verified:
        return Icons.verified;
      case VerificationStatus.pending:
        return Icons.hourglass_top_outlined;
      case VerificationStatus.rejected:
        return Icons.cancel_outlined;
      case VerificationStatus.unverified:
        return Icons.shield_outlined;
    }
  }

  Color _verificationColor(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.verified:
        return const Color(0xFF2E7D32);
      case VerificationStatus.pending:
        return const Color(0xFFE65100);
      case VerificationStatus.rejected:
        return const Color(0xFFC62828);
      case VerificationStatus.unverified:
        return const Color(0xFF546E7A);
    }
  }

  String _verificationSubtitle(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.verified:
        return 'Your business is verified';
      case VerificationStatus.pending:
        return 'Review in progress';
      case VerificationStatus.rejected:
        return 'Tap to re-submit documents';
      case VerificationStatus.unverified:
        return 'Tap to get your business verified';
    }
  }

  Widget _subscriptionBanner(BuildContext context, SubscriptionTier tier) {
    const tierColors = {
      SubscriptionTier.free:    Color(0xFF546E7A),
      SubscriptionTier.lite:    Color(0xFF0288D1),
      SubscriptionTier.pro:     Color(0xFF7B1FA2),
      SubscriptionTier.premium: Color(0xFFE65100),
    };
    const tierNames = {
      SubscriptionTier.free:    'Free',
      SubscriptionTier.lite:    'Lite',
      SubscriptionTier.pro:     'Pro',
      SubscriptionTier.premium: 'Premium',
    };
    final color = tierColors[tier]!;
    final name = tierNames[tier]!;
    final price = tierPrices[tier]!;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/plans'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name Plan',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  price.yearlyRupees == 0
                      ? const Text('Free forever',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))
                      : Wrap(
                          spacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('50% OFF',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800)),
                            ),
                            Text(
                              '₹${price.yearlyRupees * 2}/yr',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Colors.white54),
                            ),
                            Text(
                              '₹${price.yearlyRupees}/yr · ₹${price.monthlyRupees}/mo',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tier == SubscriptionTier.premium ? 'Manage' : 'Upgrade',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navGroup(List<_NavItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _navTile(items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _navTile(_NavItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: 18, color: item.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(item.subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
            item.trailing ??
                const Icon(Icons.chevron_right,
                    size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context, AuthService auth) {
    final user = auth.user!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
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
                              fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName ?? 'Google User',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      Text(user.email,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_outlined,
                          size: 12, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text('Synced',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.logout,
                  color: AppTheme.error, size: 20),
              title: const Text('Sign Out',
                  style: TextStyle(color: AppTheme.error, fontSize: 14)),
              subtitle: const Text('Data stays in your Google Drive',
                  style: TextStyle(fontSize: 11)),
              onTap: () => _signOut(context, auth),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AuthService auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Your data will be removed from this device but stays safe in your Google Drive. Sign in again to restore it.'),
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
    await context.read<AppProvider>().detachDriveAndClear();
    if (!context.mounted) return;
    await auth.signOut();
  }
}

class _NavItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
}
