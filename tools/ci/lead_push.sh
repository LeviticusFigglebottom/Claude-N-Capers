#!/usr/bin/env bash
# Lead-only: push trunk ONLY if the given test dirs (or the full gate) pass. Owner: LEAD (D-045).
# usage: tools/ci/lead_push.sh [dirs]    e.g. tools/ci/lead_push.sh b,d   (no arg = full check_all)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
if [[ $# -ge 1 ]]; then
  "$ROOT/tools/ci/run_tests.sh" "$1"; RC=$?
else
  "$ROOT/tools/ci/check_all.sh"; RC=$?
fi
if [[ $RC -ne 0 ]]; then echo "lead_push: checks FAILED (rc=$RC); NOT pushing."; exit $RC; fi
git push -u origin claude/dreamy-hamilton-pc7vck && echo "lead_push: pushed."
