"""Ostrander Federal G2 landmarks and room pieces (OF-C2 lane B; docs/design/heists/ostrander_federal.md Site /
Floor plans / Audio-lighting). Every piece is a visual over unchanged G1 colliders (the generator hides the greybox mesh
it replaces, of_landmarks.gd / of_art_rooms.gd), so each is modelled to the collider box it dresses, to the millimetre.

Landmarks (map-coordinate pieces use the dockside_landmarks `_Map` frame: blender (x, y, z) = (map x - px,
-(map z - pz), map y - py), placed at the pivot with yaw 0; facade pieces are wall props, back at y 0, placed yaw 180):
* `prop_of_sunburst` (facade, pivot (24, 0, 36.2), yaw 180): the 4 m gilded sunburst disc over the bronze doors and
  the limestone frieze below it with the bank's name cut in (dark bronze inlay).
* `prop_of_bronze_portal` (same pivot): the bronze surround of the two bronze doors: jambs, a transom grille and a
  cornice, clear of the door prefabs' own frames (x 21.83-26.18, up to 2.27).
* `prop_of_lantern` (map pivot (22, 8.6, 26)): bronze glazing bars over the G1 lantern hull (glass, group
  see_through: untouched), hips, ridge, eaves, purlins, ridge finials, the curb's limestone skin and bronze flashing.
* `prop_of_teller_line` (map pivot (24, 0, 17)): the banking counter over the G1 boxes: the 1.05 m customer ledge
  (walnut panels, marble top), the 1.50 m solid screen base, the bandit-glass mullions and rails (12 windows), the
  bronze gate piers and header, the limestone bulkhead with a bronze band and cornice. Every G1 dimension is kept.
  The 12 teller work tops (over the `teller_worktop` boxes, 2.46 x 1.00 x 0.48: walnut cabinets, cash drawers on
  the teller side) and the brass grilles of the 6 closed windows are part of the same mesh (one object per material:
  the counter is seen from the whole hall).
* `prop_of_vault_portal` (map pivot (30, -4, 12.7)): the bronze architrave round the round vault door on the VC face,
  clear of the door visual's lip ring and studs (r <= 1.27 about (30, -2.85)).
Rooms (wall / floor props, bottom-centre pivot, front +Y):
* `prop_of_box_unit_w950`: the SD double-sided box unit carcass (9.5 x 2.2 x 0.5): dark backing, stone plinth, end
  pilasters, a brass band and a bronze cornice. Its doors are MultiMesh tiles (of_art_rooms.gd).
* `prop_of_box_door_s` / `_m` / `_l`: one box door tile (0.2 x 0.15 / 0.2 x 0.225 / 0.4 x 0.225), back at y 0,
  centred: the MultiMesh meshes of the SD units and the VT walls.
* `prop_of_deposit_drawer` (deposit_box prefab visual, 0.6 x 0.45 door, flush): the 44 interactive boxes.
* `prop_of_booth_counter_w900`, `prop_of_booth_partition`, `prop_of_attendant_desk_w160`, `prop_of_desk_vault_ops`,
  `prop_of_coffee_table_sq80`, `prop_of_coffee_service_w160`: exact-fit visuals of the G1 furniture boxes in SD, VO
  and PC.
"""

import math

import _pb
from _pb import Kit, knob, legs4, lettering

TRI_BUDGET = 60000
_G = "ostrander"
VARIANTS = {
    "prop_of_sunburst": {"fn": "sunburst", "cat": {"kind": "landmark", "place": "none", "group": _G, "pin_only": True,
                                                   "surface": "metal"}},
    "prop_of_bronze_portal": {"fn": "bronze_portal", "cat": {"kind": "landmark", "place": "none", "group": _G,
                                                             "pin_only": True, "surface": "metal"}},
    "prop_of_lantern": {"fn": "lantern", "cat": {"kind": "landmark", "place": "none", "group": _G, "pin_only": True,
                                                 "surface": "metal"}},
    "prop_of_teller_line": {"fn": "teller_line", "cat": {"kind": "landmark", "place": "none", "group": _G,
                                                         "pin_only": True, "surface": "wood"}},
    "prop_of_vault_portal": {"fn": "vault_portal", "cat": {"kind": "landmark", "place": "none", "group": _G,
                                                           "pin_only": True, "surface": "metal"}},
    "prop_of_box_unit_w950": {"fn": "box_unit", "cat": {"kind": "deposit_boxes", "place": "none", "group": _G,
                                                        "pin_only": True, "surface": "metal"}},
    "prop_of_box_door_s": {"fn": "box_door", "w": 0.2, "h": 0.15, "cat": {"kind": "box_door", "place": "none",
                                                                          "group": _G, "pin_only": True}},
    "prop_of_box_door_m": {"fn": "box_door", "w": 0.2, "h": 0.225, "cat": {"kind": "box_door", "place": "none",
                                                                           "group": _G, "pin_only": True}},
    "prop_of_box_door_l": {"fn": "box_door", "w": 0.4, "h": 0.225, "cat": {"kind": "box_door", "place": "none",
                                                                           "group": _G, "pin_only": True}},
    "prop_of_box_bank_w320": {"fn": "box_bank", "w": 3.2, "cat": {"kind": "deposit_boxes", "place": "none",
                                                                  "group": _G, "pin_only": True, "surface": "metal"}},
    "prop_of_box_bank_w780": {"fn": "box_bank", "w": 7.8, "cat": {"kind": "deposit_boxes", "place": "none",
                                                                  "group": _G, "pin_only": True, "surface": "metal"}},
    "prop_of_box_bank_w1880": {"fn": "box_bank", "w": 18.8, "cat": {"kind": "deposit_boxes", "place": "none",
                                                                    "group": _G, "pin_only": True, "surface": "metal"}},
    "prop_of_deposit_drawer": {"fn": "deposit_drawer", "cat": {"prefab": "deposit_box", "kind": "deposit_box",
                                                               "mount": "wall", "surface": "metal"}},
    "prop_of_desk_pc": {"fn": "desk_pc", "cat": {"prefab": "hack_terminal", "kind": "hack_terminal",
                                                 "surface": "plastic"}},
    "prop_of_booth_counter_w900": {"fn": "booth_counter", "cat": {"kind": "counter", "place": "none", "group": _G,
                                                                  "pin_only": True, "support": True, "top": 0.9}},
    "prop_of_booth_partition": {"fn": "booth_partition", "cat": {"kind": "partition", "place": "none", "group": _G,
                                                                 "pin_only": True}},
    "prop_of_attendant_desk_w160": {"fn": "attendant_desk", "cat": {"kind": "desk", "place": "none", "group": _G,
                                                                    "pin_only": True, "support": True, "top": 0.75}},
    "prop_of_desk_vault_ops": {"fn": "desk_vault_ops", "cat": {"kind": "desk", "place": "none", "group": _G,
                                                               "pin_only": True, "support": True, "top": 0.75}},
    "prop_of_coffee_table_sq80": {"fn": "coffee_table", "cat": {"kind": "coffee_table", "place": "none", "group": _G,
                                                                "pin_only": True, "support": True, "top": 0.45}},
    "prop_of_coffee_service_w160": {"fn": "coffee_service", "cat": {"kind": "counter_service", "place": "none",
                                                                    "group": _G, "pin_only": True, "support": True,
                                                                    "top": 0.9}},
}

