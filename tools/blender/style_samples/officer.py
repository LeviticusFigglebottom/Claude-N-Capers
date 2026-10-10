"""C1-00 sample asset 2: "Halden Security" contracted guard, head-and-shoulders bust.

One geometry generator for all styles; the style preset (styles.py) only changes proportions
(head scale, landmark exaggeration, asymmetry), smoothing, surface treatment, lighting and grade.

    blender -b --factory-startup --python officer.py -- --style a_gsr [--out PATH] [--scale 0.5]

Head: SDF sculpt (head.py) -> OpenVDB quads -> Taubin smoothing -> decimate. Body: SDF torso with
collar, tie, pockets, epaulettes, shoulder patches, badge, speaker-mic and coiled cable placed on the
surface by vectorised sphere tracing.
"""

from __future__ import annotations

import math
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sdf as S  # noqa: E402
import sslib as L  # noqa: E402
import styles  # noqa: E402
from head import EYE_R, Head  # noqa: E402

ASSET = "officer"
ROOT_Z = 1.62            # eye height in the world (m)
SHIRT = "#8E9DAE"        # pale steel-blue uniform shirt
DARK = "#2A2D33"         # charcoal: cap, epaulettes, tie
GOLD = "#C9A227"         # glasshouse brass accent doubles as the company braid colour
BURGUNDY = "#6E1E2A"
SKIN = "#B98466"
HEAD_BASE = 1.04         # shared base scale of the head generator (all styles), style factor on top


# --------------------------------------------------------------------------- skin & eyes

def _ell_mask(nb, vec, c, r, soft=0.6, rot=None):
    """1 inside the ellipsoid (c, r), fading to 0 at its surface. vec is a node vector output."""
    mp = nb.node("ShaderNodeMapping", vector_type="POINT")
    mp.inputs["Location"].default_value = tuple(-c[i] / r[i] for i in range(3))
    mp.inputs["Scale"].default_value = tuple(1.0 / r[i] for i in range(3))
    nb.link(vec, mp.inputs["Vector"])
    ln = nb.node("ShaderNodeVectorMath", operation="LENGTH")
    nb.link(mp.outputs[0], ln.inputs[0])
    return nb.ramp(ln.outputs["Value"], 1.0, soft)


