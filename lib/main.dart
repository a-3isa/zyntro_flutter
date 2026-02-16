import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'utils/offline_handlers.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

import 'utils/global_error_handler.dart';
import 'widgets/error_boundary_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Load environment-specific .env file
  // Use: flutter run --dart-define=ENV=dev|staging|prod
  const environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  final envFile = environment == 'dev' ? '.env' : '.env.$environment';

  try {
    await dotenv.load(fileName: envFile);
  } catch (e) {
    // Fallback to default .env
    await dotenv.load(fileName: '.env');
  }

  // Initialize Global Error Handler
  GlobalErrorHandler().init();

  // Initialize Stripe
  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

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