E = 0.002  # visual inset from a collider face

# D and F for the frieze (the shared stroke font lacks them; this module's builds only)
_pb.GLYPHS.setdefault("D", (0.66, [[(0.0, 0.0), (0.0, 1.0), (0.28, 1.0)] + _pb._arc(0.28, 0.5, 0.38, 0.5, 90, -90, 10)
                                   + [(0.0, 0.0)]]))
_pb.GLYPHS.setdefault("F", (0.5, [[(0.5, 1.0), (0.0, 1.0), (0.0, 0.0)], [(0.0, 0.53), (0.42, 0.53)]]))


class _Map:
    """Map-coordinate front end for a Part (as dockside_landmarks._Map)."""

    def __init__(self, pivot: tuple[float, float, float]) -> None:
        self.px, self.py, self.pz = pivot

    def v(self, x: float, y: float, z: float) -> tuple[float, float, float]:
        return (x - self.px, -(z - self.pz), y - self.py)

    def box(self, part, lo: tuple[float, float, float], hi: tuple[float, float, float], key: str) -> None:
        a, b = self.v(*lo), self.v(*hi)
        part.bx((min(a[0], b[0]), min(a[1], b[1]), min(a[2], b[2])), (max(a[0], b[0]), max(a[1], b[1]), max(a[2], b[2])),
                key)

    def rod(self, part, p0, p1, r: float, key: str, segs: int = 6, square: bool = False) -> None:
        part.rod(self.v(*p0), self.v(*p1), r, key, segs=segs, square=square)

    def sphere(self, part, r: float, c, key: str, segs: int = 12) -> None:
        part.sphere(r, self.v(*c), key, segs=segs, rings=max(4, segs // 2))


# ------------------------------------------------------------------------------------------------ facade

SUN_C = 5.7      # sunburst centre height (m above the plaza floor at the doors)
SUN_R = 1.95


def _sunburst(k: Kit, p: dict) -> None:
    """Wall prop (back y 0, front +Y = the plaza): the gilded disc, 32 rays in relief, the boss; the frieze."""
    o = k.obj("Sunburst")
    plate = o.part(bevel=0.004)
    gilt = o.part(bevel=0.003)
    rim = o.part(bevel=0.0)
    plate.cyl(SUN_R, 0.05, (0.0, 0.004 + 0.025, SUN_C), "of_bronze_dark", axis="Y", segs=64)
    rim.torus(SUN_R - 0.03, 0.045, (0.0, 0.06, SUN_C), "of_gilt", segs=64, rsegs=8, axis="Y")
    rim.torus(0.8, 0.03, (0.0, 0.1, SUN_C), "of_gilt", segs=48, rsegs=6, axis="Y")
    n = 32
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        r0 = 0.82
        r1 = SUN_R - 0.1 if i % 2 == 0 else SUN_R - 0.42
        hw0 = 0.07 if i % 2 == 0 else 0.055
        ca, sa = math.cos(a), math.sin(a)
        tx, tz = -sa, ca
        pts = [(r0 * ca + tx * hw0, SUN_C + r0 * sa + tz * hw0), (r1 * ca, SUN_C + r1 * sa),
               (r0 * ca - tx * hw0, SUN_C + r0 * sa - tz * hw0)]
        gilt.profile_y(pts, 0.054, 0.085 if i % 2 == 0 else 0.075, "of_gilt")
    # the boss: stepped discs, gilt face, a bronze ring of studs
    gilt.cyl(0.74, 0.07, (0.0, 0.09, SUN_C), "of_gilt", axis="Y", segs=48)
    gilt.cyl(0.56, 0.05, (0.0, 0.15, SUN_C), "of_bronze", axis="Y", segs=48)
    gilt.cyl(0.36, 0.04, (0.0, 0.195, SUN_C), "of_gilt", axis="Y", segs=40)
    for i in range(16):
        a = 2 * math.pi * i / 16
        gilt.cyl(0.035, 0.03, (math.cos(a) * 0.65, 0.14, SUN_C + math.sin(a) * 0.65), "of_bronze", axis="Y", segs=10)
    o.build()
    # the frieze: a limestone band with mouldings, the name cut in (dark bronze inlay, read from the plaza)
    f = k.obj("Frieze")
    st = f.part(bevel=0.006)
    ink = f.part(bevel=0.0)
    st.bx((-5.6, 0.004, 2.86), (5.6, 0.1, 3.56), "of_limestone")
    st.bx((-5.75, 0.004, 3.56), (5.75, 0.16, 3.68), "of_limestone")
    st.bx((-5.65, 0.004, 2.82), (5.65, 0.12, 2.86), "of_limestone")
    lettering(ink, "OSTRANDER FEDERAL", 0.38, 0.0, 0.1, 3.02, "of_bronze_dark", stroke=0.05, depth=0.008, inlay=True,
              spacing=0.3)
    f.build()


def _bronze_portal(k: Kit, p: dict) -> None:
    """Wall prop round both bronze doors (opening x +-2.1 about the pier, 2.2 high; the door prefabs' frames reach
    x +-2.175 and 2.27 high): jambs, a transom grille panel, a cornice, stone bases."""
    o = k.obj("Portal")
    br = o.part(bevel=0.004)
    gr = o.part(bevel=0.0)
    sb = o.part(bevel=0.006)
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * 2.2, sx * 2.46))
        br.bx((x0, 0.004, 0.32), (x1, 0.09, 2.3), "of_bronze")
        br.bx((x0 + 0.04, 0.09, 0.42), (x1 - 0.04, 0.105, 2.2), "of_bronze_dark")  # sunk panel line
        sb.bx((x0 - 0.04, 0.004, 0.0), (x1 + 0.04, 0.12, 0.32), "stone_dark")
    # transom: frame, dark ground, grille bars and rosettes
    br.bx((-2.46, 0.004, 2.3), (2.46, 0.09, 2.36), "of_bronze")
    br.bx((-2.46, 0.004, 2.7), (2.46, 0.09, 2.76), "of_bronze")
    br.bx((-2.2, 0.004, 2.36), (2.2, 0.02, 2.7), "of_bronze_dark")
    x = -2.1
    while x <= 2.1001:
        gr.bx((x - 0.012, 0.02, 2.36), (x + 0.012, 0.05, 2.7), "of_bronze")
        x += 0.15
    gr.bx((-2.2, 0.02, 2.515), (2.2, 0.05, 2.545), "of_bronze")
    x = -2.025
    while x <= 2.03:
        gr.cyl(0.04, 0.025, (x, 0.06, 2.53), "of_gilt", axis="Y", segs=12)
        x += 0.3
    # cornice over the portal (under the frieze at 2.82)
    br.bx((-2.62, 0.004, 2.76), (2.62, 0.15, 2.8), "of_bronze")
    o.build()


