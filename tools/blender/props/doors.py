"""GSR door visuals for the `door` prefab (visual_slots.md): `Frame` (jamb lining + architraves on
both wall faces; `Frame/Collision` trimesh), `Leaf` (hinge pivot, closed = rotation 0, extends +X),
`Leaf2` (double: extends -X), `Handle`/`Handle2` markers on the lever axis.

Openings match the greybox wall kit (tools/blender/greybox/_kit.py DOORS): single leaf 0.9 in a
1.0 opening, double 2 x 0.9 in 2.0, service 1.1 in 1.2; leaf 2.1 high, opening 2.2. Origin =
bottom-centre of the opening on the wall centreline. Wall thickness t20 / t40.

Finishes: walnut (raised panels + brass inlay, brass lever: sales/salon/manager), painted ivory
(shaker panels, satin lever: offices, WC), steel (flush painted steel, kick plate, push bar on
single/service: back of house, fire exit), glass (double only: brass-framed glass leaves, the
shop entry).
"""

import math

from _pb import Kit, panel_door
from lib import geo

TRI_BUDGET = 8000
_KINDS = {"single": (0.9, 0.05, 1), "double": (0.9, 0.1, 2), "service": (1.1, 0.05, 1)}
VARIANTS = {
    **{
        f"prop_door_{kind}_{fin}_t{t}": {
            "kind": kind, "finish": fin, "wall_t": t / 100,
            "cat": {"prefab": "door", "kind": "door", "service": kind == "service"},
        }
        for kind in ("single", "double", "service")
        for fin in ("walnut", "ivory", "steel", "glass")
        for t in (20, 40)
        if fin != "glass" or kind == "double"
    },
    # Night Deposit: the basement vault gate (steel grille, double, t20) and the bronze street doors (double, t40).
    "prop_door_double_grille_t20": {"kind": "double", "finish": "grille", "wall_t": 0.2,
                                    "cat": {"prefab": "door", "kind": "door", "service": False}},
    "prop_door_double_bronze_t40": {"kind": "double", "finish": "bronze", "wall_t": 0.4,
                                    "cat": {"prefab": "door", "kind": "door", "service": False}},
    # PO-7: steel gates in 0.1 m fences / cages (a t20 frame's architraves stood 5 cm off the fence).
    "prop_door_double_steel_t10": {"kind": "double", "finish": "steel", "wall_t": 0.1,
                                   "cat": {"prefab": "door", "kind": "door", "service": False}},
    "prop_door_single_steel_t10": {"kind": "single", "finish": "steel", "wall_t": 0.1,
                                   "cat": {"prefab": "door", "kind": "door", "service": False}},
    # Gallery Night (GN-C2): the art-lift landing gates (steel frame, diagonal lattice, kick plate; double, t20)
    "prop_door_double_liftgate_t20": {"kind": "double", "finish": "liftgate", "wall_t": 0.2,
                                      "cat": {"prefab": "door", "kind": "door", "service": False, "surface": "metal"}},
    # the ATM vestibule's interior glass door to the banking hall (casing view, doc §Sightlines)
    "prop_door_single_glass_t20": {"kind": "single", "finish": "glass", "wall_t": 0.2,
                                   "cat": {"prefab": "door", "kind": "door", "service": False}},
}

LEAF_H = 2.1
OPEN_H = 2.2
ARCH_W = 0.07     # architrave width
ARCH_T = 0.018    # architrave projection
JAMB_ROUND = 0.04  # PO-7 frame_proud: radius of the rounded room-side edges of the jamb colliders


