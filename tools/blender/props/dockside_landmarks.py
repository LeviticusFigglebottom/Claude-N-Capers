"""Dockside Burn landmarks (DB-1 follow-ups; docs/design/heists/dockside_burn.md Site / Play-space closure): the Pier 10
rail-mounted gantry crane (landmark 2, sniper perch S1 in its cab) and the moored trawler east of the landing stage
(rare perch S4 on its wheelhouse roof).

Both are site dressing the generator instances under Site/Blocks over their unchanged collision blocks
(dockside_burn_layout.gd BLOCKS `Crane*` / `Trawler*`, drawn `none`), as the launch (D-111). They are modelled in
map coordinates around a fixed pivot so every collider face can be matched exactly:

    blender (x, y, z) = (map x - pivot x, -(map z - pivot z), map y - pivot y)

with yaw 0 in the map (Blender +Y = Godot -Z). Every part a crew member could walk into stays inside a layout
collider; the parts outside the colliders are out of reach (over the water, or 20 m up).

* `veh_gantry_crane` (pivot (77, 0, 0)): four box legs on rail bogies (x 74 / 80, z +-8; each bogie has its own
  layout collider) over two embedded crane rails, the portal beams and the two girders at +20 / +22, knee braces, the
  A-frame struts and an apex with stays holding the 54 m box boom (x 56-110, +25.6) with its trolley rails, the
  trolley parked on the boom tail (out of the S1 view) and its spreader, the machinery house on the boom tail, boom floods, the operator
  cab (S1) on the east girder with a walkable floor plate at +22.2, the open full-height front (the Longshot's view),
  side windows and a back door to the girder walkway, the caged access ladder up the NE leg.
* `prop_beacon_hazard` (a fixture, group exterior: no visibility range): the crane's two rotating hazard beacons; the
  map places them on the portal beams at (77, +22, +-8) under its CraneBeaconLight omnis (+22.7).
* `veh_trawler_dockside` (pivot (71.5, -3.4, 50.8)): a 17 m stern trawler, bow west: navy topsides over an
  anti-fouling boot top (the harbour water is at -2.4), a whaleback forecastle, the main deck 0.8 m under the bulwark
  cap at the collider top (+0.5), tyre fenders on the landing-stage side, the wheelhouse (S4 on its flat roof at +4.0,
  a low roof rail, searchlight, radar) with its window band, the mast (x 75) with the outrigger booms raised in a V,
  the stern A-frame gantry with the otter boards, the net drum, a net pile and floats, a trawl winch, the fish-hold
  hatch, fish boxes.
"""

import math

from _pb import Kit

TRI_BUDGET = 24000
_G = "dockside"
VARIANTS = {
    "veh_gantry_crane": {"fn": "gantry_crane", "cat": {"kind": "crane", "place": "none", "group": _G, "pin_only": True}},
    "veh_trawler_dockside": {"fn": "trawler_db", "cat": {"kind": "boat", "place": "none", "group": _G, "pin_only": True}},
    "prop_beacon_hazard": {"fn": "beacon_hazard", "cat": {"kind": "light_fixture", "place": "none", "fixture": True,
                                                          "group": "exterior", "pin_only": True}},
}

STRUCT = "metal_orange"   # crane steel: weathered orange (palette: rust family; the flare orange stays on the beacons)
E = 0.01  # visual inset from the collider faces


