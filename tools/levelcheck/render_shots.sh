#!/usr/bin/env bash
# Renders review shots (level_standards §8) with xvfb (Vulkan via lavapipe; set
# LC_DRIVER=opengl3 to use the compatibility renderer). Owner: ENV C.
# usage: tools/levelcheck/render_shots.sh <heist_id> <g1|g2|g3|blueprint> [--plan] [extra review_shots args]
#   blueprint -> docs/levels/<id>/blueprint.png (+ blueprint_floor<i>.png) and
#                game/world/heists/<id>/<id>_blueprint.png (pre-planning board, preplanning.md)
#   -> docs/levels/<id>/<stage>/<camera>.jpg, contact_sheet.jpg, shots.md
#   g1 (or --plan) also renders the top-down floor plans plan_floor<i>.jpg + plan.md.
set -uo pipefail
source "$(dirname "$0")/_common.sh"
if [[ $# -lt 2 ]]; then
	echo "usage: $0 <heist_id> <g1|g2|g3|blueprint> [--plan] [args]" >&2
	exit 2
fi
id="$1"; stage="$2"; shift 2
plan=0
extra=()
for a in "$@"; do
	if [[ "$a" == "--plan" ]]; then plan=1; else extra+=("$a"); fi
done
[[ "$stage" == "g1" ]] && plan=1
drv=()
[[ -n "${LC_DRIVER:-}" ]] && drv=(--rendering-driver "$LC_DRIVER")
lc_import
run() {
	local out code
	out="$(mktemp)"
	xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$ROOT/game" --resolution 1920x1080 "${drv[@]}" \
		res://world/tools/review_shots.tscn -- --heist="$id" --stage="$stage" "$@" >"$out" 2>&1
	code=$?
	lc_show "$out"
	return $code
}
rc=0
if [[ "$stage" == "blueprint" ]]; then
	run --blueprint "${extra[@]}" || rc=1
	exit $rc
fi
run "${extra[@]}" || rc=1
if [[ $plan -eq 1 ]]; then
	run --plan "${extra[@]}" || rc=1
fi
exit $rc
