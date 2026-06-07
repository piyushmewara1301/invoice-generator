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

  // TDS (Tax Deducted at Source) — common in Indian professional services.
  // [amount] = cash actually received; tdsAmount = tax credit from client.
  // Both together settle the invoice: effectivePaid = amount + tdsAmount.
  final double? tdsPercent; // e.g. 10.0 for 10 % TDS
  final double? tdsAmount;  // exact TDS rupee amount deducted by client

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
    this.tdsPercent,
    this.tdsAmount,
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
        'tdsPercent': tdsPercent,
        'tdsAmount': tdsAmount,
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
        tdsPercent: (json['tdsPercent'] as num?)?.toDouble(),
        tdsAmount: (json['tdsAmount'] as num?)?.toDouble(),
      );
}
