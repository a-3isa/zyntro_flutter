import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/zyntro_button.dart';
import 'providers/auth_controller.dart';
import 'widgets/auth_error_surface.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  static const String _lastResendKey = 'password_reset_last_resend';
  static const int _cooldownDuration = 60;

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResend = prefs.getInt(_lastResendKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = now - lastResend;

    if (elapsed < _cooldownDuration) {
      setState(() => _cooldownSeconds = _cooldownDuration - elapsed);
      _startCooldownTimer();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  Future<void> _saveCooldownTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt(_lastResendKey, now);
  }

  Future<void> _handleSendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cooldownSeconds > 0) return;

    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .sendPasswordResetEmail(_emailController.text.trim());

      await _saveCooldownTimestamp();

      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() {
          _emailSent = true;
          _cooldownSeconds = _cooldownDuration;
        });
        _startCooldownTimer();
      }
    } catch (e) {
      // Always show the same success path for unknown emails (Z-AUTH-001).
      final message = e.toString();
      final looksLikeMissingUser =
          message.contains('user-not-found') ||
          message.contains('invalid-credential');
      if (looksLikeMissingUser) {
        await _saveCooldownTimestamp();
        if (mounted) {
          setState(() {
            _emailSent = true;
            _cooldownSeconds = _cooldownDuration;
            _errorMessage = null;
          });
          _startCooldownTimer();
        }
      } else if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _errorMessage = _getErrorMessage(message));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'If an account exists for that email, we sent a reset link.';
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textV2Tertiary,
        fontSize: AppFontSize.md,
      ),
      prefixIcon: Icon(icon, color: AppColors.textV2Secondary),
      filled: true,
      fillColor: AppColors.surfaceV2Elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide(color: AppColors.surfaceV2Active),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide(color: AppColors.signal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceV2Elevated,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.textV2Primary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              _emailSent ? _buildSuccessState() : _buildFormState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.surfaceV2Elevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                size: 40,
                color: AppColors.signal,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Center(
            child: Text(
              'Forgot Password?',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            "Enter your email address and we'll send you a link to reset your password.",
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textV2Secondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xxl),

          if (_errorMessage != null) ...[
            AuthErrorSurface(
              message: _errorMessage!,
              suggestion: 'Verify email format and try sending reset again.',
              onDismiss: () => setState(() => _errorMessage = null),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: AppColors.textV2Primary),
            decoration: _buildInputDecoration(
              hint: 'Email Address',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleSendResetEmail(),
          ),

          const SizedBox(height: AppSpacing.xl),

          ZyntroButton(
            title: _isLoading
                ? 'Sending...'
                : _cooldownSeconds > 0
                ? 'Resend in ${_cooldownSeconds}s'
                : 'Send Reset Email',
            fullWidth: true,
            loading: _isLoading,
            size: ZyntroButtonSize.lg,
            rightIcon: _isLoading || _cooldownSeconds > 0
                ? null
                : const Icon(Icons.send_rounded),
            onPressed: (_isLoading || _cooldownSeconds > 0)
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    _handleSendResetEmail();
                  },
          ),

          const SizedBox(height: AppSpacing.xl),

          Center(
            child: TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go(AppRoutes.login);
              },
              child: Text(
                'Back to Sign In',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.signal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceV2Elevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 40,
              color: AppColors.success,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        Center(
          child: Text(
            'Check Your Email',
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Primary,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                "We've sent a password reset link to:",
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textV2Secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _emailController.text.trim(),
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.signal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Text(
          "Click the link in the email to reset your password. If you don't see it, check your spam folder.",
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.xxl),

        ZyntroButton(
          title: _cooldownSeconds > 0
              ? 'Resend in ${_cooldownSeconds}s'
              : 'Resend Email',
          fullWidth: true,
          variant: ZyntroButtonVariant.secondary,
          loading: _isLoading,
          size: ZyntroButtonSize.lg,
          leftIcon: _cooldownSeconds > 0
              ? null
              : const Icon(Icons.refresh_rounded),
          onPressed: (_isLoading || _cooldownSeconds > 0)
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  _handleSendResetEmail();
                },
        ),

        const SizedBox(height: AppSpacing.md),

        ZyntroButton(
          title: 'Back to Sign In',
          fullWidth: true,
          size: ZyntroButtonSize.lg,
          rightIcon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.go(AppRoutes.login);
          },
        ),
      ],
    );
  }
}
