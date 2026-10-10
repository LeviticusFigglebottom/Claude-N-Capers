"""Shared materials, builder recipes and parametric parts for every weapon script (B1-03, B4-04).

Private helper (``_`` prefix): imported by the weapon helpers (``_p9.py``, ``_corsair.py`` ...),
never built.

Axes (docs/art/pipeline.md §6): Blender +Y = muzzle direction = Godot -Z; Blender +Z = up = Godot +Y;
Blender +X = Godot +X (the right side, where ejection ports are). Meters.

Pivot conventions for mod parts (contracts/visual_slots.md, data_schemas.md §Weapons): every mod is
built in the local frame of the marker it attaches to, so its glb snaps onto the marker:
* optics / iron sights: origin = bottom centre on the rail or slide top (``SightRail``), +Y forward;
* magazines: origin = centre of the magwell opening (``Magwell``), local +Z = insertion axis;
* muzzle devices / suppressors: origin = the muzzle (``Muzzle``) on the bore axis, extending +Y;
* foregrips / bipods: origin = the underside rail surface (``Underbarrel``), hanging along -Z;
* stocks: origin = the stock mount on the receiver rear (``StockMount``), extending -Y;
* barrels: origin = the barrel root on the bore (``BarrelMount``), extending +Y.
"""

from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from lib import geo, uv

FP_DENSITY = uv.DENSITY_FIRST_PERSON


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

    # B4-04 additions (requested from ENV C's library through the lead)
    def wood(self):
        return self.ctx.material("wood_veneer_walnut", "#5A3B28", roughness=0.55)

    def rubber(self):
        return self.ctx.material("rubber_black", "#232325", roughness=0.95)

    def tan(self):
        return self.ctx.material("polymer_tan", "#8A7A5C", roughness=0.7)

    def olive(self):
        return self.ctx.material("polymer_olive", "#4E5340", roughness=0.7)

    def alu(self):
        return self.ctx.material("alu_anodized_black", "#303235", roughness=0.45, metallic=0.9)

    def lens_dark(self):
        return self.ctx.material("glass_lens_coated", "#2F4A5E", roughness=0.04, metallic=0.2, alpha=0.55)


# --- builder recipes ---------------------------------------------------------------------------
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


def tris_of_scene() -> int:
    """LOD0 triangles of every visible mesh (same rule as lib.export.validate)."""
    from lib import naming, scene

    return sum(geo.tri_count(o) for o in scene.all_objects()
               if o.type == "MESH" and not naming.is_collision_name(o.name))


# --- B4-04: generic shape helpers --------------------------------------------------------------
def taper_x(mb: geo.MeshBuilder, fn) -> None:
    """Scale every vertex's x by ``fn(y, z)`` (organic widths for stocks, grips). Call before bevel."""
    for v in mb.bm.verts:
        v.co.x *= fn(v.co.y, v.co.z)


def rounded_rect(hw: float, hh: float, r: float, cx: float = 0.0, cy: float = 0.0,
                 corner_segments: int = 3) -> list[tuple[float, float]]:
    """Rounded rectangle loop (half width/height ``hw``/``hh``, corner radius ``r``)."""
    pts = []
    corners = ((hw - r, hh - r, 0.0), (-hw + r, hh - r, 90.0), (-hw + r, -hh + r, 180.0), (hw - r, -hh + r, 270.0))
    for x0, y0, a0 in corners:
        for i in range(corner_segments + 1):
            a = math.radians(a0 + 90.0 * i / corner_segments)
            pts.append((cx + x0 + r * math.cos(a), cy + y0 + r * math.sin(a)))
    return pts


