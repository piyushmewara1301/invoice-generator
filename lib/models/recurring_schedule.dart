import 'package:flutter/material.dart';
import 'line_item.dart';

enum RecurringFrequency { weekly, biWeekly, monthly, quarterly, yearly }

extension RecurringFrequencyX on RecurringFrequency {
  String get label {
    switch (this) {
      case RecurringFrequency.weekly:    return 'Every Week';
      case RecurringFrequency.biWeekly:  return 'Every 2 Weeks';
      case RecurringFrequency.monthly:   return 'Every Month';
      case RecurringFrequency.quarterly: return 'Every 3 Months';
      case RecurringFrequency.yearly:    return 'Every Year';
    }
  }

  IconData get icon {
    switch (this) {
      case RecurringFrequency.weekly:    return Icons.date_range_outlined;
      case RecurringFrequency.biWeekly:  return Icons.view_week_outlined;
      case RecurringFrequency.monthly:   return Icons.calendar_month_outlined;
      case RecurringFrequency.quarterly: return Icons.event_repeat_outlined;
      case RecurringFrequency.yearly:    return Icons.event_outlined;
    }
  }

  /// Returns the next scheduled date after [from].
  DateTime nextDate(DateTime from) {
    switch (this) {
      case RecurringFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.biWeekly:
        return from.add(const Duration(days: 14));
      case RecurringFrequency.monthly:
        return _addMonths(from, 1);
      case RecurringFrequency.quarterly:
        return _addMonths(from, 3);
      case RecurringFrequency.yearly:
        return DateTime(from.year + 1, from.month, from.day);
    }
  }

  static DateTime _addMonths(DateTime d, int months) {
    final newMonth = d.month + months;
    final year = d.year + (newMonth - 1) ~/ 12;
    final month = ((newMonth - 1) % 12) + 1;
    final day = d.day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}

// ── Quotation status (reused for quotation documents) ────────────────────────

enum QuotationStatus { draft, sent, approved, declined }

extension QuotationStatusX on QuotationStatus {
  String get label {
    switch (this) {
      case QuotationStatus.draft:    return 'Draft';
      case QuotationStatus.sent:     return 'Sent';
      case QuotationStatus.approved: return 'Approved';
      case QuotationStatus.declined: return 'Declined';
    }
  }

  Color get color {
    switch (this) {
      case QuotationStatus.draft:    return const Color(0xFF64748B);
      case QuotationStatus.sent:     return const Color(0xFF2563EB);
      case QuotationStatus.approved: return const Color(0xFF16A34A);
      case QuotationStatus.declined: return const Color(0xFFEF4444);
    }
  }
}

// ── Recurring schedule ────────────────────────────────────────────────────────

class RecurringSchedule {
  final String id;
  String title;
  String? clientId;
  String? clientName;
  List<LineItem> items;
  String currency;
  double globalDiscountPercent;
  double globalDiscountFlat;
  String? notes;
  String? terms;
  String? paymentMethodId;
  String? paymentMethodName;
  RecurringFrequency frequency;
  final DateTime startDate;
  DateTime? endDate;
  DateTime nextGenerationDate;
  bool isActive;
  final DateTime createdAt;
  int generatedCount;
  /// Invoice due date = invoice date + daysTillDue days.
  int daysTillDue;

  RecurringSchedule({
    required this.id,
    required this.title,
    this.clientId,
    this.clientName,
    required this.items,
    required this.currency,
    this.globalDiscountPercent = 0,
    this.globalDiscountFlat = 0,
    this.notes,
    this.terms,
    this.paymentMethodId,
    this.paymentMethodName,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextGenerationDate,
    this.isActive = true,
    DateTime? createdAt,
    this.generatedCount = 0,
    this.daysTillDue = 30,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'clientId': clientId,
        'clientName': clientName,
        'items': items.map((i) => i.toJson()).toList(),
        'currency': currency,
        'globalDiscountPercent': globalDiscountPercent,
        'globalDiscountFlat': globalDiscountFlat,
        'notes': notes,
        'terms': terms,
        'paymentMethodId': paymentMethodId,
        'paymentMethodName': paymentMethodName,
        'frequency': frequency.name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'nextGenerationDate': nextGenerationDate.toIso8601String(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'generatedCount': generatedCount,
        'daysTillDue': daysTillDue,
      };

  factory RecurringSchedule.fromJson(Map<String, dynamic> j) =>
      RecurringSchedule(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        clientId: j['clientId'] as String?,
        clientName: j['clientName'] as String?,
        items: (j['items'] as List? ?? [])
            .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        currency: j['currency'] as String? ?? 'INR',
        globalDiscountPercent:
            (j['globalDiscountPercent'] as num?)?.toDouble() ?? 0,
        globalDiscountFlat:
            (j['globalDiscountFlat'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String?,
        terms: j['terms'] as String?,
        paymentMethodId: j['paymentMethodId'] as String?,
        paymentMethodName: j['paymentMethodName'] as String?,
        frequency: RecurringFrequency.values.firstWhere(
          (f) => f.name == j['frequency'],
          orElse: () => RecurringFrequency.monthly,
        ),
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] != null
            ? DateTime.parse(j['endDate'] as String)
            : null,
        nextGenerationDate:
            DateTime.parse(j['nextGenerationDate'] as String),
        isActive: j['isActive'] as bool? ?? true,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : null,
        generatedCount: j['generatedCount'] as int? ?? 0,
        daysTillDue: j['daysTillDue'] as int? ?? 30,
      );
}
