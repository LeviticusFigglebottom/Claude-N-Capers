"""Procedural humanoid base mesh for ``rig_humanoid`` (pure numpy; no Blender needed).

The body is one connected, quad-dominant surface built from lofted rings, so every joint gets
edge loops perpendicular to its bone (good deformation):

* torso + neck + head: one tube of ``C`` columns (denser at the front for the face), closed by a
  pole at the crown;
* legs: the torso's bottom ring is split along the crotch seam into two leg rings;
* arms: lofted from a rectangular hole in each side of the chest;
* hands: the arm tube continues into the palm; the palm's end loop splits into four finger tubes;
  the thumb grows from a small hole in the palm;
* feet: a shoe-shaped tube along +Y with a hole in its top that the leg is bridged into.

Separate small parts (eyes, ears) live in the same mesh. Skin weights are computed from each
vertex's part and its position along that part (not from Blender's automatic weights), so the
output is deterministic. Parameters: ``scale`` (height / 1.78 m, applied through the skeleton),
``gender`` 0 male .. 1 female, ``build`` -1 slim .. 1 heavy, ``age`` 0 young .. 1 old.
Blender axes: +Z up, +Y forward, left side -X.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

import rig

C = 36                 # torso / head columns
WARP = 0.45            # column density warp: front (face) denser, back sparser
LEG_N = C // 2 + 1 + 3  # 22: half torso ring + 3 crotch-seam vertices
ARM_N = 18             # hole 5 rows x 4 cols on the chest side
FOOT_N = 20
FINGER_N = 6
THUMB_N = 6

TAU = 2.0 * math.pi


# ------------------------------------------------------------------------------------------
# small math helpers
# ------------------------------------------------------------------------------------------
def v3(x, y, z) -> np.ndarray:
    return np.array([x, y, z], dtype=np.float64)


def unit(v: np.ndarray) -> np.ndarray:
    return v / np.linalg.norm(v)


def smoothstep(e0: float, e1: float, x: float) -> float:
    if e1 == e0:
        return 1.0 if x >= e1 else 0.0
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def wrap(a: float) -> float:
    """Wrap an angle to (-pi, pi]."""
    return (a + math.pi) % TAU - math.pi


def hermite(xs: list[float], ys: np.ndarray, x: float) -> np.ndarray:
    """Cubic Hermite interpolation of rows ``ys`` (n, k) at ``x`` (clamped), Catmull-Rom tangents."""
    n = len(xs)
    if x <= xs[0]:
        return ys[0].copy()
    if x >= xs[-1]:
        return ys[-1].copy()
    i = 0
    while i < n - 2 and x > xs[i + 1]:
        i += 1
    x0, x1 = xs[i], xs[i + 1]
    h = x1 - x0
    t = (x - x0) / h

    def tangent(k: int) -> np.ndarray:
        if k == 0:
            return (ys[1] - ys[0]) / (xs[1] - xs[0])
        if k == n - 1:
            return (ys[-1] - ys[-2]) / (xs[-1] - xs[-2])
        return (ys[k + 1] - ys[k - 1]) / (xs[k + 1] - xs[k - 1])

    m0, m1 = tangent(i) * h, tangent(i + 1) * h
    t2, t3 = t * t, t * t * t
    return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * m0
            + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * m1)


def periodic_profile(ctrl: np.ndarray, phi: float) -> float:
    """Radius at angle ``phi`` from symmetric control radii at 0,30,..,180 degrees (Catmull-Rom)."""
    full = list(ctrl) + list(ctrl[-2:0:-1])     # 0..330 degrees, 12 values
    m = len(full)
    a = (abs(wrap(phi)) / TAU) * m             # symmetric: use |phi|
    i = int(math.floor(a)) % m
    t = a - math.floor(a)
    p0, p1, p2, p3 = full[(i - 1) % m], full[i], full[(i + 1) % m], full[(i + 2) % m]
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


def column_angle(j: int) -> float:
    """Angle (0 = front, +pi/2 = character's right (+X)) of torso/head column ``j``."""
    th = TAU * j / C
    return wrap(th - WARP * math.sin(th))


# ------------------------------------------------------------------------------------------
# profile tables (male, average build, 1.78 m; radii in metres at angles 0,30,..,180 degrees)
# ------------------------------------------------------------------------------------------
TORSO_ROWS = [
    # z,     cy,     r0,    r30,   r60,   r90,   r120,  r150,  r180
    (0.855, -0.005, 0.070, 0.082, 0.118, 0.150, 0.128, 0.095, 0.078),
    (0.900, -0.005, 0.088, 0.096, 0.126, 0.162, 0.142, 0.115, 0.098),
    (0.950, -0.005, 0.094, 0.101, 0.128, 0.166, 0.148, 0.124, 0.104),
    (1.000, -0.005, 0.099, 0.103, 0.123, 0.157, 0.137, 0.114, 0.094),
    (1.050, -0.005, 0.104, 0.105, 0.116, 0.147, 0.122, 0.097, 0.084),
    (1.100, -0.008, 0.108, 0.107, 0.114, 0.140, 0.117, 0.095, 0.085),
    (1.160, -0.010, 0.111, 0.111, 0.119, 0.144, 0.121, 0.100, 0.090),
    (1.220, -0.012, 0.116, 0.117, 0.126, 0.152, 0.129, 0.108, 0.097),
    (1.280, -0.014, 0.121, 0.123, 0.131, 0.160, 0.136, 0.113, 0.101),
    (1.320, -0.016, 0.120, 0.123, 0.133, 0.165, 0.140, 0.116, 0.103),
    (1.380, -0.018, 0.111, 0.117, 0.129, 0.170, 0.140, 0.115, 0.104),
    (1.440, -0.020, 0.086, 0.096, 0.116, 0.166, 0.128, 0.103, 0.098),
    (1.470, -0.022, 0.066, 0.078, 0.104, 0.150, 0.116, 0.094, 0.090),
    (1.490, -0.024, 0.058, 0.066, 0.090, 0.126, 0.100, 0.084, 0.080),
    (1.505, -0.025, 0.055, 0.058, 0.070, 0.092, 0.080, 0.070, 0.068),
    (1.518, -0.025, 0.053, 0.054, 0.058, 0.064, 0.064, 0.064, 0.064),
]
TORSO_RINGS = [0.855, 0.88, 0.905, 0.93, 0.955, 0.98, 1.005, 1.03, 1.055, 1.08, 1.11, 1.14, 1.17,
               1.20, 1.23, 1.26, 1.29, 1.32, 1.35, 1.38, 1.41, 1.44, 1.47, 1.49, 1.505, 1.518]
HOLE_RING0 = TORSO_RINGS.index(1.32)
HOLE_RING1 = TORSO_RINGS.index(1.47)
HOLE_COL0 = 9      # right side columns 9..13; left side mirrored 23..27
HOLE_COL1 = 13

HEAD_H = 0.23        # chin -> crown, before the 1.03 enlargement
HEAD_AXIS_Y = 0.008  # world y of the head's vertical axis
HEAD_ROWS = [
    # zh,    cy,     r0,    r30,   r60,   r90,   r120,  r150,  r180
    (-0.12, -0.025, 0.052, 0.053, 0.056, 0.059, 0.060, 0.062, 0.063),
    (-0.06, -0.022, 0.058, 0.058, 0.058, 0.059, 0.061, 0.063, 0.065),
    (-0.025, -0.016, 0.070, 0.066, 0.060, 0.060, 0.062, 0.066, 0.069),
    (0.005, -0.008, 0.087, 0.075, 0.063, 0.061, 0.063, 0.069, 0.073),
    (0.050, -0.004, 0.096, 0.083, 0.067, 0.062, 0.064, 0.072, 0.078),
    (0.120, 0.000, 0.093, 0.087, 0.073, 0.066, 0.066, 0.075, 0.083),
    (0.200, 0.000, 0.094, 0.090, 0.078, 0.069, 0.068, 0.080, 0.090),
    (0.290, 0.000, 0.093, 0.091, 0.081, 0.072, 0.072, 0.086, 0.097),
    (0.390, 0.000, 0.090, 0.091, 0.084, 0.076, 0.077, 0.092, 0.102),
    (0.470, 0.000, 0.086, 0.089, 0.085, 0.078, 0.080, 0.095, 0.105),
    (0.550, 0.000, 0.090, 0.090, 0.085, 0.079, 0.081, 0.097, 0.106),
    (0.650, 0.000, 0.091, 0.089, 0.084, 0.080, 0.082, 0.097, 0.105),
    (0.760, 0.000, 0.085, 0.082, 0.079, 0.077, 0.079, 0.091, 0.098),
    (0.860, 0.000, 0.067, 0.065, 0.064, 0.064, 0.066, 0.074, 0.078),
    (0.940, 0.000, 0.041, 0.041, 0.041, 0.042, 0.044, 0.047, 0.049),
    (1.000, 0.000, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004),
]
HEAD_RINGS = [-0.07, -0.03, 0.0, 0.03, 0.06, 0.09, 0.12, 0.15, 0.17, 0.193, 0.215, 0.24,
              0.265, 0.285, 0.305, 0.33, 0.36, 0.39, 0.42, 0.45, 0.48, 0.51, 0.54, 0.57, 0.61,
              0.66, 0.72, 0.78, 0.84, 0.89, 0.935, 0.97]

# Face features: (phi centre (mirrored if > 0), zh centre, amplitude m, sigma phi rad, sigma zh)
FACE_BUMPS = [
    ("ala", 0.20, 0.292, 0.007, 0.07, 0.028),
    ("socket", 0.43, 0.47, -0.010, 0.17, 0.055),
    ("brow", 0.38, 0.555, 0.004, 0.25, 0.03),
    ("cheek", 0.80, 0.40, 0.006, 0.22, 0.05),
    ("upper_lip", 0.0, 0.215, 0.006, 0.30, 0.022),
    ("lower_lip", 0.0, 0.168, 0.006, 0.26, 0.02),
    ("mouth", 0.0, 0.193, -0.005, 0.32, 0.008),
    ("mouth_corner", 0.33, 0.193, -0.003, 0.06, 0.015),
    ("chin", 0.0, 0.06, 0.004, 0.35, 0.04),
    ("adams_apple", 0.0, -0.07, 0.006, 0.18, 0.04),
    ("temple", 1.10, 0.60, -0.004, 0.30, 0.07),
]
NOSE_PROFILE = ([0.255, 0.27, 0.285, 0.305, 0.34, 0.40, 0.47, 0.53],
                [0.0, 0.008, 0.020, 0.025, 0.021, 0.013, 0.006, 0.0])
NOSE_WIDTH = ([0.25, 0.30, 0.40, 0.53], [0.15, 0.15, 0.10, 0.09])

ARM_PROFILE = (  # s from the shoulder joint, half-size along d (back of hand) and l (thumb side)
    [0.0, 0.06, 0.10, 0.14, 0.18, 0.24, 0.29, 0.32, 0.38, 0.45, 0.52, 0.545],
    [(0.062, 0.056), (0.058, 0.054), (0.052, 0.050), (0.046, 0.047), (0.042, 0.046), (0.038, 0.043),
     (0.036, 0.040), (0.039, 0.043), (0.036, 0.041), (0.030, 0.036), (0.022, 0.031), (0.019, 0.029)],
)
ARM_RINGS = [0.06, 0.10, 0.14, 0.18, 0.22, 0.255, 0.275, 0.29, 0.305, 0.325, 0.355, 0.39, 0.43,
             0.47, 0.505, 0.53]
PALM_RINGS = [0.0, 0.016, 0.034, 0.052, 0.07, 0.084, 0.094]   # from the wrist (x HAND scale)
PALM_PROFILE = ([0.0, 0.03, 0.06, 0.094], [(0.0175, 0.031), (0.017, 0.037), (0.016, 0.041), (0.013, 0.043)])

LEG_PROFILE = (  # s from the hip joint: front, lateral, back, medial radius, lateral centre shift
    [0.14, 0.21, 0.28, 0.35, 0.39, 0.42, 0.45, 0.50, 0.55, 0.60, 0.66, 0.72, 0.77],
    [(0.082, 0.086, 0.088, 0.068, 0.010), (0.078, 0.080, 0.080, 0.064, 0.008),
     (0.072, 0.072, 0.073, 0.060, 0.006), (0.062, 0.061, 0.062, 0.055, 0.003),
     (0.056, 0.055, 0.054, 0.052, 0.0), (0.055, 0.050, 0.050, 0.050, 0.0),
     (0.049, 0.048, 0.052, 0.049, 0.0), (0.046, 0.050, 0.062, 0.052, 0.0),
     (0.044, 0.050, 0.062, 0.051, 0.0), (0.042, 0.046, 0.055, 0.046, 0.0),
     (0.038, 0.040, 0.046, 0.040, 0.0), (0.034, 0.035, 0.038, 0.034, 0.0),
     (0.031, 0.032, 0.033, 0.031, 0.0)],
)
LEG_RINGS = [0.14, 0.18, 0.22, 0.26, 0.30, 0.34, 0.375, 0.40, 0.42, 0.44, 0.465, 0.50, 0.55, 0.60,
             0.65, 0.70, 0.74, 0.77]

FOOT_RINGS = [  # y from the ankle, half width, top height
    (-0.072, 0.022, 0.050), (-0.064, 0.031, 0.062), (-0.050, 0.035, 0.072), (-0.035, 0.037, 0.080),
    (-0.015, 0.038, 0.084), (0.005, 0.039, 0.085), (0.025, 0.040, 0.082), (0.045, 0.041, 0.077),
    (0.065, 0.043, 0.070), (0.085, 0.045, 0.062), (0.105, 0.047, 0.055), (0.125, 0.048, 0.049),
    (0.145, 0.048, 0.044), (0.165, 0.046, 0.040), (0.185, 0.041, 0.036), (0.200, 0.034, 0.032),
    (0.210, 0.024, 0.027),
]
FOOT_HOLE_R0 = 3   # ring index of y=-0.035
FOOT_HOLE_R1 = 8   # y=0.065
FINGER_SIZE = {"index": (0.0098, 0.0088), "middle": (0.0100, 0.0090), "ring": (0.0093, 0.0084),
               "pinky": (0.0080, 0.0073)}


# ------------------------------------------------------------------------------------------
# parameters
# ------------------------------------------------------------------------------------------
@dataclass
class BodyParams:
    scale: float = 1.0
    gender: float = 0.0
    build: float = 0.0
    age: float = 0.0


@dataclass
class Mesh:
    """Vertex + face soup with per-vertex part info and skin weights."""

    v: list = field(default_factory=list)
    part: list = field(default_factory=list)
    side: list = field(default_factory=list)
    s: list = field(default_factory=list)       # position along the part (m, unscaled)
    ang: list = field(default_factory=list)     # angle around the part axis / column angle
    w: list = field(default_factory=list)       # {bone: weight}
    f: list = field(default_factory=list)
    fpart: list = field(default_factory=list)

    def add(self, p, part: str, side: int, s: float, ang: float, w: dict) -> int:
        self.v.append(np.asarray(p, dtype=np.float64))
        self.part.append(part)
        self.side.append(side)
        self.s.append(float(s))
        self.ang.append(float(ang))
        self.w.append(dict(w))
        return len(self.v) - 1

    def face(self, idx, part: str) -> None:
        self.f.append(tuple(int(i) for i in idx))
        self.fpart.append(part)

    def ring_band(self, a: list[int], b: list[int], part: str) -> None:
        """Quads between two equal-length closed rings."""
        n = len(a)
        for j in range(n):
            k = (j + 1) % n
            self.face((a[j], a[k], b[k], b[j]), part)

    def fan(self, ring: list[int], pole: int, part: str) -> None:
        n = len(ring)
        for j in range(n):
            self.face((ring[j], ring[(j + 1) % n], pole), part)

    def positions(self) -> np.ndarray:
        return np.array(self.v)


def _blend(a: dict, b: dict, t: float) -> dict:
    out: dict[str, float] = {}
    for k, x in a.items():
        out[k] = out.get(k, 0.0) + x * (1.0 - t)
    for k, x in b.items():
        out[k] = out.get(k, 0.0) + x * t
    return {k: x for k, x in out.items() if x > 1e-4}


def _chain_weight(bones: list[str], bounds: list[float], s: float, width: float) -> dict:
    """Weights along a bone chain: ``bounds[i]`` is the joint between bones i and i+1."""
    w = {bones[0]: 1.0}
    for i, b in enumerate(bounds):
        t = smoothstep(b - width, b + width, s)
        if t <= 0.0:
            break
        w = _blend(w, {bones[i + 1]: 1.0}, t)
    return w


# ------------------------------------------------------------------------------------------
# generator
# ------------------------------------------------------------------------------------------
class BodyGen:
    def __init__(self, params: BodyParams) -> None:
        self.p = params
        self.k = params.scale
        self.J = {n: (np.array(h), np.array(t)) for n, (h, t, _r) in rig.joints(params.scale).items()}
        self.m = Mesh()
        self.hh = rig.HEAD_HAND_SCALE
        g, b = params.gender, params.build
        self.bulk = 1.0 + 0.07 * b + 0.02 * params.age          # overall flesh multiplier
        self.limb = 1.0 + 0.06 * b - 0.06 * g
        self.head_h = HEAD_H * self.hh * self.k * (1.0 - 0.03 * g)
        self.z_chin = 1.78 * self.k - self.head_h
        self.torso_grid: list[list[int]] = []
        self.info: dict = {}

    # -- weights -----------------------------------------------------------------------------
    def torso_weight(self, p: np.ndarray, is_head: bool) -> dict:
        k = self.k
        z = p[2] / k
        w = _chain_weight(["hips", "spine", "chest", "neck", "head"], [1.05, 1.21, 1.49, 1.535], z, 0.04)
        if is_head and z > 1.545:
            w = {"head": 1.0}
        ax = abs(p[0]) / k
        side = "R" if p[0] > 0 else "L"
        if z < 0.97:
            t = smoothstep(0.97, 0.86, z) * smoothstep(0.015, 0.07, ax) * 0.55
            w = _blend(w, {f"thigh.{side}": 1.0}, t)
        if z > 1.30 and ax > 0.05:
            # shoulder girdle: clavicle near the top, upper arm right at the hole
            tc = smoothstep(0.05, 0.15, ax) * smoothstep(1.30, 1.42, z) * 0.6
            w = _blend(w, {f"clavicle.{side}": 1.0}, tc)
        return w

    # -- torso / head tube -------------------------------------------------------------------
    def torso_ring_points(self, z_rel: float) -> tuple[np.ndarray, float]:
        """Return (radii at 7 control angles, centre y) for a torso ring at z (unscaled metres)."""
        rows = np.array([r[1:] for r in TORSO_ROWS])
        zs = [r[0] for r in TORSO_ROWS]
        row = hermite(zs, rows, z_rel)
        cy, radii = row[0], row[1:].copy()
        g, b, a = self.p.gender, self.p.build, self.p.age
        # gender: narrower shoulders/waist, wider hips
        shoulder = smoothstep(1.25, 1.40, z_rel) * (1.0 - smoothstep(1.47, 1.50, z_rel))
        hipz = math.exp(-((z_rel - 0.95) / 0.07) ** 2)
        waist = math.exp(-((z_rel - 1.12) / 0.06) ** 2)
        side_mul = 1.0 - 0.07 * g * shoulder + 0.07 * g * hipz - 0.08 * g * waist + 0.04 * b * (waist + hipz)
        radii[2:5] *= side_mul
        radii[4:] *= 1.0 + 0.06 * g * hipz
        radii *= self.bulk
        radii[0:2] *= 1.0 + (0.10 * b + 0.04 * a) * math.exp(-((z_rel - 1.10) / 0.07) ** 2)  # belly
        return radii, cy

    def torso_bumps(self, phi: float, z_rel: float) -> float:
        g = self.p.gender
        out = 0.0
        for sgn in (-1.0, 1.0):
            d = wrap(phi - sgn * 0.42)
            # pecs (male) / bust (female)
            amp = 0.007 * (1 - g) + 0.032 * g
            zc = 1.30 - 0.04 * g
            sz = 0.045 + 0.01 * g
            out += amp * math.exp(-(d / 0.30) ** 2 - ((z_rel - zc) / sz) ** 2)
            # shoulder blades
            d2 = wrap(phi - sgn * 2.55)
            out += 0.006 * math.exp(-(d2 / 0.25) ** 2 - ((z_rel - 1.33) / 0.06) ** 2)
            # glutes
            d3 = wrap(phi - sgn * 2.55)
            out += (0.010 + 0.008 * g) * math.exp(-(d3 / 0.35) ** 2 - ((z_rel - 0.93) / 0.05) ** 2)
        # spine groove
        out -= 0.004 * math.exp(-(wrap(phi - math.pi) / 0.12) ** 2) * smoothstep(0.98, 1.10, z_rel)
        return out

    def head_radius(self, phi: float, zh: float) -> tuple[float, float]:
        """(radius from the head axis, centre y offset) at angle phi and normalised height zh,
        before scaling (multiply by ``self.head_scale``)."""
        rows = np.array([r[1:] for r in HEAD_ROWS])
        zs = [r[0] for r in HEAD_ROWS]
        row = hermite(zs, rows, zh)
        cy, radii = row[0], row[1:].copy()
        g = self.p.gender
        jaw = math.exp(-((zh - 0.12) / 0.12) ** 2)
        radii[1:4] *= 1.0 - 0.06 * g * jaw
        neck = 1.0 - smoothstep(-0.05, 0.02, zh)
        radii *= 1.0 - 0.10 * g * neck
        r = periodic_profile(radii, phi)
        # nose
        nz = float(np.interp(zh, *NOSE_PROFILE))
        nw = float(np.interp(zh, *NOSE_WIDTH))
        r += nz * (1.0 - 0.12 * g) * math.exp(-(wrap(phi) / nw) ** 2)
        for name, pc, zc, amp, sp, sz in FACE_BUMPS:
            if name == "adams_apple":
                amp *= (1.0 - g)
            if name in ("upper_lip", "lower_lip"):
                amp *= 1.0 + 0.4 * g
            if name == "brow":
                amp *= 1.0 - 0.6 * g
            for sgn in ((-1.0, 1.0) if pc > 0 else (1.0,)):
                d = wrap(phi - sgn * pc)
                r += amp * math.exp(-(d / sp) ** 2 - ((zh - zc) / sz) ** 2)
        return r, cy

    @property
    def head_scale(self) -> float:
        return self.hh * self.k * (1.0 - 0.03 * self.p.gender)

    def head_point(self, phi: float, zh: float, offset: float = 0.0) -> np.ndarray:
        r, cy = self.head_radius(phi, zh)
        hs = self.head_scale
        rr = r * hs + offset
        return v3(rr * math.sin(phi), HEAD_AXIS_Y * self.k + cy * hs + rr * math.cos(phi),
                  self.z_chin + zh * self.head_h)

    def torso_point(self, phi: float, z_rel: float, offset: float = 0.0) -> np.ndarray:
        """Point on the (unsmoothed) torso surface at angle phi and height z_rel, pushed out
        horizontally by ``offset`` metres."""
        k = self.k
        radii, cy = self.torso_ring_points(z_rel)
        r = periodic_profile(radii, phi) + self.torso_bumps(phi, z_rel) * self.bulk
        rr = r * k + offset
        return v3(rr * math.sin(phi), cy * k + rr * math.cos(phi), z_rel * k)

    def arm_axis(self, side: int, s_: float) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        """(centre, tangent, e_back_of_hand, e_thumb) of the arm at distance s_ from the shoulder."""
        sfx = "R" if side > 0 else "L"
        J, k = self.J, self.k
        sh, el = J[f"upper_arm.{sfx}"][0], J[f"forearm.{sfx}"][0]
        wr = J[f"hand.{sfx}"][0]
        fr = rig.arm_frame(float(side))
        s = s_ * k
        l_up = np.linalg.norm(el - sh)
        if s <= l_up:
            c, t = sh + unit(el - sh) * s, unit(el - sh)
        else:
            c, t = el + unit(wr - el) * (s - l_up), unit(wr - el)
        d = np.array(fr["d"])
        e1 = unit(d - t * (d @ t))
        e2 = np.cross(t, e1)
        if e2 @ np.array(fr["l"]) < 0:
            e2 = -e2
        return c, t, e1, e2

    def arm_radius(self, s_: float) -> tuple[float, float]:
        prof_s, prof = ARM_PROFILE
        rd, rl = hermite(prof_s, np.array(prof), s_) * self.limb * self.bulk * self.k
        return float(rd), float(rl)

    def build_torso_head(self) -> None:
        m, k = self.m, self.k
        grid: list[list[int]] = []
        for z_rel in TORSO_RINGS:
            radii, cy = self.torso_ring_points(z_rel)
            ring = []
            for j in range(C):
                phi = column_angle(j)
                r = periodic_profile(radii, phi) + self.torso_bumps(phi, z_rel) * self.bulk
                p = v3(r * math.sin(phi) * k, (cy + r * math.cos(phi)) * k, z_rel * k)
                ring.append(m.add(p, "torso", 0, z_rel, phi, self.torso_weight(p, False)))
            grid.append(ring)
        # blend from the torso's top ring into the head table
        for zh in HEAD_RINGS:
            ring = []
            for j in range(C):
                phi = column_angle(j)
                p = self.head_point(phi, zh)
                ring.append(m.add(p, "head", 0, zh, phi, self.torso_weight(p, True)))
            grid.append(ring)
        pole = m.add(self.head_point(0.0, 1.0) * np.array([0.0, 1.0, 1.0]), "head", 0, 1.0, 0.0, {"head": 1.0})
        n_torso = len(TORSO_RINGS)
        for i in range(len(grid) - 1):
            part = "torso" if i < n_torso - 1 else "head"
            for j in range(C):
                jn = (j + 1) % C
                if HOLE_RING0 <= i < HOLE_RING1 and (HOLE_COL0 <= j < HOLE_COL1 or C - HOLE_COL1 <= j < C - HOLE_COL0):
                    continue
                m.face((grid[i][j], grid[i][jn], grid[i + 1][jn], grid[i + 1][j]), part)
        m.fan(grid[-1], pole, "head")
        self.torso_grid = grid

    def hole_loop(self, side: int) -> list[int]:
        """Boundary of the arm hole, cyclic."""
        g = self.torso_grid
        if side > 0:
            c0, c1 = HOLE_COL0, HOLE_COL1
        else:
            c0, c1 = C - HOLE_COL1, C - HOLE_COL0
        r0, r1 = HOLE_RING0, HOLE_RING1
        loop = [g[r1][j] for j in range(c0, c1 + 1)]
        loop += [g[i][c1] for i in range(r1 - 1, r0 - 1, -1)]
        loop += [g[r0][j] for j in range(c1 - 1, c0 - 1, -1)]
        loop += [g[i][c0] for i in range(r0 + 1, r1)]
        return loop

    # -- generic loft from an existing loop ---------------------------------------------------
    def _align_loop(self, loop: list[int], centre: np.ndarray, e1: np.ndarray, e2: np.ndarray,
                    target: list[float]) -> tuple[list[int], list[float]]:
        """Reorder ``loop`` so vertex j sits nearest ``target[j]`` (angles decreasing or
        increasing like ``target``). Returns the reordered loop and its unwrapped angles."""
        pts = [self.m.v[i] - centre for i in loop]
        ang = [math.atan2(float(p @ e2), float(p @ e1)) for p in pts]
        n = len(loop)
        tdir = 1.0 if wrap(target[1] - target[0]) > 0 else -1.0
        # loop direction: mean signed step
        steps = sum(wrap(ang[(i + 1) % n] - ang[i]) for i in range(n))
        if steps * tdir < 0:
            loop = loop[::-1]
            ang = ang[::-1]
        start = min(range(n), key=lambda i: abs(wrap(ang[i] - target[0])))
        loop = loop[start:] + loop[:start]
        ang = ang[start:] + ang[:start]
        out = [target[0] + wrap(ang[0] - target[0])]
        for i in range(1, n):
            out.append(out[-1] + wrap(ang[i] - ang[i - 1]))
        return loop, out

    # -- arms + hands ------------------------------------------------------------------------
    def build_arm(self, side: int) -> None:
        m, J, k = self.m, self.J, self.k
        sfx = "R" if side > 0 else "L"
        fr = rig.arm_frame(float(side))
        d_ax = np.array(fr["d"])
        l_ax = np.array(fr["l"])
        sh = J[f"upper_arm.{sfx}"][0]
        el = J[f"forearm.{sfx}"][0]
        wr = J[f"hand.{sfx}"][0]
        hand_dir = unit(J[f"hand.{sfx}"][1] - wr)
        up_dir = unit(el - sh)
        fo_dir = unit(wr - el)
        l_up, l_fo = np.linalg.norm(el - sh), np.linalg.norm(wr - el)

        def frame(t: np.ndarray):
            e1 = d_ax - t * (d_ax @ t)
            e1 = unit(e1)
            e2 = np.cross(t, e1)
            if e2 @ l_ax < 0:
                e2 = -e2
            return e1, e2

        def arm_point(s_: float):
            """centre, tangent at arm distance s_ (unscaled) from the shoulder."""
            s = s_ * k
            if s <= l_up:
                c = sh + up_dir * s
            else:
                c = el + fo_dir * min(s - l_up, l_fo)
            tb = smoothstep(l_up - 0.03 * k, l_up + 0.03 * k, s)
            t = unit(up_dir * (1 - tb) + fo_dir * tb)
            return c, t

        uni = [math.radians(80.0 - 20.0 * j) for j in range(ARM_N)]
        loop = self.hole_loop(side)
        c1, t1 = arm_point(ARM_RINGS[0])
        e1, e2 = frame(t1)
        loop, loop_ang = self._align_loop(loop, c1, e1, e2, uni)
        for i in loop:
            m.w[i] = _blend(m.w[i], {f"upper_arm.{sfx}": 1.0, f"clavicle.{sfx}": 0.4}, 0.55)
        prev = loop
        lim = self.limb * self.bulk
        prof_s, prof = ARM_PROFILE
        prof = np.array(prof)
        for ri, s_ in enumerate(ARM_RINGS):
            c, t = arm_point(s_)
            e1, e2 = frame(t)
            rd, rl = hermite(prof_s, prof, s_) * lim
            mix = 0.5 if ri == 0 else 1.0
            ring = []
            for j in range(ARM_N):
                phi = loop_ang[j] * (1 - mix) + uni[j] * mix
                # biceps forward bulge on the upper arm
                bump = 0.0
                if s_ < 0.27:
                    bump = 0.004 * math.exp(-(wrap(phi - math.pi / 2) / 0.6) ** 2) * smoothstep(0.08, 0.16, s_)
                rr_d, rr_l = rd + bump, rl + bump
                p = c + (e1 * rr_d * math.cos(phi) + e2 * rr_l * math.sin(phi)) * k
                w = _chain_weight([f"upper_arm.{sfx}", f"forearm.{sfx}", f"hand.{sfx}"],
                                  [0.29, 0.548], s_, 0.03)
                if s_ < 0.12:
                    w = _blend(w, {f"clavicle.{sfx}": 1.0}, 0.25 * (1 - smoothstep(0.06, 0.12, s_)))
                ring.append(m.add(p, "arm", side, s_, phi, w))
            m.ring_band(prev, ring, "arm")
            prev = ring
        # palm: blend from the forearm ellipse to the hand's rounded rectangle
        hs = self.hh * k * (1.0 - 0.05 * self.p.gender)
        hp_s, hp = PALM_PROFILE
        hp = np.array(hp)
        e1h, e2h = frame(hand_dir)
        palm_rings: list[list[int]] = []
        for ri, hsd in enumerate(PALM_RINGS):
            c = wr + hand_dir * hsd * hs
            tb = smoothstep(-0.01, 0.03, hsd)
            t = unit(fo_dir * (1 - tb) + hand_dir * tb)
            e1, e2 = frame(t)
            th, wd = hermite(hp_s, hp, hsd)
            th *= (1.0 + 0.05 * self.p.build)
            ring = []
            for j in range(ARM_N):
                q = self._palm_rect(j, th, wd)
                ell_phi = uni[j]
                rect_phi = math.atan2(q[1], q[0])
                ell = np.array([math.cos(ell_phi) * th * 1.15, math.sin(ell_phi) * wd * 0.95])
                mixr = smoothstep(0.0, 0.035, hsd)
                del rect_phi
                qq = ell * (1 - mixr) + q * mixr
                p = c + (e1 * qq[0] + e2 * qq[1]) * hs
                ring.append(m.add(p, "hand", side, 0.55 + hsd, 0.0, {f"hand.{sfx}": 1.0}))
            palm_rings.append(ring)
        # forearm -> palm
        m.ring_band(prev, palm_rings[0], "arm")
        th_col = 16   # thumb hole between columns 16 and 17 (palmar, index side)
        for i in range(len(palm_rings) - 1):
            a, b = palm_rings[i], palm_rings[i + 1]
            for j in range(ARM_N):
                if 1 <= i <= 2 and j == th_col:
                    continue
                jn = (j + 1) % ARM_N
                m.face((a[j], a[jn], b[jn], b[j]), "hand")
        thumb_loop = [palm_rings[1][th_col], palm_rings[1][th_col + 1], palm_rings[2][th_col + 1],
                      palm_rings[3][th_col + 1], palm_rings[3][th_col], palm_rings[2][th_col]]
        self.build_thumb(side, thumb_loop, hs)
        end = palm_rings[-1]
        top = end[0:9]
        bot = [end[17 - mm] for mm in range(9)]  # b_m at the same lateral position as t_m
        for fi, fname in enumerate(("index", "middle", "ring", "pinky")):
            base = [top[2 * fi], top[2 * fi + 1], top[2 * fi + 2], bot[2 * fi + 2], bot[2 * fi + 1], bot[2 * fi]]
            for vi in base:
                m.w[vi] = _blend(m.w[vi], {f"{fname}_01.{sfx}": 1.0}, 0.35)
            self.build_finger(side, fname, base, hs)

    @staticmethod
    def _palm_rect(j: int, th: float, wd: float) -> np.ndarray:
        """Rounded-rectangle palm section: (along d, along l) for ring vertex j (18 per ring)."""
        if j <= 8:
            lat = wd * (1.0 - 2.0 * j / 8.0)
            u = lat / wd
            dd = th * (1.0 - 0.28 * u * u)
            if j in (0, 8):
                lat *= 0.93
                dd *= 0.55
        else:
            mm = 17 - j
            lat = wd * (1.0 - 2.0 * mm / 8.0)
            u = lat / wd
            dd = -th * (1.0 - 0.18 * u * u)
            if mm in (0, 8):
                lat *= 0.93
                dd *= 0.55
        return np.array([dd, lat])

    def _tube_along(self, side: int, part: str, base: list[int], pts: list[np.ndarray],
                    radii: list[tuple[float, float]], weights: list[dict], s_vals: list[float],
                    d_ref: np.ndarray, l_ref: np.ndarray, n: int, start_deg: float, tip: np.ndarray,
                    tip_w: dict) -> None:
        """Loft rings of ``n`` verts through ``pts`` from loop ``base``, close with a pole at ``tip``."""
        m = self.m
        uni = [math.radians(start_deg - 360.0 * j / n) for j in range(n)]
        prev = base
        for ri, c in enumerate(pts):
            if ri + 1 < len(pts):
                t = unit(pts[ri + 1] - c)
            else:
                t = unit(tip - c)
            if ri > 0:
                t = unit(t + unit(c - pts[ri - 1]))
            e1 = unit(d_ref - t * (d_ref @ t))
            e2 = np.cross(t, e1)
            if e2 @ l_ref < 0:
                e2 = -e2
            if ri == 0:
                prev, ang = self._align_loop(prev, c, e1, e2, uni)
            mix = 0.6 if ri == 0 else 1.0
            ring = []
            for j in range(n):
                phi = ang[j] * (1 - mix) + uni[j] * mix
                rd, rl = radii[ri]
                p = c + e1 * rd * math.cos(phi) + e2 * rl * math.sin(phi)
                ring.append(m.add(p, part, side, s_vals[ri], phi, weights[ri]))
            m.ring_band(prev, ring, part)
            prev = ring
        pole = m.add(tip, part, side, s_vals[-1] + 0.01, 0.0, tip_w)
        m.fan(prev, pole, part)

    def build_finger(self, side: int, fname: str, base: list[int], hs: float) -> None:
        sfx = "R" if side > 0 else "L"
        J = self.J
        fr = rig.arm_frame(float(side))
        heads = [J[f"{fname}_0{i}.{sfx}"][0] for i in (1, 2, 3)]
        tip = J[f"{fname}_03.{sfx}"][1]
        segs = [(heads[0], heads[1]), (heads[1], heads[2]), (heads[2], tip)]
        w0, h0 = FINGER_SIZE[fname]
        plan = [(0, 0.35), (0, 0.75), (1, -0.004), (1, 0.004), (1, 0.5), (2, -0.003), (2, 0.003),
                (2, 0.5), (2, 0.8), (2, 0.95)]
        pts, radii, weights, svals = [], [], [], []
        bones = [f"{fname}_01.{sfx}", f"{fname}_02.{sfx}", f"{fname}_03.{sfx}"]
        total = 0.0
        for si, frac in plan:
            if frac < 0:
                a, b = segs[si]
                p = a + unit(segs[si - 1][1] - segs[si - 1][0]) * frac * hs
                bw = {bones[si - 1]: 0.5, bones[si]: 0.5}
                tt = si - 0.1
            elif frac < 0.01:
                a, b = segs[si]
                p = a + unit(b - a) * frac * hs
                bw = {bones[si - 1]: 0.5, bones[si]: 0.5}
                tt = si + 0.1
            else:
                a, b = segs[si]
                p = a + (b - a) * frac
                bw = {bones[si]: 1.0}
                tt = si + frac
            taper = (1.0 - 0.18 * (tt / 3.0)) * (0.72 if frac > 0.9 else 1.0) * 1.06
            knuckle = 1.06 if abs(frac) < 0.01 else 1.0
            radii.append((h0 * taper * knuckle * hs / self.k, w0 * taper * knuckle * hs / self.k))
            pts.append(p)
            weights.append(bw)
            total = tt
            svals.append(total)
        radii = [(r[0] * self.k, r[1] * self.k) for r in radii]
        d3 = unit(segs[2][1] - segs[2][0])
        tip_p = tip + d3 * 0.001 * hs
        self._tube_along(side, "finger", base, pts, radii, weights, svals, np.array(fr["d"]),
                         np.array(fr["l"]), FINGER_N, 60.0, tip_p, {bones[2]: 1.0})

    def build_thumb(self, side: int, loop: list[int], hs: float) -> None:
        sfx = "R" if side > 0 else "L"
        J = self.J
        fr = rig.arm_frame(float(side))
        heads = [J[f"thumb_0{i}.{sfx}"][0] for i in (1, 2, 3)]
        tip = J[f"thumb_03.{sfx}"][1]
        segs = [(heads[0], heads[1]), (heads[1], heads[2]), (heads[2], tip)]
        bones = [f"thumb_01.{sfx}", f"thumb_02.{sfx}", f"thumb_03.{sfx}"]
        plan = [(0, 0.55), (0, 0.85), (1, 0.0), (1, 0.5), (2, 0.0), (2, 0.5), (2, 0.85)]
        sizes = [(0.0125, 0.0135), (0.0112, 0.0118), (0.0105, 0.0110), (0.0100, 0.0104),
                 (0.0094, 0.0098), (0.0088, 0.0092), (0.0076, 0.0080)]
        pts, radii, weights, svals = [], [], [], []
        for (si, frac), (rd, rl) in zip(plan, sizes):
            a, b = segs[si]
            pts.append(a + (b - a) * frac)
            radii.append((rd * hs, rl * hs))
            if frac == 0.0:
                weights.append({bones[si - 1]: 0.5, bones[si]: 0.5})
            else:
                weights.append({bones[si]: 1.0})
            svals.append(si + frac)
        for vi in loop:
            self.m.w[vi] = {f"hand.{sfx}": 0.6, bones[0]: 0.4}
        d_ref = np.array(fr["p"])
        tdir = unit(segs[0][1] - segs[0][0])
        l_ref = np.cross(tdir, d_ref) * side
        tip_p = tip + unit(segs[2][1] - segs[2][0]) * 0.002 * hs
        self._tube_along(side, "thumb", loop, pts, radii, weights, svals, d_ref, l_ref, THUMB_N, 60.0,
                         tip_p, {bones[2]: 1.0})

    # -- legs + feet ---------------------------------------------------------------------------
    def build_legs(self) -> None:
        m, k = self.m, self.k
        g0 = self.torso_grid[0]
        front, back = self.m.v[g0[0]], self.m.v[g0[C // 2]]
        crotch = []
        for fi, f in enumerate((0.25, 0.5, 0.75)):
            p = front * (1 - f) + back * f
            p = p.copy()
            p[0] = 0.0
            p[2] -= (0.030 + 0.012 * math.sin(math.pi * f)) * k
            crotch.append(m.add(p, "torso", 0, 0.83, 0.0, {"hips": 0.5, "thigh.L": 0.25, "thigh.R": 0.25}))
        # composite rings, both ordered front -> outside -> back -> crotch(back->front)
        right = [g0[j] for j in range(0, C // 2 + 1)] + crotch[::-1]
        left = [g0[(C - j) % C] for j in range(0, C // 2 + 1)] + crotch[::-1]
        # crotch faces: triangles closing nothing; the two leg tubes share the seam
        self.build_leg(1, right)
        self.build_leg(-1, left)

    def build_leg(self, side: int, comp: list[int]) -> None:
        m, J, k = self.m, self.J, self.k
        sfx = "R" if side > 0 else "L"
        hip, knee = J[f"thigh.{sfx}"]
        ankle = J[f"shin.{sfx}"][1]
        th_dir, sh_dir = unit(knee - hip), unit(ankle - knee)
        l_th, l_sh = np.linalg.norm(knee - hip), np.linalg.norm(ankle - knee)
        fwd = v3(0, 1, 0)
        lat = v3(side, 0, 0)

        def leg_point(s_: float):
            s = s_ * k
            c = hip + th_dir * s if s <= l_th else knee + sh_dir * (s - l_th)
            tb = smoothstep(l_th - 0.04 * k, l_th + 0.04 * k, s)
            t = unit(th_dir * (1 - tb) + sh_dir * tb)
            return c, t

        def frame(t):
            ef = unit(fwd - t * (fwd @ t))
            el = np.cross(t, ef)
            if el @ lat < 0:
                el = -el
            return ef, el

        uni_start = None
        c1, t1 = leg_point(LEG_RINGS[0])
        ef, el = frame(t1)
        # angle measured from front towards lateral
        pts = [m.v[i] - c1 for i in comp]
        ang = [math.atan2(float(p @ el), float(p @ ef)) for p in pts]
        n = len(comp)
        unwrapped = [ang[0]]
        for i in range(1, n):
            unwrapped.append(unwrapped[-1] + wrap(ang[i] - ang[i - 1]))
        direction = 1.0 if unwrapped[-1] > unwrapped[0] else -1.0
        uni_start = ang[0]
        uni = [uni_start + direction * TAU * j / n for j in range(n)]
        prof_s, prof = LEG_PROFILE
        prof = np.array(prof)
        prev = comp
        lim = self.limb * self.bulk
        g = self.p.gender
        for ri, s_ in enumerate(LEG_RINGS):
            c, t = leg_point(s_)
            ef, el = frame(t)
            rf, rl, rb, rm, shift = hermite(prof_s, prof, s_)
            thigh = 1.0 - smoothstep(0.30, 0.42, s_)
            mul = lim * (1.0 + 0.05 * g * thigh)
            mix = [0.45, 0.8][ri] if ri < 2 else 1.0
            ring = []
            for j in range(n):
                phi = unwrapped[j] * (1 - mix) + uni[j] * mix
                cph, sph = math.cos(phi), math.sin(phi)
                r = (rf if cph > 0 else rb) * cph * cph + (rl if sph > 0 else rm) * sph * sph
                p = c + (ef * cph + el * sph) * r * mul * k + el * shift * k
                w = _chain_weight([f"thigh.{sfx}", f"shin.{sfx}"], [0.42], s_, 0.04)
                if s_ < 0.24:
                    w = _blend(w, {"hips": 1.0}, 0.3 * (1 - smoothstep(0.14, 0.24, s_)))
                ring.append(m.add(p, "leg", side, s_, phi, w))
            m.ring_band(prev, ring, "leg")
            prev = ring
        hole = self.build_foot(side)
        # match the foot hole to the last leg ring, then bridge with two blended rings
        ring_c = np.mean([m.v[i] for i in prev], axis=0)
        best = None
        for direction in (1, -1):
            for off in range(n):
                cand = [hole[(off + direction * j) % n] for j in range(n)]
                cost = sum(float(np.linalg.norm(m.v[a] - m.v[b])) for a, b in zip(prev, cand))
                if best is None or cost < best[0] - 1e-12:
                    best = (cost, cand)
        hole_o = best[1]
        hole_c = np.mean([m.v[i] for i in hole_o], axis=0)
        for ti, (t, sv) in enumerate(((0.38, 0.80), (0.72, 0.83))):
            ring = []
            for a, b in zip(prev, hole_o):
                pa, pb = m.v[a], m.v[b]
                p = pa * (1 - t) + pb * t
                cc = ring_c * (1 - t) + hole_c * t
                radial = p - cc
                radial[2] = 0.0
                p = p + radial * 0.10 * math.sin(math.pi * t)
                w = {f"shin.{sfx}": 1.0 - 0.5 * t, f"foot.{sfx}": 0.5 * t}
                ring.append(m.add(p, "ankle", side, sv, 0.0, w))
            m.ring_band(prev, ring, "ankle")
            prev = ring
        for i in hole_o:
            m.w[i] = {f"shin.{sfx}": 0.35, f"foot.{sfx}": 0.65}
        m.ring_band(prev, hole_o, "ankle")

    def build_foot(self, side: int) -> list[int]:
        m, J, k = self.m, self.J, self.k
        sfx = "R" if side > 0 else "L"
        ankle = J[f"shin.{sfx}"][1]
        ball_y = J[f"toe.{sfx}"][0][1]
        cx = ankle[0] + side * 0.004 * k
        rings: list[list[int]] = []
        wmul = 1.0 + 0.04 * self.p.build - 0.06 * self.p.gender
        for (dy, hw, ht) in FOOT_RINGS:
            y = ankle[1] + dy * k
            ring = []
            for j in range(FOOT_N):
                psi = TAU * j / FOOT_N            # 0 = top, increasing towards +X
                sn, cs = math.sin(psi), math.cos(psi)
                n_exp = 3.0 if cs >= 0 else 6.0
                x = hw * wmul * math.copysign(abs(sn) ** (2.0 / n_exp), sn)
                zz = ht / 2 + ht / 2 * math.copysign(abs(cs) ** (2.0 / n_exp), cs)
                if cs < 0:
                    zz = max(0.0, zz)
                p = v3(cx + x * k * 1.08, y, zz * k * 1.12)
                tw = smoothstep(ball_y - 0.02 * k, ball_y + 0.02 * k, y)
                w = _blend({f"foot.{sfx}": 1.0}, {f"toe.{sfx}": 1.0}, tw)
                ring.append(m.add(p, "foot", side, dy, psi, w))
            rings.append(ring)
        hole_cols = set(range(FOOT_N - 3, FOOT_N)) | {0, 1, 2}
        for i in range(len(rings) - 1):
            for j in range(FOOT_N):
                if FOOT_HOLE_R0 <= i < FOOT_HOLE_R1 and j in hole_cols:
                    continue
                jn = (j + 1) % FOOT_N
                m.face((rings[i][j], rings[i][jn], rings[i + 1][jn], rings[i + 1][j]), "foot")
        heel = m.add(v3(cx, ankle[1] + (FOOT_RINGS[0][0] - 0.006) * k, 0.030 * k), "foot", side, -0.08, 0,
                     {f"foot.{sfx}": 1.0})
        toe = m.add(v3(cx, ankle[1] + (FOOT_RINGS[-1][0] + 0.005) * k, 0.014 * k), "foot", side, 0.215, 0,
                    {f"toe.{sfx}": 1.0})
        m.fan(rings[0], heel, "foot")
        m.fan(rings[-1], toe, "foot")
        r0, r1 = FOOT_HOLE_R0, FOOT_HOLE_R1
        c0, c1 = FOOT_N - 3, 3     # wraps through column 0
        cols = [(c0 + i) % FOOT_N for i in range(7)]
        loop = [rings[r1][c] for c in cols]
        loop += [rings[i][cols[-1]] for i in range(r1 - 1, r0 - 1, -1)]
        loop += [rings[r0][c] for c in cols[-2::-1]]
        loop += [rings[i][cols[0]] for i in range(r0 + 1, r1)]
        del c1
        return loop

    # -- eyes and ears -------------------------------------------------------------------------
    def build_eyes_ears(self) -> None:
        m = self.m
        hs = self.head_scale
        for sgn in (-1.0, 1.0):
            phi, zh = 0.43 * sgn, 0.47
            r, cy = self.head_radius(phi, zh)
            er = 0.0118 * hs
            centre_r = (r - 0.0118 + 0.005) * hs
            c = v3(centre_r * math.sin(phi), HEAD_AXIS_Y * self.k + cy * hs + centre_r * math.cos(phi),
                   self.z_chin + zh * self.head_h)
            look = unit(v3(sgn * 0.06, 1.0, 0.0))
            self._sphere(c, er, er, er, look, 12, 8, "eye", {"head": 1.0})
            # ear: flattened ellipsoid sticking out behind the cheek
            ephi, ezh = sgn * math.radians(97.0), 0.425
            r2, cy2 = self.head_radius(ephi, ezh)
            rr = (r2 - 0.004) * hs
            ec = v3(rr * math.sin(ephi), HEAD_AXIS_Y * self.k + cy2 * hs + rr * math.cos(ephi) - 0.004 * hs,
                    self.z_chin + ezh * self.head_h)
            out = unit(v3(sgn * 1.0, -0.35, 0.0))
            self._ear(ec, out, sgn, hs)

    def _sphere(self, c, rx, ry, rz, fwd, nu, nv, part, w) -> None:
        m = self.m
        fwd = unit(fwd)
        side = unit(np.cross(fwd, v3(0, 0, 1)))
        up = np.cross(side, fwd)
        rings = []
        for i in range(1, nv):
            th = math.pi * i / nv
            ring = []
            for j in range(nu):
                ph = TAU * j / nu
                p = c + fwd * (math.cos(th) * ry) + (side * math.cos(ph) * rx + up * math.sin(ph) * rz) * math.sin(th)
                ring.append(m.add(p, part, 0, math.cos(th), ph, w))
            rings.append(ring)
        front = m.add(c + fwd * ry, part, 0, 1.0, 0, w)
        back = m.add(c - fwd * ry, part, 0, -1.0, 0, w)
        m.fan(rings[0], front, part)
        for a, b in zip(rings[:-1], rings[1:]):
            m.ring_band(a, b, part)
        m.fan(rings[-1][::-1], back, part)

    def _ear(self, c, out, sgn, hs) -> None:
        """Ear: a curled, flattened shell (8 x 5 grid ellipsoid squashed on its outward axis)."""
        m = self.m
        up = v3(0, -0.18, 1.0)
        up = unit(up - out * (up @ out))
        fw = np.cross(up, out)
        h, wdt, th = 0.031 * hs, 0.019 * hs, 0.009 * hs
        rings = []
        nv, nu = 6, 10
        for i in range(1, nv):
            t = math.pi * i / nv
            ring = []
            for j in range(nu):
                ph = TAU * j / nu
                # local coords: a = along fw (front/back), b = up, n = out
                a = math.sin(t) * math.cos(ph) * wdt
                b = math.cos(t) * h
                n = math.sin(t) * math.sin(ph) * th
                # curl the back rim outward and cup the front
                n += 0.35 * th * (a / wdt + 1.0) * math.sin(t)
                p = c + fw * a + up * b + out * (n + th * 0.6)
                ring.append(m.add(p, "ear", 0, 0.0, 0.0, {"head": 1.0}))
            rings.append(ring)
        top = m.add(c + up * h + out * th * 0.6, "ear", 0, 0, 0, {"head": 1.0})
        bot = m.add(c - up * h + out * th * 0.6, "ear", 0, 0, 0, {"head": 1.0})
        m.fan(rings[0], top, "ear")
        for a_, b_ in zip(rings[:-1], rings[1:]):
            m.ring_band(a_, b_, "ear")
        m.fan(rings[-1][::-1], bot, "ear")

    # -- finish --------------------------------------------------------------------------------
    def build(self) -> Mesh:
        self.build_torso_head()
        self.build_arm(1)
        self.build_arm(-1)
        self.build_legs()
        self.build_eyes_ears()
        smooth_junctions(self.m)
        orient_faces(self.m)
        normalise_weights(self.m)
        return self.m


# ------------------------------------------------------------------------------------------
# mesh utilities
# ------------------------------------------------------------------------------------------
def edge_faces(faces: list[tuple]) -> dict:
    ef: dict[tuple[int, int], list[int]] = {}
    for fi, f in enumerate(faces):
        n = len(f)
        for i in range(n):
            a, b = f[i], f[(i + 1) % n]
            ef.setdefault((min(a, b), max(a, b)), []).append(fi)
    return ef


def orient_faces(m: Mesh) -> None:
    """Make winding consistent per connected component (BFS), outward by signed volume."""
    faces = [list(f) for f in m.f]
    ef = edge_faces(m.f)
    nf = len(faces)
    seen = [False] * nf
    pos = m.positions()
    for seed in range(nf):
        if seen[seed]:
            continue
        comp = [seed]
        seen[seed] = True
        queue = [seed]
        while queue:
            fi = queue.pop()
            f = faces[fi]
            n = len(f)
            for i in range(n):
                a, b = f[i], f[(i + 1) % n]
                for gj in ef[(min(a, b), max(a, b))]:
                    if gj == fi or seen[gj]:
                        continue
                    g = faces[gj]
                    # neighbour must traverse b->a
                    ng = len(g)
                    same = any(g[q] == a and g[(q + 1) % ng] == b for q in range(ng))
                    if same:
                        faces[gj] = g[::-1]
                    seen[gj] = True
                    comp.append(gj)
                    queue.append(gj)
        vol = 0.0
        for fi in comp:
            f = faces[fi]
            p0 = pos[f[0]]
            for q in range(1, len(f) - 1):
                vol += float(np.dot(p0, np.cross(pos[f[q]], pos[f[q + 1]])))
        if vol < 0:
            for fi in comp:
                faces[fi] = faces[fi][::-1]
    m.f = [tuple(f) for f in faces]


def vertex_normals(pos: np.ndarray, faces: list[tuple]) -> np.ndarray:
    nrm = np.zeros_like(pos)
    for f in faces:
        p0 = pos[f[0]]
        for q in range(1, len(f) - 1):
            c = np.cross(pos[f[q]] - p0, pos[f[q + 1]] - p0)
            for i in (f[0], f[q], f[q + 1]):
                nrm[i] += c
    ln = np.linalg.norm(nrm, axis=1)
    ln[ln == 0] = 1.0
    return nrm / ln[:, None]


def smooth_junctions(m: Mesh, iterations: int = 8) -> None:
    """Taubin-smooth the vertices around the crotch, shoulders, ankles and finger bases."""
    pos = m.positions()
    n = len(pos)
    nbr: list[set[int]] = [set() for _ in range(n)]
    for f in m.f:
        k = len(f)
        for i in range(k):
            a, b = f[i], f[(i + 1) % k]
            nbr[a].add(b)
            nbr[b].add(a)
    sel = []
    wts = []
    for i in range(n):
        part, s = m.part[i], m.s[i]
        w = 0.0
        if part == "torso" and s < 0.9:
            w = 0.5
        elif part == "leg" and s < 0.20:
            w = 0.6
        elif part == "arm" and s < 0.15:
            w = 0.7
        elif part == "torso" and 1.28 <= s <= 1.50 and abs(pos[i][0]) > 0.10 * 1.0:
            w = 0.7
        elif part == "ankle":
            w = 0.6
        if w > 0 and nbr[i]:
            sel.append(i)
            wts.append(w)
    nb_list = [sorted(nbr[i]) for i in sel]
    for _ in range(iterations):
        for lam in (0.5, -0.53):
            new = pos.copy()
            for i, w, nb in zip(sel, wts, nb_list):
                avg = pos[nb].mean(axis=0)
                new[i] = pos[i] + lam * w * (avg - pos[i])
            pos = new
    for i in sel:
        m.v[i] = pos[i]


def normalise_weights(m: Mesh, max_influences: int = 4) -> None:
    for i, w in enumerate(m.w):
        items = sorted(w.items(), key=lambda kv: (-kv[1], kv[0]))[:max_influences]
        tot = sum(x for _k, x in items)
        m.w[i] = {k: x / tot for k, x in items}


def generate(params: BodyParams) -> tuple[Mesh, BodyGen]:
    gen = BodyGen(params)
    return gen.build(), gen


def check(m: Mesh) -> dict:
    """Topology stats: non-manifold / boundary edge counts, components, triangles."""
    ef = edge_faces(m.f)
    boundary = sum(1 for v in ef.values() if len(v) == 1)
    nonman = sum(1 for v in ef.values() if len(v) > 2)
    tris = sum(len(f) - 2 for f in m.f)
    return {"verts": len(m.v), "faces": len(m.f), "tris": tris, "boundary_edges": boundary,
            "nonmanifold_edges": nonman}
