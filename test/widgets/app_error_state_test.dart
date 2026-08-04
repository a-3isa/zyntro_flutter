import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/widgets/app_empty_state.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AppErrorState', () {
    testWidgets('shows the title and a default recovery hint', (tester) async {
      await tester.pumpWidget(
        _host(const AppErrorState(title: 'Couldn\'t load posts', animate: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Couldn\'t load posts'), findsOneWidget);
      expect(find.textContaining('try again'), findsOneWidget);
    });

    testWidgets('offers retry and calls back when tapped', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          AppErrorState(
            title: 'Nope',
            onRetry: () => retries++,
            animate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(retries, 1);
    });

    testWidgets('hides the retry button when no callback is given', (tester) async {
      await tester.pumpWidget(
        _host(const AppErrorState(title: 'Nope', animate: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('uses a custom message when supplied', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppErrorState(
            title: 'Nope',
            message: 'The moderation queue is unavailable.',
            animate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The moderation queue is unavailable.'), findsOneWidget);
    });
  });

  group('raw exceptions never reach the user', () {
    testWidgets('the widget renders no exception text of its own', (tester) async {
      // The whole point of this widget: screens used to render
      // Center(child: Text('Error: $e')), which showed the raw exception —
      // unreadable, and able to leak internal detail.
      await tester.pumpWidget(
        _host(
          const AppErrorState(title: 'Couldn\'t load history', animate: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Error:'), findsNothing);
    });
  });
}
