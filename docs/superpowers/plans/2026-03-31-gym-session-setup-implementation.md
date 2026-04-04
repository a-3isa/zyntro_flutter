# Gym Session Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a gym-only setup phase where the host creates an exercise list with planned sets, each participant gets a private editable copy, everyone marks ready, and the live room logs completed weight and reps against that plan.

**Architecture:** Extend sessions with an additive `phase` field and store per-user gym plans in `sessions/{sessionId}/plans/{userId}`. Route gym starts through a new setup page, then update the existing room page to use the saved personal plan instead of free-form exercise creation.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Cloud Firestore, flutter_test, mocktail

---

### Task 1: Add session phase and gym plan models

**Files:**
- Modify: `lib/core/constants/constants.dart`
- Modify: `lib/core/models/models.dart`
- Test: `test/models/models_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
test('SessionPhase parses setup and defaults unknown values to live', () {
  expect(SessionPhase.fromString('setup'), SessionPhase.setup);
  expect(SessionPhase.fromString('oops'), SessionPhase.live);
});

test('GymSessionPlan serializes exercises and ready state', () {
  final plan = GymSessionPlan(
    userId: 'user-1',
    source: GymSessionPlanSource.hostTemplate,
    isReady: true,
    exercises: const [
      PlannedExercise(id: 'bench', name: 'Bench Press', plannedSets: 4, order: 0),
    ],
    createdAt: DateTime(2026, 3, 31),
    updatedAt: DateTime(2026, 3, 31),
  );

  final restored = GymSessionPlan.fromMap(plan.toMap());
  expect(restored.exercises.single.plannedSets, 4);
  expect(restored.isReady, isTrue);
});
```

- [ ] **Step 2: Run the failing tests**

Run: `flutter test test/models/models_test.dart`
Expected: FAIL with undefined `SessionPhase`, `PlannedExercise`, or `GymSessionPlan`.

- [ ] **Step 3: Implement the minimal model code**

```dart
enum SessionPhase { setup('setup'), live('live'); }
enum GymSessionPlanSource { hostTemplate('host_template'), personal('personal'); }
class PlannedExercise { /* id, name, plannedSets, order, toMap/fromMap */ }
class GymSessionPlan { /* userId, source, isReady, exercises, timestamps, toMap/fromMap */ }
```

Also extend `Session` with:

```dart
final SessionPhase phase;
```

and parse it with:

```dart
phase: SessionPhase.fromString(data['phase'] ?? 'live'),
```

- [ ] **Step 4: Re-run the model tests**

Run: `flutter test test/models/models_test.dart`
Expected: PASS.

### Task 2: Extend SessionService for gym setup lifecycle

**Files:**
- Modify: `lib/services/session_service.dart`
- Test: `test/services/session_service_test.dart`

- [ ] **Step 1: Write the failing service tests**

```dart
test('createSession stores setup phase for gym sessions', () async {
  await sessionService.createSession(
    hostId: 'host_123',
    type: WorkoutType.gym.value,
    title: 'Gym Session',
    mode: SessionMode.turnBased,
  );

  final captured = verify(() => mockBatch.set(mockSessionDoc, captureAny())).captured.first as Map<String, dynamic>;
  expect(captured['phase'], SessionPhase.setup.value);
});

test('saveGymSessionPlan writes a personal plan document', () async {
  final plan = GymSessionPlan(
    userId: 'host_123',
    source: GymSessionPlanSource.hostTemplate,
    isReady: false,
    exercises: const [PlannedExercise(id: 'bench', name: 'Bench Press', plannedSets: 4, order: 0)],
    createdAt: DateTime(2026, 3, 31),
    updatedAt: DateTime(2026, 3, 31),
  );

  await sessionService.saveGymSessionPlan('session_123', plan);
  verify(() => mockPlanDoc.set(any())).called(1);
});
```

- [ ] **Step 2: Run the failing service tests**

Run: `flutter test test/services/session_service_test.dart`
Expected: FAIL because gym phase branching and plan APIs do not exist yet.

- [ ] **Step 3: Implement the service changes**

Add phase branching inside `createSession`:

```dart
final phase = type == WorkoutType.gym.value
    ? SessionPhase.setup.value
    : SessionPhase.live.value;
```

Persist it in the session doc and add these methods:

```dart
Future<void> saveGymSessionPlan(String sessionId, GymSessionPlan plan)
Future<GymSessionPlan?> getGymSessionPlan(String sessionId, String userId)
Future<void> ensureGymSessionPlan({ required String sessionId, required String userId, required GymSessionPlan hostTemplate })
Future<void> setGymSessionPlanReady({ required String sessionId, required String userId, required bool isReady })
Stream<GymSessionPlan?> listenToGymSessionPlan(String sessionId, String userId)
```

