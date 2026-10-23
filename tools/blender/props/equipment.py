"""Crew equipment (D-111 prop art pass): deployables, drill / saw devices, the enemy-drop ammo box and the
bag-zipline anchor. Original models at PD2-faithful sizes; no third-party assets.

Blender +Y = Godot -Z (the front), +Z up. Prefab visuals carry no collision (the prefab owns it).

* Deployables (`deployable` prefab visual = DeployableDef.model; deployable.gd: floor object, origin on the
  floor at the footprint centre, front -Z faces the crew member who placed it), all in their placed pose,
  each with a `Handle` marker where the right hand grips the held form (visual_slots.md D-069):
  doctor bag (black medic duffel, red cross patches), ammo bag (olive duffel, flap open on magazines),
  ECM jammer (anodised box, four antennae raised, status `Led`), first-aid kit (white hard case, red cross),
  trip mine (olive polymer box, `Led`, laser lens with a `Laser` marker, -Z = beam), body-bag case (black hard
  case, orange label) and armor bag (black duffel with a coyote plate carrier strapped on top).
* Devices (`drill` prefab visual = drill_point.device_scene, visual_slots.md: a `Bit` MeshInstance3D that
  DrillPoint spins about its local Z while RUNNING). Like prop_drill_device the origin is the working tip on
  the target face and +Y (Godot -Z) points into it:
  - `prop_thermal_drill_device`: a thermic lance rig. The glowing lance (`Bit`) runs out of a heat-shielded
    burner head on a long red canister body, fed by two thermite bottles, standing on a tripod whose feet are
    PARAMS `floor` (1.0 m, the THERMAL drill points on ND / DB / GN) below the tip.
  - `prop_saw_device`: a clamp-on circular saw (two suction-clamp pads on the face, a yellow motor on a steel
    arm). The 0.36 m blade cuts square into the face, so its axle is horizontal: the `Bit` mesh sits under a
    `BladeAxle` empty turned so the Bit's local Z is the axle (it spins in the blade plane).
* `prop_ammo_pickup` (`pickup` visual; AmmoPickup `Visual` placeholder 0.24 x 0.12 x 0.16): an olive polymer
  ammo can with a loose magazine, origin on the floor at the centre.
* `prop_zipline_anchor` (`zipline` visual, wall-mounted: back-centre pivot): a bolted plate, a yellow pulley
  housing on a stand-off arm with the sheave, a cable stub leaving +Y and a `Line` marker at the sheave groove
  where the line starts (the prefab draws no cable yet).
"""

import math

from _pb import Kit

TRI_BUDGET = 8000
_DEP = {"prefab": "deployable"}
VARIANTS = {
    "prop_deploy_doctor_bag": {"fn": "doctor_bag", "cat": {**_DEP, "kind": "doctor_bag", "surface": "fabric"}},
    "prop_deploy_ammo_bag": {"fn": "ammo_bag", "cat": {**_DEP, "kind": "ammo_bag", "surface": "fabric"}},
    "prop_deploy_ecm": {"fn": "ecm", "cat": {**_DEP, "kind": "ecm", "surface": "metal"}},
    "prop_deploy_fak": {"fn": "fak", "cat": {**_DEP, "kind": "fak", "surface": "wood"}},
    "prop_deploy_trip_mine": {"fn": "trip_mine", "cat": {**_DEP, "kind": "trip_mine", "surface": "metal"}},
    "prop_deploy_body_bag_case": {"fn": "body_bag_case", "cat": {**_DEP, "kind": "body_bag_case", "surface": "wood"}},
    "prop_deploy_armor_bag": {"fn": "armor_bag", "cat": {**_DEP, "kind": "armor_bag", "surface": "fabric"}},
    "prop_thermal_drill_device": {"fn": "thermal_drill", "floor": 1.0,
                                  "cat": {"prefab": "drill", "kind": "thermal_drill", "surface": "metal",
                                          "fx": {"tip": [0.0, 0.0, 0.01]}}},
    # OF's lid (A r305, the PO): the same rig burning DOWN, its tripod's feet in the tip plane round the lance, so
    # with -Z pitched down (DrillPoint meta pitch -90) it stands on the slab it burns through
    "prop_thermal_drill_down": {"fn": "thermal_drill", "down": True, "floor": 0.0,
                                "cat": {"prefab": "drill", "kind": "thermal_drill", "surface": "metal",
                                        "fx": {"tip": [0.0, 0.0, 0.01]}}},
    "prop_saw_device": {"fn": "saw", "cat": {"prefab": "drill", "kind": "saw", "surface": "metal"}},
    "prop_ammo_pickup": {"fn": "ammo_pickup", "cat": {"prefab": "pickup", "kind": "ammo_pickup", "surface": "wood"}},
    "prop_zipline_anchor": {"fn": "zipline_anchor",
                            "cat": {"prefab": "zipline", "kind": "zipline_anchor", "mount": "wall", "surface": "metal"}},
}


# ------------------------------------------------------------------------------------ shared bits

