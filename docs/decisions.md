# Decision log

Append-only. Newest at the bottom. Format: `## D-NNN — YYYY-MM-DD — title`, then decision, rationale, and affected parties.
Only the lead writes here. Environments cite decisions by id.

## D-001 — 2026-10-10 — Engine: Godot 4.7.2-stable, GDScript (typed), Jolt physics, Forward+
The latest stable release (product owner direction). Pinned in `tools/setup/godot_version.txt`. C# and GDExtension are allowed only with a decision entry backed by profiling. Affects: all.

## D-002 — 2026-10-10 — Server-authoritative from day one; solo = OfflineMultiplayerPeer host
Every gameplay system runs the host code path, solo included. AI teammates take crew slots with peer_id 0. Clients predict their own movement and send hit claims for their own shots; everything else is server-only. See architecture.md §3. Affects: A (all systems), B (lobby UI uses only the Net API).

## D-003 — 2026-10-10 — Environments = three separate Claude Code cloud sessions on branches env/a-core, env/b-content, env/c-worlds; trunk = claude/dreamy-hamilton-pc7vck
Directory ownership is enforced by `tools/ci/owners.json` + `check_ownership.py`. Envs merge trunk in (never rebase) and push only their own branch. The lead reviews and merges. See docs/process/communication.md. The product owner may later rename trunk to `main`; only owners.json and ci.yml would change.

## D-004 — 2026-10-10 — Modifier-key system for all skills, perks, assets and difficulty
This is PD2's `upgrade_value` pattern. ENV B only grants registry keys; ENV A implements a hook per key. See contracts/modifiers.md.

## D-005 — 2026-10-10 — Gameplay prefab + visual slot composition
ENV A owns logic prefabs with placeholder visuals. ENV C/B supply visual scenes with contract-named nodes, and ENV C places prefabs in maps. See contracts/gameplay_prefabs.md and visual_slots.md.

## D-006 — 2026-10-10 — Named RNG streams; global randi/randf banned in gameplay code
Enforced by `check_banned.py`. The variant resolver is the only roller of heist variables (ENV A).

## D-007 — 2026-10-10 — Units: PD2 display units for health/armor/damage (player 230 HP)
This keeps PD2 reference numbers transferable 1:1. Unverified PD2 values are marked ◇ in pd2_fidelity.md and tuned by the lead.

## D-008 — 2026-10-10 — Ownership of weapon models: ENV B scripts under tools/blender/weapons, built on ENV C's tools/blender/lib
This means one pipeline and one style while the armory stays with its owner. ENV B may use a temporary shim until C1-01 lands, then must delete it.

## D-009 — 2026-10-10 — HUD: ENV A exposes LocalHudModel; ENV B owns all UI scenes including HUD
One UI owner gives one UI style. See contracts/ui_hud.md.

## D-010 — 2026-10-10 — Enemy tweak data (EnemyDef) owned by ENV A
Enemy balance is coupled to AI behaviour. ENV B reads it (firing-range dummies).

## D-011 — 2026-10-10 — Generated binaries (glb/png/ogg) are committed, not git-LFS
Reproducibility comes from the scripts. Budgets (style guide §4–5) keep the repo small. LFS will be revisited if the repo exceeds 1.5 GB.

## D-012 — 2026-10-10 — Art direction: "Grounded Stylized Realism" (provisional, awaiting product owner)
Options (A) GSR, (B) Neo-noir graphic, (C) Gritty photoreal have been presented to the product owner. Until they answer, ENV C works greybox-first and builds pipeline and material tooling that is direction-agnostic.

## D-013 — 2026-10-10 — Custom lightweight test runner instead of GUT
This avoids version-compat risk with Godot 4.7. See game/tests/framework.

## D-014 — 2026-10-10 — AI teammates in stealth wait at the van (undetectable) unless ordered to follow (P4 option)
This deviates from PD2, where bots don't exist in stealth. It is more useful for solo play and still never forces AI into stealth play. Affects: A.

## D-015 — 2026-10-10 — Captain (Commander Brandt) also appears in solo
PD2 restricts the captain to online lobbies. Our solo is first-class.

## D-016 — 2026-10-10 — Fleeing civilians can be shouted down with a 50% roll (◇)
PD2's wiki calls panicked civilians unpacifiable, but common play shouts them down before they reach a phone. To be revisited in P2 playtest.

