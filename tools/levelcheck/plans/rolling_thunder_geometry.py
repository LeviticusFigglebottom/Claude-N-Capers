# Rolling Thunder: the G1 greybox shell and site as primitives (walls with holes, glass, slabs with holes, ceilings,
# the car-park ramps and guards, the stair cores, the scaffold tower, the frame, the site, the streets, the trench, the
# Skyway, closures and neighbour massing) computed from the --check plan data, for rolling_thunder_emit_layout.py.
# Owner: ENV C (RT-C1). Copy-adapted from ostrander_federal_geometry.py (D-147: reuse first; not shared code).
# Coordinates: SITE (origin = the junction centre, +x east, +z south, metres); the floor plans are local and are
# moved by
# rolling_thunder_floors_ascii.BUILDINGS. Heights are absolute (FFL Underpass -5.0, Street 0.0, Upper 3.5, Roof 7.0).
# Boxes are [group, name, [x0, y0, z0], [x1, y1, z1], surface class]; hulls [group, name, [points], class]; flights are
# OF's flight() rows [name, origin (first riser line), yaw, width, risers, riser, tread].
#
# G1 fixes to the plan data (reported to the LEAD; the doc drawings follow at the RT-C1 doc pass):
# * the diner stair SC's doors (ground r_sc, upper uc_sc) move from the core's middle (5, 15) to its south end (5, 17):
#   a U-stair's floor landing is at one end, so a mid-length door would open onto a flight (DB/OF rule: doors on the
#   level landing only). OPENINGS_G1 below replaces those two rows.
# * route doors drawn 1.0 m are built with the 1.2 m service kit (leaf 1.1 m, as OF's route doors), the 0.9 m non-route
#   doors with the 1.0 m single kit (leaf 0.9), the 1.8 m doubles with the 2.0 m double kit.
import math
import os
import sys
from typing import List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_floors_ascii as P  # noqa: E402
import rolling_thunder_site_ascii as ST  # noqa: E402
from rolling_thunder_checklib import Opening  # noqa: E402

FFL = {"U": -5.0, "S": 0.0, "P": 3.5, "R": 7.0}  # plan floor keys of floor_heights
LEVEL_FFL = P.LEVEL_FFL
EXT_T, INT_T, CORE_T, LIFT_T, HOARD_T, GUARD_T, PARAPET_T = 0.4, 0.2, 0.3, 0.2, 0.2, 0.2, 0.3
PARAPET = 1.1
GUARD = 1.1
COPING_RISE = 0.3  # a ridge over the 0.3 m parapet (OF §7.5 copings: >= 50 deg)
DOOR_HEAD = 2.2
CEIL_T = 0.05
GRADE_T = 0.3
# Car park (local): decks 0.8 thick (0.3 slab + 0.5 downstand beams as one greybox body: the 2.7 m clear, QC-87).
CP_DECK = [(3.5, 0.8), (7.0, 0.8)]
CP_HH_TOP = 9.7  # head-house ceiling (2.7 m clear over the roof)
CP_STRIP = P.STRIP
DINER_SLAB = 0.3
DINER_ROOF = 7.0
CABIN_TOP = 2.65  # cabin ceiling (Room list 2.6)
SITE_SLAB = (3.2, 3.5)  # the frame's first-floor slab (FG 3.2 m clear)
HOARDING_H = 2.4
YARD_WALL_H = 2.4
PALISADE_H = 1.8
RAIL_Y = 1.2
TRENCH_Y = -5.0
SKY_DECK = (7.6, 9.0)
BRIDGE_SOFFIT = -0.4

# --- the plan's openings, with the G1 fixes (see the header) ------------------------------------------------------
_MOVED = {("DG", "r_sc"): (5, 17), ("DU", "uc_sc"): (5, 17)}
OPENINGS_G1: List[Opening] = []
for _o in P.OPENINGS:
    _k = (_o.level, _o.name)
    if _k in _MOVED:
        _o = Opening(
            _o.level,
            _o.name,
            _MOVED[_k][0],
            _MOVED[_k][1],
            _o.along,
            _o.width,
            _o.route,
            _o.note + " (G1: moved to the core's south end)",
        )
    OPENINGS_G1.append(_o)


def r3(v: float) -> float:
    return round(float(v) + 0.0, 3)


def box(group: str, name: str, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, cls: str) -> list:
    return [
        group,
        name,
        [r3(min(x0, x1)), r3(min(y0, y1)), r3(min(z0, z1))],
        [r3(max(x0, x1)), r3(max(y0, y1)), r3(max(z0, z1))],
        cls,
    ]


def off(level: str) -> Tuple[float, float]:
    return P.BUILDINGS[P.LEVEL_BUILDING[level]]


# --- door kits (OF: hole half width, leaf width, kind) ------------------------------------------------------------
def kit(width: Optional[float], route: bool) -> Optional[Tuple[str, float, float]]:
    """(kind, hole half width, leaf width) for a plan opening width; None = open (no door)."""
    if width is None or (width <= 0.95 and not route):
        return ("single", 0.5, 0.9)
    if width <= 1.25:
        return ("service", 0.6, 1.1)
    if width <= 1.85:
        return ("double", 1.0, 1.8)
    return None


def site_pt(level: str, lx: float, lz: float) -> Tuple[float, float]:
    ox, oz = off(level)
    return (lx + ox, lz + oz)


# --------------------------------------------------------------------------------------------- walls from cells
OUTSIDE_ROOMS = ("YD", "X4", "OUT")


def _cell_room(lv: P.Level, i: int, j: int) -> str:
    return lv.cells.get((i, j), "OUT")


def _unit_edges(key: str) -> List[Tuple[str, int, int, str, str]]:
    """Unit wall edges of a level: (axis, fixed, a, side0 room, side1 room); axis "x" = a wall at z = fixed spanning
    x a..a+1 (side0 north, side1 south), "z" = a wall at x = fixed spanning z a..a+1 (side0 west, side1 east)."""
    lv = P.LEVELS[key]
    x0, z0, x1, z1 = (int(v) for v in lv.foot)
    out = []
    for j in range(z0, z1 + 1):
        for i in range(x0, x1):
            a, b = _cell_room(lv, i, j - 1), _cell_room(lv, i, j)
            if a != b:
                out.append(("x", j, i, a, b))
    for i in range(x0, x1 + 1):
        for j in range(z0, z1):
            a, b = _cell_room(lv, i - 1, j), _cell_room(lv, i, j)
            if a != b:
                out.append(("z", i, j, a, b))
    return out


def _diner_kind(key: str, s0: str, s1: str) -> Optional[Tuple[float, float, float, str]]:
    """(t, y0, y1, class) of a diner wall edge, or None."""
    y = LEVEL_FFL[key]
    o0, o1 = s0 in OUTSIDE_ROOMS, s1 in OUTSIDE_ROOMS
    if o0 and o1:
        if "YD" in (s0, s1):  # the yard wall
            return (INT_T, 0.0, YARD_WALL_H, "wall_ext")
        return None
    if o0 or o1:
        if key == "DU":
            return (EXT_T, 3.5, DINER_ROOF + PARAPET, "wall_ext")
        return (EXT_T, 0.0, 3.5, "wall_ext")
    top = (3.5 if key == "DG" else DINER_ROOF) - DINER_SLAB
    return (INT_T, y, top, "wall")


def _cabin_kind(s0: str, s1: str) -> Optional[Tuple[float, float, float, str]]:
    cab = [s for s in (s0, s1) if s.startswith("C") and len(s) == 2]
    if not cab:
        return None
    return (INT_T, 0.0, CABIN_TOP + 0.25, "wall_ext")


def _merge(rows: List[list]) -> List[list]:
    rows.sort(key=lambda r: (r[0], r[1], r[2]))
    out: List[list] = []
    for r in rows:
        if (
            out
            and out[-1][0] == r[0]
            and out[-1][1] == r[1]
            and abs(out[-1][3] - r[2]) < 1e-6
            and out[-1][4:] == r[4:]
        ):
            out[-1][3] = r[3]
        else:
            out.append(list(r))
    return out


