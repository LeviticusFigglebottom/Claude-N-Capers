"""Garments and gear for the Ortega Fisheries Co-op gunmen (QC-36, ``char_cartel.py``). Blender only.

Private helper (``_`` prefix). Builds on ``_outfit`` / ``_outfit_garments`` / ``_gear_kit`` /
``_special_gear`` without changing them. Everything is plain work wear (no insignia, no uniform
parts) plus the gunman read: a sling across the chest, shell loops / a bandolier, and a slung
long gun on the back.

* Head: ``head_wrap`` (rings round the head between two elevation curves, fitted to head + hair by
  rays like ``_special_gear.head_dome``), used for the ``beanie`` (fisherman's watch cap with a
  turned-up cuff) and the ``gaiter_up`` (neck gaiter pulled over the nose); ``hood_up`` (hoodie
  hood with a face opening and drawstrings).
* Neck: ``neck_gaiter`` (bunched tube round the neck, worn down).
* Body: ``work_jacket`` (hip-length waxed dock jacket: zip, corduroy collar, flap pockets),
  ``bib_overalls`` (oilskin bib-and-brace over the sweater), ``cargo_pockets``, ``rubber_boots``
  (tall fishing boots over the trousers), ``fingerless_gloves``.
* Gear: ``sling`` (strap loop over one shoulder, across the chest and round the far hip),
  ``shell_row`` (shotgun shells in loops along a strap), ``slung_gun`` (a simplified, original
  pump-gun silhouette lying along the back strap, muzzle up behind the shoulder).

Axes as in ``_outfit``: Blender +Z up, the character faces +Y (Godot -Z), right = +X (.R).
"""

from __future__ import annotations

import itertools
import math
from collections.abc import Callable

import _outfit as o
import _outfit_garments as g
import _special_gear as sg
from _outfit import Fit, Hull, Mesh, Vector, clamp, lerp, smoothstep
from _outfit_build import Kit

UP = Vector((0.0, 0.0, 1.0))
TAU = 2.0 * math.pi
HEAD_W = sg.HEAD_W


def _front_hit(hull: Hull, x: float, z: float, fallback_y: float) -> Vector:
    hit = hull.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
    return hit[0] if hit[0] is not None else Vector((x, fallback_y, z))


def _back_hit(hull: Hull, x: float, z: float, fallback_y: float) -> Vector:
    hit = hull.cast(Vector((x, -0.6, z)), Vector((0, 1, 0)), 1.2)
    return hit[0] if hit[0] is not None else Vector((x, fallback_y, z))


# =============================================================================================
# head
# =============================================================================================
def head_wrap(fit: Fit, mat: str, el_lo: Callable[[float], float], el_hi: Callable[[float], float],
              rows: list[tuple[float, float]], n_az: int = 32, pole: bool = False, smooth: int = 2,
              neck: float | None = None, bottom_out: Vector | None = None) -> tuple[Mesh, list[list[int]]]:
    """Rings round the head (100 % ``head``): for each azimuth (0 = front, +x = right) the elevation
    runs from ``el_lo(az)`` to ``el_hi(az)`` (degrees about ``Fit.head_centre``); ``rows`` lists
    (t, gap) per ring, t in 0..1 along that span, gap in metres (before height scaling) outside the
    head/hair surface. ``pole`` closes the top. ``neck`` (radial gap) adds two rings down the neck
    with body weights. ``bottom_out`` orients the first band (an under-turn) instead of radially."""
    k = fit.k
    c = fit.head_centre()
    azs = [TAU * i / n_az for i in range(n_az)]
    m = Mesh()
    rings: list[list[int]] = []
    prev = [0.09 * k] * n_az
    for t, gap in rows:
        rs: list[float] = []
        dirs: list[Vector] = []
        for i, az in enumerate(azs):
            el = math.radians(lerp(el_lo(az), el_hi(az), t))
            d = Vector((math.cos(el) * math.sin(az), math.cos(el) * math.cos(az), math.sin(el)))
            r = sg.head_radius(fit, az, el, c)
            rs.append(prev[i] if r is None else r)
            dirs.append(d)
        for _ in range(smooth):
            rs = [0.25 * rs[i - 1] + 0.5 * rs[i] + 0.25 * rs[(i + 1) % n_az] for i in range(n_az)]
        prev = rs
        rings.append(m.ring([c + d * (r + gap * k) for d, r in zip(dirs, rs)], HEAD_W))
    for ri, (a_, b_) in enumerate(itertools.pairwise(rings)):
        for j in range(n_az):
            jj = (j + 1) % n_az
            q = (a_[j], a_[jj], b_[jj], b_[j])
            cc = sum((m.v[i] for i in q), Vector()) / 4
            out = bottom_out if (ri == 0 and bottom_out is not None) else cc - c
            sg.put(m, q, mat, out)
    if pole:
        top = rings[-1]
        pc = sum((m.v[i] for i in top), Vector()) / len(top)
        hit = sg.head_radius(fit, 0.0, math.radians(90.0), c)
        z_top = c.z + (hit if hit is not None else 0.1 * k) + rows[-1][1] * k
        pv = m.add(Vector((pc.x, pc.y, max(z_top, pc.z + 0.004 * k))), HEAD_W)
        for j in range(n_az):
            q = (top[j], top[(j + 1) % n_az], pv)
            cc = sum((m.v[i] for i in q), Vector()) / 3
            sg.put(m, q, mat, cc - c)
    if neck is not None:
        nk = g.Neck(fit)
        prev_ring = rings[0]
        for tt in (0.75, 0.0):
            ring = m.ring([nk.point(az, tt, neck * k) for az in azs], None)
            for j in range(n_az):
                jj = (j + 1) % n_az
                q = (prev_ring[j], prev_ring[jj], ring[jj], ring[j])
                cc = sum((m.v[i] for i in q), Vector()) / 4
                ax = nk.axis(cc.z)
                sg.put(m, q, mat, Vector((cc.x - ax.x, cc.y - ax.y, 0.0)))
            prev_ring = ring
        rings.insert(0, prev_ring)
    return m, rings


