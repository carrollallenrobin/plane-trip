#!/usr/bin/env bash
# Builds the sounds from the scripts in art/sounds/ into assets/audio/*.wav, then runs the
# Godot import so the engine picks them up (ADR 0009). The .wav files are committed; the
# scripts are their source. Run this after changing a script in art/sounds/.
# Usage: scripts/build-sounds.sh            all families
#        scripts/build-sounds.sh guns       one family (art/sounds/guns.py)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/sound-env.sh"
cd "$ROOT"
if [ $# -gt 0 ]; then
  scripts=()
  for name in "$@"; do scripts+=("art/sounds/$name.py"); done
else
  mapfile -t scripts < <(find art/sounds -name '*.py' | sort)
fi
for script in "${scripts[@]}"; do
  sound_python python "$script" -- assets/audio
done
"$ROOT/scripts/import.sh"
# Godot imports a new WAV compressed (QOA) by default; the bank is small, and loops and gun
# transients want PCM. A sound imported for the first time is fixed and imported again.
changed=0
for import_file in assets/audio/*.wav.import; do
  if grep -q '^compress/mode=2$' "$import_file"; then
    sed -i.bak 's#^compress/mode=2$#compress/mode=0#' "$import_file" && rm -f "$import_file.bak"
    changed=1
  fi
done
[ "$changed" -eq 0 ] || "$ROOT/scripts/import.sh"
