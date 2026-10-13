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

## D-032 — 2026-10-10 — Answers QA-9..12; ENV A P2 queue; no loud-AI split
- QA-9: new TEST-ONLY hook `HeistRuntime.isolate_npc(npc)` (test_hooks.md v1.1). The P1 gate step 4 isolates the target guard before the pager test. Being spotted by others is correct gameplay, not a pager bug.
- QA-10: `loot.body_bag` weight must be HEAVY (S6.3); ENV B fixes the data. The P9 headshot_mult is already 1.0 on trunk (A's branch was stale).
- QA-11: approved. NPCs and AI teammates open unlocked doors on their path (instant in loud, a 0.6 s animation in stealth). Guards use keycard doors their post authorises. In loud, police breach locked doors (P3). Doors toggle nav links.
- QA-12: the alarm reason list is in events.md. `pager_failed(&"cancelled")` on going loud is not an alarm.
- No separate loud-AI environment: A1-09/A1-10 are already implemented. ENV A's queue was under 2 h, so P2 stealth-complete tasks A2-01..A2-07 are dispatched now (roadmap). P4 modifier hooks come after them.

## D-033 — 2026-10-10 — A-M2/A-M3 merged: P1 systems complete on trunk
- Merged env/b-content @ 8554760 (state-tolerant tests), then env/a-core @ b2586fc (detection, guard AI, civilians, pagers incl. juggling and the cap, bodies, bags, prefab behaviour incl. drill jams, combat on the D-026 single hit path, downs/bleedout/revive, assault director wave cycle, Patrol Officer/TAC Light AI, AI teammates, modifier hooks, sandbox gate test). Trunk check_all PASS: 432 tests, 0 failed.
- The P1 gate now waits only on ENV C's Glasshouse G1 map (and art for G2). ENV A's sandbox already passes the gate scenarios.

## D-034 — 2026-10-10 — Answers QB-38..45
- QB-38: `Modifiers.list()` accepts a source value that is a Dictionary or an Array of Dictionaries. Each entry keeps its own `_source`, which defaults to the source name.
- QB-39: `defense.post_revive_buff` becomes LIST.
- QB-40: confirmed: `kill_reload_buff.mag_falloff_from`; Bulletstorm duration = lerp(base, max, fraction of the refill taken); `melee_bloodthirst.max_mult` = 17.0.
- QB-41: ENV C adds `alu_anodized_black`, `polymer_tan`, `polymer_olive`, `glass_lens_coated` and re-checks albedo for `polymer_black`, `rubber_black` and `metal_matte` on weapons (style guide floor 0.04 linear; current renders read too light).
- QB-42: viewmodel anim sets `pistol` (Warden .45 shares it), `smg`, `rifle`, `shotgun`, `lmg`, `sniper` → ENV D (rig_arms). `cue.weapon_<set>_fire(_suppressed)` + reload cues per set → ENV C. Animated parts `Pump`/`Bolt` are in visual_slots.md, and ENV A animates them.
- QB-43: `WeaponStats.reload_per_round_s / reload_start_s / reload_end_s` added (0 = magazine reload). Shell-by-shell reload is interruptible by firing (PD2), and ENV A implements it. Display pellet exponent 1 (show pellet damage × pellets): accepted.
- QB-44: recorded in visual_slots.md.
- QB-45: perk points = floor(XP / 500) from all XP (◇). Move the setting to `content/data/tweak/`.

## D-035 — 2026-10-10 — ART DIRECTION LOCKED: Grounded Stylized Realism (product owner)
- The product owner chose option A (GSR) after reviewing the counter samples. This supersedes the provisional D-012/D-018.
- style_guide.md §1 is updated. The `a_gsr` renders are the reference bar.
- ENV D: drop the noir/photo officer variants. The head/officer fix becomes the GSR character baseline for D1-02.
- ENV C/B/D: remove "parametric across directions" as a requirement. Keep code clean, but stop spending effort on non-GSR presets.

## D-036 — 2026-10-10 — P1 gate placement made map-agnostic (QC-6); officer v2 + rig merged
- QC-6: the gate no longer teleports bots to fixed offsets. `BotUtil.find_clear_point(target, dist, behind)` searches navmesh points with architectural line of sight: behind sweeps ±110° (outside the 120° FOV), in front ±45° with props blocking. `_launch` waits for `BotUtil.nav_ready`. Verified against ENV C's Glasshouse G1 snapshot (0152852): **gate steps 1, 2, 4 and 8 PASS**. The floor guard post stays as approved.
- QC-8: ENV C drops its duplicate `test_glasshouse_gate.gd`. The lead's gate is the only P1 gate.
- Merged env/d-art: GSR officer v2 reference render, rig_humanoid (52 contract bones) + parametric body generator, mask_gilded_heron. ENV B points `mask.gilded_heron` MaskDef.model at `res://assets/masks/mask_gilded_heron/mask_gilded_heron.glb`.

## D-037 — 2026-10-10 — Glasshouse G1 deviations accepted (QC-7); ENV A follow-ups
- G1 screenshots reviewed (23 shots + plans): the layout matches the approved G0 plans and is plausible for greybox stage. Merge waits on validate_all PASS (ENV C is fixing two validator bugs).
- Accepted deviations: one merged `building` patrol graph; customers as a slot group; the smoker⇒propped rule as excludes + mission logic (P(kc_jeweler) 15.8% is fine); the floor guard as a fixed spawn with guard_post holding only rovers; P2 rows at pick 0 with cameras as markers until A fixes the prefab collision; the workshop ceiling override; door shifts of 0.2–0.5 m; the 1.1 m fire-exit leaf; kit window sizes. Rare events on zero-weight carrier slots are a temporary hack, to be replaced when A ships `min_difficulty`/`force_if` (A2-08).
- ENV A gets A2-08 (resolver features, window glass sizing, safe KEYCARD method, push-bar door, camera collision).
- Visual contract: the kit door `Collision` is a sibling of `Frame`. visual_slots.md stays as written (`Frame` supplies collision) and ENV C aligns the kit.

## D-038 — 2026-10-10 — Batch merge (Glasshouse G1, P2 stealth, app flow, character assembly); answers QA-13..20, QB-46..51, QB-PP1..5, QC-9/10, QD-3/4
- Merged env/c-worlds (Glasshouse G1 + validator fixes + D-034 cues/materials), env/a-core (A2-01..A2-07: P2 stealth complete), env/b-content (range on the real crew, HUD direct bind, B2-01..03, full app flow), env/d-art (character assembly tooling).
- **New contract `preplanning.md` v1.0** reconciles A's and B's designs. ENV B resolves (`PreplanPlan.apply()` → PreplanResult) and ENV A only applies. PREPLAN_POINTs are Marker3Ds under `<Map>/Preplan`, with the node name as point id (heist_map v1.2). Each buyer pays for their own assets; a voted plan's cost is split among the humans. Votes go through the new `Net.lobby_send` / `Net.lobby_message`.
- QA-13: prefab additions in gameplay_prefabs.md v1.1. QA-14: ENV B adds the strings, and **`ui.blocked.*` is canonical** (B renames `ui.prompt.blocked.*`). QA-15: cues → ENV C.
- QA-16: **ECM feedback is built into every ECM** (S8.6, PD2 U100+). Remove the `stealth.ecm_feedback` gate. The key is deprecated: ENV B stops granting it, and ENV A ignores it.
- QA-17: `crew_cuffed` / `crew_uncuffed` added to EventBus [R]. QA-19: `HeistResult.fail_reason` added. QA-20: marking while casing requires `stealth.casing_can_mark` (PD2: Chameleon basic). Confirmed gated.
- QB-46/47/48/49 → ENV A: `CrewController.set_input_paused(bool)`; the local human's CrewController makes its camera current and attaches the WeaponVisual (ENV B class, by name); LocalHudModel gets a `tracked_crew` mode without a HeistRuntime; gamepad look via the new `look_*` actions (now in project.godot).
- QB-50 → ENV D: contact portrait busts (Odile Vance, Hollis Reyes, The Accountant silhouette) and mask base meshes (heron, visage, vulpine, bruiser, owl). QB-51: characters.md v1.2.
- QC-9: black polymers, rubber and black paint may go to 0.02 linear albedo (style guide). QC-10: provisional perf budget 3M triangles per view, vault ceiling 2.6–6.0, review shots as JPEG.
- QD-3: `Socket` Marker3D children on every BoneAttachment (characters.md v1.2). QD-4: per-character `.res` meshes (~1.2 MB) accepted.

## D-039 — 2026-10-10 — P1 GATE GREEN on trunk
- With Glasshouse G1 merged, `test_p1_vertical_slice.gd` passes 4/4 on trunk (variants deterministic, casing + no-noise, kill→pager→answer, alarm→loud with no scene change→assault reaches FADE). ENV A's sandbox gate passes 8/8 (adds early pager release, bag secure, AI revive, escape). validate_level glasshouse greybox: PASS.
- Lead hotfix: ENV B's strings had guessed Glasshouse objective ids. Added strings for the mission's actual ids (casing, keycard, workshop_door, safe, safe_loot, secure). Rule from now on: objective ids come from the heist design doc's Objectives section `[tag]`s, and ENV B reads them from there, never guesses.
- Remaining for P1 sign-off (roadmap): Glasshouse G2 art pass (C1-07/C1-08) + characters in the map (ENV D) + lead playthrough notes.

## D-040 — 2026-10-10 — Night Deposit G0 APPROVED; QC-11..14
- `docs/design/heists/night_deposit.md` approved. A closed bank with a basement vault (keycard + time-lock code, or a server hack, then a time-lock hold; loud uses the thermal drill), 3 stealth routes, and a variable table where every row changes a decision. Exceeding the pager cap on Brutal is intended. ENV C may start G1.
- QC-11 `bag_lift` and QC-12 `hack_terminal` prefabs are added to gameplay_prefabs.md and dispatched to ENV A (A3-09). QC-13 `loot.cash_bricks` → ENV B (B4-09). QC-14: new `MapZone.Kind.OUT_OF_BOUNDS` (appended to the enum), respawning at PLAYER SpawnPoints tagged `oob_respawn`, never an alarm.
- `floor_heights` must be ascending and contain 0.0. Basements are negative.

## D-041 — 2026-10-10 — Animation set merged; viewmodel contract (QD-5)
- Merged D1-03: 47 humanoid clips (all 28 P1 clips plus 19 P2; the remaining 6 come with the P3 specials).
- characters.md v1.3 records clip speeds, turn and death conventions, event frames, the third-person weapon grip, and the **first-person viewmodel contract** (`char_arms_fp` with `weapon`/`magazine` helper bones, one AnimationLibrary per anim_set, played as "<set>/<clip>").
- Library material rule: every `game/world/materials/*.tres`, `char_*` included, must satisfy ENV C's ORM-PBR library test.

## D-042 — 2026-10-10 — Shadow Ledger G0 APPROVED; QC-15..19
- `docs/design/heists/shadow_ledger.md` approved: a stealth-only tower top (L40–L42 + roof, floor heights [0, 3.6, 8.0, 11.6], stairs verified), the ledger in three forms with laptop + 2 drive bags required, 5 entries, 3 escapes each with a different loot path, and keycards consumed so the optional safe can cost the main objective. Solo cuff = fail, as intended. ENV C may start G1 after the Night Deposit G1 (Glasshouse G2 stays first).
- Accepted: 0.3 m curtain-wall sills in the executive rooms, the 1.4 m plenum, The Accountant as contact for both P2 heists, base payout $110,000, and a walkthrough whitelist for vertical tower paths.
- QC-15/16 → ENV B (B4-10). QC-17: **no ladder climbing while carrying a bag** (PD2; fidelity S10.1b). QC-18/19 → ENV A (A3-10). escape_zone `escape_type` set, `arrival_delay_s` and `bag_only` are in gameplay_prefabs.md.

## D-043 — 2026-10-10 — Answers QA-21..26
- QA-21: the order routing is confirmed and written into crew_intent.md. QA-22: ui_hud v1.2 adds `custody_changed`/`custody` and `track()`/`tracked_crew`.
- QA-23/24 → ENV B (strings ui.blocked.push_bar_outside, ui.prompt.trade_hostage/convert/cable_tie, vo.crew.ack_*).
- QA-25: new `Loadout.mask_descriptor` (contract). ENV B's resolver fills it, the client sends it with its loadout at join, and ENV A replicates it to every peer's CrewView.
- QA-26: mounted visuals and collision stay on the room side of the pivot (wall: −Z only; ceiling: −Y only). ENV A fixes the ceiling camera collision.
- heist_map.md now references A's extended variant rule fields (force_if, slot_requires, min_difficulty, per-difficulty group weights).

## D-044 — 2026-10-10 — First-person viewmodel sets merged
- ENV D's `char_arms_fp` now has all 6 sets (pistol, smg, rifle, shotgun, lmg, sniper), with clip lengths matching the weapon data (test-enforced). characters.md v1.4 records the shotgun shell-by-shell and sniper bolt conventions; visual_slots.md adds `FeedCover` for LMGs.
- ENV B: add `FeedCover` to the Rampart LMG model and set the Plowman reload data to 0.4 / 0.4333 / 0.4 (1.2 empty).

## D-045 — 2026-10-10 — Shell-by-shell reload formula; trunk hotfix
- ENV D's viewmodel test and ENV B's armory test encoded different shotgun reload formulas, and the merge of D's FP sets turned trunk red (my mistake: the push ran despite a failed test, because a grep in the command chain masked the exit code. The lead now gates pushes on the runner's exit code).
- Ruling: the PD2-style formula in data_schemas.md (derived after mods, with a new `WeaponStats.reload_end_empty_s` for the empty pump). ENV B updates the Plowman data, mod deltas, resolver derivation and test_armory. ENV D re-enables its shotgun length check afterwards (temporarily excluded by the lead).