def _back_blend(az: float) -> float:
    """0 at the front, 1 at the back."""
    return 0.5 * (1.0 - math.cos(az))


def beanie(fit: Fit, mat: str, front_el: float = 9.0, back_el: float = -14.0, cuff: float = 0.18,
           slouch: float = 0.012) -> Mesh:
    """Fisherman's watch cap: a knit dome sitting above the brows at the front and over the top of
    the ears / the nape at the back, a turned-up cuff band (``cuff`` of the height) standing proud
    by 7 mm, a little crown slouch, and an under-turn closing the bottom edge."""
    def el_lo(az: float) -> float:
        return lerp(front_el, back_el, _back_blend(az) ** 0.8)

    def el_hi(_az: float) -> float:
        return 84.0

    base = 0.008
    rows = [(0.0, 0.0012), (0.0, base + 0.004), (0.02, base + 0.007), (cuff, base + 0.007), (cuff + 0.012, base),
            (cuff + 0.12, base + slouch * 0.25), (0.48, base + slouch * 0.5), (0.64, base + slouch * 0.75),
            (0.80, base + slouch * 0.95), (0.92, base + slouch)]
    m, _r = head_wrap(fit, mat, el_lo, el_hi, rows, n_az=32, pole=True, smooth=3, bottom_out=Vector((0, 0, -1)))
    return m


def gaiter_up(fit: Fit, mat: str) -> Mesh:
    """Neck gaiter pulled up over the nose: a knit tube from the neck base over chin and mouth to
    the bridge of the nose, rising behind to the occiput. Hem on the top edge."""
    k = fit.k

    def el_lo(_az: float) -> float:
        return -64.0

    def el_hi(az: float) -> float:
        return lerp(-23.0, 2.0, _back_blend(az))

    rows = [(t, 0.0065 + 0.004 * (1.0 - t)) for t in (0.0, 0.2, 0.4, 0.6, 0.8, 0.92, 1.0)]
    m, _r = head_wrap(fit, mat, el_lo, el_hi, rows, n_az=28, smooth=2, neck=0.012)
    o.hem_all(m, thick=0.003 * k, depth=0.010 * k)
    return m


