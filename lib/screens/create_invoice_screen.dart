import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../models/partial_payment.dart';
import '../services/exchange_rate_service.dart';
import '../providers/app_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/gst_utils.dart';
import '../utils/pdf_generator.dart';
import '../utils/share_service.dart';
import '../widgets/status_badge.dart';
import 'client_picker_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Invoice invoice;
  const CreateInvoiceScreen({super.key, required this.invoice});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  late Invoice _invoice;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _invoiceNumCtrl;
  late TextEditingController _subjectCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice.copy();
    // Pre-fill GST defaults on new invoices (placeOfSupply not yet set).
    final profile = context.read<AppProvider>().profile;
    if (_invoice.placeOfSupply == null && profile.defaultPlaceOfSupply != null) {
      _invoice.placeOfSupply = profile.defaultPlaceOfSupply;
    }
    if (!_invoice.reverseCharge && profile.defaultReverseCharge) {
      _invoice.reverseCharge = profile.defaultReverseCharge;
    }
    _subjectCtrl = TextEditingController(text: _invoice.subject ?? '');
    _notesCtrl = TextEditingController(text: _invoice.notes ?? '');
    _termsCtrl = TextEditingController(
        text: _invoice.terms ??
            'Payment is due within the stated due date. Late payments may incur a fee.');
    _invoiceNumCtrl = TextEditingController(text: _invoice.invoiceNumber);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _notesCtrl.dispose();
    _termsCtrl.dispose();
    _invoiceNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _invoice.subject = _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim();
    _invoice.notes = _notesCtrl.text.trim();
    _invoice.terms = _termsCtrl.text.trim();
    _invoice.invoiceNumber = _invoiceNumCtrl.text.trim();
    final provider = context.read<AppProvider>();
    setState(() => _saving = true);
    await provider.saveInvoice(_invoice);
    setState(() => _saving = false);
    // Show interstitial ad on free tier every 3rd save.
    AdService.instance.onInvoiceSaved(
      isFreeTier: provider.profile.subscriptionTier == SubscriptionTier.free,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _generatePdf() async {
    await _save();
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final bytes =
        await PdfGenerator.generateInvoicePdf(_invoice, provider.profile);
    if (mounted) {
      await Printing.layoutPdf(onLayout: (_) => bytes);
    }
  }

  void _pickClient() async {
    final client = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const ClientPickerScreen()),
    );
    if (client != null) {
      setState(() => _invoice.client = client);
    }
  }

  void _addLineItem() {
    final profile = context.read<AppProvider>().profile;
    if (profile.serviceItems.isEmpty) {
      setState(() {
        _invoice.items.add(LineItem(
          description: '',
          rate: 0,
          taxPercent: profile.defaultTaxPercent,
        ));
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CatalogPickerSheet(
        items: profile.serviceItems,
        itemLabel: profile.itemLabel,
      ),
    ).then((picked) {
      if (!mounted) return;
      if (picked == null) {
        setState(() {
          _invoice.items.add(LineItem(
            description: '',
            rate: 0,
            taxPercent: profile.defaultTaxPercent,
          ));
        });
      } else {
        final s = picked as ServiceItem;
        setState(() {
          _invoice.items.add(LineItem(
            description: s.description?.isNotEmpty == true
                ? s.description!
                : s.name,
            rate: s.rate,
            taxPercent: s.taxPercent,
          ));
        });
      }
    });
  }

  void _removeLineItem(int index) {
    setState(() => _invoice.items.removeAt(index));
  }

  Future<void> _changeStatus(InvoiceStatus status) async {
    if (status == InvoiceStatus.paid ||
        status == InvoiceStatus.partiallyPaid) {
      await _recordPayment(prefillRemaining: status == InvoiceStatus.paid);
      return;
    }
    final provider = context.read<AppProvider>();
    await provider.updateInvoiceStatus(_invoice.id, status);
    setState(() => _invoice.status = status);

    if (status == InvoiceStatus.sent && mounted) {
      final profile = provider.profile;
      final invoice = _invoice;
      final ctx = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showShareInvoiceSheet(ctx, invoice, profile);
      });
    }
  }

  Future<void> _recordPayment({bool prefillRemaining = false}) async {
    final provider = context.read<AppProvider>();
    final baseCurrency = provider.profile.currency;
    final payment = await showModalBottomSheet<PartialPayment>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _RecordPaymentSheet(
        grandTotal: _invoice.grandTotal,
        amountPaid: _invoice.amountPaid,
        currency: _invoice.currency,
        baseCurrency: baseCurrency,
        methods: provider.profile.allPaymentMethods,
        prefillRemaining: prefillRemaining,
      ),
    );
    if (payment == null || !mounted) return;
    setState(() {
      _invoice.payments.add(payment);
      _invoice.paymentMethodId = payment.paymentMethodId;
      _invoice.paymentMethodName = payment.paymentMethodName;
      _invoice.status = _invoice.amountPaid >= _invoice.grandTotal - 0.01
          ? InvoiceStatus.paid
          : InvoiceStatus.partiallyPaid;
    });
    _invoice.subject = _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim();
    _invoice.notes = _notesCtrl.text.trim();
    _invoice.terms = _termsCtrl.text.trim();
    _invoice.invoiceNumber = _invoiceNumCtrl.text.trim();
    await provider.saveInvoice(_invoice);
  }

  @override
  Widget build(BuildContext context) {
    final symbol = Fmt.currencySymbol(_invoice.currency);
    final profile = context.watch<AppProvider>().profile;
    final showTax = profile.defaultTaxPercent > 0;
    final showQty = profile.showQuantity;

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          StatusBadge(status: _invoice.status),
          const SizedBox(width: 8),
          PopupMenuButton<InvoiceStatus>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Change status',
            onSelected: _changeStatus,
            itemBuilder: (_) => InvoiceStatus.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Text(s.label),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              'Invoice Details',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          label: 'Invoice Number',
                          controller: _invoiceNumCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _datePicker(
                          label: 'Invoice Date',
                          date: _invoice.invoiceDate,
                          onPicked: (d) =>
                              setState(() => _invoice.invoiceDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _datePicker(
                          label: 'Due Date',
                          date: _invoice.dueDate,
                          onPicked: (d) =>
                              setState(() => _invoice.dueDate = d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _currencyDropdown(),
                      ),
                    ],
                  ),
                  if (profile.isGstRegistered) ...[
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Place of Supply',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: indianStatesForGst.contains(_invoice.placeOfSupply)
                              ? _invoice.placeOfSupply
                              : null,
                          hint: const Text('Select state',
                              style: TextStyle(fontSize: 14)),
                          isDense: true,
                          isExpanded: true,
                          items: indianStatesForGst
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        style: const TextStyle(fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _invoice.placeOfSupply = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reverse Charge',
                          style: TextStyle(fontSize: 14)),
                      subtitle: const Text(
                          'Tax payable by recipient',
                          style: TextStyle(fontSize: 11)),
                      value: _invoice.reverseCharge,
                      onChanged: (v) =>
                          setState(() => _invoice.reverseCharge = v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              'Client',
              action: TextButton.icon(
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: Text(
                    _invoice.client == null ? 'Select Client' : 'Change'),
                onPressed: _pickClient,
              ),
              child: _invoice.client == null
                  ? GestureDetector(
                      onTap: _pickClient,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.divider,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.person_outline,
                                color: AppTheme.textSecondary),
                            SizedBox(height: 4),
                            Text('Tap to select client',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : _clientCard(_invoice.client!),
            ),
            const SizedBox(height: 16),
            _section(
              'Line Items',
              action: TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add ${profile.itemLabel}'),
                onPressed: _addLineItem,
              ),
              child: Column(
                children: [
                  if (_invoice.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: _addLineItem,
                          icon: const Icon(Icons.add_circle_outline),
                          label: Text(
                              'Add your first ${profile.itemLabel.toLowerCase()}'),
                        ),
                      ),
                    )
                  else
                    ...List.generate(
                      _invoice.items.length,
                      (i) => _LineItemRow(
                        key: ValueKey(_invoice.items[i]),
                        item: _invoice.items[i],
                        symbol: symbol,
                        index: i,
                        onRemove: () => _removeLineItem(i),
                        onChanged: () => setState(() {}),
                        showTax: showTax,
                        showQty: showQty,
                        itemLabel: profile.itemLabel,
                        serviceItems: profile.serviceItems,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _totalsCard(symbol),
            const SizedBox(height: 16),
            _paymentsSection(symbol),
            const SizedBox(height: 16),
            _section(
              'Subject',
              child: TextField(
                controller: _subjectCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Professional fees for hearing on 07.01.2025 (optional)',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section(
              'Notes',
              child: TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add any notes for the client...',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section(
              'Terms & Conditions',
              child: TextField(
                controller: _termsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Terms and conditions...',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generatePdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Preview PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save'),
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

  Widget _section(String title, {required Widget child, Widget? action}) {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                ?action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _field(
      {required String label,
      required TextEditingController controller,
      TextInputType? keyboardType,
      String? hint}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _datePicker(
      {required String label,
      required DateTime date,
      required ValueChanged<DateTime> onPicked}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(Fmt.date(date),
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
      ),
    );
  }

  Widget _currencyDropdown() {
    const currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD'];
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Currency'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _invoice.currency,
          isDense: true,
          items: currencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _invoice.currency = v);
          },
        ),
      ),
    );
  }

  Widget _clientCard(Client client) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            radius: 20,
            child: Text(
              client.displayName.isNotEmpty
                  ? client.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text(client.email,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                if (client.city.isNotEmpty)
                  Text('${client.city}, ${client.state}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard(String symbol) {
    final profile = context.read<AppProvider>().profile;
    final supplyType =
        getSupplyType(profile.gstin, _invoice.placeOfSupply);
    final taxItems = _invoice.items
        .where((i) => i.taxPercent > 0)
        .map((i) => (taxableAmount: i.taxableAmount, taxPercent: i.taxPercent))
        .toList();
    final gst = profile.isGstRegistered && _invoice.totalTax > 0
        ? computeInvoiceGst(taxItems, supplyType)
        : null;
    final rates =
        taxItems.map((i) => i.taxPercent).toSet();
    final single = rates.length == 1 ? rates.first : null;

    String fmtRate(double r) =>
        r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _totalRow('Subtotal', '$symbol${_invoice.subtotal.toStringAsFixed(2)}'),
            if (_invoice.totalDiscount > 0)
              _totalRow('Discount',
                  '-$symbol${_invoice.totalDiscount.toStringAsFixed(2)}',
                  color: AppTheme.error),
            if (_invoice.totalTax > 0) ...[
              if (gst != null && supplyType == GstSupplyType.interState)
                _totalRow(
                    single != null
                        ? 'IGST (${fmtRate(single)}%)'
                        : 'IGST',
                    '$symbol${gst.totalIgst.toStringAsFixed(2)}')
              else if (gst != null) ...[
                _totalRow(
                    single != null
                        ? 'CGST (${fmtRate(single / 2)}%)'
                        : 'CGST',
                    '$symbol${gst.totalCgst.toStringAsFixed(2)}'),
                _totalRow(
                    single != null
                        ? 'SGST/UTGST (${fmtRate(single / 2)}%)'
                        : 'SGST/UTGST',
                    '$symbol${gst.totalSgst.toStringAsFixed(2)}'),
              ] else
                _totalRow(
                    'Tax', '$symbol${_invoice.totalTax.toStringAsFixed(2)}'),
            ],
            const Divider(height: 20),
            _totalRow(
                'Total',
                '$symbol${_invoice.grandTotal.toStringAsFixed(2)}',
                isBold: true,
                fontSize: 18),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool isBold = false,
      double fontSize = 14,
      Color color = AppTheme.textPrimary}) {
    final style =
        TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _paymentsSection(String symbol) {
    final canRecord = _invoice.status != InvoiceStatus.paid &&
        _invoice.status != InvoiceStatus.cancelled;
    final hasPayments = _invoice.payments.isNotEmpty;

    if (!hasPayments && !canRecord) return const SizedBox.shrink();

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('Payments',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                if (canRecord)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Record'),
                    onPressed: _recordPayment,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (hasPayments) ...[
            ...List.generate(_invoice.payments.length, (i) {
              final p = _invoice.payments[i];
              final date =
                  '${p.date.day}/${p.date.month}/${p.date.year}';
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 16, color: AppTheme.success),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.paymentMethodName ?? 'Payment',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary),
                              ),
                              Text(
                                date +
                                    (p.notes != null
                                        ? ' · ${p.notes}'
                                        : ''),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                              if (p.baseAmount != null &&
                                  p.exchangeRate != null &&
                                  p.baseCurrencyCode != null)
                                Text(
                                  '≈ ${p.baseCurrencyCode} ${p.baseAmount!.toStringAsFixed(2)}  (1 ${_invoice.currency} = ${p.exchangeRate!.toStringAsFixed(4)} ${p.baseCurrencyCode})',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '$symbol${p.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success),
                        ),
                      ],
                    ),
                  ),
                  if (i < _invoice.payments.length - 1)
                    const Divider(height: 1, indent: 58),
                ],
              );
            }),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (hasPayments) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Paid',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary)),
                      Text(
                        '$symbol${_invoice.amountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Balance Due',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    Text(
                      '$symbol${_invoice.amountRemaining.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _invoice.amountRemaining > 0
                              ? AppTheme.error
                              : AppTheme.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RecordPaymentSheet extends StatefulWidget {
  final double grandTotal;
  final double amountPaid;
  final String currency;
  final String baseCurrency;
  final List<PaymentMethod> methods;
  final bool prefillRemaining;

  const _RecordPaymentSheet({
    required this.grandTotal,
    required this.amountPaid,
    required this.currency,
    required this.baseCurrency,
    required this.methods,
    this.prefillRemaining = false,
  });

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  String _selectedMethodId = '__cash__';
  final _formKey = GlobalKey<FormState>();

  bool get _isForeign => widget.currency != widget.baseCurrency;

  @override
  void initState() {
    super.initState();
    final remaining = widget.grandTotal - widget.amountPaid;
    _amountCtrl = TextEditingController(
      text: widget.prefillRemaining && remaining > 0
          ? remaining.toStringAsFixed(2)
          : '',
    );
    _notesCtrl = TextEditingController();

    // Trigger rate fetch after first frame so context is available
    if (_isForeign) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context
              .read<ExchangeRateService>()
              .fetchIfNeeded(widget.baseCurrency);
        }
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final method =
        widget.methods.firstWhere((m) => m.id == _selectedMethodId);
    final amount = double.parse(_amountCtrl.text);

    double? rate;
    double? baseAmount;
    if (_isForeign) {
      final fx = context.read<ExchangeRateService>();
      if (fx.hasRates) {
        rate = fx.toBase(1, widget.currency);
        baseAmount = fx.toBase(amount, widget.currency);
      }
    }

    Navigator.pop(
      context,
      PartialPayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        amount: amount,
        paymentMethodId: method.id,
        paymentMethodName: method.name,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        exchangeRate: rate,
        baseCurrencyCode: _isForeign ? widget.baseCurrency : null,
        baseAmount: baseAmount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = _isForeign ? context.watch<ExchangeRateService>() : null;
    final sym = Fmt.currencySymbol(widget.currency);
    final baseSym = Fmt.currencySymbol(widget.baseCurrency);
    final remaining = widget.grandTotal - widget.amountPaid;

    // Live conversion from typed amount
    final enteredAmount = double.tryParse(_amountCtrl.text);
    final rate = (_isForeign && fx != null && fx.hasRates)
        ? fx.toBase(1, widget.currency)
        : null;
    final convertedAmount = (rate != null && enteredAmount != null)
        ? enteredAmount * rate
        : null;

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
                  widget.prefillRemaining
                      ? 'Record Final Payment'
                      : 'Record Payment',
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryCol('Invoice Total',
                      '$sym${widget.grandTotal.toStringAsFixed(2)}',
                      AppTheme.textPrimary),
                  if (widget.amountPaid > 0)
                    _summaryCol('Paid',
                        '$sym${widget.amountPaid.toStringAsFixed(2)}',
                        AppTheme.success),
                  _summaryCol('Balance Due',
                      '$sym${remaining.toStringAsFixed(2)}', AppTheme.error),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: !widget.prefillRemaining,
              onChanged: (_) => setState(() {}), // trigger live conversion
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: sym,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter amount';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                if (n > remaining + 0.01) {
                  return 'Exceeds balance due ($sym${remaining.toStringAsFixed(2)})';
                }
                return null;
              },
            ),
            // Exchange rate row — only shown when currencies differ
            if (_isForeign) ...[
              const SizedBox(height: 6),
              if (fx!.loading)
                Row(children: [
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5)),
                  const SizedBox(width: 8),
                  Text('Fetching live rate…',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              AppTheme.textSecondary.withValues(alpha: 0.8))),
                ])
              else if (rate != null)
                Row(children: [
                  const Icon(Icons.swap_horiz,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      convertedAmount != null
                          ? '≈ $baseSym${convertedAmount.toStringAsFixed(2)}  '
                              '(1 ${widget.currency} = $baseSym${rate.toStringAsFixed(2)})'
                          : '1 ${widget.currency} = $baseSym${rate.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ])
              else
                Text('Rate unavailable — amount recorded as-is',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7))),
            ],
            const SizedBox(height: 16),
            const Text('Payment Method',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: _selectedMethodId,
              onChanged: (v) {
                if (v != null) setState(() => _selectedMethodId = v);
              },
              child: Column(
                children: widget.methods
                    .map((m) => RadioListTile<String>(
                          value: m.id,
                          title: Text(m.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          subtitle: m.subtitle.isNotEmpty
                              ? Text(m.subtitle,
                                  style: const TextStyle(fontSize: 11))
                              : null,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppTheme.primary,
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Cheque #1234, Bank transfer ref',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LineItemRow extends StatefulWidget {
  final LineItem item;
  final String symbol;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final bool showTax;
  final bool showQty;
  final String itemLabel;
  final List<ServiceItem> serviceItems;

  const _LineItemRow({
    Key? key,
    required this.item,
    required this.symbol,
    required this.index,
    required this.onRemove,
    required this.onChanged,
    this.showTax = true,
    this.showQty = true,
    this.itemLabel = 'Item',
    this.serviceItems = const [],
  }) : super(key: key);

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _discCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _rateCtrl = TextEditingController(text: widget.item.rate == 0 ? '' : widget.item.rate.toString());
    _taxCtrl = TextEditingController(text: widget.item.taxPercent.toString());
    _discCtrl = TextEditingController(text: widget.item.discountPercent.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _taxCtrl.dispose();
    _discCtrl.dispose();
    super.dispose();
  }

  void _update() {
    widget.item.quantity = widget.showQty ? (double.tryParse(_qtyCtrl.text) ?? 1) : 1;
    widget.item.rate = double.tryParse(_rateCtrl.text) ?? 0;
    widget.item.taxPercent = double.tryParse(_taxCtrl.text) ?? 0;
    widget.item.discountPercent = double.tryParse(_discCtrl.text) ?? 0;
    widget.onChanged();
  }

  void _selectService(ServiceItem s) {
    final desc = s.description?.isNotEmpty == true ? s.description! : s.name;
    widget.item.description = desc;
    if (s.rate > 0) {
      _rateCtrl.text = s.rate.toString();
      widget.item.rate = s.rate;
    }
    _taxCtrl.text = s.taxPercent.toString();
    widget.item.taxPercent = s.taxPercent;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${widget.itemLabel} ${widget.index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.error),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Autocomplete<ServiceItem>(
            initialValue: TextEditingValue(text: widget.item.description),
            optionsBuilder: (value) {
              if (widget.serviceItems.isEmpty) return const [];
              final q = value.text.toLowerCase();
              if (q.isEmpty) return widget.serviceItems;
              return widget.serviceItems.where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  (s.description?.toLowerCase().contains(q) ?? false));
            },
            displayStringForOption: (s) =>
                s.description?.isNotEmpty == true ? s.description! : s.name,
            onSelected: _selectService,
            fieldViewBuilder: (ctx, ctrl, focusNode, _) => TextField(
              controller: ctrl,
              focusNode: focusNode,
              onChanged: (v) {
                widget.item.description = v;
                widget.onChanged();
              },
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Type or search ${widget.itemLabel.toLowerCase()}s',
                suffixIcon: widget.serviceItems.isNotEmpty
                    ? const Icon(Icons.search, size: 18,
                        color: AppTheme.textSecondary)
                    : null,
              ),
            ),
            optionsViewBuilder: (ctx, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 340),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final s = options.elementAt(i);
                      final desc = s.description?.isNotEmpty == true
                          ? s.description!
                          : null;
                      return ListTile(
                        dense: true,
                        title: Text(s.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: desc != null
                            ? Text(desc,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: s.rate > 0
                            ? Text(
                                '${widget.symbol}${s.rate.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.primary))
                            : null,
                        onTap: () => onSelected(s),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.showQty)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _update(),
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _update(),
                    decoration: InputDecoration(
                      labelText: 'Rate',
                      prefixText: widget.symbol,
                    ),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: _rateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _update(),
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText: widget.symbol,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.showTax) ...[
                Expanded(
                  child: TextField(
                    controller: _taxCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _update(),
                    decoration: const InputDecoration(
                      labelText: 'Tax %',
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: _discCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _update(),
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    suffixText: '%',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Subtotal',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary)),
                      Text(
                        '${widget.symbol}${item.taxableAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogPickerSheet extends StatelessWidget {
  final List<ServiceItem> items;
  final String itemLabel;

  const _CatalogPickerSheet({
    required this.items,
    required this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a $itemLabel',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Select from your saved ${itemLabel.toLowerCase()}s or add a blank one.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = items[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: _subtitle(s),
                    onTap: () => Navigator.pop(context, s),
                    trailing: const Icon(Icons.chevron_right,
                        size: 18, color: AppTheme.textSecondary),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
              title: Text('Add blank ${itemLabel.toLowerCase()}',
                  style: const TextStyle(color: AppTheme.primary)),
              onTap: () => Navigator.pop(context, null),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _subtitle(ServiceItem s) {
    final parts = <String>[
      if (s.description != null && s.description!.isNotEmpty) s.description!,
      if (s.rate > 0) '₹${s.rate.toStringAsFixed(0)}',
      if (s.unit != null && s.unit!.isNotEmpty) s.unit!,
      if (s.taxPercent > 0) '${s.taxPercent.toStringAsFixed(0)}% tax',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
