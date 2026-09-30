import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/notification_service.dart';
import 'package:zyntro_flutter/services/session_analytics_service.dart';
import 'package:zyntro_flutter/services/session_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';

class _MockUserCache extends Mock implements UserCacheService {}

class _MockNotifications extends Mock implements NotificationService {}

class _MockAnalytics extends Mock implements SessionAnalyticsService {}

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeFirebaseFirestore firestore;
  late SessionService service;
  late ProviderContainer container;
  late _MockUserCache userCache;
  late _MockNotifications notifications;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    userCache = _MockUserCache();
    notifications = _MockNotifications();
    container = ProviderContainer(
      overrides: [
        userCacheServiceProvider.overrideWithValue(userCache),
        notificationServiceProvider.overrideWithValue(notifications),
        sessionAnalyticsServiceProvider.overrideWithValue(_MockAnalytics()),
      ],
    );
    service = SessionService(firestore, container.read(_refProvider));

    when(() => userCache.getUser(any())).thenAnswer(
      (inv) async => User(
        id: inv.positionalArguments.first as String,
        displayName: 'Partner',
        isPrivate: false,
        workoutPreference: WorkoutType.gym,
        beginnerFlag: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => notifications.notifyTurnChange(
        recipientId: any(named: 'recipientId'),
        sessionId: any(named: 'sessionId'),
        sessionType: any(named: 'sessionType'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() => container.dispose());

  test('switchTurn transactionally advances activeUserId (Z-RT-002)', () async {
    const sessionId = 's1';
    await firestore.collection('sessions').doc(sessionId).set({
      'type': 'gym',
      'title': 'Gym',
      'hostId': 'u1',
      'participants': ['u1', 'u2'],
      'participantTypes': {'u1': 'gym', 'u2': 'gym'},
      'status': 'active',
      'phase': 'live',
      'activeUserId': 'u1',
      'createdAt': DateTime(2026),
      'startedAt': DateTime(2026),
    });

    await service.switchTurn(sessionId, 'u1');

    final data = (await firestore.collection('sessions').doc(sessionId).get())
        .data()!;
    expect(data['activeUserId'], 'u2');
  });

  test('switchTurn no-ops when caller is not the active holder', () async {
    const sessionId = 's2';
    await firestore.collection('sessions').doc(sessionId).set({
      'type': 'gym',
      'title': 'Gym',
      'hostId': 'u1',
      'participants': ['u1', 'u2'],
      'participantTypes': {'u1': 'gym', 'u2': 'gym'},
      'status': 'active',
      'phase': 'live',
      'activeUserId': 'u2',
      'createdAt': DateTime(2026),
      'startedAt': DateTime(2026),
    });

    await service.switchTurn(sessionId, 'u1');

    final data = (await firestore.collection('sessions').doc(sessionId).get())
        .data()!;
    expect(data['activeUserId'], 'u2');
  });
}
