"""Gallery Night room dressing (GN-C2; docs/design/heists/gallery_night.md room list, palette bone / halberd green / gilt,
the Calloway gala). Floor props: bottom-centre pivot, front = Blender +Y (Godot -Z); wall props: back at y 0.

* Gala: the 1.1 m bar counter (`counter_bar`, the gala bar x 14.4-15.2 in the Great Hall), high cocktail tables with
  linen and glassware, the velvet-rope stanchion run (one box collider per run, next_heist §7.9), music stands for the
  string trio, the guest-list lectern, the cloakroom coat rail.
* Galleries: backless leather gallery benches, limestone plinths with bronze figures (two shapes), the court bronze
  on its pedestal.
* Back of house: the conservator's empty studio easel, the suction table, plan chests (art store, drawings), the
  inert-gas suppression cylinder bank (plant).
* Outside: the lilac gala uplight (a ground spot, `fixture`), the court's patio heater and ashtray stand, a stone
  park bench.
"""

import math

from _pb import Kit, bar_handle, knob

TRI_BUDGET = 12000
LILAC = "#B79CF2"
WARM = "#FFB46B"
VARIANTS = {
    "prop_bar_counter_gala": {"fn": "bar", "cat": {"kind": "counter_bar", "place": "wall", "support": True, "clear": 1.0,
                                                   "top": 1.1, "group": "gallery"}},
    "prop_cocktail_table": {"fn": "cocktail", "cat": {"kind": "cocktail_table", "place": "center", "support": True,
                                                      "clear": 0.5, "group": "gallery"}},
    "prop_glassware": {"fn": "glassware", "cat": {"kind": "glassware", "place": "on",
                                                  "hosts": ["cocktail_table", "counter_bar", "table", "kitchen_counter"],
                                                  "group": "clutter"}},
    "prop_stanchion_velvet": {"fn": "stanchion", "cat": {"kind": "stanchion", "place": "floor", "group": "gallery"}},
    "prop_music_stand": {"fn": "music_stand", "cat": {"kind": "music_stand", "place": "floor", "group": "gallery"}},
    "prop_lectern": {"fn": "lectern", "cat": {"kind": "lectern", "place": "floor", "clear": 0.6, "group": "gallery"}},
    "prop_coat_rail": {"fn": "coat_rail", "cat": {"kind": "coat_rail", "place": "wall", "clear": 0.6, "group": "gallery"}},
    "prop_bench_gallery": {"fn": "bench", "cat": {"kind": "bench", "place": "center", "clear": 0.6, "group": "gallery"}},
    "prop_plinth_bronze_a": {"fn": "plinth", "shape": "a", "cat": {"kind": "sculpture", "place": "floor", "clear": 0.6,
                                                                   "group": "gallery"}},
    "prop_plinth_bronze_b": {"fn": "plinth", "shape": "b", "cat": {"kind": "sculpture", "place": "floor", "clear": 0.6,
                                                                   "group": "gallery"}},
    "prop_bronze_court": {"fn": "court_bronze", "cat": {"kind": "sculpture", "place": "floor", "clear": 1.0,
                                                        "group": "exterior"}},
    "prop_easel_studio": {"fn": "easel", "cat": {"kind": "easel", "place": "floor", "clear": 0.6, "group": "gallery"}},
    "prop_suction_table": {"fn": "suction_table", "cat": {"kind": "suction_table", "place": "center", "support": True,
                                                          "clear": 0.8, "top": 0.86, "group": "gallery"}},
    "prop_plan_chest": {"fn": "plan_chest", "cat": {"kind": "plan_chest", "place": "wall", "support": True, "clear": 0.9,
                                                    "group": "gallery"}},
    "prop_gas_cylinders": {"fn": "gas_cylinders", "cat": {"kind": "gas_cylinders", "place": "wall", "clear": 0.6,
                                                          "group": "plant"}},
    "prop_uplight_lilac": {"fn": "uplight", "cat": {"kind": "uplight", "place": "floor", "fixture": True, "group": "exterior",
                                                    "light": {"type": "spot", "color": LILAC, "energy": 3.0, "range": 9.0,
                                                              "angle": 28, "pos": [0.0, 0.18, 0.0], "up": True}}},
    "prop_patio_heater": {"fn": "heater", "cat": {"kind": "heater", "place": "floor", "fixture": True, "group": "exterior",
                                                  "light": {"type": "omni", "color": "#FF8A3C", "energy": 0.6, "range": 3.0,
                                                            "pos": [0.0, 2.05, 0.0]}}},
    "prop_ashtray_stand": {"fn": "ashtray", "cat": {"kind": "ashtray", "place": "floor", "group": "exterior"}},
    "prop_bench_stone": {"fn": "bench_stone", "cat": {"kind": "bench", "place": "wall", "clear": 0.6, "group": "exterior"}},
}


