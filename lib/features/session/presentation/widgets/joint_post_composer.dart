import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/media_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/post_service.dart';
import '../../../../services/user_cache_service.dart';
import '../../../../widgets/fluttermoji_avatar.dart';
import '../../../auth/auth_providers.dart';

/// Post-session screen where two workout partners assemble ONE shared post
/// side by side. Each partner picks their own photo, writes their own
/// caption, and chooses their own public/private visibility; the post only
/// goes live once BOTH have tapped Post. The draft -> published flip itself
/// is a Cloud Function's job (triggered once both `authors.*.confirmed` are
/// true) — this widget just streams the draft and routes out once it
/// observes `status == 'published'`.
///
/// There is no mic/voice button here — this is a post-session screen.
class JointPostComposer extends ConsumerStatefulWidget {
  final String postId;

  const JointPostComposer({super.key, required this.postId});

  @override
  ConsumerState<JointPostComposer> createState() => _JointPostComposerState();
}

class _JointPostComposerState extends ConsumerState<JointPostComposer> {
  late final Stream<Post> _draftStream;
  final TextEditingController _captionController = TextEditingController();

  String? _localPhotoPath;
  String _visibility = 'public';
  bool _isPickingPhoto = false;
  bool _isPosting = false;
  bool _hasConfirmedLocally = false;
  bool _hasRouted = false;

  String? _partnerId;
  User? _partnerUser;
  User? _selfUser;
  bool _partnerFetchStarted = false;
  bool _selfFetchStarted = false;

  @override
  void initState() {
    super.initState();
    _draftStream = ref
        .read(postServiceProvider)
        .watchJointDraft(widget.postId);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  String get _currentUserId =>
      ref.read(authSessionProvider).value?.id ?? '';

  void _ensurePartnerAndSelfLoaded(Post post) {
    final uid = _currentUserId;

    if (!_selfFetchStarted && uid.isNotEmpty) {
      _selfFetchStarted = true;
      final cache = ref.read(userCacheServiceProvider);
      _selfUser = cache.getUserSync(uid);
      cache.getUser(uid).then((user) {
        if (mounted && user != null) setState(() => _selfUser = user);
      });
    }

    final partnerId = post.authorIds.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );
    if (partnerId.isEmpty) return;
    _partnerId = partnerId;

    if (!_partnerFetchStarted) {
      _partnerFetchStarted = true;
      final cache = ref.read(userCacheServiceProvider);
      _partnerUser = cache.getUserSync(partnerId);
      cache.getUser(partnerId).then((user) {
        if (mounted && user != null) setState(() => _partnerUser = user);
      });
    }
  }

