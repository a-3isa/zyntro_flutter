import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shouldSendNotification fails closed when preference read throws', () {
    final source = File(
      'lib/services/notification_service.dart',
    ).readAsStringSync();
    expect(source, contains('fail-closed'));
    // Catch path must return false (deny), not true (allow).
    final catchIdx = source.indexOf('Preference read failed for');
    expect(catchIdx, isNonNegative);
    final snippet = source.substring(catchIdx, catchIdx + 280);
    expect(snippet, contains('return false'));
    expect(snippet, isNot(contains('return true')));
  });

  test('Android FCM default notification icon is wired', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_icon'),
    );
    expect(manifest, contains('@drawable/ic_stat_zyntro'));
    expect(File('android/app/src/main/res/drawable/ic_stat_zyntro.xml').existsSync(), isTrue);
    expect(
      File('android/app/src/main/res/xml/network_security_config.xml').existsSync(),
      isTrue,
    );
    expect(
      File('android/app/src/main/res/xml/data_extraction_rules.xml').existsSync(),
      isTrue,
    );
  });

  test('deploy-firebase-rules is gated on analyze', () {
    final ci = File('.github/workflows/flutter-ci.yml').readAsStringSync();
    final idx = ci.indexOf('deploy-firebase-rules:');
    expect(idx, isNonNegative);
    final section = ci.substring(idx, idx + 600);
    // Deploying rules waits for analyze (and, since then, the functions and
    // rules tests too).
    expect(section, matches(RegExp(r'needs: \[analyze[,\]]')));
    expect(section, contains("node-version: '22'"));
  });
}
