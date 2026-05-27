import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../services/exchange_rate_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'create_invoice_screen.dart';

// ─── Panel IDs ────────────────────────────────────────────────────────────────
const _pInsights = 'insights';
const _pKpis     = 'kpis';
const _pRevenue  = 'revenue';
const _pCashFlow = 'cashflow';
const _pStatus   = 'status';
const _pClients  = 'clients';
const _pCustomer = 'customer';
const _pProduct  = 'product';
const _pOverdue  = 'overdue';
const _pForecast = 'forecast';
const _pRecent   = 'recent';

class _PInfo {
  final String id, label, desc;
  final IconData icon;
  const _PInfo(this.id, this.label, this.icon, this.desc);
}

const _allPanels = [
  _PInfo(_pInsights, 'Smart Insights',      Icons.auto_awesome_rounded,           'AI-generated business recommendations'),
  _PInfo(_pKpis,     'KPI Metrics',         Icons.dashboard_rounded,               'Key performance indicators'),
  _PInfo(_pRevenue,  'Revenue Chart',       Icons.bar_chart_rounded,               '12-month paid vs outstanding trend'),
  _PInfo(_pCashFlow, 'Cash Flow',           Icons.account_balance_wallet_rounded,  'Invoiced vs collected by month'),
  _PInfo(_pStatus,   'Invoice Status',      Icons.donut_large_rounded,             'Invoice status distribution'),
  _PInfo(_pClients,  'Top Clients',         Icons.people_rounded,                  'Clients ranked by revenue & LTV'),
  _PInfo(_pCustomer, 'Customer Insights',   Icons.person_search_rounded,           'Retention, churn risk & new vs returning'),
  _PInfo(_pProduct,  'Revenue by Service',  Icons.inventory_2_rounded,             'Top products & services by revenue'),
  _PInfo(_pOverdue,  'Overdue Aging',       Icons.warning_amber_rounded,           'Overdue invoice age buckets'),
  _PInfo(_pForecast, 'Revenue Forecast',    Icons.trending_up_rounded,             '3-month projected revenue'),
  _PInfo(_pRecent,   'Recent Invoices',     Icons.receipt_long_rounded,            'Latest invoice activity'),
];

// ─── Data models ──────────────────────────────────────────────────────────────

class _MonthBucket {
  final int y, m;
  double rev = 0, outs = 0, inv = 0;
  _MonthBucket(this.y, this.m);
  String get lbl {
    const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return ms[m - 1];
  }
}

class _ClientRow {
  final String id, name;
  double ltv = 0, billed = 0, overdue = 0;
  int cnt = 0, paidCnt = 0;
  DateTime? last;
  _ClientRow(this.id, this.name);
  bool get churnRisk => cnt >= 2 && last != null && DateTime.now().difference(last!).inDays > 60;
  double get payRate  => billed > 0 ? ltv / billed : 0;
  int get idleDays    => last == null ? 0 : DateTime.now().difference(last!).inDays;
}

class _ProductRow {
  final String name;
  double revenue;
  int count;
  _ProductRow(this.name, this.revenue, this.count);
}

class _FPt {
  final String lbl;
  final double v;
  final bool proj;
  _FPt(this.lbl, this.v, this.proj);
}

enum _IL { info, warn, crit }

class _Insight {
  final String title, body;
  final Color col;
  final IconData icon;
  final _IL lvl;
  const _Insight(this.lvl, this.icon, this.col, this.title, this.body);
}

// ─── Analytics helpers ────────────────────────────────────────────────────────

List<_FPt> _buildForecast(List<_MonthBucket> months) {
  const n = 6;
  final sl = months.sublist(months.length - n);
  double sx = 0, sy = 0, sxy = 0, sx2 = 0;
  for (int i = 0; i < n; i++) {
    sx += i; sy += sl[i].rev;
    sxy += i * sl[i].rev; sx2 += i * i.toDouble();
  }
  final den = n * sx2 - sx * sx;
  double b = n > 0 ? sy / n : 0, a = 0;
  if (den != 0) { a = (n * sxy - sx * sy) / den; b = (sy - a * sx) / n; }

  const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final now = DateTime.now();
  final res = <_FPt>[];
  for (int i = 0; i < n; i++) { res.add(_FPt(sl[i].lbl, sl[i].rev, false)); }
  for (int i = 0; i < 3; i++) {
    final pv = math.max(0.0, b + a * (n + i));
    final d  = DateTime(now.year, now.month + i + 1);
    res.add(_FPt(ms[d.month - 1], pv, true));
  }
  return res;
}

