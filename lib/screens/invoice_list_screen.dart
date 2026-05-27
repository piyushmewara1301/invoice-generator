import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/partial_payment.dart';
import '../models/payment_method.dart';
import '../providers/app_provider.dart';
import '../models/invoice.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/status_badge.dart';
import 'create_invoice_screen.dart';
import 'import_invoices_screen.dart';
import '../utils/share_service.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Period { all, today, week, month, custom }

enum _CsvAction { export, import }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.all:
        return 'All Time';
      case _Period.today:
        return 'Today';
      case _Period.week:
        return 'This Week';
      case _Period.month:
        return 'This Month';
      case _Period.custom:
        return 'Custom';
    }
  }
}

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _search = '';
  _Period _period = _Period.all;
  DateTimeRange? _customRange;
  Client? _clientFilter;
  bool _exporting = false;
  Set<String> _paymentMethodFilter = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  DateTimeRange _rangeFor(_Period p) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (p) {
      case _Period.all:
        return DateTimeRange(start: DateTime(2000), end: todayEnd);
      case _Period.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _Period.week:
        return DateTimeRange(
            start: todayStart.subtract(const Duration(days: 6)),
            end: todayEnd);
      case _Period.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: todayEnd);
      case _Period.custom:
        return _customRange ??
            DateTimeRange(
                start: DateTime(now.year, now.month, 1), end: todayEnd);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customRange = DateTimeRange(
          start: picked.start,
          end: DateTime(
              picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
        );
        _period = _Period.custom;
      });
    }
  }

  List<Invoice> _filter(List<Invoice> invoices, InvoiceStatus? status) {
    var list = invoices;
    if (status != null) list = list.where((i) => i.status == status).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((i) =>
              i.invoiceNumber.toLowerCase().contains(q) ||
              (i.client?.displayName.toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (_period != _Period.all) {
      final range = _rangeFor(_period);
      list = list.where((i) {
        final d = i.invoiceDate;
        return !d.isBefore(range.start) && !d.isAfter(range.end);
      }).toList();
    }
    if (_clientFilter != null) {
      list = list.where((i) => i.client?.id == _clientFilter!.id).toList();
    }
    if (_paymentMethodFilter.isNotEmpty) {
      list = list
          .where((i) => i.paymentMethodId != null &&
              _paymentMethodFilter.contains(i.paymentMethodId))
          .toList();
    }
    return list;
  }

  bool get _hasActiveFilter =>
      _period != _Period.all ||
      _clientFilter != null ||
      _paymentMethodFilter.isNotEmpty;

  void _showClientPicker(BuildContext context, List<Client> clients) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('Filter by Client',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_clientFilter != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _clientFilter = null);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.people_outline,
                      color: AppTheme.textSecondary),
                  title: const Text('All Clients'),
                  selected: _clientFilter == null,
                  selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
                  onTap: () {
                    setState(() => _clientFilter = null);
                    Navigator.pop(ctx);
                  },
                ),
                ...clients.map((c) => ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.12),
                        child: Text(
                          c.displayName.isNotEmpty
                              ? c.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(c.displayName),
                      subtitle: c.email.isNotEmpty ? Text(c.email) : null,
                      selected: _clientFilter?.id == c.id,
                      selectedTileColor:
                          AppTheme.primary.withValues(alpha: 0.08),
                      onTap: () {
                        setState(() => _clientFilter = c);
                        Navigator.pop(ctx);
                      },
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _csvField(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _buildCsv(List<Invoice> invoices) {
    const headers = [
      'Invoice No', 'Date', 'Due Date', 'Status',
      'Client Name', 'Client Company', 'Client Email', 'Client Phone',
      'Subject', 'Currency', 'Subtotal', 'Tax', 'Discount', 'Total',
      'Paid', 'Outstanding',
    ];
    final rows = <String>[headers.map(_csvField).join(',')];
    for (final inv in invoices) {
      final row = [
        inv.invoiceNumber,
        Fmt.date(inv.invoiceDate),
        Fmt.date(inv.dueDate),
        inv.status.label,
        inv.client?.displayName ?? '',
        inv.client?.companyName ?? '',
        inv.client?.email ?? '',
        inv.client?.phone ?? '',
        inv.subject ?? '',
        inv.currency,
        inv.subtotal.toStringAsFixed(2),
        inv.totalTax.toStringAsFixed(2),
        inv.totalDiscount.toStringAsFixed(2),
        inv.grandTotal.toStringAsFixed(2),
        inv.amountPaid.toStringAsFixed(2),
        inv.amountRemaining.toStringAsFixed(2),
      ];
      rows.add(row.map(_csvField).join(','));
    }
    return rows.join('\n');
  }

  String _exportFilename(List<Invoice> invoices) {
    final tabNames = ['all', 'draft', 'sent', 'paid', 'overdue'];
    final tab = tabNames[_tabs.index];
    final period = _period == _Period.custom && _customRange != null
        ? '${_customRange!.start.year}-${_customRange!.start.month.toString().padLeft(2,'0')}-${_customRange!.start.day.toString().padLeft(2,'0')}_to_${_customRange!.end.year}-${_customRange!.end.month.toString().padLeft(2,'0')}-${_customRange!.end.day.toString().padLeft(2,'0')}'
        : _period.label.toLowerCase().replaceAll(' ', '_');
    final client = _clientFilter != null
        ? '_${_clientFilter!.displayName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
        : '';
    final paymentSuffix = _paymentMethodFilter.isNotEmpty
        ? '_${_paymentMethodFilter.length}paymentmethod'
        : '';
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    return 'invoices_${tab}_$period${client}_$paymentSuffix${invoices.length}records_$stamp.csv'
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<void> _exportCsv() async {
    final provider = context.read<AppProvider>();
    if (!provider.hasDrive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in with Google to export invoices to Drive.'),
      ));
      return;
    }

    final tabInvoiceSets = [
      _filter(provider.invoices, null),
      _filter(provider.invoices, InvoiceStatus.draft),
      _filter(provider.invoices, InvoiceStatus.sent),
      _filter(provider.invoices, InvoiceStatus.paid),
      _filter(provider.invoices.where((i) => i.isOverdue).toList(), null),
    ];
    final invoices = tabInvoiceSets[_tabs.index];

    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No invoices to export with the current filters.'),
      ));
      return;
    }

    setState(() => _exporting = true);
    final csv = _buildCsv(invoices);
    final filename = _exportFilename(invoices);
    final total = invoices.fold(0.0, (s, i) => s + i.grandTotal);
    final currency = invoices.first.currency;
    final count = invoices.length;

    final link = await provider.uploadCsv(filename, csv);
    if (!mounted) return;
    setState(() => _exporting = false);

    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export failed. Check your connection and try again.'),
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count invoice${count == 1 ? '' : 's'} exported',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Total: ${Fmt.currencyAmount(total, currency)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(filename,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                content: Text('Link copied to clipboard.'),
                duration: Duration(seconds: 2),
              ));
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open in Drive'),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(link);
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodPicker(
      BuildContext context, List<PaymentMethod> methods) {
    // Work on a local copy so changes only apply on "Apply".
    var selected = Set<String>.from(_paymentMethodFilter);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('Filter by Payment Method',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (selected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setModal(() => selected.clear());
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: methods
                    .map((m) => CheckboxListTile(
                          value: selected.contains(m.id),
                          onChanged: (v) {
                            setModal(() {
                              if (v == true) {
                                selected.add(m.id);
                              } else {
                                selected.remove(m.id);
                              }
                            });
                          },
                          title: Text(m.name,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: m.subtitle.isNotEmpty
                              ? Text(m.subtitle,
                                  style: const TextStyle(fontSize: 12))
                              : null,
                          secondary: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _paymentMethodIcon(m.type),
                              size: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                          activeColor: AppTheme.primary,
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _paymentMethodFilter = selected);
                    Navigator.pop(ctx);
                  },
                  child: Text(selected.isEmpty
                      ? 'Show All'
                      : 'Apply (${selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _paymentMethodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return Icons.payments_outlined;
      case PaymentMethodType.bankAccount:
        return Icons.account_balance_outlined;
      case PaymentMethodType.upi:
        return Icons.qr_code_outlined;
      case PaymentMethodType.other:
        return Icons.credit_card_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final clients = provider.clients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<_CsvAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'CSV options',
              onSelected: (action) {
                if (action == _CsvAction.export) {
                  _exportCsv();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ImportInvoicesScreen()),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _CsvAction.export,
                  child: ListTile(
                    leading: Icon(Icons.upload_file_outlined),
                    title: Text('Export to CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: _CsvAction.import,
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Import from CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          if (_hasActiveFilter)
            TextButton(
              onPressed: () => setState(() {
                _period = _Period.all;
                _clientFilter = null;
                _customRange = null;
                _paymentMethodFilter = {};
              }),
              child: const Text('Clear Filters'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(144),
          child: Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by invoice # or client name...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              // Period + client filter row
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    // Period chips
                    ..._Period.values
                        .where((p) => p != _Period.custom)
                        .map((p) {
                      final selected = _period == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(p.label),
                          selected: selected,
                          onSelected: (_) => setState(() => _period = p),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(
                            color:
                                selected ? AppTheme.primary : AppTheme.divider,
                          ),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                    // Custom date range chip
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _period == _Period.custom && _customRange != null
                                  ? '${Fmt.shortDate(_customRange!.start)} – ${Fmt.shortDate(_customRange!.end)}'
                                  : 'Custom',
                              style: TextStyle(
                                color: _period == _Period.custom
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.calendar_month_outlined,
                                size: 13,
                                color: _period == _Period.custom
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary),
                          ],
                        ),
                        onPressed: _pickCustomRange,
                        side: BorderSide(
                          color: _period == _Period.custom
                              ? AppTheme.primary
                              : AppTheme.divider,
                        ),
                        backgroundColor: _period == _Period.custom
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    // Client filter chip
                    if (clients.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Icon(
                            _clientFilter != null
                                ? Icons.person
                                : Icons.person_outline,
                            size: 14,
                            color: _clientFilter != null
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          label: Text(
                            _clientFilter?.displayName ?? 'Client',
                            style: TextStyle(
                              color: _clientFilter != null
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () => _showClientPicker(context, clients),
                          side: BorderSide(
                            color: _clientFilter != null
                                ? AppTheme.primary
                                : AppTheme.divider,
                          ),
                          backgroundColor: _clientFilter != null
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    // Payment method filter chip
                    Builder(builder: (context) {
                      final allMethods = context
                          .read<AppProvider>()
                          .profile
                          .allPaymentMethods;
                      if (allMethods.isEmpty) return const SizedBox.shrink();
                      final active = _paymentMethodFilter.isNotEmpty;
                      final label = active
                          ? (_paymentMethodFilter.length == 1
                              ? allMethods
                                  .firstWhere(
                                    (m) => m.id == _paymentMethodFilter.first,
                                    orElse: () => allMethods.first,
                                  )
                                  .name
                              : '${_paymentMethodFilter.length} methods')
                          : 'Payment';
                      return ActionChip(
                        avatar: Icon(
                          active
                              ? Icons.account_balance_wallet
                              : Icons.account_balance_wallet_outlined,
                          size: 14,
                          color: active
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                        label: Text(
                          label,
                          style: TextStyle(
                            color: active
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () =>
                            _showPaymentMethodPicker(context, allMethods),
                        side: BorderSide(
                          color: active ? AppTheme.primary : AppTheme.divider,
                        ),
                        backgroundColor: active
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Tabs
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Draft'),
                  Tab(text: 'Sent'),
                  Tab(text: 'Paid'),
                  Tab(text: 'Overdue'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _InvoiceTab(invoices: _filter(provider.invoices, null)),
          _InvoiceTab(
              invoices: _filter(provider.invoices, InvoiceStatus.draft)),
          _InvoiceTab(
              invoices: _filter(provider.invoices, InvoiceStatus.sent)),
          _InvoiceTab(
              invoices: _filter(provider.invoices, InvoiceStatus.paid)),
          _InvoiceTab(
              invoices: _filter(
                  provider.invoices.where((i) => i.isOverdue).toList(), null)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createInvoice(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _createInvoice(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final limit = provider.checkInvoiceLimit();
    if (limit != null) {
      final upgrade = await showPaywallSheet(context, limit);
      if (upgrade && context.mounted) {
        Navigator.pushNamed(context, '/plans');
      }
      return;
    }
    if (!context.mounted) return;
    final invoice = provider.buildNewInvoice();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: invoice)));
  }
}

class _InvoiceTab extends StatefulWidget {
  final List<Invoice> invoices;
  const _InvoiceTab({required this.invoices});

  @override
  State<_InvoiceTab> createState() => _InvoiceTabState();
}

class _InvoiceTabState extends State<_InvoiceTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.invoices.isEmpty) {
      return Center(
        child: FadeTransition(
          opacity: _controller,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 52, color: AppTheme.textSecondary),
              SizedBox(height: 14),
              Text('No invoices here',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }
    // Bottom padding clears the FAB (56 height + 16 margin = ~72) and the
    // device safe-area inset so the last card is never hidden behind the button.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 88 + bottomInset),
      itemCount: widget.invoices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final delay = (i * 0.07).clamp(0.0, 0.55);
        final anim = CurvedAnimation(
          parent: _controller,
          curve: Interval(delay, (delay + 0.45).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(anim),
            child: _InvoiceCard(invoice: widget.invoices[i]),
          ),
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Dismissible(
      key: Key(invoice.id),
      direction: DismissDirection.horizontal,
      // Swipe right → edit
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      // Swipe left → delete
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Edit: navigate without dismissing
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateInvoiceScreen(invoice: invoice)),
          );
          return false;
        }
        // Delete: confirm first
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Invoice'),
            content: Text(
                'Delete ${invoice.invoiceNumber}? This cannot be undone.'),
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
      },
      onDismissed: (_) => provider.deleteInvoice(invoice.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showStatusSheet(context, provider),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.client?.displayName ?? 'No Client',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textPrimary),
                      ),
                    ),
                    StatusBadge(status: invoice.status, small: true),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Fmt.currencyAmount(invoice.grandTotal, invoice.currency),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.textPrimary),
                        ),
                        if (invoice.payments.isNotEmpty &&
                            invoice.status != InvoiceStatus.paid)
                          Text(
                            '${Fmt.currencyAmount(invoice.amountRemaining, invoice.currency)} due',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.error),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: invoice.isOverdue
                          ? AppTheme.error
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due ${Fmt.date(invoice.dueDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: invoice.isOverdue
                            ? AppTheme.error
                            : AppTheme.textSecondary,
                        fontWeight: invoice.isOverdue
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusSheet(BuildContext context, AppProvider provider) {
    final methods = provider.profile.allPaymentMethods;
    final profile = provider.profile;
    showModalBottomSheet<InvoiceStatus?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StatusSheet(
        invoice: invoice,
        methods: methods,
        onStatusChanged: (status, payment) async {
          if (payment != null) {
            final updated = invoice.copy();
            updated.payments.add(payment);
            final totalPaid =
                updated.payments.fold(0.0, (s, p) => s + p.amount);
            updated.status = totalPaid >= updated.grandTotal - 0.01
                ? InvoiceStatus.paid
                : InvoiceStatus.partiallyPaid;
            await provider.saveInvoice(updated);
          } else {
            await provider.updateInvoiceStatus(invoice.id, status);
          }
        },
      ),
    ).then((selected) {
      if (selected == InvoiceStatus.sent && context.mounted) {
        showShareInvoiceSheet(context, invoice, profile);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusSheet extends StatefulWidget {
  final Invoice invoice;
  final List<PaymentMethod> methods;
  final Future<void> Function(InvoiceStatus, PartialPayment?) onStatusChanged;

  const _StatusSheet({
    required this.invoice,
    required this.methods,
    required this.onStatusChanged,
  });

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  bool _showPartialForm = false;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedMethodId = '__cash__';
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyStatus(InvoiceStatus status) async {
    setState(() => _saving = true);
    await widget.onStatusChanged(status, null);
    if (mounted) Navigator.pop(context, status);
  }

  Future<void> _submitPartial() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.parse(_amountCtrl.text);
    final method =
        widget.methods.firstWhere((m) => m.id == _selectedMethodId);
    final payment = PartialPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      amount: amount,
      paymentMethodId: method.id,
      paymentMethodName: method.name,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    await widget.onStatusChanged(InvoiceStatus.partiallyPaid, payment);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(widget.invoice.currency);
    final remaining = widget.invoice.amountRemaining;
    final current = widget.invoice.status;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.invoice.invoiceNumber,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '$sym${widget.invoice.grandTotal.toStringAsFixed(2)}'
                          '${widget.invoice.payments.isNotEmpty ? '  ·  $sym${remaining.toStringAsFixed(2)} remaining' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            if (!_showPartialForm) ...[
              // Status options
              _statusOption(
                context,
                status: InvoiceStatus.draft,
                icon: Icons.edit_note_outlined,
                label: 'Draft',
                current: current,
              ),
              _statusOption(
                context,
                status: InvoiceStatus.sent,
                icon: Icons.send_outlined,
                label: 'Sent',
                current: current,
              ),
              _statusOption(
                context,
                status: InvoiceStatus.paid,
                icon: Icons.check_circle_outline,
                label: 'Paid in Full',
                current: current,
              ),
              if (current != InvoiceStatus.paid)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_outlined,
                        size: 18, color: Color(0xFFE65100)),
                  ),
                  title: const Text('Record Partial Payment',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '$sym${remaining.toStringAsFixed(2)} outstanding',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.textSecondary),
                  onTap: () => setState(() => _showPartialForm = true),
                ),
              const SizedBox(height: 12),
            ] else ...[
              // Partial payment form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showPartialForm = false),
                            child: const Icon(Icons.arrow_back,
                                size: 18, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          const Text('Record Partial Payment',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Amount Received',
                          prefixText: sym,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter amount';
                          }
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) {
                            return 'Enter a valid amount';
                          }
                          if (n > remaining + 0.01) {
                            return 'Exceeds balance due ($sym${remaining.toStringAsFixed(2)})';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Payment Method',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      RadioGroup<String>(
                        groupValue: _selectedMethodId,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedMethodId = v);
                          }
                        },
                        child: Column(
                          children: widget.methods
                              .map((m) => RadioListTile<String>(
                                    value: m.id,
                                    title: Text(m.name,
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: m.subtitle.isNotEmpty
                                        ? Text(m.subtitle,
                                            style:
                                                const TextStyle(fontSize: 11))
                                        : null,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    activeColor: AppTheme.primary,
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'e.g. Cheque #1234',
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saving ? null : _submitPartial,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44)),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Confirm Payment'),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusOption(
    BuildContext context, {
    required InvoiceStatus status,
    required IconData icon,
    required String label,
    required InvoiceStatus current,
  }) {
    final isActive = current == status;
    final color = AppTheme.statusColor(status.label.toLowerCase());
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: isActive
          ? Icon(Icons.check_circle, size: 18, color: color)
          : const SizedBox(width: 18),
      onTap: isActive || _saving ? null : () => _applyStatus(status),
    );
  }
}
