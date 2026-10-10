"""Rigid/semi-rigid gear geometry (pure numpy): caps, helmets, belts, pouches, radios...

Every piece is appended to a ``Gear`` soup with a material id and skin weights (usually 100% to
one bone), so gear follows the skeleton without Blender's automatic weights.
"""

from __future__ import annotations

import math

import numpy as np

TAU = 2.0 * math.pi


def unit(v):
    return v / np.linalg.norm(v)


class Gear:
    def __init__(self) -> None:
        self.v: list[np.ndarray] = []
        self.f: list[tuple] = []
        self.mat: list[str] = []
        self.w: list[dict] = []

    def add_v(self, p, w: dict) -> int:
        self.v.append(np.asarray(p, dtype=np.float64))
        self.w.append(dict(w))
        return len(self.v) - 1

    def add_f(self, idx, mat: str) -> None:
        self.f.append(tuple(int(i) for i in idx))
        self.mat.append(mat)

    # -- primitives -------------------------------------------------------------------------
    def box(self, centre, size, axes, mat: str, w: dict, chamfer: float = 0.0) -> None:
        """Oriented box. ``axes`` = (ax, ay, az) unit vectors; ``size`` full extents."""
        c = np.asarray(centre, dtype=np.float64)
        ax, ay = (unit(np.asarray(a, dtype=np.float64)) for a in axes[:2])
        ay = unit(ay - ax * (ay @ ax))
        az = np.cross(ax, ay)
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        if chamfer <= 0.0:
            idx = []
            for sx, sy, sz in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                               (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)):
                idx.append(self.add_v(c + ax * hx * sx + ay * hy * sy + az * hz * sz, w))
            for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)):
                self.add_f([idx[i] for i in q], mat)
            return
        # chamfered box: rounded-rect prism along az with chamfered top/bottom rims
        ch = min(chamfer, hx * 0.45, hy * 0.45, hz * 0.45)
        prof = [(hx - ch, -hy), (hx, -hy + ch), (hx, hy - ch), (hx - ch, hy), (-hx + ch, hy), (-hx, hy - ch),
                (-hx, -hy + ch), (-hx + ch, -hy)]
        levels = [(-hz, 1.0 - ch / max(hx, hy)), (-hz + ch, 1.0), (hz - ch, 1.0), (hz, 1.0 - ch / max(hx, hy))]
        rings = []
        for zz, sc in levels:
            ring = [self.add_v(c + ax * px * sc + ay * py * sc + az * zz, w) for px, py in prof]
            rings.append(ring)
        for a, b in zip(rings[:-1], rings[1:]):
            n = len(a)
            for j in range(n):
                k = (j + 1) % n
                self.add_f((a[j], a[k], b[k], b[j]), mat)
        self.add_f(rings[0][::-1], mat)
        self.add_f(rings[-1], mat)

    def cylinder(self, centre, axis, radius: float, length: float, mat: str, w: dict, n: int = 12,
                 cap_mat: str | None = None, radius2: float | None = None) -> None:
        c = np.asarray(centre, dtype=np.float64)
        a = unit(np.asarray(axis, dtype=np.float64))
        ref = np.array([0.0, 0.0, 1.0]) if abs(a[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        u = unit(np.cross(a, ref))
        v = np.cross(a, u)
        r2 = radius if radius2 is None else radius2
        bot = [self.add_v(c - a * length / 2 + (u * math.cos(TAU * j / n) + v * math.sin(TAU * j / n)) * radius, w)
               for j in range(n)]
        top = [self.add_v(c + a * length / 2 + (u * math.cos(TAU * j / n) + v * math.sin(TAU * j / n)) * r2, w)
               for j in range(n)]
        for j in range(n):
            k = (j + 1) % n
            self.add_f((bot[j], bot[k], top[k], top[j]), mat)
        self.add_f(bot[::-1], cap_mat or mat)
        self.add_f(top, cap_mat or mat)

    def loft(self, rings: list[list[np.ndarray]], mat, w, close_start: str | None = None,
             close_end: str | None = None, closed: bool = True) -> list[list[int]]:
        """Quad bands between rings of points (equal length). ``mat`` may be a callable
        (ring_index, column) -> material id. ``w`` a dict or callable(point) -> dict.
        ``close_*``: None, "pole" (fan to centroid) or "cap" (one n-gon)."""
        idx = []
        for ring in rings:
            idx.append([self.add_v(p, w(p) if callable(w) else w) for p in ring])
        n = len(rings[0])
        for i in range(len(idx) - 1):
            a, b = idx[i], idx[i + 1]
            for j in range(n if closed else n - 1):
                k = (j + 1) % n
                m = mat(i, j) if callable(mat) else mat
                self.add_f((a[j], a[k], b[k], b[j]), m)
        for which, ring_i, flip in ((close_start, 0, True), (close_end, -1, False)):
            if which is None:
                continue
            ring = idx[ring_i]
            m = mat(ring_i if ring_i >= 0 else len(idx) - 1, 0) if callable(mat) else mat
            if which == "cap":
                self.add_f(ring[::-1] if flip else ring, m)
            else:
                cen = np.mean([self.v[i] for i in ring], axis=0)
                pole = self.add_v(cen, w(cen) if callable(w) else w)
                for j in range(n):
                    k = (j + 1) % n
                    self.add_f((ring[k], ring[j], pole) if flip else (ring[j], ring[k], pole), m)
        return idx

    def plate(self, a_pts, b_pts, th: float, mat: str, w, top_mat: str | None = None, rows: int = 1,
              ref=None) -> None:
        """Closed thick strip between edge polylines ``a_pts`` and ``b_pts`` (same length).

        The given points form the outer surface; the inner surface sits ``th`` behind it (away
        from the outer normal, which points away from ``ref`` or upwards). ``top_mat`` colours
        the outer surface only. ``w`` is a dict or callable(point) -> dict."""
        a = [np.asarray(p, dtype=np.float64) for p in a_pts]
        b = [np.asarray(p, dtype=np.float64) for p in b_pts]
        n = len(a)
        grid = [[a[j] * (1 - r / rows) + b[j] * (r / rows) for j in range(n)] for r in range(rows + 1)]
        centre = np.mean([p for row in grid for p in row], axis=0)
        normals = []
        for r in range(rows + 1):
            row = []
            for j in range(n):
                tj = grid[r][min(j + 1, n - 1)] - grid[r][max(j - 1, 0)]
                tr = grid[min(r + 1, rows)][j] - grid[max(r - 1, 0)][j]
                nn = unit(np.cross(tj, tr))
                away = (grid[r][j] - np.asarray(ref)) if ref is not None else np.array([0.0, 0.0, 1.0])
                if nn @ away < 0:
                    nn = -nn
                row.append(nn)
            normals.append(row)
        start = len(self.f)
        wf = (lambda p: w(p)) if callable(w) else (lambda p: w)
        outer = [[self.add_v(grid[r][j], wf(grid[r][j])) for j in range(n)] for r in range(rows + 1)]
        inner = [[self.add_v(grid[r][j] - normals[r][j] * th, wf(grid[r][j])) for j in range(n)]
                 for r in range(rows + 1)]
        tm = top_mat or mat
        for r in range(rows):
            for j in range(n - 1):
                self.add_f((outer[r][j], outer[r][j + 1], outer[r + 1][j + 1], outer[r + 1][j]), tm)
                self.add_f((inner[r][j], inner[r + 1][j], inner[r + 1][j + 1], inner[r][j + 1]), mat)
        for j in range(n - 1):   # long edges
            self.add_f((outer[0][j + 1], outer[0][j], inner[0][j], inner[0][j + 1]), mat)
            self.add_f((outer[rows][j], outer[rows][j + 1], inner[rows][j + 1], inner[rows][j]), mat)
        for r in range(rows):    # short ends
            self.add_f((outer[r][0], outer[r + 1][0], inner[r + 1][0], inner[r][0]), mat)
            self.add_f((outer[r + 1][n - 1], outer[r][n - 1], inner[r][n - 1], inner[r + 1][n - 1]), mat)
        self._fix_volume(start, centre)

    def _fix_volume(self, start: int, centre) -> None:
        vol = 0.0
        c = np.asarray(centre)
        for f in self.f[start:]:
            p0 = self.v[f[0]] - c
            for q in range(1, len(f) - 1):
                vol += float(np.dot(p0, np.cross(self.v[f[q]] - c, self.v[f[q + 1]] - c)))
        if vol < 0:
            for i in range(start, len(self.f)):
                self.f[i] = tuple(reversed(self.f[i]))

    def pouch(self, gen, phi: float, z: float, off: float, size, mat: str, w: dict) -> None:
        nrm = unit(np.array([math.sin(phi), math.cos(phi), 0.0]))
        ax = unit(np.cross(np.array([0.0, 0.0, 1.0]), nrm))
        c = gen.torso_point(phi, z, off + size[1] / 2)
        self.box(c, size, (ax, nrm, np.array([0.0, 0.0, 1.0])), mat, w, chamfer=min(size) * 0.18)

    def ellipsoid(self, centre, radii, mat: str, w: dict, nu: int = 14, nv: int = 8) -> None:
        c = np.asarray(centre, dtype=np.float64)
        rings = []
        for i in range(1, nv):
            th = math.pi * i / nv
            ring = []
            for j in range(nu):
                ph = TAU * j / nu
                ring.append(c + np.array([radii[0] * math.sin(th) * math.cos(ph), radii[1] * math.sin(th) * math.sin(ph),
                                          -radii[2] * math.cos(th)]))
            rings.append(ring)
        start = len(self.f)
        self.loft(rings, mat, w, close_start="pole", close_end="pole")
        bot = len(self.v) - 2
        top = len(self.v) - 1
        self.v[bot] = c - np.array([0.0, 0.0, radii[2]])
        self.v[top] = c + np.array([0.0, 0.0, radii[2]])
        self._fix_volume(start, c)

    def result(self):
        return np.array(self.v) if self.v else np.zeros((0, 3)), list(self.f), list(self.mat), list(self.w)

    def tri_count(self) -> int:
        return sum(len(f) - 2 for f in self.f)
