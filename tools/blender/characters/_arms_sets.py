"""First-person animation sets for ``rig_arms`` (D1-03 pistol, D-034 smg / rifle / shotgun / lmg /
sniper): pure data. Private helper of ``_arms`` / ``_arms_clips``.

Units: metres, degrees, frames at 30 fps. Camera space = the ``rig_arms`` root (Blender axes: +X
right, +Y forward, +Z up; Godot -Z forward). Weapon space = the weapon scene's own axes in Blender
terms (X right, Y muzzle, Z up) relative to its origin, the firing-hand pivot (visual_slots QB-22).
Marker positions are measured from the shipped weapon glbs (``game/assets/weapons/wpn_*``).

A hold is ``(pivot, yaw, pitch, roll)``: the weapon origin in camera space, then yaw (+ = muzzle
left), pitch (+ = muzzle up) and roll (+ = canted right) in degrees (``_anim.weapon_frame``).

Clip lengths follow the weapon data (``game/content/data/weapons/*.tres``): reload / reload_empty
= ``reload_time_s`` / ``reload_empty_time_s`` x 30, draw / holster = ceil(``equip_time_s`` x 30);
the full-auto ``fire`` clips (3 f) are no longer than 1.5 shot intervals at the weapon's rpm so the
game can restart them every shot (the kick peaks on frame 1, the clip is near rest when retriggered).
``shotgun_reload_loop`` imports as LOOP_LINEAR (Godot's ``_loop`` name suffix); it is seamless, so
the game can let it loop and stop it after n x its length (or replay it per round).
"""

from __future__ import annotations

import math
import pathlib
import re
from dataclasses import dataclass, field

import numpy as np

from _anim import rxd, v3


@dataclass
class FPSet:
    """A first-person animation set for one ``WeaponDef.anim_set``."""

    name: str
    weapon: str                          # review weapon asset (wpn_<id>)
    markers: dict                        # weapon space: left_ik, aim, magwell (+ magwell_axis), ...
    hip: tuple                           # hold at rest (hip fire, PD2: low right)
    ads_dist: float                      # AimPoint distance in front of the eye (m), on the view axis
    sprint: tuple
    lowered: tuple                       # drawn-from / holstered-to (off screen)
    reload_tilt: tuple                   # the hold while the left hand works (mag change ...)
    support: str = "handguard"           # left-hand hold: pistol | handguard | pump
    blade: float = 0.0                   # torso yaw (deg, + = left shoulder forward): bladed stance
    blade_ads: float = 0.0
    reload: str = "mag"                  # mag | shells | box
    recoil: dict = field(default_factory=dict)       # hip: back, up (m), pitch, roll, yaw (deg)
    recoil_ads: dict = field(default_factory=dict)
    mag: dict = field(default_factory=dict)          # top / bottom along the axis (m), hw, depth
    clips: dict = field(default_factory=dict)        # clip -> {"frames", "loop", "events"}
    pouch: tuple = (-0.13, 0.12, -0.56)              # left hand at the belt pouch (off screen)
    sh: tuple = (0.0, 0.0, 0.0)                      # shoulder offset (camera space, both shoulders)
    pole_l: tuple = (-0.85, -0.2, -0.5)              # elbow directions of the two-handed hold (hip)
    pole_l_ads: tuple = (-0.5, -0.15, -0.85)         # ... and in ADS
    pole_r: tuple = (0.75, -0.2, -0.65)
    ads_hold: tuple | None = None                    # akimbo: an ADS hold instead of sight alignment

    def frames(self, clip: str) -> int:
        return int(self.clips[clip]["frames"])

    def ev(self, clip: str) -> dict:
        return dict(self.clips[clip].get("events", {}))


