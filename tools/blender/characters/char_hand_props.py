"""Hand-held NPC props (D-115): the props of the ambient clips, built to the grips of ``_anim_humanoid.GRIPS``.

ENV A attaches each one at a hand socket so the activity is no longer mimed. Every glb is in the prop's own
frame (the ``PROPS`` conventions of ``_anim_humanoid``, Blender axes: Godot (x, y, z) = Blender (x, z, -y)):

* ``char_hand_phone``: smartphone slab 0.072 x 0.009 x 0.147 m, origin at its centre, Z = the speaker end, the
  screen faces -Y (Godot +Z).
* ``char_hand_cigarette``: r 0.0042 m, 0.072 m long, origin at the filter (mouth) end, Z = toward the ember
  (cork filter, white paper, a glowing ember tip).
* ``char_hand_mug``: r 0.041 m, h 0.095 m, origin at the base centre, Z = up, the handle on -X, coffee inside.
* ``char_hand_mop``: string mop, origin at the floor end of the shaft (the head's centre on the floor), Z = up
  the 1.40 m shaft.
* ``char_hand_book`` (open, 0.30 x 0.022 x 0.23, centre, pages toward -Y), ``char_hand_rag`` (folded towel
  0.20 x 0.13 x 0.022, origin at the underside centre), ``char_hand_bottle`` (r 0.04, 0.30 tall, base centre),
  ``char_hand_glass`` (tumbler r 0.04, h 0.10, base centre), ``char_hand_cash`` (banknote stack
  0.156 x 0.066 x 0.015, centre).

The Godot scenes ``world/characters/_props/hand_<prop>.tscn`` (``make_hand_prop_scenes.py``) wrap each glb at
the SOURCE.txt ``<prop>_grip`` transform, so the scene root goes at ``HandR/Socket`` (or ``HandL/Socket``) with
an identity transform. No textures, logos or real branding: plain procedural shapes and library materials.
"""

from __future__ import annotations

import math

TRI_BUDGET = 3000
EXPORT = {"embed": False, "animations": False, "skins": False, "morph": False}
VARIANTS = {f"char_hand_{p}": {"prop": p} for p in
            ("phone", "cigarette", "mug", "mop", "book", "rag", "bottle", "glass", "cash")}


def _lathe(m, profile: list, segs: int, centre=(0.0, 0.0)) -> None:
    """Surface of revolution about Blender Z through ``centre`` (x, y). ``profile`` = [(r, z, mat), ...] walked so
    the surface lies on its right (outside going up, inside coming down); a point with r = 0 is a pole. ``mat``
    of a point is the material of the band that ends at it."""
    from _outfit import Vector

    cx, cy = centre
    rings: list = []
    for r, z, _mat in profile:
        if r <= 0.0:
            rings.append(m.add(Vector((cx, cy, z))))
        else:
            rings.append(m.ring([Vector((cx + r * math.cos(2 * math.pi * i / segs), cy + r * math.sin(2 * math.pi * i / segs), z))
                                 for i in range(segs)]))
    for i in range(1, len(profile)):
        a, b, mat = rings[i - 1], rings[i], profile[i][2]
        if isinstance(a, int):
            m.fan(b, a, mat, flip=True)
        elif isinstance(b, int):
            m.fan(a, b, mat)
        else:
            m.band(a, b, mat)


def _tube(m, path: list, r: float, segs: int, mat: str) -> None:
    """A closed tube of radius ``r`` along the polyline ``path`` (Blender points), capped at both ends."""
    from _outfit import Vector

    pts = [Vector(p) for p in path]
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0.0, 0.0, 1.0)) if abs(t.z) < 0.9 else Vector((1.0, 0.0, 0.0))
        u = t.cross(ref).normalized()
        w = t.cross(u)
        rings.append(m.ring([p + (u * math.cos(2 * math.pi * j / segs) + w * math.sin(2 * math.pi * j / segs)) * r
                             for j in range(segs)]))
    for i in range(1, len(rings)):
        m.band(rings[i - 1], rings[i], mat, inside=(pts[i - 1] + pts[i]) * 0.5)
    for ring, end, inward in ((rings[0], pts[0], pts[1]), (rings[-1], pts[-1], pts[-2])):
        pole = m.add(end)
        for j in range(segs):
            m.face((ring[j], ring[(j + 1) % segs], pole), mat, inside=inward)


