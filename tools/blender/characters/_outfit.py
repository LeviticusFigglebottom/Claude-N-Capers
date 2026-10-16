"""Outfit toolkit for ``rig_humanoid`` characters (D1-02). Blender only (``mathutils``).

Private helper (``_`` prefix): imported by the ``char_*.py`` asset scripts, never built on its own.

How a character is made
* ``Fit(params)`` generates the variant's body once (``_body.body_mesh_data``, nothing hidden) and
  keeps its **blended** vertex positions, vertex normals, skin weights, named rings and a BVH. All
  fitting is geometric (rays, nearest points, named rings); nothing depends on head vertex indices,
  so outfits keep working when ``_body``'s head changes.
* Soft garments (shirts, trousers, jackets, gloves, shoes) are **shells**: the body faces of the
  covered area, pushed out along the vertex normals by a per-garment offset field, then **draped**
  (Taubin smoothing with a min/max distance constraint to the body or an inner-layer hull: concave
  grooves get bridged like cloth, nothing sinks into the skin), then given cut, straightened hems
  with a folded **lip** so every opening shows cloth thickness. Skirts, jacket tails and coats are
  **lofted** downward from a hem loop over the outer hull of the legs.
* Surface details (pockets, flaps, plackets, lapels, patches, tie) are **patches**: star-shaped 2D
  outlines cast onto the current hull along a projection direction, raised a few millimetres with
  a chamfered rim.
* Hard gear (badges, buckles, radio, pouches, buttons, caps' badges) is built with
  ``lib.geo.MeshBuilder`` in a local frame, **bevelled before UVs**, then placed on a surface frame.
* Weights: soft parts copy the skin weights of the nearest body point (so cloth deforms exactly like
  the skin under it); rigid parts use one anchor point's weights for all their vertices (they move
  as one piece with the surface they sit on); headwear is 100 % ``head``; skirts blend hips/thighs.

Axes as in ``_rig``/``_body``: Blender +Z up, the character faces +Y (= Godot -Z), right = +X (.R).
"""

from __future__ import annotations

import itertools
import math
from collections.abc import Callable, Sequence

from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import _body as body
import _outfit_palette as palette
import _rig as rig
import _tri

TAU = 2.0 * math.pi
UP = Vector((0.0, 0.0, 1.0))
FWD = Vector((0.0, 1.0, 0.0))


def smoothstep(e0: float, e1: float, x: float) -> float:
    if e0 == e1:
        return 0.0 if x < e0 else 1.0
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def clamp(x: float, a: float, b: float) -> float:
    return a if x < a else min(x, b)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def angle_of(x: float, y: float) -> float:
    """Polar angle around the vertical axis: 0 = front (+Y), +90 deg = right (+X). Radians."""
    return math.atan2(x, y)


def wrap(a: float) -> float:
    """Wrap an angle to (-pi, pi]."""
    while a <= -math.pi:
        a += TAU
    while a > math.pi:
        a -= TAU
    return a


# =============================================================================================
# mesh container
# =============================================================================================
class Mesh:
    """Vertices, faces (ccw seen from outside), per-face material ids and per-vertex skinning hints.

    Skinning hints per vertex: ``w`` an explicit ``{bone: weight}`` dict, else ``a`` an anchor point
    whose body weights are used (rigid gear), else the vertex position itself (soft cloth)."""

    def __init__(self) -> None:
        self.v: list[Vector] = []
        self.f: list[tuple[int, ...]] = []
        self.m: list[str] = []
        self.w: list[dict | None] = []
        self.a: list[Vector | None] = []

    def add(self, p, w: dict | None = None, a: Vector | None = None) -> int:
        self.v.append(Vector(p))
        self.w.append(w)
        self.a.append(a)
        return len(self.v) - 1

    def ring(self, pts, w: dict | None = None, a: Vector | None = None) -> list[int]:
        return [self.add(p, w, a) for p in pts]

    def face(self, idx: Sequence[int], mat: str, inside: Vector | None = None) -> None:
        idx = tuple(idx)
        if inside is not None:
            n = newell(self.v, idx)
            c = sum((self.v[i] for i in idx), Vector()) / len(idx)
            if n.dot(c - inside) < 0.0:
                idx = tuple(reversed(idx))
        self.f.append(idx)
        self.m.append(mat)

    def band(self, a: list[int], b: list[int], mat: str, closed: bool = True, inside: Vector | None = None,
             flip: bool = False) -> None:
        n = len(a)
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            q = (a[j], a[k], b[k], b[j])
            self.face(tuple(reversed(q)) if flip else q, mat, inside)

    def fan(self, ring: list[int], pole: int, mat: str, flip: bool = False) -> None:
        n = len(ring)
        for j in range(n):
            q = (ring[j], ring[(j + 1) % n], pole)
            self.face(tuple(reversed(q)) if flip else q, mat)

    def extend(self, other: Mesh) -> None:
        off = len(self.v)
        self.v += [p.copy() for p in other.v]
        self.w += other.w
        self.a += other.a
        self.f += [tuple(i + off for i in f) for f in other.f]
        self.m += other.m

    def tris(self) -> int:
        return sum(len(f) - 2 for f in self.f)

    def set_rigid(self, anchor: Vector | None = None, weights: dict | None = None) -> Mesh:
        for i in range(len(self.v)):
            self.w[i] = weights
            self.a[i] = anchor.copy() if anchor is not None else None
        return self

    def transformed(self, mtx: Matrix) -> Mesh:
        for i, p in enumerate(self.v):
            self.v[i] = mtx @ p
        return self


def newell(verts: list[Vector], idx: Sequence[int]) -> Vector:
    n = Vector()
    k = len(idx)
    for i in range(k):
        a = verts[idx[i]]
        b = verts[idx[(i + 1) % k]]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


