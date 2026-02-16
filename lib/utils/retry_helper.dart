import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Circuit breaker states.
enum CircuitState {
  closed, // Normal operation, requests pass through
  open, // Circuit is open, requests fail immediately
  halfOpen, // Testing if service recovered
}

/// Adaptive retry policy that adjusts based on error type.
class AdaptiveRetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool Function(Exception)? shouldRetry;
  final double jitterFactor;

  const AdaptiveRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
    this.shouldRetry,
    this.jitterFactor = 0.1,
  });

  Duration getDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    // Calculate exponential backoff
    double delayMillis =
        initialDelay.inMilliseconds *
        math.pow(backoffMultiplier, attempt - 1).toDouble();

    // Clamp to max delay
    delayMillis = math.min(delayMillis, maxDelay.inMilliseconds.toDouble());

    // Add jitter
    if (jitterFactor > 0) {
      final jitter = delayMillis * jitterFactor;
      final random = math.Random();
      delayMillis = delayMillis + (random.nextDouble() * jitter * 2) - jitter;
    }

    return Duration(milliseconds: math.max(0, delayMillis.toInt()));
  }
}

/// Circuit breaker for resilient operations.
/// Prevents cascading failures by temporarily stopping requests after repeated failures.
class CircuitBreaker {
  final String name;
  final int maxFailures;
  final Duration cooldownDuration;
  final Duration halfOpenTimeout;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _circuitOpenedAt;

  // Metrics
  int _totalFailures = 0;
  int _circuitOpenCount = 0;
  final List<int> _recoveryTimes = [];

  CircuitBreaker({
    required this.name,
    this.maxFailures = 5,
    this.cooldownDuration = const Duration(seconds: 30),
    this.halfOpenTimeout = const Duration(seconds: 5),
  });

  /// Current circuit state.
  CircuitState get state => _state;

  /// Whether operations should be attempted.
  bool get shouldAttempt {
    switch (_state) {
      case CircuitState.closed:
        return true;
      case CircuitState.open:
        // Check if cooldown has passed
        if (_circuitOpenedAt != null) {
          final elapsed = DateTime.now().difference(_circuitOpenedAt!);
          if (elapsed >= cooldownDuration) {
            _state = CircuitState.halfOpen;
            debugPrint(
              '[CircuitBreaker:$name] Transitioning to halfOpen after ${elapsed.inSeconds}s cooldown',
            );
            return true;
          }
        }
        return false;
      case CircuitState.halfOpen:
        return true;
    }
  }

  /// Record a successful operation.
  void recordSuccess() {
    if (_state == CircuitState.halfOpen) {
      // Service recovered, close the circuit
      final recoveryTime = _circuitOpenedAt != null
          ? DateTime.now().difference(_circuitOpenedAt!).inMilliseconds
          : 0;
      _recoveryTimes.add(recoveryTime);

      debugPrint(
        '[CircuitBreaker:$name] Circuit closed after successful retry (recovery time: ${recoveryTime}ms)',
      );
      _state = CircuitState.closed;
      _failureCount = 0;
      _circuitOpenedAt = null;
    }
    _successCount++;
  }

  /// Record a failed operation.
  void recordFailure() {
    _failureCount++;
    _totalFailures++;

    if (_state == CircuitState.halfOpen) {
      // Test request failed, reopen circuit
      debugPrint(
        '[CircuitBreaker:$name] Circuit reopened after halfOpen failure',
      );
      _state = CircuitState.open;
      _circuitOpenedAt = DateTime.now();
      _circuitOpenCount++;
    } else if (_state == CircuitState.closed && _failureCount >= maxFailures) {
      // Too many failures, open circuit
      debugPrint(
        '[CircuitBreaker:$name] Circuit opened after $_failureCount failures',
      );
      _state = CircuitState.open;
      _circuitOpenedAt = DateTime.now();
      _circuitOpenCount++;
    }
  }

