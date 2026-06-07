import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../models/partial_payment.dart';
import '../services/exchange_rate_service.dart';
import '../providers/app_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/gst_utils.dart';
import '../utils/pdf_generator.dart';
import '../utils/share_service.dart';
import '../models/subscription_limits.dart' show LimitType;
import '../widgets/paywall_sheet.dart';
import '../widgets/quotation_status_sheet.dart';
import '../widgets/status_badge.dart';
import 'client_picker_screen.dart';
import 'recurring_invoices_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/custom_field.dart';
import '../models/employee.dart';
import '../models/recurring_schedule.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Invoice invoice;
  const CreateInvoiceScreen({super.key, required this.invoice});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  late Invoice _invoice;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _invoiceNumCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _discountCtrl;
  bool _discountIsPercent = true; // % vs flat amount toggle
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice.copy();
    // Pre-fill GST defaults on new invoices (placeOfSupply not yet set).
    final profile = context.read<AppProvider>().profile;
    if (_invoice.placeOfSupply == null && profile.defaultPlaceOfSupply != null) {
      _invoice.placeOfSupply = profile.defaultPlaceOfSupply;
    }
    if (!_invoice.reverseCharge && profile.defaultReverseCharge) {
      _invoice.reverseCharge = profile.defaultReverseCharge;
    }
    _subjectCtrl = TextEditingController(text: _invoice.subject ?? '');
    _notesCtrl = TextEditingController(text: _invoice.notes ?? '');
    _termsCtrl = TextEditingController(
        text: _invoice.terms ??
            'Payment is due within the stated due date. Late payments may incur a fee.');
    _invoiceNumCtrl = TextEditingController(text: _invoice.invoiceNumber);
    if (_invoice.globalDiscountFlat > 0) {
      _discountIsPercent = false;
      _discountCtrl = TextEditingController(
          text: _invoice.globalDiscountFlat.toStringAsFixed(2));
    } else {
      _discountIsPercent = true;
      _discountCtrl = TextEditingController(
          text: _invoice.globalDiscountPercent == 0
              ? ''
              : _invoice.globalDiscountPercent.toStringAsFixed(2));
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _notesCtrl.dispose();
    _termsCtrl.dispose();
    _invoiceNumCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _invoice.subject = _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim();
    _invoice.notes = _notesCtrl.text.trim();
    _invoice.terms = _termsCtrl.text.trim();
    _invoice.invoiceNumber = _invoiceNumCtrl.text.trim();
    // Capture context-dependent values before any await.
    final provider = context.read<AppProvider>();
    final fx = context.read<ExchangeRateService>();
    final baseCurrency = provider.profile.currency;
    // Freeze the secondary-currency exchange rate at save time so the PDF
    // always shows a consistent converted amount regardless of future rate changes.
    if (_invoice.secondaryCurrency != null) {
      await fx.fetchIfNeeded(baseCurrency);
      _invoice.secondaryExchangeRate = fx.getRate(
        _invoice.currency,
        _invoice.secondaryCurrency!,
      );
    } else {
      _invoice.secondaryExchangeRate = null;
    }
    setState(() => _saving = true);
    await provider.saveInvoice(_invoice);
    setState(() => _saving = false);
    // Show interstitial ad on free tier every 3rd save.
    AdService.instance.onInvoiceSaved(
      isFreeTier: provider.profile.subscriptionTier == SubscriptionTier.free,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _generatePdf() async {
    await _save();
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final bytes =
        await PdfGenerator.generateInvoicePdf(_invoice, provider.profile);
    if (mounted) {
      await Printing.layoutPdf(onLayout: (_) => bytes);
    }
  }

  void _pickClient() async {
    final client = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const ClientPickerScreen()),
    );
    if (client != null) {
      setState(() => _invoice.client = client);
    }
  }

  void _addLineItem() {
    final profile = context.read<AppProvider>().profile;
    if (profile.serviceItems.isEmpty) {
      setState(() {
        _invoice.items.add(LineItem(
          description: '',
          rate: 0,
          taxPercent: profile.defaultTaxPercent,
        ));
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CatalogPickerSheet(
        items: profile.serviceItems,
        itemLabel: profile.itemLabel,
      ),
    ).then((picked) async {
      if (!mounted) return;
      if (picked == null) {
        setState(() {
          _invoice.items.add(LineItem(
            description: '',
            rate: 0,
            taxPercent: profile.defaultTaxPercent,
          ));
        });
      } else {
        final s = picked as ServiceItem;
        final qty = await _showQtyPickerDialog(context, s.name) ?? 1.0;
        if (!mounted) return;
        setState(() {
          _invoice.items.add(LineItem(
            description: s.description?.isNotEmpty == true
                ? s.description!
                : s.name,
            rate: s.rate,
            taxPercent: s.taxPercent,
            quantity: qty,
            category: s.category,
          ));
        });
      }
    });
  }

  void _removeLineItem(int index) {
    setState(() => _invoice.items.removeAt(index));
  }

  Future<void> _changeStatus(InvoiceStatus status) async {
    if (status == InvoiceStatus.paid ||
        status == InvoiceStatus.partiallyPaid) {
      await _recordPayment(prefillRemaining: status == InvoiceStatus.paid);
      return;
    }
    final provider = context.read<AppProvider>();
    await provider.updateInvoiceStatus(_invoice.id, status);
    setState(() => _invoice.status = status);

    if (status == InvoiceStatus.sent && mounted) {
      final profile = provider.profile;
      final invoice = _invoice;
      final ctx = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showShareInvoiceSheet(ctx, invoice, profile);
      });
    }
  }

  Future<void> _recordPayment({bool prefillRemaining = false}) async {
    final limitInfo = context.read<AppProvider>().checkFeature(LimitType.partialPayments);
    if (limitInfo != null) {
      final upgrade = await showPaywallSheet(context, limitInfo);
      if (upgrade && mounted) Navigator.pushNamed(context, '/plans');
      return;
    }
    final provider = context.read<AppProvider>();
    final baseCurrency = provider.profile.currency;
    final payment = await showModalBottomSheet<PartialPayment>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _RecordPaymentSheet(
        grandTotal: _invoice.grandTotal,
        amountPaid: _invoice.amountPaid,
        currency: _invoice.currency,
        baseCurrency: baseCurrency,
        methods: provider.profile.allPaymentMethods,
        prefillRemaining: prefillRemaining,
      ),
    );
    if (payment == null || !mounted) return;
    setState(() {
      _invoice.payments.add(payment);
      _invoice.paymentMethodId = payment.paymentMethodId;
      _invoice.paymentMethodName = payment.paymentMethodName;
      _invoice.status = _invoice.amountPaid >= _invoice.grandTotal - 0.01
          ? InvoiceStatus.paid
          : InvoiceStatus.partiallyPaid;
    });
    _invoice.subject = _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim();
    _invoice.notes = _notesCtrl.text.trim();
    _invoice.terms = _termsCtrl.text.trim();
    _invoice.invoiceNumber = _invoiceNumCtrl.text.trim();
    await provider.saveInvoice(_invoice);
  }

  Future<void> _showCreditNoteDialog() async {
    // Guard: only one credit note per invoice.
    if (context.read<AppProvider>().hasCreditNote(_invoice.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A credit note has already been issued for this invoice.'),
        ),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    final reasonCtrl = TextEditingController();

    // issueCreditNote is called INSIDE the button handler, BEFORE Navigator.pop,
    // so notifyListeners() fires while the dialog is fully mounted (no animation
    // in progress). The dialog pops with the finished Invoice as its result,
    // eliminating the _dependents.isEmpty race entirely.
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
                  Text(
                    'Invoice: ${_invoice.invoiceNumber}  ·  '
                    '${Fmt.currencyAmount(_invoice.grandTotal, _invoice.currency)}',
                  ),
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
                          final invoice = await provider.issueCreditNote(
                            linkedInvoiceId: _invoice.id,
                            reason: reasonCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx, invoice);
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

    // Defer disposal to let the dialog's exit animation finish before the
    // TextField releases its reference to the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => reasonCtrl.dispose());

    if (cn == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: cn)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final symbol = Fmt.currencySymbol(_invoice.currency);
    final profile = provider.profile;

    // Determine whether this is a new invoice (not yet persisted).
    final isNew = !provider.invoices.any((i) => i.id == _invoice.id);
    final canEdit = provider.canDo(
        isNew ? AppPermission.createInvoice : AppPermission.editInvoice);
    final canChangeStatus = provider.canDo(AppPermission.sendInvoice) ||
        provider.canDo(AppPermission.markInvoicePaid);
    final showTax = profile.isGstRegistered || profile.defaultTaxPercent > 0;
    final showQty = profile.showQuantity;

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          StatusBadge(status: _invoice.status),
          const SizedBox(width: 8),
          if (canChangeStatus)
            PopupMenuButton<InvoiceStatus>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Change status',
              onSelected: _changeStatus,
              itemBuilder: (_) {
                return InvoiceStatus.values.where((s) {
                  if (s == InvoiceStatus.sent) {
                    return provider.canDo(AppPermission.sendInvoice);
                  }
                  if (s == InvoiceStatus.paid ||
                      s == InvoiceStatus.partiallyPaid) {
                    return provider.canDo(AppPermission.markInvoicePaid);
                  }
                  return canEdit;
                }).map((s) => PopupMenuItem(
                      value: s,
                      child: Text(s.label),
                    )).toList();
              },
            ),
          if (!isNew && canEdit)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Duplicate Invoice',
              onPressed: () async {
                final copy = await provider.duplicateInvoice(_invoice.id);
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CreateInvoiceScreen(invoice: copy)),
                  );
                }
              },
            ),
          if (!_invoice.isQuotation && !_invoice.isCreditNote && !isNew &&
              !provider.hasCreditNote(_invoice.id))
            IconButton(
              icon: const Icon(Icons.credit_card_off_outlined),
              tooltip: 'Issue Credit Note',
              onPressed: () async {
                final info = context.read<AppProvider>().checkFeature(LimitType.creditNotes);
                if (info == null) { _showCreditNoteDialog(); return; }
                final up = await showPaywallSheet(context, info); // ignore: use_build_context_synchronously
                if (up && mounted) Navigator.pushNamed(context, '/plans');
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Credit Note linked-invoice banner ────────────────────────────
            if (_invoice.isCreditNote &&
                _invoice.creditNoteLinkedInvoiceId != null) ...[
              Builder(builder: (ctx) {
                final linked = context
                    .read<AppProvider>()
                    .invoices
                    .cast<Invoice?>()
                    .firstWhere(
                      (i) => i?.id == _invoice.creditNoteLinkedInvoiceId,
                      orElse: () => null,
                    );
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFCA5A5), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          linked != null
                              ? 'Credit note for ${linked.invoiceNumber}'
                              : 'Credit note for original invoice',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (linked != null)
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    CreateInvoiceScreen(invoice: linked)),
                          ),
                          child: const Text('View',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline)),
                        ),
                    ],
                  ),
                );
              }),
            ],
            _section(
              l10n.invoiceDetails,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          label: 'Invoice Number',
                          controller: _invoiceNumCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _datePicker(
                          label: 'Invoice Date',
                          date: _invoice.invoiceDate,
                          onPicked: (d) =>
                              setState(() => _invoice.invoiceDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _datePicker(
                    label: 'Due Date',
                    date: _invoice.dueDate,
                    onPicked: (d) => setState(() => _invoice.dueDate = d),
                  ),
                  const SizedBox(height: 12),
                  _currencySection(),
                  if (profile.isGstRegistered) ...[
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Place of Supply',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: indianStatesForGst.contains(_invoice.placeOfSupply)
                              ? _invoice.placeOfSupply
                              : null,
                          hint: const Text('Select state',
                              style: TextStyle(fontSize: 14)),
                          isDense: true,
                          isExpanded: true,
                          items: indianStatesForGst
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        style: const TextStyle(fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _invoice.placeOfSupply = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reverse Charge',
                          style: TextStyle(fontSize: 14)),
                      subtitle: const Text(
                          'Tax payable by recipient',
                          style: TextStyle(fontSize: 11)),
                      value: _invoice.reverseCharge,
                      onChanged: (v) =>
                          setState(() => _invoice.reverseCharge = v),
                    ),
                  ],
                ],
              ),
            ),
            // ── Quotation toggle ─────────────────────────────────────────
            if (canEdit) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outline(context)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('Mark as Quotation / Estimate',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'PDF shows "QUOTATION" · convert to invoice when approved',
                          style: TextStyle(fontSize: 11)),
                      value: _invoice.isQuotation,
                      activeThumbColor: const Color(0xFF7C3AED),
                      onChanged: (v) async {
                        if (v) {
                          final info = context.read<AppProvider>().checkFeature(LimitType.quotations);
                          if (info != null) {
                            final up = await showPaywallSheet(context, info); // ignore: use_build_context_synchronously
                            if (up && mounted) Navigator.pushNamed(context, '/plans');
                            return;
                          }
                        }
                        final provider = context.read<AppProvider>();
                        final isNewDoc = !provider.invoices
                            .any((i) => i.id == _invoice.id);
                        setState(() {
                          _invoice.isQuotation = v;
                          if (v) {
                            _invoice.quotationStatus ??= QuotationStatus.draft;
                            // Auto-fill a quotation number for unsaved docs.
                            if (isNewDoc) {
                              _invoiceNumCtrl.text =
                                  provider.generateQuotationNumber();
                            }
                          } else if (isNewDoc) {
                            // Restore to invoice number when toggling off.
                            _invoiceNumCtrl.text =
                                provider.generateInvoiceNumber();
                          }
                        });
                      },
                    ),
                    if (_invoice.isQuotation) ...[
                      const Divider(height: 1),
                      // ── Tappable status badge ──────────────────────────
                      InkWell(
                        onTap: () => showQuotationStatusSheet(
                          context,
                          currentStatus: _invoice.quotationStatus,
                          onStatusSelected: (s) =>
                              setState(() => _invoice.quotationStatus = s),
                          onConvertToInvoice: isNew
                              ? null // can't convert an unsaved quotation
                              : () async {
                                  await _save();
                                  if (!context.mounted) return;
                                  final inv = await context
                                      .read<AppProvider>()
                                      .convertQuotationToInvoice(_invoice.id);
                                  if (context.mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              CreateInvoiceScreen(invoice: inv)),
                                    );
                                  }
                                },
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Row(
                            children: [
                              Text('Status:',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.subtext(context))),
                              const SizedBox(width: 10),
                              Builder(builder: (_) {
                                final s = _invoice.quotationStatus ??
                                    QuotationStatus.draft;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: s.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: s.color.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(s.label,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: s.color)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_drop_down,
                                          size: 16, color: s.color),
                                    ],
                                  ),
                                );
                              }),
                              const Spacer(),
                              Text('tap to change',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.subtext(context))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _section(
              l10n.client,
              action: canEdit
                  ? TextButton.icon(
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: Text(_invoice.client == null
                          ? l10n.selectClient
                          : l10n.change),
                      onPressed: _pickClient,
                    )
                  : null,
              child: _invoice.client == null
                  ? GestureDetector(
                      onTap: _pickClient,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.outline(context),
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person_outline,
                                color: AppTheme.subtext(context)),
                            const SizedBox(height: 4),
                            Text('Tap to select client',
                                style: TextStyle(
                                    color: AppTheme.subtext(context),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : _clientCard(_invoice.client!),
            ),
            const SizedBox(height: 16),
            _section(
              l10n.lineItems,
              action: canEdit
                  ? TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('${l10n.add} ${profile.itemLabel}'),
                      onPressed: _addLineItem,
                    )
                  : null,
              child: Column(
                children: [
                  if (_invoice.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: _addLineItem,
                          icon: const Icon(Icons.add_circle_outline),
                          label: Text(
                              'Add your first ${profile.itemLabel.toLowerCase()}'),
                        ),
                      ),
                    )
                  else
                    ...List.generate(
                      _invoice.items.length,
                      (i) => _LineItemRow(
                        key: ValueKey(_invoice.items[i]),
                        item: _invoice.items[i],
                        symbol: symbol,
                        index: i,
                        onRemove: () => _removeLineItem(i),
                        onChanged: () => setState(() {}),
                        showTax: showTax,
                        showQty: showQty,
                        showHsn: profile.isGstRegistered,
                        itemLabel: profile.itemLabel,
                        serviceItems: profile.serviceItems,
                        canEdit: canEdit,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _totalsCard(symbol),
            const SizedBox(height: 16),
            _paymentsSection(symbol),
            const SizedBox(height: 16),
            _section(
              l10n.subject,
              child: TextField(
                controller: _subjectCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Professional fees for hearing on 07.01.2025 (optional)',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section(
              l10n.notes,
              child: TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add any notes for the client...',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section(
              l10n.termsAndConditions,
              child: TextField(
                controller: _termsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Terms and conditions...',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generatePdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l10n.previewPdf),
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(l10n.save),
                    ),
                  ),
                ],
              ],
            ),

            // ── Set Recurring ────────────────────────────────────────────
            if (canEdit && !_invoice.isQuotation) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final info = context.read<AppProvider>().checkFeature(LimitType.recurringInvoices);
                    if (info != null) {
                      final up = await showPaywallSheet(context, info); // ignore: use_build_context_synchronously
                      if (up && mounted) Navigator.pushNamed(context, '/plans');
                      return;
                    }
                    if (mounted) showRecurringSetupSheet(context, _invoice);
                  },
                  icon: const Icon(Icons.repeat_rounded, size: 18),
                  label: const Text('Set as Recurring Invoice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF059669)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, {required Widget child, Widget? action}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context))),
                const Spacer(),
                ?action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _field(
      {required String label,
      required TextEditingController controller,
      TextInputType? keyboardType,
      String? hint}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _datePicker(
      {required String label,
      required DateTime date,
      required ValueChanged<DateTime> onPicked}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(Fmt.date(date),
            style: TextStyle(fontSize: 14, color: AppTheme.onCard(context))),
      ),
    );
  }

  Widget _currencySection() {
    final fx = context.watch<ExchangeRateService>();
    final baseCurrency = context.read<AppProvider>().profile.currency;
    final secCur = _invoice.secondaryCurrency;

    // Live rate string shown beneath the secondary dropdown
    String? liveRateLabel;
    if (secCur != null && fx.hasRates) {
      final rate = fx.getRate(_invoice.currency, secCur);
      final secSym = Fmt.currencySymbol(secCur);
      liveRateLabel = '1 ${_invoice.currency} ≈ $secSym${rate.toStringAsFixed(4)}  (live rate)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Primary currency ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Currency'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _invoice.currency,
                    isDense: true,
                    items: Fmt.supportedCurrencies
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('$c  ${Fmt.currencySymbol(c).trim()}'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _invoice.currency = v;
                        // Clear frozen rate — will be re-fetched on save
                        _invoice.secondaryExchangeRate = null;
                      });
                      // Fetch rates so the live-rate preview updates immediately
                      fx.fetchIfNeeded(baseCurrency);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Secondary / converted currency (optional) ─────────────────
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Also show converted total in',
                  helperText: 'Optional — printed on the invoice PDF',
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: secCur,
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Off — single currency'),
                      ),
                      ...Fmt.supportedCurrencies
                          .where((c) => c != _invoice.currency)
                          .map((c) => DropdownMenuItem<String?>(
                                value: c,
                                child: Text('$c  ${Fmt.currencySymbol(c).trim()}'),
                              )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _invoice.secondaryCurrency = v;
                        _invoice.secondaryExchangeRate = null;
                      });
                      if (v != null) fx.fetchIfNeeded(baseCurrency);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        // ── Live rate preview ─────────────────────────────────────────
        if (secCur != null) ...[
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: fx.loading
                ? const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Row(children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Fetching live rate…', style: TextStyle(fontSize: 12)),
                    ]),
                  )
                : liveRateLabel != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              liveRateLabel,
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Rate unavailable — connect to the internet to fetch',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
          ),
        ],
      ],
    );
  }

  Widget _clientCard(Client client) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            radius: 20,
            child: Text(
              client.displayName.isNotEmpty
                  ? client.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.displayName,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context))),
                Text(client.email,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.subtext(context))),
                if (client.city.isNotEmpty)
                  Text('${client.city}, ${client.state}',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard(String symbol) {
    final profile = context.read<AppProvider>().profile;
    final supplyType =
        getSupplyType(profile.gstin, _invoice.placeOfSupply);
    final taxItems = _invoice.items
        .where((i) => i.taxPercent > 0)
        .map((i) => (taxableAmount: i.taxableAmount, taxPercent: i.taxPercent))
        .toList();
    final gst = profile.isGstRegistered && _invoice.totalTax > 0
        ? computeInvoiceGst(taxItems, supplyType)
        : null;
    final rates =
        taxItems.map((i) => i.taxPercent).toSet();
    final single = rates.length == 1 ? rates.first : null;

    String fmtRate(double r) =>
        r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _totalRow('Subtotal', '$symbol${_invoice.subtotal.toStringAsFixed(2)}'),

            // ── Bill-level discount input ──────────────────────────────────
            _discountInputRow(symbol),

            // Item-level discounts summary (if any, separate from bill discount)
            if (_invoice.items.fold(0.0, (s, i) => s + i.discountAmount) > 0)
              _totalRow(
                'Item Discounts',
                '-$symbol${_invoice.items.fold(0.0, (s, i) => s + i.discountAmount).toStringAsFixed(2)}',
                color: AppTheme.error,
              ),

            if (_invoice.totalTax > 0) ...[
              if (gst != null && supplyType == GstSupplyType.interState)
                _totalRow(
                    single != null
                        ? 'IGST (${fmtRate(single)}%)'
                        : 'IGST',
                    '$symbol${gst.totalIgst.toStringAsFixed(2)}')
              else if (gst != null) ...[
                _totalRow(
                    single != null
                        ? 'CGST (${fmtRate(single / 2)}%)'
                        : 'CGST',
                    '$symbol${gst.totalCgst.toStringAsFixed(2)}'),
                _totalRow(
                    single != null
                        ? 'SGST/UTGST (${fmtRate(single / 2)}%)'
                        : 'SGST/UTGST',
                    '$symbol${gst.totalSgst.toStringAsFixed(2)}'),
              ] else
                _totalRow(
                    'Tax', '$symbol${_invoice.totalTax.toStringAsFixed(2)}'),
            ],
            const Divider(height: 20),
            _totalRow(
                'Total',
                '$symbol${_invoice.grandTotal.toStringAsFixed(2)}',
                isBold: true,
                fontSize: 18),
          ],
        ),
      ),
    );
  }

  Widget _discountInputRow(String symbol) {
    final hasDiscount = _discountIsPercent
        ? _invoice.globalDiscountPercent > 0
        : _invoice.globalDiscountFlat > 0;
    final discountAmount = _discountIsPercent
        ? _invoice.subtotal * (_invoice.globalDiscountPercent / 100)
        : _invoice.globalDiscountFlat;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Label
          Text('Bill Discount',
              style: TextStyle(fontSize: 14, color: AppTheme.subtext(context))),
          const SizedBox(width: 8),

          // % / ₹ toggle chip
          GestureDetector(
            onTap: () {
              setState(() {
                _discountIsPercent = !_discountIsPercent;
                _discountCtrl.clear();
                _invoice.globalDiscountPercent = 0;
                _invoice.globalDiscountFlat = 0;
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                _discountIsPercent ? '%' : symbol,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Input field
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _discountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _discountIsPercent ? '0.00' : '0.00',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                ),
                onChanged: (v) {
                  final val = double.tryParse(v) ?? 0;
                  setState(() {
                    if (_discountIsPercent) {
                      _invoice.globalDiscountPercent =
                          val.clamp(0, 100);
                      _invoice.globalDiscountFlat = 0;
                    } else {
                      _invoice.globalDiscountFlat =
                          val.clamp(0, double.infinity);
                      _invoice.globalDiscountPercent = 0;
                    }
                  });
                },
              ),
            ),
          ),

          // Computed discount amount shown on the right
          if (hasDiscount) ...[
            const SizedBox(width: 10),
            Text(
              '-$symbol${discountAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool isBold = false,
      double fontSize = 14,
      Color? color}) {
    final effectiveColor = color ?? AppTheme.onCard(context);
    final style =
        TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, color: effectiveColor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _paymentsSection(String symbol) {
    // Invoice must not be paid/cancelled AND the user must have the permission.
    final canRecord = (_invoice.status != InvoiceStatus.paid &&
            _invoice.status != InvoiceStatus.cancelled) &&
        context.read<AppProvider>().canDo(AppPermission.recordPayment);
    final hasPayments = _invoice.payments.isNotEmpty;

    if (!hasPayments && !canRecord) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.payment,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context))),
                    Text('TDS deduction supported',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.subtext(context))),
                  ],
                ),
                const Spacer(),
                if (canRecord)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(AppLocalizations.of(context)!.recordPayment),
                    onPressed: _recordPayment,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (hasPayments) ...[
            ...List.generate(_invoice.payments.length, (i) {
              final p = _invoice.payments[i];
              final date =
                  '${p.date.day}/${p.date.month}/${p.date.year}';
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 16, color: AppTheme.success),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.paymentMethodName ?? 'Payment',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.onCard(context)),
                              ),
                              Text(
                                date +
                                    (p.notes != null
                                        ? ' · ${p.notes}'
                                        : ''),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.subtext(context)),
                              ),
                              if (p.baseAmount != null &&
                                  p.exchangeRate != null &&
                                  p.baseCurrencyCode != null)
                                Text(
                                  '≈ ${p.baseCurrencyCode} ${p.baseAmount!.toStringAsFixed(2)}  (1 ${_invoice.currency} = ${p.exchangeRate!.toStringAsFixed(4)} ${p.baseCurrencyCode})',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.subtext(context)),
                                ),
                              if ((p.tdsAmount ?? 0) > 0)
                                Text(
                                  'TDS ${p.tdsPercent != null ? '(${p.tdsPercent!.toStringAsFixed(0)}%)' : ''}: $symbol${p.tdsAmount!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF0284C7)),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$symbol${p.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.success),
                            ),
                            if ((p.tdsAmount ?? 0) > 0)
                              Text(
                                '+$symbol${p.tdsAmount!.toStringAsFixed(2)} TDS',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (i < _invoice.payments.length - 1)
                    const Divider(height: 1, indent: 58),
                ],
              );
            }),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (hasPayments) ...[
                  // Cash received row
                  if (_invoice.totalTdsDeducted > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cash Received',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.subtext(context))),
                        Text(
                          '$symbol${_invoice.cashReceived.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.subtext(context)),
                        ),
                      ],
                    ),
                  // TDS credit row
                  if (_invoice.totalTdsDeducted > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TDS Credit',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0284C7))),
                        Text(
                          '+$symbol${_invoice.totalTdsDeducted.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.totalPaid,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.subtext(context))),
                      Text(
                        '$symbol${_invoice.amountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.balanceDue,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onCard(context))),
                    Text(
                      '$symbol${_invoice.amountRemaining.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _invoice.amountRemaining > 0
                              ? AppTheme.error
                              : AppTheme.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── "Show on invoice" toggle ─────────────────────────────
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: const Text('Show payments on bill',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: const Text(
                'Prints paid amounts & balance due on the invoice PDF',
                style: TextStyle(fontSize: 11)),
            value: _invoice.showPaymentsOnInvoice,
            activeThumbColor: AppTheme.primary,
            onChanged: (v) =>
                setState(() => _invoice.showPaymentsOnInvoice = v),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RecordPaymentSheet extends StatefulWidget {
  final double grandTotal;
  final double amountPaid;
  final String currency;
  final String baseCurrency;
  final List<PaymentMethod> methods;
  final bool prefillRemaining;

  const _RecordPaymentSheet({
    required this.grandTotal,
    required this.amountPaid,
    required this.currency,
    required this.baseCurrency,
    required this.methods,
    this.prefillRemaining = false,
  });

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  String _selectedMethodId = '__cash__';
  final _formKey = GlobalKey<FormState>();
  bool _hasTds = false;
  final _tdsCtrl = TextEditingController();

  bool get _isForeign => widget.currency != widget.baseCurrency;

  @override
  void initState() {
    super.initState();
    final remaining = widget.grandTotal - widget.amountPaid;
    _amountCtrl = TextEditingController(
      text: widget.prefillRemaining && remaining > 0
          ? remaining.toStringAsFixed(2)
          : '',
    );
    _notesCtrl = TextEditingController();

    // Trigger rate fetch after first frame so context is available
    if (_isForeign) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context
              .read<ExchangeRateService>()
              .fetchIfNeeded(widget.baseCurrency);
        }
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _tdsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final method =
        widget.methods.firstWhere((m) => m.id == _selectedMethodId);
    final amount = double.parse(_amountCtrl.text);

    double? rate;
    double? baseAmount;
    if (_isForeign) {
      final fx = context.read<ExchangeRateService>();
      if (fx.hasRates) {
        rate = fx.toBase(1, widget.currency);
        baseAmount = fx.toBase(amount, widget.currency);
      }
    }

    final tdsAmt = _hasTds ? (double.tryParse(_tdsCtrl.text) ?? 0) : null;
    final tdsPercent = (tdsAmt != null && amount > 0)
        ? tdsAmt / (amount + tdsAmt) * 100
        : null;

    Navigator.pop(
      context,
      PartialPayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        amount: amount,
        paymentMethodId: method.id,
        paymentMethodName: method.name,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        exchangeRate: rate,
        baseCurrencyCode: _isForeign ? widget.baseCurrency : null,
        baseAmount: baseAmount,
        tdsPercent: tdsPercent,
        tdsAmount: tdsAmt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = _isForeign ? context.watch<ExchangeRateService>() : null;
    final sym = Fmt.currencySymbol(widget.currency);
    final baseSym = Fmt.currencySymbol(widget.baseCurrency);
    final remaining = widget.grandTotal - widget.amountPaid;

    // Live conversion from typed amount
    final enteredAmount = double.tryParse(_amountCtrl.text);
    final rate = (_isForeign && fx != null && fx.hasRates)
        ? fx.toBase(1, widget.currency)
        : null;
    final convertedAmount = (rate != null && enteredAmount != null)
        ? enteredAmount * rate
        : null;

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
            Row(
              children: [
                Text(
                  widget.prefillRemaining
                      ? 'Record Final Payment'
                      : 'Record Payment',
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryCol('Invoice Total',
                      '$sym${widget.grandTotal.toStringAsFixed(2)}',
                      AppTheme.onCard(context)),
                  if (widget.amountPaid > 0)
                    _summaryCol('Paid',
                        '$sym${widget.amountPaid.toStringAsFixed(2)}',
                        AppTheme.success),
                  _summaryCol('Balance Due',
                      '$sym${remaining.toStringAsFixed(2)}', AppTheme.error),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: !widget.prefillRemaining,
              onChanged: (_) => setState(() {}), // trigger live conversion
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: sym,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter amount';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                final tdsAmt = _hasTds
                    ? (double.tryParse(_tdsCtrl.text) ?? 0)
                    : 0.0;
                if (n + tdsAmt > remaining + 0.01) {
                  return 'Exceeds balance due ($sym${remaining.toStringAsFixed(2)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // TDS toggle
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('TDS Deducted by Client', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Tax Deducted at Source (Section 194J, 194C, etc.)', style: TextStyle(fontSize: 10)),
              value: _hasTds,
              activeThumbColor: AppTheme.primary,
              onChanged: (v) => setState(() { _hasTds = v; if (!v) _tdsCtrl.clear(); }),
            ),
            if (_hasTds) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _tdsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'TDS Amount',
                  prefixText: sym,
                  hintText: '0.00',
                ),
                validator: (v) {
                  if (!_hasTds) return null;
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Enter valid TDS amount';
                  return null;
                },
              ),
              const SizedBox(height: 4),
              // Helper: show TDS % relative to invoice total
              Builder(builder: (ctx) {
                final tdsAmt = double.tryParse(_tdsCtrl.text) ?? 0;
                final cashAmt = double.tryParse(_amountCtrl.text) ?? 0;
                final total = cashAmt + tdsAmt;
                if (total <= 0) return const SizedBox.shrink();
                final pct = (tdsAmt / total * 100).toStringAsFixed(1);
                return Text('TDS = $pct% of total settlement ($sym${total.toStringAsFixed(2)})',
                    style: TextStyle(fontSize: 10, color: AppTheme.subtext(context)));
              }),
            ],
            // Exchange rate row — only shown when currencies differ
            if (_isForeign) ...[
              const SizedBox(height: 6),
              if (fx!.loading)
                Row(children: [
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5)),
                  const SizedBox(width: 8),
                  Text('Fetching live rate…',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              AppTheme.subtext(context).withValues(alpha: 0.8))),
                ])
              else if (rate != null)
                Row(children: [
                  Icon(Icons.swap_horiz,
                      size: 14, color: AppTheme.subtext(context)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      convertedAmount != null
                          ? '≈ $baseSym${convertedAmount.toStringAsFixed(2)}  '
                              '(1 ${widget.currency} = $baseSym${rate.toStringAsFixed(2)})'
                          : '1 ${widget.currency} = $baseSym${rate.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.subtext(context)),
                    ),
                  ),
                ])
              else
                Text('Rate unavailable — amount recorded as-is',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.subtext(context).withValues(alpha: 0.7))),
            ],
            const SizedBox(height: 16),
            Text('Payment Method',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onCard(context))),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: _selectedMethodId,
              onChanged: (v) {
                if (v != null) setState(() => _selectedMethodId = v);
              },
              child: Column(
                children: widget.methods
                    .map((m) => RadioListTile<String>(
                          value: m.id,
                          title: Text(m.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          subtitle: m.subtitle.isNotEmpty
                              ? Text(m.subtitle,
                                  style: const TextStyle(fontSize: 11))
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
                hintText: 'e.g. Cheque #1234, Bank transfer ref',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppTheme.subtext(context))),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LineItemRow extends StatefulWidget {
  final LineItem item;
  final String symbol;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final bool showTax;
  final bool showQty;
  final bool showHsn;
  final String itemLabel;
  final List<ServiceItem> serviceItems;
  final bool canEdit;

  const _LineItemRow({
    Key? key,
    required this.item,
    required this.symbol,
    required this.index,
    required this.onRemove,
    required this.onChanged,
    this.showTax = true,
    this.showQty = true,
    this.showHsn = false,
    this.itemLabel = 'Item',
    this.serviceItems = const [],
    this.canEdit = true,
  }) : super(key: key);

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _discCtrl;
  late TextEditingController _hsnCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _rateCtrl = TextEditingController(text: widget.item.rate == 0 ? '' : widget.item.rate.toString());
    _taxCtrl = TextEditingController(text: widget.item.taxPercent.toString());
    _discCtrl = TextEditingController(text: widget.item.discountPercent.toString());
    _hsnCtrl = TextEditingController(text: widget.item.hsnSac ?? '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _taxCtrl.dispose();
    _discCtrl.dispose();
    _hsnCtrl.dispose();
    super.dispose();
  }

  void _update() {
    widget.item.quantity = widget.showQty ? (double.tryParse(_qtyCtrl.text) ?? 1) : 1;
    widget.item.rate = double.tryParse(_rateCtrl.text) ?? 0;
    widget.item.taxPercent = double.tryParse(_taxCtrl.text) ?? 0;
    widget.item.discountPercent = double.tryParse(_discCtrl.text) ?? 0;
    final hsn = _hsnCtrl.text.trim();
    widget.item.hsnSac = hsn.isEmpty ? null : hsn;
    widget.onChanged();
  }

  void _selectService(ServiceItem s) {
    final desc = s.description?.isNotEmpty == true ? s.description! : s.name;
    widget.item.description = desc;
    if (s.rate > 0) {
      _rateCtrl.text = s.rate.toString();
      widget.item.rate = s.rate;
    }
    _taxCtrl.text = s.taxPercent.toString();
    widget.item.taxPercent = s.taxPercent;
    widget.item.category = s.category;
    if (s.hsnSac?.isNotEmpty == true) {
      _hsnCtrl.text = s.hsnSac!;
      widget.item.hsnSac = s.hsnSac;
    }

    // Defer to the next frame so the autocomplete overlay finishes closing
    // before we push the dialog route — avoids the InheritedElement
    // 'dependents.isEmpty' assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final qty = await _showQtyPickerDialog(context, s.name) ?? 1.0;
      if (!mounted) return;
      _qtyCtrl.text = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      widget.item.quantity = qty;
      widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${widget.itemLabel} ${widget.index + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.subtext(context))),
              const Spacer(),
              if (widget.canEdit)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.error),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Autocomplete<ServiceItem>(
            initialValue: TextEditingValue(text: widget.item.description),
            optionsBuilder: (value) {
              if (widget.serviceItems.isEmpty) return const [];
              final q = value.text.toLowerCase();
              if (q.isEmpty) return widget.serviceItems;
              return widget.serviceItems.where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  (s.description?.toLowerCase().contains(q) ?? false));
            },
            displayStringForOption: (s) =>
                s.description?.isNotEmpty == true ? s.description! : s.name,
            onSelected: _selectService,
            fieldViewBuilder: (ctx, ctrl, focusNode, _) => TextField(
              controller: ctrl,
              focusNode: focusNode,
              readOnly: !widget.canEdit,
              onChanged: widget.canEdit
                  ? (v) {
                      widget.item.description = v;
                      widget.onChanged();
                    }
                  : null,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: widget.canEdit
                    ? 'Type or search ${widget.itemLabel.toLowerCase()}s'
                    : null,
                suffixIcon: widget.canEdit && widget.serviceItems.isNotEmpty
                    ? Icon(Icons.search, size: 18,
                        color: AppTheme.subtext(ctx))
                    : null,
              ),
            ),
            optionsViewBuilder: (ctx, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 340),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final s = options.elementAt(i);
                      final desc = s.description?.isNotEmpty == true
                          ? s.description!
                          : null;
                      return ListTile(
                        dense: true,
                        title: Text(s.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: desc != null
                            ? Text(desc,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.subtext(ctx)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: s.rate > 0
                            ? Text(
                                '${widget.symbol}${s.rate.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.primary))
                            : null,
                        onTap: () => onSelected(s),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (widget.showHsn) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _hsnCtrl,
              readOnly: !widget.canEdit,
              onChanged: widget.canEdit ? (_) => _update() : null,
              decoration: const InputDecoration(
                labelText: 'HSN / SAC Code',
                hintText: 'e.g. 998313',
                prefixIcon: Icon(Icons.tag_outlined, size: 16),
              ),
            ),
          ],
          if (item.category != null && item.category!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 13, color: AppTheme.subtext(context)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    item.category!,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.subtext(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (widget.showQty)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    readOnly: !widget.canEdit,
                    onChanged: widget.canEdit ? (_) => _update() : null,
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    readOnly: !widget.canEdit,
                    onChanged: widget.canEdit ? (_) => _update() : null,
                    decoration: InputDecoration(
                      labelText: 'Rate',
                      prefixText: widget.symbol,
                    ),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: _rateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              readOnly: !widget.canEdit,
              onChanged: widget.canEdit ? (_) => _update() : null,
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText: widget.symbol,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.showTax) ...[
                Expanded(
                  child: TextField(
                    controller: _taxCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    readOnly: !widget.canEdit,
                    onChanged: widget.canEdit ? (_) => _update() : null,
                    decoration: const InputDecoration(
                      labelText: 'Tax %',
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: _discCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  readOnly: !widget.canEdit,
                  onChanged: widget.canEdit ? (_) => _update() : null,
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    suffixText: '%',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subtotal',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.subtext(context))),
                      Text(
                        '${widget.symbol}${item.taxableAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogPickerSheet extends StatefulWidget {
  final List<ServiceItem> items;
  final String itemLabel;

  const _CatalogPickerSheet({
    required this.items,
    required this.itemLabel,
  });

  @override
  State<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<_CatalogPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  // null = category overview, non-null = items within that category ('' = all)
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories {
    return widget.items
        .map((s) => s.category?.trim())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
  }

  List<ServiceItem> get _filteredItems {
    var list = widget.items;
    if (_selectedCategory == '__uncategorized__') {
      list = list
          .where((s) => s.category == null || s.category!.trim().isEmpty)
          .toList();
    } else if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      list = list
          .where((s) => s.category?.trim() == _selectedCategory)
          .toList();
    }
    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              (s.description?.toLowerCase().contains(q) ?? false) ||
              (s.category?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  bool get _isSearching => _query.isNotEmpty;
  bool get _showItemList => _selectedCategory != null || _isSearching;

  void _pickItem(ServiceItem s) => Navigator.pop(context, s);
  void _addBlank() => Navigator.pop(context, null);

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    if (_selectedCategory != null && !_isSearching)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = null),
                        child: Icon(Icons.arrow_back,
                            size: 20, color: AppTheme.subtext(context)),
                      )
                    else
                      const Icon(Icons.grid_view_rounded,
                          size: 20, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isSearching
                            ? 'Search results'
                            : _selectedCategory == '__uncategorized__'
                                ? 'Uncategorized'
                                : _selectedCategory != null && _selectedCategory!.isNotEmpty
                                    ? _selectedCategory!
                                    : _selectedCategory == ''
                                        ? 'All ${widget.itemLabel}s'
                                        : 'Pick a ${widget.itemLabel}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onCard(context)),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Search bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.itemLabel.toLowerCase()}s…',
                    prefixIcon:
                        Icon(Icons.search, size: 18, color: AppTheme.subtext(context)),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: Icon(Icons.clear,
                                size: 18, color: AppTheme.subtext(context)),
                          )
                        : null,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              // ── Body ──────────────────────────────────────────────────────
              Flexible(
                child: _showItemList
                    ? _ItemListView(
                        items: _filteredItems,
                        symbol: '₹',
                        onPick: _pickItem,
                      )
                    : _CategoryListView(
                        categories: _categories,
                        allItems: widget.items,
                        itemLabel: widget.itemLabel,
                        onSelectCategory: (cat) =>
                            setState(() => _selectedCategory = cat),
                      ),
              ),
              // ── Add blank ─────────────────────────────────────────────────
              const Divider(height: 1),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.add_circle_outline,
                    color: AppTheme.primary),
                title: Text(
                  'Add blank ${widget.itemLabel.toLowerCase()}',
                  style: const TextStyle(color: AppTheme.primary),
                ),
                onTap: _addBlank,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryListView extends StatelessWidget {
  final List<String> categories;
  final List<ServiceItem> allItems;
  final String itemLabel;
  final ValueChanged<String> onSelectCategory;

  const _CategoryListView({
    required this.categories,
    required this.allItems,
    required this.itemLabel,
    required this.onSelectCategory,
  });

  int _countForCategory(String cat) =>
      allItems.where((s) => s.category?.trim() == cat).length;

  int get _uncategorizedCount =>
      allItems.where((s) => s.category == null || s.category!.trim().isEmpty).length;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        // All items shortcut
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.list_rounded, color: AppTheme.primary),
          title: Text('All ${itemLabel}s',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: _CountBadge(allItems.length),
          onTap: () => onSelectCategory(''),
        ),
        if (categories.isNotEmpty) const Divider(height: 1),
        // Named categories
        ...categories.map((cat) {
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.folder_outlined,
                    color: AppTheme.primary),
                title: Text(cat,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CountBadge(_countForCategory(cat)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 18, color: AppTheme.subtext(context)),
                  ],
                ),
                onTap: () => onSelectCategory(cat),
              ),
              const Divider(height: 1),
            ],
          );
        }),
        // Uncategorized (only if there are some)
        if (_uncategorizedCount > 0) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.help_outline,
                color: AppTheme.subtext(context)),
            title: Text('Uncategorized',
                style: TextStyle(color: AppTheme.subtext(context))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CountBadge(_uncategorizedCount),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 18, color: AppTheme.subtext(context)),
              ],
            ),
            onTap: () => onSelectCategory('__uncategorized__'),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _ItemListView extends StatelessWidget {
  final List<ServiceItem> items;
  final String symbol;
  final ValueChanged<ServiceItem> onPick;

  const _ItemListView({
    required this.items,
    required this.symbol,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No items found',
              style: TextStyle(color: AppTheme.subtext(context))),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final s = items[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(s.name,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: _subtitle(ctx, s),
          onTap: () => onPick(s),
          trailing: Icon(Icons.chevron_right,
              size: 18, color: AppTheme.subtext(ctx)),
        );
      },
    );
  }

  Widget? _subtitle(BuildContext context, ServiceItem s) {
    final parts = <String>[
      if (s.category != null && s.category!.isNotEmpty) s.category!,
      if (s.description != null && s.description!.isNotEmpty) s.description!,
      if (s.rate > 0) '$symbol${s.rate.toStringAsFixed(0)}',
      if (s.unit != null && s.unit!.isNotEmpty) s.unit!,
      if (s.taxPercent > 0) '${s.taxPercent.toStringAsFixed(0)}% tax',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: TextStyle(fontSize: 12, color: AppTheme.subtext(context)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary),
      ),
    );
  }
}

