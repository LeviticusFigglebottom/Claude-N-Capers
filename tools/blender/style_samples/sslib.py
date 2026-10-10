"""Blender helpers for the C1-00 style samples: args, scene reset, style-aware materials, simple
mesh builders, camera, lighting rigs, render setup and the hand-off to post.py.

Self-contained on purpose (tools/blender/lib is under active development by another agent).
"""

from __future__ import annotations

import argparse
import math
import os
import pathlib
import subprocess
import sys
import time
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import styles as _styles  # noqa: E402

REPO = HERE.parents[2]


# --------------------------------------------------------------------------- args / scene

def parse_args(default_asset: str) -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", default="a_gsr", choices=_styles.STYLE_IDS)
    ap.add_argument("--asset", default=default_asset)
    ap.add_argument("--out", default="")
    ap.add_argument("--scale", type=float, default=1.0, help="resolution scale for previews")
    ap.add_argument("--samples", type=int, default=0, help="override sample count")
    ap.add_argument("--no-post", action="store_true")
    a = ap.parse_args(argv)
    if not a.out:
        a.out = str(REPO / "docs/art/style_samples" / a.style / f"{a.asset}.png")
    return a


def seed(asset_id: str) -> int:
    return zlib.crc32(asset_id.encode())


def reset() -> bpy.types.Scene:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    return sc


