import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification logging redacts payload data with URLs', () {
    final source = File(
      'lib/services/notification_service.dart',
    ).readAsStringSync();

    expect(source, contains('_redactedNotificationDataForLog'));
    expect(source, contains("'audioUrl': '<redacted>'"));
    expect(
      source,
      isNot(contains(r'Notification tapped: ${response.payload}')),
    );
    expect(source, isNot(contains(r'Payload data: $data')));
    expect(source, isNot(contains(r'Notification opened: ${message.data}')));
  });
}
