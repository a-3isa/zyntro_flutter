import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:zyntro_flutter/features/auth/data/models/auth_user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('auth cache omits email and photo URL (Z-AUTH-005)', () async {
    const user = AuthUserModel(
      id: 'u1',
      email: 'secret@example.com',
      displayName: 'Athlete',
      photoUrl: 'https://cdn.example/photo.jpg',
      emailVerified: true,
      providerIds: ['password'],
    );

    final local = const AuthLocalDataSource();
    await local.cacheUser(user);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('auth.cached_user')!;
    expect(raw, isNot(contains('secret@example.com')));
    expect(raw, isNot(contains('cdn.example')));
    expect(raw, contains('u1'));
    expect(raw, contains('Athlete'));

    final loaded = await local.getCachedUser();
    expect(loaded?.id, 'u1');
    expect(loaded?.email, isNull);
    expect(loaded?.photoUrl, isNull);
    expect(loaded?.displayName, 'Athlete');
    expect(loaded?.emailVerified, isTrue);
  });
}
