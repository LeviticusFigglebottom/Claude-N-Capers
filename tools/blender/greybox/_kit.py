"""Shared builders for the greybox modular kit (C1-02). Imported by the greybox asset scripts.

All coordinates are Blender (Z up, +Y = Godot -Z = "forward"/room side). Conventions (also in
PIPELINE.md §Greybox kit):

* Walls run along +X from the origin: x in [0, width], centred on the wall line (y in +-t/2),
  z from 0 (finished floor) to height. The origin is the bottom of the start end on the wall
  centreline, so walls snap end to end on the 0.5 m grid. Exterior walls: the -Y face
  (Godot +Z, outside) uses M_grey_wall_ext, the +Y face (room) M_grey_wall.
* Floors: x, y in [0, size], top at z = 0, slab down to -0.2. Ceilings: x, y in [0, size],
  visible underside at z = 0 (place at the clear ceiling height), 0.05 thick.
* Doors/windows (prefab visuals): origin at the bottom-centre of the opening on the wall
  centreline. Put them at the opening centre of the matching wall piece.
* Stairs: origin at the bottom of the first riser, centred on the stair width; they climb
  towards +Y (Godot -Z) and end with a tread flush with the upper floor.
* Architecture collision is a trimesh ``Collision-colonly`` (StaticBody3D "Collision" in Godot).
"""

from __future__ import annotations

import math

from lib import geo, uv
from lib.asset import AssetContext

from _palette import GREYBOX

GRID = 0.5
T_INT = 0.2
T_EXT = 0.4
HEIGHTS_CM = (300, 350, 400)
BEVEL = 0.005
SLAB = 0.2
CEILING_T = 0.05

# Doors: leaf width, jamb width, leaf height, head height (opening = leaf + 2 * jamb, 2.2 high).
DOORS = {
    "single": {"leaf": 0.9, "jamb": 0.05, "leaves": 1},
    "double": {"leaf": 0.9, "jamb": 0.1, "leaves": 2},
    "service": {"leaf": 1.1, "jamb": 0.05, "leaves": 1},
}
LEAF_H = 2.1
OPENING_H = 2.2
LEAF_T = 0.04

# Stairs.
RISER_MIN = 0.15
RISER_MAX = 0.19
TREAD = 0.28
STAIR_W = 1.2
LANDING = 1.2
MAX_RISERS_PER_FLIGHT = 16
WAIST = 0.25


def mat(ctx: AssetContext, lib_id: str):
    hex_color, rough, alpha = GREYBOX[lib_id]
    return ctx.material(lib_id, hex_color, roughness=rough, alpha=alpha)


def door_opening_w(kind: str) -> float:
    d = DOORS[kind]
    return d["leaf"] * d["leaves"] + 2 * d["jamb"]


# ----------------------------------------------------------------------------------- walls

