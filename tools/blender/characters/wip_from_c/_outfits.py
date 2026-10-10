"""Character definitions (body params + outfit layers + gear) for C1-05 (pure numpy).

Outfits are parametric: colours/material presets come from
``game/world/characters/materials/palette.json`` (``chr_*`` ids) or the shared material library
(``leather_dark``, ``rubber_black``, ``plastic_matte``, ``brushed_steel``). Change a colour there,
or swap a material id here, and rebuild.
"""

from __future__ import annotations

import json
import math
import pathlib

import numpy as np

import _body
import _dress
from _body import BodyGen, BodyParams, smoothstep, unit, v3, wrap
from _dress import FaceInfo, Layer
from _gear import Gear

REPO = pathlib.Path(__file__).resolve().parents[3]
PALETTE_PATH = REPO / "game" / "world" / "characters" / "materials" / "palette.json"

# Placeholder colours for shared-library materials (the .tres in game/world/materials wins).
LIBRARY = {
    "leather_dark": ("#3A2A22", 0.55, 0.0),
    "rubber_black": ("#232427", 0.85, 0.0),
    "plastic_matte": ("#2E3034", 0.6, 0.0),
    "brushed_steel": ("#9C9FA3", 0.35, 1.0),
}


def palette() -> dict:
    data = json.loads(PALETTE_PATH.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("_")}


def material_spec(mat_id: str) -> tuple[str, float, float]:
    """(sRGB hex, roughness, metallic) placeholder for a material id."""
    if mat_id in LIBRARY:
        return LIBRARY[mat_id]
    p = palette()[mat_id]
    return p["color"], float(p.get("roughness", 0.8)), 1.0 if p.get("kind") == "metal" else 0.0


# ------------------------------------------------------------------------------------------
# region rules
# ------------------------------------------------------------------------------------------
HAIRLINE = ([0.0, 0.5, 0.9, 1.3, 1.6, 1.9, 2.3, math.pi], [0.78, 0.76, 0.70, 0.60, 0.57, 0.42, 0.30, 0.25])


def hairline(phi: float) -> float:
    return float(np.interp(abs(phi), *HAIRLINE))


def is_iris(fi: FaceInfo) -> bool:
    return fi.part == "eye" and fi.ang > 0.70


def is_sole(fi: FaceInfo) -> bool:
    return fi.part == "foot" and fi.nz < -0.55


def is_shoe(fi: FaceInfo, boot_s: float = 9.0) -> bool:
    return fi.part == "foot" or (fi.part == "ankle" and fi.s > 0.81) or (fi.part in ("leg", "ankle") and fi.s >= boot_s)


def is_hand(fi: FaceInfo, cuff: float = 0.535) -> bool:
    return fi.part in ("hand", "finger", "thumb") or (fi.part == "arm" and fi.s >= cuff)


def is_brow(fi: FaceInfo) -> bool:
    if fi.part != "head":
        return False
    a = abs(fi.phi)
    if not 0.16 <= a <= 0.74:
        return False
    arch = 0.552 + 0.018 * math.sin(math.pi * (a - 0.16) / 0.58)
    return arch - 0.012 <= fi.zh <= arch + 0.022


def shoe_layers(mat: str = "leather_dark", boot_s: float = 9.0) -> list[Layer]:
    return [
        Layer("sole", is_sole, "rubber_black", 0.005),
        Layer("shoe", lambda f: is_shoe(f, boot_s), mat, lambda f: 0.004 + (0.004 if f.part in ("leg", "ankle") else 0.0)),
    ]


def face_layers(skin: str, hair_mat: str) -> list[Layer]:
    return [
        Layer("eye", lambda f: f.part == "eye", lambda f: "chr_iris" if is_iris(f) else "chr_eye", 0.0),
        Layer("brow", is_brow, hair_mat, 0.0012),
    ]