def hood_up(fit: Fit, mat: str, cord_mat: str | None = None) -> Mesh:
    """Hoodie hood worn up: a roomy dome over the head (volume at the crown and the back where the
    cloth hangs), down the neck into the hoodie's neckline, an oval face opening with a hem, and two
    drawstrings hanging from the opening."""
    k = fit.k
    eye = fit.eye_centre()
    c = fit.head_centre()

    def gap(az: float, el: float) -> float:
        back = smoothstep(0.2, -0.9, math.cos(az))
        return 0.020 + 0.012 * smoothstep(0.1, 1.3, el) + 0.022 * back * smoothstep(-0.9, 0.4, el)

    hood, _r = sg.head_dome(fit, mat, gap, el_min=-58.0, n_az=32, n_el=10, smooth=3, neck=0.030)
    brow = eye.z + 0.050 * k
    chin = eye.z - 0.135 * k
    zc = 0.5 * (brow + chin)
    hz = 0.5 * (brow - chin) + 0.01 * k

    def opening(cc: Vector) -> bool:
        az = math.atan2(cc.x - c.x, cc.y - c.y)
        u = (cc.z - zc) / hz
        if abs(u) >= 1.0:
            return False
        return abs(az) < math.radians(56.0) * math.sqrt(1.0 - u * u) + math.radians(6.0)

    g.delete_faces(hood, opening)
    o.hem_all(hood, thick=0.007 * k, depth=0.022 * k)
    hh = Hull(fit, [hood], body_regions=set())
    for sx in (-1.0, 1.0):
        top = None
        for dz in range(0, 20):
            z = chin - 0.06 * k + dz * 0.004 * k
            hit = hh.cast(Vector((sx * 0.05 * k, c.y + 0.4, z)), Vector((0, -1, 0)), 0.8)
            if hit[0] is not None and hit[0].y > c.y + 0.04 * k:
                top = hit[0]
            elif top is not None:
                break
        if top is None:
            continue
        pts = [top + Vector((0.0, 0.006 * k, 0.0)), top + Vector((sx * 0.004 * k, 0.012 * k, -0.06 * k)),
               top + Vector((sx * 0.006 * k, 0.020 * k, -0.13 * k))]
        o.tube(hood, pts, 0.0032 * k, cord_mat or mat, sides=5)
    return hood


