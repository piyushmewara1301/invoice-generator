import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_sale.dart';
import '../models/invoice.dart';
import '../models/payment_method.dart';
import '../models/service_item.dart';
import 'cash_denomination_screen.dart';
import 'daily_sales_expense_screen.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/service_item_search_field.dart';
import 'barcode_scanner_screen.dart';

class DailySalesScreen extends StatefulWidget {
  const DailySalesScreen({super.key});

  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  bool _showChart = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sales = provider.dailySales;
    final currency = provider.profile.currency;

    Widget listBody() => sales.isEmpty
        ? _emptyState(context)
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sales.length,
            separatorBuilder: (_, sep) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _SaleTile(
              sale: sales[i],
              currency: currency,
              onTap: () => _openEntry(context, sale: sales[i]),
              onDelete: () => _confirmDelete(context, sales[i]),
            ),
          );

    // Cumulative cash expected across all of today's entries — useful when
    // a shop logs multiple stock entries (different titles/registers) for
    // the same day and wants one combined cash count at closing.
    final today = DateTime.now();
    final todayExpectedCash = sales
        .where((s) =>
            s.date.year == today.year &&
            s.date.month == today.month &&
            s.date.day == today.day)
        .fold(0.0, (sum, s) => sum + s.expectedCash);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Cash Counter (Today, all entries)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CashDenominationScreen(expectedAmount: todayExpectedCash),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
                _showChart ? Icons.list_outlined : Icons.bar_chart_outlined),
            tooltip: _showChart ? 'List View' : 'Chart View',
            onPressed: () => setState(() => _showChart = !_showChart),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Expenses',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DailySalesExpenseScreen()),
            ),
          ),
        ],
      ),
      body: _showChart
          ? Column(
              children: [
                _SalesChart(
                  allSales: sales,
                  currency: currency,
                  onDrillDown: (sale) => _openEntry(context, sale: sale),
                ),
                Divider(height: 1, color: AppTheme.outline(context)),
                Expanded(child: listBody()),
              ],
            )
          : listBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntry(context),
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined,
              size: 72, color: AppTheme.subtext(context)),
          const SizedBox(height: 16),
          Text(
            'No sales entries yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.onCard(context)),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to record today\'s sales',
            style: TextStyle(color: AppTheme.subtext(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _openEntry(BuildContext context, {DailySale? sale}) async {
    if (sale != null) {
      // Existing entries open in a read-only summary first; "Edit" switches
      // to the editable form.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _SaleDetailSheet(
          sale: sale,
          onEdit: () {
            Navigator.pop(context);
            _openEditSheet(context, sale: sale);
          },
        ),
      );
      return;
    }
    await _openEditSheet(context);
  }

  Future<void> _openEditSheet(BuildContext context, {DailySale? sale}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SaleEntrySheet(sale: sale),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DailySale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
            'Remove the entry for ${Fmt.date(sale.date)}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppProvider>().deleteDailySale(sale.id);
    }
  }
}

// ── Sale tile in list ─────────────────────────────────────────────────────────

class _SaleTile extends StatelessWidget {
  final DailySale sale;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SaleTile({
    required this.sale,
    required this.currency,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final balanced = sale.isBalanced;
    final balanceColor = balanced ? AppTheme.success : AppTheme.error;

    return Card(
      elevation: 0,
      color: AppTheme.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.outline(context), width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      Fmt.date(sale.date),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: balanceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            balanced
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 13,
                            color: balanceColor),
                        const SizedBox(width: 4),
                        Text(
                          balanced ? 'Balanced' : 'Unbalanced',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: balanceColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.subtext(context)),
                    ),
                  ),
                ],
              ),
              if (sale.title != null && sale.title!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  sale.title!,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatChip(
                    icon: Icons.sell_outlined,
                    label: 'Sales',
                    value: Fmt.currencyAmount(sale.totalSales, currency),
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.payments_outlined,
                    label: 'Cash',
                    value: Fmt.currencyAmount(sale.cashReceived, currency),
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.account_balance_outlined,
                    label: 'Bank',
                    value: Fmt.currencyAmount(sale.bankReceived, currency),
                    color: const Color(0xFF0891B2),
                  ),
                ],
              ),
              if (sale.totalExpenses > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.receipt_long_outlined,
                      label: 'Expenses',
                      value: Fmt.currencyAmount(sale.totalExpenses, currency),
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.wallet_outlined,
                      label: 'Cash in Hand',
                      value: Fmt.currencyAmount(sale.expectedCash, currency),
                      color: const Color(0xFF0D9488),
                    ),
                  ],
                ),
              ],
              if (!sale.isBalanced) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppTheme.error),
                    const SizedBox(width: 4),
                    Text(
                      'Difference: ${Fmt.currencyAmount(sale.difference.abs(), currency)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
              if (sale.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${sale.items.length} item${sale.items.length == 1 ? '' : 's'} sold',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.subtext(context)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Read-only detail sheet ──────────────────────────────────────────────────

class _SaleDetailSheet extends StatelessWidget {
  final DailySale sale;
  final VoidCallback onEdit;

  const _SaleDetailSheet({required this.sale, required this.onEdit});

  Widget _summaryChip(
      BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: color)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final balanced = sale.isBalanced;
    final balColor = balanced ? AppTheme.success : AppTheme.error;

    // Resolve linked invoices once for the whole build.
    final allInvoices = provider.invoices;
    final linkedInvoices = sale.linkedInvoiceIds
        .map((id) =>
            allInvoices.cast<Invoice?>().firstWhere((i) => i?.id == id,
                orElse: () => null))
        .whereType<Invoice>()
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sale.title != null &&
                          sale.title!.trim().isNotEmpty) ...[
                        Text(
                          sale.title!,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onCard(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          Fmt.date(sale.date),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtext(context)),
                        ),
                      ] else
                        Text(
                          Fmt.date(sale.date),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onCard(context)),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calculate_outlined, size: 20),
                  tooltip: 'Cash Counter (this entry)',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CashDenominationScreen(
                          expectedAmount: sale.expectedCash),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 4),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),

          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Day Summary Card ──────────────────────────────────
                _DaySummaryCard(
                  sale: sale,
                  linkedInvoices: linkedInvoices,
                  currency: currency,
                ),
                const SizedBox(height: 20),

                if (sale.items.isNotEmpty) ...[
                  _SectionLabel('Items Sold'),
                  const SizedBox(height: 8),
                  ...sale.items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.outline(context), width: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.itemName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onCard(context)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.quantity % 1 == 0 ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2)} × ${Fmt.currencyAmount(item.rate, currency)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.subtext(context)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                Fmt.currencyAmount(item.total, currency),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total Sales: ${Fmt.currencyAmount(sale.totalSales, currency)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                _SectionLabel('Money Received'),
                const SizedBox(height: 8),
                Builder(builder: (ctx) {
                  final allMethods =
                      ctx.read<AppProvider>().profile.allPaymentMethods;
                  PaymentMethod? find(String id) =>
                      allMethods.cast<PaymentMethod?>().firstWhere(
                            (m) => m?.id == id,
                            orElse: () => null,
                          );
                  final entries = sale.paymentBreakdown.entries
                      .where((e) => e.value > 0)
                      .toList();
                  if (entries.isEmpty) {
                    return Text('No payments recorded.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(ctx)));
                  }
                  final rows = <Widget>[];
                  for (var i = 0; i < entries.length; i += 2) {
                    if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
                    final e1 = entries[i];
                    final m1 = find(e1.key);
                    final e2 =
                        i + 1 < entries.length ? entries[i + 1] : null;
                    final m2 = e2 != null ? find(e2.key) : null;
                    rows.add(Row(children: [
                      Expanded(
                        child: _ReadOnlyAmountTile(
                          label: m1?.name ?? e1.key,
                          icon: _pmIcon(
                              m1?.type ?? PaymentMethodType.other),
                          color: _pmColor(
                              m1?.type ?? PaymentMethodType.other),
                          value: Fmt.currencyAmount(e1.value, currency),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (e2 != null)
                        Expanded(
                          child: _ReadOnlyAmountTile(
                            label: m2?.name ?? e2.key,
                            icon: _pmIcon(
                                m2?.type ?? PaymentMethodType.other),
                            color: _pmColor(
                                m2?.type ?? PaymentMethodType.other),
                            value:
                                Fmt.currencyAmount(e2.value, currency),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ]));
                  }
                  return Column(children: rows);
                }),

                // ── Linked Client Bills (read-only) ───────────────────
                if (linkedInvoices.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionLabel('Linked Client Bills'),
                  const SizedBox(height: 8),
                  ...linkedInvoices.map((inv) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary
                              .withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.2),
                              width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                    Icons.receipt_outlined,
                                    size: 14,
                                    color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${inv.invoiceNumber}${inv.client != null ? ' · ${inv.client!.displayName}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600),
                                  ),
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2),
                                  decoration: BoxDecoration(
                                    color: inv.status ==
                                            InvoiceStatus.paid
                                        ? AppTheme.success
                                            .withValues(alpha: 0.1)
                                        : AppTheme.primary
                                            .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(inv.status.label,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: inv.status ==
                                                  InvoiceStatus.paid
                                              ? AppTheme.success
                                              : AppTheme.primary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _summaryChip(
                                      context,
                                      'Grand Total',
                                      Fmt.currencyAmount(
                                          inv.grandTotal, currency),
                                      AppTheme.primary),
                                ),
                                const SizedBox(width: 8),
                                if (inv.totalDiscount > 0)
                                  Expanded(
                                    child: _summaryChip(
                                        context,
                                        'Discount',
                                        Fmt.currencyAmount(
                                            inv.totalDiscount,
                                            currency),
                                        AppTheme.error),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _summaryChip(
                                      context,
                                      'Received',
                                      Fmt.currencyAmount(
                                          inv.cashReceived,
                                          currency),
                                      AppTheme.success),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                ],

                if (sale.expenses.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionLabel('Daily Expenses'),
                  const SizedBox(height: 8),
                  ...sale.expenses.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.outline(context), width: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.label,
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.onCard(context)),
                              ),
                            ),
                            Text(
                              Fmt.currencyAmount(e.amount, currency),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.error),
                            ),
                            if (e.receiptBase64 != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.image_outlined,
                                    size: 18, color: AppTheme.primary),
                                tooltip: 'View receipt',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                          base64Decode(e.receiptBase64!),
                                          fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total Expenses: ${Fmt.currencyAmount(sale.totalExpenses, currency)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.error),
                    ),
                  ),
                ],

                // Reconciliation summary
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: balColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: balColor.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Column(
                    children: [
                      reconRow('Total Sales',
                          Fmt.currencyAmount(sale.totalSales, currency),
                          AppTheme.primary),
                      const SizedBox(height: 6),
                      reconRow('Total Received',
                          Fmt.currencyAmount(sale.totalReceived, currency),
                          AppTheme.onCard(context)),
                      if (sale.totalExpenses > 0) ...[
                        const SizedBox(height: 6),
                        reconRow(
                          'Daily Expenses',
                          '− ${Fmt.currencyAmount(sale.totalExpenses, currency)}',
                          AppTheme.error,
                        ),
                      ],
                      if (sale.bankReceived > 0) ...[
                        const SizedBox(height: 6),
                        reconRow(
                          'Digital Payments (UPI/Bank)',
                          '− ${Fmt.currencyAmount(sale.bankReceived, currency)}',
                          AppTheme.onCard(context),
                        ),
                      ],
                      const SizedBox(height: 4),
                      reconRow(
                        'Expected Cash in Hand',
                        Fmt.currencyAmount(sale.expectedCash, currency),
                        const Color(0xFF0D9488),
                        bold: true,
                      ),
                      Divider(
                          height: 14,
                          color: balColor.withValues(alpha: 0.3)),
                      reconRow(
                        balanced
                            ? 'Balanced ✓'
                            : sale.difference > 0
                                ? 'Short by'
                                : 'Extra by',
                        Fmt.currencyAmount(sale.difference.abs(), currency),
                        balColor,
                        bold: true,
                      ),
                    ],
                  ),
                ),

                if (sale.notes != null && sale.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionLabel('Notes'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.outline(context), width: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(sale.notes!,
                        style: TextStyle(color: AppTheme.onCard(context))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyAmountTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String value;

  const _ReadOnlyAmountTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context)),
          ),
        ],
      ),
    );
  }
}

