"""Display case visuals for the `display_case` prefab (visual_slots.md: Body, Glass, LootAnchor).

The reference-bar look (docs/art/style_samples/a_gsr/counter.png): walnut casework with raised
panels and thin brass inlay, a recessed dark plinth with a brass kick plate, a brass-banded slab, a
rose felt deck, and a glass box framed in brass square tube. `Display` holds the jewelry dressing
(stays when the glass breaks). Floor pivot (bottom-centre), front = Godot -Z. No collision: the
prefab owns it (visual_slots.md).
"""

import math

import _jewelry as J
from _pb import Kit, knob, panel_door

TRI_BUDGET = 20000
VARIANTS = {
    "prop_display_case_island": {"kind": "island", "w": 1.2, "d": 0.6, "cat": {"prefab": "display_case", "kind": "display_case"}},
    "prop_display_case_island_long": {"kind": "island", "w": 1.8, "d": 0.7, "cat": {"prefab": "display_case", "kind": "display_case"}},
    "prop_display_case_wall": {"kind": "wall", "w": 1.2, "d": 0.5, "cat": {"prefab": "display_case", "kind": "display_case"}},
    "prop_display_case_round": {"kind": "round", "w": 2.4, "d": 2.4, "cat": {"prefab": "display_case", "kind": "display_case"}},
    "prop_display_case_vitrine": {"kind": "vitrine", "w": 0.6, "d": 0.6, "cat": {"prefab": "display_case", "kind": "display_case"}},
}

PLINTH = 0.08
TUBE = 0.016       # brass square tube of the glass frame
PANE = 0.006


def _cabinet(k: Kit, body, w: float, d: float, top: float, panels_back: bool, seed: int) -> None:
    """Walnut carcass from 0 to ``top`` with plinth, slab, brass bands and raised panels."""
    hard = body.part(bevel=0.004, segments=2)
    trim = body.part(bevel=0.0015)
    hard.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.0), (w / 2 - 0.03, d / 2 - 0.03, PLINTH), "wood_dark")
    trim.bx((-w / 2 + 0.029, -d / 2 + 0.029, 0.0), (w / 2 - 0.029, d / 2 - 0.029, 0.012), "brass")
    hard.bx((-w / 2, -d / 2, PLINTH), (w / 2, d / 2, top - 0.035), "walnut")
    hard.bx((-w / 2 - 0.02, -d / 2 - 0.02, top - 0.035), (w / 2 + 0.02, d / 2 + 0.02, top), "wood_dark")
    trim.bx((-w / 2 - 0.022, -d / 2 - 0.022, top - 0.023), (w / 2 + 0.022, d / 2 + 0.022, top - 0.013), "brass")
    trim.bx((-w / 2 - 0.004, -d / 2 - 0.004, PLINTH), (w / 2 + 0.004, d / 2 + 0.004, PLINTH + 0.01), "brass")
    n = max(1, round(w / 0.42))
    pw = (w - 0.08) / n
    z0, z1 = PLINTH + 0.05, top - 0.085
    for side in ((1, 0), (-1, 0)) if panels_back else ((1, 0),):
        s = side[0]
        for i in range(n):
            x0 = -w / 2 + 0.04 + i * pw + 0.012
            x1 = x0 + pw - 0.024
            if s > 0:
                panel_door(hard, x0, x1, z0, z1, d / 2, "walnut", "brass")
                if n % 2 == 1 and i == n // 2:
                    knob(trim, (x0 + x1) / 2, d / 2 + 0.026, (z0 + z1) / 2 + 0.14)
            else:
                # mirrored panel on the back face (front plane y = -d/2, facing -Y)
                hard.bx((x0, -d / 2 - 0.018, z0), (x1, -d / 2, z1), "walnut")
                hard.bx((x0 + 0.05, -d / 2 - 0.026, z0 + 0.05), (x1 - 0.05, -d / 2 - 0.018, z1 - 0.05), "walnut")
                g = 0.0275
                for (a0, a1, b0, b1) in ((x0 + g, x1 - g, z0 + g, z0 + g + 0.004), (x0 + g, x1 - g, z1 - g - 0.004, z1 - g),
                                         (x0 + g, x0 + g + 0.004, z0 + g, z1 - g), (x1 - g - 0.004, x1 - g, z0 + g, z1 - g)):
                    trim.bx((a0, -d / 2 - 0.02, b0), (a1, -d / 2 - 0.018, b1), "brass")
    # side panels
    for sx in (-1, 1):
        y0, y1 = -d / 2 + 0.06, d / 2 - 0.06
        xs = sx * w / 2
        lo, hi = sorted((xs, xs + sx * 0.018))
        hard.bx((lo, y0, z0), (hi, y1, z1), "walnut")
        lo2, hi2 = sorted((xs + sx * 0.018, xs + sx * 0.026))
        hard.bx((lo2, y0 + 0.05, z0 + 0.05), (hi2, y1 - 0.05, z1 - 0.05), "walnut")


