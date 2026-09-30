import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/utils/offline_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineManager retry cap contract (FR-014)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> writeOp(String id, String type, {int retryCount = 0}) async {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('zyntro_offline_queue') ?? [];
      existing.add(jsonEncode({
        'id': id,
        'type': type,
        'payload': <String, dynamic>{},
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': retryCount,
        'isSynced': false,
      }));
      await prefs.setStringList('zyntro_offline_queue', existing);
    }

    test('op at max retries is discarded and onSyncFailure emits', () async {
      final manager = OfflineManager();

      final failures = <FailedSyncEvent>[];
      final sub = manager.onSyncFailure.listen(failures.add);

      await writeOp('rc_test', 'session_end', retryCount: 3);
      manager.registerHandler('session_end', (_) async {
        throw Exception('forced offline');
      });

      await manager.processQueue();
      await Future.microtask(() {});

      final prefs = await SharedPreferences.getInstance();
      final remaining = prefs.getStringList('zyntro_offline_queue') ?? [];
      expect(remaining, isEmpty,
          reason: 'Op at retryCount==3 must not remain in the active queue');
      expect(failures, isNotEmpty,
          reason: 'onSyncFailure must emit when op hits max retries');
      expect(failures.first.operationType, equals('session_end'));
      expect(failures.first.operationId, equals('rc_test'));

      await sub.cancel();
      manager.dispose();
    });

    test('FailedSyncEvent carries correct operationType and operationId',
        () async {
      final manager = OfflineManager();

      FailedSyncEvent? captured;
      final sub = manager.onSyncFailure.listen((e) => captured = e);

      await writeOp('field_check', 'post_create', retryCount: 3);
      manager.registerHandler('post_create',
          (_) async => throw Exception('fail'));

      await manager.processQueue();
      await Future.microtask(() {});

      expect(captured, isNotNull);
      expect(captured!.operationType, equals('post_create'));
      expect(captured!.operationId, equals('field_check'));
      expect(captured!.retryCount, greaterThanOrEqualTo(3));

      await sub.cancel();
      manager.dispose();
    });

    test('queueCountStream emits updated count after each queueOperation',
        () async {
      final manager = OfflineManager();

      final countsFuture = manager.queueCountStream.take(2).toList();

      await manager.queueOperation('post_create', {'body': 'hello'}, id: 'pq1');
      await manager.queueOperation('post_create', {'body': 'world'}, id: 'pq2');

      final counts = await countsFuture;
      expect(counts, orderedEquals([1, 2]),
          reason: 'queueCountStream must emit 1 then 2 as ops are enqueued');

      manager.dispose();
    });

    test('queueCountStream emits 0 after clearQueue', () async {
      final manager = OfflineManager();

      final countsFuture = manager.queueCountStream.take(2).toList();

      await manager.queueOperation('like_post', {'postId': 'p1'}, id: 'lk1');
      await manager.clearQueue();

      final counts = await countsFuture;
      expect(counts, contains(0),
          reason: 'queueCountStream must emit 0 after clearQueue');

      manager.dispose();
    });
  });

  // ── T025: Lifecycle sync regression (I1, C2) ───────────────────────────────
  group('OfflineManager lifecycle sync and handler regression (T025)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> writeOp(String id, String type) async {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('zyntro_offline_queue') ?? [];
      existing.add(jsonEncode({
        'id': id,
        'type': type,
        'payload': <String, dynamic>{'id': id},
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
        'isSynced': false,
      }));
      await prefs.setStringList('zyntro_offline_queue', existing);
    }

    test(
        'session_end handler is invoked by processQueue after _maxRetries change',
        () async {
      // Regression guard: session_end ops must still be dispatched to the
      // registered handler after the retry cap was lowered from 5 to 3.
      final manager = OfflineManager();
      final calledWith = <String>[];

      manager.registerHandler('session_end', (op) async {
        calledWith.add(op.id);
      });

      await writeOp('se1', 'session_end');
      await manager.processQueue();
      await Future.microtask(() {});

      expect(calledWith, contains('se1'),
          reason: 'session_end handler must be called for queued op');
      manager.dispose();
    });

    test('post_create handler is invoked by processQueue after _maxRetries change',
        () async {
      final manager = OfflineManager();
      final calledWith = <String>[];

      manager.registerHandler('post_create', (op) async {
        calledWith.add(op.id);
      });

      await writeOp('pc1', 'post_create');
      await manager.processQueue();
      await Future.microtask(() {});

      expect(calledWith, contains('pc1'),
          reason: 'post_create handler must be called for queued op');
      manager.dispose();
    });

    test(
        'processQueue (called by _AppLifecycleObserver on resume) processes '
        'both session_end and post_create in a single run', () async {
      // Simulates what _AppLifecycleObserver.didChangeAppLifecycleState does:
      // it calls manager.processQueue() directly.
      final manager = OfflineManager();
      final dispatched = <String>[];

      manager.registerHandler('session_end', (op) async {
        dispatched.add('session_end:${op.id}');
      });
      manager.registerHandler('post_create', (op) async {
        dispatched.add('post_create:${op.id}');
      });

      await writeOp('se_resume', 'session_end');
      await writeOp('pc_resume', 'post_create');

      // This is what _AppLifecycleObserver calls when isOnline && resumed.
      await manager.processQueue();
      await Future.microtask(() {});

      expect(dispatched, containsAll([
        'session_end:se_resume',
        'post_create:pc_resume',
      ]), reason: 'Both op types must be dispatched in one processQueue call');
      manager.dispose();
    });
  });
}