def _std(frames_draw: int, fire: int, fire_ev: dict | None = None) -> dict:
    """The clips every set has (idle / ads_idle / sprint loop; draw / holster; fire / fire_ads)."""
    fev = fire_ev or {"shot": 0}
    return {
        "idle": {"frames": 90, "loop": True},
        "ads_idle": {"frames": 90, "loop": True},
        "sprint": {"frames": 18, "loop": True},
        "draw": {"frames": frames_draw, "loop": False, "events": {"ready": frames_draw}},
        "holster": {"frames": frames_draw, "loop": False, "events": {"gone": frames_draw}},
        "fire": {"frames": fire, "loop": False, "events": dict(fev)},
        "fire_ads": {"frames": fire, "loop": False, "events": dict(fev)},
    }


# -- pistol (Kestrel P9; the Warden .45 shares it) ---------------------------------------------
_P9_RAKE = 18.0
PISTOL = FPSet(
    name="pistol", weapon="wpn_kestrel_p9",
    markers={"left_ik": v3(-0.025, 0.0115, -0.020), "aim": v3(0.0, -0.030, 0.0665),
             "magwell": v3(0.0, -0.0227, -0.070), "magwell_axis": rxd(-_P9_RAKE) @ v3(0.0, 0.0, 1.0),
             "slide_rear": v3(0.0, -0.030, 0.050)},
    hip=((0.105, 0.36, -0.175), 5.0, 2.0, -4.0),
    ads_dist=0.31, sh=(0.0, 0.02, -0.08),
    pole_l=(-0.22, -0.25, -0.94), pole_l_ads=(-0.22, -0.25, -0.94), pole_r=(0.22, -0.25, -0.94),
    sprint=((0.15, 0.28, -0.205), 14.0, -22.0, -32.0),
    lowered=((0.16, 0.20, -0.46), 10.0, -55.0, -30.0),
    reload_tilt=((0.07, 0.36, -0.16), 16.0, 22.0, 30.0),
    support="pistol", blade=6.0, blade_ads=0.0,
    recoil={"back": 0.030, "up": 0.012, "pitch": 9.0, "roll": 1.5, "yaw": 0.6},
    recoil_ads={"back": 0.020, "up": 0.006, "pitch": 5.0, "roll": 0.8, "yaw": 0.3},
    mag={"top": 0.094, "bottom": -0.014, "hw": 0.014, "depth": 0.034, "grip": "base"},
    clips={**_std(11, 6),
           "reload": {"frames": 45, "loop": False,
                      "events": {"mag_out": 6, "mag_swap": 15, "mag_in": 29, "done": 38}},
           "reload_empty": {"frames": 63, "loop": False,
                            "events": {"mag_out": 6, "mag_swap": 15, "mag_in": 29, "slide_release": 45,
                                       "done": 56}}},
)

# -- smg (Hornet 9: 800 rpm = 2.25 frames per shot) ---------------------------------------------
SMG = FPSet(
    name="smg", weapon="wpn_hornet_9",
    markers={"left_ik": v3(-0.031, 0.160, 0.040), "aim": v3(0.0, -0.060, 0.1172),
             "magwell": v3(0.0, 0.101, -0.002), "magwell_axis": rxd(4.0) @ v3(0.0, 0.0, 1.0),
             "cock": v3(-0.040, 0.171, 0.085), "cock_back": v3(-0.040, 0.128, 0.085),
             "butt": v3(0.0, -0.330, 0.050)},
    hip=((0.13, 0.23, -0.175), 7.0, 1.0, -6.0),
    ads_dist=0.13,
    sprint=((0.16, 0.22, -0.21), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.08, -0.55), 20.0, -55.0, -35.0),
    reload_tilt=((0.075, 0.225, -0.155), 12.0, 14.0, 30.0),
    support="handguard", blade=38.0, blade_ads=44.0,
    recoil={"back": 0.018, "up": 0.006, "pitch": 2.6, "roll": 0.8, "yaw": 0.5},
    recoil_ads={"back": 0.012, "up": 0.003, "pitch": 1.4, "roll": 0.4, "yaw": 0.3},
    mag={"top": 0.034, "bottom": -0.134, "hw": 0.0115, "depth": 0.032, "grip": "side"},
    clips={**_std(14, 3),
           "reload": {"frames": 66, "loop": False,
                      "events": {"mag_out": 13, "mag_swap": 23, "mag_in": 39, "done": 56}},
           "reload_empty": {"frames": 90, "loop": False,
                            "events": {"mag_out": 13, "mag_swap": 23, "mag_in": 39, "bolt_release": 64,
                                       "done": 80}}},
)

