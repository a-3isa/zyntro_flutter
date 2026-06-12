import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/auth/data/exceptions/auth_data_exception.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:zyntro_flutter/features/auth/domain/usecases/authentication_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late AuthenticationUseCase useCase;

  setUpAll(() {
    registerFallbackValue(WorkoutType.other);
  });

  setUp(() {
    repository = MockAuthRepository();
    useCase = AuthenticationUseCase(repository);
  });

  group('AuthenticationUseCase.signInWithEmail', () {
    test('returns validation failure when email is invalid', () async {
      final result = await useCase.signInWithEmail(
        email: 'not-an-email',
        password: 'ValidPass1!',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, 'invalid-email');
      verifyNever(
        () => repository.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    test('returns success when repository succeeds', () async {
      const user = AuthUserEntity(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test',
        photoUrl: null,
        emailVerified: true,
        providerIds: ['password'],
      );

      when(
        () => repository.signInWithEmail(
          email: 'test@example.com',
          password: 'ValidPass1!',
        ),
      ).thenAnswer((_) async => user);

      final result = await useCase.signInWithEmail(
        email: 'test@example.com',
        password: 'ValidPass1!',
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.id, 'user-1');
    });

    test('maps repository exception into AuthFailure', () async {
      when(
        () => repository.signInWithEmail(
          email: 'test@example.com',
          password: 'ValidPass1!',
        ),
      ).thenThrow(
        AuthDataException.auth(
          code: 'invalid-credential',
          message: 'Invalid email or password.',
        ),
      );

      final result = await useCase.signInWithEmail(
        email: 'test@example.com',
        password: 'ValidPass1!',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, 'invalid-credential');
      expect(result.errorOrNull?.message, 'Invalid email or password.');
    });
  });

  group('AuthenticationUseCase.createUserProfile', () {
    test('returns validation failure when display name is too short', () async {
      final result = await useCase.createUserProfile(
        userId: 'user-1',
        displayName: 'a',
        workoutPreference: WorkoutType.other,
        beginnerFlag: false,
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, 'invalid-display-name');
      verifyNever(
        () => repository.createUserProfile(
          userId: 'user-1',
          displayName: 'a',
          workoutPreference: WorkoutType.other,
          beginnerFlag: false,
          photoUrl: null,
          authProvider: null,
        ),
      );
    });
  });

  group('AuthenticationUseCase.sendPasswordResetEmail', () {
    test('returns validation failure when email is invalid', () async {
      final result = await useCase.sendPasswordResetEmail('invalid-email');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, 'invalid-email');
      verifyNever(() => repository.sendPasswordResetEmail('invalid-email'));
    });
  });

  group('AuthenticationUseCase.reauthenticate', () {
    test('returns validation failure when password is empty', () async {
      final result = await useCase.reauthenticate('');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, 'invalid-password');
      verifyNever(() => repository.reauthenticate(''));
    });
  });

  group('AuthenticationUseCase.changeEmail', () {
    test('returns validation failure when new email is invalid', () async {
      final result = await useCase.changeEmail(
        password: 'ValidPass1!',
        newEmail: 'not-email',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, 'invalid-email');
      verifyNever(
        () => repository.changeEmail(
          password: any(named: 'password'),
          newEmail: any(named: 'newEmail'),
        ),
      );
    });
  });

  group('AuthenticationUseCase.changePassword', () {
    test('returns validation failure when new password is weak', () async {
      final result = await useCase.changePassword(
        currentPassword: 'old-pass',
        newPassword: '123',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, 'weak-password');
      verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    });
  });
}
