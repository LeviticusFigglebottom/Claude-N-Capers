"""Gear and assembly helpers for the special enemies (P3, ``char_specials.py``). Blender only.

Private helper (``_`` prefix). Builds on ``_outfit`` / ``_gear_kit`` / ``_outfit_build`` without
changing them:

* ``build_special(ctx, recipe)`` wraps ``_outfit_build.build_character``: the recipe may add extra,
  separately named meshes to ``kit.extra`` (``Faceplate``, ``Visor``, ``HeadArmored``, ``Goggles``;
  they become skinned MeshInstance3D nodes of exactly that name under the Skeleton3D, 100 % ``head``),
  extra attach markers to ``kit.markers`` (``LaserOrigin``) and material overrides to
  ``kit.overrides`` (assembly sets ``material_override``); ``kit.opts["recolor"]`` remaps material ids
  on every mesh after the recipe (Aegis / Corpsman recolours of shared builds).
* Head pieces: ``head_dome`` (balaclava, bomb-suit hood, helmets) and ``curved_panel`` (visors,
  faceplates) are fitted to the head + hair by rays around ``Fit.head_centre()``.
* Body pieces: ``puffy_shell`` (thick bomb-suit shells, drape distance up to 14 cm), ``plate``
  (stacked raised patches = armour plates), ``helix`` (coiled cables), ``emblem`` (Corpsman mark).

Axes as in ``_outfit``: Blender +Z up, the character faces +Y (Godot -Z), right = +X (.R).
"""

from __future__ import annotations

import json
import math
from collections.abc import Callable

import _gear_kit as gk
import _outfit as o
from _outfit import Fit, Gear, Hull, Mesh, Vector, lerp, smoothstep
from _outfit_build import Kit, build_character

HEAD_W = {"head": 1.0}
UP = o.UP


# =============================================================================================
# assembly wrapper
# =============================================================================================
def _recolor(kit: Kit, table: dict[str, str]) -> None:
    for m in [kit.soft, kit.gear, kit.head, *kit.extra.values()]:
        m.m = [table.get(x, x) for x in m.m]


def build_special(ctx, recipe: Callable[[Kit], None]) -> None:
    """``build_character`` plus the special extras (see the module doc)."""
    import bpy

    holder: dict[str, Kit] = {}

    def wrapped(kit: Kit) -> None:
        kit.extra = {}
        kit.markers = []
        kit.overrides = {}
        holder["kit"] = kit
        recipe(kit)
        if kit.opts.get("recolor"):
            _recolor(kit, dict(kit.opts["recolor"]))

    build_character(ctx, wrapped)
    kit = holder["kit"]
    arm = bpy.data.objects["rig_humanoid"]
    tris = json.loads(ctx.source_extra["tris_by_mesh"])
    for name in sorted(kit.extra):
        m = kit.extra[name]
        if not m.f:
            continue
        o.make_object(ctx, kit.fit, arm, name, m, sharp_deg=40.0, hard=True)
        tris[name] = m.tris()
    ctx.source_extra["tris"] = sum(tris.values())
    ctx.source_extra["tris_by_mesh"] = json.dumps(tris, sort_keys=True)
    ctx.source_extra["meshes"] = ",".join(sorted(tris))
    if kit.markers:
        ctx.source_extra["extra_markers"] = json.dumps(kit.markers, sort_keys=True)
    if kit.overrides:
        ctx.source_extra["material_override"] = json.dumps(kit.overrides, sort_keys=True)


# =============================================================================================
# orientation helper
# =============================================================================================
def put(m: Mesh, idx, mat: str, outward: Vector) -> None:
    idx = tuple(idx)
    if o.newell(m.v, idx).dot(outward) < 0.0:
        idx = tuple(reversed(idx))
    m.f.append(idx)
    m.m.append(mat)