def hair_layer(style: str, mat: str, cap_line: float = 9.0) -> Layer:
    def match(f: FaceInfo) -> bool:
        if f.part != "head" or f.zh > cap_line:
            return False
        a = abs(f.phi)
        if style == "bob":
            if a < 0.95:
                return f.zh > hairline(f.phi) + 0.02
            return f.zh > 0.10 if a > 1.25 else f.zh > 0.45
        if style == "bald":
            return a > 1.0 and hairline(f.phi) < f.zh < 0.70
        line = hairline(f.phi)
        if style == "bun":
            line += 0.01
        return f.zh > line

    def thick(f: FaceInfo) -> float:
        top = smoothstep(0.55, 0.95, f.zh)
        if style == "bob":
            lower = smoothstep(0.62, 0.15, f.zh) * smoothstep(0.9, 1.4, abs(f.phi))
            return 0.007 + 0.006 * top + 0.016 * lower
        if style == "crop":
            return 0.003 + 0.002 * top
        if style == "bald":
            return 0.004
        return 0.004 + 0.008 * top

    return Layer("hair", match, mat, thick)


def skin_layer(skin: str) -> Layer:
    return Layer("skin", lambda f: True, skin, 0.0)


def trousers(mat: str, waist: float = 1.02, hem: float = 0.80, flare: float = 0.006, t: float = 0.006) -> Layer:
    def match(f: FaceInfo) -> bool:
        if f.part == "torso":
            return f.z < waist
        return f.part in ("leg", "ankle") and f.s < hem

    def thick(f: FaceInfo) -> float:
        extra = flare * smoothstep(0.45, 0.78, f.s) if f.part in ("leg", "ankle") else 0.0
        return t + extra

    return Layer("trousers", match, mat, thick)


def shirt(mat: str, waist: float = 1.02, cuff: float = 0.535, collar: str = "closed", t: float = 0.0045,
          name: str = "shirt") -> Layer:
    """Shirt/top. ``collar``: closed (buttoned uniform), open (V to the sternum), crew, blouse."""
    def match(f: FaceInfo) -> bool:
        if f.part == "arm":
            return f.s < cuff
        if f.part == "torso":
            if f.z < waist:
                return False
            if collar == "open" and abs(f.phi) < 0.38 and f.z > 1.40:
                return False
            if collar == "blouse" and abs(f.phi) < 0.62 and f.z > 1.415:
                return False
            return True
        if f.part == "head" and collar in ("closed", "open"):
            return f.zh < -0.035 and abs(f.phi) > (0.30 if collar == "closed" else 0.6)
        return False

    def thick(f: FaceInfo) -> float:
        coll = 0.002 if (f.part == "head" or f.z > 1.49) else 0.0
        return t + coll

    return Layer(name, match, mat, thick)


def jacket(mat: str, hem_z: float = 0.84, cuff: float = 0.515, v_bottom: float = 1.15, t: float = 0.011,
           name: str = "jacket") -> Layer:
    def match(f: FaceInfo) -> bool:
        if f.part == "arm":
            return f.s < cuff
        if f.part == "torso":
            if f.z < hem_z:
                return False
            if f.z > v_bottom:
                half = 0.21 if f.z < 1.37 else 0.40
                if abs(f.phi) < half:
                    return False
            return f.z < 1.505 or abs(f.phi) > 1.0
        if f.part == "head":
            return f.zh < -0.04 and abs(f.phi) > 1.2
        return False

    def thick(f: FaceInfo) -> float:
        flare = 0.010 * smoothstep(0.98, 0.86, f.z) if f.part == "torso" else 0.0
        shoulder = 0.006 * smoothstep(1.36, 1.46, f.z) if f.part == "torso" else 0.0
        sleeve = 0.004 * smoothstep(0.4, 0.5, f.s) if f.part == "arm" else 0.0
        return t + flare + shoulder + sleeve

    return Layer(name, match, mat, thick)


def tie(mat: str, top: float = 1.47, bottom: float = 1.06) -> Layer:
    def match(f: FaceInfo) -> bool:
        if f.part != "torso" or not bottom <= f.z <= top:
            return False
        w = 0.17 if f.z > 1.42 else 0.22 + 0.08 * smoothstep(1.4, 1.1, f.z)
        return abs(f.phi) < w

    return Layer("tie", match, mat, 0.0075)


def belt_layer(mat: str = "leather_dark", z0: float = 1.000, z1: float = 1.035) -> Layer:
    return Layer("belt", lambda f: f.part == "torso" and z0 <= f.z <= z1, mat, 0.009)


def gloves(mat: str, cuff: float = 0.515) -> Layer:
    return Layer("gloves", lambda f: is_hand(f, cuff), mat, 0.0025)