Future<double?> _showQtyPickerDialog(BuildContext context, String itemName) {
  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _QtyPickerDialog(itemName: itemName),
  );
}

class _QtyPickerDialog extends StatefulWidget {
  final String itemName;
  const _QtyPickerDialog({required this.itemName});

  @override
  State<_QtyPickerDialog> createState() => _QtyPickerDialogState();
}

class _QtyPickerDialogState extends State<_QtyPickerDialog> {
  // null means the user is typing a custom value
  int? _selected = 1;
  final _customCtrl = TextEditingController();
  final _customFocus = FocusNode();

  static const _numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  @override
  void dispose() {
    _customCtrl.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  double? get _resolvedQty {
    if (_selected != null) return _selected!.toDouble();
    final v = double.tryParse(_customCtrl.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary;
    return AlertDialog(
      title: const Text('Select Quantity'),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.itemName,
            style: TextStyle(fontSize: 13, color: AppTheme.subtext(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          // Wrap avoids scroll-viewport intrinsic-dimension crash inside AlertDialog
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _numbers.map((n) {
              final isSelected = _selected == n;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selected = n;
                    _customCtrl.clear();
                  });
                  _customFocus.unfocus();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? primary : primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customCtrl,
            focusNode: _customFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Custom quantity',
              hintText: 'e.g. 15 or 2.5',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
            onChanged: (v) {
              // Deselect grid tiles as soon as the user starts typing
              if (v.isNotEmpty && _selected != null) {
                setState(() => _selected = null);
              } else if (v.isEmpty && _selected == null) {
                setState(() => _selected = 1);
              }
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final qty = _resolvedQty;
            if (qty == null) return; // invalid custom input — keep dialog open
            Navigator.pop(context, qty);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
