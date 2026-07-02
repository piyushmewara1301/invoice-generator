import 'package:drift/drift.dart';

@TableIndex(name: 'idx_service_items_name', columns: {#name})
@TableIndex(name: 'idx_service_items_category', columns: {#category})
@TableIndex(name: 'idx_service_items_barcode', columns: {#barcode}, unique: true)
@DataClassName('ServiceItemRow')
class ServiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get name =>
      text().customConstraint("NOT NULL DEFAULT '' COLLATE NOCASE")();
  TextColumn get description => text().nullable()();
  RealColumn get rate => real().withDefault(const Constant(0))();
  RealColumn get costPrice => real().nullable()();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  TextColumn get unit => text().nullable()();
  TextColumn get hsnSac => text().nullable()();
  TextColumn get category =>
      text().nullable().customConstraint('COLLATE NOCASE')();
  TextColumn get barcode => text().nullable()();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  RealColumn get lowStockThreshold => real().nullable()();
  DateTimeColumn get lastEditedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_product_variants_item', columns: {#itemId})
@TableIndex(name: 'idx_product_variants_barcode', columns: {#barcode}, unique: true)
@DataClassName('ProductVariantRow')
class ProductVariants extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get rate => real().withDefault(const Constant(0))();
  RealColumn get costPrice => real().nullable()();
  TextColumn get barcode => text().nullable()();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  RealColumn get lowStockThreshold => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-shop quantity on hand for a [ServiceItems] row, or one of its
/// [ProductVariants] when [variantId] is non-empty.
@TableIndex(name: 'idx_item_stock_item', columns: {#itemId})
@TableIndex(
  name: 'idx_item_stock_unique',
  columns: {#itemId, #variantId, #shopId},
  unique: true,
)
@DataClassName('ItemStockRow')
class ItemStock extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get itemId => text()();
  /// Empty string means the stock belongs to the item itself (no variant).
  TextColumn get variantId => text().withDefault(const Constant(''))();
  TextColumn get shopId => text()();
  RealColumn get quantity => real().withDefault(const Constant(0))();
}
