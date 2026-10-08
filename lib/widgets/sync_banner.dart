import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A banner that shows sync status — either an unsynced count warning
/// or a "last synced at..." success message.
class SyncBanner extends StatelessWidget {
  final int     unsyncedCount;
  final String? lastSyncAt;
  final bool    syncing;
  final VoidCallback? onSyncTap;

  const SyncBanner({
    super.key,
    required this.unsyncedCount,
    this.lastSyncAt,
    this.syncing = false,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    if (syncing) {
      return _buildBanner(
        context,
        icon:    Icons.sync,
        message: 'Syncing data…',
        color:   Colors.blue,
        spinner: true,
      );
    }

    if (unsyncedCount > 0) {
      return _buildBanner(
        context,
        icon:    Icons.cloud_off_rounded,
        message: '$unsyncedCount record${unsyncedCount > 1 ? 's' : ''} waiting to sync',
        color:   Colors.orange,
        action:  onSyncTap != null
            ? TextButton(
                onPressed: onSyncTap,
                child: const Text('Sync Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )
            : null,
      );
    }

    if (lastSyncAt != null) {
      final dt  = DateTime.tryParse(lastSyncAt!);
      final fmt = dt != null
          ? DateFormat('MMM d, h:mm a').format(dt.toLocal())
          : lastSyncAt!;
      return _buildBanner(
        context,
        icon:    Icons.cloud_done_rounded,
        message: 'Last synced: $fmt',
        color:   Colors.green,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner(
    BuildContext context, {
    required IconData icon,
    required String   message,
    required Color    color,
    Widget?           action,
    bool              spinner = false,
  }) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        border:       Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          spinner
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:       color,
                  ),
                )
              : Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize:   13,
                color:      color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}
