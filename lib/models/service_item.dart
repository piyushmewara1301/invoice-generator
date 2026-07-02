/// Marker key used to migrate stock recorded before per-shop tracking
/// existed. AppProvider rewrites this to the device's own shop id on load.
const kLegacyShopKey = '_legacy';

class ProductVariant {
  final String id;
  String name;    // e.g. "180ml", "360ml", "500ml"
  double rate;    // selling price
  double? costPrice;
  String? barcode;
  bool trackStock;
  Map<String, double> stockByShop; // shopId -> quantity on hand
  double? lowStockThreshold;

  ProductVariant({
    required this.id,
    required this.name,
    required this.rate,
    this.costPrice,
    this.barcode,
    this.trackStock = false,
    Map<String, double>? stockByShop,
    this.lowStockThreshold,
  }) : stockByShop = stockByShop ?? {};

  bool get isTrackingStock => trackStock;

  /// Total quantity on hand across all shops.
  double get totalStock =>
      stockByShop.values.fold(0.0, (a, b) => a + b);

  /// Quantity on hand for [shopId], or the total across all shops if null.
  double stockFor(String? shopId) =>
      shopId == null ? totalStock : (stockByShop[shopId] ?? 0);

  bool isLowStockFor(String? shopId) =>
      trackStock &&
      lowStockThreshold != null &&
      stockFor(shopId) <= lowStockThreshold!;

  bool get isLowStock => isLowStockFor(null);

  double? get margin => costPrice != null ? rate - costPrice! : null;

  ProductVariant copyWith({
    String? name,
    double? rate,
    double? costPrice,
    String? barcode,
    bool? trackStock,
    Map<String, double>? stockByShop,
    double? lowStockThreshold,
  }) =>
      ProductVariant(
        id: id,
        name: name ?? this.name,
        rate: rate ?? this.rate,
        costPrice: costPrice ?? this.costPrice,
        barcode: barcode ?? this.barcode,
        trackStock: trackStock ?? this.trackStock,
        stockByShop: stockByShop ?? Map.of(this.stockByShop),
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rate': rate,
        if (costPrice != null) 'costPrice': costPrice,
        'barcode': barcode,
        'trackStock': trackStock,
        'stockByShop': stockByShop,
        'lowStockThreshold': lowStockThreshold,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final stockByShop = <String, double>{};
    final rawStock = json['stockByShop'];
    if (rawStock is Map) {
      rawStock.forEach((k, v) {
        final qty = (v as num?)?.toDouble();
        if (qty != null) stockByShop[k.toString()] = qty;
      });
    }
    final legacyQty = (json['quantityOnHand'] as num?)?.toDouble();
    if (stockByShop.isEmpty && legacyQty != null) {
      stockByShop[kLegacyShopKey] = legacyQty;
    }
    final trackStock = json['trackStock'] as bool? ??
        (legacyQty != null || stockByShop.isNotEmpty);
    return ProductVariant(
      id: json['id'] as String,
      name: json['name'] as String,
      rate: (json['rate'] as num).toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      barcode: json['barcode'] as String?,
      trackStock: trackStock,
      stockByShop: stockByShop,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble(),
    );
  }
}

class ServiceItem {
  final String id;
  String name;
  String? description;
  double rate;       // selling price
  double? costPrice; // purchase / cost price (optional)
  double taxPercent;
  String? unit;
  String? hsnSac;
  String? category;
  String? barcode;

  // ── Inventory / stock tracking ──────────────────────────────────────────────
  /// Whether stock is tracked for this item. Ignored when [variants] is
  /// non-empty (each variant tracks its own stock independently).
  bool trackStock;
  /// Quantity on hand per shop (shopId -> quantity).
  Map<String, double> stockByShop;
  /// Show a low-stock alert when quantity drops to or below this level.
  double? lowStockThreshold;

  // ── Packaging variants ──────────────────────────────────────────────────────
  /// Packaging/size variants (e.g. 180ml, 360ml, 500ml). When non-empty,
  /// [rate] is unused and each variant carries its own price and optional stock.
  List<ProductVariant> variants;

  /// Stamped by AppProvider on every create/edit; used for last-write-wins
  /// merges when syncing the catalog via Google Drive.
  DateTime? lastEditedAt;

  ServiceItem({
    required this.id,
    required this.name,
    this.description,
    this.rate = 0,
    this.costPrice,
    this.taxPercent = 0,
    this.unit,
    this.hsnSac,
    this.category,
    this.barcode,
    this.trackStock = false,
    Map<String, double>? stockByShop,
    this.lowStockThreshold,
    List<ProductVariant>? variants,
    this.lastEditedAt,
  })  : stockByShop = stockByShop ?? {},
        variants = variants ?? [];

  double? get margin => costPrice != null ? rate - costPrice! : null;

  bool get isTrackingStock =>
      hasVariants
          ? variants.any((v) => v.isTrackingStock)
          : trackStock;

  /// Total quantity on hand across all shops.
  double get totalStock => hasVariants
      ? variants.fold(0.0, (sum, v) => sum + v.totalStock)
      : stockByShop.values.fold(0.0, (a, b) => a + b);

  /// Quantity on hand for [shopId], or the total across all shops if null.
  double stockFor(String? shopId) => hasVariants
      ? variants.fold(0.0, (sum, v) => sum + v.stockFor(shopId))
      : (shopId == null ? totalStock : (stockByShop[shopId] ?? 0));

  bool isLowStockFor(String? shopId) => hasVariants
      ? variants.any((v) => v.isLowStockFor(shopId))
      : trackStock &&
          lowStockThreshold != null &&
          stockFor(shopId) <= lowStockThreshold!;

  bool get isLowStock => isLowStockFor(null);

  bool get hasVariants => variants.isNotEmpty;

  /// Lowest variant rate for display in lists.
  double get lowestVariantRate =>
      hasVariants ? variants.map((v) => v.rate).reduce((a, b) => a < b ? a : b) : rate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'rate': rate,
        if (costPrice != null) 'costPrice': costPrice,
        'taxPercent': taxPercent,
        'unit': unit,
        'hsnSac': hsnSac,
        'category': category,
        'barcode': barcode,
        'trackStock': trackStock,
        'stockByShop': stockByShop,
        'lowStockThreshold': lowStockThreshold,
        'variants': variants.map((v) => v.toJson()).toList(),
        'lastEditedAt': lastEditedAt?.toIso8601String(),
      };

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final stockByShop = <String, double>{};
    final rawStock = json['stockByShop'];
    if (rawStock is Map) {
      rawStock.forEach((k, v) {
        final qty = (v as num?)?.toDouble();
        if (qty != null) stockByShop[k.toString()] = qty;
      });
    }
    final legacyQty = (json['quantityOnHand'] as num?)?.toDouble();
    if (stockByShop.isEmpty && legacyQty != null) {
      stockByShop[kLegacyShopKey] = legacyQty;
    }
    final trackStock = json['trackStock'] as bool? ??
        (legacyQty != null || stockByShop.isNotEmpty);
    return ServiceItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String?,
      hsnSac: json['hsnSac'] as String?,
      category: json['category'] as String?,
      barcode: json['barcode'] as String?,
      trackStock: trackStock,
      stockByShop: stockByShop,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble(),
      variants: (json['variants'] as List<dynamic>?)
              ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastEditedAt: json['lastEditedAt'] != null
          ? DateTime.tryParse(json['lastEditedAt'] as String)
          : null,
    );
  }
}
