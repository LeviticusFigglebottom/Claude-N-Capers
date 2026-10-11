"""Production GSR head for the parametric body (``_body``): field, mesh, eyes, ears, brows, hair.

Private helper (``_`` prefix), pure Python (no bpy, no numpy, no randomness). Every number comes
from this file; the forms are the anatomical landmarks of the approved officer style-sample head
(``tools/blender/style_samples/head.py``, the GSR character reference), re-expressed for the body.

Frames
* Body / head-local: Blender axes, the character faces +Y, +X = right (``.R``); head-local = world
  minus ``HEAD_CENTRE`` (at the reference height 1.78 m).
* Landmark frame ("hp", the officer head's frame): +X = lateral (we mirror: x = |X|), -Y = forward,
  +Z = up, origin between the eyeball centres at eye height. ``local -> hp``:
  ``x = |X| / SX, y = OY - Y, z = Z - OZ``. With SX/OY/OZ below the officer's eyeball centre
  (±0.0318, -0.0705, 0) lands exactly on ``EYE_LOCAL``, so every landmark of the officer table is
  used with its own numbers.

The skin
* A signed distance field of the landmark forms (cranium, frontal bossing, brow shelf, maxilla,
  cheekbones and malar pads, mandible with ramus/gonion/body, chin block, muzzle, lips with corners
  and philtrum, nose with dorsum/tip/alae/columella, orbits with closed lid domes), smooth-unioned in
  a fixed order, culled exactly by bounding spheres for speed. Shape keys move landmarks:
  ``build`` (jaw width, masseter, cheeks, submental fat), ``gender`` (smooth brow shelf and a rounder
  forehead, a narrower, softer jaw with a higher gonion and a small round chin, higher, fuller
  cheekbones and cheeks, a narrower nose with a finer bridge, fuller lips, larger lid openings,
  thinner, higher-arched brows; the upper lash line thickens when gender > 0.5) and ``age`` (nasolabial fold,
  jowls, thinner lips, brow and lid droop, nose-tip droop, hollower temples).
* Mesh: a ring grid stitched to the subdivided neck ring and ray-cast onto the field (columns denser
  at the face, rows denser over the eyes and the mouth), relaxed on the surface. Around each eye and
  the mouth a block of grid quads is replaced by concentric edge loops running from the block
  border down to the opening, so lids and lips get real loops: lid edge -> lid thickness (wet line)
  -> tucked behind the eyeball; vermilion border (a real loop with a Cupid's bow, ``lip_heights``) ->
  mid-lip -> lip line -> into the mouth. The faces inside the vermilion loop are the ``lip`` material.
* Shape keys: build and age re-seat the basis vertices on their own surface (no sliding); gender is
  generated natively on the same grid (its forms move too far for a re-seat, see ``_body``). The loops are fixed by grid
  index, so the topology never depends on the parameters.
* Separate parts in the same mesh: eyeballs (iris cap), ears (helix rim, scapha, antihelix,
  concha, lobe; buried in the head at the front), eyebrows (tapered ribbons on the brow shelf).

Hair (separate mesh): simplified cap volumes with a rolled, bevelled edge so the hairline has
thickness: ``buzz``, ``short``, ``side_part``, ``bob``, ``bald`` (horseshoe fringe) and ``none``.
GSR breakup, not strands (``HAIR_FLOW``): broad strand clumps cut in as grooves along the combing
direction (great circles through a per-style pole: the crown whorl, beside the parting, the crown
of a bob), a hairline that breaks into small clumps over the forehead (optional widow's peak), short
styles thinning out at the sideburns and the nape, a bob hem ending in irregular tips. The grooves
only cut in, so the outer envelope (caps, glasses and masks fit over it) is kept. ``hair_uvs`` lays
the UVs along the strands for the strand-grain hair textures (``make_materials.py``).
"""

from __future__ import annotations

import dataclasses
import math
from dataclasses import dataclass

import _rig as rig

add, sub, mul, dot, cross, norm, lerp = rig.add, rig.sub, rig.mul, rig.dot, rig.cross, rig.norm, rig.lerp
vlen = rig.length
TAU = 2.0 * math.pi
Vec = tuple[float, float, float]

HEAD_CENTRE: Vec = (0.0, -0.008, 1.648)
EYE_RADIUS = 0.0122
EYE_LOCAL: Vec = (0.0325, 0.0725, 0.018)      # eyeball centre, head-local (mirrored in x)
SX, OY, OZ = 1.022, 0.002, 0.018             # head-local <-> landmark frame (see module doc)
HAIR_STYLES = ("none", "buzz", "short", "side_part", "bob", "bald")
_BIG = 1.0e9


# =============================================================================================
# small math
# =============================================================================================
def _clamp(x: float, a: float, b: float) -> float:
    return a if x < a else b if x > b else x


def smoothstep(e0: float, e1: float, x: float) -> float:
    t = _clamp((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _smin(a: float, b: float, k: float) -> float:
    if k <= 0.0:
        return a if a < b else b
    h = k - abs(a - b)
    if h <= 0.0:
        return a if a < b else b
    h /= k
    return (a if a < b else b) - h * h * k * 0.25


def _smax(a: float, b: float, k: float) -> float:
    return -_smin(-a, -b, k)


def _ortho(v: Vec, axis: Vec) -> Vec:
    return norm(sub(v, mul(axis, dot(v, axis))))


def _rot_xyz(rx: float = 0.0, ry: float = 0.0, rz: float = 0.0) -> tuple:
    """3x3 rotation applied X then Y then Z; columns are the local axes (same as the officer's sdf.py)."""
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    mx = ((1.0, 0.0, 0.0), (0.0, cx, -sx), (0.0, sx, cx))
    my = ((cy, 0.0, sy), (0.0, 1.0, 0.0), (-sy, 0.0, cy))
    mz = ((cz, -sz, 0.0), (sz, cz, 0.0), (0.0, 0.0, 1.0))

    def mm(a, b):
        return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))
    return mm(mm(mz, my), mx)


# =============================================================================================
# field primitives (landmark frame). Each returns (fn(x, y, z) -> distance, bound centre, bound radius)
# =============================================================================================
def _ell(c: Vec, r: Vec, rot=None):
    cx, cy, cz = c
    rx, ry, rz = r
    rmin = min(r)
    if rot is None:
        def fn(x, y, z):
            px, py, pz = (x - cx) / rx, (y - cy) / ry, (z - cz) / rz
            k0 = math.sqrt(px * px + py * py + pz * pz)
            if k0 < 1e-9:
                return -rmin
            k1 = math.sqrt((px / rx) ** 2 + (py / ry) ** 2 + (pz / rz) ** 2)
            return k0 * (k0 - 1.0) / k1
    else:
        (a00, a01, a02), (a10, a11, a12), (a20, a21, a22) = rot

        def fn(x, y, z):
            dx, dy, dz = x - cx, y - cy, z - cz
            px = (dx * a00 + dy * a10 + dz * a20) / rx
            py = (dx * a01 + dy * a11 + dz * a21) / ry
            pz = (dx * a02 + dy * a12 + dz * a22) / rz
            k0 = math.sqrt(px * px + py * py + pz * pz)
            if k0 < 1e-9:
                return -rmin
            k1 = math.sqrt((px / rx) ** 2 + (py / ry) ** 2 + (pz / rz) ** 2)
            return k0 * (k0 - 1.0) / k1
    return fn, c, max(r)


def _sell(c: Vec, r: Vec, n: float):
    """Ellipsoid with a superellipse (exponent n) horizontal section: broad rounded front, no prow."""
    cx, cy, cz = c
    rx, ry, rz = r
    inv = 1.0 / n

    def fn(x, y, z):
        ax = abs((x - cx) / rx) + 1e-9
        ay = abs((y - cy) / ry) + 1e-9
        az = (z - cz) / rz
        rho = (ax ** n + ay ** n) ** inv
        k = math.sqrt(rho * rho + az * az) + 1e-9
        g = rho ** (1.0 - n)
        gx = (rho / k) * g * ax ** (n - 1.0) / rx
        gy = (rho / k) * g * ay ** (n - 1.0) / ry
        gz = az / (k * rz)
        return (k - 1.0) / max(math.sqrt(gx * gx + gy * gy + gz * gz), 1e-6)
    return fn, c, max(r) * 1.12


def _cone(a: Vec, b: Vec, ra: float, rb: float):
    ax, ay, az = a
    bx, by, bz = b[0] - ax, b[1] - ay, b[2] - az
    bb = bx * bx + by * by + bz * bz

    def fn(x, y, z):
        px, py, pz = x - ax, y - ay, z - az
        t = (px * bx + py * by + pz * bz) / bb
        t = 0.0 if t < 0.0 else 1.0 if t > 1.0 else t
        qx, qy, qz = px - bx * t, py - by * t, pz - bz * t
        return math.sqrt(qx * qx + qy * qy + qz * qz) - (ra + (rb - ra) * t)
    return fn, lerp(a, b, 0.5), 0.5 * math.sqrt(bb) + max(ra, rb)


