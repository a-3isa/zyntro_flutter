/// Workout type enum with comprehensive exercise categories.
/// Expanded from basic strength/cardio to support specific activities.
enum WorkoutType {
  gym(
    value: 'gym',
    displayName: 'Gym',
    icon: 'fitness_center',
    category: 'strength',
  ),
  running(
    value: 'running',
    displayName: 'Running',
    icon: 'directions_run',
    category: 'cardio',
  ),
  cycling(
    value: 'cycling',
    displayName: 'Cycling',
    icon: 'directions_bike',
    category: 'cardio',
  ),
  swimming(
    value: 'swimming',
    displayName: 'Swimming',
    icon: 'pool',
    category: 'cardio',
  ),
  yoga(
    value: 'yoga',
    displayName: 'Yoga',
    icon: 'self_improvement',
    category: 'flexibility',
  ),
  hiit(value: 'hiit', displayName: 'HIIT', icon: 'timer', category: 'mixed'),
  walking(
    value: 'walking',
    displayName: 'Walking',
    icon: 'directions_walk',
    category: 'cardio',
  ),
  sports(
    value: 'sports',
    displayName: 'Sports',
    icon: 'sports_soccer',
    category: 'mixed',
  ),
  other(
    value: 'other',
    displayName: 'Other',
    icon: 'category',
    category: 'mixed',
  );

  /// The string value stored in Firestore.
  final String value;

  /// User-friendly display name.
  final String displayName;

  /// Icon identifier (maps to Icons.* in Flutter).
  final String icon;

  /// Category: 'strength', 'cardio', 'flexibility', or 'mixed'.
  final String category;

  const WorkoutType({
    required this.value,
    required this.displayName,
    required this.icon,
    required this.category,
  });

  /// Whether this workout type is cardio-focused.
  bool get isCardio => category == 'cardio';

  /// Whether this workout type is strength-focused.
  bool get isStrength => category == 'strength';

  /// Whether this workout type is flexibility-focused.
  bool get isFlexibility => category == 'flexibility';

  /// Whether this workout type is mixed (combines multiple categories).
  bool get isMixed => category == 'mixed';

  /// Whether this workout type requires distance tracking.
  bool get requiresDistanceTracking =>
      this == WorkoutType.running ||
      this == WorkoutType.cycling ||
      this == WorkoutType.swimming ||
      this == WorkoutType.walking;

  /// Whether this workout type requires set/rep tracking.
  bool get requiresSetTracking =>
      this == WorkoutType.gym || this == WorkoutType.hiit;

  /// Get display string for UI presentation.
  String toDisplayString() => displayName;

  /// Parse from string value, with backward compatibility for legacy types.
  /// Maps legacy 'strength' to 'gym' and 'cardio' to 'running'.
  static WorkoutType fromString(String value) {
    // Handle legacy values for backward compatibility
    if (value == 'strength') return WorkoutType.gym;
    if (value == 'cardio') return WorkoutType.running;
    if (value == 'both') return WorkoutType.other;

    return WorkoutType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WorkoutType.other,
    );
  }

  /// Get color for category (for UI categorization).
  static String getCategoryColor(String category) {
    switch (category) {
      case 'cardio':
        return 'blue';
      case 'strength':
        return 'orange';
      case 'flexibility':
        return 'green';
      case 'mixed':
        return 'purple';
      default:
        return 'grey';
    }
  }
}

/// Session status enum matching React Native constants.
enum SessionStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const SessionStatus(this.value);

  static SessionStatus fromString(String value) {
    return SessionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionStatus.active,
    );
  }
}

/// Follow status enum matching React Native constants.
enum FollowStatus {
  pending('pending'),
  approved('approved'),
  declined('declined');

  final String value;
  const FollowStatus(this.value);

  static FollowStatus fromString(String value) {
    return FollowStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FollowStatus.pending,
    );
  }
}

/// Buddy pair status enum matching React Native constants.
enum BuddyPairStatus {
  pending('pending'),
  active('active'),
  ended('ended');

  final String value;
  const BuddyPairStatus(this.value);

  static BuddyPairStatus fromString(String value) {
    return BuddyPairStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BuddyPairStatus.pending,
    );
  }
}

/// Session event type enum matching React Native constants.
enum SessionEventType {
  start('start'),
  join('join'),
  leave('leave'),
  exercise('exercise'),
  setLogged('set_logged'),
  cardioEntry('cardio_entry_logged'),
  voice('voice'),
  voiceNote('voice_note'),
  cheer('cheer'),
  photo('photo'),
  turnSwitch('turn_switch'),
  finish('finish');

  final String value;
  const SessionEventType(this.value);

  static SessionEventType fromString(String value) {
    return SessionEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionEventType.start,
    );
  }
}

/// Session mode enum.
enum SessionMode {
  turnBased('turn_based'),
  parallel('parallel');

  final String value;
  const SessionMode(this.value);

  static SessionMode fromString(String value) {
    return SessionMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionMode.turnBased,
    );
  }
}

/// Paired friend session partner type.
enum PairedPartnerKind {
  realFriend('real_friend'),
  bot('bot');

  final String value;
  const PairedPartnerKind(this.value);

  static PairedPartnerKind fromString(String value) {
    return PairedPartnerKind.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PairedPartnerKind.realFriend,
    );
  }
}

/// Invitation lifecycle for one-to-one workout sessions.
enum WorkoutInvitationStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  expired('expired'),
  cancelled('cancelled');

  final String value;
  const WorkoutInvitationStatus(this.value);

  static WorkoutInvitationStatus fromString(String value) {
    return WorkoutInvitationStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WorkoutInvitationStatus.pending,
    );
  }
}

/// Live progress state for each participant during a paired session.
enum ParticipantProgressStatus {
  waiting('waiting'),
  active('active'),
  resting('resting'),
  paused('paused'),
  disconnected('disconnected'),
  completed('completed');

  final String value;
  const ParticipantProgressStatus(this.value);

  static ParticipantProgressStatus fromString(String value) {
    return ParticipantProgressStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ParticipantProgressStatus.waiting,
    );
  }
}

/// Session phase enum for setup flows before live workouts begin.
enum SessionPhase {
  setup('setup'),
  live('live');

  final String value;
  const SessionPhase(this.value);

  static SessionPhase fromString(String value) {
    return SessionPhase.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionPhase.live,
    );
  }
}

/// App name constant.
const String appName = 'Zyntro';

/// Stable bot friend participant id for simulated paired workout sessions.
const String pairedBotFriendId = 'zyntro_bot_friend';

/// Real friend invitations expire if not answered within this period.
/// Long enough for the invite-first lobby handshake: the friend must be able to
/// receive the push and accept while the host is still building the plan.
const Duration pairedInviteTimeout = Duration(minutes: 10);
