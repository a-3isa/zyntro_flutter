import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../app/navigation/app_route_locations.dart';
import '../app/navigation/app_router.dart';
import '../core/constants/constants.dart';
import '../features/auth/auth_providers.dart';
import '../core/models/models.dart';

/// Notification types matching React Native.
enum NotificationType {
  unknown,
  sessionInvite,
  voiceNote,
  followRequest,
  followAccepted,
  buddyInvite,
  buddyAccepted,
  buddySession,
  postLike, // Generic reaction
  postComment,
  sessionMilestone,
  streakMilestone,
  friendStreakBroken,
  friendStreakExtended,
  turnChange,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.unknown:
        return 'unknown';
      case NotificationType.sessionInvite:
        return 'session_invite';
      case NotificationType.voiceNote:
        return 'voice_note';
      case NotificationType.followRequest:
        return 'follow_request';
      case NotificationType.followAccepted:
        return 'follow_accepted';
      case NotificationType.buddyInvite:
        return 'buddy_invite';
      case NotificationType.buddyAccepted:
        return 'buddy_accepted';
      case NotificationType.buddySession:
        return 'buddy_session';
      case NotificationType.postLike:
        return 'post_like';
      case NotificationType.postComment:
        return 'post_comment';
      case NotificationType.sessionMilestone:
        return 'session_milestone';
      case NotificationType.streakMilestone:
        return 'streak_milestone';
      case NotificationType.friendStreakBroken:
        return 'friend_streak_broken';
      case NotificationType.friendStreakExtended:
        return 'friend_streak_extended';
      case NotificationType.turnChange:
        return 'turn_change';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'unknown':
        return NotificationType.unknown;
      case 'session_invite':
        return NotificationType.sessionInvite;
      case 'voice_note':
        return NotificationType.voiceNote;
      case 'follow_request':
        return NotificationType.followRequest;
      case 'follow_accepted':
        return NotificationType.followAccepted;
      case 'buddy_invite':
        return NotificationType.buddyInvite;
      case 'buddy_accepted':
        return NotificationType.buddyAccepted;
      case 'buddy_session':
        return NotificationType.buddySession;
      case 'post_like':
        return NotificationType.postLike;
      case 'post_comment':
        return NotificationType.postComment;
      case 'session_milestone':
        return NotificationType.sessionMilestone;
      case 'streak_milestone':
        return NotificationType.streakMilestone;
      case 'friend_streak_broken':
        return NotificationType.friendStreakBroken;
      case 'friend_streak_extended':
        return NotificationType.friendStreakExtended;
      case 'turn_change':
        return NotificationType.turnChange;
      default:
        return NotificationType.unknown;
    }
  }
}

/// Notification model.
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationTypeExtension.fromString(data['type'] ?? ''),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: data['data'] as Map<String, dynamic>?,
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Notification preferences model.
class NotificationPreferences {
  final bool sessionInvites;
  final bool voiceNotes;
  final bool followRequests;
  final bool followAccepted;
  final bool buddyInvites;
  final bool postLikes;
  final bool postComments;
  final bool sessionMilestones;
  final bool streakNotifications;
  final bool pushEnabled;

  const NotificationPreferences({
    this.sessionInvites = true,
    this.voiceNotes = true,
    this.followRequests = true,
    this.followAccepted = true,
    this.buddyInvites = true,
    this.postLikes = true,
    this.postComments = true,
    this.sessionMilestones = true,
    this.streakNotifications = true,
    this.pushEnabled = true,
  });

  static const defaults = NotificationPreferences();

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      sessionInvites: map['sessionInvites'] ?? true,
      voiceNotes: map['voiceNotes'] ?? true,
      followRequests: map['followRequests'] ?? true,
      followAccepted: map['followAccepted'] ?? true,
      buddyInvites: map['buddyInvites'] ?? true,
      postLikes: map['postLikes'] ?? true,
      postComments: map['postComments'] ?? true,
      sessionMilestones: map['sessionMilestones'] ?? true,
      streakNotifications: map['streakNotifications'] ?? true,
      pushEnabled: map['pushEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'sessionInvites': sessionInvites,
    'voiceNotes': voiceNotes,
    'followRequests': followRequests,
    'followAccepted': followAccepted,
    'buddyInvites': buddyInvites,
    'postLikes': postLikes,
    'postComments': postComments,
    'sessionMilestones': sessionMilestones,
    'streakNotifications': streakNotifications,
    'pushEnabled': pushEnabled,
  };

