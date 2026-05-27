import 'package:flutter/material.dart';
import '../models/subscription_limits.dart';
import '../utils/app_theme.dart';

/// Shows a modal bottom sheet explaining why an action is blocked and
/// prompting the user to upgrade. Returns true if the user tapped Upgrade.
Future<bool> showPaywallSheet(BuildContext context, LimitInfo info) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaywallSheet(info: info),
  );
  return result == true;
}

class _PaywallSheet extends StatelessWidget {
  final LimitInfo info;
  const _PaywallSheet({required this.info});

  @override
  Widget build(BuildContext context) {
    final requiredTier = info.requiredTier;
    final price = tierPrices[requiredTier]!;
    final tierName = _tierName(requiredTier);
    final tierColor = _tierColor(requiredTier);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_featureIcon(info.type), color: tierColor, size: 30),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            info.title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            info.description,
            style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Plan badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tierColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, color: tierColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$tierName Plan',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: tierColor),
                      ),
                      if (price.yearlyRupees > 0)
                        Text(
                          '₹${price.yearlyRupees}/year  ·  ₹${price.monthlyRupees}/month',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Feature bullets for required tier
          ..._tierFeatures(requiredTier).map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: tierColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textPrimary)),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 24),

          // Upgrade button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: tierColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Upgrade to $tierName',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Maybe later',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  static String _tierName(SubscriptionTier t) {
    switch (t) {
      case SubscriptionTier.free:    return 'Free';
      case SubscriptionTier.lite:    return 'Lite';
      case SubscriptionTier.pro:     return 'Pro';
      case SubscriptionTier.premium: return 'Premium';
    }
  }

  static Color _tierColor(SubscriptionTier t) {
    switch (t) {
      case SubscriptionTier.free:    return Colors.grey;
      case SubscriptionTier.lite:    return const Color(0xFF0288D1);
      case SubscriptionTier.pro:     return const Color(0xFF7B1FA2);
      case SubscriptionTier.premium: return const Color(0xFFE65100);
    }
  }

  static IconData _featureIcon(LimitType t) {
    switch (t) {
      case LimitType.monthlyInvoices: return Icons.receipt_long;
      case LimitType.clients:         return Icons.people;
      case LimitType.serviceItems:    return Icons.inventory_2;
      case LimitType.templates:       return Icons.style;
      case LimitType.paymentMethods:  return Icons.account_balance_wallet;
      case LimitType.multiCurrency:   return Icons.currency_exchange;
      case LimitType.partialPayments: return Icons.payments;
      case LimitType.driveSync:       return Icons.cloud_sync;
      case LimitType.customPrefix:      return Icons.edit_note;
      case LimitType.messageTemplates:  return Icons.chat_outlined;
      case LimitType.gstReports:        return Icons.summarize_outlined;
    }
  }

  static List<String> _tierFeatures(SubscriptionTier t) {
    switch (t) {
      case SubscriptionTier.lite:
        return [
          '50 invoices per month',
          '50 clients',
          'Google Drive sync & backup',
          '3 invoice templates',
          'Partial payments tracking',
        ];
      case SubscriptionTier.pro:
        return [
          'Unlimited invoices & clients',
          'All 5 invoice templates',
          'Multi-currency support',
          'Custom invoice prefix',
          'Unlimited payment methods',
        ];
      case SubscriptionTier.premium:
        return [
          'Everything in Pro',
          'Recurring invoices',
          'Multiple business profiles',
          'Revenue analytics',
          'Priority verification (48hr)',
        ];
      default:
        return [];
    }
  }
}
