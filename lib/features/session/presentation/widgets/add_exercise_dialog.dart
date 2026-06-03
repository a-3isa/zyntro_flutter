import 'package:flutter/material.dart';

class AddExerciseDialogResult {
  final String name;
  final int sets;

  const AddExerciseDialogResult({required this.name, required this.sets});
}

class AddExerciseDialog extends StatefulWidget {
  const AddExerciseDialog({super.key});

  @override
  State<AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<AddExerciseDialog> {
  final _controller = TextEditingController();
  int _sets = 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, AddExerciseDialogResult(name: name, sets: _sets));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Exercise'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Exercise name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Sets')),
              IconButton(
                onPressed: _sets > 1 ? () => setState(() => _sets -= 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_sets'),
              IconButton(
                onPressed: () => setState(() => _sets += 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
