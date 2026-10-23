"""Crew sentry gun (D-157; PD2 deployable sentry): the crew's own original folding auto-gun, built to ENV A's node
contract. Visual scene only: A's sentry prefab instances it, owns collision, targeting and the Yaw / Pitch rotation
(never animated here).

Original design: a compact three-leg folding stand (feet on a 0.5 m circle) in powder-coated charcoal with coyote
canvas leg sleeves, a squat centre column with a side-mounted ammunition can, a turntable yoke, and a boxy gun
receiver with a perforated barrel shroud, a short flash hider and a sensor block (lens + status LED) over the barrel.
A frontal armour plate with a barrel cut-out (``Shield``) rides the gun; it is visible in the glb and A hides it by
default (shown by the sentry armour upgrade).

Nodes (Godot names; Blender +Y = Godot -Z = the sentry's front):
* ``Base`` (origin = floor, centre; static): the stand, centre column and the AmmoBox mount.
* ``Base/AmmoBox``: the side ammunition can (A may scale / hide it as ammo runs low).
* ``Base/Yaw``: pivot 0.55 m above the floor; turns about Godot +Y. The turntable and the yoke arms.
* ``Base/Yaw/Pitch``: pivot on the trunnion axis 0.10 m above Yaw; tilts about Godot +X. The gun, the sensor.
* ``Base/Yaw/Pitch/Gun``: the gun mesh; ``Base/Yaw/Pitch/Muzzle``: Marker at the flash hider tip, Godot -Z = fire;
  ``Base/Yaw/Pitch/Shield``: the frontal plate mesh.
No collision. Rest pose: the gun level, facing Godot -Z. Palette: crew gear (charcoal powder coat, coyote canvas,
galvanised steel, a green status LED).
"""

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "props"))

from _pb import Kit  # noqa: E402

ASSET_ID = "eqp_sentry"
TRI_BUDGET = 9000
PARAMS = {}
EXPORT = {"animations": True}

#: heights (m): the yaw pivot above the floor, the pitch (trunnion) pivot above the yaw pivot
YAW_Z = 0.55
PITCH_Z = 0.10
#: the stand's feet circle radius (base about 0.5 m wide) and the barrel: shroud start / muzzle (Blender +Y from Pitch)
FOOT_R = 0.25
#: leg hinges on the hub (radius, height), leg directions (one straight back, two forward-out), the folded legs'
#: tilt out from vertical (clear of the gun and the turntable), the ammo can and carry handle in the gaps
HIP_R = 0.05
HIP_Z = 0.30
LEG_DEG = (270.0, 30.0, 150.0)
FOLD_TILT = 35.0
AMMO_DEG = -30.0
HANDLE_DEG = 210.0
#: the deploy clip length (s); A's SentryGun plays ``deploy`` on placement
DEPLOY_S = 0.8
BARREL_Y0 = 0.14
MUZZLE_Y = 0.60


def _leg_dirs(a: float):
    """(hinge, deployed unit vector, folded unit vector) of the leg in the radial plane at angle ``a``."""
    import mathutils
    hip = mathutils.Vector((math.cos(a) * HIP_R, math.sin(a) * HIP_R, HIP_Z))
    foot = mathutils.Vector((math.cos(a) * FOOT_R, math.sin(a) * FOOT_R, 0.03))
    out = mathutils.Vector((math.cos(a), math.sin(a), 0.0))
    folded = (out * math.sin(math.radians(FOLD_TILT)) + mathutils.Vector((0, 0, 1)) * math.cos(
        math.radians(FOLD_TILT))).normalized()
    return hip, foot, (foot - hip).normalized(), folded