# =============================================================================================
# head pieces
# =============================================================================================
def head_radius(fit: Fit, az: float, el: float, c: Vector | None = None) -> float | None:
    """Distance from the head centre to the outermost head/hair surface along (az, el)."""
    c = c if c is not None else fit.head_centre()
    d = Vector((math.cos(el) * math.sin(az), math.cos(el) * math.cos(az), math.sin(el)))
    hit = fit.head_bvh.ray_cast(c + d * 0.4, -d, 0.4)
    return (0.4 - hit[3]) if hit[0] is not None else None


def head_dome(fit: Fit, mat: str | Callable[[Vector, float, float], str], gap: float | Callable[[float, float], float],
              el_min: float = -55.0, n_az: int = 32, n_el: int = 9, smooth: int = 2, neck: float | None = None,
              neck_mat: str | None = None, weights: dict | None = None) -> tuple[Mesh, list[list[int]]]:
    """Closed-top dome over head + hair (balaclava, hood, helmet shell): rings at elevations from
    ``el_min`` (deg) to 84 deg plus a pole, each point ``gap(az, el)`` outside the head along its ray.
    ``neck`` (radial gap, m) adds two rings down the neck (neck_top -> neck base) with body weights.
    ``mat(centre, az, el)`` per face. Returns (mesh, rings)."""
    k = fit.k
    c = fit.head_centre()
    w = weights if weights is not None else HEAD_W
    azs = [2 * math.pi * i / n_az for i in range(n_az)]
    els = [math.radians(lerp(el_min, 84.0, j / (n_el - 1))) for j in range(n_el)]
    m = Mesh()
    rings: list[list[int]] = []
    prev = [0.09 * k] * n_az
    for el in els:
        rs = []
        for i, az in enumerate(azs):
            r = head_radius(fit, az, el, c)
            r = prev[i] if r is None else r
            gg = gap(az, el) if callable(gap) else gap
            rs.append(r + gg * k)
        for _ in range(smooth):
            rs = [0.25 * rs[i - 1] + 0.5 * rs[i] + 0.25 * rs[(i + 1) % n_az] for i in range(n_az)]
        prev = rs
        pts = [c + Vector((math.cos(el) * math.sin(az), math.cos(el) * math.cos(az), math.sin(el))) * r
               for az, r in zip(azs, rs)]
        rings.append(m.ring(pts, w))
    top_r = (head_radius(fit, 0.0, math.radians(90.0), c) or 0.1 * k) + (gap(0.0, 1.57) if callable(gap) else gap) * k
    pole = m.add(c + Vector((0.0, 0.0, top_r)), w)

    def mt(f) -> str:
        if not callable(mat):
            return mat
        cc = sum((m.v[i] for i in f), Vector()) / len(f)
        dd = cc - c
        return mat(cc, math.atan2(dd.x, dd.y), math.atan2(dd.z, math.hypot(dd.x, dd.y)))

    for a_, b_ in zip(rings, rings[1:]):
        for j in range(n_az):
            jj = (j + 1) % n_az
            q = (a_[j], a_[jj], b_[jj], b_[j])
            cc = sum((m.v[i] for i in q), Vector()) / 4
            put(m, q, mt(q), cc - c)
    for j in range(n_az):
        q = (rings[-1][j], rings[-1][(j + 1) % n_az], pole)
        cc = sum((m.v[i] for i in q), Vector()) / 3
        put(m, q, mt(q), cc - c)
    if neck is not None:
        import _outfit_garments as g

        nk = g.Neck(fit)
        prev_ring = rings[0]
        for t in (0.75, 0.0):
            pts = [nk.point(az, t, neck * k) for az in azs]
            ring = m.ring(pts, None)
            for j in range(n_az):
                jj = (j + 1) % n_az
                q = (prev_ring[j], prev_ring[jj], ring[jj], ring[j])
                cc = sum((m.v[i] for i in q), Vector()) / 4
                ax = nk.axis(cc.z)
                put(m, q, neck_mat or (mat if not callable(mat) else mt(q)), Vector((cc.x - ax.x, cc.y - ax.y, 0.0)))
            prev_ring = ring
        rings.insert(0, prev_ring)
    return m, rings


