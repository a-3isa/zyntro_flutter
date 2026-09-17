import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../services/facebook_link_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/leaderboard_service.dart';
import '../../../services/user_service.dart';
import '../../../services/user_cache_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../utils/image_cache_manager.dart';
import 'providers/facebook_friends_provider.dart';

/// Social page with Board, Buddies, and Find tabs.
class SocialPage extends ConsumerStatefulWidget {
  const SocialPage({
    super.key,
    this.initialTab = SocialTab.board,
  });

  final SocialTab initialTab;

  @override
  ConsumerState<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends ConsumerState<SocialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Buddies pagination
  final ScrollController _buddiesScrollController = ScrollController();
  List<BuddyWithPresence> _buddies = [];
  List<String> _allBuddyIds = [];
  bool _isLoadingMoreBuddies = false;
  bool _isInitialLoad = true;

  // Find tab
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _followedInFind = {};
  bool _fbBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _buddiesScrollController.addListener(_onBuddiesScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBuddies(refresh: true);
    });
  }

  @override
  void didUpdateWidget(covariant SocialPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab &&
        _tabController.index != widget.initialTab.index) {
      _tabController.animateTo(widget.initialTab.index);
    }
  }

  void _onBuddiesScroll() {
    if (_buddiesScrollController.position.pixels >=
            _buddiesScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMoreBuddies &&
        _buddies.length < _allBuddyIds.length) {
      _loadBuddies();
    }
  }

  Future<void> _loadBuddies({bool refresh = false}) async {
    if (_isLoadingMoreBuddies && !refresh) return;
    if (!mounted) return;

    setState(() => _isLoadingMoreBuddies = true);

    try {
      final authState = ref.read(authSessionProvider).value;
      if (authState == null) {
        if (mounted) {
          setState(() {
            _isLoadingMoreBuddies = false;
            _isInitialLoad = false;
            _buddies = [];
          });
        }
        return;
      }

      if (refresh) {
        final userService = ref.read(userServiceProvider);
        _allBuddyIds = await userService.computeAndCacheBuddies(authState.id);
        setState(() => _buddies.clear());
      }

      if (_buddies.length >= _allBuddyIds.length) {
        setState(() {
          _isLoadingMoreBuddies = false;
          _isInitialLoad = false;
        });
        return;
      }

      final startIndex = _buddies.length;
      final endIndex = (startIndex + 10 < _allBuddyIds.length)
          ? startIndex + 10
          : _allBuddyIds.length;
      final chunkIds = _allBuddyIds.sublist(startIndex, endIndex);

      final cacheService = ref.read(userCacheServiceProvider);
      final usersMap = await cacheService.fetchUsers(chunkIds);

      final newBuddies = chunkIds
          .map((id) {
            final user = usersMap[id];
            if (user == null) return null;
            final lastActive = user.lastActive;
            final isOnline =
                lastActive != null &&
                DateTime.now().difference(lastActive).inMinutes < 5;
            return BuddyWithPresence(
              id: user.id,
              displayName: user.displayName,
              photoURL: user.photoURL,
              isOnline: isOnline,
              lastActive: lastActive,
            );
          })
          .whereType<BuddyWithPresence>()
          .toList();

      if (mounted) {
        setState(() {
          _buddies.addAll(newBuddies);
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading buddies: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMoreBuddies = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buddiesScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 20,
              right: 20,
              bottom: 14,
            ),
            color: AppColors.backgroundV2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Social',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textV2Primary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.textV2Primary,
                    unselectedLabelColor: AppColors.textV2Secondary,
                    indicator: BoxDecoration(
                      color: AppColors.surfaceV2Active,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: AppTextStyles.label.copyWith(
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: AppTextStyles.body.copyWith(
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Board'),
                      Tab(text: 'Buddies'),
                      Tab(text: 'Find'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBoardTab(),
                _buildBuddiesTab(),
                _buildFindTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardTab() {
    final userId = ref.watch(authSessionProvider).value?.id ?? '';
    return _BoardContent(userId: userId);
  }

  // ── Buddies tab ────────────────────────────────────────────────────────────

  Widget _buildBuddiesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        HapticManager.medium();
        await _loadBuddies(refresh: true);
      },
      color: AppColors.signal,
      backgroundColor: AppColors.surfaceV2,
      child: ListView(
        controller: _buddiesScrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (_isInitialLoad)
            ...List.generate(5, (_) => _buildBuddySkeleton())
          else if (_buddies.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text(
                  'No buddies yet.\nSearch for people to follow!',
                  style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._buddies.map(_buildBuddyRow),
          if (_isLoadingMoreBuddies && !_isInitialLoad)
            Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.signal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuddyRow(BuddyWithPresence buddy) {
    return GestureDetector(
      onTap: () {
        HapticManager.light();
        context.push('/user/${buddy.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceV2Elevated,
                  ),
                  child: ClipOval(
                    child: buddy.photoURL != null
                        ? CachedNetworkImage(
                            imageUrl: buddy.photoURL!,
                            cacheManager: ZyntroImageCacheManager(),
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              buddy.displayName.isNotEmpty
                                  ? buddy.displayName[0].toUpperCase()
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
                if (buddy.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.backgroundV2,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buddy.displayName,
                    style: AppTextStyles.h5.copyWith(
                      fontSize: 15,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    buddy.isOnline ? 'Online now' : 'Offline',
                    style: AppTextStyles.caption.copyWith(
                      color: buddy.isOnline
                          ? AppColors.success
                          : AppColors.textV2Secondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticManager.light();
                context.push('/user/${buddy.id}');
              },
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuddySkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceV2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 110,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 70,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 82,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Find tab ───────────────────────────────────────────────────────────────

  Widget _buildFindTab() {
    final profile = ref.watch(authUserProfileProvider).value;
    final isFbConnected = profile?.isFacebookConnected ?? false;

    return Column(
      children: [
        // Facebook connect banner (shown when not connected and not dismissed)
        if (!isFbConnected && !_fbBannerDismissed)
          _buildFacebookConnectBanner(),

        // People You May Know (shown when FB connected)
        if (isFbConnected) _buildPeopleYouMayKnow(),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textV2Primary,
              ),
              decoration: InputDecoration(
                hintText: 'Find buddies by username…',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Tertiary,
                ),
                prefixIcon: const Icon(
                  Icons.alternate_email_rounded,
                  color: AppColors.textV2Tertiary,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (q) => setState(() => _searchQuery = q.trim()),
            ),
          ),
        ),
        Expanded(
          child: _searchQuery.isEmpty
              ? Center(
                  child: Text(
                    'Search by @username to add buddies',
                    style: AppTextStyles.body.copyWith(color: AppColors.textV2Tertiary),
                  ),
                )
              : _SearchResultsWidget(
                  query: _searchQuery,
                  followedIds: _followedInFind,
                  onFollow: (userId) =>
                      setState(() => _followedInFind.add(userId)),
                  currentUserId:
                      ref.watch(authSessionProvider).value?.id,
                ),
        ),
      ],
    );
  }

  Widget _buildFacebookConnectBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.brandFacebook.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brandFacebook.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_alt_outlined, color: AppColors.brandFacebook, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find friends from Facebook',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textV2Primary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Connect to see who\'s already on Zyntro',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textV2Secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _connectFacebookFromFind(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandFacebook,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Connect',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _fbBannerDismissed = true),
              child: const Icon(Icons.close, color: AppColors.textV2Tertiary, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleYouMayKnow() {
    final friendsAsync = ref.watch(facebookFriendsProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PEOPLE YOU MAY KNOW',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  fontSize: 10,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              const SizedBox(height: 8),
              ...friends.take(10).map((user) => _buildFriendRow(user)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  Widget _buildFriendRow(dynamic user) {
    final isFollowed = _followedInFind.contains(user.id as String);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surfaceV2Active,
          backgroundImage: (user.photoUrl as String?) != null
              ? CachedNetworkImageProvider(user.photoUrl as String)
              : null,
          child: (user.photoUrl as String?) == null
              ? Text(
                  (user.displayName as String).isNotEmpty
                      ? (user.displayName as String)[0].toUpperCase()
                      : '?',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.signal,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        title: Text(
          user.displayName as String,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textV2Primary,
            fontSize: 14,
          ),
        ),
        trailing: isFollowed
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2Active,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Following',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textV2Tertiary,
                  ),
                ),
              )
            : GestureDetector(
                onTap: () => _followFacebookFriend(user.id as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.signal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Follow',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.backgroundV2,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _followFacebookFriend(String targetUserId) async {
    final currentUserId = ref.read(authSessionProvider).value?.id;
    if (currentUserId == null) return;

    final targetProfile = ref.read(facebookFriendsProvider).value
        ?.firstWhere((u) => u.id == targetUserId);
    if (targetProfile == null) return;

    setState(() => _followedInFind.add(targetUserId));

    await ref.read(followServiceProvider).followUser(
      followerId: currentUserId,
      followeeId: targetUserId,
      isPrivate: targetProfile.isPrivate,
    );
  }

  Future<void> _connectFacebookFromFind() async {
    final uid = ref.read(authSessionProvider).value?.id;
    if (uid == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final fbService = ref.read(facebookLinkServiceProvider);
    final result = await fbService.connectFacebook(uid);

    if (!mounted) return;
    ref.invalidate(authUserProfileProvider);
    ref.invalidate(facebookFriendsProvider);

    String snack;
    switch (result) {
      case FacebookLinkSuccess(:final value):
        final count = value.length;
        snack = count > 0
            ? 'Facebook connected! Found $count friend${count == 1 ? '' : 's'} on Zyntro.'
            : 'Facebook connected.';
      case FacebookLinkNoFriendsPermission():
        snack = 'Facebook connected. Grant friend access to see friends.';
      case FacebookLinkCancelled():
        snack = 'Facebook connection cancelled.';
      case FacebookLinkFailure(:final message):
        messenger.showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: AppColors.surfaceV2Active,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        return;
    }

    messenger.showSnackBar(SnackBar(
      content: Text(snack),
      backgroundColor: AppColors.surfaceV2Active,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ── Board tab ─────────────────────────────────────────────────────────────────

class _BoardContent extends ConsumerStatefulWidget {
  final String userId;
  const _BoardContent({required this.userId});

  @override
  ConsumerState<_BoardContent> createState() => _BoardContentState();
}

class _BoardContentState extends ConsumerState<_BoardContent> {
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

class _SearchResultsWidget extends ConsumerWidget {
  final String query;
  final Set<String> followedIds;
  final void Function(String) onFollow;
  final String? currentUserId;

  const _SearchResultsWidget({
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
                  HapticManager.light();
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
