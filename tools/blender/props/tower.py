"""Shadow Ledger (Kessler & Moor, corporate tower floor): penthouse offices, partners' suite and the
roof terrace. Walnut / cognac leather / ivory and charcoal fabric / brass and brushed steel / cream
marble / dark stone (upscale law-firm palette).

Floor props: bottom-centre pivot, front +Y (Godot -Z); wall-backed floor props have their back on
-Y; wall-mounted: back at y = 0, centred vertically on the origin (catalog `z` = centre height).
No lettering. New props of kinds that existing kits already use unpinned (table, chair,
counter_transaction, planter, table_lamp, rug) are `pin_only`, so earlier kits' layouts stay exactly
as they were.
"""

import math

from _pb import Kit, bar_handle, chair_seat_marker, knob, legs4, panel_door

TRI_BUDGET = 16000
WARM = "#FFB46B"
VARIANTS = {
    # partners' suite: bedroom, dressing, dining, lounge
    "prop_bed_double": {"fn": "bed_double", "cat": {"kind": "bed", "place": "wall", "support": True, "clear": 0.6, "group": "tower",
                                                    "top": 0.55}},
    "prop_nightstand": {"fn": "nightstand", "cat": {"kind": "nightstand", "place": "wall", "support": True, "group": "tower", "top": 0.55}},
    "prop_wardrobe": {"fn": "wardrobe", "cat": {"kind": "wardrobe", "place": "wall", "clear": 0.7, "group": "tower"}},
    "prop_table_dining": {"fn": "table_slab", "w": 2.4, "d": 1.0, "bases": 2,
                          "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.8, "group": "tower", "top": 0.74,
                                  "pin_only": True}},
    "prop_chair_dining": {"fn": "chair_dining", "cat": {"kind": "chair", "place": "seat", "hosts": ["table"], "group": "tower", "pin_only": True}},
    "prop_bar_counter": {"fn": "bar_counter", "cat": {"kind": "counter_bar", "place": "wall", "support": True, "clear": 0.9, "group": "tower",
                                                      "top": 1.1}},
    "prop_piano_grand": {"fn": "piano_grand", "cat": {"kind": "piano", "place": "floor", "clear": 0.6, "group": "tower"}},
    "prop_wine_rack": {"fn": "wine_rack", "cat": {"kind": "wine_rack", "place": "wall", "clear": 0.7, "group": "tower"}},
    # bedside lamp: the existing table lamp only fits side tables / credenzas; pinned by bedroom kits
    "prop_lamp_bedside": {"fn": "lamp_bedside", "cat": {"kind": "table_lamp", "place": "on", "hosts": ["nightstand", "side_table", "credenza"],
                                                        "fixture": True, "group": "tower", "pin_only": True,
                                                        "light": {"type": "omni", "color": WARM, "energy": 0.5, "range": 2.5,
                                                                  "pos": [0.0, 0.4, 0.0]}}},
    # dining rug big enough for a 2.4 m table and its chairs
    "prop_rug_dining": {"fn": "rug_dining", "cat": {"kind": "rug", "place": "rug", "support": True, "group": "tower", "pin_only": True}},
    # wall display for boardroom / conference presentations
    "prop_tv_wall": {"fn": "tv_wall", "cat": {"kind": "tv", "place": "wall_mount", "z": 1.45, "group": "tower"}},
    # offices + meeting rooms
    "prop_table_conference": {"fn": "table_racetrack", "w": 3.0, "d": 1.2,
                              "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.8, "group": "tower", "top": 0.74,
                                      "pin_only": True}},
    "prop_table_boardroom": {"fn": "table_slab", "w": 4.2, "d": 1.3, "bases": 3,
                             "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.8, "group": "tower", "top": 0.74,
                                     "pin_only": True}},
    "prop_reception_desk": {"fn": "reception_desk", "cat": {"kind": "counter_transaction", "place": "wall", "support": True, "clear": 1.0,
                                                            "group": "tower", "top": 1.05, "pin_only": True,
                                                            "keepout": [[-1.6, -0.1, 1.6, 0.5]]}},
    "prop_laptop": {"fn": "laptop", "cat": {"kind": "laptop", "place": "on", "hosts": ["desk", "table"], "group": "tower"}},
    # galleries
    "prop_plinth": {"fn": "plinth", "cat": {"kind": "plinth", "place": "floor", "support": True, "clear": 0.4, "group": "tower", "top": 1.1}},
    # roof terrace
    "prop_lounger": {"fn": "lounger", "cat": {"kind": "lounger", "place": "floor", "clear": 0.4, "group": "exterior"}},
    "prop_patio_heater": {"fn": "patio_heater", "cat": {"kind": "heater", "place": "floor", "fixture": True, "group": "exterior",
                                                        "light": {"type": "omni", "color": "#FF9A50", "energy": 1.2, "range": 4.0,
                                                                  "pos": [0.0, 1.95, 0.0]}}},
    "prop_planter_terrace": {"fn": "planter_terrace", "cat": {"kind": "planter", "place": "wall", "group": "exterior", "pin_only": True}},
}


