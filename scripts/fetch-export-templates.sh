#!/usr/bin/env bash
# Installs the Web export templates for the pinned Godot build into Godot's data directory,
# so scripts/export-web.sh works locally: on Linux the one scripts/godot-env.sh points at,
# on macOS Godot's own ~/Library/Application Support, which it uses whatever XDG says. The
# official bundle holds every platform and is over a gigabyte, so it is downloaded once into
# .tools/godot/ and only the Web templates are unpacked from it.
# Usage: scripts/fetch-export-templates.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
GODOT_VERSION="4.7.2-stable"
version_dir="${GODOT_VERSION/-stable/.stable}"
if [ "$(uname -s)" = "Darwin" ]; then
  dest="$HOME/Library/Application Support/Godot/export_templates/$version_dir"
else
  dest="$XDG_DATA_HOME/godot/export_templates/$version_dir"
fi
if [ -f "$dest/web_nothreads_release.zip" ] && [ -f "$dest/web_nothreads_debug.zip" ]; then
  echo "Web export templates are in $dest" >&2
  exit 0
fi
bundle="$ROOT/.tools/godot/Godot_v${GODOT_VERSION}_export_templates.tpz"
if [ ! -f "$bundle" ]; then
  url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  echo "Downloading $url (about 1.3 GB)" >&2
  mkdir -p "$(dirname "$bundle")"
  curl -sSL -o "$bundle.part" "$url" && mv "$bundle.part" "$bundle"
fi
mkdir -p "$dest"
# The bundle is a zip with everything under templates/.
unzip -q -o -j "$bundle" "templates/web_nothreads_release.zip" "templates/web_nothreads_debug.zip" \
  "templates/web_release.zip" "templates/web_debug.zip" -d "$dest"
echo "Web export templates are in $dest" >&2
