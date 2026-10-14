"""Harbor dressing for Night Deposit: quay mooring bollards, the Co-op launch (escape E2), the moored
trawler (P3 sniper perch) and shipping containers for the crane yard. D-111: `prop_burn_barrel`, the Dockside
Burn thermite burn point visual (`burn_point` prefab: a rusted open drum with a `Fire` node that BurnPoint shows
while burning / lit: static emissive flame tongues over an ember bed and glowing draught holes; no particles).

The two boats and the containers are site dressing instanced under the map's Geometry over their
collision blocks (night_deposit_layout.gd BLOCKS). Floor-item pivots (props contract): boats = the keel
bottom under the deck centre (the hull is built deck-relative and lifted by its draught), containers =
the bottom centre. Front +Y (Godot -Z); long axis X.
"""

import math

from _pb import Kit

TRI_BUDGET = 20000
VARIANTS = {
    "prop_mooring_bollard": {"fn": "mooring_bollard", "cat": {"kind": "bollard", "place": "row", "standoff": 0.4, "group": "exterior",
                                                             "pin_only": True}},
    "veh_boat_launch": {"fn": "launch", "cat": {"kind": "boat", "group": "exterior"}},
    "veh_trawler": {"fn": "trawler", "cat": {"kind": "boat", "group": "exterior"}},
    "prop_burn_barrel": {"fn": "burn_barrel", "cat": {"prefab": "burn_point", "kind": "burn_barrel", "surface": "metal"}},
    **{
        f"prop_container_{n}_{c}": {"fn": "container", "len": 12.19 if n == 40 else 6.06, "paint": f"container_{c}",
                                    "cat": {"kind": "container", "group": "exterior"}}
        for n in (20, 40) for c in ("rust", "blue", "green")
    },
}


def _mooring_bollard(k: Kit, p: dict) -> None:
    o = k.obj("Bollard")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.24, 0.0), (0.24, 0.05), (0.17, 0.08), (0.14, 0.3), (0.13, 0.42), (0.19, 0.46), (0.2, 0.52),
             (0.15, 0.56), (0.0, 0.57)], "metal_dark", segs=20)
    a.bx((-0.2, -0.2, 0.0), (0.2, 0.2, 0.02), "metal_dark")
    o.build()
    k.collision([], cylinders=[(0.2, 0.57, (0.0, 0.0, 0.285))])


def _hull_outline(half_len: float, beam: float, bow: float, inset: float = 0.0) -> list[tuple[float, float]]:
    """Plan outline (x, y): square-ish stern at -x, a curved bow reaching +half_len."""
    b = beam / 2 - inset
    pts = [(-half_len + inset, -b * 0.92), (half_len - bow, -b)]
    n = 8
    for i in range(1, n):
        t = i / n
        x = half_len - bow + bow * math.sin(t * math.pi / 2) - inset * t
        y = -b * math.cos(t * math.pi / 2)
        pts.append((x, y))
    pts.append((half_len - inset, 0.0))
    for i in range(n - 1, 0, -1):
        t = i / n
        x = half_len - bow + bow * math.sin(t * math.pi / 2) - inset * t
        y = b * math.cos(t * math.pi / 2)
        pts.append((x, y))
    pts += [(half_len - bow, b), (-half_len + inset, b * 0.92)]
    return pts


