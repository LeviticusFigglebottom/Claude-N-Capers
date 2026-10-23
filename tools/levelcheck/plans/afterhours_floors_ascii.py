# Floor plans + checks for docs/design/heists/afterhours.md ("Floor plans", "Room list", vertical data table).
# Owner: ENV C (AH-C1, D-165). The data source of the Afterhours greybox: afterhours_emit_layout.py reads it.
# Run: python3 tools/levelcheck/plans/afterhours_floors_ascii.py            (the plans, redrawn from the data)
#      python3 tools/levelcheck/plans/afterhours_floors_ascii.py --check    (consistency report, exit 0 / 1)
#
# 1 char = 1 m; each char is a grid POINT (x = col, z = row). Rooms are rectangles (x0, z0, x1, z1) between wall centre
# lines, transcribed from the doc's drawings (origin = the Velvet's NW corner, +x east, +z south). Two levels: Ground
# (0.0) and Balcony (+4.2). On the balcony level the BOH roof (z 0-7, exterior at +4.2) and the hall void (x 0-26,
# z 7-15) are plan rooms too, so the level tiles the whole 36 x 28 footprint.
#
# --check: rooms tile each footprint (no overlap, nothing outside); room sizes and ceilings vs the Room list and the
# lc_check_scale.gd purpose bands; every opening lies on a wall with exactly one room on each side; every room has a
# door (stairs and voids aside) and is reachable from the street; doors on routes are >= 1.0 m (next_heist.md §7 /
# D-104); the G8 / G22 stair arithmetic of the vertical data table.
from __future__ import annotations

import os
import sys
from typing import Dict, List, Set, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rolling_thunder_checklib import OUT, Level, Opening, Report, Room, link, reach, size, stair_ok  # noqa: E402

FLOOR_HEIGHTS = [0.0, 4.2]
FLOOR_NAMES = ["Ground", "Balcony"]
LEVEL_FFL = {"G": 0.0, "U": 4.2}
FOOT = (0, 0, 36, 28)

PERSONNEL = 1.0
DOUBLE = 1.8
ROUTE_DOOR_MIN = 1.0

# lc_check_scale.gd ceiling bands for the purposes used here (doc §2.6 table; `hall` is D-075's).
CEIL_BAND: Dict[str, Tuple[float, float]] = {
    "hall": (6.0, 9.0), "bar": (3.0, 4.5), "lobby": (3.0, 4.5), "reception": (2.6, 4.5), "restroom": (2.4, 3.2),
    "storage": (2.4, 4.0), "staff_room": (2.4, 3.2), "break_room": (2.4, 3.2), "corridor": (2.4, 3.2),
    "locker_room": (2.4, 3.2), "janitor": (2.2, 3.2), "electrical": (2.2, 3.2), "loading": (3.5, 6.0),
    "cash_office": (2.6, 3.2), "security_room": (2.6, 3.2), "manager_office": (2.6, 3.2), "living_room": (2.4, 3.2),
}

