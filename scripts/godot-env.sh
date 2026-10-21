# Sourced by the other scripts. Resolves the Godot binary and gives Godot writable config dirs.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${GODOT_BIN:-}" ]; then
  GODOT_BIN="$("$ROOT/scripts/fetch-godot.sh")"
fi
export GODOT_BIN
# Godot writes editor settings under XDG dirs; keep them inside the repo so sandboxes without a
# writable home directory still work. All of these are gitignored.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$ROOT/.tools/godot-home/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$ROOT/.tools/godot-home/data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$ROOT/.tools/godot-home/cache}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