# -- rifle (Corsair AR: 700 rpm = 2.6 frames per shot) ------------------------------------------
RIFLE = FPSet(
    name="rifle", weapon="wpn_corsair_ar",
    markers={"left_ik": v3(-0.0315, 0.330, 0.067), "aim": v3(0.0, -0.060, 0.1212),
             "magwell": v3(0.0, 0.1235, -0.012), "magwell_axis": rxd(8.0) @ v3(0.0, 0.0, 1.0),
             "catch": v3(-0.017, 0.098, 0.042), "butt": v3(0.0, -0.300, 0.030)},
    hip=((0.13, 0.20, -0.18), 7.0, 1.0, -6.0),
    ads_dist=0.13,
    sprint=((0.15, 0.21, -0.22), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.06, -0.56), 20.0, -55.0, -35.0),
    reload_tilt=((0.075, 0.20, -0.165), 12.0, 14.0, 30.0),
    support="handguard", blade=44.0, blade_ads=48.0,
    recoil={"back": 0.020, "up": 0.007, "pitch": 2.8, "roll": 0.9, "yaw": 0.5},
    recoil_ads={"back": 0.014, "up": 0.003, "pitch": 1.5, "roll": 0.5, "yaw": 0.3},
    mag={"top": 0.038, "bottom": -0.124, "hw": 0.0115, "depth": 0.060, "grip": "side"},
    clips={**_std(17, 3),
           "reload": {"frames": 72, "loop": False,
                      "events": {"mag_out": 14, "mag_swap": 25, "mag_in": 43, "done": 61}},
           "reload_empty": {"frames": 93, "loop": False,
                            "events": {"mag_out": 14, "mag_swap": 25, "mag_in": 43, "bolt_release": 62,
                                       "done": 82}}},
)

# -- shotgun (Plowman 12 pump: 70 rpm = 25.7 frames per shot; the pump is part of fire) ---------
#: Shell-by-shell: reload_start + n x reload_loop + reload_end; with the data's 6-round tube the
#: composite ``reload`` / ``reload_empty`` clips (12 + 6 x 13 + 12 = 102 f = 3.4 s; 12 + 78 + 36 =
#: 126 f = 4.2 s) match reload_time_s / reload_empty_time_s exactly.
SHOTGUN_SHELLS = 6
PUMP_TRAVEL = 0.075
SHELL_START, SHELL_LOOP, SHELL_END, SHELL_END_EMPTY = 12, 13, 12, 36


def _shell_events(empty: bool) -> dict:
    """Events of the composite shotgun reload: reload_start + 6 x reload_loop + reload_end(_empty)."""
    ev = {f"shell_in_{i + 1}": SHELL_START + i * SHELL_LOOP + 8 for i in range(SHOTGUN_SHELLS)}
    end0 = SHELL_START + SHOTGUN_SHELLS * SHELL_LOOP
    if empty:
        ev.update({"pump_back": end0 + 17, "pump_forward": end0 + 23, "done": end0 + 32})
    else:
        ev["done"] = end0 + 10
    return ev