def _duffel(o, lx: float, ly: float, lz: float, key: str, trim: str = "rubber") -> None:
    """Soft duffel: a heavily rounded body, two carry handles over the top, side straps, end pulls and a
    zip seam along the top. Footprint centred on the origin, bottom at z = 0."""
    soft = o.part(bevel=min(ly, lz) * 0.3, segments=3)
    soft.bx((-lx / 2, -ly / 2, 0.0), (lx / 2, ly / 2, lz), key)
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * lx * 0.2
        r = ly * 0.3
        t.tube([(x, -r * math.cos(math.pi * i / 8), lz - 0.012 + r * 0.9 * math.sin(math.pi * i / 8)) for i in range(9)],
               0.011, trim, segs=6)
        t.bx((x - 0.019, -ly / 2 - 0.003, 0.025), (x + 0.019, ly / 2 + 0.003, lz * 0.55), trim)
        # end pull loops
        t.torus(0.03, 0.006, (sx * (lx / 2 + 0.004), 0.0, lz * 0.62), trim, segs=12, rsegs=4, axis="X")
    # zip seam and slider
    t.bx((-lx * 0.38, -0.007, lz - 0.003), (lx * 0.38, 0.007, lz + 0.004), "steel")
    t.cbox((lx * 0.3, 0.0, lz + 0.008), (0.03, 0.016, 0.008), "steel")


def _cross(p, cx: float, cz: float, y: float, size: float, key: str, axis: str = "Y", depth: float = 0.004) -> None:
    """A Greek cross plate on a face: normal along +Y (front) at depth ``y`` or along +Z (top)."""
    a, b = size / 2, size / 6
    if axis == "Y":
        p.bx((cx - a, y, cz - b), (cx + a, y + depth, cz + b), key)
        p.bx((cx - b, y, cz - a), (cx + b, y + depth, cz - b), key)
        p.bx((cx - b, y, cz + b), (cx + b, y + depth, cz + a), key)
    else:  # top face: (cx, cz) = (x, y), y = the face height
        p.bx((cx - a, cz - b, y), (cx + a, cz + b, y + depth), key)
        p.bx((cx - b, cz - a, y), (cx + b, cz - b, y + depth), key)
        p.bx((cx - b, cz + b, y), (cx + b, cz + a, y + depth), key)


def _hard_case(o, lx: float, ly: float, lz: float, key: str) -> None:
    """Rugged hard case lying flat: two shells with a rim at mid-height, ribs, two latches and a fold-down
    handle on the +Y (front) long side, rubber feet."""
    h = o.part(bevel=0.012, segments=2)
    h.bx((-lx / 2, -ly / 2, 0.006), (lx / 2, ly / 2, lz * 0.5 - 0.004), key)
    h.bx((-lx / 2, -ly / 2, lz * 0.5 + 0.004), (lx / 2, ly / 2, lz), key)
    t = o.part(bevel=0.003)
    t.bx((-lx / 2 - 0.006, -ly / 2 - 0.006, lz * 0.5 - 0.01), (lx / 2 + 0.006, ly / 2 + 0.006, lz * 0.5 + 0.01), key)
    for sx in (-1, 1):
        # lid ribs and latches
        t.bx((sx * lx * 0.3 - 0.015, -ly / 2 + 0.03, lz - 0.002), (sx * lx * 0.3 + 0.015, ly / 2 - 0.03, lz + 0.008), key)
        t.bx((sx * lx * 0.28 - 0.028, ly / 2 + 0.004, lz * 0.5 - 0.035), (sx * lx * 0.28 + 0.028, ly / 2 + 0.016, lz * 0.5 + 0.03),
             "polymer")
        t.bx((sx * lx * 0.28 - 0.02, ly / 2 + 0.016, lz * 0.5 - 0.01), (sx * lx * 0.28 + 0.02, ly / 2 + 0.02, lz * 0.5 + 0.024),
             "steel")
        for sy in (-1, 1):
            t.cyl(0.018, 0.008, (sx * (lx / 2 - 0.05), sy * (ly / 2 - 0.05), 0.004), "rubber", segs=10)
    # handle hinged on the lower shell's front, folded down
    t.bx((-0.07, ly / 2 + 0.006, lz * 0.5 - 0.06), (-0.05, ly / 2 + 0.03, lz * 0.5 - 0.035), key)
    t.bx((0.05, ly / 2 + 0.006, lz * 0.5 - 0.06), (0.07, ly / 2 + 0.03, lz * 0.5 - 0.035), key)
    t.rod((-0.06, ly / 2 + 0.03, lz * 0.5 - 0.075), (0.06, ly / 2 + 0.03, lz * 0.5 - 0.075), 0.011, "rubber", segs=8)
    t.rod((-0.06, ly / 2 + 0.02, lz * 0.5 - 0.05), (-0.06, ly / 2 + 0.03, lz * 0.5 - 0.075), 0.007, "polymer", segs=6)
    t.rod((0.06, ly / 2 + 0.02, lz * 0.5 - 0.05), (0.06, ly / 2 + 0.03, lz * 0.5 - 0.075), 0.007, "polymer", segs=6)


def _magazine(p, x: float, y: float, z: float, tilt: float, key: str = "polymer") -> None:
    """Curved rifle magazine standing in a bag / on the floor (spine along +Z, tilted about X by ``tilt``)."""
    c, s = math.cos(tilt), math.sin(tilt)

    def rot(py: float, pz: float) -> tuple[float, float]:
        return y + py * c - pz * s, z + py * s + pz * c

    pts = []
    for i in range(5):
        u = i / 4
        py, pz = rot(0.03 * u * u, 0.17 * u)
        pts.append((x, py, pz))
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        p.rod(a, b, 0.016, key, segs=6, square=True)
    tx, ty, tz = pts[-1]
    p.cbox((tx, ty, tz + 0.006), (0.02, 0.028, 0.012), "brass_case")


# ------------------------------------------------------------------------------------ deployables