LEVELS: Dict[str, Level] = {
    "G": Level("G", FOOT, [
        # BOH strip (z 0-7)
        Room("G10", "storage", (0, 0, 8, 5), 3.0), Room("G11", "staff_room", (8, 0, 14, 5), 3.0),
        Room("G12", "break_room", (14, 0, 20, 5), 3.0), Room("G14", "locker_room", (20, 0, 25, 5), 3.0),
        Room("G16", "electrical", (25, 0, 27, 2), 3.0), Room("G15", "janitor", (25, 2, 27, 5), 3.0),
        Room("G21", "loading", (27, 0, 36, 5), 3.6), Room("G13", "corridor", (0, 5, 36, 7), 3.0),
        # the auditorium: the hall (double height) and the under-circle lounge (two volumes, one open space)
        Room("G6", "hall", (0, 7, 26, 15), 8.0), Room("G7", "bar", (0, 15, 26, 21), 3.6),
        # the east wing
        Room("G20", "corridor", (26, 7, 28, 21), 3.0), Room("G23", "storage", (28, 7, 33, 14), 3.0),
        Room("G22", "stair", (33, 7, 36, 14)), Room("G25", "lobby", (28, 14, 36, 17), 3.0),
        Room("G24", "staff_room", (28, 17, 36, 21), 3.0),
        # the front block
        Room("G3a", "restroom", (0, 21, 3, 28), 3.0), Room("G3b", "restroom", (3, 21, 6, 28), 3.0),
        Room("G8", "stair", (6, 21, 10, 28)), Room("G1", "lobby", (10, 21, 22, 28), 3.6),
        Room("G2", "reception", (22, 21, 26, 28), 3.6), Room("G26", "cash_office", (26, 21, 31, 28), 3.0),
        Room("G27", "storage", (31, 21, 36, 28), 3.0),
    ]),
    "U": Level("U", FOOT, [
        Room("ROOF", "roof", (0, 0, 36, 7)), Room("VOID", "void", (0, 7, 26, 15)),
        Room("U10", "cash_office", (26, 7, 33, 14), 3.0), Room("U7", "stair", (33, 7, 36, 14)),
        Room("U6", "corridor", (26, 14, 36, 16), 3.0), Room("U1", "bar", (0, 15, 26, 21), 3.8),
        Room("U6b", "corridor", (26, 16, 28, 28), 3.0), Room("U9", "manager_office", (28, 16, 36, 21), 3.0),
        Room("U4a", "restroom", (0, 21, 3, 28), 3.0), Room("U4b", "restroom", (3, 21, 6, 28), 3.0),
        Room("U8", "stair", (6, 21, 10, 28)), Room("U2", "bar", (10, 21, 22, 28), 3.2),
        Room("U5", "security_room", (22, 21, 26, 28), 3.0), Room("U12", "living_room", (28, 21, 36, 25), 3.0),
        Room("U13", "restroom", (28, 25, 36, 28), 3.0),
    ]),
}
# U1's west edge on the balcony is the hall void (the rail at z 15): U1 spans z 15-21 under the hall ceiling.

# Room list sizes (between wall centre lines), for the size check.
ROOM_SIZES: Dict[str, Tuple[float, float]] = {
    "G1": (12, 7), "G2": (4, 7), "G3a": (3, 7), "G3b": (3, 7), "G6": (26, 8), "G7": (26, 6), "G8": (4, 7),
    "G10": (8, 5), "G11": (6, 5), "G12": (6, 5), "G13": (36, 2), "G14": (5, 5), "G15": (2, 3), "G16": (2, 2),
    "G20": (2, 14), "G21": (9, 5), "G22": (3, 7), "G23": (5, 7), "G24": (8, 4), "G25": (8, 3), "G26": (5, 7),
    "G27": (5, 7), "U1": (26, 6), "U2": (12, 7), "U4a": (3, 7), "U4b": (3, 7), "U5": (4, 7), "U6": (10, 2),
    "U6b": (2, 12), "U7": (3, 7), "U9": (8, 5), "U10": (7, 7), "U12": (8, 4), "U13": (8, 3),
}