def wall(ctx: AssetContext, width: float, height: float, thickness: float, exterior: bool,
         openings: list[tuple[float, float, float, float]] = ()) -> None:
    """Wall slab with rectangular ``openings`` (x0, x1, z0, z1); z0 == 0 cuts from the floor."""
    mb = geo.MeshBuilder()
    m_wall = mb.material(mat(ctx, "grey_wall"))
    m_ext = mb.material(mat(ctx, "grey_wall_ext")) if exterior else m_wall
    outer: list[tuple[float, float]] = [(0.0, 0.0)]
    holes: list[list[tuple[float, float]]] = []
    for x0, x1, z0, z1 in sorted(openings):
        if z0 <= 1e-6:
            outer += [(x0, 0.0), (x0, z1), (x1, z1), (x1, 0.0)]
        else:
            holes.append([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
    outer += [(width, 0.0), (width, height), (0.0, height)]
    mb.prism(outer, holes, axis="Y", start=-thickness / 2, end=thickness / 2, mat=m_wall)
    col = mb.copy()
    mb.bevel(BEVEL)
    if exterior:
        mb.bm.normal_update()
        for f in mb.bm.faces:
            if f.normal.y < -0.99:
                f.material_index = m_ext
    uv.box_project(mb.bm, density=uv.DENSITY_NEAR)
    obj = mb.to_object("Wall")
    geo.finish_hard_surface(obj)
    geo.collision_from_builder(col, "trimesh")


# --------------------------------------------------------------------------- floors/ceilings

def floor_tile(ctx: AssetContext, size: float) -> None:
    mb = geo.MeshBuilder()
    m_floor = mb.material(mat(ctx, "grey_floor"))
    m_ceil = mb.material(mat(ctx, "grey_ceiling"))
    mb.box((0, 0, -SLAB), (size, size, 0), mat=m_floor)
    col = mb.copy()
    mb.bevel(BEVEL)
    mb.bm.normal_update()
    for f in mb.bm.faces:
        if f.normal.z < -0.99:
            f.material_index = m_ceil
    uv.box_project(mb.bm, density=uv.DENSITY_NEAR)
    geo.finish_hard_surface(mb.to_object("Floor"))
    geo.collision_from_builder(col, "trimesh")


def ceiling_tile(ctx: AssetContext, size: float) -> None:
    mb = geo.MeshBuilder()
    m_ceil = mb.material(mat(ctx, "grey_ceiling"))
    mb.box((0, 0, 0), (size, size, CEILING_T), mat=m_ceil)
    col = mb.copy()
    mb.bevel(BEVEL * 0.5)
    uv.box_project(mb.bm, density=uv.DENSITY_FAR)
    geo.finish_hard_surface(mb.to_object("Ceiling"))
    geo.collision_from_builder(col, "trimesh")


# ------------------------------------------------------------------------------------ doors

# PO-7 frame_proud: greybox door frames are placed in walls of any thickness (0.04 m glazing,
# 0.06 m cages and fences, 0.3 m stair cores), so their collision is a 4 cm bullnose fin on the
# wall line (never proud of a wall face, never inside the leaf's span): the wall reveal behind the
# lining already blocks, the fin only keeps a capsule off the lining and slides it round the jamb.
DOOR_FIN = 0.04


def door_fin_collision(hw: float, jamb: float) -> geo.MeshBuilder:
    """Frame collision: per jamb a DOOR_FIN thick fin from the reveal (|x| = hw) to the lining's
    inner face (|x| = hw - jamb) with a round nose there, plus the head over the full width."""
    f = DOOR_FIN / 2
    col = geo.MeshBuilder()
    for side in (-1.0, 1.0):
        xi = hw - jamb
        pts = [(hw, -f)]
        for i in range(9):
            ang = -math.pi / 2 - math.pi * i / 8
            pts.append((xi + f + f * math.cos(ang), f * math.sin(ang)))
        pts.append((hw, f))
        prof = [(side * x, y) for x, y in pts]
        col.prism(prof if side > 0 else list(reversed(prof)), axis="Z", start=0.0, end=OPENING_H)
    col.box((-hw, -f, LEAF_H), (hw, f, OPENING_H))
    return col


def door(ctx: AssetContext, kind: str, wall_t: float, with_leaf: bool) -> None:
    d = DOORS[kind]
    w_open = door_opening_w(kind)
    hw = w_open / 2
    jamb = d["jamb"]
    depth = wall_t + 0.02
    head = OPENING_H - LEAF_H
    outer = [(-hw, 0.0), (-hw + jamb, 0.0), (-hw + jamb, LEAF_H), (hw - jamb, LEAF_H), (hw - jamb, 0.0),
             (hw, 0.0), (hw, OPENING_H), (-hw, OPENING_H)]
    assert head > 0
    mb = geo.MeshBuilder()
    mb.prism(outer, axis="Y", start=-depth / 2, end=depth / 2, mat=mb.material(mat(ctx, "grey_frame")))
    mb.bevel(BEVEL * 0.6)
    uv.box_project(mb.bm, density=uv.DENSITY_NEAR)
    frame = mb.to_object("Frame")
    geo.finish_hard_surface(frame)
    # visual_slots.md: the door prefab looks up `Frame/Collision` (StaticBody3D under the Frame mesh).
    geo.collision_from_builder(door_fin_collision(hw, jamb), "trimesh", parent=frame)
    if not with_leaf:
        return
    leaf_w = d["leaf"]
    for i in range(d["leaves"]):
        sign = 1.0 if i == 0 else -1.0  # leaf 1 hinges on the -X jamb, leaf 2 on the +X jamb
        suffix = "" if i == 0 else "2"
        hinge_x = -sign * (hw - jamb)
        pivot = geo.empty("Leaf" + suffix, (hinge_x, 0.0, 0.0))
        lo_x, hi_x = 0.002, leaf_w - 0.002
        if sign < 0:
            lo_x, hi_x = -hi_x, -lo_x
        lm = geo.MeshBuilder()
        lm.box((lo_x, -LEAF_T / 2, 0.008), (hi_x, LEAF_T / 2, LEAF_H - 0.002), mat=lm.material(mat(ctx, "grey_door")))
        lm.bevel(0.003)
        uv.box_project(lm.bm, density=uv.DENSITY_NEAR)
        geo.finish_hard_surface(lm.to_object("LeafMesh" + suffix, parent=pivot))
        hx = sign * (leaf_w - 0.07)
        hm = geo.MeshBuilder()
        m_trim = hm.material(mat(ctx, "grey_trim"))
        lever = 0.12
        for side in (1.0, -1.0):
            y0, y1 = sorted((side * LEAF_T / 2, side * (LEAF_T / 2 + 0.06)))
            hm.box((hx - 0.012, y0, 0.988), (hx + 0.012, y1, 1.012), mat=m_trim)  # spindle
            ly0, ly1 = sorted((side * (LEAF_T / 2 + 0.045), side * (LEAF_T / 2 + 0.065)))
            lx0, lx1 = sorted((hx, hx - sign * lever))
            hm.box((lx0, ly0, 0.99), (lx1, ly1, 1.01), mat=m_trim)  # lever towards the hinge
        uv.box_project(hm.bm, density=uv.DENSITY_NEAR)
        geo.finish_hard_surface(hm.to_object("HandleMesh" + suffix, parent=pivot))
        geo.empty("Handle" + suffix, (hx, 0.0, 1.0), parent=pivot)


# ---------------------------------------------------------------------------------- windows

def window(ctx: AssetContext, width: float, height: float) -> None:
    """Frame + Glass for an opening ``width`` x ``height``; origin at the opening's bottom-centre."""
    frame_w = 0.05
    depth = 0.1
    panes = max(1, math.ceil(width / 1.5 - 1e-6))
    hw = width / 2
    inner_w = (width - frame_w * (panes + 1)) / panes
    holes = []
    for i in range(panes):
        x0 = -hw + frame_w + i * (inner_w + frame_w)
        holes.append([(x0, frame_w), (x0 + inner_w, frame_w), (x0 + inner_w, height - frame_w), (x0, height - frame_w)])
    mb = geo.MeshBuilder()
    outer = [(-hw, 0.0), (hw, 0.0), (hw, height), (-hw, height)]
    mb.prism(outer, holes, axis="Y", start=-depth / 2, end=depth / 2, mat=mb.material(mat(ctx, "grey_frame")))
    mb.bevel(BEVEL * 0.6)
    uv.box_project(mb.bm, density=uv.DENSITY_NEAR)
    geo.finish_hard_surface(mb.to_object("Frame"))
    gb = geo.MeshBuilder()
    m_glass = gb.material(mat(ctx, "grey_glass"))
    for hole in holes:
        (x0, z0), (x1, _), (_, z1), _ = hole
        gb.box((x0 - 0.01, -0.005, z0 - 0.01), (x1 + 0.01, 0.005, z1 + 0.01), mat=m_glass)
    uv.box_project(gb.bm, density=uv.DENSITY_NEAR)
    geo.mark_sharp(gb.to_object("Glass"))


# ----------------------------------------------------------------------------------- stairs

def riser_count(floor_to_floor: float) -> int:
    n = math.ceil(floor_to_floor / RISER_MAX - 1e-9)
    r = floor_to_floor / n
    if not RISER_MIN - 1e-9 <= r <= RISER_MAX + 1e-9:
        raise ValueError(f"no riser count fits {floor_to_floor} m")
    return n


def _envelope(funcs, u0: float, u1: float, clamp: float) -> list[tuple[float, float]]:
    """Upper envelope of piecewise-linear functions (each a list of (u, z) breakpoints), clamped below."""
    def ev(pts, u):
        if u <= pts[0][0]:
            (ua, za), (ub, zb) = pts[0], pts[1]
        elif u >= pts[-1][0]:
            (ua, za), (ub, zb) = pts[-2], pts[-1]
        else:
            for (ua, za), (ub, zb) in zip(pts, pts[1:]):
                if ua <= u <= ub:
                    break
        return za if ub == ua else za + (zb - za) * (u - ua) / (ub - ua)

    cands = {u0, u1}
    segs = []
    for pts in funcs:
        cands.update(u for u, _ in pts)
        segs += list(zip(pts, pts[1:]))
    segs.append(((u0, clamp), (u1, clamp)))
    for i, ((a1, b1), (a2, b2)) in enumerate(segs):
        for (c1, d1), (c2, d2) in segs[i + 1:]:
            s1 = (b2 - b1) / (a2 - a1) if a2 != a1 else None
            s2 = (d2 - d1) / (c2 - c1) if c2 != c1 else None
            if s1 is None or s2 is None or abs(s1 - s2) < 1e-12:
                continue
            u = (d1 - s2 * c1 - b1 + s1 * a1) / (s1 - s2)
            cands.add(u)
    us = sorted(u for u in cands if u0 - 1e-9 <= u <= u1 + 1e-9)
    pts = [(u, max(clamp, max(ev(f, u) for f in funcs))) for u in us]
    out: list[tuple[float, float]] = []
    for p in pts:
        if out and abs(p[0] - out[-1][0]) < 1e-7:
            continue
        out.append(p)
    return _drop_collinear(out)


def _drop_collinear(pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
    out = list(pts)
    i = 1
    while i < len(out) - 1:
        (ax, ay), (bx, by), (cx, cy) = out[i - 1], out[i], out[i + 1]
        if abs((bx - ax) * (cy - ay) - (by - ay) * (cx - ax)) < 1e-9:
            out.pop(i)
        else:
            i += 1
    return out


def flight_profiles(depths: list[float], riser: float, base: float, foot: str):
    """Side profiles (u along the run, z up) of one run of steps.

    ``depths[i]`` is the tread depth of step i (TREAD for flight steps, longer for a landing).
    Returns (visual_outline, ramp_outline). ``foot='floor'``: the underside meets z=base;
    ``foot='slab'``: the run starts on a landing, underside clamped at base - SLAB."""
    top: list[tuple[float, float]] = []
    u = 0.0
    z = base
    funcs: list[list[tuple[float, float]]] = []
    ramp_top: list[tuple[float, float]] = [(0.0, base)]
    flight_start = 0.0
    flight_base = base
    slope = riser / TREAD
    for i, d in enumerate(depths):
        z += riser
        top += [(u, z), (u + d, z)]
        if d > TREAD + 1e-6 or i == len(depths) - 1:
            # Chunk = flight + the landing (or top tread) it ends on. Its underside is the line
            # parallel to the nosings WAIST below them, capped by the landing slab underside.
            za = flight_base + riser - WAIST
            flat = z - SLAB
            u_k = flight_start + (flat - za) / slope
            far = flight_start - 50.0
            funcs.append([(far, za + (far - flight_start) * slope), (u_k, flat), (u + d + 50.0, flat)])
            ramp_top += [(u, z), (u + d, z)]
            flight_start = u + d
            flight_base = z
        u += d
    u_end = u
    clamp = base if foot == "floor" else base - SLAB
    under = _envelope(funcs, 0.0, u_end, clamp)
    start = [(0.0, clamp)] if foot == "slab" else []
    visual = _dedupe(start + [(0.0, base)] + top + list(reversed(under)))
    ramp = _dedupe(start + ramp_top + list(reversed(under)))
    return _drop_collinear_closed(visual), _drop_collinear_closed(ramp)


def _dedupe(pts):
    out = []
    for p in ((round(a, 6) + 0.0, round(b, 6) + 0.0) for a, b in pts):
        if out and abs(p[0] - out[-1][0]) < 1e-7 and abs(p[1] - out[-1][1]) < 1e-7:
            continue
        out.append(p)
    if len(out) > 1 and abs(out[0][0] - out[-1][0]) < 1e-7 and abs(out[0][1] - out[-1][1]) < 1e-7:
        out.pop()
    return out


def _drop_collinear_closed(pts):
    out = _drop_collinear(pts + [pts[0]])[:-1]
    if len(out) > 2:
        (ax, ay), (bx, by), (cx, cy) = out[-1], out[0], out[1]
        if abs((bx - ax) * (cy - ay) - (by - ay) * (cx - ax)) < 1e-9:
            out.pop(0)
    return out


def stair(ctx: AssetContext, floor_to_floor: float, layout: str) -> dict:
    """``layout``: ``straight`` (<= 16 risers), ``landing`` (two flights, straight, mid landing),
    ``u`` (two flights side by side with a half landing). Returns facts for SOURCE.txt."""
    n = riser_count(floor_to_floor)
    r = floor_to_floor / n
    m_stair_obj = mat(ctx, "grey_stair")
    vis = geo.MeshBuilder()
    m_stair = vis.material(m_stair_obj)
    col = geo.MeshBuilder()
    hw = STAIR_W / 2
    if layout == "straight":
        if n > MAX_RISERS_PER_FLIGHT:
            raise ValueError(f"{floor_to_floor} m needs {n} risers: use a landing layout")
        outline, ramp = flight_profiles([TREAD] * n, r, 0.0, "floor")
        vis.prism(outline, axis="X", start=-hw, end=hw, mat=m_stair)
        col.prism(ramp, axis="X", start=-hw, end=hw)
        n1, n2 = n, 0
    elif layout == "landing":
        n1 = math.ceil(n / 2)
        n2 = n - n1
        depths = [TREAD] * (n1 - 1) + [LANDING] + [TREAD] * n2
        outline, ramp = flight_profiles(depths, r, 0.0, "floor")
        vis.prism(outline, axis="X", start=-hw, end=hw, mat=m_stair)
        col.prism(ramp, axis="X", start=-hw, end=hw)
    elif layout == "u":
        gap = 0.1
        n1 = math.ceil(n / 2)
        n2 = n - n1
        zl = n1 * r
        y_land = (n1 - 1) * TREAD
        o1, r1 = flight_profiles([TREAD] * (n1 - 1) + [LANDING], r, 0.0, "floor")
        vis.prism(o1, axis="X", start=gap / 2, end=gap / 2 + STAIR_W, mat=m_stair)
        col.prism(r1, axis="X", start=gap / 2, end=gap / 2 + STAIR_W)
        o2, r2 = flight_profiles([TREAD] * n2, r, zl, "slab")
        mirror = lambda pts: [(y_land - u, z) for u, z in pts]  # noqa: E731
        vis.prism(mirror(o2), axis="X", start=-gap / 2 - STAIR_W, end=-gap / 2, mat=m_stair)
        col.prism(mirror(r2), axis="X", start=-gap / 2 - STAIR_W, end=-gap / 2)
        vis.box((-gap / 2 - STAIR_W, y_land, zl - SLAB), (gap / 2, y_land + LANDING, zl), mat=m_stair)
        col.box((-gap / 2 - STAIR_W, y_land, zl - SLAB), (gap / 2, y_land + LANDING, zl))
    else:
        raise ValueError(layout)
    for n_flight in (n1, n2):
        if n_flight > MAX_RISERS_PER_FLIGHT:
            raise ValueError(f"flight of {n_flight} risers > {MAX_RISERS_PER_FLIGHT}")
    uv.box_project(vis.bm, density=uv.DENSITY_NEAR)
    geo.finish_hard_surface(vis.to_object("Stair"))
    geo.collision_from_builder(col, "trimesh")
    return {"risers": n, "riser_m": round(r, 4), "tread_m": TREAD, "flights": [x for x in (n1, n2) if x]}


# ---------------------------------------------------------------------------- railing/column

def railing(ctx: AssetContext, length: float, height: float = 1.05) -> None:
    mb = geo.MeshBuilder()
    m = mb.material(mat(ctx, "grey_trim"))
    post = 0.04
    rail = 0.05
    n_posts = max(2, math.ceil(length / 1.0 - 1e-6) + 1)
    for i in range(n_posts):
        x = min(max(i * length / (n_posts - 1), post / 2), length - post / 2)
        mb.box((x - post / 2, -post / 2, 0.0), (x + post / 2, post / 2, height - rail), mat=m)
    mb.box((0.0, -rail / 2, height - rail), (length, rail / 2, height), mat=m)
    mb.box((0.0, -0.01, 0.5), (length, 0.01, 0.53), mat=m)
    mb.bevel(0.003)
    uv.box_project(mb.bm, density=uv.DENSITY_NEAR)
    geo.finish_hard_surface(mb.to_object("Railing"))
    col = geo.MeshBuilder()
    col.box((0.0, -rail / 2, 0.0), (length, rail / 2, height))
    geo.collision_from_builder(col, "trimesh")


def column(ctx: AssetContext, shape: str, size: float, height: float) -> None:
    mb = geo.MeshBuilder()
    m = mb.material(mat(ctx, "grey_wall"))
    col = geo.MeshBuilder()
    if shape == "square":
        mb.box((-size / 2, -size / 2, 0.0), (size / 2, size / 2, height), mat=m)
        col.box((-size / 2, -size / 2, 0.0), (size / 2, size / 2, height))
    else:
        mb.cylinder(size / 2, height, segments=16, centre=(0, 0, height / 2), mat=m)
        col.cylinder(size / 2, height, segments=12, centre=(0, 0, height / 2))
    mb.bevel(BEVEL)
    uv.box_project(mb.bm, density=uv.DENSITY_NEAR)
    geo.finish_hard_surface(mb.to_object("Column"))
    geo.collision_from_builder(col, "trimesh")


