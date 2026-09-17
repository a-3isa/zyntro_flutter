import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_router.dart';
import '../core/constants/forced_update.dart';
import '../core/l10n/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/auth_providers.dart';
import '../features/update/presentation/forced_update_page.dart';
import '../l10n/app_localizations.dart';
import '../utils/global_error_handler.dart';

class ZyntroApp extends ConsumerWidget {
  const ZyntroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forcedUpdate = ref.watch(forcedUpdateRequiredProvider);
    if (forcedUpdate.value == true) {
      return MaterialApp(
        title: 'Zyntro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const ForcedUpdatePage(),
      );
    }

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;

    // Apply the signed-in user's chosen accent for avatars and gym type color.
    // App chrome (buttons, nav, focus) uses AppColors.signal and does not follow this.
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
      // WCAG 1.4.4 requires content remain usable at 200% text size. Shared
      // widgets are covered to 2.0x in test/app/text_scaling_test.dart (Z-A11Y-003).
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2.0,
        child: child!,
      ),
    );
  }
}
