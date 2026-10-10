# content/data: provenance notes (ENV B)

Every balance number lives in these `.tres` files. **V** = taken from `docs/research/pd2_research.md`
or `docs/design/pd2_fidelity.md`; **◇** = invented or interpolated by us (tune freely).
Names, makers and models are original. Display units: PD2 (damage, armor, health).

## Weapons: `weapons/kestrel_p9.tres` (Halvard Arms Kestrel P9, 9 mm compact, SECONDARY, PISTOL, semi)
Modeled on PD2's starter pistol feel.
| Stat | Value | Src |
|---|---|---|
| damage / headshot bonus | 35 / ×1.0 | starter-pistol feel ◇; the bonus multiplies the target's own headshot multiplier (damage.md, D-026) |
| rpm cap, mag, total | 480, 17, 153 | ◇ (PD2-like) |
| falloff start/end/min | 15 m / 30 m / 0.5 | L3.2 "pistols moderate", numbers ◇ |
| spread hip/ADS | 3.0° / 1.0° | ◇ |
| recoil kick/horizontal | 1.0° / 0.4° | ◇ |
| reload tactical/empty | 1.5 s / 2.1 s | ◇ |
| equip / ADS time | 0.35 s / 0.2 s | ◇ |
| concealment | 30 | V (cap 30) |
| suppression (threat) | 8 | ◇ |
| ammo pickup min/max | 4 / 8 rounds | ◇ (unit = rounds; see lead question) |
| noise radius | 60 m | ◇ |
| price / unlock | 0 / 0 | starter |
Fire cues use the contract pattern `cue.weapon_pistol_fire(_suppressed)`.

## Mods: `mods/`
Delta resources are `WeaponStats` that must equal `WeaponStats.make_delta()` (D-022 QB-5) except
for the fields the mod intentionally changes. `.tres` files can't call it, so each delta spells out
make_delta's zeros: `pellets = 0`, `headshot_mult = 0`, `falloff_start_m = 0`, `falloff_end_m = 0`, `falloff_min_mult = 0`,
`equip_time_s = 0`, `ads_time_s = 0`, `noise_radius_m = 0` (suppressors set their radius),
`magnification = 0` (sights set theirs). Code that builds deltas calls `make_delta()`.
`test_mod_deltas_start_from_make_delta` enforces it.
| Id | Slot | Delta | Src |
|---|---|---|---|
| `mod.p9_iron_sights` | SIGHT (default) | none (stock) | — |
| `mod.p9_standard_mag` | MAGAZINE (default) | none (stock) | — |
| `mod.p9_suppressor` (Hushline) | SUPPRESSOR | suppressed, noise 1 m (V, L3.7); damage −2, concealment −2, ADS +0.05 s, threat −8 (→0, V L3.5), kick −0.1 | ◇ amounts |
| `mod.p9_reflex_sight` (Pinpoint) | SIGHT | ADS spread −0.15°, magnification 1.1, concealment −1, ADS +0.02 s | ◇ |
| `mod.p9_extended_mag` | MAGAZINE | mag +8, total +17, concealment −2, reload +0.3 s / +0.3 s | ◇ |
Mod prices 3000 / 2000 / 2500 ◇.

## Melee: `melee/folding_knife.tres`
Damage 50, charged 120, charge 1.0 s, range 1.8 m, knockdown 0.2 ◇; concealment 30, silent (V).

## Armor: `armor/` (research §2.3, all 7 tiers)
Armor, concealment, dodge and unlock levels are V. Speed and stamina multipliers are the PD2 values
divided by the suit's (36.8 speed, 51.3 stamina).
| Ours | PD2 | Armor | Conceal | Dodge | Unlock |
|---|---|---|---|---|---|
| Tailored Suit | Two-Piece Suit | 20 | 30 | +0.05 | 0 |
| Light Vest | Lightweight Ballistic Vest | 50 | 26 | −0.05 | 7 |
| Patrol Vest | Ballistic Vest | 60 | 23 | −0.10 | 1 |
| Heavy Vest | Heavy Ballistic Vest | 70 | 21 | −0.15 | 12 |
| Flak Rig | Flak Jacket | 90 | 18 | −0.20 | 21 |
| Tactical Plate | Combined Tactical Vest | 110 | 12 | −0.25 | 31 |
| Breacher Plate | Improved CTV | 170 | 1 | −0.55 | 0 + `unlock_skill = skill.juggernaut.plated` (D-022 QB-7; "Plated" = Iron Man analog, Bruiser tree / Juggernaut subtree; placeholder id until the skill data ships) |

## Deployables: `deployables/`
Doctor bag 2 uses (V), ammo bag 4 uses = 400% (V), body bag case 3 bags (V, research §1.7).
Deploy time 2.0 s for all three ◇. Params: doctor `{heal_frac 1.0, resets_downs}`, ammo
`{refill_frac_per_use 1.0}` ◇, case `{bags 3}`.

