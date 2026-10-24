"""Vinyl customisable base mask (``mask_base.vinyl``, D-165 Afterhours reward: "Dead Air").

An original club mask: the face is a round, almost flat record. Concentric groove rings run round the
centre (clipped around the eye holes and inside the edge), a raised outer lip rims the disc, and a
round centre label with its spindle ring sits on the nose bridge below the eyes. Round eye holes, no
mouth. The round flat silhouette and the rings are the read at distance; the label is a clean canvas
for a pattern's colour B.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_vinyl"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.098,
    "bottom": -0.110,
    "side_arc": 0.104,
    "jaw_taper": 0.05,
    "brow": 0.15,
    "cheek": 0.30,
    "nose": 0.15,
    "jaw": 0.5,
    "eye_shape": "round",
    "eye_width": 0.030,
    "eye_height": 0.020,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "res": 0.0110,
    "res_back": 0.020,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.030)        # the record's centre: the nose bridge, below the eyes
LABEL_R = 0.019               # centre label radius
SPINDLE = (0.0025, 0.0045)    # spindle ring inner / outer radius
GROOVES = [0.026 + 0.0075 * i for i in range(9)]   # groove ring radii from the centre (m)
GROOVE_W = 0.0024
EYE_CLEAR = 0.005             # grooves stop this far from an eye hole
EDGE_CLEAR = 0.008            # and this far inside the outline (the lip sits there)
STEP_DEG = 7.5


def _clear(p: mask.Point2, outline: mask.Loop2, eyes: list[mask.Loop2]) -> bool:
    """A groove point is kept inside the outline (minus the lip) and away from both eye holes."""
    if not _inside(p, outline):
        return False
    return all(not mask.point_in_loop(p, e) for e in eyes)


def _inside(p: mask.Point2, outline: mask.Loop2) -> bool:
    phi = math.atan2(p[1] - CENTRE[1], p[0] - CENTRE[0])
    return math.dist(p, CENTRE) < mask.ray_radius(CENTRE, phi, outline) - EDGE_CLEAR


def _ring_pt(r: float, i: int) -> mask.Point2:
    a = math.radians(STEP_DEG * i)
    return (CENTRE[0] + r * math.cos(a), CENTRE[1] + r * math.sin(a))


def _grooves(kit: mask.MaskKit) -> None:
    """Concentric groove arcs: each ring sampled every STEP_DEG, cut into runs where it is clear."""
    outline = kit.shape.outline()
    eyes = [mask.offset_loop(mask.oriented(kit.shape.eye_hole(s), True), -EYE_CLEAR) for s in (-1, 1)]
    n = int(360.0 / STEP_DEG)
    for r in GROOVES:
        pts = [_ring_pt(r, i) for i in range(n)]
        keep = [_clear(p, outline, eyes) for p in pts]
        if all(keep):
            outer = [_ring_pt(r + GROOVE_W / 2, i) for i in range(n)]
            inner = mask.oriented([_ring_pt(r - GROOVE_W / 2, i) for i in range(n)], False)
            kit.plate(mask.oriented(outer, True), hi=0.0030, chamfer=0.0, holes=[inner], edge_res=0.004)
            continue
        start = keep.index(False)               # walk the ring from a cut so every run is contiguous
        run: list[mask.Point2] = []
        for i in range(1, n + 1):
            j = (start + i) % n
            if keep[j]:
                run.append(pts[j])
            if (not keep[j] or i == n) and run:
                if len(run) >= 4:
                    kit.plate(mask.resample(mask.strip(run, GROOVE_W, GROOVE_W), 0.006), hi=0.0030,
                              chamfer=0.0, edge_res=0.003)
                run = []


def _lip(kit: mask.MaskKit) -> None:
    """The record's raised outer lip, just inside the shell edge."""
    outline = kit.shape.outline()
    outer = mask.offset_loop(mask.oriented(outline, True), 0.0015)
    inner = mask.offset_loop(mask.oriented(outline, True), 0.0065)
    kit.plate(outer, hi=0.0016, chamfer=0.0006, holes=[mask.oriented(inner, False)], edge_res=0.008)


def _label(kit: mask.MaskKit) -> None:
    """Centre label (raised disc) and the spindle ring on it."""
    kit.plate(mask.disc(CENTRE[0], CENTRE[1], LABEL_R, 40), hi=0.0030, chamfer=0.0008, edge_res=0.003)
    ring_out = mask.disc(CENTRE[0], CENTRE[1], SPINDLE[1], 20)
    ring_in = mask.oriented(mask.disc(CENTRE[0], CENTRE[1], SPINDLE[0], 20), False)
    kit.plate(ring_out, hi=0.0044, chamfer=0.0005, holes=[ring_in], edge_res=0.002)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_lip, _grooves, _label], uv_mode="front")
