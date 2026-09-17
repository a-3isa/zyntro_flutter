# Implementation Plan: Session mode derivation

**Branch**: `009-mode-derivation` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

## Summary

Unify mode derivation (gym+gym → turn-based; else parallel) and stop persisting `sessions.mode`.

## Tasks

1. Add `Session.modeFromParticipantTypes`; wire `derivedMode` + `SessionService.derivePairedSessionMode`.
2. Remove `mode` from `sharedClockStartFields`, bot create, go-live update.
3. Drop `mode` from invite accept + `participantLiveKeys` in `firestore.rules`.
4. Tests: models, session_service, firestore_rules_contract.
5. Deploy rules after CI green (owner: check-then-deploy).

## Out of scope

Legacy documents may still contain `mode`; clients ignore it and use `derivedMode`.