def _doctor_bag(k: Kit, p: dict) -> None:
    """PD2 doctor bag: a black medic duffel (0.5 x 0.3 x 0.27) with red cross patches on the top and both
    long sides, a white cross on each, and reflective strips."""
    lx, ly, lz = 0.5, 0.3, 0.27
    o = k.obj("Bag")
    _duffel(o, lx, ly, lz, "bag_black")
    pt = o.part(bevel=0.002)
    # top patch (between the handles) and front / back patches
    pt.bx((-0.065, -0.07, lz - 0.004), (0.065, 0.07, lz + 0.002), "bag_red")
    _cross(pt, 0.0, 0.0, lz + 0.002, 0.1, "plastic_white", axis="Z", depth=0.003)
    for sy in (-1, 1):
        y0 = sy * (ly / 2 + 0.001)
        lo, hi = sorted((y0, y0 + sy * 0.003))
        pt.bx((-0.08, lo, 0.07), (0.08, hi, 0.2), "bag_red")
        lo2, hi2 = sorted((y0 + sy * 0.003, y0 + sy * 0.006))
        _cross(pt, 0.0, 0.135, lo2, 0.1, "plastic_white", depth=hi2 - lo2)
        # reflective strip low along the side
        lo3, hi3 = sorted((y0, y0 + sy * 0.002))
        pt.bx((-lx * 0.42, lo3, 0.035), (-lx * 0.24, hi3, 0.05), "metal_white")
        pt.bx((lx * 0.24, lo3, 0.035), (lx * 0.42, hi3, 0.05), "metal_white")
    o.build()
    k.empty("Handle", (0.0, 0.0, lz + 0.075))


def _ammo_bag(k: Kit, p: dict) -> None:
    """PD2 ammo bag: an olive duffel (0.55 x 0.32 x 0.28) with its top flap thrown back on rifle magazines and
    loose cartridges, a yellow ammo stencil plate on the front."""
    lx, ly, lz = 0.55, 0.32, 0.28
    o = k.obj("Bag")
    soft = o.part(bevel=0.06, segments=3)
    # open-top body: walls round a sunken floor
    w = 0.03
    soft.bx((-lx / 2, -ly / 2, 0.0), (lx / 2, ly / 2, 0.05), "bag_olive")
    soft.bx((-lx / 2, -ly / 2, 0.0), (lx / 2, -ly / 2 + w, lz), "bag_olive")
    soft.bx((-lx / 2, ly / 2 - w, 0.0), (lx / 2, ly / 2, lz), "bag_olive")
    soft.bx((-lx / 2, -ly / 2, 0.0), (-lx / 2 + w, ly / 2, lz), "bag_olive")
    soft.bx((lx / 2 - w, -ly / 2, 0.0), (lx / 2, ly / 2, lz), "bag_olive")
    inside = o.part(bevel=0.0)
    inside.bx((-lx / 2 + w, -ly / 2 + w, 0.05), (lx / 2 - w, ly / 2 - w, lz - 0.09), "bag_black")
    # flap hinged on the back top edge, lying back over the -Y side
    flap = o.part(bevel=0.012, segments=2)
    flap.profile_x([(-ly / 2 - 0.005, lz - 0.01), (-ly / 2 + 0.01, lz + 0.01), (-ly / 2 - 0.2, lz - 0.08),
                    (-ly / 2 - 0.21, lz - 0.1)], -lx / 2 + 0.01, lx / 2 - 0.01, "bag_olive")
    # magazines in two rows, cartridges on top
    mags = o.part(bevel=0.0)
    for i in range(6):
        x = -lx / 2 + 0.07 + i * 0.082
        _magazine(mags, x, -0.05, lz - 0.17, 0.12 + 0.05 * (i % 2))
        _magazine(mags, x + 0.03, 0.06, lz - 0.18, -0.08 - 0.04 * (i % 3))
    for i in range(7):
        x = -0.18 + i * 0.055
        mags.rod((x, 0.0, lz - 0.08), (x + 0.012, 0.03, lz - 0.075), 0.0055, "brass_case", segs=6)
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * lx * 0.2
        t.bx((x - 0.019, -ly / 2 - 0.003, 0.025), (x + 0.019, ly / 2 + 0.003, lz * 0.6), "rubber")
        t.tube([(x, ly / 2 + 0.003, lz * 0.6), (x, ly / 2 + 0.04, lz + 0.03), (x, ly / 2 - 0.02, lz + 0.06)], 0.011,
               "rubber", segs=6)
        t.torus(0.03, 0.006, (sx * (lx / 2 + 0.004), 0.0, lz * 0.55), "rubber", segs=12, rsegs=4, axis="X")
    # stencil plate: yellow with three cartridge silhouettes
    t.bx((-0.09, ly / 2 + 0.003, 0.08), (0.09, ly / 2 + 0.007, 0.18), "metal_yellow")
    for i in range(3):
        x = -0.045 + i * 0.045
        t.bx((x - 0.009, ly / 2 + 0.007, 0.1), (x + 0.009, ly / 2 + 0.009, 0.15), "metal_dark")
        t.bx((x - 0.006, ly / 2 + 0.007, 0.15), (x + 0.006, ly / 2 + 0.009, 0.162), "metal_dark")
    o.build()
    k.empty("Handle", (lx * 0.2, ly / 2 + 0.02, lz + 0.05))


