import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../models/invoice.dart';
import '../models/business_profile.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/feature_guide_sheet.dart';

// ── Period enum ───────────────────────────────────────────────────────────────

enum _PLPeriod { today, week, month, year, custom }

extension _PLPeriodLabel on _PLPeriod {
  String get label {
    switch (this) {
      case _PLPeriod.today:  return 'Today';
      case _PLPeriod.week:   return 'This Week';
      case _PLPeriod.month:  return 'This Month';
      case _PLPeriod.year:   return 'This Year';
      case _PLPeriod.custom: return 'Custom';
    }
  }
}

// ── Computed P&L model ────────────────────────────────────────────────────────

class _PLData {
  // Revenue
  final double invoiceRevenue;
  final double shopSalesRevenue;

  // COGS
  final double cogs;

  // Operating expenses
  final double businessExpenses;
  final double dailySaleExpenses;

  // Breakdowns
  final List<MapEntry<String, double>> clientRevenue;   // top clients
  final List<MapEntry<String, double>> expensesByCategory;
  final List<MapEntry<String, double>> cogsVendors;     // top vendors

  const _PLData({
    required this.invoiceRevenue,
    required this.shopSalesRevenue,
    required this.cogs,
    required this.businessExpenses,
    required this.dailySaleExpenses,
    required this.clientRevenue,
    required this.expensesByCategory,
    required this.cogsVendors,
  });