## D-046 — 2026-10-10 — Pre-planning data shape (QC-20..23); integration hotfix
- QC-20 (final): the contract's shape `HeistDef.preplanning = {favors, disable, "assets": {asset_id: overrides}}`; no
  top-level asset keys (B e9e5e5b, C f04cc90).
- QC-21 (final): crew-spawn PREPLAN_POINT category is **`spawn`** (the original contract; B's library and C's points).
  An intermediate `player_spawn` ruling was withdrawn; rulings crossed because trunk lagged (see D-048 process note).
- QC-22: ENV B adds library/strings for Glasshouse's heist-only `asset.inside_keycard` and `asset.propped_door`
  (force_variant) plus `ui.preplan.point.<point_id>` strings for the 9 points.
- QC-23: favors budget is design data (Glasshouse 4). ENV B makes `test_buying_deducts_budget` read the def's value
  first (done, 26bdb2d); Glasshouse favors set to 4 in the lead merge.
- `PreplanPlan.resolve_ids` returns `{}` when no id was accepted (nothing resolved = no pre-planning).
- ENV B added the A3-04/05 prompt strings and `vo.crew.ack_<order>` lines (8079505); the strings scan checks that a
  format-string prefix is completed by some line.
- D-045 closed: B's resolver derives shotgun reload totals (35b3bcc); ENV D's shotgun clip check re-enabled.
- Glasshouse VoxelGI (script-baked under xvfb) accepted for P1; LightmapGI revisited if Godot exposes a scriptable bake.

