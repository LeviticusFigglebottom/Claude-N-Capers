# Afterhours G1 geometry (AH-C1, D-165): the shell, site and closure primitives emitted into
# game/world/heists/afterhours/greybox/afterhours_layout.gd by afterhours_emit_layout.py. Owner: ENV C.
# Source: afterhours_floors_ascii.py (rooms + openings) and docs/design/heists/afterhours.md (Site, Floor plans,
# vertical data). Same table shapes as rolling_thunder_geometry.py (the generator chain is copy-adapted from RT).
#
# Walls are derived from the plan: every unit edge between two different rooms of a level (or a room and the outside)
# is a wall, merged into runs. Ground: exterior 0.4 m to +4.2, the old auditorium's walls 0.4 m (the hall G6 / G7 to
# anything else; G6 | G7 itself is the open circle soffit line, no wall), stair cores 0.3 m, interior 0.2 m to the
# slab underside (+3.6). Balcony level: the hall's walls 0.4 m to the hall roof (+8.0; the roof slab 8.0-8.8 and a
# 1.0 m upstand above it), the front block / east wing exterior to their 1.0 m parapet (+9.0, roof +8.0), interior 0.2 m
# to the roof slab underside (+7.6); the BOH roof edge is its 1.1 m parapet (the drop-ladder gap at x 30).
from __future__ import annotations

import os
import sys
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import afterhours_floors_ascii as P  # noqa: E402
from rolling_thunder_checklib import OUT  # noqa: E402

EXT = 0.4
HALL_T = 0.4
CORE = 0.3
INT = 0.2
SLAB_U = (3.6, 4.2)        # the balcony slab (and the BOH roof)
HALL_ROOF = (8.0, 8.8)
BLOCK_ROOF = (7.6, 8.0)    # front block and east wing
HALL_PARAPET = 9.8
BLOCK_PARAPET = 9.0
BOH_PARAPET = 4.2 + 1.1
DOOR_HEAD = 2.2
OPEN_HEAD = 2.4            # open passages (o_*): the G20 / U6b corridor mouths, the stair foot
WIDE_HEAD = 2.6            # the balcony-to-VIP openings
ROLLER_HEAD = 3.0
WINDOW = (0.0, 2.1)        # sill, head above the floor (the count-room window onto the BOH roof: a full-height
                           # casement, the catalog window is h210)
LADDER_GAP = (29.4, 30.6)  # the BOH roof parapet's gap at the drop-ladder hoops (x 30)
CEIL_T = 0.05
HALL_ROOMS = ("G6", "G7")
CORES = ("G8", "G22", "U8", "U7")
# the stair wells (clear, 0.3 m core walls) and their half landings (doc "Stair core fit")
G8_CLEAR = (6.15, 21.15, 9.85, 27.85)
G22_CLEAR = (33.15, 7.15, 35.85, 13.85)
RISERS = 12
RISER = 0.175
TREAD = 0.28
RUN = (RISERS - 1) * TREAD  # 3.08


def r3(v: float) -> float:
    return round(v + 0.0, 3)


def _edges(key: str) -> List[Tuple[str, int, int, str, str]]:
    """Unit edges (axis, fixed, a, room_lo, room_hi) where the room changes: 'x' = a wall at z = fixed spanning
    x a..a+1 (lo = north / -z side), 'z' = a wall at x = fixed spanning z a..a+1 (lo = west / -x side)."""
    lv = P.LEVELS[key]
    out = []
    for i in range(0, 37):
        for j in range(0, 28):
            lo = lv.room_at((i - 1, j)) if i > 0 else OUT
            hi = lv.room_at((i, j)) if i < 36 else OUT
            if lo != hi:
                out.append(("z", i, j, lo, hi))
    for j in range(0, 29):
        for i in range(0, 36):
            lo = lv.room_at((i, j - 1)) if j > 0 else OUT
            hi = lv.room_at((i, j)) if j < 28 else OUT
            if lo != hi:
                out.append(("x", j, i, lo, hi))
    return out


