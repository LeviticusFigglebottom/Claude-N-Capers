"""GSR window visuals for the `window` prefab (visual_slots.md: `Frame`, `Glass`, optional `Sash`).

Origin = bottom-centre of the opening (the sill), on the wall centreline; exterior wall 0.4 m
(the outside is Blender -Y = Godot +Z, the room side +Y = Godot -Z). Bronze-black aluminium frame
set toward the outside, interior window board, stone exterior sill. `Sash` (Node3D at the sill)
holds `Glass`; the openable variant has a lower sash (Glass) and a fixed upper pane in the Frame.
Opening sizes match the greybox wall kit (window 1.0 x 1.2, wide 3.0 x 1.2, shop 3.0 x 2.4) plus
high 1.0 x 0.6 windows (barred: workshop; frosted: WC). No collision (the prefab owns GlassBody).
Door-height 1.2 x 2.1 walk-through windows (PO-5, the Glasshouse fire-escape door-window; the prefab's
`walkable`): no bottom rail and no sills, a flush threshold plate across the wall instead, so nothing
is left across the opening once the sash is up or the glass is broken. `door` is fixed glazing;
`door_sash` is one full-height sash (`Sash` at the sill, unscaled); the map sets the window prefab's
`sash_travel_m` so the sash slides into the wall above the head (pocket sash), clearing the full opening.
"""

from _pb import Kit

TRI_BUDGET = 4000
VARIANTS = {
    "prop_window_w100_h120": {"w": 1.0, "h": 1.2, "style": "plain", "cat": {"prefab": "window", "kind": "window"}},
    "prop_window_w300_h120": {"w": 3.0, "h": 1.2, "style": "plain", "cat": {"prefab": "window", "kind": "window"}},
    "prop_window_shop_w300_h240": {"w": 3.0, "h": 2.4, "style": "shop", "cat": {"prefab": "window", "kind": "window"}},
    "prop_window_w100_h120_sash": {"w": 1.0, "h": 1.2, "style": "sash", "cat": {"prefab": "window", "kind": "window"}},
    "prop_window_w100_h60_barred": {"w": 1.0, "h": 0.6, "style": "barred", "cat": {"prefab": "window", "kind": "window"}},
    "prop_window_w100_h60_frosted": {"w": 1.0, "h": 0.6, "style": "frosted", "cat": {"prefab": "window", "kind": "window"}},
    "prop_window_w120_h210": {"w": 1.2, "h": 2.1, "style": "door", "cat": {"prefab": "window", "kind": "window"}},
    "prop_window_w120_h210_sash": {"w": 1.2, "h": 2.1, "style": "door_sash", "cat": {"prefab": "window", "kind": "window"}},
}

WALL_T = 0.4
FW = 0.055          # frame face width
FD = 0.08           # frame depth
Y0 = -0.13          # frame outside face (towards Blender -Y)


