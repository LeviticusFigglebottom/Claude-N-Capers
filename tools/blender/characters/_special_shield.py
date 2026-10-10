"""Bulwark ballistic shield prop (P3, ``char_bulwark_shield`` / ``char_bulwark_aegis_shield``). Blender only.

A hand-held ballistic shield, 0.64 m wide x 1.10 m tall: a flat centre panel (0.42 m) with two
side wings angled 24 deg back, a viewport window near the top (smoked glass in a rubber frame), the
word ``TACTICAL`` as raised block letters (geometry, an original word, no real agency branding)
under the window, a rubber edge bumper, and on the back a vertical grip with stand-offs plus a
forearm strap.

Pivot / axes (Godot): origin at the centre of the grip, +Y up, **-Z = the shield face outward**
(the side bullets hit), X right as seen from behind. So the shield attaches at ``HandL/Socket`` (or
at ENV A's body offset) without rotation. The face is 0.078 m in front of the grip; the shield
centre is 0.05 m below the grip. Meshes: ``Visual`` (all surfaces) and ``Collision-convcolonly``
(convex hull of the three panels -> StaticBody3D ``Collision`` on import; the assembly turns it into
the ``Collision`` CollisionShape3D of ``world/characters/bulwark/bulwark_shield.tscn``).
"""

from __future__ import annotations

import math

import _outfit as o
from _outfit import Gear, Matrix, Mesh, Vector

W_CENTRE = 0.42
W_WING = 0.13
WING_DEG = 24.0
HEIGHT = 1.10
THICK = 0.022
GRIP_UP = 0.05        # grip above the shield centre
GRIP_BACK = 0.056     # grip axis behind the back face
WINDOW = (0.28, 0.095, 0.355)   # w, h, centre height (above the shield centre)

# 3 x 5 block glyphs: rectangles (x0, y0, x1, y1) in glyph units
GLYPHS = {
    "T": [(0, 4, 3, 5), (1, 0, 2, 4)],
    "A": [(0, 0, 1, 5), (2, 0, 3, 5), (0, 4, 3, 5), (0, 2, 3, 3)],
    "C": [(0, 0, 1, 5), (0, 4, 3, 5), (0, 0, 3, 1)],
    "I": [(1, 0, 2, 5), (0, 4, 3, 5), (0, 0, 3, 1)],
    "L": [(0, 0, 1, 5), (0, 0, 3, 1)],
}
WORD = "TACTICAL"


