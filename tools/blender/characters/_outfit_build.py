"""Character assembly for D1-02 outfit scripts. Blender only.

``build_character(ctx, recipe)`` is the whole ``build(ctx)`` of a ``char_*.py`` asset script:

1. split ``ctx.params`` into body params (``_body.DEFAULTS`` keys) and outfit options,
2. build ``rig_humanoid`` at the variant's height and a ``Fit`` of the body,
3. run ``recipe(kit)``: it adds soft garments (``kit.soft``), hard gear (``kit.gear``) and headwear
   (``kit.head``) and may set attachment seats,
4. build the skinned ``Body``/``Hair`` and **bake** their shape keys at the variant's values,
5. delete body faces that are fully covered by clothing (rays along the skin normal hit a garment
   within 6 cm), so skin can never poke through and no triangles are wasted,
6. create the skinned ``Outfit``, ``Gear`` and ``Headwear`` objects and record SOURCE extras.

Shape-key decision (D1-02): characters are **baked** at fixed body params. No mesh of a character
glb has blend shapes, so the assembly scene must not set ``blend_shapes/*``; the params are still
recorded in SOURCE.txt (``body_params``) for reference, and variety comes from separate variants.
"""

from __future__ import annotations

import json
import math
from collections.abc import Callable

import _body as body
import _outfit as o
import _rig as rig
import _tri
from _outfit import Fit, Hull, Mesh, Vector

COVER_RAY = 0.06
# D-115 clip audit: the cover rays start just *inside* the skin, so a garment surface lying on the skin (a shoe
# sole's flat bottom is coplanar with the foot's sole at z = 0) still counts as cover; starting outside it, the
# ray began beyond that sole, the foot's skin was kept and showed through the soles whenever a sole faced the
# camera (kneel_cuffed, surrender, death_crouch).
COVER_START = 0.0008


class Kit:
    """What a recipe works with: the fit, the three output meshes, hull helpers and seats."""

    def __init__(self, ctx, fit: Fit, opts: dict) -> None:
        self.ctx = ctx
        self.fit = fit
        self.k = fit.k
        self.opts = opts
        self.soft = Mesh()
        self.gear = Mesh()
        self.head = Mesh()
        self.slung = Mesh()   # a long gun slung on the back: its own `Slung` mesh so ENV A can hide it when seated
        self.layers: list[Mesh] = []
        self.seats: dict[str, Vector] = {}
        self.notes: dict[str, str] = {}

    def hull(self, *extra: Mesh, body_regions: set[str] | None = None) -> Hull:
        return Hull(self.fit, self.layers + list(extra), body_regions=body_regions)

    def add_soft(self, m: Mesh) -> Mesh:
        self.soft.extend(m)
        self.layers.append(m)
        return m

    def add_gear(self, m: Mesh, layer: bool = True) -> Mesh:
        self.gear.extend(m)
        if layer:
            self.layers.append(m)
        return m

    def add_head(self, m: Mesh) -> Mesh:
        self.head.extend(m)
        return m

    def add_slung(self, m: Mesh) -> Mesh:
        self.slung.extend(m)
        return m


def split_params(params: dict) -> tuple[dict, dict]:
    bp = {k: v for k, v in params.items() if k in body.DEFAULTS}
    opts = {k: v for k, v in params.items() if k not in body.DEFAULTS}
    return body.body_params(bp), opts


def cull_covered(fit: Fit, obj, covers: Hull) -> int:
    """Delete Body faces whose corners and centre are all under clothing. Returns faces removed."""
    import bmesh

    me = obj.data
    if len(me.polygons) != len(fit.F):
        raise AssertionError("Body face order differs from the fit")
    hit_cache: dict[int, bool] = {}

    def covered_vert(v: int) -> bool:
        if v not in hit_cache:
            n = fit.N[v]
            hit = covers.cast(fit.P[v] - n * COVER_START, n, COVER_RAY)
            hit_cache[v] = hit[0] is not None
        return hit_cache[v]

    kill = []
    for fi, (f, r) in enumerate(zip(fit.F, fit.FR)):
        if r == "head":
            continue
        if not all(covered_vert(v) for v in f):
            continue
        c = sum((fit.P[v] for v in f), Vector()) / len(f)
        n = o.newell(fit.P, f).normalized()
        if covers.cast(c - n * COVER_START, n, COVER_RAY)[0] is None:
            continue
        kill.append(fi)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in kill], context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()
    return len(kill)


def _godot(v: Vector) -> tuple[float, float, float]:
    return (v.x, v.z, -v.y)


def bone_local(fit: Fit, bone: str, p: Vector) -> tuple[float, float, float]:
    """``p`` (Blender, rest) in the Godot rest frame of ``bone`` (Y along the bone, Z = roll ref)."""
    h, t, roll = rig.bone_segments(fit.height)[bone]
    hg = Vector(rig.to_godot(h))
    y = (Vector(rig.to_godot(t)) - hg).normalized()
    z = Vector(rig.to_godot(roll))
    z = (z - y * z.dot(y)).normalized()
    x = y.cross(z)
    d = Vector(_godot(p)) - hg
    return (d.dot(x), d.dot(y), d.dot(z))


