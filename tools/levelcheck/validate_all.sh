#!/usr/bin/env bash
# Runs validate_level (level_standards §7) on every heist, all variants. Owner: ENV C.
# usage: tools/levelcheck/validate_all.sh [heist_id ...] [--hub]
# Stage per heist: game/world/heists/<id>/stage.txt (greybox|final), default greybox.
# Reports: docs/levels/<id>/validation.md + walkthrough.md. Exit 1 if any heist fails.
# --hub (hub_map.md, C4-02): the safehouse hub instead (with heist ids: after them), --profile=hub; stage from
# game/world/hub/safehouse/stage.txt, reports to docs/levels/safehouse/. Without --hub nothing changes.
set -uo pipefail
source "$(dirname "$0")/_common.sh"
HUB=0
ARGS=()
for a in "$@"; do
	if [[ "$a" == "--hub" ]]; then HUB=1; else ARGS+=("$a"); fi
done
IDS=()
if [[ $HUB -eq 0 || ${#ARGS[@]} -gt 0 ]]; then
	mapfile -t IDS < <(lc_heists "${ARGS[@]}")
fi
if [[ ${#IDS[@]} -eq 0 && $HUB -eq 0 ]]; then
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
if [[ $HUB -eq 1 ]]; then
	stage="greybox"
	[[ -f "$ROOT/game/world/hub/safehouse/stage.txt" ]] && stage="$(tr -d '[:space:]' <"$ROOT/game/world/hub/safehouse/stage.txt")"
	echo "== validate_level safehouse hub ($stage)"
	out="$(mktemp)"
	"$GODOT" --headless --path "$ROOT/game" res://world/tools/validate_level.tscn -- \
		--scene=res://world/hub/safehouse/safehouse.tscn --profile=hub --stage="$stage" \
		--report="$ROOT/docs/levels/safehouse/validation.md" \
		--walkthrough-report="$ROOT/docs/levels/safehouse/walkthrough.md" >"$out" 2>&1
	code=$?
	lc_show "$out"
	if [[ $code -ne 0 ]]; then
		echo "!! safehouse: validate_level exit $code"
		rc=1
	fi
fi
exit $rc
