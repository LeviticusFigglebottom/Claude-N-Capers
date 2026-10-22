"""Review-only proxies for the D2-04 non-gun sets (``_arms_review``); ENV B has no melee, throwable or
deployable models yet. Never exported. Each proxy is built in its item frame (``_arms_melee`` /
``_arms_items``: Blender weapon axes X right, Y forward / edge, Z up the handle / fuse), so it rides the
``weapon`` bone exactly as the real model would.
"""

from __future__ import annotations

import bpy
from mathutils import Matrix

from lib import materials

REVIEW_CELLS = {
    "melee_knife": ["melee_knife_idle:0", "melee_knife_swing:4", "melee_knife_swing:6", "melee_knife_swing:9",
                    "melee_knife_charge:0", "melee_knife_charge_swing:5", "melee_knife_draw:6", "melee_knife_sprint:4",
                    "rifle_bash:7"],
    "melee_blunt": ["melee_blunt_idle:0", "melee_blunt_swing:6", "melee_blunt_swing:10", "melee_blunt_swing:13",
                    "melee_blunt_charge:0", "melee_blunt_charge_swing:7", "melee_blunt_sprint:4", "pistol_bash:6",
                    "minigun_bash:10"],
    "melee_blade": ["melee_blade_idle:0", "melee_blade_swing:5", "melee_blade_swing:9", "melee_blade_swing:12",
                    "melee_blade_charge:0", "melee_blade_charge_swing:7", "melee_blade_sprint:4", "shotgun_bash:7",
                    "akimbo_bash:6"],
    "melee_heavy": ["melee_heavy_idle:0", "melee_heavy_swing:7", "melee_heavy_swing:13", "melee_heavy_swing:17",
                    "melee_heavy_charge_start:30", "melee_heavy_charge_swing:9", "melee_heavy_charge_swing:14",
                    "melee_heavy_sprint:4", "melee_heavy_draw:10"],
    "throwable": ["throwable_draw:6", "throwable_draw:9", "throwable_idle:0", "throwable_throw:6", "throwable_throw:11",
                  "throwable_throw:14", "throwable_throw_low:6", "throwable_throw_low:12", "throwable_sprint:4"],
    "deploy_bag": ["deploy_bag_draw:8", "deploy_bag_idle:0", "deploy_bag_place:11", "deploy_bag_place:33",
                   "deploy_bag_place:57", "deploy_bag_place:64", "deploy_small_idle:0", "deploy_small_place:40",
                   "deploy_small_place:58"],
    "deploy_sentry": ["deploy_sentry_draw:12", "deploy_sentry_idle:0", "deploy_sentry_place:11", "deploy_sentry_place:33",
                      "deploy_sentry_place:57", "deploy_sentry_place:64", "deploy_small_draw:6", "deploy_small_place:20",
                      "deploy_small_place:66"],
}


def _mats():
    return {"steel": materials.material("ri_steel", "#9EA3A8", 0.3), "dark": materials.material("ri_dark", "#1C1D20", 0.55),
            "olive": materials.material("ri_olive", "#4B5233", 0.6), "red": materials.material("ri_red", "#A0322A", 0.45),
            "tan": materials.material("ri_tan", "#8A7452", 0.7), "grey": materials.material("ri_grey", "#3A3F45", 0.5),
            "green": materials.material("ri_green", "#2F6B3A", 0.5)}


