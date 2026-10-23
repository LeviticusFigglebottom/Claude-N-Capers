# Perk decks (B4-02): data layout, PARAMS schemas, granted keys

Owner: ENV B. Status: **approved (D-031, QB-33..37).** This file is the authoritative param schema for
ENV A (D-031); changes go through the lead. ENV A implements the mechanics.

Spec: pd2_fidelity.md P4 and the P-decks table. Reference: pd2_research.md §3.2 and Appendix B.
Data: `game/content/data/perks/<deck>.tres` (`PerkDeckDef`, id `perk.<deck>`). Tests:
`game/tests/b/test_perk_decks.gd`, `game/tests/b/test_perk_resolver.gd`.

## Layout

* 14 decks, each with 9 cards `{name, desc, cost, grants}`. Costs follow PD2: 200, 300, 400, 600,
  1000, 1600, 2400, 3200, 4000 (13,700 per deck).
* Cards 1, 3, 5, 7 and 9 are unique to the deck. Cards 2, 4, 6 and 8 are the shared cards, and they
  are identical in every deck, including the string keys:

| # | Ours | PD2 | Grants |
|---|---|---|---|
| 2 | Headhunter | Helmet Popping | `weapon.headshot_mult.all` 1.25 |
| 4 | Low Profile | Blending In | `stealth.concealment_add.all` 1, `progression.xp_mult` 1.45, `movement.armor_penalty_mult` 0.85 |
| 6 | Go Bag | Walk-in Closet | `weapon.ammo_pickup_mult.all` 1.35, `deploy.armor_bag` true |
| 8 | Hustle | Fast and Furious | `weapon.damage_mult.all` 1.05, `interaction.doctor_bag_speed_mult` 0.8333 (20% faster) |
| 9 | (completion bonus) | Deck Completion Bonus | `progression.card_drop_quality_add` 0.1, added to every deck's own card 9 |

* Strings: `perk.<deck>.name` and `perk.<deck>.desc` for the deck, and
  `perk.<deck>.card<n>.name/.desc` for unique cards. Shared cards use
  `perk.shared.card<n>.name/.desc`. The completion bonus line is `perk.shared.completion.desc`
  (the UI shows it under card 9). `PerkDeckDef.display_name` is an English debug fallback, and
  `description` holds the strings key.
* `LoadoutResolver.resolve_modifiers` merges cards `1..min(perk_deck_cards, 9)` of the active deck,
  in order: MULT multiplies, ADD sums, FLAG ors, PARAMS last wins. A LIST grant on a card becomes its own
  entry tagged `"_source": &"<deck id>.card<n>"` (no deck grants one today; skills.md "LIST keys").
* `team.*` grants of the unlocked cards are left out of the personal modifiers and returned by
  `LoadoutResolver.team_modifier_sources(loadout)` as one TEAM source `&"team_perk.<deck>"` (e.g.
  `team_perk.foreman`), so two players with the same deck do not stack (D-031 QB-35). For the whole
  crew, `LoadoutResolver.crew_team_modifier_sources(loadouts)` (B4-14) keeps the copy with the most
  unlocked cards (or the aced team skill) instead of whichever loadout was set last.

### Authoring rules

1. **PARAMS re-grant the full dict.** A PARAMS key is last-granted-wins, and the resolver does not
   merge fields. A card that changes a deck mechanic therefore grants the complete updated dict:
   all earlier fields plus the changed or new ones. `test_params_regrants_carry_full_dict`
   enforces this (a later grant must keep every field of the earlier grant). Fields that a later
   card switches on start at a neutral value when they are needed from card 1
   (`perk.infiltrator.close_range_dr` 0.0, `perk.anarchist.health_to_armor_*` 0.0).
2. **Cumulative MULTs are per-card ratios.** PD2 adds deck bonuses (Muscle +10/+10/+20/+60% =
   +100%), but our MULT type is a product. Each card therefore grants `cum(n) / cum(n−1)`, so after
   any number of unlocked cards the product equals PD2's cumulative value. Example: Bulk
   `defense.health_mult` is 1.1, 1.0909091, 1.1666667, 1.4285714, giving 1.1, 1.2, 1.4, 2.0. A
   skill's MULT on the same key still multiplies on top (D-031 QB-34: MULT stays multiplicative
   across sources, a deliberate departure from PD2's additive percentages).
3. **"Armor recovery rate +X%"** in PD2 shortens the armor regen *delay*. We grant
   `defense.armor_regen_delay_mult` 0.9 per +10%.
4. **Team keys** (`team.*`) are assumed to apply to every crew member, the granter included. Where
   the PD2 text gives a personal total ("crew +10%, you +20%"), the personal key carries the ratio
   (Foreman `defense.health_mult` 1.0909091 × `team.health_mult` 1.1 = 1.2). Confirmed by D-031 QB-35:
   TEAM sources apply to the granter; the deck's team grants go to TEAM source `team_perk.<deck>`.
5. "Medium range" or "close range" in PD2 text = 18 m (◇ PD2 `close_combat_distance` 1800 cm).
6. Deck throwables use `perk.throwable {item_id}`. The item ids `throwable.steady_flask` (Composure)
   and `throwable.boss_injector` (Overlord) must be authored by the armory task (B4-04).
7. ◇ = value not verified against PD2 source (research §5). The lead tunes these.

## Decks (summary)

