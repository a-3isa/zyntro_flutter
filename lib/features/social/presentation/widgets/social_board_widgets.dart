import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/follow_service.dart';
import '../../../../services/leaderboard_service.dart';
import '../../../../services/user_service.dart';
import '../../../../utils/haptic_manager.dart';

// ── Board tab ─────────────────────────────────────────────────────────────────

class SocialBoardContent extends ConsumerStatefulWidget {
  final String userId;
  const SocialBoardContent({super.key, required this.userId});

  @override
  ConsumerState<SocialBoardContent> createState() => _SocialBoardContentState();
}

class _SocialBoardContentState extends ConsumerState<SocialBoardContent> {
  bool _isFriends = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Friends / Global toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _toggleBtn('Friends', _isFriends, () {
                  HapticManager.selection();
                  setState(() => _isFriends = true);
                }),
                _toggleBtn('Global', !_isFriends, () {
                  HapticManager.selection();
                  setState(() => _isFriends = false);
                }),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isFriends
              ? _FriendsLeaderboard(userId: widget.userId)
              : const _GlobalUpsell(),
        ),
      ],
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceV2Active : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 13,
              color: active
                  ? AppColors.textV2Primary
                  : AppColors.textV2Secondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Friends leaderboard ───────────────────────────────────────────────────────

class _FriendsLeaderboard extends ConsumerWidget {
  final String userId;
  const _FriendsLeaderboard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) {
      return Center(
        child: Text(
          'Please sign in to view leaderboard',
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
        ),
      );
    }

    final leaderboardAsync = ref.watch(friendsLeaderboardProvider(userId));

    if (!kServerScoresLive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 56,
                color: AppColors.textV2Tertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Leaderboard pausing',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rankings will return once workout scores are verified on the server.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return leaderboardAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 56,
                    color: AppColors.textV2Tertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow people to see your friends leaderboard',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textV2Secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return _buildLeaderboardList(context, entries);
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: AppColors.signal,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load leaderboard',
              style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(
    BuildContext context,
    List<LeaderboardEntry> entries,
  ) {
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    final me = entries.firstWhere(
      (e) => e.isCurrentUser,
      orElse: () => entries.isNotEmpty ? entries.first : _emptyEntry(),
    );

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Podium
        if (top3.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (top3.length > 1)
                  _PodiumSpot(entry: top3[1], rank: 2, height: 90),
                if (top3.isNotEmpty)
                  _PodiumSpot(entry: top3[0], rank: 1, height: 116),
                if (top3.length > 2)
                  _PodiumSpot(entry: top3[2], rank: 3, height: 74),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        // My rank card
        if (entries.any((e) => e.isCurrentUser)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.signal.withValues(alpha: 0.40),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '#${me.rank}',
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.signal,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.displayName,
                          style: AppTextStyles.h5.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${me.score} pts · ${me.streak}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textV2Secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'You',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.signal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Remaining rows (rank 4+)
        ...rest.map((entry) => _LeaderboardRow(entry: entry)),
      ],
    );
  }

  LeaderboardEntry _emptyEntry() => LeaderboardEntry(
    userId: '',
    displayName: '',
    score: 0,
    rank: 0,
  );
}

// ── Podium spot ───────────────────────────────────────────────────────────────