def _kind(key: str, a: str, b: str) -> Optional[Tuple[float, float, float, str]]:
    """(thickness, y0, y1, class) of the wall between rooms a and b on level key, or None (no wall)."""
    s = {a, b}
    if key == "G":
        if s == set(HALL_ROOMS):
            return None
        if OUT in s:
            return (EXT, 0.0, 4.2, "wall_ext")
        if s & set(HALL_ROOMS):
            return (HALL_T, 0.0, 4.2, "wall")
        if s & set(CORES):
            return (CORE, 0.0, SLAB_U[0], "wall")
        return (INT, 0.0, SLAB_U[0], "wall")
    hall = {"VOID", "U1"}
    if s == hall:
        return None                                  # the balcony front: a guard (SHELL_BOXES)
    if "ROOF" in s:
        other = (s - {"ROOF"}).pop()
        if other == OUT:
            return (EXT, 4.2, BOH_PARAPET, "rail")   # the BOH roof parapet: not standable (D-104 slopes)
        if other == "VOID":
            return (HALL_T, 4.2, HALL_PARAPET, "wall_ext")
        return (EXT, 4.2, BLOCK_PARAPET, "wall_ext")
    if OUT in s:
        other = (s - {OUT}).pop()
        return (EXT, 4.2, HALL_PARAPET if other in hall else BLOCK_PARAPET, "wall_ext")
    if s & hall:
        return (HALL_T, 4.2, HALL_ROOF[0], "wall")
    if s & set(CORES):
        return (CORE, 4.2, BLOCK_ROOF[0], "wall")
    return (INT, 4.2, BLOCK_ROOF[0], "wall")


def door_kit(op) -> Optional[Tuple[str, float, float]]:
    """(kind, hole half width, leaf width) of the door in a plan opening (rolling_thunder_geometry.kit); None for the
    open passages (o_*), windows (w_*) and the roller door (a closed shutter box at G1)."""
    if op.name.startswith(("o_", "w_")) or op.name == "roller":
        return None
    if op.width is None or op.width <= 1.25:
        return ("service", 0.6, 1.1)
    return ("double", 1.0, 1.8)


def _holes(key: str) -> List[Tuple[str, float, float, float, float, float]]:
    """(axis, fixed, a0, a1, y0, y1) per opening on level key (absolute heights; door holes are the kit's)."""
    ffl = P.LEVEL_FFL[key]
    out = []
    for op in P.OPENINGS:
        if op.level != key:
            continue
        lo, hi = op.span()
        k = door_kit(op)
        if k is not None:
            c = (lo + hi) / 2.0
            lo, hi = c - k[1], c + k[1]
        fixed = op.z if op.along == "x" else op.x
        if op.name.startswith("w_"):
            y0, y1 = ffl + WINDOW[0], ffl + WINDOW[1]
        elif op.name == "roller":
            y0, y1 = ffl, ffl + ROLLER_HEAD
        elif op.name.startswith("o_u1"):
            y0, y1 = ffl, ffl + WIDE_HEAD
        elif op.name.startswith("o_"):
            y0, y1 = ffl, ffl + OPEN_HEAD
        else:
            y0, y1 = ffl, ffl + DOOR_HEAD
        out.append((op.along, float(fixed), lo, hi, y0, y1))
    if key == "U":
        out.append(("x", 0.0, LADDER_GAP[0], LADDER_GAP[1], 4.2, BOH_PARAPET))
    return out


