import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/constants.dart';
import '../../../services/session_service.dart';
import '../../../services/post_service.dart';
import '../../../services/media_service.dart';
import '../../auth/auth_providers.dart';
import '../../../utils/haptic_manager.dart';
import '../../../utils/offline_manager.dart';
import '../../../widgets/celebration_overlay.dart';
import 'recap_launch_extras.dart';
import 'widgets/joint_post_composer.dart';
import 'widgets/recap_widgets.dart';

// ────────────────────────────────────────────────────────────────────────────
// Recap page – v2 design
// ────────────────────────────────────────────────────────────────────────────

class RecapPage extends ConsumerStatefulWidget {
  final String sessionId;

  const RecapPage({super.key, required this.sessionId});

  @override
  ConsumerState<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends ConsumerState<RecapPage> {
  Session? _session;
  bool _isLoading = true;
  bool _isSharing = false;
  bool _isPickingPhoto = false;
  String? _selectedPhotoPath;
  bool _shareWithFriendsOnly = true;
  double? _uploadProgress;
  String? _createdPostId;
  bool _shareCardExpanded = false;
  final bool _postedToFeed = false;
  bool _privateSaveDone = false;

  // Joint-post (two-human paired session) section.
  String? _jointDraftPostId;
  bool _isCreatingJointDraft = false;
  String? _jointDraftError;
  // Terminal joint-draft state (Part A's JointDraftUnavailableException):
  // this session's joint post is already decided — 'published' or 'expired'.
  // Distinct from [_jointDraftError], which is a recoverable failure with a
  // Retry action.
  String? _jointDraftTerminalStatus;
  String? _jointDraftTerminalPostId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await ref
          .read(sessionServiceProvider)
          .getSession(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
        _maybeShowPrCelebration();
        if (_isTwoHumanPairedSession) {
          // Joint sessions never fall back to a solo private post — the
          // shared draft (created below) is the only post that can result.
          _privateSaveDone = true;
          unawaited(_ensureJointDraft());
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fires once when the user just set one or more PRs (Z-ENH-007).
  void _maybeShowPrCelebration() {
    final extras = RecapLaunchExtras.take();
    if (extras == null || !extras.hasNewPrs || !mounted) return;

    final names = [
      ...extras.newStrengthPrNames.map(_titleCasePr),
      ...extras.newCardioPrNames.map(_titleCasePr),
    ];
    final subtitle = names.length == 1
        ? names.first
        : '${names.length} new personal records';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticManager.heavy();
      unawaited(
        showCelebration(
          context,
          title: 'New PR!',
          subtitle: subtitle,
          emoji: '🏆',
        ),
      );
    });
  }

  String _titleCasePr(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split(RegExp(r'[\s_]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  /// Two-human paired session (not bot/solo) → joint post composer.
  bool get _isTwoHumanPairedSession {
    final session = _session;
    if (session == null) return false;
    return session.participants.length == 2 &&
        !session.participants.contains(pairedBotFriendId);
  }

  /// Creates (or reuses, idempotently) the joint draft post for a two-human
  Future<void> _ensureJointDraft() async {
    if (_jointDraftPostId != null ||
        _isCreatingJointDraft ||
        _jointDraftTerminalStatus != null ||
        _session == null) {
      return;
    }
    _isCreatingJointDraft = true;
    final session = _session!;
    final summary = session.summary ?? SessionSummary();
    try {
      final postService = ref.read(postServiceProvider);
      final postId = await postService.createJointDraft(
        sessionId: widget.sessionId,
        type: session.type,
        title: session.title,
        authorIds: session.participants,
        summaries: {for (final uid in session.participants) uid: summary},
      );
      _isCreatingJointDraft = false;
      _applyJointState(() {
        _jointDraftPostId = postId;
        _jointDraftError = null;
      });
    } on JointDraftUnavailableException catch (e) {
      _isCreatingJointDraft = false;
      // Terminal, NOT retryable: this session's joint post already published
      // or expired, so there is no live draft to compose against. Retrying
      // would just throw again.
      _applyJointState(() {
        _jointDraftTerminalStatus = e.status;
        _jointDraftTerminalPostId = e.postId;
        _jointDraftError = null;
      });
    } catch (e) {
      _isCreatingJointDraft = false;
      // Recoverable: surface an error with a retry action rather than
      // stranding the user on an indefinite spinner.
      _applyJointState(
        () => _jointDraftError = 'Could not start your joint post.',
      );
    }
  }

  /// Applies a joint-draft state mutation through `setState` when this page is
  void _applyJointState(VoidCallback mutate) {
    if (mounted) {
      setState(mutate);
    } else {
      mutate();
    }
  }

  /// Clears the last joint-draft error and retries creation.
  void _retryJointDraft() {
    setState(() => _jointDraftError = null);
    unawaited(_ensureJointDraft());
  }

  /// Persist the workout as a private post (visible only to the owner, shown
  void _savePrivatelyIfNeeded() {
    if (_createdPostId != null || _privateSaveDone || _session == null) return;
    if (_isTwoHumanPairedSession) {
      // A joint session must never also create a solo private post.
      _privateSaveDone = true;
      return;
    }
    _privateSaveDone = true;
    final uid = ref.read(authSessionProvider).value?.id;
    if (uid == null) return;
    final postService = ref.read(postServiceProvider);
    final session = _session!;
    unawaited(
      postService.createPost(
        CreatePostParams(
          authorId: uid,
          sessionId: widget.sessionId,
          visibility: 'private',
          title: session.title,
          type: session.type,
          summary: session.summary ?? SessionSummary(),
        ),
      ),
    );
  }

  void _goHome() {
    HapticManager.light();
    _savePrivatelyIfNeeded();
    // context.go: session complete, clear stack so back doesn't return to recap
    if (mounted) context.go('/?tab=feed');
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return 'N/A';
    final d = end.difference(start);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  int _calcPoints(int totalSets) => 10 + (totalSets * 3).clamp(0, 60);

  // ── photo helpers ─────────────────────────────────────────────────────────

  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceV2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textV2Tertiary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Text(
                'Add Photo',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.signal),
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
                leading: Icon(Icons.photo_library, color: AppColors.signal),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              const SnackBar(
                content: Text('Image is too large (max 5 MB).'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        setState(() => _selectedPhotoPath = file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('permission')
                  ? 'Permission denied. Enable access in settings.'
                  : 'Failed to pick photo.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _removePhoto() => setState(() => _selectedPhotoPath = null);

  // ── share / post ──────────────────────────────────────────────────────────

  Future<void> _handleShare() async {
    if (_session == null || _isTwoHumanPairedSession) return;

    final uid = ref.read(authSessionProvider).value?.id;
    if (uid == null) return;

    // When offline, queue the share so it fires once connectivity returns.
    final offlineManager = ref.read(offlineManagerProvider);
    if (!offlineManager.isOnline) {
      _privateSaveDone = true; // prevent the private-save fallback
      final summary = _session!.summary ?? SessionSummary();
      offlineManager.queueOperation('post_create', {
        'authorId': uid,
        'sessionId': widget.sessionId,
        'visibility': _shareWithFriendsOnly ? 'friends' : 'public',
        'title': _session!.title,
        'type': _session!.type,
        'summary': summary.toMap(),
        'photoUri': null,
        'buddyId': null,
        'buddyName': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "You're offline. Your workout will be shared when you reconnect.",
            ),
            backgroundColor: AppColors.surfaceV2Elevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.go('/?tab=feed');
      }
      return;
    }

    setState(() {
      _isSharing = true;
      _uploadProgress = _selectedPhotoPath != null ? 0.0 : null;
    });
    try {
      final postService = ref.read(postServiceProvider);
      final postId = await postService.createPost(
        CreatePostParams(
          authorId: uid,
          sessionId: widget.sessionId,
          visibility: _shareWithFriendsOnly ? 'friends' : 'public',
          title: _session!.title,
          type: _session!.type,
          summary: _session!.summary ?? SessionSummary(),
          photoUri: _selectedPhotoPath,
        ),
        onProgress: _selectedPhotoPath != null
            ? (p) {
                if (mounted) setState(() => _uploadProgress = p);
              }
            : null,
      );
      _createdPostId = postId;
      if (mounted) {
        // context.go: post shared, session complete — clear stack
        context.go('/?tab=feed');
      }
    } catch (e) {
      if (mounted) {
        if (_createdPostId != null && _selectedPhotoPath != null) {
          _showPhotoUploadRetryDialog(e.toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getErrorMessage(e)),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isSharing = false;
          _uploadProgress = null;
        });
      }
    }
  }

  String _getErrorMessage(dynamic e) {
    final s = e.toString().toLowerCase();
    if (s.contains('network') || s.contains('connection')) {
      return 'Network connection lost. Please try again.';
    } else if (s.contains('permission')) {
      return 'Storage permission denied.';
    } else if (s.contains('size') || s.contains('5mb')) {
      return 'Photo exceeds 5 MB limit.';
    } else if (s.contains('format') || s.contains('invalid')) {
      return 'Invalid file format. Only JPG and PNG are supported.';
    }
    return 'Error sharing: $e';
  }

  void _showPhotoUploadRetryDialog(String err) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceV2,
        title: Text(
          'Photo Upload Failed',
          style: AppTextStyles.h5.copyWith(color: AppColors.textV2Primary),
        ),
        content: Text(
          'Your post was created, but the photo could not be uploaded.\n\n'
          '${_getErrorMessage(err)}\n\n'
          'Retry the upload or continue without the photo?',
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctx.pop();
              // context.go: user chose to skip photo, session complete — clear stack
              context.go('/?tab=feed');
            },
            child: const Text('Continue Without Photo'),
          ),
          ElevatedButton(
            onPressed: () {
              ctx.pop();
              _retryPhotoUpload();
            },
            child: const Text('Retry Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryPhotoUpload() async {
    if (_createdPostId == null || _selectedPhotoPath == null) return;
    setState(() {
      _isSharing = true;
      _uploadProgress = 0.0;
    });
    try {
      final mediaService = ref.read(mediaServiceProvider);
      final postService = ref.read(postServiceProvider);
      final photoUrl = await mediaService.uploadPostPhoto(
        filePath: _selectedPhotoPath!,
        postId: _createdPostId!,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = 0.1 + p * 0.8);
        },
      );
      if (mounted) setState(() => _uploadProgress = 0.9);
      await postService.updatePostPhoto(_createdPostId!, photoUrl);
      if (mounted) {
        // context.go: photo uploaded, session complete — clear stack
        context.go('/?tab=feed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _uploadProgress = null;
        });
        _showPhotoUploadRetryDialog(e.toString());
      }
    }
  }

  // ── joint composer section ────────────────────────────────────────────────

  /// Task 13: the paired-session posting UI, rendered *inside* recap's
  Widget _buildJointComposerSection() {
    final terminalStatus = _jointDraftTerminalStatus;
    if (terminalStatus != null) {
      return _buildJointTerminalCard(terminalStatus);
    }

    final draftId = _jointDraftPostId;
    if (draftId != null) {
      return JointPostComposer(postId: draftId);
    }

    if (_jointDraftError != null) {
      return Column(
        children: [
          Text(
            _jointDraftError!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textV2Secondary,
            ),
          ),
          const SizedBox(height: 16),
          RecapGhostButton(label: 'Retry', onTap: _retryJointDraft),
        ],
      );
    }

    // Draft creation is in flight.
    return SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator(color: AppColors.signal)),
    );
  }

  /// Terminal state for a session whose joint post is already decided —
  Widget _buildJointTerminalCard(String status) {
    final isPublished = status == 'published';
    final message = isPublished
        ? 'You already posted this session together'
        : 'This joint post expired';
    final actionLabel = isPublished ? 'View post' : 'See options';
    final postId = _jointDraftTerminalPostId;

    return Container(
      key: const ValueKey('joint_draft_terminal_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textV2Secondary,
            ),
          ),
          if (postId != null) ...[
            const SizedBox(height: 16),
            RecapGhostButton(
              label: actionLabel,
              onTap: () => context.push('/post/$postId'),
            ),
          ],
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(child: CircularProgressIndicator(color: AppColors.signal)),
      );
    }