## Throwables: `throwables/`
Perk-deck items (data only, no models yet): `throwable.steady_flask` (Composure's flask, kind
`flask`, count 1, damage 0) and `throwable.boss_injector` (Overlord's injector, kind `injector`,
count 1, damage 0). Radius and fuse 0 (not thrown). Their effects live in the deck's `perk.*`
grants. `test_perk_throwables_exist` checks every `perk.throwable` item id resolves.

## Loot: `loot/`
Jewelry $1,000 LIGHT ◇, cash $1,200 LIGHT ◇, body bag $0 HEAVY (S6.3, D-032). Base values before the
difficulty multiplier.

## Difficulty: `difficulty/` (Routine, Tense, Hazardous, Brutal, Lethal, Cataclysm = PD2 Normal, Hard, Very Hard, Overkill, Mayhem, Death Sentence)
| | Rou | Ten | Haz | Bru | Let | Cat | Src |
|---|---|---|---|---|---|---|---|
| payout_mult | 1 | 2 | 2.6 | 4.2 | 7.2 | 9.2 | V (S10.4) |
| xp_mult | 1 | 2 | 5 | 10 | 11.5 | 14 | V (§2.6; Mayhem 11.5 picked from the CONFLICT) |
| enemy_cap | 16 | 20 | 24 | 28 | 32 | 36 | ◇ |
| assault_intensity | 0.6 | 0.75 | 0.9 | 1.0 | 1.15 | 1.3 | ◇ |
| bulwark/stinger/corpsman/phantom/wrecker caps | 2/1/1/0/1 ◇ | 3/1/2/0/1 ◇ | 4/2/2/1/2 ◇ | 4/2/3/2/2 V | 4/3/3/2/2 V(taser)/◇ | 4/3/3/2/3 V(dozer)/◇ | §2.6, L4.11 |
| detection_speed_mult | 1 | 1 | 1 | 1 | 1 | 1 | ◇ (no research says otherwise) |
| civilian_kill_penalty | 2000 | 3000 | 5000 | 8000 | 12000 | 16000 | ◇ (PD2 range $2k–$51k incl. job tier) |
| revive_health_frac | 0.4 | 0.4 | 0.4 | 0.4 | 0.1 | 0.1 | V (60% / 90% lost) |
| armor_invuln_s | 0.45 | 0.45 | 0.45 | 0.45 | 0.35 | 0.35 | V |
| custody_auto_release_s | 119 | 119 | −1 | −1 | −1 | −1 | V (−1 = trade only) |
| hostage_assault_delay_s | 30 | 30 | 30 | 30 | 10 | 10 | V |
Phantoms (cloakers) are capped at 0 below Hazardous (V: "Very Hard+").
`special_limits` keys must be canonical enemy ids from `docs/contracts/groups.md` (D-022 QB-9);
every Wrecker variant counts toward `enemy.wrecker`. `test_special_limits_use_canonical_enemy_ids`.

## Tweaks: `tweak/`
* `concealment_curve.tres` (`ConcealmentCurve`): total 91..119 → DR. Anchors V: 119→3, 116→7,
  113→12, 110→16, 107→20, 104→26, 101→35, 100→43, 97→49, 94→58, 93→63, 92→69, 91→75.
  Interpolated (linear, rounded) ◇: 95→55, 96→52, 98→47, 99→45, 102→32, 103→29, 105→24, 106→22,
  108→19, 109→17, 111→15, 112→13, 114→10, 115→9, 117→6, 118→4. (96→52 and 114→10 agree with
  the DR values in the S2.3 multiplier table.) `empty_slot_concealment = 30` is the P1 rule for the
  missing primary ◇. DR → detection multiplier points (S2.3) are V; interpolation between them ◇.
* `display_stats.tres` (`DisplayStatTweak`): UI mapping ◇. Accuracy = linear in ADS spread
  (0° → 100, 2.5° → 0); stability = linear in kick + 0.5 × horizontal (0° → 100, 3° → 0); threat =
  suppression capped at 43 (V cap).
* `payout.tres` (`PayoutTweak`): `stealth_xp_bonus_mult = 1.2` ◇ is the stealth bonus BANKED by a
  successful stealth heist and applied to the NEXT payday's XP (S11.1, D-022 QB-13). S11.1 scales it
  +5..25% by heist size; P1 uses one value, P4 scales it by heist size.

## Armory expansion (B4-04): `weapons/` + `mods/`
One weapon per class plus a heavy pistol. Makers are original: **Marrow & Kell** (Warden .45,
Heron .308), **Brannock Defense** (Hornet 9, Corsair), **Tillman Ironworks** (Plowman 12),
**Graff-Lindqvist** (Rampart). Slots follow PD2: pistols and SMGs are SECONDARY; ARs, shotguns,
LMGs and snipers are PRIMARY. Shapes are V (L3.2 falloff by class, L3.4 sniper piercing, L3.5/L3.7
suppressors, P6 mod trade-offs); every number is ◇ (PD2-like, tune freely). Headshot bonus 1.0 for
all (D-026). Fire cues `cue.weapon_<anim_set>_fire(_suppressed)`; anim sets `pistol`, `smg`,
`rifle`, `shotgun`, `lmg`, `sniper`.