def derived_walls(key: str) -> List[list]:
    """Merged runs [axis, fixed, a0, a1, t, y0, y1, class] in LOCAL coordinates for the diner / cabins."""
    rows = []
    for axis, fixed, a, s0, s1 in _unit_edges(key):
        if key in ("DG", "DU"):
            k = _diner_kind(key, s0, s1)
        elif key == "SG":
            k = _cabin_kind(s0, s1)
        else:
            k = None
        if k is None:
            continue
        rows.append([axis, float(fixed), float(a), float(a + 1), k[0], k[1], k[2], k[3]])
    return _merge(rows)


# --------------------------------------------------------------------------------------------- the car park walls
def carpark_walls() -> List[list]:
    """[level, axis, fixed, a0, a1, t, y0, y1, class] LOCAL, hand-drawn from the three car-park plans."""
    hh = CP_HH_TOP
    top0 = 3.5 - CP_DECK[0][1]  # deck 2 underside 2.7
    w = []
    # stair A core (0..3 x 0..6) and the lift (3..6 x 0..3): full height to the head houses
    w += [
        ["CP-G", "z", 0.0, 0.0, 6.0, CORE_T, 0.0, hh, "wall_ext"],
        ["CP-G", "x", 0.0, 0.0, 3.0, CORE_T, 0.0, hh, "wall_ext"],
        ["CP-G", "x", 0.0, 3.0, 6.0, LIFT_T, 0.0, hh, "wall_ext"],
        ["CP-G", "z", 3.0, 0.0, 6.0, CORE_T, 0.0, hh, "wall"],
        ["CP-G", "x", 6.0, 0.0, 3.0, CORE_T, 0.0, hh, "wall"],
        ["CP-G", "z", 6.0, 0.0, 3.0, LIFT_T, 0.0, hh, "wall"],
        ["CP-G", "x", 3.0, 3.0, 6.0, LIFT_T, 0.0, hh, "wall"],
    ]
    # stair B core (33..36 x 30..36)
    w += [
        ["CP-G", "z", 33.0, 30.0, 36.0, CORE_T, 0.0, hh, "wall"],
        ["CP-G", "x", 30.0, 33.0, 36.0, CORE_T, 0.0, hh, "wall"],
        ["CP-G", "x", 36.0, 33.0, 36.0, CORE_T, 0.0, hh, "wall_ext"],
        ["CP-G", "z", 36.0, 30.0, 36.0, EXT_T, 0.0, hh, "wall_ext"],
    ]
    # the east fire wall (rail side), the roof parapet included
    w += [["CP-G", "z", 36.0, 0.0, 30.0, EXT_T, 0.0, 7.0 + PARAPET, "wall_ext"]]
    # ground: booth AB, WC CWC, plant CPL, the south facade piers either side of the entrance
    w += [
        ["CP-G", "x", 30.0, 0.0, 5.0, INT_T, 0.0, top0, "wall_ext"],
        ["CP-G", "z", 0.0, 30.0, 36.0, INT_T, 0.0, top0, "wall_ext"],
        ["CP-G", "z", 5.0, 30.0, 36.0, INT_T, 0.0, top0, "wall"],
        ["CP-G", "x", 36.0, 0.0, 6.0, INT_T, 0.0, top0, "wall_ext"],
        ["CP-G", "z", 11.0, 32.0, 36.0, INT_T, 0.0, top0, "wall"],
        ["CP-G", "x", 32.0, 11.0, 14.0, INT_T, 0.0, top0, "wall"],
        ["CP-G", "z", 14.0, 30.0, 36.0, INT_T, 0.0, top0, "wall"],
        ["CP-G", "x", 30.0, 14.0, 21.0, INT_T, 0.0, top0, "wall"],
        ["CP-G", "z", 21.0, 30.0, 36.0, INT_T, 0.0, top0, "wall"],
        ["CP-G", "x", 36.0, 10.0, 21.0, INT_T, 0.0, top0, "wall_ext"],
    ]
    return w


def carpark_guards() -> List[list]:
    """The 1.1 m guards (barriers with a handrail top, `r`) and the roof parapet (`p`), LOCAL boxes
    [name, x0, y0, z0, x1, y1, z1, class]."""
    g = []
    t = GUARD_T
    for i, (y, nm) in enumerate([(0.0, "G"), (3.5, "2"), (7.0, "R")]):
        h = PARAPET if nm == "R" else GUARD
        th = PARAPET_T if nm == "R" else t
        cls = "wall_ext" if nm == "R" else "rail"
        # north facade x 6..35.8 (the fire wall's inner face), west facade z 6..30 (ground) / 6..36 (deck 2, roof)
        g.append(["Facade%sN" % nm, 6.15, y, 0.0, 35.8, y + h, th, cls])
        zw1 = 30.0 if nm == "G" else 35.8
        g.append(["Facade%sW" % nm, 0.0, y, 6.15, th, y + h, zw1, cls])
        # south facade: ground x 21.1..32.85, deck 2 / roof x 0..32.85
        xs0 = 21.1 if nm == "G" else 0.0
        g.append(["Facade%sS" % nm, xs0, y, 36.0 - th, 32.85, y + h, 36.0, cls])
    # the ramp strip edges on deck 2 and the roof (x 27 / 33, z 6..30) and the roof's z 30 edge over R2's foot
    for y, nm in [(7.0, "R")]:
        g.append(["Strip%sW" % nm, CP_STRIP[0] - t, y, CP_STRIP[1], CP_STRIP[0], y + GUARD, CP_STRIP[3], "rail"])
        g.append(["Strip%sE" % nm, CP_STRIP[2], y, CP_STRIP[1], CP_STRIP[2] + t, y + GUARD, CP_STRIP[3], "rail"])
    g.append(["StripRS", CP_STRIP[0] - t, 7.0, CP_STRIP[3], CP_STRIP[2] + t, 7.0 + GUARD, CP_STRIP[3] + t, "rail"])
    return g


RIDGE_RISE = round(0.1 * math.tan(math.radians(55.0)), 3)  # a 0.2 m guard's ridge (world/kits/ridge_top.gd, 55 deg)


def _r1(z: float) -> float:
    return 3.5 * (CP_STRIP[3] - z) / (CP_STRIP[3] - CP_STRIP[1])


def _guard_segments(base, top, cuts: List[float], ceil: Optional[float]) -> List[Tuple[float, float, bool]]:
    """[(z_a, z_b, closed)] pieces of a guard over the strip (z 30 -> 6): a piece is `closed` where the guard's 1.1 m
    top would leave a 0.0-0.3 m slit under the ceiling `ceil` (seam_gaps, PO-7): there the guard is built up to it."""
    out = []
    zs = [CP_STRIP[3]] + cuts + [CP_STRIP[1]]
    for a, b in zip(zs, zs[1:]):
        zm = (a + b) / 2.0
        t = top(zm)
        closed = ceil is not None and ceil - 0.3 < t < ceil
        out.append((a, b, closed))
    return out


def _z_at_top(t: float, base0: float) -> float:
    """z on the strip where base0 + _r1(z) + GUARD == t."""
    return CP_STRIP[3] - (t - GUARD - base0) * (CP_STRIP[3] - CP_STRIP[1]) / 3.5


