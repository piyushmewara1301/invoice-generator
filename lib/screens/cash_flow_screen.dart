import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../models/purchase_bill.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

class CashFlowScreen extends StatelessWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final sym = Fmt.currencySymbol(currency);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Inflows: outstanding invoices (sent / partially-paid / overdue) ───────
    final outstandingInvoices = provider.invoices.where((inv) =>
        !inv.isQuotation &&
        !inv.isCreditNote &&
        inv.status != InvoiceStatus.paid &&
        inv.status != InvoiceStatus.cancelled &&
        inv.status != InvoiceStatus.draft).toList();

    // ── Outflows: unpaid / partial purchase bills ─────────────────────────────
    final unpaidBills = provider.purchaseBills.where((b) =>
        b.status != PurchaseBillStatus.paid).toList();

    // ── Bucket helpers ────────────────────────────────────────────────────────
    final List<_CfEntry> inflows = outstandingInvoices.map((inv) {
      final due = DateTime(inv.dueDate.year, inv.dueDate.month, inv.dueDate.day);
      return _CfEntry(
        label: inv.client?.displayName ?? 'Unknown Client',
        sub: '#${inv.invoiceNumber}',
        amount: inv.amountRemaining,
        dueDate: due,
        isOverdue: inv.isOverdue,
        isInflow: true,
      );
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final List<_CfEntry> outflows = unpaidBills.map((b) {
      final due = b.dueDate != null
          ? DateTime(b.dueDate!.year, b.dueDate!.month, b.dueDate!.day)
          : today;
      return _CfEntry(
        label: b.vendorName,
        sub: b.billNumber != null ? '#${b.billNumber}' : 'Bill',
        amount: b.amountDue,
        dueDate: due,
        isOverdue: b.isOverdue,
        isInflow: false,
      );
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // ── Window totals ─────────────────────────────────────────────────────────
    final in7  = _sumWindow(inflows,  today, 7);
    final in30 = _sumWindow(inflows,  today, 30);
    final out7  = _sumWindow(outflows, today, 7);
    final out30 = _sumWindow(outflows, today, 30);

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Flow Forecast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 7-day and 30-day summary cards ──────────────────────────────────
          _SummaryRow(
            sym: sym,
            in7: in7, in30: in30,
            out7: out7, out30: out30,
          ),
          const SizedBox(height: 20),

          // ── Inflows section ─────────────────────────────────────────────────
          _SectionHeader(
            title: 'Expected Inflows',
            icon: Icons.trending_up_rounded,
            color: AppTheme.success,
            count: inflows.length,
            total: '$sym${Fmt.compact(inflows.fold(0.0, (s, e) => s + e.amount))}',
          ),
          const SizedBox(height: 8),
          if (inflows.isEmpty)
            _EmptyCard(message: 'No outstanding invoices 🎉')
          else
            ..._groupedEntries(context, inflows, today, sym),

          const SizedBox(height: 20),

          // ── Outflows section ────────────────────────────────────────────────
          _SectionHeader(
            title: 'Expected Outflows',
            icon: Icons.trending_down_rounded,
            color: AppTheme.error,
            count: outflows.length,
            total: '$sym${Fmt.compact(outflows.fold(0.0, (s, e) => s + e.amount))}',
          ),
          const SizedBox(height: 8),
          if (outflows.isEmpty)
            _EmptyCard(message: 'No unpaid purchase bills')
          else
            ..._groupedEntries(context, outflows, today, sym),

          const SizedBox(height: 32),

          // ── Net summary ─────────────────────────────────────────────────────
          _NetSummary(
            sym: sym,
            totalIn: inflows.fold(0.0, (s, e) => s + e.amount),
            totalOut: outflows.fold(0.0, (s, e) => s + e.amount),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  double _sumWindow(List<_CfEntry> entries, DateTime today, int days) {
    final end = today.add(Duration(days: days));
    return entries
        .where((e) => !e.dueDate.isAfter(end))
        .fold(0.0, (s, e) => s + e.amount);
  }

  List<Widget> _groupedEntries(
    BuildContext context,
    List<_CfEntry> entries,
    DateTime today,
    String sym,
  ) {
    // Group by bucket label
    final groups = <String, List<_CfEntry>>{};
    for (final e in entries) {
      final bucket = _bucketLabel(e.dueDate, today);
      (groups[bucket] ??= []).add(e);
    }

    return groups.entries.map((g) {
      final bucketTotal = g.value.fold(0.0, (s, e) => s + e.amount);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(g.key,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.subtext(context),
                        letterSpacing: 0.4)),
                const Spacer(),
                Text('$sym${Fmt.compact(bucketTotal)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.subtext(context))),
              ],
            ),
          ),
          ...g.value.map((e) => _EntryTile(entry: e, sym: sym)),
          const SizedBox(height: 4),
        ],
      );
    }).toList();
  }

  String _bucketLabel(DateTime date, DateTime today) {
    final diff = date.difference(today).inDays;
    if (diff < 0) return '🔴 Overdue';
    if (diff == 0) return '🟡 Due Today';
    if (diff <= 7) return '📅 Next 7 Days';
    if (diff <= 30) return '📆 Next 30 Days';
    return '🗓 Later';
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _CfEntry {
  final String label;
  final String sub;
  final double amount;
  final DateTime dueDate;
  final bool isOverdue;
  final bool isInflow;

  const _CfEntry({
    required this.label,
    required this.sub,
    required this.amount,
    required this.dueDate,
    required this.isOverdue,
    required this.isInflow,
  });
}

// ── Summary row (7-day / 30-day) ──────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String sym;
  final double in7, in30, out7, out30;

  const _SummaryRow({
    required this.sym,
    required this.in7, required this.in30,
    required this.out7, required this.out30,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _WindowCard(
          title: '7-Day Forecast',
          sym: sym,
          inflow: in7,
          outflow: out7,
        )),
        const SizedBox(width: 12),
        Expanded(child: _WindowCard(
          title: '30-Day Forecast',
          sym: sym,
          inflow: in30,
          outflow: out30,
        )),
      ],
    );
  }
}