## D-047 — 2026-10-10 — Runtime script errors fail the test run
- A GDScript runtime error aborts the test function and the runner counted it as a pass (found in the 4-env merge:
  `test_app_flow.gd:149`, `test_masks.gd:163`). `tools/ci/run_tests.sh` now fails on any `SCRIPT ERROR:` line and lists
  them. Tests that exercise error paths use `push_error`/`Log.error` (which print `ERROR:`), never runtime faults.
- Merge fixes (lead, B-owned files): pre-planning screen tests count markers on the shown floor (Glasshouse has an
  upstairs insider point); mask placeholder test accepts ENV D's model; strings for A's `bag_lift`/`hack_terminal`
  prompts; `PreplanPlan.resolve_ids` returns `{}` only when ids were given and none was accepted.

## D-048 — 2026-10-10 — Night Deposit G1 approved; rulings; data-shape announcement rule
- Night Deposit G1 approved (C 7875192/d79c8eb; lead reviewed plans, contact sheet and full-size shots).
- Validator: floors named by height, interactive-only walk targets, `vault_door` 1.8–2.4 m, `plant` ceiling 2.6–6.0 m.
- Ceilings beyond the §2.6 table use per-room overrides justified in the design doc; the table stays generic.
- One consumable keycard (vault gate); other staff doors LOCKPICK + NPC-authorised. Sally shutter = breach ENTRY.
- QC-24: a static-laser bypass is a discoverable stealth route, clear width ≥ 0.8 m upright or crouched (capsule
  radius 0.35, no prone); validator asserts the capsule fits.
- QC-25 (ENV A): timed NPC spawn hook in HeistMission. Also ENV A: camera hitbox behind pivot, laser_grid `size_m`,
  `oob_respawn` excluded from default crew spawns, dominated-civilian identity in the mission API, prefab collision
  sized from the visual AABB (export override).
- Per-heist UI accent: shadow_ledger `#CFE3EE` (style guide §3). `options["is_pro"]` documented in test_hooks.md.
- Process: the lead announces data-shape rulings only once they are on origin trunk (D-046 churn).

## D-049 — 2026-10-10 — Answers QA-27..31, QB-PC1/2, QB-BRD1..3, QB-52..55
- QA-27: strings/voice lines are ENV B's (most landed in 8079505/e9e5e5b); B adds the rest from A's list.
- QA-28: cue ids accepted; ENV C synthesizes them (audio_cues.md list extended by C).
- QA-29: accepted for groups.md: factions `faction.tac|frd|sentinel|zero`; enemy ids as listed (already canonical);
  `params.visual_variant` per faction; GUARD SpawnPoint tag `scripted` = not spawned at load, mission spawns it.
- QA-30: `special_spawned` emitted by the special's brain on start. A broken tase must NOT reuse `crew_revived`:
  EventBus gains `crew_tase_ended(slot: int)` (lead). Captain resistance: ui_hud.md gains `captain_resistance: float`
  (0..1; server value replicated via Net; ENV A writes, ENV B shows a widget while Brandt is on the field).
- QA-31: DifficultyDef.special_limits gains `enemy.longshot` (Routine..Cataclysm: 1,2,2,3,3,4), still capped by free perches.
- QB-PC1: no save change; quitting with an unpicked card auto-picks it (same deterministic roll as the 30 s auto-pick).
- QB-PC2: boosts and skins stay out of the card table until those systems exist.
- QB-BRD1: MenuFlow (ENV B) enforces pro-job no-restart; ENV A only reports the failure.
- QB-BRD2: each player has their own Board; a lobby runs the host's contract (shared via lobby message).
- QB-BRD3: prices and level gates stay placeholders; balance pass in P6.
- QB-52: no new loot def. Small loot = `small_loot` prefab `value` → HeistResult cash. Night Deposit 800–2,400,
  Shadow Ledger 1,200–3,000 per item (before difficulty multiplier).
- QB-53: ENV B hides a generic asset whose payload references a variant group the heist does not have (no C work).
- QB-54: heist-only assets for Night Deposit's points are defined by ENV C under `HeistDef.preplanning.assets`; B adds strings.
- QB-55: a heist shows in menus only when its def and map exist (HeistRegistry); Night Deposit shows, Shadow Ledger after G1.
- Pull-forward for ENV B: B4-11..B4-15 (roadmap).

## D-050 — 2026-10-10 — Armory batch 2 contract additions (B4-12)
- `WeaponDef.akimbo: bool` (lead, contracts/data): the `akimbo` qualifier derives from it, not from anim_set.
- visual_slots: akimbo = one model + `Offhand` marker, WeaponVisual instances the offhand gun (`offhand`,
  `get_offhand_marker`), ENV A reparents it to the left-hand socket; revolver `Crane` + child `Cylinder`.
- New FP anim sets `akimbo` and `revolver` (ENV D), plus a fast pistol auto-fire clip for the Sparrow (≈880 rpm).
- audio_cues: rows for bag lift, hack, escape vehicles, `cue.weapon_revolver_fire`; looping tells stop on end facts
  (`crew_tase_ended`) or locally.

## D-051 — 2026-10-10 — QA-32/33; mission voice lines; round-3 integration fixes
- QA-32: fitted collision order = visual `Collision` child → visual AABB → `collision_size_override` (visual_slots.md).
- QA-33: multi-process loopback tests are allowed in CI: port 0 / random free port passed by args, hard timeout ≤ 60 s,
  child always killed in teardown, the test FAILS (never skips) if the child cannot spawn, runtime < 30 s.