def vertex_normals(verts: list[Vector], faces: list[tuple[int, ...]]) -> list[Vector]:
    acc = [Vector() for _ in verts]
    for f in faces:
        n = newell(verts, f)
        for i in f:
            acc[i] += n
    out = []
    for n in acc:
        out.append(n.normalized() if n.length > 1e-12 else Vector((0.0, 0.0, 1.0)))
    return out


def adjacency(nv: int, faces: list[tuple[int, ...]]) -> list[list[int]]:
    nb: list[set[int]] = [set() for _ in range(nv)]
    for f in faces:
        k = len(f)
        for i in range(k):
            a, b = f[i], f[(i + 1) % k]
            nb[a].add(b)
            nb[b].add(a)
    return [sorted(s) for s in nb]


def boundary_loops(faces: list[tuple[int, ...]]) -> list[list[int]]:
    """Closed boundary loops, each ordered along the face winding (a -> b as in its face)."""
    count: dict[tuple[int, int], int] = {}
    directed: dict[int, list[int]] = {}
    for f in faces:
        k = len(f)
        for i in range(k):
            a, b = f[i], f[(i + 1) % k]
            key = (a, b) if a < b else (b, a)
            count[key] = count.get(key, 0) + 1
    for f in faces:
        k = len(f)
        for i in range(k):
            a, b = f[i], f[(i + 1) % k]
            if count[(a, b) if a < b else (b, a)] == 1:
                directed.setdefault(a, []).append(b)
    loops: list[list[int]] = []
    seen: set[int] = set()
    for start in sorted(directed):
        if start in seen:
            continue
        loop = [start]
        seen.add(start)
        cur = start
        while True:
            nxts = [n for n in directed.get(cur, []) if n not in seen or n == start]
            if not nxts:
                break
            nxt = min(nxts)
            if nxt == start:
                break
            loop.append(nxt)
            seen.add(nxt)
            cur = nxt
        if len(loop) >= 3:
            loops.append(loop)
    return loops


# =============================================================================================
# the fitted body
# =============================================================================================
_REGION_PRIO = {r: i for i, r in enumerate(body.REGIONS)}


class Fit:
    """One character's body for fitting: blended positions (metres, at the variant's height),
    vertex normals and regions, skin weights, named rings, BVHs and rig joints."""

    def __init__(self, params: dict) -> None:
        p = body.body_params(params)
        self.params = p
        full = dict(p)
        full["hide"] = frozenset()
        bd, hd = body.body_mesh_data(full)
        self.k = float(p["height"]) / body.REF_HEIGHT
        self.P = [Vector(v) for v in bd.blend]
        self.F = [tuple(f) for f in bd.faces]
        self.FR = list(bd.face_region)
        self.FS = list(bd.face_side)
        self.FM = list(bd.face_mat)
        self.N = vertex_normals(self.P, self.F)
        self.W = body.body_weights(bd)
        vr: list[str | None] = [None] * len(self.P)
        for f, r in zip(self.F, self.FR):
            for i in f:
                if vr[i] is None or _REGION_PRIO[r] > _REGION_PRIO[vr[i]]:
                    vr[i] = r
        self.VR = [r or "torso" for r in vr]
        self.rings = {n: list(loop) for n, loop in bd.rings.items()}
        self.bvh = BVHTree.FromPolygons([tuple(v) for v in self.P], self.F)
        nohead = [i for i, r in enumerate(self.FR) if r != "head"]
        self._skin_faces = nohead
        self.bvh_skin = BVHTree.FromPolygons([tuple(v) for v in self.P], [self.F[i] for i in nohead])
        head_faces = [self.F[i] for i, r in enumerate(self.FR) if r == "head"]
        hv = [tuple(v) for v in self.P]
        hf = list(head_faces)
        off = len(hv)
        self.hair_verts = [Vector(v) for v in hd.blend]
        self.hair_faces = [tuple(f) for f in hd.faces]
        hv += [tuple(v) for v in hd.blend]
        hf += [tuple(i + off for i in f) for f in hd.faces]
        self.head_bvh = BVHTree.FromPolygons(hv, hf)
        # the scalp/face skin alone (no ears, eyes, brows, hair): glasses temples run on it
        scalp = [f for f, r, sd, mt in zip(self.F, self.FR, self.FS, self.FM) if r == "head" and sd == 0]
        self.scalp_bvh = BVHTree.FromPolygons([tuple(v) for v in self.P], scalp)
        self.J = rig.joints(float(p["height"]))
        self.height = float(p["height"])

    # -- queries ------------------------------------------------------------------------------
    def ring(self, name: str) -> list[Vector]:
        return [self.P[i].copy() for i in self.rings[name]]

    def ring_centre(self, name: str) -> Vector:
        pts = self.ring(name)
        return sum(pts, Vector()) / len(pts)

    def weights_at(self, p: Vector) -> dict[str, float]:
        """Skin weights at the body point nearest to ``p`` (head excluded)."""
        loc, _n, fi, _d = self.bvh_skin.find_nearest(p)
        f = self.F[self._skin_faces[fi]]
        acc: dict[str, float] = {}
        tot = 0.0
        for vi in f:
            c = 1.0 / ((self.P[vi] - loc).length + 1e-4) ** 2
            tot += c
            for b, x in self.W[vi].items():
                acc[b] = acc.get(b, 0.0) + x * c
        top = sorted(acc.items(), key=lambda kv: (-kv[1], kv[0]))[:4]
        s = sum(x for _b, x in top)
        out = {b: x / s for b, x in top if x / s >= 0.01}
        s = sum(out.values())
        return {b: x / s for b, x in sorted(out.items())}

    def faces_where(self, pred: Callable[[str, Vector, int], bool]) -> list[int]:
        out = []
        for i, (f, r) in enumerate(zip(self.F, self.FR)):
            c = sum((self.P[v] for v in f), Vector()) / len(f)
            if pred(r, c, i):
                out.append(i)
        return out

    def eye_centre(self) -> Vector:
        return (Vector(self.J["eye.L"]) + Vector(self.J["eye.R"])) * 0.5

    def head_centre(self) -> Vector:
        e = self.eye_centre()
        return Vector((0.0, e.y - 0.075 * self.k, e.z + 0.03 * self.k))

    def head_top(self) -> float:
        """Highest point of skin or hair on the centre line."""
        c = self.head_centre()
        hit = self.head_bvh.ray_cast(Vector((c.x, c.y, c.z + 0.5)), Vector((0, 0, -1)), 1.0)
        return hit[0].z if hit[0] is not None else c.z + 0.12 * self.k


