#!/usr/bin/env bash
# Runs validate_level (level_standards §7) on every heist, all variants. Owner: ENV C.
# usage: tools/levelcheck/validate_all.sh [heist_id ...]
# Stage per heist: game/world/heists/<id>/stage.txt (greybox|final), default greybox.
# Reports: docs/levels/<id>/validation.md + walkthrough.md. Exit 1 if any heist fails.
set -uo pipefail
source "$(dirname "$0")/_common.sh"
mapfile -t IDS < <(lc_heists "$@")
if [[ ${#IDS[@]} -eq 0 ]]; then
	echo "no heists"
	exit 0
fi
lc_import
rc=0
for id in "${IDS[@]}"; do
	stage="$(lc_stage "$id")"
	echo "== validate_level $id ($stage)"
	out="$(mktemp)"
	"$GODOT" --headless --path "$ROOT/game" res://world/tools/validate_level.tscn -- \
		--heist="$id" --stage="$stage" --variants=all >"$out" 2>&1
	code=$?
	lc_show "$out"
	if [[ $code -ne 0 ]]; then
		echo "!! $id: validate_level exit $code"
		rc=1
	fi
done
exit $rc
