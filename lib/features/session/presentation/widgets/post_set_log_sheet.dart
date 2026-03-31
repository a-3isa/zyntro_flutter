import 'package:flutter/material.dart';

Future<({int reps, double? weight})?> showPostSetLogSheet(
  BuildContext context, {
  required String exerciseName,
  required int setNumber,
}) {
  final repsController = TextEditingController();
  final weightController = TextEditingController();

  return showModalBottomSheet<({int reps, double? weight})>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log $exerciseName',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Set $setNumber is done. Add the result now.',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight (optional)',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final reps = int.tryParse(repsController.text.trim());
                final rawWeight = weightController.text.trim();
                final weight = rawWeight.isEmpty
                    ? null
                    : double.tryParse(rawWeight);

                if (reps == null || reps <= 0) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid reps value to save the set.'),
                    ),
                  );
                  return;
                }

                if (rawWeight.isNotEmpty && weight == null) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid weight or leave it empty.'),
                    ),
                  );
                  return;
                }

                Navigator.of(sheetContext).pop((reps: reps, weight: weight));
              },
              child: const Text('Save Set'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(() {
    repsController.dispose();
    weightController.dispose();
  });
}
