"""Ostrander Federal G2 banking hall, vestibule and plaza pieces (OF-C2 lane A; docs/design/heists/ostrander_federal.md
Site: exterior landmarks 2 (the meridian line); Room list BH / VE / X1; Audio/lighting: the hall's 3000 K bronze pendants,
palette limestone #CBC3B0, deep ultramarine #2F3F6B, meridian bronze #B8873A). Placed by of_dress_a.gd and
of_landmarks.gd. Every surface is a library or `of_` tinted-library finish (no flat colour).

Exact-fit visuals of G1 furniture boxes (Props/MapBuilt; the box collider, its metas and nav obstruction stay; the art
is drawn inside the box, floor pivot, front +Y = Godot -Z):
* `prop_of_check_desk` (CheckDesk1-4, 1.6 x 0.6 x 1.0): a standing check-writing desk, both sides usable: a walnut body
  in bronze corner trims on a dark marble plinth, a marble top in a bronze band with recessed inkwells.
* `prop_of_hall_bench` (HallBench*, 1.8 x 0.5 x 0.45): a backless walnut bench, an ultramarine leather cushion, bronze
  shoes.
* `prop_of_queue_rail_w900` (QueueRail1-2, 9.0 x 0.05 x 1.0): seven bronze posts on low bases, ultramarine velvet
  ropes in a shallow catenary.
* `prop_of_planter_sq120` (PlazaPlanter1-5, 1.2 x 1.2 x 0.8): a granite planter in a bronze cap band, soil and a
  clipped box shrub.
* `prop_of_news_kiosk` (Kiosk, 2.0 x 2.0 x 2.6): the plaza's news kiosk: painted green steel, a serving hatch with
  stacked papers, magazine racks on the sides, a bronze-trimmed roof.
Placed pieces:
* `prop_of_hall_pendant` (ceiling, top at 0): the hall's bronze drum lantern on a 2.3 m rod, opal glass, a 3000 K
  light (unshadowed by default; the generator turns one on).
* `prop_of_window_bay` (wall prop, back at y 0): the bronze frame of a 3.2 x 5.5 arched hall window (sill +1.0):
  jambs, the two mullions and the transom of the breach panel, the springing transom, the semicircular arch with
  radial bars and dark bronze spandrels; one on each face of the glass.
* `prop_of_meridian_line` (map pivot (24, -0.012, 24.7), placed yaw 0): the brass meridian line inlaid flush (top at
  y 0) in a 0.5 m ultramarine marble band from the counter (z 17.5) to the vestibule (z 31.9): 12 month ticks
  1.2 m apart and Roman numerals I-XII (north to south), bronze fillets.
"""

import math

import _pb
from _pb import Kit, legs4

TRI_BUDGET = 20000
_G = "ostrander"
WARM_3000K = "#FFB878"
VARIANTS = {
    "prop_of_check_desk": {"fn": "check_desk", "cat": {"kind": "check_table", "place": "none", "group": _G,
                                                       "pin_only": True, "support": True, "top": 1.0}},
    "prop_of_hall_bench": {"fn": "hall_bench", "cat": {"kind": "bench", "place": "none", "group": _G,
                                                       "pin_only": True}},
    "prop_of_queue_rail_w900": {"fn": "queue_rail", "cat": {"kind": "stanchion", "place": "none", "group": _G,
                                                            "pin_only": True, "surface": "metal"}},
    "prop_of_news_kiosk": {"fn": "news_kiosk", "cat": {"kind": "kiosk", "place": "none", "group": _G,
                                                       "pin_only": True, "surface": "metal"}},
    "prop_of_planter_sq120": {"fn": "planter_sq", "cat": {"kind": "planter", "place": "none", "group": _G,
                                                          "pin_only": True, "surface": "concrete"}},
    "prop_of_hall_pendant": {"fn": "hall_pendant", "cat": {"kind": "light_fixture", "place": "ceiling",
                                                           "fixture": True, "group": _G, "pin_only": True,
                                                           "surface": "metal",
                                                           "light": {"type": "omni", "color": WARM_3000K,
                                                                     "energy": 2.6, "range": 12.0,
                                                                     "pos": [0.0, -2.85, 0.0]}}},
    "prop_of_window_bay": {"fn": "window_bay", "cat": {"kind": "window_frame", "place": "none", "group": _G,
                                                       "pin_only": True, "surface": "metal"}},
    "prop_of_meridian_line": {"fn": "meridian_line", "cat": {"kind": "landmark", "place": "none", "group": _G,
                                                             "pin_only": True, "surface": "metal"}},
}