## D-017 — 2026-10-10 — Environments launched; P1 dispatched
ENV A `session_016DAFQRw44j8Tz7NA7mCGJw`, ENV B `session_01UY8DitCKjvthQK7cYwvcja`, ENV C `session_01V39kctNgrNn7iYUNoTEiNF`. Each received its P1 task list (roadmap.md) with milestones M1–M3. Lead loop: read status files and messages, answer questions in this log or in contracts, review, merge, dispatch.

## D-018 — 2026-10-10 — Art direction decision deferred to style samples (task C1-00)
The product owner asked to see example assets first. ENV C produces the same 2 assets (a jewelry display counter and a Security Officer) in all 3 candidate styles, from one parametric script per asset, rendered in Blender. Output goes to `docs/art/style_samples/`. The lead reviews and presents them to the product owner, who then decides D-012. C1-00 takes priority over Glasshouse G0.

## D-019 — 2026-10-10 — MaskDef lives in contracts (answers QB-1)
ENV A attaches the mask model to crew characters, so the schema is cross-env: `game/contracts/data/mask_def.gd`. ENV B owns the data and ENV C the meshes.

## D-020 — 2026-10-10 — Economy multipliers are applied only by ENV B (answers QB-2)
`HeistResult.contract_pay` is the unscaled `HeistDef.base_payout`. ENV B's payout calculator is the single place that applies difficulty, crew-alive, stealth and other multipliers. ENV A reports only raw facts and values.

## D-021 — 2026-10-10 — Strings use Godot's standard CSV translation import, registered in project.godot by the lead (answers QB-3)
ENV B writes `game/content/data/strings/strings.csv` (`keys,en`) with the default importer. The lead adds the `.translation` to project.godot at first merge. No runtime registration.

## D-022 — 2026-10-10 — Answers to QB-4..QB-13 (ENV B, B-M1 merged at bd61e14)
- QB-4: strings.en.translation is registered in project.godot.
- QB-5: `WeaponStats.make_delta()` added. Every mod delta must start from it.
- QB-6: key `stealth.concealment_add` (ADD, P4, qualifier melee/armor/primary/secondary/all) added.
- QB-7: `ArmorDef.unlock_skill` added.
- QB-8: `ammo_pickup_min/max` are rounds per pickup (documented in the schema).
- QB-9: canonical enemy ids are in groups.md. All Wrecker variants share the `enemy.wrecker` limit.
- QB-10: `cue.weapon_<anim_set>_fire(_suppressed)` is the contract pattern (audio_cues.md). ENV C is asked for the pistol pair.
- QB-11: an empty slot counts as concealment 30 **for P1 only**. From P4 a loadout needs a primary and a secondary (PD2 rule) and the resolver rejects empty weapon slots.
- QB-12: the `crew_slot` parameter and `gross` field are accepted.
- QB-13: the civilian penalty comes from spending cash and also applies on failure (accepted). **Stealth bonus: overruled.** Per S11.1 it is stored in the profile and applied to the *next* payday (PD2). AI teammates count toward the crew-alive bonus (accepted; solo is first-class).