def ramps_cp() -> List[list]:
    """R1 (a wedge: 0.0 at z 30 -> 3.5 at z 6) and R2 (a 0.3 m slab: 3.5 -> 7.0 over R1), their side guards (ridged
    1.1 m tops, closed to the deck above where a slit would be left) and the deck-2 strip-edge guards: LOCAL hull rows
    [name, points, class]."""
    x0, z0, x1, z1 = CP_STRIP
    out = []
    out.append(
        [
            "RampR1",
            [[x0, 0.0, z1], [x1, 0.0, z1], [x0, 0.0, z0], [x1, 0.0, z0], [x0, 3.5, z0], [x1, 3.5, z0]],
            "floor",
        ]
    )
    out.append(
        [
            "RampR2",
            [
                [x0, 3.5, z1],
                [x1, 3.5, z1],
                [x0, 7.0, z0],
                [x1, 7.0, z0],
                [x0, 3.2, z1],
                [x1, 3.2, z1],
                [x0, 6.7, z0],
                [x1, 6.7, z0],
            ],
            "floor",
        ]
    )
    for nm, b0, ceil in [("R1", 0.0, 3.5 - CP_DECK[0][1]), ("R2", 3.5, 7.0 - CP_DECK[1][1])]:
        cuts = [r3(_z_at_top(ceil - 0.3, b0)), r3(_z_at_top(ceil, b0))]
        segs = _guard_segments(lambda z, b0=b0: b0 + _r1(z), lambda z, b0=b0: b0 + _r1(z) + GUARD, cuts, ceil)
        for side, (a, b) in [("W", (x0, x0 + GUARD_T)), ("E", (x1 - GUARD_T, x1))]:
            xm = (a + b) / 2.0
            for k, (za, zb, closed) in enumerate(segs):
                pts = []
                for z in (za, zb):
                    yb = r3(b0 + _r1(z))
                    if closed:
                        pts += [[a, yb, z], [b, yb, z], [a, ceil, z], [b, ceil, z]]
                    else:
                        yt = r3(yb + GUARD)
                        pts += [
                            [a, yb, z],
                            [b, yb, z],
                            [a, r3(yt - RIDGE_RISE), z],
                            [b, r3(yt - RIDGE_RISE), z],
                            [xm, yt, z],
                        ]
                out.append(["Ramp%sGuard%s%d" % (nm, side, k), pts, "rail"])
    # the deck-2 strip-edge guards (x 27 / 33, 3.5 + 1.1): built up to R2's underside where it passes 0-0.3 m over them
    und = lambda z: 3.2 + _r1(z)  # noqa: E731
    za = r3(z1 - (4.9 - 3.2) * (z1 - z0) / 3.5)
    zb = r3(z1 - (4.6 - 3.2) * (z1 - z0) / 3.5)
    for side, (a, b) in [("W", (x0 - GUARD_T, x0)), ("E", (x1, x1 + GUARD_T))]:
        xm = (a + b) / 2.0
        for k, (p, q, closed) in enumerate([(z0, za, False), (za, zb, True), (zb, z1, False)]):
            pts = []
            for z in (p, q):
                if closed:
                    pts += [[a, 3.5, z], [b, 3.5, z], [a, r3(und(z)), z], [b, r3(und(z)), z]]
                else:
                    pts += [
                        [a, 3.5, z],
                        [b, 3.5, z],
                        [a, r3(3.5 + GUARD - RIDGE_RISE), z],
                        [b, r3(3.5 + GUARD - RIDGE_RISE), z],
                        [xm, 3.5 + GUARD, z],
                    ]
            out.append(["Strip2Guard%s%d" % (side, k), pts, "rail"])
    return out


# --------------------------------------------------------------------------------------------- holes (doors, windows)
def _opening_hole(o: Opening) -> Optional[list]:
    """[level, axis, fixed, a0, a1, y0, y1] LOCAL for a plan opening (doors: the kit's hole; wide gates and the open
    entrances: their full span)."""
    y = LEVEL_FFL[o.level]
    # plan "along x" = a wall at constant z (our axis "x"); "along z" = a wall at constant x (our axis "z")
    axis, fixed, c = ("x", o.z, o.x) if o.along == "x" else ("z", o.x, o.z)
    k = kit(o.width, o.route)
    if k is None:
        hw = (o.width or 1.0) / 2.0
        head = 3.0 if o.name == "entrance" else (DOOR_HEAD if o.name == "stw_foot" else 2.6)
        return [o.level, axis, float(fixed), r3(c - hw), r3(c + hw), y, r3(y + head)]
    return [o.level, axis, float(fixed), r3(c - k[1]), r3(c + k[1]), y, r3(y + DOOR_HEAD)]


# Windows: breakable WindowPrefabs (the diner shopfronts are police ENTRY bays, doc; D-142: clear except the cabins'
# frosted glass), placed like a door: pivot bottom-centre of the opening on the wall line (the sill), front -Z the
# street side at ground and the room side upstairs (the UsePoint must stand on the navmesh). LOCAL rows [name, level,
# axis, fixed, centre, sill, visual, front, see_through]; the hole is the visual's opening (WINDOW_SIZES), so the frame
# laps the wall like the door kits.
WINDOW_SIZES = {"prop_window_shop_w300_h240": (3.0, 2.4), "prop_window_w100_h120": (1.0, 1.2),
                "prop_window_w100_h60_frosted": (1.0, 0.6)}
SHOP = "prop_window_shop_w300_h240"
WINDOW_ROWS: List[list] = [
    ["BoothWindowN", "CP-G", "x", 30.0, 2.5, 0.9, "prop_window_w100_h120", "N", True],
    ["BoothWindowW", "CP-G", "z", 0.0, 32.5, 0.9, "prop_window_w100_h120", "W", True],
    ["DinerShopN1", "DG", "x", 0.0, 1.8, 0.8, SHOP, "N", True],
    ["DinerShopN2", "DG", "x", 0.0, 7.5, 0.8, SHOP, "N", True],
    ["DinerShopN3", "DG", "x", 0.0, 10.7, 0.8, SHOP, "N", True],
    ["KitchenWindowN", "DG", "x", 0.0, 16.0, 0.9, "prop_window_w100_h120", "N", True],
    ["DinerShopW1", "DG", "z", 0.0, 3.0, 0.8, SHOP, "W", True],
    ["DinerShopW2", "DG", "z", 0.0, 10.3, 0.8, SHOP, "W", True],
    ["FunctionShopN1", "DU", "x", 0.0, 1.8, 4.3, SHOP, "S", True],
    ["FunctionShopN2", "DU", "x", 0.0, 7.5, 4.3, SHOP, "S", True],
    ["FunctionShopN3", "DU", "x", 0.0, 10.7, 4.3, SHOP, "S", True],
    ["UpperStoreWindowN1", "DU", "x", 0.0, 16.0, 4.4, "prop_window_w100_h120", "S", True],
    ["UpperStoreWindowN2", "DU", "x", 0.0, 17.2, 4.4, "prop_window_w100_h120", "S", True],
    ["FunctionShopW1", "DU", "z", 0.0, 3.0, 4.3, SHOP, "E", True],
    ["FunctionShopW2", "DU", "z", 0.0, 9.0, 4.3, SHOP, "E", True],
    ["CabinC1Window", "SG", "x", 30.0, 3.5, 1.2, "prop_window_w100_h60_frosted", "N", False],
    ["CabinC2Window", "SG", "x", 30.0, 6.5, 1.2, "prop_window_w100_h60_frosted", "N", False],
]
WINDOWS: List[list] = []   # [level, axis, fixed, a0, a1, sill, head] holes (from WINDOW_ROWS)
for _w in WINDOW_ROWS:
    _ww, _wh = WINDOW_SIZES[_w[6]]
    WINDOWS.append([_w[1], _w[2], _w[3], r3(_w[4] - _ww / 2), r3(_w[4] + _ww / 2), _w[5], r3(_w[5] + _wh)])


def window_prefabs() -> List[list]:
    """[name, site pivot [x, y, z] (sill bottom-centre on the wall line), yaw, visual, see_through]."""
    yaw = {"N": 0.0, "W": 90.0, "S": 180.0, "E": -90.0}
    out = []
    for nm, lvl, axis, fixed, c, sill, vis, front, clear in WINDOW_ROWS:
        ox, oz = off(lvl)
        pos = [r3(c + ox), sill, r3(fixed + oz)] if axis == "x" else [r3(fixed + ox), sill, r3(c + oz)]
        out.append([nm, pos, yaw[front], vis, clear])
    return out


