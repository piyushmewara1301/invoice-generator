import 'package:drift/drift.dart';

import '../../../models/service_item.dart';
import '../app_database.dart';
import '../tables/items_table.dart';

part 'items_dao.g.dart';

/// Result of a barcode lookup: the matched item, and the specific variant
/// (if the barcode belonged to a variant rather than the item itself).
class ServiceItemMatch {
  final ServiceItem item;
  final ProductVariant? variant;

  const ServiceItemMatch({required this.item, this.variant});
}

@DriftAccessor(tables: [ServiceItems, ProductVariants, ItemStock])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  // ── Conversion helpers ──────────────────────────────────────────────────

  ProductVariant _variantToModel(
    ProductVariantRow row,
    Map<String, double> stockByShop,
  ) =>
      ProductVariant(
        id: row.id,
        name: row.name,
        rate: row.rate,
        costPrice: row.costPrice,
        barcode: row.barcode,
        trackStock: row.trackStock,
        stockByShop: stockByShop,
        lowStockThreshold: row.lowStockThreshold,
      );

  ServiceItem _itemToModel(
    ServiceItemRow row,
    List<ProductVariantRow> variantRows,
    Map<String, Map<String, double>> stockByVariantId,
  ) =>
      ServiceItem(
        id: row.id,
        name: row.name,
        description: row.description,
        rate: row.rate,
        costPrice: row.costPrice,
        taxPercent: row.taxPercent,
        unit: row.unit,
        hsnSac: row.hsnSac,
        category: row.category,
        barcode: row.barcode,
        trackStock: row.trackStock,
        stockByShop: stockByVariantId[''] ?? {},
        lowStockThreshold: row.lowStockThreshold,
        variants: variantRows
            .map((v) => _variantToModel(v, stockByVariantId[v.id] ?? {}))
            .toList(),
      )..lastEditedAt = row.lastEditedAt;

  ServiceItemsCompanion _itemToCompanion(ServiceItem item) =>
      ServiceItemsCompanion(
        id: Value(item.id),
        name: Value(item.name),
        description: Value(item.description),
        rate: Value(item.rate),
        costPrice: Value(item.costPrice),
        taxPercent: Value(item.taxPercent),
        unit: Value(item.unit),
        hsnSac: Value(item.hsnSac),
        category: Value(item.category),
        barcode: Value(item.barcode),
        trackStock: Value(item.trackStock),
        lowStockThreshold: Value(item.lowStockThreshold),
        lastEditedAt: Value(item.lastEditedAt),
      );

  ProductVariantsCompanion _variantToCompanion(
          String itemId, ProductVariant v) =>
      ProductVariantsCompanion(
        id: Value(v.id),
        itemId: Value(itemId),
        name: Value(v.name),
        rate: Value(v.rate),
        costPrice: Value(v.costPrice),
        barcode: Value(v.barcode),
        trackStock: Value(v.trackStock),
        lowStockThreshold: Value(v.lowStockThreshold),
      );

  List<ItemStockCompanion> _stockCompanionsFor(ServiceItem item) {
    final rows = <ItemStockCompanion>[];
    item.stockByShop.forEach((shopId, qty) {
      rows.add(ItemStockCompanion.insert(
        itemId: item.id,
        variantId: const Value(''),
        shopId: shopId,
        quantity: Value(qty),
      ));
    });
    for (final v in item.variants) {
      v.stockByShop.forEach((shopId, qty) {
        rows.add(ItemStockCompanion.insert(
          itemId: item.id,
          variantId: Value(v.id),
          shopId: shopId,
          quantity: Value(qty),
        ));
      });
    }
    return rows;
  }

  /// Hydrates a page of [ServiceItemRow]s with their variants and stock.
  Future<List<ServiceItem>> _hydrate(List<ServiceItemRow> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r.id).toList();

    final variantRows = await (select(productVariants)
          ..where((t) => t.itemId.isIn(ids)))
        .get();
    final stockRows =
        await (select(itemStock)..where((t) => t.itemId.isIn(ids))).get();

    final variantsByItem = <String, List<ProductVariantRow>>{};
    for (final v in variantRows) {
      variantsByItem.putIfAbsent(v.itemId, () => []).add(v);
    }

    // itemId -> (variantId or '' for the item itself) -> shopId -> quantity
    final stockByItem = <String, Map<String, Map<String, double>>>{};
    for (final s in stockRows) {
      final byVariant = stockByItem.putIfAbsent(s.itemId, () => {});
      final byShop = byVariant.putIfAbsent(s.variantId, () => {});
      byShop[s.shopId] = s.quantity;
    }

    return rows
        .map((r) => _itemToModel(
              r,
              variantsByItem[r.id] ?? const [],
              stockByItem[r.id] ?? const {},
            ))
        .toList();
  }

  // ── Queries ──────────────────────────────────────────────────────────────

  /// Streams a search/paginated/category-filtered page of items ordered by
  /// name.
  Stream<List<ServiceItem>> watchServiceItems({
    String search = '',
    String? category,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(serviceItems);
    if (search.trim().isNotEmpty) {
      final pattern = '%${search.trim()}%';
      query.where((t) =>
          t.name.like(pattern) |
          t.barcode.like(pattern) |
          t.category.like(pattern) |
          t.hsnSac.like(pattern));
    }
    if (category != null && category.isNotEmpty) {
      query.where((t) => t.category.equals(category));
    }
    query
      ..orderBy([(t) => OrderingTerm(expression: t.name)])
      ..limit(limit, offset: offset);
    return query.watch().asyncMap(_hydrate);
  }

  /// Streams the full item catalog, used to populate the in-memory cache
  /// that backs [AppProvider.serviceItems] for existing call sites.
  Stream<List<ServiceItem>> watchAllForCache() {
    return select(serviceItems).watch().asyncMap(_hydrate);
  }

  /// Items that track stock (directly, or via at least one variant),
  /// optionally filtered by [search]. Used by inventory/stock-transfer
  /// screens which need a bounded subset of the catalog.
  Stream<List<ServiceItem>> watchTrackedItems({String search = ''}) {
    final query = select(serviceItems);
    final hasTrackedVariant = existsQuery(select(productVariants)
      ..where((v) =>
          v.itemId.equalsExp(serviceItems.id) & v.trackStock.equals(true)));
    query.where((t) => t.trackStock.equals(true) | hasTrackedVariant);
    if (search.trim().isNotEmpty) {
      final pattern = '%${search.trim()}%';
      query.where((t) => t.name.like(pattern) | t.category.like(pattern));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch().asyncMap(_hydrate);
  }

  /// Debounced search for item-picker autocompletes (invoices, POS, daily
  /// sales). Matches on name, barcode, category or HSN/SAC.
  Future<List<ServiceItem>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) {
      final rows = await (select(serviceItems)
            ..orderBy([(t) => OrderingTerm(expression: t.name)])
            ..limit(limit))
          .get();
      return _hydrate(rows);
    }
    final pattern = '%${query.trim()}%';
    final q = select(serviceItems)
      ..where((t) =>
          t.name.like(pattern) |
          t.barcode.like(pattern) |
          t.category.like(pattern) |
          t.hsnSac.like(pattern))
      ..orderBy([(t) => OrderingTerm(expression: t.name)])
      ..limit(limit);
    return _hydrate(await q.get());
  }

  /// Items in a given [category], for POS category grids.
  Future<List<ServiceItem>> byCategory(String category, {int limit = 100}) async {
    final rows = await (select(serviceItems)
          ..where((t) => t.category.equals(category))
          ..orderBy([(t) => OrderingTerm(expression: t.name)])
          ..limit(limit))
        .get();
    return _hydrate(rows);
  }

  /// Indexed point lookup by barcode, checking both items and variants.
  Future<ServiceItemMatch?> findByBarcode(String barcode) async {
    final itemRow = await (select(serviceItems)
          ..where((t) => t.barcode.equals(barcode)))
        .getSingleOrNull();
    if (itemRow != null) {
      final hydrated = await _hydrate([itemRow]);
      return ServiceItemMatch(item: hydrated.first);
    }

    final variantRow = await (select(productVariants)
          ..where((t) => t.barcode.equals(barcode)))
        .getSingleOrNull();
    if (variantRow == null) return null;

    final parentRow = await (select(serviceItems)
          ..where((t) => t.id.equals(variantRow.itemId)))
        .getSingleOrNull();
    if (parentRow == null) return null;

    final hydrated = await _hydrate([parentRow]);
    final item = hydrated.first;
    final variant = item.variants.firstWhere((v) => v.id == variantRow.id);
    return ServiceItemMatch(item: item, variant: variant);
  }

  /// Distinct, non-empty categories for the services screen filter dropdown.
  Future<List<String>> distinctCategories() async {
    final categoryCol = serviceItems.category;
    final query = selectOnly(serviceItems, distinct: true)
      ..addColumns([categoryCol])
      ..where(categoryCol.isNotNull() & categoryCol.equals('').not())
      ..orderBy([OrderingTerm(expression: categoryCol)]);
    final rows = await query.get();
    return rows
        .map((r) => r.read(categoryCol))
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toList();
  }

  Future<int> countItems() async {
    final countExp = serviceItems.id.count();
    final query = selectOnly(serviceItems)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  // ── Mutations ────────────────────────────────────────────────────────────

  Future<void> upsert(ServiceItem item) async {
    await transaction(() async {
      await into(serviceItems).insertOnConflictUpdate(_itemToCompanion(item));
      await (delete(productVariants)..where((t) => t.itemId.equals(item.id)))
          .go();
      await (delete(itemStock)..where((t) => t.itemId.equals(item.id))).go();
      if (item.variants.isNotEmpty) {
        await batch((b) {
          b.insertAll(productVariants,
              item.variants.map((v) => _variantToCompanion(item.id, v)).toList());
        });
      }
      final stockCompanions = _stockCompanionsFor(item);
      if (stockCompanions.isNotEmpty) {
        await batch((b) => b.insertAll(itemStock, stockCompanions));
      }
    });
  }

  Future<void> deleteById(String id) async {
    await transaction(() async {
      await (delete(productVariants)..where((t) => t.itemId.equals(id))).go();
      await (delete(itemStock)..where((t) => t.itemId.equals(id))).go();
      await (delete(serviceItems)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<ServiceItem?> getById(String id) async {
    final row = await (select(serviceItems)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).first;
  }

  Future<List<ServiceItem>> allForExport() async {
    final rows = await select(serviceItems).get();
    return _hydrate(rows);
  }

  /// Items that haven't been individually edited recently are skipped when
  /// CSV-importing inventory; this loads everything once for de-dup matching
  /// (bounded by import file size, not catalog size).
  Future<List<ServiceItem>> allForImportMatch() => allForExport();

  /// Transactionally replaces the entire catalog (items, variants, stock)
  /// with [newItems]. Used when applying a freshly-downloaded Drive payload.
  Future<void> replaceAll(List<ServiceItem> newItems) async {
    await transaction(() async {
      await delete(itemStock).go();
      await delete(productVariants).go();
      await delete(serviceItems).go();
      await batch((b) {
        b.insertAll(serviceItems, newItems.map(_itemToCompanion).toList());
        for (final item in newItems) {
          if (item.variants.isNotEmpty) {
            b.insertAll(productVariants,
                item.variants.map((v) => _variantToCompanion(item.id, v)).toList());
          }
          final stockCompanions = _stockCompanionsFor(item);
          if (stockCompanions.isNotEmpty) {
            b.insertAll(itemStock, stockCompanions);
          }
        }
      });
    });
  }
}
