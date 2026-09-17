import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/auth/email_verification_gate.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';

AuthUserEntity _user({
  required bool emailVerified,
  List<String> providerIds = const ['password'],
}) {
  return AuthUserEntity(
    id: 'u1',
    email: 'a@b.co',
    displayName: 'A',
    photoUrl: null,
    emailVerified: emailVerified,
    providerIds: providerIds,
  );
}

void main() {
  group('needsEmailVerificationForSocial', () {
    test('password + unverified needs gate', () {
      expect(needsEmailVerificationForSocial(_user(emailVerified: false)), isTrue);
    });

    test('password + verified skips gate', () {
      expect(needsEmailVerificationForSocial(_user(emailVerified: true)), isFalse);
    });

    test('google provider skips gate even if emailVerified false', () {
      expect(
        needsEmailVerificationForSocial(
          _user(emailVerified: false, providerIds: const ['google.com']),
        ),
        isFalse,
      );
    });

    test('null user skips gate', () {
      expect(needsEmailVerificationForSocial(null), isFalse);
    });
  });

  group('ensureEmailVerifiedForSocial', () {
    test('throws for unverified password user', () {
      expect(
        () => ensureEmailVerifiedForSocial(_user(emailVerified: false)),
        throwsA(isA<EmailVerificationRequiredException>()),
      );
    });

    test('allows verified password user', () {
      expect(
        () => ensureEmailVerifiedForSocial(_user(emailVerified: true)),
        returnsNormally,
      );
    });
  });
}
