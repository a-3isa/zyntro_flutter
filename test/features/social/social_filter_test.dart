import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/app/navigation/app_route_locations.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/user_profile_entity.dart';
import 'package:zyntro_flutter/features/social/presentation/providers/facebook_friends_provider.dart';

UserProfileEntity _friend(String id) => UserProfileEntity(
      id: id,
      displayName: id,
      photoUrl: null,
      isPrivate: false,
      workoutPreference: WorkoutType.gym,
      beginnerFlag: false,
    );

void main() {
  test('SocialTab defaults unknown values to board', () {
    expect(SocialTab.fromString(null), SocialTab.board);
    expect(SocialTab.fromString('nope'), SocialTab.board);
    expect(SocialTab.fromString('find'), SocialTab.find);
    expect(SocialTab.values.map((t) => t.value).toList(), [
      'board',
      'buddies',
      'find',
    ]);
  });

  test('facebook friends filter drops self and already-followed (Z-TEST-002)',
      () {
    final result = filterUnfollowedFacebookFriends(
      friends: [_friend('self'), _friend('buddy'), _friend('stranger')],
      followingIds: {'buddy'},
      selfId: 'self',
    );

    expect(result.map((u) => u.id), ['stranger']);
  });
}