def _ecm(k: Kit, p: dict) -> None:
    """PD2 ECM jammer, placed: an anodised box (0.26 x 0.17 x 0.07) on rubber feet, cooling fins on top, four
    antennae raised in a fan (deployed), a display window and a status `Led` on the front."""
    lx, ly, lz = 0.26, 0.17, 0.07
    o = k.obj("Body")
    h = o.part(bevel=0.006, segments=2)
    h.bx((-lx / 2, -ly / 2, 0.008), (lx / 2, ly / 2, 0.008 + lz), "alu_black")
    top = 0.008 + lz
    t = o.part(bevel=0.0015)
    for i in range(7):
        x = -lx / 2 + 0.035 + i * 0.016
        t.bx((x - 0.003, -ly / 2 + 0.02, top), (x + 0.003, ly / 2 - 0.03, top + 0.01), "alu_black")
    # front: display window, buttons, a switch guard
    t.bx((-0.105, ly / 2, 0.025), (0.02, ly / 2 + 0.004, 0.065), "polymer")
    t.bx((-0.098, ly / 2 + 0.004, 0.031), (0.013, ly / 2 + 0.006, 0.059), "emit_screen")
    for i in range(3):
        t.cyl(0.006, 0.006, (0.04 + i * 0.022, ly / 2 + 0.003, 0.05), "rubber", axis="Y", segs=10)
    t.bx((0.04, ly / 2, 0.022), (0.086, ly / 2 + 0.012, 0.032), "safety_orange")
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.cyl(0.012, 0.008, (sx * (lx / 2 - 0.025), sy * (ly / 2 - 0.025), 0.004), "rubber", segs=10)
    # antennae: SMA bases on the top corners, whips fanned up (deployed pose)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx_, by_ = sx * (lx / 2 - 0.022), sy * (ly / 2 - 0.02)
            t.cyl(0.008, 0.012, (bx_, by_, top + 0.006), "brass", segs=10)
            t.cyl(0.006, 0.03, (bx_, by_, top + 0.027), "polymer", segs=10)
            tip = (bx_ + sx * 0.06, by_ + sy * 0.035, top + 0.042 + 0.2 + 0.03 * (sy > 0))
            t.rod((bx_, by_, top + 0.042), tip, 0.0035, "polymer", segs=6)
            t.sphere(0.005, tip, "polymer", segs=6, rings=3)
    o.build()
    led = k.obj("Led")
    led.part(bevel=0.0).cyl(0.006, 0.004, (0.1, ly / 2 + 0.002, 0.065), "emit_led_green", axis="Y", segs=10)
    led.build()
    k.empty("Handle", (0.0, 0.0, top))


def _fak(k: Kit, p: dict) -> None:
    """PD2 first-aid kit: a white hard case (0.3 x 0.2 x 0.09) with a red cross on the lid, two red latches and
    a carry handle."""
    lx, ly, lz = 0.3, 0.2, 0.09
    o = k.obj("Body")
    h = o.part(bevel=0.01, segments=2)
    h.bx((-lx / 2, -ly / 2, 0.004), (lx / 2, ly / 2, lz * 0.55 - 0.002), "plastic_white")
    h.bx((-lx / 2 + 0.003, -ly / 2 + 0.003, lz * 0.55 + 0.002), (lx / 2 - 0.003, ly / 2 - 0.003, lz), "plastic_white")
    t = o.part(bevel=0.002)
    t.bx((-lx / 2 - 0.003, -ly / 2 - 0.003, lz * 0.55 - 0.006), (lx / 2 + 0.003, ly / 2 + 0.003, lz * 0.55 + 0.006),
         "plastic_grey")
    _cross(t, 0.0, 0.0, lz, 0.11, "metal_red", axis="Z", depth=0.003)
    for sx in (-1, 1):
        t.bx((sx * 0.09 - 0.016, ly / 2, lz * 0.55 - 0.022), (sx * 0.09 + 0.016, ly / 2 + 0.01, lz * 0.55 + 0.02), "metal_red")
        for sy in (-1, 1):
            t.cyl(0.012, 0.004, (sx * (lx / 2 - 0.03), sy * (ly / 2 - 0.03), 0.002), "rubber", segs=8)
    # handle on the front lower shell
    t.bx((-0.06, ly / 2, 0.014), (-0.045, ly / 2 + 0.02, 0.028), "plastic_grey")
    t.bx((0.045, ly / 2, 0.014), (0.06, ly / 2 + 0.02, 0.028), "plastic_grey")
    t.rod((-0.052, ly / 2 + 0.024, 0.016), (0.052, ly / 2 + 0.024, 0.016), 0.008, "plastic_grey", segs=8)
    o.build()
    k.empty("Handle", (0.0, ly / 2 + 0.024, 0.016))


