import 'business_profile.dart';

export 'business_profile.dart' show SubscriptionTier, SubscriptionTierX;

// ── What can be gated ─────────────────────────────────────────────────────────

enum LimitType {
  monthlyInvoices,
  clients,
  serviceItems,
  templates,
  paymentMethods,
  multiCurrency,
  partialPayments,
  driveSync,
  customPrefix,
  messageTemplates,
  gstReports,
  manageTeam,
  // New gates
  expenses,
  reports,
  quotations,
  creditNotes,
  recurringInvoices,
  inventory,
  categoryAnalytics,
  posScreen,
  bulkReminders,
}

// ── Pricing ───────────────────────────────────────────────────────────────────

class TierPrice {
  /// Actual price user pays (after 25 % launch discount).
  final int yearlyRupees;
  /// Approximate monthly equivalent of the yearly price.
  final int monthlyRupees;
  /// Original MRP shown crossed-out (≈ 25 % higher than yearlyRupees).
  final int mrpRupees;
  const TierPrice(this.yearlyRupees, this.monthlyRupees, this.mrpRupees);
}

// Pricing: MRP raised 25 % from previous prices; 25 % launch discount applied.
//   Free      ₹0
//   Lite      MRP ₹649  → ₹499/yr  (₹42/mo)
//   Pro       MRP ₹1,999 → ₹1,499/yr (₹125/mo)
//   Premium   MRP ₹3,999 → ₹2,999/yr (₹250/mo)
//   Enterprise MRP ₹12,999 → ₹9,999/yr (₹833/mo)
const tierPrices = {
  SubscriptionTier.free:       TierPrice(0,     0,     0),
  SubscriptionTier.lite:       TierPrice(499,   42,    649),
  SubscriptionTier.pro:        TierPrice(1499,  125,   1999),
  SubscriptionTier.premium:    TierPrice(2999,  250,   3999),
  SubscriptionTier.enterprise: TierPrice(9999,  833,   12999),
};

// ── Limits (-1 = unlimited) ───────────────────────────────────────────────────

class SubscriptionLimits {
  // Hard numeric caps
  static const monthlyInvoices = {
    SubscriptionTier.free:       5,
    SubscriptionTier.lite:       50,
    SubscriptionTier.pro:        -1,
    SubscriptionTier.premium:    -1,
    SubscriptionTier.enterprise: -1,
  };

  static const clients = {
    SubscriptionTier.free:       10,
    SubscriptionTier.lite:       50,
    SubscriptionTier.pro:        -1,
    SubscriptionTier.premium:    -1,
    SubscriptionTier.enterprise: -1,
  };

  static const serviceItems = {
    SubscriptionTier.free:       10,
    SubscriptionTier.lite:       50,
    SubscriptionTier.pro:        -1,
    SubscriptionTier.premium:    -1,
    SubscriptionTier.enterprise: -1,
  };

  /// Max number of templates the user can pick from (1 = classic only).
  static const templates = {
    SubscriptionTier.free:       1,
    SubscriptionTier.lite:       3,
    SubscriptionTier.pro:        -1,
    SubscriptionTier.premium:    -1,
    SubscriptionTier.enterprise: -1,
  };

  static const paymentMethods = {
    SubscriptionTier.free:       1,
    SubscriptionTier.lite:       2,
    SubscriptionTier.pro:        -1,
    SubscriptionTier.premium:    -1,
    SubscriptionTier.enterprise: -1,
  };

  // Boolean feature gates
  static const multiCurrency = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const partialPayments = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       true,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const driveSync = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       true,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const customPrefix = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const messageTemplates = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        false,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const gstReports = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const manageTeam = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        false,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  // Lite+ features
  static const expenses = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       true,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const reports = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       true,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const quotations = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       true,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  // Pro+ features
  static const creditNotes = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const recurringInvoices = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const inventory = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const categoryAnalytics = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const posScreen = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  static const bulkReminders = {
    SubscriptionTier.free:       false,
    SubscriptionTier.lite:       false,
    SubscriptionTier.pro:        true,
    SubscriptionTier.premium:    true,
    SubscriptionTier.enterprise: true,
  };

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static bool canUse(SubscriptionTier tier, LimitType feature) {
    switch (feature) {
      case LimitType.multiCurrency:      return multiCurrency[tier]!;
      case LimitType.partialPayments:    return partialPayments[tier]!;
      case LimitType.driveSync:          return driveSync[tier]!;
      case LimitType.customPrefix:       return customPrefix[tier]!;
      case LimitType.messageTemplates:   return messageTemplates[tier]!;
      case LimitType.gstReports:         return gstReports[tier]!;
      case LimitType.manageTeam:         return manageTeam[tier]!;
      case LimitType.expenses:           return expenses[tier]!;
      case LimitType.reports:            return reports[tier]!;
      case LimitType.quotations:         return quotations[tier]!;
      case LimitType.creditNotes:        return creditNotes[tier]!;
      case LimitType.recurringInvoices:  return recurringInvoices[tier]!;
      case LimitType.inventory:          return inventory[tier]!;
      case LimitType.categoryAnalytics:  return categoryAnalytics[tier]!;
      case LimitType.posScreen:          return posScreen[tier]!;
      case LimitType.bulkReminders:      return bulkReminders[tier]!;
      default:
        final cap = _numericLimit(tier, feature);
        return cap == -1;
    }
  }

