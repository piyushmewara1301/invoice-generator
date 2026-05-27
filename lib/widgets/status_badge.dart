import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../utils/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final label = status.label;
    final color = AppTheme.statusColor(label);
    final isOverdue = status == InvoiceStatus.overdue;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isOverdue ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isOverdue ? 0.5 : 0.25),
          width: isOverdue ? 1.0 : 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 5 : 6,
            height: small ? 5 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: small ? 4 : 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