# ------------------------------------------------------------------------------------------------ lantern

_lant = _Map((22.0, 8.6, 26.0))
L_X0, L_X1, L_Z0, L_Z1, L_Y0, L_Y1 = 14.0, 30.0, 22.0, 30.0, 9.2, 14.2
L_RX0, L_RX1 = 18.0, 26.0   # ridge ends
L_OFF = 0.04                # bar centre off the glass plane


def _lantern(k: Kit, p: dict) -> None:
    """Bronze glazing bars over the G1 hull (hipped: base 14-30 x 22-30 at +9.2, ridge 18-26 at +14.2, z 26)."""
    o = k.obj("Lantern")
    bars = o.part(bevel=0.0)
    fin = o.part(bevel=0.0)
    ln = math.hypot(4.0, 5.0)

    def off(nx: float, ny: float, nz: float, d: float = L_OFF) -> tuple[float, float, float]:
        return (nx / ln * d, ny / ln * d, nz / ln * d)

    r = 0.026
    # N and S faces: rafters at x 15..29 from the eave to the hip / ridge
    for sgn, z0 in ((-1.0, L_Z0), (1.0, L_Z1)):
        o3 = off(0.0, 4.0, 5.0 * sgn)
        for xi in range(15, 30):
            x = float(xi)
            s1 = min(1.0, (x - L_X0) / 4.0, (L_X1 - x) / 4.0)
            a = (x + o3[0], L_Y0 + 0.02 + o3[1], z0 + o3[2] - sgn * 0.016)
            b = (x + o3[0], L_Y0 + 5.0 * s1 + o3[1], z0 - sgn * 4.0 * s1 + o3[2])
            _lant.rod(bars, a, b, r, "of_bronze")
        for s in (1.0 / 3.0, 2.0 / 3.0):
            y = L_Y0 + 5.0 * s
            z = z0 - sgn * 4.0 * s
            _lant.rod(bars, (L_X0 + 4.0 * s + o3[0], y + o3[1], z + o3[2]), (L_X1 - 4.0 * s + o3[0], y + o3[1], z + o3[2]),
                     r * 0.85, "of_bronze")
        _lant.rod(bars, (L_X0, L_Y0 + 0.03, z0 - sgn * 0.02), (L_X1, L_Y0 + 0.03, z0 - sgn * 0.02), 0.04, "of_bronze_dark")
    # W and E faces (triangles): rafters at z 23..29
    for sgn, x0 in ((-1.0, L_X0), (1.0, L_X1)):
        o3 = off(5.0 * sgn, 4.0, 0.0)
        for zi in range(23, 30):
            z = float(zi)
            s1 = min((z - L_Z0) / 4.0, (L_Z1 - z) / 4.0, 1.0)
            a = (x0 + o3[0] - sgn * 0.016, L_Y0 + 0.02 + o3[1], z + o3[2])
            b = (x0 - sgn * 4.0 * s1 + o3[0], L_Y0 + 5.0 * s1 + o3[1], z + o3[2])
            _lant.rod(bars, a, b, r, "of_bronze")
        for s in (1.0 / 3.0, 2.0 / 3.0):
            x = x0 - sgn * 4.0 * s
            y = L_Y0 + 5.0 * s
            _lant.rod(bars, (x + o3[0], y + o3[1], L_Z0 + 4.0 * s + o3[2]), (x + o3[0], y + o3[1], L_Z1 - 4.0 * s + o3[2]),
                     r * 0.85, "of_bronze")
        _lant.rod(bars, (x0 - sgn * 0.02, L_Y0 + 0.03, L_Z0), (x0 - sgn * 0.02, L_Y0 + 0.03, L_Z1), 0.04, "of_bronze_dark")
    # hips and ridge (heavier rolls), finials at the ridge ends
    hy = 0.05
    for (ax, az), (bx_, bz) in (((L_X0, L_Z0), (L_RX0, 26.0)), ((L_X0, L_Z1), (L_RX0, 26.0)),
                               ((L_X1, L_Z0), (L_RX1, 26.0)), ((L_X1, L_Z1), (L_RX1, 26.0))):
        _lant.rod(bars, (ax, L_Y0 + hy, az), (bx_, L_Y1 + hy, bz), 0.045, "of_bronze", segs=8)
    _lant.rod(bars, (L_RX0 - 0.05, L_Y1 + 0.06, 26.0), (L_RX1 + 0.05, L_Y1 + 0.06, 26.0), 0.055, "of_bronze", segs=8)
    for x in (L_RX0, L_RX1):
        _lant.sphere(fin, 0.12, (x, L_Y1 + 0.2, 26.0), "of_gilt", segs=14)
        _lant.rod(fin, (x, L_Y1 + 0.3, 26.0), (x, L_Y1 + 0.75, 26.0), 0.025, "of_gilt", segs=8)
        _lant.sphere(fin, 0.045, (x, L_Y1 + 0.78, 26.0), "of_gilt", segs=10)
        _lant.rod(fin, (x, L_Y1 + 0.06, 26.0), (x, L_Y1 + 0.12, 26.0), 0.08, "of_bronze_dark", segs=12)
    o.build()
    # curb skin: limestone 5-25 mm outside the 0.3 m curb, a bronze flashing cap over its outer edge
    c = k.obj("Curb")
    st = c.part(bevel=0.004)
    fl = c.part(bevel=0.002)
    t0, t1 = 0.005, 0.025
    y0, y1 = 8.6 + 0.004, 9.12
    _lant.box(st, (L_X0 - t1, y0, L_Z0 - t1), (L_X1 + t1, y1, L_Z0 - t0), "of_limestone")
    _lant.box(st, (L_X0 - t1, y0, L_Z1 + t0), (L_X1 + t1, y1, L_Z1 + t1), "of_limestone")
    _lant.box(st, (L_X0 - t1, y0, L_Z0 - t0), (L_X0 - t0, y1, L_Z1 + t0), "of_limestone")
    _lant.box(st, (L_X1 + t0, y0, L_Z0 - t0), (L_X1 + t1, y1, L_Z1 + t0), "of_limestone")
    f0, f1 = 0.045, 0.06
    _lant.box(fl, (L_X0 - f1, y1, L_Z0 - f1), (L_X1 + f1, 9.2 - 0.004, L_Z0 + f0), "of_bronze_dark")
    _lant.box(fl, (L_X0 - f1, y1, L_Z1 - f0), (L_X1 + f1, 9.2 - 0.004, L_Z1 + f1), "of_bronze_dark")
    _lant.box(fl, (L_X0 - f1, y1, L_Z0 + f0), (L_X0 + f0, 9.2 - 0.004, L_Z1 - f0), "of_bronze_dark")
    _lant.box(fl, (L_X1 - f0, y1, L_Z0 + f0), (L_X1 + f1, 9.2 - 0.004, L_Z1 - f0), "of_bronze_dark")
    c.build()


