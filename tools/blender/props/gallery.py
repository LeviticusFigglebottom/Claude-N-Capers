"""Gallery Night props (GN-C2; docs/design/heists/gallery_night.md, palette bone / halberd green / gilt).

Blender +Y = Godot -Z (the front), +Z up. Door visuals follow doors.py (origin = bottom-centre of the opening on
the wall line, `Frame` + `Frame/Collision`, `Leaf` hinge pivot extending +X, `Handle`).

* Lockdown shutters / roller door (`door` prefab, BARRED by the mission): the curtain never swings. `Leaf` is the
  hinge pivot A rotates; its children `Curtain` (slats, origin at the curtain top) and `BottomBar` are driven by
  `world/props/shutter_leaf.gd` (wrapper `leaf_script`): it cancels the leaf's yaw and turns the open fraction into
  a roll-up (the curtain shortens into the hood, the bar rises). Closed (rotation 0) the curtain hangs in place, so
  the validators see a closed shutter.
  - `..._arch_w300_h360` (Calloway arch, 3.0 x 3.6, t20) and `prop_door_roller_steel_w360_h450` (LD, 3.6 x 4.5,
    t40): in the reveal; guides 6 cm into the opening, the coil hood fills the head. Frame/Collision = the hood.
  - `..._face_w120` / `_w200` (TR door, LD art door): on the wall's front face over a door that keeps its own frame
    (meta kind `shutter`: validate_level measures them in face mode); guides beside the reveal, the hood above it.
* `prop_door_grate_areaway_w200`: the court areaway grate as a `door` prefab laid flat (the generator tilts it:
  local +Y along the ground, front -Z up); a 2.0 x 2.0 m hinged bar grating in a steel angle curb, a lift handle and
  a padlock hasp at the latch edge. Frame/Collision = the curb lining in the hole (flush).
* `prop_ladder_caged_h900`: the 9 m fire-escape ladder with the counterweighted 2.4 m drop section (down), cage hoops
  from 2.7 m, grab rails 1.1 m over the top; wall 0.2 m behind the stiles. `prop_ladder_wall_h420_flush`: the areaway
  ladder (stiles stop under the grate).
* Canvases (`loot_spawn` visuals): gilt-framed paintings (texgen images, tools/texgen/paintings.py), wall-mounted
  (back-centre pivot, the canvas centred on it); the widow on the conservation easel, a canvas in an opened travel
  crate (floor).
* `prop_art_rack_screen`: a 3 m pull-out mesh painting screen (static dressing with convex collision).
* `prop_safe_wall_small` (safe SMALL, wall pivot at the bottom of the back), `prop_deposit_box_consign` (wall).
"""

import math

from _pb import Kit
from lib import geo

TRI_BUDGET = 8000
_DOOR = {"prefab": "door", "surface": "metal"}
_PAINT_IDS = ("lantern", "orchard", "widow", "saint", "study1", "study2", "study3", "study4", "study5", "study6",
              "study7", "study8")
# canvas size (w, h) per picture (m): the list works large, the studies small; frames add 2 x moulding
_CANVAS = {"lantern": (1.3, 1.7), "orchard": (1.5, 1.0), "widow": (0.95, 1.25), "saint": (0.85, 1.3),
           "study1": (0.6, 0.48), "study2": (0.45, 0.6), "study3": (0.7, 0.5), "study4": (0.5, 0.65),
           "study5": (0.55, 0.7), "study6": (0.75, 0.5), "study7": (0.55, 0.7), "study8": (0.8, 0.5)}
VARIANTS = {
    "prop_door_shutter_steel_arch_w300_h360": {"fn": "shutter_reveal", "w": 3.0, "h": 3.6, "t": 0.2, "hood": 0.36,
                                               "slat": "steel_galv", "cat": {**_DOOR, "kind": "industrial_door",
                                                                             "leaf_script": "shutter"}},
    "prop_door_roller_steel_w360_h450": {"fn": "shutter_reveal", "w": 3.6, "h": 4.5, "t": 0.4, "hood": 0.42,
                                         "slat": "metal_grey", "handles": True,
                                         "cat": {**_DOOR, "kind": "industrial_door", "leaf_script": "shutter"}},
    "prop_door_shutter_steel_face_w120": {"fn": "shutter_face", "w": 1.2, "h": 2.2, "t": 0.2,
                                          "cat": {**_DOOR, "kind": "shutter", "leaf_script": "shutter"}},
    "prop_door_shutter_steel_face_w200": {"fn": "shutter_face", "w": 2.0, "h": 2.2, "t": 0.2,
                                          "cat": {**_DOOR, "kind": "shutter", "leaf_script": "shutter"}},
    "prop_door_grate_steel_areaway_w200": {"fn": "grate", "w": 2.0, "l": 2.0, "t": 0.3,
                                           "cat": {**_DOOR, "kind": "hatch"}},
    "prop_ladder_caged_h900": {"fn": "ladder_caged", "h": 9.0, "drop": 2.4,
                               "cat": {"prefab": "ladder", "kind": "ladder", "surface": "metal"}},
    "prop_ladder_wall_h420_flush": {"fn": "ladder_flush", "h": 4.2,
                                    "cat": {"prefab": "ladder", "kind": "ladder", "surface": "metal"}},
    **{f"prop_canvas_{pid}": {"fn": "canvas_hung", "pid": pid,
                              "cat": {"prefab": "loot_spawn", "kind": "painting", "mount": "wall", "surface": "wood"}}
       for pid in _PAINT_IDS},
    "prop_canvas_widow_easel": {"fn": "canvas_easel", "pid": "widow",
                                "cat": {"prefab": "loot_spawn", "kind": "painting", "surface": "wood"}},
    "prop_canvas_orchard_crate": {"fn": "canvas_crate", "pid": "orchard",
                                  "cat": {"prefab": "loot_spawn", "kind": "painting", "surface": "wood"}},
    "prop_canvas_study3_crate": {"fn": "canvas_crate", "pid": "study3",
                                 "cat": {"prefab": "loot_spawn", "kind": "painting", "surface": "wood"}},
    "prop_art_rack_screen": {"fn": "rack", "cat": {"kind": "art_rack", "group": "gallery", "place": "none",
                                                   "surface": "metal", "support": True}},
    "prop_safe_wall_small": {"fn": "safe_wall", "cat": {"prefab": "safe", "kind": "safe", "mount": "wall",
                                                        "surface": "metal"}},
    "prop_deposit_box_consign": {"fn": "deposit_box", "cat": {"prefab": "deposit_box", "kind": "deposit_box",
                                                              "mount": "wall", "surface": "metal"}},
}


