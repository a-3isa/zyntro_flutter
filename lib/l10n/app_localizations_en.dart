// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to continue your fitness journey';

  @override
  String get signUpSubtitle => 'Join Zyntro and start your fitness journey';

  @override
  String get createAccountPrompt => 'Create an account to get started.';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get backToSignIn => 'Back to Sign In';

  @override
  String get checkYourEmail => 'Check Your Email';

  @override
  String get sendResetEmail => 'Send Reset Email';

  @override
  String get resendEmail => 'Resend Email';

  @override
  String resendInSeconds(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get sending => 'Sending...';

  @override
  String get enterEmail => 'Please enter your email address';

  @override
  String get enterValidEmail => 'Please enter a valid email address';

  @override
  String get enterPassword => 'Please enter your password';

  @override
  String get confirmYourPassword => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get signInFailed => 'Sign-in failed. Please try again.';

  @override
  String get signUpFailed => 'Sign-up failed. Please try again.';

  @override
  String get googleSignInFailed => 'Google Sign-In failed. Please try again.';

  @override
  String get facebookSignInFailed =>
      'Facebook Sign-In failed. Please try again.';

  @override
  String get noAccountForEmail => 'No account found with this email address.';

  @override
  String get tooManyAttempts => 'Too many attempts. Please try again later.';

  @override
  String get resetEmailFailed =>
      'Failed to send reset email. Please try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get checkConnection => 'Check your connection and try again.';
}
