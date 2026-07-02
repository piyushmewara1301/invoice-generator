import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'agewise_report_screen.dart';
import 'client_profile_screen.dart';
import 'daily_sales_screen.dart';
import 'invoice_list_screen.dart';
import 'recurring_invoices_screen.dart';
import 'settings/business_profile_screen.dart';
import 'settings/payment_methods_screen.dart';
import 'settings/services_screen.dart';

enum _Severity { error, warning, info }

class _HealthIssue {
  final _Severity severity;
  final String category;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _HealthIssue({
    required this.severity,
    required this.category,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
}

/// Scans the app's data for quality issues (missing prices, low stock,
/// incomplete profiles, unbalanced cash, etc.) so the user can fix them
/// from one place.
class DataHealthScreen extends StatelessWidget {
  const DataHealthScreen({super.key});

  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  void _openItem(BuildContext context, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ServicesScreen(initialSearch: name)),
    );
  }

  List<_HealthIssue> _collectIssues(
      BuildContext context, AppProvider provider) {
    final issues = <_HealthIssue>[];
    final profile = provider.profile;
    final currency = profile.currency;
    final shopId = provider.currentShopId;
    final itemLabel = profile.itemLabel.toLowerCase();

    // ── Invoices ─────────────────────────────────────────────────────────
    final overdue = provider.overdueInvoices;
    if (overdue.isNotEmpty) {
      final total = overdue.fold(0.0, (s, i) => s + i.amountRemaining);
      issues.add(_HealthIssue(
        severity: _Severity.error,
        category: 'Invoices',
        icon: Icons.warning_amber_rounded,
        title:
            '${overdue.length} invoice${overdue.length == 1 ? '' : 's'} overdue',
        subtitle:
            '${Fmt.currencyAmount(total, currency)} outstanding past due date',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AgewiseReportScreen())),
      ));
    }

    final staleDrafts = provider.draftInvoices
        .where((i) =>
            !i.isQuotation &&
            DateTime.now().difference(i.createdAt).inDays >= 7)
        .toList();
    if (staleDrafts.isNotEmpty) {
      issues.add(_HealthIssue(
        severity: _Severity.info,
        category: 'Invoices',
        icon: Icons.drafts_outlined,
        title:
            '${staleDrafts.length} draft invoice${staleDrafts.length == 1 ? '' : 's'} not sent',
        subtitle: 'Sitting in drafts for over a week',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InvoiceListScreen())),
      ));
    }

    // ── Pricing & Stock ──────────────────────────────────────────────────
    int uncategorized = 0;
    for (final item in provider.serviceItems) {
      if ((item.category == null || item.category!.trim().isEmpty)) {
        uncategorized++;
      }
      if (item.hasVariants) {
        for (final v in item.variants) {
          final label = '${item.name} (${v.name})';
          if (v.isTrackingStock && v.rate <= 0) {
            issues.add(_HealthIssue(
              severity: _Severity.warning,
              category: 'Pricing & Stock',
              icon: Icons.sell_outlined,
              title: 'No selling price set',
              subtitle: label,
              onTap: () => _openItem(context, item.name),
            ));
          }
          if (v.costPrice != null &&
              v.costPrice! > 0 &&
              v.rate > 0 &&
              v.rate < v.costPrice!) {
            issues.add(_HealthIssue(
              severity: _Severity.warning,
              category: 'Pricing & Stock',
              icon: Icons.trending_down_rounded,
              title: 'Selling below cost price',
              subtitle: '$label — selling at '
                  '${Fmt.currencyAmount(v.rate, currency)}, costs '
                  '${Fmt.currencyAmount(v.costPrice!, currency)}',
              onTap: () => _openItem(context, item.name),
            ));
          }
          if (v.isLowStockFor(shopId)) {
            issues.add(_HealthIssue(
              severity: _Severity.info,
              category: 'Pricing & Stock',
              icon: Icons.inventory_2_outlined,
              title: 'Running low on stock',
              subtitle: '$label — ${_fmtQty(v.stockFor(shopId))} left',
              onTap: () => _openItem(context, item.name),
            ));
          }
        }
      } else {
        if (item.trackStock && item.rate <= 0) {
          issues.add(_HealthIssue(
            severity: _Severity.warning,
            category: 'Pricing & Stock',
            icon: Icons.sell_outlined,
            title: 'No selling price set',
            subtitle: item.name,
            onTap: () => _openItem(context, item.name),
          ));
        }
        if (item.costPrice != null &&
            item.costPrice! > 0 &&
            item.rate > 0 &&
            item.rate < item.costPrice!) {
          issues.add(_HealthIssue(
            severity: _Severity.warning,
            category: 'Pricing & Stock',
            icon: Icons.trending_down_rounded,
            title: 'Selling below cost price',
            subtitle: '${item.name} — selling at '
                '${Fmt.currencyAmount(item.rate, currency)}, costs '
                '${Fmt.currencyAmount(item.costPrice!, currency)}',
            onTap: () => _openItem(context, item.name),
          ));
        }
        if (item.isLowStockFor(shopId)) {
          issues.add(_HealthIssue(
            severity: _Severity.info,
            category: 'Pricing & Stock',
            icon: Icons.inventory_2_outlined,
            title: 'Running low on stock',
            subtitle: '${item.name} — ${_fmtQty(item.stockFor(shopId))} left',
            onTap: () => _openItem(context, item.name),
          ));
        }
      }
    }

    // ── Daily Sales ──────────────────────────────────────────────────────
    final unreconciled = provider.dailySales
        .where((s) =>
            DateTime.now().difference(s.date).inDays <= 30 && !s.isBalanced)
        .toList();
    if (unreconciled.isNotEmpty) {
      issues.add(_HealthIssue(
        severity: _Severity.warning,
        category: 'Daily Sales',
        icon: Icons.calculate_outlined,
        title:
            '${unreconciled.length} day${unreconciled.length == 1 ? '' : 's'} not reconciled',
        subtitle:
            "Cash collected doesn't match the expected total in the last 30 days",
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DailySalesScreen())),
      ));
    }

    // ── Clients ──────────────────────────────────────────────────────────
    for (final c in provider.clients) {
      if (c.phone.trim().isEmpty && c.email.trim().isEmpty) {
        issues.add(_HealthIssue(
          severity: _Severity.warning,
          category: 'Clients',
          icon: Icons.person_off_outlined,
          title: 'No contact info',
          subtitle: c.displayName,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ClientProfileScreen(client: c))),
        ));
      }
    }

    // ── Business Setup ───────────────────────────────────────────────────
    if (profile.phone.trim().isEmpty || profile.address.trim().isEmpty) {
      final missing = [
        if (profile.phone.trim().isEmpty) 'phone number',
        if (profile.address.trim().isEmpty) 'address',
      ].join(' and ');
      issues.add(_HealthIssue(
        severity: _Severity.warning,
        category: 'Business Setup',
        icon: Icons.storefront_outlined,
        title: 'Business profile incomplete',
        subtitle: 'Missing $missing — shown on your invoices',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BusinessProfileScreen())),
      ));
    }

    if (profile.isGstRegistered &&
        (profile.defaultPlaceOfSupply == null ||
            profile.defaultPlaceOfSupply!.trim().isEmpty)) {
      issues.add(_HealthIssue(
        severity: _Severity.warning,
        category: 'Business Setup',
        icon: Icons.receipt_long_outlined,
        title: 'Place of supply not set',
        subtitle: 'Needed to calculate CGST/SGST vs IGST correctly',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BusinessProfileScreen())),
      ));
    }

    if (profile.paymentMethods.isEmpty) {
      issues.add(_HealthIssue(
        severity: _Severity.info,
        category: 'Business Setup',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Only cash payments configured',
        subtitle: 'Add UPI or bank accounts for faster reconciliation',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
      ));
    }

    // ── Recurring Invoices ───────────────────────────────────────────────
    final overdueRecurring = provider.activeRecurringSchedules
        .where((r) => r.nextGenerationDate.isBefore(DateTime.now()))
        .toList();
    if (overdueRecurring.isNotEmpty) {
      issues.add(_HealthIssue(
        severity: _Severity.info,
        category: 'Recurring Invoices',
        icon: Icons.repeat_rounded,
        title:
            '${overdueRecurring.length} recurring invoice${overdueRecurring.length == 1 ? '' : 's'} due for generation',
        subtitle: 'Open Recurring Invoices to generate them now',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const RecurringInvoicesScreen())),
      ));
    }

    // ── Catalog ──────────────────────────────────────────────────────────
    if (uncategorized > 0) {
      issues.add(_HealthIssue(
        severity: _Severity.info,
        category: 'Catalog',
        icon: Icons.label_off_outlined,
        title:
            '$uncategorized $itemLabel${uncategorized == 1 ? '' : 's'} have no category',
        subtitle: 'Categorizing helps organize your catalog',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ServicesScreen())),
      ));
    }

    return issues;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final issues = _collectIssues(context, provider);

    final grouped = <String, List<_HealthIssue>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.category, () => []).add(issue);
    }
    const severityOrder = {
      _Severity.error: 0,
      _Severity.warning: 1,
      _Severity.info: 2,
    };
    for (final list in grouped.values) {
      list.sort((a, b) =>
          severityOrder[a.severity]!.compareTo(severityOrder[b.severity]!));
    }

    final errorCount =
        issues.where((i) => i.severity == _Severity.error).length;
    final warningCount =
        issues.where((i) => i.severity == _Severity.warning).length;
    final infoCount =
        issues.where((i) => i.severity == _Severity.info).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Data Health')),
      body: issues.isEmpty
          ? _emptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _summaryBanner(context, errorCount, warningCount, infoCount),
                const SizedBox(height: 16),
                for (final entry in grouped.entries) ...[
                  _categoryHeader(context, entry.key, entry.value.length),
                  const SizedBox(height: 8),
                  _IssueGroupCard(issues: entry.value),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined,
                size: 56, color: AppTheme.success),
            const SizedBox(height: 16),
            Text(
              'All clear!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context)),
            ),
            const SizedBox(height: 6),
            Text(
              'No data issues found right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.subtext(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBanner(
      BuildContext context, int errors, int warnings, int infos) {
    final total = errors + warnings + infos;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined,
              color: AppTheme.subtext(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$total issue${total == 1 ? '' : 's'} found',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context)),
            ),
          ),
          if (errors > 0) _countChip(errors, AppTheme.error),
          if (warnings > 0) _countChip(warnings, AppTheme.warning),
          if (infos > 0) _countChip(infos, AppTheme.primary),
        ],
      ),
    );
  }

  Widget _countChip(int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _categoryHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        '$title ($count)',
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.subtext(context)),
      ),
    );
  }
}

class _IssueGroupCard extends StatelessWidget {
  final List<_HealthIssue> issues;

  const _IssueGroupCard({required this.issues});

  Color _severityColor(_Severity s) {
    switch (s) {
      case _Severity.error:
        return AppTheme.error;
      case _Severity.warning:
        return AppTheme.warning;
      case _Severity.info:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < issues.length; i++) ...[
            _issueTile(context, issues[i]),
            if (i < issues.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _issueTile(BuildContext context, _HealthIssue issue) {
    final color = _severityColor(issue.severity);
    return InkWell(
      onTap: issue.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(issue.icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context)),
                  ),
                  if (issue.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      issue.subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context)),
                    ),
                  ],
                ],
              ),
            ),
            if (issue.onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.subtext(context)),
          ],
        ),
      ),
    );
  }
}
