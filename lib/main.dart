import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'app/app_runtime_config.dart';
import 'app/runtime_environment_values.dart';
import 'utils/offline_handlers.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

import 'utils/global_error_handler.dart';
import 'widgets/error_boundary_widget.dart';

const _appCheckDebugChannelName = 'zyntro/debug';
const _appCheckDebugSecretMethodName = 'getAppCheckDebugSecret';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Initialize Global Error Handler
  GlobalErrorHandler().init();

  // Initialize Stripe
  Stripe.publishableKey = RuntimeEnvironmentValues.stripePublishableKey;

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: environment.androidProvider,
    appleProvider: environment.appleProvider,
  );
  await _logAndroidAppCheckDebugSecretIfNeeded(environment);

  // Register FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final container = ProviderContainer();

  // Initialize notification service
  await container.read(notificationServiceProvider).init();

  // Initialize storage service
  await container.read(storageServiceProvider).init();

  // Register offline handlers
  await registerOfflineHandlers(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ErrorBoundaryWidget(child: ZyntroApp()),
    ),
  );
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
  if (environment.androidProvider != AndroidProvider.debug) {
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

    debugPrint('[AppCheck] Android debug secret: $secret');
  } on MissingPluginException {
    debugPrint(
      '[AppCheck] Android debug secret channel is unavailable in this build.',
    );
  } catch (error) {
    debugPrint('[AppCheck] Unable to read Android debug secret: $error');
  }
}