# ------------------------------------------------------------------------------------------------ counter

_tl = _Map((24.0, 0.0, 17.0))
RUNS = ((8.1, 22.9), (25.1, 39.9))
Z_SCR0, Z_SCR1, Z_LEDGE, Z_BULK = 16.83, 16.93, 17.45, 17.5
Z_GL0, Z_GL1 = 16.86, 16.9
BAYS = 6
## Closed windows (0-11, west to east): brass grilles; staffed: the bays of the stations x 13 / 15 / 17, 31 / 33 / 35.
CLOSED_WINDOWS = (0, 4, 5, 6, 7, 11)


def _bays(run: tuple[float, float]) -> list[float]:
    w = (run[1] - run[0]) / BAYS
    return [run[0] + i * w for i in range(BAYS + 1)]


def _teller_line(k: Kit, p: dict) -> None:
    """The banking counter over its G1 boxes (ScreenBase / CustomerLedge / BanditGlass W, E, the gate piers, header
    and the bulkhead), dimension for dimension: ledge 1.05 (front z 17.45), screen base 1.50 (z 16.83-16.93), bandit
    glass 1.50-2.40 (the G1 glass stays), bulkhead 2.40-4.20 to z 17.5."""
    o = k.obj("Counter")
    wd = o.part(bevel=0.003)
    st = o.part(bevel=0.004)
    br = o.part(bevel=0.0015)
    ls = o.part(bevel=0.006)
    for run in RUNS:
        a, b = run
        xs = _bays(run)
        # customer ledge: walnut carcass inside the collider, stone plinth, marble top (the full collider top)
        _tl.box(wd, (a, 0.12, Z_SCR1), (b, 1.0, Z_LEDGE - 0.02), "walnut")
        _tl.box(st, (a, 0.0, Z_SCR1), (b, 0.12, Z_LEDGE - 0.012), "stone_dark")
        _tl.box(st, (a, 1.0, Z_SCR1), (b, 1.05, Z_LEDGE), "marble")
        _tl.box(br, (a, 0.12, Z_LEDGE - 0.02), (b, 0.145, Z_LEDGE - 0.002), "of_bronze")
        _tl.box(br, (a, 0.965, Z_LEDGE - 0.02), (b, 0.99, Z_LEDGE - 0.002), "of_bronze")
        for i in range(BAYS):
            x0, x1 = xs[i] + 0.06, xs[i + 1] - 0.06
            # raised fielded panel per bay: stiles / rails flush with the face, the field 8 mm back
            _tl.box(wd, (x0, 0.17, Z_LEDGE - 0.02), (x1, 0.94, Z_LEDGE - 0.004), "walnut")
            _tl.box(wd, (x0 + 0.1, 0.25, Z_LEDGE - 0.004), (x1 - 0.1, 0.86, Z_LEDGE - 0.0), "walnut")
        for x in xs:
            lo, hi = max(a, x - 0.02), min(b, x + 0.02)
            _tl.box(br, (lo, 0.145, Z_LEDGE - 0.02), (hi, 0.965, Z_LEDGE - 0.001), "of_bronze")
        # screen base above the ledge and the work tops (y 1.00-1.50): walnut, a bronze cap rail
        _tl.box(wd, (a, 1.0, Z_SCR0), (b, 1.47, Z_SCR1), "walnut")
        _tl.box(br, (a, 1.47, Z_SCR0), (b, 1.5, Z_SCR1), "of_bronze")
        _tl.box(br, (a, 1.05, Z_SCR1), (b, 1.075, Z_SCR1 + 0.006), "of_bronze")
        # bandit glass: mullions at the 7 bay lines, a bottom and a top rail (the glass is the G1 box)
        for x in xs:
            lo, hi = max(a, x - 0.03), min(b, x + 0.03)
            _tl.box(br, (lo, 1.5, Z_SCR0 + 0.012), (hi, 2.4, Z_SCR1 - 0.012), "of_bronze")
        _tl.box(br, (a, 1.5, Z_SCR0 + 0.006), (b, 1.535, Z_SCR1 - 0.006), "of_bronze")
        _tl.box(br, (a, 2.365, Z_SCR0 + 0.006), (b, 2.4, Z_SCR1 - 0.006), "of_bronze")
    # gate piers and header: bronze cladding with flutes
    for x0, x1 in ((22.9, 23.4), (24.6, 25.1)):
        _tl.box(br, (x0, 0.0, Z_SCR0), (x1, 2.4, 17.03), "of_bronze_dark")
        for i in range(3):
            fx = x0 + 0.1 + i * 0.15
            _tl.box(br, (fx - 0.025, 0.25, 17.03), (fx + 0.025, 2.15, 17.036), "of_bronze")
        _tl.box(br, (x0 - 0.01, 0.0, Z_SCR0), (x1 + 0.01, 0.2, 17.045), "of_bronze")
    _tl.box(br, (23.4, 2.2, Z_SCR0), (24.6, 2.4, 17.03), "of_bronze")
    # bulkhead: limestone, a bronze band at its foot and a cornice at the TW ceiling line
    _tl.box(ls, (8.1, 2.4, Z_SCR0), (39.9, 4.2, Z_BULK), "of_limestone")
    _tl.box(br, (8.1, 2.4, Z_BULK), (39.9, 2.47, Z_BULK + 0.006), "of_bronze")
    _tl.box(ls, (8.1, 4.08, Z_BULK), (39.9, 4.2, Z_BULK + 0.05), "of_limestone")
    _tl.box(br, (8.1, 4.0, Z_BULK), (39.9, 4.03, Z_BULK + 0.02), "of_bronze")
    for run in RUNS:
        for x in _bays(run)[1:-1]:
            _tl.box(ls, (x - 0.09, 2.47, Z_BULK), (x + 0.09, 4.0, Z_BULK + 0.025), "of_limestone")
    # the 12 teller work tops (G1 boxes TellerWorktop01-12: centre x, z 16.59) and the 6 closed windows' grilles,
    # one mesh with the counter (perf: the counter is seen from the whole hall)
    idx = 0
    for run in RUNS:
        xs = _bays(run)
        for i in range(BAYS):
            cx = (xs[i] + xs[i + 1]) / 2
            _worktop_geom(wd, br, (cx - 24.0, -(16.59 - 17.0) + 0.0, 0.0))
            if idx in CLOSED_WINDOWS:
                _grille_geom(br, cx - 24.0)
            idx += 1
    o.build()


