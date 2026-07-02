import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/exchange_rate_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../models/business_profile.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/summary_card.dart';
import '../widgets/status_badge.dart';
import '../models/invoice.dart';
import '../models/purchase_bill.dart';
import 'create_invoice_screen.dart';
import 'invoice_list_screen.dart';
import 'expense_list_screen.dart';
import 'cash_flow_screen.dart';
import 'settings_screen.dart';
import 'gst_report_screen.dart';
import 'category_analytics_screen.dart';
import 'pos_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/employee.dart';
import '../models/invoice.dart' show InvoiceStatus;
import 'pl_report_screen.dart';
import 'agewise_report_screen.dart';
import '../models/subscription_limits.dart' show LimitType;
import '../widgets/feature_guide_sheet.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/sync_status_badge.dart';
import '../models/daily_sale.dart';
import 'daily_sales_screen.dart';
import 'inventory_screen.dart';

enum _Period { today, week, month, year, custom }


// ─── Root shell ──────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _navController;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.dashboard);
    });
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _onTabChanged(int i) {
    if (i == _selectedIndex) return;
    _navController.reverse().then((_) {
      if (mounted) {
        setState(() => _selectedIndex = i);
        _navController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final posEnabled = appProvider.profile.posEnabled;
    final isFreeTier =
        appProvider.profile.subscriptionTier == SubscriptionTier.free;
    final isStockMode =
        appProvider.profile.businessMode == BusinessMode.stockBased;

    final l10n = AppLocalizations.of(context)!;

    final List<Widget> screens;
    final List<NavigationDestination> destinations;

    if (isStockMode) {
      screens = const [
        _StockDashboardHome(),
        DailySalesScreen(),
        InventoryScreen(),
        ExpenseListScreen(),
        SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: l10n.dashboard,
        ),
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Daily Sales',
        ),
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Stock',
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet),
          label: l10n.expenses,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.settings,
        ),
      ];
    } else {
      screens = [
        const _DashboardHome(),
        const InvoiceListScreen(),
        if (posEnabled) const PosScreen(),
        const ExpenseListScreen(),
        const SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: l10n.dashboard,
        ),
        NavigationDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long),
          label: l10n.invoices,
        ),
        if (posEnabled)
          const NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'POS',
          ),
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet),
          label: l10n.expenses,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.settings,
        ),
      ];
    }

    // Clamp index so toggling features never leaves an out-of-range selection.
    final safeIndex = _selectedIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: FadeTransition(
        opacity: _navController,
        child: screens[safeIndex],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFreeTier) const BannerAdWidget(),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: _onTabChanged,
              destinations: destinations,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard home tab ──────────────────────────────────────────────────────

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome>
    with SingleTickerProviderStateMixin {
  _Period _period = _Period.month;
  DateTimeRange? _customRange;

  late final AnimationController _enterController;
  late final Animation<double> _bannerAnim;
  late final Animation<double> _statsAnim;
  late final Animation<double> _recentAnim;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    Animation<double> interval(double b, double e) => CurvedAnimation(
          parent: _enterController,
          curve: Interval(b, e, curve: Curves.easeOutCubic),
        );

    _bannerAnim = interval(0.0, 0.5);
    _statsAnim = interval(0.2, 0.7);
    _recentAnim = interval(0.4, 1.0);

    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  DateTimeRange _rangeFor(_Period p) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (p) {
      case _Period.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _Period.week:
        return DateTimeRange(
            start: todayStart.subtract(const Duration(days: 6)),
            end: todayEnd);
      case _Period.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: todayEnd);
      case _Period.year:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: todayEnd);
      case _Period.custom:
        return _customRange ??
            DateTimeRange(
                start: DateTime(now.year, now.month, 1), end: todayEnd);
    }
  }

  List<Invoice> _filtered(List<Invoice> all) {
    final range = _rangeFor(_period);
    return all.where((inv) {
      final d = inv.invoiceDate;
      return !d.isBefore(range.start) && !d.isAfter(range.end);
    }).toList();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month, picked.end.day,
              23, 59, 59, 999),
        );
        _period = _Period.custom;
      });
    }
  }

  String _periodLabel(AppLocalizations l10n, _Period p) {
    switch (p) {
      case _Period.today:   return l10n.today;
      case _Period.week:    return l10n.thisWeek;
      case _Period.month:   return l10n.thisMonth;
      case _Period.year:    return l10n.thisYear;
      case _Period.custom:  return l10n.custom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final fx = context.watch<ExchangeRateService>();
    final canCreateInvoice = provider.canDo(AppPermission.createInvoice);
    final all = provider.invoices;
    final filtered = _filtered(all);
    final currency = provider.profile.currency;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fx.fetchIfNeeded(currency);
    });

    double toFx(double amount, Invoice i) => fx.toBase(amount, i.currency);

    final periodRevenue = filtered
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0.0, (s, i) => s + toFx(i.grandTotal, i));
    final periodOutstanding = filtered
        .where((i) =>
            i.status != InvoiceStatus.paid &&
            i.status != InvoiceStatus.cancelled)
        .fold(0.0, (s, i) => s + toFx(i.amountRemaining, i));
    final periodOverdue = filtered.where((i) => i.isOverdue).length;
    final isConverting = fx.isConverting(all.map((i) => i.currency));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dashboard),
            Text(
              provider.profile.name.isNotEmpty
                  ? provider.profile.name
                  : l10n.businessProfile,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtext(context),
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (fx.loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: SyncStatusBadge(),
          ),
          if (canCreateInvoice)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _createInvoice(context),
              tooltip: l10n.newInvoice,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => fx.fetchIfNeeded(currency),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner ──────────────────────────────────────────────
              _FadeSlide(
                animation: _bannerAnim,
                beginOffset: const Offset(0, -0.1),
                child: _overviewBanner(all, provider, l10n),
              ),
              const SizedBox(height: 20),

              // ── Period selector ─────────────────────────────────────
              _FadeSlide(
                animation: _statsAnim,
                child: _periodSelector(l10n),
              ),
              const SizedBox(height: 14),

              // ── Stats grid ──────────────────────────────────────────
              _FadeSlide(
                animation: _statsAnim,
                beginOffset: const Offset(0, 0.08),
                child: LayoutBuilder(builder: (_, constraints) {
                  final cardW = (constraints.maxWidth - 12) / 2;
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: cardW / 148,
                    children: [
                      SummaryCard(
                        title: l10n.revenue,
                        value: Fmt.currencyAmount(periodRevenue, currency),
                        icon: Icons.trending_up_rounded,
                        color: AppTheme.success,
                      ),
                      SummaryCard(
                        title: l10n.outstanding,
                        value: Fmt.currencyAmount(periodOutstanding, currency),
                        icon: Icons.hourglass_empty_rounded,
                        color: AppTheme.warning,
                      ),
                      SummaryCard(
                        title: l10n.invoices,
                        value: '${filtered.length}',
                        icon: Icons.receipt_outlined,
                        color: AppTheme.primary,
                      ),
                      SummaryCard(
                        title: l10n.overdue,
                        value: '$periodOverdue',
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.error,
                      ),
                    ],
                  );
                }),
              ),

              if (isConverting) ...[
                const SizedBox(height: 10),
                _conversionNotice(fx, currency),
              ],
              const SizedBox(height: 28),

              // ── P&L Summary card ────────────────────────────────────────
              _FadeSlide(
                animation: _recentAnim,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PLSummaryCard(
                    invoices: all,
                    expenses: provider.expenses,
                    currency: currency,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PLReportScreen()),
                    ),
                  ),
                ),
              ),

              // ── Outstanding Analysis card ────────────────────────────────
              _FadeSlide(
                animation: _recentAnim,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _OutstandingCard(
                    invoices: all,
                    currency: currency,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgewiseReportScreen()),
                    ),
                  ),
                ),
              ),

              // ── Cash Flow Forecast card ─────────────────────────────────
              _FadeSlide(
                animation: _recentAnim,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CashFlowCard(
                    invoices: all,
                    purchaseBills: provider.purchaseBills,
                    currency: currency,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CashFlowScreen()),
                    ),
                  ),
                ),
              ),

              // ── GST Reports quick-access (shown only when GST registered) ──
              if (provider.profile.isGstRegistered)
                _FadeSlide(
                  animation: _recentAnim,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _GstReportCard(onTap: () => openGstReport(context)),
                  ),
                ),

              // ── Category Insights ───────────────────────────────────
              _FadeSlide(
                animation: _recentAnim,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CategoryInsightsCard(invoices: all, onTap: () async {
                    final info = context.read<AppProvider>().checkFeature(LimitType.categoryAnalytics);
                    if (info != null) {
                      final up = await showPaywallSheet(context, info); // ignore: use_build_context_synchronously
                      if (up && context.mounted) Navigator.pushNamed(context, '/plans');
                      return;
                    }
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const CategoryAnalyticsScreen()));
                    }
                  }),
                ),
              ),

              // ── Recent invoices ─────────────────────────────────────
              _FadeSlide(
                animation: _recentAnim,
                child: _sectionHeader(context, l10n.recentInvoices,
                    onViewAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const InvoiceListScreen()))),
              ),
              const SizedBox(height: 10),
              if (all.isEmpty)
                _FadeSlide(
                  animation: _recentAnim,
                  child: _emptyState(context),
                )
              else
                ...all.take(5).toList().asMap().entries.map(
                      (e) => _AnimatedTile(
                        index: e.key,
                        parentAnim: _recentAnim,
                        child: _InvoiceTile(invoice: e.value),
                      ),
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: canCreateInvoice
          ? FloatingActionButton.extended(
              onPressed: () => _createInvoice(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.newInvoice),
              elevation: 2,
            )
          : null,
    );
  }

  Widget _conversionNotice(ExchangeRateService fx, String currency) {
    final updated = fx.lastUpdated;
    String label;
    if (fx.loading) {
      label = 'Updating exchange rates…';
    } else if (updated != null) {
      final mins = DateTime.now().difference(updated).inMinutes;
      final ago = mins < 1
          ? 'just now'
          : mins < 60
              ? '${mins}m ago'
              : '${DateTime.now().difference(updated).inHours}h ago';
      label = 'Converted to $currency · rates updated $ago';
    } else {
      label = 'Could not load rates · showing original amounts';
    }
    return Row(
      children: [
        Icon(
          fx.loading
              ? Icons.sync
              : fx.hasRates
                  ? Icons.currency_exchange
                  : Icons.wifi_off_outlined,
          size: 12,
          color: AppTheme.subtext(context),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppTheme.subtext(context))),
      ],
    );
  }

  Widget _periodSelector(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._Period.values.where((p) => p != _Period.custom).map((p) {
            final selected = _period == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: ChoiceChip(
                  label: Text(_periodLabel(l10n, p)),
                  selected: selected,
                  onSelected: (_) => setState(() => _period = p),
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.onCard(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected ? AppTheme.primary : AppTheme.outline(context),
                  ),
                  backgroundColor: AppTheme.card(context),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _period == _Period.custom && _customRange != null
                        ? '${Fmt.shortDate(_customRange!.start)} – ${Fmt.shortDate(_customRange!.end)}'
                        : l10n.custom,
                    style: TextStyle(
                      color: _period == _Period.custom
                          ? AppTheme.primary
                          : AppTheme.onCard(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: _period == _Period.custom
                        ? AppTheme.primary
                        : AppTheme.subtext(context),
                  ),
                ],
              ),
              onPressed: _pickCustomRange,
              side: BorderSide(
                color: _period == _Period.custom
                    ? AppTheme.primary
                    : AppTheme.outline(context),
              ),
              backgroundColor: _period == _Period.custom
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.card(context),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewBanner(List<Invoice> all, AppProvider provider, AppLocalizations l10n) {
    final draft = all.where((i) => i.status == InvoiceStatus.draft).length;
    final sent = all.where((i) => i.status == InvoiceStatus.sent).length;
    final paid = all.where((i) => i.status == InvoiceStatus.paid).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.totalInvoices,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              // Count-up animation on the total
              TweenAnimationBuilder<int>(
                key: ValueKey(all.length),
                tween: IntTween(begin: 0, end: all.length),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Text(
                  '$v',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statChip(l10n.draft, draft, Colors.white24),
                  const SizedBox(width: 8),
                  _statChip(l10n.sent, sent, Colors.white24),
                  const SizedBox(width: 8),
                  _statChip(l10n.paid, paid, AppTheme.success.withValues(alpha: 0.35)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color bg) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      {VoidCallback? onViewAll}) =>
      _buildSectionHeader(context, title, onViewAll: onViewAll);

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 30, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.noInvoicesYet,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context))),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.noInvoicesHint,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.subtext(context))),
          const SizedBox(height: 20),
          if (context.read<AppProvider>().canDo(AppPermission.createInvoice))
            ElevatedButton(
              onPressed: () => _createInvoice(context),
              child: Text(AppLocalizations.of(context)!.createInvoice),
            ),
        ],
      ),
    );
  }

  void _createInvoice(BuildContext context) {
    final invoice = context.read<AppProvider>().buildNewInvoice();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateInvoiceScreen(invoice: invoice)),
    );
  }
}