E = 0.002  # visual inset from a collider face


# ------------------------------------------------------------------------------------------------ hall furniture

def _check_desk(k: Kit, p: dict) -> None:
    """Standing check desk 1.6 x 0.6 x 1.0 (both long sides are fronts)."""
    w, d, h = 1.6 - 2 * E, 0.6 - 2 * E, 1.0 - E
    o = k.obj("Desk")
    st = o.part(bevel=0.004)
    wd = o.part(bevel=0.003)
    br = o.part(bevel=0.002)
    # dark marble plinth, walnut body, a bronze band and the marble top
    st.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.1), "marble")
    wd.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.1), (w / 2 - 0.05, d / 2 - 0.05, h - 0.09), "walnut")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = sx * (w / 2 - 0.05)
            y = sy * (d / 2 - 0.05)
            br.bx((x - 0.035, y - 0.035, 0.1), (x + 0.035, y + 0.035, h - 0.09), "of_bronze")
    for sy in (-1, 1):  # sunk walnut panels on both faces, bronze beads
        y = sy * (d / 2 - 0.045)
        for px in (-0.36, 0.36):
            wd.bx((px - 0.3, y - 0.008, 0.22), (px + 0.3, y + 0.008, h - 0.2), "walnut")
            br.bx((px - 0.31, y - 0.004, h - 0.205), (px + 0.31, y + 0.004, h - 0.195), "of_bronze")
    br.bx((-w / 2 + 0.01, -d / 2 + 0.01, h - 0.09), (w / 2 - 0.01, d / 2 - 0.01, h - 0.04), "of_bronze")
    st.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "marble")
    # inkwells and pen rests on the top's centre line (bronze, flush), a raised slip rail
    for x in (-0.55, 0.0, 0.55):
        br.cyl(0.03, 0.012, (x, 0.0, h + 0.006), "of_bronze", segs=12)
    br.bx((-w / 2 + 0.08, -0.012, h), (w / 2 - 0.08, 0.012, h + 0.02), "of_bronze")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _hall_bench(k: Kit, p: dict) -> None:
    """Backless hall bench 1.8 x 0.5 x 0.45: walnut frame, ultramarine leather cushion, bronze shoes."""
    w, d, h = 1.8 - 2 * E, 0.5 - 2 * E, 0.45 - E
    o = k.obj("Bench")
    wd = o.part(bevel=0.004)
    cu = o.part(bevel=0.012, segments=2)
    br = o.part(bevel=0.002)
    wd.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.3), (w / 2 - 0.03, d / 2 - 0.03, 0.36), "walnut")
    legs4(wd, w - 0.04, d - 0.04, 0.3, 0.02, 0.07, "walnut")
    wd.bx((-w / 2 + 0.1, -0.02, 0.1), (w / 2 - 0.1, 0.02, 0.16), "walnut")  # stretcher
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = sx * (w / 2 - 0.02 - 0.035)
            y = sy * (d / 2 - 0.02 - 0.035)
            br.bx((x - 0.04, y - 0.04, 0.0), (x + 0.04, y + 0.04, 0.05), "of_bronze")
    cu.bx((-w / 2, -d / 2, 0.36), (w / 2, d / 2, h), "of_leather_ultramarine")
    for x in (-0.6, -0.2, 0.2, 0.6):  # tufting buttons
        br.cyl(0.012, 0.006, (x, 0.0, h + 0.001), "of_bronze", segs=8)
    o.build()


