import 'package:flutter/foundation.dart';

/// Simple performance monitoring utility.
/// Tracks duration of key operations and logs slow ones.
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._();

  final Map<String, DateTime> _traces = {};

  /// Start a trace for an operation.
  void startTrace(String name) {
    _traces[name] = DateTime.now();
  }

  /// Stop trace and log duration.
  void stopTrace(String name, {int warningThresholdMs = 2000}) {
    final startTime = _traces.remove(name);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (duration > warningThresholdMs) {
        debugPrint(
          '[Performance] $name took ${duration}ms (Exceeded ${warningThresholdMs}ms)',
        );
      } else {
        // debugPrint('[Performance] $name took ${duration}ms');
      }
    }
  }
}