def _stand(k: Kit):
    base = k.obj("Base")
    b = base.part(bevel=0.004)
    col_top = YAW_Z - 0.03
    b.cyl(0.055, 0.10, (0.0, 0.0, HIP_Z), "powder_charcoal", segs=16)                  # hinge hub
    b.cyl(0.034, col_top - 0.35, (0.0, 0.0, (0.35 + col_top) / 2), "steel_galv", segs=14)   # centre column
    b.cyl(0.05, 0.03, (0.0, 0.0, col_top - 0.015), "powder_charcoal", segs=18)        # bearing collar
    for d in LEG_DEG:                                                                  # leg hinge clevises
        c, s_ = math.cos(math.radians(d)), math.sin(math.radians(d))
        b.cyl(0.02, 0.05, (c * HIP_R, s_ * HIP_R, HIP_Z), "steel_galv", axis="Z", segs=10)
    # carry handle on the column in the back-left gap (Base/Handle marks the grip)
    ha = math.radians(HANDLE_DEG)
    hx, hy = math.cos(ha), math.sin(ha)
    b.rod((hx * 0.034, hy * 0.034, 0.37), (hx * 0.075, hy * 0.075, 0.37), 0.008, "steel_galv")
    b.rod((hx * 0.034, hy * 0.034, 0.47), (hx * 0.075, hy * 0.075, 0.47), 0.008, "steel_galv")
    b.rod((hx * 0.075, hy * 0.075, 0.37), (hx * 0.075, hy * 0.075, 0.47), 0.013, "bag_coyote")
    base_obj = base.build()
    k.empty("Handle", (hx * 0.075, hy * 0.075, 0.42), (0.0, 0.0, ha - math.pi / 2), parent=base_obj)
    legs = k.empty("Legs", (0.0, 0.0, 0.0), parent=base_obj)
    pivots = []
    for i, d in enumerate(LEG_DEG):
        hip, foot, _dep, _fold = _leg_dirs(math.radians(d))
        pivot = k.empty(f"Leg{i}", tuple(hip), parent=legs)
        pivot.rotation_mode = "QUATERNION"
        pivots.append(pivot)
        leg = k.obj(f"Leg{i}Mesh", parent=pivot)
        g = leg.part(bevel=0.004)
        f = tuple(foot - hip)
        g.rod((0.0, 0.0, 0.0), f, 0.016, "powder_charcoal", segs=8)
        mid = tuple(c * 0.45 for c in f)
        lo = tuple(c * 0.75 for c in f)
        g.rod(mid, lo, 0.021, "bag_coyote", segs=8)                                    # canvas leg sleeve
        g.cyl(0.032, 0.03, (f[0], f[1], f[2] - 0.015), "plastic_black", segs=12)      # foot pad
        leg.build()
    # ammunition can in the right-rear gap between legs (clear of the folded legs), on its own bracket
    ammo = k.obj("AmmoBox", parent=base_obj)
    a = ammo.part(bevel=0.003)
    a.bx((0.03, -0.035, 0.40), (0.075, 0.035, 0.46), "powder_charcoal")               # bracket
    a.bx((0.075, -0.07, 0.36), (0.165, 0.07, 0.50), "grenade_olive")                  # ammunition can
    a.bx((0.07, -0.075, 0.49), (0.17, 0.075, 0.505), "powder_charcoal")               # lid rim
    a.bx((0.105, -0.025, 0.505), (0.135, 0.025, 0.515), "steel_galv")                 # latch
    a.bx((0.165, -0.04, 0.40), (0.168, 0.04, 0.44), "paint_hazard_orange")            # stencil band
    can = ammo.build()
    can.rotation_euler = (0.0, 0.0, math.radians(AMMO_DEG))   # export bakes this into the mesh
    return base_obj, pivots


def _ease(t: float) -> float:
    """0..1: the legs swing down fast, land at 0.75 and kick back up a touch before settling (feet never sink)."""
    if t >= 1.0:
        return 1.0
    if t < 0.75:
        return 1.0 - (1.0 - t / 0.75) ** 3
    return 1.0 - 0.04 * math.sin(math.pi * (t - 0.75) / 0.25)


def _clips(pivots) -> None:
    """``deploy`` (folded -> standing, DEPLOY_S) and ``fold`` (its reverse) on the Leg pivots only: Base, Yaw and
    Pitch never move. One action per clip with a slot per leg, so the glTF exporter writes one animation per clip."""
    import bpy
    import mathutils
    n = int(round(DEPLOY_S * bpy.context.scene.render.fps))
    for clip in ("deploy", "fold"):
        act = bpy.data.actions.new(clip)
        for i, (pivot, d) in enumerate(zip(pivots, LEG_DEG)):
            _hip, _foot, dep, fold = _leg_dirs(math.radians(d))
            axis, angle = dep.rotation_difference(fold).to_axis_angle()
            ad = pivot.animation_data_create()
            ad.action = act
            for fi in range(n + 1):
                t = fi / n
                if clip == "deploy":
                    w = _ease(min(1.0, max(0.0, (t - 0.06 * i) / 0.82)))   # the legs open one after another
                else:
                    u = min(1.0, t / 0.9)
                    w = 1.0 - u * u * (3.0 - 2.0 * u)
                pivot.rotation_quaternion = mathutils.Quaternion(axis, angle * (1.0 - w))
                pivot.keyframe_insert("rotation_quaternion", frame=fi)
            track = ad.nla_tracks.new()
            track.name = clip
            strip = track.strips.new(clip, 0, act)
            strip.action_slot = ad.action_slot
            strip.extrapolation = "NOTHING"
            track.mute = True
            ad.action = None
        for fc in _fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
    for pivot in pivots:
        pivot.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)          # rest pose: standing