# --------------------------------------------------------------------------------------- gala

def _bar(k: Kit, p: dict) -> None:
    """Gala bar: 2.0 x 0.8 m, 1.1 m walnut bar with a bone marble top and a gilt foot rail on the guest side (+Y);
    the bartender's side (-Y) has a 0.9 m work shelf with ice wells."""
    w, d, h = 2.0, 0.8, 1.1
    o = k.obj("Bar")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    hard.bx((-w / 2 + 0.03, -d / 2 + 0.3, 0.0), (w / 2 - 0.03, d / 2 - 0.05, 0.1), "wood_dark")
    hard.bx((-w / 2, -d / 2 + 0.3, 0.1), (w / 2, d / 2 - 0.02, h - 0.05), "walnut")
    hard.bx((-w / 2 - 0.02, -d / 2 + 0.28, h - 0.05), (w / 2 + 0.02, d / 2, h), "marble")
    # raised panels on the guest face and a gilt band under the top
    for i in range(4):
        x0 = -w / 2 + 0.06 + i * (w - 0.12) / 4
        trim.bx((x0 + 0.02, d / 2 - 0.02, 0.18), (x0 + (w - 0.12) / 4 - 0.02, d / 2 - 0.008, h - 0.14), "walnut")
    trim.bx((-w / 2 - 0.004, d / 2 - 0.016, h - 0.1), (w / 2 + 0.004, d / 2 - 0.004, h - 0.085), "brass")
    for x in (-w / 2 + 0.1, 0.0, w / 2 - 0.1):
        trim.rod((x, d / 2 - 0.02, 0.2), (x, d / 2 + 0.11, 0.2), 0.012, "brass", segs=8)
    trim.rod((-w / 2 + 0.05, d / 2 + 0.11, 0.2), (w / 2 - 0.05, d / 2 + 0.11, 0.2), 0.022, "brass", segs=12)
    # bartender work shelf (0.9 m) with two steel ice wells
    hard.bx((-w / 2, -d / 2, 0.0), (w / 2, -d / 2 + 0.3, 0.86), "metal_dark")
    hard.bx((-w / 2, -d / 2, 0.86), (w / 2, -d / 2 + 0.3, 0.9), "steel")
    for x in (-0.45, 0.45):
        trim.bx((x - 0.25, -d / 2 + 0.04, 0.9), (x + 0.25, -d / 2 + 0.26, 0.905), "plastic_black")
    o.build()
    k.collision([((-w / 2 - 0.02, -d / 2, 0.0), (w / 2 + 0.02, d / 2, h))])


def _cocktail(k: Kit, p: dict) -> None:
    """High cocktail table (1.08 m) in a fitted ivory linen sheath tied at the waist, a dark marble top disc."""
    r, h = 0.36, 1.08
    o = k.obj("Table")
    soft = o.part(bevel=0.0)
    hard = o.part(bevel=0.003)
    soft.lathe([(0.0, 0.0), (0.3, 0.0), (0.28, 0.08), (0.12, 0.5), (0.1, 0.56), (0.13, 0.62), (0.33, h - 0.05),
                (r, h - 0.03), (0.0, h - 0.03)], "fabric_ivory", segs=28)
    hard.cyl(r + 0.005, 0.03, (0.0, 0.0, h - 0.015), "stone_dark", segs=28)
    hard.torus(0.105, 0.012, (0.0, 0.0, 0.56), "brass", segs=20, rsegs=6)
    o.build()
    k.collision([((-r, -r, 0.0), (r, r, h))])


