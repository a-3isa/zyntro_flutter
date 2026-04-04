# Gym Session Flow And Theme Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved gym-session setup flow, private per-user plans, ready gating, guided live set logging, and session-first navy/neon theme rollout without breaking non-gym sessions.

**Architecture:** Extend the existing session document with a `phase`, add per-user gym plan documents under each session, route gym starts into a new setup page, and keep the live room route while swapping gym logging from a free-form form to a plan-driven set-completion flow. Keep the backend shared state small, use the existing local exercise catalog as the primary database source, and scope the visual refresh to the session journey first.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Cloud Firestore, flutter_test, mocktail

---

## File Structure

- `lib/core/constants/constants.dart`
  Add `SessionPhase` so old and new session documents share one enum source.

- `lib/core/models/models.dart`
  Extend `Session` to parse a `phase` field while defaulting legacy sessions to `live`.

- `lib/features/session/domain/gym_session_plan.dart`
  New gym-plan models for catalog and custom exercises, plus readiness aggregation helpers.

- `lib/services/session_service.dart`
  Add gym-setup APIs for phase-aware creation, plan save/load, plan cloning, ready-state writes, and live-phase promotion.

- `lib/app/navigation/app_router.dart`
  Add the gym setup route and redirect live gym sessions out of setup.

- `lib/features/session/presentation/start_session_page.dart`
  Route gym starts to setup while keeping non-gym starts on the existing room path.

- `lib/features/session/presentation/gym_session_setup_page.dart`
  New setup page for plan editing, readiness, waiting, and redirect-to-live behavior.

- `lib/features/session/presentation/widgets/gym_plan_editor.dart`
  Focused UI for ordered exercises and planned set counts.

- `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`
  Searchable exercise picker backed by `GymExercises`, with an explicit custom fallback.

- `lib/features/session/presentation/widgets/gym_live_session_panel.dart`
  Guided gym live UI that focuses on the active exercise and current set.

- `lib/features/session/presentation/widgets/post_set_log_sheet.dart`
  Reps-and-weight entry after a set is finished.

- `lib/features/session/presentation/session_room_page.dart`
  Keep the existing route and session shell, but switch gym mode to the new guided widgets and plan-driven state.

- `lib/core/theme/app_theme.dart`
  Add session-scoped navy/neon tokens without forcing a global repaint.

- `test/features/session/domain/gym_session_plan_test.dart`
  Unit coverage for plan serialization, custom/catalog exercises, and readiness logic.

- `test/services/session_service_test.dart`
  Service coverage for setup-phase session creation, plan cloning, and ready promotion wiring.

- `test/features/session/presentation/start_session_page_test.dart`
  Widget coverage for gym-vs-non-gym start routing.

- `test/features/session/presentation/gym_session_setup_page_test.dart`
  Widget coverage for setup loading, plan validation, custom fallback, and ready-state gating.

- `test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`
  Widget coverage for search, catalog picks, and custom add fallback.

- `test/features/session/presentation/widgets/gym_live_session_panel_test.dart`
  Widget coverage for start-set, finish-set, and partner-turn rendering.

- `test/core/theme/session_palette_contract_test.dart`
  Contract coverage for the approved navy/neon session palette tokens.

### Task 1: Add Session Phase And Gym Plan Models

