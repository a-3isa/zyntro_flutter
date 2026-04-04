import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app check debug provider is wired in dart and android startup', () {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final mainDart = File('lib/main.dart').readAsStringSync();
    final runtimeConfig = File(
      'lib/app/app_runtime_config.dart',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/zyntro/app/MainActivity.kt',
    ).readAsStringSync();

    expect(mainDart, contains('await FirebaseAppCheck.instance.activate('));
    expect(
      buildGradle,
      contains(
        'debugImplementation("com.google.firebase:firebase-appcheck-debug:19.0.1")',
      ),
    );
    expect(runtimeConfig, contains('return AndroidProvider.debug;'));
    expect(
      mainActivity,
      contains('const val APP_CHECK_DEBUG_CHANNEL = "zyntro/debug"'),
    );
    expect(mainActivity, contains('getAppCheckDebugSecret'));
    expect(
      mainActivity,
      contains('com.google.firebase.appcheck.debug.DEBUG_SECRET'),
    );
    expect(mainDart, contains('const MethodChannel('));
    expect(mainDart, contains('[AppCheck] Android debug secret:'));
  });
}
