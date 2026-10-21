#!/usr/bin/env bash
# Headless import of all project resources. Run after adding assets or when .godot/ is missing.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
cd "$ROOT"
"$GODOT_BIN" --headless --path . --import --quiet
