enum PaymentMethodType { cash, bankAccount, upi, other }

extension PaymentMethodTypeInfo on PaymentMethodType {
  String get displayName {
    switch (this) {
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.bankAccount:
        return 'Bank Account';
      case PaymentMethodType.upi:
        return 'UPI';
      case PaymentMethodType.other:
        return 'Other';
    }
  }
}

class PaymentMethod {
  final String id;
  String name;
  PaymentMethodType type;
  String? accountHolder;
  String? accountNumber;
  String? bankName;
  String? ifscCode;
  String? upiId;
  String? notes;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.accountHolder,
    this.accountNumber,
    this.bankName,
    this.ifscCode,
    this.upiId,
    this.notes,
  });

  static PaymentMethod get defaultCash => PaymentMethod(
        id: '__cash__',
        name: 'Cash',
        type: PaymentMethodType.cash,
      );

  bool get isCash => id == '__cash__';

  String get subtitle {
    switch (type) {
      case PaymentMethodType.cash:
        return 'Cash payment';
      case PaymentMethodType.bankAccount:
        final last4 = accountNumber != null && accountNumber!.length >= 4
            ? '••${accountNumber!.substring(accountNumber!.length - 4)}'
            : accountNumber;
        return [bankName, last4].where((s) => s?.isNotEmpty == true).join(' • ');
      case PaymentMethodType.upi:
        return upiId ?? '';
      case PaymentMethodType.other:
        return notes ?? '';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'accountHolder': accountHolder,
        'accountNumber': accountNumber,
        'bankName': bankName,
        'ifscCode': ifscCode,
        'upiId': upiId,
        'notes': notes,
      };

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Payment Method',
        type: PaymentMethodType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PaymentMethodType.other,
        ),
        accountHolder: json['accountHolder'],
        accountNumber: json['accountNumber'],
        bankName: json['bankName'],
        ifscCode: json['ifscCode'],
        upiId: json['upiId'],
        notes: json['notes'],
      );
}
