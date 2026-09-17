import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics ownership picks GA4 primary (Z-OBS-002)', () {
    final doc = File('docs/ANALYTICS.md').readAsStringSync();
    final functions = File('functions/index.js').readAsStringSync();
    final rules = File('firebase/firestore.rules').readAsStringSync();

    expect(doc, contains('Firebase Analytics (GA4)'));
    expect(doc, contains('**Yes**'));
    expect(doc, contains('writeScheduleHeartbeat'));
    expect(doc, contains('45 minutes'));

    expect(functions, contains('function writeScheduleHeartbeat'));
    expect(rules, contains('match /ops/{document=**}'));
  });
}