# ---------------------------------------------------------------------------------- suite

def _bed_double(k: Kit, p: dict) -> None:
    """Double bed, head end on -Y (against the wall): walnut base, charcoal upholstered headboard,
    2.0 x 1.8 m mattress (top 0.55 m), ivory duvet from 0.45 m to the foot (draped over the sides
    and foot), two pillows 0.05-0.45 m from the head end, a charcoal throw. `Pelvis` empty on the
    mattress top 0.9 m from the head end (sleeping NPC root: 1.1 m of mattress ahead of it)."""
    mw, ml, mt = 1.8, 2.0, 0.55
    yh = -1.0                     # mattress head end
    yf = yh + ml                  # mattress foot end (1.0)
    o = k.obj("Bed")
    wood = o.part(bevel=0.005, segments=2)
    soft = o.part(bevel=0.03, segments=2)
    pil = o.part(bevel=0.045, segments=2)
    trim = o.part(bevel=0.0015)
    # headboard: walnut back board + upholstered panel (front face at the mattress head end)
    wood.bx((-1.0, yh - 0.1, 0.0), (1.0, yh - 0.04, 1.2), "walnut")
    soft.bx((-0.96, yh - 0.04, 0.4), (0.96, yh, 1.14), "fabric_charcoal")
    # base: walnut frame round the mattress, short legs
    wood.bx((-0.92, yh, 0.1), (0.92, yf + 0.02, 0.32), "walnut")
    trim.bx((-0.922, yh, 0.12), (0.922, yf + 0.022, 0.132), "brass")
    for sx in (-1, 1):
        for y in (yh + 0.1, yf - 0.06):
            wood.bx((sx * 0.85 - 0.04, y - 0.04, 0.0), (sx * 0.85 + 0.04, y + 0.04, 0.1), "wood_dark")
    # mattress
    soft.bx((-mw / 2, yh + 0.005, 0.32), (mw / 2, yf, mt), "canvas_ivory")
    # duvet: from 0.45 m to the foot, hanging over sides and foot
    dy0 = yh + 0.45
    soft.bx((-mw / 2 - 0.035, dy0, 0.36), (mw / 2 + 0.035, yf + 0.035, mt + 0.035), "fabric_ivory")
    # turned-down edge and a throw across the foot
    trim.bx((-mw / 2 - 0.045, dy0 - 0.012, mt + 0.035), (mw / 2 + 0.045, dy0 + 0.18, mt + 0.05), "fabric_ivory")
    soft.bx((-mw / 2 - 0.05, yf - 0.55, 0.42), (mw / 2 + 0.05, yf - 0.2, mt + 0.06), "fabric_charcoal")
    # two pillows, 0.05-0.45 m from the head end
    for sx in (-1, 1):
        pil.bx((sx * 0.44 - 0.36, yh + 0.05, mt + 0.002), (sx * 0.44 + 0.36, yh + 0.45, mt + 0.15), "canvas_ivory")
    o.build()
    k.empty("Pelvis", (0.0, yh + 0.9, mt))
    k.collision([((-1.0, yh - 0.1, 0.0), (1.0, yh, 1.2)), ((-0.94, yh, 0.0), (0.94, yf + 0.04, mt + 0.05))])


def _nightstand(k: Kit, p: dict) -> None:
    """Walnut bedside table: two drawers with brass knobs on a recessed plinth, top 0.55 m."""
    w, d, h = 0.5, 0.42, 0.55
    o = k.obj("Nightstand")
    a = o.part(bevel=0.004, segments=2)
    t = o.part(bevel=0.0015)
    a.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.0), (w / 2 - 0.03, d / 2 - 0.05, 0.06), "wood_dark")
    a.bx((-w / 2, -d / 2, 0.06), (w / 2, d / 2 - 0.02, h - 0.03), "walnut")
    a.bx((-w / 2 - 0.005, -d / 2, h - 0.03), (w / 2 + 0.005, d / 2 + 0.005, h), "walnut")
    for i in range(2):
        z0 = 0.08 + i * 0.21
        a.bx((-w / 2 + 0.015, d / 2 - 0.02, z0), (w / 2 - 0.015, d / 2, z0 + 0.19), "walnut")
        knob(t, 0.0, d / 2, z0 + 0.095)
    o.build()
    k.collision([((-w / 2 - 0.005, -d / 2, 0.0), (w / 2 + 0.005, d / 2 + 0.005, h))])


