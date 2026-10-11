"""Scratch review proxies for the D-055 viewmodel sets (B4-18); used by ``_arms_review`` only while
ENV B's weapon models are not on trunk. Never exported.

Each proxy follows the marker data of its ``_arms_sets`` set (weapon space = Blender weapon axes,
origin = the right-hand grip pivot; the bow's origin is its riser grip) and the visual_slots part
names: ``Breech`` (break_action / launcher), ``Lever``, ``String`` (crossbow), ``StringUpper`` /
``StringLower`` (bow), ``Blade`` (saw), ``Rotor`` (minigun); the round / bolt / arrow / canister /
blade / ammo box that the hands carry rides the ``magazine`` bone (``Magwell``).
"""

from __future__ import annotations

import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

import _arms_sets as S
from lib import materials, scene

REVIEW_CELLS = {
    "break_action": ["break_action_idle:0", "break_action_ads_idle:0", "break_action_fire:1",
                     "break_action_reload:13", "break_action_reload:19", "break_action_reload:35",
                     "break_action_reload:45", "break_action_reload:56", "break_action_sprint:4"],
    "launcher": ["launcher_idle:0", "launcher_ads_idle:0", "launcher_fire:2", "launcher_reload:16",
                 "launcher_reload:23", "launcher_reload:48", "launcher_reload:52", "launcher_reload:71",
                 "launcher_draw:10"],
    "crossbow": ["crossbow_idle:0", "crossbow_ads_idle:0", "crossbow_fire:1", "crossbow_reload:10",
                 "crossbow_reload:17", "crossbow_reload:30", "crossbow_reload:34", "crossbow_sprint:4",
                 "crossbow_draw:10"],
    "lever": ["lever_idle:0", "lever_ads_idle:0", "lever_fire:8", "lever_fire_ads:8", "lever_reload_start:12",
              "lever_reload_loop:6", "lever_reload_loop:9", "lever_reload_end_empty:13", "lever_sprint:4"],
    "bow": ["bow_idle:0", "bow_ads_idle:0", "bow_draw_string:10", "bow_hold:0", "bow_release:2", "bow_nock:6",
            "bow_nock:14", "bow_nock:18", "bow_sprint:4"],
    "flamethrower": ["flamethrower_idle:0", "flamethrower_ads_idle:0", "flamethrower_fire_hold:7",
                     "flamethrower_fire_start:4", "flamethrower_reload:32", "flamethrower_reload:80",
                     "flamethrower_reload:112", "flamethrower_sprint:4", "flamethrower_draw:16"],
    "saw": ["saw_idle:0", "saw_ads_idle:0", "saw_cut_hold:8", "saw_rev:6", "saw_reload:18", "saw_reload:29",
            "saw_reload:63", "saw_reload:82", "saw_sprint:4"],
    "minigun": ["minigun_idle:0", "minigun_ads_idle:0", "minigun_fire_hold:8", "minigun_spin_up:8",
                "minigun_reload:43", "minigun_reload:133", "minigun_reload:178", "minigun_sprint:6",
                "minigun_draw:23"],
}


def _mat(name, color, rough=0.5):
    return materials.material(name, color, rough)


def _box(name, lo, hi, mat, rot_x: float = 0.0, about=(0.0, 0.0, 0.0)):
    from _arms_review import _box as box
    ob = box(name, lo, hi, mat, 0.0015)
    if rot_x:
        c = Vector(about)
        ob.data.transform(Matrix.Translation(c) @ Matrix.Rotation(math.radians(rot_x), 4, "X")
                          @ Matrix.Translation(-c))
    return ob


def _cyl(name, p0, p1, r, mat, seg: int = 20):
    """A cylinder from ``p0`` to ``p1`` (weapon space)."""
    import bmesh
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=d.length)
    bm.to_mesh(me)
    bm.free()
    q = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized())
    me.transform(Matrix.Translation((p0 + p1) * 0.5) @ q.to_matrix().to_4x4())
    me.materials.append(mat)
    me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    scene.link(ob)
    return ob


def _grip(name, mat, at=(0.0, 0.0, 0.0)):
    """A raked pistol grip around a grip pivot (18 deg, like ``_anim.grip_offset``)."""
    a = Vector(at)
    return _box(name, (a.x - 0.0145, a.y - 0.032, a.z - 0.085), (a.x + 0.0145, a.y + 0.012, a.z + 0.012), mat,
                rot_x=-18.0, about=at)