# =============================================================================================
# hulls
# =============================================================================================
class Hull:
    """Union of surfaces used as the 'inside' when fitting an outer layer (body + inner layers)."""

    def __init__(self, fit: Fit, meshes: Sequence[Mesh] = (), body_regions: set[str] | None = None,
                 include_hair: bool = False) -> None:
        verts = [tuple(v) for v in fit.P]
        faces = [f for f, r in zip(fit.F, fit.FR) if body_regions is None or r in body_regions]
        if include_hair:
            off = len(verts)
            verts += [tuple(v) for v in fit.hair_verts]
            faces += [tuple(i + off for i in f) for f in fit.hair_faces]
        for m in meshes:
            off = len(verts)
            verts += [tuple(v) for v in m.v]
            faces += [tuple(i + off for i in f) for f in m.f]
        self.bvh = BVHTree.FromPolygons(verts, faces)

    def nearest(self, p: Vector):
        return self.bvh.find_nearest(p)

    def cast(self, origin: Vector, direction: Vector, dist: float = 2.0):
        return self.bvh.ray_cast(origin, direction, dist)

    def inner_radius(self, z: float, theta: float, cx: float = 0.0, cy: float = 0.0, far: float = 0.6) -> float:
        """Distance from the vertical axis (cx, cy) to the first surface hit going outwards."""
        d = Vector((math.sin(theta), math.cos(theta), 0.0))
        hit = self.bvh.ray_cast(Vector((cx, cy, z)), d, far)
        return hit[3] if hit[0] is not None else 0.0

    def outer_radius(self, z: float, theta: float, cx: float = 0.0, cy: float = 0.0, far: float = 0.6) -> float:
        """Distance from the vertical axis (cx, cy) to the outermost surface at height z, angle theta
        (0 = front). 0 if nothing is hit."""
        d = Vector((math.sin(theta), math.cos(theta), 0.0))
        o = Vector((cx, cy, z)) + d * far
        hit = self.bvh.ray_cast(o, -d, far)
        if hit[0] is None:
            return 0.0
        return far - hit[3]


def push_out(p: Vector, hull: Hull, min_off: float, max_off: float | None = None) -> Vector:
    loc, n, _i, d = hull.nearest(p)
    if loc is None:
        return p
    s = (p - loc).dot(n)
    if s < min_off:
        return loc + n * min_off
    if max_off is not None and d > max_off:
        return loc + (p - loc) * (max_off / d)
    return p


# =============================================================================================
# shells
# =============================================================================================
class Shell:
    """A garment shell made from body faces. ``src[i]`` = body vertex of shell vertex i (or -1)."""

    def __init__(self, fit: Fit, faces: list[int], offset: Callable[[Vector, Vector, str], float],
                 mat: str | Callable[[Vector, str], str]) -> None:
        self.fit = fit
        used = sorted({v for fi in faces for v in fit.F[fi]})
        self.of_body = {v: n for n, v in enumerate(used)}
        self.src = list(used)
        self.mesh = Mesh()
        for v in used:
            p, n = fit.P[v], fit.N[v]
            self.mesh.add(p + n * offset(p, n, fit.VR[v]))
        for fi in faces:
            f = tuple(self.of_body[v] for v in fit.F[fi])
            if callable(mat):
                c = sum((fit.P[v] for v in fit.F[fi]), Vector()) / len(fit.F[fi])
                self.mesh.face(f, mat(c, fit.FR[fi]))
            else:
                self.mesh.face(f, mat)

    def ring(self, name: str) -> list[int]:
        """Shell vertex ids of a named body ring (all of its vertices must be in the shell)."""
        return [self.of_body[v] for v in self.fit.rings[name]]

    def loops(self) -> list[list[int]]:
        return boundary_loops(self.mesh.f)


def drape(m: Mesh, hull: Hull, min_off: float | Callable[[Vector], float], max_off: float | None = None,
          iters: int = 6, lam: float = 0.5, mu: float = -0.53, pin: set[int] | None = None,
          only: set[int] | None = None) -> None:
    """Taubin-smooth ``m`` (boundary vertices only along their boundary) while keeping every vertex
    at least ``min_off`` outside ``hull`` (and at most ``max_off`` away from it)."""
    nb = adjacency(len(m.v), m.f)
    loops = boundary_loops(m.f)
    bnb: dict[int, list[int]] = {}
    for loop in loops:
        k = len(loop)
        for i, v in enumerate(loop):
            bnb[v] = [loop[i - 1], loop[(i + 1) % k]]
    pin = pin or set()
    idx = [i for i in range(len(m.v)) if i not in pin and (only is None or i in only) and nb[i]]
    for _it in range(iters):
        for fac in (lam, mu):
            new = {}
            for i in idx:
                ns = bnb.get(i, nb[i])
                avg = sum((m.v[j] for j in ns), Vector()) / len(ns)
                new[i] = m.v[i] + (avg - m.v[i]) * fac
            for i, q in new.items():
                mo = min_off(q) if callable(min_off) else min_off
                m.v[i] = push_out(q, hull, mo, max_off)


def straighten_loop(m: Mesh, loop: list[int], iters: int = 4, fac: float = 0.5) -> None:
    """Smooth a boundary loop along itself (removes stair steps of a cut)."""
    k = len(loop)
    for _ in range(iters):
        new = []
        for i in range(k):
            a, b = m.v[loop[i - 1]], m.v[loop[(i + 1) % k]]
            new.append(m.v[loop[i]] + ((a + b) * 0.5 - m.v[loop[i]]) * fac)
        for i in range(k):
            m.v[loop[i]] = new[i]