# Openings: (level, name, x, z, along, width, route, note). "x" = a wall at constant z (spans x); "z" = at constant x.
OPENINGS: List[Opening] = [
    # Ground: BOH
    Opening("G", "d_g10", 4, 5, "x", PERSONNEL, True), Opening("G", "d_g11", 11, 5, "x", PERSONNEL, True),
    Opening("G", "d_g12", 17, 5, "x", PERSONNEL, True), Opening("G", "d_g14", 22, 5, "x", PERSONNEL, True),
    Opening("G", "d_g15", 26, 5, "x", PERSONNEL, False, "janitor"),
    Opening("G", "d_g16", 27, 1, "z", PERSONNEL, False, "electrical, from G21"),
    Opening("G", "d_g21", 32, 5, "x", PERSONNEL, True),
    Opening("G", "fx_g13_w", 0, 6, "z", PERSONNEL, True, "push bar, the passage"),
    Opening("G", "fx_g13_e", 36, 6, "z", PERSONNEL, True, "push bar, Tolley St"),
    Opening("G", "roller", 31, 0, "x", 3.0, True, "loading roller door 3.0 x 3.0, alley"),
    Opening("G", "rear_door", 35, 0, "x", PERSONNEL, True, "personnel door N (rear_door variable)"),
    Opening("G", "d_backstage", 13, 7, "x", PERSONNEL, True, "stage backstage door"),
    Opening("G", "o_g20_g13", 27, 7, "x", 2.0, True, "open corridor"),
    # the hall and the east wing
    Opening("G", "fx_hall_n", 0, 8, "z", DOUBLE, True, "fire exit, the passage"),
    Opening("G", "fx_hall_s", 0, 19, "z", DOUBLE, True, "fire exit, the passage"),
    Opening("G", "d_east_bar", 26, 11, "z", PERSONNEL, True, "east bar service door"),
    Opening("G", "d_g23", 28, 10, "z", PERSONNEL, True),
    Opening("G", "d_g22_g25", 34, 14, "x", PERSONNEL, True, "staff stair"),
    Opening("G", "d_g20_g25", 28, 15, "z", PERSONNEL, True),
    Opening("G", "staff_door", 36, 15, "z", PERSONNEL, True, "Tolley St, LOCKPICK from outside, one_way"),
    Opening("G", "d_g24", 32, 17, "x", PERSONNEL, True),
    # the front block
    Opening("G", "d_g3a", 1, 21, "x", PERSONNEL, True), Opening("G", "d_g3b", 4, 21, "x", PERSONNEL, True),
    Opening("G", "dd_hall_w", 13, 21, "x", DOUBLE, True, "curtained hall doors"),
    Opening("G", "dd_hall_e", 19, 21, "x", DOUBLE, True, "curtained hall doors"),
    Opening("G", "d_g20_g26", 27, 21, "x", PERSONNEL, True), Opening("G", "d_g24_g27", 33, 21, "x", PERSONNEL, True),
    Opening("G", "d_g2_g26", 26, 24, "z", PERSONNEL, True), Opening("G", "d_g1_g2", 22, 27, "z", PERSONNEL, True),
    Opening("G", "o_g8", 10, 27, "z", 2.0, True, "the grand stair foot, open to the foyer"),
    Opening("G", "dd_main_w", 15, 28, "x", DOUBLE, True, "entrance, Marlin Ave"),
    Opening("G", "dd_main_e", 18, 28, "x", DOUBLE, True, "entrance, Marlin Ave"),
    # Balcony
    Opening("U", "w_u10_roof", 30, 7, "x", 2.0, False, "count-room window onto the BOH roof (open_window)"),
    Opening("U", "d_u10", 30, 14, "x", PERSONNEL, True), Opening("U", "d_u7", 34, 14, "x", PERSONNEL, True),
    Opening("U", "o_u6_u6b", 27, 16, "x", 2.0, True, "the L corridor"),
    Opening("U", "d_vip_staff", 26, 18, "z", PERSONNEL, True, "VIP staff door, LOCKPICK"),
    Opening("U", "d_office", 28, 18, "z", PERSONNEL, True, "keycard door"),
    Opening("U", "d_u12", 32, 21, "x", PERSONNEL, True, "only from U9"),
    Opening("U", "d_u5", 26, 26, "z", PERSONNEL, True, "security room"),
    Opening("U", "d_u13", 28, 26, "z", PERSONNEL, True),
    Opening("U", "d_u4a", 1, 21, "x", PERSONNEL, True), Opening("U", "d_u4b", 4, 21, "x", PERSONNEL, True),
    Opening("U", "o_u1_u2_w", 13, 21, "x", 3.0, True), Opening("U", "o_u1_u2_e", 19, 21, "x", 3.0, True),
    Opening("U", "rope_gate", 10, 27, "z", PERSONNEL, True, "VIP rope gate, civilian_allowed"),
]

# Vertical connections: stair cores (ground room, upper room).
STAIRS = {"G8": ("G8", "U8", 1.5), "G22": ("G22", "U7", 1.2)}
STAIR_DATA = {"G8": (2, 12, 0.175, 0.28), "G22": (2, 12, 0.175, 0.28)}
# Exterior access of the BOH roof: the drop ladder from the alley (X1) and the count-room window.
LADDER = (30, 0)


