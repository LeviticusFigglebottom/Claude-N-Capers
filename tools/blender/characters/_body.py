"""Parametric GSR humanoid body for ``rig_humanoid`` (D1-01).

Private helper (``_`` prefix), never built on its own. The geometry is **pure Python** (no bpy, no
numpy, no randomness); only ``build_body()`` / ``skin_to_rig()`` need Blender. Nothing comes from
third-party data: every form is generated from the numbers in this file.

How the body is made
* Torso, neck, arms, legs and feet: a hand-laid quad **cage** (12-sided torso/neck rings, 8-sided
  limb rings; arms grow from a 2x2-face hole in the chest side, legs from the split pelvis ring,
  the foot is the leg tube bent forward) refined by two levels of our own **Catmull-Clark**
  subdivision (pure math, so vertex order and boundary loops are known exactly).
* Head: a 48-column grid stitched to the subdivided neck ring and ray-cast onto a smooth **signed
  distance field** of simple forms (cranium, mid-face, jaw, chin, nose, brow, cheekbones, lips,
  eye sockets). Columns are denser at the face. Ears, eyes and eyebrows are separate small parts in
  the same mesh.
* Hands: a palm lofted from the subdivided wrist ring (stitched) plus 8-sided finger tubes that
  follow the finger bones of ``_rig``.
* Shape keys ``build``, ``gender``, ``age``: the same generator run at (1,0,0), (0,1,0), (0,0,1);
  the Basis is (0,0,0) = slim, masculine, young. Topology never depends on the parameters.
* Skin colour: one skin material on every skin face plus a ``lip`` region (the vermilion loops of
  the mouth, ``char_lip_<family>`` or the ``lip`` param, e.g. ``char_lip_rose``). The face colour
  (``skin_tint``: warm cheeks, nose and ears, a soft shade round the eyes, and the beard shadow) is
  baked by ``make_materials.py`` into the skin textures in body-UV space (the UVs come from the
  basis, so one atlas fits every body). ``beard_shadow`` (0..1) picks the material
  (``skin_material``): ``char_skin_<tone>`` (< 0.25), ``char_skin_<tone>_stubble`` (< 0.6) or
  ``char_skin_<tone>_beard``. (Vertex colours were tried first: the shared exporter settings,
  ``export_image_format="NONE"`` + ``export_vertex_color="MATERIAL"``, never export them.)
* Weights: distance from each vertex to the bone segments, divided by the bone's typical radius
  (``_rig.BONE_RADIUS``), turned into weights with an inverse power falloff, restricted to bones
  that make sense for the vertex's body region, max 4 influences, normalised. Deterministic.

Axes: Blender +Z up, the character faces +Y (= Godot -Z); right side = +X (``.R``). Metres.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from functools import lru_cache

import _head as _headmod
import _rig as rig

REF_HEIGHT = rig.DEFAULT_HEIGHT
TAU = 2.0 * math.pi
Vec = tuple[float, float, float]

#: Body regions; ``hide`` takes any subset. ``head`` includes eyes, ears and brows.
REGIONS = ("head", "neck", "torso", "pelvis", "upper_arms", "forearms", "hands", "thighs", "shins", "feet")

#: Skin tones (sRGB, albedo 8-bit values 30..240 per style guide §3). Library ids char_skin_1..6.
SKIN_TONES = ("#E3BFA3", "#D2A283", "#B7835F", "#956446", "#704630", "#4C3022")
#: Hair colours, library ids ``char_hair_<name>``.
HAIR_COLORS = {"dark": "#2B2420", "brown": "#5B3B26", "blond": "#B3925C", "grey": "#9A9690"}
EYE_COLOR = "#D9D3C8"          # char_eye (sclera)
IRIS_COLOR = "#6B4C34"         # char_eye_iris (iris ring; the pupil is char_lash)
LASH_COLOR = "#3B2E28"         # char_lash (upper lid margin / lash line, pupil)
#: Lip colours per skin-tone family (sRGB), library ids ``char_lip_<family>``; tones 1-2 light,
#: 3-4 mid, 5-6 deep. ``lip`` in the body params may name another ``char_lip_*`` id (lipstick).
LIP_COLORS = {"light": "#B47670", "mid": "#8C5248", "deep": "#58302B"}
LIP_FAMILY = ("light", "light", "mid", "mid", "deep", "deep")
HAIR_STYLES = _headmod.HAIR_STYLES   # none, buzz, short, side_part, bob, bald

#: Default parameters (``char_body_base``).
DEFAULTS: dict = {"height": REF_HEIGHT, "build": 0.4, "gender": 0.0, "age": 0.25, "skin": 2,
                  "hide": frozenset(), "hair": "short", "hair_color": "dark", "hair_peak": 0.0, "beard_shadow": 0.0,
                  "lip": "auto"}
#: Shape keys in export order and the generator configs that define them.
SHAPE_KEYS = ("build", "gender", "age")


def body_params(params: dict | None = None, **overrides) -> dict:
    """Complete, validated parameter dict (defaults filled in)."""
    p = dict(DEFAULTS)
    if params:
        p.update(params)
    p.update(overrides)
    unknown = set(p) - set(DEFAULTS)
    if unknown:
        raise ValueError(f"unknown body params {sorted(unknown)}")
    rig.scale_for(float(p["height"]))
    for k in SHAPE_KEYS:
        if not 0.0 <= float(p[k]) <= 1.0:
            raise ValueError(f"{k} must be in 0..1")
    if not 1 <= int(p["skin"]) <= len(SKIN_TONES):
        raise ValueError(f"skin must be 1..{len(SKIN_TONES)}")
    hide = frozenset(p["hide"])
    if hide - set(REGIONS):
        raise ValueError(f"unknown regions {sorted(hide - set(REGIONS))}")
    p["hide"] = hide
    if p["hair"] not in HAIR_STYLES:
        raise ValueError(f"hair must be one of {HAIR_STYLES}")
    if p["hair_color"] not in HAIR_COLORS:
        raise ValueError(f"hair_color must be one of {sorted(HAIR_COLORS)}")
    if not 0.0 <= float(p["hair_peak"]) <= 1.0:
        raise ValueError("hair_peak (widow's peak) must be in 0..1")
    if not 0.0 <= float(p["beard_shadow"]) <= 1.0:
        raise ValueError("beard_shadow must be in 0..1")
    if p["lip"] != "auto" and not str(p["lip"]).startswith("char_lip_"):
        raise ValueError("lip must be 'auto' or a char_lip_* material id")
    return p


#: beard_shadow thresholds and the strength each skin variant bakes (make_materials.py)
BEARD_LEVELS = (("", 0.0, 0.25), ("_stubble", 0.5, 0.6), ("_beard", 0.9, 1.01))


def skin_material(p: dict) -> str:
    """Library id of the skin for body params ``p`` (tone + beard level)."""
    b = float(p.get("beard_shadow", 0.0))
    sfx = next(s for s, _strength, hi in BEARD_LEVELS if b < hi)
    return f"char_skin_{int(p['skin'])}{sfx}"


def lip_material(p: dict) -> str:
    """Library id of the lip region for body params ``p``."""
    if p.get("lip", "auto") != "auto":
        return str(p["lip"])
    return "char_lip_" + LIP_FAMILY[int(p["skin"]) - 1]


# =============================================================================================
# small math
# =============================================================================================
add, sub, mul, dot, cross, norm, lerp = rig.add, rig.sub, rig.mul, rig.dot, rig.cross, rig.norm, rig.lerp
vlen = rig.length


def _clamp(x: float, a: float, b: float) -> float:
    return a if x < a else b if x > b else x


def smoothstep(e0: float, e1: float, x: float) -> float:
    t = _clamp((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _spow(x: float, e: float) -> float:
    return math.copysign(abs(x) ** e, x)


def _ortho(v: Vec, axis: Vec) -> Vec:
    return norm(sub(v, mul(axis, dot(v, axis))))


def _mix(base: float, cfg: tuple[float, float, float], d_build: float = 0.0, d_gender: float = 0.0,
         d_age: float = 0.0) -> float:
    return base + cfg[0] * d_build + cfg[1] * d_gender + cfg[2] * d_age


def _seg_dist(p: Vec, a: Vec, b: Vec) -> float:
    ab = sub(b, a)
    t = _clamp(dot(sub(p, a), ab) / max(dot(ab, ab), 1e-12), 0.0, 1.0)
    return vlen(sub(p, add(a, mul(ab, t))))


# =============================================================================================
# mesh container
# =============================================================================================
@dataclass
class MeshData:
    """Vertex/face soup. ``face_mat`` in {"skin","eye","iris","lash","brow","hair"}; ``vert_rigid`` maps a
    vertex to a single bone it is weighted to 100 % (eyes, ears, brows, fingertips...)."""

    verts: list = field(default_factory=list)
    faces: list = field(default_factory=list)
    face_region: list = field(default_factory=list)
    face_mat: list = field(default_factory=list)
    face_side: list = field(default_factory=list)      # -1 left, +1 right, 0 centre (UV tiles)
    vert_rigid: dict = field(default_factory=dict)
    vert_bones: dict = field(default_factory=dict)     # vertex -> allowed bone set override
    rings: dict = field(default_factory=dict)          # name -> ordered closed loop of vertex ids
    lash_extra: list = field(default_factory=list)     # upper-lid faces that become "lash" when gender > 0.5

    def v(self, p: Vec) -> int:
        self.verts.append((float(p[0]), float(p[1]), float(p[2])))
        return len(self.verts) - 1

    def face(self, idx, region: str, inside: Vec | None, mat: str = "skin", side: int = 0) -> None:
        """Add a face, flipping its winding so the normal points away from ``inside`` (``None``:
        keep the given winding)."""
        idx = list(idx)
        if inside is not None and _newell_dot(self.verts, idx, inside) < 0.0:
            idx.reverse()
        self.faces.append(tuple(idx))
        self.face_region.append(region)
        self.face_mat.append(mat)
        self.face_side.append(side)

    def band(self, a: list[int], b: list[int], region: str, inside: Vec | None, closed: bool = True,
             mat: str = "skin", side: int = 0, flip: bool = False) -> None:
        n = len(a)
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            q = (a[j], a[k], b[k], b[j])
            self.face(tuple(reversed(q)) if flip else q, region, inside, mat, side)

    def fan(self, ring: list[int], pole: int, region: str, inside: Vec | None, mat: str = "skin", side: int = 0,
            flip: bool = False) -> None:
        n = len(ring)
        for j in range(n):
            q = (ring[j], ring[(j + 1) % n], pole)
            self.face(tuple(reversed(q)) if flip else q, region, inside, mat, side)

    def tri_count(self) -> int:
        return sum(len(f) - 2 for f in self.faces)


def _newell_dot(verts: list, idx: list[int], inside: Vec) -> float:
    nx = ny = nz = 0.0
    cx = cy = cz = 0.0
    n = len(idx)
    for i in range(n):
        a = verts[idx[i]]
        b = verts[idx[(i + 1) % n]]
        nx += (a[1] - b[1]) * (a[2] + b[2])
        ny += (a[2] - b[2]) * (a[0] + b[0])
        nz += (a[0] - b[0]) * (a[1] + b[1])
        cx += a[0]
        cy += a[1]
        cz += a[2]
    c = (cx / n, cy / n, cz / n)
    return dot((nx, ny, nz), sub(c, inside))


# =============================================================================================
# Catmull-Clark (pure Python, deterministic order, boundary = cubic B-spline)
# =============================================================================================
def catmull_clark(md: MeshData) -> MeshData:
    """One level of Catmull-Clark subdivision. Rings are refined (vertex, edge, vertex, ...)."""
    verts, faces = md.verts, md.faces
    nv = len(verts)
    edge_faces: dict[tuple[int, int], list[int]] = {}
    for fi, f in enumerate(faces):
        for i in range(len(f)):
            a, b = f[i], f[(i + 1) % len(f)]
            edge_faces.setdefault((a, b) if a < b else (b, a), []).append(fi)
    fpts = []
    for f in faces:
        n = len(f)
        fpts.append((sum(verts[i][0] for i in f) / n, sum(verts[i][1] for i in f) / n,
                     sum(verts[i][2] for i in f) / n))
    out = MeshData()
    out.vert_rigid = dict(md.vert_rigid)
    out.vert_bones = dict(md.vert_bones)
    # vertex points
    v_faces: list[list[int]] = [[] for _ in range(nv)]
    v_edges: list[list[tuple[int, int]]] = [[] for _ in range(nv)]
    for fi, f in enumerate(faces):
        for i in f:
            v_faces[i].append(fi)
    for e in edge_faces:
        v_edges[e[0]].append(e)
        v_edges[e[1]].append(e)
    for vi in range(nv):
        p = verts[vi]
        bnd = [e for e in v_edges[vi] if len(edge_faces[e]) == 1]
        if bnd:
            if len(bnd) == 2:
                o = [e[0] if e[1] == vi else e[1] for e in bnd]
                q = add(mul(p, 0.75), mul(add(verts[o[0]], verts[o[1]]), 0.125))
            else:
                q = p
        elif not v_faces[vi]:
            q = p
        else:
            n = len(v_faces[vi])
            fq = mul(_vsum([fpts[f] for f in v_faces[vi]]), 1.0 / n)
            mids = [mul(add(verts[e[0]], verts[e[1]]), 0.5) for e in v_edges[vi]]
            r = mul(_vsum(mids), 1.0 / len(mids))
            q = mul(add(add(fq, mul(r, 2.0)), mul(p, n - 3.0)), 1.0 / n)
        out.verts.append(q)
    # edge points
    epi: dict[tuple[int, int], int] = {}
    for e, fl in edge_faces.items():
        a, b = verts[e[0]], verts[e[1]]
        if len(fl) == 2:
            q = mul(add(add(a, b), add(fpts[fl[0]], fpts[fl[1]])), 0.25)
        else:
            q = mul(add(a, b), 0.5)
        epi[e] = out.v(q)
    fpi = [out.v(c) for c in fpts]
    for fi, f in enumerate(faces):
        n = len(f)
        for i in range(n):
            a, b, c = f[i - 1], f[i], f[(i + 1) % n]
            e1 = (b, c) if b < c else (c, b)
            e0 = (a, b) if a < b else (b, a)
            out.faces.append((b, epi[e1], fpi[fi], epi[e0]))
            out.face_region.append(md.face_region[fi])
            out.face_mat.append(md.face_mat[fi])
            out.face_side.append(md.face_side[fi])
    for name, loop in md.rings.items():
        new = []
        for i in range(len(loop)):
            a, b = loop[i], loop[(i + 1) % len(loop)]
            new += [a, epi[(a, b) if a < b else (b, a)]]
        out.rings[name] = new
    return out


def _vsum(vs: list[Vec]) -> Vec:
    x = y = z = 0.0
    for v in vs:
        x += v[0]
        y += v[1]
        z += v[2]
    return (x, y, z)


# =============================================================================================
# cage: torso, neck, arms, legs, feet
# =============================================================================================
CC_COMP_12 = 1.045     # Catmull-Clark shrinks 12-gons ~4.5 %, 8-gons ~9 %: cage radii are inflated
CC_COMP_8 = 1.095


def _torso_ring(z: float, cy: float, rx: float, ryf: float, ryb: float, n: float) -> list[Vec]:
    pts = []
    for i in range(12):
        th = math.radians(30.0 * i)
        s, c = math.sin(th), math.cos(th)
        e = 2.0 / n
        x = rx * CC_COMP_12 * _spow(s, e)
        y = cy + (ryf if c > 0 else ryb) * CC_COMP_12 * _spow(c, e)
        pts.append((x, y, z))
    return pts


def _limb_ring(c: Vec, fwd: Vec, out_: Vec, rf: float, rb: float, r_out: float, r_in: float,
               start_deg: float = -45.0, n: int = 8, e: float = 1.0) -> list[Vec]:
    """Ring of ``n`` points; vertex k at angle start+360k/n from ``fwd`` towards ``out_``."""
    pts = []
    for k in range(n):
        a = math.radians(start_deg + 360.0 * k / n)
        ca, sa = math.cos(a), math.sin(a)
        f = (rf if ca > 0 else rb) * CC_COMP_8 * _spow(ca, e)
        o = (r_out if sa > 0 else r_in) * CC_COMP_8 * _spow(sa, e)
        pts.append(add(c, add(mul(fwd, f), mul(out_, o))))
    return pts


def _cage(build: float, gender: float, age: float) -> MeshData:
    cfg = (build, gender, age)
    md = MeshData()
    segs = rig.bone_segments(REF_HEIGHT)

    def m(base, db=0.0, dg=0.0, da=0.0):
        return _mix(base, cfg, db, dg, da)

    # ---- torso rings: (name, z, cy, rx, ryf, ryb, superellipse n) ------------------------
    spec = [
        ("P0", 0.905, m(-0.006, 0, -0.004), m(0.163, 0.026, 0.012), m(0.081, 0.022, -0.004), m(0.101, 0.020, 0.014), 2.4),
        ("P1", 0.985, m(-0.005, 0, -0.004), m(0.162, 0.028, 0.010, 0.004), m(0.087, 0.030, -0.004, 0.010), m(0.104, 0.020, 0.012, -0.004), 2.4),
        ("P2", 1.070, m(0.000), m(0.137, 0.036, -0.016, 0.016), m(0.085, 0.052, -0.010, 0.030), m(0.083, 0.012, -0.004), 2.3),
        ("T0", 1.160, m(0.000), m(0.148, 0.038, -0.016, 0.006), m(0.097, 0.050, -0.008, 0.016), m(0.091, 0.016, -0.004, 0.004), 2.3),
        ("T1", 1.260, m(0.000), m(0.165, 0.032, -0.020, -0.004), m(0.114, 0.034, -0.006, -0.008), m(0.099, 0.016, -0.006, 0.008), 2.4),
        ("T2", 1.345, m(-0.005), m(0.170, 0.026, -0.020, -0.004), m(0.104, 0.022, -0.004, -0.006), m(0.101, 0.016, -0.006, 0.012), 2.5),
        ("T3", 1.415, m(-0.010, 0.0, 0.0, 0.006), m(0.160, 0.020, -0.018), m(0.090, 0.014, -0.006, -0.004), m(0.100, 0.014, -0.006, 0.016), 2.5),
    ]
    rings: dict[str, list[int]] = {}
    for name, z, cy, rx, ryf, ryb, n in spec:
        pts = _torso_ring(z, cy, rx, ryf, ryb, n)
        if name == "P0":   # crotch / groin / buttock crease
            for i, dz in ((0, -0.035), (1, -0.016), (11, -0.016), (6, -0.028), (5, -0.022), (7, -0.022)):
                pts[i] = (pts[i][0], pts[i][1], pts[i][2] + dz)
        if name == "T1":   # chest / bust (gender) at the 30 degree columns
            for i in (1, 11):
                p = pts[i]
                pts[i] = (p[0] * (1.0 - 0.06 * gender), p[1] + 0.034 * gender + 0.006 * build, p[2] - 0.012 * gender)
        if name == "T0":
            for i in (1, 11):
                p = pts[i]
                pts[i] = (p[0], p[1] + 0.012 * gender, p[2])
        rings[name] = [md.v(p) for p in pts]
    # shoulder-top ring T4 (only the non-arm columns are free; 2,3,4 / 8,9,10 = arm loop tops)
    t4: dict[int, Vec] = {
        0: (0.0, m(0.062, 0.014, -0.004), 1.452),
        1: (m(0.075, 0.010, -0.006), m(0.070, 0.016, -0.004), m(1.462, 0, -0.004)),
        5: (m(0.080, 0.012, -0.008), m(-0.078, -0.014, 0.0, -0.008), m(1.482, 0.004, -0.006, -0.004)),
        6: (0.0, m(-0.086, -0.014, 0.0, -0.010), m(1.476, 0.0, -0.004)),
    }
    for i in (7, 11):
        src = t4[12 - i]
        t4[i] = (-src[0], src[1], src[2])
    # arm loops (8 points each) replace torso verts around the shoulder
    arm_loops: dict[str, list[int]] = {}
    t4_ids: dict[int, int] = {}
    for sfx, sx in rig.SIDES:
        tilt = math.radians(14.0)
        c0 = (sx * m(0.165, 0.016, -0.014), m(-0.012, 0.0, 0.0, 0.008), m(1.410, 0.0, -0.004, -0.008))
        u0 = (sx * math.sin(tilt), 0.0, math.cos(tilt))
        r_up, r_dn, r_f, r_b = m(0.074, 0.010, -0.008), m(0.070, 0.012, -0.006), m(0.055, 0.012, -0.006), m(0.058, 0.012, -0.006)
        loop = []
        for k in range(8):
            ph = math.radians(45.0 * k)
            cu, su = math.cos(ph), math.sin(ph)
            q = add(c0, add(mul(u0, (r_up if cu > 0 else r_dn) * cu), (0.0, (r_f if su > 0 else r_b) * su, 0.0)))
            loop.append(md.v(q))
        arm_loops[sfx] = loop
        # torso index map: k -> (ring, column)
        cols = (3, 2, 4) if sx > 0 else (9, 10, 8)   # side, front, back columns
        top, front, bottom, back = cols[0], cols[1], cols[0], cols[2]
        rings["T4_" + sfx] = []
        t4_ids[top] = loop[0]
        t4_ids[front] = loop[1]
        t4_ids[back] = loop[7]
        rings["T3"][front] = loop[2]
        rings["T2"][front] = loop[3]
        rings["T2"][bottom] = loop[4]
        rings["T2"][back] = loop[5]
        rings["T3"][back] = loop[6]
    for i, p in t4.items():
        t4_ids[i] = md.v(p)
    rings["T4"] = [t4_ids[i] for i in range(12)]
    # neck rings (tilted: low at the front, high at the back)
    for name, zf, zb, cy, rx, ry in (
        ("N0", 1.478, m(1.506, 0.0, 0.0, -0.006), m(-0.028, 0.0, 0.0, 0.010), m(0.064, 0.014, -0.008, -0.002), m(0.060, 0.012, -0.008)),
        ("N1", 1.548, m(1.598, 0.0, 0.0, -0.004), m(-0.020, 0.0, 0.0, 0.010), m(0.057, 0.012, -0.008, -0.003), m(0.054, 0.012, -0.008, -0.002)),
    ):
        pts = []
        for i in range(12):
            th = math.radians(30.0 * i)
            z = 0.5 * (zf + zb) + 0.5 * (zf - zb) * math.cos(th)
            pts.append((rx * CC_COMP_12 * math.sin(th), cy + ry * CC_COMP_12 * math.cos(th), z))
        rings[name] = [md.v(p) for p in pts]

    order = ["P0", "P1", "P2", "T0", "T1", "T2", "T3", "T4", "N0", "N1"]
    region_of = {"P0": "pelvis", "P1": "pelvis", "P2": "torso", "T0": "torso", "T1": "torso", "T2": "torso",
                 "T3": "torso", "T4": "torso", "N0": "neck"}
    arm_faces = {("T2", 2), ("T2", 3), ("T3", 2), ("T3", 3), ("T2", 8), ("T2", 9), ("T3", 8), ("T3", 9)}
    for a, b in zip(order, order[1:]):
        ra, rb = rings[a], rings[b]
        za = sum(md.verts[i][2] for i in ra) / 12.0
        zb = sum(md.verts[i][2] for i in rb) / 12.0
        inside = (0.0, -0.01, 0.5 * (za + zb))
        for j in range(12):
            if (a, j) in arm_faces:
                continue
            k = (j + 1) % 12
            md.face((ra[j], ra[k], rb[k], rb[j]), region_of[a], inside)
    md.rings["neck_top"] = list(rings["N1"])
    md.rings["neck"] = list(rings["N0"])
    for nm, key in (("hips", "P1"), ("waist", "P2"), ("chest", "T1"), ("underbust", "T0")):
        md.rings[nm] = list(rings[key])

    # ---- arms --------------------------------------------------------------------------------
    for sfx, sx in rig.SIDES:
        sh, el = segs[f"upper_arm.{sfx}"][0], segs[f"upper_arm.{sfx}"][1]
        wr = segs[f"forearm.{sfx}"][1]
        d1 = norm(sub(el, sh))
        d2 = norm(sub(wr, el))
        prev = arm_loops[sfx]
        spec_arm = [
            # (point, dir, r_up, r_dn, r_f, r_b, up offset, region, ring name)
            (add(sh, mul(d1, 0.045)), norm(add(d1, (sx * 0.9, 0.0, 0.0))), m(0.060, 0.014, -0.012, -0.004),
             m(0.050, 0.012, -0.008), m(0.054, 0.012, -0.012, -0.002), m(0.056, 0.012, -0.010, -0.002), 0.010,
             "upper_arms", "deltoid"),
            (add(sh, mul(d1, 0.15)), d1, m(0.045, 0.014, -0.008, -0.002), m(0.046, 0.016, -0.006), m(0.047, 0.014, -0.008, -0.002),
             m(0.045, 0.014, -0.008), 0.0, "upper_arms", "upper_arm"),
            (el, norm(add(d1, d2)), m(0.037, 0.010, -0.005), m(0.040, 0.010, -0.005), m(0.040, 0.010, -0.006),
             m(0.041, 0.010, -0.006), 0.0, "upper_arms", "elbow"),
            (add(el, mul(d2, 0.075)), d2, m(0.041, 0.010, -0.007), m(0.038, 0.010, -0.007), m(0.043, 0.010, -0.007),
             m(0.040, 0.010, -0.007), 0.0, "forearms", "forearm"),
            (wr, d2, m(0.0185, 0.003, -0.002), m(0.0195, 0.003, -0.002), m(0.0285, 0.003, -0.003), m(0.0285, 0.003, -0.003),
             0.0, "forearms", "wrist"),
        ]
        for c, d, ru, rd, rf, rbk, off, region, rname in spec_arm:
            up = _ortho((0.0, 0.0, 1.0), d)
            fw = _ortho((0.0, 1.0, 0.0), d)
            cc = add(c, mul(up, off))
            pts = []
            for k in range(8):
                ph = math.radians(45.0 * k)
                cu, su = math.cos(ph), math.sin(ph)
                pts.append(add(cc, add(mul(up, (ru if cu > 0 else rd) * CC_COMP_8 * cu),
                                       mul(fw, (rf if su > 0 else rbk) * CC_COMP_8 * su))))
            ring = [md.v(p) for p in pts]
            md.band(prev, ring, region, sub(c, mul(d, 0.02)), side=int(sx))
            if rname:
                md.rings[f"{rname}.{sfx}"] = list(ring)
            prev = ring
        md.rings[f"wrist_open.{sfx}"] = list(prev)

    # ---- legs + feet ---------------------------------------------------------------------------
    p0 = rings["P0"]
    crotch = md.v((0.0, m(-0.008, 0.0, -0.004), m(0.838, 0.0, 0.006)))
    for sfx, sx in rig.SIDES:
        cols = [0, 1, 2, 3, 4, 5, 6] if sx > 0 else [0, 11, 10, 9, 8, 7, 6]
        loop = [p0[c] for c in cols] + [crotch]
        out_ = (sx, 0.0, 0.0)
        leg_spec = [
            # (centre, fwd axis, rf, rb, r_out, r_in, region, ring name)
            ((sx * m(0.093, 0.010, 0.008), -0.006, 0.80), (0, 1, 0), m(0.078, 0.022, 0.0), m(0.086, 0.022, 0.012),
             m(0.086, 0.020, 0.012), m(0.072, 0.022, 0.006), "thighs", "thigh"),
            ((sx * m(0.095, 0.006, 0.004), 0.0, 0.66), (0, 1, 0), m(0.068, 0.016, -0.002), m(0.070, 0.016, 0.002),
             m(0.070, 0.016, 0.004), m(0.064, 0.016, 0.004), "thighs", None),
            ((sx * 0.097, 0.010, 0.505), (0, 1, 0), m(0.054, 0.008, -0.004), m(0.048, 0.008, -0.004),
             m(0.051, 0.008, -0.002), m(0.050, 0.010, 0.0), "shins", "knee"),
            ((sx * 0.099, -0.006, 0.37), (0, 1, 0), m(0.043, 0.008, -0.004), m(0.060, 0.012, -0.006, -0.004),
             m(0.050, 0.010, -0.004), m(0.049, 0.010, -0.004), "shins", "calf"),
            ((sx * 0.100, -0.014, 0.125), (0, 1, 0), m(0.031, 0.004, -0.003), m(0.031, 0.004, -0.003),
             m(0.032, 0.004, -0.003), m(0.030, 0.004, -0.003), "shins", "ankle"),
            ((sx * 0.102, 0.000, 0.052), norm((0.0, 0.75, 0.66)), m(0.046, 0.004, -0.004), m(0.068, 0.004, -0.006),
             m(0.039, 0.004, -0.003), m(0.037, 0.004, -0.003), "feet", None),
            ((sx * 0.109, 0.118, 0.030), (0, 0, 1), m(0.027, 0.002, -0.002), m(0.034, 0.002, -0.002),
             m(0.050, 0.004, -0.005), m(0.046, 0.004, -0.004), "feet", "ball"),
            ((sx * 0.112, 0.208, 0.020), (0, 0, 1), m(0.015, 0.001, -0.001), m(0.021, 0.001, -0.001),
             m(0.036, 0.002, -0.003), m(0.034, 0.002, -0.003), "feet", None),
        ]
        prev = loop
        prev_c = (sx * 0.09, 0.0, 0.88)
        for c, fwd, rf, rbk, ro, ri, region, rname in leg_spec:
            fwd = norm(fwd)
            ring = [md.v(p) for p in _limb_ring(c, fwd, out_, rf, rbk, ro, ri)]
            md.band(prev, ring, region if region != "thighs" or prev is not loop else "thighs",
                    lerp(prev_c, c, 0.5), side=int(sx))
            if rname:
                md.rings[f"{rname}.{sfx}"] = list(ring)
            prev, prev_c = ring, c
        # toe cap: 3 quads closing the last 8-ring
        r = prev
        inside = (prev_c[0], prev_c[1] - 0.02, prev_c[2])
        for q in ((r[0], r[1], r[2], r[3]), (r[0], r[3], r[4], r[7]), (r[4], r[5], r[6], r[7])):
            md.face(q, "feet", inside, side=int(sx))
    return md


# =============================================================================================
# head: the production GSR head lives in _head.py (field, grid + eye/nose/mouth loops, eyes, ears,
# brows, hair). Re-exported here for compatibility.
# =============================================================================================
HEAD_CENTRE: Vec = _headmod.HEAD_CENTRE
EYE_RADIUS = _headmod.EYE_RADIUS
EYE_LOCAL: Vec = _headmod.EYE_LOCAL
HEAD_TAPER = 0.20               # legacy constant (the old head's plan-view taper), kept for importers
HeadShape = _headmod.HeadShape
HEAD_ROWS = _headmod.HEAD_ROWS


# =============================================================================================
# hands
# =============================================================================================
FINGER_RADIUS = {"thumb": 0.0108, "index": 0.0090, "middle": 0.0093, "ring": 0.0088, "pinky": 0.0078}


def _hand(md: MeshData, sfx: str, sx: float, build: float, gender: float) -> None:
    segs = rig.bone_segments(REF_HEIGHT)
    hf = rig.hand_frame(sx, REF_HEIGHT)
    w0, al, fw, back = hf["origin"], hf["along"], hf["fwd"], hf["back"]
    hh = rig.HEAD_HAND_SCALE
    thick = 1.0 + 0.10 * build - 0.07 * gender
    side = int(sx)
    wrist = md.rings[f"wrist_open.{sfx}"]
    angs = []
    for vi in wrist:
        q = sub(md.verts[vi], w0)
        angs.append(math.atan2(dot(q, fw), dot(q, back)))
    # palm rings: (t along, half width, dorsal, palmar)
    palm_spec = [(0.016, 0.031, 0.0165, 0.0185), (0.036, 0.037, 0.0145, 0.0195), (0.056, 0.0415, 0.0135, 0.0175),
                 (0.074, 0.0435, 0.0125, 0.0145), (0.088, 0.0425, 0.0105, 0.0105)]
    prev = wrist
    prev_c = w0
    for t, hw, td, tp in palm_spec:
        c = add(w0, mul(al, t * hh))
        ring = []
        for a in angs:
            ca, sa = math.cos(a), math.sin(a)
            dd = (td if ca > 0 else tp) * hh * thick
            if ca < 0 and sa > 0 and t < 0.07:      # thenar pad on the thumb side of the palm
                dd += 0.005 * sa * (-ca) * (1.0 - t / 0.07)
            ww = hw * hh * (1.0 + 0.04 * build - 0.05 * gender)
            if sa > 0 and t < 0.06:                 # thenar mass widens the thumb side
                ww *= 1.0 + 0.22 * (1.0 - t / 0.06) * max(0.0, -ca + 0.3)
            ring.append(md.v(add(c, add(mul(back, dd * _spow(ca, 0.7)), mul(fw, ww * _spow(sa, 0.7))))))
        md.band(prev, ring, "hands", lerp(prev_c, c, 0.5), side=side)
        prev, prev_c = ring, c
    # knuckle cap: strip of quads across the thickness, pinky side (24) -> thumb side (8)
    n = len(prev)
    q4 = n // 4
    pairs = [((3 * q4 + j) % n, (3 * q4 - j) % n) for j in range(q4 + 1)]   # 24/24 .. 0/16
    pairs += [(j, (2 * q4 - j) % n) for j in range(1, q4 + 1)]               # 1/15 .. 8/8
    inside = sub(prev_c, mul(al, 0.01))
    pairs = [(prev[a], prev[b]) for a, b in pairs]
    for (a0, b0), (a1, b1) in zip(pairs, pairs[1:]):
        if a0 == b0:
            md.face((a0, a1, b1), "hands", inside, side=side)
        elif a1 == b1:
            md.face((a0, a1, b0), "hands", inside, side=side)
        else:
            md.face((a0, a1, b1, b0), "hands", inside, side=side)
    # fingers
    for f in rig.FINGERS:
        chain = [segs[f"{f}_0{i}.{sfx}"] for i in (1, 2, 3)]
        r0 = FINGER_RADIUS[f] * hh * thick
        d0 = norm(sub(chain[0][1], chain[0][0]))
        pts: list[tuple[Vec, Vec, float, str]] = []
        start_back = 0.016 if f == "thumb" else 0.013
        pts.append((sub(chain[0][0], mul(d0, start_back)), d0, r0 * (1.25 if f == "thumb" else 0.95), f"{f}_01.{sfx}"))
        for i, (h, t, _r) in enumerate(chain):
            d = norm(sub(t, h))
            dj = d if i == 0 else norm(add(d, norm(sub(chain[i - 1][1], chain[i - 1][0]))))
            taper = 1.0 - 0.07 * i
            rr = r0 * taper * (1.22 if (f == "thumb" and i == 0) else 1.0)
            pts.append((h, dj, rr * (1.04 if i else 1.0), f"{f}_0{i + 1}.{sfx}"))
            if i == 0:
                pts.append((lerp(h, t, 0.5), d, rr * 0.95, f"{f}_0{i + 1}.{sfx}"))
        h, t, _r = chain[2]
        d = norm(sub(t, h))
        rr = r0 * 0.84
        pts.append((lerp(h, t, 0.86), d, rr * 0.9, f"{f}_03.{sfx}"))
        pts.append((add(t, mul(d, -0.002)), d, rr * 0.55, f"{f}_03.{sfx}"))
        prev_ring = None
        prev_p = None
        for p, d, rr, bone in pts:
            bk = _ortho(back, d)
            sd = norm(cross(d, bk))
            ring = []
            for k in range(8):
                a = math.radians(22.5 + 45.0 * k)
                ca, sa = math.cos(a), math.sin(a)
                # flatter on the back (nail side), fuller pad on the palm side
                rb_ = rr * (0.86 if ca > 0 else 1.0)
                vi = md.v(add(p, add(mul(bk, rb_ * ca), mul(sd, rr * 1.08 * sa))))
                md.vert_bones[vi] = frozenset({bone, f"hand.{sfx}"} | _chain_neighbours(bone))
                ring.append(vi)
            if prev_ring is not None:
                md.band(prev_ring, ring, "hands", sub(lerp(prev_p, p, 0.5), mul(d, 0.0)), side=side)
            prev_ring, prev_p = ring, p
        tip = md.v(add(chain[2][1], mul(norm(sub(chain[2][1], chain[2][0])), 0.0025)))
        md.vert_bones[tip] = frozenset({f"{f}_03.{sfx}"})
        md.fan(prev_ring, tip, "hands", sub(prev_p, mul(d, 0.004)), side=side)


def _chain_neighbours(bone: str) -> set[str]:
    name, sfx = bone.split(".")
    f, idx = name.rsplit("_", 1)
    i = int(idx)
    out = set()
    for j in (i - 1, i + 1):
        if 1 <= j <= 3:
            out.add(f"{f}_0{j}.{sfx}")
    return out


# =============================================================================================
# assembly
# =============================================================================================
@lru_cache(maxsize=8)
def _generate_body(build: float, gender: float, age: float) -> tuple[MeshData, HeadShape]:
    """Full body (nothing hidden) at the reference height 1.78 m, plus its head field."""
    md = _cage(build, gender, age)
    md = catmull_clark(md)
    md = catmull_clark(md)
    # flat soles
    for i, p in enumerate(md.verts):
        if p[2] < 0.0:
            md.verts[i] = (p[0], p[1], 0.0)
    neck = [md.verts[i] for i in md.rings["neck_top"]]
    cy = sum(p[1] for p in neck) / len(neck)
    rx = max(abs(p[0]) for p in neck)
    ry = 0.5 * (max(p[1] for p in neck) - min(p[1] for p in neck))
    hs = HeadShape(build, gender, age, cy - HEAD_CENTRE[1], rx, ry)
    ref = None
    # the build and age keys re-seat the basis vertices on their surface (no sliding between keys);
    # the gender key changes the face too much for that (the re-seated grid bunches round the mouth
    # and chin), so it is generated natively: same grid, same indices, its own cast + relax
    if (build, gender, age) != (0.0, 0.0, 0.0) and gender == 0.0:
        base_md, base_hs = _generate_body(0.0, 0.0, 0.0)
        ref = (base_md.verts, base_hs, base_md.head_free)
    md.head_free = _headmod.head(md, hs, ref)
    _headmod.eyes(md)
    _headmod.ears(md, hs)
    _headmod.brows(md, hs)
    for sfx, sx in rig.SIDES:
        _hand(md, sfx, sx, build, gender)
    return md, hs


@lru_cache(maxsize=16)
def _generate(build: float, gender: float, age: float, hair: str, peak: float = 0.0) -> tuple[MeshData, MeshData]:
    """(body, hair) at the reference height 1.78 m, full (nothing hidden)."""
    md, hs = _generate_body(build, gender, age)
    return md, _headmod.hair(hs, hair, peak)


def _configs() -> list[tuple[float, float, float]]:
    return [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]


@dataclass
class BodyData:
    """Final, scaled, hidden-filtered data for one variant. ``keys[name]`` are absolute vertex
    positions of each shape key (Basis = ``basis``); ``blend`` = positions at the variant's values."""

    params: dict
    faces: list
    face_region: list
    face_mat: list
    face_side: list
    basis: list
    keys: dict
    blend: list
    rigid: dict
    allowed: dict
    rings: dict


