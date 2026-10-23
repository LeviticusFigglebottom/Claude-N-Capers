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


#: D-116 (PO 2026-10-16): the one-handed pistol / revolver thumb rides high along the frame's left side (the tip ~22 mm
#: left of the bore line, 16 mm above the grip pivot, under the slide) instead of standing 40 mm off it: cmc / mcp / ip
#: flex, opposition (deg)
PISTOL_THUMB = (18.0, -10.0, -10.0, 40.0)
#: the revolver's thumb a little lower (tip ~8 mm above the grip pivot): along the frame under the cylinder, not into it
REVOLVER_THUMB = (12.0, -10.0, -10.0, 48.0)
#: the akimbo Warden .45s (both guns; the hand seats without grip_adjust): the thumb along the frame side, ~17 mm up
AKIMBO_THUMB = (4.0, -5.0, -20.0, 26.0)


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
    pole_r_ads: tuple | None = None                  # right elbow in ADS (None = pole_r)
    ads_sh: tuple = (0.0, 0.0, 0.0)                  # extra shoulder offset in ADS (camera space, both shoulders)
    grip_adjust: tuple = (0.0, 0.0)                  # D-116 one-handed: right hand re-seated on the grip: (twist
                                                     # about the grip axis, + = wrist to the gun's right; cock about
                                                     # weapon X, + = wrist down), deg, pivot on the grip
    grip_thumb: tuple = (4.0, 8.0, 6.0, -4.0)        # D-116 one-handed right thumb: flex cmc / mcp / ip, opp (deg)
    one_hand: bool = False                           # D-116: one-handed FP hold, the left hand off-screen low except
                                                     # while a reload uses it
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
    # D-116 (PO, FNV-style): ONE-HANDED in first person. Hip: the gun in the lower-right third
    # (grip ~x68 %/y96 % 0.35 m out, muzzle ~x58 %/y61 % at the 52 deg viewmodel FOV; refs
    # po_shots/2026-10-15_ref_pistol_*), yawed 12 deg toward the centre. ADS: a close pistol (0.22 m), the right
    # shoulder brought in under the eye so the firing hand's knuckles fill the bottom centre and only the cuff and a
    # short sleeve show below it. The left hand waits off-screen and comes up only to reload.
    hip=((0.102, 0.367, -0.107), 12.0, 2.0, -4.0), one_hand=True,
    # lead (P option b): the hand re-seated on the grip, wrist behind / under it and cocked down, so the eye sees the
    # back of the hand and the thumb along the frame; the gun does not move
    grip_adjust=(-28.0, 12.0), grip_thumb=PISTOL_THUMB,
    ads_dist=0.22, sh=(0.0, 0.06, 0.04), ads_sh=(-0.15, -0.05, -0.20),  # P: elbow straight under the wrist
    pole_l=(-0.22, -0.25, -0.94), pole_l_ads=(-0.22, -0.25, -0.94), pole_r=(0.22, -0.25, -0.94),
    pole_r_ads=(0.0, -0.1, -1.0),
    sprint=((0.13, 0.30, -0.15), 10.0, -16.0, -26.0),
    # D-116 (lead): the gun never rolls its grip toward the camera; the mag change happens in frame, the left hand
    # coming in from below
    lowered=((0.14, 0.22, -0.42), 10.0, -35.0, -15.0),
    # D-116 follow-up (lead): raised and canted so the magwell and the left hand seating the magazine are IN FRAME
    # under P's one-handed hip framing (set_hip_offset / set_hip_rot_deg): the well at ~0.72 of the screen height, the gun angled like the hip hold
    reload_tilt=((0.02, 0.43, 0.0), 40.0, 16.0, -15.0),
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
    # LeftHandIK under the fore-end (ENV B f8f17c7a, lead ruling 2026-10-14): the PD2 support grip of the long guns
    markers={"left_ik": v3(0.0, 0.150, 0.016), "aim": v3(0.0, -0.060, 0.1172),
             "vgrip_ik": v3(0.0, 0.175, -0.0032),  # D-118: mod_rail_vertical_grip's LeftHandIK on the hornet
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
           "vgrip_hand": {"frames": 2, "loop": False},
           "reload": {"frames": 66, "loop": False,
                      "events": {"mag_out": 13, "mag_swap": 23, "mag_in": 39, "done": 56}},
           "reload_empty": {"frames": 90, "loop": False,
                            "events": {"mag_out": 13, "mag_swap": 23, "mag_in": 39, "bolt_release": 64,
                                       "done": 80}}},
)

