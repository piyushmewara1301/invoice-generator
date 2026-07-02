import '../models/business_profile.dart';
import '../models/invoice.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LateFeeResult — output of a single penalty calculation
// ─────────────────────────────────────────────────────────────────────────────

enum LateFeeStatus {
  disabled,     // feature not enabled by business
  notOverdue,   // invoice not past due date
  inGrace,      // overdue but within the grace period
  applicable,   // penalty accruing
}

class LateFeeResult {
  final LateFeeStatus status;
  final double amount;        // penalty in invoice currency
  final int daysOverdue;      // calendar days past due date
  final int billableDays;     // daysOverdue − grace period
  final double monthlyRate;   // % per month used
  final double outstanding;   // base amount the rate is applied to

  const LateFeeResult._({
    required this.status,
    required this.amount,
    required this.daysOverdue,
    required this.billableDays,
    required this.monthlyRate,
    required this.outstanding,
  });

  bool get hasPenalty => status == LateFeeStatus.applicable && amount > 0;

  /// Human-readable label for why the penalty is zero.
  String? get zeroReason {
    switch (status) {
      case LateFeeStatus.disabled:
        return 'Late fee not enabled';
      case LateFeeStatus.notOverdue:
        return 'Invoice not yet overdue';
      case LateFeeStatus.inGrace:
        return 'Within grace period ($daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue)';
      case LateFeeStatus.applicable:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LateFeeCalculator
// ─────────────────────────────────────────────────────────────────────────────

class LateFeeCalculator {
  /// Computes the accrued penalty for [invoice] using [profile] settings.
  ///
  /// Formula:  penalty = outstanding × (rate% / 100) × (billableDays / 30)
  /// where billableDays = max(0, daysOverdue − gracePeriodDays).
  static LateFeeResult forInvoice(Invoice invoice, BusinessProfile profile) {
    if (!profile.lateFeeEnabled) {
      return const LateFeeResult._(
        status: LateFeeStatus.disabled,
        amount: 0, daysOverdue: 0, billableDays: 0,
        monthlyRate: 0, outstanding: 0,
      );
    }

    final outstanding = invoice.amountRemaining;
    if (outstanding <= 0) {
      return const LateFeeResult._(
        status: LateFeeStatus.notOverdue,
        amount: 0, daysOverdue: 0, billableDays: 0,
        monthlyRate: 0, outstanding: 0,
      );
    }

    final today = DateTime.now();
    final due = DateTime(
        invoice.dueDate.year, invoice.dueDate.month, invoice.dueDate.day);
    final daysOverdue =
        DateTime(today.year, today.month, today.day).difference(due).inDays;

    if (daysOverdue <= 0) {
      return LateFeeResult._(
        status: LateFeeStatus.notOverdue,
        amount: 0, daysOverdue: 0, billableDays: 0,
        monthlyRate: profile.lateFeePercent, outstanding: outstanding,
      );
    }

    final billableDays =
        (daysOverdue - profile.gracePeriodDays).clamp(0, daysOverdue);
    if (billableDays == 0) {
      return LateFeeResult._(
        status: LateFeeStatus.inGrace,
        amount: 0,
        daysOverdue: daysOverdue,
        billableDays: 0,
        monthlyRate: profile.lateFeePercent,
        outstanding: outstanding,
      );
    }

    final monthsOverdue = billableDays / 30.0;
    final penalty = outstanding * (profile.lateFeePercent / 100) * monthsOverdue;

    return LateFeeResult._(
      status: LateFeeStatus.applicable,
      amount: penalty,
      daysOverdue: daysOverdue,
      billableDays: billableDays,
      monthlyRate: profile.lateFeePercent,
      outstanding: outstanding,
    );
  }

  /// Penalty for a hypothetical invoice — used for live previews in settings.
  static LateFeeResult preview({
    required double outstanding,
    required int daysOverdue,
    required double monthlyRatePercent,
    required int gracePeriodDays,
  }) {
    if (daysOverdue <= 0) {
      return LateFeeResult._(
        status: LateFeeStatus.notOverdue,
        amount: 0, daysOverdue: 0, billableDays: 0,
        monthlyRate: monthlyRatePercent, outstanding: outstanding,
      );
    }
    final billableDays =
        (daysOverdue - gracePeriodDays).clamp(0, daysOverdue);
    if (billableDays == 0) {
      return LateFeeResult._(
        status: LateFeeStatus.inGrace,
        amount: 0, daysOverdue: daysOverdue, billableDays: 0,
        monthlyRate: monthlyRatePercent, outstanding: outstanding,
      );
    }
    final penalty =
        outstanding * (monthlyRatePercent / 100) * (billableDays / 30.0);
    return LateFeeResult._(
      status: LateFeeStatus.applicable,
      amount: penalty,
      daysOverdue: daysOverdue,
      billableDays: billableDays,
      monthlyRate: monthlyRatePercent,
      outstanding: outstanding,
    );
  }
}
