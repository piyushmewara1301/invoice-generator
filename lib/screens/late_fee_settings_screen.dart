import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/late_fee_calculator.dart';

class LateFeeSettingsScreen extends StatefulWidget {
  const LateFeeSettingsScreen({super.key});

  @override
  State<LateFeeSettingsScreen> createState() =>
      _LateFeeSettingsScreenState();
}

class _LateFeeSettingsScreenState extends State<LateFeeSettingsScreen> {
  // Local copies of the three settings — saved on "Save".
  late bool _enabled;
  late double _ratePercent;
  late int _graceDays;

  bool _saving = false;

  static const _rates = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0];
  static const _graces = [0, 7, 14, 30];

  // Preview parameters — a ₹10,000 invoice 45 days overdue.
  static const _previewOutstanding = 10000.0;
  static const _previewDaysOverdue = 45;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>().profile;
    _enabled = p.lateFeeEnabled;
    _ratePercent = p.lateFeePercent;
    _graceDays = p.gracePeriodDays;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final updated = provider.profile
      ..lateFeeEnabled = _enabled
      ..lateFeePercent = _ratePercent
      ..gracePeriodDays = _graceDays;
    await provider.updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _enabled
              ? 'Late payment penalty enabled (${_ratePercent.toStringAsFixed(1)}%/month)'
              : 'Late payment penalty disabled',
        ),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = LateFeeCalculator.preview(
      outstanding: _previewOutstanding,
      daysOverdue: _previewDaysOverdue,
      monthlyRatePercent: _ratePercent,
      gracePeriodDays: _graceDays,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Late Payment Penalty')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // ── Master toggle ─────────────────────────────────────────────
          _card(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (_enabled ? AppTheme.error : AppTheme.subtext(context))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    color: _enabled
                        ? AppTheme.error
                        : AppTheme.subtext(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Late Payment Penalty',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onCard(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Auto-calculate accrued interest on overdue invoices.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(context),
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeThumbColor: AppTheme.error,
                  activeTrackColor: AppTheme.error.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),

          if (_enabled) ...[
            const SizedBox(height: 16),

            // ── Rate selector ───────────────────────────────────────────
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Monthly Interest Rate'),
                  const SizedBox(height: 4),
                  Text(
                    'Applied to the outstanding balance each month overdue.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext(context),
                        height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _rates.map((r) {
                      final sel = r == _ratePercent;
                      return _Chip(
                        label: '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}%',
                        selected: sel,
                        onTap: () => setState(() => _ratePercent = r),
                        selectedColor: AppTheme.error,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_ratePercent.toStringAsFixed(1)}% / month  ≈  '
                    '${(_ratePercent * 12).toStringAsFixed(1)}% per annum',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext(context),
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Grace period selector ───────────────────────────────────
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Grace Period'),
                  const SizedBox(height: 4),
                  Text(
                    'Penalty starts only after this many days past the due date.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext(context),
                        height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: _graces.map((d) {
                      final sel = d == _graceDays;
                      return _Chip(
                        label: d == 0 ? 'No grace' : '$d days',
                        selected: sel,
                        onTap: () => setState(() => _graceDays = d),
                        selectedColor: AppTheme.error,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Live preview ────────────────────────────────────────────
            _PreviewCard(
              preview: preview,
              daysOverdue: _previewDaysOverdue,
              graceDays: _graceDays,
            ),
            const SizedBox(height: 16),

            // ── Disclosure ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.primary.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Penalty amounts are informational — they appear in the '
                      'Outstanding Analysis report and on invoice detail views. '
                      'They do not automatically modify the invoice total or '
                      'create payment records. You can mention the penalty '
                      'clause in your invoice Terms.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext(context),
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Save button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _enabled ? AppTheme.error : AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _enabled ? 'Save & Enable' : 'Save (disabled)',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: child,
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.onCard(context),
        ),
      );
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.1)
              : AppTheme.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : AppTheme.outline(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? selectedColor : AppTheme.subtext(context),
          ),
        ),
      ),
    );
  }
}

// ── Live preview card ─────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final LateFeeResult preview;
  final int daysOverdue;
  final int graceDays;

  const _PreviewCard({
    required this.preview,
    required this.daysOverdue,
    required this.graceDays,
  });

  @override
  Widget build(BuildContext context) {
    final billableDays = preview.billableDays;
    final hasPenalty = preview.hasPenalty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPenalty
            ? AppTheme.error.withValues(alpha: 0.05)
            : AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPenalty
              ? AppTheme.error.withValues(alpha: 0.25)
              : AppTheme.outline(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined,
                  size: 16,
                  color: hasPenalty
                      ? AppTheme.error
                      : AppTheme.subtext(context)),
              const SizedBox(width: 8),
              Text(
                'Live Preview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasPenalty
                      ? AppTheme.error
                      : AppTheme.subtext(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹10,000 invoice, $daysOverdue days overdue:',
            style: TextStyle(
                fontSize: 13, color: AppTheme.subtext(context)),
          ),
          const SizedBox(height: 8),
          if (graceDays > 0 && billableDays < daysOverdue) ...[
            _row(context, 'Grace period', '$graceDays days'),
            _row(context, 'Billable days',
                '$billableDays day${billableDays == 1 ? '' : 's'}'),
          ],
          _row(context, 'Monthly rate',
              '${preview.monthlyRate.toStringAsFixed(1)}% / month'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accrued penalty',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context),
                ),
              ),
              Text(
                hasPenalty
                    ? Fmt.currency(preview.amount)
                    : preview.zeroReason ?? '₹0',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: hasPenalty
                      ? AppTheme.error
                      : AppTheme.subtext(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.subtext(context))),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onCard(context))),
          ],
        ),
      );
}