List<_Insight> _mkInsights({
  required double rev, required double gap,  required double cr,
  required double mom, required double conc, required String topName,
  required int churnCnt, required int serOvCnt, required double serOvAmt,
  required double dso, required String cur,
}) {
  final s = Fmt.currencySymbol(cur);
  final r = <_Insight>[];

  if (mom > 5) {
    r.add(_Insight(_IL.info, Icons.trending_up_rounded, const Color(0xFF059669),
        'Revenue up ${mom.toStringAsFixed(1)}% MoM',
        'Strong momentum. Maintain consistent invoicing and explore upsell opportunities with top clients.'));
  } else if (mom < -5) {
    r.add(_Insight(_IL.warn, Icons.trending_down_rounded, const Color(0xFFF59E0B),
        'Revenue down ${mom.abs().toStringAsFixed(1)}% MoM',
        'Revenue dipped vs last month. Review your pipeline and follow up on any stalled deals.'));
  }

  if (cr < 70 && rev > 0) {
    r.add(_Insight(_IL.crit, Icons.account_balance_wallet_rounded, const Color(0xFFEF4444),
        'Low collection rate: ${cr.toStringAsFixed(1)}%',
        '$s${_c(gap)} invoiced but uncollected. Tighten payment terms and send automated reminders.'));
  } else if (cr < 85 && rev > 0) {
    r.add(_Insight(_IL.warn, Icons.account_balance_wallet_rounded, const Color(0xFFF59E0B),
        'Collection at ${cr.toStringAsFixed(1)}%',
        '$s${_c(gap)} outstanding. A structured follow-up schedule can recover most of this.'));
  }

  if (conc > 70 && topName.isNotEmpty) {
    r.add(_Insight(_IL.warn, Icons.pie_chart_rounded, const Color(0xFFF59E0B),
        'Revenue concentrated — top 3 = ${conc.toStringAsFixed(0)}%',
        'Heavy reliance on $topName and 2 others. Diversify your client base to reduce concentration risk.'));
  }

  if (serOvCnt > 0) {
    r.add(_Insight(_IL.crit, Icons.timer_off_rounded, const Color(0xFFEF4444),
        '$serOvCnt invoice${serOvCnt > 1 ? "s" : ""} 30+ days overdue',
        '$s${_c(serOvAmt)} overdue >30 days. Escalate with a formal notice or offer a payment plan.'));
  }

  if (churnCnt > 0) {
    r.add(_Insight(_IL.warn, Icons.person_off_rounded, const Color(0xFFDB2777),
        '$churnCnt client${churnCnt > 1 ? "s" : ""} showing churn risk',
        'No invoice in 60+ days for $churnCnt client${churnCnt > 1 ? "s" : ""}. Re-engage with a check-in or special offer.'));
  }

  if (dso > 45) {
    r.add(_Insight(_IL.warn, Icons.hourglass_full_rounded, const Color(0xFFF59E0B),
        'DSO ${dso.toStringAsFixed(0)} days — above healthy range',
        'Clients take ${dso.toStringAsFixed(0)} days on average to pay. Consider Net-15 or Net-30 payment terms.'));
  }

  return r;
}

String _c(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000)   return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000)     return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

// ─── Main widget ──────────────────────────────────────────────────────────────

class WebDashboardHome extends StatefulWidget {
  const WebDashboardHome({super.key});
  @override
  State<WebDashboardHome> createState() => _DashState();
}