def _assemble(parts: list[MeshData], p: dict, hide: frozenset) -> BodyData:
    k = float(p["height"]) / REF_HEIGHT
    base = parts[0]
    keep_f = [i for i, r in enumerate(base.face_region) if r not in hide]
    used = sorted({v for i in keep_f for v in base.faces[i]})
    remap = {v: n for n, v in enumerate(used)}

    def pos(md: MeshData) -> list[Vec]:
        return [mul(md.verts[v], k) for v in used]

    basis = pos(parts[0])
    keys = {name: pos(md) for name, md in zip(SHAPE_KEYS, parts[1:])}
    blend = [list(b) for b in basis]
    for name in SHAPE_KEYS:
        w = float(p[name])
        if w:
            for i, (b, q) in enumerate(zip(basis, keys[name])):
                blend[i][0] += w * (q[0] - b[0])
                blend[i][1] += w * (q[1] - b[1])
                blend[i][2] += w * (q[2] - b[2])
    rings = {}
    for name, loop in base.rings.items():
        if all(v in remap for v in loop):
            rings[name] = [remap[v] for v in loop]
    mats = list(base.face_mat)
    if float(p["gender"]) > 0.5:          # thicker upper lash line
        for i in base.lash_extra:
            mats[i] = "lash"
    return BodyData(
        params=p,
        faces=[tuple(remap[v] for v in base.faces[i]) for i in keep_f],
        face_region=[base.face_region[i] for i in keep_f],
        face_mat=[mats[i] for i in keep_f],
        face_side=[base.face_side[i] for i in keep_f],
        basis=basis, keys=keys, blend=[tuple(b) for b in blend],
        rigid={remap[v]: b for v, b in base.vert_rigid.items() if v in remap},
        allowed={remap[v]: b for v, b in base.vert_bones.items() if v in remap},
        rings=rings,
    )