def walls() -> List[list]:
    rows = []
    for key in ("G", "U"):
        runs: Dict[Tuple[str, int, Tuple[float, float, float, str]], List[int]] = {}
        for axis, fixed, a, lo, hi in _edges(key):
            k = _kind(key, lo, hi)
            if k is None:
                continue
            runs.setdefault((axis, fixed, k), []).append(a)
        holes = _holes(key)
        for (axis, fixed, k), cells in sorted(runs.items(), key=lambda t: (t[0][0], t[0][1], t[0][2][1], min(t[1]))):
            cells.sort()
            start = cells[0]
            prev = cells[0]
            spans = []
            for c in cells[1:] + [None]:
                if c is not None and c == prev + 1:
                    prev = c
                    continue
                spans.append((start, prev + 1))
                if c is not None:
                    start = prev = c
            for a0, a1 in spans:
                hs = [[r3(h[2]), r3(h[3]), r3(h[4]), r3(h[5])] for h in holes
                      if h[0] == axis and abs(h[1] - fixed) < 1e-6 and h[2] < a1 and h[3] > a0
                      and h[4] < k[2] and h[5] > k[1]]
                rows.append([key, axis, float(fixed), float(a0), float(a1), k[0], k[1], k[2], k[3], hs])
    return rows


def slabs() -> List[list]:
    foot = [-0.2, -0.2, 36.2, 28.2]
    return [
        ["Grade", [-20.0, -24.0, 64.0, 56.0], [foot], -0.3, 0.0, "asphalt"],
        ["GroundSlab", foot, [], -0.3, 0.0, "floor"],
        ["Balcony", foot, [[-0.2, 7.0, 26.0, 15.0], [G8_CLEAR[0], G8_CLEAR[1], G8_CLEAR[2], 26.0],
                           [G22_CLEAR[0], G22_CLEAR[1], G22_CLEAR[2], 12.0]], SLAB_U[0], SLAB_U[1], "floor"],
        ["G8HalfLanding", [G8_CLEAR[0], G8_CLEAR[1], G8_CLEAR[2], r3(26.0 - RUN)], [], 1.8, 2.1, "stair"],
        ["G22HalfLanding", [G22_CLEAR[0], G22_CLEAR[1], G22_CLEAR[2], r3(12.0 - RUN)], [], 1.8, 2.1, "stair"],
        ["HallRoof", [-0.2, 6.8, 26.2, 21.2], [], HALL_ROOF[0], HALL_ROOF[1], "roof"],
        ["FrontRoof", [-0.2, 21.2, 26.2, 28.2], [], BLOCK_ROOF[0], BLOCK_ROOF[1], "roof"],
        ["EastRoof", [26.2, -0.2, 36.2, 28.2], [[26.2, -0.2, 36.2, 6.8]], BLOCK_ROOF[0], BLOCK_ROOF[1], "roof"],
    ]


def ceilings() -> List[list]:
    rows = []
    undersides = {SLAB_U[0], HALL_ROOF[0], BLOCK_ROOF[0]}
    for key, lv in P.LEVELS.items():
        ffl = P.LEVEL_FFL[key]
        for rm in lv.rooms:
            if rm.ceiling is None:
                continue
            y = r3(ffl + rm.ceiling)
            if y in undersides:
                continue
            rows.append(["Ceil%s" % rm.rid, [float(c) for c in rm.rect], y])
    return rows


def stairs() -> Tuple[List[list], List[list]]:
    """U-stairs: flight 1 north (yaw 180) on the east half from the floor landing, flight 2 south (yaw 0) on the west
    half from the half landing to the upper floor landing (doors on the south landings, doc Stair core fit)."""
    flights, rails = [], []
    for name, clear, w in (("G8", G8_CLEAR, 1.5), ("G22", G22_CLEAR, 1.2)):
        x0, z0, x1, z1 = clear
        top_z = 26.0 if name == "G8" else 12.0
        e = r3(x1 - w / 2.0)
        wv = r3(x0 + w / 2.0)
        rows = [("%sFlight1" % name, [e, 0.0, top_z], 180.0), ("%sFlight2" % name, [wv, 2.1, r3(top_z - RUN)], 0.0)]
        for nm, org, yaw in rows:
            flights.append([nm, org, yaw, w, RISERS, RISER, TREAD])
            sgn = -1.0 if yaw == 180.0 else 1.0
            for side, dx in (("Rail0", -(w / 2.0 - 0.075)), ("Rail1", w / 2.0 - 0.075)):
                a = [r3(org[0] + dx), r3(org[1] + 1.0), org[2]]
                b = [r3(org[0] + dx), r3(org[1] + 1.0 + (RISERS - 1) * RISER), r3(org[2] + sgn * RUN)]
                rails.append([nm + side, a, b])
    return flights, rails


