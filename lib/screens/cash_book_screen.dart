import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment_method.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'cash_denomination_screen.dart';

// ── Source types ──────────────────────────────────────────────────────────────

enum _Source {
  dailySaleReceipt,
  dailySaleExpense,
  invoicePayment,
  businessExpense,
  purchaseBill,
}

extension _SourceX on _Source {
  String get label {
    switch (this) {
      case _Source.dailySaleReceipt:  return 'Shop Sales';
      case _Source.dailySaleExpense:  return 'Daily Expense';
      case _Source.invoicePayment:    return 'Invoice Receipt';
      case _Source.businessExpense:   return 'Business Expense';
      case _Source.purchaseBill:      return 'Purchase Bill';
    }
  }

  IconData get icon {
    switch (this) {
      case _Source.dailySaleReceipt:  return Icons.storefront_outlined;
      case _Source.dailySaleExpense:  return Icons.receipt_long_outlined;
      case _Source.invoicePayment:    return Icons.receipt_outlined;
      case _Source.businessExpense:   return Icons.money_off_outlined;
      case _Source.purchaseBill:      return Icons.local_shipping_outlined;
    }
  }

  Color get color {
    switch (this) {
      case _Source.dailySaleReceipt:  return AppTheme.primary;
      case _Source.dailySaleExpense:  return AppTheme.error;
      case _Source.invoicePayment:    return AppTheme.success;
      case _Source.businessExpense:   return AppTheme.error;
      case _Source.purchaseBill:      return const Color(0xFFB45309);
    }
  }

  bool get isCredit {
    switch (this) {
      case _Source.dailySaleReceipt:  return true;
      case _Source.dailySaleExpense:  return false;
      case _Source.invoicePayment:    return true;
      case _Source.businessExpense:   return false;
      case _Source.purchaseBill:      return false;
    }
  }
}

// ── Entry model ───────────────────────────────────────────────────────────────

class _CashEntry {
  final DateTime date;
  final String narration;
  final _Source source;
  final double amount;
  double runningBalance = 0;

  _CashEntry({
    required this.date,
    required this.narration,
    required this.source,
    required this.amount,
  });

  bool get isCredit => source.isCredit;
}

// ── Period ────────────────────────────────────────────────────────────────────

enum _Period { today, week, month, year, custom }