# -- rifle (Corsair AR: 700 rpm = 2.6 frames per shot) ------------------------------------------
RIFLE = FPSet(
    name="rifle", weapon="wpn_corsair_ar",
    markers={"left_ik": v3(0.0, 0.260, 0.038), "aim": v3(0.0, -0.060, 0.1212),
             "vgrip_ik": v3(0.0, 0.38, 0.0143),  # D-118: mod_corsair_vertical_grip's LeftHandIK
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
           "vgrip_hand": {"frames": 2, "loop": False},
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
    markers={"left_ik": v3(0.0, 0.360, -0.002), "aim": v3(0.0, 0.100, 0.1032),
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
    markers={"left_ik": v3(0.0, 0.293, 0.029), "aim": v3(0.0, -0.005, 0.1542),
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
    markers={"left_ik": v3(0.0, 0.333, 0.024), "aim": v3(0.0, -0.010, 0.1422),
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
    grip_thumb=AKIMBO_THUMB,
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
    # D2-04: ENV B's wpn_marshal_357 (LeftHandIK, AimPoint; Crane pivot, Cylinder 10..54 mm, r 21 mm)
    markers={"left_ik": v3(-0.028, 0.0054, -0.020), "aim": v3(0.0, -0.008, 0.082),
             "cyl": v3(0.0, 0.032, 0.0478), "cyl_len": 0.044, "cyl_r": 0.021,
             "hinge": v3(-0.006, 0.032, 0.0288), "rod_tip": v3(0.0, 0.086, 0.0478),
             "loader": v3(0.0, 0.0, 0.0478)},
    # D-116 as the pistol (PO, FNV-style): ONE-HANDED in first person. Hip: the gun in the lower-right third
    # (grip ~x68 %/y96 % 0.35 m out, muzzle ~x58 %/y61 % at the 52 deg viewmodel FOV; refs
    # po_shots/2026-10-15_ref_pistol_*), yawed 12 deg toward the centre. ADS: a close pistol (0.22 m), the right
    # shoulder brought in under the eye so the firing hand's knuckles fill the bottom centre and only the cuff and a
    # short sleeve show below it. The left hand waits off-screen and comes up only to reload.
    hip=((0.102, 0.367, -0.107), 12.0, 2.0, -4.0), one_hand=True,
    # lead (P option b): the hand re-seated on the grip, wrist behind / under it and cocked down, so the eye sees the
    # back of the hand and the thumb along the frame; the gun does not move
    grip_adjust=(-28.0, 12.0), grip_thumb=REVOLVER_THUMB,
    ads_dist=0.22, sh=(0.0, 0.06, 0.04), ads_sh=(-0.15, -0.05, -0.20),  # P: elbow straight under the wrist
    pole_l=(-0.22, -0.25, -0.94), pole_l_ads=(-0.22, -0.25, -0.94), pole_r=(0.22, -0.25, -0.94),
    pole_r_ads=(0.0, -0.1, -1.0),
    sprint=((0.13, 0.30, -0.15), 10.0, -16.0, -26.0),
    lowered=((0.14, 0.22, -0.42), 10.0, -35.0, -15.0),
    reload_tilt=((0.04, 0.41, -0.03), 22.0, 8.0, -28.0),   # D-116 follow-up: the open cylinder in frame
    support="pistol", blade=6.0, blade_ads=0.0, reload="speedloader",
    recoil={"back": 0.040, "up": 0.018, "pitch": 16.0, "roll": 2.5, "yaw": 1.0},
    recoil_ads={"back": 0.028, "up": 0.010, "pitch": 9.0, "roll": 1.4, "yaw": 0.5},
    clips=_revolver_clips(REVOLVER_DATA),
)

# =============================================================================================
# D-055 (B4-18): armory batch 3. Eight new mechanisms. Weapon models may not exist yet: markers are
# the review proxies' (``_arms_review_b3``), which follow the visual_slots part names; lengths come
# from ENV B's data when a weapon with that anim_set exists, else from the ``*_DEFAULTS`` below
# (event frames are laid out as fractions of the clip length, so a rebuild follows the data).
# =============================================================================================
def _b3_row(anim_set: str, defaults: dict) -> dict:
    """``defaults`` overridden by the first weapon .tres with ``anim_set`` (non-zero fields only)."""
    row = weapon_data(anim_set)
    out = dict(defaults)
    for k in defaults:
        v = row.get(k)
        if isinstance(v, float) and v > 0.0:
            out[k] = v
    return out


def _f(t: float) -> int:
    return int(round(t * 30.0))


def _equip(row: dict) -> int:
    return data_frames(row, "equip_time_s", 0.5, up=True)


def _one(n: int, ev: dict | None = None) -> dict:
    return {"frames": int(n), "loop": False, "events": dict(ev or {})}


# -- break_action (Reaper double barrel) ----------------------------------------------------------
#: ``Breech`` (barrels + fore-end) pivots at the hinge pin and opens BREAK_OPEN_DEG muzzle-down
#: (Godot: - about its local X). One barrel per click (PD2): fire is one shot.
BREAK_OPEN_DEG = 38.0
BREAK_DEFAULTS = {"reload_time_s": 2.6, "equip_time_s": 0.6, "fire_rate_rpm": 300.0}
BREAK_FIRE = 10


def _break_clips(row: dict, rounds: int, fire: int) -> dict:
    n = _f(row["reload_time_s"])
    ev = {"breech_open": round(0.15 * n), "eject": round(0.25 * n)}
    if rounds == 2:
        ev.update({"shell_in_1": round(0.52 * n), "shell_in_2": round(0.64 * n)})
    else:
        ev["round_in"] = round(0.58 * n)
    ev.update({"breech_close": round(0.80 * n), "done": n - 8})
    out = _std(_equip(row), fire)
    # a break action always reloads every chamber: reload_empty is the same motion (an alias)
    out["reload"] = _one(n, ev)
    out["reload_empty"] = _one(n, ev)
    return out


BREAK_DATA = _b3_row("break_action", BREAK_DEFAULTS)
BREAK_ACTION = FPSet(
    name="break_action", weapon="wpn_reaper_db",
    # D2-04: ENV B's wpn_reaper_db (LeftHandIK on the Breech fore-end, AimPoint = the tang sight, Breech
    # pivot = the hinge pin, the shells' bases at the breech face)
    markers={"left_ik": v3(0.0, 0.148, 0.005), "aim": v3(0.0, -0.016, 0.086),
             "hinge": v3(0.0, 0.066, 0.028), "chambers": (v3(-0.012, 0.071, 0.054), v3(0.012, 0.071, 0.054)),
             "lever": v3(0.0, 0.020, 0.078), "butt": v3(0.0, -0.346, 0.0),
             "magwell": v3(0.0, 0.071, 0.054), "magwell_axis": v3(0.0, -1.0, 0.0)},
    hip=((0.13, 0.20, -0.18), 7.0, 1.5, -6.0),
    ads_dist=0.20,
    sprint=((0.15, 0.21, -0.22), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.06, -0.56), 20.0, -55.0, -35.0),
    reload_tilt=((0.07, 0.24, -0.15), 14.0, 16.0, 20.0),
    support="handguard", blade=44.0, blade_ads=48.0, reload="break",
    recoil={"back": 0.050, "up": 0.018, "pitch": 11.0, "roll": 2.2, "yaw": 1.0},
    recoil_ads={"back": 0.036, "up": 0.011, "pitch": 7.0, "roll": 1.3, "yaw": 0.6},
    clips=_break_clips(BREAK_DATA, 2, BREAK_FIRE),
)

# -- launcher (Thumper 40 single-shot break-open grenade launcher) -----------------------------
LAUNCHER_OPEN_DEG = 42.0
LAUNCHER_DEFAULTS = {"reload_time_s": 3.0, "equip_time_s": 0.7, "fire_rate_rpm": 60.0}
LAUNCHER_FIRE = 14
LAUNCHER_DATA = _b3_row("launcher", LAUNCHER_DEFAULTS)
LAUNCHER = FPSet(
    name="launcher", weapon="wpn_thumper_40",
    # D2-04: ENV B's wpn_thumper_40 (LeftHandIK on the Forend, AimPoint = the leaf sight, Breech pivot,
    # the GrenadeRound base at the breech face)
    markers={"left_ik": v3(-0.024, 0.170, 0.0265), "aim": v3(0.0, 0.110, 0.1097),
             "vgrip_ik": v3(0.0, 0.170, -0.020),  # D-118: mod_thumper_vertical_grip's LeftHandIK
             "hinge": v3(0.0, 0.056, 0.026), "chambers": (v3(0.0, 0.062, 0.058),),
             "lever": v3(0.0, 0.020, 0.080), "butt": v3(0.0, -0.298, 0.0),
             "magwell": v3(0.0, 0.062, 0.058), "magwell_axis": v3(0.0, -1.0, 0.0)},
    hip=((0.13, 0.21, -0.19), 7.0, 2.5, -6.0),
    ads_dist=0.27,
    sprint=((0.15, 0.21, -0.23), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.06, -0.57), 20.0, -55.0, -35.0),
    reload_tilt=((0.07, 0.24, -0.16), 14.0, 18.0, 20.0),
    support="handguard", blade=44.0, blade_ads=48.0, reload="break",
    recoil={"back": 0.060, "up": 0.022, "pitch": 14.0, "roll": 2.5, "yaw": 1.2},
    recoil_ads={"back": 0.045, "up": 0.014, "pitch": 9.0, "roll": 1.6, "yaw": 0.7},
    clips={**_break_clips(LAUNCHER_DATA, 1, LAUNCHER_FIRE), "vgrip_hand": {"frames": 2, "loop": False}},
)

# -- crossbow (Vise crossbow: lever-cocked, one bolt) -------------------------------------------
#: The string is two halves, ``StringUpper`` (left) / ``StringLower`` (right) (ENV B's Vise, ``_vise.py``): each half
#: node's origin is its prod-tip anchor (limb-tip axle, Blender weapon (-/+0.290, 0.339, 0.066)) and its ``...Cord``
#: runs to the string CENTRE, where they meet. The model RESTS RELEASED (brace): the halves meet STRING_TRAVEL m ahead
#: of the nock, Blender (0, 0.176, 0.066) = Godot model (0, 0.066, -0.176). Latched, the centre is on the ``Magwell``
#: (Blender (0, 0.016, 0.066) = Godot (0, 0.066, -0.016)) with the bolt nocked. The cocking hand pulls the centre from
#: released to latched; ENV A bends each half from its anchor to the centre (``string_centre``). The bolt rides the
#: ``magazine`` bone (``Magwell``).
STRING_TRAVEL = 0.160
STRING_LATCHED = (0.0, 0.016, 0.066)            # Blender weapon space (x right, y muzzle, z up)
STRING_ANCHOR_X, STRING_ANCHOR_Y = 0.290, 0.339  # the halves' prod-tip anchors (-/+x, y, STRING_LATCHED z)
CROSSBOW_DEFAULTS = {"reload_time_s": 2.0, "equip_time_s": 0.55, "fire_rate_rpm": 30.0}
CROSSBOW_FIRE = 10


def _crossbow_clips(row: dict) -> dict:
    n = _f(row["reload_time_s"])
    ev = {"cock": round(0.20 * n), "string_back": round(0.36 * n), "bolt_show": round(0.50 * n),
          "bolt_in": round(0.72 * n), "done": n - 7}
    out = _std(_equip(row), CROSSBOW_FIRE, {"shot": 0, "string_release": 0})
    out["reload"] = _one(n, ev)            # one bolt: always empty, reload_empty is the same motion
    out["reload_empty"] = _one(n, ev)
    return out


CROSSBOW_DATA = _b3_row("crossbow", CROSSBOW_DEFAULTS)
CROSSBOW = FPSet(
    name="crossbow", weapon="wpn_vise_crossbow",
    # D2-04: ENV B's wpn_vise_crossbow: the left hand on the vertical Foregrip (palm on LeftHandIK),
    # AimPoint = the peep, the string halves rest released (string_rest) and latch on the Magwell, BoltArrow nocked
    # on Magwell (0.40 m); string_latched / string_rest = the string CENTRE (where StringUpper meets StringLower)
    markers={"left_ik": v3(-0.016, 0.250, -0.006), "left_palm": v3(-0.016, 0.250, -0.006),
             "aim": v3(0.0, -0.040, 0.1122),
             "string_latched": v3(*STRING_LATCHED),
             "string_rest": v3(STRING_LATCHED[0], STRING_LATCHED[1] + STRING_TRAVEL, STRING_LATCHED[2]),
             "magwell": v3(0.0, 0.016, 0.066), "magwell_axis": v3(0.0, 1.0, 0.0), "bolt_len": 0.40,
             "prod": v3(0.0, 0.375, 0.053), "butt": v3(0.0, -0.316, 0.020)},
    hip=((0.13, 0.20, -0.18), 7.0, 1.5, -6.0),
    ads_dist=0.12,
    sprint=((0.15, 0.21, -0.22), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.06, -0.56), 20.0, -55.0, -35.0),
    reload_tilt=((0.050, 0.30, -0.215), 12.0, -24.0, 6.0),
    support="vgrip", blade=44.0, blade_ads=48.0, reload="crossbow", pole_l=(-0.7, -0.25, -0.65),
    recoil={"back": 0.026, "up": 0.010, "pitch": 4.5, "roll": 1.0, "yaw": 0.6},
    recoil_ads={"back": 0.018, "up": 0.006, "pitch": 2.6, "roll": 0.6, "yaw": 0.3},
    clips=_crossbow_clips(CROSSBOW_DATA),
)

# -- lever (Shrike .44 tube-fed lever rifle) ----------------------------------------------------
#: ``Lever`` swings LEVER_OPEN_DEG down (Godot: + about its local X, the loop's rear end goes down)
#: about its pivot; the cycle is part of fire / fire_ads (like the pump). Rounds go in through the
#: right-side loading gate (``Magwell``) one by one: reload_start + n x reload_loop + reload_end(_empty).
LEVER_OPEN_DEG = 52.0
LEVER_HAND_FOLLOW = 0.55            # the right hand turns with the lever this much (fingers in the loop)
LEVER_DEFAULTS = {"fire_rate_rpm": 90.0, "equip_time_s": 0.6, "mag_size": 8.0, "reload_start_s": 0.5,
                  "reload_per_round_s": 0.5, "reload_end_s": 0.4, "reload_end_empty_s": 1.0}


def lever_fire_events(n: int) -> dict:
    return {"shot": 0, "lever_open": round(0.36 * n), "lever_close": round(0.60 * n), "done": n - 3}


def lever_pieces(row: dict) -> tuple[int, int, int, int, int]:
    """(start, loop, end, end_empty, rounds) frames / count from the data."""
    return (_f(row["reload_start_s"]), _f(row["reload_per_round_s"]), _f(row["reload_end_s"]),
            _f(row["reload_end_empty_s"]), int(row["mag_size"]))


def _lever_clips(row: dict) -> dict:
    nf = max(16, min(26, int(1800.0 / row["fire_rate_rpm"])))
    st, lp, en, ee, n = lever_pieces(row)
    out = _std(_equip(row), nf, lever_fire_events(nf))
    rin = max(4, lp - 5)
    out["reload_start"] = _one(st, {"ready": st})
    out["reload_loop"] = _one(lp, {"round_in": rin, "done": lp})
    out["reload_end"] = _one(en, {"done": en - 2})
    # the left hand needs ~0.4 s from the gate back to the fore-end (a ~165 deg wrist turn at <= ~20 deg /
    # frame, ``_arms_breech.cam_path``) before the lever is thrown at lever_open - 4
    eev = {"lever_open": round(0.53 * ee), "lever_close": round(0.70 * ee), "done": ee - 3}
    out["reload_end_empty"] = _one(ee, eev)
    for empty in (False, True):
        ev = {f"round_in_{i + 1}": st + i * lp + rin for i in range(n)}
        e0 = st + n * lp
        if empty:
            ev.update({k: e0 + v for k, v in eev.items()})
        else:
            ev["done"] = e0 + en - 2
        out["reload_empty" if empty else "reload"] = _one(e0 + (ee if empty else en), ev)
    return out


LEVER_DATA = _b3_row("lever", LEVER_DEFAULTS)
LEVER = FPSet(
    name="lever", weapon="wpn_shrike_44",
    # D2-04: ENV B's wpn_shrike_44 (LeftHandIK on the Forend, AimPoint = the buckhorn rear sight on the
    # barrel, Lever pivot at its front end); the loading gate on the receiver's right side
    markers={"left_ik": v3(0.0, 0.210, 0.004), "aim": v3(0.0, 0.270, 0.074),
             "lever_pivot": v3(0.0, 0.124, 0.010), "magwell": v3(0.017, 0.095, 0.028),
             "magwell_axis": v3(-0.10, 0.99, 0.0), "butt": v3(0.0, -0.320, -0.010)},
    hip=((0.13, 0.20, -0.18), 7.0, 1.5, -6.0),
    ads_dist=0.44,
    sprint=((0.15, 0.21, -0.22), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.06, -0.56), 20.0, -55.0, -35.0),
    reload_tilt=((-0.030, 0.31, -0.185), 14.0, 6.0, -60.0),
    support="handguard", blade=44.0, blade_ads=48.0, reload="lever",
    recoil={"back": 0.034, "up": 0.012, "pitch": 6.0, "roll": 1.4, "yaw": 0.7},
    recoil_ads={"back": 0.024, "up": 0.007, "pitch": 3.6, "roll": 0.8, "yaw": 0.4},
    clips=_lever_clips(LEVER_DATA),
)

