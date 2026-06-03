import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/waiting_turn_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('shows active partner and waiting turn status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WaitingTurnScreen(
          partnerName: 'Mina',
          partnerCurrentExercise: 'Bench Press',
          partnerSetNumber: 2,
          partnerElapsedTime: const Duration(seconds: 42),
          isPartnerVoicePlaying: false,
          onRecordVoice: () async {},
          isRecording: false,
          recordingDuration: Duration.zero,
          activeStatusLabel: 'Mina is active',
          waitingStatusLabel: 'You are waiting',
        ),
      ),
    );

    expect(find.text('Mina is active'), findsOneWidget);
    expect(find.text('You are waiting'), findsOneWidget);
    expect(find.text('Bench Press - Set 2'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
  });

  testWidgets('voice button toggles recording on long press release', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WaitingTurnScreen(
          partnerName: 'Mina',
          partnerCurrentExercise: 'Bench Press',
          partnerSetNumber: 2,
          partnerElapsedTime: const Duration(seconds: 42),
          isPartnerVoicePlaying: false,
          onRecordVoice: () async => calls += 1,
          isRecording: false,
          recordingDuration: Duration.zero,
          activeStatusLabel: 'Mina is active',
          waitingStatusLabel: 'You are waiting',
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic_none_rounded)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, 1);

    await gesture.up();
    await tester.pump();
    expect(calls, 2);
  });
}