def _queue_rail(k: Kit, p: dict) -> None:
    """9.0 m queue line: seven bronze posts (0.97 m) with low bases, velvet rope catenaries."""
    o = k.obj("Rail")
    br = o.part(bevel=0.0)
    rp = o.part(bevel=0.0)
    xs = [-4.45 + 1.4833 * i for i in range(7)]
    for x in xs:
        br.lathe([(0.0, 0.0), (0.09, 0.0), (0.09, 0.012), (0.05, 0.03), (0.022, 0.05), (0.0, 0.05)], "of_bronze",
                 centre=(x, 0.0, 0.0), segs=16)
        br.rod((x, 0.0, 0.05), (x, 0.0, 0.93), 0.022, "of_bronze", segs=10)
        br.sphere(0.035, (x, 0.0, 0.955), "of_bronze", segs=12, rings=6)
        br.cyl(0.03, 0.02, (x, 0.0, 0.9), "of_bronze_dark", segs=10)
    for i in range(len(xs) - 1):
        a, b = xs[i] + 0.03, xs[i + 1] - 0.03
        pts = []
        for j in range(9):
            t = j / 8.0
            pts.append((a + (b - a) * t, 0.0, 0.9 - 0.12 * 4.0 * t * (1.0 - t)))
        rp.tube(pts, 0.016, "of_ultramarine", segs=8)
    o.build()


def _news_kiosk(k: Kit, p: dict) -> None:
    """Plaza news kiosk 2.0 x 2.0 x 2.6 (front +Y: the serving hatch)."""
    w, h = 2.0 - 2 * E, 2.6 - E
    o = k.obj("Kiosk")
    pn = o.part(bevel=0.004)
    tr = o.part(bevel=0.003)
    pa = o.part(bevel=0.002)
    # body: painted green steel panels round a hatch (0.9-1.9 m) on the front, plinth, roof
    pn.bx((-w / 2 + 0.04, -w / 2 + 0.04, 0.12), (w / 2 - 0.04, w / 2 - 0.04, 0.9), "metal_green")
    pn.bx((-w / 2 + 0.04, -w / 2 + 0.04, 0.9), (w / 2 - 0.04, w / 2 - 0.3, 2.2), "metal_green")
    fy0, fy1 = w / 2 - 0.3, w / 2 - 0.04
    pn.bx((-w / 2 + 0.04, fy0, 0.9), (-0.8, fy1, 2.2), "metal_green")
    pn.bx((0.8, fy0, 0.9), (w / 2 - 0.04, fy1, 2.2), "metal_green")
    pn.bx((-0.8, fy0, 1.9), (0.8, fy1, 2.2), "metal_green")
    tr.bx((-w / 2, -w / 2, 0.0), (w / 2, w / 2, 0.12), "of_granite")
    tr.bx((-w / 2, -w / 2, 2.2), (w / 2, w / 2, 2.32), "of_bronze_dark")
    tr.bx((-w / 2 + 0.06, -w / 2 + 0.06, 2.32), (w / 2 - 0.06, w / 2 - 0.06, h), "metal_green")
    tr.bx((-w / 2, -w / 2, h - 0.05), (w / 2, w / 2, h), "of_bronze")
    for sx in (-1, 1):  # corner posts
        for sy in (-1, 1):
            x = sx * (w / 2 - 0.04)
            y = sy * (w / 2 - 0.04)
            tr.bx((x - 0.04, y - 0.04, 0.12), (x + 0.04, y + 0.04, 2.2), "of_bronze_dark")
    # the hatch: a counter shelf with stacked papers, a dark interior back
    tr.bx((-0.76, w / 2 - 0.3, 0.88), (0.76, w / 2 - 0.02, 0.92), "walnut")
    pn.bx((-0.76, w / 2 - 0.32, 0.92), (0.76, w / 2 - 0.3, 1.9), "metal_dark")
    for i, key in enumerate(("paper", "art_blue", "paper", "art_ochre", "paper", "art_rust")):
        x = -0.65 + i * 0.24
        pa.bx((x - 0.1, w / 2 - 0.27, 0.92), (x + 0.1, w / 2 - 0.05, 0.92 + 0.03 + 0.01 * (i % 3)), key)
    # magazine racks on both sides: three sloped shelves of covers
    for sx in (-1, 1):
        x0 = sx * (w / 2 - 0.04)
        x1 = sx * (w / 2 + 0.0)
        for j, zc in enumerate((0.55, 1.05, 1.55)):
            for i, key in enumerate(("art_blue", "art_ochre", "art_rust", "paper")):
                y = -0.6 + i * 0.4
                pa.bx((min(x0, x1) - 0.0, y - 0.15, zc), (max(x0, x1) + 0.0, y + 0.15, zc + 0.36),
                      key if (i + j) % 2 == 0 else "paper")
            tr.bx((min(x0, x1), -0.8, zc - 0.02), (max(x0, x1), 0.8, zc), "of_bronze_dark")
    o.build()


