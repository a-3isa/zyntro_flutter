import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Email/password input used by the login and sign-up forms.
///
/// When [isPassword] is true the field starts obscured and renders a
/// show/hide toggle in the suffix.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.validator,
    this.isPassword = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final bool isPassword;
  final bool enabled;
  final TextInputAction textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      keyboardType: widget.isPassword
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      style: const TextStyle(color: AppColors.textV2Primary),
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: AppColors.textV2Tertiary,
          fontSize: AppFontSize.md,
        ),
        prefixIcon: Icon(widget.icon, color: AppColors.textV2Secondary),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscured ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textV2Secondary,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
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
          borderSide: BorderSide(color: AppColors.userAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        // Tighter than AppSpacing.lg: the login/sign-up forms stack up to three
        // fields plus social buttons and must fit a small phone viewport.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 15,
        ),
        isDense: true,
        errorStyle: const TextStyle(fontSize: 11, height: 1.1),
      ),
    );
  }
}

/// Live checklist of the password rules enforced by `validatePassword`.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = <String, bool>{
      'At least 8 characters': password.length >= 8,
      'One uppercase letter': RegExp(r'[A-Z]').hasMatch(password),
      'One number': RegExp(r'[0-9]').hasMatch(password),
      'One special character': RegExp(
        r'[!@#$%^&*(),.?":{}|<>]',
      ).hasMatch(password),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rules.entries.map((rule) {
        final met = rule.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                met ? Icons.check_circle : Icons.circle_outlined,
                size: 14,
                color: met ? AppColors.success : AppColors.textV2Tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                rule.key,
                style: TextStyle(
                  fontSize: 12,
                  color: met
                      ? AppColors.textV2Secondary
                      : AppColors.textV2Tertiary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