# ------------------------------------------------------------------------------------------
# gear
# ------------------------------------------------------------------------------------------
def head_ring(gen: BodyGen, zh_fn, off_fn, n: int = 28) -> list[np.ndarray]:
    """Ring around the head, counter-clockwise seen from above (outward normals when lofting up)."""
    pts = []
    for j in range(n):
        phi = wrap(-math.tau * j / n)
        pts.append(gen.head_point(phi, zh_fn(phi), off_fn(phi)))
    return pts


def _head_centre(gen: BodyGen) -> np.ndarray:
    return v3(0.0, _body.HEAD_AXIS_Y * gen.k, gen.z_chin + 0.5 * gen.head_h)


def head_top_z(gen: BodyGen, zh: float) -> float:
    return gen.z_chin + zh * gen.head_h


def cap_peaked(G: Gear, gen: BodyGen, crown: str, band: str, visor: str, badge: str | None) -> None:
    k = gen.k
    w = {"head": 1.0}

    def bottom(phi: float) -> float:
        return 0.665 + 0.035 * (1 - math.cos(phi)) / 2

    def band_top(phi: float) -> float:
        return bottom(phi) + 0.14

    inner = head_ring(gen, bottom, lambda p: 0.001 * k)
    outer_b = head_ring(gen, bottom, lambda p: 0.008 * k)
    outer_t = head_ring(gen, band_top, lambda p: 0.011 * k)
    # crown: flares wider than the head, flat top slightly tilted up at the front
    z_top = head_top_z(gen, 1.03)
    flare, top = [], []
    for j, p in enumerate(outer_t):
        phi = wrap(-math.tau * j / len(outer_t))
        c = v3(0, _body.HEAD_AXIS_Y * k, 0)
        radial = p - c
        radial[2] = 0
        r = np.linalg.norm(radial)
        dirn = radial / r
        grow = 1.18 + 0.06 * math.cos(phi)
        zf = z_top - 0.012 * k + 0.008 * k * math.cos(phi)
        flare.append(c + dirn * r * grow + v3(0, 0, zf))
        top.append(c + dirn * r * grow * 0.93 + v3(0, 0, zf + 0.008 * k))

    def mat(i: int, j: int) -> str:
        return band if i in (0, 1) else crown

    G.loft([inner, outer_b, outer_t, flare, top], mat, w, close_end="pole")
    # visor: thick curved plate in front of the band bottom
    a_pts, b_pts = [], []
    for i in range(13):
        phi = -1.05 + 2.1 * i / 12
        base = gen.head_point(phi, bottom(phi) + 0.01, 0.007 * k)
        out = unit(v3(math.sin(phi), math.cos(phi), 0.0))
        length = 0.062 * k * (math.cos(phi * 1.2) ** 0.6 if abs(phi * 1.2) < math.pi / 2 else 0.0) + 0.004 * k
        tip = base + out * length + v3(0, 0, -0.026 * k * length / (0.066 * k))
        a_pts.append(base)
        b_pts.append(tip)
    G.plate(a_pts, b_pts, 0.004 * k, visor, w, ref=v3(0, 0, 0))
    if badge:
        c = gen.head_point(0.0, band_top(0.0) + 0.06, 0.016 * k)
        G.box(c, (0.03 * k, 0.004 * k, 0.034 * k), (v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)), badge, w)


def helmet(G: Gear, gen: BodyGen, mat: str, trim: str) -> None:
    k = gen.k
    w = {"head": 1.0}

    def rim(phi: float) -> float:
        a = abs(phi)
        return float(np.interp(a, [0.0, 0.8, 1.4, 1.8, 2.4, math.pi], [0.69, 0.66, 0.47, 0.45, 0.40, 0.38]))

    rings = [head_ring(gen, rim, lambda p: 0.014 * k), head_ring(gen, rim, lambda p: 0.032 * k)]
    for t in (0.25, 0.5, 0.7, 0.85, 0.95):
        rings.append(head_ring(gen, lambda p, t=t: rim(p) + (1.0 - rim(p)) * t, lambda p, t=t: (0.034 + 0.006 * t) * k))
    G.loft(rings, lambda i, j: trim if i == 0 else mat, w, close_end="pole")
    # side rails + front shroud
    for sgn in (-1.0, 1.0):
        c = gen.head_point(sgn * 1.57, 0.60, 0.042 * k)
        G.box(c, (0.012 * k, 0.07 * k, 0.018 * k), (v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)), trim, w, chamfer=0.002 * k)
    c = gen.head_point(0.0, 0.84, 0.042 * k)
    G.box(c, (0.045 * k, 0.012 * k, 0.03 * k), (v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)), trim, w, chamfer=0.002 * k)


