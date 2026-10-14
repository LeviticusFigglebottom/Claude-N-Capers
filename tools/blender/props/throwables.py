"""Throwables (PO-C): the six ThrowableDef.model visuals. Original models at PD2-faithful sizes; no third-party
assets.

Contract (visual_slots.md "Items", D-069): origin at the body centre, Godot +Y (Blender +Z) up the fuse, a
`Pin` node that ENV A hides at the `pin_pull` event. The same scene is the first-person held item (rides the
`rig_arms` weapon bone, so real-world size, no scale) and the flying / lying `Visual` of ThrownItem (which
hides the `Pin`). No collision (ThrownItem sweeps a ray). Godot -Z (Blender +Y) is the front: the spoon of
every grenade runs down that side, the pull ring hangs off +X (the thumb side of a right-hand grip).

* `prop_throwable_frag`: PD2 frag, an M67-style 64 mm olive steel sphere with a yellow band, fuse, spoon,
  pin and ring (`Pin` = pin + ring).
* `prop_throwable_concussion`: an M84-style stun canister (44 x 100 mm), grey painted steel with two rows of port
  holes, a white band, black end caps, fuse, spoon and `Pin`.
* `prop_throwable_incendiary`: the def has no description; PD2's incendiary grenade is a thrown canister
  (fuse 2.5 s, burns where it lands), so an AN-M14-style 63 x 115 mm grey canister with two red bands, a
  rolled lid, fuse, spoon and `Pin`, not a molotov.
* `prop_throwable_knife`: a 24 cm one-piece throwing knife, tip up (+Y), edge to the front (-Z), a
  cord-wrapped (leather) handle and a lanyard ring at the pommel. No pin.
* `prop_throwable_boss_injector`: PD2's injector (Kingpin deck), a 16 cm auto-injector: black body with
  grip rings, a glass window on green serum, a white label band, the orange needle shield at the bottom and the
  blue safety cap at the top as `Pin` (it comes off at `pin_pull`).
* `prop_throwable_steady_flask`: PD2's Stoic hip flask (6 oz, 95 x 130 x 28 mm), curved brushed steel with a
  leather wrap and a hinged screw cap as `Pin` (unscrewed at `pin_pull`).
"""

import math

import bmesh

from _pb import Kit
from lib import uv

TRI_BUDGET = 2000
_T = {"prefab": "throwable"}
VARIANTS = {
    "prop_throwable_frag": {"fn": "frag", "cat": {**_T, "kind": "frag", "surface": "metal"}},
    "prop_throwable_concussion": {"fn": "concussion", "cat": {**_T, "kind": "concussion", "surface": "metal"}},
    "prop_throwable_incendiary": {"fn": "incendiary", "cat": {**_T, "kind": "incendiary", "surface": "metal"}},
    "prop_throwable_knife": {"fn": "knife", "cat": {**_T, "kind": "throwing_knife", "surface": "metal"}},
    "prop_throwable_boss_injector": {"fn": "injector", "cat": {**_T, "kind": "injector", "surface": "metal"}},
    "prop_throwable_steady_flask": {"fn": "flask", "cat": {**_T, "kind": "flask", "surface": "metal"}},
}


# ------------------------------------------------------------------------------------ shared bits

def _strip(p, pts, thick: float, x0: float, x1: float, key: str) -> None:
    """A flat band (the spoon) following the (y, z) polyline ``pts`` outward (its outer face on the line,
    ``thick`` inward towards the body axis), extruded along X from x0 to x1."""
    n = len(pts)
    inner = []
    for i in range(n):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        dy, dz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dy, dz) or 1.0
        ny, nz = dz / ln, -dy / ln  # normal on the right of the walking direction
        # point the offset towards the axis (y = 0)
        if ny * pts[i][0] > 0 or (abs(pts[i][0]) < 1e-6 and nz > 0):
            ny, nz = -ny, -nz
        inner.append((pts[i][0] + ny * thick, pts[i][1] + nz * thick))
    p.profile_x(list(pts) + list(reversed(inner)), x0, x1, key)


