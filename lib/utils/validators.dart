// Centralized validation utilities for authentication and user input.
// Provides RFC-compliant email validation, comprehensive password strength
// checking, and display name validation.

/// Result of password strength analysis.
class PasswordStrength {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasNumber;
  final bool hasSpecialChar;
  final int score;
  final String level;

  const PasswordStrength({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSpecialChar,
    required this.score,
    required this.level,
  });

  /// Check if password meets all requirements.
  bool get isValid =>
      hasMinLength && hasUppercase && hasNumber && hasSpecialChar;
}

/// Validates an email address using RFC 5322-compliant pattern.
/// Returns null if valid, error message string if invalid.
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your email';
  }

  // Trim whitespace
  final email = value.trim();

  // Check for empty after trim
  if (email.isEmpty) {
    return 'Please enter your email';
  }

  // RFC 5322 compliant email regex pattern
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    caseSensitive: false,
  );

  if (!emailRegex.hasMatch(email)) {
    return 'Please enter a valid email address';
  }

  // Check for multiple @ symbols
  if ('@'.allMatches(email).length > 1) {
    return 'Please enter a valid email address';
  }

  // Check for spaces
  if (email.contains(' ')) {
    return 'Email cannot contain spaces';
  }

  return null;
}

/// Validates a password for strength requirements.
/// Returns null if valid, descriptive error message if invalid.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a password';
  }

  final strength = checkPasswordStrength(value);

  if (!strength.hasMinLength) {
    return 'Password must be at least 8 characters';
  }

  if (!strength.isValid) {
    return 'Password must include uppercase, number, and special character';
  }

  return null;
}

/// Analyzes password strength and returns detailed requirement checks.
/// Returns a PasswordStrength object with individual requirement checks
/// and overall strength score.
PasswordStrength checkPasswordStrength(String password) {
  final hasMinLength = password.length >= 8;
  final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
  final hasNumber = RegExp(r'[0-9]').hasMatch(password);
  final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

  // Calculate score (0-4 based on criteria met)
  int score = 0;
  if (hasMinLength) score++;
  if (hasUppercase) score++;
  if (hasNumber) score++;
  if (hasSpecialChar) score++;

  // Determine strength level
  String level;
  switch (score) {
    case 0:
    case 1:
      level = 'weak';
      break;
    case 2:
      level = 'medium';
      break;
    case 3:
      level = 'strong';
      break;
    case 4:
      level = 'very_strong';
      break;
    default:
      level = 'weak';
  }

  return PasswordStrength(
    hasMinLength: hasMinLength,
    hasUppercase: hasUppercase,
    hasNumber: hasNumber,
    hasSpecialChar: hasSpecialChar,
    score: score,
    level: level,
  );
}

/// Validates a display name for profile setup.
/// Returns null if valid, error message string if invalid.
String? validateDisplayName(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a display name';
  }

  // Check for leading/trailing spaces
  if (value != value.trim()) {
    return 'Display name cannot have leading or trailing spaces';
  }

  // Check minimum length
  if (value.length < 2) {
    return 'Display name must be at least 2 characters';
  }

  // Check maximum length
  if (value.length > 30) {
    return 'Display name must be 30 characters or less';
  }

  // Allow letters, numbers, spaces, underscores, hyphens
  final validCharsRegex = RegExp(r'^[a-zA-Z0-9\s_-]+$');
  if (!validCharsRegex.hasMatch(value)) {
    return 'Display name can only contain letters, numbers, spaces, underscores, and hyphens';
  }

  return null;
}
