#!/usr/bin/env bash
# Regenerate the Godot character scenes from the imported glbs (ENV D, D1-05).
# usage: tools/blender/characters/assemble.sh [--render]
#   1. godot --import            (imports new/changed glbs from tools/blender/build.py)
#   2. assemble_characters.gd    (anim_humanoid.res, world/characters/<id>/<id>.tscn, characters.json)
#   3. godot --import            (refreshes the filesystem / uid cache for the new files)
#   4. --render: render_lineup.gd under xvfb (assets/characters/_review/lineup_*.png, mask_fit_godot.png)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/godot/godot)}"
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/game" --script res://world/characters/_tools/assemble_characters.gd
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
if [[ "${1:-}" == "--render" ]]; then
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --audio-driver Dummy --path "$ROOT/game" \
    --script res://world/characters/_tools/render_lineup.gd
  "$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
fi
