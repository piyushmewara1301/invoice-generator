import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_sale.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/feature_guide_sheet.dart';

class CategoryAnalyticsScreen extends StatefulWidget {
  const CategoryAnalyticsScreen({super.key});

  @override
  State<CategoryAnalyticsScreen> createState() =>
      _CategoryAnalyticsScreenState();
}

class _CategoryAnalyticsScreenState extends State<CategoryAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.categoryAnalytics);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final invoices = provider.invoices;
    final dailySales = provider.dailySales;
    final currency = provider.profile.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Analytics'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Revenue'),
            Tab(text: 'Top Items'),
            Tab(text: 'Top Services'),
            Tab(text: 'Top Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CategoryRevenueTab(invoices: invoices, currency: currency),
          _TopItemsTab(invoices: invoices, currency: currency),
          _TopServicesTab(invoices: invoices, currency: currency),
          _TopProductsTab(
              invoices: invoices, dailySales: dailySales, currency: currency),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kUncategorized = 'Uncategorized';

/// All line items across all invoices (optionally paid-only).
List<LineItem> _allItems(List<Invoice> invoices, {bool paidOnly = false}) {
  return invoices
      .where((inv) => !paidOnly || inv.status == InvoiceStatus.paid)
      .expand((inv) => inv.items)
      .toList();
}

/// Category → revenue (sum of item.total for paid invoices).
Map<String, double> _categoryRevenue(List<Invoice> invoices) {
  final map = <String, double>{};
  for (final inv in invoices) {
    if (inv.status != InvoiceStatus.paid) continue;
    for (final item in inv.items) {
      final cat = (item.category?.trim().isNotEmpty == true)
          ? item.category!.trim()
          : _kUncategorized;
      map[cat] = (map[cat] ?? 0) + item.total;
    }
  }
  return map;
}

/// Description → usage count across all invoices.
Map<String, int> _itemUsage(List<Invoice> invoices) {
  final map = <String, int>{};
  for (final item in _allItems(invoices)) {
    final key = item.description.trim();
    if (key.isEmpty) continue;
    map[key] = (map[key] ?? 0) + 1;
  }
  return map;
}

/// Description → total revenue (paid invoices).
Map<String, double> _itemRevenue(List<Invoice> invoices) {
  final map = <String, double>{};
  for (final item in _allItems(invoices, paidOnly: true)) {
    final key = item.description.trim();
    if (key.isEmpty) continue;
    map[key] = (map[key] ?? 0) + item.total;
  }
  return map;
}

// Palette for category bars
const _palette = [
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFD97706),
  Color(0xFFDC2626),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
  Color(0xFF65A30D),
];

Color _colorFor(int index) => _palette[index % _palette.length];

// ── Tab 1: Revenue by category ─────────────────────────────────────────────

class _CategoryRevenueTab extends StatelessWidget {
  final List<Invoice> invoices;
  final String currency;
  const _CategoryRevenueTab(
      {required this.invoices, required this.currency});

  @override
  Widget build(BuildContext context) {
    final data = _categoryRevenue(invoices);
    if (data.isEmpty) {
      return _EmptyState(
        icon: Icons.label_outline,
        message: 'No paid invoices yet.\nCategories will appear here once '
            'you mark invoices as paid.',
      );
    }

    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;
    final total = sorted.fold(0.0, (s, e) => s + e.value);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel(
            label: 'Revenue by Category',
            subtitle: 'From paid invoices · ${Fmt.currencyAmount(total, currency)} total'),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value.key;
          final rev = entry.value.value;
          final pct = maxVal > 0 ? rev / maxVal : 0.0;
          final share = total > 0 ? (rev / total * 100) : 0.0;
          return _CategoryBar(
            label: cat,
            value: Fmt.currencyAmount(rev, currency),
            subtitle: '${share.toStringAsFixed(1)}% of total',
            fraction: pct,
            color: cat == _kUncategorized
                ? AppTheme.textSecondary.withValues(alpha: 0.4)
                : _colorFor(i),
          );
        }),
        const SizedBox(height: 24),
        _SectionLabel(label: 'Category Breakdown'),
        const SizedBox(height: 12),
        _PieChartLegend(entries: sorted, total: total),
      ],
    );
  }
}

// ── Tab 2: Top items by usage count ──────────────────────────────────────────

class _TopItemsTab extends StatelessWidget {
  final List<Invoice> invoices;
  final String currency;
  const _TopItemsTab({required this.invoices, required this.currency});

