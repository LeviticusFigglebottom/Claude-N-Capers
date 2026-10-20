"""Law-enforcement faction reskins (D2-01, pd2_fidelity L1.5, groups.md QA-29). Blender only.

Private helper (``_`` prefix). The police and special scripts (``char_police.py``,
``char_specials.py``) declare, next to every base character ``char_<id>`` (= faction ``tac``, the
default look), the variants ``char_<id>_<variant>`` for ``variant`` in ``frd``, ``sentinel`` and
``zero`` (the ``EnemyDef.params.visual_variant`` values of ENV A's faction EnemyDefs). A variant runs
the base recipe unchanged and then ``dress(kit)``:

1. **insignia** (original designs, geometry cast onto the outfit / helmet as raised patches):

   * ``frd`` (PD2 FBI analogue, "federal"): olive uniform, coyote carrier, olive-grey helmet,
     gold-yellow block letters **FRD** (an original acronym) across the back and the left chest, small
     on the helmet sides, and gold-bordered olive arm patches carrying FRD.
   * ``sentinel`` (GenSec analogue, corporate PMC): slate-grey uniform, light-grey carrier, crisp
     off-white helmet and armour, the Sentinel Corp logo: a crimson hexagon crossed by a white
     "watch-slit" bar with a crimson hexagonal pupil (back, chest, helmet sides, arm patches with a
     white border).
   * ``zero`` (ZEAL analogue, heaviest tier): black uniform and carrier, gloss-black armour, the Zero
     Division mark (a bone disc, an oxblood centre and a bone slash, i.e. a slashed zero) on back,
     chest and helmet; **silhouette**: every helmeted unit wears a bone-coloured, skull-like ballistic
     face mask (dark lens eye sockets, nose and mouth vents) under the helmet rim, the Light gets the
     Heavy's pauldrons, and the Wrecker's faceplate turns bone (the "skull" Wrecker) keeping its
     hazard-yellow rim. D-067: the Phantom gets a bone skull lower-face guard under the NVG (``zero_jaw``;
     the glowing Goggles stay the dominant silhouette), oxblood harness straps and a bigger back mark;
     the Longshot the full skull mask under a black boonie with an oxblood band, the mark on the boonie
     front and on the drag bag.

   The FRD field agent (``char_police.frd_agent``, FRD-only role) stamps its own marks with
   ``torso_mark`` (FRD letters; its Sentinel reskin the Sentinel logo); ``dress`` only recolours/tags it.

2. **material remap** of every mesh (``REMAP``): the TAC / police / special base ids become the
   faction's ids from ``_outfit_palette`` (``char_frd_*``, ``char_sen_*``, ``char_zero_*``). Special
   identity colours stay (Stinger blue, Corpsman white + mark, Phantom green lenses, Wrecker hazard
   yellow) and so do the special contract nodes (``Faceplate`` / ``Visor`` / ``HeadArmored``,
   ``Goggles`` + override, ``LaserOrigin``): the base recipe makes them, ``dress`` only recolours.

3. SOURCE.txt keys ``variant_of: <base character id>`` and ``visual_variant: <variant>``, which the
   assembly copies into ``world/characters/characters.json`` (``variant_of`` / ``variant``).

Scene convention for ENV A (proposed in the D2-01 report): ``res://world/characters/<id>_<variant>/
<id>_<variant>.tscn`` for ``visual_variant`` ``frd|sentinel|zero``; ``tac`` (or no variant) is the base
``<id>``. A Bulwark's shield lives beside it: ``<id>_<variant>/<id>_<variant>_shield.tscn``.
"""

from __future__ import annotations

import math

import _outfit as o
import _special_gear as sg
from _outfit import Hull, Mesh, Vector
from _special_shield import GLYPHS

FACTIONS = ("frd", "sentinel", "zero")

