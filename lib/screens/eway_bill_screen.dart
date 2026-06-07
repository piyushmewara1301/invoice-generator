import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class EWayBillScreen extends StatelessWidget {
  const EWayBillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final eligible = provider.invoices.where((i) =>
        !i.isQuotation &&
        !i.isCreditNote &&
        !i.isDeliveryChallan &&
        i.status != InvoiceStatus.cancelled).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final pending   = eligible.where((i) => i.ewayBillNo == null).toList();
    final generated = eligible.where((i) => i.ewayBillNo != null).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          title: const Text('E-Way Bills'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Generated'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BillList(
              invoices: pending,
              emptyMessage: 'No invoices pending E-Way Bill',
              emptyIcon: Icons.check_circle_outline,
            ),
            _BillList(
              invoices: generated,
              emptyMessage: 'No E-Way Bills generated yet',
              emptyIcon: Icons.local_shipping_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invoice list tab ──────────────────────────────────────────────────────────

class _BillList extends StatelessWidget {
  final List<Invoice> invoices;
  final String emptyMessage;
  final IconData emptyIcon;
  const _BillList(
      {required this.invoices,
      required this.emptyMessage,
      required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    final sym =
        Fmt.currencySymbol(context.read<AppProvider>().profile.currency);
    if (invoices.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(emptyIcon,
              size: 64,
              color: AppTheme.subtext(context).withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(emptyMessage,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onCard(context))),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (_, i) => _InvoiceTile(invoice: invoices[i], sym: sym),
    );
  }
}

// ── Invoice tile ──────────────────────────────────────────────────────────────

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final String sym;
  const _InvoiceTile({required this.invoice, required this.sym});

  @override
  Widget build(BuildContext context) {
    final hasEwb = invoice.ewayBillNo != null;
    final isExpired = hasEwb &&
        invoice.ewayBillValidTill != null &&
        invoice.ewayBillValidTill!.isBefore(DateTime.now());

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EWayBillFormScreen(invoice: invoice)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpired
                ? AppTheme.error.withValues(alpha: 0.4)
                : AppTheme.outline(context),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (hasEwb
                      ? isExpired
                          ? AppTheme.error
                          : const Color(0xFF059669)
                      : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasEwb
                  ? isExpired
                      ? Icons.warning_amber_rounded
                      : Icons.local_shipping_rounded
                  : Icons.add_road_outlined,
              size: 20,
              color: hasEwb
                  ? isExpired
                      ? AppTheme.error
                      : const Color(0xFF059669)
                  : const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('#${invoice.invoiceNumber}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context))),
              const SizedBox(height: 2),
              Text(invoice.client?.displayName ?? 'No customer',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.subtext(context))),
              if (hasEwb) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Text(
                    'EWB: ${invoice.ewayBillNo}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isExpired
                            ? AppTheme.error
                            : const Color(0xFF059669)),
                  ),
                  if (invoice.ewayBillValidTill != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      isExpired
                          ? 'Expired ${Fmt.shortDate(invoice.ewayBillValidTill!)}'
                          : 'Valid till ${Fmt.shortDate(invoice.ewayBillValidTill!)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: isExpired
                              ? AppTheme.error
                              : AppTheme.subtext(context)),
                    ),
                  ],
                ]),
              ],
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$sym${Fmt.compact(invoice.grandTotal)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(context))),
            const SizedBox(height: 4),
            Text(Fmt.shortDate(invoice.invoiceDate),
                style:
                    TextStyle(fontSize: 11, color: AppTheme.subtext(context))),
          ]),
        ]),
      ),
    );
  }
}

// ── Form screen ───────────────────────────────────────────────────────────────

class EWayBillFormScreen extends StatefulWidget {
  final Invoice invoice;
  const EWayBillFormScreen({super.key, required this.invoice});

  @override
  State<EWayBillFormScreen> createState() => _EWayBillFormScreenState();
}