def _glassware(k: Kit, p: dict) -> None:
    """Three champagne flutes and a folded napkin (clutter on tables / the bar)."""
    o = k.obj("Glasses")
    g = o.part(bevel=0.0)
    s = o.part(bevel=0.001)
    for i, (x, y) in enumerate(((-0.06, 0.0), (0.0, 0.05), (0.06, -0.01))):
        g.cyl(0.03, 0.004, (x, y, 0.002), "glass", segs=12)
        g.rod((x, y, 0.004), (x, y, 0.09), 0.003, "glass", segs=6)
        g.lathe([(0.0, 0.09), (0.018, 0.1), (0.024, 0.15), (0.026, 0.2), (0.0, 0.2)], "glass", centre=(x, y, 0.0), segs=12)
        if i != 1:
            g.lathe([(0.0, 0.1), (0.017, 0.105), (0.022, 0.15), (0.0, 0.15)], "emit_amber", centre=(x, y, 0.0), segs=10)
    s.bx((-0.1, -0.09, 0.0), (0.02, -0.04, 0.012), "fabric_ivory")
    o.build()


def _stanchion(k: Kit, p: dict) -> None:
    """Velvet-rope run: two gilt posts on weighted bases 2.0 m apart, a red velvet rope swagged between them."""
    span = 2.0
    o = k.obj("Stanchions")
    post = o.part(bevel=0.0)
    rope = o.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * (span / 2 - 0.15)
        post.lathe([(0.0, 0.0), (0.15, 0.0), (0.15, 0.02), (0.06, 0.05), (0.025, 0.08), (0.022, 0.88), (0.035, 0.9),
                    (0.04, 0.95), (0.0, 0.97)], "brass", centre=(x, 0.0, 0.0), segs=20)
    pts = []
    n = 12
    x0, x1 = -(span / 2 - 0.15), span / 2 - 0.15
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + (x1 - x0) * t, 0.0, 0.9 - 0.22 * math.sin(math.pi * t)))
    rope.tube(pts, 0.018, "velvet_red", segs=8)
    o.build()
    k.collision([((-span / 2, -0.15, 0.0), (span / 2, 0.15, 0.97))])


def _music_stand(k: Kit, p: dict) -> None:
    o = k.obj("Stand")
    a = o.part(bevel=0.0)
    for i in range(3):
        ang = 2 * math.pi * i / 3 + 0.3
        a.rod((0.0, 0.0, 0.12), (math.cos(ang) * 0.28, math.sin(ang) * 0.28, 0.007), 0.007, "metal_dark", segs=6)
    a.rod((0.0, 0.0, 0.0), (0.0, 0.0, 1.05), 0.01, "metal_dark", segs=8)
    a.profile_x([(-0.02, 1.02), (0.0, 1.0), (0.04, 1.32), (0.02, 1.34)], -0.25, 0.25, "metal_dark")
    a.bx((-0.25, 0.0, 1.0), (0.25, 0.05, 1.02), "metal_dark")
    a.bx((-0.2, 0.025, 1.03), (0.2, 0.03, 1.28), "paper")
    o.build()
    k.collision([((-0.25, -0.2, 0.0), (0.25, 0.2, 1.34))])


