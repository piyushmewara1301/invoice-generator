class BusinessInfo {
  final String id;
  String name;

  BusinessInfo({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory BusinessInfo.fromJson(Map<String, dynamic> j) =>
      BusinessInfo(id: j['id'] as String, name: j['name'] as String? ?? '');
}
