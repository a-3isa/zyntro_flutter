import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Confirm end-session dialog (Z-ARCH-002).
class SessionEndConfirmDialog extends StatelessWidget {
  const SessionEndConfirmDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const SessionEndConfirmDialog(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End Session?'),
      content: const Text('Are you sure you want to finish this workout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.signal,
            foregroundColor: Colors.black,
          ),
          child: const Text('Finish'),
        ),
      ],
    );
  }
}
