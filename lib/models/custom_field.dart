/// A key-value pair the user can add to any invoice (e.g. PO Number, Project).
class CustomField {
  String name;
  String value;

  CustomField({required this.name, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory CustomField.fromJson(Map<String, dynamic> j) =>
      CustomField(name: j['name'] as String, value: j['value'] as String? ?? '');

  CustomField copy() => CustomField(name: name, value: value);
}