class _Map:
    """Map-coordinate front end for a Part (see the module doc)."""

    def __init__(self, pivot: tuple[float, float, float]) -> None:
        self.px, self.py, self.pz = pivot

    def v(self, x: float, y: float, z: float) -> tuple[float, float, float]:
        return (x - self.px, -(z - self.pz), y - self.py)

    def box(self, part, lo: tuple[float, float, float], hi: tuple[float, float, float], key: str) -> None:
        a, b = self.v(*lo), self.v(*hi)
        part.bx((min(a[0], b[0]), min(a[1], b[1]), min(a[2], b[2])), (max(a[0], b[0]), max(a[1], b[1]), max(a[2], b[2])), key)

    def rod(self, part, p0, p1, r: float, key: str, segs: int = 8, square: bool = False) -> None:
        part.rod(self.v(*p0), self.v(*p1), r, key, segs=segs, square=square)

    def cyl(self, part, r: float, depth: float, c, key: str, axis: str = "Y", segs: int = 16) -> None:
        """axis: map axis (X / Y / Z) -> Blender X / Z / Y."""
        part.cyl(r, depth, self.v(*c), key, axis={"X": "X", "Y": "Z", "Z": "Y"}[axis], segs=segs)


# ------------------------------------------------------------------------------------------------ crane

LEG_X = (74.0, 80.0)
LEG_Z = (-8.0, 8.0)
CRANE_PIVOT = (77.0, 0.0, 0.0)


def _crane_legs(m: _Map, s, d, y) -> None:
    for lx in LEG_X:
        for lz in LEG_Z:
            m.box(s, (lx - 0.5 + E, 1.2, lz - 0.5 + E), (lx + 0.5 - E, 20.5, lz + 0.5 - E), STRUCT)
            # hazard bands at the foot (proud 4 mm, still inside the 1 x 1 m leg collider)
            for i in range(4):
                y0 = 1.6 + i * 0.5
                m.box(y if i % 2 == 0 else d, (lx - 0.5 + E - 0.004, y0, lz - 0.5 + E - 0.004),
                      (lx + 0.5 - E + 0.004, y0 + 0.25, lz + 0.5 - E + 0.004), "metal_yellow" if i % 2 == 0 else "metal_dark")
            # bogie under the leg (its own layout collider CraneBogie*: x lx +-0.5, z lz +-1.5, y 0..1.65): the equaliser
            # beam, two wheels on the rail in their side plates, end buffers, the travel drives on top
            m.box(d, (lx - 0.42, 0.5, lz - 1.42), (lx + 0.42, 1.25, lz + 1.42), "metal_dark")
            for sz in (-1.0, 1.0):
                m.cyl(d, 0.4, 0.16, (lx, 0.43, lz + sz * 0.95), "steel", axis="X", segs=16)
                m.box(d, (lx - 0.4, 0.12, lz + sz * 0.95 - 0.45), (lx - 0.12, 0.52, lz + sz * 0.95 + 0.45), "metal_dark")
                m.box(d, (lx + 0.12, 0.12, lz + sz * 0.95 - 0.45), (lx + 0.4, 0.52, lz + sz * 0.95 + 0.45), "metal_dark")
                z0, z1 = sorted((lz + sz * 1.41, lz + sz * 1.49))
                m.box(y, (lx - 0.3, 0.6, z0), (lx + 0.3, 1.0, z1), "metal_yellow")
                m.cyl(d, 0.2, 0.6, (lx, 1.43, lz + sz * 1.0), "metal_dark", axis="X", segs=12)


def _crane_rails(m: _Map, r) -> None:
    """Two crane rails embedded in the Pier 10 slab (head 3 cm proud), clear of the gangway landing (z -14..-12)."""
    for lx in LEG_X:
        m.box(r, (lx - 0.04, 0.0, -11.5), (lx + 0.04, 0.03, 11.5), "steel")
        m.box(r, (lx - 0.2, 0.0, -11.5), (lx - 0.12, 0.008, 11.5), "metal_dark")
        m.box(r, (lx + 0.12, 0.0, -11.5), (lx + 0.2, 0.008, 11.5), "metal_dark")


