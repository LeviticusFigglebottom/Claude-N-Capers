#!/usr/bin/env bash
# Gallery Night skeleton determinism check (scratch; moves into game/tests/c/test_generator_determinism.gd when the
# map lands after the content freeze). Owner: ENV C (GN-C1).
# 1. the emitted layout data is current (tools/levelcheck/plans/gallery_night_emit_layout.py --stdout == the .gd);
# 2. the generator runs twice into a temp dir (-- --out=<path>) and the two scenes are byte-identical.
# usage: tools/levelcheck/gn_regen_twice.sh [--keep]     (--keep leaves the temp dir and prints it)
set -uo pipefail
source "$(dirname "$0")/_common.sh"
LAYOUT="$ROOT/game/world/heists/gallery_night/greybox/gallery_night_layout.gd"
GEN="res://world/heists/gallery_night/greybox/build_greybox.gd"
rc=0
if ! diff -q <(python3 "$ROOT/tools/levelcheck/plans/gallery_night_emit_layout.py" --stdout) "$LAYOUT" >/dev/null; then
	echo "FAIL layout: $LAYOUT is stale (re-run tools/levelcheck/plans/gallery_night_emit_layout.py)"
	rc=1
else
	echo "OK   layout data is current"
fi
tmp="$(mktemp -d)"
for run in a b; do
	log="$tmp/gen_$run.log"
	if ! "$GODOT" --headless --path "$ROOT/game" --script "$GEN" -- --out="$tmp/gallery_night_$run.tscn" >"$log" 2>&1 \
		|| [[ ! -f "$tmp/gallery_night_$run.tscn" ]]; then
		echo "FAIL run $run: generator failed"
		lc_show "$log"
		rm -rf "$tmp"
		exit 1
	fi
	grep -E "^gallery_night: saved" "$log" || true
done
if cmp -s "$tmp/gallery_night_a.tscn" "$tmp/gallery_night_b.tscn"; then
	echo "OK   two regens are byte-identical ($(sha256sum "$tmp/gallery_night_a.tscn" | cut -c1-16), $(wc -c <"$tmp/gallery_night_a.tscn") bytes)"
else
	echo "FAIL two regens differ:"
	diff "$tmp/gallery_night_a.tscn" "$tmp/gallery_night_b.tscn" | head -20
	rc=1
fi
if [[ "${1:-}" == "--keep" ]]; then
	echo "kept: $tmp"
else
	rm -rf "$tmp"
fi
exit $rc
