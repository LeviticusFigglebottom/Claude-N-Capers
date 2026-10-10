"""Marrow & Kell Warden .45 Pair: akimbo model (B4-12, D-050).

One Warden .45 (built by ``warden_45.build``) plus an ``Offhand`` marker: the rest pose of the second
(left-hand) gun relative to the right gun's grip pivot. The glb holds ONE gun; ``WeaponVisual`` instances
the same model a second time at ``Offhand`` and mirrors every mod onto it (``WeaponVisual.offhand``,
``get_offhand_marker``), so node names stay unique and both guns share the mod glbs. ENV A may reparent
the offhand gun to the left hand of the ``akimbo`` viewmodel set.

Origin = firing-hand pivot of the right gun. Forward = Godot -Z.
"""

import _common as c
import warden_45

ASSET_ID = "wpn_akimbo_warden_45"
TRI_BUDGET = 25000

# left gun 22 cm to the left of the right gun, same height, a little behind (relaxed two-gun stance)
OFFHAND_POS = (-0.220, -0.020, 0.0)


def build(ctx) -> None:
    warden_45.build(ctx)
    ctx.marker("Offhand", OFFHAND_POS)
    one = c.tris_of_scene()
    ctx.source_extra["tris_lod0"] = one
    ctx.source_extra["tris_pair"] = 2 * one
    ctx.source_extra["akimbo"] = "one gun in the glb; WeaponVisual instances it again at Offhand"
