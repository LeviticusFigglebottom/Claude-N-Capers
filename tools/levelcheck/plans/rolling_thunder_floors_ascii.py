# Floor plans + checks for docs/design/heists/rolling_thunder.md ("Floor plans", "Room list", vertical data table).
# Owner: ENV C (RT-C1, paper stage: D-148.2 / D-149.10; `--check` only, no layout output, nothing under game/).
# Run: python3 tools/levelcheck/plans/rolling_thunder_floors_ascii.py            (the plans, redrawn from the data)
#      python3 tools/levelcheck/plans/rolling_thunder_floors_ascii.py --check    (consistency report, exit 0 / 1)
#
# 1 char = 1 m; each char is a grid POINT (x = col, z = row). Rooms are rectangles (x0, z0, x1, z1) between wall centre
# lines, in each building's LOCAL coordinates (origin = its NW corner, +x east, +z south), transcribed from the doc's
# drawings. Site = local + offset (BUILDINGS). Levels: car park CP-G (0.0) / CP-2 (+3.5) / CP-R (+7.0); diner DG (0.0) /
# DU (+3.5); Tanner's Reach SG (0.0) / SU (the frame slab, +3.5). The car-park decks and the site yard are the
# remainder of their footprint (the `fill` room).
#
# --check: rooms tile each footprint (no overlap, nothing outside); room sizes and ceilings vs the Room list and the
# lc_check_scale.gd purpose bands; every opening lies on a wall with exactly one room on each side; every room has a
# door and is reachable from the street; doors on routes are >= 1.0 m (next_heist.md §7 / D-104); the stair, ramp,
# ladder and storey arithmetic of the vertical data table; the §7 traversal heights (guards vs the jump apex).
import os
import sys
from typing import Dict, List, Optional, Set, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rolling_thunder_checklib import (OUT, Level, Opening, Rect, Report, Room, area, link, reach,  # noqa: E402
                                      rect_inside, size, slope_deg, stair_ok)

# HeistMap.floor_heights / floor_names (doc "Vertical data"; D-054, D-040).
FLOOR_HEIGHTS = [-5.0, 0.0, 3.5, 7.0]
FLOOR_NAMES = ["Underpass", "Street", "Upper", "Roof"]

# Building local origin -> site (doc: "site x = local x + 16, site z = local z - 50" etc.).
BUILDINGS: Dict[str, Tuple[float, float]] = {"CP": (16.0, -50.0), "D": (14.0, 14.0), "S": (-60.0, -56.0)}
LEVEL_BUILDING = {"CP-G": "CP", "CP-2": "CP", "CP-R": "CP", "DG": "D", "DU": "D", "SG": "S", "SU": "S"}
LEVEL_FFL = {"CP-G": 0.0, "CP-2": 3.5, "CP-R": 7.0, "DG": 0.0, "DU": 3.5, "SG": 0.0, "SU": 3.5}

# Legend widths (doc "Floor plans" legend): personnel 0.9 m, service 1.0-1.2 m (lower bound used), diner front 1.8 m.
PERSONNEL = 0.9
SERVICE = 1.0
DOUBLE = 1.8
ROUTE_DOOR_MIN = 1.0      # next_heist.md §7 item 7 (D-104), OF plan §7.12, RT plan §7.4

CP_FOOT: Rect = (0, 0, 36, 36)
STA: Rect = (0, 0, 3, 6)          # stair A core (3 x 6), the Orchard street door at (0, 4)
LF: Rect = (3, 0, 6, 3)           # goods lift (bag_lift, 3 landings)
SB: Rect = (33, 30, 36, 36)       # stair B core
STRIP: Rect = (27, 6, 33, 30)     # the stacked ramps R1 (0 -> 3.5) / R2 (3.5 -> 7.0), 6 x 24 m