def neck_gaiter(kit: Kit, mat: str, t0: float = 0.05, t1: float = 0.85, radial: float = 0.013,
                folds: int = 3) -> Mesh:
    """A neck gaiter / bandana tube worn down round the neck, bunched in ``folds`` soft rolls."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    n = 28
    rows = 2 * folds + 1
    m = Mesh()
    rings = []
    for j in range(rows):
        t = lerp(t0, t1, j / (rows - 1))
        bulge = 0.006 * k * (1.0 if j % 2 else 0.0)
        flare = 0.004 * k * (1.0 - j / (rows - 1))
        rings.append(m.ring([nk.point(TAU * i / n, t, radial * k + bulge + flare) for i in range(n)]))
    for a_, b_ in itertools.pairwise(rings):
        for i in range(n):
            ii = (i + 1) % n
            q = (a_[i], a_[ii], b_[ii], b_[i])
            cc = sum((m.v[v] for v in q), Vector()) / 4
            ax = nk.axis(cc.z)
            sg.put(m, q, mat, Vector((cc.x - ax.x, cc.y - ax.y, 0.0)))
    o.hem_all(m, thick=0.003 * k, depth=0.010 * k)
    kit.add_soft(m)
    return m


# =============================================================================================
# body garments
# =============================================================================================
def work_jacket(kit: Kit, mat: str, collar_mat: str, hem_z: float, v_z: float, neck_w: float = 0.055,
                base: float = 0.016, zip_mat: str = "chrome", button_mat: str = "char_button_dark") -> Mesh:
    """Hip-length waxed dock jacket: a roomy shell (extra over the shoulders) lofted straight past the
    hips to ``hem_z``, zipped to ``v_z`` with a small open V, a turned-down corduroy collar, two
    flapped bellows pockets on the hips and a flapped chest pocket, straight cuffs."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    hips = fit.ring_centre("hips")
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y

    def extra(p: Vector, r: str) -> float:
        d = 0.003 * k
        if r in ("torso", "neck"):
            for sfx in ("L", "R"):
                shp = Vector(fit.J[f"shoulder.{sfx}"])
                dd = (p - shp - Vector((0, 0, 0.04 * k))).length
                d += 0.006 * k * smoothstep(0.11 * k, 0.03 * k, dd)
        return d

    sh = g.upper_shell(fit, mat, bottom_z=hips.z, sleeve=1.93, base=base, waist_blouse=0.0, arm_ease=2.4,
                       hull=hull, min_off=0.008 * k, iters=6, extra=extra)
    m = sh.mesh
    loops = g.classify_loops(m)
    bottom = loops["hem"]
    o.straighten_loop(m, bottom, iters=3)
    for v in bottom:
        m.v[v] = Vector((m.v[v].x, m.v[v].y, hips.z))
    for key in ("cuff.L", "cuff.R"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=2)
    rows = max(2, int((hips.z - hem_z) / (0.035 * k)))
    o.loft_down(m, bottom, lambda th: hem_z, hull, rows, clearance=0.014 * k, flare=0.05, centre=hips,
                weights=o.skirt_weights(fit, hips.z, hem_z, 0.45, 0.11), keep_shape=0.6)

    def v_half(z: float) -> float:
        t = clamp((z - v_z) / max(neck_z - v_z, 1e-3), 0.0, 1.0)
        return lerp(0.004 * k, neck_w * k, t ** 0.9)

    g.delete_faces(m, lambda cc: cc.y > cy and cc.z >= v_z and abs(cc.x) < v_half(cc.z) and cc.z < neck_z + 0.08)
    g.snap_opening(m, v_half, cy, v_z, neck_z + 0.02, hull, 0.006 * k)
    mh = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        lp = g.classify_loops(m).get(key)
        if lp:
            g.cuff_band(m, lp, mh, 0.05 * k, 0.003 * k, mat)
    o.hem_all(m, thick=0.006 * k, depth=0.018 * k)
    kit.add_soft(m)
    jh = Hull(fit, [m])
    # zip placket from the V to the hem, pull at the top
    zp = Mesh()
    path = g.front_path(jh, 0.0, v_z + 0.004 * k, hem_z + 0.006 * k, step=0.02 * k)
    o.strip(zp, jh, path, 0.011 * k, 0.004 * k, mat, segs_across=1, chamfer=0.002 * k)
    kit.add_soft(zp)
    zh = Hull(fit, [m, zp])
    teeth = Mesh()
    path = g.front_path(zh, 0.0, v_z + 0.004 * k, hem_z + 0.012 * k, step=0.02 * k)
    o.strip(teeth, zh, path, 0.0035 * k, 0.0015 * k, zip_mat, segs_across=1, chamfer=0.0008 * k)
    kit.add_gear(teeth)
    pull = o.Gear()
    pull.box((-0.006 * k, -0.018 * k, 0.0), (0.006 * k, 0.004 * k, 0.004 * k), zip_mat)
    pull.bevel(0.0015 * k, 1, 30.0)
    pp = _front_hit(zh, 0.0, v_z - 0.006 * k, cy + 0.15 * k)
    kit.add_gear(pull.to_mesh(o.frame_from(pp, Vector((0.0, 1.0, 0.1))), anchor=pp))
    # turned-down corduroy collar: short points along the V, a band round the back of the neck
    col = Mesh()
    for sx in (-1.0, 1.0):
        pts = []
        for i in range(6):
            t = i / 5
            z = lerp(v_z + 0.010 * k, neck_z - 0.004 * k, t)
            pts.append(_front_hit(jh, sx * (v_half(z) + 0.020 * k), z, cy + 0.12 * k))
        o.strip(col, jh, pts, lambda t: lerp(0.014, 0.026, smoothstep(0.0, 0.7, t)) * k, 0.007 * k, collar_mat,
                side_hint=Vector((sx, 0, 0)), segs_across=2, chamfer=0.003 * k)
    back = [nk.point(th, 0.05, 0.022 * k) - Vector((0.0, 0.0, 0.010 * k))
            for th in [lerp(0.55, TAU - 0.55, i / 20) for i in range(21)]]
    o.strip(col, kit.hull(), back, 0.030 * k, 0.008 * k, collar_mat, side_hint=UP, segs_across=2,
            chamfer=0.004 * k, cast_back=0.06)
    kit.add_soft(col)
    # flapped bellows pockets on the hips + a chest pocket (left), flap snaps
    jh = kit.hull()
    pk = Mesh()
    snaps: list[Vector] = []
    for sx in (-1.0, 1.0):
        pz = hem_z + 0.10 * k
        o.patch(pk, jh, Vector((sx * 0.105 * k, 0.0, pz)), Vector((1, 0, 0)), UP,
                o.rounded_rect(0.13 * k, 0.12 * k, 0.010 * k, 2), 0.007 * k, mat,
                cast_dir=Vector((0.3 * sx, -1, 0)), rings=2, chamfer=0.004 * k)
        o.patch(pk, jh, Vector((sx * 0.105 * k, 0.0, pz + 0.068 * k)), Vector((1, 0, 0)), UP,
                o.rounded_rect(0.14 * k, 0.045 * k, 0.006 * k, 2), 0.011 * k, mat,
                cast_dir=Vector((0.3 * sx, -1, 0)), rings=1, chamfer=0.003 * k)
        snaps.append(Vector((sx * 0.105 * k, 0.0, pz + 0.058 * k)))
    o.patch(pk, jh, Vector((-0.095 * k, 0.0, 1.30 * k)), Vector((1, 0, 0)), UP,
            o.rounded_rect(0.10 * k, 0.11 * k, 0.008 * k, 2), 0.005 * k, mat,
            cast_dir=Vector((-0.15, -1, 0)), rings=1, chamfer=0.003 * k)
    o.patch(pk, jh, Vector((-0.095 * k, 0.0, 1.355 * k)), Vector((1, 0, 0)), UP,
            o.rounded_rect(0.11 * k, 0.035 * k, 0.005 * k, 2), 0.009 * k, mat,
            cast_dir=Vector((-0.15, -1, 0)), rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)
    ph = kit.hull()
    snap_mesh = Mesh()
    for p in snaps + [Vector((-0.095 * k, 0.0, 1.348 * k))]:
        hit = ph.cast(Vector((p.x, 0.6, p.z)), Vector((0, -1, 0)), 1.2)
        if hit[0] is None:
            continue
        gp = o.Gear()
        gp.cyl(0.0065 * k, 0.003 * k, centre=(0, 0, 0.0015 * k), axis="Z", segs=10, mat=button_mat)
        gp.bevel(0.001 * k, 1, 30.0)
        n = hit[1] if hit[1].y > 0 else -hit[1]
        snap_mesh.extend(gp.to_mesh(o.frame_from(hit[0], n), anchor=hit[0]))
    kit.add_gear(snap_mesh, layer=False)
    return m