def holes_local() -> List[list]:
    out = []
    for o in OPENINGS_G1:
        if o.name in ("vehicle_gate", "tannery_gate"):
            c = o.z if o.along == "z" else o.x
            axis, fixed = ("z", o.x) if o.along == "z" else ("x", o.z)
            for d in (-1.2, 1.2):  # two 2.0 m double gates either side of a 0.4 m post
                out.append([o.level, axis, float(fixed), r3(c + d - 1.0), r3(c + d + 1.0), 0.0, DOOR_HEAD])
            continue
        h = _opening_hole(o)
        if h is not None:
            out.append(h)
    for wnd in WINDOWS:
        out.append(list(wnd))
    return out


def _to_site(level: str, axis: str, fixed: float, a0: float, a1: float) -> Tuple[float, float, float]:
    ox, oz = off(level)
    if axis == "x":  # a wall at z = fixed along x
        return fixed + oz, a0 + ox, a1 + ox
    return fixed + ox, a0 + oz, a1 + oz


def walls() -> List[list]:
    """[floor key, axis, fixed, a0, a1, t, y0, y1, class, holes [[a0, a1, y0, y1]]] in SITE coordinates."""
    raw: List[Tuple[str, list]] = []
    for w in carpark_walls():
        raw.append((w[0], w[1:]))
    for key in ("DG", "DU", "SG"):
        for w in derived_walls(key):
            raw.append((key, w))
    hs = []
    for h in holes_local():
        f, a0, a1 = _to_site(h[0], h[1], h[2], h[3], h[4])
        hs.append([h[1], f, a0, a1, h[5], h[6]])
    out = []
    for level, w in raw:
        axis, fixed, a0, a1, t, y0, y1, cls = w
        f, s0, s1 = _to_site(level, axis, fixed, a0, a1)
        hh = [
            [h[2], h[3], h[4], h[5]]
            for h in hs
            if h[0] == axis
            and abs(h[1] - f) < 1e-6
            and h[3] > s0 + 1e-6
            and h[2] < s1 - 1e-6
            and h[5] > y0 + 1e-6
            and h[4] < y1 - 1e-6
        ]
        out.append([P.LEVEL_BUILDING[level], axis, r3(f), r3(s0), r3(s1), t, r3(y0), r3(y1), cls, hh])
    return out


def panes() -> List[list]:
    """Static glass panes [name, mn, mx]: none at G1 since every window is a WindowPrefab (its GlassBody glazes it)."""
    return []


# --------------------------------------------------------------------------------------------- slabs and ceilings
def _lrect(level: str, r: tuple) -> list:
    ox, oz = off(level)
    return [r3(r[0] + ox), r3(r[1] + oz), r3(r[2] + ox), r3(r[3] + oz)]


STA_WELL = (0.15, 0.15, 2.85, 4.4)  # stair A: floor landing z 4.4..5.85 (south), flights north
SB_WELL = (33.15, 31.6, 35.85, 35.85)  # stair B: floor landing z 30.15..31.6 (north), flights south
SC_WELL = (5.1, 12.1, 7.9, 16.4)  # diner SC (G1: landing south, door at z 17)


def slabs() -> List[list]:
    """[name, outer [x0, z0, x1, z1], holes, y0, y1, class] SITE."""
    out = []
    lf = (3.0, 0.0, 6.0, 3.0)
    sta = (0.0, 0.0, 3.0, 6.0)
    sb = (33.0, 30.0, 36.0, 36.0)
    for (y, t), nm in zip(CP_DECK, ["Deck2", "Roof"]):
        holes = [_lrect("CP-G", sta), _lrect("CP-G", lf), _lrect("CP-G", sb), _lrect("CP-G", CP_STRIP)]
        out.append(["CP" + nm, _lrect("CP-G", (0.0, 0.0, 35.8, 36.0)), holes, r3(y - t), y, "floor"])
        # the core landings (stair A south, stair B north) at the deck / roof level
        out.append(["CP%sLandingA" % nm, _lrect("CP-G", (0.15, 4.4, 2.85, 5.85)), [], r3(y - 0.3), y, "stair"])
        out.append(["CP%sLandingB" % nm, _lrect("CP-G", (33.15, 30.15, 35.85, 31.6)), [], r3(y - 0.3), y, "stair"])
    out.append(
        [
            "CPRoofHHA",
            _lrect("CP-G", (-0.15, -0.15, 6.15, 6.15)),
            [_lrect("CP-G", (3.0, 3.0, 6.15, 6.15))],
            CP_HH_TOP,
            CP_HH_TOP + 0.3,
            "roof",
        ]
    )
    out.append(["CPRoofHHB", _lrect("CP-G", (32.85, 29.85, 36.2, 36.2)), [], CP_HH_TOP, CP_HH_TOP + 0.3, "roof"])
    # diner: the upper floor (SC well) and the roof, inside the 0.4 m facades
    out.append(["DinerUpper", _lrect("DG", (0.2, 0.2, 19.8, 17.8)), [_lrect("DG", SC_WELL)], 3.2, 3.5, "floor"])
    out.append(["DinerRoof", _lrect("DG", (0.2, 0.2, 19.8, 17.8)), [], 6.7, 7.0, "roof"])
    # the site: cabin roof, the frame slab
    out.append(["CabinRoof", _lrect("SG", (1.9, 29.9, 14.1, 39.1)), [], CABIN_TOP, CABIN_TOP + 0.2, "roof"])
    out.append(["FrameSlab", _lrect("SG", (10.0, 6.0, 34.0, 26.0)), [], SITE_SLAB[0], SITE_SLAB[1], "floor"])
    return out


CEIL_ROOMS = {
    "DR": 3.0,
    "K": 2.8,
    "BC": 2.8,
    "E": 2.8,
    "ST": 2.8,
    "W1": 2.8,
    "W2": 2.8,
    "R": 2.8,
    "OF": 2.8,
    "U1": 3.0,
    "U2": 2.8,
    "U3": 2.8,
    "U4": 2.8,
    "J": 2.8,
    "UC": 2.8,
    "U5": 2.8,
}


def ceilings() -> List[list]:
    out = []
    for key in ("DG", "DU"):
        for rm in P.LEVELS[key].rooms:
            ce = CEIL_ROOMS.get(rm.rid)
            if ce is None:
                continue
            r = _lrect(key, rm.rect)
            out.append(["Ceil%s_%d" % (rm.rid, int(rm.rect[0] * 10 + rm.rect[1])), r, r3(LEVEL_FFL[key] + ce)])
    return out


# --------------------------------------------------------------------------------------------- stairs
CORE_STOREYS = {"STA": [(0.0, 3.5), (3.5, 7.0)], "SB": [(0.0, 3.5), (3.5, 7.0)], "SC": [(0.0, 3.5)]}
CORES = {
    # core: (level, local rect, landing end ("S" = floor landing south, flights run north), first flight side)
    "STA": ("CP-G", (0.0, 0.0, 3.0, 6.0), "S", "E", 4.4),
    "SB": ("CP-G", (33.0, 30.0, 36.0, 36.0), "N", "E", 31.6),
    "SC": ("DG", (5.0, 12.0, 8.0, 18.0), "S", "E", 16.4),
}
RISERS, RISER, TREAD = 10, 0.175, 0.28


