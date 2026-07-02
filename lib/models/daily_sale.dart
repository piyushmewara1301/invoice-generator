class DailySaleExpense {
  final String id;
  final String label;
  final double amount;
  final String? receiptBase64;

  const DailySaleExpense({
    required this.id,
    required this.label,
    required this.amount,
    this.receiptBase64,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        if (receiptBase64 != null) 'receiptBase64': receiptBase64,
      };

  factory DailySaleExpense.fromJson(Map<String, dynamic> json) =>
      DailySaleExpense(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        receiptBase64: json['receiptBase64'] as String?,
      );
}

class DailySaleItem {
  final String id;
  final String itemName;
  final String? itemId;
  final double quantity;
  final double rate;

  const DailySaleItem({
    required this.id,
    required this.itemName,
    this.itemId,
    required this.quantity,
    required this.rate,
  });

  double get total => quantity * rate;

  DailySaleItem copyWith({
    String? itemName,
    String? itemId,
    double? quantity,
    double? rate,
  }) =>
      DailySaleItem(
        id: id,
        itemName: itemName ?? this.itemName,
        itemId: itemId ?? this.itemId,
        quantity: quantity ?? this.quantity,
        rate: rate ?? this.rate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'itemId': itemId,
        'quantity': quantity,
        'rate': rate,
      };

  factory DailySaleItem.fromJson(Map<String, dynamic> json) => DailySaleItem(
        id: json['id'] as String,
        itemName: json['itemName'] as String,
        itemId: json['itemId'] as String?,
        quantity: (json['quantity'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
      );
}

class DailySale {
  final String id;
  final DateTime date;
  final String? title;
  final List<DailySaleItem> items;
  /// Payment amounts keyed by payment method id (e.g. '__cash__', '__bank__', or custom id).
  final Map<String, double> paymentBreakdown;
  final List<DailySaleExpense> expenses;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  /// Invoice IDs linked to this day entry — used to pull client sales,
  /// discounts, and payment data into the daily summary card.
  final List<String> linkedInvoiceIds;

  const DailySale({
    required this.id,
    required this.date,
    this.title,
    required this.items,
    Map<String, double>? paymentBreakdown,
    List<DailySaleExpense>? expenses,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    List<String>? linkedInvoiceIds,
  })  : paymentBreakdown = paymentBreakdown ?? const {},
        expenses = expenses ?? const [],
        linkedInvoiceIds = linkedInvoiceIds ?? const [];

  // Backward-compat getters used by dashboard and list tiles.
  double get cashReceived => paymentBreakdown['__cash__'] ?? 0;
  double get totalReceived =>
      paymentBreakdown.values.fold(0.0, (s, v) => s + v);
  // Sum of all non-cash methods — preserves the "Cash vs Bank" dashboard split.
  double get bankReceived => totalReceived - cashReceived;

  double get totalSales => items.fold(0.0, (s, i) => s + i.total);
  double get totalExpenses => expenses.fold(0.0, (s, e) => s + e.amount);
  double get netCash => totalReceived - totalExpenses;

  /// Cash that should remain in the till at day's end: total sales minus
  /// whatever was collected through non-cash methods (UPI/bank/etc.), minus
  /// expenses — which are typically paid out of the cash drawer. This is
  /// "where the money is parked" once the day is reconciled.
  double get expectedCash => totalSales - bankReceived - totalExpenses;

  /// Total sales vs. money recorded as received, after accounting for cash
  /// spent on expenses — since the cash entered is usually counted *after*
  /// paying expenses out of the till.
  double get difference => (totalSales - totalExpenses) - totalReceived;
  bool get isBalanced => difference.abs() < 0.01;

  DailySale copyWith({
    DateTime? date,
    String? title,
    List<DailySaleItem>? items,
    Map<String, double>? paymentBreakdown,
    List<DailySaleExpense>? expenses,
    String? notes,
    DateTime? updatedAt,
    List<String>? linkedInvoiceIds,
  }) =>
      DailySale(
        id: id,
        date: date ?? this.date,
        title: title ?? this.title,
        items: items ?? this.items,
        paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
        expenses: expenses ?? this.expenses,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        linkedInvoiceIds: linkedInvoiceIds ?? this.linkedInvoiceIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        if (title != null) 'title': title,
        'items': items.map((e) => e.toJson()).toList(),
        'paymentBreakdown': paymentBreakdown,
        // Legacy fields so older app versions can still read the data.
        'cashReceived': cashReceived,
        'bankReceived': bankReceived,
        if (expenses.isNotEmpty)
          'expenses': expenses.map((e) => e.toJson()).toList(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        if (linkedInvoiceIds.isNotEmpty) 'linkedInvoiceIds': linkedInvoiceIds,
      };

  factory DailySale.fromJson(Map<String, dynamic> json) {
    final Map<String, double> breakdown;
    if (json['paymentBreakdown'] != null) {
      breakdown = (json['paymentBreakdown'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else {
      // Migrate from legacy cashReceived / bankReceived fields.
      breakdown = {};
      final cash = (json['cashReceived'] as num?)?.toDouble() ?? 0;
      final bank = (json['bankReceived'] as num?)?.toDouble() ?? 0;
      if (cash != 0) breakdown['__cash__'] = cash;
      if (bank != 0) breakdown['__bank__'] = bank;
    }
    return DailySale(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((e) => DailySaleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentBreakdown: breakdown,
      expenses: (json['expenses'] as List<dynamic>?)
              ?.map((e) =>
                  DailySaleExpense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      linkedInvoiceIds: (json['linkedInvoiceIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