LEVELS: Dict[str, Level] = {
    "CP-G": Level("CP-G", CP_FOOT, [
        Room("STA", "stair", STA), Room("LF", "elevator", LF),
        Room("AB", "office", (0, 30, 5, 36), 2.6), Room("CWC", "restroom", (11, 32, 14, 36), 2.6),
        Room("CPL", "plant", (14, 30, 21, 36), 2.7), Room("SB", "stair", SB), Room("R1", "ramp", STRIP),
    ], fill=Room("CP-G", "car_park", CP_FOOT, 2.7)),
    "CP-2": Level("CP-2", CP_FOOT, [
        Room("STA", "stair", STA), Room("LF", "elevator", LF), Room("SB", "stair", SB), Room("R2", "ramp", STRIP),
    ], fill=Room("CP-2", "car_park", CP_FOOT, 2.7)),
    "CP-R": Level("CP-R", CP_FOOT, [
        Room("HHA", "stair", STA), Room("LF", "elevator", LF), Room("HHB", "stair", SB), Room("R2_VOID", "void", STRIP),
    ], fill=Room("CP-R", "roof", CP_FOOT)),
    "DG": Level("DG", (0, 0, 20, 26), [
        Room("DR", "restaurant", (0, 0, 13, 12), 3.0), Room("K", "kitchen", (13, 0, 20, 8), 2.8),
        Room("BC", "corridor", (13, 8, 20, 10), 2.8), Room("E", "electrical", (18, 10, 20, 12), 2.8),
        Room("ST", "storage", (13, 10, 18, 18), 2.8), Room("ST", "storage", (18, 12, 20, 18), 2.8),
        Room("W1", "restroom", (0, 12, 3, 15), 2.8), Room("W2", "restroom", (0, 15, 3, 18), 2.8),
        Room("R", "corridor", (3, 12, 5, 18), 2.8), Room("SC", "stair", (5, 12, 8, 18)),
        Room("OF", "office", (8, 12, 13, 18), 2.8), Room("YD", "exterior", (0, 18, 20, 26)),
    ]),
    "DU": Level("DU", (0, 0, 20, 18), [
        Room("U1", "restaurant", (0, 0, 13, 12), 3.0), Room("U2", "storage", (13, 0, 20, 10), 2.8),
        Room("U3", "storage", (13, 10, 20, 18), 2.8), Room("U4", "restroom", (0, 12, 3, 15), 2.8),
        Room("J", "janitor", (0, 15, 3, 18), 2.8), Room("UC", "corridor", (3, 12, 5, 18), 2.8),
        Room("SC", "stair", (5, 12, 8, 18)), Room("U5", "staff_room", (8, 12, 13, 18), 2.8),
    ]),
    "SG": Level("SG", (0, 0, 46, 45), [
        Room("C1", "office", (2, 30, 5, 39), 2.6), Room("C2", "break_room", (5, 30, 8, 39), 2.6),
        Room("C3", "restroom", (8, 30, 11, 39), 2.6), Room("C4", "storage", (11, 30, 14, 39), 2.6),
        Room("MG", "prop", (35, 4, 39, 7)), Room("STW", "stair", (24, 26, 28, 32)),
    ], fill=Room("X4", "exterior", (0, 0, 46, 45))),
    "SU": Level("SU", (10, 6, 34, 26), [], fill=Room("F1", "exterior", (10, 6, 34, 26))),
}