REMAP: dict[str, dict[str, str]] = {
    "frd": {
        "char_tac_charcoal": "char_frd_olive", "char_tac_gear": "char_frd_coyote", "char_tac_helmet": "char_frd_helmet",
        "char_police_navy": "char_frd_olive", "char_police_shirt": "char_chino_khaki", "char_hivis": "char_frd_yellow",
        "char_armor_black": "char_frd_armor", "char_wrecker_suit": "char_frd_olive", "char_phantom_suit": "char_frd_dark",
        "char_sniper_drab": "char_frd_coyote",
    },
    "sentinel": {
        "char_tac_charcoal": "char_sen_grey", "char_tac_gear": "char_sen_light", "char_tac_helmet": "char_sen_white",
        "char_police_navy": "char_sen_grey", "char_police_shirt": "char_shirt_white", "char_hivis": "char_sen_red",
        "char_armor_black": "char_sen_white", "char_wrecker_suit": "char_sen_grey", "char_phantom_suit": "char_sen_dark",
        "char_sniper_drab": "char_sen_light",
    },
    "zero": {
        "char_tac_charcoal": "char_zero_black", "char_tac_gear": "char_zero_gear", "char_tac_helmet": "char_zero_armor",
        "char_police_navy": "char_zero_black", "char_police_shirt": "char_shirt_black", "char_hivis": "char_zero_red",
        "char_armor_black": "char_zero_armor", "char_wrecker_suit": "char_zero_black", "char_phantom_suit": "char_zero_black",
        "char_sniper_drab": "char_zero_gear",
    },
}

#: arm patch (border, fill) per faction
PATCH = {"frd": ("char_frd_yellow", "char_frd_olive"), "sentinel": ("char_sen_white", "char_sen_grey"),
         "zero": ("char_zero_red", "char_zero_black")}

#: Wrecker faceplate body per faction (the hazard-yellow rim and eye slit stay)
FACEPLATE = {"zero": {"char_armor_black": "char_zero_bone"}}

#: insignia sites per base unit: back / chest marks, arm patch position along the upper arm (0 =
#: shoulder, None = none: pauldrons, cables or armbands there), helmet side decals, zero face mask
SITES: dict[str, dict] = {
    "patrol": {"back": 1.30, "chest": None, "arm": 0.30, "helmet": False, "mask": False},
    "tac": {"back": 1.31, "chest": 1.36, "arm": 0.30, "helmet": True, "mask": True},
    "tac_heavy": {"back": 1.31, "chest": 1.36, "arm": None, "helmet": True, "mask": True},
    "phantom": {"back": 1.30, "chest": None, "arm": 0.30, "helmet": False, "mask": False},
    "stinger": {"back": None, "chest": None, "arm": None, "helmet": True, "mask": True},
    "bulwark": {"back": 1.31, "chest": 1.36, "arm": None, "helmet": True, "mask": False},
    "wrecker": {"back": 1.28, "chest": None, "arm": None, "helmet": False, "mask": False},
    "longshot": {"back": None, "chest": None, "arm": 0.30, "helmet": False, "mask": False},
    "corpsman": {"back": None, "chest": 1.36, "arm": 0.20, "helmet": False, "mask": True},
    # the FRD field agent's recipe stamps its own marks (FRD letters; the Sentinel reskin its logo)
    "frd_agent": {"back": None, "chest": None, "arm": None, "helmet": False, "mask": False},
}

#: Zero back-mark size per unit where it differs from the default 0.12 (bigger on the Phantom)
ZERO_BACK = {"phantom": 0.17}

Item = tuple[list[tuple[float, float]], str, float]   # (outline in the emblem plane, material, lift)


# =============================================================================================
# emblem designs: levels of conforming raised patches (each level is cast onto the previous one)
# =============================================================================================
def _rect(x0: float, y0: float, x1: float, y1: float) -> list[tuple[float, float]]:
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def _ngon(r: float, n: int, rot: float = 0.0, cx: float = 0.0, cy: float = 0.0) -> list[tuple[float, float]]:
    return [(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + r * math.sin(rot + 2 * math.pi * i / n))
            for i in range(n)]


def letters(word: str, h: float, mat: str, lift: float = 0.0022) -> list[Item]:
    """Block letters (the shield glyphs, 3 x 5 units) ``h`` tall, centred on the origin."""
    u = h / 5.0
    n = len(word)
    x0 = -(n * 3 + n - 1) * u / 2
    out: list[Item] = []
    for ci, ch in enumerate(word):
        gx = x0 + ci * 4 * u
        for a, b, c, d in GLYPHS[ch]:
            out.append((_rect(gx + a * u, -h / 2 + b * u, gx + c * u, -h / 2 + d * u), mat, lift))
    return out


