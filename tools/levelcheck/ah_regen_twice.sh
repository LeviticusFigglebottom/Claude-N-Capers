#!/usr/bin/env bash
# Afterhours G1 determinism check (as rt_regen_twice.sh). Owner: ENV C (AH-C1).
# 1. the plan check passes and the emitted layout data is current (afterhours_emit_layout.py --stdout [--content]
#    == the two .gd files);
# 2. the generator runs twice into a temp dir (-- --out=<path>) and the two scenes are byte-identical.
# usage: tools/levelcheck/ah_regen_twice.sh [--keep]     (--keep leaves the temp dir and prints it)
set -uo pipefail
source "$(dirname "$0")/_common.sh"
PLANS="$ROOT/tools/levelcheck/plans"
GB="$ROOT/game/world/heists/afterhours/greybox"
GEN="res://world/heists/afterhours/greybox/build_greybox.gd"
rc=0
for chk in afterhours_floors_ascii; do
	if ! python3 "$PLANS/$chk.py" --check >/dev/null 2>&1; then
		echo "FAIL plan check: $chk.py --check"
		rc=1
	fi
done
if ! diff -q <(python3 "$PLANS/afterhours_emit_layout.py" --stdout) "$GB/afterhours_layout.gd" >/dev/null \
	|| ! diff -q <(python3 "$PLANS/afterhours_emit_layout.py" --stdout --content) \
		"$GB/afterhours_layout_content.gd" >/dev/null; then
	echo "FAIL layout: the layout .gd files are stale (re-run tools/levelcheck/plans/afterhours_emit_layout.py)"
	rc=1
else
	echo "OK   plan checks pass, layout data is current"
fi
tmp="$(mktemp -d)"
for run in a b; do
	log="$tmp/gen_$run.log"
	if ! "$GODOT" --headless --path "$ROOT/game" --script "$GEN" -- --out="$tmp/afterhours_$run.tscn" >"$log" 2>&1 \
		|| [[ ! -f "$tmp/afterhours_$run.tscn" ]]; then
		echo "FAIL run $run: generator failed"
		lc_show "$log"
		rm -rf "$tmp"
		exit 1
	fi
	grep -E "^afterhours: saved" "$log" || true
done
if cmp -s "$tmp/afterhours_a.tscn" "$tmp/afterhours_b.tscn"; then
	echo "OK   two regens are byte-identical ($(sha256sum "$tmp/afterhours_a.tscn" | cut -c1-16)," \
		"$(wc -c <"$tmp/afterhours_a.tscn") bytes)"
else
	echo "FAIL two regens differ:"
	diff "$tmp/afterhours_a.tscn" "$tmp/afterhours_b.tscn" | head -20
	rc=1
fi
if [[ "${1:-}" == "--keep" ]]; then
	echo "kept: $tmp"
else
	rm -rf "$tmp"
fi
exit $rc