# --------------------------------------------------------------------------------- shutters

def _curtain(k: Kit, leaf, width: float, top: float, bar_h: float, slat_key: str, depth: float = 0.008) -> None:
    """Slatted curtain under `leaf` from leaf-local x 0..width: `Curtain` (origin at the top, slats hanging down
    to the bar) and `BottomBar` (origin at the floor line)."""
    cur = k.obj("Curtain", parent=leaf, location=(0.0, 0.0, top))
    sp = cur.part(bevel=0.0)
    rib = cur.part(bevel=0.0)
    pitch = 0.08
    span = top - bar_h
    n = max(1, int(math.ceil(span / pitch)))
    step = span / n
    for i in range(n):
        z1 = -i * step
        z0 = z1 - step - 0.004   # overlap: no see-through between slats
        sp.bx((0.0, -depth / 2, z0), (width, depth / 2, z1), slat_key)
        zm = (z0 + z1) / 2
        rib.bx((0.0, depth / 2, zm - 0.008), (width, depth / 2 + 0.006, zm + 0.008), slat_key)
        rib.bx((0.0, -depth / 2 - 0.006, zm - 0.008), (width, -depth / 2, zm + 0.008), slat_key)
    cur.build()
    bar = k.obj("BottomBar", parent=leaf)
    bp = bar.part(bevel=0.004)
    bp.bx((0.0, -0.022, 0.012), (width, 0.022, bar_h + 0.004), "steel")
    rub = bar.part(bevel=0.0)
    rub.bx((0.0, -0.014, 0.004), (width, 0.014, 0.012), "rubber")
    bar.build()


def _shutter_reveal(k: Kit, p: dict) -> None:
    """In-reveal lockdown shutter / roller door: guides on both jambs, a coil hood filling the head."""
    w, h, t, hood = p["w"], p["h"], p["t"], p["hood"]
    hw = w / 2
    gw = 0.06
    gd = min(0.16, t - 0.04)
    fr = k.obj("Frame")
    g = fr.part(bevel=0.003)
    trim = fr.part(bevel=0.0015)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw - gw)))
        g.bx((x0, -gd / 2, 0.0), (x1, gd / 2, h - hood), "metal_dark")
        # channel lips either side of the curtain slot, 4 mm proud of the guide's inner face
        xi = sx * (hw - gw)
        xa, xb = sorted((xi, xi - sx * 0.004))
        for sy in (-1, 1):
            y0, y1 = sorted((sy * 0.012, sy * gd / 2))
            trim.bx((xa, y0, 0.0), (xb, y1, h - hood), "steel")
    yh = t / 2 - 0.008
    g.bx((-hw, -yh, h - hood), (hw, yh, h), "metal_dark")
    for sy in (-1, 1):   # hood cover plates with an inspection panel outline and bolt heads
        y0, y1 = sorted((sy * yh, sy * (yh + 0.004)))
        trim.bx((-hw + 0.06, y0, h - hood + 0.05), (hw - 0.06, y1, h - 0.05), "steel_galv")
        for x in (-hw + 0.12, 0.0, hw - 0.12):
            trim.cyl(0.012, 0.006, (x, sy * (yh + 0.006), h - hood / 2), "steel", axis="Y", segs=8)
    obj = fr.build()
    mb = geo.MeshBuilder()
    mb.box((-hw, -yh, h - hood), (hw, yh, h))
    geo.collision_from_builder(mb, "convex", parent=obj)
    leaf = k.empty("Leaf", (-hw, 0.0, 0.0))
    _curtain(k, leaf, w, h - hood + 0.05, 0.07, p["slat"])
    if p.get("handles"):
        # pull handles and a floor lock on the bottom bar, both faces (the roller is BARRED: dressing)
        hb = k.obj("BarFittings", parent=leaf)
        hp = hb.part(bevel=0.0)
        for x in (0.6, w - 0.6):
            for sy in (-1, 1):
                hp.rod((x - 0.1, sy * 0.05, 0.05), (x + 0.1, sy * 0.05, 0.05), 0.01, "steel", segs=8)
                y0, y1 = sorted((sy * 0.022, sy * 0.05))
                hp.bx((x - 0.11, y0, 0.04), (x - 0.09, y1, 0.06), "steel")
                hp.bx((x + 0.09, y0, 0.04), (x + 0.11, y1, 0.06), "steel")
        hb.build()
    k.empty("Handle", (-hw + 0.03, -gd / 2 - 0.02, 1.1))


