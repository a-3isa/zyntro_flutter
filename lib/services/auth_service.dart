import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/domain/entities/auth_user_entity.dart';

/// Legacy compatibility surface for older session UI code.
///
/// The app-wide migration moved auth state into `authSessionProvider`, but
/// `SessionRoomPage` still imports the older service surface. Keep this bridge
/// thin so runtime behavior continues to flow from the current providers.
final authStateProvider = authSessionProvider;

/// Legacy Firestore alias retained for the session room page.
final firestoreProvider = authFirestoreProvider;

extension AuthUserEntityLegacyUid on AuthUserEntity {
  String get uid => id;
}
