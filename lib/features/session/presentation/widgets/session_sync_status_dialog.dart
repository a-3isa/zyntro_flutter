import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/offline_manager.dart';

/// Offline queue sync status dialog (Z-ARCH-002).
class SessionSyncStatusDialog extends StatelessWidget {
  const SessionSyncStatusDialog({
    super.key,
    required this.queue,
    required this.failedOps,
    required this.formatTimeAgo,
    required this.onClearFailed,
  });

  final List<QueuedOperation> queue;
  final List<QueuedOperation> failedOps;
  final String Function(DateTime) formatTimeAgo;
  final Future<void> Function() onClearFailed;

  static Future<void> show({
    required BuildContext context,
    required List<QueuedOperation> queue,
    required List<QueuedOperation> failedOps,
    required String Function(DateTime) formatTimeAgo,
    required Future<void> Function() onClearFailed,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SessionSyncStatusDialog(
        queue: queue,
        failedOps: failedOps,
        formatTimeAgo: formatTimeAgo,
        onClearFailed: onClearFailed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Status'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending operations: ${queue.length}'),
            const SizedBox(height: 8),
            if (queue.isNotEmpty) ...[
              const Text(
                'Recent pending:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...queue.take(5).map(
                (op) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '• ${op.type} (${formatTimeAgo(op.timestamp)})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            if (failedOps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Failed operations: ${failedOps.length}',
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (failedOps.isNotEmpty)
          TextButton(
            onPressed: () async {
              await onClearFailed();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Clear Failed'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