def _shutter_face(k: Kit, p: dict) -> None:
    """Face-mounted lockdown shutter over a door opening: guides on the front wall face beside the reveal, the coil
    hood above it, the curtain 7 cm in front of the wall (clear of the door's own frame and levers)."""
    w, h, t = p["w"], p["h"], p["t"]
    yf = t / 2
    yc = yf + 0.07
    half = w / 2 + 0.05     # curtain half width (runs 4.5 cm into each guide)
    fr = k.obj("Frame")
    g = fr.part(bevel=0.003)
    trim = fr.part(bevel=0.0015)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 + 0.005), sx * (w / 2 + 0.095)))
        g.bx((x0, yf, 0.0), (x1, yf + 0.12, h + 0.03), "metal_dark")
        xa, xb = sorted((sx * (w / 2 + 0.03), sx * (w / 2 + 0.07)))
        for z in (0.3, 1.2, 2.0):   # wall fixings
            trim.bx((xa, yf + 0.12, z - 0.03), (xb, yf + 0.124, z + 0.03), "steel")
    hx = w / 2 + 0.13
    g.bx((-hx, yf, h + 0.03), (hx, yf + 0.26, h + 0.40), "metal_dark")
    trim.bx((-hx + 0.05, yf + 0.26, h + 0.08), (hx - 0.05, yf + 0.264, h + 0.35), "steel_galv")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hx, sx * (hx + 0.006)))
        trim.bx((x0, yf, h + 0.03), (x1, yf + 0.26, h + 0.40), "steel")
    # a halberd-green warning band on the hood (the gallery's livery) and the motor box at one end
    trim.bx((-hx + 0.05, yf + 0.264, h + 0.30), (hx - 0.05, yf + 0.268, h + 0.33), "paint_halberd")
    obj = fr.build()
    mb = geo.MeshBuilder()
    mb.box((-hx, yf, h + 0.03), (hx, yf + 0.26, h + 0.40))
    geo.collision_from_builder(mb, "convex", parent=obj)
    leaf = k.empty("Leaf", (-half, yc, 0.0))
    _curtain(k, leaf, 2 * half, h + 0.12, 0.065, "steel_galv")
    k.empty("Handle", (0.0, yf + 0.27, h + 0.2))


# ------------------------------------------------------------------------------------ grate

def _grate(k: Kit, p: dict) -> None:
    """Hinged areaway grate in a steel angle curb. Local frame as a door: X across (hinge at -X), Blender Z = the
    leaf's length along the ground, Blender +Y = up (front). The curb lines the hole (y from the top face down 8 cm)
    with a 5 cm flange on the grade; the grate (4 cm bearing bars at 40 mm, cross rods every 100 mm) sits flush."""
    w, ln, t = p["w"], p["l"], p["t"]
    hw = w / 2
    top = t / 2
    lin = 0.04
    fr = k.obj("Frame")
    c = fr.part(bevel=0.002)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw - lin)))
        c.bx((x0, top - 0.08, 0.0), (x1, top, ln), "metal_dark")
        f0, f1 = sorted((sx * hw, sx * (hw + 0.05)))
        c.bx((f0, top, -0.05), (f1, top + 0.006, ln + 0.05), "metal_dark")
    c.bx((-hw + lin, top - 0.08, 0.0), (hw - lin, top, lin), "metal_dark")
    c.bx((-hw + lin, top - 0.08, ln - lin), (hw - lin, top, ln), "metal_dark")
    c.bx((-hw, top, -0.05), (hw, top + 0.006, 0.0), "metal_dark")
    c.bx((-hw, top, ln), (hw, top + 0.006, ln + 0.05), "metal_dark")
    # padlock staple on the curb flange at the latch edge (+X)
    st = fr.part(bevel=0.0)
    st.bx((hw + 0.008, top + 0.006, ln / 2 - 0.05), (hw + 0.042, top + 0.012, ln / 2 + 0.05), "steel")
    st.torus(0.018, 0.005, (hw + 0.025, top + 0.03, ln / 2), "steel", segs=10, rsegs=4, axis="X",
             arc=math.pi)
    obj = fr.build()
    mb = geo.MeshBuilder()
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw - lin)))
        mb.box((x0, top - 0.08, 0.0), (x1, top, ln))
    mb.box((-hw + lin, top - 0.08, 0.0), (hw - lin, top, lin))
    mb.box((-hw + lin, top - 0.08, ln - lin), (hw - lin, top, ln))
    geo.collision_from_builder(mb, "trimesh", parent=obj)
    # leaf: hinge on the -X lining, top flush with the grade; Leaf pivot 2.5 cm under the top (LeafBody centre)
    yl = top - 0.025
    leaf = k.empty("Leaf", (-hw + lin, yl, 0.0))
    lw = w - 2 * lin
    lf = k.obj("LeafMesh", parent=leaf)
    rim = lf.part(bevel=0.002)
    z0, z1 = lin + 0.003, ln - lin - 0.003
    x0, x1 = 0.003, lw - 0.003
    rim.bx((x0, -0.02, z0), (x0 + 0.05, 0.025, z1), "metal_dark")
    rim.bx((x1 - 0.05, -0.02, z0), (x1, 0.025, z1), "metal_dark")
    rim.bx((x0 + 0.05, -0.02, z0), (x1 - 0.05, 0.025, z0 + 0.05), "metal_dark")
    rim.bx((x0 + 0.05, -0.02, z1 - 0.05), (x1 - 0.05, 0.025, z1), "metal_dark")
    bars = lf.part(bevel=0.0)
    n = int((x1 - x0 - 0.1) / 0.04)
    for i in range(1, n):
        x = x0 + 0.05 + i * (x1 - x0 - 0.1) / n
        bars.bx((x - 0.0025, -0.015, z0 + 0.05), (x + 0.0025, 0.024, z1 - 0.05), "metal_dark")
    zz = z0 + 0.1
    while zz < z1 - 0.08:
        bars.rod((x0 + 0.05, 0.02, zz), (x1 - 0.05, 0.02, zz), 0.004, "metal_dark", segs=6)
        zz += 0.1
    # lift handle and the hasp at the latch edge; hinge knuckles on the hinge edge
    hd = lf.part(bevel=0.0)
    hd.tube([(x1 - 0.18, 0.025, ln / 2 - 0.14), (x1 - 0.18, 0.075, ln / 2 - 0.1), (x1 - 0.18, 0.075, ln / 2 + 0.1),
             (x1 - 0.18, 0.025, ln / 2 + 0.14)], 0.01, "steel", segs=8)
    hd.bx((x1 - 0.004, 0.02, ln / 2 - 0.035), (x1 + 0.055, 0.026, ln / 2 + 0.035), "steel")
    for z in (0.35, ln / 2, ln - 0.35):
        hd.cyl(0.016, 0.12, (-0.004, 0.0, z), "steel", axis="Z", segs=10)
    lf.build()
    k.empty("Handle", (x1 - 0.18, 0.09, ln / 2), parent=leaf)


