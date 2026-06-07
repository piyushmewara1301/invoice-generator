import 'package:flutter/material.dart';

class Expense {
  final String id;
  String title;
  String category;
  double amount;
  DateTime date;
  String? notes;
  bool isRecurring;
  String currency;
  DateTime createdAt;
  String? createdBy;
  String? lastEditedBy;
  DateTime? lastEditedAt;

  /// Base-64 encoded JPEG receipt photo, or null if not attached.
  String? receiptImageBase64;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.notes,
    this.isRecurring = false,
    this.currency = 'INR',
    DateTime? createdAt,
    this.createdBy,
    this.lastEditedBy,
    this.lastEditedAt,
    this.receiptImageBase64,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'isRecurring': isRecurring,
        'currency': currency,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'lastEditedBy': lastEditedBy,
        'lastEditedAt': lastEditedAt?.toIso8601String(),
        'receiptImageBase64': receiptImageBase64,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(json['date'] as String),
        notes: json['notes'] as String?,
        isRecurring: json['isRecurring'] as bool? ?? false,
        currency: json['currency'] as String? ?? 'INR',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        createdBy: json['createdBy'] as String?,
        lastEditedBy: json['lastEditedBy'] as String?,
        lastEditedAt: json['lastEditedAt'] != null
            ? DateTime.tryParse(json['lastEditedAt'] as String)
            : null,
        receiptImageBase64: json['receiptImageBase64'] as String?,
      );
}

// ── Category metadata ─────────────────────────────────────────────────────────

const expenseCategories = [
  'Salary',
  'Rent',
  'Electricity',
  'Water',
  'Gas',
  'Internet',
  'Office Supplies',
  'Travel',
  'Other',
];

IconData expenseCategoryIcon(String category) {
  switch (category) {
    case 'Salary':
      return Icons.people_outline;
    case 'Rent':
      return Icons.home_outlined;
    case 'Electricity':
      return Icons.bolt_outlined;
    case 'Water':
      return Icons.water_drop_outlined;
    case 'Gas':
      return Icons.local_fire_department_outlined;
    case 'Internet':
      return Icons.wifi_outlined;
    case 'Office Supplies':
      return Icons.inventory_2_outlined;
    case 'Travel':
      return Icons.directions_car_outlined;
    case 'Other':
      return Icons.receipt_long_outlined;
    default:
      // Custom category — use a generic label icon
      return Icons.label_outlined;
  }
}

// Palette cycled for custom (non-predefined) categories, chosen to avoid
// the colours already used by the built-in set.
const _customCategoryPalette = [
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFF16A34A),
  Color(0xFFDC2626),
  Color(0xFF9333EA),
  Color(0xFF0284C7),
  Color(0xFFD97706),
  Color(0xFF15803D),
];

Color expenseCategoryColor(String category) {
  switch (category) {
    case 'Salary':
      return const Color(0xFFEF4444);
    case 'Rent':
      return const Color(0xFF2563EB);
    case 'Electricity':
      return const Color(0xFFF59E0B);
    case 'Water':
      return const Color(0xFF06B6D4);
    case 'Gas':
      return const Color(0xFFF97316);
    case 'Internet':
      return const Color(0xFF8B5CF6);
    case 'Office Supplies':
      return const Color(0xFF10B981);
    case 'Travel':
      return const Color(0xFF64748B);
    case 'Other':
      return const Color(0xFF94A3B8);
    default:
      // Custom category — deterministic color based on name so the same
      // category always renders the same color across devices.
      return _customCategoryPalette[
          category.hashCode.abs() % _customCategoryPalette.length];
  }
}