def cargo_pockets(kit: Kit, tr: Mesh, mat: str, z: float = 0.60, flap_mat: str | None = None) -> None:
    """Flapped cargo pockets on the outer thighs."""
    fit, k = kit.fit, kit.k
    th = Hull(fit, [tr], body_regions=set())
    pk = Mesh()
    for sx in (-1.0, 1.0):
        knee = Vector(fit.J[f"knee.{'R' if sx > 0 else 'L'}"])
        org = Vector((sx * 0.4, knee.y - 0.008 * k, z * k))
        o.patch(pk, th, org, Vector((0, 1, 0)), UP, o.rounded_rect(0.095 * k, 0.14 * k, 0.010 * k, 2),
                0.008 * k, mat, cast_dir=Vector((-sx, 0, 0)), rings=2, chamfer=0.004 * k)
        o.patch(pk, th, org + Vector((0.0, 0.0, 0.08 * k)), Vector((0, 1, 0)), UP,
                o.rounded_rect(0.10 * k, 0.04 * k, 0.006 * k, 2), 0.012 * k, flap_mat or mat,
                cast_dir=Vector((-sx, 0, 0)), rings=1, chamfer=0.003 * k)
    kit.add_soft(pk)


def rubber_boots(kit: Kit, tr: Mesh, mat: str, sole_mat: str = "rubber_black", top_z: float = 0.36,
                 flare: float = 0.010) -> Mesh:
    """Tall rubber fishing boots worn over the trousers: a boot shell whose shaft is pushed radially
    out over the trouser leg (and flared towards the top), then the trouser faces hidden inside the
    shaft are dropped (tri budget; no hems needed). Call before ``kit.add_soft(tr)``."""
    fit, k = kit.fit, kit.k
    boots = g.shoes(fit, mat, sole_mat, top_z=top_z, base=0.0075, boot=True, toe=0.012, toe_h=0.05)
    th = Hull(fit, [tr], body_regions=set())
    z0, z1 = 0.10 * k, 0.17 * k
    for sfx in ("L", "R"):
        kc = fit.ring_centre(f"knee.{sfx}")
        ac = fit.ring_centre(f"ankle.{sfx}")
        axis = (kc - ac).normalized()
        for i, p in enumerate(boots.v):
            if (p.x > 0) != (sfx == "R") or p.z < z0:
                continue
            foot = ac + axis * (p - ac).dot(axis)
            rv = p - foot
            rr = rv.length
            if rr < 1e-6:
                continue
            d = rv / rr
            hit = th.cast(foot, d, 0.3)
            r_tr = (hit[0] - foot).length if hit[0] is not None else rr
            target = max(rr, r_tr + 0.007 * k) + flare * k * smoothstep(top_z * k - 0.14 * k, top_z * k, p.z)
            w = smoothstep(z0, z1, p.z)
            boots.v[i] = foot + d * lerp(rr, target, w)
    cut = top_z * k - 0.035 * k
    g.delete_faces(tr, lambda cc: cc.z < cut)
    kit.add_soft(boots)
    return boots


def fingerless_gloves(kit: Kit, mat: str, cuff_len: float = 0.055) -> Mesh:
    """Work gloves with the fingers cut off at the middle joints (faces whose dominant bone is a
    finger's 2nd/3rd phalanx are removed) and the cut edges hemmed."""
    fit, k = kit.fit, kit.k
    m = g.gloves(fit, mat, cuff_len=cuff_len, base=0.0028, cuff_off=0.005)

    def dist(cc: Vector) -> bool:
        w = fit.weights_at(cc)
        bone = max(sorted(w.items()), key=lambda kv: kv[1])[0]
        return bone.split(".")[0].endswith(("_02", "_03"))

    g.delete_faces(m, dist)
    wrists = [Vector(fit.J["wrist.L"]), Vector(fit.J["wrist.R"])]

    def at_wrist(loop: list[int]) -> bool:
        c = o.loop_centre(m, loop)
        return min((c - w).length for w in wrists) < 0.07 * k and c.z > min(w.z for w in wrists) - 0.01 * k

    o.hem_all(m, thick=0.0025 * k, depth=0.006 * k, skip=at_wrist)
    kit.add_soft(m)
    return m