# ------------------------------------------------------------------------------------ ladders

def _ladder_caged(k: Kit, p: dict) -> None:
    """Caged fire-escape ladder on a facade (wall 0.2 m behind the stiles, Blender -Y). The fixed flight runs from
    the drop section's top to the roof; the drop section (2.4 m, down) slides inside the fixed stiles; a pulley and
    a counterweight in a guide box hang beside it. Cage hoops (r 0.36) from 2.7 m to the top, five straps."""
    h, drop = p["h"], p["drop"]
    rx, rxd = 0.23, 0.19
    wall = -0.2
    top = h + 1.1
    o = k.obj("Rails")
    lp = o.part(bevel=0.002)
    rung = o.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * rx
        # straight stiles: the top 1.1 m are the grab rails beside the parapet opening (nothing reaches over the
        # wall, so the ladder never overlaps the facade)
        lp.bx((x - 0.03, -0.01, drop - 0.3), (x + 0.03, 0.01, top), "metal_dark")
        lp.cyl(0.02, 0.07, (x, 0.0, top + 0.01), "metal_dark", segs=10)
        xd = sx * rxd
        lp.bx((xd - 0.025, 0.02, 0.0), (xd + 0.025, 0.04, drop + 0.25), "metal_dark")   # drop section
        lp.bx((xd - 0.012, 0.01, drop - 0.05), (xd + 0.012, 0.02, drop + 0.25), "steel")  # slide shoe
        z = drop + 0.4
        while z < h - 0.2:   # wall brackets
            lp.bx((x - 0.012, wall, z - 0.025), (x + 0.012, -0.01, z + 0.025), "metal_dark")
            lp.bx((x - 0.05, wall, z - 0.07), (x + 0.05, wall + 0.012, z + 0.07), "metal_dark")
            z += 1.5
    z = drop + 0.15
    while z < h - 0.05:
        rung.rod((-rx, 0.0, z), (rx, 0.0, z), 0.0125, "metal_dark", segs=8)
        z += 0.3
    z = 0.3
    while z < drop + 0.2:
        rung.rod((-rxd, 0.03, z), (rxd, 0.03, z), 0.0125, "steel_galv", segs=8)
        z += 0.3
    # cage: half hoops in front of the rungs and five vertical straps
    cage = o.part(bevel=0.0)
    r = 0.36
    cy = 0.2
    z = drop + 0.3
    hoops = []
    while z < top - 0.35:
        hoops.append(z)
        cage.torus(r, 0.012, (0.0, cy - 0.03, z), "metal_dark", segs=12, rsegs=4, axis="Z", arc=math.pi)
        for sx in (-1, 1):
            cage.rod((sx * r, cy - 0.03, z), (sx * rx, 0.0, z), 0.01, "metal_dark", segs=6)
        z += 0.9
    for a in (0.15, 0.5, 0.85):
        ang = math.pi * a
        x, y = math.cos(ang) * r, cy - 0.03 + math.sin(ang) * r
        cage.bx((x - 0.02, y - 0.004, hoops[0]), (x + 0.02, y + 0.004, hoops[-1]), "metal_dark")
    for sx in (-1, 1):
        cage.bx((sx * r - 0.004, cy - 0.05, hoops[0]), (sx * r + 0.004, cy - 0.01, hoops[-1]), "metal_dark")
    # counterweight: pulley at the drop section's head, a cable down to a weight box in a guide channel
    cw = o.part(bevel=0.003)
    px = -rx - 0.1
    cw.cyl(0.07, 0.03, (px, -0.06, drop + 0.55), "steel", axis="X", segs=16)
    cw.bx((px - 0.03, wall, drop + 0.5), (px + 0.03, -0.06, drop + 0.6), "metal_dark")
    cw.bx((px - 0.05, -0.12, drop + 0.6), (px + 0.05, -0.04, h * 0.55), "metal_dark")   # guide channel
    cw.bx((px - 0.04, -0.115, drop + 1.2), (px + 0.04, -0.045, drop + 1.65), "metal_yellow")  # weight
    cw.rod((px, -0.08, drop + 1.65), (px, -0.08, drop + 0.55), 0.004, "steel", segs=6)
    cw.rod((px + 0.06, -0.03, drop + 0.55), (-rxd, 0.03, drop + 0.2), 0.004, "steel", segs=6)
    o.build()
    k.empty("Top", (0.0, -0.6, h))
    k.empty("Bottom", (0.0, 0.45, 0.0))


