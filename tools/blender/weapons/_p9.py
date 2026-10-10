"""Shared dimensions, materials and part builders for the Halvard Arms Kestrel P9 (B1-03).

Private helper (``_`` prefix): imported by ``kestrel_p9.py`` and ``kestrel_p9_mods.py``, never built.

Axes (docs/art/pipeline.md §6): Blender +Y = muzzle direction = Godot -Z; Blender +Z = up = Godot +Y;
Blender +X = Godot +X (the right side, where the ejection port is). Meters.

Base-model origin = the firing-hand pivot: on the grip's centre plane (x = 0), centred front-to-back
in the grip, 20 mm below the top of the grip (roughly where the palm centre and middle finger sit).
The grip is raked GRIP_ANGLE_DEG back; at z = 0 its front strap is +GRIP_HALF_DEPTH and its back strap
-GRIP_HALF_DEPTH in y.

Mod pivots = their attach point, built in the local frame of their marker:
* sights: origin = bottom centre on the slide top (``SightRail``), +Y forward, +Z up;
* magazines: origin = centre of the magwell opening (``Magwell``); local +Z = insertion axis (up the
  grip), local +Y forward. ``Magwell`` is rotated by -GRIP_ANGLE_DEG about X so mags follow the rake;
* muzzle devices: origin = the barrel crown on the bore axis (``Muzzle``), extending along +Y.
"""

from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from lib import geo, uv

# --- overall dimensions (meters) ---------------------------------------------------------------
GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_HALF_DEPTH = 0.022          # 44 mm grip depth at the hand
GRIP_HALF_WIDTH = 0.0150         # 30 mm grip width
GRIP_TOP_Z = 0.020
GRIP_BOTTOM_Z = -0.070           # magwell centre height; the grip bottom is square to the rake

FRAME_HALF_WIDTH = 0.0118
FRAME_TOP_Z = 0.036
FRAME_BOTTOM_Z = 0.020
FRAME_FRONT_Y = 0.132

SLIDE_HALF_WIDTH = 0.0128
SLIDE_REAR_Y = -0.040
SLIDE_FRONT_Y = 0.140            # 180 mm slide = overall length
SLIDE_BOTTOM_Z = 0.033
SLIDE_TOP_Z = 0.063

BORE_Z = 0.048
BARREL_RADIUS = 0.0068
BORE_RADIUS = 0.0046
BARREL_REAR_Y = -0.020
MUZZLE_Y = 0.1425                # barrel crown stands 2.5 mm proud of the slide

SIGHT_RAIL_Y = -0.030            # rear-sight dovetail / optic cut centre on the slide top
FRONT_SIGHT_Y = 0.128
SIGHT_LINE_DZ = 0.0035           # sight line height above the slide top (notch bottom = post top)

RAIL_FRONT_Y = 0.128
RAIL_REAR_Y = 0.082
RAIL_BOTTOM_Z = 0.0145

MAG_HALF_WIDTH = 0.0110
MAG_HALF_DEPTH = 0.0160
MAG_BODY_LEN = 0.090             # standard 17-round body (hidden in the grip, visible on reloads)
EXT_MAG_EXTRA = 0.034            # +8 rounds of double stack below the grip

FP_DENSITY = uv.DENSITY_FIRST_PERSON


def grip_front_y(z: float) -> float:
    return GRIP_HALF_DEPTH + GRIP_TAN * z


def grip_back_y(z: float) -> float:
    return -GRIP_HALF_DEPTH + GRIP_TAN * z


def grip_mid_y(z: float) -> float:
    return GRIP_TAN * z


GRIP_COS = math.cos(math.radians(GRIP_ANGLE_DEG))
GRIP_SIN = math.sin(math.radians(GRIP_ANGLE_DEG))
GRIP_PERP_HALF = GRIP_HALF_DEPTH * GRIP_COS   # half grip depth measured square to the rake