def bib_overalls(kit: Kit, mat: str, top_z: float, waist_z: float, buckle_mat: str = "chrome",
                 hem_r: float = 0.066) -> tuple[Mesh, Mesh]:
    """Oilskin bib-and-brace overalls: loose trousers up to ``waist_z``, a bib panel over the chest
    up to ``top_z`` (cast on whatever is under it), a bib pocket, and braces over both shoulders
    down to the back waistband, buckled at the bib corners. Returns (trousers, bib) meshes; the
    trousers are NOT added (``rubber_boots`` trims them first)."""
    fit, k = kit.fit, kit.k
    tr = g.trousers(fit, mat, waist_z, hem_r=hem_r, base=0.010, hull=kit.hull(), seat=0.006)
    tl = g.classify_loops(tr.mesh)
    o.straighten_loop(tr.mesh, tl["top"], iters=3)
    o.hem_all(tr.mesh, thick=0.005 * k, depth=0.014 * k)
    hull = kit.hull(tr.mesh)
    m = Mesh()
    nj, ni = 9, 10
    z_bot = waist_z - 0.065 * k
    grid: list[list[int]] = []
    for j in range(nj + 1):
        z = lerp(top_z, z_bot, j / nj)
        hw = lerp(0.115, 0.15, smoothstep(top_z, z_bot, z)) * k
        row = []
        for i in range(ni + 1):
            x = lerp(-hw, hw, i / ni)
            hit = hull.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
            y = hit[0].y + 0.006 * k if hit[0] is not None else 0.1 * k
            row.append(m.add(Vector((x, y, z))))
        grid.append(row)
    for a, b in itertools.pairwise(grid):
        for i in range(ni):
            m.face((a[i], a[i + 1], b[i + 1], b[i]), mat, inside=Vector((0.0, -0.2, 1.0)))
    o.hem_all(m, thick=0.004 * k, depth=0.012 * k)
    corners = [m.v[grid[0][0]].copy(), m.v[grid[0][ni]].copy()]
    bh = Hull(fit, [m])
    o.patch(m, bh, Vector((0.0, 0.0, lerp(top_z, z_bot, 0.35))), Vector((1, 0, 0)), UP,
            o.rounded_rect(0.13 * k, 0.10 * k, 0.008 * k, 2), 0.004 * k, mat, cast_dir=Vector((0, -1, 0)),
            rings=1, chamfer=0.003 * k)
    hull = kit.hull(tr.mesh, m)
    cy = fit.ring_centre("chest").y
    braces = Mesh()
    for corner in corners:
        sx = 1.0 if corner.x > 0 else -1.0
        shp = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        xs = sx * 0.11 * k
        pts = [corner + Vector((0.0, 0.0, 0.01 * k))]
        for i in range(1, 6):
            t = i / 6
            pts.append(_front_hit(hull, lerp(corner.x, xs, t), lerp(corner.z, shp.z + 0.01 * k, t), cy + 0.1 * k))
        for i in range(1, 5):
            yy = lerp(cy + 0.06 * k, cy - 0.07 * k, i / 5)
            hit = hull.cast(Vector((xs, yy, shp.z + 0.5)), Vector((0, 0, -1)), 1.0)
            pts.append(hit[0] if hit[0] is not None else Vector((xs, yy, shp.z + 0.06 * k)))
        for i in range(0, 8):
            t = i / 7
            pts.append(_back_hit(hull, lerp(xs, sx * 0.075 * k, t), lerp(shp.z - 0.02 * k, waist_z - 0.02 * k, t),
                                 cy - 0.15 * k))
        o.strip(braces, hull, pts, 0.016 * k, 0.003 * k, mat, segs_across=1, chamfer=0.0015 * k)
    kit.add_soft(m)
    kit.add_soft(braces)
    gear = Mesh()
    for corner in corners:
        gp = o.Gear()
        gp.box((-0.016 * k, -0.012 * k, 0.0), (0.016 * k, 0.012 * k, 0.004 * k), buckle_mat)
        gp.box((-0.006 * k, -0.004 * k, 0.003 * k), (0.006 * k, 0.004 * k, 0.006 * k), buckle_mat)
        gp.bevel(0.0015 * k, 1, 30.0)
        p = corner + Vector((0.0, 0.003 * k, 0.012 * k))
        gear.extend(gp.to_mesh(o.frame_from(p, Vector((0.0, 1.0, 0.15))), anchor=p))
    kit.add_gear(gear, layer=False)
    return tr.mesh, m


