"""Tiny numpy signed-distance-field modeller ("sculpt by script") for the style samples.

Shapes are combined with smooth union / smooth subtraction (polynomial smin, k in metres), the field
is sampled on a dense grid in z-slabs (each primitive is only evaluated where its padded bounding box
overlaps the slab), meshed with OpenVDB (bundled with Blender) and relaxed with Taubin smoothing.
The same field can be queried at arbitrary points (``SDF.eval``) to place details onto surfaces.

No bpy import here except inside ``to_blender_mesh``; numpy + openvdb only.
"""

from __future__ import annotations

import math

import numpy as np

F = np.float32
BIG = F(1.0)


# --------------------------------------------------------------------------- rotations

def rot_xyz(rx: float = 0.0, ry: float = 0.0, rz: float = 0.0) -> np.ndarray:
    """3x3 rotation (radians), applied X then Y then Z. Columns are the local axes in world."""
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return (mz @ my @ mx).astype(F)


def _local(p: np.ndarray, c, rot) -> np.ndarray:
    q = p - np.asarray(c, F)
    if rot is not None:
        q = q @ np.asarray(rot, F)   # row-vector form of R^T (p - c)
    return q


def _bbox(c, ext) -> tuple[np.ndarray, np.ndarray]:
    c = np.asarray(c, F)
    e = np.asarray(ext, F)
    return c - e, c + e


# --------------------------------------------------------------------------- primitives
# Each returns (fn, (lo, hi)); fn maps (..., 3) float32 points to (...) distances.

def ellipsoid(c, r, rot=None):
    r = np.asarray(r, F)

    def fn(p):
        q = _local(p, c, rot)
        k0 = np.linalg.norm(q / r, axis=-1)
        k1 = np.linalg.norm(q / (r * r), axis=-1)
        return (k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)).astype(F)
    ext = np.full(3, r.max()) if rot is not None else r
    return fn, _bbox(c, ext)


def sphere(c, r):
    def fn(p):
        return (np.linalg.norm(p - np.asarray(c, F), axis=-1) - r).astype(F)
    return fn, _bbox(c, (r, r, r))


def round_cone(a, b, r1, r2):
    """Capsule with linearly varying radius from a (r1) to b (r2). Exact enough for r1~r2."""
    a = np.asarray(a, F)
    b = np.asarray(b, F)
    ba = b - a
    L2 = float(ba @ ba)

    def fn(p):
        pa = p - a
        h = np.clip((pa @ ba) / L2, 0.0, 1.0)
        return (np.linalg.norm(pa - h[..., None] * ba, axis=-1) - (r1 + (r2 - r1) * h)).astype(F)
    rmax = max(r1, r2)
    lo = np.minimum(a, b) - rmax
    hi = np.maximum(a, b) + rmax
    return fn, (lo, hi)


def capsule(a, b, r):
    return round_cone(a, b, r, r)


def box(c, half, rad=0.0, rot=None):
    half = np.asarray(half, F)

    def fn(p):
        q = np.abs(_local(p, c, rot)) - (half - rad)
        out = np.linalg.norm(np.maximum(q, 0.0), axis=-1)
        ins = np.minimum(q.max(axis=-1), 0.0)
        return (out + ins - rad).astype(F)
    ext = np.full(3, float(np.linalg.norm(half))) if rot is not None else half
    return fn, _bbox(c, ext)


def custom(fn, lo, hi):
    return fn, (np.asarray(lo, F), np.asarray(hi, F))


def shell(prim, thickness):
    fn, bb = prim

    def f2(p):
        return (np.abs(fn(p)) - thickness).astype(F)
    return f2, (bb[0] - thickness, bb[1] + thickness)


def intersect(prim_a, prim_b, k=0.0):
    fa, ba = prim_a
    fb, bb = prim_b

    def fn(p):
        return smax(fa(p), fb(p), k)
    return fn, (np.maximum(ba[0], bb[0]), np.minimum(ba[1], bb[1]))


def subtract_prim(prim_a, prim_b, k=0.0):
    fa, ba = prim_a
    fb, _ = prim_b

    def fn(p):
        return smax(fa(p), -fb(p), k)
    return fn, ba


# --------------------------------------------------------------------------- combinators

def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return (b + (a - b) * h - k * h * (1.0 - h)).astype(F)


def smax(a, b, k):
    return -smin(-a, -b, k)


