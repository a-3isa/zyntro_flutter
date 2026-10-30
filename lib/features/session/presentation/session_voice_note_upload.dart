import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/constants.dart';
import '../../../services/notification_service.dart';
import '../../../services/session_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/offline_manager.dart';

/// Uploads (or queues) a voice note and notifies partners (Z-ARCH-002).
Future<void> uploadOrQueueSessionVoiceNote({
  required String filePath,
  required String sessionId,
  required String userId,
  required double durationSeconds,
  required bool isOffline,
  required OfflineManager offlineManager,
  required StorageService storageService,
  required SessionService sessionService,
  required NotificationService notificationService,
  required Future<Map<String, dynamic>?> Function(String userId) loadUserData,
  required void Function(double progress) onUploadProgress,
  void Function(Object error)? onError,
}) async {
  if (isOffline) {
    await offlineManager.queueOperation('voice_note_upload', {
      'filePath': filePath,
      'sessionId': sessionId,
      'userId': userId,
      'duration': durationSeconds,
    });
    return;
  }

  final audioUrl = await storageService.uploadVoiceNote(
    filePath: filePath,
    sessionId: sessionId,
    onProgress: onUploadProgress,
  );

  try {
    await sessionService.addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType.voiceNote,
      userId: userId,
      text: 'sent a voice message',
      data: {'audioUrl': audioUrl, 'duration': durationSeconds},
    );
  } catch (e) {
    debugPrint('[SessionRoom] Error creating voice note event: $e');
    await offlineManager.queueOperation('session_event', {
      'sessionId': sessionId,
      'type': SessionEventType.voiceNote.value,
      'userId': userId,
      'text': 'sent a voice message',
      'data': {'audioUrl': audioUrl, 'duration': durationSeconds},
    });
  }

  final session = await sessionService.getSession(sessionId);
  if (session == null) return;

  final userData = await loadUserData(userId);
  final currentUserName = userData?['displayName'] ?? 'User';
  final recipients = session.participants.where((id) => id != userId);

  for (final recipientId in recipients) {
    unawaited(
      notificationService
          .notifyVoiceNote(
            recipientId: recipientId,
            senderName: currentUserName,
            sessionId: sessionId,
            audioUrl: audioUrl,
          )
          .catchError(
            (e) => debugPrint(
              '[SessionRoom] Notify error for $recipientId: $e',
            ),
          ),
    );
  }
}
