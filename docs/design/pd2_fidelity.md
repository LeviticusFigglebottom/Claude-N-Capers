# Payday 2 fidelity contract

Owner: **LEAD**. These design targets are non-negotiable. Each row gives:
**(a) how PD2 does it**, **(b) how we replicate it** (our numbers become the defaults in tweak data),
and **(c) the owning environment**.

Source of PD2 facts: `docs/research/pd2_research.md` (wiki-sourced, with citations). Rows marked
**◇** were UNVERIFIED in research. For those, our number is a deliberate design choice that the lead
tunes in playtests.

**Units.** Health, armor and damage use **PD2 display units** (player base health 230, suit armor 20,
and so on) so reference numbers transfer 1:1. Distances are in m and times in s. All numbers live in
tweak resources, never in code (ENV A: `game/systems/tweak/*.tres`; ENV B: `game/content/data/**`).

Phase column: the roadmap phase that must deliver the row (P1 = vertical slice).

---

## S. Stealth

### S1. Modes: casing, masked, civilian

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S1.1 | **Casing mode** (unmasked): civilians can never detect you. Guards and cameras detect you only slowly (elevated resistance), and only when you trespass in restricted areas or linger close. You cannot crouch, jump, sprint, fight, use interaction-wheel actions, carry bags, climb ladders or deploy. You *can* shout or mark and mask up. **An unmasked shout only marks (`stealth.casing_can_mark`); it never intimidates or panics civilians (PO-11).** | Identical. `CasingState` on crew: movement limited to walk. While unmasked, observers fill only if the player is inside a `MapZone.RESTRICTED`, or within 3 m of a guard (◇ "too close") while **outside** PUBLIC zones (D-025). The fill rate is ×0.35 of the masked rate (◇). Civilians never fill. Interactions flagged `casing_allowed` (keycard pickup, small cash with `stealth.casing_can_pickup_items`, mask up) are the only ones available. A HUD prompt reads "Suspicious actions not allowed". | A (B HUD) | P1 |
| S1.2 | Mask-up is a hold interaction (~1 s) and **irreversible**. Being detected or entering combat force-masks that player. Any alarm masks everyone. Masking near observers gives a short slow-motion moment. | Identical. Mask-up takes a 1.0 s hold. Forced masking happens on detection, combat or alarm. Masking within view of an NPC plays a 0.6 s time-scale 0.4 effect, **local presentation only** (never changes server time). The mask model (ENV B mask system) appears on the crew model and in first person. | A (B mask art) | P1 |
| S1.3 | **Civilian mode** (some heists): no gear, undetectable, laser grids still trip. Picking up gear moves you to casing. | Supported as a heist flag `start_mode = civilian`. A gear-pickup prefab switches the player to casing mode. Used on `afterhours`. | A | P5 |
| S1.4 | **Masked stealth**: everything is allowed and everyone can detect you. | Identical. | A | P1 |
| S1.5 | **Movement makes no noise.** Footsteps, sprinting and jumping next to a guard are fine. Only line of sight, interaction noise and specific events count. | **Hard rule.** The player has no noise emitter for movement. Noise sources are limited to the list in S4.3. A unit test asserts that sprinting and jumping behind a guard at 1 m does not raise detection. | A | P1 |