# =============================================================================================
# gear: sling, shells, slung gun
# =============================================================================================
class StrapLoop:
    """A strap loop over one shoulder (``side`` -1 = left, +1 = right), diagonally across the chest
    to the opposite hip, round that side of the waist and back up across the back. Segments are
    kept so gear can follow them: ``front`` (hip -> shoulder), ``back`` (shoulder -> hip)."""

    def __init__(self, kit: Kit, side: float, low_z: float, shoulder_in: float = 0.10, a_front: float = 48.0,
                 a_back: float = 132.0) -> None:
        fit, k = kit.fit, kit.k
        hull = kit.hull()
        self.hull = hull
        cy = fit.ring_centre("chest").y
        hips = fit.ring_centre("hips")
        shp = Vector(fit.J["shoulder.R" if side > 0 else "shoulder.L"])
        xs = side * shoulder_in * k
        zs = shp.z + 0.01 * k
        far = -side

        def side_pt(a_deg: float, z: float) -> Vector:
            # cast inwards from just outside the torso (the A-pose arms are further out)
            a = math.radians(a_deg) * far
            dv = Vector((math.sin(a), math.cos(a), 0.0))
            start = Vector((hips.x, hips.y, z)) + dv * (0.30 * k)
            hit = hull.cast(start, -dv, 0.30 * k)
            return hit[0] if hit[0] is not None else Vector((hips.x, hips.y, z)) + dv * (0.16 * k)

        pf = side_pt(a_front, low_z)
        pb = side_pt(a_back, low_z + 0.03 * k)
        n_d = 12
        self.front = [_front_hit(hull, lerp(pf.x, xs, i / n_d), lerp(pf.z, zs, i / n_d), cy + 0.12 * k)
                      for i in range(n_d + 1)]
        over = []
        for i in range(1, 5):
            yy = lerp(cy + 0.06 * k, cy - 0.07 * k, i / 5)
            hit = hull.cast(Vector((xs, yy, zs + 0.5)), Vector((0, 0, -1)), 1.0)
            over.append(hit[0] if hit[0] is not None else Vector((xs, yy, zs + 0.05 * k)))
        self.back = [_back_hit(hull, lerp(xs, pb.x, i / n_d), lerp(zs - 0.01 * k, pb.z, i / n_d), cy - 0.15 * k)
                     for i in range(n_d + 1)]
        around = [side_pt(lerp(a_back, a_front, i / 6), lerp(pb.z, pf.z, i / 6)) for i in range(1, 6)]
        self.path = self.front + over + self.back + around

    def build(self, kit: Kit, mat: str, half_w: float, height: float = 0.004) -> Mesh:
        k = kit.k
        m = Mesh()
        o.strip(m, self.hull, self.path, half_w * k, height * k, mat, segs_across=1, chamfer=0.0015 * k,
                closed=True, end_caps=False)
        kit.add_soft(m)
        return m


def _along(path: list[Vector], t: float) -> tuple[Vector, Vector]:
    """Point and unit tangent at fraction ``t`` of a polyline's length."""
    seg = [(a - b).length for a, b in itertools.pairwise(path)]
    total = sum(seg)
    s = t * total
    for (a, b), ln in zip(itertools.pairwise(path), seg):
        if s <= ln or ln == seg[-1]:
            f = clamp(s / max(ln, 1e-9), 0.0, 1.0)
            return a.lerp(b, f), (b - a).normalized()
        s -= ln
    return path[-1], (path[-1] - path[-2]).normalized()


def shell_row(kit: Kit, strap: Mesh, path: list[Vector], t0: float, t1: float, count: int, lift: float,
              hull_mat: str, base_mat: str = "brass") -> Mesh:
    """``count`` shotgun shells in loops across a strap between path fractions t0..t1 (rigid gear)."""
    fit, k = kit.fit, kit.k
    sh = Hull(fit, [strap], body_regions=set())
    out = Mesh()
    r = 0.0098 * k
    ln = 0.058 * k
    for i in range(count):
        p, tang = _along(path, lerp(t0, t1, (i + 0.5) / count))
        loc, n, _fi, _d = sh.nearest(p)
        if (p - loc).dot(n) < 0:
            n = -n
        across = tang.cross(n).normalized()
        if across.x < 0:
            across = -across
        c = loc + n * (lift * k + r * 0.8)
        gp = o.Gear()
        gp.cyl(r, ln, centre=(0, 0, 0.0), axis="Z", segs=8, mat=hull_mat)
        gp.cyl(r * 1.04, 0.012 * k, centre=(0, 0, ln * 0.5 - 0.004 * k), axis="Z", segs=8, mat=base_mat)
        gp.bevel(0.0012 * k, 1, 30.0)
        out.extend(gp.to_mesh(o.frame_from(c, across, up=n), anchor=loc))
        # the loop band over the shell (strap material)
        lp = o.Gear()
        lp.box((-r - 0.003 * k, -0.012 * k, -0.002 * k), (r + 0.003 * k, 0.012 * k, r * 1.9), "leather_dark")
        lp.bevel(0.002 * k, 1, 30.0)
        out.extend(lp.to_mesh(o.frame_from(loc + n * (lift * k), n, up=across), anchor=loc))
    kit.add_gear(out, layer=False)
    return out