class SDF:
    """Ordered list of (mode, primitive, k). mode in {'add', 'sub'}."""

    def __init__(self) -> None:
        self.ops: list[tuple[str, object, float]] = []

    def add(self, prim, k: float = 0.0) -> "SDF":
        self.ops.append(("add", prim, k))
        return self

    def sub(self, prim, k: float = 0.0) -> "SDF":
        self.ops.append(("sub", prim, k))
        return self

    def eval(self, p: np.ndarray, lo=None, hi=None, margin: float = 0.004) -> np.ndarray:
        p = np.asarray(p, F)
        d = np.full(p.shape[:-1], BIG, F)
        kmax = max((k for _, _, k in self.ops), default=0.0)
        for mode, (fn, (blo, bhi)), k in self.ops:
            if lo is not None:
                # a culled shape can still be blended by any later op, so pad by the largest k
                pad = kmax + margin
                if np.any(blo - pad > hi) or np.any(bhi + pad < lo):
                    continue
            v = fn(p)
            d = smin(d, v, k) if mode == "add" else smax(d, -v, k)
        return d

    # ----------------------------------------------------------------------- meshing
    def grid(self, lo, hi, voxel: float, slab: int = 12):
        lo = np.asarray(lo, F)
        hi = np.asarray(hi, F)
        n = np.ceil((hi - lo) / voxel).astype(int) + 1
        xs = lo[0] + np.arange(n[0], dtype=F) * voxel
        ys = lo[1] + np.arange(n[1], dtype=F) * voxel
        zs = lo[2] + np.arange(n[2], dtype=F) * voxel
        out = np.empty((n[0], n[1], n[2]), F)
        X, Y = np.meshgrid(xs, ys, indexing="ij")
        for z0 in range(0, n[2], slab):
            z1 = min(z0 + slab, n[2])
            zz = zs[z0:z1]
            P = np.empty((n[0], n[1], z1 - z0, 3), F)
            P[..., 0] = X[..., None]
            P[..., 1] = Y[..., None]
            P[..., 2] = zz[None, None, :]
            plo = np.array([xs[0], ys[0], zz[0]], F)
            phi = np.array([xs[-1], ys[-1], zz[-1]], F)
            out[:, :, z0:z1] = self.eval(P, plo, phi)
        return out, lo

    def mesh(self, lo, hi, voxel: float, smooth_iters: int = 4):
        """Returns (verts (N,3) float64, quads (M,4) int) of the zero iso-surface."""
        import openvdb as vdb
        field, origin = self.grid(lo, hi, voxel)
        band = 3.0 * voxel
        field = np.clip(field, -band, band)
        g = vdb.FloatGrid(band)
        g.copyFromArray(field, (0, 0, 0), voxel * 0.01)
        pts, quads = g.convertToQuads(0.0)
        verts = origin.astype(np.float64) + pts.astype(np.float64) * voxel
        quads = quads.astype(np.int64)
        if smooth_iters:
            verts = taubin(verts, quads, smooth_iters)
        return verts, quads

    def surface_point(self, p, direction, step: float = 0.0015, max_dist: float = 0.4):
        """March from p along direction until the field crosses zero; returns the hit point."""
        p = np.asarray(p, F)
        dvec = np.asarray(direction, F)
        dvec = dvec / np.linalg.norm(dvec)
        prev = float(self.eval(p[None])[0])
        t = 0.0
        while t < max_dist:
            t += step
            q = p + dvec * t
            v = float(self.eval(q[None])[0])
            if (prev > 0) != (v > 0):
                return q - dvec * step * (abs(v) / (abs(v) + abs(prev) + 1e-9))
            prev = v
        return p + dvec * max_dist

    def normal(self, p, eps: float = 0.0008):
        p = np.asarray(p, F)
        e = np.eye(3, dtype=F) * eps
        pts = np.concatenate([p[None] + e, p[None] - e])
        v = self.eval(pts)
        n = v[:3] - v[3:]
        return n / (np.linalg.norm(n) + 1e-9)


def taubin(verts: np.ndarray, quads: np.ndarray, iters: int, lam: float = 0.5, mu: float = -0.53):
    """Volume-preserving Taubin smoothing on a quad mesh."""
    e = np.concatenate([quads[:, [0, 1]], quads[:, [1, 2]], quads[:, [2, 3]], quads[:, [3, 0]]])
    e = np.concatenate([e, e[:, ::-1]])
    n = len(verts)
    deg = np.bincount(e[:, 0], minlength=n).astype(np.float64)
    deg[deg == 0] = 1.0
    v = verts.copy()
    for _ in range(iters):
        for f in (lam, mu):
            acc = np.zeros_like(v)
            np.add.at(acc, e[:, 0], v[e[:, 1]])
            v = v + f * (acc / deg[:, None] - v)
    return v


def to_blender_mesh(name: str, verts: np.ndarray, quads: np.ndarray, flip: bool = False):
    import bpy
    if flip:
        quads = quads[:, ::-1]
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", verts.astype(np.float32).ravel())
    me.loops.add(quads.size)
    me.loops.foreach_set("vertex_index", quads.astype(np.int32).ravel())
    me.polygons.add(len(quads))
    me.polygons.foreach_set("loop_start", (np.arange(len(quads), dtype=np.int32) * 4))
    me.polygons.foreach_set("loop_total", np.full(len(quads), 4, np.int32))
    me.update(calc_edges=True)
    me.validate(clean_customdata=False)
    me.shade_smooth()
    return me


def project(field: "SDF", starts: np.ndarray, direction, max_iter: int = 400, tol: float = 2e-5) -> np.ndarray:
    """Vectorised conservative ray march (rays start outside) to the first zero crossing, then bisection."""
    p = np.asarray(starts, F).copy()
    d = np.asarray(direction, F)
    d = d / np.linalg.norm(d)
    n = len(p)
    t = np.zeros(n, F)
    t_prev = np.zeros(n, F)
    active = np.ones(n, bool)
    v = field.eval(p)
    for _ in range(max_iter):
        if not active.any():
            break
        step = np.clip(v * 0.5, 0.0004, 0.01)
        t_prev = np.where(active, t, t_prev)
        t = np.where(active, t + step, t)
        v = field.eval(np.asarray(starts, F) + d * t[:, None])
        active &= v > 0
        active &= t < 0.6
    lo, hi = t_prev.copy(), t.copy()
    for _ in range(14):
        mid = (lo + hi) / 2
        vm = field.eval(np.asarray(starts, F) + d * mid[:, None])
        inside = vm <= 0
        hi = np.where(inside, mid, hi)
        lo = np.where(inside, lo, mid)
    return (np.asarray(starts, F) + d * hi[:, None]).astype(F)


def normals(field: "SDF", pts: np.ndarray, eps: float = 0.0008) -> np.ndarray:
    pts = np.asarray(pts, F)
    n = np.zeros_like(pts)
    for i in range(3):
        e = np.zeros(3, F)
        e[i] = eps
        n[:, i] = field.eval(pts + e) - field.eval(pts - e)
    return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-9)
