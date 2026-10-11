"""Character material palette (D1-02). Pure Python, no ``bpy``.

Single source of truth for every ``char_*`` material id that ENV D's character assets use. Outfit
scripts read the placeholder colours from here (``M_<id>`` slots in the glb) and
``make_materials.py`` writes ``game/world/materials/<id>.tres`` from the same numbers, so the
Blender preview and the game agree.

Colours are sRGB hex. Style guide §3: albedo luminance 0.04..0.85 (linear), saturation <= 0.75
(hi-vis and the faction colours included), no pure black/white; metals are albedo-coloured with
roughness >= 0.15. Faction colours: police navy ``#1E2A44`` + hi-vis ``#D7E34A``, TAC charcoal
``#2B2F33``. The Halden Security palette comes from the officer style sample
(``tools/blender/style_samples/officer.py``).

Shared-library ids (ENV C, ``game/world/materials/<id>.tres``) are used where one fits:
``leather_dark`` (shoes, belts, holsters), ``rubber_black`` (soles, grips), ``polymer_black``
(radio, pouches' hard parts, loupe), ``brass`` (gold braid, badges, buckles; the glasshouse brass
``#C9A227`` doubles as the Halden company gold), ``chrome`` (silver badge, zips).
"""

from __future__ import annotations

#: kind -> (subsurface for skin, rim etc. used by make_materials.py)
KINDS = ("skin", "eye", "hair", "cloth", "leather", "metal", "plastic", "gloss")

#: id -> (sRGB hex, roughness, metallic, kind). ``char_skin_*``, ``char_hair_*``, ``char_eye*`` are
#: filled in from ``_body`` constants by ``all_char_materials()`` so they always match the body.
OUTFIT: dict[str, tuple[str, float, float, str]] = {
    # masks (D1-04)
    "char_mask_gold": ("#D1A847", 0.30, 1.0, "metal"),
    "char_mask_lacquer_dark": ("#1F2026", 0.40, 0.0, "gloss"),
    "char_mask_inner": ("#2A2724", 0.85, 0.0, "cloth"),
    "char_mask_base": ("#B4B1AB", 0.45, 0.0, "plastic"),   # mask_base_* (mask shader overrides it)
    # crew (heist suits)
    "char_suit_dark": ("#2A2C31", 0.78, 0.0, "cloth"),
    "char_suit_navy": ("#232B3B", 0.78, 0.0, "cloth"),
    "char_shirt_white": ("#D6D4CC", 0.82, 0.0, "cloth"),
    "char_shirt_black": ("#232327", 0.80, 0.0, "cloth"),
    "char_tie_black": ("#1D1E22", 0.55, 0.0, "cloth"),
    "char_tie_burgundy": ("#5A1F2B", 0.55, 0.0, "cloth"),
    "char_leather_black": ("#1E1F22", 0.48, 0.0, "leather"),
    # Halden Security officer
    "char_sec_shirt": ("#8E9DAE", 0.86, 0.0, "cloth"),
    "char_sec_charcoal": ("#2A2D33", 0.80, 0.0, "cloth"),
    "char_sec_trousers": ("#2E3138", 0.84, 0.0, "cloth"),
    "char_sec_burgundy": ("#6E1E2A", 0.75, 0.0, "cloth"),
    "char_button_pale": ("#D5D3CB", 0.40, 0.0, "plastic"),
    "char_button_dark": ("#1E1E21", 0.40, 0.0, "plastic"),
    "char_visor_gloss": ("#1E1F22", 0.22, 0.0, "gloss"),
    "char_cable_black": ("#202124", 0.45, 0.0, "plastic"),
    "char_led_red": ("#A33A35", 0.35, 0.0, "plastic"),
    # police (Patrol) and TAC
    "char_police_navy": ("#1E2A44", 0.84, 0.0, "cloth"),
    "char_police_shirt": ("#2A3A5C", 0.85, 0.0, "cloth"),
    "char_hivis": ("#D7E34A", 0.62, 0.0, "cloth"),
    "char_metal_silver": ("#B4B6B8", 0.30, 1.0, "metal"),
    "char_tac_charcoal": ("#2B2F33", 0.90, 0.0, "cloth"),
    "char_tac_gear": ("#3A3F45", 0.86, 0.0, "cloth"),
    "char_tac_helmet": ("#30343A", 0.55, 0.0, "plastic"),
    "char_tac_glove": ("#222428", 0.70, 0.0, "leather"),
    # civilians
    "char_coat_camel": ("#9C7650", 0.88, 0.0, "cloth"),
    "char_knit_cream": ("#CDBFA4", 0.95, 0.0, "cloth"),
    "char_knit_teal": ("#3E6466", 0.95, 0.0, "cloth"),
    "char_gilet_navy": ("#2B3650", 0.45, 0.0, "cloth"),
    "char_chino_khaki": ("#9E8A66", 0.86, 0.0, "cloth"),
    "char_trousers_black": ("#26272B", 0.82, 0.0, "cloth"),
    "char_slacks_grey": ("#55585F", 0.82, 0.0, "cloth"),
    "char_dress_black": ("#252428", 0.70, 0.0, "cloth"),
    "char_blazer_navy": ("#2A3654", 0.80, 0.0, "cloth"),
    "char_shirt_blue": ("#A6B9D0", 0.82, 0.0, "cloth"),
    "char_vest_green": ("#2F4A40", 0.78, 0.0, "cloth"),
    "char_apron_leather": ("#5E412C", 0.58, 0.0, "leather"),
    "char_shoe_black": ("#1F1F22", 0.42, 0.0, "leather"),
    "char_shoe_brown": ("#5A3A26", 0.50, 0.0, "leather"),
    "char_lens": ("#1C2026", 0.06, 0.0, "gloss"),
    "char_silk_plum": ("#5E2A44", 0.42, 0.0, "cloth"),     # contacts (QB-50a): Odile Vance's blouse
    "char_suit_brown": ("#5A4632", 0.84, 0.0, "cloth"),    # contacts: Hollis Reyes's cheap suit
    "char_tweed_grey": ("#5E5A50", 0.95, 0.0, "cloth"),    # contacts: Hollis Reyes's flat cap
    "char_lip_rose": ("#7A3A44", 0.45, 0.0, "gloss"),      # contacts: Odile Vance's lipstick
    "char_armor_black": ("#222327", 0.50, 0.0, "plastic"),  # specials (P3): Wrecker plates/helmet
    "char_wrecker_suit": ("#25262A", 0.82, 0.0, "cloth"),  # specials: Wrecker bomb suit (#141518 lifted to the floor)
    "char_hazard_yellow": ("#E6B43A", 0.45, 0.0, "plastic"),  # specials: Wrecker faceplate trim (#E6B422, sat cap)
    "char_goggle_glow": ("#3FA860", 0.25, 0.0, "gloss"),  # specials: Phantom lenses (+ emission #3BFF6A)
    "char_phantom_suit": ("#24272B", 0.78, 0.0, "cloth"),  # specials: Phantom suit and balaclava
    "char_stinger_blue": ("#59A8FF", 0.45, 0.0, "plastic"),  # specials: Stinger electric blue
    "char_medic_white": ("#DADCD8", 0.55, 0.0, "plastic"),  # specials: Corpsman white
    "char_medic_red": ("#B3302D", 0.55, 0.0, "plastic"),  # specials: Corpsman emblem red (#B3261E, sat cap)
    "char_aegis_steel": ("#5D6E80", 0.50, 0.0, "plastic"),  # specials: Aegis/Brandt steel-blue armour
    "char_aegis_blue": ("#7FC8FF", 0.45, 0.0, "plastic"),  # specials: Aegis accents
    "char_sniper_drab": ("#5B5A4C", 0.88, 0.0, "cloth"),  # specials: Longshot boonie/vest
    "char_coat_command": ("#2E3440", 0.82, 0.0, "cloth"),  # specials: Brandt's command coat
}

