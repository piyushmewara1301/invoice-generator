import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/share_service.dart';
import 'create_invoice_screen.dart';

class ApprovalInboxScreen extends StatelessWidget {
  const ApprovalInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final pending = provider.pendingApprovalInvoices;
    final canApprove = provider.canDo(AppPermission.approveInvoice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Inbox'),
        actions: [
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pending.length}',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: pending.isEmpty
          ? _EmptyState(canApprove: canApprove)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _ApprovalCard(
                invoice: pending[i],
                canApprove: canApprove,
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool canApprove;
  const _EmptyState({required this.canApprove});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppTheme.subtext(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No invoices pending approval',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onCard(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canApprove
                ? 'Invoices submitted by staff will appear here.'
                : 'Invoices you submit will appear here until a manager reviews them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.subtext(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  final Invoice invoice;
  final bool canApprove;

  const _ApprovalCard({required this.invoice, required this.canApprove});

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _loading = false;

  Future<void> _approve() async {
    final notes = await _showNotesDialog(
      context,
      title: 'Approve Invoice',
      hint: 'Optional approval notes',
      confirmLabel: 'Approve',
      confirmColor: AppTheme.success,
    );
    if (notes == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.approveInvoice(widget.invoice.id,
          notes: notes.isEmpty ? null : notes);
      if (!mounted) return;
      // Offer to share the approved invoice.
      final profile = provider.profile;
      final inv = provider.invoices.firstWhere(
        (i) => i.id == widget.invoice.id,
        orElse: () => widget.invoice,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice approved and marked as Sent'),
          duration: Duration(seconds: 2),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showShareInvoiceSheet(context, inv, profile);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _showNotesDialog(
      context,
      title: 'Reject Invoice',
      hint: 'Reason for rejection (required)',
      confirmLabel: 'Reject',
      confirmColor: AppTheme.error,
      required: true,
    );
    if (reason == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await context.read<AppProvider>().rejectInvoice(
            widget.invoice.id,
            reason: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice rejected and moved back to Draft'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return Card(
      elevation: 0,
      color: AppTheme.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.onCard(context),
                        ),
                      ),
                      if (inv.client != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          inv.client!.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.subtext(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  Fmt.currencyAmount(inv.grandTotal, inv.currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.onCard(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 13, color: AppTheme.subtext(context)),
                const SizedBox(width: 4),
                Text(
                  'Submitted ${Fmt.date(inv.lastEditedAt ?? inv.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtext(context),
                  ),
                ),
                if (inv.createdBy != null) ...[
                  const SizedBox(width: 6),
                  Text('·',
                      style: TextStyle(color: AppTheme.subtext(context))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inv.createdBy!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateInvoiceScreen(invoice: inv),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Review'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: AppTheme.outline(context)),
                    ),
                  ),
                  if (widget.canApprove) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close, size: 15),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check, size: 15),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppTheme.success,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showNotesDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  required Color confirmColor,
  bool required = false,
}) {
  final ctrl = TextEditingController();
  String? error;

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
          ),
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () {
              if (required && ctrl.text.trim().isEmpty) {
                setState(() => error = 'Please enter a reason');
                return;
              }
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  ).whenComplete(
    () => WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose()),
  );
}