class _WindowCard extends StatelessWidget {
  final String title;
  final String sym;
  final double inflow;
  final double outflow;

  const _WindowCard({
    required this.title,
    required this.sym,
    required this.inflow,
    required this.outflow,
  });

  @override
  Widget build(BuildContext context) {
    final net = inflow - outflow;
    final isPositive = net >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline(context)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.subtext(context))),
          const SizedBox(height: 10),
          _miniRow(context, 'In', inflow, AppTheme.success),
          const SizedBox(height: 4),
          _miniRow(context, 'Out', outflow, AppTheme.error),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context))),
              Text(
                '${isPositive ? '+' : ''}$sym${Fmt.compact(net)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isPositive ? AppTheme.success : AppTheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniRow(BuildContext context, String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: AppTheme.subtext(context))),
        Text('$sym${Fmt.compact(value)}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final String total;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
        const Spacer(),
        Text(total,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context))),
      ],
    );
  }
}

// ── Entry tile ────────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final _CfEntry entry;
  final String sym;

  const _EntryTile({required this.entry, required this.sym});

  @override
  Widget build(BuildContext context) {
    final color = entry.isInflow ? AppTheme.success : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: entry.isOverdue
              ? AppTheme.error.withValues(alpha: 0.35)
              : AppTheme.outline(context),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(entry.sub,
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.subtext(context))),
                    const Text(' · '),
                    Text(
                      entry.isOverdue
                          ? 'Overdue ${_daysDiff(entry.dueDate)}'
                          : 'Due ${Fmt.shortDate(entry.dueDate)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: entry.isOverdue
                              ? AppTheme.error
                              : AppTheme.subtext(context),
                          fontWeight: entry.isOverdue
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${entry.isInflow ? '+' : '-'}$sym${Fmt.compact(entry.amount)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }

  String _daysDiff(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'today';
    return 'by ${diff}d';
  }
}

// ── Empty card ────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Text(message,
          style: TextStyle(
              fontSize: 13, color: AppTheme.subtext(context))),
    );
  }
}

// ── Net summary ───────────────────────────────────────────────────────────────

class _NetSummary extends StatelessWidget {
  final String sym;
  final double totalIn;
  final double totalOut;

  const _NetSummary({
    required this.sym,
    required this.totalIn,
    required this.totalOut,
  });

  @override
  Widget build(BuildContext context) {
    final net = totalIn - totalOut;
    final isPositive = net >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF059669), const Color(0xFF10B981)]
              : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overall Net Position',
              style: TextStyle(
                  fontSize: 13, color: Colors.white70,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '${isPositive ? '+' : ''}$sym${Fmt.compact(net)}',
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1),
          ),
          const SizedBox(height: 4),
          Text(
            isPositive
                ? 'You expect to receive more than you owe — healthy outlook.'
                : 'Outflows exceed inflows — consider following up on invoices.',
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _netStat('Total Inflows', '$sym${Fmt.compact(totalIn)}'),
              const SizedBox(width: 24),
              _netStat('Total Outflows', '$sym${Fmt.compact(totalOut)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _netStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white60)),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      );
}
