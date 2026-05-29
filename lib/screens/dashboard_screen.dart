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
import 'create_invoice_screen.dart';
import 'invoice_list_screen.dart';
import 'client_list_screen.dart';
import 'settings_screen.dart';
import 'gst_report_screen.dart';
import 'category_analytics_screen.dart';
import 'pos_screen.dart';

enum _Period { today, week, month, year, custom }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.today:
        return 'Today';
      case _Period.week:
        return 'This Week';
      case _Period.month:
        return 'This Month';
      case _Period.year:
        return 'This Year';
      case _Period.custom:
        return 'Custom';
    }
  }
}

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

    final screens = [
      const _DashboardHome(),
      const InvoiceListScreen(),
      if (posEnabled) const PosScreen(),
      const ClientListScreen(),
      const SettingsScreen(),
    ];

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Invoices',
      ),
      if (posEnabled)
        const NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale_rounded),
          label: 'POS',
        ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Clients',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    // Clamp index so toggling POS never leaves an out-of-range selection.
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
              color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fx = context.watch<ExchangeRateService>();
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text(
              provider.profile.name.isNotEmpty
                  ? provider.profile.name
                  : 'Set up your business profile',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createInvoice(context),
            tooltip: 'New Invoice',
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
                child: _overviewBanner(all, provider),
              ),
              const SizedBox(height: 20),

              // ── Period selector ─────────────────────────────────────
              _FadeSlide(
                animation: _statsAnim,
                child: _periodSelector(),
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
                        title: 'Revenue',
                        value: Fmt.currencyAmount(periodRevenue, currency),
                        icon: Icons.trending_up_rounded,
                        color: AppTheme.success,
                      ),
                      SummaryCard(
                        title: 'Outstanding',
                        value:
                            Fmt.currencyAmount(periodOutstanding, currency),
                        icon: Icons.hourglass_empty_rounded,
                        color: AppTheme.warning,
                      ),
                      SummaryCard(
                        title: 'Invoices',
                        value: '${filtered.length}',
                        subtitle: 'in period',
                        icon: Icons.receipt_outlined,
                        color: AppTheme.primary,
                      ),
                      SummaryCard(
                        title: 'Overdue',
                        value: '$periodOverdue',
                        subtitle: 'invoices',
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
                  child: _CategoryInsightsCard(invoices: all, onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CategoryAnalyticsScreen()),
                    );
                  }),
                ),
              ),

              // ── Recent invoices ─────────────────────────────────────
              _FadeSlide(
                animation: _recentAnim,
                child: _sectionHeader(context, 'Recent Invoices',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createInvoice(context),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
        elevation: 2,
      ),
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
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _periodSelector() {
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
                  label: Text(p.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _period = p),
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected ? AppTheme.primary : AppTheme.divider,
                  ),
                  backgroundColor: Colors.white,
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
                        : 'Custom',
                    style: TextStyle(
                      color: _period == _Period.custom
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
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
                        : AppTheme.textSecondary,
                  ),
                ],
              ),
              onPressed: _pickCustomRange,
              side: BorderSide(
                color: _period == _Period.custom
                    ? AppTheme.primary
                    : AppTheme.divider,
              ),
              backgroundColor: _period == _Period.custom
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewBanner(List<Invoice> all, AppProvider provider) {
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
              const Text('Total Invoices',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 13)),
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
                  _statChip('Draft', draft, Colors.white24),
                  const SizedBox(width: 8),
                  _statChip('Sent', sent, Colors.white24),
                  const SizedBox(width: 8),
                  _statChip('Paid', paid,
                      AppTheme.success.withValues(alpha: 0.35)),
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
      {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text('No invoices yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text('Create your first invoice to get started',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _createInvoice(context),
            child: const Text('Create Invoice'),
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
        color: Colors.white,
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invoice.invoiceNumber} · Due ${Fmt.date(invoice.dueDate)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary),
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
          color: Colors.white,
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GST Reports',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text(
                    'CGST/SGST/IGST · HSN summary · Invoice register',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.textSecondary),
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
          color: Colors.white,
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
                  const Text('Category Insights',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    catCount == 0
                        ? 'Revenue · top items · best services'
                        : topCat != null
                            ? '$catCount categor${catCount == 1 ? 'y' : 'ies'} · top: $topCat'
                            : '$catCount categor${catCount == 1 ? 'y' : 'ies'} tracked',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.textSecondary),
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