  /// Reset the circuit breaker.
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _successCount = 0;
    _circuitOpenedAt = null;
  }

  /// Get circuit breaker metrics.
  Map<String, dynamic> get metrics => {
    'name': name,
    'state': _state.name,
    'failureCount': _failureCount,
    'successCount': _successCount,
    'totalFailures': _totalFailures,
    'circuitOpenCount': _circuitOpenCount,
    'averageRecoveryTimeMs': _recoveryTimes.isNotEmpty
        ? _recoveryTimes.reduce((a, b) => a + b) / _recoveryTimes.length
        : 0,
  };
}

/// Exception thrown when circuit breaker is open.
class CircuitOpenException implements Exception {
  final String operationType;
  CircuitOpenException(this.operationType);

  @override
  String toString() => 'Circuit is open for operation: $operationType';
}

/// Global circuit breaker instances for different operation types.
final Map<String, CircuitBreaker> _circuitBreakers = {};

/// Get or create a circuit breaker for a specific operation type.
CircuitBreaker getCircuitBreaker(
  String operationType, {
  int maxFailures = 5,
  Duration cooldownDuration = const Duration(seconds: 30),
}) {
  return _circuitBreakers.putIfAbsent(
    operationType,
    () => CircuitBreaker(
      name: operationType,
      maxFailures: maxFailures,
      cooldownDuration: cooldownDuration,
    ),
  );
}

/// Helper to execute operation with adaptive retry policy.
Future<T> withAdaptiveRetry<T>(
  Future<T> Function() operation, {
  AdaptiveRetryPolicy policy = const AdaptiveRetryPolicy(),
  void Function(dynamic error, Duration delay)? onRetry,
  String? debugLabel,
}) async {
  for (int attempt = 1; attempt <= policy.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      // Don't retry if it's not strictly an exception unless we want to catch errors too
      // But typically we only retry Exceptions
      if (e is! Exception && e is! Error) rethrow;

      final isLastAttempt = attempt == policy.maxAttempts;

      // Check policy
      bool shouldRetry = true;
      if (e is Exception && policy.shouldRetry != null) {
        shouldRetry = policy.shouldRetry!(e);
      }

      if (isLastAttempt || !shouldRetry) {
        rethrow;
      }

      // Calculate delay
      final delay = policy.getDelay(attempt);
      onRetry?.call(e, delay);

      debugPrint(
        '[AdaptiveRetry${debugLabel != null ? ':$debugLabel' : ''}] Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms: $e',
      );

      await Future.delayed(delay);
    }
  }
  throw Exception('Retry failed after ${policy.maxAttempts} attempts');
}

/// Legacy Retry helper with simple backoff.
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration? initialDelay,
  bool Function(Exception)? shouldRetry,
}) async {
  return withAdaptiveRetry(
    operation,
    policy: AdaptiveRetryPolicy(
      maxAttempts: maxAttempts,
      initialDelay: initialDelay ?? const Duration(seconds: 2),
      shouldRetry: shouldRetry,
      backoffMultiplier: 2.0, // Match legacy behavior
      jitterFactor: 0.0,
    ),
  );
}

/// Retry helper with custom backoff strategy.
Future<T> withRetryBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  double multiplier = 2.0,
}) async {
  return withAdaptiveRetry(
    operation,
    policy: AdaptiveRetryPolicy(
      maxAttempts: maxAttempts,
      initialDelay: baseDelay,
      backoffMultiplier: multiplier,
      jitterFactor: 0.0,
    ),
  );
}

