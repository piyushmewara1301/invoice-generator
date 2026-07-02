import 'package:drift/drift.dart';

import 'daos/clients_dao.dart';
import 'daos/documents_dao.dart';
import 'daos/invoices_dao.dart';
import 'daos/items_dao.dart';
import 'tables/clients_table.dart';
import 'tables/documents_table.dart';
import 'tables/invoices_table.dart';
import 'tables/items_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Clients, ServiceItems, ProductVariants, ItemStock, Invoices, Documents],
  daos: [ClientsDao, ItemsDao, InvoicesDao, DocumentsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(invoices);
          if (from < 3) await m.createTable(documents);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