# -- bow (Thorn compound bow, silent) -----------------------------------------------------------
#: The bow is held in the LEFT hand: the ``weapon`` bone is animated every frame so the bow's origin
#: (its riser grip) sits in hand.L at the mirrored grip offset (``fp.offhand_grip``); the right hand
#: holds the nocked arrow on the string. Weapon axes: Y = arrow direction, Z = up along the riser.
#: D2-04: ENV B's wpn_thorn_bow: the nock (CarbonArrow / Magwell / LeftHandIK) 155 mm behind and 50 mm
#: above the grip pivot, the arrow 14 mm left of the riser (on the rest); cam axles at y -0.125, z +-0.405
BOW_BRACE = 0.155                   # string (nock) behind the grip at rest (m)
BOW_DRAW = 0.400                    # extra string travel at full draw (m)
BOW_NOCK_Z = 0.050                  # nocking point / arrow height above the grip pivot
BOW_ARROW_X = -0.014                # the arrow on the rest, left of the riser
BOW_DEFAULTS = {"reload_time_s": 1.0, "equip_time_s": 0.6}
BOW_DRAW_FRAMES = 21                # 0.7 s: last frame = full draw (= hold frame 0)
BOW_RELEASE = 15


def _bow_clips(row: dict) -> dict:
    n = _f(row["reload_time_s"])
    nock = {"arrow_show": round(0.38 * n), "nocked": round(0.78 * n), "done": n - 3}
    rel = {"shot": 0, "release": 0, "done": BOW_RELEASE - 3}
    out = _std(_equip(row), BOW_RELEASE, rel)
    out["draw_string"] = _one(BOW_DRAW_FRAMES, {"drawn": BOW_DRAW_FRAMES})
    out["hold"] = {"frames": 90, "loop": True, "events": {}}
    out["release"] = _one(BOW_RELEASE, rel)
    out["nock"] = _one(n, nock)
    out["reload"] = _one(n, nock)          # = nock (aliases for the generic reload path)
    out["reload_empty"] = _one(n, nock)
    return out


