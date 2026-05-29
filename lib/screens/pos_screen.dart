import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../models/business_profile.dart';
import '../models/client.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'client_picker_screen.dart';

// ─── Cart entry ───────────────────────────────────────────────────────────────

class _CartEntry {
  final ServiceItem item;
  int qty;
  _CartEntry(this.item, this.qty);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  // cart: itemId → qty
  final Map<String, int> _cart = {};
  String? _selectedCategory; // null = All
  bool _searchMode = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<String> _categories(List<ServiceItem> items) {
    final cats = <String>{};
    for (final i in items) {
      if (i.category != null && i.category!.isNotEmpty) cats.add(i.category!);
    }
    return cats.toList()..sort();
  }

  List<ServiceItem> _filtered(List<ServiceItem> all) {
    var list = all;
    if (_selectedCategory != null) {
      list = list.where((i) => i.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              (i.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int get _totalCount => _cart.values.fold(0, (a, b) => a + b);

  double _cartTotal(List<ServiceItem> all) {
    double t = 0;
    for (final e in _cart.entries) {
      final idx = all.indexWhere((i) => i.id == e.key);
      if (idx == -1) continue;
      final item = all[idx];
      final taxable = item.rate;
      final tax = taxable * (item.taxPercent / 100);
      t += (taxable + tax) * e.value;
    }
    return t;
  }

  List<_CartEntry> _cartEntries(List<ServiceItem> all) => _cart.entries
      .map((e) {
        final idx = all.indexWhere((i) => i.id == e.key);
        if (idx == -1) return null;
        return _CartEntry(all[idx], e.value);
      })
      .whereType<_CartEntry>()
      .toList();

  void _add(String id) {
    HapticFeedback.lightImpact();
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
  }

  void _decrement(String id) {
    setState(() {
      final c = _cart[id] ?? 0;
      if (c <= 1) {
        _cart.remove(id);
      } else {
        _cart[id] = c - 1;
      }
    });
  }

  void _clearCart() => setState(_cart.clear);

  // ── Cart sheet ───────────────────────────────────────────────────────────────

  void _openCart() {
    final appProvider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CartSheet(
        entries: _cartEntries(appProvider.profile.serviceItems),
        currency: appProvider.profile.currency,
        onIncrement: (id) {
          _add(id);
          Navigator.pop(ctx);
          Future.microtask(_openCart);
        },
        onDecrement: (id) {
          _decrement(id);
          if (_cart.isEmpty) {
            Navigator.pop(ctx);
          } else {
            Navigator.pop(ctx);
            Future.microtask(_openCart);
          }
        },
        onClear: () {
          _clearCart();
          Navigator.pop(ctx);
        },
        onCharge: () {
          Navigator.pop(ctx);
          Future.microtask(_openCharge);
        },
      ),
    );
  }

  // ── Charge sheet ──────────────────────────────────────────────────────────────

  void _openCharge() {
    final appProvider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChargeSheet(
        entries: _cartEntries(appProvider.profile.serviceItems),
        profile: appProvider.profile,
        onConfirm: (client, pmId, pmName, saveAsDraft) async {
          Navigator.pop(ctx);
          await _createInvoice(client, pmId, pmName, saveAsDraft);
        },
      ),
    );
  }

  Future<void> _createInvoice(
    Client? client,
    String? pmId,
    String? pmName,
    bool saveAsDraft,
  ) async {
    final appProvider = context.read<AppProvider>();
    final profile = appProvider.profile;
    final allItems = profile.serviceItems;

    final lineItems = _cart.entries.map((e) {
      final item = allItems.firstWhere((i) => i.id == e.key);
      return LineItem(
        description: item.name,
        quantity: e.value.toDouble(),
        rate: item.rate,
        taxPercent: item.taxPercent,
        unit: item.unit ?? 'pcs',
        hsnSac: item.hsnSac,
        category: item.category,
      );
    }).toList();

    final now = DateTime.now();
    final invoice = Invoice(
      id: const Uuid().v4(),
      invoiceNumber:
          '${profile.invoicePrefix}${profile.nextInvoiceNumber}',
      client: client,
      invoiceDate: now,
      dueDate: now,
      items: lineItems,
      status: saveAsDraft ? InvoiceStatus.draft : InvoiceStatus.paid,
      currency: profile.currency,
      paymentMethodId: pmId,
      paymentMethodName: pmName,
    );

    await appProvider.saveInvoice(invoice);

    if (mounted) {
      _clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saveAsDraft
              ? 'Invoice ${invoice.invoiceNumber} saved as draft'
              : 'Invoice ${invoice.invoiceNumber} charged & saved'),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              saveAsDraft ? AppTheme.textSecondary : AppTheme.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final profile = appProvider.profile;
    final allItems = profile.serviceItems;
    final categories = _categories(allItems);
    final filtered = _filtered(allItems);
    final sym = Fmt.currencySymbol(profile.currency);
    final total = _cartTotal(allItems);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: _searchMode
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search items…',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Point of Sale'),
        actions: [
          if (!_searchMode)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
              onPressed: () => setState(() => _searchMode = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _searchMode = false;
                _searchCtrl.clear();
                _searchQuery = '';
              }),
            ),
          if (!_searchMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    tooltip: 'Cart',
                    onPressed: _totalCount > 0 ? _openCart : null,
                  ),
                  if (_totalCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _totalCount > 9 ? '9+' : '$_totalCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      body: allItems.isEmpty
          ? const _EmptyCatalog()
          : Column(
              children: [
                if (categories.isNotEmpty)
                  _CategoryBar(
                    categories: categories,
                    selected: _selectedCategory,
                    onSelect: (c) =>
                        setState(() => _selectedCategory = c),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No items found',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15),
                          ),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                              12, 12, 12, _totalCount > 0 ? 96 : 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.05,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final item = filtered[i];
                            final qty = _cart[item.id] ?? 0;
                            return _ItemCard(
                              item: item,
                              qty: qty,
                              sym: sym,
                              onTap: () => _add(item.id),
                              onDecrement: qty > 0
                                  ? () => _decrement(item.id)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _totalCount > 0
          ? _CartBar(
              count: _totalCount,
              total: total,
              sym: sym,
              onTap: _openCart,
            )
          : null,
    );
  }
}

// ─── Category bar ─────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final void Function(String?) onSelect;

  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _chip('All', null, selected, onSelect),
            ...categories.map((c) => _chip(c, c, selected, onSelect)),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    String label,
    String? value,
    String? selected,
    void Function(String?) onSelect,
  ) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected ? AppTheme.primary : AppTheme.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
              color:
                  isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Item card ────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final ServiceItem item;
  final int qty;
  final String sym;
  final VoidCallback onTap;
  final VoidCallback? onDecrement;

  const _ItemCard({
    required this.item,
    required this.qty,
    required this.sym,
    required this.onTap,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = qty > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCart
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.divider,
            width: inCart ? 1.5 : 1,
          ),
          boxShadow: inCart
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : AppTheme.cardShadow,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category tag
                  if (item.category != null && item.category!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Name
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$sym${_fmt(item.rate)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: inCart
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            if (item.taxPercent > 0)
                              Text(
                                '+${item.taxPercent.toStringAsFixed(0)}% tax',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Qty controls when in cart
                      if (inCart)
                        _QtyControl(
                          qty: qty,
                          onAdd: onTap,
                          onRemove: onDecrement!,
                        )
                      else
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // In-cart badge
            if (inCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$qty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ─── Qty control ─────────────────────────────────────────────────────────────

class _QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QtyControl({
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onRemove,
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8)),
            child: const SizedBox(
              width: 26,
              height: 28,
              child: Icon(Icons.remove_rounded,
                  size: 14, color: AppTheme.primary),
            ),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          InkWell(
            onTap: onAdd,
            borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8)),
            child: const SizedBox(
              width: 26,
              height: 28,
              child: Icon(Icons.add_rounded,
                  size: 14, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cart bar (bottom sticky) ─────────────────────────────────────────────────

class _CartBar extends StatelessWidget {
  final int count;
  final double total;
  final String sym;
  final VoidCallback onTap;

  const _CartBar({
    required this.count,
    required this.total,
    required this.sym,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count ${count == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'View Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$sym${_fmt(total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

// ─── Cart sheet ───────────────────────────────────────────────────────────────

class _CartSheet extends StatelessWidget {
  final List<_CartEntry> entries;
  final String currency;
  final void Function(String id) onIncrement;
  final void Function(String id) onDecrement;
  final VoidCallback onClear;
  final VoidCallback onCharge;

  const _CartSheet({
    required this.entries,
    required this.currency,
    required this.onIncrement,
    required this.onDecrement,
    required this.onClear,
    required this.onCharge,
  });

  double get _subtotal =>
      entries.fold(0, (s, e) => s + e.item.rate * e.qty);
  double get _tax => entries.fold(
      0, (s, e) => s + e.item.rate * (e.item.taxPercent / 100) * e.qty);
  double get _total => _subtotal + _tax;

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(currency);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded,
                    size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Cart (${entries.length} ${entries.length == 1 ? 'item' : 'items'})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: AppTheme.error),
                  label: const Text('Clear',
                      style: TextStyle(
                          color: AppTheme.error, fontSize: 13)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Items (capped height so sheet doesn't overflow)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              separatorBuilder: (_, x) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) {
                final e = entries[i];
                final lineTotal =
                    e.item.rate * (1 + e.item.taxPercent / 100) * e.qty;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                )),
                            const SizedBox(height: 2),
                            Text(
                              '$sym${_fmtVal(e.item.rate)} × ${e.qty}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _QtyControl(
                        qty: e.qty,
                        onAdd: () => onIncrement(e.item.id),
                        onRemove: () => onDecrement(e.item.id),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '$sym${_fmtVal(lineTotal)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Totals
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _TotalRow(label: 'Subtotal', value: '$sym${_fmtVal(_subtotal)}'),
                if (_tax > 0) ...[
                  const SizedBox(height: 4),
                  _TotalRow(
                      label: 'Tax', value: '$sym${_fmtVal(_tax)}'),
                ],
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _TotalRow(
                  label: 'Total',
                  value: '$sym${_fmtVal(_total)}',
                  bold: true,
                ),
              ],
            ),
          ),
          // Charge button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onCharge,
                icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                label: Text(
                  'Charge  $sym${_fmtVal(_total)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtVal(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ─── Total row ────────────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: bold ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Charge sheet ─────────────────────────────────────────────────────────────

class _ChargeSheet extends StatefulWidget {
  final List<_CartEntry> entries;
  final BusinessProfile profile;
  final Future<void> Function(
      Client? client, String? pmId, String? pmName, bool saveAsDraft) onConfirm;

  const _ChargeSheet({
    required this.entries,
    required this.profile,
    required this.onConfirm,
  });

  @override
  State<_ChargeSheet> createState() => _ChargeSheetState();
}

class _ChargeSheetState extends State<_ChargeSheet> {
  Client? _client;
  PaymentMethod? _selectedMethod;
  bool _charging = false;

  double get _subtotal =>
      widget.entries.fold(0, (s, e) => s + e.item.rate * e.qty);
  double get _tax => widget.entries.fold(
      0, (s, e) => s + e.item.rate * (e.item.taxPercent / 100) * e.qty);
  double get _total => _subtotal + _tax;

  @override
  void initState() {
    super.initState();
    // Default to Cash
    final methods = widget.profile.allPaymentMethods;
    _selectedMethod = methods.isNotEmpty ? methods.first : null;
  }

  Future<void> _pickClient() async {
    final picked = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const ClientPickerScreen()),
    );
    if (picked != null) setState(() => _client = picked);
  }

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(widget.profile.currency);
    final methods = widget.profile.allPaymentMethods;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Confirm Charge',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // Order summary line
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                '${widget.entries.fold(0, (s, e) => s + e.qty)} item(s)  ·  $sym${_fmtVal(_total)}',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Client selector
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                'Customer',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: _pickClient,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _client != null
                            ? Icons.person_rounded
                            : Icons.person_add_alt_1_outlined,
                        size: 18,
                        color: _client != null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _client?.name ?? 'Walk-in Customer',
                          style: TextStyle(
                            fontSize: 14,
                            color: _client != null
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontWeight: _client != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (_client != null)
                        GestureDetector(
                          onTap: () => setState(() => _client = null),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: AppTheme.textSecondary),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ),

            // Payment method
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(
                'Payment Method',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.4),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: methods.map((m) {
                  final isSelected = _selectedMethod?.id == m.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedMethod = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.divider,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _methodIcon(m.type),
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              m.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Total
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  Text(
                    '$sym${_fmtVal(_total)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _charging
                      ? null
                      : () async {
                          setState(() => _charging = true);
                          await widget.onConfirm(
                            _client,
                            _selectedMethod?.id,
                            _selectedMethod?.name,
                            false,
                          );
                        },
                  icon: _charging
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded,
                          size: 20),
                  label: Text(
                    _charging ? 'Processing…' : 'Charge & Save Invoice',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: _charging
                      ? null
                      : () async {
                          setState(() => _charging = true);
                          await widget.onConfirm(
                              _client, null, null, true);
                        },
                  child: const Text('Save as Draft',
                      style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _methodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return Icons.payments_outlined;
      case PaymentMethodType.upi:
        return Icons.qr_code_rounded;
      case PaymentMethodType.bankAccount:
        return Icons.account_balance_outlined;
      case PaymentMethodType.other:
        return Icons.more_horiz_rounded;
    }
  }

  String _fmtVal(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No items in catalog',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add products or services in Settings → Items & Services to start using POS.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