def mark(faction: str, h: float) -> list[list[Item]]:
    """The faction's emblem ``h`` tall as levels of patches."""
    if faction == "frd":
        return [letters("FRD", h, "char_frd_yellow")]
    r = h / 2
    if faction == "sentinel":
        return [[(_ngon(r, 6, math.pi / 6), "char_sen_red", 0.0022)],
                [(_rect(-0.66 * r, -0.13 * r, 0.66 * r, 0.13 * r), "char_sen_white", 0.0012)],
                [(_ngon(0.27 * r, 6, math.pi / 6), "char_sen_red", 0.0010)]]
    # zero: slashed zero
    c45, s45 = math.cos(math.radians(50.0)), math.sin(math.radians(50.0))
    bar = [(x * c45 - y * s45, x * s45 + y * c45) for x, y in _rect(-0.92 * r, -0.12 * r, 0.92 * r, 0.12 * r)]
    return [[(_ngon(r, 12), "char_zero_bone", 0.0022)],
            [(_ngon(0.68 * r, 12), "char_zero_red", 0.0010)],
            [(bar, "char_zero_bone", 0.0010)]]


def arm_patch(faction: str, w: float, h: float) -> list[list[Item]]:
    border, fill = PATCH[faction]
    base = [[(o.rounded_rect(w, h, 0.18 * w, 1), border, 0.0020)],
            [(o.rounded_rect(0.80 * w, 0.80 * h, 0.14 * w, 1), fill, 0.0010)]]
    return base + mark(faction, 0.50 * h)


def stamp(m: Mesh, hull_of, origin: Vector, toward: Vector, up: Vector, levels: list[list[Item]],
          weights: dict | None = None, anchor: Vector | None = None) -> None:
    """Cast the emblem ``levels`` onto ``hull_of(m)`` around ``origin`` facing ``toward`` (text up =
    ``up``, reading left to right for a viewer looking along ``-toward``)."""
    z = toward.normalized()
    v = (up - z * up.dot(z)).normalized()
    u = (-z).cross(v).normalized()           # viewer's right
    for level in levels:
        hull = hull_of(m)
        for outline, mat, lift in level:
            o.patch(m, hull, origin + z * 0.06, u, v, outline, lift, mat, cast_dir=-z, rings=0, chamfer=0.0006,
                    sink=0.0012, weights=weights, anchor=anchor)


# =============================================================================================
# sites
# =============================================================================================
def _torso(kit, faction: str, z: float, front: bool, h: float) -> None:
    fit, k = kit.fit, kit.k
    cy = fit.ring_centre("chest").y
    sgn = 1.0 if front else -1.0
    x = -0.112 * k if front else 0.0
    target = Vector((x, cy + sgn * 0.3, z * k))
    hit = kit.hull().cast(target, Vector((0.0, -sgn, 0.0)), 0.6)
    anchor = hit[0] if hit[0] is not None else Vector((x, cy + sgn * 0.12, z * k))
    m = Mesh()
    stamp(m, kit.hull, anchor, Vector((0.0, sgn, 0.0)), o.UP, mark(faction, h * k), anchor=anchor)
    kit.add_gear(m)


torso_mark = _torso


def _arms(kit, faction: str, t: float) -> None:
    fit, k = kit.fit, kit.k
    m = Mesh()
    for sx in (-1.0, 1.0):
        sh = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        el = Vector(fit.J["elbow.R" if sx > 0 else "elbow.L"])
        p = sh.lerp(el, t)
        axis = (sh - el).normalized()
        out = Vector((sx, 0.0, 0.0))
        out = (out - axis * out.dot(axis)).normalized()
        hit = kit.hull(m).cast(p + out * 0.3, -out, 0.3)
        anchor = hit[0] if hit[0] is not None else p + out * 0.05
        stamp(m, kit.hull, anchor, out, axis, arm_patch(faction, 0.068 * k, 0.074 * k), anchor=anchor)
    kit.add_gear(m)


def _helmet(kit, faction: str) -> None:
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    m = Mesh()

    def hull_of(extra: Mesh) -> Hull:
        return Hull(fit, [kit.head, extra], body_regions=set())

    h = (0.024 if faction == "frd" else 0.036) * k
    for az in (math.radians(-118.0), math.radians(118.0)):
        d = Vector((math.sin(az), math.cos(az), 0.0))
        zz = eye.z + 0.095 * k
        hit = hull_of(m).cast(Vector((c.x, c.y, zz)) + d * 0.4, -d, 0.4)
        p = hit[0] if hit[0] is not None else Vector((c.x, c.y, zz)) + d * 0.13
        stamp(m, hull_of, p, d, o.UP, mark(faction, h), weights=sg.HEAD_W)
    kit.add_head(m)