def _planter_sq(k: Kit, p: dict) -> None:
    """Plaza planter 1.2 x 1.2 x 0.8: granite tub, bronze cap band, soil, a clipped box shrub."""
    w, h = 1.2 - 2 * E, 0.8 - E
    o = k.obj("Planter")
    st = o.part(bevel=0.01, segments=2)
    br = o.part(bevel=0.002)
    lf = o.part(bevel=0.0)
    st.bx((-w / 2, -w / 2, 0.0), (w / 2, w / 2, 0.08), "of_granite")
    st.bx((-w / 2 + 0.03, -w / 2 + 0.03, 0.08), (w / 2 - 0.03, w / 2 - 0.03, h - 0.06), "of_granite")
    br.bx((-w / 2 + 0.01, -w / 2 + 0.01, h - 0.06), (w / 2 - 0.01, w / 2 - 0.01, h), "of_bronze_dark")
    br.bx((-w / 2 + 0.09, -w / 2 + 0.09, h - 0.03), (w / 2 - 0.09, w / 2 - 0.09, h - 0.01), "soil")
    lf.sphere(0.46, (0.0, 0.0, h + 0.24), "leaf_dark", segs=16, rings=8, scale=(1.0, 1.0, 0.72))
    lf.sphere(0.3, (0.12, -0.08, h + 0.5), "leaf", segs=12, rings=6, scale=(1.0, 1.0, 0.8))
    o.build()


# ------------------------------------------------------------------------------------------------ lighting

def _hall_pendant(k: Kit, p: dict) -> None:
    """Bronze drum lantern (Art Deco): canopy, 2.3 m rod, stepped cap, opal drum in bronze ribs, stepped base."""
    o = k.obj("Pendant")
    br = o.part(bevel=0.0)
    gl = o.part(bevel=0.0)
    br.lathe([(0.0, -0.09), (0.16, -0.09), (0.2, -0.05), (0.21, -0.01), (0.21, 0.0), (0.0, 0.0)], "of_bronze", segs=20)
    br.rod((0.0, 0.0, -0.09), (0.0, 0.0, -2.3), 0.02, "of_bronze", segs=8)
    br.lathe([(0.0, -2.3), (0.06, -2.3), (0.06, -2.26), (0.0, -2.26)], "of_bronze", segs=12)
    br.lathe([(0.0, -2.47), (0.47, -2.47), (0.47, -2.44), (0.36, -2.4), (0.36, -2.36), (0.2, -2.33), (0.08, -2.3),
              (0.0, -2.3)], "of_bronze", segs=24)
    gl.lathe([(0.0, -3.24), (0.4, -3.24), (0.4, -2.47), (0.0, -2.47)], "emit_warm", segs=24)
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        br.rod((math.cos(a) * 0.415, math.sin(a) * 0.415, -2.47), (math.cos(a) * 0.415, math.sin(a) * 0.415, -3.24),
               0.014, "of_bronze", segs=4, square=True)
    for z in (-2.62, -2.86, -3.1):
        br.torus(0.415, 0.012, (0.0, 0.0, z), "of_bronze", segs=24, rsegs=5)
    br.lathe([(0.0, -3.42), (0.1, -3.42), (0.2, -3.36), (0.36, -3.3), (0.46, -3.27), (0.46, -3.24), (0.0, -3.24)],
             "of_bronze", segs=24)
    br.sphere(0.05, (0.0, 0.0, -3.47), "of_bronze", segs=12, rings=6)
    o.build()


# ------------------------------------------------------------------------------------------------ facade window

