import 'package:flutter_dotenv/flutter_dotenv.dart';

class RuntimeEnvironmentValues {
  const RuntimeEnvironmentValues._();

  static String get stripePublishableKey {
    const value = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    return value.isNotEmpty ? value : localEnvValue('STRIPE_PUBLISHABLE_KEY');
  }

  static String localEnvValue(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }
}