def _glass_box(k: Kit, body, glass, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
               front_only: bool = False) -> None:
    """Brass square-tube frame + glass panes (Glass object) on the box."""
    t = TUBE
    tube = body.part(bevel=0.0015)
    for (ax0, ay0, ax1, ay1) in ((x0, y0, x1, y0 + t), (x0, y1 - t, x1, y1), (x0, y0, x0 + t, y1), (x1 - t, y0, x1, y1)):
        tube.bx((ax0, ay0, z0), (ax1, ay1, z0 + t), "brass")
        tube.bx((ax0, ay0, z1 - t), (ax1, ay1, z1), "brass")
    for (cx, cy) in ((x0, y0), (x1 - t, y0), (x0, y1 - t), (x1 - t, y1 - t)):
        tube.bx((cx, cy, z0), (cx + t, cy + t, z1), "brass")
    g = glass.part(bevel=0.0)
    e = t * 0.5
    g.bx((x0 + e, y1 - t / 2 - PANE / 2, z0 + t), (x1 - e, y1 - t / 2 + PANE / 2, z1 - t), "glass")
    if not front_only:
        g.bx((x0 + e, y0 + t / 2 - PANE / 2, z0 + t), (x1 - e, y0 + t / 2 + PANE / 2, z1 - t), "glass")
    for xx in (x0 + t / 2, x1 - t / 2):
        g.bx((xx - PANE / 2, y0 + e, z0 + t), (xx + PANE / 2, y1 - e, z1 - t), "glass")
    g.bx((x0 + e, y0 + e, z1 - t / 2 - PANE / 2), (x1 - e, y1 - e, z1 - t / 2 + PANE / 2), "glass")


def _island(k: Kit, w: float, d: float, seed: int) -> list:
    body = k.obj("Body")
    glass = k.obj("Glass")
    disp = k.obj("Display")
    top = 0.735
    _cabinet(k, body, w, d, top, True, seed)
    felt = body.part(bevel=0.002)
    felt.bx((-w / 2 + 0.012, -d / 2 + 0.012, top), (w / 2 - 0.012, d / 2 - 0.012, top + 0.018), "felt_rose")
    deck = top + 0.018
    _glass_box(k, body, glass, -w / 2, w / 2, -d / 2, d / 2, top, 1.05)
    jp = disp.part(bevel=0.0)
    js = disp.part(bevel=0.003, segments=2)
    J.display_set(jp, js, -w / 2 + 0.08, w / 2 - 0.08, 0.0, deck, seed, depth=d - 0.08)
    body.build()
    glass.build()
    disp.build()
    anchors = [(x, 0.0, deck) for x in (-w * 0.3, 0.0, w * 0.3)]
    return anchors


