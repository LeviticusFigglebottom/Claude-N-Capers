# ENV A fidelity audit (pd2_fidelity.md rows owned by A)

Owner: ENV A. Generated 2026-10-12 by scanning game/tests/a for each row id (a test file or test name that
mentions the id). "test found" means a test references the row; it is NOT a claim that the row is complete.
"no test found" rows need a manual audit. Notes list what changed this session.

| Row | Topic | Phase | Tests (game/tests/a) | Notes |
|-----|-------|-------|----------------------|-------|
| S1.1 | Casing mode (unmasked) | P1 | test_a1_02_crew_controller, test_l2_11_deployables, test_l3_weapons | casing pickup added 2026-10-12 (1101d390) |
| S1.2 | Mask-up is a hold interaction (~1 s) and irreversible | P1 | test_a1_02_crew_controller, test_s1_casing_detection |  |
| S1.3 | Civilian mode (some heists) | P5 | test_s1_3_civilian_mode |  |
| S1.4 | Masked stealth | P1 | test_a1_02_crew_controller, test_s1_casing_detection |  |
| S1.5 | Movement makes no noise | P1 | test_a1_02_crew_controller, test_s1_casing_detection |  |
| S2.1 | Each observer keeps its own meter per player | P1 | test_s2_detection_meter |  |
| S2.2 | Fill rate is faster when the observer is close and you are n | P1 | test_s2_detection_meter |  |
| S2.3 | DR → multiplier table | P1 | test_s2_detection_meter |  |
| S2.5 | ◇ Crouching effect is unknown on the wiki | P1 | test_s2_detection_meter, test_s3_8_cameras |  |
| S2.6 | Camera rate is similar to guards (~2 s) and DR-based; moveme | P1 | no test found |  |
| S2.7 | DR also sets loud targeting range (80 m at DR 3 to 180 m at  | P3 | test_s2_7_dr_target_range | DR range 80-180 m (118c516b) |
| S2.8 | Unmasked players and masked players have different detection | P1 | no test found |  |
| S2.9 | Marking | P2 | test_s2_9_marking |  |
| S3.1 | Civilian fully alerted | P1 | test_a1_06_civilians, test_s3_1_civilian_panic |  |
| S3.2 | Guard spots a player | P1 | test_s3_2_guard_cuffs, test_s3_3_guard_radio |  |
| S3.3 | Guard raises alarm by stopping, drawing and radioing | P1 | test_s3_3_guard_radio |  |
| S3.4 | Guard sees something suspicious (body, bag, broken glass, dr | P1 | test_s3_4_guard_investigate |  |
| S3.5 | Camera fully alerted | P2 | test_s3_8_cameras, test_s8_1_cameras, test_s8_2_camera_operator |  |
| S3.6 | One-shot rule | P1 | test_l3_weapons, test_s3_6_guard_one_shot |  |
| S3.7 | Body-shot kills carry a 10% misfire chance (the guard's gun  | P2 | test_s3_7_misfire |  |
| S3.8 | Civilians and guards see illegal actions (masked player, car | P1 | test_s3_8_cameras |  |
| S4.1 | Guards react to | P1 | test_s10_loot_bags, test_s4_stimuli_noise |  |
| S4.2 | Guards ignore | P1 | no test found |  |
| S4.3 | Noise sources (stealth) | P1 | test_l3_weapons, test_s4_stimuli_noise |  |
| S4.4 | Cameras detect | P2 | test_s3_8_cameras, test_s8_1_cameras |  |
| S5.1 | Guard patrol routes and counts vary per run; guards pause, l | P1 | test_s5_1_patrol_routes |  |
| S5.2 | Pager on killing or dominating a guard (only guards carry pa | P1 | test_s5_pagers |  |
| S5.3 | 4 answers per heist, team-wide | P1 | test_s5_pagers |  |
| S5.4 | Letting go early raises the alarm immediately unless another | P1 | test_s5_pagers |  |
| S5.5 | Pager unanswered past the window → alarm | P1 | test_s5_pagers |  |
| S5.6 | ECM affects pagers only with ECM Specialist aced, which paus | P2 | test_s5_6_ecm_pager_delay |  |
| S5.7 | Some heists spawn a replacement guard after N answers | P2 | no test found |  |
| S5.8 | Guard domination (stealth) | P3 | test_s5_8_guard_domination | D-079 range/cone/tradeable (df3f6584); no HUD cue yet (PP-A-1) |
| S6.1 | Corpses are discovered by guards, civilians and cameras on s | P1 | no test found |  |
| S6.2 | Body bags | P1 | test_s6_2_body_bag_case, test_s6_body_bags |  |
| S6.3 | A bagged body is a heavy bag that must be carried, thrown an | P1 | test_s6_body_bags |  |
| S6.4 | Dominated/cuffed guards and tied civilians are themselves su | P2 | test_s6_4_hostage_stimuli |  |
| S7.1 | Intimidate with a shout | P1 | test_s7_shout_and_ties |  |
| S7.2 | Cable ties | P1 | test_s7_shout_and_ties |  |
| S7.3 | Killing a civilian costs cash (cleaner costs scale with job  | P1 | no test found |  |
| S7.4 | Civilians who see illegal actions become alerted and run to  | P1 | no test found |  |
| S7.5 | Civilians in public areas idle, browse, queue, sit and wande | P1 | test_a1_06_civilians |  |
| S7.6 | Stockholm Syndrome | P3 | no test found |  |
| S8.1 | Cameras see in cones, die to one shot (below Mayhem) | P2 | test_s8_1_cameras, test_s8_2_camera_operator |  |
| S8.2 | Camera operator in the security room (a guard with a pager) | P2 | test_s8_2_camera_operator, test_s8_3_camera_loop |  |
| S8.3 | Camera loop (Nimble basic) | P3 | test_s8_3_camera_loop | camera loop 25 s, one per crew (d0969fc0) |
| S8.4 | ECM | P2 | test_s8_4_ecm |  |
| S8.5 | ECM Overdrive aced opens keycard doors (4 s) | P2 | test_s8_4_ecm |  |
| S8.6 | ECM feedback | P3 | test_a3_08_followups, test_s8_6_ecm_feedback |  |
| S8.7 | Pocket ECM (Hacker deck) | P4 | no test found |  |
| S9.1 | Everything is a hold-to-interact with a timer | P1 | test_s9_10_lasers, test_s9_11_zipline_ladder |  |
| S9.2 | Lockpicking | P1 | no test found |  |
| S9.3 | Drill | P1 | test_s9_devices_glass |  |
| S9.4 | Saws (placed) | P2 | test_s9_4_saws |  |
| S9.5 | Shaped charges | P3 | test_s9_5_door_charges, test_s9_8_safes | safes a952cc04, doors ecfc2a9a; trip-mine placement runtime still missing |
| S9.6 | Keycards (random location per run) open keycard doors | P1 | test_s9_devices_glass |  |
| S9.7 | Codes/keypads | P2 | test_s9_7_keypads_codes |  |
| S9.8 | Safes (small/medium/vault), opened by drill/saw/C4/lockpick  | P2 | test_s9_8_safes |  |
| S9.9 | Glass breaks loudly (stimulus); display cases | P1 | test_s9_devices_glass |  |
| S9.10 | Laser grids trip the alarm on touch, even in civilian mode | P2 | test_s9_10_lasers |  |
| S9.11 | Windows, ladders, ziplines, vents | P1 | test_s9_11_zipline_ladder, test_s9_devices_glass |  |
| S10.1 | Bags | P1 | test_s10_1b_ladder_bag, test_s10_loot_bags |  |
| S10.2 | Bags are secured at an escape zone/van/zipline/heli | P1 | test_s10_loot_bags |  |
| S10.3 | Small loot (cash bundles, jewelry on counters) is picked up  | P1 | no test found |  |
| S10.5 | Loot bags dropped by custody players stay where they were | P3 | no test found |  |
| S11.2 | Seamless transition | P1 | test_a1_05_security_officer, test_a1_06_civilians, test_s2_detection_meter |  |
| S11.3 | Stealth-only heists | P2 | test_s11_3_stealth_only |  |
| L1.1 | Phases | P1 | test_l1_assault_director |  |
| L1.2 | Drama | P3 | test_l1_2_drama |  |
| L1.3 | Escalation | P3 | test_l1_3_escalation |  |
| L1.4 | Spawn groups and spawn points | P1 | test_l1_assault_director |  |
| L1.5 | Factions by difficulty | P3 | test_l1_5_factions |  |
| L1.6 | No custody negotiation during an assault (but a highlighted  | P3 | no test found |  |
| L2.1 | Health does not regenerate (except via skills/perks) | P1 | test_l2_10_trade, test_l2_11_deployables, test_l2_12_police_cuffs | regen key consumer (7154507b) |
| L2.2 | Armor absorbs first | P1 | test_l2_survival |  |
| L2.4 | Dodge | P2 | test_l2_4_dodge | melee dodge (d5054a2c) |
| L2.5 | Bleedout | P1 | test_a1_08_npc_gunner, test_l2_survival |  |
| L2.6 | Downs | P1 | test_l2_survival |  |
| L2.7 | Revive | P1 | test_l2_survival |  |
| L2.8 | Taser and Cloaker takedowns don't use bleedout or count as d | P3 | test_l2_8_incapacitate |  |
| L2.9 | Custody | P3 | test_l2_9_custody |  |
| L2.10 | Hostage trade | P3 | test_l2_10_trade |  |
| L2.11 | Doctor Bag 2 uses (full heal + reset downs) | P2 | test_l2_11_deployables |  |
| L2.12 | Cuffs (guards in stealth, P2) and cuffing by police in loud  | P3 | test_l2_12_police_cuffs |  |
| L3.3 | Headshots | P1 | test_l3_3_pellet_headshot | server head-zone check (b33e4bdc) |
| L3.4 | Armor piercing | P3 | test_l3_4_piercing |  |
| L3.5 | Suppression ("threat") | P3 | test_l3_5_suppression |  |
| L3.6 | Explosives | P3 | test_l3_6_explosives |  |
| L3.7 | Suppressors | P1 | no test found |  |
| L3.8 | Hit registration (PD2 | P1 | test_l3_weapons |  |
| L3.9 | Melee | P2 | test_l3_9_melee |  |
| L4.1 | Guard (stealth) | P1 | test_l4_11_special_caps |  |
| L4.2 | Beat cops / SWAT / heavy SWAT | P1 | test_l4_2_tac_heavy |  |
| L4.3 | Cloaker | P3 | test_l4_3_phantom |  |
| L4.4 | Taser | P3 | test_l4_4_stinger |  |
| L4.5 | Shield | P3 | test_l4_5_bulwark |  |
| L4.6 | Bulldozer | P3 | test_l4_6_wrecker |  |
| L4.7 | Sniper | P3 | test_l4_7_longshot |  |
| L4.8 | Medic | P3 | test_l4_8_corpsman |  |
| L4.9 | Captain Winters + Phalanx | P3 | test_l4_9_brandt |  |
| L4.10 | Gangsters (no pagers, can't be dominated) on some heists | P3 | no test found |  |
| L4.11 | Spawn caps by difficulty (Overkill | P3 | test_l4_11_special_caps |  |
| L5.1 | Shout makes low-tier cops surrender (chance-based, better wh | P3 | test_l5_1_surrender |  |
| L5.2 | Joker | P3 | test_l5_2_converts |  |
| L5.3 | Hostages (civilians/cops) delay the assault (+30 s once) and | P3 | no test found |  |
| L6.1 | Bots fill empty slots | P1 | test_l6_ai_teammates |  |
| L6.2 | Bots have their own loadout and abilities (later | P4 | no test found |  |
| L6.3 | Bots can trade hostages? (no) Bots get custody and are trade | P3 | no test found |  |

Summary: 108 A rows; 90 with a referencing test, 18 with none found.

## Modifier keys without a consumer in game/systems or game/content (scan 2026-10-12)
Phase 2: interaction.device_melee_restart, ability.inspire (weapon.ads_speed_mult is ENV P).
Phase 3: stealth.mark_damage_bonus_mult, stealth.pocket_ecm, defense.self_revive_charges, defense.swan_song,
defense.berserk, defense.bullseye, weapon.crit_chance_add, ability.hostage_regen, ability.stockholm
(movement.shoot/reload_while_sprinting are ENV P).
Phase 4 (47 keys; exact-string scan, keys built from a prefix + qualifier may be false positives): defense.reviving_damage_taken_mult, ability.revive_target_health_mult, ability.revive_target_buff, deploy.medical_user_buff, deploy.fak_auto_revive, defense.bleedout_health_mult, defense.post_revive_buff, defense.bleedout_pause_unseen, defense.self_revive_refill_on_doctor_bag, ability.convert_owner_buff, stealth.noise_intimidates_civilians, weapon.still_spread_mult, weapon.moving_spread_mult, weapon.hip_spread_mult, weapon.fire_rate_mult, weapon.hip_fire_rate_mult, weapon.falloff_range_mult, movement.ads_speed_penalty_mult, weapon.kill_damage_buff, weapon.hit_stack_buff, weapon.headshot_refund, weapon.graze, weapon.body_expertise, weapon.stagger_chance_add, weapon.unseen_strike, weapon.crit_per_concealment, defense.outnumbered, defense.flashbang_duration_mult, defense.interact_damage_taken_mult, defense.armor_break_speed_buff, defense.target_priority_mult, defense.armor_broken_stagger, defense.dodge_per_concealment, defense.sprint_dodge_add, movement.sprint_any_direction, loot.small_loot_value_mult, stealth.mark_far_damage_mult, stealth.mark_by_aim, deploy.sentry_cost_mult, deploy.sentry_shield, deploy.sentry_accuracy_mult, deploy.sentry_turn_speed_mult, deploy.sentry_health_mult, deploy.sentry_modes, deploy.trip_mine_radius_mult, deploy.trip_mine_fire, deploy.ammo_bag_bulletstorm.
Done this session:
interaction.speed_mult (P2), interaction.device_fix_speed_mult, defense.healing_received_mult.
