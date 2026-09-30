# Changelog

All notable changes to Zyntro Flutter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- Host-only session pause/resume; engagement counters ±1; report/analytics create bounds
- Profile photo Storage ACL mirrors Firestore privacy; invite-code abuse harden
- Auth disk cache no longer stores email/photo URL; email enumeration / verification gates

### Fixed
- Joint post Storage cleanup on full removal; session expiry purges presence/plans
- Arabic push copy across Cloud Function notification templates
- iOS Release uses production `aps-environment`; Debug keeps development
- Leaderboards hide blocked users; offline queue capped with non-retryable drop

### Added
- Privacy consent + data export; PrivacyInfo collected types; data inventory ADR
- Session wakelock; field performance traces; push path / functions unit contracts
- Payments / offline-queue / platform-deadline ADRs; audit findings status sync

### Changed
- Clean-arch migration paused (auth remains the template); god-file extraction ongoing
- CI Flutter pin + coverage floor; Codemagic/GHA ownership docs

### Added (infra)
- Deployment infrastructure setup
- CI/CD pipelines (GitHub Actions & Codemagic)
- Environment-based configuration (dev/staging/prod)
- Release signing configuration for Android
- ProGuard rules for release builds

## [1.0.0] - 2026-01-XX

### Added
- **Core Features**
  - Buddy pairing and invite system
  - Live workout sessions (strength/cardio)
  - Voice notes during sessions with <2s delivery
  - Workout recap with charts and statistics
  - Activity feed with posts and engagement

- **Social Features**
  - Public/private profiles with follow requests
  - Real-time session timeline with presence indicators
  - Friends leaderboard with streak tracking
  - Global leaderboard with Stripe paywall

- **Communication**
  - Push notifications via FCM
  - Real-time session updates
  - Voice note playback with queue support

- **Data & Performance**
  - Offline support with retry queue
  - Firestore with optimized indexes
  - Stream debouncing for real-time data
  - User profile caching

- **Safety & Moderation**
  - Content reporting system
  - User blocking functionality
  - Profanity filtering
  - Community guidelines

### Known Issues
- Performance tests need implementation (see `test/performance/realtime_test.dart`)
- iOS signing requires Apple Developer account setup

## Release Process

1. Update version in `pubspec.yaml`
2. Run `./scripts/release.sh <version> <build_number>`
3. CI/CD automatically builds and deploys
4. Update this CHANGELOG with release notes

## Build Commands

```bash
# Development
flutter build apk --flavor dev --dart-define=ENV=dev

# Staging
flutter build apk --flavor staging --dart-define=ENV=staging --release

# Production
flutter build apk --flavor prod --dart-define=ENV=prod --release
flutter build appbundle --flavor prod --dart-define=ENV=prod --release
```