def _fuse(k: Kit, o, top: float, spoon: list[tuple[float, float]]) -> None:
    """Grenade fuse on the body top at z = ``top``: a neck, the fuse head, the spoon (``spoon`` = its (y, z)
    outer line from the head over to the front and down the side) and the `Pin` object (pin through the head
    along X, the pull ring on +X)."""
    f = o.part(bevel=0.0008)
    f.cyl(0.0095, 0.006, (0.0, 0.0, top + 0.003), "steel_bare", segs=14)
    f.cyl(0.0085, 0.016, (0.0, 0.0, top + 0.014), "metal_matte", segs=14)
    f.cyl(0.006, 0.003, (0.0, 0.0, top + 0.0235), "steel_bare", segs=12)
    # striker housing ears holding the pin
    for sx in (-1, 1):
        f.bx((sx * 0.0085 - 0.002, -0.004, top + 0.008), (sx * 0.0085 + 0.002, 0.004, top + 0.02), "metal_matte")
    s = o.part(bevel=0.0)
    _strip(s, spoon, 0.0012, -0.0055, 0.0055, "steel_bare")
    pz = top + 0.014
    pin = k.obj("Pin")
    pp = pin.part(bevel=0.0)
    pp.rod((-0.012, 0.0, pz), (0.015, 0.0, pz), 0.0011, "steel_bare", segs=6)
    pp.torus(0.011, 0.0014, (0.026, 0.0, pz), "steel_bare", segs=20, rsegs=5, axis="Y")
    pin.build(density=uv.DENSITY_FIRST_PERSON)


# ------------------------------------------------------------------------------------ grenades

def _frag(k: Kit, p: dict) -> None:
    """M67-style frag: a 64 mm olive steel sphere, a yellow marking band under the fuse, the fuse and spoon."""
    r = 0.032
    o = k.obj("Body")
    b = o.part(bevel=0.0)
    b.sphere(r, (0.0, 0.0, 0.0), "grenade_olive", segs=22, rings=12)
    # yellow marking band hugging the upper hemisphere (same facets as the sphere)
    band = []
    for zb in (0.0135, 0.0185):
        band.append((math.sqrt(r * r - zb * zb) + 0.0008, zb))
    b.lathe([(band[0][0] - 0.002, band[0][1])] + band + [(band[1][0] - 0.002, band[1][1])], "metal_yellow", segs=22)
    # fuse well collar on the sphere top
    b.cyl(0.011, 0.004, (0.0, 0.0, r - 0.001), "grenade_olive", segs=16)
    top = r + 0.001
    spoon = [(-0.004, top + 0.024), (0.008, top + 0.024), (0.016, top + 0.017), (0.024, r * 0.72),
             (0.0335, 0.012), (0.0345, -0.004), (0.032, -0.016)]
    _fuse(k, o, top, spoon)
    o.build(density=uv.DENSITY_FIRST_PERSON)


def _concussion(k: Kit, p: dict) -> None:
    """M84-style stun canister (44 x 100 mm): grey painted steel, two rows of eight port holes, a white band, black end
    caps, the fuse and spoon."""
    r, h = 0.022, 0.1
    o = k.obj("Body")
    b = o.part(bevel=0.0)
    b.lathe([(0.0, -h / 2), (r - 0.003, -h / 2), (r, -h / 2 + 0.003), (r, h / 2 - 0.003), (r - 0.003, h / 2),
             (0.0, h / 2)], "metal_grey", segs=20)
    t = o.part(bevel=0.0)
    for z0, z1 in ((-h / 2 - 0.002, -h / 2 + 0.012), (h / 2 - 0.012, h / 2 + 0.002)):
        t.lathe([(0.0, z0), (r - 0.002, z0), (r + 0.0012, z0 + 0.002), (r + 0.0012, z1), (0.0, z1)], "alu_black",
                segs=20)
    t.cyl(r + 0.0008, 0.012, (0.0, 0.0, 0.0), "metal_white", segs=20)
    for zr in (-0.024, 0.024):
        for i in range(8):
            a = 2 * math.pi * (i + (0.5 if zr > 0 else 0.0)) / 8
            c, s = math.cos(a), math.sin(a)
            t.rod((c * (r - 0.0005), s * (r - 0.0005), zr), (c * (r + 0.0007), s * (r + 0.0007), zr), 0.0042, "polymer",
                  segs=8)
    top = h / 2 + 0.002
    spoon = [(-0.004, top + 0.024), (0.008, top + 0.024), (0.016, top + 0.018), (0.0235, top + 0.006),
             (0.0245, top - 0.012), (0.0245, -0.012)]
    _fuse(k, o, top, spoon)
    o.build(density=uv.DENSITY_FIRST_PERSON)


