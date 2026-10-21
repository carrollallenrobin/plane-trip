# Sourced by the sound scripts. Runs a Python with numpy (and matplotlib for previews) through
# uv, with its cache inside the repo so sandboxes without a writable home directory work.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$ROOT/.tools/uv-cache}"
export MPLCONFIGDIR="${MPLCONFIGDIR:-$ROOT/.tools/home/matplotlib}"
mkdir -p "$UV_CACHE_DIR" "$MPLCONFIGDIR"
command -v uv >/dev/null || { echo "uv is needed (https://docs.astral.sh/uv/)" >&2; exit 1; }
NUMPY="numpy==2.3.3"
MATPLOTLIB="matplotlib==3.10.6"
# --native-tls: some sandboxes only trust the system's certificate store.
sound_python() {
  uv run --quiet --native-tls --no-project --with "$NUMPY" "$@"
}
preview_python() {
  uv run --quiet --native-tls --no-project --with "$NUMPY" --with "$MATPLOTLIB" "$@"
}