def body_mesh_data(params: dict | None = None) -> tuple[BodyData, BodyData]:
    """(body, hair) data for ``params`` (see ``DEFAULTS``). Pure math; hair has no faces for "none"."""
    p = body_params(params)
    gens = [_generate(b, g, a, p["hair"], float(p["hair_peak"])) for b, g, a in _configs()]
    for g in gens[1:]:
        for i in (0, 1):
            if [sorted(f) for f in g[i].faces] != [sorted(f) for f in gens[0][i].faces]:
                raise AssertionError("shape-key configs produced different topology")
    body = _assemble([g[0] for g in gens], p, p["hide"])
    hair = _assemble([g[1] for g in gens], p, frozenset())
    return body, hair


# =============================================================================================
# landmarks (for outfit fitting)
# =============================================================================================
def _ring_stats(pts: list[Vec]) -> dict:
    n = len(pts)
    c = mul(_vsum(pts), 1.0 / n)
    circ = sum(vlen(sub(pts[i], pts[(i + 1) % n])) for i in range(n))
    return {"centre": c, "circumference": circ, "radius": circ / TAU,
            "half_width": 0.5 * (max(p[0] for p in pts) - min(p[0] for p in pts)),
            "front": max(p[1] for p in pts) - c[1], "back": c[1] - min(p[1] for p in pts),
            "z": c[2], "z_min": min(p[2] for p in pts), "z_max": max(p[2] for p in pts)}


