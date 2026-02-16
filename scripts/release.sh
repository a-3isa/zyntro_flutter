#!/bin/bash
set -e

# Zyntro Flutter Release Script
# Usage: ./scripts/release.sh <version> <build_number>
# Example: ./scripts/release.sh 1.0.0 1

VERSION=$1
BUILD_NUMBER=$2

if [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
  echo "Usage: ./scripts/release.sh <version> <build_number>"
  echo "Example: ./scripts/release.sh 1.0.0 1"
  exit 1
fi

# Validate version format (x.y.z)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in format x.y.z (e.g., 1.0.0)"
  exit 1
fi

# Validate build number is a positive integer
if ! [[ $BUILD_NUMBER =~ ^[0-9]+$ ]]; then
  echo "Error: Build number must be a positive integer"
  exit 1
fi

echo "🚀 Preparing release v$VERSION ($BUILD_NUMBER)..."

# Update pubspec.yaml
echo "📝 Updating pubspec.yaml..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  sed -i '' "s/^version: .*/version: $VERSION+$BUILD_NUMBER/" pubspec.yaml
else
  # Linux/Windows Git Bash
  sed -i "s/^version: .*/version: $VERSION+$BUILD_NUMBER/" pubspec.yaml
fi

# Get dependencies to ensure pubspec.lock is updated
echo "📦 Updating dependencies..."
flutter pub get

# Run tests to ensure release is stable
echo "🧪 Running tests..."
flutter test

# Run analysis to check for issues
echo "🔍 Running analysis..."
flutter analyze

# Create git tag and commit
echo "📌 Creating git tag..."
git add pubspec.yaml pubspec.lock
git commit -m "Release v$VERSION ($BUILD_NUMBER)"
git tag -a "v$VERSION" -m "Release v$VERSION (Build $BUILD_NUMBER)"

# Push changes
echo "⬆️ Pushing changes..."
git push origin main
git push origin "v$VERSION"

echo ""
echo "✅ Release v$VERSION ($BUILD_NUMBER) created successfully!"
echo ""
echo "Next steps:"
echo "  1. CI/CD will build and publish the release"
echo "  2. Monitor the build at your CI provider"
echo "  3. Update CHANGELOG.md with release notes"
echo ""
