import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/invoice.dart';
import '../app_database.dart';
import '../tables/invoices_table.dart';

part 'invoices_dao.g.dart';

@DriftAccessor(tables: [Invoices])
class InvoicesDao extends DatabaseAccessor<AppDatabase>
    with _$InvoicesDaoMixin {
  InvoicesDao(super.db);

  Invoice _toModel(InvoiceRow row) =>
      Invoice.fromJson(jsonDecode(row.dataJson) as Map<String, dynamic>);

  InvoicesCompanion _toCompanion(Invoice inv) => InvoicesCompanion(
        id: Value(inv.id),
        dataJson: Value(jsonEncode(inv.toJson())),
      );

  Future<void> upsert(Invoice invoice) async =>
      into(invoices).insertOnConflictUpdate(_toCompanion(invoice));

  /// Batch upsert for bulk operations (CSV import, recurring generation, etc.)
  Future<void> upsertAll(List<Invoice> list) async {
    if (list.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(
        invoices, list.map(_toCompanion).toList()));
  }

  Future<void> deleteById(String id) async =>
      (delete(invoices)..where((t) => t.id.equals(id))).go();

  Future<int> count() async {
    final countExp = invoices.id.count();
    final query = selectOnly(invoices)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<List<Invoice>> allForExport() async =>
      (await select(invoices).get()).map(_toModel).toList();

  /// Transactionally replaces the entire table — used for Drive payload
  /// apply/merge.
  Future<void> replaceAll(List<Invoice> newInvoices) async {
    await transaction(() async {
      await delete(invoices).go();
      await batch((b) =>
          b.insertAll(invoices, newInvoices.map(_toCompanion).toList()));
    });
  }
}
