#!/usr/bin/env bash
# The Web build on this machine, in one go: the pinned Godot and its Web export templates
# are fetched if missing, the project is exported to build/webgl/, and it is served on
# http://localhost:8765 with the headers the threaded build needs. Open that in a browser.
# Usage: scripts/play-web.sh [--debug] [port]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mode=""
port="8765"
for arg in "$@"; do
  case "$arg" in
    --debug) mode="--debug" ;;
    *) port="$arg" ;;
  esac
done
scripts/fetch-export-templates.sh
scripts/export-web.sh $mode
echo "Open http://localhost:$port/index.html (Ctrl-C stops the server)" >&2
exec scripts/serve-web.sh "$port"
