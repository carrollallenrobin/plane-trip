#!/usr/bin/env bash
# Exports the Web build to build/webgl/ with the headless editor: a resource import first,
# since a fresh checkout has no .godot/ directory, then the "Web" preset from
# export_presets.cfg. Needs the Web export templates (scripts/fetch-export-templates.sh
# locally; CI installs them with Godot).
# Usage: scripts/export-web.sh            release build to build/webgl/index.html
#        scripts/export-web.sh --debug    debug build, with the engine's console output
# Godot looks for the templates under $XDG_DATA_HOME/godot/export_templates; godot-env.sh
# points that into .tools/, so templates installed elsewhere need XDG_DATA_HOME set first.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
cd "$ROOT"
out="build/webgl"
mode="--export-release"
if [ "${1:-}" = "--debug" ]; then
  mode="--export-debug"
fi
rm -rf "$out"
mkdir -p "$out"
"$GODOT_BIN" --headless --path . --import --quiet >/dev/null 2>&1
"$GODOT_BIN" --headless --path . "$mode" "Web" "$out/index.html" 2>&1 \
  | grep -v -E 'PagedAllocator|resources still in use|ObjectDB instances' || true
[ -s "$out/index.html" ] && [ -s "$out/index.wasm" ] || { echo "export wrote no build" >&2; exit 1; }
du -sh "$out"
