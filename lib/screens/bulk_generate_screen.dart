import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/csv_importer.dart';
import '../utils/formatters.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BulkGenerateScreen
// ─────────────────────────────────────────────────────────────────────────────
// Three-step flow:
//   1. Download the 7-column template (or skip if user has their own CSV)
//   2. Upload the filled CSV
//   3. Configure batch options + preview rows → Generate
// ─────────────────────────────────────────────────────────────────────────────

class BulkGenerateScreen extends StatefulWidget {
  const BulkGenerateScreen({super.key});

  @override
  State<BulkGenerateScreen> createState() => _BulkGenerateScreenState();
}

class _BulkGenerateScreenState extends State<BulkGenerateScreen> {
  // ── File / parse state ────────────────────────────────────────────────────
  BulkGeneratePreview? _preview;
  String? _fileName;
  bool _downloading = false;
  bool _picking = false;
  bool _generating = false;
  String? _pickError;

  // ── Batch options ─────────────────────────────────────────────────────────
  DateTime _invoiceDate = DateTime.now();
  int _dueDays = 30;
  InvoiceStatus _status = InvoiceStatus.draft;

  // ── Done state ────────────────────────────────────────────────────────────
  int? _generatedCount; // non-null → done view

  // ── Template download ─────────────────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    setState(() => _downloading = true);
    try {
      final csv = buildBulkTemplate();
      final bytes = Uint8List.fromList(utf8.encode(csv));
      if (kIsWeb) {
        await Share.shareXFiles(
          [
            XFile.fromData(bytes,
                name: 'billbook_bulk_template.csv', mimeType: 'text/csv'),
          ],
          subject: 'BillBook Bulk Invoice Template',
          text: 'One row = one new invoice. '
              'Invoice numbers are auto-assigned. '
              'Amount = unit price (qty is always 1).',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/billbook_bulk_template.csv');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject: 'BillBook Bulk Invoice Template',
          text: 'One row = one new invoice. '
              'Invoice numbers are auto-assigned. '
              'Amount = unit price (qty is always 1).',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share template: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ── File pick & parse ─────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() {
      _picking = true;
      _pickError = null;
      _preview = null;
      _fileName = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'CSV', 'TXT'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = result.files.single;

      final String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (!kIsWeb && file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        setState(() {
          _picking = false;
          _pickError = 'Could not read file contents.';
        });
        return;
      }

      final preview = parseBulkCsv(content);
      setState(() {
        _fileName = file.name;
        _preview = preview;
        _picking = false;
      });
    } catch (e) {
      setState(() {
        _picking = false;
        _pickError = 'Failed to read file: $e';
      });
    }
  }

  // ── Generate ──────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final preview = _preview;
    if (preview == null || preview.validSpecs.isEmpty) return;

    setState(() => _generating = true);
    try {
      final dueDate = _invoiceDate.add(Duration(days: _dueDays));
      await context.read<AppProvider>().bulkGenerateInvoices(
            specs: preview.validSpecs,
            invoiceDate: _invoiceDate,
            dueDate: dueDate,
            status: _status,
          );
      if (mounted) {
        setState(() {
          _generatedCount = preview.validSpecs.length;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  void _reset() => setState(() {
        _preview = null;
        _fileName = null;
        _pickError = null;
        _generatedCount = null;
        _invoiceDate = DateTime.now();
        _dueDays = 30;
        _status = InvoiceStatus.draft;
      });

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_generatedCount != null) return _DoneView(count: _generatedCount!, onReset: _reset);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Bulk Invoice Generator'),
        elevation: 0,
        backgroundColor: AppTheme.card(context),
        foregroundColor: AppTheme.onCard(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header blurb ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create hundreds of invoices at once — school fees, '
                    'monthly retainers, utility billing. '
                    'Invoice numbers are auto-assigned.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Step 1: template ──────────────────────────────────────────────
          _StepCard(
            step: '1',
            title: 'Download the template',
            subtitle:
                'Fill in one client per row. '
                'Invoice numbers are assigned automatically — '
                'do not add them to the CSV.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _downloading ? null : _downloadTemplate,
                  icon: _downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined, size: 18),
                  label: Text(_downloading
                      ? 'Preparing…'
                      : 'Download CSV Template'),
                ),
                const SizedBox(height: 12),
                _ColumnGuide(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Step 2: upload ────────────────────────────────────────────────
          _StepCard(
            step: '2',
            title: 'Upload your filled CSV',
            subtitle: 'Select the CSV you filled in.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _picking ? null : _pickFile,
                  icon: _picking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(_picking
                      ? 'Reading…'
                      : _fileName != null
                          ? _fileName!
                          : 'Choose CSV File'),
                ),
                if (_pickError != null) ...[
                  const SizedBox(height: 8),
                  Text(_pickError!,
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 12)),
                ],
              ],
            ),
          ),

          // ── Step 3: configure + preview (after upload) ────────────────────
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _StepCard(
              step: '3',
              title: 'Configure & generate',
              subtitle: _previewSubtitle(_preview!),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invoice date
                  _OptionLabel('Invoice Date'),
                  const SizedBox(height: 6),
                  _DatePickerRow(
                    date: _invoiceDate,
                    onChanged: (d) => setState(() => _invoiceDate = d),
                  ),
                  const SizedBox(height: 16),

                  // Due in X days
                  _OptionLabel('Payment due after'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [7, 14, 30, 45, 60].map((d) {
                      final sel = d == _dueDays;
                      return _Pill(
                        label: '$d days',
                        selected: sel,
                        onTap: () => setState(() => _dueDays = d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  _OptionLabel('Invoice Status'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _Pill(
                        label: 'Draft',
                        selected: _status == InvoiceStatus.draft,
                        onTap: () =>
                            setState(() => _status = InvoiceStatus.draft),
                      ),
                      _Pill(
                        label: 'Sent',
                        selected: _status == InvoiceStatus.sent,
                        onTap: () =>
                            setState(() => _status = InvoiceStatus.sent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Preview table
                  _BulkPreviewTable(preview: _preview!),
                  const SizedBox(height: 16),

                  // Generate button
                  if (_preview!.validCount > 0)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          _generating
                              ? 'Generating…'
                              : 'Generate ${_preview!.validCount} '
                                  'Invoice${_preview!.validCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (_preview!.hasErrors && _preview!.validCount == 0)
                    Text(
                      'Fix all errors in the CSV before generating.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.error),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _previewSubtitle(BulkGeneratePreview p) {
    if (p.rows.isEmpty) return 'The file appears to be empty.';
    final parts = <String>[];
    if (p.validCount > 0) {
      parts.add('${p.validCount} invoice${p.validCount == 1 ? '' : 's'} ready');
    }
    if (p.errorCount > 0) {
      parts.add('${p.errorCount} row${p.errorCount == 1 ? '' : 's'} with errors');
    }
    return parts.join(' · ');
  }
}

// ── Done view ─────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  final int count;
  final VoidCallback onReset;
  const _DoneView({required this.count, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  size: 36, color: AppTheme.success),
            ),
            const SizedBox(height: 20),
            Text(
              '$count invoice${count == 1 ? '' : 's'} created',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onCard(context),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invoice numbers have been assigned and\nall invoices are saved to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.subtext(context),
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onReset,
              icon:
                  const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('Generate another batch'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step card (reusable shell) ────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: AppTheme.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(step,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.subtext(context))),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Column guide ──────────────────────────────────────────────────────────────

class _ColumnGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const cols = [
      ('Client Name', 'Required.'),
      ('Client Email', 'Optional. Used to match or create the client.'),
      ('Client Phone', 'Optional.'),
      ('Item Description', 'Required. The invoice line item text.'),
      ('Amount', 'Required. Unit price (qty is always 1).'),
      ('Tax %', 'Optional. e.g. 18 for 18% GST. Defaults to 0.'),
      ('Notes', 'Optional. Shown at the bottom of the invoice.'),
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      dense: true,
      title: Text('Column guide',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.subtext(context))),
      childrenPadding: const EdgeInsets.only(bottom: 4),
      children: cols
          .map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle,
                        size: 5, color: AppTheme.subtext(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.onCard(context)),
                          children: [
                            TextSpan(
                                text: '${c.$1}: ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            TextSpan(text: c.$2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Option label ──────────────────────────────────────────────────────────────

class _OptionLabel extends StatelessWidget {
  final String text;
  const _OptionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.subtext(context)));
  }
}

// ── Pill selector ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.outline(context),
              width: selected ? 2 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppTheme.primary
                    : AppTheme.subtext(context))),
      ),
    );
  }
}

// ── Date picker row ───────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _DatePickerRow({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: AppTheme.subtext(context)),
            const SizedBox(width: 8),
            Text(Fmt.date(date),
                style: TextStyle(
                    fontSize: 14, color: AppTheme.onCard(context))),
          ],
        ),
      ),
    );
  }
}

