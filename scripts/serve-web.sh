#!/usr/bin/env bash
# Serves build/webgl/ on http://localhost:8765 with the cross-origin isolation headers the
# threaded Web build needs (itch.io adds them when "SharedArrayBuffer support" is on). A
# plain static server shows an error page instead of the game.
# Usage: scripts/serve-web.sh [port]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
port="${1:-8765}"
[ -f "$ROOT/build/webgl/index.html" ] || { echo "no build/webgl; run scripts/export-web.sh first" >&2; exit 1; }
cd "$ROOT/build/webgl"
exec python3 - "$port" <<'PY'
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

class Isolated(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *_args):
        pass

port = int(sys.argv[1])
print(f"serving build/webgl on http://localhost:{port}", flush=True)
ThreadingHTTPServer(("", port), Isolated).serve_forever()
PY