# Openings: (level, name, x, z, along, width, route, note). Grid points as drawn; `along` "x" = on a wall of constant z.
OPENINGS: List[Opening] = [
    # --- car park ground ---
    Opening("CP-G", "sta_street", 0, 4, "z", PERSONNEL, True, "stair A -> Orchard sidewalk"),
    Opening("CP-G", "sta_lobby", 3, 5, "z", PERSONNEL, True, "stair A -> lobby / deck"),
    Opening("CP-G", "lf_door", 4.5, 3, "x", None, True, "lift landing DD (width not stated)"),
    Opening("CP-G", "ab_door", 5, 33, "z", PERSONNEL, True, "attendant booth"),
    Opening("CP-G", "cwc_door", 12, 32, "x", PERSONNEL, False, "staff WC"),
    Opening("CP-G", "cpl_door", 17, 30, "x", PERSONNEL, True, "plant: the lift breaker (lift_dead)"),
    Opening("CP-G", "sb_door", 33, 31, "z", PERSONNEL, True, "stair B"),
    Opening("CP-G", "fire_door", 36, 15, "z", PERSONNEL, True, "east fire door -> rail lane (push bar)"),
    Opening("CP-G", "entrance", 8, 36, "x", 4.0, True, "vehicle entrance x 6-10, barrier arm, 2.4 m height bar"),
    # --- car park deck 2 ---
    Opening("CP-2", "sta_lobby", 3, 5, "z", PERSONNEL, True, "stair A"),
    Opening("CP-2", "lf_door", 4.5, 3, "x", None, True, "lift landing DD"),
    Opening("CP-2", "sb_door", 33, 31, "z", PERSONNEL, True, "stair B"),
    # --- car park roof ---
    Opening("CP-R", "hha_door", 3, 5, "z", PERSONNEL, True, "head house A (perch_carpark_roof)"),
    Opening("CP-R", "lf_door", 4, 3, "x", None, True, "lift landing (drawn as a single D on the roof)"),
    Opening("CP-R", "hhb_door", 33, 31, "z", PERSONNEL, True, "head house B (escape route, unlocked)"),
    # --- diner ground + yard ---
    Opening("DG", "front", 4.5, 0, "x", DOUBLE, True, "front double door (Tannery)"),
    Opening("DG", "side", 0, 8, "z", PERSONNEL, True, "side door (Orchard)"),
    Opening("DG", "delivery", 18, 0, "x", SERVICE, True, "kitchen delivery door (Tannery)"),
    Opening("DG", "k_bc", 16, 8, "x", PERSONNEL, True, "kitchen -> BC"),
    Opening("DG", "dr_bc", 13, 9, "z", PERSONNEL, True, "behind the counter -> BC"),
    Opening("DG", "bc_st", 16, 10, "x", PERSONNEL, True, "BC -> dry store"),
    Opening("DG", "e_door", 19, 12, "x", PERSONNEL, False, "electrical"),
    Opening("DG", "dr_r", 4, 12, "x", PERSONNEL, True, "dining -> rear lobby"),
    Opening("DG", "dr_of", 11, 12, "x", PERSONNEL, True, "back of the counter -> office (safe)"),
    Opening("DG", "w1", 3, 13, "z", PERSONNEL, False, "customer WC 1"),
    Opening("DG", "w2", 3, 16, "z", PERSONNEL, False, "customer WC 2"),
    Opening("DG", "r_sc", 5, 15, "z", PERSONNEL, True, "rear lobby -> stair SC"),
    Opening("DG", "fire_exit", 4, 18, "x", PERSONNEL, True, "R push-bar fire exit -> yard"),
    Opening("DG", "st_service", 16, 18, "x", SERVICE, True, "dry-store service door -> yard"),
    Opening("DG", "yard_gate_w", 0, 22, "z", None, True, "yard gate W (Orchard)"),
    Opening("DG", "yard_gate_e", 20, 23, "z", None, True, "yard gate E (laundromat yard)"),
    # --- diner upper ---
    Opening("DU", "u1_u2", 13, 5, "z", PERSONNEL, True, "function room -> storage"),
    Opening("DU", "u1_u3", 13, 11, "z", PERSONNEL, True, "function room -> dry goods"),
    Opening("DU", "u1_uc", 4, 12, "x", PERSONNEL, True, "function room -> landing corridor"),
    Opening("DU", "u1_u5", 11, 12, "x", PERSONNEL, True, "function room -> staff room"),
    Opening("DU", "u4", 3, 13, "z", PERSONNEL, False, "WC"),
    Opening("DU", "uc_sc", 5, 15, "z", PERSONNEL, True, "landing corridor -> stair SC"),
    # --- Tanner's Reach ---
    Opening("SG", "vehicle_gate", 46, 12.5, "z", 5.0, True, "Orchard vehicle gate z 10-15 (chained, LOCKPICK 8 s)"),
    Opening("SG", "man_gate", 46, 40, "z", None, True, "Orchard man-gate (mesh vision panel)"),
    Opening("SG", "tannery_gate", 26.5, 45, "x", 5.0, True, "Tannery gate x 24-29 (the mixer waits inside)"),
    Opening("SG", "c1", 3, 39, "x", PERSONNEL, True, "site office"),
    Opening("SG", "c2", 6, 39, "x", PERSONNEL, True, "welfare"),
    Opening("SG", "c3", 9, 39, "x", PERSONNEL, False, "WCs"),
    Opening("SG", "c4", 12, 39, "x", PERSONNEL, True, "tool store (LOCKPICK 8 s; the thermite bag)"),
    Opening("SG", "mg", 37, 7, "x", PERSONNEL, True, "magazine door (padlock; UsePoint outside)"),
    Opening("SG", "stw_foot", 26, 32, "x", 1.2, True, "scaffold stair tower entry (stair width; drawn closed)"),
]

