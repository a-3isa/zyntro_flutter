import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Locale-aware number and relative-time helpers (Z-I18N-004).
class LocaleFormat {
  LocaleFormat._();

  static bool _timeagoRegistered = false;

  /// Call once at startup so `timeago.format(..., locale: 'ar')` works.
  static void registerTimeagoLocales() {
    if (_timeagoRegistered) return;
    timeago.setLocaleMessages('en', timeago.EnMessages());
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _timeagoRegistered = true;
  }

  static String relative(
    DateTime date, {
    Locale? locale,
  }) {
    registerTimeagoLocales();
    final code =
        locale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final normalized = code.startsWith('ar') ? 'ar' : 'en';
    return timeago.format(date, locale: normalized);
  }

  static String decimal(
    num value, {
    Locale? locale,
    int fractionDigits = 1,
  }) {
    final code =
        locale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final format = NumberFormat.decimalPattern(code);
    format.minimumFractionDigits = fractionDigits;
    format.maximumFractionDigits = fractionDigits;
    return format.format(value);
  }

  static String compact(
    num value, {
    Locale? locale,
  }) {
    final code =
        locale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return NumberFormat.compact(locale: code).format(value);
  }
}
