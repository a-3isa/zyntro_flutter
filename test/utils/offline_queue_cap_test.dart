import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/utils/offline_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('offline queue drops oldest when over maxQueueSize (Z-OFF-003)', () async {
    final manager = OfflineManager();
    manager.bindUser('u1');

    for (var i = 0; i < OfflineManager.maxQueueSize + 5; i++) {
      await manager.queueOperation('noop_$i', {'i': i}, id: 'id_$i');
    }

    final queue = await manager.getQueue();
    expect(queue.length, OfflineManager.maxQueueSize);
    expect(queue.first.id, 'id_5');
    expect(queue.last.id, 'id_${OfflineManager.maxQueueSize + 4}');
  });

  test('non-retryable errors are classified (Z-OFF-003)', () {
    expect(
      OfflineManager.isNonRetryableError(
        Exception('permission-denied'),
      ),
      isTrue,
    );
    expect(
      OfflineManager.isNonRetryableError(Exception('network timeout')),
      isFalse,
    );
  });
}