// ─── Animated tile wrapper (stagger per index) ────────────────────────────────

class _AnimatedTile extends StatelessWidget {
  final int index;
  final Animation<double> parentAnim;
  final Widget child;

  const _AnimatedTile({
    required this.index,
    required this.parentAnim,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.08).clamp(0.0, 0.5);
    final anim = CurvedAnimation(
      parent: parentAnim,
      curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

// ─── Generic fade+slide helper ────────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Offset beginOffset;
  final Widget child;

  const _FadeSlide({
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.06),
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}

// ─── Recent invoice tile ──────────────────────────────────────────────────────

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CreateInvoiceScreen(invoice: invoice)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_outlined,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.client?.displayName ?? 'No Client',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.onCard(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invoice.invoiceNumber} · Due ${Fmt.date(invoice.dueDate)}',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 90,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Fmt.currencyAmount(
                            invoice.grandTotal, invoice.currency),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.onCard(context)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: invoice.status, small: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── GST Reports quick-access card ─────────────────────────────────────────────

class _GstReportCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GstReportCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_outlined,
                  color: Color(0xFFE65100), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GST Reports',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.onCard(context))),
                  const SizedBox(height: 2),
                  Text(
                    'CGST/SGST/IGST · HSN summary · Invoice register',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.subtext(context)),
          ],
        ),
      ),
    );
  }
}

