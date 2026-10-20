"""Ostrander Federal G2 vault and back-office dressing (OF-C2 surfaces / vault lane, ENV C; ostrander_federal.md
Basement notes: the cash cage, the bullion cage, the bond safe, the box walls; palette limestone / deep ultramarine /
meridian bronze). Plain dressing props (no prefab, no interaction): the loot itself stays the mission's loot_spawn.

Floor props: pivot bottom-centre, front +Y (Godot -Z). "on" props sit on a host top. Wall props: back at y 0.
* `prop_of_gold_bars`: a stack of 400 oz bars (25 x 7 x 4.5 cm trapezoids) laid in alternating courses, "on".
* `prop_of_gold_skid`: a steel skid (0.8 x 0.6) with three bar stacks, floor.
* `prop_of_bullion_cart`: a steel platform truck (1.0 x 0.6) with a push handle, four casters and two bar stacks.
* `prop_of_cash_skid`: a half pallet (0.8 x 0.6) of banded cash bricks, the top course part-taken, floor.
* `prop_of_cage_shelving`: a 1.8 m caged steel shelving bay (barred back and ends) with cash bricks, bond boxes and gold.
* `prop_of_bond_boxes`: three grey-blue bond storage boxes with label frames, "on".
* `prop_of_bullion_scale`: a bullion balance (steel base, platform, a lit read-out), "on".
* `prop_of_vault_sign_*`: enamelled ultramarine plates with cut lettering (wall).
* `prop_of_notice_board`: a cork notice board with pinned sheets and a schedule (wall).
* `prop_of_strap_bins`: a steel bench of note-strap and band bins, floor (the count room).
"""

import _pb
from _pb import Kit

TRI_BUDGET = 8000
_G = "ostrander"

VARIANTS = {
    "prop_of_gold_bars": {"fn": "gold_bars", "cat": {"kind": "bullion", "place": "on", "group": _G, "surface": "metal"}},
    "prop_of_gold_skid": {"fn": "gold_skid", "cat": {"kind": "bullion", "place": "wall", "group": _G, "surface": "metal"}},
    "prop_of_bullion_cart": {"fn": "bullion_cart", "cat": {"kind": "cart", "place": "wall", "group": _G,
                                                           "surface": "metal"}},
    "prop_of_cash_skid": {"fn": "cash_skid", "cat": {"kind": "pallet", "place": "wall", "group": _G, "surface": "wood"}},
    "prop_of_cage_shelving": {"fn": "cage_shelving", "cat": {"kind": "shelving", "place": "wall", "group": _G,
                                                             "surface": "metal"}},
    "prop_of_bond_boxes": {"fn": "bond_boxes", "cat": {"kind": "box", "place": "on", "group": _G, "surface": "wood"}},
    "prop_of_bullion_scale": {"fn": "bullion_scale", "cat": {"kind": "scale", "place": "on", "group": _G,
                                                             "surface": "metal"}},
    "prop_of_vault_sign_bullion": {"fn": "vault_sign", "text": "BULLION", "w": 0.9,
                                   "cat": {"kind": "sign", "place": "wall_mount", "group": _G, "surface": "metal"}},
    "prop_of_vault_sign_cash": {"fn": "vault_sign", "text": "CASH CAGE", "w": 1.0,
                                "cat": {"kind": "sign", "place": "wall_mount", "group": _G, "surface": "metal"}},
    "prop_of_vault_sign_staff": {"fn": "vault_sign", "text": "AUTHORISED STAFF ONLY", "w": 1.5,
                                 "cat": {"kind": "sign", "place": "wall_mount", "group": _G, "surface": "metal"}},
    "prop_of_vault_sign_bonds": {"fn": "vault_sign", "text": "BONDS", "w": 0.7,
                                 "cat": {"kind": "sign", "place": "wall_mount", "group": _G, "surface": "metal"}},
    "prop_of_notice_board": {"fn": "notice_board", "cat": {"kind": "bulletin_board", "place": "wall_mount", "group": _G,
                                                           "surface": "wood"}},
    "prop_of_strap_bins": {"fn": "strap_bins", "cat": {"kind": "shelving", "place": "wall", "group": _G,
                                                       "surface": "metal"}},
}

