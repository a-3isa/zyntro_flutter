import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Title and primary action on the login screen
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Title and primary action on the signup screen
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Primary action that registers a new account
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Greeting headline on the login screen
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Supporting line under the login headline
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your fitness journey'**
  String get signInSubtitle;

  /// Supporting line under the signup headline
  ///
  /// In en, this message translates to:
  /// **'Join Zyntro and start your fitness journey'**
  String get signUpSubtitle;

  /// Prompt shown when no account exists for an email
  ///
  /// In en, this message translates to:
  /// **'Create an account to get started.'**
  String get createAccountPrompt;

  /// Label for the email input field
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// Label for the password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Label for the repeat-password input field
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Link to the password reset flow
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Prefix before the link back to sign in
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Link returning to the login screen
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// Confirmation heading after a reset email is sent
  ///
  /// In en, this message translates to:
  /// **'Check Your Email'**
  String get checkYourEmail;

  /// Action that sends a password reset email
  ///
  /// In en, this message translates to:
  /// **'Send Reset Email'**
  String get sendResetEmail;

  /// Action that sends the reset email again
  ///
  /// In en, this message translates to:
  /// **'Resend Email'**
  String get resendEmail;

  /// Cooldown label before the reset email can be resent
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendInSeconds(int seconds);

  /// In-flight label while a request is being sent
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// Validation error for a blank email field
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get enterEmail;

  /// Validation error for a malformed email address
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get enterValidEmail;

  /// Validation error for a blank password field
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get enterPassword;

  /// Validation error for a blank confirm-password field
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmYourPassword;

  /// Validation error when the two password fields differ
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Generic failure message for signing in
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailed;

  /// Generic failure message for signing up
  ///
  /// In en, this message translates to:
  /// **'Sign-up failed. Please try again.'**
  String get signUpFailed;

  /// Failure message for Google authentication
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed. Please try again.'**
  String get googleSignInFailed;

  /// Failure message for Facebook authentication
  ///
  /// In en, this message translates to:
  /// **'Facebook Sign-In failed. Please try again.'**
  String get facebookSignInFailed;

  /// Error shown when an email is not registered
  ///
  /// In en, this message translates to:
  /// **'No account found with this email address.'**
  String get noAccountForEmail;

  /// Rate-limit error after repeated failed attempts
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get tooManyAttempts;

  /// Error shown when the reset email could not be sent
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email. Please try again.'**
  String get resetEmailFailed;

  /// Retry action on an error state
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Default supporting line on a network error state
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkConnection;

  /// Main shell bottom nav — feed tab
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// Main shell FAB when not ready to start
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get navTrain;

  /// Main shell FAB when a workout type is selected
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get navStartSession;

  /// Main shell FAB when start is blocked
  ///
  /// In en, this message translates to:
  /// **'Pick a workout type'**
  String get navPickWorkoutType;

  /// Main shell bottom nav — profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Main shell / social destination label
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get navSocial;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Social page Board tab
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get socialTabBoard;

  /// Social page Buddies tab
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get socialTabBuddies;

  /// Social page Find tab
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get socialTabFind;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
