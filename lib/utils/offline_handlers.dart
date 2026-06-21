import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_service.dart';
import '../services/post_service.dart';
import '../services/media_service.dart';
import '../core/models/models.dart';
import '../core/constants/constants.dart';
import 'offline_manager.dart';

/// Error categories for offline operations.
enum OfflineErrorCategory {
  network, // Retryable network errors
  validation, // Invalid data, discard after max retries
  permission, // Auth/permission errors
  unknown, // Unknown errors, retry with limit
}

/// Categorize an error for appropriate handling.
OfflineErrorCategory categorizeError(Object error) {
  final errorString = error.toString().toLowerCase();

  if (errorString.contains('network') ||
      errorString.contains('timeout') ||
      errorString.contains('connection') ||
      errorString.contains('socket')) {
    return OfflineErrorCategory.network;
  }

  if (errorString.contains('permission') ||
      errorString.contains('unauthorized') ||
      errorString.contains('forbidden')) {
    return OfflineErrorCategory.permission;
  }

  if (errorString.contains('invalid') ||
      errorString.contains('argument') ||
      errorString.contains('required field')) {
    return OfflineErrorCategory.validation;
  }

  return OfflineErrorCategory.unknown;
}

/// Register offline operation handlers.
Future<void> registerOfflineHandlers(ProviderContainer container) async {
  final offlineManager = container.read(offlineManagerProvider);

  // Initialize manager
  await offlineManager.init();

  // Register batch handler for session events
  offlineManager.registerBatchHandler('session_event', (operations) async {
    final results = <bool>[];
    final sessionService = container.read(sessionServiceProvider);

    // Group operations by sessionId
    final groupedBySession = <String, List<QueuedOperation>>{};
    for (final op in operations) {
      final sessionId = op.payload['sessionId'] as String? ?? '';
      if (sessionId.isNotEmpty) {
        groupedBySession.putIfAbsent(sessionId, () => []).add(op);
      } else {
        // Invalid operation without sessionId
        debugPrint(
          '[OfflineHandlers] Batch: Invalid operation without sessionId, id=${op.id}',
        );
        results.add(false);
      }
    }

    // Process each session's events as a batch
    for (final entry in groupedBySession.entries) {
      final sessionId = entry.key;
      final sessionOps = entry.value;

      debugPrint(
        '[OfflineHandlers] Syncing batch of ${sessionOps.length} events for session $sessionId',
      );

      try {
        // Convert operations to event data list
        final eventsList = sessionOps.map((op) {
          final payload = op.payload;
          return {
            'type': payload['type'] as String,
            'userId': payload['userId'] as String,
            'text': payload['text'] as String,
            'data': payload['data'] as Map<String, dynamic>?,
          };
        }).toList();

        // Call batch add
        await sessionService.addBatchSessionEvents(sessionId, eventsList);

        // All succeeded
        for (var i = 0; i < sessionOps.length; i++) {
          results.add(true);
        }
      } catch (e, stack) {
        final errorCategory = categorizeError(e);
        debugPrint(
          '[OfflineHandlers] Batch sync failed for session $sessionId: $e (category: $errorCategory)',
        );
        debugPrint('[OfflineHandlers] Stack: $stack');

        // If batch fails, mark all as failed for re-queue with individual retry
        for (var i = 0; i < sessionOps.length; i++) {
          results.add(false);
        }
      }
    }

    return results;
  });

  // 1. Session Event - Enhanced with validation (individual handler as fallback)
  offlineManager.registerHandler('session_event', (op) async {
    final payload = op.payload;

    // Validate required fields
    final sessionId = payload['sessionId'] as String?;
    final type = payload['type'] as String?;
    final userId = payload['userId'] as String?;
    final text = payload['text'] as String?;

    if (sessionId == null || sessionId.isEmpty) {
      throw ArgumentError('Missing required field: sessionId');
    }
    if (type == null || type.isEmpty) {
      throw ArgumentError('Missing required field: type');
    }
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('Missing required field: userId');
    }
    if (text == null) {
      throw ArgumentError('Missing required field: text');
    }

    try {
      await container
          .read(sessionServiceProvider)
          .addSessionEvent(
            sessionId: sessionId,
            type: SessionEventType.fromString(type),
            userId: userId,
            text: text,
            data: payload['data'] as Map<String, dynamic>?,
          );
    } catch (e, stack) {
      final errorCategory = categorizeError(e);
      // Log detailed error for debugging
      debugPrint(
        '[OfflineHandlers] Session event sync failed: $e (category: $errorCategory)',
      );
      debugPrint('[OfflineHandlers] Operation ID: ${op.id}');
      debugPrint('[OfflineHandlers] Retry count: ${op.retryCount}');
      debugPrint(
        '[OfflineHandlers] Payload summary: sessionId=$sessionId, type=$type',
      );
      debugPrint('[OfflineHandlers] Stack: $stack');

      // For validation errors after 3 retries, just log and don't rethrow
      // to allow discarding
      if (errorCategory == OfflineErrorCategory.validation &&
          op.retryCount >= 3) {
        debugPrint(
          '[OfflineHandlers] Discarding validation error after ${op.retryCount} retries',
        );
        // TODO: Log to analytics/crash reporting service
        return;
      }

      rethrow;
    }
  });

  // 2. Session End
  offlineManager.registerHandler('session_end', (op) async {
    final payload = op.payload;
    final summaryMap = payload['summary'] as Map<String, dynamic>?;
    final summary = summaryMap != null
        ? SessionSummary.fromMap(summaryMap)
        : null;

    try {
      await container
          .read(sessionServiceProvider)
          .endSession(payload['sessionId'], payload['userId'], summary);
    } catch (e, stack) {
      final errorCategory = categorizeError(e);
      debugPrint(
        '[OfflineHandlers] Session end failed: $e (category: $errorCategory)',
      );
      debugPrint('[OfflineHandlers] Operation ID: ${op.id}');
      debugPrint('[OfflineHandlers] Stack: $stack');
      rethrow;
    }
  });

  // 3. Post Create
  offlineManager.registerHandler('post_create', (op) async {
    final payload = op.payload;
    final summaryMap = payload['summary'] as Map<String, dynamic>;

    try {
      await container
          .read(postServiceProvider)
          .createPost(
            CreatePostParams(
              authorId: payload['authorId'],
              sessionId: payload['sessionId'],
              visibility: payload['visibility'],
              title: payload['title'],
              type: payload['type'],
              summary: SessionSummary.fromMap(summaryMap),
              photoUri: payload['photoUri'],
              buddyId: payload['buddyId'],
              buddyName: payload['buddyName'],
            ),
          );
    } catch (e, stack) {
      final errorCategory = categorizeError(e);
      debugPrint(
        '[OfflineHandlers] Post create failed: $e (category: $errorCategory)',
      );
      debugPrint('[OfflineHandlers] Operation ID: ${op.id}');
      debugPrint('[OfflineHandlers] Stack: $stack');
      rethrow;
    }
  });

  // 4. Like Post (T026)
  offlineManager.registerHandler('like_post', (op) async {
    final payload = op.payload;
    final postId = payload['postId'] as String?;
    final userId = payload['userId'] as String?;
    final userName = payload['userName'] as String?;

    if (postId == null || postId.isEmpty) {
      throw ArgumentError('Missing required field: postId');
    }
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('Missing required field: userId');
    }

    try {
      await container.read(postServiceProvider).likePost(
            postId,
            userId,
            userName: userName,
          );
    } catch (e, stack) {
      final errorCategory = categorizeError(e);
      debugPrint(
        '[OfflineHandlers] Like post failed: $e (category: $errorCategory)',
      );
      debugPrint('[OfflineHandlers] Operation ID: ${op.id}');
      debugPrint('[OfflineHandlers] Stack: $stack');
      rethrow;
    }
  });

  // 5. Unlike Post (T027)
  offlineManager.registerHandler('unlike_post', (op) async {
    final payload = op.payload;
    final postId = payload['postId'] as String?;
    final userId = payload['userId'] as String?;

    if (postId == null || postId.isEmpty) {
      throw ArgumentError('Missing required field: postId');
    }
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('Missing required field: userId');
    }

    try {
      await container.read(postServiceProvider).unlikePost(postId, userId);
    } catch (e, stack) {
      final errorCategory = categorizeError(e);
      debugPrint(
        '[OfflineHandlers] Unlike post failed: $e (category: $errorCategory)',
      );
      debugPrint('[OfflineHandlers] Operation ID: ${op.id}');
      debugPrint('[OfflineHandlers] Stack: $stack');
      rethrow;
    }
  });

  // 6. Add Comment (T028)
  offlineManager.registerHandler('add_comment', (op) async {
    final payload = op.payload;
    final postId = payload['postId'] as String?;
    final userId = payload['userId'] as String?;
    final userName = payload['userName'] as String?;
    final text = payload['text'] as String?;

    if (postId == null || postId.isEmpty) {
      throw ArgumentError('Missing required field: postId');
    }
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('Missing required field: userId');
    }
    if (text == null || text.isEmpty) {
      throw ArgumentError('Missing required field: text');
    }

    try {
      await container.read(postServiceProvider).addComment( // ignore: deprecated_member_use
            postId: postId,
            userId: userId,
            userName: userName ?? 'Unknown',
            userPhotoURL: payload['userPhotoURL'] as String?,
            text: text,
          );
    } catch (e, stack) {
      final errorCategory = categorizeError(e);
      debugPrint(
        '[OfflineHandlers] Add comment failed: $e (category: $errorCategory)',
      );
      debugPrint('[OfflineHandlers] Operation ID: ${op.id}');
      debugPrint('[OfflineHandlers] Stack: $stack');
      rethrow;
    }
  });

  // 7. Voice Note Upload
  offlineManager.registerHandler('voice_note_upload', (op) async {
    final payload = op.payload;
    final String localPath = payload['filePath'];
    final String sessionId = payload['sessionId'];
    final String userId = payload['userId'];

    try {
      // Upload
      final mediaService = container.read(mediaServiceProvider);
      final audioUrl = await mediaService.uploadVoiceNote(
        filePath: localPath,
        sessionId: sessionId,
      );

      // Create event
      await container
          .read(sessionServiceProvider)
          .addSessionEvent(
            sessionId: sessionId,
            type: SessionEventType.voiceNote,
            userId: userId,
            text: '🎤 Sent a voice note',
            data: {'audioUrl': audioUrl},
          );
    } catch (e, stack) {
      final errorCategory = categorizeError(e);
      debugPrint(
        '[OfflineHandlers] Voice note upload failed: $e (category: $errorCategory)',
      );
      debugPrint('[OfflineHandlers] Operation ID: ${op.id}');
      debugPrint('[OfflineHandlers] Local path: $localPath');
      debugPrint('[OfflineHandlers] Stack: $stack');
      rethrow;
    }
  });
}