def goggles(G: Gear, gen: BodyGen, frame: str, lens: str) -> None:
    k = gen.k
    w = {"head": 1.0}
    lo, hi = [], []
    n = 13
    for i in range(n):
        phi = 0.98 - 1.96 * i / (n - 1)       # right -> left
        lo.append(gen.head_point(phi, 0.415, 0.007 * k))
        hi.append(gen.head_point(phi, 0.565, 0.006 * k))
    # outer shell offset forward: plate thickness pushes inward (towards the face)
    fwd_lo = [p + unit(v3(p[0], p[1] - _body.HEAD_AXIS_Y * k, 0)) * 0.016 * k for p in lo]
    fwd_hi = [p + unit(v3(p[0], p[1] - _body.HEAD_AXIS_Y * k, 0)) * 0.016 * k for p in hi]
    G.plate(fwd_lo, fwd_hi, 0.014 * k, frame, w, top_mat=lens, ref=_head_centre(gen))
    # strap around the back of the head
    lo2, hi2 = [], []
    for i in range(17):
        phi = 0.98 + (math.tau - 1.96) * i / 16
        lo2.append(gen.head_point(wrap(phi), 0.47, 0.007 * k))
        hi2.append(gen.head_point(wrap(phi), 0.51, 0.007 * k))
    G.plate(lo2, hi2, 0.003 * k, frame, w, ref=_head_centre(gen))


def bun(G: Gear, gen: BodyGen, mat: str) -> None:
    k = gen.k
    c = gen.head_point(math.pi, 0.66, 0.018 * k)
    G.ellipsoid(c, (0.038 * k, 0.03 * k, 0.034 * k), mat, {"head": 1.0})


def loupe(G: Gear, gen: BodyGen) -> None:
    k = gen.k
    hs = gen.head_scale
    phi, zh = 0.43, 0.47
    r, cy = gen.head_radius(phi, zh)
    eye = v3((r * hs) * math.sin(phi), _body.HEAD_AXIS_Y * k + cy * hs + (r * hs) * math.cos(phi),
             gen.z_chin + zh * gen.head_h)
    axis = unit(v3(0.15, 1.0, 0.0))
    G.cylinder(eye + axis * 0.014 * k, axis, 0.0125 * k, 0.024 * k, "plastic_matte", {"head": 1.0}, n=12,
               cap_mat="chr_lens", radius2=0.011 * k)
    # headband holding it
    lo, hi = [], []
    for i in range(25):
        phi2 = wrap(0.43 + math.tau * i / 24)
        lo.append(gen.head_point(phi2, 0.60, 0.004 * k))
        hi.append(gen.head_point(phi2, 0.64, 0.004 * k))
    G.plate(lo, hi, 0.003 * k, "plastic_matte", {"head": 1.0}, ref=_head_centre(gen))


