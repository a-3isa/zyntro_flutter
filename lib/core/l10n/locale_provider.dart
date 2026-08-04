import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale_v1';

/// The user's chosen app language, or null to follow the device.
///
/// Mirrors [ThemeModeNotifier]'s shape so language and theme are chosen and
/// persisted the same way. A null value means "follow the system locale",
/// which is the default and what MaterialApp expects for that behaviour.
class LocaleNotifier extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_kLocaleKey));
  }

  /// Sets the app language. Pass null to follow the device again.
  Future<void> setLocale(Locale? locale) async {
    state = AsyncData(locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocaleKey);
    } else {
      await prefs.setString(_kLocaleKey, locale.languageCode);
    }
  }

  /// Language codes the app ships translations for.
  static const supportedLanguageCodes = <String>['en', 'ar'];

  static Locale? _parse(String? value) {
    if (value == null || !supportedLanguageCodes.contains(value)) return null;
    return Locale(value);
  }
}

final localeProvider = AsyncNotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

/// Whether [locale] is written right-to-left.
///
/// Flutter derives text direction from the locale automatically; this exists
/// for the places that need to branch on direction themselves, and so the
/// RTL language list lives in one place rather than being spelled out inline.
bool isRtlLocale(Locale locale) => rtlLanguageCodes.contains(locale.languageCode);

/// Right-to-left languages the app may serve. Arabic is the one it ships.
const rtlLanguageCodes = <String>{'ar', 'he', 'fa', 'ur'};