# Glyphs the shared stroke font lacks (this module's builds only; as ostrander_landmarks adds D and F).
_pb.GLYPHS.setdefault("D", (0.66, [[(0.0, 0.0), (0.0, 1.0), (0.28, 1.0)] + _pb._arc(0.28, 0.5, 0.38, 0.5, 90, -90, 10)
                                   + [(0.0, 0.0)]]))
_pb.GLYPHS.setdefault("U", (0.62, [[(0.0, 1.0), (0.0, 0.3)] + _pb._arc(0.31, 0.3, 0.31, 0.3, 180, 360, 8)
                                   + [(0.62, 1.0)]]))
_pb.GLYPHS.setdefault("F", (0.5, [[(0.5, 1.0), (0.0, 1.0), (0.0, 0.0)], [(0.0, 0.53), (0.42, 0.53)]]))

BAR_L, BAR_W, BAR_H, BAR_TOP_W = 0.25, 0.075, 0.045, 0.055


def _bar(p, cx: float, cy: float, z: float, along_x: bool) -> None:
    """One gold bar: a trapezoid section extruded along its length."""
    hw, ht = BAR_W / 2, BAR_TOP_W / 2
    if along_x:
        p.profile_x([(cy - hw, z), (cy + hw, z), (cy + ht, z + BAR_H), (cy - ht, z + BAR_H)], cx - BAR_L / 2, cx + BAR_L / 2,
                    "ofd_gold")
    else:
        p.profile_y([(cx - hw, z), (cx + hw, z), (cx + ht, z + BAR_H), (cx - ht, z + BAR_H)], cy - BAR_L / 2, cy + BAR_L / 2,
                    "ofd_gold")


def _bar_stack(p, cx: float, cy: float, z0: float, courses: int, per: int = 4) -> float:
    """Alternating courses of `per` bars (lengthwise X, then Y), each course one bar narrower on top. Returns the top."""
    z = z0
    for c in range(courses):
        n = max(1, per - c // 2)
        along_x = c % 2 == 0
        pitch = BAR_W + 0.006
        for i in range(n):
            off = (i - (n - 1) / 2) * pitch
            if along_x:
                _bar(p, cx, cy + off, z, True)
            else:
                _bar(p, cx + off, cy, z, False)
        z += BAR_H + 0.001
    return z


def _gold_bars(k: Kit, p: dict) -> None:
    o = k.obj("Gold")
    a = o.part(bevel=0.0)
    _bar_stack(a, 0.0, 0.0, 0.0, 4, 3)
    o.build()


def _skid(a, w: float, d: float, h: float, key: str) -> None:
    """A low steel skid: deck plate on three runners."""
    for y in (-d / 2 + 0.04, 0.0, d / 2 - 0.04):
        a.bx((-w / 2, y - 0.035, 0.0), (w / 2, y + 0.035, h - 0.012), key)
    a.bx((-w / 2, -d / 2, h - 0.012), (w / 2, d / 2, h), key)


def _gold_skid(k: Kit, p: dict) -> None:
    w, d, h = 0.8, 0.6, 0.1
    o = k.obj("GoldSkid")
    s = o.part(bevel=0.003)
    _skid(s, w, d, h, "metal_dark")
    g = o.part(bevel=0.0)
    for cx, cy, courses in ((-0.22, -0.13, 6), (0.12, -0.13, 5), (-0.06, 0.15, 4)):
        _bar_stack(g, cx, cy, h, courses, 3)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h + 0.28))])


