#!/usr/bin/env bash
#
# Runs the test suite. The app itself builds with Command Line Tools only, but
# XCTest ships inside Xcode.app, so tests need Xcode's SDK. This script points
# `DEVELOPER_DIR` at Xcode for this invocation only -- it does NOT change your
# global `xcode-select` setting.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# If xcode-select already points at a full Xcode, just use it.
DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "${DEV_DIR}" != *"Xcode"* ]]; then
  XCODE="$(ls -d /Applications/Xcode*.app 2>/dev/null | head -1 || true)"
  if [[ -z "${XCODE}" ]]; then
    echo "ERROR: tests need Xcode.app (for XCTest), which wasn't found in /Applications." >&2
    echo "Install Xcode, or run: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
  fi
  export DEVELOPER_DIR="${XCODE}/Contents/Developer"
  echo "Using Xcode SDK at: ${DEVELOPER_DIR}"
fi

swift test "$@"