- Mission voice ids follow groups.md `vo.<speaker>.<heist>_<line>`; VoiceLineTable gains the event tag `mission`
  (lines requested directly by HeistMission.say). Lead added draft lines/text for Glasshouse and Night Deposit;
  ENV B owns the wording.
- Night Deposit's 0.03 m camera Collision workaround removed (A3-07 keeps the hitbox room-side; it clipped walls).
- laser_grid placeholder posts are inset by half their width so the grid stays within `size_m`.
- New HeistMission virtual hooks use the `_on_mission_` prefix (ENV A) to avoid clashes with map scripts.
- Characters: ENV D head pass + 30 m silhouette approved for P1 (acfbd8f).

## D-052 — 2026-10-10 — Net client lifecycle; damage v1.1 (B4-11/B4-13 QBs)
- Net (lead): `join(addr, port, name)` sends the name to the host on connect; client signals `connected_to_host`,
  `connection_failed`, `host_lost` (the last two leave the session); host/join/leave clear handlers (no
  double-connect when hosting twice). Client-side heist launch (`HeistLauncher` on clients) is ENV A's (A3-07).
- damage.md v1.1: attacker-side `pierced_armor` + new `shield_pierce`; blocked hits emit `damage_applied` with
  amount 0 and `blocked: true`; plate damage ×1, no crit, excess lost; ENV A ships EnemyDefs with armour params
  for every special; range data may reference EnemyDef paths.
- B4-11 is in the roadmap (P4 table, D-049).

## D-053 — 2026-10-10 — Shell-by-shell clips; akimbo/revolver FP notes
- Shell-fed weapons always play the shell-by-shell FP pieces (start + n × loop + end / end_empty) for any shell
  count; the composed reload clips are previews/3P only and never time a reload (consistent with D-045).
- visual_slots: akimbo offhand at the HandL/Socket grip (no helper bone; left mag hidden/shown at mag_out_l/mag_in_l);
  revolver Crane/Cylinder/Speedloader details; revolver reload_empty = reload.
- Damage v1.1 follow-up: ENV B's range keeps a shooter-stats shield-pierce fallback only for legacy info dicts
  without the key; ENV A sets `shield_pierce` attacker-side (then the fallback is dead code to remove).

## D-054 — 2026-10-10 — floor_names, stamina HUD, client launch, round-5 docs
- QC-32: `HeistMap.floor_names` (optional, parallel to floor_heights) + `floor_name(i)`.
- ui_hud v1.4 `stamina_changed` (stamina 0..1, exhausted) for ENV A's minimal stamina system (QB-60); B builds the widget.
- net.md / test_hooks.md: `HeistLauncher.launch_client` (A3-07) documented as the client entry point.
- L1 (from ENV B): modifiers.md perk.stoic example and the perk.burglar / team.armor_regen_delay_mult descriptions.
- QC-33: open-side guards pass at top ≥ 1.0 m; the 1.0–1.1 m band applies to handrails only.
- B pull-forward B4-16..B4-20 (save v2, workshop orbit view, armory batch 3, stamina widget, achievements stub).

## D-055 — 2026-10-10 — Armory batch 3 contract; round-5 integration
- visual_slots: batch-3 nodes Breech, Lever, StringUpper/StringLower, String, PilotLight, Blade, Rotor (B4-18);
  8 new FP anim sets for ENV D (break_action, lever, bow, crossbow, launcher, flamethrower, saw, minigun).
- audio_cues v1.1: per-set weapon cue ids from ENV C (B4-18). Weapons without a suppressor slot leave
  `fire_cue_suppressed` empty.
- P3 special models (ENV D d45511f) approved; contact portraits approved (Odile provisional until the feminine-head pass).
- Asset determinism: Blender glTF tangent export is nondeterministic (~1/4 builds); ENV D fixes the exporter settings
  (style guide §6 byte-reproducibility).
- Round 5 hotfixes: a removed call to the uncommitted `PerkHooks` (ENV A re-adds it with the class); lead_push lints
  first; envs validate pushes from a clean checkout of the exact commit.

## D-056 — 2026-10-11 — Perk hooks landed (QB-56..62); hostage absorption shape
- ENV A wired team.* and all 15 perk.* PARAMS mechanics (game/systems/modifiers_params.md), stamina (ui_hud v1.4),
  ModifierPush at launch (server; B drops the MenuFlow push). TEAM grants apply to the granter (QB-35), so personal ×
  team stacking is correct; lead updated 4 expectations in ENV B's test_perk_behaviour (Foreman 1.2/1.1, Hustler
  Light Vest dodge +0.40, Ironclad delay ×0.81). ENV B moves the hooked keys in test_perk_wiring + perk_decks.md.
- `team.damage_reduction_hostage` is **flat damage absorption per hostage, capped by hostage count** (PD2 Crew Chief
  shape): PARAMS `{absorb_per_hostage: float (PD2 display units), max_hostages: int}`. skills.md and perk_decks.md
  follow this; no value-based shape detection.
- `ensure_info_v11` stays as target-side defaulting for hand-built info dicts.