def _trip_mine(k: Kit, p: dict) -> None:
    """PD2 trip mine, armed on the floor: an olive polymer box (0.13 x 0.07 x 0.05) on a tilted foot plate, the
    laser emitter lens on the front (`Laser` marker, -Z = the beam), arming `Led`, a charge seam and bolts."""
    lx, ly, lz = 0.13, 0.07, 0.05
    o = k.obj("Body")
    base = o.part(bevel=0.002)
    base.bx((-0.075, -0.05, 0.0), (0.075, 0.05, 0.006), "polymer")
    h = o.part(bevel=0.006, segments=2)
    h.bx((-lx / 2, -ly / 2, 0.006), (lx / 2, ly / 2, 0.006 + lz), "polymer_olive")
    top = 0.006 + lz
    t = o.part(bevel=0.0)
    t.bx((-lx / 2 - 0.002, -ly / 2 - 0.002, 0.03), (lx / 2 + 0.002, ly / 2 + 0.002, 0.034), "polymer")
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.cyl(0.004, 0.004, (sx * (lx / 2 - 0.012), sy * (ly / 2 - 0.012), top + 0.002), "steel_bare", segs=8)
    # emitter turret on the front
    t.cyl(0.016, 0.02, (0.0, ly / 2 + 0.01, 0.034), "alu_black", axis="Y", segs=14)
    t.cyl(0.009, 0.004, (0.0, ly / 2 + 0.021, 0.034), "glass_tinted", axis="Y", segs=12)
    t.cyl(0.004, 0.002, (0.0, ly / 2 + 0.0235, 0.034), "emit_led_red", axis="Y", segs=8)
    # warning label on the top
    t.bx((-0.04, -0.022, top), (0.03, 0.022, top + 0.002), "metal_yellow")
    o.build()
    led = k.obj("Led")
    led.part(bevel=0.0).cyl(0.004, 0.004, (0.048, 0.0, top + 0.002), "emit_led_red", segs=8)
    led.build()
    k.empty("Laser", (0.0, ly / 2 + 0.025, 0.034))
    k.empty("Handle", (0.0, 0.0, top))


def _body_bag_case(k: Kit, p: dict) -> None:
    """PD2 body bag case: a black rugged hard case (0.56 x 0.38 x 0.2) with an orange label plate and a folded
    body bag tucked under the lid strap."""
    lx, ly, lz = 0.56, 0.38, 0.2
    o = k.obj("Body")
    _hard_case(o, lx, ly, lz, "polymer")
    t = o.part(bevel=0.002)
    t.bx((-0.11, -0.05, lz + 0.008), (0.11, 0.05, lz + 0.011), "safety_orange")
    for i in range(3):
        t.bx((-0.08 + i * 0.05, -0.012, lz + 0.011), (-0.06 + i * 0.05, 0.012, lz + 0.013), "polymer")
    o.build()
    k.empty("Handle", (0.0, ly / 2 + 0.03, lz * 0.5 - 0.075))


def _armor_bag(k: Kit, p: dict) -> None:
    """Armor bag: a black duffel (0.66 x 0.36 x 0.3) with a coyote plate carrier strapped on top (front plate
    pocket, magazine pouches, shoulder straps)."""
    lx, ly, lz = 0.66, 0.36, 0.3
    o = k.obj("Bag")
    _duffel(o, lx, ly, lz, "bag_black")
    v = o.part(bevel=0.015, segments=2)
    vz = lz - 0.02
    v.bx((-0.2, -0.13, vz), (0.2, 0.13, vz + 0.045), "bag_coyote")
    pv = o.part(bevel=0.006)
    for i in range(3):
        x = -0.12 + i * 0.12
        pv.bx((x - 0.05, -0.05, vz + 0.045), (x + 0.05, 0.1, vz + 0.085), "bag_coyote")
        pv.bx((x - 0.052, 0.06, vz + 0.05), (x + 0.052, 0.104, vz + 0.088), "bag_coyote")
    s = o.part(bevel=0.0)
    for sx in (-1, 1):
        s.bx((sx * 0.16 - 0.025, -0.13, vz + 0.045), (sx * 0.16 + 0.025, -0.02, vz + 0.052), "bag_coyote")
        # tie-down strap round the bag
        x = sx * 0.24
        s.bx((x - 0.02, -ly / 2 - 0.006, 0.03), (x + 0.02, -ly / 2 - 0.002, lz - 0.01), "rubber")
        s.bx((x - 0.02, ly / 2 + 0.002, 0.03), (x + 0.02, ly / 2 + 0.006, lz - 0.01), "rubber")
        s.bx((x - 0.02, -ly / 2 + 0.03, lz + 0.004), (x + 0.02, ly / 2 - 0.03, lz + 0.01), "rubber")
        s.cbox((x, ly / 2 + 0.008, lz * 0.55), (0.05, 0.006, 0.03), "polymer")
    o.build()
    k.empty("Handle", (lx * 0.2, 0.0, lz + 0.075))


# ------------------------------------------------------------------------------------ devices

