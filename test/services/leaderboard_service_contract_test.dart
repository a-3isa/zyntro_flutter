import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaderboard joins use a batch for joinedEvents and participantCount', () {
    final source = File('lib/services/leaderboard_service.dart').readAsStringSync();

    expect(source, contains('final batch = _firestore.batch();'));
    expect(source, contains('batch.set('));
    expect(source, contains('batch.update('));
  });
}
