import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/invoice.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/feature_guide_sheet.dart';

// ── Period enum ───────────────────────────────────────────────────────────────

enum _PLPeriod { today, week, month, year, custom }

extension _PLPeriodLabel on _PLPeriod {
  String get label {
    switch (this) {
      case _PLPeriod.today:
        return 'Today';
      case _PLPeriod.week:
        return 'This Week';
      case _PLPeriod.month:
        return 'This Month';
      case _PLPeriod.year:
        return 'This Year';
      case _PLPeriod.custom:
        return 'Custom';
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PLReportScreen extends StatefulWidget {
  const PLReportScreen({super.key});

  @override
  State<PLReportScreen> createState() => _PLReportScreenState();
}

class _PLReportScreenState extends State<PLReportScreen> {
  _PLPeriod _period = _PLPeriod.month;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.plReport);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  DateTimeRange _rangeFor(_PLPeriod p) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (p) {
      case _PLPeriod.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _PLPeriod.week:
        return DateTimeRange(
            start: todayStart.subtract(const Duration(days: 6)),
            end: todayEnd);
      case _PLPeriod.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: todayEnd);
      case _PLPeriod.year:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: todayEnd);
      case _PLPeriod.custom:
        return _customRange ??
            DateTimeRange(
                start: DateTime(now.year, now.month, 1), end: todayEnd);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = DateTimeRange(
          start: picked.start,
          end: DateTime(
              picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
        );
        _period = _PLPeriod.custom;
      });
    }
  }

  bool _inRange(DateTime date, DateTimeRange range) =>
      !date.isBefore(range.start) && !date.isAfter(range.end);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final range = _rangeFor(_period);

    // ── Revenue: paid invoices in period (filter by invoiceDate) ──────────────
    final paidInvoices = provider.invoicesOnly
        .where((inv) =>
            inv.status == InvoiceStatus.paid &&
            _inRange(inv.invoiceDate, range))
        .toList();
    final revenue =
        paidInvoices.fold(0.0, (sum, inv) => sum + inv.grandTotal);

    // ── Expenses in period (filter by expense.date) ───────────────────────────
    final periodExpenses = provider.expenses
        .where((e) => _inRange(e.date, range))
        .toList();
    final totalExpenses =
        periodExpenses.fold(0.0, (sum, e) => sum + e.amount);

    final netProfit = revenue - totalExpenses;

    // ── Top-5 clients by revenue ───────────────────────────────────────────────
    final clientRevMap = <String, double>{};
    for (final inv in paidInvoices) {
      final name = inv.client?.displayName ?? 'Unknown';
      clientRevMap[name] = (clientRevMap[name] ?? 0) + inv.grandTotal;
    }
    final sortedClients = clientRevMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Clients = sortedClients.take(5).toList();
    final maxClientRev =
        top5Clients.isEmpty ? 1.0 : top5Clients.first.value;

    // ── Expenses by category ──────────────────────────────────────────────────
    final catExpMap = <String, double>{};
    for (final e in periodExpenses) {
      catExpMap[e.category] = (catExpMap[e.category] ?? 0) + e.amount;
    }
    final sortedCats = catExpMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCatExp = sortedCats.isEmpty ? 1.0 : sortedCats.first.value;

    final hasData = paidInvoices.isNotEmpty || periodExpenses.isNotEmpty;

    // Period subtitle
    final periodSubtitle = _period == _PLPeriod.custom && _customRange != null
        ? '${Fmt.shortDate(_customRange!.start)} – ${Fmt.shortDate(_customRange!.end)}'
        : _period.label;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('P & L Report'),
            Text(
              periodSubtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtext(context),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Period chips ─────────────────────────────────────────────────
            _PeriodSelector(
              period: _period,
              customRange: _customRange,
              onSelect: (p) => setState(() => _period = p),
              onCustomTap: _pickCustomRange,
            ),
            const SizedBox(height: 20),

            if (!hasData) ...[
              _EmptyState(),
            ] else ...[
              // ── Summary cards row ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Revenue',
                      amount: revenue,
                      currency: currency,
                      color: AppTheme.success,
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Expenses',
                      amount: totalExpenses,
                      currency: currency,
                      color: AppTheme.error,
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                      amount: netProfit.abs(),
                      currency: currency,
                      color: netProfit >= 0 ? AppTheme.success : AppTheme.error,
                      icon: Icons.account_balance_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Revenue Breakdown ────────────────────────────────────────
              if (top5Clients.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Revenue Breakdown',
                  subtitle: 'Top 5 paying clients',
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: top5Clients.asMap().entries.map((entry) {
                      final i = entry.key;
                      final clientName = entry.value.key;
                      final clientRev = entry.value.value;
                      final fraction =
                          maxClientRev > 0 ? clientRev / maxClientRev : 0.0;
                      return _ClientRevenueRow(
                        rank: i + 1,
                        clientName: clientName,
                        amount: Fmt.currencyAmount(clientRev, currency),
                        fraction: fraction,
                        isLast: i == top5Clients.length - 1,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Expense Breakdown ────────────────────────────────────────
              if (sortedCats.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Expense Breakdown',
                  subtitle: 'By category',
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: sortedCats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final cat = entry.value.key;
                      final catAmt = entry.value.value;
                      final fraction =
                          maxCatExp > 0 ? catAmt / maxCatExp : 0.0;
                      final pct = totalExpenses > 0
                          ? (catAmt / totalExpenses * 100)
                          : 0.0;
                      return _ExpenseCategoryRow(
                        category: cat,
                        amount: Fmt.currencyAmount(catAmt, currency),
                        pct: pct,
                        fraction: fraction,
                        isLast: i == sortedCats.length - 1,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Period selector ───────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final _PLPeriod period;
  final DateTimeRange? customRange;
  final ValueChanged<_PLPeriod> onSelect;
  final VoidCallback onCustomTap;

  const _PeriodSelector({
    required this.period,
    required this.customRange,
    required this.onSelect,
    required this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._PLPeriod.values.where((p) => p != _PLPeriod.custom).map((p) {
            final selected = period == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.label),
                selected: selected,
                onSelected: (_) => onSelect(p),
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.onCard(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.outline(context),
                ),
                backgroundColor: AppTheme.card(context),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    period == _PLPeriod.custom && customRange != null
                        ? '${Fmt.shortDate(customRange!.start)} – ${Fmt.shortDate(customRange!.end)}'
                        : 'Custom',
                    style: TextStyle(
                      color: period == _PLPeriod.custom
                          ? AppTheme.primary
                          : AppTheme.onCard(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: period == _PLPeriod.custom
                        ? AppTheme.primary
                        : AppTheme.subtext(context),
                  ),
                ],
              ),
              onPressed: onCustomTap,
              side: BorderSide(
                color: period == _PLPeriod.custom
                    ? AppTheme.primary
                    : AppTheme.outline(context),
              ),
              backgroundColor: period == _PLPeriod.custom
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.card(context),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.subtext(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currencyAmount(amount, currency),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.onCard(context),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.subtext(context),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Client revenue row ────────────────────────────────────────────────────────

class _ClientRevenueRow extends StatelessWidget {
  final int rank;
  final String clientName;
  final String amount;
  final double fraction;
  final bool isLast;

  const _ClientRevenueRow({
    required this.rank,
    required this.clientName,
    required this.amount,
    required this.fraction,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: rank <= 3
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.bg(context),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rank <= 3
                              ? AppTheme.success
                              : AppTheme.subtext(context),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      clientName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor:
                      AppTheme.success.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.success),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: AppTheme.outline(context)),
      ],
    );
  }
}

// ── Expense category row ──────────────────────────────────────────────────────

class _ExpenseCategoryRow extends StatelessWidget {
  final String category;
  final String amount;
  final double pct;
  final double fraction;
  final bool isLast;

  const _ExpenseCategoryRow({
    required this.category,
    required this.amount,
    required this.pct,
    required this.fraction,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor:
                      AppTheme.error.withValues(alpha: 0.10),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.error),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pct.toStringAsFixed(1)}% of total expenses',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.subtext(context)),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppTheme.outline(context)),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 56,
              color: AppTheme.subtext(context).withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No data for this period',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mark invoices as paid or add\nexpenses to see your P&L report.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.subtext(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
