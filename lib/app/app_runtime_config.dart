import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

enum AppRuntimeEnvironment {
  dev,
  staging,
  prod;

  static AppRuntimeEnvironment fromName(String value) {
    switch (value.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppRuntimeEnvironment.prod;
      case 'staging':
        return AppRuntimeEnvironment.staging;
      case 'dev':
      case 'development':
      default:
        return AppRuntimeEnvironment.dev;
    }
  }

  String get envFileName {
    switch (this) {
      case AppRuntimeEnvironment.dev:
        return '.env';
      case AppRuntimeEnvironment.staging:
        return '.env.staging';
      case AppRuntimeEnvironment.prod:
        return '.env.prod';
    }
  }

  AndroidAppCheckProvider get androidProvider {
    switch (this) {
      case AppRuntimeEnvironment.prod:
        return const AndroidPlayIntegrityProvider();
      case AppRuntimeEnvironment.dev:
      case AppRuntimeEnvironment.staging:
        return const AndroidDebugProvider();
    }
  }

  AppleAppCheckProvider get appleProvider {
    switch (this) {
      case AppRuntimeEnvironment.prod:
        return const AppleAppAttestWithDeviceCheckFallbackProvider();
      case AppRuntimeEnvironment.dev:
      case AppRuntimeEnvironment.staging:
        return const AppleDebugProvider();
    }
  }

  bool get usesAndroidDebugAppCheckProvider {
    return androidProvider is AndroidDebugProvider;
  }
}

bool shouldEnableRouterDiagnostics({bool isDebugMode = kDebugMode}) {
  return isDebugMode;
}
