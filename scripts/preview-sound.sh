#!/usr/bin/env bash
# Draws a built sound's waveform and spectrogram to .tools/preview/<name>.png for a look at
# it without speakers.
# Usage: scripts/preview-sound.sh engine
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/sound-env.sh"
cd "$ROOT"
name="${1:?usage: scripts/preview-sound.sh <sound name>}"
sound="assets/audio/$name.wav"
[ -f "$sound" ] || { echo "no $sound; run scripts/build-sounds.sh first" >&2; exit 1; }
mkdir -p .tools/preview
preview_python python art/preview_sound.py "$sound" ".tools/preview/$name.png"
