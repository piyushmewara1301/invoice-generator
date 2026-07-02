import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/csv_importer.dart';
import '../utils/formatters.dart';

class ImportInvoicesScreen extends StatefulWidget {
  const ImportInvoicesScreen({super.key});

  @override
  State<ImportInvoicesScreen> createState() => _ImportInvoicesScreenState();
}

class _ImportInvoicesScreenState extends State<ImportInvoicesScreen> {
  CsvImportPreview? _preview;
  String? _fileName;
  bool _picking = false;
  bool _downloading = false;
  bool _importing = false;
  String? _pickError;

  Future<void> _downloadTemplate() async {
    setState(() => _downloading = true);
    try {
      final csv = buildTemplate();
      const name = 'billbook_import_template.csv';
      const text = 'Fill in your old invoices and import them into BillBook.\n'
          '• One row per line item — repeat the Invoice No for multi-item invoices.\n'
          '• Date format: DD/MM/YYYY\n'
          '• Status: Draft / Sent / Paid';
      if (kIsWeb) {
        final bytes = Uint8List.fromList(utf8.encode(csv));
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: name, mimeType: 'text/csv')],
          subject: 'BillBook Import Template',
          text: text,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsString(csv);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject: 'BillBook Import Template',
          text: text,
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
        allowedExtensions: ['csv', 'CSV', 'txt', 'TXT'],
        allowMultiple: false,
        withData: true, // required for web
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = result.files.first;

      // Decode file content: bytes path works on both web and mobile.
      final String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (!kIsWeb && file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        setState(() {
          _picking = false;
          _pickError = 'Could not read the file contents.';
        });
        return;
      }

      if (!mounted) return;
      final provider = context.read<AppProvider>();
      final existingNos =
          provider.invoices.map((i) => i.invoiceNumber).toSet();
      final existingClients = provider.clients.toList();
      final preview = parseCsv(
        content,
        existingInvoiceNumbers: existingNos,
        existingClients: existingClients,
      );
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

  Future<void> _confirmImport() async {
    final preview = _preview;
    if (preview == null || preview.invoices.isEmpty) return;
    setState(() => _importing = true);
    await context.read<AppProvider>().bulkImportInvoices(preview.invoices);
    if (!mounted) return;
    setState(() => _importing = false);

    // Show result and pop back.
    final count = preview.invoices.length;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppTheme.success, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              '$count invoice${count == 1 ? '' : 's'} imported successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // back to invoice list
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Invoices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step 1 – template
          _StepCard(
            step: '1',
            title: 'Download the template',
            subtitle:
                'Fill in your old invoices. Each row is one line item — '
                'repeat the Invoice No for invoices with multiple items.',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : _downloadTemplate,
                icon: _downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined),
                label: Text(_downloading
                    ? 'Preparing…'
                    : 'Download CSV Template'),
              ),
            ),
          ),

          const SizedBox(height: 4),
          _columnGuide(),
          const SizedBox(height: 16),

          // Step 2 – pick file
          _StepCard(
            step: '2',
            title: 'Upload your filled CSV',
            subtitle: 'Tap below to pick the CSV file you filled in.',
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
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(_picking
                      ? 'Reading file…'
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

          // Step 3 – preview + confirm (shown only after a file is picked)
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _StepCard(
              step: '3',
              title: 'Review & confirm',
              subtitle: _previewSubtitle(_preview!),
              child: _PreviewTable(preview: _preview!),
            ),
            const SizedBox(height: 16),
            if (_preview!.invoiceCount > 0)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _importing ? null : _confirmImport,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_importing
                      ? 'Importing…'
                      : 'Import ${_preview!.invoiceCount} Invoice${_preview!.invoiceCount == 1 ? '' : 's'}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (_preview!.hasErrors && _preview!.invoiceCount == 0) ...[
              const SizedBox(height: 8),
              const Text(
                'Fix all errors in the CSV before importing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.error),
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _previewSubtitle(CsvImportPreview p) {
    if (p.rows.isEmpty) return 'The file appears to be empty.';
    final parts = <String>[];
    if (p.invoiceCount > 0) {
      parts.add('${p.invoiceCount} invoice${p.invoiceCount == 1 ? '' : 's'} ready');
    }
    if (p.errorCount > 0) {
      parts.add('${p.errorCount} row${p.errorCount == 1 ? '' : 's'} with errors');
    }
    return parts.join(' · ');
  }

  Widget _columnGuide() {
    const cols = [
      ('Invoice No', 'Required. Repeat the same number for multi-item invoices.'),
      ('Invoice Date', 'Required. Format: DD/MM/YYYY'),
      ('Due Date', 'Optional. Defaults to Invoice Date + 30 days.'),
      ('Status', 'Optional. Draft / Sent / Paid. Defaults to Draft.'),
      ('Client Name', 'Required.'),
      ('Item Description', 'Required.'),
      ('Item Qty / Rate', 'Required. Numbers only.'),
      ('Item Tax % / Discount %', 'Optional. Numbers only, e.g. 18 for 18%.'),
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Column guide',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.subtext(context))),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: cols
          .map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 5,
                        color: AppTheme.subtext(context)),
                    SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.onCard(context)),
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

// ── Step card ─────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(12),
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
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
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
          SizedBox(height: 6),
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

// ── Preview table ─────────────────────────────────────────────────────────────

class _PreviewTable extends StatelessWidget {
  final CsvImportPreview preview;
  const _PreviewTable({required this.preview});

  @override
  Widget build(BuildContext context) {
    if (preview.rows.isEmpty) {
      return Text('No data rows found.',
          style: TextStyle(color: AppTheme.subtext(context), fontSize: 13));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(36),  // row#
          1: FlexColumnWidth(2),    // invoice no
          2: FlexColumnWidth(3),    // client
          3: FlexColumnWidth(2),    // total / error
        },
        border: TableBorder.all(
          color: AppTheme.outline(context),
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: AppTheme.isDark(context) ? AppTheme.darkDivider : const Color(0xFFF1F5F9)),
            children: [
              _th(context, '#'),
              _th(context, 'Invoice No'),
              _th(context, 'Client / Error'),
              _th(context, 'Total'),
            ],
          ),
          // Data rows
          ...preview.rows.map((row) {
            final isError = !row.isValid;
            final bg = isError ? AppTheme.error.withValues(alpha: 0.06) : Colors.transparent;
            return TableRow(
              decoration: BoxDecoration(color: bg),
              children: [
                _td('${row.rowNumber}',
                    color: AppTheme.subtext(context), small: true),
                _td(row.invoiceNo,
                    color: isError ? AppTheme.error : AppTheme.textPrimary,
                    bold: !isError),
                _td(
                  isError
                      ? row.errorMessage ?? 'Error'
                      : (row.clientName ?? '—'),
                  color: isError ? AppTheme.error : AppTheme.textSecondary,
                  small: isError,
                ),
                _td(
                  row.total != null
                      ? Fmt.currency(row.total!)
                      : (isError ? '—' : ''),
                  color: AppTheme.onCard(context),
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

  Widget _td(String text, {Color? color, bool bold = false, bool small = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: small ? 11 : 12,
            color: color ?? AppTheme.textPrimary,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      );
}
