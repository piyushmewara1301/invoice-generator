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
import '../models/invoice.dart';
import '../models/business_profile.dart';
import '../models/subscription_limits.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/gst_utils.dart';
import '../widgets/paywall_sheet.dart';

// ── Internal data types ───────────────────────────────────────────────────────

class _TaxGroup {
  final double rate;
  double taxable = 0;
  double cgst = 0;
  double sgst = 0;
  double igst = 0;
  _TaxGroup(this.rate);
  double get total => cgst + sgst + igst;
}

class _HsnGroup {
  final String code;
  double taxable = 0;
  double cgst = 0;
  double sgst = 0;
  double igst = 0;
  _HsnGroup(this.code);
  double get total => cgst + sgst + igst;
}

class _InvRow {
  final Invoice invoice;
  final GstSupplyType supplyType;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  const _InvRow({
    required this.invoice,
    required this.supplyType,
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });
  double get total => cgst + sgst + igst;
  bool get isB2B => invoice.client?.gstin?.isNotEmpty == true;
}

class _ReportData {
  final List<_TaxGroup> taxGroups;
  final List<_HsnGroup> hsnGroups;
  final List<_InvRow> rows;
  final double totalTaxable;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  const _ReportData({
    required this.taxGroups,
    required this.hsnGroups,
    required this.rows,
    required this.totalTaxable,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
  });
  double get totalTax => totalCgst + totalSgst + totalIgst;
  double get grandTotal => rows.fold(0.0, (s, r) => s + r.invoice.grandTotal);
  List<_InvRow> get b2b => rows.where((r) => r.isB2B).toList();
  List<_InvRow> get b2c => rows.where((r) => !r.isB2B).toList();
  bool get hasRealHsn => hsnGroups.any((g) => g.code != '—');
}

// ── Period enum ───────────────────────────────────────────────────────────────

enum _GstPeriod { q1, q2, q3, q4, fy, custom }

