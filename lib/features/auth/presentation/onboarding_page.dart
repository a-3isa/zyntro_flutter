import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/email_verification_banner.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/premium_animations.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/responsive_center.dart';
import '../auth_providers.dart';
import 'providers/auth_controller.dart';

/// Premium Onboarding screen with animated slides.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _iconController;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.fitness_center,
      title: 'Train Together',
      description:
          'Connect with workout buddies and train in real-time, no matter the distance.',
      gradientColors: AppColors.primaryGradient,
    ),
    _OnboardingSlide(
      icon: Icons.timer_outlined,
      title: 'Stay Accountable',
      description:
          'Track your sessions together and motivate each other to reach your goals.',
      gradientColors: AppColors.secondaryGradient,
    ),
    _OnboardingSlide(
      icon: Icons.emoji_events_outlined,
      title: 'Celebrate Wins',
      description:
          'Share your progress, earn badges, and celebrate achievements together.',
      gradientColors: AppColors.achievementGradient,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _iconScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _iconRotation = Tween<double>(
      begin: -0.1,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _iconController, curve: Curves.easeOut));
    _iconController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _iconController.forward(from: 0);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final isLastSlide = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background gradient orbs
          ..._buildBackgroundOrbs(),

          // Main content
          SafeArea(
            child: ResponsiveCenter(
              maxContentWidth: true,
              child: Column(
                children: [
                  // Email Verification Banner
                  Consumer(
                    builder: (context, ref, child) {
                      final authState = ref.watch(authSessionProvider);
                      final user = authState.valueOrNull;
                      if (user != null && !user.emailVerified) {
                        return EmailVerificationBanner(
                          onResendPressed: () async {
                            await ref
                                .read(authControllerProvider)
                                .sendEmailVerification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Verification email sent!',
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Skip button with fade animation
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: FadeInAnimation(
                        delay: const Duration(milliseconds: 200),
                        child: ScaleOnTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(storageServiceProvider)
                                .setHasSeenOnboarding(true);
                            context.go(AppRoutes.signUp);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Page view
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) => _buildSlide(index),
                    ),
                  ),

                  // Page indicators with tap support
                  _buildPageIndicators(),

                  const SizedBox(height: AppSpacing.xl),

                  // Next/Get Started button with gradient animation on final slide
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                    ),
                    child: isLastSlide
                        ? GradientBorderAnimation(
                            enabled: true,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.lg,
                            ),
                            gradientColors: AppColors.achievementGradient,
                            child: BounceAnimation(
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                ref
                                    .read(storageServiceProvider)
                                    .setHasSeenOnboarding(true);
                                context.go(AppRoutes.signUp);
                              },
                              child: ZyntroButton(
                                title: 'Create Account',
                                fullWidth: true,
                                size: ZyntroButtonSize.lg,
                                variant: ZyntroButtonVariant.premium,
                                rightIcon: const Icon(Icons.check_rounded),
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  ref
                                      .read(storageServiceProvider)
                                      .setHasSeenOnboarding(true);
                                  context.go(AppRoutes.signUp);
                                },
                              ),
                            ),
                          )
                        : BounceAnimation(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _pageController.nextPage(
                                duration: AppDurations.normal,
                                curve: Curves.easeInOut,
                              );
                            },
                            child: ZyntroButton(
                              title: 'Continue',
                              fullWidth: true,
                              size: ZyntroButtonSize.lg,
                              variant: ZyntroButtonVariant.primary,
                              rightIcon: const Icon(
                                Icons.arrow_forward_rounded,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _pageController.nextPage(
                                  duration: AppDurations.normal,
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundOrbs() {
    final slide = _slides[_currentPage];
    final mainColor = slide.gradientColors.first;

    return [
      Positioned(
        top: -100,
        right: -80,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                mainColor.withValues(alpha: 0.25),
                mainColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 50,
        left: -60,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                slide.gradientColors.last.withValues(alpha: 0.2),
                slide.gradientColors.last.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildSlide(int index) {
    final slide = _slides[index];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon container with slide-in animation
          SlideInAnimation.fromLeft(
            index: 0,
            duration: const Duration(milliseconds: 500),
            child: AnimatedBuilder(
              animation: _iconController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _iconScale.value,
                  child: Transform.rotate(
                    angle: _iconRotation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: slide.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: slide.gradientColors.first.withValues(alpha: 0.28),
                      blurRadius: 26,
                      offset: const Offset(0, 15),
                    ),
                    const BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: 64, color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Title with slide animation
          SlideInAnimation.fromBottom(
            index: 1,
            child: GradientText(
              text: slide.title,
              style: const TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.bold,
              ),
              colors: [AppColors.textDark, AppColors.textSecondaryDark],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Description with slide animation
          SlideInAnimation.fromBottom(
            index: 2,
            child: Text(
              slide.description,
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textSecondaryDark,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        final isActive = _currentPage == index;
        return ScaleOnTap(
          onTap: () {
            HapticFeedback.selectionClick();
            _pageController.animateToPage(
              index,
              duration: AppDurations.normal,
              curve: Curves.easeInOut,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              width: isActive ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: _slides[_currentPage].gradientColors,
                      )
                    : null,
                color: isActive ? null : AppColors.surfaceSecondaryDark,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}
