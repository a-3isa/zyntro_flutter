import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_providers.dart';
import '../../../services/facebook_link_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/user_service.dart';
import '../../../services/user_cache_service.dart';
import '../../../utils/haptic_manager.dart';
import 'providers/facebook_friends_provider.dart';
import 'widgets/social_buddy_widgets.dart';
import 'widgets/social_board_widgets.dart';
import 'widgets/social_find_widgets.dart';

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
                    tabs: [
                      Tab(text: AppLocalizations.of(context).socialTabBoard),
                      Tab(text: AppLocalizations.of(context).socialTabBuddies),
                      Tab(text: AppLocalizations.of(context).socialTabFind),
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
    final userId = ref.watch(authCurrentUserIdProvider) ?? '';
    return SocialBoardContent(userId: userId);
  }

  // ── Buddies tab ────────────────────────────────────────────────────────────

  Widget _buildBuddiesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        unawaited(HapticManager.medium());
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
            ...List.generate(5, (_) => const SocialBuddySkeleton())
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
            ..._buddies.map((b) => SocialBuddyRow(buddy: b)),
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

  // ── Find tab ───────────────────────────────────────────────────────────────

  Widget _buildFindTab() {
    final profile = ref.watch(authUserProfileProvider).value;
    final isFbConnected = profile?.isFacebookConnected ?? false;

    return Column(
      children: [
        // Facebook connect banner (shown when not connected and not dismissed)
        if (!isFbConnected && !_fbBannerDismissed)
          SocialFacebookConnectBanner(
            onConnect: _connectFacebookFromFind,
            onDismiss: () => setState(() => _fbBannerDismissed = true),
          ),

        // People You May Know (shown when FB connected)
        if (isFbConnected)
          SocialPeopleYouMayKnow(
            followedIds: _followedInFind,
            onFollow: _followFacebookFriend,
          ),

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
              : SocialSearchResults(
                  query: _searchQuery,
                  followedIds: _followedInFind,
                  onFollow: (userId) =>
                      setState(() => _followedInFind.add(userId)),
                  currentUserId: ref.watch(authCurrentUserIdProvider),
                ),
        ),
      ],
    );
  }

  Future<void> _followFacebookFriend(String targetUserId) async {
    final currentUserId = ref.read(authCurrentUserIdProvider);
    if (currentUserId == null) return;

    final targetProfile = ref.read(facebookFriendsProvider).value
        ?.firstWhere((u) => u.id == targetUserId);
    if (targetProfile == null) return;

    setState(() => _followedInFind.add(targetUserId));

    final result = await ref.read(followServiceProvider).tryFollowUser(
      followerId: currentUserId,
      followeeId: targetUserId,
      isPrivate: targetProfile.isPrivate,
    );
    if (!mounted) return;
    result.when(
      success: (_) {},
      failure: (message) {
        setState(() => _followedInFind.remove(targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.surfaceV2Active,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
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

