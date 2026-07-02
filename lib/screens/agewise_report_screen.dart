import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../providers/app_provider.dart';
import '../models/invoice.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/late_fee_calculator.dart';
import 'create_invoice_screen.dart';

// ── Bucket definition ─────────────────────────────────────────────────────────

class _Bucket {
  final String label;
  final Color color;
  final List<Invoice> invoices;
  final double penaltyTotal;

  const _Bucket({
    required this.label,
    required this.color,
    required this.invoices,
    this.penaltyTotal = 0,
  });

  double get total =>
      invoices.fold(0.0, (sum, inv) => sum + inv.amountRemaining);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AgewiseReportScreen extends StatefulWidget {
  const AgewiseReportScreen({super.key});

  @override
  State<AgewiseReportScreen> createState() => _AgewiseReportScreenState();
}

class _AgewiseReportScreenState extends State<AgewiseReportScreen> {
  // Track which buckets are expanded
  final List<bool> _expanded = List.filled(5, false);

  @override
  void dispose() {
    super.dispose();
  }

  List<_Bucket> _buildBuckets(
      List<Invoice> outstanding, BusinessProfile profile) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final notYetDue = <Invoice>[];
    final days1to30 = <Invoice>[];
    final days31to60 = <Invoice>[];
    final days61to90 = <Invoice>[];
    final days90plus = <Invoice>[];

    for (final inv in outstanding) {
      final dueDate =
          DateTime(inv.dueDate.year, inv.dueDate.month, inv.dueDate.day);
      final diff = todayDate.difference(dueDate).inDays;

      if (diff <= 0) {
        notYetDue.add(inv);
      } else if (diff <= 30) {
        days1to30.add(inv);
      } else if (diff <= 60) {
        days31to60.add(inv);
      } else if (diff <= 90) {
        days61to90.add(inv);
      } else {
        days90plus.add(inv);
      }
    }

    double bucketPenalty(List<Invoice> invoices) => invoices.fold(
        0.0,
        (sum, inv) =>
            sum + LateFeeCalculator.forInvoice(inv, profile).amount);

    return [
      _Bucket(
        label: 'Not Yet Due',
        color: AppTheme.primary,
        invoices: notYetDue,
        penaltyTotal: 0, // not overdue, never a penalty
      ),
      _Bucket(
        label: '1–30 Days',
        color: AppTheme.warning,
        invoices: days1to30,
        penaltyTotal: bucketPenalty(days1to30),
      ),
      _Bucket(
        label: '31–60 Days',
        color: const Color(0xFFF97316),
        invoices: days31to60,
        penaltyTotal: bucketPenalty(days31to60),
      ),
      _Bucket(
        label: '61–90 Days',
        color: AppTheme.error,
        invoices: days61to90,
        penaltyTotal: bucketPenalty(days61to90),
      ),
      _Bucket(
        label: '90+ Days',
        color: const Color(0xFF991B1B),
        invoices: days90plus,
        penaltyTotal: bucketPenalty(days90plus),
      ),
    ];
  }

  int _daysOverdue(Invoice inv) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDate =
        DateTime(inv.dueDate.year, inv.dueDate.month, inv.dueDate.day);
    final diff = todayDate.difference(dueDate).inDays;
    return diff > 0 ? diff : 0;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.profile;
    final currency = profile.currency;

    final outstanding = provider.invoicesOnly
        .where((inv) =>
            inv.status != InvoiceStatus.paid &&
            inv.status != InvoiceStatus.cancelled)
        .toList();

    final totalOutstanding =
        outstanding.fold(0.0, (sum, inv) => sum + inv.amountRemaining);

    final buckets = _buildBuckets(outstanding, profile);
    final allClear = outstanding.isEmpty;

    final totalPenalty = profile.lateFeeEnabled
        ? buckets.fold(0.0, (sum, b) => sum + b.penaltyTotal)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outstanding Analysis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Total outstanding banner ─────────────────────────────────
            _OutstandingBanner(
              totalAmount: Fmt.currencyAmount(totalOutstanding, currency),
              invoiceCount: outstanding.length,
              penaltyTotal: profile.lateFeeEnabled && totalPenalty > 0
                  ? Fmt.currencyAmount(totalPenalty, currency)
                  : null,
            ),
            const SizedBox(height: 20),

