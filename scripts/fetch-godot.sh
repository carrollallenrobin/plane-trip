#!/usr/bin/env bash
# Downloads the pinned Godot build for this platform into .tools/godot/ and prints the binary path.
# Usage: scripts/fetch-godot.sh            (prints path, downloads if missing)
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.tools/godot"

os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Linux)
    case "$arch" in
      aarch64|arm64) asset="linux.arm64" ;;
      x86_64)        asset="linux.x86_64" ;;
      *) echo "unsupported arch: $arch" >&2; exit 1 ;;
    esac
    binary="$DEST/Godot_v${GODOT_VERSION}_${asset}"
    ;;
  Darwin)
    asset="macos.universal"
    binary="$DEST/Godot.app/Contents/MacOS/Godot"
    ;;
  *) echo "unsupported OS: $os" >&2; exit 1 ;;
esac

if [ ! -x "$binary" ]; then
  mkdir -p "$DEST"
  url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_${asset}.zip"
  echo "Downloading $url" >&2
  curl -sSL -o "$DEST/godot.zip" "$url"
  unzip -q -o "$DEST/godot.zip" -d "$DEST"
  rm "$DEST/godot.zip"
  chmod +x "$binary"
fi

echo "$binary"