  Future<void> _pickPhoto({required bool fromCamera}) async {
    if (_isPickingPhoto) return;
    setState(() => _isPickingPhoto = true);
    try {
      final mediaService = ref.read(mediaServiceProvider);
      final file = await mediaService.pickImage(fromCamera: fromCamera);
      if (file != null && mounted) {
        final size = await file.length();
        if (size > MediaService.maxPhotoSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image is too large (max 5 MB).')),
            );
          }
          return;
        }
        setState(() => _localPhotoPath = file.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceV2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.userAccent),
              title: Text(
                'Take Photo',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Primary,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(fromCamera: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.userAccent),
              title: Text(
                'Choose from Gallery',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Primary,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(fromCamera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePost(Post post) async {
    final uid = _currentUserId;
    if (uid.isEmpty || _isPosting || _hasConfirmedLocally) return;

    setState(() => _isPosting = true);
    try {
      final postService = ref.read(postServiceProvider);

      String? photoUrl;
      if (_localPhotoPath != null) {
        final mediaService = ref.read(mediaServiceProvider);
        photoUrl = await mediaService.uploadPostPhoto(
          filePath: _localPhotoPath!,
          postId: widget.postId,
        );
      }

      final caption = _captionController.text.trim();
      await postService.setAuthorSlot(
        postId: widget.postId,
        userId: uid,
        caption: caption.isEmpty ? null : caption,
        photoUrl: photoUrl,
        visibility: _visibility,
      );

      await postService.confirmJointPost(postId: widget.postId, userId: uid);

      // The confirm already succeeded — lock the UI in now so a partner-invite
      // failure below can never make the Post button re-enable and re-fire
      // (which would re-upload the photo and re-send the invite).
      if (mounted) setState(() => _hasConfirmedLocally = true);

      final partnerId = _partnerId;
      final partnerAlreadyConfirmed =
          partnerId != null && (post.authors[partnerId]?.confirmed ?? false);
      if (partnerId != null && !partnerAlreadyConfirmed) {
        try {
          final fromName = _selfUser?.displayName ??
              ref.read(authSessionProvider).value?.displayName ??
              'Your buddy';
          await ref.read(notificationServiceProvider).sendJointPostInvite(
                recipientId: partnerId,
                fromName: fromName,
                postId: widget.postId,
                sessionId: post.sessionId,
              );
        } catch (_) {
          // Best-effort nudge only — the post itself already confirmed
          // successfully, so an invite failure must not surface as an error
          // or roll back the confirmed state.
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _routeToFeedIfPublished(Post post) {
    if (_hasRouted || post.status != 'published') return;
    _hasRouted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Grab the app-level messenger BEFORE navigating; showing the snackbar
      // after go() lets it land on the destination (feed) scaffold instead of
      // being discarded when this composer's route unmounts.
      final messenger = ScaffoldMessenger.of(context);
      context.go('/?tab=feed');
      messenger.showSnackBar(
        const SnackBar(content: Text('Posted together')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: StreamBuilder<Post>(
          stream: _draftStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.userAccent),
              );
            }
            final post = snapshot.data!;
            _ensurePartnerAndSelfLoaded(post);
            _routeToFeedIfPublished(post);

            final uid = _currentUserId;
            final selfSlot = post.authors[uid];
            final partnerSlot =
                _partnerId != null ? post.authors[_partnerId] : null;
            if (selfSlot?.confirmed == true) {
              _hasConfirmedLocally = true;
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 480;
                        final selfCard = _buildSelfSlot(post, selfSlot);
                        final partnerCard = _buildPartnerSlot(partnerSlot);
                        if (isNarrow) {
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                selfCard,
                                const SizedBox(height: 16),
                                partnerCard,
                              ],
                            ),
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: selfCard),
                            const SizedBox(width: 16),
                            Expanded(child: partnerCard),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final partnerFirstName =
        (_partnerUser?.displayName ?? '').trim().split(' ').first;
    final title = partnerFirstName.isEmpty
        ? 'You with your buddy'
        : 'You with $partnerFirstName';

    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 40,
          child: Stack(
            children: [
              FluttermojiAvatar(
                photoUrl: _selfUser?.photoURL,
                displayName: _selfUser?.displayName ?? 'You',
                size: 40,
                showGradientBorder: false,
              ),
              Positioned(
                left: 24,
                child: FluttermojiAvatar(
                  photoUrl: _partnerUser?.photoURL,
                  displayName: _partnerUser?.displayName ?? '?',
                  size: 40,
                  showGradientBorder: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textV2Primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelfSlot(Post post, PostAuthorSlot? slot) {
    final confirmed = slot?.confirmed == true || _hasConfirmedLocally;
    final fallbackPhotoUrl = slot?.photoUrl ?? _selfUser?.photoURL;
    final hasNetworkPhoto = _localPhotoPath == null &&
        fallbackPhotoUrl != null &&
        fallbackPhotoUrl.isNotEmpty;

    return Container(
      key: const ValueKey('joint_post_self_slot'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textV2Secondary,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: confirmed || _isPosting ? null : _showPhotoSourceSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surfaceV2Elevated,
                image: _localPhotoPath != null
                    ? DecorationImage(
                        image: FileImage(File(_localPhotoPath!)),
                        fit: BoxFit.cover,
                      )
                    : hasNetworkPhoto
                        ? DecorationImage(
                            image: NetworkImage(fallbackPhotoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: (_localPhotoPath == null && !hasNetworkPhoto)
                  ? Center(
                      child: _isPickingPhoto
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.userAccent,
                              ),
                            )
                          : Icon(
                              Icons.add_a_photo,
                              color: AppColors.textV2Tertiary,
                            ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('joint_post_caption_field'),
            controller: _captionController,
            enabled: !confirmed && !_isPosting,
            maxLines: 2,
            style: AppTextStyles.body.copyWith(color: AppColors.textV2Primary),
            decoration: InputDecoration(
              hintText: 'Add a caption…',
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textV2Tertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceV2Elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _visibility == 'public' ? 'Public' : 'Private',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textV2Secondary,
                ),
              ),
              Switch(
                value: _visibility == 'public',
                onChanged: confirmed || _isPosting
                    ? null
                    : (v) => setState(
                          () => _visibility = v ? 'public' : 'private',
                        ),
                activeThumbColor: AppColors.userAccent,
                inactiveTrackColor: AppColors.surfaceV2Active,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('joint_post_post_button'),
              onPressed:
                  confirmed || _isPosting ? null : () => _handlePost(post),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.userAccent,
                foregroundColor: AppColors.backgroundV2,
              ),
              child: _isPosting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.backgroundV2,
                      ),
                    )
                  : Text(confirmed ? 'Posted ✓' : 'Post'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerSlot(PostAuthorSlot? slot) {
    final photoUrl = slot?.photoUrl ?? _partnerUser?.photoURL;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final caption = slot?.caption;
    final statusLabel = _partnerStatusLabel(slot);

    return Container(
      key: const ValueKey('joint_post_partner_slot'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _partnerUser?.displayName ?? 'Partner',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textV2Secondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surfaceV2Elevated,
            ),
            child: hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => _partnerAvatarFallback(),
                    ),
                  )
                : _partnerAvatarFallback(),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2Elevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              (caption == null || caption.isEmpty)
                  ? 'No caption yet'
                  : caption,
              style: AppTextStyles.body.copyWith(
                color: caption == null || caption.isEmpty
                    ? AppColors.textV2Tertiary
                    : AppColors.textV2Primary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            statusLabel,
            style: AppTextStyles.caption.copyWith(
              color: statusLabel == 'posted ✓'
                  ? AppColors.userAccent
                  : AppColors.textV2Secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerAvatarFallback() {
    return Center(
      child: FluttermojiAvatar(
        photoUrl: _partnerUser?.photoURL,
        displayName: _partnerUser?.displayName ?? '?',
        size: 56,
        showGradientBorder: false,
      ),
    );
  }

  String _partnerStatusLabel(PostAuthorSlot? slot) {
    if (slot == null) return 'waiting…';
    if (slot.confirmed) return 'posted ✓';
    final hasCaption = slot.caption != null && slot.caption!.isNotEmpty;
    final hasPhoto = slot.photoUrl != null && slot.photoUrl!.isNotEmpty;
    return (hasCaption || hasPhoto) ? 'ready' : 'waiting…';
  }
}