def _lectern(k: Kit, p: dict) -> None:
    """Guest-list lectern: walnut, a sloped top with the leather-bound list and a small brass lamp."""
    w, d, h = 0.55, 0.42, 1.12
    o = k.obj("Lectern")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    hard.bx((-0.22, -0.16, 0.0), (0.22, 0.16, 0.06), "wood_dark")
    hard.bx((-0.16, -0.12, 0.06), (0.16, 0.12, h - 0.12), "walnut")
    hard.profile_x([(-d / 2, h - 0.12), (d / 2, h - 0.12), (d / 2, h - 0.05), (-d / 2, h)], -w / 2, w / 2, "walnut")
    trim.profile_x([(-0.14, h - 0.045), (0.12, h - 0.065), (0.12, h - 0.055), (-0.14, h - 0.035)], -0.17, 0.17, "leather")
    trim.bx((-w / 2 - 0.003, -0.02, h - 0.13), (w / 2 + 0.003, 0.02, h - 0.12), "brass")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _coat_rail(k: Kit, p: dict) -> None:
    """Cloakroom rail: a brass rail on two uprights and castors, a row of dark coats and a few ticket tags."""
    w, d, h = 1.5, 0.55, 1.75
    o = k.obj("Rail")
    fr = o.part(bevel=0.0)
    soft = o.part(bevel=0.01, segments=2)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.03)
        fr.bx((x - 0.02, -d / 2, 0.06), (x + 0.02, d / 2, 0.09), "metal_dark")
        fr.rod((x, 0.0, 0.09), (x, 0.0, h), 0.015, "brass", segs=8)
        for sy in (-1, 1):
            fr.cyl(0.03, 0.025, (x, sy * (d / 2 - 0.04), 0.03), "rubber", axis="Y", segs=10)
    fr.rod((-w / 2 + 0.03, 0.0, h - 0.02), (w / 2 - 0.03, 0.0, h - 0.02), 0.014, "brass", segs=8)
    cols = ("fabric_charcoal", "velvet_charcoal", "canvas_walnut", "fabric_charcoal", "bag_black", "velvet_charcoal",
            "fabric_charcoal", "canvas_walnut")
    for i, key in enumerate(cols):
        x = -w / 2 + 0.16 + i * (w - 0.32) / (len(cols) - 1)
        ln = 1.0 + 0.08 * ((i * 5) % 3)
        soft.bx((x - 0.07, -0.24, h - 0.08 - ln), (x + 0.07, 0.24, h - 0.06), key)
        fr.bx((x - 0.012, 0.24, h - 0.3), (x + 0.012, 0.243, h - 0.26), "paper")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


# -------------------------------------------------------------------------------------- galleries

def _bench(k: Kit, p: dict) -> None:
    """Backless gallery bench: green leather cushion (1.6 x 0.5 m) on a walnut frame and gilt-capped legs."""
    w, d = 1.6, 0.5
    o = k.obj("Bench")
    soft = o.part(bevel=0.02, segments=3)
    fr = o.part(bevel=0.004, segments=2)
    soft.bx((-w / 2, -d / 2, 0.34), (w / 2, d / 2, 0.46), "paint_halberd")
    fr.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.3), (w / 2 - 0.02, d / 2 - 0.02, 0.34), "walnut")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.07), sy * (d / 2 - 0.07)
            fr.bx((x - 0.03, y - 0.03, 0.03), (x + 0.03, y + 0.03, 0.3), "walnut")
            fr.bx((x - 0.033, y - 0.033, 0.0), (x + 0.033, y + 0.033, 0.03), "brass")
    fr.bx((-w / 2 + 0.1, -0.015, 0.1), (w / 2 - 0.1, 0.015, 0.13), "walnut")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.46))])


def _figure(p, h0: float, shape: str, scale: float = 1.0) -> None:
    """Abstract bronze (original): `a` a standing figure of stacked ellipsoids, `b` a looped ribbon form."""
    s = scale
    if shape == "a":
        p.lathe([(0.0, h0), (0.1 * s, h0), (0.1 * s, h0 + 0.03 * s), (0.04 * s, h0 + 0.05 * s), (0.0, h0 + 0.05 * s)],
                "brass_bronze", segs=16)
        for (z, rx, rz, ox) in ((0.18, 0.06, 0.14, 0.0), (0.42, 0.075, 0.13, 0.015), (0.62, 0.085, 0.09, 0.0),
                                (0.76, 0.05, 0.06, -0.01)):
            p.sphere(rx * s, (ox * s, 0.0, h0 + z * s), "brass_bronze", segs=14, rings=8, scale=(1.0, 0.8, rz / rx))
    else:
        p.lathe([(0.0, h0), (0.12 * s, h0), (0.12 * s, h0 + 0.04 * s), (0.0, h0 + 0.04 * s)], "brass_bronze", segs=16)
        p.torus(0.2 * s, 0.035 * s, (0.0, 0.0, h0 + 0.3 * s), "brass_bronze", segs=28, rsegs=8, axis="Y")
        p.torus(0.13 * s, 0.03 * s, (0.05 * s, 0.0, h0 + 0.55 * s), "brass_bronze", segs=24, rsegs=8, axis="X")
        p.rod((0.0, 0.0, h0 + 0.04 * s), (0.0, 0.0, h0 + 0.12 * s), 0.03 * s, "brass_bronze", segs=10)


