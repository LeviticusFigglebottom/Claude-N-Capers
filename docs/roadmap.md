# Roadmap

Owner: **LEAD**. Each phase ends at a **gate**: an integration test in `game/tests/integration/`
(written by the lead) plus review criteria. A phase is done only when its gate passes on trunk.
Task ids such as `A1-03` are referenced in status files, commits and messages.

## Phase overview

| Phase | Theme | Gate |
|---|---|---|
| **P0** | Foundations (lead) | Repo, docs, contracts, CI, environments live. ✅ when this commit lands |
| **P1** ✅ | **Vertical slice**: Glasshouse, 1 guard type, 1 weapon, pagers, bodies, loud transition, 1 assault wave, escape, payday | `test_p1_vertical_slice.gd` + Glasshouse at level gate G2 + lead playthrough notes |
| **P2** | Stealth complete: cameras + operator, ECM, keycards/codes, saws, lasers, cuffs, civilians full, assets; heists Night Deposit + Shadow Ledger (stealth-only) | `test_p2_stealth.gd`: scripted ghost run on 3 seeds per heist; all S-rows of phase ≤ 2 tested |
| **P3** | Loud complete: all specials + captain, director escalation, custody/trade, crowd control, AI teammate orders, factions; co-op loopback; Dockside Burn (loud-only) | `test_p3_loud.gd` (bot crew survives scripted waves; specials' counterplay verified) + `test_coop_loopback.gd` |
| **P4** | Progression: 90 skills, 14 perk decks, armory 36 weapons + workshop, firing range full, hub/safehouse, board, pre-planning board, masks, payday cards, save v2 | `test_p4_progression.gd`: every modifier key ≤ P4 has a behaviour test; resolver golden tests |
| **P5** | Content: Gallery Night, Ostrander Federal, Rolling Thunder, Afterhours; music ×3; civilian mode | Each heist passes G3 plus a ghost run and a loud run bot on 5 seeds |
| **P6** | Co-op hardening, drop-in, performance, polish, Notoriety | 4-client soak test, perf budgets in CI |

## P3: Loud complete (ENV A tasks dispatched early, D-038)

| Id | Task | Fidelity rows |
|---|---|---|
| A3-01 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Specials: Phantom, Stinger, Bulwark, Wrecker (staged plates), Longshot, Corpsman, with telegraphs and counterplay | L4.3–L4.8 |
| A3-02 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Commander Brandt + Aegis squad (resistance stacking, retreat, assault lock) | L4.9 |
| A3-03 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Director escalation: drama, stages, factions by difficulty, special spawn caps, between-wave specials | L1.2, L1.3, L1.5, L4.11 |
| A3-04 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Custody / hostage trade / auto-release, police cuffing downed players, shout-surrender + Turncoat converts | L2.8–L2.10, L2.12, L5.1–L5.3 |
| A3-05 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). AI teammate orders (follow, hold, carry/drop bag, revive), stealth follow option | L6.1 |
| A3-06 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Suppression, armor/shield/wall piercing, explosives, heavy frontal plates | L3.4–L3.6, L4.2 |
| A3-07 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Co-op hardening: replicate deployables, codes, pre-plan drops and interaction progress; host+client loopback parity | net.md |
| A3-09 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Night Deposit prefabs/systems: `bag_lift`, `hack_terminal`, OUT_OF_BOUNDS zones (respawn at `oob_respawn`), timed mission events (armoured car arrival) via HeistMission timers | QC-11/12/14 |
| A3-10 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Shadow Ledger needs: per-difficulty weights for slot-group rules (QC-18; Night Deposit too), escape_type heli/zipline/lift with `arrival_delay_s`, `bag_only` (QC-19), no ladder climbing with a bag (QC-17) | D-042 |
| A3-08 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Pending follow-ups: A2-08, QB-46..49 (input pause, camera/weapon visual ownership, HUD tracked_crew, gamepad look), D-038 (ECM feedback ungated, cuffed events, fail_reason, PreplanResult apply) | — |

