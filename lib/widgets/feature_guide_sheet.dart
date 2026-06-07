import 'package:flutter/material.dart';
import '../services/guide_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeatureGuide — data model for a single feature guide
// ─────────────────────────────────────────────────────────────────────────────

class FeatureGuide {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> tips;

  const FeatureGuide({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.tips = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AppGuides — all guide definitions in one place
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppGuides {
  static const dashboard = FeatureGuide(
    key: 'dashboard',
    title: 'Dashboard',
    description:
        'Your business at a glance — total invoices, revenue, outstanding amounts, and recent activity.',
    icon: Icons.dashboard_outlined,
    color: Color(0xFF2563EB),
    tips: [
      'Use the period filter to view Today, Week, Month, Year or Custom date ranges.',
      'Tap any stat card to drill into the matching invoice list.',
      'Outstanding card shows all unpaid invoices; overdue items are flagged in red.',
      'The P&L card shows Revenue minus Expenses for the selected period.',
    ],
  );

  static const invoices = FeatureGuide(
    key: 'invoices',
    title: 'Invoices',
    description:
        'Create, manage, and track all your invoices in one place. Supports GST, multi-currency, and 11 PDF templates.',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF2563EB),
    tips: [
      'Tap + to create a new invoice. The number auto-generates.',
      'Swipe right to edit an invoice; swipe left to delete.',
      'Tabs: All · Draft · Sent · Paid · Overdue · Quotes · Credit Notes.',
      'Long-press any invoice to enter bulk-select mode for mass reminders.',
      'Tap the status badge on a quotation card to change status or convert to invoice.',
    ],
  );

  static const expenses = FeatureGuide(
    key: 'expenses',
    title: 'Expenses',
    description:
        'Log every business cost by category. Attach receipt photos for your accountant. Expenses feed directly into your P&L report.',
    icon: Icons.money_off_outlined,
    color: Color(0xFFF97316),
    tips: [
      'Tap the red + button to add an expense with amount, category, and date.',
      'Attach a receipt photo immediately after adding an expense.',
      'Mark an expense as recurring for fixed monthly costs like rent or subscriptions.',
      'Expenses by category are visible in the P&L report.',
    ],
  );

  static const clients = FeatureGuide(
    key: 'clients',
    title: 'Clients',
    description:
        'Your complete client directory. Each client has a payment score, full invoice history, and a shareable account statement.',
    icon: Icons.people_outline,
    color: Color(0xFF0891B2),
    tips: [
      'Tap 📢 in the top bar to send bulk promotional offers via WhatsApp or Email.',
      'Tap a client to view their payment score, history, and generate a statement PDF.',
      'Payment score (Excellent / Good / Fair / Poor) is based on average days to pay.',
      'Add GSTIN to a client to enable B2B GST tracking on their invoices.',
    ],
  );

  static const deliveryChallan = FeatureGuide(
    key: 'delivery_challan',
    title: 'Delivery Challans',
    description:
        'Issue goods dispatch documents before raising the invoice — for approvals, consignments, or free samples.',
    icon: Icons.local_shipping_outlined,
    color: Color(0xFF0D9488),
    tips: [
      'Tap New Challan to create a dispatch document with the same item fields as an invoice.',
      'Swipe right to edit, swipe left to delete.',
      'Tap Convert to Invoice once the goods are accepted — all items carry over instantly.',
      'The PDF header reads "DELIVERY CHALLAN" — it is not a tax document.',
    ],
  );

  static const purchaseBills = FeatureGuide(
    key: 'purchase_bills',
    title: 'Purchase Bills',
    description:
        'Track all bills you receive from suppliers. Monitor what you owe and never miss a payment deadline.',
    icon: Icons.receipt_outlined,
    color: Color(0xFFEF4444),
    tips: [
      'Tap + to add a bill with vendor name, amount, and due date.',
      'Record full or partial payments directly against a bill.',
      'Vendor GSTIN stored for input tax credit (ITC) reference.',
      'Purchase bills feed into the Cash Flow forecast as outflows.',
      'Tap a vendor name to see full payment history and outstanding balance.',
    ],
  );

  static const inventory = FeatureGuide(
    key: 'inventory',
    title: 'Inventory',
    description:
        'Track stock levels for every product. Stock reduces automatically each time an invoice is saved.',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF7C3AED),
    tips: [
      'Enable inventory tracking per item in Settings → Items & Services → Edit Item.',
      'Set an opening quantity and a low-stock threshold for each item.',
      'Low-stock items appear in amber; out-of-stock items appear in red.',
      'Tap Adjust to manually correct stock after receiving new goods.',
    ],
  );

  static const plReport = FeatureGuide(
    key: 'pl_report',
    title: 'Profit & Loss',
    description:
        'Revenue from paid invoices minus recorded expenses = your true net profit. Review every Monday before the week gets busy.',
    icon: Icons.trending_up_outlined,
    color: Color(0xFF10B981),
    tips: [
      'Switch periods: Today, Week, Month, Year, or Custom date range.',
      'Top-5 clients by revenue shown with progress bars.',
      'Expenses breakdown by category appears below the revenue section.',
      'Only paid invoices count as revenue — sent/overdue do not.',
    ],
  );

  static const cashFlow = FeatureGuide(
    key: 'cash_flow',
    title: 'Cash Flow',
    description:
        'See all money coming in (outstanding invoices) vs going out (unpaid bills). Review before making large purchases or salary payments.',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF2563EB),
    tips: [
      'Inflows = all sent and overdue invoices with a balance still due.',
      'Outflows = all unpaid and partially paid purchase bills.',
      'Overdue entries are flagged in red — follow up or settle urgently.',
      'Net position (Expected In minus Expected Out) shown at the top.',
      'Tap any entry to open the invoice or bill and take immediate action.',
    ],
  );

