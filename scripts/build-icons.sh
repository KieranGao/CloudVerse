#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build/icon-build"
ICONSET="$WORK/CloudVerse.iconset"
mkdir -p "$WORK"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -s format png --resampleHeightWidth 1024 1024 "$ROOT/Resources/CloudVerseIcon.svg" --out "$WORK/CloudVerseIcon.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/CloudVerseIcon.png" --out "$ICONSET/icon_${size}x${size}.png"
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$WORK/CloudVerseIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" --output "$ROOT/Resources/CloudVerse.icns"
sips -z 64 64 "$WORK/CloudVerseIcon.png" --out "$WORK/CloudVerseIcon-64.png"
printf 'ICON PASS: %s\n' "$ROOT/Resources/CloudVerse.icns"