def body_rings(params: dict | None = None) -> dict[str, list[Vec]]:
    """Ordered closed loops of surface points (variant's blended shape, metres) at the named
    sections: ``neck, neck_top, chest, underbust, waist, hips, head_brow`` and per side
    ``deltoid, upper_arm, elbow, forearm, wrist, thigh, knee, calf, ankle, ball`` + ``.L``/``.R``.
    Torso/neck loops have 48 points, limb loops 32, ``head_brow`` 58. Offset them outwards along
    (point - centre) to loft garments that sit just outside the skin."""
    p = body_params(params, hide=frozenset())
    body, _hair = body_mesh_data(p)
    out = {}
    for name, loop in body.rings.items():
        if name.startswith(("wrist_open", "T4_")):
            continue
        out[name] = [body.blend[i] for i in loop]
    return out


def landmarks(params: dict | None = None) -> dict:
    """Body measurements of the variant (metres, Blender axes), measured on the generated mesh.

    Ring entries (``neck, neck_top, chest, underbust, waist, hips`` and per side ``deltoid,
    upper_arm, elbow, forearm, wrist, thigh, knee, calf, ankle, ball`` + ``.L/.R``) map to
    ``{centre, circumference, radius, half_width, front, back, z, z_min, z_max}``. Also:
    ``height`` (crown), ``shoulder_width`` (outer deltoid to deltoid), ``hip_width``,
    ``head`` (``circumference`` at the brow, ``top_z``, ``half_width``, ``front``, ``back``),
    ``eye.L/R`` (eye centres), ``sole_z`` (0)."""
    p = body_params(params, hide=frozenset())
    body, _hair = body_mesh_data(p)
    rings = body_rings(p)
    out: dict = {}
    for name, pts in rings.items():
        if name == "head_brow":
            continue
        out[name] = _ring_stats(pts)
    head = _ring_stats(rings["head_brow"])
    head_idx = sorted({v for f, r in zip(body.faces, body.face_region) if r == "head" for v in f})
    top = max(body.blend[i][2] for i in head_idx)
    out["head"] = {"circumference": head["circumference"], "top_z": top, "half_width": head["half_width"],
                   "front": head["front"], "back": head["back"], "centre": head["centre"]}
    out["height"] = top
    out["shoulder_width"] = max(q[0] for q in rings["deltoid.R"]) - min(q[0] for q in rings["deltoid.L"])
    out["hip_width"] = 2.0 * out["hips"]["half_width"]
    j = rig.joints(float(p["height"]))
    for sfx, _sx in rig.SIDES:
        out[f"eye.{sfx}"] = j[f"eye.{sfx}"]
    out["sole_z"] = 0.0
    return out


