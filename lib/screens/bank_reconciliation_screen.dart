import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/partial_payment.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain model
// ─────────────────────────────────────────────────────────────────────────────

enum _TxnStatus { unmatched, matched, ignored }

class _Txn {
  final String id;
  final DateTime date;
  final double amount; // positive = credit / inflow
  final String description;
  final String? reference;
  _TxnStatus status = _TxnStatus.unmatched;
  String? matchedInvoiceId;
  List<Invoice> suggestions = []; // ranked candidates from auto-matcher

  _Txn({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    this.reference,
  });

  bool get isCredit => amount > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// CSV parser — handles most Indian bank statement exports
// ─────────────────────────────────────────────────────────────────────────────

class _CsvParser {
  static List<_Txn> parse(String raw) {
    // Strip UTF-8 BOM
    if (raw.startsWith('﻿')) raw = raw.substring(1);
    raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Detect delimiter from first non-empty line
    final firstLine =
        raw.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    String delim = ',';
    final semi = ';'.allMatches(firstLine).length;
    final tab = '\t'.allMatches(firstLine).length;
    final comma = ','.allMatches(firstLine).length;
    if (semi > comma) delim = ';';
    if (tab > semi && tab > comma) delim = '\t';

    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(raw, fieldDelimiter: delim);

    if (rows.isEmpty) return [];

    // Find header row in first 6 rows
    int hdrIdx = 0;
    List<String> hdrs = [];
    for (int i = 0; i < rows.length.clamp(0, 6); i++) {
      final row = rows[i].map((c) => c.toString().toLowerCase().trim()).toList();
      if (row.any((c) => c.contains('date')) ||
          row.any((c) =>
              ['credit', 'debit', 'cr', 'dr', 'amount', 'amt'].contains(c))) {
        hdrIdx = i;
        hdrs = row;
        break;
      }
    }
    if (hdrs.isEmpty && rows.isNotEmpty) {
      hdrs = rows[0].map((c) => c.toString().toLowerCase().trim()).toList();
    }

    // Column index finder — returns first matching header index
    int col(List<String> keys) {
      for (final k in keys) {
        final idx = hdrs.indexWhere((h) => h.contains(k));
        if (idx >= 0) return idx;
      }
      return -1;
    }

    final dateCol =
        col(['date', 'txn date', 'tran date', 'transaction date', 'value date', 'posting date']);
    final crCol = col(['credit amount', 'credit(inr)', 'credit (inr)', 'credit', 'deposit']);
    final drCol = col(['debit amount', 'debit(inr)', 'debit (inr)', 'debit', 'withdrawal']);
    final amtCol = col(['amount', 'amt']);
    final descCol =
        col(['narration', 'description', 'particulars', 'remarks', 'transaction details', 'details']);
    final refCol = col([
      'chq/ref no', 'ref no./cheque no.', 'ref no.', 'cheque no', 'chq no',
      'reference no', 'utr', 'transaction id', 'txn id', 'ref'
    ]);

    final txns = <_Txn>[];
    int counter = 0;

    for (int i = hdrIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      String cell(int idx) =>
          idx >= 0 && idx < row.length ? row[idx].toString().trim() : '';

      final date = _parseDate(cell(dateCol));
      if (date == null) continue;

      double amount = 0;
      if (crCol >= 0 && drCol >= 0) {
        final cr = _parseAmt(cell(crCol)) ?? 0;
        final dr = _parseAmt(cell(drCol)) ?? 0;
        amount = cr > 0 ? cr : (dr > 0 ? -dr : 0);
      } else if (amtCol >= 0) {
        amount = _parseAmt(cell(amtCol)) ?? 0;
      }
      if (amount == 0) continue;

      // Description: prefer detected column, fallback to longest text field
      String desc = cell(descCol);
      if (desc.isEmpty) {
        desc = row
            .map((c) => c.toString().trim())
            .where((s) => s.length > 4 && double.tryParse(s.replaceAll(',', '')) == null)
            .fold('', (best, s) => s.length > best.length ? s : best);
      }

      final ref = cell(refCol).isEmpty ? null : cell(refCol);

      txns.add(_Txn(
        id: '${++counter}',
        date: date,
        amount: amount,
        description: desc,
        reference: ref,
      ));
    }

    return txns;
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    final sep =
        raw.contains('/') ? '/' : raw.contains('-') ? '-' : raw.contains(' ') ? ' ' : null;
    if (sep == null) return null;
    final parts = raw.split(sep).map((p) => p.trim()).toList();
    if (parts.length != 3) return null;

    // Try numeric: DD/MM/YYYY or YYYY/MM/DD
    final nums = parts.map((p) => int.tryParse(p)).toList();
    if (nums[0] != null && nums[1] != null && nums[2] != null) {
      final a = nums[0]!, b = nums[1]!, c = nums[2]!;
      if (a > 1900) return _safe(a, b, c); // YYYY-MM-DD
      final year = c > 2000 ? c : (c < 100 ? 2000 + c : c);
      return _safe(year, b, a); // DD-MM-YYYY
    }

    // Try DD MMM YYYY (e.g. "15 Jan 2024")
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    int? day, month, year;
    for (final p in parts) {
      final pn = int.tryParse(p);
      final key = p.toLowerCase().length >= 3 ? p.toLowerCase().substring(0, 3) : '';
      if (pn != null && pn <= 31 && pn > 0 && day == null) {
        day = pn;
      } else if (pn != null && pn > 31 && year == null) {
        year = pn < 100 ? 2000 + pn : pn;
      } else if (months.containsKey(key) && month == null) {
        month = months[key];
      }
    }
    if (day != null && month != null && year != null) return _safe(year, month, day);
    return null;
  }

