#!/usr/bin/env bash
# Downloads the UI fonts into assets/fonts/ from the google/fonts repository at a pinned commit
# and checks each file against its sha256 (ADR 0008). The files are committed; run this only to
# refresh them. Allerta Stencil and Oswald are under the SIL Open Font License, Special Elite
# under the Apache License 2.0; each licence is fetched beside its font.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/assets/fonts"
COMMIT="47d54ca1ebb14fd864695f1d39dc734f39017c33"
BASE="https://raw.githubusercontent.com/google/fonts/$COMMIT"

# path in the repository | file name here | sha256
FILES=(
  "ofl/allertastencil/AllertaStencil-Regular.ttf|AllertaStencil-Regular.ttf|8c504d1be20768941ab04251a389ad82d5782d647fa1c4029c811dc5bc2abd59"
  "ofl/allertastencil/OFL.txt|AllertaStencil-OFL.txt|08fba9df5c9890f3ab00ee63f63e005ad93a23746f7484f5fe9501a1ad32730e"
  "apache/specialelite/SpecialElite-Regular.ttf|SpecialElite-Regular.ttf|a776fcb4ceb8bdf03e2967688ebdad42680de5b91a7e62c17e718ae212d14bc4"
  "apache/specialelite/LICENSE.txt|SpecialElite-LICENSE.txt|cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
  "ofl/oswald/Oswald%5Bwght%5D.ttf|Oswald-Variable.ttf|5b38c246e255a12f5712d640d56bcced0472466fc68983d2d0410ec0457c2817"
  "ofl/oswald/OFL.txt|Oswald-OFL.txt|0fd731a904b729a4e02eaf5e8ebd06783edd9abe400e8882760160230675b652"
)

mkdir -p "$DEST"
for entry in "${FILES[@]}"; do
  IFS='|' read -r path name sha <<< "$entry"
  target="$DEST/$name"
  echo "Fetching $name" >&2
  curl -sSfL -o "$target" "$BASE/$path"
  actual="$(sha256sum "$target" | cut -d' ' -f1)"
  if [ "$actual" != "$sha" ]; then
    echo "checksum mismatch for $name: $actual" >&2
    rm -f "$target"
    exit 1
  fi
done
echo "Fonts are in $DEST" >&2
