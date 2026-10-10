# content/data: provenance notes (ENV B)

Every balance number lives in these `.tres` files. **V** = taken from `docs/research/pd2_research.md`
or `docs/design/pd2_fidelity.md`; **◇** = invented or interpolated by us (tune freely).
Names, makers and models are original. Display units: PD2 (damage, armor, health).

## Weapons: `weapons/kestrel_p9.tres` (Halvard Arms Kestrel P9, 9 mm compact, SECONDARY, PISTOL, semi)
Modeled on PD2's starter pistol feel.
| Stat | Value | Src |
|---|---|---|
| damage / headshot | 35 / ×2.0 | starter-pistol feel ◇ |
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
Delta resources are `WeaponStats` with only changed fields, **but** every delta must set
`pellets = 0`, `falloff_start_m = 0`, `falloff_end_m = 0`, `equip_time_s = 0`, `ads_time_s = 0`
(those schema defaults are non-zero and `plus()` adds them). `test_mod_deltas_zero_non_zero_defaults`
enforces it.
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
| Breacher Plate | Improved CTV | 170 | 1 | −0.55 | skill-gated in PD2; `unlock_level 0` until the schema has a skill gate (lead question) |

## Deployables: `deployables/`
Doctor bag 2 uses (V), ammo bag 4 uses = 400% (V), body bag case 3 bags (V, research §1.7).
Deploy time 2.0 s for all three ◇. Params: doctor `{heal_frac 1.0, resets_downs}`, ammo
`{refill_frac_per_use 1.0}` ◇, case `{bags 3}`.

## Loot: `loot/`
Jewelry $1,000 LIGHT ◇, cash $1,200 LIGHT ◇, body bag $0 MEDIUM (S10.1). Base values before the
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