| Deck | PD2 | Signature key | Generic keys used |
|---|---|---|---|
| Foreman | Crew Chief | `team.damage_reduction_hostage`, `team.*`, `perk.crew_chief` | `team.stamina_mult` 1.5, `team.health_mult` 1.1, `team.armor_mult` 1.05, `defense.health_mult`, `defense.armor_mult`, `ability.shout_range_mult` 1.25 |
| Bulk | Muscle | `perk.muscle` | `defense.health_mult` → 2.0 |
| Ironclad | Armorer | `perk.armorer` | `defense.armor_mult` → 1.35, `defense.armor_regen_delay_mult` 0.9, `team.armor_regen_delay_mult` 0.9 |
| Slipper | Rogue | `perk.rogue_dodge_stack` | `defense.dodge_add` 0.45, `weapon.armor_pierce_add.all` 0.25, `weapon.swap_speed_mult.all` 1.8 |
| Hustler | Crook | `perk.crook` | `defense.dodge_add` 0.15, `defense.armor_regen_delay_mult` 0.9 |
| Clean Sweep | Hitman / Sociopath | `perk.sociopath` | `defense.armor_mult` → 1.2, `defense.armor_regen_delay_mult` 0.9 |
| Prowler | Burglar | `perk.burglar` | `defense.dodge_add` 0.3, `stealth.body_bag_speed_mult` 0.8, `interaction.lockpick_speed_mult` 0.8, `stealth.pager_answer_speed_mult` 0.9, `movement.crouch_speed_mult` 1.1 |
| Knuckles | Infiltrator | `perk.infiltrator` | all (same names) |
| Bloodletter | Grinder | `perk.grinder` | `defense.health_mult` → 1.4, `weapon.armor_pierce_add.all` 0.2 |
| Composure | Stoic | `perk.stoic`, `perk.throwable` | none |
| Overclock | Anarchist | `perk.anarchist` | all (same names) |
| Incumbent | Ex-President | `perk.ex_president` | `defense.health_mult` → 1.4, `defense.dodge_add` 0.15 |
| Long Odds | Gambler | `perk.gambler` | `defense.health_mult` → 1.4 |
| Overlord | Kingpin | `perk.kingpin`, `perk.throwable` | `defense.health_mult` → 1.8 |
| Hacker (D-161) | Hacker | `stealth.pocket_ecm`, `perk.throwable` (`throwable.pocket_ecm`) | `defense.health_mult` → 1.2, `defense.dodge_add` 0.3 |
| Inkwork (D-162) | Yakuza | `perk.yakuza` | none |
| Road Crew (D-162) | Biker | `perk.biker` | none |
| Frenzy (D-162) | Maniac | `perk.maniac` | none |
| Veil (D-163) | Sicario | `perk.sicario`, `perk.throwable` (`throwable.smoke_bomb`) | `defense.dodge_add` 0.15 |
| Buddy System (D-163) | Tag Team | `perk.tag_team`, `perk.throwable` (`throwable.gas_dispenser`) | `defense.health_mult` → 1.4 |
| Lifeline (D-164) | Leech | `perk.leech`, `perk.throwable` (`throwable.leech_ampule`) | `defense.health_mult` → 1.4 |
| Understudy (D-164) | Copycat | `perk.copycat` + a chosen option per card + the mimicked deck's `mimic_grants` | per choice (default: `defense.health_mult` → 1.8) |

Notes on PD2 deviations:
* **Clean Sweep** merges Hitman and Sociopath (fidelity table). Its cards are: Sociopath Tension
  (card 1), Clean Hit (card 3), Overdose (card 5) and Showdown (card 7), then Hitman's Tooth and
  Claw (card 9). Sociopath's OVERDOG card is left out because Knuckles already has it.
* **Slipper**: Rogue's "80% faster swap" is a swap speed of 1.8 (◇ PD2 swap speed multiplier), not
  a swap time of ×0.2.
* **Hustler**: the vest bonus applies to the Light Vest, Patrol Vest and Heavy Vest only (D-031 QB-37:
  PD2 "ballistic vests" LBV/BV/HBV analogs). Suit, Flak Rig, Tactical Plate and Breacher Plate get nothing.
* **Bloodletter**: the PD2 Euphoria armor-pierce "20%" is read as the total (card 5 +0.1, card 9
  +0.1).
* **Incumbent**: card 5 gives +15 dodge (the PD2 note says Life of Ice gives 15, not 10).
* **Overclock**: the immunity cooldown on card 1 is 15 s (◇ PD2 text truncated, Armorer value).

## Proposed PARAMS schemas

All lengths are in meters, times in seconds, health and armor in PD2 display units. Fractions are
0..1. "Card" is the first card that sets the field. Later cards re-grant the full dict.

### `perk.crew_chief` (Foreman)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| team_dr | float | fraction | 0.08 | 1 | Damage reduction for every crew member. |
| self_low_health_threshold | float | fraction of max HP | 0.5 | 1 | Below this, the holder's own team_dr is multiplied. |
| self_low_health_dr_mult | float | × | 2.0 | 1 | Multiplier of team_dr for the holder below the threshold. |
| close_range_m | float | m | 18.0 ◇ | 3 | "Medium range" radius. |
| close_range_dr | float | fraction | 0.08 | 3 | Holder damage reduction while an enemy is within close_range_m (PD2 note: 8%, not 6%). |
| hostage_health_per | float | fraction | 0.06 | 9 | Crew max-health bonus per hostage. |
| hostage_stamina_per | float | fraction | 0.12 | 9 | Crew stamina bonus per hostage. |
| hostage_max_count | int | count | 4 | 9 | Hostages counted for the two fields above. |

Card 9 also grants `team.damage_reduction_hostage {absorb_per_hostage: 5.0, max_hostages: 4}` ◇ (D-056):
the crew absorbs 5 damage (display units) from every hit per hostage, counting up to 4 hostages. Card 3 grants `ability.shout_range_mult` 1.25 (personal).
Cards 3/5/7/9 `team.*` grants route to TEAM source `team_perk.foreman`.

### `perk.muscle` (Bulk)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| aggro_near_crew_mult | float | × | 1.15 | 3 | Enemy target-selection weight on the holder while within near_crew_m of a teammate. |
| near_crew_m | float | m | 8.0 ◇ | 3 | "Close to your crew members". |
| panic_chance | float | 0..1 | 0.1 ◇ | 7 | Chance per firearm hit to panic enemies (PD2 value unverified). |
| panic_radius_m | float | m | 6.0 ◇ | 7 | Panic radius around the hit enemy. |
| regen_fraction | float | fraction of max HP | 0.03 | 9 | Health restored per interval. |
| regen_interval_s | float | s | 5.0 | 9 | Regen interval. |