def _wardrobe(k: Kit, p: dict) -> None:
    """Walnut double wardrobe 1.6 x 0.6 x 2.1 m: four raised-panel doors, tall brass bar pulls,
    a dark plinth and a cornice."""
    w, d, h = 1.6, 0.6, 2.1
    o = k.obj("Wardrobe")
    a = o.part(bevel=0.004, segments=2)
    t = o.part(bevel=0.0)
    y0, y1 = -d / 2, d / 2
    a.bx((-w / 2 + 0.02, y0 + 0.02, 0.0), (w / 2 - 0.02, y1 - 0.06, 0.08), "wood_dark")
    a.bx((-w / 2, y0, 0.08), (w / 2, y1 - 0.03, h - 0.05), "walnut")
    a.bx((-w / 2 - 0.015, y0, h - 0.05), (w / 2 + 0.015, y1 + 0.015, h), "walnut")
    n = 4
    dw = w / n
    for i in range(n):
        x0 = -w / 2 + i * dw + 0.004
        x1 = x0 + dw - 0.008
        panel_door(a, x0, x1, 0.1, h - 0.07, y1 - 0.03, "walnut", "brass", frame_w=0.07, depth=0.018)
        hx = x1 - 0.05 if i % 2 == 0 else x0 + 0.05
        bar_handle(t, hx, 1.3, y1 - 0.012, 0.85, "brass", r=0.009, standoff=0.035, vertical=True)
    o.build()
    k.collision([((-w / 2 - 0.015, y0, 0.0), (w / 2 + 0.015, y1 + 0.015, h))])


def _table_slab(k: Kit, p: dict) -> None:
    """Walnut slab table (dining / boardroom): 0.05 m top at 0.74 m with a brass edge line, on
    dark-stone pedestal bases with brass collars."""
    w, d, h = p["w"], p["d"], 0.74
    nb = p["bases"]
    o = k.obj("Table")
    top = o.part(bevel=0.006, segments=2)
    base = o.part(bevel=0.004, segments=1)
    trim = o.part(bevel=0.0)
    top.bx((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h), "walnut")
    trim.bx((-w / 2 - 0.003, -d / 2 - 0.003, h - 0.032), (w / 2 + 0.003, d / 2 + 0.003, h - 0.026), "brass")
    span = w - 2 * 0.45
    cols = []
    for i in range(nb):
        x = -span / 2 + i * span / max(1, nb - 1)
        base.bx((x - 0.2, -d / 2 + 0.18, 0.0), (x + 0.2, d / 2 - 0.18, 0.05), "stone_dark")
        base.bx((x - 0.09, -d / 2 + 0.26, 0.05), (x + 0.09, d / 2 - 0.26, h - 0.08), "stone_dark")
        base.bx((x - 0.14, -d / 2 + 0.2, h - 0.08), (x + 0.14, d / 2 - 0.2, h - 0.05), "stone_dark")
        trim.bx((x - 0.095, -d / 2 + 0.255, 0.1), (x + 0.095, d / 2 - 0.255, 0.115), "brass")
        trim.bx((x - 0.095, -d / 2 + 0.255, h - 0.12), (x + 0.095, d / 2 - 0.255, h - 0.105), "brass")
        cols.append(((x - 0.2, -d / 2 + 0.18, 0.0), (x + 0.2, d / 2 - 0.18, h - 0.05)))
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h))] + cols)


def _chair_dining(k: Kit, p: dict) -> None:
    """Upholstered dining chair: walnut frame, ivory seat (0.47 m) and padded back (back on -Y)."""
    seat = 0.47
    o = k.obj("Chair")
    frame = o.part(bevel=0.003, segments=1)
    soft = o.part(bevel=0.02, segments=2)
    w, d = 0.48, 0.5
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.03)
        frame.bx((x - 0.02, d / 2 - 0.06, 0.0), (x + 0.02, d / 2 - 0.02, seat - 0.06), "walnut")
        # back legs rise into the back posts (slight rake)
        frame.profile_x([(-d / 2 + 0.0, 0.0), (-d / 2 + 0.04, 0.0), (-d / 2 + 0.05, seat - 0.06), (-d / 2 + 0.02, 0.95),
                         (-d / 2 - 0.02, 0.95), (-d / 2 + 0.01, seat - 0.06)], x - 0.02, x + 0.02, "walnut")
    frame.bx((-w / 2 + 0.03, -d / 2 + 0.03, seat - 0.1), (w / 2 - 0.03, d / 2 - 0.03, seat - 0.06), "walnut")
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.03)
        frame.bx((x - 0.012, -d / 2 + 0.04, 0.15), (x + 0.012, d / 2 - 0.06, 0.18), "walnut")
    soft.bx((-w / 2 + 0.01, -d / 2 + 0.03, seat - 0.065), (w / 2 - 0.01, d / 2, seat), "fabric_ivory")
    soft.profile_x([(-d / 2 + 0.045, seat + 0.07), (-d / 2 + 0.085, seat + 0.07), (-d / 2 + 0.06, 0.92), (-d / 2 + 0.02, 0.92)],
                   -w / 2 + 0.035, w / 2 - 0.035, "fabric_ivory")
    o.build()
    chair_seat_marker(k, seat)
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, seat)), ((-w / 2, -d / 2 - 0.02, seat), (w / 2, -d / 2 + 0.09, 0.95))])


