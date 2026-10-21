#!/usr/bin/env bash
# Builds every model script in art/models/ with headless Blender into assets/models/<name>.glb,
# then runs the Godot import so the engine picks the new meshes up. The .glb files are
# committed; the scripts are their source. Run this after changing a script in art/models/.
# Usage: scripts/build-models.sh            all models
#        scripts/build-models.sh plane      one model (art/models/plane.py)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BLENDER_BIN="$("$ROOT/scripts/fetch-blender.sh")"
mkdir -p assets/models .tools/blender/home
# Blender writes its user config under this; keeps sandboxes with a read-only home working.
export BLENDER_USER_RESOURCES="$ROOT/.tools/blender/home"
if [ $# -gt 0 ]; then
  scripts=()
  for name in "$@"; do scripts+=("art/models/$name.py"); done
else
  mapfile -t scripts < <(find art/models -name '*.py' | sort)
fi
for script in "${scripts[@]}"; do
  name="$(basename "$script" .py)"
  rm -f "assets/models/$name.glb"  # so a failed build cannot leave a stale model behind
  # Blender prints font and mount warnings in a headless sandbox; only the script's own
  # output and any Python error matter.
  "$BLENDER_BIN" -b --python "$script" -- "assets/models/$name.glb" 2>&1 \
    | grep -v -E '^(blf_load_font_default|Font data directory|Blender [0-9]|$)|system\.path|Blender quit|Draco' || true
  [ -s "assets/models/$name.glb" ] || { echo "$script wrote no $name.glb" >&2; exit 1; }
done
"$ROOT/scripts/import.sh"
