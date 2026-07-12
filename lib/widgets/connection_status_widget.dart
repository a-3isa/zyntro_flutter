import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/offline_manager.dart';

/// Connection status states for the widget.
enum ConnectionStatusState { offline, syncing, online }

/// A reusable widget that displays connection status with sync progress.
///
/// Shows three states:
/// - **Offline**: Orange banner with cloud_off icon + pending operations count
/// - **Syncing**: Blue banner with animated sync icon + progress
/// - **Online**: Green banner that auto-dismisses after 2 seconds
class ConnectionStatusWidget extends StatefulWidget {
  final int queueCount;
  final bool isOffline;
  final bool isSyncing;
  final SyncProgress? syncProgress;
  final VoidCallback? onTap;
  final bool compact;
  final bool autoDismissOnline;
  final Duration autoDismissDuration;

  const ConnectionStatusWidget({
    super.key,
    required this.queueCount,
    required this.isOffline,
    this.isSyncing = false,
    this.syncProgress,
    this.onTap,
    this.compact = false,
    this.autoDismissOnline = true,
    this.autoDismissDuration = const Duration(seconds: 2),
  });

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _syncAnimationController;
  bool _showOnlineBanner = false;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didUpdateWidget(ConnectionStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle syncing animation
    if (widget.isSyncing && !oldWidget.isSyncing) {
      _syncAnimationController.repeat();
    } else if (!widget.isSyncing && oldWidget.isSyncing) {
      _syncAnimationController.stop();
      _syncAnimationController.reset();
    }

    // Handle transition to online state
    if (!widget.isOffline && oldWidget.isOffline && !widget.isSyncing) {
      _showOnlineBanner = true;
      if (widget.autoDismissOnline) {
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(widget.autoDismissDuration, () {
          if (mounted) {
            setState(() => _showOnlineBanner = false);
          }
        });
      }
    }

    // Show online banner when syncing completes
    if (!widget.isSyncing && oldWidget.isSyncing && !widget.isOffline) {
      _showOnlineBanner = true;
      if (widget.autoDismissOnline) {
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(widget.autoDismissDuration, () {
          if (mounted) {
            setState(() => _showOnlineBanner = false);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _syncAnimationController.dispose();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  ConnectionStatusState get _currentState {
    if (widget.isOffline) return ConnectionStatusState.offline;
    if (widget.isSyncing) return ConnectionStatusState.syncing;
    return ConnectionStatusState.online;
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if online and banner dismissed
    if (_currentState == ConnectionStatusState.online && !_showOnlineBanner) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompact();
    }

    return _buildFull();
  }

  Widget _buildCompact() {
    final (icon, color, label) = switch (_currentState) {
      ConnectionStatusState.offline => (
        Icons.cloud_off,
        Colors.orange,
        widget.queueCount > 0 ? '${widget.queueCount}' : '',
      ),
      ConnectionStatusState.syncing => (
        Icons.sync,
        Colors.blue,
        widget.syncProgress != null ? '${widget.syncProgress!.remaining}' : '',
      ),
      ConnectionStatusState.online => (Icons.check_circle, Colors.green, ''),
    };

    return GestureDetector(
      onTap: widget.onTap,
      child: Semantics(
        label: _getAccessibilityLabel(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentState == ConnectionStatusState.syncing)
                RotationTransition(
                  turns: _syncAnimationController,
                  child: Icon(icon, size: 16, color: color),
                )
              else
                Icon(icon, size: 16, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFull() {
    final (icon, color, text, showProgress) = switch (_currentState) {
      ConnectionStatusState.offline => (
        Icons.cloud_off,
        Colors.orange,
        widget.queueCount > 0
            ? 'Offline - ${widget.queueCount} operations pending'
            : 'Offline',
        false,
      ),
      ConnectionStatusState.syncing => (
        Icons.sync,
        Colors.blue,
        _getSyncingText(),
        true,
      ),
      ConnectionStatusState.online => (
        Icons.check_circle,
        Colors.green,
        'All changes synced',
        false,
      ),
    };

    return GestureDetector(
      onTap: widget.onTap,
      child: Semantics(
        label: _getAccessibilityLabel(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border(
              bottom: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentState == ConnectionStatusState.syncing)
                    _buildPulsingIcon(icon, color)
                  else
                    Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (showProgress && widget.syncProgress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.syncProgress!.progress,
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingIcon(IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _syncAnimationController,
      builder: (context, child) {
        final opacity = 0.5 + 0.5 * (1 - _syncAnimationController.value);
        return Opacity(
          opacity: opacity,
          child: RotationTransition(
            turns: Tween(
              begin: 0.0,
              end: 1.0,
            ).animate(_syncAnimationController),
            child: Icon(icon, size: 18, color: color),
          ),
        );
      },
    );
  }

  String _getSyncingText() {
    if (widget.syncProgress == null) {
      return 'Syncing...';
    }

    final progress = widget.syncProgress!;
    final remaining = progress.remaining;

    if (progress.elapsedMs != null && progress.processed > 0) {
      // Estimate remaining time
      final avgTimePerOp = progress.elapsedMs! / progress.processed;
      final estimatedRemainingMs = (avgTimePerOp * remaining).round();
      if (estimatedRemainingMs > 1000) {
        final seconds = (estimatedRemainingMs / 1000).ceil();
        return 'Syncing $remaining operations... ~${seconds}s';
      }
    }

    return 'Syncing $remaining operations...';
  }

  String _getAccessibilityLabel() {
    return switch (_currentState) {
      ConnectionStatusState.offline =>
        'Offline. ${widget.queueCount} operations pending sync.',
      ConnectionStatusState.syncing =>
        'Syncing ${widget.syncProgress?.remaining ?? widget.queueCount} operations.',
      ConnectionStatusState.online => 'Online. All changes synced.',
    };
  }
}

/// Sync completion stats widget shown after sync finishes.
class SyncCompletionStats extends StatelessWidget {
  final int operationCount;
  final int elapsedMs;
  final int? failedCount;

  const SyncCompletionStats({
    super.key,
    required this.operationCount,
    required this.elapsedMs,
    this.failedCount,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = (elapsedMs / 1000).toStringAsFixed(1);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failedCount != null && failedCount! > 0
                ? Icons.warning_amber
                : Icons.check_circle,
            color: failedCount != null && failedCount! > 0
                ? Colors.orange
                : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Synced $operationCount operations in ${seconds}s',
            style: theme.textTheme.bodySmall,
          ),
          if (failedCount != null && failedCount! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($failedCount failed)',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}

/// Connection quality indicator dot.
class ConnectionQualityIndicator extends StatelessWidget {
  final ConnectionQuality quality;
  final bool showLabel;

  const ConnectionQualityIndicator({
    super.key,
    required this.quality,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (quality) {
      ConnectionQuality.excellent => (Colors.green, 'Excellent'),
      ConnectionQuality.good => (Colors.lightGreen, 'Good'),
      ConnectionQuality.poor => (Colors.orange, 'Poor'),
      ConnectionQuality.bad => (Colors.red, 'Bad'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
