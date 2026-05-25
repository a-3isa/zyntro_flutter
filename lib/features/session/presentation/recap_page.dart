import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/constants.dart';
import '../../../services/session_service.dart';
import '../../../services/post_service.dart';
import '../../../services/media_service.dart';
import '../../auth/auth_providers.dart';
import '../../../app/navigation/app_router.dart';
import '../../../utils/haptic_manager.dart';

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
  bool _postedToFeed = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session =
          await ref.read(sessionServiceProvider).getSession(widget.sessionId);
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
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.accentLime),
                title: Text('Take Photo',
                    style: GoogleFonts.outfit(color: AppColors.textV2Primary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(fromCamera: true);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: AppColors.accentLime),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.outfit(color: AppColors.textV2Primary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(fromCamera: false);
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.outfit(color: AppColors.textV2Secondary)),
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Image is too large (max 5 MB).'),
              backgroundColor: AppColors.error,
            ));
          }
          return;
        }
        setState(() => _selectedPhotoPath = file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().contains('permission')
              ? 'Permission denied. Enable access in settings.'
              : 'Failed to pick photo.'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _removePhoto() => setState(() => _selectedPhotoPath = null);

  // ── share / post ──────────────────────────────────────────────────────────

  Future<void> _handleShare() async {
    if (_session == null) return;
    setState(() {
      _isSharing = true;
      _uploadProgress = _selectedPhotoPath != null ? 0.0 : null;
    });
    try {
      final uid = ref.read(authSessionProvider).valueOrNull?.id;
      if (uid == null) throw Exception('Not authenticated');

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
        setState(() {
          _isSharing = false;
          _uploadProgress = null;
          _postedToFeed = true;
        });
        _showPostSuccessDialog(postId);
      }
    } catch (e) {
      if (mounted) {
        if (_createdPostId != null && _selectedPhotoPath != null) {
          _showPhotoUploadRetryDialog(e.toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ));
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
        title: Text('Photo Upload Failed',
            style: GoogleFonts.syne(color: AppColors.textV2Primary)),
        content: Text(
          'Your post was created, but the photo could not be uploaded.\n\n'
          '${_getErrorMessage(err)}\n\n'
          'Retry the upload or continue without the photo?',
          style: GoogleFonts.outfit(color: AppColors.textV2Secondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctx.pop();
              _showPostSuccessDialog(_createdPostId!);
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
        setState(() => _uploadProgress = 1.0);
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          _isSharing = false;
          _uploadProgress = null;
          _postedToFeed = true;
        });
        _showPostSuccessDialog(_createdPostId!);
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

  void _showPostSuccessDialog(String postId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceV2,
        title: Text('Post Created!',
            style:
                GoogleFonts.syne(color: AppColors.textV2Primary)),
        content: Text('Your workout has been shared to the feed.',
            style: GoogleFonts.outfit(color: AppColors.textV2Secondary)),
        actions: [
          TextButton(
            onPressed: () {
              ctx.pop();
              context.go(AppRoutes.main);
            },
            child: const Text('View in Feed'),
          ),
          TextButton(
            onPressed: () {
              ctx.pop();
              context.go(AppRoutes.main);
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.accentLime)),
      );
    }

    if (_session == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Session not found',
                  style: GoogleFonts.outfit(color: AppColors.textV2Secondary)),
              const SizedBox(height: 24),
              _GhostButton(
                label: 'Back to Home',
                onTap: () => context.go(AppRoutes.main),
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

    final authUser = ref.watch(authSessionProvider).valueOrNull;
    final username = authUser?.displayName ?? 'you';

    return Scaffold(
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
                  onTap: () {
                    HapticManager.light();
                    context.go(AppRoutes.main);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: AppColors.textV2Secondary),
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
                          Row(
                            children: [
                              Text(
                                durationStr,
                                style: GoogleFonts.outfit(
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
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceV2,
                                  border: Border.all(
                                    color: AppColors.accentLime
                                        .withValues(alpha: 0.13),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt,
                                        size: 14,
                                        color: AppColors.accentLime),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+$points',
                                      style: GoogleFonts.syne(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accentLime,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'pts',
                                      style: GoogleFonts.outfit(
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
                                  accentColor: AppColors.accentLime,
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
                            () => _shareCardExpanded = !_shareCardExpanded),
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
                        onTap: () => context.go(AppRoutes.main),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      style: GoogleFonts.syne(
        fontSize: 64,
        fontWeight: FontWeight.w800,
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
            style: GoogleFonts.syne(
              fontSize: 34,
              fontWeight: FontWeight.w800,
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
                style: GoogleFonts.outfit(
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

  @override
  Widget build(BuildContext context) {
    final maxSets =
        exercises.fold<int>(0, (m, e) => e.sets > m ? e.sets : m);

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
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Tertiary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          ...exercises.map((ex) {
            final ratio = maxSets > 0 ? ex.sets / maxSets : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ex.name,
                        style: GoogleFonts.syne(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      Text(
                        '${ex.sets} sets',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textV2Secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 4,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceV2Elevated,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          Container(
                            height: 4,
                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              color: AppColors.accentLime,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                  style: GoogleFonts.outfit(
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
                color: AppColors.accentLime.withValues(alpha: 0.13),
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
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
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentLime,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(session.startedAt),
                      style: GoogleFonts.outfit(
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
                  style: GoogleFonts.syne(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textV2Primary,
                    letterSpacing: -2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$durationStr  ·  ${WorkoutType.fromString(session.type).displayName}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
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
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textV2Secondary,
                      ),
                    ),
                    Text(
                      '+$points pts',
                      style: GoogleFonts.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentLime,
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
          style: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textV2Primary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
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
                    const Icon(Icons.check_circle,
                        size: 16, color: AppColors.accentLime),
                    const SizedBox(width: 6),
                    Text(
                      'Posted to feed',
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentLime,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Post to feed',
                  style: GoogleFonts.syne(
                    fontSize: 16,
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
                            builder: (_) => _LocalPhotoViewer(
                                path: selectedPhotoPath!),
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
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentLime,
                              ),
                            )
                          : Text(
                              'Add photo',
                              style: GoogleFonts.outfit(
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
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
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
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textV2Secondary,
                  ),
                ),
                Switch(
                  value: shareWithFriendsOnly,
                  onChanged: isSharing ? null : onToggleFriendsOnly,
                  activeThumbColor: AppColors.accentLime,
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
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textV2Secondary),
                      ),
                      Text(
                        '${(uploadProgress! * 100).toInt()}%',
                        style: GoogleFonts.syne(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentLime,
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accentLime),
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
                      ? AppColors.accentLime.withValues(alpha: 0.5)
                      : AppColors.accentLime,
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
                          style: GoogleFonts.syne(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
            style: GoogleFonts.syne(
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
          child: Center(
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
