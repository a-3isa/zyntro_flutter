import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for handling persistent local data.
/// Service for handling persistent local data and voice note uploads.
class StorageService {
  late SharedPreferences _prefs;
  final FirebaseStorage _storage;

  StorageService(this._storage);

  /// Initialize the service.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if user has seen onboarding.
  bool get hasSeenOnboarding => _prefs.getBool('has_seen_onboarding') ?? false;

  /// Set has seen onboarding flag.
  Future<void> setHasSeenOnboarding(bool value) async {
    await _prefs.setBool('has_seen_onboarding', value);
  }

  /// Get stored workout preference.
  String? get workoutPreference => _prefs.getString('workout_preference');

  /// Set workout preference.
  Future<void> setWorkoutPreference(String value) async {
    await _prefs.setString('workout_preference', value);
  }

  /// Clear all data (useful for testing/logout).
  Future<void> clear() async {
    await _prefs.clear();
  }

  /// Upload a voice note for session.
  Future<String> uploadVoiceNote({
    required String filePath,
    required String sessionId,
    void Function(double)? onProgress,
  }) async {
    // Validate file extension
    final ext = filePath.split('.').last.toLowerCase();
    const allowedExtensions = ['m4a', 'aac', 'wav', 'mp3'];
    if (!allowedExtensions.contains(ext)) {
      throw Exception(
        'Invalid file type. Only M4A, AAC, WAV, and MP3 audio files are allowed.',
      );
    }

    final file = File(filePath);
    final length = await file.length();
    const maxVoiceNoteSize = 5 * 1024 * 1024; // 5MB

    if (length > maxVoiceNoteSize) {
      throw Exception(
        'Voice note exceeds maximum size of ${maxVoiceNoteSize ~/ (1024 * 1024)}MB',
      );
    }

    final filename =
        'voiceNotes/$sessionId/${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = _storage.ref(filename);

    onProgress?.call(0.1);

    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: 'audio/mp4'),
    );

    // The failure is surfaced by `await uploadTask` below. Without an onError
    // here the progress stream also emits it, and an unhandled stream error
    // crashes the isolate (e.g. a storage-rules 403 on the voice note).
    final progressSub = uploadTask.snapshotEvents.listen(
      (event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress?.call(0.1 + progress * 0.8);
      },
      onError: (Object error) {
        debugPrint('[StorageService] Voice note upload failed: $error');
      },
      cancelOnError: true,
    );

    try {
      await uploadTask;
    } finally {
      await progressSub.cancel();
    }
    onProgress?.call(1.0);

    return await storageRef.getDownloadURL();
  }
}

/// Provider for StorageService.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(FirebaseStorage.instance);
});