def _fmt(v) -> str:
    return "[" + ", ".join(f"{c:.4f}" for c in v) + "]"


def default_seats(kit: Kit) -> None:
    fit = kit.fit
    k = fit.k
    eye = fit.eye_centre()
    kit.seats.setdefault("Head", Vector((0.0, eye.y + body.EYE_RADIUS * k, eye.z)))
    if "Back" not in kit.seats:
        hull = kit.hull()
        z = 1.30 * k
        hit = hull.cast(Vector((0.0, -0.6, z)), Vector((0, 1, 0)), 1.0)
        kit.seats["Back"] = hit[0] if hit[0] is not None else Vector((0.0, -0.13 * k, z))
    if "Hip" not in kit.seats:
        hull = kit.hull()
        a = math.radians(100.0)
        c = fit.ring_centre("hips")
        r = hull.outer_radius(c.z + 0.02 * k, a, c.x, c.y)
        kit.seats["Hip"] = Vector((c.x + r * math.sin(a), c.y + r * math.cos(a), c.z + 0.02 * k))


SEAT_BONES = {"Head": "head", "Back": "chest", "Hip": "hips"}


def apply_recolor(kit: Kit) -> None:
    """D-147 finish swaps: a variant's ``recolor`` option ({library material: library material}) remaps the materials of
    every outfit mesh after the recipe, so the swap keeps its base look's meshes exactly; its ``note`` option replaces
    the look note (the mapping is appended)."""
    table: dict[str, str] = kit.opts.get("recolor", {})
    if not table:
        return
    for m in [kit.soft, kit.gear, kit.head, kit.slung, *getattr(kit, "extra", {}).values()]:
        m.m = [table.get(x, x) for x in m.m]
    mapping = ", ".join(f"{a} -> {b}" for a, b in sorted(table.items()))
    kit.notes["look"] = f"{kit.opts.get('note', kit.notes.get('look', ''))} [{mapping}]"


def build_character(ctx, recipe: Callable[[Kit], None]) -> None:
    bparams, opts = split_params(ctx.params)
    arm = rig.build_rig(ctx, bparams["height"])
    fit = Fit(bparams)
    kit = Kit(ctx, fit, opts)
    recipe(kit)
    apply_recolor(kit)
    default_seats(kit)
    objs = body.build_body(ctx, arm, bparams)
    o.bake_body(objs, objs["data"])
    removed = cull_covered(fit, objs["Body"], Hull(fit, kit.layers, body_regions=set()))
    for name in ("Body", "Hair"):
        if objs[name] is not None:
            _tri.triangulate(objs[name])
    tris = {"Body": sum(len(p.vertices) - 2 for p in objs["Body"].data.polygons)}
    if objs["Hair"] is not None:
        tris["Hair"] = sum(len(p.vertices) - 2 for p in objs["Hair"].data.polygons)
    if kit.soft.f:
        o.make_object(ctx, fit, arm, "Outfit", kit.soft, sharp_deg=55.0)
        tris["Outfit"] = kit.soft.tris()
    if kit.gear.f:
        o.make_object(ctx, fit, arm, "Gear", kit.gear, sharp_deg=32.0, hard=True)
        tris["Gear"] = kit.gear.tris()
    if kit.head.f:
        o.make_object(ctx, fit, arm, "Headwear", kit.head, sharp_deg=40.0, hard=True)
        tris["Headwear"] = kit.head.tris()
    if kit.slung.f:
        o.make_object(ctx, fit, arm, "Slung", kit.slung, sharp_deg=32.0, hard=True)
        tris["Slung"] = kit.slung.tris()
    bp = {k: (sorted(v) if isinstance(v, frozenset) else v) for k, v in bparams.items() if k != "hide"}
    ctx.source_extra["body_params"] = json.dumps(bp, sort_keys=True)
    ctx.source_extra["shape_keys"] = "none (baked at body_params; do not set blend_shapes/*)"
    ctx.source_extra["bones"] = len(rig.BONES)
    ctx.source_extra["tris"] = sum(tris.values())
    ctx.source_extra["tris_by_mesh"] = json.dumps(tris, sort_keys=True)
    ctx.source_extra["body_faces_culled"] = removed
    ctx.source_extra["meshes"] = ",".join(sorted(tris))
    for name in sorted(kit.seats):
        p = kit.seats[name]
        bone = SEAT_BONES[name]
        ctx.source_extra[f"attach_{name}"] = (f"bone {bone}, local {_fmt(bone_local(fit, bone, p))} "
                                              f"(model {_fmt(_godot(p))}, Godot axes, rest pose)")
    for key, val in sorted(kit.notes.items()):
        ctx.source_extra[key] = val