## D-057 — 2026-10-11 — Armory batch 3 contracts; save v5
- `WeaponDef.params` / `WeaponModDef.params` (Dictionary; mod params shallow-merged over the def's in mod order).
  Schemas per mechanic in game/systems/modifiers_params.md (ENV A).
- fire_modes gain `charge` (bow/crossbow draw) and `lever`.
- gameplay_prefabs v1.3: group `saw_target` + `saw_cut(seconds, attacker_net_id)`.
- Modifier keys `weapon.saw_wear_mult`, `weapon.saw_damage_mult`, `weapon.saw_shield_pierce` (FLAG).
- ui_hud v1.5 `weapon_charge_changed` / `weapon_spin_changed`.
- Mechanics follow pd2_fidelity L3.4 (fire ignores armor and shields) and L3.6 (explosion falloff).
- Save format v5 (ENV B B4-16 = roadmap "save v2"): unlocks/achievements/pro_job_locks, sanitizing + validator
  pruning, golden v0..v4→v5 migrations, damaged-file fallback (content/docs/save_format.md).
- Armory reaches 36 weapons (B4-18); stinger_45 renamed lancet_45 (name clash with a mod).

## D-058 — 2026-10-11 — Batch-3 viewmodel notes; shotgun_box set
- Harrow 12 / Brute 12 (box/drum-fed shotguns) get their own FP set `shotgun_box` (ENV D) instead of reusing `rifle`,
  so their reload lengths follow their own data. ENV B sets `anim_set = &"shotgun_box"`.
- characters.md v1.5: batch-2/3 sets, loop naming (`fire_hold`/`cut_hold`), bow draw curve + offhand hold, weapon-bone
  exceptions, model-layout assumptions, Bulwark `shield_idle`.

## D-059 — 2026-10-11 — Glasshouse passes G2 (final art); punch list for G3
- Reviewed: contact sheet (all 23 shots) and 13 full-size shots (exteriors, workshop, salon, stair core, garage perch,
  offices, G4 corridor, counter, site plan). validate_level glasshouse [final] PASS (18 checks), P1 gate 4/4.
- **G2 approved.** Scale, lighting, dressing and the stealth reads (shopfront glazing, G4 sightline, safe + reader)
  meet level_standards. QC-34: the 1.0 m parapet is the perch guard (no extra rail).
- Punch list (non-blocking, fix before G3): wood plaque "VOSSBERG" lettering garbles (counter shot) and blocks at a
  grazing angle; black splotch decals on desk fronts (security, admin); faint alley fence posts; add a garage-ramp
  review shot; reframe admin_office (cabinet in front); U5 monitor orientation warning.
- P1 sign-off is held until the P1 integration gate automates all 11 roadmap steps end-to-end (today: 1, 2/3, 4, 8/9).

## D-060 — 2026-10-11 — P1 gate complete (all 11 steps end-to-end)
- game/tests/integration/test_p1_vertical_slice_b.gd adds steps 3, 5, 6, 7, 10, 11 on the real Glasshouse map
  (10/10 integration tests, two identical runs). Stated shortcuts: isolate_npc for NPCs outside the step, teleports
  instead of walking, alarm/down injected in step 10. No missing APIs.
- Roadmap step 11: "escape with the mission's required bags" (Glasshouse mission: 2).
- Findings routed: ENV C, SafeLoot not parented under WorkshopSafe (the loot could be taken from a locked safe; P1
  sign-off waits on this fix); camera variant group resolving to none (enable now that P2 is done); ENV A, a spurious
  CASING→STEALTH hop on alarm-while-casing.

## D-061 — 2026-10-11 — P1 signed off
- All P1 gate items pass (docs/process/p1_signoff.md): the 11-step end-to-end gate, Glasshouse G2 (final art,
  18/18 checks), characters, full CI. Known gaps are carried forward there; a product-owner playtest is recommended.
- Glasshouse: security_room_staffed (operator 0.6 / empty 0.4) and code_note (one of three) are enabled (ENV C).

## D-062 — 2026-10-11 — Music selection (B5-03)
- ENV C: `MusicTrackTable` (`res://world/audio/music/tracks.tres`; id, stems, default_for_heists, unlock;
  `load_default()`, `all()`); MusicDirector plays `rt.launch_options.music_track` when set, else `HeistDef.music_track`;
  hub preview `MusicDirector.preview(track_id, stem = &"assault")` / `stop_preview()`. 3 more tracks for P5.
- ENV A: `HeistRuntime.launch_options` (read-only dict from launch()/launch_client()), replicated in the bring-up so
  every peer plays the host's pick.
- ENV B: `options["music_track"]` from the pre-planning/lobby pick (host wins in co-op), hub jukebox UI, `music.<id>.name`
  strings, track unlocks (Notoriety ranks) in the profile.

## D-063 — 2026-10-11 — Shared-set reload scaling; heist NPC casting
- An FP set whose one reload clip serves weapons with different reload times plays it at
  `speed_scale = clip_len / reload_time_s` (and reload_empty likewise), allowed range 0.75–1.35×; outside that
  a weapon needs its own clip. First use: `shotgun_box` authored to Brute (3.6/4.4), Harrow plays ≈1.24×.
  Shell-by-shell pieces keep data timings (D-053). ENV A implements; test_arms accepts any weapon within range.
- NPC casting follows the heist design docs:
  - Night Deposit: night manager, cleaner, Halden Security guard (ENV D re-badges its bank guard).
  - Shadow Ledger: cleaners (cleaner variant), an IT contractor (to build), Helena Moor (brief from ENV C), and Kessler
    in a robe by default (`npc_kessler_coat` kept).
  - Tellers are reserved for Meridian Federal (now Ostrander Federal, D-075); guests and the waitress for Gallery Night (P5).

## D-064 — 2026-10-11 — Dockside Burn G0 approved
- Loud-only (P3) heist; Ortega Cold Storage, Pier 9. Opens with a cartel phase, then police after a rolled 60/90/120 s
  delay. Required: the burn + 4 bags (extra bags and product are a bonus). Base payout $95k (placeholder; P6 balance).
- Approved: high-bay ceiling override 6.0–9.0 m; scale rule `industrial_door` 2.4–4.0 m wide × 2.1–4.5 m high;
  the −1.8 Landing in floor_heights.
- Cartel gunmen share `DifficultyDef.max_active_enemies` with police; the police quota is reduced by the cartel alive
  count. Fire damages players (DoT, ignores armour, L3.4), telegraphed (warning cue + 5 s shutter countdown).
- Police never spawn inside the building; they enter only via ENTRY TacticalPoints.
- Two always-on sniper perches suffice for the P3 gate.
- Requests:
  - ENV A: QC-35 police start delay, QC-36 cartel EnemyDef, QC-37 saw_cut implementers, QC-38 burn_point, QC-41 one-way
    rappel links.
  - ENV B: QC-39 loot, QC-40 preplan assets.
  - ENV D: the cartel gunman model.
- Priority: Dockside Burn G1 (the P3 gate) before the ND/SL G2 art passes.

## D-065 — 2026-10-11 — Civilian mode contracts (S1.3, B5-05)
- `HeistDef.start_mode` (&"casing" default | &"civilian"); ui_hud v1.6 `player_mode_changed` + crew `mode`;
  gameplay_prefabs v1.4 `gear_pickup` and the common `civilian_allowed` export (block reason `ui.blocked.civilian`).
  ENV A implements, ENV B adds strings (`ui.prompt.pick_up_gear`, `ui.blocked.civilian`) + HUD, ENV C uses it on
  Afterhours (P5).
- D-063 range check landed (ENV A 34b5537). Outliers (furnace ×0.5, cyclone empty ×0.73) are re-measured after
  ENV D's batch-3 rebuild (bfde340) reaches trunk; any that remain get their own clip (D) or adjusted data (B).

## D-066 — 2026-10-11 — P3 gate tests drafted (Glasshouse until Dockside Burn)
- game/tests/integration/test_p3_loud.gd: escalation and caps over 3 waves; counterplay for each special (Phantom,
  Stinger, Bulwark, Wrecker, Longshot, Corpsman, Brandt/Aegis); custody + hostage trades; AI orders during an assault.
  test_coop_loopback.gd: host/client parity (variants, crew, NPCs, a door, the alarm, a bag, heist_ended) with
  D-051 process rules. 21 integration tests green on two runs (~85 s added).
- Temporary workarounds accepted, each with a routed fix and a revisit:
  - seed 3007 (salon open) until ENV A ships police door breaching / locked-door-aware pathing; then add seed 3001.
  - loopback seed 3074 until ENV C fixes the esc_alley_west secure-zone floor offset.
  - loopback ends through all-custody; revisit with Dockside Burn's loud escape.
- Bugs routed:
  - ENV A: police path through locked doors with no breach (`NpcMotor.door_blocked`).
  - ENV A: AI teammates never free kicked or tased crew (only DOWNED), which breaks L2.8/L6.1.
  - ENV C: VanSecureE1 zone floor at 0.0 vs alley ground −0.15.
- The P3 gate switches its map constant to dockside_burn once that map reaches G1.

## D-067 — 2026-10-11 — Faction variants, cartel look, repo size
- characters.md v1.6: the faction variant scene convention (ENV D D2-01). ENV D adds `frd_agent` (plain-clothes federal
  agent) and stronger Zero accents on Phantom/Longshot. Cartel gunmen get an `idle_thug` hunched idle (D authors, A maps).
- Repo size: each assembled character duplicated its glb meshes into .res (~3.5 MB per character). ENV D switches
  assembly to reference the glb meshes (the contract node paths must not change; any change needs a lead-approved
  contract edit first). Git LFS is deferred: it is infra with storage/bandwidth costs on the owner's GitHub account,
  so the lead raises it with the product owner if .git approaches 2 GB (411 MB now).
- B5-01 options hooks routed (A: FOV/sensitivity/invert/toggles; C: brightness + palettes); B5-02 Notoriety costs
  spending cash (no offshore account); music unlocks `unlock.music.vault_hymn`/`long_con`/`last_call` (ranks VII/XIII/XXI).

## D-068 — 2026-10-11 — Dockside Burn content answers (B5-04)
- `LootDef.is_tool` (contracts/data): no value, no XP, never counts toward [secure] (thermite). preplanning.md v1.1:
  `loot.<id>` drop kinds spawn that bag; point labels heist-qualified for new heists.
- $95k base is a placeholder (P6 balance); per-heist Board gating is P6; no armor-bag drop on loud-only jobs; small
  loot $600–1,500 until ENV C sets prefab values.

## D-069 — 2026-10-11 — Item FP contracts, gun bash, music hooks, B6 dispatch
- ENV D's seven proposals (D2-04) accepted: `anim_set` on MeleeDef/ThrowableDef/DeployableDef plus optional
  `MeleeDef.swing_time_s` / `hit_delay_s` / `equip_time_s` (contracts/data, lead); item-model conventions
  (visual_slots.md "Items"); `<set>_bash` with hit@; viewmodel near plane 0.02 m and runtime left-hand IK to
  `LeftHandIK` (ENV A); bow brace 0.155 m; crossbow string halves and the Marshal `Speedloader` (ENV B).
  characters.md v1.7 records the sets and D2-02's NPC ambient clips.
- B5-03 music: `MusicTrackTable` (ENV C, `res://world/audio/music/tracks.tres`), `MusicDirector.preview/stop_preview`
  usable without the EventBus, heist music = `launch_options["music_track"]` else `HeistDef.music_track`; ENV A
  replicates `music_track`. The lobby profile summary gains an optional `music` field (missing reads as "").
- Glasshouse G3 signed off (ENV C 21ca875; garage lights accepted). Polish backlog: garage parked cars as props,
  stray bracket by the VOSSBERG neon, security-office bins.
- ENV B dispatched B6-01..05 (P5 loot/contracts, Tab scoreboard + awards, chat, drop-in/kick UI, lobby codes).
- Gate hygiene: HUD-model asserts after a physics wait call `hud_model.refresh()` first (it polls on render frames).

## D-070 — 2026-10-11 — P3 gate on Dockside Burn; safehouse; contract updates
- **P3 gate map = dockside_burn** (test_p3_loud, seed 3007): wave hold on Ferro Street (the open street; the holdouts
  were hollow while police spawned at `breach_only` doors), cartel gunmen despawned where they are not the subject,
  Bulwark standoff point clear of every SHIELD_ANCHOR, a second hostage spawned (night_shift rolls 1–3). New assert:
  no unit spawns at a `breach_only` ENTRY point (QC-42, ENV A 878d35f). 10/10 on 3+2 runs. test_coop_loopback stays on
  Glasshouse (it needs a STEALTH phase), now seed 3071 with bags dropped at the van `DropAnchor`.
- Routed from the port: ENV A — navmesh through barred Ferro gates (or ENV C bake), Bulwark anchors behind the target,
  CrewAiBrain out-of-tree targets; ENV C — holdouts need ≥ 2 non-breach-only approaches, keep the yard arena open.
- Safehouse "The Press" G0 approved (docs/design/heists/safehouse.md): SafehouseMap root (contract hub_map.md v1.0 to be
  written with C4-02), 8 stations incl. `crew` phone and `notoriety`, solo v1, 2D hub fallback. Roadmap C4-01..03,
  A3-11 hub support, B6-06 3D hub mode, C5-01 stems (unlockables alias heist stems until P5 music ×3).
- Contracts: characters v1.8 (heister FP sleeves, `rappel` clip), visual_slots crossbow `StringUpper`/`StringLower`
  + revolver `Speedloader`, audio_cues v1.2 (`cue.door_breach`, `cue.burn_warning`). Shadow Ledger painting = LIGHT.
- A3-12: player melee (L3.9) was never implemented — ENV A builds CrewMelee then CrewThrowables (high priority).

## D-071 — 2026-10-11 — Scoreboard stats and payday awards (B6-02)
- ui_hud v1.7 `crew_stats_changed` (`crew_stats` rows) and events v1.1 HeistResult crew rows gain `name`, `shots`,
  `hits`, `headshots`; counting rules in ui_hud v1.7 (a shield/plate strike is a hit: accuracy measures aim). ENV A owns.
- Payday "Crew Honours": AI teammates appear on the scoreboard but **never win awards** (PD2's end screen honours
  players); among humans, ties break by lowest slot. A solo player still gets awards they earn.

## D-072 — 2026-10-11 — Net.kick, chat, drop-in policy, safehouse hub contract (B6-03..06)
- `Net.kick(peer_id)` (lead, core/net.gd): host-only; notice RPC then disconnect after 0.25 s (ENet drops queued
  packets on an immediate disconnect); `peer_kicked(peer_id, slot)`; client `last_disconnect_reason = &"kicked"`;
  kicked display names are re-kicked for the rest of the session. net.md v1.1 also reserves `lobby.chat`/`lobby.kick`.
- Input action `chat` = Enter / keypad Enter (T is `order_menu`). `G.HUB_STATION`, `G.DROP_IN_SERVICE`.
- Rulings for ENV B: kicked peers cannot rejoin that session; drop-in policy ask (default) / auto / off (PD2);
  hub return to the station UsePoint; jukebox duck is MusicDirector `set_ducked`; hub prompts use the in-heist
  prompt format; IPv6 lobby codes out of scope.
- hub_map.md v1.0 (safehouse scene, stations, StationCam as Marker3D) with ENV C's wording.

## D-073 — 2026-10-11 — Heister choice, throwables, mask fit
- `Loadout.heister: StringName` (&"" = generic crew): the player's heister rides the loadout; ENV B sets it from the
  profile (unique per lobby, PD2); ENV A's FpViewmodel reads it for the sleeve variant (characters v1.8).
- A3-12 throwables: ENV B adds `throwable.frag` / `concussion` / `incendiary` / `throwing_knife` data (◇);
  audio_cues v1.3 `cue.throwable_*` (ENV C).
- Masks clear the crew face envelope by ≥ 3 mm (ENV D fix for skin/hair poking through; characters v1.8).
- Nav bake: BARRED/locked closure gates are baked closed (ENV C), A's door NavLink bridges them while passable.
- D-067(b) implemented (ENV D fb65fdd): all 76 character scenes are inherited scenes of their glb (remove_armature),
  367 per-scene .res removed, game/world/characters 114.9 MB → 3.3 MB; node-tree dump of 84 scenes identical
  before/after; builds byte-deterministic. characters.md v1.6's variant text applies as written; ENV A unchanged.

## D-074 — 2026-10-11 — Weapon finishes, kick-list query, P5 prep
- `Loadout.weapon_finishes: Dictionary` (weapon_id → finish_id, ENV B B7-04; save v7 reserves `weapon_finishes`).
- `Net.was_kicked(display_name)`: public query of the session kick list (HeistDropIn and lobby agree).
- Drop-in: host sends `full` when no human-replaceable seat; a host's policy change applies live; B's client-side
  `unreachable` reason. characters v1.9 adds D3-02's P5 ambient clips with placement numbers for ENV C.
- P5 preparation: ENV D's P5 cast (fda27f0) precedes the P5 G0 docs; ENV C drafts gallery_night, meridian_federal,
  afterhours, rolling_thunder G0s (QC ranges 51–89) and confirms/renames D's invented companies.
- Roadmap: A4-01..03 (fidelity audit, perf budgets, 4-client soak), B7-01..04 (career stats, achievements, contact
  radio, weapon finishes), D3-01..04 (P5 cast, P5 anims, mask batch 3, animation polish).

## D-075 — 2026-10-11 — P5 G0 rulings; Meridian renamed
- **`meridian_federal` → `ostrander_federal` ("Ostrander Federal")**: "Meridian" is used by real banks and credit
  unions, and the standing rule is original names only. The branch already sits on Ostrander Plaza. Owners rename
  ids/strings/files (B content + strings, C design doc, D p5_cast.json). The "meridian line" floor detail may stay.
- P5 G0 drafts (ENV C 231c056) approved for G1 with rulings sent to ENV C (gala clock, camera-layout validator rules,
  required loot, civilian staff doors closed, Afterhours contact = The Accountant, Rolling Thunder "Loud (ambush
  start)" label, room purposes `gallery` / `hall` / `car_park` in C's scale table). Big prefab asks (armored_truck,
  convoy_vehicle, C4 item) become ENV A roadmap rows A5-01..03.
