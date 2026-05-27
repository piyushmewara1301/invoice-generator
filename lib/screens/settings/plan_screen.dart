import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_limits.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current =
        context.watch<AppProvider>().profile.subscriptionTier;
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _CurrentPlanBanner(tier: current),
          const SizedBox(height: 20),
          ...SubscriptionTier.values.where((tier) {
            // Hide ineligible tiers for upgrade
            if (tier == current) return true; // Always show current
            return provider.canUpgradeTo(tier);
          }).map(
            (tier) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlanCard(tier: tier, isCurrentPlan: tier == current),
            ),
          ),
          const SizedBox(height: 8),
          const _BillingNote(),
        ],
      ),
    );
  }
}

// ── Current plan banner ───────────────────────────────────────────────────────

class _CurrentPlanBanner extends StatelessWidget {
  final SubscriptionTier tier;
  const _CurrentPlanBanner({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    final price = tierPrices[tier]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan: ${_tierName(tier)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                price.yearlyRupees == 0
                    ? const Text('Free forever',
                        style: TextStyle(color: Colors.white70, fontSize: 12))
                    : Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('50% OFF',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                          Text(
                            '₹${price.yearlyRupees * 2}/yr',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white54),
                          ),
                          Text(
                            '₹${price.yearlyRupees}/yr  ·  ₹${price.monthlyRupees}/mo',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final bool isCurrentPlan;
  const _PlanCard({required this.tier, required this.isCurrentPlan});

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    final price = tierPrices[tier]!;
    final features = _features(tier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentPlan ? color : Colors.transparent,
          width: isCurrentPlan ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_tierIcon(tier), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_tierName(tier),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: color)),
                          if (isCurrentPlan) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Current',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      price.yearlyRupees == 0
                          ? const Text('Free forever',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary))
                          : Wrap(
                              spacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('50% OFF',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800)),
                                ),
                                Text(
                                  '₹${price.yearlyRupees * 2}/yr',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      decoration: TextDecoration.lineThrough),
                                ),
                                Text(
                                  '₹${price.yearlyRupees}/yr  ·  ₹${price.monthlyRupees}/mo',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: features
                  .map((f) => _FeatureRow(
                        text: f.text,
                        included: f.included,
                        color: color,
                      ))
                  .toList(),
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.all(16),
            child: isCurrentPlan
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Current Plan',
                        style: TextStyle(color: color)),
                  )
                : _buildUpgradeButton(context, tier, color),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(
    BuildContext context,
    SubscriptionTier tier,
    Color color,
  ) {
    final provider = context.watch<AppProvider>();
    final currentTier = provider.profile.subscriptionTier;
    final canUpgrade = provider.canUpgradeTo(tier);

    if (!canUpgrade) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          currentTier == SubscriptionTier.premium
              ? 'Premium plan locked'
              : 'Cannot downgrade',
          style: TextStyle(
            color: color.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _handleUpgrade(context, tier),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
      label: Text(
        currentTier == SubscriptionTier.free ? 'Subscribe' : 'Upgrade',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _handleUpgrade(BuildContext context, SubscriptionTier tier) {
    showDialog(
      context: context,
      builder: (ctx) => _PurchaseDialog(tier: tier),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final bool included;
  final Color color;
  const _FeatureRow(
      {required this.text, required this.included, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 16,
            color: included ? color : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13,
                  color: included
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Billing note ──────────────────────────────────────────────────────────────

class _BillingNote extends StatelessWidget {
  const _BillingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Paid plans (Lite, Pro, Premium) are now available! Subscribe directly from this screen via Google Play. Annual subscriptions will auto-renew each year.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _tierName(SubscriptionTier t) {
  switch (t) {
    case SubscriptionTier.free:    return 'Free';
    case SubscriptionTier.lite:    return 'Lite';
    case SubscriptionTier.pro:     return 'Pro';
    case SubscriptionTier.premium: return 'Premium';
  }
}

Color _tierColor(SubscriptionTier t) {
  switch (t) {
    case SubscriptionTier.free:    return const Color(0xFF546E7A);
    case SubscriptionTier.lite:    return const Color(0xFF0288D1);
    case SubscriptionTier.pro:     return const Color(0xFF7B1FA2);
    case SubscriptionTier.premium: return const Color(0xFFE65100);
  }
}

IconData _tierIcon(SubscriptionTier t) {
  switch (t) {
    case SubscriptionTier.free:    return Icons.free_breakfast_outlined;
    case SubscriptionTier.lite:    return Icons.bolt_outlined;
    case SubscriptionTier.pro:     return Icons.rocket_launch_outlined;
    case SubscriptionTier.premium: return Icons.workspace_premium;
  }
}

// ── Feature list per plan ─────────────────────────────────────────────────────

class _F {
  final String text;
  final bool included;
  const _F(this.text, {required this.included});
}

List<_F> _features(SubscriptionTier t) {
  switch (t) {
    case SubscriptionTier.free:
      return [
        _F('5 invoices / month', included: true),
        _F('10 clients', included: true),
        _F('1 invoice template', included: true),
        _F('PDF export', included: true),
        _F('Google Drive sync', included: false),
        _F('Partial payments', included: false),
        _F('Multi-currency', included: false),
      ];
    case SubscriptionTier.lite:
      return [
        _F('50 invoices / month', included: true),
        _F('50 clients', included: true),
        _F('3 invoice templates', included: true),
        _F('Google Drive sync & backup', included: true),
        _F('Partial payments', included: true),
        _F('Multi-currency', included: false),
        _F('Custom invoice prefix', included: false),
      ];
    case SubscriptionTier.pro:
      return [
        _F('Unlimited invoices & clients', included: true),
        _F('All 5 invoice templates', included: true),
        _F('Multi-currency support', included: true),
        _F('Custom invoice prefix', included: true),
        _F('Unlimited payment methods', included: true),
        _F('Recurring invoices', included: false),
        _F('Multiple business profiles', included: false),
      ];
    case SubscriptionTier.premium:
      return [
        _F('Everything in Pro', included: true),
        _F('Recurring invoices', included: true),
        _F('Multiple business profiles (3)', included: true),
        _F('Revenue analytics dashboard', included: true),
        _F('Priority verification (48hr)', included: true),
        _F('CSV / Excel export', included: true),
        _F('Priority support', included: true),
      ];
  }
}

// ── Purchase Dialog ───────────────────────────────────────────────────────────

class _PurchaseDialog extends StatefulWidget {
  final SubscriptionTier tier;
  const _PurchaseDialog({required this.tier});

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final price = tierPrices[widget.tier]!;
    return AlertDialog(
      title: Text('Upgrade to ${_tierName(widget.tier)}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₹${price.yearlyRupees}/year (₹${price.monthlyRupees}/month)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your subscription will auto-renew each year. You can cancel anytime from Google Play.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _handlePurchase,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Subscribe'),
        ),
      ],
    );
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final appProvider = context.read<AppProvider>();
      await appProvider.purchaseSubscription(widget.tier);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully upgraded to ${_tierName(widget.tier)}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Purchase failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
