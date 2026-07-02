import 'package:drift/drift.dart';

@DataClassName('InvoiceRow')
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get dataJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}
