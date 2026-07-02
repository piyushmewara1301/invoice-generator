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

class ImportInventoryScreen extends StatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  State<ImportInventoryScreen> createState() => _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends State<ImportInventoryScreen> {
  InventoryImportPreview? _preview;
  String? _csvContent;
  String? _fileName;
  bool _picking = false;
  bool _downloading = false;
  bool _importing = false;
  String? _pickError;

  Future<void> _downloadTemplate() async {
    setState(() => _downloading = true);
    try {
      final csv = buildInventoryTemplate();
      const name = 'billbook_inventory_template.csv';
      const text =
          'Fill in your products/services and import them into BillBook.\n'
          '• Flat items: fill columns A–K, leave Variant Name and Variant Rate empty.\n'
          '• Variant items: repeat the same Name for each variant row.\n'
          '• Track Stock: type yes or no.\n'
          '• Opening Stock and Low Stock Alert are only used when Track Stock = yes.';
      if (kIsWeb) {
        final bytes = Uint8List.fromList(utf8.encode(csv));
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: name, mimeType: 'text/csv')],
          subject: 'BillBook Inventory Template',
          text: text,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsString(csv);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject: 'BillBook Inventory Template',
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
      _csvContent = null;
      _fileName = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'CSV', 'txt', 'TXT'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = result.files.first;

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
      final existingItems = await provider.db.itemsDao.allForImportMatch();
      final preview = parseInventoryCsv(
        content,
        existingItems: existingItems,
        shopId: await provider.getOrCreateShopId(),
      );
      setState(() {
        _fileName = file.name;
        _csvContent = content;
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
    final csv = _csvContent;
    if (csv == null) return;
    setState(() => _importing = true);
    final result = await context.read<AppProvider>().bulkImportInventory(csv);
    if (!mounted) return;
    setState(() => _importing = false);

    final newCount = result.newCount;
    final updateCount = result.updateCount;
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
            if (newCount > 0)
              Text(
                '$newCount new item${newCount == 1 ? '' : 's'} added.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
            if (updateCount > 0)
              Text(
                '$updateCount item${updateCount == 1 ? '' : 's'} updated.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Import Inventory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step 1 — template
          _StepCard(
            step: '1',
            title: 'Download the template',
            subtitle:
                'Fill in your products and services. One row per flat item, '
                'or repeat the same Name for each size/variant.',
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
                label: Text(
                    _downloading ? 'Preparing…' : 'Download CSV Template'),
              ),
            ),
          ),

          const SizedBox(height: 4),
          _columnGuide(context),
          const SizedBox(height: 16),

          // Step 2 — pick file
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

          // Step 3 — preview + confirm
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _StepCard(
              step: '3',
              title: 'Review & confirm',
              subtitle: _previewSubtitle(_preview!),
              child: _PreviewTable(preview: _preview!),
            ),
            const SizedBox(height: 16),
            if (_preview!.totalCount > 0)
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
                      : 'Import ${_preview!.totalCount} Item${_preview!.totalCount == 1 ? '' : 's'}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (_preview!.hasErrors && _preview!.totalCount == 0) ...[
              const SizedBox(height: 8),
              const Text(
                'Fix all errors in the CSV before importing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.error),
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _previewSubtitle(InventoryImportPreview p) {
    if (p.rows.isEmpty) return 'The file appears to be empty.';
    final parts = <String>[];
    if (p.newCount > 0) {
      parts.add('${p.newCount} new item${p.newCount == 1 ? '' : 's'}');
    }
    if (p.updateCount > 0) {
      parts.add('${p.updateCount} update${p.updateCount == 1 ? '' : 's'}');
    }
    if (p.errorCount > 0) {
      parts.add('${p.errorCount} error${p.errorCount == 1 ? '' : 's'}');
    }
    return parts.join(' · ');
  }

  Widget _columnGuide(BuildContext context) {
    const cols = [
      ('Name', 'Required. For variant items, repeat this for each variant row.'),
      ('Category', 'Optional. Groups items in your catalog.'),
      ('Rate', 'Required for flat items. Can be blank for variant-only items.'),
      ('Tax%', 'Optional. e.g. 18 for 18% GST.'),
      ('Track Stock (yes/no)', 'Whether to track inventory levels.'),
      ('Opening Stock', 'Starting quantity — only used when Track Stock = yes.'),
      ('Low Stock Alert', 'Alert threshold — only used when Track Stock = yes.'),
      ('Variant Name', 'For variant items: the size/colour/type label (e.g. "500ml").'),
      ('Variant Rate', 'Rate for this specific variant.'),
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
                    Icon(Icons.circle,
                        size: 5, color: AppTheme.subtext(context)),
                    const SizedBox(width: 8),
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

// ── Shared step card widget ───────────────────────────────────────────────────

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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primary,
                  child: Text(step,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Preview table ─────────────────────────────────────────────────────────────

class _PreviewTable extends StatelessWidget {
  final InventoryImportPreview preview;

  const _PreviewTable({required this.preview});

  @override
  Widget build(BuildContext context) {
    if (preview.rows.isEmpty) {
      return const Text('No data rows found.',
          style: TextStyle(fontSize: 13));
    }
    return Column(
      children: preview.rows.map((row) {
        final isError = !row.isValid;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isError
                ? AppTheme.error.withValues(alpha: 0.08)
                : AppTheme.success.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isError
                  ? AppTheme.error.withValues(alpha: 0.3)
                  : AppTheme.success.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 16,
                color: isError ? AppTheme.error : AppTheme.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.isVariantRow
                          ? '${row.name}  ›  ${row.variantName}'
                          : row.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onCard(context),
                      ),
                    ),
                    if (isError)
                      Text(
                        row.errorMessage ?? 'Invalid row',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.error),
                      ),
                  ],
                ),
              ),
              Text('Row ${row.rowNumber}',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.subtext(context))),
            ],
          ),
        );
      }).toList(),
    );
  }
}
