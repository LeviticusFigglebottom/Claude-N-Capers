# Site plan + checks for docs/design/heists/rolling_thunder.md ("Site", "Play-space closure", "Site plan", "Sightlines",
# "Holdouts", "Police spawns", "Police entry points", "Escape", "Budgets"). Owner: ENV C (RT-C1, paper stage: D-148.2 /
# D-149.10; `--check` only, nothing under game/).
# Run: python3 tools/levelcheck/plans/rolling_thunder_site_ascii.py            (the site plan, 1 char = 2 m)
#      python3 tools/levelcheck/plans/rolling_thunder_site_ascii.py --check    (consistency report, exit 0 / 1)
#
# Site coordinates: origin = the junction centre, +x east, +z south, metres (the doc's convention). Heights: y above the
# street (FFL 0.0). Building footprints match rolling_thunder_floors_ascii.BUILDINGS.
#
# --check: every marker inside the play space; buildings inside it and not overlapping each other or the carriageways;
# the floor-plan offsets agree with the site rectangles; holdouts, escapes, entries and perches sit where the doc says;
# the spawn -> holdout distance table and the >= 15 m spawn rule (L1.4); police spawns behind their closure vehicles;
# the sniper-lane distances; the underpass ramp profile and the height bar; the navmesh polygon early warning (D-149.5).
import math
import os
import sys
from typing import Dict, List, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_floors_ascii as P  # noqa: E402
from rolling_thunder_checklib import Rect, Report, dist, inside, overlap, rect_inside  # noqa: E402

Pt = Tuple[float, float]
PLAY: Rect = (-80, -90, 104, 72)            # "Play space: x -80...104, z -90...72"
OOB_N, OOB_S, OOB_E = -92.0, 72.0, 104.0

# Streets (Site): carriageways, median, sidewalks.
ORCHARD_CW: Rect = (-10, -90, 10, 72)
MEDIAN: Rect = (-1, -90, 1, 72)
ORCHARD_SW: List[Rect] = [(-14, -90, -10, 72), (10, -90, 14, 72)]
TANNERY_CW: Rect = (-80, -8, 104, 8)
TANNERY_SW: List[Rect] = [(-80, -11, 104, -8), (-80, 8, 104, 11)]
SKYWAY: Rect = (-13, -90, 13, 72)           # deck +9.0, soffit +7.6
SKYWAY_DECK_Y = 9.0
PIERS: List[Rect] = [(-1, z - 1.5, 1, z + 1.5) for z in (-72, -40, 30, 62)]
RAMP_X = (34.0, 66.0)                       # 0.0 -> -5.0 over 32 m
UNDERPASS_X = (66.0, 84.0)                  # -5.0, clear 4.6 m (bridge soffit -0.4)
CUT_X = (84.0, 104.0)
UNDERPASS_CLEAR = 4.6
HEIGHT_BAR = (62.0, 4.4)                    # x, clear height
RETAINING_Z = (-11.0, 11.0)

# Buildings and areas (Site).
AREAS: Dict[str, Rect] = {
    "car_park": (16, -50, 52, -14), "site": (-60, -56, -14, -11), "diner": (14, 14, 34, 32),
    "diner_yard": (14, 32, 34, 40), "plaza": (-60, 11, -14, 30), "ashby": (-60, 30, -24, 50),
    "rail_lane": (52, -90, 64, -14),
}
BUILT = ["car_park", "site", "diner", "diner_yard", "ashby"]
DOC_SIZES = {"plaza": (46, 19), "rail_lane": (12, 76)}   # Room list X3, X5
PALISADES_X = (64.0, 86.0)