// ─── Category Insights card ───────────────────────────────────────────────────

class _CategoryInsightsCard extends StatelessWidget {
  final List<Invoice> invoices;
  final VoidCallback onTap;
  const _CategoryInsightsCard({required this.invoices, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Count distinct categories used across all invoices.
    final cats = invoices
        .expand((inv) => inv.items)
        .map((item) => item.category?.trim())
        .where((c) => c != null && c.isNotEmpty)
        .toSet();
    final catCount = cats.length;

    // Find the top category by revenue (paid invoices).
    final revenueMap = <String, double>{};
    for (final inv in invoices) {
      if (inv.status != InvoiceStatus.paid) continue;
      for (final item in inv.items) {
        final cat = item.category?.trim();
        if (cat == null || cat.isEmpty) continue;
        revenueMap[cat] = (revenueMap[cat] ?? 0) + item.total;
      }
    }
    final topCat = revenueMap.isEmpty
        ? null
        : (revenueMap.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.label_outlined,
                  color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category Insights',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.onCard(context))),
                  const SizedBox(height: 2),
                  Text(
                    catCount == 0
                        ? 'Revenue · top items · best services'
                        : topCat != null
                            ? '$catCount categor${catCount == 1 ? 'y' : 'ies'} · top: $topCat'
                            : '$catCount categor${catCount == 1 ? 'y' : 'ies'} tracked',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.subtext(context)),
          ],
        ),
      ),
    );
  }
}

