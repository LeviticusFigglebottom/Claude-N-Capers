#!/usr/bin/env bash
# ENV D equipment pipeline (D-157 / D-161): Blender glbs -> the prop-material import patch -> Godot import.
# The equipment models use the props material library (M_pr_<key>); like build_props.sh, every .glb.import must point
# those materials at res://world/props/materials/pr_<key>.tres or Godot imports raw glTF fallbacks (no emission,
# no detail). Reuses C's _make_materials.patch_import (read-only).
#   tools/blender/equipment/build_equipment.sh [--asset <id> ...] [--no-import]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
IMPORT=1
ARGS=()
for a in "$@"; do
  if [[ "$a" == "--no-import" ]]; then IMPORT=0; else ARGS+=("$a"); fi
done
python3 "$ROOT/tools/blender/build.py" --category equipment "${ARGS[@]}"
python3 - "$ROOT" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "blender" / "props"))
sys.path.insert(0, str(root / "tools" / "blender"))
import _make_materials as mm
glbs = sorted((root / "game" / "assets" / "equipment").glob("eqp_*/eqp_*.glb"))
print(f"build_equipment: {sum(mm.patch_import(g) for g in glbs)} .glb.import file(s) patched")
PY
if [[ $IMPORT -eq 1 ]]; then
  "${GODOT:-/opt/godot/godot}" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
fi
echo "build_equipment: done"