def fluted(r_out: float, r_in: float, flutes: int, cx: float = 0.0, cy: float = 0.0) -> list[tuple[float, float]]:
    """Fluted barrel cross-section: ``flutes`` shallow grooves between full-radius lands."""
    pts = []
    for i in range(flutes * 4):
        a = 2 * math.pi * i / (flutes * 4)
        r = r_in if i % 4 == 2 else r_out
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def picatinny(mb: geo.MeshBuilder, mat: int, y0: float, y1: float, base_z: float, hw: float = 0.0105,
              pitch: float = 0.010, slot: float = 0.0052, height: float = 0.0062) -> None:
    """Top picatinny rail from ``y0`` to ``y1`` sitting on ``base_z``: spine + cross-slot lugs.
    Rail top surface = ``base_z + height``."""
    spine_top = base_z + height - 0.0028
    mb.prism([(-hw * 0.72, base_z), (hw * 0.72, base_z), (hw * 0.72, spine_top), (-hw * 0.72, spine_top)],
             axis="Y", start=y0, end=y1, mat=mat)
    lug_len = pitch - slot
    n = int((y1 - y0 - 0.002) // pitch)
    start = y0 + 0.5 * (y1 - y0 - (n * pitch - slot))
    # dovetail-ish lug: wide at mid height, chamfered top
    prof = [(-hw * 0.72, spine_top - 0.0015), (-hw, spine_top - 0.0002), (-hw, spine_top + 0.0012),
            (-hw * 0.8, base_z + height), (hw * 0.8, base_z + height), (hw, spine_top + 0.0012),
            (hw, spine_top - 0.0002), (hw * 0.72, spine_top - 0.0015)]
    for i in range(n):
        ya = start + i * pitch
        mb.prism(prof, axis="Y", start=ya, end=ya + lug_len, mat=mat)


def rail_side(mb: geo.MeshBuilder, mat: int, y0: float, y1: float, x: float, z: float, side: float,
              pitch: float = 0.010, slot: float = 0.0052) -> None:
    """Short side/bottom rail section approximated as lugs on a spine. ``side`` = +1 right, -1 left,
    0 = bottom (hanging under ``z``)."""
    lug = pitch - slot
    n = int((y1 - y0) // pitch)
    for i in range(n):
        ya = y0 + i * pitch
        if side == 0:
            mb.box((-0.0105, ya, z - 0.0062), (0.0105, ya + lug, z - 0.0028), mat=mat)
        else:
            lo, hi = sorted((x + side * 0.0028, x + side * 0.0062))
            mb.box((lo, ya, z - 0.0105), (hi, ya + lug, z + 0.0105), mat=mat)
    if side == 0:
        mb.box((-0.0076, y0, z - 0.0030), (0.0076, y0 + n * pitch - slot, z + 0.0005), mat=mat)
    else:
        lo, hi = sorted((x - side * 0.0005, x + side * 0.0030))
        mb.box((lo, y0, z - 0.0076), (hi, y0 + n * pitch - slot, z + 0.0076), mat=mat)


def raked_grip_profile(top_z: float, bottom_z: float, half_depth: float, angle_deg: float,
                       palm_swell: float = 0.002, finger_bumps: int = 0, y0: float = 0.0) -> list[tuple[float, float]]:
    """Side profile (y, z) of a raked pistol grip centred on y = ``y0`` at z = 0."""
    t = math.tan(math.radians(angle_deg))

    def front(z):
        return y0 + half_depth + t * z

    def back(z):
        return y0 - half_depth + t * z

    pts = [(front(top_z), top_z)]
    steps = 8
    for i in range(1, steps):
        z = top_z + (bottom_z - top_z) * i / steps
        bump = 0.0
        if finger_bumps:
            phase = (i / steps) * finger_bumps * math.pi
            bump = 0.0016 * abs(math.sin(phase))
        pts.append((front(z) + bump, z))
    pts.append((front(bottom_z) - 0.002, bottom_z))
    pts.append((back(bottom_z) - 0.003, bottom_z - 0.001))
    for i in range(steps - 1, 0, -1):
        z = top_z + (bottom_z - top_z) * i / steps
        swell = palm_swell * math.sin(math.pi * i / steps)
        pts.append((back(z) - swell, z))
    pts.append((back(top_z), top_z))
    return pts


# --- B4-04: parametric parts shared by several weapons ----------------------------------------
def build_can(ctx, mats: Mats, length: float, r: float, overlap: float = 0.0, parent=None,
              name: str = "Suppressor", bore_r: float = 0.0055, rings: int = 4, cap_style: str = "flat"):
    """Suppressor along +Y; origin = ``Muzzle``. ``overlap`` > 0 extends the tube backwards to slip
    over a flash hider / brake. Adds its own ``Muzzle`` marker at the front cap."""
    mb = ctx.builder()
    matte = mb.material(mats.matte())
    steel = mb.material(mats.steel())
    y_back = -overlap
    collar_len = 0.016
    # rear collar (mount) with grip rings
    mb.cylinder(r * 0.86, collar_len, segments=32, centre=(0.0, y_back + collar_len / 2, 0.0), axis="Y", mat=steel)
    for i in range(rings):
        mb.cylinder(r * 0.90, 0.0018, segments=32, centre=(0.0, y_back + 0.0025 + i * 0.0035, 0.0), axis="Y",
                    mat=steel)
    body0 = y_back + collar_len
    mb.cylinder(r, length - (body0), segments=40, centre=(0.0, (length + body0) / 2, 0.0), axis="Y", mat=steel)
    # two wrench-flat bands
    for y in (body0 + 0.012, length - 0.018):
        mb.cylinder(r + 0.0005, 0.006, segments=8, centre=(0.0, y, 0.0), axis="Y", mat=matte)
    body = finish(mb, name, bevel=0.0012, segments=2, parent=parent)
    cap = ctx.builder()
    cm = cap.material(mats.steel())
    ring_y(cap, r - 0.0012, bore_r, length, length + 0.004, 0.0, cm, segments=40)
    if cap_style == "teeth":
        for i in range(6):
            a = 2 * math.pi * i / 6
            cx, cz = math.cos(a) * (r - 0.004), math.sin(a) * (r - 0.004)
            cap.box((cx - 0.002, length + 0.004, cz - 0.002), (cx + 0.002, length + 0.008, cz + 0.002), mat=cm)
    dark = cap.material(mats.polymer())
    cap.cylinder(bore_r + 0.0001, 0.001, segments=24, centre=(0.0, length + 0.0015, 0.0), axis="Y", mat=dark)
    finish(cap, name + "Cap", bevel=0.0006, segments=1, parent=body)
    tip = length + (0.008 if cap_style == "teeth" else 0.004)
    ctx.marker("Muzzle", (0.0, tip, 0.0), parent=body)
    return body


def build_box_mag(ctx, mats: Mats, below: float, hw: float, hd: float, curve: float = 0.0, inside: float = 0.05,
                  mat_name: str = "polymer", round_r: float = 0.0045, ribs: int = 0, parent=None,
                  name: str = "Magazine", window: bool = False, base_drop: float = 0.006):
    """Box magazine in the ``Magwell`` frame: origin = magwell opening centre, +Z = insertion axis.
    ``below`` = length hanging out of the magwell, ``inside`` = length hidden in the well, ``curve`` =
    forward sweep of the bottom (m), ``hw``/``hd`` half width/depth."""
    mb = ctx.builder()
    body_mat = mb.material(getattr(mats, mat_name)())
    steps = 8
    front, back = [], []
    for i in range(steps + 1):
        s = i / steps
        z = inside - (inside + below) * s
        off = curve * s * s if z < 0 else 0.0
        front.append((hd + off, z))
        back.append((-hd + off, z))
    prof = front + list(reversed(back))
    mb.prism(prof, axis="X", start=-hw, end=hw, mat=body_mat)
    # floor plate
    bot = back[-1]
    fp_y = bot[0] + hd
    mb.box((-hw - 0.0012, fp_y - hd - 0.002, -below - base_drop), (hw + 0.0012, fp_y + hd + 0.002, -below + 0.0005),
           mat=body_mat)
    # ribs on the sides
    for i in range(ribs):
        s = (i + 1) / (ribs + 1)
        z = -below * s * 0.9
        off = curve * (z / -below) ** 2 if below > 0 else 0.0
        mb.box((-hw - 0.0008, -hd * 0.55 + off, z - 0.0012), (hw + 0.0008, hd * 0.55 + off, z + 0.0012), mat=body_mat)
    body = finish(mb, name, bevel=0.0012, segments=2, parent=parent)
    if window:
        wb = ctx.builder()
        wm = wb.material(mats.lens())
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * (hw + 0.0002), side * (hw + 0.0006)))
            wb.box((lo, -hd * 0.35, -below * 0.85), (hi, hd * 0.35, -below * 0.15), mat=wm)
        finish(wb, name + "Window", parent=body)
    rd = ctx.builder()
    br = rd.material(mats.brass())
    rd.cylinder(round_r, hd * 1.7, segments=16, centre=(0.0, -hd * 0.1, inside + round_r * 0.6), axis="Y", mat=br)
    finish(rd, name + "Round", bevel=0.0005, segments=1, parent=body)
    return body