// ─── Public wrapper so WebShell can embed the dashboard home tab ─────────────

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) => const _DashboardHome();
}

// ─── P&L Summary card ─────────────────────────────────────────────────────────

class _PLSummaryCard extends StatelessWidget {
  final List<Invoice> invoices;
  final List expenses; // List<Expense> — typed as dynamic to avoid import
  final String currency;
  final VoidCallback onTap;

  const _PLSummaryCard({
    required this.invoices,
    required this.expenses,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final revenue = invoices
        .where((i) =>
            !i.isQuotation &&
            i.status == InvoiceStatus.paid &&
            !i.invoiceDate.isBefore(start) &&
            !i.invoiceDate.isAfter(end))
        .fold(0.0, (s, i) => s + i.grandTotal);

    // expenses is List<Expense> but typed dynamically to avoid import cycle
    double expTotal = 0;
    for (final e in expenses) {
      final date = e.date as DateTime;
      if (!date.isBefore(start) && !date.isAfter(end)) {
        expTotal += (e.amount as num).toDouble();
      }
    }

    final net = revenue - expTotal;
    final netColor = net >= 0 ? AppTheme.success : AppTheme.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_outlined,
                  color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('P & L — This Month',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.onCard(context))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '↑ ${Fmt.currencyAmount(revenue, currency)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600),
                      ),
                      const Text('  ',
                          style: TextStyle(fontSize: 11)),
                      Text(
                        '↓ ${Fmt.currencyAmount(expTotal, currency)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        'Net ${Fmt.currencyAmount(net.abs(), currency)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: netColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.subtext(context)),
          ],
        ),
      ),
    );
  }
}