def build(ctx) -> None:
    k = Kit(ctx)
    p = ctx.params
    w, h, style = p["w"], p["h"], p["style"]
    hw = w / 2
    if style in ("door", "door_sash"):
        _build_door_window(k, w, h, style)
        return
    fr = k.obj("Frame")
    alu = fr.part(bevel=0.002)
    board = fr.part(bevel=0.003, segments=2)
    y1 = Y0 + FD
    # outer frame
    alu.bx((-hw, Y0, 0.0), (-hw + FW, y1, h), "metal_dark")
    alu.bx((hw - FW, Y0, 0.0), (hw, y1, h), "metal_dark")
    alu.bx((-hw, Y0, 0.0), (hw, y1, FW), "metal_dark")
    alu.bx((-hw, Y0, h - FW), (hw, y1, h), "metal_dark")
    panes = 3 if w > 2.0 else 1
    pw = (w - FW * 2) / panes
    for i in range(1, panes):
        x = -hw + FW + i * pw
        alu.bx((x - FW * 0.4, Y0, FW), (x + FW * 0.4, y1, h - FW), "metal_dark")
    if style == "shop":
        # brass cap line on the room side of the frame and a transom bar
        for x0, x1, z0, z1 in ((-hw, hw, h - FW - 0.006, h - FW), (-hw, hw, FW, FW + 0.006)):
            alu.bx((x0 + FW, y1, z0), (x1 - FW, y1 + 0.004, z1), "brass")
        alu.bx((-hw + FW, Y0, h - 0.42), (hw - FW, y1, h - 0.38), "metal_dark")
    # interior window board (sill) and exterior stone sill
    board.bx((-hw - 0.04, y1, 0.0), (hw + 0.04, WALL_T / 2 + 0.03, 0.028), "marble" if style != "shop" else "walnut")
    board.bx((-hw - 0.03, -WALL_T / 2 - 0.05, -0.0), (hw + 0.03, Y0, 0.035), "concrete_light")
    if style == "barred":
        for i in range(7):
            x = -hw + FW + (w - 2 * FW) * (i + 0.5) / 7
            alu.rod((x, Y0 - 0.03, FW), (x, Y0 - 0.03, h - FW), 0.008, "metal_dark", segs=8)
        for z in (0.12, h - 0.12):
            alu.bx((-hw + FW, Y0 - 0.04, z - 0.015), (hw - FW, Y0 - 0.02, z + 0.015), "metal_dark")
    glass_key = "glass_frosted" if style == "frosted" else "glass"
    gy = Y0 + FD * 0.5
    sash = k.empty("Sash", (0.0, 0.0, 0.0))
    if style == "sash":
        # upper fixed pane in the frame, lower sliding sash with its own frame
        up = fr.part(bevel=0.0)
        zm = h / 2
        alu.bx((-hw + FW, Y0, zm - 0.02), (hw - FW, Y0 + FD * 0.45, zm + 0.02), "metal_dark")
        up.bx((-hw + FW - 0.005, Y0 + FD * 0.22 - 0.003, zm + 0.015), (hw - FW + 0.005, Y0 + FD * 0.22 + 0.003, h - FW + 0.005), "glass")
        sf = k.obj("SashFrame", parent=sash)
        sp = sf.part(bevel=0.002)
        ys0, ys1 = Y0 + FD * 0.5, Y0 + FD * 0.95
        sp.bx((-hw + FW, ys0, FW), (-hw + FW + 0.04, ys1, zm + 0.02), "metal_dark")
        sp.bx((hw - FW - 0.04, ys0, FW), (hw - FW, ys1, zm + 0.02), "metal_dark")
        sp.bx((-hw + FW, ys0, FW), (hw - FW, ys1, FW + 0.05), "metal_dark")
        sp.bx((-hw + FW, ys0, zm - 0.02), (hw - FW, ys1, zm + 0.02), "metal_dark")
        sp.bx((-0.08, ys1, FW + 0.02), (0.08, ys1 + 0.02, FW + 0.035), "steel")
        sf.build()
        gl = k.obj("Glass", parent=sash)
        gp = gl.part(bevel=0.0)
        gp.bx((-hw + FW + 0.03, (ys0 + ys1) / 2 - 0.003, FW + 0.04), (hw - FW - 0.03, (ys0 + ys1) / 2 + 0.003, zm - 0.01), "glass")
        gl.build()
    else:
        gl = k.obj("Glass", parent=sash)
        gp = gl.part(bevel=0.0)
        for i in range(panes):
            x0 = -hw + FW + i * pw + (0.0 if i == 0 else FW * 0.4) - 0.005
            x1 = -hw + FW + (i + 1) * pw - (0.0 if i == panes - 1 else FW * 0.4) + 0.005
            gp.bx((x0, gy - 0.004, FW - 0.005), (x1, gy + 0.004, h - FW + 0.005), glass_key)
        gl.build()
    fr.build()


def _build_door_window(k: Kit, w: float, h: float, style: str) -> None:
    """Walk-through window: jambs + head, a flush threshold plate, glass down to the threshold."""
    hw = w / 2
    fr = k.obj("Frame")
    alu = fr.part(bevel=0.002)
    y1 = Y0 + FD
    alu.bx((-hw, Y0, 0.0), (-hw + FW, y1, h), "metal_dark")
    alu.bx((hw - FW, Y0, 0.0), (hw, y1, h), "metal_dark")
    alu.bx((-hw, Y0, h - FW), (hw, y1, h), "metal_dark")
    # threshold plate over the wall top (the walking surface stays the wall at the sill line)
    alu.bx((-hw + FW, -WALL_T / 2, 0.0), (hw - FW, WALL_T / 2, 0.008), "steel")
    sash = k.empty("Sash", (0.0, 0.0, 0.0))
    if style == "door_sash":
        sf = k.obj("SashFrame", parent=sash)
        sp = sf.part(bevel=0.002)
        ys0, ys1 = Y0 + FD * 0.5, Y0 + FD * 0.95
        z0, z1 = 0.008, h - FW
        sp.bx((-hw + FW, ys0, z0), (-hw + FW + 0.05, ys1, z1), "metal_dark")
        sp.bx((hw - FW - 0.05, ys0, z0), (hw - FW, ys1, z1), "metal_dark")
        sp.bx((-hw + FW, ys0, z0), (hw - FW, ys1, z0 + 0.1), "metal_dark")
        sp.bx((-hw + FW, ys0, z1 - 0.05), (hw - FW, ys1, z1), "metal_dark")
        # lift handles on both faces of the bottom rail
        for y_a, y_b in ((ys1, ys1 + 0.02), (ys0 - 0.02, ys0)):
            sp.bx((-0.1, y_a, z0 + 0.03), (0.1, y_b, z0 + 0.06), "steel")
        sf.build()
        gl = k.obj("Glass", parent=sash)
        gp = gl.part(bevel=0.0)
        gc = (ys0 + ys1) / 2
        gp.bx((-hw + FW + 0.04, gc - 0.003, z0 + 0.09), (hw - FW - 0.04, gc + 0.003, z1 - 0.04), "glass")
        gl.build()
    else:
        gl = k.obj("Glass", parent=sash)
        gp = gl.part(bevel=0.0)
        gy = Y0 + FD * 0.5
        gp.bx((-hw + FW - 0.005, gy - 0.004, 0.014), (hw - FW + 0.005, gy + 0.004, h - FW + 0.005), "glass")
        gl.build()
    fr.build()