**Files:**
- Create: `lib/features/session/domain/gym_session_plan.dart`
- Modify: `lib/core/constants/constants.dart`
- Modify: `lib/core/models/models.dart`
- Test: `test/features/session/domain/gym_session_plan_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/data/gym_exercises.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';

class _FakeSessionDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeSessionDocumentSnapshot({
    required this.snapshotId,
    required this.snapshotData,
  });

  final String snapshotId;
  final Map<String, dynamic> snapshotData;

  @override
  String get id => snapshotId;

  @override
  Map<String, dynamic>? data() => snapshotData;
}

void main() {
  test('gym session plan round-trips catalog and custom exercises', () {
    final plan = GymSessionPlan(
      userId: 'host_1',
      source: GymSessionPlanSource.hostTemplate,
      isReady: false,
      exercises: [
        PlannedExercise.catalog(
          id: 'bench_0',
          exerciseId: 'bench_press',
          name: 'Bench Press',
          muscleGroup: MuscleGroup.chest,
          equipment: const [Equipment.barbell, Equipment.bench],
          plannedSets: 4,
          order: 0,
        ),
        PlannedExercise.custom(
          id: 'custom_1',
          name: 'JM Press',
          plannedSets: 3,
          order: 1,
        ),
      ],
    );

    final encoded = plan.toMap();
    final decoded = GymSessionPlan.fromMap(encoded);

    expect(decoded.exercises.first.exerciseId, 'bench_press');
    expect(decoded.exercises.last.sourceType, PlannedExerciseSource.custom);
  });

  test('legacy sessions default to live phase', () {
    final session = Session.fromFirestore(
      _FakeSessionDocumentSnapshot(
        snapshotId: 'session_1',
        snapshotData: {
          'type': 'gym',
          'title': 'Push Day',
          'hostId': 'host_1',
          'participants': ['host_1'],
          'status': 'active',
          'mode': 'turn_based',
        },
      ),
    );

    expect(session.phase, SessionPhase.live);
  });

  test('all joined participants must be ready before live starts', () {
    final allReady = areAllJoinedGymParticipantsReady(
      participants: const ['host_1', 'user_2'],
      plans: const [
        GymSessionPlan(userId: 'host_1', isReady: true, exercises: []),
        GymSessionPlan(userId: 'user_2', isReady: false, exercises: []),
      ],
    );

    expect(allReady, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/session/domain/gym_session_plan_test.dart`
Expected: FAIL with errors such as `Target of URI doesn't exist: 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart'` and `The getter 'phase' isn't defined for the type 'Session'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/constants/constants.dart
enum SessionPhase {
  setup('setup'),
  live('live');

  final String value;

  const SessionPhase(this.value);

  static SessionPhase fromString(String value) {
    return SessionPhase.values.firstWhere(
      (phase) => phase.value == value,
      orElse: () => SessionPhase.live,
    );
  }
}

// lib/features/session/domain/gym_session_plan.dart
enum GymSessionPlanSource { hostTemplate, personal }
enum PlannedExerciseSource { catalog, custom }

class GymSessionPlan {
  final String userId;
  final GymSessionPlanSource source;
  final bool isReady;
  final List<PlannedExercise> exercises;

  const GymSessionPlan({
    required this.userId,
    this.source = GymSessionPlanSource.personal,
    this.isReady = false,
    this.exercises = const [],
  });

  factory GymSessionPlan.fromMap(Map<String, dynamic> data) => GymSessionPlan(
    userId: data['userId'] as String,
    source: (data['source'] == 'host_template')
        ? GymSessionPlanSource.hostTemplate
        : GymSessionPlanSource.personal,
    isReady: data['isReady'] as bool? ?? false,
    exercises: (data['exercises'] as List<dynamic>? ?? const [])
        .map((entry) => PlannedExercise.fromMap(entry as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'source': source == GymSessionPlanSource.hostTemplate
        ? 'host_template'
        : 'personal',
    'isReady': isReady,
    'exercises': exercises.map((exercise) => exercise.toMap()).toList(),
  };
}

bool areAllJoinedGymParticipantsReady({
  required List<String> participants,
  required List<GymSessionPlan> plans,
}) {
  if (participants.isEmpty) return false;
  final byUser = {for (final plan in plans) plan.userId: plan};
  return participants.every((userId) => byUser[userId]?.isReady == true);
}

// lib/core/models/models.dart
class Session {
  final SessionPhase phase;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/session/domain/gym_session_plan_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/constants.dart lib/core/models/models.dart lib/features/session/domain/gym_session_plan.dart test/features/session/domain/gym_session_plan_test.dart
git commit -m "feat: add gym session phase and plan models"
```

### Task 2: Extend SessionService For Gym Setup Lifecycle