def _gun_gear(k: float, wood: str, metal: str, poly: str) -> o.Gear:
    """Simplified original pump-gun silhouette in a local frame: +X towards the muzzle, +Y the top of
    the gun, +Z the thickness (out of the wearer's back). Origin near the balance point."""
    gp = o.Gear()
    half = 0.018 * k
    stock = [(-0.18, 0.022), (-0.30, 0.012), (-0.52, 0.030), (-0.52, -0.092), (-0.46, -0.090), (-0.30, -0.060),
             (-0.20, -0.050), (-0.18, -0.036)]
    gp.prism([(x * k, y * k) for x, y in stock], -half, half, wood)
    gp.bevel(0.004 * k, 1, 30.0)
    gp.box((-0.52 * k, -0.094 * k, -half - 0.002 * k), (-0.505 * k, 0.032 * k, half + 0.002 * k), poly)   # butt pad
    gp.box((-0.185 * k, -0.038 * k, -0.017 * k), (0.045 * k, 0.030 * k, 0.017 * k), metal)              # receiver
    gp.box((-0.12 * k, -0.062 * k, -0.005 * k), (-0.05 * k, -0.038 * k, 0.005 * k), metal)              # guard
    gp.bevel(0.003 * k, 1, 30.0)
    gp.cyl(0.0115 * k, 0.43 * k, centre=(0.255 * k, 0.014 * k, 0.0), axis="X", segs=10, mat=metal)     # barrel
    gp.cyl(0.0125 * k, 0.33 * k, centre=(0.205 * k, -0.014 * k, 0.0), axis="X", segs=10, mat=metal)    # mag tube
    gp.cyl(0.0215 * k, 0.17 * k, centre=(0.175 * k, -0.010 * k, 0.0), axis="X", segs=12, mat=wood)     # pump
    gp.bevel(0.002 * k, 1, 30.0)
    return gp


def slung_gun(kit: Kit, loop: StrapLoop, centre_z: float, wood: str, metal: str, poly: str = "polymer_black",
              stand_off: float = 0.026, tilt_deg: float = 21.0, centre_x: float = 0.04) -> dict:
    """The slung long gun on the back, lying along the strap's back segment, muzzle up behind the
    strap's shoulder (rigid ``Slung`` mesh on the chest, not a hull layer; ENV A hides it while seated). Returns
    placement info."""
    fit, k = kit.fit, kit.k
    back = loop.back
    hi, lo = back[0], back[-1]
    # steeper than the strap so the butt stays behind the hip, clear of the hanging arm; the muzzle
    # leans towards the strap's shoulder
    lean = -1.0 if hi.x < lo.x else 1.0
    tl = math.radians(tilt_deg)
    d = Vector((lean * math.sin(tl), 0.0, math.cos(tl)))
    p = _back_hit(loop.hull, lean * centre_x * k, centre_z * k, -0.15 * k)
    loc, n, _fi, _dd = loop.hull.nearest(p)
    if n.y > 0:
        n = -n
    n = Vector((n.x * 0.3, n.y, 0.0)).normalized()
    x_ax = (d - n * d.dot(n)).normalized()
    y_ax = n.cross(x_ax).normalized()
    origin = loc + n * (stand_off * k + 0.018 * k)
    from mathutils import Matrix

    mtx = Matrix(((x_ax.x, y_ax.x, n.x, origin.x), (x_ax.y, y_ax.y, n.y, origin.y),
                  (x_ax.z, y_ax.z, n.z, origin.z), (0, 0, 0, 1)))
    anchor = Vector((0.0, loc.y, 1.30 * k))
    gm = _gun_gear(k, wood, metal, poly).to_mesh(mtx, anchor=anchor)
    kit.add_slung(gm)
    muzzle = origin + x_ax * (0.47 * k)
    butt = origin - x_ax * (0.52 * k)
    return {"muzzle": muzzle, "butt": butt, "angle_from_vertical_deg": math.degrees(math.acos(clamp(x_ax.z, -1, 1)))}