def _thermal_drill(k: Kit, p: dict) -> None:
    """Thermic lance rig: origin = the lance tip on the door face, +Y into it. A burner head with a round heat
    shield, a long red canister body with steel bands and a status box, two thermite bottles with gauges and
    hoses on its back, all on a tripod whose rubber feet stand ``floor`` m below the tip. ``down``: the drill-down
    variant (pitched lance-down on a floor): the tripod's feet lie in the tip plane (Blender y 0) round the lance, the
    legs rising to a collar on the canister."""
    fl = p["floor"]
    down = bool(p.get("down", False))
    body = k.obj("Body")
    hard = body.part(bevel=0.008, segments=2)
    trim = body.part(bevel=0.0)
    # heat shield and burner head
    trim.cyl(0.06, 0.12, (0.0, -0.37, 0.0), "chrome", axis="Y", segs=20)
    trim.cyl(0.1, 0.05, (0.0, -0.455, 0.0), "metal_dark", axis="Y", segs=24)
    trim.cyl(0.2, 0.012, (0.0, -0.3, 0.0), "steel", axis="Y", segs=32)
    trim.torus(0.2, 0.008, (0.0, -0.3, 0.0), "steel", segs=32, rsegs=4, axis="Y")
    # canister body
    trim.cyl(0.14, 0.72, (0.0, -0.84, 0.0), "metal_red", axis="Y", segs=28)
    trim.cyl(0.11, 0.04, (0.0, -1.22, 0.0), "metal_dark", axis="Y", segs=24)
    for y in (-0.53, -0.72, -0.96, -1.15):
        trim.torus(0.14, 0.009, (0.0, y, 0.0), "steel", segs=28, rsegs=4, axis="Y")
    # status box on the right side
    hard.bx((0.13, -0.95, -0.06), (0.2, -0.72, 0.07), "metal_dark")
    trim.bx((0.2, -0.92, -0.02), (0.204, -0.75, 0.05), "polymer")
    trim.bx((0.204, -0.9, 0.0), (0.206, -0.8, 0.035), "emit_led_green")
    trim.bx((0.204, -0.78, 0.0), (0.206, -0.76, 0.02), "emit_led_red")
    # carry handle over the top
    trim.tube([(0.0, -0.62, 0.14), (0.0, -0.62, 0.22), (0.0, -1.06, 0.22), (0.0, -1.06, 0.14)], 0.014, "rubber", segs=8)
    # thermite bottles (two, on the left back), gauges, hoses into the burner head
    for i, y in enumerate((-0.98, -0.72)):
        x, zb = -0.26, -0.42
        trim.lathe([(0.0, 0.0), (0.075, 0.0), (0.075, 0.42), (0.06, 0.47), (0.02, 0.5), (0.02, 0.53), (0.0, 0.53)],
                   "metal_red" if i == 0 else "metal_grey", centre=(x, y, zb), segs=20)
        trim.torus(0.075, 0.006, (x, y, zb + 0.32), "metal_yellow", segs=20, rsegs=4)
        trim.cyl(0.022, 0.012, (x + 0.02, y + 0.045, zb + 0.5), "chrome", axis="Y", segs=12)
        trim.tube([(x, y, zb + 0.53), (x + 0.03, y, zb + 0.6), (-0.12, y + 0.1, 0.12), (-0.05, -0.42, 0.08)], 0.009,
                  "rubber", segs=6)
    # bottle cradle tying the bottles to the body
    hard.bx((-0.34, -1.07, -0.44), (-0.18, -0.63, -0.42), "metal_dark")
    for y in (-1.0, -0.7):
        trim.rod((-0.2, y, -0.3), (-0.12, y, -0.05), 0.012, "steel", segs=8)
    if down:
        # three legs from a collar round the canister (y -0.9) down to feet in the tip plane, 120 deg apart
        trim.torus(0.16, 0.02, (0.0, -0.9, 0.0), "metal_dark", segs=28, rsegs=6, axis="Y")
        for ang in (90.0, 210.0, 330.0):
            a = math.radians(ang)
            c = (0.16 * math.cos(a), -0.9, 0.16 * math.sin(a))
            f = (0.55 * math.cos(a), 0.0, 0.55 * math.sin(a))
            trim.rod(c, (f[0], f[1] - 0.03, f[2]), 0.018, "steel", segs=8)
            trim.cyl(0.04, 0.03, (f[0], -0.015, f[2]), "rubber", axis="Y", segs=12)
        body.build()
        _thermal_bit(k)
        return
    # tripod: hub under the body, three legs to the floor, rubber feet
    hub = (0.0, -0.84, -0.17)
    trim.cyl(0.05, 0.06, hub, "metal_dark", segs=16)
    trim.rod((0.0, -0.84, -0.14), (0.0, -0.84, -0.11), 0.03, "steel", segs=12)
    feet = [(0.42, -0.6, -fl), (-0.42, -0.6, -fl), (0.0, -1.38, -fl)]
    for f in feet:
        knee = (hub[0] + (f[0] - hub[0]) * 0.12, hub[1] + (f[1] - hub[1]) * 0.12, hub[2] - 0.03)
        trim.rod(knee, (f[0], f[1], f[2] + 0.03), 0.016, "steel", segs=8)
        trim.cyl(0.035, 0.03, (f[0], f[1], f[2] + 0.015), "rubber", segs=12)
        trim.rod((hub[0], hub[1], hub[2] - 0.2), ((knee[0] + f[0]) / 2, (knee[1] + f[1]) / 2, (knee[2] + f[2]) / 2 + 0.2),
                 0.008, "steel", segs=6)
    trim.cyl(0.03, 0.2, (hub[0], hub[1], hub[2] - 0.12), "steel", segs=12)
    body.build()
    _thermal_bit(k)


def _thermal_bit(k: Kit) -> None:
    # Bit: the lance from the burner head to the door face, glowing towards the tip (spins about its axis)
    bit = k.obj("Bit", location=(0.0, -0.12, 0.0))
    bp = bit.part(bevel=0.0)
    bp.cyl(0.014, 0.2, (0.0, -0.08, 0.0), "steel", axis="Y", segs=12)
    bp.cyl(0.015, 0.06, (0.0, 0.05, 0.0), "emit_amber", axis="Y", segs=12)
    bp.cyl(0.017, 0.04, (0.0, 0.1, 0.0), "emit_sodium", axis="Y", segs=12)
    bp.sphere(0.024, (0.0, 0.12, 0.0), "emit_sodium", segs=12, rings=6, scale=(1.0, 0.6, 1.0))
    bit.build()


