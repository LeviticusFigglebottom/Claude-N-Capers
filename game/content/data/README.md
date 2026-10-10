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
P2 heists (PD2 bag shape: a heavier bag is worth more per bag, but less per second of carrying):
| id | weight | value | heist | src |
|---|---|---|---|---|
| `loot.cash_bricks` | MEDIUM | $1,600 | Night Deposit (Co-op pallet) | weight: lead (B4-09; the C doc asked HEAVY); value ◇ (1.33× LIGHT cash) |
| `loot.ledger_laptop` | LIGHT | $2,000 | Shadow Ledger (required) | weight V (doc QC-15); value ◇ (one bag, the key to the data) |
| `loot.ledger_drives` | MEDIUM | $1,800 | Shadow Ledger (required ×2, 3 spawn) | weight V (doc); value ◇ |
| `loot.ledger_books` | MEDIUM | $2,400 | Shadow Ledger (optional, time-locked safe) | weight: lead (B4-10; the doc asked LIGHT); value ◇ (greed bag: costs a keycard + a time-lock hold) |
| `loot.painting` | MEDIUM | $1,500 | Shadow Ledger art hall ×2, reusable by `gallery_night` | weight V (doc); value ◇ |
Shadow Ledger's archive safe uses the existing `loot.cash`.

**Small loot (QB-52, D-049): no loot def.** Small loot (cash stacks, jewellery, deposit-box contents
picked up by hand, not bagged) gets its value from the map prefab that spawns it (ENV A/C), which
reports the sum in `HeistResult.small_loot`; `PayoutCalculator` scales it by difficulty
(`PayoutTweak.small_loot_scaled_by_difficulty`). `loot.small_loot_value_mult` (Plain Sight aced) belongs
to the pickup side (ENV A). Per-item ranges before the difficulty
multiplier (recorded from the G0 docs): **Night Deposit $800–2,400**, **Shadow Ledger $1,200–3,000**.

## Difficulty: `difficulty/` (Routine, Tense, Hazardous, Brutal, Lethal, Cataclysm = PD2 Normal, Hard, Very Hard, Overkill, Mayhem, Death Sentence)
| | Rou | Ten | Haz | Bru | Let | Cat | Src |
|---|---|---|---|---|---|---|---|
| payout_mult | 1 | 2 | 2.6 | 4.2 | 7.2 | 9.2 | V (S10.4) |
| xp_mult | 1 | 2 | 5 | 10 | 11.5 | 14 | V (§2.6; Mayhem 11.5 picked from the CONFLICT) |
| enemy_cap | 16 | 20 | 24 | 28 | 32 | 36 | ◇ |
| assault_intensity | 0.6 | 0.75 | 0.9 | 1.0 | 1.15 | 1.3 | ◇ |
| bulwark/stinger/corpsman/phantom/wrecker caps | 2/1/1/0/1 ◇ | 3/1/2/0/1 ◇ | 4/2/2/1/2 ◇ | 4/2/3/2/2 V | 4/3/3/2/2 V(taser)/◇ | 4/3/3/2/3 V(dozer)/◇ | §2.6, L4.11 |
| longshot cap | 1 | 2 | 2 | 3 | 3 | 4 | lead QA-31 (also bounded by free perches) |
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
  suppression capped at 43 (V cap). `damage_pellet_exponent = 1` (D-034 QB-43): shown damage = pellet
  damage x pellets, so the Plowman 12 (16 x 10) shows 160 like a PD2 shotgun.
