"""``rig_arms``: first-person viewmodel arms (rig, mesh, weapon animation sets), D1-03 / D-034.

Private helper for ``arms_fp.py``. Pure numpy except ``build_arms_rig`` / ``build_arms_mesh``.

Rig (camera space). Bone ``root`` is the camera origin (the eye point between the eyes of a 1.78 m
``rig_humanoid``), Blender +Y forward = Godot -Z, +Z up. The arm chains reuse the contract names and
the exact rest geometry of ``rig_humanoid`` translated by -eye (``clavicle.L/R, upper_arm.L/R,
forearm.L/R, hand.L/R`` and the 30 finger bones), with the clavicles parented to ``root``. Two helper
bones are added (contract proposal, see the D1-03 report):

* ``weapon`` (child of ``hand.R``; identity relative to it except while the right hand works a bolt
  (``sniper_bolt*``, ``sniper_reload_empty``) or a lever (the lever cycle, D-055), and in every ``bow`` clip (the
  bow sits in ``hand.L``, ``_arms_bow``)): its head is the weapon origin and
  its axes are the weapon's Godot axes (bone Y = weapon up, bone Z = weapon back, X = right), at the
  HandR grip offset of ``_anim.grip_offset``. A BoneAttachment3D on ``weapon`` with the weapon scene
  as an identity child places the gun; the same offset applies to ``rig_humanoid``'s HandR.
* ``magazine`` (child of ``weapon``, rest = the ``weapon`` frame): identity while the magazine is
  seated; animated during reloads (drops out, travels in the left hand, is inserted). Put the
  weapon's ``Magwell`` magazine node under a BoneAttachment3D on ``magazine`` with the same
  weapon-space transform it has in the weapon scene.

The clavicles are posed with a location too (bladed stance and the first-person shoulder placement,
``_arms_choreo``), so every clip keys the same transforms. Animation sets are data
(``_arms_sets.FPSet``: weapon markers, hip / ADS / sprint holds, stance); ``_arms_clips.fp_clips(sk,
set)`` turns a set into clips named ``<set>_<clip>`` (``pistol_idle`` ...) with the key-pose
choreography of ``_arms_choreo``.
"""

from __future__ import annotations

import numpy as np

import _anim as A
import _rig as rig
from _anim import Skeleton

ARMATURE_NAME = "rig_arms"
ARM_PREFIXES = ("clavicle", "upper_arm", "forearm", "hand", "thumb", "index", "middle", "ring", "pinky")


def eye_point(height: float = rig.DEFAULT_HEIGHT) -> np.ndarray:
    j = rig.joints(height)
    return (np.array(j["eye.L"]) + np.array(j["eye.R"])) * 0.5


def arm_bones() -> list[str]:
    return [b for b in rig.BONES if b.split("_0")[0].split(".")[0] in ARM_PREFIXES]


BONES: list[str] = ["root", *arm_bones(), "weapon", "magazine"]
PARENT: dict[str, str | None] = {"root": None, "weapon": "hand.R", "magazine": "weapon"}
for _b in arm_bones():
    PARENT[_b] = "root" if _b.startswith("clavicle") else rig.PARENT[_b]


def segments(height: float = rig.DEFAULT_HEIGHT) -> dict:
    """{bone: (head, tail, roll_ref)} in camera space (metres, Blender axes)."""
    eye = eye_point(height)
    segs = rig.bone_segments(height)
    out = {"root": ((0.0, 0.0, 0.0), (0.0, 0.0, 0.1), (0.0, -1.0, 0.0))}
    for b in arm_bones():
        h, t, r = segs[b]
        out[b] = (tuple(np.array(h) - eye), tuple(np.array(t) - eye), r)
    tmp = Skeleton({k: v for k, v in out.items()}, {k: PARENT[k] for k in out}, list(out))
    R_off, t_off = A.grip_offset(tmp, "R")
    B = tmp.B["hand.R"]
    Rw = B @ R_off
    pw = tmp.head["hand.R"] + B @ t_off
    up, back = Rw[:, 2], -Rw[:, 1]
    out["weapon"] = (tuple(pw), tuple(pw + up * 0.06), tuple(back))
    out["magazine"] = (tuple(pw), tuple(pw + up * 0.03), tuple(back))
    return out


def skeleton(height: float = rig.DEFAULT_HEIGHT) -> Skeleton:
    return Skeleton(segments(height), PARENT, BONES, rig.scale_for(height))


