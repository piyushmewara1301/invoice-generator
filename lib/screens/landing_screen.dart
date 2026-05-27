import 'package:flutter/material.dart';
import '../models/subscription_limits.dart';
import '../utils/app_theme.dart';
import '../widgets/gsi_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillBook Landing Page
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollCtrl = ScrollController();
  bool _navScrolled = false;

  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();
  final _gstKey = GlobalKey();
  final _faqKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final scrolled = _scrollCtrl.offset > 10;
      if (scrolled != _navScrolled) setState(() => _navScrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              children: [
                const SizedBox(height: 68),
                const _HeroSection(),
                _StatsStrip(),
                _FeaturesSection(sectionKey: _featuresKey),
                _HowItWorksSection(),
                _GstSection(sectionKey: _gstKey),
                _PricingSection(sectionKey: _pricingKey),
                _FaqSection(sectionKey: _faqKey),
                const _CtaBanner(),
                const _LandingFooter(),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _LandingNavbar(
              scrolled: _navScrolled,
              onFeatures: () => _scrollTo(_featuresKey),
              onPricing: () => _scrollTo(_pricingKey),
              onGst: () => _scrollTo(_gstKey),
              onFaq: () => _scrollTo(_faqKey),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVBAR
// ─────────────────────────────────────────────────────────────────────────────

class _LandingNavbar extends StatelessWidget {
  final bool scrolled;
  final VoidCallback onFeatures;
  final VoidCallback onPricing;
  final VoidCallback onGst;
  final VoidCallback onFaq;

  const _LandingNavbar({
    required this.scrolled,
    required this.onFeatures,
    required this.onPricing,
    required this.onGst,
    required this.onFaq,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 68,
      decoration: BoxDecoration(
        color: scrolled
            ? Colors.white
            : Colors.white.withValues(alpha: 0.97),
        boxShadow: scrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
        border: scrolled
            ? Border(bottom: BorderSide(color: const Color(0xFFE2E8F0)))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 56),
        child: Row(
          children: [
            _NavLogo(),
            if (!isMobile) ...[
              const SizedBox(width: 40),
              _NavLink('Features', onFeatures),
              _NavLink('GST', onGst),
              _NavLink('Pricing', onPricing),
              _NavLink('FAQ', onFaq),
            ],
            const Spacer(),
            buildGSignInButton(width: isMobile ? 180 : 220),
          ],
        ),
      ),
    );
  }
}

class _NavLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Text('BB',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 9),
        const Text('BillBook',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4)),
      ],
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color:
                  _hovered ? AppTheme.primary : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  const _HeroSection();

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _textSlide;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _textSlide =
        Tween<Offset>(begin: const Offset(-0.06, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _cardSlide =
        Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.microtask(() {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w > 960;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: isDesktop ? 96 : 56,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: const _HeroText(),
                    ),
                  ),
                ),
                const SizedBox(width: 72),
                Expanded(
                  flex: 4,
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: const _AppDashboardPreview(),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const _HeroText(),
                  ),
                ),
                const SizedBox(height: 48),
                FadeTransition(
                  opacity: _fade,
                  child: const _AppDashboardPreview(),
                ),
              ],
            ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 13, color: Color(0xFF93C5FD)),
              SizedBox(width: 5),
              Text('GST-Compliant Invoicing for India',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF93C5FD),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Invoice like a\nPro. Get Paid\nFaster.',
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Create GST-compliant invoices, track payments, manage clients and grow your business — beautifully.',
          style: TextStyle(
              fontSize: 17,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.7,
              letterSpacing: -0.1),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            buildGSignInButton(width: 280),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone_android_rounded,
                  size: 17, color: Colors.white70),
              label: const Text('Download App',
                  style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 22,
          runSpacing: 10,
          children: const [
            _HeroPill('No credit card required'),
            _HeroPill('Free forever plan'),
            _HeroPill('100% data privacy'),
          ],
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String text;
  const _HeroPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 7),
        Text(text,
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}

// Premium app dashboard mockup replacing the invoice widget
class _AppDashboardPreview extends StatefulWidget {
  const _AppDashboardPreview();

  @override
  State<_AppDashboardPreview> createState() => _AppDashboardPreviewState();
}

