"""Per-heister first-person sleeve variants of ``char_arms_fp`` (D2-03 follow-up). Pure math, no ``bpy``.

The crew heisters' ``fp_sleeve`` (``_crew_heisters.FP_SLEEVE``, copied into their SOURCE.txt) says what
their forearms wear; ``arms_fp_heisters.py`` builds one mesh-only asset per heister,
``char_arms_fp_<heister>``: the same ``rig_arms`` armature as ``char_arms_fp`` (identical bones,
rest pose and skin binds) and one skinned ``Arms`` mesh, no animations. ENV A swaps that mesh onto
``char_arms_fp``'s ``Arms`` node (mesh + skin), which keeps the single copy of the clips.

A variant is a stack of lofted layers along the arm (``Layer``), outermost last, plus the hands:

* gloved heisters: the hands of ``_arms.hand_part`` re-materialled with the glove and pushed out by
  ``GLOVE_INFLATE`` (glove-material hands: no skin under them), plus a short glove gauntlet;
* Wren: bare skin hands are not visible either (short tactical gloves), but her forearm is: the body's
  ``forearms`` region (body UVs, ``char_skin_<tone>``) under a pale-blue shirt sleeve rolled to the
  elbow (a double roll that tucks onto the skin).

Layers are lofted through the body's ``upper_arm, elbow, forearm, wrist`` rings (``_arms.arm_loops``)
with ``u`` = metres along the arm from the wrist ring (negative toward the shoulder, ``U_SHOULDER`` ~
-0.39 at the upper-arm ring), an ease profile (radial offset off the skin), optional knit ribs
(alternating columns at double ring resolution) or gathering pleats, and turned hems at the free ends.
Weights: ``_body.skin_weights`` against the side's upper_arm / forearm / hand bones (gloves: forearm /
hand only); sleeve verts within ``CUFF_FOREARM_U`` of the wrist follow the forearm (0.85 / 0.15
hand, like the generic cuff) so the hand turns inside the cuff.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

#: Glove leather thickness: the gloved hand verts move this far along their normals (metres).
GLOVE_INFLATE = 0.0008
#: Sleeve verts closer to the wrist than this (u > -CUFF_FOREARM_U) are weighted to the forearm.
CUFF_FOREARM_U = 0.035
#: Hem: how far the turned-in facing goes back inside the opening (metres).
HEM_DEPTH = 0.014


@dataclass(frozen=True)
class Layer:
    """One lofted tube. ``profile``: ``(u, ease[, pleat])`` control rows (u ascending; ease = metres off
    the skin ring; pleat = radial amplitude of ``pleats`` lobes). ``hems``: free ends with a turned
    edge, ``"start"`` (shoulder side, a glove's opening) and/or ``"end"`` (wrist side), ``hem``
    = edge thickness. ``ribs``: (columns, depth) knit rib (columns alternate +-depth / 2)."""

    mat: str
    profile: tuple
    hems: tuple = ()
    hem: float = 0.003
    ribs: tuple | None = None
    pleats: int = 0
    glove: bool = False


@dataclass(frozen=True)
class Variant:
    heister: str
    glove: str                 # glove material on the hands (every crew heister wears gloves)
    layers: tuple
    forearm_skin: bool = False  # Wren: the body's bare forearm region
    note: str = ""
    extra: dict = field(default_factory=dict)


U_SHOULDER = -0.389          # metres from the wrist ring to the upper-arm ring on the default rig (checked)

VARIANTS: dict[str, Variant] = {
    "rook": Variant(
        "rook", "char_leather_black",
        (
            Layer("char_leather_black", ((-0.035, 0.0035), (-0.02, 0.0032), (-0.008, 0.0030), (0.0, 0.0028)),
                  hems=("start",), hem=0.0015, glove=True),
            Layer("char_shirt_white", ((-0.062, 0.0075), (-0.045, 0.0078), (-0.03, 0.0080), (-0.020, 0.0080),
                                       (-0.013, 0.0080)), hems=("end",), hem=0.003),
            Layer("char_crew_rook_coat", ((U_SHOULDER, 0.020), (-0.33, 0.020), (-0.263, 0.019), (-0.21, 0.018),
                                          (-0.163, 0.0175), (-0.125, 0.017), (-0.096, 0.0165), (-0.090, 0.0185),
                                          (-0.060, 0.0185), (-0.030, 0.0185)), hems=("end",), hem=0.0045),
        ),
        note="charcoal overcoat sleeve with a turned-back cuff band, white shirt cuff showing 17 mm, black "
             "leather gloves with a short gauntlet"),
    "sable": Variant(
        "sable", "char_crew_glove_ivory",
        (
            Layer("char_crew_glove_ivory", ((-0.030, 0.0030), (-0.015, 0.0029), (0.0, 0.0027)),
                  hems=("start",), hem=0.0013, glove=True),
            Layer("char_knit_graphite", ((-0.062, 0.0062), (-0.045, 0.0062), (-0.030, 0.0060), (-0.020, 0.0060),
                                         (-0.012, 0.0060)), hems=("end",), hem=0.0022, ribs=(64, 0.0007)),
            Layer("char_crew_sable_blazer", ((U_SHOULDER, 0.014), (-0.30, 0.013), (-0.22, 0.012), (-0.163, 0.011),
                                             (-0.11, 0.0105), (-0.07, 0.0105), (-0.035, 0.0105)),
                  hems=("end",), hem=0.003),
        ),
        note="aubergine blazer sleeve, black roll-neck knit cuff (fine rib) showing 23 mm, ivory kid gloves"),
    "dutch": Variant(
        "dutch", "char_crew_glove_tan",
        (
            Layer("char_crew_glove_tan", ((-0.040, 0.0038), (-0.025, 0.0036), (-0.010, 0.0034), (0.0, 0.0032)),
                  hems=("start",), hem=0.0018, glove=True),
            Layer("char_knit_graphite", ((-0.072, 0.0075), (-0.060, 0.0080), (-0.046, 0.0085), (-0.032, 0.0087),
                                         (-0.020, 0.0085), (-0.012, 0.0080), (-0.007, 0.0075)),
                  hems=("end",), hem=0.003, ribs=(64, 0.0026)),
            Layer("char_crew_dutch_bomber", ((U_SHOULDER, 0.024, 0.0), (-0.30, 0.023, 0.0), (-0.22, 0.022, 0.0),
                                             (-0.163, 0.021, 0.0), (-0.11, 0.021, 0.0005), (-0.080, 0.0225, 0.0015),
                                             (-0.064, 0.0215, 0.0025), (-0.056, 0.017, 0.002), (-0.050, 0.012, 0.001)),
                  hems=("end",), hem=0.003, pleats=7),
        ),
        note="brown leather bomber sleeve gathered (7 pleats) into a ribbed graphite knit cuff (32 ribs), tan "
             "work gloves"),
    "marten": Variant(
        "marten", "char_crew_glove_orange",
        (
            Layer("char_crew_glove_orange", ((-0.042, 0.0040), (-0.026, 0.0038), (-0.010, 0.0035), (0.0, 0.0032)),
                  hems=("start",), hem=0.0018, glove=True),
            Layer("char_crew_marten_parka", ((-0.050, 0.0120), (-0.040, 0.0125), (-0.030, 0.0125), (-0.022, 0.0120),
                                             (-0.016, 0.0115)),
                  hems=("end",), hem=0.004),
            Layer("char_crew_marten_parka", ((U_SHOULDER, 0.026, 0.0), (-0.30, 0.025, 0.0), (-0.22, 0.024, 0.0),
                                             (-0.15, 0.023, 0.0008), (-0.095, 0.0235, 0.0018), (-0.068, 0.0225, 0.0024),
                                             (-0.056, 0.019, 0.002), (-0.048, 0.016, 0.001)),
                  hems=("end",), hem=0.003, pleats=6),
        ),
        note="roomy olive parka sleeve gathered (6 pleats) into a plain parka cuff band, burnt-orange gloves"),
    "jay": Variant(
        "jay", "char_crew_glove_driving",
        (
            Layer("char_crew_glove_driving", ((-0.034, 0.0034), (-0.020, 0.0032), (-0.008, 0.0030), (0.0, 0.0028)),
                  hems=("start",), hem=0.0016, glove=True),
            Layer("char_crew_jay_jacket", ((-0.046, 0.0080), (-0.036, 0.0084), (-0.026, 0.0084), (-0.018, 0.0080),
                                           (-0.012, 0.0076)),
                  hems=("end",), hem=0.003, ribs=(48, 0.0018)),
            Layer("char_crew_jay_jacket", ((U_SHOULDER, 0.013, 0.0), (-0.30, 0.012, 0.0), (-0.22, 0.011, 0.0),
                                           (-0.15, 0.0105, 0.0), (-0.090, 0.0105, 0.0004), (-0.060, 0.0100, 0.0008),
                                           (-0.048, 0.0090, 0.0006)),
                  hems=("end",), hem=0.0025, pleats=4),
        ),
        note="slim cobalt racing-jacket sleeve (white stripes on the body only: they run down the outside of the "
             "upper arm, off screen in first person) into a ribbed cuff, cognac driving gloves"),
    "juno": Variant(
        "juno", "char_crew_glove_suede",
        (
            Layer("char_crew_glove_suede", ((-0.036, 0.0034), (-0.022, 0.0032), (-0.009, 0.0030), (0.0, 0.0028)),
                  hems=("start",), hem=0.0016, glove=True),
            Layer("char_crew_juno_jacket", ((-0.044, 0.0072), (-0.034, 0.0075), (-0.024, 0.0075), (-0.016, 0.0072),
                                            (-0.011, 0.0068)),
                  hems=("end",), hem=0.0028),
            Layer("char_crew_juno_jacket", ((U_SHOULDER, 0.012, 0.0), (-0.30, 0.011, 0.0), (-0.22, 0.010, 0.0),
                                            (-0.15, 0.0095, 0.0), (-0.090, 0.0095, 0.0003), (-0.060, 0.0092, 0.0006),
                                            (-0.046, 0.0084, 0.0004)),
                  hems=("end",), hem=0.0025, pleats=3),
        ),
        note="fitted emerald leather moto sleeve into a plain leather cuff, grey suede gloves"),
    "hale": Variant(
        "hale", "char_crew_glove_work",
        (
            Layer("char_crew_glove_work", ((-0.056, 0.0046), (-0.040, 0.0044), (-0.024, 0.0040), (-0.010, 0.0036),
                                           (0.0, 0.0033)),
                  hems=("start",), hem=0.0020, glove=True),
            Layer("char_crew_hale_jacket", ((-0.062, 0.0140), (-0.052, 0.0145), (-0.042, 0.0145), (-0.034, 0.0140),
                                            (-0.028, 0.0134)),
                  hems=("end",), hem=0.004),
            Layer("char_crew_hale_jacket", ((U_SHOULDER, 0.024, 0.0), (-0.30, 0.023, 0.0), (-0.22, 0.022, 0.0),
                                            (-0.15, 0.021, 0.0006), (-0.10, 0.021, 0.0014), (-0.076, 0.020, 0.0018),
                                            (-0.066, 0.018, 0.0014), (-0.060, 0.016, 0.0008)),
                  hems=("end",), hem=0.003, pleats=5),
        ),
        note="boxy sand canvas chore-jacket sleeve into a plain cuff band, long-gauntlet yellow work gloves"),
    "wren": Variant(
        "wren", "char_crew_glove_sage",
        (
            Layer("char_crew_glove_sage", ((-0.020, 0.0030), (-0.010, 0.0029), (0.0, 0.0027)),
                  hems=("start",), hem=0.0013, glove=True),
            Layer("char_crew_glove_sage", ((-0.017, 0.0046), (-0.011, 0.0049), (-0.005, 0.0049)),
                  hems=("start", "end"), hem=0.0016, glove=True),
            Layer("char_shirt_blue", ((U_SHOULDER, 0.012), (-0.35, 0.012), (-0.31, 0.011), (-0.275, 0.011),
                                      (-0.268, 0.013), (-0.258, 0.017), (-0.248, 0.016), (-0.241, 0.012),
                                      (-0.236, 0.013), (-0.226, 0.016), (-0.216, 0.014), (-0.210, 0.009),
                                      (-0.206, 0.004), (-0.204, 0.0012))),
        ),
        forearm_skin=True,
        note="pale-blue shirt sleeve rolled to just below the elbow (double roll tucked onto the skin), bare "
             "forearm (body forearm region, skin tone of the variant), short sage tactical gloves with a strap"),
}


# -- sections ---------------------------------------------------------------------------------
class Arm:
    """Sections of one side's arm: ``section(u)`` -> (32 ring points, centre, axis)."""

    def __init__(self, loops: list):
        self.loops = [np.array(lp, float) for lp in loops]
        self.cen = [lp.mean(axis=0) for lp in self.loops]
        d = [float(np.linalg.norm(self.cen[i + 1] - self.cen[i])) for i in range(len(self.cen) - 1)]
        acc = [0.0]
        for x in reversed(d):
            acc.insert(0, acc[0] - x)
        self.us = acc                                   # [upper_arm, elbow, forearm, wrist] -> [-.., 0]
        ax = self.cen[-1] - self.cen[-2]
        self.wrist_axis = ax / np.linalg.norm(ax)

    def section(self, u: float) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        us = self.us
        if u >= 0.0:
            return self.loops[-1] + self.wrist_axis * u, self.cen[-1] + self.wrist_axis * u, self.wrist_axis
        i = max(0, min(len(us) - 2, int(np.searchsorted(us, u, side="right")) - 1))
        t = (u - us[i]) / (us[i + 1] - us[i])
        pts = self.loops[i] * (1.0 - t) + self.loops[i + 1] * t
        cen = self.cen[i] * (1.0 - t) + self.cen[i + 1] * t
        ax = self.cen[i + 1] - self.cen[i]
        return pts, cen, ax / np.linalg.norm(ax)


def _resample(pts: np.ndarray, n: int) -> np.ndarray:
    """Closed loop of ``len(pts)`` points -> ``n`` (a multiple), linear in between."""
    m = len(pts)
    if n == m:
        return pts
    k = n // m
    out = []
    for i in range(m):
        a, b = pts[i], pts[(i + 1) % m]
        for j in range(k):
            out.append(a + (b - a) * (j / k))
    return np.array(out)


def _ring(arm: Arm, u: float, ease: float, layer: Layer, pleat: float = 0.0) -> tuple[list, np.ndarray]:
    pts, cen, _ax = arm.section(u)
    n = layer.ribs[0] if layer.ribs else len(pts)
    pts = _resample(pts, n)
    out = []
    for j, q in enumerate(pts):
        d = q - cen
        r = float(np.linalg.norm(d))
        dirv = d / r if r > 1e-9 else d
        off = ease
        if layer.ribs:
            off += layer.ribs[1] * (0.5 if j % 2 == 0 else -0.5)
        if layer.pleats and pleat:
            off += pleat * float(np.cos(2.0 * np.pi * layer.pleats * j / n))
        out.append(q + dirv * off)
    return out, cen


def loft(arm: Arm, layer: Layer) -> dict:
    """Loops (each a list of points) + per-loop (u, centre) + per-row kind (out / end / in) + axis signs."""
    prof = [tuple(r) + (0.0,) * (3 - len(r)) for r in layer.profile]
    loops, meta = [], []
    for u, e, pl in prof:
        pts, cen = _ring(arm, u, e, layer, pl)
        loops.append(pts)
        meta.append((u, cen))
    kinds = ["out"] * (len(loops) - 1)
    signs = [0.0] * (len(loops) - 1)
    t = layer.hem
    if "end" in layer.hems:
        u, e, pl = prof[-1]
        for du, de in ((t * 0.6, -t * 0.5), (-HEM_DEPTH, -t)):
            pts, cen = _ring(arm, u + du, e + de, layer, pl)
            loops.append(pts)
            meta.append((u, cen))
        kinds += ["end", "in"]
        signs += [1.0, 0.0]
    if "start" in layer.hems:
        u, e, pl = prof[0]
        for du, de in ((-t * 0.6, -t * 0.5), (HEM_DEPTH, -t)):
            pts, cen = _ring(arm, u + du, e + de, layer, pl)
            loops.insert(0, pts)
            meta.insert(0, (u, cen))
        kinds = ["in", "end"] + kinds
        signs = [0.0, -1.0] + signs
    return {"loops": loops, "meta": meta, "kinds": kinds, "signs": signs}


def _quads(verts: list, base: int, n: int, nl: int, kinds: list, signs: list, meta: list, axis: np.ndarray) -> list:
    faces = []
    for li in range(nl - 1):
        cmid = (meta[li][1] + meta[li + 1][1]) * 0.5
        for j in range(n):
            a = base + li * n + j
            b = base + li * n + (j + 1) % n
            c = base + (li + 1) * n + (j + 1) % n
            d = base + (li + 1) * n + j
            fa = np.array(verts[a])
            nrm = np.cross(np.array(verts[b]) - fa, np.array(verts[d]) - fa)
            if kinds[li] == "end":
                want = float(nrm @ axis) * signs[li]
            elif kinds[li] == "in":
                want = -float(nrm @ (fa - cmid))
            else:
                want = float(nrm @ (fa - cmid))
            faces.append((a, b, c, d) if want >= 0.0 else (d, c, b, a))
    return faces


def _vertex_normals(verts: np.ndarray, faces: list) -> np.ndarray:
    nrm = np.zeros_like(verts)
    for f in faces:
        p = verts[list(f)]
        fn = np.zeros(3)
        for i in range(len(f)):                         # Newell
            a, b = p[i], p[(i + 1) % len(f)]
            fn += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]),
                            (a[0] - b[0]) * (a[1] + b[1])])
        for v in f:
            nrm[v] += fn
    ln = np.linalg.norm(nrm, axis=1)
    ln[ln < 1e-12] = 1.0
    return nrm / ln[:, None]