def _crane_portal(m: _Map, s) -> None:
    for lz in LEG_Z:  # portal beams (N / S), x 73.5-80.5, +20..+22
        m.box(s, (73.5 + E, 20.0 + E, lz - 0.5 + E), (80.5 - E, 21.0, lz + 0.5 - E), STRUCT)
    for lx in LEG_X:  # girders (W / E) along z on top, +21..+22
        m.box(s, (lx - 0.5 + E, 21.0, -8.5 + E), (lx + 0.5 - E, 22.0 - E, 8.5 - E), STRUCT)
    for lz in LEG_Z:  # portal top between the girders
        m.box(s, (74.45, 21.0, lz - 0.5 + E), (79.55, 22.0 - E, lz + 0.5 - E), STRUCT)
    # knee braces in the portal planes and the girder planes
    for lz in LEG_Z:
        m.rod(s, (74.5, 16.5, lz), (77.0, 20.05, lz), 0.18, STRUCT, square=True)
        m.rod(s, (79.5, 16.5, lz), (77.0, 20.05, lz), 0.18, STRUCT, square=True)
    for lx in LEG_X:
        for sz in (-1.0, 1.0):
            m.rod(s, (lx, 16.5, sz * 7.5), (lx, 21.05, sz * 3.5), 0.16, STRUCT, square=True)
    # cab supports under the cab floor: two brackets from the east girder west to the cab front (x 76.5)
    for z in (-1.7, 1.7):
        m.box(s, (76.55, 21.55, z - 0.12), (79.55, 22.0, z + 0.12), STRUCT)
        m.rod(s, (79.5, 20.6, z), (76.7, 21.6, z), 0.08, STRUCT, square=True)


def _crane_walkway(m: _Map, w) -> None:
    """Girder walkway on brackets east of the east girder (x 80.5-81.9, +22.0), from the ladder head at the NE leg
    (z -8) to the cab's back door (z -1.5..-0.6); the ladder comes up through the opening at x 80.5-80.95."""
    m.box(w, (80.5, 21.96, -7.7), (81.9, 22.0, -0.4), "metal_graphite")
    m.box(w, (80.95, 21.96, -8.6), (81.9, 22.0, -7.7), "metal_graphite")
    for z in (-8.3, -5.5, -3.0, -0.7):
        m.rod(w, (80.5, 21.25, z), (81.85, 21.95, z), 0.04, "metal_graphite", segs=6)
        m.rod(w, (81.86, 22.0, z), (81.86, 23.1, z), 0.022, "metal_yellow", segs=6)
    for hy in (22.55, 23.1):
        m.rod(w, (81.86, hy, -8.58), (81.86, hy, -0.42), 0.022, "metal_yellow", segs=6)
        m.rod(w, (80.97, hy, -8.58), (81.86, hy, -8.58), 0.022, "metal_yellow", segs=6)
        m.rod(w, (81.02, hy, -0.42), (81.86, hy, -0.42), 0.022, "metal_yellow", segs=6)


