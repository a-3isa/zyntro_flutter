import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/user_service.dart';
import '../../../../widgets/widgets.dart';
import '../profile_providers.dart';
import 'profile_award_card.dart';
import 'profile_history_widgets.dart';

/// Profile workout history tab (Z-ARCH-002).
class ProfileHistoryTab extends ConsumerWidget {
  const ProfileHistoryTab({super.key, required this.targetUserId});

  final String targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider(targetUserId));

    return sessionsAsync.when(
      data: (sessions) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          WeeklyVolumeChart(sessions: sessions),
          const SizedBox(height: AppSpacing.xl),
          ActivityHeatmap(sessions: sessions),
          const SizedBox(height: AppSpacing.xl),
          RecentSessionsList(sessions: sessions),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.signal,
          semanticsLabel: 'Loading workout history',
        ),
      ),
      error: (_, _) => AppErrorState(
        title: "Couldn't load history",
        onRetry: () => ref.invalidate(userSessionsProvider(targetUserId)),
      ),
    );
  }
}

/// Profile awards/badges tab (Z-ARCH-002).
class ProfileAwardsTab extends ConsumerWidget {
  const ProfileAwardsTab({super.key, required this.targetUserId});

  final String targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider(targetUserId));

    return badgesAsync.when(
      data: (earnedBadges) {
        final earnedIds = earnedBadges.map((b) => b.id).toSet();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: availableBadges.length,
          itemBuilder: (context, index) {
            final badge = availableBadges[index];
            final isEarned = earnedIds.contains(badge.id);
            return ProfileAwardCard(badge: badge, isEarned: isEarned);
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.signal,
        ),
      ),
      error: (_, _) => const SizedBox(),
    );
  }
}
