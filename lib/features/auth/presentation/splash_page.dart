import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/zyntro_button.dart';
import '../auth_providers.dart';

/// Welcome / Landing page. Shown to logged-out users; logged-in users see a
/// brief loader while the router sends them to the app (or to profile setup).
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);
    final user = authState.value;

    // Auth resolving, or already signed in → loader while the router routes.
    if (authState.isLoading || user != null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Starting Zyntro'),
        ),
      );
    }

    // Logged out → welcome with sign-up / sign-in.
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
                  colors: [AppColors.accentLimeGlowFaint, Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  Text(
                    'zyntro',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                      letterSpacing: -2.5,
                      height: 1,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Train. Compete. Dominate.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textV2Secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.signal.withValues(alpha: 0.27),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.bolt,
                        color: AppColors.signal,
                        size: 32,
                      ),
                    ),
                  ),

                  const Spacer(),

                  ZyntroButton(
                    title: 'Get Started',
                    fullWidth: true,
                    variant: ZyntroButtonVariant.primary,
                    size: ZyntroButtonSize.lg,
                    onPressed: () => context.go(AppRoutes.signUp),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: Text(
                      'Already have an account',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textV2Tertiary,
                      ),
                      textAlign: TextAlign.center,
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