def _crane_boom(m: _Map, s, w, e) -> None:
    # the boom: a 2 x 1 m box girder, x 56-110, +25.6..+26.6, side stiffeners every 3 m, trolley rails on top
    m.box(s, (56.0 + E, 25.6 + E, -1.0 + E), (110.0 - E, 26.6 - E, 1.0 - E), STRUCT)
    x = 57.5
    while x < 109.0:
        for sz in (-1.0, 1.0):
            z0, z1 = sorted((sz * (1.0 - E), sz * (1.0 - E + 0.05)))
            m.box(s, (x - 0.08, 25.62, z0), (x + 0.08, 26.58, z1), STRUCT)
        x += 3.0
    for z in (-0.6, 0.6):
        m.box(w, (56.2, 26.58, z - 0.06), (109.8, 26.69, z + 0.06), "steel")
    # A-frame struts from the girder ends up to the boom underside (over the cab roof: at z +-2 they are at +25.0)
    for lx in LEG_X:
        for sz in (-1.0, 1.0):
            m.rod(s, (lx, 21.95, sz * 7.8), (lx, 25.65, sz * 0.8), 0.16, STRUCT, square=True)
    # apex and stays
    for sz in (-1.0, 1.0):
        m.rod(s, (77.0, 26.55, sz * 0.75), (77.0, 33.0, sz * 0.4), 0.22, STRUCT, square=True)
        for tx in (58.0, 66.0, 96.0, 107.0):
            m.rod(w, (77.0, 32.8, sz * 0.4), (tx, 26.6, sz * 0.85), 0.05, "steel", segs=6)
    m.box(s, (76.7, 32.9, -0.65), (77.3, 33.4, 0.65), STRUCT)
    m.cyl(e, 0.12, 0.2, (77.0, 33.49, 0.0), "emit_led_red", axis="Y", segs=10)
    # boom floods (emissive lenses under the boom)
    for fx in (58.5, 70.0, 84.0, 94.0):
        m.box(s, (fx - 0.3, 25.25, -0.35), (fx + 0.3, 25.65, 0.35), "metal_dark")
        m.box(e, (fx - 0.24, 25.23, -0.28), (fx + 0.24, 25.25, 0.28), "emit_sodium")
    # machinery house on the boom tail (over the stacks)
    m.box(w, (98.0, 26.55, -1.6), (106.0, 29.2, 1.6), "hull_white")
    m.box(s, (97.9, 29.2, -1.7), (106.1, 29.35, 1.7), STRUCT)
    for xx in (99.5, 102.0, 104.5):
        for sz in (-1.0, 1.0):
            z0, z1 = sorted((sz * 1.6, sz * 1.608))
            m.box(w, (xx - 0.5, 27.6, z0), (xx + 0.5, 28.2, z1), "metal_dark")


def _crane_trolley(m: _Map, s, d) -> None:
    """Trolley parked at the boom tail behind the cab (x 89, over the Pier 10 stacks: out of the S1 view) with the
    headblock and a 40 ft spreader hanging at +17.6..+18.6."""
    T = 89.0
    m.box(s, (T - 1.4, 26.7, -1.3), (T + 1.4, 27.7, 1.3), STRUCT)
    m.box(d, (T - 1.2, 27.65, -0.9), (T + 1.2, 28.1, 0.9), "metal_dark")
    for xx in (T - 1.1, T + 1.1):
        for z in (-0.6, 0.6):
            m.cyl(d, 0.22, 0.12, (xx, 26.9, z), "metal_dark", axis="Z", segs=10)
    for xx in (T - 0.6, T + 0.6):
        for z in (-0.5, 0.5):
            m.rod(d, (xx, 26.75, z), (xx, 19.05, z * 1.6), 0.03, "steel", segs=5)
    m.box(d, (T - 0.9, 18.55, -1.0), (T + 0.9, 19.1, 1.0), "metal_yellow")
    m.box(s, (T - 1.0, 17.8, -6.1), (T + 1.0, 18.3, 6.1), "metal_yellow")
    m.box(d, (T - 0.7, 18.25, -1.2), (T + 0.7, 18.6, 1.2), "metal_dark")
    for sz in (-1.0, 1.0):
        for xx in (T - 0.9, T + 0.9):
            m.box(d, (xx - 0.08, 17.6, sz * 6.0 - 0.08), (xx + 0.08, 17.82, sz * 6.0 + 0.08), "metal_dark")


