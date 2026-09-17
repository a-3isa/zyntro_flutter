import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/ui/image_decode_budget.dart';

void main() {
  testWidgets('ImageDecodeBudget scales with device pixel ratio (Z-PERF-003)', (
    tester,
  ) async {
    late int? width;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2, size: Size(400, 800)),
        child: Builder(
          builder: (context) {
            width = ImageDecodeBudget.memCacheWidthFor(context, 200);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(width, 400);
  });
}