  double get totalRevenue       => invoiceRevenue + shopSalesRevenue;
  double get grossProfit        => totalRevenue - cogs;
  double get totalOpex          => businessExpenses + dailySaleExpenses;
  double get netProfit          => grossProfit - totalOpex;
  bool   get hasData            => totalRevenue > 0 || cogs > 0 || totalOpex > 0;
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
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.plReport);
    });
  }

  DateTimeRange _rangeFor(_PLPeriod p) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (p) {
      case _PLPeriod.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _PLPeriod.week:
        final monday =
            todayStart.subtract(Duration(days: todayStart.weekday - 1));
        return DateTimeRange(start: monday, end: todayEnd);
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

  bool _inRange(DateTime date, DateTimeRange range) =>
      !date.isBefore(range.start) && !date.isAfter(range.end);

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange,
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
          end: DateTime(picked.end.year, picked.end.month, picked.end.day,
              23, 59, 59, 999),
        );
        _period = _PLPeriod.custom;
      });
    }
  }

  _PLData _compute(AppProvider provider, DateTimeRange range) {
    // ── Invoice revenue (accrual: invoiceDate, status=paid) ──────────
    final paidInvoices = provider.invoicesOnly
        .where((i) =>
            i.status == InvoiceStatus.paid && _inRange(i.invoiceDate, range))
        .toList();
    final invoiceRevenue =
        paidInvoices.fold(0.0, (s, i) => s + i.grandTotal);

    // ── Shop sales revenue ──────────────────────────────────────────
    final shopSalesRevenue = provider.dailySales
        .where((s) => _inRange(s.date, range))
        .fold(0.0, (s, sale) => s + sale.totalReceived);

    // ── COGS from purchase bills ────────────────────────────────────
    final periodBills = provider.purchaseBills
        .where((b) => _inRange(b.billDate, range))
        .toList();
    final cogs = periodBills.fold(0.0, (s, b) => s + b.grandTotal);

    // ── Business expenses ───────────────────────────────────────────
    final periodExpenses =
        provider.expenses.where((e) => _inRange(e.date, range)).toList();
    final businessExpenses =
        periodExpenses.fold(0.0, (s, e) => s + e.amount);

    // ── Daily sale expenses ─────────────────────────────────────────
    final dailySaleExpenses = provider.dailySales
        .where((s) => _inRange(s.date, range))
        .fold(0.0, (s, sale) => s + sale.totalExpenses);

    // ── Client revenue breakdown ────────────────────────────────────
    final clientMap = <String, double>{};
    for (final inv in paidInvoices) {
      final name = inv.client?.displayName ?? 'Unknown';
      clientMap[name] = (clientMap[name] ?? 0) + inv.grandTotal;
    }
    final clientRevenue = (clientMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    // ── Expenses by category ────────────────────────────────────────
    final catMap = <String, double>{};
    for (final e in periodExpenses) {
      catMap[e.category] = (catMap[e.category] ?? 0) + e.amount;
    }
    // Add daily sale expenses as a single category
    if (dailySaleExpenses > 0) {
      catMap['Daily Expenses'] =
          (catMap['Daily Expenses'] ?? 0) + dailySaleExpenses;
    }
    final expensesByCategory = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── COGS by vendor ──────────────────────────────────────────────
    final vendorMap = <String, double>{};
    for (final b in periodBills) {
      vendorMap[b.vendorName] =
          (vendorMap[b.vendorName] ?? 0) + b.grandTotal;
    }
    final cogsVendors = (vendorMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    return _PLData(
      invoiceRevenue: invoiceRevenue,
      shopSalesRevenue: shopSalesRevenue,
      cogs: cogs,
      businessExpenses: businessExpenses,
      dailySaleExpenses: dailySaleExpenses,
      clientRevenue: clientRevenue,
      expensesByCategory: expensesByCategory,
      cogsVendors: cogsVendors,
    );
  }

  Future<void> _export(
      _PLData data, BusinessProfile profile, String periodLabel) async {
    setState(() => _exporting = true);
    try {
      final bytes =
          await _PLPdf.generate(data, profile, periodLabel);
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) => bytes,
          name: 'PL_Report_${periodLabel.replaceAll(' ', '_')}',
        );
      } else {
        final safe =
            periodLabel.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/PL_Report_$safe.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'P&L Report – $periodLabel',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final range = _rangeFor(_period);
    final data = _compute(provider, range);

    final periodLabel = _period == _PLPeriod.custom && _customRange != null
        ? '${Fmt.shortDate(_customRange!.start)} – ${Fmt.shortDate(_customRange!.end)}'
        : _period.label;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('P & L Report'),
            Text(
              periodLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtext(context),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: data.hasData
                  ? () => _export(data, provider.profile, periodLabel)
                  : null,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Period selector ────────────────────────────────────────
            _PeriodSelector(
              period: _period,
              customRange: _customRange,
              onSelect: (p) => setState(() => _period = p),
              onCustomTap: _pickCustomRange,
            ),
            const SizedBox(height: 20),

            if (!data.hasData) ...[
              _EmptyState(),
            ] else ...[
              // ── Summary cards ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Revenue',
                      amount: data.totalRevenue,
                      currency: currency,
                      color: AppTheme.success,
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Gross Profit',
                      amount: data.grossProfit,
                      currency: currency,
                      color: data.grossProfit >= 0
                          ? const Color(0xFF0891B2)
                          : AppTheme.error,
                      icon: Icons.show_chart_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: data.netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                      amount: data.netProfit.abs(),
                      currency: currency,
                      color: data.netProfit >= 0
                          ? const Color(0xFF0D9488)
                          : AppTheme.error,
                      icon: data.netProfit >= 0
                          ? Icons.account_balance_outlined
                          : Icons.account_balance_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── P&L Statement (accounting format) ─────────────────
              _PLStatement(data: data, currency: currency),
              const SizedBox(height: 24),

              // ── Revenue Breakdown (top clients) ────────────────────
              if (data.clientRevenue.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Revenue Breakdown',
                  subtitle: 'Top ${data.clientRevenue.length} paying clients',
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: data.clientRevenue
                        .asMap()
                        .entries
                        .map((e) => _ClientRevenueRow(
                              rank: e.key + 1,
                              clientName: e.value.key,
                              amount: Fmt.currencyAmount(
                                  e.value.value, currency),
                              fraction: data.invoiceRevenue > 0
                                  ? e.value.value / data.invoiceRevenue
                                  : 0,
                              isLast:
                                  e.key == data.clientRevenue.length - 1,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── COGS Breakdown (top vendors) ───────────────────────
              if (data.cogsVendors.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Cost of Goods Sold',
                  subtitle: 'Top ${data.cogsVendors.length} vendors',
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: data.cogsVendors
                        .asMap()
                        .entries
                        .map((e) => _VendorCogsRow(
                              rank: e.key + 1,
                              vendorName: e.value.key,
                              amount: Fmt.currencyAmount(
                                  e.value.value, currency),
                              fraction: data.cogs > 0
                                  ? e.value.value / data.cogs
                                  : 0,
                              isLast:
                                  e.key == data.cogsVendors.length - 1,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Expense Breakdown (by category) ────────────────────
              if (data.expensesByCategory.isNotEmpty) ...[
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
                    children: data.expensesByCategory
                        .asMap()
                        .entries
                        .map((e) {
                      final pct = data.totalOpex > 0
                          ? e.value.value / data.totalOpex * 100
                          : 0.0;
                      final maxCat = data.expensesByCategory.first.value;
                      return _ExpenseCategoryRow(
                        category: e.value.key,
                        amount: Fmt.currencyAmount(
                            e.value.value, currency),
                        pct: pct,
                        fraction:
                            maxCat > 0 ? e.value.value / maxCat : 0,
                        isLast:
                            e.key == data.expensesByCategory.length - 1,
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

// ── P&L Statement card ────────────────────────────────────────────────────────

class _PLStatement extends StatelessWidget {
  final _PLData data;
  final String currency;

  const _PLStatement({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final profitColor =
        data.netProfit >= 0 ? const Color(0xFF0D9488) : AppTheme.error;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              'Statement',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.subtext(context),
                letterSpacing: 0.4,
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.outline(context)),

          // Revenue section
          _StatRow(label: 'Invoice Sales',
              value: Fmt.currencyAmount(data.invoiceRevenue, currency),
              indent: 1, color: null, context: context),
          if (data.shopSalesRevenue > 0)
            _StatRow(label: 'Shop Sales',
                value: Fmt.currencyAmount(data.shopSalesRevenue, currency),
                indent: 1, color: null, context: context),
          _StatRow(label: 'Total Revenue',
              value: Fmt.currencyAmount(data.totalRevenue, currency),
              bold: true, color: AppTheme.success, context: context),

          Divider(height: 1, color: AppTheme.outline(context)),

          // COGS section
          _StatRow(label: 'Cost of Goods Sold (Purchases)',
              value: '(${Fmt.currencyAmount(data.cogs, currency)})',
              indent: 1, color: data.cogs > 0 ? AppTheme.error : null,
              context: context),
          _StatRow(label: 'Gross Profit',
              value: Fmt.currencyAmount(data.grossProfit, currency),
              bold: true,
              color: data.grossProfit >= 0
                  ? const Color(0xFF0891B2)
                  : AppTheme.error,
              context: context),

          Divider(height: 1, color: AppTheme.outline(context)),

          // Operating expenses section
          _StatRow(label: 'Business Expenses',
              value: '(${Fmt.currencyAmount(data.businessExpenses, currency)})',
              indent: 1, color: data.businessExpenses > 0 ? AppTheme.error : null,
              context: context),
          if (data.dailySaleExpenses > 0)
            _StatRow(label: 'Daily Sale Expenses',
                value: '(${Fmt.currencyAmount(data.dailySaleExpenses, currency)})',
                indent: 1, color: AppTheme.error, context: context),
          _StatRow(label: 'Total Operating Expenses',
              value: '(${Fmt.currencyAmount(data.totalOpex, currency)})',
              bold: true, color: data.totalOpex > 0 ? AppTheme.error : null,
              context: context),

          Divider(height: 1, color: AppTheme.outline(context)),

          // Net profit
          Container(
            decoration: BoxDecoration(
              color: profitColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: _StatRow(
              label: data.netProfit >= 0 ? 'Net Profit' : 'Net Loss',
              value: Fmt.currencyAmount(data.netProfit.abs(), currency),
              bold: true,
              large: true,
              color: profitColor,
              context: context,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;
  final int indent;
  final Color? color;
  final BuildContext context;

  const _StatRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.large = false,
    this.indent = 0,
    this.color,
    required this.context,
  });

  @override
  Widget build(BuildContext outerContext) {
    final textColor = color ?? AppTheme.onCard(context);
    final labelColor = bold ? textColor : AppTheme.subtext(context);
    final fontSize = large ? 14.0 : 13.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.0 + indent * 10, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w500,
                    color: labelColor)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: textColor)),
        ],
      ),
    );
  }
}

// ── PDF generator ─────────────────────────────────────────────────────────────

class _PLPdf {
  static Future<Uint8List> generate(
      _PLData data, BusinessProfile profile, String periodLabel) async {
    final pdf = pw.Document();

    // Fonts
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldData);
    final theme = pw.ThemeData.withFont(base: font, bold: bold);

    final cur = profile.currency;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          // ── Header ────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    profile.name.isNotEmpty
                        ? profile.name
                        : 'Business',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: const PdfColor.fromInt(0xFF2563EB)),
                  ),
                  if (profile.address.isNotEmpty)
                    pw.Text(profile.address,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                  if (profile.phone.isNotEmpty)
                    pw.Text(profile.phone,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Profit & Loss Report',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 14,
                          color: PdfColors.grey800)),
                  pw.SizedBox(height: 4),
                  pw.Text(periodLabel,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 11,
                          color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: const PdfColor.fromInt(0xFF2563EB), thickness: 1.5),
          pw.SizedBox(height: 16),

          // ── Revenue ──────────────────────────────────────────────
          _pdfSectionHeader('REVENUE', bold),
          _pdfRow('Invoice Sales',
              Fmt.currencyAmount(data.invoiceRevenue, cur), font, bold,
              indent: true),
          if (data.shopSalesRevenue > 0)
            _pdfRow('Shop Sales',
                Fmt.currencyAmount(data.shopSalesRevenue, cur), font, bold,
                indent: true),
          _pdfRow('Total Revenue',
              Fmt.currencyAmount(data.totalRevenue, cur), font, bold,
              isBold: true,
              textColor: const PdfColor.fromInt(0xFF16A34A)),
          pw.SizedBox(height: 12),

          // ── COGS ─────────────────────────────────────────────────
          _pdfSectionHeader('COST OF GOODS SOLD', bold),
          _pdfRow('Purchases (Bills)',
              '(${Fmt.currencyAmount(data.cogs, cur)})', font, bold,
              indent: true,
              textColor: data.cogs > 0 ? PdfColors.red700 : PdfColors.grey800),
          _pdfRow('Gross Profit',
              Fmt.currencyAmount(data.grossProfit, cur), font, bold,
              isBold: true,
              textColor: data.grossProfit >= 0
                  ? const PdfColor.fromInt(0xFF0891B2)
                  : PdfColors.red700),
          pw.SizedBox(height: 12),

          // ── Operating expenses ────────────────────────────────────
          _pdfSectionHeader('OPERATING EXPENSES', bold),
          _pdfRow('Business Expenses',
              '(${Fmt.currencyAmount(data.businessExpenses, cur)})',
              font, bold,
              indent: true,
              textColor: data.businessExpenses > 0
                  ? PdfColors.red700
                  : PdfColors.grey800),
          if (data.dailySaleExpenses > 0)
            _pdfRow('Daily Sale Expenses',
                '(${Fmt.currencyAmount(data.dailySaleExpenses, cur)})',
                font, bold,
                indent: true,
                textColor: PdfColors.red700),
          _pdfRow('Total Operating Expenses',
              '(${Fmt.currencyAmount(data.totalOpex, cur)})', font, bold,
              isBold: true,
              textColor: data.totalOpex > 0 ? PdfColors.red700 : PdfColors.grey800),
          pw.SizedBox(height: 12),

          // ── Net profit ────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              color: data.netProfit >= 0
                  ? const PdfColor.fromInt(0x110D9488)
                  : const PdfColor.fromInt(0x11DC2626),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  data.netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 13,
                      color: data.netProfit >= 0
                          ? const PdfColor.fromInt(0xFF0D9488)
                          : PdfColors.red700),
                ),
                pw.Text(
                  Fmt.currencyAmount(data.netProfit.abs(), cur),
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 14,
                      color: data.netProfit >= 0
                          ? const PdfColor.fromInt(0xFF0D9488)
                          : PdfColors.red700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // ── Expense breakdown ─────────────────────────────────────
          if (data.expensesByCategory.isNotEmpty) ...[
            _pdfSectionHeader('EXPENSE BREAKDOWN BY CATEGORY', bold),
            pw.Table(
              border: pw.TableBorder(
                  bottom: const pw.BorderSide(color: PdfColors.grey300)),
              children: [
                pw.TableRow(children: [
                  _pdfCell('Category', bold, isHeader: true),
                  _pdfCell('Amount', bold,
                      isHeader: true, align: pw.Alignment.centerRight),
                  _pdfCell('%', bold,
                      isHeader: true, align: pw.Alignment.centerRight),
                ]),
                ...data.expensesByCategory.map((e) {
                  final pct = data.totalOpex > 0
                      ? e.value / data.totalOpex * 100
                      : 0.0;
                  return pw.TableRow(children: [
                    _pdfCell(e.key, font),
                    _pdfCell(Fmt.currencyAmount(e.value, cur), font,
                        align: pw.Alignment.centerRight,
                        color: PdfColors.red700),
                    _pdfCell('${pct.toStringAsFixed(1)}%', font,
                        align: pw.Alignment.centerRight),
                  ]);
                }),
              ],
            ),
          ],

          // ── Footer ────────────────────────────────────────────────
          pw.SizedBox(height: 32),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            'Generated by BillBook  •  ${Fmt.date(DateTime.now())}',
            style: pw.TextStyle(
                font: font, fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfSectionHeader(String title, pw.Font bold) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(title,
            style: pw.TextStyle(
                font: bold,
                fontSize: 9,
                color: PdfColors.grey600,
                letterSpacing: 0.8)),
      );

  static pw.Widget _pdfRow(
    String label,
    String value,
    pw.Font font,
    pw.Font bold, {
    bool indent = false,
    bool isBold = false,
    PdfColor? textColor,
  }) =>
      pw.Padding(
        padding: pw.EdgeInsets.only(
            left: indent ? 12.0 : 0, bottom: 5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: isBold ? bold : font,
                    fontSize: isBold ? 12 : 11,
                    color: textColor ?? PdfColors.grey800)),
            pw.Text(value,
                style: pw.TextStyle(
                    font: isBold ? bold : font,
                    fontSize: isBold ? 12 : 11,
                    color: textColor ?? PdfColors.grey800)),
          ],
        ),
      );

  static pw.Widget _pdfCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    PdfColor? color,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        alignment: align,
        decoration: isHeader
            ? const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400)))
            : null,
        child: pw.Text(text,
            style: pw.TextStyle(
                font: font,
                fontSize: isHeader ? 9 : 10,
                color: color ??
                    (isHeader ? PdfColors.grey600 : PdfColors.grey800),
                fontWeight: isHeader
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal)),
      );
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
                  color:
                      selected ? Colors.white : AppTheme.onCard(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.outline(context),
                ),
                backgroundColor: AppTheme.card(context),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                  Icon(Icons.calendar_month_outlined,
                      size: 14,
                      color: period == _PLPeriod.custom
                          ? AppTheme.primary
                          : AppTheme.subtext(context)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.subtext(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currencyAmount(amount, currency),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color),
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
        Text(title,
            style: TextStyle(
                fontSize: 15,
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
                      child: Text('$rank',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: rank <= 3
                                  ? AppTheme.success
                                  : AppTheme.subtext(context))),
                    ),
                  ),
                  Expanded(
                    child: Text(clientName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(amount,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success)),
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
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.success),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppTheme.outline(context)),
      ],
    );
  }
}

// ── Vendor COGS row ───────────────────────────────────────────────────────────

class _VendorCogsRow extends StatelessWidget {
  final int rank;
  final String vendorName;
  final String amount;
  final double fraction;
  final bool isLast;

  const _VendorCogsRow({
    required this.rank,
    required this.vendorName,
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
                      color: const Color(0xFFB45309).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$rank',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309))),
                    ),
                  ),
                  Expanded(
                    child: Text(vendorName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(amount,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309))),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor:
                      const Color(0xFFB45309).withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFB45309)),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppTheme.outline(context)),
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
                    child: Text(category,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(amount,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error)),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppTheme.error.withValues(alpha: 0.10),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.error),
                ),
              ),
              const SizedBox(height: 4),
              Text('${pct.toStringAsFixed(1)}% of total expenses',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.subtext(context))),
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
            Icon(Icons.analytics_outlined,
                size: 56,
                color:
                    AppTheme.subtext(context).withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text('No data for this period',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(context))),
            const SizedBox(height: 6),
            Text(
              'Record invoices, daily sales, or expenses\nto see your P&L report.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.subtext(context),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