            if (allClear) ...[
              _AllClearState(),
            ] else ...[
              // ── Bucket cards ──────────────────────────────────────────
              ...buckets.asMap().entries.map((entry) {
                final i = entry.key;
                final bucket = entry.value;
                if (bucket.invoices.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BucketCard(
                    bucket: bucket,
                    currency: currency,
                    expanded: _expanded[i],
                    onToggle: () =>
                        setState(() => _expanded[i] = !_expanded[i]),
                    daysOverdueFn: _daysOverdue,
                    showPenalty: profile.lateFeeEnabled,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Outstanding banner ────────────────────────────────────────────────────────

class _OutstandingBanner extends StatelessWidget {
  final String totalAmount;
  final int invoiceCount;
  /// Non-null when late fee is enabled and total accrued penalty > 0.
  final String? penaltyTotal;

  const _OutstandingBanner({
    required this.totalAmount,
    required this.invoiceCount,
    this.penaltyTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Outstanding',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  totalAmount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'} outstanding',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (penaltyTotal != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        '$penaltyTotal accrued penalty',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bucket card ───────────────────────────────────────────────────────────────

class _BucketCard extends StatelessWidget {
  final _Bucket bucket;
  final String currency;
  final bool expanded;
  final VoidCallback onToggle;
  final int Function(Invoice) daysOverdueFn;
  final bool showPenalty;

  const _BucketCard({
    required this.bucket,
    required this.currency,
    required this.expanded,
    required this.onToggle,
    required this.daysOverdueFn,
    this.showPenalty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // ── Header row ───────────────────────────────────────────────
          InkWell(
            borderRadius: expanded
                ? const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  )
                : BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: bucket.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bucket.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onCard(context),
                          ),
                        ),
                        Text(
                          '${bucket.invoices.length} invoice${bucket.invoices.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.subtext(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.currencyAmount(bucket.total, currency),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: bucket.color,
                        ),
                      ),
                      if (showPenalty && bucket.penaltyTotal > 0)
                        Text(
                          '+${Fmt.currencyAmount(bucket.penaltyTotal, currency)} penalty',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error.withValues(alpha: 0.75),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppTheme.subtext(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded invoice list ───────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: AppTheme.outline(context)),
                ...bucket.invoices.asMap().entries.map((entry) {
                  final i = entry.key;
                  final inv = entry.value;
                  final days = daysOverdueFn(inv);
                  final isLast = i == bucket.invoices.length - 1;
                  // Compute per-invoice penalty via provider for accuracy.
                  final profile =
                      context.read<AppProvider>().profile;
                  final penalty = showPenalty
                      ? LateFeeCalculator.forInvoice(inv, profile)
                      : null;
                  return _InvoiceRow(
                    invoice: inv,
                    currency: currency,
                    daysOverdue: days,
                    bucketColor: bucket.color,
                    isLast: isLast,
                    penaltyResult: penalty,
                  );
                }),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Invoice row inside bucket ─────────────────────────────────────────────────

class _InvoiceRow extends StatelessWidget {
  final Invoice invoice;
  final String currency;
  final int daysOverdue;
  final Color bucketColor;
  final bool isLast;
  final LateFeeResult? penaltyResult;

  const _InvoiceRow({
    required this.invoice,
    required this.currency,
    required this.daysOverdue,
    required this.bucketColor,
    required this.isLast,
    this.penaltyResult,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateInvoiceScreen(invoice: invoice),
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bucketColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_outlined,
                    color: bucketColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onCard(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        invoice.client?.displayName ?? 'No Client',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.subtext(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.currencyAmount(invoice.amountRemaining, currency),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: bucketColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daysOverdue == 0
                          ? 'Due ${Fmt.date(invoice.dueDate)}'
                          : '$daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue',
                      style: TextStyle(
                        fontSize: 10,
                        color: daysOverdue == 0
                            ? AppTheme.subtext(context)
                            : bucketColor,
                        fontWeight: daysOverdue > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (penaltyResult != null && penaltyResult!.hasPenalty) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${Fmt.currencyAmount(penaltyResult!.amount, currency)}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppTheme.subtext(context),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: AppTheme.outline(context),
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}

// ── All-clear state ───────────────────────────────────────────────────────────

class _AllClearState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 32,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.onCard(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No outstanding invoices.\nAll payments have been received.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.subtext(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
