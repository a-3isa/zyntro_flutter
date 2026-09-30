import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startup release safety', () {
    test('release builds default to the production runtime environment', () {
      final mainDart = File('lib/main.dart').readAsStringSync();

      expect(mainDart, contains("const String.fromEnvironment("));
      expect(mainDart, contains("defaultValue: kReleaseMode ? 'prod' : 'dev'"));
    });

    test('router does not wait forever on profile completion errors', () {
      final routerSource = File(
        'lib/app/navigation/app_router.dart',
      ).readAsStringSync();

      expect(routerSource, contains('profileComplete.hasError'));
      expect(routerSource, contains('AppRoutes.onboarding'));
    });

    test('Android uninstall does not allow app data backup restoration', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:allowBackup="false"'));
    });

    test('startup profile validation waits for restored auth state', () {
      final providersSource = File(
        'lib/features/auth/auth_providers.dart',
      ).readAsStringSync();

      expect(
        providersSource,
        contains('await ref.watch(authSessionProvider.future)'),
      );
      expect(providersSource, contains('.isProfileComplete(uid)'));
    });

    test('startup disables Flutter debug paint overlays', () {
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(mainSource, contains('debugPaintSizeEnabled = false'));
      expect(mainSource, contains('debugPaintBaselinesEnabled = false'));
    });
  });
}