def _crane_cab(m: _Map, c, g, w) -> None:
    """Operator cab (S1, the Longshot at (79, +22.2, 0)): floor plate at the collider top (+22.2), back wall at
    x 80.8-81 with the door to the walkway, roof +24.6..+24.8, the open full-height front (west) with mullions (the
    Longshot's view), side walls with windows; the operator's seat and joystick consoles behind the perch spot."""
    m.box(c, (76.5 + E, 22.0 + E, -2.0 + E), (81.0 - E, 22.2, 2.0 - E), "metal_graphite")
    m.box(c, (76.5 + E, 24.6, -2.0 + E), (81.0 - E, 24.8 - E, 2.0 - E), "hull_white")
    m.box(c, (80.8, 22.2, -2.0 + E), (81.0 - E, 24.6, -1.5), "hull_white")
    m.box(c, (80.8, 22.2, -0.6), (81.0 - E, 24.6, 2.0 - E), "hull_white")
    m.box(c, (80.8, 24.2, -1.5), (81.0 - E, 24.6, -0.6), "hull_white")
    m.box(w, (80.82, 22.2, -1.5), (80.97, 24.2, -0.6), "metal_dark")
    for z in (-1.95, -0.65, 0.65, 1.95):
        m.box(c, (76.52, 22.2, z - 0.05), (76.62, 24.6, z + 0.05), "metal_graphite")
    m.box(c, (76.52, 24.35, -2.0 + E), (76.62, 24.6, 2.0 - E), "metal_graphite")
    for sz in (-1.0, 1.0):
        z0, z1 = sorted((sz * (2.0 - E), sz * (2.0 - E - 0.06)))
        m.box(c, (76.62, 22.2, z0), (80.8, 23.0, z1), "hull_white")
        m.box(c, (76.62, 24.25, z0), (80.8, 24.6, z1), "hull_white")
        m.box(g, (76.62, 23.0, z0 + 0.02), (80.8, 24.25, z1 - 0.02), "glass_tinted")
        m.box(c, (78.6, 23.0, z0), (78.7, 24.25, z1), "metal_graphite")
    m.box(w, (79.95, 22.2, -0.3), (80.4, 22.65, 0.3), "metal_dark")
    m.box(w, (80.25, 22.65, -0.3), (80.4, 23.3, 0.3), "metal_dark")
    for z in (-0.6, 0.6):
        m.box(w, (79.65, 22.2, z - 0.15), (80.2, 22.85, z + 0.15), "metal_graphite")
    m.box(w, (80.5, 23.6, 0.2), (80.8, 24.2, 1.4), "metal_grey")


def _crane_ladder(m: _Map, w) -> None:
    """Caged access ladder up the NE leg's east face (from 2.4 m: the bottom section is lifted, anti-climb) to the
    walkway opening at +22.0, its stiles carried up 1.1 m as grab rails."""
    lx, lz = 80.72, -8.0
    for z in (lz - 0.22, lz + 0.22):
        m.rod(w, (lx, 2.4, z), (lx, 23.1, z), 0.025, "metal_yellow", segs=6)
        for by in (2.6, 12.0):
            m.rod(w, (80.5, by, z), (lx, by, z), 0.02, "metal_yellow", segs=5)
    yy = 2.7
    while yy < 21.9:
        m.rod(w, (lx, yy, lz - 0.22), (lx, yy, lz + 0.22), 0.014, "metal_yellow", segs=5)
        yy += 0.3
    cx = lx + 0.36
    h = 3.4
    while h < 21.5:
        pts = [(lx, h, lz - 0.36)]
        for i in range(7):
            a = -math.pi / 2 + math.pi * i / 6
            pts.append((cx + 0.36 * math.cos(a), h, lz + 0.36 * math.sin(a)))
        pts.append((lx, h, lz + 0.36))
        for i in range(len(pts) - 1):
            m.rod(w, pts[i], pts[i + 1], 0.012, "metal_yellow", segs=4)
        h += 1.0
    for a in (-1.2, 0.0, 1.2):
        px, pz = cx + 0.36 * math.cos(a), lz + 0.36 * math.sin(a)
        m.rod(w, (px, 3.4, pz), (px, 20.4, pz), 0.012, "metal_yellow", segs=4)


def _gantry_crane(k: Kit, p: dict) -> None:
    m = _Map(CRANE_PIVOT)
    o = k.obj("Crane")
    s, d, y, w, c, g, e, r = (o.part(bevel=0.0) for _ in range(8))
    _crane_legs(m, s, d, y)
    _crane_rails(m, r)
    _crane_portal(m, s)
    _crane_walkway(m, w)
    _crane_boom(m, s, w, e)
    _crane_trolley(m, s, d)
    _crane_cab(m, c, g, w)
    _crane_ladder(m, w)
    o.build()