  NotificationPreferences copyWith({
    bool? sessionInvites,
    bool? voiceNotes,
    bool? followRequests,
    bool? followAccepted,
    bool? buddyInvites,
    bool? postLikes,
    bool? postComments,
    bool? sessionMilestones,
    bool? streakNotifications,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      sessionInvites: sessionInvites ?? this.sessionInvites,
      voiceNotes: voiceNotes ?? this.voiceNotes,
      followRequests: followRequests ?? this.followRequests,
      followAccepted: followAccepted ?? this.followAccepted,
      buddyInvites: buddyInvites ?? this.buddyInvites,
      postLikes: postLikes ?? this.postLikes,
      postComments: postComments ?? this.postComments,
      sessionMilestones: sessionMilestones ?? this.sessionMilestones,
      streakNotifications: streakNotifications ?? this.streakNotifications,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}

/// Notification service for managing in-app and push notifications.
/// Matches React Native notificationService.ts behavior.
class NotificationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirebaseMessaging _messaging;

  NotificationService(
    this._firestore, {
    FirebaseAuth? auth,
    http.Client? httpClient,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client(),
       _localNotifications = FlutterLocalNotificationsPlugin(),
       _messaging = FirebaseMessaging.instance;

  static Map<String, dynamic> sessionInvitePayload({
    required String sessionId,
    required String hostId,
    required String hostName,
    required String sessionType,
    required DateTime expiresAt,
  }) {
    return {
      'type': NotificationType.sessionInvite.value,
      'sessionId': sessionId,
      'hostId': hostId,
      'hostName': hostName,
      'byUserName': hostName,
      'sessionType': sessionType,
      'expiresAt': expiresAt.toIso8601String(),
      'context': 'one_to_one',
    };
  }

  String get _pushDeliveryUrl {
    final projectId = Firebase.app().options.projectId;
    return 'https://us-central1-$projectId.cloudfunctions.net/deliverNotificationPush';
  }

  CollectionReference<Map<String, dynamic>> _userNotificationsRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  DocumentReference<Map<String, dynamic>> _userNotificationRef(
    String userId,
    String notificationId,
  ) {
    return _userNotificationsRef(userId).doc(notificationId);
  }

  // ==================== INITIALIZATION ====================

  /// Initialize the notification service.
  /// Sets up local notifications and foreground message handlers.
  Future<void> init() async {
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'zyntro_default',
      'Zyntro Notifications',
      description: 'Notifications from Zyntro app',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '[NotificationService] Notification tapped: ${response.payload}',
    );
    // Handle navigation based on payload
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        debugPrint('[NotificationService] Payload data: $data');
        _navigateBasedOnData(data);
      } catch (e) {
        debugPrint('[NotificationService] Error parsing payload: $e');
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      '[NotificationService] Foreground message: ${message.notification?.title}',
    );
    await _showLocalNotification(message);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[NotificationService] Notification opened: ${message.data}');
    unawaited(_navigateBasedOnData(message.data));
  }

  /// Navigate based on notification data.
  Future<void> _navigateBasedOnData(Map<String, dynamic> data) async {
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      debugPrint('[NotificationService] No navigation context available');
      return;
    }

    // Navigate based on data contents
    if (data.containsKey('sessionId')) {
      final sessionId = data['sessionId'] as String;
      final notificationType = data['type'] as String?;
      final sessionType =
          data['sessionType'] as String? ?? WorkoutType.gym.value;
      final audioUrl = data['audioUrl'] as String?;

      // Session invites go to the acceptance page so the friend can choose
      // their workout type and plan before joining.
      if (notificationType == 'session_invite') {
        if (!navigatorContext.mounted) return;
        navigatorContext.push(
          AppRouteLocations.sessionAccept(sessionId),
          extra: data,
        );
        return;
      }

      String location = AppRouteLocations.sessionRoom(
        sessionId,
        type: sessionType,
        audioUrl: audioUrl,
      );

      try {
        final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
        final sessionData = sessionDoc.data();
        if (sessionDoc.exists && sessionData != null) {
          location = AppRouteLocations.sessionEntry(
            sessionId: sessionId,
            type: sessionData['type'] as String? ?? sessionType,
            phase: SessionPhase.fromString(
              sessionData['phase'] as String? ?? SessionPhase.live.value,
            ),
            audioUrl: audioUrl,
          );
        }
      } catch (error) {
        debugPrint(
          '[NotificationService] Failed to resolve session navigation: $error',
        );
      }

      if (!navigatorContext.mounted) return;
      navigatorContext.push(location, extra: data);
    } else if (data.containsKey('postId')) {
      final postId = data['postId'] as String;
      if (!navigatorContext.mounted) return;
      navigatorContext.push('/post/$postId');
    } else if (data.containsKey('buddyPairId') ||
        data.containsKey('fromUserId')) {
      // Navigate to notifications list for buddy/follow requests
      if (!navigatorContext.mounted) return;
      navigatorContext.push(AppRoutes.notifications);
    } else {
      // Default: go to notifications list
      if (!navigatorContext.mounted) return;
      navigatorContext.push(AppRoutes.notifications);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'zyntro_default',
      'Zyntro Notifications',
      channelDescription: 'Notifications from Zyntro app',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Zyntro',
      message.notification?.body ?? '',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }

  Future<String?> registerForPushNotifications() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return null;
      }
      return await _messaging.getToken();
    } catch (e) {
      return null;
    }
  }

  Future<void> savePushToken(
    String userId,
    String token,
    String deviceId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .set({
            'token': token,
            'platform': Platform.operatingSystem,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('[NotificationService] Error saving token: $e');
    }
  }

  Future<void> removePushToken(String userId, String deviceId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .delete();
    } catch (e) {
      debugPrint('[NotificationService] Error removing token: $e');
    }
  }

  Future<String> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final notificationRef = _userNotificationsRef(userId).doc();

    await notificationRef.set({
      'userId': userId,
      'type': type.value,
      'title': title,
      'message': message,
      'data': data ?? {},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return notificationRef.id;
  }

  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 50,
  }) async {
    final snapshot = await _userNotificationsRef(userId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => AppNotification.fromFirestore(doc))
        .toList();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final snapshot = await _userNotificationsRef(
      userId,
    ).where('userId', isEqualTo: userId).where('read', isEqualTo: false).get();
    return snapshot.docs.length;
  }

  Future<void> markNotificationAsRead(AppNotification notification) async {
    await _userNotificationRef(
      notification.userId,
      notification.id,
    ).update({'read': true});
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final snapshot = await _userNotificationsRef(
      userId,
    ).where('userId', isEqualTo: userId).where('read', isEqualTo: false).get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(AppNotification notification) async {
    await _userNotificationRef(notification.userId, notification.id).delete();
  }

  Stream<List<AppNotification>> listenToNotifications(String userId) {
    return _userNotificationsRef(userId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<int> listenToUnreadCount(String userId) {
    return _userNotificationsRef(userId)
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ==================== PUSH NOTIFICATION SENDING ====================

  Future<void> _deliverPushNotification({
    required NotificationType type,
    required String recipientId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint(
          '[NotificationService] Skipping push delivery because no authenticated user is available.',
        );
        return;
      }

      final idToken = await currentUser.getIdToken();
      final appCheckToken = await FirebaseAppCheck.instance.getToken(false);
      if (appCheckToken == null || appCheckToken.isEmpty) {
        debugPrint(
          '[NotificationService] Skipping push delivery because no App Check token is available.',
        );
        return;
      }

      final response = await _httpClient.post(
        Uri.parse(_pushDeliveryUrl),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'X-Firebase-AppCheck': appCheckToken,
        },
        body: jsonEncode(<String, dynamic>{
          'type': type.value,
          'recipientId': recipientId,
          'data': data ?? <String, dynamic>{},
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[NotificationService] Push delivery failed '
          '(${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Error delivering push: $e');
    }
  }

  // ==================== NOTIFICATION PREFERENCES ====================

  Future<NotificationPreferences> getNotificationPreferences(
    String userId,
  ) async {
    final prefDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('notifications')
        .get();

    if (prefDoc.exists) {
      return NotificationPreferences.fromMap(prefDoc.data() ?? {});
    }
    return NotificationPreferences.defaults;
  }

  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('notifications')
        .set({
          ...preferences.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<bool> shouldSendNotification(
    String userId,
    NotificationType type,
  ) async {
    final preferences = await getNotificationPreferences(userId);

    if (!preferences.pushEnabled) return false;

    switch (type) {
      case NotificationType.unknown:
        return false;
      case NotificationType.sessionInvite:
        return preferences.sessionInvites;
      case NotificationType.voiceNote:
        return preferences.voiceNotes;
      case NotificationType.followRequest:
        return preferences.followRequests;
      case NotificationType.followAccepted:
        return preferences.followAccepted;
      case NotificationType.buddyInvite:
      case NotificationType.buddyAccepted:
      case NotificationType.buddySession:
        return preferences.buddyInvites;
      case NotificationType.postLike:
        return preferences.postLikes;
      case NotificationType.postComment:
        return preferences.postComments;
      case NotificationType.sessionMilestone:
        return preferences.sessionMilestones;
      case NotificationType.streakMilestone:
      case NotificationType.friendStreakBroken:
      case NotificationType.friendStreakExtended:
        return preferences.streakNotifications;
      case NotificationType.turnChange:
        return preferences.sessionInvites;
    }
  }

  // ==================== NOTIFICATION TRIGGERS ====================

  /// Notify user of session invite.
  /// Supports group context for multi-participant sessions.
  Future<void> notifySessionInvite({
    required String recipientId,
    required String inviterName,
    required String sessionId,
    required String sessionType,
    String? hostId,
    DateTime? expiresAt,
    int groupSize = 0,
    String? otherParticipantNames,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.sessionInvite,
    );
    if (!shouldSend) return;

    // Build message with group context if applicable
    String message;
    final otherCount = groupSize > 0
        ? groupSize - 2
        : 0; // -1 for self, -1 for host

    if (groupSize > 2 &&
        otherParticipantNames != null &&
        otherParticipantNames.isNotEmpty) {
      // "Host invited you to a Type session with A, B and X others"
      message =
          '$inviterName invited you to a $sessionType session with $otherParticipantNames';
      if (otherCount > 0) {
        message += ' and $otherCount others';
      }
    } else if (groupSize > 2) {
      message =
          '$inviterName invited you to a $sessionType session with ${groupSize - 1} others';
    } else {
      message = '$inviterName invited you to a $sessionType session!';
    }

    final data = sessionInvitePayload(
      sessionId: sessionId,
      hostId: hostId ?? '',
      hostName: inviterName,
      sessionType: sessionType,
      expiresAt: expiresAt ?? DateTime.now().add(pairedInviteTimeout),
    )..['groupSize'] = groupSize;

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.sessionInvite,
        title: 'Session Invite',
        message: message,
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.sessionInvite,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user when it's their turn in a multi-participant session.
  Future<void> notifyTurnChange({
    required String recipientId,
    required String sessionId,
    required String sessionType,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.turnChange,
    );
    if (!shouldSend) return;

    final data = {
      'sessionId': sessionId,
      'sessionType': sessionType,
      'action': 'open_session',
    };

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.turnChange,
        title: 'Your Turn!',
        message: "It's your turn to log a set in the $sessionType session",
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.turnChange,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user of voice note - OPTIMIZED for <2s delivery.
  Future<void> notifyVoiceNote({
    required String recipientId,
    required String senderName,
    required String sessionId,
    required String audioUrl,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.voiceNote,
    );
    if (!shouldSend) return;

    final data = {
      'sessionId': sessionId,
      'audioUrl': audioUrl,
      'byUserName': senderName,
      'autoPlay': true, // Added for auto-play trigger
    };

    unawaited(
      createNotification(
        userId: recipientId,
        type: NotificationType.voiceNote,
        title: 'Voice Note',
        message: '$senderName sent you a voice note',
        data: data,
      ),
    );

    unawaited(
      _deliverPushNotification(
        type: NotificationType.voiceNote,
        recipientId: recipientId,
        data: data,
      ),
    );
  }

  /// Notify user of follow request.
  Future<void> notifyFollowRequest({
    required String recipientId,
    required String requesterId,
    required String requesterName,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.followRequest,
    );
    if (!shouldSend) return;

    final data = {'fromUserId': requesterId, 'byUserName': requesterName};

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.followRequest,
        title: 'New Follow Request',
        message: '$requesterName wants to follow you',
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.followRequest,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user that their follow request was accepted.
  Future<void> notifyFollowAccepted({
    required String recipientId,
    required String acceptorId,
    required String acceptorName,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.followAccepted,
    );
    if (!shouldSend) return;

    final data = {'byUserId': acceptorId, 'byUserName': acceptorName};

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.followAccepted,
        title: 'Follow Request Accepted',
        message: '$acceptorName accepted your follow request',
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.followAccepted,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user of buddy invite.
  Future<void> notifyBuddyInvite({
    required String recipientId,
    required String inviterId,
    required String inviterName,
    required String buddyPairId,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.buddyInvite,
    );
    if (!shouldSend) return;

    final data = {
      'buddyPairId': buddyPairId,
      'fromUserId': inviterId,
      'byUserName': inviterName,
    };

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.buddyInvite,
        title: 'Buddy Invite',
        message: '$inviterName wants to be your workout buddy!',
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.buddyInvite,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  Future<void> notifyBuddyAccepted({
    required String recipientId,
    required String acceptorId,
    required String acceptorName,
    required String buddyPairId,
  }) async {
    // Implementation similar to original
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.buddyAccepted,
    );
    if (!shouldSend) return;

    final data = {
      'buddyPairId': buddyPairId,
      'byUserId': acceptorId,
      'byUserName': acceptorName,
    };

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.buddyAccepted,
        title: 'Buddy Request Accepted',
        message: '$acceptorName is now your workout buddy!',
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.buddyAccepted,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  Future<void> notifyBuddySession({
    required String recipientId,
    required String buddyName,
    required String sessionId,
    required String sessionType,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.buddySession,
    );
    if (!shouldSend) return;

    final data = {
      'sessionId': sessionId,
      'sessionType': sessionType,
      'byUserName': buddyName,
    };

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.buddySession,
        title: 'Buddy Session',
        message: '$buddyName started a $sessionType session with you!',
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.buddySession,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user that someone liked/reacted to their post.
  /// Renamed from notifyPostLike to support reactions, but kept alias.
  Future<void> notifyPostLike({
    required String recipientId,
    required String likerId,
    required String likerName,
    required String postId,
    ReactionType type = ReactionType.fire,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.postLike,
    );
    if (!shouldSend) return;

    final data = {
      'postId': postId,
      'byUserId': likerId,
      'byUserName': likerName,
      'reactionType': type.value,
    };

    // Customize message based on type
    String message;
    String title = 'New Reaction';
    switch (type) {
      case ReactionType.fire:
        message = '$likerName reacted 🔥 to your post';
        break;
      case ReactionType.strong:
        message = '$likerName reacted 💪 to your post';
        break;
      case ReactionType.clap:
        message = '$likerName reacted 👏 to your post';
        break;
    }

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.postLike,
        title: title,
        message: message,
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.postLike,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user that someone commented on their post.
  Future<void> notifyPostComment({
    required String recipientId,
    required String commenterId,
    required String commenterName,
    required String postId,
    required String commentId,
    required String commentText,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.postComment,
    );
    if (!shouldSend) return;

    final truncatedComment = commentText.length > 50
        ? '${commentText.substring(0, 50)}...'
        : commentText;

    final data = {
      'postId': postId,
      'commentId': commentId,
      'byUserId': commenterId,
      'byUserName': commenterName,
    };

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.postComment,
        title: 'New Comment',
        message: '$commenterName: "$truncatedComment"',
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.postComment,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user of a session milestone (e.g. "Work out today!").
  Future<void> notifySessionMilestone({
    required String userId,
    required String title,
    required String message,
  }) async {
    final shouldSend = await shouldSendNotification(
      userId,
      NotificationType.sessionMilestone,
    );
    if (!shouldSend) return;

    await Future.wait([
      createNotification(
        userId: userId,
        type: NotificationType.sessionMilestone,
        title: title,
        message: message,
      ),
      _deliverPushNotification(
        type: NotificationType.sessionMilestone,
        recipientId: userId,
      ),
    ]);
  }

  /// Notify user of their own streak milestone.
  Future<void> notifyStreakMilestone({
    required String userId,
    required int streakDays,
  }) async {
    final shouldSend = await shouldSendNotification(
      userId,
      NotificationType.streakMilestone,
    );
    if (!shouldSend) return;

    final title = 'Streak Milestone! 🔥';
    final message = "You've reached a $streakDays-day streak! Keep it up!";

    await Future.wait([
      createNotification(
        userId: userId,
        type: NotificationType.streakMilestone,
        title: title,
        message: message,
        data: {'streak': streakDays},
      ),
      _deliverPushNotification(
        type: NotificationType.streakMilestone,
        recipientId: userId,
        data: {'streak': streakDays},
      ),
    ]);
  }

  /// Notify user that a friend's streak is broken.
  Future<void> notifyFriendStreakBroken({
    required String recipientId,
    required String friendId,
    required String friendName,
    required int previousStreak,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.friendStreakBroken,
    );
    if (!shouldSend) return;

    final title = 'Oh no! Streak Broken 😢';
    final message =
        "$friendName lost their $previousStreak-day streak. Cheer them up!";

    final data = {
      'friendId': friendId,
      'friendName': friendName,
      'previousStreak': previousStreak,
    };

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.friendStreakBroken,
        title: title,
        message: message,
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.friendStreakBroken,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }

  /// Notify user that a friend extended their streak.
  Future<void> notifyFriendStreakExtended({
    required String recipientId,
    required String friendId,
    required String friendName,
    required int newStreak,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.friendStreakExtended,
    );
    if (!shouldSend) return;

    final title = 'Streak Extended! 🔥';
    final message = "$friendName just hit a $newStreak-day streak!";

    final data = {
      'friendId': friendId,
      'friendName': friendName,
      'newStreak': newStreak,
    };

    await Future.wait([
      createNotification(
        userId: recipientId,
        type: NotificationType.friendStreakExtended,
        title: title,
        message: message,
        data: data,
      ),
      _deliverPushNotification(
        type: NotificationType.friendStreakExtended,
        recipientId: recipientId,
        data: data,
      ),
    ]);
  }
}

Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  String? deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }
  return deviceId;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Notification service provider.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(authFirestoreProvider));
});

/// User notifications stream provider.
final userNotificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
      return ref
          .watch(notificationServiceProvider)
          .listenToNotifications(userId);
    });

/// Unread notification count stream provider.
final unreadCountProvider = StreamProvider.family<int, String>((ref, userId) {
  return ref.watch(notificationServiceProvider).listenToUnreadCount(userId);
});

/// Notification preferences provider.
final notificationPreferencesProvider =
    FutureProvider.family<NotificationPreferences, String>((ref, userId) async {
      return ref
          .watch(notificationServiceProvider)
          .getNotificationPreferences(userId);
    });