| B4-05 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Payday card pick (1 of 3, 30 s auto-pick, card types) | P9 |
| B4-06 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). The Board + contract broker (contacts, rotating contracts, pro jobs) | C1 |
| B4-07 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Safehouse hub UI layer (screens the 3D hub will host) + GSR accent UI theme pass | C9, D-035 |
| B4-09 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Loot `loot.cash_bricks` (MEDIUM, PD2 money-bag value shape) + strings for Night Deposit objectives (from the G0 `[tag]`s) | QC-13 |
| B4-10 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Shadow Ledger data: loot `loot.ledger_laptop` (LIGHT), `loot.ledger_drives` (MEDIUM), `loot.ledger_books` (MEDIUM), `loot.painting` (LIGHT, PD2 painting shape; was MEDIUM); preplan library assets `asset.intel_laptop`, `asset.gondola_left_hung`, `asset.riser_panel`; objective strings from the G0 `[tag]`s | QC-15/16 |
| B4-08 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). D-038 follow-ups: strings for QA-14, `ui.blocked.*` rename, drop `stealth.ecm_feedback` grants, PreplanResult per preplanning.md (+ `resolve_ids`, points read from the map) | — |
| B4-11 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Co-op lobby UI on the Net API: host/join (IP + loopback), 4 crew slots incl. AI fill, ready states, loadout/mask summary per slot, plan vote + Board contract over `Net.lobby_send`; host's contract is the lobby's job (QB-BRD2) | P3 gate test_coop_loopback, net.md |
| B4-12 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Armory batch 2 toward 36 weapons: 10 weapons across AR, SMG, LMG, sniper, second shotgun, akimbo pistol pair, revolver, with mods + model scripts (ENV D FP sets follow) | P4 armory |
| B4-13 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Firing range full: moving targets, armoured dummies (body armor, shield, Wrecker plate) for A3-06 piercing, damage-falloff graph, DPS readout | P4 range |
| B4-14 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Perk decks complete: every card's modifier keys wired and behaviour-tested with ENV A hooks (P4 gate "every modifier key ≤ P4 has a behaviour test"); report missing hooks as QB | P4 |
| B4-15 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Masks batch: +12 base shapes requested from ENV D, +16 patterns, +10 materials; mask unlock sources (payday cards, achievements stub) | P8 |
| B4-16 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Save v2 + v1→v2 migration (armory batch 2, masks/unlocks, payday cards, Board locks, perk/skill progress), golden migration tests, corrupt-file fallback | P4 gate |
| B4-17 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Workshop 3D orbit view: live mod swap, attach-marker previews, stat diff, gamepad orbit | P4 workshop |
| B4-18 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Armory batch 3: last 16 weapons to 36 (incl. special weapons), mods, models; list to lead early for ENV D FP sets | P4 armory |
| B4-19 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Stamina HUD widget (ui_hud v1.4) | QB-60 |
| B4-20 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Achievements stub: data-driven conditions, MaskLocker.grant_unlock, small screen | P8 |
| B5-01 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Options menu: key/pad rebinding (all InputMap actions incl. look_*), audio buses (Master/Music/SFX/Voice/Ambience), video (resolution, vsync, FOV 60–110, quality presets), gameplay (hold vs toggle for ADS/crouch/interact), accessibility (colour-blind-safe detection/HUD palettes, subtitle size); persisted in the profile | P6 polish (pulled forward) |
| B5-02 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Notoriety ranks (PD2 infamy analog): at level 100 reset to 0 for a rank (I–XXV), rank XP bonus, rank-gated cosmetic unlocks (masks/patterns/materials), skill-point refund on rank-up; save v6 + migration; rank UI in the hub | P6 |
| B5-03 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Music selection: per-heist track choice in pre-planning/lobby (host decides), hub jukebox; data-driven track list (ENV C supplies the stems) | P5 music |
| B5-04 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Dockside Burn content data (P3 loud-only heist): HeistDef skeleton, contract/briefing/strings, loot defs; objective ids from ENV C's G0 `[tag]`s once its design doc lands | P3 gate |
| B5-05 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Civilian-mode UI (S1.3): HUD civilian state, gear-pickup prompt, briefing flag display (ENV A owns `start_mode = civilian` + the gear prefab) | P5 |
| B6-01 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). P5 loot + contract catalogue: PD2-shaped LootDefs the P5 heists need (gold HEAVY, money MEDIUM, coke LIGHT, painting variants, bearer bonds LIGHT, server drives MEDIUM, deposit-box valuables), values/weights per pd2_fidelity S10; Board contract stubs for gallery_night / ostrander_federal / rolling_thunder / afterhours hidden until a HeistDef ships | P5 |
| B6-02 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Heist stats: Tab scoreboard overlay (per crew: kills, specials, civilians, downs, accuracy, headshots) over HeistRuntime crew stats + end-of-heist awards on payday (PD2 "best of" lines); missing counters (shots/hits/headshots) → QB to ENV A | P6 |
| B6-03 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Chat: lobby + in-heist text chat UI (open/close key, history, fade), over `Net.lobby_send` in the lobby; in-heist transport → QB to ENV A if absent | P6 |
| B6-04 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Drop-in + kick UI: host join-request dialog (accept/deny, PD2 drop-in), joining player's loadout pick + "joining" progress, host kick menu; on mocks until ENV A's drop-in lands | P6 |
| B6-05 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Lobby codes (game_overview §9): short shareable code ⇄ address:port (no service), join-by-code field in the lobby; LAN host list if A exposes discovery | P6 |
| B6-06 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). 3D hub mode (QC-45..49): MenuFlow loads the safehouse from data, connects `station_requested`, pauses while a screen is open, returns to the station marker, 2D hub fallback + walk/menu toggle; `notoriety` and `crew` station ids; `ui.prompt.station.<id>`; minimal hub HUD + pause menu with a quick-stations list; jukebox previews through the safehouse jukebox | C4-01 |
| B6-07 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Heister choice (D-073): `Loadout.heister` picker, unique per lobby (first come keeps it, conflicts fall back to the next free heister), every launch slot gets a distinct heister | D-073 |
| B6-08 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Throwable data (D-073): `throwable.frag` / `concussion` / `incendiary` / `throwing_knife` ThrowableDefs for A3-12 + picker | A3-12 |
| B7-01 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Career stats + profile screen: lifetime counters from HeistResult (heists by difficulty, stealth/loud, kills, specials, accuracy, downs, cash), per-heist best times, favourite weapon; save v7 + migration | P6 |
| B7-02 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Achievements expansion: 8 → ~40 PD2-style data-driven achievements (heist/difficulty/stealth/weapon/special/crew feats) with mask/material/colour unlocks | P8 |
| B7-03 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Contact radio (PD2 "Bain" analog): data-driven contact lines keyed by mission facts (objective_updated, alarm, assault phases, escape, loot secured), subtitle overlay (accessibility subtitle size), `vo.<contact>.<line>` keys; lines for the 4 existing heists | P5 charm |
| B7-04 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Weapon finishes: earned cosmetic finishes (colour/material/pattern) from payday cards and achievements, applied through WeaponVisual material overrides; workshop preview | P8 |

