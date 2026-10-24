#!/usr/bin/env python3
"""Write the achievement mask pattern textures (D-ACH). No Blender needed.

    python3 tools/blender/masks/make_mask_patterns.py [--only guilloche,vault_bolts,acanthus]

Each pattern is ``game/assets/masks/patterns/tex_mask_pattern_<name>.png`` (1024 x 1024, grey:
R = G = B; the mask shader reads the RED channel: 0 = colour A, 1 = colour B) plus ``.import`` and
``SOURCE.txt``. The texture maps ONCE over mask UV0 (content/docs/masks.md, mask_surface.gdshader):
x 0..1 = the viewer's left..right, y 0..1 = forehead..chin, front-planar; it does not tile.

The motifs are drawn in physical mask units: a typical base spans about 0.17 m (x) by 0.235 m (y),
so x and y are scaled to ``W`` x ``H`` metres before drawing and circles stay round on the face.
Shapes are signed-distance fields rendered with a one-texel anti-aliased edge, supersampled 2x and
box-filtered down, so every edge is smooth. Lines are at least ~10 texels (~1.6 mm) wide.
Original designs, procedural only; deterministic (no randomness at all). Pillow + numpy; PNGs go
through ENV C's texgen writer (read-only) for byte-stable output.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / "tools"))

from texgen import godot  # noqa: E402
from texgen import io as tio  # noqa: E402

OUT_DIR = REPO / "game" / "assets" / "masks" / "patterns"
SIZE = 1024
SS = 2                      # supersampling factor
W, H = 0.17, 0.235          # physical extent of mask UV0 (m), typical base
#: lossless (the mask edges must stay crisp and the 0/1 levels exact), mipmapped (filter_linear_mipmap)
IMPORT_PARAMS = {"compress/mode": "0", "mipmaps/generate": "true", "process/fix_alpha_border": "true"}


def grid(n: int) -> tuple[np.ndarray, np.ndarray, float]:
    """Physical coordinates (m) of an n x n texel grid: x from the UV centre, y down from the top
    (y = 0 at UV y 0). Returns (x, y, texel size in m along x)."""
    t = (np.arange(n) + 0.5) / n
    u, v = np.meshgrid(t, t, indexing="xy")
    return (u - 0.5) * W, v * H, W / n


def cover(sd: np.ndarray, px: float) -> np.ndarray:
    """Coverage of a signed distance (m, < 0 inside) with a one-texel anti-aliased edge."""
    return np.clip(0.5 - sd / px, 0.0, 1.0)


def line(d: np.ndarray, width: float, px: float) -> np.ndarray:
    """Coverage of a stroke of ``width`` (m) around distance field ``d`` (m, >= 0)."""
    return cover(np.abs(d) - 0.5 * width, px)


def curve_dist(r: np.ndarray, rc: np.ndarray, drc: np.ndarray) -> np.ndarray:
    """Approximate distance from polar points (r) to the polar curve r = rc(theta) with slope drc."""
    return np.abs(r - rc) / np.sqrt(1.0 + (drc / np.maximum(r, 1e-4)) ** 2)


# ------------------------------------------------------------------------------------------------
# guilloche: banknote rosette centred on the nose bridge plus a lathe-work band
# ------------------------------------------------------------------------------------------------
def guilloche(n: int) -> np.ndarray:
    x, y, px = grid(n)
    cx, cy = 0.0, 0.42 * H
    dx, dy = x, y - cy
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    lw = 1.9e-3                                   # stroke width (m): ~11 texels at 1024
    m = np.zeros_like(r)
    # central rosette: two families of 12-lobed sinusoidal rings in opposite phase interlace into
    # the classic lattice; rings get wider apart outwards
    for k, base in enumerate((0.012, 0.019, 0.027, 0.036)):
        amp = 0.0045 + 0.0012 * k
        for ph in (0.0, np.pi):
            rc = base + amp * np.sin(12 * th + ph)
            drc = 12 * amp * np.cos(12 * th + ph)
            m = np.maximum(m, line(curve_dist(r, rc, drc), lw, px))
    m = np.maximum(m, cover(r - 0.0055, px))                                # hub dot
    # lathe-work band: two high-frequency sinusoids crossing between two border rings
    r_in, r_out = 0.050, 0.068
    mid, amp = 0.5 * (r_in + r_out), 0.5 * (r_out - r_in) - 0.0012
    for ph in (0.0, np.pi):
        rc = mid + amp * np.sin(36 * th + ph)
        drc = 36 * amp * np.cos(36 * th + ph)
        m = np.maximum(m, line(curve_dist(r, rc, drc), lw, px))
    for rr in (r_in - 0.0018, r_out + 0.0018):
        m = np.maximum(m, line(r - rr, lw * 1.2, px))
    # epicycloid crown outside the band: a looping trochoid ring (a lathe pattern of loops)
    rc = 0.083 + 0.006 * np.cos(24 * th)
    drc = -24 * 0.006 * np.sin(24 * th)
    m = np.maximum(m, line(curve_dist(r, rc, drc), lw, px))
    rc2 = 0.083 + 0.006 * np.cos(24 * th + np.pi)
    m = np.maximum(m, line(curve_dist(r, rc2, -drc), lw, px))
    # background: fine waves (banknote ground) beyond the crown, fading in
    ground = np.abs(np.mod(y + 0.0016 * np.sin(x / 0.006), 0.0085) - 0.00425)
    m = np.maximum(m, line(ground, lw * 0.9, px) * (r > 0.095))
    return m


# ------------------------------------------------------------------------------------------------
# vault door: radial bolt bars round the face edge, a rivet circle, a central hub disk with spokes
# ------------------------------------------------------------------------------------------------
def vault_bolts(n: int) -> np.ndarray:
    x, y, px = grid(n)
    cy = 0.45 * H
    ax, ay = 0.5 * W, 0.55 * H                     # door ellipse half axes (reaches the face edge)
    dx, dy = x, y - cy
    th = np.arctan2(dy / ay, dx / ax)
    e = np.hypot(dx / ax, dy / ay)                  # elliptic radius: 1 = the door edge
    s = 0.5 * (ax + ay)                             # metres per unit of e (for AA widths)
    m = np.zeros_like(e)
    # vault frame round the face edge, a dark gap, the door's edge ring and a thin inner ring
    m = np.maximum(m, cover((0.965 - e) * s, px))
    m = np.maximum(m, line((e - 0.86) * s, 3.0e-3, px))
    m = np.maximum(m, line((e - 0.68) * s, 2.2e-3, px))
    # locking bolts: 14 radial bars thrown from inside the door across the gap into the frame
    nb = 14
    seg = 2 * np.pi / nb
    a = np.mod(th + 0.5 * seg, seg) - 0.5 * seg      # angle to the nearest bar axis
    bx = e * s * np.cos(a)                          # along the bar (m)
    by = e * s * np.sin(a)                          # across the bar (m)
    half_w = 0.0068
    r0, r1 = 0.74 * s, 1.0 * s
    qx = np.clip(bx, r0, r1)
    bar = np.hypot(bx - qx, by) - half_w            # capsule
    m = np.maximum(m, cover(bar, px))
    # rivet circle: 32 rivets between the hub and the inner rim
    nr = 28
    seg_r = 2 * np.pi / nr
    ar = np.mod(th + 0.5 * seg_r, seg_r) - 0.5 * seg_r
    rx, ry = e * s * np.cos(ar) - 0.58 * s, e * s * np.sin(ar)
    m = np.maximum(m, cover(np.hypot(rx, ry) - 0.0036, px))
    # central hub disk with a ring groove, and a three-spoke handle wheel round it
    rh = np.hypot(dx, dy)
    hub = cover(rh - 0.019, px) * (1.0 - line(rh - 0.0125, 2.2e-3, px))
    m = np.maximum(m, hub)
    m = np.maximum(m, line(rh - 0.033, 3.2e-3, px))
    tha = np.arctan2(dy, dx)
    seg_s = 2 * np.pi / 3
    sa = np.mod(tha + np.pi / 2 + 0.5 * seg_s, seg_s) - 0.5 * seg_s
    sx, sy = rh * np.cos(sa), rh * np.sin(sa)
    spoke = np.where((sx > 0.017) & (sx < 0.046), np.abs(sy) - 0.0028, 1.0)
    m = np.maximum(m, cover(spoke, px))
    knob = np.hypot(sx - 0.047, sy) - 0.0052
    m = np.maximum(m, cover(knob, px))
    return m


# ------------------------------------------------------------------------------------------------
# acanthus: gilded picture-frame scroll border round the face perimeter, plain centre field
# ------------------------------------------------------------------------------------------------
def _leaf(lx: np.ndarray, ly: np.ndarray, length: float, width: float, ang: float, px: float) -> np.ndarray:
    """Coverage of a lobed acanthus leaf rooted at the origin, pointing along ``ang`` (rad)."""
    c, s = np.cos(ang), np.sin(ang)
    a = lx * c + ly * s                              # along the leaf
    b = -lx * s + ly * c                             # across
    t = np.clip(a / length, 0.0, 1.0)
    half = width * np.sin(np.pi * np.power(t, 0.7)) * (0.78 + 0.22 * np.abs(np.cos(3.5 * np.pi * t)))
    half = half * (1.0 + 0.25 * t)                   # curling tip is fuller
    inside = np.maximum(np.abs(b) - half, np.maximum(-a, a - length))
    vein = line(b + 0.25 * width * np.sin(np.pi * t), 0.9e-3, px) * (t > 0.08) * (t < 0.85)
    return cover(inside, px) * (1.0 - vein)


def acanthus(n: int) -> np.ndarray:
    x, y, px = grid(n)
    cy = 0.46 * H
    hx = 0.5 * W
    dx, dy = x, y - cy
    hy = np.where(dy < 0.0, cy, H - cy)
    # face-shaped outline: a superellipse that narrows towards the chin like the mask bases do
    taper = 1.0 - 0.30 * np.clip(dy / (H - cy), 0.0, 1.0) ** 1.5
    p = 2.4
    rho = np.power(np.abs(dx / (hx * taper)) ** p + np.abs(dy / hy) ** p, 1.0 / p)
    band_w = 0.15 * W                                 # border width (m)
    inner = 1.0 - band_w / hx                         # rho at the inner band edge (along x)
    th = np.arctan2(dy / hy, dx / (hx * taper))
    reps = 10
    # band coordinates: t 0 (inner edge) .. 1 (face edge), s along the perimeter (repeat units)
    t = (rho - inner) / (1.0 - inner)
    srep = np.mod(th / (2 * np.pi) * reps, 1.0)
    per_len = 0.62 / reps                             # perimeter ~0.62 m: one repeat ~5.2 cm
    lx = srep * per_len                               # metres along the repeat
    ly = t * band_w                                   # metres across the band
    m = np.zeros_like(rho)
    # frame mouldings: outer fillet (face edge) and an inner bead-and-reel line
    m = np.maximum(m, cover((0.94 - t) * band_w, px))
    m = np.maximum(m, line(ly - 0.08 * band_w, 2.4e-3, px) * (t > -0.5))
    bead_p = per_len / 8.0
    bead = np.hypot(np.mod(lx, bead_p) - 0.5 * bead_p, ly + 0.12 * band_w) - 0.0022
    m = np.maximum(m, cover(bead, px) * (t < 0.2))
    # running scroll: a sinuous stem, a volute in every bight, acanthus leaves on the stem
    yc = 0.52 * band_w + 0.22 * band_w * np.sin(2 * np.pi * srep)
    dyc = 0.22 * band_w * 2 * np.pi / per_len * np.cos(2 * np.pi * srep)
    stem = np.abs(ly - yc) / np.sqrt(1.0 + dyc * dyc)
    m = np.maximum(m, line(stem, 3.0e-3, px) * (t > 0.12) * (t < 0.92))
    for sx0, sy0, sign in ((0.25, 0.38, 1.0), (0.75, 0.66, -1.0)):
        vx, vy = lx - sx0 * per_len, ly - sy0 * band_w
        rr = np.hypot(vx, vy)
        ph = np.mod(sign * np.arctan2(vy, vx), 2 * np.pi)
        r_big = 0.30 * band_w
        dmin = np.full_like(rr, 1.0)
        for k in range(2):                            # spiral r = R * (1 - phi / (2 pi * 2.2))
            phi = ph + 2 * np.pi * k
            rs = r_big * (1.0 - phi / (2 * np.pi * 2.2))
            dmin = np.where(rs > 0.001, np.minimum(dmin, np.abs(rr - rs)), dmin)
        m = np.maximum(m, line(dmin, 2.6e-3, px) * (rr < r_big * 1.05))
        m = np.maximum(m, cover(rr - 0.0022, px))      # volute eye (rosette)
    for lx0, sgn in ((0.0, 1.0), (0.5, -1.0), (1.0, 1.0)):
        ox, oy = lx - lx0 * per_len, ly - 0.52 * band_w
        for side in (1.0, -1.0):
            ang = (0.55 if side > 0 else np.pi - 0.55) * sgn
            m = np.maximum(m, _leaf(ox, oy, 0.52 * band_w, 0.20 * band_w, ang, px) * (t > 0.08) * (t < 0.98))
    m = np.where(rho >= 1.0, 1.0, m)                  # beyond the face edge: the frame moulding
    m = np.where(t < -0.15, 0.0, m)                   # centre field = colour A
    return np.clip(m, 0.0, 1.0)


# ------------------------------------------------------------------------------------------------
# polygon motifs (facets, dial hands, stencil glyphs): rasterised with Pillow at 2x the working
# resolution and box-filtered down (with render()'s 2x: 4x4 samples per texel)
# ------------------------------------------------------------------------------------------------
class Canvas:
    """Pillow drawing in physical mask units (x m from the UV centre line, y m down from the top)."""

    def __init__(self, n: int, k: int = 2) -> None:
        from PIL import Image, ImageDraw

        self.n, self.k = n, k
        self.img = Image.new("L", (n * k, n * k), 0)
        self.draw = ImageDraw.Draw(self.img)

    def _p(self, x: float, y: float) -> tuple[float, float]:
        return ((x / W + 0.5) * self.n * self.k, y / H * self.n * self.k)

    def poly(self, pts, value: int = 255) -> None:
        self.draw.polygon([self._p(x, y) for x, y in pts], fill=value)

    def rect(self, x0: float, y0: float, x1: float, y1: float, value: int = 255) -> None:
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], value)

    def seg(self, a, b, width: float, value: int = 255) -> None:
        """A straight stroke of ``width`` m from a to b (as a quad, square ends)."""
        (ax, ay), (bx, by) = a, b
        dx, dy = bx - ax, by - ay
        ln = max(np.hypot(dx, dy), 1e-9)
        ox, oy = -dy / ln * 0.5 * width, dx / ln * 0.5 * width
        self.poly([(ax + ox, ay + oy), (bx + ox, by + oy), (bx - ox, by - oy), (ax - ox, ay - oy)], value)

    def array(self) -> np.ndarray:
        a = np.asarray(self.img, dtype=np.float64) / 255.0
        n, k = self.n, self.k
        return a.reshape(n, k, n, k).mean(axis=(1, 3))


def facets(n: int) -> np.ndarray:
    """Brilliant-cut crown seen from above, centred on the nose bridge: octagonal table, 8 star facets,
    8 kite (bezel) facets, 16 upper-girdle halves, the girdle ring; facets alternate A / B and every
    facet edge is a B line, so the cut reads at a distance."""
    cx, cy = 0.0, 0.42 * H
    rg = 0.104                                     # girdle radius: the crown spans the whole face
    rt, rs = 0.50 * rg, 0.76 * rg                  # table corner radius, star tip radius

    def pt(r: float, deg: float) -> tuple[float, float]:
        a = np.deg2rad(deg - 90.0)
        return (cx + r * np.cos(a), cy + r * np.sin(a))

    cv = Canvas(n)
    cv.poly([pt(rg * 1.6, 22.5 * i) for i in range(16)], 0)
    table = [pt(rt, 45 * i + 22.5) for i in range(8)]
    edges = []
    for i in range(8):
        t0, t1 = table[i - 1], table[i]               # table edge centred on angle 45 i
        star = pt(rs, 45 * i)
        cv.poly([t0, t1, star], 255)                  # star facet: B
        kite = [table[i], pt(rs, 45 * i), pt(rg, 45 * i + 22.5), pt(rs, 45 * (i + 1))]
        cv.poly(kite, 0)                              # kite: A
        # upper girdle halves either side of the star tip, alternating
        g0, g1, g2 = pt(rg, 45 * i - 22.5), pt(rg, 45 * i), pt(rg, 45 * i + 22.5)
        cv.poly([star, g0, g1], 255 if i % 2 == 0 else 0)
        cv.poly([star, g1, g2], 0 if i % 2 == 0 else 255)
        edges += [(t0, t1), (t0, star), (t1, star), (star, g0), (star, g1), (star, g2),
                  (table[i], pt(rs, 45 * i)), (pt(rs, 45 * i), g2)]
    for a, b in edges:
        cv.seg(a, b, 1.8e-3)
    m = cv.array()
    x, y, px = grid(n)
    r = np.hypot(x - cx, y - cy)
    m = np.maximum(m, line(r - rg, 2.6e-3, px))                       # girdle
    m = np.where(r > rg + 1.3e-3, 0.0, m)                                # outside the girdle: A
    return np.clip(m, 0.0, 1.0)


def time_lock_dial(n: int) -> np.ndarray:
    """Time-lock movement dial round the face centre: a knurled bezel, a solid chapter ring with
    hour windows cut into it, 60 minute ticks, bold hour batons (double at 12), two tapered hands
    (ten past ten) and a centre boss."""
    cx, cy = 0.0, 0.47 * H
    x, y, px = grid(n)
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    a = np.arctan2(dx, -dy)                         # clockwise from 12 o'clock
    m = np.zeros_like(r)
    # knurled outer bezel (sawtooth edge) out to the face edge
    knurl = 0.090 + 0.0022 * np.abs(np.mod(a / (2 * np.pi) * 90, 1.0) - 0.5)
    m = np.maximum(m, cover(knurl - r, px))
    m = np.where(r > 0.084, m, 0.0)
    # chapter ring band with 12 hour windows (A) cut into it
    ring = cover(np.abs(r - 0.0735) - 0.0065, px)
    seg_h = 2 * np.pi / 12
    ah = np.mod(a + 0.5 * seg_h, seg_h) - 0.5 * seg_h
    win = cover(np.maximum(np.abs(r * np.sin(ah)) - 0.0028, np.abs(r - 0.0735) - 0.0035), px)
    m = np.maximum(m, ring * (1.0 - win))
    # minute ticks inside the ring
    seg_m = 2 * np.pi / 60
    am = np.mod(a + 0.5 * seg_m, seg_m) - 0.5 * seg_m
    tick = cover(np.maximum(np.abs(r * np.sin(am)) - 0.0008, np.abs(r - 0.0625) - 0.0025), px)
    m = np.maximum(m, tick)
    # hour batons
    bat = cover(np.maximum(np.abs(r * np.sin(ah)) - 0.0024, np.abs(r - 0.0555) - 0.0055), px)
    m = np.maximum(m, bat)
    cv = Canvas(n)
    for deg in (-1.6, 1.6):                          # doubled baton at 12
        ang = np.deg2rad(deg)
        cv.seg((cx + 0.050 * np.sin(ang), cy - 0.050 * np.cos(ang)),
               (cx + 0.061 * np.sin(ang), cy - 0.061 * np.cos(ang)), 3.2e-3)

    def hand(deg: float, length: float, w: float, tail: float) -> None:
        ang = np.deg2rad(deg)
        ux, uy = np.sin(ang), -np.cos(ang)
        vx, vy = -uy, ux
        cv.poly([(cx - ux * tail + vx * w * 0.6, cy - uy * tail + vy * w * 0.6),
                 (cx + ux * length * 0.75 + vx * w, cy + uy * length * 0.75 + vy * w),
                 (cx + ux * length, cy + uy * length),
                 (cx + ux * length * 0.75 - vx * w, cy + uy * length * 0.75 - vy * w),
                 (cx - ux * tail - vx * w * 0.6, cy - uy * tail - vy * w * 0.6)])

    hand(305.0, 0.040, 0.0042, 0.010)              # hour hand at ten
    hand(60.0, 0.056, 0.0032, 0.013)               # minute hand at two
    m = np.maximum(m, cv.array())
    m = np.maximum(m, cover(r - 0.0075, px))
    m = np.minimum(m, 1.0 - cover(r - 0.0025, px))  # arbor hole (A)
    return np.clip(m, 0.0, 1.0)


#: Original blocky stencil glyphs on a 3 x 5 unit cell: filled rectangles / polygons, then the
#: stencil bridges cut back out (A). Units: x 0..3, y 0..5 (down).
_GLYPHS: dict[str, tuple[list, list]] = {
    "C": ([("r", 0, 0, 3, 1), ("r", 0, 0, 1, 5), ("r", 0, 4, 3, 5)],
          [("r", 1.0, 0, 1.3, 1), ("r", 1.0, 4, 1.3, 5)]),
    "X": ([("p", (0, 0), (1.1, 0), (3, 5), (1.9, 5)), ("p", (1.9, 0), (3, 0), (1.1, 5), (0, 5))],
          [("r", 0, 2.35, 1.5, 2.65)]),
    "4": ([("r", 0, 0, 1, 3), ("r", 0, 2, 3, 3), ("r", 2, 0, 3, 5)],
          [("r", 1.0, 2, 1.3, 3)]),
    "0": ([("r", 0, 0, 3, 1), ("r", 0, 0, 1, 5), ("r", 2, 0, 3, 5), ("r", 0, 4, 3, 5)],
          [("r", 1.35, 0, 1.65, 1), ("r", 1.35, 4, 1.65, 5)]),
    "7": ([("r", 0, 0, 3, 1), ("p", (2, 1), (3, 1), (1.7, 5), (0.7, 5))],
          [("r", 1.85, 0, 2.15, 1)]),
    "3": ([("r", 0, 0, 3, 1), ("r", 0.6, 2, 3, 3), ("r", 0, 4, 3, 5), ("r", 2, 0, 3, 5)],
          [("r", 1.75, 0, 2.05, 1), ("r", 1.75, 2, 2.05, 3), ("r", 1.75, 4, 2.05, 5)]),
    "1": ([("r", 1, 0, 2, 4.0), ("p", (0.1, 0.5), (1, 0), (1, 1.2), (0.1, 1.5)), ("r", 0, 4.3, 3, 5)],
          []),
}
STENCIL_TEXT = "CX40 7731"                         # original, no real owner code or company mark


def stencil(n: int) -> np.ndarray:
    """Shipping-container stencil: a painted brow panel (B) with the blocky stencil code knocked out
    (A) between two thin rules, and a hazard-stripe chin band."""
    cv = Canvas(n)
    unit = 0.118 / 33.0                            # glyph unit (m): the code spans ~12 cm of brow
    y0 = 0.205 * H                                  # brow panel (ends just above the brow line)
    y1 = y0 + 5.0 * unit + 0.010
    cv.rect(-W, y0, W, y1)
    cv.rect(-W, y0 - 0.0062, W, y0 - 0.0040)        # rules above / below the panel
    cv.rect(-W, y1 + 0.0040, W, y1 + 0.0062)
    adv, space = 4.0 * unit, 2.0 * unit
    width = sum(space if ch == " " else adv for ch in STENCIL_TEXT) - unit
    gx, gy = -0.5 * width, y0 + 0.005

    def shape(item, ox: float, value: int) -> None:
        if item[0] == "r":
            _k, a0, b0, a1, b1 = item
            cv.rect(ox + a0 * unit, gy + b0 * unit, ox + a1 * unit, gy + b1 * unit, value)
        else:
            cv.poly([(ox + px_ * unit, gy + py_ * unit) for px_, py_ in item[1:]], value)

    for ch in STENCIL_TEXT:
        if ch == " ":
            gx += space
            continue
        fills, cuts = _GLYPHS[ch]
        for it in fills:
            shape(it, gx, 0)                        # knocked out of the panel: A
        for it in cuts:
            shape(it, gx, 255)                      # stencil bridges: panel colour B
        gx += adv
    # hazard chin band: 45 degree stripes between two rules
    c0, c1 = 0.80 * H, 1.02 * H
    cv.rect(-W, c0 - 0.0062, W, c0 - 0.0040)
    period = 0.022
    k = -12
    while k * period < W + (c1 - c0) + period:
        xa = -W + k * period
        cv.poly([(xa, c1), (xa + 0.5 * period, c1), (xa + 0.5 * period + (c1 - c0), c0), (xa + (c1 - c0), c0)])
        k += 1
    return cv.array()


def road_lines(n: int) -> np.ndarray:
    """Road markings (RT-D2, Rolling Thunder): solid edge lines down both sides, a dashed centre line
    down the nose, a straight-ahead arrow on the brow, a wide stop line across the mouth and a
    45 degree hatched box below it on the chin."""
    x, y, px = grid(n)
    m = np.zeros_like(x)
    ex = 0.068                                       # edge lines (m from the centre line)
    m = np.maximum(m, line(np.abs(x) - ex, 6.0e-3, px))
    # dashed centre line, from under the arrow to the stop line: 16 mm dashes, 11 mm gaps
    y0, y1 = 0.30 * H, 0.70 * H
    period, dash = 0.027, 0.016
    t = np.mod(y - y0, period)
    dist_y = np.abs(t - 0.5 * dash) - 0.5 * dash
    inside = (y > y0) & (y < y1)
    m = np.maximum(m, np.where(inside, cover(np.maximum(np.abs(x) - 4.5e-3, dist_y), px), 0.0))
    # straight-ahead arrow on the brow: shaft and a triangular head pointing up (toward the forehead)
    shaft = np.maximum(np.abs(x) - 4.0e-3, np.maximum(0.13 * H - y, y - 0.26 * H))
    hy = y - 0.13 * H                                # head: apex at 0.06 H, base at 0.13 H, half width 13 mm
    head = np.maximum(hy, (np.abs(x) - 0.013 * (y - 0.06 * H) / (0.07 * H)) / 1.4)
    head = np.where(y < 0.06 * H, 1.0, head)
    m = np.maximum(m, cover(np.minimum(shaft, head), px))
    # stop line across the mouth between the edge lines
    stop = np.maximum(np.abs(y - 0.765 * H) - 0.012, np.abs(x) - ex)
    m = np.maximum(m, cover(stop, px))
    # hatched box on the chin: 45 degree stripes inside a frame
    b0, b1 = 0.83 * H, 0.99 * H
    frame = np.maximum(np.abs(y - 0.5 * (b0 + b1)) - 0.5 * (b1 - b0), np.abs(x) - ex)
    m = np.maximum(m, line(frame, 3.0e-3, px))
    hp = 0.016
    hat = np.abs(np.mod((x + y) / np.sqrt(2.0), hp) - 0.5 * hp) - 0.25 * hp
    m = np.maximum(m, np.where(frame < 0.0, cover(hat, px), 0.0))
    return m


def tread(n: int) -> np.ndarray:
    """Tyre tread band (RT-D2): a tyre's footprint run straight down the face (forehead to chin, ~10 cm
    wide): a solid centre rib, directional V blocks either side split by thin sipes, square shoulder
    blocks on a different pitch, plain A outside the band."""
    x, y, px = grid(n)
    ax = np.abs(x)
    m = np.zeros_like(x)
    bw = 0.050                                       # band half width (m)
    k = 0.65                                         # V slope (m of y per m of |x|)
    norm = np.sqrt(1.0 + k * k)
    # centre rib
    m = np.maximum(m, cover(ax - 5.0e-3, px))
    # V blocks: stripes of t = y + k |x| between the rib groove and the shoulder groove
    period, blk = 0.026, 0.017
    t = np.mod(y + k * ax, period)
    vb = (np.abs(t - 0.5 * blk) - 0.5 * blk) / norm
    zone = np.maximum(9.0e-3 - ax, ax - 0.034)       # between x 9 mm and 34 mm
    vblk = np.maximum(vb, zone)
    # a sipe across each V block (thin groove along its middle)
    sipe = np.abs(np.mod(y + k * ax - 0.5 * blk, period)) / norm - 0.8e-3
    vblk = np.maximum(vblk, -sipe)
    m = np.maximum(m, cover(vblk, px))
    # shoulder blocks: square lugs on a half-step pitch
    sp, sl = 0.022, 0.015
    ts = np.mod(y + 0.5 * sp, sp)
    sh = np.maximum(np.abs(ts - 0.5 * sl) - 0.5 * sl, np.maximum(0.0375 - ax, ax - bw))
    m = np.maximum(m, cover(sh, px))
    return m


def vinyl_label(n: int) -> np.ndarray:
    """Record label for mask_base_vinyl (D-165 "Dead Air"): drawn in that base's own UV bounds (x +-0.0852 m,
    z -0.1106..0.0971 m, mask_base_vinyl/SOURCE.txt) so the disc lands on its raised centre label (r 19 mm, 30 mm
    below the eye line): a B paper label with a thin A print ring and the A spindle hole; the record is A."""
    t = (np.arange(n) + 0.5) / n
    u, v = np.meshgrid(t, t, indexing="xy")
    x, y, px = (u - 0.5) * 0.1704, v * 0.2077, 0.1704 / n
    r = np.sqrt(x * x + (y - (0.0971 + 0.030)) ** 2)
    m = cover(r - 0.0185, px)
    m = m * (1.0 - line(r - 0.0125, 0.0012, px))
    m = m * (1.0 - cover(r - 0.0030, px))
    return m


PATTERNS = {
    "guilloche": (guilloche, "banknote guilloche rosette: two 12-lobed interlaced ring families round "
                             "the nose bridge (UV 0.5, 0.42), a 36-wave lathe-work band between two rings, "
                             "a looping crown ring, fine wave ground outside"),
    "vault_bolts": (vault_bolts, "vault door: frame at the face edge, 14 locking bolts thrown across the gap into "
                                 "it, the door's edge ring and an inner ring, a circle of 28 rivets, a central "
                                 "hub disk with a groove ring and a three-spoke handle wheel"),
    "acanthus": (acanthus, "gilded picture-frame border (~15 % of the width) round a face-shaped perimeter: "
                           "outer fillet, bead line, running acanthus scroll (stem, volutes, lobed leaves); "
                           "centre field 0 = colour A"),
    "facets": (facets, "brilliant-cut crown from above centred on the nose bridge (UV 0.5, 0.42): octagonal "
                       "table, 8 star, 8 kite and 16 upper-girdle facets alternating A/B, B facet edges, "
                       "girdle ring"),
    "time_lock_dial": (time_lock_dial, "time-lock dial round the face centre: knurled bezel, chapter ring with "
                                       "hour windows, 60 minute ticks, hour batons (double at 12), hour and "
                                       "minute hands at ten past ten, centre boss"),
    "stencil": (stencil, f"container stencil: brow panel (B) with the original blocky stencil code "
                         f"'{STENCIL_TEXT}' knocked out (A, with stencil bridges) between rules; 45 degree "
                         "hazard-stripe chin band"),
    "road_lines": (road_lines, "road markings: solid edge lines down both sides, a dashed centre line down the "
                               "nose, a straight-ahead arrow on the brow, a wide stop line across the mouth, a "
                               "45 degree hatched box on the chin"),
    "tread": (tread, "tyre tread band run down the face (~10 cm wide): solid centre rib, directional V blocks "
                     "with sipes, square shoulder blocks on a half-step pitch; A outside the band"),
    "vinyl_label": (vinyl_label, "record label for mask_base_vinyl (its own UV bounds): a B paper disc (r 18.5 mm) "
                                 "on the raised centre label, a thin A print ring and the A spindle hole; A record"),
}


def render(fn) -> np.ndarray:
    big = fn(SIZE * SS)
    small = big.reshape(SIZE, SS, SIZE, SS).mean(axis=(1, 3))
    return np.clip(small, 0.0, 1.0)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="", help="comma-separated pattern names")
    args = ap.parse_args()
    only = {s for s in args.only.split(",") if s}
    for name, (fn, desc) in PATTERNS.items():
        if only and name not in only:
            continue
        m = render(fn)
        g8 = np.round(m * 255.0).astype(np.uint8)
        png = OUT_DIR / f"tex_mask_pattern_{name}.png"
        tio.write_png(png, np.stack([g8, g8, g8], axis=-1))
        godot.ensure_import(png, "texture", "CompressedTexture2D", IMPORT_PARAMS)
        share1 = float((m >= 0.5).mean())
        tio.write_text(OUT_DIR / f"SOURCE_tex_mask_pattern_{name}.txt", "\n".join([
            f"asset: tex_mask_pattern_{name}",
            f"generator: python3 tools/blender/masks/make_mask_patterns.py --only {name}",
            f"motif: {desc}",
            f"size_px: {SIZE} x {SIZE} (supersampled {SS}x, box filtered); grey PNG, RED channel = pattern mask",
            "mapping: once over mask UV0 (x 0..1 viewer's left..right, y 0..1 forehead..chin, front-planar); "
            f"drawn in physical units over {W} x {H} m",
            "values: 0 = MaskDef colour A, 1 = colour B (mask_surface.gdshader)",
            f"share_b (red >= 0.5): {share1:.3f}",
            "import: lossless, mipmaps (filter_linear_mipmap)",
            "deterministic: no randomness; PNG via tools/texgen io (ENV C, read-only)",
            "edit policy: generated, never edit by hand",
            "",
        ]))
        print(f"{name}: share_b {share1:.3f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
