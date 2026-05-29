class LineItem {
  String description;
  double quantity;
  double rate;
  double taxPercent;
  double discountPercent;
  String unit;
  String? hsnSac; // HSN (goods) or SAC (services) code — required for GST invoices
  String? category;

  LineItem({
    required this.description,
    this.quantity = 1,
    required this.rate,
    this.taxPercent = 0,
    this.discountPercent = 0,
    this.unit = 'pcs',
    this.hsnSac,
    this.category,
  });

  double get subtotal => quantity * rate;
  double get discountAmount => subtotal * (discountPercent / 100);
  double get taxableAmount => subtotal - discountAmount;
  double get taxAmount => taxableAmount * (taxPercent / 100);
  double get total => taxableAmount + taxAmount;

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'rate': rate,
        'taxPercent': taxPercent,
        'discountPercent': discountPercent,
        'unit': unit,
        'hsnSac': hsnSac,
        'category': category,
      };

  LineItem copy() => LineItem(
        description: description,
        quantity: quantity,
        rate: rate,
        taxPercent: taxPercent,
        discountPercent: discountPercent,
        unit: unit,
        hsnSac: hsnSac,
        category: category,
      );

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
        description: json['description'],
        quantity: (json['quantity'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        taxPercent: (json['taxPercent'] as num).toDouble(),
        discountPercent: (json['discountPercent'] as num).toDouble(),
        unit: json['unit'] ?? 'pcs',
        hsnSac: json['hsnSac'] as String?,
        category: json['category'] as String?,
      );
}
