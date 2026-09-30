#!/bin/bash
set -e

# Builds a release Android App Bundle with the build number auto-incremented.
# Play Console rejects re-uploading a versionCode it has already seen, so this
# bumps pubspec.yaml's version (X.Y.Z+B -> X.Y.Z+(B+1)) before every build.
#
# Usage: ./scripts/build_aab.sh [extra flutter build args...]
# Example: ./scripts/build_aab.sh --dart-define=ENV=prod

PUBSPEC="pubspec.yaml"
CURRENT=$(grep -E '^version:' "$PUBSPEC" | sed -E 's/^version:[[:space:]]*//')
SEMVER="${CURRENT%%+*}"
BUILD_NUMBER="${CURRENT##*+}"

if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: could not parse build number from version: $CURRENT"
  exit 1
fi

NEXT_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="$SEMVER+$NEXT_BUILD_NUMBER"

echo "Bumping version: $CURRENT -> $NEW_VERSION"
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
else
  sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
fi

echo "Building release AAB ($NEW_VERSION)..."
flutter build appbundle --release "$@"

echo ""
echo "Done. AAB at build/app/outputs/bundle/release/app-release.aab"
echo "pubspec.yaml now at $NEW_VERSION (uncommitted — commit it yourself if you want to keep this build number)."
