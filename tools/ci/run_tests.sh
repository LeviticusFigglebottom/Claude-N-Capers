#!/usr/bin/env bash
# Run headless tests. Owner: LEAD.  usage: tools/ci/run_tests.sh [dir[,dir]] [filter]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/godot/godot)}"
ARGS=()
[[ $# -ge 1 && -n "$1" ]] && ARGS+=("--dir=$1")
[[ $# -ge 2 ]] && ARGS+=("--filter=$2")
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
exec "$GODOT" --headless --path "$ROOT/game" res://tests/framework/runner.tscn -- "${ARGS[@]}"
