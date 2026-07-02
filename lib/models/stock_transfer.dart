class TransferItem {
  final String itemName;
  final String itemId;
  final String? variantId;
  final String? variantName;
  final double quantity;

  const TransferItem({
    required this.itemName,
    required this.itemId,
    this.variantId,
    this.variantName,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'itemId': itemId,
        if (variantId != null) 'variantId': variantId,
        if (variantName != null) 'variantName': variantName,
        'quantity': quantity,
      };

  factory TransferItem.fromJson(Map<String, dynamic> j) => TransferItem(
        itemName: j['itemName'] as String,
        itemId: j['itemId'] as String,
        variantId: j['variantId'] as String?,
        variantName: j['variantName'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
      );
}

enum TransferStatus { pending, accepted, rejected, cancelled }

class StockTransfer {
  final String id;
  final String ownerEmail;
  final String fromShopId;
  final String fromShopName;
  final String toShopId;
  final String toShopName;
  final List<TransferItem> items;
  final TransferStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? note;

  const StockTransfer({
    required this.id,
    required this.ownerEmail,
    required this.fromShopId,
    required this.fromShopName,
    required this.toShopId,
    required this.toShopName,
    required this.items,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.note,
  });

  bool get isPending => status == TransferStatus.pending;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerEmail': ownerEmail,
        'fromShopId': fromShopId,
        'fromShopName': fromShopName,
        'toShopId': toShopId,
        'toShopName': toShopName,
        'items': items.map((i) => i.toJson()).toList(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory StockTransfer.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.parse(v);
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    return StockTransfer(
      id: j['id'] as String,
      ownerEmail: j['ownerEmail'] as String,
      fromShopId: j['fromShopId'] as String,
      fromShopName: j['fromShopName'] as String,
      toShopId: j['toShopId'] as String,
      toShopName: j['toShopName'] as String,
      items: (j['items'] as List)
          .map((e) => TransferItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: TransferStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => TransferStatus.pending,
      ),
      createdAt: parseDate(j['createdAt']),
      respondedAt:
          j['respondedAt'] != null ? parseDate(j['respondedAt']) : null,
      note: j['note'] as String?,
    );
  }

  StockTransfer copyWith({TransferStatus? status, DateTime? respondedAt}) =>
      StockTransfer(
        id: id,
        ownerEmail: ownerEmail,
        fromShopId: fromShopId,
        fromShopName: fromShopName,
        toShopId: toShopId,
        toShopName: toShopName,
        items: items,
        status: status ?? this.status,
        createdAt: createdAt,
        respondedAt: respondedAt ?? this.respondedAt,
        note: note,
      );
}

class ShopInfo {
  final String shopId;
  final String shopName;
  final DateTime? lastSeen;

  const ShopInfo(
      {required this.shopId, required this.shopName, this.lastSeen});

  Map<String, dynamic> toJson() => {
        'shopId': shopId,
        'shopName': shopName,
        if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
      };

  factory ShopInfo.fromJson(Map<String, dynamic> j) => ShopInfo(
        shopId: j['shopId'] as String,
        shopName: j['shopName'] as String,
        lastSeen: j['lastSeen'] != null
            ? (() {
                final v = j['lastSeen'];
                if (v is String) return DateTime.parse(v);
                try {
                  return (v as dynamic).toDate() as DateTime;
                } catch (_) {
                  return null;
                }
              })()
            : null,
      );
}
