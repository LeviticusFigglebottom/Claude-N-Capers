"""Rail gadgets shared by every conventional weapon with a ``SideRail`` (D-118): pistols, SMGs, rifles,
shotguns, LMGs, snipers. Built in the ``SideRail`` marker's frame:

* origin = the rail face (clamp contact), local +X = away from the rail (outward), +Y = forward (Godot -Z),
  +Z = across the rail face. On the long guns ``SideRail`` sits on the right-hand rail with an identity basis
  (outward = right); on the pistols it shares the dust-cover rail with ``Underbarrel`` and is turned +90 deg
  about the bore axis, so outward = down and the gadget hangs under the frame.

* ``mod_rail_laser``       GADGET -> ``SideRail`` (compact laser module; ``LaserOrigin`` at the emitter lens)
* ``mod_rail_flashlight``  GADGET -> ``SideRail`` (tactical light on an offset arm; ``LightOrigin`` at the lens)
* ``mod_rail_combo``       GADGET -> ``SideRail`` (laser + light unit; both markers)

The origin markers carry an identity basis, so their local -Z (Godot) is the beam / cone axis = weapon forward
(contracts/visual_slots.md). ENV P draws the beam, dot and light cone from them.
"""

import _common as c

TRI_BUDGET = 25000
VARIANTS = {
    "mod_rail_laser": {"part": "laser"},
    "mod_rail_flashlight": {"part": "flashlight"},
    "mod_rail_combo": {"part": "combo"},
}

CLAMP_X = 0.005      # clamp thickness off the rail face
CLAMP_HY = 0.014     # clamp half length along the rail
CLAMP_HZ = 0.0105    # clamp half width across the rail (picatinny ~21 mm)


def _clamp(mb, mat, x1: float = CLAMP_X) -> None:
    mb.box((0.0, -CLAMP_HY, -CLAMP_HZ), (x1, CLAMP_HY, CLAMP_HZ), mat=mat)
    mb.box((0.0, -0.004, CLAMP_HZ), (x1 - 0.001, 0.004, CLAMP_HZ + 0.003), mat=mat)     # cross-bolt nut


def _laser(ctx, mats: c.Mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    _clamp(mb, alu)
    mb.box((CLAMP_X, -0.016, -0.011), (0.024, 0.026, 0.011), mat=alu)                    # housing
    mb.cylinder(0.0045, 0.006, segments=20, centre=(0.0145, 0.029, 0.0), axis="Y", mat=alu)  # emitter barrel
    body = c.finish(mb, "LaserModule", bevel=0.0010, segments=2)
    sw = ctx.builder()
    rub = sw.material(mats.rubber())
    sw.box((0.024, -0.012, -0.005), (0.0265, 0.000, 0.005), mat=rub)                     # pressure switch
    c.finish(sw, "LaserModuleSwitch", bevel=0.0006, parent=body)
    ln = ctx.builder()
    ln.cylinder(0.0030, 0.001, segments=16, centre=(0.0145, 0.0325, 0.0), axis="Y", mat=ln.material(mats.reticle()))
    c.finish(ln, "LaserModuleLens", parent=body)
    ctx.marker("LaserOrigin", (0.0145, 0.0330, 0.0), parent=body)
    return body


def _flashlight(ctx, mats: c.Mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    _clamp(mb, alu, x1=0.006)
    mb.box((0.006, -0.012, -0.008), (0.013, 0.012, 0.008), mat=alu)                      # offset arm
    axis_x = 0.0240
    mb.cylinder(0.0115, 0.062, segments=24, centre=(axis_x, 0.009, 0.0), axis="Y", mat=alu)   # body tube
    mb.cylinder(0.0140, 0.016, segments=24, centre=(axis_x, 0.048, 0.0), axis="Y", mat=alu)   # head / bezel
    body = c.finish(mb, "Flashlight", bevel=0.0008, segments=2)
    tc = ctx.builder()
    tc.cylinder(0.0105, 0.008, segments=20, centre=(axis_x, -0.026, 0.0), axis="Y", mat=tc.material(mats.rubber()))
    c.finish(tc, "FlashlightTailCap", bevel=0.0010, parent=body)
    ln = ctx.builder()
    ln.cylinder(0.0118, 0.001, segments=24, centre=(axis_x, 0.0565, 0.0), axis="Y", mat=ln.material(mats.lens()))
    c.finish(ln, "FlashlightLens", parent=body)
    ctx.marker("LightOrigin", (axis_x, 0.0570, 0.0), parent=body)
    return body


def _combo(ctx, mats: c.Mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    _clamp(mb, alu)
    mb.box((CLAMP_X, -0.018, -0.016), (0.030, 0.034, 0.016), mat=alu)                    # housing
    light = (0.0185, 0.005)
    laser = (0.0175, -0.0105)
    mb.cylinder(0.0105, 0.004, segments=24, centre=(light[0], 0.036, light[1]), axis="Y", mat=alu)  # light bezel
    mb.cylinder(0.0038, 0.004, segments=16, centre=(laser[0], 0.036, laser[1]), axis="Y", mat=alu)  # laser barrel
    body = c.finish(mb, "ComboModule", bevel=0.0010, segments=2)
    sw = ctx.builder()
    rub = sw.material(mats.rubber())
    sw.box((0.030, -0.014, -0.006), (0.0325, -0.002, 0.006), mat=rub)                    # mode switch
    c.finish(sw, "ComboModuleSwitch", bevel=0.0006, parent=body)
    ll = ctx.builder()
    ll.cylinder(0.0088, 0.001, segments=24, centre=(light[0], 0.0385, light[1]), axis="Y", mat=ll.material(mats.lens()))
    c.finish(ll, "ComboModuleLightLens", parent=body)
    lz = ctx.builder()
    lz.cylinder(0.0025, 0.001, segments=16, centre=(laser[0], 0.0385, laser[1]), axis="Y",
                mat=lz.material(mats.reticle()))
    c.finish(lz, "ComboModuleLaserLens", parent=body)
    ctx.marker("LightOrigin", (light[0], 0.0390, light[1]), parent=body)
    ctx.marker("LaserOrigin", (laser[0], 0.0390, laser[1]), parent=body)
    return body


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "laser":
        _laser(ctx, mats)
    elif part == "flashlight":
        _flashlight(ctx, mats)
    elif part == "combo":
        _combo(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
