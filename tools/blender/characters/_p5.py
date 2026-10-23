"""Shared garments, gear and insignia for the P5 heist casts (D3-01: ``char_p5_gallery.py``,
``char_p5_bank.py``, ``char_p5_convoy.py``, ``char_p5_club.py``). Blender only.

Private helper (``_`` prefix). Builds on ``_outfit`` / ``_outfit_garments`` / ``_gear_kit`` /
``_npc`` / ``_cartel_gear`` / ``_faction`` without changing them. New pieces:

* ``letters``: block lettering with the shield glyphs plus V, U, Y, H, K (``_faction.letters``
  lacks them), stamped with ``_faction.stamp``.
* ``halberd`` / ``halberd_pin`` / ``halberd_crest``: the **Halberd Gallery** insignia (original): a
  gold halberd head (spear point, crescent axe blade, back spike) on a wine field.
* ``vaultline_mark`` / ``vaultline_patch``: the **Vaultline Armored Transport** insignia (original):
  an amber chevron "V" over a road bar on a dark brown field with an amber rim.
* ``ball_cap``: a six-panel crew cap (soft dome fitted to head + hair, a curved peak, a front badge).
* ``headphones_on``: over-ear DJ headphones worn on the head (band over the crown, cups on the ears).
* ``backpack``: a daypack on the back (shell, front pocket, top handle, two shoulder straps).
* ``carrier_vest``: an external soft ballistic vest over a uniform shirt (boxy front/back panels,
  side straps, a stand-off from the shirt, armholes and a scoop neck).

Axes as in ``_outfit``: Blender +Z up, the character faces +Y (Godot -Z), right = +X (.R).
"""

from __future__ import annotations

import math

import _cartel_gear as cgear
import _faction as faction
import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
import _special_gear as sg
from _outfit import Hull, Mesh, Vector, lerp, smoothstep
from _outfit_build import Kit
from _special_shield import GLYPHS

UP = Vector((0.0, 0.0, 1.0))
TAU = 2.0 * math.pi
HEAD_W = {"head": 1.0}

#: extra 3 x 5 block glyphs (same grid as ``_special_shield.GLYPHS``)
EXTRA_GLYPHS = {
    "V": [(0, 2, 1, 5), (2, 2, 3, 5), (1, 0, 2, 2)],
    "U": [(0, 0, 1, 5), (2, 0, 3, 5), (1, 0, 2, 1)],
    "Y": [(0, 3, 1, 5), (2, 3, 3, 5), (1, 0, 2, 3)],
    "H": [(0, 0, 1, 5), (2, 0, 3, 5), (1, 2, 2, 3)],
    "K": [(0, 0, 1, 5), (1, 2, 2, 3), (2, 3, 3, 5), (2, 0, 3, 2)],
    "P": [(0, 0, 1, 5), (1, 4, 2, 5), (2, 3, 3, 4), (1, 2, 2, 3)],  # D-145.3 POLICE (the R without its leg)
    # RT-G3 (the LEAD's review): the shared N (a block high in the middle column) read as M in VAULTLINE; a two-step
    # diagonal from the top left to the bottom right reads N
    "N": [(0, 0, 1, 5), (2, 0, 3, 5), (1, 2.6, 1.6, 4.2), (1.4, 0.8, 2, 2.8)],
}


def _rect(x0: float, y0: float, x1: float, y1: float) -> list[tuple[float, float]]:
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def _front_hit(hull: Hull, x: float, z: float, fallback_y: float) -> Vector:
    hit = hull.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
    return hit[0] if hit[0] is not None else Vector((x, fallback_y, z))


def _back_hit(hull: Hull, x: float, z: float, fallback_y: float) -> Vector:
    hit = hull.cast(Vector((x, -0.6, z)), Vector((0, 1, 0)), 1.2)
    return hit[0] if hit[0] is not None else Vector((x, fallback_y, z))