class Proxy:
    """Part groups: ``static`` (weapon frame), named moving parts, ``mag`` (magazine bone)."""

    def __init__(self) -> None:
        self.parts: dict[str, list] = {"static": [], "mag": []}
        self.dyn: dict = {}

    def add(self, group: str, *obs) -> None:
        self.parts.setdefault(group, []).extend(obs)


def build(s) -> Proxy:
    steel = _mat("rv_steel", "#2E3034", 0.35)
    dark = _mat("rv_dark", "#1C1D20", 0.5)
    wood = _mat("rv_wood", "#5B3B27", 0.6)
    brass = _mat("rv_brass", "#B48A3E", 0.3)
    red = _mat("rv_red", "#A0322A", 0.45)
    orange = _mat("rv_orange", "#C8661E", 0.5)
    olive = _mat("rv_olive", "#4B5233", 0.6)
    pr = Proxy()
    m = s.markers
    n = s.name
    if n in ("break_action", "launcher"):
        dbl = n == "break_action"
        rcv_w = 0.019 if dbl else 0.026
        top = 0.058 if dbl else 0.072
        h = m["hinge"]
        pr.add("static", _box("Rcv", (-rcv_w, -0.005, 0.0), (rcv_w, 0.118, top), steel),
               _box("Knuckle", (-rcv_w, 0.10, h[2] - 0.012), (rcv_w, h[1] + 0.010, h[2] + 0.010), steel),
               _grip("Grip", wood),
               _box("Wrist", (-0.016, -0.11, -0.030), (0.016, 0.0, 0.025), wood),
               _box("Stock", (-0.020, -0.34, -0.095), (0.020, -0.10, 0.030), wood, rot_x=-6.0, about=(0, -0.1, 0)),
               _box("Guard", (-0.003, 0.005, -0.022), (0.003, 0.06, -0.016), steel),
               _box("TopLever", (-0.004, 0.0, top), (0.004, 0.035, top + 0.006), steel))
        if dbl:
            pr.add("static", _box("RearNotchL", (-0.007, 0.012, top), (-0.0025, 0.026, 0.0705), steel),
                   _box("RearNotchR", (0.0025, 0.012, top), (0.007, 0.026, 0.0705), steel))
            br = [_tube2("BarrelL", (-0.0105, 0.046), 0.0105, 0.118, 0.70, steel),
                  _tube2("BarrelR", (0.0105, 0.046), 0.0105, 0.118, 0.70, steel),
                  _box("Rib", (-0.0045, 0.118, 0.054), (0.0045, 0.70, 0.0595), steel),
                  _box("Bead", (-0.002, 0.684, 0.0595), (0.002, 0.690, 0.0705), brass),
                  _box("Fore", (-0.022, 0.20, 0.006), (0.022, 0.42, 0.036), wood)]
        else:
            pr.add("static", _box("LadderL", (-0.010, 0.050, top), (-0.006, 0.066, 0.104), steel),
                   _box("LadderR", (0.006, 0.050, top), (0.010, 0.066, 0.104), steel),
                   _box("LadderBar", (-0.010, 0.050, 0.104), (0.010, 0.066, 0.108), steel))
            br = [_tube2("Barrel", (0.0, 0.052), 0.026, 0.118, 0.42, olive),
                  _box("Fore", (-0.025, 0.15, -0.004), (0.025, 0.36, 0.030), wood),
                  _box("FrontPost", (-0.0015, 0.394, 0.074), (0.0015, 0.400, 0.0985), steel)]
        pr.add("Breech", *br)
        rims = []
        for i, c in enumerate(m["chambers"]):
            r = 0.0108 if dbl else 0.021
            rims.append(_tube2(f"Rim{i}", (c[0], c[2]), r, c[1] - 0.002, c[1] + 0.003, red if dbl else brass))
        pr.add("Rims", *rims)
        ln = 0.068 if dbl else 0.100
        rr = 0.0105 if dbl else 0.020
        pr.add("held", _tube2("HeldRound", (0.0, 0.0), rr, -ln / 2, ln / 2, red if dbl else brass))
        pr.dyn["round_len"] = ln
    elif n == "crossbow":
        pr.add("static", _grip("Grip", dark),
               _box("Stock", (-0.018, -0.30, -0.065), (0.018, -0.035, 0.040), dark),
               _box("Rail", (-0.014, -0.04, 0.012), (0.014, 0.42, 0.0475), steel),
               _box("Latch", (-0.012, 0.035, 0.0475), (0.012, 0.058, 0.060), steel),
               _box("Riser", (-0.032, 0.315, 0.018), (0.032, 0.36, 0.062), dark),
               _cyl("LimbL", (-0.02, 0.338, 0.040), (-0.24, 0.296, 0.040), 0.010, dark),
               _cyl("LimbR", (0.02, 0.338, 0.040), (0.24, 0.296, 0.040), 0.010, dark),
               _box("PeepL", (-0.008, 0.002, 0.060), (-0.004, 0.018, 0.0905), steel),
               _box("PeepR", (0.004, 0.002, 0.060), (0.008, 0.018, 0.0905), steel),
               _box("Front", (-0.0015, 0.376, 0.0475), (0.0015, 0.382, 0.0905), brass))
        pr.add("strings", _cyl("StringL", (0, 0, 0), (0, 0, 1), 0.0016, dark, 8),
               _cyl("StringR", (0, 0, 0), (0, 0, 1), 0.0016, dark, 8))
        mw = m["magwell"]
        pr.add("mag", _tube2("Bolt", (mw[0], mw[2]), 0.0045, mw[1], mw[1] + m["bolt_len"], olive, 10),
               _tube2("BoltHead", (mw[0], mw[2]), 0.006, mw[1] + m["bolt_len"], mw[1] + m["bolt_len"] + 0.025,
                      steel, 10))
    elif n == "lever":
        pr.add("static", _box("Rcv", (-0.016, -0.012, 0.0), (0.016, 0.12, 0.056), steel),
               _box("Wrist", (-0.015, -0.11, -0.030), (0.015, 0.0, 0.022), wood),
               _box("Stock", (-0.019, -0.35, -0.065), (0.019, -0.10, 0.034), wood),
               _tube2("Barrel", (0.0, 0.046), 0.0095, 0.12, 0.62, steel),
               _tube2("Tube", (0.0, 0.020), 0.0085, 0.12, 0.56, steel),
               _box("Fore", (-0.019, 0.14, 0.004), (0.019, 0.36, 0.034), wood),
               _box("RearL", (-0.010, 0.166, 0.050), (-0.003, 0.174, 0.0655), steel),
               _box("RearR", (0.003, 0.166, 0.050), (0.010, 0.174, 0.0655), steel),
               _box("Front", (-0.0015, 0.600, 0.050), (0.0015, 0.606, 0.0655), brass),
               _box("Gate", (0.0158, 0.044, 0.008), (0.0185, 0.078, 0.032), brass))
        pr.add("Lever", _box("LvTop", (-0.004, 0.0, -0.013), (0.004, 0.078, -0.004), steel),
               _box("LvFront", (-0.004, 0.046, -0.072), (0.004, 0.056, -0.013), steel),
               _box("LvBottom", (-0.004, -0.045, -0.078), (0.004, 0.056, -0.068), steel),
               _box("LvTail", (-0.004, -0.048, -0.072), (0.004, -0.038, -0.030), steel))
        pr.add("held", _tube2("HeldRound", (0.0, 0.0), 0.0058, -0.020, 0.020, brass))
        pr.dyn["round_len"] = 0.040
    elif n == "bow":
        cu, cl = m["cam_upper"], m["cam_lower"]
        pr.add("static", _box("Grip", (-0.014, -0.028, -0.055), (0.014, 0.022, 0.040), dark, rot_x=-18.0),
               _box("RiserUp", (-0.011, -0.005, 0.040), (0.011, 0.040, 0.250), olive, rot_x=8.0, about=(0, 0, 0.04)),
               _box("RiserLow", (-0.011, -0.005, -0.235), (0.011, 0.040, -0.050), olive, rot_x=-8.0,
                    about=(0, 0, -0.05)),
               _box("Shelf", (-0.013, -0.010, 0.040), (0.001, 0.035, 0.050), dark),
               _cyl("LimbU", (0.0, 0.050, 0.245), cu, 0.010, dark),
               _cyl("LimbL", (0.0, 0.050, -0.230), cl, 0.010, dark),
               _cyl("CamU", (cu[0] - 0.007, cu[1], cu[2]), (cu[0] + 0.007, cu[1], cu[2]), 0.026, steel),
               _cyl("CamL", (cl[0] - 0.007, cl[1], cl[2]), (cl[0] + 0.007, cl[1], cl[2]), 0.026, steel),
               _box("SightPin", (-0.040, 0.050, 0.075), (-0.012, 0.056, 0.080), red))
        pr.add("strings", _cyl("StringUpper", (0, 0, 0), (0, 0, 1), 0.0018, dark, 8),
               _cyl("StringLower", (0, 0, 0), (0, 0, 1), 0.0018, dark, 8))
        nk = m["nock"]
        pr.add("mag", _tube2("Arrow", (nk[0], nk[2]), 0.0040, nk[1], nk[1] + m["arrow_len"], olive, 10),
               _tube2("ArrowHead", (nk[0], nk[2]), 0.0065, nk[1] + m["arrow_len"], nk[1] + m["arrow_len"] + 0.03,
                      steel, 10),
               _box("Fletch", (nk[0] - 0.0005, nk[1] + 0.01, nk[2] - 0.012), (nk[0] + 0.0005, nk[1] + 0.08,
                                                                               nk[2] + 0.012), red))
    elif n == "flamethrower":
        vg = m["vgrip"]
        pr.add("static", _grip("Grip", dark),
               _grip("VGrip", dark, tuple(vg)),
               _tube2("Body", (0.0, 0.058), 0.036, -0.07, 0.36, red),
               _box("Stock", (-0.020, -0.30, -0.02), (0.020, -0.06, 0.07), dark),
               _tube2("Nozzle", (0.0, 0.040), 0.016, 0.36, 0.64, steel),
               _tube2("Shield", (0.0, 0.040), 0.025, 0.42, 0.58, dark),
               _box("Rear", (-0.007, 0.030, 0.090), (0.007, 0.050, 0.1235), steel),
               _box("FrontS", (-0.0015, 0.556, 0.065), (0.0015, 0.562, 0.1235), steel),
               _box("Pilot", (-0.006, 0.630, 0.012), (0.006, 0.648, 0.026), orange))
        mw = m["magwell"]
        pr.add("mag", _cyl("Canister", (mw[0], mw[1], mw[2]), (mw[0], mw[1], mw[2] + s.mag["bottom"]), 0.045,
                           orange, 24))
    elif n == "saw":
        ab, br = m["arbor"], m["blade_r"]
        pr.add("static", _grip("Grip", dark),
               _box("Housing", (-0.025, -0.05, -0.03), (0.065, 0.20, 0.105), orange),
               _box("HandleLoop", (-0.012, -0.075, -0.06), (0.012, -0.05, 0.06), dark),
               _grip("SideGrip", dark, tuple(m["vgrip"])),
               _box("GripArm", (-0.075, 0.12, 0.07), (-0.025, 0.15, 0.09), dark),
               _box("Arm", (-0.036, 0.15, 0.005), (-0.024, 0.32, 0.055), dark),
               _box("Guard", (-0.068, 0.15, 0.04), (-0.058, 0.33, 0.19), orange))
        blade = [_cyl("Blade", (ab[0] - 0.0015, ab[1], ab[2]), (ab[0] + 0.0015, ab[1], ab[2]), br, steel, 48),
                 _cyl("Nut", (ab[0] - 0.008, ab[1], ab[2]), (ab[0] + 0.002, ab[1], ab[2]), 0.018, dark, 12)]
        for i in range(6):
            a = math.radians(60.0 * i)
            p = (ab[0] - 0.002, ab[1] + 0.10 * math.cos(a), ab[2] + 0.10 * math.sin(a))
            blade.append(_box(f"Mark{i}", (p[0] - 0.0005, p[1] - 0.012, p[2] - 0.006),
                              (p[0] + 0.0005, p[1] + 0.012, p[2] + 0.006), red))
        pr.add("mag", *blade)
        pr.dyn["spin_axis"] = ("X", tuple(ab))
    elif n == "minigun":
        pr.add("static", _grip("Grip", dark),
               _box("Housing", (-0.040, -0.10, 0.030), (0.040, 0.27, 0.120), olive),
               _cyl("Motor", (0.055, -0.02, 0.06), (0.055, 0.12, 0.06), 0.03, dark),
               _grip("SideGrip", dark, tuple(m["vgrip"])),
               _box("GripArm", (-0.095, 0.185, 0.010), (-0.050, 0.215, 0.040), dark),
               _cyl("Chute", (-0.085, 0.06, -0.03), tuple(m["feed"]), 0.016, dark))
        rot = []
        for i in range(6):
            a = math.radians(60.0 * i)
            rot.append(_tube2(f"Bbl{i}", (0.026 * math.cos(a), 0.075 + 0.026 * math.sin(a)), 0.0085, 0.27, 0.78,
                              steel, 12))
        rot += [_tube2("Clamp1", (0.0, 0.075), 0.040, 0.40, 0.42, dark), _tube2("Clamp2", (0.0, 0.075), 0.040,
                                                                              0.70, 0.72, dark)]
        pr.add("Rotor", *rot)
        mw = m["magwell"]
        hw = s.mag["hw"]
        pr.add("mag", _box("Box", (mw[0] - hw, mw[1] - 0.10, mw[2] + s.mag["bottom"]), (mw[0] + hw, mw[1] + 0.10,
                                                                                         mw[2]), olive))
        pr.dyn["spin_axis"] = ("Y", (0.0, 0.0, 0.075))
    return pr


