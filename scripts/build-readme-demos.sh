#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh > /dev/null
dist/CloudVerse.app/Contents/MacOS/CloudVerse --render-readme-demos
ls -lh docs/assets/theme-gallery-demo.gif docs/assets/control-panel-demo.gif
