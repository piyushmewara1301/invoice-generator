import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/location_fields.dart';
import '../models/employee.dart';

class CreateClientScreen extends StatefulWidget {
  final Client? client;
  const CreateClientScreen({super.key, this.client});

  @override
  State<CreateClientScreen> createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends State<CreateClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _postalCtrl;
  late TextEditingController _gstinCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _companyCtrl = TextEditingController(text: c?.companyName ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _cityCtrl = TextEditingController(text: c?.city ?? '');
    _stateCtrl = TextEditingController(text: c?.state ?? '');
    _countryCtrl = TextEditingController(text: c?.country ?? '');
    _postalCtrl = TextEditingController(text: c?.postalCode ?? '');
    _gstinCtrl = TextEditingController(text: c?.gstin ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _companyCtrl, _emailCtrl, _phoneCtrl, _addressCtrl,
      _cityCtrl, _stateCtrl, _countryCtrl, _postalCtrl, _gstinCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();

    final name = _toTitleCase(_nameCtrl.text.trim());
    final company = _companyCtrl.text.trim();

    final client = Client(
      id: widget.client?.id ?? provider.newClientId(),
      name: name,
      companyName: company.isEmpty ? null : _toTitleCase(company),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      postalCode: _postalCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
    );

    if (widget.client == null) {
      await provider.addClient(client);
    } else {
      await provider.updateClient(client);
    }

    if (mounted) Navigator.pop(context, client);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final canEdit = widget.client == null
        ? provider.canDo(AppPermission.createClient)
        : provider.canDo(AppPermission.editClient);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? l10n.newClient : l10n.editClient),
        actions: [
          if (canEdit)
            TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard(
              icon: Icons.person_outline,
              title: l10n.clientName,
              children: [
                _field(_nameCtrl, l10n.clientName,
                    required: true, readOnly: !canEdit),
                _field(_companyCtrl, l10n.companyName,
                    hint: 'Leave blank if individual', readOnly: !canEdit),
              ],
            ),
            const SizedBox(height: 12),

            _sectionCard(
              icon: Icons.contact_phone_outlined,
              title: 'Contact',
              subtitle: l10n.optional,
              children: [
                _field(_emailCtrl, l10n.email,
                    type: TextInputType.emailAddress,
                    hint: 'e.g. client@example.com',
                    readOnly: !canEdit),
                _field(_phoneCtrl, l10n.phone,
                    type: TextInputType.phone,
                    hint: 'e.g. +91 98765 43210',
                    readOnly: !canEdit),
              ],
            ),
            const SizedBox(height: 12),

            _sectionCard(
              icon: Icons.location_on_outlined,
              title: l10n.address,
              subtitle: l10n.optional,
              children: [
                _field(_addressCtrl, l10n.address,
                    hint: 'Building, street, area',
                    maxLines: 3,
                    readOnly: !canEdit),
                _field(_cityCtrl, l10n.city, readOnly: !canEdit),
                LocationFields(
                  countryCtrl: _countryCtrl,
                  stateCtrl: _stateCtrl,
                  postalCtrl: _postalCtrl,
                  readOnly: !canEdit,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (provider.profile.isGstRegistered) ...[
              const SizedBox(height: 12),
              _sectionCard(
                icon: Icons.receipt_outlined,
                title: l10n.tax,
                subtitle: l10n.optional,
                children: [
                  _field(_gstinCtrl, l10n.gstin,
                      hint: 'e.g. 22AAAAA0000A1Z5', readOnly: !canEdit),
                ],
              ),
            ],
            const SizedBox(height: 24),

            if (canEdit)
              ElevatedButton(
                onPressed: _save,
                child: Text(
                    widget.client == null ? l10n.addClient : l10n.update),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context))),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.subtext(context))),
                  ),
                ],
              ],
            ),
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
      {TextInputType? type,
      bool required = false,
      String? hint,
      int? maxLines = 1,
      bool readOnly = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: required && !readOnly ? '$label *' : label,
        hintText: readOnly ? null : hint,
      ),
      validator: (required && !readOnly)
          ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
          : null,
    );
  }
}
