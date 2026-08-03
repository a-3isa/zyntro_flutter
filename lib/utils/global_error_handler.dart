import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'offline_handlers.dart'; // For OfflineErrorCategory

/// Reports an error to a crash backend. Injectable so tests can assert what
/// would be sent without touching Firebase.
typedef CrashReporter =
    Future<void> Function(Object error, StackTrace? stack, {required bool fatal});

final _emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
// Firebase UIDs, session/post document ids, and the app's own uuid v4 ids.
final _longIdPattern = RegExp(r'\b[A-Za-z0-9_-]{20,}\b');
final _urlPattern = RegExp(r'https?://\S+');
final _phonePattern = RegExp(r'(?<!\d)\+?\d[\d\s()-]{7,}\d(?!\d)');

/// Strips identifying values out of an error before it leaves the device.
///
/// An error's `toString()` routinely embeds user content — a Firestore document
/// body, a rejected message, an email in an auth failure, a signed media URL.
/// The exception type and the stack trace are what actually identify a fault,
/// so everything that could name a person is replaced with a placeholder while
/// the shape of the message is preserved.
String scrubForReport(Object error) {
  final scrubbed = error
      .toString()
      .replaceAll(_urlPattern, '[url]')
      .replaceAll(_emailPattern, '[email]')
      .replaceAll(_phonePattern, '[phone]')
      .replaceAll(_longIdPattern, '[id]');

  // A very long message is user content far more often than it is diagnostic.
  const maxLength = 300;
  if (scrubbed.length <= maxLength) return scrubbed;
  return '${scrubbed.substring(0, maxLength)}… [truncated]';
}

/// Global key for ScaffoldMessenger to show snackbars without context
final GlobalKey<ScaffoldMessengerState> scannerMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Centralized global error handler.
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();

  factory GlobalErrorHandler() => _instance;

  GlobalErrorHandler._internal();

  /// Where errors are reported. Defaults to Crashlytics; tests override it.
  CrashReporter _report = _reportToCrashlytics;

  /// Overrides the crash reporter. Tests only.
  @visibleForTesting
  void debugSetReporter(CrashReporter reporter) => _report = reporter;

  /// Restores the default Crashlytics reporter.
  @visibleForTesting
  void debugResetReporter() => _report = _reportToCrashlytics;

  static Future<void> _reportToCrashlytics(
    Object error,
    StackTrace? stack, {
    required bool fatal,
  }) {
    return FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: fatal,
      // The error's own toString() can carry user content (a Firestore
      // document body, a failed message, an email in an auth error). Send a
      // scrubbed reason and let the type plus stack trace identify the fault.
      reason: scrubForReport(error),
    );
  }

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
      return false;
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

    // Debug builds log to the console above; shipping those to Crashlytics
    // would bury real user crashes under development noise.
    if (kDebugMode) return;

    // Reporting must never itself throw out of an error handler — that would
    // turn a handled error into an unhandled one.
    unawaited(
      _report(error, stack, fatal: fatal).catchError((Object e) {
        debugPrint('[GlobalErrorHandler] Failed to report error: $e');
      }),
    );
  }

  void _logError(Object error, StackTrace? stack, bool fatal) {
    if (kDebugMode) {
      debugPrint(
        '[GlobalErrorHandler] ${fatal ? 'FATAL ' : ''}Error: $error',
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