// ── Entry sheet (create / edit) ───────────────────────────────────────────────

class _SaleEntrySheet extends StatefulWidget {
  final DailySale? sale;

  const _SaleEntrySheet({this.sale});

  @override
  State<_SaleEntrySheet> createState() => _SaleEntrySheetState();
}

class _SaleEntrySheetState extends State<_SaleEntrySheet> {
  final _uuid = const Uuid();
  late DateTime _date;
  late TextEditingController _titleCtrl;
  late List<_ItemRow> _rows;
  // One controller per payment method id, initialised in didChangeDependencies.
  final Map<String, TextEditingController> _paymentCtrls = {};
  bool _paymentCtrlsReady = false;
  late TextEditingController _notesCtrl;
  late List<_ExpenseEntry> _expenseRows;
  late Set<String> _linkedInvoiceIds;

  // ── Stock Count mode ───────────────────────────────────────────────
  bool _isStockAuditMode = false;
  List<_AuditItemGroup> _auditGroups = [];
  // Which shop's stock is being counted — relevant when the user has access
  // to more than one shop. Defaults to this device's own shop.
  String? _auditShopId;

  // Above this many audit rows, category sections start collapsed so the
  // sheet doesn't have to build hundreds/thousands of audit cards at once.
  static const _kAuditAutoExpandThreshold = 30;

  // Above this many rows in a single category, that category's audit cards
  // are rendered in a bounded-height, truly virtualized ListView instead of
  // being laid out all at once by ExpansionTile's Column.
  static const _kAuditVirtualizeThreshold = 20;

  @override
  void initState() {
    super.initState();
    final s = widget.sale;
    _date = s?.date ?? DateTime.now();
    _titleCtrl = TextEditingController(text: s?.title ?? '');
    _rows = s == null
        ? [_ItemRow(id: _uuid.v4())]
        : s.items
            .map((i) => _ItemRow(
                  id: i.id,
                  itemName: i.itemName,
                  itemId: i.itemId,
                  qty: i.quantity.toString(),
                  rate: i.rate.toString(),
                ))
            .toList();
    _linkedInvoiceIds = Set<String>.from(s?.linkedInvoiceIds ?? []);
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _expenseRows = s?.expenses
            .map((e) => _ExpenseEntry(
                  id: e.id,
                  label: e.label,
                  amount: e.amount.toString(),
                  receiptBase64: e.receiptBase64,
                ))
            .toList() ??
        [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paymentCtrlsReady) return;
    _paymentCtrlsReady = true;
    final provider = context.read<AppProvider>();
    final shopId = provider.activeShopId ?? '';
    final methods = provider.profile.paymentMethodsForShop(shopId);
    final s = widget.sale;
    for (final m in methods) {
      final existing = s?.paymentBreakdown[m.id] ?? 0;
      _paymentCtrls[m.id] =
          TextEditingController(text: existing == 0 ? '' : existing.toString());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _paymentCtrls.values) {
      c.dispose();
    }
    _notesCtrl.dispose();
    for (final g in _auditGroups) {
      g.dispose();
    }
    for (final e in _expenseRows) {
      e.dispose();
    }
    super.dispose();
  }

