import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/purchase_bill.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'create_purchase_bill_screen.dart';

// ── Vendor summary ────────────────────────────────────────────────────────────

class VendorSummary {
  final String vendorName;
  final String? gstin;
  final String? phone;
  final String? email;
  final List<PurchaseBill> bills;

  const VendorSummary({
    required this.vendorName,
    this.gstin,
    this.phone,
    this.email,
    required this.bills,
  });

  double get totalBilled => bills.fold(0, (s, b) => s + b.grandTotal);
  double get totalPaid   => bills.fold(0, (s, b) => s + b.amountPaid);
  double get totalDue    => bills.fold(0, (s, b) => s + b.amountDue);
  double get totalItc    => bills.fold(0, (s, b) => s + b.itcAmount);
  int    get overdueCount => bills.where((b) => b.isOverdue).length;
  int    get paidCount    => bills.where((b) => b.status == PurchaseBillStatus.paid).length;

  String get reliabilityGrade {
    if (bills.isEmpty) return 'New';
    final onTimeRate = bills.isEmpty ? 0 : (paidCount / bills.length);
    if (onTimeRate >= 0.9) return 'Reliable';
    if (onTimeRate >= 0.6) return 'Good';
    if (onTimeRate >= 0.3) return 'Average';
    return 'Review';
  }

  Color gradeColor(BuildContext ctx) {
    switch (reliabilityGrade) {
      case 'Reliable': return const Color(0xFF059669);
      case 'Good':     return const Color(0xFF2563EB);
      case 'Average':  return const Color(0xFFF59E0B);
      default:         return AppTheme.subtext(ctx);
    }
  }

