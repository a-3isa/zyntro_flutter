import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../app/launch_intent.dart';
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
  newFollower,
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
  jointPostInvite,
  jointPostExpired,
  partnerLeft,
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
      case NotificationType.newFollower:
        return 'new_follower';
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
      case NotificationType.jointPostInvite:
        return 'joint_post_invite';
      case NotificationType.jointPostExpired:
        return 'joint_post_expired';
      case NotificationType.partnerLeft:
        return 'partner_left';
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
      case 'new_follower':
        return NotificationType.newFollower;
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
      case 'joint_post_invite':
        return NotificationType.jointPostInvite;
      case 'joint_post_expired':
        return NotificationType.jointPostExpired;
      case 'partner_left':
        return NotificationType.partnerLeft;
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
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
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

    // Handle notification tap while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Handle notification tap that launched the app from terminated state.
    // onMessageOpenedApp does NOT fire for this case — only getInitialMessage does.
    // init() is called before runApp(), so defer navigation one frame.
    final initialMessage = await _messaging.getInitialMessage();

    // Record that this launch already has a destination, BEFORE runApp() builds
    // the router. Session-resume reads this and stands down.
    //
    // Without it the two race: this navigation runs from a post-frame callback
    // while the resume redirect runs from GoRouter's redirect callback, both
    // driving the same navigator with nothing sequencing them — so a member who
    // tapped a notification while holding a live session would land wherever
    // the scheduler happened to finish last. init() running before runApp()
    // turns that race into an ordering fact.
    LaunchIntent.instance.hasExplicitDestination = initialMessage != null;

    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_navigateBasedOnData(initialMessage.data));
      });
    }

    // Re-save the FCM token whenever it rotates (reinstall, clear data, etc.).
    // Without this, push silently breaks for users whose token has changed.
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    if (deviceId != null) {
      await savePushToken(user.uid, newToken, deviceId);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped');
    // Handle navigation based on payload
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        debugPrint(
          '[NotificationService] Payload data: ${_redactedNotificationDataForLog(data)}',
        );
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
    debugPrint(
      '[NotificationService] Notification opened: ${_redactedNotificationDataForLog(message.data)}',
    );
    unawaited(_navigateBasedOnData(message.data));
  }

  /// Navigate based on notification data.
  Future<void> _navigateBasedOnData(Map<String, dynamic> data) async {
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      debugPrint('[NotificationService] No navigation context available');
      return;
    }

    // Follow request taps → deep-link to requester's profile
    if (data['type'] == 'follow_request') {
      final fromUserId = data['fromUserId'] as String?;
      if (fromUserId != null && navigatorContext.mounted) {
        unawaited(navigatorContext.push('/user/$fromUserId'));
        return;
      }
    }

    // Navigate based on data contents
    if (data.containsKey('sessionId')) {
      final sessionId = data['sessionId'] as String;
      final notificationType = data['type'] as String?;
      final sessionType =
          data['sessionType'] as String? ?? WorkoutType.gym.value;

      // Session invites go to the acceptance page so the friend can choose
      // their workout type and plan before joining.
      if (notificationType == 'session_invite') {
        // Mark the invite doc read first so SessionInviteListener doesn't also
        // pop its in-app dialog on top of the page we're about to open.
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          try {
            await _userNotificationRef(
              uid,
              'session_invite_$sessionId',
            ).update({'read': true});
          } catch (_) {
            // Doc may not exist yet (push-only path) — safe to ignore.
          }
        }
        if (!navigatorContext.mounted) return;
        unawaited(navigatorContext.push(AppRouteLocations.gymSessionSetup(sessionId)));
        return;
      }

      // A partner leaving points at a session that is still live for the
      // recipient — they are mid-workout and get to decide whether to carry on.
      // Mark it read on the way in so the notification list does not keep
      // nagging about something they have now seen; the finish-or-continue
      // choice itself comes from the session document, not from this doc, so
      // clearing it costs them nothing.
      if (notificationType == 'partner_left') {
        final uid = _auth.currentUser?.uid;
        final leaverId = data['leaverId'] as String?;
        if (uid != null && leaverId != null) {
          try {
            await _userNotificationRef(
              uid,
              'partner_left_${sessionId}_$leaverId',
            ).update({'read': true});
          } catch (_) {
            // Push-only path — the doc may not exist yet. Safe to ignore.
          }
        }
        if (!navigatorContext.mounted) return;
        unawaited(navigatorContext.push(
          AppRouteLocations.sessionRoom(
            sessionId,
            type: (data['sessionType'] as String?) ?? WorkoutType.gym.value,
          ),
        ));
        return;
      }

      // Joint-post invite/expiry offers also carry sessionId (for context),
      // but must never fall through to the generic live-session route below
      // — the session itself may be long finished. Route to the post instead.
      //
      // An *invite* points at an unpublished draft the recipient still has to
      // complete, so it opens the composer route; only the *expired* offer
      // goes to post detail, where the solo-repost flow lives.
      if (notificationType == 'joint_post_invite' ||
          notificationType == 'joint_post_expired') {
        final postId = data['postId'] as String?;
        if (postId != null && navigatorContext.mounted) {
          unawaited(navigatorContext.push(
            notificationType == 'joint_post_invite'
                ? AppRouteLocations.jointPostComposer(postId)
                : AppRouteLocations.postDetail(postId),
          ));
        }
        return;
      }

      String location = AppRouteLocations.sessionRoom(
        sessionId,
        type: sessionType,
      );

      try {
        final sessionDoc = await _firestore
            .collection('sessions')
            .doc(sessionId)
            .get();
        final sessionData = sessionDoc.data();
        if (sessionDoc.exists && sessionData != null) {
          location = AppRouteLocations.sessionEntry(
            sessionId: sessionId,
            type: sessionData['type'] as String? ?? sessionType,
            phase: SessionPhase.fromString(
              sessionData['phase'] as String? ?? SessionPhase.live.value,
            ),
          );
        }
      } catch (error) {
        debugPrint(
          '[NotificationService] Failed to resolve session navigation: $error',
        );
      }

      if (!navigatorContext.mounted) return;
      unawaited(navigatorContext.push(location, extra: data));
    } else if (data.containsKey('postId')) {
      final postId = data['postId'] as String;
      if (!navigatorContext.mounted) return;
      unawaited(navigatorContext.push('/post/$postId'));
    } else if (data.containsKey('buddyPairId') ||
        data.containsKey('fromUserId')) {
      // Navigate to notifications list for buddy/follow requests
      if (!navigatorContext.mounted) return;
      unawaited(navigatorContext.push(AppRoutes.notifications));
    } else {
      // Default: go to notifications list
      if (!navigatorContext.mounted) return;
      unawaited(navigatorContext.push(AppRoutes.notifications));
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
      id: message.hashCode,
      title: message.notification?.title ?? 'Zyntro',
      body: message.notification?.body ?? '',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
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
      String appVersion = 'unknown';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      final locale =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .set({
            'token': token,
            'platform': Platform.operatingSystem,
            // Ops targeting / push localization (Z-NOTIF-003).
            'locale': locale,
            'appVersion': appVersion,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
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

  Future<void> updateNotificationData(
    String notificationId,
    String userId,
    Map<String, dynamic> dataUpdate,
  ) async {
    final docRef = _userNotificationRef(userId, notificationId);
    final snap = await docRef.get();
    final existing = Map<String, dynamic>.from(
      snap.data()?['data'] as Map? ?? {},
    );
    existing.addAll(dataUpdate);
    await docRef.update({'data': existing});
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
    bool rethrowOnFailure = false,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        const error =
            'No authenticated user is available for notification delivery.';
        if (rethrowOnFailure) throw StateError(error);
        debugPrint('[NotificationService] $error');
        return;
      }

      final idToken = await currentUser.getIdToken();
      // Limited-use token so the Cloud Function can consume it and block
      // replay of captured App Check headers (Z-FN-002).
      final appCheckToken =
          await FirebaseAppCheck.instance.getLimitedUseToken();
      if (appCheckToken.isEmpty) {
        const error =
            'No App Check token is available for notification delivery.';
        if (rethrowOnFailure) throw StateError(error);
        debugPrint('[NotificationService] $error');
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
        final error = StateError(
          'Notification delivery failed (${response.statusCode}): ${response.body}',
        );
        if (rethrowOnFailure) throw error;
        debugPrint('[NotificationService] $error');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error delivering push: $e');
      if (rethrowOnFailure) rethrow;
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
    final NotificationPreferences preferences;
    try {
      preferences = await getNotificationPreferences(userId);
    } catch (error) {
      // users/{id}/settings is owner-only, so a cross-user read (e.g. the host
      // checking the recipient before a turn_change) is denied by rules.
      // Fail closed (Z-NOTIF-002): do not create client-side inbox noise when
      // preferences are unknown. Trusted Cloud Functions re-check with Admin
      // SDK before push delivery.
      debugPrint(
        '[NotificationService] Preference read failed for $userId; '
        'suppressing client notification (fail-closed): $error',
      );
      return false;
    }

    if (!preferences.pushEnabled) return false;

    switch (type) {
      case NotificationType.unknown:
        return false;
      case NotificationType.sessionInvite:
        return preferences.sessionInvites;
      case NotificationType.voiceNote:
        return preferences.voiceNotes;
      case NotificationType.followRequest:
      case NotificationType.newFollower:
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
        // Turn alerts are core in-session gameplay, not a promotional bucket —
        // honour only the global pushEnabled switch (already checked above).
        return true;
      case NotificationType.jointPostInvite:
      case NotificationType.jointPostExpired:
        // No dedicated preference bucket exists yet for joint-post
        // notifications — mirrors the Cloud Function's recipientAllowsPush
        // default (honour only the global pushEnabled switch checked above).
        return true;
      case NotificationType.partnerLeft:
        // Core in-session information, like turn alerts: the member is mid
        // workout and their partner has just walked out. Honour only the global
        // pushEnabled switch (already checked above).
        return true;
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
    final data = sessionInvitePayload(
      sessionId: sessionId,
      hostId: hostId ?? '',
      hostName: inviterName,
      sessionType: sessionType,
      expiresAt: expiresAt ?? DateTime.now().add(pairedInviteTimeout),
    )..['groupSize'] = groupSize;

    // CF-authoritative: the Cloud Function writes the in-app invite doc (with
    // server-validated content, under the deterministic session_invite_<id> key)
    // AND dispatches the push. Clients cannot write cross-user notifications
    // directly (owner-only rule). rethrowOnFailure: true so a real delivery
    // failure fails the invite instead of silently half-succeeding — the caller
    // (createSession) rolls back the orphaned session on this throw.
    await _deliverPushNotification(
      type: NotificationType.sessionInvite,
      recipientId: recipientId,
      data: data,
      rethrowOnFailure: true,
    );
  }

  /// Tell the remaining participants that a partner has left the session.
  ///
  /// This is the fast route only. The finish-or-continue choice itself renders
  /// from `endedParticipants` on the session document, so a member whose phone
  /// was off, who had no signal, or who dismissed this still gets the choice
  /// the next time they open the session. Never make the decision depend on
  /// delivery.
  ///
  /// CF-authoritative like [notifySessionInvite]: the Cloud Function writes the
  /// in-app doc (clients cannot create cross-user notifications — owner-only
  /// rule) under the deterministic `partner_left_<sessionId>_<leaverId>` key,
  /// so one departure yields exactly one notification however many times it is
  /// retried.
  ///
  /// Not `rethrowOnFailure`: unlike an invite, a failed send here must not undo
  /// anything. The member has already left, and the session record is the
  /// source of truth regardless.
  Future<void> notifyPartnerLeft({
    required String recipientId,
    required String sessionId,
    required String leaverId,
    required String leaverName,
  }) async {
    await _deliverPushNotification(
      type: NotificationType.partnerLeft,
      recipientId: recipientId,
      data: {
        'type': NotificationType.partnerLeft.value,
        'sessionId': sessionId,
        'leaverId': leaverId,
        'leaverName': leaverName,
        'byUserName': leaverName,
      },
    );
  }

  /// Notify a co-author's partner that a joint (two-author) session post is
  /// ready for them to review and confirm.
  /// CF-authoritative, same as [notifySessionInvite]: the Cloud Function is
  /// the only writer of the in-app doc (clients cannot create cross-user
  /// notifications directly — owner-only rule) and persists it under the
  /// deterministic `joint_post_invite_<postId>` key, so a re-sent invite
  /// refreshes the existing doc instead of duplicating it. `data` carries
  /// `postId` + `sessionId` for the tap deep-link to the joint-post
  /// confirmation screen.
  Future<void> sendJointPostInvite({
    required String recipientId,
    required String fromName,
    required String postId,
    required String sessionId,
  }) async {
    final data = {
      'type': NotificationType.jointPostInvite.value,
      'postId': postId,
      'sessionId': sessionId,
      'fromName': fromName,
      'byUserName': fromName,
    };

    await _deliverPushNotification(
      type: NotificationType.jointPostInvite,
      recipientId: recipientId,
      data: data,
    );
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

    // CF-authoritative: the Cloud Function persists the in-app doc and pushes.
    await _deliverPushNotification(
      type: NotificationType.turnChange,
      recipientId: recipientId,
      data: data,
    );
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

    // CF-authoritative: the Cloud Function persists the in-app doc and pushes.
    unawaited(
      _deliverPushNotification(
        type: NotificationType.voiceNote,
        recipientId: recipientId,
        data: data,
      ),
    );
  }

  /// Notify user of follow request.
  Future<void> notifyNewFollower({
    required String recipientId,
    required String followerId,
    required String followerName,
  }) async {
    final shouldSend = await shouldSendNotification(
      recipientId,
      NotificationType.newFollower,
    );
    if (!shouldSend) return;

    final data = {'fromUserId': followerId, 'byUserName': followerName};

    // CF-authoritative: the Cloud Function persists the in-app doc and pushes.
    await _deliverPushNotification(
      type: NotificationType.newFollower,
      recipientId: recipientId,
      data: data,
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

    // CF-authoritative: the Cloud Function persists the in-app doc and pushes.
    await _deliverPushNotification(
      type: NotificationType.followRequest,
      recipientId: recipientId,
      data: data,
    );
    unawaited(FirebaseAnalytics.instance.logEvent(name: 'follow_notification_delivered'));
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

    // CF-authoritative: the Cloud Function persists the in-app doc and pushes.
    await _deliverPushNotification(
      type: NotificationType.followAccepted,
      recipientId: recipientId,
      data: data,
    );
  }

  /// Notify user of buddy invite.
  ///
  /// CF-authoritative (Z-NOTIF-001): clients cannot write another user's inbox.
  Future<void> notifyBuddyInvite({
    required String recipientId,
    required String inviterId,
    required String inviterName,
    required String buddyPairId,
  }) async {
    final data = {
      'buddyPairId': buddyPairId,
      'fromUserId': inviterId,
      'byUserName': inviterName,
    };

    await _deliverPushNotification(
      type: NotificationType.buddyInvite,
      recipientId: recipientId,
      data: data,
    );
  }

  Future<void> notifyBuddyAccepted({
    required String recipientId,
    required String acceptorId,
    required String acceptorName,
    required String buddyPairId,
  }) async {
    final data = {
      'buddyPairId': buddyPairId,
      'byUserId': acceptorId,
      'byUserName': acceptorName,
    };

    await _deliverPushNotification(
      type: NotificationType.buddyAccepted,
      recipientId: recipientId,
      data: data,
    );
  }

  Future<void> notifyBuddySession({
    required String recipientId,
    required String buddyName,
    required String sessionId,
    required String sessionType,
  }) async {
    final data = {
      'sessionId': sessionId,
      'sessionType': sessionType,
      'byUserName': buddyName,
    };

    await _deliverPushNotification(
      type: NotificationType.buddySession,
      recipientId: recipientId,
      data: data,
    );
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

    // CF-authoritative: the Cloud Function builds the title/body (per reaction
    // type), persists the in-app doc, and pushes.
    await _deliverPushNotification(
      type: NotificationType.postLike,
      recipientId: recipientId,
      data: data,
    );
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

    final data = {
      'postId': postId,
      'commentId': commentId,
      'byUserId': commenterId,
      'byUserName': commenterName,
    };

    // CF-authoritative: the Cloud Function builds the body from the stored
    // comment, persists the in-app doc, and pushes.
    await _deliverPushNotification(
      type: NotificationType.postComment,
      recipientId: recipientId,
      data: data,
    );
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

    final title = 'Streak Milestone!';
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

    final title = 'Oh no! Streak Broken';
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

    final title = 'Streak Extended!';
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

const _notificationLogRedactions = <String, String>{
  'audioUrl': '<redacted>',
  'token': '<redacted>',
  'idToken': '<redacted>',
  'appCheckToken': '<redacted>',
  'Authorization': '<redacted>',
  'X-Firebase-AppCheck': '<redacted>',
};

Map<String, dynamic> _redactedNotificationDataForLog(
  Map<String, dynamic> data,
) {
  return data.map((key, value) {
    return MapEntry(key, _notificationLogRedactions[key] ?? value);
  });
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
  // Background isolate: Firebase must be re-initialised before any Firebase call.
  await Firebase.initializeApp();
  debugPrint(
    '[FCM] Background message received: ${message.messageId} type=${message.data['type']}',
  );
  // Z-NOTIF-004: intentional no-op beyond init. Notification-field messages are
  // displayed by the OS; durable in-app docs are written by Cloud Functions
  // before FCM dispatch. Do not duplicate UI work here.
}

/// Notification service provider.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(authFirestoreProvider));
});

/// User notifications stream provider.
final userNotificationsProvider =
    StreamProvider.autoDispose.family<List<AppNotification>, String>((ref, userId) {
      return ref
          .watch(notificationServiceProvider)
          .listenToNotifications(userId);
    });

/// Unread notification count stream provider.
///
/// autoDispose with a grace window rather than plain autoDispose: this backs
/// the notification badge in the app shell, so a momentary drop to zero
/// listeners during a navigation transition would otherwise tear down the
/// listener and re-subscribe, making the badge flicker.
final unreadCountProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(timer.cancel);

  return ref.watch(notificationServiceProvider).listenToUnreadCount(userId);
});

/// Notification preferences provider.
final notificationPreferencesProvider =
    FutureProvider.family<NotificationPreferences, String>((ref, userId) async {
      return ref
          .watch(notificationServiceProvider)
          .getNotificationPreferences(userId);
    });