def hem(m: Mesh, loop: list[int], thick: float = 0.004, depth: float = 0.014, mat: str | None = None,
        roll: float = 0.0) -> list[int]:
    """Fold a boundary loop inwards: an edge face (cloth thickness) and an inner facing strip.

    ``loop`` must be ordered along the face winding (as ``boundary_loops`` returns it). ``roll``
    pushes the boundary itself outwards a little first (a rolled/stitched hem). Returns the inner
    ring."""
    nrm = vertex_normals(m.v, m.f)
    # tangent pointing into the garment (from the boundary towards the adjacent faces)
    inward: dict[int, Vector] = {i: Vector() for i in loop}
    fmat: dict[tuple[int, int], str] = {}
    in_loop = set(loop)
    for fi, f in enumerate(m.f):
        k = len(f)
        c = sum((m.v[i] for i in f), Vector()) / k
        for j in range(k):
            a = f[j]
            if a in in_loop:
                inward[a] += c - m.v[a]
            b = f[(j + 1) % k]
            if a in in_loop and b in in_loop:
                fmat[(a, b)] = m.m[fi]
    k = len(loop)
    r1, r2 = [], []
    for v in loop:
        n = nrm[v]
        t = inward[v] - n * inward[v].dot(n)
        t = t.normalized() if t.length > 1e-9 else Vector()
        if roll:
            m.v[v] = m.v[v] + n * roll
        p1 = m.v[v] - n * thick
        r1.append(m.add(p1, m.w[v], m.a[v]))
        r2.append(m.add(p1 + t * depth - n * 0.0005, m.w[v], m.a[v]))
    for i in range(k):
        a, b = loop[i], loop[(i + 1) % k]
        mt = mat or fmat.get((a, b)) or fmat.get((b, a)) or m.m[0]
        m.f.append((b, a, r1[i], r1[(i + 1) % k]))
        m.m.append(mt)
        m.f.append((r1[(i + 1) % k], r1[i], r2[i], r2[(i + 1) % k]))
        m.m.append(mt)
    return r2


def hem_all(m: Mesh, thick: float = 0.004, depth: float = 0.014, skip: Callable[[list[int]], bool] | None = None) -> None:
    for loop in boundary_loops(m.f):
        if skip is not None and skip(loop):
            continue
        hem(m, loop, thick, depth)


def loop_centre(m: Mesh, loop: list[int]) -> Vector:
    return sum((m.v[i] for i in loop), Vector()) / len(loop)


def snap_loop_z(m: Mesh, loop: list[int], z_of: Callable[[Vector], float], hull: Hull | None = None,
                clearance: float = 0.004) -> None:
    """Move boundary vertices vertically onto a cut line z(p) (keeps them outside ``hull``)."""
    for v in loop:
        p = m.v[v]
        q = Vector((p.x, p.y, z_of(p)))
        m.v[v] = push_out(q, hull, clearance) if hull is not None else q


# =============================================================================================
# lofts (skirts, coat and jacket tails, trouser and sleeve hems)
# =============================================================================================
def loft_down(m: Mesh, top: list[int], z_hem: Callable[[float], float], hull: Hull, rows: int,
              clearance: float = 0.012, flare: float = 0.06, centre: Vector | None = None,
              weights: Callable[[Vector, float], dict] | None = None, mat: str | None = None,
              keep_shape: float = 0.5) -> list[list[int]]:
    """Hang cloth straight down from the loop ``top`` (ordered as a boundary loop of ``m``).

    For each top vertex (angle theta around ``centre``), rows go down to ``z_hem(theta)``; the radius
    grows by ``flare`` per metre and never comes closer than ``clearance`` to the outer hull of
    whatever is inside (legs, trousers). ``keep_shape`` blends from the top loop's cross-section
    (1) to a rounded one (0) towards the hem. Returns the rings (top first)."""
    c = centre if centre is not None else loop_centre(m, top)
    cols = []
    for v in top:
        p = m.v[v]
        th = angle_of(p.x - c.x, p.y - c.y)
        r0 = math.hypot(p.x - c.x, p.y - c.y)
        cols.append((th, r0, p.z))
    rmean = sum(r for _t, r, _z in cols) / len(cols)
    rings = [list(top)]
    prev_r = [r for _t, r, _z in cols]
    mt = mat or m.m[0]
    for j in range(1, rows + 1):
        t = j / rows
        ring = []
        new_r = []
        for i, (th, r0, z0) in enumerate(cols):
            z = lerp(z0, z_hem(th), t)
            dz = z0 - z
            target = lerp(rmean, r0, keep_shape + (1 - keep_shape) * (1 - t)) + flare * dz
            r_in = hull.outer_radius(z, th, c.x, c.y)
            r = max(target, prev_r[i] * 0.985, r_in + clearance if r_in > 0 else 0.0)
            new_r.append(r)
            ring.append(Vector((c.x + r * math.sin(th), c.y + r * math.cos(th), z)))
        # smooth radii around the ring so a leg gap doesn't leave a dent
        n = len(ring)
        sm = []
        for i in range(n):
            sm.append(max(new_r[i], 0.25 * new_r[i - 1] + 0.5 * new_r[i] + 0.25 * new_r[(i + 1) % n]))
        ring = [Vector((c.x + sm[i] * math.sin(cols[i][0]), c.y + sm[i] * math.cos(cols[i][0]), ring[i].z))
                for i in range(n)]
        prev_r = sm
        ids = []
        for p in ring:
            ids.append(m.add(p, weights(p, t) if weights is not None else None))
        rings.append(ids)
    # faces: keep the winding of the shell (top loop is ordered along its faces' winding)
    for a, b in itertools.pairwise(rings):
        k = len(a)
        for i in range(k):
            j = (i + 1) % k
            m.f.append((a[j], a[i], b[i], b[j]))
            m.m.append(mt)
    return rings