def build(name: str) -> dict:
    """{"item": [objects in the item frame], "ring": [the grenade's pin ring]}."""
    from _arms_review import _box
    from _arms_review_b3 import _cyl

    m = _mats()
    out: dict = {"item": [], "ring": []}
    add = out["item"].extend
    if name == "melee_knife":
        add([_box("KnHandle", (-0.011, -0.014, -0.075), (0.011, 0.014, 0.035), m["dark"], 0.004),
             _box("KnGuard", (-0.013, -0.020, 0.035), (0.013, 0.020, 0.042), m["steel"]),
             _box("KnBlade", (-0.0018, -0.016, 0.042), (0.0018, 0.012, 0.165), m["steel"]),
             _box("KnTip", (-0.0018, -0.006, 0.165), (0.0018, 0.008, 0.185), m["steel"])])
    elif name == "melee_blunt":
        add([_cyl("BtGrip", (0, 0, -0.080), (0, 0, 0.040), 0.016, m["dark"]),
             _cyl("BtShaft", (0, 0, 0.040), (0, 0, 0.480), 0.014, m["grey"]),
             _cyl("BtTip", (0, 0, 0.480), (0, 0, 0.500), 0.017, m["dark"])])
    elif name == "melee_blade":
        add([_box("McHandle", (-0.012, -0.015, -0.085), (0.012, 0.015, 0.035), m["tan"], 0.004),
             _box("McBlade", (-0.0015, -0.030, 0.035), (0.0015, 0.010, 0.440), m["steel"]),
             _box("McTip", (-0.0015, -0.020, 0.440), (0.0015, 0.004, 0.470), m["steel"])])
    elif name == "melee_heavy":          # stand-in two-handed sledge: handle -0.33..+0.55, head at +0.55 (v1.38)
        add([_cyl("HvHandle", (0, 0, -0.330), (0, 0, 0.520), 0.017, m["tan"]),
             _box("HvHead", (-0.040, -0.110, 0.520), (0.040, 0.110, 0.600), m["steel"], 0.006)])
    elif name == "throwable":
        add([_cyl("GrBody", (0, 0, -0.045), (0, 0, 0.030), 0.029, m["olive"], 24),
             _cyl("GrFuse", (0, 0, 0.030), (0, 0, 0.055), 0.010, m["steel"], 12),
             _box("GrSpoon", (0.006, -0.006, -0.020), (0.016, 0.006, 0.055), m["steel"])])
        out["ring"].append(_cyl("GrRing", (-0.030, -0.008, 0.040), (-0.030, 0.008, 0.040), 0.011, m["steel"], 12))
    elif name == "deploy_bag":           # handle bar at the frame origin, the bag hanging under it
        add([_box("BagBody", (-0.21, -0.12, -0.30), (0.21, 0.12, -0.045), m["green"], 0.02),
             _box("BagCross", (-0.06, -0.122, -0.22), (0.06, 0.122, -0.12), m["red"]),
             _cyl("BagBar", (-0.06, 0, 0), (0.06, 0, 0), 0.011, m["dark"], 12),
             _box("BagStrapL", (-0.07, -0.01, -0.05), (-0.055, 0.01, 0.0), m["dark"]),
             _box("BagStrapR", (0.055, -0.01, -0.05), (0.07, 0.01, 0.0), m["dark"])])
    elif name == "deploy_small":         # an ECM box lying in the palm, antennas forward
        add([_box("EcmBody", (-0.065, -0.040, -0.016), (0.065, 0.040, 0.016), m["grey"], 0.004),
             _box("EcmPanel", (-0.045, -0.030, 0.016), (0.045, 0.030, 0.019), m["dark"]),
             _cyl("EcmAntL", (-0.050, 0.040, 0.0), (-0.050, 0.110, 0.0), 0.003, m["dark"], 8),
             _cyl("EcmAntR", (0.050, 0.040, 0.0), (0.050, 0.110, 0.0), 0.003, m["dark"], 8),
             _box("EcmLed", (0.020, -0.010, 0.019), (0.030, 0.000, 0.022), m["red"])])
    elif name == "deploy_sentry":        # right side handle at the origin, the case to its left
        add([_box("SnCase", (-0.345, -0.15, -0.16), (-0.015, 0.15, 0.13), m["olive"], 0.01),
             _box("SnHandleR", (-0.015, -0.06, -0.01), (0.0, 0.06, 0.01), m["dark"]),
             _box("SnHandleL", (-0.36, -0.06, -0.01), (-0.345, 0.06, 0.01), m["dark"]),
             _cyl("SnBarrel", (-0.18, 0.15, 0.06), (-0.18, 0.30, 0.06), 0.015, m["dark"], 12)])
    return out


def pose(pr: dict, Mg: Matrix, st) -> None:
    for o in pr["item"]:
        o.matrix_world = Mg
        o.hide_render = not st.extra.get("item", True)
    for o in pr["ring"]:
        o.matrix_world = Mg
        o.hide_render = not st.extra.get("pin", False) or not st.extra.get("item", True)


_ = (bpy,)