`setGymSessionPlanReady` should update the current user's plan and promote the session to `phase=live` only when every joined participant has a ready plan.

- [ ] **Step 4: Re-run the service tests**

Run: `flutter test test/services/session_service_test.dart`
Expected: PASS.

### Task 3: Add setup routing and gym setup page

**Files:**
- Modify: `lib/app/navigation/app_router.dart`
- Modify: `lib/features/session/presentation/start_session_page.dart`
- Create: `lib/features/session/presentation/gym_session_setup_page.dart`
- Test: `test/features/session/presentation/gym_session_setup_flow_contract_test.dart`

- [ ] **Step 1: Write the failing route contract tests**

```dart
test('app router defines a gym setup route', () {
  final source = File('lib/app/navigation/app_router.dart').readAsStringSync();
  expect(source, contains("static const sessionSetup = '/session/setup/:sessionId';"));
  expect(source, contains('GymSessionSetupPage'));
});

test('start session page routes gym starts through setup', () {
  final source = File('lib/features/session/presentation/start_session_page.dart').readAsStringSync();
  expect(source, contains("'/session/setup/"));
});
```

- [ ] **Step 2: Run the failing route tests**

Run: `flutter test test/features/session/presentation/gym_session_setup_flow_contract_test.dart`
Expected: FAIL because the setup route and page do not exist.

- [ ] **Step 3: Implement route branching and the setup page**

Add a new route constant:

```dart
static const sessionSetup = '/session/setup/:sessionId';
```

Update session start navigation:

```dart
final destination = _selectedType == WorkoutType.gym
    ? '/session/setup/$sessionId?type=${_selectedType.value}'
    : '/session/room/$sessionId?type=${_selectedType.value}';
```

Create `GymSessionSetupPage` that:
- loads the session and current user plan
- lets the user add, edit, remove, and reorder planned exercises
- saves the plan with `saveGymSessionPlan`
- shows participant readiness
- calls `setGymSessionPlanReady` when the user taps `Ready`
- redirects to `/session/room/:sessionId` when the session phase becomes `live`

- [ ] **Step 4: Re-run the route tests**

Run: `flutter test test/features/session/presentation/gym_session_setup_flow_contract_test.dart`
Expected: PASS.

### Task 4: Use the saved plan in the live gym room

**Files:**
- Modify: `lib/features/session/presentation/session_room_page.dart`
- Test: `test/features/session/presentation/gym_live_room_contract_test.dart`

- [ ] **Step 1: Write the failing room contract tests**

```dart
test('session room loads a saved gym plan', () {
  final source = File('lib/features/session/presentation/session_room_page.dart').readAsStringSync();
  expect(source, contains('getGymSessionPlan'));
});

test('gym room shows a planned exercise selector', () {
  final source = File('lib/features/session/presentation/session_room_page.dart').readAsStringSync();
  expect(source, contains('DropdownButtonFormField'));
});
```

- [ ] **Step 2: Run the failing room tests**

Run: `flutter test test/features/session/presentation/gym_live_room_contract_test.dart`
Expected: FAIL because gym logging is still free-form.

- [ ] **Step 3: Implement planned exercise execution**

Load the current user's plan for gym sessions:

```dart
GymSessionPlan? _gymPlan;
PlannedExercise? _selectedPlannedExercise;
```

```dart
final plan = await ref.read(sessionServiceProvider).getGymSessionPlan(widget.sessionId, uid);
```

Replace free-form exercise entry for gym workouts with a planned-exercise selector:

```dart
DropdownButtonFormField<PlannedExercise>(
  value: _selectedPlannedExercise,
  items: (_gymPlan?.exercises ?? const [])
      .map((exercise) => DropdownMenuItem(value: exercise, child: Text('${exercise.name} (${exercise.plannedSets} sets)')))
      .toList(),
  onChanged: (exercise) {
    setState(() {
      _selectedPlannedExercise = exercise;
      _currentExercise = exercise?.name;
    });
  },
)
```

Keep `_handleLogSet` as the completed-set logger, but derive `_currentExercise` from the selected planned exercise and keep weight and reps entered only after the set is finished.

- [ ] **Step 4: Re-run the room tests and the focused regression suite**

Run: `flutter test test/features/session/presentation/gym_live_room_contract_test.dart test/features/session/presentation/gym_session_setup_flow_contract_test.dart test/features/session/presentation/session_room_auth_contract_test.dart test/models/models_test.dart test/services/session_service_test.dart`
Expected: PASS.
