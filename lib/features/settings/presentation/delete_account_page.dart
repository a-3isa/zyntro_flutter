import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/reauthentication_dialog.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';

/// Account deletion page with confirmation and password verification.
/// Shows warnings about permanent data loss before allowing account deletion.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _understandConsequences = false;
  String? _errorMessage;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handleDeleteAccount() async {
    // Only validate the checkbox/form here
    if (!_formKey.currentState!.validate()) return;
    if (!_understandConsequences) return;

    // Show initial warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            const Text('Final Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you absolutely sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Request re-authentication
    final password = await ReauthenticationDialog.show(
      context,
      title: 'Delete Account',
      description: 'Please enter your password to confirm account deletion.',
      isDestructive: true,
    );

    if (password == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).deleteAccount(password);

      if (mounted) {
        // Navigate to login page after successful deletion
        context.go(AppRoutes.login);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    } else if (error.contains('requires-recent-login')) {
      return 'Please sign out and sign in again before deleting your account.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'Failed to delete account. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
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
                const GradientText(
                  text: 'Delete Account',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  colors: [AppColors.textDark, AppColors.textSecondaryDark],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Warning banner
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'This action is permanent',
                            style: TextStyle(
                              fontSize: AppFontSize.lg,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Once you delete your account, there is no going back. Please be certain.',
                            style: TextStyle(
                              color: AppColors.error.withValues(alpha: 0.8),
                              fontSize: AppFontSize.md,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // What will be deleted
                    const Text(
                      'What will be deleted:',
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDeletionItem('Your profile and personal information'),
                    _buildDeletionItem('All your workout posts'),
                    _buildDeletionItem('Your workout sessions and history'),
                    _buildDeletionItem(
                      'Your followers and following connections',
                    ),
                    _buildDeletionItem('All notifications and preferences'),

                    const SizedBox(height: AppSpacing.xl),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.md,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Confirmation checkbox
                    CheckboxListTile(
                      value: _understandConsequences,
                      onChanged: (value) {
                        setState(
                          () => _understandConsequences = value ?? false,
                        );
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I understand that this action cannot be undone and all my data will be permanently deleted.',
                        style: TextStyle(fontSize: AppFontSize.sm),
                      ),
                      activeColor: AppColors.error,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Delete button
                    ZyntroButton(
                      title: _isLoading
                          ? 'Deleting Account...'
                          : 'Delete My Account',
                      fullWidth: true,
                      loading: _isLoading,
                      variant: ZyntroButtonVariant.destructive,
                      onPressed: (_isLoading || !_understandConsequences)
                          ? null
                          : () {
                              HapticFeedback.heavyImpact();
                              _handleDeleteAccount();
                            },
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Cancel button
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(
            Icons.remove_circle_outline,
            color: AppColors.error,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: AppFontSize.sm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