* `perk_points.tres` (`PerkPointTweak`, D-034 QB-45): `xp_per_perk_point = 500` ◇ (ours, accepted
  by the lead). Perk points = floor(all XP / 500), derived, never stored (PerkProgress.earned). The
  dev switch `dev_unlock_all_perks` is UI data and stays in `data/ui/progression_ui.tres`.
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
| `plowman_12` Plowman 12 | SHOTGUN / PRI / pump | 16 × 10 | 70 | 6 / 48 | 8 / 22 / 0.15 | 21 | 3.3 / 3.8 | 28000 / 8 |
| `rampart_lmg` Rampart | LMG / PRI / auto | 48 | 750 | 100 / 300 | 25 / 45 / 0.6 | 2 | 5.6 / 6.6 | 54000 / 18 |
| `heron_308` Heron .308 | SNIPER / PRI / bolt | 230 | 50 | 5 / 40 | 25 / 60 / **1.35** (gains) | 6 | 3.0 / 3.8 | 48000 / 14 |
Heron: `armor_pierce` 1.0, `shield_pierce`, `wall_pierce` (L3.4). Threat (suppression) 11 / 10 /
12 / 18 / 22 / 30; noise 70 / 60 / 70 / 80 / 90 / 100 m; spreads, recoil, equip/ADS times and ammo
pickups are in the .tres files (all ◇). Shell-by-shell reload (D-034 QB-43): the Plowman 12 sets
`reload_start_s` 0.4, `reload_per_round_s` 0.5, `reload_end_s` 0.4 ◇; ENV A loads one shell per
`reload_per_round_s` and firing interrupts it. The whole-reload fields stay consistent for the UI and
for any code that reads them: `reload_empty_time_s` = start + mag x per_round + end (6 shells: 3.8 s),
`reload_time_s` = start + (mag - 1) x per_round + end (one shell left: 3.3 s); the Extended Tube adds
2 x 0.5 = 1.0 s to both. The Heron .308 has a detachable 5-round box magazine, so it keeps a magazine
reload (the three fields 0). `test_shell_by_shell_reload_fields` checks this.