def _wall(k: Kit, w: float, d: float, seed: int) -> list:
    body = k.obj("Body")
    glass = k.obj("Glass")
    disp = k.obj("Display")
    top = 0.9
    # back of the case is y = -d/2 (against the wall), front +Y
    _cabinet(k, body, w, d, top, False, seed)
    hard = body.part(bevel=0.004, segments=2)
    felt = body.part(bevel=0.002)
    trim = body.part(bevel=0.0015)
    z_top = 2.05
    felt.bx((-w / 2 + 0.012, -d / 2 + 0.012, top), (w / 2 - 0.012, d / 2 - 0.012, top + 0.018), "felt_rose")
    felt.bx((-w / 2 + 0.02, -d / 2 + 0.012, top + 0.018), (w / 2 - 0.02, -d / 2 + 0.03, z_top - 0.02), "felt_rose")
    # cornice with a warm LED strip under it
    hard.bx((-w / 2 - 0.02, -d / 2, z_top), (w / 2 + 0.02, d / 2 + 0.03, z_top + 0.14), "walnut")
    hard.bx((-w / 2 - 0.035, -d / 2, z_top + 0.14), (w / 2 + 0.035, d / 2 + 0.045, z_top + 0.17), "wood_dark")
    trim.bx((-w / 2 - 0.022, d / 2 + 0.03, z_top + 0.05), (w / 2 + 0.022, d / 2 + 0.034, z_top + 0.058), "brass")
    trim.bx((-w / 2 + 0.03, d / 2 - 0.06, z_top - 0.006), (w / 2 - 0.03, d / 2 - 0.035, z_top), "emit_warm")
    _glass_box(k, body, glass, -w / 2, w / 2, -d / 2 + 0.03, d / 2, top + 0.018, z_top, front_only=False)
    # two glass shelves on brass pins
    gp = glass.part(bevel=0.0)
    shelves = (top + 0.4, top + 0.78)
    for z in shelves:
        gp.bx((-w / 2 + 0.03, -d / 2 + 0.035, z), (w / 2 - 0.03, d / 2 - 0.04, z + 0.008), "glass")
        for sx in (-1, 1):
            trim.cyl(0.004, 0.02, (sx * (w / 2 - 0.035), -d / 2 + 0.05, z - 0.004), "brass", segs=8)
    jp = disp.part(bevel=0.0)
    js = disp.part(bevel=0.003, segments=2)
    deck = top + 0.018
    J.display_set(jp, js, -w / 2 + 0.08, w / 2 - 0.08, 0.02, deck, seed, depth=d - 0.1)
    for i, z in enumerate(shelves):
        J.display_set(jp, js, -w / 2 + 0.1, w / 2 - 0.1, 0.0, z + 0.008, seed + i + 1, depth=0.2)
    body.build()
    glass.build()
    disp.build()
    return [(-w * 0.25, 0.02, deck), (w * 0.25, 0.02, deck), (0.0, 0.0, shelves[0] + 0.008)]


def _round(k: Kit, w: float, seed: int) -> list:
    body = k.obj("Body")
    glass = k.obj("Glass")
    disp = k.obj("Display")
    r = w / 2
    seg = 48
    hard = body.part(bevel=0.0)
    trim = body.part(bevel=0.0)
    top = 0.75
    hard.lathe([(r - 0.06, 0.0), (r - 0.06, PLINTH)], "wood_dark", segs=seg)
    trim.lathe([(r - 0.055, 0.0), (r - 0.055, 0.012)], "brass", segs=seg)
    hard.lathe([(r - 0.02, PLINTH), (r, PLINTH + 0.015), (r, top - 0.04), (r + 0.02, top - 0.03), (r + 0.02, top)],
               "walnut", segs=seg)
    trim.torus(r + 0.021, 0.006, (0, 0, top - 0.018), "brass", segs=seg, rsegs=6)
    trim.torus(r + 0.002, 0.005, (0, 0, PLINTH + 0.02), "brass", segs=seg, rsegs=6)
    # vertical brass fluting on the drum
    for i in range(24):
        a = 2 * math.pi * (i + 0.5) / 24
        trim.rod((math.cos(a) * (r + 0.002), math.sin(a) * (r + 0.002), PLINTH + 0.05),
                 (math.cos(a) * (r + 0.002), math.sin(a) * (r + 0.002), top - 0.06), 0.003, "brass", segs=6)
    felt = body.part(bevel=0.0)
    felt.lathe([(r - 0.012, top), (r - 0.012, top + 0.018), (0.0, top + 0.018)], "felt_rose", segs=seg)
    deck = top + 0.018
    # centre riser (stepped walnut drum) for the hero pieces
    felt.lathe([(0.35, deck), (0.35, deck + 0.12), (0.0, deck + 0.12)], "felt_rose", segs=32)
    trim.torus(0.352, 0.004, (0, 0, deck + 0.12), "brass", segs=32, rsegs=4)
    # glass drum: 24 flat panes between brass mullions, brass rings, glass lid
    z0, z1 = top, top + 0.45
    trim.torus(r - 0.006, 0.008, (0, 0, z0 + 0.008), "brass", segs=seg, rsegs=6)
    trim.torus(r - 0.006, 0.008, (0, 0, z1 - 0.008), "brass", segs=seg, rsegs=6)
    gp = glass.part(bevel=0.0)
    n = 24
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        trim.rod((math.cos(a0) * (r - 0.006), math.sin(a0) * (r - 0.006), z0),
                 (math.cos(a0) * (r - 0.006), math.sin(a0) * (r - 0.006), z1), 0.005, "brass", segs=6)
        pts = [(math.cos(a) * (r - 0.006), math.sin(a) * (r - 0.006)) for a in (a0, a1)]
        (xa, ya), (xb, yb) = pts
        nx, ny = math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2)
        ht = PANE / 2
        quad = [(xa - nx * ht, ya - ny * ht), (xb - nx * ht, yb - ny * ht), (xb + nx * ht, yb + ny * ht),
                (xa + nx * ht, ya + ny * ht)]
        gp.slab(quad, z0 + 0.016, z1 - 0.016, "glass")
    gp.lathe([(r - 0.01, z1 - 0.004), (r - 0.01, z1 + 0.004), (0.0, z1 + 0.004)], "glass", segs=seg)
    jp = disp.part(bevel=0.0)
    js = disp.part(bevel=0.003, segments=2)
    J.bust(jp, js, 0.0, 0.0, deck + 0.12, height=0.3, pearls=False)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        cx, cy = math.cos(a) * 0.78, math.sin(a) * 0.78
        if i % 2 == 0:
            J.bust(jp, js, cx, cy, deck, pearls=i % 4 == 0)
        else:
            J.ring_tray(jp, js, cx, cy, deck, w=0.22, d=0.11, rot=abs(math.cos(a)) > 0.7)
    body.build()
    glass.build()
    disp.build()
    return [(0.78, 0.0, deck), (-0.78, 0.0, deck), (0.0, 0.0, deck + 0.12)]


