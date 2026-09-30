import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/resume_session_prompt.dart';

/// The prompt exists because dropping someone straight into a workout that has
/// been idle for an hour reads as being dragged somewhere. So it has to ask —
/// and, just as importantly, it has to take "no answer" for an answer.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onContinue,
    required VoidCallback onDiscard,
    required VoidCallback onDismiss,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResumeSessionPrompt(
            onContinue: onContinue,
            onDiscard: onDiscard,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );
  }

  testWidgets('offers continue, finish and neither', (tester) async {
    await pump(
      tester,
      onContinue: () {},
      onDiscard: () {},
      onDismiss: () {},
    );

    expect(find.byKey(const Key('resume_prompt_title')), findsOneWidget);
    expect(find.byKey(const Key('resume_prompt_continue')), findsOneWidget);
    expect(find.byKey(const Key('resume_prompt_discard')), findsOneWidget);
    expect(find.byKey(const Key('resume_prompt_dismiss')), findsOneWidget);
  });

  testWidgets('continuing goes back into the session', (tester) async {
    var continued = false;
    await pump(
      tester,
      onContinue: () => continued = true,
      onDiscard: () => fail('must not discard'),
      onDismiss: () => fail('must not dismiss'),
    );

    await tester.tap(find.byKey(const Key('resume_prompt_continue')));
    await tester.pump();

    expect(continued, isTrue);
  });

  testWidgets('finishing ends only this member\'s part', (tester) async {
    var discarded = false;
    await pump(
      tester,
      onContinue: () => fail('must not resume'),
      onDiscard: () => discarded = true,
      onDismiss: () => fail('must not dismiss'),
    );

    await tester.tap(find.byKey(const Key('resume_prompt_discard')));
    await tester.pump();

    expect(discarded, isTrue);
  });

  testWidgets('ignoring it is a valid answer and touches nothing', (
    tester,
  ) async {
    var dismissed = false;
    await pump(
      tester,
      onContinue: () => fail('ignoring must not resume'),
      onDiscard: () => fail('ignoring must never end the session'),
      onDismiss: () => dismissed = true,
    );

    await tester.tap(find.byKey(const Key('resume_prompt_dismiss')));
    await tester.pump();

    expect(dismissed, isTrue);
  });

  testWidgets('choosing nothing is distinguishable from choosing', (
    tester,
  ) async {
    // The sheet returns null when dismissed, so a caller cannot mistake
    // "walked away" for "finish it" and quietly end a live workout.
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

    final result = ResumeSessionPrompt.show(ctx);
    await tester.pumpAndSettle();

    // Tap outside the sheet — the "I did not choose" path.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });

  testWidgets('the sheet reports which choice was made', (tester) async {
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

    final result = ResumeSessionPrompt.show(ctx);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('resume_prompt_continue')));
    await tester.pumpAndSettle();

    expect(await result, ResumePromptChoice.resume);
  });
}