def _grille_geom(g, ox: float) -> None:
    """Brass grille closing one window (2.47 m bay less the mullions), on the hall face of the bandit glass
    (z 16.903-16.93), 1.535-2.365 m, centred on map x = 24 + ox (counter frame: pivot (24, 0, 17))."""
    hw = 1.2
    z0, z1 = 16.903, 16.926
    y0, y1 = 1.535, 2.365
    cx = 24.0 + ox
    x = -hw + 0.04
    while x <= hw - 0.0399:
        _tl.box(g, (cx + x - 0.007, y0, z0), (cx + x + 0.007, y1, z1), "brass")
        x += 0.08
    for y in (y0, y0 + 0.28, y1 - 0.28, y1 - 0.025):
        _tl.box(g, (cx - hw, y, z0), (cx + hw, y + 0.025, z1 + 0.004), "brass")
    x = -hw + 0.12
    while x <= hw - 0.1199:
        g.torus(0.06, 0.008, _tl.v(cx + x, (y0 + y1) / 2, z1 + 0.002), "brass", segs=16, rsegs=4, axis="Y")
        x += 0.16


def _worktop_geom(hard, trim, o: tuple[float, float, float]) -> None:
    """Teller work top 2.46 x 1.00 x 0.48 at Blender offset `o` (front +Y = the teller side): walnut cabinet, two
    cash drawers and cupboard doors on the teller side, a 30 mm top with a brass nosing; the back is solid."""
    w, d, h = 2.46, 0.48, 1.0
    y0, y1 = -d / 2, d / 2

    def b(v: tuple[float, float, float]) -> tuple[float, float, float]:
        return (v[0] + o[0], v[1] + o[1], v[2] + o[2])

    hard.bx(b((-w / 2 + E, y0 + E, 0.0)), b((w / 2 - E, y1 - 0.06, h - 0.03)), "walnut")
    hard.bx(b((-w / 2 + E, y1 - 0.06, 0.0)), b((w / 2 - E, y1 - 0.05, 0.09)), "stone_dark")
    hard.bx(b((-w / 2, y0, h - 0.03)), b((w / 2, y1, h)), "leather")
    trim.bx(b((-w / 2, y1 - 0.012, h - 0.034)), b((w / 2, y1, h - 0.002)), "brass")
    for i in range(2):
        x0 = -w / 2 + 0.06 + i * (w - 0.12) / 2
        x1 = x0 + (w - 0.12) / 2 - 0.02
        hard.bx(b((x0, y1 - 0.06, h - 0.2)), b((x1, y1 - 0.004, h - 0.05)), "walnut")
        trim.bx(b(((x0 + x1) / 2 - 0.08, y1 - 0.004, h - 0.13)), b(((x0 + x1) / 2 + 0.08, y1, h - 0.115)), "brass")
        for j in range(2):
            c0 = x0 + j * (x1 - x0) / 2 + 0.01
            c1 = x0 + (j + 1) * (x1 - x0) / 2 - 0.01
            hard.bx(b((c0, y1 - 0.06, 0.11)), b((c1, y1 - 0.004, h - 0.23)), "walnut")
            q = b(((c0 + c1) / 2 + (0.18 if j == 0 else -0.18), y1 - 0.004, h - 0.3))
            knob(trim, q[0], q[1], q[2])