# Vertical connections (graph edges between levels): (level a, room a, level b, room b, kind).
VERTICAL: List[Tuple[str, str, str, str, str]] = [
    ("CP-G", "STA", "CP-2", "STA", "stair"), ("CP-2", "STA", "CP-R", "HHA", "stair"),
    ("CP-G", "SB", "CP-2", "SB", "stair"), ("CP-2", "SB", "CP-R", "HHB", "stair"),
    ("CP-G", "LF", "CP-2", "LF", "lift"), ("CP-2", "LF", "CP-R", "LF", "lift"),
    ("CP-G", "CP-G", "CP-G", "R1", "ramp foot (south)"), ("CP-G", "R1", "CP-2", "CP-2", "ramp top (north)"),
    ("CP-2", "CP-2", "CP-2", "R2", "ramp foot (south)"), ("CP-2", "R2", "CP-R", "CP-R", "ramp top (north)"),
    ("DG", "SC", "DU", "SC", "stair"),
    ("SG", "STW", "SU", "F1", "scaffold stair"), ("SG", "X4", "SU", "F1", "ladder (no bags)"),
]
# Openings this script assumes because the drawing does not show them (reported as WARN).
ASSUMED: Dict[str, str] = {
    "SG stw_foot": "the scaffold stair tower is drawn closed at street level (SSSSS on all sides); an entry is assumed "
                   "on its south face (RT-C0: draw it)",
}

# Room list sizes (doc "Room list"; sizes between wall centre lines). ST is "7 x 8 less E" (56 - 4 m2).
ROOM_LIST: Dict[str, Tuple[float, float]] = {
    "STA": (3, 6), "SB": (3, 6), "HHA": (3, 6), "HHB": (3, 6), "LF": (3, 3), "AB": (5, 6), "CWC": (3, 4),
    "CPL": (7, 6), "DR": (13, 12), "K": (7, 8), "BC": (7, 2), "E": (2, 2), "W1": (3, 3), "W2": (3, 3), "R": (2, 6),
    "SC": (3, 6), "OF": (5, 6), "U1": (13, 12), "U2": (7, 10), "U3": (7, 8), "U4": (3, 3), "J": (3, 3), "U5": (5, 6),
    "YD": (20, 8), "C1": (3, 9), "C2": (3, 9), "C3": (3, 9), "C4": (3, 9), "MG": (3, 2.4), "STW": (4, 6),
}
ROOM_LIST_AREA = {"ST": 7 * 8 - 4}
ZONE_SIZES = {"FG": ((10, 6, 34, 26), (24, 20)), "F1": ((10, 6, 34, 26), (24, 20))}
# lc_check_scale.gd CEILING (level_standards §2.6, D-075): purpose -> band. Purposes without a rule are skipped.
CEILING: Dict[str, Tuple[float, float]] = {
    "office": (2.6, 3.0), "break_room": (2.6, 3.0), "kitchen": (2.6, 3.0), "restroom": (2.6, 3.0),
    "storage": (2.6, 3.0), "janitor": (2.6, 3.0), "electrical": (2.6, 3.0), "corridor": (2.6, 3.0),
    "staff_room": (2.6, 3.0), "restaurant": (3.0, 4.5), "plant": (2.6, 6.0), "car_park": (2.2, 3.0),
}

