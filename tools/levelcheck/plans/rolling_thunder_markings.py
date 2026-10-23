# Rolling Thunder road markings (RT-C2 G3, LEAD r305 punch list 1): painted lines, stop lines, crosswalks and lane
# arrows on Orchard Avenue, Tannery Road, the trench ramp and the underpass. Owner: ENV C. Emitted as MARKINGS by
# rolling_thunder_emit_layout.py; rt_markings.gd turns every quad into one visual-only mesh in the library paint
# (paint_white), MARK_LIFT above the asphalt (no collision, no bake, no shadow).
# Layout (rolling_thunder_site_ascii.py streets, the doc's Site section; right-hand traffic):
#   Orchard: carriageway x -10..10, median x -1..1; southbound x -10..-1, northbound x 1..10, two 4.5 m lanes each.
#   Tannery: carriageway z -8..8, no median; eastbound z 0..8 (the south half), westbound z -8..0; it runs down the
#            trench ramp (x 34..66, 0 -> -5) and through the underpass and the cut to x 104 at -5.
#   The junction: carriageways cross at x -10..10, z -8..8; crosswalks on the sidewalk lines, stop lines behind them.
# Every quad: 4 corners [x, y, z], counter-clockwise from above. y follows the grade (site_ascii.ramp_y).
from __future__ import annotations

import math
import os
import sys
from typing import List

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_site_ascii as ST  # noqa: E402

MARK_LIFT = 0.008                 # above the asphalt (zfight-safe at play distances; under the 0.02 decal kerb)
LINE_W = 0.12                     # lane / edge line width
STOP_W = 0.3                      # stop line width
DASH, GAP = 3.0, 6.0              # lane divider rhythm
ZEBRA_W, ZEBRA_PITCH = 0.5, 1.0   # crosswalk bars along the crossing direction
ORCHARD_N = (-90.0, -12.4)        # north arm (z), behind the stop line
ORCHARD_S = (12.4, 72.0)          # south arm
TANNERY_W = (-80.0, -14.8)        # west arm (x)
TANNERY_E = (14.8, 104.0)         # east arm: the forecourt, the ramp, the underpass and the cut
RAMP_BREAKS = (ST.RAMP_X[0], ST.RAMP_X[1])


def r3(v: float) -> float:
    return round(float(v) + 0.0, 3)


def _y(x: float) -> float:
    return r3(ST.ramp_y(x) + MARK_LIFT)


def _quad(x0: float, z0: float, x1: float, z1: float) -> List[float]:
    """Axis-aligned rectangle on the grade (x0 < x1, z0 < z1), corners CCW from above."""
    pts = [(x0, z0), (x0, z1), (x1, z1), (x1, z0)]
    out: List[float] = []
    for x, z in pts:
        out += [r3(x), _y(x), r3(z)]
    return out


def _x_run(xa: float, xb: float, z: float, w: float) -> List[List[float]]:
    """A solid line along x (split at the ramp's slope breaks so every quad is planar)."""
    cuts = [xa] + [b for b in RAMP_BREAKS if xa < b < xb] + [xb]
    return [_quad(cuts[i], z - w / 2.0, cuts[i + 1], z + w / 2.0) for i in range(len(cuts) - 1)]


def _x_dashed(xa: float, xb: float, z: float) -> List[List[float]]:
    out: List[List[float]] = []
    x = xa
    while x + DASH <= xb + 1e-6:
        out += _x_run(x, x + DASH, z, LINE_W)
        x += DASH + GAP
    return out


def _z_run(za: float, zb: float, x: float, w: float) -> List[List[float]]:
    return [_quad(x - w / 2.0, za, x + w / 2.0, zb)]


def _z_dashed(za: float, zb: float, x: float) -> List[List[float]]:
    out: List[List[float]] = []
    z = za
    while z + DASH <= zb + 1e-6:
        out += _z_run(z, z + DASH, x, LINE_W)
        z += DASH + GAP
    return out