def _vault_portal(k: Kit, p: dict) -> None:
    """Bronze architrave on the VC face (z 12.7) round the vault door: fluted jambs at |x - 30| 1.35-1.55, a head at
    -1.45..-1.2 and a half-sunburst lintel up to the ceiling (-0.8)."""
    m = _Map((30.0, -4.0, 12.7))
    o = k.obj("Portal")
    br = o.part(bevel=0.003)
    gl = o.part(bevel=0.0)
    zf, zb = 12.655, 12.698
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((30.0 + sx * 1.35, 30.0 + sx * 1.57))
        m.box(br, (x0, -4.0 + 0.004, zf), (x1, -1.2, zb), "of_bronze_dark")
        for i in range(3):
            fx = x0 + 0.05 + i * 0.06
            m.box(gl, (fx - 0.012, -3.75, zf - 0.006), (fx + 0.012, -1.5, zf), "of_bronze")
        m.box(br, (x0 - 0.02, -4.0 + 0.004, zf - 0.02), (x1 + 0.02, -3.78, zb), "of_bronze")
    m.box(br, (28.43 - 0.02, -1.45, zf - 0.02), (31.57 + 0.02, -1.2, zb), "of_bronze")
    m.box(br, (28.6, -1.2, zf + 0.01), (31.4, -0.84, zb), "of_bronze_dark")
    # half sunburst on the lintel: a gilt half disc and 9 rays, 10 mm in front of the lintel face (z 12.665)
    cx, cy = 30.0, -1.2
    by0, by1 = -(12.665 - 12.7), -(12.655 - 12.7)

    def plane(pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
        return [(x - 30.0, y + 4.0) for x, y in pts]

    half = [(cx + 0.28 * math.cos(math.pi * i / 16), cy + 0.28 * math.sin(math.pi * i / 16)) for i in range(17)]
    gl.profile_y(plane(half), by0, by1, "of_gilt")
    for i in range(9):
        a = math.pi * (i + 0.5) / 9
        ca, sa = math.cos(a), math.sin(a)
        r0 = 0.31
        rl = min(0.3 if i % 2 else 0.36, (-0.86 - cy) / sa - r0)
        if rl <= 0.03:
            continue
        tri = [(cx + ca * r0 - sa * 0.03, cy + sa * r0 + ca * 0.03), (cx + ca * (r0 + rl), cy + sa * (r0 + rl)),
               (cx + ca * r0 + sa * 0.03, cy + sa * r0 - ca * 0.03)]
        gl.profile_y(plane(tri), by0, by1, "of_gilt")
    o.build()


# ------------------------------------------------------------------------------------------------ deposit boxes

def _box_unit(k: Kit, p: dict) -> None:
    """SD box unit carcass 9.5 x 2.2 x 0.5 (double sided, faces y +-0.25): dark backing 7 mm behind the faces (the
    door tiles span face -5 mm .. +12 mm), stone plinth, end pilasters (x -4.75..-4.55 and 4.45..4.75), a brass band
    at 1.9-2.1 and a bronze cornice."""
    w, d, h = 9.5, 0.5, 2.2
    o = k.obj("Unit")
    a = o.part(bevel=0.0)
    s = o.part(bevel=0.004)
    hw, hd = w / 2, d / 2
    a.bx((-4.55, -hd + 0.007, 0.1), (4.45, hd - 0.007, 1.9), "metal_dark")
    s.bx((-hw + E, -hd + 0.012, 0.0), (hw - E, hd - 0.012, 0.1), "stone_dark")
    s.bx((-hw, -hd, 0.004), (-4.55, hd, 2.1), "of_box_steel")
    s.bx((4.45, -hd, 0.004), (hw, hd, 2.1), "of_box_steel")
    s.bx((-4.55, -hd + 0.004, 1.9), (4.45, hd - 0.004, 2.1), "brass")
    s.bx((-hw, -hd, 2.1), (hw, hd, h), "of_bronze_dark")
    o.build()


def _box_bank(k: Kit, p: dict) -> None:
    """VT wall bank frame (wall prop, back y 0 on the vault wall, bottom centre): the dark backing seen in the door
    gaps (1-4 mm off the wall; the tiles span 0..+17 mm), a stone plinth, steel end pilasters, a brass band at
    1.9-2.0 and a bronze cornice."""
    w = float(p["w"])
    o = k.obj("Bank")
    a = o.part(bevel=0.0)
    s = o.part(bevel=0.003)
    a.bx((-w / 2, 0.001, 0.1), (w / 2, 0.004, 1.9), "metal_dark")
    s.bx((-w / 2 - 0.06, 0.001, 0.004), (w / 2 + 0.06, 0.03, 0.1), "stone_dark")
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 + 0.06)))
        s.bx((x0, 0.001, 0.1), (x1, 0.024, 1.9), "of_box_steel")
    s.bx((-w / 2 - 0.06, 0.001, 1.9), (w / 2 + 0.06, 0.014, 2.0), "brass")
    s.bx((-w / 2 - 0.08, 0.001, 2.0), (w / 2 + 0.08, 0.04, 2.08), "of_bronze_dark")
    o.build()