def _bar_counter(k: Kit, p: dict) -> None:
    """Lounge bar counter (back to the wall): walnut-panelled front on a stone plinth, marble top at
    1.1 m overhanging the front, brass foot rail on brackets."""
    w, d, h = 2.4, 0.6, 1.1
    o = k.obj("Bar")
    hard = o.part(bevel=0.004, segments=2)
    top = o.part(bevel=0.006, segments=2)
    trim = o.part(bevel=0.0015)
    rail = o.part(bevel=0.0)
    y0, y1 = -d / 2, d / 2 - 0.08
    hard.bx((-w / 2, y0 + 0.02, 0.1), (w / 2, y1, h - 0.04), "walnut")
    hard.bx((-w / 2 + 0.02, y0 + 0.04, 0.0), (w / 2 - 0.02, y1 - 0.04, 0.1), "stone_dark")
    n = 4
    pw = (w - 0.08) / n
    for i in range(n):
        x0 = -w / 2 + 0.04 + i * pw + 0.025
        x1 = x0 + pw - 0.05
        hard.bx((x0, y1, 0.18), (x1, y1 + 0.015, h - 0.14), "walnut")
        hard.bx((x0 + 0.05, y1 + 0.015, 0.24), (x1 - 0.05, y1 + 0.027, h - 0.2), "walnut")
    trim.bx((-w / 2, y1, 0.1), (w / 2, y1 + 0.02, 0.125), "brass")
    trim.bx((-w / 2, y1, h - 0.1), (w / 2, y1 + 0.02, h - 0.08), "brass")
    top.bx((-w / 2 - 0.02, y0, h - 0.04), (w / 2 + 0.02, d / 2 + 0.02, h), "marble")
    # foot rail 0.2 m above the floor, 0.2 m in front of the panels
    ry = y1 + 0.2
    rail.rod((-w / 2 + 0.08, ry, 0.2), (w / 2 - 0.08, ry, 0.2), 0.025, "brass", segs=14)
    for x in (-w / 2 + 0.15, 0.0, w / 2 - 0.15):
        rail.rod((x, y1 + 0.02, 0.2), (x, ry, 0.2), 0.012, "brass", segs=8)
        rail.cyl(0.035, 0.012, (x, y1 + 0.026, 0.2), "brass", axis="Y", segs=12)
    o.build()
    k.collision([((-w / 2 - 0.02, y0, 0.0), (w / 2 + 0.02, d / 2 + 0.02, h)),
                 ((-w / 2 + 0.08, y1, 0.17), (w / 2 - 0.08, ry + 0.03, 0.23))])


def _piano_grand(k: Kit, p: dict) -> None:
    """Grand piano (black lacquer, lid closed) with its bench: bentside case on three tapered legs,
    keyboard at the front (+Y), pedal lyre, leather-topped bench in front of the keys."""
    oy = -0.28                      # shift so the piano + bench footprint is centred on the pivot
    o = k.obj("Piano")
    case = o.part(bevel=0.0)
    keys = o.part(bevel=0.0015)
    legs = o.part(bevel=0.0)
    outline = [(0.75, 0.7), (-0.75, 0.7), (-0.75, 0.35), (-0.72, 0.2), (-0.62, 0.06), (-0.46, -0.08), (-0.27, -0.24),
               (-0.1, -0.44), (0.0, -0.64), (0.1, -0.82), (0.25, -0.93), (0.45, -0.98), (0.62, -0.96), (0.72, -0.88), (0.75, -0.74)]
    case.slab([(x, y + oy) for x, y in outline], 0.62, 0.95, "plastic_black")
    lid = [(x * 1.008, y * 1.008 + oy) for x, y in outline]
    case.slab(lid, 0.95, 0.968, "plastic_black")
    # brass lid hinges on the straight (bass, +X) side
    for y in (0.3, -0.2, -0.6):
        case.bx((0.752, y - 0.03 + oy, 0.94), (0.762, y + 0.03 + oy, 0.975), "brass")
    # key frame, cheek blocks, fallboard
    case.bx((-0.68, 0.7 + oy, 0.62), (0.68, 0.98 + oy, 0.69), "plastic_black")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.68, sx * 0.75))
        case.bx((x0, 0.7 + oy, 0.62), (x1, 0.98 + oy, 0.77), "plastic_black")
    case.bx((-0.68, 0.7 + oy, 0.69), (0.68, 0.83 + oy, 0.77), "plastic_black")
    # 52 white keys, black keys in the 2-3 pattern
    nw = 52
    kw = 1.36 / nw
    for i in range(nw):
        x0 = -0.68 + i * kw
        keys.bx((x0 + 0.0008, 0.83 + oy, 0.69), (x0 + kw - 0.0008, 0.975 + oy, 0.708), "plastic_white")
    for i in range(nw - 1):
        if (i + 5) % 7 in (2, 6):   # no black key after E and B (keyboard starts on A)
            continue
        xc = -0.68 + (i + 1) * kw
        keys.bx((xc - kw * 0.3, 0.83 + oy, 0.708), (xc + kw * 0.3, 0.92 + oy, 0.722), "plastic_black")
    # three tapered legs with brass ferrules
    for x, y in ((0.62, 0.55), (-0.62, 0.55), (0.42, -0.78)):
        legs.lathe([(0.04, 0.05), (0.05, 0.3), (0.07, 0.58), (0.075, 0.62)], "plastic_black", centre=(x, y + oy, 0.0), segs=12)
        legs.lathe([(0.045, 0.0), (0.045, 0.05)], "brass", centre=(x, y + oy, 0.0), segs=12)
    # pedal lyre
    for sx in (-1, 1):
        legs.rod((sx * 0.08, 0.5 + oy, 0.08), (sx * 0.06, 0.5 + oy, 0.62), 0.018, "plastic_black", segs=8)
    legs.bx((-0.15, 0.44 + oy, 0.03), (0.15, 0.56 + oy, 0.09), "plastic_black")
    for x in (-0.07, 0.0, 0.07):
        legs.bx((x - 0.015, 0.56 + oy, 0.055), (x + 0.015, 0.66 + oy, 0.068), "brass")
    # bench
    b = o.part(bevel=0.006, segments=2)
    by0, by1 = 1.18 + oy, 1.53 + oy
    b.bx((-0.38, by0, 0.44), (0.38, by1, 0.5), "leather")
    legs4(b, 0.76, by1 - by0, 0.44, 0.03, 0.045, "plastic_black")
    o.build()
    k.collision([((-0.76, -0.98 + oy, 0.62), (0.76, 0.98 + oy, 0.97)), ((-0.15, 0.44 + oy, 0.0), (0.15, 0.56 + oy, 0.62)),
                 ((-0.38, by0, 0.0), (0.38, by1, 0.5))],
                cylinders=[(0.075, 0.62, (x, y + oy, 0.31)) for x, y in ((0.62, 0.55), (-0.62, 0.55), (0.42, -0.78))])


