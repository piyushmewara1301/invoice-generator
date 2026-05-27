import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_limits.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class WebPremiumGateScreen extends StatelessWidget {
  const WebPremiumGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrandHeader(),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _GateCard(),
              ),
              const SizedBox(height: 24),
              _SignOutLink(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Brand header ─────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'BB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'BillBook',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Invoice Generator',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

// ── Main gate card ────────────────────────────────────────────────────────────

class _GateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.5)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.laptop_mac_outlined,
                          size: 13, color: Color(0xFFEA580C)),
                      SizedBox(width: 5),
                      Text(
                        'Web Dashboard',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Premium Plan Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The BillBook web dashboard is exclusively available to Premium plan members. Upgrade your plan from the mobile app to unlock web access.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                const _FeatureList(),
                const SizedBox(height: 28),
                const _PremiumPriceBox(),
                const SizedBox(height: 20),
                const _MobileInstructions(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature list ──────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.receipt_long_outlined, 'Unlimited invoices every month'),
      (Icons.palette_outlined, 'All 9 professional invoice templates'),
      (Icons.chat_outlined, 'Custom WhatsApp & email message templates'),
      (Icons.bar_chart_outlined, 'GST Reports — GSTR-1 style with CGST/SGST/IGST'),
      (Icons.cloud_sync_outlined, 'Google Drive sync & backup'),
      (Icons.laptop_mac_outlined, 'Web dashboard — create & manage from any browser'),
      (Icons.currency_exchange_outlined, 'Multi-currency invoicing'),
      (Icons.people_outline, 'Unlimited clients & service items'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What's included in Premium:",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check,
                        size: 13, color: AppTheme.success),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.$2,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Pricing box ───────────────────────────────────────────────────────────────

class _PremiumPriceBox extends StatelessWidget {
  const _PremiumPriceBox();

  @override
  Widget build(BuildContext context) {
    final price = tierPrices[SubscriptionTier.premium]!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEA580C).withValues(alpha: 0.08),
            const Color(0xFFEA580C).withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium,
              color: Color(0xFFEA580C), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium Plan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEA580C),
                  ),
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
                      child: const Text('50% OFF',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                    Text(
                      '₹${price.yearlyRupees * 2}/yr',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          decoration: TextDecoration.lineThrough),
                    ),
                    Text(
                      '₹${price.yearlyRupees}/yr  ·  ₹${price.monthlyRupees}/mo',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined,
                    size: 13, color: Color(0xFFEA580C)),
                SizedBox(width: 5),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile instructions ───────────────────────────────────────────────────────

class _MobileInstructions extends StatelessWidget {
  const _MobileInstructions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_iphone_outlined,
              size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'To upgrade, open the BillBook mobile app → Settings → Plan. Once in-app purchases launch, Premium will unlock web dashboard access instantly.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sign out link ─────────────────────────────────────────────────────────────

class _SignOutLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final auth = context.read<AuthService>();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text(
                'Your data stays safe in Google Drive. Sign in again anytime to restore it.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sign Out',
                      style: TextStyle(color: AppTheme.error))),
            ],
          ),
        );
        if (confirmed != true) return;
        if (!context.mounted) return;
        await context.read<AppProvider>().detachDriveAndClear();
        if (!context.mounted) return;
        await auth.signOut();
      },
      icon: const Icon(Icons.logout, size: 16, color: AppTheme.textSecondary),
      label: const Text('Sign out',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    );
  }
}
