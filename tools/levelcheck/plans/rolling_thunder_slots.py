# Rolling Thunder: the doc's variable table, rare events, pre-planning points, objectives, review cameras and the setup
# clock, with the --check against docs/design/heists/rolling_thunder.md and the rulings (D-075, D-140 / D-141.2,
# D-149). Owner: ENV C (RT-C1, paper stage: D-148.2 / D-149.10; `--check` only, nothing under game/). ENV B owns the
# values (D-137 QB-2): the weights below are the doc's G0 numbers until B's values block replaces them.
# Run: python3 tools/levelcheck/plans/rolling_thunder_slots.py --check    (consistency report, exit 0 / 1)
import os
import sys
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_floors_ascii as P  # noqa: E402
from rolling_thunder_checklib import Report  # noqa: E402

DIFFS = ["Routine", "Tense", "Hazardous", "Brutal", "Lethal", "Cataclysm"]

# Variable table, in rule order: (id, options, weights; a list of 6 rows = per difficulty, None = uniform / pick rule,
# scalar?, requires {group: [slots]}).
Var = Tuple[str, List[str], Optional[List[List[float]]], bool, Dict[str, List[str]]]
VARIABLES: List[Var] = [
    ("convoy_route", ["route_north", "route_east"], [[0.55, 0.45]], False, {}),
    ("truck_count", ["trucks_2", "trucks_3"], [[0.7, 0.3], [0.7, 0.3], [0.4, 0.6], [0.4, 0.6], [0.2, 0.8], [0.2, 0.8]],
     False, {}),
    ("cargo_t3", ["t3_cash", "t3_bullion"], [[0.5, 0.5]], False, {"truck_count": ["trucks_3"]}),
    ("cash_bags", ["4", "5", "6"], [[0.3, 0.5, 0.2], [0.3, 0.5, 0.2], [0.3, 0.5, 0.2], [0.2, 0.4, 0.4], [0.2, 0.4, 0.4],
                                    [0.2, 0.4, 0.4]], True, {}),
    ("gold_bags", ["3", "4"], [[0.5, 0.5]], True, {}),
    ("controller", ["ctrl_locked", "ctrl_open"], [[0.7, 0.3]], False, {}),
    ("site_stores", ["stores_c4", "stores_thermite", "stores_both"], [[0.4, 0.3, 0.3]], False, {}),
    ("guard_post", ["post_site_gate", "post_site_frame", "post_site_cabins"], None, False, {}),
    ("camera", ["cam_mast_cabins", "cam_magazine", "cam_gate"], None, False, {}),
    ("cop_on_scene", ["cop_plaza", "cop_diner", "cop_none"], [[0.4, 0.3, 0.3]], False, {}),
    ("marshal_walk", ["marshal_carpark", "marshal_site_corner", "marshal_plaza"], None, False, {}),
    ("goods_lift", ["lift_powered", "lift_dead"], [[0.6, 0.4]], False, {}),
    ("player_perch", ["perch_carpark_roof", "perch_frame", "perch_none"], [[0.3, 0.3, 0.4]], False, {}),
    ("escape", ["esc_van_carpark", "esc_van_underpass", "esc_heli_roof"], [[0.4, 0.35, 0.25]], False, {}),
    ("convoy_eta_s", ["150", "180", "210"], None, True, {}),
    ("police_delay_s", ["45", "60", "90"], [[0.1, 0.3, 0.6], [0.2, 0.4, 0.4], [0.3, 0.5, 0.2], [0.5, 0.4, 0.1],
                                            [0.7, 0.3, 0.0], [1.0, 0.0, 0.0]], True, {}),
    ("escape_eta_s", ["90", "120", "150"], [[0.4, 0.4, 0.2], [0.4, 0.4, 0.2], [0.4, 0.4, 0.2], [0.2, 0.4, 0.4],
                                            [0.2, 0.4, 0.4], [0.2, 0.4, 0.4]], True, {}),
    ("civilians", ["6", "9", "12"], None, True, {}),
]
DOC_VARIABLE_COUNT = 18
# Guard / camera picks per difficulty (doc: guard 1 Routine/Tense, 2 Hazardous+; camera 1 to Hazardous, 2 Brutal+).
PICKS = {"guard_post": [1, 1, 2, 2, 2, 2], "camera": [1, 1, 1, 2, 2, 2]}

