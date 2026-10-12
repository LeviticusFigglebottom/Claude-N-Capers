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

step "conflict markers"
CM="$(cd "$ROOT" && git grep -nE '^(<<<<<<< |>>>>>>> )' -- . ':!*.png' ':!*.jpg' || true)"
if [[ -n "$CM" ]]; then echo "merge-conflict markers:"; echo "$CM" | head -10; FAIL=1; else echo ok; fi

step "banned + ownership"
python3 "$ROOT/tools/ci/check_banned.py" | tail -1 || FAIL=1
python3 "$ROOT/tools/ci/check_ownership.py" c | tail -1 || FAIL=1

step "gdlint (ENV C code)"
(cd "$ROOT" && gdlint game/world game/tests/c 2>&1 | tail -1) | grep -q "no problems" || { echo "gdlint failed"; FAIL=1; }

step "tests c + integration"
for d in c integration; do
  # Per-run log (a shared fixed path let concurrent gate runs read each other's results).
  LOG="$(mktemp "/tmp/push_gate_tests_${d}_XXXXXX.txt")"
  "$ROOT/tools/ci/run_tests.sh" "$d" > "$LOG" 2>&1
  OUT="$(grep -E '^== ' "$LOG")"
  echo "$d: $OUT (log: $LOG)"
  # Name the failures (an unnamed one cannot be told apart from a flake later).
  grep -A2 -E '^FAIL ' "$LOG" | head -20
  echo "$OUT" | grep -q ' 0 failed' || FAIL=1
done

step "validate_all"
VLOG="$(mktemp /tmp/push_gate_validate_XXXXXX.txt)"
"$ROOT/tools/levelcheck/validate_all.sh" > "$VLOG" 2>&1 || FAIL=1
grep -E 'PASS in|FAIL|exit' "$VLOG" | tail -8

echo
if [[ $FAIL -eq 0 ]]; then echo "PUSH_GATE: PASS"; else echo "PUSH_GATE: FAIL"; fi
exit $FAIL
