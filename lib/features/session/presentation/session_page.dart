import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../auth/auth_providers.dart';
import '../../../services/buddy_service.dart';
import '../../../widgets/zyntro_button.dart';
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
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // ── Animated background orbs ──────────────────────────────────────
          _buildBackground(),

          Column(
            children: [
              // ── Header (Elite Brutalist Glass) ────────────────────────────
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617).withValues(alpha: 0.7),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 16,
                      bottom: 16,
                      left: 20,
                      right: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SESSIONS',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'TRAIN. LOG. DOMINATE.',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.5,
                                color: AppColors.primary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        if (uid != null)
                          unreadCountAsync.when(
                            data: (count) => BounceAnimation(
                              onTap: () {
                                HapticManager.light();
                                context.push(AppRoutes.notifications);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 2,
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
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            loading: () => Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        AppColors.primary),
                                  ),
                                ),
                              ),
                            ),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Body ──────────────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    HapticManager.medium();
                    ref.invalidate(currentBuddyPairProvider);
                    if (uid != null) ref.invalidate(unreadCountProvider(uid));
                  },
                  color: AppColors.primary,
                  backgroundColor: const Color(0xFF0F172A),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero CTA Card
                        SlideInAnimation(
                          index: 0,
                          child: _buildHeroSection(context),
                        ),

                        const SizedBox(height: 32),

                        // Buddy Status
                        SlideInAnimation(
                          index: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(title: 'WORKOUT BUDDY'),
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

                        const SizedBox(height: 32),

                        // Performance Stats
                        SlideInAnimation(
                          index: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(title: 'YOUR PERFORMANCE'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      icon: Icons.local_fire_department_rounded,
                                      value: '7',
                                      label: 'DAY STREAK',
                                      accentColor: AppColors.secondary,
                                      index: 0,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      icon: Icons.fitness_center_rounded,
                                      value: '24',
                                      label: 'THIS MONTH',
                                      accentColor: AppColors.primary,
                                      index: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Quick Start
                        SlideInAnimation(
                          index: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(title: 'QUICK START'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickAction(
                                      context,
                                      icon: Icons.bolt_rounded,
                                      label: 'STRENGTH',
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
                                      label: 'CARDIO',
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
        ],
      ),
    );
  }

  // ── Background ─────────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFF020617)),
        Positioned(
          top: -100,
          right: -100,
          child: PulseAnimation(
            duration: const Duration(seconds: 8),
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -200,
          left: -150,
          child: PulseAnimation(
            duration: const Duration(seconds: 12),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero Section ───────────────────────────────────────────────────────────
  Widget _buildHeroSection(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              // Pulsing icon block
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const PulseAnimation(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'READY TO TRAIN?',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Start a solo or buddy session',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              ZyntroButton(
                title: 'START SESSION',
                fullWidth: true,
                size: ZyntroButtonSize.lg,
                variant: ZyntroButtonVariant.premium,
                rightIcon:
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                onPressed: () {
                  HapticManager.medium();
                  context.push(AppRoutes.startSession);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Buddy Cards ────────────────────────────────────────────────────────────
  Widget _buildBuddyCard(BuildContext context, List<String> participants) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.05),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
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
                ),
                child: const Icon(Icons.people_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE TRAINING PARTNER',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connected for synced sessions',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                    width: 2,
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
        ),
      ),
    );
  }

  Widget _buildNoBuddyCard(BuildContext context) {
    return BounceAnimation(
      onTap: () {
        HapticManager.light();
        context.push(AppRoutes.startSession);
      },
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
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
                        'FIND A BUDDY',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Train together for 2x results',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Stat Cards ─────────────────────────────────────────────────────────────
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color accentColor,
    required int index,
  }) {
    return SlideInAnimation.fromBottom(
      index: index,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.05),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, size: 26, color: accentColor),
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: accentColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Quick Action Cards ─────────────────────────────────────────────────────
  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required int index,
    required VoidCallback onTap,
    ZyntroButtonVariant variant = ZyntroButtonVariant.primary,
  }) {
    return SlideInAnimation.fromRight(
      index: index,
      child: BounceAnimation(
        onTap: () {
          HapticManager.light();
          onTap();
        },
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: variant == ZyntroButtonVariant.primary ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, size: 30, color: color),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Skeleton loader for buddy card.
class _BuddyCardSkeleton extends StatelessWidget {
  const _BuddyCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              const ShimmerLoader(
                width: 52,
                height: 52,
                borderRadius: BorderRadius.zero,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerLoader(width: 140, height: 14),
                    SizedBox(height: 8),
                    ShimmerLoader(width: 180, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
