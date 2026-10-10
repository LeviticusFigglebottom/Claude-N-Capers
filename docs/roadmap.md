# Roadmap

Owner: **LEAD**. Each phase ends at a **gate**: an integration test in `game/tests/integration/`
(written by the lead) plus review criteria. A phase is done only when its gate passes on trunk.
Task ids such as `A1-03` are referenced in status files, commits and messages.

## Phase overview

| Phase | Theme | Gate |
|---|---|---|
| **P0** | Foundations (lead) | Repo, docs, contracts, CI, environments live. ✅ when this commit lands |
| **P1** | **Vertical slice**: Glasshouse, 1 guard type, 1 weapon, pagers, bodies, loud transition, 1 assault wave, escape, payday | `test_p1_vertical_slice.gd` + Glasshouse at level gate G2 + lead playthrough notes |
| **P2** | Stealth complete: cameras + operator, ECM, keycards/codes, saws, lasers, cuffs, civilians full, assets; heists Night Deposit + Shadow Ledger (stealth-only) | `test_p2_stealth.gd`: scripted ghost run on 3 seeds per heist; all S-rows of phase ≤ 2 tested |
| **P3** | Loud complete: all specials + captain, director escalation, custody/trade, crowd control, AI teammate orders, factions; co-op loopback; Dockside Burn (loud-only) | `test_p3_loud.gd` (bot crew survives scripted waves; specials' counterplay verified) + `test_coop_loopback.gd` |
| **P4** | Progression: 90 skills, 14 perk decks, armory 36 weapons + workshop, firing range full, hub/safehouse, board, pre-planning board, masks, payday cards, save v2 | `test_p4_progression.gd`: every modifier key ≤ P4 has a behaviour test; resolver golden tests |
| **P5** | Content: Gallery Night, Meridian Federal, Rolling Thunder, Afterhours; music ×3; civilian mode | Each heist passes G3 plus a ghost run and a loud run bot on 5 seeds |
| **P6** | Co-op hardening, drop-in, performance, polish, Notoriety | 4-client soak test, perf budgets in CI |

## P3: Loud complete (ENV A tasks dispatched early, D-038)

| Id | Task | Fidelity rows |
|---|---|---|
| A3-01 | Specials: Phantom, Stinger, Bulwark, Wrecker (staged plates), Longshot, Corpsman, with telegraphs and counterplay | L4.3–L4.8 |
| A3-02 | Commander Brandt + Aegis squad (resistance stacking, retreat, assault lock) | L4.9 |
| A3-03 | Director escalation: drama, stages, factions by difficulty, special spawn caps, between-wave specials | L1.2, L1.3, L1.5, L4.11 |
| A3-04 | Custody / hostage trade / auto-release, police cuffing downed players, shout-surrender + Turncoat converts | L2.8–L2.10, L2.12, L5.1–L5.3 |
| A3-05 | AI teammate orders (follow, hold, carry/drop bag, revive), stealth follow option | L6.1 |
| A3-06 | Suppression, armor/shield/wall piercing, explosives, heavy frontal plates | L3.4–L3.6, L4.2 |
| A3-07 | Co-op hardening: replicate deployables, codes, pre-plan drops and interaction progress; host+client loopback parity | net.md |
| A3-09 | Night Deposit prefabs/systems: `bag_lift`, `hack_terminal`, OUT_OF_BOUNDS zones (respawn at `oob_respawn`), timed mission events (armoured car arrival) via HeistMission timers | QC-11/12/14 |
| A3-08 | Pending follow-ups: A2-08, QB-46..49 (input pause, camera/weapon visual ownership, HUD tracked_crew, gamepad look), D-038 (ECM feedback ungated, cuffed events, fail_reason, PreplanResult apply) | — |

| B4-05 | Payday card pick (1 of 3, 30 s auto-pick, card types) | P9 |
| B4-06 | The Board + contract broker (contacts, rotating contracts, pro jobs) | C1 |
| B4-07 | Safehouse hub UI layer (screens the 3D hub will host) + GSR accent UI theme pass | C9, D-035 |
| B4-09 | Loot `loot.cash_bricks` (MEDIUM, PD2 money-bag value shape) + strings for Night Deposit objectives (from the G0 `[tag]`s) | QC-13 |
| B4-08 | D-038 follow-ups: strings for QA-14, `ui.blocked.*` rename, drop `stealth.ecm_feedback` grants, PreplanResult per preplanning.md (+ `resolve_ids`, points read from the map) | — |

| C2-00 | G0 design docs: Night Deposit and Shadow Ledger (stealth-only) | level_standards §9 |

## P2: Stealth complete (ENV A tasks dispatched early under the utilization policy, D-032)

| Id | Task | Fidelity rows |
|---|---|---|
| A2-01 | Doors on the nav graph: NPC/AI teammates open unlocked doors on their path; guards use keycard doors they're authorised for; nav links toggle with door state | (QA-11) |
| A2-02 | Cameras complete: security room + `camera_station` operator (kill/dominate → all cameras off), operator dispatches a guard to investigate a broken camera, Titan cameras (Lethal+) | S8.1, S8.2 |
| A2-03 | ECM jammer runtime: deploy, chaining, cameras/phones jam, doors/ATM open with skill, feedback stun, pager-delay skill | S8.4–S8.6, S5.6 |
| A2-04 | Keypads + code notes, safes with methods and time locks, saws, laser grids, zipline | S9.4, S9.7, S9.8, S9.10, S9.11 |
| A2-05 | Guard cuff flow (yell, pause, cuff, 4 min cooldown, 60 s self-free), body-shot misfire, marking + Sixth Sense | S3.2, S3.7, S2.9 |
| A2-06 | Deployables runtime: doctor bag, FAK, ammo bag, body bag case, ECM; dodge rolls | L2.11, L2.4, S6.2 |
| A2-08 | Glasshouse feedback from ENV C (D-037): VariantResolver conditional forcing (`force_if`), per-slot `requires`, `min_difficulty` on rare events, per-difficulty scalar weights; window prefab glass sized from the visual's `Glass` AABB; safe KEYCARD method (reader-bound); one-way push-bar door (fire exits); security_camera collision kept in front of its wall-mount pivot | (QC-7) |
| A2-07 | Restrained/hostage stimuli, stealth-only heist mode (alarm = fail), pre-planning asset hooks (spawn choice, asset drops, modifier assets) | S6.4, S11.3, C3 |

| B2-01 | Pre-planning + assets UI: HeistDef.preplanning, favors budget, location choice on the map blueprint, asset purchase, plan vote stub | C3 |
| B2-02 | Briefing screen: contact portrait slot, objectives, loot, escape options | C2 |
| B2-03 | Mask customization data/UI (base shapes from ENV D, colours/patterns/materials) | P8 |

## P1: Vertical slice (detailed)

**Slice definition.** One small heist (**Glasshouse**: jewelry store). One guard type (Security
Officer). Civilians (customers and staff). One weapon (a pistol with suppressor and sight mods).
Casing → mask → stealth with detection, pagers (4 cap), body bags, cable ties, a drill on the back
safe, small loot plus loot bags, keycard variant. Seamless loud transition. One assault wave with
Patrol Officers and TAC Light (CONTROL → ANTICIPATION → BUILD → SUSTAIN → FADE). AI teammates in
loud (follow, fight, revive). Downs/bleedout/revive. Escape van. Payday screen. Difficulty tiers
Routine and Brutal. Solo-first, with every system written authority-correct.

### ENV A: Core Systems & AI
| Id | Task | Depends |
|---|---|---|
| A1-01 | `HeistLauncher` / `HeistRuntime`: load map, seed, `VariantResolver`, services, phase machine (LOADING→CASING→STEALTH→LOUD→ESCAPE→ENDED), `HeistMission` base, **test hooks** (contracts/test_hooks.md) | — |
| A1-02 | Crew: `CrewController` (first-person CharacterBody3D, walk/sprint/crouch/jump, casing restrictions, mask-up), `player_input.gd` → CrewIntent, camera/viewmodel placeholder, net replication skeleton | A1-01 |
| A1-03 | Interaction framework + P1 prefabs: door (none/lockpick/keycard), display_case, small_loot, loot_spawn, keycard_pickup/reader, drill_point (drill + jams + fix), window, secure_zone, escape_zone, body_container, ladder (placeholder visuals with contract node names) | A1-02 |
| A1-04 | Stealth: detection (S2.1–S2.6, S2.8), stimuli core set, NoiseEvent, NPC alert states, alarm (S3.x), phase transition | A1-01 |
| A1-05 | Security Officer AI: patrol generation from PatrolGraph, pauses, investigate, radio alarm, combat, one-shot rule | A1-04 |
| A1-06 | Civilians: idle activities, panic → call/alarm button, intimidate (shout), re-shout timer, cable ties | A1-04 |
| A1-07 | Pagers (S5.2–S5.5 incl. juggling), body bagging, loot bags (carry/weights/throw/secure), small loot | A1-03, A1-05 |
| A1-08 | Combat: weapon runtime from resolved WeaponStats (hitscan, spread, recoil, falloff, headshot, reload, ammo), hit claims, health/armor gating/regen, bleedout/downs/revive | A1-02 |
| A1-09 | `AssaultDirector` single-wave cycle, spawn groups, Patrol Officer + TAC Light AI (nav, cover-lite, shoot, flank-lite) | A1-08 |
| A1-10 | AI teammates (loud): follow nearest human, engage, revive; stealth: wait at van | A1-08 |
| A1-11 | `LocalHudModel` (ui_hud.md) | A1-02.. |
| A1-12 | Modifier hooks for all phase-1 keys + tests | A1-03..08 |

### ENV B: Content & Progression
| Id | Task | Depends |
|---|---|---|
| B1-01 | Data: `weapon.kestrel_p9` pistol + mods (suppressor, reflex sight, extended mag), melee knife, 2 armors (Tailored Suit, Patrol Vest), deployables (doctor bag, ammo bag, body bag case), loot defs (jewelry, cash, body bag), difficulty defs (Routine, Brutal), concealment curve | — |
| B1-02 | `LoadoutResolver` (stats, concealment, DR) + display-stat calculator + golden tests | B1-01 |
| B1-03 | Weapon model scripts for the pistol and its mods (`tools/blender/weapons/`), using ENV C's `tools/blender/lib` once C1-01 lands (until then, a thin local shim that will be deleted) | C1-01 |
| B1-04 | UI: main menu → heist select (difficulty) → loadout screen (simple) → launch; in-heist HUD bound to LocalHudModel (detection chevrons, interaction bar, ammo, health/armor, pager timer, bag, objectives, assault banner, teammates); payday/results screen (cash, XP breakdown) | A1-11 |
| B1-05 | Firing range v1 (`content/range/`): greybox lanes using ENV C greybox kit, distance markers, static targets, damage numbers, live stat panel, loadout swap | C1-02 |
| B1-06 | `SaveService` v1 (profile: cash, stash, xp, level, owned weapons/mods, loadout), migration scaffold | — |
| B1-07 | Strings table + P1 voice-line text (Mercer + crew barks) + payout calculator (S10.4) | — |
| B1-08 | Mask v1: one procedural mask (ENV C mesh request) + mask equip data | — |

### ENV C: Worlds & Art
| Id | Task | Depends |
|---|---|---|
| C1-00 | ✅ DONE (D-035: GSR chosen). **Art direction samples** (PO request, D-018): 2 assets × 3 styles, parametric, rendered to docs/art/style_samples/ | C1-01 core |
| C1-01 | Pipeline: `tools/blender/lib` (scene reset, materials M_ naming, bevel/weighted normals, UV, LOD, glTF export, determinism), `build.py`, `tools/texgen` (tileables, trim sheet, ORM packing, LUT), `tools/audiogen` (synth core), Godot glb post-import script, `docs/art/pipeline.md` how-to | — |
| C1-02 | Greybox modular kit (walls/doors/windows/stairs/floors/ceilings on 0.5 m grid) + greybox materials | C1-01 |
| C1-03 | **Glasshouse design doc (G0)** → lead approval → **greybox (G1)** with every contract node, variants table, mission script (on HeistMission when A1-01 lands) | C1-02 |
| C1-04 | `validate_level` + walkthrough + `review_shots` renderer (level_standards §6–§8) + `tools/levelcheck/validate_all.sh` | C1-03 |
| C1-05 | **→ moved to ENV D (D1-01..D1-03), D-027.** Characters v1: `rig_humanoid`, body generator, Security Officer, Civilian (×4 variants), Patrol Officer, TAC Light, crew body; animation set (P1 subset: idle, walk, run, crouch_*, aim/fire pistol+rifle, reload, death_*, hit_react, cower, hands_up, lie_down, tied, flee, phone_call, radio_call, pager_answer, downed, carry_bag_walk, throw_bag, interact_*) | C1-01 |
| C1-06 | Audio P1 cue set (audio_cues.md P1 rows) + `MusicDirector` + Glasshouse track stems | C1-01 |
| C1-07 | Material library v1 + Glasshouse dressing kits (sales floor, back office, break room, restroom, storage, security office, workshop/vault room, alley) | C1-01 |
| C1-08 | **Glasshouse art pass (G2)** + lighting + review shots | C1-03, C1-07 |

### ENV D: Characters & Art Production (added by D-027; takes over C1-05 and the officer half of C1-00)
| Id | Task | Depends |
|---|---|---|
| D1-00 | Officer renders for the C1-00 style samples (3 styles), from ENV C's sample scripts, in parallel with C's counter renders | C pushes sample scripts |
| D1-01 | `rig_humanoid` + parametric body generator (build/height/age variants, shared skeleton) per characters.md | C1-01 lib |
| D1-02 | Outfits and heads: Security Officer, civilians ×4 variants (customers, sales associate, jeweler, clerk/manager), Patrol Officer, TAC Light, crew body | D1-01 |
| D1-03 | Procedural animation set (the P1 subset listed in C1-05) + first-person arms rig `rig_arms` with the pistol anim set | D1-01 |
| D1-04 | Masks: `mask.gilded_heron` mesh (B1-08) + a mask base-shape generator for later masks | C1-01 lib |
| D1-05 | Character import checks (`game/tests/d/`) + silhouette lineup render | D1-02 |

### LEAD
| Id | Task |
|---|---|
| L1-01 | Write `test_p1_vertical_slice.gd` against test_hooks.md (done in P0 as a skipped/pending test) and keep it updated |
| L1-02 | Review G0/G1/G2 for Glasshouse |
| L1-03 | Integrate env branches; maintain decisions log |

### P1 gate: `game/tests/integration/test_p1_vertical_slice.gd`
1. Launch Glasshouse solo, seed 1001, Routine. Variants resolve; relaunching with the same seed gives an identical resolution. Seed 1002 differs in ≥ 1 group.
2. Casing: a bot unmasked in a PUBLIC zone next to a guard for 5 s → no detection. In a RESTRICTED zone in view → detection > 0.
3. Sprinting and jumping 1 m behind a guard (masked, outside his FOV) → detection stays 0 (no-noise rule).
4. Mask up → kill a guard with the suppressed pistol (launcher default loadout = kestrel_p9 + suppressor, D-025) (headshot) → `pager_started` within 2–4 s → bot answers (10 s hold) → `pager_answered(total = 1)`.
5. Release a pager early with nobody else answering → alarm (separate seed run).
6. Bag the body → carry → drop in BODY_HIDE → never discovered over 60 s of patrols.
7. Break a display case → small loot taken. Secure 1 loot bag at the van.
8. Get spotted masked by a guard (or fire unsuppressed nearby) → `alarm_raised` → phase LOUD **without scene change** (the same `HeistMap` instance; bodies/bags/doors persist).
9. Assault: the director goes CONTROL → ANTICIPATION → BUILD → SUSTAIN → FADE (Engine.time_scale ×4), enemies spawn out of crew LOS and path toward the crew.
10. The bot goes down → an AI teammate revives within its revive time.
11. Escape with ≥ 1 bag → `heist_ended(success)`; the payout calculator gives contract + loot × difficulty.
