class PartialPayment {
  final String id;
  final DateTime date;
  final double amount;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String? notes;
  // Locked at payment time — only set when invoice currency ≠ base currency
  final double? exchangeRate;     // 1 invoice-currency = X base-currency
  final String? baseCurrencyCode; // e.g. 'INR'
  final double? baseAmount;       // amount converted to base currency

  PartialPayment({
    required this.id,
    required this.date,
    required this.amount,
    this.paymentMethodId,
    this.paymentMethodName,
    this.notes,
    this.exchangeRate,
    this.baseCurrencyCode,
    this.baseAmount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'paymentMethodId': paymentMethodId,
        'paymentMethodName': paymentMethodName,
        'notes': notes,
        'exchangeRate': exchangeRate,
        'baseCurrencyCode': baseCurrencyCode,
        'baseAmount': baseAmount,
      };

  factory PartialPayment.fromJson(Map<String, dynamic> json) => PartialPayment(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        paymentMethodId: json['paymentMethodId'] as String?,
        paymentMethodName: json['paymentMethodName'] as String?,
        notes: json['notes'] as String?,
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
        baseCurrencyCode: json['baseCurrencyCode'] as String?,
        baseAmount: (json['baseAmount'] as num?)?.toDouble(),
      );
}