  void _toggleAuditMode(bool on, List<ServiceItem> serviceItems) {
    setState(() {
      _isStockAuditMode = on;
      if (on && _auditGroups.isEmpty) {
        _auditShopId ??= context.read<AppProvider>().currentShopId;
        _auditGroups = _buildAuditGroups(serviceItems, _auditShopId);
      }
    });
  }

  /// Switches which shop's stock is being counted — discards any
  /// in-progress closing-stock entries since they belonged to the old shop.
  void _changeAuditShop(String? shopId, List<ServiceItem> serviceItems) {
    setState(() {
      _auditShopId = shopId;
      for (final g in _auditGroups) {
        g.dispose();
      }
      _auditGroups = _buildAuditGroups(serviceItems, shopId);
    });
  }

  List<_AuditItemGroup> _buildAuditGroups(
      List<ServiceItem> serviceItems, String? shopId) {
    final groups = <_AuditItemGroup>[];
    for (final item in serviceItems) {
      if (item.hasVariants) {
        final variantRows = item.variants
            .where((v) => v.isTrackingStock && v.stockFor(shopId) > 0)
            .map((v) => _AuditRow(
                  variantId: v.id,
                  variantName: v.name,
                  openingStock: v.stockFor(shopId),
                  rate: v.rate,
                ))
            .toList();
        if (variantRows.isNotEmpty) {
          groups.add(_AuditItemGroup(
            itemId: item.id,
            itemName: item.name,
            category: item.category,
            rows: variantRows,
          ));
        }
      } else if (item.isTrackingStock && item.stockFor(shopId) > 0) {
        groups.add(_AuditItemGroup(
          itemId: item.id,
          itemName: item.name,
          category: item.category,
          rows: [
            _AuditRow(
              openingStock: item.stockFor(shopId),
              rate: item.rate,
            )
          ],
        ));
      }
    }
    return groups;
  }

  double get _totalExpenses => _expenseRows.fold(
      0.0, (s, e) => s + (double.tryParse(e.amountCtrl.text) ?? 0));

  void _addExpenseRow() =>
      setState(() => _expenseRows.add(_ExpenseEntry(id: _uuid.v4())));