    if (_session == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Session not found',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Secondary,
                ),
              ),
              const SizedBox(height: 24),
              RecapGhostButton(label: 'Back to Home', onTap: _goHome),
            ],
          ),
        ),
      );
    }

    final session = _session!;
    final summary = session.summary;
    final workoutType = WorkoutType.fromString(session.type);

    String durationStr;
    if (workoutType.isCardio &&
        summary?.duration != null &&
        summary!.duration!.isNotEmpty) {
      durationStr = summary.duration!;
    } else {
      durationStr = _formatDuration(session.startedAt, session.endedAt);
    }

    final totalSets = summary?.totalSets ?? 0;
    final totalExercises = summary?.totalExercises ?? 0;
    final totalVolume = summary?.totalVolume ?? 0.0;
    final points = _calcPoints(totalSets);
    final exercises = summary?.exercises ?? [];

    final authUser = ref.watch(authSessionProvider).value;
    final username = authUser?.displayName ?? 'you';
    final yourWorkoutType = authUser != null
        ? session.participantTypes[authUser.id] ?? session.type
        : session.type;
    final yourWorkoutTypeLabel = WorkoutType.fromString(
      yourWorkoutType,
    ).displayName;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Recap is terminal: leaving without sharing saves the workout privately
        // and returns home rather than popping into the finished session.
        _goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: SafeArea(
          child: Column(
            children: [
              // ── close button header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: _goHome,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceV2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textV2Secondary,
                    ),
                  ),
                ),
              ),
              // ── scrollable body ────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),

                      // ── hero section ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RecapDoneHeader(),
                            const SizedBox(height: 10),
                            // T024: offline banner — shown when device has no network.
                            Builder(
                              builder: (ctx) {
                                final isOnline =
                                    ref.watch(connectivityProvider).value ??
                                    true;
                                if (isOnline) return const SizedBox.shrink();
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceV2,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.textV2Secondary
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cloud_off_outlined,
                                        size: 16,
                                        color: AppColors.textV2Secondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Saved locally — your workout will post when you\'re back online',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textV2Secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Row(
                              children: [
                                Text(
                                  durationStr,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 13,
                                    color: AppColors.textV2Secondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: AppColors.textV2Tertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Points badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceV2,
                                    border: Border.all(
                                      color: AppColors.signal.withValues(
                                        alpha: 0.13,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt,
                                        size: 14,
                                        color: AppColors.signal,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '+$points',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: AppColors.signal,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'pts',
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 11,
                                          color: AppColors.textV2Tertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── stats 2×2 grid ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: RecapStatCell(
                                    value: '$totalExercises',
                                    label: 'Exercises',
                                    accentColor: AppColors.signal,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RecapStatCell(
                                    value: '$totalSets',
                                    label: 'Sets',
                                    accentColor: AppColors.accentSky,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: RecapStatCell(
                                    value: durationStr,
                                    label: 'Duration',
                                    accentColor: AppColors.warnV2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RecapStatCell(
                                    value: totalVolume > 0
                                        ? '${totalVolume.toStringAsFixed(1)} kg'
                                        : '—',
                                    label: 'Volume',
                                    accentColor: AppColors.errorV2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── breakdown section ───────────────────────────────────
                      if (session.participantTypes.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceV2,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.signal.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  color: AppColors.signal,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Personal workout history',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: AppColors.textV2Primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Your workout type: $yourWorkoutTypeLabel',
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 13,
                                          color: AppColors.textV2Secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (exercises.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: RecapBreakdownSection(exercises: exercises),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── share card (collapsible) ────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: RecapShareCardSection(
                          expanded: _shareCardExpanded,
                          onToggle: () => setState(
                            () => _shareCardExpanded = !_shareCardExpanded,
                          ),
                          session: session,
                          durationStr: durationStr,
                          totalExercises: totalExercises,
                          totalSets: totalSets,
                          totalVolume: totalVolume,
                          points: points,
                          username: username,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── post section ────────────────────────────────────────
                      // Task 13: everyone sees the stats/breakdown above; only
                      // the posting UI differs. A two-human paired session posts
                      // through the embedded joint composer (its own Post button,
                      // photo picker and visibility toggle), so the solo
                      // "Post to feed" card — whose _handleShare is a no-op for
                      // joint sessions — is swapped out rather than stacked on
                      // top of it.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _isTwoHumanPairedSession
                            ? _buildJointComposerSection()
                            : RecapPostToFeedSection(
                                postedToFeed: _postedToFeed,
                                selectedPhotoPath: _selectedPhotoPath,
                                isPickingPhoto: _isPickingPhoto,
                                isSharing: _isSharing,
                                shareWithFriendsOnly: _shareWithFriendsOnly,
                                uploadProgress: _uploadProgress,
                                onPhotoTap: _showPhotoSourceDialog,
                                onRemovePhoto: _removePhoto,
                                onToggleFriendsOnly: (v) =>
                                    setState(() => _shareWithFriendsOnly = v),
                                onShare: _handleShare,
                              ),
                      ),

                      const SizedBox(height: 16),

                      // ── back to home ghost button ───────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: RecapGhostButton(
                          label: 'Back to Home',
                          onTap: _goHome,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