def _frame(k: Kit, hw: float, jamb: float, wall_t: float, finish: str):
    """Jamb lining (in the opening) and architraves on both wall faces; trimesh collision.

    The lining fills the whole jamb allowance, so the leaf closes 3 mm off it (PO-7: a 0.03 m
    lining in the 0.05 / 0.10 m jamb left 2.3 / 7.3 cm slits beside the leaves).

    Collision (PO-7 frame_proud): only the jamb linings and the head, exactly flush with the wall
    faces (+-wall_t / 2), the jambs' room-side edges rounded (JAMB_ROUND quarter arcs) so a crew
    capsule cutting the corner slides round the jamb. The architraves and plinth blocks stand
    proud of the wall as visual trim only: their old box colliders stood 1.8 cm off both wall
    faces with sharp corners 7 cm beside the reveal (a bag-carrying capsule stalled on them at
    Glasshouse LobbyDoor), and the wall behind them already blocks."""
    fr = k.obj("Frame")
    key = {"walnut": "walnut", "ivory": "paint_ivory", "steel": "metal_dark", "glass": "brass", "grille": "metal_dark",
           "bronze": "brass", "liftgate": "metal_dark"}[finish]
    lin = fr.part(bevel=0.003)
    arch = fr.part(bevel=0.004, segments=2)
    lining = jamb
    d = wall_t / 2 + 0.002
    lin.bx((-hw, -d, 0.0), (-hw + lining, d, OPEN_H), key)
    lin.bx((hw - lining, -d, 0.0), (hw, d, OPEN_H), key)
    head = LEAF_H + 0.004
    lin.bx((-hw, -d, head), (hw, d, OPEN_H), key)
    # door stop (thin strip the leaf closes against)
    lin.bx((-hw + lining, 0.024, 0.0), (-hw + lining + 0.012, 0.035, head), key)
    lin.bx((hw - lining - 0.012, 0.024, 0.0), (hw - lining, 0.035, head), key)
    lin.bx((-hw + lining, 0.024, head - 0.012), (hw - lining, 0.035, head), key)
    for side in (-1, 1):
        y0, y1 = sorted((side * wall_t / 2, side * (wall_t / 2 + ARCH_T)))
        arch.bx((-hw - ARCH_W, y0, 0.0), (-hw, y1, OPEN_H + ARCH_W), key)
        arch.bx((hw, y0, 0.0), (hw + ARCH_W, y1, OPEN_H + ARCH_W), key)
        arch.bx((-hw - ARCH_W, y0, OPEN_H), (hw + ARCH_W, y1, OPEN_H + ARCH_W), key)
        # plinth blocks at the foot of the architrave
        y2, y3 = sorted((side * wall_t / 2, side * (wall_t / 2 + ARCH_T + 0.006)))
        arch.bx((-hw - ARCH_W - 0.004, y2, 0.0), (-hw + 0.004, y3, 0.16), key)
        arch.bx((hw - 0.004, y2, 0.0), (hw + ARCH_W + 0.004, y3, 0.16), key)
    obj = fr.build()
    _frame_collision(obj, hw, lining, wall_t, head)
    return obj


def _jamb_profile(hw: float, lining: float, wall_t: float, side: float) -> list[tuple[float, float]]:
    """Plan profile (x, y) of one jamb collider: the lining across the full wall thickness, outer
    face on the reveal (|x| = hw), inner face at |x| = hw - lining, both room-side edges of the
    inner face rounded with radius JAMB_ROUND (4 segments). side -1 = -X jamb, +1 = +X jamb."""
    h = wall_t / 2
    r = min(JAMB_ROUND, lining - 0.005, h - 0.01)
    xi = hw - lining  # |x| of the inner face
    pts: list[tuple[float, float]] = [(hw, -h)]
    for i in range(5):  # -Y edge: from the wall face (|x| = xi + r) round to the inner face
        a = math.pi / 2 * i / 4
        pts.append((xi + r - r * math.sin(a), -h + r - r * math.cos(a)))
    for i in range(5):  # +Y edge: from the inner face round to the wall face
        a = math.pi / 2 * i / 4
        pts.append((xi + r - r * math.cos(a), h - r + r * math.sin(a)))
    pts.append((hw, h))
    out = [(side * x, y) for x, y in pts]
    return out if side > 0 else list(reversed(out))