def skin_material(st: dict, eyes):
    m = bpy.data.materials.new("M_skin")
    m.use_nodes = True
    nb = L.NB(m)
    p = nb.n["Principled BSDF"]
    tc = nb.node("ShaderNodeTexCoord")
    co = tc.outputs["Object"]
    # mirrored coords (|x|) so one mask covers both sides
    sep = nb.node("ShaderNodeSeparateXYZ")
    nb.link(co, sep.inputs[0])
    ax = nb.math("ABSOLUTE", sep.outputs[0])
    cmb = nb.node("ShaderNodeCombineXYZ")
    nb.link(ax, cmb.inputs[0])
    nb.link(sep.outputs[1], cmb.inputs[1])
    nb.link(sep.outputs[2], cmb.inputs[2])
    mco = cmb.outputs[0]
    base = L._sat(L.hex_lin(SKIN), st["saturation"])
    surf = st["surface"]
    # low-frequency mottling
    mott = nb.noise(co, 45.0, 3.0, 0.55)
    col = nb.mix(L._scale_rgb(base, 0.9), L._scale_rgb(base, 1.08), mott)
    # redness: cheeks, nose, ears, lips
    red = (base[0] * 1.05, base[1] * 0.62, base[2] * 0.62)
    rmask = nb.math("MAXIMUM", _ell_mask(nb, mco, (0.045, -0.07, -0.03), (0.025, 0.03, 0.025)),
                    _ell_mask(nb, mco, (0.0, -0.112, -0.042), (0.016, 0.02, 0.016)))
    rmask = nb.math("MAXIMUM", rmask, _ell_mask(nb, mco, (0.075, 0.012, -0.012), (0.02, 0.03, 0.038)))
    col = nb.mix(col, red, nb.math("MULTIPLY", rmask, 0.45))
    lips = _ell_mask(nb, mco, (0.0, -0.098, -0.075), (0.0235, 0.012, 0.0115), 0.5)
    col = nb.mix(col, (base[0] * 0.78, base[1] * 0.42, base[2] * 0.42), nb.math("MULTIPLY", lips, 0.75))
    # under-eye shadow
    ue = _ell_mask(nb, mco, (0.032, -0.08, -0.012), (0.016, 0.02, 0.008))
    col = nb.mix(col, (base[0] * 0.7, base[1] * 0.6, base[2] * 0.65), nb.math("MULTIPLY", ue, 0.35))
    # stubble / beard shadow
    zb = nb.ramp(sep.outputs[2], -0.048, -0.064)
    yb = nb.ramp(sep.outputs[1], 0.005, -0.02)
    neck = nb.ramp(sep.outputs[2], -0.16, -0.125)
    beard = nb.math("MULTIPLY", nb.math("MULTIPLY", zb, yb), neck)
    beard = nb.math("MULTIPLY", beard, nb.math("SUBTRACT", 1.0, lips), clamp=True)
    stub_col = (0.11, 0.09, 0.085)
    if surf == "micro":
        dots = nb.node("ShaderNodeTexVoronoi", feature="F1")
        dots.inputs["Scale"].default_value = 2600.0
        nb.link(co, dots.inputs["Vector"])
        dmask = nb.ramp(dots.outputs["Distance"], 0.35, 0.15)
        beard_amt = nb.math("ADD", nb.math("MULTIPLY", beard, 0.22), nb.math("MULTIPLY", nb.math("MULTIPLY", beard, dmask), 0.5))
    else:
        beard_amt = nb.math("MULTIPLY", beard, 0.3)
    col = nb.mix(col, stub_col, beard_amt)
    # eyebrows (arched: two overlapping ellipsoids), strands along +x
    brow = nb.math("MAXIMUM", _ell_mask(nb, mco, (0.025, -0.092, 0.0175), (0.014, 0.02, 0.0048), 0.3),
                   _ell_mask(nb, mco, (0.044, -0.083, 0.0185), (0.012, 0.02, 0.0040), 0.3))
    smap = nb.node("ShaderNodeMapping")
    smap.inputs["Scale"].default_value = (60.0, 900.0, 900.0)
    nb.link(co, smap.inputs["Vector"])
    strands = nb.noise(smap.outputs[0], 1.0, 2.0, 0.5)
    brow_amt = nb.math("MULTIPLY", brow, nb.ramp(strands, 0.3, 0.6) if surf == "micro" else 1.0)
    hair_col = (0.035, 0.024, 0.018)
    col = nb.mix(col, hair_col, nb.math("MULTIPLY", brow_amt, 0.92))
    # lash line: darken the lid margins close to the eyeball
    ec = eyes[1] if eyes[1][0] > 0 else eyes[0]
    dv = nb.node("ShaderNodeVectorMath", operation="DISTANCE")
    nb.link(mco, dv.inputs[0])
    dv.inputs[1].default_value = ec
    lash = nb.ramp(dv.outputs["Value"], EYE_R + 0.0049, EYE_R + 0.0030)
    front = nb.ramp(sep.outputs[1], ec[1] - 0.004, ec[1] - 0.008)
    upper = nb.ramp(sep.outputs[2], ec[2] - 0.004, ec[2] + 0.001)
    lash = nb.math("MULTIPLY", nb.math("MULTIPLY", lash, front), nb.math("ADD", 0.35, nb.math("MULTIPLY", upper, 0.65)))
    col = nb.mix(col, (0.02, 0.015, 0.012), nb.math("MULTIPLY", lash, 0.95))
    # painterly posterised modulation for the graphic style
    if surf == "painterly":
        bm = nb.node("ShaderNodeMapping")
        bm.inputs["Scale"].default_value = (30.0, 30.0, 110.0)
        nb.link(co, bm.inputs["Vector"])
        brush = nb.math("SNAP", nb.noise(bm.outputs[0], 1.0, 1.0, 0.4, 1.0), 1.0 / st["posterize"])
        col = nb.mix(col, nb.mix(col, (0.0, 0.0, 0.0), 0.0), 0.0)
        col = nb.mix(nb.mix(col, (0, 0, 0), 0.14), nb.mix(col, (1, 0.9, 0.85), 0.10), brush)
    nb.link(col, p.inputs["Base Color"])
    # roughness: oily T-zone
    tz = nb.math("MAXIMUM", _ell_mask(nb, mco, (0.0, -0.1, 0.035), (0.03, 0.03, 0.03)),
                 _ell_mask(nb, mco, (0.0, -0.11, -0.03), (0.012, 0.02, 0.03)))
    rough = nb.math("SUBTRACT", st["skin_rough"], nb.math("MULTIPLY", tz, 0.14))
    rough = nb.math("ADD", rough, nb.math("MULTIPLY", brow_amt, 0.25))
    nb.link(rough, p.inputs["Roughness"])
    p.inputs["Subsurface Weight"].default_value = st["skin_sss"]
    p.inputs["Subsurface Radius"].default_value = (1.0, 0.38, 0.2)
    p.inputs["Subsurface Scale"].default_value = st["skin_sss_scale"]
    p.inputs["Specular IOR Level"].default_value = 0.45
    if surf == "micro":
        pores = nb.node("ShaderNodeTexVoronoi", feature="F1")
        pores.inputs["Scale"].default_value = 1500.0
        nb.link(co, pores.inputs["Vector"])
        fine = nb.noise(co, 700.0, 4.0, 0.6)
        h = nb.math("ADD", nb.math("MULTIPLY", pores.outputs["Distance"], 0.6), nb.math("MULTIPLY", fine, 0.4))
        bn = nb.node("ShaderNodeBump")
        bn.inputs["Strength"].default_value = 0.22
        bn.inputs["Distance"].default_value = 0.00025
        nb.link(h, bn.inputs["Height"])
        nb.link(bn.outputs["Normal"], p.inputs["Normal"])
    elif surf == "clean":
        bn = nb.node("ShaderNodeBump")
        bn.inputs["Strength"].default_value = 0.06
        bn.inputs["Distance"].default_value = 0.0003
        nb.link(nb.noise(co, 500.0, 2.0, 0.5), bn.inputs["Height"])
        nb.link(bn.outputs["Normal"], p.inputs["Normal"])
    return m