BOW_DATA = _b3_row("bow", BOW_DEFAULTS)
BOW = FPSet(
    name="bow", weapon="wpn_thorn_bow",
    markers={"left_ik": v3(0.0, 0.0, 0.0), "aim": v3(0.0, 0.40, BOW_NOCK_Z),
             "nock": v3(BOW_ARROW_X, -BOW_BRACE, BOW_NOCK_Z), "rest": v3(BOW_ARROW_X, 0.010, BOW_NOCK_Z),
             "cam_upper": v3(0.0, -0.125, 0.405), "cam_lower": v3(0.0, -0.125, -0.405),
             "magwell": v3(BOW_ARROW_X, -BOW_BRACE, BOW_NOCK_Z), "magwell_axis": v3(0.0, 1.0, 0.0), "arrow_len": 0.67},
    # the bow (left hand) at rest: low left, canted, an arrow nocked
    hip=((-0.165, 0.42, -0.225), -8.0, 4.0, 24.0),
    ads_dist=0.0, ads_hold=((-0.115, 0.45, -0.185), -5.0, 3.0, 18.0),
    sprint=((-0.12, 0.30, -0.27), -18.0, -24.0, 38.0),
    lowered=((-0.14, 0.18, -0.52), -15.0, -50.0, 40.0),
    reload_tilt=((-0.150, 0.40, -0.21), -12.0, 2.0, 36.0),
    support="bow", blade=30.0, blade_ads=36.0, reload="nock",
    pole_l=(-0.75, -0.15, -0.65), pole_l_ads=(-0.85, 0.0, -0.55), pole_r=(0.8, -0.35, -0.5),
    recoil={"back": -0.012, "up": 0.010, "pitch": 3.0, "roll": 4.0, "yaw": -1.0},
    recoil_ads={"back": -0.012, "up": 0.010, "pitch": 3.0, "roll": 4.0, "yaw": -1.0},
    clips=_bow_clips(BOW_DATA),
)

