import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release logging', () {
    late String mainSource;

    setUpAll(() {
      mainSource = File('lib/main.dart').readAsStringSync();
    });

    test('debugPrint is silenced in release builds', () {
      // Flutter's debugPrint is NOT stripped from release builds — it writes to
      // the platform log, where any app with log access can read it. The app
      // has hundreds of debugPrint call sites, most interpolating a caught
      // exception whose toString() can embed user content. Reassigning the sink
      // closes all of them at once.
      expect(mainSource, contains('if (kReleaseMode)'));
      expect(
        mainSource,
        contains('debugPrint = (String? message, {int? wrapWidth}) {};'),
      );
    });

    test('the kill switch runs before any Firebase or app work', () {
      // A leak before the switch is set is still a leak.
      final switchAt = mainSource.indexOf('debugPrint = (String? message');
      final firebaseAt = mainSource.indexOf('Firebase.initializeApp()');
      final runAppAt = mainSource.indexOf('runApp(');

      expect(switchAt, isNonNegative);
      expect(switchAt, lessThan(firebaseAt));
      expect(switchAt, lessThan(runAppAt));
    });

    test('startup failures still reach Crashlytics in release', () {
      // Silencing debugPrint would otherwise make a failed startup service
      // completely invisible in production.
      final start = mainSource.indexOf('void _debugPrintStartupFailure');
      expect(start, isNonNegative);
      final body = mainSource.substring(start, start + 900);

      expect(body, contains('FirebaseCrashlytics.instance'));
      expect(body, contains('fatal: false'));
      // The reason string must be scrubbed, like every other reported error.
      expect(body, contains('scrubForReport(error)'));
    });
  });
}