def shell_boxes() -> List[list]:
    return [
        ["Stage", "Riser", [7.0, 0.0, 7.2], [19.0, 0.3, 10.0], "floor"],
        # the U-stairs' spine walls: the well between the two flights is closed floor to floor (scale: guards)
        ["Stairs", "G8Spine", [r3(G8_CLEAR[0] + 1.5), 0.0, r3(26.0 - RUN)], [r3(G8_CLEAR[2] - 1.5), 4.2, 26.0], "wall"],
        ["Stairs", "G22Spine", [r3(G22_CLEAR[0] + 1.2), 0.0, r3(12.0 - RUN)], [r3(G22_CLEAR[2] - 1.2), 4.2, 12.0],
         "wall"],
        # the G10 stock cage (mesh to the 3.0 m ceiling) and its gate's head; the gate (StockCageGate) is a door
        ["Cage", "StockCageW", [1.0, 0.0, 0.2], [1.1, 3.0, 2.5], "mesh"],
        ["Cage", "StockCageE", [4.9, 0.0, 0.2], [5.0, 3.0, 2.5], "mesh"],
        ["Cage", "StockCageFrontW", [1.0, 0.0, 2.5], [2.5, 3.0, 2.6], "mesh"],
        ["Cage", "StockCageFrontE", [3.5, 0.0, 2.5], [5.0, 3.0, 2.6], "mesh"],
        ["Cage", "StockCageHead", [2.5, 2.2, 2.5], [3.5, 3.0, 2.6], "mesh"],
        # the smokers' passage north gate: posts and head between the Hallam wall and the Velvet (hole x -2.6 .. -0.6)
        ["PassageGate", "PostW", [-3.0, 0.0, -0.1], [-2.6, 2.6, 0.1], "frame"],
        ["PassageGate", "PostE", [-0.6, 0.0, -0.1], [-0.2, 2.6, 0.1], "frame"],
        ["PassageGate", "Head", [-2.6, 2.2, -0.1], [-0.6, 2.6, 0.1], "frame"],
        ["Guards", "BalconyFront", [0.2, 4.2, 14.95], [25.8, 5.25, 15.05], "rail"],
        ["Guards", "G8Well", [r3(G8_CLEAR[0] + 1.5), 4.2, 25.95], [G8_CLEAR[2], 5.25, 26.05], "rail"],
        ["Guards", "G22Well", [r3(G22_CLEAR[0] + 1.2), 4.2, 11.95], [G22_CLEAR[2], 5.25, 12.05], "rail"],
        # the hall's 1.0 m upstand over the front block / east wing roofs
        ["Upstands", "HallS", [-0.2, HALL_ROOF[1], 20.8], [26.2, HALL_PARAPET, 21.2], "wall_ext"],
        ["Upstands", "HallE", [25.8, HALL_ROOF[1], 6.8], [26.2, HALL_PARAPET, 20.8], "wall_ext"],
    ]