def _vitrine(k: Kit, w: float, d: float, seed: int) -> list:
    body = k.obj("Body")
    glass = k.obj("Glass")
    disp = k.obj("Display")
    top = 0.55
    _cabinet(k, body, w, d, top, True, seed)
    hard = body.part(bevel=0.004, segments=2)
    trim = body.part(bevel=0.0015)
    felt = body.part(bevel=0.002)
    felt.bx((-w / 2 + 0.012, -d / 2 + 0.012, top), (w / 2 - 0.012, d / 2 - 0.012, top + 0.018), "felt_rose")
    z1 = 1.75
    _glass_box(k, body, glass, -w / 2, w / 2, -d / 2, d / 2, top, z1)
    hard.bx((-w / 2 - 0.015, -d / 2 - 0.015, z1), (w / 2 + 0.015, d / 2 + 0.015, z1 + 0.06), "walnut")
    trim.bx((-w / 2 - 0.017, -d / 2 - 0.017, z1 + 0.02), (w / 2 + 0.017, d / 2 + 0.017, z1 + 0.028), "brass")
    trim.bx((-w / 2 + 0.05, -d / 2 + 0.05, z1 - 0.006), (w / 2 - 0.05, d / 2 - 0.05, z1), "emit_warm")
    gp = glass.part(bevel=0.0)
    shelves = (top + 0.42, top + 0.82)
    for z in shelves:
        gp.bx((-w / 2 + 0.02, -d / 2 + 0.02, z), (w / 2 - 0.02, d / 2 - 0.02, z + 0.008), "glass")
    jp = disp.part(bevel=0.0)
    js = disp.part(bevel=0.003, segments=2)
    deck = top + 0.018
    J.bust(jp, js, 0.0, 0.0, deck, pearls=True)
    J.ring_tray(jp, js, 0.0, 0.0, shelves[0] + 0.008, w=0.24, d=0.12)
    for j in (-1, 1):
        J.watch_pillow(jp, js, j * 0.1, 0.0, shelves[1] + 0.008, "brass" if j > 0 else "chrome")
    body.build()
    glass.build()
    disp.build()
    return [(0.0, 0.0, deck), (0.0, 0.0, shelves[0] + 0.008), (0.0, 0.0, shelves[1] + 0.008)]


def build(ctx) -> None:
    k = Kit(ctx)
    p = ctx.params
    w, d = p["w"], p["d"]
    kind = p["kind"]
    if kind == "island":
        anchors = _island(k, w, d, ctx.seed)
    elif kind == "wall":
        anchors = _wall(k, w, d, ctx.seed)
    elif kind == "round":
        anchors = _round(k, w, ctx.seed)
    else:
        anchors = _vitrine(k, w, d, ctx.seed)
    for i, a in enumerate(anchors):
        k.empty("LootAnchor" if i == 0 else f"LootAnchor{i + 1}", a)
