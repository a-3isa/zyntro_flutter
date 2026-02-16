import 'package:flutter/material.dart';
import '../utils/global_error_handler.dart';

/// A widget that catches build errors in its subtree and displays a friendly error screen.
/// Designed to wrap the entire application or major features.
class ErrorBoundaryWidget extends StatefulWidget {
  final Widget child;

  const ErrorBoundaryWidget({super.key, required this.child});

  @override
  State<ErrorBoundaryWidget> createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget> {
  @override
  void initState() {
    super.initState();
    // Customize the global error widget for build phase errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Log the error through our global handler
      GlobalErrorHandler().handleError(
        details.exception,
        details.stack,
        fatal: true,
      );

      return Material(
        color: Colors.white, // Safe fallback
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Something Went Wrong',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We encountered an unexpected error. Please restart the app or try again later.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Attempt to re-render by doing nothing (hot reload)
                      // or navigate to home if possible in a real app context
                      // For now, we can only suggest restart or maybe try to rebuild
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload App'),
                  ),
                  if (details.exception.toString().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ExpansionTile(
                      title: const Text(
                        'Technical Details',
                        style: TextStyle(fontSize: 12),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.grey.shade100,
                          width: double.infinity,
                          child: Text(
                            details.exception.toString(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
