import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/status_badge.dart';
import 'create_invoice_screen.dart';
import '../widgets/feature_guide_sheet.dart';

class DeliveryChallanScreen extends StatefulWidget {
  const DeliveryChallanScreen({super.key});

  @override
  State<DeliveryChallanScreen> createState() => _DeliveryChallanScreenState();
}

class _DeliveryChallanScreenState extends State<DeliveryChallanScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.deliveryChallan);
    });
  }

  List<Invoice> _apply(List<Invoice> all) {
    final challans = all.where((i) => i.isDeliveryChallan).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_search.isEmpty) return challans;
    final q = _search.toLowerCase();
    return challans.where((c) {
      return c.invoiceNumber.toLowerCase().contains(q) ||
          (c.client?.displayName.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _createChallan() async {
    final provider = context.read<AppProvider>();
    final challan = provider.buildNewChallan();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: challan)),
    );
  }

  Future<void> _deleteChallan(Invoice challan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Challan'),
        content: Text(
            'Delete ${challan.invoiceNumber}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    context.read<AppProvider>().deleteInvoice(challan.id);
  }

  Future<void> _convertToInvoice(Invoice challan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Convert to Invoice?'),
        content: Text(
            'Challan #${challan.invoiceNumber} will be converted to a new invoice. '
            'The challan remains unchanged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Convert')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final provider = context.read<AppProvider>();
      final invoice = await provider.convertChallanToInvoice(challan.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreateInvoiceScreen(invoice: invoice)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final challans  = _apply(provider.invoices);
    final sym       = Fmt.currencySymbol(provider.profile.currency);
    final total     = challans.fold(0.0, (s, c) => s + c.grandTotal);
    final converted = challans.where((c) => c.challanLinkedInvoiceId != null).length;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text('Delivery Challans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Challan',
            onPressed: _createChallan,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search challan or customer…',
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
        ),
      ),
      body: challans.isEmpty
          ? _EmptyState(hasSearch: _search.isNotEmpty, onCreate: _createChallan)
          : CustomScrollView(
              slivers: [
                // ── Summary banner ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SummaryBanner(
                    total: total,
                    sym: sym,
                    count: challans.length,
                    converted: converted,
                  ),
                ),
                // ── Challan list ────────────────────────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final challan = challans[i];
                      final tile = _ChallanTile(
                        challan: challan,
                        sym: sym,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreateInvoiceScreen(invoice: challan),
                          ),
                        ),
                        onConvert: challan.challanLinkedInvoiceId == null
                            ? () => _convertToInvoice(challan)
                            : null,
                        onDelete: () => _deleteChallan(challan),
                      );
                      return Dismissible(
                        key: Key(challan.id),
                        direction: DismissDirection.horizontal,
                        // Swipe right → edit
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_outlined,
                                  color: Colors.white, size: 22),
                              SizedBox(height: 4),
                              Text('Edit',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        // Swipe left → delete
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.white, size: 22),
                              SizedBox(height: 4),
                              Text('Delete',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreateInvoiceScreen(invoice: challan),
                              ),
                            );
                            return false;
                          }
                          // Swipe left → confirm delete
                          await _deleteChallan(challan);
                          return false; // _deleteChallan handles deletion
                        },
                        child: tile,
                      );
                    },
                    childCount: challans.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createChallan,
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('New Challan'),
      ),
    );
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final double total;
  final String sym;
  final int count;
  final int converted;
  const _SummaryBanner(
      {required this.total,
      required this.sym,
      required this.count,
      required this.converted});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _Col(label: 'Total Challans', value: '$count'),
        const VerticalDivider(color: Colors.white24, width: 32),
        _Col(label: 'Goods Value', value: '$sym${Fmt.compact(total)}'),
        const VerticalDivider(color: Colors.white24, width: 32),
        _Col(label: 'Converted', value: '$converted', sub: 'to invoice'),
      ]),
    );
  }
}

class _Col extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _Col({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ]),
      );
}

// ── Challan tile ──────────────────────────────────────────────────────────────

class _ChallanTile extends StatelessWidget {
  final Invoice challan;
  final String sym;
  final VoidCallback onTap;
  final VoidCallback? onConvert;
  final VoidCallback? onDelete;
  const _ChallanTile({
    required this.challan,
    required this.sym,
    required this.onTap,
    this.onConvert,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isConverted = challan.challanLinkedInvoiceId != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline(context)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Challan icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  size: 20, color: Color(0xFF0D9488)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('#${challan.invoiceNumber}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onCard(context))),
                      const SizedBox(width: 6),
                      if (isConverted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Converted',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669))),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      challan.client?.displayName ?? 'No customer',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context)),
                    ),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$sym${Fmt.compact(challan.grandTotal)}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context))),
              const SizedBox(height: 2),
              Text(Fmt.shortDate(challan.invoiceDate),
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.subtext(context))),
            ]),
          ]),
          if (onConvert != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onConvert,
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded,
                    size: 16, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                const Text('Convert to Invoice',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8))),
                const Spacer(),
                StatusBadge(status: challan.status),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onCreate;
  const _EmptyState({required this.hasSearch, required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping_outlined,
              size: 64, color: AppTheme.subtext(context).withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No challans match your search' : 'No Delivery Challans',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.onCard(context)),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try a different search term'
                : 'Create a challan to track goods dispatched\nbefore a formal invoice is raised',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppTheme.subtext(context)),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Challan'),
            ),
          ],
        ]),
      );
}
