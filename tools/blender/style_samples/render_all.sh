#!/usr/bin/env bash
# C1-00 art-direction samples: render 2 assets x 3 styles, then build the labelled contact sheet.
#   tools/blender/style_samples/render_all.sh [--scale 0.5] [--samples 32]   (extra args go to every render)
# Output: docs/art/style_samples/<style>/<asset>.png and docs/art/style_samples/comparison.png
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
BLENDER="${BLENDER:-blender}"
OUT="$REPO/docs/art/style_samples"
for style in a_gsr b_noir c_photo; do
  for asset in counter officer; do
    echo "== $style / $asset"
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/$asset.py" -- \
      --style "$style" --asset "$asset" --out "$OUT/$style/$asset.png" "$@" 2>&1 \
      | grep -E '^\[(counter|officer|style_samples|post)\]|Error|Traceback' || true
    test -f "$OUT/$style/$asset.png"
  done
done
python3 "$HERE/contact_sheet.py" --root "$OUT" --out "$OUT/comparison.png"
