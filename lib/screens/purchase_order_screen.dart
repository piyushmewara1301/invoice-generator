import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _PoLine {
  final String itemId;
  final String itemName;
  final String? unit;
  final double currentStock;
  final double avgDailyUsage;   // units/day over the analysis window
  final double? daysRemaining;  // null when avgDailyUsage == 0
  final double? costPrice;
  final double? lowStockThreshold;
  double orderQty;

  _PoLine({
    required this.itemId,
    required this.itemName,
    this.unit,
    required this.currentStock,
    required this.avgDailyUsage,
    this.daysRemaining,
    this.costPrice,
    this.lowStockThreshold,
    required this.orderQty,
  });

  bool get isUrgent => daysRemaining != null && daysRemaining! <= 1;
  bool get isWarning => daysRemaining != null && daysRemaining! <= 2;

  String get daysLabel {
    if (avgDailyUsage <= 0) return 'No data';
    final d = daysRemaining!;
    if (d <= 0) return 'OUT OF STOCK';
    if (d < 1) return '< 1 day';
    return '${d.toStringAsFixed(1)} days';
  }

  double get lineTotal => orderQty * (costPrice ?? 0);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  static const int _windowDays   = 30; // velocity look-back
  static const int _bufferDays   = 7;  // how many days of stock to order
  static const int _alertDays    = 3;  // items running out within N days

  final _vendorCtrl  = TextEditingController();
  final _notesCtrl   = TextEditingController();
  DateTime? _deliveryDate;

  List<_PoLine> _lines = [];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildLines());
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Velocity computation ─────────────────────────────────────────────────

  void _buildLines() {
    final provider = context.read<AppProvider>();
    final items    = provider.serviceItems;
    final shopId   = provider.currentShopId;
    final cutoff   = DateTime.now().subtract(const Duration(days: _windowDays));
    final today    = DateTime.now();

    // Build item-id → total-sold map from daily sales
    final Map<String, double> soldById   = {};
    final Map<String, double> soldByName = {};

    for (final sale in provider.dailySales) {
      final saleDate = DateTime(sale.date.year, sale.date.month, sale.date.day);
      if (saleDate.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) {
        continue;
      }
      for (final si in sale.items) {
        if (si.itemId != null) {
          soldById[si.itemId!] = (soldById[si.itemId!] ?? 0) + si.quantity;
        } else {
          final key = si.itemName.toLowerCase().trim();
          soldByName[key] = (soldByName[key] ?? 0) + si.quantity;
        }
      }
    }

    // Also aggregate from invoices (invoice-based mode or dual mode)
    for (final inv in provider.invoices) {
      final d = DateTime(
          inv.invoiceDate.year, inv.invoiceDate.month, inv.invoiceDate.day);
      if (d.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) continue;
      for (final li in inv.items) {
        final key = li.description.toLowerCase().trim();
        soldByName[key] = (soldByName[key] ?? 0) + li.quantity;
      }
    }

    final lines = <_PoLine>[];

    for (final item in items) {
      if (!item.isTrackingStock) continue;

      if (item.hasVariants) {
        for (final v in item.variants) {
          if (!v.isTrackingStock) continue;
          final stock = v.stockFor(shopId);
          final sold  = soldById[v.id] ??
              soldByName[v.name.toLowerCase().trim()] ??
              0.0;
          final daily = sold / _windowDays;
          final days  = daily > 0 ? stock / daily : null;
          final threshold = v.lowStockThreshold ?? item.lowStockThreshold;

          final needsOrder = (days != null && days <= _alertDays) ||
              (threshold != null && stock <= threshold);
          if (!needsOrder) continue;

          final suggested = daily > 0
              ? max(1.0, (daily * _bufferDays - stock).ceilToDouble())
              : max(1.0, ((threshold ?? 10) * 2 - stock).ceilToDouble());

          lines.add(_PoLine(
            itemId: v.id,
            itemName: '${item.name} – ${v.name}',
            unit: item.unit,
            currentStock: stock,
            avgDailyUsage: daily,
            daysRemaining: days,
            costPrice: v.costPrice ?? item.costPrice,
            lowStockThreshold: threshold,
            orderQty: suggested,
          ));
        }
      } else {
        final stock = item.stockFor(shopId);
        final sold  = soldById[item.id] ??
            soldByName[item.name.toLowerCase().trim()] ??
            0.0;
        final daily = sold / _windowDays;
        final days  = daily > 0 ? stock / daily : null;
        final threshold = item.lowStockThreshold;

        final needsOrder = (days != null && days <= _alertDays) ||
            (threshold != null && stock <= threshold);
        if (!needsOrder) continue;

        final suggested = daily > 0
            ? max(1.0, (daily * _bufferDays - stock).ceilToDouble())
            : max(1.0, ((threshold ?? 10) * 2 - stock).ceilToDouble());

        lines.add(_PoLine(
          itemId: item.id,
          itemName: item.name,
          unit: item.unit,
          currentStock: stock,
          avgDailyUsage: daily,
          daysRemaining: days,
          costPrice: item.costPrice,
          lowStockThreshold: threshold,
          orderQty: suggested,
        ));
      }
    }

    // Sort: urgency first (fewer days remaining), then by name
    lines.sort((a, b) {
      final da = a.daysRemaining ?? double.infinity;
      final db = b.daysRemaining ?? double.infinity;
      if ((da - db).abs() > 0.01) return da.compareTo(db);
      return a.itemName.compareTo(b.itemName);
    });

    final now = today;
    _deliveryDate = now.add(const Duration(days: 3));

    setState(() => _lines = lines);
  }

  // ── PDF generation ───────────────────────────────────────────────────────

  Future<void> _export() async {
    if (_lines.isEmpty) return;
    setState(() => _generating = true);
    try {
      final provider = context.read<AppProvider>();
      final poNumber = 'PO-${DateTime.now().year}'
          '${DateTime.now().month.toString().padLeft(2, '0')}'
          '${DateTime.now().day.toString().padLeft(2, '0')}-'
          '${(provider.purchaseBills.length + 1).toString().padLeft(3, '0')}';

      final bytes = await PdfGenerator.generatePurchaseOrderPdf(
        profile: provider.profile,
        lines: _lines
            .where((l) => l.orderQty > 0)
            .map((l) => PurchaseOrderLine(
                  itemName: l.itemName,
                  unit: l.unit,
                  currentStock: l.currentStock,
                  avgDailyUsage: l.avgDailyUsage,
                  daysRemaining: l.daysRemaining,
                  orderQty: l.orderQty,
                  costPrice: l.costPrice,
                ))
            .toList(),
        vendorName: _vendorCtrl.text.trim().isEmpty
            ? null
            : _vendorCtrl.text.trim(),
        poNumber: poNumber,
        deliveryDate: _deliveryDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        windowDays: _windowDays,
      );

      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$poNumber.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Purchase Order $poNumber',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final currency  = provider.profile.currency;
    final sym       = Fmt.currencySymbol(currency);
    final totalCost = _lines.fold(0.0, (s, l) => s + l.lineTotal);
    final hasLines  = _lines.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text('Purchase Order'),
        actions: [
          if (_generating)
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
              onPressed: hasLines ? _export : null,
            ),
        ],
      ),
      body: hasLines ? _buildBody(sym, totalCost) : _buildEmpty(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: AppTheme.subtext(context)),
          const SizedBox(height: 16),
          Text(
            'No items need reordering',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.onCard(context)),
          ),
          const SizedBox(height: 6),
          Text(
            'Items with stock levels below their threshold\nor running out within 3 days will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.subtext(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String sym, double totalCost) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary banner ──────────────────────────────────────────────
        _SummaryBanner(lines: _lines, sym: sym, totalCost: totalCost),
        const SizedBox(height: 16),

        // ── Vendor / PO details ─────────────────────────────────────────
        _DetailsCard(
          vendorCtrl: _vendorCtrl,
          notesCtrl: _notesCtrl,
          deliveryDate: _deliveryDate,
          onDeliveryDateChanged: (d) => setState(() => _deliveryDate = d),
        ),
        const SizedBox(height: 16),

        // ── Items ───────────────────────────────────────────────────────
        Text(
          'ITEMS TO ORDER',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.subtext(context)),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline(context), width: 0.6),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lines.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppTheme.outline(context)),
            itemBuilder: (ctx, i) => _LineRow(
              line: _lines[i],
              sym: sym,
              onQtyChanged: (v) => setState(() => _lines[i].orderQty = v),
            ),
          ),
        ),

        if (totalCost > 0) ...[
          const SizedBox(height: 12),
          _TotalBar(sym: sym, total: totalCost),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Summary banner ───────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final List<_PoLine> lines;
  final String sym;
  final double totalCost;

  const _SummaryBanner(
      {required this.lines, required this.sym, required this.totalCost});

  @override
  Widget build(BuildContext context) {
    final urgent  = lines.where((l) => l.isUrgent).length;
    final warning = lines.where((l) => !l.isUrgent && l.isWarning).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context), width: 0.6),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Items',
            value: '${lines.length}',
            color: AppTheme.primary,
          ),
          const SizedBox(width: 16),
          _Stat(
            label: '≤ 1 day',
            value: '$urgent',
            color: urgent > 0 ? AppTheme.error : AppTheme.subtext(context),
          ),
          const SizedBox(width: 16),
          _Stat(
            label: '≤ 2 days',
            value: '$warning',
            color: warning > 0
                ? const Color(0xFFEA580C)
                : AppTheme.subtext(context),
          ),
          const Spacer(),
          if (totalCost > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Est. Cost',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.subtext(context)),
                ),
                Text(
                  '$sym${Fmt.compact(totalCost)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onCard(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: AppTheme.subtext(context))),
      ],
    );
  }
}