String _periodLabel(_Period p) {
  switch (p) {
    case _Period.today:  return 'Today';
    case _Period.week:   return 'This Week';
    case _Period.month:  return 'This Month';
    case _Period.year:   return 'This Year';
    case _Period.custom: return 'Custom';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CashBookScreen extends StatefulWidget {
  const CashBookScreen({super.key});

  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  _Period _period = _Period.month;
  DateTimeRange? _customRange;
  // Empty set = all sources shown.
  final Set<_Source> _sourceFilter = {};

  DateTimeRange _rangeFor(_Period p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    switch (p) {
      case _Period.today:
        return DateTimeRange(start: today, end: tomorrow);
      case _Period.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: monday, end: tomorrow);
      case _Period.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: tomorrow);
      case _Period.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: tomorrow);
      case _Period.custom:
        return _customRange ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: tomorrow);
    }
  }

  List<_CashEntry> _buildEntries(AppProvider provider) {
    final range = _rangeFor(_period);
    final rangeStart = range.start;
    final rangeEnd = range.end;

    bool inRange(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(rangeStart) && day.isBefore(rangeEnd);
    }

    bool showSource(_Source s) =>
        _sourceFilter.isEmpty || _sourceFilter.contains(s);

    final entries = <_CashEntry>[];
    final allMethods = provider.profile.allPaymentMethods;

    PaymentMethod? findMethod(String id) =>
        allMethods.cast<PaymentMethod?>().firstWhere(
          (m) => m?.id == id,
          orElse: () => null,
        );

    // ── 1. Daily sale receipts + daily expenses ──────────────────────
    for (final sale in provider.dailySales) {
      final day = DateTime(sale.date.year, sale.date.month, sale.date.day);
      if (!inRange(day)) continue;

      final saleTitle =
          sale.title?.trim().isNotEmpty == true ? sale.title! : Fmt.date(sale.date);

      if (showSource(_Source.dailySaleReceipt)) {
        for (final e in sale.paymentBreakdown.entries) {
          if (e.value <= 0) continue;
          final method = findMethod(e.key);
          final methodName = method?.name ?? e.key;
          entries.add(_CashEntry(
            date: day,
            narration: 'Shop Sales – $saleTitle ($methodName)',
            source: _Source.dailySaleReceipt,
            amount: e.value,
          ));
        }
      }

      if (showSource(_Source.dailySaleExpense)) {
        for (final exp in sale.expenses) {
          if (exp.amount <= 0) continue;
          entries.add(_CashEntry(
            date: day,
            narration: 'Daily Expense – ${exp.label}',
            source: _Source.dailySaleExpense,
            amount: exp.amount,
          ));
        }
      }
    }

    // ── 2. Invoice partial payments ──────────────────────────────────
    if (showSource(_Source.invoicePayment)) {
      for (final inv in provider.invoices) {
        if (inv.isQuotation || inv.isCreditNote) continue;
        for (final p in inv.payments) {
          if (p.amount <= 0) continue;
          final day = DateTime(p.date.year, p.date.month, p.date.day);
          if (!inRange(day)) continue;
          final clientName = inv.client?.displayName ?? '';
          final methodPart = p.paymentMethodName?.isNotEmpty == true
              ? ' (${p.paymentMethodName})'
              : '';
          entries.add(_CashEntry(
            date: day,
            narration:
                'Invoice #${inv.invoiceNumber}${clientName.isNotEmpty ? ' · $clientName' : ''}$methodPart',
            source: _Source.invoicePayment,
            amount: p.amount,
          ));
        }
      }
    }

    // ── 3. Business expenses ─────────────────────────────────────────
    if (showSource(_Source.businessExpense)) {
      for (final exp in provider.expenses) {
        if (exp.amount <= 0) continue;
        final day = DateTime(exp.date.year, exp.date.month, exp.date.day);
        if (!inRange(day)) continue;
        entries.add(_CashEntry(
          date: day,
          narration: '${exp.title} [${exp.category}]',
          source: _Source.businessExpense,
          amount: exp.amount,
        ));
      }
    }

    // ── 4. Purchase bills (amount already paid) ──────────────────────
    if (showSource(_Source.purchaseBill)) {
      for (final bill in provider.purchaseBills) {
        if (bill.amountPaid <= 0) continue;
        final day = DateTime(
            bill.billDate.year, bill.billDate.month, bill.billDate.day);
        if (!inRange(day)) continue;
        final ref = bill.billNumber?.isNotEmpty == true
            ? ' #${bill.billNumber}'
            : '';
        entries.add(_CashEntry(
          date: day,
          narration: 'Purchase · ${bill.vendorName}$ref',
          source: _Source.purchaseBill,
          amount: bill.amountPaid,
        ));
      }
    }

    // Sort chronologically; within a day credits come before debits.
    entries.sort((a, b) {
      final d = a.date.compareTo(b.date);
      if (d != 0) return d;
      if (a.isCredit && !b.isCredit) return -1;
      if (!a.isCredit && b.isCredit) return 1;
      return 0;
    });

    // Running balance
    double balance = 0;
    for (final e in entries) {
      balance += e.isCredit ? e.amount : -e.amount;
      e.runningBalance = balance;
    }

    return entries;
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _period = _Period.custom;
        _customRange = range;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final entries = _buildEntries(provider);

    double totalIn = 0, totalOut = 0;
    for (final e in entries) {
      if (e.isCredit) { totalIn += e.amount; }
      else { totalOut += e.amount; }
    }
    final net = totalIn - totalOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Cash Counter',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CashDenominationScreen(expectedAmount: net),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period selector ─────────────────────────────────────────
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: _Period.values.map((p) {
                final sel = _period == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      p == _Period.custom && _customRange != null
                          ? '${Fmt.date(_customRange!.start)} – ${Fmt.date(_customRange!.end)}'
                          : _periodLabel(p),
                    ),
                    selected: sel,
                    onSelected: (_) {
                      if (p == _Period.custom) {
                        _pickCustomRange();
                      } else {
                        setState(() => _period = p);
                      }
                    },
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : AppTheme.onCard(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Source filter chips ─────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _Source.values.map((s) {
                final active = _sourceFilter.contains(s);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(s.icon, size: 13,
                        color: active ? s.color : AppTheme.subtext(context)),
                    label: Text(s.label),
                    selected: active,
                    onSelected: (v) => setState(() {
                      v ? _sourceFilter.add(s) : _sourceFilter.remove(s);
                    }),
                    selectedColor: s.color.withValues(alpha: 0.12),
                    checkmarkColor: s.color,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: active ? s.color : AppTheme.subtext(context),
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    side: BorderSide(
                      color: active
                          ? s.color.withValues(alpha: 0.4)
                          : AppTheme.outline(context),
                      width: 0.8,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Summary banner ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outline(context), width: 0.8),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _BannerStat(
                    label: 'Total In',
                    value: Fmt.currencyAmount(totalIn, currency),
                    color: AppTheme.success,
                    icon: Icons.arrow_downward_rounded,
                  ),
                  VerticalDivider(
                      width: 1, color: AppTheme.outline(context)),
                  _BannerStat(
                    label: 'Total Out',
                    value: Fmt.currencyAmount(totalOut, currency),
                    color: AppTheme.error,
                    icon: Icons.arrow_upward_rounded,
                  ),
                  VerticalDivider(
                      width: 1, color: AppTheme.outline(context)),
                  _BannerStat(
                    label: net >= 0 ? 'Net Surplus' : 'Net Deficit',
                    value: Fmt.currencyAmount(net.abs(), currency),
                    color: net >= 0
                        ? const Color(0xFF0D9488)
                        : AppTheme.error,
                    icon: net >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Column headers ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _ColHeader('NARRATION'),
                ),
                Expanded(
                  flex: 2,
                  child: _ColHeader('IN', align: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: _ColHeader('OUT', align: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: _ColHeader('BALANCE', align: TextAlign.right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppTheme.divider),

          // ── Entries ─────────────────────────────────────────────────
          Expanded(
            child: entries.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final showDate = i == 0 ||
                          !_sameDay(entries[i].date, entries[i - 1].date);
                      return _EntryRow(
                        entry: entries[i],
                        currency: currency,
                        showDateHeader: showDate,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Entry row ─────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final _CashEntry entry;
  final String currency;
  final bool showDateHeader;

  const _EntryRow({
    required this.entry,
    required this.currency,
    required this.showDateHeader,
  });

  @override
  Widget build(BuildContext context) {
    final balNeg = entry.runningBalance < 0;
    final balColor = balNeg ? AppTheme.error : const Color(0xFF0D9488);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDateHeader)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Fmt.date(entry.date),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    indent: 8,
                    color: AppTheme.divider,
                  ),
                ),
              ],
            ),
          ),

        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: entry.source.color, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Narration + badge
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.narration,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onCard(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(entry.source.icon,
                              size: 10, color: entry.source.color),
                          const SizedBox(width: 3),
                          Text(
                            entry.source.label,
                            style: TextStyle(
                              fontSize: 9,
                              color: entry.source.color,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Credit (IN)
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.isCredit
                        ? Fmt.currencyAmount(entry.amount, currency)
                        : '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ),
                // Debit (OUT)
                Expanded(
                  flex: 2,
                  child: Text(
                    !entry.isCredit
                        ? Fmt.currencyAmount(entry.amount, currency)
                        : '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                  ),
                ),
                // Running balance
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.currencyAmount(
                            entry.runningBalance.abs(), currency),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: balColor,
                        ),
                      ),
                      if (balNeg)
                        Text('(Dr)',
                            style: TextStyle(
                                fontSize: 9, color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _BannerStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 11, color: color),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.subtext(context))),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
}

class _ColHeader extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _ColHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppTheme.subtext(context),
          letterSpacing: 0.5,
        ),
      );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: AppTheme.subtext(context)),
            const SizedBox(height: 16),
            Text(
              'No transactions in this period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.onCard(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Record daily sales, invoices, or expenses\nto see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.subtext(context)),
            ),
          ],
        ),
      );
}
