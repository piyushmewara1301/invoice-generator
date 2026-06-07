import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/subscription_limits.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AppProvider>().profile.subscriptionTier;
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _CurrentPlanBanner(tier: current),
          const SizedBox(height: 8),
          _DiscountBanner(),
          const SizedBox(height: 12),
          ...SubscriptionTier.values.where((tier) {
            if (tier == current) return true;
            return provider.canUpgradeTo(tier);
          }).map(
            (tier) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: tier == SubscriptionTier.enterprise
                  ? _EnterpriseCard(isCurrentPlan: tier == current)
                  : _PlanCard(tier: tier, isCurrentPlan: tier == current),
            ),
          ),
          const SizedBox(height: 8),
          const _BillingNote(),
        ],
      ),
    );
  }
}

// ── Discount banner ───────────────────────────────────────────────────────────

class _DiscountBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Text('🎉', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Launch Offer — 25% OFF on all plans! Limited time.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
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
          Icon(_tierIcon(tier), color: Colors.white, size: 32),
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
                    : _PriceRow(price: price, textColor: Colors.white70),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared price row (MRP crossed out + sale price) ───────────────────────────

class _PriceRow extends StatelessWidget {
  final TierPrice price;
  final Color textColor;
  const _PriceRow({required this.price, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text('25% OFF',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800)),
        ),
        Text(
          '₹${price.mrpRupees}/yr',
          style: TextStyle(
              color: textColor,
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              decorationColor: textColor),
        ),
        Text(
          '₹${price.yearlyRupees}/yr  ·  ₹${price.monthlyRupees}/mo',
          style: TextStyle(color: textColor, fontSize: 12),
        ),
      ],
    );
  }
}

// ── Standard plan card ────────────────────────────────────────────────────────

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
        color: AppTheme.card(context),
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
                          ? Text('Free forever',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.subtext(context)))
                          : _PriceRow(
                              price: price,
                              textColor: AppTheme.subtext(context)),
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
                : _UpgradeButton(tier: tier, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Enterprise card ───────────────────────────────────────────────────────────

class _EnterpriseCard extends StatelessWidget {
  final bool isCurrentPlan;
  const _EnterpriseCard({required this.isCurrentPlan});

  @override
  Widget build(BuildContext context) {
    final price = tierPrices[SubscriptionTier.enterprise]!;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF2D1B69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentPlan
              ? Colors.white.withValues(alpha: 0.6)
              : const Color(0xFF4338CA).withValues(alpha: 0.5),
          width: isCurrentPlan ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.business_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Enterprise',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Colors.white)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('NEW',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                          if (isCurrentPlan) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
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
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('25% OFF',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                          Text(
                            '₹${price.mrpRupees}/yr',
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white38),
                          ),
                          Text(
                            '₹${price.yearlyRupees}/yr  ·  ₹${price.monthlyRupees}/mo',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: _features(SubscriptionTier.enterprise)
                  .map((f) => _EntFeatureRow(text: f.text))
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
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Current Plan',
                        style: TextStyle(color: Colors.white70)),
                  )
                : _EnterpriseContactButton(),
          ),
        ],
      ),
    );
  }
}