def build_scope(ctx, mats: Mats, length: float, tube_r: float, obj_r: float, eye_r: float, ring_h: float,
                parent=None, name: str = "Scope", parallax: bool = False, ring_ys=(-0.045, 0.045),
                obj_len: float = 0.07, eye_len: float = 0.08):
    """Riflescope on two rings; origin = rail top centre (``SightRail``). Tube axis at z = ring_h.
    Adds ``AimPoint`` on the axis at the eyepiece (-Z down the bore)."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    rub = mb.material(mats.rubber())
    z = ring_h
    y_rear = -length * 0.45
    y_front = length * 0.55
    # eyepiece bell + rubber ring
    eye0, eye1 = y_rear, y_rear + eye_len
    mb.cylinder(eye_r, eye_len - 0.02, segments=36, centre=(0.0, eye0 + 0.02 + (eye_len - 0.02) / 2, z), axis="Y",
                mat=alu)
    mb.cylinder(eye_r + 0.001, 0.02, segments=36, centre=(0.0, eye0 + 0.01, z), axis="Y", mat=rub)
    # taper eyepiece -> tube
    _cone_y(mb, eye_r, tube_r, eye1, eye1 + 0.018, z, alu)
    # main tube
    t0, t1 = eye1 + 0.018, y_front - obj_len - 0.03
    mb.cylinder(tube_r, t1 - t0, segments=32, centre=(0.0, (t0 + t1) / 2, z), axis="Y", mat=alu)
    # objective taper + bell
    _cone_y(mb, tube_r, obj_r, t1, t1 + 0.03, z, alu)
    mb.cylinder(obj_r, obj_len, segments=40, centre=(0.0, y_front - obj_len / 2, z), axis="Y", mat=alu)
    # turret saddle + turrets
    sy = (t0 + t1) / 2
    mb.box((-tube_r - 0.002, sy - 0.018, z - tube_r * 0.8), (tube_r + 0.002, sy + 0.018, z + tube_r * 0.8), mat=alu)
    mb.cylinder(0.0115, 0.016, segments=24, centre=(0.0, sy, z + tube_r + 0.007), axis="Z", mat=alu)
    mb.cylinder(0.0115, 0.016, segments=24, centre=(tube_r + 0.007, sy, z), axis="X", mat=alu)
    if parallax:
        mb.cylinder(0.0125, 0.012, segments=24, centre=(-tube_r - 0.006, sy, z), axis="X", mat=alu)
    body = finish(mb, name, bevel=0.0008, segments=1, parent=parent)
    # turret knurl rings + rings/mounts
    rg = ctx.builder()
    mat = rg.material(mats.alu())
    rg.cylinder(0.0122, 0.004, segments=24, centre=(0.0, sy, z + tube_r + 0.013), axis="Z", mat=mat)
    rg.cylinder(0.0122, 0.004, segments=24, centre=(tube_r + 0.013, sy, z), axis="X", mat=mat)
    for ry in ring_ys:
        ring_y(rg, tube_r + 0.003, tube_r - 0.0002, ry - 0.008, ry + 0.008, z, mat, segments=32)
        rg.box((-0.010, ry - 0.008, 0.0), (0.010, ry + 0.008, z - tube_r + 0.0005), mat=mat)
        rg.box((0.006, ry - 0.007, 0.001), (0.0125, ry + 0.007, 0.010), mat=mat)   # clamp nut, right
    finish(rg, name + "Rings", bevel=0.0006, segments=1, parent=body)
    # lenses
    ln = ctx.builder()
    lm = ln.material(mats.lens_dark())
    ln.cylinder(obj_r - 0.002, 0.001, segments=32, centre=(0.0, y_front - 0.004, z), axis="Y", mat=lm)
    ln.cylinder(eye_r - 0.002, 0.001, segments=32, centre=(0.0, y_rear + 0.004, z), axis="Y", mat=lm)
    finish(ln, name + "Lens", parent=body)
    ctx.marker("AimPoint", (0.0, y_rear, z), parent=body)
    return body


def _cone_y(mb, r0, r1, y0, y1, z, mat, segments=32):
    a = circle(r0, segments, 0.0, z)
    b = circle(r1, segments, 0.0, z)
    bm = mb.bm
    va = [bm.verts.new((p[0], y0, p[1])) for p in a]
    vb = [bm.verts.new((p[0], y1, p[1])) for p in b]
    faces = []
    for i in range(segments):
        j = (i + 1) % segments
        f = bm.faces.new((va[i], va[j], vb[j], vb[i]))
        f.material_index = mat
        faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def build_rail_reflex(ctx, mats: Mats, parent=None, name: str = "ReflexSight"):
    """Tube-less open reflex on a picatinny clamp; origin = rail top centre. Adds ``AimPoint``."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    # clamp base
    mb.box((-0.0135, -0.022, 0.0), (0.0135, 0.022, 0.009), mat=alu)
    mb.box((0.0135, -0.010, 0.001), (0.0175, 0.010, 0.008), mat=alu)          # throw lever
    # housing: rear electronics + window frame
    mb.box((-0.0140, -0.022, 0.009), (0.0140, -0.006, 0.020), mat=alu)
    outer = [(-0.0165, 0.009), (0.0165, 0.009), (0.0165, 0.034), (0.0120, 0.041), (-0.0120, 0.041),
             (-0.0165, 0.034)]
    hole = [(-0.0130, 0.012), (-0.0130, 0.032), (-0.0095, 0.037), (0.0095, 0.037), (0.0130, 0.032),
            (0.0130, 0.012)]
    mb.prism(outer, holes=[hole], axis="Y", start=0.006, end=0.022, mat=alu)
    body = finish(mb, name, bevel=0.0009, segments=2, parent=parent)
    dt = ctx.builder()
    st = dt.material(mats.matte())
    dt.cylinder(0.0045, 0.006, segments=20, centre=(0.0150, -0.012, 0.016), axis="X", mat=st)   # brightness knob
    dt.cylinder(0.0035, 0.004, segments=16, centre=(0.0, -0.014, 0.022), axis="Z", mat=st)      # elevation cap
    finish(dt, name + "Details", bevel=0.0004, parent=body)
    ln = ctx.builder()
    lm = ln.material(mats.lens())
    ln.prism(hole, axis="Y", start=0.0135, end=0.0145, mat=lm)
    finish(ln, name + "Lens", parent=body)
    rt = ctx.builder()
    rm = rt.material(mats.reticle())
    dot_z = 0.0225
    rt.cylinder(0.0008, 0.0002, segments=12, centre=(0.0, 0.0128, dot_z), axis="Y", mat=rm)
    finish(rt, name + "Reticle", parent=body)
    ctx.marker("AimPoint", (0.0, 0.0128, dot_z), parent=body)
    return body


