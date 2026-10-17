"""Rolling Thunder cast (D3-01): the armoured-car crew (``rolling_thunder``, P5; Transport analogue).

No rolling_thunder design doc yet: roles follow the D3-01 brief. The convoy is run by **Vaultline
Armored Transport** (original company): sand-khaki short-sleeved uniform shirts, dark brown work
trousers and caps, black external ballistic vests, and the Vaultline mark (an amber chevron "V" over
a road bar, amber-rimmed brown patch) on the vest front, the left sleeve and the cap, with
VAULTLINE in amber block letters across the vest back. Distinct from the police (navy + hi-vis,
long sleeves, patrol cap), Halden (steel-blue shirt, saucer cap) and TAC (charcoal, helmets): no
helmet, bare forearms, a soft crew cap with a curved peak.

* ``char_armored_car_crew``: a heavy-set man, 40s, buzz cut and stubble.
* ``char_armored_car_crew_b``: a woman, 30s, dark bob under the cap.
* RT-D1 (Rolling Thunder: up to 3 trucks x driver + custodian, so six crew on screen, D-130): four more faces in
  the same uniform, ``_c`` a man in his 50s (grey, short), ``_d`` a woman in her 40s (brown bob), ``_e`` a young man
  (buzz cut), ``_f`` a man in his 30s (blond side part, stubble).
* ``char_armored_car_marshal``: the route marshal (QC-86), a man in his 50s, stubble: the crew uniform with a
  Vaultline-amber hi-vis vest (not the police yellow) in place of the ballistic vest, VAULTLINE in brown on its back
  and the amber patch on its chest, so he reads as "the advance man" at 30 m.

Both: duty belt with a holstered pistol, the radio on the right hip (= the ``Hip`` seat where the
pager rides), a coiled cable up to a speaker-mic on the vest's right shoulder strap, pouches, black
work boots. The convoy escort is the law-enforcement roster (``tac_light`` / ``tac_heavy`` /
``patrol_officer`` and their ``frd`` / ``sentinel`` / ``zero`` reskins by difficulty), listed in
``world/characters/p5_cast.json``; nothing new is built for it.

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (cap).
No blend shapes (baked at the params below).
"""

import math

import _gear_kit as gk
import _npc as n
import _outfit as o
import _outfit_garments as g
import _p5 as p5
import char_dock_workers as dw
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_armored_car_crew": {"height": 1.84, "build": 0.8, "gender": 0.0, "age": 0.45, "skin": 2,
                              "beard_shadow": 0.7, "hair": "buzz", "hair_color": "dark", "look": "crew"},
    "char_armored_car_crew_b": {"height": 1.73, "build": 0.55, "gender": 1.0, "age": 0.3, "skin": 6, "hair": "bob",
                                "hair_color": "dark", "look": "crew"},
    "char_armored_car_crew_c": {"height": 1.78, "build": 0.6, "gender": 0.0, "age": 0.62, "skin": 4,
                                "beard_shadow": 0.4, "hair": "short", "hair_color": "grey", "look": "crew"},
    "char_armored_car_crew_d": {"height": 1.69, "build": 0.65, "gender": 1.0, "age": 0.45, "skin": 3, "hair": "bob",
                                "hair_color": "brown", "look": "crew"},
    "char_armored_car_crew_e": {"height": 1.80, "build": 0.5, "gender": 0.0, "age": 0.2, "skin": 5, "hair": "buzz",
                                "hair_color": "dark", "look": "crew"},
    "char_armored_car_crew_f": {"height": 1.76, "build": 0.65, "gender": 0.0, "age": 0.35, "skin": 1,
                                "beard_shadow": 0.5, "hair": "side_part", "hair_color": "blond", "look": "crew"},
    "char_armored_car_marshal": {"height": 1.81, "build": 0.7, "gender": 0.0, "age": 0.66, "skin": 3,
                                 "beard_shadow": 0.8, "hair": "short", "hair_color": "grey", "look": "marshal"},
}

SHIRT = "char_vl_shirt"
BROWN = "char_vl_trousers"
VEST = "char_vl_vest"
AMBER = "char_vl_amber"
HIVIS = "char_vl_hivis"  # Vaultline amber hi-vis, never the police yellow