# -- flamethrower (Furnace): hold-fire start / loop / end; canister swap -------------------------
FLAME_DEFAULTS = {"reload_time_s": 3.0, "reload_empty_time_s": 3.6, "equip_time_s": 0.8}
FLAME_START, FLAME_LOOP, FLAME_END = 9, 30, 12
CONT_FIRE = 3                       # fire / fire_ads one-shots (restart per tick, <= 1.5 x 1/900 rpm)


def _mag_events(n: int, empty: bool) -> dict:
    if empty:
        return {"mag_out": round(0.14 * n), "mag_swap": round(0.32 * n), "mag_in": round(0.62 * n), "done": n - 10}
    return {"mag_out": round(0.18 * n), "mag_swap": round(0.36 * n), "mag_in": round(0.62 * n), "done": n - 10}


def _flame_clips(row: dict) -> dict:
    out = _std(_equip(row), CONT_FIRE)
    out["fire_start"] = _one(FLAME_START, {"ignite": 2, "ready": FLAME_START})
    out["fire_hold"] = {"frames": FLAME_LOOP, "loop": True, "events": {}}
    out["fire_end"] = _one(FLAME_END, {"extinguish": 0, "done": FLAME_END - 2})
    for clip, key, empty in (("reload", "reload_time_s", False), ("reload_empty", "reload_empty_time_s", True)):
        n = _f(row[key])
        out[clip] = _one(n, _mag_events(n, empty))
    return out


FLAME_DATA = _b3_row("flamethrower", FLAME_DEFAULTS)
FLAMETHROWER = FPSet(
    name="flamethrower", weapon="wpn_furnace_ft",
    # D2-04: ENV B's wpn_furnace_ft: the left hand on the vertical FrontHandle (palm on LeftHandIK), AimPoint
    # on the post sight rail, the FuelTank under the housing (Magwell = its top), PilotLight at the nozzle
    markers={"left_ik": v3(-0.016, 0.380, -0.001), "left_palm": v3(-0.016, 0.380, -0.001), "aim": v3(0.0, 0.030, 0.106),
             "magwell": v3(0.0, 0.200, 0.033), "magwell_axis": v3(0.0, 0.0, 1.0),
             "pilot": v3(0.0, 0.512, 0.051), "butt": v3(0.0, -0.272, 0.030)},
    hip=((0.13, 0.16, -0.20), 6.0, 1.5, -5.0),         # D2-04: pulled back (the real FrontHandle is at y 0.38)
    ads_dist=0.19,
    sprint=((0.15, 0.20, -0.25), 26.0, -8.0, -36.0),
    lowered=((0.16, 0.05, -0.58), 20.0, -55.0, -35.0),
    reload_tilt=((0.07, 0.21, -0.17), 16.0, 16.0, 26.0),
    support="vgrip", blade=36.0, blade_ads=40.0, reload="mag",
    pole_l=(-0.7, -0.25, -0.65),
    recoil={"back": 0.004, "up": 0.002, "pitch": 0.5, "roll": 0.3, "yaw": 0.2},
    recoil_ads={"back": 0.003, "up": 0.001, "pitch": 0.3, "roll": 0.2, "yaw": 0.1},
    mag={"top": 0.0, "bottom": -0.090, "hw": 0.040, "depth": 0.210, "grip": "box"},
    clips=_flame_clips(FLAME_DATA),
)

# -- saw (Rotor power saw, secondary): rev / cut loop / cut end; blade change -------------------
SAW_DEFAULTS = {"reload_time_s": 3.0, "equip_time_s": 0.6}
SAW_REV, SAW_CUT, SAW_CUT_END = 12, 30, 12


def _saw_clips(row: dict) -> dict:
    n = _f(row["reload_time_s"])
    ev = {"nut_off": round(0.16 * n), "blade_out": round(0.26 * n), "blade_in": round(0.62 * n),
          "nut_on": round(0.72 * n), "done": n - 8}
    out = _std(_equip(row), CONT_FIRE)
    out["rev"] = _one(SAW_REV, {"rev": 0, "ready": SAW_REV})
    out["cut_hold"] = {"frames": SAW_CUT, "loop": True, "events": {}}
    out["cut_end"] = _one(SAW_CUT_END, {"done": SAW_CUT_END - 2})
    out["reload"] = _one(n, ev)            # a blade change is the same whether worn out or not (alias)
    out["reload_empty"] = _one(n, ev)
    return out