# =============================================================================================
# lettering and insignia
# =============================================================================================
def letters(word: str, h: float, mat: str, lift: float = 0.0022, bold: float = 0.0) -> list[faction.Item]:
    """Block letters ``h`` tall, centred on the origin (``_faction.letters`` + ``EXTRA_GLYPHS``); ``bold`` pads every
    stroke by that fraction of a stroke on each side (0 = the plain 1-unit strokes)."""
    u = h / 5.0
    pad = bold * u
    n = len(word)
    x0 = -(n * 3 + n - 1) * u / 2
    out: list[faction.Item] = []
    for ci, ch in enumerate(word):
        gx = x0 + ci * 4 * u
        for a, b, c, d in EXTRA_GLYPHS.get(ch) or GLYPHS[ch]:
            out.append((_rect(gx + a * u - pad, -h / 2 + b * u - pad, gx + c * u + pad, -h / 2 + d * u + pad), mat,
                        lift))
    return out


def stamp_back(kit: Kit, word: str, z: float, h: float, mat: str, bold: float = 0.0) -> None:
    """Lettering across the upper back at ``z`` (m before height scaling), ``h`` tall (``bold``: see ``letters``)."""
    fit, k = kit.fit, kit.k
    cy = fit.ring_centre("chest").y
    anchor = _back_hit(kit.hull(), 0.0, z * k, cy - 0.12 * k)
    m = Mesh()
    faction.stamp(m, kit.hull, anchor, Vector((0.0, -1.0, 0.0)), UP, [letters(word, h * k, mat, bold=bold)], anchor=anchor)
    kit.add_gear(m)


def halberd(h: float) -> list[list[tuple[float, float]]]:
    """Outlines of the Halberd Gallery mark ``h`` tall (centred): shaft, spear point, crescent axe
    blade on the left, back spike on the right."""
    s = h
    shaft = _rect(-0.045 * s, -0.50 * s, 0.045 * s, 0.30 * s)
    point = [(-0.075 * s, 0.28 * s), (0.075 * s, 0.28 * s), (0.0, 0.50 * s)]
    blade = [(-0.040 * s, 0.24 * s), (-0.20 * s, 0.30 * s), (-0.33 * s, 0.29 * s), (-0.38 * s, 0.18 * s),
             (-0.38 * s, 0.02 * s), (-0.33 * s, -0.08 * s), (-0.20 * s, -0.07 * s), (-0.040 * s, 0.0)]
    spike = [(0.040 * s, 0.20 * s), (0.27 * s, 0.13 * s), (0.040 * s, 0.07 * s)]
    return [shaft, point, blade, spike]


def halberd_pin(hull: Hull, p: Vector, k: float, metal: str = "brass", enamel: str = "char_gallery_wine",
                r: float = 0.011) -> Mesh:
    """Halberd Gallery staff pin: a round wine-enamel disc in a gold rim with the gold halberd."""
    mtx, loc = o.surface_frame(hull, p, Vector((0.0, 1.0, 0.15)), lift=0.0005)
    gr = o.Gear()
    rr = r * k
    gr.cyl(rr, 0.0022 * k, centre=(0.0, 0.0, 0.0011 * k), axis="Z", segs=16, mat=metal)
    gr.cyl(rr * 0.82, 0.0012 * k, centre=(0.0, 0.0, 0.0024 * k), axis="Z", segs=16, mat=enamel)
    gr.bevel(0.0004 * k, 1, 30.0)
    for outline in halberd(rr * 1.55):
        gr.prism(outline, 0.0026 * k, 0.0038 * k, metal)
    return gr.to_mesh(mtx, anchor=loc)


def halberd_crest(kit: Kit, x: float, z: float, w: float = 0.060, h: float = 0.070,
                  fill: str = "char_gallery_wine", rim: str = "brass") -> None:
    """Embroidered breast-pocket crest: a wine shield with a gold rim and the gold halberd."""
    fit, k = kit.fit, kit.k
    cy = fit.ring_centre("chest").y
    anchor = _front_hit(kit.hull(), x * k, z * k, cy + 0.12 * k)
    soft = Mesh()
    o.patch(soft, kit.hull(), anchor + Vector((0, 0.1, 0)), Vector((1, 0, 0)), UP,
            o.shield_outline(w * k, h * k), 0.0022 * k, fill, cast_dir=Vector((0, -1, 0)), rim_mat=rim, rings=2,
            chamfer=0.003 * k)
    kit.add_soft(soft)
    m = Mesh()
    items = [(outline, rim, 0.0012) for outline in halberd(0.62 * h * k)]
    shifted = [([(x_, y_ + 0.06 * h * k) for x_, y_ in ol], mt, lf) for ol, mt, lf in items]
    faction.stamp(m, kit.hull, anchor, Vector((0.0, 1.0, 0.0)), UP, [shifted], anchor=anchor)
    kit.add_gear(m)