**Files:**
- Modify: `lib/services/session_service.dart`
- Modify: `test/services/session_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('createSession stores setup phase when requested', () async {
  final hostId = 'host_1';

  when(() => mockUserCacheService.getUser(hostId)).thenAnswer(
    (_) async => User(
      id: hostId,
      displayName: 'Host',
      photoURL: null,
      isPrivate: false,
      workoutPreference: WorkoutType.gym,
      beginnerFlag: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  final mockQuery = MockQuery();
  final mockSnapshot = MockQuerySnapshot();
  when(
    () => mockSessionsCollection.where('participants', arrayContains: hostId),
  ).thenReturn(mockQuery);
  when(() => mockQuery.where('status', isEqualTo: 'active')).thenReturn(mockQuery);
  when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
  when(() => mockSnapshot.docs).thenReturn([]);

  await sessionService.createSession(
    hostId: hostId,
    type: WorkoutType.gym.value,
    title: 'Gym Session',
    phase: SessionPhase.setup,
  );

  final sessionPayload = verify(
    () => mockBatch.set(mockSessionDoc, captureAny()),
  ).captured.first as Map<String, dynamic>;

  expect(sessionPayload['phase'], SessionPhase.setup.value);
});

test('ensureGymPlan clones host template when participant plan is missing', () async {
  final hostPlan = GymSessionPlan(
    userId: 'host_1',
    source: GymSessionPlanSource.hostTemplate,
    exercises: [
      PlannedExercise.catalog(
        id: 'bench_0',
        exerciseId: 'bench_press',
        name: 'Bench Press',
        muscleGroup: MuscleGroup.chest,
        equipment: const [Equipment.barbell],
        plannedSets: 4,
        order: 0,
      ),
    ],
  );

  final plansCollection = MockCollectionReference();
  final hostPlanDoc = MockDocumentReference();
  final userPlanDoc = MockDocumentReference();
  final hostSnapshot = MockDocumentSnapshot();
  final emptySnapshot = MockDocumentSnapshot();

  when(() => mockSessionDoc.collection('plans')).thenReturn(plansCollection);
  when(() => plansCollection.doc('host_1')).thenReturn(hostPlanDoc);
  when(() => plansCollection.doc('user_2')).thenReturn(userPlanDoc);
  when(() => userPlanDoc.get()).thenAnswer((_) async => emptySnapshot);
  when(() => emptySnapshot.exists).thenReturn(false);
  when(() => emptySnapshot.data()).thenReturn(null);
  when(() => hostPlanDoc.get()).thenAnswer((_) async => hostSnapshot);
  when(() => hostSnapshot.exists).thenReturn(true);
  when(() => hostSnapshot.data()).thenReturn(hostPlan.toMap());
  when(() => userPlanDoc.set(any())).thenAnswer((_) async {});

  final plan = await sessionService.ensureGymPlan(
    sessionId: 'session_1',
    hostId: 'host_1',
    userId: 'user_2',
  );

  expect(plan.userId, 'user_2');
  expect(plan.source, GymSessionPlanSource.personal);
  expect(plan.exercises.single.name, 'Bench Press');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/session_service_test.dart`
Expected: FAIL with errors such as `The named parameter 'phase' isn't defined` and `The method 'ensureGymPlan' isn't defined for the type 'SessionService'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/session_service.dart
Future<String> createSession({
  required String hostId,
  required String type,
  required String title,
  String? buddyPairId,
  List<String>? invitedUserIds,
  SessionMode mode = SessionMode.turnBased,
  SessionPhase phase = SessionPhase.live,
}) async {
  batch.set(sessionRef, {
    'type': type,
    'title': title,
    'hostId': hostId,
    'participants': [hostId],
    'invitedUserIds': invitedUserIds ?? [],
    'status': 'active',
    'phase': phase.value,
    'createdAt': FieldValue.serverTimestamp(),
    'startedAt': FieldValue.serverTimestamp(),
    'buddyPairId': buddyPairId,
    'mode': mode.value,
    'activeUserId': mode == SessionMode.turnBased ? hostId : null,
  });
}

Future<void> saveGymPlan({
  required String sessionId,
  required GymSessionPlan plan,
}) {
  return _firestore
      .collection('sessions')
      .doc(sessionId)
      .collection('plans')
      .doc(plan.userId)
      .set({
        ...plan.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}

Future<GymSessionPlan> ensureGymPlan({
  required String sessionId,
  required String hostId,
  required String userId,
}) async {
  final plansRef = _firestore.collection('sessions').doc(sessionId).collection('plans');
  final existing = await plansRef.doc(userId).get();
  if (existing.exists && existing.data() != null) {
    return GymSessionPlan.fromMap(existing.data()!);
  }

  final hostSnapshot = await plansRef.doc(hostId).get();
  final hostPlan = GymSessionPlan.fromMap(hostSnapshot.data()!);
  final cloned = GymSessionPlan(
    userId: userId,
    source: GymSessionPlanSource.personal,
    isReady: false,
    exercises: hostPlan.exercises,
  );
  await saveGymPlan(sessionId: sessionId, plan: cloned);
  return cloned;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/session_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/session_service.dart test/services/session_service_test.dart
git commit -m "feat: add gym setup session service APIs"
```

