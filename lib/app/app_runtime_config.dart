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

  AndroidProvider get androidProvider {
    switch (this) {
      case AppRuntimeEnvironment.prod:
        return AndroidProvider.playIntegrity;
      case AppRuntimeEnvironment.dev:
      case AppRuntimeEnvironment.staging:
        return AndroidProvider.debug;
    }
  }

  AppleProvider get appleProvider {
    switch (this) {
      case AppRuntimeEnvironment.prod:
        return AppleProvider.appAttestWithDeviceCheckFallback;
      case AppRuntimeEnvironment.dev:
      case AppRuntimeEnvironment.staging:
        return AppleProvider.debug;
    }
  }
}

bool shouldEnableRouterDiagnostics({bool isDebugMode = kDebugMode}) {
  return isDebugMode;
}