def _ladder_flush(k: Kit, p: dict) -> None:
    """Fixed steel well ladder (wall at Blender y 0, stiles 0.16 in front); the stiles stop 6 cm under the landing
    (a grate closes the well over it), rungs every 0.3 m, wall brackets every 1.2 m."""
    h = p["h"]
    rail_x = 0.2
    off = 0.16
    lad = k.obj("Rails")
    lp = lad.part(bevel=0.002)
    top = h - 0.1
    for sx in (-1, 1):
        x = sx * rail_x
        lp.bx((x - 0.03, off - 0.01, 0.0), (x + 0.03, off + 0.01, top), "metal_dark")
        z = 0.6
        while z < top - 0.1:
            lp.bx((x - 0.012, 0.012, z - 0.02), (x + 0.012, off - 0.01, z + 0.02), "metal_dark")
            lp.bx((x - 0.04, 0.0, z - 0.05), (x + 0.04, 0.012, z + 0.05), "metal_dark")
            z += 1.2
    z = 0.3
    while z < top - 0.05:
        lp.rod((-rail_x, off, z), (rail_x, off, z), 0.0125, "metal_dark", segs=8)
        z += 0.3
    lad.build()
    k.empty("Top", (0.0, -0.45, h))
    k.empty("Bottom", (0.0, 0.5, 0.0))


# ---------------------------------------------------------------------------------- canvases

def _paint_uv(obj, mat_name: str, crop: float = 1.0) -> None:
    """Map the painted faces of `obj` onto the square image (cover fit, centred; `crop` < 1 zooms in)."""
    me = obj.data
    idx = {i for i, m in enumerate(me.materials) if m is not None and m.name == mat_name}
    polys = [pl for pl in me.polygons if pl.material_index in idx]
    if not polys:
        return
    xs = [me.vertices[v].co.x for pl in polys for v in pl.vertices]
    zs = [me.vertices[v].co.z for pl in polys for v in pl.vertices]
    xc, zc = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2
    s = max(max(xs) - min(xs), max(zs) - min(zs)) / crop
    uvl = me.uv_layers.active.data
    for pl in polys:
        for li in pl.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uvl[li].uv = (0.5 + (co.x - xc) / s, 0.5 + (co.z - zc) / s)


def _framed(k: Kit, name: str, pid: str, cw: float, ch: float, y_back: float, zc: float, mould: float,
            gilt: bool = True, parent=None):
    """Framed canvas, back plane at y_back, centred at (0, zc): moulding (outer bead, cove, inner sight edge in
    gilt), a linen slip and the painted canvas recessed 1.5 cm."""
    o = k.obj(name, parent=parent)
    fk = "brass" if gilt else "wood_dark"
    fr = o.part(bevel=0.006, segments=2)
    bead = o.part(bevel=0.002)
    hw, hh = cw / 2 + mould, ch / 2 + mould
    d = 0.06
    for (x0, x1, z0, z1) in ((-hw, hw, zc + hh - mould, zc + hh), (-hw, hw, zc - hh, zc - hh + mould),
                             (-hw, -hw + mould, zc - hh + mould, zc + hh - mould),
                             (hw - mould, hw, zc - hh + mould, zc + hh - mould)):
        fr.bx((x0, y_back, z0), (x1, y_back + d, z1), fk)
    # outer bead and inner sight edge
    for inset, dy, key in ((0.004, d + 0.008, fk), (mould - 0.012, d + 0.004, "wood_dark" if gilt else "brass")):
        x0, x1, z0, z1 = -hw + inset, hw - inset, zc - hh + inset, zc + hh - inset
        bw = 0.012
        bead.bx((x0, y_back + d, z1 - bw), (x1, y_back + dy, z1), key)
        bead.bx((x0, y_back + d, z0), (x1, y_back + dy, z0 + bw), key)
        bead.bx((x0, y_back + d, z0 + bw), (x0 + bw, y_back + dy, z1 - bw), key)
        bead.bx((x1 - bw, y_back + d, z0 + bw), (x1, y_back + dy, z1 - bw), key)
    slip = o.part(bevel=0.0)
    s = 0.03
    slip.bx((-cw / 2 - 0.002, y_back + 0.01, zc - ch / 2 - 0.002), (cw / 2 + 0.002, y_back + d - 0.024, zc + ch / 2 + 0.002),
            "canvas_ivory")
    pt = o.part(bevel=0.0)
    pt.bx((-cw / 2 + s, y_back + d - 0.03, zc - ch / 2 + s), (cw / 2 - s, y_back + d - 0.016, zc + ch / 2 - s),
          f"painting_{pid}")
    obj = o.build()
    _paint_uv(obj, k.mat(f"painting_{pid}").name)
    return obj