def _saw(k: Kit, p: dict) -> None:
    """Clamp-on circular saw: origin = the cut on the face, +Y into it. Two suction-clamp pads on the face carry
    a steel rail; a yellow motor on a swing arm drives a 0.36 m blade square into the face (its edge 4 cm deep)
    under a half guard."""
    r = 0.18
    cy = -0.14  # blade centre: 4 cm of blade inside the face
    body = k.obj("Body")
    hard = body.part(bevel=0.006, segments=2)
    trim = body.part(bevel=0.0)
    # clamp pads either side of the cut and the rail between them
    for sx in (-1, 1):
        x = sx * 0.2
        trim.cyl(0.07, 0.02, (x, -0.01, -0.12), "rubber", axis="Y", segs=20)
        trim.cyl(0.05, 0.03, (x, -0.035, -0.12), "metal_dark", axis="Y", segs=16)
        trim.rod((x - 0.04, -0.06, -0.12), (x + 0.04, -0.06, -0.12), 0.008, "steel", segs=6)
        trim.rod((x, -0.05, -0.12), (x, -0.07, -0.12), 0.012, "steel", segs=8)
    hard.bx((-0.24, -0.09, -0.15), (0.24, -0.06, -0.09), "metal_dark")
    # swing arm up to the motor, the motor (axle along X), gearbox on the blade side
    trim.rod((-0.05, -0.08, -0.12), (-0.06, cy - 0.02, 0.0), 0.02, "steel", segs=10, square=True)
    trim.cyl(0.075, 0.2, (-0.16, cy, 0.0), "metal_yellow", axis="X", segs=24)
    for i in range(4):
        trim.torus(0.075, 0.005, (-0.1 - i * 0.04, cy, 0.0), "metal_dark", segs=24, rsegs=4, axis="X")
    trim.cyl(0.05, 0.03, (-0.275, cy, 0.0), "metal_dark", axis="X", segs=20)
    hard.bx((-0.06, cy - 0.06, -0.05), (-0.025, cy + 0.05, 0.06), "metal_dark")
    # rear handle with trigger, and the power cord
    trim.tube([(-0.2, cy - 0.06, 0.07), (-0.2, cy - 0.16, 0.14), (-0.2, cy - 0.28, 0.12), (-0.2, cy - 0.28, 0.03),
               (-0.2, cy - 0.08, 0.0)], 0.017, "polymer", segs=8)
    trim.bx((-0.21, cy - 0.24, 0.07), (-0.19, cy - 0.21, 0.1), "safety_orange")
    trim.tube([(-0.2, cy - 0.28, 0.03), (-0.18, cy - 0.36, -0.08), (-0.1, cy - 0.4, -0.3)], 0.007, "rubber", segs=6)
    # half guard over the back of the blade (x = 0 plane), a lower guard lip
    g = body.part(bevel=0.0)
    n = 10
    for i in range(n):
        a0 = math.pi * 0.5 + math.pi * i / n
        a1 = math.pi * 0.5 + math.pi * (i + 1) / n
        rr = r + 0.02
        p0 = (0.0, cy + rr * math.cos(a0), rr * math.sin(a0))
        p1 = (0.0, cy + rr * math.cos(a1), rr * math.sin(a1))
        g.rod((0.0, p0[1], p0[2]), (0.0, p1[1], p1[2]), 0.02, "metal_dark", segs=4, square=True)
    for sx in (-1, 1):
        g.profile_x([(cy, 0.0)] + [(cy + (r + 0.02) * math.cos(math.pi * 0.5 + math.pi * i / n),
                                    (r + 0.02) * math.sin(math.pi * 0.5 + math.pi * i / n)) for i in range(n + 1)],
                    sx * 0.018 - 0.002, sx * 0.018 + 0.002, "metal_dark")
    trim.bx((0.02, cy - 0.04, -0.03), (0.035, cy + 0.04, 0.03), "safety_orange")
    body.build()
    # BladeAxle: Blender local +Y (Godot local -Z, the Bit's spin axis) along the blade axle (+X)
    axle = k.empty("BladeAxle", (0.0, cy, 0.0), rotation=(0.0, 0.0, -math.pi / 2))
    bit = k.obj("Bit", parent=axle)
    bp = bit.part(bevel=0.0)
    bp.cyl(r - 0.012, 0.003, (0.0, 0.0, 0.0), "steel", axis="Y", segs=40)
    teeth = 40
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        c, s = math.cos(a), math.sin(a)
        rr = r - 0.008
        bp.rod((c * (r - 0.016), 0.0, s * (r - 0.016)), (c * rr - s * 0.012, 0.0, s * rr + c * 0.012), 0.0035,
               "steel_bare", segs=4, square=True)
    bp.cyl(0.035, 0.012, (0.0, 0.0, 0.0), "metal_dark", axis="Y", segs=16)
    bp.cyl(0.01, 0.016, (0.0, 0.0, 0.0), "chrome", axis="Y", segs=10)
    for i in range(4):
        a = math.pi / 4 + math.pi / 2 * i
        bp.cyl(0.012, 0.004, (math.cos(a) * 0.09, 0.0, math.sin(a) * 0.09), "metal_dark", axis="Y", segs=10)
    bit.build()


# ------------------------------------------------------------------------------------ pickups / rigs