# =============================================================================================
# skin weights (pure math)
# =============================================================================================
_REGION_BONES = {
    "head": ("head", "neck"),
    "neck": ("neck", "head", "chest", "clavicle.{s}"),
    "torso": ("chest", "spine", "hips", "neck", "clavicle.{s}", "upper_arm.{s}"),
    "pelvis": ("hips", "spine", "thigh.{s}"),
    "upper_arms": ("upper_arm.{s}", "forearm.{s}", "clavicle.{s}", "chest"),
    "forearms": ("forearm.{s}", "upper_arm.{s}", "hand.{s}"),
    "hands": ("hand.{s}", "forearm.{s}"),
    "thighs": ("thigh.{s}", "hips", "shin.{s}"),
    "shins": ("shin.{s}", "thigh.{s}", "foot.{s}"),
    "feet": ("foot.{s}", "toe.{s}", "shin.{s}"),
}

#: Bone segments used for distance skinning where the real bone is a poor proxy for the flesh.
def _skin_segments(height: float) -> dict[str, tuple[Vec, Vec]]:
    k = height / REF_HEIGHT
    segs = {b: (h, t) for b, (h, t, _r) in rig.bone_segments(height).items() if b != "root"}
    h, t = segs["head"]
    segs["head"] = (add(h, (0.0, 0.012 * k, 0.045 * k)), t)
    segs["hips"] = ((0.0, -0.01 * k, 0.86 * k), (0.0, -0.01 * k, 1.0 * k))
    for sfx, sx in rig.SIDES:
        a, b = segs[f"foot.{sfx}"]
        segs[f"foot.{sfx}"] = ((a[0], a[1] - 0.045 * k, a[2] - 0.035 * k), (b[0], b[1], b[2]))
    return segs


