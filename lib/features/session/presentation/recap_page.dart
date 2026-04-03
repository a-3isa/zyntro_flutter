import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/constants.dart';
import '../../../services/session_service.dart';
import '../../../services/post_service.dart';
import '../../../services/media_service.dart';
import '../../auth/auth_providers.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/premium_animations.dart';
import '../../../utils/haptic_manager.dart';

/// Recap page showing session summary after completion.
/// Updated with photo sharing functionality and improved UI.
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
  double? _uploadProgress; // Track upload progress (0.0 to 1.0)
  String? _createdPostId; // Store post ID for retry scenarios

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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows a bottom sheet with camera and gallery options for photo selection.
  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use your camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotoFromCamera();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotoFromGallery();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick photo from camera.
  Future<void> _pickPhotoFromCamera() async {
    if (_isPickingPhoto) return;
    setState(() => _isPickingPhoto = true);

    try {
      final mediaService = ref.read(mediaServiceProvider);
      final file = await mediaService.pickImage(fromCamera: true);

      if (file != null && mounted) {
        // Check file size
        final fileSize = await file.length();
        if (fileSize > MediaService.maxPhotoSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Image is too large. Please choose a smaller image (max 5MB).',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedPhotoPath = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to capture photo';
        if (e.toString().contains('permission')) {
          errorMessage =
              'Camera permission denied. Please enable camera access in settings.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  /// Pick photo from gallery.
  Future<void> _pickPhotoFromGallery() async {
    if (_isPickingPhoto) return;
    setState(() => _isPickingPhoto = true);

    try {
      final mediaService = ref.read(mediaServiceProvider);
      final file = await mediaService.pickImage(fromCamera: false);

      if (file != null && mounted) {
        // Check file size
        final fileSize = await file.length();
        if (fileSize > MediaService.maxPhotoSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Image is too large. Please choose a smaller image (max 5MB).',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedPhotoPath = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to pick photo';
        if (e.toString().contains('permission')) {
          errorMessage =
              'Photo library permission denied. Please enable access in settings.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedPhotoPath = null;
    });
  }

  Future<void> _handleShare() async {
    if (_session == null) return;

    setState(() {
      _isSharing = true;
      _uploadProgress = _selectedPhotoPath != null ? 0.0 : null;
    });

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) throw Exception('Not authenticated');

      final postService = ref.read(postServiceProvider);

      // Create post with progress callback
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
            ? (progress) {
                if (mounted) {
                  setState(() => _uploadProgress = progress);
                }
              }
            : null,
      );

      _createdPostId = postId;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared to feed! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _isSharing = false;
          _uploadProgress = null;
        });

        // Show "View in Feed" option or navigate?
        _showPostSuccessDialog(postId);
      }
    } catch (e) {
      if (mounted) {
        // Check if post was created but photo upload failed
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

  /// Get user-friendly error message based on error type
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network connection lost. Please check your internet and try again.';
    } else if (errorStr.contains('permission')) {
      return 'Storage permission denied. Please enable storage access in settings.';
    } else if (errorStr.contains('size') || errorStr.contains('5mb')) {
      return 'Photo exceeds 5MB limit. Please choose a smaller photo.';
    } else if (errorStr.contains('format') || errorStr.contains('invalid')) {
      return 'Invalid file format. Only JPG and PNG are supported.';
    }
    return 'Error sharing: $error';
  }

  /// Show retry dialog when post is created but photo upload failed
  void _showPhotoUploadRetryDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Photo Upload Failed'),
        content: Text(
          'Your post was created, but the photo could not be uploaded.\n\n'
          'Error: ${_getErrorMessage(errorMessage)}\n\n'
          'Would you like to retry the upload or continue without the photo?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              // Continue without photo - post already created
              _showPostSuccessDialog(_createdPostId!);
            },
            child: const Text('Continue Without Photo'),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              _retryPhotoUpload();
            },
            child: const Text('Retry Upload'),
          ),
        ],
      ),
    );
  }

  /// Retry photo upload for an already created post
  Future<void> _retryPhotoUpload() async {
    if (_createdPostId == null || _selectedPhotoPath == null) return;

    setState(() {
      _isSharing = true;
      _uploadProgress = 0.0;
    });

    try {
      final mediaService = ref.read(mediaServiceProvider);
      final postService = ref.read(postServiceProvider);

      // Upload photo with progress (raw 0-1 values, scale to 10-90%)
      final photoUrl = await mediaService.uploadPostPhoto(
        filePath: _selectedPhotoPath!,
        postId: _createdPostId!,
        onProgress: (progress) {
          if (mounted) {
            // Scale raw 0-1 progress to 10-90% range
            setState(() => _uploadProgress = 0.1 + progress * 0.8);
          }
        },
      );

      // Update progress to 90% before final update
      if (mounted) {
        setState(() => _uploadProgress = 0.9);
      }

      // Update post with photo URL
      await postService.updatePostPhoto(_createdPostId!, photoUrl);

      // Complete at 100%
      if (mounted) {
        setState(() => _uploadProgress = 1.0);
        await Future.delayed(
          const Duration(milliseconds: 200),
        ); // Brief pause to show 100%

        if (!mounted) return;

        setState(() {
          _isSharing = false;
          _uploadProgress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
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
      builder: (context) => AlertDialog(
        title: const Text('Post Created!'),
        content: const Text('Your workout has been shared to the feed.'),
        actions: [
          TextButton(
            onPressed: () {
              context.pop(); // close dialog
              context.go(
                '/feed',
              ); // Navigate to feed (or specific post if router supports)
            },
            child: const Text('View in Feed'),
          ),
          TextButton(
            onPressed: () {
              context.pop();
              context.go(AppRoutes.main);
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return 'N/A';
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_session == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Session not found'),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.main),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _session!.summary;
    final workoutType = WorkoutType.fromString(_session!.type);
    String durationStr;

    if (workoutType.isCardio &&
        summary?.duration != null &&
        summary!.duration!.isNotEmpty) {
      durationStr = summary.duration!;
    } else {
      durationStr = _formatDuration(_session!.startedAt, _session!.endedAt);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,

      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.15),
                    AppColors.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Custom Header
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 8,
                  bottom: 8,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: GradientText(
                        text: 'Session Recap',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        colors: [
                          AppColors.textDark,
                          AppColors.textSecondaryDark,
                        ],
                      ),
                    ),
                    BounceAnimation(
                      onTap: () {
                        HapticManager.light();
                        _confirmExit();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondaryDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.textDark,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Celebration header with glow and fade animation
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: AppColors.secondaryGradient,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.celebration,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const GradientText(
                              text: 'Great Workout! 💪',
                              style: TextStyle(
                                fontSize: AppFontSize.xxl,
                                fontWeight: FontWeight.bold,
                              ),
                              colors: AppColors.secondaryGradient,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SlideInAnimation.fromBottom(
                        index: 1,
                        child: Text(
                          _session!.title,
                          style: TextStyle(
                            fontSize: AppFontSize.md,
                            color: AppColors.textSecondaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SlideInAnimation.fromBottom(
                        index: 2,
                        child: Text(
                          '$durationStr • ${workoutType.displayName}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // Stats cards - conditional display based on session type
                      if (workoutType.isCardio) ...[
                        // Cardio stats
                        SlideInAnimation.fromBottom(
                          index: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.straighten,
                                  value: summary?.distance != null
                                      ? '${summary!.distance!.toStringAsFixed(2)} km'
                                      : '-',
                                  label: 'Distance',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.timer,
                                  value: durationStr,
                                  label: 'Duration',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SlideInAnimation.fromBottom(
                          index: 4,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.speed,
                                  value: summary?.pace ?? '-',
                                  label: 'Avg Pace',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.local_fire_department,
                                  value: summary?.activeCalories != null
                                      ? '${summary!.activeCalories}'
                                      : '-',
                                  label: 'Calories',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Strength stats
                        SlideInAnimation.fromBottom(
                          index: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.fitness_center,
                                  value: '${summary?.totalExercises ?? 0}',
                                  label: 'Exercises',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.repeat,
                                  value: '${summary?.totalSets ?? 0}',
                                  label: 'Total Sets',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Volume and Duration Row
                        SlideInAnimation.fromBottom(
                          index: 4,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.timer,
                                  value: durationStr,
                                  label: 'Duration',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.scale,
                                  value: summary?.totalVolume != null
                                      ? '${summary!.totalVolume!.toStringAsFixed(1)} kg'
                                      : '-',
                                  label: 'Volume',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Calories and Pace
                        SlideInAnimation.fromBottom(
                          index: 5,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.local_fire_department,
                                  value: summary?.activeCalories != null
                                      ? '${summary!.activeCalories}'
                                      : '-',
                                  label: 'Calories',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.speed,
                                  value: summary?.pace ?? '-',
                                  label: 'Pace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xxl),

                      // Exercises chart (using fl_chart)
                      if (summary?.exercises != null &&
                          summary!.exercises!.isNotEmpty) ...[
                        const Text(
                          'Exercises Breakdown',
                          style: TextStyle(
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Scrollable Bar chart for sets per exercise
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 600),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: (summary.exercises!.length * 60)
                                  .toDouble()
                                  .clamp(300.0, 1000.0), // Dynamic width
                              height: 200,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY:
                                      summary.exercises!.fold<double>(
                                        0,
                                        (max, e) => e.sets > max
                                            ? e.sets.toDouble()
                                            : max,
                                      ) *
                                      1.2,
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem:
                                          (group, groupIndex, rod, rodIndex) {
                                            final exercise =
                                                summary.exercises![groupIndex];
                                            return BarTooltipItem(
                                              '${exercise.name}\n${exercise.sets} sets',
                                              const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final index = value.toInt();
                                          if (index >= 0 &&
                                              index <
                                                  summary.exercises!.length) {
                                            final name =
                                                summary.exercises![index].name;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  return Text(
                                                    name.length > 8
                                                        ? '${name.substring(0, 8)}...'
                                                        : name,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  );
                                                },
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: const FlGridData(show: false),
                                  barGroups: summary.exercises!
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final index = entry.key;
                                        final exercise = entry.value;
                                        return BarChartGroupData(
                                          x: index,
                                          barRods: [
                                            BarChartRodData(
                                              toY: exercise.sets.toDouble(),
                                              color: AppColors.primary,
                                              width: 16,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(4),
                                                    topRight: Radius.circular(
                                                      4,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        );
                                      })
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Exercise list with details
                        ...summary.exercises!.map(
                          (exercise) => Card(
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMuted,
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.sm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fitness_center,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(exercise.name),
                              trailing: Text(
                                '${exercise.sets} sets',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xxl),

                      // Photo selector with enhanced visual feedback
                      Tooltip(
                        message: _selectedPhotoPath != null
                            ? 'Tap to view full size'
                            : 'Add a photo to your post',
                        child: GestureDetector(
                          onTap: (_isPickingPhoto || _isSharing)
                              ? null
                              : (_selectedPhotoPath != null
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              _buildLocalPhotoViewer(),
                                        ),
                                      )
                                    : _showPhotoSourceDialog),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 200,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondaryLight,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.lg,
                              ),
                              border: Border.all(
                                color: _selectedPhotoPath != null
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.3),
                                width: _selectedPhotoPath != null ? 3 : 2,
                                style: BorderStyle.solid,
                              ),
                              boxShadow: _selectedPhotoPath != null
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                              image: _selectedPhotoPath != null
                                  ? DecorationImage(
                                      image: FileImage(
                                        File(_selectedPhotoPath!),
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                // Loading shimmer effect for picking
                                if (_isPickingPhoto)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppBorderRadius.lg,
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          AppColors.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                          AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: AppSpacing.sm),
                                          Text(
                                            'Processing photo...',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                // Empty state
                                else if (_selectedPhotoPath == null)
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 40,
                                          color: _isSharing
                                              ? AppColors.primary.withValues(
                                                  alpha: 0.5,
                                                )
                                              : AppColors.primary,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'Add a photo (optional)',
                                          style: TextStyle(
                                            color: _isSharing
                                                ? AppColors.primary.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Photo action buttons (when photo is selected)
                                if (_selectedPhotoPath != null && !_isSharing)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        // Retake button
                                        GestureDetector(
                                          onTap: _showPhotoSourceDialog,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.refresh,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Remove button
                                        GestureDetector(
                                          onTap: _removePhoto,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Tap to expand hint
                                if (_selectedPhotoPath != null && !_isSharing)
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.fullscreen,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                // Upload in progress overlay
                                if (_isSharing && _selectedPhotoPath != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppBorderRadius.lg,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                          SizedBox(height: AppSpacing.sm),
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(
                                              color: Colors.white,
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
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Actions
                      SwitchListTile(
                        value: _shareWithFriendsOnly,
                        onChanged: (value) =>
                            setState(() => _shareWithFriendsOnly = value),
                        title: const Text('Share with friends only'),
                        activeThumbColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Upload progress indicator
                      if (_uploadProgress != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMuted,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _uploadProgress! < 0.1
                                        ? 'Creating post...'
                                        : _uploadProgress! < 0.9
                                        ? 'Uploading photo...'
                                        : 'Finalizing...',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${(_uploadProgress! * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _uploadProgress!,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[300],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      ElevatedButton.icon(
                        onPressed: _isSharing ? null : _handleShare,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.share),
                        label: Text(
                          _isSharing
                              ? (_uploadProgress != null
                                    ? 'Uploading...'
                                    : 'Sharing...')
                              : 'Share to Feed',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      OutlinedButton(
                        onPressed: () {
                          context.pushReplacement(
                            '/session/start',
                          ); // Verify route
                        },
                        child: const Text('Start Another Session'),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      TextButton(
                        onPressed: () => _confirmExit(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                        child: const Text('Skip Sharing & Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ], // Stack children
      ), // Stack
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without sharing?'),
        content: const Text(
          'Your workout is saved, but not shared to your feed. You can still access it in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.pop();
              context.go(AppRoutes.main);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  /// Build a full-screen viewer for locally selected photos
  Widget _buildLocalPhotoViewer() {
    final transformationController = TransformationController();

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
            onPressed: () =>
                transformationController.value = Matrix4.identity(),
            tooltip: 'Reset zoom',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          transformationController: transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(20),
          child: Center(
            child: Image.file(File(_selectedPhotoPath!), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
