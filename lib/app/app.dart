import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_router.dart';
import '../core/l10n/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../utils/global_error_handler.dart';

class ZyntroApp extends ConsumerWidget {
  const ZyntroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;

    // Apply the signed-in user's chosen neon color app-wide. Watching this
    // rebuilds the whole app when the color changes (login / onboarding /
    // sign-out), so every widget reading AppColors.userAccent recolors.
    final accent = ref.watch(accentColorProvider);
    AppColors.setAccent(accent);

    // null follows the device locale, which is what MaterialApp expects for
    // that behaviour. Arabic is right-to-left; Flutter flips the whole
    // directionality from the locale, so nothing here has to say so.
    final locale = ref.watch(localeProvider).value;

    return MaterialApp.router(
      title: 'Zyntro',
      scaffoldMessengerKey: scannerMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: child!,
      ),
    );
  }
}
