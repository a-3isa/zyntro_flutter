import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/models.dart';
import '../../../../core/constants/constants.dart';

// ────────────────────────────────────────────────────────────────────────────
// "Done." hero header
// ────────────────────────────────────────────────────────────────────────────

class RecapDoneHeader extends StatelessWidget {
  const RecapDoneHeader();

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

class RecapStatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;

  const RecapStatCell({
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
            style: AppTextStyles.sessionStat.copyWith(
              fontSize: 34,
              color: AppColors.textV2Primary,
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

class RecapBreakdownSection extends StatelessWidget {
  final List<ExerciseSummary> exercises;

  const RecapBreakdownSection({required this.exercises});

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
                          color: AppColors.signal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${ex.sets} ${ex.sets == 1 ? 'set' : 'sets'}',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.signal,
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

class RecapShareCardSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final Session session;
  final String durationStr;
  final int totalExercises;
  final int totalSets;
  final double totalVolume;
  final int points;
  final String username;

  const RecapShareCardSection({
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
                color: AppColors.signal.withValues(alpha: 0.13),
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
                        color: AppColors.signal,
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
                    RecapCardStat(label: 'Exercises', value: '$totalExercises'),
                    const SizedBox(width: 20),
                    RecapCardStat(label: 'Sets', value: '$totalSets'),
                    const SizedBox(width: 20),
                    RecapCardStat(
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
                        color: AppColors.signal,
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

class RecapCardStat extends StatelessWidget {
  final String label;
  final String value;

  const RecapCardStat({required this.label, required this.value});

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

class RecapPostToFeedSection extends StatelessWidget {
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

  const RecapPostToFeedSection({
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
                    Icon(Icons.check_circle, size: 16, color: AppColors.signal),
                    const SizedBox(width: 6),
                    Text(
                      'Posted to feed',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.signal,
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
                                RecapLocalPhotoViewer(path: selectedPhotoPath!),
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
                                color: AppColors.signal,
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
                  activeThumbColor: AppColors.signal,
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
                          color: AppColors.signal,
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
                        AppColors.signal,
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
                      ? AppColors.signal.withValues(alpha: 0.5)
                      : AppColors.signal,
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

class RecapGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const RecapGhostButton({required this.label, required this.onTap});

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

class RecapLocalPhotoViewer extends StatelessWidget {
  final String path;

  const RecapLocalPhotoViewer({required this.path});

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