def _ammo_pickup(k: Kit, p: dict) -> None:
    """Enemy-drop ammo: an olive polymer ammo can (0.24 x 0.13 x 0.11) with a latch, a folded handle and a
    yellow stencil band, a loose magazine lying in front of it; the pair is centred on the origin."""
    lx, ly, lz = 0.24, 0.13, 0.11
    oy = -0.03  # can centre: the magazine in front makes the footprint ~0.19 m deep, centred on y = 0
    o = k.obj("Body")
    h = o.part(bevel=0.006, segments=2)
    h.bx((-lx / 2 + 0.01, oy - ly / 2, 0.0), (lx / 2 - 0.01, oy + ly / 2, lz - 0.012), "polymer_olive")
    h.bx((-lx / 2 + 0.006, oy - ly / 2 - 0.004, lz - 0.014), (lx / 2 - 0.006, oy + ly / 2 + 0.004, lz), "polymer_olive")
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        t.bx((sx * 0.06 - 0.008, oy - ly / 2 + 0.01, lz), (sx * 0.06 + 0.008, oy + ly / 2 - 0.01, lz + 0.004),
             "polymer_olive")
    t.rod((-0.05, oy, lz + 0.01), (0.05, oy, lz + 0.01), 0.007, "polymer", segs=8)
    t.bx((-0.05, oy - 0.004, lz), (-0.044, oy + 0.004, lz + 0.012), "polymer")
    t.bx((0.044, oy - 0.004, lz), (0.05, oy + 0.004, lz + 0.012), "polymer")
    t.bx((lx / 2 - 0.012, oy - 0.025, lz - 0.05), (lx / 2 - 0.002, oy + 0.025, lz - 0.006), "steel_bare")
    t.bx((-lx / 2 + 0.01, oy - ly / 2 - 0.002, 0.04), (lx / 2 - 0.01, oy - ly / 2, 0.055), "metal_yellow")
    t.bx((-lx / 2 + 0.01, oy + ly / 2, 0.04), (lx / 2 - 0.01, oy + ly / 2 + 0.002, 0.055), "metal_yellow")
    # loose magazine lying on its side in front (+Y), cartridges showing
    my = oy + ly / 2 + 0.03
    t.rod((-0.08, my, 0.016), (0.07, my + 0.01, 0.016), 0.016, "polymer", segs=6, square=True)
    t.cbox((0.084, my + 0.01, 0.016), (0.014, 0.022, 0.018), "brass_case")
    o.build()


def _zipline_anchor(k: Kit, p: dict) -> None:
    """Bag-zipline anchor, wall-mounted (back at y = 0): a bolted steel plate, a stand-off arm, a yellow
    housing round a grooved sheave (axle along X), a short cable stub leaving +Y and slightly down, and the
    `Line` marker where the line leaves the sheave."""
    body = k.obj("Body")
    hard = body.part(bevel=0.006, segments=2)
    trim = body.part(bevel=0.0)
    hard.bx((-0.15, 0.0, -0.2), (0.15, 0.016, 0.2), "steel_galv")
    for sx in (-1, 1):
        for sz in (-1, 1):
            trim.cyl(0.016, 0.012, (sx * 0.11, 0.022, sz * 0.16), "steel", axis="Y", segs=6)
            trim.cyl(0.007, 0.024, (sx * 0.11, 0.028, sz * 0.16), "steel", axis="Y", segs=8)
    # stand-off arm with gussets
    hard.bx((-0.04, 0.016, -0.04), (0.04, 0.2, 0.04), "metal_dark")
    for sx in (-1, 1):
        trim.profile_x([(0.016, -0.04), (0.016, -0.16), (0.12, -0.04)], sx * 0.006 - 0.004, sx * 0.006 + 0.004, "metal_dark")
    # housing: two yellow cheek plates round the sheave, spacer bolts
    cy, cz = 0.27, 0.0
    for sx in (-1, 1):
        trim.profile_x([(cy - 0.09, cz - 0.07), (cy + 0.08, cz - 0.07), (cy + 0.1, cz + 0.02), (cy + 0.04, cz + 0.1),
                        (cy - 0.07, cz + 0.1), (cy - 0.09, cz + 0.05)], sx * 0.035 - 0.006, sx * 0.035 + 0.006,
                       "metal_yellow")
    hard.bx((-0.041, 0.19, -0.05), (0.041, cy - 0.06, 0.05), "metal_yellow")
    for y, z in ((cy - 0.06, cz + 0.07), (cy + 0.06, cz + 0.07), (cy + 0.07, cz - 0.05)):
        trim.cyl(0.008, 0.1, (0.0, y, z), "steel", axis="X", segs=8)
    # sheave with a groove (two flanges and a hub), axle bolt
    trim.cyl(0.055, 0.008, (-0.014, cy, cz), "steel", axis="X", segs=24)
    trim.cyl(0.055, 0.008, (0.014, cy, cz), "steel", axis="X", segs=24)
    trim.cyl(0.04, 0.022, (0.0, cy, cz), "steel", axis="X", segs=24)
    trim.cyl(0.014, 0.1, (0.0, cy, cz), "chrome", axis="X", segs=10)
    # cable over the sheave top and away (+Y, slightly down), a ferrule on the stub end, rubber stop
    top = cz + 0.042
    trim.tube([(0.0, cy - 0.04, top - 0.012), (0.0, cy, top), (0.0, cy + 0.06, top - 0.004),
               (0.0, cy + 0.45, top - 0.05)], 0.005, "steel", segs=6)
    trim.cyl(0.016, 0.03, (0.0, cy + 0.12, top - 0.012), "rubber", axis="Y", segs=10)
    trim.rod((0.0, cy + 0.42, top - 0.047), (0.0, cy + 0.47, top - 0.052), 0.008, "steel", segs=8)
    body.build()
    k.empty("Line", (0.0, cy, top))


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
