import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zyntro_flutter/utils/offline_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    manager = OfflineManager();
  });

  tearDown(() => manager.dispose());

  test('queues are isolated per bound user (Z-OFF-001)', () async {
    manager.bindUser('alice');
    await manager.queueOperation('session_event', {
      'sessionId': 's1',
      'userId': 'alice',
    }, id: 'op_alice');

    manager.bindUser('bob');
    expect(await manager.getQueueCount(), 0);

    await manager.queueOperation('session_event', {
      'sessionId': 's2',
      'userId': 'bob',
    }, id: 'op_bob');
    expect(await manager.getQueueCount(), 1);

    manager.bindUser('alice');
    expect(await manager.getQueueCount(), 1);
    final aliceQueue = await manager.getQueue();
    expect(aliceQueue.single.id, 'op_alice');

    manager.bindUser('bob');
    final bobQueue = await manager.getQueue();
    expect(bobQueue.single.id, 'op_bob');
  });

  test('clearQueue wipes the bound user and the legacy unscoped key', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('zyntro_offline_queue', ['legacy']);

    manager.bindUser('alice');
    await manager.queueOperation('session_event', {'sessionId': 's1'});
    await manager.clearQueue();

    expect(await manager.getQueueCount(), 0);
    expect(prefs.containsKey('zyntro_offline_queue'), isFalse);
    expect(prefs.containsKey('zyntro_offline_queue_alice'), isFalse);
  });
}