# =============================================================================================
# animation sets (data in ``_arms_sets``, clips in ``_arms_clips``, choreography in ``_arms_choreo``)
# =============================================================================================
from _arms_clips import fp_clips, state_fns  # noqa: E402
from _arms_sets import B3, PISTOL, SETS, FPSet, clip_table  # noqa: E402

__all__ = ["ARMATURE_NAME", "B3", "BONES", "PARENT", "PISTOL", "SETS", "FPSet", "build_arms_mesh", "build_arms_rig",
           "clip_table", "eye_point", "fp_clips", "segments", "skeleton", "state_fns"]


# =============================================================================================
# Blender: rig + mesh
# =============================================================================================
def build_arms_rig(height: float = rig.DEFAULT_HEIGHT):
    import bpy  # noqa: PLC0415
    from mathutils import Vector  # noqa: PLC0415

    from lib import scene  # noqa: PLC0415

    arm = bpy.data.armatures.new(ARMATURE_NAME)
    arm.display_type = "OCTAHEDRAL"
    obj = bpy.data.objects.new(ARMATURE_NAME, arm)
    scene.link(obj)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    segs = segments(height)
    for bone in BONES:
        head, tail, roll = segs[bone]
        eb = arm.edit_bones.new(bone)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.align_roll(Vector(roll))
        if PARENT[bone] is not None:
            eb.parent = arm.edit_bones[PARENT[bone]]
            eb.use_connect = False
        eb.use_deform = bone not in ("root", "weapon", "magazine")
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    obj.select_set(False)
    return obj


# -- mesh (pure part) --------------------------------------------------------------------------
SLEEVE_RINGS = ("upper_arm", "elbow", "forearm", "wrist")
SLEEVE_EASE = {"upper_arm": 0.012, "elbow": 0.011, "forearm": 0.009, "wrist": 0.008}


def _align_ring(ref: list, ring: list) -> list:
    """Rotate ``ring`` (closed loop) so its points best match ``ref`` index by index."""
    n = len(ring)
    best, best_d = 0, None
    for sh in range(n):
        d = sum(float(np.sum((np.array(ref[i]) - np.array(ring[(i + sh) % n])) ** 2)) for i in range(0, n, 4))
        if best_d is None or d < best_d:
            best, best_d = sh, d
    return [ring[(i + best) % n] for i in range(n)]


def hand_part(params: dict) -> dict:
    """Pure-math hands in humanoid space (one Catmull-Clark level above the body's) with body UVs and
    weights. Returns verts, faces, mats ("skin"), uvs, weights, height (the ``hands_data`` layout)."""
    import _body as body  # noqa: PLC0415

    p = body.body_params(params, hide=frozenset(r for r in body.REGIONS if r != "hands"))
    data, _hair = body.body_mesh_data(p)
    w0 = body.body_weights(data)
    md = body.MeshData(verts=[tuple(v) for v in data.blend], faces=list(data.faces), face_region=list(data.face_region),
                       face_mat=list(data.face_mat), face_side=list(data.face_side))
    sub = body.catmull_clark(md)
    nv = len(md.verts)
    weights: list[dict] = [dict(w) for w in w0] + [dict() for _ in range(len(sub.verts) - nv)]

    def avg(ids: list[int]) -> dict:
        acc: dict = {}
        for i in ids:
            for b, x in weights[i].items():
                acc[b] = acc.get(b, 0.0) + x / len(ids)
        return acc
    k = 0
    for f in md.faces:
        n = len(f)
        for i in range(n):
            b_, e1, fp, _e0 = sub.faces[k]
            c = f[(i + 1) % n]
            if not weights[e1]:
                weights[e1] = avg([f[i], c])
            if not weights[fp]:
                weights[fp] = avg(list(f))
            k += 1
    weights = [_top4(w) for w in weights]
    uvs = body.face_uvs(sub.faces, sub.face_region, sub.face_mat, sub.face_side, sub.verts, float(p["height"]))
    verts = [tuple(v) for v in sub.verts]
    faces = [tuple(f) for f in sub.faces]
    mats = ["skin"] * len(faces)
    face_uv: list = list(uvs)
    return {"verts": verts, "faces": faces, "mats": mats, "uvs": face_uv, "weights": weights,
            "height": float(p["height"])}