- L1.1 fade_threshold: data (8–18) wins; PD2's "50" rescaled to our enemy cap.

## D-076 — 2026-10-11 — Playability before content (product owner)
- **New content is paused until a playability pass lands.** Hands-on play is largely unplayable today. The gates
  pass because the bots use shortcuts (teleports, isolate_npc, injected downs; p1_signoff.md "known gaps"), and the
  recommended product-owner playtest before P5 content scaling never happened.
- Paused: the P5 heists (G1s, P5 contract data), D4-03 new heisters, D4-02 crowd variety, C5-01 music stems, and
  new roadmap content rows.
- Continues: finishing existing heists (Shadow Ledger G2, Dockside Burn G2 → P3 sign-off), A4-01 fidelity gap fixes,
  bug fixes, B7 loose ends, D's socket fix / LODs / touch-ups, and the lead's P2/P4 gates.
- The pass: the product owner plays and lists quirks; the lead turns them into roadmap rows (mostly ENV A
  controller/ADS/casing, ENV D animation, ENV B HUD/menus). Each fix ships with a test that drives the crew the way
  a player does (real movement input, no teleports) where a test can catch it.
- Seed items: CrewController has no step-up (plain `move_and_slide()`, so curbs and small ledges block the player);
  ADS animation quality; casing-mode quirks (incl. the spurious STEALTH hop when the alarm goes off while casing).