def _frame_collision(parent, hw: float, lining: float, wall_t: float, head: float) -> None:
    """Flush trimesh collision of the frame: two rounded jambs + the head (see _frame)."""
    mb = geo.MeshBuilder()
    for side in (-1.0, 1.0):
        mb.prism(_jamb_profile(hw, lining, wall_t, side), axis="Z", start=0.0, end=OPEN_H)
    mb.box((-hw + lining, -wall_t / 2, head), (hw - lining, wall_t / 2, OPEN_H))
    geo.collision_from_builder(mb, "trimesh", parent=parent)


def _lever(p, x: float, sign: float, t: float, key: str) -> None:
    """Lever handle + rose on both faces at x (leaf-local), lever pointing toward the hinge."""
    for side in (1, -1):
        yf = side * t / 2
        y0, y1 = sorted((yf, yf + side * 0.008))
        p.cyl(0.026, abs(y1 - y0), (x, (y0 + y1) / 2, 1.0), key, axis="Y", segs=20)
        p.rod((x, yf, 1.0), (x, yf + side * 0.055, 1.0), 0.009, key, segs=10)
        p.rod((x, yf + side * 0.055, 1.0), (x - sign * 0.13, yf + side * 0.062, 1.0), 0.008, key, segs=10)
        p.sphere(0.0095, (x, yf + side * 0.055, 1.0), key, segs=10, rings=5)
        # escutcheon (key cylinder) below the lever
        p.cyl(0.014, abs(y1 - y0), (x, (y0 + y1) / 2, 0.88), key, axis="Y", segs=14)


