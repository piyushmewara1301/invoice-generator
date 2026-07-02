import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import 'barcode_scanner_screen.dart';

/// Lets the user search for a product (or variant) and enter the quantity
/// that just arrived from a supplier — the entered quantity is added on top
/// of the current stock on hand.
class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  String _search = '';
  String? _shopId;
  final Map<String, TextEditingController> _qtyCtrls = {};

  // Tracks how much has been added to each row during this screen session,
  // so the user can see "old stock + added = new total" as a running tally.
  final Map<String, _StockChange> _changes = {};

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(String key) =>
      _qtyCtrls.putIfAbsent(key, () => TextEditingController());

  static String _fmtQty(double q) =>
      q % 1 == 0 ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  Future<void> _scan() async {
    final barcode = await scanBarcode(context, title: 'Scan Item');
    if (!mounted || barcode == null) return;
    setState(() => _search = barcode);
  }

  Future<void> _receive(_StockRow row, String shopId) async {
    final ctrl = _ctrlFor(row.key);
    final qty = double.tryParse(ctrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a quantity greater than 0'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    final provider = context.read<AppProvider>();
    await provider.receiveStock(row.itemId, qty,
        variantId: row.variantId, shopId: shopId);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ctrl.clear();
    final existing = _changes[row.key];
    setState(() {
      _changes[row.key] = _StockChange(
        original: existing?.original ?? row.currentStock,
        added: (existing?.added ?? 0) + qty,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Added ${_fmtQty(qty)} ${row.unit} to ${row.displayLabel}. '
          'New stock: ${_fmtQty(row.currentStock + qty)} ${row.unit}'),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Lets the user correct the quantity *they added* during this session —
  /// not the stock-on-hand value directly, so users can fix a mistaken entry
  /// without being able to arbitrarily override stock levels.
  Future<void> _editAdded(_StockRow row, String shopId) async {
    final change = _changes[row.key];
    if (change == null) return;
    final ctrl = TextEditingController(text: _fmtQty(change.added));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Added Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.displayLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.deny('-')],
              decoration: InputDecoration(
                labelText: 'Added quantity',
                suffixText: row.unit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Dispose after the dialog's exit animation finishes — the TextField is
    // still attached to the controller while it's animating away, so an
    // immediate dispose() throws "used after being disposed".
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result == null || result < 0 || !mounted) return;

    final provider = context.read<AppProvider>();
    final newStock = (change.original + result).clamp(0, double.infinity);
    await provider.updateItemStock(row.itemId, newStock.toDouble(),
        variantId: row.variantId, shopId: shopId);
    if (!mounted) return;
    setState(() {
      if (result == 0) {
        _changes.remove(row.key);
      } else {
        _changes[row.key] = _StockChange(original: change.original, added: result);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added quantity for ${row.displayLabel} corrected to '
          '${_fmtQty(result)} ${row.unit}. New stock: ${_fmtQty(newStock.toDouble())} ${row.unit}'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final shops = provider.allShops;
    final shopId = _shopId ??
        provider.currentShopId ??
        (shops.isNotEmpty ? shops.first.shopId : null);

    final allGroups = <_ProductGroup>[];
    for (final item in provider.serviceItems) {
      if (item.hasVariants) {
        final variantRows = item.variants
            .where((v) => v.isTrackingStock)
            .map((v) => _StockRow(
                  key: '${item.id}:${v.id}',
                  itemId: item.id,
                  variantId: v.id,
                  itemName: item.name,
                  variantName: v.name,
                  category: item.category,
                  unit: item.unit ?? 'units',
                  barcode: v.barcode ?? item.barcode,
                  currentStock: v.stockFor(shopId),
                ))
            .toList();
        if (variantRows.isNotEmpty) {
          allGroups.add(_ProductGroup(
            itemId: item.id,
            itemName: item.name,
            category: item.category,
            rows: variantRows,
          ));
        }
      } else if (item.isTrackingStock) {
        allGroups.add(_ProductGroup(
          itemId: item.id,
          itemName: item.name,
          category: item.category,
          rows: [
            _StockRow(
              key: item.id,
              itemId: item.id,
              variantId: null,
              itemName: item.name,
              variantName: null,
              category: item.category,
              unit: item.unit ?? 'units',
              barcode: item.barcode,
              currentStock: item.stockFor(shopId),
            ),
          ],
        ));
      }
    }
    allGroups.sort((a, b) => a.itemName.compareTo(b.itemName));

    final query = _search.trim().toLowerCase();
    final List<_ProductGroup> groups;
    if (query.isEmpty) {
      groups = allGroups;
    } else {
      groups = [];
      for (final g in allGroups) {
        final headerMatches = g.itemName.toLowerCase().contains(query) ||
            (g.category?.toLowerCase().contains(query) ?? false);
        if (headerMatches) {
          groups.add(g);
          continue;
        }
        final matchingRows = g.rows
            .where((r) =>
                (r.variantName?.toLowerCase().contains(query) ?? false) ||
                (r.barcode?.toLowerCase() == query))
            .toList();
        if (matchingRows.isNotEmpty) {
          groups.add(_ProductGroup(
            itemId: g.itemId,
            itemName: g.itemName,
            category: g.category,
            rows: matchingRows,
          ));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Stock')),
      body: Column(
        children: [
          if (shops.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: shopId,
                decoration: const InputDecoration(labelText: 'Shop'),
                items: shops
                    .map((s) => DropdownMenuItem(
                          value: s.shopId,
                          child: Text(s.shopName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _shopId = v),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search items or scan barcode…',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: AppTheme.subtext(context)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan barcode',
                  onPressed: _scan,
                ),
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
          Expanded(
            child: allGroups.isEmpty
                ? Center(
                    child: Text('No stock-tracked items yet.',
                        style: TextStyle(
                            color: AppTheme.subtext(context), fontSize: 14)))
                : groups.isEmpty
                    ? Center(
                        child: Text('No items match your search.',
                            style: TextStyle(
                                color: AppTheme.subtext(context),
                                fontSize: 14)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: groups.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final group = groups[i];
                          return _ReceiveProductCard(
                            group: group,
                            qtyCtrlFor: _ctrlFor,
                            changeFor: (key) => _changes[key],
                            onAdd: shopId == null
                                ? null
                                : (row) => _receive(row, shopId),
                            onEditAdded: shopId == null
                                ? null
                                : (row) => _editAdded(row, shopId),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StockRow {
  final String key;
  final String itemId;
  final String? variantId;
  final String itemName;
  final String? variantName;
  final String? category;
  final String unit;
  final String? barcode;
  final double currentStock;

  _StockRow({
    required this.key,
    required this.itemId,
    this.variantId,
    required this.itemName,
    this.variantName,
    this.category,
    required this.unit,
    this.barcode,
    required this.currentStock,
  });

  String get displayLabel =>
      variantName != null ? '$itemName ($variantName)' : itemName;
}

/// A product and all of its stock-tracked rows (its variants, or itself if
/// it has none) — rendered as a single card.
class _ProductGroup {
  final String itemId;
  final String itemName;
  final String? category;
  final List<_StockRow> rows;

  _ProductGroup({
    required this.itemId,
    required this.itemName,
    this.category,
    required this.rows,
  });
}

/// Tracks how much stock has been added to a row during this screen
/// session, so the user can see "old + added = new total".
class _StockChange {
  final double original;
  final double added;

  const _StockChange({required this.original, required this.added});
}

class _ReceiveProductCard extends StatelessWidget {
  final _ProductGroup group;
  final TextEditingController Function(String key) qtyCtrlFor;
  final _StockChange? Function(String key) changeFor;
  final void Function(_StockRow row)? onAdd;
  final void Function(_StockRow row)? onEditAdded;

  const _ReceiveProductCard({
    required this.group,
    required this.qtyCtrlFor,
    required this.changeFor,
    required this.onAdd,
    required this.onEditAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.itemName,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (group.category?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(group.category!,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.subtext(context))),
          ],
          for (var i = 0; i < group.rows.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 10),
            _buildRow(context, group.rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, _StockRow row) {
    final change = changeFor(row.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (row.variantName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              row.variantName!,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Current stock: ${_ReceiveStockScreenState._fmtQty(row.currentStock)} ${row.unit}',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary),
        ),
        if (change != null && change.added > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${_ReceiveStockScreenState._fmtQty(change.original)} + '
                '${_ReceiveStockScreenState._fmtQty(change.added)} added = '
                '${_ReceiveStockScreenState._fmtQty(row.currentStock)} ${row.unit}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtext(context)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEditAdded == null ? null : () => onEditAdded!(row),
                child: Icon(Icons.edit_outlined,
                    size: 13, color: AppTheme.subtext(context)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: qtyCtrlFor(row.key),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.deny('-')],
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Qty Received',
                  suffixText: row.unit,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onAdd == null ? null : () => onAdd!(row),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