# Rare events: (id, good, chance, min_difficulty or None, forces {group: slot}, reveals [groups], scalar overrides).
RARE: List[Tuple[str, bool, float, Optional[str], Dict[str, str], List[str], Dict[str, str]]] = [
    ("bonds_courier", True, 0.08, None, {}, [], {}),
    ("informant_tip", True, 0.06, None, {}, ["convoy_route", "marshal_walk"], {}),
    ("gold_rush", True, 0.04, None, {"truck_count": "trucks_3", "cargo_t3": "t3_bullion"}, [], {}),
    ("marshal_early", False, 0.08, None, {}, [], {}),
    ("convoy_early", False, 0.06, None, {}, [], {}),
    ("crane_sniper", False, 0.08, "Brutal", {}, [], {}),
    ("armored_escort", False, 0.06, "Lethal", {}, [], {}),
    ("rush_hour", False, 0.06, None, {}, [], {"civilians": "12"}),
]
DOC_RARE_COUNT = 8

# Pre-planning points: (id, category, floor index into floor_heights, variant group / slot or "").
PREPLAN: List[Tuple[str, str, int, str]] = [
    ("pp_spawn_plaza", "spawn", 1, ""), ("pp_spawn_carpark", "spawn", 2, ""), ("pp_spawn_underpass", "spawn", 0, ""),
    ("pp_drop_site", "drop_zone", 1, ""), ("pp_drop_carpark", "drop_zone", 2, ""),
    ("pp_drop_diner_yard", "drop_zone", 1, ""), ("pp_drop_underpass", "drop_zone", 0, ""),
    ("pp_escape_carpark", "escape", 1, "escape/esc_van_carpark"),
    ("pp_escape_underpass", "escape", 0, "escape/esc_van_underpass"),
    ("pp_escape_roof", "escape", 3, "escape/esc_heli_roof"),
    ("pp_perch_roof", "drop_zone", 3, "player_perch/perch_carpark_roof"),
    ("pp_perch_frame", "drop_zone", 2, "player_perch/perch_frame"),
    ("pp_signals", "insider", 1, "controller/ctrl_open"),
]
ASSET_POINTS: Dict[str, List[str]] = {
    "asset.ammo_bag_drop": ["pp_drop_site", "pp_drop_carpark", "pp_drop_diner_yard", "pp_drop_underpass"],
    "asset.doctor_bag_drop": ["pp_drop_site", "pp_drop_carpark", "pp_drop_diner_yard", "pp_drop_underpass"],
    "asset.body_bag_case_drop": ["pp_drop_site", "pp_drop_diner_yard"],
    "asset.thermite_drop": ["pp_drop_site", "pp_drop_carpark", "pp_drop_underpass"],
    "asset.sniper_position": ["pp_perch_roof", "pp_perch_frame"],
    "asset.c4_drop": ["pp_drop_carpark", "pp_drop_underpass"],
    "asset.signal_insider": ["pp_signals"],
}
# Drop-zone point -> the level its floor index must name (Pre-planning table) for the drop's own notes.
POINT_LEVEL = {"pp_drop_carpark": "CP-2", "pp_spawn_carpark": "CP-2", "pp_perch_frame": "SU", "pp_escape_roof": "CP-R",
               "pp_perch_roof": "CP-R", "pp_escape_carpark": "CP-G"}

OBJECTIVES = ["casing", "signals", "charges", "thermite", "marshal", "convoy", "ambush", "escort", "trucks", "cargo",
              "secure", "escape_wait", "escape"]
HEISTDEF_OBJECTIVES = ["casing", "signals", "charges", "thermite", "marshal", "convoy", "ambush", "escort", "trucks",
                       "cargo", "secure", "escape_wait", "escape"]
REQUIRED_BAGS = 4

