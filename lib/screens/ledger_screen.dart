import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';

// ─── Entry point: party-wise ledger list ─────────────────────────────────────

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final clients = provider.clients;
    final invoices = provider.invoices
        .where((i) => !i.isQuotation && !i.isDeliveryChallan)
        .toList();

    // Build per-client balance
    final entries = clients.map((c) {
      final clientInvoices =
          invoices.where((i) => i.client?.id == c.id).toList();
      final totalBilled =
          clientInvoices.fold(0.0, (s, i) => s + i.grandTotal);
      final totalPaid =
          clientInvoices.fold(0.0, (s, i) => s + i.amountPaid);
      final outstanding = totalBilled - totalPaid;
      return _ClientLedgerSummary(
          client: c,
          totalBilled: totalBilled,
          totalPaid: totalPaid,
          outstanding: outstanding);
    }).where((e) {
      if (_search.isEmpty) return true;
      return e.client.displayName
          .toLowerCase()
          .contains(_search.toLowerCase());
    }).toList()
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(title: const Text('Ledger')),
      body: Column(
        children: [
          // Summary banner
          Container(
            color: AppTheme.card(context),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _SummaryTile(
                  label: 'Total Billed',
                  value: Fmt.currencyAmount(
                      entries.fold(0.0, (s, e) => s + e.totalBilled),
                      currency),
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 12),
                _SummaryTile(
                  label: 'Total Received',
                  value: Fmt.currencyAmount(
                      entries.fold(0.0, (s, e) => s + e.totalPaid), currency),
                  color: AppTheme.success,
                ),
                const SizedBox(width: 12),
                _SummaryTile(
                  label: 'Outstanding',
                  value: Fmt.currencyAmount(
                      entries.fold(0.0, (s, e) => s + e.outstanding),
                      currency),
                  color: AppTheme.error,
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search party…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppTheme.inputFill(context),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // List
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text('No parties found',
                        style: TextStyle(color: AppTheme.subtext(context))))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _PartyRow(
                      entry: entries[i],
                      currency: currency,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientLedgerScreen(
                              client: entries[i].client),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClientLedgerSummary {
  final Client client;
  final double totalBilled;
  final double totalPaid;
  final double outstanding;
  const _ClientLedgerSummary(
      {required this.client,
      required this.totalBilled,
      required this.totalPaid,
      required this.outstanding});
}

class _PartyRow extends StatelessWidget {
  final _ClientLedgerSummary entry;
  final String currency;
  final VoidCallback onTap;
  const _PartyRow(
      {required this.entry, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final hasBalance = e.outstanding > 0.01;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasBalance
                  ? AppTheme.error.withValues(alpha: 0.3)
                  : AppTheme.outline(context),
              width: 0.8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(
                e.client.displayName.isNotEmpty
                    ? e.client.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.client.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  if (e.client.phone.isNotEmpty)
                    Text(e.client.phone,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.subtext(context))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.currencyAmount(e.outstanding, currency),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color:
                          hasBalance ? AppTheme.error : AppTheme.success),
                ),
                Text(
                  hasBalance ? 'Outstanding' : 'Settled',
                  style: TextStyle(
                      fontSize: 10,
                      color: hasBalance
                          ? AppTheme.error
                          : AppTheme.success),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.subtext(context)),
          ],
        ),
      ),
    );
  }
}

// ─── Per-client ledger detail ─────────────────────────────────────────────────

class ClientLedgerScreen extends StatefulWidget {
  final Client client;
  const ClientLedgerScreen({super.key, required this.client});

  @override
  State<ClientLedgerScreen> createState() => _ClientLedgerScreenState();
}