def zero_mask(kit) -> None:
    """Bone ballistic face mask (skull-like: dark lens sockets, nose and mouth vents) under the helmet
    rim, 100 % head. Original design."""
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    z0, z1 = eye.z - 0.150 * k, eye.z + 0.028 * k
    a0 = math.radians(52.0)
    fr = max(sg.face_radius(fit, a, z, c) for a in [math.radians(x) for x in range(-50, 51, 10)]
             for z in [o.lerp(z0 + 0.02 * k, z1, t / 6) for t in range(7)])

    def r_fn(az: float, z: float) -> float:
        # jaw tapers in below the mouth, cheeks wrap back towards the sides
        jaw = 0.10 * max(0.0, (eye.z - 0.10 * k) - z)
        return fr + 0.013 * k - jaw - 0.012 * k * (az / a0) ** 2

    def mat(u: float, v: float) -> str:
        if 0.60 < v < 0.84 and (0.16 < u < 0.42 or 0.58 < u < 0.84):
            return "char_lens"                                        # eye sockets
        if 0.44 < v < 0.56 and 0.44 < u < 0.56:
            return "polymer_black"                                    # nose vent
        if 0.12 < v < 0.32 and 0.30 < u < 0.70 and int(u * 14) % 2 == 0:
            return "polymer_black"                                    # mouth vents (teeth)
        return "char_zero_bone"

    kit.add_head(sg.curved_panel(c, -a0, a0, z0, z1, r_fn, 0.006 * k, mat, nu=14, nv=9, side_mat="char_zero_bone"))
    kit.notes["faction_mask"] = "zero: bone face mask under the helmet rim (Headwear)"


def zero_jaw(kit) -> None:
    """Phantom (Zero): a bone, skull-like lower-face guard over the balaclava, below the night-vision
    housing (so the quad-tube goggle silhouette stays dominant): an inverted-heart nasal cavity and
    two rows of black teeth vents, wrapping under the jaw. 100 % head. Original design."""
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    z0, z1 = eye.z - 0.138 * k, eye.z - 0.030 * k
    a0 = math.radians(62.0)
    hh = Hull(fit, [kit.head], body_regions=set())
    memo: dict[tuple[float, float], float] = {}

    def shell(az: float, z: float) -> float:
        key = (round(az, 5), round(z, 5))
        if key not in memo:
            d = Vector((math.sin(az), math.cos(az), 0.0))
            hit = hh.cast(Vector((c.x, c.y, z)) + d * 0.5, -d, 0.5)
            memo[key] = (0.5 - hit[3]) if hit[0] is not None else 0.11 * k
        return memo[key]

    def r_fn(az: float, z: float) -> float:
        # sampled balaclava + clearance; never turns in faster than the row above (chin / neck)
        return max(shell(az, z), shell(az, min(z + 0.02 * k, z1)) - 0.012 * k) + 0.008 * k

    nu, nv = 18, 8

    def mat(u: float, v: float) -> str:
        i, j = int(u * nu), int(v * nv)
        if (j in (5, 6) and i in (8, 9)) or (j == 5 and i in (7, 10)):
            return "polymer_black"                                    # nasal cavity (inverted heart)
        if j in (2, 3) and 5 <= i <= 12 and i % 2 == 1:
            return "polymer_black"                                    # teeth vents
        return "char_zero_bone"

    kit.add_head(sg.curved_panel(c, -a0, a0, z0, z1, r_fn, 0.006 * k, mat, nu=nu, nv=nv, side_mat="char_zero_bone"))
    kit.notes["faction_mask"] = "zero: bone skull lower-face guard under the NVG (Headwear)"


