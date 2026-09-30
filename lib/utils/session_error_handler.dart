import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/session_service.dart';
import 'offline_handlers.dart';
import 'offline_manager.dart';

/// Strategy for recovering from an error.
enum ErrorRecoveryStrategy {
  retry, // User can manually retry immediately
  queue, // Operation queued for offline sync
  navigate, // Navigate to a different screen (e.g. home)
  ignore, // Transient error, can be ignored
  fatal, // Critical error requiring app restart or session exit
}

void _debugPrintStack(StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('[SessionErrorHandler] Stack: $stackTrace');
  }
}

/// Error handler for session-related errors.
class SessionErrorHandler {
  /// Determine the best recovery strategy for an error.
  static ErrorRecoveryStrategy getRecoveryStrategy(
    Object error,
    bool isOnline,
  ) {
    if (!isOnline) {
      if (error.toString().toLowerCase().contains('network') ||
          error.toString().toLowerCase().contains('connection') ||
          error.toString().toLowerCase().contains('socket')) {
        return ErrorRecoveryStrategy.queue;
      }
    }

    final category = categorizeError(error);

    switch (category) {
      case OfflineErrorCategory.network:
        return isOnline
            ? ErrorRecoveryStrategy.retry
            : ErrorRecoveryStrategy.queue;
      case OfflineErrorCategory.permission:
        return ErrorRecoveryStrategy.fatal;
      case OfflineErrorCategory.validation:
        // If validation fails, usually no point retrying exactly same data
        return ErrorRecoveryStrategy.ignore;
      case OfflineErrorCategory.unknown:
        if (error.toString().contains('session-ended')) {
          return ErrorRecoveryStrategy.navigate;
        }
        return ErrorRecoveryStrategy.retry;
    }
  }

  /// Handle session errors and provide user feedback/recovery.
  static Future<void> handleError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
    WidgetRef ref, {
    String? sessionId,
    VoidCallback? onRetry,
    void Function(String)? onErrorMessage,
  }) async {
    debugPrint('[SessionErrorHandler] Error: $error');
    if (stackTrace != null) {
      _debugPrintStack(stackTrace);
    }

    final offlineManager = ref.read(offlineManagerProvider);
    final isOnline = offlineManager.isOnline;
    final strategy = getRecoveryStrategy(error, isOnline);

    switch (strategy) {
      case ErrorRecoveryStrategy.queue:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Network issue detected. Action queued for offline sync.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        break;

      case ErrorRecoveryStrategy.retry:
        // Use inline error banner if callback provided, otherwise snackbar
        if (onErrorMessage != null) {
          final errorMessage = error.toString().replaceAll('Exception: ', '');
          onErrorMessage(errorMessage);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Operation failed. Please try again.'),
              backgroundColor: Colors.redAccent,
              action: onRetry != null
                  ? SnackBarAction(
                      label: 'RETRY',
                      textColor: Colors.white,
                      onPressed: onRetry,
                    )
                  : null,
            ),
          );
        }
        break;

      case ErrorRecoveryStrategy.navigate:
        _showRecoveryDialog(
          context,
          'Session Ended',
          'This session has ended or is no longer available.',
          strategy: strategy,
        );
        break;

      case ErrorRecoveryStrategy.fatal:
        _showRecoveryDialog(
          context,
          'Permission Denied',
          'You do not have permission to perform this action.',
          strategy: strategy,
        );
        break;

      case ErrorRecoveryStrategy.ignore:
        // Do nothing suitable for UI
        break;
    }
  }

  static void _showRecoveryDialog(
    BuildContext context,
    String title,
    String message, {
    required ErrorRecoveryStrategy strategy,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: strategy != ErrorRecoveryStrategy.fatal,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (strategy == ErrorRecoveryStrategy.retry && onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (strategy == ErrorRecoveryStrategy.navigate) {
                context.go('/');
              }
            },
            child: Text(
              strategy == ErrorRecoveryStrategy.fatal ? 'Exit' : 'OK',
            ),
          ),
        ],
      ),
    );
  }

  /// Recover session state by forcing a refresh.
  static Future<void> recoverSessionState(
    WidgetRef ref,
    String sessionId,
  ) async {
    // Invalidate providers to force refetch
    ref.invalidate(currentSessionProvider(sessionId));
    ref.invalidate(sessionEventsProvider(sessionId));
  }
}