### Task 3: Route Gym Starts Into Setup And Add The Setup Shell

**Files:**
- Modify: `lib/app/navigation/app_router.dart`
- Modify: `lib/features/session/presentation/start_session_page.dart`
- Create: `lib/features/session/presentation/gym_session_setup_page.dart`
- Test: `test/features/session/presentation/start_session_page_test.dart`
- Test: `test/features/session/presentation/gym_session_setup_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/session/presentation/gym_session_setup_page.dart';
import 'package:zyntro_flutter/features/session/presentation/start_session_page.dart';
import 'package:zyntro_flutter/services/session_service.dart';

class MockSessionService extends Mock implements SessionService {}

Widget buildStartSessionHarness(GoRouter router, SessionService sessionService) {
  final container = ProviderContainer(
    overrides: [
      sessionServiceProvider.overrideWithValue(sessionService),
      authSessionProvider.overrideWith(
        (ref) => Stream.value(
          const AuthUserEntity(
            id: 'host_1',
            email: 'host@example.com',
            displayName: 'Host',
            photoUrl: null,
            emailVerified: true,
            providerIds: ['password'],
          ),
        ),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('gym start navigates to setup route', (tester) async {
    final sessionService = MockSessionService();
    when(
      () => sessionService.createSession(
        hostId: any(named: 'hostId'),
        type: any(named: 'type'),
        title: any(named: 'title'),
        buddyPairId: any(named: 'buddyPairId'),
        invitedUserIds: any(named: 'invitedUserIds'),
        mode: any(named: 'mode'),
        phase: any(named: 'phase'),
      ),
    ).thenAnswer((_) async => 'session_42');

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const StartSessionPage()),
        GoRoute(
          path: '/session/setup/:sessionId',
          builder: (_, state) => GymSessionSetupPage(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(buildStartSessionHarness(router, sessionService));
    await tester.tap(find.text('Gym'));
    await tester.tap(find.textContaining('Start Gym Session'));
    await tester.pumpAndSettle();

    expect(find.byType(GymSessionSetupPage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/session/presentation/start_session_page_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:zyntro_flutter/features/session/presentation/gym_session_setup_page.dart'` or a missing route failure.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/app/navigation/app_router.dart
class AppRoutes {
  static const gymSessionSetup = '/session/setup/:sessionId';
}

GoRoute(
  path: AppRoutes.gymSessionSetup,
  pageBuilder: (context, state) => buildPremiumPageTransition(
    context: context,
    state: state,
    child: GymSessionSetupPage(
      sessionId: state.pathParameters['sessionId']!,
    ),
  ),
),

// lib/features/session/presentation/start_session_page.dart
final sessionId = await ref.read(sessionServiceProvider).createSession(
  hostId: uid,
  type: _selectedType.value,
  title: '${_selectedType.displayName} Session',
  mode: _selectedMode,
  invitedUserIds: _selectedFriends.isNotEmpty ? _selectedFriends.toList() : null,
  phase: _selectedType == WorkoutType.gym
      ? SessionPhase.setup
      : SessionPhase.live,
);

if (mounted) {
  final route = _selectedType == WorkoutType.gym
      ? '/session/setup/$sessionId'
      : '/session/room/$sessionId?type=${_selectedType.value}';
  context.push(route);
}

