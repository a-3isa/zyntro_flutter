import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/domain/turn_eligibility.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/participant_avatar.dart';

/// Away and left must never look alike. One partner stepped out and is coming
/// back; the other has finished. Rendering them the same tells the member the
/// wrong thing about their own workout.
void main() {
  Future<void> pump(WidgetTester tester, ParticipantStanding standing) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParticipantAvatar(name: 'Sara', standing: standing),
        ),
      ),
    );
  }

  testWidgets('a present partner gets no badge at all', (tester) async {
    await pump(tester, ParticipantStanding.active);

    expect(find.byKey(const Key('participant_away_badge')), findsNothing);
    expect(find.byKey(const Key('participant_left_badge')), findsNothing);
  });

  testWidgets('an away partner is badged as away, not as left', (tester) async {
    await pump(tester, ParticipantStanding.away);

    expect(find.byKey(const Key('participant_away_badge')), findsOneWidget);
    expect(find.byKey(const Key('participant_left_badge')), findsNothing);
  });

  testWidgets('a departed partner is badged as left, not as away', (
    tester,
  ) async {
    await pump(tester, ParticipantStanding.left);

    expect(find.byKey(const Key('participant_left_badge')), findsOneWidget);
    expect(find.byKey(const Key('participant_away_badge')), findsNothing);
  });

  testWidgets('the avatar stays visible in every state', (tester) async {
    // Dimmed, never removed — the member should still see who they started
    // with.
    for (final standing in ParticipantStanding.values) {
      await pump(tester, standing);
      expect(find.byType(CircleAvatar), findsOneWidget);
    }
  });

  testWidgets('left is rendered more faintly than away', (tester) async {
    await pump(tester, ParticipantStanding.away);
    final awayOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

    await pump(tester, ParticipantStanding.left);
    final leftOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

    expect(leftOpacity, lessThan(awayOpacity));
  });

  testWidgets('the distinction is announced, not only drawn', (tester) async {
    // Opacity alone is not a distinction anyone can rely on.
    String labelFor(WidgetTester t) => t
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .whereType<String>()
        .firstWhere((l) => l.contains('Sara'));

    await pump(tester, ParticipantStanding.left);
    expect(labelFor(tester), 'Sara has left the session');

    await pump(tester, ParticipantStanding.away);
    expect(labelFor(tester), 'Sara is away');
  });

  testWidgets('falls back to an initial when there is no photo', (
    tester,
  ) async {
    await pump(tester, ParticipantStanding.active);
    expect(find.text('S'), findsOneWidget);
  });
}
