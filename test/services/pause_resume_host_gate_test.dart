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

  Future<void> seedSession({required String status}) async {
    await firestore.collection('sessions').doc('s1').set({
      'type': 'gym',
      'title': 'Gym',
      'hostId': 'host',
      'participants': ['host', 'partner'],
      'participantTypes': {'host': 'gym', 'partner': 'gym'},
      'status': status,
      'phase': 'live',
      'activeUserId': 'host',
      'createdAt': DateTime(2026),
      'startedAt': DateTime(2026),
    });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [
        userCacheServiceProvider.overrideWithValue(_MockUserCache()),
        notificationServiceProvider.overrideWithValue(_MockNotifications()),
        sessionAnalyticsServiceProvider.overrideWithValue(_MockAnalytics()),
      ],
    );
    service = SessionService(firestore, container.read(_refProvider));
  });

  tearDown(() => container.dispose());

  test('pauseSession allows host and writes paused (Z-RT-005)', () async {
    await seedSession(status: 'active');
    await service.pauseSession('s1', 'host');
    final data = (await firestore.collection('sessions').doc('s1').get()).data();
    expect(data?['status'], 'paused');
  });

  test('pauseSession rejects non-host (Z-RT-005)', () async {
    await seedSession(status: 'active');
    await expectLater(
      () => service.pauseSession('s1', 'partner'),
      throwsA(isA<StateError>()),
    );
    final data = (await firestore.collection('sessions').doc('s1').get()).data();
    expect(data?['status'], 'active');
  });

  test('resumeSession allows host and writes active (Z-RT-005)', () async {
    await seedSession(status: 'paused');
    await service.resumeSession('s1', 'host');
    final data = (await firestore.collection('sessions').doc('s1').get()).data();
    expect(data?['status'], 'active');
  });

  test('resumeSession rejects non-host (Z-RT-005)', () async {
    await seedSession(status: 'paused');
    await expectLater(
      () => service.resumeSession('s1', 'partner'),
      throwsA(isA<StateError>()),
    );
    final data = (await firestore.collection('sessions').doc('s1').get()).data();
    expect(data?['status'], 'paused');
  });
}
