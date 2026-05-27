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
}

// ── Pricing ───────────────────────────────────────────────────────────────────

class TierPrice {
  final int yearlyRupees;
  final int monthlyRupees;
  const TierPrice(this.yearlyRupees, this.monthlyRupees);
}

const tierPrices = {
  SubscriptionTier.free:    TierPrice(0,    0),
  SubscriptionTier.lite:    TierPrice(249,  29),
  SubscriptionTier.pro:     TierPrice(699,  79),
  SubscriptionTier.premium: TierPrice(1299, 149),
};

// ── Limits (-1 = unlimited) ───────────────────────────────────────────────────

class SubscriptionLimits {
  // Hard numeric caps
  static const monthlyInvoices = {
    SubscriptionTier.free:    5,
    SubscriptionTier.lite:    50,
    SubscriptionTier.pro:     -1,
    SubscriptionTier.premium: -1,
  };

  static const clients = {
    SubscriptionTier.free:    10,
    SubscriptionTier.lite:    50,
    SubscriptionTier.pro:     -1,
    SubscriptionTier.premium: -1,
  };

  static const serviceItems = {
    SubscriptionTier.free:    10,
    SubscriptionTier.lite:    50,
    SubscriptionTier.pro:     -1,
    SubscriptionTier.premium: -1,
  };

  /// Max number of templates the user can pick from (1 = classic only).
  static const templates = {
    SubscriptionTier.free:    1,
    SubscriptionTier.lite:    3,
    SubscriptionTier.pro:     -1,
    SubscriptionTier.premium: -1,
  };

  static const paymentMethods = {
    SubscriptionTier.free:    1,
    SubscriptionTier.lite:    2,
    SubscriptionTier.pro:     -1,
    SubscriptionTier.premium: -1,
  };

  // Boolean feature gates
  static const multiCurrency = {
    SubscriptionTier.free:    false,
    SubscriptionTier.lite:    false,
    SubscriptionTier.pro:     true,
    SubscriptionTier.premium: true,
  };

  static const partialPayments = {
    SubscriptionTier.free:    false,
    SubscriptionTier.lite:    true,
    SubscriptionTier.pro:     true,
    SubscriptionTier.premium: true,
  };

  static const driveSync = {
    SubscriptionTier.free:    false,
    SubscriptionTier.lite:    true,
    SubscriptionTier.pro:     true,
    SubscriptionTier.premium: true,
  };

  static const customPrefix = {
    SubscriptionTier.free:    false,
    SubscriptionTier.lite:    false,
    SubscriptionTier.pro:     true,
    SubscriptionTier.premium: true,
  };

  static const messageTemplates = {
    SubscriptionTier.free:    false,
    SubscriptionTier.lite:    false,
    SubscriptionTier.pro:     false,
    SubscriptionTier.premium: true,
  };

  static const gstReports = {
    SubscriptionTier.free:    false,
    SubscriptionTier.lite:    false,
    SubscriptionTier.pro:     true,
    SubscriptionTier.premium: true,
  };

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static bool canUse(SubscriptionTier tier, LimitType feature) {
    switch (feature) {
      case LimitType.multiCurrency:   return multiCurrency[tier]!;
      case LimitType.partialPayments: return partialPayments[tier]!;
      case LimitType.driveSync:       return driveSync[tier]!;
      case LimitType.customPrefix:      return customPrefix[tier]!;
      case LimitType.messageTemplates:  return messageTemplates[tier]!;
      case LimitType.gstReports:        return gstReports[tier]!;
      default:
        final cap = _numericLimit(tier, feature);
        return cap == -1; // only makes sense for hard caps called as boolean
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
      case LimitType.messageTemplates:  return 'Custom message templates';
      case LimitType.gstReports:        return 'GST Reports';
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
        return 'Track partial payments and outstanding balances.';
      case LimitType.driveSync:
        return 'Sync and back up your data securely to Google Drive.';
      case LimitType.customPrefix:
        return 'Set a custom prefix for your invoice numbers.';
      case LimitType.messageTemplates:
        return 'Personalise the WhatsApp and email messages sent with every invoice.';
      case LimitType.gstReports:
        return 'Generate detailed GSTR-1 style reports with CGST/SGST/IGST splits, HSN/SAC summary and invoice register.';
    }
  }
}
