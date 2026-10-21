#!/usr/bin/env bash
# Renders the store-page cover from the built models with headless Blender, at every size a
# store wants, into promo/. The PNGs are committed as build products of art/cover.py; change
# the script and rebuild. Takes a minute or two on the CPU.
# Usage: scripts/build-cover.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SIZES=(640x512 630x500)
BLENDER_BIN="$("$ROOT/scripts/fetch-blender.sh")"
mkdir -p promo .tools/blender/home
export BLENDER_USER_RESOURCES="$ROOT/.tools/blender/home"
args=()
for size in "${SIZES[@]}"; do args+=("promo/cover-$size.png" "$size"); done
"$BLENDER_BIN" -b --python art/cover.py -- "${args[@]}" 2>&1 \
  | grep -E 'wrote|Error|Traceback|^  File' || true
for size in "${SIZES[@]}"; do
  [ -s "promo/cover-$size.png" ] || { echo "art/cover.py wrote no promo/cover-$size.png" >&2; exit 1; }
done
ls -l promo/cover-*.png