def _launch(k: Kit, p: dict) -> None:
    """Co-op fishing launch: navy topsides, red bottom, teak deck at z = 0 (the walkable collision
    block's top), low gunwale open on the quay side (boarding), forward cabin over the cabin block.
    Built deck-relative (deck z 0, keel z -1.0) and lifted 1.0 m so the pivot is the keel bottom."""
    L, B = 9.0, 3.0
    o = k.obj("Hull", location=(0.0, 0.0, 1.0))
    hull = o.part(bevel=0.0)
    hull.slab(_hull_outline(L / 2, B, 2.2), -0.62, -0.02, "hull_navy")
    hull.slab(_hull_outline(L / 2, B, 2.2, inset=0.18), -1.0, -0.62, "metal_red")
    hull.slab(_hull_outline(L / 2, B, 2.2, inset=0.02), -0.02, 0.0, "wood_pine")
    trim = o.part(bevel=0.0)
    trim.slab(_hull_outline(L / 2, B, 2.2, inset=-0.004), -0.5, -0.44, "hull_white")
    # gunwale cap: south side (-Y in Godot = +Y here is the quay side, left open between x -2.5 and 1.0)
    for x0, x1, y in ((-L / 2 + 0.1, 2.3, -B / 2 + 0.06), (-L / 2 + 0.1, -2.6, B / 2 - 0.06), (1.1, 2.3, B / 2 - 0.06)):
        trim.bx((x0, y - 0.05, 0.0), (x1, y + 0.05, 0.12), "hull_white")
    trim.bx((-L / 2 + 0.1, -B / 2 + 0.06, 0.0), (-L / 2 + 0.2, B / 2 - 0.06, 0.12), "hull_white")
    for x in (-3.8, -1.2, 1.6):
        trim.cyl(0.07, 0.18, (x, -B / 2 + 0.25, 0.09), "metal_dark", segs=10)
    # cabin (local x 1.5..4.1, y -1.1..0.7) with windows, roof and a mast
    c = o.part(bevel=0.02, segments=2)
    c.bx((1.5, -1.1, 0.0), (3.6, 0.7, 1.9), "hull_white")
    c.profile_y([(3.6, 0.0), (4.1, 0.0), (3.8, 1.5), (3.6, 1.9)], -1.1, 0.7, "hull_white")
    c.bx((1.4, -1.2, 1.9), (3.9, 0.8, 2.0), "hull_navy")
    g = o.part(bevel=0.0)
    for y in (-1.104, 0.704):
        y0, y1 = sorted((y, y + (0.003 if y > 0 else -0.003)))
        for x0 in (1.7, 2.6):
            g.bx((x0, y0, 1.15), (x0 + 0.7, y1, 1.65), "glass_tinted")
    g.profile_y([(3.62, 1.2), (3.8, 1.2), (3.73, 1.55), (3.6, 1.62)], -0.9, 0.5, "glass_tinted")
    m = o.part(bevel=0.0)
    m.rod((2.4, -0.2, 2.0), (2.4, -0.2, 3.4), 0.04, "metal_white", segs=8)
    m.rod((2.0, -0.2, 3.0), (2.8, -0.2, 3.0), 0.025, "metal_white", segs=8)
    m.sphere(0.06, (2.4, -0.2, 3.45), "emit_cool", segs=10, rings=5)
    m.torus(0.28, 0.06, (1.45, -0.4, 1.0), "metal_red", segs=20, rsegs=6, axis="X")
    # nets and fish boxes on the aft deck
    s = o.part(bevel=0.02, segments=2)
    s.bx((-3.6, -1.0, 0.0), (-2.8, -0.4, 0.35), "plastic_white")
    s.bx((-3.6, -0.3, 0.0), (-2.8, 0.3, 0.35), "plastic_grey")
    s.bx((-1.2, -1.2, 0.0), (0.2, -0.5, 0.25), "canvas_teal")
    o.build()


