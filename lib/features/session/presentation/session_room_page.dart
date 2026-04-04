import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
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
import '../../../widgets/shimmer_widgets.dart';
import '../../../widgets/connection_status_widget.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/session_error_banner.dart';
import '../../../utils/session_error_handler.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/premium_animations.dart';

/// Tracks real-time progress for a participant in a session.
class ParticipantProgress {
  final String currentExercise;
  final int totalSets;
  final double totalVolume;
  final DateTime? lastActivity;
  // Cardio-specific metrics
  final double totalDistance; // in km
  final int totalDuration; // in minutes
  final String? averagePace; // e.g., "5:30/km"
  final String? activityType; // 'running' or 'cycling'

  const ParticipantProgress({
    this.currentExercise = '',
    this.totalSets = 0,
    this.totalVolume = 0,
    this.lastActivity,
    this.totalDistance = 0,
    this.totalDuration = 0,
    this.averagePace,
    this.activityType,
  });

  /// Check if participant is active (logged set in last 2 minutes).
  bool get isActive {
    if (lastActivity == null) return false;
    return DateTime.now().difference(lastActivity!).inMinutes < 2;
  }

  ParticipantProgress copyWith({
    String? currentExercise,
    int? totalSets,
    double? totalVolume,
    DateTime? lastActivity,
    double? totalDistance,
    int? totalDuration,
    String? averagePace,
    String? activityType,
  }) {
    return ParticipantProgress(
      currentExercise: currentExercise ?? this.currentExercise,
      totalSets: totalSets ?? this.totalSets,
      totalVolume: totalVolume ?? this.totalVolume,
      lastActivity: lastActivity ?? this.lastActivity,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      averagePace: averagePace ?? this.averagePace,
      activityType: activityType ?? this.activityType,
    );
  }
}

/// Session room page for active workout sessions.
/// Matches React Native SessionRoomScreen behavior.
class SessionRoomPage extends ConsumerStatefulWidget {
  final String sessionId;
  final String type;
  final String? initialAudioUrl;

  const SessionRoomPage({
    super.key,
    required this.sessionId,
    required this.type,
    this.initialAudioUrl,
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
  bool _isLogging = false;

  // Voice recording state
  bool _isRecording = false;
  bool _isUploadingVoice = false;
  double _voiceUploadProgress = 0;
  Duration _recordingDuration = Duration.zero;
  StreamSubscription<Duration>? _durationSubscription;

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingAudioUrl;
  bool _isLoadingAudio = false;

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

  // Cheers emojis
  static const List<String> _cheersEmojis = ['ðŸ”¥', 'ðŸ’ª', 'ðŸ‘', 'ðŸŽ‰', 'âš¡'];

  // Participant progress tracking
  final Map<String, ParticipantProgress> _participantProgress = {};

  // Session mode flags
  bool _isSoloSession = false;

  // Set milestone tracking for animations
  int _lastMilestoneAchieved = 0;
  final List<int> _milestones = [5, 10, 15, 20, 25, 30, 40, 50];
  int _eventLimit = 50; // Pagination limit for events
  final List<TimelineEvent> _localPendingEvents = [];

  // Floating emojis state
  final List<({String id, String emoji})> _activeCheers = [];
  int _cheerCounter = 0;

  bool _voiceNotesEnabled = true;

  StreamSubscription? _audioPlayerSubscription;
  StreamSubscription? _connectivitySubscription;

  void _addCheer(String emoji) {
    if (!mounted) return;
    setState(() {
      _activeCheers.add((id: 'cheer_${_cheerCounter++}', emoji: emoji));
    });
  }

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
          _isLoadingAudio = false;
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
    final uid = authState.valueOrNull?.id;
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
    final uid = authState.valueOrNull?.id;
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

  Future<void> _initPresence() async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid != null) {
      // Set initial status
      await ref.read(presenceServiceProvider).setOnline(widget.sessionId, uid);
      // Heartbeat would go here (or in service)
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid == null) return;

    final presenceService = ref.read(presenceServiceProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        presenceService.setOnline(widget.sessionId, uid);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        presenceService.setAway(widget.sessionId, uid);
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
    _timerUpdateTimer?.cancel();
    _durationSubscription?.cancel();
    _queueCountTimer?.cancel();
    _syncProgressSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _audioPlayerSubscription?.cancel();
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
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid != null) {
      await ref.read(presenceServiceProvider).setOffline(widget.sessionId, uid);
    }
  }

  // Monitor events for voice notes
  void _monitorVoiceNotes(List<TimelineEvent> events) async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
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
  void _updateParticipantProgressFromMap(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final newProgress = <String, ParticipantProgress>{};

    data.forEach((userId, stats) {
      if (stats is Map<String, dynamic>) {
        DateTime? lastActivity;
        if (stats['lastActivity'] != null) {
          try {
            lastActivity = DateTime.parse(stats['lastActivity']);
          } catch (_) {}
        }

        newProgress[userId] = ParticipantProgress(
          // Strength metrics
          currentExercise: stats['currentExercise'] as String? ?? '',
          totalSets: stats['totalSets'] as int? ?? 0,
          totalVolume: (stats['totalVolume'] as num?)?.toDouble() ?? 0.0,
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

    // Check for milestones
    _checkMilestones();
  }

  /// Check for set milestones and show achievement notification.
  void _checkMilestones() {
    final totalSets = _participantProgress.values.fold<int>(
      0,
      (sum, p) => sum + p.totalSets,
    );

    for (final milestone in _milestones) {
      if (totalSets >= milestone && _lastMilestoneAchieved < milestone) {
        _lastMilestoneAchieved = milestone;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ðŸŽ¯ $milestone sets completed! Keep going!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
          HapticFeedback.heavyImpact();
        }
        break; // Only show one milestone at a time
      }
    }
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

  Future<void> _handleLogSet() async {
    if (_currentExercise == null) return;

    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid weight and reps')),
      );
      return;
    }

    // Check availability based on turn-based rules
    final session = ref
        .read(currentSessionProvider(widget.sessionId))
        .valueOrNull;
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;

    if (session != null &&
        session.mode == SessionMode.turnBased &&
        !_isSoloSession &&
        session.activeUserId != uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("It's not your turn yet! â³")),
      );
      return;
    }

    // Add to recent exercises for autocomplete
    if (!_recentExercises.contains(_currentExercise!)) {
      _recentExercises.insert(0, _currentExercise!);
      if (_recentExercises.length > 10) _recentExercises.removeLast();
    }

    setState(() => _isLogging = true);

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) return;