class _EWayBillFormScreenState extends State<EWayBillFormScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _billNoCtrl  = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _transpCtrl  = TextEditingController();
  final _distCtrl    = TextEditingController();

  String _transportMode = 'Road';
  DateTime _billDate    = DateTime.now();
  DateTime _validTill   = DateTime.now().add(const Duration(days: 1));
  bool _saving          = false;

  static const _modes = ['Road', 'Rail', 'Air', 'Ship'];

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    if (inv.ewayBillNo != null) {
      _billNoCtrl.text = inv.ewayBillNo!;
      if (inv.ewayBillDate != null)    _billDate   = inv.ewayBillDate!;
      if (inv.ewayBillValidTill != null) _validTill = inv.ewayBillValidTill!;
    }
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _vehicleCtrl.dispose();
    _transpCtrl.dispose();
    _distCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      widget.invoice
        ..ewayBillNo        = _billNoCtrl.text.trim()
        ..ewayBillDate      = _billDate
        ..ewayBillValidTill = _validTill;
      await context.read<AppProvider>().saveInvoice(widget.invoice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-Way Bill details saved')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(bool isValidTill) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isValidTill ? _validTill : _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isValidTill) {
          _validTill = picked;
        } else {
          _billDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv    = widget.invoice;
    final sym    = Fmt.currencySymbol(context.read<AppProvider>().profile.currency);
    final hasEwb = inv.ewayBillNo != null;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text('E-Way Bill · #${inv.invoiceNumber}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Invoice summary ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_outlined,
                    color: Colors.white, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Invoice #${inv.invoiceNumber}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text(
                        '${inv.client?.displayName ?? 'No customer'} · $sym${Fmt.compact(inv.grandTotal)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                  ]),
                ),
                if (hasEwb)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('EWB Active',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── EWB number ──────────────────────────────────────────────────
            _SectionLabel('E-Way Bill Details'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _billNoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('EWB Number', Icons.tag_rounded,
                  hint: '12-digit number from portal'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'EWB number is required' : null,
            ),
            const SizedBox(height: 12),

            // ── Dates ───────────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: _DateTile(
                  label: 'Bill Date',
                  date: _billDate,
                  onTap: () => _pickDate(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTile(
                  label: 'Valid Till',
                  date: _validTill,
                  onTap: () => _pickDate(true),
                  isExpired: _validTill.isBefore(DateTime.now()),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Transport details ────────────────────────────────────────────
            _SectionLabel('Transport Details'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _transportMode,
              decoration: _dec('Mode of Transport', Icons.commute_outlined),
              items: _modes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _transportMode = v ?? 'Road'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicleCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('Vehicle Number', Icons.directions_car_outlined,
                  hint: 'e.g. MH12AB1234'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _transpCtrl,
              decoration: _dec('Transporter Name / ID',
                  Icons.local_shipping_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _distCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('Approximate Distance (km)', Icons.straighten_outlined),
            ),
            const SizedBox(height: 8),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Generate the EWB number on the GST E-Way Bill portal '
                    '(ewaybillgst.gov.in) and enter it here to link it to this invoice.',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF1E40AF)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label:
                    Text(_saving ? 'Saving…' : hasEwb ? 'Update EWB' : 'Save EWB'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF1D4ED8),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.subtext(context),
          letterSpacing: 0.4));
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final bool isExpired;
  const _DateTile(
      {required this.label,
      required this.date,
      required this.onTap,
      this.isExpired = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isExpired
                  ? AppTheme.error.withValues(alpha: 0.6)
                  : AppTheme.outline(context),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: AppTheme.subtext(context))),
            const SizedBox(height: 4),
            Row(children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isExpired ? AppTheme.error : AppTheme.subtext(context),
              ),
              const SizedBox(width: 6),
              Text(
                Fmt.shortDate(date),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isExpired ? AppTheme.error : AppTheme.onCard(context)),
              ),
            ]),
          ]),
        ),
      );
}
