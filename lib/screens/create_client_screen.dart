import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/location_fields.dart';

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();

    final client = Client(
      id: widget.client?.id ?? provider.newClientId(),
      name: _nameCtrl.text.trim(),
      companyName: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'New Client' : 'Edit Client'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Required ──────────────────────────────────────────
            _sectionCard(
              icon: Icons.person_outline,
              title: 'Identity',
              children: [
                _field(_nameCtrl, 'Full Name', required: true),
                _field(_companyCtrl, 'Company Name',
                    hint: 'Leave blank if individual'),
              ],
            ),
            const SizedBox(height: 12),

            // ── Contact ───────────────────────────────────────────
            _sectionCard(
              icon: Icons.contact_phone_outlined,
              title: 'Contact',
              subtitle: 'All optional',
              children: [
                _field(_emailCtrl, 'Email',
                    type: TextInputType.emailAddress,
                    hint: 'e.g. client@example.com'),
                _field(_phoneCtrl, 'Phone',
                    type: TextInputType.phone,
                    hint: 'e.g. +91 98765 43210'),
              ],
            ),
            const SizedBox(height: 12),

            // ── Address ───────────────────────────────────────────
            _sectionCard(
              icon: Icons.location_on_outlined,
              title: 'Address',
              subtitle: 'All optional — only filled lines appear on invoices',
              children: [
                _field(_addressCtrl, 'Street Address',
                    hint: 'Building, street, area', maxLines: 3),
                _field(_cityCtrl, 'City'),
                LocationFields(
                  countryCtrl: _countryCtrl,
                  stateCtrl: _stateCtrl,
                  postalCtrl: _postalCtrl,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Tax ───────────────────────────────────────────────
            _sectionCard(
              icon: Icons.receipt_outlined,
              title: 'Tax',
              subtitle: 'Optional',
              children: [
                _field(_gstinCtrl, 'GSTIN', hint: 'e.g. 22AAAAA0000A1Z5'),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              child: Text(
                  widget.client == null ? 'Add Client' : 'Update Client'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
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
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
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
      {TextInputType? type, bool required = false, String? hint, int? maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
          : null,
    );
  }
}