def _trawler(k: Kit, p: dict) -> None:
    """Moored trawler: white topsides, red bottom, deck at z = 0, wheelhouse over the wheelhouse block
    with a flat roof at 3.4 m (the P3 sniper perch), stern gantry with a net drum. Built deck-relative
    (keel z -1.8) and lifted 1.8 m so the pivot is the keel bottom."""
    L, B = 10.0, 4.0
    o = k.obj("Hull", location=(0.0, 0.0, 1.8))
    hull = o.part(bevel=0.0)
    hull.slab(_hull_outline(L / 2, B, 2.6), -0.95, 0.25, "hull_white")
    hull.slab(_hull_outline(L / 2, B, 2.6, inset=0.25), -1.8, -0.95, "metal_red")
    deck = o.part(bevel=0.0)
    deck.slab(_hull_outline(L / 2, B, 2.6, inset=0.12), 0.0, 0.004, "wood_pine")
    stripe = o.part(bevel=0.0)
    stripe.slab(_hull_outline(L / 2, B, 2.6, inset=-0.004), -0.3, -0.18, "hull_navy")
    # bulwark inner faces: a navy band 0.25 above the deck
    stripe.slab(_hull_outline(L / 2, B, 2.6, inset=0.1), 0.0, 0.22, "hull_navy")
    # wheelhouse (x -2..2, y -1.2..1.2), roof flat at 3.4
    w = o.part(bevel=0.02, segments=2)
    w.bx((-2.0, -1.2, 0.0), (2.0, 1.2, 3.3), "hull_white")
    w.bx((-2.08, -1.28, 3.3), (2.08, 1.28, 3.4), "hull_navy")
    g = o.part(bevel=0.0)
    for x0 in (-1.6, -0.5, 0.6):
        for y in (-1.204, 1.204):
            y0, y1 = sorted((y, y + (0.003 if y > 0 else -0.003)))
            g.bx((x0, y0, 2.2), (x0 + 0.9, y1, 2.9), "glass_tinted")
    g.bx((2.0, -0.9, 2.2), (2.004, 0.9, 2.95), "glass_tinted")
    g.bx((-2.004, -0.5, 0.2), (-2.0, 0.5, 2.0), "metal_dark")
    # stern gantry (A-frame) with a net drum, a mast with lights on the wheelhouse roof
    m = o.part(bevel=0.0)
    for y in (-1.5, 1.5):
        m.rod((-4.6, y, 0.25), (-4.1, y * 0.4, 4.2), 0.08, "metal_yellow", segs=10)
    m.rod((-4.1, -0.6, 4.2), (-4.1, 0.6, 4.2), 0.08, "metal_yellow", segs=10)
    m.cyl(0.45, 2.2, (-3.4, 0.0, 0.75), "metal_dark", axis="Y", segs=20)
    m.cyl(0.38, 2.0, (-3.4, 0.0, 0.75), "canvas_teal", axis="Y", segs=20)
    m.rod((0.8, 0.0, 3.4), (0.8, 0.0, 5.6), 0.05, "metal_white", segs=8)
    m.rod((0.3, 0.0, 5.0), (1.3, 0.0, 5.0), 0.03, "metal_white", segs=8)
    m.sphere(0.07, (0.8, 0.0, 5.65), "emit_cool", segs=10, rings=5)
    s = o.part(bevel=0.02, segments=2)
    for i in range(3):
        s.bx((2.6 + i * 0.7, -1.4, 0.0), (3.2 + i * 0.7, -0.9, 0.3 + 0.3 * (i % 2)), ("plastic_white", "metal_orange", "plastic_grey")[i])
    o.build()


def _container(k: Kit, p: dict) -> None:
    """ISO shipping container (20 ft / 40 ft): corrugated side and roof panels between corner posts,
    corner castings, cargo doors with locking bars on the +X end."""
    ln = p["len"]
    w, h = 2.44, 2.59
    key = p["paint"]
    o = k.obj("Container")
    a = o.part(bevel=0.0)
    a.bx((-ln / 2 + 0.02, -w / 2 + 0.02, 0.0), (ln / 2 - 0.02, w / 2 - 0.02, h), key)
    fr = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = sorted((sx * ln / 2, sx * (ln / 2 - 0.16)))
            y0, y1 = sorted((sy * w / 2, sy * (w / 2 - 0.16)))
            fr.bx((x0, y0, 0.0), (x1, y1, h), key)
            for z0, z1 in ((0.0, 0.12), (h - 0.12, h)):
                fr.bx((x0 - 0.004 * sx, y0 - 0.004 * sy, z0), (x1, y1, z1), "metal_dark")
    for z0, z1 in ((0.0, 0.15), (h - 0.1, h)):
        for sy in (-1, 1):
            y0, y1 = sorted((sy * w / 2, sy * (w / 2 - 0.06)))
            fr.bx((-ln / 2 + 0.16, y0, z0), (ln / 2 - 0.16, y1, z1), key)
    rib = o.part(bevel=0.0)
    pitch = 0.28
    n = int((ln - 0.4) / pitch)
    for i in range(n):
        x = -ln / 2 + 0.2 + pitch * (i + 0.5)
        for sy in (-1, 1):
            y0, y1 = sorted((sy * (w / 2 - 0.02), sy * (w / 2 + 0.008)))
            rib.bx((x - 0.06, y0, 0.15), (x + 0.06, y1, h - 0.1), key)
        rib.bx((x - 0.06, -w / 2 + 0.1, h - 0.02), (x + 0.06, w / 2 - 0.1, h + 0.012), key)
    # cargo doors on +X: door seam, four locking bars with handles
    d = o.part(bevel=0.0)
    d.bx((ln / 2 - 0.02, -0.01, 0.15), (ln / 2 + 0.006, 0.01, h - 0.12), "metal_dark")
    for y in (-0.85, -0.35, 0.35, 0.85):
        d.rod((ln / 2 + 0.03, y, 0.18), (ln / 2 + 0.03, y, h - 0.15), 0.018, "metal_grey", segs=8)
        d.bx((ln / 2 + 0.006, y - 0.12, 1.15), (ln / 2 + 0.05, y + 0.02, 1.2), "metal_grey")
    o.build()


