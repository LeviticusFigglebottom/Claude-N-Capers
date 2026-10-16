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

Dockside Burn industrial doors (D-111, `fn`): the frame boxes, leaf planes and leaf widths of the G1 greybox visuals
they replace (`Frame/Collision` = the same jamb + head boxes as a trimesh), so door logic, sizes and collision stay:

* `prop_door_roller_twin_w360_h400` (t40): two 1.8 m roller curtains on a removable centre post line, steel guides
  in the jambs, the coil box in the head. Each `Leaf` / `Leaf2` carries `world/props/shutter_leaf.gd` (wrapper
  `leaf_script` + `leaf2`): the curtain rolls up when the DOUBLE leaf opens.
* `prop_door_slide_coldstore_w240_h360` (t20): insulated cold-store leaves (white skin, steel edge channel,
  rubber seals, pull bar), `world/props/slide_leaf.gd`: opening slides each leaf into the wall pocket.
* `prop_door_vault_strongroom_w200_h220` (t40): a 0.12 m steel strongroom door, locking wheel, dial, hinge
  barrels, bolt heads; the frame a heavy steel lining.
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
    # D-111: Shadow Ledger / Dockside Burn doors in the 0.3 m core walls (stairs, WCs, plant, riser) and the SL police /
    # cage gates in the 0.06 m mesh screens (a t40 / t20 frame's architraves stood 5-9 cm off those faces).
    **{
        f"prop_door_{kind}_{fin}_t30": {"kind": kind, "finish": fin, "wall_t": 0.3,
                                        "cat": {"prefab": "door", "kind": "door", "service": kind == "service"}}
        for kind, fin in (("single", "steel"), ("single", "ivory"), ("service", "steel"))
    },
    "prop_door_single_steel_t06": {"kind": "single", "finish": "steel", "wall_t": 0.06,
                                   "cat": {"prefab": "door", "kind": "door", "service": False}},
    # D-111: Shadow Ledger curtain-wall doors (gondola access doors, terrace sliders): a slim frame in the 0.04 m glazing
    **{
        f"prop_door_single_{fin}_t04": {"kind": "single", "finish": fin, "wall_t": 0.04,
                                        "cat": {"prefab": "door", "kind": "door", "service": False}}
        for fin in ("steel", "glass")
    },
    # Gallery Night (GN-C2): the art-lift landing gates (steel frame, diagonal lattice, kick plate; double, t20)
    "prop_door_double_liftgate_t20": {"kind": "double", "finish": "liftgate", "wall_t": 0.2,
                                      "cat": {"prefab": "door", "kind": "door", "service": False, "surface": "metal"}},
    # the ATM vestibule's interior glass door to the banking hall (casing view, doc §Sightlines)
    "prop_door_single_glass_t20": {"kind": "single", "finish": "glass", "wall_t": 0.2,
                                   "cat": {"prefab": "door", "kind": "door", "service": False}},
    # D-111 Dockside Burn industrial doors (module docstring)
    "prop_door_roller_twin_w360_h400": {"fn": "roller_twin", "w": 3.6, "h": 4.0, "jamb": 0.1, "wall_t": 0.4,
                                        "cat": {"prefab": "door", "kind": "industrial_door", "surface": "metal",
                                                "leaf_script": "shutter", "leaf2": True}},
    "prop_door_slide_coldstore_w240_h360": {"fn": "slide", "w": 2.4, "h": 3.6, "jamb": 0.1, "wall_t": 0.2,
                                            "frame_t": 0.3,
                                            "cat": {"prefab": "door", "kind": "industrial_door", "surface": "metal",
                                                    "leaf_script": "slide", "leaf2": True}},
    "prop_door_vault_strongroom_w200_h220": {"fn": "vault", "w": 2.0, "h": 2.2, "jamb": 0.1, "wall_t": 0.4,
                                             "cat": {"prefab": "door", "kind": "vault_door", "surface": "metal"}},
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


# ------------------------------------------------------------------------- Dockside Burn industrial

def _box_frame(k: Kit, hw: float, jamb: float, h: float, wall_t: float, key: str, frame_t: float = 0.0):
    """Jambs (x hw - jamb .. hw) and head (z h .. h + jamb) across the wall; trimesh collision = the same boxes over
    `wall_t` (the G1 greybox visual's collision). `frame_t` > wall_t: the visual lining stands proud by half the
    difference on each face (the greybox mesh depth). Returns (Frame object, its main Part, its trim Part)."""
    fr = k.obj("Frame")
    body = fr.part(bevel=0.004)
    trim = fr.part(bevel=0.0015)
    d = max(wall_t, frame_t) / 2
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw + jamb)))
        body.bx((x0, -d, 0.0), (x1, d, h + jamb), key)
    body.bx((-hw - jamb, -d, h), (hw + jamb, d, h + jamb), key)
    return fr, body, trim


