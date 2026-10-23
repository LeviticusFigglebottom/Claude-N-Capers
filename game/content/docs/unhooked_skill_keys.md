# Unhooked skill keys: triage for ENV A (LEAD r280 ruling, B audit)

Owner: ENV B. Source: `game/tests/integration/p4_coverage_ratchet.gd` `UNHOOKED` (57 keys, all owner A, 2026-10-22).
Every key below is granted by B's skill data, but no runtime code reads it, so **the skill does nothing in play**.
**No perk deck grants an unhooked key**; every deck card is hooked.

**How to use this file**
- A lands one batch at a time. Each key moves from `UNHOOKED` to tested, following the ratchet's rules.
- Per key: the skill(s) granting it (tree / subtree, Basic or Aced), the value shape B's data uses (exact numbers from
  `content/data/skills/**`), the PD2 skill it stands for (`docs/research/pd2_research.md` Appendix A), and the behaviour
  A implements.
- B's skill tree marks every skill that grants a key from this list: "Not active yet" (every key it grants waits) or
  "Partly active" on the skill button, plus the detail panel's per-part note. The data is
  `content/data/skills/trees.tres` `blocked_on_keys` (50 skills, 84 parts), kept equal to `UNHOOKED` by
  `test_skill_data.gd::test_blocked_parts_track_the_unhooked_keys`. When A lands a batch, that test fails until B
  drops those keys in the same round, and the markers disappear.
- Key suffixes: `.all` / `.<weapon class>` / `.suppressed` select the weapons a stat applies to (the hooked
  `weapon.*_mult` keys already use the same rule).

**Ranking:** PD2 build impact. A batch comes first when popular builds depend on it (Inspire, Swan Song, Berserker,
Overkill, Bulletstorm, Bullseye, Kickstarter, crits and dodge). Every key is in exactly one batch.

| Batch | Keys | Theme | Size (A) |
|---|---|---|---|
| 1 | 9 | Core loud-build pillars | M-L |
| 2 | 8 | Crits and dodge (stealth / hybrid builds) | M (includes the crit roll) |
| 3 | 7 | Revives and medic support | M |
| 4a | 10 | Gun handling and movement stats | S-M (stat lookups) |
| 4b | 8 | Combat triggers | M |
| 5 | 7 | Sentries and trip-mine fire | M |
| 6 | 7 | Hostages, converts and marks | M |
| held | 1 | `stealth.pocket_ecm` (Hacker deck held, P5+, LEAD r280) | — |

---

**All batches hooked (LEAD r285):** A (env/a-core 05477b73, 48608af4, f12e25ba) and P (env/p-play 67b66fd3) read every
key below; `SkillTreeDef.blocked_on_keys` is empty. Only `stealth.pocket_ecm` (held, granted by no skill) stays in the
ratchet's UNHOOKED. Cornered and Kickstarter behaviour are still open.

## Batch 1: core loud-build pillars (9)
| Key | Granted by | Data | PD2 | Behaviour |
|---|---|---|---|---|
| `ability.inspire` | Rally Cry (Ringleader / Field Medic) B, A | B: `{range 0, cooldown 0, buff_move_mult 1.2, buff_reload_mult 1.2, buff_duration 10}`; A: `range 9, cooldown 20` | Inspire | **Basic:** shouting at a teammate (the existing shout key, aimed at an ally) gives them move ×1.2 and reload ×1.2 for 10 s. **Aced:** shouting at a downed teammate within 9 m revives them instantly; cooldown 20 s per user. The heart of PD2 loud co-op. |
| `defense.swan_song` | Last Stand (Outlaw / Undying) B, A | B: `{duration 3, speed_penalty 0.6, infinite_ammo false}`; A: `duration 6, infinite_ammo true` | Swan Song | When health would hit 0, the player stays up for `duration` s at move ×(1 - 0.6), then goes down. Aced: no ammo is consumed during it. Once per down. |
| `defense.berserk` | Red Mist (Outlaw / Scrapper) B, A | `{threshold 0.5, max_damage_mult 3.5, ranged_max_damage_mult 1.0 / 2.0 (A)}` | Berserker | Below 50 % health, melee damage scales linearly up to ×3.5 at 0 health. Aced: ranged damage up to ×2.0. Must read the health fraction each hit. |
| `weapon.kill_damage_buff` | Momentum (Bruiser / Scattergun) B, A | `{trigger_class shotgun, damage_mult 1.75, duration 20, all_weapons false / true (A)}` | Overkill | A shotgun kill gives ×1.75 damage for 20 s to shotguns (Aced: all weapons). Re-kills refresh the timer. |
| `deploy.ammo_bag_bulletstorm` | Lead Rain (Bruiser / Quartermaster) B, A | `{base_duration 0, max_duration 5 / 20 (A)}` | Bulletstorm | After using an ammo bag, no ammo is consumed for a time that scales with the ammo taken (up to `max_duration` s). |
| `defense.bullseye` | Clean Shot (Bruiser / Juggernaut) B, A | `{armor 5 / 25 (A), cooldown 2}` | Bullseye | A headshot restores `armor` armor points; at most once per 2 s. The Anarchist / armor-gate builds rely on it. |
| `interaction.device_melee_restart` | Percussive Maintenance (Wrench / Breacher) A | `true` | Kickstarter (aced) | Hitting a jammed drill or saw with melee has a chance to restart it (PD2: 50 %, once per jam ◇). Needs the DeviceRunner jam state. |
| `defense.self_revive_charges` | Comeback (Outlaw / Undying) B | `1` | Messiah | While downed, a kill revives you; `charges` uses per heist. |
| `defense.self_revive_refill_on_doctor_bag` | Comeback A | `true` | Messiah (aced) | Using a doctor bag refills the self-revive charge. |

