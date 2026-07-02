import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_sale.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Flattened view of a single [DailySaleExpense] with its parent sale date.
class _ExpenseEntry {
  final DailySale sale;
  final DailySaleExpense expense;

  const _ExpenseEntry({required this.sale, required this.expense});

  DateTime get date => sale.date;
  String get label => expense.label;
  double get amount => expense.amount;
  String? get receiptBase64 => expense.receiptBase64;
  String? get saleTitle => sale.title;
}

enum _Period { today, week, month, year, all }

String _periodLabel(_Period p) {
  switch (p) {
    case _Period.today:
      return 'Today';
    case _Period.week:
      return 'This Week';
    case _Period.month:
      return 'This Month';
    case _Period.year:
      return 'This Year';
    case _Period.all:
      return 'All Time';
  }
}

class DailySalesExpenseScreen extends StatefulWidget {
  const DailySalesExpenseScreen({super.key});

  @override
  State<DailySalesExpenseScreen> createState() =>
      _DailySalesExpenseScreenState();
}

class _DailySalesExpenseScreenState extends State<DailySalesExpenseScreen> {
  _Period _period = _Period.month;
  DateTimeRange? _customRange;
  String _labelFilter = 'All';

  DateTimeRange _rangeFor(_Period p) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (p) {
      case _Period.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _Period.week:
        return DateTimeRange(
            start: todayStart.subtract(const Duration(days: 6)),
            end: todayEnd);
      case _Period.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: todayEnd);
      case _Period.year:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: todayEnd);
      case _Period.all:
        return _customRange ??
            DateTimeRange(start: DateTime(2020), end: todayEnd);
    }
  }

  List<_ExpenseEntry> _flatten(List<DailySale> sales) {
    final range = _rangeFor(_period);
    final entries = <_ExpenseEntry>[];
    for (final sale in sales) {
      if (sale.date.isBefore(range.start) || sale.date.isAfter(range.end)) {
        continue;
      }
      for (final exp in sale.expenses) {
        entries.add(_ExpenseEntry(sale: sale, expense: exp));
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
              start: DateTime(now.year, now.month, 1), end: now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month,
              picked.end.day, 23, 59, 59, 999),
        );
        _period = _Period.all;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final symbol = Fmt.currencySymbol(currency);
    final allEntries = _flatten(provider.dailySales);

    // Label breakdown for the current period.
    final labelTotals = <String, double>{};
    for (final e in allEntries) {
      labelTotals[e.label] = (labelTotals[e.label] ?? 0) + e.amount;
    }
    final sortedLabels = labelTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final availableLabels = ['All', ...sortedLabels.map((e) => e.key)];

    final filtered = _labelFilter == 'All'
        ? allEntries
        : allEntries.where((e) => e.label == _labelFilter).toList();

    final total = filtered.fold(0.0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text('Daily Expenses'),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Summary banner ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SummaryBanner(
                total: total,
                symbol: symbol,
                currency: currency,
                sortedLabels: sortedLabels,
                period: _period,
                customRange: _customRange,
              ),
            ),
          ),

          // ── Period selector ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _PeriodSelector(
                selected: _period,
                customRange: _customRange,
                onPeriodChanged: (p) =>
                    setState(() => _period = p),
                onCustomTap: () => _pickCustomRange(context),
              ),
            ),
          ),

          // ── Label filter chips ─────────────────────────────────────
          if (sortedLabels.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 10, 0, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableLabels.map((lbl) {
                      final isSelected = lbl == _labelFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(lbl),
                          selected: isSelected,
                          onSelected: (_) => setState(
                              () => _labelFilter = lbl),
                          selectedColor: AppTheme.error
                              .withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.error,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.error
                                : AppTheme.subtext(context),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.error
                                : AppTheme.outline(context),
                          ),
                          backgroundColor: AppTheme.card(context),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // ── List ────────────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                            Icons.receipt_long_outlined,
                            size: 34,
                            color: AppTheme.error),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No daily expenses',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onCard(context)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Expenses you enter in daily sales entries will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.subtext(context)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ExpenseTile(
                    entry: filtered[i],
                    symbol: symbol,
                    currency: currency,
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
            const SliverPadding(
                padding: EdgeInsets.only(bottom: 80)),
          ],
        ],
      ),
    );
  }
}

// ── Summary banner ─────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final double total;
  final String symbol;
  final String currency;
  final List<MapEntry<String, double>> sortedLabels;
  final _Period period;
  final DateTimeRange? customRange;

  const _SummaryBanner({
    required this.total,
    required this.symbol,
    required this.currency,
    required this.sortedLabels,
    required this.period,
    required this.customRange,
  });

  String _title() {
    if (period == _Period.all && customRange != null) {
      return 'Daily Expenses · ${Fmt.shortDate(customRange!.start)} – ${Fmt.shortDate(customRange!.end)}';
    }
    return 'Daily Expenses · ${_periodLabel(period)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title(),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                key: ValueKey(total),
                tween: Tween(begin: 0, end: total),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  Fmt.currencyAmount(v, currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              if (sortedLabels.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: sortedLabels.take(4).map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${e.key}: $symbol${Fmt.compact(e.value)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Period selector ────────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final _Period selected;
  final DateTimeRange? customRange;
  final ValueChanged<_Period> onPeriodChanged;
  final VoidCallback onCustomTap;

  const _PeriodSelector({
    required this.selected,
    required this.customRange,
    required this.onPeriodChanged,
    required this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._Period.values
              .where((p) => p != _Period.all)
              .map((p) {
            final isSelected = selected == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_periodLabel(p)),
                selected: isSelected,
                onSelected: (_) => onPeriodChanged(p),
                selectedColor: const Color(0xFFDC2626),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppTheme.onCard(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFDC2626)
                      : AppTheme.outline(context),
                ),
                backgroundColor: AppTheme.card(context),
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
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
                    selected == _Period.all && customRange != null
                        ? '${Fmt.shortDate(customRange!.start)} – ${Fmt.shortDate(customRange!.end)}'
                        : 'Custom',
                    style: TextStyle(
                        color: AppTheme.onCard(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_month_outlined,
                      size: 14,
                      color: AppTheme.subtext(context)),
                ],
              ),
              onPressed: onCustomTap,
              side: BorderSide(color: AppTheme.outline(context)),
              backgroundColor: AppTheme.card(context),
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expense tile ───────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  final _ExpenseEntry entry;
  final String symbol;
  final String currency;

  const _ExpenseTile({
    required this.entry,
    required this.symbol,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: entry.receiptBase64 != null
            ? () => _viewReceipt(context)
            : null,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: AppTheme.error, size: 22),
              ),
              const SizedBox(width: 14),
              // Label + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.onCard(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.saleTitle != null
                          ? '${entry.saleTitle!} · ${Fmt.date(entry.date)}'
                          : Fmt.date(entry.date),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtext(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Amount + receipt indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$symbol${Fmt.compact(entry.amount)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.error),
                  ),
                  if (entry.receiptBase64 != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 12,
                            color: AppTheme.primary),
                        const SizedBox(width: 3),
                        Text('Receipt',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewReceipt(BuildContext context) {
    if (entry.receiptBase64 == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(entry.receiptBase64!),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
