#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift scripts/video-to-gif.swift "${1:-overmydeadbody.mov}" docs/assets/recording-demo.gif "${2:-6}" "${3:-16}" 1080 10 56
sips -g pixelWidth -g pixelHeight docs/assets/recording-demo.gif