  @override
  Widget build(BuildContext context) {
    final usage = _itemUsage(invoices);
    if (usage.isEmpty) {
      return _EmptyState(
        icon: Icons.bar_chart_outlined,
        message: 'No invoice items yet.\nCreate some invoices to see '
            'which items are used most.',
      );
    }

    final sorted = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20).toList();
    final maxCount = top.first.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel(
          label: 'Most Used Items',
          subtitle: 'Across all invoices · by number of times added',
        ),
        const SizedBox(height: 12),
        ...top.asMap().entries.map((entry) {
          final i = entry.key;
          final name = entry.value.key;
          final count = entry.value.value;
          final pct = maxCount > 0 ? count / maxCount : 0.0;
          return _CategoryBar(
            label: name,
            value: '$count time${count == 1 ? '' : 's'}',
            subtitle: 'used on invoices',
            fraction: pct,
            color: _colorFor(i),
            rank: i + 1,
          );
        }),
      ],
    );
  }
}

// ── Tab 3: Top services by revenue ────────────────────────────────────────────

class _TopServicesTab extends StatelessWidget {
  final List<Invoice> invoices;
  final String currency;
  const _TopServicesTab({required this.invoices, required this.currency});

  @override
  Widget build(BuildContext context) {
    final revenue = _itemRevenue(invoices);
    if (revenue.isEmpty) {
      return _EmptyState(
        icon: Icons.trending_up_outlined,
        message: 'No paid invoices yet.\nService revenue will appear here '
            'once you mark invoices as paid.',
      );
    }

    final sorted = revenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20).toList();
    final maxVal = top.first.value;
    final total = top.fold(0.0, (s, e) => s + e.value);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel(
          label: 'Top Services by Revenue',
          subtitle:
              'From paid invoices · ${Fmt.currencyAmount(total, currency)} total',
        ),
        const SizedBox(height: 12),
        ...top.asMap().entries.map((entry) {
          final i = entry.key;
          final name = entry.value.key;
          final rev = entry.value.value;
          final pct = maxVal > 0 ? rev / maxVal : 0.0;
          final share = total > 0 ? (rev / total * 100) : 0.0;
          return _CategoryBar(
            label: name,
            value: Fmt.currencyAmount(rev, currency),
            subtitle: '${share.toStringAsFixed(1)}% of service revenue',
            fraction: pct,
            color: _colorFor(i),
            rank: i + 1,
          );
        }),
      ],
    );
  }
}

// ── Tab 4: Top products by revenue / units sold (period filterable) ──────────

enum _ProdPeriod { allTime, today, week, month, year, custom }

enum _ProdSort { revenue, units }

String _prodPeriodLabel(_ProdPeriod p) {
  switch (p) {
    case _ProdPeriod.allTime: return 'All Time';
    case _ProdPeriod.today:   return 'Today';
    case _ProdPeriod.week:    return 'This Week';
    case _ProdPeriod.month:   return 'This Month';
    case _ProdPeriod.year:    return 'This Year';
    case _ProdPeriod.custom:  return 'Custom';
  }
}

class _ProductStat {
  final String name;
  double revenue = 0;
  double units = 0;
  String unit = 'pcs';
  _ProductStat(this.name);
}

class _TopProductsTab extends StatefulWidget {
  final List<Invoice> invoices;
  final List<DailySale> dailySales;
  final String currency;

  const _TopProductsTab({
    required this.invoices,
    required this.dailySales,
    required this.currency,
  });

  @override
  State<_TopProductsTab> createState() => _TopProductsTabState();
}

class _TopProductsTabState extends State<_TopProductsTab> {
  _ProdPeriod _period = _ProdPeriod.allTime;
  DateTimeRange? _customRange;
  _ProdSort _sortBy = _ProdSort.revenue;