def _box_door(k: Kit, p: dict) -> None:
    """One box door tile (MultiMesh mesh): back at y 0, centred in x / z, 17 mm thick plate with 2 mm gaps, two
    keyhole bosses and a number-plate boss (no numerals), one material (one draw call per bank tile size)."""
    w, h = float(p["w"]), float(p["h"])
    o = k.obj("Door")
    pl = o.part(bevel=0.002)
    dt = o.part(bevel=0.0)
    g = 0.002
    pl.bx((-w / 2 + g, 0.0, -h / 2 + g), (w / 2 - g, 0.017, h / 2 - g), "of_box_steel")
    kx = (-0.04, 0.04) if w < 0.3 else (-0.07, 0.07)
    for x in kx:
        dt.cyl(0.009, 0.004, (x, 0.019, -h * 0.12), "of_box_steel", axis="Y", segs=6)
    dt.bx((-0.025, 0.017, h / 2 - g - 0.032), (0.025, 0.02, h / 2 - g - 0.014), "of_box_steel")
    o.build()


def _deposit_drawer(k: Kit, p: dict) -> None:
    """Deposit box door (deposit_box prefab visual): 0.6 x 0.45, flush with the box-door tiles (back on the unit /
    wall face, front 17 mm proud), bottom at the pivot: a two-leaf brass-trimmed door with a lever handle."""
    w, h = 0.6, 0.45
    o = k.obj("Drawer")
    pl = o.part(bevel=0.002)
    dt = o.part(bevel=0.0)
    g = 0.002
    pl.bx((-w / 2 + g, 0.0, g), (w / 2 - g, 0.017, h - g), "of_box_steel")
    f = 0.017
    dt.bx((-w / 2 + 0.03, f, 0.03), (w / 2 - 0.03, f + 0.002, 0.034), "brass")
    dt.bx((-w / 2 + 0.03, f, h - 0.034), (w / 2 - 0.03, f + 0.002, h - 0.03), "brass")
    dt.bx((-w / 2 + 0.03, f, 0.034), (-w / 2 + 0.034, f + 0.002, h - 0.034), "brass")
    dt.bx((w / 2 - 0.034, f, 0.034), (w / 2 - 0.03, f + 0.002, h - 0.034), "brass")
    dt.bx((-0.06, f, h - 0.1), (0.06, f + 0.004, h - 0.06), "brass")
    for x in (-0.07, 0.07):
        dt.cyl(0.012, 0.005, (x, f + 0.0025, h * 0.42), "brass", axis="Y", segs=12)
        dt.cbox((x, f + 0.0055, h * 0.42), (0.003, 0.002, 0.012), "metal_dark")
    dt.rod((0.18, f + 0.028, h * 0.5 + 0.07), (0.18, f + 0.028, h * 0.5 - 0.07), 0.009, "steel", segs=8)
    for z in (h * 0.5 + 0.07, h * 0.5 - 0.07):
        dt.rod((0.18, f, z), (0.18, f + 0.028, z), 0.006, "steel", segs=6)
    o.build()


def _desk_pc(k: Kit, p: dict) -> None:
    """Desktop PC on a desk top (hack_terminal visual, visual_slots: `Screen` = the monitor face only, its material
    follows the hack state; `Panel` = the monitor body, the stand, the keyboard and the mouse). Pivot: the desk top
    under the monitor stand, front +Y = the user's side."""
    sc = k.obj("Screen")
    s = sc.part(bevel=0.0)
    s.bx((-0.255, 0.012, 0.135), (0.255, 0.016, 0.43), "emit_screen")
    sc.build()
    pn = k.obj("Panel")
    b = pn.part(bevel=0.003)
    t = pn.part(bevel=0.0015)
    b.bx((-0.275, -0.03, 0.115), (0.275, 0.012, 0.45), "plastic_black")
    b.bx((-0.11, -0.12, 0.0), (0.11, 0.06, 0.012), "plastic_black")
    b.bx((-0.03, -0.07, 0.012), (0.03, -0.035, 0.16), "plastic_black")
    t.bx((-0.22, 0.18, 0.0), (0.22, 0.32, 0.018), "plastic_grey")
    for r in range(4):
        t.bx((-0.205, 0.192 + r * 0.03, 0.018), (0.205, 0.214 + r * 0.03, 0.024), "plastic_black")
    t.bx((0.27, 0.21, 0.0), (0.33, 0.31, 0.02), "plastic_black")
    pn.build()


# ------------------------------------------------------------------------------------------------ room furniture