def _wine_rack(k: Kit, p: dict) -> None:
    """Walnut wine wall 1.2 x 0.4 x 2.0 m: 8 x 12 cubbies, bottles lying necks out (a few gaps)."""
    w, d, h = 1.2, 0.4, 2.0
    o = k.obj("Rack")
    a = o.part(bevel=0.003)
    bt = o.part(bevel=0.0)
    y0, y1 = -d / 2, d / 2
    a.bx((-w / 2, y0, 0.0), (w / 2, y1, 0.08), "wood_dark")
    a.bx((-w / 2, y0, 0.08), (-w / 2 + 0.03, y1, h), "walnut")
    a.bx((w / 2 - 0.03, y0, 0.08), (w / 2, y1, h), "walnut")
    a.bx((-w / 2 + 0.03, y0, 0.08), (w / 2 - 0.03, y0 + 0.012, h - 0.04), "walnut")
    a.bx((-w / 2 - 0.01, y0, h - 0.04), (w / 2 + 0.01, y1 + 0.01, h), "walnut")
    cols, rows = 8, 12
    z0, z1 = 0.08, h - 0.04
    cw = (w - 0.06) / cols
    rh = (z1 - z0) / rows
    for c in range(1, cols):
        x = -w / 2 + 0.03 + c * cw
        a.bx((x - 0.006, y0 + 0.012, z0), (x + 0.006, y1 - 0.01, z1), "walnut")
    for r in range(1, rows):
        z = z0 + r * rh
        a.bx((-w / 2 + 0.03, y0 + 0.012, z - 0.006), (w / 2 - 0.03, y1 - 0.01, z + 0.006), "walnut")
    rng = k.ctx.rng
    for r in range(rows):
        for c in range(cols):
            if rng.random() < 0.14:
                continue
            x = -w / 2 + 0.03 + (c + 0.5) * cw
            z = z0 + r * rh + (0.006 if r else 0.0) + 0.037
            key = "leaf_dark" if rng.random() < 0.6 else "plastic_black"
            bt.cyl(0.037, 0.24, (x, y0 + 0.17, z), key, axis="Y", segs=8)
            bt.cyl(0.014, 0.08, (x, y0 + 0.33, z), key, axis="Y", segs=6)
            bt.cyl(0.016, 0.03, (x, y0 + 0.385, z), "car_wine" if (r + c) % 3 else "brass", axis="Y", segs=6)
    o.build()
    k.collision([((-w / 2 - 0.01, y0, 0.0), (w / 2 + 0.01, y1 + 0.01, h))])


def _lamp_bedside(k: Kit, p: dict) -> None:
    """Bedside lamp: round brass base, slim stem, charcoal drum shade with a glowing diffuser."""
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.075, 0.0), (0.075, 0.015), (0.03, 0.03), (0.0, 0.03)], "brass", segs=20)
    a.rod((0.0, 0.0, 0.03), (0.0, 0.0, 0.36), 0.008, "brass", segs=8)
    a.lathe([(0.13, 0.28), (0.13, 0.46), (0.0, 0.46)], "fabric_charcoal", segs=24)
    # glowing diffuser under the shade
    a.lathe([(0.11, 0.274), (0.11, 0.28), (0.0, 0.28)], "emit_warm", segs=20)
    o.build()


