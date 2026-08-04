import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/follow_service.dart';
import '../../../widgets/widgets.dart';

enum ConnectionsListKind {
  followers,
  following;

  String get title {
    switch (this) {
      case ConnectionsListKind.followers:
        return 'Followers';
      case ConnectionsListKind.following:
        return 'Following';
    }
  }
}



class ConnectionsListPage extends ConsumerStatefulWidget {
  const ConnectionsListPage({
    super.key,
    required this.userId,
    required this.kind,
  });

  final String userId;
  final ConnectionsListKind kind;

  @override
  ConsumerState<ConnectionsListPage> createState() =>
      _ConnectionsListPageState();
}

/// Pages the list instead of reading it whole.
///
/// The underlying query used to be unbounded, so opening this screen on a
/// popular account read every follow edge that account had. Paging state lives
/// here rather than in a provider because it is screen-local: leaving the
/// screen should drop it.
class _ConnectionsListPageState extends ConsumerState<ConnectionsListPage> {
  final _scrollController = ScrollController();
  final _users = <User>[];

  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _loadedFirstPage = false;
  Object? _error;

  ConnectionsListKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Fetches the next page once the user is within a screen of the end, so the
  /// list keeps moving rather than stalling at the boundary.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    // Guarded so a burst of scroll events cannot queue duplicate reads.
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final followService = ref.read(followServiceProvider);
      final page = switch (widget.kind) {
        ConnectionsListKind.followers =>
          await followService.getFollowersPage(widget.userId, startAfter: _cursor),
        ConnectionsListKind.following =>
          await followService.getFollowingPage(widget.userId, startAfter: _cursor),
      };

      if (!mounted) return;
      setState(() {
        _users.addAll(page.users);
        _cursor = page.cursor ?? _cursor;
        _hasMore = page.hasMore;
        _error = null;
      });
    } catch (e) {
      // Whatever loaded already stays on screen; only the first page failing
      // leaves nothing to show.
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadedFirstPage = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textV2Primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  kind.title,
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_loadedFirstPage) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.userAccent,
          semanticsLabel: 'Loading ${kind.title.toLowerCase()}',
        ),
      );
    }

    if (_error != null && _users.isEmpty) {
      return AppErrorState(
        title: 'Unable to load ${kind.title.toLowerCase()}',
        onRetry: () {
          setState(() {
            _error = null;
            _hasMore = true;
          });
          _loadNextPage();
        },
      );
    }

    if (_users.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline,
        title: 'No ${kind.title.toLowerCase()} yet',
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      // One extra row carries the tail spinner while the next page loads.
      itemCount: _users.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _users.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading more people',
              ),
            ),
          );
        }

        final user = _users[index];
        return ListTile(
          tileColor: AppColors.surfaceV2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.surfaceV2Elevated,
            child: Text(
              user.displayName.isEmpty
                  ? '?'
                  : user.displayName[0].toUpperCase(),
              style: const TextStyle(color: AppColors.textV2Primary),
            ),
          ),
          title: Text(
            user.displayName,
            style: const TextStyle(color: AppColors.textV2Primary),
          ),
          subtitle: Text(
            user.workoutPreference.displayName,
            style: const TextStyle(color: AppColors.textV2Secondary),
          ),
          onTap: () => context.push('/user/${user.id}'),
        );
      },
    );
  }
}
