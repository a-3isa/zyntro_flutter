import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/utils/offline_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline social handlers contract (T033)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> writeOp(
        String id, String type, Map<String, dynamic> payload) async {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('zyntro_offline_queue') ?? [];
      existing.add(jsonEncode({
        'id': id,
        'type': type,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
        'isSynced': false,
      }));
      await prefs.setStringList('zyntro_offline_queue', existing);
    }

    // ── like_post handler ──────────────────────────────────────────────────

    test('like_post handler is invoked with correct postId and userId',
        () async {
      final manager = OfflineManager();
      String? dispatchedPost;
      String? dispatchedUser;

      manager.registerHandler('like_post', (op) async {
        dispatchedPost = op.payload['postId'] as String?;
        dispatchedUser = op.payload['userId'] as String?;
      });

      await writeOp('lp1', 'like_post', {'postId': 'post_abc', 'userId': 'user_1'});
      await manager.processQueue();
      await Future.microtask(() {});

      expect(dispatchedPost, equals('post_abc'));
      expect(dispatchedUser, equals('user_1'));
      manager.dispose();
    });

    test('like_post uses stable ID — duplicate ops have same queue key',
        () async {
      // Stable ID means queueOperation with same id overwrites rather than
      // duplicating. Verify by queuing two ops with the same id and asserting
      // the queue length is 1.
      final manager = OfflineManager();

      await manager.queueOperation(
        'like_post',
        {'postId': 'p1', 'userId': 'u1'},
        id: 'like_p1_u1',
      );
      await manager.queueOperation(
        'like_post',
        {'postId': 'p1', 'userId': 'u1'},
        id: 'like_p1_u1', // same stable id
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('zyntro_offline_queue') ?? [];
      final ids = raw.map((s) => (jsonDecode(s) as Map)['id']).toList();
      expect(ids.where((id) => id == 'like_p1_u1'), hasLength(1),
          reason: 'Stable ID must deduplicate like_post ops');

      manager.dispose();
    });

    // ── unlike_post handler ────────────────────────────────────────────────

    test('unlike_post handler is invoked with correct postId and userId',
        () async {
      final manager = OfflineManager();
      String? dispatchedPost;
      String? dispatchedUser;

      manager.registerHandler('unlike_post', (op) async {
        dispatchedPost = op.payload['postId'] as String?;
        dispatchedUser = op.payload['userId'] as String?;
      });

      await writeOp(
          'ulp1', 'unlike_post', {'postId': 'post_xyz', 'userId': 'user_2'});
      await manager.processQueue();
      await Future.microtask(() {});

      expect(dispatchedPost, equals('post_xyz'));
      expect(dispatchedUser, equals('user_2'));
      manager.dispose();
    });

    test('unlike_post uses stable ID — deduplicated in queue', () async {
      final manager = OfflineManager();

      await manager.queueOperation(
        'unlike_post',
        {'postId': 'p2', 'userId': 'u2'},
        id: 'unlike_p2_u2',
      );
      await manager.queueOperation(
        'unlike_post',
        {'postId': 'p2', 'userId': 'u2'},
        id: 'unlike_p2_u2',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('zyntro_offline_queue') ?? [];
      final ids = raw.map((s) => (jsonDecode(s) as Map)['id']).toList();
      expect(ids.where((id) => id == 'unlike_p2_u2'), hasLength(1),
          reason: 'Stable ID must deduplicate unlike_post ops');

      manager.dispose();
    });

    // ── add_comment handler ────────────────────────────────────────────────

    test('add_comment handler is invoked with correct payload fields',
        () async {
      final manager = OfflineManager();
      Map<String, dynamic>? received;

      manager.registerHandler('add_comment', (op) async {
        received = op.payload;
      });

      await writeOp('ac1', 'add_comment', {
        'postId': 'post_001',
        'userId': 'user_3',
        'userName': 'Alice',
        'text': 'Great workout!',
      });
      await manager.processQueue();
      await Future.microtask(() {});

      expect(received, isNotNull);
      expect(received!['postId'], equals('post_001'));
      expect(received!['userId'], equals('user_3'));
      expect(received!['text'], equals('Great workout!'));
      manager.dispose();
    });

    // ── cross-type regression ──────────────────────────────────────────────

    test('like_post, unlike_post, and add_comment all dispatch in one queue run',
        () async {
      final manager = OfflineManager();
      final dispatched = <String>[];

      manager.registerHandler('like_post', (op) async {
        dispatched.add('like:${op.payload['postId']}');
      });
      manager.registerHandler('unlike_post', (op) async {
        dispatched.add('unlike:${op.payload['postId']}');
      });
      manager.registerHandler('add_comment', (op) async {
        dispatched.add('comment:${op.payload['postId']}');
      });

      await writeOp('m1', 'like_post', {'postId': 'pA', 'userId': 'u'});
      await writeOp('m2', 'unlike_post', {'postId': 'pB', 'userId': 'u'});
      await writeOp('m3', 'add_comment',
          {'postId': 'pC', 'userId': 'u', 'text': 'hi'});

      await manager.processQueue();
      await Future.microtask(() {});

      expect(dispatched, containsAll(['like:pA', 'unlike:pB', 'comment:pC']));
      manager.dispose();
    });
  });
}