def eye_material(st: dict, iris_hex: str = "#5B4632"):
    m = bpy.data.materials.new("M_eye")
    m.use_nodes = True
    nb = L.NB(m)
    p = nb.n["Principled BSDF"]
    tc = nb.node("ShaderNodeTexCoord")
    sep = nb.node("ShaderNodeSeparateXYZ")
    nb.link(tc.outputs["Object"], sep.inputs[0])
    r = nb.math("DIVIDE", nb.math("SQRT", nb.math("ADD", nb.math("POWER", sep.outputs[0], 2.0),
                                                     nb.math("POWER", sep.outputs[2], 2.0))), EYE_R)
    front = nb.ramp(sep.outputs[1], 0.0, -0.004)
    iris = nb.math("MULTIPLY", nb.ramp(r, 0.54, 0.50), front)
    pupil = nb.math("MULTIPLY", nb.ramp(r, 0.22, 0.19), front)
    limbal = nb.math("MULTIPLY", nb.ramp(r, 0.42, 0.53), iris)
    ic = L.hex_lin(iris_hex)
    fib = nb.noise(tc.outputs["Object"], 1800.0, 3.0, 0.6, distortion=0.4)
    icol = nb.mix(L._scale_rgb(ic, 0.6), L._scale_rgb(ic, 1.6), fib)
    sclera = nb.mix((0.42, 0.36, 0.33), (0.58, 0.54, 0.50), front)
    col = nb.mix(sclera, icol, iris)
    col = nb.mix(col, (0.03, 0.025, 0.02), nb.math("MULTIPLY", limbal, 0.7))
    col = nb.mix(col, (0.008, 0.008, 0.008), pupil)
    nb.link(col, p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.3
    p.inputs["Coat Weight"].default_value = 1.0
    p.inputs["Coat Roughness"].default_value = 0.02
    p.inputs["Coat IOR"].default_value = 1.38
    p.inputs["Subsurface Weight"].default_value = 0.2 * st["skin_sss"]
    p.inputs["Subsurface Scale"].default_value = 0.002
    return m


# --------------------------------------------------------------------------- body (SDF)

def torso_field() -> S.SDF:
    f = S.SDF()
    f.add(S.ellipsoid((0, 0.028, -0.41), (0.165, 0.112, 0.255)))
    for s in (-1, 1):
        f.add(S.capsule((s * 0.035, 0.032, -0.182), (s * 0.162, 0.036, -0.228), 0.040), k=0.03)
        f.add(S.sphere((s * 0.182, 0.032, -0.268), 0.056), k=0.03)
        f.add(S.capsule((s * 0.191, 0.036, -0.27), (s * 0.214, 0.055, -0.64), 0.050), k=0.02)
        f.add(S.ellipsoid((s * 0.068, -0.042, -0.315), (0.074, 0.05, 0.062)), k=0.04)
        # cloth folds from the armpit across the chest
        f.sub(S.capsule((s * 0.155, -0.072, -0.335), (s * 0.085, -0.088, -0.43), 0.004), k=0.012)
        f.sub(S.capsule((s * 0.193, -0.03, -0.36), (s * 0.203, -0.02, -0.50), 0.004), k=0.012)
    f.add(S.ellipsoid((0, -0.025, -0.52), (0.148, 0.088, 0.16)), k=0.05)
    f.sub(S.capsule((0, 0.02, -0.06), (0, 0.022, -0.30), 0.0615), k=0.006)        # neck hole
    f.sub(S.box((0, 0, -0.95), (0.6, 0.6, 0.23)))                                # bottom cut
    return f


def collar_field() -> S.SDF:
    f = S.SDF()
    axis_a, axis_b = np.array((0, 0.02, -0.06), np.float32), np.array((0, 0.022, -0.30), np.float32)

    def stand(p):
        ba = axis_b - axis_a
        h = np.clip(((p - axis_a) @ ba) / (ba @ ba), 0, 1)
        dist = np.linalg.norm(p - axis_a - h[..., None] * ba, axis=-1)
        ring = np.abs(dist - 0.0655) - 0.0022
        y = p[..., 1]
        top = p[..., 2] - (-0.137 + 0.03 * np.clip((y + 0.06) / 0.12, 0, 1))      # higher at the back
        bot = -(p[..., 2] - (-0.172 + 0.02 * np.clip((y + 0.06) / 0.12, 0, 1)))
        frontgap = 0.008 - np.abs(p[..., 0]) + np.clip(-y - 0.03, 0, 1) * 0 - (y > -0.03) * 1.0
        return np.maximum(np.maximum(ring, np.maximum(top, bot)), frontgap).astype(np.float32)
    f.add(S.custom(stand, (-0.08, -0.08, -0.18), (0.08, 0.1, -0.1)))
    return f


def build_body(st, mats):
    t = time.time()
    torso = torso_field()
    v, q = torso.mesh((-0.30, -0.16, -0.73), (0.30, 0.20, -0.10), 0.0022, 3)
    me = S.to_blender_mesh("Torso", v, q)
    ob = bpy.data.objects.new("Torso", me)
    L.link(ob)
    me.materials.append(mats["shirt"])
    _decimate(ob, 0.3)
    col = collar_field()
    v, q = col.mesh((-0.09, -0.11, -0.22), (0.09, 0.11, -0.09), 0.0009, 2)
    cme = S.to_blender_mesh("Collar", v, q)
    cob = bpy.data.objects.new("Collar", cme)
    L.link(cob)
    cme.materials.append(mats["shirt"])
    _decimate(cob, 0.35)
    print(f"[officer] body sdf {time.time() - t:.1f}s")
    return torso


def _decimate(ob, ratio):
    md = ob.modifiers.new("Decimate", "DECIMATE")
    md.ratio = ratio


def surface_patch(name, field, origin, u, v, dirn, shape, size_u, size_v, offset, thick, mat, n=(24, 24),
                  bevel_w=0.0, warp=None):
    """Mesh patch conforming to the field surface. shape(a, b) -> bool keeps the cell; a, b in [-1, 1]."""
    origin = np.asarray(origin, np.float32)
    u = np.asarray(u, np.float32)
    v = np.asarray(v, np.float32)
    dirn = np.asarray(dirn, np.float32) / np.linalg.norm(dirn)
    A, B = np.meshgrid(np.linspace(-1, 1, n[0]), np.linspace(-1, 1, n[1]), indexing="ij")
    A0, B0 = A, B
    if warp is not None:
        A, B = warp(A, B)
    starts = origin + A.reshape(-1, 1) * u * size_u + B.reshape(-1, 1) * v * size_v - dirn * 0.2
    hit = S.project(field, starts, dirn)
    nrm = S.normals(field, hit)
    pts = hit + nrm * offset
    bm = bmesh.new()
    verts = [bm.verts.new(tuple(p)) for p in pts]
    for i in range(n[0] - 1):
        for j in range(n[1] - 1):
            a, b = (A0[i, j] + A0[i + 1, j]) / 2, (B0[i, j] + B0[i, j + 1]) / 2
            if shape(a, b):
                k = i * n[1] + j
                bm.faces.new((verts[k], verts[k + n[1]], verts[k + n[1] + 1], verts[k + 1]))
    loose = [vv for vv in bm.verts if not vv.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = L.obj_from_bm(name, bm, mat, smooth=True)
    # outward-facing normal check: flip if pointing into the body
    me = ob.data
    if len(me.polygons):
        pn = np.array(me.polygons[len(me.polygons) // 2].normal)
        if float(pn @ nrm[len(nrm) // 2]) < 0:
            me.flip_normals()
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = -1.0
    if bevel_w:
        bv = ob.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel_w
        bv.segments = 2
        bv.limit_method = "ANGLE"
    return ob, hit, nrm


def shield_warp(A, B):
    """Map the unit square onto a crest/shield outline (flat top, curved sides, pointed bottom)."""
    w = np.where(B > 0.4, 1.0, np.sqrt(np.clip(1 - ((0.4 - B) / 1.4) ** 2.0, 0, 1)))
    return A * w, B


def flap_warp(A, B):
    """Pocket flap: rectangle whose bottom edge comes to a soft point."""
    return A, np.where(B < 0, B - (1 - np.abs(A)) * 0.9 * (-B), B)


def shield(a, b):
    """Shield / crest outline in [-1, 1]^2 (b up)."""
    if b > 0.55:
        return abs(a) < 0.92 and b < 0.95
    w = 0.92 * math.sqrt(max(0.0, 1 - ((0.55 - b) / 1.55) ** 2.2))
    return abs(a) < w


def tri_warp(p_in, p_out, p_tip):
    """Map the unit square to a triangle (collar point): b=1 edge = p_in..p_out, b=-1 = tip."""
    p_in, p_out, p_tip = (np.asarray(p, np.float32) for p in (p_in, p_out, p_tip))

    def w(A, B):
        t = (B + 1) / 2
        top = p_in[:, None, None] * (1 - (A + 1) / 2) + p_out[:, None, None] * ((A + 1) / 2)
        pt = top * t + p_tip[:, None, None] * (1 - t)
        return pt[0], pt[1]
    return w


def build_details(st, torso, mats):
    bw = st["bevel"] * 0.25
    # collar points lying on the chest, projected onto torso + neck proxy
    proxy = S.SDF()
    proxy.ops = list(torso.ops)
    proxy.add(S.capsule((0, 0.02, -0.06), (0, 0.022, -0.30), 0.0672), k=0.012)
    for s in (-1, 1):
        surface_patch(f"CollarPoint{s}", proxy, (0, 0, -0.17), (1, 0, 0), (0, 0, 1), (0, 1, 0), lambda a, b: True,
                      1.0, 1.0, 0.0012, 0.0022, mats["shirt"], (10, 10), bw,
                      tri_warp((s * 0.010, -0.150 + 0.17), (s * 0.068, -0.150 + 0.17), (s * 0.050, -0.222 + 0.17)))
    for s in (-1, 1):
        # chest pockets with flap and button
        org = (s * 0.078, 0.0, -0.335)
        surface_patch(f"Pocket{s}", torso, org, (1, 0, 0), (0, 0, 1), (0, 1, 0),
                      lambda a, b: True, 0.052, 0.062, 0.0006, 0.0018, mats["shirt"], (18, 18), bw)
        _, hit, nrm = surface_patch(f"Flap{s}", torso, (s * 0.078, 0, -0.268), (1, 0, 0), (0, 0, 1), (0, 1, 0),
                                    lambda a, b: True,
                                    0.055, 0.019, 0.0028, 0.0022, mats["shirt"], (18, 8), bw, flap_warp)
        c = hit[len(hit) // 2] + nrm[len(nrm) // 2] * 0.004 + np.array((0, 0, -0.008), np.float32)
        btn = L.cylinder(f"Btn{s}", 0.0055, 0.003, tuple(c), mats["button"], 24, bevel_w=0.001)
        btn.rotation_euler = Vector(nrm[len(nrm) // 2]).to_track_quat("Z", "Y").to_euler()
        # epaulettes on the shoulder tops (projected downwards)
        ep, hit, nrm = surface_patch(f"Epaulette{s}", torso, (s * 0.128, 0.035, -0.12), (1, 0, -0.32), (0, 1, 0),
                                     (0, 0, -1), lambda a, b: not (a * s < -0.75 and abs(b) > 0.4 + (-a * s - 0.75) * 2.0),
                                     0.065, 0.024, 0.0012, 0.003, mats["dark"], (20, 10), bw)
        bp = S.project(torso, np.array([[s * 0.088, 0.035, 0.1]], np.float32), (0, 0, -1))[0]
        bn_ = S.normals(torso, bp[None])[0]
        b2 = L.cylinder(f"EpBtn{s}", 0.005, 0.003, tuple(bp + bn_ * 0.0055), mats["brass"], 24, bevel_w=0.001)
        b2.rotation_euler = Vector(bn_).to_track_quat("Z", "Y").to_euler()
        # gold braid stripe on each epaulette
        surface_patch(f"EpStripe{s}", torso, (s * 0.157, 0.035, -0.12), (1, 0, -0.32), (0, 1, 0), (0, 0, -1),
                      lambda a, b: True, 0.006, 0.022, 0.0045, 0.0008, mats["gold"], (4, 10))
        # shoulder patch: gold border, charcoal field, burgundy band, gold "H" monogram
        org = (s * 0.30, 0.035, -0.335)
        U = (0, -s * 1.0, 0)
        U = (0, -1, 0) if s > 0 else (0, 1, 0)
        Vd = (0, 0, 1)
        dirn = (-s, 0, 0)
        surface_patch(f"PatchBorder{s}", torso, org, (0, -1, 0), Vd, dirn, lambda a, b: True, 0.036, 0.044, 0.0008,
                      0.0012, mats["gold"], (30, 30), 0.0, shield_warp)
        surface_patch(f"PatchField{s}", torso, org, (0, -1, 0), Vd, dirn, lambda a, b: True, 0.032, 0.040, 0.0017,
                      0.0008, mats["dark"], (30, 30), 0.0, shield_warp)
        surface_patch(f"PatchBand{s}", torso, (org[0], org[1], org[2] + 0.025), (0, -1, 0), Vd, dirn,
                      lambda a, b: True, 0.032, 0.0055, 0.0024, 0.0006, mats["burgundy"], (16, 4))
        surface_patch(f"PatchH{s}", torso, org, (0, -1, 0), Vd, dirn,
                      lambda a, b: (-0.55 < b < 0.3) and (0.22 < abs(a) < 0.38 or (abs(a) < 0.3 and -0.2 < b < -0.04)),
                      0.036, 0.044, 0.0024, 0.0006, mats["gold"], (40, 40))
    # chest badge (left breast, wearer's left = +x) and name bar (right breast)
    surface_patch("Badge", torso, (0.078, 0, -0.222), (1, 0, 0), (0, 0, 1), (0, 1, 0), lambda a, b: True, 0.017,
                  0.021, 0.0012, 0.0022, mats["brass"], (24, 24), 0.0006, shield_warp)
    surface_patch("BadgeInlay", torso, (0.078, 0, -0.224), (1, 0, 0), (0, 0, 1), (0, 1, 0), lambda a, b: True,
                  0.012, 0.015, 0.0034, 0.0006, mats["burgundy"], (24, 24), 0.0, shield_warp)
    surface_patch("NameBar", torso, (-0.078, 0, -0.242), (1, 0, 0), (0, 0, 1), (0, 1, 0), lambda a, b: True,
                  0.032, 0.0065, 0.0012, 0.002, mats["dark"], (16, 4), 0.0005)


def build_tie(st, torso, mats):
    # knot
    knot = L.uvsphere("TieKnot", 0.012, (0, -0.069, -0.172), mats["dark"], 24, 12, (0.95, 0.65, 1.15))
    zs = np.linspace(-0.183, -0.56, 40)
    wid = np.interp(zs, [-0.56, -0.53, -0.4, -0.183], [0.0, 0.040, 0.036, 0.020]) / 2
    ys = []
    starts = np.stack([np.zeros_like(zs), np.full_like(zs, -0.2), zs], 1).astype(np.float32)
    hit = S.project(torso, starts, (0, 1, 0))
    verts, faces = [], []
    for i, z in enumerate(zs):
        y = min(hit[i, 1] - 0.0035, -0.064 - (i == 0) * 0.002)
        w = max(wid[i], 0.0005)
        verts += [(-w, y, z), (0, y - 0.0018, z), (w, y, z)]
    for i in range(len(zs) - 1):
        for j in range(2):
            a = i * 3 + j
            faces.append((a, a + 1, a + 4, a + 3))
    ob = L.mesh_obj("TieBlade", verts, faces, mats["dark"])
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.003
    sol.offset = 1.0
    # tie bar (brass)
    L.box("TieBar", (0.045, 0.004, 0.004), (0, float(hit[18, 1]) - 0.0075, float(zs[18])), mats["brass"], 0.001, 2)


def build_radio(st, torso, mats):
    """Speaker-mic clipped high on the right chest, coiled cable running down off frame."""
    org = np.array((-0.118, -0.2, -0.235), np.float32)
    hit = S.project(torso, org[None], (0, 1, 0))[0]
    n = S.normals(torso, hit[None])[0]
    up = np.array((0, 0, 1), np.float32)
    xax = np.cross(up, n)
    xax /= np.linalg.norm(xax)
    yax = np.cross(n, xax)
    c = hit + n * 0.016
    mic = L.box("SpeakerMic", (0.052, 0.072, 0.024), (0, 0, 0), mats["plastic"], st["bevel"] * 1.3, 3)
    M = Matrix(((*xax, 0), (*yax, 0), (*n, 0), (0, 0, 0, 1))).transposed()
    mic.matrix_world = Matrix.Translation(Vector(c)) @ M
    # grille slots
    for i in range(6):
        g = L.box(f"Grille{i}", (0.034, 0.003, 0.0022), (0, 0, 0), mats["grille"], 0.0005, 1)
        loc = Vector(c) + Vector(n) * 0.0122 + Vector(yax) * (0.016 - i * 0.0055) + Vector(xax) * 0.0
        g.matrix_world = Matrix.Translation(loc) @ M
    # PTT button and orange emergency button
    ptt = L.box("PTT", (0.006, 0.026, 0.012), (0, 0, 0), mats["rubber"], 0.002, 2)
    ptt.matrix_world = Matrix.Translation(Vector(c) + Vector(xax) * 0.028) @ M
    eb = L.cylinder("Emergency", 0.0042, 0.004, (0, 0, 0), mats["orange"], 20, bevel_w=0.001)
    eb.matrix_world = Matrix.Translation(Vector(c) + Vector(yax) * 0.04 + Vector(n) * 0.003) @ M
    # clip over the shirt
    clip = L.box("MicClip", (0.018, 0.004, 0.03), (0, 0, 0), mats["metal"], 0.001, 2)
    clip.matrix_world = Matrix.Translation(Vector(hit + n * 0.002 + yax * 0.02)) @ M
    # coiled cable: base path on the chest surface, helix around it
    base_start = c - yax * 0.036 - n * 0.002
    xs = np.array([base_start[0], -0.125, -0.15, -0.17, -0.19, -0.205])
    zs = np.array([base_start[2], -0.31, -0.39, -0.47, -0.56, -0.66])
    t = np.linspace(0, 1, 60)
    px = np.interp(t, np.linspace(0, 1, len(xs)), xs)
    pz = np.interp(t, np.linspace(0, 1, len(zs)), zs)
    starts = np.stack([px, np.full_like(px, -0.25), pz], 1).astype(np.float32)
    ph = S.project(torso, starts, (0, 1, 0))
    pn = S.normals(torso, ph)
    path = ph + pn * 0.0095
    path[0] = base_start
    # resample path densely
    seg = np.linalg.norm(np.diff(path, axis=0), axis=1)
    s_acc = np.concatenate([[0], np.cumsum(seg)])
    total = s_acc[-1]
    pitch = 0.0042
    turns = total / pitch
    npts = int(turns * 14)
    ss = np.linspace(0, total, npts)
    P = np.stack([np.interp(ss, s_acc, path[:, i]) for i in range(3)], 1)
    N = np.stack([np.interp(ss, s_acc, pn[:, i]) for i in range(3)], 1)
    T = np.gradient(P, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True) + 1e-9
    B = np.cross(T, N)
    B /= np.linalg.norm(B, axis=1, keepdims=True) + 1e-9
    N2 = np.cross(B, T)
    ang = ss / pitch * 2 * math.pi
    R = 0.0062
    coil = P + R * (np.cos(ang)[:, None] * N2 + np.sin(ang)[:, None] * B)
    pts = [tuple(c - yax * 0.036 + n * 0.0)] + [tuple(p) for p in coil]
    print(f"[officer] coil points {len(pts)}, path length {total:.3f} m")
    cab = L.tube("CoilCable", pts, 0.0017, mats["rubber"], bevel_res=2)
    return cab


# --------------------------------------------------------------------------- cap

def build_cap(st, mats, parent):
    def ring(z_front, z_back, rx, ry, cy, n=96, bulge=0.0):
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n
            x = rx * math.sin(a)
            y = cy - ry * math.cos(a)        # a = 0 -> front (-y)
            fr = (1 - math.cos(a)) / 2       # 0 front, 1 back
            z = z_front + (z_back - z_front) * fr
            pts.append((x, y, z))
        return pts
    rings = [
        ring(0.046, 0.052, 0.0785, 0.1045, 0.007),       # band bottom (just above the brow)
        ring(0.084, 0.086, 0.0795, 0.1055, 0.007),       # band top
        ring(0.090, 0.090, 0.0815, 0.1080, 0.006),       # crown begins
        ring(0.122, 0.102, 0.1000, 0.1260, -0.004),      # crown flare (front higher)
        ring(0.1305, 0.1085, 0.0975, 0.1225, -0.004),    # rolled top edge
        ring(0.1335, 0.1115, 0.0880, 0.1100, -0.004),
        ring(0.1350, 0.1130, 0.0500, 0.0620, -0.004),    # top
    ]
    n = len(rings[0])
    verts = [p for r in rings for p in r] + [(0, -0.004, 0.1352 - 0.011)]
    faces = []
    for k in range(len(rings) - 1):
        for i in range(n):
            i2 = (i + 1) % n
            faces.append((k * n + i, k * n + i2, (k + 1) * n + i2, (k + 1) * n + i))
    ctr = len(verts) - 1
    top = (len(rings) - 1) * n
    for i in range(n):
        faces.append((top + i, top + (i + 1) % n, ctr))
    crown = L.mesh_obj("CapCrown", verts, faces, mats["cap"])
    crown.data.polygons.foreach_set("material_index", [0] * len(crown.data.polygons))
    crown.data.materials.append(mats["capband"])
    idx = [1 if (fi < n) else 0 for fi in range(len(faces))]
    crown.data.polygons.foreach_set("material_index", idx)
    sol = crown.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.0025
    sol.offset = 1.0
    sub = crown.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    crown.parent = parent
    # visor (peak): pitched down, half-ellipse
    vverts, vfaces = [], []
    nu, nv = 40, 8
    for i in range(nu):
        a = -math.radians(78) + math.radians(156) * i / (nu - 1)
        x0 = 0.0785 * math.sin(a)
        y0 = 0.007 - 0.1045 * math.cos(a)
        ext = 0.058 * math.cos(a) ** 0.6
        for j in range(nv):
            v = j / (nv - 1)
            d = ext * v
            vverts.append((x0 * (1 + 0.12 * v), y0 - d * 0.88 - 0.002, 0.047 - d * 0.47 - 0.004 * v * v))
    for i in range(nu - 1):
        for j in range(nv - 1):
            a = i * nv + j
            vfaces.append((a, a + nv, a + nv + 1, a + 1))
    visor = L.mesh_obj("CapVisor", vverts, vfaces, mats["visor"])
    sol = visor.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.0035
    sol.offset = 0.0
    bv = visor.modifiers.new("Bevel", "BEVEL")
    bv.width = 0.0012
    bv.segments = 2
    visor.parent = parent
    # gold chin cord across the band front with two side buttons
    cord = []
    for i in range(41):
        a = -math.radians(70) + math.radians(140) * i / 40
        cord.append((0.0815 * math.sin(a), 0.007 - 0.1075 * math.cos(a), 0.054 + 0.004 * math.cos(a)))
    c1 = L.tube("CapCord", cord, 0.0018, mats["gold"], bevel_res=2)
    c1.parent = parent
    for s in (-1, 1):
        a = s * math.radians(70)
        b = L.cylinder(f"CapBtn{s}", 0.0042, 0.003, (0.0825 * math.sin(a), 0.007 - 0.1085 * math.cos(a), 0.054),
                       mats["brass"], 20, bevel_w=0.0008)
        b.rotation_euler = (math.pi / 2, 0, a + math.pi)
        b.parent = parent
    # cap badge: brass shield on the crown front
    bm = bmesh.new()
    pts = []
    for i in range(24):
        a = i / 24
        b = 1 - 2 * a
        w = 0.92 * math.sqrt(max(0.0, 1 - ((0.55 - b) / 1.55) ** 2.2)) if b <= 0.55 else 0.92
        pts.append((w, b))
    outline = [(x, z) for x, z in pts] + [(-x, z) for x, z in reversed(pts)]
    vs = [bm.verts.new((x * 0.013, 0, z * 0.016)) for x, z in outline]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0.003, 0), verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    badge = L.obj_from_bm("CapBadge", bm, mats["brass"])
    badge.location = (0, -0.110, 0.093)
    badge.rotation_euler = (math.radians(-14), 0, 0)
    L.bevel(badge, 0.0008, 2)
    badge.parent = parent
    return crown


# --------------------------------------------------------------------------- set

def build_set(st, mats):
    """Out-of-focus Glasshouse interior: ivory wall, walnut wainscot, magenta neon, warm bulbs."""
    setroot = bpy.data.objects.new("SetRoot", None)
    L.link(setroot)
    setroot.location = (0, 0, ROOT_Z)
    before = set(bpy.context.scene.objects)
    L.box("Wall", (6.0, 0.1, 4.0), (0, 1.6, 0.4), mats["wall"])
    L.box("Wainscot", (6.0, 0.05, 0.9), (0, 1.53, -1.1), mats["walnut"], 0.004)
    L.box("Floor", (8, 8, 0.05), (0, 0, -1.7), mats["floor"])
    # neon: a diamond outline + underline, behind camera-left
    pts = []
    cx, cz = -0.62, 0.32
    for a in np.linspace(0, 2 * math.pi, 5):
        pts.append((cx + 0.22 * math.sin(a), 1.5, cz + 0.16 * math.cos(a) * (1.4 if math.cos(a) < 0 else 0.7)))
    L.tube("NeonDiamond", pts, 0.008, mats["neon"])
    L.tube("NeonLine", [(cx - 0.32, 1.5, cz - 0.27), (cx + 0.32, 1.5, cz - 0.27)], 0.008, mats["neon"])
    # warm practical bulbs (pendants) camera-right
    for i, (x, z) in enumerate(((0.62, 0.12), (0.98, 0.02), (1.32, 0.16))):
        L.uvsphere(f"Bulb{i}", 0.05, (x, 1.25, z), mats["bulb"], 24, 12)
        L.tube(f"BulbCord{i}", [(x, 1.25, z + 0.05), (x, 1.25, 2.0)], 0.003, mats["dark"])
    for ob in set(bpy.context.scene.objects) - before:
        ob.parent = setroot


# --------------------------------------------------------------------------- main

def main() -> None:
    args = L.parse_args(ASSET)
    st = styles.get(args.style)
    L.reset()
    t0 = time.time()
    seed = L.seed(ASSET)
    bw = st["bevel"]
    fab = dict(kind="fabric")
    mats = {
        "shirt": L.material("shirt", st, SHIRT, 0.78, **fab, sheen=0.25),
        "dark": L.material("charcoal_twill", st, DARK, 0.7, **fab),
        "cap": L.material("cap_wool", st, DARK, 0.75, **fab, sheen=0.3),
        "capband": L.material("cap_band", st, "#1A1C20", 0.6, **fab),
        "visor": L.material("visor_patent", st, "#141518", 0.12, kind="plastic", coat=1.0),
        "gold": L.material("gold_braid", st, GOLD, 0.45, 0.7, kind="fabric", tag=1.0),
        "brass": L.material("brass", st, GOLD, 0.28, 1.0, kind="metal"),
        "button": L.material("button", st, "#D8D2C6", 0.35, kind="plastic"),
        "burgundy": L.material("patch_burgundy", st, BURGUNDY, 0.7, **fab),
        "plastic": L.material("radio_plastic", st, "#25272B", 0.45, kind="plastic"),
        "grille": L.material("grille", st, "#0E0F10", 0.6, kind="plastic"),
        "rubber": L.material("rubber", st, "#1B1C1E", 0.55, kind="plastic"),
        "orange": L.material("emergency", st, "#E0661E", 0.4, kind="plastic"),
        "metal": L.material("steel", st, "#9A9EA3", 0.3, 1.0, kind="metal"),
        "hair": L.material("hair", st, "#2B2119", 0.5, kind="fabric", aniso=0.6),
        "wall": L.material("wall_ivory", st, "#E8DCC8", 0.85, kind="paint"),
        "walnut": L.material("walnut", st, "#5A3B28", 0.35, kind="wood", coat=0.6),
        "floor": L.material("floor", st, "#3A3430", 0.5, kind="paint"),
        "neon": L.emission_material("neon_magenta", "#FF3EA5", {"a_gsr": 10.0, "b_noir": 30.0, "c_photo": 12.0}[args.style]),
        "bulb": L.emission_material("bulb_warm", L.kelvin(2400), {"a_gsr": 14.0, "b_noir": 6.0, "c_photo": 12.0}[args.style]),
    }
    root = bpy.data.objects.new("OfficerRoot", None)
    L.link(root)
    # ---- head
    head = Head(st["exaggeration"], st["asymmetry"], seed)
    v, q = head.mesh(0.00105, st["smooth_iters"])
    hme = S.to_blender_mesh("Head", v, q)
    hob = bpy.data.objects.new("Head", hme)
    L.link(hob)
    hme.materials.append(skin_material(st, head.eyes))
    _decimate(hob, 0.22)
    print(f"[officer] head sdf {time.time() - t0:.1f}s, {len(q)} quads before decimate")
    pivot = bpy.data.objects.new("HeadPivot", None)
    L.link(pivot)
    pivot.location = (0, 0.015, -0.115)
    hob.parent = pivot
    hob.location = (0, -0.015, 0.115)
    emat = eye_material(st)
    for i, e in enumerate(head.eyes):
        eo = L.uvsphere(f"Eye{i}", EYE_R, e, emat, 48, 24)
        eo.parent = hob
    hf = head.hair_field()
    v, q = hf.mesh((-0.1, -0.08, -0.07), (0.1, 0.13, 0.12), 0.0011, 2)
    if len(q):
        hm = S.to_blender_mesh("Hair", v, q)
        ho = bpy.data.objects.new("Hair", hm)
        L.link(ho)
        hm.materials.append(mats["hair"])
        ho.parent = hob
        _decimate(ho, 0.3)
    capgrp = bpy.data.objects.new("CapGroup", None)
    L.link(capgrp)
    capgrp.parent = hob
    build_cap(st, mats, capgrp)
    pivot.scale = (HEAD_BASE * st["head_scale"],) * 3
    # ---- body
    torso = build_body(st, mats)
    build_details(st, torso, mats)
    build_tie(st, torso, mats)
    build_radio(st, torso, mats)
    for ob in list(bpy.context.scene.objects):
        if ob.parent is None and ob is not root:
            ob.parent = root
    # slight turn of the head toward camera, body three-quarter
    root.location = (0, 0, ROOT_Z)
    root.rotation_euler = (0, 0, math.radians(-20))
    pivot.rotation_euler = (math.radians(3), 0, math.radians(8))
    build_set(st, mats)
    # ---- camera, lights, world
    target = Vector((0.0, -0.02, ROOT_Z - 0.10))
    cam_loc = (0.36, -1.95, ROOT_Z + 0.02)
    bpy.context.view_layer.update()
    for i, e in enumerate(head.eyes):   # eyes look into the lens
        eo = bpy.data.objects[f"Eye{i}"]
        d = hob.matrix_world.inverted() @ Vector(cam_loc) - Vector(e)
        eo.rotation_euler = d.to_track_quat("-Y", "Z").to_euler()
    L.camera(cam_loc, target, 75.0, st)
    bpy.context.scene.camera.data.dof.focus_distance = (Vector(cam_loc) - Vector((0.0, -0.09, ROOT_Z))).length
    L.light_rig(st, (0, -0.02, ROOT_Z - 0.08), cam_loc, 0.55, gain=0.6)
    L.world(st)
    L.setup_render(st, args)
    print(f"[officer] build {time.time() - t0:.1f}s, tris {L.tri_count(verbose=True)}")
    L.render(args, st)


if __name__ == "__main__":
    main()
