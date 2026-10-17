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


PATTERNS = {
    "guilloche": (guilloche, "banknote guilloche rosette: two 12-lobed interlaced ring families round "
                             "the nose bridge (UV 0.5, 0.42), a 36-wave lathe-work band between two rings, "
                             "a looping crown ring, fine wave ground outside"),
    "vault_bolts": (vault_bolts, "vault door: rim band at the face edge, 16 radial bolt bars, inner rim ring, "
                                 "a circle of 32 rivets, a central hub disk with a groove ring and a "
                                 "three-spoke handle wheel"),
    "acanthus": (acanthus, "gilded picture-frame border (~15 % of the width) round the face perimeter: outer "
                           "fillet, bead line, running acanthus scroll (stem, volutes, lobed leaves); centre "
                           "field 0 = colour A"),
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