def _plinth(k: Kit, p: dict) -> None:
    """Limestone plinth (0.5 x 0.5 x 1.0 m, gilt-ringed base) with an original bronze on top."""
    s, h = 0.5, 1.0
    o = k.obj("Plinth")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    hard.bx((-s / 2, -s / 2, 0.06), (s / 2, s / 2, h - 0.04), "plaster")
    hard.bx((-s / 2 - 0.02, -s / 2 - 0.02, 0.0), (s / 2 + 0.02, s / 2 + 0.02, 0.06), "marble")
    hard.bx((-s / 2 - 0.015, -s / 2 - 0.015, h - 0.04), (s / 2 + 0.015, s / 2 + 0.015, h), "marble")
    trim.bx((-s / 2 - 0.004, -s / 2 - 0.004, 0.06), (s / 2 + 0.004, s / 2 + 0.004, 0.07), "brass")
    fig = o.part(bevel=0.0)
    _figure(fig, h, p["shape"])
    o.build()
    k.collision([((-s / 2 - 0.02, -s / 2 - 0.02, 0.0), (s / 2 + 0.02, s / 2 + 0.02, h))])


def _court_bronze(k: Kit, p: dict) -> None:
    """Sculpture Court bronze: a 1.6 m figure on a 0.6 m granite pedestal (1.0 x 1.0)."""
    s, h = 1.0, 0.6
    o = k.obj("Bronze")
    hard = o.part(bevel=0.006, segments=2)
    hard.bx((-s / 2, -s / 2, 0.0), (s / 2, s / 2, h), "stone_dark")
    hard.bx((-s / 2 - 0.03, -s / 2 - 0.03, h - 0.06), (s / 2 + 0.03, s / 2 + 0.03, h), "stone_dark")
    fig = o.part(bevel=0.0)
    _figure(fig, h, "a", 2.0)
    o.build()
    k.collision([((-s / 2 - 0.03, -s / 2 - 0.03, 0.0), (s / 2 + 0.03, s / 2 + 0.03, h + 1.6))])


# ----------------------------------------------------------------------------------- back of house

def _easel(k: Kit, p: dict) -> None:
    """Studio H-frame easel (oak), empty, the tray at 0.72 m and a crank."""
    w = 0.8
    o = k.obj("Easel")
    wd = o.part(bevel=0.004)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.08)
        wd.bx((x - 0.03, -0.12, 0.08), (x + 0.03, -0.06, 2.05), "wood_oak")
    wd.bx((-w / 2 + 0.05, -0.12, 0.08), (w / 2 - 0.05, -0.06, 0.14), "wood_oak")
    wd.bx((-w / 2 + 0.05, -0.12, 2.0), (w / 2 - 0.05, -0.06, 2.06), "wood_oak")
    wd.bx((-0.05, -0.12, 0.14), (0.05, -0.06, 2.0), "wood_oak")
    wd.bx((-w / 2 - 0.02, -0.06, 0.69), (w / 2 + 0.02, 0.06, 0.72), "wood_oak")
    wd.bx((-w / 2 - 0.02, 0.04, 0.72), (w / 2 + 0.02, 0.06, 0.76), "wood_oak")
    wd.bx((-0.3, -0.62, 0.0), (0.3, -0.12, 0.08), "wood_oak")
    wd.bx((-0.06, -0.06, 1.5), (0.06, 0.02, 1.56), "wood_oak")
    m = o.part(bevel=0.0)
    m.cyl(0.03, 0.04, (w / 2 - 0.02, -0.09, 0.4), "metal_dark", axis="X", segs=12)
    m.rod((w / 2 + 0.02, -0.09, 0.4), (w / 2 + 0.02, -0.09, 0.32), 0.006, "metal_dark", segs=6)
    o.build()
    k.collision([((-w / 2, -0.62, 0.0), (w / 2, 0.06, 2.06))])