def _box_frame_collision(obj, hw: float, jamb: float, h: float, wall_t: float) -> None:
    mb = geo.MeshBuilder()
    t = wall_t / 2
    mb.box((-hw - jamb, -t, 0.0), (-hw, t, h + jamb))
    mb.box((hw, -t, 0.0), (hw + jamb, t, h + jamb))
    mb.box((-hw, -t, h), (hw, t, h + jamb))
    geo.collision_from_builder(mb, "trimesh", parent=obj)


def _roller_curtain(k: Kit, leaf, suffix: str, x0: float, x1: float, top: float) -> None:
    """Slatted curtain under `leaf` from leaf-local x0..x1: `Curtain<suffix>` (origin at the top, slats hanging to
    the bar), `BottomBar<suffix>` (origin on the floor line) and `BarFittings<suffix>` (pull handles both faces)."""
    bar_h = 0.07
    depth = 0.012
    cur = k.obj("Curtain" + suffix, parent=leaf, location=(0.0, 0.0, top))
    sp = cur.part(bevel=0.0)
    rib = cur.part(bevel=0.0)
    span = top - bar_h
    n = max(1, int(math.ceil(span / 0.09)))
    step = span / n
    for i in range(n):
        z1 = -i * step
        z0 = z1 - step - 0.004
        sp.bx((x0, -depth / 2, z0), (x1, depth / 2, z1), "steel_galv")
        zm = (z0 + z1) / 2
        rib.bx((x0, depth / 2, zm - 0.01), (x1, depth / 2 + 0.008, zm + 0.01), "steel_galv")
        rib.bx((x0, -depth / 2 - 0.008, zm - 0.01), (x1, -depth / 2, zm + 0.01), "steel_galv")
    cur.build()
    bar = k.obj("BottomBar" + suffix, parent=leaf)
    bp = bar.part(bevel=0.004)
    bp.bx((x0, -0.025, 0.012), (x1, 0.025, bar_h + 0.004), "metal_dark")
    bp.bx((x0, -0.026, bar_h - 0.02), (x1, 0.026, bar_h), "paint_hazard_orange")
    bar.part(bevel=0.0).bx((x0, -0.016, 0.004), (x1, 0.016, 0.012), "rubber")
    bar.build()
    fit = k.obj("BarFittings" + suffix, parent=leaf)
    hp = fit.part(bevel=0.0)
    xm = (x0 + x1) / 2
    for sy in (-1, 1):
        hp.rod((xm - 0.12, sy * 0.06, 0.05), (xm + 0.12, sy * 0.06, 0.05), 0.011, "steel", segs=8)
        y0, y1 = sorted((sy * 0.026, sy * 0.06))
        hp.bx((xm - 0.13, y0, 0.04), (xm - 0.11, y1, 0.06), "steel")
        hp.bx((xm + 0.11, y0, 0.04), (xm + 0.13, y1, 0.06), "steel")
    fit.build()


def _roller_twin(k: Kit, p: dict) -> None:
    w, h, jamb, t = p["w"], p["h"], p["jamb"], p["wall_t"]
    hw = w / 2
    fr, body, trim = _box_frame(k, hw, jamb, h, t, "metal_dark")
    # guide channel lips (the curtains run in the slot), the coil box cover plates with bolt heads, a hazard band
    for sx in (-1, 1):
        xi = sx * hw
        xa, xb = sorted((xi, xi - sx * 0.006))
        for sy in (-1, 1):
            y0, y1 = sorted((sy * 0.014, sy * t / 2))
            trim.bx((xa, y0, 0.0), (xb, y1, h), "steel")
        for z in (0.4, 1.6, 2.8):
            x0, x1 = sorted((sx * (hw + 0.02), sx * (hw + 0.08)))
            for sy in (-1, 1):
                y0, y1 = sorted((sy * t / 2, sy * (t / 2 + 0.004)))
                trim.bx((x0, y0, z), (x1, y1, z + 0.12), "paint_hazard_orange")
    for sy in (-1, 1):
        y0, y1 = sorted((sy * t / 2, sy * (t / 2 + 0.004)))
        trim.bx((-hw - jamb + 0.03, y0, h + 0.015), (hw + jamb - 0.03, y1, h + jamb - 0.015), "steel_galv")
        for x in (-hw + 0.2, -hw / 2, 0.0, hw / 2, hw - 0.2):
            trim.cyl(0.011, 0.008, (x, sy * (t / 2 + 0.006), h + jamb / 2), "steel", axis="Y", segs=8)
    obj = fr.build()
    _box_frame_collision(obj, hw, jamb, h, t)
    for name, sx in (("Leaf", -1.0), ("Leaf2", 1.0)):
        leaf = k.empty(name, (sx * hw, 0.0, 0.0))
        x0, x1 = (0.0, hw) if sx < 0 else (-hw, 0.0)
        _roller_curtain(k, leaf, name[4:], x0, x1, h)
        if name == "Leaf":
            k.empty("Handle", (hw - 0.15, 0.06, 1.0), parent=leaf)


