#!/usr/bin/env bash
#
# Builds Daily Routine.app (via build-app.sh) and packages it into a
# distributable .dmg with a drag-to-Applications shortcut. Uses hdiutil,
# which ships with macOS — no extra tools required.
#
# Usage:
#   scripts/build-dmg.sh                      # build unsigned app + dmg
#   SIGN_ID="Developer ID Application: ..." scripts/build-dmg.sh   # sign the app first
#
# To sign the dmg itself (and notarize), after this script:
#   codesign --sign "$SIGN_ID" "build/Daily Routine.dmg"
#   xcrun notarytool submit "build/Daily Routine.dmg" --keychain-profile <profile> --wait
#   xcrun stapler staple "build/Daily Routine.dmg"
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Daily Routine"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

echo "[1/2] Building app bundle"
"${ROOT}/scripts/build-app.sh"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "ERROR: ${APP_DIR} not found after build-app.sh" >&2
  exit 1
fi

echo "[2/2] Packaging ${DMG_PATH}"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

cp -R "${APP_DIR}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE}" \
  -ov -format UDZO \
  "${DMG_PATH}"

echo "Done: ${DMG_PATH}"
