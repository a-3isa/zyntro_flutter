import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:zyntro_flutter/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:zyntro_flutter/features/auth/data/models/auth_user_model.dart';
import 'package:zyntro_flutter/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  late MockAuthRemoteDataSource remoteDataSource;
  late MockAuthLocalDataSource localDataSource;
  late AuthRepositoryImpl repository;

  // A user whose cachedAt would have been 35 minutes ago — previously would
  // have been evicted by the 30-min TTL. The TTL was removed in T003, so this
  // user must now be returned.
  const staleButValidCachedUser = AuthUserModel(
    id: 'user-123',
    email: 'test@example.com',
    displayName: 'Test User',
    photoUrl: null,
    emailVerified: true,
    providerIds: ['password'],
  );

  setUp(() {
    remoteDataSource = MockAuthRemoteDataSource();
    localDataSource = MockAuthLocalDataSource();
    repository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );
  });

  // Test 1: TTL removal — cache entry older than 30 min must still be returned.
  // Before T003 this returned null (TTL evicted the entry); after T003 it must
  // return the cached user because TTL logic is gone.
  test(
    'getCurrentUser returns cached user when Firebase returns null (TTL removed)',
    () async {
      when(
        () => remoteDataSource.getCurrentUser(),
      ).thenAnswer((_) async => null);
      when(
        () => localDataSource.getCachedUser(),
      ).thenAnswer((_) async => staleButValidCachedUser);

      final result = await repository.getCurrentUser();

      expect(result, isNotNull);
      expect(result!.id, equals('user-123'));
    },
  );

  // Test 2: Sign-in required path — both remote and cache return null.
  test(
    'getCurrentUser returns null when Firebase and cache both return null',
    () async {
      when(
        () => remoteDataSource.getCurrentUser(),
      ).thenAnswer((_) async => null);
      when(
        () => localDataSource.getCachedUser(),
      ).thenAnswer((_) async => null);

      final result = await repository.getCurrentUser();

      expect(result, isNull);
    },
  );
}