def _sphere(c: Vec, r: float):
    cx, cy, cz = c

    def fn(x, y, z):
        return math.sqrt((x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2) - r
    return fn, c, r


# =============================================================================================
# the field
# =============================================================================================
ADD, SUB = 0, 1


@dataclass(frozen=True)
class HeadShape:
    """The head field for one (build, gender, age); neck ellipse from the body's neck ring
    (head-local metres). ``detail=False`` is the smooth guide field used to place the grid."""

    build: float
    gender: float
    age: float
    neck_cy: float
    neck_rx: float
    neck_ry: float
    detail: bool = True
    nose: bool = True

    # -- construction --------------------------------------------------------------------------
    def _ops(self) -> list:
        b, g, a = self.build, self.gender, self.age
        ops: list = []

        def op(mode, prim, k, pair=0.0):
            fn, c, r = prim
            if pair:                       # evaluated at +x and -x and smooth-unioned (crosses the midline)
                c = (0.0, c[1], c[2])
                r += abs(prim[1][0])
            ops.append((mode, k, c[0], c[1], c[2], r * 1.25 + 0.003, pair, fn))

        guide = not self.detail
        # ---- cranium and forehead
        op(ADD, _ell((0.0, 0.008, 0.028), (0.0735 - 0.0015 * g, 0.102 - 0.002 * g, 0.086 - 0.002 * g)), 0.0)
        op(ADD, _ell((0.0, -0.030 - 0.004 * g, 0.045 + 0.003 * g), (0.064, 0.064, 0.052 + 0.003 * g)), 0.02)   # frontal bossing
        if not guide:
            # brow shelf: glabella + arches (finer and set back for gender, drooping laterally with age)
            bz = 0.017
            br = 0.0090 * (1.0 - 0.55 * g) * (1.0 + 0.05 * b)
            op(ADD, _cone((0.0, -0.0905 + 0.0060 * g, bz + 0.002 * g), (0.047, -0.079 + 0.005 * g, bz + 0.004 + 0.003 * g - 0.003 * a),
                          br, br * (0.92 - 0.1 * g)), 0.014 + 0.006 * g, pair=0.006)
            op(ADD, _cone((0.047, -0.079 + 0.004 * g, bz + 0.004 + 0.003 * g - 0.003 * a), (0.058, -0.060, bz + 0.009 + 0.003 * g - 0.004 * a),
                          0.0050 * (1.0 - 0.45 * g), 0.0050 * (1.0 - 0.45 * g)), 0.016 + 0.004 * g)
        # ---- maxilla
        op(ADD, _sell((0.0, -0.033, -0.036), (0.053 + 0.003 * b - 0.004 * g, 0.061, 0.050), 2.35), 0.02)
        if not guide:
            # cheekbones: zygoma body, arch, malar fat pad, lateral orbital rim
            zr = _rot_xyz(0.0, 0.0, -0.45)
            op(ADD, _ell((0.046 + 0.002 * b - 0.003 * g, -0.061 - 0.003 * g, -0.016 + 0.007 * g),
                         (0.0160 + 0.001 * b + 0.0015 * g, 0.020 + 0.001 * g, 0.0125 + 0.0015 * g), zr), 0.022 + 0.004 * g)
            op(ADD, _cone((0.053 - 0.002 * g, -0.046, -0.017), (0.063 - 0.002 * g, -0.010, -0.019), 0.0050, 0.0050 + 0.0010 * g), 0.018 + 0.010 * g)
            op(ADD, _ell((0.034 + 0.002 * g, -0.068 - 0.002 * a - 0.002 * g, -0.030 + 0.007 * g - 0.005 * a),
                         (0.017 + 0.003 * b + 0.002 * g, 0.015 + 0.002 * b + 0.002 * g, 0.016 + 0.002 * b)), 0.024)
            op(ADD, _cone((0.0545, -0.064, 0.020), (0.0525, -0.060, -0.012), 0.0065, 0.0065), 0.018)
        # ---- mandible: body block, ramus to a defined gonion, body to the chin
        jw = 1.0 + 0.10 * b - 0.15 * g
        op(ADD, _sell((0.0, -0.026, -0.071 + 0.003 * g), (0.054 * jw, 0.062, 0.043 - 0.003 * g), 2.6 - 0.6 * g), 0.02 + 0.006 * g)
        if not guide:
            go = (0.0545 * jw, 0.004 - 0.008 * g, -0.084 + 0.012 * g)
            jr = 0.0092 * (1.0 + 0.2 * b - 0.40 * g)
            op(ADD, _cone((0.057 * jw, 0.012, -0.030), go, jr * 0.95, jr * 0.95), 0.022 + 0.008 * g)
            op(ADD, _cone(go, (0.028 * jw - 0.004 * g, -0.072, -0.107 + 0.004 * g), jr, jr), 0.024 + 0.012 * g)
            op(ADD, _ell((0.043 * jw - 0.002 * g, -0.018, -0.050 + 0.004 * g), (0.019 + 0.004 * b - 0.008 * g, 0.032, 0.033 - 0.006 * g)), 0.024 + 0.006 * g)    # masseter
            op(ADD, _ell((0.052 * (jw + 0.10 * g), -0.004, -0.026), (0.014, 0.028, 0.030)), 0.025)               # TMJ fill
        # chin block (narrower, rounder for gender)
        op(ADD, _sell((0.0, -0.0855 - 0.0015 * g, -0.106 + 0.005 * g),
                      (0.025 * (1.0 - 0.32 * g) + 0.002 * b, 0.017 * (1.0 - 0.12 * g), 0.0175 * (1.0 - 0.20 * g)), 2.8 - 0.8 * g),
           0.018 + 0.006 * g)
        # submental soft tissue (build / age)
        op(ADD, _ell((0.0, -0.034, -0.108 - 0.004 * a), (0.030 + 0.020 * b + 0.008 * a, 0.026 + 0.014 * b + 0.004 * a,
                                                          0.012 + 0.010 * b + 0.003 * a)), 0.04)
        # neck: elliptic cylinder (from the body's neck ring) up to under the skull
        nrx, nry, ncy = self.neck_rx, self.neck_ry, self.neck_cy

        def neck(x, y, z):
            X, Y, Z = x * SX, OY - y, z + OZ
            px, py = X / nrx, (Y - ncy) / nry
            k0 = math.sqrt(px * px + py * py)
            k1 = math.sqrt((px / nrx) ** 2 + (py / nry) ** 2)
            dn = k0 * (k0 - 1.0) / max(k1, 1e-9)
            return _smax(dn, Z + 0.02, 0.02)
        ops.append((ADD, 0.025, 0.0, 0.0, 0.0, -1.0, 0.0, neck))
        # ---- muzzle
        op(ADD, _ell((0.0, -0.066 - 0.0005 * g, -0.0705 + 0.002 * g), (0.041 - 0.003 * g, 0.034, 0.028 - 0.003 * g)), 0.028)
        if guide:
            return ops
        # ---- lips: volume, corners, philtrum, mentolabial sulcus
        lu = 1.0 + 0.32 * g - 0.30 * a
        ll = 1.0 + 0.10 * g - 0.26 * a
        op(ADD, _ell((0.0, -0.0996 + 0.0016 * g + 0.0016 * a, -0.0684),
                     (0.0228 - 0.001 * g, 0.0114 * (1.0 + 0.06 * g), 0.0080 * lu), _rot_xyz(-0.30, 0.0, 0.0)), 0.0035 + 0.0035 * g)
        op(ADD, _ell((0.0, -0.0986 + 0.0034 * g + 0.0016 * a, -0.0832 - 0.0008 * g),
                     (0.0202 - 0.0008 * g, 0.0126 * (1.0 + 0.05 * g), 0.0108 * ll), _rot_xyz(0.35, 0.0, 0.0)), 0.0030 + 0.0035 * g)
        mcx = 0.0216 - 0.0010 * g + 0.0004 * b
        op(SUB, _sphere((mcx, -0.0910 + 0.0010 * g, -0.0756 - 0.0012 * a), 0.0021 * (1.0 - 0.15 * g)), 0.0055 + 0.0015 * g)       # mouth corners
        op(ADD, _ell((mcx + 0.0040, -0.0870 + 0.0010 * g, -0.0760 - 0.0012 * a), (0.0040 * (1.0 - 0.5 * g) + 0.0005, 0.0035 * (1.0 - 0.5 * g) + 0.0005, 0.0055 * (1.0 - 0.4 * g))), 0.006)   # modiolus
        op(ADD, _cone((0.0042, -0.1040, -0.0585), (0.0056, -0.1030, -0.0662), 0.0017, 0.0017), 0.003)
        op(SUB, _cone((0.0, -0.1060, -0.0595), (0.0, -0.1062, -0.065), 0.0016, 0.0016), 0.003)
        op(SUB, _ell((0.0, -0.0990 + 0.0025 * g, -0.0958 + 0.003 * g), (0.017 - 0.002 * g, 0.0040 * (1.0 - 0.45 * g), 0.0045)), 0.011 + 0.006 * g)
        # ---- nose
        if not self.nose:
            return ops
        nl = 1.0 + 0.02 * a
        nw = 1.0 + 0.06 * b - 0.10 * g
        tip = (0.0, -0.1165 * nl + 0.0005 + 0.0028 * g, -0.0425 * nl - 0.0025 * a + 0.0012 * g)
        op(ADD, _ell((0.0, -0.088, -0.026), (0.0135 * nw, 0.017, 0.026)), 0.012)                 # body
        op(ADD, _cone((0.0, -0.0925, 0.003), tip, 0.0058 * (1.0 - 0.14 * g), 0.0075 * nw), 0.008 + 0.002 * g)  # dorsum
        op(ADD, _sphere((0.0, tip[1] + 0.0024, tip[2] - 0.0012), 0.0080 * nw), 0.007)            # tip
        op(ADD, _ell((0.0128 * nw, -0.0995, -0.0478), (0.0064 * nw, 0.0082, 0.0060), _rot_xyz(0.0, 0.0, 0.35)), 0.009)
        op(ADD, _cone((0.0, tip[1] + 0.003, tip[2] - 0.0085), (0.0, -0.1025, -0.0565), 0.0040, 0.0040), 0.004)
        # alar groove: a soft shadow line round the wing (nostril pits are left to the texture: GSR)
        op(SUB, _cone((0.0222 * nw, -0.0945, -0.040), (0.0212 * nw, -0.0965, -0.052), 0.0006 * (1.0 - 0.7 * g), 0.0006 * (1.0 - 0.7 * g)), 0.009)
        # ---- gender: fuller, softer cheeks (fills the submalar hollow under the cheekbone)
        if g > 0.0:
            op(ADD, _ell((0.040, -0.060, -0.026), (0.005 + 0.008 * g, 0.005 + 0.008 * g, 0.006 + 0.009 * g)), 0.024)
            # ... and the nasolabial groove between the cheek and the muzzle (smooth, youthful)
            op(ADD, _ell((0.029, -0.079, -0.054), (0.004 + 0.005 * g, 0.004 + 0.004 * g, 0.006 + 0.008 * g)), 0.022)
        # ---- age: nasolabial fold, the cheek mass over it, jowls, temple hollow
        if a > 0.0:
            op(ADD, _ell((0.031, -0.085, -0.060 - 0.002 * a), (0.011, 0.007 * a + 0.001, 0.013)), 0.020)
            op(SUB, _cone((0.0262, -0.0945, -0.055), (0.0298, -0.0905, -0.072), 0.0001 * a, 0.0005 * a), 0.012)
            op(ADD, _ell((0.035, -0.066, -0.100), (0.011 * a + 0.001, 0.013 * a + 0.001, 0.009 * a + 0.001)), 0.016)
            op(SUB, _ell((0.067, -0.040, 0.030), (0.003 * a + 0.0005, 0.016, 0.018)), 0.010)
        # ---- orbits: hollow above the lid (upper lid crease), orbital depth, socket, closed lid dome
        ec = (0.0318, -0.0705, 0.0)
        op(SUB, _ell((ec[0] + 0.002, ec[1] - 0.0140, ec[2] + 0.0100 - 0.0015 * a), (0.0160, 0.0072, 0.0058)), 0.011)
        op(SUB, _ell((ec[0] + 0.002, ec[1] - 0.0150, ec[2] + 0.004), (0.0195, 0.0080, 0.0110)), 0.014)
        op(SUB, _sphere(ec, EYE_RADIUS + 0.0016), 0.004)
        lid_r = EYE_RADIUS + 0.0030
        ls = _sphere(ec, lid_r)[0]
        le = _ell((ec[0], ec[1] - 0.004, ec[2]), (0.0185, 0.02, 0.0145))[0]
        y_front = ec[1] + 0.004

        def lid(x, y, z, ls=ls, le=le):
            return _smax(_smax(ls(x, y, z), y - y_front, 0.002), le(x, y, z), 0.003)
        ops.append((ADD, 0.0035, ec[0], ec[1], ec[2], lid_r * 1.25 + 0.003, 0.0, lid))
        if a > 0.0:     # soft under-eye bag
            op(ADD, _ell((ec[0] + 0.001, ec[1] - 0.0120, ec[2] - 0.0125), (0.010, 0.003 * a + 0.0005, 0.004)), 0.006)
        return ops

    @property
    def _o(self) -> list:
        cache = self.__dict__.get("_cache")
        if cache is None:
            cache = self._ops()
            object.__setattr__(self, "_cache", cache)
        return cache

    # -- evaluation ----------------------------------------------------------------------------
    def sdf(self, p: Vec) -> float:
        X = p[0] - HEAD_CENTRE[0]
        x = abs(X) / SX
        y = OY - (p[1] - HEAD_CENTRE[1])
        z = p[2] - HEAD_CENTRE[2] - OZ
        d = _BIG
        for mode, k, cx, cy, cz, br, pair, fn in self._o:
            if br > 0.0:
                lb = math.sqrt((x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2) - br
                if mode == ADD:
                    if lb >= d + k:
                        continue
                elif lb >= k - d:
                    continue
            v = fn(x, y, z)
            if pair:
                v = _smin(v, fn(-x, y, z), pair)
            if mode == ADD:
                d = v if d >= _BIG else _smin(d, v, k)
            else:
                d = _smax(d, -v, k)
        return d

    def grad(self, p: Vec, h: float = 0.0004) -> Vec:
        f = self.sdf
        gx = f((p[0] + h, p[1], p[2])) - f((p[0] - h, p[1], p[2]))
        gy = f((p[0], p[1] + h, p[2])) - f((p[0], p[1] - h, p[2]))
        gz = f((p[0], p[1], p[2] + h)) - f((p[0], p[1], p[2] - h))
        return norm((gx, gy, gz))

    def project(self, p: Vec, n: Vec | None = None, reach: float = 0.06) -> Vec:
        """Move ``p`` onto the surface along the line through it with direction ``n`` (default: the
        field gradient at ``p``): the first exit when ``p`` is inside, the nearest entry when outside."""
        if n is None:
            n = self.grad(p)
        d = self.sdf(p)
        if d <= 0.0:
            return self.cast(p, n, reach)
        t, prev = 0.0, 0.0
        while d > 0.0 and t < reach:
            prev = t
            t += max(d * 0.8, 0.0003)
            d = self.sdf(add(p, mul(n, -t)))
        lo, hi = prev, t
        for _ in range(18):
            mid = 0.5 * (lo + hi)
            if self.sdf(add(p, mul(n, -mid))) > 0.0:
                lo = mid
            else:
                hi = mid
        return add(p, mul(n, -0.5 * (lo + hi)))

    def cast(self, origin: Vec, direction: Vec, t_max: float = 0.3) -> Vec:
        """First exit point of the ray (origin inside the head)."""
        t, prev = 0.0, 0.0
        d = self.sdf(origin)
        it = 0
        while d <= 0.0 and t < t_max and it < 400:
            prev = t
            t += max(-d * 0.8, 0.0004)
            d = self.sdf(add(origin, mul(direction, t)))
            it += 1
        lo, hi = prev, t
        for _ in range(18):
            mid = 0.5 * (lo + hi)
            if self.sdf(add(origin, mul(direction, mid))) > 0.0:
                hi = mid
            else:
                lo = mid
        return add(origin, mul(direction, 0.5 * (lo + hi)))


    def snap(self, p: Vec, n: Vec, reach: float = 0.012) -> Vec:
        """``project`` along ``n``, guarded: keeps ``p`` when no surface lies within ``reach``."""
        q = self.project(p, n, reach)
        if abs(self.sdf(q)) > 2e-4 or vlen(sub(q, p)) > reach:
            return p
        return q


def local_to_world(q: Vec) -> Vec:
    return add(HEAD_CENTRE, q)


def hp_to_local(x: float, y: float, z: float, sx: float = 1.0) -> Vec:
    """Landmark frame -> head-local (``sx`` picks the side)."""
    return (sx * x * SX, OY - y, z + OZ)


# =============================================================================================
# the head grid
# =============================================================================================
HEAD_ROWS = 30         # intervals from the neck ring to the crown pole
COLUMN_WARP = 0.42     # >0: columns denser at the face
HEAD_RELAX = 8


def _row_params() -> list[float]:
    """Non-uniform row parameters s in [0,1] (0 = neck ring, 1 = crown), denser over the mouth and
    the eyes/nose."""
    n = 4000
    dens = [1.0 + 1.5 * math.exp(-(((i + 0.5) / n - 0.245) / 0.06) ** 2)
            + 1.7 * math.exp(-(((i + 0.5) / n - 0.47) / 0.12) ** 2) for i in range(n)]
    cum = [0.0]
    for x in dens:
        cum.append(cum[-1] + x)
    total = cum[-1]
    out = [0.0]
    j = 0
    for r in range(1, HEAD_ROWS):
        target = total * r / HEAD_ROWS
        while cum[j + 1] < target:
            j += 1
        out.append((j + (target - cum[j]) / (cum[j + 1] - cum[j])) / n)
    out.append(1.0)
    return out


def _head_dir(theta: float, phi: float) -> Vec:
    return (math.sin(phi) * math.sin(theta), math.sin(phi) * math.cos(theta), math.cos(phi))


def _splits(i: int, n0: int) -> int:
    """Extra head columns in neck interval i (by index: identical for every parameter set)."""
    a = min(i + 0.5, n0 - i - 0.5) * 360.0 / n0
    return 2 if a < 32.0 else 1 if a < 64.0 else 0


def _grid(md, hs: HeadShape) -> dict:
    neck = md.rings["neck_top"]
    n0 = len(neck)
    c = HEAD_CENTRE
    guide = dataclasses.replace(hs, detail=False)
    ang = []
    for vi in neck:
        q = sub(md.verts[vi], c)
        ang.append((math.atan2(q[0], q[1]), math.atan2(math.hypot(q[0], q[1]), q[2])))
    cols: list[tuple[float, float]] = []
    base: list[Vec] = []
    nsplit: list[int] = []
    for i in range(n0):
        j = (i + 1) % n0
        cols.append(ang[i])
        base.append(md.verts[neck[i]])
        th_i, th_j = ang[i][0], ang[j][0]
        dth = math.atan2(math.sin(th_j - th_i), math.cos(th_j - th_i))
        m = _splits(i, n0)
        nsplit.append(m)
        for s in range(1, m + 1):
            f = s / (m + 1)
            cols.append((th_i + f * dth, ang[i][1] + f * (ang[j][1] - ang[i][1])))
            base.append(lerp(md.verts[neck[i]], md.verts[neck[j]], f))
    s_rows = _row_params()
    rows: list[list[int]] = []
    for r in range(1, HEAD_ROWS):
        s = s_rows[r]
        w = smoothstep(0.0, 0.32, s)
        ring = []
        for th0, phi0 in cols:
            th = th0 - COLUMN_WARP * math.sin(th0) * w
            phi = phi0 * (1.0 - s)
            gp = guide.cast(c, _head_dir(th, phi))
            ring.append(md.v(hs.project(gp, guide.grad(gp))))
        rows.append(ring)
    pole = md.v(hs.cast(c, (0.0, 0.0, 1.0)))
    return {"neck": neck, "cols": cols, "base": base, "nsplit": nsplit, "rows": rows, "pole": pole,
            "s_rows": s_rows}


def _relax_grid(md, hs: HeadShape, base: list[Vec], rows: list[list[int]], pole: int, iters: int,
                skip: set | None = None) -> None:
    """Even out a ring grid on the surface: Laplacian step, then re-project along the grid normal.
    ``base`` are the fixed positions below the first row; the pole stays fixed. Jacobi update."""
    c = HEAD_CENTRE
    nr = len(rows)
    for _ in range(iters):
        new: dict[int, Vec] = {}
        for r in range(nr):
            ring = rows[r]
            n = len(ring)
            for j in range(n):
                if skip and (r, j) in skip:
                    continue
                p = md.verts[ring[j]]
                lft = md.verts[ring[j - 1]]
                rgt = md.verts[ring[(j + 1) % n]]
                dn = base[j] if r == 0 else md.verts[rows[r - 1][j]]
                up = md.verts[rows[r + 1][j]] if r + 1 < nr else md.verts[pole]
                avg = mul(add(add(lft, rgt), add(dn, up)), 0.25)
                q = lerp(p, avg, 0.5)
                nrm = cross(sub(rgt, lft), sub(up, dn))
                if vlen(nrm) < 1e-12:
                    continue
                nrm = norm(nrm)
                if dot(nrm, sub(q, c)) < 0.0:
                    nrm = mul(nrm, -1.0)
                new[ring[j]] = hs.snap(q, nrm, 0.012)
        for vi, q in new.items():
            md.verts[vi] = q


# =============================================================================================
# eye and mouth loops
# =============================================================================================
#: Grid blocks replaced by concentric loops: (columns of the right half / around the midline, rows).
#: Fixed indices (rows: 0 = first ring above the neck), so the topology is parameter independent.
EYE_BLOCK = (range(4, 18), (12, 19))
EYE_CORNER_ROW = 16                       # grid row of the block's side vertices = the eye corners
MOUTH_BLOCK = (range(-9, 10), (2, 8))
EYE_LOOP_W = (0.30, 0.58, 0.82)          # interpolation weights block border -> lid edge
MOUTH_LOOP_W = (0.28, 0.52, 0.72, 0.87)  # block border -> lip line
NOSE_BLOCK = (range(-6, 7), (8, 11))
NOSE_LOOP_W = (0.18, 0.38, 0.58, 0.78, 1.0)  # block border -> nose tip


def _perimeter(cols: list[int], r_lo: int, r_hi: int) -> list[tuple[int, int]]:
    """(row, col) around a grid block: bottom row cols[0]->cols[-1], up, top row back, down."""
    per = [(r_lo, c) for c in cols]
    per += [(r, cols[-1]) for r in range(r_lo + 1, r_hi + 1)]
    per += [(r_hi, c) for c in reversed(cols[:-1])]
    per += [(r, cols[0]) for r in range(r_hi - 1, r_lo, -1)]
    return per


def _chains(per: list[tuple[int, int]], pts: list[Vec], cols: list[int], r_mid: int) -> list[tuple[int, float]]:
    """For each perimeter vertex: (+1 upper / -1 lower chain, u in [0,1] from the cols[0] side to the
    cols[-1] side), by arc length along the block border. The two mid-side vertices get u = 0 / 1."""
    n = len(per)
    i_r = per.index((r_mid, cols[-1]))
    i_l = per.index((r_mid, cols[0]))
    out: list[tuple[int, float]] = [(0, 0.0)] * n

    def walk(start: int, stop: int) -> list[int]:
        ids = [start]
        i = start
        while i != stop:
            i = (i + 1) % n
            ids.append(i)
        return ids
    for chain, ids in ((1, walk(i_r, i_l)), (-1, walk(i_l, i_r))):
        acc = [0.0]
        for a, b in zip(ids, ids[1:]):
            acc.append(acc[-1] + vlen(sub(pts[b], pts[a])))
        for i, s in zip(ids, acc):
            t = s / acc[-1]
            out[i] = (chain, 1.0 - t if chain > 0 else t)
    out[i_r] = (0, 1.0)
    out[i_l] = (0, 0.0)
    return out


def _bump(u: float, peak: float, e: float = 0.75) -> float:
    w = 0.5 * u / peak if u <= peak else 0.5 + 0.5 * (u - peak) / (1.0 - peak)
    return max(math.sin(math.pi * w), 0.0) ** e


@dataclass(frozen=True)
class EyeShape:
    """Lid opening on the eyeball, as angles (degrees) in the eye frame: psi lateral (+ = outward),
    eps up. u in [0,1] runs medial -> lateral corner."""

    psi_med: float
    psi_lat: float
    eps_med: float
    eps_lat: float
    upper: float
    lower: float
    peak_u: float = 0.42
    peak_l: float = 0.58

    @staticmethod
    def of(build: float, gender: float, age: float) -> EyeShape:
        return EyeShape(psi_med=-61.0 - 1.5 * gender, psi_lat=67.0 + 2.0 * gender, eps_med=-2.0,
                        eps_lat=2.5 + 3.0 * gender - 2.0 * age,
                        upper=27.0 + 4.0 * gender - 4.0 * age, lower=25.5 + 2.0 * gender - 1.0 * age,
                        peak_u=0.42 + 0.06 * age)

    def angles(self, chain: int, u: float, shrink: float = 1.0) -> tuple[float, float]:
        psi_mid = 0.5 * (self.psi_med + self.psi_lat)
        psi = self.psi_med + (self.psi_lat - self.psi_med) * u
        epc = self.eps_med + (self.eps_lat - self.eps_med) * u
        if chain > 0:
            eps = epc + self.upper * _bump(u, self.peak_u)
        elif chain < 0:
            eps = epc - self.lower * _bump(u, self.peak_l)
        else:
            eps = epc
        return psi_mid + (psi - psi_mid) * shrink, epc + (eps - epc) * shrink


def _eye_frame(sx: float) -> tuple[Vec, Vec, Vec, Vec]:
    e = add(HEAD_CENTRE, (sx * EYE_LOCAL[0], EYE_LOCAL[1], EYE_LOCAL[2]))
    f = norm((sx * 0.10, 1.0, 0.0))
    up = _ortho((0.0, 0.0, 1.0), f)
    lat = mul(norm(cross(f, up)), sx)
    return e, f, up, lat


def _eye_dir(f: Vec, up: Vec, lat: Vec, psi: float, eps: float) -> Vec:
    p, e = math.radians(psi), math.radians(eps)
    return norm(add(add(mul(f, math.cos(p) * math.cos(e)), mul(lat, math.sin(p) * math.cos(e))), mul(up, math.sin(e))))


def _eye_loops(md, hs: HeadShape, sx: float, per_ids: list[int], chains: list[tuple[int, float]], es: EyeShape) -> list[list[int]]:
    e, f, up, lat = _eye_frame(sx)
    inner = add(e, mul(f, 0.002))
    m0, mb, m1, tk = [], [], [], []
    for ch, u in chains:
        d0 = _eye_dir(f, up, lat, *es.angles(ch, u))
        m0.append(hs.cast(inner, d0, 0.05))
        mb.append(add(e, mul(_eye_dir(f, up, lat, *es.angles(ch, u, 0.975)), EYE_RADIUS + (0.0026 if ch > 0 else 0.0019))))
        m1.append(add(e, mul(_eye_dir(f, up, lat, *es.angles(ch, u, 0.94)), EYE_RADIUS + 0.0004)))
        tk.append(add(e, mul(_eye_dir(f, up, lat, *es.angles(ch, u, 0.80)), EYE_RADIUS - 0.0016)))
    loops = [list(per_ids)]
    loops += _interp_loops(md, hs, per_ids, m0, EYE_LOOP_W)
    for ring in (m0, mb, m1, tk):
        loops.append([md.v(p) for p in ring])
    _relax_loops(md, hs, loops, range(1, 1 + len(EYE_LOOP_W)), 4)
    return loops


def _relax_loops(md, hs: HeadShape, loops: list[list[int]], free: range, iters: int,
                 pole: int | None = None, proj=None) -> None:
    """Laplacian relax of the loops in ``free`` (between fixed neighbour loops), re-snapped to the
    surface along the field gradient. ``pole`` closes the innermost loop when given."""
    for _ in range(iters):
        new = {}
        for k in free:
            ring = loops[k]
            n = len(ring)
            for j in range(n):
                p = md.verts[ring[j]]
                inner = md.verts[pole] if (k + 1 == len(loops) and pole is not None) else md.verts[loops[k + 1][j]]
                avg = mul(add(add(md.verts[ring[j - 1]], md.verts[ring[(j + 1) % n]]),
                              add(md.verts[loops[k - 1][j]], inner)), 0.25)
                q = lerp(p, avg, 0.5)
                new[ring[j]] = proj(q) if proj is not None else hs.snap(q, hs.grad(q), 0.006)
        for vi, q in new.items():
            md.verts[vi] = q


def _interp_loops(md, hs: HeadShape, per_ids: list[int], target: list[Vec], weights) -> list[list[int]]:
    """Loops between the block border and ``target`` (surface points), snapped to the surface along
    the interpolated surface normal."""
    nb = [hs.grad(md.verts[b]) for b in per_ids]
    nt = [hs.grad(m) for m in target]
    out = []
    for w in weights:
        ring = []
        for b, m, n1, n2 in zip(per_ids, target, nb, nt):
            ring.append(md.v(hs.snap(lerp(md.verts[b], m, w), norm(lerp(n1, n2, w)), 0.012)))
        out.append(ring)
    return out


def nose_tip(hs: HeadShape) -> Vec:
    g, a = hs.gender, hs.age
    nl = 1.0 + 0.02 * a
    return hp_to_local(0.0, -0.1165 * nl + 0.0005 + 0.0028 * g - 0.004, -0.0425 * nl - 0.0025 * a + 0.0012 * g - 0.0012)


def _nose_loops(md, hs: HeadShape, per_ids: list[int]) -> tuple[list[list[int]], int]:
    """Loops from the block border to a small ring round the tip, snapped to the surface along the
    interpolated normal, then relaxed; the tip closes with a fan."""
    c = HEAD_CENTRE
    tip = hs.cast(add(c, (0.0, 0.09, -0.02)), norm(sub(add(c, nose_tip(hs)), add(c, (0.0, 0.09, -0.02)))), 0.08)
    nt = hs.grad(tip)
    # the tip ring: directions of the border vertices round the tip, evened out towards uniform
    # spacing (border vertices that line up with the tip would otherwise collapse onto one point
    # and leave zero-area faces, worst on the small feminine nose)
    e1 = _ortho((0.0, 0.0, 1.0), nt)
    e2 = cross(nt, e1)
    ang = []
    for b in per_ids:
        q = sub(md.verts[b], tip)
        a_ = math.atan2(dot(q, e2), dot(q, e1))
        if ang:
            while a_ - ang[-1] > math.pi:
                a_ -= TAU
            while a_ - ang[-1] < -math.pi:
                a_ += TAU
        ang.append(a_)
    n_ = len(ang)
    sgn = 1.0 if ang[-1] >= ang[0] else -1.0
    # uniform reference by arc length, centred on the bottom-row midpoint (the symmetry axis, at
    # angle pi from e1 = up), so mirrored border vertices get mirrored angles
    cum = [0.0]
    for j in range(1, n_ + 1):
        cum.append(cum[-1] + vlen(sub(md.verts[per_ids[j % n_]], md.verts[per_ids[j - 1]])))
    n_bottom = len(NOSE_BLOCK[0]) - 1          # the border starts with the block's bottom row
    c_mid = 0.5 * cum[n_bottom]
    tgt = []
    for j in range(n_):
        u_ = math.pi + sgn * TAU * (cum[j] - c_mid) / cum[-1]
        u_ += TAU * round((ang[j] - u_) / TAU)
        a_ = 0.45 * ang[j] + 0.55 * u_
        d = add(mul(e1, math.cos(a_)), mul(e2, math.sin(a_)))
        tgt.append(hs.snap(add(tip, mul(d, 0.0045)), nt, 0.006))
    loops = [list(per_ids)] + _interp_loops(md, hs, per_ids, tgt, NOSE_LOOP_W)
    pole = md.v(tip)
    _relax_loops(md, hs, loops, range(1, len(loops) - 1), 6)
    return loops, pole


def mouth_line(build: float, gender: float, age: float) -> tuple[float, float, float]:
    """(half width, z of the lip line at the centre, corner drop), head-local metres."""
    return ((0.0216 - 0.0010 * gender + 0.0004 * build) * SX, -0.0756 + OZ, -0.0006 - 0.0014 * age)


def lip_heights(build: float, gender: float, age: float) -> tuple[float, float]:
    """(upper, lower) vermilion height at the centre (head-local metres): fuller for gender,
    thinner with age."""
    del build
    return ((0.0052 + 0.0032 * gender) * (1.0 - 0.28 * age), (0.0074 + 0.0012 * gender) * (1.0 - 0.22 * age))


def _vermilion_dz(ch: int, xr: float, hu: float, hl: float) -> float:
    """Vermilion border offset from the lip line at xr in -1..1 (Cupid's bow on the upper lip)."""
    if ch > 0:
        bow = 1.0 - 0.20 * math.exp(-(xr / 0.13) ** 2) + 0.10 * math.exp(-((abs(xr) - 0.30) / 0.16) ** 2)
        return 0.0004 + hu * bow * max(0.0, 1.0 - xr * xr) ** 0.62
    if ch < 0:
        return -0.0004 - hl * max(0.0, 1.0 - xr * xr) ** 0.50
    return 0.0


#: mouth loop index of the vermilion border (loops: block border, 2 interpolated, vermilion, mid-lip,
#: lip line, mouth interior). Bands from it inwards are the ``lip`` material.
MOUTH_VERMILION = 3


def _mouth_loops(md, hs: HeadShape, per_ids: list[int], chains: list[tuple[int, float]],
                 shape: tuple[float, float, float]) -> list[list[int]]:
    w_half, zc, drop = shape
    hu, hl = lip_heights(hs.build, hs.gender, hs.age)
    c = HEAD_CENTRE
    m0, tk, vm = [], [], []
    for ch, u in chains:
        x = -w_half * math.cos(math.pi * u)
        xr = x / w_half
        open_ = 1.0 - xr * xr
        z = zc + drop * xr * xr + ch * 0.0004 * open_
        hit = hs.project((c[0] + x, c[1] + 0.20, c[2] + z), (0.0, 1.0, 0.0), 0.25)
        m0.append(add(hit, (0.0, -0.0009 - 0.0006 * open_, 0.0)))
        tk.append((c[0] + x * 0.88, hit[1] - 0.0065, c[2] + zc + drop * xr * xr + ch * 0.0016 * open_))
        # vermilion border: the lip outline, a little wider than the lip line at the corners
        xv = x + math.copysign(0.0016, x) * (1.0 - open_) ** 2 if abs(xr) > 1e-6 else x
        vm.append((c[0] + xv, 0.0, c[2] + zc + drop * xr * xr + _vermilion_dz(ch, xr, hu, hl)))
    loops = [list(per_ids)]

    def front(q: Vec) -> Vec:
        return hs.project((q[0], c[1] + 0.20, q[2]), (0.0, 1.0, 0.0), 0.25)
    vm = [front(q) for q in vm]
    for w in (0.36, 0.70):
        loops.append([md.v(front(lerp(md.verts[b], m, w))) for b, m in zip(per_ids, vm)])
    loops.append([md.v(p) for p in vm])
    loops.append([md.v(front(lerp(v, m, 0.5))) for v, m in zip(vm, m0)])
    loops.append([md.v(p) for p in m0])
    _relax_loops(md, hs, loops, range(1, 3), 4, proj=front)
    loops.append([md.v(p) for p in tk])
    return loops


# =============================================================================================
# head assembly
# =============================================================================================
def _directed_edges(md, start: int) -> dict:
    out = {}
    for f in md.faces[start:]:
        n = len(f)
        for i in range(n):
            out[(f[i], f[(i + 1) % n])] = True
    return out


def _emit(md, group: list[tuple], edges: dict, mat: str | list[str] = "skin") -> None:
    """Add a face group (internally consistent winding) oriented consistently with ``edges``."""
    flip = None
    for f in group:
        n = len(f)
        for i in range(n):
            a, b = f[i], f[(i + 1) % n]
            if (a, b) in edges:
                flip = True
            elif (b, a) in edges:
                flip = False
            if flip is not None:
                break
        if flip is not None:
            break
    for i, f in enumerate(group):
        ff = tuple(reversed(f)) if flip else tuple(f)
        md.face(ff, "head", None, mat if isinstance(mat, str) else mat[i], 0)
        n = len(ff)
        for i in range(n):
            edges[(ff[i], ff[(i + 1) % n])] = True


def _bands(loops: list[list[int]]) -> list[tuple]:
    out = []
    for a, b in zip(loops, loops[1:]):
        n = len(a)
        for j in range(n):
            k = (j + 1) % n
            out.append((a[j], a[k], b[k], b[j]))
    return out


def head(md, hs: HeadShape, ref: tuple | None = None) -> list[int]:
    """Head skin (grid + eye/nose/mouth loops) stitched to ``md.rings["neck_top"]``. Sets
    ``md.rings["head_brow"]`` and returns the "free" skin vertices (grid and interpolated loops).

    ``ref = (basis_verts, basis_shape, basis_free)``: for a shape-key config, every free vertex is
    re-seated by projecting the basis vertex along the basis surface normal onto this config's
    surface, so the keys move vertices consistently (no sliding across the surface between keys,
    which would make the linear blends wobble). Lid margins, lip line, mouth interior and the
    nose tip keep their own parametric construction."""
    b, g, a = hs.build, hs.gender, hs.age
    gr = _grid(md, hs)
    rows, neck, nsplit, pole = gr["rows"], gr["neck"], gr["nsplit"], gr["pole"]
    free: list[int] = [pole] + [vi for ring in rows for vi in ring]
    nc = len(gr["cols"])
    n0 = len(neck)
    # blocks: (cols in order, r_lo, r_hi, kind, side)
    eye_cols, (er0, er1) = EYE_BLOCK
    mcols, (mr0, mr1) = MOUTH_BLOCK
    ncols, (nr0, nr1) = NOSE_BLOCK
    blocks = [([c % nc for c in eye_cols], er0, er1, "eye", 1.0),
              ([(nc - c) % nc for c in eye_cols], er0, er1, "eye", -1.0),
              ([c % nc for c in mcols], mr0, mr1, "mouth", 0.0)]
    blocks.append(([c % nc for c in ncols], nr0, nr1, "nose", 0.0))
    skip_faces: set[tuple[int, int]] = set()
    fixed: set[tuple[int, int]] = set()
    for cols, r0, r1, _kind, _sx in blocks:
        for ca, cb in zip(cols, cols[1:]):
            j = ca if (ca + 1) % nc == cb else cb
            for r in range(r0, r1):
                skip_faces.add((r, j))
        for r in range(r0, r1 + 1):
            for cc in cols:
                fixed.add((r, cc))
    _relax_grid(md, hs, gr["base"], rows, pole, HEAD_RELAX, fixed)
    # the border shared by the mouth and nose blocks must run just under the nose base: seat it on a
    # fixed line (cast on the field without the nose), blending back to the grid at the cheeks
    flat = dataclasses.replace(hs, nose=False)
    c = HEAD_CENTRE
    own: set[int] = set()        # vertices with their own (config-consistent) construction
    for cc in [c_ % nc for c_ in mcols]:
        vi = rows[nr0][cc]
        v = md.verts[vi]
        ax = abs(v[0] - c[0])
        w = 1.0 - smoothstep(0.024, 0.036, ax)
        if w <= 0.0:
            continue
        z = c[2] - 0.0405 + 0.005 * smoothstep(0.006, 0.026, ax)
        p = flat.cast((v[0], c[1], z), (0.0, 1.0, 0.0), 0.2)
        p = hs.snap(p, flat.grad(p), 0.004)
        md.verts[vi] = lerp(v, p, w)
        own.add(vi)
    free = [vi for vi in free if vi not in own]
    n_grid = len(free)

    def reseat(ids: list[int]) -> None:
        if ref is None:
            return
        ref_verts, ref_hs, _ref_free = ref
        for vi in ids:
            p0 = ref_verts[vi]
            n0 = ref_hs.grad(p0)
            q = hs.snap(p0, n0, 0.016)
            if q is p0:                       # the form moved further (e.g. the smaller feminine nose)
                q = hs.snap(p0, n0, 0.04)
            if q is p0:
                q = hs.snap(p0, hs.grad(p0), 0.04)
            md.verts[vi] = q
    if ref is not None and ref[2][:n_grid] != free:
        raise AssertionError("head topology differs from the basis")
    reseat(free)
    if ref is not None:
        # the seat line's lateral part blends to the re-seated position: its own construction per
        # config gives the key a jump against the re-seated grid beside the alae (a crease once the
        # key is added to another shape, e.g. age on the feminine face); the midline keeps it
        for vi in sorted(own):
            p_own = md.verts[vi]
            reseat([vi])
            wm = 1.0 - smoothstep(0.010, 0.024, abs(ref[0][vi][0] - c[0]))
            md.verts[vi] = lerp(md.verts[vi], p_own, wm)
    start = len(md.faces)
    # neck ring (n0) -> first head row (nc)
    group = []
    col = 0
    first = rows[0]
    for i in range(n0):
        p, q = neck[i], neck[(i + 1) % n0]
        m = nsplit[i]
        u = [first[(col + s) % nc] for s in range(m + 2)]
        if m == 0:
            group.append((p, q, u[1], u[0]))
        elif m == 1:
            group += [(p, q, u[1], u[0]), (q, u[2], u[1])]
        else:
            group += [(p, u[1], u[0]), (p, q, u[2], u[1]), (q, u[3], u[2])]
        col += m + 1
    for r, (ra, rb) in enumerate(zip(rows, rows[1:])):
        for j in range(nc):
            if (r, j) not in skip_faces:
                k = (j + 1) % nc
                group.append((ra[j], ra[k], rb[k], rb[j]))
    for j in range(nc):
        group.append((rows[-1][j], rows[-1][(j + 1) % nc], pole))
    # winding: outward at a well-shaped face at the back of the skull
    jb, rm = nc // 2, len(rows) // 2
    probe = (rows[rm][jb], rows[rm][(jb + 1) % nc], rows[rm + 1][(jb + 1) % nc], rows[rm + 1][jb])
    flip = _newell_out(md.verts, probe, HEAD_CENTRE) < 0.0
    for f in group:
        md.face(tuple(reversed(f)) if flip else f, "head", None, "skin", 0)
    edges = _directed_edges(md, start)
    # loops
    es = EyeShape.of(b, g, a)
    mouth_outer: list[int] = []
    for cols, r0, r1, kind, sx in blocks:
        per = _perimeter(cols, r0, r1)
        per_ids = [rows[r][cc] for r, cc in per]
        chains = _chains(per, [md.verts[i] for i in per_ids], cols, EYE_CORNER_ROW if kind == "eye" else (r0 + r1) // 2)
        if kind == "eye":
            loops = _eye_loops(md, hs, sx, per_ids, chains, es)
            n = len(per_ids)
            nb = len(EYE_LOOP_W) + 1          # band index of m0 -> mb
            mats = []
            first = len(md.faces)
            for k in range(len(loops) - 1):
                for j in range(n):
                    upper = chains[j][0] >= 0 and chains[(j + 1) % n][0] >= 0 and (chains[j][0] + chains[(j + 1) % n][0]) > 0
                    mats.append("lash" if upper and k in (nb, nb + 1) else "skin")
                    # the lid band just above the lash line, lateral two thirds: a thicker lash line
                    # (``MeshData.lash_extra``; used when gender > 0.5)
                    uu = 0.5 * (chains[j][1] + chains[(j + 1) % n][1])
                    if upper and k == nb - 1 and uu > 0.22:
                        md.lash_extra.append(first + k * n + j)
            _emit(md, _bands(loops), edges, mats)
            free += [vi for ring in loops[1:1 + len(EYE_LOOP_W)] for vi in ring]
        elif kind == "nose":
            loops, pole_n = _nose_loops(md, hs, per_ids)
            last = loops[-1]
            fan = [(last[j], last[(j + 1) % len(last)], pole_n) for j in range(len(last))]
            _emit(md, _bands(loops) + fan, edges)
            # the outer nose loops are re-seated like the grid (see ``reseat``): their own cast would
            # give the build/age keys a jump against the grid at the block border (creases beside
            # the alae once a key is added to another shape, e.g. age on the feminine face)
            free += [vi for ring in loops[1:3] for vi in ring]
        else:
            loops = _mouth_loops(md, hs, per_ids, chains, mouth_line(b, g, a))
            mouth_outer = [vi for ring in loops[1:3] for vi in ring]
            n = len(per_ids)
            mats = ["lip" if k >= MOUTH_VERMILION else "skin" for k in range(len(loops) - 1) for _j in range(n)]
            _emit(md, _bands(loops), edges, mats)
            tk = loops[-1]
            n = len(tk)
            i_r = next(i for i, (ch, u) in enumerate(chains) if ch == 0 and u > 0.5)
            i_l = next(i for i, (ch, u) in enumerate(chains) if ch == 0 and u < 0.5)
            up = []
            i = i_r
            while i != i_l:
                up.append(i)
                i = (i + 1) % n
            up.append(i_l)
            lo = []
            i = i_r
            while i != i_l:
                lo.append(i)
                i = (i - 1) % n
            lo.append(i_l)
            close = []
            for s in range(len(up) - 1):
                a0, a1, b0, b1 = tk[up[s]], tk[up[s + 1]], tk[lo[s]], tk[lo[s + 1]]
                if a0 == b0:
                    close.append((a0, a1, b1))
                elif a1 == b1:
                    close.append((a0, a1, b0))
                else:
                    close.append((a0, a1, b1, b0))
            _emit(md, close, edges, "lip")
    s_rows = gr["s_rows"]
    md.rings["head_brow"] = rows[min(range(1, HEAD_ROWS), key=lambda r: abs(s_rows[r] - 0.62)) - 1]
    reseat(free[n_grid:])
    if ref is not None:
        _smooth_key(md, ref[0], start, set(free) | own | set(mouth_outer), KEY_SMOOTH)
    return free


#: Jacobi iterations smoothing a re-seated key's displacement over the skin (see ``_smooth_key``)
KEY_SMOOTH = 6


def _smooth_key(md, ref_verts: list, start: int, movable: set, iters: int) -> None:
    """Smooth the displacement (this config - basis) of the ``movable`` skin vertices over the head
    faces from ``start`` on; the other vertices (neck ring, lid margins, lip loops, nose tip) hold their
    displacement. A key is added to every other shape (age on the feminine face, build on the old
    one), so a displacement that changes sharply between neighbours (a cast landing on either side
    of a groove) creases the sum even where the key alone looks clean."""
    nbr: dict[int, set] = {}
    for f in md.faces[start:]:
        n = len(f)
        for i in range(n):
            a_, b_ = f[i], f[(i + 1) % n]
            if a_ in movable:
                nbr.setdefault(a_, set()).add(b_)
            if b_ in movable:
                nbr.setdefault(b_, set()).add(a_)
    ids = sorted(nbr)
    dlt = {}
    for vi in {v for s_ in nbr.values() for v in s_} | set(ids):
        dlt[vi] = sub(md.verts[vi], ref_verts[vi])
    for _ in range(iters):
        new = {}
        for vi in ids:
            ns = sorted(nbr[vi])
            avg = mul(_vsum3([dlt[v] for v in ns]), 1.0 / len(ns))
            new[vi] = lerp(dlt[vi], avg, 0.5)
        dlt.update(new)
    for vi in ids:
        md.verts[vi] = add(ref_verts[vi], dlt[vi])


def _vsum3(vs: list) -> Vec:
    x = y = z = 0.0
    for v in vs:
        x += v[0]
        y += v[1]
        z += v[2]
    return (x, y, z)


def _newell_out(verts: list, idx, inside: Vec) -> float:
    nx = ny = nz = 0.0
    n = len(idx)
    cx = cy = cz = 0.0
    for i in range(n):
        a = verts[idx[i]]
        b = verts[idx[(i + 1) % n]]
        nx += (a[1] - b[1]) * (a[2] + b[2])
        ny += (a[2] - b[2]) * (a[0] + b[0])
        nz += (a[0] - b[0]) * (a[1] + b[1])
        cx += a[0]
        cy += a[1]
        cz += a[2]
    return dot((nx, ny, nz), sub((cx / n, cy / n, cz / n), inside))


# =============================================================================================
# eyes, ears, brows (separate parts, rigid to the head bone)
# =============================================================================================
def _lat_long(md, centre: Vec, radii: Vec, axes: tuple[Vec, Vec, Vec], segs: int, polar: list[float],
              mat_of_band, side: int) -> None:
    """Lat-long ellipsoid around ``axes[0]`` (pole) with polar angles ``polar`` (degrees, 0..180)."""
    a0, a1, a2 = axes
    rings: list[list[int]] = []
    for pi_, ang in enumerate(polar):
        th = math.radians(ang)
        if pi_ in (0, len(polar) - 1):
            vi = md.v(add(centre, mul(a0, radii[0] * math.cos(th))))
            md.vert_rigid[vi] = "head"
            rings.append([vi])
            continue
        ring = []
        for k in range(segs):
            ph = TAU * k / segs
            p = add(centre, add(mul(a0, radii[0] * math.cos(th)), add(mul(a1, radii[1] * math.sin(th) * math.cos(ph)),
                                                                     mul(a2, radii[2] * math.sin(th) * math.sin(ph)))))
            vi = md.v(p)
            md.vert_rigid[vi] = "head"
            ring.append(vi)
        rings.append(ring)
    for ri in range(len(rings) - 1):
        a, b = rings[ri], rings[ri + 1]
        mat = mat_of_band(ri)
        if len(a) == 1:
            md.fan(b, a[0], "head", centre, mat, side)
        elif len(b) == 1:
            md.fan(a, b[0], "head", centre, mat, side)
        else:
            md.band(a, b, "head", centre, mat=mat, side=side)


def eyes(md) -> None:
    """Eyeballs (sclera + iris cap), rigid to ``head``; the lids are skin loops (``head``)."""
    for _sfx, sx in rig.SIDES:
        c = add(HEAD_CENTRE, (sx * EYE_LOCAL[0], EYE_LOCAL[1], EYE_LOCAL[2]))
        fwd = norm((sx * 0.06, 1.0, 0.0))
        up = (0.0, 0.0, 1.0)
        side_ax = norm(cross(fwd, up))
        polar = [0.0, 11.0, 19.0, 29.0, 40.0, 62.0, 95.0, 135.0, 180.0]
        _lat_long(md, c, (EYE_RADIUS, EYE_RADIUS, EYE_RADIUS), (fwd, up, side_ax), 16, polar,
                  lambda ri: "lash" if ri == 0 else "iris" if ri <= 2 else "eye", int(sx))


# ear outline radius (fraction of the ear frame) by angle: 0 = towards the face, 90 = up, 180 = back
_EAR_OUTLINE = [(0.0, 0.0125), (40.0, 0.0215), (90.0, 0.0285), (140.0, 0.0245), (180.0, 0.0195),
                (225.0, 0.0205), (270.0, 0.0300), (310.0, 0.0215), (360.0, 0.0125)]
# radial profile rings: (rho, helix-part height, lobe-part height, front-part height) along the ear normal (m)
_EAR_RINGS = [(0.22, -0.0040, -0.0026, -0.0032), (0.45, -0.0012, -0.0004, -0.0008), (0.62, 0.0022, 0.0016, 0.0016),
              (0.78, 0.0004, 0.0018, 0.0020), (0.90, 0.0032, 0.0016, 0.0020), (1.00, 0.0042, 0.0006, 0.0006),
              (1.035, 0.0018, -0.0016, -0.0020), (0.97, -0.0014, -0.0040, -0.0060), (0.78, -0.0048, -0.0060, -0.0090),
              (0.42, -0.0085, -0.0080, -0.0110)]
_EAR_SEGS = 16


def _wrap_interp(table: list[tuple[float, float]], x: float) -> float:
    x %= 360.0
    for (x0, y0), (x1, y1) in zip(table, table[1:]):
        if x <= x1:
            t = (x - x0) / (x1 - x0)
            t = t * t * (3.0 - 2.0 * t)
            return y0 + (y1 - y0) * t
    return table[-1][1]


def ears(md, hs: HeadShape) -> None:
    """Ears: helix rim rolled over a scapha groove, antihelix ridge, concha bowl, fleshy lobe; the back
    surface and the front edge sink into the head. Rigid to ``head``."""
    b, a = hs.build, hs.age
    s = 1.0 + 0.07 * a
    for _sfx, sx in rig.SIDES:
        sp = hs.cast(add(HEAD_CENTRE, (0.0, -0.0112, 0.0050)), (sx, 0.0, 0.0))
        c = (sp[0] + sx * 0.0080, sp[1], sp[2])
        n = norm((sx * 1.0, -0.30, 0.0))
        up = _ortho(norm((0.0, -0.22, 1.0)), n)
        fw = mul(norm(cross(up, n)), sx)
        o2 = (0.0030, -0.0015)              # concha centre in the (fw, up) plane
        rings: list[list[int]] = []
        front_pole = md.v(add(add(c, add(mul(fw, o2[0]), mul(up, o2[1]))), mul(n, -0.0046)))
        for rho, hh, hl, hf in _EAR_RINGS:
            ring = []
            for k in range(_EAR_SEGS):
                al = 360.0 * k / _EAR_SEGS
                r = _wrap_interp(_EAR_OUTLINE, al) * s
                if 230.0 < al < 320.0:
                    r *= 1.0 + 0.10 * a * math.sin(math.radians((al - 230.0) * 2.0))   # longer lobe with age
                ar = math.radians(al)
                # part weights: lobe (bottom), front (attached edge, tragus), helix (rest)
                wl = smoothstep(200.0, 245.0, al) * (1.0 - smoothstep(305.0, 335.0, al))
                wf = max(1.0 - smoothstep(18.0, 50.0, al), smoothstep(320.0, 352.0, al))
                wf *= 1.0 - wl
                wh = max(0.0, 1.0 - wl - wf)
                h = wh * hh + wl * hl + wf * hf
                h *= 1.0 + 0.15 * b
                pa = o2[0] + r * rho * math.cos(ar)
                pu = o2[1] + r * rho * math.sin(ar)
                vi = md.v(add(c, add(add(mul(fw, pa), mul(up, pu)), mul(n, h))))
                md.vert_rigid[vi] = "head"
                ring.append(vi)
            rings.append(ring)
        back_pole = md.v(add(add(c, add(mul(fw, o2[0]), mul(up, o2[1]))), mul(n, -0.0115)))
        md.vert_rigid[front_pole] = "head"
        md.vert_rigid[back_pole] = "head"
        faces = []
        m = _EAR_SEGS
        for j in range(m):
            faces.append((front_pole, rings[0][j], rings[0][(j + 1) % m]))
        for ra, rb in zip(rings, rings[1:]):
            for j in range(m):
                k = (j + 1) % m
                faces.append((ra[j], ra[k], rb[k], rb[j]))
        for j in range(m):
            faces.append((rings[-1][j], back_pole, rings[-1][(j + 1) % m]))
        # orientation: a front face at the top of the rim must face along +n
        probe = (rings[3][4], rings[3][5], rings[4][5], rings[4][4])
        flip = _newell_out(md.verts, probe, sub(md.verts[rings[3][4]], n)) < 0.0
        for f in faces:
            md.face(tuple(reversed(f)) if flip else f, "head", None, "skin", int(sx))


def brows(md, hs: HeadShape) -> None:
    """Eyebrows: tapered raised ribbons on the brow shelf (thick medial head, arch at ~2/3, thin
    tail), the edges tucked into the skin. Finer and higher for gender, drooping tail with age."""
    g, a = hs.gender, hs.age
    c = HEAD_CENTRE
    n_seg = 9
    for _sfx, sx in rig.SIDES:
        rows: list[list[int]] = [[], [], [], []]
        for i in range(n_seg + 1):
            u = i / n_seg
            x = sx * (0.0145 + 0.042 * u)
            arch = math.sin(math.pi * min(1.0, u / 0.68) * 0.5) if u < 0.68 else math.cos(math.pi * (u - 0.68) / 0.64 * 0.5)
            arch_g = arch ** (1.0 + 0.5 * g)                 # feminine: a higher, sharper arch
            z = (c[2] + 0.0362 + (0.0036 + 0.0010 * g) * arch_g - 0.0035 * u * u + 0.0008 * g
                 - (0.0008 + 0.0024 * u * u) * a)
            th = (0.0044 * (1.0 - u) ** (0.8 + 0.5 * g) + 0.0008 * (1.0 - 0.4 * g)) * (0.75 + 0.25 * smoothstep(0.0, 0.2, u)) * (1.0 - 0.50 * g) * (1.0 + 0.12 * a)
            lift = 0.0017 * (1.0 - 0.4 * u) * (1.0 - 0.25 * g) * (0.15 + 0.85 * smoothstep(0.0, 0.16, u)) * (1.0 - 0.8 * smoothstep(0.85, 1.0, u))
            for row, dz, lf in ((0, th, 0.00012), (1, th * 0.35, lift), (2, -th * 0.45, lift * 0.8),
                                (3, -th, 0.00012)):
                zz = z + dz
                org = (0.0, c[1], zz)
                p = hs.cast(org, norm(sub((x * 1.35, 0.12, zz), org)))
                vi = md.v(add(p, mul(hs.grad(p), lf)))
                md.vert_rigid[vi] = "head"
                rows[row].append(vi)
        inside = add(c, (sx * 0.02, 0.0, 0.03))
        for r in range(3):
            md.band(rows[r], rows[r + 1], "head", inside, closed=False, mat="brow", side=int(sx))


# =============================================================================================
# hair (separate mesh): cap volumes with a rolled edge, strand clumps and a broken hairline
# =============================================================================================
#: |theta| (deg, 0 = front) -> polar angle phi (deg from the crown) of the hairline. The line rises
#: over the ear (ear top ~66 deg) and drops behind it to the nape.
_HAIRLINE = {
    "buzz": [(0.0, 45.0), (40.0, 53.0), (60.0, 60.0), (72.0, 84.0), (84.0, 66.0), (97.0, 60.0), (112.0, 68.0),
             (132.0, 100.0), (180.0, 117.0)],
    "short": [(0.0, 43.0), (40.0, 52.0), (60.0, 60.0), (72.0, 86.0), (84.0, 67.0), (97.0, 60.0), (112.0, 68.0),
              (132.0, 101.0), (180.0, 119.0)],
    "bob": [(0.0, 42.0), (35.0, 52.0), (75.0, 112.0), (130.0, 116.0), (180.0, 118.0)],
}
_HAIRLINE["side_part"] = _HAIRLINE["short"]
_HAIRLINE["bald"] = [(0.0, 64.0), (80.0, 66.0), (95.0, 62.0), (112.0, 70.0), (138.0, 100.0), (180.0, 116.0)]
#: style -> (columns, main rows). Every key/variant of a style shares the grid (shape keys need it).
#: buzz keeps 48 x 9 (1200 tris; it is on the tightest specials); short 1728, side_part 1856, bob 2088.
HAIR_GRID = {"buzz": (48, 9), "short": (64, 10), "side_part": (64, 11), "bob": (72, 11)}
BALD_COLS = 30
PART_THETA = 30.0      # side_part: parting line angle (deg, + = character's right)
BALD_END = 82.0        # bald: the horseshoe fringe covers |theta| >= this


@dataclass(frozen=True)
class HairFlow:
    """Combing direction and breakup of a style. The strands run on great circles through ``pole``
    (theta, phi deg: the crown whorl, or beside the parting for ``side_part``); the volume is split
    into ``clumps`` irregular strand groups around the pole, separated by grooves ``groove`` (fraction
    of the volume) deep. ``fringe``/``edge``: hairline clump amplitude (deg of phi) over the forehead /
    elsewhere; ``taper``: thinning of the edge at the sideburns and the nape; ``lump``: subtractive
    low-frequency volume breakup. ``hem``: bob tip length (m). ``uv``: (u repeats round the pole,
    v scale) of the strand texture (buzz: finer, short strands)."""

    pole: tuple[float, float]
    clumps: int
    groove: float
    fringe: float
    edge: float
    taper: float
    lump: float
    hem: float = 0.0
    uv: tuple[int, float] = (2, 1.0)


HAIR_FLOW = {
    "buzz": HairFlow((180.0, 24.0), 36, 0.0, 1.2, 0.5, 0.30, 0.05, uv=(3, 16.0)),
    "short": HairFlow((180.0, 24.0), 18, 0.55, 3.2, 1.3, 0.55, 0.12),
    "side_part": HairFlow((105.0, 85.0), 20, 0.48, 3.2, 1.3, 0.55, 0.12),
    "bob": HairFlow((0.0, 0.0), 21, 0.36, 2.6, 0.0, 0.0, 0.12, hem=0.014),
    "bald": HairFlow((180.0, 24.0), 16, 0.30, 0.0, 0.7, 0.0, 0.10),
}
#: UV v per radian from the flow pole. Across the strands the texture is squeezed ~7x (u: twice round
#: a ~0.55 m head per 2 m tile), along them stretched ~4x (0.1 m of arc per radian: 0.024 tile-m), so the
#: hair textures' grain reads as long strands.
HAIR_UV_V = 0.012


def _h01(i: int, salt: int) -> float:
    """Deterministic hash of (i, salt) to [0, 1) (integer mixing; no RNG)."""
    x = (i * 0x9E3779B1 + salt * 0x85EBCA77 + 0x165667B1) & 0xFFFFFFFF
    x ^= x >> 15
    x = (x * 0x2C1B3C6D) & 0xFFFFFFFF
    x ^= x >> 12
    x = (x * 0x297A2D39) & 0xFFFFFFFF
    x ^= x >> 15
    return x / 4294967296.0


def _flow_frame(style: str) -> tuple[Vec, Vec, Vec]:
    f = HAIR_FLOW[style]
    a = _head_dir(math.radians(f.pole[0]), math.radians(f.pole[1]))
    ref = (0.0, 1.0, 0.0) if abs(a[1]) < 0.9 else (1.0, 0.0, 0.0)
    e1 = norm(cross(ref, a))
    return a, e1, cross(a, e1)


def hair_flow(style: str, d: Vec) -> tuple[float, float]:
    """(azimuth around the flow pole in [0, 1), angle from the pole in radians) of a direction from
    the head centre. Strands run along constant azimuth; the hair UVs are (azimuth, angle)."""
    a, e1, e2 = _flow_frame(style)
    s = (math.atan2(dot(d, e2), dot(d, e1)) / TAU) % 1.0
    return s, math.acos(_clamp(dot(d, a), -1.0, 1.0))


def _clump_bounds(style: str) -> list[float]:
    n = HAIR_FLOW[style].clumps
    w = [0.65 + 0.7 * _h01(i, 1) for i in range(n)]
    tot = sum(w)
    out, acc = [0.0], 0.0
    for x in w:
        acc += x / tot
        out.append(acc)
    out[-1] = 1.0
    return out


_CLUMPS = {s: _clump_bounds(s) for s in HAIR_FLOW}


def _clump(style: str, s: float) -> tuple[float, float]:
    """(groove 0..1, bulge 0..1) at flow azimuth ``s``: grooves between the clumps, each clump with
    its own groove depth and tip length."""
    b = _CLUMPS[style]
    i = 0
    while i < len(b) - 2 and s >= b[i + 1]:
        i += 1
    x = _clamp((s - b[i]) / (b[i + 1] - b[i]), 0.0, 1.0)
    groove = (0.6 + 0.4 * _h01(i, 2)) * math.cos(math.pi * x) ** 2
    bulge = (0.35 + 0.65 * _h01(i, 3)) * math.sin(math.pi * x) ** 1.5
    return groove, bulge


def _lump(d: Vec) -> float:
    """Smooth low-frequency field in 0..1 over directions (volume breakup)."""
    return 0.5 + 0.25 * (math.sin(7.0 * d[0] + 3.0 * d[2] + 0.6) * math.sin(5.0 * d[1] - 2.0 * d[2] + 1.7)
                         + math.sin(6.0 * d[1] + 4.0 * d[0] + 2.3))


def _volume_mod(style: str, d: Vec) -> float:
    """Volume multiplier (<= 1: grooves and breakup only cut in, so the outer envelope is kept)."""
    f = HAIR_FLOW[style]
    s, dist = hair_flow(style, d)
    g, _b = _clump(style, s)
    fade = smoothstep(math.radians(6.0), math.radians(30.0), dist)       # no star at the whorl
    return (1.0 - f.groove * g * fade) * (1.0 - f.lump * _lump(d))


def _edge_taper(style: str, ath: float) -> float:
    """Edge thickness factor: thinner at the sideburns and the nape (short styles fade out there)."""
    f = HAIR_FLOW[style]
    return 1.0 - f.taper * max(math.exp(-((ath - 80.0) / 11.0) ** 2), smoothstep(120.0, 165.0, ath))


def _interp(table: list[tuple[float, float]], x: float) -> float:
    for (x0, y0), (x1, y1) in zip(table, table[1:]):
        if x <= x1:
            t = (x - x0) / (x1 - x0)
            t = t * t * (3.0 - 2.0 * t)
            return y0 + (y1 - y0) * t
    return table[-1][1]


def _thickness(style: str, th_deg: float, phi_deg: float) -> float:
    """Hair volume (m off the scalp) at a direction (theta from the front, phi from the crown)."""
    tt = _clamp(1.0 - phi_deg / 95.0, 0.0, 1.0)            # 1 at the crown, 0 around the hairline
    front = max(0.0, math.cos(math.radians(th_deg))) ** 2
    if style == "buzz":
        return 0.0024 + 0.0012 * tt
    if style in ("short", "bald"):
        return 0.0036 + 0.0080 * smoothstep(0.22, 0.72, tt) + 0.0022 * front * smoothstep(0.15, 0.45, tt)
    if style == "side_part":
        t = 0.0040 + 0.0088 * smoothstep(0.18, 0.70, tt)
        d = math.degrees(math.atan2(math.sin(math.radians(th_deg - PART_THETA)), math.cos(math.radians(th_deg - PART_THETA))))
        lead = smoothstep(-0.35, 0.2, math.cos(math.radians(th_deg)))          # the part runs over the front half
        t *= 1.0 - 0.80 * math.exp(-(d / 5.0) ** 2) * smoothstep(0.25, 0.50, tt) * lead
        t += 0.0045 * smoothstep(0.0, -30.0, d) * smoothstep(0.2, 0.6, tt) * lead   # swept-over side, fuller
        return t
    # bob: clears the ears (they sit under it)
    ear = math.exp(-((abs(th_deg) - 98.0) / 30.0) ** 2) * smoothstep(48.0, 72.0, phi_deg)
    return 0.0085 + 0.0075 * smoothstep(0.30, 0.80, tt) + 0.016 * ear


def hair(hs: HeadShape, style: str, peak: float = 0.0):
    """Hair mesh (``MeshData``; empty for "none"), rigid to ``head``. The edge rolls from the scalp
    up into the volume (rounded, with real thickness at the hairline); a bob hangs straight below
    its widest point and its hem turns under. The volume is cut into strand clumps along the combing
    direction (``HAIR_FLOW``), the hairline breaks into small clumps over the forehead (``peak`` 0..1
    adds a widow's peak), short styles thin out at the sideburns and the nape, and the bob's hem ends
    in irregular tips."""
    from _body import MeshData  # noqa: PLC0415  (import here: _body imports this module)

    md = MeshData()
    if style == "none":
        return md
    c = HEAD_CENTRE
    table = _HAIRLINE[style]
    flow = HAIR_FLOW[style]
    bald = style == "bald"
    if bald:
        ncol, nmain = BALD_COLS, 0
        thetas = [math.radians(BALD_END + (360.0 - 2.0 * BALD_END) * k / (ncol - 1)) for k in range(ncol)]
    else:
        ncol, nmain = HAIR_GRID[style]
        thetas = []
        for k in range(ncol):
            th0 = math.pi - TAU * k / ncol
            thetas.append(th0 - COLUMN_WARP * 0.55 * math.sin(th0))
    columns: list[list[Vec]] = []
    for th in thetas:
        thd = math.degrees(math.atan2(math.sin(th), math.cos(th)))
        ath = abs(thd)
        phi_h = _interp(table, ath)
        # broken hairline: the clumps reach a little over the hairline (more over the forehead)
        front = smoothstep(60.0, 25.0, ath)
        amp = flow.fringe * front + flow.edge * (1.0 - front)
        _g, bulge = _clump(style, hair_flow(style, _head_dir(th, math.radians(phi_h)))[0])
        phi_h += amp * (bulge - 0.2)
        if peak:
            phi_h += peak * (6.0 * math.exp(-(ath / 8.0) ** 2) - 3.0 * math.exp(-((ath - 30.0) / 12.0) ** 2))
        taper = 1.0
        if bald:
            taper = smoothstep(BALD_END - 2.0, BALD_END + 28.0, ath)
            phi_top = phi_h - (15.0 + 28.0 * smoothstep(105.0, 160.0, ath)) * (0.35 + 0.65 * taper)
        et = _edge_taper(style, ath)

        def surf(phi: float, th: float = th) -> tuple[Vec, Vec]:
            p = hs.cast(c, _head_dir(th, math.radians(phi)))
            return p, hs.grad(p)

        def vol(phi: float, ath: float = ath, th: float = th, taper: float = taper, et: float = et,
                phi_h: float = phi_h, full: bool = False) -> float:
            t = _thickness(style, ath, phi) * taper
            if full:
                return t
            near = 1.0 - smoothstep(0.0, 16.0, phi_h - phi)                # 1 at the hairline
            return t * _volume_mod(style, _head_dir(th, math.radians(phi))) * (1.0 - (1.0 - et) * near)

        def roll(phi_edge: float, toward: float, surf=surf, vol=vol) -> list[Vec]:
            """Edge rows at the hairline phi_edge, the volume lying towards phi + toward."""
            h_, n_ = surf(phi_edge)
            q_, _ = surf(phi_edge + toward * 2.0)
            v_ = norm(sub(q_, h_))
            t_ = vol(phi_edge)
            rr = min(0.6 * t_, 0.0035)
            k45 = 0.7071
            return [add(add(h_, mul(n_, -0.0006)), mul(v_, -0.0006)),
                    add(h_, mul(n_, max(t_ - rr, 0.2 * t_))),
                    add(add(h_, mul(n_, t_ - rr + rr * k45)), mul(v_, rr * (1.0 - k45))),
                    add(add(h_, mul(n_, t_ - rr * 0.06)), mul(v_, rr * 0.65))]

        def main(phi: float, full: bool = False, surf=surf, vol=vol) -> Vec:
            p, n_ = surf(phi)
            return add(p, mul(n_, vol(phi, full=full)))

        step = math.degrees(0.0035 / 0.095)
        if bald:
            lo = roll(phi_h, -1.0)
            hi = roll(phi_top, 1.0)
            mids = [main(phi_h - step - (phi_h - phi_top - 2.0 * step) * f) for f in (0.2, 0.5, 0.8)]
            columns.append(lo + mids + list(reversed(hi)))
            continue
        edge = roll(phi_h, -1.0)
        phi0 = phi_h - step
        phis = [phi0 * (1.0 - r / (nmain - 0.3)) ** 1.15 for r in range(nmain)]
        rows_m = [main(ph) for ph in phis]
        col = edge + rows_m
        if style == "bob" and math.cos(th) < 0.80:
            # hang straight below the widest point of the column (grooves kept); the hem ends in
            # irregular tips (clumps longer, grooves shorter) and turns under, thinner at the tips
            rows_f = [main(ph, full=True) for ph in phis]
            rad = [math.hypot(q[0] - c[0], q[1] - c[1]) for q in rows_f]
            wi = max(range(len(rows_f)), key=lambda i: rad[i])
            rw = rad[wi]
            o = norm((rows_f[0][0] - c[0], rows_f[0][1] - c[1], 0.0))
            blend = smoothstep(0.80, 0.55, math.cos(th))
            _g, tip = _clump(style, hair_flow(style, _head_dir(th, math.radians(phis[0])))[0])
            dz = -(flow.hem * tip - 0.0025) * blend
            for r in range(wi):
                q = rows_m[r]
                rr_ = math.hypot(q[0] - c[0], q[1] - c[1])
                target = max(rad[r], rw * (1.0 - 0.015 * (wi - r) / max(wi, 1))) - (rad[r] - rr_)
                want = rr_ + (target - rr_) * blend
                rows_m[r] = (c[0] + o[0] * want, c[1] + o[1] * want, q[2] + dz * (1.0 - r / wi) ** 1.2)
            b0 = rows_m[0]
            tb = 0.0075 * (1.0 - 0.45 * tip)
            hem = [edge[0],
                   add(b0, add(mul(o, -tb), (0.0, 0.0, 0.006))),
                   add(b0, add(mul(o, -0.55 * tb), (0.0, 0.0, -0.0022))),
                   add(b0, add(mul(o, -0.08 * tb), (0.0, 0.0, -0.0012)))]
            col = [lerp(e_, h_, blend) for e_, h_ in zip(edge, hem)] + rows_m
        columns.append(col)
    vid = [[md.v(p) for p in col] for col in columns]
    nr = len(vid[0])
    faces: list[tuple] = []
    nc = len(vid)
    for k in range(nc if not bald else nc - 1):
        a_, b_ = vid[k], vid[(k + 1) % nc]
        for r in range(nr - 1):
            faces.append((a_[r], b_[r], b_[r + 1], a_[r + 1]))
    if not bald:
        pt = hs.cast(c, (0.0, 0.0, 1.0))
        pn = hs.grad(pt)
        pole = md.v(add(pt, mul(pn, _thickness(style, 0.0, 0.0) * _volume_mod(style, (0.0, 0.0, 1.0)))))
        for k in range(nc):
            faces.append((vid[k][-1], vid[(k + 1) % nc][-1], pole))
        mid = nr - 3
    else:
        mid = nr // 2
    k0 = nc // 2
    probe = (vid[k0][mid], vid[k0 + 1][mid], vid[k0 + 1][mid + 1], vid[k0][mid + 1])
    flip = _newell_out(md.verts, probe, c) < 0.0
    for f in faces:
        md.face(tuple(reversed(f)) if flip else f, "head", None, "hair", 0)
    for vi in range(len(md.verts)):
        md.vert_rigid[vi] = "head"
    return md


def hair_uvs(faces: list, verts: list, style: str, k: float) -> list[list[tuple[float, float]]]:
    """Per-face-corner UVs of the hair mesh along the strands: u = azimuth around the flow pole
    (``HairFlow.uv`` whole repeats round, so the tileable hair textures close without a seam), v =
    angle from the pole (``HAIR_UV_V``): the texture is squeezed across the strands and stretched
    along them."""
    c = mul(HEAD_CENTRE, k)
    rep, vs = HAIR_FLOW[style].uv
    per = []
    for p in verts:
        s, dist = hair_flow(style, norm(sub(p, c)))
        per.append((s, dist * HAIR_UV_V * vs, dist < 1e-3))
    out = []
    for f in faces:
        us = [per[v][0] for v in f if not per[v][2]]
        if us and max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        mean = sum(us) / len(us) if us else 0.0
        it = iter(us)
        out.append([((mean if per[v][2] else next(it)) * rep, per[v][1]) for v in f])
    return out
