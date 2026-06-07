import 'package:flutter/material.dart';

// ── Item ─────────────────────────────────────────────────────────────────────

class PurchaseBillItem {
  String id;
  String description;
  double quantity;
  double rate;
  /// GST % on this line (0, 5, 12, 18, 28).
  double taxPercent;

  PurchaseBillItem({
    required this.id,
    required this.description,
    this.quantity = 1,
    required this.rate,
    this.taxPercent = 0,
  });

  double get subtotal  => quantity * rate;
  double get taxAmount => subtotal * taxPercent / 100;
  double get total     => subtotal + taxAmount;

  PurchaseBillItem copy() => PurchaseBillItem(
        id: id,
        description: description,
        quantity: quantity,
        rate: rate,
        taxPercent: taxPercent,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'quantity': quantity,
        'rate': rate,
        'taxPercent': taxPercent,
      };

  factory PurchaseBillItem.fromJson(Map<String, dynamic> j) => PurchaseBillItem(
        id: j['id'] as String,
        description: j['description'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
        taxPercent: (j['taxPercent'] as num?)?.toDouble() ?? 0,
      );
}

// ── Status ───────────────────────────────────────────────────────────────────

enum PurchaseBillStatus { unpaid, partiallyPaid, paid }

extension PurchaseBillStatusX on PurchaseBillStatus {
  String get label {
    switch (this) {
      case PurchaseBillStatus.unpaid:        return 'Unpaid';
      case PurchaseBillStatus.partiallyPaid: return 'Partial';
      case PurchaseBillStatus.paid:          return 'Paid';
    }
  }

  Color get color {
    switch (this) {
      case PurchaseBillStatus.unpaid:        return const Color(0xFFEF4444);
      case PurchaseBillStatus.partiallyPaid: return const Color(0xFFF97316);
      case PurchaseBillStatus.paid:          return const Color(0xFF10B981);
    }
  }

  IconData get icon {
    switch (this) {
      case PurchaseBillStatus.unpaid:        return Icons.pending_outlined;
      case PurchaseBillStatus.partiallyPaid: return Icons.timelapse_outlined;
      case PurchaseBillStatus.paid:          return Icons.check_circle_outline;
    }
  }
}

// ── Bill ─────────────────────────────────────────────────────────────────────

class PurchaseBill {
  final String id;
  String vendorName;
  String? vendorGstin;
  String? vendorPhone;
  String? vendorEmail;
  /// Vendor's own invoice/bill number (for reconciliation).
  String? billNumber;
  DateTime billDate;
  DateTime? dueDate;
  List<PurchaseBillItem> items;
  PurchaseBillStatus status;
  /// Cash already paid towards this bill.
  double amountPaid;
  String? notes;
  DateTime createdAt;
  String? createdBy;
  String? lastEditedBy;
  DateTime? lastEditedAt;

  /// Whether a local push notification should be scheduled for this bill.
  bool reminderEnabled;
  /// Days before the due date to fire the reminder (0 = on due date).
  int reminderDaysBefore;
  /// Base64-encoded JPEG of the attached bill/receipt image.
  String? receiptImageBase64;

  PurchaseBill({
    required this.id,
    required this.vendorName,
    this.vendorGstin,
    this.vendorPhone,
    this.vendorEmail,
    this.billNumber,
    required this.billDate,
    this.dueDate,
    List<PurchaseBillItem>? items,
    this.status = PurchaseBillStatus.unpaid,
    this.amountPaid = 0,
    this.notes,
    DateTime? createdAt,
    this.createdBy,
    this.lastEditedBy,
    this.lastEditedAt,
    this.reminderEnabled = false,
    this.reminderDaysBefore = 1,
    this.receiptImageBase64,
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now();

  double get subtotal   => items.fold(0, (s, i) => s + i.subtotal);
  double get totalTax   => items.fold(0, (s, i) => s + i.taxAmount);
  double get grandTotal => subtotal + totalTax;
  double get amountDue  => (grandTotal - amountPaid).clamp(0.0, double.infinity);

  /// Input Tax Credit claimable = GST paid on this purchase.
  double get itcAmount => totalTax;

  bool get isOverdue =>
      status != PurchaseBillStatus.paid &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorName': vendorName,
        'vendorGstin': vendorGstin,
        'vendorPhone': vendorPhone,
        'vendorEmail': vendorEmail,
        'billNumber': billNumber,
        'billDate': billDate.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'status': status.index,
        'amountPaid': amountPaid,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'lastEditedBy': lastEditedBy,
        'lastEditedAt': lastEditedAt?.toIso8601String(),
        'reminderEnabled': reminderEnabled,
        'reminderDaysBefore': reminderDaysBefore,
        'receiptImageBase64': receiptImageBase64,
      };

  factory PurchaseBill.fromJson(Map<String, dynamic> j) => PurchaseBill(
        id: j['id'] as String,
        vendorName: j['vendorName'] as String? ?? '',
        vendorGstin: j['vendorGstin'] as String?,
        vendorPhone: j['vendorPhone'] as String?,
        vendorEmail: j['vendorEmail'] as String?,
        billNumber: j['billNumber'] as String?,
        billDate: DateTime.parse(j['billDate'] as String),
        dueDate: j['dueDate'] != null
            ? DateTime.tryParse(j['dueDate'] as String)
            : null,
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => PurchaseBillItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        status: PurchaseBillStatus.values[(j['status'] as int?) ?? 0],
        amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
        createdBy: j['createdBy'] as String?,
        lastEditedBy: j['lastEditedBy'] as String?,
        lastEditedAt: j['lastEditedAt'] != null
            ? DateTime.tryParse(j['lastEditedAt'] as String)
            : null,
        reminderEnabled: j['reminderEnabled'] as bool? ?? false,
        reminderDaysBefore: j['reminderDaysBefore'] as int? ?? 1,
        receiptImageBase64: j['receiptImageBase64'] as String?,
      );
}