SHOTGUN = FPSet(
    name="shotgun", weapon="wpn_plowman_12",
    markers={"left_ik": v3(-0.026, 0.390, 0.0285), "aim": v3(0.0, 0.100, 0.1032),
             "magwell": v3(0.0, 0.172, 0.008), "magwell_axis": v3(0.0, -0.20, 0.98),
             "butt": v3(0.0, -0.360, -0.010)},
    hip=((0.13, 0.19, -0.18), 7.0, 1.5, -6.0),
    ads_dist=0.11,
    sprint=((0.15, 0.21, -0.22), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.06, -0.56), 20.0, -55.0, -35.0),
    reload_tilt=((0.07, 0.22, -0.15), 16.0, 14.0, 48.0),
    support="pump", blade=44.0, blade_ads=48.0, reload="shells",
    recoil={"back": 0.045, "up": 0.016, "pitch": 9.0, "roll": 2.0, "yaw": 1.0},
    recoil_ads={"back": 0.032, "up": 0.010, "pitch": 6.0, "roll": 1.2, "yaw": 0.6},
    clips={**_std(17, 24, {"shot": 0, "pump_back": 9, "pump_forward": 14, "done": 21}),
           "reload_start": {"frames": 12, "loop": False, "events": {"ready": 12}},
           "reload_loop": {"frames": 13, "loop": False, "events": {"shell_in": 8, "done": 13}},
           "reload_end": {"frames": 12, "loop": False, "events": {"done": 10}},
           "reload_end_empty": {"frames": 36, "loop": False,
                                "events": {"pump_back": 17, "pump_forward": 23, "done": 32}},
           "reload": {"frames": 102, "loop": False, "events": _shell_events(False)},
           "reload_empty": {"frames": 126, "loop": False, "events": _shell_events(True)}},
)

# -- lmg (Rampart: 750 rpm = 2.4 frames per shot; belt box) -------------------------------------
LMG = FPSet(
    name="lmg", weapon="wpn_rampart_lmg",
    markers={"left_ik": v3(-0.0385, 0.360, 0.066), "aim": v3(0.0, -0.005, 0.1542),
             "magwell": v3(0.0, 0.150, 0.020), "magwell_axis": v3(0.0, 0.0, 1.0),
             "cover_rear": v3(0.0, -0.022, 0.134), "cover_hinge": v3(0.0, 0.160, 0.124),
             "feed": v3(-0.027, 0.062, 0.100), "charge": v3(0.040, 0.205, 0.090),
             "butt": v3(0.0, -0.390, 0.040)},
    hip=((0.135, 0.195, -0.205), 7.0, 1.0, -6.0),
    ads_dist=0.13,
    sprint=((0.16, 0.20, -0.25), 26.0, -8.0, -36.0),
    lowered=((0.16, 0.05, -0.58), 20.0, -55.0, -35.0),
    reload_tilt=((0.07, 0.205, -0.20), 18.0, 14.0, -16.0),
    support="handguard", blade=36.0, blade_ads=40.0, reload="box",
    recoil={"back": 0.022, "up": 0.007, "pitch": 2.4, "roll": 1.0, "yaw": 0.6},
    recoil_ads={"back": 0.015, "up": 0.004, "pitch": 1.3, "roll": 0.5, "yaw": 0.3},
    mag={"top": 0.0, "bottom": -0.105, "hw": 0.040, "depth": 0.104, "grip": "box"},
    clips={**_std(27, 3),
           "reload": {"frames": 168, "loop": False,
                      "events": {"cover_open": 24, "mag_out": 54, "mag_in": 100, "belt_seat": 116,
                                 "cover_close": 132, "done": 156}},
           "reload_empty": {"frames": 198, "loop": False,
                            "events": {"cover_open": 24, "mag_out": 54, "mag_in": 100, "belt_seat": 116,
                                       "cover_close": 132, "charge": 160, "done": 186}}},
)