class _EntFeatureRow extends StatelessWidget {
  final String text;
  const _EntFeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: Color(0xFF818CF8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterpriseContactButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _contactSales(context),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      icon: const Icon(Icons.mail_outline, size: 16),
      label: const Text('Contact Sales',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  void _contactSales(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'enterprise@billbook.app',
      queryParameters: {
        'subject': 'BillBook Enterprise Subscription',
        'body':
            'Hi BillBook Team,\n\nI am interested in the Enterprise plan.\n\nBusiness Name: \nNumber of Users: \nContact: \n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact us at enterprise@billbook.app'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// ── Upgrade button (non-enterprise plans) ─────────────────────────────────────

class _UpgradeButton extends StatelessWidget {
  final SubscriptionTier tier;
  final Color color;
  const _UpgradeButton({required this.tier, required this.color});

  @override
  Widget build(BuildContext context) {
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
          currentTier.index >= SubscriptionTier.premium.index
              ? 'Upgrade to Enterprise'
              : 'Cannot downgrade',
          style: TextStyle(color: color.withValues(alpha: 0.5)),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (ctx) => _PurchaseDialog(tier: tier),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
      label: Text(
        currentTier == SubscriptionTier.free ? 'Subscribe' : 'Upgrade',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
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
                      ? AppTheme.onCard(context)
                      : AppTheme.subtext(context)),
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
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.subtext(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All plans billed annually via Google Play. 25% launch discount applied automatically. Subscriptions auto-renew each year — cancel anytime from Google Play settings.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.subtext(context), height: 1.5),
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
    case SubscriptionTier.free:       return 'Free';
    case SubscriptionTier.lite:       return 'Lite';
    case SubscriptionTier.pro:        return 'Pro';
    case SubscriptionTier.premium:    return 'Premium';
    case SubscriptionTier.enterprise: return 'Enterprise';
  }
}

Color _tierColor(SubscriptionTier t) {
  switch (t) {
    case SubscriptionTier.free:       return const Color(0xFF546E7A);
    case SubscriptionTier.lite:       return const Color(0xFF0288D1);
    case SubscriptionTier.pro:        return const Color(0xFF7B1FA2);
    case SubscriptionTier.premium:    return const Color(0xFFE65100);
    case SubscriptionTier.enterprise: return const Color(0xFF4338CA);
  }
}

IconData _tierIcon(SubscriptionTier t) {
  switch (t) {
    case SubscriptionTier.free:       return Icons.free_breakfast_outlined;
    case SubscriptionTier.lite:       return Icons.bolt_outlined;
    case SubscriptionTier.pro:        return Icons.rocket_launch_outlined;
    case SubscriptionTier.premium:    return Icons.workspace_premium;
    case SubscriptionTier.enterprise: return Icons.business_outlined;
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
        _F('10 clients · 10 items', included: true),
        _F('Classic template only', included: true),
        _F('1 payment method', included: true),
        _F('Google Drive sync', included: false),
        _F('Partial payments & expenses', included: false),
        _F('Reports & analytics', included: false),
      ];
    case SubscriptionTier.lite:
      return [
        _F('50 invoices / month', included: true),
        _F('50 clients · 50 items', included: true),
        _F('3 invoice templates', included: true),
        _F('Google Drive sync & backup', included: true),
        _F('Partial payments & TDS', included: true),
        _F('Expense tracking', included: true),
        _F('P&L · Outstanding · Statement', included: true),
        _F('Multi-currency · custom prefix', included: false),
        _F('Recurring invoices & POS', included: false),
      ];
    case SubscriptionTier.pro:
      return [
        _F('Unlimited invoices & clients', included: true),
        _F('All 11 PDF templates', included: true),
        _F('Multi-currency · custom prefix', included: true),
        _F('Recurring invoices & credit notes', included: true),
        _F('GST reports (GSTR-1 style)', included: true),
        _F('Inventory & POS screen', included: true),
        _F('Bulk reminders & category analytics', included: true),
        _F('Team management (up to 5)', included: false),
        _F('Custom message templates', included: false),
      ];
    case SubscriptionTier.premium:
      return [
        _F('Everything in Pro', included: true),
        _F('Team management (up to 5 members)', included: true),
        _F('Custom WhatsApp & email templates', included: true),
        _F('Scheduled payment reminders', included: true),
        _F('Web dashboard & smart insights', included: true),
        _F('Priority email + chat support', included: true),
        _F('Unlimited team members', included: false),
        _F('Dedicated account manager', included: false),
      ];
    case SubscriptionTier.enterprise:
      return [
        _F('Everything in Premium', included: true),
        _F('Unlimited team members', included: true),
        _F('Dedicated account manager', included: true),
        _F('Phone & WhatsApp support', included: true),
        _F('Custom onboarding session', included: true),
        _F('SLA guarantee (48hr response)', included: true),
        _F('API & webhook access', included: true),
        _F('Activity audit log', included: true),
        _F('Volume & multi-business discounts', included: true),
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
    final color = _tierColor(widget.tier);
    return AlertDialog(
      title: Text('Upgrade to ${_tierName(widget.tier)}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price with MRP and discount
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('25% OFF',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${price.mrpRupees}/yr',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${price.yearlyRupees}/year  (₹${price.monthlyRupees}/month)',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 14),
          const Text(
            'Billed annually via Google Play. Cancel anytime — your data stays safe.',
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_error!,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.red)),
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
                  child: CircularProgressIndicator(strokeWidth: 2))
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
            content:
                Text('Successfully upgraded to ${_tierName(widget.tier)}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Purchase failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