def _fcurves(act):
    """Every F-curve of a (slotted, Blender 4.4+) action."""
    out = []
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def _yaw(k: Kit, base):
    yaw = k.empty("Yaw", (0.0, 0.0, YAW_Z), parent=base)
    ym = k.obj("YawMesh", parent=yaw)
    y = ym.part(bevel=0.004)
    y.cyl(0.09, 0.035, (0.0, 0.0, 0.0), "powder_charcoal", segs=24)                   # turntable
    y.cyl(0.07, 0.012, (0.0, 0.0, 0.022), "steel_galv", segs=24)
    for sx in (-1, 1):                                                                  # yoke arms to the trunnion
        x0, x1 = sorted((sx * 0.085, sx * 0.105))
        y.bx((x0, -0.045, 0.01), (x1, 0.045, PITCH_Z + 0.04), "powder_charcoal")
    ym.build()
    return yaw


def _gun(k: Kit, yaw) -> None:
    pitch = k.empty("Pitch", (0.0, 0.0, PITCH_Z), parent=yaw)
    gun = k.obj("Gun", parent=pitch)
    g = gun.part(bevel=0.005, segments=2)
    t = gun.part(bevel=0.002)
    g.bx((-0.065, -0.20, -0.06), (0.065, BARREL_Y0 + 0.02, 0.065), "powder_charcoal")  # receiver
    g.bx((-0.07, -0.22, -0.03), (0.07, -0.19, 0.05), "metal_dark")                      # back plate
    t.cyl(0.022, 0.21, (0.0, 0.0, 0.0), "steel_galv", axis="X", segs=12)               # trunnion pin
    t.bx((-0.068, -0.12, -0.07), (0.068, 0.02, -0.06), "metal_dark")                    # feed tray
    t.bx((0.065, -0.08, -0.02), (0.075, 0.0, 0.03), "metal_dark")                      # feed port (to the can)
    shroud_len = MUZZLE_Y - 0.06 - BARREL_Y0
    t.cyl(0.034, shroud_len, (0.0, BARREL_Y0 + shroud_len / 2, 0.0), "metal_dark", axis="Y", segs=16)  # shroud
    n = 5
    for i in range(n):                                                                  # shroud vent rings
        t.cyl(0.0365, 0.012, (0.0, BARREL_Y0 + 0.05 + i * (shroud_len - 0.08) / (n - 1), 0.0), "powder_charcoal",
              axis="Y", segs=16)
    t.cyl(0.018, 0.04, (0.0, MUZZLE_Y - 0.04, 0.0), "steel_galv", axis="Y", segs=10)   # barrel tip
    t.cyl(0.026, 0.04, (0.0, MUZZLE_Y - 0.02, 0.0), "metal_dark", axis="Y", segs=10)   # flash hider
    # sensor block over the barrel root: a lens and the green status LED
    t.bx((-0.04, -0.02, 0.065), (0.04, 0.10, 0.12), "powder_charcoal")
    t.cyl(0.022, 0.012, (0.0, 0.104, 0.092), "plastic_black", axis="Y", segs=14)
    t.cyl(0.012, 0.006, (0.0, 0.112, 0.092), "emit_led_cold", axis="Y", segs=12)
    t.bx((0.025, 0.098, 0.105), (0.035, 0.104, 0.113), "emit_led_green")
    t.bx((-0.045, -0.10, 0.065), (0.045, -0.085, 0.08), "bag_coyote")                   # carry strap stub
    gun.build()
    shield = k.obj("Shield", parent=pitch)
    s = shield.part(bevel=0.003)
    sy0, sy1 = BARREL_Y0 + 0.03, BARREL_Y0 + 0.045
    for x0, x1, z0, z1 in ((-0.17, -0.045, -0.13, 0.17), (0.045, 0.17, -0.13, 0.17), (-0.045, 0.045, 0.045, 0.17),
                           (-0.045, 0.045, -0.13, -0.045)):
        s.bx((x0, sy0, z0), (x1, sy1, z1), "armor_charcoal")
    s.bx((-0.17, sy0 - 0.002, 0.15), (0.17, sy1 + 0.002, 0.17), "bag_coyote")          # top edge band
    shield.build()
    k.empty("Muzzle", (0.0, MUZZLE_Y, 0.0), parent=pitch)


def build(ctx) -> None:
    k = Kit(ctx)
    base, pivots = _stand(k)
    yaw = _yaw(k, base)
    _gun(k, yaw)
    _clips(pivots)
