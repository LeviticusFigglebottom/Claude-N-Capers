#!/usr/bin/env bash
# Run headless tests. Owner: LEAD.  usage: tools/ci/run_tests.sh [dir[,dir]] [filter]
# Fails on any GDScript runtime error ("SCRIPT ERROR"): it aborts the test function, which the runner
# would otherwise count as a pass (D-047).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/godot/godot)}"
ARGS=()
[[ $# -ge 1 && -n "$1" ]] && ARGS+=("--dir=$1")
[[ $# -ge 2 ]] && ARGS+=("--filter=$2")
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
set +e
"$GODOT" --headless --path "$ROOT/game" res://tests/framework/runner.tscn -- "${ARGS[@]}" 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
set -e
if grep -q "^SCRIPT ERROR:" "$LOG"; then
	echo "== run_tests: GDScript runtime errors during tests (each aborted a test silently) =="
	grep -A1 "^SCRIPT ERROR:" "$LOG" | grep -v "^--$"
	[[ $RC -eq 0 ]] && RC=1
fi
exit $RC
