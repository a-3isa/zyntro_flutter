import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_runtime_config.dart';
import 'app/launch_intent.dart';
import 'utils/offline_handlers.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'utils/global_error_handler.dart';
import 'widgets/error_boundary_widget.dart';
import 'services/feed_cache_service.dart';

const _appCheckDebugChannelName = 'zyntro/debug';
const _appCheckDebugSecretMethodName = 'getAppCheckDebugSecret';
const _logAppCheckDebugSecret = bool.fromEnvironment(
  'LOG_APP_CHECK_DEBUG_SECRET',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;

  // Flutter's debugPrint is NOT stripped from release builds — it writes to the
  // platform log (logcat on Android), where any app on the device with log
  // access can read it. The app has 227 debugPrint call sites, 97 of which
  // interpolate a caught exception, and an exception's toString() routinely
  // embeds user content. Silencing the sink in release closes all of them at
  // once, and keeps debug logging untouched.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await Firebase.initializeApp();

  // Load environment-specific .env file
  // Use: flutter run --dart-define=ENV=dev|staging|prod
  final environment = AppRuntimeEnvironment.fromName(
    const String.fromEnvironment(
      'ENV',
      defaultValue: kReleaseMode ? 'prod' : 'dev',
    ),
  );
  final envFile = environment.envFileName;

  debugPrint(
    '[AppCheck] ENV=${environment.name}, androidProvider=${environment.androidProvider}, appleProvider=${environment.appleProvider}',
  );

  await _loadLocalEnvironment(envFile);

  // Crash reporting stays off in debug so development crashes never land in
  // production crash data. GlobalErrorHandler also skips reporting in debug;
  // this covers native crashes, which never reach the Dart handler.
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  } catch (e, st) {
    _debugPrintStartupFailure('Crashlytics', e, st);
  }

  // Initialize Global Error Handler
  GlobalErrorHandler().init();

  // Initialize App Check — wrapped so a Play Integrity failure in release
  // doesn't prevent runApp() from being called.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: environment.androidProvider,
      providerApple: environment.appleProvider,
    );
  } catch (e, st) {
    _debugPrintStartupFailure('AppCheck', e, st);
  }

  await _logAndroidAppCheckDebugSecretIfNeeded(environment);

  // Register FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final sharedPrefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
  );

  // Resolve notification-vs-resume BEFORE the first GoRouter redirect.
  // getInitialMessage does not show a permission dialog. Unknown used to
  // default to "explicit destination", which latched ResumeNone on every
  // ordinary cold start because NotificationService.init() runs after runApp.
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    LaunchIntent.instance.hasExplicitDestination = initialMessage != null;
  } catch (e, st) {
    LaunchIntent.instance.hasExplicitDestination = false;
    _debugPrintStartupFailure('LaunchIntent', e, st);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ErrorBoundaryWidget(child: ZyntroApp()),
    ),
  );

  // Deliberately after runApp: none of these gate the first frame, and awaiting
  // them serially beforehand held the splash screen for the duration of a
  // notification-permission round trip. They run concurrently now, and each
  // still swallows its own failure so one bad init cannot take down startup.
  unawaited(_initDeferredServices(container));
}

/// Startup work that the first frame does not depend on.
Future<void> _initDeferredServices(ProviderContainer container) async {
  await Future.wait([
    _guarded(
      'NotificationService',
      () => container.read(notificationServiceProvider).init(),
    ),
    _guarded(
      'StorageService',
      () => container.read(storageServiceProvider).init(),
    ),
    _guarded('OfflineHandlers', () => registerOfflineHandlers(container)),
  ]);
}

Future<void> _guarded(String component, Future<void> Function() init) async {
  try {
    await init();
  } catch (e, st) {
    _debugPrintStartupFailure(component, e, st);
  }
}

void _debugPrintStartupFailure(
  String component,
  Object error, [
  StackTrace? stackTrace,
]) {
  debugPrint('[$component] Init failed (non-fatal): $error');
  if (kDebugMode && stackTrace != null) {
    debugPrint('[$component] Stack: $stackTrace');
  }

  // debugPrint is silenced in release, so without this a failed startup
  // service would be completely invisible in production. Reported as
  // non-fatal: the app deliberately carries on when one of these fails.
  if (kReleaseMode) {
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(
            error,
            stackTrace,
            fatal: false,
            reason: '$component init failed: ${scrubForReport(error)}',
          )
          .catchError((_) {}),
    );
  }
}

Future<void> _loadLocalEnvironment(String envFile) async {
  try {
    await dotenv.load(fileName: envFile);
    return;
  } catch (_) {
    // Local env files are intentionally not bundled in release artifacts.
  }

  if (envFile == '.env') {
    return;
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Continue with dart-define values when no local env file is available.
  }
}

Future<void> _logAndroidAppCheckDebugSecretIfNeeded(
  AppRuntimeEnvironment environment,
) async {
  if (!kDebugMode || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  if (!environment.usesAndroidDebugAppCheckProvider) {
    return;
  }
  if (!_logAppCheckDebugSecret) {
    debugPrint(
      '[AppCheck] Android debug secret check disabled. Use --dart-define=LOG_APP_CHECK_DEBUG_SECRET=true to verify local availability.',
    );
    return;
  }

  try {
    await FirebaseAppCheck.instance.getToken(true);
  } catch (error) {
    debugPrint(
      '[AppCheck] Debug token exchange failed before allowlisting, reading local secret next: $error',
    );
  }

  try {
    final secret = await const MethodChannel(
      _appCheckDebugChannelName,
    ).invokeMethod<String>(_appCheckDebugSecretMethodName);

    if (secret == null || secret.isEmpty) {
      debugPrint(
        '[AppCheck] Android debug secret is not available yet. Trigger a Firebase request and try again.',
      );
      return;
    }

    debugPrint(
      '[AppCheck] Android debug secret is available but is not printed by the app.',
    );
  } on MissingPluginException {
    debugPrint(
      '[AppCheck] Android debug secret channel is unavailable in this build.',
    );
  } catch (error) {
    debugPrint('[AppCheck] Unable to read Android debug secret: $error');
  }
}