  Future<void> _pickExpenseReceipt(_ExpenseEntry entry) async {
    if (entry.receiptBase64 != null) {
      // Already has a receipt — show options
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View receipt'),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Replace — camera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Replace — gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: const Text('Remove receipt',
                    style: TextStyle(color: AppTheme.error)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (action == 'view') {
        _viewReceipt(entry.receiptBase64!);
        return;
      }
      if (action == 'remove') {
        setState(() => entry.receiptBase64 = null);
        return;
      }
      if (action == null) return;
      final source =
          action == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() => entry.receiptBase64 = base64Encode(bytes));
    } else {
      // No receipt yet — pick source
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() => entry.receiptBase64 = base64Encode(bytes));
    }
  }

  void _viewReceipt(String base64) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(base64Decode(base64), fit: BoxFit.contain),
        ),
      ),
    );
  }

  double get _totalSales => _isStockAuditMode
      ? _auditGroups.fold(
          0.0, (s, g) => s + g.rows.fold(0.0, (rs, r) => rs + r.totalValue))
      : _rows.fold(0.0,
          (s, r) => s + (double.tryParse(r.qty) ?? 0) * (double.tryParse(r.rate) ?? 0));

  double get _totalReceived => _paymentCtrls.values
      .fold(0.0, (s, c) => s + (double.tryParse(c.text) ?? 0));

  /// Amount entered against non-cash payment methods (UPI, bank, etc.).
  double get _nonCashReceived {
    final shopId = context.read<AppProvider>().activeShopId ?? '';
    final methods = context.read<AppProvider>().profile.paymentMethodsForShop(shopId);
    return methods.where((m) => !m.isCash).fold(
        0.0, (s, m) => s + (double.tryParse(_paymentCtrls[m.id]?.text ?? '') ?? 0));
  }

  /// Cash that should remain in the till at day's end: total sales minus
  /// non-cash collections (UPI/bank/etc.), minus expenses — which are
  /// typically paid out of the cash drawer.
  double get _expectedCash => _totalSales - _totalExpenses - _nonCashReceived;

  // Total sales vs. money recorded as received, after accounting for cash
  // spent on expenses — since the cash entered is usually counted *after*
  // paying expenses out of the till.
  double get _difference => (_totalSales - _totalExpenses) - _totalReceived;
  bool get _isBalanced => _difference.abs() < 0.01;

  /// Returns category-grouped ExpansionTile sections for the stock audit UI.
  List<Widget> _buildCategorySections(String currency) {
    // Group audit items by category; null category → 'Other'
    final Map<String, List<_AuditItemGroup>> byCategory = {};
    for (final g in _auditGroups) {
      final key = (g.category?.trim().isNotEmpty == true) ? g.category! : 'Other';
      byCategory.putIfAbsent(key, () => []).add(g);
    }

    // Sort: named categories first (alphabetically), 'Other' last
    final sortedKeys = byCategory.keys.toList()
      ..sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        return a.compareTo(b);
      });

    return sortedKeys.map((cat) {
      final groups = byCategory[cat]!;
      final catTotal = groups.fold(
          0.0, (s, g) => s + g.rows.fold(0.0, (rs, r) => rs + r.totalValue));

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.outline(context), width: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Remove the default ExpansionTile divider
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            // With large catalogs, expanding every category by default would
            // build hundreds/thousands of audit cards (each with its own
            // TextField) in a single frame and freeze/crash the app.
            initiallyExpanded:
                _auditGroups.length <= _kAuditAutoExpandThreshold,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            backgroundColor: AppTheme.card(context),
            collapsedBackgroundColor: AppTheme.card(context),
            title: Row(
              children: [
                const Icon(Icons.label_outline, size: 15, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  cat,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${groups.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
                ),
                const Spacer(),
                if (catTotal > 0)
                  Text(
                    Fmt.currencyAmount(catTotal, currency),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
              ],
            ),
            children: groups.length > _kAuditVirtualizeThreshold
                ? [
                    SizedBox(
                      height: 400,
                      child: ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (_, i) => _AuditGroupCard(
                          key: ValueKey(groups[i].itemId),
                          group: groups[i],
                          currency: currency,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ),
                  ]
                : groups
                    .map((g) => _AuditGroupCard(
                          key: ValueKey(g.itemId),
                          group: g,
                          currency: currency,
                          onChanged: () => setState(() {}),
                        ))
                    .toList(),
          ),
        ),
      );
    }).toList();
  }

  void _addRow() => setState(() => _rows.add(_ItemRow(id: _uuid.v4())));

  Future<void> _scanAndAddRow() async {
    final barcode = await scanBarcode(context, title: 'Scan Item');
    if (!mounted || barcode == null) return;

    final provider = context.read<AppProvider>();
    final result = await provider.findByBarcode(barcode);
    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No product found for barcode: $barcode'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }

    final s = result.item;
    final currency = provider.profile.currency;
    String name;
    double rate;

    if (result.variant != null) {
      // Barcode matched a specific variant directly
      final v = result.variant!;
      name = '${s.name} (${v.name})';
      rate = v.rate;
    } else if (s.hasVariants) {
      // Item-level barcode — ask which variant
      final variant = await showDialog<ProductVariant>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.name),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a variant:',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 10),
              ...s.variants.map((v) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('$currency ${v.rate.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.primary)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.pop(ctx, v),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (!mounted || variant == null) return;
      name = '${s.name} (${variant.name})';
      rate = variant.rate;
    } else {
      name = s.name;
      rate = s.rate;
    }

    // Show qty prompt — user confirms item name and enters quantity
    if (!mounted) return;
    final result2 = await showDialog<({double qty, double rate})>(
      context: context,
      builder: (_) => _ScannedItemQtyDialog(
        itemName: name,
        rate: rate,
        currency: currency,
      ),
    );
    if (!mounted || result2 == null) return;

    // Find if this item already exists in the rows (same name) — increment qty
    final existingIndex =
        _rows.indexWhere((r) => r.itemName == name);
    if (existingIndex != -1) {
      final existing = _rows[existingIndex];
      final prevQty = double.tryParse(existing.qty) ?? 0;
      setState(() {
        existing.qty = (prevQty + result2.qty).toStringAsFixed(
            (prevQty + result2.qty) % 1 == 0 ? 0 : 2);
        existing.rate = result2.rate.toString();
      });
    } else {
      setState(() {
        final row = _ItemRow(
          id: _uuid.v4(),
          itemName: name,
          itemId: s.id,
          qty: result2.qty.toStringAsFixed(result2.qty % 1 == 0 ? 0 : 2),
          rate: result2.rate > 0 ? result2.rate.toString() : '',
        );
        _rows.add(row);
      });
    }
  }

  void _removeRow(int i) {
    if (_rows.length > 1) setState(() => _rows.removeAt(i));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final provider = context.read<AppProvider>();

    List<DailySaleItem> items;
    if (_isStockAuditMode) {
      // Build items from stock audit: sold = opening − closing (clamped ≥ 0)
      items = [];
      for (final g in _auditGroups) {
        for (final r in g.rows) {
          if (r.closingCtrl.text.trim().isNotEmpty && r.sold > 0) {
            final name = r.variantName != null
                ? '${g.itemName} (${r.variantName})'
                : g.itemName;
            items.add(DailySaleItem(
              id: _uuid.v4(),
              itemName: name,
              itemId: g.itemId,
              quantity: r.sold,
              rate: r.rate,
            ));
          }
        }
      }

      // Update stock on hand for every row whose closing stock was entered
      final shopId = _auditShopId ?? provider.currentShopId;
      if (shopId != null) {
        for (final g in _auditGroups) {
          for (final r in g.rows) {
            if (r.closingCtrl.text.trim().isNotEmpty) {
              provider.updateItemStock(g.itemId, r.closingStock,
                  variantId: r.variantId, shopId: shopId);
            }
          }
        }
      }
    } else {
      items = _rows
          .where((r) =>
              r.itemName.trim().isNotEmpty &&
              (double.tryParse(r.qty) ?? 0) > 0)
          .map((r) => DailySaleItem(
                id: r.id,
                itemName: r.itemName.trim(),
                itemId: r.itemId,
                quantity: double.tryParse(r.qty) ?? 0,
                rate: double.tryParse(r.rate) ?? 0,
              ))
          .toList();
    }

    final expenses = _expenseRows
        .where((e) => (double.tryParse(e.amountCtrl.text) ?? 0) > 0)
        .map((e) => DailySaleExpense(
              id: e.id,
              label: e.labelCtrl.text.trim().isEmpty
                  ? 'Expense'
                  : e.labelCtrl.text.trim(),
              amount: double.tryParse(e.amountCtrl.text) ?? 0,
              receiptBase64: e.receiptBase64,
            ))
        .toList();

    final sale = DailySale(
      id: widget.sale?.id ?? _uuid.v4(),
      date: _date,
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      items: items,
      paymentBreakdown: {
        for (final e in _paymentCtrls.entries)
          if ((double.tryParse(e.value.text) ?? 0) > 0)
            e.key: double.tryParse(e.value.text)!,
      },
      expenses: expenses,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.sale?.createdAt ?? DateTime.now(),
      linkedInvoiceIds: _linkedInvoiceIds.toList(),
    );

    provider.saveDailySale(sale);
    Navigator.pop(context);
  }

  Future<void> _pickLinkedInvoices(
      BuildContext ctx, List<Invoice> dateInvoices) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InvoicePickerSheet(
        invoices: dateInvoices,
        initialSelected: Set<String>.from(_linkedInvoiceIds),
        currency: context.read<AppProvider>().profile.currency,
      ),
    );
    if (result == null || !mounted) return;

    // For any newly linked invoice that has a discount, offer to add it
    // as a daily expense row.
    final newlyLinked = result.difference(_linkedInvoiceIds);
    setState(() => _linkedInvoiceIds
      ..clear()
      ..addAll(result));

    for (final id in newlyLinked) {
      final inv =
          dateInvoices.cast<Invoice?>().firstWhere((i) => i?.id == id);
      if (inv == null || inv.totalDiscount <= 0) continue;
      final clientName =
          inv.client?.displayName ?? inv.invoiceNumber;
      final label = 'Discount – $clientName';
      final already =
          _expenseRows.any((e) => e.labelCtrl.text == label);
      if (already || !mounted) continue;
      final add = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Track Discount as Expense?'),
          content: Text(
            'Invoice #${inv.invoiceNumber} has a discount of '
            '${Fmt.currencyAmount(inv.totalDiscount, context.read<AppProvider>().profile.currency)}. '
            'Add it as a daily expense?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('Skip')),
            FilledButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Add')),
          ],
        ),
      );
      if (add == true && mounted) {
        setState(() => _expenseRows.add(_ExpenseEntry(
              id: const Uuid().v4(),
              label: label,
              amount: inv.totalDiscount.toStringAsFixed(2),
            )));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final serviceItems = provider.serviceItems;
    final balColor = _isBalanced ? AppTheme.success : AppTheme.error;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(
              children: [
                Text(
                  widget.sale == null ? 'New Sales Entry' : 'Edit Sales Entry',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context)),
                ),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 4),
                ElevatedButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),

          // Mode toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Items Sold'),
                  icon: Icon(Icons.sell_outlined, size: 14),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Stock Count'),
                  icon: Icon(Icons.inventory_2_outlined, size: 14),
                ),
              ],
              selected: {_isStockAuditMode},
              onSelectionChanged: (v) =>
                  _toggleAuditMode(v.first, serviceItems),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Date picker
                _SectionLabel('Date'),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppTheme.outline(context), width: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          Fmt.date(_date),
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onCard(context)),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            color: AppTheme.subtext(context)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                _SectionLabel('Title (optional)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Morning Shift, Counter 1',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),

                if (_isStockAuditMode) ...[
                  // ── Stock Count mode ──────────────────────────────
                  _SectionLabel('Stock Count'),
                  const SizedBox(height: 4),
                  if (provider.allShops.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _auditShopId ?? provider.currentShopId,
                      decoration: InputDecoration(
                        labelText: 'Shop',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: provider.allShops
                          .map((s) => DropdownMenuItem(
                                value: s.shopId,
                                child: Text(s.shopName),
                              ))
                          .toList(),
                      onChanged: (v) => _changeAuditShop(v, serviceItems),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_auditGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Enable stock tracking on your products in Settings → Products to use this mode.',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.subtext(context)),
                      ),
                    )
                  else ...[
                    ..._buildCategorySections(currency),
                    if (_totalSales > 0) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Est. Sales: ${Fmt.currencyAmount(_totalSales, currency)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ],
                ] else ...[
                  // ── Items Sold mode ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionLabel('Items Sold'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                            tooltip: 'Scan barcode',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _scanAndAddRow,
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._rows.asMap().entries.map((e) => _ItemRowWidget(
                        key: ValueKey(e.value.id),
                        row: e.value,
                        index: e.key,
                        serviceItems: serviceItems,
                        currency: currency,
                        canRemove: _rows.length > 1,
                        onRemove: () => _removeRow(e.key),
                        onChanged: () => setState(() {}),
                      )),
                  if (_rows.any((r) =>
                      r.itemName.trim().isNotEmpty &&
                      (double.tryParse(r.qty) ?? 0) > 0)) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total Sales: ${Fmt.currencyAmount(_totalSales, currency)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.primary),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 20),
                _SectionLabel('Money Received'),
                const SizedBox(height: 8),

                Builder(builder: (ctx) {
                  final shopId =
                      context.read<AppProvider>().activeShopId ?? '';
                  final methods =
                      provider.profile.paymentMethodsForShop(shopId);
                  final rows = <Widget>[];
                  for (var i = 0; i < methods.length; i += 2) {
                    if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
                    final m1 = methods[i];
                    final m2 =
                        i + 1 < methods.length ? methods[i + 1] : null;
                    rows.add(Row(children: [
                      Expanded(
                        child: _AmountField(
                          controller: _paymentCtrls[m1.id] ??
                              TextEditingController(),
                          label: m1.name,
                          icon: _pmIcon(m1.type),
                          color: _pmColor(m1.type),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (m2 != null)
                        Expanded(
                          child: _AmountField(
                            controller: _paymentCtrls[m2.id] ??
                                TextEditingController(),
                            label: m2.name,
                            icon: _pmIcon(m2.type),
                            color: _pmColor(m2.type),
                            onChanged: (_) => setState(() {}),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ]));
                  }
                  return Column(children: rows);
                }),

                // ── Daily Expenses ────────────────────────────────────
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionLabel('Daily Expenses'),
                    TextButton.icon(
                      onPressed: _addExpenseRow,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_expenseRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'No expenses recorded for the day.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context)),
                    ),
                  )
                else ...[
                  ..._expenseRows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppTheme.outline(context), width: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        color: AppTheme.card(context),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: e.labelCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Description',
                                isDense: true,
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: e.amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                isDense: true,
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          // Receipt attachment button
                          IconButton(
                            icon: e.receiptBase64 != null
                                ? const Icon(Icons.image_outlined,
                                    size: 20, color: AppTheme.primary)
                                : Icon(Icons.attach_file_outlined,
                                    size: 20,
                                    color: AppTheme.subtext(context)),
                            tooltip: e.receiptBase64 != null
                                ? 'View / change receipt'
                                : 'Attach receipt',
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _pickExpenseReceipt(e),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 16, color: AppTheme.subtext(context)),
                            onPressed: () =>
                                setState(() => _expenseRows.removeAt(i)),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_totalExpenses > 0) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total Expenses: ${Fmt.currencyAmount(_totalExpenses, currency)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error),
                      ),
                    ),
                  ],
                ],

                // Reconciliation summary
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: balColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: balColor.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Column(
                    children: [
                      reconRow('Total Sales',
                          Fmt.currencyAmount(_totalSales, currency),
                          AppTheme.primary),
                      const SizedBox(height: 6),
                      reconRow('Total Received',
                          Fmt.currencyAmount(_totalReceived, currency),
                          AppTheme.onCard(context)),
                      if (_totalExpenses > 0) ...[
                        const SizedBox(height: 6),
                        reconRow(
                          'Daily Expenses',
                          '− ${Fmt.currencyAmount(_totalExpenses, currency)}',
                          AppTheme.error,
                        ),
                      ],
                      if (_nonCashReceived > 0) ...[
                        const SizedBox(height: 6),
                        reconRow(
                          'Digital Payments (UPI/Bank)',
                          '− ${Fmt.currencyAmount(_nonCashReceived, currency)}',
                          AppTheme.onCard(context),
                        ),
                      ],
                      const SizedBox(height: 4),
                      reconRow(
                        'Expected Cash in Hand',
                        Fmt.currencyAmount(_expectedCash, currency),
                        const Color(0xFF0D9488),
                        bold: true,
                      ),
                      Divider(
                          height: 14,
                          color: balColor.withValues(alpha: 0.3)),
                      reconRow(
                        _isBalanced
                            ? 'Balanced ✓'
                            : _difference > 0
                                ? 'Short by'
                                : 'Extra by',
                        Fmt.currencyAmount(_difference.abs(), currency),
                        balColor,
                        bold: true,
                      ),
                    ],
                  ),
                ),

                // ── Linked Client Bills ───────────────────────────────
                const SizedBox(height: 20),
                Builder(builder: (ctx) {
                  final dateInvoices =
                      provider.invoicesForDate(_date);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionLabel('Linked Client Bills'),
                          if (dateInvoices.isNotEmpty)
                            TextButton.icon(
                              onPressed: () =>
                                  _pickLinkedInvoices(
                                      ctx, dateInvoices),
                              icon: const Icon(Icons.link, size: 15),
                              label: const Text('Select'),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4)),
                            ),
                        ],
                      ),
                      if (dateInvoices.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 4, bottom: 2),
                          child: Text(
                            'No invoices found for this date.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtext(ctx)),
                          ),
                        )
                      else if (_linkedInvoiceIds.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 4, bottom: 2),
                          child: Text(
                            '${dateInvoices.length} invoice${dateInvoices.length == 1 ? '' : 's'} on this date — tap Select to link.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtext(ctx)),
                          ),
                        )
                      else
                        ...dateInvoices
                            .where((inv) =>
                                _linkedInvoiceIds.contains(inv.id))
                            .map((inv) => _LinkedInvoiceTile(
                                  invoice: inv,
                                  currency: currency,
                                  onRemove: () => setState(() =>
                                      _linkedInvoiceIds.remove(inv.id)),
                                )),
                    ],
                  );
                }),

                const SizedBox(height: 20),
                _SectionLabel('Notes (optional)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Any remarks for the day…',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Invoice picker bottom sheet ───────────────────────────────────────────────

class _InvoicePickerSheet extends StatefulWidget {
  final List<Invoice> invoices;
  final Set<String> initialSelected;
  final String currency;
  const _InvoicePickerSheet({
    required this.invoices,
    required this.initialSelected,
    required this.currency,
  });

  @override
  State<_InvoicePickerSheet> createState() => _InvoicePickerSheetState();
}

class _InvoicePickerSheetState extends State<_InvoicePickerSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Link Client Bills',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onCard(context))),
                ),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 4),
                FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Done')),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: widget.invoices.length,
              itemBuilder: (_, i) {
                final inv = widget.invoices[i];
                final linked = _selected.contains(inv.id);
                final hasDiscount = inv.totalDiscount > 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: linked
                          ? AppTheme.primary.withValues(alpha: 0.5)
                          : AppTheme.outline(context),
                      width: linked ? 1.4 : 0.8,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: linked,
                    onChanged: (v) => setState(() =>
                        v == true
                            ? _selected.add(inv.id)
                            : _selected.remove(inv.id)),
                    title: Text(
                      '${inv.invoiceNumber}${inv.client != null ? ' · ${inv.client!.displayName}' : ''}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Fmt.currencyAmount(inv.grandTotal, widget.currency),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.onCard(context),
                              fontWeight: FontWeight.w500),
                        ),
                        if (hasDiscount)
                          Text(
                            'Discount: ${Fmt.currencyAmount(inv.totalDiscount, widget.currency)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.error),
                          ),
                      ],
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: inv.status == InvoiceStatus.paid
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(inv.status.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: inv.status == InvoiceStatus.paid
                                  ? AppTheme.success
                                  : AppTheme.primary)),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.primary,
                    contentPadding:
                        const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Linked invoice tile (shown in entry form) ─────────────────────────────────

