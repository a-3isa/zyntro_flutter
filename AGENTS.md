# zyntro_flutter Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-09-17

## Active Technologies
- Dart SDK `^3.10.4` with Flutter 3.38.9 (CI pin) + `flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `mocktail`, `flutter_test`, `integration_test`
- Cloud Firestore: `sessions` (+ `plans`/`events`), `workouts`, `users`/`usernames`/`follows`, exercise catalog, notifications
- Node.js 22 for Firestore rules unit tests and Cloud Functions

## Project Structure

```text
lib/
test/
firebase/
functions/
specs/
```

## Commands

```bash
flutter analyze
flutter test
cd test/rules && npm test   # Firestore rules emulator suite
```

## Code Style

Dart SDK `^3.10.4` with Flutter 3.10+: Follow standard conventions

## Recent Changes
- 011-audit-quick-wins: moderation route guard, FCM icon, notif prefs fail-closed, CI rules gate
- 010-score-integrity: deny client score/streak writes (Z-DATA-001 phase 1)
- 009-mode-derivation: gym+gym turn-based; stop persisting sessions.mode
- 008-firestore-trust-boundaries: users list privacy (Z-SEC-001)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
`specs/011-audit-quick-wins/spec.md`
<!-- SPECKIT END -->