def _beacon_hazard(k: Kit, p: dict) -> None:
    """Rotating hazard beacon (the crane's portal beams: the map's CraneBeaconLight omni sits 0.7 m over the pivot,
    inside the flare-orange dome): a base plate on the beam top, the drive housing, the dome."""
    o = k.obj("Beacon")
    b = o.part(bevel=0.0)
    b.bx((-0.25, -0.25, 0.0), (0.25, 0.25, 0.12), "metal_dark")
    b.cyl(0.17, 0.3, (0.0, 0.0, 0.27), "metal_dark", segs=12)
    b.lathe([(0.15, 0.0), (0.15, 0.22), (0.12, 0.33), (0.0, 0.38)], "emit_fire", centre=(0.0, 0.0, 0.42), segs=12)
    for a in range(4):
        ang = a * math.pi / 2
        b.rod((0.0, 0.0, 0.8), (0.16 * math.cos(ang), 0.16 * math.sin(ang), 0.42), 0.008, "metal_dark", segs=4)
    o.build()


# ---------------------------------------------------------------------------------------------- trawler

TRAWL_PIVOT = (71.5, -3.4, 50.8)
HULL_X = (63.0, 80.0)
HULL_HALF_B = 2.2
DECK = -0.3          # main deck, under the bulwark cap at the collider top (+0.5)
CAP = 0.5
BOW = 4.2


def _plan(inset: float, cut_x: float | None = None) -> list[tuple[float, float]]:
    """Hull plan as Blender (x, y) (symmetric about the centre line z 50.8): the bow west at x 63 (rounded), a transom
    stern at x 80; ``cut_x``: only the part west of that map x (the forecastle)."""
    x0, x1 = HULL_X[0] + E + inset, HULL_X[1] - E - inset
    b = HULL_HALF_B - E - inset
    if cut_x is not None:
        x1 = cut_x
    n = 9
    side = [(x0 + BOW - BOW * math.sin(i / n * math.pi / 2), b * math.cos(i / n * math.pi / 2)) for i in range(n)]
    pts = [(x1, -b * (0.9 if cut_x is None else 1.0)), (x1, b * (0.9 if cut_x is None else 1.0))]
    pts += side + [(x0, 0.0)] + [(sx, -sz) for sx, sz in reversed(side)]
    return [(px - TRAWL_PIVOT[0], pz) for px, pz in pts]


def _ring(h, outer: float, inner: float, y0: float, y1: float, key: str) -> None:
    py = TRAWL_PIVOT[1]
    h.prism(_plan(outer), holes=[_plan(inner)], axis="Z", start=y0 - py, end=y1 - py, mat=h.m(key))


def _trawler_hull(h) -> None:
    py = TRAWL_PIVOT[1]
    h.slab(_plan(0.3), -3.4 - py, -2.7 - py, "metal_red")      # keel / bilge (under water)
    _ring(h, 0.0, 0.1, -2.7, -2.25, "metal_red")                # anti-fouling boot top (water at -2.4)
    _ring(h, 0.0, 0.1, -2.25, CAP - 0.12, "hull_navy")          # topsides and the bulwark (inner face above the deck)
    _ring(h, -0.004, 0.05, -0.75, -0.6, "hull_white")          # sheer stripe
    _ring(h, -0.002, 0.12, CAP - 0.12, CAP, "hull_white")       # bulwark cap
    h.slab(_plan(0.105), DECK - 0.3 - py, DECK - py, "wood_pine")  # main deck
    h.slab(_plan(0.125, cut_x=67.5), DECK - 0.1 - py, CAP - 0.03 - py, "hull_navy")  # whaleback forecastle (x 63-67.5)
    h.slab(_plan(0.135, cut_x=67.49), CAP - 0.04 - py, CAP - py, "wood_pine")         # its planked deck