# Vertical data table: (name, from, to, flights, risers per flight, riser, tread, width).
STAIRS: List[Tuple[str, float, float, int, int, float, float, float]] = [
    ("car park A/B 0 -> 3.5", 0.0, 3.5, 2, 10, 0.175, 0.28, 1.2),
    ("car park A/B 3.5 -> 7.0", 3.5, 7.0, 2, 10, 0.175, 0.28, 1.2),
    ("diner SC 0 -> 3.5", 0.0, 3.5, 2, 10, 0.175, 0.28, 1.2),
    ("site scaffold 0 -> 3.5", 0.0, 3.5, 2, 10, 0.175, 0.28, 1.2),
]
DOC_RUN = 2.52
CORE_CLEAR = (3.0 - 0.3, 6.0 - 0.3)      # 3.0 x 6.0 centre lines, 0.15 m walls
CORE_LANDING = 1.30
SCAFFOLD_TOWER = (4.0, 6.0)
SCAFFOLD_HALF_LANDING = 1.2
# (name, rise, run, width, doc degrees, headroom below the next slab or None)
RAMPS: List[Tuple[str, float, float, float, float, Optional[float]]] = [
    ("car park R1 0 -> 3.5", 3.5, 24.0, 6.0, 8.3, 3.5 - 0.3),
    ("car park R2 3.5 -> 7.0", 3.5, 24.0, 6.0, 8.3, None),
    ("Tannery road ramp 0 -> -5.0", 5.0, 32.0, 16.0, 8.9, None),
]
NAV_MAX_SLOPE = 40.0      # heist_map §3 (NPC agent)
PLAYER_MAX_SLOPE = 45.0
JUMP_APEX = 1.08          # next_heist.md §7 player numbers (D-102)
STEP = 0.35
HEADROOM = 2.1            # lc_check_scale.gd HEADROOM
# Storey makeup (doc vertical table): (name, ceiling, plenum / slab / downstand, floor-to-floor)
STOREYS = [("car park", 2.7, 0.3 + 0.5, 3.5), ("diner dining", 3.0, 0.5, 3.5), ("diner back rooms", 2.8, 0.7, 3.5)]
# Guards / barriers a crew member must not get over (height, what, can a 0.35 m step stand next to it?).
BARRIERS = [("car-park facade crash barrier", 1.1), ("car-park ramp guards", 1.1), ("roof parapet", 1.1),
            ("F1 edge protection", 1.1), ("retaining-wall parapet", 1.1), ("hoarding", 2.4), ("rail palisade", 1.8)]
GUARD_MIN = 1.0           # QC-33 guard height
# The F1 slab's edge-protection openings: (name, clear width along the edge) from the drawn 'r' runs.
SLAB_GAPS = [("ladder landing at the NW corner (rail from x 11 and z 7)", 1.0),
             ("scaffold stair arrival at x 25-27 (z 26)", 2.0)]


def _floor_index(ffl: float) -> int:
    return FLOOR_HEIGHTS.index(ffl) if ffl in FLOOR_HEIGHTS else -1


