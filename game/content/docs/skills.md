# Skills (B4-01)

Owner: ENV B. Data: `content/data/skills/<tree>/<subtree>/<skill>.tres` (`SkillDef`) and
`content/data/skills/trees.tres` (`SkillTreeDef`: layout, tier gates, costs, point formula, team-key
convention, blocked parts, unlocks). Logic: `progression/skill_points.gd` (`SkillPoints`), modifiers via
`LoadoutResolver.resolve_modifiers` / `team_modifier_sources`. Tests: `tests/b/test_skill_data.gd`,
`tests/b/test_skill_points.gd`. Reference: research Appendix A; spec: pd2_fidelity P1-P3.

## Rules (data in trees.tres)

* 5 trees x 3 subtrees x 6 skills = 90. Tiers per subtree 1/2/2/1 skills (pd2_fidelity P2).
* Costs basic/aced per tier: 1/3, 2/4, 3/6, 4/8. Aced includes basic, so acing costs basic + aced
  (a full subtree is 46, a full tree 138; level 100 gives 120, so no tree can be finished).
* **Tier gates 0/1/3/18, counted on lower tiers only.** A tier-t skill needs that many points spent on
  skills of tiers below t in the same subtree. Research 3.1: "tier 2 after 1 point spent in that subtree,
  tier 3 after 3, tier 4 after 18"; tier 1 is always open. In PD2 the points that open a tier are, at that
  moment, necessarily lower-tier points; counting only lower tiers keeps that true when a finished set
  is validated in any order (a tier-3 skill's own 3 points never open tier 3).
* Points: `level * 1 + floor(level / 10) * 2` = 120 at level 100. Respec is free (`respec_cost = 0`):
  the UI just submits a new set and the host validates it (`SkillPoints.validate`).
* `Loadout.skills` = id -> 1 (basic) / 2 (aced). Any other level, unknown id or missing tier gate is
  illegal.
* Strings: `<skill id>.name|.basic|.aced` (e.g. `skill.juggernaut.plated.name`), `ui.skills.tree.<tree>`,
  `ui.skills.subtree.<subtree>`, `ui.skills.reason.<code>` for `SkillPoints.can_unlock` reasons. The
  SkillDef `display_name` / `desc_*` are debug fallbacks and must equal the strings (tested).

### Team skills

A grant whose key starts with `team.` is crew-wide (convention in `SkillTreeDef.team_key_prefix`).
`LoadoutResolver.resolve_modifiers` leaves those out of the personal modifiers;
`LoadoutResolver.team_modifier_sources(loadout)` returns them as `{&"team_skill.<skill id>": grants}`. At
heist start the server calls `Modifiers.set_source(Modifiers.TEAM, source, grants)` for every crew
member, so two players with the same skill write the same source and it counts once (PD2).
Team skills today: **Zip & Tie** aced (`team.damage_reduction_hostage`). Shoulder Check basic becomes one
when `team.armor_regen_rate_mult` exists. Skills that buff the crew through a PARAMS mechanic the owner
triggers (Rally Cry's shout, Bolt aced) are personal grants: the owner's behaviour reaches the crew.

### Unlocks

`skill.juggernaut.plated` aced unlocks `armor.breacher_plate` through `ArmorDef.unlock_skill` (D-022 QB-7),
listed in `trees.tres unlocks`; it has no modifier grant.

### Value conventions and assumptions (for ENV A / lead review)

* `interaction.*_speed_mult`, `interaction.revive_speed_mult`, `interaction.device_speed_mult`, time-like
  `stealth.*_speed_mult`: time multipliers (lower = faster). PD2 "100% faster" = 0.5.
* `weapon.reload_speed_mult`, `swap_speed_mult`, `ads_speed_mult`: speed (higher = faster). "33% less
  time" = 1.5.
* PD2 accuracy/stability points: 1 point ~ 1% of spread/recoil (`+8 accuracy` = `spread_mult` 0.92,
  `+16 stability` = `recoil_mult` 0.84). ◇ to be tuned against StatCalculator display numbers.
* Sequential PD2 bonuses are split so basic x aced = PD2 total (Overclocked Bits 0.85 x 0.8235 = 0.70).
* `deploy.capacity_mult.sentry` scales sentry ammo; `deploy.extra.<kind>` adds units.
* `team.damage_reduction_hostage.per` = flat damage absorbed per hit per hostage, in display units
  (PD2 0.5 internal = 5).
* Simplified mappings (condition dropped because no key carries it): Deliberate Fire (PD2 single-fire
  only), Long Barrel basic (ADS only), Hauler aced (PD2 scales with armor), Deep Pockets aced (PD2:
  ballistic vests only), Heavy Hands basic (PD2: non-specials only), Light Step basic (stamina pool
  instead of stamina regen).

### PARAMS schemas proposed for existing keys

ENV A documents the final schemas in `game/systems/modifiers_params.md`; the data uses these:

| Key | Params used | Skill |
|---|---|---|
| `ability.inspire` | `range` (m, 0 = no shout-revive), `cooldown` s, `buff_move_mult`, `buff_reload_mult`, `buff_duration` s | Rally Cry |
| `ability.hostage_regen` | `per_hostage` (fraction of max health per tick), `max_hostages`, `interval` s | Leverage |
| `team.damage_reduction_hostage` | `per` (flat absorption, display units), `max` hostages | Zip & Tie |
| `defense.bullseye` | `armor` (display units per headshot), `cooldown` s | Clean Shot |
| `defense.shockproof` | `backfire_chance`, `tase_shorten`, `can_interact_counter`, `counter_window` s | Grounded |
| `defense.swan_song` | `duration` s, `speed_penalty` (0.6 = 60% slower), `infinite_ammo` | Last Stand |
| `defense.berserk` | `threshold` (health fraction), `max_damage_mult` (melee), `ranged_max_damage_mult` | Red Mist |

## Expressibility today

* **32** skills fully expressible (every basic and aced effect is a registry grant or a data unlock).
* **29** partly expressible (at least one grant; some effects wait on a requested key).
* **29** have no grant yet (blocked on key requests; listed in `trees.tres blocked_on_keys`).
* A blocked part is inactive at runtime until the key ships. `test_requested_keys_are_not_grantable_yet`
  fails as soon as the lead registers one, as a reminder to add the grant and remove the entry.

## Skill list

PD2 analog in brackets (Appendix A). Grants: basic / aced (aced applies in addition). Blocked: keys
requested below.

### Ringleader (PD2 Mastermind)

#### Field Medic

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Triage** [Combat Medic]<br>`skill.field_medic.triage` | Take 30% less damage while reviving a crew member and for 5 s afterwards. | Crew members you revive get up with 30% more health. |  |  | basic: `defense.reviving_damage_taken_mult`<br>aced: `ability.revive_target_health_mult` |
| 2 | **Bedside Manner** [Quick Fix]<br>`skill.field_medic.bedside_manner` | Deploy First Aid Kits and Doctor Bags 50% faster. | Crew members who use your First Aid Kits or Doctor Bags take 10% less damage for 120 s. |  |  | basic: `deploy.deploy_speed_mult`<br>aced: `deploy.medical_user_buff` |
| 2 | **Numbing Agent** [Painkillers]<br>`skill.field_medic.numbing_agent` | Crew members you revive take 30% less damage for 5 s. | That damage reduction rises to 80%. |  |  | basic: `ability.revive_target_buff`<br>aced: `ability.revive_target_buff` |
| 3 | **Field Kit** [Uppers]<br>`skill.field_medic.field_kit` | Carry 7 more First Aid Kits. | Carry 3 more First Aid Kits. A crew member who goes down within 5 m of one of your placed kits uses it automatically and stays up (at most once every 20 s). | `deploy.extra.fak`=7 | `deploy.extra.fak`=3 | aced: `deploy.fak_auto_revive` |
| 3 | **House Call** [Combat Doctor]<br>`skill.field_medic.house_call` | Carry 2 Doctor Bags instead of 1. | Your Doctor Bags have 2 more charges (4 each). | `deploy.extra.doctor_bag`=1 | `deploy.capacity_mult.doctor_bag`=2.0 |  |
| 4 | **Rally Cry** [Inspire]<br>`skill.field_medic.rally_cry` | Revive crew members 100% faster. Shouting at a crew member gives them 20% more movement and reload speed for 10 s. | Shout at a downed crew member up to 9 m away to revive them instantly. Once every 20 s. | `interaction.revive_speed_mult`=0.5<br>`ability.inspire`={"range": 0.0, "cooldown": 0.0, "buff_move_mult": 1.2, "buff_reload_mult": 1.2, "buff_duration": 10.0} | `ability.inspire`={"range": 9.0, "cooldown": 20.0, "buff_move_mult": 1.2, "buff_reload_mult": 1.2, "buff_duration": 10.0} |  |

#### Persuader

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Zip & Tie** [Forced Friendship]<br>`skill.persuader.zip_and_tie` | Carry 4 more cable ties. Tie hostages 75% faster. | You and your crew absorb 5 damage from every hit for each hostage you hold, up to 8 hostages. Crew-wide; does not stack with another Zip & Tie. | `stealth.cable_ties_extra`=4<br>`stealth.cable_tie_speed_mult`=0.25 | `team.damage_reduction_hostage`={"per": 5.0, "max": 8} |  |
| 2 | **Silver Tongue** [Confident]<br>`skill.persuader.silver_tongue` | Your shouts reach civilians 50% further. | You can keep 2 converted enemies at once. | `stealth.civilian_intimidate_range_mult`=1.5 | `ability.converts_max`=1 |  |
| 2 | **Turncoat** [Joker]<br>`skill.persuader.turncoat` | Your shouts can make low-tier police surrender. Hold the shout on a surrendered non-special enemy to convert them into an ally (loud only, 1 at a time). | Converted allies deal 35% more damage, and converting takes 65% less time. | `ability.intimidate_cops`=true<br>`ability.converts_max`=1 |  | aced: `ability.convert_damage_mult`, `ability.convert_speed_mult` |
| 3 | **Captive Audience** [Stockholm Syndrome]<br>`skill.persuader.captive_audience` | Your gunfire intimidates nearby civilians, and intimidated civilians stay down 50% longer. | When you go down, a hostage near you can revive you. Once per heist. | `stealth.civilian_stay_down_mult`=1.5 | `ability.stockholm`=true | basic: `stealth.noise_intimidates_civilians` |
| 3 | **Accomplice** [Partners in Crime]<br>`skill.persuader.accomplice` | While you have a converted ally, you move 10% faster. Your converted allies take 45% less damage. | While you have a converted ally, you have 30% more health. Your converted allies take a further 54% less damage. | `ability.convert_health_mult`=1.82 | `ability.convert_health_mult`=2.17 | basic: `ability.convert_owner_buff`<br>aced: `ability.convert_owner_buff` |
| 4 | **Leverage** [Hostage Taker]<br>`skill.persuader.leverage` | While you hold at least one hostage or converted ally, regenerate 1.5% health every 5 s. | The regeneration rises to 4.5% every 5 s. | `ability.hostage_regen`={"per_hostage": 0.015, "max_hostages": 1, "interval": 5.0} | `ability.hostage_regen`={"per_hostage": 0.045, "max_hostages": 1, "interval": 5.0} |  |

#### Marksman

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Steady Aim** [Stable Shot]<br>`skill.marksman.steady_aim` | +8 stability (8% less recoil) with all weapons. | +16 accuracy (16% tighter spread) while standing still. | `weapon.recoil_mult.all`=0.92 |  | aced: `weapon.still_spread_mult` |
| 2 | **Snap Shot** [Rifleman]<br>`skill.marksman.snap_shot` | Aim down sights 100% faster with all weapons and move at full speed while aiming. | +16 accuracy while moving with SMGs, assault rifles and sniper rifles. | `weapon.ads_speed_mult.all`=2.0 |  | basic: `movement.ads_speed_penalty_mult`<br>aced: `weapon.moving_spread_mult` |
| 2 | **Deliberate Fire** [Marksman]<br>`skill.marksman.deliberate_fire` | +8 accuracy with SMGs, assault rifles and sniper rifles. | +12 more accuracy with SMGs, assault rifles and sniper rifles. | `weapon.spread_mult.smg`=0.92<br>`weapon.spread_mult.assault_rifle`=0.92<br>`weapon.spread_mult.sniper`=0.92 | `weapon.spread_mult.smg`=0.88<br>`weapon.spread_mult.assault_rifle`=0.88<br>`weapon.spread_mult.sniper`=0.88 |  |
| 3 | **Economy** [Ammo Efficiency]<br>`skill.marksman.economy` | 3 headshots within 6 s with an SMG, assault rifle or sniper rifle put 1 round back in the magazine. | Only 2 headshots are needed. |  |  | basic: `weapon.headshot_refund`<br>aced: `weapon.headshot_refund` |
| 3 | **Reload Rhythm** [Aggressive Reload]<br>`skill.marksman.reload_rhythm` | Reload SMGs, assault rifles and sniper rifles 15% faster. | A headshot kill with one of them doubles your reload speed for 4 s. | `weapon.reload_speed_mult.smg`=1.15<br>`weapon.reload_speed_mult.assault_rifle`=1.15<br>`weapon.reload_speed_mult.sniper`=1.15 |  | aced: `weapon.kill_reload_buff` |
| 4 | **Grazing Fire** [Graze]<br>`skill.marksman.grazing_fire` | Sniper rifle hits also deal 20% of their damage to every enemy within 1 m of the bullet's path. | If the hit is a headshot kill, the graze deals 100% of the damage. |  |  | basic: `weapon.graze`<br>aced: `weapon.graze` |

### Bruiser (PD2 Enforcer)

#### Scattergun

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Outnumbered** [Underdog]<br>`skill.scattergun.outnumbered` | When 3 or more enemies are within 18 m, deal 15% more damage for 7 s. | You also take 10% less damage for those 7 s. |  |  | basic: `defense.outnumbered`<br>aced: `defense.outnumbered` |
| 2 | **Pump Action** [Shotgun CQB]<br>`skill.scattergun.pump_action` | Reload shotguns 15% faster. | Reload shotguns a further 17% faster (35% in total) and aim them down sights 125% faster. | `weapon.reload_speed_mult.shotgun`=1.15 | `weapon.reload_speed_mult.shotgun`=1.174<br>`weapon.ads_speed_mult.shotgun`=2.25 |  |
| 2 | **Heavy Shot** [Shotgun Impact]<br>`skill.scattergun.heavy_shot` | +8 stability and 5% more damage with shotguns. | Shotgun damage rises to 15% more in total. | `weapon.recoil_mult.shotgun`=0.92<br>`weapon.damage_mult.shotgun`=1.05 | `weapon.damage_mult.shotgun`=1.095 |  |
| 3 | **Long Barrel** [Far Away]<br>`skill.scattergun.long_barrel` | Shotguns are 40% more accurate. | Shotgun damage starts falling off 50% further away. | `weapon.spread_mult.shotgun`=0.6 |  | aced: `weapon.falloff_range_mult` |
| 3 | **Hip Fire** [Close By]<br>`skill.scattergun.hip_fire` | Fire shotguns from the hip while sprinting. | Shotguns fire 35% faster from the hip. |  |  | basic: `movement.shoot_while_sprinting.shotgun`<br>aced: `weapon.hip_fire_rate_mult` |
| 4 | **Momentum** [Overkill]<br>`skill.scattergun.momentum` | A shotgun kill gives you 75% more shotgun damage for 20 s. | The bonus applies to all your weapons (a shotgun kill still triggers it). Swap weapons 80% faster. |  | `weapon.swap_speed_mult.all`=1.8 | basic: `weapon.kill_damage_buff`<br>aced: `weapon.kill_damage_buff` |

#### Juggernaut

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Thick Skin** [Resilience]<br>`skill.juggernaut.thick_skin` | Your armor regenerates 15% faster. | Flashbangs blind you for 75% less time. | `defense.armor_regen_rate_mult`=1.15 |  | aced: `defense.flashbang_duration_mult` |
| 2 | **Hold the Line** [Die Hard]<br>`skill.juggernaut.hold_the_line` | Taking damage no longer interrupts your interactions. | Take 50% less damage while interacting. | `interaction.no_interrupt_on_damage`=true |  | aced: `defense.interact_damage_taken_mult` |
| 2 | **Hauler** [Transporter]<br>`skill.juggernaut.hauler` | Throw bags 50% further. | Bags slow you 10% less. | `loot.throw_distance_mult`=1.5 | `loot.carry_speed_penalty_mult`=0.9 |  |
| 3 | **Shoulder Check** [Shock and Awe]<br>`skill.juggernaut.shoulder_check` | Your crew's armor regenerates 25% faster. Crew-wide; does not stack with another Shoulder Check. | Your hits can knock Bulwarks back: melee always, ranged with a chance that rises with weapon damage. |  |  | basic: `team.armor_regen_rate_mult`<br>aced: `weapon.shield_knockback` |
| 3 | **Clean Shot** [Bullseye]<br>`skill.juggernaut.clean_shot` | Each headshot restores 5 armor (at most once every 2 s). | Each headshot restores 25 armor instead. | `defense.bullseye`={"armor": 5.0, "cooldown": 2.0} | `defense.bullseye`={"armor": 25.0, "cooldown": 2.0} |  |
| 4 | **Plated** [Iron Man]<br>`skill.juggernaut.plated` | +30% armor. | Unlocks the Breacher Plate, the heaviest armor (170 armor, 1 concealment). | `defense.armor_mult`=1.3 |  | aced: unlock `armor.breacher_plate` |

#### Quartermaster

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Scrounger** [Scavenger]<br>`skill.quartermaster.scrounger` | Pick up ammo from 50% further away. | Every 6th enemy you kill drops an extra ammo box. |  |  | basic: `weapon.ammo_pickup_range_mult`<br>aced: `weapon.kill_ammo_drop` |
| 2 | **Lead Rain** [Bulletstorm]<br>`skill.quartermaster.lead_rain` | Crew members who refill from your ammo bags don't use ammo for up to 5 s; the more they took, the longer. | The effect lasts up to 15 s longer. |  |  | basic: `deploy.ammo_bag_bulletstorm`<br>aced: `deploy.ammo_bag_bulletstorm` |
| 2 | **Strip Loader** [Portable Saw (replaced)]<br>`skill.quartermaster.strip_loader` | Reload all weapons 10% faster. | Swap weapons 25% faster. | `weapon.reload_speed_mult.all`=1.1 | `weapon.swap_speed_mult.all`=1.25 |  |
| 3 | **Penetrator Loads** [Saw Massacre (replaced)]<br>`skill.quartermaster.penetrator_loads` | Your rounds pierce Bulwark shields, but you carry 15% less ammo. | The ammo penalty is removed. | `weapon.shield_pierce`=true<br>`weapon.ammo_total_mult.all`=0.85 | `weapon.ammo_total_mult.all`=1.1765 |  |
| 3 | **Second Crate** [Extra Lead]<br>`skill.quartermaster.second_crate` | Carry 2 ammo bags instead of 1. | Your ammo bags hold 50% more ammo. | `deploy.extra.ammo_bag`=1 | `deploy.capacity_mult.ammo_bag`=1.5 |  |
| 4 | **Pack Mule** [Fully Loaded]<br>`skill.quartermaster.pack_mule` | Carry 25% more ammo for all weapons. | Ammo boxes give 75% more ammo and have a 5% chance (+1% for every box without one) to hold a throwable. | `weapon.ammo_total_mult.all`=1.25 | `weapon.ammo_pickup_mult.all`=1.75 | aced: `weapon.ammo_pickup_throwable` |

### Wrench (PD2 Technician)

#### Sapper

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Mount Up** [Third Law]<br>`skill.sapper.mount_up` | Sentry guns cost 5% less of your ammo to deploy. | Your sentry guns get a protective shield. |  |  | basic: `deploy.sentry_cost_mult`<br>aced: `deploy.sentry_shield` |
| 2 | **Calibrated** [Sentry Targeting Package]<br>`skill.sapper.calibrated` | Your sentry guns are 100% more accurate. | Your sentry guns turn 150% faster and carry 50% more ammo. |  | `deploy.capacity_mult.sentry`=1.5 | basic: `deploy.sentry_accuracy_mult`<br>aced: `deploy.sentry_turn_speed_mult` |
| 2 | **Lean Build** [Eco Sentry]<br>`skill.sapper.lean_build` | Sentry guns cost a further 5% less of your ammo to deploy. | Your sentry guns have 150% more health. |  |  | basic: `deploy.sentry_cost_mult`<br>aced: `deploy.sentry_health_mult` |
| 3 | **Silent Partner** [Engineering]<br>`skill.sapper.silent_partner` | Switch your sentry guns to quiet mode: enemies are much less likely to target them. | Switch your sentry guns to armor-piercing rounds: 75% lower fire rate, 250% more damage, pierces enemies and shields. |  |  | basic: `deploy.sentry_modes`<br>aced: `deploy.sentry_modes` |
| 3 | **Two Kits** [Jack of All Trades]<br>`skill.sapper.two_kits` | Deploy and use all deployables 100% faster. | Carry a second deployable type (half the usual amount of it). |  | `deploy.second_deployable`=true | basic: `deploy.deploy_speed_mult` |
| 4 | **Battery** [Tower Defense]<br>`skill.sapper.battery` | Carry 1 more sentry gun. | Carry 2 more sentry guns. | `deploy.extra.sentry`=1 | `deploy.extra.sentry`=2 |  |

#### Breacher

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Tinker** [Hardware Expert]<br>`skill.breacher.tinker` | Fix drills and saws 25% faster and place trip mines 20% faster. Your drills and saws are silent: guards and civilians must see them to react. | Your drills and saws have a 10% chance to restart by themselves after jamming. | `stealth.silent_devices`=true | `interaction.device_auto_restart_chance`=0.1 | basic: `interaction.device_fix_speed_mult`, `deploy.deploy_speed_mult` |
| 2 | **Charge Shaping** [Combat Engineering]<br>`skill.breacher.charge_shaping` | Your trip mines have a 30% larger blast radius. | Use trip mines as shaped charges on doors and safes. |  | `interaction.shaped_charge`=true | basic: `deploy.trip_mine_radius_mult` |
| 2 | **Overclocked Bits** [Drill Sawgeant]<br>`skill.breacher.overclocked_bits` | Drill and saw timers are 15% shorter. | They are 30% shorter in total. | `interaction.device_speed_mult`=0.85 | `interaction.device_speed_mult`=0.8235 |  |
| 3 | **Extra Charges** [More Firepower]<br>`skill.breacher.extra_charges` | Carry 4 more trip mines. | Carry 3 more trip mines (7 in total). | `deploy.extra.trip_mine`=4 | `deploy.extra.trip_mine`=3 |  |
| 3 | **Percussive Maintenance** [Kickstarter]<br>`skill.breacher.percussive_maintenance` | Your drills and saws have a further 20% chance to restart by themselves after jamming. | Hit a jammed drill or saw with your melee weapon for a 50% chance to restart it (one try per jam). | `interaction.device_auto_restart_chance`=0.2 | `interaction.device_melee_restart`=true |  |
| 4 | **Hot Floor** [Fire Trap]<br>`skill.breacher.hot_floor` | Your trip mines leave a 4 m wide fire for 10 s when they go off. | The fire lasts 10 s longer and covers a 50% larger area. |  |  | basic: `deploy.trip_mine_fire`<br>aced: `deploy.trip_mine_fire` |

#### Gunnery

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Firm Grip** [Steady Grip]<br>`skill.gunnery.firm_grip` | +8 accuracy (8% tighter spread) with all weapons. | +16 stability (16% less recoil) with all weapons. | `weapon.spread_mult.all`=0.92 | `weapon.recoil_mult.all`=0.84 |  |
| 2 | **Knockdown** [Heavy Impact]<br>`skill.gunnery.knockdown` | Your shots have a 5% chance to stagger enemies (Wreckers and Commander Brandt are immune). | The stagger chance rises to 20%. |  |  | basic: `weapon.stagger_chance_add`<br>aced: `weapon.stagger_chance_add` |
| 2 | **Hip Discipline** [Fire Control]<br>`skill.gunnery.hip_discipline` | +12 accuracy when firing from the hip. | The accuracy penalty for moving is 20% smaller. |  |  | basic: `weapon.hip_spread_mult`<br>aced: `weapon.moving_spread_mult` |
| 3 | **Run and Gun** [Lock N' Load]<br>`skill.gunnery.run_and_gun` | Fire any weapon while sprinting. | Killing 2 enemies with an automatic SMG, LMG, assault rifle or special weapon makes your next reload up to 100% faster (at least 40% for large magazines). | `movement.shoot_while_sprinting`=true |  | aced: `weapon.kill_reload_buff` |
| 3 | **Hardball** [Surefire]<br>`skill.gunnery.hardball` | SMGs, LMGs and assault rifles hold 15 more rounds per magazine. | All your ranged weapons pierce body armor. | `weapon.mag_extra.smg`=15<br>`weapon.mag_extra.lmg`=15<br>`weapon.mag_extra.assault_rifle`=15 | `weapon.armor_pierce_add.all`=1.0 |  |
| 4 | **Anatomy** [Body Expertise]<br>`skill.gunnery.anatomy` | Automatic fire with SMGs, LMGs, assault rifles and special weapons applies 30% of the headshot bonus to body hits. | 90% of the headshot bonus applies. |  |  | basic: `weapon.body_expertise`<br>aced: `weapon.body_expertise` |

### Shade (PD2 Ghost)

#### Infiltrator

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Plain Sight** [Chameleon]<br>`skill.infiltrator.plain_sight` | While casing, you are detected 25% more slowly and can mark guards and cameras. | Pick up small loot and items while casing. Small loot you pick up is worth 30% more. | `stealth.casing_detection_rate_mult`=0.75 | `stealth.casing_can_pickup_items`=true | basic: `stealth.casing_can_mark`<br>aced: `loot.small_loot_value_mult` |
| 2 | **Tidy Up** [Cleaner]<br>`skill.infiltrator.tidy_up` | Carry 1 more body bag. | Carry 2 body bag cases. | `stealth.body_bags_extra`=1 | `deploy.extra.body_bag_case`=1 |  |
| 2 | **Gut Feeling** [Sixth Sense]<br>`skill.infiltrator.gut_feeling` | Stand still for 3.5 s in stealth to mark every enemy within 10 m automatically. | Answer pagers 50% faster. | `stealth.sixth_sense`=true | `stealth.pager_answer_speed_mult`=0.5 |  |
| 3 | **Light Fingers** [Nimble]<br>`skill.infiltrator.light_fingers` | Loop a camera for 25 s so it sees nothing (one camera at a time). | Pick locks 100% faster, and pick the locks of small safes. | `stealth.camera_loop`=true | `interaction.lockpick_speed_mult`=0.5<br>`interaction.can_lockpick_safes`=true |  |
| 3 | **Signal Flood** [ECM Overdrive]<br>`skill.infiltrator.signal_flood` | ECM jams and ECM feedback last 25% longer. | Place an ECM on a keycard door (4 s) or an ATM (8 s) to open it. The ECM is used up. | `stealth.ecm_duration_mult`=1.25<br>`stealth.ecm_feedback_duration_mult`=1.25 | `stealth.ecm_opens_doors`=true |  |
| 4 | **Jammer Jockey** [ECM Specialist]<br>`skill.infiltrator.jammer_jockey` | Carry 2 ECM jammers. | ECM jams and feedback last a further 25% longer. Pagers of guards killed during a jam stay silent until it ends. | `stealth.ecm_extra`=1 | `stealth.ecm_duration_mult`=1.25<br>`stealth.ecm_feedback_duration_mult`=1.25<br>`stealth.ecm_pager_delay`=true |  |

#### Slipstream

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Light Step** [Duck and Cover]<br>`skill.slipstream.light_step` | 25% more stamina. Sprint 25% faster. | +10% dodge while sprinting. | `movement.stamina_mult`=1.25 |  | basic: `movement.sprint_speed_mult`<br>aced: `defense.sprint_dodge_add` |
| 2 | **Free Running** [Parkour]<br>`skill.slipstream.free_running` | Move 10% faster. | Sprint in any direction, and reload while sprinting. | `movement.speed_mult`=1.1 | `movement.reload_while_sprinting`=true | aced: `movement.sprint_any_direction` |
| 2 | **Deep Pockets** [Inner Pockets]<br>`skill.slipstream.deep_pockets` | +2 concealment on your melee weapon. | +4 concealment on your armor. | `stealth.concealment_add.melee`=2 | `stealth.concealment_add.armor`=4 |  |
| 3 | **Cornered** [Dire Need]<br>`skill.slipstream.cornered` | While your armor is broken, your first shot on each enemy staggers it. | The effect lasts 6 s after your armor comes back. |  |  | basic: `defense.armor_broken_stagger`<br>aced: `defense.armor_broken_stagger` |
| 3 | **Grounded** [Shockproof]<br>`skill.slipstream.grounded` | When a Stinger tases you, there is a 30% chance it backfires and knocks the Stinger back. | Interact within 2 s of being tased to shock the Stinger and break free. | `defense.shockproof`={"backfire_chance": 0.3, "tase_shorten": 0.0, "can_interact_counter": false, "counter_window": 0.0} | `defense.shockproof`={"backfire_chance": 0.3, "tase_shorten": 0.0, "can_interact_counter": true, "counter_window": 2.0} |  |
| 4 | **Slippery** [Sneaky Bastard]<br>`skill.slipstream.slippery` | +1% dodge for every 3 points your detection risk is below 35, up to +10%. | +1% dodge for every point below 35, up to +10%. |  |  | basic: `defense.dodge_per_concealment`<br>aced: `defense.dodge_per_concealment` |

#### Quiet Professional

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Bolt** [Second Wind]<br>`skill.quiet_professional.bolt` | When your armor breaks, move 30% faster for 5 s. | Your crew gets the speed boost too. |  |  | basic: `defense.armor_break_speed_buff`<br>aced: `defense.armor_break_speed_buff` |
| 2 | **Low Profile** [Optical Illusions]<br>`skill.quiet_professional.low_profile` | Enemies are 35% less likely to target you. | +1 concealment for each suppressed weapon you carry, and suppressors cost 2 less concealment. |  |  | basic: `defense.target_priority_mult`<br>aced: `stealth.concealment_add.suppressed` |
| 2 | **Hushed Hands** [The Professional]<br>`skill.quiet_professional.hushed_hands` | +8 stability and 100% faster aiming with suppressed weapons. | +12 accuracy with suppressed weapons. |  |  | basic: `weapon.recoil_mult.suppressed`, `weapon.ads_speed_mult.suppressed`<br>aced: `weapon.spread_mult.suppressed` |
| 3 | **Cheap Shot** [Low Blow]<br>`skill.quiet_professional.cheap_shot` | +3% critical hit chance for every 3 points your detection risk is below 35, up to 30%. | +3% for every point below 35, up to 30%. |  |  | basic: `weapon.crit_per_concealment`<br>aced: `weapon.crit_per_concealment` |
| 3 | **Price Tag** [High Value Target]<br>`skill.quiet_professional.price_tag` | Enemies you mark take 15% more damage. | Marks last twice as long. Marked enemies more than 10 m away take a further 50% more damage. Mark specials by aiming at them. | `stealth.mark_damage_bonus_mult`=1.15 | `stealth.mark_duration_mult`=2.0 | aced: `stealth.mark_far_damage_mult`, `stealth.mark_by_aim` |
| 4 | **Ambusher** [Unseen Strike]<br>`skill.quiet_professional.ambusher` | If you lose no armor or health for 4 s, gain +35% critical hit chance for 6 s. | The critical hit bonus lasts 18 s. |  |  | basic: `weapon.unseen_strike`<br>aced: `weapon.unseen_strike` |

### Outlaw (PD2 Fugitive)

#### Two-Gun

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Quick Holster** [Equilibrium]<br>`skill.two_gun.quick_holster` | Draw and holster pistols in 33% less time. | +8 accuracy with pistols. | `weapon.swap_speed_mult.pistol`=1.5 | `weapon.spread_mult.pistol`=0.92 |  |
| 2 | **Extended Clip** [Gun Nut]<br>`skill.two_gun.extended_clip` | Pistols hold 5 more rounds per magazine. | Pistols fire 50% faster. | `weapon.mag_extra.pistol`=5 |  | aced: `weapon.fire_rate_mult` |
| 2 | **Both Hands** [Akimbo]<br>`skill.two_gun.both_hands` | +8 stability with akimbo weapons. | +8 more stability with akimbo weapons, and they carry 50% more ammo. |  |  | basic: `weapon.recoil_mult.akimbo`<br>aced: `weapon.recoil_mult.akimbo`, `weapon.ammo_total_mult.akimbo` |
| 3 | **Steel Core** [One Handed Talent (replaced)]<br>`skill.two_gun.steel_core` | Pistol rounds have a 50% chance to pierce body armor. | Pistol rounds always pierce body armor, and pistols deal 15% more damage. | `weapon.armor_pierce_add.pistol`=0.5 | `weapon.armor_pierce_add.pistol`=0.5<br>`weapon.damage_mult.pistol`=1.15 |  |
| 3 | **Rhythm** [Desperado]<br>`skill.two_gun.rhythm` | Each pistol hit gives +10% accuracy for 10 s, stacking 4 times. | Reload pistols 50% faster. |  | `weapon.reload_speed_mult.pistol`=1.5 | basic: `weapon.hit_stack_buff` |
| 4 | **Hot Streak** [Trigger Happy]<br>`skill.two_gun.hot_streak` | Each pistol hit gives +20% pistol damage for 2 s. | The bonus lasts 4 s. |  |  | basic: `weapon.hit_stack_buff`<br>aced: `weapon.hit_stack_buff` |

#### Undying

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Cat's Luck** [Nine Lives]<br>`skill.undying.cats_luck` | You have 50% more health while bleeding out. | You can go down 1 more time before custody. |  | `defense.downs_extra`=1 | basic: `defense.bleedout_health_mult` |
| 2 | **Second Lease** [Running From Death]<br>`skill.undying.second_lease` | For 10 s after being revived, reload and swap weapons 100% faster. | For those 10 s you also move 30% faster. |  |  | basic: `defense.post_revive_buff`<br>aced: `defense.post_revive_buff` |
| 2 | **Back on Your Feet** [Up You Go]<br>`skill.undying.back_on_your_feet` | Take 30% less damage for 10 s after being revived. | Get up with 40% more health. |  | `defense.revived_health_mult`=1.4 | basic: `defense.post_revive_buff` |
| 3 | **Last Stand** [Swan Song]<br>`skill.undying.last_stand` | When you would go down, keep fighting for 3 s first, moving 60% slower. | You keep fighting for 6 s, and your ammo is not used up meanwhile. | `defense.swan_song`={"duration": 3.0, "speed_penalty": 0.6, "infinite_ammo": false} | `defense.swan_song`={"duration": 6.0, "speed_penalty": 0.6, "infinite_ammo": true} |  |
| 3 | **Playing Possum** [Feign Death (redesigned)]<br>`skill.undying.playing_possum` | While you are down, your bleedout timer pauses whenever no enemy can see you. | Bleed out 15 s more slowly. |  | `defense.bleedout_time_add`=15.0 | basic: `defense.bleedout_pause_unseen` |
| 4 | **Comeback** [Messiah]<br>`skill.undying.comeback` | While bleeding out, kill an enemy to get back up. 1 charge per heist. | Using a Doctor Bag restores your charge. | `defense.self_revive_charges`=1 |  | aced: `defense.self_revive_refill_on_doctor_bag` |

#### Scrapper

| T | Skill | Basic | Aced | Grants basic | Grants aced | Blocked on |
|---|---|---|---|---|---|---|
| 1 | **Iron Jaw** [Martial Arts]<br>`skill.scrapper.iron_jaw` | Take 50% less damage from melee attacks. | Your melee strikes are 50% more likely to knock enemies down. |  |  | basic: `defense.melee_damage_taken_mult`<br>aced: `weapon.melee_knockdown_mult` |
| 2 | **Wind Up** [Bloodthirst]<br>`skill.scrapper.wind_up` | Each kill adds +100% damage to your next melee hit, up to +1600%. A melee kill spends it. | A melee kill gives 50% faster reloads for 10 s. |  |  | basic: `weapon.melee_bloodthirst`<br>aced: `weapon.kill_reload_buff` |
| 2 | **Heavy Hands** [Pumping Iron]<br>`skill.scrapper.heavy_hands` | Deal 100% more melee damage. | Charge melee attacks 50% faster. | `weapon.damage_mult.melee`=2.0 | `weapon.melee_charge_speed_mult`=1.5 |  |
| 3 | **Riposte** [Counterstrike]<br>`skill.scrapper.riposte` | While charging a melee attack, counter enemies that strike you and knock them down. | You also counter Phantom kicks. |  | `defense.cloaker_counter`=true | basic: `defense.melee_counter` |
| 3 | **Red Mist** [Berserker]<br>`skill.scrapper.red_mist` | Below 50% health, deal up to 250% more melee damage the lower your health is. | Ranged weapons gain up to 100% more damage the same way. | `defense.berserk`={"threshold": 0.5, "max_damage_mult": 3.5, "ranged_max_damage_mult": 1.0} | `defense.berserk`={"threshold": 0.5, "max_damage_mult": 3.5, "ranged_max_damage_mult": 2.0} |  |
| 4 | **Nothing to Lose** [Frenzy]<br>`skill.scrapper.nothing_to_lose` | Your max health drops to 30% and healing on you is 75% weaker, but you take 10% less damage. | Take 25% less damage instead, and healing is no longer weakened. | `defense.health_mult`=0.3<br>`defense.damage_taken_mult`=0.9 | `defense.damage_taken_mult`=0.8333 | basic: `defense.healing_received_mult`<br>aced: `defense.healing_received_mult` |

## Decisions

Every tier-3 and tier-4 skill must change a decision (pd2_fidelity P2). Where PD2's skill was filler or
depended on content we do not have, it was redesigned (marked *replaced/redesigned*).

| Skill | Tier | What decision it changes |
|---|---|---|
| **Field Kit** `skill.field_medic.field_kit` | 3 | Aced turns First Aid Kits from heals into pre-placed down insurance: you seed kits where the crew will hold (vault door, bag drop, escape) before the fight instead of carrying them. |
| **House Call** `skill.field_medic.house_call` | 3 | Two bags are two medical stations: one at the objective, one at the fallback or escape, so the crew can split up. Aced makes you the crew's down-reset supply, which frees the other three deployable slots for ammo bags and ECMs. |
| **Rally Cry** `skill.field_medic.rally_cry` | 4 | Reviving no longer means walking into the fire: you stay in cover and decide whom to pick up and when to spend the 20 s cooldown, and the crew can take riskier positions around you. |
| **Captive Audience** `skill.persuader.captive_audience` | 3 | Hostages become a personal revive and gunfire becomes crowd control: you keep one hostage at your holding position instead of trading it, and you go loud inside crowds without spending shouts. |
| **Accomplice** `skill.persuader.accomplice` | 3 | Your convert stops being disposable: your own speed and health depend on it, so you keep it near you, re-convert as soon as you lose it and keep a surrendered cop in reserve. |
| **Leverage** `skill.persuader.leverage` | 4 | Your healing is a living hostage: you take and guard one at the start of every loud phase (and stop the police rescuing it) instead of leaning on Doctor Bags. |
| **Economy** `skill.marksman.economy` | 3 | Rewards a paced, aimed rhythm over spraying: hitting heads keeps the magazine topped up, so a precise player can run without an ammo bag in the crew. |
| **Reload Rhythm** `skill.marksman.reload_rhythm` | 3 | Aced makes reload timing a choice: you reload right after a headshot kill, mid-fight, instead of only when the magazine runs dry. |
| **Grazing Fire** `skill.marksman.grazing_fire` | 4 | Sniper rifles become crowd weapons: you line up the head of the front enemy in a column or cluster instead of picking off specials, and a sniper primary becomes a chokepoint-holding choice. |
| **Long Barrel** `skill.scattergun.long_barrel` | 3 | Shotguns become a mid-range primary: you can hold open rooms (lobbies, yards) with a shotgun instead of carrying a rifle as the range gun. |
| **Hip Fire** `skill.scattergun.hip_fire` | 3 | Room clearing on the move: you sprint through a doorway firing instead of stopping to aim, which pairs with Momentum's kill trigger. |
| **Momentum** `skill.scattergun.momentum` | 4 | Loadout and rhythm change: you carry a shotgun secondary purely as the trigger, open every fight with a shotgun kill, then swap to the primary with the bonus running. |
| **Shoulder Check** `skill.juggernaut.shoulder_check` | 3 | Knocking a Bulwark back opens it up for the whole crew: you become the shield breaker and pick a high-damage weapon for it, while the team aura means one Juggernaut per crew is enough. |
| **Clean Shot** `skill.juggernaut.clean_shot` | 3 | Armor sustain comes from aim: a heavy-armor player picks an accurate weapon and pops heads on weak enemies to refill, instead of retreating out of sight to regenerate. |
| **Plated** `skill.juggernaut.plated` | 4 | Aced is a hard stealth-or-loud fork: the Breacher Plate (170 armor, 1 concealment, -55 dodge, slow) commits the whole loadout to loud, and the basic bonus rewards heavy vests in general. |
| **Penetrator Loads** `skill.quartermaster.penetrator_loads` | 3 | A real trade: every gun handles Bulwarks, which frees you from carrying a sniper or LMG for them, at the cost of ammo until you invest in the ace. |
| **Second Crate** `skill.quartermaster.second_crate` | 3 | Two bags (which become damage stations with Lead Rain) let the crew hold two positions at once, objective and escape, instead of falling back to a single supply point. |
| **Pack Mule** `skill.quartermaster.pack_mule` | 4 | Throwables refill from the floor, so a grenade-heavy loadout becomes sustainable, and you no longer need an ammo bag: your deployable slot goes to an ECM or Doctor Bag instead. |
| **Silent Partner** `skill.sapper.silent_partner` | 3 | Sentries get modes you switch mid-fight: quiet for long holds where they must survive, armor piercing when Bulwarks and heavies arrive. Walking back to reconfigure them is a new verb. |
| **Two Kits** `skill.sapper.two_kits` | 3 | A second deployable rewrites the crew plan: one player can carry ECM and a Doctor Bag, so the crew covers stealth and loud needs without leaving a slot empty. |
| **Battery** `skill.sapper.battery` | 4 | Sentries go from one helper to an area-denial network: you plan positions that cover every flank and spend your own ammo on them instead of on your guns. |
| **Extra Charges** `skill.breacher.extra_charges` | 3 | With Charge Shaping's ace, trip mines are breaching charges: enough of them lets you blow doors and safes in seconds instead of drilling (loud and fast versus slow), or mine every flank. |
| **Percussive Maintenance** `skill.breacher.percussive_maintenance` | 3 | Aced turns a jam into a gamble you take under fire: you guard the drill from melee range and try a 1 s hit before committing to the long fix interaction. |
| **Hot Floor** `skill.breacher.hot_floor` | 4 | Trip mines become area denial instead of alarms: you mine the chokepoints the assault must come through and time your defense around the burn. |
| **Run and Gun** `skill.gunnery.run_and_gun` | 3 | Removes the stop-to-shoot trade: you reposition and flank under fire, and the ace times your reloads to kill pairs. |
| **Hardball** `skill.gunnery.hardball` | 3 | TAC Heavy plates stop dictating your weapon: with armor piercing on every gun you drop the AP mods and the sniper and build for fire rate and capacity. |
| **Anatomy** `skill.gunnery.anatomy` | 4 | Center-mass spraying becomes as good as aiming for heads: you pick full-auto fire modes and high-capacity weapons and stop chasing headshots. |
| **Light Fingers** `skill.infiltrator.light_fingers` | 3 | Cameras get a silent answer (loop instead of breaking one, which alerts, or spending an ECM), and small safes can be picked quietly instead of drilled. |
| **Signal Flood** `skill.infiltrator.signal_flood` | 3 | An ECM becomes a key as well as a jammer: every jammer is a choice between a quiet window and a door you no longer need a keycard for. |
| **Jammer Jockey** `skill.infiltrator.jammer_jockey` | 4 | Jams become kill windows: you schedule guard kills inside an ECM so their pagers wait, getting past the pager limit on guard-heavy maps. |
| **Cornered** `skill.slipstream.cornered` | 3 | Losing armor opens a crowd-control window: you push into the enemies that broke it instead of retreating, which suits light armor that breaks often. |
| **Grounded** `skill.slipstream.grounded` | 3 | A tase is something you answer yourself: you can push past Stingers alone instead of waiting for the crew to shoot them off you. |
| **Slippery** `skill.slipstream.slippery` | 4 | Stealth gear becomes a loud defense: low-detection loadouts (suits, concealed weapons) survive by dodging, so you pick concealment over armor even on loud heists. |
| **Cheap Shot** `skill.quiet_professional.cheap_shot` | 3 | Concealment becomes a damage stat in loud: a concealed loadout kills faster, so you weigh every mod's concealment cost even when you never intend to stay quiet. |
| **Price Tag** `skill.quiet_professional.price_tag` | 3 | Marking becomes a combat action in loud: you spend a moment marking the Wrecker or Longshot for the whole crew before shooting, and you hold long sightlines. |
| **Ambusher** `skill.quiet_professional.ambusher` | 4 | Rewards fighting from cover and flanks: taking any damage ends the bonus, so you pick angles where you are not shot instead of face-tanking. |
| **Steel Core** `skill.two_gun.steel_core` | 3 | The sidearm becomes the anti-heavy tool: you swap to it against TAC Heavies and Wrecker plates, so your primary can be a non-piercing crowd weapon. |
| **Rhythm** `skill.two_gun.rhythm` | 3 | Rewards sustained pistol fire: the accuracy only holds while you keep landing hits, so the pistol is your main gun, not a backup. |
| **Hot Streak** `skill.two_gun.hot_streak` | 4 | Commits you to a pistol-main build: the bonus only lives while you chain hits, so you fight at pistol range and swap targets instead of reloading. |
| **Last Stand** `skill.undying.last_stand` | 3 | Those seconds are a decision: finish the special, secure the bag or close the objective, or get to cover where the crew can reach you. |
| **Playing Possum** `skill.undying.playing_possum` | 3 | PD2's random self-revive is replaced by a choice: go down in cover and stay quiet to buy the crew time, or shoot from bleedout and give your position away. |
| **Comeback** `skill.undying.comeback` | 4 | Going down becomes a fight, not a wait: you carry a weapon that can kill from bleedout, and the ace ties your run to Doctor Bags. |
| **Riposte** `skill.scrapper.riposte` | 3 | Charging melee becomes a defensive stance: you hold a charge at corners and doorways against Phantoms and melee rushers instead of shooting. |
| **Red Mist** `skill.scrapper.red_mist` | 3 | You stay hurt on purpose: healing costs damage, so you skip Doctor Bags and First Aid Kits and live on armor, which pairs with Nothing to Lose. |
| **Nothing to Lose** `skill.scrapper.nothing_to_lose` | 4 | Permanently low health locks Red Mist at full strength and moves your survival onto armor and dodge: you build for armor regeneration and stop relying on heals. |

Redesigns: Strip Loader (T2) and Penetrator Loads (T3) replace PD2's Portable Saw / Saw Massacre (no saw
weapon in our armory); Steel Core replaces One Handed Talent (flat damage filler at T3); Playing Possum
replaces Feign Death (random self-revive); Gut Feeling aced (pagers) replaces insider-asset access;
Hold the Line basic (no interrupt) and Charge Shaping aced (trip mines as shaped charges) use registry
verbs in place of PD2 filler.

## Requested keys

For the lead (ENV B status file question). None of these is granted; the affected skill parts are
listed in `trees.tres blocked_on_keys`. Proposed phase for all: **P4** (skills ship in P4).

### Revive and medical

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `defense.reviving_damage_taken_mult` | PARAMS {mult: float, linger_s: float} | Incoming damage x `mult` while you hold a revive interaction and for `linger_s` after it completes. | Triage (basic) |
| `ability.revive_target_health_mult` | MULT | Health a crew member YOU revive gets up with (the reviver's skill; `defense.revived_health_mult` is the revived player's own). | Triage (aced) |
| `ability.revive_target_buff` | PARAMS {damage_taken_mult: float, duration: float} | A crew member you revive takes damage x `damage_taken_mult` for `duration` s. | Numbing Agent (aced), Numbing Agent (basic) |
| `deploy.medical_user_buff` | PARAMS {damage_taken_mult: float, duration: float} | Anyone using your First Aid Kit or Doctor Bag takes damage x `damage_taken_mult` for `duration` s. | Bedside Manner (aced) |
| `deploy.fak_auto_revive` | PARAMS {radius: float, cooldown: float} | A crew member downed within `radius` m of your placed First Aid Kit consumes it and is not downed; at most once per `cooldown` s (per owner). | Field Kit (aced) |
| `defense.bleedout_health_mult` | MULT | Bleedout HP (100 base, L2.5). | Cat's Luck (basic) |
| `defense.post_revive_buff` | PARAMS {duration: float, reload_mult: float, swap_mult: float, move_mult: float, damage_taken_mult: float} | Buffs on yourself for `duration` s after being revived (1.0 = none). Basic/aced grant the full dict; last wins, so the aced dict repeats the basic values. | Back on Your Feet (basic), Second Lease (aced), Second Lease (basic) |
| `defense.bleedout_pause_unseen` | FLAG | Bleedout timer pauses while no enemy has line of sight to you (counts again as soon as one does or you fire). | Playing Possum (basic) |
| `defense.self_revive_refill_on_doctor_bag` | FLAG | Using a Doctor Bag restores your `defense.self_revive_charges` to their granted value. | Comeback (aced) |
| `defense.healing_received_mult` | MULT | All healing you receive (bags, kits, regen, perks). | Nothing to Lose (aced), Nothing to Lose (basic) |

### Converts, hostages, civilians

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `ability.convert_damage_mult` | MULT | Damage dealt by your converted allies. | Turncoat (aced) |
| `ability.convert_speed_mult` | MULT | Convert interaction time (lower = faster). | Turncoat (aced) |
| `ability.convert_owner_buff` | PARAMS {move_mult: float, health_mult: float} | While you own at least one living convert: your move speed and max health multipliers. | Accomplice (aced), Accomplice (basic) |
| `stealth.noise_intimidates_civilians` | FLAG | Your unsuppressed gunfire acts as an intimidation shout on civilians within its noise radius. | Captive Audience (basic) |

### Weapon handling (qualified by weapon class or .all)

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `weapon.still_spread_mult` | MULT | Spread multiplier while you stand still. | Steady Aim (aced) |
| `weapon.moving_spread_mult` | MULT | Multiplier on the moving-spread penalty (lower = smaller penalty). | Hip Discipline (aced), Snap Shot (aced) |
| `weapon.hip_spread_mult` | MULT | Spread multiplier for hip fire only. | Hip Discipline (basic) |
| `weapon.fire_rate_mult` | MULT | Rate of fire (higher = faster). | Extended Clip (aced) |
| `weapon.hip_fire_rate_mult` | MULT | Rate of fire while hip firing (single-shot weapons). | Hip Fire (aced) |
| `weapon.falloff_range_mult` | MULT | Scales falloff_start/falloff_end distances. | Long Barrel (aced) |
| `movement.ads_speed_penalty_mult` | MULT | Move-speed penalty while aiming down sights (0 = no penalty). | Snap Shot (basic) |
| `movement.shoot_while_sprinting.shotgun` | FLAG (qualifier) | Accept a weapon-class qualifier on the existing `movement.shoot_while_sprinting` so the shotgun-only version can be granted. | Hip Fire (basic) |

### Weapon qualifiers

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `weapon.recoil_mult.suppressed` | qualifier | New weapon qualifier `suppressed` (weapon has a suppressor mod) for weapon.* keys; Hushed Hands grants recoil_mult/ads_speed_mult/spread_mult with it. | Hushed Hands (basic) |
| `weapon.ads_speed_mult.suppressed` | qualifier | As above. | Hushed Hands (basic) |
| `weapon.spread_mult.suppressed` | qualifier | As above. | Hushed Hands (aced) |
| `stealth.concealment_add.suppressed` | qualifier (ADD) | Concealment per equipped suppressed weapon; LoadoutResolver applies it per suppressed primary/secondary. Low Profile aced also wants suppressors' concealment penalty -2 (same qualifier, counted per suppressor). | Low Profile (aced) |
| `weapon.recoil_mult.akimbo` | qualifier | New weapon qualifier `akimbo` (needs the akimbo weapon category from P5) for weapon.* keys. | Both Hands (aced), Both Hands (basic) |
| `weapon.ammo_total_mult.akimbo` | qualifier | As above. | Both Hands (aced) |

### Triggered combat effects

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `weapon.kill_damage_buff` | PARAMS {trigger_class: String, damage_mult: float, duration: float, all_weapons: bool} | A kill with `trigger_class` gives damage x `damage_mult` for `duration` s, to that class or to all weapons. | Momentum (aced), Momentum (basic) |
| `weapon.kill_reload_buff` | PARAMS {trigger: String (headshot_kill|auto_kills|melee_kill), kills: int, classes: Array, reload_mult: float, duration: float, min_mult: float, mag_falloff: float} | Reload speed bonus after the trigger: timed (`duration` > 0) or next reload only (`duration` 0, Run and Gun with `min_mult`/`mag_falloff` for big magazines). One key, several skills: needs either per-source params or a list value; the lead decides (PARAMS is last-wins today). | Reload Rhythm (aced), Run and Gun (aced), Wind Up (aced) |
| `weapon.hit_stack_buff` | PARAMS {class: String, stat: String (accuracy|damage), per_hit: float, max_stacks: int, duration: float} | Each hit with `class` adds a stack; stacks refresh on hit and expire after `duration`. Same multi-skill caveat as above. | Hot Streak (aced), Hot Streak (basic), Rhythm (basic) |
| `weapon.headshot_refund` | PARAMS {classes: Array, headshots: int, window: float, refund: int} | `headshots` headshots within `window` s refund `refund` rounds to the magazine. | Economy (aced), Economy (basic) |
| `weapon.graze` | PARAMS {class: String, radius: float, frac: float, headshot_kill_frac: float} | Hits deal `frac` of the damage to enemies within `radius` m of the trajectory; `headshot_kill_frac` if the hit was a headshot kill. | Grazing Fire (aced), Grazing Fire (basic) |
| `weapon.body_expertise` | PARAMS {frac: float, auto_only: bool, classes: Array} | Fraction of the headshot bonus applied to non-head hits for automatic fire. | Anatomy (aced), Anatomy (basic) |
| `weapon.stagger_chance_add` | ADD (qualified) | Chance per hit to stagger a non-immune enemy. | Knockdown (aced), Knockdown (basic) |
| `weapon.unseen_strike` | PARAMS {idle_s: float, crit_add: float, duration: float} | After `idle_s` without losing armor/health, +`crit_add` crit chance for `duration` s (taking damage ends it). | Ambusher (aced), Ambusher (basic) |
| `weapon.crit_per_concealment` | PARAMS {per_step: float, points_per_step: int, threshold_dr: int, max: float} | Crit chance from detection risk below `threshold_dr` (35): +`per_step` per `points_per_step` points, capped at `max`. | Cheap Shot (aced), Cheap Shot (basic) |
| `weapon.melee_bloodthirst` | PARAMS {per_kill: float, max_mult: float} | Each non-melee kill adds `per_kill` to the next melee hit's multiplier (cap `max_mult`); a melee kill spends it. | Wind Up (basic) |
| `weapon.melee_knockdown_mult` | MULT | Knockdown chance of your melee hits. | Iron Jaw (aced) |
| `weapon.shield_knockback` | FLAG | Hits can knock Bulwarks back (melee 100%, ranged by damage). | Shoulder Check (aced) |
| `defense.outnumbered` | PARAMS {enemies: int, radius: float, damage_mult: float, damage_taken_mult: float, duration: float} | With `enemies`+ enemies within `radius` m: damage and damage-taken multipliers for `duration` s. | Outnumbered (aced), Outnumbered (basic) |

### Defense and movement

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `defense.flashbang_duration_mult` | MULT | Flashbang blind duration. | Thick Skin (aced) |
| `defense.interact_damage_taken_mult` | MULT | Incoming damage while holding an interaction. | Hold the Line (aced) |
| `defense.armor_break_speed_buff` | PARAMS {move_mult: float, duration: float, team: bool} | On armor break: move speed for `duration` s, also for the crew if `team`. | Bolt (aced), Bolt (basic) |
| `defense.target_priority_mult` | MULT | Weight of you in enemy target selection (lower = targeted less). | Low Profile (basic) |
| `defense.armor_broken_stagger` | PARAMS {persist_s: float} | While armor is broken (and `persist_s` after it recovers) your first hit on each enemy staggers it. | Cornered (aced), Cornered (basic) |
| `defense.dodge_per_concealment` | PARAMS {per_step: float, points_per_step: int, threshold_dr: int, max: float} | Dodge from detection risk below `threshold_dr` (35), same shape as weapon.crit_per_concealment. | Slippery (aced), Slippery (basic) |
| `defense.sprint_dodge_add` | ADD | Dodge added while sprinting. | Light Step (aced) |
| `defense.melee_damage_taken_mult` | MULT | Incoming melee damage. | Iron Jaw (basic) |
| `defense.melee_counter` | FLAG | While charging melee, an enemy melee strike on you is countered (knockdown, no damage). | Riposte (basic) |
| `movement.sprint_speed_mult` | MULT | Sprint speed. | Light Step (basic) |
| `movement.sprint_any_direction` | FLAG | Sprint sideways/backwards. | Free Running (aced) |
| `team.armor_regen_rate_mult` | MULT (team) | Crew-wide armor regeneration speed (team key, non-stacking). | Shoulder Check (basic) |

### Stealth and loot

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `stealth.casing_can_mark` | FLAG | Mark guards and cameras while casing. | Plain Sight (basic) |
| `loot.small_loot_value_mult` | MULT | Value of small loot (cash/jewelry pickups) you pick up. | Plain Sight (aced) |
| `stealth.mark_far_damage_mult` | PARAMS {min_distance: float, mult: float} | Extra damage multiplier on your marked enemies beyond `min_distance` m. | Price Tag (aced) |
| `stealth.mark_by_aim` | FLAG | Aiming at a special for a moment marks it (any weapon). | Price Tag (aced) |

### Deployables

| Proposed key | Type / params | Semantics | Needed by |
|---|---|---|---|
| `deploy.deploy_speed_mult` | MULT (qualified by deployable kind or .all) | Deploy/use time of deployables (lower = faster). | Bedside Manner (basic), Tinker (basic), Two Kits (basic) |
| `deploy.sentry_cost_mult` | MULT | Fraction of your ammo a sentry costs to deploy. | Lean Build (basic), Mount Up (basic) |
| `deploy.sentry_shield` | FLAG | Your sentries have a frontal shield. | Mount Up (aced) |
| `deploy.sentry_accuracy_mult` | MULT | Sentry spread (lower = more accurate). | Calibrated (basic) |
| `deploy.sentry_turn_speed_mult` | MULT | Sentry rotation speed. | Calibrated (aced) |
| `deploy.sentry_health_mult` | MULT | Sentry health. | Lean Build (aced) |
| `deploy.sentry_modes` | PARAMS {quiet: bool, ap: bool, quiet_threat_mult: float, ap_fire_rate_mult: float, ap_damage_mult: float} | Unlocks switchable sentry modes (interact to cycle). | Silent Partner (aced), Silent Partner (basic) |
| `deploy.trip_mine_radius_mult` | MULT | Trip mine blast radius. | Charge Shaping (basic) |
| `deploy.trip_mine_fire` | PARAMS {duration: float, radius: float} | Detonations leave a fire area. | Hot Floor (aced), Hot Floor (basic) |
| `deploy.ammo_bag_bulletstorm` | PARAMS {base_duration: float, max_duration: float} | Users of your ammo bags fire without using ammo for a duration scaled by the ammo taken. | Lead Rain (aced), Lead Rain (basic) |
| `weapon.ammo_pickup_range_mult` | MULT | Ammo box pickup radius. | Scrounger (basic) |
| `weapon.kill_ammo_drop` | PARAMS {every_n_kills: int} | Every n-th kill drops an extra ammo box. | Scrounger (aced) |
| `weapon.ammo_pickup_throwable` | PARAMS {base_chance: float, step: float} | Ammo boxes may contain a throwable; chance grows by `step` per box without one, resets on success. | Pack Mule (aced) |
| `interaction.device_fix_speed_mult` | MULT | Time to fix a jammed drill/saw (lower = faster). | Tinker (basic) |