def vaultline_mark(h: float, mat: str) -> list[faction.Item]:
    """Vaultline mark ``h`` tall: a chevron V (two slanted bars meeting at the bottom) over a road bar."""
    s = h
    lw = 0.13 * s
    out: list[faction.Item] = []
    for sx in (-1.0, 1.0):
        top_o, top_i = sx * 0.42 * s, sx * (0.42 * s - lw * 1.25)
        out.append(([(top_o, 0.50 * s), (top_i, 0.50 * s), (0.0, -0.10 * s), (sx * lw * 0.9, -0.22 * s)]
                    if sx < 0 else
                    [(top_i, 0.50 * s), (top_o, 0.50 * s), (sx * lw * 0.9, -0.22 * s), (0.0, -0.10 * s)], mat, 0.0012))
    out.append((_rect(-0.45 * s, -0.50 * s, -0.08 * s, -0.36 * s), mat, 0.0012))
    out.append((_rect(0.08 * s, -0.50 * s, 0.45 * s, -0.36 * s), mat, 0.0012))
    return out


def vaultline_patch(kit: Kit, anchor_fn, toward: Vector, up: Vector, w: float, h: float,
                    fill: str = "char_vl_trousers", rim: str = "char_vl_amber") -> None:
    """A rounded-rect patch (amber rim, brown fill) with the amber Vaultline mark, stamped as Gear."""
    k = kit.k
    anchor = anchor_fn()
    m = Mesh()
    levels = [[(o.rounded_rect(w * k, h * k, 0.16 * w * k, 1), rim, 0.0020)],
              [(o.rounded_rect(0.84 * w * k, 0.84 * h * k, 0.12 * w * k, 1), fill, 0.0010)],
              vaultline_mark(0.62 * h * k, rim)]
    faction.stamp(m, kit.hull, anchor, toward, up, levels, anchor=anchor)
    kit.add_gear(m)