def _trawler_superstructure(m: _Map, wv, g, d) -> None:
    # wheelhouse x 68-72, z 49.6-52 (collider +0.5..+4.0): the deckhouse, the bridge's window band, the roof (S4 +4.0)
    lo_z, hi_z = 49.6 + E, 52.0 - E
    m.box(wv, (68.3, DECK - 0.05, lo_z), (72.0 - E, 2.4, hi_z), "hull_white")
    m.box(wv, (68.0 + E, 2.4, lo_z), (72.0 - E, 2.75, hi_z), "hull_white")
    m.box(wv, (68.0 + E, 3.6, lo_z), (72.0 - E, 3.92, hi_z), "hull_white")
    m.box(wv, (67.99, 3.9, 49.59), (72.01, 4.0, 52.01), "hull_navy")
    for z in (49.62, 50.4, 51.2, 51.98):
        m.box(wv, (68.02, 2.75, z - 0.04), (68.12, 3.6, z + 0.04), "hull_white")
    m.box(g, (68.1, 2.75, 49.66), (68.13, 3.6, 51.94), "glass_tinted")
    for z0, z1 in ((lo_z, 49.64), (51.96, hi_z)):
        m.box(g, (68.13, 2.75, z0), (71.6, 3.6, z1), "glass_tinted")
        m.box(wv, (71.6, 2.75, z0), (72.0 - E, 3.6, z1), "hull_white")
    m.box(g, (71.95, 2.75, 49.64), (71.99, 3.6, 51.96), "glass_tinted")
    m.box(d, (68.2, 2.75, 50.0), (68.6, 3.05, 51.6), "metal_dark")
    # side doors aft on the deckhouse, a life ring on the north face
    m.box(d, (70.9, DECK, 49.604), (71.6, 1.9, 49.62), "metal_dark")
    m.box(d, (70.9, DECK, 51.98), (71.6, 1.9, 51.996), "metal_dark")
    # roof rail (low, 0.5 m), searchlight, radar post and scanner
    for z in (49.64, 51.96):
        m.rod(d, (68.1, 4.5, z), (71.9, 4.5, z), 0.02, "metal_white", segs=5)
    for x in (68.1, 71.9):
        m.rod(d, (x, 4.5, 49.64), (x, 4.5, 51.96), 0.02, "metal_white", segs=5)
    for x in (68.1, 70.0, 71.9):
        for z in (49.64, 51.96):
            m.rod(d, (x, 4.0, z), (x, 4.5, z), 0.02, "metal_white", segs=5)
    m.cyl(d, 0.05, 1.2, (71.5, 4.6, 50.8), "metal_white", axis="Y", segs=8)
    m.box(d, (70.9, 5.2, 50.7), (72.1, 5.28, 50.9), "metal_dark")
    m.cyl(d, 0.14, 0.24, (68.5, 4.12, 50.2), "metal_dark", axis="Y", segs=10)
    m.cyl(g, 0.11, 0.05, (68.37, 4.2, 50.2), "emit_cool", axis="X", segs=10)


def _trawler_mast(m: _Map, d, s) -> None:
    """Mast at x 75 (collider 74.8-75.2, to +9.0) with a crosstree and the outrigger booms raised in a V; the stern
    A-frame gantry with the otter boards hung on its legs."""
    m.cyl(s, 0.17, 9.0 - DECK, (75.0, (9.0 + DECK) / 2, 50.8), "metal_white", axis="Y", segs=12)
    m.box(s, (74.9, 7.0, 50.0), (75.1, 7.12, 51.6), "metal_white")
    m.cyl(d, 0.07, 0.12, (75.0, 9.05, 50.8), "emit_cool", axis="Y", segs=8)
    for sz in (-1.0, 1.0):
        m.cyl(d, 0.06, 0.1, (75.0, 7.17, 50.8 + sz * 0.75), "emit_led_red" if sz < 0 else "emit_led_green", axis="Y", segs=8)
        m.rod(s, (75.0, 0.8, 50.8 + sz * 0.35), (75.3, 8.2, 50.8 + sz * 4.0), 0.09, "metal_orange", segs=8)
        m.rod(d, (75.0, 8.8, 50.8), (75.3, 8.2, 50.8 + sz * 4.0), 0.012, "steel", segs=4)
        m.rod(s, (79.4, CAP, 50.8 + sz * 1.85), (79.0, 5.2, 50.8 + sz * 1.3), 0.14, "metal_orange", segs=10)
        m.box(d, (78.6, 1.2, 50.8 + sz * 1.95 - 0.06), (79.6, 2.6, 50.8 + sz * 1.95 + 0.06), "metal_rust")
    m.rod(s, (79.0, 5.2, 49.4), (79.0, 5.2, 52.2), 0.14, "metal_orange", segs=10)
    m.cyl(d, 0.25, 0.5, (79.0, 4.9, 50.8), "metal_dark", axis="Z", segs=12)


