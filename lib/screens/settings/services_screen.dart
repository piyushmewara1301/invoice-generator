import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_profile.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/paywall_sheet.dart';
import '../barcode_scanner_screen.dart';
import '../import_inventory_screen.dart';

// ─── Palette for category colour dots ────────────────────────────────────────
const _kCategoryColors = [
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFD97706),
  Color(0xFFDC2626),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
  Color(0xFF65A30D),
];

Color _catColor(String category, List<String> allCats) {
  final i = allCats.indexOf(category);
  return i < 0
      ? AppTheme.textSecondary
      : _kCategoryColors[i % _kCategoryColors.length];
}

const _kUncategorized = 'Uncategorized';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, this.initialSearch});

  /// Pre-fills the search box — used to deep-link here (e.g. from the Data
  /// Health screen) directly to a specific item.
  final String? initialSearch;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _itemLabel = 'Item';
  bool _initialized = false;
  String _search = '';
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _search = widget.initialSearch ?? '';
    _searchCtrl = TextEditingController(text: _search);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Which category sections are expanded (all expanded by default for
  // small catalogs).
  final Set<String> _collapsed = {};

  // Above this many items, every category starts collapsed so the screen
  // doesn't have to build hundreds/thousands of item tiles on first frame.
  static const _kAutoCollapseThreshold = 30;

  // Above this many search matches, results are rendered in a bounded-height,
  // truly virtualized ListView instead of a shrinkWrap one.
  static const _kSearchVirtualizeThreshold = 20;

  void _init(BusinessProfile p, List<ServiceItem> items) {
    _itemLabel = p.itemLabel;
    if (items.length > _kAutoCollapseThreshold) {
      _collapsed
        ..addAll(_sortedCategories(items))
        ..add(_kUncategorized);
    }
    _initialized = true;
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final cur = provider.profile;
    await provider.updateProfile(cur.copyWith(itemLabel: _itemLabel));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_itemLabel}s saved'),
            duration: const Duration(seconds: 2)),
      );
    }
  }

  // ── Item CRUD ────────────────────────────────────────────────────────────

  Future<void> _add({String? presetCategory}) async {
    final provider = context.read<AppProvider>();
    final limitInfo = await provider.checkServiceItemLimit();
    if (limitInfo != null) {
      if (!mounted) return;
      final upgrade = await showPaywallSheet(context, limitInfo);
      if (upgrade && mounted) Navigator.pushNamed(context, '/plans');
      return;
    }
    final result = await _showForm(presetCategory: presetCategory);
    if (result != null) {
      await provider.addServiceItem(result);
    }
  }

  Future<void> _edit(ServiceItem s) async {
    final result = await _showForm(existing: s);
    if (result != null && mounted) {
      await context.read<AppProvider>().updateServiceItem(result);
    }
  }

  Future<ServiceItem?> _showForm({ServiceItem? existing, String? presetCategory}) {
    final allCategories =
        _sortedCategories(context.read<AppProvider>().serviceItems);
    return showModalBottomSheet<ServiceItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ServiceItemForm(
        existing: existing,
        presetCategory: presetCategory,
        itemLabel: _itemLabel,
        defaultTaxPercent:
            context.read<AppProvider>().profile.defaultTaxPercent,
        allCategories: allCategories,
      ),
    );
  }

  // ── Category helpers ─────────────────────────────────────────────────────

  /// All named categories sorted, then null/empty items go to Uncategorized.
  List<String> _sortedCategories(List<ServiceItem> items) {
    return items
        .map((s) => s.category?.trim())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
  }

  /// Whether [item] (or any of its variants) matches the search [query].
  bool _matchesQuery(ServiceItem item, String query) {
    if (item.name.toLowerCase().contains(query)) return true;
    if (item.category?.toLowerCase().contains(query) ?? false) return true;
    if (item.barcode?.toLowerCase().contains(query) ?? false) return true;
    if (item.hasVariants) {
      for (final v in item.variants) {
        if (v.name.toLowerCase().contains(query)) return true;
        if (v.barcode?.toLowerCase().contains(query) ?? false) return true;
      }
    }
    return false;
  }

  /// { categoryName → items } with '' key for uncategorized items.
  Map<String, List<ServiceItem>> _grouped(List<ServiceItem> items) {
    final map = <String, List<ServiceItem>>{};
    for (final s in items) {
      final key = (s.category?.trim().isNotEmpty == true)
          ? s.category!.trim()
          : '';
      (map[key] ??= []).add(s);
    }
    return map;
  }

  Future<void> _promptAddCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Design, Food, Consulting',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Next: Add Item')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (!mounted || name == null || name.isEmpty) return;
    await _add(presetCategory: name);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.profile;
    if (!_initialized) _init(profile, provider.serviceItems);

    final items = provider.serviceItems;
    final grouped = _grouped(items);
    final namedCats = _sortedCategories(items);
    final uncategorized = grouped[''] ?? [];

    final query = _search.trim().toLowerCase();
    final matches =
        query.isEmpty ? <ServiceItem>[] : items.where((s) => _matchesQuery(s, query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${_itemLabel}s & Services'),
        actions: [
          IconButton(
            tooltip: 'Import from CSV',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ImportInventoryScreen()),
            ),
          ),
          TextButton.icon(
            onPressed: _promptAddCategory,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('Add Category'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(),
        tooltip: 'Add $_itemLabel',
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Label toggle ────────────────────────────────────────────────
          _labelToggleCard(),
          const SizedBox(height: 20),

          // ── Empty state ─────────────────────────────────────────────────
          if (items.isEmpty) _emptyState(),

          if (items.isNotEmpty) ...[
            // ── Search ───────────────────────────────────────────────────
            _searchField(),
            const SizedBox(height: 16),

            if (query.isNotEmpty) ...[
              // ── Search results ────────────────────────────────────────
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No ${_itemLabel.toLowerCase()}s match "$query".',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.subtext(context)),
                    ),
                  ),
                )
              else if (matches.length > _kSearchVirtualizeThreshold)
                // shrinkWrap would force every match to be laid out up front —
                // for a large catalog a broad query can match hundreds of
                // items, so give this list a bounded height and a real
                // viewport that only builds the visible tiles.
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outline(context)),
                  ),
                  child: ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _searchResultTile(matches[i]),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outline(context)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _searchResultTile(matches[i]),
                  ),
                ),
            ] else ...[
              // ── Named categories ──────────────────────────────────────
              for (final cat in namedCats) ...[
                _CategorySection(
                  categoryName: cat,
                  color: _catColor(cat, namedCats),
                  items: grouped[cat] ?? [],
                  itemLabel: _itemLabel,
                  collapsed: _collapsed.contains(cat),
                  onToggle: () => setState(() {
                    if (_collapsed.contains(cat)) {
                      _collapsed.remove(cat);
                    } else {
                      _collapsed.add(cat);
                    }
                  }),
                  onAdd: () => _add(presetCategory: cat),
                  onEdit: _edit,
                  onDelete: (s) async {
                    await context.read<AppProvider>().deleteServiceItem(s.id);
                  },
                ),
                const SizedBox(height: 12),
              ],

              // ── Uncategorized ─────────────────────────────────────────
              if (uncategorized.isNotEmpty) ...[
                _CategorySection(
                  categoryName: _kUncategorized,
                  color: AppTheme.subtext(context),
                  items: uncategorized,
                  itemLabel: _itemLabel,
                  collapsed: _collapsed.contains(_kUncategorized),
                  onToggle: () => setState(() {
                    if (_collapsed.contains(_kUncategorized)) {
                      _collapsed.remove(_kUncategorized);
                    } else {
                      _collapsed.add(_kUncategorized);
                    }
                  }),
                  onAdd: () => _add(),
                  onEdit: _edit,
                  onDelete: (s) async {
                    await context.read<AppProvider>().deleteServiceItem(s.id);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: 'Search ${_itemLabel.toLowerCase()}s…',
        prefixIcon: Icon(Icons.search_rounded,
            size: 20, color: AppTheme.subtext(context)),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  _search = '';
                  _searchCtrl.clear();
                }),
              ),
        filled: true,
        fillColor: AppTheme.inputFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }

  Widget _searchResultTile(ServiceItem item) {
    return _ItemTile(
      item: item,
      categoryLabel:
          item.category?.trim().isNotEmpty == true ? item.category : _kUncategorized,
      onEdit: () => _edit(item),
      onDelete: () async {
        await context.read<AppProvider>().deleteServiceItem(item.id);
      },
    );
  }

  Widget _labelToggleCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How do you call them in invoices?',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onCard(context))),
          SizedBox(height: 4),
          Text(
              'This label appears on line items in invoices and buttons.',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.subtext(context))),
          const SizedBox(height: 12),
          Row(
            children: ['Item', 'Service'].map((label) {
              final selected = _itemLabel == label;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) async {
                    setState(() => _itemLabel = label);
                    await _save();
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 52,
                color: AppTheme.textSecondary.withValues(alpha: 0.35)),
            SizedBox(height: 12),
            Text('No ${_itemLabel.toLowerCase()}s yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.subtext(context))),
            SizedBox(height: 6),
            Text(
              'Tap + to add your first ${_itemLabel.toLowerCase()},\nor "Add Category" to organise from the start.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.subtext(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Section widget ───────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  // Above this many items, the item list switches to a bounded-height,
  // truly virtualized ListView instead of a shrinkWrap one.
  static const _kVirtualizeThreshold = 20;

  final String categoryName;
  final Color color;
  final List<ServiceItem> items;
  final String itemLabel;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(ServiceItem) onEdit;
  final void Function(ServiceItem) onDelete;

  const _CategorySection({
    required this.categoryName,
    required this.color,
    required this.items,
    required this.itemLabel,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        children: [
          // ── Category header ─────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom:
                  collapsed ? const Radius.circular(12) : Radius.zero,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      categoryName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color == AppTheme.textSecondary
                              ? AppTheme.subtext(context)
                              : AppTheme.onCard(context)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 14),
                    label: Text('Add $itemLabel',
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: AppTheme.subtext(context),
                  ),
                ],
              ),
            ),
          ),

          // ── Item list ───────────────────────────────────────────────────
          if (!collapsed) ...[
            const Divider(height: 1),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 32,
                          color: AppTheme.subtext(context)
                              .withValues(alpha: 0.3)),
                      SizedBox(height: 8),
                      Text(
                        'No ${itemLabel.toLowerCase()}s in this category',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(context)),
                      ),
                    ],
                  ),
                ),
              )
            else if (items.length > _CategorySection._kVirtualizeThreshold)
              // shrinkWrap forces every child to be laid out up front, so for
              // large categories that builds hundreds of tiles in one frame.
              // Give this list a bounded height so it gets a real viewport
              // and only builds the tiles that are actually visible.
              SizedBox(
                height: 400,
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _ItemTile(
                    item: items[i],
                    onEdit: () => onEdit(items[i]),
                    onDelete: () => onDelete(items[i]),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _ItemTile(
                  item: items[i],
                  onEdit: () => onEdit(items[i]),
                  onDelete: () => onDelete(items[i]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Item tile ─────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final ServiceItem item;
  final String? categoryLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemTile(
      {required this.item,
      this.categoryLabel,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.description != null && item.description!.isNotEmpty)
        item.description!,
      if (!item.hasVariants && item.rate > 0)
        '₹${item.rate.toStringAsFixed(0)}',
      if (!item.hasVariants && item.unit != null && item.unit!.isNotEmpty)
        item.unit!,
      if (item.taxPercent > 0)
        '${item.taxPercent.toStringAsFixed(0)}% tax',
    ];
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        child: Icon(
          item.hasVariants
              ? Icons.layers_outlined
              : Icons.receipt_long_outlined,
          size: 15,
          color: AppTheme.primary,
        ),
      ),
      title: Text(item.name,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (categoryLabel != null) ...[
            Text(categoryLabel!,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
            const SizedBox(height: 2),
          ],
          if (item.hasVariants) ...[
            Text(
              '${item.variants.length} variant${item.variants.length == 1 ? '' : 's'}'
              ' · from ₹${item.lowestVariantRate.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.subtext(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (parts.isNotEmpty)
            Text(
              parts.join(' · '),
              style: TextStyle(
                  fontSize: 11, color: AppTheme.subtext(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (!item.hasVariants && item.isTrackingStock) ...[
            const SizedBox(height: 4),
            _StockBadge(item: item),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 18, color: AppTheme.subtext(context)),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppTheme.error),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Stock badge ──────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final ServiceItem item;
  const _StockBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLow = item.isLowStock;
    final qty = item.totalStock;
    final bgColor = isLow
        ? AppTheme.error.withValues(alpha: 0.12)
        : AppTheme.textSecondary.withValues(alpha: 0.1);
    final fgColor = isLow ? AppTheme.error : AppTheme.textSecondary;
    final label = isLow
        ? '${qty % 1 == 0 ? qty.toInt() : qty} · Low Stock'
        : '${qty % 1 == 0 ? qty.toInt() : qty} in stock';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            size: 10,
            color: fgColor,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Service Item Form ────────────────────────────────────────────────────

class _ServiceItemForm extends StatefulWidget {
  final ServiceItem? existing;
  final String? presetCategory;
  final String itemLabel;
  final double defaultTaxPercent;
  final List<String> allCategories;

  const _ServiceItemForm({
    this.existing,
    this.presetCategory,
    required this.itemLabel,
    required this.defaultTaxPercent,
    this.allCategories = const [],
  });

  @override
  State<_ServiceItemForm> createState() => _ServiceItemFormState();
}

class _ServiceItemFormState extends State<_ServiceItemForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _costPriceCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _thresholdCtrl;
  late TextEditingController _barcodeCtrl;
  bool _trackStock = false;
  bool _hasVariants = false;
  List<_VariantRowData> _variantRows = [];
  String? _stockShopId;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _stockShopId = context.read<AppProvider>().currentShopId;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _rateCtrl = TextEditingController(
        text: s != null && !s.hasVariants && s.rate > 0
            ? s.rate.toString()
            : '');
    _costPriceCtrl = TextEditingController(
        text: s?.costPrice != null ? s!.costPrice.toString() : '');
    _taxCtrl = TextEditingController(
        text: s != null
            ? s.taxPercent.toString()
            : widget.defaultTaxPercent.toString());
    _unitCtrl = TextEditingController(text: s?.unit ?? '');
    _categoryCtrl = TextEditingController(
        text: s?.category ?? widget.presetCategory ?? '');
    _trackStock = (s?.isTrackingStock ?? false) && !(s?.hasVariants ?? false);
    _qtyCtrl = TextEditingController(
        text: s?.stockByShop[_stockShopId]?.toString() ?? '');
    _thresholdCtrl = TextEditingController(
        text: s?.lowStockThreshold?.toString() ?? '');
    _barcodeCtrl = TextEditingController(text: s?.barcode ?? '');
    _hasVariants = s?.hasVariants ?? false;
    _variantRows = s?.variants
            .map((v) => _VariantRowData.fromVariant(v, _stockShopId))
            .toList() ??
        [];
    if (_hasVariants && _variantRows.isEmpty) {
      _variantRows.add(_VariantRowData.empty());
    }
  }

  /// Re-reads the qty controllers for the newly selected stock location.
  void _onStockShopChanged(String? shopId) {
    setState(() {
      _stockShopId = shopId;
      final s = widget.existing;
      _qtyCtrl.text = s?.stockByShop[shopId]?.toString() ?? '';
      for (final row in _variantRows) {
        row.qtyCtrl.text =
            row.existingStockByShop[shopId]?.toString() ?? '';
      }
    });
  }

  /// Dropdown for choosing which shop's stock level is being edited.
  /// Hidden when the business only has a single shop.
  Widget _buildStockShopPicker() {
    final shops = context.watch<AppProvider>().allShops;
    if (shops.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _stockShopId,
        decoration: const InputDecoration(labelText: 'Stock Location'),
        items: shops
            .map((s) => DropdownMenuItem(
                  value: s.shopId,
                  child: Text(s.shopName),
                ))
            .toList(),
        onChanged: _onStockShopChanged,
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _rateCtrl,
      _costPriceCtrl,
      _taxCtrl,
      _unitCtrl,
      _categoryCtrl,
      _qtyCtrl,
      _thresholdCtrl,
      _barcodeCtrl,
    ]) {
      c.dispose();
    }
    for (final r in _variantRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _toggleVariants(bool on) {
    setState(() {
      _hasVariants = on;
      if (on) {
        // Pre-fill first variant with existing rate if set
        if (_variantRows.isEmpty) {
          final seed = _VariantRowData.empty();
          if (_rateCtrl.text.isNotEmpty) {
            seed.rateCtrl.text = _rateCtrl.text;
          }
          _variantRows.add(seed);
        }
        // Clear flat rate / stock (per-variant takes over)
        _trackStock = false;
      }
    });
  }

  void _addVariantRow() {
    setState(() => _variantRows.add(_VariantRowData.empty()));
  }

  void _removeVariantRow(int i) {
    if (_variantRows.length <= 1) return;
    final row = _variantRows.removeAt(i);
    row.dispose();
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final cat = _categoryCtrl.text.trim();

    List<ProductVariant>? variants;
    if (_hasVariants) {
      variants = _variantRows
          .where((r) => r.nameCtrl.text.trim().isNotEmpty)
          .map((r) {
            final bc = r.barcodeCtrl.text.trim();
            final newStockByShop = Map<String, double>.from(r.existingStockByShop);
            if (r.trackStock && _stockShopId != null) {
              newStockByShop[_stockShopId!] = double.tryParse(r.qtyCtrl.text) ?? 0;
            } else if (!r.trackStock) {
              newStockByShop.clear();
            }
            return ProductVariant(
              id: r.id,
              name: r.nameCtrl.text.trim(),
              rate: double.tryParse(r.rateCtrl.text) ?? 0,
              costPrice: double.tryParse(r.costPriceCtrl.text.trim()),
              barcode: bc.isEmpty ? null : bc,
              trackStock: r.trackStock,
              stockByShop: newStockByShop,
              lowStockThreshold: r.trackStock
                  ? double.tryParse(r.thresholdCtrl.text)
                  : null,
            );
          })
          .toList();
    }

    final newStockByShop =
        Map<String, double>.from(widget.existing?.stockByShop ?? {});
    if (!_hasVariants && _trackStock && _stockShopId != null) {
      newStockByShop[_stockShopId!] = double.tryParse(_qtyCtrl.text) ?? 0;
    } else if (!_trackStock) {
      newStockByShop.clear();
    }

    final barcode = _barcodeCtrl.text.trim();
    Navigator.pop(
      context,
      ServiceItem(
        id: id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        rate: _hasVariants ? 0 : (double.tryParse(_rateCtrl.text) ?? 0),
        costPrice: _hasVariants
            ? null
            : double.tryParse(_costPriceCtrl.text.trim()),
        taxPercent: double.tryParse(_taxCtrl.text) ?? 0,
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        category: cat.isEmpty ? null : cat,
        barcode: barcode.isEmpty ? null : barcode,
        trackStock: !_hasVariants && _trackStock,
        stockByShop: newStockByShop,
        lowStockThreshold: (!_hasVariants && _trackStock)
            ? double.tryParse(_thresholdCtrl.text)
            : null,
        variants: variants,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.itemLabel;
    // Build suggestion list: preset + previously used categories
    final suggestions = <String>{
      if (widget.presetCategory != null) widget.presetCategory!,
      ...widget.allCategories,
    }.where((c) => c.isNotEmpty).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.existing == null ? 'Add $label' : 'Edit $label',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Category field — shown first so user sees which group
            if (_categoryCtrl.text.isNotEmpty || widget.presetCategory != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.label_outline,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      _categoryCtrl.text.isNotEmpty
                          ? _categoryCtrl.text
                          : widget.presetCategory ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),

            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '$label Name',
                hintText: 'e.g. Web Design, Haircut, Masala Dosa',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Description (shown on invoice)',
                hintText: 'Leave blank to use $label name',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // ── Barcode ───────────────────────────────────────────────
            TextFormField(
              controller: _barcodeCtrl,
              decoration: InputDecoration(
                labelText: 'Barcode / SKU',
                hintText: 'Scan or type barcode',
                prefixIcon: const Icon(Icons.qr_code, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.document_scanner_outlined, size: 20),
                  tooltip: 'Scan with camera',
                  onPressed: () async {
                    final value = await scanBarcode(context,
                        title: 'Scan Product Barcode');
                    if (value != null && mounted) {
                      setState(() => _barcodeCtrl.text = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category autocomplete
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _categoryCtrl.text),
              optionsBuilder: (value) {
                if (suggestions.isEmpty) return const [];
                final q = value.text.toLowerCase();
                if (q.isEmpty) return suggestions;
                return suggestions
                    .where((c) => c.toLowerCase().contains(q));
              },
              onSelected: (v) =>
                  setState(() => _categoryCtrl.text = v),
              fieldViewBuilder: (ctx, ctrl, focusNode, _) {
                ctrl.text = _categoryCtrl.text;
                ctrl.addListener(
                    () => _categoryCtrl.text = ctrl.text);
                return TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Design, Food, Consulting',
                    prefixIcon:
                        const Icon(Icons.label_outline, size: 18),
                    suffixIcon: suggestions.isNotEmpty
                        ? Icon(Icons.expand_more,
                            size: 18,
                            color: AppTheme.subtext(context))
                        : null,
                  ),
                );
              },
              optionsViewBuilder: (ctx, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxHeight: 160, maxWidth: 300),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: options
                          .map((cat) => ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.label_outline,
                                    size: 16,
                                    color: AppTheme.primary),
                                title: Text(cat,
                                    style: const TextStyle(
                                        fontSize: 13)),
                                onTap: () => onSelected(cat),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Packaging variants toggle ────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.outline(context)),
              ),
              child: SwitchListTile(
                title: const Text('Has Packaging Variants',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'e.g. 180ml, 360ml, 500ml — each with its own price',
                    style: TextStyle(fontSize: 11)),
                value: _hasVariants,
                activeThumbColor: AppTheme.primary,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
                onChanged: _toggleVariants,
              ),
            ),
            const SizedBox(height: 12),

            if (!_hasVariants) ...[
              // ── Selling price + unit ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _rateCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Selling Price', hintText: '0'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Unit', hintText: 'hrs, pcs…'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Cost price ────────────────────────────────────────
              _CostPriceField(
                costCtrl: _costPriceCtrl,
                sellingPrice: double.tryParse(_rateCtrl.text.trim()),
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Tax %', suffixText: '%'),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 100) return '0–100';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // ── Stock tracking ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.outline(context)),
                ),
                child: SwitchListTile(
                  title: const Text('Track Stock / Inventory',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Monitor quantity on hand for this item',
                      style: TextStyle(fontSize: 11)),
                  value: _trackStock,
                  activeThumbColor: AppTheme.primary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  onChanged: (v) => setState(() => _trackStock = v),
                ),
              ),
              if (_trackStock) ...[
                const SizedBox(height: 12),
                _buildStockShopPicker(),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity on Hand',
                          hintText: '0',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _thresholdCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Low Stock Alert Threshold',
                          hintText: 'e.g. 5',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // ── Variant rows ──────────────────────────────────────
              TextFormField(
                controller: _taxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Tax % (applied to all variants)',
                    suffixText: '%'),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 100) return '0–100';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildStockShopPicker(),
              Row(
                children: [
                  const Text('Variants',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addVariantRow,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._variantRows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return _VariantRowWidget(
                  key: ValueKey(row.id),
                  row: row,
                  index: i,
                  canRemove: _variantRows.length > 1,
                  onRemove: () => _removeVariantRow(i),
                  onChanged: () => setState(() {}),
                );
              }),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
              child: Text(widget.existing == null
                  ? 'Add $label'
                  : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Variant row data holder ──────────────────────────────────────────────────

class _VariantRowData {
  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController costPriceCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController thresholdCtrl;
  bool trackStock;
  Map<String, double> existingStockByShop;

  _VariantRowData({
    required this.id,
    required this.nameCtrl,
    required this.rateCtrl,
    required this.costPriceCtrl,
    required this.barcodeCtrl,
    required this.qtyCtrl,
    required this.thresholdCtrl,
    this.trackStock = false,
    Map<String, double>? existingStockByShop,
  }) : existingStockByShop = existingStockByShop ?? {};

  factory _VariantRowData.empty() => _VariantRowData(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        nameCtrl: TextEditingController(),
        rateCtrl: TextEditingController(),
        costPriceCtrl: TextEditingController(),
        barcodeCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(),
        thresholdCtrl: TextEditingController(),
      );

  factory _VariantRowData.fromVariant(ProductVariant v, String? stockShopId) =>
      _VariantRowData(
        id: v.id,
        nameCtrl: TextEditingController(text: v.name),
        rateCtrl: TextEditingController(
            text: v.rate > 0 ? v.rate.toString() : ''),
        costPriceCtrl: TextEditingController(
            text: v.costPrice != null ? v.costPrice.toString() : ''),
        barcodeCtrl: TextEditingController(text: v.barcode ?? ''),
        qtyCtrl: TextEditingController(
            text: v.stockByShop[stockShopId]?.toString() ?? ''),
        thresholdCtrl: TextEditingController(
            text: v.lowStockThreshold?.toString() ?? ''),
        trackStock: v.isTrackingStock,
        existingStockByShop: Map.of(v.stockByShop),
      );

  void dispose() {
    nameCtrl.dispose();
    rateCtrl.dispose();
    costPriceCtrl.dispose();
    barcodeCtrl.dispose();
    qtyCtrl.dispose();
    thresholdCtrl.dispose();
  }
}

// ─── Variant row widget ───────────────────────────────────────────────────────

class _VariantRowWidget extends StatefulWidget {
  final _VariantRowData row;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _VariantRowWidget({
    super.key,
    required this.row,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_VariantRowWidget> createState() => _VariantRowWidgetState();
}

class _VariantRowWidgetState extends State<_VariantRowWidget> {
  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Variant ${widget.index + 1}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary),
              ),
              const Spacer(),
              if (widget.canRemove)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 18, color: Colors.red),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: row.nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Size / Name',
                    hintText: 'e.g. 180ml',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Selling Price',
                    hintText: '0',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CostPriceField(
            costCtrl: row.costPriceCtrl,
            sellingPrice: double.tryParse(row.rateCtrl.text.trim()),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: row.barcodeCtrl,
            decoration: InputDecoration(
              labelText: 'Barcode (optional)',
              hintText: 'Scan or type',
              isDense: true,
              prefixIcon: const Icon(Icons.qr_code, size: 16),
              suffixIcon: IconButton(
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                padding: EdgeInsets.zero,
                tooltip: 'Scan',
                onPressed: () async {
                  final value =
                      await scanBarcode(context, title: 'Scan Variant Barcode');
                  if (value != null && mounted) {
                    setState(() => row.barcodeCtrl.text = value);
                    widget.onChanged();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Track Stock',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            value: row.trackStock,
            activeThumbColor: AppTheme.primary,
            onChanged: (v) => setState(() {
              row.trackStock = v;
              widget.onChanged();
            }),
          ),
          if (row.trackStock) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Qty on Hand',
                      hintText: '0',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: row.thresholdCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Low Alert',
                      hintText: 'e.g. 5',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Cost price field with live margin hint ───────────────────────────────────

class _CostPriceField extends StatelessWidget {
  final TextEditingController costCtrl;
  final double? sellingPrice;
  final VoidCallback onChanged;

  const _CostPriceField({
    required this.costCtrl,
    required this.sellingPrice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cost = double.tryParse(costCtrl.text.trim());
    final sp = sellingPrice;
    String? hint;
    Color hintColor = AppTheme.success;
    if (cost != null && sp != null && sp > 0) {
      final margin = sp - cost;
      final pct = (margin / sp * 100).toStringAsFixed(1);
      if (margin >= 0) {
        hint = 'Margin ₹${margin.toStringAsFixed(0)}  ($pct%)';
        hintColor = AppTheme.success;
      } else {
        hint = 'Loss ₹${margin.abs().toStringAsFixed(0)}  ($pct%)';
        hintColor = AppTheme.error;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: costCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cost Price (optional)',
            hintText: 'Purchase / landed cost',
          ),
          onChanged: (_) => onChanged(),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(fontSize: 11, color: hintColor, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
