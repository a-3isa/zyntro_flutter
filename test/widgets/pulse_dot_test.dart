import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/widgets/pulse_dot.dart';

void main() {
  testWidgets('PulseDot renders without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PulseDot()),
        ),
      ),
    );
    expect(find.byType(PulseDot), findsOneWidget);
  });

  testWidgets('PulseDot accepts custom color and size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PulseDot(color: Colors.red, size: 12),
          ),
        ),
      ),
    );
    expect(find.byType(PulseDot), findsOneWidget);
  });
}