def _rug_dining(k: Kit, p: dict) -> None:
    """Dining-room rug 4.0 x 3.0 m: burgundy field, ivory border line (fits a 2.4 m table + chairs)."""
    w, d = 4.0, 3.0
    o = k.obj("Rug")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.01), "rug_burgundy")
    b = o.part(bevel=0.0)
    m, t = 0.18, 0.05
    for (x0, y0, x1, y1) in ((-w / 2 + m, -d / 2 + m, w / 2 - m, -d / 2 + m + t), (-w / 2 + m, d / 2 - m - t, w / 2 - m, d / 2 - m),
                             (-w / 2 + m, -d / 2 + m, -w / 2 + m + t, d / 2 - m), (w / 2 - m - t, -d / 2 + m, w / 2 - m, d / 2 - m)):
        b.bx((x0, y0, 0.01), (x1, y1, 0.0112), "rug_ivory")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.01))])


def _tv_wall(k: Kit, p: dict) -> None:
    """Wall-mounted presentation display (1.65 x 0.95 m), back at y = 0, centred on the origin;
    dim screen."""
    w, h = 1.65, 0.95
    o = k.obj("Display")
    a = o.part(bevel=0.003)
    a.bx((-0.2, 0.0, -0.15), (0.2, 0.02, 0.15), "metal_dark")
    a.bx((-w / 2, 0.02, -h / 2), (w / 2, 0.055, h / 2), "plastic_black")
    s = o.part(bevel=0.0)
    s.bx((-w / 2 + 0.015, 0.055, -h / 2 + 0.015), (w / 2 - 0.015, 0.0565, h / 2 - 0.015), "emit_screen")
    o.build()


# ---------------------------------------------------------------------------------- offices

def _table_racetrack(k: Kit, p: dict) -> None:
    """Conference table: racetrack walnut top at 0.74 m with a flush leather centre inlay and
    brushed-steel panel legs joined by a beam."""
    w, d, h = p["w"], p["d"], 0.74
    r = d / 2
    n = 10
    o = k.obj("Table")
    top = o.part(bevel=0.0)
    base = o.part(bevel=0.004, segments=1)
    trim = o.part(bevel=0.0)

    def stadium(hw: float, rr: float) -> list[tuple[float, float]]:
        pts = []
        for i in range(n + 1):
            a = -math.pi / 2 + math.pi * i / n
            pts.append((hw - rr + rr * math.cos(a), rr * math.sin(a)))
        for i in range(n + 1):
            a = math.pi / 2 + math.pi * i / n
            pts.append((-hw + rr + rr * math.cos(a), rr * math.sin(a)))
        return pts

    # walnut ring round a flush leather centre (one plane at 0.74 m, no overlaps)
    inner = stadium(w / 2 - 0.35, r - 0.3)
    top.prism(stadium(w / 2, r), holes=[inner], axis="Z", start=h - 0.05, end=h, mat=top.m("walnut"))
    trim.slab(inner, h - 0.05, h, "leather")
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.6)
        base.bx((x - 0.025, -d / 2 + 0.2, 0.0), (x + 0.025, d / 2 - 0.2, h - 0.05), "steel")
        base.bx((x - 0.05, -d / 2 + 0.18, 0.0), (x + 0.05, d / 2 - 0.18, 0.02), "steel")
    base.bx((-w / 2 + 0.6, -0.04, h - 0.13), (w / 2 - 0.6, 0.04, h - 0.05), "steel")
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h))] +
                [((sx * (w / 2 - 0.6) - 0.05, -d / 2 + 0.18, 0.0), (sx * (w / 2 - 0.6) + 0.05, d / 2 - 0.18, h - 0.05)) for sx in (-1, 1)])


