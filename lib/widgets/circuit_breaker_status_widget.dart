import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/retry_helper.dart';

class CircuitBreakerStatusWidget extends StatefulWidget {
  const CircuitBreakerStatusWidget({super.key});

  @override
  State<CircuitBreakerStatusWidget> createState() =>
      _CircuitBreakerStatusWidgetState();
}

class _CircuitBreakerStatusWidgetState
    extends State<CircuitBreakerStatusWidget> {
  Timer? _timer;
  Map<String, Map<String, dynamic>> _metrics = {};

  @override
  void initState() {
    super.initState();
    _refreshMetrics();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshMetrics();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshMetrics() {
    if (mounted) {
      setState(() {
        _metrics = getCircuitBreakerMetrics();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_metrics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No active circuit breakers'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _metrics.length,
      itemBuilder: (context, index) {
        final key = _metrics.keys.elementAt(index);
        final data = _metrics[key]!;
        final state = data['state'] as String;
        final failures = data['failureCount'] as int;
        final successes = data['successCount'] as int;
        final openCount = data['circuitOpenCount'] as int;

        Color stateColor;
        IconData stateIcon;

        switch (state) {
          case 'closed':
            stateColor = Colors.green;
            stateIcon = Icons.check_circle_outline;
            break;
          case 'open':
            stateColor = Colors.red;
            stateIcon = Icons.error_outline;
            break;
          case 'halfOpen':
            stateColor = Colors.orange;
            stateIcon = Icons.warning_amber_rounded;
            break;
          default:
            stateColor = Colors.grey;
            stateIcon = Icons.help_outline;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: Icon(stateIcon, color: stateColor),
            title: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('State: $state'),
                Text('Failures: $failures | Successes: $successes'),
                Text('Times Opened: $openCount'),
              ],
            ),
            trailing: state == 'open'
                ? TextButton(
                    onPressed: () {
                      // We might want to expose a reset for specific CB
                      // For now, reset all is the only public method easily accessible
                      // Or we add a specific reset to retry_helper
                      // resetCircuitBreaker(key);
                    },
                    child: const Text('RESET'),
                  )
                : null,
          ),
        );
      },
    );
  }
}