# =============================================================================================
# headwear
# =============================================================================================
def ball_cap(fit, crown_mat: str, peak_mat: str | None = None, button_mat: str | None = None,
             front_el: float = 14.0, back_el: float = -6.0, reach: float = 0.072,
             tilt: float = 14.0) -> tuple[Mesh, list[int]]:
    """Six-panel crew cap: a soft dome over head + hair from ``front_el`` (above the brows) to
    ``back_el`` (over the nape), panel seams as shallow grooves, a top button and a curved peak.
    Returns (mesh, the bottom ring's vertex ids)."""
    k = fit.k

    def el_lo(az: float) -> float:
        return lerp(front_el, back_el, cgear._back_blend(az) ** 0.8)

    def el_hi(_az: float) -> float:
        return 86.0

    rows = [(0.0, 0.0030), (0.0, 0.0075), (0.12, 0.0085), (0.35, 0.0090), (0.60, 0.0085), (0.82, 0.0075),
            (0.95, 0.0065)]
    m, rings = cgear.head_wrap(fit, crown_mat, el_lo, el_hi, rows, n_az=36, pole=True, smooth=3,
                               bottom_out=Vector((0, 0, -1)))
    base = rings[1]
    c = fit.head_centre()
    # peak: an arc of the front of the band ring, pushed forward and slightly down, curved across
    n = len(base)
    arc = [i for i in range(n) if math.cos(TAU * i / n) > 0.25]
    arc.sort(key=lambda i: o.wrap(TAU * i / n))
    pm = peak_mat or crown_mat
    ti, to, bi, bo = [], [], [], []
    t_r = math.radians(tilt)
    for i in arc:
        a = TAU * i / n
        cf = max(0.0, math.cos(a))
        rch = reach * k * ((cf - 0.25) / 0.75) ** 0.55
        p_in = m.v[base[i]] + Vector((0, 0, -0.001 * k))
        d = Vector((math.sin(a), math.cos(a), 0.0))
        p_out = p_in + (d * math.cos(t_r) - UP * math.sin(t_r)) * rch
        p_out.z -= 0.010 * k * (1.0 - cf)           # curved peak: the sides droop
        ti.append(m.add(p_in + UP * 0.0025 * k, HEAD_W))
        to.append(m.add(p_out + UP * 0.0016 * k, HEAD_W))
        bi.append(m.add(p_in - UP * 0.0015 * k, HEAD_W))
        bo.append(m.add(p_out - UP * 0.0015 * k, HEAD_W))
    zf = m.v[base[0]].z
    up_ref = Vector((c.x, c.y + 0.03 * k, zf - 0.3))
    dn_ref = Vector((c.x, c.y + 0.03 * k, zf + 0.3))
    for j in range(len(arc) - 1):
        m.face((ti[j], ti[j + 1], to[j + 1], to[j]), pm, inside=up_ref)
        m.face((bi[j], bi[j + 1], bo[j + 1], bo[j]), pm, inside=dn_ref)
        m.face((to[j], to[j + 1], bo[j + 1], bo[j]), pm, inside=Vector((c.x, c.y, zf)))
    for e in (0, len(arc) - 1):
        m.face((ti[e], to[e], bo[e], bi[e]), pm, inside=Vector((c.x, c.y + 0.05 * k, zf)))
    # top button
    hit = sg.head_radius(fit, 0.0, math.radians(90.0), c)
    top = Vector((c.x, c.y, c.z + (hit if hit is not None else 0.1 * k) + 0.0075 * k))
    gr = o.Gear()
    gr.cyl(0.008 * k, 0.004 * k, centre=(0, 0, 0.0015 * k), axis="Z", segs=10, mat=button_mat or crown_mat)
    gr.bevel(0.0015 * k, 1, 30.0)
    m.extend(gr.to_mesh(o.frame_from(top, UP), weights=HEAD_W))
    return m, base


def cap_badge(fit, cap: Mesh, levels_fn, w: float, h: float) -> Mesh:
    """Stamp an emblem on the cap front (above the peak). ``levels_fn(w, h)`` -> emblem levels."""
    k = fit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    z = eye.z + 0.085 * k
    ch = Hull(fit, [cap], body_regions=set())
    hit = ch.cast(Vector((c.x, c.y + 0.4, z)), Vector((0, -1, 0)), 0.8)
    anchor = hit[0] if hit[0] is not None else Vector((c.x, c.y + 0.11 * k, z))
    toward = Vector((0.0, 1.0, 0.35)).normalized()
    m = Mesh()
    faction.stamp(m, lambda extra: Hull(fit, [cap, extra], body_regions=set()), anchor, toward, UP,
                  levels_fn(w * k, h * k), weights=HEAD_W, anchor=anchor)
    return m


