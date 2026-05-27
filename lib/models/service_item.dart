class ServiceItem {
  final String id;
  String name;
  String? description;
  double rate;
  double taxPercent;
  String? unit;
  String? hsnSac; // HSN (goods) or SAC (services) code

  ServiceItem({
    required this.id,
    required this.name,
    this.description,
    this.rate = 0,
    this.taxPercent = 0,
    this.unit,
    this.hsnSac,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'rate': rate,
        'taxPercent': taxPercent,
        'unit': unit,
        'hsnSac': hsnSac,
      };

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        rate: (json['rate'] as num?)?.toDouble() ?? 0,
        taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String?,
        hsnSac: json['hsnSac'] as String?,
      );
}