def duty_belt(G: Gear, gen: BodyGen, mat: str = "leather_dark", holster: bool = True, pager: bool = True,
              radio_hip: bool = False) -> dict:
    """Wide belt with pouches; returns socket positions (Blender world) for the pager."""
    k = gen.k
    n = 40
    z0, z1 = 0.985, 1.035
    w = {"hips": 0.85, "spine": 0.15}

    def ring(z: float, off: float) -> list[np.ndarray]:
        return [gen.torso_point(wrap(-math.tau * j / n), z, off) for j in range(n)]

    ob, ot = ring(z0, 0.017 * k), ring(z1, 0.017 * k)
    it, ib = ring(z1, 0.006 * k), ring(z0, 0.006 * k)
    G.loft([ob, ot, it, ib, ob], mat, w)
    # buckle
    c = gen.torso_point(0.0, (z0 + z1) / 2, 0.02 * k)
    G.box(c, (0.06 * k, 0.008 * k, 0.045 * k), (v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)), "brushed_steel", w)
    out: dict = {}
    pouch_list = [(0.85, 0.05, 0.04, 0.06), (-0.85, 0.05, 0.04, 0.06), (2.5, 0.07, 0.035, 0.05), (-2.5, 0.07, 0.035, 0.05)]
    if pager:
        pouch_list = [p for p in pouch_list if p[0] != -0.85]
    for phi, sx, sy, sz in pouch_list:
        G.pouch(gen, phi, (z0 + z1) / 2 - 0.01, 0.019 * k, (sx * k, sy * k, sz * k), "rubber_black" if mat != "leather_dark" else "leather_dark", w)
    if holster:
        phi = 1.62
        c = gen.torso_point(phi, 0.955, 0.024 * k)
        nrm = unit(v3(math.sin(phi), math.cos(phi), 0))
        ax = unit(np.cross(v3(0, 0, 1), nrm))
        hw = {"hips": 0.6, "thigh.R": 0.4}
        G.box(c, (0.06 * k, 0.04 * k, 0.17 * k), (ax, nrm, v3(0, 0, 1)), "rubber_black", hw, chamfer=0.006 * k)
        grip = c + v3(0, 0, 0.1 * k) - ax * 0.012 * k
        G.box(grip, (0.03 * k, 0.03 * k, 0.06 * k), (ax, nrm, v3(0, 0, 1)), "plastic_matte", hw, chamfer=0.004 * k)
    if pager:
        phi = -0.85
        c = gen.torso_point(phi, 1.0, 0.03 * k)
        nrm = unit(v3(math.sin(phi), math.cos(phi), 0))
        ax = unit(np.cross(v3(0, 0, 1), nrm))
        G.box(c, (0.045 * k, 0.022 * k, 0.065 * k), (ax, nrm, v3(0, 0, 1)), "plastic_matte", w, chamfer=0.004 * k)
        out["hip"] = (c + nrm * 0.012 * k, phi)
    if radio_hip:
        phi = -1.55
        c = gen.torso_point(phi, 1.0, 0.032 * k)
        nrm = unit(v3(math.sin(phi), math.cos(phi), 0))
        ax = unit(np.cross(v3(0, 0, 1), nrm))
        G.box(c, (0.055 * k, 0.03 * k, 0.1 * k), (ax, nrm, v3(0, 0, 1)), "plastic_matte", w, chamfer=0.004 * k)
        out.setdefault("hip", (c + nrm * 0.016 * k, phi))
    return out


def chest_radio(G: Gear, gen: BodyGen, phi: float = -0.48, z: float = 1.345) -> None:
    k = gen.k
    w = {"chest": 1.0}
    nrm = unit(v3(math.sin(phi), math.cos(phi), 0.15))
    ax = unit(np.cross(v3(0, 0, 1), nrm))
    az = np.cross(ax, nrm)
    c = gen.torso_point(phi, z, 0.026 * k)
    G.box(c, (0.052 * k, 0.03 * k, 0.085 * k), (ax, nrm, az), "plastic_matte", w, chamfer=0.005 * k)
    G.cylinder(c + az * 0.07 * k + ax * 0.012 * k, az, 0.0045 * k, 0.06 * k, "rubber_black", w, n=8)


def chest_badge(G: Gear, gen: BodyGen, mat: str, phi: float = 0.5, z: float = 1.35) -> None:
    k = gen.k
    nrm = unit(v3(math.sin(phi), math.cos(phi), 0.1))
    ax = unit(np.cross(v3(0, 0, 1), nrm))
    az = np.cross(ax, nrm)
    c = gen.torso_point(phi, z, 0.009 * k)
    G.box(c, (0.04 * k, 0.005 * k, 0.05 * k), (ax, nrm, az), mat, {"chest": 1.0}, chamfer=0.003 * k)


def arm_patches(G: Gear, gen: BodyGen, mat: str, s: float = 0.10, offset: float = 0.0055) -> None:
    for side in (-1, 1):
        sfx = "R" if side > 0 else "L"
        c, t, e1, e2 = gen.arm_axis(side, s)
        rd, rl = gen.arm_radius(s)
        nrm = unit(e1 * 0.95 - e2 * 0.3)
        centre = c + nrm * (rd + offset * gen.k)
        az = np.cross(t, nrm)
        G.box(centre, (0.075 * gen.k, 0.004 * gen.k, 0.062 * gen.k), (t, nrm, az), mat,
              {f"upper_arm.{sfx}": 1.0}, chamfer=0.0015 * gen.k)


