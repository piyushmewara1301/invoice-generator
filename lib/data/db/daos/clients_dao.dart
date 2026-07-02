import 'package:drift/drift.dart';

import '../../../models/client.dart';
import '../app_database.dart';
import '../tables/clients_table.dart';

part 'clients_dao.g.dart';

@DriftAccessor(tables: [Clients])
class ClientsDao extends DatabaseAccessor<AppDatabase> with _$ClientsDaoMixin {
  ClientsDao(super.db);

  Client _toModel(ClientRow row) => Client(
        id: row.id,
        name: row.name,
        email: row.email,
        phone: row.phone,
        address: row.address,
        city: row.city,
        state: row.state,
        country: row.country,
        postalCode: row.postalCode,
        gstin: row.gstin,
        companyName: row.companyName,
        industry: row.industry,
        creditLimit: row.creditLimit,
        isBulkBuyer: row.isBulkBuyer,
        bulkDiscountPercent: row.bulkDiscountPercent,
        createdBy: row.createdBy,
        lastEditedBy: row.lastEditedBy,
        lastEditedAt: row.lastEditedAt,
      );

  ClientsCompanion _toCompanion(Client c) => ClientsCompanion(
        id: Value(c.id),
        name: Value(c.name),
        email: Value(c.email),
        phone: Value(c.phone),
        address: Value(c.address),
        city: Value(c.city),
        state: Value(c.state),
        country: Value(c.country),
        postalCode: Value(c.postalCode),
        gstin: Value(c.gstin),
        companyName: Value(c.companyName),
        industry: Value(c.industry),
        creditLimit: Value(c.creditLimit),
        isBulkBuyer: Value(c.isBulkBuyer),
        bulkDiscountPercent: Value(c.bulkDiscountPercent),
        createdBy: Value(c.createdBy),
        lastEditedBy: Value(c.lastEditedBy),
        lastEditedAt: Value(c.lastEditedAt),
      );

  /// Streams a search/paginated page of clients ordered by name.
  Stream<List<Client>> watchClients({
    String search = '',
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(clients);
    if (search.trim().isNotEmpty) {
      final pattern = '%${search.trim()}%';
      query.where((t) =>
          t.name.like(pattern) |
          t.email.like(pattern) |
          t.phone.like(pattern) |
          t.companyName.like(pattern) |
          t.gstin.like(pattern));
    }
    query
      ..orderBy([(t) => OrderingTerm(expression: t.name)])
      ..limit(limit, offset: offset);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// Streams the full client list, used to populate the in-memory cache
  /// that backs [AppProvider.clients] for existing call sites.
  Stream<List<Client>> watchAllForCache() {
    return select(clients).watch().map((rows) => rows.map(_toModel).toList());
  }

  Future<int> count() async {
    final countExp = clients.id.count();
    final query = selectOnly(clients)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<void> upsert(Client client) async {
    await into(clients).insertOnConflictUpdate(_toCompanion(client));
  }

  Future<void> deleteById(String id) async {
    await (delete(clients)..where((t) => t.id.equals(id))).go();
  }

  Future<Client?> getById(String id) async {
    final row = await (select(clients)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  Future<List<Client>> allForExport() async {
    final rows = await select(clients).get();
    return rows.map(_toModel).toList();
  }

  /// Transactionally replaces the entire clients table with [newClients].
  /// Used when applying a freshly-downloaded Drive payload.
  Future<void> replaceAll(List<Client> newClients) async {
    await transaction(() async {
      await delete(clients).go();
      await batch((b) {
        b.insertAll(clients, newClients.map(_toCompanion).toList());
      });
    });
  }
}
