import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/sync_status_badge.dart';
import '../models/business_profile.dart';
import '../models/subscription_limits.dart';
import 'settings/business_profile_screen.dart';
import 'settings/invoice_settings_screen.dart';
import 'settings/payment_methods_screen.dart';
import 'settings/printer_settings_screen.dart';
import 'settings/services_screen.dart';
import 'settings/message_templates_screen.dart';
import 'settings/gst_setup_screen.dart';
import 'settings/reminder_settings_screen.dart';
import 'approval_inbox_screen.dart';
import 'late_fee_settings_screen.dart';
import 'gst_report_screen.dart';
import 'pl_report_screen.dart';
import 'agewise_report_screen.dart';
import 'data_health_screen.dart';
import 'recurring_invoices_screen.dart';
import 'settings/verification_screen.dart';
import 'employees/employees_screen.dart';
import 'employees/scan_pairing_screen.dart';
import '../models/employee.dart';
import '../providers/locale_provider.dart';
import '../widgets/paywall_sheet.dart';
import '../l10n/app_localizations.dart';
import 'inventory_screen.dart';
import 'cash_book_screen.dart';
import 'bank_reconciliation_screen.dart';
import 'purchase_bill_list_screen.dart';
import 'stock_transfer_screen.dart';
import 'ledger_screen.dart';
import 'shop_management_screen.dart';
import 'delivery_challan_screen.dart';
import 'einvoice_screen.dart';
import 'eway_bill_screen.dart';
import '../services/review_service.dart';

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
    final activePairing = appProvider.activePairing;
    final ownerEmail = appProvider.employeeOwnerEmail;
    final isInvoiceMode = profile.businessMode == BusinessMode.invoiceBased;
    final isStockMode = profile.businessMode == BusinessMode.stockBased;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.user != null) ...[
            _accountCard(context, auth, profile.verificationStatus),
            const SizedBox(height: 16),
          ],

          _subscriptionBanner(context, profile.subscriptionTier),
          const SizedBox(height: 16),

          // ── Business Mode selector ────────────────────────────────────────
          // Employees see a locked read-only indicator; only the owner can change mode.
          _BusinessModeCard(
            current: profile.businessMode,
            locked: appProvider.isEmployeeMode,
            onChanged: appProvider.isEmployeeMode
                ? null
                : (mode) async {
                    await appProvider.updateProfile(
                        profile.copyWith(businessMode: mode));
                  },
          ),
          const SizedBox(height: 16),

          // ── Daily tools moved off the bottom bar ───────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Daily Tools',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.subtext(context),
                letterSpacing: 0.3,
              ),
            ),
          ),
          _navGroup([
            _NavItem(
              icon: Icons.menu_book_outlined,
              color: const Color(0xFF7C3AED),
              title: 'Cash Book',
              subtitle: 'Daily cash in/out & running balance',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CashBookScreen())),
            ),
            _NavItem(
              icon: Icons.account_balance_outlined,
              color: const Color(0xFF0369A1),
              title: 'Bank Reconciliation',
              subtitle: 'Match your bank statement with your records',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BankReconciliationScreen()),
              ),
            ),
            if (isInvoiceMode && profile.purchaseBillEnabled)
            _NavItem(
              icon: Icons.receipt_outlined,
              color: const Color(0xFF7C3AED),
              title: 'View Purchase Bills',
              subtitle: 'Vendor bills & input tax credit',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PurchaseBillListScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          _navGroup([
            if (appProvider.canDo(AppPermission.editBusinessProfile))
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
            if (appProvider.canDo(AppPermission.editBusinessProfile) &&
                isInvoiceMode)
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
            if (appProvider.canDo(AppPermission.editBusinessProfile) &&
                isInvoiceMode)
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
            if (appProvider.canDo(AppPermission.viewReports) &&
                profile.isGstRegistered &&
                isInvoiceMode)
            _NavItem(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFFBF360C),
              title: 'GST Reports',
              subtitle: 'GSTR-1 style · CGST/SGST/IGST · HSN summary',
              onTap: () => openGstReport(context),
            ),
            if (appProvider.canDo(AppPermission.viewReports))
            _NavItem(
              icon: Icons.show_chart_rounded,
              color: const Color(0xFF7C3AED),
              title: 'P & L Report',
              subtitle: 'Revenue vs expenses · net profit by period',
              onTap: () => _requireFeature(
                LimitType.reports,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PLReportScreen())),
              ),
            ),
            if (appProvider.canDo(AppPermission.viewReports) && isInvoiceMode)
            _NavItem(
              icon: Icons.hourglass_bottom_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Outstanding Analysis',
              subtitle: 'Age-wise overdue invoice buckets',
              onTap: () => _requireFeature(
                LimitType.reports,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AgewiseReportScreen())),
              ),
            ),
            if (appProvider.canDo(AppPermission.viewReports))
            _NavItem(
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF0D9488),
              title: 'Data Health',
              subtitle: 'Missing prices, low stock & other issues to fix',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DataHealthScreen())),
            ),
            if (appProvider.canDo(AppPermission.createInvoice) && isInvoiceMode)
            _NavItem(
              icon: Icons.repeat_rounded,
              color: const Color(0xFF059669),
              title: 'Recurring Invoices',
              subtitle: 'Auto-generate invoices on a schedule',
              onTap: () => _requireFeature(
                LimitType.recurringInvoices,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RecurringInvoicesScreen())),
              ),
            ),
            if (isInvoiceMode)
            _NavItem(
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFF0D9488),
              title: 'Delivery Challans',
              subtitle: () {
                final count = appProvider.invoices
                    .where((i) => i.isDeliveryChallan)
                    .length;
                return count == 0
                    ? 'Track goods dispatched before invoicing'
                    : '$count challan${count == 1 ? '' : 's'}';
              }(),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DeliveryChallanScreen())),
            ),
            if (isInvoiceMode)
            _NavItem(
              icon: Icons.qr_code_2_outlined,
              color: const Color(0xFF0369A1),
              title: 'E-Invoice (IRP / IRN)',
              subtitle: () {
                final done = appProvider.invoices.where((i) => i.irn != null).length;
                return done == 0
                    ? 'Generate IRN & signed QR via IRP portal'
                    : '$done invoice${done == 1 ? '' : 's'} registered on IRP';
              }(),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EInvoiceScreen())),
            ),
            if (isInvoiceMode)
            _NavItem(
              icon: Icons.add_road_outlined,
              color: const Color(0xFF7C3AED),
              title: 'E-Way Bills',
              subtitle: () {
                final done = appProvider.invoices
                    .where((i) => i.ewayBillNo != null).length;
                final expired = appProvider.invoices
                    .where((i) =>
                        i.ewayBillNo != null &&
                        i.ewayBillValidTill != null &&
                        i.ewayBillValidTill!.isBefore(DateTime.now()))
                    .length;
                if (done == 0) return 'Track goods movement for invoices ≥ ₹50,000';
                if (expired > 0) return '$done bill${done == 1 ? '' : 's'} · $expired expired';
                return '$done e-way bill${done == 1 ? '' : 's'} active';
              }(),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EWayBillScreen())),
            ),
            if (appProvider.canDo(AppPermission.manageItems))
            _NavItem(
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF6A1B9A),
              title: '${profile.itemLabel}s & Services',
              subtitle: appProvider.serviceItems.isEmpty
                  ? 'Build your product/service catalog'
                  : '${appProvider.serviceItems.length} ${profile.itemLabel.toLowerCase()}${appProvider.serviceItems.length == 1 ? '' : 's'} saved',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesScreen()),
              ),
            ),
            if (appProvider.canDo(AppPermission.manageItems) &&
                appProvider.serviceItems.any((s) => s.isTrackingStock))
            _NavItem(
              icon: Icons.warehouse_outlined,
              color: const Color(0xFF0E7490),
              title: 'Inventory',
              subtitle: () {
                final tracked =
                    appProvider.serviceItems.where((s) => s.isTrackingStock).length;
                final low =
                    appProvider.serviceItems.where((s) => s.isLowStock).length;
                return low > 0
                    ? '$tracked tracked · $low low stock'
                    : '$tracked item${tracked == 1 ? '' : 's'} tracked';
              }(),
              onTap: () => _requireFeature(
                LimitType.inventory,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InventoryScreen())),
              ),
            ),
            if (!appProvider.isEmployeeMode)
            _NavItem(
              icon: Icons.storefront_outlined,
              color: const Color(0xFF059669),
              title: 'This Shop\'s Name',
              subtitle: appProvider.currentShopName,
              onTap: () => _editShopName(context),
            ),
            _NavItem(
              icon: Icons.store_outlined,
              color: const Color(0xFF059669),
              title: 'My Shops',
              subtitle: 'Manage shops, view filters & employee access',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ShopManagementScreen())),
            ),
            if (isStockMode)
            _NavItem(
              icon: Icons.swap_horiz_rounded,
              color: const Color(0xFF0891B2),
              title: 'Stock Transfers',
              subtitle: 'Send & receive stock between your shops',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const StockTransferScreen())),
            ),
            _NavItem(
              icon: Icons.menu_book_outlined,
              color: const Color(0xFF7C3AED),
              title: 'Ledger',
              subtitle: 'Party-wise account statements & balances',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LedgerScreen())),
            ),
            if (appProvider.canDo(AppPermission.managePaymentMethods))
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
            if (appProvider.canDo(AppPermission.manageEmployees))
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
                icon: activePairing != null
                    ? Icons.link
                    : Icons.qr_code_scanner,
                color: const Color(0xFF0369A1),
                title: 'Connect to Business',
                subtitle: activePairing != null
                    ? 'Connected · ${activePairing.ownerEmail}'
                    : 'Scan a QR code from your employer',
                onTap: activePairing != null
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
            if (!kIsWeb && isInvoiceMode)
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
            if (!kIsWeb)
            _NavItem(
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFF59E0B),
              title: 'Low Stock Alerts',
              subtitle: profile.lowStockAlertsEnabled
                  ? 'Enabled · Notified when items fall below threshold'
                  : 'Disabled · No alerts for low inventory',
              onTap: () => _toggleLowStockAlerts(context, profile),
              trailing: Switch(
                value: profile.lowStockAlertsEnabled,
                onChanged: (_) => _toggleLowStockAlerts(context, profile),
                activeThumbColor: const Color(0xFFF59E0B),
              ),
            ),
            if (!kIsWeb)
            _NavItem(
              icon: Icons.print_outlined,
              color: const Color(0xFF0F766E),
              title: 'Printer Settings',
              subtitle: 'Connect a Bluetooth thermal receipt printer',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.timer_outlined,
              color: AppTheme.error,
              title: 'Late Payment Penalty',
              subtitle: profile.lateFeeEnabled
                  ? '${profile.lateFeePercent.toStringAsFixed(profile.lateFeePercent % 1 == 0 ? 0 : 1)}%/month · Grace ${profile.gracePeriodDays == 0 ? 'none' : '${profile.gracePeriodDays}d'}'
                  : 'Disabled · Enable to auto-calculate interest',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LateFeeSettingsScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF0891B2),
              title: 'Default Credit Limit',
              subtitle: profile.defaultCreditLimit != null
                  ? '${Fmt.currencySymbol(profile.currency)}${Fmt.compact(profile.defaultCreditLimit!)} applied to all clients without an individual limit'
                  : 'Not set · Tap to apply a limit to all clients',
              onTap: () => _editDefaultCreditLimit(context, profile),
            ),
            if (isInvoiceMode)
            _NavItem(
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF7C3AED),
              title: 'Invoice Approval Workflow',
              subtitle: profile.approvalWorkflowEnabled
                  ? 'Enabled · Invoices need manager approval before sending'
                  : 'Disabled · Invoices can be sent directly',
              onTap: () => _toggleApprovalWorkflow(context, profile),
              trailing: Switch(
                value: profile.approvalWorkflowEnabled,
                onChanged: (_) => _toggleApprovalWorkflow(context, profile),
                activeThumbColor: const Color(0xFF7C3AED),
              ),
            ),
            if (profile.approvalWorkflowEnabled && isInvoiceMode)
            _NavItem(
              icon: Icons.inbox_outlined,
              color: const Color(0xFF7C3AED),
              title: 'Approval Inbox',
              subtitle: () {
                final count = appProvider.pendingApprovalInvoices.length;
                return count == 0
                    ? 'No invoices pending approval'
                    : '$count invoice${count == 1 ? '' : 's'} awaiting review';
              }(),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApprovalInboxScreen()),
              ),
            ),
            if (!appProvider.isEmployeeMode)
            _NavItem(
              icon: Icons.price_change_outlined,
              color: const Color(0xFF7C3AED),
              title: 'Employee Price Changes',
              subtitle: profile.allowEmployeePriceChange
                  ? 'Allowed · Employees can edit item prices'
                  : 'Locked · Employees cannot change item prices',
              onTap: () => _toggleEmployeePriceChange(context, profile),
              trailing: Switch(
                value: profile.allowEmployeePriceChange,
                onChanged: (_) => _toggleEmployeePriceChange(context, profile),
                activeThumbColor: const Color(0xFF7C3AED),
              ),
            ),
            if (isStockMode && !appProvider.isEmployeeMode)
            _NavItem(
              icon: Icons.history_outlined,
              color: const Color(0xFF0891B2),
              title: 'Employee Daily Sales History',
              subtitle: profile.employeeDailySalesVisibilityDays == null
                  ? 'Employees can view all past entries'
                  : 'Employees can view the last '
                      '${profile.employeeDailySalesVisibilityDays} day'
                      '${profile.employeeDailySalesVisibilityDays == 1 ? '' : 's'}',
              onTap: () => _editDailySalesVisibility(context, profile),
            ),
            _NavItem(
              icon: Icons.receipt_outlined,
              color: const Color(0xFF7C3AED),
              title: 'Purchase Bills',
              subtitle: profile.purchaseBillEnabled
                  ? 'Enabled · Track vendor bills & ITC'
                  : 'Disabled · Enable to track vendor purchases',
              onTap: () => _togglePurchaseBill(context, profile),
              trailing: Switch(
                value: profile.purchaseBillEnabled,
                onChanged: (_) => _togglePurchaseBill(context, profile),
                activeThumbColor: AppTheme.primary,
              ),
            ),
            if (appProvider.canDo(AppPermission.manageItems))
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
            // Language and appearance — always visible (personal preferences).
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
              icon: context.watch<ThemeProvider>().isDark
                  ? Icons.dark_mode
                  : Icons.light_mode_outlined,
              color: const Color(0xFF334155),
              title: 'Appearance',
              subtitle: context.watch<ThemeProvider>().isDark
                  ? 'Dark mode · tap to switch to light'
                  : 'Light mode · tap to switch to dark',
              onTap: () => context.read<ThemeProvider>().toggle(),
              trailing: Switch(
                value: context.watch<ThemeProvider>().isDark,
                onChanged: (_) => context.read<ThemeProvider>().toggle(),
                activeThumbColor: const Color(0xFF334155),
              ),
            ),
            if (appProvider.canDo(AppPermission.editBusinessProfile))
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
                  : profile.verificationStatus == VerificationStatus.verified
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 12, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 4),
                                  Text('Verified',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh,
                                  size: 16, color: AppTheme.subtext(context)),
                              tooltip: 'Refresh verification status',
                              onPressed: _refreshVerification,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        )
                      : IconButton(
                          icon: Icon(Icons.refresh,
                              size: 18, color: AppTheme.subtext(context)),
                          tooltip: 'Refresh verification status',
                          onPressed: _refreshVerification,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
            ),
            _NavItem(
              icon: Icons.star_outline_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Rate Us on the Store',
              subtitle: 'Enjoying the app? Leave us a review',
              onTap: () => ReviewService.openStoreListing(),
            ),
          ]),

          // Employee mode: active connection banner
          if (activePairing != null) ...[
            const SizedBox(height: 16),
            _EmployeeModeBanner(
              pairing: activePairing,
              onDisconnect: _disconnectFromBusiness,
            ),
          ],

          // Team membership: user is also an employee of another business
          if (appProvider.isAlsoEmployee && ownerEmail != null) ...[
            const SizedBox(height: 16),
            _TeamMembershipCard(
              ownerEmail: ownerEmail,
              employee: appProvider.employeeRecord,
              isConnected: activePairing != null,
              onConnect: _connectToBusiness,
              onDisconnect: _disconnectFromBusiness,
            ),
          ],

          SizedBox(height: 32),
          Center(
            child: Builder(
              builder: (ctx) => Text(
                'Invoice Generator v1.0.0',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtext(ctx).withValues(alpha: 0.7)),
              ),
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
      SubscriptionTier.free:       Color(0xFF546E7A),
      SubscriptionTier.lite:       Color(0xFF0288D1),
      SubscriptionTier.pro:        Color(0xFF7B1FA2),
      SubscriptionTier.premium:    Color(0xFFE65100),
      SubscriptionTier.enterprise: Color(0xFF4338CA),
    };
    const tierNames = {
      SubscriptionTier.free:       'Free',
      SubscriptionTier.lite:       'Lite',
      SubscriptionTier.pro:        'Pro',
      SubscriptionTier.premium:    'Premium',
      SubscriptionTier.enterprise: 'Enterprise',
    };
    final color = tierColors[tier] ?? const Color(0xFF546E7A);
    final name  = tierNames[tier]  ?? tier.name;
    final price = tierPrices[tier] ?? tierPrices[SubscriptionTier.free]!;

    final canBill = context.read<AppProvider>().canDo(AppPermission.manageBilling);
    return GestureDetector(
      onTap: canBill ? () => Navigator.pushNamed(context, '/plans') : null,
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
                tier.isPremium ? 'Manage' : 'Upgrade',
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
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
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
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onCard(context))),
                  SizedBox(height: 2),
                  Text(item.subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtext(context))),
                ],
              ),
            ),
            item.trailing ??
                Icon(Icons.chevron_right,
                    size: 18, color: AppTheme.subtext(context)),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context, AuthService auth,
      VerificationStatus verificationStatus) {
    final user = auth.user!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
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
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName ?? 'Google User',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onCard(context))),
                      Text(user.email,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtext(context))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SyncStatusBadge(),
                    if (verificationStatus == VerificationStatus.verified) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF2E7D32)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                size: 12, color: Color(0xFF2E7D32)),
                            SizedBox(width: 4),
                            Text('Verified',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
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
    if (!profile.posEnabled) {
      _requireFeature(LimitType.posScreen, () => _doTogglePos(context, profile));
      return;
    }
    _doTogglePos(context, profile);
  }

  void _doTogglePos(BuildContext context, BusinessProfile profile) {
    context.read<AppProvider>().updateProfile(
          profile.copyWith(posEnabled: !profile.posEnabled));
  }

  void _togglePurchaseBill(BuildContext context, BusinessProfile profile) {
    context.read<AppProvider>().updateProfile(
          profile.copyWith(purchaseBillEnabled: !profile.purchaseBillEnabled));
  }

  void _toggleApprovalWorkflow(BuildContext context, BusinessProfile profile) {
    context.read<AppProvider>().updateProfile(
          profile.copyWith(approvalWorkflowEnabled: !profile.approvalWorkflowEnabled));
  }

  void _toggleLowStockAlerts(BuildContext context, BusinessProfile profile) {
    context.read<AppProvider>().updateProfile(
          profile.copyWith(lowStockAlertsEnabled: !profile.lowStockAlertsEnabled));
  }

  void _toggleEmployeePriceChange(BuildContext context, BusinessProfile profile) {
    context.read<AppProvider>().updateProfile(
          profile.copyWith(allowEmployeePriceChange: !profile.allowEmployeePriceChange));
  }

  Future<void> _editDailySalesVisibility(
      BuildContext context, BusinessProfile profile) async {
    const options = <int?>[7, 15, 30, 90, null];
    final selected = await showDialog<int?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Employee Daily Sales History'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Choose how many days of past Daily Sales entries '
              'employees can view.',
              style: TextStyle(fontSize: 13, color: AppTheme.subtext(ctx)),
            ),
          ),
          const SizedBox(height: 8),
          for (final days in options)
            RadioListTile<int?>(
              value: days,
              groupValue: profile.employeeDailySalesVisibilityDays,
              title: Text(days == null ? 'All time' : 'Last $days days'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (selected == profile.employeeDailySalesVisibilityDays || !context.mounted) return;
    await context.read<AppProvider>().updateProfile(
        profile.copyWith(employeeDailySalesVisibilityDays: selected));
  }

  Future<void> _editShopName(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final ctrl = TextEditingController(text: provider.currentShopName);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shop / Branch Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give this device a unique name so you can tell your branches apart.',
              style: TextStyle(fontSize: 13, color: AppTheme.subtext(ctx)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Shop / Branch Name',
                hintText: 'e.g. Main Branch, City Mall, Warehouse',
              ),
            ),
          ],
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
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (saved == null) return;
    await provider.setShopName(saved);
  }

  Future<void> _editDefaultCreditLimit(
      BuildContext context, BusinessProfile profile) async {
    final sym = Fmt.currencySymbol(profile.currency);
    final ctrl = TextEditingController(
      text: profile.defaultCreditLimit != null
          ? profile.defaultCreditLimit!
              .toStringAsFixed(profile.defaultCreditLimit! % 1 == 0 ? 0 : 2)
          : '',
    );
    String? error;

    final result = await showDialog<_CreditLimitResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Default Credit Limit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a credit limit that applies to all clients who don\'t have '
                'their own individual limit. Leave blank to remove the default.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.subtext(ctx)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$sym ',
                  hintText: 'e.g. 50000',
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
              ),
            ],
          ),
          actions: [
            if (profile.defaultCreditLimit != null)
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, const _CreditLimitResult(value: null, clear: true)),
                child: const Text('Remove Default',
                    style: TextStyle(color: AppTheme.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.isEmpty) {
                  Navigator.pop(ctx, const _CreditLimitResult(value: null, clear: true));
                  return;
                }
                final parsed = double.tryParse(text);
                if (parsed == null || parsed <= 0) {
                  setState(() => error = 'Enter a valid amount greater than 0');
                  return;
                }
                Navigator.pop(ctx, _CreditLimitResult(value: parsed, clear: false));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result == null || !context.mounted) return;

    context.read<AppProvider>().updateProfile(
          result.clear
              ? profile.copyWith(defaultCreditLimit: null)
              : profile.copyWith(defaultCreditLimit: result.value),
        );
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pairing.shopName != null
                      ? 'Shop: ${pairing.shopName}'
                      : 'Viewing business data',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
                const SizedBox(height: 2),
                Text(
                  pairing.ownerEmail as String,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.subtext(context)),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context),
                ),
              ),
            ),
            Divider(height: 1),
            ...LocaleProvider.localeNames.entries.map((entry) {
              final isSelected = currentLocale.languageCode == entry.key;
              return ListTile(
                title: Text(entry.value),
                leading: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppTheme.primary)
                    : Icon(Icons.radio_button_unchecked_rounded,
                        color: AppTheme.subtext(context)),
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
          SizedBox(height: 10),
          Text(
            'You are a $roleName at another business.',
            style: TextStyle(fontSize: 13, color: AppTheme.onCard(context)),
          ),
          SizedBox(height: 2),
          Text(
            ownerEmail,
            style: TextStyle(
                fontSize: 11, color: AppTheme.subtext(context)),
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

class _CreditLimitResult {
  final double? value;
  final bool clear;
  const _CreditLimitResult({required this.value, required this.clear});
}

// ── Business mode card ────────────────────────────────────────────────────────

class _BusinessModeCard extends StatelessWidget {
  final BusinessMode current;
  final ValueChanged<BusinessMode>? onChanged;
  final bool locked;

  const _BusinessModeCard({
    required this.current,
    this.onChanged,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz_rounded,
                    size: 18, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Mode',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onCard(context)),
                    ),
                    Text(
                      'Choose how your business tracks sales',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (locked) ...[
            Row(
              children: [
                _ModeOption(
                  icon: current == BusinessMode.invoiceBased
                      ? Icons.receipt_long_outlined
                      : Icons.storefront_outlined,
                  label: current == BusinessMode.invoiceBased
                      ? 'Invoice Based'
                      : 'Stock Based',
                  description: current == BusinessMode.invoiceBased
                      ? 'Create & send invoices\nto clients'
                      : 'Daily stock sales &\ncash reconciliation',
                  selected: true,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 13, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  'Set by owner — disconnect to change',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.subtext(context)),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                _ModeOption(
                  icon: Icons.receipt_long_outlined,
                  label: 'Invoice Based',
                  description: 'Create & send invoices\nto clients',
                  selected: current == BusinessMode.invoiceBased,
                  onTap: () => onChanged!(BusinessMode.invoiceBased),
                ),
                const SizedBox(width: 10),
                _ModeOption(
                  icon: Icons.storefront_outlined,
                  label: 'Stock Based',
                  description: 'Daily stock sales &\ncash reconciliation',
                  selected: current == BusinessMode.stockBased,
                  onTap: () => onChanged!(BusinessMode.stockBased),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppTheme.primary;
    final bg = selected
        ? activeColor.withValues(alpha: 0.10)
        : AppTheme.card(context);
    final border = selected
        ? activeColor
        : AppTheme.outline(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: border, width: selected ? 1.5 : 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? activeColor : AppTheme.subtext(context)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? activeColor
                        : AppTheme.onCard(context)),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                    fontSize: 11, color: AppTheme.subtext(context)),
              ),
              if (selected) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: activeColor),
                    const SizedBox(width: 4),
                    Text('Active',
                        style: TextStyle(
                            fontSize: 11,
                            color: activeColor,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