def build_prism_scope(ctx, mats: Mats, parent=None, name: str = "PrismScope"):
    """Compact fixed 3x prism sight (boxy body, short objective); origin = rail top centre."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    rub = mb.material(mats.rubber())
    axis_z = 0.040
    # mount
    mb.box((-0.0135, -0.030, 0.0), (0.0135, 0.030, 0.010), mat=alu)
    mb.box((0.0135, -0.012, 0.001), (0.0180, 0.012, 0.008), mat=alu)
    # prism housing: wedge-ish box
    prof = [(-0.034, 0.010), (0.040, 0.010), (0.040, 0.054), (0.020, 0.062), (-0.026, 0.062), (-0.034, 0.054)]
    mb.prism(prof, axis="X", start=-0.0175, end=0.0175, mat=alu)
    # objective + eyepiece
    mb.cylinder(0.0170, 0.030, segments=36, centre=(0.0, 0.055, axis_z), axis="Y", mat=alu)
    mb.cylinder(0.0160, 0.020, segments=36, centre=(0.0, -0.044, axis_z), axis="Y", mat=alu)
    mb.cylinder(0.0168, 0.010, segments=36, centre=(0.0, -0.059, axis_z), axis="Y", mat=rub)
    # turrets
    mb.cylinder(0.0090, 0.010, segments=20, centre=(0.0, 0.004, 0.066), axis="Z", mat=alu)
    mb.cylinder(0.0090, 0.010, segments=20, centre=(0.0215, 0.004, axis_z), axis="X", mat=alu)
    body = finish(mb, name, bevel=0.0010, segments=2, parent=parent)
    ln = ctx.builder()
    lm = ln.material(mats.lens_dark())
    ln.cylinder(0.0150, 0.001, segments=32, centre=(0.0, 0.0705, axis_z), axis="Y", mat=lm)
    ln.cylinder(0.0140, 0.001, segments=32, centre=(0.0, -0.0645, axis_z), axis="Y", mat=lm)
    finish(ln, name + "Lens", parent=body)
    ctx.marker("AimPoint", (0.0, -0.064, axis_z), parent=body)
    return body


def build_vertical_grip(ctx, mats: Mats, length: float = 0.075, parent=None, name: str = "Foregrip"):
    """Vertical foregrip; origin = underside rail surface (``Underbarrel``), hangs along -Z."""
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    mb.box((-0.0125, -0.020, -0.010), (0.0125, 0.020, 0.0), mat=poly)    # clamp
    prof = rounded_rect(0.0130, 0.0150, 0.008, corner_segments=3)
    mb.prism(prof, axis="Z", start=-length, end=-0.008, mat=poly)
    # finger grooves on the front
    for i in range(3):
        z = -0.025 - i * 0.016
        mb.box((-0.010, 0.013, z - 0.003), (0.010, 0.0165, z + 0.003), mat=poly)
    mb.cylinder(0.0145, 0.006, segments=24, centre=(0.0, 0.0, -length - 0.002), axis="Z", mat=poly)
    return finish(mb, name, bevel=0.0015, segments=2, parent=parent)


def build_bipod(ctx, mats: Mats, leg_len: float = 0.17, parent=None, name: str = "Bipod"):
    """Folded-forward bipod on a rail clamp; origin = underside rail surface (``Underbarrel``)."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    rub = mb.material(mats.rubber())
    mb.box((-0.015, -0.020, -0.014), (0.015, 0.020, 0.0), mat=alu)               # clamp + hinge block
    mb.cylinder(0.006, 0.040, segments=16, centre=(0.0, 0.012, -0.012), axis="X", mat=alu)   # hinge pin
    for side in (-1.0, 1.0):
        x = side * 0.0145
        # legs folded forward, slightly angled down
        mb.box((x - 0.0045, 0.010, -0.022), (x + 0.0045, 0.010 + leg_len, -0.012), mat=alu)
        mb.box((x - 0.0035, 0.010 + leg_len, -0.021), (x + 0.0035, 0.010 + leg_len + 0.05, -0.013), mat=alu)
        mb.cylinder(0.0065, 0.016, segments=16, centre=(x, 0.018 + leg_len + 0.05, -0.017), axis="Y", mat=rub)
    return finish(mb, name, bevel=0.0010, segments=1, parent=parent)