## Batch 2: crits and dodge (8)
Batch 2 needs a crit roll first. Settled (LEAD r285, D-027 QB-29): a crit deals the headshot multiplier on any zone,
with no extra ×3. Pay-off: Shade builds (stealth / hybrid), the second most common archetype.

| Key | Granted by | Data | PD2 | Behaviour |
|---|---|---|---|---|
| `weapon.crit_chance_add` | — (registry key; no grant yet) | — | — | The shared crit chance the rest add into. Hook it as the roll's base input. |
| `weapon.crit_per_concealment` | Cheap Shot (Shade / Quiet Professional) B, A | `{per_step 0.03, points_per_step 3 / 1 (A), threshold_dr 35, max 0.3}` | Low Blow | Crit chance +3 % per 3 (Aced: 1) concealment points under DR 35, up to 30 %. |
| `weapon.unseen_strike` | Ambusher (Shade / QP) B, A | `{idle_s 4, crit_add 0.35, duration 6 / 18 (A)}` | Unseen Strike | After not taking damage for 4 s, +35 % crit for 6 s (Aced: 18 s). |
| `defense.dodge_per_concealment` | Slippery (Shade / Slipstream) B, A | `{per_step 0.01, points_per_step 3 / 1 (A), threshold_dr 35, max 0.1}` | Sneaky Bastard | Dodge +1 % per 3 (Aced: 1) concealment points under DR 35, up to +10 %. |
| `defense.sprint_dodge_add` | Light Step A | `0.1` | Duck and Cover (aced) | +10 % dodge while sprinting. |
| `defense.armor_break_speed_buff` | Bolt (Shade / QP) B, A | `{move_mult 1.3, duration 5, team false / true (A)}` | Second Wind | When your armor breaks: move ×1.3 for 5 s (Aced: the whole crew). |
| `defense.armor_broken_stagger` | Cornered (Shade / Slipstream) B, A | `{persist_s 0 / 6 (A)}` | Trigger Happy-style / "Shockproof" ◇ | While your armor is broken, your hits stagger enemies; Aced: for 6 s after armor returns. |
| `defense.target_priority_mult` | Low Profile (Shade / QP) B | `0.65` | Duck and Cover / Shinobi ◇ | Enemies choose you as a target ×0.65 as often (a weight in A's target choice). |

## Batch 3: revives and medic support (7)
| Key | Granted by | Data | PD2 | Behaviour |
|---|---|---|---|---|
| `ability.revive_target_buff` | Numbing Agent (Ringleader / Field Medic) B, A | `{damage_taken_mult 0.7 / 0.2 (A), duration 5}` | Combat Medic / Painkillers | A teammate you revive takes ×0.7 (Aced ×0.2) damage for 5 s. |
| `ability.revive_target_health_mult` | Triage A | `1.3` | Combat Medic (aced) | A teammate you revive comes back with ×1.3 the normal revive health. |
| `defense.reviving_damage_taken_mult` | Triage B | `{mult 0.7, linger_s 5}` | Combat Medic | While you revive someone, and 5 s after, you take ×0.7 damage. |
| `defense.post_revive_buff` | Back on Your Feet B; Second Lease B, A | BoYF `{duration 10, damage_taken_mult 0.7}`; SL `{reload 2.0, swap 2.0, move 1.0 / 1.3 (A)}` | Up You Go / Running from Death | For 10 s after being revived: the listed multipliers (damage taken, reload, swap, move). |
| `deploy.fak_auto_revive` | Field Kit A | `{radius 5, cooldown 20}` | Uppers (aced) | A downed player within 5 m of your first-aid kit is revived automatically; once per kit per 20 s. |
| `deploy.medical_user_buff` | Bedside Manner A | `{damage_taken_mult 0.9, duration 120}` | Doctor bag / Medic ◇ | Anyone who uses your doctor bag or first-aid kit takes ×0.9 damage for 120 s. |
| `defense.bleedout_pause_unseen` | Playing Possum B | `true` | — (original) ◇ | The bleedout timer pauses while no enemy sees you. |

## Batch 4a: gun handling and movement stats (10)
These are plain stat lookups at the existing weapon / movement sites, the same pattern as the hooked `weapon.*_mult`
keys. They are cheap, so A can merge them with 4b.

| Key | Granted by (data) | Behaviour |
|---|---|---|
| `weapon.ads_speed_mult` | Pump Action A (`.shotgun` 2.25), Snap Shot B (`.all` 2.0), Hushed Hands B (`.suppressed` 2.0) | Aim-down-sights transition speed ×value. |
| `movement.ads_speed_penalty_mult` | Snap Shot B (0.0) | Scales the ADS walk-speed penalty (0 = none). |
| `weapon.hip_spread_mult` | Hip Discipline B (`.all` 0.88) | Hip-fire spread ×value. |
| `weapon.hip_fire_rate_mult` | Hip Fire A (`.shotgun` 1.35) | Fire rate ×value while not aiming. |
| `weapon.still_spread_mult` | Steady Aim A (`.all` 0.84) | Spread ×value while standing still. |
| `weapon.moving_spread_mult` | Snap Shot A (`.smg/.assault_rifle/.sniper` 0.84), Hip Discipline A | Spread ×value while moving. |
| `weapon.falloff_range_mult` | Long Barrel A (`.shotgun` 1.5) | Damage-falloff distances ×value (PD2 Far Away). |
| `movement.shoot_while_sprinting` | Hip Fire B (`.shotgun`), Run and Gun B (`.all`) | Can fire while sprinting with these weapons. |
| `movement.reload_while_sprinting` | Free Running A | Reloading no longer stops a sprint. |
| `movement.sprint_any_direction` | Free Running A | Sprint sideways and backwards (PD2 Parkour). |

## Batch 4b: combat triggers (8)
| Key | Granted by | Data | PD2 | Behaviour |
|---|---|---|---|---|
| `weapon.kill_reload_buff` | Run and Gun A; Wind Up A; Reload Rhythm A | e.g. RaG `{trigger auto_kills, kills 2, reload 2.0, min 1.4, mag_falloff 0.01 from 20}`; WU `{melee_kill, 1.5, 10 s}`; RR `{headshot_kill, 2.0, 4 s}` | Lock n' Load / Aggressive Reload | The trigger arms the next reload at ×`reload_mult` (or for `duration`); RaG falls off with magazine size past 20. |
| `weapon.hit_stack_buff` | Hot Streak B, A; Rhythm B | `{class pistol, stat damage / accuracy, per_hit, max_stacks, duration}` | Desperado / Trigger Happy | Each pistol hit adds a stack of `per_hit` to the stat, up to `max_stacks`, for `duration` s (refreshed). |
| `weapon.headshot_refund` | Economy B, A | `{classes smg/ar/sniper, headshots 3 / 2 (A), window 6, refund 1}` | Ammo Efficiency | N headshots within 6 s return 1 round to the magazine. |
| `weapon.graze` | Grazing Fire B, A | `{class sniper, radius 1, frac 0.2, headshot_kill_frac 0.2 / 1.0 (A)}` | Graze | A sniper hit deals 20 % to enemies within 1 m of the target (Aced: 100 % on a headshot kill). |
| `weapon.body_expertise` | Anatomy B, A | `{frac 0.3 / 0.9 (A), auto_only, classes smg/lmg/ar/special}` | Body Expertise | Body shots with full-auto fire get `frac` of the headshot multiplier. |
| `weapon.stagger_chance_add` | Knockdown B (.all 0.05), A (0.15) | — | Shock and Awe ◇ | Extra chance per hit to stagger non-special enemies. |
| `defense.outnumbered` | Outnumbered B, A | `{enemies 3, radius 18, damage_mult 1.15, damage_taken_mult 1.0 / 0.9 (A), duration 7}` | Close By / Underdog | With 3+ enemies within 18 m: damage ×1.15 (Aced: also damage taken ×0.9) for 7 s. |
| `defense.flashbang_duration_mult` | Thick Skin A | `0.25` | Sharpshooter / flashbang resist ◇ | Flashbang blind duration ×0.25. |

## Batch 5: sentries and trip-mine fire (7)
Pay-off: the Wrench / Sapper subtree is fully dead today, so a player who builds it gets nothing.

| Key | Granted by | Data | PD2 | Behaviour |
|---|---|---|---|---|
| `deploy.sentry_accuracy_mult` | Calibrated B | `0.5` | Sentry Targeting Package | Sentry spread ×0.5. |
| `deploy.sentry_turn_speed_mult` | Calibrated A | `2.5` | (aced) | Sentry turn speed ×2.5. |
| `deploy.sentry_cost_mult` | Lean Build B; Mount Up B | `0.95` each | Sentry Combat Upgrade | The ammo deploying a sentry costs ×0.95 (stacks multiplicatively). |
| `deploy.sentry_health_mult` | Lean Build A | `2.5` | Eco Sentry | Sentry health ×2.5. |
| `deploy.sentry_shield` | Mount Up A | `true` | Third Law (aced) | The sentry gets a frontal shield (blocks damage from the front). |
| `deploy.sentry_modes` | Silent Partner B, A | `{quiet, ap (A), quiet_threat_mult 0.2, ap_fire_rate_mult 0.25, ap_damage_mult 3.5}` | Engineering / Jack of All Trades | A toggle on the sentry: quiet mode (×0.2 threat), Aced also AP mode (fire rate ×0.25, damage ×3.5, pierces shields). |
| `deploy.trip_mine_fire` | Hot Floor B, A | `{duration 10 / 20 (A), radius 2.0 / 2.45 (A)}` | Fire Trap | A trip mine leaves a fire pool of `radius` m for `duration` s (reuses the incendiary fire volume). |

## Batch 6: hostages, converts and marks (7)
| Key | Granted by | Data | PD2 | Behaviour |
|---|---|---|---|---|
| `ability.convert_owner_buff` | Accomplice B, A | `{move_mult 1.1, health_mult 1.0 / 1.3 (A)}` | Partners in Crime | While you have a converted enemy: move ×1.1 (Aced: health ×1.3). |
| `ability.hostage_regen` | Leverage B, A | `{per_hostage 0.015 / 0.045 (A), max_hostages 1, interval 5}` | Hostage Taker | Regenerate 1.5 % (Aced 4.5 %) health every 5 s while a hostage is tied. |
| `ability.stockholm` | Captive Audience A | `true` | Stockholm Syndrome | Civilian hostages may revive a downed crew member when asked (PD2: they free you from custody / bleedout). |
| `stealth.noise_intimidates_civilians` | Captive Audience B | `true` | Stockholm Syndrome (basic) | Gunfire / shouts intimidate civilians in a wider radius (they drop and stay down). |
| `stealth.mark_by_aim` | Price Tag A | `true` | High Value Target | Aiming at a guard / special for a moment marks it, without a shout. |
| `stealth.mark_damage_bonus_mult` | Price Tag B | `1.15` | Marked Target | Marked enemies take ×1.15 damage from the crew. |
| `stealth.mark_far_damage_mult` | Price Tag A | `{min_distance 10, mult 1.5}` | High Value Target (aced) | Marked enemies beyond 10 m take ×1.5 damage. |

## Held (1)
- `stealth.pocket_ecm`: the Hacker deck's card, HELD (LEAD r280: P5+ per the deck table). No grant exists.

## Notes for A
- **Tests:** each key needs one behaviour test (the ratchet moves it to tested). The values above are what B's data
  grants today, and the tests should read them from `ContentDB`, not copy them.
- **Values marked ◇** are original or unverified in research; implement the shape, and the LEAD tunes it.
- **Batch order suggestion:** 1 -> 2 -> 3 -> 4a + 4b -> 5 -> 6. If A prefers cheap wins first, 4a (stat lookups) can go
  before 2.
