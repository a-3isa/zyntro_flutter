import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'global_error_handler.dart';

/// Connection quality states based on operation latency.
enum ConnectionQuality {
  excellent, // <100ms
  good, // 100-500ms
  poor, // 500-1000ms
  bad, // >1000ms
}

/// Queued operation for offline retry.
class QueuedOperation {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  int retryCount;
  bool isSynced;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.retryCount = 0,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
    'isSynced': isSynced,
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }
}

/// Emitted when an operation permanently fails after max retries.
class FailedSyncEvent {
  final String operationType;
  final String operationId;
  final int retryCount;
  final DateTime timestamp;

  FailedSyncEvent({
    required this.operationType,
    required this.operationId,
    required this.retryCount,
    required this.timestamp,
  });
}

/// Handler for processing queued operations.
typedef OperationHandler = Future<void> Function(QueuedOperation operation);

/// Handler for processing batched operations.
typedef BatchOperationHandler =
    Future<List<bool>> Function(List<QueuedOperation> operations);

/// Offline manager for queueing and retrying operations.
/// Matches React Native offlineManager.ts behavior.
/// Enhanced with batch sync, connection quality monitoring, and improved retry strategies.
class OfflineManager {
  static const String _queueKey = 'zyntro_offline_queue';
  static const String _failedOpsKey = 'zyntro_failed_operations';
  static const int _maxRetries = 3;
  static const int _batchSize = 10;

  final Connectivity _connectivity = Connectivity();
  final Map<String, OperationHandler> _handlers = {};
  final Map<String, BatchOperationHandler> _batchHandlers = {};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isProcessing = false;
  bool _isBatchProcessing = false;
  bool _syncPaused = false;

  // Connection quality tracking
  ConnectionQuality _connectionQuality = ConnectionQuality.good;
  final List<int> _latencyHistory = [];
  static const int _latencyHistorySize = 10;

  // Sync progress tracking
  final StreamController<SyncProgress> _syncProgressController =
      StreamController<SyncProgress>.broadcast();

  // Connection quality tracking stream
  final StreamController<ConnectionQuality> _connectionQualityController =
      StreamController<ConnectionQuality>.broadcast();

  // Failure notification stream (emitted when an op hits max retries)
  final StreamController<FailedSyncEvent> _failureNotificationController =
      StreamController<FailedSyncEvent>.broadcast();

  // Queue count stream (emitted after each queue mutation)
  final StreamController<int> _queueCountController =
      StreamController<int>.broadcast();

  /// Whether the device is currently online.
  bool get isOnline => _isOnline;

  /// Whether sync is currently paused (e.g., on metered connection).
  bool get syncPaused => _syncPaused;

  /// Current connection quality based on recent latency measurements.
  ConnectionQuality get connectionQuality => _connectionQuality;

  /// Stream of sync progress updates.
  Stream<SyncProgress> get onSyncProgress => _syncProgressController.stream;

  /// Stream of connection quality updates.
  Stream<ConnectionQuality> get onConnectionQualityChanged =>
      _connectionQualityController.stream;