def _bullion_cart(k: Kit, p: dict) -> None:
    w, d = 1.0, 0.6
    deck = 0.28
    o = k.obj("Cart")
    f = o.part(bevel=0.004)
    f.bx((-w / 2, -d / 2, deck - 0.03), (w / 2, d / 2, deck), "of_box_steel")
    f.bx((-w / 2, -d / 2, deck - 0.08), (w / 2, -d / 2 + 0.03, deck - 0.03), "metal_dark")
    f.bx((-w / 2, d / 2 - 0.03, deck - 0.08), (w / 2, d / 2, deck - 0.03), "metal_dark")
    r = o.part(bevel=0.0)
    for x in (-w / 2 + 0.1, w / 2 - 0.1):
        for y in (-d / 2 + 0.08, d / 2 - 0.08):
            r.cyl(0.07, 0.05, (x, y, 0.07), "rubber", axis="X", segs=12)
            r.bx((x - 0.035, y - 0.02, 0.07), (x + 0.035, y + 0.02, deck - 0.08), "metal_dark")
    # push handle at the -X end
    for y in (-d / 2 + 0.04, d / 2 - 0.04):
        r.rod((-w / 2 + 0.02, y, deck), (-w / 2 - 0.02, y, deck + 0.75), 0.014, "steel", segs=8)
    r.rod((-w / 2 - 0.02, -d / 2 + 0.04, deck + 0.75), (-w / 2 - 0.02, d / 2 - 0.04, deck + 0.75), 0.016, "steel", segs=8)
    g = o.part(bevel=0.0)
    _bar_stack(g, 0.12, -0.12, deck, 5, 3)
    _bar_stack(g, 0.12, 0.14, deck, 4, 3)
    o.build()
    k.collision([((-w / 2 - 0.05, -d / 2, 0.0), (w / 2, d / 2, deck + 0.3))])


def _bricks(b, x0: float, y0: float, z0: float, nx: int, ny: int, nz: int, lw: float, ld: float, lh: float,
            skip_top: bool = True) -> None:
    for layer in range(nz):
        z = z0 + layer * lh
        for ix in range(nx):
            for iy in range(ny):
                if skip_top and layer == nz - 1 and (ix * 2 + iy) % 3 == 1:
                    continue
                x = x0 + ix * (lw + 0.01) + lw / 2
                y = y0 + iy * (ld + 0.01) + ld / 2
                b.bx((x - lw / 2, y - ld / 2, z), (x + lw / 2, y + ld / 2, z + lh - 0.004), "cash_green")
                b.bx((x - 0.018, y - ld / 2 - 0.002, z + 0.002), (x + 0.018, y + ld / 2 + 0.002, z + lh - 0.006), "paper")


def _cash_skid(k: Kit, p: dict) -> None:
    w, d = 0.8, 0.6
    o = k.obj("CashSkid")
    a = o.part(bevel=0.003)
    for y in (-d / 2 + 0.05, 0.0, d / 2 - 0.05):
        a.bx((-w / 2, y - 0.045, 0.0), (w / 2, y + 0.045, 0.09), "wood_pine")
    for i in range(5):
        x = -w / 2 + 0.06 + i * (w - 0.12) / 4
        a.bx((x - 0.05, -d / 2, 0.09), (x + 0.05, d / 2, 0.11), "wood_pine")
    b = o.part(bevel=0.003)
    _bricks(b, -w / 2 + 0.02, -d / 2 + 0.02, 0.11, 3, 3, 4, 0.245, 0.18, 0.12)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.59))])