class _DashState extends State<WebDashboardHome> {
  final Set<String> _off = {};
  bool _v(String id) => !_off.contains(id);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final fx   = context.watch<ExchangeRateService>();
    final all  = prov.invoices;
    final cur  = prov.profile.currency;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fx.fetchIfNeeded(cur);
    });

    final now = DateTime.now();
    double x(double a, Invoice i) => fx.toBase(a, i.currency);
    bool smo(DateTime d, int y, int mo) => d.year == y && d.month == mo;
    final py = now.month == 1 ? now.year - 1 : now.year;
    final pm = now.month == 1 ? 12 : now.month - 1;

    // ── Filtered lists ────────────────────────────────────────────────────────
    final live = all.where((i) => i.status != InvoiceStatus.cancelled).toList();
    final paidL = all.where((i) => i.status == InvoiceStatus.paid).toList();
    final pendL = all.where((i) => i.status != InvoiceStatus.paid && i.status != InvoiceStatus.cancelled).toList();

    double sm(Iterable<Invoice> l, {bool rem = false}) =>
        l.fold(0.0, (s, i) => s + x(rem ? i.amountRemaining : i.grandTotal, i));

    // ── Core KPIs ────────────────────────────────────────────────────────────
    final totRev  = sm(paidL);
    final totBill = sm(live);
    final totOuts = sm(pendL, rem: true);
    final cr      = totBill > 0 ? totRev / totBill * 100 : 0.0;
    final aov     = live.isNotEmpty ? totBill / live.length : 0.0;
    final gap     = totBill - totRev;
    final expIn   = totOuts * (cr / 100);

    final mRev  = sm(paidL.where((i) => smo(i.invoiceDate, now.year, now.month)));
    final lmRev = sm(paidL.where((i) => smo(i.invoiceDate, py, pm)));
    final mom   = lmRev > 0 ? (mRev - lmRev) / lmRev * 100 : 0.0;

    final rev90 = sm(paidL.where((i) => i.invoiceDate.isAfter(now.subtract(const Duration(days: 90)))));
    final dso   = rev90 > 0 ? (totOuts / rev90 * 90).clamp(0.0, 365.0) : 0.0;

    // ── 12-month buckets ──────────────────────────────────────────────────────
    final months = List.generate(12, (i) {
      final d = DateTime(now.year, now.month - (11 - i), 1);
      return _MonthBucket(d.year, d.month);
    });
    for (final inv in all) {
      if (inv.status == InvoiceStatus.cancelled) continue;
      final b = months.where((m) => m.y == inv.invoiceDate.year && m.m == inv.invoiceDate.month).firstOrNull;
      if (b == null) continue;
      b.inv += x(inv.grandTotal, inv);
      if (inv.status == InvoiceStatus.paid) { b.rev += x(inv.grandTotal, inv); }
      else { b.outs += x(inv.amountRemaining, inv); }
    }

    // ── Status distribution ───────────────────────────────────────────────────
    final sCnts = {for (final s in InvoiceStatus.values) s: all.where((i) => i.status == s).length};

    // ── Client metrics ────────────────────────────────────────────────────────
    final cmap = <String, _ClientRow>{};
    for (final inv in all) {
      if (inv.client == null) continue;
      final c = cmap.putIfAbsent(inv.client!.id, () => _ClientRow(inv.client!.id, inv.client!.displayName));
      if (inv.status == InvoiceStatus.cancelled) continue;
      c.cnt++;
      c.billed += x(inv.grandTotal, inv);
      if (inv.status == InvoiceStatus.paid) { c.ltv += x(inv.grandTotal, inv); c.paidCnt++; }
      if (inv.isOverdue) c.overdue += x(inv.amountRemaining, inv);
      if (c.last == null || inv.invoiceDate.isAfter(c.last!)) c.last = inv.invoiceDate;
    }
    final sortC  = cmap.values.toList()..sort((a, b) => b.ltv.compareTo(a.ltv));
    final topC   = sortC.take(6).toList();
    final churnC = sortC.where((c) => c.churnRisk).take(5).toList();
    final totCli = cmap.length;

    // New clients this month + new vs returning revenue
    int newCnt = 0; double newRev = 0, retRev = 0;
    for (final cid in cmap.keys) {
      final dates = all.where((i) => i.client?.id == cid).map((i) => i.invoiceDate).toList()..sort();
      if (dates.isEmpty) continue;
      final isNew = smo(dates.first, now.year, now.month);
      final cRevMo = sm(paidL.where((i) => i.client?.id == cid && smo(i.invoiceDate, now.year, now.month)));
      if (isNew) { newCnt++; newRev += cRevMo; }
      else { retRev += cRevMo; }
    }

    // Concentration
    final top3Rev = sortC.take(3).fold(0.0, (s, c) => s + c.ltv);
    final conc    = totRev > 0 ? top3Rev / totRev * 100 : 0.0;

    // ── Product revenue ────────────────────────────────────────────────────────
    final pmap = <String, _ProductRow>{};
    for (final inv in paidL) {
      for (final item in inv.items) {
        final key = item.description.trim();
        if (key.isEmpty) continue;
        final rev = x(item.total, inv);
        pmap.putIfAbsent(key, () => _ProductRow(key, 0, 0));
        pmap[key]!.revenue += rev;
        pmap[key]!.count   += item.quantity.round();
      }
    }
    final topProds = (pmap.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue))).take(8).toList();

    // ── Overdue aging ─────────────────────────────────────────────────────────
    int ob1 = 0, ob2 = 0, ob3 = 0, ob4 = 0;
    double oa1 = 0, oa2 = 0, oa3 = 0, oa4 = 0;
    for (final inv in all.where((i) => i.isOverdue)) {
      final d = now.difference(inv.dueDate).inDays;
      final a = x(inv.amountRemaining, inv);
      if (d <= 7)       { ob1++; oa1 += a; }
      else if (d <= 30) { ob2++; oa2 += a; }
      else if (d <= 60) { ob3++; oa3 += a; }
      else              { ob4++; oa4 += a; }
    }

    // ── Forecast ──────────────────────────────────────────────────────────────
    final fcst = _buildForecast(months);

    // ── Smart insights ────────────────────────────────────────────────────────
    final insights = _mkInsights(
      rev: totRev, gap: gap, cr: cr, mom: mom, conc: conc,
      topName: sortC.isNotEmpty ? sortC.first.name : '',
      churnCnt: churnC.length, serOvCnt: ob3 + ob4, serOvAmt: oa3 + oa4,
      dso: dso, cur: cur,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashHeader(
              name: prov.profile.name,
              onNew: () {
                final inv = context.read<AppProvider>().buildNewInvoice();
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: inv)));
              },
              onCustomize: _openCustomize,
            ),
            const SizedBox(height: 20),

            // Smart Insights
            if (_v(_pInsights) && insights.isNotEmpty) ...[
              _InsightsBanner(insights: insights),
              const SizedBox(height: 18),
            ],

            // KPI Cards
            if (_v(_pKpis)) ...[
              _KpiRow(
                totRev: totRev, mRev: mRev, mom: mom, cr: cr, totOuts: totOuts,
                dso: dso, aov: aov, totCli: totCli, newCnt: newCnt,
                expIn: expIn, gap: gap, cur: cur,
              ),
              const SizedBox(height: 20),
            ],

            // Revenue chart + Status donut
            if (_v(_pRevenue) || _v(_pStatus)) ...[
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_v(_pRevenue)) Expanded(flex: 6, child: _RevenueChart(months: months, cur: cur)),
                  if (_v(_pRevenue) && _v(_pStatus)) const SizedBox(width: 18),
                  if (_v(_pStatus))  Expanded(flex: 4, child: _StatDonut(cnts: sCnts, total: all.length, totRev: totRev, cr: cr, cur: cur)),
                ]),
              ),
              const SizedBox(height: 18),
            ],

            // Cash flow
            if (_v(_pCashFlow)) ...[
              _CashFlowCard(months: months, totBill: totBill, totRev: totRev, gap: gap, expIn: expIn, cr: cr, cur: cur),
              const SizedBox(height: 18),
            ],

            // Top clients + Customer insights
            if (_v(_pClients) || _v(_pCustomer)) ...[
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_v(_pClients)) Expanded(flex: 11, child: _TopCliCard(clients: topC, cur: cur)),
                  if (_v(_pClients) && _v(_pCustomer)) const SizedBox(width: 18),
                  if (_v(_pCustomer)) Expanded(flex: 9, child: _CustCard(
                    churn: churnC, newCnt: newCnt, total: totCli,
                    newRev: newRev, retRev: retRev, cur: cur,
                  )),
                ]),
              ),
              const SizedBox(height: 18),
            ],

            // Revenue by product
            if (_v(_pProduct) && topProds.isNotEmpty) ...[
              _ProductCard(products: topProds, totRev: totRev, cur: cur),
              const SizedBox(height: 18),
            ],

            // Overdue aging + Forecast
            if (_v(_pOverdue) || _v(_pForecast)) ...[
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_v(_pOverdue))  Expanded(flex: 4, child: _OverdueCard(b1:ob1,b2:ob2,b3:ob3,b4:ob4,a1:oa1,a2:oa2,a3:oa3,a4:oa4,cur:cur)),
                  if (_v(_pOverdue) && _v(_pForecast)) const SizedBox(width: 18),
                  if (_v(_pForecast)) Expanded(flex: 6, child: _FcstCard(pts: fcst, cur: cur)),
                ]),
              ),
              const SizedBox(height: 18),
            ],

            // Recent invoices
            if (_v(_pRecent))
              _RecTable(invoices: all.take(10).toList()),
          ],
        ),
      ),
    );
  }

  void _openCustomize() => showDialog(
    context: context,
    builder: (_) => _CustomizeDialog(
      off: _off,
      toggle: (id, on) => setState(() => on ? _off.remove(id) : _off.add(id)),
    ),
  );
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final String name;
  final VoidCallback onNew, onCustomize;
  const _DashHeader({required this.name, required this.onNew, required this.onCustomize});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Row(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            name.isNotEmpty ? '$greet, $name 👋' : greet,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 3),
          const Text("Here's your business overview", style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ]),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onCustomize,
          icon: const Icon(Icons.tune_rounded, size: 15),
          label: const Text('Customize'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Invoice'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ─── Customize dialog ─────────────────────────────────────────────────────────

class _CustomizeDialog extends StatefulWidget {
  final Set<String> off;
  final void Function(String id, bool on) toggle;
  const _CustomizeDialog({required this.off, required this.toggle});
  @override
  State<_CustomizeDialog> createState() => _CustomizeDialogState();
}

class _CustomizeDialogState extends State<_CustomizeDialog> {
  late final Set<String> _local;
  @override
  void initState() {
    super.initState();
    _local = Set.from(widget.off);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.tune_rounded, size: 17, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Customize Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text('Toggle panels on or off', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: _allPanels.map((p) {
              final on = !_local.contains(p.id);
              return SwitchListTile(
                value: on,
                onChanged: (v) {
                  setState(() => v ? _local.remove(p.id) : _local.add(p.id));
                  widget.toggle(p.id, v);
                },
                secondary: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: (on ? AppTheme.primary : AppTheme.textSecondary).withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(p.icon, size: 16, color: on ? AppTheme.primary : AppTheme.textSecondary),
                ),
                title: Text(p.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? AppTheme.textPrimary : AppTheme.textSecondary)),
                subtitle: Text(p.desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                dense: true,
                activeThumbColor: AppTheme.primary,
              );
            }).toList()),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Smart Insights banner ────────────────────────────────────────────────────

class _InsightsBanner extends StatelessWidget {
  final List<_Insight> insights;
  const _InsightsBanner({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Smart Insights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('${insights.length} alert${insights.length != 1 ? "s" : ""}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: insights.map((ins) => _InsightChip(ins)).toList(),
        ),
      ]),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final _Insight ins;
  const _InsightChip(this.ins);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360, minWidth: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ins.col.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ins.col.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: ins.col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(ins.icon, size: 15, color: ins.col),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ins.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ins.col)),
            const SizedBox(height: 3),
            Text(ins.body, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final double totRev, mRev, mom, cr, totOuts, dso, aov, expIn, gap;
  final int totCli, newCnt;
  final String cur;

  const _KpiRow({
    required this.totRev, required this.mRev, required this.mom, required this.cr,
    required this.totOuts, required this.dso, required this.aov, required this.totCli,
    required this.newCnt, required this.expIn, required this.gap, required this.cur,
  });

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final momPos = mom >= 0;

    final kpis = [
      _KD('Total Revenue',   '$sym${_c(totRev)}',    'All-time collected',   Icons.currency_rupee_rounded,  const Color(0xFF059669)),
      _KD('This Month',      '$sym${_c(mRev)}',      mom != 0 ? '${momPos ? "▲" : "▼"} ${mom.abs().toStringAsFixed(1)}% vs last month' : 'Current month', Icons.today_rounded, const Color(0xFF2563EB)),
      _KD('Outstanding',     '$sym${_c(totOuts)}',   'Awaiting payment',     Icons.hourglass_empty_rounded, const Color(0xFFF59E0B)),
      _KD('Collection Rate', '${cr.toStringAsFixed(1)}%', 'Of total billed', Icons.donut_large_rounded,     AppTheme.primary),
      _KD('Avg Order Value', '$sym${_c(aov)}',        'Per invoice',         Icons.receipt_outlined,         const Color(0xFF7C3AED)),
      _KD('Days Sales Out.', '${dso.toStringAsFixed(0)}d', dso > 45 ? '⚠ Above target' : 'Healthy range', Icons.timer_outlined, dso > 45 ? const Color(0xFFEF4444) : const Color(0xFF059669)),
      _KD('Active Clients',  '$totCli',               '$newCnt new this month', Icons.people_outline_rounded, const Color(0xFFDB2777)),
      _KD('Expected Inflow', '$sym${_c(expIn)}',     'At current coll. rate', Icons.input_rounded,           const Color(0xFF0891B2)),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kpis.length,
        separatorBuilder: (context2, i2) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 200, child: _KpiCard(d: kpis[i])),
      ),
    );
  }
}

