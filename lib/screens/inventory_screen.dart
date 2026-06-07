import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_item.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/feature_guide_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.inventory);
    });
  }

  // ── Quick stock adjustment sheet ─────────────────────────────────────────────
  void _showAdjustSheet(BuildContext context, AppProvider provider,
      ServiceItem item) {
    final ctrl = TextEditingController(
        text: item.quantityOnHand?.toStringAsFixed(
            item.quantityOnHand! % 1 == 0 ? 0 : 2) ??
            '0');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outline(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(item.name,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(ctx))),
            SizedBox(height: 4),
            Text('Adjust quantity on hand',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.subtext(ctx))),
            const SizedBox(height: 20),
            Row(
              children: [
                // Decrement
                _AdjustButton(
                  icon: Icons.remove,
                  onTap: () {
                    final v = double.tryParse(ctrl.text) ?? 0;
                    ctrl.text = (v - 1).clamp(0, double.infinity)
                        .toStringAsFixed(v % 1 == 0 ? 0 : 2);
                  },
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Quantity on Hand',
                      suffix: item.unit != null
                          ? Text(item.unit!,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.subtext(ctx)))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Increment
                _AdjustButton(
                  icon: Icons.add,
                  onTap: () {
                    final v = double.tryParse(ctrl.text) ?? 0;
                    ctrl.text = (v + 1)
                        .toStringAsFixed(v % 1 == 0 ? 0 : 2);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final newQty = double.tryParse(ctrl.text);
                  if (newQty == null) return;
                  final updated = ServiceItem(
                    id: item.id,
                    name: item.name,
                    description: item.description,
                    rate: item.rate,
                    taxPercent: item.taxPercent,
                    unit: item.unit,
                    hsnSac: item.hsnSac,
                    category: item.category,
                    quantityOnHand: newQty,
                    lowStockThreshold: item.lowStockThreshold,
                  );
                  provider.updateServiceItem(updated);
                  Navigator.pop(ctx);
                },
                child: const Text('Save',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allTracked = provider.profile.serviceItems
        .where((s) => s.isTrackingStock)
        .toList();

    // Sort: low-stock first, then alphabetical
    allTracked.sort((a, b) {
      if (a.isLowStock && !b.isLowStock) return -1;
      if (!a.isLowStock && b.isLowStock) return 1;
      return a.name.compareTo(b.name);
    });

    final items = _search.isEmpty
        ? allTracked
        : allTracked
            .where((s) =>
                s.name.toLowerCase().contains(_search.toLowerCase()) ||
                (s.category?.toLowerCase().contains(_search.toLowerCase()) ??
                    false))
            .toList();

    final lowStockCount = allTracked.where((s) => s.isLowStock).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          // ── Summary banner ───────────────────────────────────────────────────
          if (allTracked.isNotEmpty)
            Container(
              color: AppTheme.card(context),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _SummaryChip(
                    label: 'Tracked',
                    value: '${allTracked.length}',
                    color: AppTheme.primary,
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    label: 'Low Stock',
                    value: '$lowStockCount',
                    color: lowStockCount > 0
                        ? AppTheme.error
                        : AppTheme.success,
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ),
            ),

          // ── Search bar ───────────────────────────────────────────────────────
          if (allTracked.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search items…',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppTheme.subtext(context)),
                  filled: true,
                  fillColor: AppTheme.inputFill(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

          // ── Item list ────────────────────────────────────────────────────────
          Expanded(
            child: allTracked.isEmpty
                ? _EmptyState()
                : items.isEmpty
                    ? Center(
                        child: Text('No items match your search.',
                            style: TextStyle(
                                color: AppTheme.subtext(context),
                                fontSize: 14)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          return _InventoryCard(
                            item: item,
                            onAdjust: () => _showAdjustSheet(
                                context, provider, item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Inventory card ────────────────────────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  final ServiceItem item;
  final VoidCallback onAdjust;

  const _InventoryCard({required this.item, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final qty = item.quantityOnHand!;
    final isLow = item.isLowStock;
    final qtyLabel =
        qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
    final unit = item.unit ?? 'units';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: isLow
            ? Border.all(color: AppTheme.error.withValues(alpha: 0.35))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isLow ? AppTheme.error : AppTheme.primary)
                  .withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLow
                  ? Icons.warning_amber_rounded
                  : Icons.inventory_2_outlined,
              size: 22,
              color: isLow ? AppTheme.error : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          // Name + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.category?.isNotEmpty == true) ...[
                  SizedBox(height: 2),
                  Text(item.category!,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context))),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Qty chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isLow ? AppTheme.error : AppTheme.primary)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$qtyLabel $unit',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLow
                                ? AppTheme.error
                                : AppTheme.primary),
                      ),
                    ),
                    if (isLow) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Low Stock',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.error),
                        ),
                      ),
                    ],
                    if (item.lowStockThreshold != null) ...[
                      SizedBox(width: 6),
                      Text(
                        'Alert ≤ ${item.lowStockThreshold!.toStringAsFixed(item.lowStockThreshold! % 1 == 0 ? 0 : 1)}',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.subtext(context)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Adjust button
          GestureDetector(
            onTap: onAdjust,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Adjust',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Adjust +/- button ─────────────────────────────────────────────────────────

class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AdjustButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 22),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 40,
                  color: AppTheme.primary.withValues(alpha: 0.6)),
            ),
            SizedBox(height: 20),
            Text('No items tracked',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(context)),
                textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text(
              'Enable "Track Stock" on any item in\nSettings → Services & Items.',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.subtext(context),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