def curved_panel(c: Vector, az0: float, az1: float, z0: float, z1: float, r_fn: Callable[[float, float], float],
                 thick: float, mat_fn: Callable[[float, float], str] | str, nu: int = 12, nv: int = 5,
                 weights: dict | None = None, side_mat: str | None = None) -> Mesh:
    """Solid panel on a surface of revolution around the vertical axis through ``c``: azimuth az0..az1
    (rad, 0 = front), height z0..z1, outer radius ``r_fn(az, z)``, ``thick`` inwards. ``mat_fn(u, v)``
    (u, v in 0..1 at the face centre) picks the outer-face material (trim, slits)."""
    w = weights if weights is not None else HEAD_W
    m = Mesh()

    def pt(u: float, v: float, inset: float) -> Vector:
        az = lerp(az0, az1, u)
        z = lerp(z0, z1, v)
        r = r_fn(az, z) - inset
        return Vector((c.x + r * math.sin(az), c.y + r * math.cos(az), z))

    outer = [[m.add(pt(i / nu, j / nv, 0.0), w) for i in range(nu + 1)] for j in range(nv + 1)]
    inner = [[m.add(pt(i / nu, j / nv, thick), w) for i in range(nu + 1)] for j in range(nv + 1)]
    smat = side_mat or (mat_fn if isinstance(mat_fn, str) else mat_fn(0.0, 0.0))
    for j in range(nv):
        for i in range(nu):
            u, v = (i + 0.5) / nu, (j + 0.5) / nv
            az = lerp(az0, az1, u)
            rad = Vector((math.sin(az), math.cos(az), 0.0))
            mo = mat_fn if isinstance(mat_fn, str) else mat_fn(u, v)
            put(m, (outer[j][i], outer[j][i + 1], outer[j + 1][i + 1], outer[j + 1][i]), mo, rad)
            put(m, (inner[j][i], inner[j][i + 1], inner[j + 1][i + 1], inner[j + 1][i]), smat, -rad)
    for j in range(nv):
        for i, sgn in ((0, -1.0), (nu, 1.0)):
            az = lerp(az0, az1, i / nu)
            tang = Vector((math.cos(az), -math.sin(az), 0.0)) * sgn
            put(m, (outer[j][i], outer[j + 1][i], inner[j + 1][i], inner[j][i]), smat, tang)
    for i in range(nu):
        for j, sgn in ((0, -1.0), (nv, 1.0)):
            put(m, (outer[j][i], outer[j][i + 1], inner[j][i + 1], inner[j][i]), smat, Vector((0, 0, sgn)))
    return m


def face_radius(fit: Fit, az: float, z: float, c: Vector | None = None) -> float:
    """Horizontal distance from the vertical axis through the head centre to the head/hair surface."""
    c = c if c is not None else fit.head_centre()
    d = Vector((math.sin(az), math.cos(az), 0.0))
    hit = fit.head_bvh.ray_cast(Vector((c.x, c.y, z)) + d * 0.4, -d, 0.4)
    return (0.4 - hit[3]) if hit[0] is not None else 0.0


def crown_rings(fit: Fit, zs: list[float], gap: float, n: int = 28, min_r: float = 0.0) -> list[list[Vector]]:
    """Horizontal rings around the head at heights ``zs`` (hats), ``gap`` outside the head/hair."""
    c = fit.head_centre()
    out = []
    for z in zs:
        rs = [max(face_radius(fit, 2 * math.pi * i / n, z, c), min_r) + gap for i in range(n)]
        for _ in range(3):
            rs = [0.25 * rs[i - 1] + 0.5 * rs[i] + 0.25 * rs[(i + 1) % n] for i in range(n)]
        out.append([Vector((c.x + r * math.sin(2 * math.pi * i / n), c.y + r * math.cos(2 * math.pi * i / n), z))
                    for i, r in enumerate(rs)])
    return out