def _canvas_hung(k: Kit, p: dict) -> None:
    pid = p["pid"]
    cw, ch = _CANVAS[pid]
    mould = 0.11 if pid in ("lantern", "orchard", "widow", "saint") else 0.07
    _framed(k, "Canvas", pid, cw, ch, 0.0, 0.0, mould)
    # hanging wire and two brass hooks above the frame (the gallery's picture rail look, at the wall)
    hook = k.obj("Hooks")
    hp = hook.part(bevel=0.0)
    top = ch / 2 + mould
    for sx in (-1, 1):
        hp.bx((sx * cw * 0.3 - 0.01, 0.0, top + 0.05), (sx * cw * 0.3 + 0.01, 0.012, top + 0.08), "brass")
        hp.rod((sx * cw * 0.3, 0.008, top + 0.05), (sx * cw * 0.15, 0.008, top - 0.02), 0.0015, "steel", segs=4)
    hook.build()


def _canvas_easel(k: Kit, p: dict) -> None:
    """Conservation easel (H-frame studio easel, oak) with the unframed canvas on its tray; floor pivot, the easel
    centred, canvas facing -Z."""
    pid = p["pid"]
    cw, ch = _CANVAS[pid]
    e = k.obj("Easel")
    wd = e.part(bevel=0.004)
    tray = 0.72
    lean = 0.12
    for sx in (-1, 1):
        x = sx * (cw / 2 - 0.08)
        wd.bx((x - 0.03, -0.12, 0.0), (x + 0.03, -0.06, 2.05), "wood_oak")
    wd.bx((-cw / 2 + 0.05, -0.12, 0.08), (cw / 2 - 0.05, -0.06, 0.14), "wood_oak")
    wd.bx((-cw / 2 + 0.05, -0.12, 2.0), (cw / 2 - 0.05, -0.06, 2.06), "wood_oak")
    wd.bx((-0.05, -0.12, 0.14), (0.05, -0.06, 2.0), "wood_oak")
    wd.bx((-cw / 2 - 0.02, -0.06, tray - 0.03), (cw / 2 + 0.02, 0.06, tray), "wood_oak")       # tray
    wd.bx((-cw / 2 - 0.02, 0.04, tray), (cw / 2 + 0.02, 0.06, tray + 0.04), "wood_oak")
    wd.bx((-0.25, -0.6 - lean, 0.0), (0.25, -0.12, 0.08), "wood_oak")                          # base
    wd.rod((0.0, -0.6 - lean, 0.08), (0.0, -0.1, 1.6), 0.02, "wood_oak", segs=8)               # back leg
    wd.bx((-0.06, -0.06, tray + ch + 0.01), (0.06, 0.02, tray + ch + 0.08), "wood_oak")        # top clamp
    e.build()
    c = k.obj("Canvas")
    st = c.part(bevel=0.002)
    st.bx((-cw / 2, -0.03, tray), (cw / 2, 0.0, tray + ch), "canvas_ivory")
    pt = c.part(bevel=0.0)
    pt.bx((-cw / 2 + 0.005, 0.0, tray + 0.005), (cw / 2 - 0.005, 0.004, tray + ch - 0.005), f"painting_{pid}")
    obj = c.build()
    _paint_uv(obj, k.mat(f"painting_{pid}").name)
    # task lamp clip and a palette on the tray end (conservation dressing)
    d = k.obj("Tools")
    dp = d.part(bevel=0.002)
    dp.bx((cw / 2 - 0.2, -0.05, tray), (cw / 2 - 0.02, 0.03, tray + 0.012), "wood_pine")
    dp.cyl(0.006, 0.12, (cw / 2 - 0.25, 0.0, tray + 0.006), "wood_dark", axis="X", segs=6)
    d.build()


