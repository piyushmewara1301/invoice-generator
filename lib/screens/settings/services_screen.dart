import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_profile.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/paywall_sheet.dart';

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
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _itemLabel = 'Item';
  List<ServiceItem> _items = [];
  bool _initialized = false;

  // Which category sections are expanded (all expanded by default)
  final Set<String> _collapsed = {};

  void _init(BusinessProfile p) {
    _itemLabel = p.itemLabel;
    _items = List.from(p.serviceItems);
    _initialized = true;
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final cur = provider.profile;
    await provider.updateProfile(cur.copyWith(
      itemLabel: _itemLabel,
      serviceItems: _items,
    ));
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
    final limitInfo = context.read<AppProvider>().checkServiceItemLimit();
    if (limitInfo != null) {
      final upgrade = await showPaywallSheet(context, limitInfo);
      if (upgrade && mounted) Navigator.pushNamed(context, '/plans');
      return;
    }
    final result = await _showForm(presetCategory: presetCategory);
    if (result != null) {
      setState(() => _items.add(result));
      await _save();
    }
  }

  Future<void> _edit(ServiceItem s) async {
    final result = await _showForm(existing: s);
    if (result != null) {
      setState(() {
        final i = _items.indexOf(s);
        if (i >= 0) _items[i] = result;
      });
      await _save();
    }
  }

  Future<ServiceItem?> _showForm({ServiceItem? existing, String? presetCategory}) {
    final allCategories = _sortedCategories();
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
  List<String> _sortedCategories() {
    return _items
        .map((s) => s.category?.trim())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
  }

  /// { categoryName → items } with '' key for uncategorized items.
  Map<String, List<ServiceItem>> _grouped() {
    final map = <String, List<ServiceItem>>{};
    for (final s in _items) {
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
      builder: (_) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Design, Food, Consulting',
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Next: Add Item')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _add(presetCategory: name);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;
    if (!_initialized) _init(profile);

    final grouped = _grouped();
    final namedCats = _sortedCategories();
    final uncategorized = grouped[''] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_itemLabel}s & Services'),
        actions: [
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
          if (_items.isEmpty) _emptyState(),

          // ── Named categories ────────────────────────────────────────────
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
                setState(() => _items.remove(s));
                await _save();
              },
            ),
            const SizedBox(height: 12),
          ],

          // ── Uncategorized ───────────────────────────────────────────────
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
                setState(() => _items.remove(s));
                await _save();
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemTile(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.description != null && item.description!.isNotEmpty)
        item.description!,
      if (item.rate > 0) '₹${item.rate.toStringAsFixed(0)}',
      if (item.unit != null && item.unit!.isNotEmpty) item.unit!,
      if (item.taxPercent > 0)
        '${item.taxPercent.toStringAsFixed(0)}% tax',
    ];
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.receipt_long_outlined,
            size: 15, color: AppTheme.primary),
      ),
      title: Text(item.name,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (parts.isNotEmpty)
            Text(
              parts.join(' · '),
              style: TextStyle(
                  fontSize: 11, color: AppTheme.subtext(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (item.isTrackingStock) ...[
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
    final qty = item.quantityOnHand!;
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
  late TextEditingController _taxCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _thresholdCtrl;
  bool _trackStock = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _rateCtrl = TextEditingController(
        text: s != null && s.rate > 0 ? s.rate.toString() : '');
    _taxCtrl = TextEditingController(
        text: s != null
            ? s.taxPercent.toString()
            : widget.defaultTaxPercent.toString());
    _unitCtrl = TextEditingController(text: s?.unit ?? '');
    _categoryCtrl = TextEditingController(
        text: s?.category ?? widget.presetCategory ?? '');
    _trackStock = s?.isTrackingStock ?? false;
    _qtyCtrl = TextEditingController(
        text: s?.quantityOnHand?.toString() ?? '');
    _thresholdCtrl = TextEditingController(
        text: s?.lowStockThreshold?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _rateCtrl,
      _taxCtrl,
      _unitCtrl,
      _categoryCtrl,
      _qtyCtrl,
      _thresholdCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final cat = _categoryCtrl.text.trim();
    Navigator.pop(
      context,
      ServiceItem(
        id: id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        rate: double.tryParse(_rateCtrl.text) ?? 0,
        taxPercent: double.tryParse(_taxCtrl.text) ?? 0,
        unit:
            _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        category: cat.isEmpty ? null : cat,
        quantityOnHand:
            _trackStock ? double.tryParse(_qtyCtrl.text) : null,
        lowStockThreshold: _trackStock
            ? double.tryParse(_thresholdCtrl.text)
            : null,
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

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Default Rate', hintText: '0'),
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

            // ── Inventory / Stock tracking ────────────────────────────
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