def site_boxes() -> List[list]:
    return [
        # neighbours (dressing): Hallam Furniture (west, blank), Keston Row (north, across the alley), the Tolley St
        # offices (east), the Corliss Hotel, the diner and apartments (south, across Marlin Ave)
        ["Neighbours", "Hallam", [-20.0, 0.0, 0.0], [-3.0, 8.0, 28.2], "wall_ext"],
        ["Neighbours", "KestonRow", [-12.0, 0.0, -24.0], [36.2, 10.0, -6.2], "wall_ext"],
        ["Neighbours", "OfficesE", [48.0, 0.0, -24.0], [64.0, 16.0, 28.0], "wall_ext"],
        ["Neighbours", "Corliss", [-20.0, 0.0, 48.0], [20.0, 18.0, 56.0], "wall_ext"],
        ["Neighbours", "AllNightDiner", [20.0, 0.0, 48.0], [36.0, 6.0, 56.0], "wall_ext"],
        ["Neighbours", "Apartments", [36.0, 0.0, 48.0], [64.0, 15.0, 56.0], "wall_ext"],
        # closures (doc Play-space closure)
        ["Closures", "AlleyGateW", [-12.1, 0.0, -6.2], [-11.9, 2.4, 0.0], "frame"],
        ["Closures", "RoadworksW", [-20.2, 0.0, 28.2], [-20.0, 2.4, 48.0], "frame"],
        ["Closures", "WorksVanW", [-19.0, 0.0, 41.0], [-17.0, 2.4, 46.0], "prop"],
        ["Closures", "NightBusE", [61.0, 0.0, 33.0], [63.6, 3.4, 45.0], "prop"],
        ["Closures", "BarriersE", [63.8, 0.0, 28.0], [64.0, 2.4, 48.0], "frame"],
        ["Closures", "RefuseTruck", [38.0, 0.0, -19.0], [46.0, 3.4, -17.0], "prop"],
        ["Closures", "TolleyNEnd", [36.2, 0.0, -24.2], [48.0, 2.4, -24.0], "frame"],
        # landmarks: the VELVET marquee over the entrance, the blade sign on the corner
        ["Landmarks", "Marquee", [11.0, 3.6, 28.2], [23.0, 4.0, 31.0], "prop"],
        ["Landmarks", "BladeSign", [35.4, 4.6, 27.6], [36.4, 12.0, 28.2], "prop"],
    ]


def nav_cull() -> List[list]:
    return [
        ["HallRoof", [0.0, 7.0, 26.0, 21.0], 8.8, 2.0], ["FrontRoof", [0.0, 21.0, 26.0, 28.0], 8.0, 2.0],
        ["EastRoof", [26.0, 7.0, 36.0, 28.0], 8.0, 2.0], ["Marquee", [11.0, 28.2, 23.0, 31.0], 4.0, 2.0],
        ["Hallam", [-20.0, 0.0, -3.0, 28.2], 8.0, 3.0], ["KestonRow", [-12.0, -24.0, 36.2, -6.2], 10.0, 3.0],
        ["OfficesE", [48.0, -24.0, 64.0, 28.0], 16.0, 3.0], ["Corliss", [-20.0, 48.0, 20.0, 56.0], 18.0, 3.0],
        ["AllNightDiner", [20.0, 48.0, 36.0, 56.0], 6.0, 3.0], ["Apartments", [36.0, 48.0, 64.0, 56.0], 15.0, 3.0],
        ["WorksVanW", [-19.0, 41.0, -17.0, 46.0], 2.4, 2.0], ["NightBusE", [61.0, 33.0, 63.6, 45.0], 3.4, 2.0],
        ["RefuseTruck", [38.0, -19.0, 46.0, -17.0], 3.4, 2.0],
    ]


def oob() -> List[list]:
    return [
        ["OobAlleyW", [-20.0, -1.0, -6.2, -12.2, 6.0, 0.0]],
        ["OobTolleyN", [36.2, -1.0, -30.0, 48.0, 6.0, -24.2]],
        ["OobMarlinW", [-28.0, -1.0, 28.2, -20.2, 6.0, 48.0]],
        ["OobMarlinE", [64.2, -1.0, 28.0, 72.0, 6.0, 48.0]],
    ]