# -- sniper (Heron .308 bolt action: 50 rpm = 36 frames per shot = fire 9 + bolt 27) ------------
BOLT_LIFT_DEG = 62.0
BOLT_TRAVEL = 0.075
SNIPER = FPSet(
    name="sniper", weapon="wpn_heron_308",
    markers={"left_ik": v3(-0.032, 0.400, 0.040), "aim": v3(0.0, -0.010, 0.1422),
             "magwell": v3(0.0, 0.135, 0.022), "magwell_axis": v3(0.0, 0.0, 1.0),
             "knob": v3(0.047, 0.016, 0.044), "bore": v3(0.0, 0.0, 0.078),
             "butt": v3(0.0, -0.380, 0.020)},
    hip=((0.13, 0.18, -0.19), 7.0, 1.0, -6.0),
    ads_dist=0.10,
    sprint=((0.15, 0.20, -0.23), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.05, -0.57), 20.0, -55.0, -35.0),
    reload_tilt=((0.075, 0.195, -0.17), 12.0, 12.0, 28.0),
    support="handguard", blade=44.0, blade_ads=48.0,
    recoil={"back": 0.040, "up": 0.014, "pitch": 6.0, "roll": 1.6, "yaw": 0.8},
    recoil_ads={"back": 0.030, "up": 0.008, "pitch": 4.0, "roll": 1.0, "yaw": 0.5},
    mag={"top": 0.032, "bottom": -0.016, "hw": 0.0125, "depth": 0.056, "grip": "base"},
    clips={**_std(24, 9),
           "bolt": {"frames": 27, "loop": False,
                    "events": {"bolt_open": 8, "bolt_back": 12, "bolt_forward": 15, "bolt_close": 18,
                               "done": 25}},
           "bolt_ads": {"frames": 27, "loop": False,
                        "events": {"bolt_open": 8, "bolt_back": 12, "bolt_forward": 15, "bolt_close": 18,
                                   "done": 25}},
           "reload": {"frames": 90, "loop": False,
                      "events": {"mag_out": 15, "mag_swap": 28, "mag_in": 50, "done": 76}},
           "reload_empty": {"frames": 114, "loop": False,
                            "events": {"mag_out": 15, "mag_swap": 28, "mag_in": 50, "bolt_open": 72,
                                       "bolt_back": 76, "bolt_forward": 79, "bolt_close": 83, "done": 102}}},
)

# =============================================================================================
# D-050 (B4-12): akimbo, revolver, pistol full-auto. Lengths come from ENV B's weapon data when it
# exists (the first ``game/content/data/weapons/*.tres`` with that ``anim_set``, sorted by file
# name), else from the defaults below; event frames are laid out as fractions of the clip length.
# =============================================================================================
WEAPONS_DIR = pathlib.Path(__file__).resolve().parents[3] / "game" / "content" / "data" / "weapons"
_RX_KV = re.compile(r"^(\w+) = (.+)$")


def weapon_data(anim_set: str, want=None) -> dict:
    """``{field: value}`` of the first weapon .tres using ``anim_set`` (base stats as floats, plus
    ``id`` / ``fire_modes`` strings), filtered by ``want(row)``; {} when there is none."""
    if not WEAPONS_DIR.is_dir():
        return {}
    for path in sorted(WEAPONS_DIR.glob("*.tres")):
        row: dict = {}
        for line in path.read_text().splitlines():
            m = _RX_KV.match(line.strip())
            if not m:
                continue
            k, v = m.group(1), m.group(2).strip()
            if k in ("anim_set", "id", "fire_modes"):
                row[k] = v
            else:
                try:
                    row.setdefault(k, float(v))
                except ValueError:
                    pass
        if row.get("anim_set", "").strip('&"') == anim_set and (want is None or want(row)):
            return row
    return {}


def data_frames(row: dict, key: str, default_s: float, up: bool = False) -> int:
    """Clip frames from a data time (``up``: ceil, the draw / equip rule), else from ``default_s``."""
    t = float(row.get(key, default_s))
    return int(math.ceil(t * 30.0 - 0.001)) if up else int(round(t * 30.0))


# -- pistol full-auto (Sparrow MP machine pistol, ~880 rpm = 2.05 frames per shot) -------------
#: 3 f = 1.46 shot intervals at 880 rpm: restarted every shot like the other full-auto clips.
PISTOL_AUTO_FRAMES = 3
PISTOL.clips["fire_auto"] = {"frames": PISTOL_AUTO_FRAMES, "loop": False, "events": {"shot": 0}}
PISTOL.clips["fire_auto_ads"] = {"frames": PISTOL_AUTO_FRAMES, "loop": False, "events": {"shot": 0}}
#: a small snappy kick (fraction of the pistol's semi-auto recoil)
PISTOL_AUTO_RECOIL = 0.45


