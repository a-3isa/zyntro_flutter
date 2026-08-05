import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import 'cardio_activity_options.dart';
import 'live_participant_progress.dart';
import '../../../core/constants/constants.dart';
import '../../../services/session_service.dart';
import '../../auth/auth_providers.dart';
import '../../../services/voice_recording_service.dart';

import '../../../services/presence_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/session_analytics_service.dart';
import '../../../services/user_cache_service.dart';
import '../../../utils/offline_manager.dart';
import '../../../utils/retry_helper.dart';
import '../../../widgets/session_widgets.dart';
import 'widgets/session_room_animations.dart';
import '../../../widgets/shimmer_widgets.dart';
import '../../../widgets/connection_status_widget.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/session_error_banner.dart';
import '../../../utils/haptic_manager.dart';
import 'widgets/active_turn_screen.dart';
import 'widgets/waiting_turn_screen.dart';
import 'widgets/parallel_gym_view.dart';
import 'widgets/parallel_cardio_view.dart';
import 'widgets/gym_exercise_picker_sheet.dart';
import '../domain/gym_session_plan.dart';
import '../domain/turn_eligibility.dart';
import 'widgets/partner_left_dialog.dart';
import '../domain/turn_plan_progress.dart';
import '../domain/workout_score.dart';

/// Session room page for active workout sessions.
class SessionRoomPage extends ConsumerStatefulWidget {
  final String sessionId;
  final String type;
  final String? initialAudioUrl;
  final List<PlannedExercise>? plannedExercises;

  const SessionRoomPage({
    super.key,
    required this.sessionId,
    required this.type,
    this.initialAudioUrl,
    this.plannedExercises,
  });

  @override
  ConsumerState<SessionRoomPage> createState() => _SessionRoomPageState();
}