class _PodiumSpot extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double height;

  const _PodiumSpot({
    required this.entry,
    required this.rank,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const podiumColors = {
      1: AppColors.accentGold,
      2: AppColors.accentSilver,
      3: AppColors.accentBronze,
    };
    final podiumColor = podiumColors[rank]!;
    final avatarRadius = rank == 1 ? 30.0 : 24.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rank == 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('👑', style: TextStyle(fontSize: 22)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: podiumColor.withValues(alpha: 0.20),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: podiumColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: entry.isCurrentUser
                    ? AppColors.signal
                    : podiumColor.withValues(alpha: 0.60),
                width: entry.isCurrentUser ? 2.5 : 2,
              ),
            ),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: podiumColor.withValues(alpha: 0.25),
              backgroundImage: entry.photoURL != null
                  ? CachedNetworkImageProvider(entry.photoURL!)
                  : null,
              child: entry.photoURL == null
                  ? Text(
                      entry.displayName.isNotEmpty
                          ? entry.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: podiumColor,
                        fontWeight: FontWeight.w800,
                        fontSize: rank == 1 ? 20 : 16,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 76,
            child: Text(
              entry.displayName,
              style: AppTextStyles.h5.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: entry.isCurrentUser
                    ? AppColors.signal
                    : AppColors.textV2Primary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.score} pts',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textV2Tertiary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 76,
            height: height,
            decoration: BoxDecoration(
              color: podiumColor.withValues(alpha: 0.14),
              border: Border.all(
                color: podiumColor.withValues(alpha: 0.45),
                width: 1.5,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: AppTextStyles.h5.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: podiumColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard row (rank 4+) ─────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.signal.withValues(alpha: 0.08)
            : AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppColors.signal.withValues(alpha: 0.35)
              : AppColors.surfaceV2Elevated,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: AppTextStyles.h4.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: entry.isCurrentUser
                    ? AppColors.signal
                    : AppColors.textV2Tertiary,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceV2Elevated,
            backgroundImage: entry.photoURL != null
                ? CachedNetworkImageProvider(entry.photoURL!)
                : null,
            child: entry.photoURL == null
                ? Text(
                    entry.displayName.isNotEmpty
                        ? entry.displayName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.h5.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 14,
                    color: entry.isCurrentUser
                        ? AppColors.signal
                        : AppColors.textV2Primary,
                  ),
                ),
                Text(
                  '${entry.streak} streak',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.score} pts',
            style: AppTextStyles.h5.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Global upsell ─────────────────────────────────────────────────────────────

class _GlobalUpsell extends StatelessWidget {
  const _GlobalUpsell();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surfaceV2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.signal.withValues(alpha: 0.30),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.signal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.public_rounded,
                  size: 32,
                  color: AppColors.signal,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Global Leaderboard',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Global rankings are paused while we move scoring to the server. Check back soon.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.signal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Coming soon',
                  style: AppTextStyles.h5.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Find tab — search results ─────────────────────────────────────────────────

class SocialSearchResults extends ConsumerWidget {
  final String query;
  final Set<String> followedIds;
  final void Function(String) onFollow;
  final String? currentUserId;

  const SocialSearchResults({
    super.key,
    required this.query,
    required this.followedIds,
    required this.onFollow,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(userSearchProvider(query));

    return resultsAsync.when(
      data: (users) {
        final filtered = users.where((u) => u.id != currentUserId).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No athletes found',
              style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => _UserSearchRow(
            user: filtered[i],
            isFollowed: followedIds.contains(filtered[i].id),
            currentUserId: currentUserId,
            onFollow: () => onFollow(filtered[i].id),
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: AppColors.signal,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'Search failed',
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
        ),
      ),
    );
  }
}

class _UserSearchRow extends ConsumerWidget {
  final User user;
  final bool isFollowed;
  final String? currentUserId;
  final VoidCallback onFollow;

  const _UserSearchRow({
    required this.user,
    required this.isFollowed,
    this.currentUserId,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticManager.light();
        context.push('/user/${user.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceV2Elevated,
              ),
              child: ClipOval(
                child: user.photoURL != null
                    ? CachedNetworkImage(
                        imageUrl: user.photoURL!,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.h5.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: 14,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.username != null
                        ? '@${user.username}'
                        : '${user.totalWorkouts} workouts',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textV2Secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isFollowed)
              GestureDetector(
                onTap: () async {
                  if (currentUserId == null) return;
                  unawaited(HapticManager.light());
                  onFollow();
                  await ref.read(followServiceProvider).followUser(
                    followerId: currentUserId!,
                    followeeId: user.id,
                    isPrivate: user.isPrivate,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.signal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Follow',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2,
                  border: Border.all(color: AppColors.surfaceV2Active),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Following',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