// ─── Cash Flow preview card ───────────────────────────────────────────────────

class _CashFlowCard extends StatelessWidget {
  final List<Invoice> invoices;
  final List<PurchaseBill> purchaseBills;
  final String currency;
  final VoidCallback onTap;

  const _CashFlowCard({
    required this.invoices,
    required this.purchaseBills,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(currency);
    final now = DateTime.now();

    final in7 = invoices
        .where((inv) =>
            !inv.isQuotation &&
            !inv.isCreditNote &&
            inv.status != InvoiceStatus.paid &&
            inv.status != InvoiceStatus.cancelled &&
            inv.status != InvoiceStatus.draft &&
            !inv.dueDate.isAfter(now.add(const Duration(days: 7))))
        .fold(0.0, (s, inv) => s + inv.amountRemaining);

    final out7 = purchaseBills
        .where((b) =>
            b.status != PurchaseBillStatus.paid &&
            b.dueDate != null &&
            !b.dueDate!.isAfter(now.add(const Duration(days: 7))))
        .fold(0.0, (s, b) => s + b.amountDue);

    final net7 = in7 - out7;
    final isPositive = net7 >= 0;
    final netColor = isPositive ? AppTheme.success : AppTheme.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outline(context)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.show_chart_rounded,
                      size: 18, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 10),
                Text('Cash Flow (7-day)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onCard(context))),
                const Spacer(),
                Icon(Icons.chevron_right,
                    size: 18, color: AppTheme.subtext(context)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _cfStat(context, 'Inflows',
                        '$sym${Fmt.compact(in7)}', AppTheme.success)),
                Expanded(
                    child: _cfStat(context, 'Outflows',
                        '$sym${Fmt.compact(out7)}', AppTheme.error)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.subtext(context))),
                      const SizedBox(height: 2),
                      Text(
                        '${isPositive ? '+' : ''}$sym${Fmt.compact(net7)}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: netColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cfStat(
      BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppTheme.subtext(context))),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ─── Outstanding Analysis card ────────────────────────────────────────────────

class _OutstandingCard extends StatelessWidget {
  final List<Invoice> invoices;
  final String currency;
  final VoidCallback onTap;

  const _OutstandingCard({
    required this.invoices,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final outstanding = invoices.where((i) =>
        !i.isQuotation &&
        i.status != InvoiceStatus.paid &&
        i.status != InvoiceStatus.cancelled).toList();

    final overdueNow = outstanding.where((i) => i.dueDate.isBefore(now)).toList();
    final over30 = overdueNow.where((i) =>
        now.difference(i.dueDate).inDays > 30).length;
    final totalAmt = outstanding.fold(0.0, (s, i) => s + i.amountRemaining);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
          border: overdueNow.isNotEmpty
              ? Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.hourglass_bottom_rounded,
                  color: overdueNow.isNotEmpty
                      ? AppTheme.warning
                      : AppTheme.subtext(context),
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Outstanding Analysis',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.onCard(context))),
                  const SizedBox(height: 3),
                  Text(
                    outstanding.isEmpty
                        ? 'All invoices are cleared'
                        : '${outstanding.length} unpaid · '
                            '${overdueNow.length} overdue'
                            '${over30 > 0 ? ' · $over30 past 30 days' : ''}'
                            ' · ${Fmt.currencyAmount(totalAmt, currency)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: overdueNow.isNotEmpty
                            ? AppTheme.warning
                            : AppTheme.subtext(context),
                        fontWeight: overdueNow.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.subtext(context)),
          ],
        ),
      ),
    );
  }
}


// ─── Stock mode dashboard home ────────────────────────────────────────────────

// Top-level helper shared by both dashboard home widgets.
Widget _buildSectionHeader(BuildContext context, String title,
    {VoidCallback? onViewAll}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.onCard(context))),
      if (onViewAll != null)
        TextButton(
            onPressed: onViewAll,
            child: Text(AppLocalizations.of(context)!.viewAll)),
    ],
  );
}

class _StockDashboardHome extends StatelessWidget {
  const _StockDashboardHome();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final sales = provider.dailySales;
    final today = provider.todaysSale;
    final l10n = AppLocalizations.of(context)!;