def arm_loops(params: dict) -> dict:
    """{side: [upper_arm, elbow, forearm, wrist] body rings, each rotated to match the previous one}."""
    import _body as body  # noqa: PLC0415

    rings = body.body_rings(body.body_params(params, hide=frozenset()))
    out = {}
    for sfx, _sx in rig.SIDES:
        loops = [rings[f"{r}.{sfx}"] for r in SLEEVE_RINGS]
        for i in range(1, len(loops)):
            loops[i] = _align_ring(loops[i - 1], loops[i])
        out[sfx] = loops
    return out


def hands_data(params: dict) -> dict:
    """Pure-math arm mesh in humanoid space: hands (``hand_part``) plus lofted suit sleeves with a
    turned-in cuff. Returns verts, faces, face material ("skin"/"suit"), face uvs (skin only; None
    for suit), weights."""
    import _body as body  # noqa: PLC0415

    hp = hand_part(params)
    verts, faces, mats, face_uv, weights = hp["verts"], hp["faces"], hp["mats"], hp["uvs"], hp["weights"]
    p = {"height": hp["height"]}
    # sleeves
    all_loops = arm_loops(params)
    for sfx, _sx in rig.SIDES:
        loops = all_loops[sfx]
        cen =[np.mean(np.array(lp), axis=0) for lp in loops]
        offs = [SLEEVE_EASE[r] for r in SLEEVE_RINGS]
        out_loops = []
        for li in range(len(loops) - 1):
            for t in (0.0, 0.25, 0.5, 0.75):
                pts = []
                for a, b in zip(loops[li], loops[li + 1]):
                    pa = np.array(a) + _outward(np.array(a), cen[li]) * offs[li]
                    pb = np.array(b) + _outward(np.array(b), cen[li + 1]) * offs[li + 1]
                    pts.append(pa + (pb - pa) * t)
                out_loops.append(pts)
        wr = [np.array(a) + _outward(np.array(a), cen[-1]) * offs[-1] for a in loops[-1]]
        axis = (cen[-1] - cen[-2]) / np.linalg.norm(cen[-1] - cen[-2])
        out_loops.append(wr)
        cuff = [q + axis * 0.014 + _outward(q, cen[-1] + axis * 0.014) * 0.002 for q in wr]
        out_loops.append(cuff)
        lip = [q + axis * 0.016 - _outward(q, cen[-1] + axis * 0.016) * 0.005 for q in cuff]
        out_loops.append(lip)
        inner = [q - axis * 0.02 - _outward(q, cen[-1]) * 0.003 for q in lip]
        out_loops.append(inner)
        base = len(verts)
        n = len(wr)
        for lp in out_loops:
            verts.extend(tuple(float(c) for c in q) for q in lp)
        pts_side = [np.array(v) for v in verts[base:]]
        cands = [[b for b in (f"upper_arm.{sfx}", f"forearm.{sfx}", f"hand.{sfx}")]] * len(pts_side)
        ws = body.skin_weights([tuple(q) for q in pts_side], float(p["height"]), cands)
        # the cuff and lip follow the forearm (the hand turns inside the cuff)
        for i in range(len(ws)):
            li = i // n
            if li >= len(out_loops) - 3:
                ws[i] = {f"forearm.{sfx}": 0.85, f"hand.{sfx}": 0.15}
        weights.extend(_top4(w) for w in ws)
        nl = len(out_loops)
        loop_c = [np.mean(np.array(lp), axis=0) for lp in out_loops]
        for li in range(nl - 1):
            for j in range(n):
                a = base + li * n + j
                b = base + li * n + (j + 1) % n
                c = base + (li + 1) * n + (j + 1) % n
                d = base + (li + 1) * n + j
                q = (a, b, c, d)
                fa = np.array(verts[a])
                nrm = np.cross(np.array(verts[b]) - fa, np.array(verts[d]) - fa)
                if li == nl - 3:                  # cuff end face: faces the hand
                    want = float(nrm @ axis)
                elif li == nl - 2:                # inside of the cuff: faces the arm
                    want = -float(nrm @ (fa - (loop_c[li] + loop_c[li + 1]) * 0.5))
                else:
                    want = float(nrm @ (fa - (loop_c[li] + loop_c[li + 1]) * 0.5))
                if want < 0.0:
                    q = (d, c, b, a)
                faces.append(q)
                mats.append("suit")
                face_uv.append(None)
    return {"verts": verts, "faces": faces, "mats": mats, "uvs": face_uv, "weights": weights,
            "height": float(p["height"])}