  static DateTime? _safe(int y, int m, int d) {
    if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static double? _parseAmt(String raw) {
    if (raw.trim().isEmpty) return null;
    String s = raw
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .replaceAll('INR', '')
        .replaceAll(' ', '') // non-breaking space
        .trim();
    bool neg = false;
    if (s.toLowerCase().endsWith('dr')) {
      neg = true;
      s = s.substring(0, s.length - 2).trim();
    } else if (s.toLowerCase().endsWith('cr')) {
      s = s.substring(0, s.length - 2).trim();
    }
    if (s.startsWith('-')) {
      neg = true;
      s = s.substring(1);
    }
    if (s.startsWith('(') && s.endsWith(')')) {
      neg = true;
      s = s.substring(1, s.length - 1);
    }
    final v = double.tryParse(s);
    return v == null ? null : (neg ? -v : v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-matcher
// ─────────────────────────────────────────────────────────────────────────────

class _Matcher {
  /// Returns a ranked list of invoice candidates for a credit transaction.
  static List<Invoice> rank(_Txn txn, List<Invoice> invoices) {
    if (!txn.isCredit) return [];

    final scored = <MapEntry<Invoice, double>>[];
    for (final inv in invoices) {
      final remaining = inv.amountRemaining;
      if (remaining <= 0.01) continue;

      double score = 0;

      // Amount similarity (most important signal)
      final ratio = (remaining - txn.amount).abs() / remaining;
      if (ratio < 0.001) {
        score += 60;
      } else if (ratio < 0.02) {
        score += 40;
      } else if (ratio < 0.10) {
        score += 15;
      } else if (ratio < 0.25) {
        score += 5;
      }

      // Date proximity vs invoice date and due date
      final daysDiff = [
        txn.date.difference(inv.invoiceDate).inDays.abs(),
        txn.date.difference(inv.dueDate).inDays.abs(),
      ].reduce((a, b) => a < b ? a : b);
      if (daysDiff <= 3) {
        score += 20;
      } else if (daysDiff <= 14) {
        score += 10;
      } else if (daysDiff <= 45) {
        score += 3;
      }

      // Client name in description or reference
      final clientName = inv.client?.name.toLowerCase() ?? '';
      final firstWord = clientName.split(' ').firstWhere(
          (w) => w.length > 3, orElse: () => '');
      final haystack =
          '${txn.description.toLowerCase()} ${(txn.reference ?? '').toLowerCase()}';
      if (firstWord.isNotEmpty && haystack.contains(firstWord)) score += 25;

      // Invoice number in description/reference
      final invNum =
          inv.invoiceNumber.toLowerCase().replaceAll(RegExp(r'[/\-]'), '');
      if (haystack.replaceAll(RegExp(r'[/\-]'), '').contains(invNum)) {
        score += 35;
      }

      if (score >= 10) scored.add(MapEntry(inv, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(6).map((e) => e.key).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class BankReconciliationScreen extends StatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  State<BankReconciliationScreen> createState() => _BankReconState();
}

class _BankReconState extends State<BankReconciliationScreen> {
  int _step = 0; // 0=upload  1=review  2=done
  List<_Txn> _txns = [];
  String _fileName = '';
  bool _loading = false;
  String? _parseError;
  int _appliedCount = 0;

  // Outstanding invoices for matching (refreshed from provider)
  List<Invoice> _outstanding(AppProvider p) => p.invoices
      .where((i) =>
          i.amountRemaining > 0.01 &&
          !i.isQuotation &&
          !i.isCreditNote &&
          !i.isDeliveryChallan)
      .toList();

  // ── File pick & parse ────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _parseError = null;
    });
    final provider = context.read<AppProvider>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'CSV', 'TXT'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
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
          _loading = false;
          _parseError = 'Could not read file contents.';
        });
        return;
      }

      final txns = _CsvParser.parse(content);
      if (txns.isEmpty) {
        setState(() {
          _loading = false;
          _parseError =
              'No transactions found. Check that the file is a bank statement CSV with Date and Amount columns.';
        });
        return;
      }

      // Auto-match
      final outstanding = _outstanding(provider);
      for (final txn in txns) {
        if (!txn.isCredit) {
          txn.status = _TxnStatus.ignored;
          continue;
        }
        txn.suggestions = _Matcher.rank(txn, outstanding);
        if (txn.suggestions.isNotEmpty) {
          final best = txn.suggestions.first;
          final ratio =
              (best.amountRemaining - txn.amount).abs() / best.amountRemaining;
          // Auto-accept when amount matches closely
          if (ratio < 0.01) {
            txn.status = _TxnStatus.matched;
            txn.matchedInvoiceId = best.id;
          }
        }
      }

      setState(() {
        _txns = txns;
        _fileName = file.name;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _parseError = 'Parse error: $e';
      });
    }
  }

  // ── Apply matched payments ───────────────────────────────────────────────

  Future<void> _applyMatches() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    int count = 0;

    for (final txn in _txns) {
      if (txn.status != _TxnStatus.matched || txn.matchedInvoiceId == null) continue;

      final inv = provider.invoices
          .where((i) => i.id == txn.matchedInvoiceId)
          .firstOrNull;
      if (inv == null) continue;

      final notes = [
        'Bank reconciliation: ${txn.description}',
        if (txn.reference != null) 'Ref: ${txn.reference}',
      ].join(' · ');

      inv.payments.add(PartialPayment(
        id: '${DateTime.now().millisecondsSinceEpoch}_$count',
        date: txn.date,
        amount: txn.amount,
        notes: notes,
      ));
      await provider.saveInvoice(inv);
      count++;
    }

    setState(() {
      _appliedCount = count;
      _loading = false;
      _step = 2;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: switch (_step) {
        0 => _UploadView(
            loading: _loading,
            error: _parseError,
            onPick: _pickFile,
          ),
        1 => _ReviewView(
            txns: _txns,
            fileName: _fileName,
            outstanding: _outstanding(context.watch<AppProvider>()),
            loading: _loading,
            onTxnsChanged: () => setState(() {}),
            onApply: _applyMatches,
          ),
        _ => _DoneView(
            count: _appliedCount,
            onReset: () => setState(() {
              _step = 0;
              _txns = [];
              _fileName = '';
              _appliedCount = 0;
            }),
          ),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 0 — Upload
// ─────────────────────────────────────────────────────────────────────────────

class _UploadView extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onPick;

  const _UploadView({
    required this.loading,
    required this.error,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_outlined,
                        color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Reconciliation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onCard(context),
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'Match bank credits to outstanding invoices',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.subtext(context)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Drop zone
              _DropZone(loading: loading, onPick: onPick),
              const SizedBox(height: 20),

              // Supported banks hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 15, color: AppTheme.subtext(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Supports HDFC, ICICI, SBI, Axis, Kotak and most CSV exports. '
                        'The file must have Date and Amount (or Credit/Debit) columns.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(context),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              if (error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(error!,
                            style: const TextStyle(
                                color: AppTheme.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DropZone extends StatefulWidget {
  final bool loading;
  final VoidCallback onPick;
  const _DropZone({required this.loading, required this.onPick});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 200,
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.primary.withValues(alpha: 0.04)
                : AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : AppTheme.divider,
              width: 1.5,
              // Dashed effect via strokeAlign isn't supported; solid border is fine
            ),
          ),
          child: widget.loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file_outlined,
                      size: 40,
                      color: _hovered
                          ? AppTheme.primary
                          : AppTheme.subtext(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Click to upload your bank statement',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _hovered
                            ? AppTheme.primary
                            : AppTheme.onCard(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CSV or TXT file',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.subtext(context)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Review
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewView extends StatelessWidget {
  final List<_Txn> txns;
  final String fileName;
  final List<Invoice> outstanding;
  final bool loading;
  final VoidCallback onTxnsChanged;
  final VoidCallback onApply;

  const _ReviewView({
    required this.txns,
    required this.fileName,
    required this.outstanding,
    required this.loading,
    required this.onTxnsChanged,
    required this.onApply,
  });

  int get _credits => txns.where((t) => t.isCredit).length;
  int get _matched => txns.where((t) => t.status == _TxnStatus.matched).length;
  int get _unmatched =>
      txns.where((t) => t.isCredit && t.status == _TxnStatus.unmatched).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar ─────────────────────────────────────────────────────
        Container(
          color: AppTheme.card(context),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Transactions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    fileName,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.subtext(context)),
                  ),
                ],
              ),
              const Spacer(),
              // Stats chips
              _StatChip('${txns.length} rows', const Color(0xFF475569)),
              const SizedBox(width: 8),
              _StatChip('$_credits credits', AppTheme.primary),
              const SizedBox(width: 8),
              _StatChip('$_matched matched', const Color(0xFF059669)),
              if (_unmatched > 0) ...[
                const SizedBox(width: 8),
                _StatChip('$_unmatched unmatched', const Color(0xFFD97706)),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Column headers ───────────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: const _TxnHeader(),
        ),
        const Divider(height: 1),

        // ── Transactions list ────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            itemCount: txns.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 24),
            itemBuilder: (ctx, i) {
              final txn = txns[i];
              return _TxnRow(
                txn: txn,
                outstanding: outstanding,
                onChanged: () => onTxnsChanged(),
              );
            },
          ),
        ),
        const Divider(height: 1),

        // ── Apply bar ────────────────────────────────────────────────────
        Container(
          color: AppTheme.card(context),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Text(
                '$_matched payment${_matched == 1 ? '' : 's'} will be recorded.',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.subtext(context)),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _matched > 0 && !loading ? onApply : null,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label:
                    Text('Apply $_matched match${_matched == 1 ? '' : 'es'}'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _TxnHeader extends StatelessWidget {
  const _TxnHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _hdr(context, 'Date', 90),
        const SizedBox(width: 12),
        Expanded(child: _hdr(context, 'Description')),
        const SizedBox(width: 12),
        _hdr(context, 'Amount', 110, TextAlign.right),
        const SizedBox(width: 12),
        _hdr(context, 'Status', 110),
        const SizedBox(width: 12),
        _hdr(context, 'Invoice', 200),
      ],
    );
  }

  Widget _hdr(BuildContext context, String label,
      [double? w, TextAlign align = TextAlign.left]) {
    final text = Text(
      label.toUpperCase(),
      textAlign: align,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.subtext(context),
          letterSpacing: 0.5),
    );
    return w == null ? text : SizedBox(width: w, child: text);
  }
}

// ─── Individual transaction row ───────────────────────────────────────────────

class _TxnRow extends StatelessWidget {
  final _Txn txn;
  final List<Invoice> outstanding;
  final VoidCallback onChanged;

  const _TxnRow({
    required this.txn,
    required this.outstanding,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = !txn.isCredit;
    final amtColor = isDebit
        ? AppTheme.error
        : txn.status == _TxnStatus.matched
            ? const Color(0xFF059669)
            : AppTheme.onCard(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 90,
            child: Text(
              Fmt.shortDate(txn.date),
              style: TextStyle(
                  fontSize: 13,
                  color: isDebit
                      ? AppTheme.subtext(context)
                      : AppTheme.onCard(context)),
            ),
          ),
          const SizedBox(width: 12),

          // Description + reference
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDebit
                        ? AppTheme.subtext(context)
                        : AppTheme.onCard(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (txn.reference != null)
                  Text(
                    txn.reference!,
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Amount
          SizedBox(
            width: 110,
            child: Text(
              '${isDebit ? '-' : ''}${Fmt.currency(txn.amount.abs())}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: amtColor),
            ),
          ),
          const SizedBox(width: 12),

          // Status chip
          SizedBox(width: 110, child: _StatusChip(txn: txn)),
          const SizedBox(width: 12),

          // Invoice match selector (credits only)
          SizedBox(
            width: 200,
            child: isDebit
                ? Text('—',
                    style: TextStyle(color: AppTheme.subtext(context)))
                : _InvoiceSelector(
                    txn: txn,
                    outstanding: outstanding,
                    onChanged: onChanged,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _Txn txn;
  const _StatusChip({required this.txn});

  @override
  Widget build(BuildContext context) {
    if (!txn.isCredit) {
      return Text('Debit',
          style: TextStyle(fontSize: 12, color: AppTheme.subtext(context)));
    }
    return switch (txn.status) {
      _TxnStatus.matched => _chip(
          context, '✓ Matched', const Color(0xFF059669), const Color(0xFFF0FDF4)),
      _TxnStatus.unmatched => _chip(
          context, '? Unmatched', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
      _TxnStatus.ignored => _chip(
          context, '— Ignored', AppTheme.textSecondary, AppTheme.surface),
    };
  }

  Widget _chip(BuildContext ctx, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _InvoiceSelector extends StatelessWidget {
  final _Txn txn;
  final List<Invoice> outstanding;
  final VoidCallback onChanged;

  const _InvoiceSelector({
    required this.txn,
    required this.outstanding,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Find currently matched invoice
    Invoice? matched;
    if (txn.matchedInvoiceId != null) {
      matched = outstanding
          .where((i) => i.id == txn.matchedInvoiceId)
          .firstOrNull;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: matched != null
                ? const Color(0xFFF0FDF4)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: matched != null
                  ? const Color(0xFF059669).withValues(alpha: 0.35)
                  : AppTheme.divider,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: matched != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            matched.invoiceNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                          Text(
                            matched.client?.name ?? '—',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : Text(
                        txn.suggestions.isNotEmpty
                            ? 'Pick invoice…'
                            : 'No match',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(context)),
                      ),
              ),
              Icon(Icons.unfold_more_rounded,
                  size: 15, color: AppTheme.subtext(context)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDialog<String?>(
      context: context,
      builder: (_) => _MatchPickerDialog(
        txn: txn,
        outstanding: outstanding,
      ),
    );
    if (picked == null) return; // dialog dismissed
    if (picked == '__ignore__') {
      txn.status = _TxnStatus.ignored;
      txn.matchedInvoiceId = null;
    } else if (picked == '__clear__') {
      txn.status = _TxnStatus.unmatched;
      txn.matchedInvoiceId = null;
    } else {
      txn.status = _TxnStatus.matched;
      txn.matchedInvoiceId = picked;
    }
    onChanged();
  }
}

// ─── Match picker dialog ──────────────────────────────────────────────────────

class _MatchPickerDialog extends StatefulWidget {
  final _Txn txn;
  final List<Invoice> outstanding;
  const _MatchPickerDialog({required this.txn, required this.outstanding});

  @override
  State<_MatchPickerDialog> createState() => _MatchPickerDialogState();
}

class _MatchPickerDialogState extends State<_MatchPickerDialog> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Invoice> get _filtered {
    if (_query.isEmpty) {
      // Show suggestions first, then rest
      final sugIds = widget.txn.suggestions.map((i) => i.id).toSet();
      final sug = widget.txn.suggestions;
      final rest = widget.outstanding
          .where((i) => !sugIds.contains(i.id))
          .toList()
        ..sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
      return [...sug, ...rest];
    }
    final q = _query.toLowerCase();
    return widget.outstanding.where((i) {
      return i.invoiceNumber.toLowerCase().contains(q) ||
          (i.client?.name.toLowerCase().contains(q) ?? false) ||
          Fmt.currency(i.amountRemaining).contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Invoice',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        Text(
                          '${Fmt.shortDate(widget.txn.date)} · ${Fmt.currency(widget.txn.amount)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by invoice # or client name…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: 8),

            // Invoice list
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                itemCount: _filtered.length + 2, // +2 for ignore + clear
                itemBuilder: (ctx, i) {
                  // Special actions at the bottom
                  if (i == _filtered.length) {
                    return _actionTile(
                      context,
                      icon: Icons.visibility_off_outlined,
                      label: 'Ignore this transaction',
                      color: AppTheme.textSecondary,
                      onTap: () => Navigator.pop(context, '__ignore__'),
                    );
                  }
                  if (i == _filtered.length + 1 &&
                      widget.txn.matchedInvoiceId != null) {
                    return _actionTile(
                      context,
                      icon: Icons.clear_rounded,
                      label: 'Clear match',
                      color: AppTheme.error,
                      onTap: () => Navigator.pop(context, '__clear__'),
                    );
                  }
                  if (i >= _filtered.length) return const SizedBox.shrink();

                  final inv = _filtered[i];
                  final isSuggested = widget.txn.suggestions
                      .any((s) => s.id == inv.id);
                  final isSelected = inv.id == widget.txn.matchedInvoiceId;

                  return _InvoiceTile(
                    invoice: inv,
                    isSuggested: isSuggested && _query.isEmpty,
                    isSelected: isSelected,
                    txnAmount: widget.txn.amount,
                    onTap: () => Navigator.pop(context, inv.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: color),
      title: Text(label, style: TextStyle(fontSize: 13, color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final bool isSuggested;
  final bool isSelected;
  final double txnAmount;
  final VoidCallback onTap;

  const _InvoiceTile({
    required this.invoice,
    required this.isSuggested,
    required this.isSelected,
    required this.txnAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final diff = (invoice.amountRemaining - txnAmount).abs();
    final exact = diff < 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFF0FDF4)
            : isSuggested
                ? AppTheme.primary.withValues(alpha: 0.03)
                : null,
        borderRadius: BorderRadius.circular(9),
        border: isSelected
            ? Border.all(
                color: const Color(0xFF059669).withValues(alpha: 0.4))
            : null,
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        title: Row(
          children: [
            Text(
              invoice.invoiceNumber,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF059669)
                    : AppTheme.textPrimary,
              ),
            ),
            if (isSuggested && !isSelected) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Suggested',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ),
            ],
            if (exact) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Exact',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669))),
              ),
            ],
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: Color(0xFF059669)),
          ],
        ),
        subtitle: Text(
          '${invoice.client?.name ?? '—'}  ·  Due ${Fmt.shortDate(invoice.dueDate)}',
          style:
              const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Fmt.currency(invoice.amountRemaining),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            Text(
              'outstanding',
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Done
// ─────────────────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  final int count;
  final VoidCallback onReset;

  const _DoneView({required this.count, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 36, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 20),
          Text(
            '$count payment${count == 1 ? '' : 's'} recorded',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.onCard(context),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invoice statuses have been updated automatically.',
            style:
                TextStyle(fontSize: 14, color: AppTheme.subtext(context)),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: const Text('Reconcile another file'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