class _KD {
  final String t, v, s;
  final IconData ic;
  final Color c;
  const _KD(this.t, this.v, this.s, this.ic, this.c);
}

class _KpiCard extends StatelessWidget {
  final _KD d;
  const _KpiCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppTheme.cardShadow),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: d.c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(d.ic, color: d.c, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(d.t, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(d.v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 1),
          Text(d.s, style: TextStyle(fontSize: 10, color: d.c, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ─── Revenue Chart ────────────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  final List<_MonthBucket> months;
  final String cur;
  const _RevenueChart({required this.months, required this.cur});

  @override
  Widget build(BuildContext context) {
    final maxV = months.fold(0.0, (m, b) => math.max(m, b.rev + b.outs));
    return _Card(
      title: 'Revenue Overview',
      subtitle: 'Last 12 months — paid vs outstanding',
      icon: Icons.bar_chart_rounded,
      iconColor: AppTheme.primary,
      child: Column(children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SizedBox(
              width: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) => Text(_c(maxV * (4 - i) / 4),
                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: CustomPaint(
              painter: _BarPainter(months: months, maxV: maxV == 0 ? 1 : maxV),
              child: const SizedBox.expand(),
            )),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: Row(children: months.map((b) => Expanded(child: Text(b.lbl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8.5, color: AppTheme.textSecondary)))).toList()),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(const Color(0xFF2563EB), 'Paid'),
          const SizedBox(width: 20),
          _legend(const Color(0xFFF59E0B), 'Outstanding'),
        ]),
      ]),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(t, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  ]);
}