def skirt_weights(fit: Fit, z_top: float, z_hem: float, thigh_max: float = 0.85,
                  centre_w: float = 0.05, ramp: float = 1.0, back_relax: float = 0.0,
                  front_ramp: float | None = None, shin_max: float = 0.0,
                  knee_band: float = 0.10) -> Callable[[Vector, float], dict]:
    """Hips at the waist, blending to the thigh of the vertex's side towards the hem (at most
    ``thigh_max`` at the hem). Within ``centre_w`` of the centre line the two thighs are mixed, so
    the cloth either side of a front split (coat and jacket tails: a wider ``centre_w``, a lower
    ``thigh_max``) moves together and the split does not gape on long strides. ``ramp`` < 1 reaches
    ``thigh_max`` that share of the way down (a closed skirt: the cloth over the thigh follows it early).
    ``back_relax`` takes that share of the thigh weight back to the hips behind the body, so a seated figure's
    back panel stays under the seat instead of swinging up between the knees with the thighs. ``front_ramp`` (D-115
    clip audit) replaces ``ramp`` in front of the body: a short ramp lays a closed front panel on the thigh from just
    below the crease instead of blending through it (tabard in cower_stand). ``shin_max`` (D-116 seated drape, long
    coats and robes): below the knee that share of each side's thigh weight moves to its shin over ``knee_band`` m, so
    the cloth past the knees falls with the shins on a seated body instead of standing out level with the thighs."""
    cy = fit.ring_centre("hips").y
    knee_z = min(Vector(fit.J["knee.L"]).z, Vector(fit.J["knee.R"]).z) if shin_max else 0.0
    def w(p: Vector, _t: float) -> dict:
        t = clamp((z_top - p.z) / max(z_top - z_hem, 1e-3), 0.0, 1.0)
        rp = ramp
        if front_ramp is not None:
            rp = lerp(ramp, front_ramp, smoothstep(cy + 0.02 * fit.k, cy + 0.08 * fit.k, p.y))
        t = thigh_max * smoothstep(0.0, rp, t)
        t_full = t
        if back_relax:
            t *= 1.0 - back_relax * smoothstep(cy + 0.01 * fit.k, cy - 0.06 * fit.k, p.y)
        s_r = smoothstep(-centre_w * fit.k, centre_w * fit.k, p.x)
        out = {"hips": 1.0 - t}
        # below the knee the shin share ignores back_relax: the back panel past the seat edge hangs behind the calves
        # too, instead of staying on the hips and stretching the side hem into a strip from the lap to the shins
        sh = shin_max * smoothstep(knee_z + 0.02 * fit.k, knee_z - knee_band * fit.k, p.z) if shin_max else 0.0
        out["hips"] = 1.0 - t * (1.0 - sh) - t_full * sh
        for sfx, share in (("R", s_r), ("L", 1 - s_r)):
            if t * share * (1.0 - sh) > 0.01:
                out[f"thigh.{sfx}"] = t * share * (1.0 - sh)
            if t_full * share * sh > 0.01:
                out[f"shin.{sfx}"] = t_full * share * sh
        s = sum(out.values())
        return {b: x / s for b, x in sorted(out.items())}
    return w


# =============================================================================================
# patches (pockets, flaps, plackets, lapels, tie, patches)
# =============================================================================================
def rounded_rect(w: float, h: float, r: float, n_corner: int = 3, point: float = 0.0) -> list[tuple[float, float]]:
    """Outline centred at the origin, counter-clockwise (u right, v up). ``point`` > 0 pulls the
    bottom edge down to a centred point (pocket flaps, tie tips)."""
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0.0), (-w / 2 + r, h / 2 - r, 90.0), (-w / 2 + r, -h / 2 + r, 180.0),
               (w / 2 - r, -h / 2 + r, 270.0)]
    for cx, cy, a0 in corners:
        for i in range(n_corner + 1):
            a = math.radians(a0 + 90.0 * i / n_corner)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        if a0 == 180.0 and point > 0:
            pts.append((0.0, -h / 2 - point))
    return pts


def shield_outline(w: float, h: float, n: int = 6) -> list[tuple[float, float]]:
    """Heraldic shield (flat top with rounded corners, curved sides to a bottom point), ccw."""
    pts = [(w / 2, h / 2 - 0.08 * h), (w / 2 - 0.08 * w, h / 2), (-w / 2 + 0.08 * w, h / 2), (-w / 2, h / 2 - 0.08 * h)]
    for i in range(1, n + 1):
        t = i / n
        x = -w / 2 * (1 - t ** 1.6)
        y = h / 2 - 0.08 * h - t * (h - 0.08 * h)
        pts.append((x, y))
    for i in range(n - 1, 0, -1):
        t = i / n
        x = w / 2 * (1 - t ** 1.6)
        y = h / 2 - 0.08 * h - t * (h - 0.08 * h)
        pts.append((x, y))
    return pts


def _poly_centre(outline: list[tuple[float, float]]) -> tuple[float, float]:
    n = len(outline)
    return (sum(p[0] for p in outline) / n, sum(p[1] for p in outline) / n)