def build_flipup_irons(ctx, mats: Mats, rear_y: float, front_y: float, front_base_z: float,
                       sight_h: float = 0.016, parent=None, name: str = "IronSights"):
    """Flip-up rear aperture at ``rear_y`` (on the rail top, z = 0) and a front post at ``front_y`` whose
    base sits at ``front_base_z`` (relative to the rail top). Origin = rail top centre (``SightRail``).
    Returns (body, aim_z) where aim_z = sight-line height above the rail top."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    aim_z = sight_h
    # rear: base clamp + ear protectors + aperture disc
    y = rear_y
    mb.box((-0.0130, y - 0.012, 0.0), (0.0130, y + 0.012, 0.006), mat=alu)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0085, side * 0.0125))
        mb.box((lo, y - 0.006, 0.006), (hi, y + 0.004, aim_z + 0.006), mat=alu)
    ap_outer = circle(0.0060, 20, 0.0, aim_z)
    ap_hole = list(reversed(circle(0.0018, 12, 0.0, aim_z)))
    mb.prism(ap_outer, holes=[ap_hole], axis="Y", start=y - 0.0015, end=y + 0.0015, mat=alu)
    mb.box((-0.0045, y - 0.0015, 0.006), (0.0045, y + 0.0015, aim_z - 0.004), mat=alu)
    # front: clamp + protective ears + post
    y = front_y
    z0 = front_base_z
    mb.box((-0.0130, y - 0.012, z0), (0.0130, y + 0.012, z0 + 0.006), mat=alu)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0070, side * 0.0110))
        mb.box((lo, y - 0.007, z0 + 0.006), (hi, y + 0.007, aim_z + 0.004), mat=alu)
    mb.box((-0.0012, y - 0.0015, z0 + 0.006), (0.0012, y + 0.0015, aim_z), mat=alu)
    body = finish(mb, name, bevel=0.0005, segments=1, parent=parent)
    return body, aim_z