# -- akimbo (a pair of Warden .45; the left gun rides hand.L at the mirrored grip offset) --------
#: Default lengths (s) until ENV B's akimbo data exists: reload 2.0, reload_empty 2.6, equip 0.5.
AKIMBO_DEFAULTS = {"reload_time_s": 2.0, "reload_empty_time_s": 2.6, "equip_time_s": 0.5}
#: fire / fire_l (and _ads) are 3 f, under one shot interval up to 600 rpm (the Warden is 400), so an
#: alternating fire_l never cuts a running fire kick short.
AKIMBO_FIRE = 3


def _akimbo_clips(row: dict) -> dict:
    get = {k: row.get(k, d) for k, d in AKIMBO_DEFAULTS.items()}
    n_r = data_frames(get, "reload_time_s", 2.0)
    n_e = data_frames(get, "reload_empty_time_s", 2.6)
    n_d = data_frames(get, "equip_time_s", 0.5, up=True)
    mo_r = round(0.13 * n_r)
    mi_r = round(0.50 * n_r)
    rel = {"mag_out_r": mo_r, "mag_out_l": mo_r + 2, "mag_in_r": mi_r, "mag_in_l": mi_r + 3, "done": n_r - 8}
    mo_e = round(0.10 * n_e)
    mi_e = round(0.385 * n_e)
    sr_e = round(0.655 * n_e)
    emp = {"mag_out_r": mo_e, "mag_out_l": mo_e + 2, "mag_in_r": mi_e, "mag_in_l": mi_e + 3,
           "slide_release_r": sr_e, "slide_release_l": sr_e + 4, "done": n_e - 9}
    out = _std(n_d, AKIMBO_FIRE)
    out["fire_l"] = {"frames": AKIMBO_FIRE, "loop": False, "events": {"shot": 0}}
    out["fire_ads_l"] = {"frames": AKIMBO_FIRE, "loop": False, "events": {"shot": 0}}
    out["reload"] = {"frames": n_r, "loop": False, "events": rel}
    out["reload_empty"] = {"frames": n_e, "loop": False, "events": emp}
    return out


_W45_RAKE = 18.0
AKIMBO_DATA = weapon_data("akimbo")
AKIMBO = FPSet(
    name="akimbo", weapon="wpn_warden_45",
    markers={"left_ik": v3(-0.024, 0.0114, -0.020), "aim": v3(0.0, -0.034, 0.066),
             "magwell": v3(0.0, -0.0232, -0.076), "magwell_axis": rxd(-_W45_RAKE) @ v3(0.0, 0.0, 1.0),
             "slide_rear": v3(0.0, -0.034, 0.050)},
    # the right gun; the left one is its mirror image (x -> -x, yaw and roll negated)
    hip=((0.145, 0.36, -0.19), 3.0, 2.0, -5.0),
    ads_dist=0.31, ads_hold=((0.082, 0.34, -0.128), 1.5, 1.0, -3.0), sh=(0.0, 0.02, -0.08),
    pole_l=(-0.55, -0.3, -0.78), pole_l_ads=(-0.55, -0.3, -0.78), pole_r=(0.55, -0.3, -0.78),
    sprint=((0.17, 0.28, -0.20), 8.0, -28.0, -15.0),
    lowered=((0.17, 0.20, -0.47), 6.0, -55.0, -20.0),
    reload_tilt=((0.105, 0.34, -0.15), 10.0, 18.0, -42.0),
    support="akimbo", blade=0.0, blade_ads=0.0, reload="akimbo",
    recoil={"back": 0.030, "up": 0.012, "pitch": 10.0, "roll": 1.5, "yaw": 0.6},
    recoil_ads={"back": 0.022, "up": 0.007, "pitch": 6.0, "roll": 0.8, "yaw": 0.3},
    mag={"top": 0.087, "bottom": -0.010, "hw": 0.009, "depth": 0.030, "grip": "base"},
    clips=_akimbo_clips(AKIMBO_DATA),
)