def stairs() -> Tuple[List[list], List[list], List[list]]:
    """Flights, boxes (half landings, dividers, top rails) and handrails per core (U-stairs as OF's stairs())."""
    flights, boxes, rails = [], [], []
    for core, (lvl, rect, end, first, z_start) in CORES.items():
        ox, oz = off(lvl)
        t_wall = 0.15 if core != "SC" else 0.1
        cx0, cz0, cx1, cz1 = rect[0] + t_wall, rect[1] + t_wall, rect[2] - t_wall, rect[3] - t_wall
        lw = (cx1 - cx0 - 0.2) / 2.0
        west = [cx0, cx0 + lw]
        well = [cx0 + lw, cx0 + lw + 0.2]
        east = [well[1], cx1]
        sides = {"W": west, "E": east}
        f1, f2 = sides[first], sides["W" if first == "E" else "E"]
        run = (RISERS - 1) * TREAD
        sgn = -1.0 if end == "S" else 1.0  # flight 1 runs toward -z (north) for a south landing
        yaw1, yaw2 = (180.0, 0.0) if end == "S" else (0.0, 180.0)
        zh = z_start + sgn * run  # flight 2 origin (the half landing edge)
        hl = (cz0, zh) if end == "S" else (zh, cz1)  # half landing z extent
        storeys = CORE_STOREYS[core]
        for i, (y0, y1) in enumerate(storeys):
            yh = r3(y0 + RISERS * RISER)
            x1c, x2c = (f1[0] + f1[1]) / 2.0, (f2[0] + f2[1]) / 2.0
            flights.append(
                ["%sFlight%d_1" % (core, i), [r3(x1c + ox), y0, r3(z_start + oz)], yaw1, r3(lw), RISERS, RISER, TREAD]
            )
            flights.append(
                ["%sFlight%d_2" % (core, i), [r3(x2c + ox), yh, r3(zh + oz)], yaw2, r3(lw), RISERS, RISER, TREAD]
            )
            boxes.append(
                box(
                    "Stairs",
                    "%sHalfLanding%d" % (core, i),
                    cx0 + ox,
                    yh - 0.3,
                    hl[0] + oz,
                    cx1 + ox,
                    yh,
                    hl[1] + oz,
                    "stair",
                )
            )
            top = y1 + (PARAPET if i == len(storeys) - 1 else 0.0)
            za, zb = sorted([zh, z_start])
            boxes.append(
                box(
                    "Stairs", "%sDivider%d" % (core, i), well[0] + ox, y0, za + oz, well[1] + ox, top, zb + oz, "wall"
                )
            )
            hr, of = 1.025, 0.07
            for k, xx in enumerate([f1[0] + of, f1[1] - of]):
                rails.append(
                    [
                        "%sFlight%d_1Rail%d" % (core, i, k),
                        [r3(xx + ox), r3(y0 + RISER + hr), r3(z_start + oz)],
                        [r3(xx + ox), r3(yh + hr), r3(zh + oz)],
                    ]
                )
            for k, xx in enumerate([f2[0] + of, f2[1] - of]):
                rails.append(
                    [
                        "%sFlight%d_2Rail%d" % (core, i, k),
                        [r3(xx + ox), r3(yh + RISER + hr), r3(zh + oz)],
                        [r3(xx + ox), r3(y1 + hr), r3(z_start + oz)],
                    ]
                )
        ytop = storeys[-1][1]
        zr = z_start - 0.06 if end == "S" else z_start
        boxes.append(
            box(
                "Stairs",
                "%sTopRail" % core,
                f1[0] + ox,
                ytop,
                zr + oz,
                f1[1] + ox,
                ytop + GUARD,
                zr + 0.06 + oz,
                "trim",
            )
        )
    # the scaffold stair tower (site local 24..28 x 26..32): ground + upper landings north, flights south
    sx, sz = off("SG")
    tw = (24.0, 26.0, 28.0, 32.0)
    land = 27.3
    flights.append(["ScaffoldFlight_1", [r3(25.3 + sx), 0.0, r3(land + sz)], 0.0, 1.2, RISERS, RISER, TREAD])
    zh2 = land + (RISERS - 1) * TREAD
    flights.append(
        ["ScaffoldFlight_2", [r3(26.7 + sx), r3(RISERS * RISER), r3(zh2 + sz)], 180.0, 1.2, RISERS, RISER, TREAD]
    )
    boxes.append(
        box(
            "Scaffold",
            "ScaffoldHalfLanding",
            tw[0] + 0.1 + sx,
            1.55,
            zh2 + sz,
            tw[2] - 0.1 + sx,
            1.75,
            tw[3] - 0.1 + sz,
            "frame",
        )
    )
    boxes.append(
        box(
            "Scaffold",
            "ScaffoldTopLanding",
            tw[0] + 0.1 + sx,
            3.3,
            tw[1] + sz,
            tw[2] - 0.1 + sx,
            3.5,
            land + sz,
            "frame",
        )
    )
    boxes.append(box("Scaffold", "ScaffoldDivider", 25.9 + sx, 0.0, land + sz, 26.1 + sx, 3.5, zh2 + sz, "frame"))
    for k, xx in enumerate([24.77, 25.83]):
        rails.append(
            [
                "ScaffoldFlight_1Rail%d" % k,
                [r3(xx + sx), r3(RISER + 1.025), r3(land + sz)],
                [r3(xx + sx), r3(1.75 + 1.025), r3(zh2 + sz)],
            ]
        )
    for k, xx in enumerate([26.17, 27.23]):
        rails.append(
            [
                "ScaffoldFlight_2Rail%d" % k,
                [r3(xx + sx), r3(1.75 + RISER + 1.025), r3(zh2 + sz)],
                [r3(xx + sx), r3(3.5 + 1.025), r3(land + sz)],
            ]
        )
    return flights, boxes, rails


# --------------------------------------------------------------------------------------------- the site
def _ramp_y(x: float) -> float:
    return r3(ST.ramp_y(x))


