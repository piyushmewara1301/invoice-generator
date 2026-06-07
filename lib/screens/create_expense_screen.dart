import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/ocr_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/ocr_result_sheet.dart';

class CreateExpenseScreen extends StatefulWidget {
  final Expense? expense;
  const CreateExpenseScreen({super.key, this.expense});

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _category;
  late DateTime _date;
  bool _isRecurring = false;
  bool _saving = false;

  String? _receiptImageBase64;
  bool _ocrScanning = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _category = e?.category ?? expenseCategories.first;
    _date = e?.date ?? DateTime.now();
    _isRecurring = e?.isRecurring ?? false;
    _receiptImageBase64 = e?.receiptImageBase64;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _notesCtrl.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _receiptImageBase64 = base64Encode(bytes));
  }

  // Future<void> _scanReceipt() async {
  //   if (_receiptImageBase64 == null) return;
  //   setState(() => _ocrScanning = true);
  //   try {
  //     final text =
  //         await OcrService.extractTextFromBase64(_receiptImageBase64!);
  //     if (!mounted) return;
  //     if (text == null) {
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //           content:
  //               Text('Could not read text. Try a clearer, well-lit photo.')));
  //       return;
  //     }
  //     final result = OcrService.parseExpense(text);
  //     if (!result.hasData) {
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //           content: Text('No fields detected. Fill in the form manually.')));
  //       return;
  //     }
  //     _showOcrSheet(result);
  //   } finally {
  //     if (mounted) setState(() => _ocrScanning = false);
  //   }
  // }

  void _showOcrSheet(OcrExpenseResult result) {
    final fields = <OcrField>[
      if (result.amount != null)
        OcrField(
          key: 'amount',
          label: 'Amount',
          displayValue:
              '${Fmt.currencySymbol(context.read<AppProvider>().profile.currency)}'
              '${result.amount!.toStringAsFixed(2)}',
          rawValue: result.amount!,
        ),
      if (result.date != null)
        OcrField(
          key: 'date',
          label: 'Date',
          displayValue: Fmt.date(result.date!),
          rawValue: result.date!,
        ),
      if (result.vendorName != null)
        OcrField(
          key: 'vendor',
          label: 'Title',
          displayValue: result.vendorName!,
          rawValue: result.vendorName!,
        ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => OcrResultSheet(
        fields: fields,
        onApply: (selected) {
          setState(() {
            if (selected['amount'] case final double amt) {
              _amountCtrl.text = amt.toStringAsFixed(2);
            }
            if (selected['date'] case final DateTime d) {
              _date = d;
            }
            if (selected['vendor'] case final String name) {
              if (_titleCtrl.text.trim().isEmpty) _titleCtrl.text = name;
            }
          });
        },
      ),
    );
  }

  Future<void> _showCategoryPicker() async {
    final provider = context.read<AppProvider>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CategoryPickerSheet(
        selected: _category,
        customCategories: provider.customExpenseCategories,
        onSelected: (cat) {
          setState(() => _category = cat);
          Navigator.pop(ctx);
        },
        onAddNew: (name) =>
            context.read<AppProvider>().addExpenseCategory(name),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<AppProvider>();
    final currency = provider.profile.currency;

    try {
      if (_isEditing) {
        final updated = widget.expense!
          ..title = _titleCtrl.text.trim()
          ..category = _category
          ..amount = double.parse(_amountCtrl.text.replaceAll(',', ''))
          ..date = _date
          ..notes = _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim()
          ..isRecurring = _isRecurring
          ..currency = currency
          ..receiptImageBase64 = _receiptImageBase64;
        await provider.updateExpense(updated);
      } else {
        final expense = Expense(
          id: const Uuid().v4(),
          title: _titleCtrl.text.trim(),
          category: _category,
          amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
          date: _date,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          isRecurring: _isRecurring,
          currency: currency,
          receiptImageBase64: _receiptImageBase64,
        );
        await provider.addExpense(expense);
      }
      if (mounted) Navigator.pop(context);
    } on PermissionDeniedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency =
        context.watch<AppProvider>().profile.currency;
    final symbol = Fmt.currencySymbol(currency);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editExpense : l10n.addExpense),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                _isEditing ? l10n.update : l10n.save,
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Receipt attachment ──────────────────────────────────────
            _SectionLabel('Receipt / Attachment'),
            const SizedBox(height: 8),
            ReceiptCard(
              imageBase64: _receiptImageBase64,
              scanning: _ocrScanning,
              onCamera: () => _pickReceipt(ImageSource.camera),
              onGallery: () => _pickReceipt(ImageSource.gallery),
              // onScan: _ocrScanning ? null : _scanReceipt,
              onRemove: () => setState(() => _receiptImageBase64 = null),
            ),
            const SizedBox(height: 20),

            // ── Category picker ─────────────────────────────────────────
            _SectionLabel(l10n.category),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showCategoryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.outline(context), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: expenseCategoryColor(_category)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        expenseCategoryIcon(_category),
                        color: expenseCategoryColor(_category),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _category,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onCard(context)),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.subtext(context)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ───────────────────────────────────────────────────
            _SectionLabel('Title'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. March Electricity Bill',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            // ── Amount ──────────────────────────────────────────────────
            _SectionLabel('Amount'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '$symbol ',
                prefixStyle: TextStyle(
                    color: AppTheme.onCard(context),
                    fontWeight: FontWeight.w600),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Date ────────────────────────────────────────────────────
            _SectionLabel('Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.outline(context), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      Fmt.date(_date),
                      style: TextStyle(
                          fontSize: 15, color: AppTheme.onCard(context)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Recurring toggle ────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outline(context), width: 1.5),
              ),
              child: SwitchListTile(
                title: Text(l10n.recurring,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                subtitle: const Text(
                    'Mark this as a monthly repeating expense',
                    style: TextStyle(fontSize: 12)),
                value: _isRecurring,
                activeThumbColor: AppTheme.primary,
                onChanged: (v) => setState(() => _isRecurring = v),
              ),
            ),
            const SizedBox(height: 20),

            // ── Notes ───────────────────────────────────────────────────
            _SectionLabel('${l10n.notes} (${l10n.optional})'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Any additional details…',
              ),
            ),
            const SizedBox(height: 32),

            // ── Save button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isEditing ? l10n.editExpense : l10n.addExpense,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Category picker bottom sheet ──────────────────────────────────────────────

class _CategoryPickerSheet extends StatefulWidget {
  final String selected;
  final List<String> customCategories;
  final ValueChanged<String> onSelected;
  final Future<void> Function(String) onAddNew;

  const _CategoryPickerSheet({
    required this.selected,
    required this.customCategories,
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late List<String> _all;

  @override
  void initState() {
    super.initState();
    _all = [...expenseCategories, ...widget.customCategories];
  }

  Future<void> _promptNewCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddCategoryDialog(),
    );
    if (name == null || name.isEmpty) return;

    // Optimistic UI — add to local list immediately
    final alreadyExists =
        _all.any((c) => c.toLowerCase() == name.toLowerCase());
    if (!alreadyExists) setState(() => _all.add(name));

    // Persist to provider (fire-and-forget from sheet's perspective)
    await widget.onAddNew(name);

    // Select the new category and close the sheet
    widget.onSelected(name);
  }

  @override
  Widget build(BuildContext context) {
    // +1 for the "New Category" tile at the end
    final itemCount = _all.length + 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.category,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context)),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: itemCount,
              itemBuilder: (_, i) {
                // Last tile → "New Category" button
                if (i == _all.length) return _NewCategoryTile(onTap: _promptNewCategory);

                final cat = _all[i];
                final isSelected = cat == widget.selected;
                final color = expenseCategoryColor(cat);
                return GestureDetector(
                  onTap: () => widget.onSelected(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.12)
                          : AppTheme.card(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : AppTheme.outline(context),
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          expenseCategoryIcon(cat),
                          color: isSelected ? color : AppTheme.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? color
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add-category dialog ───────────────────────────────────────────────────────

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addCategory),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. Equipment, Marketing…',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ── "New Category" tile ───────────────────────────────────────────────────────

class _NewCategoryTile extends StatelessWidget {
  final VoidCallback onTap;
  const _NewCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(
        builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.4),
            width: 1.5,
            // Dashed via a custom painter would be ideal, but a solid
            // lighter-weight border reads clearly as "action" vs selection.
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add,
                  color: AppTheme.primary, size: 18),
            ),
            const SizedBox(height: 6),
            const Text(
              'New',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Small label widget ────────────────────────────────────────────────────────

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
          letterSpacing: 0.3,
        ),
      );
}