def patch(m: Mesh, hull: Hull, origin: Vector, u: Vector, v: Vector, outline: list[tuple[float, float]],
          height: float, mat: str, cast_dir: Vector, rim_mat: str | None = None, rings: int = 2,
          chamfer: float = 0.0025, sink: float = 0.0015, centre: tuple[float, float] | None = None,
          min_gap: float = 0.0, weights: dict | None = None, anchor: Vector | None = None) -> list[int]:
    """Raised patch: ``outline`` (star-shaped around ``centre``) drawn in the plane (origin, u, v) and
    cast onto ``hull`` along ``cast_dir``, lifted by ``height`` along the hit normal, with a chamfered
    rim sinking ``sink`` below the surface. Returns the vertex ids of the top (inset) ring."""
    u = u.normalized()
    v = v.normalized()
    d = cast_dir.normalized()
    cu, cv = centre if centre is not None else _poly_centre(outline)

    def cast(a: float, b: float, lift: float) -> tuple[Vector, Vector]:
        p = origin + u * a + v * b
        hit = hull.cast(p - d * 0.25, d, 0.6)
        if hit[0] is None:
            return p - d * lift, -d
        n = hit[1]
        if n.dot(-d) < 0:
            n = -n
        return hit[0] + n * (lift + min_gap), n

    k = len(outline)
    pc, pn = cast(cu, cv, height)
    pole = m.add(pc, weights, anchor)
    rings_ids: list[list[int]] = []
    for r in range(1, rings + 1):
        f = r / (rings + 0.6)
        rings_ids.append([m.add(cast(cu + (a - cu) * f, cv + (b - cv) * f, height)[0], weights, anchor)
                          for a, b in outline])
    inset = []
    for a, b in outline:
        da, db = a - cu, b - cv
        ln = math.hypot(da, db) or 1.0
        s = max(0.0, 1.0 - chamfer / ln)
        inset.append((cu + da * s, cv + db * s))
    top = [m.add(cast(a, b, height)[0], weights, anchor) for a, b in inset]
    rim = [m.add(cast(a, b, height * 0.55)[0], weights, anchor) for a, b in outline]
    base = [m.add(cast(a, b, -sink)[0], weights, anchor) for a, b in outline]
    allrings = rings_ids + [top, rim, base]
    mats = [mat] * len(rings_ids) + [rim_mat or mat, rim_mat or mat]

    def put(q: tuple[int, ...], mt: str, outward: Vector) -> None:
        n = newell(m.v, q)
        if n.dot(outward) < 0:
            q = tuple(reversed(q))
        m.f.append(q)
        m.m.append(mt)

    for j in range(k):
        put((allrings[0][j], allrings[0][(j + 1) % k], pole), mat, pn)
    for ri, (a_, b_) in enumerate(itertools.pairwise(allrings)):
        for j in range(k):
            jj = (j + 1) % k
            q = (a_[j], a_[jj], b_[jj], b_[j])
            mid = (m.v[a_[j]] + m.v[b_[jj]]) * 0.5
            radial = mid - m.v[pole]
            radial -= pn * radial.dot(pn)
            outward = pn if ri < len(rings_ids) else (radial.normalized() + pn * 0.3)
            put(q, mats[ri], outward)
    return top


def strip(m: Mesh, hull: Hull, path: list[Vector], half_width: float | Callable[[float], float], height: float,
          mat: str, side_hint: Vector | None = None, cast_back: float = 0.15, segs_across: int = 2,
          weights: dict | None = None, anchor: Vector | None = None, chamfer: float = 0.002,
          closed: bool = False, end_caps: bool = True, edge_mat: str | None = None,
          profile: Callable[[float], float] | None = None) -> list[list[int]]:
    """A raised band along ``path`` (points near the surface): straps, plackets, hi-vis stripes,
    lapels, the tie blade. Each cross-section is cast onto ``hull`` along its own surface normal.
    ``profile(o)`` scales the lift across the band (o = -1 .. 1 from edge to edge; e.g. a lapel
    rolled up at its front edge). Returns the rows of vertex ids (across the band, edge to edge)."""
    n = len(path)
    rows: list[list[int]] = []
    sns: list[Vector] = []
    sides: list[Vector] = []
    for i, p in enumerate(path):
        a = path[i - 1] if closed else path[max(i - 1, 0)]
        b = path[(i + 1) % n] if closed else path[min(i + 1, n - 1)]
        tang = (b - a).normalized()
        loc, sn, _fi, _d = hull.nearest(p)
        if (p - loc).dot(sn) < -0.002:
            sn = -sn
        side = tang.cross(sn).normalized()
        if side_hint is not None and side.dot(side_hint) < 0:
            side = -side
        hw = half_width(i / max(n - 1, 1)) if callable(half_width) else half_width
        ch = min(chamfer, 0.45 * hw)
        offs = [-1.0, -1.0 + ch / max(hw, 1e-5)]
        offs += [-1.0 + 2.0 * (j + 1) / (segs_across + 1) for j in range(segs_across)]
        offs += [1.0 - ch / max(hw, 1e-5), 1.0]
        lifts = [-0.0012, height] + [height] * segs_across + [height, -0.0012]
        if profile is not None:
            lifts = [lf * profile(o) if lf > 0 else lf for o, lf in zip(offs, lifts)]
        row = []
        for o, lift in zip(offs, lifts):
            q = p + side * (o * hw) + sn * cast_back
            hit = hull.cast(q, -sn, cast_back * 2)
            if hit[0] is None:
                pt = p + side * (o * hw) + sn * lift
            else:
                hn = hit[1] if hit[1].dot(sn) > 0 else -hit[1]
                pt = hit[0] + hn * lift
            row.append(m.add(pt, weights, anchor))
        rows.append(row)
        sns.append(sn)
        sides.append(side)
    pairs = list(zip(range(n - 1), range(1, n))) + ([(n - 1, 0)] if closed else [])
    last = len(rows[0]) - 2
    for ia, ib in pairs:
        ra, rb = rows[ia], rows[ib]
        for j in range(len(ra) - 1):
            q = (ra[j], ra[j + 1], rb[j + 1], rb[j])
            sn = sns[ia]
            if j == 0:
                out, mt = -sides[ia] + sn * 0.3, edge_mat or mat
            elif j == last:
                out, mt = sides[ia] + sn * 0.3, edge_mat or mat
            else:
                out, mt = sn, mat
            if newell(m.v, q).dot(out) < 0:
                q = tuple(reversed(q))
            m.f.append(q)
            m.m.append(mt)
    if end_caps and not closed:
        for ri, sgn in ((0, -1.0), (n - 1, 1.0)):
            row = rows[ri]
            t = path[min(ri + 1, n - 1)] - path[max(ri - 1, 0)]
            out = t.normalized() * sgn
            for j in range(len(row) - 2):
                q = (row[0], row[j + 1], row[j + 2])
                if newell(m.v, q).dot(out) < 0:
                    q = tuple(reversed(q))
                m.f.append(q)
                m.m.append(edge_mat or mat)
    return rows