def grip_bottom_point(s: float) -> tuple[float, float]:
    """(y, z) on the grip bottom, ``s`` metres forward of the magwell centre, square to the rake."""
    return (grip_mid_y(GRIP_BOTTOM_Z) + s * GRIP_COS, GRIP_BOTTOM_Z - s * GRIP_SIN)


MAGWELL_POS = (0.0, grip_mid_y(GRIP_BOTTOM_Z), GRIP_BOTTOM_Z)
MAGWELL_ROT = (-math.radians(GRIP_ANGLE_DEG), 0.0, 0.0)


# --- materials ---------------------------------------------------------------------------------
class Mats:
    """Material slots M_<library_id>. Flat colours are the sRGB placeholders shown in Godot until the
    shared library (game/world/materials/<id>.tres, ENV C) provides the real PBR material."""

    def __init__(self, ctx) -> None:
        self.ctx = ctx

    def polymer(self):
        return self.ctx.material("polymer_black", "#2B2C2E", roughness=0.62)

    def stipple(self):
        return self.ctx.material("polymer_stipple", "#252628", roughness=0.92)

    def steel(self):
        return self.ctx.material("steel_blued", "#3A3D42", roughness=0.36, metallic=1.0)

    def bare(self):
        return self.ctx.material("steel_bare", "#8C8E91", roughness=0.28, metallic=1.0)

    def matte(self):
        return self.ctx.material("metal_matte", "#4A4C50", roughness=0.58, metallic=0.85)

    def dot(self):
        return self.ctx.material("paint_white", "#D8D8D2", roughness=0.5)

    def brass(self):
        return self.ctx.material("brass_cartridge", "#B48F3E", roughness=0.3, metallic=1.0)

    def lens(self):
        return self.ctx.material("glass_lens_tint", "#6E9A8E", roughness=0.05, metallic=0.0, alpha=0.3)

    def reticle(self):
        mat = self.ctx.material("emissive_reticle_red", "#FF2A1E", roughness=0.4)
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Emission Color"].default_value = (1.0, 0.03, 0.015, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
        return mat


# --- builder helpers ---------------------------------------------------------------------------
def finish(mb: geo.MeshBuilder, name: str, bevel: float = 0.0, segments: int = 1, parent=None,
           angle_deg: float = 30.0):
    """Recipe: chamfer first, then UVs (determinism), then sharp edges + weighted normals."""
    if bevel > 0:
        mb.bevel(bevel, segments=segments, angle_deg=angle_deg)
    uv.box_project(mb.bm, density=FP_DENSITY)
    obj = mb.to_object(name, parent)
    geo.finish_hard_surface(obj)
    return obj


def finish_object_uv(obj):
    """UV + shading for an object whose mesh was edited after to_object (booleans)."""
    uv.box_project_object(obj, density=FP_DENSITY)
    geo.finish_hard_surface(obj)
    return obj


def circle(r: float, n: int, cx: float = 0.0, cy: float = 0.0) -> list[tuple[float, float]]:
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def ring_y(mb: geo.MeshBuilder, r_out: float, r_in: float, y0: float, y1: float, z: float, mat: int,
           segments: int = 32) -> None:
    """Tube along Y (bore axis at x=0, height z) with an open bore."""
    outer = circle(r_out, segments, 0.0, z)
    hole = list(reversed(circle(r_in, segments, 0.0, z)))
    mb.prism(outer, holes=[hole], axis="Y", start=y0, end=y1, mat=mat)


