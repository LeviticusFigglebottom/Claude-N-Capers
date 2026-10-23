"""Smoke bomb (D-163, a throwable): the crew's own original canister smoke grenade, held in the right hand and thrown.
Visual scene only, no collision.

Original design: a squat 64 mm canister (0.13 m tall) in matte grey-green paint with a broad ivory band, a ribbed
rubber base cap, a perforated steel top plate with six vent holes ringing a domed fuse head, a long bent spoon lever
down the side and a steel pull ring on a split pin. Deliberately unlike a fragmentation grenade: no segmented body,
no olive drab, a can not an egg.

Nodes (Godot names; Blender +Z = Godot +Y = up the can, Blender +Y = Godot -Z = the side the spoon runs down):
* root origin = the grip centre in the palm (the hand-held item convention, as eqp_pocket_ecm).
* ``Body``: the can, band, base cap, top plate, fuse head and spoon.
* ``Pin``: the pull ring and split pin as their own mesh, so code can hide it once the pin is pulled.
* ``Vent``: a Marker on the top plate, +Y up: where the smoke effect starts.
"""

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "props"))

from _pb import Kit  # noqa: E402

ASSET_ID = "eqp_smoke_bomb"
TRI_BUDGET = 3000
PARAMS = {}

R = 0.032
Z0 = -0.055
Z1 = 0.075


def build(ctx) -> None:
    k = Kit(ctx)
    body = k.obj("Body")
    c = body.part(bevel=0.002)
    t = body.part(bevel=0.0)
    c.cyl(R, Z1 - Z0, (0.0, 0.0, (Z0 + Z1) / 2), "canister_grey", segs=24)                           # the can
    t.cyl(R + 0.0008, 0.032, (0.0, 0.0, 0.0), "paint_ivory", segs=24)                                  # the band
    for z in (-0.017, 0.017):
        t.cyl(R + 0.0012, 0.003, (0.0, 0.0, z), "metal_dark", segs=24)                                 # band edges
    c.cyl(R + 0.002, 0.016, (0.0, 0.0, Z0 + 0.006), "rubber", segs=24)                                 # base cap
    for i in range(12):                                                                                # its ribs
        a = math.tau * i / 12
        t.rod((math.cos(a) * (R + 0.002), math.sin(a) * (R + 0.002), Z0 - 0.001),
              (math.cos(a) * (R + 0.002), math.sin(a) * (R + 0.002), Z0 + 0.013), 0.0018, "rubber", segs=4)
    c.cyl(R - 0.001, 0.006, (0.0, 0.0, Z1 + 0.003), "metal_grey", segs=24)                            # top plate
    for i in range(6):                                                                                 # vent holes
        a = math.tau * (i + 0.5) / 6
        t.cyl(0.0042, 0.0012, (math.cos(a) * 0.021, math.sin(a) * 0.021, Z1 + 0.0062), "metal_dark", segs=8)
    t.lathe([(0.0, 0.0), (0.012, 0.0), (0.012, 0.010), (0.008, 0.017), (0.0, 0.019)], "metal_grey",
            centre=(0.0, 0.0, Z1 + 0.006), segs=16)                                                     # fuse head
    # the spoon: over the fuse head and down the +Y side
    sy = R + 0.004
    t.rod((0.0, -0.004, Z1 + 0.024), (0.0, sy - 0.004, Z1 + 0.022), 0.003, "metal_grey", segs=4, square=True)
    t.rod((0.0, sy - 0.004, Z1 + 0.022), (0.0, sy, Z1 + 0.008), 0.003, "metal_grey", segs=4, square=True)
    t.bx((-0.007, sy - 0.001, Z0 + 0.03), (0.007, sy + 0.002, Z1 + 0.010), "metal_grey")
    body.build()
    pin = k.obj("Pin")
    p = pin.part(bevel=0.0)
    p.rod((-0.016, 0.004, Z1 + 0.014), (0.010, 0.004, Z1 + 0.014), 0.0015, "metal_grey", segs=6)      # split pin
    p.torus(0.013, 0.0018, (-0.029, 0.004, Z1 + 0.014), "metal_grey", segs=20, rsegs=6, axis="Y")     # pull ring
    pin.build()
    k.empty("Vent", (0.0, 0.0, Z1 + 0.026))