### S2. Detection meter

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S2.1 | Each observer keeps its **own meter per player**. It fills only with line of sight (LOS); the HUD shows it offset by DR (DR 3 starts at 3%). "?" while filling, "!" at 100% with a loud cue. | **D-128, PD2 source.** A per-(observer, crew member) progress from 0 to 1; HUD shows `p·(1−DR/100)+DR/100` (playertweakdata SUSPICION_OFFSET_LERP). Without LOS it drains at **0.125/s** for NPCs (coplogicbase) and **1/3 per s** for cameras (securitycamera); below 0 the attention drops. HUD (ui_hud v1.17): a ring over each observer filling clockwise with "?" inside, red "!" at 1.0, plus one crosshair arc per observer; white → orange (≥ 0.5) → red. Rows carry `state` (curious / investigating) so a guard checking a noise shows "?" at 0. Rings hide while LOUD. Replicated at 10 Hz to the observed client only. | A (B HUD) | P1 |
| S2.2 | **Fill rate** is faster when the observer is close and you are near the centre of their view; slower at range or at the edge of view. | **D-128, PD2 source** (github steam-test1/Payday-2-LuaJIT-Complete, lib/…).<br>• Range: `max_dis = min(dis_max, max_range) × range_mul`; noticeable while `dis/max_dis < 1` (coplogicbase `_angle_and_dis_chk`).<br>• NPC cone: `angle_max_eff = lerp(180°, angle_max, clamp((dis−1.5)/7))`, all-round within 1.5 m, ±60° from 8.5 m (horizontal sector, ◇ stricter than PD2's 3D head angle).<br>• NPC per tick: `delay = lerp(min_delay × notice_mul × delay_mul, max_delay, 0.75·dis/max_dis + 0.25·min(angle/angle_max, 1))`; `progress += dt/delay`.<br>• Camera per tick: same lerp with weights 0.85 / 0.15, angle over the full fov.<br>• Presets: guard = police = gangster {40 m, ±60°, delay 0.2/2.0} (charactertweakdata detection.normal.ntl); civilian {20 m, ±60°, 0.2/3.0}; camera {15 m, 60° cone, **1.6/2.4**} (= PD2 editor default {2, 3} × 0.8, **D-130 ◇**; per-camera overrides kept; GH/ND/SL/GN cameras keep their authored 20 m).<br>• Player attention (attentiontweakdata whisper mode): masked vs combatants stand {max_range 20 m, notice ×2, uncover 2 m}, crouch {12 m, ×2, 2 m}; vs civilians stand {no cap, ×1.5, uncover 5.5 m}, crouch {15 m, ×3, 2 m}.<br>• **Uncover:** instant detection when `dis < uncover` and angle < 55° (NPCs only; masked crew only).<br>• Example fill times, masked standing, DR 35, centre/edge: guard 1 m 0/0.85 s, 10 m 1.00/1.39 s, 20 m never; camera 1 m 3.94 s, 10 m 3.43 s. Pinned in test_d128_detection_pd2. | A | P1 |
| S2.3 | **DR → multiplier** table: DR3 ×1.55 … DR35 ×1.0 … DR75 ×0.3. | PD2: `con_mul = stats.concealment[index]`; `set_detection_multiplier(1/con_mul)` gives `delay_mul = con_mul` (scales delay_min only) and `range_mul = sqrt(1/con_mul)` (playerbase). Our DR table is PD2's exactly. | A (B computes DR) | P1 |
| S2.4 | **Concealment → DR**: total concealment = primary + secondary + melee + armor + bonuses (each weapon caps at 30). 119+ gives DR 3; 91 or less gives DR 75. The curve is steep below 100. | PD2 breakpoints copied into `content/data/tweak/concealment_curve.tres`. ENV B's `LoadoutResolver` produces `Loadout.detection_risk`. | B | P1 |
| S2.5 | Crouching swaps the attention setting (shorter detection range; civilians notice slower but uncover closer). | **D-128:** no rate multiplier (the old ×0.75 is dropped). Crouch uses PD2's `*_crouch` attention settings above, cameras included. Sprinting and movement have no term; `difficulty.detection_speed_mult` stays 1.0. | A | P1 |
| S2.6 | Camera rate is DR-based; movement speed is irrelevant. PD2 cameras are slow up close (about 4 s at DR 35). | Camera preset and per-tick weights as in S2.2. D-130: camera delays ×0.8 (◇, PO: cameras a little faster); fill times in test_d128 scale ×0.8. Titan (indestructible) from LETHAL, or from the heist's `camera_titan_min_difficulty` (GH: HAZARDOUS). Prefab default range 15 m (PD2 editor default). No uncover. | A | P1 |
| S2.7 | DR also sets loud targeting range (80 m at DR 3 to 180 m at DR 75). | `ai_target_range = lerp(80, 180, (DR − 3)/72)`. | A | P3 |
| S2.8 | Unmasked players and masked players have different detection rules. | See S1.1. A masked player in a public area is still detected by everyone. | A | P1 |
| S2.9 | Marking: shout or mark key highlights a guard, camera or special for the team for a few seconds. Sixth Sense passively marks when you stand still in stealth. | Mark via the `shout` intent while aiming at a markable target: outline for the whole crew, 4.5 s (guards) or 8 s (cameras) (◇). `stealth.sixth_sense`: standing still 3.5 s marks enemies within 10 m. | A (B outline shader → C) | P2 |

### S3. Detection outcomes

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S3.1 | **Civilian fully alerted**: panics and flees, then calls police, hits a panic button or alerts guards. Leaving the map raises the alarm. An alerted civilian can't be pacified unless you shout them down before they reach a phone. | Civilian goes `PANICKED`. They choose the nearest of `phone` / `alarm_button` / exit / nearest guard (nav cost). Reaching it starts a 3 s call (◇). Finishing the call raises the alarm (`reason = &"civilian_call"`). Shouting interrupts the call and makes them `INTIMIDATED`. **Fidelity note:** PD2 calls panicked civilians unpacifiable, but players routinely shout fleeing civilians down, so we allow intimidation while fleeing at a 50% success roll (◇). Lead may revisit. | A | P1 |
| S3.2 | **Guard spots a player**: yells, pauses ~5 s, walks over and tries to cuff. Moving > 1.7 m or shooting makes him open fire. Cuffed means the alarm follows soon. Cuff cooldown is 4 min per player; escaping takes 60 s. | Same flow and numbers, **from P2**. P1 simplification: a guard reaching "!" raises the alarm after a 2.0 s radio call; killing him during the call cancels it (S3.3). | A | P1 (simple) / P2 (cuffs) |
| S3.3 | **Guard raises alarm** by stopping, drawing and radioing. **Killing him before the call finishes prevents the alarm.** | Radio call takes 2.0 s (◇; PD2 ~2 s). It is interruptible by death, domination or ECM feedback stun. | A | P1 |
| S3.4 | **Guard sees something suspicious** (body, bag, broken glass, drill…): "?" then investigates, then calls it in if confirmed. | Stimulus → `CURIOUS` (meter fills toward the stimulus) → `INVESTIGATING` (walks to it, 20 s search budget ◇) → `ALARMED` → radio (S3.3). Each stimulus type has its own preset in `stealth_tweak.tres`. | A | P1 |
| S3.5 | **Camera fully alerted**: "!" plus a tone. The **alarm sounds 7 s later and cannot be stopped**, even by destroying the camera, killing the operator or using ECM. | Identical: 7.0 s unstoppable countdown. Cue `cue.camera_alert_tone`. HUD shows a red camera icon with a countdown. | A (C audio) | P2 |
| S3.6 | **One-shot rule**: an unalerted guard dies to any hit. | Identical. Damage to a `CALM`/`CURIOUS` guard is ≥ remaining HP. | A | P1 |
| S3.7 | Body-shot kills carry a 10% misfire chance (the guard's gun fires and alerts nearby NPCs). Headshots and shotguns don't. | Identical: 10%, rolled on `GameRng.stream(&"misfire")`. Noise = NPC gunshot (25 m). | A | P2 |
| S3.8 | **Civilians and guards see illegal actions** (masked player, carrying bag, holding weapon in casing…). | Masked player: always detectable. Unmasked: only in RESTRICTED zones. Carrying a bag (masked) counts as a suspicious stimulus. | A | P1 |

### S4. Stimuli: what NPCs react to

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S4.1 | **Guards react to:** unsuppressed gunfire (45 m player, 25 m NPC), explosions, masked players, bodies, body bags within 19 m LOS, other bags within 18 m (pre-placed bags ignored until moved), dominated guards, tied/panicking/downed civilians, broken cameras, active drills/saws, a saw cutting within 10 m, sentries, broken glass, ECM-feedback victims, hacking devices, some open doors. | Exactly this list as stimulus types (`StimulusKind` in `stealth_tweak.tres`), each with a range and LOS requirement. Pre-placed bags are flagged `moved = false` until first pickup. | A | P1 (core set) / P2 (rest) |
| S4.2 | **Guards ignore:** most opened doors and crates, open vaults, missing items, flashlights and lasers, getaway vehicles. | Identical. Doors carry a per-instance `suspicious_when_open` flag (default false). | A | P1 |
| S4.3 | **Noise sources** (stealth): unsuppressed shots, explosions, drills (25 m, or 12.5 m through walls) unless silenced, saws, glass breaking, alarms. Nothing else. | `NoiseEvent{pos, radius, kind}` broadcast by the server. Radius is reduced 50% when there is no LOS (◇ generalised from the drill rule). Suppressed weapons: radius 0–1 m. Melee: 0. **No other noise sources exist.** | A | P1 |
| S4.4 | **Cameras detect:** players, bags (19 m body bags / 18 m other), corpses, alerted NPCs, hostages, broken glass, broken cameras, drills (even outside their view), open vaults, sentries. Cameras do not hear. | Same list, except drills: a camera detects a running drill only inside its view cone and line of sight (D-114 §1; PD2's through-wall drill detection is dropped so the stealth route stays fair). Cameras have no hearing. | A | P2 |

### S5. Guards, patrols, pagers

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S5.1 | Guard patrol routes and counts vary per run; guards pause, look around, use phones, smoke. | Routes are generated from `PatrolGraph` per run (`GameRng &"patrols"`). Pause behaviours come from `PatrolPoint.pause_anim`. Guard count comes from variant rules (`guard_post`, `guard_extra`). | A (C graphs) | P1 |
| S5.2 | **Pager** on killing **or dominating** a guard (only guards carry pagers; police/civilians don't). It starts beeping **2–4 s** later. You have **12 s to start answering**. Answering is a **10 s hold**. | Identical numbers: delay rand(2, 4), 12 s start window, 10 s channel × `stealth.pager_answer_speed_mult`. The answer interaction is on the body (or dominated guard). The `cue.pager_beep` loop is audible to everyone near the body, plus a HUD timer. | A (C audio) | P1 |
| S5.3 | **4 answers per heist, team-wide.** The 5th answer raises the alarm *when it completes*. | `PagerSystem.max_answers = 4` (heist-definable; Crime-Spree-style modifiers may lower it). The answer that would exceed the cap completes and then raises `alarm_raised(&"pager_limit")`. Mercer voice line on answer 4 ("That's the last one they'll buy."). | A | P1 |
| S5.4 | **Letting go early raises the alarm immediately** unless another player is answering the same pager. **Juggling:** two players can overlap holds; the first completion counts. | Identical rule, plus the PD2 freeze (D-114 §4 as amended by the PO, 2026-10-15). The 12 s response window **freezes** the moment a player starts the answer hold and stays frozen while anyone holds it; it ends for good on a completed answer. A pager tracks a set of current answerers: when the set becomes empty before completion (release, look-away, going down, leaving) the **alarm** fires (`pager_failed(&"released")` → `alarm_raised(&"pager_failed")`), unless the pager is being **juggled** (another player holds it; first completion counts; juggling: same player starts another live pager within `pager_juggle_window_s` 0.5 s (ENV A 450b8ea0)). `StealthTweak.pager_release_resumes` (default `false`) is an opt-in variant where an early release instead resumes the frozen window with no alarm (fact `pager_answer_released`, events v1.4). Integration test `test_05_pager_released_early_alarm` covers the release alarm. | A | P1 |
| S5.5 | Pager unanswered past the window → alarm. | Identical: `pager_failed(&"timeout")` → alarm. | A | P1 |
| S5.6 | ECM affects pagers **only** with ECM Specialist aced, which pauses the response window of pagers whose guard died during the jam. | Base ECM does not touch pagers. The skill grant `stealth.ecm_pager_delay` pauses the 12 s window of pagers whose guard died during an active jam. | A, B | P2 |
| S5.7 | Some heists spawn a replacement guard after N answers. | `HeistMission` hook `on_pager_answered(total)`. Heist scripts may spawn a guard. | A, C | P2 |
| S5.8 | **Guard domination (stealth)**: one shout in the ~1.5 s window after a guard fully detects you makes him kneel and cuff himself. **His pager still fires.** | Requires `stealth.can_dominate_guards` (or base shout on non-guards, P3). Window 1.5 s after "!", success 100% inside it. Pager fires as normal. | A | P3 |

### S6. Bodies and body bags

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S6.1 | Corpses are discovered by guards, civilians and cameras on sight (→ alarm, or investigation for civilians, who panic). | Body = stimulus `corpse`. Guard → `ALARMED`; civilian → `PANICKED`; camera → alerts. | A | P1 |
| S6.2 | **Body bags**: 1 per player base, inventory cap 2. Cleaner gives +1 and cap 3. A Body Bag Case deployable holds 3. A body-bag asset can be bought. | Base 1, cap 2 (`stealth.body_bags_extra` raises both). `deployable.body_bag_case` holds 3. Pre-planning asset `asset.body_bag_drop` places a case. Bagging is a 3.0 s hold (◇) × `stealth.body_bag_speed_mult`. | A (B data) | P1 |
| S6.3 | A bagged body is a heavy bag that must be carried, thrown and hidden or secured. Guards see body bags within 19 m. | Body bag = loot bag `loot.body_bag` (HEAVY, value 0). Can be secured in `SECURE_LOOT` zones or dropped in `BODY_HIDE` zones/`body_container`. Stimulus range 19 m. | A (C zones) | P1 |
| S6.4 | Dominated/cuffed guards and tied civilians are themselves suspicious if seen. | Stimulus `hostage` (guards) / `restrained` (civilians see them → panic). | A | P2 |
| S6.5 | **Bodies:** close-range shotguns and explosions throw bodies (ragdoll); shooting a corpse makes it bleed and twitch, deals no damage. | Explosion kills always ragdoll; hit kills ragdoll at ≥ 90 N·s summed impulse (point-blank shotgun ≈ 250), else the pose-aware death clip then a 1 s settle; freeze after 3 s, cap 8 active. A bullet on a corpse (its lying `CorpseHitbox`) emits `blood_hit` + an impulse nudge, no damage, not counted for stats or suppression (damage.md v1.2, net.md v1.2 `rs`/`rp`, D-114 §7). ◇ | A | P6 |

### S7. Civilians and hostages

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S7.1 | **Intimidate** with a shout: they get down. They **get back up after a while** if not re-shouted and go back to fleeing/calling. ◇ duration (~50 s community guess). | `INTIMIDATED` for 45 s (◇) × `stealth.civilian_stay_down_mult`. A re-shout resets the timer. Shout range 12 m (◇) × `stealth.civilian_intimidate_range_mult`. One shout can affect several civilians in a cone (in the aim cone at ≤ 6 m, all of them). **Shouts do not pass walls or floors** (A civilian lane; on trunk once re-merged): only civilians on the shouter's floor (\|dy\| ≤ 2.5 m) with a clear line of sight (other NPCs don't block) or a navmesh path ≤ 6 m × `shout_path_mult` are affected. | A | P1 |
| S7.2 | **Cable ties**: 2 base, 6 with Forced Friendship. Tying takes 2 s (0.5 s with skill). Tied civilians stay down until freed by police. Hostages can be moved ("follow me"). | Base 2. Tie is a 2.0 s hold on an intimidated civilian → `TIED` (permanent until police free them). Follow-me order (P3). | A | P1 |
| S7.3 | **Killing a civilian** costs cash (cleaner costs scale with job tier × difficulty, $2k–$51k) and adds +30 s per kill to that player's trade negotiation. | Penalty per heist tier × difficulty in `difficulty_def` (`civilian_kill_penalty`). Deducted from the killer's payout and shown on the results screen. +30 s trade delay per kill. | A, B | P1 (penalty) / P3 (trade) |
| S7.4 | Civilians who see illegal actions become alerted and run to call. | See S3.1/S3.8. | A | P1 |
| S7.5 | Civilians in public areas idle, browse, queue, sit and wander. | Civilian spawn `idle_activity` plus ambient patrol tags. | A (C markers) | P1 |
| S7.6 | Stockholm Syndrome: your noise intimidates; hostages may revive you. | `ability.stockholm` (P3). | A | P3 |

### S8. Cameras, security room, ECM

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S8.1 | Cameras see in cones, die to one shot (below Mayhem). The operator may send a guard to investigate a broken camera. A broken camera is itself a stimulus. | Identical. Destroying a camera triggers `camera_disabled(&"destroyed")`. If the room is staffed, the operator dispatches the nearest guard to investigate (30% chance, ◇) after 10 s. Titan (indestructible) cameras appear on Lethal+. | A | P2 |
| S8.2 | **Camera operator** in the security room (a guard with a pager). Killing or dominating him disables **all** cameras permanently; the camera feed becomes viewable. | Identical. `camera_station` prefab plus a `CAMERA_OPERATOR` spawn. The `security_room_staffed` variant decides presence. | A (C room) | P2 |
| S8.3 | Camera loop (Nimble basic): 25 s, one at a time per crew. | `stealth.camera_loop` 25 s. | A | P3 |
| S8.4 | **ECM**: 2 s deploy, 20 s jam (flashing for the last 8 s). Jams all cameras and all phones globally. Does **not** jam pagers (without skill), lasers, panic buttons, or an already-alerted camera. Two ECMs don't stack (they chain sequentially). | Identical numbers. "Chainable": placing a second ECM queues it to start when the first ends. Duration × `stealth.ecm_duration_mult`. | A (B data, C model/audio) | P2 |
| S8.5 | ECM Overdrive aced opens keycard doors (4 s). ATMs open in 8 s (consumes the ECM). | `stealth.ecm_opens_doors`: placing an ECM on `keycard_reader`/`atm` consumes it and opens after 4 s/8 s. | A | P2 |
| S8.6 | **ECM feedback**: interact with a placed ECM to stun enemies in range (Cloakers immune). Recharges every 4 min. Alerts NPCs in stealth. | Built into every ECM (since PD2 U100). Radius 15 m (◇), stun 6 s (◇). The stun is an ALARM stimulus in stealth. | A | P3 |
| S8.7 | Pocket ECM (Hacker deck): 6 s, 2 charges, 100 s recharge (−6 s per kill), no doors. | `stealth.pocket_ecm` params. | A, B | P4 |

### S9. Interactions, tools, locks

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S9.1 | Everything is a **hold-to-interact with a timer**. Releasing cancels. Some interactions are instant. **Taking damage does not cancel an interaction** (D-134, PD2 source: `PlayerDamage:damage_bullet` never calls `interupt_interact`; it is only called when the target stops being interactable, and by `PlayerStandard:exit`, i.e. going down, tased, cuffed). | `InteractableComponent{duration, requires_item, phase, casing_allowed, noise}`. Progress lives on the server; the client shows a radial bar. Moving more than 0.5 m (◇) or looking away more than 40° cancels. Damage never cancels (humans and bots); the interactor going down, tased, cuffed or stunned/flashed (◇) does. `interaction.no_interrupt_on_damage` is obsolete. | A (B HUD) | P1 |
| S9.2 | **Lockpicking**: most doors, ~10 s (◇). Nimble aced: 100% faster and can pick safes. | Lockpick 8 s door (◇) × `interaction.lockpick_speed_mult`. Safes need `interaction.can_lockpick_safes`. | A | P1 |
| S9.3 | **Drill**: 3 s to place. 180 s on a security door, 60 s on a cage, 360 s thermal. Each drill jams up to 3 times at random (ours: 1–2, D-114). Fixing is an interaction. Noise 25 m (12.5 m occluded). Hardware Expert: fix 25% faster and silent. Auto-restart chance +10% (HWE aced) +20% (Kickstarter), rolled once at placement. Kickstarter aced: melee to fix, 50%. Drill Sawgeant −15%/−30% time. Upgrades apply to remaining time. | Identical rules. Jam times are rolled at placement (`GameRng &"devices"`): `n_jams` = 1, +1 with chance `device_jam_extra_chance` 0.35 (D-114 §2: 1–2 per drill, mean ≈ 1.35, never in the first/last 10 %), placed in 15–90% of progress with a ≥ 20% gap (`DeviceRunner.roll_jam_points`). Fix = 2 s hold (◇) × 0.75 if skilled. Auto-restart rolled once at placement and on each fix: restart after rand(5, 10) s. Drill duration per `drill_point.duration_s` × `interaction.device_speed_mult`. Silent via `stealth.silent_devices`. Upgrades (asset/skill, P4). | A (C model/audio) | P1 |
| S9.4 | **Saws** (placed): same as drills, same skills. | `drill_point.device = SAW`, same code path. | A | P2 |
| S9.5 | **Shaped charges**: 3 base (trip-mine deployable), 6 max. Loud. N per door type. | `interaction.shaped_charge` plus trip-mine count. Charges per target come from prefab `charges_required`. | A | P3 |
| S9.6 | **Keycards** (random location per run) open keycard doors. | `keycard` slot_group, ≥ 3 slots per heist, `item.keycard` count per player. | A, C | P1 |
| S9.7 | **Codes/keypads**: the code is found on a note, computer or person (random per run). | `code_note` slot group. The code value is rolled (`&"codes"`) and shown in the note's prompt and on the HUD when read. | A, C | P2 |
| S9.8 | **Safes** (small/medium/vault), opened by drill/saw/C4/lockpick (skill)/code. **Vaults with time locks.** | `safe` prefab with `methods` and a `time_lock_s` option (vault waits on a timer once opened, with a hackable panel). Stealth-only lockpick fallback on safes that allow it: 20 / 40 / 60 s for small / medium / large (◇, D-114 §1); the drill stays the loud route. | A | P2 |
| S9.9 | **Glass breaks loudly** (stimulus); display cases. | `display_case.Glass` shatter → stimulus `broken_glass` (camera/guard visible) + noise 15 m (◇). | A (C shatter art) | P1 |
| S9.10 | **Laser grids** trip the alarm on touch, even in civilian mode. ECM doesn't affect them. | `laser_grid` prefab with patterns: static / sweeping / timed-off. Trips → `alarm_raised(&"laser")`. | A (C FX) | P2 |
| S9.11 | Windows, ladders, ziplines, vents. | `window` (open/break), `ladder`, `zipline` (bag and/or player), vents via nav layer `vent`. | A, C | P1 (window, ladder) / P2 |

### S10. Loot

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S10.1 | **Bags**: carry one at a time. Heavier bags slow you more and limit sprint/jump. You can throw them (thrown bags are visible to NPCs within 18 m). | Weight classes LIGHT/MEDIUM/HEAVY/VERY_HEAVY (PD2 light/medium/heavy/very_heavy, carrytweakdata.lua) → speed ×1.0/0.75/0.5/0.25; sprint allowed only for LIGHT; jump always allowed, jump velocity ×1/1/0.5/0.25; head bob × the speed mult (D-102). Throw distance 4/4/2/1.2 m × `loot.throw_distance_mult` (◇). Thrown bags are physics bodies (server) and act as stimulus `bag` (18 m). | A | P1 |
| S10.1b | Ladders can't be climbed while carrying a bag (PD2): bags are thrown up or down, or sent by lift or zipline. | Identical (QC-17, D-042). | A | P2 |
| S10.2 | Bags are **secured** at an escape zone/van/zipline/heli. Throwing a bag into the zone secures it. | `SECURE_LOOT` MapZone: a bag resting inside for 0.5 s is secured → `loot_secured`. | A | P1 |
| S10.3 | Small loot (cash bundles, jewelry on counters) is picked up instantly and adds to payout without bags. | `small_loot` prefab, 0.5–1 s pickup. | A | P1 |
| S10.4 | Loot value × difficulty multiplier (×1 … ×9.2). Payout = (contract + secured loot) × crew-alive bonus (110%). Split 80% offshore / 20% spending. | Identical structure. Our difficulty loot multipliers: Routine 1, Tense 2, Hazardous 2.6, Brutal 4.2, Lethal 7.2, Cataclysm 9.2. The offshore currency is named **"the stash"**. | B (payout), A (counts) | P1 |
| S10.4b | Job heat: jobs not played recently give bonus XP, jobs played a lot give less. | **Deviation (PO, D-139):** "heist freshness" moves XP **and** money: −10 % per appearance in the player's last 10 runs (floor ×0.10); once a completed heist leaves that memory, +1 % per further run, up to +10 %. Per player. | B | P6 |
| S10.5 | Loot bags dropped by custody players stay where they were. | Identical. | A | P3 |
| S10.6 | **Economy shape (D-120).** PD2: on loot heists the secured bags pay most of a full clear and greed pays; the contract is the floor. Bag values rank gold > heavy/medium goods > cash > light items. The contract broker costs a modest, difficulty-rising share of a run. The top difficulties are level-gated. | Bags (unscaled): gold 14k, weapon crate 8.5k, cash bricks / ledger books 8k, drives / parcels 7.5k, contraband / bonds 7k, cash 6.5k, jewelry 6k, laptop 5k, SL painting 4.5k, GN canvases 8k/6.8k/6k/5.2k, study 2.8k. Contracts (unscaled): GH 12k, ND 26k, SL 70k, DB 24k, GN 57k. Broker = [4k, 8k, 14k, 30k, 60k, 90k][d] + 10% of the scaled contract. Board gates: Lethal and Cataclysm at level 70 (D-151; was 80). Bag share of a full clear: GH 55%, ND 67%, SL 39% (objective heist), DB 81%, GN 53%. Table below; full clear = contract + every bag + small loot, × payout_mult × 1.1 crew-alive (expected variant rolls). | B (values), C (base_payout) | P5 |

Full clear vs. minimum run (contract + required bags) and broker price, per heist and difficulty (D-120):

| Heist | Difficulty | Contract | Full-clear bags | Small loot | Full clear ×1.1 | Min run ×1.1 | Broker | Gate |
|---|---|---|---|---|---|---|---|---|
| GH | Routine | $12,000 | $27,000 | $9,850 | $53,735 | $26,400 | $5,200 | 0 |
| GH | Tense | $24,000 | $54,000 | $19,700 | $107,470 | $52,800 | $10,400 | 0 |
| GH | Hazardous | $31,200 | $70,200 | $25,610 | $139,711 | $68,640 | $17,120 | 0 |
| GH | Brutal | $50,400 | $113,400 | $41,370 | $225,687 | $110,880 | $35,040 | 0 |
| GH | Lethal | $86,400 | $194,400 | $70,920 | $386,892 | $190,080 | $68,640 | 80 |
| GH | Cataclysm | $110,400 | $248,400 | $90,620 | $494,362 | $242,880 | $101,040 | 80 |
| ND | Routine | $26,000 | $75,350 | $11,000 | $123,585 | $57,200 | $6,600 | 0 |
| ND | Tense | $52,000 | $150,700 | $22,000 | $247,170 | $114,400 | $13,200 | 0 |
| ND | Hazardous | $67,600 | $195,910 | $28,600 | $321,321 | $148,720 | $20,760 | 0 |
| ND | Brutal | $109,200 | $316,470 | $46,200 | $519,057 | $240,240 | $40,920 | 0 |
| ND | Lethal | $187,200 | $542,520 | $79,200 | $889,812 | $411,840 | $78,720 | 80 |
| ND | Cataclysm | $239,200 | $693,220 | $101,200 | $1,136,982 | $526,240 | $113,920 | 80 |
| SL | Routine | $70,000 | $51,000 | $8,500 | $142,450 | $99,000 | $11,000 | 0 |
| SL | Tense | $140,000 | $102,000 | $17,000 | $284,900 | $198,000 | $22,000 | 0 |
| SL | Hazardous | $182,000 | $132,600 | $22,100 | $370,370 | $257,400 | $32,200 | 0 |
| SL | Brutal | $294,000 | $214,200 | $35,700 | $598,290 | $415,800 | $59,400 | 0 |
| SL | Lethal | $504,000 | $367,200 | $61,200 | $1,025,640 | $712,800 | $110,400 | 80 |
| SL | Cataclysm | $644,000 | $469,200 | $78,200 | $1,310,540 | $910,800 | $154,400 | 80 |
| DB | Routine | $24,000 | $122,400 | $5,250 | $166,815 | $61,600 | $6,400 | 0 |
| DB | Tense | $48,000 | $244,800 | $10,500 | $333,630 | $123,200 | $12,800 | 0 |
| DB | Hazardous | $62,400 | $318,240 | $13,650 | $433,719 | $160,160 | $20,240 | 0 |
| DB | Brutal | $100,800 | $514,080 | $22,050 | $700,623 | $258,720 | $40,080 | 0 |
| DB | Lethal | $172,800 | $881,280 | $37,800 | $1,201,068 | $443,520 | $77,280 | 80 |
| DB | Cataclysm | $220,800 | $1,126,080 | $48,300 | $1,534,698 | $566,720 | $112,080 | 80 |
| GN | Routine | $57,000 | $79,200 | $14,100 | $165,330 | $78,980 | $9,700 | 0 |
| GN | Tense | $114,000 | $158,400 | $28,200 | $330,660 | $157,960 | $19,400 | 0 |
| GN | Hazardous | $148,200 | $205,920 | $36,660 | $429,858 | $205,348 | $28,820 | 0 |
| GN | Brutal | $239,400 | $332,640 | $59,220 | $694,386 | $331,716 | $53,940 | 0 |
| GN | Lethal | $410,400 | $570,240 | $101,520 | $1,190,376 | $568,656 | $101,040 | 80 |
| GN | Cataclysm | $524,400 | $728,640 | $129,720 | $1,521,036 | $726,616 | $142,440 | 80 |

Broker / full clear 4–20 %; broker / minimum run 10–42 % (GH Cataclysm highest). Unbuilt P5 heists (Ostrander, Rolling
Thunder, Afterhours) keep placeholder $75–160k contracts and need the same cut when built.

### S11. Stealth reward and transition

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| S11.1 | **Stealth bonus**: an XP bonus applied to the *next* heist (0–25%). | Stealth bonus of 5–25%, scaled by heist size; stored in the profile and applied to the next payday. Values (LEAD 2026-10-17, B): S 1.10 (GH), M 1.15 (ND, GN, SL), L 1.25 (OF), loud-only 1.0; PayoutCalculator banks `HeistDef.stealth_bonus_mult` when > 1.0, else the tweak. | B | P4 |
| S11.2 | **Seamless transition**: when the alarm sounds the heist becomes loud with no load and no reset. Everything persists. | `HeistPhase.STEALTH → LOUD` is a state change only. Bodies, bags, doors and devices persist. Guards switch to combat AI. Civilians panic. The director starts **CONTROL** (first responders) → first assault. Music crossfades. **Tested in P1 gate.** | A | P1 |
| S11.3 | Stealth-only heists: an alarm = fail (or a scripted "loud failure"). Loud-only heists start loud. | `HeistDef.mode`. On STEALTH_ONLY, alarm → `heist_ended(failed)` after a 5 s Mercer abort line. | A | P2 |

---

## L. Loud

### L1. Assault director

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| L1.1 | Phases: **Control** (first responders, negotiations) → **Anticipation** 30 s (+30 s if hostage held; +10 s on Mayhem+) → **Build** ~35 s (flashbangs, smoke) → **Sustain** 40–209 s by stage and player count → **Fade** (stop spawning, retreat when fewer than 50 enemies remain or after a no-damage drama window) → Control again. | Identical phase machine in `AssaultDirector` (server). Sustain duration table by stage (50/75/100%) × crew count copied from PD2. Fade when `alive_enemies < fade_threshold` or drama < 0.2 for 30 s after the sustain timer. `fade_threshold` is PD2's "fewer than 50" rescaled to our enemy cap (DifficultyDef.enemy_cap ≈ 30): 8/10/12/14/16/18 by difficulty in DirectorTweak (D-075). Hostage anticipation bonus applies once (not per hostage). ◇ D-099: each assault has a force pool (PD2 force_pool); spending it ends the assault → FADE, where units retreat to non-breach spawns and despawn out of sight. | A | P1 (one wave) / P3 (full) |
| L1.2 | **Drama**: the director tracks pressure (damage to players) and adapts spawn pressure. | `drama` 0..1 rises with player damage taken and nearby combat, decays 0.05/s. Build/sustain spawn rate is scaled by `(1 − 0.5·drama)`. | A | P3 |
| L1.3 | **Escalation**: later waves → later stages, more units, specials; specials also between waves (Cloakers more so). | `assault_index` → stage curve (wave 1 = 50%, wave 2 = 75%, wave 3+ = 100%). Special spawn weights by wave and difficulty. Specials spawn in CONTROL (low rate). ◇ D-099: alive cap = enemy_cap × crew balance mul × stage 50/75/100 %. | A | P3 |
| L1.4 | **Spawn groups and spawn points**: police enter from map edges, entry points and rappel points; group compositions vary by difficulty/faction. | `SpawnGroupDef` resources (`systems/ai/data/groups/*.tres`). Spawns use `POLICE_SPAWN` and `ENTRY` points out of sight of all crew (LOS + 15 m rule), choosing the nearest valid one to the crew centroid. Enemy cap per difficulty. ◇ D-099: crew scaling counts AI bots as half a player (PD2 _get_balancing_multiplier); Routine, 1 human + 3 bots = 4/6/8 alive in waves 1/2/3+. | A (C points) | P1 |
| L1.5 | **Factions** by difficulty: beat cops → SWAT → FBI → GenSec → ZEAL. | Patrol Officer → TAC (Routine/Tense) → FRD (Hazardous/Brutal) → **Sentinel Corp** (Lethal) → **Zero Division** (Cataclysm). Same roles, new models and voice packs. | A (C art) | P3 |
| L1.6 | No custody negotiation during an assault (but a highlighted hostage can still be traded). | Identical. | A | P3 |
| L1.7 | Assault HUD banner with difficulty skulls; "police assault in progress" styling; phase-reactive music. | HUD banner (B). `assault_phase_changed` drives music stems (C): calm/stealth, control, anticipation riser, assault full, fade. | B, C | P1 |

### L2. Player survival model

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| L2.1 | **Health** does not regenerate (except via skills/perks). ◇ base 230 display units. | Base health 230. No regen unless `defense.health_regen_per_sec` or perk mechanics. | A | P1 |
| L2.2 | **Armor** absorbs first. **Armor-gating**: any normal enemy hit is capped at remaining armor (sniper excepted), with 0.35 s (0.45 s below Mayhem) invulnerability after a hit. Full regen after ~3 s without damage or dodge. | Identical, including gating and the per-difficulty invuln window. Regen delay 3.0 s × `defense.armor_regen_delay_mult`. Regen refills fully over 1.0 s (◇). The delay restarts on any damage or dodge. | A | P1 |
| L2.3 | **Armor tiers**: Suit 20/30 conceal/+5 dodge … ICTV 170/1/−55. Speed and stamina scale down. | Our 7 tiers mirror PD2's table (names: Tailored Suit, Light Vest, Patrol Vest, Heavy Vest, Flak Rig, Tactical Plate, Breacher Plate (needs skill)). | B | P1 (2 tiers) / P4 |
| L2.4 | **Dodge**: chance a ranged hit does nothing. Additive; a negative total means no dodge. Melee can be dodged but knockback still applies. Sources: armor, Sneaky Bastard (DR-scaled), decks. | Identical. Dodge roll per incoming hit on `GameRng &"dodge"`. A dodge resets armor delay. | A | P2 |
| L2.5 | **Bleedout**: 30 s. Can shoot, throw and toss bags; can't move or deploy. Bleedout HP 100. Police don't shoot a downed player who isn't shooting. | Identical. | A | P1 |
| L2.6 | **Downs**: 3. The 4th "zero health" goes straight to custody. Reset only by Doctor Bag or custody release. Final down → greyscale screen. | Identical (`defense.downs_extra`). Greyscale is a post FX (C) driven by state (A). | A, C | P1 |
| L2.7 | **Revive**: 6 s hold. After revive, health is 40% of base on Brutal and below (−60%) and 10% on Lethal+ (−90%). | Identical. | A | P1 |
| L2.8 | **Taser and Cloaker takedowns.** PD2: a Cloaker kick puts the victim into a normal (counted) down with bleed-out; a tase that is not broken (Taser killed / stunned / LOS) ends in a down. | **Amended by D-145:** an expired tase → a counted down (bleed-out, revivable); a broken tase frees the victim (no down). A Phantom kick is a counted down with bleed-out (the victim stays kicked flat in `CLOAKER_DOWNED`, can't shoot); custody only when bleed-out runs out. No takedown goes straight to custody. Stinger re-tase cooldown 12 / 8 / 4 s by difficulty + victim immunity 10 / 6 / 0 s (◇, Routine/Tense gentler). | A | P3 |
| L2.9 | **Custody**: auto-release 119 s on Normal/Hard, otherwise trade-only. Released at full health with 50% ammo, no deployables refilled. Heist fails if all humans are in custody. | Identical. Auto-release on Routine/Tense. **Solo with AI**: the heist fails if the human is in custody and no AI can trade (AI teammates can't take hostages; the trade happens automatically when a hostage exists). | A | P3 |
| L2.10 | **Hostage trade**: negotiation of 5 s + 30 s per civilian killed by that player, outside assaults. Then a hostage is highlighted; interacting trades. | Identical (Mercer lines). | A | P3 |
| L2.11 | **Doctor Bag** 2 uses (full heal + reset downs). **First Aid Kit** 4 (1 s deploy, heals, no down reset). **Ammo bag** 4 uses (400%). | Identical. | A (logic), B (data) | P2 |
| L2.12 | **Cuffs** (guards in stealth, P2) and **cuffing by police** in loud on downed players? (PD2: cops can cuff a player at melee range). | Police arrest a downed heister who is not shooting: after 2 s down without firing, a cop at arm's length (1 m) holds a 1.5 s arrest; firing from the floor or hurting / stunning the cop interrupts it (◇ timings, D-108). No self-free from a police cuff: the bleed-out keeps running while cuffed, and a teammate uncuffs (back to DOWNED, revivable) or it ends in custody (LEAD 2026-10-21; stealth guard cuffs, S3.2, keep their 60 s escape). **D-145:** police cuff a downed heister only from Hazardous up (`CustodyTweak.police_cuff_min_difficulty`); on Routine/Tense the bleed-out timer alone decides custody (◇, no PD2 source either way). | A | P3 |

### L3. Weapons and damage

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| L3.1 | Stats: magazine, total ammo, RPM, damage, accuracy, stability, concealment (cap 30), threat, reload (tactical/empty), hidden ammo pickup. | `WeaponStats` physical values; ENV B maps them to PD2-style 0–100 display numbers for UI. | B (A uses physical) | P1 |
| L3.2 | **Falloff**: ARs none; shotguns heavy past close range (except AP slugs); SMG/LMG past medium; pistols moderate; **snipers gain damage at long range**; specials none. | `falloff_start/end/min_mult` per weapon. Snipers use `min_mult > 1` (damage increases with range). ARs use start = end = 9999. | B (data), A (apply) | P1 |
| L3.3 | **Headshots**: multiplier per enemy per difficulty; it shrinks on the top difficulties. For shotguns, any pellet on the head counts. Crits are a separate multiplicative headshot. | `EnemyDef.headshot_mult[difficulty]` copied from the PD2 table shape. Pellet rule identical. | A | P1 |
| L3.4 | **Armor piercing**: snipers, AP slugs and AP pistols pierce body armor, shields (~25% dmg), thin walls. Fire ignores armor and shields. | `armor_pierce`, `shield_pierce`, `wall_pierce` on WeaponStats. Shield pass-through ×0.25. | A, B | P3 |
| L3.5 | **Suppression ("threat")**: damage and near-misses build it. Threshold 1: enemy hunches (+50% shot delay, +50% aim time, −50% hit chance). Threshold 2: dives for cover. Afterwards 50% resistance for 30 s. Specials and top-faction units are immune. Suppressed weapons have 0 threat. | Identical structure. | A | P3 |
| L3.6 | **Explosives**: damage × (1 − d/r)^0.1. | Identical formula. | A | P3 |
| L3.7 | **Suppressors**: noise radius ~0 m. | `noise_radius_m` 0–1. | A, B | P1 |
| L3.8 | **Hit registration** (PD2: client-side for players). | Client hit claims validated by server (see architecture §3). | A | P1 |
| L3.9 | **Melee**: charge, knockdown, silent; concealment matters; melee kills in stealth are silent. | MeleeDef + melee intent; charge 0–1 s scales damage. | A, B | P2 |
| L3.10 | **Shotgun ammo** (PD2: AP slug, HE, flechette, dragon's breath). Listed damage is per shot; the ammo changes delivery. | `ShotgunAmmo` (D-118 + addendum). Per-shot damage is preserved: per-pellet × stock/new pellets. Slug: 1 pellet, armor + shield + thin-wall pierce, no falloff penalty. HE: 1 pellet, explosion 2.0 m. Flechette: pellets ×1.5, bleed 4/s for 3 s. Dragon's breath: ignite 8/s for 3 s, panics civilians in the cone. range_mult 0.7. Values are B's AMMO mod params; `CombatTweak.shotgun_ammo_defaults` are fallbacks only. | A (B data) | P4 |

### L4. Enemy roster (PD2 behaviour, our names)

Every special has (i) an **audio telegraph** distinct enough to recognise without seeing it, (ii) a
**visual telegraph**, and (iii) a **counterplay** verb. All are in `audio_cues.md`.

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| L4.1 | **Guard** (stealth): pager, patrol, radio, cuffs, one-shot when unalerted. | **Security Officer**. | A (C model) | P1 |
| L1.D | **Low-difficulty loud (PO-17/18, D-145):** PD2 Normal/Hard are much gentler than the top tiers. | ◇ Routine ≈ PD2 Normal, Tense ≈ PD2 Hard, tuned by feel (verify against PD2 tweak data): police damage Routine/Tense ×0.7/×0.85 of the old shared value, `npc_hit_chance_mult` 0.65/0.8, assault force pool ×0.6/×0.8, refill ×2/×1.5 slower, specials share ×0.5/×0.75. No body-armored police (TAC Heavy, plates, Wreckers) below Hazardous (`EnemyRoster.resolve`, `armored_min_difficulty`); Bulwark shields stay. Acceptance: P windowed, solo + 3 bots, median ≤ 2 downs. | A (B data) | P6 |
| L4.2 | **Beat cops / SWAT / heavy SWAT**: basic loud units. Heavies have frontal armor. Suppressible, dominatable (low tiers). | **Patrol Officer / TAC Light / TAC Heavy** (heavy: frontal plate ×0 body damage from non-AP, head vulnerable). Health per PD2 table shape. | A | P1 (Patrol, TAC Light) / P3 |
| L4.3 | **Cloaker**: Very Hard+, cap 2. Electrical hum/"phone ring" while near. When charging, **goggles glow green** and the sound gets louder. Sprinting jump-kick → instant incapacitation (no down counted), beats you, drops smoke, may camp the body. ~10 s kick cooldown. Dodgeable with a sidestep. Flanks via vents/manholes, plays dead. Immune to ECM feedback. **Won't kick a solo player with no AI, or the last player standing.** Counterstrike aced knocks it down. | **Phantom**. Identical behaviour and numbers. Telegraphs: `cue.phantom_hum` (a detuned buzzing 2-tone ring, 3D, 25 m), `cue.phantom_charge` (rising scream plus the hum doubling in volume), green goggle emission. Uses nav layer `vent`. "Play dead": 15% chance (◇) when hit to drop and get up later. | A (C audio/model) | P3 |
| L4.4 | **Taser**: ~1 s audible windup. Tase loop: victim can't move/interact, convulses, weapon auto-fires and auto-reloads; the victim can still click to shoot. Broken by killing the taser, Shockproof (30% knockback; aced: interact within 2 s to shock back). A long tase downs silently (no down counted). Deploy in pairs and retarget. | **Stinger**. Identical. Windup cue `cue.stinger_windup` (ramp 1 s), loop `cue.stinger_arc`, blue arc beam VFX. Auto-fire: weapon fires at max RPM with spread ×3 and aim jitter, pulled 15° up. Long tase → `CLOAKER_DOWNED`-like helpless state after 6 s (◇). | A (C VFX/audio) | P3 |
| L4.5 | **Shield**: frontal ballistic shield blocks all but explosives/fire/AP (AP ×0.25). Blocks doorways, fixates on one player, acts as cover for Tasers/Dozers, bangs the shield. Weak to flanks. A dead Shield's shield falls to the floor and can be walked over. Shock-and-awe-style stagger. | **Bulwark**. Identical. Shield is a separate body (physics layer `world_dynamic`, bullet-blocking) while carried; on the carrier's death it lies flat on the floor (≤ 0.2 m) off the movement-blocking layers, so crew, NPCs and bags pass over it (round 130, ND soft-lock: an upright dropped shield walled a 1 m corridor). Cue `cue.bulwark_bang`. Formation logic: other specials prefer positions behind an allied Bulwark (`shield_anchor`). | A | P3 |
| L4.6 | **Bulldozer**: headshot-immune until **faceplate (150 HP)** then **visor (160 HP)** are shot off (same HP on every difficulty). Huge HP (2k–24k). Immune to stuns, sprints while firing, ×1.1 explosive damage. Variants: pump shotgun, semi-auto shotgun, LMG, minigun (2× HP), medic. | **Wrecker**. Identical staged weakpoints: `Faceplate` (150) → `Visor` (160) → head exposed (headshot mult per table). Each stage break plays `cue.wrecker_plate_crack` plus a visible mesh change (C provides 3 head states). Intro `cue.wrecker_roar`; heavy footstep loop audible 30 m. Variants: Wrecker-G (pump), Wrecker-B (semi), Wrecker-S (LMG), Wrecker-M (minigun, Cataclysm). | A (C staged model) | P3 |
| L4.7 | **Sniper**: rooftop/perch. **Red laser** visible, loud report. 100–240 dmg by difficulty, **halved beyond 30 m** (except Death Wish). **Bypasses armor-gating.** | **Longshot**. Identical. Spawns only at `SNIPER_PERCH` TacticalPoints. Laser beam visible to all players (C shader); 1.2 s aim lock (◇) with a laser that tracks, then fires. Cue `cue.longshot_report`. | A (C laser FX) | P3 |
| L4.8 | **Medic**: heals or revives **one** ally within **7 m**, even through walls (green outline), with a 3 s cooldown. Neither medic nor target can move or shoot while healing. Medics don't heal medics. | **Corpsman**. Identical. Cue `cue.corpsman_heal` (bright two-note chime) plus green outline on the healed unit. | A | P3 |
| L4.9 | **Captain Winters + Phalanx**: once per heist day, VH+, arrives during an assault with 10 shields. Assault locked until he retreats. All enemies +10% damage resistance, +5% every 5 s while in position, up to 50%. He and the shields take at most 10% max HP per hit, ×6 from explosives, no flinch. **Cannot be killed**; retreats at 20% HP or when the formation drops to ~3 shields. | **Commander Brandt + Aegis squad**. Identical rules. Visual: a translucent hex "bubble" shader around the squad (C), pulsing as the resistance stacks. Cue `cue.brandt_arrival` (horn plus music sting) and a periodic `cue.aegis_pulse`. HUD shows a buff icon with the % resistance. Online-only in PD2; **ours: also in solo** (solo with AI is first-class). | A (C shader/audio) | P3 |
| L4.10 | Gangsters (no pagers, can't be dominated) on some heists. | **Cartel crew** faction for `dockside_burn`. | A | P3 |
| L4.11 | Spawn caps by difficulty (Overkill: Shields 4, Tasers 2, Medics 3, Cloakers 2, Dozers 2; higher on Mayhem+). | `DifficultyDef.special_limits`; PD2 shape copied. | A | P3 |

### L5. Crowd control in loud

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| L5.1 | Shout makes low-tier cops surrender (chance-based, better when hurt or outnumbered). Specials and top factions are immune. | `ability.intimidate_cops` or base (chance formula ◇: 0.2 + 0.5·(1−hp%) + 0.1·nearby_crew). | A | P3 |
| L5.2 | **Joker**: convert a surrendered cop to an ally (1, or 2 with skill). | `ability.converts_max`. Converted ally is an AI with an ally outline. | A | P3 |
| L5.3 | Hostages (civilians/cops) delay the assault (+30 s once) and enable trades. | See L1.1, L2.10. | A | P3 |

### L6. AI teammates (solo is first-class)

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| L6.1 | Bots fill empty slots. They follow, revive, fight, don't do objectives, don't carry bags (later mods allowed bag carrying). They can be ordered to hold position. Bots don't play stealth (they spawn when the heist goes loud). | **Ours improves on PD2 (allowed: "never required"):** AI crew exist from the start but in stealth they **stay at the spawn/hide point** (cannot be detected; they are "in the van") unless ordered to follow (then they are detectable like players; P4 option). In loud: follow the nearest human (or the human who ordered), revive (6 s, prioritise downed humans), fight, use cover, **carry a bag only when ordered** (`order: carry_bag` targeting a bag, then they follow and secure it on a `drop_bag` order or on reaching a secure zone they know), **hold position** on order. | A | P1 (loud follow/fight/revive) / P3 (orders, bags) |
| L6.2 | Bots have their own loadout and abilities (later: bot skills/boosts). | AI loadout data (B) with a small AI skill set (inspire-light, ammo/health boosts). | A, B | P4 |
| L6.3 | Bots can trade hostages? (no) Bots get custody and are traded like players. | Identical. | A | P3 |

---

## P. Progression and customisation

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| P1 | **Levels**: reputation 0–100, 1 skill point per level + 2 every 10 levels (120 total). XP curve 900 → 1,000,000 per level (~23M total). | Level 0–100, same point formula (120). XP curve: PD2's 900 → 1,000,000 per level (~23.3 M), D-148. Base heist XP by size (S 1,500 / M 2,000 / L 2,500–3,000, `PayoutTweak.base_xp_by_heist`) + 250 per bag, PD2 difficulty multipliers. | B | P4 |
| P2 | **5 trees × 3 subtrees × 6 skills = 90 skills**. Tiers per subtree 1/2/2/1 skills. Tier unlocks at 1/3/18 points spent in the subtree. Cost basic/aced 1/3, 2/4, 3/6, 4/8. A full tree costs 138 (you can't finish one). Respec is free; multiple skill sets. Same team skill from several players doesn't stack. | Identical structure and costs. Tree names in `game_overview.md` §6. ENV B authors all 90 skills as `SkillDef` (originally named), mapping effects only to modifier keys. **Every skill must change a decision**: lead review rejects pure "+X%" filler in tiers 3–4. Reference: research Appendix A. | B (A hooks) | P4 (P2: 12 key skills) |
| P3 | **Signature skills** that must exist (our names in brackets): Inspire [Rally Cry], Forced Friendship [Zip & Tie], Joker [Turncoat], Stockholm Syndrome [Captive Audience], Hostage Taker [Leverage], Bullseye [Clean Shot], Iron Man [Plated], Hardware Expert [Tinker], Drill Sawgeant [Overclocked Bits], Kickstarter [Percussive Maintenance], Chameleon [Plain Sight], Cleaner [Tidy Up], Sixth Sense [Gut Feeling], Nimble [Light Fingers], ECM Overdrive [Signal Flood], ECM Specialist [Jammer Jockey], Inner Pockets [Deep Pockets], Dire Need [Cornered], Shockproof [Grounded], Sneaky Bastard [Slippery], Second Wind [Bolt], Optical Illusions [Low Profile], Low Blow [Cheap Shot], Unseen Strike [Ambusher], Nine Lives [Cat's Luck], Swan Song [Last Stand], Messiah [Comeback], Counterstrike [Riposte], Berserker [Red Mist], Body Expertise [Anatomy], Bulletstorm [Lead Rain], Fully Loaded [Pack Mule], Overkill [Momentum], Graze [Grazing Fire], Trigger Happy [Hot Streak]. | Final names may be changed by ENV B but must stay original. | B | P4 |
| P4 | **Perk decks**: 23 × 9 cards. Cards 2/4/6/8 shared (Helmet Popping +25% HS dmg; Blending In +1 conceal, +45% XP, −15% armor move penalty; Walk-in Closet armor bag + 135% ammo pickup; Fast & Furious +5% dmg, faster doctor bag). Odd cards unique. Card costs 200…4000 (13,700 per deck). One active deck. | 14 decks at launch (see table below), same 9-card layout and costs. Shared cards renamed (Headhunter, Low Profile, Go Bag, Hustle). | B (A mechanics) | P4 |
| P5 | **Armory**: pistols, SMGs, ARs, shotguns, LMGs, snipers, specials (launchers, flamethrower, bows/crossbows, minigun), akimbo, melee, throwables, deployables. | Launch target: 36 weapons (6 pistols, 6 SMGs, 6 ARs, 5 shotguns, 3 LMGs, 4 snipers, 6 specials incl. a bow, a launcher, a flamethrower) + 12 melee + 6 throwables + 7 deployables. All fictional manufacturers. | B | P1 (1 pistol + 1 rifle) / P4 |
| P6 | **Mod workshop**: barrel, barrel ext (suppressors), sight, gadget (laser/flashlight/angled sight), grip, foregrip, stock, magazine, upper/lower receiver, bolt, ammo types, boosts, skins. Mods trade stats, especially concealment vs performance. Visual change on the model. | `ModType` enum covers these. Every mod has ≥ 1 downside unless cosmetic. 3D workshop UI with orbit camera, live stat deltas (green/red), concealment → DR preview. | B | P1 (suppressor + sight) / P4 |
| P7 | **Firing range** (PD2 "Shooting range" in the safehouse). | **Expanded** per brief: lanes with marked distances 5/10/15/20/30/40/60/80/100 m, moving targets (lateral tracks 2–5 m/s), armor dummies per special (Bulwark shield, Wrecker staged plates, Corpsman, heavy frontal plate), DPS/TTK readout, falloff graph, live stat panel, instant loadout swap (any weapon and mod without owning it), difficulty selector for dummy HP. | B (C art kit) | P1 (basic) / P4 |
| P8 | **Masks**: base mask + color + pattern + material, from drops/unlocks. | Procedural mask system: base mask shapes (C generates meshes) × material shaders × colour pairs × patterns. | B (C mesh/shader) | P4 |
| P9 | **Payday cards**: pick 1 of 3 (30 s auto-pick): mask parts, cash, XP, weapon mods, boosts, skins. | Identical; no real-money anything. | B | P4 |
| P10 | **Infamy**: prestige past 100 (cost, XP bonus, cosmetics). | **Notoriety** ranks 1–25 (P6). | B | P6 |
| P11 | **Crime Spree** endless mode. | Post-launch candidate ("Hot Streak"); not scheduled. | — | — |

### P-decks: our 14 decks (signature mechanic)

| Deck | PD2 analog | Signature (modifier key) |
|---|---|---|
| Foreman | Crew Chief | Team aura DR/stamina/health/armor + per-hostage bonuses (`team.*`, `team.damage_reduction_hostage`) |
| Bulk | Muscle | +100% health, draws aggro, health regen 3%/5 s (`perk.muscle`) |
| Ironclad | Armorer | +armor; 2 s health immunity on armor break, 15 s cd (`perk.armorer`) |
| Slipper | Rogue | Dodge stack +45%, weapon swap speed, AP chance (`perk.rogue_dodge_stack`) |
| Hustler | Crook | Dodge + armor bonus in mid vests only (`perk.crook`) |
| Clean Sweep | Hitman / Sociopath | Kill-chain armor restore (30 per kill, 1 s cd), armor always returns 1.5 s after break (`perk.sociopath`) |
| Prowler | Burglar | Faster bagging / lockpick / pager, dodge; armor regen while crouched-still (`perk.burglar`) |
| Knuckles | Infiltrator | Close-range DR, melee stacking, melee heal (`perk.infiltrator`) |
| Bloodletter | Grinder | Damage dealt → stacking heal over time; suit / light vest only (`perk.grinder`) |
| Composure | Stoic | No armor (→ health), damage → DoT, flask negates (`perk.stoic`) |
| Overclock | Anarchist | Health→armor, periodic armor ticks, armor on hit (`perk.anarchist`) |
| Incumbent | Ex-President | Kills bank health released when armor regenerates (`perk.ex_president`) |
| Long Odds | Gambler | Ammo pickups heal you and the team (`perk.gambler`) |
| Overlord | Kingpin | Injector throwable: heal 75% of damage taken for 6 s, 30 s cd (`perk.kingpin`) |

Further decks (Hacker: pocket ECM; Leech; Tag Team; Maniac; Biker; Yakuza; Sicario; Copycat) are
P5+ candidates.

---

## C. Structure and "charm"

| # | (a) PD2 | (b) Ours | (c) | P |
|---|---|---|---|---|
| C1 | **CRIME.NET** job map with contractors, difficulty, contract broker (buy any contract with offshore money). | **The Board**: a city map in the safehouse showing rotating contracts from our contacts (Vance, Reyes, The Accountant) with difficulty, payout and "pro job" flags. A broker buys any contract with stash money. | B | P4 (P1: simple heist select) |
| C2 | **Briefing**: contractor voice-over, objectives, map, loot. | Briefing screen with a contact portrait (procedural silhouette art), text plus synthesized VO hook, objectives, blueprint. | B (C portraits) | P2 |
| C3 | **Assets / pre-planning**: buy assets with spending cash (scales with difficulty). Some heists have a blueprint board with favors per day (e.g. 10), location-limited assets, plans by majority vote (host breaks ties), map drawing. | Identical: `HeistDef.preplanning` with favors budget, location `PREPLAN_POINT`s in the map, plan votes, map drawing. Assets grant modifiers (`Modifiers.set_source(TEAM, asset_id, …)`) or spawn things (body bag case, ammo/doctor drop, spawn/loot-drop location choice, escape choice, insider info revealing variant outcomes). | B (UI), A (apply), C (points) | P2 (assets) / P4 (board) |
| C4 | **Difficulty tiers**: Normal → Death Sentence (7), plus One Down. | 6 tiers: Routine, Tense, Hazardous, Brutal, Lethal, Cataclysm, plus a **Last Breath** toggle (One Down). | A, B | P1 (2 tiers) |
| C5 | **Masks**: see P8. Mask-up moment (camera FOV pulse + sound). | `cue.mask_on` + short viewmodel anim. | B, C | P1 |
| C6 | **Payday screen**: time, kills, downs, civilian kills, cash breakdown (contract + loot × crew-alive bonus; 80/20 split), XP breakdown in a fixed order (base, pro, difficulty, custody, additive bonuses, multiplicative stealth bonus), then the card pick. | Identical structure. | B | P1 (cash/XP) / P4 |
| C7 | **Music**: bombastic loud tracks with distinct phase stems (stealth, control, anticipation, assault, fade). | Synthesized in-house (ENV C `tools/audiogen/music/`), driven by `assault_phase_changed` and `heist_phase_changed`. ≥ 3 tracks by P5. | C | P1 (1 track) |
| C8 | **Voice lines**: Bain's dry comms, heister callouts (specials spotted, reloading, "pager!", "cameras down"), contractor briefings. | `voice_line_requested(speaker, line_id, ctx)` hook. Text subtitles plus synthesized voice (C: formant-synth "radio voice" for Mercer; filtered speech-like babble or TTS if a permissively licensed TTS model is vendored; lead decision P3). Line table in `game/content/data/voice/lines.tres` (B writes text; A/C trigger and voice). | B, C, A | P1 (text) / P3 |
| C9 | **Safehouse hub**. | Explorable safehouse: Board, planning table, armory/workshop bench, mask bench, door to the firing range. | B (C art) | P4 |
| C10 | **Escape**: van/boat/heli with a timer or an "escape available" state. Some escapes are a short extra phase. | `escape_zone` activated by mission. Escape variants (type, timing, location) per heist. | A, C | P1 |