def skin_weights(points: list[Vec], height: float = REF_HEIGHT, candidates: list | None = None,
                 power: float = 6.0, max_influences: int = 4) -> list[dict[str, float]]:
    """Deterministic weights ``[{bone: w}]`` for ``points`` (rest pose, metres).

    For each candidate bone: s = distance to its segment / (``_rig.BONE_RADIUS`` x height scale);
    w = s^-power; the top ``max_influences`` are kept and normalised. ``candidates[i]`` (optional)
    restricts the bones of point i. Points with |x| > 4 cm never get bones of the other side."""
    k = height / REF_HEIGHT
    segs = _skin_segments(height)
    all_bones = [b for b in rig.BONES if b != "root"]
    out = []
    for i, p in enumerate(points):
        cands = candidates[i] if candidates is not None and candidates[i] else all_bones
        side_ok = None
        if p[0] > 0.04 * k:
            side_ok = ".R"
        elif p[0] < -0.04 * k:
            side_ok = ".L"
        scored = []
        for b in cands:
            if side_ok is not None and "." in b and not b.endswith(side_ok):
                continue
            a, t = segs[b]
            s = _seg_dist(p, a, t) / (rig.BONE_RADIUS[b] * k)
            scored.append((max(s, 1e-4) ** -power, b))
        if not scored:
            scored = [(1.0, "hips")]
        scored.sort(key=lambda x: (-x[0], x[1]))
        top = scored[:max_influences]
        tot = sum(w for w, _b in top)
        ws = {b: w / tot for w, b in top if w / tot >= 0.015}
        tot = sum(ws.values())
        out.append({b: w / tot for b, w in sorted(ws.items())})
    return out


