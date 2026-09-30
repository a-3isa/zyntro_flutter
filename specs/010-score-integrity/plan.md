# Implementation Plan: Score integrity phase 1

**Branch**: `010-score-integrity` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

## Summary

Close leaderboard cheating surface: clients stop writing scores/streaks/PRs; rules enforce; leaderboard hidden; CF stub for later server grant.

## Tasks

1. Extend `privilegedUserFields` (+ stats write deny).
2. Strip client writes in `session_service` / `User.toFirestore` / dead `updateUserStreak` writes.
3. Workout create `userId == auth.uid`.
4. Leaderboard kill switch + UI copy.
5. Stub `exports.applySessionScore`.
6. Flip social.rules + session_service tests; deploy rules; commit.
