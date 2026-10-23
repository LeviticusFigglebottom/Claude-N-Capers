# ENV A fidelity audit (pd2_fidelity.md rows owned by A, phase <= P5)

Owner: ENV A. A4-01 audit, regenerated 2026-10-22 on env/a-core (trunk cb4b72dd merged). The scan
(scratchpad scan.py) lists every docs/design/pd2_fidelity.md row whose owner column starts with A and whose
phase is P1-P5, then finds the test files in game/tests/a that cite the row id (in a file name or in code /
comments). Rows the scan could not place were audited by hand (Status + evidence below).

**Result: 103 rows. 101 covered, 1 held (S8.7 Pocket ECM, LEAD r280), 1 partial gap (L6.2 bot skill set).**
- Fixed inline by this audit: S10.5 had no test; added test_s10_loot_bags test_s10_5_custody_drop_stays
  (behaviour was already correct).
- L6.2 gap (reported to the LEAD, not built): bots do have their own loadouts, but the "small AI skill set"
  (inspire-light, ammo / health boosts) does not exist.
- "covered" means tests exercise the row; it is not a claim that every number matches PD2 (◇ rows stay the
  LEAD's tuning calls).

## Roadmap A3-01 .. A3-13 (not marked done in roadmap.md): all delivered, all green today
| Item | Tests run 2026-10-22 | Result |
|------|----------------------|--------|
| A3-01 specials | test_l4_3 .. test_l4_8 | 46/46 |
| A3-02 Brandt + Aegis | test_l4_9_brandt | 11/11 |
| A3-03 director escalation | test_l1_* (drama, escalation, factions, director), test_l4_11 | 26/26 |
| A3-04 custody / trade / cuffs / surrender / converts | test_l2_8, l2_9, l2_10, l2_12, test_l5_* | 38/38 |
| A3-05 AI orders | test_a3_05_ai_orders, test_l6* | 31/31 |
| A3-06 suppression / piercing / explosives / plates | test_l3_4, l3_5, l3_6, test_l4_2 | 20/20 |
| A3-07 co-op hardening | test_a3_07_coop_loopback | 1/1 |
| A3-08 follow-ups | test_a3_08_followups | 10/10 |
| A3-09 Night Deposit systems | test_a3_09_* | 27/27 |
| A3-10 Shadow Ledger needs | test_a3_10_* | 10/10 |
| A3-11 hub support | test_a3_11_hub | 3/3 |
| A3-12 melee + throwables | test_l3_9_melee, test_a3_12_throwables | 10/10 |
| A3-13 enemy melee | test_a3_13_npc_melee | 4/4 |

## Rows
| Row | Topic | Phase | Status | Tests / evidence |
|-----|-------|-------|--------|------------------|
| S1.1 | Casing mode (unmasked): civilians can never detect you. Guards and cam | P1 | covered | test_a1_02_crew_controller, test_a3_10_ladder_nav_layer, test_a3_12_throwables, test_b5_01_options_hooks, test_crew_ai_formation, test_gn_mission +12 |
| S1.2 | Mask-up is a hold interaction (~1 s) and irreversible. Being detected  | P1 | covered | test_a1_01_heist_runtime, test_a1_02_crew_controller, test_po11_casing_civilians, test_s1_3_civilian_mode, test_s1_casing_detection, test_s3_1_civilian_panic +1 |
| S1.3 | Civilian mode (some heists): no gear, undetectable, laser grids still  | P5 | covered | test_a3_11_hub, test_s1_3_civilian_mode |
| S1.4 | Masked stealth: everything is allowed and everyone can detect you. | P1 | covered | test_s1_casing_detection |
| S1.5 | Movement makes no noise. Footsteps, sprinting and jumping next to a gu | P1 | covered | test_a1_02_crew_controller, test_s1_casing_detection |
| S2.1 | Each observer keeps its own meter per player. It fills only with line  | P1 | covered | test_d118_gadget_detection, test_s2_detection_meter |
| S2.2 | Fill rate is faster when the observer is close and you are near the ce | P1 | covered | test_s2_detection_meter |
| S2.3 | DR → multiplier table: DR3 ×1.55 … DR35 ×1.0 … DR75 ×0.3. | P1 | covered | test_s2_detection_meter |
| S2.5 | Crouching swaps the attention setting (shorter detection range; civili | P1 | covered | test_d128_detection_pd2, test_s2_detection_meter, test_s3_8_cameras |
| S2.6 | Camera rate is DR-based; movement speed is irrelevant. PD2 cameras are | P1 | covered | test_d128_detection_pd2 (camera fill times, D-130 x0.8), test_s3_8_cameras |
| S2.7 | DR also sets loud targeting range (80 m at DR 3 to 180 m at DR 75). | P3 | covered | test_s2_7_dr_target_range |
| S2.8 | Unmasked players and masked players have different detection rules. | P1 | covered | test_s1_casing_detection |
| S2.9 | Marking: shout or mark key highlights a guard, camera or special for t | P2 | covered | test_s2_9_marking |
| S3.1 | Civilian fully alerted: panics and flees, then calls police, hits a pa | P1 | covered | test_a1_06_civilians, test_of_a6_bank_ambient, test_po6_civilian_reacts_to_kill, test_s3_1_civilian_panic |
| S3.3 | Guard raises alarm by stopping, drawing and radioing. Killing him befo | P1 | covered | test_gn8_vaultline_courier, test_gn_inspectors_empty_slot, test_s3_3_guard_radio, test_s3_4_guard_investigate |
| S3.4 | Guard sees something suspicious (body, bag, broken glass, drill…): "?" | P1 | covered | test_s3_4_guard_investigate |
| S3.5 | Camera fully alerted: "!" plus a tone. The alarm sounds 7 s later and  | P2 | covered | test_po6_04_gh_stealth_safe, test_s3_8_cameras, test_s8_1_cameras, test_s8_2_camera_operator, test_s8_4_ecm |
| S3.6 | One-shot rule: an unalerted guard dies to any hit. | P1 | covered | test_d113_blood_fx, test_d123_limb_hitboxes, test_l3_3_pellet_headshot, test_l3_weapons, test_po6_19_ragdoll, test_s3_6_guard_one_shot |
| S3.7 | Body-shot kills carry a 10% misfire chance (the guard's gun fires and  | P2 | covered | test_s3_7_misfire |
| S3.8 | Civilians and guards see illegal actions (masked player, carrying bag, | P1 | covered | test_s1_casing_detection, test_s3_8_cameras |
| S4.2 | Guards ignore: most opened doors and crates, open vaults, missing item | P1 | covered | test_a2_01_doors_nav, test_d118_gadget_detection, test_s3_4_guard_investigate |
| S4.3 | Noise sources (stealth): unsuppressed shots, explosions, drills (25 m, | P1 | covered | test_l3_9_melee, test_l3_weapons, test_s4_stimuli_noise |
| S4.4 | Cameras detect: players, bags (19 m body bags / 18 m other), corpses,  | P2 | covered | test_po6_04_gh_stealth_safe, test_s3_8_cameras, test_s8_1_cameras |
| S5.1 | Guard patrol routes and counts vary per run; guards pause, look around | P1 | covered | test_s5_1_patrol_routes |
| S5.2 | Pager on killing or dominating a guard (only guards carry pagers; poli | P1 | covered | test_po6_08_pager_freeze, test_s5_8_guard_domination, test_s5_pagers |
| S5.3 | 4 answers per heist, team-wide. The 5th answer raises the alarm *when  | P1 | covered | test_s5_pagers |
| S5.4 | Letting go early raises the alarm immediately unless another player is | P1 | covered | test_p1_sandbox_gate, test_po6_08_pager_freeze, test_s5_pagers |
| S5.5 | Pager unanswered past the window → alarm. | P1 | covered | test_s5_pagers |
| S5.6 | ECM affects pagers only with ECM Specialist aced, which pauses the res | P2 | covered | test_s5_6_ecm_pager_delay |
| S5.7 | Some heists spawn a replacement guard after N answers. | P2 | covered (hook) | HeistMission._on_pager_answered: GH/ND/SL/GN/OF react (last-pager VO; test_d117_mission_vo); no heist spawns a replacement guard (the contract says 'may') |
| S5.8 | Guard domination (stealth): one shout in the ~1.5 s window after a gua | P3 | covered | test_pp_a2_real_domination, test_s5_8_guard_domination |
| S6.1 | Corpses are discovered by guards, civilians and cameras on sight (→ al | P1 | covered | guards: test_s3_4 (corpse stimulus alarms); cameras: test_s3_8 (S4.4 cameras see corpses); civilians: test_po6_civilian_reacts_to_kill |
| S6.2 | Body bags: 1 per player base, inventory cap 2. Cleaner gives +1 and ca | P1 | covered | test_a1_02_crew_controller, test_s6_2_body_bag_case, test_s6_body_bags |
| S6.3 | A bagged body is a heavy bag that must be carried, thrown and hidden o | P1 | covered | test_s10_loot_bags, test_s4_stimuli_noise, test_s6_body_bags |
| S6.4 | Dominated/cuffed guards and tied civilians are themselves suspicious i | P2 | covered | test_s6_4_hostage_stimuli, test_s7_shout_and_ties |
| S7.1 | Intimidate with a shout: they get down. They get back up after a while | P1 | covered | test_po5_shout_walls_floors, test_s2_9_marking, test_s7_shout_and_ties |
| S7.2 | Cable ties: 2 base, 6 with Forced Friendship. Tying takes 2 s (0.5 s w | P1 | covered | test_a1_02_crew_controller, test_s7_shout_and_ties |
| S7.4 | Civilians who see illegal actions become alerted and run to call. | P1 | covered | test_po6_06_civilians_spawn_standing, test_s3_1_civilian_panic |
| S7.5 | Civilians in public areas idle, browse, queue, sit and wander. | P1 | covered | test_a1_06_civilians, test_po5_civilian_wander_areas, test_po6_06_civilians_spawn_standing |
| S7.6 | Stockholm Syndrome: your noise intimidates; hostages may revive you. | P3 | covered | A4-04 B6: ability.stockholm + stealth.noise_intimidates_civilians, test_skills_b56 |
| S8.1 | Cameras see in cones, die to one shot (below Mayhem). The operator may | P2 | covered | test_s8_1_cameras, test_s8_2_camera_operator |
| S8.2 | Camera operator in the security room (a guard with a pager). Killing o | P2 | covered | test_s8_2_camera_operator |
| S8.3 | Camera loop (Nimble basic): 25 s, one at a time per crew. | P3 | covered | test_s8_3_camera_loop |
| S8.4 | ECM: 2 s deploy, 20 s jam (flashing for the last 8 s). Jams all camera | P2 | covered | test_s8_4_ecm |
| S8.5 | ECM Overdrive aced opens keycard doors (4 s). ATMs open in 8 s (consum | P2 | covered | test_s8_4_ecm (the ATM half added in r291: test_s8_5_ecm_on_atm_spot_opens_it; ND ATM spots flagged) |
| S8.6 | ECM feedback: interact with a placed ECM to stun enemies in range (Clo | P3 | covered | test_s8_6_ecm_feedback |
| S8.7 | Pocket ECM (Hacker deck): 6 s, 2 charges, 100 s recharge (−6 s per kil | P4 | held | stealth.pocket_ecm: Hacker deck held to P5+ (LEAD r280); no grant exists |
| S9.1 | Everything is a hold-to-interact with a timer. Releasing cancels. Some | P1 | covered | test_d134_revive_under_fire, test_l2_survival, test_s9_10_lasers, test_s9_11_zipline_ladder |
| S9.2 | Lockpicking: most doors, ~10 s (◇). Nimble aced: 100% faster and can p | P1 | covered | test_nd_teller_door_lockpick (door lockpick x interaction.lockpick_speed_mult), test_s9_8_safes (can_lockpick_safes) |
| S9.3 | Drill: 3 s to place. 180 s on a security door, 60 s on a cage, 360 s t | P1 | covered | test_po6_02_jam_schedule, test_s9_devices_glass |
| S9.4 | Saws (placed): same as drills, same skills. | P2 | covered | test_d115_db8_padlock_saw, test_s9_4_saws |
| S9.5 | Shaped charges: 3 base (trip-mine deployable), 6 max. Loud. N per door | P3 | covered | test_s9_5_door_charges, test_s9_5_trip_mine, test_s9_8_safes |
| S9.6 | Keycards (random location per run) open keycard doors. | P1 | covered | test_s9_devices_glass |
| S9.7 | Codes/keypads: the code is found on a note, computer or person (random | P2 | covered | test_s9_7_keypads_codes |
| S9.8 | Safes (small/medium/vault), opened by drill/saw/C4/lockpick (skill)/co | P2 | covered | test_s9_8_safes |
| S9.9 | Glass breaks loudly (stimulus); display cases. | P1 | covered | test_s9_devices_glass |
| S9.10 | Laser grids trip the alarm on touch, even in civilian mode. ECM doesn' | P2 | covered | test_s9_10_lasers |
| S10.1 | Bags: carry one at a time. Heavier bags slow you more and limit sprint | P1 | covered | test_a3_10_ladder_nav_layer, test_po6_14_bot_catch_bag, test_s10_1b_ladder_bag, test_s10_loot_bags |
| S10.1b | Ladders can't be climbed while carrying a bag (PD2): bags are thrown u | P2 | covered | test_a3_10_ladder_nav_layer, test_po6_14_bot_catch_bag, test_s10_1b_ladder_bag |
| S10.2 | Bags are secured at an escape zone/van/zipline/heli. Throwing a bag in | P1 | covered | test_p1_sandbox_gate, test_s10_loot_bags |
| S10.3 | Small loot (cash bundles, jewelry on counters) is picked up instantly  | P1 | covered | test_s9_devices_glass |
| S10.5 | Loot bags dropped by custody players stay where they were. | P3 | covered | test_s10_loot_bags test_s10_5_custody_drop_stays (added by this audit) |
| S11.2 | Seamless transition: when the alarm sounds the heist becomes loud with | P1 | covered | test_a1_01_heist_runtime, test_a1_05_security_officer, test_a1_06_civilians, test_l1_assault_director, test_s2_detection_meter, test_s3_3_guard_radio |
| S11.3 | Stealth-only heists: an alarm = fail (or a scripted "loud failure"). L | P2 | covered | test_po6_06_civilians_spawn_standing, test_s11_3_stealth_only, test_sl6_loud |
| L1.2 | Drama: the director tracks pressure (damage to players) and adapts spa | P3 | covered | test_l1_2_drama |
| L1.3 | Escalation: later waves → later stages, more units, specials; specials | P3 | covered | test_l1_3_escalation, test_po5_director_caps |
| L1.4 | Spawn groups and spawn points: police enter from map edges, entry poin | P1 | covered | test_l1_assault_director, test_of_a5_roof_rappel, test_po6_16_assault_push, test_po6_16_gh_office_push, test_po6_16_gh_office_sustain, test_qc42_breach_only |
| L1.5 | Factions by difficulty: beat cops → SWAT → FBI → GenSec → ZEAL. | P3 | covered | test_l1_5_factions |
| L1.6 | No custody negotiation during an assault (but a highlighted hostage ca | P3 | covered | test_l2_10_trade |
| L2.1 | Health does not regenerate (except via skills/perks). ◇ base 230 displ | P1 | covered | test_d145_bot_regen, test_l2_10_trade, test_l2_11_deployables, test_l2_12_police_cuffs, test_l2_survival |
| L2.2 | Armor absorbs first. Armor-gating: any normal enemy hit is capped at r | P1 | covered | test_l2_survival |
| L2.4 | Dodge: chance a ranged hit does nothing. Additive; a negative total me | P2 | covered | test_l2_4_dodge |
| L2.5 | Bleedout: 30 s. Can shoot, throw and toss bags; can't move or deploy.  | P1 | covered | test_a1_08_npc_gunner, test_d126_shotgun_secondary, test_l2_survival |
| L2.6 | Downs: 3. The 4th "zero health" goes straight to custody. Reset only b | P1 | covered | test_l2_survival |
| L2.7 | Revive: 6 s hold. After revive, health is 40% of base on Brutal and be | P1 | covered | test_l2_survival |
| L2.8 | Taser and Cloaker takedowns. PD2: a Cloaker kick puts the victim into  | P3 | covered | test_l2_8_incapacitate, test_l6_ai_teammates |
| L2.9 | Custody: auto-release 119 s on Normal/Hard, otherwise trade-only. Rele | P3 | covered | test_l2_10_trade, test_l2_9_custody |
| L2.10 | Hostage trade: negotiation of 5 s + 30 s per civilian killed by that p | P3 | covered | test_l2_10_trade |
| L2.11 | Doctor Bag 2 uses (full heal + reset downs). First Aid Kit 4 (1 s depl | P2 | covered | test_l2_11_deployables |
| L2.12 | Cuffs (guards in stealth, P2) and cuffing by police in loud on downed  | P3 | covered | test_l2_12_police_cuffs, test_l6_ai_teammates, test_v121_crew_states |
| L3.3 | Headshots: multiplier per enemy per difficulty; it shrinks on the top  | P1 | covered | test_l3_3_pellet_headshot |
| L3.4 | Armor piercing: snipers, AP slugs and AP pistols pierce body armor, sh | P3 | covered | test_b4_18_special_weapons, test_l3_4_piercing, test_qc38_burn_point |
| L3.5 | Suppression ("threat"): damage and near-misses build it. Threshold 1:  | P3 | covered | test_l3_4_piercing, test_l3_5_suppression |
| L3.6 | Explosives: damage × (1 − d/r)^0.1. | P3 | covered | test_a3_12_throwables, test_b4_18_special_weapons, test_l3_6_explosives |
| L3.7 | Suppressors: noise radius ~0 m. | P1 | covered | test_l3_weapons |
| L3.8 | Hit registration (PD2: client-side for players). | P1 | covered | test_l3_weapons |
| L3.9 | Melee: charge, knockdown, silent; concealment matters; melee kills in  | P2 | covered | test_l3_9_melee |
| L3.10 | Shotgun ammo (PD2: AP slug, HE, flechette, dragon's breath). Listed da | P4 | covered | test_d118_shotgun_ammo (slug, HE, flechette, dragon's breath) |
| L4.1 | Guard (stealth): pager, patrol, radio, cuffs, one-shot when unalerted. | P1 | covered | test_a1_05_security_officer, test_l4_11_special_caps |
| L4.3 | Cloaker: Very Hard+, cap 2. Electrical hum/"phone ring" while near. Wh | P3 | covered | test_l4_3_phantom |
| L4.4 | Taser: ~1 s audible windup. Tase loop: victim can't move/interact, con | P3 | covered | test_l4_4_stinger, test_l6_ai_teammates |
| L4.5 | Shield: frontal ballistic shield blocks all but explosives/fire/AP (AP | P3 | covered | test_d116_anim_clips, test_l4_5_bulwark |
| L4.6 | Bulldozer: headshot-immune until faceplate (150 HP) then visor (160 HP | P3 | covered | test_l4_6_wrecker |
| L4.7 | Sniper: rooftop/perch. Red laser visible, loud report. 100–240 dmg by  | P3 | covered | test_l4_7_longshot |
| L4.8 | Medic: heals or revives one ally within 7 m, even through walls (green | P3 | covered | test_l4_8_corpsman |
| L4.9 | Captain Winters + Phalanx: once per heist day, VH+, arrives during an  | P3 | covered | test_l4_9_brandt, test_of_mission_loud |
| L4.10 | Gangsters (no pagers, can't be dominated) on some heists. | P3 | covered | test_qc36_cartel |
| L4.11 | Spawn caps by difficulty (Overkill: Shields 4, Tasers 2, Medics 3, Clo | P3 | covered | test_l4_11_special_caps |
| L5.1 | Shout makes low-tier cops surrender (chance-based, better when hurt or | P3 | covered | test_l5_1_surrender |
| L5.2 | Joker: convert a surrendered cop to an ally (1, or 2 with skill). | P3 | covered | test_l5_2_converts |
| L5.3 | Hostages (civilians/cops) delay the assault (+30 s once) and enable tr | P3 | covered | test_l5_1_surrender |
| L6.2 | Bots have their own loadout and abilities (later: bot skills/boosts). | P4 | GAP (part) | bots carry their own loadouts (B's CrewLoadouts, tests/b/test_crew_loadouts; A: bot gear, D-073 heisters); the 'small AI skill set' (inspire-light, ammo / health boosts) does not exist: reported to the LEAD |
| L6.3 | Bots can trade hostages? (no) Bots get custody and are traded like pla | P3 | covered | test_l2_10_trade |