  /// Stream of connectivity status changes.
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));

  /// Stream of permanent sync failures (after max retries exhausted).
  Stream<FailedSyncEvent> get onSyncFailure =>
      _failureNotificationController.stream;

  /// Stream of pending queue length, emitted after each queue mutation.
  Stream<int> get queueCountStream => _queueCountController.stream;

  /// Operation types that support batch processing.
  List<String> getBatchableOperationTypes() => ['session_event'];

  /// Initialize the offline manager.
  Future<void> init() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      debugPrint('[OfflineManager] Connectivity changed: $_isOnline');

      // Process queue when coming back online
      if (!wasOnline && _isOnline && !_syncPaused) {
        processQueue();
      }
    });

    // Register lifecycle observer so processQueue fires on app resume (T015)
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));

    // Process any pending operations if online
    if (_isOnline && !_syncPaused) {
      processQueue();
    }
  }

  /// Dispose resources.
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncProgressController.close();
    _connectionQualityController.close();
    _failureNotificationController.close();
    _queueCountController.close();
  }

  /// Register a handler for a specific operation type.
  void registerHandler(String type, OperationHandler handler) {
    _handlers[type] = handler;
  }

  /// Register a batch handler for a specific operation type.
  void registerBatchHandler(String type, BatchOperationHandler handler) {
    _batchHandlers[type] = handler;
  }

  /// Pause sync operations (useful on metered connections).
  void pauseSync() {
    _syncPaused = true;
    debugPrint('[OfflineManager] Sync paused');
  }

  /// Resume sync operations.
  void resumeSync() {
    _syncPaused = false;
    debugPrint('[OfflineManager] Sync resumed');
    if (_isOnline) {
      processQueue();
    }
  }

  /// Queue an operation for retry.
  /// When [id] is provided (stable ID), any existing entry with that ID is
  /// replaced, ensuring idempotent queuing (e.g. offline like/unlike).
  Future<void> queueOperation(
    String type,
    Map<String, dynamic> payload, {
    String? id,
  }) async {
    final operation = QueuedOperation(
      id: id ?? '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      payload: payload,
      timestamp: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    var queue = prefs.getStringList(_queueKey) ?? [];
    if (id != null) {
      queue = queue.where((s) {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        return decoded['id'] != id;
      }).toList();
    }
    queue.add(jsonEncode(operation.toJson()));
    await prefs.setStringList(_queueKey, queue);
    _queueCountController.add(queue.length);

    debugPrint('[OfflineManager] Queued operation: ${operation.type}');
  }

  /// Get all queued operations.
  Future<List<QueuedOperation>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];

    return queue
        .map((json) => QueuedOperation.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Get failed operations that exceeded max retries.
  Future<List<QueuedOperation>> getFailedOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final failed = prefs.getStringList(_failedOpsKey) ?? [];

    return failed
        .map((json) => QueuedOperation.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Clear failed operations after user acknowledgement.
  Future<void> clearFailedOperations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedOpsKey);
  }

  /// Update connection quality based on operation latency.
  void _updateConnectionQuality(int latencyMs) {
    _latencyHistory.add(latencyMs);
    if (_latencyHistory.length > _latencyHistorySize) {
      _latencyHistory.removeAt(0);
    }

    final avgLatency =
        _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;

    final previousQuality = _connectionQuality;
    if (avgLatency < 100) {
      _connectionQuality = ConnectionQuality.excellent;
    } else if (avgLatency < 500) {
      _connectionQuality = ConnectionQuality.good;
    } else if (avgLatency < 1000) {
      _connectionQuality = ConnectionQuality.poor;
    } else {
      _connectionQuality = ConnectionQuality.bad;
    }

    if (previousQuality != _connectionQuality) {
      debugPrint(
        '[OfflineManager] Connection quality changed to: $_connectionQuality (avg: ${avgLatency.toStringAsFixed(0)}ms)',
      );
      _connectionQualityController.add(_connectionQuality);
    }
  }

  /// Get retry delay based on connection quality.
  Duration _getRetryDelay(int retryCount) {
    final baseDelay = 1 << retryCount; // 2, 4, 8...

    // Adjust delay based on connection quality
    final multiplier = switch (_connectionQuality) {
      ConnectionQuality.excellent => 1.0,
      ConnectionQuality.good => 1.5,
      ConnectionQuality.poor => 2.0,
      ConnectionQuality.bad => 3.0,
    };

    return Duration(seconds: (baseDelay * multiplier).round());
  }

  /// Process all queued operations with batch support.
  Future<void> processQueue() async {
    if (_isProcessing || !_isOnline || _syncPaused) return;
    _isProcessing = true;

    debugPrint('[OfflineManager] Processing queue...');
    final stopwatch = Stopwatch()..start();

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? [];
      final failedOperations = <String>[];
      final permanentlyFailed = <String>[];
      int processedCount = 0;
      int successCount = 0;
      int failureCount = 0;
      final totalCount = queue.length;

      // Emit initial progress
      _syncProgressController.add(
        SyncProgress(
          total: totalCount,
          processed: 0,
          succeeded: 0,
          failed: 0,
          isSyncing: true,
        ),
      );

      // Group operations by type for batch processing
      final operationsByType = <String, List<String>>{};
      final nonBatchableOps = <String>[];

      for (final json in queue) {
        try {
          final operation = QueuedOperation.fromJson(jsonDecode(json));
          if (getBatchableOperationTypes().contains(operation.type) &&
              _batchHandlers.containsKey(operation.type)) {
            operationsByType.putIfAbsent(operation.type, () => []).add(json);
          } else {
            nonBatchableOps.add(json);
          }
        } catch (e) {
          debugPrint('[OfflineManager] Invalid operation in queue: $e');
          // Discard invalid operations
        }
      }

      // Process batch operations first
      for (final entry in operationsByType.entries) {
        if (!_isOnline || _syncPaused) break;

        final type = entry.key;
        final ops = entry.value;
        final batchHandler = _batchHandlers[type];

        if (batchHandler != null) {
          await _processBatchOperations(
            type,
            ops,
            batchHandler,
            failedOperations,
            permanentlyFailed,
            (processed, succeeded, failed) {
              processedCount = processed;
              successCount = succeeded;
              failureCount = failed;
              _syncProgressController.add(
                SyncProgress(
                  total: totalCount,
                  processed: processedCount,
                  succeeded: successCount,
                  failed: failureCount,
                  isSyncing: true,
                ),
              );
            },
          );
        }
      }

      // Process non-batchable operations individually
      for (final json in nonBatchableOps) {
        if (!_isOnline || _syncPaused) {
          failedOperations.add(json);
          continue;
        }

        try {
          final opStopwatch = Stopwatch()..start();
          final operation = QueuedOperation.fromJson(jsonDecode(json));
          final handler = _handlers[operation.type];

          if (handler == null) {
            debugPrint(
              '[OfflineManager] No handler for type: ${operation.type}',
            );
            failedOperations.add(json);
            continue;
          }

          // Backoff delay before retry if it had prev failures
          if (operation.retryCount > 0) {
            final delay = _getRetryDelay(operation.retryCount);
            debugPrint('[OfflineManager] Backoff for ${delay.inSeconds}s');
            await Future.delayed(delay);
          }

          await handler(operation);
          opStopwatch.stop();
          _updateConnectionQuality(opStopwatch.elapsedMilliseconds);

          processedCount++;
          successCount++;
          debugPrint('[OfflineManager] Processed: ${operation.type}');
        } catch (e) {
          debugPrint('[OfflineManager] Failed to process operation: $e');

          final operation = QueuedOperation.fromJson(jsonDecode(json));
          operation.retryCount++;
          processedCount++;
          failureCount++;

          if (operation.retryCount < _maxRetries) {
            failedOperations.add(jsonEncode(operation.toJson()));
          } else {
            debugPrint(
              '[OfflineManager] Max retries exceeded for: ${operation.type}',
            );
            _failureNotificationController.add(FailedSyncEvent(
              operationType: operation.type,
              operationId: operation.id,
              retryCount: operation.retryCount,
              timestamp: DateTime.now(),
            ));
            permanentlyFailed.add(jsonEncode(operation.toJson()));
          }
        }

        // Update progress
        _syncProgressController.add(
          SyncProgress(
            total: totalCount,
            processed: processedCount,
            succeeded: successCount,
            failed: failureCount,
            isSyncing: true,
          ),
        );
      }

      // Update queue with failed operations
      await prefs.setStringList(_queueKey, failedOperations);
      _queueCountController.add(failedOperations.length);

      // Store permanently failed operations for user inspection
      if (permanentlyFailed.isNotEmpty) {
        final existingFailed = prefs.getStringList(_failedOpsKey) ?? [];
        existingFailed.addAll(permanentlyFailed);
        await prefs.setStringList(_failedOpsKey, existingFailed);
      }

      stopwatch.stop();
      debugPrint(
        '[OfflineManager] Queue processed in ${stopwatch.elapsedMilliseconds}ms. '
        'Success: $successCount, Failed: $failureCount, Remaining: ${failedOperations.length}',
      );

      // Emit final progress
      _syncProgressController.add(
        SyncProgress(
          total: totalCount,
          processed: processedCount,
          succeeded: successCount,
          failed: failureCount,
          isSyncing: false,
          elapsedMs: stopwatch.elapsedMilliseconds,
        ),
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Process operations in batches.
  Future<void> _processBatchOperations(
    String type,
    List<String> operations,
    BatchOperationHandler handler,
    List<String> failedOperations,
    List<String> permanentlyFailed,
    void Function(int processed, int succeeded, int failed) onProgress,
  ) async {
    if (_isBatchProcessing) return;
    _isBatchProcessing = true;

    try {
      // Group by sessionId for session_event type
      final groupedBySession = <String, List<String>>{};
      for (final json in operations) {
        final operation = QueuedOperation.fromJson(jsonDecode(json));
        final sessionId =
            operation.payload['sessionId'] as String? ?? 'unknown';
        groupedBySession.putIfAbsent(sessionId, () => []).add(json);
      }

      int totalProcessed = 0;
      int totalSucceeded = 0;
      int totalFailed = 0;

      for (final sessionOps in groupedBySession.values) {
        // Process in batches of _batchSize
        for (var i = 0; i < sessionOps.length; i += _batchSize) {
          if (!_isOnline || _syncPaused) {
            // Queue remaining for later
            failedOperations.addAll(sessionOps.skip(i));
            break;
          }

          final batchEnd = (i + _batchSize < sessionOps.length)
              ? i + _batchSize
              : sessionOps.length;
          final batch = sessionOps.sublist(i, batchEnd);
          final batchOps = batch
              .map((j) => QueuedOperation.fromJson(jsonDecode(j)))
              .toList();

          debugPrint(
            '[OfflineManager] Processing batch of ${batchOps.length} $type operations',
          );

          try {
            final opStopwatch = Stopwatch()..start();
            final results = await handler(batchOps);
            opStopwatch.stop();
            _updateConnectionQuality(opStopwatch.elapsedMilliseconds);

            // Handle individual results
            for (var idx = 0; idx < results.length; idx++) {
              final op = batchOps[idx];
              totalProcessed++;

              if (results[idx]) {
                totalSucceeded++;
              } else {
                totalFailed++;
                op.retryCount++;
                if (op.retryCount < _maxRetries) {
                  failedOperations.add(jsonEncode(op.toJson()));
                } else {
                  _failureNotificationController.add(FailedSyncEvent(
                    operationType: op.type,
                    operationId: op.id,
                    retryCount: op.retryCount,
                    timestamp: DateTime.now(),
                  ));
                  permanentlyFailed.add(jsonEncode(op.toJson()));
                }
              }
            }
          } catch (e) {
            debugPrint('[OfflineManager] Batch processing failed: $e');
            // Re-queue all operations in the batch with incremented retry count
            for (final op in batchOps) {
              totalProcessed++;
              totalFailed++;
              op.retryCount++;
              if (op.retryCount < _maxRetries) {
                failedOperations.add(jsonEncode(op.toJson()));
              } else {
                _failureNotificationController.add(FailedSyncEvent(
                  operationType: op.type,
                  operationId: op.id,
                  retryCount: op.retryCount,
                  timestamp: DateTime.now(),
                ));
                permanentlyFailed.add(jsonEncode(op.toJson()));
              }
            }
          }

          onProgress(totalProcessed, totalSucceeded, totalFailed);

          // Add delay between batches based on connection quality
          if (i + _batchSize < sessionOps.length) {
            final batchDelay = switch (_connectionQuality) {
              ConnectionQuality.excellent => const Duration(milliseconds: 100),
              ConnectionQuality.good => const Duration(milliseconds: 200),
              ConnectionQuality.poor => const Duration(milliseconds: 500),
              ConnectionQuality.bad => const Duration(seconds: 1),
            };
            await Future.delayed(batchDelay);
          }
        }
      }
    } finally {
      _isBatchProcessing = false;
    }
  }

  /// Clear all queued operations.
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    _queueCountController.add(0);
  }

  /// Get count of queued operations.
  Future<int> getQueueCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_queueKey)?.length ?? 0;
  }

  /// Check if WiFi is connected.
  Future<bool> isWifiConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Show sync notification using global key
  void showSyncNotification(SyncProgress progress) {
    if (!progress.isSyncing) return;

    final state = scannerMessengerKey.currentState;
    if (state != null) {
      // Logic to show/update snackbar
      // For now, we rely on the UI widgets listening to the stream/notifier
      // but if we need a persistent service-level notification:
      /*
      state.showSnackBar(
        SnackBar(
          content: Text('Syncing ${progress.remaining} items...'),
          duration: const Duration(milliseconds: 1000), // Short duration for updates
        ),
      );
      */
    }
  }
}