- **ENV P (Playability), branch `env/p-play`:** a dedicated env for player feel. For the pass it owns
  `game/systems/player/**` (CrewController, CrewView, PlayerInput, stamina), `game/systems/anim/fp_viewmodel*`
  (first-person viewmodel and ADS) and `game/systems/tweak/crew_tweak.*`, plus `game/tests/p/**` and
  `docs/status/env_p.md`. These are excluded from ENV A (owners.json). Moved from ENV A's queue to P: S1.2 mask-up
  feel and apply_loadout_finish in fp_viewmodel. P's changes to other envs' files go through the lead, as usual.
  P's branch is merged locally by the lead.

## D-077 — 2026-10-11 — Checkpoint cadence (product owner)
- Sessions can stop without warning (credits or usage limits). Every agent works so that a stop loses at most about
  30 minutes:
  - Commit locally every 20–30 minutes and at each logical step, WIP included (`WIP` prefix is fine).
  - Keep the status file's In progress entry current (done / half-done / exact next step) so a fresh agent can
    resume from the file alone.
  - Push the env branch whenever a checked unit passes, at least about hourly. Failing checks are never pushed and
    nobody force-pushes.
- Envs that don't push (P, the lead's helpers) commit on their local branch and notify the lead per finished item.
- **Known-flake waiver (temporary):** until ENV A's condition-wait fix to
  `game/tests/a/test_b4_18_special_weapons.gd:test_parts_animator_drives_named_parts` reaches trunk, a check_all
  whose only failure is that test ("Breech open while reloading") counts as a pass for env pushes. The env names
  the waiver in its push report. The lead's trunk gate is not waived.

## D-078 — 2026-10-12 — Team moves to Grok Bot agents on the shared box
- The Claude Code cloud sessions / WSL subagents are retired. LEAD + ENV A/B/C/D/P are Grok Bot agents, each in its
  own clone under `/workspace/cnc-team/<role>/` on the shared box. Coordination: BOARD (`/workspace/cnc-team/BOARD.md`),
  SendToAgent messages, and docs/ on trunk for anything durable. Unpushed WSL work is on `backup/2026-10-12/*`.
