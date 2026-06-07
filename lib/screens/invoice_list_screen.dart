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
import '../widgets/feature_guide_sheet.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/quotation_status_sheet.dart';
import '../widgets/status_badge.dart';
import 'create_invoice_screen.dart';
import 'import_invoices_screen.dart';
import 'client_list_screen.dart';
import '../utils/share_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/employee.dart';
import '../models/recurring_schedule.dart';

enum _Period { all, today, week, month, custom }

enum _CsvAction { export, import }


class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _search = '';
  _Period _period = _Period.today;
  DateTimeRange? _customRange;
  Client? _clientFilter;
  bool _exporting = false;
  Set<String> _paymentMethodFilter = {};

  // Multi-select state
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.invoices);
    });
  }

  String _periodLabel(AppLocalizations l10n, _Period p) {
    switch (p) {
      case _Period.all:    return l10n.allTime;
      case _Period.today:  return l10n.today;
      case _Period.week:   return l10n.thisWeek;
      case _Period.month:  return l10n.thisMonth;
      case _Period.custom: return l10n.custom;
    }
  }

  // English-only slug used for CSV filenames — locale-independent by design.
  String _periodSlug(_Period p) {
    switch (p) {
      case _Period.all:    return 'all_time';
      case _Period.today:  return 'today';
      case _Period.week:   return 'this_week';
      case _Period.month:  return 'this_month';
      case _Period.custom: return 'custom';
    }
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
        final created = i.invoiceDate;
        final createdInRange =
            !created.isBefore(range.start) && !created.isAfter(range.end);
        if (createdInRange) return true;
        // For the "Today" period also include invoices whose due date is today,
        // regardless of when they were created.
        if (_period == _Period.today) {
          final due = i.dueDate;
          return !due.isBefore(range.start) && !due.isAfter(range.end);
        }
        return false;
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(l10n.filterByClient,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_clientFilter != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _clientFilter = null);
                      Navigator.pop(ctx);
                    },
                    child: Text(l10n.cancel),
                  ),
              ],
            ),
          ),
          Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(Icons.people_outline,
                      color: AppTheme.subtext(context)),
                  title: Text(l10n.allClients),
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
        : _periodSlug(_period);
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
            SizedBox(height: 4),
            Text('Total: ${Fmt.currencyAmount(total, currency)}',
                style: TextStyle(fontSize: 13, color: AppTheme.subtext(context))),
            SizedBox(height: 12),
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
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(filename,
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.onCard(context)),
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
    final l10n = AppLocalizations.of(context)!;
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
                  Text(l10n.paymentMethod,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (selected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setModal(() => selected.clear());
                      },
                      child: Text(l10n.cancel),
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

  Future<void> _sendBulkReminders(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final selected = provider.invoices
        .where((i) => _selectedIds.contains(i.id))
        .toList();

    int sent = 0;
    int skipped = 0;

    for (final invoice in selected) {
      if (invoice.client?.phone.isNotEmpty != true) {
        skipped++;
        continue;
      }
      try {
        await ShareService.openWhatsAppDirectly(invoice, provider.profile);
        sent++;
        // Small delay between opens to avoid overwhelming WhatsApp
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {
        skipped++;
      }
    }

    setState(() => _selectedIds.clear());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          skipped > 0
              ? 'Reminders sent to $sent clients. $skipped skipped (no phone).'
              : 'Reminders sent to $sent clients.',
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final canCreate = provider.canDo(AppPermission.createInvoice);
    final clients = provider.clients;

    return Scaffold(
      appBar: AppBar(
        title: _isSelecting
            ? Text('${_selectedIds.length} selected')
            : Text(l10n.invoices),
        actions: [
          if (_isSelecting)
            TextButton(
              onPressed: () => setState(() => _selectedIds.clear()),
              child: const Text('Cancel'),
            )
          else ...[
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: l10n.clients,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientListScreen()),
            ),
          ),
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
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _CsvAction.export,
                  child: ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(l10n.exportInvoices),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                if (canCreate)
                  PopupMenuItem(
                    value: _CsvAction.import,
                    child: ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: Text(l10n.importInvoices),
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
              child: Text(l10n.clearFilters),
            ),
          ],
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
                          label: Text(_periodLabel(l10n, p)),
                          selected: selected,
                          onSelected: (_) => setState(() => _period = p),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.onCard(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(
                            color:
                                selected ? AppTheme.primary : AppTheme.outline(context),
                          ),
                          backgroundColor: AppTheme.card(context),
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
                                    : AppTheme.onCard(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.calendar_month_outlined,
                                size: 13,
                                color: _period == _Period.custom
                                    ? AppTheme.primary
                                    : AppTheme.subtext(context)),
                          ],
                        ),
                        onPressed: _pickCustomRange,
                        side: BorderSide(
                          color: _period == _Period.custom
                              ? AppTheme.primary
                              : AppTheme.outline(context),
                        ),
                        backgroundColor: _period == _Period.custom
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : AppTheme.card(context),
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
                                  : AppTheme.onCard(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () => _showClientPicker(context, clients),
                          side: BorderSide(
                            color: _clientFilter != null
                                ? AppTheme.primary
                                : AppTheme.outline(context),
                          ),
                          backgroundColor: _clientFilter != null
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : AppTheme.card(context),
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
                                : AppTheme.onCard(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () =>
                            _showPaymentMethodPicker(context, allMethods),
                        side: BorderSide(
                          color: active ? AppTheme.primary : AppTheme.outline(context),
                        ),
                        backgroundColor: active
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : AppTheme.card(context),
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
                tabs: [
                  Tab(text: l10n.all),
                  Tab(text: l10n.draft),
                  Tab(text: l10n.sent),
                  Tab(text: l10n.paid),
                  Tab(text: l10n.overdue),
                  const Tab(text: 'Quotes'),
                  const Tab(text: 'Credit Notes'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [
              _InvoiceTab(
                invoices: _filter(provider.invoicesOnly, null),
                selectedIds: _selectedIds,
                isSelecting: _isSelecting,
                onToggle: (id) => setState(() {
                  if (_selectedIds.contains(id)) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                }),
              ),
              _InvoiceTab(
                invoices: _filter(provider.invoicesOnly, InvoiceStatus.draft),
                selectedIds: _selectedIds,
                isSelecting: _isSelecting,
                onToggle: (id) => setState(() {
                  if (_selectedIds.contains(id)) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                }),
              ),
              _InvoiceTab(
                invoices: _filter(provider.invoicesOnly, InvoiceStatus.sent),
                selectedIds: _selectedIds,
                isSelecting: _isSelecting,
                onToggle: (id) => setState(() {
                  if (_selectedIds.contains(id)) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                }),
              ),
              _InvoiceTab(
                invoices: _filter(provider.invoicesOnly, InvoiceStatus.paid),
                selectedIds: _selectedIds,
                isSelecting: _isSelecting,
                onToggle: (id) => setState(() {
                  if (_selectedIds.contains(id)) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                }),
              ),
              _InvoiceTab(
                invoices: _filter(
                    provider.invoicesOnly.where((i) => i.isOverdue).toList(),
                    null),
                selectedIds: _selectedIds,
                isSelecting: _isSelecting,
                onToggle: (id) => setState(() {
                  if (_selectedIds.contains(id)) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                }),
              ),
              _QuotationsTab(
                  quotations: provider.quotations,
                  search: _search),
              _CreditNotesTab(
                  creditNotes: provider.creditNotes,
                  search: _search),
            ],
          ),
          if (_isSelecting)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  boxShadow: AppTheme.elevatedShadow,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        final all = provider.invoicesOnly;
                        setState(() {
                          if (_selectedIds.length == all.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(all.map((i) => i.id));
                          }
                        });
                      },
                      child: const Text('Select All'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _sendBulkReminders(context),
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: Text('Send Reminders (${_selectedIds.length})'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _selectedIds.clear()),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: canCreate && !_isSelecting
          ? FloatingActionButton(
              onPressed: () => _createInvoice(context),
              child: const Icon(Icons.add),
            )
          : null,
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
  final Set<String> selectedIds;
  final bool isSelecting;
  final void Function(String id) onToggle;

  const _InvoiceTab({
    required this.invoices,
    required this.selectedIds,
    required this.isSelecting,
    required this.onToggle,
  });

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 52, color: AppTheme.subtext(context)),
              SizedBox(height: 14),
              Text('No invoices here',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.subtext(context))),
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
            child: _InvoiceCard(
              invoice: widget.invoices[i],
              isSelected: widget.selectedIds.contains(widget.invoices[i].id),
              isSelecting: widget.isSelecting,
              onToggle: widget.onToggle,
            ),
          ),
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final bool isSelected;
  final bool isSelecting;
  final void Function(String id) onToggle;

  const _InvoiceCard({
    required this.invoice,
    required this.isSelected,
    required this.isSelecting,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    final card = Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.07)
            : AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: isSelected
            ? Border.all(color: AppTheme.primary, width: 1.5)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isSelecting
            ? () => onToggle(invoice.id)
            : () => _showStatusSheet(context, provider),
        onLongPress: isSelecting ? null : () => onToggle(invoice.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelecting) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggle(invoice.id),
                    activeColor: AppTheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            invoice.client?.displayName ?? 'No Client',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppTheme.onCard(context)),
                          ),
                        ),
                        StatusBadge(status: invoice.status, small: true),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.subtext(context)),
                        ),
                        Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Fmt.currencyAmount(invoice.grandTotal, invoice.currency),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppTheme.onCard(context)),
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
            ],
          ),
        ),
      ),
    );

    // Disable swipe gestures while in selection mode
    if (isSelecting) return card;

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
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateInvoiceScreen(invoice: invoice)),
          );
          return false;
        }
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
      child: card,
    );
  }

  void _showStatusSheet(BuildContext context, AppProvider provider) {
    final methods = provider.profile.allPaymentMethods;
    final profile = provider.profile;
    final canIssueCN = !invoice.isQuotation &&
        !invoice.isCreditNote &&
        !provider.hasCreditNote(invoice.id);

    showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StatusSheet(
        invoice: invoice,
        methods: methods,
        canIssueCreditNote: canIssueCN,
        onIssueCreditNote: () => Navigator.pop(context, _SheetResult.creditNote),
        onStatusChanged: (status, payment) async {
          if (payment != null) {
            final updated = invoice.copy();
            updated.payments.add(payment);
            // amountPaid includes TDS credit so the invoice is correctly
            // settled when cash + TDS covers the grand total.
            updated.status = updated.amountPaid >= updated.grandTotal - 0.01
                ? InvoiceStatus.paid
                : InvoiceStatus.partiallyPaid;
            await provider.saveInvoice(updated);
          } else {
            await provider.updateInvoiceStatus(invoice.id, status);
          }
        },
      ),
    ).then((result) {
      if (!context.mounted) return;
      if (result == _SheetResult.sent) {
        showShareInvoiceSheet(context, invoice, profile);
      } else if (result == _SheetResult.creditNote) {
        _issueCreditNoteFromList(context, provider);
      }
    });
  }

  Future<void> _issueCreditNoteFromList(
      BuildContext context, AppProvider provider) async {
    final reasonCtrl = TextEditingController();

    final cn = await showDialog<Invoice>(
      context: context,
      builder: (ctx) {
        String? errorText;
        bool submitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Issue Credit Note'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice: ${invoice.invoiceNumber}  ·  '
                      '${Fmt.currencyAmount(invoice.grandTotal, invoice.currency)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Reason for credit note',
                      hintText: 'e.g. Goods returned, overcharged',
                      errorText: errorText,
                    ),
                    maxLines: 2,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (reasonCtrl.text.trim().isEmpty) {
                          setDialogState(() => errorText = 'Please enter a reason');
                          return;
                        }
                        setDialogState(() => submitting = true);
                        try {
                          final created = await provider.issueCreditNote(
                            linkedInvoiceId: invoice.id,
                            reason: reasonCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          setDialogState(() {
                            submitting = false;
                            errorText = e.toString();
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Issue Credit Note'),
              ),
            ],
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => reasonCtrl.dispose());

    if (cn == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: cn)),
    );
  }
}