SAW_DATA = _b3_row("saw", SAW_DEFAULTS)
SAW = FPSet(
    name="saw", weapon="wpn_rotor_saw",
    # D2-04: ENV B's wpn_rotor_saw: the left hand palm-down on the transverse top FrontHandle (LeftHandIK on
    # its left half; the palm rests on the bar top, 136 mm), the Blade (r 150 mm) centred on the arbor at
    # x 0 (the arm on its right, the nut on its left)
    markers={"left_ik": v3(-0.030, 0.205, 0.122), "top_bar": v3(-0.030, 0.203, 0.140), "arbor": v3(0.0, 0.420, -0.010),
             "blade_r": 0.150,
             "magwell": v3(0.0, 0.420, -0.010), "magwell_axis": v3(1.0, 0.0, 0.0), "aim": v3(0.0, 0.110, 0.096)},
    hip=((0.14, 0.26, -0.315), 10.0, 6.0, -4.0),       # D2-04: pulled back (the left hand on the top bar)
    ads_dist=0.0, ads_hold=((0.11, 0.32, -0.285), 6.0, 7.0, -2.0),
    sprint=((0.15, 0.21, -0.26), 22.0, -14.0, -26.0),
    lowered=((0.15, 0.08, -0.57), 18.0, -50.0, -30.0),
    reload_tilt=((0.10, 0.17, -0.28), 36.0, 20.0, 46.0),
    support="top", blade=26.0, blade_ads=28.0, reload="blade",
    pole_l=(-0.6, -0.2, -0.75), pole_l_ads=(-0.6, -0.2, -0.75),
    recoil={"back": 0.004, "up": 0.003, "pitch": 0.6, "roll": 0.5, "yaw": 0.3},
    recoil_ads={"back": 0.003, "up": 0.002, "pitch": 0.4, "roll": 0.3, "yaw": 0.2},
    clips=_saw_clips(SAW_DATA),
)

# -- minigun (Cyclone rotary): spin up / fire loop / spin down; box swap -----------------------
MINIGUN_DEFAULTS = {"reload_time_s": 6.0, "reload_empty_time_s": 6.6, "equip_time_s": 1.2}
MINI_SPIN_UP, MINI_LOOP, MINI_SPIN_DOWN = 15, 30, 24


def _minigun_clips(row: dict) -> dict:
    out = _std(_equip(row), CONT_FIRE)
    out["sprint"] = {"frames": 24, "loop": True}                    # a heavy jog
    out["spin_up"] = _one(MINI_SPIN_UP, {"spin": 0, "spun": MINI_SPIN_UP})
    out["fire_hold"] = {"frames": MINI_LOOP, "loop": True, "events": {}}
    out["spin_down"] = _one(MINI_SPIN_DOWN, {"stopped": MINI_SPIN_DOWN})
    for clip, key, empty in (("reload", "reload_time_s", False), ("reload_empty", "reload_empty_time_s", True)):
        n = _f(row[key])
        ev = _mag_events(n, empty)
        ev["belt_seat"] = round(0.74 * n)
        out[clip] = _one(n, ev)
    return out


MINIGUN_DATA = _b3_row("minigun", MINIGUN_DEFAULTS)
MINIGUN = FPSet(
    name="minigun", weapon="wpn_cyclone_rotary",
    # D2-04: ENV B's wpn_cyclone_rotary: the left hand on the vertical FrontHandle under the housing (palm on
    # LeftHandIK), the AmmoBox on the left (Magwell = its top right corner: the box is 117 mm wide, centred
    # 54.5 mm left of it), the belt chute into the left of the housing, Rotor axis at z 80 mm
    markers={"left_ik": v3(-0.016, 0.090, -0.014), "left_palm": v3(-0.016, 0.090, -0.014), "aim": v3(0.0, -0.060, 0.1892),
             "magwell": v3(-0.048, 0.0, 0.036), "magwell_axis": v3(0.0, 0.0, 1.0),
             "feed": v3(-0.060, 0.0, 0.022), "rotor": v3(0.0, 0.124, 0.080)},
    hip=((0.11, 0.22, -0.30), 9.0, 7.0, -3.0),
    ads_dist=0.0, ads_hold=((0.085, 0.25, -0.255), 6.0, 5.0, -2.0),
    sprint=((0.13, 0.18, -0.33), 20.0, -6.0, -18.0),
    lowered=((0.14, 0.06, -0.62), 16.0, -45.0, -25.0),
    reload_tilt=((0.06, 0.24, -0.21), 22.0, 14.0, 26.0),
    support="vgrip", blade=22.0, blade_ads=24.0, reload="mag",
    pole_l=(-0.6, -0.2, -0.75), pole_l_ads=(-0.6, -0.2, -0.75),
    recoil={"back": 0.006, "up": 0.003, "pitch": 0.8, "roll": 0.5, "yaw": 0.4},
    recoil_ads={"back": 0.005, "up": 0.002, "pitch": 0.6, "roll": 0.4, "yaw": 0.3},
    mag={"top": 0.004, "bottom": -0.115, "hw": 0.0585, "depth": 0.144, "grip": "box", "cx": -0.0545},
    clips=_minigun_clips(MINIGUN_DATA),
)

# =============================================================================================
# D-058: shotgun_box: box / drum-fed self-loading shotguns (Brute 12 drum, Harrow 12 box). The rifle
# hold (shouldered, left hand on the fore-end / shroud ``LeftHandIK``) with a shotgun's kick; the
# magazine swap rocks the drum (or box) in front lip first; reload_empty ends with the left hand
# racking the charging handle (``bolt_release``). Lengths from the first weapon .tres with
# ``anim_set = &"shotgun_box"`` (sorted by file name: brute_12, the drum), else SHOTGUN_BOX_DEFAULTS
# (the Brute's numbers).
# =============================================================================================
SHOTGUN_BOX_DEFAULTS = {"reload_time_s": 3.6, "reload_empty_time_s": 4.4, "equip_time_s": 0.7,
                        "fire_rate_rpm": 300.0}
#: charging-handle stroke (m, along weapon -Y), left side of the receiver
SHOTGUN_BOX_CHARGE = 0.070


def shotgun_box_fire_frames(rpm: float) -> int:
    """9..12 f of heavy kick, no longer than 1.5 shot intervals (restarted every shot like the
    full-auto clips; 300 rpm = 6 f per shot -> 9 f)."""
    return max(9, min(12, int(1.5 * 1800.0 / max(1.0, rpm) + 1e-6)))


def _shotgun_box_clips(row: dict) -> dict:
    n_r = _f(row["reload_time_s"])
    n_e = _f(row["reload_empty_time_s"])
    out = _std(_equip(row), shotgun_box_fire_frames(row["fire_rate_rpm"]))
    out["reload"] = _one(n_r, {"mag_out": round(0.18 * n_r), "mag_swap": round(0.36 * n_r),
                               "mag_in": round(0.62 * n_r), "done": n_r - 12})
    out["reload_empty"] = _one(n_e, {"mag_out": round(0.13 * n_e), "mag_swap": round(0.30 * n_e),
                                     "mag_in": round(0.55 * n_e), "bolt_release": round(0.77 * n_e),
                                     "done": n_e - 12})
    return out


