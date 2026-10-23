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
KINDS = ("skin", "eye", "hair", "cloth", "leather", "metal", "plastic", "gloss", "stone", "bronze", "canvas", "rust", "velvet", "crinkle", "gilt")

#: id -> (sRGB hex, roughness, metallic, kind). ``char_skin_*``, ``char_lip_<family>``, ``char_hair_*``, ``char_eye*`` are
#: filled in from ``_body`` constants by ``all_char_materials()`` so they always match the body.
OUTFIT: dict[str, tuple[str, float, float, str]] = {
    # masks (D1-04)
    "char_mask_gold": ("#D1A847", 0.30, 1.0, "metal"),
    "char_mask_lacquer_dark": ("#1F2026", 0.40, 0.0, "gloss"),
    "char_mask_inner": ("#2A2724", 0.85, 0.0, "cloth"),
    "char_mask_base": ("#B4B1AB", 0.45, 0.0, "plastic"),   # mask_base_* (mask shader overrides it)
    # D-ACH achievement-reward mask materials (MaskMaterialDef grain, content/docs/masks.md): 512 px,
    # features sized for a mask face (uv_tile ~1.5: one texture tile ~ 12 cm of mask)
    "char_mask_limestone": ("#CDC4B0", 0.80, 0.0, "stone"),      # honed limestone, shell fragments
    "char_mask_bronze": ("#A27A46", 0.40, 1.0, "bronze"),        # statuary bronze, green-brown patina
    "char_mask_oil_canvas": ("#D6CEBB", 0.62, 0.0, "canvas"),    # primed canvas weave + impasto strokes
    "char_mask_container_rust": ("#9A4232", 0.78, 0.0, "rust"),  # painted container steel, rust, chips
    "char_mask_velvet_case": ("#77737A", 0.92, 0.0, "velvet"),     # display-case velvet, neutral mid grain
    "char_mask_night_safe": ("#4A4B50", 0.50, 0.0, "crinkle"),     # black crinkle safe paint, satin
    "char_mask_gilt_leaf": ("#C9A34A", 0.30, 1.0, "gilt"),         # worn gold leaf over red bole
    # RT-D2 achievement mask materials (Rolling Thunder)
    "char_mask_armor_plate": ("#8C8E91", 0.45, 1.0, "tread"),      # diamond-tread truck floor steel
    "char_mask_hi_vis": ("#D9733A", 0.40, 0.0, "hivis"),          # retroreflective safety sheeting
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
    "char_bank_slate": ("#3F5A52", 0.80, 0.0, "cloth"),  # npcs (D2-02): night_deposit slate green (bank livery)
    "char_bank_slate_dark": ("#2D3B37", 0.82, 0.0, "cloth"),  # npcs: bank livery trousers/skirts
    "char_bank_cream": ("#D9D2C2", 0.82, 0.0, "cloth"),  # npcs: marble cream blouses/shirts, patch border
    "char_bank_red": ("#9E302A", 0.70, 0.0, "cloth"),  # npcs: bank red (#9E2B25, sat cap): ties, scarves, manager suit
    "char_knit_slate": ("#4A665D", 0.95, 0.0, "cloth"),  # npcs: teller's sweater vest
    "char_cleaner_tabard": ("#4C6680", 0.80, 0.0, "cloth"),  # npcs: cleaning contractor tabard
    "char_knit_grey": ("#6B6C70", 0.95, 0.0, "cloth"),  # npcs: cleaner's long-sleeve top
    "char_rubber_yellow": ("#D2AE3E", 0.40, 0.0, "plastic"),  # npcs: cleaner's rubber gloves
    "char_satin_teal": ("#2F5558", 0.40, 0.0, "cloth"),  # npcs: shadow_ledger guest dress (glass teal, deep)
    "char_satin_black": ("#202024", 0.35, 0.0, "gloss"),  # npcs: dinner-jacket lapels
    "char_tux_black": ("#232327", 0.74, 0.0, "cloth"),  # npcs: dinner suit
    "char_waistcoat_graphite": ("#2E3136", 0.66, 0.0, "cloth"),  # npcs: penthouse staff waistcoat (graphite)
    "char_coat_ice": ("#BCC9D0", 0.85, 0.0, "cloth"),  # npcs: Kessler's coat (cold white accent #CFE3EE, toned)
    "char_knit_graphite": ("#2A2C30", 0.95, 0.0, "cloth"),  # npcs: Kessler's roll-neck
    "char_frd_olive": ("#434A3A", 0.86, 0.0, "cloth"),  # D2-01 faction FRD: olive uniform / green Wrecker suit
    "char_frd_coyote": ("#7A6B50", 0.86, 0.0, "cloth"),  # D2-01 FRD: coyote carrier, pouches, drag bag
    "char_frd_helmet": ("#4E5544", 0.55, 0.0, "plastic"),  # D2-01 FRD: olive-grey helmet / armour plates
    "char_frd_armor": ("#3E4634", 0.50, 0.0, "plastic"),  # D2-01 FRD: green Wrecker armour
    "char_frd_yellow": ("#D6B34A", 0.60, 0.0, "cloth"),  # D2-01 FRD: lettering, bands, patch borders
    "char_frd_dark": ("#2C3028", 0.78, 0.0, "cloth"),  # D2-01 FRD: Phantom suit (dark olive)
    "char_frd_navy": ("#252D3D", 0.72, 0.0, "cloth"),  # D2-01 FRD: field agent's nylon raid windbreaker (navy)
    "char_sen_grey": ("#60666D", 0.84, 0.0, "cloth"),  # D2-01 faction Sentinel: slate-grey uniform
    "char_sen_light": ("#A2A6A9", 0.84, 0.0, "cloth"),  # D2-01 Sentinel: light-grey carrier, pouches
    "char_sen_white": ("#C8CAC6", 0.45, 0.0, "plastic"),  # D2-01 Sentinel: off-white helmet / armour
    "char_sen_red": ("#A3302F", 0.55, 0.0, "cloth"),  # D2-01 Sentinel: corporate crimson (logo, bands)
    "char_sen_dark": ("#363B42", 0.78, 0.0, "cloth"),  # D2-01 Sentinel: Phantom suit (dark slate)
    "char_zero_black": ("#1D1E22", 0.80, 0.0, "cloth"),  # D2-01 faction Zero Division: black uniform
    "char_zero_gear": ("#292B30", 0.82, 0.0, "cloth"),  # D2-01 Zero: black carrier
    "char_zero_armor": ("#2C2E34", 0.30, 0.0, "gloss"),  # D2-01 Zero: gloss-black helmet / armour
    "char_zero_bone": ("#BDB4A0", 0.50, 0.0, "plastic"),  # D2-01 Zero: bone face mask, Zero mark
    "char_zero_red": ("#6E2329", 0.60, 0.0, "cloth"),  # D2-01 Zero: oxblood bands / mark ring
    "char_crew_rook_coat": ("#2E3138", 0.86, 0.0, "cloth"),  # D2-03 crew Rook: long charcoal overcoat
    "char_crew_rook_scarf": ("#6A2229", 0.92, 0.0, "cloth"),  # D2-03 Rook: oxblood scarf / pocket square
    "char_crew_sable_blazer": ("#40273A", 0.74, 0.0, "cloth"),  # D2-03 Sable: aubergine cropped blazer
    "char_crew_glove_ivory": ("#CFC6B4", 0.50, 0.0, "leather"),  # D2-03 Sable: ivory kid gloves
    "char_crew_dutch_bomber": ("#4E3726", 0.62, 0.0, "leather"),  # D2-03 Dutch: brown leather bomber
    "char_crew_shearling": ("#C9B696", 0.97, 0.0, "cloth"),  # D2-03 Dutch: cream shearling collar
    "char_crew_glove_tan": ("#7A5A3E", 0.55, 0.0, "leather"),  # D2-03 Dutch: tan work gloves
    "char_crew_wren_vest": ("#8A6A30", 0.82, 0.0, "cloth"),  # D2-03 Wren: mustard tweed waistcoat
    "char_crew_marten_parka": ("#4C5233", 0.88, 0.0, "cloth"),  # D-111 Marten: olive field parka
    "char_crew_marten_fur": ("#6E6152", 0.98, 0.0, "cloth"),  # D-111 Marten: grey-brown fur hood trim
    "char_crew_glove_orange": ("#A85A2C", 0.60, 0.0, "leather"),  # D-111 Marten: burnt-orange gloves
    "char_crew_jay_jacket": ("#2A559C", 0.55, 0.0, "cloth"),  # D-111 Jay: cobalt racing jacket (nylon)
    "char_crew_jay_stripe": ("#E8E6E0", 0.55, 0.0, "cloth"),  # D-111 Jay: white racing stripes
    "char_crew_glove_driving": ("#9C6B3E", 0.50, 0.0, "leather"),  # D-111 Jay: cognac driving gloves
    "char_crew_juno_jacket": ("#2F5D4A", 0.58, 0.0, "leather"),  # D4-03 Juno: emerald leather moto jacket
    "char_crew_glove_suede": ("#6A6560", 0.85, 0.0, "leather"),  # D4-03 Juno: grey suede gloves
    "char_crew_hale_jacket": ("#B49A6E", 0.92, 0.0, "cloth"),  # D4-03 Hale: sand canvas chore jacket
    "char_crew_glove_work": ("#A8893E", 0.80, 0.0, "leather"),  # D4-03 Hale: yellow work gloves
    # D-115 lead call (pistol framing shows only the glove): Wren's own sage-olive tactical gloves (were the black
    # char_tac_glove, identical to Rook's black leather with the pistol out)
    "char_crew_glove_sage": ("#6B7556", 0.72, 0.0, "leather"),
    "char_sec_knit": ("#2C2F35", 0.95, 0.0, "cloth"),  # npcs (D-063): Halden night-shift guard's V-neck sweater vest
    "char_cleaner_teal": ("#4F7F82", 0.80, 0.0, "cloth"),  # npcs: shadow_ledger cleaner tabard (glass teal #5D8C8F, toned)
    "char_hoodie_rust": ("#7A4C34", 0.95, 0.0, "cloth"),  # npcs: IT contractor's hoodie
    "char_denim": ("#36455C", 0.90, 0.0, "cloth"),  # npcs: IT contractor's jeans
    "char_sneaker_grey": ("#9D9B94", 0.75, 0.0, "cloth"),  # npcs: IT contractor's trainers
    "char_lanyard": ("#3D6EA3", 0.60, 0.0, "cloth"),  # npcs: contractor lanyard / visitor badge band
    "char_silk_ice": ("#BCC9D0", 0.45, 0.0, "cloth"),  # npcs: Kessler's dressing robe (cold-white accent, silk)
    "char_silk_graphite": ("#30343A", 0.42, 0.0, "cloth"),  # npcs: Kessler's pyjamas / robe shawl collar
    "char_ng_shirt": ("#9EA2A6", 0.82, 0.0, "cloth"),  # npcs: Northgate Executive Protection grey shirt
    "char_ng_enamel": ("#2F4E6E", 0.40, 0.0, "gloss"),  # npcs: Northgate lapel-pin enamel (steel blue)
    "char_silk_ivory": ("#D3CBB8", 0.45, 0.0, "cloth"),  # npcs: Helena Moor's silk blouse
    "char_cartel_wax_rust": ("#6E4630", 0.55, 0.0, "cloth"),  # QC-36 cartel gunmen: rust waxed dock jacket (#7A4A2E)
    "char_cartel_cord": ("#3F3127", 0.95, 0.0, "cloth"),  # QC-36 cartel: corduroy jacket collar
    "char_cartel_cargo": ("#58553F", 0.88, 0.0, "cloth"),  # QC-36 cartel: drab cargo trousers
    "char_cartel_rubber": ("#2E3830", 0.42, 0.0, "plastic"),  # QC-36 cartel: dark-green rubber fishing boots
    "char_cartel_flare": ("#D06E36", 0.85, 0.0, "cloth"),  # QC-36 cartel: flare-orange bandana (#FF6B1A, sat cap)
    "char_cartel_oilskin": ("#B85E32", 0.38, 0.0, "cloth"),  # QC-36 cartel: orange oilskin bib overalls
    "char_cartel_hoodie": ("#4A4B4E", 0.95, 0.0, "cloth"),  # QC-36 cartel: heather-grey hoodie
    "char_cartel_puffer": ("#26272A", 0.45, 0.0, "cloth"),  # QC-36 cartel: black quilted puffer vest
    "char_cartel_webbing": ("#4B4536", 0.90, 0.0, "cloth"),  # QC-36 cartel: sling webbing
    "char_cartel_wood": ("#5E3D26", 0.55, 0.0, "plastic"),  # QC-36 cartel: slung gun stock / pump
    "char_cartel_gunmetal": ("#3C3E42", 0.40, 1.0, "metal"),  # QC-36 cartel: slung gun receiver / barrel
    "char_cartel_shell": ("#8E3228", 0.50, 0.0, "plastic"),  # QC-36 cartel: shotgun shell hulls
    "char_gallery_bone": ("#CFC6B2", 0.80, 0.0, "cloth"),  # D3-01 gallery_night: curator's bone-white suit
    "char_gallery_green": ("#2C463B", 0.80, 0.0, "cloth"),  # D3-01 gallery: Halberd Gallery Security blazer
    "char_gallery_wine": ("#6E2A3A", 0.60, 0.0, "cloth"),  # D3-01 gallery: Halberd wine (crest, ties, pin enamel)
    "char_glove_white": ("#D3D1C9", 0.75, 0.0, "cloth"),  # D3-01 gallery: attendants' cotton art-handling gloves
    "char_satin_wine": ("#6A2433", 0.40, 0.0, "cloth"),  # D3-01 gallery: patron's wine satin cocktail dress
    "char_velvet_midnight": ("#313A5C", 0.95, 0.0, "cloth"),  # D3-01 gallery: patron's velvet dinner jacket
    "char_chino_navy": ("#343D52", 0.86, 0.0, "cloth"),  # D3-01 meridian_federal: customer's navy chinos
    "char_blazer_grey": ("#6A6C70", 0.84, 0.0, "cloth"),  # D3-01 meridian: customer's unstructured grey blazer
    "char_nylon_olive": ("#4E5640", 0.55, 0.0, "cloth"),  # D3-01 meridian: parent's olive nylon bomber
    "char_suit_grey": ("#4D5056", 0.80, 0.0, "cloth"),  # D-075 ostrander_federal: bank officers' grey worsted suit
    "char_sneaker_white": ("#CBC8C0", 0.70, 0.0, "cloth"),  # D3-01: white trainers
    "char_vl_shirt": ("#A0946E", 0.86, 0.0, "cloth"),  # D3-01 rolling_thunder: Vaultline Armored sand shirt
    "char_vl_trousers": ("#433A2F", 0.84, 0.0, "cloth"),  # D3-01 rolling_thunder: Vaultline brown trousers / cap
    "char_vl_vest": ("#2A2C30", 0.80, 0.0, "cloth"),  # D3-01 rolling_thunder: Vaultline black ballistic vest
    "char_vl_amber": ("#C98A3A", 0.55, 0.0, "cloth"),  # D3-01 rolling_thunder: Vaultline amber (patch, lettering)
    "char_club_violet": ("#4E2F66", 0.80, 0.0, "cloth"),  # D3-01 afterhours: the Velvet's violet (DJ, bar staff)
    "char_nylon_black": ("#26272B", 0.45, 0.0, "cloth"),  # D3-01 afterhours: bouncer's black nylon bomber
    "char_satin_gold": ("#B8954E", 0.35, 0.0, "cloth"),  # D3-01 afterhours: patron's gold satin mini dress
    "char_club_magenta": ("#9E3A72", 0.70, 0.0, "cloth"),  # D3-01 afterhours: patron's magenta top
    "char_club_lime": ("#9BC43A", 0.60, 0.0, "cloth"),  # D-165 afterhours: neon-safe lime accent (wristbands, clubwear)
    "char_club_coral": ("#E0705A", 0.60, 0.0, "cloth"),  # D-165 afterhours: neon-safe coral accent
    "char_hoodie_cream": ("#B9AE98", 0.95, 0.0, "cloth"),  # D3-01 afterhours: patron's cream hoodie
    "char_suit_plum": ("#4A2C40", 0.76, 0.0, "cloth"),  # D-115 glasshouse: Greta Vossberg's deep plum trouser suit
    "char_knit_oat": ("#A89878", 0.95, 0.0, "cloth"),  # D-115 glasshouse: admin clerk's oatmeal cardigan
    "char_hivis_orange": ("#E07A3C", 0.62, 0.0, "cloth"),  # D-115 dockside_burn: orange hi-vis vest
    "char_reflect_silver": ("#BCC0C2", 0.32, 0.0, "plastic"),  # D-115 dockside: reflective vest tape
    "char_hardhat_white": ("#D2D0C8", 0.38, 0.0, "plastic"),  # D-115 dockside: white hard hat
    "char_hardhat_blue": ("#3D5F8E", 0.38, 0.0, "plastic"),  # D-115 dockside: blue hard hat
    "char_work_navy": ("#2E3647", 0.80, 0.0, "cloth"),  # D-115 dockside: navy canvas work jacket
    "char_work_charcoal": ("#3D4045", 0.86, 0.0, "cloth"),  # D-115 dockside: charcoal work / cargo trousers
    "char_fleece_maroon": ("#6A2E30", 0.97, 0.0, "cloth"),  # D-115 dockside: packer's maroon fleece
    "char_knit_navy": ("#2B3346", 0.95, 0.0, "cloth"),  # D-115 dockside: packer's navy beanie
    "char_glove_work": ("#7D776A", 0.80, 0.0, "cloth"),  # D-115 dockside: grey work gloves
    "char_satin_sapphire": ("#2D3F70", 0.38, 0.0, "cloth"),  # GN-D1 gallery: patron_e's sapphire satin dress
    "char_satin_amethyst": ("#4E3164", 0.38, 0.0, "cloth"),  # GN-D1 gallery: patron_g's amethyst satin dress
    # OF-D1 Ostrander Federal bank civilians (char_p5_bank.py)
    "char_skirt_navy": ("#2E3446", 0.80, 0.0, "cloth"),  # OF-D1: customer_c's navy pencil skirt
    "char_knit_mustard": ("#9C7A34", 0.95, 0.0, "cloth"),  # OF-D1: customer_c's mustard cardigan
    "char_coat_heather": ("#6B5E66", 0.92, 0.0, "cloth"),  # OF-D1: the retiree's heather wool coat
    "char_coat_stone": ("#A49C88", 0.88, 0.0, "cloth"),  # OF-D1: the office man's stone trench coat
    "char_canvas_tan": ("#8A7352", 0.86, 0.0, "cloth"),  # OF-D1: the tradesperson's canvas chore jacket
    "char_vl_hivis": ("#E0963E", 0.62, 0.0, "cloth"),  # RT-D1: Vaultline route marshal's amber hi-vis vest
    # RT-D1 Rolling Thunder street civilians and staff (char_p5_street.py)
    "char_diner_rose": ("#BF8A8E", 0.80, 0.0, "cloth"),  # RT-D1: the diner waitress's pale rose uniform dress
    "char_apron_cream": ("#D3CDBC", 0.88, 0.0, "cloth"),  # RT-D1: the diner aprons (waitress, cook)
    "char_polo_teal": ("#2F6A66", 0.88, 0.0, "cloth"),  # RT-D1: the car-park attendant's polo
    "char_fleece_espresso": ("#3B302A", 0.97, 0.0, "cloth"),  # RT-D1: the attendant's dark fleece gilet
    "char_mac_cherry": ("#8A2E38", 0.70, 0.0, "cloth"),  # RT-D1: the commuter's cherry raincoat (mac)
    "char_hoodie_heather": ("#85878A", 0.95, 0.0, "cloth"),  # RT-D1: the jogger's heather-grey hoodie
    "char_nylon_green": ("#4C8040", 0.60, 0.0, "cloth"),  # RT-D1: the delivery rider's padded jacket and bag
    "char_blazer_forest": ("#35503F", 0.82, 0.0, "cloth"),  # RT-D1: the office worker's forest-green blazer
    # D-115 hand props (char_hand_props.py)
    "char_prop_paper": ("#DCDAD2", 0.85, 0.0, "plastic"),  # cigarette paper, book pages, cash strap, bottle label
    "char_prop_filter": ("#C08A52", 0.80, 0.0, "plastic"),  # cigarette cork filter
    "char_prop_ember": ("#9A4A36", 0.90, 0.0, "plastic"),  # cigarette ember (+ emission, make_materials EMISSION)
    "char_prop_ceramic": ("#D4D0C6", 0.30, 0.0, "gloss"),  # mug glaze
    "char_prop_coffee": ("#3B2A20", 0.20, 0.0, "gloss"),  # coffee in the mug
    "char_prop_mop_string": ("#C9C3B0", 0.95, 0.0, "cloth"),  # cotton mop strands
    "char_prop_cash": ("#8A9677", 0.85, 0.0, "cloth"),  # banknote stack (original grey-green, no real currency)
    "char_prop_bottle": ("#6B4A26", 0.15, 0.0, "gloss"),  # amber liquor bottle glass (opaque)
    "char_prop_book": ("#5A2E2E", 0.60, 0.0, "leather"),  # book cover
    "char_prop_glass": ("#B4C2C6", 0.08, 0.0, "gloss"),  # tumbler glass (opaque: reads at range, no alpha pass)
}