def site() -> Tuple[List[list], List[list]]:
    """Site boxes and hulls (the trench ramp, the retaining walls' copings are boxes)."""
    b: List[list] = []
    hulls: List[list] = []
    g = GRADE_T
    # grade (asphalt carriageways, paving elsewhere); the east trench is cut out (x >= 34, z -11..11)
    grade = [
        ("Orchard", (-14.0, -100.0, 14.0, 80.0), "asphalt"),
        ("TanneryW", (-88.0, -11.0, -14.0, 11.0), "asphalt"),
        ("Site", (-60.0, -56.0, -14.0, -11.0), "paving"),
        ("Plaza", (-60.0, 11.0, -14.0, 30.0), "paving"),
        ("AshbyFront", (-24.0, 30.0, -14.0, 50.0), "paving"),
        ("CarParkBlock", (14.0, -56.0, 52.0, -14.0), "paving"),
        ("ForecourtW", (14.0, -14.0, 34.0, -11.0), "paving"),
        ("ForecourtE", (34.0, -14.0, 64.0, -11.2), "paving"),
        ("RailLane", (52.0, -100.0, 64.0, -14.0), "paving"),
        ("TanneryE", (14.0, -11.0, 34.0, 11.0), "asphalt"),
        ("SouthEastW", (14.0, 11.0, 34.0, 40.0), "paving"),
        ("SouthEastE", (34.0, 11.2, 64.0, 40.0), "paving"),
    ]
    for nm, r, cls in grade:
        b.append(box("Grade", "Grade" + nm, r[0], -g, r[1], r[2], 0.0, r[3], cls))
    # the east trench: ramp x 34..66 (0 -> -5), underpass + cut at -5 to the OOB extension x 112
    zt = (-11.0 + EXT_T / 2.0, 11.0 - EXT_T / 2.0)
    pts = []
    for x in (34.0, 66.0):
        y = _ramp_y(x)
        for z in zt:
            pts += [[x, y, z], [x, y - g, z]]
    hulls.append(["Grade", "TrenchRamp", pts, "asphalt"])
    b.append(box("Grade", "GradeTrench", 66.0, TRENCH_Y - g, zt[0], 112.0, TRENCH_Y, zt[1], "asphalt"))
    # retaining walls (z -11 / 11): x 34..64 a wall to the street + a 1.1 m parapet railing; x 64..112 to the rail bank
    for side, z in (("N", -11.0), ("S", 11.0)):
        b.append(
            box(
                "Trench",
                "Retaining%s" % side,
                34.0,
                TRENCH_Y - g,
                z - EXT_T / 2,
                64.0,
                0.0,
                z + EXT_T / 2,
                "wall_ext",
            )
        )
        b.append(box("Trench", "Parapet%s" % side, 34.0, 0.0, z - GUARD_T / 2, 64.0, GUARD, z + GUARD_T / 2, "rail"))
        b.append(
            box(
                "Trench",
                "CutWall%s" % side,
                64.0,
                TRENCH_Y - g,
                z - EXT_T / 2,
                112.0,
                RAIL_Y,
                z + EXT_T / 2,
                "wall_ext",
            )
        )
    # the rail bank (+1.2, police / dressing only) N and S of the trench, the bridge over the underpass, palisades
    b.append(box("Rail", "BankN", 64.0, -g, -100.0, 112.0, RAIL_Y, -11.0 - EXT_T / 2, "paving"))
    b.append(box("Rail", "BankS", 64.0, -g, 11.0 + EXT_T / 2, 112.0, RAIL_Y, 80.0, "paving"))
    b.append(box("Rail", "Bridge", 66.0, BRIDGE_SOFFIT, -11.0, 84.0, RAIL_Y, 11.0, "wall_ext"))
    for nm, z0, z1 in (("N", -100.0, -11.2), ("S", 11.2, 80.0)):
        for x in (64.0, 86.0):
            b.append(
                box("Rail", "Palisade%s%d" % (nm, int(x)), x, RAIL_Y, z0, x + 0.06, RAIL_Y + PALISADE_H, z1, "frame")
            )
    # the height bar at x 62 (4.4 m over the road) on two posts, the rail-lane palisades (south end, the gate line)
    yb = _ramp_y(62.0) + 4.4
    b.append(box("Trench", "HeightBar", 61.9, yb, -10.8, 62.1, yb + 0.25, 10.8, "trim"))
    # the signal gantry over the tracks (S2's platform, police only)
    b.append(box("Rail", "GantryDeck", 72.0, 7.2, -25.0, 78.0, 7.5, -23.0, "frame"))
    for x in (72.2, 77.4):
        b.append(box("Rail", "GantryLeg%d" % int(x), x, RAIL_Y, -24.3, x + 0.4, 7.2, -23.7, "frame"))
    # rail lane: the palisade at its south end (no gate: the lane is reached through the car-park fire door) and the
    # gate line at z -72 (P_NE's breachable gate at x 60, hole 59..61)
    b.append(box("RailLane", "LaneSouthFence", 52.2, 0.0, -14.1, 64.0, PALISADE_H, -13.9, "frame"))
    b.append(box("RailLane", "LaneGateW", 52.2, 0.0, -72.1, 59.0, PALISADE_H, -71.9, "frame"))
    b.append(box("RailLane", "LaneGateE", 61.0, 0.0, -72.1, 64.0, PALISADE_H, -71.9, "frame"))
    b.append(box("RailLane", "LaneGateHead", 59.0, 2.2, -72.1, 61.0, PALISADE_H + 0.6, -71.9, "frame"))
    b.append(box("RailLane", "LaneNorthLot", 51.8, 0.0, -56.0, 52.2, HOARDING_H, -50.0, "frame"))
    # the forecourt's east end (the palisade line x 64 at street level)
    b.append(box("RailLane", "ForecourtEnd", 63.9, 0.0, -14.0, 64.1, PALISADE_H, -11.2, "frame"))
    # the Skyway: deck (girder soffit 7.6, top 9.0), parapets with the two rappel gaps, the four median piers
    b.append(box("Skyway", "Deck", -13.0, SKY_DECK[0], -100.0, 13.0, SKY_DECK[1], 80.0, "wall_ext"))
    for side, x0 in (("W", -13.0), ("E", 13.0 - PARAPET_T)):
        gap = -26.0 if side == "W" else 20.0
        for k, (z0, z1) in enumerate([(-100.0, gap - 0.8), (gap + 0.8, 80.0)]):
            b.append(
                box(
                    "Skyway",
                    "Parapet%s%d" % (side, k),
                    x0,
                    SKY_DECK[1],
                    z0,
                    x0 + PARAPET_T,
                    SKY_DECK[1] + PARAPET,
                    z1,
                    "wall_ext",
                )
            )
    for z in (-72.0, -40.0, 30.0, 62.0):
        b.append(box("Skyway", "Pier%d" % int(z), -1.0, 0.0, z - 1.5, 1.0, SKY_DECK[0], z + 1.5, "wall_ext"))
    # Tanner's Reach: the hoarding (2.4 m solid) with its three gates; the magazine; the frame columns
    sx, sz = off("SG")
    hz = [
        ("N", "x", 0.0, 0.0, 46.0, []),
        ("W", "z", 0.0, 0.0, 45.0, []),
        ("E", "z", 46.0, 0.0, 45.0, [(10.3, 12.3), (12.7, 14.7), (39.4, 40.6)]),
        ("S", "x", 45.0, 0.0, 46.0, [(24.3, 26.3), (26.7, 28.7)]),
    ]
    for nm, axis, fixed, a0, a1, gaps in hz:
        spans, cur = [], a0
        for g0, g1 in gaps:
            spans.append((cur, g0))
            cur = g1
        spans.append((cur, a1))
        for k, (p, q) in enumerate(spans):
            if axis == "x":
                b.append(
                    box(
                        "Hoarding",
                        "Hoarding%s%d" % (nm, k),
                        p + sx,
                        0.0,
                        fixed - HOARD_T / 2 + sz,
                        q + sx,
                        HOARDING_H,
                        fixed + HOARD_T / 2 + sz,
                        "trim",
                    )
                )
            else:
                b.append(
                    box(
                        "Hoarding",
                        "Hoarding%s%d" % (nm, k),
                        fixed - HOARD_T / 2 + sx,
                        0.0,
                        p + sz,
                        fixed + HOARD_T / 2 + sx,
                        HOARDING_H,
                        q + sz,
                        "trim",
                    )
                )
        for g0, g1 in gaps:  # the gate heads (2.2 m openings in the 2.4 m hoarding)
            if axis == "x":
                b.append(
                    box(
                        "Hoarding",
                        "GateHead%s%d" % (nm, int(g0 * 10)),
                        g0 + sx,
                        DOOR_HEAD,
                        fixed - HOARD_T / 2 + sz,
                        g1 + sx,
                        HOARDING_H,
                        fixed + HOARD_T / 2 + sz,
                        "trim",
                    )
                )
            else:
                b.append(
                    box(
                        "Hoarding",
                        "GateHead%s%d" % (nm, int(g0 * 10)),
                        fixed - HOARD_T / 2 + sx,
                        DOOR_HEAD,
                        g0 + sz,
                        fixed + HOARD_T / 2 + sx,
                        HOARDING_H,
                        g1 + sz,
                        "trim",
                    )
                )
    # the magazine MG (local 35..39 x 4..7): a 4 x 3 m steel box, door on its south face at x 37 (hole 36.4..37.6)
    mg = (35.0, 4.0, 39.0, 7.0)
    for nm, a in (("W", mg[0]), ("E", mg[2])):
        b.append(
            box("Magazine", "MagWall%s" % nm, a - 0.1 + sx, 0.0, mg[1] + sz, a + 0.1 + sx, 2.4, mg[3] + sz, "trim")
        )
    b.append(
        box(
            "Magazine",
            "MagWallN",
            mg[0] + 0.1 + sx,
            0.0,
            mg[1] - 0.1 + sz,
            mg[2] - 0.1 + sx,
            2.4,
            mg[1] + 0.1 + sz,
            "trim",
        )
    )
    for nm, p, q in (("SW", mg[0] + 0.1, 36.4), ("SE", 37.6, mg[2] - 0.1)):
        b.append(
            box("Magazine", "MagWall%s" % nm, p + sx, 0.0, mg[3] - 0.1 + sz, q + sx, 2.4, mg[3] + 0.1 + sz, "trim")
        )
    b.append(
        box("Magazine", "MagHead", 36.4 + sx, DOOR_HEAD, mg[3] - 0.1 + sz, 37.6 + sx, 2.4, mg[3] + 0.1 + sz, "trim")
    )
    b.append(
        box(
            "Magazine",
            "MagRoof",
            mg[0] - 0.1 + sx,
            2.4,
            mg[1] - 0.1 + sz,
            mg[2] + 0.1 + sx,
            2.55,
            mg[3] + 0.1 + sz,
            "roof",
        )
    )
    for cx in (10.0, 16.0, 22.0, 28.0, 34.0):
        for cz in (6.0, 11.0, 16.0, 21.0, 26.0):
            b.append(
                box(
                    "Frame",
                    "Column%d_%d" % (int(cx), int(cz)),
                    cx - 0.2 + sx,
                    0.0,
                    cz - 0.2 + sz,
                    cx + 0.2 + sx,
                    SITE_SLAB[0],
                    cz + 0.2 + sz,
                    "wall_ext",
                )
            )
    # F1 edge protection (1.1 m, mesh + rails: one 0.06 m greybox body; _nav_thick widens it in the bake): gaps at the
    # NW ladder landing (rails from x 11 / z 7) and the scaffold stair arrival (x 25..27 on z 26)
    ey = SITE_SLAB[1]
    eps = [
        ("N", 11.0 + sx, ey, 6.0 + sz - 0.03, 34.0 + sx, ey + GUARD, 6.0 + sz + 0.03),
        ("W", 10.0 + sx - 0.03, ey, 7.0 + sz, 10.0 + sx + 0.03, ey + GUARD, 26.0 + sz),
        ("E", 34.0 + sx - 0.03, ey, 6.0 + sz, 34.0 + sx + 0.03, ey + GUARD, 26.0 + sz),
        ("S0", 10.0 + sx, ey, 26.0 + sz - 0.03, 25.0 + sx, ey + GUARD, 26.0 + sz + 0.03),
        ("S1", 27.0 + sx, ey, 26.0 + sz - 0.03, 34.0 + sx, ey + GUARD, 26.0 + sz + 0.03),
    ]
    for nm, *bb in eps:
        b.append(box("Frame", "EdgeProtection" + nm, *bb, "frame"))
    # the scaffold tower cladding (mesh, 0.06 m): open N face at x 25..27 at both levels, guards to 3.5 + 1.1
    tw = (24.0, 26.0, 28.0, 32.0)
    th = 3.5 + GUARD
    clad = [
        ("W", tw[0] - 0.03, 0.0, tw[1], tw[0] + 0.03, th, tw[3]),
        ("E", tw[2] - 0.03, 0.0, tw[1], tw[2] + 0.03, th, tw[3]),
        ("S", tw[0], 0.0, tw[3] - 0.03, tw[2], th, tw[3] + 0.03),
        ("NW", tw[0], 0.0, tw[1] - 0.03, 25.0, th, tw[1] + 0.03),
        ("NE", 27.0, 0.0, tw[1] - 0.03, tw[2], th, tw[1] + 0.03),
        ("NMid", 25.0, DOOR_HEAD, tw[1] - 0.03, 27.0, 3.3, tw[1] + 0.03),
    ]
    for nm, x0, y0, z0, x1, y1, z1 in clad:
        b.append(box("Scaffold", "Clad" + nm, x0 + sx, y0, z0 + sz, x1 + sx, y1, z1 + sz, "frame"))
    # the crane base (local 32..36 x 30..34) and its mast, the signal controller cabinet (local 44, 43)
    b.append(box("Crane", "CraneBase", 32.0 + sx, 0.0, 30.0 + sz, 36.0 + sx, 1.4, 34.0 + sz, "wall_ext"))
    b.append(box("Crane", "CraneMast", 33.2 + sx, 1.4, 31.2 + sz, 34.8 + sx, 29.6, 32.8 + sz, "frame"))
    b.append(box("Crane", "CraneCab", 30.0 + sx, 29.6, 30.0 + sz, 35.0 + sx, 30.0, 34.0 + sz, "frame"))
    b.append(box("Crane", "CraneJib", 34.8 + sx, 31.0, 31.6 + sz, 74.0 + sx, 31.8, 32.4 + sz, "frame"))
    b.append(box("Controller", "ControllerCabinet", 43.4 + sx, 0.0, 42.55 + sz, 44.6 + sx, 2.0, 43.2 + sz, "prop"))
    # the diner chamfer-free shell is walls; Ashby House (police roof perch S4), the laundromat and the tyre shop
    for nm, r, h in NEIGHBOURS:
        y0 = TRENCH_Y - g if nm == "VistaE" else -g
        b.append(box("Neighbours", nm, r[0], y0, r[1], r[2], h, r[3], "wall_ext"))
    b.append(box("Neighbours", "AshbyRoofPlant", -31.0, 14.4, 35.0, -29.0, 15.5, 37.0, "wall_ext"))
    b.append(box("Neighbours", "AshbyParapetN", -60.0, 14.4, 30.0, -24.0, 14.4 + PARAPET, 30.3, "wall_ext"))
    # closures (site-plan rectangles; G1: the W and S lorries leave a >= 4 m police lane, RT plan §7.12)
    for nm, r, y0, h, cls in CLOSURES:
        b.append(box("Closures", nm, r[0], y0, r[1], r[2], y0 + h, r[3], cls))
    return b, hulls


