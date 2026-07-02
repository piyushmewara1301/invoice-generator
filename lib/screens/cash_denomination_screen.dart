import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

// Standard Indian currency note & coin denominations.
const List<int> _denominations = [2000, 500, 200, 100, 50, 20, 10, 5, 2, 1];

class CashDenominationScreen extends StatefulWidget {
  const CashDenominationScreen({super.key, this.expectedAmount});

  /// Optional expected closing-cash figure to pre-fill (e.g. from Cash Book).
  final double? expectedAmount;

  @override
  State<CashDenominationScreen> createState() =>
      _CashDenominationScreenState();
}

class _CashDenominationScreenState extends State<CashDenominationScreen> {
  final Map<int, TextEditingController> _controllers = {
    for (final d in _denominations) d: TextEditingController(),
  };
  late final TextEditingController _expectedCtrl;

  @override
  void initState() {
    super.initState();
    _expectedCtrl = TextEditingController(
      text: widget.expectedAmount != null && widget.expectedAmount != 0
          ? _trimZeros(widget.expectedAmount!)
          : '',
    );
  }

  String _trimZeros(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _expectedCtrl.dispose();
    super.dispose();
  }

  double get _total {
    double sum = 0;
    for (final d in _denominations) {
      final count = int.tryParse(_controllers[d]!.text) ?? 0;
      sum += count * d;
    }
    return sum;
  }

  int get _totalPieces {
    int sum = 0;
    for (final d in _denominations) {
      sum += int.tryParse(_controllers[d]!.text) ?? 0;
    }
    return sum;
  }

  void _changeCount(int denom, int delta) {
    final ctrl = _controllers[denom]!;
    final current = int.tryParse(ctrl.text) ?? 0;
    final next = (current + delta).clamp(0, 999999);
    setState(() => ctrl.text = next == 0 ? '' : next.toString());
  }

  void _reset() {
    setState(() {
      for (final c in _controllers.values) {
        c.clear();
      }
      _expectedCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = provider.profile.currency;
    final sym = Fmt.currencySymbol(currency);
    final expected = double.tryParse(_expectedCtrl.text.trim());
    final diff = (expected != null) ? _total - expected : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _denominations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = _denominations[i];
                return _DenomRow(
                  denom: d,
                  symbol: sym,
                  controller: _controllers[d]!,
                  onChanged: () => setState(() {}),
                  onIncrement: () => _changeCount(d, 1),
                  onDecrement: () => _changeCount(d, -1),
                );
              },
            ),
          ),
          _TotalsCard(
            total: _total,
            totalPieces: _totalPieces,
            symbol: sym,
            currency: currency,
            expectedCtrl: _expectedCtrl,
            diff: diff,
            onExpectedChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

// ── Denomination row ─────────────────────────────────────────────────────────

class _DenomRow extends StatelessWidget {
  final int denom;
  final String symbol;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _DenomRow({
    required this.denom,
    required this.symbol,
    required this.controller,
    required this.onChanged,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(controller.text) ?? 0;
    final subtotal = count * denom;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$symbol$denom',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context),
              ),
            ),
          ),
          Icon(Icons.close, size: 14, color: AppTheme.subtext(context)),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.remove,
            onTap: count > 0 ? onDecrement : null,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppTheme.onCard(context)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppTheme.outline(context)),
                ),
                hintText: '0',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 6),
          _StepButton(icon: Icons.add, onTap: onIncrement),
          const Spacer(),
          Text(
            subtotal > 0 ? Fmt.compact(subtotal.toDouble()) : '—',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: subtotal > 0
                  ? AppTheme.primary
                  : AppTheme.subtext(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.08)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16,
            color: active ? AppTheme.primary : AppTheme.subtext(context)),
      ),
    );
  }
}

// ── Totals & reconciliation ──────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final double total;
  final int totalPieces;
  final String symbol;
  final String currency;
  final TextEditingController expectedCtrl;
  final double? diff;
  final VoidCallback onExpectedChanged;

  const _TotalsCard({
    required this.total,
    required this.totalPieces,
    required this.symbol,
    required this.currency,
    required this.expectedCtrl,
    required this.diff,
    required this.onExpectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        border: Border(top: BorderSide(color: AppTheme.outline(context))),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Counted',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtext(context))),
                  const SizedBox(height: 2),
                  Text('$totalPieces note${totalPieces == 1 ? '' : 's'}/coins',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.subtext(context))),
                ],
              ),
              Text(
                Fmt.currencyAmount(total, currency),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: expectedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Expected Closing Cash (optional)',
              prefixText: symbol,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) => onExpectedChanged(),
          ),
          if (diff != null) ...[
            const SizedBox(height: 10),
            _DiffBanner(diff: diff!, currency: currency),
          ],
        ],
      ),
    );
  }
}

class _DiffBanner extends StatelessWidget {
  final double diff;
  final String currency;

  const _DiffBanner({required this.diff, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isMatch = diff.abs() < 0.005;
    final isExcess = diff > 0;
    final color = isMatch
        ? const Color(0xFF0D9488)
        : (isExcess ? AppTheme.warning : AppTheme.error);
    final label = isMatch
        ? 'Matches expected cash'
        : isExcess
            ? 'Excess of ${Fmt.currencyAmount(diff, currency)}'
            : 'Short by ${Fmt.currencyAmount(diff.abs(), currency)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isMatch
                ? Icons.check_circle_outline
                : (isExcess
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
