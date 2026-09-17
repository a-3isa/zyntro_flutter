import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/widgets/zyntro_button.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(AppColors.resetAccent);

  testWidgets('primary button uses brand signal, not the user accent',
      (tester) async {
    AppColors.setAccent(AppColors.accentPink);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZyntroButton(title: 'Sign in', onPressed: _noop),
        ),
      ),
    );

    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ZyntroButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.signal);
    expect(decoration.color, isNot(AppColors.userAccent));
  });

  testWidgets('primary button meets 44px touch target', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZyntroButton(
            title: 'Go',
            size: ZyntroButtonSize.sm,
            onPressed: _noop,
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ZyntroButton));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}

void _noop() {}
