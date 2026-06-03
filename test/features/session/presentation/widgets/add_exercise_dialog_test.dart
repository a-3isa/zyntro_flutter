import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/add_exercise_dialog.dart';

void main() {
  testWidgets('returns exercise details without controller disposal errors', (
    tester,
  ) async {
    AddExerciseDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<AddExerciseDialogResult>(
                    context: context,
                    builder: (_) => const AddExerciseDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Incline Press');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(result?.name, 'Incline Press');
    expect(result?.sets, 1);
    expect(tester.takeException(), isNull);
  });
}