# Gameplay markers (x, z, y).
HOLDOUTS: Dict[str, Tuple[float, float, str]] = {
    "H1": (35, -32, "car_park"), "H2": (24, 23, "diner"), "H3": (-38, -40, "site"), "H4": (75, 0, "underpass"),
}
POLICE: Dict[str, Tuple[float, float, float]] = {
    "P_N": (6, -86, 0.0), "P_S": (0, 68, 0.0), "P_W": (-78, 0, 0.0), "P_E": (102, 4, -5.0), "P_NE": (60, -76, 0.0),
    "P_SKY": (0, -84, 9.0),
}
# Doc spawn -> holdout table (flat m).
DOC_SPAWN_TABLE: Dict[str, Tuple[int, int, int, int]] = {
    "P_N": (61, 110, 64, 110), "P_S": (106, 51, 115, 101), "P_W": (117, 105, 57, 153), "P_E": (76, 80, 147, 27),
    "P_NE": (51, 105, 104, 78), "P_SKY": (63, 110, 58, 113),
}
MIN_CREW_DISTANCE = 15.0                     # DirectorTweak.min_crew_distance_m (L1.4)
# Closure vehicles (site rect) and the side their spawn must be on ("-z" = further north than the vehicle, etc.).
CLOSURES: Dict[str, Tuple[Rect, str, str]] = {
    "P_N": ((1, -88, 10, -86), "-z", "traffic-management truck, x 1-10; z drawn on the -88 row (no z extent stated)"),
    "P_S": ((-8, 64, 10, 66), "+z", "jack-knifed lorry (was the stalled bus, D-149.6), x -8-10, z 64-66"),
    "P_W": ((-76, -8, -74, 8), "-x", "articulated lorry x -76-74"),
    "P_E": ((98, 0, 102, 8), "+x", "jack-knifed lorry z 0-8, x 98-102"),
}
ESCAPES: Dict[str, Tuple[float, float, float, str]] = {
    "E1": (23, -30, 0.0, "car_park"), "E2": (92, -4, -5.0, "cut"), "E3": (32, -34, 7.0, "car_park"),
}
E3_PAD_LOCAL: Rect = (10, 9, 22, 23)         # roof plan '+' 12 x 14 m
ENTRIES: Dict[str, Tuple[float, float, str]] = {
    "carpark_entrance": (24, -14, "car_park"), "carpark_stairA_door": (16, -46, "car_park"),
    "carpark_fire_door": (52, -35, "car_park"), "site_vehicle_gate": (-14, -43, "site"),
    "site_man_gate": (-14, -16, "site"), "site_tannery_gate": (-33, -11, "site"),
    "diner_yard_gate_w": (14, 36, "diner_yard"), "diner_yard_gate_e": (34, 37, "diner_yard"),
    "rail_gate": (60, -72, "rail_lane"),
}
# Same points from the floor plans (local -> site): building, local x, local z.
ENTRY_LOCAL: Dict[str, Tuple[str, float, float]] = {
    "carpark_entrance": ("CP", 8, 36), "carpark_stairA_door": ("CP", 0, 4), "carpark_fire_door": ("CP", 36, 15),
    "site_vehicle_gate": ("S", 46, 12.5), "site_man_gate": ("S", 46, 40), "site_tannery_gate": ("S", 26.5, 45),
    "diner_yard_gate_w": ("D", 0, 22), "diner_yard_gate_e": ("D", 20, 23),
}
RAPPELS: List[Pt] = [(-13, -26), (13, 20)]
SHIELD_ANCHORS: List[Pt] = [(0, 0), (24, -11), (64, 0), (-33, -8), (24, 11), (-3, -40)]
STORM_DRAIN: Tuple[Pt, Pt] = ((-40, 14), (75, 9))
CONTROLLER: Pt = (-16, -13)
DOC_CONTROLLER_TO_MAN_GATE = 2.0
# Sniper perches (x, z, y) and the doc's distances: (target, point, doc m).
PERCHES: Dict[str, Tuple[float, float, float]] = {
    "S1": (12, -20, 10.1), "S2": (75, -24, 7.5), "S3": (-28, -24, 30.0), "S4": (-30, 36, 15.5),
}
PERCH_DIST: List[Tuple[str, str, Pt, float]] = [
    ("S1", "car park entrance", (24, -14), 13), ("S1", "diner front door", (18.5, 14), 36),
    ("S1", "east T1 (centre)", (27.75, -4), 22), ("S2", "east T3 (centre)", (51, -4), 31),
    ("S2", "forecourt", (43, -12.5), 34), ("S3", "E3", (32, -34), 61), ("S4", "junction", (0, 0), 47),
    ("S3", "H3 (holdout table: 19 m)", (-38, -40), 19),
]
PLAYER_PERCHES: List[Tuple[str, Pt, str, float]] = [
    ("roof centre", (34, -32), "S1", 26), ("roof centre", (34, -32), "S2", 41),
    ("frame NE corner", (-26, -50), "S4", 86), ("frame NE corner", (-26, -50), "S3", 26),
]
TOL_M = 2.0