class _AppDashboardPreviewState extends State<_AppDashboardPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _notifCtrl;
  late Animation<double> _notifFade;
  late Animation<Offset> _notifSlide;

  @override
  void initState() {
    super.initState();
    _notifCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _notifFade = CurvedAnimation(parent: _notifCtrl, curve: Curves.easeOut);
    _notifSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(CurvedAnimation(parent: _notifCtrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _notifCtrl.forward();
    });
  }

  @override
  void dispose() {
    _notifCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main dashboard card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 60,
                offset: const Offset(0, 30),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App header
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('BB',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('BillBook',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Text('Dashboard',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D))),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // KPI row
              Row(
                children: [
                  _KpiTile('Revenue', '₹2.4L', '+18%', const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _KpiTile(
                      'Invoices', '148', '+5 today', const Color(0xFF059669)),
                  const SizedBox(width: 8),
                  _KpiTile(
                      'Clients', '36', '+2 new', const Color(0xFF7C3AED)),
                ],
              ),
              const SizedBox(height: 18),
              // Bar chart
              const Text('Monthly Revenue',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              _MiniBarChart(),
              const SizedBox(height: 18),
              // Recent invoices label
              Row(
                children: [
                  const Text('Recent Invoices',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text('View all →',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary.withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(height: 8),
              _InvoiceRow(
                  'Rajesh Kumar', '₹35,000', 'PAID', const Color(0xFF059669)),
              _InvoiceRow('Priya Sharma', '₹12,500', 'PENDING',
                  const Color(0xFFD97706)),
              _InvoiceRow(
                  'Tech Innovators', '₹75,000', 'PAID', const Color(0xFF059669)),
            ],
          ),
        ),
        // Floating notification badge
        Positioned(
          bottom: -18,
          right: 16,
          child: FadeTransition(
            opacity: _notifFade,
            child: SlideTransition(
              position: _notifSlide,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: Color(0xFF4ADE80)),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice Paid!',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('₹35,000 · Rajesh Kumar',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _KpiTile(this.label, this.value, this.sub, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.7),
                    letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(sub,
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  static const _bars = [0.45, 0.6, 0.5, 0.75, 0.55, 0.9, 0.7];
  static const _months = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_bars.length, (i) {
          final isLast = i == _bars.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 400 + i * 80),
                    curve: Curves.easeOutCubic,
                    height: 36 * _bars[i],
                    decoration: BoxDecoration(
                      color: isLast
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(_months[i],
                      style: const TextStyle(
                          fontSize: 8, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String client;
  final String amount;
  final String status;
  final Color statusColor;
  const _InvoiceRow(this.client, this.amount, this.status, this.statusColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                client[0],
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(client,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(amount,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatefulWidget {
  @override
  State<_StatsStrip> createState() => _StatsStripState();
}

class _StatsStripState extends State<_StatsStrip> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) setState(() => _started = true); });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding:
          EdgeInsets.symmetric(vertical: 40, horizontal: isMobile ? 24 : 80),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 40,
        runSpacing: 28,
        children: [
          _AnimatedStat(
              target: 50000,
              suffix: '+',
              label: 'Invoices Created',
              started: _started),
          _AnimatedStat(
              target: 10000,
              suffix: '+',
              label: 'Active Businesses',
              started: _started),
          _AnimatedStat(
              target: 9, suffix: '', label: 'Templates', started: _started),
          _AnimatedStat(
              target: 100,
              suffix: '%',
              label: 'GST Compliant',
              started: _started),
        ],
      ),
    );
  }
}

class _AnimatedStat extends StatelessWidget {
  final int target;
  final String suffix;
  final String label;
  final bool started;
  const _AnimatedStat(
      {required this.target,
      required this.suffix,
      required this.label,
      required this.started});

  String _format(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 0)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: started ? target : 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_format(val)}$suffix',
            style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: -1),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURES
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatefulWidget {
  final GlobalKey sectionKey;
  const _FeaturesSection({required this.sectionKey});

  @override
  State<_FeaturesSection> createState() => _FeaturesSectionState();
}

class _FeaturesSectionState extends State<_FeaturesSection> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100),
        () { if (mounted) setState(() => _visible = true); });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w > 960;
    final crossCount = isDesktop ? 3 : (w > 600 ? 2 : 1);

    const features = [
      (Icons.receipt_long_rounded, Color(0xFF2563EB), 'Professional Invoices',
          'Create beautiful GST-compliant invoices in seconds. Pick a template, add your items — done.'),
      (Icons.account_balance_rounded, Color(0xFFEA580C), 'GST Compliant',
          'Auto CGST/SGST/IGST split, HSN/SAC codes, GSTR-1 ready reports. Built for Indian tax law.'),
      (Icons.people_rounded, Color(0xFF7C3AED), 'Client Management',
          'Unlimited client profiles with invoice history, GSTIN, and full contact details.'),
      (Icons.currency_rupee_rounded, Color(0xFF059669), 'Payment Tracking',
          'Track partial payments, outstanding balances, overdue alerts. Know exactly what you\'re owed.'),
      (Icons.cloud_sync_rounded, Color(0xFF0284C7), 'Google Drive Sync',
          'Your data auto-synced to your own Google Drive. Private, secure, always accessible.'),
      (Icons.devices_rounded, Color(0xFFDB2777), 'Mobile + Web',
          'Designed for your phone. Premium users unlock the full web dashboard from any browser.'),
    ];

    return Container(
      key: widget.sectionKey,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          vertical: 88, horizontal: isDesktop ? 80 : 24),
      child: Column(
        children: [
          _SectionBadge('Features', AppTheme.primary),
          const SizedBox(height: 16),
          const _SectionTitle('Everything your business\nneeds to invoice'),
          const SizedBox(height: 10),
          const _SectionSubtitle(
              'From your first invoice to GST reports — BillBook has it all covered.'),
          const SizedBox(height: 60),
          _ResponsiveGrid(
            crossCount: crossCount,
            spacing: 20,
            children: features
                .asMap()
                .entries
                .map((e) => _AnimatedFeatureCard(
                      index: e.key,
                      icon: e.value.$1,
                      color: e.value.$2,
                      title: e.value.$3,
                      desc: e.value.$4,
                      visible: _visible,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFeatureCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final bool visible;

  const _AnimatedFeatureCard({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: visible ? 1 : 0),
      duration: Duration(milliseconds: 500 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - val)),
          child: child,
        ),
      ),
      child: _FeatureCard(icon: icon, color: color, title: title, desc: desc),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _FeatureCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.desc});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(26),
        transform: _hovered
            ? Matrix4.translationValues(0, -4, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _hovered ? 24 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: _hovered ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icon, color: widget.color, size: 25),
            ),
            const SizedBox(height: 18),
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 9),
            Text(widget.desc,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.65)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOW IT WORKS
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    const steps = [
      (Icons.person_add_rounded, '01', 'Set Up Your Business',
          'Add your business name, logo, GSTIN, address and payment details in under 2 minutes.'),
      (Icons.edit_note_rounded, '02', 'Create Your Invoice',
          'Pick a template, add your client, fill in line items — your invoice is ready instantly.'),
      (Icons.send_rounded, '03', 'Send & Get Paid',
          'Download PDF, share via WhatsApp or email. Track payments as they arrive.'),
    ];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
        ),
      ),
      padding: EdgeInsets.symmetric(
          vertical: 88, horizontal: isDesktop ? 80 : 24),
      child: Column(
        children: [
          _SectionBadge('How it works', const Color(0xFF059669)),
          const SizedBox(height: 16),
          const _SectionTitle('Up and running in 3 steps'),
          const SizedBox(height: 10),
          const _SectionSubtitle('No training required. Start creating invoices in minutes.'),
          const SizedBox(height: 56),
          _ResponsiveGrid(
            crossCount: isDesktop ? 3 : 1,
            spacing: 20,
            children: steps
                .asMap()
                .entries
                .map((e) => _StepCard(
                    icon: e.value.$1,
                    number: e.value.$2,
                    title: e.value.$3,
                    desc: e.value.$4,
                    index: e.key))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final String number;
  final String title;
  final String desc;
  final int index;
  const _StepCard(
      {required this.icon,
      required this.number,
      required this.title,
      required this.desc,
      required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    letterSpacing: -2),
              ),
              const Spacer(),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 9),
          Text(desc,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.65)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GST SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _GstSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const _GstSection({required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    const points = [
      (Icons.calculate_rounded, 'Auto CGST/SGST/IGST',
          'Inter-state and intra-state tax auto-split based on place of supply.'),
      (Icons.qr_code_rounded, 'HSN/SAC Code Support',
          'Add HSN for goods and SAC for services on every line item.'),
      (Icons.summarize_rounded, 'GSTR-1 Style Reports',
          'Tax-period reports with invoice register, HSN summary and net liability.'),
      (Icons.swap_horiz_rounded, 'Reverse Charge (RCM)',
          'Mark invoices as RCM and shift tax liability to the recipient.'),
      (Icons.badge_rounded, 'Composition Scheme',
          'Full composition dealer support — correct tax display and calculations.'),
      (Icons.business_rounded, 'B2B & B2C Invoicing',
          'Capture buyer GSTIN for B2B or issue B2C invoices directly.'),
    ];
    return Container(
      key: sectionKey,
      padding: EdgeInsets.symmetric(
          vertical: 88, horizontal: isDesktop ? 80 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF7ED),
            Colors.white,
            const Color(0xFFFFF7ED)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _SectionBadge('GST Ready', const Color(0xFFEA580C)),
          const SizedBox(height: 16),
          const _SectionTitle('Built for Indian\nBusinesses'),
          const SizedBox(height: 10),
          const _SectionSubtitle(
              'Purpose-built for GST compliance. Every invoice follows Indian tax law — no manual calculations needed.'),
          const SizedBox(height: 56),
          _ResponsiveGrid(
            crossCount:
                isDesktop ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
            spacing: 16,
            children: points
                .map((p) => _GstPoint(icon: p.$1, title: p.$2, desc: p.$3))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _GstPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _GstPoint(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA).withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: const Color(0xFFEA580C), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 5),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRICING — yearly only
// ─────────────────────────────────────────────────────────────────────────────

class _PricingSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const _PricingSection({required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 960;
    final tiers = [
      _PricingData(
        tier: SubscriptionTier.free,
        name: 'Free',
        color: const Color(0xFF64748B),
        tagline: 'For getting started',
        price: tierPrices[SubscriptionTier.free]!,
        features: [
          '5 invoices / month',
          '10 clients',
          '1 template (Classic)',
          '1 payment method',
          'PDF download & share',
          'Google Drive sync',
        ],
        cta: 'Start Free',
        highlight: false,
      ),
      _PricingData(
        tier: SubscriptionTier.lite,
        name: 'Lite',
        color: const Color(0xFF0284C7),
        tagline: 'For freelancers',
        price: tierPrices[SubscriptionTier.lite]!,
        features: [
          '50 invoices / month',
          '50 clients',
          '3 templates',
          '2 payment methods',
          'Partial payments',
          'Multi-currency',
        ],
        cta: 'Get Lite',
        highlight: false,
      ),
      _PricingData(
        tier: SubscriptionTier.pro,
        name: 'Pro',
        color: const Color(0xFF7C3AED),
        tagline: 'For growing businesses',
        price: tierPrices[SubscriptionTier.pro]!,
        features: [
          'Unlimited invoices',
          'Unlimited clients',
          'All 9 templates',
          'Unlimited payment methods',
          'GST Reports (GSTR-1)',
          'Custom invoice prefix',
        ],
        cta: 'Get Pro',
        highlight: true,
      ),
      _PricingData(
        tier: SubscriptionTier.premium,
        name: 'Premium',
        color: const Color(0xFFEA580C),
        tagline: 'For power users',
        price: tierPrices[SubscriptionTier.premium]!,
        features: [
          'Everything in Pro',
          'Web dashboard access',
          'Custom message templates',
          'Priority support',
          'Early access to new features',
        ],
        cta: 'Get Premium',
        highlight: false,
      ),
    ];

    return Container(
      key: sectionKey,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.symmetric(
          vertical: 88, horizontal: isDesktop ? 80 : 24),
      child: Column(
        children: [
          _SectionBadge('Pricing', const Color(0xFFA78BFA)),
          const SizedBox(height: 16),
          const Text(
            'Simple, transparent pricing',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.8),
          ),
          const SizedBox(height: 10),
          Text(
            'Start free. Upgrade anytime from the mobile app.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5),
          ),
          const SizedBox(height: 56),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiers
                      .map((t) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: _PricingCard(data: t),
                          )))
                      .toList(),
                )
              : Column(
                  children: tiers
                      .map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _PricingCard(data: t)))
                      .toList(),
                ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  'In-app purchases coming soon. Start with Free today.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingData {
  final SubscriptionTier tier;
  final String name, tagline, cta;
  final Color color;
  final TierPrice price;
  final List<String> features;
  final bool highlight;
  const _PricingData({
    required this.tier,
    required this.name,
    required this.tagline,
    required this.cta,
    required this.color,
    required this.price,
    required this.features,
    required this.highlight,
  });
}

class _PricingCard extends StatefulWidget {
  final _PricingData data;
  const _PricingCard({required this.data});

  @override
  State<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<_PricingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: (_hovered || d.highlight)
            ? Matrix4.translationValues(0, d.highlight ? -8 : -4, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: d.highlight ? d.color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: d.highlight
              ? null
              : Border.all(
                  color: _hovered
                      ? d.color.withValues(alpha: 0.4)
                      : const Color(0xFF2D3748),
                  width: 1.5),
          boxShadow: [
            BoxShadow(
              color: d.highlight
                  ? d.color.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: _hovered ? 0.25 : 0.15),
              blurRadius: d.highlight ? 40 : (_hovered ? 24 : 10),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d.highlight)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('MOST POPULAR',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ),
                  Text(
                    d.name,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: d.highlight ? Colors.white : d.color,
                        letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 3),
                  Text(d.tagline,
                      style: TextStyle(
                          fontSize: 13,
                          color: d.highlight
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF94A3B8))),
                  const SizedBox(height: 20),
                  if (d.price.yearlyRupees == 0)
                    Text('Free',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: d.highlight ? Colors.white : d.color,
                            letterSpacing: -1))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('50% OFF',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${d.price.yearlyRupees * 2}',
                              style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: d.highlight
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : const Color(0xFF94A3B8),
                                  color: d.highlight
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${d.price.yearlyRupees}',
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: d.highlight ? Colors.white : d.color,
                                  letterSpacing: -1.5),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6, left: 3),
                              child: Text(
                                '/year',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: d.highlight
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '≈ ₹${(d.price.yearlyRupees / 12).round()}/month — billed annually',
                          style: TextStyle(
                              fontSize: 11,
                              color: d.highlight
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: d.highlight
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE2E8F0)),
            // Features
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  ...d.features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: d.highlight
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : d.color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded,
                                  size: 12,
                                  color: d.highlight
                                      ? Colors.white
                                      : d.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(f,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: d.highlight
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : AppTheme.textPrimary)),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: d.tier == SubscriptionTier.free
                        ? buildGSignInButton(width: double.infinity)
                        : d.highlight
                            ? ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 15),
                                    const SizedBox(width: 6),
                                    Text(d.cta,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ],
                                ),
                              )
                            : OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: d.color,
                                  side: BorderSide(
                                      color: d.color.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 15),
                                    const SizedBox(width: 6),
                                    Text(d.cta,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ
// ─────────────────────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const _FaqSection({required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    const faqs = [
      ('Is BillBook free to use?',
          'Yes! BillBook has a Free plan that lets you create up to 5 invoices per month with no credit card needed. Free forever — no surprise charges.'),
      ('Does it support GST invoices?',
          'Absolutely. BillBook is purpose-built for Indian GST compliance. It auto-calculates CGST, SGST, and IGST based on the place of supply. It also supports HSN/SAC codes, composition dealers, and reverse charge.'),
      ('How is my data stored and secured?',
          'Your data is AES-256 encrypted and backed up to your own personal Google Drive. We never have access to your business data.'),
      ('Can I use BillBook on multiple devices?',
          'Yes. Your data syncs automatically via Google Drive. Sign in with the same Google account on any Android or iOS device. Premium users also get the full web dashboard.'),
      ('What invoice templates are available?',
          'BillBook includes 9 professional templates: Classic, Minimal, Corporate, Modern, Restaurant, Receipt, Professional, GST Bill, and Letterhead. Free users get the Classic template; premium users unlock all 9.'),
      ('When will paid plans be available?',
          'In-app purchases are coming very soon. Once launched, you\'ll be able to upgrade directly from the mobile app under Settings → Plan.'),
    ];

    return Container(
      key: sectionKey,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          vertical: 88, horizontal: isDesktop ? 80 : 24),
      child: Column(
        children: [
          _SectionBadge('FAQ', const Color(0xFF0284C7)),
          const SizedBox(height: 16),
          const _SectionTitle('Frequently asked questions'),
          const SizedBox(height: 10),
          const _SectionSubtitle('Everything you need to know about BillBook.'),
          const SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              children: faqs
                  .map((faq) =>
                      _FaqTile(question: faq.$1, answer: faq.$2))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _open
                ? AppTheme.primary.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
            width: 1.5),
        boxShadow: _open
            ? [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]
            : [],
      ),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.question,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 22, color: AppTheme.primary),
                  ),
                ],
              ),
              FadeTransition(
                opacity: _fade,
                child: _open
                    ? Column(children: [
                        const SizedBox(height: 14),
                        Text(widget.answer,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.7)),
                      ])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _CtaBanner extends StatelessWidget {
  const _CtaBanner();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
          vertical: 88, horizontal: isDesktop ? 80 : 32),
      child: Column(
        children: [
          const Text(
            'Start invoicing professionally\ntoday — for free.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Join thousands of Indian businesses using BillBook.\nNo credit card required. Free forever.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.6),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              buildGSignInButton(width: 240),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.phone_android_rounded,
                    size: 17, color: Colors.white70),
                label: const Text('Download App',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Container(
      color: const Color(0xFF0A0F1A),
      padding: EdgeInsets.symmetric(
          vertical: 64, horizontal: isDesktop ? 80 : 24),
      child: Column(
        children: [
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _FooterBrand()),
                    Expanded(
                        flex: 2,
                        child: _FooterCol('Product', [
                          'Features',
                          'GST Compliance',
                          'Pricing',
                          'Changelog'
                        ])),
                    Expanded(
                        flex: 2,
                        child: _FooterCol('Support', [
                          'Help Center',
                          'Contact Us',
                          'Privacy Policy',
                          'Terms of Service',
                        ])),
                    Expanded(
                        flex: 2,
                        child: _FooterCol(
                            'Download', ['Android App', 'iPhone App'])),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FooterBrand(),
                    const SizedBox(height: 36),
                    _FooterCol('Product', ['Features', 'Pricing', 'GST']),
                    const SizedBox(height: 28),
                    _FooterCol('Support',
                        ['Help Center', 'Contact Us', 'Privacy Policy']),
                  ],
                ),
          const SizedBox(height: 48),
          Container(height: 1, color: const Color(0xFF1E293B)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('© ${DateTime.now().year} BillBook. All rights reserved.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF475569))),
              const Text('Made with ♥ in India',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF475569))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Center(
                child: Text('BB',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('BillBook',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 14),
        const SizedBox(
          width: 260,
          child: Text(
            'Professional invoicing for modern Indian businesses. GST-compliant, cloud-synced, beautifully designed.',
            style: TextStyle(
                fontSize: 13, color: Color(0xFF64748B), height: 1.65),
          ),
        ),
      ],
    );
  }
}

class _FooterCol extends StatelessWidget {
  final String title;
  final List<String> links;
  const _FooterCol(this.title, this.links);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2)),
        const SizedBox(height: 16),
        ...links.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Text(l,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B))),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: AppTheme.textPrimary,
          height: 1.15,
          letterSpacing: -0.8),
    );
  }
}

class _SectionSubtitle extends StatelessWidget {
  final String text;
  const _SectionSubtitle(this.text);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 16, color: AppTheme.textSecondary, height: 1.65)),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final int crossCount;
  final double spacing;
  final List<Widget> children;
  const _ResponsiveGrid(
      {required this.crossCount,
      required this.spacing,
      required this.children});

  @override
  Widget build(BuildContext context) {
    if (crossCount == 1) {
      return Column(
          children: children
              .map((c) =>
                  Padding(padding: EdgeInsets.only(bottom: spacing), child: c))
              .toList());
    }
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += crossCount) {
      final rowItems =
          children.sublist(i, (i + crossCount).clamp(0, children.length));
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: e.key < rowItems.length - 1 ? spacing : 0),
                child: e.value,
              ),
            );
          }).toList(),
        ),
      ));
    }
    return Column(children: rows);
  }
}
