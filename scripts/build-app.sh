#!/usr/bin/env bash
#
# Assembles a distributable Daily Routine.app bundle from the SwiftPM release
# build. Optionally code-signs and (if configured) notarizes it.
#
# Usage:
#   scripts/build-app.sh                      # build unsigned .app
#   SIGN_ID="Developer ID Application: ..." scripts/build-app.sh   # build + sign
#
# After signing you can notarize with:
#   xcrun notarytool submit "Daily Routine.app.zip" --keychain-profile <profile> --wait
#   xcrun stapler staple "build/Daily Routine.app"
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Daily Routine"
EXEC_NAME="DailyRoutineApp"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"

echo "[1/4] Building release binary..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${EXEC_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "ERROR: built binary not found at ${BIN_PATH}" >&2
  exit 1
fi

echo "[2/4] Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources/Fonts"

cp "${BIN_PATH}" "${CONTENTS}/MacOS/${EXEC_NAME}"
cp "packaging/Info.plist" "${CONTENTS}/Info.plist"

echo "[3/4] Bundling resources"
# Bundle fonts if present so the app ships its own typefaces (auto-registered
# via ATSApplicationFontsPath). Drop InstrumentSerif-Regular.ttf and
# JetBrainsMono-Regular.ttf (etc.) into packaging/Fonts/ to include them.
if [[ -d "packaging/Fonts" ]] && compgen -G "packaging/Fonts/*" > /dev/null; then
  cp packaging/Fonts/* "${CONTENTS}/Resources/Fonts/"
  echo "  - bundled fonts: $(ls packaging/Fonts | tr '\n' ' ')"
else
  echo "  - no fonts in packaging/Fonts/ -> app uses system serif/mono fallback"
fi

# App icon, if provided as a compiled .icns.
if [[ -f "packaging/AppIcon.icns" ]]; then
  cp "packaging/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"
else
  echo "  - no packaging/AppIcon.icns -> app uses the default icon"
fi

echo "[4/4] Code signing"
# Code signing (optional). Required for distribution outside your own machine.
if [[ -n "${SIGN_ID:-}" ]]; then
  echo "  - signing with: ${SIGN_ID}"
  codesign --force --deep --options runtime --sign "${SIGN_ID}" "${APP_DIR}"
  codesign --verify --strict --verbose=2 "${APP_DIR}"
else
  echo "  - skipped (set SIGN_ID to enable)"
fi

echo "Done: ${APP_DIR}"
