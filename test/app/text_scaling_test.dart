import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/widgets/app_empty_state.dart';
import 'package:zyntro_flutter/widgets/zyntro_button.dart';

/// Renders [child] at [scale] on a small phone and fails on overflow.
///
/// Accessibility text sizes are a real setting with real adoption; a layout
/// that overflows at 2.0 is unusable for the people who need it most. These
/// use the smallest common phone width so the scale and the width squeeze
/// together, which is where overflow actually shows up.
Future<void> _pumpAtScale(
  WidgetTester tester,
  double scale,
  Widget child,
) async {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const scales = [1.0, 1.3, 1.5, 2.0];

  group('AppEmptyState survives large text', () {
    for (final scale in scales) {
      testWidgets('at ${scale}x', (tester) async {
        await _pumpAtScale(
          tester,
          scale,
          const AppEmptyState(
            icon: Icons.inbox,
            title: 'No posts yet',
            message: 'Finish a workout and share it to see it here.',
            actionLabel: 'Start a session',
            animate: false,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AppErrorState survives large text', () {
    for (final scale in scales) {
      testWidgets('at ${scale}x', (tester) async {
        await _pumpAtScale(
          tester,
          scale,
          AppErrorState(
            title: "Couldn't load the moderation queue",
            onRetry: () {},
            animate: false,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ZyntroButton survives large text', () {
    for (final scale in scales) {
      testWidgets('at ${scale}x', (tester) async {
        await _pumpAtScale(
          tester,
          scale,
          const SizedBox(
            width: 320,
            child: ZyntroButton(
              title: 'Continue to your session',
              fullWidth: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