  static const gstReport = FeatureGuide(
    key: 'gst_report',
    title: 'GST Reports',
    description:
        'GSTR-1 style report — auto-splits CGST/SGST or IGST, separates B2B and B2C invoices, and groups by HSN/SAC code.',
    icon: Icons.account_balance_outlined,
    color: Color(0xFFEF4444),
    tips: [
      'Switch quarters (Q1–Q4) or view the full financial year.',
      'B2B invoices = clients with a GSTIN; B2C = without.',
      'HSN/SAC summary groups items by their tax classification code.',
      'Export as PDF to share with your CA for GST filing.',
    ],
  );

  static const categoryAnalytics = FeatureGuide(
    key: 'category_analytics',
    title: 'Category Analytics',
    description:
        'Understand which services and products drive your revenue — by category, by item, and by service.',
    icon: Icons.bar_chart_outlined,
    color: Color(0xFF7C3AED),
    tips: [
      'Revenue tab: income grouped by the line-item category.',
      'Top Items tab: most-billed products ranked by total revenue.',
      'Top Services tab: service-based items ranked the same way.',
      'Use this to identify underperforming offerings to reprice or cut.',
    ],
  );

  static const pos = FeatureGuide(
    key: 'pos',
    title: 'Point of Sale',
    description:
        'Quickly bill walk-in customers from your product catalog. Perfect for cafes, retail counters, and service shops.',
    icon: Icons.point_of_sale_outlined,
    color: Color(0xFF0891B2),
    tips: [
      'Tap an item to add it to cart; tap again to increase quantity.',
      'Filter items by category using the top chip bar.',
      'Tap the cart bar at the bottom to review, select client, and charge.',
      'Checkout creates a saved invoice and optionally records payment.',
    ],
  );

  static const bulkOffer = FeatureGuide(
    key: 'bulk_offer',
    title: 'Bulk Offer Messages',
    description:
        'Send promotional messages to multiple clients at once via WhatsApp or Email.',
    icon: Icons.campaign_outlined,
    color: Color(0xFF25D366),
    tips: [
      'Compose tab: write your offer message using {client_name}, {business_name} etc.',
      'Tap a variable chip to insert it at the cursor position.',
      'Recipients tab: select which clients receive the message.',
      'WhatsApp opens one at a time — tap Send in WhatsApp for each client.',
      'Email personalises the subject and body with each client\'s name.',
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// showFeatureGuide — entry point used by screens
//
// Call from initState via WidgetsBinding.instance.addPostFrameCallback so it
// does not block the first frame render.
//
// Set [force] = true to always show the guide regardless of dismissed state
// (e.g., when the user manually taps a Help button).
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showFeatureGuide(
  BuildContext context,
  FeatureGuide guide, {
  bool force = false,
}) async {
  if (!force && !await GuideService.shouldShow(guide.key)) return;
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeatureGuideSheet(guide: guide),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _FeatureGuideSheet
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureGuideSheet extends StatelessWidget {
  final FeatureGuide guide;
  const _FeatureGuideSheet({required this.guide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.outline(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Icon + Title ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: guide.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(guide.icon, color: guide.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onCard(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: guide.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Feature Guide',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: guide.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Description ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              guide.description,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.subtext(context),
                height: 1.55,
              ),
            ),
          ),

          // ── Tips ─────────────────────────────────────────────────────────
          if (guide.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Quick tips',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.subtext(context),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...guide.tips.map(
              (tip) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.circle,
                          size: 6, color: guide.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.onCard(context),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Action buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // "Don't show again" — permanent dismiss
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await GuideService.dismiss(guide.key);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                          color: AppTheme.outline(context)),
                    ),
                    child: Text(
                      "Don't show again",
                      style: TextStyle(
                        color: AppTheme.subtext(context),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // "Got it" — dismiss for this session only
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: guide.color,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
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
