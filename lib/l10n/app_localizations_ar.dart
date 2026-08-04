// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get welcomeBack => 'أهلاً بعودتك';

  @override
  String get signInSubtitle => 'سجّل الدخول لمواصلة رحلتك الرياضية';

  @override
  String get signUpSubtitle => 'انضم إلى Zyntro وابدأ رحلتك الرياضية';

  @override
  String get createAccountPrompt => 'أنشئ حساباً للبدء.';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get checkYourEmail => 'تحقّق من بريدك الإلكتروني';

  @override
  String get sendResetEmail => 'إرسال رابط إعادة التعيين';

  @override
  String get resendEmail => 'إعادة الإرسال';

  @override
  String resendInSeconds(int seconds) {
    return 'إعادة الإرسال خلال $seconds ثانية';
  }

  @override
  String get sending => 'جارٍ الإرسال...';

  @override
  String get enterEmail => 'من فضلك أدخل بريدك الإلكتروني';

  @override
  String get enterValidEmail => 'من فضلك أدخل بريداً إلكترونياً صحيحاً';

  @override
  String get enterPassword => 'من فضلك أدخل كلمة المرور';

  @override
  String get confirmYourPassword => 'من فضلك أكّد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get signInFailed => 'فشل تسجيل الدخول. من فضلك حاول مرة أخرى.';

  @override
  String get signUpFailed => 'فشل إنشاء الحساب. من فضلك حاول مرة أخرى.';

  @override
  String get googleSignInFailed =>
      'فشل تسجيل الدخول عبر Google. من فضلك حاول مرة أخرى.';

  @override
  String get facebookSignInFailed =>
      'فشل تسجيل الدخول عبر Facebook. من فضلك حاول مرة أخرى.';

  @override
  String get noAccountForEmail => 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';

  @override
  String get tooManyAttempts => 'محاولات كثيرة. من فضلك حاول لاحقاً.';

  @override
  String get resetEmailFailed =>
      'تعذّر إرسال رسالة إعادة التعيين. من فضلك حاول مرة أخرى.';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get checkConnection => 'تحقّق من اتصالك وحاول مرة أخرى.';
}