    final weekStart = DateTime.now().subtract(const Duration(days: 6));
    final weekSales = sales.where((s) =>
        !s.date.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day)));
    final weekTotal = weekSales.fold(0.0, (s, d) => s + d.totalSales);
    final weekCash  = weekSales.fold(0.0, (s, d) => s + d.cashReceived);
    final weekBank  = weekSales.fold(0.0, (s, d) => s + d.bankReceived);
    final unbalancedCount = weekSales.where((d) => !d.isBalanced).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dashboard),
            Text(
              provider.profile.name.isNotEmpty
                  ? provider.profile.name
                  : l10n.businessProfile,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtext(context),
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Daily Entry',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailySalesScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StockTodayCard(sale: today, currency: currency),
            const SizedBox(height: 20),
            Text(
              'Last 7 Days',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.subtext(context)),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - 12) / 2;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: w / 130,
                children: [
                  SummaryCard(
                    title: 'Total Sales',
                    value: Fmt.currencyAmount(weekTotal, currency),
                    icon: Icons.sell_outlined,
                    color: AppTheme.primary,
                  ),
                  SummaryCard(
                    title: 'Cash',
                    value: Fmt.currencyAmount(weekCash, currency),
                    icon: Icons.payments_outlined,
                    color: AppTheme.success,
                  ),
                  SummaryCard(
                    title: 'Bank / UPI',
                    value: Fmt.currencyAmount(weekBank, currency),
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF0891B2),
                  ),
                  SummaryCard(
                    title: 'Unbalanced Days',
                    value: '$unbalancedCount',
                    icon: Icons.warning_amber_rounded,
                    color: unbalancedCount > 0 ? AppTheme.error : AppTheme.success,
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Recent Entries',
                onViewAll: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DailySalesScreen()))),
            const SizedBox(height: 10),
            if (sales.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 52, color: AppTheme.subtext(context)),
                      const SizedBox(height: 12),
                      Text('No entries yet',
                          style: TextStyle(color: AppTheme.subtext(context))),
                    ],
                  ),
                ),
              )
            else
              ...sales.take(5).map(
                  (s) => _StockSaleSummaryTile(sale: s, currency: currency)),
          ],
        ),
      ),
    );
  }
}

// ── Today card ────────────────────────────────────────────────────────────────

class _StockTodayCard extends StatelessWidget {
  final DailySale? sale;
  final String currency;
  const _StockTodayCard({required this.sale, required this.currency});

  @override
  Widget build(BuildContext context) {
    final s = sale;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: s == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Sales",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                const Text('No entry yet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const DailySalesScreen())),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Add Entry',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Today's Sales",
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.isBalanced
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppTheme.error.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              s.isBalanced
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              size: 12,
                              color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            s.isBalanced ? 'Balanced' : 'Unbalanced',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Fmt.currencyAmount(s.totalSales, currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(child: _MiniStat(
                        label: 'Cash',
                        value: Fmt.currencyAmount(s.cashReceived, currency))),
                    const SizedBox(width: 16),
                    Flexible(child: _MiniStat(
                        label: 'Bank',
                        value: Fmt.currencyAmount(s.bankReceived, currency))),
                    if (!s.isBalanced) ...[
                      const SizedBox(width: 16),
                      Flexible(child: _MiniStat(
                          label: 'Diff',
                          value: Fmt.currencyAmount(s.difference.abs(), currency),
                          isAlert: true)),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isAlert;
  const _MiniStat(
      {required this.label, required this.value, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color:
                    isAlert ? Colors.orange.shade200 : Colors.white70)),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAlert
                    ? Colors.orange.shade100
                    : Colors.white)),
      ],
    );
  }
}

// ── Recent entry row ──────────────────────────────────────────────────────────

class _StockSaleSummaryTile extends StatelessWidget {
  final DailySale sale;
  final String currency;
  const _StockSaleSummaryTile(
      {required this.sale, required this.currency});

  @override
  Widget build(BuildContext context) {
    final balanced = sale.isBalanced;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.date(sale.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context))),
                Text(
                  '${sale.items.length} item${sale.items.length == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.subtext(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Fmt.currencyAmount(sale.totalSales, currency),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          Icon(
            balanced ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: balanced ? AppTheme.success : AppTheme.error,
          ),
        ],
      ),
    );
  }
}