def _area(pts: list[tuple[float, float]]) -> float:
    return 0.5 * sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                     for i in range(len(pts)))


WB_W, WB_H, WB_SPRING = 3.2, 5.5, 3.9   # bay width, height (sill +1.0 to +6.5), arch springing above the sill
WB_D = 0.06                             # frame depth in front of the glass


def _window_bay(k: Kit, p: dict) -> None:
    """Arched window frame (wall prop: back y 0 on the glass face, x centred, bottom at the sill)."""
    o = k.obj("Bay")
    fr = o.part(bevel=0.003)
    sp = o.part(bevel=0.0)
    hw = WB_W / 2
    d = WB_D
    b = 0.09   # frame bar width
    m = 0.05   # mullion half width
    fr.bx((-hw, 0.0, 0.0), (-hw + b, d, WB_H), "of_bronze")
    fr.bx((hw - b, 0.0, 0.0), (hw, d, WB_H), "of_bronze")
    fr.bx((-hw + b, 0.0, 0.0), (hw - b, d, b), "of_bronze")
    for x in (-0.55, 0.55):  # mullions just outside the breach panel (its 1.0 x 1.1 opening stays clear)
        fr.bx((x - m, 0.0, b), (x + m, d, WB_SPRING), "of_bronze")
    fr.bx((-hw + b, 0.0, 1.1), (hw - b, d, 1.1 + 2 * m), "of_bronze")
    fr.bx((-hw + b, 0.0, WB_SPRING - b / 2), (hw - b, d, WB_SPRING + b / 2), "of_bronze")
    # the arch: a semicircular bronze rib (r = half the bay), radial bars from a hub, spandrels above it
    r = hw - b / 2
    segs = 24
    ring = []
    for i in range(segs + 1):
        a = math.pi * i / segs
        ring.append((math.cos(a) * r, d * 0.5, WB_SPRING + math.sin(a) * r))
    fr.tube(ring, b / 2, "of_bronze", segs=6)
    for i in range(1, 6):
        a = math.pi * i / 6
        fr.rod((0.0, d * 0.5, WB_SPRING), (math.cos(a) * r, d * 0.5, WB_SPRING + math.sin(a) * r), 0.022, "of_bronze",
               segs=6)
    fr.cyl(0.12, d, (0.0, d * 0.5, WB_SPRING), "of_bronze", axis="Y", segs=16)
    for sgn in (-1, 1):  # spandrels between the arch and the frame's top corners
        outline = [(sgn * hw, WB_SPRING)]
        for i in range(0, segs // 2 + 1):
            a = (math.pi / 2) * i / (segs // 2)
            outline.append((sgn * math.cos(a) * r, WB_SPRING + math.sin(a) * r))
        outline += [(0.0, WB_H), (sgn * hw, WB_H)]
        if _area(outline) < 0:
            outline.reverse()
        sp.profile_y(outline, 0.004, d - 0.012, "of_bronze_dark")
    o.build()


# ------------------------------------------------------------------------------------------------ meridian line

ML_PIVOT = (24.0, -0.012, 24.7)   # placed 12 mm down: the asset's bottom is its pivot
ML_Z0, ML_Z1 = 17.5, 31.9       # counter ledge -> the vestibule's inner doors (map z)
ML_HALF = 0.25                  # band half width
ML_DEPTH = 0.012                # inlay depth below the floor (top flush at y 0)


def _mv(x: float, z: float, y: float = 0.0) -> tuple[float, float, float]:
    """Map (x, y, z) -> Blender, about ML_PIVOT."""
    return (x - ML_PIVOT[0], -(z - ML_PIVOT[2]), y - ML_PIVOT[1])


def _flat_strip(part, x0: float, z0: float, x1: float, z1: float, w: float, key: str, top: float = 0.0,
                depth: float = 0.004) -> None:
    """A flush floor strip (map coordinates) of width w from (x0, z0) to (x1, z1), top at `top`."""
    dx, dz = x1 - x0, z1 - z0
    ln = math.hypot(dx, dz)
    nx, nz = -dz / ln * w / 2, dx / ln * w / 2
    pts = [(x0 + nx, z0 + nz), (x1 + nx, z1 + nz), (x1 - nx, z1 - nz), (x0 - nx, z0 - nz)]
    outline = [(_mv(x, z)[0], _mv(x, z)[1]) for x, z in pts]
    a = outline[1][0] - outline[0][0], outline[1][1] - outline[0][1]
    b = outline[2][0] - outline[0][0], outline[2][1] - outline[0][1]
    if a[0] * b[1] - a[1] * b[0] < 0:
        outline.reverse()
    part.slab(outline, top - depth - ML_PIVOT[1], top - ML_PIVOT[1], key)


def _numeral(part, text: str, cx: float, cz: float, hgt: float) -> None:
    """Roman numeral laid flat, read from the south (up = north, -z): I, V, X strokes as flush brass strips."""
    widths = {"I": 0.25, "V": 0.6, "X": 0.6}
    total = sum(widths[c] * hgt for c in text) + 0.18 * hgt * (len(text) - 1)
    x = cx - total / 2
    zt, zb = cz - hgt / 2, cz + hgt / 2   # top (north) and bottom (south) of the glyphs
    sw = 0.12 * hgt
    for c in text:
        gw = widths[c] * hgt
        if c == "I":
            _flat_strip(part, x + gw / 2, zb, x + gw / 2, zt, sw, "brass", depth=0.003)
        elif c == "V":
            _flat_strip(part, x, zt, x + gw / 2, zb, sw, "brass", depth=0.003)
            _flat_strip(part, x + gw / 2, zb, x + gw, zt, sw, "brass", depth=0.003)
        else:
            _flat_strip(part, x, zt, x + gw, zb, sw, "brass", depth=0.003)
            _flat_strip(part, x, zb, x + gw, zt, sw, "brass", depth=0.003)
        x += gw + 0.18 * hgt


def _meridian_line(k: Kit, p: dict) -> None:
    """The brass meridian line in its marble band (flush with the floor: top at map y 0)."""
    o = k.obj("Meridian")
    bd = o.part(bevel=0.0)
    ln = o.part(bevel=0.0)
    x0, x1 = 24.0 - ML_HALF, 24.0 + ML_HALF
    # the band sits a hair below the brass so the inlays read on top (never coplanar: 1.5 mm)
    bd.bx((x0 - ML_PIVOT[0], -(ML_Z1 - ML_PIVOT[2]), -ML_DEPTH - ML_PIVOT[1]),
          (x1 - ML_PIVOT[0], -(ML_Z0 - ML_PIVOT[2]), -0.0015 - ML_PIVOT[1]),
          "of_marble_blue")
    # bronze fillets along both edges, the brass line down the middle (flush, y 0)
    for x in (x0 + 0.012, x1 - 0.012):
        _flat_strip(ln, x, ML_Z0, x, ML_Z1, 0.024, "of_bronze", depth=0.006)
    _flat_strip(ln, 24.0, ML_Z0, 24.0, ML_Z1, 0.03, "brass", depth=0.006)
    # month ticks every 1.2 m (13 marks: the ends included), numerals I-XII north to south east of the line
    for i in range(13):
        z = ML_Z0 + 1.2 * i
        z = min(max(z, ML_Z0 + 0.012), ML_Z1 - 0.012)
        _flat_strip(ln, x0 + 0.03, z, x1 - 0.03, z, 0.018, "brass", depth=0.005)
    names = ["I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
    for i, nm in enumerate(names):
        zc = ML_Z0 + 1.2 * i + 0.6
        _numeral(ln, nm, 24.125, zc, 0.1)
    # the October noon mark: a brass ring west of the line in month X (the sun disc's mark)
    zc = ML_Z0 + 1.2 * 9 + 0.6
    segs = 20
    for i in range(segs):
        a0 = 2 * math.pi * i / segs
        a1 = 2 * math.pi * (i + 1) / segs
        _flat_strip(ln, 23.885 + math.cos(a0) * 0.07, zc + math.sin(a0) * 0.07, 23.885 + math.cos(a1) * 0.07,
                    zc + math.sin(a1) * 0.07, 0.012, "brass", depth=0.004)
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
