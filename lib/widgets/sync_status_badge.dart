import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

/// Small pill showing whether local changes are synced to Drive, pending
/// upload, or actively syncing. Renders nothing when no cloud account is
/// connected (purely local / offline mode).
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.hasDrive) return const SizedBox.shrink();

    late final IconData icon;
    late final Color color;
    late final String label;
    late final String tooltip;
    Widget? leading;

    if (provider.syncing) {
      icon = Icons.sync;
      color = AppTheme.primary;
      label = 'Syncing…';
      tooltip = 'Syncing with cloud…';
      leading = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
      );
    } else if (provider.pendingUpload) {
      icon = Icons.cloud_upload_outlined;
      color = AppTheme.warning;
      label = 'Pending';
      tooltip = 'Changes saved on this device — waiting to sync to cloud';
    } else {
      icon = Icons.cloud_done_outlined;
      color = AppTheme.success;
      label = 'Synced';
      tooltip = _syncedTooltip(provider.lastSyncedAt);
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading ?? Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _syncedTooltip(DateTime? at) {
    if (at == null) return 'All changes synced to cloud';
    final diff = DateTime.now().difference(at);
    final String when;
    if (diff.inSeconds < 60) {
      when = 'just now';
    } else if (diff.inMinutes < 60) {
      when = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      when = '${diff.inHours}h ago';
    } else {
      when = '${diff.inDays}d ago';
    }
    return 'Last synced $when';
  }
}