def check_tiling(rep: Report) -> None:
    rep.section("Tiling (rooms vs footprint, 1 m cells)")
    for key, lv in LEVELS.items():
        bad = False
        for o in sorted(lv.overlaps):
            rep.fail("%s rooms overlap: %s" % (key, o))
            bad = True
        for o in sorted(lv.outside):
            rep.fail("%s room outside the footprint: %s" % (key, o))
            bad = True
        covered = len(lv.cells)
        if not bad:
            rep.ok("%s %d m2 footprint, %d m2 rooms%s" % (key, area(lv.foot), covered - lv.fill_area,
                                                          ", %d m2 %s (remainder)" % (lv.fill_area, lv.fill.rid)
                                                          if lv.fill else ""))
        if lv.fill is None and covered != area(lv.foot):
            rep.fail("%s: %d m2 of the footprint is in no room" % (key, area(lv.foot) - covered))


def check_sizes(rep: Report) -> None:
    rep.section("Room sizes and ceilings vs the Room list / lc_check_scale bands")
    seen: Set[str] = set()
    for key, lv in LEVELS.items():
        rects: Dict[str, List[Rect]] = {}
        for rm in lv.rooms:
            rects.setdefault(rm.rid, []).append(rm.rect)
        for rid, rs in rects.items():
            if rid in ROOM_LIST_AREA:
                got = sum(area(r) for r in rs)
                rep.expect(got == ROOM_LIST_AREA[rid], "%s %s %.0f m2 (Room list %.0f)" % (key, rid, got,
                                                                                           ROOM_LIST_AREA[rid]))
            elif rid in ROOM_LIST and len(rs) == 1:
                w, d = size(rs[0])
                want = ROOM_LIST[rid]
                if (w, d) != want and (d, w) != want:
                    rep.fail("%s %s drawn %g x %g, Room list %g x %g" % (key, rid, w, d, want[0], want[1]))
                elif rid not in seen:
                    rep.ok("%s %s %g x %g" % (key, rid, w, d))
            elif rid not in ROOM_LIST and lv.rooms and rid not in ("R1", "R2", "R2_VOID"):
                rep.fail("%s %s is drawn but not in the Room list" % (key, rid))
            seen.add(rid)
        for rm in lv.rooms + ([lv.fill] if lv.fill else []):
            band = CEILING.get(rm.purpose)
            if band and rm.ceiling is not None:
                if not band[0] <= rm.ceiling <= band[1]:
                    rep.fail("%s %s ceiling %.1f outside %s %.1f-%.1f" % (key, rm.rid, rm.ceiling, rm.purpose,
                                                                          band[0], band[1]))
    for zid, (r, want) in ZONE_SIZES.items():
        rep.expect(size(r) == want, "%s %g x %g (Room list %g x %g)" % ((zid,) + size(r) + want))
    rep.info("MG has a 2.2 m interior: below every band, so it is a container prop, not a RoomVolume (doc)")


def _edges() -> Dict[str, Set[str]]:
    """Room graph: openings with one room on each side, plus the vertical links (stairs, lift, ramps, ladder)."""
    edges: Dict[str, Set[str]] = {}
    for op in OPENINGS:
        a, b = LEVELS[op.level].sides(op)
        if len(a) == 1 and len(b) == 1:
            na, nb = ("street" if r == OUT else "%s:%s" % (op.level, r) for r in (next(iter(a)), next(iter(b))))
            link(edges, na, nb)
    for la, ra, lb, rb, _k in VERTICAL:
        link(edges, "%s:%s" % (la, ra), "%s:%s" % (lb, rb))
    return edges


def check_openings(rep: Report) -> None:
    rep.section("Openings (on a wall, one room each side) and door widths on routes (>= %.1f m)" % ROUTE_DOOR_MIN)
    narrow: List[str] = []
    unstated: List[str] = []
    for op in OPENINGS:
        lv = LEVELS[op.level]
        a, b = lv.sides(op)
        tag = "%s %s (%g, %g)" % (op.level, op.name, op.x, op.z)
        if len(a) != 1 or len(b) != 1:
            rep.fail("%s straddles a partition: %s / %s" % (tag, sorted(a), sorted(b)))
            continue
        ra, rb = next(iter(a)), next(iter(b))
        if ra == rb:
            rep.fail("%s is not on a wall (%s both sides)" % (tag, ra))
            continue
        if op.route:
            if op.width is None:
                unstated.append(tag)
            elif op.width < ROUTE_DOOR_MIN:
                narrow.append("%s %.1f m" % (tag, op.width))
    rep.ok("%d openings lie on walls between two rooms" % len(OPENINGS))
    if narrow:
        rep.fail("%d route doors are narrower than %.1f m (the legend's 0.9 m personnel doors; RT plan §3 Wrong 2): %s"
                 % (len(narrow), ROUTE_DOOR_MIN, "; ".join(narrow)))
    for u in unstated:
        rep.warn("%s: width not stated in the doc (RT-C0: state >= %.1f m)" % (u, ROUTE_DOOR_MIN))


