import 'package:drift/drift.dart';

@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get collection => text()();
  TextColumn get id => text()();
  TextColumn get dataJson => text()();

  @override
  Set<Column> get primaryKey => {collection, id};
}