/// Retry helper with circuit breaker integration for void operations.
/// Throws CircuitOpenException if circuit is open.
Future<void> withRetryCircuitBreakerVoid(
  Future<void> Function() operation, {
  required String operationType,
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  double multiplier = 2.0,
  int maxFailures = 5,
  Duration cooldownDuration = const Duration(seconds: 30),
  void Function()? onCircuitOpen,
}) async {
  final circuitBreaker = getCircuitBreaker(
    operationType,
    maxFailures: maxFailures,
    cooldownDuration: cooldownDuration,
  );

  // Check if circuit allows attempts
  if (!circuitBreaker.shouldAttempt) {
    debugPrint(
      '[withRetryCircuitBreakerVoid:$operationType] Circuit is open, operation should be queued',
    );
    onCircuitOpen?.call();
    throw CircuitOpenException(operationType);
  }

  // Use adaptive retry wrapper? No, complex interaction with circuit breaker
  // We'll keep explicit loop to handle circuit breaker state
  Duration currentDelay = baseDelay;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    // Check circuit state before each attempt
    if (!circuitBreaker.shouldAttempt) {
      debugPrint(
        '[withRetryCircuitBreakerVoid:$operationType] Circuit opened during retries',
      );
      onCircuitOpen?.call();
      throw CircuitOpenException(operationType);
    }

    try {
      await operation();
      circuitBreaker.recordSuccess();
      return;
    } catch (e) {
      if (e is CircuitOpenException) rethrow;

      circuitBreaker.recordFailure();

      if (attempt == maxAttempts) {
        debugPrint(
          '[withRetryCircuitBreakerVoid:$operationType] All $maxAttempts attempts failed',
        );
        rethrow;
      }

      // Check if circuit opened after this failure
      if (!circuitBreaker.shouldAttempt) {
        debugPrint(
          '[withRetryCircuitBreakerVoid:$operationType] Circuit opened, stopping retries',
        );
        onCircuitOpen?.call();
        throw CircuitOpenException(operationType);
      }

      debugPrint(
        '[withRetryCircuitBreakerVoid:$operationType] Attempt $attempt failed, retrying in ${currentDelay.inMilliseconds}ms',
      );
      await Future.delayed(currentDelay);
      currentDelay = currentDelay * multiplier;
    }
  }
}

/// Retry helper with circuit breaker integration.
/// Returns null if circuit is open and operation should be queued instead.
Future<T?> withRetryCircuitBreaker<T>(
  Future<T> Function() operation, {
  required String operationType,
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  double multiplier = 2.0,
  int maxFailures = 5,
  Duration cooldownDuration = const Duration(seconds: 30),
  void Function()? onCircuitOpen,
}) async {
  final circuitBreaker = getCircuitBreaker(
    operationType,
    maxFailures: maxFailures,
    cooldownDuration: cooldownDuration,
  );

  // Check if circuit allows attempts
  if (!circuitBreaker.shouldAttempt) {
    debugPrint(
      '[withRetryCircuitBreaker:$operationType] Circuit is open, operation should be queued',
    );
    onCircuitOpen?.call();
    return null;
  }

  Duration currentDelay = baseDelay;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    // Check circuit state before each attempt
    if (!circuitBreaker.shouldAttempt) {
      debugPrint(
        '[withRetryCircuitBreaker:$operationType] Circuit opened during retries',
      );
      onCircuitOpen?.call();
      return null;
    }

    try {
      final result = await operation();
      circuitBreaker.recordSuccess();
      return result;
    } catch (e) {
      circuitBreaker.recordFailure();

      if (attempt == maxAttempts) {
        debugPrint(
          '[withRetryCircuitBreaker:$operationType] All $maxAttempts attempts failed',
        );
        rethrow;
      }

      // Check if circuit opened after this failure
      if (!circuitBreaker.shouldAttempt) {
        debugPrint(
          '[withRetryCircuitBreaker:$operationType] Circuit opened, stopping retries',
        );
        onCircuitOpen?.call();
        return null;
      }

      debugPrint(
        '[withRetryCircuitBreaker:$operationType] Attempt $attempt failed, retrying in ${currentDelay.inMilliseconds}ms',
      );
      await Future.delayed(currentDelay);
      currentDelay = currentDelay * multiplier;
    }
  }

  throw Exception('Retry failed after $maxAttempts attempts');
}

/// Get metrics for all circuit breakers.
Map<String, Map<String, dynamic>> getCircuitBreakerMetrics() {
  return _circuitBreakers.map((key, value) => MapEntry(key, value.metrics));
}

/// Reset all circuit breakers (useful for testing or manual recovery).
void resetAllCircuitBreakers() {
  for (final cb in _circuitBreakers.values) {
    cb.reset();
  }
}