class _LinkedInvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final String currency;
  final VoidCallback onRemove;

  const _LinkedInvoiceTile({
    required this.invoice,
    required this.currency,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_outlined,
              size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${invoice.invoiceNumber}${invoice.client != null ? ' · ${invoice.client!.displayName}' : ''}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Text(
                      Fmt.currencyAmount(invoice.grandTotal, currency),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtext(context)),
                    ),
                    if (invoice.totalDiscount > 0) ...[
                      Text(' · ',
                          style: TextStyle(
                              color: AppTheme.subtext(context))),
                      Text(
                        'Discount ${Fmt.currencyAmount(invoice.totalDiscount, currency)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.error),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
            color: AppTheme.subtext(context),
          ),
        ],
      ),
    );
  }
}

// ── Day Summary card (shown at top of _SaleDetailSheet) ──────────────────────

class _DaySummaryCard extends StatelessWidget {
  final DailySale sale;
  final List<Invoice> linkedInvoices;
  final String currency;

  const _DaySummaryCard({
    required this.sale,
    required this.linkedInvoices,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    // ── Compute totals ──────────────────────────────────────────────
    final shopSales = sale.totalSales;
    final clientSales =
        linkedInvoices.fold(0.0, (s, i) => s + i.grandTotal);
    final totalSales = shopSales + clientSales;

    final shopCash = sale.totalReceived;

    // Payments from linked invoices whose payment date matches this day.
    final saleDay = DateTime(
        sale.date.year, sale.date.month, sale.date.day);
    double invoiceCash = 0;
    for (final inv in linkedInvoices) {
      for (final p in inv.payments) {
        final pd =
            DateTime(p.date.year, p.date.month, p.date.day);
        if (pd == saleDay) invoiceCash += p.amount;
      }
    }
    final totalCashInflow = shopCash + invoiceCash;

    final discountsGiven =
        linkedInvoices.fold(0.0, (s, i) => s + i.totalDiscount);
    final dailyExpenses = sale.totalExpenses;
    final totalOutflow = discountsGiven + dailyExpenses;
    final netCash = totalCashInflow - totalOutflow;

    // ── Stock movement per item ─────────────────────────────────────
    final Map<String, double> shopQty = {};
    for (final item in sale.items) {
      shopQty[item.itemName.toLowerCase()] =
          (shopQty[item.itemName.toLowerCase()] ?? 0) + item.quantity;
    }
    final Map<String, double> clientQty = {};
    for (final inv in linkedInvoices) {
      for (final li in inv.items) {
        final k = li.description.toLowerCase();
        clientQty[k] = (clientQty[k] ?? 0) + li.quantity;
      }
    }
    final allItemKeys = {
      ...shopQty.keys,
      ...clientQty.keys,
    };

    // ── UI ──────────────────────────────────────────────────────────
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.summarize_outlined,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Day Summary · ${Fmt.date(sale.date)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Sales ──────────────────────────────────────────────
          _summaryRow(context, 'Shop Sales',
              Fmt.currencyAmount(shopSales, currency), null),
          if (linkedInvoices.isNotEmpty) ...[
            const SizedBox(height: 4),
            _summaryRow(
                context,
                'Client Invoice Sales',
                Fmt.currencyAmount(clientSales, currency),
                null),
          ],
          const SizedBox(height: 4),
          _summaryRow(
              context,
              'Total Sales',
              Fmt.currencyAmount(totalSales, currency),
              AppTheme.primary,
              bold: true),
          const Divider(height: 16),

          // ── Cash Inflow ─────────────────────────────────────────
          _summaryRow(context, 'Shop Cash Received',
              Fmt.currencyAmount(shopCash, currency), null),
          if (invoiceCash > 0) ...[
            const SizedBox(height: 4),
            _summaryRow(
                context,
                'Invoice Payments (today)',
                Fmt.currencyAmount(invoiceCash, currency),
                null),
          ],
          const SizedBox(height: 4),
          _summaryRow(
              context,
              'Total Cash Inflow',
              Fmt.currencyAmount(totalCashInflow, currency),
              AppTheme.success,
              bold: true),

          if (discountsGiven > 0 || dailyExpenses > 0) ...[
            const Divider(height: 16),
            if (discountsGiven > 0) ...[
              _summaryRow(
                  context,
                  'Discounts Given',
                  '− ${Fmt.currencyAmount(discountsGiven, currency)}',
                  AppTheme.error),
              const SizedBox(height: 4),
            ],
            if (dailyExpenses > 0)
              _summaryRow(
                  context,
                  'Daily Expenses',
                  '− ${Fmt.currencyAmount(dailyExpenses, currency)}',
                  AppTheme.error),
          ],
          const Divider(height: 16),
          _summaryRow(
              context,
              'Net Cash',
              Fmt.currencyAmount(netCash, currency),
              netCash >= 0 ? const Color(0xFF0D9488) : AppTheme.error,
              bold: true),

          // ── Stock movement table ────────────────────────────────
          if (allItemKeys.isNotEmpty) ...[
            const Divider(height: 20),
            Text('Stock Movement',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.subtext(context),
                    letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    'Item',
                    'To Client',
                    'Shop Sale',
                    'Total',
                  ]
                      .map((h) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 4),
                            child: Text(h,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.subtext(
                                        context))),
                          ))
                      .toList(),
                ),
                ...allItemKeys.map((k) {
                  final cQty = clientQty[k] ?? 0;
                  final sQty = shopQty[k] ?? 0;
                  final display = k.length > 14
                      ? '${k.substring(0, 13)}…'
                      : k;
                  String fmtQty(double q) =>
                      q == 0
                          ? '—'
                          : q % 1 == 0
                              ? q.toStringAsFixed(0)
                              : q.toStringAsFixed(1);
                  return TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3),
                      child: Text(display,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.onCard(context))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3),
                      child: Text(fmtQty(cQty),
                          style: TextStyle(
                              fontSize: 11,
                              color: cQty > 0
                                  ? AppTheme.error
                                  : AppTheme.subtext(context))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3),
                      child: Text(fmtQty(sQty),
                          style: TextStyle(
                              fontSize: 11,
                              color: sQty > 0
                                  ? AppTheme.primary
                                  : AppTheme.subtext(context))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3),
                      child: Text(
                        fmtQty(cQty + sQty),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]);
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label,
      String value, Color? color,
      {bool bold = false}) {
    final c = color ?? AppTheme.onCard(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: bold ? c : AppTheme.subtext(context))),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                color: c)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Widget reconRow(String label, String value, Color color,
    {bool bold = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: color)),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color)),
    ],
  );
}