def headphones_on(kit: Kit, mat: str = "polymer_black", pad_mat: str = "rubber_black",
                  accent: str | None = None) -> None:
    """Over-ear headphones worn on the head: a padded band over the crown from ear to ear, big
    round cups over the ears (100 % ``head``)."""
    fit, k = kit.fit, kit.k
    eye = fit.eye_centre()
    c = fit.head_centre()
    hh = gk.HeadHull(fit)
    m = Mesh()
    cup_r, cup_d = 0.042 * k, 0.030 * k
    tops = []
    for sx in (-1.0, 1.0):
        hit = hh.cast(Vector((sx * 0.3, c.y - 0.006 * k, eye.z - 0.022 * k)), Vector((-sx, 0, 0)), 0.4)
        ear = hit[0] if hit[0] is not None else Vector((sx * 0.075 * k, c.y, eye.z - 0.022 * k))
        axis = Vector((sx, 0.0, 0.0))
        p = ear + axis * 0.006 * k
        cup = o.Gear()
        cup.cyl(cup_r * 0.92, 0.014 * k, centre=(0, 0, 0.007 * k), axis="Z", segs=18, mat=pad_mat)
        cup.bevel(0.004 * k, 1, 30.0)
        cup.cyl(cup_r, cup_d - 0.012 * k, centre=(0, 0, 0.014 * k + (cup_d - 0.012 * k) / 2), axis="Z", segs=18,
                mat=mat)
        cup.bevel(0.005 * k, 2, 30.0)
        if accent:
            cup.cyl(cup_r * 0.55, 0.003 * k, centre=(0, 0, cup_d + 0.0015 * k), axis="Z", segs=14, mat=accent)
        m.extend(cup.to_mesh(o.frame_from(p, axis), weights=HEAD_W))
        tops.append(p + axis * 0.012 * k + UP * (cup_r * 0.85))
    # band: over the crown, slightly behind the ears' line
    pts = []
    n = 22
    for i in range(n + 1):
        t = i / n
        ang = lerp(-math.pi / 2, math.pi / 2, t)          # -90 (left) .. 0 (top) .. +90 (right)
        az = math.copysign(math.pi / 2, ang) if abs(ang) > 1e-6 else 0.0
        el = math.pi / 2 - abs(ang)
        r = sg.head_radius(fit, az, el, c) if abs(ang) > 1e-6 else sg.head_radius(fit, 0.0, math.pi / 2, c)
        r = (r if r is not None else 0.1 * k) + 0.016 * k
        d = Vector((math.sin(ang), 0.0, math.cos(ang)))
        q = c + d * r + Vector((0.0, -0.006 * k, 0.0))
        pts.append(q)
    # join the band ends to the cup tops
    pts = [tops[0]] + [q for q in pts if q.z > tops[0].z + 0.01 * k] + [tops[1]]
    o.tube(m, pts, 0.0085 * k, mat, sides=8, weights=lambda q, t: HEAD_W)
    inner = [c + (q - c) * 0.985 for q in pts[2:-2]]
    o.tube(m, inner, 0.0065 * k, pad_mat, sides=6, weights=lambda q, t: HEAD_W)
    kit.add_head(m)