# Neighbour massing [name, [x0, z0, x1, z1], height]: every edge of the play space that is not a street closure.
NEIGHBOURS: List[list] = [
    ["WarehousesW", [-88.0, -100.0, -60.0, -11.0], 9.0],
    ["WarehousesSW", [-88.0, 11.0, -60.0, 80.0], 9.0],
    ["BlockNW", [-60.0, -100.0, -14.0, -56.0], 10.0],
    ["AshbyHouse", [-60.0, 30.0, -24.0, 50.0], 14.4],
    ["BlockSW", [-60.0, 50.0, -14.0, 80.0], 10.0],
    ["BlockNE", [14.0, -100.0, 52.0, -56.0], 10.0],
    ["Laundromat", [34.0, 14.0, 50.0, 32.0], 7.5],
    ["TyreShop", [52.0, 14.0, 64.0, 36.0], 6.0],
    ["BlockSE", [14.0, 40.0, 64.0, 80.0], 10.0],
    ["YardBlockE", [52.0, 36.0, 64.0, 40.0], 6.0],
    ["VistaN", [-14.0, -102.0, 14.0, -100.0], 12.0],
    ["VistaS", [-14.0, 80.0, 14.0, 82.0], 12.0],
    ["VistaW", [-90.0, -11.0, -88.0, 11.0], 12.0],
    ["VistaE", [112.0, -11.0, 114.0, 11.0], 6.0],
    ["VistaRailN", [52.0, -102.0, 64.0, -100.0], 10.0],
]
# Closures [name, [x0, z0, x1, z1], y0, height, class] (site_ascii CLOSURES + the sidewalk barriers).
CLOSURES: List[list] = [
    ["TMTruckN", [1.0, -85.5, 10.0, -83.0], 0.0, 3.4, "prop"],
    ["BarrierNE", [10.0, -85.0, 14.0, -84.0], 0.0, 1.2, "trim"],
    ["LorryS", [-4.0, 64.0, 10.0, 66.0], 0.0, 4.0, "prop"],
    ["BarrierSE", [10.0, 64.5, 14.0, 65.5], 0.0, 1.2, "trim"],
    ["LorryW", [-76.0, -8.0, -74.0, 4.0], 0.0, 4.0, "prop"],
    ["BarrierWN", [-75.5, -11.0, -74.5, -8.0], 0.0, 1.2, "trim"],
    ["LorryE", [96.0, 0.0, 100.0, 8.0], TRENCH_Y, 4.0, "prop"],
    ["BarrierES", [97.5, 8.0, 98.5, 10.8], TRENCH_Y, 1.2, "trim"],
]
# Navmesh culls [name, [x0, z0, x1, z1], y0, height]: the tops nobody stands on (no walkable islands in the bake).
NAV_CULL: List[list] = (
    [[nm, r, h - 0.2, 4.0] for nm, r, h in NEIGHBOURS if nm != "AshbyHouse"]
    + [
        ["BankN", [64.0, -100.0, 112.0, -11.2], RAIL_Y - 0.2, 2.5],
        ["BankS", [64.0, 11.2, 112.0, 80.0], RAIL_Y - 0.2, 2.5],
        ["Bridge", [64.0, -11.0, 86.0, 11.0], RAIL_Y - 0.2, 2.5],
        ["Ashby", [-60.0, 30.0, -24.0, 50.0], 14.2, 4.0],
        ["DinerRoof", [14.0, 14.0, 34.0, 32.0], 6.8, 3.0],
        ["CabinRoof", [-58.2, -26.2, -45.8, -16.8], 2.5, 2.0],
        ["HHA", [15.8, -50.2, 22.2, -43.8], 9.5, 2.0],
        ["HHB", [48.8, -20.2, 52.2, -13.8], 9.5, 2.0],
        ["Magazine", [-25.2, -52.2, -20.8, -48.8], 2.3, 2.0],
        ["Crane", [-28.0, -26.0, -24.0, -22.0], 0.8, 40.0],
        ["Controller", [-16.7, -13.5, -15.3, -12.7], 1.3, 1.0],
    ]
    + [[nm, r, y0 + h - 0.2, 2.0] for nm, r, y0, h, _c in CLOSURES]
)


