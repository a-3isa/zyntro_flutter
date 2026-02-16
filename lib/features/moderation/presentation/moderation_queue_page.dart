import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../services/auth_service.dart';
import '../../../services/moderation_service.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';
import '../../../utils/haptic_manager.dart';
import 'package:go_router/go_router.dart';

/// Moderation queue page for admins to review reports.
/// Only accessible to users with isModerator = true.
class ModerationQueuePage extends ConsumerStatefulWidget {
  const ModerationQueuePage({super.key});

  @override
  ConsumerState<ModerationQueuePage> createState() =>
      _ModerationQueuePageState();
}

class _ModerationQueuePageState extends ConsumerState<ModerationQueuePage> {
  final Set<String> _processingIds = {};

  Future<void> _handleAction(
    Report report,
    ReportStatus status,
    String moderatorId, {
    Duration? banDuration,
  }) async {
    if (_processingIds.contains(report.id)) return;

    setState(() => _processingIds.add(report.id));

    try {
      final moderationService = ref.read(moderationServiceProvider);

      // Review the report
      await moderationService.reviewReport(
        reportId: report.id,
        newStatus: status,
        moderatorId: moderatorId,
      );

      // If banning, apply the ban
      if (banDuration != null || status == ReportStatus.reviewed) {
        if (banDuration != null) {
          await moderationService.banUser(
            userId: report.reportedUserId,
            reason: 'Violation: ${report.reason.value}',
            duration: banDuration,
            moderatorId: moderatorId,
          );
        }
      }

      // Refresh the list
      ref.invalidate(pendingReportsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == ReportStatus.dismissed
                  ? 'Report dismissed'
                  : banDuration != null
                  ? 'User banned'
                  : 'Report reviewed',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(report.id));
      }
    }
  }

  void _showActionMenu(Report report, String moderatorId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Take Action',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Dismiss Report'),
                subtitle: const Text('No action needed'),
                onTap: () {
                  Navigator.pop(context);
                  _handleAction(report, ReportStatus.dismissed, moderatorId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: const Text('Warn User'),
                subtitle: const Text('Mark as reviewed without ban'),
                onTap: () {
                  Navigator.pop(context);
                  _handleAction(report, ReportStatus.reviewed, moderatorId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer, color: AppColors.error),
                title: const Text('Ban 1 Day'),
                onTap: () {
                  Navigator.pop(context);
                  _handleAction(
                    report,
                    ReportStatus.reviewed,
                    moderatorId,
                    banDuration: const Duration(days: 1),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer, color: AppColors.error),
                title: const Text('Ban 7 Days'),
                onTap: () {
                  Navigator.pop(context);
                  _handleAction(
                    report,
                    ReportStatus.reviewed,
                    moderatorId,
                    banDuration: const Duration(days: 7),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.error),
                title: const Text('Permanent Ban'),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Permanent Ban'),
                      content: const Text(
                        'Are you sure you want to permanently ban this user?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: const Text('Ban Permanently'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    Navigator.pop(context);
                    // Permanent ban = no duration
                    await ref
                        .read(moderationServiceProvider)
                        .banUser(
                          userId: report.reportedUserId,
                          reason: 'Violation: ${report.reason.value}',
                          moderatorId: moderatorId,
                        );
                    await ref
                        .read(moderationServiceProvider)
                        .reviewReport(
                          reportId: report.id,
                          newStatus: ReportStatus.reviewed,
                          moderatorId: moderatorId,
                        );
                    ref.invalidate(pendingReportsProvider);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final reportsAsync = ref.watch(pendingReportsProvider);

    return Scaffold(
      body: Column(
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
                BounceAnimation(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: GradientText(
                    text: 'Moderation Queue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    colors: [AppColors.textDark, AppColors.textSecondaryDark],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: userAsync.when(
              data: (user) {
                if (user == null || !user.isModerator) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 64, color: Colors.grey),
                        SizedBox(height: AppSpacing.lg),
                        Text(
                          'Access Denied',
                          style: TextStyle(
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text('You do not have moderator privileges'),
                      ],
                    ),
                  );
                }

                return reportsAsync.when(
                  data: (reports) {
                    if (reports.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(pendingReportsProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          return _buildReportCard(report, user.id);
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green.shade400),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'All clear!',
              style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No pending reports to review',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: AppFontSize.md,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Report report, String moderatorId) {
    final isProcessing = _processingIds.contains(report.id);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: _getReasonColor(report.reason),
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: Text(
                    _getReasonLabel(report.reason),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppFontSize.xs,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(report.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Report details
            Text(
              _getReportTitle(report),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (report.description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                report.description!,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Action button
            SizedBox(
              width: double.infinity,
              child: isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _showActionMenu(report, moderatorId),
                      child: const Text('Take Action'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getReportTitle(Report report) {
    if (report.reportedPostId != null) {
      return 'Post reported';
    } else if (report.reportedCommentId != null) {
      return 'Comment reported';
    }
    return 'User reported';
  }

  String _getReasonLabel(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'SPAM';
      case ReportReason.harassment:
        return 'HARASSMENT';
      case ReportReason.inappropriate:
        return 'INAPPROPRIATE';
      case ReportReason.other:
        return 'OTHER';
    }
  }

  Color _getReasonColor(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return Colors.orange;
      case ReportReason.harassment:
        return AppColors.error;
      case ReportReason.inappropriate:
        return Colors.purple;
      case ReportReason.other:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}
