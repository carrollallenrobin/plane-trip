#!/usr/bin/env bash
# Runs the gdUnit4 test suites headlessly. Extra arguments are passed to the gdUnit4 command tool,
# e.g. scripts/test.sh -a res://test/flight   (run one directory)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
cd "$ROOT"
# Import first so new class_name scripts and resources are known to the engine.
"$GODOT_BIN" --headless --path . --import --quiet >/dev/null 2>&1
args=("$@")
if [ ${#args[@]} -eq 0 ]; then
  args=(-a res://test)
fi
# --continue runs every suite instead of stopping at the first failure.
# --remote-debug to a never-bound port stops Godot from dropping into its interactive debugger on
# a script parse error, which would otherwise hang the run.
"$GODOT_BIN" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue "${args[@]}"
