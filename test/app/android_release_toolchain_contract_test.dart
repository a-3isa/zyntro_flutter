import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android plugin versions that decide whether a release build runs
/// at all.
///
/// `flutter build appbundle --release` failed outright with:
///
///   The Crashlytics Gradle plugin 3 requires Google-Services 4.4.1 and above
///
/// Two files declared google-services independently — settings.gradle.kts
/// pinned 4.3.15 and build.gradle.kts carried a 4.4.0 classpath — so the
/// effective version sat below the floor Crashlytics 3.x needs. The error named
/// neither file, and nothing failed until someone tried to cut a release.
///
/// Debug builds do not exercise this. Without these assertions the next drift
/// is found the same way: at release time.
void main() {
  final settings =
      File('android/settings.gradle.kts').readAsStringSync();
  final rootBuild = File('android/build.gradle.kts').readAsStringSync();

  ({int major, int minor, int patch})? parseVersion(String raw) {
    final parts = raw.split('.');
    if (parts.length < 2) return null;
    return (
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: parts.length > 2 ? int.parse(parts[2]) : 0,
    );
  }

  String? pluginVersion(String pluginId) {
    final match = RegExp(
      'id\\("${RegExp.escape(pluginId)}"\\)\\s*version\\s*\\(?\\s*"([0-9.]+)"',
    ).firstMatch(settings);
    return match?.group(1);
  }

  group('the Android release toolchain', () {
    test('declares google-services exactly once', () {
      // The whole failure came from two declarations drifting apart. The
      // plugins{} block in settings.gradle.kts is what applies; a buildscript
      // classpath in build.gradle.kts resolves nothing and only adds a second
      // number to keep in step.
      expect(
        rootBuild.contains('com.google.gms:google-services'),
        isFalse,
        reason: 'version belongs in settings.gradle.kts only',
      );
      expect(pluginVersion('com.google.gms.google-services'), isNotNull);
    });

    test('google-services meets the floor Crashlytics 3.x requires', () {
      final gs = parseVersion(pluginVersion('com.google.gms.google-services')!)!;
      final crashlytics =
          parseVersion(pluginVersion('com.google.firebase.crashlytics')!)!;

      if (crashlytics.major >= 3) {
        final meetsFloor = gs.major > 4 ||
            (gs.major == 4 &&
                (gs.minor > 4 || (gs.minor == 4 && gs.patch >= 1)));
        expect(
          meetsFloor,
          isTrue,
          reason:
              'Crashlytics ${crashlytics.major}.x needs google-services 4.4.1+, '
              'found ${gs.major}.${gs.minor}.${gs.patch} — release builds will '
              'fail',
        );
      }
    });

    test('both Firebase Gradle plugins are actually applied to :app', () {
      // Declared-but-unapplied is the other way this goes quiet: the version
      // checks above would still pass while Crashlytics silently did nothing.
      final appBuild = File('android/app/build.gradle.kts').readAsStringSync();
      expect(appBuild.contains('id("com.google.gms.google-services")'), isTrue);
      expect(
        appBuild.contains('id("com.google.firebase.crashlytics")'),
        isTrue,
      );
    });
  });
}
