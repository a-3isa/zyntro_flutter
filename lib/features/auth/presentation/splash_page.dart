import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/zyntro_button.dart';
import '../auth_providers.dart';

/// Welcome / Landing (formerly Splash) page — v2 design.
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
        backgroundColor: AppColors.backgroundV2,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle radial lime tint positioned at ~20% from top, centered
          Positioned(
            top: MediaQuery.of(context).size.height * 0.20 - 140,
            left: MediaQuery.of(context).size.width / 2 - 140,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0x10C8FF00), // #C8FF00 at ~6.3% opacity
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // "zyntro" wordmark
                  Text(
                    'zyntro',
                    style: GoogleFonts.syne(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textV2Primary,
                      letterSpacing: -2.5,
                      height: 1,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Train. Compete. Dominate.',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: AppColors.textV2Secondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Lightning bolt icon in circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentLime.withValues(alpha: 0.27),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bolt,
                        color: AppColors.accentLime,
                        size: 32,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // "Get started" primary button
                  ZyntroButton(
                    title: 'Get Started',
                    fullWidth: true,
                    variant: ZyntroButtonVariant.primary,
                    size: ZyntroButtonSize.lg,
                    onPressed: () => context.go(AppRoutes.onboarding),
                  ),

                  const SizedBox(height: 16),

                  // "Already have an account" text button
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Already have an account',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textV2Tertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