SHOTGUN_BOX_DATA = _b3_row("shotgun_box", SHOTGUN_BOX_DEFAULTS)
#: Brute 12 markers (ENV B ``tools/blender/weapons/_brute.py``): LeftHandIK under the shroud, AimPoint =
#: the carry-handle aperture, Magwell ahead of the trigger guard (drum: feed tower 20 mm up, r 74 mm
#: drum centred 94 mm below it, 30 mm half width + side plates).
SHOTGUN_BOX = FPSet(
    name="shotgun_box", weapon="wpn_brute_12",
    markers={"left_ik": v3(0.0, 0.307, 0.026), "aim": v3(0.0, -0.040, 0.1482),
             "magwell": v3(0.0, 0.150, 0.022), "magwell_axis": v3(0.0, 0.0, 1.0),
             "cock": v3(-0.034, 0.200, 0.084), "butt": v3(0.0, -0.330, 0.060)},
    hip=((0.13, 0.20, -0.185), 7.0, 1.5, -6.0),
    ads_dist=0.13,
    sprint=((0.15, 0.21, -0.23), 28.0, -8.0, -40.0),
    lowered=((0.16, 0.06, -0.57), 20.0, -55.0, -35.0),
    reload_tilt=((0.075, 0.21, -0.165), 14.0, 14.0, 34.0),
    support="handguard", blade=44.0, blade_ads=48.0, reload="mag",
    recoil={"back": 0.042, "up": 0.015, "pitch": 7.5, "roll": 1.8, "yaw": 0.9},
    recoil_ads={"back": 0.030, "up": 0.009, "pitch": 4.8, "roll": 1.1, "yaw": 0.5},
    mag={"top": 0.020, "bottom": -0.168, "hw": 0.034, "depth": 0.150, "grip": "box", "rock": 14.0},
    clips=_shotgun_box_clips(SHOTGUN_BOX_DATA),
)

#: the D-055 sets (clips in ``_arms_breech`` / ``_arms_bow`` / ``_arms_heavy``)
B3_SETS = ("break_action", "lever", "bow", "crossbow", "launcher", "flamethrower", "saw", "minigun")

# =============================================================================================
# D2-04: non-gun sets (clips in ``_arms_melee`` / ``_arms_items``) and the gun ``bash`` (quick melee)
# =============================================================================================
#: Lengths come from ENV B's MeleeDef / ThrowableDef / DeployableDef data where a field exists
#: (``charge_time_s``, ``deploy_time_s``), else from the defaults below (DATA_PENDING in test_arms).
CONTENT_DIR = WEAPONS_DIR.parent


def def_rows(kind: str) -> list[dict]:
    """``[{field: value}]`` of ``content/data/<kind>/*.tres`` (sorted by file name): numbers as floats,
    StringName / string fields (id, kind, anim_set) as bare strings."""
    out = []
    d = CONTENT_DIR / kind
    if not d.is_dir():
        return out
    for path in sorted(d.glob("*.tres")):
        row: dict = {}
        for line in path.read_text().splitlines():
            m = _RX_KV.match(line.strip())
            if not m:
                continue
            k, v = m.group(1), m.group(2).strip()
            if v.startswith(("&\"", "\"")):
                row.setdefault(k, v.lstrip("&").strip('"'))
                continue
            try:
                row.setdefault(k, float(v))
            except ValueError:
                pass
        out.append(row)
    return out


def def_row(kind: str, anim_set: str, match=None) -> dict:
    """The first row of ``kind`` whose ``anim_set`` is ``anim_set``, else (no anim_set field yet) the first
    one ``match(row)`` accepts; {} when none."""
    rows = def_rows(kind)
    for r in rows:
        if r.get("anim_set") == anim_set:
            return r
    for r in rows:
        if "anim_set" not in r and match is not None and match(r):
            return r
    return {}


def _len(row: dict, key: str, default_s: float) -> int:
    v = row.get(key)
    return _f(float(v)) if isinstance(v, float) and v > 0.0 else _f(default_s)


# -- melee -------------------------------------------------------------------------------------
#: melee kinds: (swing frames, hit frame, charged swing frames, hit frame, draw frames). PD2: a quick
#: swing lands ~0.2 s after the press; the charged swing is quicker to land (the wind-up is done).
MELEE_TIMING = {"melee_knife": (18, 6, 18, 5, 12), "melee_blunt": (24, 10, 22, 7, 15),
                "melee_blade": (22, 9, 20, 7, 14), "melee_heavy": (30, 13, 26, 9, 20)}
MELEE_DEFAULTS = {"charge_time_s": 1.0}
MELEE_CHARGE_LOOP = 30
#: MeleeDef ids without an ``anim_set`` field map by name until ENV B adds it (contract proposal)
MELEE_MATCH = {"melee_knife": ("knife", "dagger", "shank"), "melee_blunt": ("baton", "bat", "club", "hammer", "pipe",
                                                                          "crowbar", "wrench"),
               "melee_blade": ("machete", "sword", "katana", "axe", "cleaver"),
               "melee_heavy": ("sledge", "fire_axe")}
#: fragments that a set must not match (the two-handed fire axe is melee_heavy, not melee_blade)
MELEE_EXCLUDE = {"melee_blade": ("fire_axe",), "melee_blunt": ("sledge",)}


def _melee_clips(name: str, row: dict) -> dict:
    sw, hit, csw, chit, dr = MELEE_TIMING[name]
    nc = _len(row, "charge_time_s", MELEE_DEFAULTS["charge_time_s"])
    return {
        "idle": {"frames": 90, "loop": True},
        "sprint": {"frames": 18, "loop": True},
        "draw": _one(dr, {"ready": dr}),
        "holster": _one(dr, {"gone": dr}),
        "swing": _one(sw, {"hit": hit, "done": sw}),
        "charge_start": _one(nc, {"charged": nc}),
        "charge": {"frames": MELEE_CHARGE_LOOP, "loop": True, "events": {}},
        "charge_swing": _one(csw, {"hit": chit, "done": csw}),
    }