def _arrow(cx: float, cz: float, heading: float) -> List[List[float]]:
    """A straight-ahead lane arrow (shaft 3 m + two 1.1 m head strokes at 35 deg), pointing along `heading` (deg, 0 =
    +x, 90 = +z), its tip at (cx, cz). Flat ground only."""
    out: List[List[float]] = []
    h = math.radians(heading)
    fx, fz = math.cos(h), math.sin(h)

    def bar(ax: float, az: float, bx: float, bz: float, w: float) -> List[float]:
        dx, dz = bx - ax, bz - az
        ln = math.hypot(dx, dz)
        nx, nz = -dz / ln * w / 2.0, dx / ln * w / 2.0
        pts = [(ax + nx, az + nz), (bx + nx, bz + nz), (bx - nx, bz - nz), (ax - nx, az - nz)]
        if (pts[1][0] - pts[0][0]) * (pts[2][1] - pts[0][1]) - (pts[1][1] - pts[0][1]) * (pts[2][0] - pts[0][0]) > 0:
            pts.reverse()
        q: List[float] = []
        for x, z in pts:
            q += [r3(x), _y(x), r3(z)]
        return q
    out.append(bar(cx - fx * 3.0, cz - fz * 3.0, cx - fx * 0.15, cz - fz * 0.15, 0.18))
    for side in (1.0, -1.0):
        a = h + math.pi + side * math.radians(35.0)
        out.append(bar(cx, cz, cx + math.cos(a) * 1.1, cz + math.sin(a) * 1.1, 0.16))
    return out


def markings() -> List[list]:
    """[feature, [quad, ...]] (quad = 12 floats: 4 corners x, y, z)."""
    cw = ST.ORCHARD_CW
    md = ST.MEDIAN
    tc = ST.TANNERY_CW
    rows: List[list] = []
    # Orchard: edge lines (kerb and median), lane dividers, per arm
    q: List[List[float]] = []
    for za, zb in (ORCHARD_N, ORCHARD_S):
        for x in (cw[0] + 0.15, md[0] - 0.15, md[2] + 0.15, cw[2] - 0.15):
            q += _z_run(za, zb, x, LINE_W)
        for x in (-5.5, 5.5):
            q += _z_dashed(za, zb, x)
    rows.append(["OrchardLines", q])
    # Tannery: double centre line, edge lines, lane dividers (west arm; east arm down the ramp and through the cut)
    q = []
    for xa, xb in (TANNERY_W, TANNERY_E):
        for z in (-0.12, 0.12, tc[1] + 0.15, tc[3] - 0.15):
            q += _x_run(xa, xb, z, 0.1 if abs(z) < 1.0 else LINE_W)
        for z in (-4.0, 4.0):
            q += _x_dashed(xa, xb, z)
    rows.append(["TanneryLines", q])
    # stop lines: southbound (Orchard N arm, west half), northbound (S arm, east half), eastbound (Tannery W arm, south
    # half), westbound (E arm, north half)
    rows.append(["StopLines", [
        _quad(cw[0] + 0.3, -12.4, md[0] - 0.3, -12.4 + STOP_W),
        _quad(md[2] + 0.3, 12.4 - STOP_W, cw[2] - 0.3, 12.4),
        _quad(-14.8, 0.3, -14.8 + STOP_W, tc[3] - 0.3),
        _quad(14.8 - STOP_W, tc[1] + 0.3, 14.8, -0.3),
    ]])
    # crosswalks (zebra bars across the crossing) on the junction's sidewalk lines
    q = []
    for za, zb in ((-11.4, -8.8), (8.8, 11.4)):     # across Orchard's north / south arms (bars along x)
        x = cw[0] + 0.5
        while x + ZEBRA_W <= cw[2] - 0.5 + 1e-6:
            if not (md[0] - 0.2 < x + ZEBRA_W and x < md[2] + 0.2):
                q.append(_quad(x, za, x + ZEBRA_W, zb))
            x += ZEBRA_PITCH
    for xa, xb in ((-13.6, -11.0), (11.0, 13.6)):    # across Tannery's west / east arms (bars along z)
        z = tc[1] + 0.5
        while z + ZEBRA_W <= tc[3] - 0.5 + 1e-6:
            q.append(_quad(xa, z, xb, z + ZEBRA_W))
            z += ZEBRA_PITCH
    rows.append(["Crosswalks", q])
    # lane arrows 4 m behind each stop line, one per lane, pointing the way of travel
    q = []
    for x in (-7.75, -3.25):
        q += _arrow(x, -16.4, 90.0)                  # southbound (+z)
    for x in (3.25, 7.75):
        q += _arrow(x, 16.4, -90.0)                  # northbound (-z)
    for z in (2.0, 6.0):
        q += _arrow(-18.8, z, 0.0)                   # eastbound (+x)
    for z in (-2.0, -6.0):
        q += _arrow(18.8, z, 180.0)                  # westbound (-x)
    rows.append(["LaneArrows", q])
    return rows


if __name__ == "__main__":
    for nm, qs in markings():
        print(nm, len(qs))