def _booth_counter(k: Kit, p: dict) -> None:
    """SD viewing-booth counter 9.0 x 0.6 x 0.9 (front +Y = the customers): walnut, a marble top, a recessed kick."""
    w, d, h = 9.0, 0.6, 0.9
    o = k.obj("Counter")
    wd = o.part(bevel=0.003)
    tp = o.part(bevel=0.004)
    y0, y1 = -d / 2, d / 2
    wd.bx((-w / 2 + E, y0 + E, 0.1), (w / 2 - E, y1 - E, h - 0.03), "walnut")
    wd.bx((-w / 2 + E, y0 + E, 0.0), (w / 2 - E, y1 - 0.06, 0.1), "stone_dark")
    tp.bx((-w / 2, y0, h - 0.03), (w / 2, y1, h), "marble")
    for i in range(9):
        x0 = -w / 2 + 0.06 + i * (w - 0.12) / 9
        x1 = x0 + (w - 0.12) / 9 - 0.04
        wd.bx((x0, y1 - E, 0.16), (x1, y1 + 0.004, h - 0.1), "walnut")
    o.build()


def _booth_partition(k: Kit, p: dict) -> None:
    """Booth partition 0.6 x 2.0 x 0.05: walnut frame, frosted glass from 0.9 to 1.9, a bronze cap."""
    w, t, h = 0.6, 0.05, 2.0
    o = k.obj("Partition")
    wd = o.part(bevel=0.003)
    gl = o.part(bevel=0.0)
    wd.bx((-w / 2 + E, -t / 2 + E, 0.0), (w / 2 - E, t / 2 - E, 0.9), "walnut")
    wd.bx((-w / 2 + E, -t / 2 + E, 0.9), (-w / 2 + 0.05, t / 2 - E, 1.95), "walnut")
    wd.bx((w / 2 - 0.05, -t / 2 + E, 0.9), (w / 2 - E, t / 2 - E, 1.95), "walnut")
    gl.bx((-w / 2 + 0.05, -0.008, 0.9), (w / 2 - 0.05, 0.008, 1.95), "glass_frosted")
    wd.bx((-w / 2, -t / 2, 1.95), (w / 2, t / 2, h), "of_bronze")
    o.build()


def _pedestal_desk(k: Kit, w: float, d: float, h: float) -> None:
    """Walnut pedestal desk (front +Y = the user's side): top, a drawer pedestal each side, a modesty panel at -Y."""
    o = k.obj("Desk")
    wd = o.part(bevel=0.003)
    tr = o.part(bevel=0.0015)
    y0, y1 = -d / 2, d / 2
    wd.bx((-w / 2, y0, h - 0.035), (w / 2, y1, h), "walnut")
    tr.bx((-w / 2 + 0.03, y0 + 0.03, h - 0.036), (w / 2 - 0.03, y1 - 0.08, h - 0.034), "leather")
    pw = 0.42
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * (w / 2 - E), sx * (w / 2 - pw)))
        wd.bx((x0, y0 + E, 0.0), (x1, y1 - 0.02, h - 0.035), "walnut")
        for j in range(3):
            z0 = 0.06 + j * (h - 0.13) / 3
            z1 = z0 + (h - 0.13) / 3 - 0.015
            wd.bx((x0 + 0.02, y1 - 0.02, z0), (x1 - 0.02, y1 - E, z1), "walnut")
            knob(tr, (x0 + x1) / 2, y1 - E, (z0 + z1) / 2)
    wd.bx((-w / 2 + pw, y0 + 0.03, 0.18), (w / 2 - pw, y0 + 0.05, h - 0.035), "walnut")
    o.build()


def _attendant_desk(k: Kit, p: dict) -> None:
    """SD attendant's desk 1.6 x 0.75 x 0.7."""
    _pedestal_desk(k, 1.6, 0.7, 0.75)


def _desk_vault_ops(k: Kit, p: dict) -> None:
    """VO vault-schedule desk 1.4 x 0.75 x 0.7."""
    _pedestal_desk(k, 1.4, 0.7, 0.75)


def _coffee_table(k: Kit, p: dict) -> None:
    """PC coffee table 0.8 x 0.8 x 0.45: a marble top in a bronze band on four tapered walnut legs, a shelf."""
    w, h = 0.8, 0.45
    o = k.obj("Table")
    wd = o.part(bevel=0.003)
    tp = o.part(bevel=0.004)
    tp.bx((-w / 2 + 0.01, -w / 2 + 0.01, h - 0.03), (w / 2 - 0.01, w / 2 - 0.01, h), "marble")
    wd.bx((-w / 2, -w / 2, h - 0.07), (w / 2, w / 2, h - 0.03), "of_bronze")
    legs4(wd, w - 0.02, w - 0.02, h - 0.07, 0.04, 0.05, "walnut")
    wd.bx((-w / 2 + 0.06, -w / 2 + 0.06, 0.1), (w / 2 - 0.06, w / 2 - 0.06, 0.125), "walnut")
    o.build()


def _coffee_service(k: Kit, p: dict) -> None:
    """PC coffee service sideboard 1.6 x 0.45 x 0.9 (front +Y): walnut doors, a marble top, a bronze kick."""
    w, d, h = 1.6, 0.45, 0.9
    o = k.obj("Service")
    wd = o.part(bevel=0.003)
    tp = o.part(bevel=0.004)
    tr = o.part(bevel=0.0015)
    y0, y1 = -d / 2, d / 2
    wd.bx((-w / 2 + E, y0 + E, 0.08), (w / 2 - E, y1 - 0.02, h - 0.03), "walnut")
    tr.bx((-w / 2 + 0.02, y0 + E, 0.0), (w / 2 - 0.02, y1 - 0.05, 0.08), "of_bronze_dark")
    tp.bx((-w / 2, y0, h - 0.03), (w / 2, y1, h), "marble")
    for i in range(3):
        x0 = -w / 2 + 0.03 + i * (w - 0.06) / 3
        x1 = x0 + (w - 0.06) / 3 - 0.015
        wd.bx((x0, y1 - 0.02, 0.11), (x1, y1 - E, h - 0.06), "walnut")
        knob(tr, x1 - 0.05, y1 - E, h - 0.2)
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