def _trawler_deck_gear(m: _Map, d, n) -> None:
    # net drum (x 77.2) wound with net, the trawl winch aft of the wheelhouse, fish-hold hatch, fish boxes
    for sz in (-1.0, 1.0):
        m.cyl(d, 0.75, 0.06, (77.2, DECK + 1.2, 50.8 + sz * 1.2), "metal_dark", axis="Z", segs=18)
    m.cyl(n, 0.62, 2.34, (77.2, DECK + 1.2, 50.8), "net_green", axis="Z", segs=18)
    for sz in (-1.0, 1.0):
        m.box(d, (77.0, DECK - 0.02, 50.8 + sz * 1.36 - 0.06), (77.4, DECK + 1.25, 50.8 + sz * 1.36 + 0.06), "metal_dark")
        m.cyl(d, 0.32, 0.4, (73.0, DECK + 0.6, 50.8 + sz * 1.0), "metal_red", axis="Z", segs=14)
    m.box(d, (72.4, DECK - 0.02, 50.2), (73.6, DECK + 0.9, 51.4), "metal_dark")
    m.box(d, (75.6, DECK - 0.02, 50.3), (76.5, DECK + 0.25, 51.3), "metal_rust")
    for i, (x, z) in enumerate(((73.9, 49.2), (74.5, 49.2), (73.9, 52.4))):
        m.box(n, (x - 0.28, DECK - 0.02, z - 0.2), (x + 0.28, DECK + 0.3 + 0.28 * (i % 2), z + 0.2), "plastic_blue")
    # net pile on the aft deck with floats
    n.lathe([(1.0, 0.0), (0.95, 0.2), (0.7, 0.42), (0.3, 0.55), (0.0, 0.58)], "net_green",
            centre=m.v(78.4, DECK - 0.02, 49.75), segs=12, scale_xy=(0.9, 0.5))
    for i in range(5):
        a = i * 1.25
        m.cyl(d, 0.14, 0.2, (78.4 + 0.55 * math.cos(a), DECK + 0.42, 49.75 + 0.3 * math.sin(a)), "metal_orange", axis="Y",
              segs=10)
    # tyre fenders on the landing-stage side (north, z 48.6) on their lines, the life ring on the deckhouse
    for x in (65.5, 69.0, 73.0, 77.0):
        n.torus(0.32, 0.12, m.v(x, -0.9, 48.46), "rubber", segs=12, rsegs=6, axis="Y")
        m.rod(d, (x, CAP, 48.62), (x, -0.62, 48.5), 0.012, "rope_tan", segs=4)
    n.torus(0.3, 0.06, m.v(70.0, 1.5, 49.55), "metal_orange", segs=16, rsegs=6, axis="Y")


def _trawler_db(k: Kit, p: dict) -> None:
    m = _Map(TRAWL_PIVOT)
    o = k.obj("Trawler")
    h, wv, g, d, s, n = (o.part(bevel=0.0) for _ in range(6))
    _trawler_hull(h)
    _trawler_superstructure(m, wv, g, d)
    _trawler_mast(m, d, s)
    _trawler_deck_gear(m, d, n)
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