Mods (stock defaults have a zero delta, except the Heron's stock 4x scope = magnification 4.0):
| Weapon | Optional mods (type: main effect / downside) |
|---|---|
| Warden | `w45_suppressor` (SUPP: silent, threat 0 / dmg −4, conc −3, ADS +0.05), `w45_compensator` (BARREL_EXT: kick −0.5 / conc −2; **conflicts** with the suppressor), `w45_reflex_sight` (SIGHT: ADS spread −0.15, 1.1× / conc −1), `w45_extended_mag` (MAG: +4 / conc −2, reload +0.25) |
| Hornet | `hornet_suppressor` (silent, threat 0 / dmg −3, conc −2), `rail_reflex_sight`, `hornet_extended_mag` (+15 / conc −3, reload +0.4), `hornet_stock_folded` (STOCK: conc +3 / kick +0.35, horiz +0.2, ADS spread +0.3) |
| Corsair | `corsair_suppressor` (silent, threat 0 / dmg −4, conc −3), `rail_reflex_sight`, `rail_prism_scope` (3×, ADS spread −0.25 / conc −3, ADS +0.08), `corsair_vertical_grip` (FOREGRIP: kick −0.2 / conc −1, ADS +0.03), `corsair_extended_mag` (+10 / conc −2) |
| Plowman | `plowman_choke` (BARREL_EXT: spreads −0.5 / conc −1), `rail_reflex_sight`, `plowman_extended_tube` (+2 / conc −2, reload +1.0 = 2 shells), `plowman_pistol_grip` (STOCK: conc +5, hip −0.3 / kick +0.8, ADS spread +0.5) |
| Rampart | `rampart_short_barrel` (BARREL: conc +4 / ADS spread +0.4, kick +0.15), `rail_reflex_sight`, `rail_prism_scope`, `rampart_bipod` (FOREGRIP: kick −0.35 / conc −2, ADS +0.05), `rampart_box_200` (+100 / conc −3, reload +1.2, equip +0.1) |
| Heron | `heron_suppressor` (silent, threat 0 / dmg −20, conc −3), `heron_scope_10x` (8× / conc −2, ADS +0.08), `heron_bipod` (kick −0.6 / conc −2), `heron_extended_mag` (+5 / conc −2) |
Shared rail optics: `rail_reflex_sight` (ADS spread −0.1, 1.15× / conc −1, ADS +0.02, $3000) and
`rail_prism_scope` ($6000). Every suppressor's `suppression` delta equals minus its weapon's base
threat, so a resolved suppressed weapon has threat 0 (L3.5). `test_armory.gd` checks the shapes.
Models: `tools/blender/weapons/<weapon>.py` + `<weapon>_mods.py` (+ `rail_optics_mods.py`), helpers
`_common.py` and `_<weapon>.py`; previews `game/assets/weapons/<weapon>_preview_*.png`. Tube
magazines hang from `Magwell` at the loading port; the LMG's quick-change barrel is
`BarrelMount/StockBarrel`; folding/removable stocks are `StockMount/StockStock`.

## Armory batch 2 (B4-12): `weapons/` + `mods/`
Ten weapons toward the P5 launch target (36). Makers are the existing original ones. Shapes are V
(L3.2 falloff by class, L3.4 sniper piercing, L3.5/L3.7 suppressors, P6 trade-offs, PD2 slots incl. a
secondary shotgun and primary akimbo pairs); every number is ◇. Headshot bonus 1.0 for all (D-026).

| Weapon | Class / slot / modes / anim set | Dmg × pellets | RPM | Mag / total | Falloff start/end/min | Conc | Reload | Threat | Price / unlock |
|---|---|---|---|---|---|---|---|---|---|
| `drover_762` Drover 762 (Graff-Lindqvist) | AR / PRI / auto, semi / rifle | 80 | 600 | 30 / 120 | none | 16 | 2.6 / 3.4 | 14 | 42000 / 9 |
| `mastiff_45` Mastiff .45 (Tillman) | SMG / SEC / auto, semi / smg | 52 | 620 | 25 / 150 | 15 / 32 / 0.5 | 22 | 2.4 / 3.2 | 12 | 30000 / 11 |
| `anvil_lmg` Anvil (Tillman) | LMG / PRI / auto / lmg | 64 | 600 | 100 / 250 | 25 / 45 / 0.6 | 1 | 6.0 / 7.0 | 26 | 68000 / 26 |
| `condor_50` Condor .50 (Marrow & Kell) | SNIPER / PRI / bolt / sniper | 520 | 35 | 5 / 25 | 30 / 70 / **1.5** | 0 | 3.6 / 4.6 | 40 | 80000 / 32 |
| `mule_12` Mule 12 (Tillman) | SHOTGUN / **SEC** / pump / shotgun | 13 × 10 | 72 | 5 / 35 | 6 / 18 / 0.12 | 25 | shell: 0.4 + n × 0.4333 + 0.4 (1.2 empty) = 2.97 / 3.77 | 16 | 26000 / 13 |
| `akimbo_warden_45` Warden .45 Pair (Marrow & Kell) | PISTOL / **PRI** / semi / akimbo | 62 | 400 | 16 / 128 | 15 / 30 / 0.5 | 23 | 3.0 / 3.6 | 11 | 36000 / 16 |
| `marshal_357` Marshal .357 (Marrow & Kell) | PISTOL / SEC / semi / revolver | 155 | 330 | 6 / 54 | 18 / 35 / 0.5 | 26 | 2.4 / 2.4 (speedloader) | 12 | 30000 / 10 |
| `falchion_dmr` Falchion DMR (Brannock) | AR / PRI / semi / rifle | 150 | 420 | 20 / 80 | none | 8 | 2.7 / 3.5 | 18 | 52000 / 20 |
| `wasp_pdw` Wasp PDW (Brannock) | SMG / SEC / auto, semi / smg | 30 | 850 | 30 / 210 | 16 / 32 / 0.5 | 27 | 2.2 / 2.9 | 9 | 28000 / 7 |
| `sparrow_mp` Sparrow MP (Halvard Arms) | PISTOL / SEC / auto, semi / pistol | 30 | 880 | 20 / 140 | 12 / 26 / 0.45 | 28 | 1.8 / 2.4 | 7 | 22000 / 5 |
Condor: `armor_pierce` 1.0, `shield_pierce`, `wall_pierce` (L3.4); pickup 0.5–1.5 rounds. Spreads, recoil,
equip/ADS times, noise and pickups are in the .tres files (all ◇).

Rules the numbers respect (test-enforced in `test_armory_batch2.gd`): ENV D's shared viewmodel clips
(characters.md v1.4) cap full-auto smg/rifle/lmg sets at ≤ 900 rpm (3 f fire clip ≤ 1.5 shot intervals),
the shotgun set at ≤ 75 rpm (24 f pump clip) and the sniper set at ≤ 50 rpm (9 f fire + 27 f bolt), so the
DMR uses the rifle set and there is no semi-auto shotgun yet. The Mule loads shells one by one with the
Plowman's clip timings (D-044/D-045; the resolver derives the totals, no raw reload deltas on its mods).
The Marshal uses a speedloader (PD2 Bronco): a magazine-style reload (per-round fields 0, tactical =
empty) and no suppressor. The Warden .45 Pair is one WeaponDef (PISTOL class, primary slot like PD2
akimbos, D-050) with `anim_set = akimbo`, the pistol cue family, twice the Warden's magazine and worse
spread and concealment. `akimbo = true` (D-050); the `akimbo` modifier qualifier derives from it.

Mods (stock defaults have a zero delta, except the Condor's stock 6x scope = magnification 6.0):
| Weapon | Optional mods (type: main effect / downside) |
|---|---|
| Drover | `drover_suppressor` (silent, threat 0 / dmg −6, conc −3), `rail_reflex_sight`, `rail_prism_scope`, `drover_folding_stock` (STOCK: conc +4 / kick +0.4, horiz +0.2, ADS spread +0.4), `drover_extended_mag` (+10 / conc −2, reload +0.3) |
| Mastiff | `mastiff_suppressor` (silent / dmg −4, conc −3), `rail_reflex_sight`, `mastiff_vertical_grip` (kick −0.2 / conc −1, ADS +0.03), `mastiff_extended_mag` (+10 / conc −2, reload +0.3) |
| Anvil | `anvil_short_barrel` (BARREL: conc +4 / ADS spread +0.4, kick +0.15), `rail_reflex_sight`, `rail_prism_scope`, `anvil_bipod` (kick −0.4 / conc −2, ADS +0.05), `anvil_box_150` (+50 / conc −3, reload +0.8, equip +0.1) |
| Condor | `condor_suppressor` (silent / dmg −40, conc −4, ADS +0.08), `condor_scope_12x` (12× / conc −2, ADS +0.1), `condor_bipod` (kick −1.0 / conc −2, ADS +0.05), `condor_extended_mag` (+3 / conc −2, reload +0.4) |
| Mule | `rail_reflex_sight`, `mule_folding_stock` (STOCK, the Mule ships stockless: kick −0.8, ADS spread −0.4 / conc −4, equip +0.05), `mule_extended_tube` (+2 shells / conc −2; reload through mag only) |
| Warden Pair | `akimbo_w45_suppressor` (silent / dmg −4, conc −4), `akimbo_w45_compensator` (kick −0.5 / conc −3; **conflicts** with the suppressor), `akimbo_w45_reflex_sight` (ADS spread −0.15, 1.1× / conc −2), `akimbo_w45_extended_mag` (+8 / conc −3, reload +0.4); all reuse the Warden's mod glbs |
| Marshal | `marshal_long_barrel` (BARREL: dmg +15, ADS spread −0.2 / conc −3, equip +0.05), `marshal_snub_barrel` (BARREL: conc +3 / dmg −15, ADS spread +0.3, kick +0.3), `marshal_rubber_grip` (GRIP: kick −0.35 / conc −1), `marshal_reflex_sight` (ADS spread −0.15, 1.1× / conc −1) |
| Falchion | `falchion_suppressor` (silent / dmg −10, conc −3), `rail_reflex_sight`, `rail_prism_scope`, `falchion_bipod` (kick −0.5 / conc −2, ADS +0.05), `falchion_extended_mag` (+5 / conc −2, reload +0.25) |
| Wasp | `wasp_suppressor` (silent / dmg −2, conc −2), `rail_reflex_sight`, `wasp_end_cap` (STOCK removed: conc +2 / kick +0.3, horiz +0.2, ADS spread +0.4), `wasp_extended_mag` (+10 / conc −2, reload +0.3) |
| Sparrow | `sparrow_suppressor` (silent / dmg −2, conc −2), `sparrow_reflex_sight` (ADS spread −0.15, 1.1× / conc −1), `sparrow_wire_stock` (STOCK: kick −0.35, horiz −0.25 / conc −3, equip +0.05), `sparrow_extended_mag` (+12 / conc −3, reload +0.35) |
Every suppressor's `suppression` delta equals minus its weapon's threat (L3.5). Mod prices are ◇.

Models: `tools/blender/weapons/<weapon>.py` + `<weapon>_mods.py`, helpers `_<weapon>.py`; the pair is
`akimbo_warden_45.py` (one Warden + an `Offhand` marker; `WeaponVisual` instances the gun twice and
mirrors the mods). Animated parts: `Pump` (Mule), `Bolt` (Condor; origin on the bore axis, the Heron's
bolt now too), `FeedCover` (Anvil, rear hinge, D-044), `Slide` (Sparrow), and the revolver's `Crane`
(hinge pivot; +80° about local Z swings the cylinder out left) with `Crane/Cylinder` (60° per shot) and
the speedloader `Magwell` on the cylinder. Stock parts beyond sight/magazine: `StockStock` (Drover walnut
stock, Mastiff wire stock, Wasp collapsed stock), `StockBarrel` (Anvil, Marshal), `StockGrip` (Marshal).
Previews: `game/assets/weapons/<weapon>_preview_*.png`.