def _canvas_crate(k: Kit, p: dict) -> None:
    """Opened travel crate (pine, front panel off and leaning against the side) with the framed canvas standing in
    foam packing; floor pivot at the crate's footprint centre, canvas facing -Z."""
    pid = p["pid"]
    cw, ch = _CANVAS[pid]
    big = pid == "orchard"
    mould = 0.08 if big else 0.05
    iw, ih, idp = cw + 2 * mould + 0.12, ch + 2 * mould + 0.12, 0.28
    o = k.obj("Crate")
    cr = o.part(bevel=0.004)
    b = 0.022
    cr.bx((-iw / 2 - b, -idp / 2 - b, 0.0), (iw / 2 + b, idp / 2, 0.1), "wood_pine")           # skid base
    cr.bx((-iw / 2 - b, -idp / 2 - b, 0.1), (iw / 2 + b, -idp / 2, ih + 0.1), "wood_pine")    # back
    for sx in (-1, 1):
        x0, x1 = sorted((sx * iw / 2, sx * (iw / 2 + b)))
        cr.bx((x0, -idp / 2, 0.1), (x1, idp / 2, ih + 0.1), "wood_pine")
    cr.bx((-iw / 2 - b, -idp / 2, ih + 0.1), (iw / 2 + b, idp / 2, ih + 0.1 + b), "wood_pine")
    # battens on the outside of the back and sides, stencil-like dark bands
    bt = o.part(bevel=0.002)
    for z in (0.2, ih * 0.5 + 0.1, ih):
        bt.bx((-iw / 2 - b, -idp / 2 - b - 0.02, z), (iw / 2 + b, -idp / 2 - b, z + 0.07), "wood_oak")
    foam = o.part(bevel=0.003)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * iw / 2, sx * (iw / 2 - 0.06)))
        foam.bx((x0, -idp / 2, 0.1), (x1, idp / 2 - 0.02, ih + 0.08), "plastic_grey")
    foam.bx((-iw / 2 + 0.06, -idp / 2, 0.1), (iw / 2 - 0.06, idp / 2 - 0.02, 0.16), "plastic_grey")
    o.build()
    _framed(k, "Canvas", pid, cw, ch, -0.03, 0.16 + ch / 2 + mould, mould)
    lid = k.obj("Lid")
    lp = lid.part(bevel=0.004)
    # the removed front panel leans against the crate's right side
    ang = math.radians(12)
    x0 = iw / 2 + b + 0.005
    lh = ih + 0.12
    lean = math.sin(ang) * lh
    # leaning outward: foot away from the crate, top resting on its side
    pts = [(x0 + lean, 0.0), (x0 + lean + 0.02, 0.0), (x0 + 0.02, lh * math.cos(ang)), (x0, lh * math.cos(ang))]
    lp.prism(pts, axis="Y", start=-idp / 2, end=idp / 2 - 0.04, mat=lp.m("wood_pine"))
    lid.build()


# ------------------------------------------------------------------------------------- rack

def _rack(k: Kit, p: dict) -> None:
    """Pull-out painting screen: 3.0 m steel frame with welded mesh infill, 2.7 m tall, riding a floor channel on
    the left end and hung from a ceiling trolley post; a pull handle and a number plate at the aisle end (+X)."""
    ln, hgt, th = 3.0, 2.7, 0.08
    hl = ln / 2
    o = k.obj("Screen")
    f = o.part(bevel=0.003)
    for x0, x1 in ((-hl, -hl + 0.05), (hl - 0.05, hl)):
        f.bx((x0, -th / 2, 0.06), (x1, th / 2, hgt), "powder_charcoal")
    f.bx((-hl, -th / 2, hgt - 0.05), (hl, th / 2, hgt), "powder_charcoal")
    f.bx((-hl, -th / 2, 0.06), (hl, th / 2, 0.11), "powder_charcoal")
    f.bx((-hl, -th / 2 + 0.01, 1.35), (hl, th / 2 - 0.01, 1.39), "powder_charcoal")
    f.bx((-0.02, -th / 2 + 0.01, 0.11), (0.02, th / 2 - 0.01, hgt - 0.05), "powder_charcoal")
    # floor channel and wheels, top trolley
    run = o.part(bevel=0.0)
    run.bx((-hl - 0.02, -0.03, 0.0), (hl + 0.02, 0.03, 0.02), "metal_dark")
    for x in (-hl + 0.3, hl - 0.3):
        run.cyl(0.03, 0.025, (x, 0.0, 0.045), "rubber", axis="Y", segs=10)
        run.bx((x - 0.04, -0.02, 0.04), (x + 0.04, 0.02, 0.07), "metal_dark")
    run.bx((-hl + 0.2, -0.02, hgt), (hl - 0.2, 0.02, hgt + 0.04), "metal_dark")
    mesh = o.part(bevel=0.0)
    for i in range(1, 30):
        x = -hl + 0.05 + i * (ln - 0.1) / 30
        if abs(x) < 0.03:
            continue
        mesh.bx((x - 0.002, -0.003, 0.11), (x + 0.002, 0.003, hgt - 0.05), "steel_galv")
    z = 0.11 + 0.1
    while z < hgt - 0.08:
        if not 1.33 < z < 1.41:
            mesh.bx((-hl + 0.05, -0.003, z - 0.002), (hl - 0.05, 0.003, z + 0.002), "steel_galv")
        z += 0.1
    h2 = o.part(bevel=0.0)
    for sy in (-1, 1):
        y = sy * (th / 2 + 0.035)
        h2.rod((hl - 0.03, sy * th / 2, 1.0), (hl - 0.03, y, 1.0), 0.008, "steel", segs=6)
        h2.rod((hl - 0.03, sy * th / 2, 1.3), (hl - 0.03, y, 1.3), 0.008, "steel", segs=6)
        h2.rod((hl - 0.03, y, 1.0), (hl - 0.03, y, 1.3), 0.012, "steel", segs=8)
        y0, y1 = sorted((sy * th / 2, sy * (th / 2 + 0.003)))
        h2.bx((hl - 0.045, y0, 1.6), (hl - 0.005, y1, 1.68), "plastic_white")
    o.build()
    k.collision([((-hl, -th / 2, 0.0), (hl, th / 2, hgt + 0.04))])


