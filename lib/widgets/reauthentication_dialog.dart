import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/providers/auth_controller.dart';

/// A reusable dialog for re-authentication before sensitive operations.
///
/// Returns `true` if re-authentication was successful, `false` otherwise.
/// Used by password change, email change, and account deletion flows.
class ReauthenticationDialog extends ConsumerStatefulWidget {
  /// Title of the dialog
  final String title;

  /// Description explaining why re-authentication is needed
  final String description;

  /// Whether this is a destructive action (e.g. delete account)
  final bool isDestructive;

  const ReauthenticationDialog({
    super.key,
    this.title = 'Confirm Your Identity',
    this.description = 'Please enter your password to continue.',
    this.isDestructive = false,
  });

  @override
  ConsumerState<ReauthenticationDialog> createState() =>
      _ReauthenticationDialogState();

  /// Shows the re-authentication dialog and returns the password if successful.
  /// Returns `null` if the user cancels.
  static Future<String?> show(
    BuildContext context, {
    String title = 'Confirm Your Identity',
    String description = 'Please enter your password to continue.',
    bool isDestructive = false,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReauthenticationDialog(
        title: title,
        description: description,
        isDestructive: isDestructive,
      ),
    );
  }
}

class _ReauthenticationDialogState
    extends ConsumerState<ReauthenticationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final providers =
        ref.read(authSessionProvider).value?.providerIds ?? const <String>[];
    final passwordOnly =
        providers.contains('password') &&
        !providers.contains('google.com') &&
        !providers.contains('facebook.com') &&
        !providers.contains('apple.com');
    final oauthOnly = !providers.contains('password') &&
        (providers.contains('google.com') ||
            providers.contains('facebook.com') ||
            providers.contains('apple.com'));

    if (passwordOnly || !oauthOnly) {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final password = oauthOnly ? '' : _passwordController.text;

      await ref.read(authControllerProvider).reauthenticate(password);

      if (mounted) {
        Navigator.of(context).pop(password);
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
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    } else if (error.contains('user-not-found')) {
      return 'User not found. Please sign in again.';
    }
    return 'Authentication failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final providers =
        ref.watch(authSessionProvider).value?.providerIds ?? const <String>[];
    final oauthOnly = !providers.contains('password') &&
        (providers.contains('google.com') ||
            providers.contains('facebook.com') ||
            providers.contains('apple.com'));
    final oauthLabel = providers.contains('google.com')
        ? 'Continue with Google'
        : providers.contains('facebook.com')
        ? 'Continue with Facebook'
        : providers.contains('apple.com')
        ? 'Continue with Apple'
        : 'Confirm';

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              oauthOnly
                  ? 'Confirm it is you to continue.'
                  : widget.description,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: AppFontSize.sm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (!oauthOnly)
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _handleConfirm(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleConfirm,
          style: widget.isDestructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                )
              : null,
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(oauthOnly ? oauthLabel : 'Confirm'),
        ),
      ],
    );
  }
}
