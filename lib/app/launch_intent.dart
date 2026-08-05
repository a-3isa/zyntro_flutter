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
/// Rather than trying to synchronise the two, this records the fact early:
/// `NotificationService.init()` runs before `runApp()`, so by the time the
/// router exists the answer is already known and the resume decision simply
/// stands down. A race becomes an ordering fact.
///
/// Deliberately a plain singleton rather than a provider: it has to be writable
/// from `init()`, which runs before any [ProviderContainer] exists.
class LaunchIntent {
  LaunchIntent._();

  static final LaunchIntent instance = LaunchIntent._();

  bool? _hasExplicitDestination;

  /// Set once during start-up, before the first frame.
  set hasExplicitDestination(bool value) => _hasExplicitDestination = value;

  /// True when the launch has its own destination — including when we could not
  /// work out whether it does.
  ///
  /// The unknown case deliberately reads as `true`: skipping a redirect costs
  /// the member one tap, while hijacking their notification tap sends them
  /// somewhere they did not ask to go. Only one of those is recoverable.
  bool get hasExplicitDestination => _hasExplicitDestination ?? true;

  /// Whether start-up has resolved the question yet.
  bool get isResolved => _hasExplicitDestination != null;

  /// Test seam.
  void resetForTest() => _hasExplicitDestination = null;
}

/// Exposes [LaunchIntent] to the router's resume decision.
final launchIntentProvider = Provider<LaunchIntent>(
  (ref) => LaunchIntent.instance,
);