IconData _pmIcon(PaymentMethodType type) {
  switch (type) {
    case PaymentMethodType.cash:
      return Icons.payments_outlined;
    case PaymentMethodType.bankAccount:
      return Icons.account_balance_outlined;
    case PaymentMethodType.upi:
      return Icons.phone_android_outlined;
    case PaymentMethodType.other:
      return Icons.receipt_outlined;
  }
}

Color _pmColor(PaymentMethodType type) {
  switch (type) {
    case PaymentMethodType.cash:
      return AppTheme.success;
    case PaymentMethodType.bankAccount:
      return const Color(0xFF0891B2);
    case PaymentMethodType.upi:
      return const Color(0xFF7C3AED);
    case PaymentMethodType.other:
      return const Color(0xFF64748B);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.subtext(context),
            letterSpacing: 0.3),
      );
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  final ValueChanged<String> onChanged;

  const _AmountField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 18),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }
}

// ── Mutable row state ─────────────────────────────────────────────────────────

class _ItemRow {
  final String id;
  String itemName;
  String? itemId;
  String qty;
  String rate;

  _ItemRow({
    required this.id,
    this.itemName = '',
    this.itemId,
    this.qty = '',
    this.rate = '',
  });
}

class _ItemRowWidget extends StatefulWidget {
  final _ItemRow row;
  final int index;
  final List<ServiceItem> serviceItems;
  final String currency;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRowWidget({
    super.key,
    required this.row,
    required this.index,
    required this.serviceItems,
    required this.currency,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;
  late FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.row.itemName);
    _qtyCtrl = TextEditingController(text: widget.row.qty);
    _rateCtrl = TextEditingController(text: widget.row.rate);
    _nameFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _selectFromCatalog() async {
    final items = widget.serviceItems;
    if (items.isEmpty) return;
    final picked = await showModalBottomSheet<ServiceItem>(
      context: context,
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(
            leading: Icon(
              item.hasVariants
                  ? Icons.layers_outlined
                  : Icons.receipt_long_outlined,
              size: 18,
              color: AppTheme.primary,
            ),
            title: Text(item.name),
            subtitle: item.hasVariants
                ? Text('${item.variants.length} variants'
                    ' · from ${widget.currency} ${item.lowestVariantRate.toStringAsFixed(0)}')
                : item.rate > 0
                    ? Text('${widget.currency} ${item.rate}')
                    : null,
            onTap: () => Navigator.pop(ctx, item),
          );
        },
      ),
    );
    if (!mounted || picked == null) return;
    await _applyPickedItem(picked);
  }

  Future<void> _applyPickedItem(ServiceItem picked) async {
    String name = picked.name;
    double rate = picked.rate;

    if (picked.hasVariants) {
      final variant = await showDialog<ProductVariant>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(picked.name),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a variant:',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 10),
              ...picked.variants.map((v) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${widget.currency} ${v.rate.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.primary)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.pop(ctx, v),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (!mounted || variant == null) return;
      name = '${picked.name} (${variant.name})';
      rate = variant.rate;
    }

    widget.row.itemName = name;
    widget.row.itemId = picked.id;
    if (rate > 0) {
      widget.row.rate = rate.toString();
      _rateCtrl.text = widget.row.rate;
    }
    _nameCtrl.text = name;
    widget.onChanged();
  }

  double get _rowTotal =>
      (double.tryParse(_qtyCtrl.text) ?? 0) *
      (double.tryParse(_rateCtrl.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ServiceItemSearchField(
                  db: context.read<AppProvider>().db,
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  labelText: 'Item name',
                  onSelected: _applyPickedItem,
                  onChangedText: (v) {
                    widget.row.itemName = v;
                    widget.onChanged();
                  },
                  suffixIcon: widget.serviceItems.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.list_alt_outlined, size: 18),
                          onPressed: _selectFromCatalog,
                          tooltip: 'Pick from catalog',
                        )
                      : null,
                  itemBuilder: (ctx, s) => ListTile(
                    dense: true,
                    leading: Icon(
                      s.hasVariants
                          ? Icons.layers_outlined
                          : Icons.receipt_long_outlined,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    title: Text(s.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: s.hasVariants
                        ? Text(
                            '${s.variants.length} variants'
                            ' · from ${widget.currency} ${s.lowestVariantRate.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.subtext(ctx)))
                        : s.rate > 0
                            ? Text(
                                '${widget.currency} ${s.rate.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.primary))
                            : null,
                  ),
                ),
              ),
              if (widget.canRemove) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.close, size: 18,
                      color: AppTheme.subtext(context)),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,3}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) {
                    widget.row.qty = v;
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Rate',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) {
                    widget.row.rate = v;
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (_rowTotal > 0)
                Text(
                  Fmt.currencyAmount(_rowTotal, widget.currency),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Scanned item qty dialog ──────────────────────────────────────────────────

class _ScannedItemQtyDialog extends StatefulWidget {
  final String itemName;
  final double rate;
  final String currency;

  const _ScannedItemQtyDialog({
    required this.itemName,
    required this.rate,
    required this.currency,
  });

  @override
  State<_ScannedItemQtyDialog> createState() => _ScannedItemQtyDialogState();
}

class _ScannedItemQtyDialogState extends State<_ScannedItemQtyDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController();
    _rateCtrl = TextEditingController(
        text: widget.rate > 0 ? widget.rate.toString() : '');
    // Auto-focus qty field after frame builds
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _qtyCtrl.selection = TextSelection.collapsed(offset: 0));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final qty = double.tryParse(_qtyCtrl.text.trim());
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    if (qty == null || qty <= 0) return;
    Navigator.pop(context, (qty: qty, rate: rate));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Item Scanned'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name chip
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.itemName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Rate row
          TextField(
            controller: _rateCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Rate (${widget.currency})',
              prefixText: '${widget.currency} ',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          // Qty field
          TextField(
            controller: _qtyCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              labelText: 'Quantity *',
              hintText: 'e.g. 24',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Daily expense entry (mutable state) ─────────────────────────────────────

class _ExpenseEntry {
  final String id;
  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;
  String? receiptBase64;

  _ExpenseEntry({
    required this.id,
    String label = '',
    String amount = '',
    this.receiptBase64,
  })  : labelCtrl = TextEditingController(text: label),
        amountCtrl = TextEditingController(text: amount);

  void dispose() {
    labelCtrl.dispose();
    amountCtrl.dispose();
  }
}

/// Rejects keystrokes that would make the field's numeric value exceed [max].
/// Incomplete inputs (e.g. "0.", "-") are allowed through since they don't
/// yet parse to a number.
class _MaxValueInputFormatter extends TextInputFormatter {
  final double max;
  _MaxValueInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final parsed = double.tryParse(newValue.text);
    if (parsed != null && parsed > max) return oldValue;
    return newValue;
  }
}

// ─── Stock audit data classes ─────────────────────────────────────────────────

/// A single stock row — one per flat item, or one per variant.
class _AuditRow {
  final String? variantId;
  final String? variantName; // null for flat (non-variant) items
  final double openingStock;
  final double rate;
  final TextEditingController closingCtrl = TextEditingController();

  _AuditRow({
    this.variantId,
    this.variantName,
    required this.openingStock,
    required this.rate,
  });

  double get closingStock =>
      double.tryParse(closingCtrl.text.trim()) ?? openingStock;

  double get sold =>
      (openingStock - closingStock).clamp(0.0, double.infinity);

  double get totalValue => sold * rate;

  void dispose() => closingCtrl.dispose();
}

/// One card per product — contains one or more [_AuditRow]s.
class _AuditItemGroup {
  final String itemId;
  final String itemName;
  final String? category;
  final List<_AuditRow> rows;

  _AuditItemGroup({
    required this.itemId,
    required this.itemName,
    this.category,
    required this.rows,
  });

  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
  }
}

// ─── Stock audit group card ───────────────────────────────────────────────────

class _AuditGroupCard extends StatefulWidget {
  final _AuditItemGroup group;
  final String currency;
  final VoidCallback onChanged;

  const _AuditGroupCard({
    super.key,
    required this.group,
    required this.currency,
    required this.onChanged,
  });

  @override
  State<_AuditGroupCard> createState() => _AuditGroupCardState();
}

class _AuditGroupCardState extends State<_AuditGroupCard> {
  @override
  void initState() {
    super.initState();
    for (final r in widget.group.rows) {
      r.closingCtrl.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    for (final r in widget.group.rows) {
      r.closingCtrl.removeListener(_rebuild);
    }
    super.dispose();
  }

  void _rebuild() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final hasVariants = g.rows.any((r) => r.variantName != null);
    final totalSold = g.rows.fold(0.0, (s, r) => s + r.totalValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(
                  hasVariants
                      ? Icons.layers_outlined
                      : Icons.inventory_2_outlined,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.itemName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (totalSold > 0)
                  Text(
                    '${widget.currency} ${totalSold.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
              ],
            ),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(
              children: [
                if (hasVariants) const SizedBox(width: 80),
                Expanded(
                  child: Text('Opening',
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.subtext(context))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Closing',
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.subtext(context))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Sold',
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.subtext(context))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // One row per variant (or single row for flat item)
          ...g.rows.map((r) => _buildRow(context, r, hasVariants)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, _AuditRow r, bool showLabel) {
    final hasClosed = r.closingCtrl.text.trim().isNotEmpty;
    final sold = hasClosed ? r.sold : null;
    final isPositive = sold != null && sold > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          // Variant label (only for variant items)
          if (showLabel)
            SizedBox(
              width: 80,
              child: Text(
                r.variantName ?? '',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Opening (read-only)
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.outline(context), width: 0.8),
              ),
              child: Text(
                _fmt(r.openingStock),
                style: TextStyle(
                    fontSize: 13, color: AppTheme.subtext(context)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Closing (editable) — capped at opening stock, since closing
          // stock can't exceed what was on hand at the start of the day.
          Expanded(
            child: TextField(
              controller: r.closingCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.deny('-'),
                _MaxValueInputFormatter(r.openingStock),
              ],
              decoration: InputDecoration(
                hintText: _fmt(r.openingStock),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sold (calculated)
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isPositive
                    ? AppTheme.primary.withValues(alpha: 0.07)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isPositive
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : AppTheme.outline(context),
                    width: 0.8),
              ),
              child: Text(
                sold != null ? _fmt(sold) : '—',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? AppTheme.primary
                        : AppTheme.subtext(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
}

// ─── Chart data model ────────────────────────────────────────────────────────

class _BarDatum {
  final DateTime date;
  final double received;
  final DailySale? sale;
  const _BarDatum({required this.date, required this.received, this.sale});
}

// ─── Chart widget ────────────────────────────────────────────────────────────

class _SalesChart extends StatefulWidget {
  final List<DailySale> allSales;
  final String currency;
  final void Function(DailySale) onDrillDown;

  const _SalesChart({
    required this.allSales,
    required this.currency,
    required this.onDrillDown,
  });

  @override
  State<_SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<_SalesChart> {
  int? _selectedIndex;

  List<_BarDatum> _buildData() {
    final today = DateTime.now();
    return List.generate(30, (i) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 29 - i));
      final sale = widget.allSales.where((s) {
        final d = s.date;
        return d.year == date.year &&
            d.month == date.month &&
            d.day == date.day;
      }).firstOrNull;
      return _BarDatum(
          date: date, received: sale?.totalReceived ?? 0, sale: sale);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _buildData();
    final maxVal =
        data.fold(0.0, (m, d) => d.received > m ? d.received : m);
    final primary = Theme.of(context).colorScheme.primary;
    final sym = Fmt.currencySymbol(widget.currency);
    final sel =
        (_selectedIndex != null) ? data[_selectedIndex!] : null;

    return Container(
      color: AppTheme.card(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Last 30 Days',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context)),
                ),
                const Spacer(),
                if (sel != null && sel.sale != null) ...[
                  Text(Fmt.shortDate(sel.date),
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context))),
                  const SizedBox(width: 6),
                  Text(
                    '$sym${Fmt.compact(sel.received)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primary),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => widget.onDrillDown(sel.sale!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withAlpha(28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Details →',
                          style: TextStyle(
                              fontSize: 11,
                              color: primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else if (sel != null) ...[
                  Text(Fmt.shortDate(sel.date),
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context))),
                  const SizedBox(width: 6),
                  Text('No entry',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context))),
                ] else
                  Text('Tap a bar to view details',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.subtext(context))),
              ],
            ),
          ),
          // ── Bar chart ───────────────────────────────────────────────────
          SizedBox(
            height: 175,
            child: LayoutBuilder(builder: (_, constraints) {
              const leftPad = 52.0;
              const rightPad = 8.0;
              final totalW = constraints.maxWidth;
              final barSlotW = (totalW - leftPad - rightPad) / 30;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final idx = ((details.localPosition.dx - leftPad) /
                          barSlotW)
                      .floor();
                  if (idx >= 0 && idx < 30) {
                    setState(() => _selectedIndex = idx);
                    if (data[idx].sale != null) {
                      widget.onDrillDown(data[idx].sale!);
                    }
                  }
                },
                child: CustomPaint(
                  size: Size(totalW, 175),
                  painter: _SalesBarChartPainter(
                    data: data,
                    selectedIndex: _selectedIndex,
                    maxValue: maxVal,
                    primaryColor: primary,
                    textColor: AppTheme.onCard(context),
                    subtextColor: AppTheme.subtext(context),
                    gridColor: AppTheme.outline(context),
                    currencySymbol: sym,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─── CustomPainter ───────────────────────────────────────────────────────────

class _SalesBarChartPainter extends CustomPainter {
  final List<_BarDatum> data;
  final int? selectedIndex;
  final double maxValue;
  final Color primaryColor;
  final Color textColor;
  final Color subtextColor;
  final Color gridColor;
  final String currencySymbol;

  static const _leftPad = 52.0;
  static const _rightPad = 8.0;
  static const _topPad = 8.0;
  static const _bottomPad = 34.0;

  const _SalesBarChartPainter({
    required this.data,
    required this.selectedIndex,
    required this.maxValue,
    required this.primaryColor,
    required this.textColor,
    required this.subtextColor,
    required this.gridColor,
    required this.currencySymbol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - _leftPad - _rightPad;
    final plotH = size.height - _topPad - _bottomPad;
    final effectiveMax = maxValue <= 0 ? 1.0 : maxValue;
    final barSlotW = plotW / 30;
    final barW = (barSlotW - 2.5).clamp(2.0, double.infinity);

    final gridPaint = Paint()
      ..color = gridColor.withAlpha(160)
      ..strokeWidth = 0.5;

    final labelStyle = TextStyle(
        fontSize: 9, color: subtextColor, fontWeight: FontWeight.w400);

    // ── Y-axis grid lines and labels ───────────────────────────────────────
    for (int j = 0; j <= 4; j++) {
      final y = _topPad + plotH * (1 - j / 4);
      canvas.drawLine(
          Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);

      final amount = effectiveMax * j / 4;
      final label = _yLabel(amount);
      final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: _leftPad - 4);
      tp.paint(canvas,
          Offset(_leftPad - tp.width - 4, y - tp.height / 2));
    }

    // ── Bars and X-axis labels ────────────────────────────────────────────
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final isSelected = i == selectedIndex;
      final hasData = d.sale != null;

      final x = _leftPad + i * barSlotW + (barSlotW - barW) / 2;
      final frac = (d.received / effectiveMax).clamp(0.0, 1.0);
      final barH = (frac * plotH).clamp(2.0, plotH);
      final y = _topPad + plotH - barH;

      Color barColor;
      if (!hasData) {
        barColor = gridColor.withAlpha(120);
      } else if (isSelected) {
        barColor = primaryColor;
      } else {
        barColor = primaryColor.withAlpha(170);
      }

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, hasData ? y : _topPad + plotH - 2, barW,
            hasData ? barH : 2),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = barColor);

      // X-axis label every 7 bars and the last bar (today)
      if (i % 7 == 0 || i == 29) {
        final label = '${d.date.day}/${d.date.month}';
        final tp = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: TextDirection.ltr)
          ..layout();
        final lx = x + barW / 2 - tp.width / 2;
        final ly = _topPad + plotH + 5;
        tp.paint(canvas, Offset(lx, ly));
      }
    }
  }

  String _yLabel(double amount) {
    if (amount == 0) return '0';
    if (amount >= 1e7) return '${(amount / 1e7).toStringAsFixed(1)}Cr';
    if (amount >= 1e5) return '${(amount / 1e5).toStringAsFixed(1)}L';
    if (amount >= 1e3) return '${(amount / 1e3).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(_SalesBarChartPainter old) =>
      old.selectedIndex != selectedIndex ||
      old.maxValue != maxValue ||
      old.data != data ||
      old.gridColor != gridColor;
}
