import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

/// First golden lock for brand signal (Z-TEST-005). Expand suite later.
void main() {
  testWidgets('signal chip matches golden', (tester) async {
    const chipKey = Key('signal_chip');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ColoredBox(
              key: chipKey,
              color: AppColors.signal,
              child: SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(chipKey),
      matchesGoldenFile('signal_chip.png'),
    );
  });
}
