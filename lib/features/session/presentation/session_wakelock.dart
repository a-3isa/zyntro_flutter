import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the display awake while a live session room is mounted (Z-RT-006).
///
/// Best-effort — platform failures must never break the workout UI.
class SessionWakelock {
  SessionWakelock._();

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Ignore — some desktops / emulators reject wakelock.
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Ignore.
    }
  }
}