| C2-00 | G0 design docs: Night Deposit and Shadow Ledger (stealth-only) | level_standards §9 |
| C4-01 | 3D safehouse hub (fidelity C9): explorable safehouse whose stations are interactables calling `MenuFlow.open_station` (Board, planning table, armory/workshop bench, mask bench, jukebox, Notoriety, firing-range door); B's 2D hub stays as the menu fallback | P4 hub |
| C4-02 | Safehouse greybox (G1) per docs/design/heists/safehouse.md: SafehouseMap root, 8 stations, validate_level `--profile=hub` | C4-01 |
| C4-03 | Safehouse art pass (G2/G3) + review shots; dedicated safehouse music track (C5 backlog) | C4-02 |
| A3-12 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Player melee (L3.9, P2 gap): CrewMelee from Loadout.melee (MeleeDef timings, charge, knockdown), gun bash, silent stealth kills, server-validated hit; then CrewThrowables (frag / concussion / incendiary by ThrowableDef.kind, pin_pull / release) with the D-069 FP sets | L3.9, D-069 |
| A3-13 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Enemy close-range melee (PD2 point-blank shove/strike on crew; drives `defense.melee_counter` and `defense.melee_damage_taken_mult`) | L3.9, L2 |
| A4-01 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Fidelity audit: every pd2_fidelity row owned by ENV A with phase ≤ P5 → test coverage table (row, test, status); implement any row found missing (as L3.9 melee was) | all A rows |
| A4-02 | ✅ DONE (26509c96 + 2ceafc4d, env_a.md -35/-47; test_a4_02_dockside_perf). Performance: frame/physics/AI/net budgets instrumented (Perf monitors + a headless perf scene: Dockside, 4 crew, enemy cap reached), CI perf test with thresholds; fix the worst offenders | P6 gate |
| A4-03 | ✅ DONE (env_a.md -37). 4-client soak harness: host + 3 loopback clients with bot crew for a long loud run; checks desync (state hashes), memory growth, error log; feeds the lead's P6 gate | P6 gate |
| A4-04 | ✅ DONE (A audit, env_a.md -48). Hook the modifier keys that do nothing: the lead's P4 gate (test_p4_progression.gd) found 69 keys ≤ P4 with no runtime hook (mostly the D-031 skill keys, e.g. weapon.fire_rate_mult, weapon.ads_speed_mult, defense.swan_song, interaction.speed_mult) and 31 hooked keys with no behaviour test. Hook each one and add a behaviour test, then shrink the gate's allowlist. Hooks in ENV P's files (player/viewmodel, e.g. ADS speed, movement) go through ENV P. Next after A4-01 (D-076 playability) | P4 gate |
| A5-01 | ✅ DONE (A audit, env_a.md -48). `armored_truck` prefab (Rolling Thunder QC-80): vehicle-shaped LARGE safe — saw target, `charges_required`, lockdown state (saw ×1.5), roof-hatch thermite | P5 rolling_thunder |
| A5-02 | ✅ DONE (A audit, env_a.md -48). `convoy_vehicle` mover (QC-82): path-following vehicles with stop/crash states, escort cars, replicated | P5 rolling_thunder |
| A5-03 | ✅ DONE (A audit, env_a.md -48). C4 item + shaped charges (QC-84 / S9.5): carried charge count, `charges_required` doors/safes/trucks, placement interaction, detonation | S9.5, P5 |
| D3-01 | P5 cast (casting per heist; reuse bodies/outfits via variants): Gallery Night (curator, gallery attendants, guards, patrons in evening wear), Ostrander Federal (tellers, bank manager, bank guards, customers), Rolling Thunder (armoured-car crew, convoy escort), Afterhours (bouncers, bartenders, DJ, club patrons); names/roles from ENV C's G0 docs as they land | P5 |
| D3-02 | P5 NPC ambient animations: club dance loops ×3, bartender wipe/pour, bouncer arms-crossed idle, teller counting at a counter, curator inspecting a painting, walking-while-texting, seated/standing cower variants | P5 |
| D3-03 | Mask bases batch 3: +12 original base shapes through `_mask_base` (face-envelope fit), for ENV B's unlock sources (payday cards, Notoriety, achievements) | P8 |
| D3-04 | Animation polish: crew locomotion blend set (start/stop, strafe 8-way), hit-react and death variety (×3 each), downed crawl, a heavy (Wrecker) gait | P6 polish |
| D4-01 | Character LODs for performance (A4-02): 3 LOD levels per body/outfit (≈ 100 / 45 / 15 %), visibility ranges, crowd-friendly lowest LOD (Afterhours, Gallery Night gala) | A4-02, P5 |
| D4-02 | Crowd variety: +8 civilian outfits/variants for P5 crowds (club patrons, gala guests, bank customers, commuters), mix-and-match tops/bottoms/hair/colour so no two neighbours match | P5 |
| D4-03 | Four more heisters (8 total, PD2 grew its roster): bodies, outfits, faces, FP sleeves, portraits, masks-fit envelope regen; ids to ENV B for the picker | P6 |
| A3-11 | ✅ DONE (A4-01 audit, docs/status/env_a_fidelity.md). Hub support (QC-43/44): crew spawn + interaction without a HeistRuntime (civilian mode, HUD prompt), `hub_station` prefab emitting `station_requested(id)` | C4-01 |
| C5-01 | Music stems: night_deposit, shadow_ledger, dockside_burn heist tracks now (unlockables vault_hymn / long_con / last_call point at those stems meanwhile); the 3 unlockables get their own stems as P5 "music ×3" | P5 music |