def forearm_part(params: dict) -> dict:
    """The body's ``forearms`` region (cage resolution, body UVs, body weights) in humanoid space."""
    import _arms as F  # noqa: PLC0415
    import _body as body  # noqa: PLC0415

    p = body.body_params(params, hide=frozenset(r for r in body.REGIONS if r != "forearms"))
    data, _hair = body.body_mesh_data(p)
    ws = [F._top4(w) for w in body.body_weights(data)]
    uvs = body.face_uvs(data.faces, data.face_region, data.face_mat, data.face_side, data.blend, float(p["height"]))
    return {"verts": [tuple(v) for v in data.blend], "faces": [tuple(f) for f in data.faces],
            "uvs": list(uvs), "weights": ws}


def variant_data(params: dict) -> dict:
    """Pure-math ``Arms`` mesh of ``params["heister"]`` (the ``_arms.hands_data`` layout + ``slots``:
    ordered {material key: library id}; keys are the library ids)."""
    import _arms as F  # noqa: PLC0415
    import _body as body  # noqa: PLC0415
    import _rig as rig  # noqa: PLC0415

    v = VARIANTS[str(params["heister"])]
    params = {k: x for k, x in params.items() if k != "heister"}        # the rest are body params
    skin_id = int(body.body_params(params)["skin"])
    skin = f"char_skin_{skin_id}"
    hp = F.hand_part(params)
    hv = np.array(hp["verts"], float)
    hv = hv + _vertex_normals(hv, hp["faces"]) * GLOVE_INFLATE
    verts = [tuple(float(c) for c in q) for q in hv]
    faces = list(hp["faces"])
    mats = [v.glove] * len(faces)
    uvs: list = [None] * len(faces)
    weights = list(hp["weights"])
    height = float(hp["height"])
    if v.forearm_skin:
        fp = forearm_part(params)
        base = len(verts)
        verts.extend(fp["verts"])
        faces.extend(tuple(base + i for i in f) for f in fp["faces"])
        mats.extend([skin] * len(fp["faces"]))
        uvs.extend(fp["uvs"])
        weights.extend(fp["weights"])
    arms = F.arm_loops(params, slim=not v.forearm_skin)
    for sfx, _sx in rig.SIDES:
        arm = Arm(arms[sfx])
        if abs(arm.us[0] - U_SHOULDER) > 0.01:
            raise AssertionError(f"upper-arm ring at u={arm.us[0]:.3f}, U_SHOULDER={U_SHOULDER}")
        for layer in v.layers:
            lo = loft(arm, layer)
            loops = lo["loops"]
            n = len(loops[0])
            base = len(verts)
            for lp in loops:
                verts.extend(tuple(float(c) for c in q) for q in lp)
            lf = _quads(verts, base, n, len(loops), lo["kinds"], lo["signs"], lo["meta"], arm.wrist_axis)
            faces.extend(lf)
            mats.extend([layer.mat] * len(lf))
            uvs.extend([None] * len(lf))
            pts = [verts[base + i] for i in range(len(loops) * n)]
            bones = ([f"forearm.{sfx}", f"hand.{sfx}"] if layer.glove
                     else [f"upper_arm.{sfx}", f"forearm.{sfx}", f"hand.{sfx}"])
            ws = body.skin_weights(pts, height, [bones] * len(pts))
            for li in range(len(loops)):
                u = lo["meta"][li][0]
                for j in range(n):
                    i = li * n + j
                    if not layer.glove and u > -CUFF_FOREARM_U:
                        ws[i] = {f"forearm.{sfx}": 0.85, f"hand.{sfx}": 0.15}
            weights.extend(F._top4(w) for w in ws)
    slots: dict = {}
    for m in mats:
        slots.setdefault(m, m)
    return {"verts": verts, "faces": faces, "mats": mats, "uvs": uvs, "weights": weights, "height": height,
            "slots": slots, "note": v.note}
