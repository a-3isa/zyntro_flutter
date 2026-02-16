# Zyntro Flutter

A Flutter workout buddy app migrated from React Native.

## Getting Started

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Create a `.env` file with your Firebase and Stripe configuration
4. Run `flutter run` to start the app

## Environment Configuration

Create a `.env` file in the project root with the following:

```env
# Firebase Configuration
FIREBASE_API_KEY=your_api_key
FIREBASE_AUTH_DOMAIN=your_domain.firebaseapp.com
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_bucket.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id

# Environment
ENV=development

# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here
```

## Features

### Workout Sessions
- Start solo or buddy workout sessions
- Strength and cardio session types
- Real-time timeline with voice notes
- Session summary and progress tracking

### Social Features
- Follow/follower system with privacy controls
- Buddy pairing for accountability
- Activity feed with workout posts

### Leaderboards

The app includes a competitive leaderboard system:

#### Friends Leaderboard (Free)
- Ranks users among their mutual follows (buddies)
- Shows workout scores and ranks
- Updates in real-time

#### Global Leaderboard (Premium - $5 one-time)
- Top 50 users worldwide by workout score
- Requires one-time purchase for lifetime access
- Stripe payment integration with fallback simulation

#### Points System
- **+10** points per completed workout
- **+25-100** points per challenge submission (based on difficulty)
- **+5** points per accurate judgment
- **+20** points for first-time partner support
- **+50** consistency bonus (5+ workouts/week)

### Notifications
- Push notifications via Firebase Cloud Messaging
- In-app notification center
- Session invites and activity alerts

## Stripe Setup

For payment integration:

1. Get your Stripe publishable key from the [Stripe Dashboard](https://dashboard.stripe.com/test/apikeys)
2. Add it to your `.env` file as `STRIPE_PUBLISHABLE_KEY`
3. For production, implement a Cloud Function to create PaymentIntents server-side

The app includes a simulated purchase fallback for testing when Stripe is not fully configured.

## Firebase Indexes

Deploy the Firestore indexes for optimal query performance:

```bash
firebase deploy --only firestore:indexes
```

See `firebase/firestore.indexes.json` for the index definitions.

## Tech Stack

- Flutter 3.10+
- Firebase (Auth, Firestore, Storage, Messaging)
- Riverpod for state management
- GoRouter for navigation
- Stripe for payments
- FL Chart for workout visualizations

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Stripe Flutter SDK](https://pub.dev/packages/flutter_stripe)

## Deployment

### Environment Setup

The app supports multiple environments:

| Environment | Config File | Firebase Project |
|-------------|-------------|-----------------|
| Development | `.env` / `.env.dev` | `gym-avatar-dev` |
| Staging | `.env.staging` | `gym-avatar-staging` |
| Production | `.env.prod` | `gym-avatar` |

### Build Commands

```bash
# Development build
flutter build apk --flavor dev --dart-define=ENV=dev

# Staging build
flutter build apk --flavor staging --dart-define=ENV=staging --release

# Production build
flutter build apk --flavor prod --dart-define=ENV=prod --release
flutter build appbundle --flavor prod --dart-define=ENV=prod --release

# iOS builds
flutter build ios --flavor prod --dart-define=ENV=prod --release
```

### Android Release Signing

1. Generate a keystore: `keytool -genkey -v -keystore zyntro-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias zyntro-key-alias`
2. Copy `android/key.properties.template` to `android/key.properties`
3. Fill in your keystore details

### Firebase Setup

1. Download `google-services.json` from Firebase Console → Add to `android/app/`
2. Download `GoogleService-Info.plist` → Add to `ios/Runner/`
3. Deploy Firestore rules: `firebase deploy --only firestore:rules`

### CI/CD

The project includes:
- **GitHub Actions** (`.github/workflows/flutter-ci.yml`) - Analyze, test, build
- **Codemagic** (`codemagic.yaml`) - Full CI/CD with App Store deployment

### App Icons & Splash

```bash
# Add icon.png and splash_icon.png to assets/, then:
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

### Release Process

```bash
./scripts/release.sh <version> <build_number>
# Example: ./scripts/release.sh 1.0.0 1
```

## Documentation

- [Privacy Policy](docs/privacy-policy.md)
- [Terms of Service](docs/terms-of-service.md)
- [Community Guidelines](docs/community-guidelines.md)