# -- revolver (Marshal .357, 6 rounds, speedloader) ----------------------------------------------
#: Weapon parts (Blender weapon space, the scratch review proxy and the proposed marshal model):
#: ``Crane`` hinges on an axis parallel to the bore below-left of the cylinder and swings out to the
#: left by CRANE_OPEN_DEG (+ about its local Godot Z); its child ``Cylinder`` turns CYLINDER_STEP_DEG
#: per shot about its own axis. ``Speedloader`` rides the ``magazine`` bone.
CRANE_OPEN_DEG = 80.0
CYLINDER_STEP_DEG = 60.0
REVOLVER_ROUNDS = 6
REVOLVER_DEFAULTS = {"reload_time_s": 2.4, "equip_time_s": 0.45}
REVOLVER_FIRE = 9


def _revolver_clips(row: dict) -> dict:
    get = {k: row.get(k, d) for k, d in REVOLVER_DEFAULTS.items()}
    n_r = data_frames(get, "reload_time_s", 2.4)
    n_d = data_frames(get, "equip_time_s", 0.45, up=True)
    sl = round(0.61 * n_r)
    ev = {"crane_open": round(0.14 * n_r), "eject": round(0.30 * n_r), "loader_show": sl - 12, "speedloader_in": sl,
          "loader_drop": sl + 4, "crane_close": round(0.80 * n_r), "done": n_r - 8}
    out = _std(n_d, REVOLVER_FIRE)
    # revolvers have no empty distinction: reload_empty is the same motion (an alias)
    out["reload"] = {"frames": n_r, "loop": False, "events": dict(ev)}
    out["reload_empty"] = {"frames": n_r, "loop": False, "events": dict(ev)}
    return out


REVOLVER_DATA = weapon_data("revolver")
REVOLVER = FPSet(
    name="revolver", weapon="wpn_marshal_357",
    markers={"left_ik": v3(-0.025, 0.0115, -0.020), "aim": v3(0.0, -0.026, 0.0645),
             "cyl": v3(0.0, 0.030, 0.034), "cyl_len": 0.040, "cyl_r": 0.019,
             "hinge": v3(-0.007, 0.030, 0.008), "rod_tip": v3(0.0, 0.094, 0.034),
             "loader": v3(0.0, 0.0, 0.034)},
    hip=((0.105, 0.36, -0.175), 5.0, 2.0, -4.0),
    ads_dist=0.31, sh=(0.0, 0.02, -0.08),
    pole_l=(-0.22, -0.25, -0.94), pole_l_ads=(-0.22, -0.25, -0.94), pole_r=(0.22, -0.25, -0.94),
    sprint=((0.15, 0.28, -0.205), 14.0, -22.0, -32.0),
    lowered=((0.16, 0.20, -0.46), 10.0, -55.0, -30.0),
    reload_tilt=((0.07, 0.34, -0.15), 12.0, 10.0, -20.0),
    support="pistol", blade=6.0, blade_ads=0.0, reload="speedloader",
    recoil={"back": 0.040, "up": 0.018, "pitch": 16.0, "roll": 2.5, "yaw": 1.0},
    recoil_ads={"back": 0.028, "up": 0.010, "pitch": 9.0, "roll": 1.4, "yaw": 0.5},
    clips=_revolver_clips(REVOLVER_DATA),
)

SETS: dict[str, FPSet] = {s.name: s for s in (PISTOL, SMG, RIFLE, SHOTGUN, LMG, SNIPER, AKIMBO, REVOLVER)}


def clip_table() -> dict[str, dict]:
    """``{<set>_<clip>: {"frames", "loop", "events"}}`` for every set (export order = sorted)."""
    out = {}
    for s in SETS.values():
        for clip, row in s.clips.items():
            out[f"{s.name}_{clip}"] = {"frames": int(row["frames"]), "loop": bool(row["loop"]),
                                       "events": dict(row.get("events", {}))}
    return out


def _check() -> None:
    for s in SETS.values():
        for clip, row in s.clips.items():
            for ev, f in row.get("events", {}).items():
                if not 0 <= f <= row["frames"]:
                    raise ValueError(f"{s.name}_{clip}: event {ev}@{f} outside 0..{row['frames']}")


_check()
_ = np  # numpy arrays are the marker type
