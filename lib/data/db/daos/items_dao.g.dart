// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'items_dao.dart';

// ignore_for_file: type=lint
mixin _$ItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ServiceItemsTable get serviceItems => attachedDatabase.serviceItems;
  $ProductVariantsTable get productVariants => attachedDatabase.productVariants;
  $ItemStockTable get itemStock => attachedDatabase.itemStock;
  ItemsDaoManager get managers => ItemsDaoManager(this);
}

class ItemsDaoManager {
  final _$ItemsDaoMixin _db;
  ItemsDaoManager(this._db);
  $$ServiceItemsTableTableManager get serviceItems =>
      $$ServiceItemsTableTableManager(_db.attachedDatabase, _db.serviceItems);
  $$ProductVariantsTableTableManager get productVariants =>
      $$ProductVariantsTableTableManager(
        _db.attachedDatabase,
        _db.productVariants,
      );
  $$ItemStockTableTableManager get itemStock =>
      $$ItemStockTableTableManager(_db.attachedDatabase, _db.itemStock);
}
