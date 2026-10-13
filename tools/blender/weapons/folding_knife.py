"""Folding knife (melee.folding_knife, the loadout default melee): first-person item model (PO-4).

Original design: a compact modern folding knife shown open. 110 mm handle (two dark polymer scales on
steel liners, back spacer, lanyard tube, pocket clip on the right scale), a 3 mm drop-point blade with
a flat grind, about 82 mm of it out of the handle, and a thumb stud on both blade flats.

Item contract (contracts/visual_slots.md "Items", D-069), expressed in Blender axes:
* origin on the handle axis 20 mm below the top of the fist (the index finger rests in the finger
  groove just under the pivot);
* handle along Godot +Y = Blender +Z (the blade points up from the fist);
* cutting edge toward Godot -Z = Blender +Y, spine toward Blender -Y;
* Blender +X = Godot +X = the blade flat normal (pocket-clip side).

Nodes (Godot names): ``Handle`` (scales) with ``GripPanels``; ``Frame`` (liners, back spacer, lanyard
tube) with ``Hardware`` (pivot, scale screws, pocket clip); ``Blade`` (tang, jimping, flat-ground blade)
with ``ThumbStud``. No markers. Previews: game/assets/weapons/folding_knife_preview_*.png.
"""

import math

import bmesh

import _common as c

ASSET_ID = "wpn_melee_folding_knife"
TRI_BUDGET = 6000

# --- dimensions (meters, Blender axes) ---------------------------------------------------------
PIVOT = (0.001, 0.016)          # (y, z) of the pivot axis
BLADE_HALF_T = 0.0015           # 3 mm blade stock
LINER_OUT = 0.0027              # liner outer face (x)
SCALE_OUT = 0.0062              # scale outer face (x): 12.4 mm handle thickness
SPINE_Y = -0.0105
EDGE_Y = 0.0125
HEEL_Z = 0.029                  # blade leaves the tang / plunge
TIP = (-0.0030, 0.1105)         # (y, z)
DROP_Z = 0.076                  # spine starts dropping to the tip
BELLY_Z = 0.050                 # edge starts sweeping up to the tip
GRIND = 0.42                    # flat-grind line, fraction of the width from the spine
EDGE_HALF_T = 0.00018
LANYARD = (-0.0015, -0.0800)
LANYARD_R = 0.0028