def tube(m: Mesh, path: list[Vector], radius: float | Callable[[float], float], mat: str, sides: int = 6,
         up: Vector = UP, weights: Callable[[Vector, float], dict] | None = None, caps: bool = True) -> None:
    """Round tube along a path (cables, cords, piping)."""
    n = len(path)
    rings: list[list[int]] = []
    prev_side = None
    for i, p in enumerate(path):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, n - 1)]
        tang = (b - a).normalized()
        ref = up if abs(tang.dot(up)) < 0.95 else FWD
        side = tang.cross(ref).normalized()
        if prev_side is not None and side.dot(prev_side) < 0:
            side = -side
        prev_side = side
        up2 = side.cross(tang).normalized()
        r = radius(i / max(n - 1, 1)) if callable(radius) else radius
        t = i / max(n - 1, 1)
        ring = []
        for s in range(sides):
            ang = TAU * s / sides
            q = p + side * (r * math.cos(ang)) + up2 * (r * math.sin(ang))
            ring.append(m.add(q, weights(p, t) if weights is not None else None))
        rings.append(ring)
    for a, b in itertools.pairwise(rings):
        for s in range(sides):
            t2 = (s + 1) % sides
            m.f.append((a[s], a[t2], b[t2], b[s]))
            m.m.append(mat)
    if caps:
        for ring, rev in ((rings[0], True), (rings[-1], False)):
            for s in range(1, sides - 1):
                t = (ring[0], ring[s], ring[s + 1])
                m.f.append(tuple(reversed(t)) if rev else t)
                m.m.append(mat)


# =============================================================================================
# hard gear
# =============================================================================================
def surface_frame(hull: Hull, target: Vector, toward: Vector, up: Vector = UP, lift: float = 0.0,
                  reach: float = 0.3) -> tuple[Matrix, Vector]:
    """Frame on the hull surface hit by a ray from ``target + toward*reach`` back along ``-toward``.

    Local +Z = outward surface normal, +Y = ``up`` projected onto the surface, +X = Y x Z.
    Returns (matrix, surface point)."""
    toward = toward.normalized()
    hit = hull.cast(target + toward * reach, -toward, reach * 2)
    if hit[0] is None:
        loc, n = target, toward
    else:
        loc, n = hit[0], hit[1]
        if n.dot(toward) < 0:
            n = -n
    z = n.normalized()
    y = (up - z * up.dot(z))
    y = y.normalized() if y.length > 1e-6 else FWD.copy()
    x = y.cross(z).normalized()
    mtx = Matrix((
        (x.x, y.x, z.x, loc.x + z.x * lift),
        (x.y, y.y, z.y, loc.y + z.y * lift),
        (x.z, y.z, z.z, loc.z + z.z * lift),
        (0.0, 0.0, 0.0, 1.0),
    ))
    return mtx, loc


def frame_from(origin: Vector, z_axis: Vector, up: Vector = UP) -> Matrix:
    z = z_axis.normalized()
    y = up - z * up.dot(z)
    y = y.normalized() if y.length > 1e-6 else FWD.copy()
    x = y.cross(z).normalized()
    return Matrix(((x.x, y.x, z.x, origin.x), (x.y, y.y, z.y, origin.y), (x.z, y.z, z.z, origin.z), (0, 0, 0, 1)))


def ear_clip(pts: list[Vector], normal: Vector) -> list[tuple[int, int, int]]:
    """Deterministic ear-clipping triangulation of a simple planar polygon (any convexity)."""
    n = normal.normalized()
    ax = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
    u = n.cross(ax).normalized()
    v = n.cross(u)
    p2 = [(p.dot(u), p.dot(v)) for p in pts]
    area = sum(p2[i][0] * p2[(i + 1) % len(p2)][1] - p2[(i + 1) % len(p2)][0] * p2[i][1] for i in range(len(p2)))
    order = list(range(len(pts)))
    if area < 0:
        order.reverse()

    def cross2(a, b, c) -> float:
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def inside(p, a, b, c) -> bool:
        return cross2(a, b, p) > 1e-14 and cross2(b, c, p) > 1e-14 and cross2(c, a, p) > 1e-14

    tris = []
    guard = 0
    while len(order) > 3 and guard < 10000:
        guard += 1
        m = len(order)
        for i in range(m):
            ia, ib, ic = order[i - 1], order[i], order[(i + 1) % m]
            a, b, c = p2[ia], p2[ib], p2[ic]
            if cross2(a, b, c) <= 1e-14:
                continue
            if any(inside(p2[j], a, b, c) for j in order if j not in (ia, ib, ic)):
                continue
            tris.append((ia, ib, ic))
            order.pop(i)
            break
        else:
            ia, ib, ic = order[-1], order[0], order[1]   # degenerate leftovers: clip anyway
            tris.append((ia, ib, ic))
            order.pop(0)
    tris.append(tuple(order))
    return tris