class _BarPainter extends CustomPainter {
  final List<_MonthBucket> months;
  final double maxV;
  _BarPainter({required this.months, required this.maxV});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final n = months.length;
    final gw = size.width / n;
    final bw = gw * 0.32;
    final gap = bw * 0.2;
    for (int i = 0; i < n; i++) {
      final b = months[i];
      final cx = gw * i + gw / 2;
      if (b.rev > 0) {
        final h = (b.rev / maxV) * size.height;
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw - gap / 2, size.height - h, bw, h), const Radius.circular(4)),
          Paint()..color = const Color(0xFF2563EB));
      }
      if (b.outs > 0) {
        final h = (b.outs / maxV) * size.height;
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + gap / 2, size.height - h, bw, h), const Radius.circular(4)),
          Paint()..color = const Color(0xFFF59E0B));
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.months != months;
}

// ─── Cash Flow Panel ──────────────────────────────────────────────────────────

class _CashFlowCard extends StatelessWidget {
  final List<_MonthBucket> months;
  final double totBill, totRev, gap, expIn, cr;
  final String cur;
  const _CashFlowCard({required this.months, required this.totBill, required this.totRev,
      required this.gap, required this.expIn, required this.cr, required this.cur});

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final maxV = months.fold(0.0, (m, b) => math.max(m, b.inv));

    return _Card(
      title: 'Cash Flow Analysis',
      subtitle: 'Invoiced vs collected — 12 months',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF059669),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Chart
        Expanded(
          flex: 7,
          child: Column(children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (i) => Text(_c(maxV * (4 - i) / 4),
                        style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: CustomPaint(
                  painter: _CashFlowPainter(months: months, maxV: maxV == 0 ? 1 : maxV),
                  child: const SizedBox.expand(),
                )),
              ]),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Row(children: months.map((b) => Expanded(child: Text(b.lbl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8.5, color: AppTheme.textSecondary)))).toList()),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _cfLeg(const Color(0xFFCBD5E1), 'Invoiced'),
              const SizedBox(width: 20),
              _cfLeg(const Color(0xFF059669), 'Collected'),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        // Stats
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            _cfStat('Total Invoiced', '$sym${_c(totBill)}', const Color(0xFF64748B), Icons.receipt_long_rounded),
            const SizedBox(height: 12),
            _cfStat('Total Collected', '$sym${_c(totRev)}', const Color(0xFF059669), Icons.check_circle_rounded),
            const SizedBox(height: 12),
            _cfStat('Cash Gap', '$sym${_c(gap)}', const Color(0xFFEF4444), Icons.remove_circle_outline_rounded),
            const SizedBox(height: 12),
            _cfStat('Expected Inflow', '$sym${_c(expIn)}', const Color(0xFF2563EB), Icons.input_rounded),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Collection Rate', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Row(children: [
                  Text('${cr.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                  const Spacer(),
                  Icon(cr >= 85 ? Icons.check_circle : Icons.warning_rounded,
                      size: 16, color: cr >= 85 ? const Color(0xFF059669) : const Color(0xFFF59E0B)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (cr / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFDCFCE7),
                    valueColor: AlwaysStoppedAnimation(cr >= 85 ? const Color(0xFF059669) : const Color(0xFFF59E0B)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _cfLeg(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(t, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  ]);

  Widget _cfStat(String t, String v, Color c, IconData ic) => Row(children: [
    Icon(ic, size: 14, color: c),
    const SizedBox(width: 7),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
    ])),
  ]);
}

class _CashFlowPainter extends CustomPainter {
  final List<_MonthBucket> months;
  final double maxV;
  _CashFlowPainter({required this.months, required this.maxV});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), grid);
    }
    final n = months.length;
    final gw = size.width / n;
    final bw = gw * 0.32;
    final gap = bw * 0.2;
    for (int i = 0; i < n; i++) {
      final b = months[i];
      final cx = gw * i + gw / 2;
      if (b.inv > 0) {
        final h = (b.inv / maxV) * size.height;
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw - gap / 2, size.height - h, bw, h), const Radius.circular(4)),
          Paint()..color = const Color(0xFFCBD5E1));
      }
      if (b.rev > 0) {
        final h = (b.rev / maxV) * size.height;
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + gap / 2, size.height - h, bw, h), const Radius.circular(4)),
          Paint()..color = const Color(0xFF059669));
      }
    }
  }

  @override
  bool shouldRepaint(_CashFlowPainter old) => old.months != months;
}

// ─── Status Donut ─────────────────────────────────────────────────────────────

class _StatDonut extends StatelessWidget {
  final Map<InvoiceStatus, int> cnts;
  final int total;
  final double totRev, cr;
  final String cur;
  const _StatDonut({required this.cnts, required this.total, required this.totRev, required this.cr, required this.cur});

  static const _cols = {
    InvoiceStatus.paid:          Color(0xFF059669),
    InvoiceStatus.sent:          Color(0xFF2563EB),
    InvoiceStatus.draft:         Color(0xFF94A3B8),
    InvoiceStatus.overdue:       Color(0xFFEF4444),
    InvoiceStatus.partiallyPaid: Color(0xFFF59E0B),
    InvoiceStatus.cancelled:     Color(0xFFCBD5E1),
  };

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final segs = cnts.entries.where((e) => e.value > 0)
        .map((e) => _DS(e.key.label, e.value, _cols[e.key]!)).toList();

