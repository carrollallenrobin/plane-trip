#!/usr/bin/env bash
# Checks formatting and lint of all project GDScript (addons excluded).
# Usage: scripts/lint.sh          check only
#        scripts/lint.sh --fix    reformat in place, then lint
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# gdtoolkit caches its parser under $HOME/.cache. In sandboxes where the home directory is not
# writable, point HOME at a gitignored folder inside the repo instead.
if ! mkdir -p "$HOME/.cache/gdtoolkit" 2>/dev/null || [ ! -w "$HOME/.cache/gdtoolkit" ]; then
  export HOME="$ROOT/.tools/home"
  mkdir -p "$HOME"
fi
mapfile -t files < <(find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' -not -path './.tools/*')
if [ ${#files[@]} -eq 0 ]; then
  echo "no GDScript files"
  exit 0
fi
if [ "${1:-}" = "--fix" ]; then
  gdformat "${files[@]}"
else
  gdformat --check "${files[@]}"
fi
# gdlint reads the gdlintrc found from the current directory upward, so test suites are linted
# from inside test/ to pick up test/.gdlintrc (which only relaxes the public-method limit).
mapfile -t src_files < <(printf '%s\n' "${files[@]}" | grep -v '^./test/' || true)
mapfile -t test_files < <(printf '%s\n' "${files[@]}" | grep '^./test/' | sed 's#^./test/##' || true)
status=0
if [ ${#src_files[@]} -gt 0 ]; then
  gdlint "${src_files[@]}" || status=1
fi
if [ ${#test_files[@]} -gt 0 ]; then
  (cd test && gdlint "${test_files[@]}") || status=1
fi
exit $status