REVIEW_CAMS = ["rc_top_down", "rc_ext_junction", "rc_ext_north_arm", "rc_ext_east_arm", "rc_ext_plaza",
               "rc_ext_tannery_west", "rc_diner_neon", "rc_convoy_cash", "rc_convoy_bullion", "rc_carpark_ground",
               "rc_carpark_deck2", "rc_carpark_ramp", "rc_carpark_roof", "rc_carpark_booth", "rc_carpark_plant",
               "rc_carpark_stair", "rc_diner_dining", "rc_diner_kitchen", "rc_diner_function", "rc_diner_office",
               "rc_diner_staff", "rc_site_controller", "rc_site_frame", "rc_site_slab", "rc_site_cabins",
               "rc_site_welfare", "rc_underpass", "rc_sniper_skyway"]
DOC_REVIEW_COUNT = 28

# Setup clock (Circulation / Mission script notes): marshal at ETA - 75 (- 90 marshal_early), sighting at ETA - 20,
# convoy_early subtracts 45 s.
MARSHAL_LEAD = 75
MARSHAL_LEAD_EARLY = 90
SIGHTED_LEAD = 20
CONVOY_EARLY = 45
RIG_TIME = 15 + 8           # controller padlock 8 s + the rig 15 s (no interruption)

# Pager budget (Stealth routes): site guards 1-2 + the marshal; cap 4 (D-141.2: RT keeps the default pager cap).
PAGER_CAP = 4
SITE_GUARDS = (1, 2)
# Truck numbers (Truck targets; D-075 ◇) and the lockdown multiplier (original mechanic, D-149.9).
SAW = {"cash": 120, "bullion": 180}
HAND_SAW = {"cash": 60, "bullion": 90}
LOCKDOWN_MULT = 1.5
CHARGES = 4
C4_BOXES = 2                # two boxes x item.c4 4 = one truck each
THERMITE_BURN = 45


def check_variables(rep: Report) -> None:
    rep.section("Variable table (%d rows, rule order, weights)" % DOC_VARIABLE_COUNT)
    rep.expect(len(VARIABLES) == DOC_VARIABLE_COUNT, "%d variables (doc %d)" % (len(VARIABLES), DOC_VARIABLE_COUNT))
    seen: Dict[str, List[str]] = {}
    for vid, opts, weights, scalar, req in VARIABLES:
        for g, slots in req.items():
            ok = g in seen and all(s in seen[g] for s in slots)
            rep.expect(ok, "%s requires %s (resolved earlier: %s)" % (vid, req, g in seen))
        if weights is not None:
            for i, row in enumerate(weights):
                good = len(row) == len(opts) and abs(sum(row) - 1.0) < 1e-6
                label = DIFFS[i] if len(weights) == 6 else "all"
                if not good:
                    rep.fail("%s weights %s (%s) do not match %d options / sum to 1" % (vid, row, label, len(opts)))
            if len(weights) not in (1, 6):
                rep.fail("%s has %d weight rows (1 or 6)" % (vid, len(weights)))
        if not scalar and len(opts) < 2:
            rep.fail("%s needs >= 2 slots (heist_map §5)" % vid)
        seen[vid] = opts
    rep.ok("every weighted row sums to 1 and matches its options")
    for g, picks in PICKS.items():
        n = len(next(v[1] for v in VARIABLES if v[0] == g))
        rep.expect(all(1 <= p <= n for p in picks), "%s picks %s of %d slots" % (g, picks, n))


def check_rare(rep: Report) -> None:
    rep.section("Rare events")
    rep.expect(len(RARE) == DOC_RARE_COUNT, "%d rare events (doc %d)" % (len(RARE), DOC_RARE_COUNT))
    groups = {v[0]: v[1] for v in VARIABLES}
    for rid, _good, chance, mind, forces, reveals, scal in RARE:
        bad = [g for g, s in forces.items() if s not in groups.get(g, [])]
        bad += [g for g in reveals if g not in groups]
        bad += [g for g, s in scal.items() if s not in groups.get(g, [])]
        if mind is not None and mind not in DIFFS:
            bad.append("min_difficulty %s" % mind)
        rep.expect(not bad and 0 < chance < 0.2, "%s %.0f %%%s%s" % (rid, chance * 100,
                                                                     " (from %s)" % mind if mind else "",
                                                                     ": bad refs " + str(bad) if bad else ""))


