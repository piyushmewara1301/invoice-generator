// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoices_dao.dart';

// ignore_for_file: type=lint
mixin _$InvoicesDaoMixin on DatabaseAccessor<AppDatabase> {
  $InvoicesTable get invoices => attachedDatabase.invoices;
  InvoicesDaoManager get managers => InvoicesDaoManager(this);
}

class InvoicesDaoManager {
  final _$InvoicesDaoMixin _db;
  InvoicesDaoManager(this._db);
  $$InvoicesTableTableManager get invoices =>
      $$InvoicesTableTableManager(_db.attachedDatabase, _db.invoices);
}