    return _Card(
      title: 'Invoice Status',
      subtitle: '$total total invoices',
      icon: Icons.donut_large_rounded,
      iconColor: AppTheme.primary,
      child: Column(children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: total == 0
              ? const Center(child: Text('No invoices yet', style: TextStyle(color: AppTheme.textSecondary)))
              : CustomPaint(
                  painter: _DonutPainter(segs: segs, total: total),
                  child: const SizedBox.expand()),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 7, alignment: WrapAlignment.center,
            children: segs.map((s) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.c, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${s.lbl} (${s.n})', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ])).toList()),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _statMini('Revenue', '$sym${_c(totRev)}', const Color(0xFF059669))),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          Expanded(child: _statMini('Collection', '${cr.toStringAsFixed(1)}%', AppTheme.primary)),
        ]),
      ]),
    );
  }

  Widget _statMini(String t, String v, Color c) => Column(children: [
    Text(t, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    const SizedBox(height: 3),
    Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
  ]);
}

class _DS {
  final String lbl; final int n; final Color c;
  _DS(this.lbl, this.n, this.c);
}

class _DonutPainter extends CustomPainter {
  final List<_DS> segs; final int total;
  _DonutPainter({required this.segs, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 10;
    final ir = r * 0.58;
    double start = -math.pi / 2;
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = r - ir;
    for (final s in segs) {
      final sw = (s.n / total) * math.pi * 2;
      p.color = s.c;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: (r + ir) / 2), start, sw - 0.02, false, p);
      start += sw;
    }
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(text: '$total\n', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.1)),
        const TextSpan(text: 'Total', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.segs != segs;
}

// ─── Top Clients ──────────────────────────────────────────────────────────────

class _TopCliCard extends StatelessWidget {
  final List<_ClientRow> clients;
  final String cur;
  const _TopCliCard({required this.clients, required this.cur});

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final maxRev = clients.isEmpty ? 1.0 : math.max(1.0, clients.first.ltv);

    return _Card(
      title: 'Top Clients by Revenue',
      subtitle: 'Lifetime value, payment rate & activity',
      icon: Icons.people_rounded,
      iconColor: const Color(0xFF2563EB),
      child: clients.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No client data yet', style: TextStyle(color: AppTheme.textSecondary))),
            )
          : Column(children: [
              const SizedBox(height: 6),
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: const [
                  SizedBox(width: 36),
                  SizedBox(width: 10),
                  Expanded(flex: 4, child: Text('Client', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary))),
                  Expanded(flex: 3, child: Text('LTV', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary))),
                  Expanded(flex: 2, child: Text('Pay Rate', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary))),
                  Expanded(flex: 2, child: Text('Invoices', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary))),
                  Expanded(flex: 2, child: Text('Last Active', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary))),
                ]),
              ),
              const Divider(height: 1),
              ...clients.asMap().entries.map((e) {
                final c = e.value;
                final frac = c.ltv / maxRev;
                final rankColors = [
                  const Color(0xFFF59E0B), const Color(0xFF94A3B8),
                  const Color(0xFF92400E), const Color(0xFF2563EB),
                  const Color(0xFF059669), const Color(0xFF7C3AED),
                ];
                final rc = rankColors[e.key % rankColors.length];
                final idle = c.idleDays;

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: rc.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Center(child: Text('${e.key + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: rc))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(value: frac, minHeight: 4, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(rc)),
                        ),
                        if (c.churnRisk) Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(children: const [
                            Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFDB2777)),
                            SizedBox(width: 2),
                            Text('Churn risk', style: TextStyle(fontSize: 9, color: Color(0xFFDB2777), fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ])),
                      Expanded(flex: 3, child: Text('$sym${_c(c.ltv)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                      Expanded(flex: 2, child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (c.payRate >= 0.8 ? const Color(0xFF059669) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${(c.payRate * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.payRate >= 0.8 ? const Color(0xFF059669) : const Color(0xFFF59E0B))),
                        ),
                      )),
                      Expanded(flex: 2, child: Text('${c.cnt}', textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                      Expanded(flex: 2, child: Text(idle == 0 ? '—' : idle < 30 ? '${idle}d ago' : idle < 365 ? '${(idle / 30).round()}mo' : '${(idle / 365).round()}y',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, color: idle > 60 ? const Color(0xFFDB2777) : AppTheme.textSecondary))),
                    ]),
                  ),
                  const Divider(height: 1),
                ]);
              }),
            ]),
    );
  }
}

// ─── Customer Insights ────────────────────────────────────────────────────────

class _CustCard extends StatelessWidget {
  final List<_ClientRow> churn;
  final int newCnt, total;
  final double newRev, retRev;
  final String cur;
  const _CustCard({required this.churn, required this.newCnt, required this.total,
      required this.newRev, required this.retRev, required this.cur});

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final retCnt = total - newCnt;
    final totMoRev = newRev + retRev;

    return _Card(
      title: 'Customer Insights',
      subtitle: 'Retention, new clients & churn signals',
      icon: Icons.person_search_rounded,
      iconColor: const Color(0xFFDB2777),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),