#: Shared-library ids used by outfits, with a placeholder colour for the glb (the .tres wins).
LIBRARY: dict[str, tuple[str, float, float]] = {
    "leather_dark": ("#3A2A22", 0.55, 0.0),
    "rubber_black": ("#232427", 0.85, 0.0),
    "polymer_black": ("#26272A", 0.60, 0.0),
    "brass": ("#C9A227", 0.30, 1.0),
    "chrome": ("#C8CACC", 0.15, 1.0),
}


#: Skin base roughness (D2-03 touch-up: 0.55 read glossy under a close key on every tone; skin
#: breaks up +-0.1 around this in make_materials ``_skin``) and the skin specular (Godot
#: ``metallic_specular``; 0.35 ~ F0 2.8 %, skin's IOR ~1.4, instead of the 0.5 / 4 % default).
SKIN_ROUGHNESS = 0.66
SKIN_SPECULAR = 0.35


def all_char_materials() -> dict[str, tuple[str, float, float, str]]:
    """Every ``char_*`` id of ENV D (body + masks + outfits) -> (hex, roughness, metallic, kind)."""
    import _body as body

    out: dict[str, tuple[str, float, float, str]] = {}
    for i, hexc in enumerate(body.SKIN_TONES, 1):
        for sfx, _strength, _hi in body.BEARD_LEVELS:
            out[f"char_skin_{i}{sfx}"] = (hexc, SKIN_ROUGHNESS, 0.0, "skin")
    for name, hexc in body.HAIR_COLORS.items():
        out[f"char_hair_{name}"] = (hexc, 0.6, 0.0, "hair")
    out["char_eye"] = (body.EYE_COLOR, 0.25, 0.0, "eye")
    out["char_eye_iris"] = (body.IRIS_COLOR, 0.2, 0.0, "eye")
    out["char_lash"] = (body.LASH_COLOR, 0.5, 0.0, "eye")
    for fam, hexc in body.LIP_COLORS.items():
        out[f"char_lip_{fam}"] = (hexc, 0.45, 0.0, "skin")
    out.update(OUTFIT)
    return dict(sorted(out.items()))


def spec(mat_id: str) -> tuple[str, float, float]:
    """(hex, roughness, metallic) placeholder for any id an outfit uses."""
    if mat_id in LIBRARY:
        return LIBRARY[mat_id]
    h, r, m, _k = all_char_materials()[mat_id]
    return h, r, m