def _slide(k: Kit, p: dict) -> None:
    w, h, jamb, t, ft = p["w"], p["h"], p["jamb"], p["wall_t"], p["frame_t"]
    hw = w / 2
    fr, body, trim = _box_frame(k, hw, jamb, h, t, "metal_grey", frame_t=ft)
    for sy in (-1, 1):   # head track cover and a thermometer box on the front
        y0, y1 = sorted((sy * ft / 2, sy * (ft / 2 + 0.005)))
        trim.bx((-hw - jamb, y0, h + 0.02), (hw + jamb, y1, h + jamb - 0.02), "steel")
    obj = fr.build()
    _box_frame_collision(obj, hw, jamb, h, t)
    lt = 0.08
    lw = hw
    for name, sx in (("Leaf", -1.0), ("Leaf2", 1.0)):
        leaf = k.empty(name, (sx * hw, 0.0, 0.0))
        x0, x1 = (0.003, lw - 0.003) if sx < 0 else (-(lw - 0.003), -0.003)
        lf = k.obj("LeafMesh" + name[4:], parent=leaf)
        core = lf.part(bevel=0.006, segments=2)
        edge = lf.part(bevel=0.002)
        soft = lf.part(bevel=0.0)
        core.bx((x0 + 0.03, -lt / 2 + 0.004, 0.03), (x1 - 0.03, lt / 2 - 0.004, h - 0.03), "plastic_white")
        # steel edge channel all round
        edge.bx((x0, -lt / 2, 0.02), (x0 + 0.03, lt / 2, h - 0.003), "steel")
        edge.bx((x1 - 0.03, -lt / 2, 0.02), (x1, lt / 2, h - 0.003), "steel")
        edge.bx((x0, -lt / 2, h - 0.03), (x1, lt / 2, h - 0.003), "steel")
        edge.bx((x0, -lt / 2, 0.02), (x1, lt / 2, 0.05), "steel")
        # floor seal and the meeting-edge rubber seal
        soft.bx((x0 + 0.01, -0.02, 0.003), (x1 - 0.01, 0.02, 0.02), "rubber")
        xm0, xm1 = (x1 - 0.002, x1) if sx < 0 else (x0, x0 + 0.002)
        soft.bx((xm0, -0.025, 0.05), (xm1, 0.025, h - 0.03), "rubber")
        # kick plate and stiffening ribs both faces, a pull bar near the meeting edge, a hazard stripe at eye level
        hx = x1 - 0.12 if sx < 0 else x0 + 0.12
        for sy in (-1, 1):
            y0, y1 = sorted((sy * (lt / 2 - 0.004), sy * (lt / 2 + 0.002)))
            edge.bx((x0 + 0.04, y0, 0.06), (x1 - 0.04, y1, 0.36), "steel")
            for z in (1.2, 2.4):
                edge.bx((x0 + 0.04, y0, z), (x1 - 0.04, y1, z + 0.04), "steel")
            edge.bx((x0 + 0.04, y0, 1.62), (x1 - 0.04, y1, 1.7), "paint_hazard_orange")
            yb = sy * (lt / 2 + 0.06)
            edge.rod((hx, yb, 0.85), (hx, yb, 1.45), 0.016, "steel", segs=10)
            for z in (0.9, 1.4):
                edge.rod((hx, sy * lt / 2, z), (hx, yb, z), 0.01, "steel", segs=8)
        lf.build()
        k.empty("Handle" + name[4:], (hx, 0.0, 1.0), parent=leaf)