        // New vs Returning
        Row(children: [
          Expanded(child: _custStat('New This Month', '$newCnt', const Color(0xFF2563EB), Icons.person_add_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _custStat('Returning', '$retCnt', const Color(0xFF059669), Icons.repeat_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _custStat('Total Clients', '$total', const Color(0xFF7C3AED), Icons.people_rounded)),
        ]),

        const SizedBox(height: 14),

        // Revenue split bar
        if (totMoRev > 0) ...[
          const Text('This Month Revenue Split', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 22,
              child: Row(children: [
                if (newRev > 0) Expanded(
                  flex: (newRev / totMoRev * 100).round(),
                  child: Container(color: const Color(0xFF2563EB),
                      child: Center(child: Text('$sym${_c(newRev)} new', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)))),
                ),
                if (retRev > 0) Expanded(
                  flex: (retRev / totMoRev * 100).round(),
                  child: Container(color: const Color(0xFF059669),
                      child: Center(child: Text('$sym${_c(retRev)} ret.', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)))),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
        ],

        const Divider(height: 1),
        const SizedBox(height: 12),

        // Churn risk
        Row(children: [
          Icon(Icons.person_off_rounded, size: 14, color: churn.isEmpty ? const Color(0xFF059669) : const Color(0xFFDB2777)),
          const SizedBox(width: 6),
          Text('Churn Risk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: churn.isEmpty ? const Color(0xFF059669) : const Color(0xFFDB2777))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (churn.isEmpty ? const Color(0xFF059669) : const Color(0xFFDB2777)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(churn.isEmpty ? 'All clear' : '${churn.length} at risk',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: churn.isEmpty ? const Color(0xFF059669) : const Color(0xFFDB2777))),
          ),
        ]),

        if (churn.isEmpty) ...[
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF059669)),
            SizedBox(width: 6),
            Text('All clients active in the last 60 days.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ] else ...[
          const SizedBox(height: 8),
          ...churn.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: const Color(0xFFDB2777).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Center(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDB2777)))),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${c.idleDays}d idle', style: const TextStyle(fontSize: 11, color: Color(0xFFDB2777), fontWeight: FontWeight.w600)),
            ]),
          )),
        ],

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Retention rate
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Retention Rate', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ])),
          Text(total > 0 ? '${((retCnt / total) * 100).toStringAsFixed(0)}%' : '—',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? retCnt / total : 0,
            minHeight: 7,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF059669)),
          ),
        ),
        const SizedBox(height: 4),
        Text('$retCnt of $total clients are returning customers',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _custStat(String t, String v, Color c, IconData ic) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Icon(ic, size: 16, color: c),
      const SizedBox(height: 4),
      Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
      Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary), maxLines: 2),
    ]),
  );
}