#: Shared-library ids used by outfits, with a placeholder colour for the glb (the .tres wins).
LIBRARY: dict[str, tuple[str, float, float]] = {
    "leather_dark": ("#3A2A22", 0.55, 0.0),
    "rubber_black": ("#232427", 0.85, 0.0),
    "polymer_black": ("#26272A", 0.60, 0.0),
    "brass": ("#C9A227", 0.30, 1.0),
    "chrome": ("#C8CACC", 0.15, 1.0),
}


def all_char_materials() -> dict[str, tuple[str, float, float, str]]:
    """Every ``char_*`` id of ENV D (body + masks + outfits) -> (hex, roughness, metallic, kind)."""
    import _body as body

    out: dict[str, tuple[str, float, float, str]] = {}
    for i, hexc in enumerate(body.SKIN_TONES, 1):
        out[f"char_skin_{i}"] = (hexc, 0.55, 0.0, "skin")
    for name, hexc in body.HAIR_COLORS.items():
        out[f"char_hair_{name}"] = (hexc, 0.6, 0.0, "hair")
    out["char_eye"] = (body.EYE_COLOR, 0.25, 0.0, "eye")
    out["char_eye_iris"] = (body.IRIS_COLOR, 0.2, 0.0, "eye")
    out["char_lash"] = (body.LASH_COLOR, 0.5, 0.0, "eye")
    out.update(OUTFIT)
    return dict(sorted(out.items()))


def spec(mat_id: str) -> tuple[str, float, float]:
    """(hex, roughness, metallic) placeholder for any id an outfit uses."""
    if mat_id in LIBRARY:
        return LIBRARY[mat_id]
    h, r, m, _k = all_char_materials()[mat_id]
    return h, r, m