  DateTimeRange? _rangeFor(_ProdPeriod p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    switch (p) {
      case _ProdPeriod.allTime:
        return null;
      case _ProdPeriod.today:
        return DateTimeRange(start: today, end: tomorrow);
      case _ProdPeriod.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: monday, end: tomorrow);
      case _ProdPeriod.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: tomorrow);
      case _ProdPeriod.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: tomorrow);
      case _ProdPeriod.custom:
        return _customRange ??
            DateTimeRange(
                start: DateTime(now.year, now.month, 1), end: tomorrow);
    }
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
        _period = _ProdPeriod.custom;
        _customRange = range;
      });
    }
  }

  List<_ProductStat> _buildStats() {
    final range = _rangeFor(_period);
    bool inRange(DateTime d) {
      if (range == null) return true;
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(range.start) && day.isBefore(range.end);
    }

    final map = <String, _ProductStat>{};

    for (final inv in widget.invoices) {
      if (inv.isQuotation || inv.isCreditNote) continue;
      if (!inRange(inv.invoiceDate)) continue;
      for (final item in inv.items) {
        final name = item.description.trim();
        if (name.isEmpty) continue;
        final stat = map.putIfAbsent(name, () => _ProductStat(name));
        stat.revenue += item.total;
        stat.units += item.quantity;
        if (item.unit.trim().isNotEmpty) stat.unit = item.unit.trim();
      }
    }

    for (final sale in widget.dailySales) {
      if (!inRange(sale.date)) continue;
      for (final item in sale.items) {
        final name = item.itemName.trim();
        if (name.isEmpty) continue;
        final stat = map.putIfAbsent(name, () => _ProductStat(name));
        stat.revenue += item.total;
        stat.units += item.quantity;
      }
    }

    return map.values.toList();
  }

  String _fmtUnits(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final stats = _buildStats();

    return Column(
      children: [
        // ── Period chips ─────────────────────────────────────────────────
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: _ProdPeriod.values.map((p) {
              final sel = _period == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    p == _ProdPeriod.custom && _customRange != null
                        ? '${Fmt.date(_customRange!.start)} – ${Fmt.date(_customRange!.end)}'
                        : _prodPeriodLabel(p),
                  ),
                  selected: sel,
                  onSelected: (_) {
                    if (p == _ProdPeriod.custom) {
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

        if (stats.isEmpty)
          Expanded(
            child: _EmptyState(
              icon: Icons.inventory_2_outlined,
              message:
                  'No sales recorded for this period.\nTop products will '
                  'appear here once you create invoices or daily sales entries.',
            ),
          )
        else
          Expanded(child: _buildList(stats)),
      ],
    );
  }

  Widget _buildList(List<_ProductStat> stats) {
    final sorted = stats.toList()
      ..sort((a, b) => _sortBy == _ProdSort.revenue
          ? b.revenue.compareTo(a.revenue)
          : b.units.compareTo(a.units));
    final top = sorted.take(20).toList();
    final maxVal = _sortBy == _ProdSort.revenue
        ? top.first.revenue
        : top.first.units;
    final totalRevenue = stats.fold(0.0, (s, e) => s + e.revenue);
    final totalUnits = stats.fold(0.0, (s, e) => s + e.units);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'Total Revenue',
                value: Fmt.currencyAmount(totalRevenue, widget.currency),
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                label: 'Units Sold',
                value: _fmtUnits(totalUnits),
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _SortToggle(
              label: 'By Revenue',
              selected: _sortBy == _ProdSort.revenue,
              onTap: () => setState(() => _sortBy = _ProdSort.revenue),
            ),
            const SizedBox(width: 8),
            _SortToggle(
              label: 'By Units Sold',
              selected: _sortBy == _ProdSort.units,
              onTap: () => setState(() => _sortBy = _ProdSort.units),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...top.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final pct = maxVal > 0
              ? (_sortBy == _ProdSort.revenue ? s.revenue : s.units) / maxVal
              : 0.0;
          return _ProductRow(
            rank: i + 1,
            name: s.name,
            revenue: Fmt.currencyAmount(s.revenue, widget.currency),
            units: '${_fmtUnits(s.units)} ${s.unit}',
            fraction: pct,
            highlightRevenue: _sortBy == _ProdSort.revenue,
            color: _colorFor(i),
          );
        }),
      ],
    );
  }
}

// ── Shared small widgets for the products tab ─────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: AppTheme.subtext(context))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.4)
                : AppTheme.outline(context),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primary : AppTheme.subtext(context),
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final String name;
  final String revenue;
  final String units;
  final double fraction;
  final bool highlightRevenue;
  final Color color;

  const _ProductRow({
    required this.rank,
    required this.name,
    required this.revenue,
    required this.units,
    required this.fraction,
    required this.highlightRevenue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? color.withValues(alpha: 0.15)
                      : AppTheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$rank',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rank <= 3 ? color : AppTheme.textSecondary)),
                ),
              ),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(revenue,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: highlightRevenue
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: highlightRevenue
                              ? color
                              : AppTheme.onCard(context))),
                  Text(units,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: highlightRevenue
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: highlightRevenue
                              ? AppTheme.subtext(context)
                              : color)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? subtitle;
  const _SectionLabel({required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context))),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle!,
                style: TextStyle(
                    fontSize: 11, color: AppTheme.subtext(context))),
          ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final double fraction; // 0.0 – 1.0
  final Color color;
  final int? rank;

  const _CategoryBar({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.fraction,
    required this.color,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
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
              if (rank != null)
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: rank! <= 3
                        ? color.withValues(alpha: 0.15)
                        : AppTheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rank! <= 3 ? color : AppTheme.textSecondary),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10, color: AppTheme.subtext(context))),
        ],
      ),
    );
  }
}

class _PieChartLegend extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  const _PieChartLegend({required this.entries, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries.asMap().entries.map((e) {
        final i = e.key;
        final cat = e.value.key;
        final rev = e.value.value;
        final share = total > 0 ? (rev / total * 100) : 0.0;
        final color = cat == _kUncategorized
            ? AppTheme.textSecondary.withValues(alpha: 0.4)
            : _colorFor(i);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(cat,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.onCard(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${share.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context))),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppTheme.textSecondary.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.subtext(context),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
