import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/purchase_bill.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'create_purchase_bill_screen.dart';
import 'vendor_profile_screen.dart';
import '../widgets/feature_guide_sheet.dart';

class PurchaseBillListScreen extends StatefulWidget {
  const PurchaseBillListScreen({super.key});

  @override
  State<PurchaseBillListScreen> createState() => _PurchaseBillListScreenState();
}

class _PurchaseBillListScreenState extends State<PurchaseBillListScreen> {
  String _filter = 'All'; // All | Unpaid | Partial | Paid
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.purchaseBills);
    });
  }

  static const _filters = ['All', 'Unpaid', 'Partial', 'Paid'];

  List<PurchaseBill> _apply(List<PurchaseBill> bills) {
    return bills.where((b) {
      final matchStatus = _filter == 'All' ||
          (_filter == 'Unpaid' && b.status == PurchaseBillStatus.unpaid) ||
          (_filter == 'Partial' && b.status == PurchaseBillStatus.partiallyPaid) ||
          (_filter == 'Paid' && b.status == PurchaseBillStatus.paid);
      if (!matchStatus) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return b.vendorName.toLowerCase().contains(q) ||
          (b.billNumber?.toLowerCase().contains(q) ?? false) ||
          (b.vendorGstin?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _delete(PurchaseBill bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text('Delete bill from ${bill.vendorName}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppProvider>().deletePurchaseBill(bill.id);
    }
  }

  void _showVendors(BuildContext context) {
    final allBills = context.read<AppProvider>().purchaseBills;
    final vendors = allBills.map((b) => b.vendorName).toSet().toList()
      ..sort();
    if (vendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vendors yet. Add a purchase bill first.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.store_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Vendors (${vendors.length})',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: vendors.length,
              itemBuilder: (_, i) {
                final name = vendors[i];
                final count = allBills.where((b) => b.vendorName == name).length;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w700)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$count bill${count == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VendorProfileScreen(vendorName: name),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bills = _apply(context.watch<AppProvider>().purchaseBills);
    final currency = context.read<AppProvider>().profile.currency;
    final sym = Fmt.currencySymbol(currency);

    // Summary totals
    final totalDue = bills.where((b) => b.status != PurchaseBillStatus.paid)
        .fold(0.0, (s, b) => s + b.amountDue);
    final totalItc = bills.fold(0.0, (s, b) => s + b.itcAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store_outlined),
            tooltip: 'Vendors',
            onPressed: () => _showVendors(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Bill',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePurchaseBillScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search vendor, bill no., GSTIN…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.outline(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.outline(context)),
                    ),
                  ),
                ),
              ),
              // Status filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  children: _filters.map((f) {
                    final sel = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: sel,
                        onSelected: (_) => setState(() => _filter = f),
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          color: sel ? AppTheme.primary : AppTheme.subtext(context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: bills.isEmpty
          ? _EmptyState(hasFilter: _filter != 'All' || _search.isNotEmpty)
          : CustomScrollView(
              slivers: [
                // Summary banner
                SliverToBoxAdapter(
                  child: _SummaryBanner(
                    sym: sym,
                    totalDue: totalDue,
                    totalItc: totalItc,
                  ),
                ),
                // Bill list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _BillTile(
                      bill: bills[i],
                      sym: sym,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatePurchaseBillScreen(bill: bills[i]),
                        ),
                      ),
                      onDelete: () => _delete(bills[i]),
                    ),
                    childCount: bills.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePurchaseBillScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
    );
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final String sym;
  final double totalDue;
  final double totalItc;
  const _SummaryBanner({required this.sym, required this.totalDue, required this.totalItc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF7C3AED), const Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _StatCol(label: 'Amount Due', value: '$sym${Fmt.compact(totalDue)}'),
          const VerticalDivider(color: Colors.white24, width: 32),
          _StatCol(label: 'ITC Claimable', value: '$sym${Fmt.compact(totalItc)}',
              sub: 'Input Tax Credit'),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _StatCol({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          if (sub != null)
            Text(sub!, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }
}

// ── Bill tile ─────────────────────────────────────────────────────────────────

class _BillTile extends StatelessWidget {
  final PurchaseBill bill;
  final String sym;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BillTile({
    required this.bill,
    required this.sym,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = bill.status.color;
    final isOverdue = bill.isOverdue;

    return Dismissible(
      key: ValueKey(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // let onDelete handle it with confirmation
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOverdue
                  ? AppTheme.error.withValues(alpha: 0.4)
                  : AppTheme.outline(context),
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(bill.status.icon, size: 20, color: statusColor),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(bill.vendorName,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onCard(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('$sym${Fmt.compact(bill.grandTotal)}',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onCard(context))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (bill.billNumber != null) ...[
                          Text('#${bill.billNumber}',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.subtext(context))),
                          Text(' · ',
                              style: TextStyle(color: AppTheme.subtext(context))),
                        ],
                        Text(Fmt.shortDate(bill.billDate),
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.subtext(context))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(bill.status.label,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor)),
                        ),
                      ],
                    ),
                    if (bill.itcAmount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ITC: $sym${Fmt.compact(bill.itcAmount)}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('Overdue',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.error,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_outlined, size: 56, color: AppTheme.subtext(context)),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No bills match the filter' : 'No purchase bills yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.onCard(context)),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try changing the status filter'
                : 'Tap + to record a vendor invoice',
            style: TextStyle(fontSize: 13, color: AppTheme.subtext(context)),
          ),
        ],
      ),
    );
  }
}