| Weapon | Class / slot / modes | Dmg × pellets | RPM | Mag / total | Falloff start/end/min | Conc | Reload | Price / unlock |
|---|---|---|---|---|---|---|---|---|
| `warden_45` Warden .45 | PISTOL / SEC / semi | 62 | 400 | 8 / 72 | 15 / 30 / 0.5 | 27 | 1.7 / 2.3 | 18000 / 6 |
| `hornet_9` Hornet 9 | SMG / SEC / auto, semi | 36 | 800 | 30 / 180 | 18 / 36 / 0.55 | 24 | 2.2 / 3.0 | 24000 / 4 |
| `corsair_ar` Corsair | AR / PRI / auto, semi | 55 | 700 | 30 / 150 | 9999 / 9999 / 1.0 (none) | 20 | 2.4 / 3.1 | 32000 / 3 |
| `plowman_12` Plowman 12 | SHOTGUN / PRI / pump | 16 × 10 | 70 | 6 / 48 | 8 / 22 / 0.15 | 21 | 3.4 / 4.2 | 28000 / 8 |
| `rampart_lmg` Rampart | LMG / PRI / auto | 48 | 750 | 100 / 300 | 25 / 45 / 0.6 | 2 | 5.6 / 6.6 | 54000 / 18 |
| `heron_308` Heron .308 | SNIPER / PRI / bolt | 230 | 50 | 5 / 40 | 25 / 60 / **1.35** (gains) | 6 | 3.0 / 3.8 | 48000 / 14 |
Heron: `armor_pierce` 1.0, `shield_pierce`, `wall_pierce` (L3.4). Threat (suppression) 11 / 10 /
12 / 18 / 22 / 30; noise 70 / 60 / 70 / 80 / 90 / 100 m; spreads, recoil, equip/ADS times and ammo
pickups are in the .tres files (all ◇). Shotgun reloads are whole-tube times (PD2 loads shell by
shell; see the lead question in the B4-04 report).

Mods (stock defaults have a zero delta, except the Heron's stock 4x scope = magnification 4.0):
| Weapon | Optional mods (type: main effect / downside) |
|---|---|
| Warden | `w45_suppressor` (SUPP: silent, threat 0 / dmg −4, conc −3, ADS +0.05), `w45_compensator` (BARREL_EXT: kick −0.5 / conc −2; **conflicts** with the suppressor), `w45_reflex_sight` (SIGHT: ADS spread −0.15, 1.1× / conc −1), `w45_extended_mag` (MAG: +4 / conc −2, reload +0.25) |
| Hornet | `hornet_suppressor` (silent, threat 0 / dmg −3, conc −2), `rail_reflex_sight`, `hornet_extended_mag` (+15 / conc −3, reload +0.4), `hornet_stock_folded` (STOCK: conc +3 / kick +0.35, horiz +0.2, ADS spread +0.3) |
| Corsair | `corsair_suppressor` (silent, threat 0 / dmg −4, conc −3), `rail_reflex_sight`, `rail_prism_scope` (3×, ADS spread −0.25 / conc −3, ADS +0.08), `corsair_vertical_grip` (FOREGRIP: kick −0.2 / conc −1, ADS +0.03), `corsair_extended_mag` (+10 / conc −2) |
| Plowman | `plowman_choke` (BARREL_EXT: spreads −0.5 / conc −1), `rail_reflex_sight`, `plowman_extended_tube` (+2 / conc −2, reload +0.6), `plowman_pistol_grip` (STOCK: conc +5, hip −0.3 / kick +0.8, ADS spread +0.5) |
| Rampart | `rampart_short_barrel` (BARREL: conc +4 / ADS spread +0.4, kick +0.15), `rail_reflex_sight`, `rail_prism_scope`, `rampart_bipod` (FOREGRIP: kick −0.35 / conc −2, ADS +0.05), `rampart_box_200` (+100 / conc −3, reload +1.2, equip +0.1) |
| Heron | `heron_suppressor` (silent, threat 0 / dmg −20, conc −3), `heron_scope_10x` (8× / conc −2, ADS +0.08), `heron_bipod` (kick −0.6 / conc −2), `heron_extended_mag` (+5 / conc −2) |
Shared rail optics: `rail_reflex_sight` (ADS spread −0.1, 1.15× / conc −1, ADS +0.02, $3000) and
`rail_prism_scope` ($6000). Every suppressor's `suppression` delta equals minus its weapon's base
threat, so a resolved suppressed weapon has threat 0 (L3.5). `test_armory.gd` checks the shapes.
Models: `tools/blender/weapons/<weapon>.py` + `<weapon>_mods.py` (+ `rail_optics_mods.py`), helpers
`_common.py` and `_<weapon>.py`; previews `game/assets/weapons/<weapon>_preview_*.png`. Tube
magazines hang from `Magwell` at the loading port; the LMG's quick-change barrel is
`BarrelMount/StockBarrel`; folding/removable stocks are `StockMount/StockStock`.