# Navmesh polygon early warning (D-149.5: report-only). Uncalibrated coefficients (◇): polygons per carved obstacle,
# per room / door, per 100 m2 of open walkable ground, per stair / ramp. OF measured 4,165 polygons (ENV C r254).
POLY_PER_OBSTACLE = 6
POLY_PER_ROOM = 4
POLY_PER_DOOR = 2
POLY_PER_100M2 = 1.5
POLY_PER_STAIR = 8
POLY_WARN = 3500
OBSTACLES = {
    "parked cars (3 decks x 15 + 12 street)": 57, "car-park columns (ground + deck 2)": 40, "frame columns": 25,
    "Skyway piers": 4, "bus shelters, benches, kiosk, clock": 14, "formwork / rebar / pallets": 16,
    "cabins, magazine, crane base, skip, mixer": 8, "closure vehicles": 4, "lamp posts, bins, bollard groups": 30,
    "convoy (active layout pair: 2 x 6 vehicles + mixer)": 13, "underpass abutments / bridge piers": 6,
    "diner furniture (booths, counter, tables)": 20,
}


def _site_of(bld: str, lx: float, lz: float) -> Pt:
    ox, oz = P.BUILDINGS[bld]
    return (lx + ox, lz + oz)


def ramp_y(x: float) -> float:
    if x <= RAMP_X[0]:
        return 0.0
    if x >= RAMP_X[1]:
        return -5.0
    return -5.0 * (x - RAMP_X[0]) / (RAMP_X[1] - RAMP_X[0])


