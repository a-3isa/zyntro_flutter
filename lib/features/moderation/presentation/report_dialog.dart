import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../auth/auth_providers.dart';
import '../../../services/moderation_service.dart';

/// Report dialog for reporting users, posts, or comments.
/// Shows as a bottom sheet with reason selection and optional description.
class ReportDialog extends ConsumerStatefulWidget {
  final String? reportedUserId;
  final String? reportedPostId;
  final String? reportedCommentId;
  final String? postAuthorId;
  final String? commentAuthorId;
  final String reportedUserName;

  const ReportDialog({
    super.key,
    this.reportedUserId,
    this.reportedPostId,
    this.reportedCommentId,
    this.postAuthorId,
    this.commentAuthorId,
    required this.reportedUserName,
  });

  /// Show the report dialog as a bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    String? reportedUserId,
    String? reportedPostId,
    String? reportedCommentId,
    String? postAuthorId,
    String? commentAuthorId,
    required String reportedUserName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ReportDialog(
        reportedUserId: reportedUserId,
        reportedPostId: reportedPostId,
        reportedCommentId: reportedCommentId,
        postAuthorId: postAuthorId,
        commentAuthorId: commentAuthorId,
        reportedUserName: reportedUserName,
      ),
    );
  }

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  ReportReason? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String get _reportType {
    if (widget.reportedPostId != null) return 'post';
    if (widget.reportedCommentId != null) return 'comment';
    return 'user';
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a reason')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authState = ref.read(authSessionProvider);
      final reporterId = authState.valueOrNull?.id;
      if (reporterId == null) throw Exception('Not authenticated');

      final moderationService = ref.read(moderationServiceProvider);

      if (widget.reportedPostId != null) {
        await moderationService.reportPost(
          reporterId: reporterId,
          postId: widget.reportedPostId!,
          postAuthorId: widget.postAuthorId ?? widget.reportedUserId ?? '',
          reason: _selectedReason!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      } else if (widget.reportedCommentId != null) {
        await moderationService.reportComment(
          reporterId: reporterId,
          commentId: widget.reportedCommentId!,
          commentAuthorId:
              widget.commentAuthorId ?? widget.reportedUserId ?? '',
          reason: _selectedReason!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      } else if (widget.reportedUserId != null) {
        await moderationService.reportUser(
          reporterId: reporterId,
          reportedUserId: widget.reportedUserId!,
          reason: _selectedReason!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted. Thank you for keeping our community safe.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            'Report ${_reportType == 'user' ? widget.reportedUserName : _reportType}',
            style: const TextStyle(
              fontSize: AppFontSize.xl,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Why are you reporting this $_reportType?',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Reason selection
          ...ReportReason.values.map(
            (reason) => RadioListTile<ReportReason>(
              value: reason,
              // ignore: deprecated_member_use
              groupValue: _selectedReason,
              // ignore: deprecated_member_use
              onChanged: (value) => setState(() => _selectedReason = value),
              title: Text(_getReasonLabel(reason)),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Description field
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Additional details (optional)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Report'),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  String _getReasonLabel(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'Spam or misleading';
      case ReportReason.harassment:
        return 'Harassment or bullying';
      case ReportReason.inappropriate:
        return 'Inappropriate content';
      case ReportReason.other:
        return 'Other';
    }
  }
}