- communication.md §1/§4, envs/*/CLAUDE.md and lead_handoff.md §4–5 rewritten accordingly. D-027, D-077 still apply.

## D-079 — 2026-10-12 — Guard domination (product owner + PD2 precedent)
- **Dominated (cuffed) guards count as hostages** (trade/hostage count), as in PD2. They also stay a `hostage`
  stimulus (S6.4) and their pager still fires (S5.8).
- Range/angle follow PD2 (`playertweakdata.lua` long_dis_interaction, `playerstandard.lua`
  `_add_unit_to_char_table`), replacing 15 m / 20°: base shout range **10 m** to enemies × `intimidate_range_mul`
  (1.5, Dominator/Confident) × passive mul (1.25, Crew Chief); target check tolerance ×1.05 (CopLogicIntimidated).
  Aim cone: `max(8°, lerp(90°, 30°, dist / 12 m))` (tight areas `lerp(30°, 10°, …)`). 15 m is the skilled
  value, not base. ENV A updates S5.8 data/tests; pd2_fidelity S5.8 gets these numbers.

## D-080 — 2026-10-12 — Character LODs (ENV D, ENV P)
- 13 MB total of `*_lod.res` is accepted (disk only; attribute compression stays off because it breaks skinning).
- **Specials have no LOD2** (PD2 precedent: specials must be readable at range); they use LOD0/1 only, so silhouettes
  and telegraphs (e.g. Corpsman red cross) survive at distance. Regular units use LOD2.
- Near-black armed units (`tac_heavy`, `corpsman`, `security_officer`) get a lighter shoulder/helmet accent (ENV D)
  so they read against dark backgrounds.
- Scopes: a **zoom-aware LOD bias in camera code** (ENV P), not raised LOD switch distances. *(Superseded by D-084.)*

## D-081 — 2026-10-12 — `loot.painting_study` value
- **$700** (LIGHT bag, ◇), as in gallery_night.md QC-57/D-075: a study is minor loot, below a full painting, in line
  with PD2 where light art bags are worth less than the main pieces. Not $1,100. P5 is frozen, so this lands when P5 resumes.

## D-082 — 2026-10-12 — Playability pass before anything new (product owner)
- Before any new addition, the game gets a **full practical gameplay pass** plus a **test suite that plays it as a
  real player would**: real input events (keyboard/mouse through Godot's Input), real camera/aim, walking every route,
  no teleports, no direct intent/state shortcuts, no bot short-cuts. The team builds the issue list itself
  (`docs/process/playability_pass.md`); no waiting on the product owner.
- **P5 and all new content are frozen** until the pass is done, including ENV B's B4-12..18. Supersedes D-076's scope.
- Every env queue is steered toward it (lead_handoff §5).

## D-083 — 2026-10-12 — Push blocker and merge order
- The box's GitHub token lacks `contents:write` (403 on push): pushes/merges to origin are blocked until the
  product owner fixes it. Meanwhile the lead prepares merges locally (lead/round-34, lead/p2-gate, lead/d078-docs).
- When pushes work, **first** merge `p_input_driver.gd` (env/p-play a43d33b7 + 6b858a0b) to trunk (D-082 real-input
  suite foundation), then round 34 (env/b-content), the docs branch, and A/D once they pass check_all.

## D-084 — 2026-10-12 — Scope LOD via zoom_factor (supersedes D-080 scope bullet)
- Godot's mesh LOD already scales with camera FOV, so **no extra `mesh_lod_threshold` bias for scopes**.
  That part of D-080 is superseded.
- Instead, **CrewView (ENV P) publishes a `zoom_factor`**. Props/characters in ENV C and ENV D that use
  visibility ranges scale those ranges by it while ADS/scoped, so distant detail stays up under zoom without
  fighting the engine's FOV-based mesh LOD.
- Context (ENV P, `env/p-play` `1328183f`): mouse look used `InputEventMouseMotion.relative`, which is
  stretch-scaled and wrong at non-1080p; switched to `screen_relative` for correct sensitivity.

## D-085 — 2026-10-12 — Door snagging: fix movement, not the navmesh (supersedes "capsule 0.35 re-bake")
- Navmesh `agent_radius` **stays 0.30**: with `cell_size` 0.1, 0.35 ceils to 0.4 and breaks `validate_level`.
  The crew capsule **stays 0.35**. The earlier "re-bake for a 0.35 capsule" instruction is withdrawn.
- **ENV P:** the player capsule slides along door frames and props instead of snagging. Test with real input:
  a 0.9 m door, 30° approach, walking and sprinting.
- **ENV A:** AI followers keep ~0.1 m off path corners, with headroom in `path_desired_distance`.
- Human real-input walk tests aim at door centres; corner-following is checked only for AI.

## D-086 — 2026-10-13 — Team v3: lead + three Claude Code cloud sessions; product-owner playtest issues first
- The Grok Bot team (D-078) is retired. A LEAD Claude Code session dispatches three cloud sessions: **ENV P** (Player &
  Input, `env/p-play`), **ENV B** (Content & UI, `env/b-content`), **ENV A** (Core Systems & Heist Loop, `env/a-core`).
  ENV C and ENV D are **dormant** (their branches were merged as-is in round 35; no new C/D work). Protocol:
  communication.md §1/§4, live state in `docs/process/board.md`.
- Ownership during the pass: ENV A also owns `game/world/heists/**` and `game/world/props/**` (heist-map collision,
  nav, door and objective fixes that ENV C would otherwise do). ENV B owns `docs/design/ui/**` (UI style spec).
- **Product-owner playtest (2026-10-13), top priority, rows PO-1..PO-5 in playability_pass.md:** the mouse is never
  captured in a heist so you cannot turn; you cannot leave casing mode; a slight bump in the road stops the player; the
  UI is cluttered, unintuitive and unstyled. Found by the lead: no game code sets `MOUSE_MODE_CAPTURED` outside the
  safehouse, and every real-input test fakes capture (`PlayerInput.test_assume_captured`), so the suite never saw it.
- **Verification rule:** a player-facing fix counts as verified only when seen in a **windowed** run (xvfb with a real
  display server, not `--headless`): screenshot or windowed test. Fake-state tests stay as regressions only.
- D-082 stands: end-to-end playability (main menu → hub → loadout → heist stealth and loud → payday → hub) before any
  new heist or content. P5 stays frozen.

## D-087 — 2026-10-13 — Mouse capture has one owner (`input_focus.md` 1.0)
- One module, `MouseCapture` (ENV P, `game/systems/player/mouse_capture.gd`), is the only code that writes
  `Input.mouse_mode`. Gameplay (PlayerInput of a local human crew in a heist or the walkable safehouse) declares itself
  active; every UI that needs a cursor holds a named release. Captured = gameplay active ∧ no release held ∧ window focused.
  Contract: `docs/contracts/input_focus.md`. ENV B migrates its four direct writers (menu_flow, menu_options,
  join_request_dialog, safehouse_host) once P's module is on trunk. The lead adds a banned-pattern check afterwards.

## D-088 — 2026-10-13 — Targeted checks; the full suite runs only at the lead (product owner)
- **Envs never run `check_all.sh` or a whole test dir as a routine pre-push step.** Before a push an env runs only what
  its change touches: `gdlint` on changed files, `python3 tools/ci/check_ownership.py <env>`, `python3 tools/ci/check_banned.py`,
  and the specific test files it changed or that exercise the changed code (single-file runs), plus its windowed
  verification (D-086). Long runs (>~5 min) stay in the background so work continues meanwhile.
- **The full gate (`check_all` / `lead_push.sh` with no args) runs only at the LEAD, occasionally**: per merge round, in
  the background in a separate worktree, while everyone keeps working. A failure there goes back to the owning env as a
  normal task. Supersedes the "check_all PASS before push" rule in communication.md §2–§5 and the env manuals.