enum _SheetResult { sent, creditNote }

// ─────────────────────────────────────────────────────────────────────────────

class _StatusSheet extends StatefulWidget {
  final Invoice invoice;
  final List<PaymentMethod> methods;
  final Future<void> Function(InvoiceStatus, PartialPayment?) onStatusChanged;
  final bool canIssueCreditNote;
  final VoidCallback? onIssueCreditNote;

  const _StatusSheet({
    required this.invoice,
    required this.methods,
    required this.onStatusChanged,
    this.canIssueCreditNote = false,
    this.onIssueCreditNote,
  });

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  bool _showPartialForm = false;
  bool _isFullPayment = false;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tdsCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedMethodId = '__cash__';
  bool _saving = false;
  bool _hasTds = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _tdsCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyStatus(InvoiceStatus status) async {
    setState(() => _saving = true);
    await widget.onStatusChanged(status, null);
    if (mounted) {
      Navigator.pop(
        context,
        status == InvoiceStatus.sent ? _SheetResult.sent : null,
      );
    }
  }

  Future<void> _submitPartial() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.parse(_amountCtrl.text);
    final method =
        widget.methods.firstWhere((m) => m.id == _selectedMethodId);
    final tdsAmt = _hasTds ? (double.tryParse(_tdsCtrl.text) ?? 0) : null;
    final tdsPercent = (tdsAmt != null && tdsAmt > 0 && amount + tdsAmt > 0)
        ? tdsAmt / (amount + tdsAmt) * 100
        : null;
    final payment = PartialPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      amount: amount,
      paymentMethodId: method.id,
      paymentMethodName: method.name,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      tdsPercent: tdsPercent,
      tdsAmount: tdsAmt,
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
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.subtext(context)),
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
              if (current == InvoiceStatus.paid)
                // Already paid — show as active indicator only
                _statusOption(
                  context,
                  status: InvoiceStatus.paid,
                  icon: Icons.check_circle_outline,
                  label: 'Paid in Full',
                  current: current,
                )
              else
                // Opens payment form pre-filled with full amount — TDS accessible
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check_circle_outline,
                        size: 18, color: AppTheme.success),
                  ),
                  title: const Text('Paid in Full',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Record payment · TDS deduction supported',
                    style: TextStyle(fontSize: 11, color: AppTheme.subtext(context)),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.subtext(context)),
                  onTap: () => setState(() {
                    _amountCtrl.text = remaining.toStringAsFixed(2);
                    _isFullPayment = true;
                    _showPartialForm = true;
                  }),
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
                    '$sym${remaining.toStringAsFixed(2)} outstanding · TDS deduction supported',
                    style: TextStyle(fontSize: 11, color: AppTheme.subtext(context)),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.subtext(context)),
                  onTap: () => setState(() {
                    _isFullPayment = false;
                    _showPartialForm = true;
                  }),
                ),

              // ── Credit Note ──────────────────────────────────────────────
              if (widget.canIssueCreditNote) ...[
                const Divider(indent: 16, endIndent: 16, height: 16),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.credit_card_off_outlined,
                        size: 18, color: Color(0xFFDC2626)),
                  ),
                  title: const Text('Issue Credit Note',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDC2626))),
                  subtitle: const Text(
                    'Create a credit document against this invoice',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.subtext(context)),
                  onTap: widget.onIssueCreditNote,
                ),
              ],

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
                            onTap: () => setState(() {
                              _showPartialForm = false;
                              _isFullPayment = false;
                            }),
                            child: Icon(Icons.arrow_back,
                                size: 18, color: AppTheme.subtext(context)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isFullPayment
                                ? 'Record Full Payment'
                                : 'Record Partial Payment',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
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
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter amount';
                          }
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) {
                            return 'Enter a valid amount';
                          }
                          final tdsAmt = _hasTds
                              ? (double.tryParse(_tdsCtrl.text) ?? 0)
                              : 0.0;
                          if (n + tdsAmt > remaining + 0.01) {
                            return 'Exceeds balance due ($sym${remaining.toStringAsFixed(2)})';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      // TDS toggle
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('TDS Deducted by Client',
                            style: TextStyle(fontSize: 13)),
                        subtitle: const Text(
                            'Tax Deducted at Source (194J, 194C, etc.)',
                            style: TextStyle(fontSize: 10)),
                        value: _hasTds,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (v) => setState(() {
                          _hasTds = v;
                          if (!v) _tdsCtrl.clear();
                        }),
                      ),
                      if (_hasTds) ...[
                        TextFormField(
                          controller: _tdsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'TDS Amount',
                            prefixText: sym,
                            hintText: '0.00',
                          ),
                          validator: (v) {
                            if (!_hasTds) return null;
                            final n = double.tryParse(v ?? '');
                            if (n == null || n < 0) {
                              return 'Enter a valid TDS amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        Builder(builder: (ctx) {
                          final tdsAmt =
                              double.tryParse(_tdsCtrl.text) ?? 0;
                          final cashAmt =
                              double.tryParse(_amountCtrl.text) ?? 0;
                          final total = cashAmt + tdsAmt;
                          if (total <= 0) return const SizedBox.shrink();
                          final pct =
                              (tdsAmt / total * 100).toStringAsFixed(1);
                          return Text(
                            'TDS = $pct% of total settlement'
                            ' ($sym${total.toStringAsFixed(2)})',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.subtext(ctx)),
                          );
                        }),
                      ],
                      SizedBox(height: 12),
                      Text('Payment Method',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onCard(context))),
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