def check() -> Report:
    rep = Report("afterhours_floors_ascii --check")
    rooms: Dict[str, Room] = {}
    for key, lv in LEVELS.items():
        rep.section("level %s (FFL %.1f)" % (key, LEVEL_FFL[key]))
        rep.expect(not lv.overlaps, "no overlapping rooms %s" % sorted(lv.overlaps))
        rep.expect(not lv.outside, "no room outside the footprint %s" % sorted(lv.outside))
        missing = [(i, j) for i in range(36) for j in range(28) if (i, j) not in lv.cells]
        rep.expect(not missing, "the rooms tile the 36 x 28 footprint (%d cells uncovered)" % len(missing))
        for rm in lv.rooms:
            rooms[rm.rid] = rm
            if rm.rid in ROOM_SIZES:
                w, d = size(rm.rect)
                want = ROOM_SIZES[rm.rid]
                if sorted((w, d)) != sorted(want):
                    rep.fail("%s is %g x %g, Room list %g x %g" % (rm.rid, w, d, want[0], want[1]))
            if rm.ceiling is not None and rm.purpose in CEIL_BAND:
                lo, hi = CEIL_BAND[rm.purpose]
                if not lo <= rm.ceiling <= hi:
                    rep.fail("%s ceiling %.1f outside the %s band %.1f-%.1f" % (rm.rid, rm.ceiling, rm.purpose, lo, hi))
        rep.ok("room sizes and ceiling bands checked (%d rooms)" % len(lv.rooms))
    rep.section("openings")
    edges: Dict[str, Set[str]] = {}
    doors: Dict[str, int] = {}
    for op in OPENINGS:
        lv = LEVELS[op.level]
        a, b = lv.sides(op)
        if len(a) != 1 or len(b) != 1 or a == b:
            rep.fail("%s %s at (%g, %g): sides %s / %s" % (op.level, op.name, op.x, op.z, sorted(a), sorted(b)))
            continue
        ra, rb = next(iter(a)), next(iter(b))
        link(edges, op.level + ":" + ra if ra != OUT else OUT, op.level + ":" + rb if rb != OUT else OUT)
        for r in (ra, rb):
            doors[r] = doors.get(r, 0) + 1
        if op.route and op.width is not None and op.width < ROUTE_DOOR_MIN:
            rep.fail("%s is %.2f m on a route (< %.1f)" % (op.name, op.width, ROUTE_DOOR_MIN))
    rep.ok("%d openings, each on a wall between two rooms" % len(OPENINGS))
    for g, u, _w in STAIRS.values():
        link(edges, "G:" + g, "U:" + u)
    link(edges, OUT, "U:ROOF")       # the drop ladder from the alley
    link(edges, "U:ROOF", "U:VOID")  # (the void is not walkable: excluded below)
    edges["U:VOID"] = set()
    edges["U:ROOF"].discard("U:VOID")
    for key, lv in LEVELS.items():
        for rm in lv.rooms:
            if rm.purpose in ("stair", "void", "roof"):
                continue
            if doors.get(rm.rid, 0) == 0:
                rep.fail("%s:%s has no door" % (key, rm.rid))
    seen = reach(edges, OUT)
    unreached = ["%s:%s" % (k, rm.rid) for k, lv in LEVELS.items() for rm in lv.rooms
                 if rm.purpose != "void" and "%s:%s" % (k, rm.rid) not in seen]
    rep.expect(not unreached, "every room reachable from the street %s" % unreached)
    rep.section("stairs")
    for name, (fl, ris, riser, tread) in STAIR_DATA.items():
        good, msg = stair_ok(4.2, fl, ris, riser, tread)
        rep.expect(good, "%s: %s" % (name, msg))
    return rep


def draw(key: str) -> str:
    lv = LEVELS[key]
    ids = sorted({r.rid for r in lv.rooms})
    sym = {rid: "abcdefghijklmnopqrstuvwxyz0123456789"[i % 36] for i, rid in enumerate(ids)}
    rows = []
    for j in range(28):
        rows.append("%3d " % j + "".join(sym.get(lv.room_at((i, j)), " ") for i in range(36)))
    legend = "  ".join("%s=%s" % (sym[r], r) for r in ids)
    return "== %s (FFL %.1f)\n%s\n%s" % (key, LEVEL_FFL[key], "\n".join(rows), legend)


if __name__ == "__main__":
    if "--check" in sys.argv:
        r = check()
        print(r.render())
        sys.exit(0 if r.passed else 1)
    for k in LEVELS:
        print(draw(k))
