# Data dictionary (starter) — Z-ENH-040

High-level Firestore collections the Flutter client uses. Prefer `firebase/firestore.rules` and domain models for authoritative shapes.

| Path | Owner | Notes |
| --- | --- | --- |
| `users/{userId}` | user | Profile; privileged score/streak fields server-owned |
| `usernames/{username}` | user | Unique handle map |
| `follows/{id}` | pair | Follow edges |
| `sessions/{sessionId}` | host/participants | Live session; `mode` not client-writable |
| `sessions/{id}/plans/{userId}` | participant | Gym plan readiness |
| `sessions/{id}/events/{eventId}` | participant | Timeline (sets, voice, finish) |
| `workouts/{id}` | author | Completed workout log |
| `posts` / feed trees | author | Social posts; joint drafts |
| Shared exercise catalog | platform | Exercise picker catalog |

Update this table when adding collections or changing trust boundaries (see `specs/008-firestore-trust-boundaries`).