// lib/features/session/presentation/gym_session_setup_page.dart
class GymSessionSetupPage extends ConsumerWidget {
  final String sessionId;

  const GymSessionSetupPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider(sessionId));
    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          return const Scaffold(body: Center(child: Text('Session not found')));
        }
        if (session.phase == SessionPhase.live) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/session/room/${session.id}?type=${session.type}');
          });
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/session/presentation/start_session_page_test.dart test/features/session/presentation/gym_session_setup_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/app/navigation/app_router.dart lib/features/session/presentation/start_session_page.dart lib/features/session/presentation/gym_session_setup_page.dart test/features/session/presentation/start_session_page_test.dart test/features/session/presentation/gym_session_setup_page_test.dart
git commit -m "feat: route gym sessions into setup flow"
```

### Task 4: Build The Catalog Picker And Plan Editor

**Files:**
- Create: `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`
- Create: `lib/features/session/presentation/widgets/gym_plan_editor.dart`
- Modify: `lib/features/session/presentation/gym_session_setup_page.dart`
- Test: `test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`
- Test: `test/features/session/presentation/gym_session_setup_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/gym_exercise_picker_sheet.dart';

void main() {
  testWidgets('picker searches catalog and offers custom fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GymExercisePickerSheet(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jm press');
    await tester.pumpAndSettle();
    expect(find.text('Add Custom Exercise'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:zyntro_flutter/features/session/presentation/widgets/gym_exercise_picker_sheet.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart
class GymExercisePickerSheet extends StatefulWidget {
  final ValueChanged<PlannedExercise>? onPicked;
  final ValueChanged<String>? onAddCustom;

  const GymExercisePickerSheet({
    super.key,
    this.onPicked,
    this.onAddCustom,
  });

  @override
  State<GymExercisePickerSheet> createState() => _GymExercisePickerSheetState();
}

class _GymExercisePickerSheetState extends State<GymExercisePickerSheet> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final results = GymExercises.search(_controller.text);
    final showCustom = _controller.text.trim().isNotEmpty &&
        results.every((exercise) =>
            exercise.name.toLowerCase() != _controller.text.trim().toLowerCase());

    return Column(
      children: [
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Search exercises'),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final exercise in results)
                ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(exercise.muscleGroup.displayName),
                  onTap: () => widget.onPicked?.call(
                    PlannedExercise.catalog(
                      id: '${exercise.id}_${DateTime.now().millisecondsSinceEpoch}',
                      exerciseId: exercise.id,
                      name: exercise.name,
                      muscleGroup: exercise.muscleGroup,
                      equipment: exercise.equipment,
                      plannedSets: 3,
                      order: 0,
                    ),
                  ),
                ),
              if (showCustom)
                ListTile(
                  title: const Text('Add Custom Exercise'),
                  subtitle: Text(_controller.text.trim()),
                  onTap: () => widget.onAddCustom?.call(_controller.text.trim()),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// lib/features/session/presentation/widgets/gym_plan_editor.dart
class GymPlanEditor extends StatelessWidget {
  final List<PlannedExercise> exercises;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;
  final void Function(int index, int plannedSets) onSetsChanged;

  const GymPlanEditor({
    super.key,
    required this.exercises,
    required this.onAddExercise,
    required this.onRemoveExercise,
    required this.onSetsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < exercises.length; index++)
          ListTile(
            title: Text(exercises[index].name),
            subtitle: Text('${exercises[index].plannedSets} planned sets'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onRemoveExercise(index),
            ),
          ),
        FilledButton.icon(
          onPressed: onAddExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add Exercise'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart lib/features/session/presentation/widgets/gym_plan_editor.dart lib/features/session/presentation/gym_session_setup_page.dart test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart test/features/session/presentation/gym_session_setup_page_test.dart
git commit -m "feat: add gym exercise picker and plan editor"
```

### Task 5: Wire Plan Cloning, Ready State, And Waiting UI

**Files:**
- Modify: `lib/features/session/presentation/gym_session_setup_page.dart`
- Modify: `lib/services/session_service.dart`
- Test: `test/features/session/presentation/gym_session_setup_page_test.dart`
- Test: `test/services/session_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/presentation/gym_session_setup_page.dart';
import 'package:zyntro_flutter/services/session_service.dart';

class MockSessionService extends Mock implements SessionService {}

Session buildSession({required SessionPhase phase}) => Session(
  phase: phase,
  id: 'session_1',
  type: 'gym',
  title: 'Gym Session',
  hostId: 'host_1',
  participants: const ['host_1', 'user_2'],
  status: SessionStatus.active,
  mode: SessionMode.turnBased,
  createdAt: DateTime(2026, 3, 31),
  startedAt: DateTime(2026, 3, 31),
);

GymSessionPlan buildValidPlan({required bool isReady}) => GymSessionPlan(
  userId: 'host_1',
  isReady: isReady,
  exercises: const [
    PlannedExercise.custom(
      id: 'custom_0',
      name: 'JM Press',
      plannedSets: 3,
      order: 0,
    ),
  ],
);

Widget buildGymSetupHarness(SessionService service) {
  final container = ProviderContainer(
    overrides: [
      sessionServiceProvider.overrideWithValue(service),
      authSessionProvider.overrideWith(
        (ref) => Stream.value(
          const AuthUserEntity(
            id: 'host_1',
            email: 'host@example.com',
            displayName: 'Host',
            photoUrl: null,
            emailVerified: true,
            providerIds: ['password'],
          ),
        ),
      ),
      sessionProvider('session_1').overrideWith(
        (ref) => Stream.value(buildSession(phase: SessionPhase.setup)),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: GymSessionSetupPage(sessionId: 'session_1'),
    ),
  );
}

void main() {
  testWidgets('ready stays disabled until the plan is valid', (tester) async {
    final service = MockSessionService();
    when(() => service.listenToGymPlan(any(), any()))
        .thenAnswer((_) => Stream.value(const GymSessionPlan(userId: 'host_1')));

    await tester.pumpWidget(buildGymSetupHarness(service));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ready'),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('participant sees waiting state after tapping ready', (tester) async {
    final service = MockSessionService();
    when(() => service.listenToSession(any())).thenAnswer(
      (_) => Stream.value(buildSession(phase: SessionPhase.setup)),
    );
    when(() => service.listenToGymPlan(any(), any())).thenAnswer(
      (_) => Stream.value(buildValidPlan(isReady: true)),
    );

    await tester.pumpWidget(buildGymSetupHarness(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('Waiting'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/session/presentation/gym_session_setup_page_test.dart`
Expected: FAIL because the setup page does not yet hydrate plans, validate readiness, or show waiting state.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/session/presentation/gym_session_setup_page.dart
class _GymSessionSetupPageState extends ConsumerState<GymSessionSetupPage> {
  List<PlannedExercise> _draftExercises = const [];
  bool _savingReady = false;

  bool get _isPlanValid =>
      _draftExercises.isNotEmpty &&
      _draftExercises.every((exercise) => exercise.plannedSets > 0);

  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureJoinedPlan);
  }

  Future<void> _ensureJoinedPlan() async {
    final auth = ref.read(authSessionProvider).valueOrNull;
    final session = await ref.read(sessionProvider(widget.sessionId).future);
    if (auth == null || session == null) return;

    if (!session.participants.contains(auth.id)) {
      await ref.read(sessionServiceProvider).joinSession(widget.sessionId, auth.id);
    }

    final plan = await ref.read(sessionServiceProvider).ensureGymPlan(
      sessionId: widget.sessionId,
      hostId: session.hostId,
      userId: auth.id,
    );

    if (mounted) {
      setState(() => _draftExercises = plan.exercises);
    }
  }

  Future<void> _markReady() async {
    if (!_isPlanValid || _savingReady) return;
    setState(() => _savingReady = true);

    final auth = ref.read(authSessionProvider).valueOrNull!;
    final plan = GymSessionPlan(
      userId: auth.id,
      source: GymSessionPlanSource.personal,
      isReady: true,
      exercises: _draftExercises,
    );

    await ref.read(sessionServiceProvider).saveGymPlan(
      sessionId: widget.sessionId,
      plan: plan,
    );
    await ref.read(sessionServiceProvider).setGymPlanReady(
      sessionId: widget.sessionId,
      userId: auth.id,
      isReady: true,
    );

    if (mounted) {
      setState(() => _savingReady = false);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/session/presentation/gym_session_setup_page_test.dart test/services/session_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/presentation/gym_session_setup_page.dart lib/services/session_service.dart test/features/session/presentation/gym_session_setup_page_test.dart test/services/session_service_test.dart
git commit -m "feat: add gym setup ready state and waiting flow"
```

### Task 6: Switch Gym Room Mode To Guided Set Execution

**Files:**
- Create: `lib/features/session/presentation/widgets/gym_live_session_panel.dart`
- Create: `lib/features/session/presentation/widgets/post_set_log_sheet.dart`
- Modify: `lib/features/session/presentation/session_room_page.dart`
- Test: `test/features/session/presentation/widgets/gym_live_session_panel_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/data/gym_exercises.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/gym_live_session_panel.dart';

void main() {
  testWidgets('live panel shows current set progress and finish action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GymLiveSessionPanel(
            exercise: PlannedExercise.catalog(
              id: 'bench_0',
              exerciseId: 'bench_press',
              name: 'Bench Press',
              muscleGroup: MuscleGroup.chest,
              equipment: const [Equipment.barbell],
              plannedSets: 4,
              order: 0,
            ),
            currentSetNumber: 2,
            isUsersTurn: true,
            isSetRunning: true,
            onStartSet: () {},
            onFinishSet: () {},
          ),
        ),
      ),
    );

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Set 2 of 4'), findsOneWidget);
    expect(find.text('Finish Set'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/session/presentation/widgets/gym_live_session_panel_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:zyntro_flutter/features/session/presentation/widgets/gym_live_session_panel.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/session/presentation/widgets/gym_live_session_panel.dart
class GymLiveSessionPanel extends StatelessWidget {
  final PlannedExercise exercise;
  final int currentSetNumber;
  final bool isUsersTurn;
  final bool isSetRunning;
  final VoidCallback onStartSet;
  final VoidCallback onFinishSet;

  const GymLiveSessionPanel({
    super.key,
    required this.exercise,
    required this.currentSetNumber,
    required this.isUsersTurn,
    required this.isSetRunning,
    required this.onStartSet,
    required this.onFinishSet,
  });

  @override
  Widget build(BuildContext context) {
    if (!isUsersTurn) {
      return Card(
        child: ListTile(
          title: Text(exercise.name),
          subtitle: const Text('Partner turn'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall),
        Text('Set $currentSetNumber of ${exercise.plannedSets}'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isSetRunning ? onFinishSet : onStartSet,
          child: Text(isSetRunning ? 'Finish Set' : 'Start Set'),
        ),
      ],
    );
  }
}

// lib/features/session/presentation/widgets/post_set_log_sheet.dart
Future<({int reps, double? weight})?> showPostSetLogSheet(
  BuildContext context,
) {
  final repsController = TextEditingController();
  final weightController = TextEditingController();
  return showModalBottomSheet<({int reps, double? weight})>(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: repsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
          ),
          TextField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (optional)'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop((
                reps: int.parse(repsController.text),
                weight: weightController.text.isEmpty
                    ? null
                    : double.parse(weightController.text),
              ));
            },
            child: const Text('Save Set'),
          ),
        ],
      ),
    ),
  );
}

// lib/features/session/presentation/session_room_page.dart
if (_workoutType == WorkoutType.gym) {
  return GymLiveSessionPanel(
    exercise: _selectedPlannedExercise!,
    currentSetNumber: _currentSetNumber,
    isUsersTurn: _isCurrentUsersTurn,
    isSetRunning: _isCurrentSetRunning,
    onStartSet: () => setState(() => _isCurrentSetRunning = true),
    onFinishSet: _handleFinishGymSet,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/session/presentation/widgets/gym_live_session_panel_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/presentation/widgets/gym_live_session_panel.dart lib/features/session/presentation/widgets/post_set_log_sheet.dart lib/features/session/presentation/session_room_page.dart test/features/session/presentation/widgets/gym_live_session_panel_test.dart
git commit -m "feat: add guided gym live room widgets"
```

### Task 7: Add Session Palette Tokens And Apply The Theme Rollout

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/features/session/presentation/start_session_page.dart`
- Modify: `lib/features/session/presentation/gym_session_setup_page.dart`
- Modify: `lib/features/session/presentation/widgets/gym_live_session_panel.dart`
- Test: `test/core/theme/session_palette_contract_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  test('session palette matches approved figma colors', () {
    expect(AppColors.sessionNavy900, const Color(0xFF0A0E27));
    expect(AppColors.sessionNavy800, const Color(0xFF151B3D));
    expect(AppColors.sessionNavy700, const Color(0xFF1E2749));
    expect(AppColors.sessionNeonGreen, const Color(0xFF39FF14));
    expect(AppColors.sessionMutedText, const Color(0xFFA0A0AC));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/session_palette_contract_test.dart`
Expected: FAIL because the session-specific palette constants do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/theme/app_theme.dart
class AppColors {
  static const Color sessionNavy900 = Color(0xFF0A0E27);
  static const Color sessionNavy800 = Color(0xFF151B3D);
  static const Color sessionNavy700 = Color(0xFF1E2749);
  static const Color sessionNeonGreen = Color(0xFF39FF14);
  static const Color sessionNeonGreenHover = Color(0xFF2EE00F);
  static const Color sessionMutedText = Color(0xFFA0A0AC);
  static const Color sessionSubtleText = Color(0xFF8B8B98);
}

// lib/features/session/presentation/start_session_page.dart
return Scaffold(
  backgroundColor: AppColors.sessionNavy900,
  body: Column(
    children: [
      Container(
        decoration: BoxDecoration(
          color: AppColors.sessionNavy800,
          border: Border(
            bottom: BorderSide(color: AppColors.sessionNavy700, width: 1),
          ),
        ),
      ),
    ],
  ),
);

// lib/features/session/presentation/gym_session_setup_page.dart
Container(
  decoration: BoxDecoration(
    color: AppColors.sessionNavy800,
    border: Border.all(color: AppColors.sessionNavy700),
  ),
  child: FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.sessionNeonGreen,
      foregroundColor: AppColors.sessionNavy900,
    ),
    onPressed: _isPlanValid ? _markReady : null,
    child: const Text('Ready'),
  ),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/session_palette_contract_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart lib/features/session/presentation/start_session_page.dart lib/features/session/presentation/gym_session_setup_page.dart lib/features/session/presentation/widgets/gym_live_session_panel.dart test/core/theme/session_palette_contract_test.dart
git commit -m "feat: apply approved session palette"
```

## Final Verification

Run:

```bash
flutter test test/features/session/domain/gym_session_plan_test.dart
flutter test test/services/session_service_test.dart
flutter test test/features/session/presentation/start_session_page_test.dart
flutter test test/features/session/presentation/gym_session_setup_page_test.dart
flutter test test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart
flutter test test/features/session/presentation/widgets/gym_live_session_panel_test.dart
flutter test test/core/theme/session_palette_contract_test.dart
flutter analyze lib/features/session lib/services/session_service.dart lib/core/theme/app_theme.dart
```

Expected:

- all targeted tests pass
- analyzer returns no new errors in the touched session/theme files

Manual QA checklist:

1. Start a solo gym session and confirm it opens setup instead of the live room.
2. Add two catalog exercises, set planned sets, tap `Ready`, and confirm the room opens in guided gym mode.
3. Search for a missing movement, use `Add Custom Exercise`, and confirm it survives setup and live logging.
4. Start a partner gym session, join from the invitee account, confirm the invitee receives a private copy of the host plan, and edit only the invitee plan.
5. Confirm the session does not enter live mode until every joined participant is ready.
6. Finish a gym set and verify that reps and weight are entered after the set, not before it.
7. Confirm non-gym sessions still open the existing live room directly.
8. Spot-check the start page, setup page, and gym live widgets against the approved navy/neon palette.
