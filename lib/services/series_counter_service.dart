import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';

/// Manages per-business sequential series counters in Firestore.
///
/// Firestore path:  /series_counters/{ownerEmail}
/// Document fields: { invoice: N, quotation: N, challan: N, creditNote: N }
///
/// All counter increments run inside a [runTransaction] call, so concurrent
/// pushes from multiple employees never produce duplicate series numbers.
class SeriesCounterService {
  static final SeriesCounterService _instance =
      SeriesCounterService._internal();
  factory SeriesCounterService() => _instance;
  SeriesCounterService._internal();

  static final _db = FirebaseFirestore.instance;
  static const _col = 'series_counters';

  /// Assigns real sequential numbers to every invoice in [pending].
  ///
  /// [pending] must be sorted by [Invoice.createdAt] ascending so numbers
  /// follow creation order.  Returns a map of { invoiceId → assignedNumber }.
  ///
  /// [seedCounters] provides the starting values used only when the Firestore
  /// document does not yet exist (i.e. first sync after the feature is
  /// enabled).  Pass { 'invoice': profile.nextInvoiceNumber, … }.
  ///
  /// Throws if Firestore is unavailable — callers should swallow the error
  /// and retry on the next push.
  Future<Map<String, String>> assignPendingNumbers({
    required String ownerEmail,
    required String invoicePrefix,
    required String quotationPrefix,
    required String challanPrefix,
    required List<Invoice> pending,
    required Map<String, int> seedCounters,
  }) async {
    if (pending.isEmpty) return {};

    // Partition by document type, preserving chronological order.
    final invoices = pending
        .where((i) => !i.isQuotation && !i.isDeliveryChallan && !i.isCreditNote)
        .toList();
    final quotations = pending.where((i) => i.isQuotation).toList();
    final challans = pending.where((i) => i.isDeliveryChallan).toList();
    final creditNotes = pending.where((i) => i.isCreditNote).toList();

    final result = <String, String>{};
    final ref = _db.collection(_col).doc(ownerEmail);

    await _db.runTransaction((txn) async {
      // ── Read first (Firestore requires all reads before any writes) ──────
      final snap = await txn.get(ref);
      final data = snap.exists ? snap.data()! : <String, dynamic>{};

      // Prefer Firestore counter; fall back to profile seed on first use.
      int iCnt  = (data['invoice']    as int?) ?? seedCounters['invoice']!;
      int qCnt  = (data['quotation']  as int?) ?? seedCounters['quotation']!;
      int cCnt  = (data['challan']    as int?) ?? seedCounters['challan']!;
      int cnCnt = (data['creditNote'] as int?) ?? seedCounters['creditNote']!;

      // ── Assign numbers ────────────────────────────────────────────────────
      for (final inv in invoices) {
        result[inv.id] = '$invoicePrefix${iCnt.toString().padLeft(4, '0')}';
        iCnt++;
      }
      for (final q in quotations) {
        result[q.id] = '$quotationPrefix${qCnt.toString().padLeft(4, '0')}';
        qCnt++;
      }
      for (final c in challans) {
        result[c.id] = '$challanPrefix${cCnt.toString().padLeft(4, '0')}';
        cCnt++;
      }
      for (final cn in creditNotes) {
        result[cn.id] = 'CN-${cnCnt.toString().padLeft(4, '0')}';
        cnCnt++;
      }

      // ── Write updated counters ────────────────────────────────────────────
      txn.set(ref, {
        'invoice':     iCnt,
        'quotation':   qCnt,
        'challan':     cCnt,
        'creditNote':  cnCnt,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });

    return result;
  }
}
