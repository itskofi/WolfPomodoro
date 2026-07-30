#!/bin/bash
# Builds Wolf.app from the SwiftPM executable and ad-hoc signs it.
# Usage: ./build.sh [--install]   (--install copies to ~/Applications and launches)
set -euo pipefail

cd "$(dirname "$0")"
APP="build/Wolf.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Wolf "$APP/Contents/MacOS/Wolf"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  pkill -f "Wolf.app/Contents/MacOS/Wolf" 2>/dev/null || true
  rm -rf "$HOME/Applications/Wolf.app"
  cp -R "$APP" "$HOME/Applications/Wolf.app"
  open "$HOME/Applications/Wolf.app"
  echo "Installed to ~/Applications and launched — look for the timer in your menu bar."
fi