def _burn_barrel(k: Kit, p: dict) -> None:
    """Burn barrel: a rusted 205 l drum (0.58 m, 0.88 m tall) with its lid cut out, rolling hoops, a ring of
    draught holes punched near the bottom, charred cardboard goods sticking out of the top, on three bricks.
    `Fire` (shown by BurnPoint while burning): an ember bed at the rim, flame tongues rising 0.6 m above it
    and glowing plugs in the draught holes."""
    r, h, lift = 0.29, 0.88, 0.06
    top = lift + h
    o = k.obj("Body")
    drum = o.part(bevel=0.0)
    n = 32
    # open drum: outer wall, inner wall (dark), bottom, a rolled rim
    ring = [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    hole = [(x * (r - 0.006) / r, y * (r - 0.006) / r) for x, y in ring]
    drum.prism(ring, holes=[hole], axis="Z", start=lift, end=top, mat=drum.m("metal_rust"), cap_mat=drum.m("metal_dark"))
    inner = o.part(bevel=0.0)
    inner.cyl(r - 0.006, 0.01, (0.0, 0.0, lift + 0.005), "metal_dark", segs=n)
    drum.torus(r, 0.008, (0.0, 0.0, top), "metal_rust", segs=n, rsegs=5)
    drum.torus(r, 0.007, (0.0, 0.0, lift + 0.004), "metal_rust", segs=n, rsegs=4)
    for z in (lift + h * 0.33, lift + h * 0.66):
        drum.torus(r + 0.004, 0.011, (0.0, 0.0, z), "metal_rust", segs=n, rsegs=5)
    # draught-hole rims (dark collars; the glowing plugs are in Fire)
    holes = []
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        c, s_ = math.cos(a), math.sin(a)
        holes.append((c, s_))
        drum.rod((c * (r - 0.004), s_ * (r - 0.004), lift + 0.12), (c * (r + 0.006), s_ * (r + 0.006), lift + 0.12), 0.03,
                 "metal_dark", segs=10)
    # bricks under it
    b = o.part(bevel=0.006)
    for i in range(3):
        a = 2 * math.pi * i / 3 + math.pi / 2
        cx, cy = math.cos(a) * 0.17, math.sin(a) * 0.17
        b.cbox((cx, cy, lift / 2), (0.21, 0.1, lift), "brick")
    # charred cardboard goods poking out of the top
    g = o.part(bevel=0.004)
    g.bx((-0.16, -0.12, top - 0.18), (0.06, 0.08, top + 0.04), "cardboard")
    g.bx((0.02, -0.05, top - 0.2), (0.2, 0.15, top - 0.03), "metal_dark")
    o.build()
    fire = k.obj("Fire")
    f = fire.part(bevel=0.0)
    f.cyl(r - 0.012, 0.03, (0.0, 0.0, top - 0.05), "emit_ember", segs=n)
    rng = k.ctx.rng
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.2, 0.2)
        d = 0.06 + 0.12 * (i % 3) / 2
        cx, cy = math.cos(a) * d, math.sin(a) * d
        hgt = 0.28 + rng.uniform(0.0, 0.32)
        rad = 0.07 + rng.uniform(0.0, 0.04)
        prof = [(rad, 0.0), (rad * 0.9, hgt * 0.25), (rad * 0.55, hgt * 0.6), (rad * 0.2, hgt * 0.88), (0.0, hgt)]
        f.lathe(prof, "emit_fire" if i % 3 else "emit_amber", centre=(cx, cy, top - 0.04), segs=7)
    for c, s_ in holes:
        f.rod((c * (r - 0.002), s_ * (r - 0.002), lift + 0.12), (c * (r + 0.009), s_ * (r + 0.009), lift + 0.12), 0.022,
              "emit_ember", segs=10)
    fire.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