  static VendorSummary fromBills(String vendorName, List<PurchaseBill> all) {
    final vBills = all.where((b) => b.vendorName == vendorName).toList()
      ..sort((a, b) => b.billDate.compareTo(a.billDate));
    final sample = vBills.isNotEmpty ? vBills.first : null;
    return VendorSummary(
      vendorName: vendorName,
      gstin: sample?.vendorGstin,
      phone: sample?.vendorPhone,
      email: sample?.vendorEmail,
      bills: vBills,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VendorProfileScreen extends StatelessWidget {
  final String vendorName;
  const VendorProfileScreen({super.key, required this.vendorName});

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final sym       = Fmt.currencySymbol(provider.profile.currency);
    final summary   = VendorSummary.fromBills(vendorName, provider.purchaseBills);
    final gradeColor = summary.gradeColor(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
        slivers: [
          // ── Collapsing header ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          vendorName.isNotEmpty
                              ? vendorName[0].toUpperCase()
                              : 'V',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(vendorName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      if (summary.gstin?.isNotEmpty == true)
                        Text(summary.gstin!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Quick actions ─────────────────────────────────────────────
                Row(children: [
                  _ActionBtn(
                    icon: Icons.add_circle_outline,
                    label: 'New Bill',
                    color: const Color(0xFF7C3AED),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreatePurchaseBillScreen(prefilledVendorName: vendorName),
                      ),
                    ),
                  ),
                  if (summary.phone?.isNotEmpty == true) ...[
                    const SizedBox(width: 10),
                    _ActionBtn(
                      icon: Icons.call_outlined,
                      label: 'Call',
                      color: const Color(0xFF059669),
                      onTap: () => launchUrl(
                        Uri(scheme: 'tel', path: summary.phone),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                  if (summary.email?.isNotEmpty == true) ...[
                    const SizedBox(width: 10),
                    _ActionBtn(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      color: const Color(0xFF2563EB),
                      onTap: () => launchUrl(
                        Uri(scheme: 'mailto', path: summary.email),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 16),

                // ── Financial summary ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.outline(context)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Vendor Summary',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onCard(context))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: gradeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: gradeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(summary.reliabilityGrade,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: gradeColor)),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        _StatTile(
                          label: 'Total Billed',
                          value: '$sym${Fmt.compact(summary.totalBilled)}',
                          color: AppTheme.onCard(context),
                        ),
                        _StatTile(
                          label: 'Total Paid',
                          value: '$sym${Fmt.compact(summary.totalPaid)}',
                          color: const Color(0xFF059669),
                        ),
                        _StatTile(
                          label: 'Outstanding',
                          value: '$sym${Fmt.compact(summary.totalDue)}',
                          color: summary.totalDue > 0
                              ? AppTheme.error
                              : const Color(0xFF059669),
                        ),
                      ]),
                      if (summary.bills.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(children: [
                          _StatTile(
                            label: 'ITC Claimable',
                            value: '$sym${Fmt.compact(summary.totalItc)}',
                            color: const Color(0xFF7C3AED),
                          ),
                          _StatTile(
                            label: 'Total Bills',
                            value: '${summary.bills.length}',
                            color: AppTheme.onCard(context),
                          ),
                          _StatTile(
                            label: 'Overdue',
                            value: '${summary.overdueCount}',
                            color: summary.overdueCount > 0
                                ? AppTheme.error
                                : const Color(0xFF059669),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Contact details ───────────────────────────────────────────
                if (summary.phone?.isNotEmpty == true ||
                    summary.email?.isNotEmpty == true ||
                    summary.gstin?.isNotEmpty == true) ...[
                  _SectionCard(title: 'Contact Details', children: [
                    if (summary.phone?.isNotEmpty == true)
                      _InfoRow(Icons.phone_outlined, 'Phone', summary.phone!),
                    if (summary.email?.isNotEmpty == true)
                      _InfoRow(Icons.email_outlined, 'Email', summary.email!),
                    if (summary.gstin?.isNotEmpty == true)
                      _InfoRow(Icons.badge_outlined, 'GSTIN', summary.gstin!),
                  ]),
                  const SizedBox(height: 16),
                ],

                // ── Bill history ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bill History (${summary.bills.length})',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onCard(context))),
                    if (summary.totalDue > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$sym${Fmt.compact(summary.totalDue)} due',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (summary.bills.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outline(context)),
                    ),
                    child: Center(
                      child: Text('No bills yet',
                          style:
                              TextStyle(color: AppTheme.subtext(context))),
                    ),
                  )
                else
                  ...summary.bills.map((bill) => _BillTile(
                        bill: bill,
                        sym: sym,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreatePurchaseBillScreen(bill: bill),
                          ),
                        ),
                      )),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Bill',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CreatePurchaseBillScreen(prefilledVendorName: vendorName),
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
        ),
      );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: AppTheme.subtext(context))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outline(context)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.subtext(context),
                    letterSpacing: 0.4)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppTheme.subtext(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.subtext(context))),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.onCard(context))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _BillTile extends StatelessWidget {
  final PurchaseBill bill;
  final String sym;
  final VoidCallback onTap;
  const _BillTile(
      {required this.bill, required this.sym, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = bill.status.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: bill.isOverdue
                ? AppTheme.error.withValues(alpha: 0.35)
                : AppTheme.outline(context),
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(bill.status.icon, size: 18, color: sc),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                bill.billNumber != null && bill.billNumber!.isNotEmpty
                    ? '#${bill.billNumber}'
                    : Fmt.shortDate(bill.billDate),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context)),
              ),
              Text(Fmt.shortDate(bill.billDate),
                  style:
                      TextStyle(fontSize: 11, color: AppTheme.subtext(context))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$sym${Fmt.compact(bill.grandTotal)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(context))),
            if (bill.amountDue > 0)
              Text('$sym${Fmt.compact(bill.amountDue)} due',
                  style: TextStyle(
                      fontSize: 10,
                      color: bill.isOverdue
                          ? AppTheme.error
                          : AppTheme.subtext(context),
                      fontWeight: bill.isOverdue
                          ? FontWeight.w600
                          : FontWeight.normal)),
          ]),
        ]),
      ),
    );
  }
}