def check_bounds(rep: Report) -> None:
    rep.section("Play space, buildings and streets")
    marks: List[Tuple[str, Pt]] = [(k, (v[0], v[1])) for k, v in HOLDOUTS.items()]
    marks += [(k, (v[0], v[1])) for k, v in POLICE.items()] + [(k, (v[0], v[1])) for k, v in ESCAPES.items()]
    marks += [(k, (v[0], v[1])) for k, v in PERCHES.items()] + [(k, (v[0], v[1])) for k, v in ENTRIES.items()]
    out = [k for k, p in marks if not inside(p, PLAY)]
    rep.expect(not out, "%d markers inside the play space x %g..%g z %g..%g%s"
               % (len(marks), PLAY[0], PLAY[2], PLAY[1], PLAY[3], (": outside " + ", ".join(out)) if out else ""))
    for name in BUILT:
        r = AREAS[name]
        rep.expect(rect_inside(r, PLAY), "%s %s inside the play space" % (name, r))
        for cw in (ORCHARD_CW, TANNERY_CW):
            if overlap(r, cw):
                rep.fail("%s overlaps a carriageway %s" % (name, cw))
    for i, a in enumerate(BUILT):
        for b in BUILT[i + 1:]:
            if overlap(AREAS[a], AREAS[b]):
                rep.fail("%s overlaps %s" % (a, b))
    for name, want in DOC_SIZES.items():
        r = AREAS[name]
        rep.expect((r[2] - r[0], r[3] - r[1]) == want, "%s %g x %g (Room list %g x %g)"
                   % (name, r[2] - r[0], r[3] - r[1], want[0], want[1]))
    for bld, key in (("CP", "car_park"), ("D", "diner"), ("S", "site")):
        lv = {"CP": "CP-G", "D": "DG", "S": "SG"}[bld]
        f = P.LEVELS[lv].foot
        x0, z0 = _site_of(bld, f[0], f[1])
        a = AREAS[key]
        rep.expect((x0, z0) == (a[0], a[1]), "floor-plan origin of %s %s = the site rectangle's NW corner %s"
                   % (lv, (x0, z0), (a[0], a[1])))
    for name, pt in ENTRIES.items():
        if name in ENTRY_LOCAL:
            bld, lx, lz = ENTRY_LOCAL[name]
            s = _site_of(bld, lx, lz)
            rep.expect(dist(s, pt) <= 1.0, "entry %s: the floor plan puts it at %s, the entry table at %s"
                       % (name, s, pt))
    for name, pt in ESCAPES.items():
        if pt[3] == "car_park":
            rep.expect(inside((pt[0], pt[1]), AREAS["car_park"]), "%s inside the car park" % name)
    lx, lz = ESCAPES["E3"][0] - 16, ESCAPES["E3"][1] + 50
    rep.expect(inside((lx, lz), E3_PAD_LOCAL), "E3 heli (local %g, %g) on the 12 x 14 m pad" % (lx, lz))
    rep.expect(CUT_X[0] <= ESCAPES["E2"][0] <= CUT_X[1], "E2 van in the east cut (x %g)" % ESCAPES["E2"][0])
    for name, (x, z, where) in HOLDOUTS.items():
        if where == "underpass":
            good = UNDERPASS_X[0] <= x <= UNDERPASS_X[1] and -8 <= z <= 8
        else:
            good = inside((x, z), AREAS[where])
        rep.expect(good, "holdout %s (%g, %g) inside %s" % (name, x, z, where))
    for p in RAPPELS:
        on_edge = abs(abs(p[0]) - SKYWAY[2]) < 1e-6 and any(inside(p, s) for s in ORCHARD_SW)
        rep.expect(on_edge, "rappel (%g, %g) on the deck edge over a sidewalk (drop %.1f m)" % (p + (SKYWAY_DECK_Y,)))
    for a in SHIELD_ANCHORS:
        rep.expect(inside(a, PLAY), "shield anchor %s in the play space" % (a,))
    d = dist(CONTROLLER, ENTRIES["site_man_gate"][:2])
    if abs(d - DOC_CONTROLLER_TO_MAN_GATE) > 0.5:
        rep.fail("signal controller %s is %.1f m from the man-gate %s; the doc says %.0f m (site notes)"
                 % (CONTROLLER, d, ENTRIES["site_man_gate"][:2], DOC_CONTROLLER_TO_MAN_GATE))
    rep.info("storm drain FLANK %s -> %s: %.0f m as a vent-layer nav link (DB culvert precedent)"
             % (STORM_DRAIN[0], STORM_DRAIN[1], dist(*STORM_DRAIN)))


