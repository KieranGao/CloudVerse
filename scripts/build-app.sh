#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release --product FancyLyrics
swift build -c release --product PlaybackBridge
BIN="$(swift build -c release --show-bin-path)"
APP="$ROOT/dist/FancyLyrics.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/FancyLyrics" "$APP/Contents/MacOS/FancyLyrics"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN/libPlaybackBridge.dylib" "$APP/Contents/Resources/PlaybackBridge.dylib"
codesign --force --sign - "$APP/Contents/Resources/PlaybackBridge.dylib"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf '\nBuilt: %s\nOpen with: open "%s"\n' "$APP" "$APP"