def _phone(m) -> None:
    import _outfit as o
    from _outfit import Gear, Matrix

    # local: X = Blender X, Y = Blender Z (up the phone), Z = Blender -Y (out of the screen)
    to_b = Matrix(((1.0, 0.0, 0.0, 0.0), (0.0, 0.0, -1.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    g = Gear()
    g.prism(o.rounded_rect(0.072, 0.147, 0.009, 3), -0.0045, 0.0045, "polymer_black")
    g.bevel(0.0015, 1, 30.0)
    g.prism(o.rounded_rect(0.066, 0.139, 0.006, 3), 0.0044, 0.0049, "char_lens")
    g.box((-0.012, 0.064, 0.0047), (0.012, 0.0655, 0.0050), "polymer_black")                 # speaker slot
    g.prism(o.rounded_rect(0.020, 0.030, 0.005, 2), -0.0055, -0.0044, "polymer_black")      # camera bump (back)
    g.cyl(0.0042, 0.0012, centre=(-0.003, 0.054, -0.0058), segs=10, mat="chrome")
    g.box((0.036, 0.020, -0.0015), (0.0372, 0.040, 0.0015), "chrome")                         # side key
    m.extend(g.to_mesh(to_b))


def _cigarette(m) -> None:
    import _anim_humanoid as lib

    r, f, n = lib.CIG_R, lib.CIG_FILTER, lib.CIG_LEN
    _lathe(m, [(0.0, 0.0, ""), (r * 0.9, 0.0, "char_prop_filter"), (r, 0.0006, "char_prop_filter"),
               (r, f, "char_prop_filter"), (r, n - 0.004, "char_prop_paper"), (r * 0.97, n - 0.0012, "char_prop_ember"),
               (0.0, n, "char_prop_ember")], 10)


def _mug(m) -> None:
    _lathe(m, [(0.0, 0.0, ""), (0.037, 0.0, "char_prop_ceramic"), (0.041, 0.004, "char_prop_ceramic"),
               (0.041, 0.093, "char_prop_ceramic"), (0.0395, 0.095, "char_prop_ceramic"),
               (0.0365, 0.093, "char_prop_ceramic"), (0.0365, 0.080, "char_prop_ceramic"), (0.0, 0.080, "char_prop_coffee")],
           20)
    path = [(-0.039, 0.0, 0.076)]
    for i in range(7):
        a = math.pi * (0.5 - i / 6.0)
        path.append((-0.050 - 0.020 * math.cos(a), 0.0, 0.049 + 0.024 * math.sin(a)))
    path.append((-0.039, 0.0, 0.022))
    _tube(m, path, 0.0055, 6, "char_prop_ceramic")


def _mop(m) -> None:
    import _anim_humanoid as lib

    top = lib.MOP_LENGTH
    _lathe(m, [(0.0, 0.055, ""), (0.012, 0.055, "char_metal_silver"), (0.012, top - 0.035, "char_metal_silver"),
               (0.0135, top - 0.034, "polymer_black"), (0.0135, top - 0.002, "polymer_black"), (0.0, top, "polymer_black")],
           10)
    _lathe(m, [(0.0, 0.035, ""), (0.024, 0.035, "char_hardhat_blue"), (0.024, 0.105, "char_hardhat_blue"),
               (0.015, 0.115, "char_hardhat_blue"), (0.0, 0.115, "char_hardhat_blue")], 12)
    n = 22
    for i in range(n):
        a = 2 * math.pi * (i + 0.5 * (i % 2)) / n
        reach = 0.15 + 0.025 * math.sin(i * 2.3)
        ca, sa = math.cos(a), math.sin(a)
        path = [(0.016 * ca, 0.016 * sa, 0.06), (0.05 * ca, 0.05 * sa, 0.05), (0.10 * ca, 0.10 * sa, 0.022),
                (reach * ca, reach * sa, 0.0066), ((reach + 0.03) * ca, (reach + 0.03) * sa, 0.0066)]
        _tube(m, path, 0.0065, 4, "char_prop_mop_string")


def _book(m) -> None:
    from _outfit import Gear, Matrix

    g = Gear()
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * 0.004, sx * 0.150))
        g.box((x0, 0.004, -0.115), (x1, 0.010, 0.115), "char_prop_book")            # cover (back, +Y)
        g.box((min(x0, x1) + (0.004 if sx < 0 else 0.0), -0.011, -0.110),
              (max(x0, x1) - (0.0 if sx < 0 else 0.004), 0.004, 0.110), "char_prop_paper")
    g.box((-0.006, 0.002, -0.115), (0.006, 0.011, 0.115), "char_prop_book")          # spine
    g.bevel(0.0012, 1, 30.0)
    m.extend(g.to_mesh(Matrix.Identity(4)))


def _rag(m) -> None:
    from _outfit import Gear, Matrix

    g = Gear()
    g.box((-0.10, -0.065, 0.0), (0.10, 0.065, 0.011), "char_shirt_white")
    g.bevel(0.004, 2, 30.0)
    g.box((-0.098, -0.063, 0.011), (0.09, 0.063, 0.022), "char_shirt_white")
    g.bevel(0.004, 2, 30.0)
    m.extend(g.to_mesh(Matrix.Identity(4)))


def _bottle(m) -> None:
    b, c, p = "char_prop_bottle", "brass", "char_prop_paper"
    _lathe(m, [(0.0, 0.0, ""), (0.036, 0.0, b), (0.040, 0.005, b), (0.040, 0.070, b), (0.0403, 0.070, p),
               (0.0403, 0.150, p), (0.040, 0.150, b), (0.040, 0.200, b), (0.030, 0.228, b), (0.016, 0.245, b),
               (0.014, 0.275, b), (0.0155, 0.278, c), (0.0155, 0.300, c), (0.0, 0.300, c)], 16)


def _glass(m) -> None:
    g = "char_prop_glass"
    _lathe(m, [(0.0, 0.0, ""), (0.038, 0.0, g), (0.040, 0.003, g), (0.040, 0.100, g), (0.0365, 0.100, g),
               (0.0365, 0.014, g), (0.0, 0.014, g)], 18)


def _cash(m) -> None:
    from _outfit import Gear, Matrix

    g = Gear()
    g.box((-0.078, -0.033, -0.0075), (0.078, 0.033, 0.0075), "char_prop_cash")
    g.bevel(0.0008, 1, 30.0)
    g.box((-0.014, -0.0335, -0.0078), (0.014, 0.0335, 0.0078), "char_prop_paper")    # paper strap
    m.extend(g.to_mesh(Matrix.Identity(4)))


def build(ctx) -> None:
    import _outfit as o
    import _tri
    import bmesh
    import bpy
    from _outfit import Mesh
    from lib import scene, uv

    prop = ctx.params["prop"]
    m = Mesh()
    {"phone": _phone, "cigarette": _cigarette, "mug": _mug, "mop": _mop, "book": _book, "rag": _rag,
     "bottle": _bottle, "glass": _glass, "cash": _cash}[prop](m)
    me = bpy.data.meshes.new("Visual")
    me.from_pydata([tuple(p) for p in m.v], [], [tuple(f) for f in m.f])
    order = sorted(set(m.m))
    for mid in order:
        me.materials.append(o.material(ctx, mid))
    idx = {mid: i for i, mid in enumerate(order)}
    me.polygons.foreach_set("material_index", [idx[x] for x in m.m])
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    uv.box_project(bm, density=512.0, texture_px=1024.0)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(40.0))
    me.validate(clean_customdata=False)
    me.update()
    obj = bpy.data.objects.new("Visual", me)
    scene.link(obj, None)
    _tri.triangulate(obj)
    lo = [min(p[i] for p in m.v) for i in range(3)]
    hi = [max(p[i] for p in m.v) for i in range(3)]
    ctx.source_extra["prop"] = prop
    ctx.source_extra["tris"] = m.tris()
    ctx.source_extra["bounds_blender"] = (f"({lo[0]:.4f},{lo[1]:.4f},{lo[2]:.4f})..({hi[0]:.4f},{hi[1]:.4f},{hi[2]:.4f}) m "
                                          f"(Godot: x, z, -y)")
    ctx.source_extra["grip"] = (f"char_anim_humanoid/SOURCE.txt `{prop}_grip` (prop frame relative to the hand Socket); "
                                f"scene world/characters/_props/hand_{prop}.tscn wraps this glb at that transform")