def _cage_shelving(k: Kit, p: dict) -> None:
    """Back at y 0 against the wall, front +Y: four shelves in a barred steel bay."""
    w, d, h = 1.8, 0.5, 2.0
    o = k.obj("Shelving")
    f = o.part(bevel=0.003)
    for x in (-w / 2, w / 2 - 0.04):
        for y in (0.0, d - 0.04):
            f.bx((x, y, 0.0), (x + 0.04, y + 0.04, h), "metal_dark")
    shelves = (0.08, 0.55, 1.02, 1.49, 1.96)
    for z in shelves:
        f.bx((-w / 2 + 0.04, 0.02, z - 0.03), (w / 2 - 0.04, d - 0.02, z), "of_box_steel")
    bars = o.part(bevel=0.0)
    for i in range(1, 18):
        x = -w / 2 + i * w / 18
        bars.bx((x - 0.006, 0.01, 0.08), (x + 0.006, 0.022, h - 0.04), "metal_dark")
    for side in (-w / 2 + 0.014, w / 2 - 0.026):
        for j in range(1, 5):
            y = j * d / 5
            bars.bx((side, y - 0.006, 0.08), (side + 0.012, y + 0.006, h - 0.04), "metal_dark")
    c = o.part(bevel=0.003)
    # shelf 1 / 2: cash bricks; shelf 3: bond boxes; shelf 4: gold
    _bricks(c, -w / 2 + 0.08, 0.06, shelves[0], 6, 2, 3, 0.25, 0.18, 0.12)
    _bricks(c, -w / 2 + 0.08, 0.06, shelves[1], 4, 2, 2, 0.25, 0.18, 0.12)
    for i in range(4):
        x = -w / 2 + 0.12 + i * 0.4
        c.bx((x, 0.06, shelves[2]), (x + 0.34, 0.42, shelves[2] + 0.28), "ofd_bond_grey")
        c.bx((x + 0.12, 0.42, shelves[2] + 0.12), (x + 0.22, 0.424, shelves[2] + 0.18), "paper")
    g = o.part(bevel=0.0)
    for cx in (-0.55, -0.15, 0.25):
        _bar_stack(g, cx, 0.24, shelves[3], 4, 3)
    o.build()
    k.collision([((-w / 2, 0.0, 0.0), (w / 2, d, h))])


def _bond_boxes(k: Kit, p: dict) -> None:
    o = k.obj("Bonds")
    a = o.part(bevel=0.004)
    for i, (x, y, z) in enumerate(((0.0, 0.0, 0.0), (0.02, 0.01, 0.13), (-0.01, -0.01, 0.26))):
        a.bx((x - 0.18, y - 0.13, z), (x + 0.18, y + 0.13, z + 0.125), "ofd_bond_grey")
        a.bx((x - 0.05, y + 0.13, z + 0.04), (x + 0.05, y + 0.133, z + 0.09), "of_box_steel")
        if i == 2:
            a.bx((x - 0.04, y + 0.133, z + 0.05), (x + 0.04, y + 0.135, z + 0.08), "paper")
    o.build()


def _bullion_scale(k: Kit, p: dict) -> None:
    o = k.obj("Scale")
    a = o.part(bevel=0.004)
    a.bx((-0.2, -0.16, 0.0), (0.2, 0.16, 0.05), "metal_dark")
    a.bx((-0.17, -0.13, 0.05), (0.17, 0.13, 0.065), "steel")
    a.bx((-0.08, 0.16, 0.0), (0.08, 0.22, 0.14), "metal_dark")
    s = o.part(bevel=0.0)
    s.bx((-0.065, 0.159, 0.06), (0.065, 0.161, 0.11), "emit_led_green")
    g = o.part(bevel=0.0)
    _bar(g, 0.0, -0.02, 0.065, True)
    o.build()


def _vault_sign(k: Kit, p: dict) -> None:
    """Wall plate, back at y 0: ultramarine enamel, a bronze rim, cut white lettering."""
    w = float(p["w"])
    h = 0.22
    o = k.obj("Sign")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.012, h / 2), "of_bronze_dark")
    a.bx((-w / 2 + 0.012, 0.012, -h / 2 + 0.012), (w / 2 - 0.012, 0.016, h / 2 - 0.012), "ofd_enamel_ultra")
    t = o.part(bevel=0.0)
    text = str(p["text"])
    th = 0.075 if len(text) < 12 else 0.06
    _pb.lettering(t, text, th, 0.0, 0.016, -th / 2, "paint_ivory", stroke=0.012, depth=0.003, inlay=True)
    o.build()


