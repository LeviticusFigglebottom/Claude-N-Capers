"""Pocket ECM (D-161, the Hacker perk deck; PD2's pocket ECM jammer): the crew's own original hand-held jammer, used
from the throwable slot (held up and switched on, never placed). Visual scene only, no collision.

Original design: a rugged pocket unit (0.075 x 0.024 x 0.12 m) in black anodised aluminium with rubber corner
bumpers, two stubby rubber antennae on the top edge (one taller), a flip-guarded orange toggle, a three-segment status
light bar and a small mesh speaker grille on the face, knurled grip ribs down the sides and a steel belt clip on the
back. Related to the crew's placed ECM (same black anodising, rubber, orange switch guard) but a different object.

Nodes (Godot names; Blender +Z = Godot +Y = up the device, Blender +Y = Godot -Z = its face):
* root origin = the grip centre in the palm (the hand-held item convention: the right hand holds the origin, the item
  rises along +Y), so the light bar and the antennae stand above the fist.
* ``Body``: the case, bumpers, antennae, switch, grille, ribs, clip.
* ``Led``: the three light-bar segments (emissive green) as their own mesh, so code can hide / tint it while the
  jammer recharges.
* ``Top``: a Marker at the antenna base (top centre), +Y up: a hook for a jamming effect.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "props"))

from _pb import Kit  # noqa: E402

ASSET_ID = "eqp_pocket_ecm"
TRI_BUDGET = 3000
PARAMS = {}

#: the case (m): width (X), depth (Y, face at +Y), bottom / top (Z) relative to the grip centre
W = 0.075
D = 0.024
Z0 = -0.050
Z1 = 0.070


def build(ctx) -> None:
    k = Kit(ctx)
    hx, hy = W / 2, D / 2
    body = k.obj("Body")
    c = body.part(bevel=0.005, segments=2)
    t = body.part(bevel=0.0015)
    c.bx((-hx, -hy, Z0), (hx, hy, Z1), "alu_black")                                          # the case
    for sx in (-1, 1):                                                                       # corner bumpers
        for z in (Z0 + 0.012, Z1 - 0.012):
            x0, x1 = sorted((sx * (hx - 0.010), sx * (hx + 0.003)))
            c.bx((x0, -hy - 0.002, z - 0.013), (x1, hy + 0.002, z + 0.013), "rubber")
        for i in range(6):                                                                   # knurled grip ribs
            z = Z0 + 0.030 + i * 0.008
            x0, x1 = sorted((sx * hx, sx * (hx + 0.0018)))
            t.bx((x0, -hy + 0.003, z), (x1, hy - 0.003, z + 0.004), "rubber")
    # the face: a recessed panel, the light-bar window, the speaker grille and the guarded toggle
    t.bx((-hx + 0.006, hy, Z0 + 0.008), (hx - 0.006, hy + 0.0015, Z1 - 0.010), "polymer")
    t.bx((-0.024, hy + 0.0015, Z1 - 0.030), (0.024, hy + 0.003, Z1 - 0.018), "plastic_black")   # light-bar window
    for i in range(4):                                                                       # speaker grille slots
        z = Z0 + 0.016 + i * 0.006
        t.bx((-0.020, hy + 0.0015, z), (0.004, hy + 0.0028, z + 0.0028), "plastic_black")
    t.bx((0.010, hy + 0.0015, Z0 + 0.012), (0.030, hy + 0.012, Z0 + 0.016), "safety_orange")   # switch guard (U)
    for sx in (0.010, 0.026):
        t.bx((sx, hy + 0.0015, Z0 + 0.016), (sx + 0.004, hy + 0.012, Z0 + 0.040), "safety_orange")
    t.cyl(0.0035, 0.008, (0.020, hy + 0.006, Z0 + 0.028), "steel_bare", axis="Y", segs=8)       # the toggle stem
    t.rod((0.020, hy + 0.008, Z0 + 0.028), (0.020, hy + 0.016, Z0 + 0.036), 0.0022, "steel_bare", segs=6)
    # the top edge: two stubby rubber antennae on brass bases (the left one taller)
    for x, ln in ((-0.020, 0.050), (0.018, 0.034)):
        t.cyl(0.0055, 0.006, (x, 0.0, Z1 + 0.003), "brass", segs=10)
        t.cyl(0.0042, ln, (x, 0.0, Z1 + 0.006 + ln / 2), "rubber", segs=10)
        t.sphere(0.0042, (x, 0.0, Z1 + 0.006 + ln), "rubber", segs=10, rings=4)
    # the back: a steel belt clip
    t.bx((-0.010, -hy - 0.003, Z1 - 0.040), (0.010, -hy - 0.0015, Z1 - 0.010), "steel_bare")
    t.bx((-0.010, -hy - 0.0015, Z1 - 0.014), (0.010, -hy, Z1 - 0.008), "steel_bare")
    body.build()
    led = k.obj("Led")
    lp = led.part(bevel=0.0)
    for i in range(3):
        x = -0.020 + i * 0.0145
        lp.bx((x, hy + 0.0075, Z1 - 0.028), (x + 0.011, hy + 0.009, Z1 - 0.020), "emit_led_green")  # clear of the
        # window after the kit's z-fight pass (it can push the window face 4 mm out)
    led.build()
    k.empty("Top", (0.0, 0.0, Z1 + 0.006))
