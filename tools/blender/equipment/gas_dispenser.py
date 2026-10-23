"""Gas dispenser (D-163, a throwable slot item): the crew's own original hand-held dispenser, an inhaler-style medical
device that is held up and pressed, never a weapon. Visual scene only, no collision.

Original design: a rounded off-white body (an L: the upright housing and a short mouthpiece at its foot) with a teal
dose canister seated in the top, a pale-teal press cap, a dose-counter window on the face, a green cross printed on
the side, a rubber grip pad on the back and a small lanyard loop at the base.

Nodes (Godot names; Blender +Z = Godot +Y = up the housing, Blender +Y = Godot -Z = the mouthpiece side):
* root origin = the grip centre in the palm (the hand-held item convention, as eqp_pocket_ecm).
* ``Body``: the housing, mouthpiece, grip pad, counter window, cross and loop.
* ``Canister``: the dose canister and its press cap as their own mesh, so code can push it down on use.
* ``Nozzle``: a Marker at the mouthpiece opening, +Y up: where the gas effect starts.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "props"))

from _pb import Kit  # noqa: E402

ASSET_ID = "eqp_gas_dispenser"
TRI_BUDGET = 3000
PARAMS = {}

W = 0.044
D = 0.032
Z0 = -0.050
Z1 = 0.055


def build(ctx) -> None:
    k = Kit(ctx)
    hx, hy = W / 2, D / 2
    body = k.obj("Body")
    c = body.part(bevel=0.010, segments=3)
    t = body.part(bevel=0.0015)
    c.bx((-hx, -hy, Z0), (hx, hy, Z1), "ceramic")                                                    # housing
    c.bx((-0.017, hy - 0.004, Z0), (0.017, hy + 0.034, Z0 + 0.030), "ceramic")                      # mouthpiece
    t.bx((-0.012, hy + 0.034, Z0 + 0.006), (0.012, hy + 0.036, Z0 + 0.024), "metal_dark")          # its opening
    t.bx((-hx + 0.006, -hy - 0.002, Z0 + 0.020), (hx - 0.006, -hy, Z1 - 0.012), "rubber")           # grip pad
    t.bx((-0.009, hy, Z1 - 0.030), (0.009, hy + 0.0015, Z1 - 0.016), "glass_tinted")                 # counter
    t.bx((-0.005, hy + 0.0015, Z1 - 0.026), (0.005, hy + 0.002, Z1 - 0.020), "paper")
    for sx in (-1, 1):                                                                               # the cross
        x = sx * (hx + 0.0008)
        x0, x1 = sorted((x, sx * hx))
        t.bx((x0, -0.004, -0.014), (x1, 0.004, 0.010), "serum_green")
        t.bx((x0, -0.012, -0.006), (x1, 0.012, 0.002), "serum_green")
    t.torus(0.008, 0.0018, (0.0, -hy + 0.004, Z0 - 0.006), "polymer", segs=12, rsegs=5, axis="X")    # lanyard loop
    body.build()
    can = k.obj("Canister")
    p = can.part(bevel=0.0)
    p.cyl(0.0125, 0.040, (0.0, -0.002, Z1 + 0.012), "ice_blue", segs=18)
    p.lathe([(0.0, 0.0), (0.0135, 0.0), (0.0135, 0.008), (0.010, 0.012), (0.0, 0.013)], "glass_teal",
            centre=(0.0, -0.002, Z1 + 0.030), segs=18)                                              # press cap
    can.build()
    k.empty("Nozzle", (0.0, hy + 0.036, Z0 + 0.015))
