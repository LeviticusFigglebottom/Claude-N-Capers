"""Leech ampule (D-164, the Leech perk deck's throwable slot): the crew's own original auto-injector, held in the
right hand and pressed to the thigh, never a weapon. Visual scene only, no collision.

Original design: a 0.15 m pen-shaped injector, an off-white barrel with a ribbed grey grip, a clear window over
the green serum, a safety-orange cap at the back, a green-ringed needle shield at the business end, a pocket clip
and a printed green band.

Nodes (Godot names; Blender +Z = Godot +Y = toward the needle end):
* root origin = the grip centre in the palm (the hand-held item convention, as eqp_pocket_ecm).
* ``Body``: the barrel, grip ribs, cap, shield, clip and band.
* ``Serum``: the serum in its window as its own mesh, so code can tint or empty it.
* ``Tip``: a Marker at the needle end, +Y along the injector.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "props"))

from _pb import Kit  # noqa: E402

ASSET_ID = "eqp_leech_ampule"
TRI_BUDGET = 2500
PARAMS = {}

R = 0.0105
Z0 = -0.060
Z1 = 0.090


def build(ctx) -> None:
    k = Kit(ctx)
    body = k.obj("Body")
    c = body.part(bevel=0.002)
    t = body.part(bevel=0.0)
    c.cyl(R, Z1 - Z0 - 0.03, (0.0, 0.0, (Z0 + Z1 - 0.03) / 2), "ceramic", segs=18)                 # barrel
    for i in range(7):                                                                               # grip ribs
        t.cyl(R + 0.0012, 0.004, (0.0, 0.0, -0.030 + i * 0.008), "plastic_grey", segs=18)
    c.lathe([(0.0, 0.0), (R + 0.0015, 0.0), (R + 0.0015, 0.022), (R - 0.003, 0.030), (0.0, 0.031)],
            "safety_orange", centre=(0.0, 0.0, Z0 - 0.022), segs=18)                                  # back cap
    t.cyl(R + 0.0006, 0.009, (0.0, 0.0, 0.040), "serum_green", segs=18)                              # band
    t.cyl(R - 0.0005, 0.030, (0.0, 0.0, Z1 - 0.015), "glass_frosted", segs=18)                        # shield
    t.cyl(R + 0.0008, 0.004, (0.0, 0.0, Z1 - 0.032), "serum_green", segs=18)                          # its ring
    t.cyl(R - 0.004, 0.004, (0.0, 0.0, Z1 + 0.001), "plastic_grey", segs=12)                          # tip face
    t.bx((-0.0025, R - 0.0005, Z0 - 0.010), (0.0025, R + 0.0025, Z0 + 0.035), "steel_bare")           # clip
    t.bx((-0.0025, R - 0.0005, Z0 - 0.012), (0.0025, R + 0.0003, Z0 - 0.008), "steel_bare")
    t.bx((-0.006, -R - 0.0006, 0.050), (0.006, -R + 0.002, 0.066), "glass_tinted")                    # window frame
    body.build()
    serum = k.obj("Serum")
    s = serum.part(bevel=0.0)
    s.bx((-0.0045, -R - 0.0012, 0.052), (0.0045, -R + 0.001, 0.064), "serum_green")
    serum.build()
    k.empty("Tip", (0.0, 0.0, Z1 + 0.003))