def loft(m: Mesh, rings: list[list[Vector]], mat: str, centre: Vector, w: dict | None = None,
         cap_top: bool = False, inward: bool = False) -> list[list[int]]:
    """Bands between closed rings (outward = away from the vertical axis through ``centre``)."""
    ids = [m.ring(r, w) for r in rings]
    n = len(rings[0])
    for a_, b_ in zip(ids, ids[1:]):
        for j in range(n):
            jj = (j + 1) % n
            q = (a_[j], a_[jj], b_[jj], b_[j])
            cc = sum((m.v[i] for i in q), Vector()) / 4
            out = Vector((cc.x - centre.x, cc.y - centre.y, 0.0))
            put(m, q, mat, -out if inward else out)
    if cap_top:
        top = ids[-1]
        cc = sum((m.v[i] for i in top), Vector()) / n
        pole = m.add(cc, w)
        for j in range(n):
            put(m, (top[j], top[(j + 1) % n], pole), mat, UP)
    return ids


def cull_hidden(m: Mesh, upto_face: int, cover: Hull, dist: float = 0.07) -> int:
    """Delete faces ``< upto_face`` of ``m`` whose corners and centre all hit ``cover`` within ``dist``
    along the face normal (layers fully hidden under a coat). Unused vertices are dropped. Returns the
    number of faces removed."""
    keep_f = []
    for fi, f in enumerate(m.f):
        if fi >= upto_face:
            keep_f.append(fi)
            continue
        n = o.newell(m.v, f)
        if n.length < 1e-12:
            keep_f.append(fi)
            continue
        n.normalize()
        pts = [m.v[i] for i in f] + [sum((m.v[i] for i in f), Vector()) / len(f)]
        if all(cover.cast(p + n * 0.0005, n, dist)[0] is not None for p in pts):
            continue
        keep_f.append(fi)
    removed = len(m.f) - len(keep_f)
    used = sorted({i for fi in keep_f for i in m.f[fi]})
    remap = {old: new for new, old in enumerate(used)}
    m.v = [m.v[i] for i in used]
    m.w = [m.w[i] for i in used]
    m.a = [m.a[i] for i in used]
    m.f = [tuple(remap[i] for i in m.f[fi]) for fi in keep_f]
    m.m = [m.m[fi] for fi in keep_f]
    return removed


# =============================================================================================
# body pieces
# =============================================================================================
def puffy_shell(fit: Fit, mat: str | Callable[[Vector, str], str], keep: Callable[[str, Vector], bool],
                off: Callable[[Vector, str], float], hull: Hull | None = None, max_off: float = 0.14,
                iters: int = 4) -> o.Shell:
    """Thick suit shell (bomb suit): body faces where ``keep(region, centre)`` pushed out by
    ``off(p, region)`` along the normals, then draped (bridges grooves, stays clear of the body)."""
    faces = fit.faces_where(lambda r, c, _i: keep(r, c))
    sh = o.Shell(fit, faces, lambda p, _n, r: off(p, r), mat)
    o.drape(sh.mesh, hull or Hull(fit), 0.01 * fit.k, max_off=max_off, iters=iters)
    return sh


def plate(kit: Kit, origin: Vector, toward: Vector, w: float, h: float, layers: list[tuple[float, float, str]],
          up: Vector = UP, r: float = 0.02, anchor: Vector | None = None, rings: int = 3) -> Mesh:
    """Armour plate: stacked raised patches (``layers`` = (scale, height, mat), outer last) cast onto
    the current hull along ``-toward``; rigid to ``anchor`` if given (else cloth-like weights)."""
    k = kit.k
    m = Mesh()
    toward = toward.normalized()
    v = up - toward * up.dot(toward)
    v = v.normalized() if v.length > 1e-6 else Vector((0, 1, 0))
    u = v.cross(toward).normalized()
    for scale, height, mat in layers:
        hull = kit.hull(m)
        o.patch(m, hull, origin, u, v, o.rounded_rect(w * scale * k, h * scale * k, r * k, 3),
                height * k, mat, cast_dir=-toward, rings=rings, chamfer=0.006 * k, anchor=anchor)
    return m


