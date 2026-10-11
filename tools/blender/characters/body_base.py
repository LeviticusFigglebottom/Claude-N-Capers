"""Base humanoid bodies on ``rig_humanoid`` (D1-01): the shared skeleton plus the parametric GSR body.

Each variant is one glb with the armature ``rig_humanoid`` (52 bones, A-pose, see ``_rig.py``), a
skinned ``Body`` mesh (head, eyes, ears, brows and hands included) with shape keys ``build``,
``gender``, ``age`` (default weights = the variant's values) and, unless ``hair`` is "none", a
skinned ``Hair`` mesh with the same shape keys. Outfits and characters import ``_rig``/``_body``
and build on top of this; these assets are the reference bodies and the rig test fixture.

Godot (after import): ``<root>/rig_humanoid/Skeleton3D/{Body,Hair}``; facing -Z, feet at y = 0.
"""

import _body as body
import _rig as rig
import _tri

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": True}

VARIANTS = {
    "char_body_base": {"height": 1.78, "build": 0.4, "gender": 0.0, "age": 0.25, "skin": 2,
                       "hair": "short", "hair_color": "dark"},
    "char_body_base_heavy": {"height": 1.80, "build": 1.0, "gender": 0.0, "age": 0.35, "skin": 4,
                             "hair": "buzz", "hair_color": "brown"},
    "char_body_base_fem": {"height": 1.68, "build": 0.35, "gender": 1.0, "age": 0.2, "skin": 3,
                           "hair": "bob", "hair_color": "brown"},
    "char_body_base_old": {"height": 1.74, "build": 0.45, "gender": 0.0, "age": 1.0, "skin": 1,
                           "hair": "short", "hair_color": "grey"},
}


def build(ctx) -> None:
    params = body.body_params(ctx.params)
    arm = rig.build_rig(ctx, params["height"])
    out = body.build_body(ctx, arm, params)
    for name in ("Body", "Hair"):
        if out[name] is not None:
            _tri.triangulate(out[name])
    ctx.source_extra["bones"] = len(rig.BONES)
    ctx.source_extra["body_tris"] = out["tris"]
    ctx.source_extra["shape_keys"] = ",".join(body.SHAPE_KEYS)
