import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this app launch already carries a destination of its own — a
/// notification tap or an incoming link.
///
/// Two independent things want to navigate at cold start: the notification
/// handler, from a post-frame callback, and the session-resume redirect, from
/// GoRouter's redirect callback. They drive the same navigator and nothing
/// sequences them, so left alone the member lands wherever the scheduler
/// happened to finish last.
///
/// `main()` captures `FirebaseMessaging.getInitialMessage()` before `runApp()`,
/// so by the time the router exists the answer is already known. Unknown
/// (not yet captured) reads as no explicit destination so an ordinary cold
/// start can still resume.
///
/// Deliberately a plain singleton rather than a provider: it has to be writable
/// from `init()`, which runs before any [ProviderContainer] exists.
class LaunchIntent {
  LaunchIntent._();

  static final LaunchIntent instance = LaunchIntent._();

  bool? _hasExplicitDestination;

  /// Set once during start-up, before the first frame.
  set hasExplicitDestination(bool value) => _hasExplicitDestination = value;

  /// True when the launch has its own destination.
  ///
  /// Unknown (not yet resolved) reads as `false` so an ordinary cold start can
  /// still resume a live session. [main] captures `getInitialMessage` before
  /// `runApp`, so a notification tap is recorded as `true` before the first
  /// redirect. Prefer waiting on [isResolved] if you are not sure the capture
  /// has run.
  bool get hasExplicitDestination => _hasExplicitDestination ?? false;

  /// Whether start-up has resolved the question yet.
  bool get isResolved => _hasExplicitDestination != null;

  /// Test seam.
  void resetForTest() => _hasExplicitDestination = null;
}

/// Exposes [LaunchIntent] to the router's resume decision.
final launchIntentProvider = Provider<LaunchIntent>(
  (ref) => LaunchIntent.instance,
);
