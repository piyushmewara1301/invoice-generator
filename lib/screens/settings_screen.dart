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
import 'employees/scan_pairing_screen.dart';
import '../models/employee.dart';
import '../providers/locale_provider.dart';
import '../widgets/paywall_sheet.dart';
import '../l10n/app_localizations.dart';

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
    final appProvider = context.watch<AppProvider>();
    final profile = appProvider.profile;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
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
            if (!kIsWeb)
              _NavItem(
                icon: appProvider.isEmployeeMode
                    ? Icons.link
                    : Icons.qr_code_scanner,
                color: const Color(0xFF0369A1),
                title: 'Connect to Business',
                subtitle: appProvider.isEmployeeMode
                    ? 'Connected · ${appProvider.activePairing!.ownerEmail}'
                    : 'Scan a QR code from your employer',
                onTap: appProvider.isEmployeeMode
                    ? _disconnectFromBusiness
                    : _connectToBusiness,
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
              icon: Icons.point_of_sale_rounded,
              color: const Color(0xFF0F766E),
              title: 'Point of Sale',
              subtitle: profile.posEnabled
                  ? 'Enabled · Quick billing from catalog'
                  : 'Disabled · Tap to enable quick billing',
              onTap: () => _togglePos(context, profile),
              trailing: Switch(
                value: profile.posEnabled,
                onChanged: (_) => _togglePos(context, profile),
                activeThumbColor: AppTheme.primary,
              ),
            ),
            _NavItem(
              icon: Icons.language_outlined,
              color: const Color(0xFF6A1B9A),
              title: AppLocalizations.of(context)!.language,
              subtitle: LocaleProvider.localeNames[
                  context.watch<LocaleProvider>().locale.languageCode] ??
                  'English',
              onTap: () => _showLanguagePicker(context),
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

          // Employee mode: active connection banner
          if (appProvider.isEmployeeMode) ...[
            const SizedBox(height: 16),
            _EmployeeModeBanner(
              pairing: appProvider.activePairing!,
              onDisconnect: _disconnectFromBusiness,
            ),
          ],

          // Team membership: user is also an employee of another business
          if (appProvider.isAlsoEmployee) ...[
            const SizedBox(height: 16),
            _TeamMembershipCard(
              ownerEmail: appProvider.employeeOwnerEmail!,
              employee: appProvider.employeeRecord,
              isConnected: appProvider.isEmployeeMode,
              onConnect: _connectToBusiness,
              onDisconnect: _disconnectFromBusiness,
            ),
          ],

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

  Future<void> _connectToBusiness() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPairingScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Now viewing the business data. Tap Disconnect to switch back.'),
      ));
    }
  }

  Future<void> _disconnectFromBusiness() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text(
            'You will stop viewing the business data and return to your own account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppProvider>().disconnectPairing();
    }
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

  void _togglePos(BuildContext context, BusinessProfile profile) {
    final updated = BusinessProfile(
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      address: profile.address,
      city: profile.city,
      state: profile.state,
      country: profile.country,
      postalCode: profile.postalCode,
      gstin: profile.gstin,
      website: profile.website,
      currency: profile.currency,
      invoicePrefix: profile.invoicePrefix,
      nextInvoiceNumber: profile.nextInvoiceNumber,
      logoBase64: profile.logoBase64,
      headerFields: profile.headerFields,
      defaultTemplate: profile.defaultTemplate,
      themeColorHex: profile.themeColorHex,
      defaultTaxPercent: profile.defaultTaxPercent,
      showQuantity: profile.showQuantity,
      itemLabel: profile.itemLabel,
      paymentMethods: profile.paymentMethods,
      serviceItems: profile.serviceItems,
      verificationStatus: profile.verificationStatus,
      verificationNotes: profile.verificationNotes,
      verificationSubmittedAt: profile.verificationSubmittedAt,
      subscriptionTier: profile.subscriptionTier,
      subscriptionExpiryDate: profile.subscriptionExpiryDate,
      subscriptionLastCheckedDate: profile.subscriptionLastCheckedDate,
      signatureBase64: profile.signatureBase64,
      showPaymentDetailsOnInvoice: profile.showPaymentDetailsOnInvoice,
      defaultPlaceOfSupply: profile.defaultPlaceOfSupply,
      defaultReverseCharge: profile.defaultReverseCharge,
      isCompositionDealer: profile.isCompositionDealer,
      showThankYouMessage: profile.showThankYouMessage,
      thankYouMessage: profile.thankYouMessage,
      showClientAcknowledgment: profile.showClientAcknowledgment,
      posEnabled: !profile.posEnabled,
    );
    context.read<AppProvider>().updateProfile(updated);
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _LanguagePickerSheet(
        currentLocale: context.read<LocaleProvider>().locale,
        onSelect: (locale) {
          context.read<LocaleProvider>().setLocale(locale);
          Navigator.pop(ctx);
        },
      ),
    );
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

// ── Employee mode active banner ───────────────────────────────────────────────

class _EmployeeModeBanner extends StatelessWidget {
  final dynamic pairing; // EmployeePairing
  final VoidCallback onDisconnect;

  const _EmployeeModeBanner({
    required this.pairing,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0369A1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync_alt, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Viewing business data',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
                const SizedBox(height: 2),
                Text(
                  pairing.ownerEmail as String,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onDisconnect,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Language picker sheet ─────────────────────────────────────────────────────

class _LanguagePickerSheet extends StatelessWidget {
  final Locale currentLocale;
  final void Function(Locale) onSelect;

  const _LanguagePickerSheet({
    required this.currentLocale,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                AppLocalizations.of(context)!.selectLanguage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            ...LocaleProvider.localeNames.entries.map((entry) {
              final isSelected = currentLocale.languageCode == entry.key;
              return ListTile(
                title: Text(entry.value),
                leading: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppTheme.primary)
                    : const Icon(Icons.radio_button_unchecked_rounded,
                        color: AppTheme.textSecondary),
                onTap: () => onSelect(Locale(entry.key)),            
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Team membership card ──────────────────────────────────────────────────────

class _TeamMembershipCard extends StatelessWidget {
  final String ownerEmail;
  final Employee? employee;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _TeamMembershipCard({
    required this.ownerEmail,
    required this.employee,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0F766E);

    final roleName = employee?.role.displayName ?? 'Team Member';
    final isActive = employee?.isActive ?? true;
    final perms = employee?.effectivePermissions ?? const <AppPermission>{};

    // Show up to 4 permission labels
    final permLabels = perms.take(4).map((p) => p.displayName).toList();

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.badge_outlined, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Team Membership',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFF16A34A)
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You are a $roleName at another business.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            ownerEmail,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
          if (permLabels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: permLabels
                  .map((l) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l,
                            style: const TextStyle(
                                fontSize: 10, color: accent)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: isConnected
                ? OutlinedButton.icon(
                    onPressed: onDisconnect,
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text('Disconnect from business',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.5)),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Connect — Scan QR',
                        style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
