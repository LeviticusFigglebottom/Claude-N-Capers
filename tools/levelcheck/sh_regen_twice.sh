#!/usr/bin/env bash
# Safehouse hub determinism check (C4-02). Owner: ENV C.
# The generator runs twice into a temp dir (-- --out=<path>); the two scenes must be byte-identical and equal to the
# committed scene at build_safehouse.gd SCENE_PATH (the header line, which carries each file's own uid, aside).
# usage: tools/levelcheck/sh_regen_twice.sh [--keep]     (--keep leaves the temp dir and prints it)
set -uo pipefail
source "$(dirname "$0")/_common.sh"
GEN="res://world/hub/safehouse/greybox/build_safehouse.gd"
COMMITTED="$ROOT/game/world/hub/safehouse/safehouse.tscn"
rc=0
tmp="$(mktemp -d)"
for run in a b; do
	log="$tmp/gen_$run.log"
	if ! "$GODOT" --headless --path "$ROOT/game" --script "$GEN" -- --out="$tmp/safehouse_$run.tscn" >"$log" 2>&1 \
		|| [[ ! -f "$tmp/safehouse_$run.tscn" ]]; then
		echo "FAIL run $run: generator failed"
		lc_show "$log"
		rm -rf "$tmp"
		exit 1
	fi
	grep -E "^safehouse: saved" "$log" || true
done
body() { tail -n +2 "$1"; }
if cmp -s <(body "$tmp/safehouse_a.tscn") <(body "$tmp/safehouse_b.tscn"); then
	echo "OK   two regens are byte-identical ($(body "$tmp/safehouse_a.tscn" | sha256sum | cut -c1-16), $(wc -c <"$tmp/safehouse_a.tscn") bytes)"
else
	echo "FAIL two regens differ:"
	diff <(body "$tmp/safehouse_a.tscn") <(body "$tmp/safehouse_b.tscn") | head -20
	rc=1
fi
if cmp -s <(body "$tmp/safehouse_a.tscn") <(body "$COMMITTED"); then
	echo "OK   the committed scene is current"
else
	echo "FAIL the committed $(basename "$COMMITTED") is stale (re-run the generator without --out)"
	rc=1
fi
if [[ "${1:-}" == "--keep" ]]; then
	echo "kept: $tmp"
else
	rm -rf "$tmp"
fi
exit $rc