def helix(m: Mesh, a: Vector, b: Vector, radius: float, turns: float, wire: float, mat: str, steps: int = 60) -> None:
    """Coiled cable around the segment a->b (forearm coils)."""
    axis = (b - a)
    ln = axis.length
    axis.normalize()
    ref = UP if abs(axis.dot(UP)) < 0.9 else Vector((0, 1, 0))
    s1 = axis.cross(ref).normalized()
    s2 = axis.cross(s1).normalized()
    pts = []
    for i in range(steps + 1):
        t = i / steps
        ang = 2 * math.pi * turns * t
        pts.append(a + axis * (ln * t) + (s1 * math.cos(ang) + s2 * math.sin(ang)) * radius)
    o.tube(m, pts, wire, mat, sides=5)


def limb_radius(hull: Hull, p: Vector, axis: Vector, n: int = 12) -> float:
    """Mean outer radius of a limb around ``p`` (rays inward from 0.3 m)."""
    axis = axis.normalized()
    ref = UP if abs(axis.dot(UP)) < 0.9 else Vector((0, 1, 0))
    s1 = axis.cross(ref).normalized()
    s2 = axis.cross(s1).normalized()
    acc = 0.0
    cnt = 0
    for i in range(n):
        a = 2 * math.pi * i / n
        d = s1 * math.cos(a) + s2 * math.sin(a)
        hit = hull.cast(p + d * 0.3, -d, 0.3)
        if hit[0] is not None:
            acc += 0.3 - hit[3]
            cnt += 1
    return acc / cnt if cnt else 0.05


def emblem(mtx, k: float, size: float = 0.03, disc: str = "char_medic_red", mark: str = "char_medic_white",
           anchor: Vector | None = None, weights: dict | None = None) -> Mesh:
    """Corpsman mark (original design, not the protected Red Cross emblem): a red disc carrying a
    white plus whose four arms end in round caps, framed by a thin white ring."""
    s = size * k
    g = Gear()
    g.cyl(s, 0.004 * k, centre=(0, 0, 0.002 * k), axis="Z", segs=20, mat=disc)
    g.cyl(s * 1.12, 0.002 * k, centre=(0, 0, 0.001 * k), axis="Z", segs=20, mat=mark)
    arm = 0.62 * s
    hw = 0.17 * s
    g.box((-arm, -hw, 0.003 * k), (arm, hw, 0.0055 * k), mark)
    g.box((-hw, -arm, 0.003 * k), (hw, arm, 0.0055 * k), mark)
    for x, y in ((arm, 0.0), (-arm, 0.0), (0.0, arm), (0.0, -arm)):
        g.cyl(hw, 0.0025 * k, centre=(x, y, 0.00425 * k), axis="Z", segs=10, mat=mark)
    return g.to_mesh(mtx, anchor=anchor, weights=weights)


def backpack(kit: Kit, w: float, h: float, d: float, z: float, mat: str, trim: str | None = None,
             lid: float = 0.03) -> tuple[Mesh, o.Matrix, Vector]:
    """Box pack on the back centred at height ``z`` (rigid to the chest). Returns (mesh, frame, anchor)."""
    k = kit.k
    hull = kit.hull()
    mtx, loc = o.surface_frame(hull, Vector((0.0, -0.3, z * k)), Vector((0, -1, 0)), up=UP)
    g = Gear()
    g.box((-w / 2 * k, -h / 2 * k, 0.0), (w / 2 * k, h / 2 * k, d * k), mat)
    g.box((-w / 2 * k - 0.004 * k, h / 2 * k - lid * k, -0.002 * k), (w / 2 * k + 0.004 * k, h / 2 * k + 0.006 * k,
          d * k + 0.006 * k), trim or mat)
    g.bevel(0.012 * k, 2, 30.0)
    return g.to_mesh(mtx, anchor=loc), mtx, loc


__all__ = ["HEAD_W", "backpack", "build_special", "crown_rings", "cull_hidden", "curved_panel", "emblem", "face_radius", "gk",
           "head_dome", "head_radius", "helix", "limb_radius", "loft", "plate", "puffy_shell", "put", "smoothstep"]
