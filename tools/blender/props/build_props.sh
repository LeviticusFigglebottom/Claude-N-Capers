#!/usr/bin/env bash
# C1-07 props pipeline: Blender glbs -> prop materials + import patches -> Godot wrapper scenes +
# catalog -> Godot import. Usage: tools/blender/props/build_props.sh [--asset <id> ...] [--no-import]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
IMPORT=1
ARGS=()
for a in "$@"; do
  if [[ "$a" == "--no-import" ]]; then IMPORT=0; else ARGS+=("$a"); fi
done
python3 "$ROOT/tools/blender/build.py" --category props "${ARGS[@]}"
python3 "$ROOT/tools/blender/props/_make_materials.py"
python3 "$ROOT/tools/blender/props/_scenes.py"
if [[ $IMPORT -eq 1 ]]; then
  "${GODOT:-/opt/godot/godot}" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
  if grep -rl "valid=false" "$ROOT/game/assets/props" "$ROOT/game/world/props" --include=*.import; then
    echo "build_props: invalid imports above"; exit 1
  fi
fi
echo "build_props: done"
