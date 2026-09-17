import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/widgets/zyntro_back_button.dart';

void main() {
  testWidgets('back button meets 48px touch target', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ZyntroBackButton(),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ZyntroBackButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('back button pops the current route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: ZyntroBackButton(),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(ZyntroBackButton), findsOneWidget);

    await tester.tap(find.byType(ZyntroBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ZyntroBackButton), findsNothing);
  });
}
