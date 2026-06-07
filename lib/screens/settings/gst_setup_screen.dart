import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/gst_utils.dart';

class GstSetupScreen extends StatefulWidget {
  const GstSetupScreen({super.key});

  @override
  State<GstSetupScreen> createState() => _GstSetupScreenState();
}

class _GstSetupScreenState extends State<GstSetupScreen> {
  late TextEditingController _gstinCtrl;
  late TextEditingController _taxCtrl;
  String? _defaultPlaceOfSupply;
  bool _defaultReverseCharge = false;
  bool _isCompositionDealer = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>().profile;
    _gstinCtrl = TextEditingController(text: p.gstin ?? '');
    _taxCtrl = TextEditingController(
        text: p.defaultTaxPercent == 0 ? '' : p.defaultTaxPercent.toString());
    _defaultPlaceOfSupply = p.defaultPlaceOfSupply;
    _defaultReverseCharge = p.defaultReverseCharge;
    _isCompositionDealer = p.isCompositionDealer;
  }

  @override
  void dispose() {
    _gstinCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  String get _gstinUpper => _gstinCtrl.text.trim().toUpperCase();
  bool get _hasGstin => _gstinUpper.isNotEmpty;
  bool get _gstinValid => _hasGstin && isValidGstin(_gstinUpper);
  String? get _detectedState {
    if (!_hasGstin) return null;
    final code = extractGstStateCode(_gstinUpper);
    if (code == null) return null;
    return gstStateCodeToName[code];
  }

  GstSupplyType get _previewSupplyType =>
      getSupplyType(_gstinUpper, _defaultPlaceOfSupply);

  Future<void> _save() async {
    if (_hasGstin && !_gstinValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 15-character GSTIN')),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final updated = provider.profile
      ..gstin = _hasGstin ? _gstinUpper : null
      ..defaultTaxPercent =
          double.tryParse(_taxCtrl.text.trim()) ?? provider.profile.defaultTaxPercent
      ..defaultPlaceOfSupply = _defaultPlaceOfSupply
      ..defaultReverseCharge = _defaultReverseCharge
      ..isCompositionDealer = _isCompositionDealer;
    await provider.updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GST settings saved')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Setup'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── GST Registration ──────────────────────────────────
          _sectionCard(
            icon: Icons.verified_outlined,
            iconColor: const Color(0xFF1565C0),
            title: 'GST Registration',
            children: [
              // GSTIN field
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
                  suffixIcon: _hasGstin
                      ? Icon(
                          _gstinValid
                              ? Icons.check_circle
                              : Icons.cancel_outlined,
                          color: _gstinValid
                              ? AppTheme.success
                              : AppTheme.error,
                          size: 20,
                        )
                      : null,
                ),
              ),

              // Detected state badge
              if (_hasGstin) ...[
                const SizedBox(height: 12),
                _detectedStateBadge(),
              ],

              const SizedBox(height: 16),

              // Composition scheme toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Composition Scheme Dealer',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                    'Pays fixed % of turnover; cannot collect GST from customers',
                    style: TextStyle(fontSize: 11)),
                value: _isCompositionDealer,
                activeThumbColor: AppTheme.primary,
                onChanged: (v) => setState(() => _isCompositionDealer = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Invoice Defaults ──────────────────────────────────
          _sectionCard(
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xFF00897B),
            title: 'Invoice Defaults',
            subtitle: 'Pre-filled on every new invoice',
            children: [
              // Default Place of Supply
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Default Place of Supply',
                  helperText:
                      'State where your services/goods are delivered',
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

              // Default Tax Rate
              TextFormField(
                controller: _taxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Default GST Rate',
                  suffixText: '%',
                  helperText:
                      'Applied to new items (e.g. 18 for 18% GST)',
                ),
              ),
              const SizedBox(height: 8),

              // Reverse Charge toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reverse Charge by Default',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                    'Tax liability shifts to the recipient',
                    style: TextStyle(fontSize: 11)),
                value: _defaultReverseCharge,
                activeThumbColor: AppTheme.primary,
                onChanged: (v) =>
                    setState(() => _defaultReverseCharge = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Supply Type Preview ───────────────────────────────
          if (_gstinValid && _defaultPlaceOfSupply != null)
            _supplyTypePreview(),

          // ── GST Rate Reference ────────────────────────────────
          _sectionCard(
            icon: Icons.info_outline,
            iconColor: const Color(0xFF6A1B9A),
            title: 'Common GST Rates',
            children: [
              _rateRow('0%', 'Essentials — food grains, milk, eggs, salt'),
              _rateRow('5%', 'Packaged food, transport, small restaurants'),
              _rateRow('12%',
                  'Processed foods, business class air travel, work contracts'),
              _rateRow(
                  '18%', 'Most services, electronics, AC restaurants'),
              _rateRow('28%',
                  'Luxury goods — cars, tobacco, aerated drinks'),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────

  Widget _detectedStateBadge() {
    if (_detectedState != null) {
      return Row(
        children: [
          Icon(Icons.location_on_outlined,
              size: 14, color: AppTheme.success),
          const SizedBox(width: 4),
          Text(
            'Registered in: $_detectedState '
            '(${extractGstStateCode(_gstinUpper)})',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.success),
          ),
        ],
      );
    }
    return Row(
      children: const [
        Icon(Icons.warning_amber_outlined,
            size: 14, color: AppTheme.error),
        SizedBox(width: 4),
        Text('Invalid GSTIN format',
            style: TextStyle(fontSize: 12, color: AppTheme.error)),
      ],
    );
  }

  Widget _supplyTypePreview() {
    final type = _previewSupplyType;
    final taxRate = double.tryParse(_taxCtrl.text.trim()) ?? 18.0;
    final half = taxRate / 2;
    String fmtRate(double r) =>
        r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);

    final isInter = type == GstSupplyType.interState;
    final color = isInter
        ? const Color(0xFF0277BD)
        : const Color(0xFF2E7D32);
    final label = isInter ? 'Inter-state Supply' : 'Intra-state Supply';
    final taxLabel = isInter
        ? 'IGST @ ${fmtRate(taxRate)}%'
        : 'CGST @ ${fmtRate(half)}%  +  SGST/UTGST @ ${fmtRate(half)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isInter
                ? Icons.swap_horiz_outlined
                : Icons.swap_vert_outlined,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 2),
                Text(
                  'Invoices to $_defaultPlaceOfSupply will apply $taxLabel',
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: iconColor),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context))),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.subtext(context))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateRow(String rate, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(rate,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(description,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.subtext(context))),
          ),
        ],
      ),
    );
  }
}
