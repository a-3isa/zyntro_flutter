import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/utils/animation_utils.dart';
import 'package:zyntro_flutter/widgets/premium_effects.dart';

void main() {
  testWidgets('PulsingGlow honors reduce motion (Z-UI-001)', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(
            body: PulsingGlow(
              glowColor: Colors.orange,
              minRadius: 4,
              maxRadius: 16,
              child: Text('static'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.text('static'));
    expect(PerformanceMonitor.shouldReduceMotion(context), isTrue);
    expect(find.text('static'), findsOneWidget);

    // No continuous glow rebuild churn: pumping time must not throw.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PulsingGlow animates when reduce motion is off', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: const MaterialApp(
          home: Scaffold(
            body: PulsingGlow(
              glowColor: Colors.orange,
              minRadius: 4,
              maxRadius: 16,
              child: Text('pulse'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(PerformanceMonitor.shouldReduceMotion(tester.element(find.text('pulse'))), isFalse);
    expect(find.text('pulse'), findsOneWidget);
  });
}