def _vault(k: Kit, p: dict) -> None:
    w, h, jamb, t = p["w"], p["h"], p["jamb"], p["wall_t"]
    hw = w / 2
    fr, body, trim = _box_frame(k, hw, jamb, h, t, "metal_dark")
    for sy in (-1, 1):   # a steel face plate ring around the reveal, bolt heads
        y0, y1 = sorted((sy * t / 2, sy * (t / 2 + 0.006)))
        for sx in (-1, 1):
            x0, x1 = sorted((sx * (hw + 0.012), sx * (hw + jamb - 0.012)))
            trim.bx((x0, y0, 0.0), (x1, y1, h + jamb - 0.012), "steel")
            for z in (0.3, 1.0, 1.7):
                trim.cyl(0.012, 0.008, ((x0 + x1) / 2, sy * (t / 2 + 0.008), z), "steel", axis="Y", segs=8)
        trim.bx((-hw - jamb + 0.012, y0, h + 0.012), (hw + jamb - 0.012, y1, h + jamb - 0.012), "steel")
    obj = fr.build()
    _box_frame_collision(obj, hw, jamb, h, t)
    leaf = k.empty("Leaf", (-hw, 0.0, 0.0))
    lt = 0.12
    x0, x1 = 0.003, w - 0.003
    lf = k.obj("LeafMesh", parent=leaf)
    slab = lf.part(bevel=0.01, segments=2)
    det = lf.part(bevel=0.002)
    slab.bx((x0, -lt / 2, 0.006), (x1, lt / 2, h - 0.003), "metal_dark")
    yf = lt / 2   # front face (Blender +Y = Godot -Z, the antechamber side)
    det.bx((x0 + 0.08, yf, 0.08), (x1 - 0.08, yf + 0.01, h - 0.08), "metal_grey")
    det.bx((x0 + 0.14, yf + 0.01, 0.14), (x1 - 0.14, yf + 0.016, h - 0.14), "metal_dark")
    # locking wheel (hub, rim, 4 spokes), the combination dial and a key escutcheon
    cx, cz = w / 2, 1.15
    det.cyl(0.07, 0.06, (cx, yf + 0.046, cz), "steel", axis="Y", segs=16)
    rim = lf.part(bevel=0.0)
    n = 16
    r = 0.26
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        rim.rod((cx + r * math.cos(a0), yf + 0.07, cz + r * math.sin(a0)),
                (cx + r * math.cos(a1), yf + 0.07, cz + r * math.sin(a1)), 0.018, "steel", segs=8)
    for i in range(4):
        a = math.pi / 4 + math.pi / 2 * i
        rim.rod((cx, yf + 0.06, cz), (cx + r * math.cos(a), yf + 0.07, cz + r * math.sin(a)), 0.014, "steel",
                segs=8)
    det.cyl(0.06, 0.03, (cx, yf + 0.031, cz + 0.5), "chrome", axis="Y", segs=20)
    det.cyl(0.035, 0.02, (cx, yf + 0.055, cz + 0.5), "metal_dark", axis="Y", segs=16)
    det.bx((cx - 0.03, yf + 0.016, cz - 0.52), (cx + 0.03, yf + 0.024, cz - 0.4), "brass")
    # hinge barrels on the hinge edge (front) and locking bolt heads along the latch edge
    for z in (0.35, h / 2, h - 0.35):
        det.cyl(0.045, 0.32, (x0 + 0.05, yf + 0.04, z), "steel", segs=14)
    for z in (0.4, 0.8, 1.2, 1.6, 2.0):
        det.cyl(0.03, 0.03, (x1 - 0.07, yf + 0.018, z), "steel", axis="Y", segs=12)
    det.bx((x1 - 0.2, yf, h - 0.32), (x1 - 0.1, yf + 0.004, h - 0.2), "paint_hazard_orange")
    # back face: the bolt-work cover plate
    det.bx((x0 + 0.12, -lt / 2 - 0.008, 0.3), (x1 - 0.12, -lt / 2, h - 0.3), "metal_grey")
    lf.build()
    k.empty("Handle", (w - 0.15, 0.0, 1.0), parent=leaf)


def _industrial(fn: str):
    return {"roller_twin": _roller_twin, "slide": _slide, "vault": _vault}.get(fn)


def build(ctx) -> None:
    k = Kit(ctx)
    p = ctx.params
    fn = _industrial(p.get("fn", ""))
    if fn is not None:
        fn(k, p)
        return
    leaf_w, jamb, leaves = _KINDS[p["kind"]]
    hw = leaf_w * leaves / 2 + jamb
    _frame(k, hw, jamb, p["wall_t"], p["finish"])
    for i in range(leaves):
        sign = 1.0 if i == 0 else -1.0
        _leaf(k, "Leaf" if i == 0 else "Leaf2", -sign * (hw - jamb), sign, leaf_w, p["finish"], p["kind"])
