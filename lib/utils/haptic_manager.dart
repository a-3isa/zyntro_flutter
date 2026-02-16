import 'package:flutter/services.dart';

/// Centralized haptic feedback manager with debouncing and platform support.
///
/// Provides consistent haptic feedback patterns throughout the app with
/// automatic debouncing to prevent haptic spam.
class HapticManager {
  static DateTime? _lastHaptic;
  static const Duration _debounceInterval = Duration(milliseconds: 100);
  static bool _enabled = true;

  /// Enable or disable haptic feedback globally.
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Check if haptic feedback is enabled.
  static bool get isEnabled => _enabled;

  /// Light impact for subtle interactions (taps, selections).
  static Future<void> light() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for important actions (reactions, submissions).
  static Future<void> medium() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact for significant events (achievements, errors).
  static Future<void> heavy() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.heavyImpact();
  }

  /// Selection feedback for scrolling through options.
  static Future<void> selection() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.selectionClick();
  }

  /// Vibration feedback (fallback for older devices).
  static Future<void> vibrate() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.vibrate();
  }

  /// Success pattern (light-medium-light) for completions.
  static Future<void> success() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  /// Error pattern (heavy-heavy) for failures.
  static Future<void> error() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Notification pattern for new notifications/messages.
  static Future<void> notification() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Milestone achievement pattern - rhythmic pulse
  static Future<void> milestone() async {
    if (!_shouldTrigger()) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Streak pattern - rapid light ticks
  static Future<void> streak() async {
    if (!_shouldTrigger()) return;
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await HapticFeedback.mediumImpact();
  }

  /// Check if we should trigger haptic feedback (debounce + enabled check).
  static bool _shouldTrigger() {
    if (!_enabled) return false;

    final now = DateTime.now();
    if (_lastHaptic != null &&
        now.difference(_lastHaptic!) < _debounceInterval) {
      return false;
    }
    _lastHaptic = now;
    return true;
  }
}