## P2: Stealth complete (ENV A tasks dispatched early under the utilization policy, D-032)

| Id | Task | Fidelity rows |
|---|---|---|
| A2-01 | ✅ DONE (A audit, env_a.md -48). Doors on the nav graph: NPC/AI teammates open unlocked doors on their path; guards use keycard doors they're authorised for; nav links toggle with door state | (QA-11) |
| A2-02 | ✅ DONE (A audit, env_a.md -48). Cameras complete: security room + `camera_station` operator (kill/dominate → all cameras off), operator dispatches a guard to investigate a broken camera, Titan cameras (Lethal+) | S8.1, S8.2 |
| A2-03 | GAP: S8.5 ATM-by-ECM only (A fixing, env_a.md -48). ECM jammer runtime: deploy, chaining, cameras/phones jam, doors/ATM open with skill, feedback stun, pager-delay skill | S8.4–S8.6, S5.6 |
| A2-04 | ✅ DONE (A audit, env_a.md -48). Keypads + code notes, safes with methods and time locks, saws, laser grids, zipline | S9.4, S9.7, S9.8, S9.10, S9.11 |
| A2-05 | ✅ DONE (A audit, env_a.md -48). Guard cuff flow (yell, pause, cuff, 4 min cooldown, 60 s self-free), body-shot misfire, marking + Sixth Sense | S3.2, S3.7, S2.9 |
| A2-06 | ✅ DONE (A audit, env_a.md -48). Deployables runtime: doctor bag, FAK, ammo bag, body bag case, ECM; dodge rolls | L2.11, L2.4, S6.2 |
| A2-08 | ✅ DONE (A audit, env_a.md -48). Glasshouse feedback from ENV C (D-037): VariantResolver conditional forcing (`force_if`), per-slot `requires`, `min_difficulty` on rare events, per-difficulty scalar weights; window prefab glass sized from the visual's `Glass` AABB; safe KEYCARD method (reader-bound); one-way push-bar door (fire exits); security_camera collision kept in front of its wall-mount pivot | (QC-7) |
| A2-07 | ✅ DONE (A audit, env_a.md -48). Restrained/hostage stimuli, stealth-only heist mode (alarm = fail), pre-planning asset hooks (spawn choice, asset drops, modifier assets) | S6.4, S11.3, C3 |