// ── Preview table ─────────────────────────────────────────────────────────────

class _BulkPreviewTable extends StatelessWidget {
  final BulkGeneratePreview preview;
  const _BulkPreviewTable({required this.preview});

  @override
  Widget build(BuildContext context) {
    if (preview.rows.isEmpty) {
      return Text('No data rows found.',
          style: TextStyle(
              color: AppTheme.subtext(context), fontSize: 13));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(32),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(3),
          3: FlexColumnWidth(2),
          4: FixedColumnWidth(64),
        },
        border: TableBorder.all(
          color: AppTheme.outline(context),
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(
                color: AppTheme.isDark(context)
                    ? AppTheme.darkDivider
                    : const Color(0xFFF1F5F9)),
            children: [
              _th(context, '#'),
              _th(context, 'Client'),
              _th(context, 'Description'),
              _th(context, 'Amount'),
              _th(context, 'Status'),
            ],
          ),
          ...preview.rows.map((row) {
            final isError = !row.isValid;
            return TableRow(
              decoration: BoxDecoration(
                  color: isError
                      ? AppTheme.error.withValues(alpha: 0.06)
                      : Colors.transparent),
              children: [
                _td('${row.rowNumber}',
                    color: AppTheme.subtext(context), small: true),
                _td(
                  isError
                      ? row.errorMessage ?? 'Error'
                      : row.spec!.clientName,
                  color: isError ? AppTheme.error : AppTheme.textPrimary,
                  bold: !isError,
                  small: isError,
                ),
                _td(
                  isError ? '—' : row.spec!.itemDescription,
                  color: AppTheme.textSecondary,
                ),
                _td(
                  isError
                      ? '—'
                      : Fmt.currency(row.spec!.lineTotal),
                  color: isError
                      ? AppTheme.subtext(context)
                      : AppTheme.textPrimary,
                  bold: !isError,
                ),
                _td(
                  isError ? '✗' : '✓',
                  color: isError ? AppTheme.error : AppTheme.success,
                  bold: true,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _th(BuildContext ctx, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.subtext(ctx))),
      );

  Widget _td(String text,
          {Color? color, bool bold = false, bool small = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: small ? 11 : 12,
                color: color ?? AppTheme.textPrimary,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      );
}
