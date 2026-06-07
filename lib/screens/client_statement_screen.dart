import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';
import '../widgets/status_badge.dart';

class ClientStatementScreen extends StatefulWidget {
  const ClientStatementScreen({super.key});

  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen> {
  Client? _selectedClient;
  late DateTimeRange _range;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
    );
  }

  List<Invoice> _filteredInvoices(AppProvider provider) {
    if (_selectedClient == null) return [];
    final rangeEnd = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      23,
      59,
      59,
      999,
    );
    return provider.invoicesOnly
        .where((inv) =>
            inv.client?.id == _selectedClient!.id &&
            !inv.invoiceDate.isBefore(_range.start) &&
            !inv.invoiceDate.isAfter(rangeEnd))
        .toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
  }

  Future<void> _openClientPicker(AppProvider provider) async {
    final clients = provider.clients;
    String search = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final filtered = search.isEmpty
                ? clients
                : clients
                    .where((c) =>
                        c.displayName
                            .toLowerCase()
                            .contains(search.toLowerCase()) ||
                        c.email.toLowerCase().contains(search.toLowerCase()))
                    .toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    // Handle
                    SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.outline(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Select Client',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onCard(context),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search clients...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppTheme.subtext(context),
                            size: 20,
                          ),
                          hintStyle: TextStyle(
                            color: AppTheme.subtext(context),
                            fontSize: 14,
                          ),
                        ),
                        onChanged: (v) => setModal(() => search = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No clients found',
                                style: TextStyle(
                                  color: AppTheme.subtext(context),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final c = filtered[i];
                                final selected =
                                    _selectedClient?.id == c.id;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: selected
                                        ? AppTheme.primary
                                        : AppTheme.primary
                                            .withValues(alpha: 0.1),
                                    radius: 20,
                                    child: Text(
                                      c.displayName
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    c.displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.onCard(context),
                                    ),
                                  ),
                                  subtitle: c.email.isNotEmpty
                                      ? Text(
                                          c.email,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.subtext(context),
                                          ),
                                        )
                                      : null,
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppTheme.primary,
                                          size: 20,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() => _selectedClient = c);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
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

  Future<void> _generatePdf(
      AppProvider provider, List<Invoice> invoices) async {
    if (_selectedClient == null || invoices.isEmpty) return;
    setState(() => _generating = true);
    try {
      final profile = provider.profile;
      final bytes = await PdfGenerator.generateClientStatementPdf(
        invoices: invoices,
        client: _selectedClient!,
        profile: profile,
        rangeStart: _range.start,
        rangeEnd: _range.end,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
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
    final invoices = _filteredInvoices(provider);

    final totalBilled =
        invoices.fold(0.0, (sum, inv) => sum + inv.grandTotal);
    final totalPaid =
        invoices.fold(0.0, (sum, inv) => sum + inv.amountPaid);
    final balanceDue =
        invoices.fold(0.0, (sum, inv) => sum + inv.amountRemaining);

    final currency = provider.profile.currency;
    final symbol = Fmt.currencySymbol(currency);

    return Scaffold(

      appBar: AppBar(
        title: const Text('Client Statement'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _generating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _selectedClient != null && invoices.isNotEmpty
                        ? () => _generatePdf(provider, invoices)
                        : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Generate PDF'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      disabledForegroundColor:
                          AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Client selector ────────────────────────────────────────────────
          _SectionLabel(label: 'Client'),
          SizedBox(height: 6),
          GestureDetector(
            onTap: () => _openClientPicker(provider),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _selectedClient != null
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : AppTheme.surface,
                    child: _selectedClient != null
                        ? Text(
                            _selectedClient!.displayName
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          )
                        : Icon(
                            Icons.person_outline_rounded,
                            color: AppTheme.subtext(context),
                            size: 22,
                          ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _selectedClient != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedClient!.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onCard(context),
                                ),
                              ),
                              if (_selectedClient!.email.isNotEmpty) ...[
                                SizedBox(height: 2),
                                Text(
                                  _selectedClient!.email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.subtext(context),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            'Select a client',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.subtext(context),
                            ),
                          ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.subtext(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Date range selector ────────────────────────────────────────────
          _SectionLabel(label: 'Date Range'),
          SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _DateFieldButton(
                    label: 'From',
                    date: _range.start,
                    onTap: _pickDateRange,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: AppTheme.outline(context),
                ),
                Expanded(
                  child: _DateFieldButton(
                    label: 'To',
                    date: _range.end,
                    onTap: _pickDateRange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Summary + table (only when a client is selected) ───────────────
          if (_selectedClient == null) ...[
            const SizedBox(height: 48),
            _EmptyState(
              icon: Icons.account_circle_outlined,
              title: 'No client selected',
              subtitle:
                  'Select a client above to view their invoices and payment history.',
            ),
          ] else ...[
            // Summary cards
            _SectionLabel(label: 'Summary'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _MiniSummaryCard(
                    label: 'Total Billed',
                    amount: Fmt.currency(totalBilled, symbol: symbol),
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniSummaryCard(
                    label: 'Total Paid',
                    amount: Fmt.currency(totalPaid, symbol: symbol),
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniSummaryCard(
                    label: 'Balance Due',
                    amount: Fmt.currency(balanceDue, symbol: symbol),
                    color: balanceDue > 0
                        ? AppTheme.error
                        : AppTheme.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Transaction table / list
            _SectionLabel(label: 'Transactions'),
            const SizedBox(height: 6),
            if (invoices.isEmpty)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.cardShadow,
                ),
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No invoices found',
                  subtitle:
                      'No invoices for this client in the selected period.',
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.cardShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Header row
                    Container(
                      color: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Date',
                              style: _kHeaderStyle,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Invoice #',
                              style: _kHeaderStyle,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Status',
                              style: _kHeaderStyle,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Amount',
                              textAlign: TextAlign.right,
                              style: _kHeaderStyle,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Paid',
                              textAlign: TextAlign.right,
                              style: _kHeaderStyle,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Balance',
                              textAlign: TextAlign.right,
                              style: _kHeaderStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: invoices.length,
                      separatorBuilder: (_, i) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final inv = invoices[i];
                        final balance = inv.amountRemaining;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Date
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Fmt.shortDate(inv.invoiceDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.subtext(context),
                                  ),
                                ),
                              ),
                              // Invoice #
                              Expanded(
                                flex: 3,
                                child: Text(
                                  inv.invoiceNumber,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onCard(context),
                                  ),
                                ),
                              ),
                              // Status badge
                              Expanded(
                                flex: 2,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: StatusBadge(
                                    status: inv.status,
                                    small: true,
                                  ),
                                ),
                              ),
                              // Grand Total
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Fmt.currency(inv.grandTotal,
                                      symbol: symbol),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onCard(context),
                                  ),
                                ),
                              ),
                              // Amount Paid
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Fmt.currency(inv.amountPaid,
                                      symbol: symbol),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.success,
                                  ),
                                ),
                              ),
                              // Balance
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Fmt.currency(balance, symbol: symbol),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: balance > 0
                                        ? AppTheme.error
                                        : AppTheme.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Footer totals row
                    Divider(height: 1),
                    Container(
                      color: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: Text(
                              'Totals',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onCard(context),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              Fmt.currency(totalBilled, symbol: symbol),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onCard(context),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              Fmt.currency(totalPaid, symbol: symbol),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              Fmt.currency(balanceDue, symbol: symbol),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: balanceDue > 0
                                    ? AppTheme.error
                                    : AppTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// ── Header text style constant ────────────────────────────────────────────────

const _kHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.3,
);

// ── Reusable small widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.subtext(context),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DateFieldButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateFieldButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.subtext(context),
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppTheme.primary,
                ),
                SizedBox(width: 5),
                Text(
                  Fmt.date(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _MiniSummaryCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.subtext(context),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppTheme.primary.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.subtext(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