## D-023 — 2026-10-10 — Glasshouse G0 APPROVED with required changes; ENV C tooling answers (QC-1..QC-5)
- G0 approved (review notes in the lead's message to ENV C). Required changes go into the doc before G1 sign-off: fixed staff roster; security console placement; drill-in-stealth intent stated; play-space closure list.
- QC-1: `noise` removed from tools/requirements.txt (doesn't build on Python 3.13). Texgen keeps its own numpy noise.
- QC-2: `tools/setup/install_render_deps.sh` (lavapipe + xvfb) runs from session_start. Review shots use Vulkan Forward+ under xvfb.
- QC-3: `docs/art/pipeline.md` and `docs/art/style_samples/**` are now ENV C-owned (owners.json).
- QC-4: the default bus layout is registered in project.godot when ENV C's `default_bus_layout.tres` first merges.
- QC-5: Glasshouse base_payout is $40,000 (unscaled; ENV B's calculator scales it). HeistDef data stays ENV C's file; economy changes go through the lead.

## D-024 — 2026-10-10 — App flow, HUD discovery, heist discovery (answers QB-14..19); merges of C1-01/C1-02 and B1-04
- Merged env/c-worlds (C1-01 Blender pipeline with deterministic builds, C1-02 greybox kit, G0 revisions) and env/b-content (B1-04 UI, D-022 follow-ups). Trunk check_all: PASS, 121 tests.
- QB-14/16: ENV B's app shell owns the application flow: launch, HUD/payday spawn, teardown + Net.leave after results. `core/boot.gd` now routes to `res://content/ui/menus/menu_flow.tscn`, which must handle `--heist/--seed/--difficulty` direct launch. ENV A never instantiates UI.
- QB-15: group `G.LOCAL_HUD_MODEL`; ENV A's LocalHudModel joins it. The exact binding shape is in ui_hud.md v1.1.
- QB-17: "coming soon" buttons for Firing Range and Settings in P1: OK. The Range unlocks with B1-05.
- QB-18: ui_hud.md fixed (strings.csv).
- QB-19: no hard paths into world/. Use the lead's `HeistRegistry` (core) to discover heists by the `<id>/<id>_def.tres` convention. The placeholder fallback may stay until Glasshouse's def lands.

## D-025 — 2026-10-10 — A-M1 merged; answers QA-1..QA-8
- Merged env/a-core A-M1 (heist runtime + test hooks, crew controller, 21 prefab shapes, LocalHudModel, dev sandbox). Trunk check_all PASS, 154 tests.
- QA-1: the launcher finds maps via core `HeistRegistry.map_scene_path(id)` (HeistDef.map_scene, else convention). No C-owned catalog is needed.
- QA-2: the launcher's default loadout (when no `loadouts` option is given) is `weapon.kestrel_p9` + suppressor via LoadoutResolver. Gate steps 4/8 were reworded.
- QA-3: requires/excludes semantics are specified in heist_map.md v1.1.
- QA-4: InputMap actions are now in project.godot (keyboard/mouse + gamepad), generated by `tools/ci/set_project_settings.gd`. F is both interact (hold) and shout (tap), contextual as in PD2. G is mask-up / throw / drop bag, contextual. Remove the runtime registration.
- QA-5: the casing "too close" rule does not apply inside PUBLIC zones (pd2_fidelity S1.1 updated).
- QA-6: the check_banned.py `*input*` exemption bug is fixed. Revert the Engine.get_singleton workaround.
- QA-7: nav cell size/height 0.1 (project defaults), NPC agent radius 0.3 m. 0.05 is too costly for full heists. Rebake the sandbox at 0.1.
- QA-8: the UsePoint convention is confirmed and written into heist_map.md.

## D-026 — 2026-10-10 — Damage contract; answers QB-20..27; StringName sort rule
- New contract `docs/contracts/damage.md` + `Damage` helper. There is a single hit path: the attacker calls `target.take_hit(info, attacker)` once, and the target applies zone, armor and resistance and emits `damage_applied` itself (QB-27).
- QB-26: the target's zone multiplier (EnemyDef) is canonical. `WeaponStats.headshot_mult` is now a weapon headshot *bonus*, default 1.0 (schema default changed). ENV B must set the P9 to 1.0.
- QB-20: types are written into ui_hud.md. QB-22: viewmodel conventions are accepted into visual_slots.md (origin, Slide +Z, optional AimPoint, mod-owned Muzzle wins), and the Stock<ModType> naming is in data_schemas.md. QB-24: `G.RANGE_TARGET` added.
- QB-25: ENV A implements `CrewController.spawn_for_range(parent, xform, loadout) -> Node` + `set_loadout(loadout)` (standalone crew member with weapon runtime, no HeistRuntime) in A-M3.
- QB-21/QB-23: ENV C adds the 9 weapon M_ materials (emissive/transparent library ids are fine) and the pistol reload cues `cue.weapon_pistol_mag_out|mag_in|slide_release`.
- Rule: StringName `<` compares pointers. Sorting StringName arrays is non-deterministic across load orders (it broke `test_catalog_uses_registry_defs` on the merged tree). Sort by String. HeistRegistry is fixed. B must fix HeistCatalog and LoadoutResolver skill-id ordering.

## D-027 — 2026-10-10 — Utilization policy; ENV D (Characters & Art Production) created; B pulls P4 forward
- Product owner directive: no environment idles or leaves capacity unused. The policy is in communication.md §7.
- ENV D session: `session_016Esc7YANZPKv4jDCqWdvQ8`.
- ENV C was the bottleneck: C1-00 samples, C1-05 characters, G1, C1-07/08, materials and the mask mesh were all queued on it. **ENV D** is created with ownership carved from C: characters, animations, first-person arms, masks, `char_` materials, and the officer renders of the style samples (owners.json updated; C's excludes cover them). C1-05 moves to D (D1-01..D1-05). C keeps the pipeline lib, texgen, materials, levels, audio, validate_level, and the counter renders.
- ENV B finished P1 (except the mask, now D1-04) and pulls P4 progression forward: B4-01 skills data, B4-02 perk decks data, B4-03 skill tree / perk deck UI, B4-04 armory expansion (one weapon per class).
- B1-03/B1-05 merged (ecc0e41). QB-28: ENV A's branch already conforms to ui_hud v1.1 (commit be99316, not yet on trunk). B deletes its HudModelAdapter once A-M2 merges. QB-29: `info.crit = true` ⇒ the target additionally multiplies by its HEAD zone multiplier on any zone (on a head hit they stack), as in PD2. QB-30: WEAKPOINT counts ×1 on targets without plates; range dummies never emit `npc_killed`.

## D-028 — 2026-10-10 — Style-sample handoff C → D; C1-00/01/04/06 merged
- Merged env/c-worlds @ 222c28c: style-sample scripts, texgen + 22-material library, validate_level (16 checks, with mutation tests proving each check catches its defect), audio cue set + MusicDirector + Glasshouse stems, pistol reload cues. Trunk check_all PASS, 228 tests.
- `tools/blender/style_samples/officer.py` and `head.py` now belong to ENV D. The shared modules (styles.py, sslib.py, sdf.py, post.py, contact_sheet.py, render_all.sh) stay with ENV C, and ENV D imports them read-only. ENV C owns the comparison sheet.
- ENV C's unpushed C1-05 character WIP (rig with contract bone names, body, outfits, poses, anims) is handed to ENV D as a head start. C pushes it under `tools/blender/_handoff_d/` (C-owned); the lead moves it to `tools/blender/characters/` (D-owned) in a lead commit. D treats it as untested input, not as accepted work.

## D-029 — 2026-10-10 — Character node paths confirmed (QD-2); mask prefix (QD-1)
- characters.md v1.1 fixes the exact node paths (Skeleton3D, AnimationPlayer, BoneAttachments as Skeleton3D children) and the shared "humanoid" AnimationLibrary. ENV A must use them.
- QD-1: ENV C adds `"mask": "masks"` to `tools/blender/lib/naming.py` PREFIX_CATEGORY. ENV D may build under the char_ prefix temporarily and rename once that lands. The final mask path is `game/assets/masks/mask_gilded_heron.glb`.

## D-030 — 2026-10-10 — Weapon materials merged; CI guards against invalid .import files
- Merged ENV C's 9 weapon materials (a6fa9eb). Every library material carries `metadata/uv_tile_m` (1.0 weapon, 2.0 environment).
- Concurrent `godot --import` runs can commit `.import` files with `valid=false`. check_all now fails on any committed `.import` containing `valid=false`. Never run two imports on one checkout at the same time.

## D-031 — 2026-10-10 — P4 skill/perk keys approved (QB-31..37); LIST modifier type; multi-qualifier queries
- Merged B4-01 (90 skills) and B4-02 (14 perk decks). All **71 requested keys** were registered at phase 4 (64 skill keys + 7 perk keys). Full semantics live in ENV B's `game/content/docs/skills.md` / `perk_decks.md`, which are the authoritative param schemas for ENV A. Any change to them goes through the lead.
- New `ModifierKeys.Type.LIST` with `Modifiers.list(slot, key) -> Array[Dictionary]` (one entry per source, tagged `_source`), for triggered effects that several skills grant independently: `weapon.kill_reload_buff`, `weapon.hit_stack_buff`, `weapon.kill_damage_buff`.
- New weapon qualifiers `suppressed` and `akimbo`. `Modifiers.mult/add/flag` accept an Array of qualifiers (e.g. `[&"pistol", &"suppressed"]`), combining `.all` with each one. `movement.shoot_while_sprinting.<class>` is allowed.
- QB-33: perk param schemas approved as proposed. ENV A implements them in P4 (or earlier when idle).
- QB-34: **MULT stays multiplicative** across sources (no zero or negative edge cases). This deliberately departs from PD2's additive percentages; ENV B tunes card values as cumulative ratios.
- QB-35: TEAM sources apply to the granter too. Perk-deck `team.*` grants go to a TEAM source `team_perk.<deck>`, so two players with the same deck don't stack (PD2 rule).
- QB-36: `interaction.revive_speed_mult` is a time multiplier (lower = faster), like every `interaction.*` key.
- QB-37: Hustler's vest bonus applies to **Light Vest, Patrol Vest and Heavy Vest only** (PD2 "ballistic vests" LBV/BV/HBV analogs). Overrules "all except suit".
- Trunk hygiene: the lead set ENV B's reminder test `test_requested_keys_are_not_grantable_yet` to SKIP while `blocked_on_keys` is non-empty, so trunk stays green. ENV B grants the keys, clears the list and may restore the strict test.
