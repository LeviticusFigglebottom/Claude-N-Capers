#!/usr/bin/env bash
# ENV C pre-push gate (lead process rule: validate_all before every push, not only tests).
# usage: tools/levelcheck/push_gate.sh   -> exit 0 only if every check passes.
# Fast subset of tools/ci/check_all.sh --env c, plus the import-validity check that concurrent
# imports have broken before. Run from anywhere.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/godot/godot)}"
FAIL=0
step() { echo "== $1"; }

step "import"
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1
BAD="$(grep -rl 'valid=false' "$ROOT/game" --include='*.import' || true)"
if [[ -n "$BAD" ]]; then echo "invalid imports:"; echo "$BAD"; FAIL=1; else echo ok; fi

step "banned + ownership"
python3 "$ROOT/tools/ci/check_banned.py" | tail -1 || FAIL=1
python3 "$ROOT/tools/ci/check_ownership.py" c | tail -1 || FAIL=1

step "gdlint (ENV C code)"
(cd "$ROOT" && gdlint game/world game/tests/c 2>&1 | tail -1) | grep -q "no problems" || { echo "gdlint failed"; FAIL=1; }

step "tests c + integration"
for d in c integration; do
  OUT="$("$ROOT/tools/ci/run_tests.sh" "$d" 2>&1 | grep -E '^== ')"
  echo "$d: $OUT"
  echo "$OUT" | grep -q ' 0 failed' || FAIL=1
done

step "validate_all"
"$ROOT/tools/levelcheck/validate_all.sh" > /tmp/push_gate_validate.txt 2>&1 || FAIL=1
grep -E 'PASS in|FAIL|exit' /tmp/push_gate_validate.txt | tail -6

echo
if [[ $FAIL -eq 0 ]]; then echo "PUSH_GATE: PASS"; else echo "PUSH_GATE: FAIL"; fi
exit $FAIL
