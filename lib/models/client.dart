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
      );
}
