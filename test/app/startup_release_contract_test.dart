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

      expect(routerSource, contains('profileCompleteAsync.hasError'));
      expect(routerSource, contains('AppRoutes.profileSetup'));
    });
  });
}