class Gear:
    """Hard-surface builder: ``lib.geo.MeshBuilder`` primitives with material ids, bevelled, then
    converted to a ``Mesh``. Model in a local frame (+Z out of the surface, +Y up) and place it with
    ``to_mesh(matrix, anchor)``. Always bevel before UVs (UVs are projected on the final object).

    Determinism: every ``bevel()`` closes the current bmesh and later primitives go into a fresh one
    (bmesh reuses freed element slots in an unstable order after a bevel), faces are emitted in a
    canonical order, and n-gon caps are ear-clipped here instead of by Blender."""

    def __init__(self) -> None:
        from lib import geo

        self._geo = geo
        self.mb = geo.MeshBuilder()
        self.done: list = []
        self.ids: list[str] = []

    def _mat(self, mat_id: str) -> int:
        if mat_id not in self.ids:
            self.ids.append(mat_id)
        idx = self.ids.index(mat_id)
        while len(self.mb.materials) <= idx:
            self.mb.materials.append(None)
        return idx

    def box(self, lo, hi, mat: str) -> Gear:
        self.mb.box(lo, hi, mat=self._mat(mat))
        return self

    def cyl(self, r: float, depth: float, centre=(0, 0, 0), axis: str = "Z", segs: int = 12, mat: str = "") -> Gear:
        self.mb.cylinder(r, depth, segments=segs, centre=centre, axis=axis, mat=self._mat(mat))
        return self

    def prism(self, outline, z0: float, z1: float, mat: str, cap_mat: str | None = None) -> Gear:
        """Extrude an (x, y) outline from z0 to z1 (local +Z out of the surface)."""
        self.mb.prism(outline, axis="Z", start=z0, end=z1, mat=self._mat(mat),
                      cap_mat=self._mat(cap_mat) if cap_mat else None)
        return self

    def bevel(self, width: float = 0.002, segments: int = 1, angle_deg: float = 30.0) -> Gear:
        self.mb.bevel(width, segments, angle_deg)
        self.done.append(self.mb)
        self.mb = self._geo.MeshBuilder()
        return self

    def to_mesh(self, mtx: Matrix, anchor: Vector | None = None, weights: dict | None = None) -> Mesh:
        out = Mesh()
        rot = mtx.to_3x3()
        for mb in self.done + [self.mb]:
            bm = mb.bm
            bm.verts.index_update()
            bm.faces.index_update()
            bm.verts.ensure_lookup_table()
            bm.normal_update()
            off = len(out.v)
            for v in bm.verts:
                out.add(mtx @ v.co, weights, anchor)
            faces = []
            for f in bm.faces:
                idx = [v.index for v in f.verts]
                k0 = idx.index(min(idx))
                idx = idx[k0:] + idx[:k0]
                faces.append((sorted(idx), idx, f.material_index, f.normal.copy()))
            faces.sort(key=lambda t: (t[0], t[1]))
            for _key, idx, mi, fn in faces:
                mat = self.ids[mi]
                if len(idx) <= 4:
                    out.face([i + off for i in idx], mat)
                    continue
                for tri in ear_clip([bm.verts[i].co.copy() for i in idx], fn):
                    t = [idx[j] + off for j in tri]
                    if newell(out.v, t).dot(rot @ fn) < 0:
                        t.reverse()
                    out.face(t, mat)
            bm.free()
        return out


# =============================================================================================
# Blender objects
# =============================================================================================
def material(ctx, mat_id: str):
    h, r, met = palette.spec(mat_id)
    return ctx.material(mat_id, h, roughness=r, metallic=met)


def resolve_weights(fit: Fit, m: Mesh) -> list[dict[str, float]]:
    cache: dict[tuple, dict] = {}
    out = []
    for p, w, a in zip(m.v, m.w, m.a):
        if w is not None:
            out.append(w)
            continue
        q = a if a is not None else p
        key = (round(q.x, 7), round(q.y, 7), round(q.z, 7))
        if key not in cache:
            cache[key] = fit.weights_at(q)
        out.append(cache[key])
    return out


def make_object(ctx, fit: Fit, armature, name: str, m: Mesh, sharp_deg: float = 50.0, hard: bool = False):
    """Create a skinned mesh object from ``m`` under ``armature`` (UVs box-projected after all
    geometry is final; materials ``M_<id>`` from the palette)."""
    import bmesh
    import bpy
    from lib import scene, uv

    ngons = sum(1 for f in m.f if len(f) > 4)
    if ngons:
        raise ValueError(f"{name}: {ngons} n-gons (triangulate them deterministically before export)")
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in m.v], [], [tuple(f) for f in m.f])
    order = sorted(set(m.m))
    for mid in order:
        me.materials.append(material(ctx, mid))
    idx = {mid: i for i, mid in enumerate(order)}
    me.polygons.foreach_set("material_index", [idx[x] for x in m.m])
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    uv.box_project(bm, density=512.0, texture_px=1024.0)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    if sharp_deg is not None:
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    me.validate(clean_customdata=False)
    me.update()
    obj = bpy.data.objects.new(name, me)
    scene.link(obj, armature)
    apply_weights(obj, armature, resolve_weights(fit, m))
    _tri.triangulate(obj)
    return obj


def apply_weights(obj, armature, weights: list[dict[str, float]]) -> None:
    groups = {}
    for b in rig.BONES:
        if b == "root":
            continue
        groups[b] = obj.vertex_groups.new(name=b)
    per_bone: dict[str, list[tuple[int, float]]] = {b: [] for b in groups}
    for vi, w in enumerate(weights):
        for b, x in sorted(w.items()):
            per_bone[b].append((vi, x))
    for b, grp in groups.items():
        for vi, x in per_bone[b]:
            grp.add([vi], x, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    mod.use_vertex_groups = True
    mod.use_bone_envelopes = False


def bake_body(objs: dict, data) -> None:
    """Replace the Body/Hair shape keys by the variant's blended positions (no morphs exported)."""
    import bpy

    del bpy
    for name in ("Body", "Hair"):
        obj = objs.get(name)
        if obj is None:
            continue
        me = obj.data
        if me.shape_keys is None:
            continue
        mix = [tuple(kb.co) for kb in me.shape_keys.key_blocks[0].data]
        # evaluate the mix of all keys at their values
        basis = me.shape_keys.key_blocks[0]
        acc = [list(c) for c in mix]
        for kb in me.shape_keys.key_blocks[1:]:
            val = kb.value
            if not val:
                continue
            for i, (d, b) in enumerate(zip(kb.data, basis.data)):
                acc[i][0] += val * (d.co.x - b.co.x)
                acc[i][1] += val * (d.co.y - b.co.y)
                acc[i][2] += val * (d.co.z - b.co.z)
        obj.shape_key_clear()
        me.vertices.foreach_set("co", [c for p in acc for c in p])
        me.update()
