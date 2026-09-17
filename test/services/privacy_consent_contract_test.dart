import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy consent service gates analytics and crashlytics (Z-PRV-002)', () {
    final service = File('lib/services/privacy_consent_service.dart')
        .readAsStringSync();
    expect(service, contains('setAnalyticsCollectionEnabled'));
    expect(service, contains('setCrashlyticsCollectionEnabled'));
    expect(service, contains('privacy_consent_analytics'));

    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('privacyConsentServiceProvider'));

    final privacyPage =
        File('lib/features/settings/presentation/privacy_settings_page.dart')
            .readAsStringSync();
    expect(privacyPage, contains('Usage analytics'));
    expect(privacyPage, contains('Crash reports'));
  });
}
