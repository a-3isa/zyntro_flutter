import 'package:flutter/material.dart';

/// Asks the user to open settings when mic permission is denied (Z-ARCH-002).
Future<bool?> showMicrophonePermissionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Microphone Permission Required'),
      content: const Text(
        'Voice notes require microphone access. Would you like to open settings to grant permission?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}