def _arc(cy: float, cz: float, r: float, a0: float, a1: float, n: int) -> list[tuple[float, float]]:
    return [(cy + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def handle_profile() -> list[tuple[float, float]]:
    """Side outline (y, z) of the handle, counter-clockwise from the edge side under the pivot."""
    top = _arc(PIVOT[0], PIVOT[1], 0.0125, 0.0, 180.0, 10)          # rounded head around the pivot
    spine = [(-0.0117, 0.002), (-0.0121, -0.030), (-0.0120, -0.060), (-0.0112, -0.077)]
    butt = [(-0.0085, -0.0870), (-0.0035, -0.0905), (0.0030, -0.0905), (0.0085, -0.0868)]
    edge = [(0.0118, -0.078), (0.0130, -0.062), (0.0131, -0.040), (0.0124, -0.018),
            (0.0112, -0.008), (0.0096, 0.000), (0.0093, 0.006), (0.0101, 0.011)]
    return top + spine + butt + edge


def _scale_inset(pts, k: float = 0.035):
    """Scale outline slightly inside the liner outline so a thin liner line shows all round."""
    cy, cz = 0.0007, -0.036
    return [(cy + (y - cy) * (1.0 - k), cz + (z - cz) * (1.0 - k * 0.12)) for y, z in pts]


def spine_y(z: float) -> float:
    if z <= DROP_Z:
        return SPINE_Y
    u = min(1.0, (z - DROP_Z) / (TIP[1] - DROP_Z))
    return SPINE_Y + (TIP[0] - SPINE_Y) * (1.0 - math.sqrt(max(0.0, 1.0 - u * u)))


def edge_y(z: float) -> float:
    if z <= BELLY_Z:
        return EDGE_Y
    u = min(1.0, (z - BELLY_Z) / (TIP[1] - BELLY_Z))
    return EDGE_Y + (TIP[0] - EDGE_Y) * (1.0 - math.sqrt(max(0.0, 1.0 - u * u)))


def _blade_loft(mb, flat: int, bevel: int, edge: int) -> None:
    """Blade from the heel to the tip as a loft of 6-vertex cross-sections (spine flats, grind bevels,
    edge) with a plunge at the heel and a little distal taper, closed by a tip vertex."""
    bm = mb.bm
    zs = [HEEL_Z, HEEL_Z + 0.004]
    n = 16
    for i in range(1, n + 1):
        u = i / n
        zs.append(HEEL_Z + 0.004 + (TIP[1] - 0.0012 - HEEL_Z - 0.004) * (1.0 - (1.0 - u) ** 1.6))
    rings = []
    for k, z in enumerate(zs):
        s, e = spine_y(z), edge_y(z)
        t = (z - HEEL_Z) / (TIP[1] - HEEL_Z)
        h = BLADE_HALF_T * (1.0 - 0.45 * t)
        if k == 0:                       # plunge: full stock thickness right at the heel
            g, he = e - 0.0008, h
        else:
            g, he = s + GRIND * (e - s), EDGE_HALF_T
        loop = [(-h, s), (-h, g), (-he, e), (he, e), (h, g), (h, s)]
        rings.append([bm.verts.new((x, y, z)) for x, y in loop])
    face_mat = [flat, bevel, edge, bevel, flat, flat]   # side between loop[i] and loop[i+1]
    for a, b in zip(rings, rings[1:]):
        for i in range(6):
            j = (i + 1) % 6
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = face_mat[i]
    f = bm.faces.new(list(reversed(rings[0])))
    f.material_index = flat
    tip = bm.verts.new((0.0, TIP[0], TIP[1]))
    last = rings[-1]
    for i in range(6):
        f = bm.faces.new((last[i], last[(i + 1) % 6], tip))
        f.material_index = face_mat[i]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def _blade(ctx, mats, steel_satin, steel_edge):
    mb = ctx.builder()
    flat = mb.material(steel_satin)
    bev = mb.material(steel_edge)
    # tang: rounded around the pivot, full thickness, mostly hidden between the liners
    tang = [(EDGE_Y, HEEL_Z), (SPINE_Y, HEEL_Z), (SPINE_Y, PIVOT[1])]
    tang += _arc(PIVOT[0], PIVOT[1], 0.0115, 180.0, 360.0, 10)[1:]
    tang += [(EDGE_Y, PIVOT[1] + 0.002), (EDGE_Y - 0.0018, PIVOT[1] + 0.0060), (EDGE_Y - 0.0012, HEEL_Z - 0.0035)]
    mb.prism(tang, axis="X", start=-BLADE_HALF_T, end=BLADE_HALF_T, mat=flat)
    # thumb-ramp jimping on the spine just above the handle
    for i in range(6):
        z = HEEL_Z + 0.0020 + i * 0.0024
        mb.box((-BLADE_HALF_T + 0.0002, SPINE_Y - 0.0006, z), (BLADE_HALF_T - 0.0002, SPINE_Y + 0.0004, z + 0.0012),
               mat=flat)
    _blade_loft(mb, flat, bev, bev)
    blade = c.finish(mb, "Blade")

    # thumb stud through the blade, both flats
    st = ctx.builder()
    sm = st.material(mats.matte())
    st.cylinder(0.0021, 2 * 0.0046, segments=16, centre=(0.0, -0.0050, HEEL_Z + 0.0055), axis="X", mat=sm)
    st.cylinder(0.0014, 2 * 0.0052, segments=12, centre=(0.0, -0.0050, HEEL_Z + 0.0055), axis="X", mat=sm)
    c.finish(st, "ThumbStud", bevel=0.0004, segments=1, parent=blade)
    return blade


def _handle(ctx, mats):
    prof = handle_profile()
    hole = list(reversed(c.circle(LANYARD_R, 16, LANYARD[0], LANYARD[1])))
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    sc = _scale_inset(prof)
    for side in (-1.0, 1.0):
        a, b = side * LINER_OUT, side * SCALE_OUT
        mb.prism(sc, holes=[hole], axis="X", start=min(a, b), end=max(a, b), mat=poly)
    handle = c.finish(mb, "Handle", bevel=0.0010, segments=2)

    # grip panels: slightly raised textured-material inserts on both scales
    gp = ctx.builder()
    gm = gp.material(mats.stipple())
    panel = c.rounded_rect(0.0072, 0.0215, 0.0040, cx=0.0012, cy=-0.042, corner_segments=3)
    for side in (-1.0, 1.0):
        a, b = side * (SCALE_OUT - 0.0004), side * (SCALE_OUT + 0.00035)
        gp.prism(panel, axis="X", start=min(a, b), end=max(a, b), mat=gm)
        # three shallow grip ribs across the panel
        for i in range(3):
            z = -0.056 + i * 0.014
            lo, hi = sorted((side * (SCALE_OUT + 0.0002), side * (SCALE_OUT + 0.0008)))
            gp.box((lo, -0.0050, z - 0.0011), (hi, 0.0075, z + 0.0011), mat=gm)
    c.finish(gp, "GripPanels", bevel=0.00025, segments=1, parent=handle)
    return handle


def _frame(ctx, mats, steel_edge):
    prof = handle_profile()
    hole = list(reversed(c.circle(LANYARD_R, 16, LANYARD[0], LANYARD[1])))
    mb = ctx.builder()
    liner = mb.material(mats.matte())
    for side in (-1.0, 1.0):
        a, b = side * BLADE_HALF_T, side * LINER_OUT
        mb.prism(prof, holes=[hole], axis="X", start=min(a, b), end=max(a, b), mat=liner)
    # back spacer closing the spine side, lanyard tube between the liners
    spacer = [(-0.0117, 0.0015), (-0.0084, 0.0015), (-0.0084, -0.0745), (-0.0095, -0.0790), (-0.0112, -0.0770),
              (-0.0121, -0.060), (-0.0121, -0.030)]
    poly = mb.material(mats.polymer())
    mb.prism(spacer, axis="X", start=-BLADE_HALF_T, end=BLADE_HALF_T, mat=poly)
    tube_out = c.circle(LANYARD_R + 0.0012, 16, LANYARD[0], LANYARD[1])
    mb.prism(tube_out, holes=[hole], axis="X", start=-BLADE_HALF_T, end=BLADE_HALF_T, mat=liner)
    frame = c.finish(mb, "Frame", bevel=0.0002, segments=1)

    # pivot collar + screw heads (both sides), scale screws, pocket clip on the right (+X)
    hw = ctx.builder()
    hm = hw.material(mats.matte())
    hb = hw.material(steel_edge)
    hw.cylinder(0.0056, 2 * (SCALE_OUT + 0.0006), segments=20, centre=(0.0, PIVOT[0], PIVOT[1]), axis="X", mat=hm)
    hw.cylinder(0.0030, 2 * (SCALE_OUT + 0.0010), segments=12, centre=(0.0, PIVOT[0], PIVOT[1]), axis="X", mat=hb)
    for y, z in ((0.0040, -0.0130), (0.0020, -0.0700)):
        hw.cylinder(0.0019, 2 * (SCALE_OUT + 0.0004), segments=10, centre=(0.0, y, z), axis="X", mat=hm)
    clip = [(-0.0128, -0.0880), (-0.0040, -0.0880), (-0.0040, -0.0700), (-0.0072, -0.0640), (-0.0080, -0.0100),
            (-0.0098, -0.0030), (-0.0122, -0.0050), (-0.0122, -0.0640)]
    x0 = SCALE_OUT + 0.0010
    hw.prism(clip, axis="X", start=x0, end=x0 + 0.0009, mat=hm)
    hw.box((SCALE_OUT - 0.0002, -0.0110, -0.0870), (x0 + 0.0002, -0.0045, -0.0735), mat=hm)   # clip mount pad
    c.finish(hw, "Hardware", bevel=0.0003, segments=1, parent=frame)
    return frame


def build(ctx) -> None:
    mats = c.Mats(ctx)
    steel_satin = ctx.material("brushed_steel", "#A7AAAE", roughness=0.32, metallic=1.0)
    steel_edge = mats.bare()
    _handle(ctx, mats)
    _frame(ctx, mats, steel_edge)
    _blade(ctx, mats, steel_satin, steel_edge)
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "handle axis, 20 mm below the top of the fist; handle +Y, edge -Z (Godot)"
