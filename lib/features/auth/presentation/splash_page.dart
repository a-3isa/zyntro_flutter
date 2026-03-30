import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/premium_effects.dart';
import '../auth_providers.dart';

/// Welcome / Landing (formerly Splash) page.
/// Displays branding and entry points (Get Started / Sign In).
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);
    final isLoading = authState.isLoading;
    final user = authState.valueOrNull;

    // If already logged in, show loader while router redirects (handled by app_router)
    if (isLoading || user != null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A0E1A),
                  Color(0xFF141B2D),
                  Color(0xFF0A0E1A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // App Title
                  const GradientText(
                    text: 'ZYNTRO',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                    colors: [
                      AppColors.primary,
                      AppColors.premium,
                      AppColors.secondary,
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Tagline
                  Text(
                    'Sync Your Sweat – Workout Together, Anywhere',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      color: AppColors.textSecondaryDark,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // Action Buttons
                  Column(
                    children: [
                      ZyntroButton(
                        title: 'Get Started',
                        fullWidth: true,
                        variant: ZyntroButtonVariant.primary,
                        size: ZyntroButtonSize.lg,
                        onPressed: () => context.go(AppRoutes.onboarding),
                        rightIcon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.login),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(
                                fontSize: AppFontSize.md,
                                color: AppColors.textSecondaryDark,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Sign In',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