| B2-01 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Pre-planning + assets UI: HeistDef.preplanning, favors budget, location choice on the map blueprint, asset purchase, plan vote stub | C3 |
| B2-02 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Briefing screen: contact portrait slot, objectives, loot, escape options | C2 |
| B2-03 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Mask customization data/UI (base shapes from ENV D, colours/patterns/materials) | P8 |

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
| A1-01 | ✅ DONE (A audit, env_a.md -48). `HeistLauncher` / `HeistRuntime`: load map, seed, `VariantResolver`, services, phase machine (LOADING→CASING→STEALTH→LOUD→ESCAPE→ENDED), `HeistMission` base, **test hooks** (contracts/test_hooks.md) | — |
| A1-02 | ✅ DONE (A audit, env_a.md -48). Crew: `CrewController` (first-person CharacterBody3D, walk/sprint/crouch/jump, casing restrictions, mask-up), `player_input.gd` → CrewIntent, camera/viewmodel placeholder, net replication skeleton | A1-01 |
| A1-03 | ✅ DONE (A audit, env_a.md -48). Interaction framework + P1 prefabs: door (none/lockpick/keycard), display_case, small_loot, loot_spawn, keycard_pickup/reader, drill_point (drill + jams + fix), window, secure_zone, escape_zone, body_container, ladder (placeholder visuals with contract node names) | A1-02 |
| A1-04 | ✅ DONE (A audit, env_a.md -48). Stealth: detection (S2.1–S2.6, S2.8), stimuli core set, NoiseEvent, NPC alert states, alarm (S3.x), phase transition | A1-01 |
| A1-05 | ✅ DONE (A audit, env_a.md -48). Security Officer AI: patrol generation from PatrolGraph, pauses, investigate, radio alarm, combat, one-shot rule | A1-04 |
| A1-06 | ✅ DONE (A audit, env_a.md -48). Civilians: idle activities, panic → call/alarm button, intimidate (shout), re-shout timer, cable ties | A1-04 |
| A1-07 | ✅ DONE (A audit, env_a.md -48). Pagers (S5.2–S5.5 incl. juggling), body bagging, loot bags (carry/weights/throw/secure), small loot | A1-03, A1-05 |
| A1-08 | ✅ DONE (A audit, env_a.md -48). Combat: weapon runtime from resolved WeaponStats (hitscan, spread, recoil, falloff, headshot, reload, ammo), hit claims, health/armor gating/regen, bleedout/downs/revive | A1-02 |
| A1-09 | ✅ DONE (A audit, env_a.md -48). `AssaultDirector` single-wave cycle, spawn groups, Patrol Officer + TAC Light AI (nav, cover-lite, shoot, flank-lite) | A1-08 |
| A1-10 | ✅ DONE (A audit, env_a.md -48). AI teammates (loud): follow nearest human, engage, revive; stealth: wait at van | A1-08 |
| A1-11 | ✅ DONE (A audit, env_a.md -48). `LocalHudModel` (ui_hud.md) | A1-02.. |
| A1-12 | ✅ DONE (A audit, env_a.md -48). Modifier hooks for all phase-1 keys + tests | A1-03..08 |

