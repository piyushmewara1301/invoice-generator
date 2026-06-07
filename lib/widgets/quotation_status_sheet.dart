import 'package:flutter/material.dart';
import '../models/recurring_schedule.dart' show QuotationStatus, QuotationStatusX;
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showQuotationStatusSheet
//
// A bottom sheet that lets the user change the status of a quotation and,
// when selecting Approved, also offers "Convert to Invoice".
//
// [onStatusSelected]     – called with the chosen QuotationStatus.
// [onConvertToInvoice]   – called when the user picks "Convert to Invoice".
//                          If null, the convert option is not shown (e.g. for
//                          a quotation that hasn't been saved yet).
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showQuotationStatusSheet(
  BuildContext context, {
  required QuotationStatus? currentStatus,
  required void Function(QuotationStatus) onStatusSelected,
  Future<void> Function()? onConvertToInvoice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuotationStatusSheet(
      currentStatus: currentStatus,
      onStatusSelected: onStatusSelected,
      onConvertToInvoice: onConvertToInvoice,
    ),
  );
}

// ─── Bottom sheet widget ──────────────────────────────────────────────────────

class _QuotationStatusSheet extends StatefulWidget {
  final QuotationStatus? currentStatus;
  final void Function(QuotationStatus) onStatusSelected;
  final Future<void> Function()? onConvertToInvoice;

  const _QuotationStatusSheet({
    required this.currentStatus,
    required this.onStatusSelected,
    this.onConvertToInvoice,
  });

  @override
  State<_QuotationStatusSheet> createState() => _QuotationStatusSheetState();
}

class _QuotationStatusSheetState extends State<_QuotationStatusSheet> {
  bool _converting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.outline(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Heading ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Change Quotation Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onCard(context),
              ),
            ),
          ),

          // ── Status options ───────────────────────────────────────────────
          ...QuotationStatus.values.map((s) {
            final isCurrent = s == widget.currentStatus;
            final isApproved = s == QuotationStatus.approved;
            return _StatusOption(
              status: s,
              isCurrent: isCurrent,
              canConvert: isApproved && widget.onConvertToInvoice != null,
              converting: _converting,
              onTap: () {
                widget.onStatusSelected(s);
                Navigator.pop(context);
              },
              onConvert: isApproved && widget.onConvertToInvoice != null
                  ? () async {
                      // Mark approved first, then convert.
                      widget.onStatusSelected(QuotationStatus.approved);
                      setState(() => _converting = true);
                      try {
                        await widget.onConvertToInvoice!();
                      } finally {
                        if (mounted) setState(() => _converting = false);
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  : null,
            );
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Single status row ────────────────────────────────────────────────────────

class _StatusOption extends StatelessWidget {
  final QuotationStatus status;
  final bool isCurrent;
  final bool canConvert;
  final bool converting;
  final VoidCallback onTap;
  final Future<void> Function()? onConvert;

  const _StatusOption({
    required this.status,
    required this.isCurrent,
    required this.canConvert,
    required this.converting,
    required this.onTap,
    this.onConvert,
  });

  IconData get _icon {
    switch (status) {
      case QuotationStatus.draft:    return Icons.edit_note_outlined;
      case QuotationStatus.sent:     return Icons.send_outlined;
      case QuotationStatus.approved: return Icons.check_circle_outline;
      case QuotationStatus.declined: return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status row ─────────────────────────────────────────────────────
        InkWell(
          onTap: converting ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? color : AppTheme.onCard(context),
                    ),
                  ),
                ),
                if (isCurrent)
                  Icon(Icons.check_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),

        // ── "Convert to Invoice" sub-action (Approved only) ────────────────
        if (canConvert)
          InkWell(
            onTap: converting ? null : onConvert,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  if (converting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF16A34A)),
                    )
                  else
                    const Icon(Icons.swap_horiz_rounded,
                        color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Convert to Invoice',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        Text(
                          'Mark as Approved and create a live invoice',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: Color(0xFF16A34A)),
                ],
              ),
            ),
          ),

        Divider(height: 1, indent: 20, endIndent: 20,
            color: AppTheme.outline(context).withValues(alpha: 0.5)),
      ],
    );
  }
}
