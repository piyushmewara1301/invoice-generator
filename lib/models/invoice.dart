import 'client.dart';
import 'invoice_template.dart';
import 'line_item.dart';
import 'partial_payment.dart';

// partiallyPaid added at end (index 5) to preserve existing stored indexes 0-4
enum InvoiceStatus { draft, sent, paid, overdue, cancelled, partiallyPaid }

extension InvoiceStatusExt on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.partiallyPaid:
        return 'Partial';
    }
  }
}

class Invoice {
  final String id;
  String invoiceNumber;
  Client? client;
  DateTime invoiceDate;
  DateTime dueDate;
  List<LineItem> items;
  InvoiceStatus status;
  String? notes;
  String? terms;
  double globalDiscountPercent;
  double globalDiscountFlat;
  String currency;
  DateTime createdAt;
  InvoiceTemplate? template;
  String? paymentMethodId;
  String? paymentMethodName;
  String? subject;
  List<PartialPayment> payments;
  String? placeOfSupply;
  bool reverseCharge;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    this.client,
    required this.invoiceDate,
    required this.dueDate,
    List<LineItem>? items,
    this.status = InvoiceStatus.draft,
    this.subject,
    this.notes,
    this.terms,
    this.globalDiscountPercent = 0,
    this.globalDiscountFlat = 0,
    this.currency = 'INR',
    DateTime? createdAt,
    this.template,
    this.paymentMethodId,
    this.paymentMethodName,
    List<PartialPayment>? payments,
    this.placeOfSupply,
    this.reverseCharge = false,
  })  : items = items ?? [],
        payments = payments ?? [],
        createdAt = createdAt ?? DateTime.now();

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalDiscount =>
      items.fold(0.0, (sum, item) => sum + item.discountAmount) +
      subtotal * (globalDiscountPercent / 100) +
      globalDiscountFlat;
  double get totalTax => items.fold(0, (sum, item) => sum + item.taxAmount);
  double get grandTotal => subtotal - totalDiscount + totalTax;

  double get amountPaid =>
      payments.fold(0.0, (sum, p) => sum + p.amount);
  double get amountRemaining => (grandTotal - amountPaid).clamp(0.0, double.infinity);

  bool get isOverdue =>
      status != InvoiceStatus.paid &&
      status != InvoiceStatus.cancelled &&
      dueDate.isBefore(DateTime.now());

  Invoice copy() => Invoice(
        id: id,
        invoiceNumber: invoiceNumber,
        client: client,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        items: items.map((e) => e.copy()).toList(),
        status: status,
        subject: subject,
        notes: notes,
        terms: terms,
        globalDiscountPercent: globalDiscountPercent,
        globalDiscountFlat: globalDiscountFlat,
        currency: currency,
        createdAt: createdAt,
        template: template,
        paymentMethodId: paymentMethodId,
        paymentMethodName: paymentMethodName,
        payments: List.from(payments),
        placeOfSupply: placeOfSupply,
        reverseCharge: reverseCharge,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'client': client?.toJson(),
        'invoiceDate': invoiceDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'status': status.index,
        'subject': subject,
        'notes': notes,
        'terms': terms,
        'globalDiscountPercent': globalDiscountPercent,
        'globalDiscountFlat': globalDiscountFlat,
        'currency': currency,
        'createdAt': createdAt.toIso8601String(),
        'template': template?.name,
        'paymentMethodId': paymentMethodId,
        'paymentMethodName': paymentMethodName,
        'payments': payments.map((p) => p.toJson()).toList(),
        'placeOfSupply': placeOfSupply,
        'reverseCharge': reverseCharge,
      };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'],
        invoiceNumber: json['invoiceNumber'],
        client:
            json['client'] != null ? Client.fromJson(json['client']) : null,
        invoiceDate: DateTime.parse(json['invoiceDate']),
        dueDate: DateTime.parse(json['dueDate']),
        items: (json['items'] as List)
            .map((e) => LineItem.fromJson(e))
            .toList(),
        status: InvoiceStatus.values[json['status'] ?? 0],
        subject: json['subject'],
        notes: json['notes'],
        terms: json['terms'],
        globalDiscountPercent:
            (json['globalDiscountPercent'] as num?)?.toDouble() ?? 0,
        globalDiscountFlat:
            (json['globalDiscountFlat'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] ?? 'INR',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        template: json['template'] != null
            ? InvoiceTemplate.values.firstWhere(
                (e) => e.name == json['template'],
                orElse: () => InvoiceTemplate.classic)
            : null,
        paymentMethodId: json['paymentMethodId'],
        paymentMethodName: json['paymentMethodName'],
        payments: (json['payments'] as List<dynamic>?)
                ?.map((e) => PartialPayment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        placeOfSupply: json['placeOfSupply'] as String?,
        reverseCharge: json['reverseCharge'] as bool? ?? false,
      );
}