// ─── Quotations tab ───────────────────────────────────────────────────────────

class _QuotationsTab extends StatelessWidget {
  final List<Invoice> quotations;
  final String search;
  const _QuotationsTab({required this.quotations, required this.search});

  @override
  Widget build(BuildContext context) {
    final filtered = search.isEmpty
        ? quotations
        : quotations.where((q) {
            final q2 = search.toLowerCase();
            return q.invoiceNumber.toLowerCase().contains(q2) ||
                (q.client?.displayName.toLowerCase().contains(q2) ?? false);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.request_quote_outlined,
                size: 56,
                color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            SizedBox(height: 12),
            Text('No quotations yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context))),
            SizedBox(height: 6),
            Text('Create a quotation from an invoice',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.subtext(context))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final q = filtered[i];
        final qs = q.quotationStatus;
        final statusColor = qs?.color ?? AppTheme.textSecondary;
        final statusLabel = qs?.label ?? 'Draft';
        final currency = q.currency;
        final card = GestureDetector(
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
                builder: (_) => CreateInvoiceScreen(invoice: q)),
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.card(ctx),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.request_quote_outlined,
                      color: Color(0xFF7C3AED), size: 20),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.client?.displayName ?? 'No Client',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.onCard(ctx)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${q.invoiceNumber} · ${Fmt.date(q.invoiceDate)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(ctx)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.currencyAmount(q.grandTotal, currency),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.onCard(ctx)),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => showQuotationStatusSheet(
                        ctx,
                        currentStatus: q.quotationStatus,
                        onStatusSelected: (s) {
                          q.quotationStatus = s;
                          ctx.read<AppProvider>().saveInvoice(q);
                        },
                        onConvertToInvoice: () async {
                          q.quotationStatus = QuotationStatus.approved;
                          final provider = ctx.read<AppProvider>();
                          await provider.saveInvoice(q);
                          if (!ctx.mounted) return;
                          final inv = await provider
                              .convertQuotationToInvoice(q.id);
                          if (ctx.mounted) {
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreateInvoiceScreen(invoice: inv),
                              ),
                            );
                          }
                        },
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              statusLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor),
                            ),
                            Icon(Icons.arrow_drop_down,
                                size: 14, color: statusColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        return Dismissible(
          key: Key(q.id),
          direction: DismissDirection.horizontal,
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
              Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => CreateInvoiceScreen(invoice: q)));
              return false;
            }
            return await showDialog<bool>(
              context: ctx,
              builder: (dlg) => AlertDialog(
                title: const Text('Delete Quotation'),
                content: Text('Delete ${q.invoiceNumber}? This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dlg, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(dlg, true),
                      child: const Text('Delete',
                          style: TextStyle(color: AppTheme.error))),
                ],
              ),
            );
          },
          onDismissed: (_) => ctx.read<AppProvider>().deleteInvoice(q.id),
          child: card,
        );
      },
    );
  }
}

