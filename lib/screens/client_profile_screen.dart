import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/status_badge.dart';
import 'create_client_screen.dart';
import 'create_invoice_screen.dart';
import 'ledger_screen.dart';

// ── Payment behaviour score ───────────────────────────────────────────────────

class PaymentScore {
  final double avgDaysToPay;    // average days between invoice date and payment date
  final double onTimePercent;   // % of invoices paid on or before due date
  final double totalBilled;
  final double totalCollected;
  final double outstanding;
  final int invoiceCount;
  final int paidCount;
  final int overdueCount;

  const PaymentScore({
    required this.avgDaysToPay,
    required this.onTimePercent,
    required this.totalBilled,
    required this.totalCollected,
    required this.outstanding,
    required this.invoiceCount,
    required this.paidCount,
    required this.overdueCount,
  });

  /// Overall grade based on on-time % and avg days.
  String get grade {
    if (invoiceCount == 0) return 'New';
    if (paidCount == 0 && invoiceCount > 0) return 'No Payments';
    if (onTimePercent >= 90 && avgDaysToPay <= 5) return 'Excellent';
    if (onTimePercent >= 75 && avgDaysToPay <= 15) return 'Good';
    if (onTimePercent >= 50 && avgDaysToPay <= 30) return 'Fair';
    return 'Poor';
  }

  Color gradeColor(BuildContext context) {
    switch (grade) {
      case 'Excellent': return const Color(0xFF059669);
      case 'Good':      return const Color(0xFF2563EB);
      case 'Fair':      return const Color(0xFFF59E0B);
      case 'Poor':      return const Color(0xFFDC2626);
      default:          return AppTheme.subtext(context);
    }
  }

  IconData get gradeIcon {
    switch (grade) {
      case 'Excellent': return Icons.verified_rounded;
      case 'Good':      return Icons.thumb_up_outlined;
      case 'Fair':      return Icons.thumbs_up_down_outlined;
      case 'Poor':      return Icons.warning_amber_rounded;
      default:          return Icons.fiber_new_outlined;
    }
  }