def check_spawns(rep: Report) -> None:
    rep.section("Police spawns: distances to the holdouts, the 15 m rule, closures")
    names = ["H1", "H2", "H3", "H4"]
    for sp, (x, z, _y) in POLICE.items():
        got = [dist((x, z), HOLDOUTS[h][:2]) for h in names]
        doc = DOC_SPAWN_TABLE[sp]
        off = [(h, g, w) for h, g, w in zip(names, got, doc) if abs(g - w) > TOL_M]
        rep.expect(not off, "%s -> H1..H4 %s m (doc %s)%s" % (sp, [round(g) for g in got], list(doc),
                                                              "" if not off else ": off " + str(off)))
        rep.expect(min(got) >= MIN_CREW_DISTANCE, "%s >= %.0f m from every holdout (min %.0f)"
                   % (sp, MIN_CREW_DISTANCE, min(got)))
    for sp, (r, side, note) in CLOSURES.items():
        x, z, _y = POLICE[sp]
        behind = {"-z": z < r[1], "+z": z > r[3], "-x": x < r[0], "+x": x > r[2]}[side]
        if behind:
            rep.ok("%s (%g, %g) is behind its closure (%s)" % (sp, x, z, note))
        else:
            edge = {"-z": r[1], "+z": r[3], "-x": r[0], "+x": r[2]}[side]
            rep.fail("%s (%g, %g) is not behind its closure (%s): the closure's far face is at %s = %g"
                     % (sp, x, z, note, "z" if "z" in side else "x", edge))
    py = POLICE["P_E"][2]
    rep.expect(abs(py - ramp_y(POLICE["P_E"][0])) < 1e-6, "P_E at y %.1f = the cut level" % py)


def check_lanes(rep: Report) -> None:
    rep.section("Sniper lanes and player perches (doc distances, +- %.0f m)" % TOL_M)
    for perch, what, pt, doc in PERCH_DIST:
        p = PERCHES[perch]
        d = dist((p[0], p[1]), pt)
        rep.expect(abs(d - doc) <= TOL_M, "%s -> %s %.1f m (doc %g)" % (perch, what, d, doc))
    for nm, pt, perch, doc in PLAYER_PERCHES:
        p = PERCHES[perch]
        d = dist(pt, (p[0], p[1]))
        rep.expect(abs(d - doc) <= TOL_M, "player perch %s -> %s %.1f m (doc %g)" % (nm, perch, d, doc))
    s1 = PERCHES["S1"]
    rep.expect(inside((s1[0], s1[1]), SKYWAY) and s1[2] > SKYWAY_DECK_Y, "S1 stands on the Skyway deck")
    s2 = PERCHES["S2"]
    rep.expect(PALISADES_X[0] < s2[0] < PALISADES_X[1], "S2 over the tracks between the palisades")


def check_profile(rep: Report) -> None:
    rep.section("Underpass ramp profile and clearances")
    for x, doc in ((34.5, -0.1), (43.5, -1.5), (46.5, -2.0), (55.5, -3.4), (58.5, -3.8), (63.5, -4.6)):
        rep.expect(abs(ramp_y(x) - doc) <= 0.1, "ramp at x %.1f: y %.2f (doc %.1f)" % (x, ramp_y(x), doc))
    rep.expect(HEIGHT_BAR[1] <= UNDERPASS_CLEAR, "height bar %.1f m <= underpass clear %.1f m"
               % (HEIGHT_BAR[1], UNDERPASS_CLEAR))
    rep.expect(RAMP_X[0] <= HEIGHT_BAR[0] <= UNDERPASS_X[0], "height bar at x %.0f on the ramp, before the bridge"
               % HEIGHT_BAR[0])
    for name, r in AREAS.items():
        if name in BUILT and overlap(r, (RAMP_X[0], RETAINING_Z[0], CUT_X[1], RETAINING_Z[1])):
            rep.fail("%s overlaps the trench between the retaining walls" % name)
    gap = AREAS["car_park"][0] - ORCHARD_SW[1][2]
    rep.warn("car park west barrier is %.1f m beyond the Orchard sidewalk edge: a HEAVY bag (2 m throw, D-102) from "
             "the sidewalk may not clear it (RT plan §7.5: test at 3 pitches)" % gap)