def check_reach(rep: Report) -> None:
    rep.section("Doors and reachability from the street")
    edges = _edges()
    seen = reach(edges, "street")
    n = 0
    for key, lv in LEVELS.items():
        for rid in dict.fromkeys([r.rid for r in lv.rooms] + ([lv.fill.rid] if lv.fill else [])):
            if rid.endswith("_VOID"):
                continue
            n += 1
            node = "%s:%s" % (key, rid)
            if not edges.get(node):
                rep.fail("%s %s has no door or opening" % (key, rid))
            elif node not in seen:
                rep.fail("%s %s is not reachable from the street" % (key, rid))
    rep.ok("%d rooms checked, %d reachable" % (n, len(seen) - 1))
    for tag, why in ASSUMED.items():
        rep.warn("%s: %s" % (tag, why))


def check_vertical(rep: Report) -> None:
    rep.section("Vertical data (floor heights, stairs, ramps, storeys, ladders)")
    fh = FLOOR_HEIGHTS
    rep.expect(fh == sorted(fh) and 0.0 in fh and len(FLOOR_NAMES) == len(fh),
               "floor_heights %s ascending, contain 0.0, %d names" % (fh, len(FLOOR_NAMES)))
    for key, ffl in LEVEL_FFL.items():
        rep.expect(_floor_index(ffl) >= 0, "%s FFL %.1f is a listed floor (%s)" % (key, ffl,
                                                                                   FLOOR_NAMES[_floor_index(ffl)]))
    for (nm, h0, h1, fl, rn, rh, tr, w) in STAIRS:
        good, txt = stair_ok(h1 - h0, fl, rn, rh, tr)
        run = (rn - 1) * tr
        rep.expect(good and abs(run - DOC_RUN) < 1e-6 and w >= 1.1, "%s: %s, width %.1f (>= 1.1)" % (nm, txt, w))
    across = 1.2 + 0.2 + 1.2
    along = CORE_LANDING + DOC_RUN + CORE_LANDING
    rep.expect(across <= CORE_CLEAR[0] and along <= CORE_CLEAR[1],
               "core fit: across %.2f <= %.2f, along %.2f <= %.2f" % (across, CORE_CLEAR[0], along, CORE_CLEAR[1]))
    s_along = SCAFFOLD_HALF_LANDING + DOC_RUN + SCAFFOLD_HALF_LANDING
    rep.expect(across <= SCAFFOLD_TOWER[0] and s_along <= SCAFFOLD_TOWER[1],
               "scaffold tower fit: across %.2f <= %.1f, along %.2f <= %.1f" % (across, SCAFFOLD_TOWER[0], s_along,
                                                                                SCAFFOLD_TOWER[1]))
    for (nm, rise, run, w, doc_deg, head) in RAMPS:
        deg = slope_deg(rise, run)
        ok = abs(deg - doc_deg) < 0.06 and deg < NAV_MAX_SLOPE and deg < PLAYER_MAX_SLOPE and w >= 1.0
        if head is not None:
            ok = ok and head >= HEADROOM
        rep.expect(ok, "%s: %.2f deg (doc %.1f; nav <= %.0f, player <= %.0f), width %.0f m%s"
                   % (nm, deg, doc_deg, NAV_MAX_SLOPE, PLAYER_MAX_SLOPE, w,
                      ", headroom %.1f m" % head if head is not None else ""))
    rep.expect(STRIP[2] - STRIP[0] == 6.0 and STRIP[3] - STRIP[1] == 24.0,
               "ramp strip %g x %g m = the R1 / R2 width and run" % size(STRIP))
    for (nm, ceil, extra, f2f) in STOREYS:
        rep.expect(abs(ceil + extra - f2f) < 1e-6, "%s storey: ceiling %.1f + %.1f = %.1f" % (nm, ceil, extra, f2f))
    rep.expect(abs((LEVEL_FFL["SU"] - LEVEL_FFL["SG"]) - 3.5) < 1e-6, "site ladder 3.5 m = the slab FFL (no bags)")
    rep.expect(rect_inside((24, 26, 28, 32), LEVELS["SG"].foot), "scaffold tower inside the hoarding")


