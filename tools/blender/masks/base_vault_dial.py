"""Vault Dial customisable base mask (``mask_base.vault_dial``, achievement reward, Ostrander Federal).

An original bank-vault door worn as a face: a round, gently domed steel plate (not a face form at
all) edged by a raised bolt-ring rim with hex bolt heads all the way round, a combination-dial ring
inside it (a raised band with relief tick marks, a longer tick and a numeral 0-9 every fifth tick,
and an index notch at the top), two round porthole eyes with raised rims set in the plate, and over
the nose a spoked handle: a turned hub with three spokes ending in ball knobs. No real-world maker's
mark or brand. The round outline, bolt ring and spoked hub read as "vault door" at a glance.

The plate is a cylinder-and-dome sheet (``DoorSurface``, a ``FaceSurface`` without the face features
and with a constant width), so circles drawn in front-view coordinates (x, v) stay round; the crew
fit still lifts it clear of every crew face.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_vault_dial"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "brow": 0.0,
    "cheek": 0.0,
    "nose": 0.0,
    "jaw": 0.0,
    "eye_shape": "round",
    "eye_width": 0.025,
    "eye_height": 0.025,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.100,
    "wrap_radius": 0.100,
    "thickness": 0.005,
    "chamfer": 0.0016,
    "res": 0.0100,
    "res_back": 0.016,
    "edge_res": 0.0060,
}

C = (0.0, -0.012)        # door centre in front-view coordinates (x, v)
RX, RV = 0.093, 0.097    # door outline radii (front view)
Y0 = 0.058               # plate depth at the door centre (m in front of the eye plane)
DOME_R = 0.26            # vertical dome radius
RIM_IN = 0.083           # inner edge of the bolt-ring rim (fraction-free radius, front view)
DIAL_IN, DIAL_OUT = 0.057, 0.078
N_TICKS = 50
HUB = (0.0, -0.016)      # handle hub centre (x, v)
SPOKES = (90.0, -30.0, -150.0)
SPOKE_LEN = 0.036


class DoorSurface(mask.FaceSurface):
    """Constant-width cylinder (radius ``wrap_radius``) domed vertically: a door plate, no face."""

    def width(self, v: float) -> float:
        return self.W0

    def profile(self, v: float) -> float:
        return Y0 - (v - C[1]) ** 2 / (2 * DOME_R)

    def features(self, u: float, v: float) -> float:
        return self.extra(u, v) if self.extra is not None else 0.0


def _door(surf: mask.FaceSurface) -> mask.FaceSurface:
    return DoorSurface(surf.p, surf.extra)


R = PARAMS["wrap_radius"]


def to_uv(x: float, v: float) -> mask.Point2:
    """Front-view (x, v) -> design (u, v) on the door cylinder."""
    return (R * math.asin(max(-0.999, min(0.999, x / R))), v)


def loop_uv(loop: list[mask.Point2]) -> mask.Loop2:
    return [to_uv(x, v) for x, v in loop]


def polar(r: float, phi: float, c: mask.Point2 = C, sx: float = 1.0) -> mask.Point2:
    return (c[0] + r * sx * math.cos(phi), c[1] + r * math.sin(phi))


def ring_loop(r: float, n: int, c: mask.Point2 = C) -> mask.Loop2:
    return [polar(r, 2 * math.pi * i / n, c, RX / RV) for i in range(n)]


def _outline_fn(shape: mask.MaskShape) -> mask.Loop2:
    return mask.oriented(loop_uv([(C[0] + RX * math.cos(a), C[1] + RV * math.sin(a))
                                  for a in (2 * math.pi * i / 128 for i in range(128))]), True)


def _sculpt(u: float, v: float) -> float:
    # a shallow groove just inside the dial ring and a faint step round the hub
    x = R * math.sin(u / R)
    r = math.hypot((x - C[0]) * RV / RX, v - C[1])
    return -0.0010 * math.exp(-((r - 0.081) / 0.0018) ** 2)


# --- the rim -------------------------------------------------------------------------------------
def _rim(kit: mask.MaskKit) -> None:
    """Bolt-ring rim: a raised band round the edge with 16 hex bolt heads."""
    outer = mask.oriented(loop_uv([(C[0] + (RX + 0.002) * math.cos(a), C[1] + (RV + 0.002) * math.sin(a))
                                   for a in (2 * math.pi * i / 128 for i in range(128))]), True)
    inner = mask.oriented(loop_uv(ring_loop(RIM_IN, 96)), False)
    kit.plate(outer, holes=[inner], hi=0.0042, lo=-0.0040, chamfer=0.0014, edge_res=0.0065, res=0.03)
    rb = 0.5 * (RIM_IN + RV)
    for k in range(16):
        phi = 2 * math.pi * (k + 0.5) / 16
        cx, cv = polar(rb, phi, C, RX / RV)
        hexa = [(cx + 0.0034 * math.cos(phi + j * math.pi / 3), cv + 0.0034 * math.sin(phi + j * math.pi / 3))
                for j in range(6)]
        kit.plate(mask.oriented(loop_uv(hexa), True), hi=0.0074, lo=0.0030, chamfer=0.0008,
                  edge_res=0.02, res=0.03)


# --- the combination dial ------------------------------------------------------------------------
def _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int = 7) -> list[mask.Point2]:
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * k / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def _digit_strokes() -> dict[int, list]:
    """Digit strokes in a 0.6 x 1.0 box (y up); ("ring", cx, cy, rx, ry) is a closed oval."""
    return {
        0: [("ring", 0.30, 0.50, 0.27, 0.47)],
        1: [[(0.32, 0.0), (0.32, 1.0)], [(0.32, 1.0), (0.10, 0.80)]],
        2: [_arc(0.30, 0.72, 0.27, 0.26, 165, -35), [(0.53, 0.57), (0.02, 0.02)], [(0.0, 0.02), (0.60, 0.02)]],
        3: [_arc(0.30, 0.75, 0.25, 0.24, 160, -90), _arc(0.30, 0.27, 0.28, 0.26, 90, -160)],
        4: [[(0.46, 0.0), (0.46, 1.0)], [(0.44, 1.0), (0.02, 0.32)], [(0.0, 0.32), (0.60, 0.32)]],
        5: [[(0.56, 0.98), (0.10, 0.98)], [(0.10, 0.98), (0.07, 0.56)], _arc(0.30, 0.32, 0.28, 0.31, 135, -160)],
        6: [("ring", 0.30, 0.30, 0.27, 0.28), _arc(0.62, 0.30, 0.59, 0.68, 90, 172, 6)],
        7: [[(0.0, 0.98), (0.60, 0.98)], [(0.59, 0.98), (0.22, 0.0)]],
        8: [("ring", 0.30, 0.76, 0.23, 0.23), ("ring", 0.30, 0.27, 0.28, 0.27)],
        9: [("ring", 0.30, 0.70, 0.27, 0.28), _arc(-0.02, 0.70, 0.59, 0.68, -90, -8, 6)],
    }


def _digit_loops(d: int, centre: mask.Point2, up: tuple[float, float], h: float,
                 w: float) -> list[tuple[mask.Loop2, list[mask.Loop2]]]:
    """Plate loops (outline, holes) of digit ``d`` at ``centre``, its top toward ``up``."""
    rx, ry = (-up[1], up[0]), up  # the viewer's right is Blender -X: keep numerals unmirrored
    s = h

    def xf(p: mask.Point2) -> mask.Point2:
        lx, ly = (p[0] - 0.30) * s, (p[1] - 0.50) * s
        return (centre[0] + rx[0] * lx + ry[0] * ly, centre[1] + rx[1] * lx + ry[1] * ly)

    out = []
    for stroke in _digit_strokes()[d]:
        if isinstance(stroke, tuple) and stroke[0] == "ring":
            _k, cx, cy, ax, ay = stroke
            hw = 0.5 * w / s
            o = [xf((cx + (ax + hw) * math.cos(t), cy + (ay + hw) * math.sin(t)))
                 for t in (2 * math.pi * i / 16 for i in range(16))]
            i_ = [xf((cx + (ax - hw) * math.cos(t), cy + (ay - hw) * math.sin(t)))
                  for t in (2 * math.pi * i / 12 for i in range(12))]
            out.append((o, [i_]))
        else:
            pts = [xf(p) for p in stroke]
            if len(pts) == 2:  # a straight stroke: subdivide so the strip follows the dome
                pts = [(pts[0][0] + (pts[1][0] - pts[0][0]) * k / 3, pts[0][1] + (pts[1][1] - pts[0][1]) * k / 3)
                       for k in range(4)]
            out.append((mask.strip(pts, w, w), []))
    return out


def _dial(kit: mask.MaskKit) -> None:
    """The dial ring: a raised band with ticks, numerals and an index notch at the top."""
    band = mask.oriented(loop_uv(ring_loop(DIAL_OUT, 96)), True)
    hole = mask.oriented(loop_uv(ring_loop(DIAL_IN, 80)), False)
    kit.plate(band, holes=[hole], hi=0.0030, lo=-0.0030, chamfer=0.0010, edge_res=0.0065, res=0.03)
    sx = RX / RV
    for k in range(N_TICKS):
        phi = math.pi / 2 - 2 * math.pi * k / N_TICKS
        major = k % 5 == 0
        r0 = DIAL_OUT - (0.0085 if major else 0.0055)
        r1 = DIAL_OUT - 0.0018
        hw = 0.0007 if major else 0.00045
        t = (-math.sin(phi), math.cos(phi))
        a, b = polar(r0, phi, C, sx), polar(r1, phi, C, sx)
        quad = [(a[0] - t[0] * hw, a[1] - t[1] * hw), (b[0] - t[0] * hw, b[1] - t[1] * hw),
                (b[0] + t[0] * hw, b[1] + t[1] * hw), (a[0] + t[0] * hw, a[1] + t[1] * hw)]
        kit.plate(mask.oriented(loop_uv(quad), True), hi=0.0044, lo=0.0018, chamfer=0.0003,
                  edge_res=0.03, res=0.05)
        if major:
            num = k // 5
            c = polar(DIAL_IN + 0.0068, phi, C, sx)
            for o, hs in _digit_loops(num, c, (math.cos(phi), math.sin(phi)), 0.0100, 0.0013):
                kit.plate(mask.oriented(loop_uv(o), True), holes=[mask.oriented(loop_uv(h), False) for h in hs],
                          hi=0.0040, lo=0.0018, chamfer=0.0, edge_res=0.0011, res=0.05)
    # index notch: a small raised triangle above the dial pointing at 0
    tri = [(C[0], C[1] + DIAL_OUT + 0.0012), (C[0] - 0.0035, C[1] + RIM_IN - 0.0005),
           (C[0] + 0.0035, C[1] + RIM_IN - 0.0005)]
    kit.plate(mask.oriented(loop_uv(tri), True), hi=0.0036, lo=-0.002, chamfer=0.0006, edge_res=0.03, res=0.05)


# --- eyes and handle -----------------------------------------------------------------------------
def _portholes(kit: mask.MaskKit) -> None:
    """A raised round rim round each eye."""
    for side in (1, -1):
        eye = mask.oriented(kit.shape.eye_hole(side), True)
        cu = sum(p[0] for p in eye) / len(eye)
        cv = sum(p[1] for p in eye) / len(eye)
        r = 0.5 * float(kit.params["eye_width"])
        kit.plate(mask.oriented(mask.disc(cu, cv, r + 0.0045, 32), True),
                  holes=[mask.oriented(mask.disc(cu, cv, r + 0.0006, 28), False)],
                  hi=0.0034, chamfer=0.0012, edge_res=0.004)


def _handle(kit: mask.MaskKit) -> None:
    """Turned hub over the nose with three spokes ending in ball knobs."""
    surf = kit.surf
    m = kit.mat("primary")
    hu = to_uv(*HUB)
    c = surf.point(hu[0], hu[1], -0.002)
    nrm = surf.normal(*hu)
    prof = [(0.0170, 0.0), (0.0170, 0.0030), (0.0150, 0.0050), (0.0120, 0.0060), (0.0110, 0.0110),
            (0.0125, 0.0125), (0.0125, 0.0160), (0.0105, 0.0180), (0.0060, 0.0192), (0.0, 0.0195)]
    mask.lathe(kit.mb, c, nrm, prof, m, n=22)
    for deg in SPOKES:
        phi = math.radians(deg)
        pts = []
        for k in range(7):
            s = k / 6
            x, v = HUB[0] + SPOKE_LEN * s * math.cos(phi), HUB[1] + SPOKE_LEN * s * math.sin(phi)
            q = to_uv(x, v)
            lift = 0.0140 - 0.0035 * s
            pts.append(surf.point(q[0], q[1], lift))
        mask.tube(kit.mb, pts, lambda s: 0.0034 - 0.0008 * s, m, n=10, tip=False)
        mask.sphere(kit.mb, pts[-1], 0.0050, m, n=12, rings=6, axis=nrm)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_rim, _dial, _portholes, _handle],
                    surface_extra=_sculpt, outline_fn=_outline_fn, uv_mode="front", surface_wrap=_door)
