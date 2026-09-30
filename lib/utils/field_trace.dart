import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Lightweight field timing traces without Firebase Performance (Z-OBS-001).
///
/// Emits `perf_trace` analytics events with name + duration_ms so production
/// dashboards can chart startup / join / resume latency without a new SDK.
class FieldTrace {
  FieldTrace(this.name) : _sw = Stopwatch()..start();

  final String name;
  final Stopwatch _sw;
  bool _stopped = false;

  Future<void> stop({Map<String, Object>? extras}) async {
    if (_stopped) return;
    _stopped = true;
    _sw.stop();
    final ms = _sw.elapsedMilliseconds;
    debugPrint('[FieldTrace] $name ${ms}ms');
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'perf_trace',
        parameters: <String, Object>{
          'trace_name': name,
          'duration_ms': ms,
          ...?extras,
        },
      );
    } catch (e) {
      debugPrint('[FieldTrace] analytics log failed: $e');
    }
  }

  /// Runs [action] under a named trace and always stops.
  static Future<T> measure<T>(
    String name,
    Future<T> Function() action, {
    Map<String, Object>? extras,
  }) async {
    final trace = FieldTrace(name);
    try {
      return await action();
    } finally {
      await trace.stop(extras: extras);
    }
  }
}