extension _GstPeriodLabel on _GstPeriod {
  String label(int fyStart) {
    switch (this) {
      case _GstPeriod.q1:  return 'Q1 Apr–Jun';
      case _GstPeriod.q2:  return 'Q2 Jul–Sep';
      case _GstPeriod.q3:  return 'Q3 Oct–Dec';
      case _GstPeriod.q4:  return 'Q4 Jan–Mar';
      case _GstPeriod.fy:  return 'Full FY ${fyStart % 100}-${(fyStart + 1) % 100}';
      case _GstPeriod.custom: return 'Custom';
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GstReportScreen extends StatefulWidget {
  const GstReportScreen({super.key});

  @override
  State<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends State<GstReportScreen> {
  late _GstPeriod _period;
  DateTimeRange? _customRange;
  bool _exporting = false;

  static const _saffron = Color(0xFFE65100);
  static const _saffronLight = Color(0xFFFFF3E0);

  @override
  void initState() {
    super.initState();
    _period = _currentFyQuarter();
  }

  // ── Period helpers ─────────────────────────────────────────────────────────

  int get _fyStartYear {
    final now = DateTime.now();
    return now.month >= 4 ? now.year : now.year - 1;
  }

  _GstPeriod _currentFyQuarter() {
    final m = DateTime.now().month;
    if (m >= 4 && m <= 6) return _GstPeriod.q1;
    if (m >= 7 && m <= 9) return _GstPeriod.q2;
    if (m >= 10 && m <= 12) return _GstPeriod.q3;
    return _GstPeriod.q4;
  }

  DateTimeRange _rangeFor(_GstPeriod p) {
    final fy = _fyStartYear;
    switch (p) {
      case _GstPeriod.q1:
        return DateTimeRange(
            start: DateTime(fy, 4, 1),
            end: DateTime(fy, 6, 30, 23, 59, 59));
      case _GstPeriod.q2:
        return DateTimeRange(
            start: DateTime(fy, 7, 1),
            end: DateTime(fy, 9, 30, 23, 59, 59));
      case _GstPeriod.q3:
        return DateTimeRange(
            start: DateTime(fy, 10, 1),
            end: DateTime(fy, 12, 31, 23, 59, 59));
      case _GstPeriod.q4:
        return DateTimeRange(
            start: DateTime(fy + 1, 1, 1),
            end: DateTime(fy + 1, 3, 31, 23, 59, 59));
      case _GstPeriod.fy:
        return DateTimeRange(
            start: DateTime(fy, 4, 1),
            end: DateTime(fy + 1, 3, 31, 23, 59, 59));
      case _GstPeriod.custom:
        return _customRange ?? _rangeFor(_currentFyQuarter());
    }
  }

  String get _periodLabel {
    if (_period == _GstPeriod.custom && _customRange != null) {
      return '${Fmt.shortDate(_customRange!.start)} – ${Fmt.shortDate(_customRange!.end)}';
    }
    final r = _rangeFor(_period);
    return '${Fmt.shortDate(r.start)} – ${Fmt.shortDate(r.end)}';
  }

  // ── Data computation ───────────────────────────────────────────────────────

  _ReportData _compute(List<Invoice> all, BusinessProfile profile) {
    final range = _rangeFor(_period);
    final invoices = all.where((inv) {
      final d = inv.invoiceDate;
      return !d.isBefore(range.start) && !d.isAfter(range.end);
    }).toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    final Map<double, _TaxGroup> taxMap = {};
    final Map<String, _HsnGroup> hsnMap = {};
    double totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalIgst = 0;

    final rows = <_InvRow>[];

    for (final inv in invoices) {
      final supplyType = getSupplyType(profile.gstin, inv.placeOfSupply);
      double invTaxable = 0, invCgst = 0, invSgst = 0, invIgst = 0;

      for (final item in inv.items) {
        final split =
            computeTaxSplit(item.taxableAmount, item.taxPercent, supplyType);
        invTaxable += item.taxableAmount;
        invCgst += split.cgstAmount;
        invSgst += split.sgstAmount;
        invIgst += split.igstAmount;

        // Tax rate group
        taxMap.putIfAbsent(item.taxPercent, () => _TaxGroup(item.taxPercent));
        taxMap[item.taxPercent]!
          ..taxable += item.taxableAmount
          ..cgst += split.cgstAmount
          ..sgst += split.sgstAmount
          ..igst += split.igstAmount;

        // HSN/SAC group
        final code =
            (item.hsnSac?.isNotEmpty == true) ? item.hsnSac! : '—';
        hsnMap.putIfAbsent(code, () => _HsnGroup(code));
        hsnMap[code]!
          ..taxable += item.taxableAmount
          ..cgst += split.cgstAmount
          ..sgst += split.sgstAmount
          ..igst += split.igstAmount;
      }

      totalTaxable += invTaxable;
      totalCgst += invCgst;
      totalSgst += invSgst;
      totalIgst += invIgst;

      rows.add(_InvRow(
        invoice: inv,
        supplyType: supplyType,
        taxable: invTaxable,
        cgst: invCgst,
        sgst: invSgst,
        igst: invIgst,
      ));
    }

    return _ReportData(
      taxGroups: taxMap.values.toList()
        ..sort((a, b) => a.rate.compareTo(b.rate)),
      hsnGroups: hsnMap.values.toList()
        ..sort((a, b) => a.code.compareTo(b.code)),
      rows: rows,
      totalTaxable: totalTaxable,
      totalCgst: totalCgst,
      totalSgst: totalSgst,
      totalIgst: totalIgst,
    );
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf(
      _ReportData data, BusinessProfile profile, String sym) async {
    setState(() => _exporting = true);
    try {
      final bytes =
          await _GstReportPdf.generate(data, profile, sym, _periodLabel);
      if (kIsWeb) {
        // Web: open native browser print/save dialog
        await Printing.layoutPdf(
          onLayout: (_) => Uint8List.fromList(bytes),
          name: 'GST_Report_$_periodLabel',
        );
      } else {
        // Mobile: save to temp file then share
        final safe = _periodLabel.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
        final dir  = await getTemporaryDirectory();
        final file = File('${dir.path}/GST_Report_$safe.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'GST Report – $_periodLabel',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Period picker ──────────────────────────────────────────────────────────

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _saffron),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month, picked.end.day,
              23, 59, 59),
        );
        _period = _GstPeriod.custom;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.profile;
    final invoices = provider.invoices;
    final sym = Fmt.currencySymbol(profile.currency);

    final data = _compute(invoices, profile);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('GST Reports'),
        actions: [
          if (data.rows.isNotEmpty)
            _exporting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Export PDF',
                    onPressed: () => _exportPdf(data, profile, sym),
                  ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Period selector ────────────────────────────────────────────────
          _buildPeriodSelector(),
          const SizedBox(height: 4),
          Text(
            _periodLabel,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── GST not set up banner ──────────────────────────────────────────
          if (!profile.isGstRegistered) ...[
            _buildGstSetupBanner(),
            const SizedBox(height: 16),
          ],

          // ── No invoices ────────────────────────────────────────────────────
          if (data.rows.isEmpty) ...[
            _buildEmpty(),
          ] else ...[
            // ── Summary totals ─────────────────────────────────────────────
            _buildSummaryBanner(data, sym),
            const SizedBox(height: 16),

            // ── Tax rate summary ───────────────────────────────────────────
            _buildSection(
              icon: Icons.percent_rounded,
              title: 'Tax Rate Summary',
              subtitle:
                  'Taxable value and GST collected grouped by rate',
              child: _buildTaxRateTable(data, sym),
            ),
            const SizedBox(height: 12),

            // ── HSN/SAC summary ────────────────────────────────────────────
            if (data.hasRealHsn) ...[
              _buildSection(
                icon: Icons.tag_rounded,
                title: 'HSN / SAC Summary',
                subtitle: 'Tax breakup by commodity / service code',
                child: _buildHsnTable(data, sym),
              ),
              const SizedBox(height: 12),
            ],

            // ── B2B supplies ───────────────────────────────────────────────
            if (data.b2b.isNotEmpty) ...[
              _buildSection(
                icon: Icons.business_outlined,
                title: 'B2B Supplies',
                subtitle:
                    '${data.b2b.length} invoice${data.b2b.length == 1 ? '' : 's'} with buyer GSTIN',
                child: _buildInvoiceList(data.b2b, sym, showGstin: true),
              ),
              const SizedBox(height: 12),
            ],

            // ── B2C supplies ───────────────────────────────────────────────
            if (data.b2c.isNotEmpty) ...[
              _buildSection(
                icon: Icons.person_outline,
                title: 'B2C Supplies',
                subtitle:
                    '${data.b2c.length} invoice${data.b2c.length == 1 ? '' : 's'} without buyer GSTIN',
                child: _buildInvoiceList(data.b2c, sym, showGstin: false),
              ),
              const SizedBox(height: 12),
            ],

            // ── Invoice register ───────────────────────────────────────────
            _buildSection(
              icon: Icons.receipt_long_outlined,
              title: 'Invoice Register',
              subtitle:
                  '${data.rows.length} invoice${data.rows.length == 1 ? '' : 's'} · $_periodLabel',
              child: _buildRegisterTable(data, sym),
            ),
          ],
        ],
      ),
    );
  }

  // ── Period selector widget ─────────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    final fy = _fyStartYear;
    final periods = [
      _GstPeriod.q1,
      _GstPeriod.q2,
      _GstPeriod.q3,
      _GstPeriod.q4,
      _GstPeriod.fy,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...periods.map((p) {
            final sel = _period == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.label(fy)),
                selected: sel,
                onSelected: (_) => setState(() => _period = p),
                selectedColor: _saffron,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : AppTheme.textPrimary,
                ),
                side: BorderSide(
                    color: sel ? _saffron : AppTheme.divider),
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            );
          }),
          ActionChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _period == _GstPeriod.custom && _customRange != null
                      ? '${Fmt.shortDate(_customRange!.start)} – ${Fmt.shortDate(_customRange!.end)}'
                      : 'Custom',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _period == _GstPeriod.custom
                        ? _saffron
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.calendar_month_outlined,
                    size: 14,
                    color: _period == _GstPeriod.custom
                        ? _saffron
                        : AppTheme.textSecondary),
              ],
            ),
            onPressed: _pickCustomRange,
            side: BorderSide(
                color: _period == _GstPeriod.custom
                    ? _saffron
                    : AppTheme.divider),
            backgroundColor: _period == _GstPeriod.custom
                ? _saffron.withValues(alpha: 0.08)
                : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
        ],
      ),
    );
  }

  // ── Summary banner ─────────────────────────────────────────────────────────

  Widget _buildSummaryBanner(_ReportData data, String sym) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFBF360C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _saffron.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              const Text('GST Summary',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data.rows.length} invoice${data.rows.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryTile('Taxable Value',
                  '$sym${Fmt.compact(data.totalTaxable)}'),
              _summaryDivider(),
              _summaryTile('Total GST',
                  '$sym${Fmt.compact(data.totalTax)}',
                  highlight: true),
              _summaryDivider(),
              _summaryTile('Grand Total',
                  '$sym${Fmt.compact(data.grandTotal)}'),
            ],
          ),
          if (data.totalCgst > 0 || data.totalIgst > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (data.totalCgst > 0) ...[
                    _taxChip(
                        'CGST', '$sym${Fmt.compact(data.totalCgst)}'),
                    _taxChip(
                        'SGST/UTGST', '$sym${Fmt.compact(data.totalSgst)}'),
                  ],
                  if (data.totalIgst > 0)
                    _taxChip(
                        'IGST', '$sym${Fmt.compact(data.totalIgst)}'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value,
      {bool highlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color:
                    highlight ? const Color(0xFFFFCC80) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() => Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.25));

  Widget _taxChip(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Section card wrapper ───────────────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _saffron.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: _saffron),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  // ── Tax rate table ─────────────────────────────────────────────────────────

  Widget _buildTaxRateTable(_ReportData data, String sym) {
    final isInter =
        data.rows.any((r) => r.supplyType == GstSupplyType.interState);
    final isIntra =
        data.rows.any((r) => r.supplyType == GstSupplyType.intraState);
    final mixed = isInter && isIntra;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        horizontalMargin: 0,
        columnSpacing: 20,
        headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary),
        dataTextStyle: const TextStyle(
            fontSize: 12, color: AppTheme.textPrimary),
        columns: [
          const DataColumn(label: Text('Rate')),
          DataColumn(
              label: const Text('Taxable Value'),
              numeric: true),
          if (!isInter || mixed)
            const DataColumn(label: Text('CGST'), numeric: true),
          if (!isInter || mixed)
            const DataColumn(label: Text('SGST/UTGST'), numeric: true),
          if (!isIntra || mixed)
            const DataColumn(label: Text('IGST'), numeric: true),
          DataColumn(
              label: const Text('Total Tax'), numeric: true),
        ],
        rows: [
          ...data.taxGroups.map((g) => DataRow(cells: [
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: g.rate == 0
                        ? AppTheme.divider
                        : _saffron.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    g.rate == 0
                        ? 'Nil'
                        : '${_fmt(g.rate)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: g.rate == 0
                          ? AppTheme.textSecondary
                          : _saffron,
                    ),
                  ),
                )),
                DataCell(Text('$sym${_amt(g.taxable)}')),
                if (!isInter || mixed)
                  DataCell(Text('$sym${_amt(g.cgst)}')),
                if (!isInter || mixed)
                  DataCell(Text('$sym${_amt(g.sgst)}')),
                if (!isIntra || mixed)
                  DataCell(Text('$sym${_amt(g.igst)}')),
                DataCell(Text(
                  '$sym${_amt(g.total)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
              ])),
          // Total row
          DataRow(
            color: WidgetStateProperty.all(_saffronLight),
            cells: [
              const DataCell(Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text('$sym${_amt(data.totalTaxable)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700))),
              if (!isInter || mixed)
                DataCell(Text('$sym${_amt(data.totalCgst)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700))),
              if (!isInter || mixed)
                DataCell(Text('$sym${_amt(data.totalSgst)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700))),
              if (!isIntra || mixed)
                DataCell(Text('$sym${_amt(data.totalIgst)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700))),
              DataCell(Text('$sym${_amt(data.totalTax)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _saffron))),
            ],
          ),
        ],
      ),
    );
  }

  // ── HSN/SAC table ──────────────────────────────────────────────────────────

  Widget _buildHsnTable(_ReportData data, String sym) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        horizontalMargin: 0,
        columnSpacing: 20,
        headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary),
        dataTextStyle: const TextStyle(
            fontSize: 12, color: AppTheme.textPrimary),
        columns: const [
          DataColumn(label: Text('HSN / SAC')),
          DataColumn(label: Text('Taxable Value'), numeric: true),
          DataColumn(label: Text('CGST'), numeric: true),
          DataColumn(label: Text('SGST/UTGST'), numeric: true),
          DataColumn(label: Text('IGST'), numeric: true),
          DataColumn(label: Text('Total Tax'), numeric: true),
        ],
        rows: data.hsnGroups
            .map((g) => DataRow(cells: [
                  DataCell(Text(g.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500))),
                  DataCell(Text('$sym${_amt(g.taxable)}')),
                  DataCell(Text('$sym${_amt(g.cgst)}')),
                  DataCell(Text('$sym${_amt(g.sgst)}')),
                  DataCell(Text('$sym${_amt(g.igst)}')),
                  DataCell(Text('$sym${_amt(g.total)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600))),
                ]))
            .toList(),
      ),
    );
  }

  // ── Invoice list (B2B / B2C) ───────────────────────────────────────────────

  Widget _buildInvoiceList(List<_InvRow> rows, String sym,
      {required bool showGstin}) {
    return Column(
      children: rows.asMap().entries.map((e) {
        final i = e.key;
        final row = e.value;
        final inv = row.invoice;
        final isInter = row.supplyType == GstSupplyType.interState;
        return Column(
          children: [
            if (i > 0) const Divider(height: 1, indent: 14),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                inv.client?.displayName ?? '—',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _supplyChip(isInter),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${inv.invoiceNumber} · ${Fmt.date(inv.invoiceDate)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                        if (showGstin &&
                            inv.client?.gstin?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            'GSTIN: ${inv.client!.gstin}',
                            style: TextStyle(
                                fontSize: 10,
                                color: _saffron.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 4),
                        _taxBreakupRow(row, sym),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$sym${_amt(inv.grandTotal)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tax: $sym${_amt(row.total)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: _saffron,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _supplyChip(bool isInter) {
    final color = isInter
        ? const Color(0xFF0277BD)
        : const Color(0xFF2E7D32);
    final label = isInter ? 'IGST' : 'CGST+SGST';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _taxBreakupRow(_InvRow row, String sym) {
    final isInter = row.supplyType == GstSupplyType.interState;
    final parts = <String>[];
    if (row.taxable > 0) {
      parts.add('Taxable: $sym${_amt(row.taxable)}');
    }
    if (isInter && row.igst > 0) {
      parts.add('IGST: $sym${_amt(row.igst)}');
    }
    if (!isInter && row.cgst > 0) {
      parts.add('CGST: $sym${_amt(row.cgst)}');
      parts.add('SGST: $sym${_amt(row.sgst)}');
    }
    return Text(
      parts.join(' · '),
      style: const TextStyle(
          fontSize: 10, color: AppTheme.textSecondary),
    );
  }

  // ── Invoice register table ─────────────────────────────────────────────────

  Widget _buildRegisterTable(_ReportData data, String sym) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        horizontalMargin: 0,
        columnSpacing: 16,
        headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary),
        dataTextStyle: const TextStyle(
            fontSize: 12, color: AppTheme.textPrimary),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Invoice #')),
          DataColumn(label: Text('Party')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Taxable'), numeric: true),
          DataColumn(label: Text('Tax'), numeric: true),
          DataColumn(label: Text('Total'), numeric: true),
        ],
        rows: data.rows.asMap().entries.map((e) {
          final idx = e.key;
          final row = e.value;
          final inv = row.invoice;
          final isInter =
              row.supplyType == GstSupplyType.interState;
          return DataRow(
            color: WidgetStateProperty.resolveWith((states) =>
                idx.isOdd ? _saffronLight.withValues(alpha: 0.4) : null),
            cells: [
              DataCell(Text(Fmt.shortDate(inv.invoiceDate))),
              DataCell(Text(inv.invoiceNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500))),
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  inv.client?.displayName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
              DataCell(_supplyChip(isInter)),
              DataCell(Text('$sym${_amt(row.taxable)}')),
              DataCell(Text('$sym${_amt(row.total)}',
                  style: TextStyle(color: _saffron))),
              DataCell(Text('$sym${_amt(inv.grandTotal)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600))),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Banners ────────────────────────────────────────────────────────────────

  Widget _buildGstSetupBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFFF57F17), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'GSTIN not configured. Set up GST in Settings to see CGST/SGST/IGST splits.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF5D4037)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _saffron.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 30, color: _saffron),
            ),
            const SizedBox(height: 16),
            const Text('No invoices in this period',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text('Select a different period or create invoices',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Format helpers ─────────────────────────────────────────────────────────

  static String _amt(double v) => v.toStringAsFixed(2);
  static String _fmt(double r) =>
      r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);
}

// ── Paywall wrapper ───────────────────────────────────────────────────────────

/// Entry point — wraps GstReportScreen with a paywall check.
Future<void> openGstReport(BuildContext context) async {
  final provider = context.read<AppProvider>();
  final info = provider.checkFeature(LimitType.gstReports);
  if (info != null) {
    final upgrade = await showPaywallSheet(context, info);
    if (upgrade && context.mounted) {
      Navigator.pushNamed(context, '/plans');
    }
    return;
  }
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const GstReportScreen()),
  );
}

// ── PDF generator ─────────────────────────────────────────────────────────────

class _GstReportPdf {
  static Future<List<int>> generate(
    _ReportData data,
    BusinessProfile profile,
    String sym,
    String periodLabel,
  ) async {
    final fontData     = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);
    final theme = pw.ThemeData.withFont(base: font, bold: fontBold);
    final pdf = pw.Document();

    const saffron = PdfColor(0.90, 0.32, 0.00);
    const saffronLight = PdfColor(1.00, 0.97, 0.88);
    const dark = PdfColor(0.10, 0.10, 0.10);
    const grey = PdfColor(0.45, 0.45, 0.45);

    final isInter =
        data.rows.any((r) => r.supplyType == GstSupplyType.interState);
    final isIntra =
        data.rows.any((r) => r.supplyType == GstSupplyType.intraState);
    final mixed = isInter && isIntra;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: theme,
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    profile.name.isNotEmpty
                        ? profile.name
                        : 'GST Report',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: dark),
                  ),
                  if (profile.gstin?.isNotEmpty == true)
                    pw.Text('GSTIN: ${profile.gstin}',
                        style: pw.TextStyle(
                            fontSize: 9, color: grey)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: saffron,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('GST REPORT',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 1.5)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(periodLabel,
                      style: pw.TextStyle(
                          fontSize: 9, color: grey)),
                  pw.Text(
                      'Generated: ${_fmtDate(DateTime.now())}',
                      style: pw.TextStyle(
                          fontSize: 8, color: grey)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.8, color: saffron),
          pw.SizedBox(height: 8),
        ],
      ),
      build: (ctx) => [
        // ── Summary ──────────────────────────────────────────────
        _pdfSummaryBox(data, sym, saffron, saffronLight, dark, grey),
        pw.SizedBox(height: 16),

        // ── Tax Rate Summary ─────────────────────────────────────
        _pdfSectionTitle('Tax Rate Summary', saffron),
        pw.SizedBox(height: 6),
        _pdfTaxTable(data, sym, saffron, saffronLight, dark, grey,
            isInter: isInter, isIntra: isIntra, mixed: mixed),
        pw.SizedBox(height: 16),

        // ── HSN/SAC Summary ──────────────────────────────────────
        if (data.hasRealHsn) ...[
          _pdfSectionTitle('HSN / SAC Summary', saffron),
          pw.SizedBox(height: 6),
          _pdfHsnTable(data, sym, saffron, saffronLight, dark, grey),
          pw.SizedBox(height: 16),
        ],

        // ── Invoice Register ─────────────────────────────────────
        _pdfSectionTitle('Invoice Register', saffron),
        pw.SizedBox(height: 6),
        _pdfRegisterTable(
            data, sym, saffron, saffronLight, dark, grey),
      ],
    ));

    return pdf.save();
  }

  static pw.Widget _pdfSummaryBox(
    _ReportData data,
    String sym,
    PdfColor saffron,
    PdfColor saffronLight,
    PdfColor dark,
    PdfColor grey,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: saffronLight,
        border: pw.Border.all(color: saffron, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _pdfSumTile(
              'Invoices', '${data.rows.length}', dark, grey),
          _pdfVdivider(saffron),
          _pdfSumTile('Taxable Value',
              '$sym${_fmtAmt(data.totalTaxable)}', dark, grey),
          _pdfVdivider(saffron),
          _pdfSumTile(
              'Total GST', '$sym${_fmtAmt(data.totalTax)}', saffron, grey),
          _pdfVdivider(saffron),
          _pdfSumTile('Grand Total',
              '$sym${_fmtAmt(data.grandTotal)}', dark, grey),
        ],
      ),
    );
  }

  static pw.Widget _pdfVdivider(PdfColor color) => pw.Container(
      width: 0.6, height: 30, color: color.withAlpha(0.4));

  static pw.Widget _pdfSumTile(
      String label, String value, PdfColor vc, PdfColor lc) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 7.5, color: lc)),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style:
                pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: vc)),
      ],
    );
  }

  static pw.Widget _pdfSectionTitle(String title, PdfColor saffron) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: saffron,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              letterSpacing: 0.5)),
    );
  }

  static pw.Widget _pdfTaxTable(
    _ReportData data,
    String sym,
    PdfColor saffron,
    PdfColor saffronLight,
    PdfColor dark,
    PdfColor grey, {
    required bool isInter,
    required bool isIntra,
    required bool mixed,
  }) {
    final headers = <String>['Rate', 'Taxable Value'];
    if (!isInter || mixed) headers.addAll(['CGST', 'SGST/UTGST']);
    if (!isIntra || mixed) headers.add('IGST');
    headers.add('Total Tax');

    final rows = <pw.TableRow>[];
    rows.add(_pdfTh(headers, saffron));

    for (int i = 0; i < data.taxGroups.length; i++) {
      final g = data.taxGroups[i];
      final bg = i.isEven ? PdfColors.white : saffronLight;
      final cells = <String>[
        g.rate == 0 ? 'Nil' : '${_fmtRate(g.rate)}%',
        '$sym${_fmtAmt(g.taxable)}',
      ];
      if (!isInter || mixed) {
        cells.add('$sym${_fmtAmt(g.cgst)}');
        cells.add('$sym${_fmtAmt(g.sgst)}');
      }
      if (!isIntra || mixed) cells.add('$sym${_fmtAmt(g.igst)}');
      cells.add('$sym${_fmtAmt(g.total)}');
      rows.add(_pdfTr(cells, bg, dark, grey, lastBold: true));
    }

    // Total row
    final totCells = ['Total', '$sym${_fmtAmt(data.totalTaxable)}'];
    if (!isInter || mixed) {
      totCells.add('$sym${_fmtAmt(data.totalCgst)}');
      totCells.add('$sym${_fmtAmt(data.totalSgst)}');
    }
    if (!isIntra || mixed) totCells.add('$sym${_fmtAmt(data.totalIgst)}');
    totCells.add('$sym${_fmtAmt(data.totalTax)}');
    rows.add(_pdfTr(totCells, saffronLight, saffron, saffron,
        allBold: true));

    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: pw.BorderSide(color: saffron, width: 0.3)),
      children: rows,
    );
  }

  static pw.Widget _pdfHsnTable(
    _ReportData data,
    String sym,
    PdfColor saffron,
    PdfColor saffronLight,
    PdfColor dark,
    PdfColor grey,
  ) {
    final rows = <pw.TableRow>[];
    rows.add(_pdfTh(
        ['HSN / SAC', 'Taxable', 'CGST', 'SGST/UTGST', 'IGST', 'Total Tax'],
        saffron));
    for (int i = 0; i < data.hsnGroups.length; i++) {
      final g = data.hsnGroups[i];
      final bg = i.isEven ? PdfColors.white : saffronLight;
      rows.add(_pdfTr([
        g.code,
        '$sym${_fmtAmt(g.taxable)}',
        '$sym${_fmtAmt(g.cgst)}',
        '$sym${_fmtAmt(g.sgst)}',
        '$sym${_fmtAmt(g.igst)}',
        '$sym${_fmtAmt(g.total)}',
      ], bg, dark, grey, lastBold: true));
    }
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: pw.BorderSide(color: saffron, width: 0.3)),
      children: rows,
    );
  }

  static pw.Widget _pdfRegisterTable(
    _ReportData data,
    String sym,
    PdfColor saffron,
    PdfColor saffronLight,
    PdfColor dark,
    PdfColor grey,
  ) {
    final rows = <pw.TableRow>[];
    rows.add(_pdfTh(
        ['Date', 'Invoice #', 'Party', 'Type', 'Taxable', 'Tax', 'Total'],
        saffron));
    for (int i = 0; i < data.rows.length; i++) {
      final row = data.rows[i];
      final inv = row.invoice;
      final bg = i.isEven ? PdfColors.white : saffronLight;
      final isInter = row.supplyType == GstSupplyType.interState;
      rows.add(_pdfTr([
        _fmtDate(inv.invoiceDate),
        inv.invoiceNumber,
        inv.client?.displayName ?? '—',
        isInter ? 'IGST' : 'CGST+SGST',
        '$sym${_fmtAmt(row.taxable)}',
        '$sym${_fmtAmt(row.total)}',
        '$sym${_fmtAmt(inv.grandTotal)}',
      ], bg, dark, grey, lastBold: true));
    }
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: pw.BorderSide(color: saffron, width: 0.3)),
      columnWidths: {
        0: const pw.FixedColumnWidth(54),
        1: const pw.FixedColumnWidth(66),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FixedColumnWidth(54),
        4: const pw.FixedColumnWidth(56),
        5: const pw.FixedColumnWidth(50),
        6: const pw.FixedColumnWidth(56),
      },
      children: rows,
    );
  }

  static pw.TableRow _pdfTh(List<String> cols, PdfColor saffron) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: saffron),
      children: cols
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5, vertical: 5),
                child: pw.Text(c,
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ))
          .toList(),
    );
  }

  static pw.TableRow _pdfTr(
    List<String> cells,
    PdfColor bg,
    PdfColor textColor,
    PdfColor lastColor, {
    bool lastBold = false,
    bool allBold = false,
  }) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: cells.asMap().entries.map((e) {
        final isLast = e.key == cells.length - 1;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 5, vertical: 4),
          child: pw.Text(
            e.value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: (isLast && lastBold) || allBold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: isLast ? lastColor : textColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _fmtAmt(double v) => v.toStringAsFixed(2);
  static String _fmtRate(double r) =>
      r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);
  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}