### ENV B: Content & Progression
| Id | Task | Depends |
|---|---|---|
| B1-01 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Data: `weapon.kestrel_p9` pistol + mods (suppressor, reflex sight, extended mag), melee knife, 2 armors (Tailored Suit, Patrol Vest), deployables (doctor bag, ammo bag, body bag case), loot defs (jewelry, cash, body bag), difficulty defs (Routine, Brutal), concealment curve | — |
| B1-02 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). `LoadoutResolver` (stats, concealment, DR) + display-stat calculator + golden tests | B1-01 |
| B1-03 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Weapon model scripts for the pistol and its mods (`tools/blender/weapons/`), using ENV C's `tools/blender/lib` once C1-01 lands (until then, a thin local shim that will be deleted) | C1-01 |
| B1-04 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). UI: main menu → heist select (difficulty) → loadout screen (simple) → launch; in-heist HUD bound to LocalHudModel (detection chevrons, interaction bar, ammo, health/armor, pager timer, bag, objectives, assault banner, teammates); payday/results screen (cash, XP breakdown) | A1-11 |
| B1-05 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Firing range v1 (`content/range/`): greybox lanes using ENV C greybox kit, distance markers, static targets, damage numbers, live stat panel, loadout swap | C1-02 |
| B1-06 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). `SaveService` v1 (profile: cash, stash, xp, level, owned weapons/mods, loadout), migration scaffold | — |
| B1-07 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Strings table + P1 voice-line text (Mercer + crew barks) + payout calculator (S10.4) | — |
| B1-08 | ✅ DONE (B audit c2ebc7a0, docs/status/env_b.md). Mask v1: one procedural mask (ENV C mesh request) + mask equip data | — |

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
11. Escape with the mission's required bags (Glasshouse: 2) → `heist_ended(success)`; the payout calculator gives contract + loot × difficulty.
