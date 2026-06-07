import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/business_profile.dart';
import '../../models/subscription_limits.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/paywall_sheet.dart';
import '../../widgets/template_picker.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _prefixCtrl;
  late TextEditingController _quotationPrefixCtrl;
  late TextEditingController _challanPrefixCtrl;
  late TextEditingController _taxRateCtrl;
  late TextEditingController _thankYouCtrl;
  String _currency = 'INR';
  InvoiceTemplate _defaultTemplate = InvoiceTemplate.classic;
  String? _themeColorHex;
  double _defaultTaxPercent = 0;
  bool _showQuantity = true;
  bool _saving = false;
  bool _initialized = false;
  String? _signatureBase64;
  bool _showPaymentDetailsOnInvoice = true;
  bool _showThankYouMessage = true;
  bool _showClientAcknowledgment = true;
  List<CustomField> _businessInfoFields = [];

  void _init(BusinessProfile p) {
    _prefixCtrl = TextEditingController(text: p.invoicePrefix);
    _quotationPrefixCtrl = TextEditingController(text: p.quotationPrefix);
    _challanPrefixCtrl = TextEditingController(text: p.challanPrefix);
    _taxRateCtrl = TextEditingController(
        text: p.defaultTaxPercent == 0 ? '' : p.defaultTaxPercent.toString());
    _thankYouCtrl = TextEditingController(text: p.thankYouMessage);
    _currency = p.currency;
    _defaultTemplate = p.defaultTemplate;
    _themeColorHex = p.themeColorHex;
    _defaultTaxPercent = p.defaultTaxPercent;
    _showQuantity = p.showQuantity;
    _signatureBase64 = p.signatureBase64;
    _showPaymentDetailsOnInvoice = p.showPaymentDetailsOnInvoice;
    _showThankYouMessage = p.showThankYouMessage;
    _showClientAcknowledgment = p.showClientAcknowledgment;
    _businessInfoFields = p.businessInfoFields.map((f) => CustomField(name: f.name, value: f.value)).toList();
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _prefixCtrl.dispose();
      _quotationPrefixCtrl.dispose();
      _challanPrefixCtrl.dispose();
      _taxRateCtrl.dispose();
      _thankYouCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    final cur = provider.profile;
    setState(() => _saving = true);
    await provider.updateProfile(cur.copyWith(
      currency: _currency,
      invoicePrefix: _prefixCtrl.text.trim(),
      quotationPrefix: _quotationPrefixCtrl.text.trim().isEmpty
          ? 'QT-'
          : _quotationPrefixCtrl.text.trim(),
      challanPrefix: _challanPrefixCtrl.text.trim().isEmpty
          ? 'DC-'
          : _challanPrefixCtrl.text.trim(),
      defaultTemplate: _defaultTemplate,
      themeColorHex: _themeColorHex,
      defaultTaxPercent: _defaultTaxPercent,
      showQuantity: _showQuantity,
      signatureBase64: _signatureBase64,
      showPaymentDetailsOnInvoice: _showPaymentDetailsOnInvoice,
      showThankYouMessage: _showThankYouMessage,
      thankYouMessage: _thankYouCtrl.text.trim(),
      showClientAcknowledgment: _showClientAcknowledgment,
      businessInfoFields: _businessInfoFields,
    ));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invoice settings saved'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  static const _colorPresets = [
    Color(0xFF1565C0), Color(0xFF0288D1), Color(0xFF00897B),
    Color(0xFF2E7D32), Color(0xFF558B2F), Color(0xFF6A1B9A),
    Color(0xFFAD1457), Color(0xFF781120), Color(0xFFBF360C),
    Color(0xFFE65100), Color(0xFF37474F), Color(0xFF212121),
  ];

  Future<void> _requireFeature(LimitType feature) async {
    final provider = context.read<AppProvider>();
    final info = provider.checkFeature(feature);
    if (info == null) return;
    final upgrade = await showPaywallSheet(context, info);
    if (upgrade && mounted) Navigator.pushNamed(context, '/plans');
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;
    if (!_initialized) _init(profile);
    final tier = profile.subscriptionTier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card('Numbering & Prefixes', [
              // ── Invoice prefix ──────────────────────────────────────────
              _lockedField(
                locked: !SubscriptionLimits.canUse(tier, LimitType.customPrefix),
                child: TextFormField(
                  controller: _prefixCtrl,
                  enabled: SubscriptionLimits.canUse(tier, LimitType.customPrefix),
                  decoration: InputDecoration(
                    labelText: 'Invoice Prefix',
                    hintText: 'e.g. INV-',
                    suffixIcon: SubscriptionLimits.canUse(tier, LimitType.customPrefix)
                        ? null
                        : const Icon(Icons.lock_outline, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                onTapLocked: () => _requireFeature(LimitType.customPrefix),
              ),
              const SizedBox(height: 8),
              // ── Quotation prefix ─────────────────────────────────────────
              _lockedField(
                locked: !SubscriptionLimits.canUse(tier, LimitType.customPrefix),
                child: TextFormField(
                  controller: _quotationPrefixCtrl,
                  enabled: SubscriptionLimits.canUse(tier, LimitType.customPrefix),
                  decoration: InputDecoration(
                    labelText: 'Quotation Prefix',
                    hintText: 'e.g. QT-',
                    suffixIcon: SubscriptionLimits.canUse(tier, LimitType.customPrefix)
                        ? null
                        : const Icon(Icons.lock_outline, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                onTapLocked: () => _requireFeature(LimitType.customPrefix),
              ),
              const SizedBox(height: 8),
              // ── Challan prefix ───────────────────────────────────────────
              _lockedField(
                locked: !SubscriptionLimits.canUse(tier, LimitType.customPrefix),
                child: TextFormField(
                  controller: _challanPrefixCtrl,
                  enabled: SubscriptionLimits.canUse(tier, LimitType.customPrefix),
                  decoration: InputDecoration(
                    labelText: 'Delivery Challan Prefix',
                    hintText: 'e.g. DC-',
                    suffixIcon: SubscriptionLimits.canUse(tier, LimitType.customPrefix)
                        ? null
                        : const Icon(Icons.lock_outline, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                onTapLocked: () => _requireFeature(LimitType.customPrefix),
              ),
              const SizedBox(height: 12),
              _currencyDropdown(tier),
              const SizedBox(height: 8),
              // ── Next-number previews ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _previewRow(Icons.receipt_long_outlined, 'Invoice',
                        '${_prefixCtrl.text.isEmpty ? 'INV-' : _prefixCtrl.text}${profile.nextInvoiceNumber.toString().padLeft(4, '0')}'),
                    const SizedBox(height: 4),
                    _previewRow(Icons.description_outlined, 'Quotation',
                        '${_quotationPrefixCtrl.text.isEmpty ? 'QT-' : _quotationPrefixCtrl.text}${profile.nextQuotationNumber.toString().padLeft(4, '0')}'),
                    const SizedBox(height: 4),
                    _previewRow(Icons.local_shipping_outlined, 'Delivery Challan',
                        '${_challanPrefixCtrl.text.isEmpty ? 'DC-' : _challanPrefixCtrl.text}${profile.nextChallanNumber.toString().padLeft(4, '0')}'),
                    const SizedBox(height: 4),
                    _previewRow(Icons.remove_circle_outline, 'Credit Note',
                        'CN-${profile.nextCreditNoteNumber.toString().padLeft(4, '0')}'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _card('Template', [
              InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Default Invoice Template'),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: TemplatePicker(
                    selected: _defaultTemplate,
                    onSelected: (tpl) async {
                      final allowedCount =
                          SubscriptionLimits.templates[tier]!;
                      final tplIndex =
                          InvoiceTemplate.values.indexOf(tpl);
                      if (allowedCount != -1 && tplIndex >= allowedCount) {
                        await _requireFeature(LimitType.templates);
                        return;
                      }
                      setState(() => _defaultTemplate = tpl);
                    },
                    lockedAfterIndex: SubscriptionLimits.templates[tier]! == -1
                        ? null
                        : SubscriptionLimits.templates[tier],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _colorPickerSection(),
            ]),
            SizedBox(height: 16),
            _card('Tax & Quantity', [
              _taxRateSelector(),
              SizedBox(height: 4),
              SwitchListTile(
                value: _showQuantity,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _showQuantity = v),
                title: Text('Show Quantity Field',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.onCard(context))),
                subtitle: Text(
                    'Hide for service-based invoices where qty is always 1',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context))),
              ),
            ]),
            SizedBox(height: 16),
            _card('Signature & Payment Footer', [
              _signatureRow(),
              SizedBox(height: 4),
              SwitchListTile(
                value: _showPaymentDetailsOnInvoice,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) =>
                    setState(() => _showPaymentDetailsOnInvoice = v),
                title: Text('Show Bank & UPI Details',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.onCard(context))),
                subtitle: Text(
                    'Prints payment info and UPI QR code at the bottom of every invoice',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context))),
              ),
            ]),
            SizedBox(height: 16),
            _card('Thank You Message', [
              SwitchListTile(
                value: _showThankYouMessage,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) =>
                    setState(() => _showThankYouMessage = v),
                title: Text('Show Thank You Message',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.onCard(context))),
                subtitle: Text(
                    'Display a thank you message at the bottom of invoices',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context))),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thankYouCtrl,
                enabled: _showThankYouMessage,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Thank You Message',
                  hintText: 'e.g., Thank you for your business!',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                validator: (v) {
                  if (_showThankYouMessage && (v?.trim().isEmpty ?? true)) {
                    return 'Please enter a thank you message';
                  }
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 16),
            _businessInfoCard(),
            SizedBox(height: 16),
            _card('Client Acknowledgment', [
              SwitchListTile(
                value: _showClientAcknowledgment,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) =>
                    setState(() => _showClientAcknowledgment = v),
                title: Text('Show Client Receipt / Acknowledgment',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.onCard(context))),
                subtitle: Text(
                    'Display signature and acknowledgment section for advocates, CAs, consultants',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context))),
              ),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48)),
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(IconData icon, String label, String number) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.subtext(context)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: AppTheme.subtext(context)),
        ),
        Text(
          number,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.onCard(context),
          ),
        ),
      ],
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context))),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps [child] in a transparent tap interceptor when [locked] is true,
  /// so the underlying field is visually present but interactions call [onTapLocked].
  Widget _lockedField({
    required bool locked,
    required Widget child,
    required VoidCallback onTapLocked,
  }) {
    if (!locked) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: GestureDetector(
            onTap: onTapLocked,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _currencyDropdown(SubscriptionTier tier) {
    const currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD'];
    final multiCurrencyAllowed =
        SubscriptionLimits.canUse(tier, LimitType.multiCurrency);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Default Currency',
        suffixIcon: multiCurrencyAllowed
            ? null
            : const Icon(Icons.lock_outline, size: 18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currency,
          isDense: true,
          items: currencies.map((c) {
            final locked = !multiCurrencyAllowed && c != 'INR';
            return DropdownMenuItem(
              value: c,
              child: Row(
                children: [
                  Text(c,
                      style: TextStyle(
                          color: locked ? AppTheme.textSecondary : null)),
                  if (locked) ...[
                    SizedBox(width: 6),
                    Icon(Icons.lock_outline,
                        size: 13, color: AppTheme.subtext(context)),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (v) async {
            if (v == null) return;
            if (!multiCurrencyAllowed && v != 'INR') {
              await _requireFeature(LimitType.multiCurrency);
              return;
            }
            setState(() => _currency = v);
          },
        ),
      ),
    );
  }

  Widget _colorPickerSection() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Template Accent Color'),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            GestureDetector(
              onTap: () => setState(() => _themeColorHex = null),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _themeColorHex == null
                        ? AppTheme.primary
                        : AppTheme.divider,
                    width: _themeColorHex == null ? 3 : 1,
                  ),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _themeColorHex == null
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            ..._colorPresets.map((c) {
              final hex = c.toARGB32().toRadixString(16).substring(2).toUpperCase();
              final isSelected = _themeColorHex == hex;
              return GestureDetector(
                onTap: () => setState(() => _themeColorHex = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: c.withValues(alpha: 0.5),
                            blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _taxRateSelector() {
    const presets = [0.0, 5.0, 12.0, 18.0, 28.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _taxRateCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Default Tax Rate',
            hintText: '0',
            suffixText: '%',
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null && parsed >= 0 && parsed <= 100) {
              setState(() => _defaultTaxPercent = parsed);
            }
          },
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final n = double.tryParse(v);
            if (n == null || n < 0 || n > 100) return 'Enter 0–100';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: presets.map((r) {
            final selected = _defaultTaxPercent == r;
            return ChoiceChip(
              label: Text(r == 0 ? 'No Tax' : '${r.toStringAsFixed(0)}%'),
              selected: selected,
              onSelected: (_) => setState(() {
                _defaultTaxPercent = r;
                _taxRateCtrl.text =
                    r == 0 ? '' : r.toStringAsFixed(0);
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _signatureRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Authorized Signature',
            style: TextStyle(fontSize: 13, color: AppTheme.onCard(context))),
        const SizedBox(height: 8),
        if (_signatureBase64 != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 130,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.outline(context)),
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.memory(
                    base64Decode(_signatureBase64!),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: const Text('Change'),
                    onPressed: _pickSignature,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(110, 36)),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppTheme.error),
                    label: const Text('Remove',
                        style: TextStyle(color: AppTheme.error)),
                    onPressed: () =>
                        setState(() => _signatureBase64 = null),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(110, 36)),
                  ),
                ],
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Upload Signature Image'),
              onPressed: _pickSignature,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
            ),
          ),
        SizedBox(height: 4),
        Text(
          'Shown at the bottom of every invoice as "Authorized Signatory"',
          style: TextStyle(fontSize: 11, color: AppTheme.subtext(context)),
        ),
      ],
    );
  }

  Widget _businessInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registration & Compliance Info',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onCard(context))),
                      const SizedBox(height: 2),
                      Text(
                        'PAN, FSSAI, MSME, Trade Licence, etc. — shown on every invoice',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.subtext(context)),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: () => _showInfoFieldDialog(),
                ),
              ],
            ),
          ),
          if (_businessInfoFields.isNotEmpty) ...[
            const Divider(height: 1),
            ...List.generate(_businessInfoFields.length, (i) {
              final f = _businessInfoFields[i];
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: Text(f.name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onCard(context))),
                    subtitle: Text(f.value,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.subtext(context))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showInfoFieldDialog(index: i),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.error),
                          onPressed: () =>
                              setState(() => _businessInfoFields.removeAt(i)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  if (i < _businessInfoFields.length - 1)
                    Divider(height: 1, indent: 16, color: AppTheme.outline(context)),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _showInfoFieldDialog({int? index}) async {
    final existing = index != null ? _businessInfoFields[index] : null;
    final labelCtrl = TextEditingController(text: existing?.name ?? '');
    final valueCtrl = TextEditingController(text: existing?.value ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? labelError;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: Text(index == null ? 'Add Field' : 'Edit Field'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Label',
                      hintText: 'e.g. PAN Number, FSSAI Licence',
                      errorText: labelError,
                    ),
                    onChanged: (_) {
                      if (labelError != null) {
                        setDlgState(() => labelError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      hintText: 'e.g. ABCDE1234F',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty) {
                    setDlgState(() => labelError = 'Label is required');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    final label = labelCtrl.text.trim();
    final value = valueCtrl.text.trim();
    // Defer disposal to let the dialog's exit animation finish before the
    // TextFields release their references to the controllers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      labelCtrl.dispose();
      valueCtrl.dispose();
    });

    if (confirmed != true || !mounted) return;
    setState(() {
      if (index == null) {
        _businessInfoFields.add(CustomField(name: label, value: value));
      } else {
        _businessInfoFields[index] = CustomField(name: label, value: value);
      }
    });
  }

  Future<void> _pickSignature() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _signatureBase64 = base64Encode(bytes));
  }
}
