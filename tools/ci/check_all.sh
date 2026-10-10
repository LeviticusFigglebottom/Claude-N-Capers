#!/usr/bin/env bash
# Full validation gate. Owner: LEAD.
# usage: tools/ci/check_all.sh [--env a|b|c] [--no-levels]
# Run by every env before reporting "ready for integration" and by the lead before merging.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/godot/godot)}"
ENV=""; LEVELS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2;;
    --no-levels) LEVELS=0; shift;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
FAIL=0
step() { echo; echo "=== $1 ==="; }

step "import (script parse errors)"
OUT="$("$GODOT" --headless --path "$ROOT/game" --import 2>&1)"
if echo "$OUT" | grep -E "SCRIPT ERROR|Parse Error|ERROR: Failed to load" ; then FAIL=1; else echo ok; fi

step "gdlint"
if command -v gdlint >/dev/null; then
  (cd "$ROOT" && gdlint game/core game/contracts game/systems game/content game/world game/tests 2>&1 | tail -30) || FAIL=1
else echo "gdlint not installed (pip install -r tools/requirements.txt) - skipped"; fi

step "banned patterns"
python3 "$ROOT/tools/ci/check_banned.py" || FAIL=1

if [[ -n "$ENV" ]]; then
  step "ownership (env $ENV)"
  python3 "$ROOT/tools/ci/check_ownership.py" "$ENV" || FAIL=1
fi

step "tests"
"$ROOT/tools/ci/run_tests.sh" || FAIL=1

if [[ $LEVELS -eq 1 ]]; then
  step "validate_level"
  if [[ -x "$ROOT/tools/levelcheck/validate_all.sh" ]]; then
    "$ROOT/tools/levelcheck/validate_all.sh" || FAIL=1
  else echo "no levelcheck yet (ENV C delivers tools/levelcheck/validate_all.sh in P1)"; fi
fi

echo
if [[ $FAIL -eq 0 ]]; then echo "CHECK_ALL: PASS"; else echo "CHECK_ALL: FAIL"; fi
exit $FAIL
