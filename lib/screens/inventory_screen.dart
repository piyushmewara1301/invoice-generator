import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_item.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/feature_guide_sheet.dart';
import 'purchase_order_screen.dart';
import 'receive_stock_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';
  String? _shopFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.inventory);
    });
  }

  static String _fmtQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);

  // ── Quick stock adjustment sheet ─────────────────────────────────────────────
  void _showAdjustSheet(BuildContext context, AppProvider provider,
      ServiceItem item) {
    final shops = provider.allShops;
    String shopId = _shopFilter ?? provider.currentShopId ?? shops.first.shopId;
    final ctrl = TextEditingController(text: _fmtQty(item.stockFor(shopId)));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
            if (shops.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: shopId,
                decoration: const InputDecoration(labelText: 'Shop'),
                items: shops
                    .map((s) => DropdownMenuItem(
                          value: s.shopId,
                          child: Text(s.shopName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setSheetState(() {
                    shopId = v;
                    ctrl.text = _fmtQty(item.stockFor(shopId));
                  });
                },
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                // Decrement
                _AdjustButton(
                  icon: Icons.remove,
                  onTap: () {
                    final v = double.tryParse(ctrl.text) ?? 0;
                    setSheetState(() {
                      ctrl.text = (v - 1)
                          .clamp(0, double.infinity)
                          .toStringAsFixed(v % 1 == 0 ? 0 : 2);
                    });
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
                    setSheetState(() {
                      ctrl.text = (v + 1).toStringAsFixed(v % 1 == 0 ? 0 : 2);
                    });
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
                  provider.updateItemStock(item.id, newQty, shopId: shopId);
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
      ),
    ).whenComplete(
      () => WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final shops = provider.allShops;
    final allTracked = provider.serviceItems
        .where((s) => s.isTrackingStock)
        .toList();

    // Sort: low-stock first, then alphabetical
    allTracked.sort((a, b) {
      final aLow = a.isLowStockFor(_shopFilter);
      final bLow = b.isLowStockFor(_shopFilter);
      if (aLow && !bLow) return -1;
      if (!aLow && bLow) return 1;
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

    final lowStockCount =
        allTracked.where((s) => s.isLowStockFor(_shopFilter)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.move_to_inbox_outlined),
            tooltip: 'Receive Stock',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ReceiveStockScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Purchase Order',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PurchaseOrderScreen()),
            ),
          ),
        ],
      ),
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

          // ── Shop filter ──────────────────────────────────────────────────────
          if (allTracked.isNotEmpty && shops.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ShopFilterChip(
                      label: 'All Shops',
                      selected: _shopFilter == null,
                      onTap: () => setState(() => _shopFilter = null),
                    ),
                    for (final shop in shops) ...[
                      const SizedBox(width: 8),
                      _ShopFilterChip(
                        label: shop.shopName,
                        selected: _shopFilter == shop.shopId,
                        onTap: () =>
                            setState(() => _shopFilter = shop.shopId),
                      ),
                    ],
                  ],
                ),
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
                            shopFilter: _shopFilter,
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
  final String? shopFilter;
  final VoidCallback onAdjust;

  const _InventoryCard(
      {required this.item, required this.shopFilter, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final isLow = item.isLowStockFor(shopFilter);
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              item.hasVariants
                  ? Icons.layers_outlined
                  : isLow
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
              size: 22,
              color: isLow ? AppTheme.error : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          // Name + stock info
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
                if (item.hasVariants)
                  // Per-variant chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.variants
                        .where((v) => v.isTrackingStock)
                        .map((v) {
                      final vLow = v.isLowStockFor(shopFilter);
                      final qLabel = _InventoryScreenState._fmtQty(
                          v.stockFor(shopFilter));
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (vLow ? AppTheme.error : AppTheme.primary)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: vLow
                              ? Border.all(
                                  color: AppTheme.error.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: Text(
                          '${v.name}: $qLabel $unit${vLow ? ' ⚠' : ''}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: vLow ? AppTheme.error : AppTheme.primary),
                        ),
                      );
                    }).toList(),
                  )
                else ...[
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
                          '${_InventoryScreenState._fmtQty(item.stockFor(shopFilter))} $unit',
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
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Adjust button — only for flat-stock items
          if (!item.hasVariants)
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

// ── Shop filter chip ──────────────────────────────────────────────────────────

class _ShopFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShopFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.primary,
          ),
        ),
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