// ─── Vendor / PO details card ─────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final TextEditingController vendorCtrl;
  final TextEditingController notesCtrl;
  final DateTime? deliveryDate;
  final ValueChanged<DateTime> onDeliveryDateChanged;

  const _DetailsCard({
    required this.vendorCtrl,
    required this.notesCtrl,
    required this.deliveryDate,
    required this.onDeliveryDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER DETAILS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.subtext(context)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: vendorCtrl,
            decoration: InputDecoration(
              labelText: 'Vendor / Supplier name (optional)',
              prefixIcon: const Icon(Icons.store_outlined, size: 18),
              isDense: true,
              filled: true,
              fillColor: AppTheme.inputFill(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: deliveryDate ?? now.add(const Duration(days: 3)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: AppTheme.primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) onDeliveryDateChanged(picked);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.inputFill(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      deliveryDate != null
                          ? 'Expected delivery: ${Fmt.date(deliveryDate!)}'
                          : 'Expected delivery date (optional)',
                      style: TextStyle(
                          fontSize: 14,
                          color: deliveryDate != null
                              ? AppTheme.onCard(context)
                              : AppTheme.subtext(context)),
                    ),
                  ),
                  Icon(Icons.calendar_today_outlined,
                      size: 15, color: AppTheme.subtext(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: const Icon(Icons.notes_outlined, size: 18),
              isDense: true,
              filled: true,
              fillColor: AppTheme.inputFill(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Line item row ────────────────────────────────────────────────────────────

class _LineRow extends StatefulWidget {
  final _PoLine line;
  final String sym;
  final ValueChanged<double> onQtyChanged;

  const _LineRow(
      {required this.line, required this.sym, required this.onQtyChanged});

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.line.orderQty
            .toStringAsFixed(widget.line.orderQty % 1 == 0 ? 0 : 1));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Color get _urgencyColor {
    if (widget.line.isUrgent) return AppTheme.error;
    if (widget.line.isWarning) return const Color(0xFFEA580C);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgency indicator bar
          Container(
            width: 3,
            height: 52,
            decoration: BoxDecoration(
              color: _urgencyColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Item name + velocity info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.itemName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _Badge(
                      label: 'Stock: ${_qty(l.currentStock)}${l.unit != null ? ' ${l.unit}' : ''}',
                      color: AppTheme.subtext(context),
                    ),
                    if (l.avgDailyUsage > 0)
                      _Badge(
                        label: '${l.avgDailyUsage.toStringAsFixed(1)}/day',
                        color: AppTheme.primary,
                      ),
                    _Badge(
                      label: l.daysLabel,
                      color: _urgencyColor,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Order quantity editor
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () {
                        final v = (l.orderQty - 1).clamp(0.0, double.infinity);
                        widget.onQtyChanged(v);
                        _qtyCtrl.text =
                            v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
                      },
                    ),
                    SizedBox(
                      width: 42,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          border: InputBorder.none,
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v);
                          if (parsed != null && parsed >= 0) {
                            widget.onQtyChanged(parsed);
                          }
                        },
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () {
                        final v = l.orderQty + 1;
                        widget.onQtyChanged(v);
                        _qtyCtrl.text =
                            v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
                      },
                    ),
                  ],
                ),
                if (l.costPrice != null && l.costPrice! > 0)
                  Text(
                    '${widget.sym}${Fmt.compact(l.lineTotal)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.subtext(context)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _qty(double v) =>
      v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: AppTheme.primary),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool bold;
  const _Badge({required this.label, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color),
      ),
    );
  }
}

// ─── Total bar ────────────────────────────────────────────────────────────────

class _TotalBar extends StatelessWidget {
  final String sym;
  final double total;
  const _TotalBar({required this.sym, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        children: [
          Text(
            'Estimated total',
            style: TextStyle(
                fontSize: 13, color: AppTheme.subtext(context)),
          ),
          const Spacer(),
          Text(
            '$sym${Fmt.currency(total)}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