// ─── Credit Notes tab ──────────────────────────────────────────────────────────

class _CreditNotesTab extends StatelessWidget {
  final List<Invoice> creditNotes;
  final String search;
  const _CreditNotesTab({required this.creditNotes, required this.search});

  @override
  Widget build(BuildContext context) {
    final filtered = search.isEmpty
        ? creditNotes
        : creditNotes.where((cn) {
            final q = search.toLowerCase();
            return cn.invoiceNumber.toLowerCase().contains(q) ||
                (cn.client?.displayName.toLowerCase().contains(q) ?? false);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off_outlined,
                size: 56,
                color: AppTheme.subtext(context).withValues(alpha: 0.4)),
            SizedBox(height: 12),
            Text('No credit notes yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context))),
            SizedBox(height: 6),
            Text('Tap "Issue Credit Note" on any sent or paid invoice',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.subtext(context))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final cn = filtered[i];
        const cnColor = Color(0xFFDC2626);
        final card = GestureDetector(
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
                builder: (_) => CreateInvoiceScreen(invoice: cn)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.card(ctx),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cnColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.credit_card_off_outlined,
                      color: cnColor, size: 20),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cn.client?.displayName ?? 'No Client',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.onCard(ctx)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${cn.invoiceNumber} · ${Fmt.date(cn.invoiceDate)}',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.subtext(ctx)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.currencyAmount(cn.grandTotal, cn.currency),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.onCard(ctx)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cnColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'CREDIT NOTE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: cnColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        return Dismissible(
          key: Key(cn.id),
          direction: DismissDirection.horizontal,
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
              Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => CreateInvoiceScreen(invoice: cn)));
              return false;
            }
            return await showDialog<bool>(
              context: ctx,
              builder: (dlg) => AlertDialog(
                title: const Text('Delete Credit Note'),
                content: Text('Delete ${cn.invoiceNumber}? This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dlg, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(dlg, true),
                      child: const Text('Delete',
                          style: TextStyle(color: AppTheme.error))),
                ],
              ),
            );
          },
          onDismissed: (_) => ctx.read<AppProvider>().deleteInvoice(cn.id),
          child: card,
        );
      },
    );
  }
}
