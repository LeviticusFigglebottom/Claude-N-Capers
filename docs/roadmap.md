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
| C1-00 | **Art direction samples** (PO request, D-018): 2 assets × 3 styles, parametric, rendered to docs/art/style_samples/ | C1-01 core |
| C1-01 | Pipeline: `tools/blender/lib` (scene reset, materials M_ naming, bevel/weighted normals, UV, LOD, glTF export, determinism), `build.py`, `tools/texgen` (tileables, trim sheet, ORM packing, LUT), `tools/audiogen` (synth core), Godot glb post-import script, `docs/art/pipeline.md` how-to | — |
| C1-02 | Greybox modular kit (walls/doors/windows/stairs/floors/ceilings on 0.5 m grid) + greybox materials | C1-01 |
| C1-03 | **Glasshouse design doc (G0)** → lead approval → **greybox (G1)** with every contract node, variants table, mission script (on HeistMission when A1-01 lands) | C1-02 |
| C1-04 | `validate_level` + walkthrough + `review_shots` renderer (level_standards §6–§8) + `tools/levelcheck/validate_all.sh` | C1-03 |
| C1-05 | Characters v1: `rig_humanoid`, body generator, Security Officer, Civilian (×4 variants), Patrol Officer, TAC Light, crew body; animation set (P1 subset: idle, walk, run, crouch_*, aim/fire pistol+rifle, reload, death_*, hit_react, cower, hands_up, lie_down, tied, flee, phone_call, radio_call, pager_answer, downed, carry_bag_walk, throw_bag, interact_*) | C1-01 |
| C1-06 | Audio P1 cue set (audio_cues.md P1 rows) + `MusicDirector` + Glasshouse track stems | C1-01 |
| C1-07 | Material library v1 + Glasshouse dressing kits (sales floor, back office, break room, restroom, storage, security office, workshop/vault room, alley) | C1-01 |
| C1-08 | **Glasshouse art pass (G2)** + lighting + review shots | C1-03, C1-07 |

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
4. Mask up → kill a guard with the suppressed pistol (headshot) → `pager_started` within 2–4 s → bot answers (10 s hold) → `pager_answered(total = 1)`.
5. Release a pager early with nobody else answering → alarm (separate seed run).
6. Bag the body → carry → drop in BODY_HIDE → never discovered over 60 s of patrols.
7. Break a display case → small loot taken. Secure 1 loot bag at the van.
8. Fire an unsuppressed shot near a guard → `alarm_raised` → phase LOUD **without scene change** (the same `HeistMap` instance; bodies/bags/doors persist).
9. Assault: the director goes CONTROL → ANTICIPATION → BUILD → SUSTAIN → FADE (Engine.time_scale ×4), enemies spawn out of crew LOS and path toward the crew.
10. The bot goes down → an AI teammate revives within its revive time.
11. Escape with ≥ 1 bag → `heist_ended(success)`; the payout calculator gives contract + loot × difficulty.