def _reception_desk(k: Kit, p: dict) -> None:
    """Reception desk 3.0 x 0.8 m, visitor side +Y (front): walnut front with brass fins on a dark
    stone plinth, marble transaction ledge at 1.05 m along the front; staff work surface at 0.74 m
    on the -Y side with drawer pedestals (catalog keepout = the work surface, so `on` items stay
    on the ledge)."""
    w, d = 3.0, 0.8
    hl, hw = 1.05, 0.74
    y0, y1 = -d / 2, d / 2
    o = k.obj("Desk")
    hard = o.part(bevel=0.004, segments=2)
    top = o.part(bevel=0.006, segments=2)
    trim = o.part(bevel=0.0015)
    # front upstand (visitor side) and its plinth
    yu0, yu1 = 0.12, y1 - 0.04
    hard.bx((-w / 2, yu0, 0.1), (w / 2, yu1, hl - 0.03), "walnut")
    hard.bx((-w / 2 + 0.02, yu0 + 0.02, 0.0), (w / 2 - 0.02, yu1 - 0.04, 0.1), "stone_dark")
    nf = 9
    for i in range(nf):
        x = -w / 2 + 0.15 + i * (w - 0.3) / (nf - 1)
        trim.bx((x - 0.012, yu1, 0.14), (x + 0.012, yu1 + 0.015, hl - 0.1), "brass")
    trim.bx((-w / 2, yu1, 0.1), (w / 2, yu1 + 0.018, 0.125), "brass")
    top.bx((-w / 2 - 0.02, yu0 - 0.02, hl - 0.03), (w / 2 + 0.02, y1, hl), "marble")
    # staff work surface + pedestals
    hard.bx((-w / 2, y0, hw - 0.035), (w / 2, yu0, hw), "walnut")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.02), sx * (w / 2 - 0.47)))
        hard.bx((x0, y0 + 0.04, 0.0), (x1, yu0, hw - 0.035), "walnut")
        for i in range(3):
            z0 = 0.05 + i * 0.21
            hard.bx((x0 + 0.015, y0 + 0.025, z0), (x1 - 0.015, y0 + 0.04, z0 + 0.19), "walnut")
            trim.bx(((x0 + x1) / 2 - 0.06, y0 + 0.012, z0 + 0.15), ((x0 + x1) / 2 + 0.06, y0 + 0.025, z0 + 0.162), "brass")
    trim.bx((-w / 2 - 0.003, y0 - 0.003, hw - 0.022), (w / 2 + 0.003, yu0, hw - 0.016), "brass")
    o.build()
    k.collision([((-w / 2 - 0.02, yu0 - 0.02, 0.0), (w / 2 + 0.02, y1, hl)), ((-w / 2, y0, hw - 0.035), (w / 2, yu0, hw)),
                 ((-w / 2 + 0.02, y0 + 0.025, 0.0), (-w / 2 + 0.47, yu0, hw - 0.035)),
                 ((w / 2 - 0.47, y0 + 0.025, 0.0), (w / 2 - 0.02, yu0, hw - 0.035))])


def _laptop(k: Kit, p: dict) -> None:
    """Open laptop (0.33 x 0.23 m): charcoal base with keyboard and trackpad, lid at ~105 degrees
    with a dim screen facing the user (+Y)."""
    w, d = 0.33, 0.23
    o = k.obj("Laptop")
    a = o.part(bevel=0.003)
    s = o.part(bevel=0.0)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.016), "powder_charcoal")
    s.bx((-w / 2 + 0.02, -d / 2 + 0.025, 0.016), (w / 2 - 0.02, -d / 2 + 0.125, 0.0175), "plastic_black")
    s.bx((-0.05, d / 2 - 0.085, 0.016), (0.05, d / 2 - 0.02, 0.0172), "plastic_grey")
    # lid hinged at the back edge, tilted back 15 degrees from vertical
    ang = math.radians(15.0)
    lh = 0.22
    bx_, bz = -d / 2, 0.016
    tx, tz = bx_ - math.sin(ang) * lh, bz + math.cos(ang) * lh
    nx, nz = math.cos(ang) * 0.006, math.sin(ang) * 0.006
    a.profile_x([(bx_, bz), (bx_ - 0.006 * math.cos(ang), bz - 0.006 * math.sin(ang) + 0.003),
                 (tx - nx, tz - nz), (tx, tz)], -w / 2, w / 2, "powder_charcoal")
    # screen: 4 mm proud of the lid's front face (along its normal), inset 12 mm from the edges
    f = 0.012
    ny, nz2 = math.cos(ang), math.sin(ang)

    def lid_pt(t: float, off: float) -> tuple[float, float]:
        return (bx_ - math.sin(ang) * t + ny * off, bz + math.cos(ang) * t + nz2 * off)

    s.profile_x([lid_pt(f, 0.0005), lid_pt(lh - f, 0.0005), lid_pt(lh - f, 0.004), lid_pt(f, 0.004)],
                -w / 2 + f, w / 2 - f, "emit_screen")
    o.build()


# ---------------------------------------------------------------------------------- galleries

def _plinth(k: Kit, p: dict) -> None:
    """Gallery plinth 0.5 x 0.5 x 1.1 m: ivory-painted box on a recessed dark shadow-gap base."""
    s, h = 0.5, 1.1
    o = k.obj("Plinth")
    a = o.part(bevel=0.003, segments=1)
    a.bx((-s / 2 + 0.02, -s / 2 + 0.02, 0.0), (s / 2 - 0.02, s / 2 - 0.02, 0.04), "powder_charcoal")
    a.bx((-s / 2, -s / 2, 0.04), (s / 2, s / 2, h), "paint_ivory")
    o.build()
    k.collision([((-s / 2, -s / 2, 0.0), (s / 2, s / 2, h))])


# ---------------------------------------------------------------------------------- terrace