def _boonie_mark(kit) -> None:
    """Zero mark on the front of the Longshot's boonie crown."""
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    m = Mesh()

    def hull_of(extra: Mesh) -> Hull:
        return Hull(fit, [kit.head, extra], body_regions=set())

    zz = eye.z + 0.080 * k
    d = Vector((0.0, 1.0, 0.0))
    hit = hull_of(m).cast(Vector((c.x, c.y, zz)) + d * 0.4, -d, 0.4)
    p = hit[0] if hit[0] is not None else Vector((c.x, c.y, zz)) + d * 0.13
    stamp(m, hull_of, p, d, o.UP, mark("zero", 0.046 * k), weights=sg.HEAD_W)
    kit.add_head(m)


def _zero_unit(kit, unit: str) -> None:
    """Zero identity beyond the recolour on the units that have no helmet for the face mask."""
    if unit == "phantom":
        zero_jaw(kit)
        # oxblood harness straps over the black suit
        kit.soft.m = [("char_zero_red" if x == "polymer_black" else x) for x in kit.soft.m]
    elif unit == "longshot":
        zero_mask(kit)
        # black boonie with an oxblood band and the mark on the crown front
        kit.head.m = [{"char_sniper_drab": "char_zero_black", "char_tac_gear": "char_zero_red"}.get(x, x)
                      for x in kit.head.m]
        _boonie_mark(kit)
        _torso(kit, "zero", 1.30, front=False, h=0.10)          # on the drag bag


def _zero_bulk(kit, unit: str) -> None:
    if unit == "tac":
        import char_specials as sp

        sp.pauldrons(kit, "char_zero_armor", "char_zero_gear", size=1.05, lift=1.3)


# =============================================================================================
# entry points
# =============================================================================================
def recolor(kit, table: dict[str, str]) -> None:
    for m in [kit.soft, kit.gear, kit.head, *getattr(kit, "extra", {}).values()]:
        m.m = [table.get(x, x) for x in m.m]


def base_id(asset_id: str, faction: str) -> str:
    """``char_tac_light_frd`` -> ``tac_light``; ``char_bulwark_frd_shield`` -> ``bulwark_shield``."""
    aid = asset_id.removeprefix("char_")
    if aid.endswith("_" + faction):
        return aid[: -len(faction) - 1]
    return aid.replace(f"_{faction}_", "_")


def tag(ctx, faction: str) -> None:
    ctx.source_extra["variant_of"] = base_id(ctx.asset_id, faction)
    ctx.source_extra["visual_variant"] = faction


def dress(kit) -> None:
    """Turn the finished base build into its faction variant (no-op without ``faction``)."""
    faction = kit.opts.get("faction")
    if not faction:
        return
    unit = kit.opts["unit"]
    site = SITES[unit]
    # D-145.3 faction duty looks (``armored`` False): no armour, so no Zero pauldrons, no ballistic face mask (it sits
    # under a helmet rim) and no helmet decals (a soft cap); the arm patches the pauldrons would cover come back
    armored = kit.opts.get("armored", True)
    if faction == "zero":
        if armored:
            _zero_bulk(kit, unit)
            if site["mask"]:
                zero_mask(kit)
        _zero_unit(kit, unit)
    if site["back"] is not None:
        h = 0.11 if faction == "frd" else (ZERO_BACK.get(unit, 0.12) if faction == "zero" else 0.12)
        _torso(kit, faction, site["back"], front=False, h=h)
    if site["chest"] is not None:
        _torso(kit, faction, site["chest"], front=True, h=0.030 if faction == "frd" else 0.042)
    if site["arm"] is not None and not (faction == "zero" and unit == "tac" and armored):
        _arms(kit, faction, site["arm"])
    if site["helmet"] and armored:
        _helmet(kit, faction)
    extra = getattr(kit, "extra", {})
    if "Faceplate" in extra and faction in FACEPLATE:
        fp = extra["Faceplate"]
        fp.m = [FACEPLATE[faction].get(x, x) for x in fp.m]
    recolor(kit, REMAP[faction])
    tag(kit.ctx, faction)
    if not armored:     # char_<id>_<faction>_duty: the <id> look, variant "<faction>_duty" (scene <id>_<faction>_duty)
        kit.ctx.source_extra["variant_of"] = base_id(kit.ctx.asset_id, faction).removesuffix("_duty")
        kit.ctx.source_extra["visual_variant"] = f"{faction}_duty"
    kit.notes["faction"] = faction


__all__ = ["FACTIONS", "REMAP", "arm_patch", "base_id", "dress", "letters", "mark", "recolor", "stamp", "tag",
           "torso_mark", "zero_jaw", "zero_mask"]
