import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../services/buddy_service.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/zyntro_card.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';
import '../../../utils/haptic_manager.dart';
import '../../../services/notification_service.dart';
import '../../../services/auth_service.dart';

/// Premium Session tab entry point.
class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddyPairAsync = ref.watch(currentBuddyPairProvider);

    final authState = ref.watch(authStateProvider);
    final uid = authState.valueOrNull?.uid;
    final unreadCountAsync = uid != null
        ? ref.watch(unreadCountProvider(uid))
        : const AsyncValue.data(0);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const GradientText(
                  text: 'Session',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Badge(
                            label: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(fontSize: 10),
                            ),
                            isLabelVisible: count > 0,
                            backgroundColor: AppColors.secondary,
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.textDark,
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero section with gradient
                  _buildHeroSection(context),

                  const SizedBox(height: AppSpacing.xl),

                  // Buddy status card
                  buddyPairAsync.when(
                    data: (buddyPair) {
                      if (buddyPair != null) {
                        return _buildBuddyCard(context, buddyPair.participants);
                      }
                      return _buildNoBuddyCard(context);
                    },
                    loading: () => const _BuddyCardSkeleton(),
                    error: (_, _) => _buildNoBuddyCard(context),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Quick stats section
                  Text(
                    'Your Stats',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.local_fire_department_rounded,
                          value: '7',
                          label: 'Day Streak',
                          gradientColors: AppColors.secondaryGradient,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.fitness_center_rounded,
                          value: '24',
                          label: 'This Month',
                          gradientColors: AppColors.primaryGradient,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Recent workouts placeholder
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAction(
                          context,
                          icon: Icons.bolt_rounded,
                          label: 'Strength',
                          color: AppColors.primary,
                          onTap: () => context.push(
                            '${AppRoutes.startSession}?type=strength',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildQuickAction(
                          context,
                          icon: Icons.directions_run_rounded,
                          label: 'Cardio',
                          color: AppColors.secondary,
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return GlowContainer(
      glowColor: AppColors.primaryGlow,
      blurRadius: 30,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2940), Color(0xFF0D1520)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            // Animated icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const GradientText(
              text: 'Ready to Train?',
              style: TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.bold,
              ),
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start a solo or buddy session',
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ZyntroButton(
              title: 'Start Session',
              fullWidth: true,
              size: ZyntroButtonSize.lg,
              rightIcon: const Icon(Icons.arrow_forward_rounded),
              onPressed: () => context.push(AppRoutes.startSession),
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
      glowColor: AppColors.successGlow,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.successGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workout Buddy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'You have an active buddy pair!',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
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
      onTap: () => context.push(AppRoutes.startSession),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find a Buddy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Train together with a friend',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Invite',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.sm,
              ),
            ),
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
    required List<Color> gradientColors,
  }) {
    return ZyntroCard(
      variant: ZyntroCardVariant.glass,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppFontSize.xxxl,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: AppFontSize.sm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ZyntroCard(
      variant: ZyntroCardVariant.glass,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for buddy card.
class _BuddyCardSkeleton extends StatelessWidget {
  const _BuddyCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ZyntroCard(
      variant: ZyntroCardVariant.glass,
      child: Row(
        children: [
          const ShimmerLoader(
            width: 50,
            height: 50,
            borderRadius: BorderRadius.all(Radius.circular(25)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoader(width: 120, height: 16),
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