def check_traversal(rep: Report) -> None:
    rep.section("Traversal heights and slab openings (RT plan §7)")
    for nm, h in BARRIERS:
        if h < GUARD_MIN:
            rep.fail("%s %.2f m below the %.1f m guard rule" % (nm, h, GUARD_MIN))
        elif h - JUMP_APEX < 0.05:
            rep.warn("%s %.2f m clears the %.2f m jump apex by only %.2f m: nothing standable (kerb, wheel stop, "
                     "step <= %.2f m) within 0.5 m of it" % (nm, h, JUMP_APEX, h - JUMP_APEX, STEP))
        else:
            rep.ok("%s %.2f m > jump apex %.2f m" % (nm, h, JUMP_APEX))
    for nm, w in SLAB_GAPS:
        rep.expect(w >= 1.0, "F1 %s: %.1f m clear (>= 1.0)" % (nm, w))


def check() -> Report:
    rep = Report("rolling_thunder_floors_ascii --check")
    check_tiling(rep)
    check_sizes(rep)
    check_openings(rep)
    check_reach(rep)
    check_vertical(rep)
    check_traversal(rep)
    return rep


def plan(key: str) -> str:
    """Redraw a level from the data: room boundaries, openings (D), the fill room left blank."""
    lv = LEVELS[key]
    x0, z0, x1, z1 = (int(v) for v in lv.foot)
    g = [[" "] * (x1 - x0 + 1) for _ in range(z1 - z0 + 1)]
    for rm in lv.rooms + ([lv.fill] if lv.fill else []):
        a, b, c, d = (int(v) for v in rm.rect)
        for i in range(a, c + 1):
            for j in (b, d):
                if x0 <= i <= x1 and z0 <= j <= z1:
                    g[j - z0][i - x0] = "-" if g[j - z0][i - x0] in (" ", "-") else "+"
        for j in range(b, d + 1):
            for i in (a, c):
                if x0 <= i <= x1 and z0 <= j <= z1:
                    g[j - z0][i - x0] = "|" if g[j - z0][i - x0] in (" ", "|") else "+"
        if rm is not lv.fill and rm.rid not in ("R1", "R2"):
            for n, ch in enumerate(rm.rid[:max(1, c - a - 1)]):
                if a + 1 + n <= x1:
                    g[b + 1 - z0][a + 1 + n - x0] = ch
    for op in OPENINGS:
        if op.level == key:
            g[int(op.z) - z0][int(op.x) - x0] = "D"
    out = ["%s (FFL %+.1f, local; site = local + %s)" % (key, LEVEL_FFL[key], BUILDINGS[LEVEL_BUILDING[key]]),
           "      " + "".join(str(i % 10) for i in range(x0, x1 + 1))]
    for j, row in enumerate(g):
        out.append(("%5d " % (z0 + j) if (z0 + j) % 2 == 0 else "      ") + "".join(row).rstrip())
    return "\n".join(out)


if __name__ == "__main__":
    if "--check" in sys.argv:
        r = check()
        print(r.render())
        sys.exit(0 if r.passed else 1)
    for k in LEVELS:
        print(plan(k))
        print()
