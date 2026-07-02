import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/documents_table.dart';

part 'documents_dao.g.dart';

@DriftAccessor(tables: [Documents])
class DocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentsDaoMixin {
  DocumentsDao(super.db);

  Future<void> upsertOne(String collection, String id, String dataJson) async =>
      into(documents).insertOnConflictUpdate(DocumentsCompanion(
        collection: Value(collection),
        id: Value(id),
        dataJson: Value(dataJson),
      ));

  Future<void> upsertMany(
      String collection, Map<String, String> idToJson) async {
    if (idToJson.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(
        documents,
        idToJson.entries
            .map((e) => DocumentsCompanion(
                  collection: Value(collection),
                  id: Value(e.key),
                  dataJson: Value(e.value),
                ))
            .toList()));
  }

  Future<void> deleteById(String collection, String id) async =>
      (delete(documents)
            ..where((t) => t.collection.equals(collection) & t.id.equals(id)))
          .go();

  Future<int> count(String collection) async {
    final countExp = documents.id.count();
    final query = selectOnly(documents)
      ..addColumns([countExp])
      ..where(documents.collection.equals(collection));
    return (await query.getSingle()).read(countExp) ?? 0;
  }

  Future<List<String>> allJsonForExport(String collection) async =>
      (await (select(documents)..where((t) => t.collection.equals(collection)))
              .get())
          .map((r) => r.dataJson)
          .toList();

  Future<void> replaceAll(
      String collection, Map<String, String> idToJson) async {
    await transaction(() async {
      await (delete(documents)
            ..where((t) => t.collection.equals(collection)))
          .go();
      await batch((b) => b.insertAll(
          documents,
          idToJson.entries
              .map((e) => DocumentsCompanion(
                    collection: Value(collection),
                    id: Value(e.key),
                    dataJson: Value(e.value),
                  ))
              .toList()));
    });
  }
}
