import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Persist the workout as a private post (visible only to the owner, shown
  /// with a lock badge in their profile) when they leave recap without sharing.
  /// Best-effort, fire-and-forget; the session itself is already saved.
  void _savePrivatelyIfNeeded() {
    if (_createdPostId != null || _privateSaveDone || _session == null) return;
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
                leading: Icon(
                  Icons.camera_alt,
                  color: AppColors.userAccent,
                ),
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
                leading: Icon(
                  Icons.photo_library,
                  color: AppColors.userAccent,
                ),
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
    if (_session == null) return;

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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.userAccent),
        ),
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
              _GhostButton(
                label: 'Back to Home',
                onTap: _goHome,
              ),
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
                child: GestureDetector(
                  onTap: _goHome,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textV2Secondary,
                    ),
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
                          _DoneHeader(),
                          const SizedBox(height: 10),
                          // T024: offline banner — shown when device has no network.
                          Builder(builder: (ctx) {
                            final isOnline = ref
                                .watch(connectivityProvider)
                                .value ?? true;
                            if (isOnline) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceV2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.textV2Secondary
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_off_outlined,
                                      size: 16,
                                      color: AppColors.textV2Secondary),
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
                          }),
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
                                    color: AppColors.userAccent.withValues(
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
                                      color: AppColors.userAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+$points',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        color: AppColors.userAccent,
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
                                child: _StatCell(
                                  value: '$totalExercises',
                                  label: 'Exercises',
                                  accentColor: AppColors.userAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCell(
                                  value: '$totalSets',
                                  label: 'Sets',
                                  accentColor: const Color(0xFF38BDF8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCell(
                                  value: durationStr,
                                  label: 'Duration',
                                  accentColor: const Color(0xFFFF8C00),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCell(
                                  value: totalVolume > 0
                                      ? '${totalVolume.toStringAsFixed(1)} kg'
                                      : '—',
                                  label: 'Volume',
                                  accentColor: const Color(0xFFFF4D4D),
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
                              color: AppColors.userAccent.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.userAccent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: _BreakdownSection(exercises: exercises),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── share card (collapsible) ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _ShareCardSection(
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

                    // ── post to feed section ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _PostToFeedSection(
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
                      child: _GhostButton(
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

// ────────────────────────────────────────────────────────────────────────────
// "Done." hero header
// ────────────────────────────────────────────────────────────────────────────

class _DoneHeader extends StatelessWidget {
  const _DoneHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Done.',
      style: AppTextStyles.display.copyWith(
        fontSize: 64,
        color: AppColors.textV2Primary,
        letterSpacing: -3,
        height: 0.9,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Stat cell
// ────────────────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;

  const _StatCell({
    required this.value,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.h1.copyWith(
              fontSize: 34,
              color: AppColors.textV2Primary,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 16,
                height: 2,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textV2Secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Breakdown section
// ────────────────────────────────────────────────────────────────────────────

class _BreakdownSection extends StatelessWidget {
  final List<ExerciseSummary> exercises;

  const _BreakdownSection({required this.exercises});

  String _fmtWeight(double w) =>
      w == w.truncateToDouble() ? '${w.toInt()}' : '$w';

  String _fmtDuration(int secs) {
    if (secs <= 0) return '';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BREAKDOWN',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Tertiary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          ...exercises.map((ex) {
            final hasDetail = ex.setDetails.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ex.name,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textV2Primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.userAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${ex.sets} ${ex.sets == 1 ? 'set' : 'sets'}',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.userAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Per-set rows
                  if (hasDetail) ...[
                    const SizedBox(height: 8),
                    ...ex.setDetails.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final dur = _fmtDuration(s.durationSeconds);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                '${i + 1}',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textV2Tertiary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.weight > 0
                                    ? '${_fmtWeight(s.weight)} kg × ${s.reps} reps'
                                    : '${s.reps} reps',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 13,
                                  color: AppColors.textV2Secondary,
                                ),
                              ),
                            ),
                            if (dur.isNotEmpty)
                              Text(
                                dur,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textV2Tertiary,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Share card section
// ────────────────────────────────────────────────────────────────────────────

class _ShareCardSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final Session session;
  final String durationStr;
  final int totalExercises;
  final int totalSets;
  final double totalVolume;
  final int points;
  final String username;

  const _ShareCardSection({
    required this.expanded,
    required this.onToggle,
    required this.session,
    required this.durationStr,
    required this.totalExercises,
    required this.totalSets,
    required this.totalVolume,
    required this.points,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle button
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: expanded
                  ? const BorderRadius.vertical(top: Radius.circular(20))
                  : BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text(
                  'SHARE CARD PREVIEW',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Tertiary,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textV2Secondary,
                ),
              ],
            ),
          ),
        ),
        // Preview card
        if (expanded)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF141414), Color(0xFF1A1A1A)],
              ),
              border: Border.all(
                color: AppColors.userAccent.withValues(alpha: 0.13),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wordmark + date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'zyntro',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 15,
                        color: AppColors.userAccent,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(session.startedAt),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Headline
                Text(
                  'DONE.',
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.textV2Primary,
                    letterSpacing: -2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$durationStr  ·  ${WorkoutType.fromString(session.type).displayName}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textV2Secondary,
                  ),
                ),
                const SizedBox(height: 16),
                // 3 stats row
                Row(
                  children: [
                    _CardStat(label: 'Exercises', value: '$totalExercises'),
                    const SizedBox(width: 20),
                    _CardStat(label: 'Sets', value: '$totalSets'),
                    const SizedBox(width: 20),
                    _CardStat(
                      label: 'Volume',
                      value: totalVolume > 0
                          ? '${totalVolume.toStringAsFixed(1)} kg'
                          : '—',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '@$username',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textV2Secondary,
                      ),
                    ),
                    Text(
                      '+$points pts',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        color: AppColors.userAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;

  const _CardStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.h5.copyWith(color: AppColors.textV2Primary),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: AppColors.textV2Tertiary,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Post to feed section
// ────────────────────────────────────────────────────────────────────────────

class _PostToFeedSection extends StatelessWidget {
  final bool postedToFeed;
  final String? selectedPhotoPath;
  final bool isPickingPhoto;
  final bool isSharing;
  final bool shareWithFriendsOnly;
  final double? uploadProgress;
  final VoidCallback onPhotoTap;
  final VoidCallback onRemovePhoto;
  final ValueChanged<bool> onToggleFriendsOnly;
  final VoidCallback onShare;

  const _PostToFeedSection({
    required this.postedToFeed,
    required this.selectedPhotoPath,
    required this.isPickingPhoto,
    required this.isSharing,
    required this.shareWithFriendsOnly,
    required this.uploadProgress,
    required this.onPhotoTap,
    required this.onRemovePhoto,
    required this.onToggleFriendsOnly,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          postedToFeed
              ? Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.userAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Posted to feed',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.userAccent,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Post to feed',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),

          const SizedBox(height: 14),

          // Photo placeholder / preview
          GestureDetector(
            onTap: (isPickingPhoto || isSharing || postedToFeed)
                ? null
                : (selectedPhotoPath != null
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                _LocalPhotoViewer(path: selectedPhotoPath!),
                          ),
                        )
                      : onPhotoTap),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textV2Tertiary,
                  style: BorderStyle.solid,
                ),
                image: selectedPhotoPath != null
                    ? DecorationImage(
                        image: FileImage(File(selectedPhotoPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: selectedPhotoPath == null
                  ? Center(
                      child: isPickingPhoto
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.userAccent,
                              ),
                            )
                          : Text(
                              'Add photo',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                color: AppColors.textV2Tertiary,
                              ),
                            ),
                    )
                  : Stack(
                      children: [
                        if (!isSharing && !postedToFeed)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: onRemovePhoto,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Friends only toggle
          if (!postedToFeed) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Friends only',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.textV2Secondary,
                  ),
                ),
                Switch(
                  value: shareWithFriendsOnly,
                  onChanged: isSharing ? null : onToggleFriendsOnly,
                  activeThumbColor: AppColors.userAccent,
                  inactiveTrackColor: AppColors.surfaceV2Active,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Upload progress
          if (uploadProgress != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Elevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        uploadProgress! < 0.1
                            ? 'Creating post...'
                            : uploadProgress! < 0.9
                            ? 'Uploading photo...'
                            : 'Finalizing...',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textV2Secondary,
                        ),
                      ),
                      Text(
                        '${(uploadProgress! * 100).toInt()}%',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.userAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: uploadProgress,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceV2Active,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.userAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Share button
          if (!postedToFeed)
            GestureDetector(
              onTap: isSharing ? null : onShare,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: isSharing
                      ? AppColors.userAccent.withValues(alpha: 0.5)
                      : AppColors.userAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: isSharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Share Workout',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Ghost button
// ────────────────────────────────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textV2Tertiary),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 15,
              color: AppColors.textV2Secondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Local photo full-screen viewer
// ────────────────────────────────────────────────────────────────────────────

class _LocalPhotoViewer extends StatelessWidget {
  final String path;

  const _LocalPhotoViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    final controller = TransformationController();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fit_screen, color: Colors.white),
            ),
            onPressed: () => controller.value = Matrix4.identity(),
            tooltip: 'Reset zoom',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          transformationController: controller,
          minScale: 0.5,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(20),
          child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
