import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_profile.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethod> _methods = [];
  bool _initialized = false;

  void _init(BusinessProfile p) {
    _methods = List.from(p.paymentMethods);
    _initialized = true;
  }

  Future<void> _persist() async {
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
      itemLabel: cur.itemLabel,
      paymentMethods: _methods,
      serviceItems: cur.serviceItems,
    ));
  }

  Future<void> _add() async {
    final result = await _showForm();
    if (result != null) {
      setState(() => _methods.add(result));
      await _persist();
    }
  }

  Future<void> _edit(PaymentMethod m) async {
    final result = await _showForm(existing: m);
    if (result != null) {
      setState(() {
        final i = _methods.indexOf(m);
        if (i >= 0) _methods[i] = result;
      });
      await _persist();
    }
  }

  Future<PaymentMethod?> _showForm({PaymentMethod? existing}) {
    return showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PaymentMethodForm(existing: existing),
    );
  }

  IconData _pmIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return Icons.payments_outlined;
      case PaymentMethodType.bankAccount:
        return Icons.account_balance_outlined;
      case PaymentMethodType.upi:
        return Icons.qr_code_outlined;
      case PaymentMethodType.other:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;
    if (!_initialized) _init(profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add method',
            onPressed: _add,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      const Text('Methods',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Cash — always first, not deletable
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.1),
                    child: Icon(_pmIcon(PaymentMethodType.cash),
                        size: 16, color: AppTheme.primary),
                  ),
                  title: const Text('Cash',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Cash payment',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Default',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.primary)),
                  ),
                ),
                if (_methods.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _methods.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _methodTile(_methods[i]),
                  ),
                ] else ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Add bank accounts, UPI IDs or other payment details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _methodTile(PaymentMethod m) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        child: Icon(_pmIcon(m.type), size: 16, color: AppTheme.primary),
      ),
      title: Text(m.name,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: m.subtitle.isNotEmpty
          ? Text(m.subtitle,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppTheme.textSecondary),
            onPressed: () => _edit(m),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppTheme.error),
            onPressed: () async {
              setState(() => _methods.remove(m));
              await _persist();
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

class _PaymentMethodForm extends StatefulWidget {
  final PaymentMethod? existing;
  const _PaymentMethodForm({this.existing});

  @override
  State<_PaymentMethodForm> createState() => _PaymentMethodFormState();
}

class _PaymentMethodFormState extends State<_PaymentMethodForm> {
  late PaymentMethodType _type;
  late TextEditingController _nameCtrl;
  late TextEditingController _holderCtrl;
  late TextEditingController _accountCtrl;
  late TextEditingController _bankCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _upiCtrl;
  late TextEditingController _notesCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _type = m?.type ?? PaymentMethodType.bankAccount;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _holderCtrl = TextEditingController(text: m?.accountHolder ?? '');
    _accountCtrl = TextEditingController(text: m?.accountNumber ?? '');
    _bankCtrl = TextEditingController(text: m?.bankName ?? '');
    _ifscCtrl = TextEditingController(text: m?.ifscCode ?? '');
    _upiCtrl = TextEditingController(text: m?.upiId ?? '');
    _notesCtrl = TextEditingController(text: m?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _holderCtrl, _accountCtrl, _bankCtrl,
      _ifscCtrl, _upiCtrl, _notesCtrl,
    ]) {
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
      PaymentMethod(
        id: id,
        name: _nameCtrl.text.trim(),
        type: _type,
        accountHolder: _holderCtrl.text.trim().isEmpty
            ? null
            : _holderCtrl.text.trim(),
        accountNumber: _accountCtrl.text.trim().isEmpty
            ? null
            : _accountCtrl.text.trim(),
        bankName:
            _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
        ifscCode:
            _ifscCtrl.text.trim().isEmpty ? null : _ifscCtrl.text.trim(),
        upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
  }

  IconData _iconFor(PaymentMethodType t) {
    switch (t) {
      case PaymentMethodType.cash:
        return Icons.payments_outlined;
      case PaymentMethodType.bankAccount:
        return Icons.account_balance_outlined;
      case PaymentMethodType.upi:
        return Icons.qr_code_outlined;
      case PaymentMethodType.other:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  widget.existing == null
                      ? 'Add Payment Method'
                      : 'Edit Payment Method',
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
            Row(
              children: PaymentMethodType.values
                  .where((t) => t != PaymentMethodType.cash)
                  .map((t) {
                final selected = _type == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.divider,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(_iconFor(t),
                              size: 20,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary),
                          const SizedBox(height: 4),
                          Text(
                            t.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Label / Display Name',
                hintText: 'e.g. HDFC Savings, PhonePe',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            if (_type == PaymentMethodType.bankAccount) ...[
              TextFormField(
                controller: _holderCtrl,
                decoration: const InputDecoration(
                    labelText: 'Account Holder Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankCtrl,
                decoration:
                    const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Account Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ifscCtrl,
                decoration:
                    const InputDecoration(labelText: 'IFSC Code'),
                textCapitalization: TextCapitalization.characters,
              ),
            ] else if (_type == PaymentMethodType.upi) ...[
              TextFormField(
                controller: _upiCtrl,
                decoration: const InputDecoration(
                    labelText: 'UPI ID / VPA',
                    hintText: 'yourname@bank'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Any additional payment details',
                ),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
              child: Text(widget.existing == null
                  ? 'Add Method'
                  : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
