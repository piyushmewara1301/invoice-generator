import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase_bill.dart';
import '../providers/app_provider.dart';
import '../services/ocr_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/ocr_result_sheet.dart';

class CreatePurchaseBillScreen extends StatefulWidget {
  final PurchaseBill? bill;
  final String? prefilledVendorName;
  const CreatePurchaseBillScreen({super.key, this.bill, this.prefilledVendorName});

  @override
  State<CreatePurchaseBillScreen> createState() =>
      _CreatePurchaseBillScreenState();
}

class _CreatePurchaseBillScreenState extends State<CreatePurchaseBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  // Vendor fields
  late TextEditingController _vendorCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _billNoCtrl;
  late TextEditingController _notesCtrl;

  late DateTime _billDate;
  DateTime? _dueDate;

  // Line items
  List<_ItemRow> _items = [];

  // Amount paid
  late TextEditingController _paidCtrl;

  // Reminder
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 1;

  // Receipt image & OCR
  String? _receiptImageBase64;
  bool _ocrScanning = false;

  bool get _isEdit => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _vendorCtrl  = TextEditingController(text: b?.vendorName ?? widget.prefilledVendorName ?? '');
    _gstinCtrl   = TextEditingController(text: b?.vendorGstin ?? '');
    _phoneCtrl   = TextEditingController(text: b?.vendorPhone ?? '');
    _emailCtrl   = TextEditingController(text: b?.vendorEmail ?? '');
    _billNoCtrl  = TextEditingController(text: b?.billNumber ?? '');
    _notesCtrl   = TextEditingController(text: b?.notes ?? '');
    _paidCtrl    = TextEditingController(
        text: b != null && b.amountPaid > 0
            ? b.amountPaid.toStringAsFixed(2)
            : '');
    _billDate           = b?.billDate ?? DateTime.now();
    _dueDate            = b?.dueDate;
    _reminderEnabled    = b?.reminderEnabled ?? false;
    _reminderDaysBefore = b?.reminderDaysBefore ?? 1;
    _receiptImageBase64 = b?.receiptImageBase64;
    _items = b?.items
            .map((i) => _ItemRow(
                  id: i.id,
                  descCtrl: TextEditingController(text: i.description),
                  qtyCtrl: TextEditingController(
                      text: i.quantity.toStringAsFixed(
                          i.quantity == i.quantity.roundToDouble() ? 0 : 2)),
                  rateCtrl: TextEditingController(
                      text: i.rate.toStringAsFixed(2)),
                  taxPercent: i.taxPercent,
                ))
            .toList() ??
        [_ItemRow.blank(_uuid.v4())];
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _gstinCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _billNoCtrl.dispose();
    _notesCtrl.dispose();
    _paidCtrl.dispose();
    for (final r in _items) { r.dispose(); }
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0, (s, r) => s + r.subtotal);
  double get _totalTax =>
      _items.fold(0, (s, r) => s + r.taxAmount);
  double get _grandTotal => _subtotal + _totalTax;

  Future<void> _pickReceipt(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _receiptImageBase64 = base64Encode(bytes));
  }

  // Future<void> _scanBill() async {
  //   if (_receiptImageBase64 == null) return;
  //   setState(() => _ocrScanning = true);
  //   try {
  //     final text =
  //         await OcrService.extractTextFromBase64(_receiptImageBase64!);
  //     if (!mounted) return;
  //     if (text == null) {
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //           content:
  //               Text('Could not read text. Try a clearer, well-lit photo.')));
  //       return;
  //     }
  //     final result = OcrService.parseBill(text);
  //     if (!result.hasData) {
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //           content: Text('No fields detected. Fill in the form manually.')));
  //       return;
  //     }
  //     _showBillOcrSheet(result);
  //   } finally {
  //     if (mounted) setState(() => _ocrScanning = false);
  //   }
  // }

  void _showBillOcrSheet(OcrBillResult result) {
    final sym =
        Fmt.currencySymbol(context.read<AppProvider>().profile.currency);
    final fields = <OcrField>[
      if (result.vendorName != null)
        OcrField(
          key: 'vendor',
          label: 'Vendor Name',
          displayValue: result.vendorName!,
          rawValue: result.vendorName!,
        ),
      if (result.billNumber != null)
        OcrField(
          key: 'billNo',
          label: 'Bill Number',
          displayValue: result.billNumber!,
          rawValue: result.billNumber!,
        ),
      if (result.date != null)
        OcrField(
          key: 'date',
          label: 'Bill Date',
          displayValue: Fmt.date(result.date!),
          rawValue: result.date!,
        ),
      if (result.total != null)
        OcrField(
          key: 'total',
          label: 'Total Amount',
          displayValue: '$sym${result.total!.toStringAsFixed(2)}',
          rawValue: result.total!,
        ),
      if (result.gstin != null)
        OcrField(
          key: 'gstin',
          label: 'Vendor GSTIN',
          displayValue: result.gstin!,
          rawValue: result.gstin!,
        ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => OcrResultSheet(
        fields: fields,
        onApply: (selected) {
          setState(() {
            if (selected['vendor'] case final String name) {
              if (_vendorCtrl.text.trim().isEmpty) _vendorCtrl.text = name;
            }
            if (selected['billNo'] case final String no) {
              if (_billNoCtrl.text.trim().isEmpty) _billNoCtrl.text = no;
            }
            if (selected['date'] case final DateTime d) {
              _billDate = d;
            }
            if (selected['total'] case final double total) {
              // Pre-fill the first blank item's rate with the extracted total
              final blank = _items
                  .where((r) => r.description.isEmpty && r.rate == 0)
                  .firstOrNull;
              if (blank != null) {
                blank.rateCtrl.text = total.toStringAsFixed(2);
                blank.descCtrl.text = _vendorCtrl.text.trim().isNotEmpty
                    ? _vendorCtrl.text.trim()
                    : 'Purchase';
              }
            }
            if (selected['gstin'] case final String gstin) {
              if (_gstinCtrl.text.trim().isEmpty) _gstinCtrl.text = gstin;
            }
          });
        },
      ),
    );
  }

  Future<void> _pickBillDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _billDate = d);
  }

  Future<void> _pickDueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.every((r) => r.description.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item')),
      );
      return;
    }

    final paid = double.tryParse(_paidCtrl.text) ?? 0;
    final PurchaseBillStatus status;
    if (paid <= 0) {
      status = PurchaseBillStatus.unpaid;
    } else if (paid >= _grandTotal - 0.01) {
      status = PurchaseBillStatus.paid;
    } else {
      status = PurchaseBillStatus.partiallyPaid;
    }

    final provider = context.read<AppProvider>();
    final bill = PurchaseBill(
      id: widget.bill?.id ?? provider.newPurchaseBillId(),
      vendorName: _vendorCtrl.text.trim(),
      vendorGstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim().toUpperCase(),
      vendorPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      vendorEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      billNumber: _billNoCtrl.text.trim().isEmpty ? null : _billNoCtrl.text.trim(),
      billDate: _billDate,
      dueDate: _dueDate,
      items: _items
          .where((r) => r.description.isNotEmpty)
          .map((r) => PurchaseBillItem(
                id: r.id,
                description: r.description,
                quantity: r.quantity,
                rate: r.rate,
                taxPercent: r.taxPercent,
              ))
          .toList(),
      status: status,
      amountPaid: paid,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.bill?.createdAt,
      reminderEnabled: _reminderEnabled && _dueDate != null,
      reminderDaysBefore: _reminderDaysBefore,
      receiptImageBase64: _receiptImageBase64,
    );

    if (_isEdit) {
      await provider.updatePurchaseBill(bill);
    } else {
      await provider.addPurchaseBill(bill);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(
        context.read<AppProvider>().profile.currency);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Purchase Bill' : 'New Purchase Bill'),
        actions: [
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Receipt / Bill image ─────────────────────────────────────
            _sectionHeader('Attach Bill / Receipt'),
            const SizedBox(height: 8),
            ReceiptCard(
              imageBase64: _receiptImageBase64,
              scanning: _ocrScanning,
              onCamera: () => _pickReceipt(ImageSource.camera),
              onGallery: () => _pickReceipt(ImageSource.gallery),
              // onScan: _ocrScanning ? null : _scanBill,
              onRemove: () => setState(() => _receiptImageBase64 = null),
            ),
            const SizedBox(height: 16),

            _section('Vendor Details', [
              _field(_vendorCtrl, 'Vendor / Supplier Name *',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _field(_gstinCtrl, 'Vendor GSTIN (optional)',
                  caps: TextCapitalization.characters),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_phoneCtrl, 'Phone',
                    type: TextInputType.phone)),
                const SizedBox(width: 12),
                Expanded(child: _field(_emailCtrl, 'Email',
                    type: TextInputType.emailAddress)),
              ]),
            ]),
            const SizedBox(height: 16),

            _section('Bill Info', [
              Row(children: [
                Expanded(child: _field(_billNoCtrl, 'Bill / Invoice No.')),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickBillDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Bill Date'),
                      child: Text(Fmt.shortDate(_billDate),
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.onCard(context))),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date (optional)',
                    suffixIcon: _dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _dueDate = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _dueDate != null ? Fmt.shortDate(_dueDate!) : 'Tap to set',
                    style: TextStyle(
                        fontSize: 14,
                        color: _dueDate != null
                            ? AppTheme.onCard(context)
                            : AppTheme.subtext(context)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Line items ───────────────────────────────────────────────────
            _sectionHeader('Line Items (with GST)'),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return _ItemEditor(
                key: ValueKey(row.id),
                row: row,
                sym: sym,
                onChanged: () => setState(() {}),
                onRemove: _items.length > 1
                    ? () => setState(() => _items.removeAt(i))
                    : null,
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_ItemRow.blank(_uuid.v4()))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Line Item'),
            ),
            const SizedBox(height: 16),

            // ── Totals ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outline(context)),
              ),
              child: Column(
                children: [
                  _totRow('Subtotal', '$sym${_subtotal.toStringAsFixed(2)}'),
                  _totRow('GST', '$sym${_totalTax.toStringAsFixed(2)}',
                      sub: 'Input Tax Credit claimable'),
                  const Divider(height: 16),
                  _totRow('Total', '$sym${_grandTotal.toStringAsFixed(2)}',
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Payment ──────────────────────────────────────────────────────
            _section('Payment', [
              TextFormField(
                controller: _paidCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Amount Already Paid',
                  prefixText: sym,
                  hintText: '0.00',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Enter a valid amount';
                  if (n > _grandTotal + 0.01) return 'Cannot exceed total';
                  return null;
                },
              ),
              if ((_grandTotal) > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Status → ${_derivedStatus(double.tryParse(_paidCtrl.text) ?? 0).label}',
                  style: TextStyle(
                      fontSize: 12,
                      color: _derivedStatus(double.tryParse(_paidCtrl.text) ?? 0).color,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // ── Notes ────────────────────────────────────────────────────────
            _section('Notes', [
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Internal notes, PO reference, etc.',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Payment Reminder ─────────────────────────────────────────────
            _sectionHeader('Payment Reminder'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outline(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: _reminderEnabled,
                    onChanged: _dueDate == null
                        ? null
                        : (v) => setState(() => _reminderEnabled = v),
                    title: const Text('Remind me to settle this bill',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: _dueDate == null
                        ? const Text('Set a due date above to enable',
                            style: TextStyle(fontSize: 11, color: Colors.orange))
                        : Text(
                            _reminderEnabled
                                ? 'Notification scheduled before due date'
                                : 'No reminder set for this bill',
                            style: const TextStyle(fontSize: 11)),
                    secondary: Icon(
                      Icons.notifications_outlined,
                      color: _reminderEnabled
                          ? AppTheme.primary
                          : AppTheme.subtext(context),
                    ),
                  ),
                  if (_reminderEnabled && _dueDate != null) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remind me:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onCard(context)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final days in [0, 1, 2, 3, 7, 14])
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _reminderDaysBefore = days),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _reminderDaysBefore == days
                                          ? AppTheme.primary
                                          : AppTheme.primary
                                              .withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _reminderDaysBefore == days
                                            ? AppTheme.primary
                                            : AppTheme.primary
                                                .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      days == 0
                                          ? 'On due date'
                                          : '$days day${days == 1 ? '' : 's'} before',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _reminderDaysBefore == days
                                            ? Colors.white
                                            : AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _reminderDaysBefore == 0
                                ? 'You will be notified on ${Fmt.shortDate(_dueDate!)}'
                                : 'You will be notified on ${Fmt.shortDate(_dueDate!.subtract(Duration(days: _reminderDaysBefore)))}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.subtext(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  PurchaseBillStatus _derivedStatus(double paid) {
    if (paid <= 0) return PurchaseBillStatus.unpaid;
    if (paid >= _grandTotal - 0.01) return PurchaseBillStatus.paid;
    return PurchaseBillStatus.partiallyPaid;
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outline(context)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ],
      );

  Widget _sectionHeader(String t) => Text(t,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.subtext(context),
          letterSpacing: 0.5));

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? type,
      TextCapitalization caps = TextCapitalization.words,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      textCapitalization: caps,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  Widget _totRow(String label, String value,
      {bool bold = false, String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: bold ? 14 : 13,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w400,
                    color: AppTheme.onCard(context))),
            if (sub != null)
              Text(sub,
                  style: TextStyle(
                      fontSize: 10, color: const Color(0xFF7C3AED))),
          ]),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w400,
                  color: bold
                      ? AppTheme.onCard(context)
                      : AppTheme.subtext(context))),
        ],
      ),
    );
  }
}

