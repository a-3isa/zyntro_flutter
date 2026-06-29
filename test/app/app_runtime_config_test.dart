import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/app/app_runtime_config.dart';

void main() {
  group('AppRuntimeEnvironment', () {
    test('falls back to dev for unknown environment names', () {
      expect(
        AppRuntimeEnvironment.fromName('unexpected'),
        AppRuntimeEnvironment.dev,
      );
    });

    test('resolves expected env file names', () {
      expect(AppRuntimeEnvironment.dev.envFileName, '.env');
      expect(AppRuntimeEnvironment.staging.envFileName, '.env.staging');
      expect(AppRuntimeEnvironment.prod.envFileName, '.env.prod');
    });

    test('uses debug app check providers outside production', () {
      expect(
        AppRuntimeEnvironment.dev.androidProvider,
        isA<AndroidDebugProvider>(),
      );
      expect(AppRuntimeEnvironment.dev.appleProvider, isA<AppleDebugProvider>());
    });

    test('uses hardened app check providers in production', () {
      expect(
        AppRuntimeEnvironment.prod.androidProvider,
        isA<AndroidPlayIntegrityProvider>(),
      );
      expect(
        AppRuntimeEnvironment.prod.appleProvider,
        isA<AppleAppAttestWithDeviceCheckFallbackProvider>(),
      );
    });
  });

  group('router diagnostics', () {
    test('are only enabled for debug builds', () {
      expect(shouldEnableRouterDiagnostics(isDebugMode: true), isTrue);
      expect(shouldEnableRouterDiagnostics(isDebugMode: false), isFalse);
    });
  });
}