### `perk.armorer` (Ironclad)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| break_immunity_s | float | s | 2.0 | 7 | Health-damage immunity when armor reaches 0. |
| break_immunity_cooldown_s | float | s | 15.0 | 7 | Minimum time between immunities. |

Card 9's crew-wide armor regen delay (PD2 Liquid Armor) is the team key `team.armor_regen_delay_mult` 0.9
(TEAM source `team_perk.ironclad`, holder included). It replaced the former
`perk.armorer.team_regen_delay_mult` field at D-031, so card 9 no longer re-grants `perk.armorer`.

### `perk.rogue_dodge_stack` (Slipper)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| aggro_near_crew_mult | float | × | 0.85 | 3 | Target-selection weight near teammates (less likely to be targeted). |
| near_crew_m | float | m | 8.0 ◇ | 3 | As in perk.muscle. |

Dodge, swap speed and armor pierce use generic keys. The registry description ("dodge ramps on
miss") does not match PD2 Rogue; we suggest rewording it to "Slipper: reduced aggro near crew".

### `perk.crook` (Hustler)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| vest_armor_ids | Array[StringName] | ids | armor.light_vest, armor.patrol_vest, armor.heavy_vest | 3 | Armors that get the bonus (D-031 QB-37). |
| vest_dodge_add | float | 0..1 | 0.05 → 0.15 → 0.25 | 3/5/7 | Dodge added while wearing one of those armors (cumulative). |
| vest_armor_mult | float | × | 1.2 → 1.4 → 1.65 | 3/5/7 | Max armor multiplier while wearing one of them (cumulative). |

### `perk.sociopath` (Clean Sweep)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| kill_armor | float | armor | 30.0 | 1 | Armor restored per kill. |
| kill_armor_cooldown_s | float | s | 1.0 | 1 | Cooldown of kill_armor. |
| close_range_m | float | m | 18.0 ◇ | 3 | Medium range. |
| close_range_dr | float | fraction | 0.08 | 3 | Damage reduction while an enemy is within close_range_m. |
| melee_kill_health_fraction | float | fraction of max HP | 0.1 | 3 | Health on a melee kill. |
| melee_kill_cooldown_s | float | s | 1.0 | 3 | Cooldown of the melee heal. |
| close_kill_armor | float | armor | 30.0 | 5 | Extra armor for a kill within close_range_m (own 1 s cooldown, ◇ shared with kill_armor?). |
| close_kill_panic_chance | float | 0..1 | 0.75 | 7 | Chance that a kill within close_range_m spreads panic. |
| close_kill_panic_cooldown_s | float | s | 1.0 | 7 | Panic cooldown. |
| panic_radius_m | float | m | 6.0 ◇ | 7 | Panic radius around the killed enemy. |
| forced_regen_after_break_s | float | s | 1.5 | 9 | Armor starts regenerating this long after breaking, whatever the regen delay or damage taken. |

### `perk.burglar` (Prowler)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| still_aggro_mult | float | × | 0.9 → 0.85 → 0.8 | 3/5/7 | Target-selection weight while standing still or crouching. |
| still_regen_delay_mult | float | × | 0.8 | 9 | Armor regen delay multiplier while standing still or crouching. |

### `perk.infiltrator` (Knuckles)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| surrounded_min_enemies | int | count | 3 | 1 | Enemies within surrounded_radius_m needed for surrounded_dr. |
| surrounded_radius_m | float | m | 6.0 ◇ | 1 | "Surrounded" radius. |
| surrounded_dr | float | fraction | 0.12 | 1 | Damage reduction while surrounded. |
| melee_chain_mult | float | × | 10.0 | 1 | Melee damage of the 2nd and later hits inside the window. A miss resets the chain. |
| melee_chain_window_s | float | s | 1.0 → 7.0 | 1/5 | Window after a melee hit (PD2 hidden +6 s on Advanced Close Combat). |
| close_range_m | float | m | 18.0 ◇ | 1 | Medium range. |
| close_range_dr | float | fraction | 0 → 0.08 → 0.16 → 0.24 | 1/3/5/7 | Damage reduction while an enemy is within close_range_m. |
| melee_hit_heal_fraction | float | fraction of max HP | 0.2 | 9 | Heal on a melee hit. |
| melee_hit_heal_cooldown_s | float | s | 10.0 | 9 | Cooldown of that heal. |

### `perk.grinder` (Bloodletter)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| allowed_armor_ids | Array[StringName] | ids | tailored_suit, light_vest | 1 | The mechanic only works in these armors. |
| heal_per_tick | float | HP | 1 → 2 → 3 → 4 | 1/3/5/7 | Health per tick per stack. |
| tick_s | float | s | 0.3 | 1 | Tick interval. |
| duration_s | float | s | 3.0 → 4.2 | 1/9 | Lifetime of a stack. |
| stack_cooldown_s | float | s | 1.5 | 1 | Minimum time between new stacks (gained by damaging an enemy). |

### `perk.stoic` (Composure)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| delayed_fraction | float | fraction | 0.75 | 1 | Part of each hit converted into damage over time. The rest applies now. |
| dot_duration_s | float | s | 12.0 | 1 | Time over which the delayed part is applied. |
| flask_cooldown_s | float | s | 10.0 | 1 | Flask cooldown. Drinking cancels all pending DoT. |
| kill_cooldown_reduction_s | float | s | 1.0 | 1 | Flask cooldown reduction per kill. |
| armor_to_health | float | fraction | 1.0 | 3 | Fraction of armor removed and added to max health (1.0 = all). |
| auto_negate_after_s | float | s | 4.0 | 5 | Pending DoT is cancelled after this long without damage. |
| low_health_threshold | float | fraction | 0.35 | 7 | Below this, kills use the next field. |
| low_health_kill_cooldown_reduction_s | float | s | 2.0 | 7 | Flask cooldown reduction per kill at low health. |
| negate_heal_fraction | float | fraction | 0.5 | 9 | Heal by this part of the remaining DoT whenever DoT is cancelled. |

Card 1 also grants `perk.throwable {item_id: &"throwable.steady_flask"}`.

### `perk.anarchist` (Overclock)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| tick_by_armor | Dictionary[StringName, [float, float]] | armor, s | suit [1, 2] … breacher [6, 10] ◇ | 1 | Per armor id: [armor per tick, tick interval]. It replaces the normal delayed full regen with continuous ticks. |
| break_immunity_s | float | s | 2.0 | 1 | Health immunity on armor break. |
| break_immunity_cooldown_s | float | s | 15.0 ◇ | 1 | Its cooldown. |
| health_to_armor_fraction | float | fraction | 0 → 0.5 | 1/3 | Part of max health removed. |
| health_to_armor_ratio | float | × | 0 → 1.0 → 1.1 → 1.2 | 1/3/5/7 | Armor gained per health removed. |
| damage_dealt_armor | float | armor | 30.0 | 9 | Armor gained when dealing damage (PD2 note: 30, not 10). |
| damage_dealt_armor_cooldown_s | float | s | 1.5 | 9 | Its cooldown. |

### `perk.ex_president` (Incumbent)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| store_per_kill | float | HP | 4 → 8 → 12 | 1/3/7 | Health banked per crew kill while the holder's armor is above 0. |
| max_store_by_armor | Dictionary[StringName, float] | HP | suit 24 … breacher 60 ◇ | 1 | Bank cap per armor id (PD2 table unverified). |
| max_store_mult | float | × | 1.0 → 1.5 | 1/5 | Multiplier of the bank cap. |
| kill_regen_speedup_fraction | float | fraction | 0.1 ◇ | 9 | Per kill, cut this fraction × (1 − armor_tier/6) from the remaining armor regen delay. Reset when armor recovers. |

The bank pays out when armor breaks and starts to regenerate.

### `perk.gambler` (Long Odds)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| heal_min / heal_max | float | HP | 16 / 24 | 1 | Ammo pickup heal, rolled on `GameRng.stream(&"perks")`. |
| heal_bonus | float | HP | 0 → 8 → 16 | 1/7/9 | Flat amount added to the heal. |
| cooldown_s | float | s | 3.0 | 1 | Heal cooldown. |
| lowest_health_bonus_per_ally | float | fraction | 0.2 | 1 | +heal per teammate with more health than the holder. |
| lowest_health_max_stacks | int | count | 3 | 1 | Cap of that bonus. |
| team_ammo_share | float | fraction of a pickup | 0.5 | 3 | Ammo that the holder's pickups give each teammate. |
| team_ammo_share_cooldown_s | float | s | 5.0 | 3 | Its cooldown. |
| team_heal_fraction | float | fraction | 0.5 | 5 | Teammates heal for this part of the holder's pickup heal. |

### `perk.kingpin` (Overlord)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| heal_fraction | float | fraction | 0.75 | 1 | Part of damage taken that is healed while the injector is active. |
| duration_s | float | s | 6.0 | 1 | Injector effect duration. |
| cooldown_s | float | s | 30.0 | 1 | Injector cooldown. |
| kill_cooldown_reduction_s | float | s | 1.0 | 1 | Cooldown reduction per kill. |
| draws_aggro | bool | flag | true | 5 | Nearby enemies prefer the holder while active. |
| low_health_threshold | float | fraction | 0.5 | 7 | Below this, the heal is boosted. |
| low_health_heal_bonus | float | fraction | 0.25 | 7 | heal_fraction × (1 + bonus) below the threshold. |
| overheal_per_cooldown_s | float | HP | 50.0 | 9 | Every this much healing while at full health cuts 1 s from the cooldown (PD2 note: 50, not 5). |

Card 1 also grants `perk.throwable {item_id: &"throwable.boss_injector"}`.

### `stealth.pocket_ecm` (Hacker, D-161)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| charges | int | count | 2 | 1 | Charges; each one recharges on its own timer, one after another. |
| duration_s | float | s | 6.0 | 1 | Jam (stealth) / feedback (loud) duration of one charge. |
| cooldown_s | float | s | 100.0 | 1 | Recharge time of one charge. |
| kill_cooldown_reduction_s | float | s | 6.0 | 1 | Recharge cut per holder kill. |
| kill_heal | float | HP | 20.0 | 5 | A holder kill while the feedback is active heals this. |
| kill_dodge_add / kill_dodge_s | float | fraction / s | 0.2 / 30.0 | 7 | A holder kill while jamming or feedback gives this dodge for this long. |
| crew_kill_heal | float | HP | 10.0 | 9 | A teammate's kill while the holder's feedback is active heals that teammate this. |

Card 1 also grants `perk.throwable {item_id: &"throwable.pocket_ecm"}`.

### `perk.yakuza` (Inkwork, D-162)
`s` = 0 at full health, rising linearly to 1 at `low_health_threshold` and staying 1 below it (PD2 Irezumi).
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| low_health_threshold | float | fraction | 0.25 → 0.5 | 1, 9 | Health fraction where the bonuses peak. |
| armor_regen_max_add | float | fraction | 0.2 / 0.4 / 0.6 | 1, 5, 7 | Armor recovery rate +add × s: the regen delay counts down (1 + add × s) times as fast (rule 3). |
| move_speed_max_add | float | fraction | 0.0 → 0.2 | 3 | Movement speed × (1 + add × s). |
| blocks_regen | bool | flag | true | 1 | While s > 0, other health regeneration (`defense.health_regen_per_sec`) is off (PD2 Koi: "negates third party regeneration"). |

### `perk.biker` (Road Crew, D-162)
Any crew kill (the holder's or a teammate's) is a proc: +heal health and +armor armor (PD2 display units),
at most `max_procs` within a sliding `window_s`. `missing_h` / `missing_a` = whole 10% steps of missing health / armor.
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| heal / armor | float | HP | 5.0 / 5.0 | 1 | Base gain per proc. |
| max_procs / window_s | int / float | count / s | 4 / 4.0 | 1 | Rate limit. |
| armor_per_missing_health | float | armor | 1.0 | 3 | armor + this × missing_h. |
| window_cut_per_missing_health | float | s | 0.1 | 5 | window_s − this × missing_h. |
| heal_per_missing_armor | float | HP | 1.0 | 7 | heal + this × missing_a. |
| window_cut_per_missing_armor | float | s | 0.1 | 9 | window_s − this × missing_a (both cuts add). |

### `perk.maniac` (Frenzy, D-162)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| conversion | float | fraction | 1.0 | 1 | Stacks gained = damage dealt (PD2 display units) × this. |
| gain_cap / gain_window_s | float | stacks / s | 240.0 / 4.0 | 1 | At most this many stacks gained per window. |
| max_stacks | float | stacks | 600.0 | 1 | Cap. |
| stacks_per_absorb | float | stacks | 30.0 → 25.0 | 1, 7 | 1 damage absorbed from every hit per this many stacks (floor). |
| decay_fraction / decay_flat / decay_interval_s | float | fraction / stacks / s | 0.8 / 120 / 8 → 0.6 / 40 / 8 ◇ | 1, 5 | Every interval: stacks −= stacks × fraction + flat (min 0). Card 1's 80% + 120 is from memory (research text truncated) ◇. |
| team | bool | flag | false → true | 3 | Teammates also absorb from the holder's stacks; with several holders, only the best absorb counts. |
| self_absorb_mult | float | mult | 1.0 → 2.0 | 9 | The holder's own absorb × this (teammates keep ×1). |

### `perk.sicario` (Veil, D-163)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| smoke_duration_s / smoke_radius_m | float | s / m | 10.0 / 4.0 ◇ | 1 | The smoke bomb's cloud. |
| cooldown_s / kill_cooldown_reduction_s | float | s | 60.0 ◇ / 1.0 ◇ | 1 | Recharge after the cloud ends; cut per holder kill. |
| in_smoke_dodge_add | float | fraction | 0.5 | 1 | Holder and allies inside the cloud avoid this share of bullets. |
| enemy_accuracy_mult | float | mult | 0.5 | 1 | Accuracy of enemies inside the cloud. |
| twitch_dodge_add / twitch_lockout_s | float | fraction / s | 0.0 → 0.2 / 4.0 | 3 | Each hit taken adds this dodge (stacking) until a dodge resets it; then no stacking for the lockout. |
| dodge_restores_armor | bool | flag | false → true | 7 | A dodge refills the holder's armor (◇ full refill, LEAD D-163). |
| in_smoke_effect_mult | float | mult | 1.0 → 2.0 | 9 | While the holder is in the cloud, the deck's own effects (twitch, card 5 dodge) × this. |
| ally_in_smoke_dodge_add | float | fraction | 0.0 → 0.1 | 9 | Extra dodge for allies inside the cloud. |

Card 1 also grants `perk.throwable {item_id: &"throwable.smoke_bomb"}`; card 5 is the generic `defense.dodge_add` 0.15.

### `perk.tag_team` (Buddy System, D-163)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| tag_range_m | float | m | 18.0 | 1 | The gas dispenser tags the ally under the crosshair within this range with line of sight. |
| duration_s / cooldown_s | float | s | 11.0 ◇ / 60.0 ◇ | 1 | Pairing time; recharge. |
| kill_extend_s | float | s | 1.3 ◇ | 1 | Each holder kill extends the pairing. |
| holder_kill_heal / tagged_kill_heal | float | HP | 15.0 / 7.5 | 1 | Each kill by either partner heals the holder / the tagged ally. |
| kill_absorb / max_absorb | float | HP | 0 → 2.0 / 0 → 20.0 | 5 | Holder absorb per pair kill, capped, kept until the dispenser has recharged. |
| tagged_kill_cooldown_cut_s | float | s | 0 → 2.0 | 9 | Each tagged-ally kill while paired cuts the recharge. |

Card 1 also grants `perk.throwable {item_id: &"throwable.gas_dispenser"}`; cards 3 / 7 are `defense.health_mult` 1.2 / 1.1666667.

### `perk.leech` (Lifeline, D-164)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| duration_s / cooldown_s | float | s | 6.0 → 10.0 / 40.0 | 1, 5 | The ampule's effect and recharge. |
| kill_cooldown_reduction_s | float | s | 0 → 1.0 | 5 | Recharge cut per holder kill. |
| activate_heal_fraction | float | fraction | 0.4 | 1 | On use, heal this share of max health. |
| armor_off | bool | flag | true | 1 | Armor is disabled while active. |
| segment_fraction / kills_per_segment | float / int | fraction / kills | 0.2 → 0.1 ◇ / 2 | 1, 9 | While active, health is in slices of this share of max; a hit removes one whole slice; this many kills restore one. |
| team_heal_on_damage_fraction | float | fraction | 0.05 → 0.1 | 1, 5 | Taking damage while active heals each teammate this share of their max health. |
| no_bleedout / zero_health_speed_mult | bool / float | flag / mult | false → true / 1.0 → 0.2 | 3 | While active the holder can't go down; at 0 health their speed × this. |
| usable_while_downed | bool | flag | false → true | 9 | Usable while downed: a temporary revive until it ends; a revive given or a doctor bag used before then keeps the holder up if health > 0. |

Card 1 also grants `perk.throwable {item_id: &"throwable.leech_ampule"}`; cards 3 / 7 are `defense.health_mult` 1.2 / 1.1666667.

### `perk.copycat` (Understudy, D-164)
| Field | Type | Unit | Value | Card | Semantics |
|---|---|---|---|---|---|
| tactical_reload_kills / quick_swap_window_s | int / float | kills / s | 10 / 3.0 | 1 | This many kills with the equipped weapon refill the holstered one's magazine (from reserve ◇); swapping to it within the window is near instant. |
| headshot_heal / headshot_heal_cooldown_s | float | HP / s | 0 → 10.0 / 2.0 | 3 | Any headshot hit heals, at most once per cooldown. |
| dodge_ricochet / ricochet_cooldown_s | bool / float | flag / s | false → true / 0.45 | 5 | A dodged bullet hits its shooter for its damage (◇), at most once per cooldown (0.35 s on the top difficulties, A's tweak). |
| grace_health_threshold / grace_immunity_s / grace_cooldown_s | float | fraction / s / s | 0.5 / 0 → 2.0 / 15.0 | 7 | Dropping below the threshold gives this long without health damage, at most once per cooldown. |

**Choices (cards 1/3/5/7, D-164).** Each of these cards also carries `"choices"`; the player picks one per card
(`Loadout.perk_choices`, card index → option; default 0): Thick Skin `defense.health_mult` 1.2, Plated
`defense.armor_mult` 1.05, Quick Step `defense.dodge_add` 0.05, Low Rider `movement.crouch_speed_mult` 1.1 +
`loot.carry_speed_penalty_mult` 0.9. The same MULT picked on several cards stacks additively like PD2: LoadoutResolver
grants the n-th pick the cumulative ratio (rule 2 at resolve time), so four health picks give 1.8.

**Mimic (card 9, D-164).** Card 9 carries `"mimic": true` and grants `Loadout.perk_mimic_deck`'s
`PerkDeckDef.mimic_grants`: that deck's card 9 as standalone keys. A PARAMS mimic sets every field the card 9 did not
change to its neutral value, so only that card's effect runs. Mimicable (15): Hustler, Ironclad, Slipper, Prowler,
Bulk (the card's own +60% health and regen), Clean Sweep, Foreman, Knuckles, Incumbent, Long Odds, Overclock
(`tick_by_armor` {} = keep normal armor regen; A), Bloodletter (the whole card-9 grinder, since its card-9 change is
only a duration), and the standalone variants Frenzy (PD2's Hysteria Stacks mimic), Inkwork ◇ and Road Crew ◇.
Not mimicable (their card 9 needs the deck's own item, as in PD2): Composure, Overlord, Hacker, Veil, Buddy System,
Lifeline, and Understudy itself. `perk.<deck>.mimic.desc` describes each mimic for the deck screen.
A mimicked MULT bonus **adds** to the picks (LEAD r304, PD2 sums armor / health multipliers): card-1 armor +5% plus
Ironclad's +5% is ×1.10, not 1.05 × 1.05. LoadoutResolver grants (total + m) / total, where total is the key's
running product (1 + the summed bonuses). Crew-wide `team.*` keys go to the TEAM source unchanged.

### `perk.throwable` (Composure, Overlord)
| Field | Type | Semantics |
|---|---|---|
| item_id | StringName | Throwable id that replaces the equipped throwable while the deck is active. |

### `team.damage_reduction_hostage` (Foreman card 9, Zip & Tie aced; D-056)
PD2 Crew Chief shape: flat damage absorption per hostage, capped by hostage count.
| Field | Type | Unit | Semantics |
|---|---|---|---|
| absorb_per_hostage | float | PD2 display units | Damage removed from every hit per hostage held (hit floored at 0). |
| max_hostages | int | count | Hostages counted at most. |

Foreman card 9 grants `{absorb_per_hostage: 5.0, max_hostages: 4}` ◇, Zip & Tie aced
`{absorb_per_hostage: 5.0, max_hostages: 8}` (skills.md). No value-based shape detection.

## Requested keys (granted, D-031)

Registered at phase 4 by D-031 and granted in the data as listed.

| Proposed key | Type | Used by | Semantics |
|---|---|---|---|
| `progression.xp_mult` | MULT | shared card 4 (1.45) | Heist XP multiplier (payout calculator). |
| `movement.armor_penalty_mult` | MULT | shared card 4 (0.85) | Scales the armor's move-speed penalty `(1 − ArmorDef.move_speed_mult)`. |
| `deploy.armor_bag` | FLAG | shared card 6 | Unlocks the armor bag deployable (change armor mid-heist). |
| `interaction.doctor_bag_speed_mult` | MULT | shared card 8 (0.8333 = 20% faster) | Doctor bag use time multiplier (lower = faster). |
| `progression.card_drop_quality_add` | ADD | card 9 completion bonus (0.1) | Chance that a PAYDAY card rolls the next quality tier. |
| `ability.shout_range_mult` | MULT | Foreman card 3 (1.25) | Shout distance (all shout targets). The existing `stealth.civilian_intimidate_range_mult` only covers civilians. |
| `team.armor_regen_delay_mult` | MULT (team) | Ironclad card 9 (0.9) | Crew-wide armor regen delay (TEAM source `team_perk.ironclad`). Replaced `perk.armorer.team_regen_delay_mult`. |

Answered by D-031: MULTs stay multiplicative (QB-34); `team.*` includes the granter and perk-deck team
grants go to `team_perk.<deck>` (QB-35); Hustler vests are Light/Patrol/Heavy only (QB-37); the registry
descriptions of `perk.rogue_dodge_stack` and `perk.crook` were reworded.

## Hook coverage (B4-14)

Audit of every key the 14 decks grant (9 cards each) against the code that reads it, at ENV B
`env/b-content` after merging trunk (2026-10-10). "Hook" = a `Modifiers.mult/add/flag/params/list`
call (or an `InteractableComponent.speed_modifier_key`) on the key. ENV A owns `game/systems/**`; ENV B
owns the progression readers in `game/content/**`. Tests: `game/tests/b/test_perk_wiring.gd`
(every deck at 9 cards through `Modifiers.set_source(slot, &"perk", …)` + TEAM sources, cards 1..n
gating at every n, team_perk dedupe, exact PARAMS field sets = the schemas above) and
`game/tests/b/test_perk_behaviour.gd` (behaviour on a `CrewController.spawn_for_range` crew member).
`test_every_granted_key_is_hooked_or_filed` fails if a deck grants a key that is in neither list below.

**D-161 / D-162:** `stealth.pocket_ecm` (A `perk_pocket_ecm.gd` + EcmSystem), `perk.yakuza`, `perk.biker` and
`perk.maniac` (A `perk_<name>.gd`, PerkTweak defaults = card-1 values; Road Crew and Hacker card 9 via CrewKillFeed)
are hooked under the field names of the schema tables above.
D-163: `perk.sicario` and `perk.tag_team` (A `perk_sicario.gd` / `perk_tag_team.gd`) likewise.

D-164: `perk.leech` and `perk.copycat` (A `perk_leech.gd` / `perk_copycat.gd`) likewise.

**Every granted key is hooked (D-056, A3-08 QB-56..62).** Every PARAMS grant at 9 cards has exactly the
fields and final values of the tables above; every armor id and throwable id it names exists. ENV A's
`game/systems/modifiers_params.md` reads every field under the same name (checked 2026-10-11), with
`PerkTweak.defaults` for fields a card has not set yet. The schemas above stay authoritative. Since
D-056 the modifiers reach a real heist through ENV A's server-side `LoadoutModifiers` push
(`ModifierPush.push` for every launch, default and AI loadouts included); MenuFlow no longer pushes.

### Shared cards (identical in every deck)

| Card | Key | Hook | Behaviour test |
|---|---|---|---|
| 2 | `weapon.headshot_mult.all` 1.25 | ✅ A `systems/combat/crew_weapons.gd:202` (`headshot_bonus`) | `test_shared_cards_scale_weapon_damage_and_headshot_bonus` |
| 4 | `stealth.concealment_add.all` 1 | ✅ B `content/progression/loadout_resolver.gd:160` (concealment bonus) | `test_concealment_bonus.gd`, `test_perk_resolver.gd` |
| 4 | `progression.xp_mult` 1.45 | ✅ B `content/ui/results/payday.gd:269` → `PayoutCalculator` | `test_payout_calculator.gd` |
| 4 | `movement.armor_penalty_mult` 0.85 | ✅ A `player/crew_controller.gd` (`1 − (1 − move_speed_mult) × mult`, QB-56) | A `test_p4_*` |
| 6 | `weapon.ammo_pickup_mult.all` 1.35 | ✅ A `combat/ammo_pickup_system.gd` (enemy ammo drops, QB-57) | A `test_p4_*` |
| 6 | `deploy.armor_bag` true | ✅ A `deployables/deployable_system.gd` (armor bag, QB-58; prompt `ui.prompt.use_armor_bag`) | A `test_p4_*` |
| 8 | `weapon.damage_mult.all` 1.05 | ✅ A `crew_weapons.gd:192` (`damage_at`) | `test_shared_cards_scale_weapon_damage_and_headshot_bonus` |
| 8 | `interaction.doctor_bag_speed_mult` 0.8333 | ✅ A `prefabs/deployable/deployable.gd` (doctor bag hold, QB-59) | A `test_p4_*` |
| 9 | `progression.card_drop_quality_add` 0.1 | ✅ B `content/progression/payday_cards.gd:49` | `test_payday_cards.gd` |

### Deck cards 1/3/5/7/9 (generic keys)

| Deck | Card | Key (cumulative at 9) | Hook | Behaviour test |
|---|---|---|---|---|
| Foreman | 3/5/7 | `team.stamina_mult` 1.5, `team.health_mult` 1.1, `team.armor_mult` 1.05 (TEAM `team_perk.foreman`) | ✅ A `combat/crew_health.gd` via `TeamModifiers.combined` (personal × team, QB-60); stamina `team_modifiers.gd` (ui_hud v1.4) | `test_perk_behaviour.gd` (Foreman 1.2 / 1.1, D-056) |
| Foreman | 3 | `ability.shout_range_mult` 1.25 | ✅ A `ai/police/police_surrender.gd` + `stealth/shout_system.gd` (civilians and marks, QB-61) | A tests |
| Foreman | 5/7 | `defense.health_mult` 1.0909091, `defense.armor_mult` 1.047619 | ✅ A `combat/crew_health.gd:80`, `:90` | `test_health_mult_decks_raise_max_health`, `test_armor_mult_decks_raise_max_armor` |
| Foreman | 9 | `team.damage_reduction_hostage {absorb_per_hostage 5, max_hostages 4}` | ✅ A `combat/team_modifiers.gd` (`hostage_reduced`, D-056) | A tests |
| Bulk | 1/3/5/9 | `defense.health_mult` → 2.0 | ✅ `crew_health.gd:80` | `test_health_mult_decks_raise_max_health` (incl. 1-card gating) |
| Ironclad | 1/3/5/9 | `defense.armor_mult` → 1.35 | ✅ `crew_health.gd:90` | `test_armor_mult_decks_raise_max_armor` (incl. 3-card gating) |
| Ironclad | 7 | `defense.armor_regen_delay_mult` 0.9 | ✅ `crew_health.gd:168`, `:188` | `test_armor_regen_delay_decks_shorten_the_delay` (incl. 6-card gating) |
| Ironclad | 9 | `team.armor_regen_delay_mult` 0.9 (TEAM `team_perk.ironclad`) | ✅ `crew_health.gd` (personal × team, QB-60) | `test_perk_behaviour.gd` (delay × 0.81, D-056) |
| Slipper | 1/5/7 | `defense.dodge_add` 0.45 | ✅ `crew_health.gd:117` | `test_dodge_decks_add_to_armor_dodge` |
| Slipper | 9 | `weapon.armor_pierce_add.all` 0.25 | ✅ `combat/combat_system.gd:113` (`pierce_profile`) | `test_armor_pierce_decks_raise_pierce_chance` |
| Slipper | 9 | `weapon.swap_speed_mult.all` 1.8 | ✅ `crew_weapons.gd:289` | not exercised (equip timer is private) |
| Hustler | 1 | `defense.dodge_add` 0.15 | ✅ `crew_health.gd:117` | `test_dodge_decks_add_to_armor_dodge` |
| Hustler | 9 | `defense.armor_regen_delay_mult` 0.9 | ✅ `crew_health.gd:168/188` | `test_armor_regen_delay_decks_shorten_the_delay` |
| Clean Sweep | 1/5 | `defense.armor_mult` → 1.2 | ✅ `crew_health.gd:90` | `test_armor_mult_decks_raise_max_armor` |
| Clean Sweep | 9 | `defense.armor_regen_delay_mult` 0.9 | ✅ `crew_health.gd:168/188` | `test_armor_regen_delay_decks_shorten_the_delay` |
| Prowler | 1/5/7 | `defense.dodge_add` 0.3 | ✅ `crew_health.gd:117` | `test_dodge_decks_add_to_armor_dodge` |
| Prowler | 3 | `stealth.body_bag_speed_mult` 0.8 | ✅ `loot/loot_manager.gd:261` (speed key) | `test_prowler_shortens_interaction_hold_times` |
| Prowler | 5 | `interaction.lockpick_speed_mult` 0.8 | ✅ `prefabs/door/door.gd:348`, `prefabs/safe/safe.gd:260` | `test_prowler_shortens_interaction_hold_times` |
| Prowler | 7 | `stealth.pager_answer_speed_mult` 0.9 | ✅ `stealth/pager_system.gd:162`, `hud_model/local_hud_model.gd:655` | `test_prowler_shortens_interaction_hold_times` |
| Prowler | 9 | `movement.crouch_speed_mult` 1.1 | ✅ `player/crew_controller.gd:302` | not exercised (physics movement) |
| Bloodletter | 3/7 | `defense.health_mult` → 1.4 | ✅ `crew_health.gd:80` | `test_health_mult_decks_raise_max_health` |
| Bloodletter | 5/9 | `weapon.armor_pierce_add.all` 0.2 | ✅ `combat_system.gd:113` | `test_armor_pierce_decks_raise_pierce_chance` |
| Incumbent | 3/5/7 | `defense.health_mult` → 1.4 | ✅ `crew_health.gd:80` | `test_health_mult_decks_raise_max_health` |
| Incumbent | 5 | `defense.dodge_add` 0.15 | ✅ `crew_health.gd:117` | `test_dodge_decks_add_to_armor_dodge` |
| Long Odds | 3/5 | `defense.health_mult` → 1.4 | ✅ `crew_health.gd:80` | `test_health_mult_decks_raise_max_health` |
| Overlord | 3/5/7/9 | `defense.health_mult` → 1.8 | ✅ `crew_health.gd:80` | `test_health_mult_decks_raise_max_health` |
| Knuckles, Composure, Overclock | — | no generic keys | — | — |

### Signature PARAMS keys (all ✅, QB-62: `game/systems/combat/perks/perk_<name>.gd`)

| Deck | Key (cards) | Fields we grant (approved schema) | Fields A reads |
|---|---|---|---|
| Foreman | `perk.crew_chief` (1/3/9) | team_dr, self_low_health_threshold, self_low_health_dr_mult, close_range_m, close_range_dr, hostage_health_per, hostage_stamina_per, hostage_max_count | all (same names) |
| Bulk | `perk.muscle` (3/7/9) | aggro_near_crew_mult, near_crew_m, panic_chance, panic_radius_m, regen_fraction, regen_interval_s | all (same names) |
| Ironclad | `perk.armorer` (7) | break_immunity_s, break_immunity_cooldown_s | all (same names) |
| Slipper | `perk.rogue_dodge_stack` (3) | aggro_near_crew_mult, near_crew_m | all (same names) |
| Hustler | `perk.crook` (3/5/7) | vest_armor_ids, vest_dodge_add, vest_armor_mult | all (same names) |
| Clean Sweep | `perk.sociopath` (1/3/5/7/9) | kill_armor, kill_armor_cooldown_s, close_range_m, close_range_dr, melee_kill_health_fraction, melee_kill_cooldown_s, close_kill_armor, close_kill_panic_chance, close_kill_panic_cooldown_s, panic_radius_m, forced_regen_after_break_s | all (same names) |
| Prowler | `perk.burglar` (3/5/7/9) | still_aggro_mult, still_regen_delay_mult | all (same names) |
| Knuckles | `perk.infiltrator` (1/3/5/7/9) | surrounded_min_enemies, surrounded_radius_m, surrounded_dr, melee_chain_mult, melee_chain_window_s, close_range_m, close_range_dr, melee_hit_heal_fraction, melee_hit_heal_cooldown_s | all (same names) |
| Bloodletter | `perk.grinder` (1/3/5/7/9) | allowed_armor_ids, heal_per_tick, tick_s, duration_s, stack_cooldown_s | all (same names) |
| Composure | `perk.stoic` (1/3/5/7/9), `perk.throwable` (1) | delayed_fraction, dot_duration_s, flask_cooldown_s, kill_cooldown_reduction_s, armor_to_health, auto_negate_after_s, low_health_threshold, low_health_kill_cooldown_reduction_s, negate_heal_fraction; item_id | all (same names) |
| Overclock | `perk.anarchist` (1/3/5/7/9) | tick_by_armor, break_immunity_s, break_immunity_cooldown_s, health_to_armor_fraction, health_to_armor_ratio, damage_dealt_armor, damage_dealt_armor_cooldown_s | all (same names) |
| Incumbent | `perk.ex_president` (1/3/5/7/9) | store_per_kill, max_store_by_armor, max_store_mult, kill_regen_speedup_fraction | all (same names) |
| Long Odds | `perk.gambler` (1/3/5/7/9) | heal_min, heal_max, heal_bonus, cooldown_s, lowest_health_bonus_per_ally, lowest_health_max_stacks, team_ammo_share, team_ammo_share_cooldown_s, team_heal_fraction | all (same names) |
| Overlord | `perk.kingpin` (1/5/7/9), `perk.throwable` (1) | heal_fraction, duration_s, cooldown_s, kill_cooldown_reduction_s, draws_aggro, low_health_threshold, low_health_heal_bonus, overheal_per_cooldown_s; item_id | all (same names) |

### QBs filed (B4-14), all closed

* **QB-A1..A7** (armor move penalty, ammo pickups, armor bag, doctor bag speed, `team.*`, shout range
  for every target, the 15 `perk.*` PARAMS keys): done by ENV A in A3-08 (QB-56..62, D-056).
* **QB-L1** (registry text of `perk.stoic` / `perk.burglar` / `team.armor_regen_delay_mult`): lead.
* **QB-L2** (no modifiers in a real heist): B4-14 `ModifierPush`, called by ENV A on the server for every
  launch since D-056.