// ─── Revenue by Product ───────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final List<_ProductRow> products;
  final double totRev;
  final String cur;
  const _ProductCard({required this.products, required this.totRev, required this.cur});

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final maxRev = products.isEmpty ? 1.0 : math.max(1.0, products.first.revenue);

    final colors = [
      const Color(0xFF2563EB), const Color(0xFF059669), const Color(0xFF7C3AED),
      const Color(0xFFDB2777), const Color(0xFFF59E0B), const Color(0xFF0891B2),
      const Color(0xFFEA580C), const Color(0xFF64748B),
    ];

    return _Card(
      title: 'Revenue by Product / Service',
      subtitle: 'Top items from paid invoices',
      icon: Icons.inventory_2_rounded,
      iconColor: const Color(0xFF7C3AED),
      child: Column(children: [
        const SizedBox(height: 8),
        ...products.asMap().entries.map((e) {
          final p = e.value;
          final frac = p.revenue / maxRev;
          final pct = totRev > 0 ? p.revenue / totRev * 100 : 0.0;
          final c = colors[e.key % colors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: Text(p.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 5, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: frac, minHeight: 8, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(c)),
                ),
              )),
              SizedBox(width: 70, child: Text('$sym${_c(p.revenue)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
              SizedBox(width: 42, child: Text('${pct.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600))),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─── Overdue Aging ────────────────────────────────────────────────────────────

class _OverdueCard extends StatelessWidget {
  final int b1, b2, b3, b4;
  final double a1, a2, a3, a4;
  final String cur;
  const _OverdueCard({required this.b1, required this.b2, required this.b3, required this.b4,
      required this.a1, required this.a2, required this.a3, required this.a4, required this.cur});

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final total = b1 + b2 + b3 + b4;
    final totAmt = a1 + a2 + a3 + a4;

    return _Card(
      title: 'Overdue Aging',
      subtitle: '$total overdue invoice${total != 1 ? "s" : ""} · $sym${_c(totAmt)}',
      icon: Icons.warning_amber_rounded,
      iconColor: total == 0 ? const Color(0xFF059669) : const Color(0xFFEF4444),
      child: total == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline, size: 44, color: const Color(0xFF059669).withValues(alpha: 0.7)),
                const SizedBox(height: 10),
                const Text('No overdue invoices', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                const Text('All caught up!', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            )
          : Column(children: [
              const SizedBox(height: 10),
              _ageBucket('1–7 days',   b1, total, a1, sym, const Color(0xFFF59E0B)),
              _ageBucket('8–30 days',  b2, total, a2, sym, const Color(0xFFEF4444).withValues(alpha: 0.7)),
              _ageBucket('31–60 days', b3, total, a3, sym, const Color(0xFFEF4444)),
              _ageBucket('60+ days',   b4, total, a4, sym, const Color(0xFF7F1D1D).withValues(alpha: 0.85)),
              const SizedBox(height: 14),
              if (b3 + b4 > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '${b3 + b4} invoice${b3 + b4 > 1 ? "s" : ""} 30+ days overdue ($sym${_c(a3 + a4)}). Escalate now.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                    )),
                  ]),
                ),
            ]),
    );
  }

  Widget _ageBucket(String lbl, int cnt, int total, double amt, String sym, Color c) {
    if (cnt == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 72, child: Text(lbl, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: total > 0 ? cnt / total : 0, minHeight: 8, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(c)),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 22, child: Text('$cnt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c))),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 72, top: 2),
          child: Text('$sym${_c(amt)}', style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── Revenue Forecast ─────────────────────────────────────────────────────────

class _FcstCard extends StatelessWidget {
  final List<_FPt> pts;
  final String cur;
  const _FcstCard({required this.pts, required this.cur});

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(cur);
    final maxV = pts.fold(0.0, (m, p) => math.max(m, p.v));
    final projected = pts.where((p) => p.proj).toList();
    final nextMoRev = projected.isNotEmpty ? projected.first.v : 0.0;
    final nextNext  = projected.length > 1 ? projected[1].v : 0.0;
    final trend     = nextMoRev > 0 && pts.length >= 2
        ? (nextMoRev - pts[pts.length - 4].v) / math.max(1, pts[pts.length - 4].v) * 100
        : 0.0;

    return _Card(
      title: 'Revenue Forecast',
      subtitle: 'Linear trend projection — next 3 months',
      icon: Icons.trending_up_rounded,
      iconColor: const Color(0xFF7C3AED),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),

        // Forecast numbers
        Row(children: [
          Expanded(child: _fcstStat(projected.isNotEmpty ? projected[0].lbl : 'Next mo.',
              '$sym${_c(nextMoRev)}', const Color(0xFF7C3AED), Icons.calendar_month_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _fcstStat(projected.length > 1 ? projected[1].lbl : '+2 mo.',
              '$sym${_c(nextNext)}', const Color(0xFF2563EB), Icons.calendar_month_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _fcstStat('Trend',
              '${trend >= 0 ? "+" : ""}${trend.toStringAsFixed(1)}%',
              trend >= 0 ? const Color(0xFF059669) : const Color(0xFFEF4444),
              trend >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
        ]),

        const SizedBox(height: 16),

        // Chart
        SizedBox(
          height: 160,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SizedBox(
              width: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) => Text(_c(maxV * (4 - i) / 4),
                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: CustomPaint(
              painter: _FcstPainter(pts: pts, maxV: maxV == 0 ? 1 : maxV),
              child: const SizedBox.expand(),
            )),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: Row(children: pts.map((p) => Expanded(child: Text(p.lbl,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8.5, color: p.proj ? const Color(0xFF7C3AED) : AppTheme.textSecondary,
                  fontWeight: p.proj ? FontWeight.w600 : FontWeight.normal)))).toList()),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _fcstLeg(const Color(0xFF2563EB), 'Actual'),
          const SizedBox(width: 16),
          _fcstLeg(const Color(0xFF7C3AED).withValues(alpha: 0.5), 'Projected'),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 13, color: Color(0xFF7C3AED)),
            const SizedBox(width: 7),
            Expanded(child: Text(
              'Forecast uses linear trend from last 6 months. Actual results may vary based on seasonality and new clients.',
              style: const TextStyle(fontSize: 10, color: Color(0xFF6D28D9)),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _fcstStat(String t, String v, Color c, IconData ic) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(ic, size: 13, color: c), const SizedBox(width: 4), Text(t, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 4),
      Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
    ]),
  );

  Widget _fcstLeg(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(t, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  ]);
}

class _FcstPainter extends CustomPainter {
  final List<_FPt> pts;
  final double maxV;
  _FcstPainter({required this.pts, required this.maxV});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), grid);
    }
    final n = pts.length;
    final gw = size.width / n;
    final bw = gw * 0.55;
    for (int i = 0; i < n; i++) {
      final p = pts[i];
      if (p.v <= 0) continue;
      final h = (p.v / maxV) * size.height;
      final cx = gw * i + gw / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - bw / 2, size.height - h, bw, h), const Radius.circular(4)),
        Paint()..color = p.proj
            ? const Color(0xFF7C3AED).withValues(alpha: 0.45)
            : const Color(0xFF2563EB),
      );
    }
  }

  @override
  bool shouldRepaint(_FcstPainter o) => o.pts != pts;
}

// ─── Recent Invoices ──────────────────────────────────────────────────────────

class _RecTable extends StatelessWidget {
  final List<Invoice> invoices;
  const _RecTable({required this.invoices});

  static const _sc = {
    InvoiceStatus.paid:          Color(0xFF059669),
    InvoiceStatus.sent:          Color(0xFF2563EB),
    InvoiceStatus.draft:         Color(0xFF64748B),
    InvoiceStatus.overdue:       Color(0xFFEF4444),
    InvoiceStatus.partiallyPaid: Color(0xFFF59E0B),
    InvoiceStatus.cancelled:     Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Recent Invoices',
      subtitle: 'Latest ${invoices.length} invoices',
      icon: Icons.receipt_long_rounded,
      iconColor: AppTheme.primary,
      child: invoices.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No invoices yet', style: TextStyle(color: AppTheme.textSecondary))),
            )
          : Column(children: [
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: const [
                  Expanded(flex: 3, child: _TH('Invoice #')),
                  Expanded(flex: 4, child: _TH('Client')),
                  Expanded(flex: 2, child: _TH('Date')),
                  Expanded(flex: 2, child: _TH('Due')),
                  Expanded(flex: 3, child: _TH('Amount', right: true)),
                  Expanded(flex: 2, child: _TH('Status', center: true)),
                ]),
              ),
              const Divider(height: 1),
              ...invoices.map((inv) => _InvRow(invoice: inv, sc: _sc[inv.status] ?? AppTheme.textSecondary)),
            ]),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right, center;
  const _TH(this.text, {this.right = false, this.center = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: right ? TextAlign.right : center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.4));
}

class _InvRow extends StatefulWidget {
  final Invoice invoice;
  final Color sc;
  const _InvRow({required this.invoice, required this.sc});
  @override
  State<_InvRow> createState() => _InvRowState();
}

class _InvRowState extends State<_InvRow> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: inv))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hov ? const Color(0xFFF1F5F9) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(children: [
            Expanded(flex: 3, child: Text(inv.invoiceNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary))),
            Expanded(flex: 4, child: Text(inv.client?.displayName ?? '—', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(Fmt.shortDate(inv.invoiceDate), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
            Expanded(flex: 2, child: Text(Fmt.shortDate(inv.dueDate), style: TextStyle(fontSize: 11, color: inv.isOverdue ? const Color(0xFFEF4444) : AppTheme.textSecondary))),
            Expanded(flex: 3, child: Text(Fmt.currencyAmount(inv.grandTotal, inv.currency), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
            Expanded(flex: 2, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: widget.sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(inv.status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.sc)),
            ))),
          ]),
        ),
      ),
    );
  }
}

// ─── Shared card wrapper ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _Card({
    required this.title, required this.subtitle,
    required this.icon,  required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ]),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        child,
      ]),
    );
  }
}
