"""``char_arms_fp_<heister>``: per-heister first-person sleeve meshes for ``char_arms_fp`` (D2-03 follow-up).

Mesh-only assets (no animations): the ``rig_arms`` armature of ``char_arms_fp`` (same bones, rest pose
and therefore the same Skeleton3D bone order and skin binds) and one skinned ``Arms`` mesh dressed
like the crew heister's third-person outfit (``fp_sleeve`` in ``char_crew_<heister>/SOURCE.txt``;
geometry in ``_arms_sleeves``). The clips stay once, in ``char_arms_fp``.

Godot (after import): ``<root>/rig_arms/Skeleton3D/Arms`` (MeshInstance3D with a Skin). Swap (ENV A,
``FpViewmodel``): instance the variant, then on ``char_arms_fp``'s ``Arms`` set ``mesh`` and ``skin`` to
the variant ``Arms``' ones and free the variant instance; the bone names and bind poses are identical
(tests/d/test_arms.gd), so the clips drive it unchanged. No variant (generic crew, unknown heister):
keep ``char_arms_fp``'s own suit sleeves.
"""

import _arms as arms
import _arms_sleeves as sleeves

TRI_BUDGET = 12000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False}
#: skin = the heister's body tone (char_crew.py); only Wren's bare forearm shows it.
VARIANTS = {
    "char_arms_fp_rook": {"heister": "rook", "skin": 3},
    "char_arms_fp_sable": {"heister": "sable", "skin": 5},
    "char_arms_fp_dutch": {"heister": "dutch", "skin": 1},
    "char_arms_fp_marten": {"heister": "marten", "skin": 3},
    "char_arms_fp_jay": {"heister": "jay", "skin": 4},
    "char_arms_fp_wren": {"heister": "wren", "skin": 2},
    "char_arms_fp_juno": {"heister": "juno", "skin": 1},
    "char_arms_fp_hale": {"heister": "hale", "skin": 6},
}


def build(ctx) -> None:
    arm = arms.build_arms_rig()
    params = {"heister": ctx.param("heister"), "skin": int(ctx.param("skin", 2))}
    mesh = arms.build_arms_mesh(ctx, arm, params)
    v = sleeves.VARIANTS[params["heister"]]
    ctx.source_extra["tris"] = mesh["tris"]
    ctx.source_extra["heister"] = params["heister"]
    ctx.source_extra["look"] = v.note
    ctx.source_extra["materials"] = ",".join(sorted({layer.mat for layer in v.layers} | {v.glove}
                                                    | ({f"char_skin_{params['skin']}"} if v.forearm_skin else set())))
    ctx.source_extra["layers"] = "; ".join(
        f"{layer.mat} u={layer.profile[0][0]:.3f}..{layer.profile[-1][0]:.3f} m"
        + (f" ribs={layer.ribs[0] // 2}" if layer.ribs else "") + (f" pleats={layer.pleats}" if layer.pleats else "")
        for layer in v.layers)
    ctx.source_extra["fp.variant"] = (
        "mesh-only sleeve variant of char_arms_fp (no AnimationPlayer): <root>/rig_arms/Skeleton3D/Arms, same "
        "rig_arms bones / rest / bind poses; ENV A puts this Arms' mesh + skin on char_arms_fp's Arms (the clips "
        "stay in char_arms_fp); the hands are glove-material hands (no skin under the glove)")