# =============================================================================================
# body gear
# =============================================================================================
def backpack(kit: Kit, mat: str, strap_mat: str, trim: str = "char_tac_gear", z: float = 1.18,
             w: float = 0.15, h: float = 0.21, d: float = 0.13) -> None:
    """Daypack on the back: a rounded shell with a front zip pocket and a top handle, shoulder straps
    over both shoulders down the chest to the sides. Rigid Gear on the chest (clear of the Back seat's
    bone: the bag seat stays on the torso, civilians never carry loot)."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    cy = fit.ring_centre("chest").y
    zb = z * k
    p = _back_hit(hull, 0.0, zb, cy - 0.13 * k) + Vector((0.0, -0.006 * k, 0.0))
    W, H, D = w * k, h * k, d * k
    bag = o.Gear()
    bag.box((-W, -H, 0.0), (W, H, D), mat)
    bag.bevel(0.035 * k, 3, 30.0)
    pk = o.Gear()
    pk.box((-W * 0.72, -H * 0.92, D - 0.004 * k), (W * 0.72, -H * 0.15, D + 0.035 * k), mat)
    pk.bevel(0.014 * k, 2, 30.0)
    zp = o.Gear()
    zp.box((-W * 0.68, -H * 0.20, D + 0.030 * k), (W * 0.68, -H * 0.17, D + 0.038 * k), trim)
    zp.box((-W * 0.96, H * 0.90, D * 0.1), (W * 0.96, H * 0.94, D * 0.92), trim)
    zp.bevel(0.001 * k, 1, 30.0)
    hd = o.Gear()
    hd.box((-0.035 * k, H - 0.004 * k, D * 0.25), (0.035 * k, H + 0.012 * k, D * 0.45), strap_mat)
    hd.bevel(0.003 * k, 1, 30.0)
    mtx = o.frame_from(p, Vector((0.0, -1.0, 0.0)))
    for part in (bag, pk, zp, hd):
        kit.add_gear(part.to_mesh(mtx, anchor=p), layer=False)
    # shoulder straps: from the bag top over each shoulder, down the chest to the armpit
    m = Mesh()
    for sx in (-1.0, 1.0):
        sh = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        xb = sx * 0.085 * k          # on the bag top
        xs = sx * 0.120 * k          # over the shoulder, clear of the neck and hair
        pts: list[Vector] = []
        for i in range(5):
            t = i / 4
            zz = lerp(zb + H * 0.85, sh.z + 0.03 * k, t)
            pts.append(_back_hit(hull, lerp(xb, xs, t), zz, cy - 0.12 * k))
        for i in range(1, 4):
            yy = lerp(cy - 0.06 * k, cy + 0.06 * k, i / 4)
            hit = hull.cast(Vector((xs, yy, sh.z + 0.25 * k)), Vector((0, 0, -1)), 0.5)
            ok = hit[0] is not None and hit[0].z < sh.z + 0.09 * k
            pts.append(hit[0] if ok else Vector((xs, yy, sh.z + 0.06 * k)))
        for i in range(8):
            t = i / 7
            x = lerp(xs, sx * 0.135 * k, t)
            zz = lerp(sh.z + 0.04 * k, 1.17 * k, t)
            pts.append(_front_hit(hull, x, zz, cy + 0.12 * k))
        o.strip(m, hull, pts, 0.022 * k, 0.006 * k, strap_mat, segs_across=1, chamfer=0.002 * k)
    kit.add_soft(m)
    kit.notes["backpack_note"] = "daypack is rigid Gear on the chest bone; strap padding is Outfit"


def carrier_vest(kit: Kit, mat: str, bottom_z: float, strap_mat: str = "polymer_black") -> tuple[Mesh, dict]:
    """External soft ballistic vest: boxy front and back panels standing off the shirt, wide
    armholes, a scoop neck, padded shoulders, two side straps per side with buckles."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y
    chest_z = fit.ring_centre("chest").z

    def cut(c: Vector) -> bool:
        if c.y > cy:
            return c.z > neck_z - 0.060 * k * smoothstep(0.12 * k, 0.0, abs(c.x)) - 0.012 * k
        return c.z > neck_z + 0.006 * k

    def pad(p: Vector, r: str) -> float:
        d = 0.0
        for sfx in ("L", "R"):
            sh_pt = Vector(fit.J[f"shoulder.{sfx}"])
            dd = (p - sh_pt - Vector((0, 0, 0.035 * k))).length
            d += 0.006 * k * smoothstep(0.10 * k, 0.03 * k, dd)
        return d

    vest = g.upper_shell(fit, mat, bottom_z=bottom_z, base=0.018, sleeveless=True, hull=kit.hull(), top_cut=cut,
                         iters=4, waist_blouse=0.0, min_off=0.010 * k, extra=pad)
    vm = vest.mesh
    box = g.box_out(vm, chest_z + 0.01 * k, chest_z + 0.12 * k, 0.020 * k, 0.026 * k, 0.018 * k, power=4.0)
    for loop in o.boundary_loops(vm.f):
        o.straighten_loop(vm, loop, iters=3)
    o.hem_all(vm, thick=0.014 * k, depth=0.018 * k)
    kit.add_soft(vm)
    hull = kit.hull()
    gear = Mesh()
    for sx in (-1.0, 1.0):
        for zz in (1.10, 1.21):
            # G3: cast from just outside the torso (it cast from 0.7 m out and hit the bind-pose arm first, so the
            # straps rode the upper arm / forearm)
            mtx, loc = o.surface_frame(hull, Vector((sx * 0.12 * k, box.get("cy", cy), zz * k)), Vector((sx, 0, 0)),
                                       up=o.UP, reach=0.10 * k)
            gp = o.Gear()
            gp.box((-0.050 * k, -0.020 * k, -0.002 * k), (0.050 * k, 0.020 * k, 0.005 * k), strap_mat)
            gp.box((-0.015 * k, -0.024 * k, 0.003 * k), (0.015 * k, 0.024 * k, 0.012 * k), strap_mat)
            gp.bevel(0.002 * k, 1, 30.0)
            gear.extend(gp.to_mesh(mtx, anchor=loc))
    kit.add_gear(gear)
    return vm, box
