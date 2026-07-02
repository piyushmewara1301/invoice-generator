import 'package:drift/drift.dart';

@TableIndex(name: 'idx_clients_name', columns: {#name})
@TableIndex(name: 'idx_clients_email', columns: {#email})
@TableIndex(name: 'idx_clients_phone', columns: {#phone})
@TableIndex(name: 'idx_clients_company', columns: {#companyName})
@DataClassName('ClientRow')
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name =>
      text().customConstraint("NOT NULL DEFAULT '' COLLATE NOCASE")();
  TextColumn get email =>
      text().customConstraint("NOT NULL DEFAULT '' COLLATE NOCASE")();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get state => text().withDefault(const Constant(''))();
  TextColumn get country => text().withDefault(const Constant(''))();
  TextColumn get postalCode => text().withDefault(const Constant(''))();
  TextColumn get gstin => text().nullable()();
  TextColumn get companyName =>
      text().nullable().customConstraint('COLLATE NOCASE')();
  TextColumn get industry => text().nullable()();
  RealColumn get creditLimit => real().nullable()();
  BoolColumn get isBulkBuyer => boolean().withDefault(const Constant(false))();
  RealColumn get bulkDiscountPercent => real().withDefault(const Constant(0.0))();
  TextColumn get createdBy => text().nullable()();
  TextColumn get lastEditedBy => text().nullable()();
  DateTimeColumn get lastEditedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