/// Triggers processQueue() when the app returns to the foreground (T014).
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final OfflineManager _manager;
  _AppLifecycleObserver(this._manager);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _manager.isOnline) {
      _manager.processQueue();
    }
  }
}

/// Sync progress data.
class SyncProgress {
  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final bool isSyncing;
  final int? elapsedMs;

  const SyncProgress({
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.isSyncing,
    this.elapsedMs,
  });

  double get progress => total > 0 ? processed / total : 0.0;
  int get remaining => total - processed;
}

/// Offline manager provider.
final offlineManagerProvider = Provider<OfflineManager>((ref) {
  final manager = OfflineManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Connectivity status provider.
final connectivityProvider = StreamProvider<bool>((ref) {
  final manager = ref.watch(offlineManagerProvider);
  return manager.onConnectivityChanged;
});

/// Sync progress provider.
final syncProgressProvider = StreamProvider<SyncProgress>((ref) {
  final manager = ref.watch(offlineManagerProvider);
  return manager.onSyncProgress;
});

/// Connection quality provider.
final connectionQualityProvider = StreamProvider<ConnectionQuality>((
  ref,
) async* {
  final manager = ref.watch(offlineManagerProvider);
  // Emit current quality first
  yield manager.connectionQuality;
  // Then yield updates
  yield* manager.onConnectionQualityChanged;
});

/// Notifies UI about sync status changes.
class SyncStatusNotifier extends ChangeNotifier {
  final OfflineManager _offlineManager;
  SyncProgress? _progress;
  bool _isSyncing = false;
  StreamSubscription? _subscription;

  SyncStatusNotifier(this._offlineManager) {
    _subscription = _offlineManager.onSyncProgress.listen((progress) {
      _progress = progress;
      _isSyncing = progress.isSyncing;
      notifyListeners();

      // We can trigger the notification manager here if needed
      if (isSyncing) {
        _offlineManager.showSyncNotification(progress);
      }
    });
  }

  SyncProgress? get progress => _progress;
  bool get isSyncing => _isSyncing;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Sync status provider using ChangeNotifier.
final syncStatusProvider = ChangeNotifierProvider<SyncStatusNotifier>((ref) {
  final manager = ref.watch(offlineManagerProvider);
  return SyncStatusNotifier(manager);
});

/// Emits FailedSyncEvent whenever an operation permanently fails (T013).
final syncFailureProvider = StreamProvider<FailedSyncEvent>((ref) {
  return ref.watch(offlineManagerProvider).onSyncFailure;
});

/// Emits the current pending queue length after each mutation (T016).
final pendingQueueCountProvider = StreamProvider<int>((ref) {
  return ref.watch(offlineManagerProvider).queueCountStream;
});