  static int _numericLimit(SubscriptionTier tier, LimitType type) {
    switch (type) {
      case LimitType.monthlyInvoices: return monthlyInvoices[tier]!;
      case LimitType.clients:         return clients[tier]!;
      case LimitType.serviceItems:    return serviceItems[tier]!;
      case LimitType.templates:       return templates[tier]!;
      case LimitType.paymentMethods:  return paymentMethods[tier]!;
      default:                        return -1;
    }
  }

  /// Returns null if [count] is within the limit, otherwise the cap.
  static int? hitLimit(SubscriptionTier tier, LimitType type, int count) {
    final cap = _numericLimit(tier, type);
    if (cap == -1 || count < cap) return null;
    return cap;
  }

  /// Returns the minimum tier that unlocks [feature].
  static SubscriptionTier minTierFor(LimitType feature) {
    for (final tier in SubscriptionTier.values) {
      if (canUse(tier, feature)) return tier;
    }
    return SubscriptionTier.premium;
  }
}

// ── Limit info (passed to paywall) ────────────────────────────────────────────

class LimitInfo {
  final LimitType type;
  final int cap;
  final SubscriptionTier requiredTier;

  const LimitInfo({
    required this.type,
    required this.cap,
    required this.requiredTier,
  });

  factory LimitInfo.numeric(LimitType type, int cap) => LimitInfo(
        type: type,
        cap: cap,
        requiredTier: _nextTierWithMore(type, cap),
      );

  factory LimitInfo.feature(LimitType type, SubscriptionTier current) =>
      LimitInfo(
        type: type,
        cap: 0,
        requiredTier: SubscriptionLimits.minTierFor(type),
      );

  static SubscriptionTier _nextTierWithMore(LimitType type, int cap) {
    for (final tier in SubscriptionTier.values) {
      final c = SubscriptionLimits._numericLimit(tier, type);
      if (c == -1 || c > cap) return tier;
    }
    return SubscriptionTier.premium;
  }

  String get title {
    switch (type) {
      case LimitType.monthlyInvoices: return 'Invoice limit reached';
      case LimitType.clients:         return 'Client limit reached';
      case LimitType.serviceItems:    return 'Item limit reached';
      case LimitType.templates:       return 'Premium template';
      case LimitType.paymentMethods:  return 'Payment method limit';
      case LimitType.multiCurrency:   return 'Multi-currency';
      case LimitType.partialPayments: return 'Partial payments';
      case LimitType.driveSync:       return 'Drive sync';
      case LimitType.customPrefix:      return 'Custom invoice prefix';
      case LimitType.messageTemplates:    return 'Custom message templates';
      case LimitType.gstReports:         return 'GST Reports';
      case LimitType.manageTeam:         return 'Manage Team';
      case LimitType.expenses:           return 'Expense Tracking';
      case LimitType.reports:            return 'Reports & Analytics';
      case LimitType.quotations:         return 'Quotations & Estimates';
      case LimitType.creditNotes:        return 'Credit Notes';
      case LimitType.recurringInvoices:  return 'Recurring Invoices';
      case LimitType.inventory:          return 'Inventory Management';
      case LimitType.categoryAnalytics:  return 'Category Analytics';
      case LimitType.posScreen:          return 'Point of Sale';
      case LimitType.bulkReminders:      return 'Bulk Reminders';
    }
  }

  String get description {
    switch (type) {
      case LimitType.monthlyInvoices:
        return "You've used all $cap invoices this month on your current plan.";
      case LimitType.clients:
        return "You've reached the $cap client limit on your current plan.";
      case LimitType.serviceItems:
        return "You've reached the $cap item limit on your current plan.";
      case LimitType.templates:
        return 'This template is only available on higher plans.';
      case LimitType.paymentMethods:
        return "You've reached the $cap payment method limit.";
      case LimitType.multiCurrency:
        return 'Create invoices in any currency with a higher plan.';
      case LimitType.partialPayments:
        return 'Track partial payments and outstanding balances with a higher plan.';
      case LimitType.driveSync:
        return 'Sync and back up your data securely to Google Drive.';
      case LimitType.customPrefix:
        return 'Set a custom prefix for your invoice numbers.';
      case LimitType.messageTemplates:
        return 'Personalise the WhatsApp and email messages sent with every invoice.';
      case LimitType.gstReports:
        return 'Generate detailed GSTR-1 style reports with CGST/SGST/IGST splits, HSN/SAC summary and invoice register.';
      case LimitType.manageTeam:
        return 'Add employees and control exactly what each person can do in the app.';
      case LimitType.expenses:
        return 'Log and categorise every business expense with receipt photos.';
      case LimitType.reports:
        return 'Access P&L, age-wise outstanding, and client statement reports.';
      case LimitType.quotations:
        return 'Send quotations/estimates to clients and convert them to invoices in one tap.';
      case LimitType.creditNotes:
        return 'Issue credit notes against any sent or paid invoice.';
      case LimitType.recurringInvoices:
        return 'Auto-generate invoices on a weekly, monthly, or yearly schedule.';
      case LimitType.inventory:
        return 'Track stock levels and get low-stock alerts for your products.';
      case LimitType.categoryAnalytics:
        return 'See revenue breakdown and trends by item category.';
      case LimitType.posScreen:
        return 'Quickly bill customers from your product catalog with the POS screen.';
      case LimitType.bulkReminders:
        return 'Select multiple invoices and send WhatsApp payment reminders in one action.';
    }
  }
}