def _outward(p: np.ndarray, c: np.ndarray) -> np.ndarray:
    d = p - c
    n = float(np.linalg.norm(d))
    return d / n if n > 1e-9 else d


def _top4(w: dict) -> dict:
    top = sorted(w.items(), key=lambda kv: (-kv[1], kv[0]))[:4]
    tot = sum(x for _b, x in top) or 1.0
    return {b: x / tot for b, x in sorted(top)}


SUIT_COLOR = "#23262B"


def build_arms_mesh(ctx, arm_obj, params: dict) -> dict:
    """Create the skinned ``Arms`` mesh in camera space under ``arm_obj``: skin hands + suit sleeves, or
    with ``params["heister"]`` that crew heister's sleeve variant (``_arms_sleeves``)."""
    import bmesh  # noqa: PLC0415
    import bpy  # noqa: PLC0415

    import _body as body  # noqa: PLC0415
    from lib import scene  # noqa: PLC0415

    skin_id = int(body.body_params({k: x for k, x in params.items() if k != "heister"})["skin"])
    if params.get("heister"):
        import _arms_sleeves as sleeves  # noqa: PLC0415

        d = sleeves.variant_data(params)
    else:
        d = hands_data(params)
        d["slots"] = {"skin": f"char_skin_{skin_id}", "suit": "char_suit_dark"}
    eye = eye_point(d["height"])
    me = bpy.data.meshes.new("Arms")
    me.from_pydata([tuple(np.array(v) - eye) for v in d["verts"]], [], d["faces"])
    keys = list(d["slots"])
    for key in keys:
        me.materials.append(_slot_material(ctx, d["slots"][key]))
    me.polygons.foreach_set("material_index", [keys.index(m) for m in d["mats"]])
    me.validate(clean_customdata=False)
    me.update()
    # UVs: skin from the body's tiles; sleeves / gloves box-projected at the first-person density
    bm = bmesh.new()
    bm.from_mesh(me)
    layer = bm.loops.layers.uv.new("UVMap")
    box_faces = [f for f in bm.faces if d["uvs"][f.index] is None]
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        if d["uvs"][f.index] is not None:
            for loop, uvc in zip(f.loops, d["uvs"][f.index]):
                loop[layer].uv = uvc
    _box_suit(bm, layer, box_faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    obj = bpy.data.objects.new("Arms", me)
    scene.link(obj, arm_obj)
    groups = {}
    for b in BONES:
        if b in ("root", "weapon", "magazine"):
            continue
        groups[b] = obj.vertex_groups.new(name=b)
    per_bone: dict[str, list] = {b: [] for b in groups}
    for vi, w in enumerate(d["weights"]):
        for b, x in sorted(w.items()):
            per_bone[b].append((vi, x))
    for b in groups:
        for vi, x in per_bone[b]:
            groups[b].add([vi], x, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj
    mod.use_vertex_groups = True
    mod.use_bone_envelopes = False
    return {"Arms": obj, "tris": sum(len(f) - 2 for f in d["faces"])}


def _slot_material(ctx, lib_id: str):
    """Library material ``lib_id`` with its placeholder colour (skin tones from ``_body``, the rest from
    ``_outfit_palette``)."""
    import _body as body  # noqa: PLC0415
    import _outfit_palette as pal  # noqa: PLC0415

    if lib_id.startswith("char_skin_"):
        return ctx.material(lib_id, body.SKIN_TONES[int(lib_id[len("char_skin_"):]) - 1], roughness=0.55)
    if lib_id == "char_suit_dark":
        return ctx.material(lib_id, SUIT_COLOR, roughness=0.75)
    hexc, rough, metal = pal.spec(lib_id)
    return ctx.material(lib_id, hexc, roughness=rough, metallic=metal)


def _box_suit(bm, layer, faces) -> None:
    """Deterministic box projection for the sleeve faces (1024 px/m on a 1024 px texture)."""
    from lib import uv  # noqa: PLC0415

    k = uv.DENSITY_FIRST_PERSON / 1024.0
    for f in faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            c = loop.vert.co
            u, v = [(c.y, c.z), (c.x, c.z), (c.x, c.y)][ax]
            loop[layer].uv = (u * k, v * k)
