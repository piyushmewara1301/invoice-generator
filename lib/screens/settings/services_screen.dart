import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_profile.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _itemLabel = 'Item';
  List<ServiceItem> _items = [];
  bool _initialized = false;

  void _init(BusinessProfile p) {
    _itemLabel = p.itemLabel;
    _items = List.from(p.serviceItems);
    _initialized = true;
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final cur = provider.profile;
    await provider.updateProfile(BusinessProfile(
      name: cur.name,
      email: cur.email,
      phone: cur.phone,
      address: cur.address,
      city: cur.city,
      state: cur.state,
      country: cur.country,
      postalCode: cur.postalCode,
      gstin: cur.gstin,
      website: cur.website,
      logoBase64: cur.logoBase64,
      headerFields: cur.headerFields,
      currency: cur.currency,
      invoicePrefix: cur.invoicePrefix,
      nextInvoiceNumber: cur.nextInvoiceNumber,
      defaultTemplate: cur.defaultTemplate,
      themeColorHex: cur.themeColorHex,
      defaultTaxPercent: cur.defaultTaxPercent,
      showQuantity: cur.showQuantity,
      itemLabel: _itemLabel,
      paymentMethods: cur.paymentMethods,
      serviceItems: _items,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_itemLabel}s saved'),
            duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _add() async {
    final result = await _showForm();
    if (result != null) {
      setState(() => _items.add(result));
      await _save();
    }
  }

  Future<void> _edit(ServiceItem s) async {
    final result = await _showForm(existing: s);
    if (result != null) {
      setState(() {
        final i = _items.indexOf(s);
        if (i >= 0) _items[i] = result;
      });
      await _save();
    }
  }

  Future<ServiceItem?> _showForm({ServiceItem? existing}) {
    return showModalBottomSheet<ServiceItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ServiceItemForm(
        existing: existing,
        itemLabel: _itemLabel,
        defaultTaxPercent:
            context.read<AppProvider>().profile.defaultTaxPercent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;
    if (!_initialized) _init(profile);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_itemLabel}s & Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add $_itemLabel',
            onPressed: _add,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Label toggle card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How do you call them in invoices?',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  const Text(
                      'This label appears on line items in invoices and buttons.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Item', 'Service'].map((label) {
                      final selected = _itemLabel == label;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) async {
                            setState(() => _itemLabel = label);
                            await _save();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // List card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text('Your ${_itemLabel}s',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('Add $_itemLabel'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 40,
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text(
                            'No ${_itemLabel.toLowerCase()}s yet',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add your common ${_itemLabel.toLowerCase()}s to quickly fill invoices.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _itemTile(_items[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _itemTile(ServiceItem s) {
    final parts = <String>[
      if (s.description != null && s.description!.isNotEmpty) s.description!,
      if (s.rate > 0) '₹${s.rate.toStringAsFixed(0)}',
      if (s.unit != null && s.unit!.isNotEmpty) s.unit!,
      if (s.taxPercent > 0) '${s.taxPercent.toStringAsFixed(0)}% tax',
    ];

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.receipt_long_outlined,
            size: 16, color: AppTheme.primary),
      ),
      title: Text(s.name,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: parts.isNotEmpty
          ? Text(
              parts.join(' · '),
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppTheme.textSecondary),
            onPressed: () => _edit(s),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppTheme.error),
            onPressed: () async {
              setState(() => _items.remove(s));
              await _save();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ServiceItemForm extends StatefulWidget {
  final ServiceItem? existing;
  final String itemLabel;
  final double defaultTaxPercent;

  const _ServiceItemForm({
    this.existing,
    required this.itemLabel,
    required this.defaultTaxPercent,
  });

  @override
  State<_ServiceItemForm> createState() => _ServiceItemFormState();
}

class _ServiceItemFormState extends State<_ServiceItemForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _unitCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _rateCtrl = TextEditingController(
        text: s != null && s.rate > 0 ? s.rate.toString() : '');
    _taxCtrl = TextEditingController(
        text: s != null
            ? s.taxPercent.toString()
            : widget.defaultTaxPercent.toString());
    _unitCtrl = TextEditingController(text: s?.unit ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _rateCtrl, _taxCtrl, _unitCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.pop(
      context,
      ServiceItem(
        id: id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        rate: double.tryParse(_rateCtrl.text) ?? 0,
        taxPercent: double.tryParse(_taxCtrl.text) ?? 0,
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.itemLabel;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.existing == null ? 'Add $label' : 'Edit $label',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '$label Name',
                hintText: 'e.g. Web Design, Haircut, Masala Dosa',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Description (shown on invoice)',
                hintText: 'Leave blank to use $label name',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Default Rate', hintText: '0'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Unit', hintText: 'hrs, pcs…'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _taxCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tax %', suffixText: '%'),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final n = double.tryParse(v);
                if (n == null || n < 0 || n > 100) return '0–100';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
              child: Text(
                  widget.existing == null ? 'Add $label' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
