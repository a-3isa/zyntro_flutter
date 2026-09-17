# zyntro_flutter Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-09

## Active Technologies
- Dart SDK `^3.10.4` with Flutter 3.10+ + `flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `mocktail`, `flutter_test`, `integration_test`, existing session/follow/notification/user-cache services (001-friend-workout-sessions)
- Cloud Firestore collections already used by the app: `sessions`, session `plans` subcollection, session `events` subcollection, `workouts`, user follow/block data, notification data (001-friend-workout-sessions)
- Dart SDK `^3.10.4` with Flutter 3.10+ + `flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `mocktail`, `flutter_test`, `integration_test`, existing session service and gym plan domain models (004-database-exercise-picker)
- Cloud Firestore: new shared exercise catalog collection, user-owned personal exercise collection/subcollection, exercise review submissions, existing `sessions/{sessionId}/plans/{userId}` and session events (004-database-exercise-picker)
- Dart SDK ^3.10.4 (Flutter 3.10+), Node.js 22 (rules unit tests / Functions already on 22) + `cloud_firestore`, Firebase Security Rules, `@firebase/rules-unit-testing`, existing `UserService` (008-firestore-trust-boundaries)
- Cloud Firestore — `users/{userId}`, `usernames/{username}`, `follows/{id}` (008-firestore-trust-boundaries)

- Dart SDK `^3.10.4` with Flutter 3.10+ + `flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `mocktail`, `flutter_test`, `integration_test` (001-clean-architecture-migration)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Dart SDK `^3.10.4` with Flutter 3.10+

## Code Style

Dart SDK `^3.10.4` with Flutter 3.10+: Follow standard conventions

## Recent Changes
- 008-firestore-trust-boundaries: Added Dart SDK ^3.10.4 (Flutter 3.10+), Node.js 22 (rules unit tests / Functions already on 22) + `cloud_firestore`, Firebase Security Rules, `@firebase/rules-unit-testing`, existing `UserService`
- 008-firestore-trust-boundaries: Added Dart SDK ^3.10.4 (Flutter 3.10+), Node.js 22 (rules unit tests / Functions already on 22) + `cloud_firestore`, Firebase Security Rules, `@firebase/rules-unit-testing`, existing `UserService`
- 008-firestore-trust-boundaries: Added Dart SDK ^3.10.4 (Flutter 3.10+), Node.js 22 (rules unit tests / Functions already on 22) + `cloud_firestore`, Firebase Security Rules, `@firebase/rules-unit-testing`, existing `UserService`


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
`specs/008-firestore-trust-boundaries/plan.md`
<!-- SPECKIT END -->