class _SessionRoomPageState extends ConsumerState<SessionRoomPage>
    with WidgetsBindingObserver {
  final _exerciseController = TextEditingController();

  // Error state
  String? _errorMessage;

  // Strength tracking controllers & focus
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _exerciseNameFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  // Cardio tracking controllers & focus
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _paceController = TextEditingController();
  final _distanceFocus = FocusNode();
  final _durationFocus = FocusNode();
  final _paceFocus = FocusNode();
  String? _cardioActivityType; // 'running' or 'cycling'

  // Workout type derived from session
  late WorkoutType _workoutType;

  // Local exercises state
  final List<Exercise> _exercises = [];
  String? _currentExercise;
  int _currentSetDuration = 0;
  bool _isLogging = false;

  // Turn-based active session state machine
  String? _currentTurnExercise; // exercise name chosen for current set
  int _currentSetNumber = 1; // which set the active user is on

  // Planned exercises (passed from start session page)
  List<PlannedExercise> _plannedExercises = [];
  String? _currentExerciseId;
  bool _isRecordingToggleInFlight = false;
  bool _stopRecordingAfterStart = false;
  bool _isProcessingBotTurn = false;
  String? _lastBotTurnKey;

  // Presence heartbeat — proves someone is still in the room so the session
  // does not expire underneath them. Refreshed faster than the staleness
  // threshold so one missed beat is tolerated.
  Timer? _presenceHeartbeatTimer;

  // Damped shared↔solo state. A partner who closes their app must not leave the
  // member stuck on a waiting screen, but a flaky connection must not strobe
  // the view either.
  final _soloDamper = SoloModeDamper();
  Timer? _soloReevaluationTimer;

  // Departures already announced, so the dialog raises once per partner rather
  // than on every snapshot re-emit.
  final _announcedDepartures = AnnouncedDepartures();
  bool _departureSeedDone = false;

  // Voice recording state
  bool _isRecording = false;
  bool _isUploadingVoice = false;
  double _voiceUploadProgress = 0;
  Duration _recordingDuration = Duration.zero;
  StreamSubscription<Duration>? _durationSubscription;

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingAudioUrl;
  // Dedicated one-shot player for the "your turn" cue so it never interrupts,
  // or is interrupted by, a partner voice note on _audioPlayer.
  final AudioPlayer _turnCuePlayer = AudioPlayer();

  // Auto-play queue
  final List<String> _audioQueue = [];
  bool _isPlayingQueue = false;

  // Connection status
  bool _isOffline = false;
  bool _isSyncing = false;
  int _queueCount = 0;
  int _initialQueueCount = 0;
  SyncProgress? _syncProgress;
  // _lastSyncTime removed as unused
  Timer? _queueCountTimer;
  StreamSubscription<SyncProgress>? _syncProgressSubscription;

  // Shared session timer
  Timer? _timerUpdateTimer;
  Duration _elapsedTime = Duration.zero;
  DateTime? _sessionStartTime;
  final bool _isPaused = false;

  // Autocomplete
  List<String> _recentExercises = [
    'Bench Press',
    'Squat',
    'Deadlift',
    'Overhead Press',
    'Pull Up',
  ]; // Mock for now, ideally fetch

  // Processed events for auto-play deduplication
  final Set<String> _processedVoiceEvents = {};
  DateTime? _lastProcessedEventTime;

  // Participant progress tracking
  final Map<String, LiveParticipantProgress> _participantProgress = {};

  // Session mode flags
  bool _isSoloSession = false;

  final int _eventLimit = 50;
  final List<TimelineEvent> _localPendingEvents = [];
  // Participant ids already requested for the activity strip; prevents a
  // refetch loop when a user doc is missing and the cache stays empty.
  final Set<String> _requestedParticipantNames = {};

  // Cached for use in dispose() — ref is invalid by the time dispose() is called
  String? _presenceUserId;
  PresenceService? _presenceServiceRef;

  bool _voiceNotesEnabled = true;

  StreamSubscription? _audioPlayerSubscription;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize workout type from widget.type
    _workoutType = WorkoutType.fromString(widget.type);

    // Pre-select cardio activity type based on workout type
    if (_workoutType == WorkoutType.running) {
      _cardioActivityType = 'running';
    } else if (_workoutType == WorkoutType.cycling) {
      _cardioActivityType = 'cycling';
    } else if (_workoutType == WorkoutType.swimming) {
      _cardioActivityType = 'swimming';
    } else if (_workoutType == WorkoutType.walking) {
      _cardioActivityType = 'walking';
    }

    // Load planned exercises if provided
    if (widget.plannedExercises != null &&
        widget.plannedExercises!.isNotEmpty) {
      _plannedExercises = List<PlannedExercise>.from(widget.plannedExercises!);
      _currentTurnExercise = _plannedExercises[0].name;
      _currentExerciseId = _plannedExercises[0].id;
    }

    _initPresence();
    _initConnectivity();
    _initSessionTimer();
    // Initialize marker to ignore historical events
    _lastProcessedEventTime = DateTime.now();

    // Listen to player complete
    _audioPlayerSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingAudioUrl = null;
        });
      }
    });

    if (widget.initialAudioUrl != null) {
      _audioQueue.add(widget.initialAudioUrl!);
      // Delay slightly to allow UI to build
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _processAudioQueue('Deep Link');
      });
    }

    // Load recent exercises for autocomplete
    Future.microtask(_loadRecentExercises);
    Future.microtask(_loadNotificationPreferences);
  }

  Future<void> _loadNotificationPreferences() async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    if (uid != null) {
      final prefs = await ref
          .read(notificationServiceProvider)
          .getNotificationPreferences(uid);
      if (mounted) {
        setState(() {
          _voiceNotesEnabled = prefs.voiceNotes;
        });
      }
    }
  }

  Future<void> _loadRecentExercises() async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    if (uid != null) {
      final exercises = await ref
          .read(sessionAnalyticsServiceProvider)
          .getRecentExercises(uid);
      if (mounted && exercises.isNotEmpty) {
        setState(() {
          _recentExercises = exercises;
        });
      }
    }
  }

  /// Initialize the shared session timer from Firestore session document.
  void _initSessionTimer() {
    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionStartTime != null && !_isPaused && mounted) {
        setState(() {
          // In real app, we might sync with server time
          _elapsedTime = DateTime.now().difference(_sessionStartTime!);

          // Milestone check
          if (_elapsedTime.inMinutes > 0 &&
              _elapsedTime.inMinutes % 30 == 0 &&
              _elapsedTime.inSeconds == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${_elapsedTime.inMinutes} minutes completed! ðŸ’ª',
                ),
              ),
            );
          }
        });
      }
    });
  }

  void _applySharedClockStart(DateTime? startedAt) {
    if (startedAt == null || !mounted) return;
    if (_sessionStartTime?.isAtSameMomentAs(startedAt) ?? false) return;

    final elapsed = DateTime.now().difference(startedAt);
    setState(() {
      _sessionStartTime = startedAt;
      _elapsedTime = elapsed.isNegative ? Duration.zero : elapsed;
    });
  }

  Future<void> _ensureSharedClockStarted(Session session) async {
    if (session.sharedClockStartedAt != null) {
      _applySharedClockStart(session.sharedClockStartedAt);
      return;
    }
    if (_sessionStartTime == null && mounted) {
      setState(() {
        _sessionStartTime = DateTime.now();
        _elapsedTime = Duration.zero;
      });
    }

    try {
      await ref
          .read(sessionServiceProvider)
          .startSharedSessionClock(widget.sessionId);
    } catch (e) {
      debugPrint('[SessionRoom] Failed to start shared session clock: $e');
    }
  }

  Future<void> _initPresence() async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    if (uid != null) {
      _presenceUserId = uid;
      _presenceServiceRef = ref.read(presenceServiceProvider);
      await _presenceServiceRef!.setOnline(widget.sessionId, uid);
      _startPresenceHeartbeat(uid);
    }
  }

  void _initConnectivity() {
    final offlineManager = ref.read(offlineManagerProvider);

    // Listen for connectivity changes
    _connectivitySubscription = offlineManager.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (mounted) {
        final wasOffline = _isOffline;
        setState(() => _isOffline = !isOnline);

        // When coming back online, start tracking sync progress
        if (wasOffline && isOnline) {
          _startSyncTracking();
        }
      }
    });

    // Listen for sync progress updates
    _syncProgressSubscription = offlineManager.onSyncProgress.listen((
      progress,
    ) {
      if (mounted) {
        final wasSyncing = _isSyncing; // Capture before updating
        setState(() {
          _syncProgress = progress;
          _isSyncing = progress.isSyncing;
          _queueCount = progress.remaining;

          // Track initial count when sync starts
          if (progress.isSyncing && _initialQueueCount == 0) {
            _initialQueueCount = progress.total;
          }
        });

        // Record sync completion time (check after setState)
        if (!progress.isSyncing && wasSyncing) {
          // Clear local pending events after successful sync
          _reconcileLocalEvents();
        }
      }
    });

    // Periodically update queue count
    _queueCountTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateQueueCount();
    });

    // Initial queue count check
    _updateQueueCount();
  }

  void _startSyncTracking() async {
    final offlineManager = ref.read(offlineManagerProvider);
    final count = await offlineManager.getQueueCount();
    if (mounted && count > 0) {
      setState(() {
        _initialQueueCount = count;
        _queueCount = count;
      });
    }
  }

  Future<void> _updateQueueCount() async {
    final offlineManager = ref.read(offlineManagerProvider);
    final count = await offlineManager.getQueueCount();
    if (mounted) {
      setState(() => _queueCount = count);
    }
  }

  /// Reconcile local pending events with server events after sync.
  void _reconcileLocalEvents() {
    // Mark local events as synced and schedule removal
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _localPendingEvents.clear();
        });
      }
    });
  }

  /// Show detailed queue status dialog.
  void _showQueueStatusDialog() async {
    final offlineManager = ref.read(offlineManagerProvider);
    final queue = await offlineManager.getQueue();
    final failedOps = await offlineManager.getFailedOperations();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Status'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending operations: ${queue.length}'),
              const SizedBox(height: 8),
              if (queue.isNotEmpty) ...[
                const Text(
                  'Recent pending:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...queue
                    .take(5)
                    .map(
                      (op) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text(
                          'â€¢ ${op.type} (${_formatTimeAgo(op.timestamp)})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
              ],
              if (failedOps.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Failed operations: ${failedOps.length}',
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (failedOps.isNotEmpty)
            TextButton(
              onPressed: () async {
                await offlineManager.clearFailedOperations();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Clear Failed'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Announces a partner leaving, once, to the member still in the room.
  ///
  /// Only for departures that happen while they are watching. A partner who
  /// left before they opened the session is seeded as already-seen: the
  /// avatar's "left" state tells them, and a dialog about something that
  /// happened while they were away would be noise.
  ///
  /// Dismissing is equivalent to carrying on — this never ends the member's own
  /// session for them.
  void _announceDeparturesIfNeeded(Session session, String currentUserId) {
    final departed =
        session.endedParticipants.where((id) => id != currentUserId).toList();

    if (!_departureSeedDone) {
      _departureSeedDone = true;
      _announcedDepartures.markSeen(departed);
      return;
    }

    final fresh = _announcedDepartures.takeUnannounced(departed);
    if (fresh.isEmpty) return;

    // Out of the build phase — showDialog cannot run during a rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final leaverId = fresh.first;
      final leaver = await ref.read(userCacheServiceProvider).getUser(leaverId);
      if (!mounted) return;

      final choice = await PartnerLeftDialog.show(
        context,
        partnerName: leaver?.displayName ?? 'Your partner',
      );

      if (choice == PartnerLeftChoice.finishToo && mounted) {
        await _handleFinishSession();
      }
    });
  }

  /// How a partner should currently be rendered — present, temporarily away,
  /// or gone for good.
  ParticipantStanding _partnerStanding(Session session, String partnerId) {
    if (partnerId.isEmpty) return ParticipantStanding.active;

    final presence =
        ref.watch(sessionPresenceProvider(widget.sessionId)).value ??
        const <UserPresence>[];

    return standingOf(
      userId: partnerId,
      session: session,
      presence: {for (final p in presence) p.userId: p},
      now: DateTime.now().toUtc(),
    );
  }

  /// Re-evaluates whether the member is effectively training alone.
  ///
  /// Called on every presence change. A partner who closed their app must not
  /// leave the member stuck on a waiting screen for someone who is never going
  /// to take their turn — but a connection blip must not flip the view either,
  /// hence the damper.
  bool _evaluateSolo(Session session, String currentUserId) {
    final presence =
        ref.watch(sessionPresenceProvider(widget.sessionId)).value ??
        const <UserPresence>[];

    final byUser = {for (final p in presence) p.userId: p};
    final now = DateTime.now().toUtc();

    final rawSolo = isEffectivelySolo(
      userId: currentUserId,
      session: session,
      presence: byUser,
      now: now,
    );

    final damped = _soloDamper.update(rawSolo: rawSolo, now: now);

    // Presence streams only push when something changes, so without this the
    // grace period could elapse with nothing left to notice it.
    final pending = _soloDamper.timeUntilSolo;
    if (pending != null && (_soloReevaluationTimer?.isActive != true)) {
      _soloReevaluationTimer = Timer(pending, () {
        if (mounted) setState(() {});
      });
    } else if (pending == null) {
      _soloReevaluationTimer?.cancel();
    }

    return damped;
  }

  void _startPresenceHeartbeat(String userId) {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = ref
        .read(presenceServiceProvider)
        .startHeartbeat(widget.sessionId, userId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    if (uid == null) return;

    final presenceService = ref.read(presenceServiceProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        presenceService.setOnline(widget.sessionId, uid);
        _startPresenceHeartbeat(uid);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        presenceService.setAway(widget.sessionId, uid);
        _presenceHeartbeatTimer?.cancel();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Best-effort only: `detached` is frequently skipped when the app is
        // swiped out of the recent-apps list, and never fires on an OS kill.
        // Nothing here may be load-bearing.
        //
        // This used to call endSession(), which destroyed the very session the
        // member wanted to return to — the whole reason resume was impossible.
        // Expiry is now the scheduled `expireStaleSessions` Function's job, so
        // a session outlives the app and can be resumed on the next cold start.
        presenceService.setAway(widget.sessionId, uid);
        _presenceHeartbeatTimer?.cancel();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exerciseController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _paceController.dispose();
    _audioPlayer.dispose();
    _turnCuePlayer.dispose();
    _timerUpdateTimer?.cancel();
    _durationSubscription?.cancel();
    _queueCountTimer?.cancel();
    _syncProgressSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _audioPlayerSubscription?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _soloReevaluationTimer?.cancel();
    _setOfflinePresence();

    _exerciseNameFocus.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    _distanceFocus.dispose();
    _durationFocus.dispose();
    _paceFocus.dispose();

    super.dispose();
  }

  Future<void> _setOfflinePresence() async {
    final uid = _presenceUserId;
    final service = _presenceServiceRef;
    if (uid != null && service != null) {
      await service.setOffline(widget.sessionId, uid);
    }
  }

  // Monitor events for voice notes
  void _monitorVoiceNotes(List<TimelineEvent> events) async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    if (uid == null) return;

    // Get perfs inside method or cache them
    if (!_voiceNotesEnabled) return;

    for (final event in events) {
      if (event.type == SessionEventType.voiceNote &&
          event.userId != uid &&
          !_processedVoiceEvents.contains(event.id)) {
        // Skip historical events
        if (_lastProcessedEventTime != null &&
            event.timestamp.isBefore(_lastProcessedEventTime!)) {
          continue;
        }

        _processedVoiceEvents.add(event.id);

        // Update marker
        if (_lastProcessedEventTime == null ||
            event.timestamp.isAfter(_lastProcessedEventTime!)) {
          _lastProcessedEventTime = event.timestamp;
        }

        final url = event.data?['audioUrl'] as String?;
        if (url != null) {
          // Determine sender name
          String senderName = 'A friend'; // Ideally resolve from user cache
          // Add to queue
          _audioQueue.add(url);
          _processAudioQueue(senderName);
        }
      }
    }
  }

  /// Update participant progress from service map.
  void _updateLiveParticipantProgressFromMap(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final newProgress = <String, LiveParticipantProgress>{};

    data.forEach((userId, stats) {
      if (stats is Map<String, dynamic>) {
        DateTime? lastActivity;
        if (stats['lastActivity'] != null) {
          try {
            lastActivity = DateTime.parse(stats['lastActivity']);
          } catch (_) {}
        }

        newProgress[userId] = LiveParticipantProgress(
          // Strength metrics
          currentExercise: stats['currentExercise'] as String? ?? '',
          totalSets: stats['totalSets'] as int? ?? 0,
          totalVolume: (stats['totalVolume'] as num?)?.toDouble() ?? 0.0,
          lastWeight: (stats['lastWeight'] as num?)?.toDouble(),
          lastReps: stats['lastReps'] as int?,
          lastSetSeconds: stats['lastSetSeconds'] as int?,
          // Cardio metrics
          totalDistance: (stats['totalDistance'] as num?)?.toDouble() ?? 0.0,
          totalDuration: stats['totalDuration'] as int? ?? 0,
          averagePace: stats['averagePace'] as String?,
          activityType: stats['activityType'] as String?,
          // Shared
          lastActivity: lastActivity,
        );
      }
    });

    // Only update if changed (basic check or rely on riverpod equality)
    setState(() {
      _participantProgress.clear();
      _participantProgress.addAll(newProgress);
    });
  }

  Future<void> _processAudioQueue(String senderName) async {
    if (_isPlayingQueue || _audioQueue.isEmpty) return;

    _isPlayingQueue = true;
    final url = _audioQueue.removeAt(0);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ðŸŽ¤ Playing voice note from $senderName'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await _playAudio(url);
    _isPlayingQueue = false;
    _processAudioQueue(senderName); // Process next
  }

  /// Wrapper that lets new turn-based/parallel widgets submit a set
  /// with explicit parameters. Reuses the existing controller-based flow
  /// by mutating the controllers and delegating to [_handleLogSetFromControllers].
  Future<bool> _handleLogSet({
    required String exercise,
    required double weight,
    required int reps,
    String? exerciseId,
    int durationSeconds = 0,
  }) async {
    _currentExercise = exercise;
    _currentExerciseId = exerciseId;
    _currentSetDuration = durationSeconds;
    _weightController.text = weight.toString();
    _repsController.text = reps.toString();
    return _handleLogSetFromControllers();
  }

  Future<bool> _handleLogSetFromControllers() async {
    if (_currentExercise == null) return false;

    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid weight and reps')),
      );
      return false;
    }

    // Check availability based on turn-based rules
    final session = ref
        .read(currentSessionProvider(widget.sessionId))
        .value;
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;

    if (session != null &&
        session.derivedMode == SessionMode.turnBased &&
        !_isSoloSession &&
        session.activeUserId != uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("It's not your turn yet")),
      );
      return false;
    }

    // Add to recent exercises for autocomplete
    if (!_recentExercises.contains(_currentExercise!)) {
      _recentExercises.insert(0, _currentExercise!);
      if (_recentExercises.length > 10) _recentExercises.removeLast();
    }

    setState(() => _isLogging = true);

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.value?.id;
      if (uid == null) return false;

      // Add to local exercises
      final existingIndex = _exercises.indexWhere(
        (e) => e.name == _currentExercise,
      );
      if (existingIndex >= 0) {
        _exercises[existingIndex] = _exercises[existingIndex].copyWith(
          sets: [
            ..._exercises[existingIndex].sets,
            SetData(weight: weight, reps: reps, durationSeconds: _currentSetDuration),
          ],
        );
      } else {
        _exercises.add(
          Exercise(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: _currentExercise!,
            sets: [SetData(weight: weight, reps: reps, durationSeconds: _currentSetDuration)],
          ),
        );
      }

      // Optimistic update — always immediate, regardless of connectivity.
      final currentProgress = _participantProgress[uid];
      final newTotalSets = (currentProgress?.totalSets ?? 0) + 1;
      final newVolume = (currentProgress?.totalVolume ?? 0) + (weight * reps);
      final localEvent = TimelineEvent(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        type: SessionEventType.setLogged,
        userId: uid,
        text: '$_currentExercise: ${weight}kg x $reps reps',
        timestamp: DateTime.now(),
        data: {
          'exercise': _currentExercise,
          if (_currentExerciseId != null) 'exerciseId': _currentExerciseId,
          'weight': weight,
          'reps': reps,
          'durationSeconds': _currentSetDuration,
        },
      );
      setState(() {
        _participantProgress[uid] = LiveParticipantProgress(
          currentExercise: _currentExercise!,
          totalSets: newTotalSets,
          totalVolume: newVolume,
          lastActivity: DateTime.now(),
          lastWeight: weight,
          lastReps: reps,
          lastSetSeconds: _currentSetDuration,
        );
        _localPendingEvents.insert(0, localEvent);
      });

      // Sync to backend.
      if (_isOffline) {
        await ref.read(offlineManagerProvider).queueOperation('session_event', {
          'sessionId': widget.sessionId,
          'type': SessionEventType.setLogged.value,
          'userId': uid,
          'text': '$_currentExercise: ${weight}kg x $reps reps',
          'data': {
            'exercise': _currentExercise,
            if (_currentExerciseId != null) 'exerciseId': _currentExerciseId,
            'weight': weight,
            'reps': reps,
            'durationSeconds': _currentSetDuration,
          },
        });
      } else {
        try {
          await ref.read(sessionServiceProvider).addSessionEvent(
            sessionId: widget.sessionId,
            type: SessionEventType.setLogged,
            userId: uid,
            text: '$_currentExercise: ${weight}kg x $reps reps',
            data: {
              'exercise': _currentExercise,
              if (_currentExerciseId != null) 'exerciseId': _currentExerciseId,
              'weight': weight,
              'reps': reps,
              'durationSeconds': _currentSetDuration,
            },
          );
          // Server event is arriving via stream — drop the local placeholder so
          // there is no transient double-count in _completedSetsByUserAndExercise.
          if (mounted) setState(() => _localPendingEvents.remove(localEvent));
          await HapticFeedback.mediumImpact();
        } catch (e) {
          // Network call failed — keep the local event for display and queue it.
          await ref.read(offlineManagerProvider).queueOperation(
            'session_event',
            {
              'sessionId': widget.sessionId,
              'type': SessionEventType.setLogged.value,
              'userId': uid,
              'text': '$_currentExercise: ${weight}kg x $reps reps',
              'data': {
                'exercise': _currentExercise,
                if (_currentExerciseId != null) 'exerciseId': _currentExerciseId,
                'weight': weight,
                'reps': reps,
                'durationSeconds': _currentSetDuration,
              },
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved offline (Sync pending)')),
            );
          }
        }
      }

      // Clear inputs but keep exercise name for convenience? No, usually clear reps/weight
      _weightController.clear();
      _repsController.clear();

      // Logging a set stamps session activity server-side (see
      // SessionService.activityStamp), which is what pushes expiry out. No
      // client-side timer is involved any more.

      // Advance planned exercise list (per-set cycling through plan)
      if (_plannedExercises.isNotEmpty) {
        final totalLogged = _participantProgress.values.fold<int>(
          0,
          (s, p) => s + p.totalSets,
        );
        // Figure out which exercise index we're on based on total sets and sets per exercise
        // Simple approach: advance to next exercise every time current exercise's sets match plan order
        final nextIndex = (totalLogged) % _plannedExercises.length;
        final nextExercise = _plannedExercises[nextIndex];
        if (nextExercise.name != _currentTurnExercise) {
          setState(() {
            _currentTurnExercise = nextExercise.name;
            _currentExerciseId = nextExercise.id;
          });
        }
      }

      setState(() {});
      return true;
    } finally {
      setState(() => _isLogging = false);
    }
  }

  /// Parameterized cardio logger used by the new parallel-mode cardio view.
  /// Delegates to [_handleLogCardioFromControllers] by mutating controllers.
  Future<void> _handleLogCardio({
    required double distance,
    required int durationSeconds,
    required String activityType,
  }) async {
    _cardioActivityType = activityType;
    _distanceController.text = distance.toString();
    // Existing flow expects minutes in the duration controller.
    final minutes = (durationSeconds / 60).round();
    _durationController.text = minutes.toString();
    _paceController.clear();
    await _handleLogCardioFromControllers();
  }

  Map<String, Map<String, int>> _completedSetsByUserAndExercise(
    List<TimelineEvent> events,
  ) {
    final counts = <String, Map<String, int>>{};
    for (final event in events) {
      if (event.type != SessionEventType.setLogged) continue;
      final exerciseKey =
          event.data?['exerciseId']?.toString() ??
          event.data?['exercise']?.toString();
      if (exerciseKey == null || exerciseKey.isEmpty) continue;
      final userCounts = counts.putIfAbsent(
        event.userId,
        () => <String, int>{},
      );
      userCounts[exerciseKey] = (userCounts[exerciseKey] ?? 0) + 1;
    }
    return counts;
  }

  GymSessionPlan _localPlanFor(String userId, GymSessionPlanSource source) {
    return GymSessionPlan(
      userId: userId,
      workoutType: _workoutType,
      source: source,
      isReady: true,
      exercises: List<PlannedExercise>.from(_plannedExercises),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _handleTurnAfterLoggedSet({
    required Session session,
    required String currentUserId,
    required Map<String, GymSessionPlan> plans,
    required Map<String, Map<String, int>> counts,
    PlannedExercise? plannedExercise,
  }) async {
    if (session.derivedMode != SessionMode.turnBased || _isSoloSession) return;

    if (plans.isEmpty || plannedExercise == null) {
      await ref
          .read(sessionServiceProvider)
          .switchTurn(widget.sessionId, currentUserId);
      return;
    }

    final nextCounts = <String, Map<String, int>>{
      for (final entry in counts.entries)
        entry.key: Map<String, int>.from(entry.value),
    };
    nextCounts[currentUserId] = TurnPlanProgress.incrementedCounts(
      counts: nextCounts[currentUserId] ?? const {},
      exercise: plannedExercise,
    );

    final nextActiveUserId = TurnPlanProgress.nextActiveParticipant(
      currentUserId: currentUserId,
      participants: session.participants,
      plans: plans,
      completedSetsByUserAndExercise: nextCounts,
    );
    if (nextActiveUserId != null && nextActiveUserId != currentUserId) {
      await ref
          .read(sessionServiceProvider)
          .switchTurn(widget.sessionId, currentUserId);
    } else {
      setState(() {});
    }
  }

  void _scheduleBotTurnIfNeeded({
    required Session session,
    required Map<String, GymSessionPlan> plans,
    required List<TimelineEvent> events,
  }) {
    if (session.partnerKind != PairedPartnerKind.bot ||
        session.activeUserId != pairedBotFriendId ||
        _isProcessingBotTurn) {
      return;
    }

    final botPlan = plans[pairedBotFriendId];
    if (botPlan == null) return;
    final counts = _completedSetsByUserAndExercise(events);
    final botState = TurnPlanProgress.participantState(
      botPlan,
      counts[pairedBotFriendId] ?? const {},
    );
    final botExercise = botState.currentExercise;
    if (botState.isComplete || botExercise == null) return;

    final turnKey =
        '${session.id}:${botExercise.id}:${botState.currentSetNumber}';
    if (_lastBotTurnKey == turnKey) return;
    _lastBotTurnKey = turnKey;
    _isProcessingBotTurn = true;

    Future<void>(() async {
      final bot = BotFriend.gymSimulation();
      await Future<void>.delayed(Duration(seconds: bot.gymSetSeconds));
      if (!mounted) return;
      final latestSession = ref
          .read(currentSessionProvider(widget.sessionId))
          .value;
      if (latestSession?.activeUserId != pairedBotFriendId) {
        _isProcessingBotTurn = false;
        return;
      }

      try {
        await ref
            .read(sessionServiceProvider)
            .addSessionEvent(
              sessionId: widget.sessionId,
              type: SessionEventType.setLogged,
              userId: pairedBotFriendId,
              text:
                  '${botExercise.name}: ${bot.gymWeightKg}kg x ${bot.gymReps} reps',
              data: {
                'exercise': botExercise.name,
                'exerciseId': botExercise.id,
                'weight': bot.gymWeightKg,
                'reps': bot.gymReps,
                'durationSeconds': bot.gymSetSeconds,
                'simulated': true,
              },
            );

        final nextCounts = <String, Map<String, int>>{
          for (final entry in counts.entries)
            entry.key: Map<String, int>.from(entry.value),
        };
        nextCounts[pairedBotFriendId] = TurnPlanProgress.incrementedCounts(
          counts: nextCounts[pairedBotFriendId] ?? const {},
          exercise: botExercise,
        );
        final nextActiveUserId = TurnPlanProgress.nextActiveParticipant(
          currentUserId: pairedBotFriendId,
          participants: latestSession?.participants ?? session.participants,
          plans: plans,
          completedSetsByUserAndExercise: nextCounts,
        );
        if (nextActiveUserId != null && nextActiveUserId != pairedBotFriendId) {
          await ref
              .read(sessionServiceProvider)
              .switchTurn(widget.sessionId, pairedBotFriendId);
        }
      } finally {
        _isProcessingBotTurn = false;
      }
    });
  }

  /// Handle logging a cardio activity entry.
  Future<void> _handleLogCardioFromControllers() async {
    if (_cardioActivityType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an activity type')),
      );
      return;
    }

    final distance = double.tryParse(_distanceController.text);
    final duration = int.tryParse(_durationController.text);
    final pace = _paceController.text.trim();

    if (distance == null || distance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid distance')),
      );
      return;
    }

    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid duration')),
      );
      return;
    }

    // Check availability based on turn-based rules
    final session = ref
        .read(currentSessionProvider(widget.sessionId))
        .value;
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;

    if (session != null &&
        session.derivedMode == SessionMode.turnBased &&
        !_isSoloSession &&
        session.activeUserId != uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("It's not your turn yet")),
      );
      return;
    }

    setState(() => _isLogging = true);

    try {
      if (uid == null) return;

      // Calculate pace if not provided
      String calculatedPace = pace;
      if (pace.isEmpty && distance > 0) {
        final paceMinutes = duration / distance;
        final paceMinsPart = paceMinutes.floor();
        final paceSecsPart = ((paceMinutes - paceMinsPart) * 60).round();
        calculatedPace =
            '$paceMinsPart:${paceSecsPart.toString().padLeft(2, '0')}/km';
      }

      final activityName = cardioActivityLabel(_cardioActivityType);
      final eventText =
          '$activityName: ${distance.toStringAsFixed(2)}km in ${duration}min';

      // Optimistic update — immediate regardless of connectivity.
      final currentProgress = _participantProgress[uid];
      final newDistance = (currentProgress?.totalDistance ?? 0) + distance;
      final newDuration = (currentProgress?.totalDuration ?? 0) + duration;
      final localEvent = TimelineEvent(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        type: SessionEventType.cardioEntry,
        userId: uid,
        text: eventText,
        timestamp: DateTime.now(),
        data: {
          'activityType': _cardioActivityType,
          'distance': distance,
          'duration': duration,
          'pace': calculatedPace,
        },
      );
      setState(() {
        _participantProgress[uid] = LiveParticipantProgress(
          activityType: _cardioActivityType,
          totalDistance: newDistance,
          totalDuration: newDuration,
          averagePace: calculatedPace,
          lastActivity: DateTime.now(),
        );
        _localPendingEvents.insert(0, localEvent);
      });

      // Sync to backend.
      if (_isOffline) {
        await ref.read(offlineManagerProvider).queueOperation('session_event', {
          'sessionId': widget.sessionId,
          'type': SessionEventType.cardioEntry.value,
          'userId': uid,
          'text': eventText,
          'data': {
            'activityType': _cardioActivityType,
            'distance': distance,
            'duration': duration,
            'pace': calculatedPace,
          },
        });
      } else {
        try {
          await ref.read(sessionServiceProvider).addSessionEvent(
            sessionId: widget.sessionId,
            type: SessionEventType.cardioEntry,
            userId: uid,
            text: eventText,
            data: {
              'activityType': _cardioActivityType,
              'distance': distance,
              'duration': duration,
              'pace': calculatedPace,
            },
          );
          // Drop local placeholder once the server event is incoming via stream.
          if (mounted) setState(() => _localPendingEvents.remove(localEvent));
          await HapticFeedback.mediumImpact();
        } catch (e) {
          // Network call failed — keep the local event and queue for retry.
          await ref.read(offlineManagerProvider).queueOperation(
            'session_event',
            {
              'sessionId': widget.sessionId,
              'type': SessionEventType.cardioEntry.value,
              'userId': uid,
              'text': eventText,
              'data': {
                'activityType': _cardioActivityType,
                'distance': distance,
                'duration': duration,
                'pace': calculatedPace,
              },
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved offline (Sync pending)')),
            );
          }
        }
      }

      // Clear inputs
      _distanceController.clear();
      _durationController.clear();
      _paceController.clear();

      setState(() {});
    } finally {
      setState(() => _isLogging = false);
    }
  }

  // Voice recording handlers
  Future<void> _toggleRecording() async {
    if (_isRecordingToggleInFlight) {
      if (!_isRecording) _stopRecordingAfterStart = true;
      return;
    }
    _isRecordingToggleInFlight = true;
    final voiceService = ref.read(voiceRecordingServiceProvider);

    try {
      if (_isRecording) {
        await _stopAndUploadRecording(voiceService);
      } else {
        await _startRecording(voiceService);
      }
    } finally {
      _isRecordingToggleInFlight = false;
      if (_stopRecordingAfterStart && _isRecording) {
        _stopRecordingAfterStart = false;
        await _toggleRecording();
      } else {
        _stopRecordingAfterStart = false;
      }
    }
  }

  Future<void> _startRecording(VoiceRecordingService voiceService) async {
    final hasPermission = await voiceService.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        // Show permission dialog with option to open settings
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Microphone Permission Required'),
            content: const Text(
              'Voice notes require microphone access. Would you like to open settings to grant permission?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (shouldOpenSettings == true && mounted) {
          // Note: For production, you'd use a package like app_settings
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please enable microphone permission in app settings',
              ),
            ),
          );
        }
      }
      return;
    }

    final path = await voiceService.startRecording();
    if (path != null) {
      // Subscribe to duration updates
      _durationSubscription?.cancel();
      _durationSubscription = voiceService.durationStream.listen((duration) {
        if (mounted) {
          setState(() => _recordingDuration = duration);
        }
      });
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _stopAndUploadRecording(
    VoiceRecordingService voiceService,
  ) async {
    // Capture duration before stopping
    final recordedDuration = _recordingDuration;

    // Cancel duration subscription
    _durationSubscription?.cancel();
    _durationSubscription = null;

    setState(() => _isRecording = false);
    HapticFeedback.selectionClick();

    final path = await voiceService.stopRecording();
    if (path == null) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });
      }
      return;
    }

    setState(() {
      _isUploadingVoice = true;
      _voiceUploadProgress = 0;
    });

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.value?.id;
      if (uid == null) return;

      // Calculate duration in seconds for storage
      final durationSeconds = recordedDuration.inMilliseconds / 1000.0;

      if (_isOffline) {
        await ref
            .read(offlineManagerProvider)
            .queueOperation('voice_note_upload', {
              'filePath': path,
              'sessionId': widget.sessionId,
              'userId': uid,
              'duration': durationSeconds,
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice note queued (Offline)')),
          );
        }
      } else {
        final storageService = ref.read(storageServiceProvider);
        final sessionService = ref.read(sessionServiceProvider);

        final audioUrl = await storageService.uploadVoiceNote(
          filePath: path,
          sessionId: widget.sessionId,
          onProgress: (progress) {
            if (mounted) setState(() => _voiceUploadProgress = progress);
          },
        );

        // Create Firestore session event with audio URL and duration
        try {
          await sessionService.addSessionEvent(
            sessionId: widget.sessionId,
            type: SessionEventType.voiceNote,
            userId: uid,
            text: 'sent a voice message',
            data: {'audioUrl': audioUrl, 'duration': durationSeconds},
          );
        } catch (e) {
          debugPrint('[SessionRoom] Error creating voice note event: $e');
          // Queue for offline sync if event creation fails
          await ref.read(offlineManagerProvider).queueOperation(
            'session_event',
            {
              'sessionId': widget.sessionId,
              'type': SessionEventType.voiceNote.value,
              'userId': uid,
              'text': 'sent a voice message',
              'data': {'audioUrl': audioUrl, 'duration': durationSeconds},
            },
          );
        }

        // Notify partner
        final session = await sessionService.getSession(widget.sessionId);
        if (session != null) {
          final userDoc = await ref
              .read(authFirestoreProvider)
              .collection('users')
              .doc(uid)
              .get();
          final currentUserName = userDoc.data()?['displayName'] ?? 'User';

          // Notify all other participants
          final recipients = session.participants.where((id) => id != uid);

          for (final recipientId in recipients) {
            unawaited(
              ref
                  .read(notificationServiceProvider)
                  .notifyVoiceNote(
                    recipientId: recipientId,
                    senderName: currentUserName,
                    sessionId: widget.sessionId,
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
      }

      if (mounted) {
        // Optionally show sent confirmation
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingVoice = false;
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  /// "It's your turn" cue — physical, not a banner: a distinct double buzz plus
  /// a short weight-plate clank. The sound is skipped while a partner voice note
  /// is playing so it never cuts one off; the haptic always fires.
  Future<void> _signalMyTurn() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    await HapticFeedback.heavyImpact();

    if (_playingAudioUrl != null) return;
    try {
      await _turnCuePlayer.stop();
      await _turnCuePlayer.play(AssetSource('sounds/turn_start.wav'));
    } catch (e) {
      debugPrint('[SessionRoom] turn cue sound failed: $e');
    }
  }

  // Play audio from URL with loading state and retry
  Future<void> _playAudio(String url) async {
    try {
      if (_playingAudioUrl == url) {
        // Stop if already playing
        await _audioPlayer.stop();
        setState(() {
          _playingAudioUrl = null;
        });
      } else {
        // Show loading state

        // Use withRetryBackoff for robust retry with exponential backoff
        await withRetryBackoff(
          () async {
            await _audioPlayer.play(UrlSource(url));
          },
          maxAttempts: 3,
          baseDelay: const Duration(seconds: 1),
          multiplier: 2.0,
        );

        setState(() {
          _playingAudioUrl = url;
        });
        // Listener is set up in initState
      }
    } catch (e) {
      debugPrint('[SessionRoom] Error playing audio after retries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to play audio'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _playAudio(url),
            ),
          ),
        );
      }
    }
  }

  /// Dispatches to turn-based or parallel UIs when we have a session,
  /// otherwise falls back to the legacy monolithic [_buildInputSection].
  Widget _buildDispatchedInputSection() {
    final session = ref
        .watch(currentSessionProvider(widget.sessionId))
        .value;
    final uid = ref.watch(authSessionProvider).value?.id;
    if (session == null || uid == null) {
      return _buildInputSection();
    }
    // Solo sessions: with a plan, always show the turn view (user is always active).
    if (_isSoloSession) {
      if (_plannedExercises.isNotEmpty) {
        final events = [
          ...?ref.watch(sessionEventsProvider(widget.sessionId)).value,
          ..._localPendingEvents,
        ];
        final soloPlans = {
          uid: _localPlanFor(uid, GymSessionPlanSource.hostTemplate),
        };
        final counts = _completedSetsByUserAndExercise(events);
        if (TurnPlanProgress.isSessionComplete(
          plans: soloPlans,
          completedSetsByUserAndExercise: counts,
        )) {
          return _buildPlanCompleteView(session, uid, soloPlans);
        }
        return _buildActiveTurnView(
          session, uid, soloPlans, soloPlans[uid],
          counts[uid] ?? const {}, counts,
        );
      }
      return _buildInputSection();
    }

    final events = [
      ...?ref.watch(sessionEventsProvider(widget.sessionId)).value,
      ..._localPendingEvents,
    ];
    final plans = <String, GymSessionPlan>{};
    for (final participantId in session.participants) {
      final plan = ref
          .watch(
            gymSessionPlanProvider((
              sessionId: widget.sessionId,
              userId: participantId,
            )),
          )
          .value;
      if (plan != null && plan.exercises.isNotEmpty) {
        plans[participantId] = plan;
      }
    }

    if (_plannedExercises.isNotEmpty && !plans.containsKey(uid)) {
      plans[uid] = _localPlanFor(uid, GymSessionPlanSource.hostTemplate);
    }
    if (session.partnerKind == PairedPartnerKind.bot &&
        _plannedExercises.isNotEmpty &&
        !plans.containsKey(pairedBotFriendId)) {
      plans[pairedBotFriendId] = SessionService.botGymPlanFromHostPlan(
        plans[uid] ?? _localPlanFor(uid, GymSessionPlanSource.hostTemplate),
      );
    }

    if (session.activeUserId == pairedBotFriendId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleBotTurnIfNeeded(
          session: session,
          plans: plans,
          events: events,
        );
      });
    }

    return _buildSessionBody(session, uid, plans, events);
  }

  /// Main dispatch: switches on [Session.derivedMode] and the participant's
  /// workout type to pick between the turn-based and parallel widget trees.
  Widget _buildSessionBody(
    Session session,
    String currentUserId,
    Map<String, GymSessionPlan> plans,
    List<TimelineEvent> events,
  ) {
    // Applies to both modes: a partner walking out of a parallel session is
    // just as much news as one walking out of a turn-based one.
    _announceDeparturesIfNeeded(session, currentUserId);

    switch (session.derivedMode) {
      case SessionMode.turnBased:
        final counts = _completedSetsByUserAndExercise(events);
        if (plans.isNotEmpty &&
            TurnPlanProgress.isSessionComplete(
              plans: plans,
              completedSetsByUserAndExercise: counts,
            )) {
          return _buildPlanCompleteView(session, currentUserId, plans);
        }
        // Whoever the session thinks holds the turn, a member training alone
        // takes it. Otherwise closing one app would strand the other on a
        // waiting screen for a partner who is never going to act.
        //
        // Presentation-layer only — `derivedMode` is untouched, so the session
        // reverts to shared on its own the moment the partner comes back.
        final trainingAlone = _evaluateSolo(session, currentUserId);
        final isMyTurn = session.activeUserId == currentUserId || trainingAlone;
        if (isMyTurn) {
          return _buildActiveTurnView(
            session,
            currentUserId,
            plans,
            plans[currentUserId],
            counts[currentUserId] ?? const {},
            counts,
          );
        } else {
          return _buildWaitingTurnView(session, currentUserId, plans, counts);
        }
      case SessionMode.parallel:
        final myType = session.participantTypes[currentUserId] ?? widget.type;
        final workoutType = WorkoutType.fromString(myType);
        if (workoutType.isCardio || workoutType.requiresDistanceTracking) {
          return _buildParallelCardioView(session, currentUserId);
        } else {
          return _buildParallelGymView(session, currentUserId);
        }
    }
  }

  Widget _buildActiveTurnView(
    Session session,
    String currentUserId,
    Map<String, GymSessionPlan> plans,
    GymSessionPlan? plan,
    Map<String, int> currentUserCounts,
    Map<String, Map<String, int>> allCounts,
  ) {
    final plannedState = plan != null
        ? TurnPlanProgress.participantState(plan, currentUserCounts)
        : null;
    final plannedExercise = plannedState?.currentExercise;
    final exerciseName =
        plannedExercise?.name ?? _currentTurnExercise ?? 'Workout';
    final setNumber = plannedState?.currentSetNumber ?? _currentSetNumber;

    // Pre-fill last reps/weight for this exercise so users don't re-enter if unchanged
    final exerciseEntry = _exercises.firstWhere(
      (e) => e.name == exerciseName,
      orElse: () => Exercise(id: '', name: exerciseName, sets: const []),
    );
    final lastSet = exerciseEntry.sets.isNotEmpty ? exerciseEntry.sets.last : null;

    return ActiveTurnScreen(
      exerciseName: exerciseName,
      setNumber: setNumber,
      lastReps: lastSet?.reps ?? 0,
      lastWeight: lastSet?.weight ?? 0.0,
      onTimerStart: () {
        _ensureSharedClockStarted(session);
        // Stamp the per-set start so the waiting partner's timer counts this
        // set from now, not from the session start.
        ref
            .read(sessionServiceProvider)
            .setActiveSetStarted(widget.sessionId, started: true);
      },
      onSetSubmit:
          ({
            required int reps,
            required double weight,
            required int durationSeconds,
          }) async {
            final logged = await _handleLogSet(
              exercise: exerciseName,
              exerciseId: plannedExercise?.id,
              weight: weight,
              reps: reps,
              durationSeconds: durationSeconds,
            );
            if (!logged) return;
            // Set finished — clear the per-set start so the partner's timer
            // freezes on the completed set until the next START.
            unawaited(
              ref
                  .read(sessionServiceProvider)
                  .setActiveSetStarted(widget.sessionId, started: false),
            );
            await _handleTurnAfterLoggedSet(
              session: session,
              currentUserId: currentUserId,
              plans: plans,
              counts: allCounts,
              plannedExercise: plannedExercise,
            );
            if (mounted && plannedExercise == null) {
              setState(() => _currentSetNumber += 1);
            }
          },
    );
  }

  Widget _buildWaitingTurnView(
    Session session,
    String currentUserId,
    Map<String, GymSessionPlan> plans,
    Map<String, Map<String, int>> counts,
  ) {
    final partnerId = session.activeUserId;
    final partnerProgress = partnerId != null
        ? _participantProgress[partnerId]
        : null;
    final partnerPlan = partnerId != null ? plans[partnerId] : null;
    final partnerState = partnerPlan != null
        ? TurnPlanProgress.participantState(
            partnerPlan,
            counts[partnerId] ?? const {},
          )
        : null;
    final partnerCurrentExercise =
        partnerState?.currentExercise?.name ??
        partnerProgress?.currentExercise ??
        '';
    final partnerSetNumber =
        partnerState?.currentSetNumber ?? (partnerProgress?.totalSets ?? 0) + 1;

    // Per-set timer: while the partner is mid-set (activeSetStartedAt stamped)
    // count up live from that instant; between sets freeze on their last
    // completed set. The parent's 1s ticker rebuilds this view so it advances.
    final Duration partnerSetElapsed;
    final activeSetStart = session.activeSetStartedAt;
    if (activeSetStart != null) {
      final d = DateTime.now().difference(activeSetStart);
      partnerSetElapsed = d.isNegative ? Duration.zero : d;
    } else {
      partnerSetElapsed = Duration(seconds: partnerProgress?.lastSetSeconds ?? 0);
    }

    return FutureBuilder<User?>(
      future: partnerId != null
          ? ref.read(userCacheServiceProvider).getUser(partnerId)
          : Future<User?>.value(null),
      builder: (context, snapshot) {
        final partnerUser = snapshot.data;
        final partnerName = partnerUser?.displayName ?? 'Partner';
        final partnerPhotoUrl = partnerUser?.photoURL;

        return WaitingTurnScreen(
          partnerName: partnerName,
          partnerPhotoUrl: partnerPhotoUrl,
          partnerCurrentExercise: partnerCurrentExercise,
          partnerSetNumber: partnerSetNumber,
          partnerElapsedTime: partnerSetElapsed,
          isPartnerVoicePlaying: _playingAudioUrl != null,
          onRecordVoice: _toggleRecording,
          isRecording: _isRecording,
          recordingDuration: _recordingDuration,
          activeStatusLabel: '$partnerName is active',
          waitingStatusLabel: 'You are waiting',
        );
      },
    );
  }

  Widget _buildPlanCompleteView(
    Session session,
    String currentUserId,
    Map<String, GymSessionPlan> plans,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.userAccent,
              size: 64,
            ),
            const SizedBox(height: 18),
            const Text(
              'Plan complete',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textV2Primary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Finish the session or add another exercise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textV2Secondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleFinishSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.userAccent,
                foregroundColor: AppColors.backgroundV2,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Finish Session'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _openLateAddPicker(
                session: session,
                currentUserId: currentUserId,
                plans: plans,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textV2Primary,
                side: const BorderSide(color: AppColors.surfaceV2Active),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add Exercise'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLateAddPicker({
    required Session session,
    required String currentUserId,
    required Map<String, GymSessionPlan> plans,
  }) async {
    final uid = ref.read(authSessionProvider).value?.id;

    final pickedExercises = await showModalBottomSheet<List<PlannedExercise>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context2, scrollController) =>
            GymExercisePickerSheet(userId: uid),
      ),
    );
    if (pickedExercises == null || pickedExercises.isEmpty) return;

    final currentPlan =
        plans[currentUserId] ??
        _localPlanFor(currentUserId, GymSessionPlanSource.personal);
    var nextOrder = currentPlan.exercises.isEmpty
        ? 0
        : currentPlan.exercises
                  .map((exercise) => exercise.order)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final extraExercises = <PlannedExercise>[];
    for (final picked in pickedExercises) {
      extraExercises.add(
        picked.copyWithPlanFields(
          id: 'extra_${DateTime.now().microsecondsSinceEpoch}_$nextOrder',
          order: nextOrder,
        ),
      );
      nextOrder += 1;
    }
    final updatedPlan = GymSessionPlan(
      userId: currentPlan.userId,
      workoutType: currentPlan.workoutType,
      source: currentPlan.source,
      isReady: true,
      exercises: [...currentPlan.exercises, ...extraExercises],
      stages: currentPlan.stages,
      targets: currentPlan.targets,
      updatedAt: DateTime.now(),
    );

    await ref
        .read(sessionServiceProvider)
        .saveGymPlan(sessionId: widget.sessionId, plan: updatedPlan);
    if (session.partnerKind == PairedPartnerKind.bot &&
        currentUserId == session.hostId) {
      await ref
          .read(sessionServiceProvider)
          .saveGymPlan(
            sessionId: widget.sessionId,
            plan: SessionService.botGymPlanFromHostPlan(updatedPlan),
          );
    }
    if (session.derivedMode == SessionMode.turnBased &&
        session.activeUserId != null &&
        session.activeUserId != currentUserId) {
      await ref
          .read(sessionServiceProvider)
          .switchTurn(widget.sessionId, session.activeUserId!);
    }
    if (mounted) {
      final lastAdded = extraExercises.last;
      setState(() {
        _plannedExercises = updatedPlan.exercises;
        _currentTurnExercise = lastAdded.name;
        _currentExerciseId = lastAdded.id;
      });
    }
  }

  Widget _buildParallelGymView(Session session, String currentUserId) {
    final partnerId = session.participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
    final partnerProgress = partnerId.isNotEmpty
        ? _participantProgress[partnerId]
        : null;
    final partnerType = session.participantTypes[partnerId] ?? 'gym';

    final partner = ParallelPartnerData(
      name: 'Partner',
      workoutType: partnerType,
      totalDistance: partnerProgress?.totalDistance ?? 0,
      averagePace: partnerProgress?.averagePace,
      elapsedTime: _elapsedTime,
      currentExercise: partnerProgress?.currentExercise,
      totalSets: partnerProgress?.totalSets ?? 0,
      totalVolume: partnerProgress?.totalVolume ?? 0,
      standing: _partnerStanding(session, partnerId),
    );

    final exerciseName = _currentTurnExercise ?? 'Workout';
    return ParallelGymView(
      exerciseName: exerciseName,
      setNumber: _currentSetNumber,
      onSetSubmit:
          ({
            required int reps,
            required double weight,
            required int durationSeconds,
          }) {
            _handleLogSet(exercise: exerciseName, weight: weight, reps: reps);
            if (mounted) {
              setState(() => _currentSetNumber += 1);
            }
          },
      partner: partner,
    );
  }

  Widget _buildParallelCardioView(Session session, String currentUserId) {
    final partnerId = session.participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
    final partnerProgress = partnerId.isNotEmpty
        ? _participantProgress[partnerId]
        : null;
    final partnerType = session.participantTypes[partnerId] ?? 'gym';
    final myType = session.participantTypes[currentUserId] ?? widget.type;

    final partner = ParallelPartnerData(
      name: 'Partner',
      workoutType: partnerType,
      totalDistance: partnerProgress?.totalDistance ?? 0,
      averagePace: partnerProgress?.averagePace,
      elapsedTime: _elapsedTime,
      currentExercise: partnerProgress?.currentExercise,
      totalSets: partnerProgress?.totalSets ?? 0,
      totalVolume: partnerProgress?.totalVolume ?? 0,
      standing: _partnerStanding(session, partnerId),
    );

    return ParallelCardioView(
      activityType: myType,
      onCardioLog:
          ({
            required double distanceKm,
            required int durationSeconds,
            required String activityType,
          }) {
            _handleLogCardio(
              distance: distanceKm,
              durationSeconds: durationSeconds,
              activityType: activityType,
            );
          },
      partner: partner,
    );
  }

  /// Build input section based on workout type category.
  Widget _buildInputSection() {
    // Route to appropriate input widget based on workout type
    Widget child;
    if (_workoutType.requiresDistanceTracking) {
      // Cardio activities: running, cycling, swimming, walking
      child = _buildCardioInputSection();
    } else if (_workoutType.requiresSetTracking || _workoutType.isStrength) {
      // Strength activities: gym, hiit
      child = _buildStrengthInputSection();
    } else if (_workoutType == WorkoutType.yoga) {
      // Yoga/flexibility: duration-based input
      child = _buildDurationInputSection();
    } else {
      // Sports, other: flexible input (default to strength)
      child = _buildStrengthInputSection();
    }

    return AnimatedSwitcher(
      duration: AppDurations.normal,
      switchInCurve: AppCurves.premium,
      switchOutCurve: AppCurves.premium,
      child: KeyedSubtree(key: ValueKey(_workoutType), child: child),
    );
  }

  /// Build duration-based input section for yoga, flexibility workouts.
  Widget _buildDurationInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Workout type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.self_improvement,
                size: 16,
                color: AppColors.successDark,
              ),
              const SizedBox(width: 6),
              Text(
                _workoutType.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.successDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Duration input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (min)',
                  hintText: '30',
                  prefixIcon: Icon(Icons.timer),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Log button
        ElevatedButton.icon(
          onPressed: _isLogging ? null : _handleLogDuration,
          icon: _isLogging
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isLogging ? 'Logging...' : 'Log Session'),
        ),
      ],
    );
  }

  /// Handle logging a duration-based activity.
  Future<void> _handleLogDuration() async {
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid duration')),
      );
      return;
    }

    setState(() => _isLogging = true);
    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.value?.id;
      if (uid == null) return;

      final eventText = '${_workoutType.displayName}: ${duration}min session';
      await ref
          .read(sessionServiceProvider)
          .addSessionEvent(
            sessionId: widget.sessionId,
            type: SessionEventType.exercise,
            userId: uid,
            text: eventText,
            data: {'activityType': _workoutType.value, 'duration': duration},
          );
      await HapticFeedback.mediumImpact();
      _durationController.clear();
    } finally {
      setState(() => _isLogging = false);
    }
  }

  /// Build strength training input section (exercise name, weight, reps).
  Widget _buildStrengthInputSection() {
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Autocomplete for Exercise name
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return _recentExercises.where((String option) {
                return option.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                );
              });
            },
            onSelected: (String selection) {
              _exerciseController.text = selection;
              setState(() => _currentExercise = selection);
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // Sync controllers
              if (controller.text != _exerciseController.text) {
                controller.text = _exerciseController.text;
              }

              return TextField(
                controller: controller,
                focusNode:
                    focusNode, // Autocomplete handles its own focus node internally usually, but we can try to use ours if exposed or just rely on it. Actually Autocomplete fieldViewBuilder gives a focusNode. We should use THAT one. But we wanted to use _exerciseNameFocus.
                // Correction: Autocomplete gives a focusNode. We should probably stick with that or use ours if we can pass it.
                // Let's use the one provided by builder but ensure next focus works.
                // We'll leave this one alone as it uses the builder's focusNode.
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                onChanged: (value) {
                  _exerciseController.text = value;
                  setState(
                    () => _currentExercise = value.isNotEmpty ? value : null,
                  );
                },
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // Weight and Reps row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  focusNode: _weightFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _repsController,
                  focusNode: _repsFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Log button row with voice (Elite Brutalist)
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Log Amount',
                  hint: 'Adds this set to your workout',
                  child: SessionBounce(
                    onTap: (_currentExercise != null && !_isLogging)
                        ? _handleLogSetFromControllers
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      constraints: const BoxConstraints(minHeight: 56),
                      decoration: BoxDecoration(
                        gradient: (_currentExercise != null && !_isLogging)
                            ? LinearGradient(
                                colors: [
                                  AppColors.userAccent,
                                  AppColors.userAccentDim,
                                ],
                              )
                            : null,
                        color: (_currentExercise != null && !_isLogging)
                            ? null
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: (_currentExercise != null && !_isLogging)
                              ? AppColors.userAccent
                              : Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: _isLogging
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'LOG SET',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Voice recording button with states
              if (_isUploadingVoice)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _voiceUploadProgress > 0
                              ? _voiceUploadProgress
                              : null,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_voiceUploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isRecording)
                GestureDetector(
                  onTap: _toggleRecording,
                  child: RecordingWaveform(
                    amplitudeStream: ref
                        .read(voiceRecordingServiceProvider)
                        .amplitudeStream,
                    duration: _recordingDuration,
                  ),
                )
              else
                SessionBounce(
                  onTap: _toggleRecording,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.userAccent.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.userAccent.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Record Voice Note',
                      child: Icon(
                        Icons.mic_rounded,
                        color: AppColors.userAccent,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get available cardio activity options based on workout type.
  /// Build cardio input section (activity type, distance, duration, pace).
  Widget _buildCardioInputSection() {
    // Get available activity options based on workout type
    final activityOptions = cardioActivityOptions(_workoutType);

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workout type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.userAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(
                color: AppColors.userAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cardioActivityIcon(_workoutType.value),
                  size: 16,
                  color: AppColors.userAccentDim,
                ),
                const SizedBox(width: 6),
                Text(
                  _workoutType.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.userAccentDim,
                  ),
                ),
              ],
            ),
          ),

          // Activity type selector - only show if multiple options available
          if (activityOptions.length > 1) ...[
            Row(
              children: activityOptions.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isFirst = index == 0;
                final isLast = index == activityOptions.length - 1;
                final isSelected = _cardioActivityType == option['value'];

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _cardioActivityType = option['value'] as String,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.userAccent
                            : AppColors.surfaceSecondaryLight,
                        borderRadius: BorderRadius.horizontal(
                          left: isFirst
                              ? const Radius.circular(AppBorderRadius.md)
                              : Radius.zero,
                          right: isLast
                              ? const Radius.circular(AppBorderRadius.md)
                              : Radius.zero,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            option['icon'] as IconData,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              option['label'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Distance and Duration row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _distanceController,
                  focusNode: _distanceFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Distance (km)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _durationController,
                  focusNode: _durationFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (min)',
                    prefixIcon: Icon(Icons.timer),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Pace input (optional)
          TextField(
            controller: _paceController,
            focusNode: _paceFocus,
            decoration: const InputDecoration(
              labelText: 'Pace (optional, e.g. 5:30/km)',
              prefixIcon: Icon(Icons.speed),
              hintText: 'Auto-calculated if empty',
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Log button row with voice (Elite Brutalist)
          Row(
            children: [
              Expanded(
                child: SessionBounce(
                  onTap: (_cardioActivityType != null && !_isLogging)
                      ? _handleLogCardioFromControllers
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: (_cardioActivityType != null && !_isLogging)
                          ? LinearGradient(
                              colors: [
                                AppColors.userAccent,
                                AppColors.userAccentDim,
                              ],
                            )
                          : null,
                      color: (_cardioActivityType != null && !_isLogging)
                          ? null
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: (_cardioActivityType != null && !_isLogging)
                            ? AppColors.userAccent
                            : Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: _isLogging
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'LOG ACTIVITY',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SessionBounce(
                onTap: _isUploadingVoice ? null : _toggleRecording,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.userAccent.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _isRecording
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.userAccent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Semantics(
                    button: true,
                    label: _isRecording
                        ? 'Stop Recording'
                        : 'Record Voice Note',
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isRecording ? AppColors.error : AppColors.userAccent,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleFinishSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Are you sure you want to finish this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.userAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Stop timer
    _timerUpdateTimer?.cancel();

    // Calculate summary stats
    int totalSets = 0;
    double totalVolume = 0.0;
    double totalDistance = 0.0;

    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    if (uid == null) return;

    final myProgress = _participantProgress[uid];

    if (myProgress != null) {
      totalSets = myProgress.totalSets;
      totalVolume = myProgress.totalVolume;
      totalDistance = myProgress.totalDistance;
    }

    // Create summary object matching the model definition
    final elapsed = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : _elapsedTime;
    // Cardio speed must be computed from time actually spent doing the
    // activity, not from how long the session room happened to stay open.
    // myProgress.totalDuration (minutes) accumulates from logged cardio
    // entries, so it can't be inflated by lingering in — or rushing out of —
    // the room after the activity is done. Fall back to the wall-clock
    // `elapsed` only when there's no progress record to read from.
    final activityElapsed = myProgress != null
        ? Duration(minutes: myProgress.totalDuration)
        : elapsed;
    final summary = SessionSummary(
      activityType: _cardioActivityType,
      duration: _formatElapsedTime(elapsed),
      totalSets: totalSets,
      totalExercises: _exercises.length,
      totalVolume: totalVolume,
      distance: totalDistance,
      // Cardio progress scores speed-vs-own-best, so the summary must carry it.
      // Null when there is no distance or no elapsed clock (e.g. gym sessions).
      averageSpeed: averageSpeedKmh(
        distanceKm: totalDistance,
        elapsed: activityElapsed,
      ),
      exercises: _exercises
          .map(
            (e) => ExerciseSummary(
              name: e.name,
              sets: e.sets.length,
              setDetails: e.sets
                  .map(
                    (s) => SetSummary(
                      reps: s.reps,
                      weight: s.weight,
                      durationSeconds: s.durationSeconds,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      activeCalories: null, // Could estimate if needed
    );

    try {
      // Save session completion to backend
      await ref
          .read(sessionServiceProvider)
          .endSession(widget.sessionId, uid, summary);

      if (mounted) {
        // Recap is a terminal screen for the workout. Use go() (not push) so the
        // finished session room and the exercise-setup page are removed from the
        // back stack — otherwise "back"/"return home" surfaces the picker again.
        context.go(AppRouteLocations.sessionRecap(widget.sessionId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error finishing session: $e')));
      }
    }
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Deep obsidian base
        Container(color: const Color(0xFF020617)),

        // Base gradient for depth
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.userAccent.withValues(alpha: 0.05),
                Colors.transparent,
                AppColors.secondary.withValues(alpha: 0.03),
              ],
            ),
          ),
        ),

        // Primary glowing orb (top-right)
        Positioned(
          top: -150,
          right: -150,
          child: SessionPulse(
            duration: const Duration(seconds: 8),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.userAccent.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Secondary accent orb (bottom-left)
        Positioned(
          bottom: -200,
          left: -200,
          child: SessionPulse(
            duration: const Duration(seconds: 12),
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check combined loading state
    final sessionAsync = ref.watch(currentSessionProvider(widget.sessionId));
    final participantsAsync = ref.watch(
      sessionOnlineUsersProvider(widget.sessionId),
    );
    final eventsAsync = ref.watch(
      recentSessionEventsProvider((
        sessionId: widget.sessionId,
        limit: _eventLimit,
      )),
    );

    // Show skeleton if critical data is still loading and has no data
    final shouldShowSkeleton =
        (sessionAsync.isLoading && !sessionAsync.hasValue) ||
        (participantsAsync.isLoading && !participantsAsync.hasValue) ||
        (eventsAsync.isLoading && !eventsAsync.hasValue);

    if (shouldShowSkeleton) {
      return const SessionRoomSkeleton();
    }

    // Seed the elapsed timer from the shared workout clock once the first
    // active set timer has started.
    // ref.listen only fires on changes; if the provider was cached before
    // this widget's first build, the listener never fires for the initial value.
    if (_sessionStartTime == null) {
      sessionAsync.whenData((session) {
        if (session != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _applySharedClockStart(session.sharedClockStartedAt);
            }
          });
        }
      });
    }

    // Monitor events for auto-play using ref.listen
    ref.listen(
      recentSessionEventsProvider((
        sessionId: widget.sessionId,
        limit: _eventLimit,
      )),
      (previous, next) {
        next.whenData(_monitorVoiceNotes);
      },
    );

    // Listen for turn changes to notify user
    ref.listen(currentSessionProvider(widget.sessionId), (previous, next) {
      next.whenData((session) async {
        if (session == null) return;
        final previousSession = previous?.value;
        final authState = ref.read(authSessionProvider);
        final currentUserId = authState.value?.id;

        // Check if turn changed to me
        if (session.derivedMode == SessionMode.turnBased &&
            session.activeUserId == currentUserId &&
            previousSession?.activeUserId != currentUserId) {
          // It's my turn — announce it physically, not with a banner: a distinct
          // double buzz plus a weight-plate clank.
          _signalMyTurn();
        }
      });
    });

    // Update participant progress from service stream
    ref.listen(sessionProgressProvider(widget.sessionId), (previous, next) {
      next.whenData(_updateLiveParticipantProgressFromMap);
    });

    // Update session clock when the first set timer start reaches Firestore.
    ref.listen(currentSessionProvider(widget.sessionId), (previous, next) {
      next.whenData((session) {
        if (session != null) {
          _applySharedClockStart(session.sharedClockStartedAt);
          // Detect solo session mode
          if (session.participants.length == 1 && !_isSoloSession) {
            _isSoloSession = true;
          } else if (session.participants.length > 1 && _isSoloSession) {
            _isSoloSession = false;
          }
        }
      });
    });

    return Stack(
      children: [
        _buildAnimatedBackground(),
        Scaffold(
          backgroundColor: Colors.transparent, // Transparent to show background
          body: Column(
            children: [
              _buildV2SessionHeader(context),
              _buildV2ProgressRow(context),
              ConnectionStatusWidget(
                queueCount: _queueCount,
                isOffline: _isOffline,
                isSyncing: _isSyncing,
                syncProgress: _syncProgress,
                onTap: _showQueueStatusDialog,
              ),
              if (_errorMessage != null)
                SessionErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                  onRetry: () {
                    setState(() => _errorMessage = null);
                  },
                ),
              Expanded(child: _buildDispatchedInputSection()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildV2SessionHeader(BuildContext context) {
    final session = ref
        .watch(currentSessionProvider(widget.sessionId))
        .value;
    final inviteStatus = session?.invitationStatus;
    final setupStatusChip = session?.phase == SessionPhase.setup
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.surfaceV2Active),
            ),
            child: const Text(
              'Waiting for workout plans',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textV2Secondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null;

    Widget buildCompactTimer() {
      final h = _elapsedTime.inHours;
      final m = _elapsedTime.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = _elapsedTime.inSeconds.remainder(60).toString().padLeft(2, '0');
      final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 11,
              color: AppColors.userAccent.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 5),
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    final isInviteUnanswered =
        inviteStatus == WorkoutInvitationStatus.declined ||
        inviteStatus == WorkoutInvitationStatus.expired;
    final inviteChipColor = switch (inviteStatus) {
      WorkoutInvitationStatus.accepted => AppColors.userAccent,
      WorkoutInvitationStatus.declined => AppColors.errorV2,
      WorkoutInvitationStatus.expired => Colors.orange,
      _ => AppColors.textV2Secondary,
    };
    final inviteChipLabel = switch (inviteStatus) {
      WorkoutInvitationStatus.pending => 'Waiting for your friend…',
      WorkoutInvitationStatus.accepted => 'Friend joined',
      WorkoutInvitationStatus.declined =>
        'Friend declined — train solo or invite someone else',
      WorkoutInvitationStatus.expired =>
        'Invite expired — train solo or invite someone else',
      _ => 'Invite: ${inviteStatus?.value ?? ''}',
    };
    // Only surface invite state when it needs the user's attention (declined /
    // expired). "Friend joined" and "pending" are redundant — the partner's
    // presence is already shown by the participant row below.
    final inviteStatusChip =
        isInviteUnanswered &&
            session?.partnerKind == PairedPartnerKind.realFriend
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isInviteUnanswered
                  ? inviteChipColor.withValues(alpha: 0.12)
                  : AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isInviteUnanswered
                    ? inviteChipColor.withValues(alpha: 0.4)
                    : AppColors.surfaceV2Active,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isInviteUnanswered) ...[
                  Icon(
                    inviteStatus == WorkoutInvitationStatus.declined
                        ? Icons.person_off_rounded
                        : Icons.timer_off_rounded,
                    size: 13,
                    color: inviteChipColor,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    inviteChipLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isInviteUnanswered
                          ? inviteChipColor
                          : AppColors.textV2Secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        : null;
    final endButton = GestureDetector(
      onTap: () {
        HapticManager.heavy();
        _handleFinishSession();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'End',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final participants = session?.participants ?? const <String>[];
    final avatars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in participants) ...[
          _buildHeaderAvatar(id, session),
          const SizedBox(width: 8),
        ],
        // Surface only states that need attention (declined / expired invite,
        // or "waiting for plans") — everything else is minimal, C-style. Each
        // avatar already emits a trailing gap, so no extra spacer is needed.
        ?inviteStatusChip,
        if (setupStatusChip != null) ...[
          const SizedBox(width: 8),
          setupStatusChip,
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: AppColors.backgroundV2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactHeader = constraints.maxWidth < 420;
          if (isCompactHeader) {
            // Narrow: let the avatar/status cluster scroll horizontally rather
            // than squeeze, so the timer and End button stay put.
            return Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.42,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: avatars,
                  ),
                ),
                const Spacer(),
                buildCompactTimer(),
                const Spacer(),
                const SizedBox(width: 8),
                endButton,
              ],
            );
          }
          return Row(
            children: [
              avatars,
              const Spacer(),
              buildCompactTimer(),
              const Spacer(),
              const SizedBox(width: 8),
              endButton,
            ],
          );
        },
      ),
    );
  }

  /// Header avatar for C-style top bar. Active participant (whose turn it is,
  /// or logging in the last 2 min) gets an accent ring + green live dot.
  Widget _buildHeaderAvatar(String userId, Session? session) {
    final currentUid = ref.read(authSessionProvider).value?.id;
    final isSelf = userId == currentUid;
    final isBot = userId == pairedBotFriendId;
    final active =
        session?.activeUserId == userId ||
        (_participantProgress[userId]?.isActive ?? false);
    final cachedUser = isSelf || isBot
        ? null
        : ref.read(userCacheServiceProvider).getUserSync(userId);
    if (!isSelf &&
        !isBot &&
        cachedUser == null &&
        _requestedParticipantNames.add(userId)) {
      ref.read(userCacheServiceProvider).getUser(userId).then((_) {
        if (mounted) setState(() {});
      });
    }
    final label = isSelf
        ? 'Y'
        : isBot
        ? 'B'
        : ((cachedUser?.displayName ?? '?').trim().isNotEmpty
              ? cachedUser!.displayName.trim()[0].toUpperCase()
              : '?');
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: active
            ? Border.all(color: AppColors.userAccent, width: 2)
            : null,
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.surfaceV2Active,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary,
              ),
            ),
          ),
          if (active)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.accentEmerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.backgroundV2, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Small per-set panel shown directly under the C-style top bar: for the
  /// current exercise, each participant's sets side by side as
  /// weight × reps · time, with dim placeholders for planned-but-undone sets.
  Widget _buildV2ProgressRow(BuildContext context) {
    final session = ref
        .watch(currentSessionProvider(widget.sessionId))
        .value;
    if (session == null || session.participants.length < 2) {
      return const SizedBox.shrink();
    }

    final exerciseName =
        _currentTurnExercise ??
        _currentExercise ??
        (_plannedExercises.isNotEmpty ? _plannedExercises.first.name : '');
    if (exerciseName.isEmpty) return const SizedBox.shrink();

    final events =
        ref.watch(sessionEventsProvider(widget.sessionId)).value ??
        const <TimelineEvent>[];
    final match = _plannedExercises.where((e) => e.name == exerciseName);
    final plannedSets = match.isNotEmpty ? match.first.plannedSets : 3;
    final participants = session.participants;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              exerciseName.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textV2Secondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < participants.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildSetColumn(
                    participants[i],
                    exerciseName,
                    plannedSets,
                    events,
                    session,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// One participant's set column for [exerciseName]: header (avatar + name)
  /// then [plannedSets] compact rows, filled from their logged sets.
  Widget _buildSetColumn(
    String userId,
    String exerciseName,
    int plannedSets,
    List<TimelineEvent> events,
    Session session,
  ) {
    final currentUid = ref.read(authSessionProvider).value?.id;
    final isSelf = userId == currentUid;
    final isBot = userId == pairedBotFriendId;
    final cachedUser = isSelf || isBot
        ? null
        : ref.read(userCacheServiceProvider).getUserSync(userId);
    if (!isSelf &&
        !isBot &&
        cachedUser == null &&
        _requestedParticipantNames.add(userId)) {
      ref.read(userCacheServiceProvider).getUser(userId).then((_) {
        if (mounted) setState(() {});
      });
    }
    final name = isSelf
        ? 'You'
        : isBot
        ? 'Bot'
        : (cachedUser?.displayName.split(' ').first ?? 'Buddy');
    final active =
        session.activeUserId == userId ||
        (_participantProgress[userId]?.isActive ?? false);

    // Logged sets for this exercise, oldest first.
    final sets = events
        .where(
          (e) =>
              e.type == SessionEventType.setLogged &&
              e.userId == userId &&
              (e.data?['exercise'] as String?) == exerciseName,
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    String rowText(int i) {
      if (i >= sets.length) return '—';
      final d = sets[i].data ?? const {};
      final w = (d['weight'] as num?)?.toStringAsFixed(0) ?? '0';
      final r = (d['reps'] as num?)?.toInt() ?? 0;
      final secs = (d['durationSeconds'] as num?)?.toInt() ?? 0;
      final t = secs >= 60
          ? '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'
          : '${secs}s';
      return '${w}kg × $r · $t';
    }

    return Container(
      decoration: BoxDecoration(
        color: active
            ? AppColors.userAccent.withValues(alpha: 0.08)
            : AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppColors.userAccent.withValues(alpha: 0.4)
              : AppColors.borderDarkSecondary,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.accentEmerald
                      : AppColors.textV2Tertiary,
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? AppColors.userAccent
                        : AppColors.textV2Primary,
                  ),
                ),
              ),
              Text(
                '${sets.length.clamp(0, plannedSets)}/$plannedSets',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textV2Secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < plannedSets; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      'S${i + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textV2Tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rowText(i),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: i < sets.length
                            ? AppColors.textV2Primary
                            : AppColors.textV2Tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  /// Format elapsed duration as HH:MM:SS
  String _formatElapsedTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