def hex_lin(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def kelvin(k: float) -> tuple[float, float, float]:
    """Approximate blackbody colour (linear, normalised so max = 1)."""
    t = k / 100.0
    r = 255.0 if t <= 66 else 329.698727446 * ((t - 60) ** -0.1332047592)
    g = 99.4708025861 * math.log(t) - 161.1195681661 if t <= 66 else 288.1221695283 * ((t - 60) ** -0.0755148492)
    b = 255.0 if t >= 66 else (0.0 if t <= 19 else 138.5177312231 * math.log(t - 10) - 305.0447927307)
    c = [max(0.0, min(255.0, v)) / 255.0 for v in (r, g, b)]
    c = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    m = max(c)
    return tuple(v / m for v in c)


def link(obj, parent=None):
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


# --------------------------------------------------------------------------- materials

class NB:
    """Small node-building helper."""

    def __init__(self, mat):
        self.nt = mat.node_tree
        self.n = self.nt.nodes
        self.l = self.nt.links

    def node(self, kind, **props):
        nd = self.n.new(kind)
        for k, v in props.items():
            setattr(nd, k, v)
        return nd

    def link(self, a, b):
        self.l.new(a, b)

    def math(self, op, a, b=None, clamp=False):
        nd = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                nd.inputs[i].default_value = v
            else:
                self.link(v, nd.inputs[i])
        return nd.outputs[0]

    def mix(self, a, b, fac, blend="MIX"):
        nd = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        for sock, v in ((nd.inputs[6], a), (nd.inputs[7], b), (nd.inputs[0], fac)):
            if isinstance(v, (int, float)):
                sock.default_value = v
            elif isinstance(v, (tuple, list)):
                sock.default_value = (*v[:3], 1.0)
            else:
                self.link(v, sock)
        return nd.outputs[2]

    def noise(self, vec, scale, detail=2.0, rough=0.5, distortion=0.0, out=0, w=None):
        nd = self.node("ShaderNodeTexNoise")
        if w is not None:
            nd.noise_dimensions = "4D"
            nd.inputs["W"].default_value = w
        nd.inputs["Scale"].default_value = scale
        nd.inputs["Detail"].default_value = detail
        nd.inputs["Roughness"].default_value = rough
        nd.inputs["Distortion"].default_value = distortion
        self.link(vec, nd.inputs["Vector"])
        return nd.outputs[out]

    def ramp(self, fac, a, b):
        nd = self.node("ShaderNodeMapRange", clamp=True)
        nd.inputs[1].default_value = a
        nd.inputs[2].default_value = b
        self.link(fac, nd.inputs[0])
        return nd.outputs[0]

    def coords(self, scale=(1, 1, 1), seed_offset=0.0):
        tc = self.node("ShaderNodeTexCoord")
        mp = self.node("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = scale
        mp.inputs["Location"].default_value = (seed_offset * 1.37, seed_offset * 2.11, seed_offset * 0.73)
        self.link(tc.outputs["Object"], mp.inputs["Vector"])
        return mp.outputs[0]


def _scale_rgb(c, f):
    return tuple(max(0.0, min(1.0, v * f)) for v in c)


def _sat(c, s):
    lum = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    return tuple(max(0.0, lum + (v - lum) * s) for v in c)


def material(name: str, st: dict, base, rough: float = 0.5, metal: float = 0.0, kind: str = "paint",
             coat: float = 0.0, sheen: float = 0.0, transmission: float = 0.0, ior: float = 1.5,
             emission=None, emission_strength: float = 0.0, aniso: float = 0.0, wear_scale: float = 1.0,
             grain_dir: str = "x", sss: float = 0.0, dispersion: float = 0.0, tag: float = 0.0):
    """Style-aware PBR material. ``base`` is linear RGB or '#hex' (sRGB)."""
    if isinstance(base, str):
        base = hex_lin(base)
    base = _sat(base, st["saturation"])
    m = bpy.data.materials.new(f"M_{name}")
    m.use_nodes = True
    nb = NB(m)
    p = nb.n["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["IOR"].default_value = ior
    if coat:
        p.inputs["Coat Weight"].default_value = coat
        p.inputs["Coat Roughness"].default_value = 0.06 if st["surface"] != "micro" else 0.09
    if sheen:
        p.inputs["Sheen Weight"].default_value = sheen
        p.inputs["Sheen Roughness"].default_value = 0.35
        p.inputs["Sheen Tint"].default_value = (*_scale_rgb(base, 1.6), 1)
    if transmission:
        p.inputs["Transmission Weight"].default_value = transmission
    if dispersion and "Dispersion" in p.inputs:
        p.inputs["Dispersion"].default_value = dispersion
    if aniso:
        p.inputs["Anisotropic"].default_value = aniso
    if sss:
        p.inputs["Subsurface Weight"].default_value = sss
    if emission is not None:
        if isinstance(emission, str):
            emission = hex_lin(emission)
        p.inputs["Emission Color"].default_value = (*emission, 1)
        p.inputs["Emission Strength"].default_value = emission_strength

    surf = st["surface"]
    off = (zlib.crc32(name.encode()) % 997) / 97.0 + tag
    co = nb.coords(seed_offset=off)
    col = (*base, 1.0)
    color_out = None
    rough_out = None
    bump_out = None

    # --- albedo pattern per material kind (shared by all styles) ---
    if kind == "wood":
        # streaky grain: noise stretched along the grain axis, plus soft growth-ring bands
        gscale = {"x": (2.0, 60.0, 60.0), "y": (60.0, 2.0, 60.0), "z": (60.0, 60.0, 2.0)}[grain_dir]
        mp = nb.node("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = gscale
        nb.link(co, mp.inputs["Vector"])
        streak = nb.noise(mp.outputs[0], 1.0, 6.0, 0.62, distortion=0.6)
        mp2 = nb.node("ShaderNodeMapping")
        mp2.inputs["Scale"].default_value = tuple(v * 0.08 for v in gscale)
        nb.link(co, mp2.inputs["Vector"])
        rings = nb.noise(mp2.outputs[0], 1.0, 3.0, 0.5, distortion=2.5)
        g = nb.math("ADD", nb.math("MULTIPLY", nb.ramp(streak, 0.3, 0.7), 0.6), nb.math("MULTIPLY", nb.ramp(rings, 0.35, 0.65), 0.4))
        color_out = nb.mix(_scale_rgb(base, 0.6), _scale_rgb(base, 1.25), g)
    elif kind in ("fabric", "velvet"):
        ws = st.get("fabric_weave_scale", 1.0)
        weave = nb.noise(co, (900.0 if kind == "fabric" else 400.0) * ws, 1.0, 0.5)
        color_out = nb.mix(_scale_rgb(base, 0.85), _scale_rgb(base, 1.12), weave)
        bump_out = (weave, (0.12 if kind == "fabric" else 0.05) * st.get("fabric_weave_strength", 1.0))
    # --- style treatment ---
    v = st["variation"]
    if surf == "painterly":
        sc = nb.node("ShaderNodeMapping")
        sc.inputs["Scale"].default_value = (5.0, 5.0, 22.0)
        sc.inputs["Rotation"].default_value = (0.3, 0.5, 0.2)
        nb.link(co, sc.inputs["Vector"])
        brush = nb.noise(sc.outputs[0], 1.6, 1.0, 0.4, distortion=1.2)
        steps = max(st["posterize"], 2)
        q = nb.math("SNAP", nb.math("MULTIPLY", brush, 1.0), 1.0 / steps)
        src = color_out if color_out is not None else col
        if kind == "wood":
            color_out = nb.mix(src, _scale_rgb(base, 1.0 + v * 2), nb.math("MULTIPLY", q, 0.5))
        else:
            color_out = nb.mix(_scale_rgb(base, 1.0 - v * 2.2), _scale_rgb(base, 1.0 + v * 2.2), q)
        rough_out = nb.math("ADD", nb.math("MULTIPLY", q, 0.15), rough)
    else:
        lowf = nb.noise(co, 2.5, 2.0, 0.5)
        src = color_out if color_out is not None else col
        lo = nb.mix(src, (0, 0, 0), v)
        hi = nb.mix(src, (1, 1, 1), v * 0.5)
        color_out = nb.mix(lo, hi, lowf)
        rn = nb.noise(co, 8.0, 3.0, 0.55)
        rough_out = nb.math("ADD", nb.math("MULTIPLY", nb.math("SUBTRACT", rn, 0.5), 0.08 + 0.3 * st["micro"] * rough), rough)

    wear = st["wear"] * wear_scale
    if wear > 0 and kind not in ("glass", "gem", "emission", "skin"):
        # edge mask from the Bevel node (rounded-normal vs true normal)
        bev = nb.node("ShaderNodeBevel", samples=6)
        bev.inputs["Radius"].default_value = 0.004
        geo = nb.node("ShaderNodeNewGeometry")
        dot = nb.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        nb.link(bev.outputs[0], dot.inputs[0])
        nb.link(geo.outputs["Normal"], dot.inputs[1])
        edge = nb.math("MULTIPLY", nb.math("SUBTRACT", 1.0, dot.outputs["Value"]), 25.0, clamp=True)
        if surf == "micro":
            brk = nb.noise(co, 60.0, 4.0, 0.7)
            edge = nb.math("MULTIPLY", edge, nb.ramp(brk, 0.45, 0.6))
        edge = nb.math("MULTIPLY", edge, min(1.0, wear * 1.6))
        worn = (0.55, 0.5, 0.45) if metal < 0.5 and kind == "paint" else _scale_rgb(base, 1.5)
        color_out = nb.mix(color_out, worn, edge)
        if surf != "painterly":
            # cavity grime (ambient occlusion in a 5 cm radius)
            ao = nb.node("ShaderNodeAmbientOcclusion", samples=8, only_local=True)
            ao.inputs["Distance"].default_value = 0.05
            cav = nb.math("SUBTRACT", 1.0, ao.outputs["AO"])
            grime_amt = wear * (0.9 if surf == "micro" else 0.45)
            if surf == "micro":
                gn = nb.noise(co, 25.0, 5.0, 0.65)
                cav = nb.math("MULTIPLY", cav, nb.ramp(gn, 0.3, 0.7))
            cav = nb.math("MULTIPLY", cav, grime_amt, clamp=True)
            color_out = nb.mix(color_out, (0.03, 0.025, 0.02), cav)
            rough_out = nb.math("ADD", rough_out, nb.math("MULTIPLY", cav, 0.3))

    if surf == "micro" and kind not in ("emission",):
        # scratches + smudges in roughness, fine bump
        smap = nb.node("ShaderNodeMapping")
        smap.inputs["Scale"].default_value = (1.0, 1.0, 1.0)
        nb.link(co, smap.inputs["Vector"])
        scr = nb.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
        scr.inputs["Scale"].default_value = 70.0
        scr.inputs["Distortion"].default_value = 25.0
        scr.inputs["Detail"].default_value = 6.0
        nb.link(co, scr.inputs["Vector"])
        scr_m = nb.math("MULTIPLY", nb.ramp(scr.outputs["Fac"], 0.93, 1.0),
                        nb.ramp(nb.noise(co, 6.0, 2.0), 0.45, 0.65))
        scr_m = nb.math("MULTIPLY", scr_m, 0.25 if kind in ("metal", "paint", "wood", "plastic", "glass") else 0.0)
        rough_out = nb.math("ADD", rough_out, scr_m)
        if bump_out is None and kind not in ("glass", "gem"):
            bump_out = (nb.noise(co, 350.0, 3.0, 0.6), 0.04 * st.get("micro_normal", 1.0))

    brushed = st.get("brushed_metal", 0.0)
    if kind == "metal" and brushed > 0:
        # brushed finish: anisotropic lobe plus streaks stretched along the brushing direction
        bm_ = nb.node("ShaderNodeMapping")
        bm_.inputs["Scale"].default_value = (2.0, 900.0, 900.0)
        nb.link(co, bm_.inputs["Vector"])
        streak = nb.noise(bm_.outputs[0], 1.0, 4.0, 0.6)
        rough_out = nb.math("ADD", rough_out, nb.math("MULTIPLY", nb.math("SUBTRACT", streak, 0.5), 0.18 * brushed))
        p.inputs["Anisotropic"].default_value = 0.75 * brushed
        bump_out = (streak, 0.05 * brushed)

    dust = st.get("dust", 0.0)
    if dust > 0 and kind not in ("glass", "gem", "emission"):
        # dust settles on up-facing surfaces, broken up by low-frequency noise
        geo2 = nb.node("ShaderNodeNewGeometry")
        sepn = nb.node("ShaderNodeSeparateXYZ")
        nb.link(geo2.outputs["Normal"], sepn.inputs[0])
        up = nb.ramp(sepn.outputs["Z"], 0.55, 0.95)
        dm = nb.math("MULTIPLY", up, nb.ramp(nb.noise(co, 12.0, 4.0, 0.6), 0.4, 0.75))
        dm = nb.math("MULTIPLY", dm, 0.35 * dust, clamp=True)
        color_out = nb.mix(color_out if color_out is not None else col, (0.40, 0.38, 0.35), dm)
        rough_out = nb.math("ADD", rough_out if rough_out is not None else rough, nb.math("MULTIPLY", dm, 0.6))

    fuzz = st.get("velvet_fuzz", 0.0)
    if kind == "velvet" and fuzz > 0:
        p.inputs["Sheen Weight"].default_value = 1.0
        p.inputs["Sheen Roughness"].default_value = 0.5
        fib = nb.noise(co, 3000.0, 2.0, 0.7)
        bump_out = (fib, 0.35 * fuzz)

    if kind in ("glass",):
        fp = st["fingerprints"]
        if fp > 0:
            blobs = nb.ramp(nb.noise(co, 9.0, 2.0, 0.5, w=off), 0.58, 0.68)
            ring = nb.node("ShaderNodeTexWave", wave_type="RINGS")
            ring.inputs["Scale"].default_value = 260.0
            ring.inputs["Distortion"].default_value = 6.0
            ring.inputs["Detail"].default_value = 2.0
            nb.link(co, ring.inputs["Vector"])
            smudge = nb.math("MULTIPLY", blobs, nb.ramp(ring.outputs["Fac"], 0.3, 0.9))
            dust = nb.math("MULTIPLY", nb.ramp(nb.noise(co, 140.0, 2.0), 0.62, 0.75), 0.6)
            wv = nb.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
            wv.inputs["Scale"].default_value = 5.0
            wv.inputs["Distortion"].default_value = 5.0
            nb.link(co, wv.inputs["Vector"])
            wipe = nb.math("MULTIPLY", nb.ramp(wv.outputs["Fac"], 0.9, 0.98), 0.35)
            amt = st.get("glass_smudge", 0.22) * fp
            rough_out = nb.math("ADD", nb.math("MULTIPLY", nb.math("ADD", nb.math("ADD", smudge, dust), wipe), amt), rough)
        else:
            rough_out = None
        color_out = None

    if color_out is not None:
        nb.link(color_out, p.inputs["Base Color"])
    else:
        p.inputs["Base Color"].default_value = col
    if rough_out is not None:
        nb.link(nb.math("MAXIMUM", rough_out, 0.0 if kind == "glass" else 0.04), p.inputs["Roughness"])
    if bump_out is not None:
        bn = nb.node("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump_out[1] * (1.0 if surf != "painterly" else 0.3)
        bn.inputs["Distance"].default_value = 0.0005
        nb.link(bump_out[0], bn.inputs["Height"])
        nb.link(bn.outputs["Normal"], p.inputs["Normal"])
    return m


def emission_material(name: str, color, strength: float):
    if isinstance(color, str):
        color = hex_lin(color)
    m = bpy.data.materials.new(f"M_{name}")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    return m


# --------------------------------------------------------------------------- meshes

def obj_from_bm(name: str, bm: bmesh.types.BMesh, mat=None, smooth: bool = False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    if mat is not None:
        ob.data.materials.append(mat)
    link(ob)
    return ob


def bevel(ob, width: float, segments: int = 3, angle: float = 0.6):
    if width <= 0:
        return ob
    md = ob.modifiers.new("Bevel", "BEVEL")
    md.width = width
    md.segments = segments
    md.limit_method = "ANGLE"
    md.angle_limit = angle
    md.harden_normals = True
    ob.data.shade_smooth()
    wn = ob.modifiers.new("WN", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    return ob


def box(name, size, loc=(0, 0, 0), mat=None, bevel_w: float = 0.0, segments: int = 3, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bm(name, bm, mat)
    ob.location = loc
    ob.rotation_euler = rot
    bevel(ob, min(bevel_w, min(size) * 0.45), segments)
    return ob


def cylinder(name, r1, depth, loc=(0, 0, 0), mat=None, segs: int = 48, r2=None, rot=(0, 0, 0),
             bevel_w: float = 0.0, segments: int = 2, smooth: bool = True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1,
                          radius2=r1 if r2 is None else r2, depth=depth)
    ob = obj_from_bm(name, bm, mat, smooth=smooth)
    ob.location = loc
    ob.rotation_euler = rot
    if bevel_w:
        bevel(ob, bevel_w, segments, angle=0.9)
    return ob


def uvsphere(name, r, loc=(0, 0, 0), mat=None, segs: int = 32, rings: int = 16, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    ob = obj_from_bm(name, bm, mat, smooth=True)
    ob.location = loc
    ob.scale = scale
    return ob


def torus(name, R, r, loc=(0, 0, 0), mat=None, seg_major: int = 64, seg_minor: int = 16, rot=(0, 0, 0),
          minor_scale=(1.0, 1.0)):
    verts, faces = [], []
    for i in range(seg_major):
        a = 2 * math.pi * i / seg_major
        ca, sa = math.cos(a), math.sin(a)
        for j in range(seg_minor):
            b = 2 * math.pi * j / seg_minor
            rr = R + r * minor_scale[0] * math.cos(b)
            verts.append((rr * ca, rr * sa, r * minor_scale[1] * math.sin(b)))
    for i in range(seg_major):
        for j in range(seg_minor):
            i2, j2 = (i + 1) % seg_major, (j + 1) % seg_minor
            faces.append((i * seg_minor + j, i2 * seg_minor + j, i2 * seg_minor + j2, i * seg_minor + j2))
    return mesh_obj(name, verts, faces, mat, loc, rot)


def mesh_obj(name, verts, faces, mat=None, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    if smooth:
        me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    if mat is not None:
        me.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = rot
    link(ob)
    return ob


def lathe(name, profile, mat=None, segs: int = 64, loc=(0, 0, 0), scale=(1, 1, 1)):
    """Revolve a (r, z) profile around Z."""
    verts, faces = [], []
    n = len(profile)
    for i in range(segs):
        a = 2 * math.pi * i / segs
        for r, z in profile:
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for i in range(segs):
        i2 = (i + 1) % segs
        for j in range(n - 1):
            faces.append((i * n + j, i2 * n + j, i2 * n + j + 1, i * n + j + 1))
    ob = mesh_obj(name, verts, faces, mat, loc)
    ob.scale = scale
    return ob


def tube(name, pts, radius, mat=None, resolution: int = 6, cyclic: bool = False, bevel_res: int = 4):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = bevel_res
    cu.resolution_u = 1
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
    sp.use_cyclic_u = cyclic
    sp.use_smooth = True
    ob = bpy.data.objects.new(name, cu)
    if mat is not None:
        cu.materials.append(mat)
    link(ob)
    return ob


# --------------------------------------------------------------------------- camera & lights

def camera(loc, target, lens: float, st: dict, focus_obj=None, sensor: float = 36.0):
    cam = bpy.data.cameras.new("Camera")
    cam.lens = lens
    cam.sensor_width = sensor
    cam.clip_start = 0.05
    ob = bpy.data.objects.new("Camera", cam)
    link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.dof.use_dof = True
    cam.dof.focus_distance = d.length
    cam.dof.aperture_fstop = st["dof_fstop"]
    bpy.context.scene.camera = ob
    return ob


def _area(name, loc, target, power, color, size, shape="RECTANGLE", size_y=None, spread=180.0):
    li = bpy.data.lights.new(name, "AREA")
    li.energy = power
    li.color = color
    li.shape = shape
    li.size = size
    li.size_y = size_y if size_y is not None else size
    li.spread = math.radians(spread)
    ob = bpy.data.objects.new(name, li)
    link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return ob


def _spot(name, loc, target, power, color, radius, angle_deg, blend):
    li = bpy.data.lights.new(name, "SPOT")
    li.energy = power
    li.color = color
    li.shadow_soft_size = radius
    li.spot_size = math.radians(angle_deg)
    li.spot_blend = blend
    ob = bpy.data.objects.new(name, li)
    link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return ob


def _orbit(target, cam_loc, az_deg, el_deg, dist):
    """Point at azimuth relative to the camera direction (0 = camera side, +90 = camera-right)."""
    t = Vector(target)
    v = Vector(cam_loc) - t
    v.z = 0
    base = math.atan2(v.y, v.x)
    a = base - math.radians(az_deg)
    e = math.radians(el_deg)
    return t + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * dist


def light_rig(st: dict, target, cam_loc, size: float, gain: float = 1.0):
    """Style lighting rig around a subject of roughly ``size`` metres. Returns the light objects."""
    rig = st["rig"]
    d = size * 2.6
    s2 = d * d
    out = []
    if rig == "soft_practical":
        out.append(_area("Key", _orbit(target, cam_loc, -40, 38, d), target, 70 * s2 * gain, kelvin(4800), size * 1.3))
        out.append(_area("Fill", _orbit(target, cam_loc, 65, 8, d), target, 12 * s2 * gain, kelvin(6200), size * 1.8))
        out.append(_area("Rim", _orbit(target, cam_loc, 155, 32, d), target, 55 * s2 * gain, kelvin(3200), size * 0.8))
    elif rig == "noir_neon":
        out.append(_spot("Key", _orbit(target, cam_loc, -70, 48, d), target, 260 * s2 * gain, kelvin(4300), 0.015, 32, 0.25))
        out.append(_area("RimMagenta", _orbit(target, cam_loc, 140, 18, d), target, 80 * s2 * gain,
                         hex_lin("#FF3EA5"), size * 0.25, "RECTANGLE", size * 1.4))
        out.append(_area("RimTeal", _orbit(target, cam_loc, -145, 22, d), target, 130 * s2 * gain,
                         (0.01, 0.45, 0.42), size * 0.25, "RECTANGLE", size * 1.4))
    elif rig == "softbox_bounce":
        out.append(_area("Softbox", _orbit(target, cam_loc, -45, 32, d), target, 70 * s2 * gain, kelvin(4800), size * 1.5))
        out.append(_area("Bounce", _orbit(target, cam_loc, 70, 0, d * 0.8), target, 14 * s2 * gain, kelvin(4500),
                         size * 2.2))
        out.append(_area("Top", Vector(target) + Vector((0, 0.3 * size, d * 0.9)), target, 12 * s2 * gain,
                         kelvin(4000), size * 1.0))
        out.append(_area("Kicker", _orbit(target, cam_loc, 150, 25, d), target, 30 * s2 * gain, kelvin(5600), size * 0.9))
    else:
        raise ValueError(rig)
    return out


def world(st: dict):
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    # procedural sky gradient: horizon colour -> zenith darker
    nt = w.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    c = st["world_color"]
    mx.inputs[6].default_value = (*[v * 0.35 for v in c], 1)
    mx.inputs[7].default_value = (*c, 1)
    nt.links.new(sep.outputs["Z"], mx.inputs[0])
    nt.links.new(mx.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = st["world_strength"]
    bpy.context.scene.world = w
    return w


# --------------------------------------------------------------------------- render

def setup_render(st: dict, args, res=(1600, 1000)):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    cy = sc.cycles
    cy.device = "CPU"
    cy.samples = args.samples or st["samples"]
    cy.use_adaptive_sampling = True
    cy.adaptive_threshold = 0.02
    cy.use_denoising = True
    cy.denoiser = "OPENIMAGEDENOISE"
    cy.seed = 0
    cy.max_bounces = 10
    cy.diffuse_bounces = 3
    cy.glossy_bounces = 4
    cy.transmission_bounces = 12
    cy.transparent_max_bounces = 8
    cy.caustics_reflective = False
    cy.caustics_refractive = bool(st.get("caustics", False))
    cy.filter_glossy = 0.8 if st.get("caustics", False) else 0.0
    cy.sample_clamp_indirect = 6.0
    cy.blur_glossy = 0.5
    sc.render.threads_mode = "FIXED"
    sc.render.threads = 4
    sc.render.resolution_x = int(res[0] * args.scale)
    sc.render.resolution_y = int(res[1] * args.scale)
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = st["look"]
    except TypeError:
        sc.view_settings.look = "None"
    sc.view_settings.exposure = st["exposure"]
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.image_settings.color_depth = "8"
    sc.render.image_settings.compression = 15
    # Freestyle ink lines (noir)
    if st["outline"] > 0:
        sc.render.use_freestyle = True
        sc.render.line_thickness_mode = "ABSOLUTE"
        sc.render.line_thickness = st["outline"] * args.scale
        vl = sc.view_layers[0]
        vl.use_freestyle = True
        fs = vl.freestyle_settings
        fs.crease_angle = math.radians(128)
        ls = fs.linesets[0] if len(fs.linesets) else fs.linesets.new("Ink")
        ls.select_by_visibility = True
        ls.select_by_edge_types = True
        ls.select_silhouette = True
        ls.select_border = True
        ls.select_crease = True
        ls.select_contour = True
        if ls.linestyle is None:
            ls.linestyle = bpy.data.linestyles.new("Ink")
        ls.linestyle.color = (0.025, 0.015, 0.03)
        ls.linestyle.thickness = st["outline"] * args.scale
        ls.linestyle.alpha = 0.9
    # Compositor bloom
    if st["bloom"] > 0:
        sc.use_nodes = True
        nt = sc.node_tree
        rl = nt.nodes.get("Render Layers") or nt.nodes.new("CompositorNodeRLayers")
        comp = nt.nodes.get("Composite") or nt.nodes.new("CompositorNodeComposite")
        gl = nt.nodes.new("CompositorNodeGlare")
        try:
            gl.glare_type = "BLOOM"
        except TypeError:
            gl.glare_type = "FOG_GLOW"
        _set_glare(gl, st["bloom"])
        nt.links.new(rl.outputs["Image"], gl.inputs["Image"])
        nt.links.new(gl.outputs["Image"], comp.inputs["Image"])


def _set_glare(gl, strength):
    vals = {"Threshold": 1.0, "Strength": strength, "Size": 0.6}
    for k, v in vals.items():
        if k in gl.inputs:
            try:
                gl.inputs[k].default_value = v
            except Exception:
                pass
    for attr, v in (("threshold", 1.0), ("mix", -1.0 + strength), ("size", 7)):
        if hasattr(gl, attr):
            try:
                setattr(gl, attr, v)
            except Exception:
                pass


def render(args, st: dict):
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    raw = out.with_name(out.stem + ".raw.png")
    sc = bpy.context.scene
    sc.render.filepath = str(raw)
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    dt = time.time() - t0
    print(f"[style_samples] rendered {args.style}/{args.asset} in {dt:.1f}s "
          f"({sc.render.resolution_x}x{sc.render.resolution_y}, {sc.cycles.samples} spp)")
    if not args.no_post:
        subprocess.run(["python3", str(HERE / "post.py"), "--style", args.style, "--in", str(raw), "--out", str(out),
                        "--seed", str(seed(args.style + args.asset))], check=True)
        os.remove(raw)
    return dt


def tri_count(verbose: bool = False) -> int:
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for ob in bpy.context.scene.objects:
        if ob.type not in ("MESH", "CURVE"):
            continue
        ev = ob.evaluated_get(dg)
        try:
            me = ev.to_mesh()
        except RuntimeError:
            continue
        me.calc_loop_triangles()
        n += len(me.loop_triangles)
        if verbose and len(me.loop_triangles) > 20000:
            print(f"  tris {ob.name}: {len(me.loop_triangles)}")
        ev.to_mesh_clear()
    return n