def pyramid(bm, base_centre: Vector, u: Vector, v: Vector, n: Vector, half: float, height: float,
            mat: int) -> None:
    """Four-sided stipple bump: square base (``u``/``v`` half-extents) pushed out along ``n``."""
    c = base_centre
    corners = [c + (u * a + v * b) * half for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    vs = [bm.verts.new(p) for p in corners]
    tip = bm.verts.new(c + n * height)
    for i in range(4):
        f = bm.faces.new((vs[i], vs[(i + 1) % 4], tip))
        f.material_index = mat
    # make sure normals face out of the grip (along n)
    for f in tip.link_faces:
        f.normal_update()
        if f.normal.dot(n) < 0:
            f.normal_flip()


def stipple_patch(mb: geo.MeshBuilder, rng, mat: int, side: float, x: float, z0: float, z1: float,
                  front_inset: float, back_inset: float, pitch: float = 0.0024) -> None:
    """Grid of jittered pyramids on a raked grip side face at ``x`` (side = +1 right, -1 left)."""
    n = Vector((side, 0.0, 0.0))
    u = Vector((0.0, 1.0, 0.0))
    v = Vector((0.0, 0.0, 1.0))
    rows = int((z1 - z0) / pitch)
    for r in range(rows + 1):
        z = z0 + r * pitch
        y_lo = grip_back_y(z) + back_inset
        y_hi = grip_front_y(z) - front_inset
        cols = int((y_hi - y_lo) / pitch)
        stagger = (pitch * 0.5) if r % 2 else 0.0
        for c in range(cols + 1):
            y = y_lo + c * pitch + stagger
            if y > y_hi:
                continue
            jy = (rng.random() - 0.5) * 0.0004
            jz = (rng.random() - 0.5) * 0.0004
            h = 0.00035 + rng.random() * 0.0002
            pyramid(mb.bm, Vector((x, y + jy, z + jz)), u, v, n, 0.00075, h, mat)


# --- parts shared by base and mods -------------------------------------------------------------
def build_rear_sight(ctx, mats: Mats, parent=None, name: str = "RearSightMesh"):
    """Three-dot rear sight; origin = bottom centre (sits on the slide top at SightRail)."""
    mb = ctx.builder()
    steel = mb.material(mats.steel())
    notch_half = 0.0016
    profile = [(-0.0075, 0.0), (0.0075, 0.0), (0.0075, 0.0065), (notch_half, 0.0065),
               (notch_half, SIGHT_LINE_DZ), (-notch_half, SIGHT_LINE_DZ), (-notch_half, 0.0065),
               (-0.0075, 0.0065)]
    mb.prism(profile, axis="Y", start=-0.0050, end=0.0045, mat=steel)
    mb.box((-0.0085, -0.0050, -0.0010), (0.0085, 0.0045, 0.0005), mat=steel)   # dovetail foot
    body = finish(mb, name, bevel=0.0004, segments=1, parent=parent)
    dots = ctx.builder()
    d = dots.material(mats.dot())
    for x in (-0.0044, 0.0044):
        dots.cylinder(0.0010, 0.0006, segments=12, centre=(x, -0.0051, SIGHT_LINE_DZ - 0.0015), axis="Y", mat=d)
    finish(dots, name + "Dots", parent=body)
    return body


def build_magazine(ctx, mats: Mats, extended: bool, parent=None, name: str = "MagazineMesh"):
    """Magazine in the Magwell frame: origin = magwell opening centre, +Z = insertion axis."""
    extra = EXT_MAG_EXTRA if extended else 0.0
    mb = ctx.builder()
    steel = mb.material(mats.steel())
    poly = mb.material(mats.polymer())
    # body: tube from below the opening up into the grip (hidden while seated, seen on reloads)
    mb.box((-MAG_HALF_WIDTH, -MAG_HALF_DEPTH, -extra), (MAG_HALF_WIDTH, MAG_HALF_DEPTH, MAG_BODY_LEN), mat=steel)
    # feed lips
    for x in (-MAG_HALF_WIDTH + 0.0012, MAG_HALF_WIDTH - 0.0012):
        mb.box((x - 0.0012, -MAG_HALF_DEPTH, MAG_BODY_LEN), (x + 0.0012, MAG_HALF_DEPTH - 0.004, MAG_BODY_LEN + 0.003),
               mat=steel)
    if extended:
        # grip-matching sleeve that continues the frame below the magwell
        z0 = -extra
        sleeve = [(-GRIP_PERP_HALF + 0.0005, z0), (GRIP_PERP_HALF - 0.0005, z0),
                  (GRIP_PERP_HALF, 0.0), (-GRIP_PERP_HALF, 0.0)]
        mb.prism(sleeve, axis="X", start=-GRIP_HALF_WIDTH + 0.0003, end=GRIP_HALF_WIDTH - 0.0003, mat=poly)
        base_z = z0
    else:
        base_z = 0.0
    # base pad with a pull lip at the front
    mb.box((-GRIP_HALF_WIDTH + 0.0006, -GRIP_PERP_HALF + 0.0015, base_z - 0.006),
           (GRIP_HALF_WIDTH - 0.0006, GRIP_PERP_HALF - 0.0005, base_z), mat=poly)
    mb.box((-0.009, GRIP_PERP_HALF - 0.004, base_z - 0.0075), (0.009, GRIP_PERP_HALF + 0.0015, base_z - 0.002),
           mat=poly)
    body = finish(mb, name, bevel=0.0012, segments=2, parent=parent)
    if extended:
        st = ctx.builder()
        sm = st.material(mats.stipple())
        for side in (-1.0, 1.0):
            _ext_stipple(st, ctx.rng, sm, side, -extra + 0.004, -0.004)
        finish(st, name + "Texture", parent=body)
    # the top cartridge
    rd = ctx.builder()
    br = rd.material(mats.brass())
    rd.cylinder(0.0048, 0.0190, segments=16, centre=(0.0, -0.0020, MAG_BODY_LEN + 0.0035), axis="Y", mat=br)
    rd.cylinder(0.0045, 0.0080, segments=16, centre=(0.0, 0.0115, MAG_BODY_LEN + 0.0035), axis="Y", mat=br)
    finish(rd, name + "Round", bevel=0.0006, segments=1, parent=body)
    return body


def _ext_stipple(mb, rng, mat, side, z0, z1, pitch=0.0024):
    n = Vector((side, 0.0, 0.0))
    u = Vector((0.0, 1.0, 0.0))
    v = Vector((0.0, 0.0, 1.0))
    x = side * (GRIP_HALF_WIDTH - 0.0003)
    rows = int((z1 - z0) / pitch)
    for r in range(rows + 1):
        z = z0 + r * pitch
        y = -GRIP_PERP_HALF + 0.006 + (pitch * 0.5 if r % 2 else 0.0)
        while y < GRIP_PERP_HALF - 0.006:
            jy = (rng.random() - 0.5) * 0.0004
            pyramid(mb.bm, Vector((x, y + jy, z)), u, v, n, 0.00075, 0.00035 + rng.random() * 0.0002, mat)
            y += pitch


def build_reflex(ctx, mats: Mats, parent=None, name: str = "ReflexBody"):
    """Open reflex sight on a slide plate; origin = bottom centre on the slide top. Adds ``AimPoint``."""
    mb = ctx.builder()
    matte = mb.material(mats.matte())
    y0, y1 = -0.008, 0.033
    # base plate / housing
    mb.box((-0.0125, y0, 0.0), (0.0125, y1, 0.0065), mat=matte)
    # rear electronics block (low, so the window is visible over it)
    mb.box((-0.0120, y0, 0.0065), (0.0120, y0 + 0.010, 0.0110), mat=matte)
    # hood: window frame with an opening, tapered toward the top
    outer = [(-0.0125, 0.0065), (0.0125, 0.0065), (0.0118, 0.0200), (0.0095, 0.0262), (0.0, 0.0285),
             (-0.0095, 0.0262), (-0.0118, 0.0200)]
    hole = [(-0.0095, 0.0085), (-0.0099, 0.0190), (-0.0078, 0.0238), (0.0, 0.0255), (0.0078, 0.0238),
            (0.0099, 0.0190), (0.0095, 0.0085)]
    mb.prism(outer, holes=[hole], axis="Y", start=y1 - 0.013, end=y1, mat=matte)
    body = finish(mb, name, bevel=0.0009, segments=2, parent=parent)
    # details: emitter, screws, adjustment caps
    dt = ctx.builder()
    m2 = dt.material(mats.steel())
    dt.box((-0.0022, y0 + 0.010, 0.0065), (0.0022, y0 + 0.014, 0.0095), mat=m2)          # LED emitter
    for x in (-0.0080, 0.0080):                                                            # mount screws
        dt.cylinder(0.0018, 0.0008, segments=12, centre=(x, 0.0100, 0.0069), axis="Z", mat=m2)
    dt.cylinder(0.0028, 0.0012, segments=16, centre=(0.0, y0 + 0.005, 0.0114), axis="Z", mat=m2)  # battery cap
    dt.cylinder(0.0020, 0.0012, segments=12, centre=(0.0124, y0 + 0.006, 0.0085), axis="X", mat=m2)  # windage
    finish(dt, name + "Details", bevel=0.0003, parent=body)
    # lens (tinted, transparent)
    ln = ctx.builder()
    lm = ln.material(mats.lens())
    lens_y = y1 - 0.0065
    ln.prism(hole, axis="Y", start=lens_y - 0.0004, end=lens_y + 0.0004, mat=lm)
    finish(ln, "ReflexLens", parent=body)
    # reticle dot, just behind the lens (facing the shooter)
    dot_z = 0.0170
    rt = ctx.builder()
    rm = rt.material(mats.reticle())
    rt.cylinder(0.00065, 0.0002, segments=12, centre=(0.0, lens_y - 0.0006, dot_z), axis="Y", mat=rm)
    finish(rt, "Reticle", parent=body)
    ctx.marker("AimPoint", (0.0, lens_y - 0.0006, dot_z), parent=body)
    return body


def build_suppressor(ctx, mats: Mats, parent=None, name: str = "SuppressorBody"):
    """Can along +Y; origin = barrel crown on the bore. Adds a ``Muzzle`` marker at its front."""
    length = 0.150
    r = 0.0140
    mb = ctx.builder()
    matte = mb.material(mats.matte())
    steel = mb.material(mats.steel())
    # threaded collar with grip rings
    mb.cylinder(0.0100, 0.012, segments=32, centre=(0.0, 0.006, 0.0), axis="Y", mat=steel)
    for i in range(4):
        mb.cylinder(0.0106, 0.0016, segments=32, centre=(0.0, 0.0018 + i * 0.0028, 0.0), axis="Y", mat=steel)
    # main tube
    mb.cylinder(r, length - 0.012, segments=40, centre=(0.0, 0.012 + (length - 0.012) / 2, 0.0), axis="Y",
                mat=matte)
    # wrench flats band near the front
    mb.cylinder(r + 0.0004, 0.006, segments=8, centre=(0.0, length - 0.016, 0.0), axis="Y", mat=matte)
    body = finish(mb, name, bevel=0.0012, segments=2, parent=parent)
    cap = ctx.builder()
    cm = cap.material(mats.steel())
    ring_y(cap, r - 0.0012, 0.0052, length, length + 0.004, 0.0, cm, segments=40)
    dark = cap.material(mats.polymer())
    cap.cylinder(0.0053, 0.001, segments=24, centre=(0.0, length + 0.0015, 0.0), axis="Y", mat=dark)
    finish(cap, name + "Cap", bevel=0.0006, segments=1, parent=body)
    ctx.marker("Muzzle", (0.0, length + 0.004, 0.0), parent=body)
    return body


def tris_of_scene() -> int:
    """LOD0 triangles of every visible mesh (same rule as lib.export.validate)."""
    from lib import naming, scene

    return sum(geo.tri_count(o) for o in scene.all_objects()
               if o.type == "MESH" and not naming.is_collision_name(o.name))