def _incendiary(k: Kit, p: dict) -> None:
    """AN-M14-style incendiary canister (63 x 115 mm): grey sheet steel, two red bands, a rolled lid seam and
    a stepped top, the fuse and spoon."""
    r, h = 0.0315, 0.115
    o = k.obj("Body")
    b = o.part(bevel=0.0)
    b.lathe([(0.0, -h / 2), (r - 0.002, -h / 2), (r, -h / 2 + 0.002), (r, h / 2 - 0.004), (r - 0.006, h / 2),
             (0.012, h / 2 + 0.003), (0.0, h / 2 + 0.003)], "canister_grey", segs=24)
    t = o.part(bevel=0.0)
    for zc in (-0.03, 0.022):
        t.cyl(r + 0.0007, 0.009, (0.0, 0.0, zc), "metal_red", segs=24)
    # rolled lid seam
    t.torus(r - 0.0005, 0.0018, (0.0, 0.0, h / 2 - 0.006), "canister_grey", segs=24, rsegs=5)
    top = h / 2 + 0.003
    spoon = [(-0.004, top + 0.024), (0.008, top + 0.024), (0.018, top + 0.016), (0.028, top - 0.002),
             (0.0335, top - 0.016), (0.0335, -0.004)]
    _fuse(k, o, top, spoon)
    o.build(density=uv.DENSITY_FIRST_PERSON)


# ------------------------------------------------------------------------------------ knife

