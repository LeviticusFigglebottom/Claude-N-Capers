"""Shotgun ammunition (D-118), shared by the Plowman 12, Brute 12, Harrow 12, Mule 12 and Reaper Double.

AMMO has no attach marker (WeaponVisual.MARKER_FOR_MOD_TYPE), so these scenes are never put on the gun: each is
a small icon model for the workshop / armory (an open shell caddy with three shells whose hull colour tells
the load). Origin = bottom centre, +Y forward.

* ``mod_shotgun_slug``            AMMO (olive hulls)
* ``mod_shotgun_he``              AMMO (tan hulls)
* ``mod_shotgun_flechette``       AMMO (dark anodised hulls)
* ``mod_shotgun_dragons_breath``  AMMO (glowing red hulls)
"""

import _common as c

TRI_BUDGET = 25000
VARIANTS = {
    "mod_shotgun_slug": {"part": "slug"},
    "mod_shotgun_he": {"part": "he"},
    "mod_shotgun_flechette": {"part": "flechette"},
    "mod_shotgun_dragons_breath": {"part": "dragons_breath"},
}

SHELL_R = 0.0100
SHELL_LEN = 0.065
CADDY_HX = 0.040
CADDY_HY = 0.036
CADDY_H = 0.022


def _hull(mats: c.Mats, part: str):
    return {"slug": mats.olive, "he": mats.tan, "flechette": mats.alu, "dragons_breath": mats.reticle}[part]()


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if "mod_shotgun_" + part not in VARIANTS:
        raise ValueError(f"unknown part {part!r}")
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    # open caddy: floor + four low walls
    t = 0.003
    mb.box((-CADDY_HX, -CADDY_HY, 0.0), (CADDY_HX, CADDY_HY, t), mat=poly)
    mb.box((-CADDY_HX, -CADDY_HY, t), (-CADDY_HX + t, CADDY_HY, CADDY_H), mat=poly)
    mb.box((CADDY_HX - t, -CADDY_HY, t), (CADDY_HX, CADDY_HY, CADDY_H), mat=poly)
    mb.box((-CADDY_HX + t, -CADDY_HY, t), (CADDY_HX - t, -CADDY_HY + t, CADDY_H), mat=poly)
    mb.box((-CADDY_HX + t, CADDY_HY - t, t), (CADDY_HX - t, CADDY_HY, CADDY_H), mat=poly)
    caddy = c.finish(mb, "AmmoCaddy", bevel=0.0008)
    # three shells lying across the caddy, heads to the left, a hull colour per load
    hull = _hull(mats, part)
    for i, y in enumerate((-0.022, 0.0, 0.022)):
        sb = ctx.builder()
        hm = sb.material(hull)
        br = sb.material(mats.brass())
        z = t + SHELL_R + 0.0005
        body_len = SHELL_LEN - 0.012
        sb.cylinder(SHELL_R, body_len, segments=16, centre=(0.006, y, z), axis="X", mat=hm)
        sb.cylinder(SHELL_R + 0.0006, 0.012, segments=16, centre=(0.006 - (body_len + 0.012) / 2, y, z), axis="X",
                    mat=br)
        c.finish(sb, f"AmmoShell{i}", bevel=0.0004, parent=caddy)
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