def _lounger(k: Kit, p: dict) -> None:
    """Teak sun lounger 0.7 x 1.9 m: slatted frame on four legs, back raised at the head end (-Y),
    ivory cushion."""
    w, ln, hs = 0.7, 1.9, 0.34
    y0, y1 = -ln / 2, ln / 2
    o = k.obj("Lounger")
    a = o.part(bevel=0.004, segments=1)
    c = o.part(bevel=0.02, segments=2)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.04)))
        a.bx((x0, y0 + 0.55, hs - 0.06), (x1, y1, hs), "wood_oak")
        for y in (y0 + 0.62, y1 - 0.08):
            a.bx((x0, y - 0.03, 0.0), (x1, y + 0.03, hs - 0.06), "wood_oak")
    for i in range(10):
        y = y0 + 0.6 + i * (y1 - y0 - 0.64) / 9
        a.bx((-w / 2 + 0.04, y - 0.035, hs - 0.04), (w / 2 - 0.04, y + 0.035, hs - 0.015), "wood_oak")
    c.bx((-w / 2 + 0.05, y0 + 0.58, hs - 0.015), (w / 2 - 0.05, y1 - 0.02, hs + 0.05), "canvas_ivory")
    # raised back rest (45 degrees)
    ang = math.radians(45.0)
    bl = 0.62
    py, pz = y0 + 0.58, hs
    ey, ez = py - math.cos(ang) * bl, pz + math.sin(ang) * bl
    a.profile_x([(py, pz - 0.03), (py + 0.02, pz), (ey + 0.02, ez + 0.01), (ey, ez - 0.02)], -w / 2 + 0.04, w / 2 - 0.04, "wood_oak")
    c.profile_x([(py + 0.02, pz + 0.005), (py + 0.05, pz + 0.045), (ey + 0.06, ez + 0.05), (ey + 0.025, ez + 0.012)],
                -w / 2 + 0.05, w / 2 - 0.05, "canvas_ivory")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.04)))
        a.bx((x0, ey + 0.06, 0.0), (x1, ey + 0.12, ez - 0.09), "wood_oak")
    o.build()
    k.collision([((-w / 2, y0 + 0.55, 0.0), (w / 2, y1, hs + 0.05)), ((-w / 2, ey, 0.0), (w / 2, py, ez))])


def _patio_heater(k: Kit, p: dict) -> None:
    """Mushroom patio heater (2.2 m): weighted base, steel pole, burner with a glowing emitter
    grille and the reflector hood. The catalog light sits under the hood."""
    o = k.obj("Heater")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.26, 0.0), (0.26, 0.03), (0.2, 0.12), (0.08, 0.16), (0.0, 0.16)], "powder_charcoal", segs=24)
    a.rod((0.0, 0.0, 0.15), (0.0, 0.0, 1.72), 0.035, "steel", segs=12)
    a.lathe([(0.0, 1.62), (0.07, 1.62), (0.09, 1.7), (0.09, 1.76), (0.0, 1.76)], "steel", segs=16)
    e = o.part(bevel=0.0)
    e.lathe([(0.09, 1.76), (0.11, 1.8), (0.11, 2.02), (0.06, 2.06), (0.0, 2.06)], "emit_warm", segs=16)
    for i in range(6):
        ang = 2 * math.pi * i / 6
        a.rod((math.cos(ang) * 0.115, math.sin(ang) * 0.115, 1.78), (math.cos(ang) * 0.115, math.sin(ang) * 0.115, 2.04), 0.006,
              "steel", segs=5)
    a.lathe([(0.0, 2.08), (0.08, 2.08), (0.42, 2.14), (0.43, 2.16), (0.08, 2.2), (0.0, 2.2)], "steel", segs=28)
    a.lathe([(0.0, 2.2), (0.03, 2.2), (0.0, 2.24)], "steel", segs=10)
    o.build()
    k.collision([], cylinders=[(0.26, 0.16, (0.0, 0.0, 0.08)), (0.05, 2.0, (0.0, 0.0, 1.16))])


def _planter_terrace(k: Kit, p: dict) -> None:
    """Terrace planter 2.4 x 0.8 x 0.9 m: dark stone trough, soil, low clipped shrubs."""
    w, d, h = 2.4, 0.8, 0.9
    o = k.obj("Planter")
    a = o.part(bevel=0.008, segments=2)
    zi = h - 0.1                  # top of the solid body; the rim walls stand on it
    t = 0.06
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, zi), "stone_dark")
    for sy in (-1, 1):
        y0, y1 = sorted((sy * d / 2, sy * (d / 2 - t)))
        a.bx((-w / 2, y0, zi), (w / 2, y1, h), "stone_dark")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - t)))
        a.bx((x0, -d / 2 + t, zi), (x1, d / 2 - t, h), "stone_dark")
    s = o.part(bevel=0.0)
    s.bx((-w / 2 + t, -d / 2 + t, zi), (w / 2 - t, d / 2 - t, zi + 0.03), "soil")
    rng = k.ctx.rng
    for i in range(16):
        x = -w / 2 + 0.25 + i * (w - 0.5) / 15 + rng.uniform(-0.04, 0.04)
        y = rng.uniform(-0.12, 0.12)
        r = rng.uniform(0.16, 0.22)
        s.sphere(r, (x, y, zi + 0.03 + r * 0.6), "leaf" if i % 3 else "leaf_dark", segs=8, rings=5, scale=(1.0, 1.0, 0.8))
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
