import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/partner_left_dialog.dart';

/// A partner leaving must never end this member's workout for them. The dialog
/// informs and offers; it never decides.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onFinishToo,
    required VoidCallback onCarryOn,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerLeftDialog(
            partnerName: 'Sara',
            onFinishToo: onFinishToo,
            onCarryOn: onCarryOn,
          ),
        ),
      ),
    );
  }

  group('the dialog', () {
    testWidgets('names the partner who left', (tester) async {
      await pump(tester, onFinishToo: () {}, onCarryOn: () {});

      expect(find.text('Sara left the session'), findsOneWidget);
    });

    testWidgets('offers both finishing and carrying on', (tester) async {
      await pump(tester, onFinishToo: () {}, onCarryOn: () {});

      expect(find.byKey(const Key('partner_left_finish_too')), findsOneWidget);
      expect(find.byKey(const Key('partner_left_carry_on')), findsOneWidget);
    });

    testWidgets('carrying on does not end the session', (tester) async {
      var carriedOn = false;
      await pump(
        tester,
        onFinishToo: () => fail('carrying on must not end the session'),
        onCarryOn: () => carriedOn = true,
      );

      await tester.tap(find.byKey(const Key('partner_left_carry_on')));
      await tester.pump();

      expect(carriedOn, isTrue);
    });

    testWidgets('finishing too is an explicit choice', (tester) async {
      var finished = false;
      await pump(
        tester,
        onFinishToo: () => finished = true,
        onCarryOn: () => fail('must not carry on'),
      );

      await tester.tap(find.byKey(const Key('partner_left_finish_too')));
      await tester.pump();

      expect(finished, isTrue);
    });
  });

  group('dismissing', () {
    testWidgets('is treated as carrying on, never as finishing', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final result = PartnerLeftDialog.show(ctx, partnerName: 'Sara');
      await tester.pumpAndSettle();

      // Tap the barrier — the "I did not answer" path. If this ever resolved to
      // finishToo, closing a dialog would silently end a live workout.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await result, PartnerLeftChoice.carryOn);
    });
  });

  group('AnnouncedDepartures — once per departure', () {
    test('announces a departure the first time', () {
      final announced = AnnouncedDepartures();

      expect(announced.takeUnannounced(['bob']), ['bob']);
    });

    test('never announces the same departure twice', () {
      // The session document is streamed, so endedParticipants re-emits on
      // every snapshot. Without this the dialog would reappear on every
      // rebuild.
      final announced = AnnouncedDepartures();
      announced.takeUnannounced(['bob']);

      expect(announced.takeUnannounced(['bob']), isEmpty);
      expect(announced.takeUnannounced(['bob']), isEmpty);
    });

    test('announces a second partner leaving separately', () {
      final announced = AnnouncedDepartures();
      announced.takeUnannounced(['bob']);

      expect(announced.takeUnannounced(['bob', 'carol']), ['carol']);
    });

    test('markSeen suppresses departures that happened while away', () {
      // Opening a session where a partner had already left should not raise a
      // dialog about it — the avatar already shows it.
      final announced = AnnouncedDepartures();
      announced.markSeen(['bob']);

      expect(announced.takeUnannounced(['bob']), isEmpty);
      expect(announced.hasAnnounced('bob'), isTrue);
    });

    test('survives repeated empty emissions', () {
      final announced = AnnouncedDepartures();

      for (var i = 0; i < 5; i++) {
        expect(announced.takeUnannounced(const []), isEmpty);
      }
      expect(announced.takeUnannounced(['bob']), ['bob']);
    });
  });
}
