import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/auth_providers.dart';
import '../utils/global_error_handler.dart';

class ZyntroApp extends ConsumerWidget {
  const ZyntroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    // Apply the signed-in user's chosen neon color app-wide. Watching this
    // rebuilds the whole app when the color changes (login / onboarding /
    // sign-out), so every widget reading AppColors.userAccent recolors.
    final accent = ref.watch(accentColorProvider);
    AppColors.setAccent(accent);

    return MaterialApp.router(
      title: 'Zyntro',
      scaffoldMessengerKey: scannerMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: child!,
      ),
    );
  }
}