def _to_blender() -> Matrix:
    """Local shield frame (X = right seen from the front, Y = up, Z = out of the face) -> Blender
    (+Y = Godot -Z forward), with the grip at the origin."""
    rot = Matrix(((-1.0, 0.0, 0.0, 0.0), (0.0, 0.0, 1.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    return rot @ Matrix.Translation((0.0, -GRIP_UP, GRIP_BACK))


def _wing(sx: float) -> Matrix:
    """Frame of a wing: hinged at the centre panel's edge, rotated back (towards -Z)."""
    return (Matrix.Translation((sx * W_CENTRE / 2, 0.0, 0.0))
            @ Matrix.Rotation(math.radians(WING_DEG) * sx, 4, "Y"))


def shield_mesh(face: str, edge: str, letters: str, glass: str, metal: str) -> Mesh:
    base = _to_blender()
    m = Mesh()
    hh = HEIGHT / 2
    # centre panel with the viewport hole
    ww, wh, wz = WINDOW
    g = Gear()
    outline = [(-W_CENTRE / 2, -hh), (W_CENTRE / 2, -hh), (W_CENTRE / 2, hh), (-W_CENTRE / 2, hh)]
    hole = o.rounded_rect(ww, wh, 0.02, 3)
    hole = [(x, y + wz) for x, y in hole]
    g.mb.prism(outline, holes=[hole], axis="Z", start=0.0, end=THICK, mat=g._mat(face))
    g.bevel(0.003, 1, 30.0)
    # window frame (rubber) and smoked glass
    fr = 0.014
    g.box((-ww / 2 - fr, wz + wh / 2, THICK - 0.002), (ww / 2 + fr, wz + wh / 2 + fr, THICK + 0.008), edge)
    g.box((-ww / 2 - fr, wz - wh / 2 - fr, THICK - 0.002), (ww / 2 + fr, wz - wh / 2, THICK + 0.008), edge)
    g.box((-ww / 2 - fr, wz - wh / 2, THICK - 0.002), (-ww / 2, wz + wh / 2, THICK + 0.008), edge)
    g.box((ww / 2, wz - wh / 2, THICK - 0.002), (ww / 2 + fr, wz + wh / 2, THICK + 0.008), edge)
    g.box((-ww / 2 - 0.004, wz - wh / 2 - 0.004, THICK * 0.35), (ww / 2 + 0.004, wz + wh / 2 + 0.004, THICK * 0.65),
          glass)
    g.bevel(0.002, 1, 30.0)
    # raised block letters under the window
    unit = 0.0105
    n = len(WORD)
    total = n * 3 + (n - 1)
    x0 = -total * unit / 2
    y0 = wz - wh / 2 - fr - 0.03 - 5 * unit
    for ci, ch in enumerate(WORD):
        gx = x0 + ci * 4 * unit
        for a, b, c_, d in GLYPHS[ch]:
            g.box((gx + a * unit, y0 + b * unit, THICK - 0.001), (gx + c_ * unit, y0 + d * unit, THICK + 0.0035), letters)
    # a horizontal band under the lettering (reads as a stripe at range)
    g.box((-W_CENTRE / 2 + 0.01, y0 - 0.05, THICK - 0.001), (W_CENTRE / 2 - 0.01, y0 - 0.025, THICK + 0.002), letters)
    m.extend(g.to_mesh(base))
    # wings with a rounded outer edge and a rubber bumper
    for sx in (-1.0, 1.0):
        gw = Gear()
        r = 0.05
        pts = []
        # outline in wing-local x (0 at the hinge, sx * W_WING at the outer edge)
        for i in range(4):
            a = math.radians(-90.0 + 90.0 * i / 3)
            pts.append((sx * (W_WING - r + r * math.cos(a)), -hh + r + r * math.sin(a)))
        for i in range(4):
            a = math.radians(0.0 + 90.0 * i / 3)
            pts.append((sx * (W_WING - r + r * math.cos(a)), hh - r + r * math.sin(a)))
        pts += [(0.0, hh), (0.0, -hh)]
        if sx < 0:
            pts.reverse()
        gw.prism(pts, 0.0, THICK, face)
        gw.bevel(0.003, 1, 30.0)
        gw.box((sx * W_WING - 0.012 if sx > 0 else -W_WING - 0.004, -hh + r, -0.004),
               (W_WING + 0.004 if sx > 0 else -W_WING + 0.012, hh - r, THICK + 0.006), edge)
        gw.bevel(0.003, 1, 30.0)
        m.extend(gw.to_mesh(base @ _wing(sx)))
    # top/bottom bumpers along the centre panel
    gb = Gear()
    for y in (hh - 0.004, -hh - 0.008):
        gb.box((-W_CENTRE / 2, y, -0.004), (W_CENTRE / 2, y + 0.012, THICK + 0.006), edge)
    gb.bevel(0.003, 1, 30.0)
    # back: grip (vertical bar on two stand-offs) and forearm strap with a pad
    gy = GRIP_UP
    gb.cyl(0.016, 0.13, centre=(0.0, gy, -GRIP_BACK), axis="Y", segs=12, mat=edge)
    for dy in (-0.085, 0.085):
        gb.box((-0.018, gy + dy - 0.015, -GRIP_BACK - 0.012), (0.018, gy + dy + 0.015, 0.0), metal)
    sy = gy - 0.22
    gb.box((-0.075, sy - 0.03, -0.034), (0.075, sy + 0.03, -0.022), edge)
    for sx in (-1.0, 1.0):
        gb.box((sx * 0.075 - 0.012, sy - 0.03, -0.034), (sx * 0.075 + 0.012, sy + 0.03, 0.0), metal)
    gb.box((-0.06, sy - 0.06, -0.012), (0.06, sy + 0.06, 0.0), edge)
    gb.bevel(0.002, 1, 30.0)
    m.extend(gb.to_mesh(base))
    return m


def collision_points() -> list[Vector]:
    """Corners of the three panels (Blender coords) for the convex collision hull."""
    base = _to_blender()
    hh = HEIGHT / 2
    pts = []
    for x in (-W_CENTRE / 2, W_CENTRE / 2):
        for y in (-hh, hh):
            for z in (-0.004, THICK + 0.008):
                pts.append(base @ Vector((x, y, z)))
    for sx in (-1.0, 1.0):
        for y in (-hh, hh):
            for z in (-0.004, THICK + 0.006):
                pts.append(base @ _wing(sx) @ Vector((sx * (W_WING + 0.004), y, z)))
    return pts


def build_shield(ctx, colors: dict) -> None:
    import bmesh
    from lib import geo, scene, uv

    m = shield_mesh(colors["face"], colors["edge"], colors["letters"], colors["glass"], colors["metal"])
    me_name = "Visual"
    import bpy

    me = bpy.data.meshes.new(me_name)
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
    me.set_sharp_from_angle(angle=math.radians(32.0))
    me.validate(clean_customdata=False)
    me.update()
    obj = bpy.data.objects.new(me_name, me)
    scene.link(obj, None)
    mb = geo.MeshBuilder()
    verts = [mb.bm.verts.new(p) for p in collision_points()]
    bmesh.ops.convex_hull(mb.bm, input=verts)
    geo.collision_from_builder(mb, "convex")
    ctx.source_extra["tris"] = m.tris()
    ctx.source_extra["shield"] = (f"{W_CENTRE + 2 * W_WING * math.cos(math.radians(WING_DEG)):.3f} m wide x {HEIGHT:.2f} m; "
                                  f"pivot = grip centre, -Z (Godot) = face outward; face {GRIP_BACK + THICK:.3f} m in "
                                  f"front of the grip, shield centre {GRIP_UP:.2f} m below it")
    ctx.source_extra["word"] = WORD