      // Add to local exercises
      final existingIndex = _exercises.indexWhere(
        (e) => e.name == _currentExercise,
      );
      if (existingIndex >= 0) {
        _exercises[existingIndex] = _exercises[existingIndex].copyWith(
          sets: [
            ..._exercises[existingIndex].sets,
            SetData(weight: weight, reps: reps),
          ],
        );
      } else {
        _exercises.add(
          Exercise(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: _currentExercise!,
            sets: [SetData(weight: weight, reps: reps)],
          ),
        );
      }

      // Log to Firestore or Queue
      if (_isOffline) {
        // Optimistic update
        final currentProgress = _participantProgress[uid];
        final newTotalSets = (currentProgress?.totalSets ?? 0) + 1;
        final newVolume = (currentProgress?.totalVolume ?? 0) + (weight * reps);

        // Create local event for timeline
        final localEvent = TimelineEvent(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          type: SessionEventType.setLogged,
          userId: uid,
          text: '$_currentExercise: ${weight}kg x $reps reps',
          timestamp: DateTime.now(),
          data: {'exercise': _currentExercise, 'weight': weight, 'reps': reps},
        );

        setState(() {
          _participantProgress[uid] = ParticipantProgress(
            currentExercise: _currentExercise!,
            totalSets: newTotalSets,
            totalVolume: newVolume,
            lastActivity: DateTime.now(),
          );
          _localPendingEvents.insert(0, localEvent);
        });

        await ref.read(offlineManagerProvider).queueOperation('session_event', {
          'sessionId': widget.sessionId,
          'type': SessionEventType.setLogged.value,
          'userId': uid,
          'text': '$_currentExercise: ${weight}kg x $reps reps',
          'data': {
            'exercise': _currentExercise,
            'weight': weight,
            'reps': reps,
          },
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged locally (Offline)')),
          );
        }
      } else {
        try {
          await ref
              .read(sessionServiceProvider)
              .addSessionEvent(
                sessionId: widget.sessionId,
                type: SessionEventType.setLogged,
                userId: uid,
                text: '$_currentExercise: ${weight}kg x $reps reps',
                data: {
                  'exercise': _currentExercise,
                  'weight': weight,
                  'reps': reps,
                },
              );
          // Highlight effect
          await HapticFeedback.mediumImpact();
        } catch (e) {
          // Queue on failure
          await ref.read(offlineManagerProvider).queueOperation(
            'session_event',
            {
              'sessionId': widget.sessionId,
              'type': SessionEventType.setLogged.value,
              'userId': uid,
              'text': '$_currentExercise: ${weight}kg x $reps reps',
              'data': {
                'exercise': _currentExercise,
                'weight': weight,
                'reps': reps,
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

      setState(() {});
    } finally {
      setState(() => _isLogging = false);
    }
  }

  void _undoLastSet() {
    // Implementation for local undo
    if (_exercises.isEmpty) return;

    setState(() {
      final lastExercise = _exercises.last;
      if (lastExercise.sets.length > 1) {
        // Remove last set
        final updatedSets = List<SetData>.from(lastExercise.sets)..removeLast();
        _exercises[_exercises.length - 1] = lastExercise.copyWith(
          sets: updatedSets,
        );
      } else {
        // Remove exercise if only 1 set
        _exercises.removeLast();
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Last set undone (Local)')));
  }

  /// Handle logging a cardio activity entry.
  Future<void> _handleLogCardio() async {
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
        .valueOrNull;
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;

    if (session != null &&
        session.mode == SessionMode.turnBased &&
        !_isSoloSession &&
        session.activeUserId != uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("It's not your turn yet! â³")),
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

      final activityName = _getActivityLabel(_cardioActivityType);
      final eventText =
          '$activityName: ${distance.toStringAsFixed(2)}km in ${duration}min';

      // Log to Firestore or Queue
      if (_isOffline) {
        // Optimistic update
        final currentProgress = _participantProgress[uid];
        final newDistance = (currentProgress?.totalDistance ?? 0) + distance;
        final newDuration = (currentProgress?.totalDuration ?? 0) + duration;

        // Create local event for timeline
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
          _participantProgress[uid] = ParticipantProgress(
            activityType: _cardioActivityType,
            totalDistance: newDistance,
            totalDuration: newDuration,
            averagePace: calculatedPace,
            lastActivity: DateTime.now(),
          );
          _localPendingEvents.insert(0, localEvent);
        });

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged locally (Offline)')),
          );
        }
      } else {
        try {
          await ref
              .read(sessionServiceProvider)
              .addSessionEvent(
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
          await HapticFeedback.mediumImpact();
        } catch (e) {
          // Queue on failure
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
    final voiceService = ref.read(voiceRecordingServiceProvider);

    if (_isRecording) {
      await _stopAndUploadRecording(voiceService);
    } else {
      await _startRecording(voiceService);
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
    if (path == null) return;

    setState(() {
      _isUploadingVoice = true;
      _voiceUploadProgress = 0;
    });

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
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
      if (mounted) setState(() => _isUploadingVoice = false);
    }
  }

  // Send cheer emoji
  Future<void> _sendCheer(String emoji) async {
    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) return;

      HapticFeedback.lightImpact();

      // Optimistic local animation
      _addCheer(emoji);

      // Log event to service
      try {
        if (!_isOffline) {
          await ref
              .read(sessionServiceProvider)
              .addSessionEvent(
                sessionId: widget.sessionId,
                type: SessionEventType.cheer,
                userId: uid,
                text: 'sent $emoji',
                data: {'emoji': emoji},
              );
        } else {
          // Queue offline cheer
          await ref.read(offlineManagerProvider).queueOperation(
            'session_event',
            {
              'sessionId': widget.sessionId,
              'type': SessionEventType.cheer.value,
              'userId': uid,
              'text': 'sent $emoji',
              'data': {'emoji': emoji},
            },
          );
        }
      } catch (e) {
        debugPrint('[SessionRoom] Error sending cheer: $e');
        // If online send fails, queue for offline sync
        await ref.read(offlineManagerProvider).queueOperation('session_event', {
          'sessionId': widget.sessionId,
          'type': SessionEventType.cheer.value,
          'userId': uid,
          'text': 'sent $emoji',
          'data': {'emoji': emoji},
        });
      }
    } catch (e) {
      debugPrint('[SessionRoom] Error sending cheer: $e');
    }
  }

  // Handle Pass Turn
  Future<void> _handlePassTurn() async {
    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) return;

      if (_isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot pass turn while offline.')),
        );
        return;
      }

      setState(
        () => _isLogging = true,
      ); // Show loading state on button potentially

      await ref.read(sessionServiceProvider).switchTurn(widget.sessionId, uid);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Turn passed!')));
      }
    } catch (e, stack) {
      if (mounted) {
        await SessionErrorHandler.handleError(
          context,
          e,
          stack,
          ref,
          onRetry: _handlePassTurn, // Allow retrying this specific action
          onErrorMessage: (msg) {
            if (mounted) setState(() => _errorMessage = msg);
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
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
          _isLoadingAudio = false;
        });
      } else {
        // Show loading state
        setState(() => _isLoadingAudio = true);

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
          _isLoadingAudio = false;
        });
        // Listener is set up in initState
      }
    } catch (e) {
      debugPrint('[SessionRoom] Error playing audio after retries: $e');
      setState(() => _isLoadingAudio = false);
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
      final uid = authState.valueOrNull?.id;
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
                  child: BounceAnimation(
                    onTap: (_currentExercise != null && !_isLogging) ? _handleLogSet : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: (_currentExercise != null && !_isLogging)
                            ? LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                              )
                            : null,
                        color: (_currentExercise != null && !_isLogging)
                            ? null
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: (_currentExercise != null && !_isLogging)
                              ? AppColors.primary
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
                                  fontWeight: FontWeight.w900,
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
                          fontWeight: FontWeight.w900,
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
                BounceAnimation(
                  onTap: _toggleRecording,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Record Voice Note',
                      child: Icon(
                        Icons.mic_rounded,
                        color: AppColors.primary,
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
  List<Map<String, dynamic>> _getCardioActivityOptions() {
    switch (_workoutType) {
      case WorkoutType.running:
        return [
          {
            'value': 'running',
            'label': 'Running',
            'icon': Icons.directions_run,
          },
          {
            'value': 'jogging',
            'label': 'Jogging',
            'icon': Icons.directions_run,
          },
        ];
      case WorkoutType.cycling:
        return [
          {
            'value': 'cycling',
            'label': 'Cycling',
            'icon': Icons.directions_bike,
          },
          {
            'value': 'stationary',
            'label': 'Stationary',
            'icon': Icons.pedal_bike,
          },
        ];
      case WorkoutType.swimming:
        return [
          {'value': 'swimming', 'label': 'Swimming', 'icon': Icons.pool},
          {'value': 'laps', 'label': 'Laps', 'icon': Icons.pool},
        ];
      case WorkoutType.walking:
        return [
          {
            'value': 'walking',
            'label': 'Walking',
            'icon': Icons.directions_walk,
          },
          {'value': 'hiking', 'label': 'Hiking', 'icon': Icons.terrain},
        ];
      default:
        // For generic cardio or other types, show common options
        return [
          {
            'value': 'running',
            'label': 'Running',
            'icon': Icons.directions_run,
          },
          {
            'value': 'cycling',
            'label': 'Cycling',
            'icon': Icons.directions_bike,
          },
          {'value': 'swimming', 'label': 'Swimming', 'icon': Icons.pool},
          {
            'value': 'walking',
            'label': 'Walking',
            'icon': Icons.directions_walk,
          },
        ];
    }
  }

  /// Get icon for activity type.
  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'running':
      case 'jogging':
        return Icons.directions_run;
      case 'cycling':
      case 'stationary':
        return Icons.directions_bike;
      case 'swimming':
      case 'laps':
        return Icons.pool;
      case 'walking':
      case 'hiking':
        return Icons.directions_walk;
      default:
        return Icons.fitness_center;
    }
  }

  /// Get display label for activity type.
  String _getActivityLabel(String? activityType) {
    if (activityType == null) return 'Activity';
    // Capitalize first letter
    return activityType[0].toUpperCase() + activityType.substring(1);
  }

  /// Build cardio input section (activity type, distance, duration, pace).
  Widget _buildCardioInputSection() {
    // Get available activity options based on workout type
    final activityOptions = _getCardioActivityOptions();

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workout type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getActivityIcon(_workoutType.value),
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  _workoutType.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
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
                            ? AppColors.primary
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
                child: BounceAnimation(
                  onTap: (_cardioActivityType != null && !_isLogging) ? _handleLogCardio : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: (_cardioActivityType != null && !_isLogging)
                          ? LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                            )
                          : null,
                      color: (_cardioActivityType != null && !_isLogging)
                          ? null
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: (_cardioActivityType != null && !_isLogging)
                            ? AppColors.primary
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
                                fontWeight: FontWeight.w900,
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
              BounceAnimation(
                onTap: _isUploadingVoice ? null : _toggleRecording,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _isRecording
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.primary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Semantics(
                    button: true,
                    label: _isRecording ? 'Stop Recording' : 'Record Voice Note',
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isRecording ? AppColors.error : AppColors.primary,
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

  /// Show detailed participants list bottom sheet
  void _showParticipantsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.xl),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiaryLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Participants',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                // List
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final sessionAsync = ref.watch(
                        currentSessionProvider(widget.sessionId),
                      );
                      final participantsAsync = ref.watch(
                        sessionOnlineUsersProvider(widget.sessionId),
                      );

                      return sessionAsync.when(
                        data: (session) {
                          if (session == null) return const SizedBox.shrink();

                          return participantsAsync.when(
                            data: (onlineUserIds) {
                              return ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                itemCount: session.participants.length,
                                separatorBuilder: (_, _) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(),
                                ),
                                itemBuilder: (context, index) {
                                  final uid = session.participants[index];
                                  final isOnline = onlineUserIds.contains(uid);
                                  final progress = _participantProgress[uid];
                                  final isActive =
                                      session.mode == SessionMode.turnBased &&
                                      session.activeUserId == uid;

                                  return FutureBuilder<User?>(
                                    future: ref
                                        .read(userCacheServiceProvider)
                                        .getUser(uid),
                                    builder: (context, snapshot) {
                                      final user = snapshot.data;
                                      final name = user?.displayName ?? 'User';

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundImage:
                                                  user?.photoURL != null
                                                  ? NetworkImage(
                                                      user!.photoURL!,
                                                    )
                                                  : null,
                                              child: user?.photoURL == null
                                                  ? Text(
                                                      name.isNotEmpty
                                                          ? name[0]
                                                          : '?',
                                                    )
                                                  : null,
                                            ),
                                            if (isOnline)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Theme.of(
                                                        context,
                                                      ).canvasColor,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        title: Row(
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  'Active Turn',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isOnline ? 'Online' : 'Offline',
                                              style: TextStyle(
                                                color: isOnline
                                                    ? AppColors.success
                                                    : AppColors
                                                          .textSecondaryLight,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (progress != null)
                                              Text(
                                                '${progress.totalSets} sets â€¢ ${progress.totalVolume.toInt()}kg',
                                                style: TextStyle(
                                                  color: AppColors
                                                      .textSecondaryLight,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  color: AppColors.warning.withValues(
                                    alpha: 0.1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.cloud_off,
                                        size: 16,
                                        color: AppColors.warning,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Presence status unavailable',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.warning,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(
                                      AppSpacing.lg,
                                    ),
                                    itemCount: session.participants.length,
                                    separatorBuilder: (_, _) => const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Divider(),
                                    ),
                                    itemBuilder: (context, index) {
                                      final uid = session.participants[index];
                                      final isActive =
                                          session.mode ==
                                              SessionMode.turnBased &&
                                          session.activeUserId == uid;

                                      return FutureBuilder<User?>(
                                        future: ref
                                            .read(userCacheServiceProvider)
                                            .getUser(uid),
                                        builder: (context, snapshot) {
                                          final user = snapshot.data;
                                          final name =
                                              user?.displayName ?? 'User';

                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              radius: 24,
                                              backgroundImage:
                                                  user?.photoURL != null
                                                  ? NetworkImage(
                                                      user!.photoURL!,
                                                    )
                                                  : null,
                                              child: user?.photoURL == null
                                                  ? Text(
                                                      name.isNotEmpty
                                                          ? name[0]
                                                          : '?',
                                                    )
                                                  : null,
                                            ),
                                            title: Row(
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (isActive) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Active',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            // Show generic status or nothing
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) =>
                            const Center(child: Text('Error loading session')),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
    final uid = authState.valueOrNull?.id;
    if (uid == null) return;

    final myProgress = _participantProgress[uid];

    if (myProgress != null) {
      totalSets = myProgress.totalSets;
      totalVolume = myProgress.totalVolume;
      totalDistance = myProgress.totalDistance;
    }

    // Create summary object matching the model definition
    final summary = SessionSummary(
      activityType: _cardioActivityType,
      duration: _formatElapsedTime(_elapsedTime),
      totalSets: totalSets,
      totalVolume: totalVolume,
      distance: totalDistance,
      exercises: _exercises
          .map((e) => ExerciseSummary(name: e.name, sets: e.sets.length))
          .toList(),
      activeCalories: null, // Could estimate if needed
    );

    try {
      // Save session completion to backend
      await ref
          .read(sessionServiceProvider)
          .endSession(widget.sessionId, uid, summary);

      if (mounted) {
        context.push(AppRouteLocations.sessionRecap(widget.sessionId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error finishing session: $e')));
      }
    }
  }

  List<Widget> _buildProgressComparisonList() {
    // Calculate max values for relative progress bars
    final maxSets = _participantProgress.values
        .map((p) => p.totalSets)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxVolume = _participantProgress.values
        .map((p) => p.totalVolume)
        .fold<double>(0.0, (a, b) => a > b ? a : b);
    final maxDistance = _participantProgress.values
        .map((p) => p.totalDistance)
        .fold<double>(0.0, (a, b) => a > b ? a : b);

    return _participantProgress.entries.map((entry) {
      final authState = ref.read(authSessionProvider);
      final isCurrentUser = entry.key == authState.valueOrNull?.id;
      final progress = entry.value;

      // Determine if leader in each category
      final isLeaderSets = maxSets > 0 && progress.totalSets == maxSets;
      final isLeaderVolume = maxVolume > 0 && progress.totalVolume == maxVolume;
      final isLeaderDistance =
          maxDistance > 0 && progress.totalDistance == maxDistance;

      return FutureBuilder<User?>(
        future: ref.read(userCacheServiceProvider).getUser(entry.key),
        builder: (context, userSnapshot) {
          final user = userSnapshot.data;
          final displayName = user?.displayName ?? 'User';

          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.surfaceSecondaryLight,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(
                color: isCurrentUser
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User header with avatar
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surfaceSecondaryLight,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCurrentUser ? 'You' : displayName.split(' ').first,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                      ),
                    ),
                    if (progress.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Metrics row with progress bars
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Sets metric
                    _buildMetricChip(
                      emoji: 'ðŸ‹ï¸',
                      label: 'Sets',
                      value: '${progress.totalSets}',
                      progress: maxSets > 0
                          ? progress.totalSets / maxSets
                          : 0.0,
                      isLeader: isLeaderSets,
                    ),
                    // Volume metric (strength) or Distance (cardio)
                    if (_workoutType.isCardio ||
                        _workoutType.requiresDistanceTracking)
                      _buildMetricChip(
                        emoji: 'ðŸ“',
                        label: 'Distance',
                        value: '${progress.totalDistance.toStringAsFixed(2)}km',
                        progress: maxDistance > 0
                            ? progress.totalDistance / maxDistance
                            : 0.0,
                        isLeader: isLeaderDistance,
                      )
                    else
                      _buildMetricChip(
                        emoji: 'âš–ï¸',
                        label: 'Volume',
                        value: '${progress.totalVolume.toStringAsFixed(0)}kg',
                        progress: maxVolume > 0
                            ? progress.totalVolume / maxVolume
                            : 0.0,
                        isLeader: isLeaderVolume,
                      ),
                  ],
                ),
                // Current exercise
                if (progress.currentExercise.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'â€¢ ${progress.currentExercise}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Deep obsidian base
        Container(
          color: const Color(0xFF020617),
        ),

        // Base gradient for depth
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.05),
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
          child: PulseAnimation(
            duration: const Duration(seconds: 8),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
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
          child: PulseAnimation(
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

        // Fine glass texture overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: Colors.black.withValues(alpha: 0.1),
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
        final previousSession = previous?.valueOrNull;
        final authState = ref.read(authSessionProvider);
        final currentUserId = authState.valueOrNull?.id;

        // Check if turn changed to me
        if (session.mode == SessionMode.turnBased &&
            session.activeUserId == currentUserId &&
            previousSession?.activeUserId != currentUserId) {
          // It's my turn!
          await HapticFeedback.heavyImpact();

          if (mounted) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: const Text(
                  "It's your turn! ðŸ’ª",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Let\'s Go',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );

            // Optional: Play a sound if audio player is free
            // _audioPlayer.play(AssetSource('sounds/turn_start.mp3'));
          }
        }
      });
    });

    // Update participant progress from service stream
    ref.listen(sessionProgressProvider(widget.sessionId), (previous, next) {
      next.whenData(_updateParticipantProgressFromMap);
    });

    // Update session start time when session data loads
    ref.listen(currentSessionProvider(widget.sessionId), (previous, next) {
      next.whenData((session) {
        if (session != null) {
          if (_sessionStartTime == null) {
            _sessionStartTime = session.startedAt;
            _elapsedTime = DateTime.now().difference(session.startedAt);
          }
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
              // Custom Header (Elite Brutalist + Glassmorphic)
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withValues(alpha: 0.6),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 16,
                      bottom: 16,
                      left: 20,
                      right: 20,
                    ),
                    child: Row(
                      children: [
                        BounceAnimation(
                          onTap: () {
                            HapticManager.light();
                            context.go(
                              AppRouteLocations.mainTab(MainShellTab.session),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(0),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _workoutType.displayName.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'SESSION #${widget.sessionId.substring(0, 4)}',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: AppColors.primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            BounceAnimation(
                              onTap: () {
                                HapticManager.heavy();
                                _handleFinishSession();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: AppColors.error.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.stop_rounded,
                                  color: AppColors.error,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            BounceAnimation(
                              onTap: () {
                                HapticManager.light();
                                _showParticipantsBottomSheet();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.people_alt_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Connection status banner (offline/syncing/online)
              ConnectionStatusWidget(
                queueCount: _queueCount,
                isOffline: _isOffline,
                isSyncing: _isSyncing,
                syncProgress: _syncProgress,
                onTap: _showQueueStatusDialog,
              ),

              // Session Error Banner
              if (_errorMessage != null)
                SessionErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                  onRetry: () {
                    setState(() => _errorMessage = null);
                  },
                ),

              // Turn Status Banner (if turn-based and not solo)
              sessionAsync.when(
                data: (session) {
                  // Hide turn banner for solo sessions or parallel mode
                  if (session == null ||
                      session.mode != SessionMode.turnBased ||
                      _isSoloSession) {
                    return const SizedBox.shrink();
                  }

                  final authState = ref.read(authSessionProvider);
                  final uid = authState.valueOrNull?.id;
                  final isMyTurn = session.activeUserId == uid;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    color: isMyTurn
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey[200],

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isMyTurn
                              ? Icons.play_circle_fill
                              : Icons.hourglass_empty,
                          color: isMyTurn ? AppColors.primary : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMyTurn
                              ? "It's your turn! Log a set."
                              : "Waiting for partner...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMyTurn
                                ? AppColors.primary
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // Participants Section
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                color: Theme.of(context).cardColor,
                child: participantsAsync.when(
                  data: (onlineUserIds) {
                    return sessionAsync.when(
                      data: (session) {
                        if (session == null) return const SizedBox.shrink();
                        final isTurnBased =
                            session.mode == SessionMode.turnBased;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: session.participants.map((uid) {
                              final isOnline = onlineUserIds.contains(uid);
                              final progress = _participantProgress[uid];
                              final setCount = progress?.totalSets ?? 0;
                              final currentEx = progress?.currentExercise ?? '';
                              final isActive = progress?.isActive ?? false;
                              final isMyTurn =
                                  isTurnBased && session.activeUserId == uid;

                              // Calculate progress for mini bar (strength: sets/15, cardio: distance/5km)
                              final progressValue =
                                  _workoutType.isCardio ||
                                      _workoutType.requiresDistanceTracking
                                  ? ((progress?.totalDistance ?? 0) / 5.0)
                                        .clamp(0.0, 1.0)
                                  : (setCount / 15.0).clamp(0.0, 1.0);

                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: FutureBuilder<User?>(
                                  future: ref
                                      .read(userCacheServiceProvider)
                                      .getUser(uid),
                                  builder: (context, userSnapshot) {
                                    final user = userSnapshot.data;
                                    final displayName =
                                        user?.displayName ?? 'User';
                                    final photoUrl = user?.photoURL;

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Avatar with glowing border for active turn
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: isMyTurn
                                                ? Border.all(
                                                    color: AppColors.primary,
                                                    width: 3,
                                                  )
                                                : isActive
                                                ? Border.all(
                                                    color: AppColors.success,
                                                    width: 2,
                                                  )
                                                : null,
                                            boxShadow: isMyTurn
                                                ? [
                                                    BoxShadow(
                                                      color: AppColors.primary
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                      blurRadius: 8,
                                                      spreadRadius: 2,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              CircleAvatar(
                                                radius: isMyTurn ? 28 : 22,
                                                backgroundColor:
                                                    Colors.grey[200],
                                                backgroundImage:
                                                    photoUrl != null
                                                    ? NetworkImage(photoUrl)
                                                    : null,
                                                child: photoUrl == null
                                                    ? Text(
                                                        displayName.isNotEmpty
                                                            ? displayName[0]
                                                                  .toUpperCase()
                                                            : '?',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: isMyTurn
                                                              ? 18
                                                              : 14,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              // Online status indicator
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: isOnline
                                                        ? (isActive
                                                              ? Colors.green
                                                              : Colors.amber)
                                                        : Colors.grey,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Set count badge
                                              if (setCount > 0)
                                                Positioned(
                                                  top: -4,
                                                  right: -4,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '$setCount',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // User name
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            displayName.split(' ').first,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isMyTurn
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isMyTurn
                                                  ? AppColors.primary
                                                  : (isActive
                                                        ? Colors.grey[800]
                                                        : Colors.grey[600]),
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        // Current exercise or "Active" label
                                        if (isMyTurn)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Active',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          )
                                        else if (currentEx.isNotEmpty)
                                          SizedBox(
                                            width: 60,
                                            child: Text(
                                              currentEx,
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: isActive
                                                    ? AppColors.primary
                                                    : Colors.grey[600],
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        // Mini progress bar
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 50,
                                          height: 4,
                                          child: AnimatedProgressBar(
                                            value: progressValue,
                                            backgroundColor: Colors.grey[300]!,
                                            foregroundColor:
                                                progressValue >= 1.0
                                                ? AppColors.success
                                                : AppColors.primary,
                                            height: 4,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),

              // Pass Turn Button (hide for solo sessions)
              sessionAsync.when(
                data: (session) {
                  if (session == null ||
                      session.mode != SessionMode.turnBased ||
                      _isSoloSession) {
                    return const SizedBox.shrink();
                  }

                  final authState = ref.read(authSessionProvider);
                  final uid = authState.valueOrNull?.id;
                  final isMyTurn = session.activeUserId == uid;

                  if (!isMyTurn) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLogging ? null : _handlePassTurn,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Pass Turn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // Voice upload progress
              if (_isUploadingVoice)
                AnimatedProgressBar(
                  value: _voiceUploadProgress,
                  backgroundColor: AppColors.primaryMuted,
                  foregroundColor: AppColors.primary,
                  height: 4,
                ),

              // Shared Session Timer (Elite Brutalist)
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withValues(alpha: 0.4),
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatElapsedTime(_elapsedTime),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isPaused
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.success.withValues(alpha: 0.15),
                            border: Border.all(
                              color: _isPaused
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : AppColors.success.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PulseAnimation(
                                duration: const Duration(seconds: 1),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: _isPaused ? Colors.grey : AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isPaused ? 'PAUSED' : 'LIVE',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: _isPaused ? Colors.grey : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Current Activity Display (real-time tracking) - conditional based on session type
              if (_participantProgress.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  color: AppColors.primaryMuted.withValues(alpha: 0.1),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSoloSession)
                          // Solo mode: Single user activity
                          (_workoutType.isCardio ||
                                  _workoutType.requiresDistanceTracking)
                              ? _buildCardioActivityChip(
                                  label: 'Current',
                                  distance: _participantProgress
                                      .values
                                      .first
                                      .totalDistance,
                                  duration: _participantProgress
                                      .values
                                      .first
                                      .totalDuration,
                                  activityType: _participantProgress
                                      .values
                                      .first
                                      .activityType,
                                  isActive: _participantProgress
                                      .values
                                      .first
                                      .isActive,
                                )
                              : _buildCurrentActivityChip(
                                  label: 'Current',
                                  exercise: _participantProgress
                                      .values
                                      .first
                                      .currentExercise,
                                  setCount: _participantProgress
                                      .values
                                      .first
                                      .totalSets,
                                  isActive: _participantProgress
                                      .values
                                      .first
                                      .isActive,
                                )
                        else
                          // Buddy mode: Show all users
                          ..._participantProgress.entries.map((entry) {
                            final authState = ref.read(authSessionProvider);
                            final isCurrentUser =
                                entry.key == authState.valueOrNull?.id;
                            final label = isCurrentUser ? 'You' : 'Partner';

                            if (_workoutType.isCardio ||
                                _workoutType.requiresDistanceTracking) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _buildCardioActivityChip(
                                  label: label,
                                  distance: entry.value.totalDistance,
                                  duration: entry.value.totalDuration,
                                  activityType: entry.value.activityType,
                                  isActive: entry.value.isActive,
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _buildCurrentActivityChip(
                                  label: label,
                                  exercise: entry.value.currentExercise,
                                  setCount: entry.value.totalSets,
                                  isActive: entry.value.isActive,
                                ),
                              );
                            }
                          }),
                      ],
                    ),
                  ),
                ),

              // Session Progress Bar - conditionally show strength or cardio metrics
              if (_participantProgress.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      if (_workoutType.isCardio ||
                          _workoutType.requiresDistanceTracking) ...[
                        // Cardio progress display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_participantProgress.values.fold<double>(0, (sum, p) => sum + p.totalDistance).toStringAsFixed(2)} km covered',
                              style: TextStyle(
                                fontSize: AppFontSize.sm,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              'Goal: 5 km',
                              style: TextStyle(
                                fontSize: AppFontSize.xs,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AnimatedProgressBar(
                          value:
                              (_participantProgress.values.fold<double>(
                                        0,
                                        (sum, p) => sum + p.totalDistance,
                                      ) /
                                      5)
                                  .clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200]!,
                          foregroundColor:
                              _participantProgress.values.fold<double>(
                                    0,
                                    (sum, p) => sum + p.totalDistance,
                                  ) >=
                                  5
                              ? AppColors.success
                              : AppColors.primary,
                          height: 4,
                        ),
                      ] else ...[
                        // Strength progress display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_participantProgress.values.fold<int>(0, (sum, p) => sum + p.totalSets)} sets logged',
                              style: TextStyle(
                                fontSize: AppFontSize.sm,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              'Goal: 20 sets',
                              style: TextStyle(
                                fontSize: AppFontSize.xs,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AnimatedProgressBar(
                          value:
                              (_participantProgress.values.fold<int>(
                                        0,
                                        (sum, p) => sum + p.totalSets,
                                      ) /
                                      20)
                                  .clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200]!,
                          foregroundColor:
                              _participantProgress.values.fold<int>(
                                    0,
                                    (sum, p) => sum + p.totalSets,
                                  ) >=
                                  20
                              ? AppColors.success
                              : AppColors.primary,
                          height: 8,
                        ),
                      ],
                    ],
                  ),
                ),

              // Exercise/Cardio input section (Elite Brutalist Glass Card)
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildInputSection(),
                  ),
                ),
              ),

              // Cheers bar (Elite Brutalist Style)
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _cheersEmojis.map((emoji) {
                        return BounceAnimation(
                          onTap: () => _sendCheer(emoji),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // Enhanced Participant Progress Comparison View (for multi-participant sessions)
              if (_participantProgress.isNotEmpty && !_isSoloSession)
                ExpansionTile(
                  title: const Row(
                    children: [
                      Text('ðŸ“Š '),
                      Text(
                        'Progress Comparison',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${_participantProgress.length} participants â€¢ ${_participantProgress.values.fold<int>(0, (sum, p) => sum + p.totalSets)} total sets',
                  ),
                  initiallyExpanded: false,
                  backgroundColor: AppColors.primaryMuted.withValues(
                    alpha: 0.05,
                  ),
                  children: [..._buildProgressComparisonList()],
                ),

              const SizedBox(height: AppSpacing.sm),

              // Timeline
              Expanded(
                child: eventsAsync.when(
                  data: (events) =>
                      events.isEmpty && _localPendingEvents.isEmpty
                      ? const Center(
                          child: Text('No events yet. Log your first set!'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount:
                              _localPendingEvents.length +
                              events.length +
                              (events.length >= _eventLimit ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show Load More button at the top (index 0) if we hit the limit
                            if (events.length >= _eventLimit && index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _eventLimit += 50;
                                    });
                                  },
                                  icon: const Icon(Icons.history, size: 16),
                                  label: const Text('Load Older Events'),
                                ),
                              );
                            }

                            // Adjust index for Load More button
                            final listIndex = events.length >= _eventLimit
                                ? index - 1
                                : index;

                            // Show pending events (newest) at bottom?
                            // If logic is "bottom of list" (index=N), but this is standard ListView.
                            // Standard ListView: index 0 is top.
                            // Our events list is reversed (oldest -> newest).
                            // So events[0] is oldest. events[last] is newest.
                            // _localPendingEvents are NEWER than events.
                            // So they should be AFTER events.
                            // Order: [LoadMore?, ...events (old->new), ...pendingEvents (newest)]

                            if (listIndex < events.length) {
                              return _buildTimelineItem(events[listIndex]);
                            } else {
                              // Pending events
                              final pendingIndex = listIndex - events.length;
                              // _localPendingEvents was inserted at 0 (newest).
                              // If we want [A, B] (chronological) but list is [B, A] (reverse chronological)
                              // pendingIndex 0 -> _localPendingEvents[len-1] (oldest pending)
                              // pendingIndex 1 -> _localPendingEvents[len-2]
                              // So we need to render in reverse order of _localPendingEvents list.

                              final reversedIndex =
                                  _localPendingEvents.length - 1 - pendingIndex;
                              return Opacity(
                                opacity: 0.7,
                                child: _buildTimelineItem(
                                  _localPendingEvents[reversedIndex],
                                ),
                              );
                            }
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),

              // Local exercises summary
              if (_exercises.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    'Session Summary (${_exercises.length} Exercises)',
                  ),
                  subtitle: Text(
                    '${_exercises.fold(0, (sum, e) => sum + e.sets.length)} sets total',
                  ),
                  backgroundColor: AppColors.primaryMuted.withValues(
                    alpha: 0.1,
                  ),
                  children: [
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(8.0),
                      child: ListView.builder(
                        itemCount: _exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _exercises[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              exercise.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('${exercise.sets.length} sets'),
                            trailing: Text(
                              exercise.sets
                                  .map((s) => '${s.weight}kg x ${s.reps}')
                                  .join(', '),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    // Undo button
                    TextButton.icon(
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo Last Set'),
                      onPressed: _undoLastSet,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip({
    required String emoji,
    required String label,
    required String value,
    required double progress,
    required bool isLeader,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLeader
              ? Colors.amber.withValues(alpha: 0.5)
              : Colors.grey[200]!,
        ),
        boxShadow: isLeader
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLeader)
                const Icon(Icons.emoji_events, size: 12, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isLeader ? Colors.amber[800] : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedProgressBar(
            value: progress,
            backgroundColor: Colors.grey[100]!,
            foregroundColor: isLeader ? Colors.amber : AppColors.primary,
            height: 4,
          ),
        ],
      ),
    );
  }

  /// Build a chip showing current activity for a participant.
  Widget _buildCurrentActivityChip({
    required String label,
    required String exercise,
    required int setCount,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.15)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.success : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: isActive ? AppColors.success : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          Text(
            exercise.isNotEmpty ? exercise : 'Idle',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.primary : Colors.grey[600],
            ),
          ),
          if (setCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(Set $setCount)',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a chip showing cardio activity for a participant.
  Widget _buildCardioActivityChip({
    required String label,
    required double distance,
    required int duration,
    required String? activityType,
    required bool isActive,
  }) {
    final activityIcon = activityType == 'cycling'
        ? Icons.directions_bike
        : Icons.directions_run;
    final activityName = activityType == 'cycling' ? 'Cycling' : 'Running';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.15)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.success : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            activityIcon,
            size: 14,
            color: isActive ? AppColors.success : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          if (distance > 0 || duration > 0) ...[
            Text(
              '${distance.toStringAsFixed(2)}km',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.primary : Colors.grey[600],
              ),
            ),
            Text(
              ' / ${duration}min',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ] else
            Text(
              activityType != null ? activityName : 'Idle',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.primary : Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TimelineEvent event) {
    final iconData = switch (event.type) {
      SessionEventType.start => Icons.play_arrow_rounded,
      SessionEventType.join => Icons.person_add_rounded,
      SessionEventType.setLogged => Icons.fitness_center_rounded,
      SessionEventType.finish => Icons.flag_rounded,
      SessionEventType.voiceNote => Icons.mic_rounded,
      SessionEventType.cheer => Icons.celebration_rounded,
      _ => Icons.circle,
    };

    final iconColor = switch (event.type) {
      SessionEventType.cheer => AppColors.secondary,
      SessionEventType.voiceNote => const Color(0xFFFF9800),
      SessionEventType.finish => AppColors.success,
      SessionEventType.start => AppColors.primary,
      _ => AppColors.primary,
    };

    // Check for audio URL in voice note events
    final audioUrl = event.data?['audioUrl'] as String?;
    final isPlaying = audioUrl != null && _playingAudioUrl == audioUrl;

    // Check for emoji in cheer events
    final emoji = event.data?['emoji'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event icon or emoji
                if (event.type == SessionEventType.cheer && emoji != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(iconData, size: 16, color: iconColor),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.text,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      // Voice note playback button
                      if (event.type == SessionEventType.voiceNote &&
                          audioUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: VoiceNoteWaveform(
                            duration: event.data?['duration'],
                            isPlaying: isPlaying,
                            isLoading:
                                _isLoadingAudio && _playingAudioUrl == audioUrl,
                            onTap: () => _playAudio(audioUrl),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(event.timestamp),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: iconColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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

class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _fadeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.backgroundColor = Colors.grey,
    this.foregroundColor = Colors.blue,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * value,
                height: height,
                decoration: BoxDecoration(
                  color: foregroundColor,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