def body_weights(body: BodyData) -> list[dict[str, float]]:
    """Weights for a ``BodyData`` (region-restricted, rigid parts fixed)."""
    n = len(body.basis)
    vreg: list[str | None] = [None] * n
    vside = [0] * n
    prio = {r: i for i, r in enumerate(REGIONS)}
    for f, r, sd in zip(body.faces, body.face_region, body.face_side):
        for v in f:
            if vreg[v] is None or prio[r] > prio[vreg[v]]:
                vreg[v] = r
                vside[v] = sd
    cands = []
    for i in range(n):
        if i in body.allowed:
            cands.append(sorted(body.allowed[i]))
            continue
        r = vreg[i] or "torso"
        sides = ["L", "R"]
        x = body.basis[i][0]
        if x > 0.04:
            sides = ["R"]
        elif x < -0.04:
            sides = ["L"]
        names = []
        for b in _REGION_BONES[r]:
            names += [b.format(s=s) for s in sides] if "{s}" in b else [b]
        cands.append(sorted(set(names)))
    ws = skin_weights(body.basis, float(body.params["height"]), cands)
    for v, b in body.rigid.items():
        ws[v] = {b: 1.0}
    return ws


# =============================================================================================
# UVs (pure math, per face corner)
# =============================================================================================
_TILES = {  # region -> (u0, v0, w, h) per side (None = centre)
    "head": (0.0, 0.5, 0.5, 0.5), "torso": (0.5, 0.5, 0.5, 0.5),
    "arm.R": (0.0, 0.25, 0.25, 0.25), "arm.L": (0.25, 0.25, 0.25, 0.25),
    "hand.R": (0.0, 0.0, 0.125, 0.25), "hand.L": (0.125, 0.0, 0.125, 0.25),
    "leg.R": (0.5, 0.0, 0.25, 0.5), "leg.L": (0.75, 0.0, 0.25, 0.5),
    "parts": (0.25, 0.0, 0.25, 0.25),
}


def _uv_point(region: str, mat: str, side: int, p: Vec, k: float) -> tuple[str, float, float]:
    sfx = "R" if side > 0 else "L"
    if mat != "skin" or (region == "head" and side != 0):
        # eyes, brows, hair, ears (head parts carry a side; the head skin is side 0): planar
        # front/side projection in a shared tile
        return "parts", 0.5 + p[0] / (0.4 * k), (p[2] / k - 1.45) / 0.4
    if region == "head":
        q = sub(p, mul(HEAD_CENTRE, k))
        return "head", (math.atan2(q[0], q[1]) + math.pi) / TAU, (p[2] / k - 1.50) / 0.30
    if region in ("neck", "torso", "pelvis"):
        return "torso", (math.atan2(p[0], p[1] + 0.01 * k) + math.pi) / TAU, (p[2] / k - 0.80) / 0.82
    if region in ("upper_arms", "forearms"):
        segs = rig.bone_segments(REF_HEIGHT)
        sh = mul(segs[f"upper_arm.{sfx}"][0], k)
        wr = mul(segs[f"forearm.{sfx}"][1], k)
        ax = norm(sub(wr, sh))
        q = sub(p, sh)
        up, fw = _ortho((0, 0, 1), ax), _ortho((0, 1, 0), ax)
        return f"arm.{sfx}", (math.atan2(dot(q, fw), -dot(q, up)) + math.pi) / TAU, dot(q, ax) / (0.62 * k)
    if region == "hands":
        hf = rig.hand_frame(side or 1, REF_HEIGHT)
        q = sub(p, mul(hf["origin"], k))
        flip = 0.0 if dot(q, hf["back"]) > 0 else 0.5
        return f"hand.{sfx}", 0.25 + 0.5 * flip + dot(q, hf["fwd"]) / (0.24 * k), dot(q, hf["along"]) / (0.2 * k)
    cx = side * 0.10 * k
    return f"leg.{sfx}", (math.atan2(p[0] - cx, p[1]) * side + math.pi) / TAU, p[2] / (0.92 * k)


def face_uvs(faces: list, regions: list, mats: list, sides: list, verts: list, height: float) -> list[list[tuple[float, float]]]:
    """Per-face-corner UVs: cylindrical per body region, packed into fixed 0..1 tiles."""
    k = height / REF_HEIGHT
    out = []
    for f, r, mt, sd in zip(faces, regions, mats, sides):
        pts = [_uv_point(r, mt, sd, verts[v], k) for v in f]
        tile = pts[0][0]
        us = [q[1] for q in pts]
        if tile not in ("parts",) and not tile.startswith("hand") and max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        u0, v0, w, h = _TILES[tile]
        out.append([(u0 + w * _clamp(u, -0.1, 1.1), v0 + h * _clamp(q[2], 0.0, 1.0)) for u, q in zip(us, pts)])
    return out


# =============================================================================================
# skin tint (vertex colours, pure math)
# =============================================================================================
#: Linear-RGB albedo multipliers per head vertex; ``make_materials.py`` rasterises them into the skin
#: textures' body-UV atlas (``skin_tint`` on the default body); everything else stays white.
TINT_CHEEK = (1.0, 0.875, 0.855)     # malar flush
TINT_NOSE = (1.0, 0.895, 0.875)      # nose tip and wings
TINT_EAR = (1.0, 0.915, 0.895)       # ears
TINT_LID = (0.955, 0.925, 0.935)     # under-eye / upper-lid shade
TINT_BEARD = (0.60, 0.645, 0.72)     # beard shadow at full strength (cool, darker)


def _gauss(q: Vec, c: Vec, sigma: Vec) -> float:
    return math.exp(-(((q[0] - c[0]) / sigma[0]) ** 2 + ((q[1] - c[1]) / sigma[1]) ** 2 + ((q[2] - c[2]) / sigma[2]) ** 2))


def _beard_top(ax: float) -> float:
    """Upper edge of the beard (head-local z) at |x| = ax: under the nose, across the cheek, up the
    sideburn to the ear."""
    pts = ((0.0, -0.0405), (0.012, -0.0415), (0.022, -0.0470), (0.030, -0.0440), (0.040, -0.0340),
           (0.050, -0.0230), (0.058, -0.0080), (0.064, 0.0080), (0.080, 0.0120))
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if ax <= x1:
            t = smoothstep(x0, x1, ax)
            return z0 + (z1 - z0) * t
    return pts[-1][1]