def crew(kit: Kit, marshal: bool = False) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * k
    boots = g.shoes(fit, "char_shoe_black", "rubber_black", top_z=0.15, base=0.007, boot=True)
    kit.add_soft(boots)
    n.shirt(kit, SHIRT, belt_z - 0.02 * k, collar="fold", sleeve=0.55, point_len=0.056)
    tr = n.trousers(kit, BROWN, boots, belt_z + 0.026 * k, hem_r=0.062)
    # duty belt: radio on the right hip (Hip seat), holster behind it, pouches on the left
    b = gk.Belt(fit, Hull(fit, [tr], body_regions=set()), belt_z, height=0.046, thick=0.006)
    kit.add_soft(b.mesh("char_leather_black"))
    bg = Mesh()
    bg.extend(gk.buckle(b, "char_metal_silver"))
    a_radio = math.radians(100.0)
    bg.extend(gk.radio(b, a_radio))
    bg.extend(gk.holster(b, math.radians(138.0)))
    bg.extend(gk.pouch(b, math.radians(-112.0), 0.065, 0.075, 0.03, "polymer_black", snap="char_metal_silver"))
    bg.extend(gk.pouch(b, math.radians(-150.0), 0.07, 0.06, 0.03, "char_leather_black", snap="char_metal_silver"))
    kit.add_gear(bg)
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    # vest over the shirt, ending above the belt (the route marshal: a soft hi-vis vest instead of the carrier)
    n0 = len(kit.soft.f)
    if marshal:
        vest = dw.hivis_vest(kit, HIVIS, stand=0.016)
    else:
        vest, _box = p5.carrier_vest(kit, VEST, belt_z + 0.04 * k)
    n.cull_under(kit, n0, vest, "faces_hidden_by_vest")
    p5.vaultline_patch(kit, lambda: p5._front_hit(kit.hull(), -0.095 * k, 1.315 * k, 0.1 * k),
                       Vector((0.0, 1.0, 0.0)), Vector((0, 0, 1)), 0.080, 0.060)
    p5.stamp_back(kit, "VAULTLINE", 1.30, 0.036, BROWN if marshal else AMBER)
    # sleeve patch on the left upper arm
    sh_l, el_l = Vector(fit.J["shoulder.L"]), Vector(fit.J["elbow.L"])
    axis = (sh_l - el_l).normalized()
    out = Vector((-1.0, 0.0, 0.0))
    out = (out - axis * out.dot(axis)).normalized()
    pa = sh_l.lerp(el_l, 0.30)

    def arm_anchor() -> Vector:
        hit = kit.hull().cast(pa + out * 0.3, -out, 0.3)
        return hit[0] if hit[0] is not None else pa + out * 0.05

    p5.vaultline_patch(kit, arm_anchor, out, axis, 0.064, 0.058)
    # speaker-mic on the vest's right shoulder, coiled cable down to the radio
    hull = kit.hull()
    sh_r = Vector(fit.J["shoulder.R"])
    mic, exit_pt = gk.speaker_mic(hull, Vector((sh_r.x - 0.05 * k, sh_r.y + 0.06 * k, sh_r.z - 0.03 * k)),
                                  Vector((0.25, 1.0, 0.35)), k=k)
    kit.add_gear(mic)
    radio_top = b.point(a_radio, dz=0.045 * k, out=0.03 * k)
    mid = [exit_pt + Vector((0.01 * k, 0.02 * k, -0.08 * k)), Vector((0.175 * k, 0.07 * k, 1.20 * k)),
           Vector((0.20 * k, 0.03 * k, 1.11 * k))]
    kit.add_soft(gk.coil_cable(fit, kit.hull(), exit_pt, radio_top, mid, k=k, coil_to=0.62))
    # crew cap with the mark on the front
    cap, _ring = p5.ball_cap(fit, BROWN, peak_mat=BROWN, button_mat=AMBER)
    badge = p5.cap_badge(fit, cap, lambda w, h: [[(o.rounded_rect(w, h, 0.18 * w, 1), AMBER, 0.0012)],
                                                  [(o.rounded_rect(0.84 * w, 0.84 * h, 0.14 * w, 1), BROWN, 0.0008)],
                                                  p5.vaultline_mark(0.62 * h, AMBER)], 0.050, 0.038)
    cap.extend(badge)
    kit.add_head(cap)
    kit.notes["hip_note"] = "Hip seat = the radio on the duty belt (right hip); the pager rides there"
    kit.notes["look"] = ("Vaultline Armored Transport crew: sand short-sleeved shirt, brown trousers, black ballistic "
                         "vest with the amber Vaultline patch (chest, left sleeve) and VAULTLINE on the back, brown "
                         "crew cap with the mark, duty belt (radio = Hip, holster, pouches), speaker-mic, boots")


def marshal(kit: Kit) -> None:
    crew(kit, marshal=True)
    kit.notes["look"] = ("Vaultline route marshal: the crew uniform (sand shirt, brown trousers, crew cap, duty belt, "
                         "speaker-mic) with an amber hi-vis vest instead of the ballistic vest, the amber patch on its "
                         "chest and VAULTLINE in brown across its back")


_looks = {"crew": crew, "marshal": marshal}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
