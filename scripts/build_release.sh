#!/usr/bin/env bash
# Release build script for Quicklify.
#
# Produces:
#   build/app/outputs/flutter-apk/app-release.apk        (the deliverable)
#   build/symbols/<version>/                              (debug symbols — KEEP THESE)
#
# The symbols directory is REQUIRED to deobfuscate stack traces from release
# crashes. Lose it and any future crash report is uninterpretable.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION=$(awk -F: '/^version:/ {gsub(/ /, "", $2); print $2}' pubspec.yaml)
SYMBOLS_DIR="build/symbols/${VERSION}"

echo "→ Building Quicklify v${VERSION}"
echo "→ Symbols will be written to ${SYMBOLS_DIR}"

mkdir -p "${SYMBOLS_DIR}"

flutter clean
flutter pub get

flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info="${SYMBOLS_DIR}" \
  --target-platform android-arm64,android-arm

# Hash the APK so we can verify website distribution integrity later.
APK="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK" ]; then
  echo "✗ APK not produced at $APK"
  exit 1
fi
APK_SIZE=$(du -h "$APK" | awk '{print $1}')
APK_HASH=$(shasum -a 256 "$APK" | awk '{print $1}')

echo ""
echo "✓ Build complete"
echo "  APK:    $APK ($APK_SIZE)"
echo "  SHA256: $APK_HASH"
echo "  Symbols: $SYMBOLS_DIR"
echo ""
echo "Next steps:"
echo "  - Back up ${SYMBOLS_DIR} somewhere safe (1Password, drive, separate repo)"
echo "  - cp $APK website/downloads/quicklify-latest.apk"
echo "  - Commit + push to gh-pages branch to deploy"
