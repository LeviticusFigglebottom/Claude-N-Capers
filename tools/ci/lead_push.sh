#!/usr/bin/env bash
# Lead-only: push trunk ONLY if the given test dirs (or the full gate) pass. Owner: LEAD (D-045).
# usage: tools/ci/lead_push.sh [dirs]    e.g. tools/ci/lead_push.sh b,d   (no arg = full check_all)
# Pushes exactly the commit that was checked, so commits made while the checks run are never pushed
# untested; refuses to run with uncommitted changes or merge-conflict markers in tracked files.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BRANCH="claude/dreamy-hamilton-pc7vck"
cd "$ROOT"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "lead_push: uncommitted changes; commit first. NOT pushing."; exit 1
fi
if git grep -nE '^(<<<<<<< |>>>>>>> )' -- . >/dev/null; then
  git grep -nE '^(<<<<<<< |>>>>>>> )' -- . | head
  echo "lead_push: merge-conflict markers in tracked files. NOT pushing."; exit 1
fi
SHA="$(git rev-parse HEAD)"
if [[ $# -ge 1 ]]; then
  "$ROOT/tools/ci/run_tests.sh" "$1"; RC=$?
else
  "$ROOT/tools/ci/check_all.sh"; RC=$?
fi
if [[ $RC -ne 0 ]]; then echo "lead_push: checks FAILED (rc=$RC); NOT pushing."; exit $RC; fi
git push -u origin "$SHA:refs/heads/$BRANCH" && echo "lead_push: pushed $SHA."
