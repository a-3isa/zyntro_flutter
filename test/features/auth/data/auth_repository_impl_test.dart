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

  const cachedUser = AuthUserModel(
    id: 'user-1',
    email: 'test@example.com',
    displayName: 'Test',
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

  test('getCurrentUser caches and returns remote user when present', () async {
    when(
      () => remoteDataSource.getCurrentUser(),
    ).thenAnswer((_) async => cachedUser);
    when(() => localDataSource.cacheUser(cachedUser)).thenAnswer((_) async {});

    final result = await repository.getCurrentUser();

    expect(result?.id, 'user-1');
    verify(() => localDataSource.cacheUser(cachedUser)).called(1);
  });

  test(
    'getCurrentUser falls back to cached user when remote is null',
    () async {
      when(
        () => remoteDataSource.getCurrentUser(),
      ).thenAnswer((_) async => null);
      when(
        () => localDataSource.getCachedUser(),
      ).thenAnswer((_) async => cachedUser);

      final result = await repository.getCurrentUser();

      expect(result?.id, 'user-1');
      verify(() => localDataSource.getCachedUser()).called(1);
    },
  );

  test('signOut clears local cache after remote signOut', () async {
    when(() => remoteDataSource.signOut()).thenAnswer((_) async {});
    when(() => localDataSource.clearCachedUser()).thenAnswer((_) async {});

    await repository.signOut();

    verifyInOrder([
      () => remoteDataSource.signOut(),
      () => localDataSource.clearCachedUser(),
    ]);
  });

  test('authStateChanges caches remote user and maps to entity', () async {
    when(() => remoteDataSource.authStateChanges()).thenAnswer((_) {
      return Stream<AuthUserModel?>.value(cachedUser);
    });
    when(() => localDataSource.cacheUser(cachedUser)).thenAnswer((_) async {});

    final emitted = await repository.authStateChanges().first;

    expect(emitted?.id, cachedUser.id);
    verify(() => localDataSource.cacheUser(cachedUser)).called(1);
  });
}