def knee_pads(G: Gear, gen: BodyGen, mat: str) -> None:
    for side in (-1, 1):
        sfx = "R" if side > 0 else "L"
        knee = gen.J[f"shin.{sfx}"][0]
        c = knee + v3(0, 0.062 * gen.k, -0.025 * gen.k)
        G.box(c, (0.09 * gen.k, 0.03 * gen.k, 0.12 * gen.k), (v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)), mat,
              {f"shin.{sfx}": 0.75, f"thigh.{sfx}": 0.25}, chamfer=0.008 * gen.k)


def carrier_pouches(G: Gear, gen: BodyGen, mat: str) -> None:
    k = gen.k
    w = {"chest": 0.6, "spine": 0.4}
    for phi in (-0.36, 0.0, 0.36):
        nrm = unit(v3(math.sin(phi), math.cos(phi), 0))
        ax = unit(np.cross(v3(0, 0, 1), nrm))
        c = gen.torso_point(phi, 1.15, 0.065 * k)
        G.box(c, (0.07 * k, 0.04 * k, 0.12 * k), (ax, nrm, v3(0, 0, 1)), mat, w, chamfer=0.006 * k)
    # radio pouch on the left chest + admin pouch
    phi = -0.55
    nrm = unit(v3(math.sin(phi), math.cos(phi), 0))
    ax = unit(np.cross(v3(0, 0, 1), nrm))
    G.box(gen.torso_point(phi, 1.34, 0.06 * k), (0.06 * k, 0.04 * k, 0.11 * k), (ax, nrm, v3(0, 0, 1)), mat,
          {"chest": 1.0}, chamfer=0.006 * k)
    G.cylinder(gen.torso_point(phi, 1.43, 0.06 * k), v3(0, 0, 1), 0.005 * k, 0.09 * k, "rubber_black", {"chest": 1.0}, n=8)


def apron_panel(G: Gear, gen: BodyGen, mat: str) -> None:
    """Lower apron hanging from the waist to above the knee (weights blend hips -> both thighs)."""
    k = gen.k
    top, bot = [], []
    n = 11
    for i in range(n):
        u = -1.0 + 2.0 * i / (n - 1)
        phi = u * 0.95
        top.append(gen.torso_point(phi, 1.0, 0.016 * k))
        x = u * 0.19 * k
        bot.append(v3(x, 0.115 * k - 0.03 * k * u * u, 0.55 * k))

    def wfn(p: np.ndarray) -> dict:
        t = smoothstep(0.98 * k, 0.6 * k, p[2])
        side = smoothstep(-0.06 * k, 0.06 * k, p[0])
        return _dress_blend({"hips": 1.0}, {"thigh.L": 1.0 - side, "thigh.R": side}, t * 0.85)

    G.plate(top, bot, 0.005 * k, mat, wfn, rows=6, ref=v3(0, -0.2 * k, 0.8 * k))


def _dress_blend(a: dict, b: dict, t: float) -> dict:
    out: dict = {}
    for kk, x in a.items():
        out[kk] = out.get(kk, 0.0) + x * (1 - t)
    for kk, x in b.items():
        out[kk] = out.get(kk, 0.0) + x * t
    return {kk: x for kk, x in out.items() if x > 1e-4}


# ------------------------------------------------------------------------------------------
# characters
# ------------------------------------------------------------------------------------------
CHARACTERS = {
    "security_officer": dict(body=dict(scale=1.0, gender=0.0, build=0.35, age=0.35), skin="chr_skin_b",
                             hair=("crop", "chr_hair_brown")),
    "civilian_customer_m": dict(body=dict(scale=1.01, gender=0.0, build=0.0, age=0.4), skin="chr_skin_a",
                                hair=("short", "chr_hair_blond")),
    "civilian_customer_f": dict(body=dict(scale=0.955, gender=1.0, build=-0.2, age=0.3), skin="chr_skin_c",
                                hair=("bob", "chr_hair_auburn")),
    "civilian_associate": dict(body=dict(scale=0.95, gender=1.0, build=-0.3, age=0.15), skin="chr_skin_d",
                               hair=("bun", "chr_hair_black")),
    "civilian_jeweler": dict(body=dict(scale=0.975, gender=0.0, build=0.3, age=0.9), skin="chr_skin_a",
                             hair=("bald", "chr_hair_grey")),
    "patrol_officer": dict(body=dict(scale=1.02, gender=0.0, build=0.25, age=0.3), skin="chr_skin_d",
                           hair=("crop", "chr_hair_black")),
    "tac_light": dict(body=dict(scale=1.03, gender=0.0, build=0.5, age=0.25), skin="chr_skin_b",
                      hair=("crop", "chr_hair_brown")),
    "crew_body": dict(body=dict(scale=1.0, gender=0.0, build=0.1, age=0.3), skin="chr_skin_b",
                      hair=("short", "chr_hair_brown")),
}


