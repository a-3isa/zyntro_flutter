import '../../features/auth/domain/entities/auth_user_entity.dart';

/// Thrown when a password-provider user tries a social write before verifying
/// email. Mirrors Firestore `isEmailVerifiedForSocial` (Z-AUTH-002).
class EmailVerificationRequiredException implements Exception {
  const EmailVerificationRequiredException([
    this.message =
        'Verify your email before following, posting, or inviting friends.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Password accounts must verify email before social/abuse-prone writes.
/// Federated IdPs are treated as verified.
bool needsEmailVerificationForSocial(AuthUserEntity? user) {
  if (user == null) return false;
  final isPassword = user.providerIds.contains('password');
  return isPassword && !user.emailVerified;
}

void ensureEmailVerifiedForSocial(AuthUserEntity? user) {
  if (needsEmailVerificationForSocial(user)) {
    throw const EmailVerificationRequiredException();
  }
}