  static PaymentScore compute(String clientId, List<Invoice> allInvoices) {
    final invs = allInvoices.where((i) =>
        i.client?.id == clientId &&
        !i.isQuotation &&
        !i.isCreditNote &&
        !i.isDeliveryChallan &&
        i.status != InvoiceStatus.cancelled).toList();

    if (invs.isEmpty) {
      return const PaymentScore(
        avgDaysToPay: 0, onTimePercent: 0,
        totalBilled: 0, totalCollected: 0, outstanding: 0,
        invoiceCount: 0, paidCount: 0, overdueCount: 0,
      );
    }

    final paid = invs.where((i) =>
        i.status == InvoiceStatus.paid ||
        i.status == InvoiceStatus.partiallyPaid).toList();

    // Days to pay: last payment date vs invoice date, for fully/partially paid
    final daysList = <double>[];
    int onTime = 0;
    for (final inv in paid) {
      if (inv.payments.isEmpty) continue;
      final lastPayment = inv.payments
          .map((p) => p.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final days = lastPayment.difference(inv.invoiceDate).inDays.toDouble();
      daysList.add(days.clamp(0, 365));
      if (!lastPayment.isAfter(inv.dueDate)) onTime++;
    }

    final avg = daysList.isEmpty
        ? 0.0
        : daysList.reduce((a, b) => a + b) / daysList.length;

    final onTimePct = paid.isEmpty ? 0.0 : (onTime / paid.length) * 100;

    final billed = invs.fold(0.0, (s, i) => s + i.grandTotal);
    final collected = invs.fold(0.0, (s, i) => s + i.cashReceived);
    final outstanding = invs.fold(0.0, (s, i) => s + i.amountRemaining);
    final overdueCount = invs.where((i) => i.isOverdue).length;

    return PaymentScore(
      avgDaysToPay: avg,
      onTimePercent: onTimePct,
      totalBilled: billed,
      totalCollected: collected,
      outstanding: outstanding,
      invoiceCount: invs.length,
      paidCount: paid.length,
      overdueCount: overdueCount,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ClientProfileScreen extends StatelessWidget {
  final Client client;
  const ClientProfileScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final sym = Fmt.currencySymbol(currency);

    final clientInvoices = provider.invoices
        .where((i) =>
            i.client?.id == client.id &&
            !i.isQuotation &&
            !i.isCreditNote &&
            !i.isDeliveryChallan)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final score = PaymentScore.compute(client.id, provider.invoices);
    final gradeColor = score.gradeColor(context);
    final outstanding = provider.clientOutstanding(client.id);
    final creditLimit = provider.effectiveCreditLimit(client);
    final isDefaultLimit = creditLimit != null && client.creditLimit == null;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
        slivers: [
          // ── Collapsing header ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Client',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateClientScreen(client: client),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          client.displayName[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(client.displayName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      if (client.companyName != null &&
                          client.companyName!.isNotEmpty &&
                          client.companyName != client.name)
                        Text(client.companyName!,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Quick action buttons ─────────────────────────────────
                Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.add_circle_outline,
                      label: 'New Invoice',
                      color: AppTheme.primary,
                      onTap: () {
                        final inv = context.read<AppProvider>().buildNewInvoice();
                        inv.client = client;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateInvoiceScreen(invoice: inv),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _ActionBtn(
                      icon: Icons.description_outlined,
                      label: 'Statement',
                      color: const Color(0xFF7C3AED),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientLedgerScreen(client: client),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (client.phone.isNotEmpty)
                      _ActionBtn(
                        icon: Icons.call_outlined,
                        label: 'Call',
                        color: const Color(0xFF059669),
                        onTap: () {/* phone dial handled by OS */},
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Payment behaviour score ─────────────────────────────
                _ScoreCard(score: score, sym: sym, gradeColor: gradeColor),
                const SizedBox(height: 16),

                // ── Credit limit ────────────────────────────────────────
                if (creditLimit != null) ...[
                  _CreditLimitCard(
                    outstanding: outstanding,
                    creditLimit: creditLimit,
                    isDefault: isDefaultLimit,
                    sym: sym,
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateClientScreen(client: client),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Contact details ─────────────────────────────────────
                _SectionCard(title: 'Contact Details', children: [
                  if (client.email.isNotEmpty)
                    _InfoRow(Icons.email_outlined, 'Email', client.email),
                  if (client.phone.isNotEmpty)
                    _InfoRow(Icons.phone_outlined, 'Phone', client.phone),
                  if (client.gstin != null && client.gstin!.isNotEmpty)
                    _InfoRow(Icons.badge_outlined, 'GSTIN', client.gstin!),
                  if (client.address.isNotEmpty)
                    _InfoRow(
                        Icons.location_on_outlined,
                        'Address',
                        [
                          client.address,
                          if (client.city.isNotEmpty) client.city,
                          if (client.state.isNotEmpty) client.state,
                          if (client.postalCode.isNotEmpty) client.postalCode,
                          if (client.country.isNotEmpty) client.country,
                        ].join(', ')),
                ]),
                const SizedBox(height: 16),

                // ── Invoice history ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Invoice History (${clientInvoices.length})',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onCard(context))),
                    if (score.outstanding > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$sym${Fmt.compact(score.outstanding)} outstanding',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (clientInvoices.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outline(context)),
                    ),
                    child: Center(
                      child: Text('No invoices yet',
                          style: TextStyle(color: AppTheme.subtext(context))),
                    ),
                  )
                else
                  ...clientInvoices.map((inv) => _InvoiceTile(
                        invoice: inv,
                        sym: sym,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreateInvoiceScreen(invoice: inv),
                          ),
                        ),
                      )),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score card ────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final PaymentScore score;
  final String sym;
  final Color gradeColor;

  const _ScoreCard({
    required this.score,
    required this.sym,
    required this.gradeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline(context)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Payment Behaviour',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: gradeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(score.gradeIcon, size: 13, color: gradeColor),
                    const SizedBox(width: 4),
                    Text(score.grade,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: gradeColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _ScoreStat(
                label: 'Total Billed',
                value: '$sym${Fmt.compact(score.totalBilled)}',
                color: AppTheme.onCard(context),
              )),
              Expanded(
                  child: _ScoreStat(
                label: 'Collected',
                value: '$sym${Fmt.compact(score.totalCollected)}',
                color: const Color(0xFF059669),
              )),
              Expanded(
                  child: _ScoreStat(
                label: 'Outstanding',
                value: '$sym${Fmt.compact(score.outstanding)}',
                color: score.outstanding > 0
                    ? AppTheme.error
                    : const Color(0xFF059669),
              )),
            ],
          ),
          if (score.paidCount > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _ScoreStat(
                  label: 'Avg Days to Pay',
                  value: '${score.avgDaysToPay.toStringAsFixed(0)} days',
                  color: score.avgDaysToPay <= 15
                      ? const Color(0xFF059669)
                      : score.avgDaysToPay <= 30
                          ? const Color(0xFFF59E0B)
                          : AppTheme.error,
                )),
                Expanded(
                    child: _ScoreStat(
                  label: 'On-Time Rate',
                  value: '${score.onTimePercent.toStringAsFixed(0)}%',
                  color: score.onTimePercent >= 75
                      ? const Color(0xFF059669)
                      : score.onTimePercent >= 50
                          ? const Color(0xFFF59E0B)
                          : AppTheme.error,
                )),
                Expanded(
                    child: _ScoreStat(
                  label: 'Overdue Now',
                  value: '${score.overdueCount}',
                  color: score.overdueCount > 0
                      ? AppTheme.error
                      : const Color(0xFF059669),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ScoreStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: AppTheme.subtext(context))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.subtext(context),
                  letterSpacing: 0.4)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppTheme.subtext(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.subtext(context))),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.onCard(context))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      );
}

// ── Credit limit card ─────────────────────────────────────────────────────────

class _CreditLimitCard extends StatelessWidget {
  final double outstanding;
  final double creditLimit;
  final bool isDefault;
  final String sym;
  final VoidCallback onEdit;

  const _CreditLimitCard({
    required this.outstanding,
    required this.creditLimit,
    required this.isDefault,
    required this.sym,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = creditLimit > 0
        ? (outstanding / creditLimit).clamp(0.0, 1.0)
        : 0.0;
    final used = outstanding;
    final available = (creditLimit - outstanding).clamp(0.0, double.infinity);
    final isOver = outstanding > creditLimit;
    final isNear = !isOver && ratio >= 0.8;

    final Color barColor = isOver
        ? AppTheme.error
        : isNear
            ? const Color(0xFFF59E0B)
            : const Color(0xFF059669);

    final String statusLabel = isOver
        ? 'Over Limit'
        : isNear
            ? 'Near Limit'
            : 'Within Limit';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOver
              ? AppTheme.error.withValues(alpha: 0.4)
              : AppTheme.outline(context),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 15, color: AppTheme.subtext(context)),
              const SizedBox(width: 6),
              Text('Credit Limit',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context))),
              if (isDefault) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.subtext(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('default',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.subtext(context))),
                ),
              ],
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: barColor.withValues(alpha: 0.35)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: barColor)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: Icon(Icons.edit_outlined,
                    size: 15, color: AppTheme.subtext(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppTheme.outline(context),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CreditStat(
                  label: 'Used',
                  value: '$sym${Fmt.compact(used)}',
                  color: isOver ? AppTheme.error : AppTheme.onCard(context),
                ),
              ),
              Expanded(
                child: _CreditStat(
                  label: 'Limit',
                  value: '$sym${Fmt.compact(creditLimit)}',
                  color: AppTheme.onCard(context),
                ),
              ),
              Expanded(
                child: _CreditStat(
                  label: isOver ? 'Exceeded by' : 'Available',
                  value: isOver
                      ? '$sym${Fmt.compact(outstanding - creditLimit)}'
                      : '$sym${Fmt.compact(available)}',
                  color: isOver
                      ? AppTheme.error
                      : const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CreditStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: AppTheme.subtext(context))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      );
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final String sym;
  final VoidCallback onTap;
  const _InvoiceTile(
      {required this.invoice, required this.sym, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: invoice.isOverdue
                  ? AppTheme.error.withValues(alpha: 0.35)
                  : AppTheme.outline(context),
            ),
          ),
          child: Row(
            children: [
              StatusBadge(status: invoice.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${invoice.invoiceNumber}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context))),
                    Text(Fmt.shortDate(invoice.invoiceDate),
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.subtext(context))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$sym${Fmt.compact(invoice.grandTotal)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onCard(context))),
                  if (invoice.amountRemaining > 0 &&
                      invoice.status != InvoiceStatus.paid)
                    Text(
                      '$sym${Fmt.compact(invoice.amountRemaining)} due',
                      style: TextStyle(
                          fontSize: 10,
                          color: invoice.isOverdue
                              ? AppTheme.error
                              : AppTheme.subtext(context),
                          fontWeight: invoice.isOverdue
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}
