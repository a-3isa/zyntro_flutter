import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/notifications/presentation/notification_preferences_page.dart';
import 'package:zyntro_flutter/services/notification_service.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
  });

  testWidgets('loads saved preferences and persists updates', (tester) async {
    final notificationService = MockNotificationService();
    const user = AuthUserEntity(
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Test User',
      photoUrl: null,
      emailVerified: true,
      providerIds: ['password'],
    );
    const initialPreferences = NotificationPreferences(
      sessionInvites: false,
      voiceNotes: true,
      followRequests: true,
      followAccepted: true,
      buddyInvites: true,
      postLikes: true,
      postComments: true,
      sessionMilestones: true,
      streakNotifications: true,
      pushEnabled: true,
    );

    when(
      () => notificationService.getNotificationPreferences(user.id),
    ).thenAnswer((_) async => initialPreferences);
    when(
      () => notificationService.updateNotificationPreferences(any(), any()),
    ).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
        authSessionProvider.overrideWithValue(const AsyncValue.data(user)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationPreferencesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('Session Invites'), findsOneWidget);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.first.value, isTrue);
    expect(switches[1].value, isFalse);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => notificationService.updateNotificationPreferences(
                user.id,
                captureAny(),
              ),
            ).captured.single
            as NotificationPreferences;

    expect(captured.pushEnabled, isFalse);
    expect(captured.sessionInvites, isFalse);
  });
}