def _suction_table(k: Kit, p: dict) -> None:
    """Conservation suction (low-pressure) table: 2.0 x 1.2 m perforated aluminium top at 0.86 m, the pump box under
    it, a hinged acrylic dome lid propped open at the back."""
    w, d, h = 2.0, 1.2, 0.86
    o = k.obj("Table")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0)
    hard.bx((-w / 2, -d / 2, h - 0.06), (w / 2, d / 2, h), "steel")
    for sx in (-1, 1):
        for sy in (-1, 1):
            hard.bx((sx * (w / 2 - 0.06) - 0.03, sy * (d / 2 - 0.06) - 0.03, 0.0), (sx * (w / 2 - 0.06) + 0.03,
                    sy * (d / 2 - 0.06) + 0.03, h - 0.06), "metal_white")
    hard.bx((-0.4, -0.3, 0.2), (0.4, 0.3, 0.6), "metal_white")
    for i in range(18):
        for j in range(10):
            trim.cyl(0.006, 0.002, (-w / 2 + 0.1 + i * (w - 0.2) / 17, -d / 2 + 0.1 + j * (d - 0.2) / 9, h + 0.0005),
                     "plastic_black", segs=6)
    trim.bx((-0.3, -0.31, 0.45), (0.3, -0.302, 0.55), "emit_screen")
    knob(trim, 0.32, -0.31, 0.5, "steel", r=0.015)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _plan_chest(k: Kit, p: dict) -> None:
    """Plan chest for works on paper: 1.3 x 0.95 x 0.9 m, ten shallow drawers with brass pulls and label holders."""
    w, d, h = 1.3, 0.95, 0.9
    o = k.obj("Chest")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    hard.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.01, h - 0.03), "paint_greige")
    hard.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.0), (w / 2 - 0.03, d / 2 - 0.05, 0.08), "plastic_black")
    hard.bx((-w / 2 - 0.01, -d / 2 - 0.01, h - 0.03), (w / 2 + 0.01, d / 2 + 0.01, h), "wood_oak")
    n = 10
    for i in range(n):
        z0 = 0.1 + i * (h - 0.15) / n
        z1 = z0 + (h - 0.15) / n - 0.008
        hard.bx((-w / 2 + 0.02, d / 2 - 0.01, z0), (w / 2 - 0.02, d / 2, z1), "paint_greige")
        bar_handle(trim, -0.18, 0.18, d / 2, (z0 + z1) / 2, "brass", r=0.005, standoff=0.02)
        trim.bx((0.3, d / 2, (z0 + z1) / 2 - 0.012), (0.4, d / 2 + 0.003, (z0 + z1) / 2 + 0.012), "brass")
    o.build()
    k.collision([((-w / 2 - 0.01, -d / 2 - 0.01, 0.0), (w / 2 + 0.01, d / 2 + 0.01, h))])


def _gas_cylinders(k: Kit, p: dict) -> None:
    """Inert-gas suppression bank: six 1.6 m cylinders (red / grey) in a steel rack with a manifold and gauges."""
    w, d, h = 1.5, 0.36, 1.85
    o = k.obj("Bank")
    rack = o.part(bevel=0.003)
    cyl = o.part(bevel=0.0)
    for sx in (-1, 1):
        rack.bx((sx * (w / 2) - 0.03 * (sx > 0), -d / 2, 0.0), (sx * (w / 2) + 0.03 * (sx < 0), d / 2, h), "metal_dark")
    for z in (0.5, 1.2):
        rack.bx((-w / 2, d / 2 - 0.03, z), (w / 2, d / 2, z + 0.05), "metal_dark")
    rack.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.04), "metal_dark")
    for i in range(6):
        x = -w / 2 + 0.15 + i * (w - 0.3) / 5
        key = "metal_red" if i % 3 != 2 else "metal_grey"
        cyl.lathe([(0.0, 0.04), (0.11, 0.04), (0.115, 0.1), (0.115, 1.45), (0.08, 1.55), (0.03, 1.6), (0.0, 1.6)], key,
                  centre=(x, 0.0, 0.0), segs=16)
        cyl.rod((x, 0.0, 1.6), (x, 0.0, 1.68), 0.018, "brass", segs=8)
    cyl.rod((-w / 2 + 0.1, 0.0, 1.72), (w / 2 - 0.1, 0.0, 1.72), 0.025, "steel", segs=10)
    for x in (-0.3, 0.3):
        cyl.cyl(0.04, 0.02, (x, -0.04, 1.77), "metal_white", axis="Y", segs=14)
    o.build()
    k.collision([((-w / 2 - 0.03, -d / 2, 0.0), (w / 2 + 0.03, d / 2, h))])