def skin_tint(body: BodyData) -> list[tuple[float, float, float]]:
    """Per-vertex linear multipliers for the skin of ``body`` (variant shape, see ``TINT_*``):
    warmth on the cheeks, nose and ears, a soft shade round the eyes and, with ``beard_shadow``,
    a cool darker jaw, chin and upper lip. Head skin only; everything else stays white."""
    p = body.params
    k = float(p["height"]) / REF_HEIGHT
    g = float(p["gender"])
    beard = float(p["beard_shadow"])
    n = len(body.blend)
    out = [(1.0, 1.0, 1.0)] * n
    head_v: set[int] = set()
    ear_v: set[int] = set()
    for f, r, mt, sd in zip(body.faces, body.face_region, body.face_mat, body.face_side):
        if r != "head" or mt not in ("skin", "lip", "lash"):
            continue
        if sd != 0 and mt != "skin":           # pupils (lash) are side parts too, not ears
            continue
        (ear_v if sd != 0 else head_v).update(f)
    cheek_w = 0.80 + 0.25 * g
    for vi in sorted(head_v | ear_v):
        q = sub(mul(body.blend[vi], 1.0 / k), HEAD_CENTRE)
        ax = abs(q[0])
        qa = (ax, q[1], q[2])
        mult = [1.0, 1.0, 1.0]

        def mix(tint: tuple[float, float, float], w: float) -> None:
            w = _clamp(w, 0.0, 1.0)
            for i in range(3):
                mult[i] *= 1.0 + (tint[i] - 1.0) * w
        if vi in ear_v:
            mix(TINT_EAR, 1.0)
        else:
            mix(TINT_CHEEK, cheek_w * _gauss(qa, (0.044, 0.068, -0.014), (0.020, 0.030, 0.017)))
            mix(TINT_NOSE, 0.85 * _gauss(qa, (0.0, 0.118, -0.027), (0.017, 0.016, 0.013)))
            mix(TINT_LID, _gauss(qa, (0.031, 0.078, 0.004), (0.012, 0.012, 0.0055))
                + 0.7 * _gauss(qa, (0.031, 0.080, 0.030), (0.013, 0.012, 0.0045)))
            if beard > 0.0:
                top = _beard_top(ax)
                wb = smoothstep(top + 0.005, top - 0.006, q[2])                 # below the beard line
                wb *= smoothstep(-0.036, -0.012, q[1])                           # in front of the ear
                wb *= smoothstep(-0.128, -0.100, q[2])                           # fades down the throat
                mix(TINT_BEARD, beard * wb)
        out[vi] = (mult[0], mult[1], mult[2])
    return out


# =============================================================================================
# Blender side
# =============================================================================================
def _material(ctx, lib_id: str, color: str, roughness: float = 0.6):
    if ctx is not None:
        return ctx.material(lib_id, color, roughness=roughness)
    from lib import materials  # noqa: PLC0415

    return materials.material(lib_id, color, roughness)


def _make_object(name: str, data: BodyData, mats: dict, armature, weights: list[dict[str, float]]):
    import bpy  # noqa: PLC0415

    from lib import scene  # noqa: PLC0415

    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in data.basis], [], [tuple(f) for f in data.faces])
    order = []
    for mname in ("skin", "lip", "eye", "iris", "lash", "brow", "hair"):
        if mname in data.face_mat:
            order.append(mname)
            me.materials.append(mats[mname])
    idx = {m: i for i, m in enumerate(order)}
    me.polygons.foreach_set("material_index", [idx[m] for m in data.face_mat])
    if name == "Hair":       # along the strands (the hair textures' detail runs along v)
        uvs = _headmod.hair_uvs(data.faces, data.basis, data.params["hair"], float(data.params["height"]) / REF_HEIGHT)
    else:
        uvs = face_uvs(data.faces, data.face_region, data.face_mat, data.face_side, data.basis,
                       float(data.params["height"]))
    layer = me.uv_layers.new(name="UVMap")
    flat = [c for f in uvs for uv in f for c in uv]
    layer.data.foreach_set("uv", flat)
    me.shade_smooth()
    me.validate(clean_customdata=False)
    me.update()
    obj = bpy.data.objects.new(name, me)
    scene.link(obj, armature)
    obj.shape_key_add(name="Basis", from_mix=False)
    for kname in SHAPE_KEYS:
        kb = obj.shape_key_add(name=kname, from_mix=False)
        kb.data.foreach_set("co", [c for v in data.keys[kname] for c in v])
        kb.slider_min, kb.slider_max = 0.0, 1.0
        kb.value = float(data.params[kname])
    _apply_weights(obj, armature, weights)
    return obj


def _apply_weights(obj, armature, weights: list[dict[str, float]]) -> None:
    groups = {}
    for b in rig.BONES:
        if b == "root":
            continue
        groups[b] = obj.vertex_groups.get(b) or obj.vertex_groups.new(name=b)
    per_bone: dict[str, list[tuple[int, float]]] = {b: [] for b in groups}
    for vi, w in enumerate(weights):
        for b, x in sorted(w.items()):
            per_bone[b].append((vi, x))
    for b in groups:
        for vi, x in per_bone[b]:
            groups[b].add([vi], x, "REPLACE")
    mod = next((m for m in obj.modifiers if m.type == "ARMATURE"), None) or obj.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    mod.use_vertex_groups = True
    mod.use_bone_envelopes = False


def build_body(ctx, armature, params: dict | None = None) -> dict:
    """Create the skinned ``Body`` (and ``Hair`` unless hair="none") meshes under ``armature``.

    Returns ``{"Body": obj, "Hair": obj | None, "data": BodyData, "tris": int}``."""
    p = body_params(params)
    body, hair = body_mesh_data(p)
    skin = _material(ctx, skin_material(p), SKIN_TONES[int(p["skin"]) - 1], 0.55)
    hair_mat = _material(ctx, f"char_hair_{p['hair_color']}", HAIR_COLORS[p["hair_color"]], 0.6)
    lip_id = lip_material(p)
    lip_hex = LIP_COLORS.get(lip_id.removeprefix("char_lip_"))
    if lip_hex is None:
        from _outfit_palette import OUTFIT  # noqa: PLC0415
        lip_hex = OUTFIT[lip_id][0]
    mats = {"skin": skin, "lip": _material(ctx, lip_id, lip_hex, 0.45), "eye": _material(ctx, "char_eye", EYE_COLOR, 0.25),
            "iris": _material(ctx, "char_eye_iris", IRIS_COLOR, 0.2), "lash": _material(ctx, "char_lash", LASH_COLOR, 0.5),
            "brow": hair_mat, "hair": hair_mat}
    out = {"Body": _make_object("Body", body, mats, armature, body_weights(body)), "Hair": None, "data": body}
    if hair.faces:
        out["Hair"] = _make_object("Hair", hair, mats, armature, [{"head": 1.0} for _ in hair.basis])
    out["tris"] = sum(len(f) - 2 for f in body.faces) + sum(len(f) - 2 for f in hair.faces)
    return out


def skin_to_rig(mesh_obj, armature, bones_subset=None, power: float = 6.0) -> None:
    """Skin any mesh object (e.g. clothing) to ``armature`` with the body's deterministic weights.

    Vertex positions are read in armature space at rest (``mesh_obj`` must not be posed); the
    mesh is parented to ``armature`` (transform kept) and gets vertex groups + an Armature
    modifier. ``bones_subset`` (iterable of bone names) restricts the influences, e.g. a glove to
    the hand and finger bones of one side. The height is read from the armature's ``head`` bone."""
    from mathutils import Matrix  # noqa: PLC0415

    head = armature.data.bones["head"]
    height = (armature.matrix_world @ head.tail_local).z
    to_arm = armature.matrix_world.inverted() @ mesh_obj.matrix_world
    pts = [tuple(to_arm @ v.co) for v in mesh_obj.data.vertices]
    cands = None
    if bones_subset is not None:
        subset = sorted(set(bones_subset) - {"root"})
        cands = [subset] * len(pts)
    weights = skin_weights(pts, height, cands, power=power)
    mw = mesh_obj.matrix_world.copy()
    mesh_obj.parent = armature
    mesh_obj.matrix_parent_inverse = Matrix.Identity(4)
    mesh_obj.matrix_world = mw
    _apply_weights(mesh_obj, armature, weights)
