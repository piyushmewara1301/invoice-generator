class Client {
  final String id;
  String name;
  String email;
  String phone;
  String address;
  String city;
  String state;
  String country;
  String postalCode;
  String? gstin;
  String? companyName;
  /// Business industry/sector — used for client segmentation.
  String? industry;

  /// Maximum outstanding balance allowed for this client.
  /// null means no limit is set.
  double? creditLimit;

  /// When true, this client is a regular bulk buyer.
  bool isBulkBuyer;

  /// Discount percentage automatically applied on invoices for this client.
  /// e.g. 10.0 means 10% off every line item. Only used when [isBulkBuyer] is true.
  double bulkDiscountPercent;

  // Audit fields — stamped by AppProvider on every create/edit
  String? createdBy;
  String? lastEditedBy;
  DateTime? lastEditedAt;

  Client({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.postalCode = '',
    this.gstin,
    this.companyName,
    this.industry,
    this.creditLimit,
    this.isBulkBuyer = false,
    this.bulkDiscountPercent = 0.0,
    this.createdBy,
    this.lastEditedBy,
    this.lastEditedAt,
  });

  String get displayName => companyName?.isNotEmpty == true ? companyName! : name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        'gstin': gstin,
        'companyName': companyName,
        'industry': industry,
        'creditLimit': creditLimit,
        'isBulkBuyer': isBulkBuyer,
        'bulkDiscountPercent': bulkDiscountPercent,
        'createdBy': createdBy,
        'lastEditedBy': lastEditedBy,
        'lastEditedAt': lastEditedAt?.toIso8601String(),
      };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'],
        name: json['name'],
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        country: json['country'] ?? 'India',
        postalCode: json['postalCode'] ?? '',
        gstin: json['gstin'],
        companyName: json['companyName'],
        industry: json['industry'] as String?,
        creditLimit: (json['creditLimit'] as num?)?.toDouble(),
        isBulkBuyer: json['isBulkBuyer'] as bool? ?? false,
        bulkDiscountPercent:
            (json['bulkDiscountPercent'] as num?)?.toDouble() ?? 0.0,
        createdBy: json['createdBy'] as String?,
        lastEditedBy: json['lastEditedBy'] as String?,
        lastEditedAt: json['lastEditedAt'] != null
            ? DateTime.tryParse(json['lastEditedAt'] as String)
            : null,
      );
}