def _item_set(name: str, hip: tuple, sprint: tuple, lowered: tuple, clips: dict, support: str, data: dict) -> FPSet:
    s = FPSet(name=name, weapon="", markers={"left_ik": v3(0.0, 0.0, 0.0), "aim": v3(0.0, 0.0, 0.0)}, hip=hip,
              ads_dist=0.0, sprint=sprint, lowered=lowered, reload_tilt=hip, support=support, blade=0.0,
              blade_ads=0.0, reload="none", clips=clips, pole_l=(-0.6, -0.4, -0.7), pole_r=(0.7, -0.3, -0.65))
    s.markers["data"] = data
    return s


def _melee_set(name: str) -> FPSet:
    keys = MELEE_MATCH[name]
    skip = MELEE_EXCLUDE.get(name, ())
    row = def_row("melee", name, lambda r: any(k in str(r.get("id", "")) for k in keys)
                  and not any(k in str(r.get("id", "")) for k in skip))
    return _item_set(name, ((0.15, 0.30, -0.20), 0.0, 0.0, 0.0), ((0.16, 0.24, -0.26), 0.0, 0.0, 0.0),
                     ((0.17, 0.12, -0.50), 0.0, 0.0, 0.0), _melee_clips(name, row), "melee", row)


MELEE_KNIFE = _melee_set("melee_knife")
MELEE_BLUNT = _melee_set("melee_blunt")
MELEE_BLADE = _melee_set("melee_blade")
MELEE_HEAVY = _melee_set("melee_heavy")

# -- throwable (frag / concussion / incendiary: the pin pulled, an overhand or underhand throw) -----
THROW_DRAW, THROW_PIN, THROW_N, THROW_RELEASE, THROW_HOLSTER = 18, 9, 24, 11, 12


def _throw_clips() -> dict:
    return {
        "idle": {"frames": 90, "loop": True},
        "sprint": {"frames": 18, "loop": True},
        "draw": _one(THROW_DRAW, {"pin_pull": THROW_PIN, "ready": THROW_DRAW}),
        "holster": _one(THROW_HOLSTER, {"gone": THROW_HOLSTER}),
        "throw": _one(THROW_N, {"release": THROW_RELEASE, "done": THROW_N}),
        "throw_low": _one(THROW_N, {"release": THROW_RELEASE + 1, "done": THROW_N}),
    }


THROWABLE_DATA = def_row("throwables", "throwable", lambda r: r.get("kind") in ("frag", "concussion", "incendiary"))
THROWABLE = _item_set("throwable", ((0.14, 0.30, -0.18), 0.0, 0.0, 0.0), ((0.16, 0.24, -0.26), 0.0, 0.0, 0.0),
                      ((0.16, 0.12, -0.50), 0.0, 0.0, 0.0), _throw_clips(), "throw", THROWABLE_DATA)

# -- deployables: bag (ammo / doctor / body bag case / armor), small (ECM, trip mine, FAK), sentry -----
#: ``place`` = the deploy hold (DeployableDef.deploy_time_s; ``place`` lands on its end: ENV A spawns the
#: prefab there) + DEPLOY_RECOVER frames back off screen
DEPLOY_RECOVER = 12
DEPLOY_DEFAULTS = {"deploy_bag": 2.0, "deploy_small": 2.0, "deploy_sentry": 2.0}
DEPLOY_KINDS = {"deploy_bag": ("ammo_bag", "doctor_bag", "body_bag_case", "armor_bag"),
                "deploy_small": ("ecm", "trip_mine", "fak"), "deploy_sentry": ("sentry",)}
DEPLOY_DRAW = {"deploy_bag": 15, "deploy_small": 12, "deploy_sentry": 24}


def _deploy_set(name: str) -> FPSet:
    row = def_row("deployables", name, lambda r: r.get("kind") in DEPLOY_KINDS[name])
    n = _len(row, "deploy_time_s", DEPLOY_DEFAULTS[name])
    dr = DEPLOY_DRAW[name]
    clips = {"idle": {"frames": 90, "loop": True},
             "draw": _one(dr, {"ready": dr}),
             "holster": _one(12, {"gone": 12}),
             "place": _one(n + DEPLOY_RECOVER, {"place": n, "done": n + DEPLOY_RECOVER})}
    return _item_set(name, ((0.10, 0.34, -0.28), 0.0, 0.0, 0.0), ((0.10, 0.30, -0.30), 0.0, 0.0, 0.0),
                     ((0.10, 0.16, -0.62), 0.0, 0.0, 0.0), clips, "deploy", row)


DEPLOY_BAG = _deploy_set("deploy_bag")
DEPLOY_SMALL = _deploy_set("deploy_small")
DEPLOY_SENTRY = _deploy_set("deploy_sentry")

#: the D2-04 non-gun sets
ITEM_SETS = ("melee_knife", "melee_blunt", "melee_blade", "melee_heavy", "throwable", "deploy_bag", "deploy_small", "deploy_sentry")

B3: dict[str, FPSet] = {s.name: s for s in (BREAK_ACTION, LEVER, BOW, CROSSBOW, LAUNCHER, FLAMETHROWER, SAW, MINIGUN)}
SETS: dict[str, FPSet] = {s.name: s for s in (PISTOL, SMG, RIFLE, SHOTGUN, LMG, SNIPER, AKIMBO, REVOLVER, *B3.values(),
                                              SHOTGUN_BOX)}
GUN_SETS = tuple(SETS)

# -- the gun bash (PD2 quick melee with the weapon out): one ``bash`` clip per gun set ---------------
#: (frames, hit) by family: one-handed / pistols are quick, heavy guns slow
BASH = {"pistol": (15, 6), "long": (18, 7), "heavy": (24, 10), "bow": (18, 7)}
BASH_FAMILY = {"pistol": "pistol", "revolver": "pistol", "akimbo": "pistol", "lmg": "heavy", "minigun": "heavy",
               "flamethrower": "heavy", "saw": "heavy", "bow": "bow"}


def bash_family(name: str) -> str:
    return BASH_FAMILY.get(name, "long")


for _s in list(SETS.values()):
    _n, _h = BASH[bash_family(_s.name)]
    _s.clips["bash"] = _one(_n, {"hit": _h, "done": _n})
SETS.update({s.name: s for s in (MELEE_KNIFE, MELEE_BLUNT, MELEE_BLADE, MELEE_HEAVY, THROWABLE, DEPLOY_BAG, DEPLOY_SMALL,
                                  DEPLOY_SENTRY)})


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