def _solid(p, outline: list[tuple[float, float]], half: list[float], key: str) -> None:
    """A flat solid from a (y, z) outline, each point ``half[i]`` thick either side of x = 0 (a ground edge is
    thin, the spine thick): two outline faces and the rim."""
    bm = p.bm
    a = [bm.verts.new((half[i], y, z)) for i, (y, z) in enumerate(outline)]
    b = [bm.verts.new((-half[i], y, z)) for i, (y, z) in enumerate(outline)]
    n = len(outline)
    faces = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((a[i], b[i], b[j], a[j])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    p._set_mat(faces, p.m(key))


def _knife(k: Kit, p: dict) -> None:
    """24 cm one-piece throwing knife, tip up (+Z), the edge to the front (+Y): a spear-point blade ground thin
    along the edge, a cord-wrapped handle (leather) between the ricasso and the pommel, a lanyard ring."""
    o = k.obj("Body")
    bl = o.part(bevel=0.0)
    edge, spine = 0.0004, 0.0021
    blade = [(-0.011, -0.012), (0.012, -0.012), (0.0125, 0.055), (0.0095, 0.09), (0.004, 0.11), (0.0, 0.12),
             (-0.005, 0.104), (-0.009, 0.086), (-0.011, 0.06)]
    half = [spine, edge * 3, edge, edge, edge, edge, edge * 2, spine * 0.6, spine]
    _solid(bl, blade, half, "steel_bare")
    # fuller line on both faces
    for sx in (-1, 1):
        bl.bx((sx * spine - 0.0004, -0.0055, -0.004), (sx * spine + 0.0004, -0.0035, 0.06), "metal_matte")
    # tang (handle core) to the pommel, a rounded butt
    tang = [(-0.011, -0.012), (0.011, -0.012), (0.0105, -0.1), (0.008, -0.112), (0.0, -0.118), (-0.008, -0.112),
            (-0.0105, -0.1)]
    _solid(bl, tang, [0.002] * len(tang), "steel_bare")
    w = o.part(bevel=0.0012)
    n = 13
    for i in range(n):
        z = -0.019 - i * 0.0062
        tilt = 0.0012 if i % 2 else -0.0012
        w.bx((-0.0045, -0.0125, z - 0.0027 + tilt), (0.0045, 0.0125, z + 0.0027 - tilt), "leather")
    # lanyard ring through the pommel (ring in the blade plane)
    w.torus(0.0075, 0.0013, (0.0, 0.0, -0.118), "steel_bare", segs=16, rsegs=5, axis="X")
    o.build(density=uv.DENSITY_FIRST_PERSON)


# ------------------------------------------------------------------------------------ injector / flask

def _injector(k: Kit, p: dict) -> None:
    """Auto-injector (16 cm): black grip body with rings, a glass window on green serum, white label band, the
    orange needle shield at the bottom and the blue safety cap (`Pin`) on top."""
    r = 0.0125
    o = k.obj("Body")
    b = o.part(bevel=0.0)
    b.lathe([(0.0, -0.058), (r - 0.002, -0.058), (r, -0.055), (r, -0.012), (r - 0.001, -0.011), (0.0, -0.011)],
            "alu_black", segs=20)
    b.lathe([(0.0, 0.031), (r - 0.001, 0.031), (r, 0.032), (r, 0.056), (r - 0.002, 0.059), (0.0, 0.059)],
            "alu_black", segs=20)
    b.cyl(0.0098, 0.044, (0.0, 0.0, 0.0105), "serum_green", segs=16)
    b.cyl(r + 0.0004, 0.04, (0.0, 0.0, 0.0105), "glass", segs=20)
    # plunger rod visible in the serum, grip rings, label band
    b.cyl(0.0025, 0.03, (0.0, 0.0, 0.017), "steel_bare", segs=8)
    for z in (-0.05, -0.044, -0.038):
        b.torus(r, 0.0009, (0.0, 0.0, z), "polymer", segs=20, rsegs=4)
    b.cyl(r + 0.0006, 0.016, (0.0, 0.0, -0.024), "metal_white", segs=20)
    b.cyl(r + 0.0009, 0.003, (0.0, 0.0, -0.024), "safety_orange", segs=20)
    # needle shield (orange) at the bottom
    b.lathe([(0.0, -0.079), (0.008, -0.079), (0.0105, -0.076), (0.0105, -0.058), (0.0, -0.058)], "safety_orange",
            segs=18)
    b.cyl(0.0022, 0.0008, (0.0, 0.0, -0.0794), "polymer", segs=8)
    o.build(density=uv.DENSITY_FIRST_PERSON)
    cap = k.obj("Pin")
    c = cap.part(bevel=0.0)
    c.lathe([(0.0, 0.059), (0.0115, 0.059), (0.0115, 0.074), (0.009, 0.078), (0.0, 0.078)], "metal_blue", segs=18)
    for i in range(8):
        a = 2 * math.pi * i / 8
        c.cbox((math.cos(a) * 0.0117, math.sin(a) * 0.0117, 0.066), (0.0018, 0.0018, 0.011), "metal_blue")
    cap.build(density=uv.DENSITY_FIRST_PERSON)


def _flask_outline(w: float, depth: float, bow: float, segs: int = 10) -> list[tuple[float, float]]:
    """Plan (x, y) of a curved hip flask: a bowed band ``w`` wide and ``depth`` thick, rounded ends."""
    pts = []
    hd = depth / 2
    xr = w / 2 - hd

    def cy(x: float) -> float:
        return bow * ((x / xr) ** 2 - 0.5)

    for i in range(segs + 1):  # front (+Y) face, -x -> +x
        x = -xr + 2 * xr * i / segs
        pts.append((x, cy(x) + hd))
    for i in range(1, 6):  # right end cap
        a = math.pi / 2 - math.pi * i / 6
        pts.append((xr + hd * math.cos(a), cy(xr) + hd * math.sin(a)))
    for i in range(segs + 1):  # back face, +x -> -x
        x = xr - 2 * xr * i / segs
        pts.append((x, cy(x) - hd))
    for i in range(1, 6):
        a = -math.pi / 2 - math.pi * i / 6
        pts.append((-xr + hd * math.cos(a), cy(-xr) + hd * math.sin(a)))
    return pts


def _flask(k: Kit, p: dict) -> None:
    """Hip flask (6 oz): a curved brushed-steel body 95 x 28 mm in plan (the front bows out), 130 mm tall with
    the cap, a stepped shoulder, a leather wrap band round the middle, a neck and the hinged cap (`Pin`)."""
    w, d, bow = 0.095, 0.022, 0.006
    o = k.obj("Body")
    b = o.part(bevel=0.003, segments=1, angle=45.0)
    b.slab(_flask_outline(w, d, bow), -0.062, 0.046, "steel")
    s = o.part(bevel=0.002, segments=1, angle=45.0)
    s.slab(_flask_outline(w * 0.8, d * 0.85, bow * 0.7), 0.046, 0.052, "steel")
    s.slab(_flask_outline(w * 0.45, d * 0.75, bow * 0.3), 0.052, 0.055, "steel")
    lw = o.part(bevel=0.001)
    lw.slab(_flask_outline(w + 0.0016, d + 0.0016, bow), -0.042, 0.026, "leather")
    n = o.part(bevel=0.0)
    n.cyl(0.0085, 0.008, (0.0, 0.0, 0.059), "chrome", segs=16)
    # cap hinge on the shoulder (-X side)
    n.bx((-0.016, -0.003, 0.053), (-0.009, 0.003, 0.06), "chrome")
    o.build(density=uv.DENSITY_FIRST_PERSON)
    cap = k.obj("Pin")
    c = cap.part(bevel=0.0008)
    c.cyl(0.0115, 0.012, (0.0, 0.0, 0.069), "chrome", segs=20)
    c.cyl(0.0095, 0.002, (0.0, 0.0, 0.076), "chrome", segs=20)
    c.bx((-0.017, -0.0025, 0.062), (-0.010, 0.0025, 0.067), "chrome")
    g = cap.part(bevel=0.0)
    for i in range(12):
        a = 2 * math.pi * i / 12
        g.cbox((math.cos(a) * 0.0117, math.sin(a) * 0.0117, 0.069), (0.0016, 0.0016, 0.009), "chrome")
    cap.build(density=uv.DENSITY_FIRST_PERSON)


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
