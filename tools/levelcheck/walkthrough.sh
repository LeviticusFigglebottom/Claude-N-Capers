#!/usr/bin/env bash
# Walkthrough bot (level_standards §6): pure navmesh path queries from every player spawn to every
# objective / loot / secure zone / escape zone / UsePoint. Owner: ENV C.
# usage: tools/levelcheck/walkthrough.sh [heist_id ...]   -> docs/levels/<id>/walkthrough.md
# Whitelist detours in game/world/heists/<id>/walkthrough_whitelist.txt ("<spawn> <target>" per line).
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
	echo "== walkthrough $id"
	out="$(mktemp)"
	"$GODOT" --headless --path "$ROOT/game" res://world/tools/validate_level.tscn -- \
		--heist="$id" --stage="$(lc_stage "$id")" --only=walkthrough \
		--walkthrough-report="$ROOT/docs/levels/$id/walkthrough.md" >"$out" 2>&1
	code=$?
	lc_show "$out"
	[[ $code -ne 0 ]] && rc=1
done
exit $rc
