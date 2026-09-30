import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/voice_recording_service.dart';

/// The `record` plugin talks to a platform channel from the AudioRecorder
/// constructor onward, so the service cannot even be built without one. This
/// answers every call with a benign default so the Dart-side state machine can
/// be exercised.
const _recordChannel = MethodChannel('com.llfbandit.record/messages');

void _stubRecorderChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_recordChannel, (call) async {
    switch (call.method) {
      case 'hasPermission':
      case 'isRecording':
      case 'isPaused':
        return false;
      case 'getAmplitude':
        return {'current': -60.0, 'max': -60.0};
      default:
        return null;
    }
  });
}

void _clearRecorderChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_recordChannel, null);
}

/// Only the state surface is exercised here.
///
/// start/stop/pause/resume all drive the `record` plugin, which needs a real
/// platform channel and a microphone, so they cannot run in a unit test. What
/// is testable is the state machine's starting position and the guards that
/// stop a transition being attempted from the wrong state — which is where a
/// bug would strand the UI showing a recording that is not running.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VoiceRecordingService service;

  // Stubbed once for the file: dispose() is async, so clearing the handler in
  // tearDown pulled the channel out from under an in-flight call.
  setUpAll(_stubRecorderChannel);
  tearDownAll(_clearRecorderChannel);

  setUp(() {
    service = VoiceRecordingService();
  });

  tearDown(() => service.dispose());

  group('initial state', () {
    test('starts idle', () {
      expect(service.state, RecordingState.idle);
    });

    test('is not recording', () {
      expect(service.isRecording, isFalse);
    });

    test('has no file path yet', () {
      expect(service.currentPath, isNull);
    });
  });

  group('maxRecordingDuration', () {
    test('caps a voice note at one minute', () {
      expect(VoiceRecordingService.maxRecordingDuration,
          const Duration(seconds: 60));
    });

    test('is positive, so the auto-stop timer can never fire immediately', () {
      expect(
        VoiceRecordingService.maxRecordingDuration.inMilliseconds,
        greaterThan(0),
      );
    });
  });

  group('transitions guard against the wrong state', () {
    test('pausing while idle is a no-op rather than an error', () async {
      await expectLater(service.pauseRecording(), completes);
      expect(service.state, RecordingState.idle);
    });

    test('resuming while idle is a no-op rather than an error', () async {
      await expectLater(service.resumeRecording(), completes);
      expect(service.state, RecordingState.idle);
    });

    test('cancelling while idle is a no-op rather than an error', () async {
      await expectLater(service.cancelRecording(), completes);
      expect(service.state, RecordingState.idle);
      expect(service.currentPath, isNull);
    });
  });

  group('durationStream', () {
    test('is a broadcast stream, so several widgets can listen', () {
      expect(service.durationStream.isBroadcast, isTrue);
    });

    test('supports a second listener without throwing', () {
      final a = service.durationStream.listen((_) {});
      final b = service.durationStream.listen((_) {});

      addTearDown(() {
        a.cancel();
        b.cancel();
      });

      expect(a, isNotNull);
      expect(b, isNotNull);
    });
  });

  group('dispose', () {
    test('is safe to call on a service that never recorded', () {
      final fresh = VoiceRecordingService();

      expect(fresh.dispose, returnsNormally);
    });
  });
}
