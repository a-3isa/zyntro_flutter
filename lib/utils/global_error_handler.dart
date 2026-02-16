import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'offline_handlers.dart'; // For OfflineErrorCategory

/// Global key for ScaffoldMessenger to show snackbars without context
final GlobalKey<ScaffoldMessengerState> scannerMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Centralized global error handler.
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();

  factory GlobalErrorHandler() => _instance;

  GlobalErrorHandler._internal();

  /// Initialize error handlers
  void init() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      handleError(details.exception, details.stack, fatal: true);
    };

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      handleError(error, stack);
      return true;
    };
  }

  /// Handle a generic error
  void handleError(Object error, StackTrace? stack, {bool fatal = false}) {
    // Log error
    _logError(error, stack, fatal);

    // Get friendly message
    final (message, action) = _friendlyError(error);

    // Show feedback to user if appropriate
    _showUserFeedback(message, action, fatal);

    // TODO: Report to Crashlytics
    // if (!kDebugMode) {
    //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    // }
  }

  void _logError(Object error, StackTrace? stack, bool fatal) {
    if (kDebugMode) {
      debugPrint(
        '🛑 [GlobalErrorHandler] ${fatal ? 'FATAL ' : ''}Error: $error',
      );
      if (stack != null) {
        debugPrint('Stack trace:\n$stack');
      }
    }
  }

  void _showUserFeedback(String message, VoidCallback? action, bool fatal) {
    // Run on next frame to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = scannerMessengerKey.currentState;
      if (state != null) {
        state.clearSnackBars(); // Avoid stacking
        state.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  fatal ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: fatal ? Colors.red.shade800 : Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: fatal ? 10 : 4),
            action: action != null
                ? SnackBarAction(
                    label: 'RETRY',
                    textColor: Colors.amber,
                    onPressed: action,
                  )
                : null,
          ),
        );
      }
    });
  }

  /// Categorize and return friendly message
  (String, VoidCallback?) _friendlyError(Object error) {
    final category = categorizeError(error);

    // Default action (can be customized)
    final VoidCallback? retryAction =
        null; // TODO: Implement retry logic hooking

    switch (category) {
      case OfflineErrorCategory.network:
        return (
          'Network issue detected. Please check your connection.',
          retryAction,
        );
      case OfflineErrorCategory.permission:
        return ('Permission denied. You may need to sign in again.', null);
      case OfflineErrorCategory.validation:
        return ('Data validation failed. Please try again.', null);
      case OfflineErrorCategory.unknown:
        return ('Something went wrong. Please try again later.', retryAction);
    }
  }
}
