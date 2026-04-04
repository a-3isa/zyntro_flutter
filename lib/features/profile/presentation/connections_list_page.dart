import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/follow_service.dart';

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

final connectionsListProvider =
    FutureProvider.family<List<User>, ({String userId, ConnectionsListKind kind})>(
      (ref, params) {
        final followService = ref.read(followServiceProvider);
        switch (params.kind) {
          case ConnectionsListKind.followers:
            return followService.getFollowersList(params.userId);
          case ConnectionsListKind.following:
            return followService.getFollowingList(params.userId);
        }
      },
    );

class ConnectionsListPage extends ConsumerWidget {
  const ConnectionsListPage({
    super.key,
    required this.userId,
    required this.kind,
  });

  final String userId;
  final ConnectionsListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(
      connectionsListProvider((userId: userId, kind: kind)),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(kind.title),
        backgroundColor: AppColors.surfaceDark,
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load ${kind.title.toLowerCase()} right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No ${kind.title.toLowerCase()} yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondaryDark),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                tileColor: AppColors.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceSecondaryDark,
                  child: Text(
                    user.displayName.isEmpty
                        ? '?'
                        : user.displayName[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                ),
                title: Text(
                  user.displayName,
                  style: const TextStyle(color: AppColors.textDark),
                ),
                subtitle: Text(
                  user.workoutPreference.displayName,
                  style: const TextStyle(color: AppColors.textSecondaryDark),
                ),
                onTap: () => context.push('/user/${user.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
