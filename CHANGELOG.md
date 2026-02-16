# Changelog

All notable changes to Zyntro Flutter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
