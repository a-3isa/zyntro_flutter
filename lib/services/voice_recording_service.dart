import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// Voice recording state.
enum RecordingState { idle, recording, paused, stopped }

/// Voice recording service for session voice notes.
/// Uses the record package for cross-platform audio recording.
class VoiceRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  RecordingState _state = RecordingState.idle;
  String? _currentPath;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // Timer for max duration (60s limit)
  Timer? _limitTimer;
  Timer? _durationTimer;
  final _durationController = StreamController<Duration>.broadcast();
  Duration _currentDuration = Duration.zero;

  static const Duration maxRecordingDuration = Duration(seconds: 60);

  /// Current recording state.
  RecordingState get state => _state;

  /// Current recording file path.
  String? get currentPath => _currentPath;

  /// Check if recording is in progress.
  bool get isRecording => _state == RecordingState.recording;

  /// Stream of current recording duration.
  Stream<Duration> get durationStream => _durationController.stream;

  /// Request microphone permissions.
  Future<bool> requestPermissions() async {
    return await _recorder.hasPermission();
  }

  /// Check if microphone permissions are granted.
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Get the temporary directory for recordings.
  Future<String> _getTempPath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/voice_note_$timestamp.m4a';
  }

  /// Start recording audio.
  /// Automatically stops after [maxRecordingDuration].
  Future<String?> startRecording({String? customPath}) async {
    if (_state == RecordingState.recording) {
      debugPrint('[VoiceRecordingService] Already recording');
      return null;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint('[VoiceRecordingService] No permission to record');
      return null;
    }

    try {
      _currentPath = customPath ?? await _getTempPath();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );

      _state = RecordingState.recording;
      _currentDuration = Duration.zero;
      _durationController.add(Duration.zero);
      debugPrint('[VoiceRecordingService] Recording started: $_currentPath');

      // Start timers
      _startTimers();

      return _currentPath;
    } catch (e) {
      debugPrint('[VoiceRecordingService] Error starting recording: $e');
      _state = RecordingState.idle;
      return null;
    }
  }

  void _startTimers() {
    _limitTimer?.cancel();
    _durationTimer?.cancel();

    // Auto-stop limit
    _limitTimer = Timer(maxRecordingDuration, () {
      debugPrint('[VoiceRecordingService] Max duration reached');
      stopRecording(); // This returns a Future, but we can't await it in Timer callback easily without fire & forget
    });

    // Duration ticker
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_state == RecordingState.recording) {
        _currentDuration += const Duration(milliseconds: 100);
        _durationController.add(_currentDuration);
      }
    });
  }

  void _stopTimers() {
    _limitTimer?.cancel();
    _durationTimer?.cancel();
    _limitTimer = null;
    _durationTimer = null;
  }

  /// Stop recording and return the file path.
  Future<String?> stopRecording() async {
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      debugPrint('[VoiceRecordingService] Not recording');
      return null;
    }

    _stopTimers();

    try {
      final path = await _recorder.stop();
      _state = RecordingState.stopped;

      if (path != null) {
        debugPrint('[VoiceRecordingService] Recording stopped: $path');

        // Verify file exists
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint(
            '[VoiceRecordingService] Recording size: ${size / 1024} KB',
          );
          return path;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[VoiceRecordingService] Error stopping recording: $e');
      _state = RecordingState.idle;
      return null;
    }
  }

  /// Cancel recording and delete the file.
  Future<void> cancelRecording() async {
    _stopTimers();
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      return;
    }

    try {
      await _recorder.stop();

      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[VoiceRecordingService] Error cancelling recording: $e');
    } finally {
      _state = RecordingState.idle;
      _currentPath = null;
      _currentDuration = Duration.zero;
      _durationController.add(Duration.zero);
    }
  }

  /// Pause recording.
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) return;

    try {
      await _recorder.pause();
      _state = RecordingState.paused;
      _durationTimer?.cancel(); // Pause timer
      _limitTimer
          ?.cancel(); // Pause limit check (re-schedule remaining on resume?)
      // For simplicity, just cancel limit and assume resume handles it or restart logic if complex.
      // Actually simpler: Max duration is usually continuous recording time.
      // If paused, we pause ticker. Limit might need to be adjusted.
      // Current implementation simply cancels.
      debugPrint('[VoiceRecordingService] Recording paused');
    } catch (e) {
      debugPrint('[VoiceRecordingService] Error pausing recording: $e');
    }
  }

  /// Resume recording.
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) return;

    try {
      await _recorder.resume();
      _state = RecordingState.recording;

      // Resume timers
      final remaining = maxRecordingDuration - _currentDuration;
      if (remaining.inMilliseconds > 0) {
        _limitTimer = Timer(remaining, () => stopRecording());
        _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          _currentDuration += const Duration(milliseconds: 100);
          _durationController.add(_currentDuration);
        });
      }

      debugPrint('[VoiceRecordingService] Recording resumed');
    } catch (e) {
      debugPrint('[VoiceRecordingService] Error resuming recording: $e');
    }
  }

  /// Stream of amplitude values for visualization.
  /// Values are normalized between 0.0 and 1.0.
  Stream<double> get amplitudeStream {
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).map((
      amp,
    ) {
      // Normalize dB values to 0-1 range
      // Typical range: -160 dB (silence) to 0 dB (max)
      // Boost sensitivity: use -60dB as floor
      final normalized = (amp.current + 60) / 60;
      return normalized.clamp(0.0, 1.0);
    });
  }

  /// Get current amplitude (for single reads).
  Future<double> getAmplitude() async {
    try {
      final amp = await _recorder.getAmplitude();
      final normalized = (amp.current + 60) / 60;
      return normalized.clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  /// Dispose resources.
  Future<void> dispose() async {
    _stopTimers();
    await _durationController.close();
    await _amplitudeSubscription?.cancel();
    await _recorder.dispose();
  }
}

/// Voice recording service provider.
final voiceRecordingServiceProvider = Provider<VoiceRecordingService>((ref) {
  final service = VoiceRecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Recording state provider.
final recordingStateProvider = StateProvider<RecordingState>((ref) {
  return RecordingState.idle;
});
