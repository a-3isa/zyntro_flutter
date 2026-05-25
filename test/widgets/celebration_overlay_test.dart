import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/widgets/celebration_overlay.dart';

void main() {
  testWidgets('CelebrationOverlay renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CelebrationOverlay(
            title: '7-Day Streak!',
            subtitle: 'You worked out every day this week',
            emoji: '🔥',
            onDismiss: () {},
          ),
        ),
      ),
    );
    // pump a frame for the animation to start
    await tester.pump();
    expect(find.text('7-Day Streak!'), findsOneWidget);
    expect(find.text('You worked out every day this week'), findsOneWidget);
  });
}
