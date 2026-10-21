#!/usr/bin/env bash
# PO-5 release check (D-086): a real, WINDOWED playthrough through the menus, played by input only.
# Owner: ENV A.   usage: game/tests/a/e2e/run_po5.sh <flow> [seed] [budget_s] [out_dir] [heist] [difficulty]
#   flows: gh_loud (Golden Hour / glasshouse loud win -> payday -> hub), gh_stealth (WIP), auto_loud (any heist via
#          objective markers), smoke (menus -> heist start), dump (map inventory).
#   seed: run seed (menus are still clicked; HeistLauncher.next_seed_override); "-" = the menu's time seed.
#   budget_s: wall-clock budget, default 5400 (llvmpipe: a loud Glasshouse takes ~45-90 min wall).
# HEADLESS=1 runs it without a window (see below). Exit code 0 = PASS. Screenshots (NN_<step>.png), run.log and po5_log.txt land in out_dir.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
GODOT="${GODOT:-/opt/godot/godot}"
FLOW="${1:?flow}"
SEED="${2:--}"
BUDGET="${3:-5400}"
OUT="${4:-${TMPDIR:-/tmp}/po5_$FLOW}"
HEIST="${5:-Golden Hour}"  # menu display name; a heist id / code name ("Glasshouse") is mapped too
DIFF="${6:-Routine}"
mkdir -p "$OUT"
ARGS=(--po5-flow="$FLOW" --po5-out="$OUT" --po5-budget="$BUDGET" --po5-heist="$HEIST" --po5-difficulty="$DIFF")
[[ "$SEED" != "-" ]] && ARGS+=(--po5-seed="$SEED")
# D-133: CREW_DMG=0.25 runs the loud flow gate with the harness-only crew_damage_taken_mult (named in run.log).
[[ -n "${CREW_DMG:-}" ]] && ARGS+=(--po5-crew-dmg="$CREW_DMG")
# HITCH_MS=50 logs every heist frame over 50 ms with FrameProf's top (the GPU box's hitch runs).
[[ -n "${HITCH_MS:-}" ]] && ARGS+=(--po5-hitch-ms="$HITCH_MS")
# FOCUS=bond_safe: the auto_loud pilot takes that objective's marker first once it is up (po5_flow_auto_loud.focus).
[[ -n "${FOCUS:-}" ]] && ARGS+=(--po5-focus="$FOCUS")
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
# HEADLESS=1: the same real-menu flow without rendering (no xvfb, no screenshots; po5_flow.shot skips): LEAD D-145
# pre-checks, where llvmpipe frames under box load blew the wall budgets. Windowed stays the evidence for visuals.
if [[ "${HEADLESS:-}" == "1" ]]; then
	timeout $((BUDGET + 300)) "$GODOT" --headless --path "$ROOT/game" res://tests/a/e2e/po5_runner.tscn -- "${ARGS[@]}" \
		> "$OUT/run.log" 2>&1
else
	timeout $((BUDGET + 300)) xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$ROOT/game" --resolution 960x540 \
		res://tests/a/e2e/po5_runner.tscn -- "${ARGS[@]}" > "$OUT/run.log" 2>&1
fi
RC=$?
grep -E "^\[PO5.*(RESULT|FAIL|FINDING|EVENT heist_ended|back in the hub)" "$OUT/run.log" | tail -20
echo "screenshots + log: $OUT  (exit $RC)"
exit $RC
