import 'dart:convert';

import 'app_database.dart';

/// Generic per-row JSON document store backed by the [Documents] table.
///
/// Wraps [DocumentsDao] for a single logical collection, providing the same
/// shape as [InvoicesDao]: [upsert]/[upsertAll]/[deleteById]/[count]/
/// [allForExport]/[replaceAll].
class JsonCollectionStore<T> {
  JsonCollectionStore(
    this._getDb,
    this.collection, {
    required this.toJson,
    required this.fromJson,
    required this.idOf,
  });

  final AppDatabase Function() _getDb;
  final String collection;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;
  final String Function(T) idOf;

  Future<void> upsert(T item) => _getDb()
      .documentsDao
      .upsertOne(collection, idOf(item), jsonEncode(toJson(item)));

  Future<void> upsertAll(List<T> items) {
    if (items.isEmpty) return Future.value();
    return _getDb().documentsDao.upsertMany(
        collection, {for (final i in items) idOf(i): jsonEncode(toJson(i))});
  }

  Future<void> deleteById(String id) =>
      _getDb().documentsDao.deleteById(collection, id);

  Future<int> count() => _getDb().documentsDao.count(collection);

  Future<List<T>> allForExport() async =>
      (await _getDb().documentsDao.allJsonForExport(collection))
          .map((j) => fromJson(jsonDecode(j) as Map<String, dynamic>))
          .toList();

  Future<void> replaceAll(List<T> items) => _getDb().documentsDao.replaceAll(
      collection, {for (final i in items) idOf(i): jsonEncode(toJson(i))});
}
