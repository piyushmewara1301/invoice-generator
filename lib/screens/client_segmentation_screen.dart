import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'bulk_offer_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Revenue tier — lifetime paid revenue from this client.
// ─────────────────────────────────────────────────────────────────────────────

enum _RevenueTier {
  high,   // ≥ ₹1,00,000
  medium, // ₹10,000 – ₹99,999
  low;    // < ₹10,000

  String get label => switch (this) {
        _RevenueTier.high   => 'High (₹1L+)',
        _RevenueTier.medium => 'Medium',
        _RevenueTier.low    => 'Low (<₹10K)',
      };

  Color get color => switch (this) {
        _RevenueTier.high   => const Color(0xFF059669),
        _RevenueTier.medium => const Color(0xFF2563EB),
        _RevenueTier.low    => const Color(0xFF64748B),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment behaviour — based on outstanding / overdue counts.
// ─────────────────────────────────────────────────────────────────────────────

enum _PaymentBehavior {
  good,        // zero overdue invoices
  atRisk,      // 1 overdue
  delinquent;  // 2+ overdue

  String get label => switch (this) {
        _PaymentBehavior.good       => 'Good Payer',
        _PaymentBehavior.atRisk     => 'At Risk',
        _PaymentBehavior.delinquent => 'Delinquent',
      };

  Color get color => switch (this) {
        _PaymentBehavior.good       => const Color(0xFF059669),
        _PaymentBehavior.atRisk     => const Color(0xFFD97706),
        _PaymentBehavior.delinquent => AppTheme.error,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-client computed statistics
// ─────────────────────────────────────────────────────────────────────────────

class _ClientStats {
  final Client client;
  final double lifetimeRevenue;
  final double outstanding;
  final int invoiceCount;
  final int overdueCount;

  const _ClientStats({
    required this.client,
    required this.lifetimeRevenue,
    required this.outstanding,
    required this.invoiceCount,
    required this.overdueCount,
  });

  _RevenueTier get revenueTier {
    if (lifetimeRevenue >= 100000) return _RevenueTier.high;
    if (lifetimeRevenue >= 10000) return _RevenueTier.medium;
    return _RevenueTier.low;
  }

  _PaymentBehavior get paymentBehavior {
    if (overdueCount == 0) return _PaymentBehavior.good;
    if (overdueCount == 1) return _PaymentBehavior.atRisk;
    return _PaymentBehavior.delinquent;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Industry list — curated for Indian SMBs
// ─────────────────────────────────────────────────────────────────────────────

const _kIndustries = [
  'Technology',
  'Manufacturing',
  'Retail & E-commerce',
  'Healthcare',
  'Education',
  'Food & Beverage',
  'Construction',
  'Professional Services',
  'Finance & Accounting',
  'Real Estate',
  'Transport & Logistics',
  'Media & Advertising',
  'Other',
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ClientSegmentationScreen extends StatefulWidget {
  const ClientSegmentationScreen({super.key});

  @override
  State<ClientSegmentationScreen> createState() =>
      _ClientSegmentationScreenState();
}

class _ClientSegmentationScreenState extends State<ClientSegmentationScreen> {
  // ── Active filters ────────────────────────────────────────────────────────
  _RevenueTier? _tierFilter;
  _PaymentBehavior? _behaviorFilter;
  String? _stateFilter;
  String? _industryFilter;
  String _search = '';

  // ── Selection ─────────────────────────────────────────────────────────────
  final Set<String> _selected = {};

  // ── Compute stats from invoices once per build ────────────────────────────
  List<_ClientStats> _computeStats(
      List<Client> clients, List<Invoice> invoices) {
    return clients.map((client) {
      final ci = invoices.where((inv) =>
          inv.client?.id == client.id &&
          !inv.isQuotation &&
          !inv.isCreditNote &&
          !inv.isDeliveryChallan);
      final revenue = ci
          .where((inv) => inv.status == InvoiceStatus.paid)
          .fold(0.0, (s, inv) => s + inv.grandTotal);
      final outstanding = ci
          .where((inv) => inv.amountRemaining > 0)
          .fold(0.0, (s, inv) => s + inv.amountRemaining);
      final overdueCount = ci.where((inv) => inv.isOverdue).length;
      return _ClientStats(
        client: client,
        lifetimeRevenue: revenue,
        outstanding: outstanding,
        invoiceCount: ci.length,
        overdueCount: overdueCount,
      );
    }).toList();
  }

  // ── Apply filters ─────────────────────────────────────────────────────────
  List<_ClientStats> _apply(List<_ClientStats> all) {
    var list = all;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) {
        final c = s.client;
        return c.displayName.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            (c.state.toLowerCase().contains(q)) ||
            (c.industry?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    if (_tierFilter != null) {
      list = list.where((s) => s.revenueTier == _tierFilter).toList();
    }
    if (_behaviorFilter != null) {
      list = list.where((s) => s.paymentBehavior == _behaviorFilter).toList();
    }
    if (_stateFilter != null) {
      list = list
          .where((s) => s.client.state == _stateFilter)
          .toList();
    }
    if (_industryFilter != null) {
      list = list
          .where((s) => s.client.industry == _industryFilter)
          .toList();
    }
    // Sort: delinquent first, then by outstanding desc.
    list.sort((a, b) {
      final bOrd = b.paymentBehavior.index.compareTo(a.paymentBehavior.index);
      if (bOrd != 0) return bOrd;
      return b.outstanding.compareTo(a.outstanding);
    });
    return list;
  }

  // ── Industry quick-set ────────────────────────────────────────────────────
  Future<void> _setIndustry(Client client) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set Industry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onCard(ctx),
                      ),
                    ),
                  ),
                  if (client.industry != null)
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: const Text('Clear',
                          style: TextStyle(color: AppTheme.error)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _kIndustries.map((ind) {
                  final sel = client.industry == ind;
                  return ListTile(
                    dense: true,
                    title: Text(ind,
                        style: TextStyle(
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: sel
                              ? AppTheme.primary
                              : AppTheme.onCard(ctx),
                        )),
                    trailing: sel
                        ? const Icon(Icons.check_rounded,
                            color: AppTheme.primary, size: 18)
                        : null,
                    onTap: () => Navigator.pop(ctx, ind),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    final provider = context.read<AppProvider>();
    client.industry = picked.isEmpty ? null : picked;
    await provider.updateClient(client);
  }

  // ── Bulk actions ──────────────────────────────────────────────────────────
  void _bulkSend(_Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BulkOfferScreen(initialSelectedIds: Set.of(_selected)),
      ),
    );
  }

  // ── Segment summary card ──────────────────────────────────────────────────
  bool get _hasFilters =>
      _tierFilter != null ||
      _behaviorFilter != null ||
      _stateFilter != null ||
      _industryFilter != null;

  int get _activeFilterCount => [
        _tierFilter,
        _behaviorFilter,
        _stateFilter,
        _industryFilter,
      ].where((f) => f != null).length;

  void _clearFilters() => setState(() {
        _tierFilter = null;
        _behaviorFilter = null;
        _stateFilter = null;
        _industryFilter = null;
      });

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allStats = _computeStats(provider.clients, provider.invoicesOnly);
    final filtered = _apply(allStats);

    // Unique states & industries present in full client list (not filtered).
    final allStates = allStats
        .map((s) => s.client.state)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final allIndustries = allStats
        .map((s) => s.client.industry)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final totalRevenue =
        filtered.fold(0.0, (s, c) => s + c.lifetimeRevenue);
    final totalOutstanding =
        filtered.fold(0.0, (s, c) => s + c.outstanding);
    final sym = Fmt.currencySymbol(provider.profile.currency);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Client Segments'),
        backgroundColor: AppTheme.card(context),
        foregroundColor: AppTheme.onCard(context),
        elevation: 0,
        actions: [
          if (_hasFilters)
            TextButton(
              onPressed: _clearFilters,
              child: Text(
                'Clear ($_activeFilterCount)',
                style: const TextStyle(color: AppTheme.primary),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search ───────────────────────────────────────────────────
          Container(
            color: AppTheme.card(context),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search clients…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() {
                _search = v.trim();
                _selected.clear();
              }),
            ),
          ),

          // ── Filter chips ─────────────────────────────────────────────
          Container(
            color: AppTheme.card(context),
            child: Column(
              children: [
                const Divider(height: 1),
                _FilterRow(children: [
                  _FilterChip(
                    icon: Icons.bar_chart_outlined,
                    label: _tierFilter?.label ?? 'Revenue',
                    active: _tierFilter != null,
                    onTap: () => _showTierFilter(context),
                  ),
                  _FilterChip(
                    icon: Icons.payments_outlined,
                    label: _behaviorFilter?.label ?? 'Payment',
                    active: _behaviorFilter != null,
                    onTap: () => _showBehaviorFilter(context),
                  ),
                  _FilterChip(
                    icon: Icons.location_on_outlined,
                    label: _stateFilter ?? 'State',
                    active: _stateFilter != null,
                    onTap: () => _showStateFilter(context, allStates),
                  ),
                  _FilterChip(
                    icon: Icons.business_outlined,
                    label: _industryFilter ?? 'Industry',
                    active: _industryFilter != null,
                    onTap: () => _showIndustryFilter(context, allIndustries),
                  ),
                ]),
                const Divider(height: 1),
              ],
            ),
          ),

          // ── Stats bar ────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _StatPill(
                    '${filtered.length} client${filtered.length == 1 ? '' : 's'}',
                    AppTheme.primary),
                const SizedBox(width: 8),
                _StatPill(
                    '$sym${Fmt.compact(totalRevenue)} revenue',
                    const Color(0xFF059669)),
                const SizedBox(width: 8),
                if (totalOutstanding > 0)
                  _StatPill(
                      '$sym${Fmt.compact(totalOutstanding)} due',
                      AppTheme.error),
              ],
            ),
          ),

          // ── Select-all bar ───────────────────────────────────────────
          if (filtered.isNotEmpty)
            Container(
              color: AppTheme.card(context),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _selected.length == filtered.length &&
                        filtered.isNotEmpty,
                    tristate: false,
                    activeColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) {
                      setState(() {
                        if (_selected.length == filtered.length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(
                              filtered.map((s) => s.client.id));
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selected.isEmpty
                        ? 'Select all ${filtered.length}'
                        : '${_selected.length} selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _selected.isEmpty
                          ? AppTheme.subtext(context)
                          : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // ── Client list ──────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(hasFilters: _hasFilters || _search.isNotEmpty)
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) {
                      final stats = filtered[i];
                      return _ClientRow(
                        stats: stats,
                        currency: sym,
                        selected: _selected.contains(stats.client.id),
                        onToggle: () => setState(() {
                          if (_selected.contains(stats.client.id)) {
                            _selected.remove(stats.client.id);
                          } else {
                            _selected.add(stats.client.id);
                          }
                        }),
                        onSetIndustry: () => _setIndustry(stats.client),
                      );
                    },
                  ),
          ),

          // ── Bulk action bar ──────────────────────────────────────────
          if (_selected.isNotEmpty)
            _BulkActionBar(
              count: _selected.length,
              onWhatsApp: () => _bulkSend(_Channel.whatsapp),
              onEmail: () => _bulkSend(_Channel.email),
              onClear: () => setState(() => _selected.clear()),
            ),
        ],
      ),
    );
  }