// ── Item row data ─────────────────────────────────────────────────────────────

class _ItemRow {
  final String id;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  double taxPercent;

  _ItemRow({
    required this.id,
    required this.descCtrl,
    required this.qtyCtrl,
    required this.rateCtrl,
    this.taxPercent = 0,
  });

  factory _ItemRow.blank(String id) => _ItemRow(
        id: id,
        descCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        rateCtrl: TextEditingController(),
      );

  String get description => descCtrl.text.trim();
  double get quantity => double.tryParse(qtyCtrl.text) ?? 1;
  double get rate => double.tryParse(rateCtrl.text) ?? 0;
  double get subtotal => quantity * rate;
  double get taxAmount => subtotal * taxPercent / 100;

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

// ── Item editor widget ────────────────────────────────────────────────────────

class _ItemEditor extends StatefulWidget {
  final _ItemRow row;
  final String sym;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _ItemEditor({
    super.key,
    required this.row,
    required this.sym,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  static const _taxRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final lineTotal = r.subtotal + r.taxAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: r.descCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => widget.onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    isDense: true,
                  ),
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      color: AppTheme.error, size: 20),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // ── Qty + Rate row ────────────────────────────────────────────────
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: r.qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  onChanged: (_) { setState(() {}); widget.onChanged(); },
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: r.rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  onChanged: (_) { setState(() {}); widget.onChanged(); },
                  decoration: InputDecoration(
                    labelText: 'Rate',
                    prefixText: '${widget.sym} ',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── GST % chips ───────────────────────────────────────────────────
          Row(
            children: [
              Text('GST %',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.subtext(context))),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _taxRates.map((t) {
                      final selected = r.taxPercent == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => r.taxPercent = t);
                            widget.onChanged();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.inputFill(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.outline(context),
                              ),
                            ),
                            child: Text(
                              '${t.toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.onCard(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          if (r.rate > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (r.taxAmount > 0)
                  Text(
                    'GST: ${widget.sym}${r.taxAmount.toStringAsFixed(2)}  |  ',
                    style: TextStyle(fontSize: 11, color: AppTheme.subtext(context)),
                  ),
                Text(
                  'Total: ${widget.sym}${lineTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
