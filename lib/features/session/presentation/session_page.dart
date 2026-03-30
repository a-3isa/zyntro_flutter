import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../auth/auth_providers.dart';
import '../../../services/buddy_service.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/zyntro_card.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';
import '../../../utils/haptic_manager.dart';
import '../../../services/notification_service.dart';

/// Premium Session tab entry point.
class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddyPairAsync = ref.watch(currentBuddyPairProvider);

    final authState = ref.watch(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    final unreadCountAsync = uid != null
        ? ref.watch(unreadCountProvider(uid))
        : const AsyncValue.data(0);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header with Premium Styling
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const GradientText(
                  text: 'Session',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  colors: [AppColors.textDark, AppColors.textSecondaryDark],
                ),
                if (uid != null)
                  unreadCountAsync.when(
                    data: (count) {
                      return BounceAnimation(
                        onTap: () {
                          HapticManager.light();
                          context.push(AppRoutes.notifications);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Badge(
                            label: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            isLabelVisible: count > 0,
                            backgroundColor: AppColors.secondary,
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textDark,
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondaryDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticManager.medium();
                ref.invalidate(currentBuddyPairProvider);
                if (uid != null) ref.invalidate(unreadCountProvider(uid));
              },
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceDark,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero section with gradient
                    SlideInAnimation(
                      index: 0,
                      child: _buildHeroSection(context),
                    ),

                    const SizedBox(height: 28),

                    // Buddy status section
                    SlideInAnimation(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Workout Buddy'),
                          const SizedBox(height: 12),
                          buddyPairAsync.when(
                            data: (buddyPair) {
                              if (buddyPair != null) {
                                return _buildBuddyCard(
                                  context,
                                  buddyPair.participants,
                                );
                              }
                              return _buildNoBuddyCard(context);
                            },
                            loading: () => const _BuddyCardSkeleton(),
                            error: (_, _) => _buildNoBuddyCard(context),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Quick stats section
                    SlideInAnimation(
                      index: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Your Performance'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  icon: Icons.local_fire_department_rounded,
                                  value: '7',
                                  label: 'Day Streak',
                                  gradient: AppColors.secondaryGradient,
                                  index: 0,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  icon: Icons.fitness_center_rounded,
                                  value: '24',
                                  label: 'This Month',
                                  gradient: AppColors.primaryGradient,
                                  index: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Quick Actions
                    SlideInAnimation(
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Quick Start'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickAction(
                                  context,
                                  icon: Icons.bolt_rounded,
                                  label: 'Strength',
                                  color: AppColors.primary,
                                  index: 0,
                                  onTap: () => context.push(
                                    '${AppRoutes.startSession}?type=strength',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildQuickAction(
                                  context,
                                  icon: Icons.directions_run_rounded,
                                  label: 'Cardio',
                                  color: AppColors.secondary,
                                  index: 1,
                                  onTap: () => context.push(
                                    '${AppRoutes.startSession}?type=cardio',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return GlowContainer(
      glowColor: AppColors.primaryGlow.withValues(alpha: 0.3),
      blurRadius: 40,
      child: GlassContainer(
        blur: 15,
        backgroundColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            // Animated icon circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const PulseAnimation(
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const GradientText(
              text: 'Ready to Train?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              colors: [AppColors.textDark, AppColors.primaryLight],
            ),
            const SizedBox(height: 8),
            Text(
              'Start a solo or buddy session',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 32),
            ZyntroButton(
              title: 'Start Session',
              fullWidth: true,
              size: ZyntroButtonSize.lg,
              variant: ZyntroButtonVariant.premium,
              rightIcon: const Icon(Icons.arrow_forward_rounded, size: 20),
              onPressed: () {
                HapticManager.medium();
                context.push(AppRoutes.startSession);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuddyCard(BuildContext context, List<String> participants) {
    return ZyntroCard(
      variant: ZyntroCardVariant.glass,
      showGlow: true,
      glowColor: AppColors.successGlow.withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.successGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.people_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Training Partner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connected for synced sessions',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBuddyCard(BuildContext context) {
    return ZyntroCard(
      variant: ZyntroCardVariant.glass,
      onTap: () {
        HapticManager.light();
        context.push(AppRoutes.startSession);
      },
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find a Buddy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Train together for 2x results',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiaryDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required List<Color> gradient,
    required int index,
  }) {
    return SlideInAnimation.fromBottom(
      index: index,
      child: GlassContainer(
        blur: 10,
        backgroundColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required int index,
    required VoidCallback onTap,
  }) {
    return SlideInAnimation.fromRight(
      index: index,
      child: ScaleOnTap(
        onTap: () {
          HapticManager.light();
          onTap();
        },
        child: GlassContainer(
          blur: 10,
          backgroundColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: AppColors.textDark,
      ),
    );
  }
}

/// Skeleton loader for buddy card.
class _BuddyCardSkeleton extends StatelessWidget {
  const _BuddyCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 10,
      backgroundColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const ShimmerLoader(
            width: 52,
            height: 52,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoader(width: 140, height: 16),
                SizedBox(height: 8),
                ShimmerLoader(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
