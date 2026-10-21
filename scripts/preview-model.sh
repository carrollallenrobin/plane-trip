#!/usr/bin/env bash
# Renders a built model with headless Blender for a look at it. Writes
# .tools/preview/<name>.png (three-quarter view) and <name>-side.png. With an object name,
# only that object of the model is rendered, to <name>-<object>.png: a Backdrop piece's
# variants all sit on the origin, so each is looked at alone.
# Usage: scripts/preview-model.sh plane
#        scripts/preview-model.sh tree TreeA
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
name="${1:?usage: scripts/preview-model.sh <model name> [object]}"
object="${2:-}"
model="assets/models/$name.glb"
out="$name${object:+-$object}"
[ -f "$model" ] || { echo "no $model; run scripts/build-models.sh $name first" >&2; exit 1; }
BLENDER_BIN="$("$ROOT/scripts/fetch-blender.sh")"
mkdir -p .tools/preview .tools/blender/home
export BLENDER_USER_RESOURCES="$ROOT/.tools/blender/home"
"$BLENDER_BIN" -b --python art/preview.py -- "$model" "$ROOT/.tools/preview/$out.png" $object 2>&1 \
  | grep -E 'wrote|Error|Traceback|^  File|no object' || true
ls .tools/preview/"$out"*.png
