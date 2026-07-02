import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../models/subscription_limits.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/gst_utils.dart';
import '../widgets/template_picker.dart';
import 'dashboard_screen.dart';
import 'settings/payment_methods_screen.dart';
import 'settings/services_screen.dart';
import 'settings/verification_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _initialized = false;
  bool _saving = false;

  // ── Step 0: Business Profile ──────────────────────────────────────
  final _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  String? _logoBase64;

  // ── Step 1: Plan ──────────────────────────────────────────────────
  SubscriptionTier _selectedTier = SubscriptionTier.free;

  // ── Step 2: GST Registration ──────────────────────────────────────
  late final TextEditingController _gstinCtrl;
  bool _isCompositionDealer = false;
  String? _defaultPlaceOfSupply;
  bool _defaultReverseCharge = false;

  // ── Step 3: Invoice Settings ──────────────────────────────────────
  InvoiceTemplate _template = InvoiceTemplate.classic;
  String _currency = 'INR';
  double _taxRate = 18.0;
  late final TextEditingController _prefixCtrl;

  static const _stepLabels = [
    'Profile', 'GST', 'Invoice', 'Items', 'Payments', 'Verify', 'Plan'
  ];

  static const _saffron = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController();
    _emailCtrl   = TextEditingController();
    _phoneCtrl   = TextEditingController();
    _addressCtrl = TextEditingController();
    _cityCtrl    = TextEditingController();
    _stateCtrl   = TextEditingController();
    _gstinCtrl   = TextEditingController();
    _prefixCtrl  = TextEditingController(text: 'INV-');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final p = context.read<AppProvider>().profile;
      _nameCtrl.text    = p.name;
      _emailCtrl.text   = p.email;
      _phoneCtrl.text   = p.phone;
      _addressCtrl.text = p.address;
      _cityCtrl.text    = p.city;
      _stateCtrl.text   = p.state;
      _gstinCtrl.text   = p.gstin ?? '';
      _logoBase64             = p.logoBase64;
      _selectedTier           = SubscriptionTier.free; // forced until IAP launches
      _isCompositionDealer    = p.isCompositionDealer;
      _defaultPlaceOfSupply   = p.defaultPlaceOfSupply;
      _defaultReverseCharge   = p.defaultReverseCharge;
      _template               = p.defaultTemplate;
      _currency               = p.currency;
      _taxRate                = p.defaultTaxPercent > 0 ? p.defaultTaxPercent : 18.0;
      if (p.invoicePrefix.isNotEmpty) _prefixCtrl.text = p.invoicePrefix;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl,
      _cityCtrl, _stateCtrl, _gstinCtrl, _prefixCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String get _gstinUpper => _gstinCtrl.text.trim().toUpperCase();
  bool get _hasGstin => _gstinUpper.isNotEmpty;
  bool get _gstinValid => _hasGstin && isValidGstin(_gstinUpper);
  String? get _detectedState {
    final code = extractGstStateCode(_gstinUpper);
    if (code == null) return null;
    return gstStateCodeToName[code];
  }

  int? get _templateLockIndex {
    final limit = SubscriptionLimits.templates[_selectedTier]!;
    return limit == -1 ? null : limit;
  }

  // ── Navigation ────────────────────────────────────────────────────

  Future<void> _goNext() async {
    FocusScope.of(context).unfocus();
    switch (_step) {
      case 0:
        if (!_profileFormKey.currentState!.validate()) return;
        await _saveProfile();
      case 1:
        if (_hasGstin && !_gstinValid) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Enter a valid 15-character GSTIN or leave empty to skip')));
          return;
        }
        await _saveGstSetup();
      case 2:
        await _saveInvoiceSettings();
      case 6:
        await _savePlan();
    }
    if (_step == _stepLabels.length - 1) {
      await _finish();
      return;
    }
    _pageController.nextPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    setState(() => _step++);
  }

  void _goBack() {
    if (_step == 0) return;
    _pageController.previousPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    setState(() => _step--);
  }

  Future<void> _skipStep() async {
    if (_step == _stepLabels.length - 1) {
      await _finish();
      return;
    }
    _pageController.nextPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    setState(() => _step++);
  }

  // ── Save helpers ──────────────────────────────────────────────────

  BusinessProfile _cur() => context.read<AppProvider>().profile;

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final cur = _cur();
    await context.read<AppProvider>().updateProfile(BusinessProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      country: cur.country,
      postalCode: cur.postalCode,
      gstin: cur.gstin, // GSTIN is saved in GST step, not here
      website: cur.website,
      logoBase64: _logoBase64,
      headerFields: cur.headerFields,
      currency: cur.currency,
      invoicePrefix: cur.invoicePrefix,
      nextInvoiceNumber: cur.nextInvoiceNumber,
      defaultTemplate: cur.defaultTemplate,
      themeColorHex: cur.themeColorHex,
      defaultTaxPercent: cur.defaultTaxPercent,
      showQuantity: cur.showQuantity,
      itemLabel: cur.itemLabel,
      paymentMethods: cur.paymentMethods,
      verificationStatus: cur.verificationStatus,
      verificationNotes: cur.verificationNotes,
      verificationSubmittedAt: cur.verificationSubmittedAt,
      subscriptionTier: cur.subscriptionTier,
      signatureBase64: cur.signatureBase64,
      showPaymentDetailsOnInvoice: cur.showPaymentDetailsOnInvoice,
      defaultPlaceOfSupply: cur.defaultPlaceOfSupply,
      defaultReverseCharge: cur.defaultReverseCharge,
      isCompositionDealer: cur.isCompositionDealer,
    ));
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _savePlan() async {
    setState(() => _saving = true);
    // Reset template to classic if it exceeds the tier's template limit.
    final lock = _templateLockIndex;
    if (lock != null && _template.index >= lock) {
      _template = InvoiceTemplate.classic;
    }
    final cur = _cur();
    await context.read<AppProvider>().updateProfile(BusinessProfile(
      name: cur.name, email: cur.email, phone: cur.phone,
      address: cur.address, city: cur.city, state: cur.state,
      country: cur.country, postalCode: cur.postalCode,
      gstin: cur.gstin, website: cur.website, logoBase64: cur.logoBase64,
      headerFields: cur.headerFields, currency: cur.currency,
      invoicePrefix: cur.invoicePrefix, nextInvoiceNumber: cur.nextInvoiceNumber,
      defaultTemplate: cur.defaultTemplate, themeColorHex: cur.themeColorHex,
      defaultTaxPercent: cur.defaultTaxPercent, showQuantity: cur.showQuantity,
      itemLabel: cur.itemLabel, paymentMethods: cur.paymentMethods,
      verificationStatus: cur.verificationStatus,
      verificationNotes: cur.verificationNotes,
      verificationSubmittedAt: cur.verificationSubmittedAt,
      subscriptionTier: SubscriptionTier.free, // forced until IAP launches
      signatureBase64: cur.signatureBase64,
      showPaymentDetailsOnInvoice: cur.showPaymentDetailsOnInvoice,
      defaultPlaceOfSupply: cur.defaultPlaceOfSupply,
      defaultReverseCharge: cur.defaultReverseCharge,
      isCompositionDealer: cur.isCompositionDealer,
    ));
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveGstSetup() async {
    setState(() => _saving = true);
    final cur = _cur();
    final gstin = _hasGstin ? _gstinUpper : null;
    await context.read<AppProvider>().updateProfile(BusinessProfile(
      name: cur.name, email: cur.email, phone: cur.phone,
      address: cur.address, city: cur.city, state: cur.state,
      country: cur.country, postalCode: cur.postalCode,
      gstin: gstin, website: cur.website, logoBase64: cur.logoBase64,
      headerFields: cur.headerFields, currency: cur.currency,
      invoicePrefix: cur.invoicePrefix, nextInvoiceNumber: cur.nextInvoiceNumber,
      defaultTemplate: cur.defaultTemplate, themeColorHex: cur.themeColorHex,
      defaultTaxPercent: _taxRate,
      showQuantity: cur.showQuantity, itemLabel: cur.itemLabel,
      paymentMethods: cur.paymentMethods,
      verificationStatus: cur.verificationStatus,
      verificationNotes: cur.verificationNotes,
      verificationSubmittedAt: cur.verificationSubmittedAt,
      subscriptionTier: cur.subscriptionTier,
      signatureBase64: cur.signatureBase64,
      showPaymentDetailsOnInvoice: cur.showPaymentDetailsOnInvoice,
      defaultPlaceOfSupply: _defaultPlaceOfSupply,
      defaultReverseCharge: _defaultReverseCharge,
      isCompositionDealer: _isCompositionDealer,
    ));
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveInvoiceSettings() async {
    setState(() => _saving = true);
    final cur = _cur();
    await context.read<AppProvider>().updateProfile(BusinessProfile(
      name: cur.name, email: cur.email, phone: cur.phone,
      address: cur.address, city: cur.city, state: cur.state,
      country: cur.country, postalCode: cur.postalCode,
      gstin: cur.gstin, website: cur.website, logoBase64: cur.logoBase64,
      headerFields: cur.headerFields,
      currency: _currency,
      invoicePrefix: _prefixCtrl.text.trim().isEmpty ? 'INV-' : _prefixCtrl.text.trim(),
      nextInvoiceNumber: cur.nextInvoiceNumber,
      defaultTemplate: _template,
      themeColorHex: cur.themeColorHex,
      defaultTaxPercent: cur.defaultTaxPercent,
      showQuantity: cur.showQuantity, itemLabel: cur.itemLabel,
      paymentMethods: cur.paymentMethods,
      verificationStatus: cur.verificationStatus,
      verificationNotes: cur.verificationNotes,
      verificationSubmittedAt: cur.verificationSubmittedAt,
      subscriptionTier: cur.subscriptionTier,
      signatureBase64: cur.signatureBase64,
      showPaymentDetailsOnInvoice: cur.showPaymentDetailsOnInvoice,
      defaultPlaceOfSupply: cur.defaultPlaceOfSupply,
      defaultReverseCharge: cur.defaultReverseCharge,
      isCompositionDealer: cur.isCompositionDealer,
    ));
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await context.read<AppProvider>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  // ── Logo picker ───────────────────────────────────────────────────

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400, maxHeight: 200, imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _logoBase64 = base64Encode(bytes));
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.card(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepper(),
            const Divider(height: 1),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildProfileStep(),
                  _buildGstStep(),
                  _buildInvoiceStep(),
                  _buildServicesStep(),
                  _buildPaymentsStep(),
                  _buildVerifyStep(),
                  _buildPlanStep(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Stepper ───────────────────────────────────────────────────────

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          Row(
            children: List.generate(_stepLabels.length, (i) {
              final done   = i < _step;
              final active = i == _step;
              final isGst  = i == 1;
              final color  = (done || active)
                  ? (isGst ? _saffron : AppTheme.primary)
                  : const Color(0xFFDDDDDD);
              return Expanded(
                child: Row(
                  children: [
                    if (i > 0)
                      Expanded(child: Container(height: 2,
                          color: done
                              ? (i <= 1 ? _saffron : AppTheme.primary)
                              : const Color(0xFFDDDDDD))),
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      child: done
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : Center(
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: active ? Colors.white : const Color(0xFFAAAAAA),
                                  )),
                            ),
                    ),
                    if (i < _stepLabels.length - 1)
                      Expanded(child: Container(height: 2,
                          color: done
                              ? (i < 1 ? _saffron : AppTheme.primary)
                              : const Color(0xFFDDDDDD))),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(_stepLabels.length, (i) {
              final active = i == _step;
              return Expanded(
                child: Text(
                  _stepLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active
                        ? (i == 1 ? _saffron : AppTheme.primary)
                        : AppTheme.textSecondary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLast  = _step == _stepLabels.length - 1;
    // GST step (1) through Verify (5) are skippable; Plan (last) is not
    final canSkip = _step >= 1 && !isLast;
    final isGstStep = _step == 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        border: Border(top: BorderSide(color: AppTheme.outline(context))),
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton.icon(
              onPressed: _saving ? null : _goBack,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
            )
          else
            const SizedBox(width: 72),
          const Spacer(),
          if (canSkip) ...[
            TextButton(
              onPressed: _saving ? null : _skipStep,
              child: Text(isGstStep ? 'Skip GST' : 'Skip',
                  style: isGstStep
                      ? const TextStyle(color: _saffron)
                      : null),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            onPressed: _saving ? null : _goNext,
            style: isGstStep
                ? FilledButton.styleFrom(backgroundColor: _saffron)
                : null,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 16),
            label: Text(isLast ? 'Continue with Free' : 'Continue'),
          ),
        ],
      ),
    );
  }

  // ── Shared step header ────────────────────────────────────────────

  Widget _stepHeader(IconData icon, String title, String subtitle,
      {Color? iconBg, Color? iconColor, Widget? badge}) {
    final bg  = iconBg  ?? AppTheme.primary.withValues(alpha: 0.1);
    final ic  = iconColor ?? AppTheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: ic, size: 26),
            ),
            if (badge != null) ...[const SizedBox(width: 10), badge],
          ],
        ),
        SizedBox(height: 14),
        Text(title,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.onCard(context))),
        SizedBox(height: 6),
        Text(subtitle,
            style: TextStyle(
                fontSize: 13, color: AppTheme.subtext(context), height: 1.4)),
      ],
    );
  }

  // ── STEP 0: Business Profile ──────────────────────────────────────

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(Icons.business_outlined, 'Business Profile',
                'Tell us about your business — this appears on every invoice you send.'),
            const SizedBox(height: 24),

            // Logo
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outline(context)),
                      ),
                      child: _logoBase64 != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.memory(base64Decode(_logoBase64!),
                                  fit: BoxFit.contain))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 28,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                SizedBox(height: 4),
                                Text('Add Logo',
                                    style: TextStyle(fontSize: 11, color: AppTheme.subtext(context))),
                              ],
                            ),
                    ),
                  ),
                  if (_logoBase64 != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _logoBase64 = null),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                prefixIcon: Icon(Icons.storefront_outlined, size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Business name is required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Street Address',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateCtrl,
                    decoration: const InputDecoration(labelText: 'State'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── STEP 1: Plan ──────────────────────────────────────────────────

  Widget _buildPlanStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(Icons.workspace_premium_outlined, 'Your Plan',
              'You\'re all set! Start with the Free plan. Paid plans with in-app purchase are coming soon.'),
          const SizedBox(height: 20),

          // Coming soon banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.08),
                  const Color(0xFF7B1FA2).withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag_outlined,
                      color: AppTheme.primary, size: 18),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In-App Purchases Coming Soon',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                      SizedBox(height: 2),
                      Text(
                        'Upgrade to Lite, Pro, or Premium will be available in the next update.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.subtext(context),
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ...SubscriptionTier.values.map((t) => _planTile(t, comingSoon: t != SubscriptionTier.free)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _planTile(SubscriptionTier tier, {bool comingSoon = false}) {
    const colors = {
      SubscriptionTier.free:    Color(0xFF546E7A),
      SubscriptionTier.lite:    Color(0xFF0288D1),
      SubscriptionTier.pro:     Color(0xFF7B1FA2),
      SubscriptionTier.premium: Color(0xFFE65100),
    };
    const icons = {
      SubscriptionTier.free:    Icons.free_breakfast_outlined,
      SubscriptionTier.lite:    Icons.bolt_outlined,
      SubscriptionTier.pro:     Icons.rocket_launch_outlined,
      SubscriptionTier.premium: Icons.workspace_premium,
    };
    const names = {
      SubscriptionTier.free:    'Free',
      SubscriptionTier.lite:    'Lite',
      SubscriptionTier.pro:     'Pro',
      SubscriptionTier.premium: 'Premium',
    };
    const features = {
      SubscriptionTier.free:    '5 invoices/mo · 10 clients · Classic template only',
      SubscriptionTier.lite:    '50 invoices/mo · 50 clients · 3 templates',
      SubscriptionTier.pro:     'Unlimited invoices · All templates · Multi-currency · GST Reports',
      SubscriptionTier.premium: 'Everything in Pro · Message templates · Priority support',
    };

    final color    = colors[tier]!;
    final selected = _selectedTier == tier;
    final price    = tierPrices[tier]!;
    final dimmed   = comingSoon ? 0.4 : 1.0;

    return GestureDetector(
      onTap: comingSoon
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'In-app purchases coming soon! You\'ll be able to upgrade once billing is live.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          : null,
      child: Opacity(
        opacity: comingSoon ? 0.55 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? color : const Color(0xFFE0E0E0),
                width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12 * dimmed), shape: BoxShape.circle),
                child: Icon(icons[tier], color: color, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(names[tier]!,
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: color, fontSize: 14)),
                        if (comingSoon) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppTheme.textSecondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('COMING SOON',
                                style: TextStyle(
                                    color: AppTheme.subtext(context),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ] else if (tier == SubscriptionTier.free) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: color, borderRadius: BorderRadius.circular(4)),
                            child: const Text('YOUR PLAN',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    price.yearlyRupees == 0
                        ? Text('Free forever',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.subtext(context)))
                        : Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
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
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.subtext(context),
                                    decoration: TextDecoration.lineThrough),
                              ),
                              Text(
                                '₹${price.yearlyRupees}/yr  ·  ₹${price.monthlyRupees}/mo',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.subtext(context)),
                              ),
                            ],
                          ),
                    const SizedBox(height: 2),
                    Text(features[tier]!,
                        style:
                            TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              comingSoon
                  ? const Icon(Icons.lock_outline,
                      color: Color(0xFFCCCCCC), size: 18)
                  : (selected
                      ? Icon(Icons.check_circle, color: color, size: 20)
                      : const Icon(Icons.radio_button_unchecked,
                          color: Color(0xFFCCCCCC), size: 20)),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 2: GST Registration ──────────────────────────────────────

  Widget _buildGstStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            Icons.account_balance_outlined,
            'GST Registration',
            'Set up your GSTIN so invoices show CGST/SGST/IGST splits automatically. You can skip this and set it up later.',
            iconBg: _saffron.withValues(alpha: 0.10),
            iconColor: _saffron,
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _saffron.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _saffron.withValues(alpha: 0.3)),
              ),
              child: const Text('Optional',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _saffron)),
            ),
          ),
          const SizedBox(height: 24),

          // ── GSTIN field ──────────────────────────────────────────
          TextFormField(
            controller: _gstinCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(15),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'GSTIN',
              hintText: '22AAAAA0000A1Z5',
              helperText: '15-character GST Identification Number',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              suffixIcon: _hasGstin
                  ? Icon(
                      _gstinValid ? Icons.check_circle : Icons.cancel_outlined,
                      color: _gstinValid ? AppTheme.success : AppTheme.error,
                      size: 20,
                    )
                  : null,
            ),
          ),

          // Detected state badge
          if (_hasGstin) ...[
            const SizedBox(height: 10),
            _detectedState != null
                ? Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: AppTheme.success),
                      const SizedBox(width: 4),
                      Text(
                        'Registered in: $_detectedState (${extractGstStateCode(_gstinUpper)})',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.success),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          size: 14, color: AppTheme.error),
                      const SizedBox(width: 4),
                      const Text('Invalid GSTIN format',
                          style: TextStyle(fontSize: 12, color: AppTheme.error)),
                    ],
                  ),
          ],
          const SizedBox(height: 16),

          // ── Composition scheme ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.outline(context)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              title: const Text('Composition Scheme Dealer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text(
                  'Pays fixed % of turnover · cannot collect GST from customers',
                  style: TextStyle(fontSize: 11)),
              value: _isCompositionDealer,
              activeThumbColor: _saffron,
              onChanged: (v) => setState(() => _isCompositionDealer = v),
            ),
          ),
          const SizedBox(height: 12),

          // ── Place of Supply ──────────────────────────────────────
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Default Place of Supply',
              helperText: 'State where your goods/services are usually delivered',
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: indianStatesForGst.contains(_defaultPlaceOfSupply)
                    ? _defaultPlaceOfSupply
                    : null,
                hint: Text('Select state',
                    style: TextStyle(fontSize: 14)),
                isDense: true,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('— Not set —',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.subtext(context))),
                  ),
                  ...indianStatesForGst.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s,
                            style: const TextStyle(fontSize: 14)),
                      )),
                ],
                onChanged: (v) =>
                    setState(() => _defaultPlaceOfSupply = v),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Default GST Rate ─────────────────────────────────────
          Text('Default GST Rate',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onCard(context))),
          SizedBox(height: 4),
          Text('Applied to new invoice line items by default',
              style: TextStyle(fontSize: 11, color: AppTheme.subtext(context))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [0.0, 5.0, 12.0, 18.0, 28.0].map((r) {
              final sel = _taxRate == r;
              return ChoiceChip(
                label: Text(r == 0 ? 'Nil / 0%' : '${r.toStringAsFixed(0)}%'),
                selected: sel,
                selectedColor: _saffron,
                labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : AppTheme.textPrimary),
                side: BorderSide(
                    color: sel ? _saffron : AppTheme.divider),
                onSelected: (_) => setState(() => _taxRate = r),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ── Reverse Charge ───────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.outline(context)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              title: const Text('Reverse Charge by Default',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text(
                  'Tax liability shifts to the recipient (RCM)',
                  style: TextStyle(fontSize: 11)),
              value: _defaultReverseCharge,
              activeThumbColor: _saffron,
              onChanged: (v) =>
                  setState(() => _defaultReverseCharge = v),
            ),
          ),
          const SizedBox(height: 12),

          // ── Skip note ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _saffron.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _saffron.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: _saffron.withValues(alpha: 0.7)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GST setup is optional. You can configure it later from Settings → GST Setup. Tap "Skip GST" to continue.',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 3: Invoice Settings ──────────────────────────────────────

  Widget _buildInvoiceStep() {
    final lockIdx = _templateLockIndex;

    // Ensure selected template is within allowed range for this tier.
    if (lockIdx != null && _template.index >= lockIdx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _template.index >= lockIdx) {
          setState(() => _template = InvoiceTemplate.classic);
        }
      });
    }

    final tierName = {
      SubscriptionTier.free:    'Free',
      SubscriptionTier.lite:    'Lite',
      SubscriptionTier.pro:     'Pro',
      SubscriptionTier.premium: 'Premium',
    }[_selectedTier]!;

    final unlockedCount = lockIdx ?? InvoiceTemplate.values.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(Icons.receipt_long_outlined, 'Invoice Settings',
              'Customise how your invoices look and how numbers are formatted.'),
          const SizedBox(height: 24),

          // Template section
          Row(
            children: [
              Text('Invoice Template',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context))),
              const Spacer(),
              // Tier badge showing how many templates are unlocked
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lockIdx == null
                      ? '$tierName · All templates'
                      : '$tierName · $unlockedCount of ${InvoiceTemplate.values.length}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (lockIdx != null && lockIdx < InvoiceTemplate.values.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Locked templates require a higher plan. Upgrade in Settings after setup.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary.withValues(alpha: 0.8)),
              ),
            ),
          TemplatePicker(
            selected: _template,
            onSelected: (tpl) {
              if (lockIdx != null && tpl.index >= lockIdx) return;
              setState(() => _template = tpl);
            },
            lockedAfterIndex: lockIdx,
          ),
          const SizedBox(height: 20),

          InputDecorator(
            decoration: const InputDecoration(labelText: 'Default Currency'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currency,
                isDense: true,
                items: ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _currency = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _prefixCtrl,
            decoration: const InputDecoration(
              labelText: 'Invoice Number Prefix',
              hintText: 'INV-',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 4: Items & Services ──────────────────────────────────────

  Widget _buildServicesStep() {
    final count = context.watch<AppProvider>().serviceItems.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(Icons.inventory_2_outlined, 'Items & Services',
              'Pre-add your products or services so you can pick them quickly when creating invoices.'),
          const SizedBox(height: 24),
          _launchCard(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF6A1B9A),
            title: count == 0
                ? 'No items added yet'
                : '$count item${count == 1 ? '' : 's'} added',
            subtitle: count == 0
                ? 'Add your products or services to speed up invoice creation'
                : 'Tap to manage your catalog',
            buttonLabel: count == 0 ? 'Add Items' : 'Manage Items',
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ServicesScreen()));
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _optionalNote(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 5: Payment Methods ───────────────────────────────────────

  Widget _buildPaymentsStep() {
    final count = context.watch<AppProvider>().profile.paymentMethods.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(Icons.account_balance_wallet_outlined, 'Payment Methods',
              'Add your bank account or UPI ID so clients can pay directly from the invoice.'),
          const SizedBox(height: 24),
          _launchCard(
            icon: Icons.account_balance_outlined,
            color: const Color(0xFFBF360C),
            title: count == 0
                ? 'No payment methods added'
                : '$count method${count == 1 ? '' : 's'} configured',
            subtitle: count == 0
                ? 'Bank accounts and UPI IDs appear on your invoices'
                : 'Tap to manage payment methods',
            buttonLabel:
                count == 0 ? 'Add Payment Method' : 'Manage Payments',
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()));
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _optionalNote(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 6: Business Verification ────────────────────────────────

  Widget _buildVerifyStep() {
    final status = context.watch<AppProvider>().profile.verificationStatus;

    final Map<VerificationStatus, (String, String, IconData, Color)> meta = {
      VerificationStatus.unverified: (
        'Not verified yet',
        'Verified businesses get a badge on their invoices and higher trust from clients.',
        Icons.shield_outlined,
        const Color(0xFF546E7A),
      ),
      VerificationStatus.pending: (
        'Review in progress',
        "Your documents are being reviewed. We'll notify you within 24–48 hours.",
        Icons.hourglass_top_outlined,
        const Color(0xFFE65100),
      ),
      VerificationStatus.verified: (
        'Business verified ✓',
        'Your business is verified. Invoices show a verified badge.',
        Icons.verified,
        const Color(0xFF2E7D32),
      ),
      VerificationStatus.rejected: (
        'Re-submit documents',
        'Verification was rejected. Tap to review and re-submit your documents.',
        Icons.cancel_outlined,
        const Color(0xFFC62828),
      ),
    };

    final (title, subtitle, icon, color) = meta[status]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(Icons.verified_outlined, 'Business Verification',
              'Verified businesses get a badge on every invoice, increasing trust with clients.'),
          const SizedBox(height: 24),
          _launchCard(
            icon: icon,
            color: color,
            title: title,
            subtitle: subtitle,
            buttonLabel: status == VerificationStatus.verified
                ? 'View Verification'
                : 'Start Verification',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VerificationScreen())),
          ),
          const SizedBox(height: 12),
          _optionalNote(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────

  Widget _launchCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context))),
                    SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.subtext(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onTap,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.1),
                foregroundColor: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionalNote() {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: AppTheme.subtext(context)),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'This step is optional — you can set it up later from Settings.',
            style: TextStyle(fontSize: 11, color: AppTheme.subtext(context)),
          ),
        ),
      ],
    );
  }
}