def _notice_board(k: Kit, p: dict) -> None:
    """Wall board, back at y 0: oak frame, cork, pinned sheets, a ruled duty schedule."""
    w, h = 1.2, 0.8
    o = k.obj("Board")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.02, h / 2), "wood_oak")
    a.bx((-w / 2 + 0.03, 0.02, -h / 2 + 0.03), (w / 2 - 0.03, 0.024, h / 2 - 0.03), "cork")
    s = o.part(bevel=0.0)
    sheets = ((-0.42, 0.12, 0.21, 0.297), (-0.18, 0.15, 0.21, 0.297), (0.06, 0.1, 0.297, 0.21), (-0.38, -0.2, 0.21, 0.15),
              (0.0, -0.18, 0.15, 0.21))
    for x, z, sw, sh in sheets:
        s.bx((x, 0.024, z - sh / 2), (x + sw, 0.026, z + sh / 2), "paper")
        s.bx((x + sw / 2 - 0.006, 0.026, z + sh / 2 - 0.02), (x + sw / 2 + 0.006, 0.034, z + sh / 2 - 0.008), "metal_red")
    # the schedule grid (ruled sheet)
    gx0, gz0, gw, gh = 0.25, -0.33, 0.3, 0.6
    s.bx((gx0, 0.024, gz0), (gx0 + gw, 0.026, gz0 + gh), "paper")
    for i in range(1, 8):
        z = gz0 + i * gh / 8
        s.bx((gx0 + 0.01, 0.026, z - 0.002), (gx0 + gw - 0.01, 0.0275, z + 0.002), "art_blue")
    s.bx((gx0 + 0.09, 0.026, gz0 + 0.01), (gx0 + 0.094, 0.0275, gz0 + gh - 0.01), "art_blue")
    o.build()


def _strap_bins(k: Kit, p: dict) -> None:
    """Back at y 0: a steel bench (1.2 x 0.5 x 0.9) with a top rack of strap / band bins."""
    w, d, h = 1.2, 0.5, 0.9
    o = k.obj("Bins")
    f = o.part(bevel=0.003)
    for x in (-w / 2, w / 2 - 0.04):
        for y in (0.0, d - 0.04):
            f.bx((x, y, 0.0), (x + 0.04, y + 0.04, h), "metal_dark")
    f.bx((-w / 2, 0.0, h - 0.03), (w / 2, d, h), "of_box_steel")
    f.bx((-w / 2 + 0.04, 0.04, 0.12), (w / 2 - 0.04, d - 0.04, 0.15), "of_box_steel")
    f.bx((-w / 2, 0.0, h), (w / 2, 0.04, h + 0.5), "metal_dark")
    b = o.part(bevel=0.003)
    keys = ("plastic_blue", "metal_yellow", "metal_red", "plastic_blue", "metal_green")
    for i in range(5):
        x = -w / 2 + 0.04 + i * 0.23
        b.bx((x, 0.04, h + 0.05), (x + 0.2, 0.26, h + 0.2), keys[i])
        b.bx((x + 0.03, 0.06, h + 0.2), (x + 0.17, 0.22, h + 0.24), "paper")
        b.bx((x, 0.04, h + 0.27), (x + 0.2, 0.22, h + 0.4), keys[(i + 2) % 5])
    for i in range(3):
        x = -w / 2 + 0.1 + i * 0.36
        b.bx((x, 0.05, 0.15), (x + 0.3, 0.4, 0.4), "ofd_bond_grey")
    o.build()
    k.collision([((-w / 2, 0.0, 0.0), (w / 2, d, h + 0.5))])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