class _ClientLedgerScreenState extends State<ClientLedgerScreen> {
  static final DateTime _epoch = DateTime(2000, 1, 1);
  late DateTimeRange _range;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange;
  }

  DateTimeRange get _defaultRange {
    final now = DateTime.now();
    return DateTimeRange(start: _epoch, end: DateTime(now.year, now.month, now.day));
  }

  bool get _isAllTime =>
      _range.start == _defaultRange.start && _range.end == _defaultRange.end;

  // Build the full chronological ledger (invoice + payment entries) with a
  // running balance, regardless of the selected date range.
  List<_LedgerRow> _buildAllRows(List<Invoice> invoices) {
    final entries = <_LedgerEntry>[];
    for (final inv in invoices) {
      entries.add(_LedgerEntry(
        date: inv.invoiceDate,
        description: 'Invoice ${inv.invoiceNumber}',
        debit: inv.grandTotal,
        credit: 0,
        isCreditNote: inv.isCreditNote,
      ));
      for (final p in inv.payments) {
        entries.add(_LedgerEntry(
          date: p.date,
          description: 'Payment — ${inv.invoiceNumber}'
              '${p.notes != null ? ' (${p.notes})' : ''}',
          debit: 0,
          credit: p.amount + (p.tdsAmount ?? 0),
        ));
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));

    double running = 0;
    return entries.map((e) {
      running += e.debit - e.credit;
      return _LedgerRow(
        date: e.date,
        description: e.description,
        debit: e.debit,
        credit: e.credit,
        balance: running,
        isCreditNote: e.isCreditNote,
      );
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _epoch,
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _generatePdf({
    required List<_LedgerRow> rows,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required double openingBalance,
    required double closingBalance,
    required List<Invoice> clientInvoices,
  }) async {
    setState(() => _generating = true);
    try {
      final provider = context.read<AppProvider>();
      final today = DateTime.now();

      // Build invoice rows for the statement table
      final invRows = clientInvoices
          .where((i) => !i.invoiceDate.isBefore(rangeStart) &&
              !i.invoiceDate.isAfter(rangeEnd))
          .toList()
        ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

      String agingBucket(Invoice inv) {
        if (inv.amountRemaining <= 0.01) return 'Paid';
        final days = today.difference(inv.dueDate).inDays;
        if (days <= 0) return 'Current';
        if (days <= 30) return '1–30 Days';
        if (days <= 60) return '31–60 Days';
        return '60+ Days';
      }

      final statementInvoiceRows = invRows
          .map((i) => StatementInvoiceRow(
                invoiceNumber: i.invoiceNumber,
                invoiceDate: i.invoiceDate,
                dueDate: i.dueDate,
                grandTotal: i.grandTotal,
                amountPaid: i.amountPaid,
                amountRemaining: i.amountRemaining,
                agingBucket: agingBucket(i),
              ))
          .toList();

      // Compute aging across all outstanding invoices (not just range)
      double agCurrent = 0, ag30 = 0, ag60 = 0, ag90 = 0;
      for (final inv in clientInvoices.where((i) => i.amountRemaining > 0.01)) {
        final days = today.difference(inv.dueDate).inDays;
        if (days <= 0) { agCurrent += inv.amountRemaining; }
        else if (days <= 30) { ag30 += inv.amountRemaining; }
        else if (days <= 60) { ag60 += inv.amountRemaining; }
        else { ag90 += inv.amountRemaining; }
      }

      final bytes = await PdfGenerator.generateLedgerPdf(
        rows: rows
            .map((r) => LedgerPdfRow(
                  date: r.date,
                  description: r.description,
                  debit: r.debit,
                  credit: r.credit,
                  balance: r.balance,
                ))
            .toList(),
        client: widget.client,
        profile: provider.profile,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        openingBalance: openingBalance,
        closingBalance: closingBalance,
        invoiceRows: statementInvoiceRows,
        aging: StatementAging(
          current: agCurrent,
          days30: ag30,
          days60: ag60,
          days90plus: ag90,
        ),
      );

      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        final dir = await getTemporaryDirectory();
        final safe = widget.client.displayName.replaceAll(RegExp(r'[^\w]'), '_');
        final file = File('${dir.path}/statement_$safe.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Account Statement – ${widget.client.displayName}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final client = widget.client;
    final clientInvoices = provider.invoices
        .where((i) =>
            i.client?.id == client.id &&
            !i.isQuotation &&
            !i.isDeliveryChallan)
        .toList();

    final allRows = _buildAllRows(clientInvoices);

    final rangeStart =
        DateTime(_range.start.year, _range.start.month, _range.start.day);
    final rangeEnd = DateTime(
        _range.end.year, _range.end.month, _range.end.day, 23, 59, 59, 999);

    // Opening balance = running balance just before the selected range.
    double openingBalance = 0;
    for (final r in allRows) {
      if (r.date.isBefore(rangeStart)) {
        openingBalance = r.balance;
      } else {
        break;
      }
    }

    final rows = allRows
        .where((r) => !r.date.isBefore(rangeStart) && !r.date.isAfter(rangeEnd))
        .toList();
    final closingBalance = rows.isNotEmpty ? rows.last.balance : openingBalance;
    final periodBilled = rows.fold(0.0, (s, r) => s + r.debit);
    final periodReceived = rows.fold(0.0, (s, r) => s + r.credit);

    // Aging buckets across ALL outstanding invoices for this client
    final today = DateTime.now();
    double agCurrent = 0, ag30 = 0, ag60 = 0, ag90 = 0;
    for (final inv in clientInvoices.where((i) => i.amountRemaining > 0.01)) {
      final days = today.difference(inv.dueDate).inDays;
      if (days <= 0) { agCurrent += inv.amountRemaining; }
      else if (days <= 30) { ag30 += inv.amountRemaining; }
      else if (days <= 60) { ag60 += inv.amountRemaining; }
      else { ag90 += inv.amountRemaining; }
    }
    final hasOutstanding = (agCurrent + ag30 + ag60 + ag90) > 0.01;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(client.displayName),
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: () => _generatePdf(
                rows: rows,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                openingBalance: openingBalance,
                closingBalance: closingBalance,
                clientInvoices: clientInvoices,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Balance header
          Container(
            color: AppTheme.card(context),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _BalanceTile(
                      label: 'Billed',
                      value: Fmt.currencyAmount(periodBilled, currency),
                      color: AppTheme.primary),
                ),
                Expanded(
                  child: _BalanceTile(
                      label: 'Received',
                      value: Fmt.currencyAmount(periodReceived, currency),
                      color: AppTheme.success),
                ),
                Expanded(
                  child: _BalanceTile(
                      label: 'Closing Balance',
                      value: Fmt.currencyAmount(closingBalance, currency),
                      color: closingBalance > 0.01
                          ? AppTheme.error
                          : AppTheme.success),
                ),
              ],
            ),
          ),
          // Aging analysis (only when there's an outstanding balance)
          if (hasOutstanding) ...[
            const Divider(height: 1),
            Container(
              color: AppTheme.card(context),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AGING ANALYSIS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppTheme.subtext(context)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _AgingChip(label: 'Current',    amount: agCurrent, currency: currency, color: AppTheme.success),
                      const SizedBox(width: 8),
                      _AgingChip(label: '1–30 days',  amount: ag30,      currency: currency, color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _AgingChip(label: '31–60 days', amount: ag60,      currency: currency, color: const Color(0xFFEA580C)),
                      const SizedBox(width: 8),
                      _AgingChip(label: '60+ days',   amount: ag90,      currency: currency, color: AppTheme.error),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // Date range selector
          Container(
            color: AppTheme.card(context),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.outline(context)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range_outlined,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isAllTime
                                  ? 'All time'
                                  : '${Fmt.date(_range.start)}  →  ${Fmt.date(_range.end)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onCard(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_isAllTime) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _range = _defaultRange),
                    child: const Text('All time'),
                  ),
                ],
              ],
            ),
          ),
          // Column headers
          Container(
            color: AppTheme.card(context).withValues(alpha: 0.6),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 70, child: _ColHeader('Date')),
                const Expanded(child: _ColHeader('Description')),
                const SizedBox(width: 72, child: _ColHeader('Debit', right: true)),
                const SizedBox(width: 72, child: _ColHeader('Credit', right: true)),
                const SizedBox(width: 80, child: _ColHeader('Balance', right: true)),
              ],
            ),
          ),
          // Opening balance
          Container(
            color: AppTheme.card(context).withValues(alpha: 0.6),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Opening Balance',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.subtext(context))),
                ),
                Text(
                  Fmt.currencyAmount(openingBalance, currency),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: openingBalance > 0.01
                          ? AppTheme.error
                          : AppTheme.success),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text('No transactions in this period',
                        style:
                            TextStyle(color: AppTheme.subtext(context))))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppTheme.outline(context)),
                    itemBuilder: (ctx, i) =>
                        _LedgerRowWidget(row: rows[i], currency: currency),
                  ),
          ),
          // Footer total
          Container(
            color: AppTheme.card(context),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Closing Balance',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(
                  Fmt.currencyAmount(closingBalance, currency),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: closingBalance > 0.01
                          ? AppTheme.error
                          : AppTheme.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ledger row data + widget ─────────────────────────────────────────────────

class _LedgerEntry {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final bool isCreditNote;
  const _LedgerEntry({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    this.isCreditNote = false,
  });
}

class _LedgerRow {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final bool isCreditNote;
  const _LedgerRow({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.isCreditNote = false,
  });
}

class _LedgerRowWidget extends StatelessWidget {
  final _LedgerRow row;
  final String currency;
  const _LedgerRowWidget({required this.row, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isPayment = row.credit > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              _shortDate(row.date),
              style: TextStyle(
                  fontSize: 11, color: AppTheme.subtext(context)),
            ),
          ),
          Expanded(
            child: Text(
              row.description,
              style: TextStyle(
                  fontSize: 12,
                  color: isPayment
                      ? AppTheme.success
                      : AppTheme.onCard(context)),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              row.debit > 0 ? _fmt(row.debit) : '',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppTheme.primary),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              row.credit > 0 ? _fmt(row.credit) : '',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppTheme.success),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(row.balance),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: row.balance > 0.01
                    ? AppTheme.error
                    : AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);
  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
}

// ─── Small helper widgets ─────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: AppTheme.subtext(context))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BalanceTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: AppTheme.subtext(context))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final bool right;
  const _ColHeader(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.subtext(context)),
    );
  }
}

class _AgingChip extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;

  const _AgingChip({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: amount > 0.01 ? color.withValues(alpha: 0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: amount > 0.01 ? color.withValues(alpha: 0.4) : AppTheme.outline(context),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: amount > 0.01 ? color : AppTheme.subtext(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              amount > 0.01 ? Fmt.currencyAmount(amount, currency) : '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: amount > 0.01 ? color : AppTheme.subtext(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