# ------------------------------------------------------------------------------ safe / boxes

def _safe_wall(k: Kit, p: dict) -> None:
    """Small wall safe (safe SMALL): steel body bolted to the wall, back at y 0, bottom at the pivot; door hinged
    on -X with a dial and a handle; `DrillPoint` at the dial, `LootAnchor` on the inside floor."""
    w, h, d, wall = 0.6, 0.55, 0.42, 0.05
    body = k.obj("Body")
    hard = body.part(bevel=0.004, segments=2)
    inner = body.part(bevel=0.0)
    hard.bx((-w / 2, 0.0, 0.0), (w / 2, wall, h), "paint_halberd")
    hard.bx((-w / 2, 0.0, 0.0), (-w / 2 + wall, d, h), "paint_halberd")
    hard.bx((w / 2 - wall, 0.0, 0.0), (w / 2, d, h), "paint_halberd")
    hard.bx((-w / 2, 0.0, h - wall), (w / 2, d, h), "paint_halberd")
    hard.bx((-w / 2, 0.0, 0.0), (w / 2, d, wall), "paint_halberd")
    inner.bx((-w / 2 + wall, wall, wall), (w / 2 - wall, wall + 0.004, h - wall), "steel")
    for sx in (-1, 1):   # wall bolts visible inside
        inner.cyl(0.012, 0.01, (sx * 0.15, wall + 0.009, h / 2), "steel", axis="Y", segs=8)
    body.build()
    ow, oh = w - 2 * wall, h - 2 * wall
    door = k.empty("Door", (-ow / 2, d, wall))
    dm = k.obj("DoorMesh", parent=door)
    dh = dm.part(bevel=0.004, segments=2)
    dt = dm.part(bevel=0.0015)
    dw, dz = ow - 0.004, oh - 0.004
    dh.bx((0.002, -0.06, 0.002), (dw, 0.0, dz), "paint_halberd")
    dh.bx((0.03, 0.0, 0.03), (dw - 0.03, 0.01, dz - 0.03), "paint_halberd")
    cx, cz = dw * 0.4, dz * 0.55
    dt.cyl(0.055, 0.01, (cx, 0.015, cz), "brass", axis="Y", segs=28)
    dt.cyl(0.04, 0.025, (cx, 0.03, cz), "metal_dark", axis="Y", segs=24)
    for i in range(20):
        a = 2 * math.pi * i / 20
        dt.cbox((cx + math.cos(a) * 0.048, 0.021, cz + math.sin(a) * 0.048), (0.003, 0.004, 0.003), "plastic_white")
    hx = dw * 0.8
    dt.cyl(0.018, 0.02, (hx, 0.02, cz), "brass", axis="Y", segs=14)
    dt.rod((hx, 0.03, cz), (hx, 0.03, cz - 0.09), 0.008, "brass", segs=8)
    dt.bx((dw * 0.5 - 0.06, 0.0, dz - 0.07), (dw * 0.5 + 0.06, 0.004, dz - 0.045), "brass")
    for z in (0.08, dz - 0.08):
        dt.cyl(0.01, 0.07, (-0.006, -0.03, z), "steel", segs=10)
    dm.build()
    k.empty("DrillPoint", (-ow / 2 + cx, d + 0.05, wall + cz), rotation=(0.0, 0.0, math.pi))
    k.empty("LootAnchor", (0.0, d * 0.5, wall + 0.002))


def _deposit_box(k: Kit, p: dict) -> None:
    """Consignment locker box (deposit_box): a steel box 0.42 x 0.45, 0.4 deep, wall-mounted (back at y 0, bottom at
    the pivot); a numbered door with a lever lock and twin keyholes, hinges on -X."""
    w, h, d = 0.42, 0.45, 0.4
    b = k.obj("Body")
    hard = b.part(bevel=0.004, segments=2)
    hard.bx((-w / 2, 0.0, 0.0), (w / 2, d, h), "steel_galv")
    trim = b.part(bevel=0.0015)
    trim.bx((-w / 2 + 0.02, d, 0.02), (w / 2 - 0.02, d + 0.012, h - 0.02), "steel")
    trim.bx((-0.06, d + 0.012, h - 0.11), (0.06, d + 0.016, h - 0.06), "brass")          # number plate
    for x in (-0.05, 0.05):
        trim.cyl(0.012, 0.006, (x, d + 0.015, h * 0.45), "brass", axis="Y", segs=12)
        trim.cbox((x, d + 0.019, h * 0.45), (0.003, 0.003, 0.012), "metal_dark")
    trim.rod((0.13, d + 0.03, h * 0.45 + 0.06), (0.13, d + 0.03, h * 0.45 - 0.06), 0.008, "steel", segs=8)
    for z in (0.08, h - 0.08):
        trim.cyl(0.009, 0.06, (-w / 2 + 0.01, d + 0.008, z), "steel", segs=8)
    b.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
