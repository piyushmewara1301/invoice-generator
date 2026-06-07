import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/business_profile.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/location_fields.dart';

// ── Business type visual metadata (kept in screen layer — not in model) ────────

IconData _btIcon(BusinessType t) {
  switch (t) {
    case BusinessType.restaurant:    return Icons.restaurant_outlined;
    case BusinessType.grocery:       return Icons.shopping_cart_outlined;
    case BusinessType.retail:        return Icons.storefront_outlined;
    case BusinessType.professional:  return Icons.work_outline;
    case BusinessType.healthcare:    return Icons.local_hospital_outlined;
    case BusinessType.education:     return Icons.school_outlined;
    case BusinessType.construction:  return Icons.construction;
    case BusinessType.salon:         return Icons.content_cut;
    case BusinessType.technology:    return Icons.computer_outlined;
    case BusinessType.manufacturing: return Icons.precision_manufacturing_outlined;
    case BusinessType.wholesale:     return Icons.inventory_2_outlined;
    case BusinessType.transport:     return Icons.local_shipping_outlined;
    case BusinessType.freelancer:    return Icons.person_outline;
    case BusinessType.other:         return Icons.category_outlined;
  }
}

Color _btColor(BusinessType t) {
  switch (t) {
    case BusinessType.restaurant:    return const Color(0xFFF97316);
    case BusinessType.grocery:       return const Color(0xFF16A34A);
    case BusinessType.retail:        return const Color(0xFF0891B2);
    case BusinessType.professional:  return const Color(0xFF2563EB);
    case BusinessType.healthcare:    return const Color(0xFFEF4444);
    case BusinessType.education:     return const Color(0xFF7C3AED);
    case BusinessType.construction:  return const Color(0xFFD97706);
    case BusinessType.salon:         return const Color(0xFFEC4899);
    case BusinessType.technology:    return const Color(0xFF06B6D4);
    case BusinessType.manufacturing: return const Color(0xFF78716C);
    case BusinessType.wholesale:     return const Color(0xFF0F766E);
    case BusinessType.transport:     return const Color(0xFF4F46E5);
    case BusinessType.freelancer:    return const Color(0xFF9333EA);
    case BusinessType.other:         return const Color(0xFF64748B);
  }
}

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _postalCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _professionCtrl;
  String? _logoBase64;
  Set<String> _headerFields = {kHeaderLogo, kHeaderName, kHeaderAddress};
  BusinessType? _businessType;
  bool _saving = false;
  bool _initialized = false;

  void _init(BusinessProfile p) {
    _nameCtrl = TextEditingController(text: p.name);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl = TextEditingController(text: p.phone);
    _addressCtrl = TextEditingController(text: p.address);
    _cityCtrl = TextEditingController(text: p.city);
    _stateCtrl = TextEditingController(text: p.state);
    _countryCtrl = TextEditingController(text: p.country);
    _postalCtrl = TextEditingController(text: p.postalCode);
    _gstinCtrl = TextEditingController(text: p.gstin ?? '');
    _websiteCtrl = TextEditingController(text: p.website ?? '');
    _logoBase64 = p.logoBase64;
    _headerFields = Set<String>.from(p.headerFields);
    _businessType = p.businessType;
    _professionCtrl = TextEditingController(text: p.professionTitle ?? '');
    _initialized = true;

    // Rebuild header selector whenever any field changes so _fieldHasData
    // reflects the live form values immediately as the user types.
    for (final c in [
      _nameCtrl, _emailCtrl, _addressCtrl,
      _cityCtrl, _stateCtrl, _gstinCtrl, _websiteCtrl,
    ]) {
      c.addListener(_rebuildHeader);
    }
  }

  void _rebuildHeader() => setState(() {});

  @override
  void dispose() {
    if (_initialized) {
      for (final c in [
        _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl,
        _cityCtrl, _stateCtrl, _countryCtrl, _postalCtrl,
        _gstinCtrl, _websiteCtrl, _professionCtrl,
      ]) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _logoBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    final cur = provider.profile;
    setState(() => _saving = true);
    await provider.updateProfile(cur.copyWith(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      postalCode: _postalCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
      website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      logoBase64: _logoBase64,
      headerFields: _headerFields.where(_fieldHasData).toSet(),
      businessType: _businessType,
      professionTitle: _professionCtrl.text.trim().isEmpty
          ? null
          : _professionCtrl.text.trim(),
    ));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Business profile saved'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;
    if (!_initialized) _init(profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
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
            _logoCard(),
            const SizedBox(height: 16),
            _businessTypeCard(),
            const SizedBox(height: 16),
            _professionCard(),
            const SizedBox(height: 16),
            _card('Business Information', [
              _field(_nameCtrl, 'Business Name', required: true),
              _field(_emailCtrl, 'Email', type: TextInputType.emailAddress),
              _field(_phoneCtrl, 'Phone', type: TextInputType.phone),
              _field(_websiteCtrl, 'Website', type: TextInputType.url),
              _field(_gstinCtrl, 'GSTIN (optional)'),
            ]),
            const SizedBox(height: 16),
            _card('Address', [
              _field(_addressCtrl, 'Street Address'),
              _field(_cityCtrl, 'City'),
              LocationFields(
                countryCtrl: _countryCtrl,
                stateCtrl: _stateCtrl,
                postalCtrl: _postalCtrl,
              ),
            ]),
            const SizedBox(height: 16),
            _card('Invoice Header Style', [_headerStyleSelector()]),
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

  // ── Profession / designation quick-pick suggestions per business type ──────
  static const _professionSuggestions = <BusinessType, List<String>>{
    BusinessType.professional: [
      'Chartered Accountant',
      'CA',
      'Advocate',
      'Solicitor',
      'Auditor',
      'Company Secretary',
      'Cost Accountant (CMA)',
      'Tax Consultant',
      'Financial Advisor',
      'Management Consultant',
      'Business Analyst',
    ],
    BusinessType.healthcare: [
      'Doctor',
      'Dentist',
      'Surgeon',
      'Physiotherapist',
      'Pharmacist',
      'Veterinarian',
      'Dietitian',
      'Psychologist',
    ],
    BusinessType.freelancer: [
      'Graphic Designer',
      'Web Developer',
      'Content Writer',
      'Photographer',
      'Videographer',
      'Social Media Manager',
      'UI/UX Designer',
      'Digital Marketer',
    ],
    BusinessType.education: [
      'Tutor',
      'Trainer',
      'Coach',
      'Lecturer',
      'Professor',
      'Instructor',
    ],
    BusinessType.technology: [
      'Software Developer',
      'IT Consultant',
      'System Architect',
      'DevOps Engineer',
      'Cybersecurity Expert',
    ],
    BusinessType.construction: [
      'Architect',
      'Civil Engineer',
      'Interior Designer',
      'Structural Engineer',
      'Project Manager',
    ],
    BusinessType.other: [
      'Consultant',
      'Advisor',
      'Agent',
      'Broker',
      'Contractor',
    ],
  };

  Widget _professionCard() {
    final suggestions =
        _professionSuggestions[_businessType] ?? const <String>[];
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
                Text(
                  'Profession / Designation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _professionCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Your profession or designation',
                    hintText: suggestions.isNotEmpty
                        ? 'e.g., ${suggestions.take(3).join(', ')}'
                        : 'e.g., Consultant, Director, Partner',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _professionCtrl,
                      builder: (_, v, _) => v.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () =>
                                  setState(() => _professionCtrl.clear()),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Common options — tap to fill:',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions.map((s) {
                      final active = _professionCtrl.text.trim() == s;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _professionCtrl.text = s;
                          _professionCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: s.length),
                          );
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: active
                                ? AppTheme.primary
                                : AppTheme.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? AppTheme.primary
                                  : AppTheme.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active ? Colors.white : AppTheme.primary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Appears below your name on Professional, Letterhead, and Legal Pro invoice PDFs.',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.subtext(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessTypeCard() {
    final selected = _businessType;
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<BusinessType>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _BusinessTypePickerSheet(selected: _businessType),
        );
        // null means "clear selection"; -1 sentinel means user dismissed
        if (picked != null) setState(() => _businessType = picked);
      },
      child: Container(
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
                  Text(
                    'Business Type',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context)),
                  ),
                  const Spacer(),
                  if (selected != null)
                    GestureDetector(
                      onTap: () => setState(() => _businessType = null),
                      child: Icon(Icons.close,
                          size: 16, color: AppTheme.subtext(context)),
                    ),
                ],
              ),
            ),
            Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: selected == null
                  ? Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.outline(context),
                                style: BorderStyle.solid),
                          ),
                          child: Icon(Icons.add_business_outlined,
                              color: AppTheme.subtext(context), size: 20),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Select your business type',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.subtext(context)),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right,
                            size: 18, color: AppTheme.subtext(context)),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _btColor(selected).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_btIcon(selected),
                              color: _btColor(selected), size: 20),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            selected.displayName,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onCard(context)),
                          ),
                        ),
                        Icon(Icons.edit_outlined,
                            size: 16, color: AppTheme.subtext(context)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoCard() {
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
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Business Logo',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context))),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 120,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.outline(context)),
                    ),
                    child: _logoBase64 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.memory(base64Decode(_logoBase64!),
                                fit: BoxFit.contain))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: AppTheme.subtext(context)
                                      .withValues(alpha: 0.5),
                                  size: 24),
                              SizedBox(height: 4),
                              Text('Upload Logo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.subtext(context))),
                            ],
                          ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appears at the top of your invoices',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.onCard(context))),
                      SizedBox(height: 4),
                      Text('PNG or JPG · Max 400×200px recommended',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.subtext(context))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.upload_outlined, size: 14),
                            label: Text(_logoBase64 == null ? 'Upload' : 'Change'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          if (_logoBase64 != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _logoBase64 = null),
                              icon: const Icon(Icons.delete_outline,
                                  size: 14, color: AppTheme.error),
                              label: const Text('Remove',
                                  style: TextStyle(color: AppTheme.error)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: const BorderSide(color: AppTheme.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? type, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
          : null,
    );
  }

  bool _fieldHasData(String key) {
    switch (key) {
      case kHeaderLogo:    return _logoBase64 != null;
      case kHeaderName:    return _nameCtrl.text.trim().isNotEmpty;
      case kHeaderEmail:   return _emailCtrl.text.trim().isNotEmpty;
      case kHeaderAddress: return _addressCtrl.text.trim().isNotEmpty ||
                                  _cityCtrl.text.trim().isNotEmpty ||
                                  _stateCtrl.text.trim().isNotEmpty;
      case kHeaderGstin:   return _gstinCtrl.text.trim().isNotEmpty;
      case kHeaderWebsite: return _websiteCtrl.text.trim().isNotEmpty;
      default:             return false;
    }
  }

  String _emptyHint(String key) {
    switch (key) {
      case kHeaderLogo:    return 'Upload a logo first';
      case kHeaderEmail:   return 'Add your email above';
      case kHeaderAddress: return 'Add your address above';
      case kHeaderGstin:   return 'Add your GSTIN above';
      case kHeaderWebsite: return 'Add your website above';
      default:             return 'Fill in the field above';
    }
  }

  Widget _headerStyleSelector() {
    const items = [
      (kHeaderLogo,    Icons.image_outlined,         'Logo'),
      (kHeaderName,    Icons.storefront_outlined,     'Business Name'),
      (kHeaderEmail,   Icons.email_outlined,          'Email'),
      (kHeaderAddress, Icons.location_on_outlined,    'Address'),
      (kHeaderGstin,   Icons.badge_outlined,          'GST Number'),
      (kHeaderWebsite, Icons.language_outlined,       'Website'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose what appears in the invoice header:',
          style: TextStyle(fontSize: 12, color: AppTheme.subtext(context)),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final (key, icon, label) = item;
          final hasData = _fieldHasData(key);
          final checked = hasData && _headerFields.contains(key);
          final color = !hasData
              ? AppTheme.textSecondary.withValues(alpha: 0.4)
              : checked
                  ? AppTheme.primary
                  : AppTheme.onCard(context);

          return InkWell(
            onTap: !hasData
                ? null
                : () => setState(() {
                      if (checked) {
                        _headerFields.remove(key);
                      } else {
                        _headerFields.add(key);
                      }
                    }),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
                children: [
                  Icon(icon, size: 18,
                      color: !hasData
                          ? AppTheme.textSecondary.withValues(alpha: 0.35)
                          : checked
                              ? AppTheme.primary
                              : AppTheme.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: checked
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )),
                        if (!hasData && key != kHeaderName)
                          Text(_emptyHint(key),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.subtext(context)
                                    .withValues(alpha: 0.5),
                              )),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: checked,
                    activeColor: AppTheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: !hasData
                        ? null
                        : (_) => setState(() {
                              if (checked) {
                                _headerFields.remove(key);
                              } else {
                                _headerFields.add(key);
                              }
                            }),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Business type picker bottom sheet ─────────────────────────────────────────

class _BusinessTypePickerSheet extends StatelessWidget {
  final BusinessType? selected;
  const _BusinessTypePickerSheet({this.selected});

  @override
  Widget build(BuildContext context) {
    final types = BusinessType.values;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What type of business do you run?',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context)),
            ),
            SizedBox(height: 4),
            Text(
              'Helps personalise your experience',
              style: TextStyle(fontSize: 12, color: AppTheme.subtext(context)),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemCount: types.length,
              itemBuilder: (_, i) {
                final t = types[i];
                final isSelected = t == selected;
                final color = _btColor(t);
                return GestureDetector(
                  onTap: () => Navigator.pop(context, t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : AppTheme.divider,
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _btIcon(t),
                          color: isSelected ? color : AppTheme.textSecondary,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? color
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
