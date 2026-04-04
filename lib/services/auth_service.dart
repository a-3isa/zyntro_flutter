export '../features/auth/auth_providers.dart' show authFirestoreProvider;

import '../features/auth/auth_providers.dart';
import '../features/auth/domain/entities/auth_user_entity.dart';

/// Temporary compatibility bridge while session flows migrate to the new
/// auth providers.
final authStateProvider = authSessionProvider;

extension LegacyAuthUserEntityCompat on AuthUserEntity {
  String get uid => id;
}