def polygon_estimate() -> Tuple[int, Dict[str, float]]:
    rooms = sum(len(lv.rooms) + (1 if lv.fill else 0) for lv in P.LEVELS.values())
    doors = len(P.OPENINGS)
    stairs = len(P.STAIRS) + len(P.RAMPS) + 2
    open_m2 = (PLAY[2] - PLAY[0]) * (PLAY[3] - PLAY[1])
    for name in BUILT:
        r = AREAS[name]
        open_m2 -= (r[2] - r[0]) * (r[3] - r[1])
    open_m2 -= (PALISADES_X[1] - PALISADES_X[0]) * (PLAY[3] - PLAY[1])   # the tracks: not walkable
    parts = {
        "obstacles": POLY_PER_OBSTACLE * sum(OBSTACLES.values()), "rooms": POLY_PER_ROOM * rooms,
        "doors": POLY_PER_DOOR * doors, "open ground": POLY_PER_100M2 * open_m2 / 100.0,
        "stairs / ramps": POLY_PER_STAIR * stairs,
    }
    return int(math.ceil(sum(parts.values()))), parts


def check_polygons(rep: Report) -> None:
    rep.section("Navmesh polygon early warning (D-149.5: report-only; uncalibrated estimate)")
    tot, parts = polygon_estimate()
    rep.info("estimate %d polygons: %s" % (tot, ", ".join("%s %d" % (k, v) for k, v in parts.items())))
    if tot > POLY_WARN:
        rep.warn("estimate %d > %d (NavPath is uncapped on trunk; measure at G1)" % (tot, POLY_WARN))
    else:
        rep.ok("estimate %d <= %d (measure the real bake at G1)" % (tot, POLY_WARN))


def check() -> Report:
    rep = Report("rolling_thunder_site_ascii --check")
    check_bounds(rep)
    check_spawns(rep)
    check_lanes(rep)
    check_profile(rep)
    check_polygons(rep)
    return rep


def plan() -> str:
    step = 2.0
    w = int((PLAY[2] - PLAY[0]) / step) + 1
    h = int((PLAY[3] - PLAY[1]) / step) + 1
    g = [[" "] * w for _ in range(h)]

    def fill(r: Rect, ch: str) -> None:
        for j in range(h):
            for i in range(w):
                x, z = PLAY[0] + i * step, PLAY[1] + j * step
                if r[0] <= x < r[2] and r[1] <= z < r[3]:
                    g[j][i] = ch

    def put(x: float, z: float, s: str) -> None:
        i, j = int(round((x - PLAY[0]) / step)), int(round((z - PLAY[1]) / step))
        for n, ch in enumerate(s):
            if 0 <= j < h and 0 <= i + n < w:
                g[j][i + n] = ch

    for r in ORCHARD_SW + TANNERY_SW:
        fill(r, ".")
    fill((RAMP_X[0], -11, CUT_X[1], 11), "~")
    fill((PALISADES_X[0], PLAY[1], PALISADES_X[1], PLAY[3]), "H")
    for name in ("car_park", "diner", "diner_yard"):
        fill(AREAS[name], "#")
    fill(AREAS["site"], "|")
    fill(AREAS["ashby"], "%")
    for p in PIERS:
        fill(p, "O")
    for r, _s, _n in CLOSURES.values():
        fill(r, "K")
    for k, v in HOLDOUTS.items():
        put(v[0], v[1], k)
    for k, v in POLICE.items():
        put(v[0], v[1], k.replace("P_", "P"))
    for k, v in ESCAPES.items():
        put(v[0], v[1], k)
    for k, v in PERCHES.items():
        put(v[0], v[1], k)
    lines = ["      x " + "".join("%-10d" % (PLAY[0] + i * step) for i in range(0, w, 5))]
    for j, row in enumerate(g):
        z = PLAY[1] + j * step
        lines.append(("%5d " % z if j % 2 == 0 else "      ") + "".join(row).rstrip())
    lines.append(". sidewalk  ~ ramp / underpass / cut  H rail bank  # car park, diner  | Tanner's Reach  % Ashby  "
                 "O piers  K closures  H1-H4 holdouts  P* police spawns  E1-E3 escapes  S1-S4 perches")
    return "\n".join(lines)


if __name__ == "__main__":
    if "--check" in sys.argv:
        r = check()
        print(r.render())
        sys.exit(0 if r.passed else 1)
    print(plan())