def outfit(cid: str, gen: BodyGen, m: _body.Mesh):
    """Build the dressed body and the gear for character ``cid``.

    Returns dict(body=(P, F, M, W, flat), gear=(P, F, M, W), sockets={name: (pos, phi)})."""
    spec = CHARACTERS[cid]
    skin = spec["skin"]
    style, hair_mat = spec["hair"]
    G = Gear()
    shells = []
    sockets: dict = {}
    drop: tuple = ()
    cap_line = 9.0
    L: list[Layer] = []
    if cid == "security_officer":
        cap_line = 0.70
        L = [*face_layers(skin, hair_mat), *shoe_layers("leather_dark"),
             trousers("chr_security_trousers", waist=1.0), shirt("chr_security_shirt", waist=1.0, collar="closed", t=0.005)]
        cap_peaked(G, gen, "chr_cap_black", "chr_cap_black", "plastic_matte", "chr_badge_gold")
        sockets.update(duty_belt(G, gen, "leather_dark"))
        chest_radio(G, gen)
        chest_badge(G, gen, "chr_badge_gold")
        arm_patches(G, gen, "chr_security_patch")
    elif cid == "patrol_officer":
        cap_line = 0.70
        L = [*face_layers(skin, hair_mat), *shoe_layers("leather_dark"),
             trousers("chr_police_navy", waist=1.0), shirt("chr_police_navy", waist=1.0, collar="closed", t=0.005)]
        cap_peaked(G, gen, "chr_police_navy", "chr_hivis", "plastic_matte", "brushed_steel")
        sockets.update(duty_belt(G, gen, "rubber_black", radio_hip=True, pager=False))

        def vest_match(f: FaceInfo) -> bool:
            if f.part != "torso" or not 0.99 <= f.z <= 1.47:
                return False
            a = abs(f.phi)
            if f.z > 1.30 and 1.15 < a < 2.05:
                return False
            if f.z > 1.44 and a < 0.75:
                return False
            return True

        def vest_mat(f: FaceInfo) -> str:
            if 1.10 <= f.z <= 1.145 or 1.24 <= f.z <= 1.285:
                return "chr_hivis"
            return "chr_police_navy"

        shells.append(_dress.shell(m, gen, vest_match, vest_mat, 0.016, base_offset=0.005, rim_mat="chr_hivis"))
        chest_radio(G, gen, phi=-0.5, z=1.36)
        arm_patches(G, gen, "chr_hivis", offset=0.0055)
    elif cid == "tac_light":
        cap_line = 0.0
        drop = ("ear",)
        L = [Layer("eye", lambda f: f.part == "eye", lambda f: "chr_iris" if is_iris(f) else "chr_eye", 0.0),
             Layer("eyeskin", lambda f: f.part == "head" and abs(f.phi) < 0.85 and 0.39 <= f.zh <= 0.58, skin, 0.0),
             Layer("balaclava", lambda f: f.part == "head" or (f.part == "torso" and f.z > 1.49), "chr_tac_charcoal", 0.003),
             *shoe_layers("rubber_black", boot_s=0.60), gloves("rubber_black"),
             trousers("chr_tac_charcoal", waist=1.0, t=0.008, flare=0.004),
             shirt("chr_tac_charcoal", waist=1.0, collar="crew", cuff=0.515, t=0.006)]
        helmet(G, gen, "chr_tac_gear", "rubber_black")
        goggles(G, gen, "rubber_black", "chr_lens")

        def carrier(f: FaceInfo) -> bool:
            if f.part != "torso" or not 1.02 <= f.z <= 1.47:
                return False
            a = abs(f.phi)
            if f.z > 1.27 and 1.05 < a < 2.15:
                return False
            if f.z > 1.40 and (a < 0.62 or a > 2.5):
                return False
            return True

        shells.append(_dress.shell(m, gen, carrier, "chr_tac_gear", 0.028, base_offset=0.006))
        carrier_pouches(G, gen, "chr_tac_gear")
        sockets.update(duty_belt(G, gen, "rubber_black", holster=True, pager=False, radio_hip=False))
        knee_pads(G, gen, "rubber_black")
    elif cid == "civilian_customer_m":
        L = [*face_layers(skin, hair_mat), *shoe_layers("leather_dark"),
             trousers("chr_chino_khaki", waist=1.02), belt_layer("leather_dark", 1.005, 1.035),
             jacket("chr_suit_navy", v_bottom=1.12, hem_z=0.86),
             shirt("chr_shirt_blue", waist=1.02, collar="open", cuff=0.53)]
    elif cid == "civilian_customer_f":
        drop = ("ear",)
        L = [*face_layers(skin, hair_mat), *shoe_layers("chr_suit_black"),
             trousers("chr_slacks_grey", waist=1.04, hem=0.79, flare=0.012, t=0.007),
             shirt("chr_blouse_teal", waist=1.04, collar="blouse", cuff=0.47, t=0.006)]
    elif cid == "civilian_associate":
        L = [*face_layers(skin, hair_mat), *shoe_layers("chr_suit_black"),
             trousers("chr_suit_charcoal", waist=1.03, t=0.006),
             jacket("chr_suit_charcoal", v_bottom=1.17, hem_z=0.88),
             shirt("chr_shirt_white", waist=1.03, collar="blouse", cuff=0.53)]
        bun(G, gen, hair_mat)
        chest_badge(G, gen, "chr_badge_gold", phi=-0.62, z=1.33)
    elif cid == "civilian_jeweler":
        L = [*face_layers(skin, hair_mat), *shoe_layers("leather_dark"),
             trousers("chr_slacks_grey", waist=1.03),
             Layer("cuff", lambda f: f.part == "arm" and 0.355 <= f.s < 0.395, "chr_shirt_white", 0.011),
             shirt("chr_shirt_white", waist=1.03, collar="open", cuff=0.375)]

        def apron(f: FaceInfo) -> bool:
            return f.part == "torso" and 0.98 <= f.z <= 1.40 and abs(f.phi) < (0.95 if f.z < 1.3 else 0.55)

        shells.append(_dress.shell(m, gen, apron, "chr_apron_leather", 0.005, base_offset=0.007))
        apron_panel(G, gen, "chr_apron_leather")
        loupe(G, gen)
    elif cid == "crew_body":
        L = [*face_layers(skin, hair_mat), *shoe_layers("leather_dark"), gloves("leather_dark", cuff=0.52),
             trousers("chr_suit_black", waist=1.03), jacket("chr_suit_black", v_bottom=1.16),
             tie("chr_tie_burgundy", bottom=1.12), shirt("chr_shirt_white", waist=1.03, collar="closed", cuff=0.53)]
    else:
        raise KeyError(cid)
    L.append(hair_layer(style, hair_mat, cap_line))
    L.append(skin_layer(skin))
    body = _dress.dress(m, gen, L, drop_parts=drop)
    if shells:
        body = _dress.merge([body, *shells])
    gear = G.result()
    return {"body": body, "gear": gear, "sockets": sockets}


def standard_sockets(gen: BodyGen, extra: dict) -> dict:
    """Godot-space socket transforms (world rest pose) for Head / Back / Hip."""
    k = gen.k
    head = v3(0.0, _body.HEAD_AXIS_Y * k, gen.z_chin + 0.5 * gen.head_h)
    back = gen.torso_point(math.pi, 1.28, 0.02 * k)
    if "hip" in extra:
        hip = extra["hip"][0]
    else:
        hip = gen.torso_point(-1.2, 1.0, 0.02 * k)
    return {"Head": ("head", head), "Back": ("chest", back), "Hip": ("hips", hip)}


def build(cid: str):
    """Generate everything for character ``cid``: (gen, dressed body, gear, sockets)."""
    spec = CHARACTERS[cid]
    m, gen = _body.generate(BodyParams(**spec["body"]))
    out = outfit(cid, gen, m)
    out["sockets"] = standard_sockets(gen, out["sockets"])
    return gen, out

