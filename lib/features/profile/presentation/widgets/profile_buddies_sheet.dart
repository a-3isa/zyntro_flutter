import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/follow_service.dart';

/// Followers/buddies bottom sheet for a profile (Z-ARCH-002).
class ProfileBuddiesSheet extends ConsumerStatefulWidget {
  const ProfileBuddiesSheet({super.key, required this.targetUserId});

  final String targetUserId;

  @override
  ConsumerState<ProfileBuddiesSheet> createState() =>
      _ProfileBuddiesSheetState();
}

class _ProfileBuddiesSheetState extends ConsumerState<ProfileBuddiesSheet> {
  late Future<List<User>> _followersFuture;

  @override
  void initState() {
    super.initState();
    _followersFuture = ref
        .read(followServiceProvider)
        .getFollowersList(widget.targetUserId);
  }

  @override
  Widget build(BuildContext context) {
    final followersAsync = _followersFuture;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textV2Tertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Buddies',
            style: AppTextStyles.h5.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Primary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: followersAsync,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.signal,
                    ),
                  );
                }
                final users = snap.data ?? [];
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No buddies yet',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: users.length,
                  itemBuilder: (_, index) {
                    final u = users[index];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/user/${u.id}');
                      },
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceV2Elevated,
                        backgroundImage:
                            u.photoURL != null && u.photoURL!.isNotEmpty
                            ? CachedNetworkImageProvider(u.photoURL!)
                            : null,
                        child: u.photoURL == null || u.photoURL!.isEmpty
                            ? Text(
                                u.displayName.isNotEmpty
                                    ? u.displayName[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.textV2Primary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        u.displayName,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      subtitle: u.username != null && u.username!.isNotEmpty
                          ? Text(
                              '@${u.username}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textV2Tertiary,
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