def _tube2(name, c, r, y0, y1, mat, seg: int = 24):
    from _arms_review import _tube
    return _tube(name, c, r, y0, y1, mat, seg)


def _m(R, p) -> Matrix:
    from _arms_review import _m as mm
    return mm(R, p)


def _seg(ob, p0, p1) -> None:
    """Place a unit cylinder proxy (built along +Z from 0 to 1) between two world points."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    q = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized())
    ob.matrix_world = Matrix.Translation(p0) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((1.0, 1.0, d.length, 1.0))


def pose(pr: Proxy, s, st, Mg: Matrix, Mm: Matrix, f: int, clip: str, hand_l=None) -> None:
    """Move the proxy parts for one review frame (``Mg`` weapon, ``Mm`` magazine bone world)."""
    import _anim as A
    import _arms_breech as B
    m = s.markers
    for o in pr.parts["static"]:
        o.matrix_world = Mg
    for o in pr.parts["mag"]:
        o.matrix_world = Mm
    ex = st.extra
    if "Breech" in pr.parts:
        R = B.breech_rot(s, ex.get("breech", 0.0))
        h = m["hinge"]
        Mb = Mg @ _m(R, h - R @ h)
        for o in pr.parts["Breech"]:
            o.matrix_world = Mb
        for i, o in enumerate(pr.parts["Rims"]):
            o.matrix_world = Mb
            o.hide_render = i >= ex.get("chambered", len(pr.parts["Rims"]))
    if "Lever" in pr.parts:
        R = A.rxd(S.LEVER_OPEN_DEG * ex.get("lever", 0.0))
        pv = m["lever_pivot"]
        for o in pr.parts["Lever"]:
            o.matrix_world = Mg @ _m(R, pv - R @ pv)
    if "held" in pr.parts and hand_l is not None:
        o = pr.parts["held"][0]
        o.hide_render = not ex.get("shell", False)
        Rh, ph = hand_l
        # the round between thumb and index, along the hand's fingers
        p = ph + Rh @ np.array([0.012, 0.100, -0.020])
        o.matrix_world = _m(_rot3(Mg), p)
    if s.name == "crossbow":
        t = ex.get("string", 1.0)
        c = m["string_rest"] + (m["string_latched"] - m["string_rest"]) * t
        for o, x in zip(pr.parts["strings"], (-0.24, 0.24)):
            _seg(o, Mg @ Vector((x, 0.296, 0.040)), Mg @ Vector(tuple(c)))
        for o in pr.parts["mag"]:
            o.hide_render = not ex.get("bolt", True)
    if s.name == "bow":
        d = ex.get("draw", 0.0)
        nk = m["nock"] + np.array([0.0, -S.BOW_DRAW * d, 0.0])
        for o, cam in zip(pr.parts["strings"], (m["cam_upper"], m["cam_lower"])):
            _seg(o, Mg @ Vector((cam[0], cam[1] - 0.024, cam[2])), Mg @ Vector(tuple(nk)))
        for o in pr.parts["mag"]:
            o.hide_render = not ex.get("arrow", True)
    if "spin_axis" in pr.dyn:
        ax, c = pr.dyn["spin_axis"]
        ang = ex.get("spin", 0.0)
        Rs = Matrix.Translation(c) @ Matrix.Rotation(ang, 4, ax) @ Matrix.Translation(-Vector(c))
        group = pr.parts["Rotor"] if "Rotor" in pr.parts else pr.parts["mag"]
        base = Mg if "Rotor" in pr.parts else Mm
        for o in group:
            o.matrix_world = base @ Rs
    if s.name == "flamethrower":
        pass


def _rot3(M: Matrix) -> np.ndarray:
    return np.array([[M[i][j] for j in range(3)] for i in range(3)])
