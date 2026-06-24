// test/features/session/presentation/lobby_waiting_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/lobby_waiting_view.dart';

void main() {
  testWidgets('LobbyWaitingView shows title and subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LobbyWaitingView(
          title: 'Waiting for host to finish the plan',
          subtitle: 'They are still building it',
        ),
      ),
    ));
    expect(find.text('Waiting for host to finish the plan'), findsOneWidget);
    expect(find.text('They are still building it'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
