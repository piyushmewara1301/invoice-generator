import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_schedule.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

class RecurringInvoicesScreen extends StatefulWidget {
  const RecurringInvoicesScreen({super.key});

  @override
  State<RecurringInvoicesScreen> createState() =>
      _RecurringInvoicesScreenState();
}

class _RecurringInvoicesScreenState extends State<RecurringInvoicesScreen> {
  // ── Frequency colour palette ──────────────────────────────────────────────
  Color _frequencyColor(RecurringFrequency freq) {
    switch (freq) {
      case RecurringFrequency.weekly:
        return const Color(0xFF7C3AED);
      case RecurringFrequency.biWeekly:
        return const Color(0xFF0891B2);
      case RecurringFrequency.monthly:
        return AppTheme.primary;
      case RecurringFrequency.quarterly:
        return const Color(0xFFD97706);
      case RecurringFrequency.yearly:
        return AppTheme.success;
    }
  }

  double _scheduleTotal(RecurringSchedule s) =>
      s.items.fold(0.0, (sum, item) => sum + item.quantity * item.rate);

  // ── Delete confirmation ───────────────────────────────────────────────────
  Future<void> _confirmDelete(
      BuildContext context, AppProvider provider, RecurringSchedule s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Schedule',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.onCard(context),
          ),
        ),
        content: Text(
          'Delete "${s.title}"? This will not affect already-generated invoices.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.subtext(context),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteRecurringSchedule(s.id);
    }
  }

  // ── Detail bottom sheet ───────────────────────────────────────────────────
  void _showDetail(BuildContext context, RecurringSchedule s) {
    final color = _frequencyColor(s.frequency);
    final total = _scheduleTotal(s);
    final symbol = Fmt.currencySymbol(s.currency);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title + icon
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      s.frequency.icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onCard(ctx),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.frequency.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Detail rows
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Client',
                value: s.clientName ?? 'No client',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.event_repeat_outlined,
                label: 'Frequency',
                value: s.frequency.label,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Next Invoice',
                value: Fmt.date(s.nextGenerationDate),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.receipt_long_outlined,
                label: 'Generated',
                value:
                    '${s.generatedCount} invoice${s.generatedCount == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.attach_money_rounded,
                label: 'Amount',
                value: Fmt.currency(total, symbol: symbol),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final schedules = provider.recurringSchedules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Invoices'),
      ),
      body: schedules.isEmpty
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                ...schedules.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScheduleCard(
                      schedule: s,
                      color: _frequencyColor(s.frequency),
                      total: _scheduleTotal(s),
                      onTap: () => _showDetail(context, s),
                      onLongPress: () =>
                          _confirmDelete(context, provider, s),
                      onToggle: (active) {
                        final updated = RecurringSchedule(
                          id: s.id,
                          title: s.title,
                          clientId: s.clientId,
                          clientName: s.clientName,
                          items: s.items,
                          currency: s.currency,
                          globalDiscountPercent: s.globalDiscountPercent,
                          globalDiscountFlat: s.globalDiscountFlat,
                          notes: s.notes,
                          terms: s.terms,
                          paymentMethodId: s.paymentMethodId,
                          paymentMethodName: s.paymentMethodName,
                          frequency: s.frequency,
                          startDate: s.startDate,
                          endDate: s.endDate,
                          nextGenerationDate: s.nextGenerationDate,
                          isActive: active,
                          createdAt: s.createdAt,
                          generatedCount: s.generatedCount,
                          daysTillDue: s.daysTillDue,
                        );
                        provider.updateRecurringSchedule(updated);
                      },
                    ),
                  ),
                ),
                // Info card
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppTheme.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Invoices are auto-generated when you open the app',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
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

// ── Schedule card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final RecurringSchedule schedule;
  final Color color;
  final double total;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onToggle;

  const _ScheduleCard({
    required this.schedule,
    required this.color,
    required this.total,
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = Fmt.currencySymbol(schedule.currency);

    return Dismissible(
      key: ValueKey(schedule.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onLongPress();
        // Return false — actual deletion is handled inside _confirmDelete
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.error,
          size: 24,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Frequency avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      schedule.frequency.icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onCard(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3),
                        Text(
                          '${schedule.frequency.label} · Next: ${Fmt.date(schedule.nextGenerationDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Fmt.currency(total, symbol: symbol),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Active toggle
                  Switch(
                    value: schedule.isActive,
                    onChanged: onToggle,
                    activeThumbColor: AppTheme.primary,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.subtext(context)),
        SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.subtext(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onCard(context),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.repeat_outlined,
                size: 40,
                color: AppTheme.primary.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'No recurring invoices',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Create one from any invoice.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.subtext(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recurring setup sheet ─────────────────────────────────────────────────────

Future<void> showRecurringSetupSheet(
    BuildContext context, Invoice invoice) async {
  final provider = context.read<AppProvider>();
  RecurringFrequency frequency = RecurringFrequency.monthly;
  int daysTillDue = 30;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Set as Recurring Invoice',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            SizedBox(height: 4),
            Text(
              invoice.client != null
                  ? 'For ${invoice.client!.displayName}'
                  : 'No client assigned',
              style: TextStyle(fontSize: 13, color: AppTheme.subtext(context)),
            ),
            SizedBox(height: 20),
            Text('Repeat Frequency',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppTheme.subtext(context))),
            SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: RecurringFrequency.values.map((f) {
                final sel = f == frequency;
                return GestureDetector(
                  onTap: () => setModal(() => frequency = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.card(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppTheme.primary : AppTheme.outline(context),
                          width: sel ? 2 : 1),
                    ),
                    child: Text(f.label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: sel ? AppTheme.primary : AppTheme.subtext(context))),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            Text('Invoice due after',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppTheme.subtext(context))),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [7, 14, 30, 45, 60].map((d) {
                final sel = d == daysTillDue;
                return GestureDetector(
                  onTap: () => setModal(() => daysTillDue = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.card(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppTheme.primary : AppTheme.outline(context),
                          width: sel ? 2 : 1),
                    ),
                    child: Text('$d days',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: sel ? AppTheme.primary : AppTheme.subtext(context))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final now = DateTime.now();
                  final schedule = RecurringSchedule(
                    id: const Uuid().v4(),
                    title: invoice.client != null
                        ? '${invoice.client!.displayName} – ${frequency.label}'
                        : 'Invoice – ${frequency.label}',
                    clientId: invoice.client?.id,
                    clientName: invoice.client?.displayName,
                    items: List.from(invoice.items),
                    currency: invoice.currency,
                    globalDiscountPercent: invoice.globalDiscountPercent,
                    globalDiscountFlat: invoice.globalDiscountFlat,
                    notes: invoice.notes,
                    terms: invoice.terms,
                    paymentMethodId: invoice.paymentMethodId,
                    paymentMethodName: invoice.paymentMethodName,
                    frequency: frequency,
                    startDate: now,
                    nextGenerationDate: frequency.nextDate(now),
                    daysTillDue: daysTillDue,
                  );
                  provider.addRecurringSchedule(schedule);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Recurring enabled: ${schedule.title}'),
                    backgroundColor: AppTheme.success,
                    duration: const Duration(seconds: 3),
                  ));
                },
                child: const Text('Enable Recurring',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