def _leaf(k: Kit, name: str, hinge_x: float, sign: float, leaf_w: float, finish: str, kind: str):
    pivot = k.empty(name, (hinge_x, 0.0, 0.0))
    suffix = name[4:]
    lo, hi = (0.003, leaf_w - 0.003) if sign > 0 else (-(leaf_w - 0.003), -0.003)
    t = 0.045 if finish == "steel" else 0.042
    lf = k.obj("LeafMesh" + suffix, parent=pivot)
    body = lf.part(bevel=0.003, segments=1)
    trim = lf.part(bevel=0.0015)
    hw_key = {"walnut": "brass", "ivory": "steel", "steel": "steel", "glass": "brass", "grille": "steel", "bronze": "brass",
              "liftgate": "steel"}[finish]
    if finish == "grille":
        # vault gate: flat-bar frame, vertical round bars, two rails and a lock box at the meeting stile
        stile = 0.06
        body.bx((lo, -0.02, 0.008), (hi, 0.02, 0.008 + stile), "metal_dark")
        body.bx((lo, -0.02, LEAF_H - stile - 0.003), (hi, 0.02, LEAF_H - 0.003), "metal_dark")
        body.bx((lo, -0.02, 0.008), (lo + stile, 0.02, LEAF_H - 0.003), "metal_dark")
        body.bx((hi - stile, -0.02, 0.008), (hi, 0.02, LEAF_H - 0.003), "metal_dark")
        for z in (0.75, 1.45):
            body.bx((lo + stile, -0.012, z), (hi - stile, 0.012, z + 0.04), "metal_dark")
        g = lf.part(bevel=0.0)
        n = 7
        for i in range(n):
            x = lo + stile + (hi - lo - 2 * stile) * (i + 0.5) / n
            g.rod((x, 0.0, 0.008 + stile), (x, 0.0, LEAF_H - stile - 0.003), 0.011, "steel", segs=8)
        hx = hi - 0.03 if sign > 0 else lo + 0.03
        trim.bx((hx - 0.03 - 0.06 * (sign > 0), -0.05, 0.9), (hx + 0.03 + 0.06 * (sign < 0), 0.05, 1.12), "metal_dark")
        for z in (0.25, 1.05, 1.85):
            trim.cyl(0.012, 0.12, (lo - 0.004 if sign > 0 else hi + 0.004, 0.0, z), hw_key, segs=10)
        lf.build()
        k.empty("Handle" + suffix, (hx, 0.0, 1.0), parent=pivot)
        return
    if finish == "liftgate":
        # art-lift landing gate: steel tube frame, a diagonal lattice of flats, a kick plate, a vision band
        stile = 0.05
        body.bx((lo, -0.022, 0.008), (hi, 0.022, 0.3), "steel")
        body.bx((lo, -0.022, LEAF_H - stile - 0.003), (hi, 0.022, LEAF_H - 0.003), "metal_dark")
        body.bx((lo, -0.022, 0.008), (lo + stile, 0.022, LEAF_H - 0.003), "metal_dark")
        body.bx((hi - stile, -0.022, 0.008), (hi, 0.022, LEAF_H - 0.003), "metal_dark")
        body.bx((lo + stile, -0.018, 1.0), (hi - stile, 0.018, 1.06), "metal_dark")
        g = lf.part(bevel=0.0)
        x0, x1 = lo + stile, hi - stile
        for zb, zt in ((0.3, 1.0), (1.06, LEAF_H - stile - 0.003)):
            n = 4
            for i in range(n):
                xa = x0 + (x1 - x0) * i / n
                xb = x0 + (x1 - x0) * (i + 1) / n
                g.rod((xa, -0.006, zb), (xb, -0.006, zt), 0.005, "steel", segs=4, square=True)
                g.rod((xb, 0.006, zb), (xa, 0.006, zt), 0.005, "steel", segs=4, square=True)
        hx = hi - 0.07 if sign > 0 else lo + 0.07
        for side in (1, -1):
            yf = side * 0.022
            trim.rod((hx, yf + side * 0.045, 0.85), (hx, yf + side * 0.045, 1.25), 0.012, "steel", segs=10)
            trim.rod((hx, yf, 0.9), (hx, yf + side * 0.045, 0.9), 0.008, "steel", segs=8)
            trim.rod((hx, yf, 1.2), (hx, yf + side * 0.045, 1.2), 0.008, "steel", segs=8)
        hx_h = lo - 0.002 if sign > 0 else hi + 0.002
        for z in (0.25, 1.05, 1.85):
            trim.cyl(0.01, 0.1, (hx_h, -0.026, z), "steel", segs=10)
        lf.build()
        k.empty("Handle" + suffix, (hx, 0.0, 1.0), parent=pivot)
        return
    if finish == "bronze":
        # bronze street doors: cast panels in a heavy frame, push plates and pull bars both faces
        body.bx((lo, -t / 2, 0.008), (hi, t / 2, LEAF_H - 0.003), "brass")
        for side in (1, -1):
            for z0, z1 in ((0.15, 0.95), (1.08, LEAF_H - 0.15)):
                y0, y1 = sorted((side * t / 2, side * (t / 2 + 0.012)))
                body.bx((lo + 0.1, y0, z0), (hi - 0.1, y1, z1), "brass")
                y2, y3 = sorted((side * (t / 2 + 0.012), side * (t / 2 + 0.02)))
                body.bx((lo + 0.16, y2, z0 + 0.06), (hi - 0.16, y3, z1 - 0.06), "metal_dark")
            hx2 = hi - 0.07 if sign > 0 else lo + 0.07
            trim.rod((hx2, side * (t / 2 + 0.06), 0.8), (hx2, side * (t / 2 + 0.06), 1.3), 0.015, "brass", segs=12)
            trim.rod((hx2, side * t / 2, 0.85), (hx2, side * (t / 2 + 0.06), 0.85), 0.01, "brass", segs=10)
            trim.rod((hx2, side * t / 2, 1.25), (hx2, side * (t / 2 + 0.06), 1.25), 0.01, "brass", segs=10)
        hx_h2 = lo - 0.002 if sign > 0 else hi + 0.002
        for z in (0.25, 1.05, 1.85):
            trim.cyl(0.01, 0.12, (hx_h2, -t / 2 - 0.004, z), "brass", segs=10)
        lf.build()
        hx = hi - 0.07 if sign > 0 else lo + 0.07
        k.empty("Handle" + suffix, (hx, 0.0, 1.0), parent=pivot)
        return
    if finish == "glass":
        stile = 0.09
        body.bx((lo, -t / 2, 0.006), (hi, t / 2, 0.006 + 0.22), "brass")
        body.bx((lo, -t / 2, LEAF_H - 0.12), (hi, t / 2, LEAF_H - 0.003), "brass")
        body.bx((lo, -t / 2, 0.006), (lo + stile, t / 2, LEAF_H - 0.003), "brass")
        body.bx((hi - stile, -t / 2, 0.006), (hi, t / 2, LEAF_H - 0.003), "brass")
        g = lf.part(bevel=0.0)
        g.bx((lo + stile - 0.01, -0.005, 0.2), (hi - stile + 0.01, 0.005, LEAF_H - 0.11), "glass")
        # tall pull handles on both faces near the meeting stile
        hx = hi - 0.05 if sign > 0 else lo + 0.05
        for side in (1, -1):
            yf = side * t / 2
            trim.rod((hx, yf + side * 0.05, 0.75), (hx, yf + side * 0.05, 1.45), 0.014, "brass", segs=12)
            trim.rod((hx, yf, 0.8), (hx, yf + side * 0.05, 0.8), 0.009, "brass", segs=10)
            trim.rod((hx, yf, 1.4), (hx, yf + side * 0.05, 1.4), 0.009, "brass", segs=10)
        lf.build()
        k.empty("Handle" + suffix, (hx, 0.0, 1.0), parent=pivot)
        return
    key = {"walnut": "walnut", "ivory": "paint_ivory", "steel": "metal_grey"}[finish]
    body.bx((lo, -t / 2, 0.008), (hi, t / 2, LEAF_H - 0.003), key)
    if finish == "walnut" or finish == "ivory":
        inlay = "brass" if finish == "walnut" else None
        rails = ((0.12, 0.9), (1.02, LEAF_H - 0.12))
        for side in (1, -1):
            for z0, z1 in rails:
                if side > 0:
                    panel_door(body, lo + 0.11, hi - 0.11, z0, z1, t / 2 - 0.006, key, inlay, frame_w=0.05, depth=0.008)
                else:
                    body.bx((lo + 0.11, -t / 2 - 0.002, z0), (hi - 0.11, -t / 2 + 0.006, z1), key)
                    body.bx((lo + 0.16, -t / 2 - 0.012, z0 + 0.05), (hi - 0.16, -t / 2 - 0.002, z1 - 0.05), key)
    else:
        # steel: kick plates both faces, push bar on the push side (+Y = the side it swings toward)
        for side in (1, -1):
            y0, y1 = sorted((side * t / 2, side * (t / 2 + 0.0015)))
            trim.bx((lo + 0.02, y0, 0.02), (hi - 0.02, y1, 0.27), "steel")
        if kind in ("single", "service"):
            yb = t / 2 + 0.07
            x0, x1 = (lo + 0.12, hi - 0.06) if sign > 0 else (lo + 0.06, hi - 0.12)
            trim.cbox(((x0 + x1) / 2, t / 2 + 0.035, 1.0), (x1 - x0, 0.07, 0.07), "metal_dark")
            trim.rod((x0, yb, 1.0), (x1, yb, 1.0), 0.016, "steel", segs=12)
    # hinges on the hinge edge
    hx_h = lo - 0.002 if sign > 0 else hi + 0.002
    for z in (0.25, 1.05, 1.85):
        trim.cyl(0.008, 0.1, (hx_h, -t / 2 - 0.004, z), hw_key, segs=10)
    hx = (hi - 0.07) if sign > 0 else (lo + 0.07)
    _lever(trim, hx, sign, t, hw_key)
    lf.build()
    k.empty("Handle" + suffix, (hx, 0.0, 1.0), parent=pivot)


def build(ctx) -> None:
    k = Kit(ctx)
    p = ctx.params
    leaf_w, jamb, leaves = _KINDS[p["kind"]]
    hw = leaf_w * leaves / 2 + jamb
    _frame(k, hw, jamb, p["wall_t"], p["finish"])
    for i in range(leaves):
        sign = 1.0 if i == 0 else -1.0
        _leaf(k, "Leaf" if i == 0 else "Leaf2", -sign * (hw - jamb), sign, leaf_w, p["finish"], p["kind"])