# --------------------------------------------------------------------------------------------- copings, hulls
def copings() -> List[list]:
    """Ridge copings over the roof parapets (car park, diner): hull rows [group, name, points, class]."""
    out = []
    runs = [
        # car park roof parapet tops (site): N, W, S
        ("CPRoofN", "x", -50.0 + PARAPET_T / 2, 22.15, 51.8, 7.0 + PARAPET),
        ("CPRoofW", "z", 16.0 + PARAPET_T / 2, -43.85, -14.2, 7.0 + PARAPET),
        ("CPRoofS", "x", -14.0 - PARAPET_T / 2, 16.0, 48.85, 7.0 + PARAPET),
    ]
    runs.append(("CPRoofE", "z", 52.0, -49.8, -20.15, 7.0 + PARAPET))  # the fire wall's top (0.4 m)
    for nm, axis, fixed, a0, a1, y in runs:
        hw = (EXT_T if nm == "CPRoofE" else PARAPET_T) / 2
        prof = [[-hw, 0.0], [-0.001, COPING_RISE], [0.001, COPING_RISE], [hw, 0.0]]
        pts = []
        for a in (a0, a1):
            for q in prof:
                pts.append(
                    [r3(a), r3(y + q[1]), r3(fixed + q[0])]
                    if axis == "x"
                    else [r3(fixed + q[0]), r3(y + q[1]), r3(a)]
                )
        out.append(["Coping", nm, pts, "wall_ext"])
    return out


def _sub(a: list, b: list) -> list:
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def _cross(a: list, b: list) -> list:
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def _dot(a: list, b: list) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def hull_faces(pts: List[list]) -> List[List[int]]:
    """Faces of the convex hull of `pts` (OF's hull_faces): point-index polygons, counter-clockwise from outside."""
    uniq: List[int] = []
    for i, p in enumerate(pts):
        if not any(abs(p[0] - pts[j][0]) + abs(p[1] - pts[j][1]) + abs(p[2] - pts[j][2]) < 1e-6 for j in uniq):
            uniq.append(i)
    centre = [sum(pts[i][k] for i in uniq) / len(uniq) for k in range(3)]
    faces: List[List[int]] = []
    seen: List[tuple] = []
    for a in range(len(uniq)):
        for b in range(a + 1, len(uniq)):
            for c in range(b + 1, len(uniq)):
                pa, pb, pc = pts[uniq[a]], pts[uniq[b]], pts[uniq[c]]
                nrm = _cross(_sub(pb, pa), _sub(pc, pa))
                ln = _dot(nrm, nrm) ** 0.5
                if ln < 1e-9:
                    continue
                nrm = [v / ln for v in nrm]
                d = _dot(nrm, pa)
                if _dot(nrm, centre) > d:
                    nrm, d = [-v for v in nrm], -d
                if any(_dot(nrm, pts[i]) > d + 1e-6 for i in uniq):
                    continue
                key = (round(nrm[0], 5), round(nrm[1], 5), round(nrm[2], 5), round(d, 4))
                if key in seen:
                    continue
                seen.append(key)
                on = [i for i in uniq if abs(_dot(nrm, pts[i]) - d) < 1e-6]
                fc = [sum(pts[i][k] for i in on) / len(on) for k in range(3)]
                ref = _sub(pts[on[0]], fc)
                ref2 = _cross(nrm, ref)
                faces.append(
                    sorted(on, key=lambda i: math.atan2(_dot(_sub(pts[i], fc), ref2), _dot(_sub(pts[i], fc), ref)))
                )
    return faces


def shell_boxes() -> List[list]:
    """Car-park guards, columns, the entrance height bar (site boxes, group Building/<group>)."""
    ox, oz = off("CP-G")
    out = []
    for nm, x0, y0, z0, x1, y1, z1, cls in carpark_guards():
        out.append(box("Guards", nm, x0 + ox, y0, z0 + oz, x1 + ox, y1, z1 + oz, cls))
    cols = {
        0.0: [(x, z) for x in (5, 11, 16, 21) for z in (6, 12, 18, 24)] + [(11, 30)],
        3.5: [(x, z) for x in (5, 11, 16, 21) for z in (6, 12, 18, 24, 30)],
    }
    for y, pts in cols.items():
        top = y + 3.5 - CP_DECK[0][1]
        for x, z in pts:
            out.append(
                box(
                    "Columns",
                    "Col%d_%d_%d" % (int(y), x, z),
                    x - 0.2 + ox,
                    y,
                    z - 0.2 + oz,
                    x + 0.2 + ox,
                    top,
                    z + 0.2 + oz,
                    "wall_ext",
                )
            )
    out.append(box("Columns", "EntranceHeightBar", 6.0 + ox, 2.4, 35.85 + oz, 10.0 + ox, 2.7, 36.0 + oz, "trim"))
    # the lintel over the 4 m entrance (deck 2 downstand down to 2.7 is the slab itself)
    return out


def hulls() -> List[list]:
    ox, oz = off("CP-G")
    out = []
    for nm, pts, cls in ramps_cp():
        out.append(["Ramps", nm, [[r3(p[0] + ox), r3(p[1]), r3(p[2] + oz)] for p in pts], cls])
    return out + copings()


def oob() -> List[list]:
    """OUT_OF_BOUNDS curtains beyond the play space (D-040): [name, [x0, y0, z0, x1, y1, z1]]."""
    return [
        ["OobNorth", [-14.0, -1.0, -100.0, 14.0, 7.0, -92.0]],
        ["OobRailNorth", [52.0, -1.0, -100.0, 64.0, 6.0, -92.0]],
        ["OobSouth", [-14.0, -1.0, 72.0, 14.0, 7.0, 80.0]],
        ["OobWest", [-88.0, -1.0, -11.0, -80.0, 7.0, 11.0]],
        ["OobEast", [104.0, TRENCH_Y - 1.0, -11.0, 112.0, 1.0, 11.0]],
        # the Skyway deck beyond the play space (police island; nobody stands there, but a thrown bag lands there)
        ["OobDeckN", [-13.0, SKY_DECK[1] - 0.5, -100.0, 13.0, 14.0, -92.0]],
        ["OobDeckS", [-13.0, SKY_DECK[1] - 0.5, 72.0, 13.0, 14.0, 80.0]],
    ]