# ------------------------------------------------------------------------------------------ outside

def _uplight(k: Kit, p: dict) -> None:
    """Gala uplight: a 0.24 m ground canister on a cable spike, its lens up (the lilac wash on the facade)."""
    o = k.obj("Uplight")
    a = o.part(bevel=0.003)
    a.cyl(0.12, 0.16, (0.0, 0.0, 0.08), "metal_dark", segs=20)
    a.cyl(0.13, 0.015, (0.0, 0.0, 0.16), "metal_dark", segs=20)
    e = o.part(bevel=0.0)
    e.cyl(0.1, 0.004, (0.0, 0.0, 0.17), "emit_lilac", segs=20)
    a.bx((-0.15, -0.03, 0.0), (0.15, 0.03, 0.02), "metal_dark")
    o.build()


def _heater(k: Kit, p: dict) -> None:
    """Standing patio heater (gas): a 2.2 m post with the burner head and reflector hood; the glow is its light."""
    o = k.obj("Heater")
    a = o.part(bevel=0.003)
    a.lathe([(0.0, 0.0), (0.24, 0.0), (0.24, 0.05), (0.2, 0.08), (0.2, 0.75), (0.06, 0.8), (0.05, 0.8), (0.0, 0.8)],
            "metal_dark", segs=20)
    a.rod((0.0, 0.0, 0.8), (0.0, 0.0, 1.95), 0.03, "steel", segs=10)
    a.lathe([(0.0, 1.95), (0.1, 1.95), (0.1, 2.15), (0.0, 2.15)], "metal_dark", segs=16)
    a.lathe([(0.04, 2.2), (0.4, 2.15), (0.42, 2.18), (0.05, 2.24), (0.0, 2.24)], "steel", segs=24)
    e = o.part(bevel=0.0)
    e.lathe([(0.0, 1.97), (0.085, 1.97), (0.085, 2.13), (0.0, 2.13)], "emit_fire", segs=16)
    o.build()
    k.collision([((-0.24, -0.24, 0.0), (0.24, 0.24, 2.24))])


def _ashtray(k: Kit, p: dict) -> None:
    o = k.obj("Ashtray")
    a = o.part(bevel=0.002)
    a.lathe([(0.0, 0.0), (0.16, 0.0), (0.16, 0.03), (0.04, 0.05), (0.035, 0.85), (0.14, 0.88), (0.15, 0.95), (0.0, 0.95)],
            "steel", segs=20)
    s = o.part(bevel=0.0)
    s.cyl(0.12, 0.01, (0.0, 0.0, 0.955), "concrete", segs=16)
    o.build()
    k.collision([((-0.16, -0.16, 0.0), (0.16, 0.16, 0.95))])


def _bench_stone(k: Kit, p: dict) -> None:
    """Limestone court bench: a 1.8 m slab on two blocks."""
    w, d = 1.8, 0.48
    o = k.obj("Bench")
    a = o.part(bevel=0.008, segments=2)
    a.bx((-w / 2, -d / 2, 0.36), (w / 2, d / 2, 0.46), "plaster")
    for sx in (-1, 1):
        a.bx((sx * (w / 2 - 0.25) - 0.15, -d / 2 + 0.04, 0.0), (sx * (w / 2 - 0.25) + 0.15, d / 2 - 0.04, 0.36), "plaster")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.46))])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
