# PARAMS modifier keys: how ENV A reads them (contracts/modifiers.md)

Owner: ENV A. Reviewed by the lead. The authoritative field list and values of every `perk.*` dict
are ENV B's `game/content/docs/perk_decks.md` (D-031); this file says how the engine **reads** each
field. Code: `game/systems/combat/perks/` (QB-62, P4). Tests: `game/tests/a/test_p4_perk_*.gd`
(one behaviour test per key).

## Runtime

* `PerkHooks` (static) is the only entry point other systems call, each with one `# perk hook` line:
  `CrewHealth.compute_max_health / compute_max_armor / dodge_chance / take_hit / server_tick`,
  `PoliceBrain._pick_target` and `GuardBrain._pick_target` (target weight).
* `CrewPerks` (one per crew member, metadata on the CrewController) creates one `PerkComponent` per
  key while `Modifiers.params(slot, key)` is a non-empty dict, and re-reads the dicts every tick (a
  re-grant keeps the component's timers).
* Damage dealt and kills come from `EventBus.damage_applied` / `npc_killed` with the holder as
  attacker. Ammo pickups come from `AmmoPickupSystem.ammo_picked(crew, amount)`. All of this happens on
  the server only.
* **Missing fields** use `PerkTweak.defaults[key]` (`perk_tweak.tres`). That is the card-1 value, or a
  neutral value (0, 1.0, off) for a field that a later card switches on, so a card-1 holder never gets
  a later card's feature.
* **Damage reduction**: the `damage_reduction` of every perk is summed, plus the best `perk.crew_chief`
  `team_dr` in the heist. The total is capped at `PerkTweak.max_damage_reduction` (0.9) and applied
  after the dodge roll and before armor. `team.damage_reduction_hostage` is a separate key, handled
  by TeamModifiers.
* **Order of the max values**: health is (base x `defense.health_mult` x `team.health_mult`) x the
  crew chief hostage bonus, then the perk adjustments. Armor is (ArmorDef x `defense.armor_mult` x
  `team.armor_mult`), then the perk adjustments. The perk adjustments run in the order of
  `CrewPerks.scripts()`.
* **Target weight** (`PerkHooks.aggro_weight`): the product over all perks. The NPC brains divide
  their squared-distance score by it (> 1 = preferred).
* **Randomness**: `GameRng.stream(&"perks")`.
* **Panic** (`perk.muscle`, `perk.sociopath`): `NpcBase.stun(PerkTweak.panic_stun_s)` (◇ 2 s) on the
  enemies in the radius. CrewPerks ticks those stuns.

Units: m, s, PD2 display HP / armor; fractions 0..1. "Card" = first card that sets the field.

## `perk.stoic` (Composure), PerkStoic
| Field | Default | Read as |
|---|---|---|
| delayed_fraction | 0.75 | Part of each hit (after DR) that becomes DoT. The rest goes through the normal armor/health path. |
| dot_duration_s | 12 | Each hit's delayed part is applied linearly over this time (one DoT instance per hit). |
| flask_cooldown_s | 10 | The flask (deck throwable of kind `flask`) cancels all DoT. It then has this cooldown. |
| kill_cooldown_reduction_s | 1 | Flask cooldown cut per kill by the holder. |
| armor_to_health | 0 | Fraction of the raw armor removed from max armor and added to max health. |
| auto_negate_after_s | 0 (off) | The DoT is cancelled after this long without taking a hit. |
| low_health_threshold | 0.35 | Health fraction under which a kill cuts low_health_kill_cooldown_reduction_s instead. |
| low_health_kill_cooldown_reduction_s | 0 | The larger of this and kill_cooldown_reduction_s is used. |
| negate_heal_fraction | 0 | Any cancel (flask or auto) heals this part of the remaining DoT. |

DoT ignores armor and pauses during invulnerability. A down clears it. DoT reaching 0 health calls
`go_down()`.

## `perk.grinder` (Bloodletter), PerkGrinder
| Field | Default | Read as |
|---|---|---|
| allowed_armor_ids | suit, light vest | The worn armor (`Loadout.armor`, else CombatTweak.default_armor) must be in the list. |
| heal_per_tick | 1 | HP per tick per stack (`CrewHealth.heal`). |
| tick_s | 0.3 | Tick interval of each stack. |
| duration_s | 3 | Stack lifetime. |
| stack_cooldown_s | 1.5 | Damaging an enemy (amount > 0) adds a stack, at most once per this. Stacks have no cap. |

## `perk.anarchist` (Overclock), PerkAnarchist
| Field | Default | Read as |
|---|---|---|
| tick_by_armor | table ◇ | `{armor_id: [armor, interval_s]}`. While armor < max, `armor` is added every `interval_s`, whatever the regen delay. This replaces CrewHealth's delayed full regen. Unknown armor: `PerkTweak.anarchist_fallback_tick`. |
| break_immunity_s / break_immunity_cooldown_s | 2 / 15 | `invuln_left` = max(current, s) on the hit that breaks the armor, at most once per cooldown. |
| health_to_armor_fraction | 0 | Max health x (1 - f) (f capped at 0.95). |
| health_to_armor_ratio | 0 | Max armor + raw health x f x ratio. |
| damage_dealt_armor / _cooldown_s | 0 / 1.5 | Armor gained when the holder damages an enemy, at most once per cooldown. |

## `perk.ex_president` (Incumbent), PerkExPresident
| Field | Default | Read as |
|---|---|---|
| store_per_kill | 4 | Health banked per holder kill while armor > 0. |
| max_store_by_armor | table ◇ | Bank cap per armor id. Unknown armor: `PerkTweak.ex_president_fallback_store`. |
| max_store_mult | 1 | Cap multiplier. |
| kill_regen_speedup_fraction | 0 | A kill while armor is 0 removes `regen_delay_left x f x (1 - tier/6)` (tier from `PerkTweak.armor_tiers`, suit 0 .. breacher 6). |

Payout: the first tick after armor broke on which `regen_delay_left <= 0` heals the whole bank.

## `perk.gambler` (Long Odds), PerkGambler
| Field | Default | Read as |
|---|---|---|
| heal_min / heal_max / heal_bonus | 16 / 24 / 0 | Heal = randf_range(min, max) + bonus (stream `perks`). |
| cooldown_s | 3 | Heal cooldown. |
| lowest_health_bonus_per_ally / lowest_health_max_stacks | 0.2 / 3 | Heal x (1 + per x number of non-custody teammates with more current health than the holder, capped). |
| team_heal_fraction | 0 | Every non-custody teammate heals heal x this. |
| team_ammo_share / _cooldown_s | 0 / 5 | Every teammate's equipped weapon gets round(picked rounds x share) reserve, capped at total ammo (x `weapon.ammo_total_mult`) minus the magazine. |

Trigger: `AmmoPickupSystem.ammo_picked(crew, amount)`, or `PerkHooks.on_ammo_picked(crew, amount)`.
The ammo share runs even when the heal is on cooldown.

## `perk.kingpin` (Overlord), PerkKingpin
| Field | Default | Read as |
|---|---|---|
| heal_fraction | 0.75 | While active, every hit heals `amount x f` (armor + health damage taken). |
| duration_s / cooldown_s | 6 / 30 | The injector (deck throwable of kind `injector`) starts both on use. |
| kill_cooldown_reduction_s | 1 | Cooldown cut per kill. |
| draws_aggro | false | While active, enemies within `PerkTweak.kingpin_aggro_radius_m` (◇ 18 m) weight the holder x `PerkTweak.kingpin_aggro_mult` (◇ 2). |
| low_health_threshold / low_health_heal_bonus | 0.5 / 0 | Below the threshold: f x (1 + bonus). |
| overheal_per_cooldown_s | 0 (off) | Each this much healing beyond max health cuts 1 s from the cooldown. |

## `perk.sociopath` (Clean Sweep), PerkSociopath
| Field | Default | Read as |
|---|---|---|
| kill_armor / kill_armor_cooldown_s | 30 / 1 | Armor per holder kill, with this cooldown. |
| close_range_m / close_range_dr | 18 / 0 | DR while a living enemy is within range. |
| close_kill_armor | 0 | Extra armor for a kill within close_range_m. It has its own timer with the same kill_armor_cooldown_s. |
| melee_kill_health_fraction / _cooldown_s | 0 / 1 | A MELEE kill heals max health x f. |
| close_kill_panic_chance / _cooldown_s, panic_radius_m | 0 / 1, 6 | A close kill panics the enemies within the radius of the victim. |
| forced_regen_after_break_s | 0 (off) | On the hit that breaks the armor a timer starts. Until it runs out, every hit caps `regen_delay_left` at what is left of it, so armor returns that long after the break. |

## `perk.rogue_dodge_stack` (Slipper), PerkRogue
| Field | Default | Read as |
|---|---|---|
| aggro_near_crew_mult | 1.0 | Target weight while a non-custody teammate is within near_crew_m. |
| near_crew_m | 8 | Radius. |

Dodge, swap speed and armor pierce come from the generic keys.

## `perk.crook` (Hustler), PerkCrook
| Field | Default | Read as |
|---|---|---|
| vest_armor_ids | light, patrol, heavy | Worn armor must be listed. |
| vest_dodge_add | 0 | Added to `CrewHealth.dodge_chance()` (before its clamp). |
| vest_armor_mult | 1.0 | Max armor multiplier. |

## `perk.burglar` (Prowler), PerkBurglar
| Field | Default | Read as |
|---|---|---|
| still_aggro_mult | 1.0 | Target weight while crouched or with horizontal speed < `PerkTweak.still_speed_threshold` (◇ 0.3 m/s). |
| still_regen_delay_mult | 1.0 | In the same state, the regen delay counts down 1/mult as fast (only for mult < 1). |

## `perk.infiltrator` (Knuckles), PerkInfiltrator
| Field | Default | Read as |
|---|---|---|
| surrounded_min_enemies / surrounded_radius_m / surrounded_dr | 3 / 6 / 0.12 | DR while at least that many living enemies are within the radius. |
| close_range_m / close_range_dr | 18 / 0 | Additional DR while any enemy is within range. |
| melee_chain_mult / melee_chain_window_s | 10 / 1 | A MELEE hit dealt by the holder opens the window. While it is open, `PerkHooks.melee_damage_mult(crew)` returns the mult. `PerkHooks.on_melee_miss` resets it. |
| melee_hit_heal_fraction / _cooldown_s | 0 / 10 | A MELEE hit heals max health x f. |

There is no crew melee attack yet. The melee parts run off MELEE DamageInfos, and the future melee
code must multiply by `melee_damage_mult` and call `on_melee_miss`.

## `perk.muscle` (Bulk), PerkMuscle
| Field | Default | Read as |
|---|---|---|
| regen_fraction / regen_interval_s | 0 / 5 | Heals max health x f every interval (NORMAL only). |
| aggro_near_crew_mult / near_crew_m | 1.0 / 8 | As for perk.rogue_dodge_stack. |
| panic_chance / panic_radius_m | 0 / 6 | Each BULLET hit by the holder rolls the chance to panic the enemies near the victim. |

## `perk.armorer` (Ironclad), PerkArmorer
| Field | Default | Read as |
|---|---|---|
| break_immunity_s / break_immunity_cooldown_s | 0 / 15 | As for perk.anarchist (`invuln_left`, which blocks all damage). |

## `perk.crew_chief` (Foreman), PerkCrewChief
| Field | Default | Read as |
|---|---|---|
| team_dr | 0.08 | DR for every crew member, the holder included. Several holders: the best one counts. |
| self_low_health_threshold / self_low_health_dr_mult | 0.5 / 2 | The holder's own team_dr x mult below the health fraction. |
| close_range_m / close_range_dr | 18 / 0 | Holder DR while an enemy is within range. |
| hostage_health_per / hostage_stamina_per / hostage_max_count | 0 / 0 / 4 | Every crew member: max health x (1 + per x min(hostages, max)). Stamina likewise through `PerkHooks.stamina_mult(crew)`. Hostages = `TeamModifiers.hostage_count`. |

## `perk.throwable`, PerkThrowable
| Field | Default | Read as |
|---|---|---|
| item_id | &"" | `PerkHooks.throwable_id(crew)` returns it (it replaces `Loadout.throwable`). |

Throwing: a rising edge of `CrewIntent.throw_item` (NORMAL crew), or `PerkHooks.use_throwable(crew)`,
looks up `ContentDB.throwable(item_id).kind`, and the first perk that accepts the kind consumes it
(`flask` goes to perk.stoic, `injector` to perk.kingpin). The perk's own cooldown gates use, so the
item never runs out. Grenades and other thrown objects are not implemented.

## Open items (for the lead)
* Stamina: `CrewStamina` should multiply `PerkHooks.stamina_mult(crew)` (Foreman hostage stamina).
  That is a one-line hook in ENV A's stamina code, which was not part of QB-62.
* HUD: the throwable slot still shows `Loadout.throwable`. `PerkHooks.throwable_id` is the override.
* `defense.healing_received_mult` is not applied by `CrewHealth.heal`. If it is added there, perk
  heals get it automatically.