  // ── Filter bottom-sheet helpers ───────────────────────────────────────────

  void _showTierFilter(BuildContext context) => _showPickSheet(
        context: context,
        title: 'Revenue Tier',
        options: _RevenueTier.values
            .map((t) => _PickOption(t.label, t == _tierFilter))
            .toList(),
        onPick: (i) => setState(() =>
            _tierFilter = _tierFilter == _RevenueTier.values[i]
                ? null
                : _RevenueTier.values[i]),
        onClear: () => setState(() => _tierFilter = null),
        hasValue: _tierFilter != null,
      );

  void _showBehaviorFilter(BuildContext context) => _showPickSheet(
        context: context,
        title: 'Payment Behavior',
        options: _PaymentBehavior.values
            .map((b) => _PickOption(b.label, b == _behaviorFilter))
            .toList(),
        onPick: (i) => setState(() =>
            _behaviorFilter = _behaviorFilter == _PaymentBehavior.values[i]
                ? null
                : _PaymentBehavior.values[i]),
        onClear: () => setState(() => _behaviorFilter = null),
        hasValue: _behaviorFilter != null,
      );

  void _showStateFilter(BuildContext context, List<String> states) {
    if (states.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No state data on your clients yet.')),
      );
      return;
    }
    _showPickSheet(
      context: context,
      title: 'State',
      options:
          states.map((s) => _PickOption(s, s == _stateFilter)).toList(),
      onPick: (i) => setState(() =>
          _stateFilter = _stateFilter == states[i] ? null : states[i]),
      onClear: () => setState(() => _stateFilter = null),
      hasValue: _stateFilter != null,
    );
  }

  void _showIndustryFilter(
      BuildContext context, List<String> industries) {
    final options = industries.isEmpty ? _kIndustries : industries;
    _showPickSheet(
      context: context,
      title: 'Industry',
      options:
          options.map((s) => _PickOption(s, s == _industryFilter)).toList(),
      onPick: (i) => setState(() =>
          _industryFilter =
              _industryFilter == options[i] ? null : options[i]),
      onClear: () => setState(() => _industryFilter = null),
      hasValue: _industryFilter != null,
    );
  }

  void _showPickSheet({
    required BuildContext context,
    required String title,
    required List<_PickOption> options,
    required void Function(int) onPick,
    required VoidCallback onClear,
    required bool hasValue,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (hasValue)
                    TextButton(
                        onPressed: () {
                          onClear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear',
                            style: TextStyle(color: AppTheme.error))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  title: Text(options[i].label,
                      style: TextStyle(
                        fontWeight: options[i].selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: options[i].selected
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                      )),
                  trailing: options[i].selected
                      ? const Icon(Icons.check_rounded,
                          color: AppTheme.primary, size: 18)
                      : null,
                  onTap: () {
                    onPick(i);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter row — horizontally scrollable
// ─────────────────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final List<Widget> children;
  const _FilterRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(spacing: 8, children: children),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.divider,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    active ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w500,
                color: active
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: active ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat pill
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client row
// ─────────────────────────────────────────────────────────────────────────────

class _ClientRow extends StatelessWidget {
  final _ClientStats stats;
  final String currency;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onSetIndustry;

  const _ClientRow({
    required this.stats,
    required this.currency,
    required this.selected,
    required this.onToggle,
    required this.onSetIndustry,
  });

  @override
  Widget build(BuildContext context) {
    final c = stats.client;
    final behavior = stats.paymentBehavior;
    final tier = stats.revenueTier;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: selected,
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 4),

            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tier.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  c.displayName.isNotEmpty
                      ? c.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tier.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (c.state.isNotEmpty) ...[
                        Icon(Icons.location_on_outlined,
                            size: 11,
                            color: AppTheme.subtext(context)),
                        const SizedBox(width: 2),
                        Text(c.state,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.subtext(context))),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: onSetIndustry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary
                                .withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.industry ?? '+ Industry',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: c.industry != null
                                  ? AppTheme.primary
                                  : AppTheme.subtext(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right column: amounts + badges
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Revenue tier badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: tier.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    tier == _RevenueTier.high
                        ? 'High'
                        : tier == _RevenueTier.medium
                            ? 'Med'
                            : 'Low',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tier.color),
                  ),
                ),
                const SizedBox(height: 4),
                // Payment behavior badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: behavior.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (behavior != _PaymentBehavior.good)
                        Icon(Icons.warning_amber_rounded,
                            size: 9, color: behavior.color),
                      if (behavior != _PaymentBehavior.good)
                        const SizedBox(width: 2),
                      Text(
                        behavior == _PaymentBehavior.good
                            ? 'Good'
                            : behavior == _PaymentBehavior.atRisk
                                ? 'At Risk'
                                : 'Overdue',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: behavior.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (stats.outstanding > 0)
                  Text(
                    '$currency${Fmt.compact(stats.outstanding)} due',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulk action bar (appears when selection > 0)
// ─────────────────────────────────────────────────────────────────────────────

class _BulkActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final VoidCallback onClear;

  const _BulkActionBar({
    required this.count,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        border:
            Border(top: BorderSide(color: AppTheme.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              '$count selected',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            const Spacer(),
            // WhatsApp
            _ActionBtn(
              icon: Icons.message_outlined,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: onWhatsApp,
            ),
            const SizedBox(width: 8),
            // Email
            _ActionBtn(
              icon: Icons.email_outlined,
              label: 'Email',
              color: AppTheme.primary,
              onTap: onEmail,
            ),
            const SizedBox(width: 8),
            // Clear
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              color: AppTheme.textSecondary,
              tooltip: 'Clear selection',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.filter_list_off : Icons.people_outline,
            size: 48,
            color: AppTheme.subtext(context),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No clients match these filters'
                : 'No clients yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onCard(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try removing some filters'
                : 'Add clients from the Clients tab',
            style: TextStyle(
                fontSize: 13, color: AppTheme.subtext(context)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

class _PickOption {
  final String label;
  final bool selected;
  const _PickOption(this.label, this.selected);
}

// Sentinel for the channel enum used in _bulkSend.
enum _Channel { whatsapp, email }