def check_preplan(rep: Report) -> None:
    rep.section("Pre-planning points and assets")
    ids = [p[0] for p in PREPLAN]
    rep.expect(len(ids) == len(set(ids)) == 13, "%d unique points" % len(set(ids)))
    groups = {v[0]: v[1] for v in VARIABLES}
    for pid, _cat, fl, slot in PREPLAN:
        if not 0 <= fl < len(P.FLOOR_HEIGHTS):
            rep.fail("%s floor %d not in floor_heights" % (pid, fl))
        if slot:
            g, s = slot.split("/")
            rep.expect(s in groups.get(g, []), "%s -> %s/%s exists" % (pid, g, s))
        lv = POINT_LEVEL.get(pid)
        if lv is not None:
            want = P.FLOOR_HEIGHTS.index(P.LEVEL_FFL[lv])
            if want != fl:
                rep.fail("%s is on %s (floor %d) but the table says floor %d" % (pid, lv, want, fl))
    for aid, pts in ASSET_POINTS.items():
        rep.expect(all(p in ids for p in pts), "%s points %s exist" % (aid, pts))


def check_objectives(rep: Report) -> None:
    rep.section("Objectives, review cameras")
    rep.expect(OBJECTIVES == HEISTDEF_OBJECTIVES and len(OBJECTIVES) == 13,
               "13 objective tags match the HeistDef list, in order")
    rep.expect(len(REVIEW_CAMS) == len(set(REVIEW_CAMS)) == DOC_REVIEW_COUNT,
               "%d review cameras (doc %d)" % (len(set(REVIEW_CAMS)), DOC_REVIEW_COUNT))


def check_clock(rep: Report) -> None:
    rep.section("Setup clock, pager budget, truck numbers")
    etas = [int(s) for s in next(v[1] for v in VARIABLES if v[0] == "convoy_eta_s")]
    worst = min(etas) - CONVOY_EARLY
    rep.expect(worst - MARSHAL_LEAD_EARLY >= 0, "earliest convoy %d s (eta %d - %d): marshal at %d s (marshal_early)"
               % (worst, min(etas), CONVOY_EARLY, worst - MARSHAL_LEAD_EARLY))
    rep.expect(worst - SIGHTED_LEAD > RIG_TIME, "earliest sighting at %d s leaves time for the %d s signal job"
               % (worst - SIGHTED_LEAD, RIG_TIME))
    rep.expect(SITE_GUARDS[1] + 1 <= PAGER_CAP, "pagers: %d-%d site guards + the marshal <= cap %d (D-141.2)"
               % (SITE_GUARDS[0], SITE_GUARDS[1], PAGER_CAP))
    for k in ("cash", "bullion"):
        rep.ok("%s: placed saw %d s (lockdown %d s), hand saw %d s (lockdown %d s), C4 %d charges"
               % (k, SAW[k], SAW[k] * LOCKDOWN_MULT, HAND_SAW[k], HAND_SAW[k] * LOCKDOWN_MULT, CHARGES))
    rep.ok("bullion thermite %d s on the rear-door lock at ground level (D-149.2)" % THERMITE_BURN)
    rep.expect(C4_BOXES * 4 >= CHARGES, "%d C4 boxes x 4 = %d charges >= one truck (%d)" % (C4_BOXES, C4_BOXES * 4,
                                                                                            CHARGES))
    cash = [int(s) for s in next(v[1] for v in VARIABLES if v[0] == "cash_bags")]
    rep.expect(max(cash) >= REQUIRED_BAGS, "one cash van alone can meet the %d required bags on %s of its rolls"
               % (REQUIRED_BAGS, [c for c in cash if c >= REQUIRED_BAGS]))


def check() -> Report:
    rep = Report("rolling_thunder_slots --check")
    check_variables(rep)
    check_rare(rep)
    check_preplan(rep)
    check_objectives(rep)
    check_clock(rep)
    return rep


if __name__ == "__main__":
    r = check()
    print(r.render())
    sys.exit(0 if r.passed else 1)
