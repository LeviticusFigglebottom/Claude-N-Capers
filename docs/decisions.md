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

## D-089 — 2026-10-13 — Objective world markers (ui_hud 1.8); placeholder-capsule NPCs
- ENV A's QA-PO5-1 approved: objectives carry `data.marker_tags`; `LocalHudModel.objective_markers` (ui_hud 1.8). ENV B draws them.
- NPCs/police rendering as placeholder capsules (PO-5.7, B's captures) is a top playability issue. ENV A diagnoses
  first: wiring (EnemyDef/NPC spawn pointing at placeholders, a failed scene load: A's domain) vs missing assets
  (ENV D, dormant). If assets are missing, the lead decides whether to wake ENV D.

## D-090 — 2026-10-13 — UI sound cues (audio_cues 1.5); ENV B synthesises them while ENV C is dormant
- audio_cues 1.5 adds ten UI/HUD cue ids (`cue.ui_*`, `cue.hud_objective_done`, `cue.hud_hint`, `cue.payday_total`, `cue.card_flip`).
- ENV C is dormant, so **ENV B builds them** with ENV C's `tools/audiogen` synth core (read-only for B) via new scripts in
  `tools/audiogen/ui/**`, output in `game/assets/audio/sfx/ui/**`, and registers them in `game/world/audio/cues.tres`
  (co-owned by B for UI-bus entries only while C is dormant). Procedural only, no third-party audio. UI bus, 2D.

## D-091 — 2026-10-13 — Look sensitivity defaults (ENV P, PO-4 feel)
- Default mouse gain 0.0016 rad/count (≈0.092°/count; was 0.0025). ADS/scoped look divides by `CrewView.zoom_factor`
  (PD2 zoom sensitivity: 4× scope → ¼ turn rate). Both stay player-adjustable in Options (B5-01); defaults live in
  ENV P's tweak data. Verified windowed via the real menu flow (env/p-play c1b3c2ad).

## D-092 — 2026-10-13 — Parallel lanes, no idling (product owner)
- Every env runs **several lanes at once**: slow windowed runs go to the background, and independent items run as Agent
  subagents in their own git worktrees (or on disjoint files). The env integrates, runs each lane's targeted tests (D-088)
  and **pushes each lane as soon as it is green**; no batching, and nothing sits unpushed for more than ~1 h.
- Limits on 4 cores: at most 2 windowed Godot processes at once (`--rendering-driver opengl3`, small windows for
  non-visual runs, waits in physics ticks); code-only subagents run alongside.
- Each env always keeps ≥ 2 h of queued lanes and proposes the next ones before the current ones run dry (D-027).

## D-093 — 2026-10-13 — Helpless crew can't soft-lock a heist (QA-PO5-2)
- A TASED / CLOAKER_DOWNED crew member who is not revived within `bleedout_time_s` (30 s, the bleedout tweak) goes to
  **custody**, as if they bled out, **without counting a down** (keeps L2.8 "not a down"). Then L2.9 applies as usual
  (all humans in custody → heist failed; solo with AI per L2.9). pd2_fidelity L2.8 gets a ◇ note. A windowed Glasshouse
  loud run soft-locked with all four crew helpless for 260 s (env/a-core, PO-5).

## D-094 — 2026-10-13 — Viewmodel lighting: key light + `viewmodel_lit` render layer (QP-2)
- Root cause found by ENV P (0cb3e25f): the viewmodel camera's cull_mask also culled every world light, so arms/guns were
  lit by sky ambient only (near-black at night). ENV P adds a viewmodel-only key light (FpViewmodelTweak).
- Option (a) adopted for world lights: render layer 20 `viewmodel_lit` (visual_slots 1.1). ENV P adds it to the viewmodel
  camera's cull_mask and to its own muzzle flash; ENV A tags heist-map key lights and NPC/crew flashlights/muzzle flashes.

## D-095 — 2026-10-13 — `viewmodel_lit` is render layer 21 (supersedes D-094's layer number, QP-3)
- Layer 20 (`1 << 19`) is already the local player's hidden third-person body/mask (CrewView.FIRST_PERSON_HIDDEN_LAYER) and
  levelcheck's PROXY_LAYER. `viewmodel_lit` = **layer 21 (`1 << 20`)**, `CrewView.VIEWMODEL_LIT_LAYER`. visual_slots 1.2.

## D-096 — 2026-10-13 — `dismiss_tip` input action (QB-5); recoil numbers via ENV B data
- New InputMap action `dismiss_tip`: key **H**, pad **D-pad right** (button 14, unused elsewhere). B's onboarding cards
  and any future tip/hint dismissal use it (rebindable in Options).
- Recoil/spread per weapon class: ENV P owns delivery (PD2-like eased kick, no auto-recovery, dff06548); the numbers stay
  in ENV B's WeaponDef data. ENV P sends B a PD2-reference table (first-shot kick, horizontal, hip/ADS spread per class);
  ENV B applies it and keeps the resolver goldens green.

## D-097 — 2026-10-13 — Spread and recoil follow PD2; release e2e check
- Spread/recoil numbers follow PD2 (the project's fidelity rule): ENV B applies ENV P's PD2 table (Lua cites) to WeaponDef
  data, even where it is looser than today (AR ADS ≈ 2.5–3.1° vs 0.8–1.0°). ENV A fixes `combat_tweak` stance multipliers
  to PD2 (standing 1.0, crouched 0.4; the current 0.5/0.75 is backwards). Camera recoil auto-recovers as in PD2 (vertical
  ≈ 0.11 s, horizontal ≈ 0.2 s after one fire interval, vertical accumulation capped at 20°) — ENV P.
  If playtests show it feels wrong, tune through skills/stats, not by departing from PD2 base values.
- **Release e2e (ENV A, 2f7a8991):** `game/tests/a/e2e/run_po5.sh <flow> [seed] [budget_s] [out_dir] [heist] [difficulty]`,
  windowed, real menu clicks, input-only play. `gh_loud` (Glasshouse loud → payday → hub) is the release check the lead
  runs occasionally in the background (~45–90 min on llvmpipe); `gh_stealth` joins when ready; `auto_loud` for any heist.

## D-098 — 2026-10-13 — Stretch aspect "expand"; mod deltas on the PD2 scale
- `window/stretch/aspect = "expand"` (was the default "keep", which pillarboxed 21:9) — **landed in round 55** (B fixed the test's headless 0x0-window assumption, 673150c9). Menu screens cap to a centred 16:9
  column (B's `UiScreen.fit_width`); the HUD anchors to the real window corners (B verifies 21:9 in-heist).
- With PD2 base spread (D-097), weapon-mod accuracy/stability deltas move to PD2's point steps (+4..+12 per mod class);
  ENV B rescales them with goldens. P4 goldens updated by the lead (test_p4_progression test_10/11/14).

## D-099 — 2026-10-13 — Director force model (KR-1 / PO-5.4); specials by difficulty; LMG drift data
- ENV A's director rework (49fd9fad) adopted and folded into pd2_fidelity L1.1/L1.3/L1.4: per-assault force pool → FADE with
  retreat/despawn; alive cap = enemy_cap × crew balance mul (bots count half) × stage 50/75/100 %. Special units follow PD2
  difficulty gating: Routine = regular SWAT + shields only; Stinger (taser) from Tense, Wrecker/Phantom from Brutal-equivalent,
  Corpsman from the Overkill-equivalent tier (ENV A keeps the exact tier map in EnemyDef/difficulty data, cited to PD2).
- Corpses still count in `G.ENEMY` (the "70 alive" was partly that): ENV A removes dead NPCs from the group and despawns
  bodies out of sight in loud (stealth bodies stay, S5).
- **LMG right drift**: a WeaponDef stat `recoil_horizontal_bias_deg` (signed mean of the horizontal kick, per shot; 0 = none),
  data_schemas WeaponStats addition. ENV B adds the field + PD2 values (ENV P has the Lua cites); ENV A consumes it in
  CrewWeapons. Default 0 keeps every other weapon unchanged.

## D-100 — 2026-10-13 — Combat feedback (hit markers, damage direction, low health)
- ENV B's hit/headshot/kill markers, damage-direction arcs and low-health vignette + heartbeat adopted (env/b-content f32eee36);
  four UI cues added to audio_cues 1.6. ui_hud 1.9 adds `LocalHudModel.local_net_id` (ENV A) so markers work in normal play.

## D-101 — 2026-10-14 — ENV P co-owns the first-person arms rig scripts while ENV D is dormant
- ENV P may edit `tools/blender/characters/_arms*` and regenerate `game/assets/characters/char_arms_fp*/**` (owners.json),
  for first-person pose fixes found in play: first the pistol/revolver ADS pose (elbows lower, isosceles PD2 stance; forearms
  angle up from below the frame) and the rifle-family left hand (cup under the handguard). Same pipeline rules as ENV D
  (docs/art/pipeline.md: deterministic Blender scripts, `--threads 1`, no third-party assets), arm-mesh topology unchanged,
  every arms set re-exported together, D's character tests (`game/tests/d/`) kept green.
- Pistol-ADS framing via a per-set aimed viewmodel FOV was prototyped and withdrawn (27 % → 23 % coverage only).

## D-102 — 2026-10-14 — Bag carry follows PD2 (S10.1)
- Faithful PD2 carry values (carrytweakdata.lua, playercarry.lua, ENV P's cites) replace our estimates in pd2_fidelity S10.1:
  speed mult light/medium/heavy/very_heavy = 1.0 / 0.75 / 0.5 / 0.25; sprint only with light bags; jump always allowed with
  jump-velocity mult 1 / 1 / 0.5 / 0.25; throw distance 4 / 4 / 2 / 1.2 m; head-bob scales with the carry speed mult.
- ENV P: CrewTweak + jump mult + head-bob; ENV A: S10 tests and any heist pacing that assumed the old speeds (escape timers,
  objective time budgets in e2e flows). Skills that override carry speed (PD2 does this) stay data-driven.

## D-103 — 2026-10-14 — Next heist: Gallery Night; build plan and rulings
- After the freeze-lift gates (next_heist.md §2), the next heist built is **Gallery Night** (G0 approved, D-075). Build plan,
  audit and rulings: `docs/process/next_heist.md` §3–§6 (NpcVisuals tag priority over EnemyDef, QC-56 dropped, no
  stealth-only fail, marker_tags/viewmodel_lit/D-099/D-102 apply, painting_study $700, ENV A system groundwork first).

## D-104 — 2026-10-14 — ENV C re-activated; ENV D at freeze-lift (product owner approved the lead's recommendation)
- **ENV C (Worlds & Art)** runs again as a cloud session now. Until the freeze-lift gates pass it does non-content groundwork
  for Gallery Night: the floor-plan generator, validate_level `camera_spine` / `camera_screen` (D-075), a slope/parapet rule
  (no walkable slope < 50° outside the play mesh, P's review), a `viewmodel_lit` light check (D-095), and fixing the PP-C-1
  walk test (unmasked LOCKPICK doors, 0 m legs after teleports). Then the Gallery Night greybox (G1) → G2 when the freeze
  lifts. ENV A keeps co-ownership of existing heists' mission scripts / marker_tags / small fixes (D-086).
- **ENV D (Characters)** is dispatched when the freeze lifts and there is cast/animation work (Gallery Night cast is already
  delivered; remaining: admin PA look, any gala ambient clips missing, parked FP left-hand cup).
- P's Gallery Night traversal review (laser gaps, balcony throws, Mews dock height, pool exit, roof slopes, ladders, door
  widths, stair ramps, stanchions, broken windows) is adopted as G1 build requirements (next_heist.md §7).

## D-105 — 2026-10-14 — Product-owner polish pass: impact, effects, doors, dressing (cross-heist)
- Product owner: doors snap (confirmed: door.gd sets leaf rotation instantly), gaps between doors and walls and other small
  clipping / empty-space gaps, gunplay lacks impact (no muzzle flash/tracers; the game has **no particle effects at all**),
  no material debris, and odd prop placement (two chairs facing each other in front of a desk).
- New contract `impact_fx.md` 1.0: surface ids (C), `EventBus.shot_fx` / `explosion_fx` local presentation events on every
  peer (A), VFX library — impact debris + decals + audio per surface, tracers, muzzle flash, shells (C), first-person
  muzzle/tracer/shells (P), effects-quality option (B), door swing animation (A), `door_frame_gap` validate_level check (C).
- Dressing: C audits all four maps for implausible prop arrangements (furniture facing, chairs vs desks/tables, blocked
  doors, floating/clipping) with a levelcheck `furniture_logic` rule where it can be automated, plus screenshot review.
- This polish is cross-heist (lives in kits/systems), so Gallery Night inherits it. It runs in parallel with the
  freeze-lift gates; it does not lift the freeze.

## D-106 — 2026-10-14 — HUD reload indicator; armory stats with skills
- ui_hud 1.12: `reloading` / `reload_progress` (A provides, B draws).
- Armory/loadout stats show values **with the player's skills and perk deck applied** by default (PD2 shows skill-boosted
  stats), with a toggle to compare base values; boosted numbers are marked (B, through LoadoutResolver, no new rules).

## D-107: stamina and jumping follow PD2 (2026-10-14, LEAD; ENV P proposal)
PD2 reference: playertweakdata.lua L341-354, playermovement.lua L238-258/L1092-1107, playerstandard.lua
L1531/L4133-4166/L4670. Faithful, items 1-5 of P's audit:
- Pool 50, drain 2/s running, regen 3/s (unchanged).
- Regen starts **1.0 s** after the sprint ends (`CrewTweak.stamina_regen_delay_s` 3.0 → 1.0); the timer restarts on
  sprint start/stop only, jump drains do not restart it.
- Sprint **start** needs stamina > 4 (MIN_STAMINA_THRESHOLD); a sprint continues until 0. `exhausted` (HUD/net) =
  stamina ≤ threshold and not sprinting (ui_hud field meaning unchanged for B).
- Jumps are **never** blocked by stamina; a jump costs 2 only as a run-jump (running > 0.4 s, above the threshold,
  with a move direction).
- 0.55 s cooldown between jumps; jump pressed while crouched stands the player up instead of jumping.
Owner: ENV P (crew_stamina.gd, crew_controller). One-time carve-out: P updates the two QB-60 tests in A's
`test_qb56_61_modifier_keys.gd` to the new rules (tell A the diff); A reviews on its next merge.

## D-108: police cuffing a downed player has a grace and an arrest time (2026-10-14, LEAD; ENV A proposal)
pd2_fidelity L2.12 kept, with the PD2 feel of a cop walking up and taking a moment: (a) a cop may only start cuffing
once the player has been downed AND not fired for `CustodyTweak.police_cuff_grace_s` (2.0 s ◇); (b) cuffing is a
`police_cuff_time_s` (1.5 s ◇) hold, interrupted if the player fires or the cop is hurt or staggered; (c) both values
in CustodyTweak with tests. ENV A implements; blocking freeze gate 2 (ND loud), where an adjacent cop cuffed the
pilot the same second it went down.

## D-109: briefings show a short objective list (2026-10-14, LEAD; ENV B question)
PD2 briefings stay short and the product owner's first complaint was UI clutter. HeistDef gains
`briefing_objectives` (ordered ids: the main stealth path ending in secure / escape; empty = every objective, today's
behaviour), `briefing_loud_key` (one "If it goes loud: …" line) and `briefing_optional` (listed under an "Optional"
sub-head). B builds the briefing side and sets Gallery Night's values; existing heists opt in where their lists are
long (values sent to whoever owns each def).

## D-110: Gallery Night build starts now; freeze lifted for new content (2026-10-14, LEAD; product owner)
The product owner asked for the other environments to work on new content instead of waiting on gate 2 (ND
`auto_loud`). Gates 1 (gh_loud) and 3 (gh_stealth) passed; gate 2 keeps running on ENV A's clean box at a fixed commit,
so trunk merges cannot disturb it. Its failures since attempt 15 have been harness or crew-AI issues, now fixed (L6.1).
From now on:
- **Lifted:** Gallery Night work per next_heist.md §6 (GN-L1, GN-C1/C2, GN-D1, GN-A1, GN-B1, GN-P1) and the D-103 rulings;
  `env/b-gallery-night` merged; C applies `docs/levels/gallery_night/g1_skeleton.patch` (GN-C1); ENV D is re-activated
  for character/animation work (art-gap brief in docs/status/env_c.md §"Art gaps" items marked [D], plus GN cast needs).
- **Still guarded:** changes that alter shipped-heist behaviour (GH/ND/DB/SL gameplay, AI, combat, net) keep the
  pre-merge targeted tests and must not regress p3_loud / PO-5 flows; ND gate 2 result is still reported and any real
  game bug it finds outranks GN work.
- ENV A runs gate 2 in the background while starting the D-103 §6 system groundwork (each API with a unit test).

## D-111: polish gate before the heist after Gallery Night (2026-10-14, LEAD; product owner)
The product owner: before starting the next heist, the game needs more non-heist content and polish. Gallery Night
finishes first (GN-A1/C1/C2/D1/P1), then these must hold before the next heist's build starts:
1. **Firing range out of "experimental"** (B4-13 full + polish): moving and armoured targets, damage-falloff graph,
   DPS readout, clean layout and lighting, reached from the hub like a real place. Owner B (content/range), map/lighting C.
2. **Menus: clean, uncluttered, consistent** (PO complaint): main menu, hub/stations, Board, loadout/armory, mask bench,
   options, briefing, payday. Owner B; P runs the windowed feel pass; target fewer elements per screen, one visual language.
3. **Animations actually play** (PO: "almost zero animations play"): an audit of which authored clips play in game
   (NPC ambient/activities, reactions, interactions, crew TP, FP actions) versus fall back to idle/T-pose/static. P builds
   the clip-coverage probe; A wires AnimDriver gaps; D authors missing clips. Exit: every clip in characters.md has a
   trigger that fires in a shipped heist, or is marked unused.
4. **More masks and heisters:** D builds new masks and heister characters; B adds their defs, unlocks and bench/selection UI.
   Target set by D's capacity, at least +6 masks and +2 heisters this pass.
Envs with spare capacity start these now (B: menus + range; P: animation audit; D: after the current FP queue);
A and C stay on Gallery Night until it is complete.

## D-112: render light cap raised; weapon/library albedo lifted (2026-10-14, LEAD)
- `rendering/limits/opengl/max_renderable_lights` 32 → 256 (Compatibility, per view). SL has 58 omni lights and GN ~61;
  with 32, the lights that render depend on cull order, so splitting slabs into 6 m tiles (D-111) darkened some rooms.
  The per-object cap (`max_lights_per_object`, 8) stays at the default; maps keep ≤ 8 lights per 6 m tile. Perf is to be
  re-checked on the real-GPU probe; distance-fade on map lights (ENV C) is the follow-up if needed.
- **D-038 amendment:** the shared library's "black" materials (polymer, rubber, anodised/blued metal) move from a
  near-black albedo band (linear 0.018–0.035) to 0.04–0.10 (polymer_black sRGB ~70, steel_blued ~110, metal_matte ~120),
  because weapons and props read as untextured black silhouettes wherever environment reflection is weak (PO feedback,
  round 188 ruling; ENV C 3de44573).

## D-113: more impactful blood/gore and gritty muzzle flash (2026-10-14, LEAD; product owner)
PO: "add some more blood/impactful gore as well as better more realistic/gritty muzzle flash". Part of the D-111 gate.
Today blood is only a mist billboard on flesh impacts, and the muzzle flash is a star + flame + smoke card.
1. **Blood (ENV C, world/vfx; procedural textures only, no third-party assets):** directional spray cone on flesh hits
   (exit-side spurt on penetrating/strong hits, larger on headshots); wall and floor splatter decals projected behind the
   target along the shot (range-limited, pooled, fade over minutes); a growing blood pool under corpses and downed
   bodies; drag smears when bodies are carried/bagged (if cheap); body-bag and corpse decals persist for the heist.
   Caps in VfxSettings so co-op and Compatibility stay in budget.
2. **Muzzle flash (C third-person / world; P first-person viewmodel):** randomized multi-petal flash (3–4 texture variants,
   random roll/scale per shot), a hot core + longer side petals per weapon class (shotgun wide, rifle long, pistol short),
   brief spark streaks, a lingering smoke wisp that drifts, short heat-coloured light pulse (existing 0.05 s light).
   Suppressed weapons keep a tiny puff. FP and TP should match.
3. **Hooks (ENV A):** hit events must carry headshot / penetration / strength so C can scale gore; a corpse/downed
   "bleed" hook for the pool. 4. **Option (ENV B):** Options → Gameplay "Blood & gore: Full / Reduced / Off".

## D-114: PO playtest list 2026-10-15 is top priority; LEAD handover to a new session (2026-10-15, LEAD; product owner)
The product owner played Golden Hour (in-world name "Vossberg Jewelers", heist id `glasshouse`), other heists and the
firing range, and filed the list in `docs/process/po_playtest_2026-10-15.md` (items PO6-01..PO6-19, each with an owner,
a spec and acceptance). Those items go **ahead of every other queue item**, including the 2026-10-14 handoff list,
except the two open PO complaints already in flight (FP black-gun material, long-gun support grip), which are folded
into the list as PO6-10/PO6-09. Rulings made with it:
1. **Golden Hour stealth never needs the drill.** The manager-office safe gets a silent stealth path (PD2-style: the
   manager's code/keycard opens it; lockpicking is a slow fallback). The drill stays the loud path. A running drill is
   a noise source that guards/civilians can hear and investigate; it is not an instant alarm, and cameras react only
   to what they see.
2. **Drill jams follow PD2:** at most 1-2 jams per standard drill, fewer with upgrades; never a jam in the first or last
   10 % of progress. Values stay in `interaction_tweak` (data, not code).
3. **One-shot audio is one-shot.** Pager beep, sirens and alarm bells stop when their source state ends (pager answered
   or expired, assault phase over, alarm cleared). A loop flag on a cue needs an owner that stops it.
4. **Pager (amended by the PO, 2026-10-15 18:10):** the countdown freezes the moment a player starts answering and
   stops for good when answered. **Releasing early raises the alarm** (PD2), **unless juggled**: the release is
   forgiven only when the same player starts answering another live pager within 0.5 s (pager juggling); the released
   pager then resumes its remaining countdown and must be answered later. `StealthTweak.pager_release_resumes`
   defaults to false. A pager that goes off must be easy to find: the guard's body gets a **yellow outline** (visible
   through walls within ~15 m, PD2 contour) and a HUD waypoint while its pager is live (PO6-20).
5. **Loud waves are horde-paced (PD2 assault):** continuous spawning to a force cap during sustain, units path *into*
   rooms players hold (no idling outside doors), plus RNG assault events per heist: turret van, helicopter
   (sniper/rappel drop), and breach points (marked wall/ceiling/window spots cops blow open mid-loud).
6. **Bot crew** must catch and carry thrown bags and be toned down (PD2 bots: weaker damage, cannot carry the run).
7. **Death and bodies:** death animation picks from the pose before death (standing / crouched / kneeling-cuffed /
   prone / downed); never stand a body up. Explosions and shotguns at close range impart an impulse (physical bones
   ragdoll, or a scripted body push where ragdoll is too costly); corpses accept small hit impulses and bleed at the
   hit point (D-113 VFX).
8. **Muzzle flash is toned down** from D-113 (smaller, shorter, less light), and long guns get a muzzle-brake/
   compensator mesh at the barrel tip that the flash emits from. Marker rule (round 205): the brake node carries its own
   `Muzzle` marker and the outermost `Muzzle` wins (no code change); optional `MuzzlePortL`/`MuzzlePortR` for side ports.
9. **Team:** the previous sessions are not reachable from this account; the new LEAD (session_01XAPqmFJ32zHKLK9Sezymym)
   spawns fresh A, B, C, D and P sessions (board Sessions table).

## D-115: finish every existing heist before a new one (2026-10-15, LEAD; product owner)
PO: "flesh out every existing heist as previously documented before adding new ones." No new heist (Ostrander Federal,
Afterhours, Rolling Thunder; `docs/process/next_heist.md` §1) starts until all five existing heists meet their own design
doc (`docs/design/heists/<id>.md`) and the D-111 polish gate. Per heist "done" = (1) every objective, variant, loot,
door/lock table and NPC role in the design doc exists and works; (2) final art (G2) with lighting and props, no greybox;
(3) a windowed e2e flow for each mode the heist supports (stealth and/or loud) passes on the real menus; (4) a PO-6-style
windowed real-input pass by ENV P with no STUCK/snag rows; (5) briefing, strings, music, VO and HUD markers complete;
(6) assault events (D-114 §5) defined for the heist (N/A for stealth-only heists such as Shadow Ledger, PD2-style; ruled 2026-10-15). Gap lists live in `docs/process/heist_completion.md` (LEAD).
Order: Gallery Night (G2 + e2e) → Dockside Burn and Shadow Ledger (G2 + mission audit) → Night Deposit gate 2 → Golden
Hour polish. The PO6 list stays top priority until it is closed.

## D-116: first-person pistol framing follows the PO's reference shots (2026-10-15, LEAD; product owner)
PO: holds "look better but still largely inorganic", with two reference images (`docs/process/po_shots/
2026-10-15_ref_pistol_hip.png`, `..._ref_pistol_ads.png`). Read as the target for pistols/revolvers:
* **Hip:** one-handed. Firing arm enters from the bottom-right corner (wrist + a short length of forearm visible, no
  sleeve wall); gun in the lower-right third (grip ≈ x 65 %, y 85 %, muzzle ≈ x 60 %, y 62 % of the screen), yawed
  ≈ 12-15° in toward the screen centre, muzzle slightly up, gun reads large and close. No support hand on screen.
* **ADS:** gun dead centre, rear sight on the crosshair, viewed straight down the slide (back of the slide and both
  sights read clearly); the firing hand's knuckles/thumb fill the bottom centre directly below the gun; no forearms
  beyond the wrist cuff; no support hand on screen.
* **Organic motion (all weapons):** the gun lags the view on mouse turns and springs back (inertia, small overshoot);
  figure-8 walk bob tied to footsteps, larger when running; a slow breathing idle; a landing dip; recoil kicks up and
  back then recovers on a damped spring; ADS in/out on an arc with a slight settle. No rigid locked-to-camera frames.
This supersedes the two-handed pistol hold of PO6-11 for the first-person view (third-person characters keep their
two-handed pose). Owners: P (viewmodel offsets, motion, tweaks), D (one-handed pistol/revolver clips if needed).
Acceptance: side-by-side sheet against both references, hip and ADS, for every pistol and revolver, plus a short
windowed motion clip (turn, walk, run, jump-land, fire, ADS in/out).

## D-117: content-audit rulings (2026-10-15, LEAD; from ENV B's D-115 audit)
1. **Heist display names** follow the design docs: "Golden Hour" (id `glasshouse`, location "Vossberg Jewelers") and
   "Nightfall Depository" (id `night_deposit`). Ids never change; B aligns the `heist.<id>.name` strings, C the docs.
2. **Lethal / Cataclysm** stay in the game: unlocked by progression (Lethal after any heist won on the top currently
   pickable difficulty, Cataclysm after a Lethal win), never hidden by `unlocked_difficulties`. B implements the unlock
   + UI; doc content for those tiers stays.
3. **Docs follow data where the data is deliberate:** ND "ECM drop" asset is dropped from the doc (ECM is a deployable);
   GN escape options = [van, limo] (doc fix); loot weights in docs follow the data (ND cash_bricks MEDIUM, SL
   ledger_books / painting as in data). C edits `docs/design/heists/**`; `glasshouse.md` §Objectives gains `[code]`.
4. **Localized briefings:** heist defs reference `heist.<id>.briefing` keys, never literal strings (C fixes the GH/ND/SL
   generators; GH gets `code`, a briefing_objectives list and briefing_optional: extra bags, salon, display cases).
5. **Briefing objective list (GN-U5):** show the first 5 steps of the heist's objective list, then always its final step
   (secure/escape), with a "+N more steps on the night" line between when steps are cut; cap 6 rows.
6. **Mission VO:** every written mission line is either said by the mission script or deleted; A wires GN's 17 unsaid
   lines, SL's camera warning and GH's code-found line; DB's briefing lines play only on the briefing screen (ctx.source).
7. **Music:** every built heist gets its own stems (C: ND, SL, DB, GN; SL stealth bed + abort sting).

## D-118: weapon gadgets and shotgun ammo types are in scope (2026-10-15, LEAD; from ENV B's weapon audit)
PD2 fidelity: weapons get GADGET mods (laser sight, flashlight, combo) and shotguns get AMMO mods (slug, HE, flechette,
dragon's breath / incendiary), with real behaviour, not only stat deltas.
* **B:** gadget + ammo mod defs, models (rail-mounted laser/light units; shells shown in the ammo icon), stat deltas, strings,
  workshop UI; plus the audit's slot gaps (shared rail vertical grip, stocks, pistol grips, muzzle devices, shrike suppressor).
* **P:** gadget toggle input (default key B), first-person rendering: laser beam + dot (visible to the owner and teammates),
  flashlight cone with real light (shadows off, range ~25 m), on/off state per weapon, kept through swaps.
* **A:** third-person + network: gadget state replicated, [CORRECTED below: not a detection stimulus, S4.2] enemies/cameras can see a laser or flashlight in stealth (detection
  stimulus, PD2-style), ammo runtime: slug (armor pierce, shield pierce), HE (small explosion via Explosion.apply, no
  penetration), flechette (more pellets, bleed-like DoT), dragon's breath (fire DoT, panic civilians); ammo pickup multipliers
  as data.
* Values in data (WeaponStats / tweak), documented in pd2_fidelity.md (C-owned doc rows via the LEAD).

## D-119: revert the PO6-10 gun look (2026-10-16, LEAD; product owner)
The PO saw the flat light-grey first-person guns in the D-118 gadget captures and asked for the earlier look back. PO6-10
("FP weapons render near-black") is **reverted** and closed as won't-fix:
* **C:** restore the gun finish parameters from before 68b4e770 (alu_anodized_black, metal_matte, steel_blued, gsr preset)
  and regenerate their textures. The test/audio files in that commit stay.
* **P:** the viewmodel gun fill light is off by default (`FpViewmodelTweak` gun fill energy 0, hip and ADS). The code stays
  so it can be re-enabled, but nothing in the game turns it on.
* Acceptance: windowed Glasshouse hip shot of the Corsair and the Kestrel side by side with
  `game/assets/characters/_review/grip_glasshouse_corsair_ar_hip.png` (black guns), reviewed by the LEAD.

### D-118 addendum (2026-10-16, LEAD): shotgun ammo values and per-shot damage
* **Values:** B's AMMO mod params are the data and override A's `CombatTweak.shotgun_ammo_defaults` placeholders:
  HE radius 2.0 m; flechette pellets_mult 1.5 with a 4/s bleed; dragon's breath 8/s; range_mult 0.7. A keeps its defaults
  only as fallbacks for missing keys.
* **Per-shot damage is preserved when the pellet count changes.** ShotgunAmmo scales per-pellet damage by
  stock_pellets / new_pellets. A slug (1 pellet) therefore hits for the stock shot's full damage in one ray, and an HE round
  splits nothing. Flechette's extra pellets share the same per-shot total. Mod `damage` deltas stay per-pellet on the stock
  count, so they also scale with the rule. This is PD2's model: listed damage is per shot, and the ammo changes how it is
  delivered.
* **Pistol SideRail** is the dust-cover rail and its outward axis points down, so pistol gadgets hang under the barrel
  (visual_slots.md).

## D-120: heist economy follows PD2's "greed pays" shape (2026-10-16, LEAD; from ENV B's payout pass)
Bags were 8–20 % of a full clear (contracts $40–110k vs bags $0.7–2.8k), and the broker's flat cost could reach 69 % of a
Cataclysm full clear. Approved, and it lands in **one round** (B 49d0171b + C's base_payout change together):
* **B (data):** bag values ×4–5, keeping PD2's order (gold 14k > crate 8.5k > bricks/books 8k > drives/parcels 7.5k >
  contraband/bonds 7k > cash 6.5k > jewelry 6k > laptop 5k > SL painting 4.5k; GN canvases 8k/6.8k/6k/5.2k per D-075's
  ratios; study 2.8k). Broker flat part [4k, 8k, 14k, 30k, 60k, 90k] + 10 % of the scaled contract. Level gates, civilian
  penalty and difficulty multipliers are unchanged.
* **C (maps):** base_payout GH 12k, ND 26k, SL 70k, DB 24k, GN 57k. GH display cases point their `loot_id` at an id with no
  loot def (as GN's vitrines do), so a case is not paid as a jewelry bag.
* **Result:** full clears within ±10 % of before (DB +20 %, by design: 16 bags); bags are 39–81 % of a full clear; minimum runs
  roughly halve; the broker costs 4–20 % of a full clear and never more than the run pays.
* Supersedes the payout values in QC-5 (GH $40k) and D-081 (study $700). B publishes the full per-difficulty table in
  pd2_fidelity.md via the LEAD.

### D-118 correction (2026-10-16, LEAD): gadgets are NOT a detection stimulus
pd2_fidelity.md S4.2 holds: PD2 guards and cameras ignore flashlights and lasers. The D-118 line "enemies/cameras can see a
laser or flashlight in stealth" was wrong. ENV A sets the StealthTweak "Weapon gadgets (D-118)" multipliers to **0** by default.
The code stays behind the tweak, and nothing in the game enables it. The third-person beams and lights stay (visual only).

**D-120 addendum (2026-10-16): a failed heist pays nothing and costs nothing.** Civilian cleanup costs are charged only
against a successful payout; a failed payday shows $0 and no cleanup line, matching "A failed heist pays no cash".

## D-121: loud-path determinism rules (2026-10-16, LEAD; from ENV A's DET audit)
* Heist navigation runs synchronous map/region iterations (`HeistRuntime.use_sync_navigation`; launch option `nav_sync`
  false opts out). Async iterations made door/breach link changes land on a timing-dependent frame.
* Gameplay never reads positions of nodes animated on render frames: shot origins, noise origins and "nearby shot" drama
  use the shooter's eye/body position; muzzles and lasers are for FX only. This includes crew_weapons' server noise origin.
* **Corpses (PO6-19):** the server keeps a deterministic corpse anchor (pose-at-death position plus an analytic impulse
  offset) and puts the body-bag interaction, corpse stimulus, despawn and server corpse hitbox on that anchor. The physical
  ragdoll is cosmetic. Shots still nudge it and it still bleeds where shot, locally.
* Thrown and dropped bags stay server-authoritative physics with a replicated rest position. Exact cross-process replay of
  bag rest positions is not required.
* Replay tests compare traces from a fresh process; a real-input pilot driven by wall-clock menus is exempt.

## D-122: police-only breach navigation (2026-10-16, LEAD; from ENV C's GN bronze-doors finding)
A loud-breachable locked door links on `Door.NAV_LAYER_BREACH` (navigation layer 2, "npc_only"). Police and specials path
through it (AssaultDirector._path_cost includes it). Crew, bots, civilians and the test pilot query layer 1 only, so they
treat a closed, locked door as blocked. Test: `test_d122_breach_nav_layer` (ENV A).

## D-123: limb hitboxes for hit reactions only (2026-10-16, LEAD)
NPCs get LIMB hitboxes (upper arms, thighs) so D's shoulder/leg flinch clips can trigger. A LIMB hit takes the BODY damage
multiplier (1.0) and counts as a body hit for every rule (headshot rules, armor, and so on), so PD2 damage is unchanged.
Flinches play through the existing UpperBodyLayer (spine-up) while moving and full-body only when standing still.

## D-124: weapon balance pass (2026-10-16, LEAD; from ENV B's audit game/content/docs/weapon_balance.md)
Approved, all data-only (ENV B applies them in one commit, reruns the tool and updates pinned tests):
P1 tern_556 concealment 21→24, spread_ads 2.7→2.1; P2 bastion_br damage 100→110; P3 falchion_dmr damage 150→120;
P4 marshal_357 rpm 330→230 with the 2.4 s reload kept (amended 2026-10-16: the revolver clips pin the reload; 235 tied the weakest AR at 253 DPS, 230 gives 251 and clears the SECONDARY-DPS flag); P5 wren_380 mag 7→10, total 98→160, rpm 520→600; P6 hush_9
concealment 21→25; P7 vise_crossbow damage 350→450; P8 akimbo_warden_45 total_ammo 128→144; P9 cyclone_rotary pickup
15–30→10–20; P10 reaper_db 19→22 per pellet (Heavy one-shot breakpoint).
Shape kept (PD2): no early weapon best in class; LMGs have the best ammo economy; every sniper out-damages every AR per
shot; secondaries stay below primaries of the same role. ENV A reviews the Wrecker's Cataclysm HP scaling (×12 against
the Heavy's ×4) against PD2's Bulldozer, and adds carry-over for fractional ammo pickups.

**D-124 addendum (2026-10-16, after D-127): keep the Heavy SWAT breakpoints.** P11 bastion_br damage 110 → 135, with rpm
scaled down so its sustained DPS stays at about its D-124 value (~395), keeping the 2-headshot Heavy breakpoint. P12 reaper_db 22 → 27
per pellet (the point-blank double-barrel one-shot). P13 heron_308 230 → 270 (the entry sniper one-taps a Heavy's head, as in
PD2). No other weapon changes for D-127.

## D-125: Wrecker HP curve (2026-10-16, LEAD; from ENV A's review of B's D-124 audit)
Wrecker HP per difficulty (ROUTINE..CATACLYSM) becomes 2000 / 2000 / 3000 / 4500 / 7000 / 10000 (×5, was ×12 up to
24000), so the Wrecker:Heavy ratio goes 12.5 → 15.6 instead of 12.5 → 37.5. wrecker_b/g/s share it; wrecker_m stays
2× (4000 / 4000 / 6000 / 9000 / 14000 / 20000). Plates (150 / 160), head ×2.5, explosive ×1.1 and the damage table are
unchanged. PD2 shape: tanky, killable by an AR player through the visor with headshots at about half the reserve, and
not by body fire alone. ENV A pins the table, the ratio and a Corsair head-route budget in a test; ENV B re-runs the
balance tool after landing and reports the "solo within reserve" count.

## D-126: the secondary slot holds pistols, SMGs and shotguns (PO, 2026-10-16)
The PO's playtest: SMGs and shotguns belong in the secondary slot with the pistols. Every SMG and every shotgun
(plowman_12, brute_12, harrow_12, reaper_db, mule_12) has `slot = SECONDARY`. Primaries are assault rifles, LMGs, snipers
and specials. ENV B owns the data, the armory/loadout filters and the class tabs, and checks that the real loadout screen
offers all of them as secondaries from a fresh profile (unlock levels apply as before). Ammo pools stay per weapon (D-118
values). ENV A checks crew-AI loadouts, custody and downed (downed equips the secondary: a downed player with a shotgun
secondary may fire it, PD2 bleed-out). ENV P checks the FP viewmodel and the swap paths for a secondary long gun.

## D-127: enemies get a little tougher (PO, 2026-10-16)
The PO's playtest: NPCs die too quickly. Every non-special enemy (guards, beat cops, SWAT, heavy SWAT, FBI, cartel gunmen and their
variants) gets +25 % health on every difficulty. Head and limb multipliers, armor, damage and accuracy are unchanged.
Specials keep their tuned values (D-125 Wrecker HP is not re-scaled). ENV A owns the enemy tweak data and pins the new table
in a test (the D-125 Wrecker:Heavy ratio test moves to the new Heavy HP). ENV B re-runs the balance tool, with
shots-to-kill per class against a Heavy SWAT, and flags any weapon that falls outside the PD2 class shape. Civilians
are unchanged.

## D-128: detection follows PD2's formula and its ring indicator (PO, 2026-10-16)
The PO's playtest: detection is too forgiving, and should mirror PD2's formula and its detection icon/ring. This replaces
our ◇ design choices in pd2_fidelity S2 with PD2's behaviour wherever PD2's is known:
* **Formula (ENV A).** Use PD2's detection presets and per-tick progress (the delay interpolated between the near and far
  ranges, the angle term, the player's concealment-derived detection multiplier, the per-observer-type presets for
  guards / civilians / cameras / police, and PD2's close-range uncover behaviour). Take the decay of the meter when
  line of sight breaks from PD2 too. Our deviations go: the ×0.75 crouch multiplier (◇), the 0.25/s decay (◇), the 0.45
  angle floor and the 0.1 distance floor, unless PD2 has the same term. Casing-mode rules (S1.1) stay. ENV A researches
  PD2's actual values (the game's character detection presets and attention logic; cite the source in the S2 rows),
  lands them in `stealth_tweak.tres`, and pins point-blank / mid / far fill times per observer type and DR in a test.
  Where PD2's value can't be found, A picks the less forgiving option and marks it ◇.
* **Indicator (ENV B).** PD2's detection HUD: over each observing NPC, a circular ring that fills clockwise as the
  meter rises, with "?" inside while filling, turning into the red "!" at 100 %. Around the crosshair, one arc per
  observer, in the observer's direction, filling the same way. Colours run white → orange → red. It replaces the
  blue/orange chevrons in S2.1. Cameras use the same ring.
* **Feel check (ENV P).** A windowed real-input stealth run on GH and SL after both land: detection should feel like PD2,
  with lingering in a guard's view punished quickly and a clean, careful route still possible. Report fill times seen.
The LEAD rewrites the S2 rows from A's sourced table when it lands.

## D-129: LEAD handover to a new session; fresh env team (2026-10-16, LEAD; product owner)
The previous LEAD (session_01XAPqmFJ32zHKLK9Sezymym) and its five env sessions ran in another account and are
unreachable from the new LEAD (session_01HwYKRgCdkLfJCt4ZM6rfTk). They stopped ~16:30 UTC with round 229 merged on
`claude/epic-fermi-k5fa09` but not gated. The new LEAD:
* keeps trunk = `claude/dreamy-hamilton-pc7vck` and every rule in force (D-086 team v3, D-088 targeted checks, D-115
  heist completion before any new heist);
* spawned five new env sessions (A, B, C, D, P; ids on the board) from each env branch's origin tip; any lane that was
  only in an old container is lost and is re-queued from the status files and `docs/process/heist_completion.md`;
* gates round 229 = the old LEAD's merges (epic-fermi, incl. characters v1.26) + the env commits pushed after them
  (B 0ddba6f8, C 80eeb5a8, D 0e4e2a0f).
Answer carried to ENV P: D-116 stands, first-person pistols/revolvers are one-handed; third person keeps two hands.
Next heist after D-115 closes: Ostrander Federal (`docs/process/next_heist.md` §1), planning only until then.

## D-130: difficulty shapes stealth by heist size; cameras detect faster (2026-10-16, LEAD; product owner)
PO: "difficulty affects how many guards/civs there are for the larger heists in stealth (gallery, ledger) and, in smaller
maps (jewelers), it reduces the total amount of pagers and makes cameras indestructible like PD2 does; cameras also need
to detect the player a little bit faster." Size class = the design doc's `Size` line (S: Golden Hour; M: Night Deposit,
Gallery Night, Shadow Ledger; Dockside Burn is loud-only, so N/A).
1. **M stealth heists (GN, SL, ND): population scales with difficulty.** Guards *and* civilians. Routine = the design doc's
   baseline count; each tier adds, reaching about **+50 % guards and +35 % civilians at Cataclysm** (Tense ≈ +10 %,
   Hazardous ≈ +20 %, Brutal ≈ +30 %, Lethal ≈ +40 %; round to whole NPCs, guards first). Extras come from real spawn
   points with their own patrol routes / work spots, never doubled-up posts. Data: the heists' variant-table
   `difficulty_add` rows (guard_extra / civilian groups) and generator spawn points: **C**. Runtime: A checks the spawner
   and VariantResolver apply `difficulty_add` to civilian groups as well as guards, that director caps (D-099) don't clip
   stealth spawns, and pins per-heist guard/civilian counts for Routine and Cataclysm in a test. ND is included because it
   is the same size class; GH keeps its current small `difficulty_add` rows.
2. **S heists (GH): fewer pagers by difficulty.** New `HeistDef.pager_max_by_difficulty: Array[int]` (indexed by
   Enums.Difficulty; empty = `StealthTweak.pager_max_answers`, 4). Golden Hour: **[4, 4, 3, 3, 2, 1]**. A's PagerSystem
   and LocalHudModel `pagers_max` read it (the HUD and the `mercer.pager_limit` bark follow automatically). Value: C (GH
   generator row). Other heists stay at 4.
3. **S heists (GH): Titan cameras earlier.** New `HeistDef.camera_titan_min_difficulty: int = -1` (-1 = the tweak default,
   LETHAL, PD2's top tiers, unchanged for every other heist). Golden Hour: **HAZARDOUS** (indestructible from the third
   tier up). A's `SecurityCamera.is_titan()` reads the def first. Value: C. B: the briefing/difficulty card says "Titan
   cameras" and "N pagers" when they apply (strings + a line in the briefing intel).
4. **All cameras detect about 20 % faster (◇ vs PD2's editor defaults).** StealthTweak camera preset
   `delay_min` 2.0 → **1.6**, `delay_max` 3.0 → **2.4** (range, FOV and weights unchanged). A updates `stealth_tweak.tres`,
   the S2 row note and the D-128 pinned fill-time test. P includes cameras in the D-128 feel check.
Contract: data_schemas v1.3 (HeistDef fields). Acceptance: A's count/pager/titan unit tests; P's windowed GH stealth run on
Routine and Lethal shows the pager count on the HUD and a camera that can't be shot; LEAD looks at the shots.
**D-130 addendum (round 229, camera range):** A's D-128 prefab default `range_m` 15 m (PD2 editor default) stays for
cameras without an override; the map generators' explicit 20 m per camera stay too (authored range, and in line with
the PO's harsher-cameras ask). The round-229 merge regenerates GH/ND/SL/GN scenes so they match their generators.
**QD-1 (D, 2026-10-16):** FP pistol/revolver web-of-hand vertices 1.7-4.0 mm into the tang/beavertail are accepted as skin
compression on a high grip; the hand seat stays (D-116 sight picture); d/test_fp_pistol_thumb guards at 4.5 mm.
**QB-1 (B, 2026-10-16):** heist-specific escape radio lines that a mission escape say() always covers are deleted; the
generic escape lines stay as the fallback. B's briefing_objectives lists for GN/DB/SL approved (C edits the generator rows).
**D-128 addendum (B, 2026-10-17):** an observer whose world ring lands on the crosshair arc band draws no crosshair arc
(the ring already marks that spot); every other observer keeps its arc. Ring/arc sizes live in `hud_tweak.tres` (B 98c39e44).

## D-131: aimed (ADS) spread multiplier (2026-10-17, LEAD; from ENV A's accuracy test, B's 372f3bd7 finding)
A's test (100 seeds, real hitscan, ADS, standing still, guard chest at 10 m) hits 92/100 with kestrel_p9's
`spread_deg_ads` 2.3; 18 weapons sit above that (up to 4.0), so most pistols/SMGs miss aimed torso shots at 10 m. PD2's
steelsight spread is well under its standing spread; an aimed pistol at 10 m does not miss a torso.
Ruling: a single runtime multiplier `ads_spread_mult = 0.7` (◇, ENV A's CrewWeapons tweak) on `spread_deg_ads`, so each
class keeps its shape and B's weapon data stays as is (2.3 → 1.61°, 100/100 in A's sweep). Acceptance: A's
test_l3_ads_pistol_accuracy at ≥ 98/100 for every pistol and revolver at 10 m; SMGs reported, not gated. B reports any weapon
whose ADS readout in the armory needs the multiplier shown (stat display = effective cone).

## D-132: character render/animation budget for D-130 crowds (2026-10-17, LEAD; from ENV D's perf audit)
Audit: `docs/art/d130_character_perf_audit.md` (D 53fa7154, bench `world/characters/_tools/bench_crowd.tscn`). Live skinned
characters at Cataclysm: GN ~35, SL ~20, ND ~16, any loud Cataclysm fight ~50. Triangles are fine; **draw calls dominate**
(16-32 surfaces per character, each again per shadow pass: GN ~1011 draws/frame, loud ~2860); animation ~0.07-0.1 ms per
character at every distance.
Approved, in order: (1) **D2** LOD2 from 15 m for civilians/staff, 25 m for combat units, and **D3** no shadow casting from
tiny surfaces (badges, glasses, buttons): measured GN 1011 → 489 draws. (2) **D1** per-character material atlas (surfaces
16-32 → 1-2; est. GN ~150, loud ~600 draws), supersedes D3; acceptance = before/after lineups at 2/10/30 m with no visible
change, test_lod/test_scenes/test_npcs green, P's vm/arms probes unaffected (FP arms keep their own materials).
(3) **ENV A animation LOD**: full rate < 15 m; every 2nd frame 15-30 m with IK off; every 4th > 30 m or off screen; paused
off screen > 30 m; staggered per NPC; clip events kept on a timer so footsteps/barks/hand props still fire; never applied to
crew AI or anything a player is aiming at. Est. GN 3.3 → ~1.3 ms, loud 5 → ~2 ms; test: event parity over a 30 s bench.
Real-GPU numbers are still unmeasured (open risk, handoff §4.14); these counters are exact on llvmpipe.
**D-130 addendum (C a5f115c1, 2026-10-17):** targets are met on the **expected** count per tier (1500-seed rolls on the real
maps); on tiny bases the maxima may rise more than the % (ND guards max 3 → 5). Counts never fall with difficulty and
never fall below a tier's pre-D-130 value (QC-b). D-130 §1's +50 % / +35 % are floors, not caps: GN's existing guard
curve (1.8 → 5, ruling 2) stays (QC-a). ND Hazardous+ rolls can exceed the 4-pager cap; accepted (PD2 has the same pressure).

## D-133: loud e2e gates may use a harness-only damage option (2026-10-17, LEAD; from ENV A's DB-7 / GN runs)
The windowed `auto_loud` pilot reaches every loud objective (DB: breach, product, burn, cartel, thermite carry; GN: hack,
vault drill) but loses the fight before the end-game, so no loud heist can show a full windowed win, while the mission flow
itself has no errors. D-115 item 3 is a **flow** gate (objectives, transitions, escape, payday), not a difficulty check
(difficulty feel is P's real-input pass, item 4). Ruling: an e2e gate run may set a harness-only dev option
`crew_damage_taken_mult` (ENV A; default 1.0, only settable through the e2e launcher's options, never from menus or
saves, logged in the run header) to **0.25**, on Routine, with assault events ON. Full immunity and turning assault events
off are not allowed. The evidence names the option. A mission run that passes this way closes D-115 item 3 for that heist.
**D-132 addendum (D 87e7bf4b):** D2 landed (LOD2 at 15 m crowd / 25 m units: GN 1011 → 738 draws, loud 2860 → 2524). D3 is
folded into D1 (Godot casts shadows per node, not per surface). D1 becomes shared Texture2DArray tiers (256²/512², repeat
wrap) + one ShaderMaterial per merged node instead of a flat atlas (189 uniform ORM materials, tiled UVs up to 3.75),
crowd + unit characters only; checks: Compatibility lighting/shadows/fog/viewmodel_lit parity, outline + bleed next_pass,
ragdoll/HandProps, VRAM, 2/10/30 m lineups; per-character fallback switch.
**D-128 feel check, Golden Hour (P 6e3c49d3, 2026-10-17):** guard at 4.3-4.9 m fills in 1.13 s (formula 1.17-1.24 s);
civilians within 5.5 m uncover instantly; camera C4 at 4.95 m (D-130 presets) 3.89 s (3.85-4.07), decay 1.23 s (1.17); a
careful crouched route keeps every meter at 0.00. All within ~5 % of A's formula; verdict: feels like PD2. Pending: GH
Lethal (Titan, cap 2), 10 m camera fills, the SL leg.
**D-130 addendum (C b7cfb928, SL):** SL civilians end at +75 % at Cataclysm (pre-D-130 SL already ran +45 % from Brutal and
no tier may fall; SL's test cap is 1.9x, GN/ND keep 1.5x). SL guards stay flat at 5 for Lethal/Cataclysm (QC-e), as GN.
New SL civilian group late_staff (one seated late worker, chance 0/25/25/33/44/67 % by tier).
**D-132 addendum 2 (D1 parked, 2026-10-17):** D1 is done and verified on `wip/d-d1-merge` 78098c11 (fallback list, lighting
diff 0.003, outline/ragdoll/hand props OK, lineups identical at close/30 m) but measured GN 738 → 499 draws (-32 %), loud
-12 %, with llvmpipe frame time only -2 % (829 → 814 ms), for +29-45 MB VRAM and ~194 MB of committed merged meshes.
Ruling: **park D1** (keep the branch, do not merge) until a real-GPU measurement shows draw calls bind; D2 and A's
animation LOD stay. Real-GPU probe: ask the product owner to run the bench (`world/characters/_tools/bench_crowd.tscn`)
on their machine, D1 on/off; land D1 (option A, or B if it binds hard) only on that evidence.
**D-132 addendum 3 (A e6ee87d9, animation LOD):** AnimLod bands FULL < 15 m on screen / NEAR 15-30 m every 2nd frame, IK off /
FAR > 30 m or off screen every 4th frame, layer off / PAUSED off screen > 30 m; staggered by net_id; skipped time advanced
on the due frame. Bench 34 NPCs: 2.69 → 1.49 ms/frame (-45 %), event parity within one cadence step. Rulings: (a) TIED is
LOD'd (steady pose), surrender transitions exempt; (b) "aimed at" = within 2 m of a crew aim ray; (c) "on screen" =
frustum check without occlusion; (d) a paused body catches up its clip events on resume (fine under D-121).

## D-134: taking damage does not cancel a revive (2026-10-17, LEAD; from ENV A's ND-1 analysis)
ND-1 (×1.0 and ×0.25) both end in custody at t≈577: the pilot goes down carrying a bag, two AI bots stand inside revive
range, but every hit restarts their 6 s revive (`InteractionSystem.interrupt_on_damage`, pd2_fidelity S9.1), so nobody is
revived before bleed-out. PD2: being shot does not cancel a revive (only going down, a tase, a stun/flash or letting go
does), which is why reviving under fire is the bots' and players' core job.
Ruling: **(b)**: a revive in progress is never interrupted by damage, for humans and AI bots alike (interrupted by: the
reviver going down, tased, stunned/flashed, moving out of range, or releasing). For **other** hold interactions S9.1 stays
until ENV A source-checks PD2 (playerstandard / interaction ext: does damage cancel a held interaction?); A reports the
finding with a citation and I amend S9.1 then. Test: a bot and a human revive complete under continuous fire; a tase
still cancels.
**D-134 addendum (LEAD source check, 2026-10-17):** steam-test1/Payday-2-LuaJIT-Complete `lib/units/beings/player/playerdamage.lua`
`damage_bullet` (l.1290-1466) never interrupts an interaction; `interupt_interact` is called only when the active unit can
no longer be interacted with (swansong path, l.2191) and by `PlayerStandard:exit` (l.309: a state change such as downed,
tased, arrested). So in PD2 **damage cancels no held interaction**, not only revives. S9.1 amended: damage never cancels
any hold interaction (humans and bots); the flash/stun cancel stays as ◇. ENV A removes the damage interrupt for all holds.

## D-135: close the queue, then start Ostrander Federal together (2026-10-17, LEAD; product owner)
PO: "finish all currently queued work and instruct each environment to do so together." No new scope enters any env's
queue from now on; each env closes its open `heist_completion.md` rows and in-flight lanes and reports QUEUE CLEAR (last
sha + anything that cannot close, with the reason). When all five have reported and the LEAD has merged and gated the
final round, the D-115 gate is assessed and Ostrander Federal (`docs/process/next_heist_ostrander.md`, finalised by the
LEAD meanwhile) starts for all envs at once with one kickoff dispatch. Parked items that do not block: D-132 D1 (waits on
the PO's real-GPU bench run).

## D-136: Ostrander Federal build rulings (2026-10-17, LEAD)
The OF-L1 build plan (`docs/process/next_heist_ostrander.md`) is approved. Its §3b rulings 1-11 are adopted as written:
vault on the ND pattern (no new Safe API); manager keycard = QC-52 carrier_tag at 1 s; D-120 re-price by B; a general
`CivilianRoute` system (A) for timed cross-floor civilian routines; the SD customer escort descoped; assault events
(turret van, heli rappel, breach points) added; D-122 breach layer on every loud-breachable shell door (not the vault);
D-102/D-104 doc fixes by C; no stealth-only fail and no soft lock; loud escape on `[secure]` + `escape_eta_s`; D-128
"hidden" claims verified with A's LOS sampling. Build starts for all envs together after D-135 (all queues clear).
**D-132/v1.28 rulings (A 2b97d701, 2026-10-17):** turn-in-place plays at speed_scale 1 (45 vs 90 by |yaw diff|), the
rig follows the clip's root rate and the ≤ 22.5° residual eases in during the blend-out (planted feet over exact yaw).
NPC one-shot presentation clips (door_kick, panic_start, cuff) must replicate: A adds a one-shot cue (net.md line by the
LEAD at merge). AnimCoverage flags FROZEN only on two consecutive identical samples (P).

## D-137: Ostrander Federal payout (D-120 shape) + QB-2 def ownership (2026-10-17, LEAD)
1. **Payout (§3b.3 / D-136.3):** B's proposal is adopted as written: `base_payout` $80,000; loot at the D-120 ids/values
   (cash_bricks MEDIUM $8,000 ×6/8/10, gold HEAVY $14,000 ×2/3/4, bearer_bonds LIGHT $7,000, server_drives MEDIUM $7,500 ×2
   optional); small loot at prefab values (deposit boxes $1.2-2.0k, teller drawers $500 ×6, CP straps $800 ×4; no
   `loot.small_valuables` def, as ND); new `loot.thermal_drill_part` HEAVY, `is_tool`, $0. Bag share 54 % (inside the 39-81 %
   band); Routine full clear ≈ $275k (1.65× DB) is accepted for the first L heist with up to 20 bags. test_p5_catalogue pins
   80000 × mult. The design doc's loot table follows the data (C, OF-C0).
2. **QB-2:** one owner per file stays. `ostrander_federal_def.tres` and `_variants.tres` are generated by C's
   `ostrander_federal_resources.gd`, as for every other heist. B owns the **values**: B sends C a ready-to-paste block in the
   generator's own format (D-130 population/pager tables, loot list, objectives, briefing_objectives, preplan overrides,
   variant rows); C pastes it verbatim and regenerates, with no edits to values. Value changes later go the same way.

## D-138: a cage is locked like a cage; every device is visible (PO-14, 2026-10-17, LEAD; product owner)
PO report: "on the ledger heist the door to the server lockup was a normal safe that needed sawing (the saw was
invisible too); the safe door and the server door opened together, nothing was inside the safe." Confirmed in code:
SL `CageLock` (sl_gameplay.gd) is a `prop_safe_large` standing at the CageGate whose opening only tells the mission to
open the gate, and a Safe with a drill/saw method but no child DrillPoint runs its own runner with **no device
visual** (safe.gd PO6-01 note). DB `CountCage` (db_gameplay.gd, LARGE safe, drill/c4) is the same pattern.
Ruling (PD2: cage/server doors take a saw or a keypad on the gate itself; no stand-in safes):
1. **No stand-in safes.** A cage, gate or door is beaten on the gate: a `keypad` on the gate post for the code route
   (code_group as today) and a `padlock`/hasp on the gate for the saw/drill route; opening either opens the gate.
   SL CageLock and DB CountCage become this. Safes are only real safes with loot inside.
2. **Padlock (A):** `place_saw_stealth` (place a saw on the padlock in stealth, not only once loud; the noise is the saw's
   own radius), plus `place_drill`/C4 parity where a doc asks (DB CountCage drill 120 s / C4). The objective's
   open_method (`code` / `saw` / `drill` / `c4`) and the HUD device row are unchanged.
3. **Every placed device is visible (A):** a Safe (or any prefab) running its own DeviceRunner spawns the device art
   (DrillPoint.DEFAULT_DEVICE / DEFAULT_SAW / DEFAULT_THERMAL) at its DrillPoint marker or lock point, for the whole run.
   A regression test fails any runner without a visual. Audit every heist's drill/saw/thermal spot (GH, ND, SL, GN, DB).
4. **Map (C):** SL and DB generators swap the stand-in safes for the gate keypad + padlock on the existing CageGate /
   cage gate; regenerate, validate final. Mission scripts (A) read the gate locks instead of the safe.
5. Ostrander's padlocked bullion cage and the cash cage use the same pattern from G1.

## D-139: heist freshness: repeat penalty + rotation bonus (2026-10-17, LEAD; product owner)
PO: "discourage playing the same heist over and over: less XP/money if it's been played multiple times in a short
period (rolling last 10 heists, -10% each time that heist appears), and an incentive to play heists not touched in a
while like PAYDAY does it: +1% XP/money, up to 10%, for each other heist played after it, if it has been completed at
least once and is not in the rolling memory." PD2's job heat moves XP only; ours moves XP **and** money (PO). Owner: B.
1. **Memory (per player profile, never crew-wide):** the heist ids of that player's last 10 runs that reached the payday
   screen (success or failure; a menu abort or disconnect is not a run). Plus a run counter and, per heist, the counter
   value of its last run and whether it was ever completed successfully. Pushed after the payday is computed.
2. **Repeat penalty:** n = times heist H is in the memory at the start of this run (this run not counted).
   n ≥ 1 → freshness = 1 − 0.10 × n, floored at **0.10** (LEAD default so a farmed heist still pays; PO may change it).
3. **Rotation bonus:** n = 0 and H completed at least once → k = runs played since H **left** the memory
   (runs since H's last run − 10, ≥ 0); freshness = 1 + 0.01 × min(k, 10). (A heist absent from a 10-run memory has always
   had ≥ 10 runs since, so the ramp starts when it drops out: +1 % per further run, full +10 % at 20 runs since.)
   Never completed → 1.0 (no bonus for a heist you haven't beaten yet).
4. **Applies to:** money: `gross` (contract + loot + small loot, after the crew-alive mult; the civilian penalty is taken
   after, unscaled) → total/stash/spending follow. XP: a multiplicative `freshness` step after the C6 lines (`xp_lines`
   gains an 8th key `freshness`, the delta; `xp_total` includes it). Failed heists: XP scaled too (money is 0 anyway).
   Each player's own freshness applies to their own payday.
5. **UI:** the payday shows a "Heist freshness ±N %" line (money and XP) with a one-line reason ("played 3× in your last
   10 heists" / "not played in 17 heists"). The heist list / contract card shows the current ±% badge before launch.
6. **Data:** tweak values in payout.tres (`freshness_memory`=10, `repeat_step`=0.10, `repeat_floor`=0.10,
   `rotation_step`=0.01, `rotation_cap`=0.10); profile schema +1 (migration: empty memory, completion flags seeded from
   career stats). Tests: the formula table (n = 0..10, k = 0..12, never completed), migration, payday line, two players
   with different memories in one crew.

## D-140: stealth heists can't be beaten by killing every guard (PO-15, 2026-10-17, LEAD; product owner; REVISED 12:25)
PO: "no stealth heist should be completable just by killing each guard except the jewelry heist or on the easiest
difficulty." PO clarification (12:25): "pagers should always be 4 on Routine, and there should always be no more than 4
guards on Routine (some maps should have 4), but further difficulties should EITHER add more guards OR lower the amount
of pagers, not both, the lead's call per map (if more guards would overcrowd a map, lower the pager cap)."
**Rule.** "Guards" = pager-carrying NPCs present at load (guards, the camera operator, escorts; not rare-event or timed
spawns); counts are the **minimum over seeds** unless stated as fixed.
(a) **Routine:** pager cap **4**, guards **≤ 4**.
(b) **Tense and up: one lever per map.** Either **GUARDS** (the cap stays 4; guards rise above 4 from Tense) or **PAGERS**
    (the guard count stays at its Routine number on every difficulty; the cap drops below it from Tense). Never both.
(c) From Tense up, guards > pager cap on every seed. A rolled `pager_max_answers` variant scalar may lower the cap, never
    raise it above the table (and never on a GUARDS map).
**Per-heist tables** (Routine, Tense, Hazardous, Brutal, Lethal, Cataclysm):

| Heist | Lever | Guards | Pager cap | Why |
|---|---|---|---|---|
| Ostrander Federal (L) | GUARDS | 4 / 5 / 6 / 6 / 7 / 8 (min) | 4 at every difficulty | big open bank, five levels: room for more patrols |
| Gallery Night (M) | GUARDS | 4 / 5 / 5 / 6 / 6 / 7 (min) | 4 at every difficulty | wide gallery floors and the mews: extras fit |
| Night Deposit (M, compact) | PAGERS | 4 fixed | 4 / 3 / 3 / 2 / 2 / 1 | 26 × 20 m, one storey + basement: more guards would crowd it |
| Shadow Ledger (M, tower) | PAGERS | 4 fixed | 4 / 3 / 3 / 2 / 2 / 1 | narrow tower corridors and stair cores: slower, denser play |
| Golden Hour (S, jewelry) | exempt (D-130) | as today | 4 / 4 / 3 / 3 / 2 / 1 | the PO's exception |

For the GUARDS maps these minimums replace D-130 §1's guard percentages; on the PAGERS maps guards no longer scale with
difficulty (D-130 §1 guards superseded). Civilians keep D-130 scaling everywhere. Every guard is a real spawn with its own
route or post, never a doubled-up post.
**Owners.** C: GN/ND/SL generator rows (GN Routine baseline 4 + `difficulty_add` to the table; ND/SL exactly 4 guards on
every seed and difficulty, guard `difficulty_add` removed, `pager_max_by_difficulty` set; GN `pager_max_by_difficulty`
empty = 4), regen, validate final. B: the OF values block per QB-2 (GUARDS: 4/5/6/6/7/8, no pager table) and the briefing
/difficulty card "N pagers" line where the cap is below 4. A: PagerSystem scalar-lowers-only; re-pin test_d130_population;
a test asserts (a)-(c) on 3 seeds for ND/GN/SL (OF once G1 lands); the stealth e2e tests still win. P: one windowed stealth
run each on Tense and Lethal for ND/GN/SL afterwards.

## D-141: Rolling Thunder groundwork rulings (QB-RT1..5, 2026-10-17, LEAD)
1. **Payout:** `base_payout` **$30k** (B's D-120 shape: full clear ≈ $135k at Routine, bag share 76 %, required-only ≈ $62k;
   table 30k/60k/78k/126k/216k/276k). The $85k placeholder predates D-120. test_p5_catalogue pins it.
2. **D-130 §1 / D-140 exempt:** RT is loud with a stealth set-up (an early alarm is a penalty, not a fail), so it has no
   stealth win to protect. The site guard keeps the default pager cap 4; civilians stay on the 6/9/12 scalar + `rush_hour`.
3. `asset.c4_drop` is drafted by B after A5-03's item drop kind lands.
4. Reyes in-heist radio uses speaker `reyes` with `vo.reyes.*` lines in the B7-03 contact-radio shape; the mission's
   `say(…, &"reyes")` plays those ids.
5. RT preplan point and room labels wait for the VO round after G1.
**D-141 addendum (OF-C0 QCs, 2026-10-17, LEAD):** QC-g the teller counter gets a solid bandit-screen base (1.35 m proposed; **1.50 m adopted**, C hide_los: oblique observers saw a crouched player over 1.35 m) in front
of the 1.05 m ledge (a crouched player's top detection point is 1.05 m), glazing above; QC-h civilian budget ≤ 22;
QC-i no new "door" assault kind: XL/HH doors breach via D-122 NAV_LAYER_BREACH, Breach_3/4 stay police-entry points;
QC-j C's call in OF-C2.

## D-142: clear glass is see-through for detection (QC-k, 2026-10-17, LEAD)
PD2: guards, civilians and cameras see the crew through clear windows and glass doors. Today `VISION_MASK` (1|2|8) treats
Window glass (world_static) as opaque. Ruling: **PD2-faithful**: vision rays ignore colliders in group `see_through`
(A: the Window prefab's GlassBody + the group check in the LOS sample; bullets and movement unchanged). C tags clear
glazing only; frosted, tinted-opaque and mirrored glass stays opaque, as authored. Sequenced after PO-14/PO-15. Because it
changes sightlines on every shipped heist with windows (GH storefront, SL tower, GN, ND, DB offices), C audits glazing per
heist (clear vs opaque list in the heist doc), A re-runs the stealth e2e routes, and P re-walks each stealth heist's
main route windowed before the round that enables it reaches trunk; any route that dies on new sightlines gets a C cover
fix or that pane made frosted, not a revert. The OF checks assume see-through.

## D-143: Afterhours groundwork rulings (QB-AH1..5, 2026-10-17, LEAD)
1. **Payout:** `base_payout` **$40k** (D-120 shape: full clear ≈ $126k at Routine, bag share 63 %, required-only ≈ $64k;
   table 40k/80k/104k/168k/288k/368k). Afterhours `stealth_bonus_mult` 1.15 (size M, S11.1).
2. **D-140 lever: PAGERS** (crowded club; more guards would crowd it): exactly 4 guards at every difficulty (door + rope +
   2 rovers from the rover pool, no guard `difficulty_add`), `pager_max_by_difficulty` [4, 3, 3, 2, 2, 1].
3. `escape_options` = [van] only (D-075 ruling 9: no walk-out).
4. Mode label stays "Stealth or loud"; the loadout's civilian-start notice (B5-05) carries the civilian start.
5. `asset.intel_safe_code` / `asset.intel_product` are AH-only: assets gain a per-heist allow-list (`heists: []`, empty =
   every heist), B's library field, so no other heist's def needs a `disable`.
6. (Clarification 2026-10-23, LEAD; A's AH harness) "Exactly 4 guards" counts the door + rope + 2 rovers only. The security-room
   camera operator (sec_staffed, rolls from Tense per afterhours.md) is a separate role, as in GH/OF, and stays: on Hazardous+ that
   makes 5 pagered NPCs against a pager cap of 3, which is the D-140 lever doing its job (the club can't be cleared by killing everyone).

## D-144: one new heist at a time (2026-10-17, LEAD; product owner)
PO: "ensure they're fully finished before moving on to new ones." Ostrander Federal is the only heist in build until it
passes its D-115-style done check (G2 final, e2e stealth + loud, P windowed G2 pass, strings/VO, cast). Rolling Thunder
and Afterhours groundwork already pushed (hidden behind the readiness gate; D-141/D-143 rulings) is parked as is: no
further next-heist work in any env until OF is done. Idle capacity goes to OF, PO items and shipped-heist polish.

## D-145: PO feel pass: ladders, low-difficulty loud, early armor, crew bots, run bob (2026-10-17, LEAD; product owner)
PO: "ladders should be climbable when looked at, not a forced animation; loud is too hard on lower difficulties; the cops
seem to have body armor which they shouldn't until later; AI bots need a little health regen / to be customizable to
perform better (armor and weapons you can buy, customize, and equip to each helping bot slot); the run looks a little too
wobbly and bobs the gun weirdly." Idle capacity, alongside Ostrander (D-144 unaffected: no next-heist work).
1. **Ladders (P, A):** PD2-style free climbing. Walking into a ladder attaches; forward/back moves along it with the
   direction set by look pitch (look up + forward climbs up, look down + forward climbs down); jump detaches; reaching
   the top/bottom steps off. No forced/locked animation and no camera lock; the player keeps full look. Bag rule
   unchanged (S10.1b). P: player controller; A: ladder prefab volume/exits + bot use unchanged.
2. **Loud on Routine/Tense (A, B data):** compare our police damage, accuracy, wave size, special frequency and assault
   length against PD2 Normal/Hard and bring Routine ≈ PD2 Normal, Tense ≈ PD2 Hard (Hazardous+ unchanged). Acceptance:
   P windowed loud runs, solo + 3 bots, GH and DB on Routine and Tense, 3 seeds each: win, median ≤ 2 player downs.
3. **No armor early (A, D):** on Routine and Tense no police unit has damage-reducing body armor (no TAC Heavy, no
   armored vests); armored units start at Hazardous. D: Routine/Tense police looks carry no plate-carrier visual.
4. **Crew bots (B, A):** (a) health regen: after 6 s without damage a bot regains 2 % max health per second
   (tunable, `CrewAiTweak`, bot-only), a deliberate deviation from PD2 (◇). (b) Per-bot-slot loadout: each of the 3 bot slots
   equips a primary (any weapon the player owns, with its mods), an armor tier (owned armors) and a cosmetic mask/outfit;
   bought through the existing armory economy, saved in the profile, shown in a Crew screen in the hub. Bots use the
   equipped weapon's real stats through the bot accuracy profile and the armor's real values. B: UI, save, economy;
   A: bot runtime.
5. **Run bob (P):** calmer sprint/run: lower head-bob amplitude, smoother viewmodel bob (no sharp figure-8 snap), a
   steady PD2-like sprint pose (gun lowered and angled, gentle sway). P judges windowed at 60 fps, before/after clip.

## D-146: draw-call budget counts shadow passes (2026-10-20, LEAD)
D found the OF hall at 12,885 submitted draws (79 % shadow passes) while levelcheck `perf` reported 2,438: the check
counted main-pass surfaces only. Ruling, amending architecture §10:
1. **Main pass ≤ 2,500** draws per view (unchanged), and a new **total ≤ 4,000** submitted draws per view *including*
   shadow passes (sun cascades, spot cones, omni ×6 faces), measured with the peak cast for the heist (Cataclysm).
   **Shadowed lights ≤ 8 in view** is unchanged.
2. levelcheck `perf` counts both numbers and is reconciled against D's `heist_cast_perf` on the same view (unit test).
3. **OF must meet both to reach G2 final.** C measures the five shipped heists with the new check and reports. Overruns
   there are queued as polish *after* OF is done (D-144), unless one is so far over that it plays badly; then the LEAD
   pulls it forward.
4. Levers, in order: a shadow only where it reads; no omni shadows; distance fade / shadow max distance on spots; sun
   2 splits and a shorter max distance; `cast_shadow` off on small props, skyline and far NPCs; occluders.
5. **Addendum (2026-10-20, C's perf lane):** occlusion culling turned **on** project-wide
   (`rendering/occlusion_culling/use_occlusion_culling=true`); it was off, so every map's occluders (OF 286, GN 129,
   SL 125, …) did nothing. levelcheck cannot credit occlusion, so its numbers stay conservative. The D-146 counter
   enforces at stage final only for heists flagged `perf_d146` (OF first) and is report-only for the five shipped heists
   until their D-144 polish slot.

## D-145 addendum (2026-10-20, LEAD; from P's GH Tense acceptance runs and A's fixes)
Tense losses traced to takedown rules, not tuning. Amends **D-093** and pd2_fidelity **L2.8 / L2.12**:
1. An expired tase is a counted down (bleed-out, revivable); a broken tase frees the victim. No takedown path goes
   straight to custody at any difficulty (A d65a3a1d, 10357121).
2. A Phantom (Cloaker) kick is a counted down with bleed-out, as in PD2; the victim stays kicked flat until revived.
3. Police cuff downed heisters only from Hazardous up; Routine/Tense custody comes from bleed-out alone (◇).
4. Stinger re-tase cooldown 12 / 8 / 4 s (Routine / Tense / Hazardous+) and per-victim immunity 10 / 6 / 0 s (◇).
5. A downed heister who shoots from the floor draws fire and can be shot out of bleed-out (PD2), unchanged.
6. **Addendum (2026-10-20, real-GPU evidence):** the shipping renderer is Forward+ (D-001, architecture §1). The PO's
   RX 9070 XT (GPU box, branch `gpu/renders`, GPU-2) measured the OF hall under a Cataclysm loud assault at
   ~2,000–2,300 total submitted draws in Forward+ (map ~1,300–1,450, cast ~730), well inside 4,000. Therefore D-146 is
   **judged on Forward+, measured on the GPU box**; levelcheck's Compatibility-based model stays as a conservative
   early-warning (report-only from now) because Compatibility is the fallback renderer. A heist passes D-146 when its
   worst views, Cataclysm cast, loud, measure ≤ 2,500 main / ≤ 4,000 total in Forward+ on the GPU box.

## D-147: reuse-first for props and kits (2026-10-21, LEAD; PO question)
The prop catalog has 520 entries (522 prop scenes). Ostrander used 296 distinct props, of which 245 (83 %) were reused
and 51 were new bank-specific pieces (teller line, sunburst, vault gear). From the next heist on: **every map uses
catalog props and kits first.** A new prop needs a one-line reason in the heist doc's art list: no catalog piece fits the
role, or it is a landmark / hero piece. Generic dressing (furniture, office, kitchen, clutter, lighting, doors, exterior,
vehicles) is never rebuilt per heist. Variants come from library finishes (materials/colour), not new meshes. C reports
reused vs new counts in each G1/G2 review.

## D-148: PO picks: next heist Rolling Thunder, XP option D, paper start now (2026-10-21, LEAD; product owner)
PO: "Proceed with all your recommended options."
1. **Next heist: Rolling Thunder** (`rolling_thunder`, the Vaultline convoy, D-075/D-141). Afterhours follows it.
2. **Paper start now** (amends D-144 for paper only): the RT build plan, systems/content/cast audits and prep branches
   may proceed while Ostrander finishes. Building on the env branches (maps, mission code, data) starts at the OF done
   check. D's assembled cast waits on `prep/d-rt`.
3. **XP pacing = option D** (B's progression_pace.md): the curve ×2 (= PD2's ~23 M total to level 100), heist-size base
   XP (S 1,500 / M 2,000 / L 2,500-3,000), PD2 difficulty multipliers kept. B applies it, re-checks every level-locked
   unlock (weapons, armor `unlock_level`, Bot Crew armors) against the new pace, and updates pd2_fidelity.
4. **Hardest-difficulty OF loud vs the AI pilot** (Haz 0/3, Cata 0/2 with real bots): accepted as a harness limit; no
   tuning for it. Human playtests decide later.
5. **Reuse-first (D-147)** applies to RT from day one.

## D-149: Rolling Thunder paper rulings (QC-RT1..11, escort looks) (2026-10-21, LEAD)
Rulings on C's `docs/process/next_heist_rolling_thunder.md` §8 and D's cast note (env/d-art 3411484a). Each item
takes the recommendation the env gave.
1. **QC-RT1 convoy nav:** pre-baked nav regions per convoy layout, swapped at the stop. The same applies to the mixer
   and the Tannery gate. No runtime rebake (heist_map v1.4, D-121). A adds a TacticalPoint `enabled` flag.
2. **QC-RT2 bullion hatch:** a ground-level thermite point on the truck's rear doors. No truck-roof traversal.
3. **QC-RT3 size:** M (15-25 min). It sets the e2e budgets and the D-120 checks. Base XP is 2,000 (D-148).
4. **QC-RT4 P5 gate:** RT has no stealth win. Its gate is a clean-setup run instead of a ghost run: signals rigged,
   marshal handled, no early alarm.
5. **QC-RT5 path cap:** A's uncapped NavPath has been on trunk since round 255 (ffc264d4). C's ≤ 3,500-polygon target is
   an early warning, not a hard G1 rule.
6. **QC-RT6:** the D-147 substitutions (trees, dumper, bus, jukebox, cycle racks, bunting, wheel stops) are accepted.
   C updates the design doc.
7. **QC-RT7:** civilians reuse `civilians_leave` plus sidewalk call points. No new flee-exit system.
8. **QC-RT8:** the convoy and mixer drive in (≤ 8 movers, then static), and the escape van pops in.
9. **QC-RT9:** the early-alarm truck lockdown (saws ×1.5) and the 8 s ambush window stay, labelled as original
   (not PD2-sourced) in pd2_fidelity.
10. **QC-RT10:** C may write the `--check`-only plan scripts (`tools/levelcheck/plans/rolling_thunder_*.py`) before
    the OF done check. Paper only: no map.
11. **QC-RT11:** D-147 and D-148 are already in this file.
12. **Escort looks (D):** `convoy_lead` and `convoy_rear` are carved out of the "every spawn tag maps to a look" rule.
    They are EnemyDefs, so NpcVisuals resolves them by difficulty (D-145.3 duty looks, faction reskins, tac_heavy).
    A adds a test that they never get a capsule.

## D-150: OF ghost acceptance difficulty (2026-10-21, LEAD)
P's ghost line (seed 1002): steps 1-4 pass on every run, and step 5's gate, lasers and time lock work unseen. At
Cataclysm (8 guards, D-140), BB has no window with both rover_basement and the vault guard away (r257d: three
windows in 700 s, each under 4 s). PD2's top-difficulty bank stealth relies on kills within the pager cap rather
than pure ghosting. Ruling:
1. **The no-kill ghost acceptance runs on Hazardous** (6 guards). That is the OF ghost gate for the done check.
2. **On Cataclysm, the stealth acceptance is a stealth win.** Guard kills are allowed within the pager cap (D-140), plus
   body bagging. Patrols are not lengthened to make a Cataclysm ghost possible. Density is the difficulty lever.
3. If the Hazardous ghost also finds no BB window, C and A lengthen rover_basement's away leg at that difficulty
   only.

**D-145 addendum (2026-10-21, LEAD): DB Tense accepted at 2/3.** On r257 + 60d8c6ab (P's capsule fix, the 1-Longshot
cap, the Longshot timing), headless auto_loud, solo + 3 bots:
- plain: 2/3, player downs 3 / 3 / 1;
- with the doctor bag: 2/3, downs 6 / 2 / 2, median 2.

GH Tense was already 3/3. No further Tense data lever (no Bulwark cap change). Seed 1's custody chain (about 640-690 s
in both cells) is a low-priority look for A, not a blocker.

## D-151: Rolling Thunder build opens now; level-70 gate; the LEAD makes judgement calls (2026-10-21, LEAD; PO delegated)
PO: "Have the judgement calls be your own." From here the LEAD rules on design and process questions and records them,
and asks the PO only for taste or scope calls the PO has asked to keep.
1. **RT build opens now** (amends D-144 / D-148.2). Ostrander has met 5 of 6 done gates (heist_completion.md). The last
   one, P's Hazardous ghost line, is P's work alone, so it no longer holds the other envs.
   - env/c-worlds (RT G1 + RT-C2 batch 1) merges to trunk; prep/d-rt merges via env/d-art.
   - A builds A5-01/02/03 plus C's mission asks; B lands the RT-B1 data; D's cast rows go to A's npc_visual_tweak.
   - The LEAD adds QC-87c to the shared levelcheck.
   - OF fixes still take priority in every round.
2. **Lethal / Cataclysm gate: level 70** (was 80). Under D-148's XP curve, 80 took about 230 clears; 70 takes about 135,
   the old time-to-Lethal. B changes the data and re-pins the gate test.
3. **Older heists:** the r266 regression sweep stands as their check after today's systemic AI changes:
   - loud Routine GH / ND / GN / DB PASS, SL stealth PASS;
   - D's anim coverage: 0 flags;
   - B's screen-text walk: all clean.

   No further broad runs. Future changes get targeted tests only (D-088).

## D-152: Ostrander Federal is DONE (2026-10-21 23:40, LEAD; D-151 judgement)
All six D-115 gates are met (docs/process/heist_completion.md).
- The windowed loud gate was met by GPU-20c: a full Cataclysm win on the PO's GPU.
- The ghost gate is accepted on step-wise evidence, under the D-151 time-box fallback:
  - P's Hazardous line, seed 1002, passes steps 1-5 unseen in one continuous run (haz_zd: vault open at t=1484).
  - Every step-6 sub-move passes unseen (lift cycle 1 in ghost6_m / t / u).
  - Steps 6-7 are covered by P's route note, ghost_route_note_hazardous.md, which C folds into the design doc.
  - No game or AI bug was found. The limit is harness margin: the vault guard is away 30-40 s every ~200 s, and a bag
    crossing needs 20-25 s.
- Playability margin, not a gate: on Routine, Tense and Hazardous, the vault guard's loop (b) RC dwell gets +15 s
  (A: guard_tweak hub_loops; C: the doc).
- Open follow-ups, none blocking: a human-input windowed ghost when the PO or a session has time.
- **Rolling Thunder is the active heist (D-148 / D-151).**

## D-153: LEAD handover back to session_01XAPqm; fresh env team (2026-10-22, LEAD; product owner)
The PO resumed the original LEAD (session_01XAPqmFJ32zHKLK9Sezymym) as the core orchestrator. The 10-20 team (LEAD
session_014E3p2… and its envs) is in another account and unreachable from here; it stopped after round 273
(d1ecb0b6, 2026-10-21 23:47). This LEAD:
* keeps trunk = `claude/dreamy-hamilton-pc7vck` and every rule in force (D-086, D-088 targeted checks, D-115, D-144 one new
  heist at a time, D-151 the LEAD makes judgement calls, the 10-20 standing directive: no env idles);
* spawned five new env sessions from each env branch's origin tip (ids on the board). Each resumes from the top of its
  `docs/status/env_*.md`; the obsolete local round-229 merge on `claude/epic-fermi-k5fa09` is superseded by D-129's gate;
* gates round 274 = the env commits pushed after round 273 (A 0eb9537a, C bfdf43e7, P 5e01c275).
Rolling Thunder stays the active heist (D-148 / D-151 / D-152).
Ruling (A's open question, status env_a -23; AMENDED same day after A's ownership note): the `enemy.convoy_lead` /
`enemy.convoy_rear` EnemyDefs live in A's path (game/systems/ai/data/enemies), so ENV A writes them with the design doc's
stats (Routine/Tense patrol-officer, Hazardous+ TAC); ENV D supplies their look ids (D-149.12); ENV B reviews the values
for the balance tool.

## D-154: Bulwark (shield) share follows PD2's shape; RT early alarm brings the convoy (2026-10-22, LEAD; D-151 judgement)
From ENV B's review (game/content/docs/rt_early_alarm_balance.md, env/b-content 1dd63c4c + addendum 280bdbf8):
1. **Shields, all heists (the director's general tables).** Today about 15 % of police are Bulwarks on Routine and on
   Hazardous (low tiers: Bulwark and Longshot are the only weighted specials; Hazardous funnels capped specials into
   Bulwark). Target, PD2 shape: about 5-8 % on Routine/Tense, 10-12 % on Hazardous+.
   - ENV A: `special_bulwark.weights` 0.6/0.8/1/1.2/1.4/1.6 → 0.25/0.4/0.8/1.0/1.2/1.4; `special_share_difficulty_mult`
     0.5/0.75/1… → 0.35/0.6/1….
   - ENV B: Bulwark `special_limits` 2/3/4/4/4/4 → 1/2/3/4/4/4.
   - Verify (targeted, D-088): A re-runs the RT seeds it measured, then one loud seed each on GH / ND / DB (all heists
     share the tables) and reports the per-difficulty share.
   - Measured (A, 2026-10-22): Routine 4.3 % (in band at the low edge), Hazardous 5.1 % (half the target). AMENDED for
     Hazardous+: `special_bulwark.weights` → 0.25 / 0.4 / 1.0 / 1.2 / 1.4 / 1.6 (low tiers kept, Hazardous+ restored) and
     Bulwark `special_limits` → 1 / 2 / 4 / 4 / 4 / 4 (Hazardous back to 4). A re-measures 3 Hazardous seeds + ND / DB Routine.
2. **RT early alarm:** the convoy arrives at min(convoy_eta_s, alarm + 25 s) (REVISED from +75 s, which landed the stop on wave 1's SUSTAIN; +25 s stops it inside ANTICIPATION, B fd41028a), so wave 1 fights over the trucks
   (police_delay_s stays 0, D-075). A re-measures 5 seeds each on Hazardous and Lethal (targets: Hazardous reaches the trucks
   opening on ≥ 3/5, Lethal 1-2/5, Cataclysm ≤ 1/5). B's first-assault Stinger cap for Lethal+ is held until then.
   - Result at +25 s (A ce09f134): the stop lands at ~+33 s with only 2-3 police, but Hazardous is still 0/5; the crash
     stop dismounts all 11 convoy units at once onto a 4-bot crew in the open. Ruling: **staggered crash dismount** (A):
     escorts out first, the Vaultline crew and the TAC Heavy over the next ~6 s (the clean stop already staggers 4 s).
     Re-measure Hazardous 5 seeds. If still < 3/5, the call is made on P's real-input run of a blown setup on Hazardous,
     not on the bot: a human crew using cover is the target audience; the bot's convoy tactics stay a parked item.
3. **Payday cards:** achievement-reward parts never drop (PD2; B 804c97f0).

## D-155: Melee unlocks by level, never sold for cash (2026-10-22, LEAD; D-151 judgement)
PD2 never sells melee weapons: each one unlocks at a player level (or an achievement / DLC) and is then free to equip.
We follow that shape:
1. No `owned_melees`, no Workshop buy, no save-version bump. MeleeDef's unused cash price is removed (or pinned to 0 and ignored).
2. Each MeleeDef carries an `unlock_level` (B owns the values). The loadout picker shows locked melees greyed out with "Unlocks at level N", and they can't be equipped.
   Unlocking is derived from the player's level, so nothing new is saved.
3. The starter knife and at least one blunt weapon are level 0. The heavy picks (sledgehammer, fire axe) unlock late, as in PD2.
   Achievement-gated melee waits until achievements grant items, and isn't built now.

## D-156: Melee models stay with B; D builds the two-handed arms set (2026-10-22, LEAD; D-151 judgement)
I had planned to move the 11 melee models to D (B's queue is long). B had already built them before the handover reached it, so ownership is unchanged:
1. **B** keeps the melee models (`tools/blender/weapons/**`) and the MeleeDefs.
2. **D** builds a new two-handed FP arms set `melee_heavy` (PD2: the sledgehammer and fire axe are two-handed). The right hand sits at the grip pivot (the item origin, as in every melee set) and the left hand on the same handle 0.28 m further down (item −Z).
   Clips and events have the melee_blunt/blade shape, charge_time_s 1.0; characters v1.38 row when it lands.
   B switches `sledgehammer` / `fire_axe` to `anim_set = &"melee_heavy"` in the same round, and makes the models' handles fit that two-hand grip.

## D-157: The crew sentry gun is built (2026-10-22, LEAD; D-151 judgement)
B's skill trees (Technician: Engineering / Sapper) carry six sentry keys: sentry_accuracy_mult, turn_speed_mult, cost_mult, health_mult, sentry_shield, sentry_modes.
The game has no crew sentry, and PD2's Technician isn't PD2 without one. So it's built, not parked:
1. **A** (after skills B6): the sentry prefab.
   - It's placed like a deployable, with a hold to deploy, and its ammo is paid from the owner's ammo (PD2: 40% of total ammo, ◇ until B sets it).
   - Targeting, turn rate, spread, health; it marks enemies the way PD2 sentries draw aggro.
   - Pickup returns the remaining ammo.
   - Mode toggle (standard / armour-piercing, the latter needing Engineering) and the sentry shield.
   - Server-authoritative and replicated.
   - It hooks the six keys.
2. **B**: `deployables/sentry.tres` (DeployableDef kind "sentry"), loadout/armory entry, strings, the values (PD2-shaped), and the Technician markers.
3. **D**: the model and its deploy/fold animation, once A's prefab nodes are fixed. A placeholder box until then.
4. pd2_fidelity P5's deployables launch target becomes 8 (7 + sentry). pocket_ecm stays parked.
5. (Amendment, LEAD) The sentry model is **D's**, at `tools/blender/equipment/sentry.py` → `game/assets/equipment/sentry/`
   (owners.json: those paths go to D, excluded from C). The other deployable models stay in C's `tools/blender/props/equipment.py`.

## D-158: Rolling Thunder Hazardous verdict: clean-stop detection fix, a truck window after a crash stop, bots use cover (2026-10-22, LEAD; D-151 judgement)
P's real-input Hazardous pair (P 6f7baa97: rifle, heavy vest, doctor bag, no skills; seed 4101 north): **clean stop 0/1, unfair**
(the crew was seen 1.5 s after the hand-over by an escort still SEATED in T3's cab, then wiped in 23 s from the best cover);
**blown 0/1, borderline** (the escort was beaten from cover in 20 s, but police wave 1 BUILD landed 15 s after the crash stop, with a
Phantom kick and a Stinger, before anyone reached a truck across 25 m of open road). A's bot data agrees: the escort itself is fair.
1. **Logic fix (A):** a unit seated in a vehicle has no detection (vision and hearing gauges off) until it dismounts.
   Seated crews can't see out of an armoured cab. The clean stop's ambush window then means what it says. Dismount stays
   triggered by the ambush / any non-seated escort's alert, as now.
2. **RT truck window (A, D-154 amendment):** after a crash or clean stop, the first assault's BUILD can't start before
   stop + 30 s (◇) on any difficulty. That is the heist's designed "hit the trucks" beat. The alarm-based anticipation still
   applies when it is later. Specials in wave 1 stay (PD2).
3. **Bots use cover (A):** when the human they follow is in cover or crouched in combat, AI teammates take the nearest cover
   point within 8 m of them instead of standing in the open. Small, general, all heists.
4. **Check (C):** site guards hit the crew at the pier "over or through the hoarding line". Verify the hoarding blocks LOS
   and bullets where it is solid.
5. Re-judge: P reruns the Hazardous pair on the round with 1-3, once with no skills and once with a PD2 loud build. RT is done
   only when the clean stop is fair (≥ 1 truck reachable by a competent human) and the blown run is at worst "hard but fair".

## D-159: Safehouse hero props are D's (2026-10-23, LEAD; C proposal)
D builds the 8 safehouse hero props (Old Press, jukebox, Board map, bunk, gun cabinet, PPE rack, drying line, type case).
`owners.json`: `tools/blender/props/safehouse_hero.py` + `game/assets/props/prop_sh_*/**` go to D, excluded from C.
C keeps the safehouse catalogue, placement and the stand-in → hero swaps (C4-03/G3). Pendants, work light and van stay C's.

## D-160: No PO-only steps on the done path (2026-10-23, PO)
PO: "skip the GPU render / any steps that'd need something you can't do yourself."
Heist done checks no longer wait on PO actions (GPU re-renders, PO playthroughs). Windowed opengl3 evidence from the envs
(reviewed by the LEAD) stands in. Rolling Thunder's done path is now:
P's D-158 real-input verdict → the LEAD's D-115-style done check → B flips the un-hide flag → Afterhours starts (D-144).
6. (Amendment 2026-10-23, LEAD) A's bot A/B (seeds 1001-1003, 6 runs each way): the window / wave-1 Stinger / cover knobs never
   engage, because the convoy escort decides the run in the first ~20 s after the stop. Cover-behind-leader was HARMFUL (bots held
   back while the leader lay downed at the front), so it stays 0. The escort knobs act on the right phase: escort_engage_delay_s 1.5
   + escort_accuracy_mult 0.7 for 10 s took the escort phase from 2/6 to 4/6 survived, and downs before BUILD from 13 to 8, without
   touching the later heist. **Ruling: escort knobs ON (1.5 s / ×0.7 / 10 s).** The truck window and the wave-1 exclusion stay
   available but OFF unless P's human runs show the crew dies in the first assault. P's remaining verdicts run with the escort knobs on.

## D-161: Hacker perk deck (pocket ECM) is the 15th deck; B's economy pin now (2026-10-23, LEAD; D-151 judgement)
The B audit (c2ebc7a0) closes every B roadmap row, and A's P4/P6 audit closes A's, so capacity is free while RT finishes.
pd2_fidelity lists Hacker as the first "further deck" (S8.7 pocket ECM, P4 row). It is built now:
1. **B:** `perk.hacker` deck data (9 cards, PD2 shape: Pocket ECM unlock on card 1; on kill while a pocket ECM is active, heal / dodge
   per PD2; the deck's standard cards). The throwable slot shows Pocket ECM when equipped (replaces the throwable, PD2). Strings, picker.
2. **A:** `stealth.pocket_ecm`: 6 s jam, 2 charges, 100 s recharge per charge (−6 s per kill), charges recharge one after another;
   it jams like the ECM (pagers, cameras, phones) but cannot open doors / ATMs; in loud it does feedback per PD2. Replicated,
   behaviour-tested; this removes the last UNHOOKED ratchet key.
3. **B (now):** S10.6: pin the D-120 bag-value table and the bag share of a full clear in a test (golden values).

## D-162: Further perk decks, batch 1: Yakuza, Biker, Maniac (2026-10-23, LEAD; B sizing)
B's sizing ranked the pd2_fidelity "further decks" by new A behaviour. Batch 1 = the three cheapest:
- **Yakuza** (S): one per-tick health-scaled scaler (armor regen and move speed rise as health falls below the threshold; card 9 moves the threshold to 50%).
- **Biker** (S-M): kill → health + armor, at most N per window, scaled by missing health/armor. Needs a shared **crew-kill event**
  (any teammate's kill), which also serves Hacker card 9 (crew_kill_heal).
- **Maniac** (M): Hysteria stacks from damage dealt → flat absorb, with decay; the crew shares the best holder's; replicated.
B: deck data, strings, docs, tests. A: perk.yakuza / perk.biker / perk.maniac hooks + the crew-kill event. Values per PD2
(docs/research/pd2_research.md). Next candidates: Sicario, Tag Team; then Leech, Copycat.
7. (Amendment 2026-10-23, LEAD) Bot revive work (A r288 batch): bots already revived first in loud, and bots revive bots (now tested).
   The two new levers (cuffer_score_mult: shoot the cop moving to cuff first; cuffer_clear_first: clear a cuffer near the patient
   before kneeling) measured WORSE on rt_clean in every diverging A/B comparison (4/4) and equal elsewhere. Both ship OFF (1.0 / false)
   and stay as knobs. The cuff-vs-revive race is lost on time, not targeting.
8. (Amendment 2026-10-23, LEAD) P verdict 3/4 (blown, loud build, escort knobs on): the escort is now won and the saw placed, but
   the crew is pinned at the open truck during the 180 s lockdown cut by wave 1's specials (2 Phantoms + 2 Stingers: each tase/kick
   costs a revive). That is the "survives the escort, dies in the first assault" case, so: **truck_window_from = escort_down**
   (BUILD 30 s after the last escort dies, capped at stop + 60 s) and **wave1_exclude = [stinger, phantom]** on Hazardous+ (RT only;
   wave 2+ unchanged). Lockdown multipliers stay as they are (PD2). P's confirm run judges the result.
9. (Amendment 2026-10-23, LEAD) A's 5-seed harness table (env_a.md -50; 20 headless real-menu runs on r294): Routine 9/10 won
   end to end (auto_loud 5/5); Hazardous 0/10 with the bot pilot (escort won, then the truck fight lost: read as bot-skill data next
   to P's windowed confirm pair). The one escort outlier is **route_east, clean stop**: its rear TAC Heavy halts 33 m from the stop
   (north: 50 m on every seed) and downs the crew at t+13 s. A traced it to the truck count, not the route: on trucks_2 the rear car
   closes up at RearStop2 (behind T2), 32 m from the crew's cover vs 49 m on trucks_3. Ruling: RtTweak.rear_close_up_clean = false
   (a CLEAN stop always uses RearStop, so the rear stays LeadStop + 42.5 m on both routes and truck counts; the crash stop keeps its
   close-up); a test pins both routes x both truck counts. The pilot snag at (21.9, 0, -12.8) between BinStreet0 and CarParkBarrier
   (7/20 runs) is a dressing fix for C (widen the gap ≥ 1.2 m). RT is loud-forced by design (the 8 s window raises the ambush
   alarm), so its D-115 ghost gate reads "n/a, loud-forced", like the PD2 original.

## D-163: Further perk decks, batch 2: Sicario, Tag Team (2026-10-23, LEAD; A plan)
- **Sicario:** Smoke Bomb = a new thrown kind `smoke` (existing thrown-item path; 10 s cloud). Crew inside avoid 50% of bullet hits
  (a separate roll); enemies inside hit at ×0.5; no LOS blocking (PD2). Twitch (+20% dodge per hit taken until a dodge, 4 s lockout),
  Agility Shield (a dodge refills armor, via a new PerkHooks.on_dodge), Unseen Shadow (×2 in smoke; allies in smoke +10% dodge).
- **Tag Team:** Gas Dispenser = throwable-key tag of an aimed ally ≤ 18 m with LOS (ShoutSystem.ally_target_for). Paired kills heal
  holder 15 / tagged 7.5 (CrewKillFeed); Synergy +2 flat absorb per paired kill (max 20) via a generic PerkComponent.absorb() summed in
  PerkHooks.incoming_damage (Maniac moves onto it); Harmony −2 s cooldown per tagged kill.
- Order: **B proposes the param names first** (deck data + ThrowableDefs); A builds against them (avoids the D-162 rename).
  Truncated PD2 values (smoke cooldown, tag duration, per-kill extension) are ◇.
- HUD: `LocalHudModel.tag_team {tagged_slot, left, cooldown}` → ui_hud v1.21 when A lands it. C: smoke-cloud VFX + cue.smoke_bomb;
  D/C: gas-tether look + cue.gas_dispenser_tag.

## D-164: Further perk decks, batch 3 (last): Leech, Copycat (2026-10-23, LEAD; A plan)
- **Leech:** armor off deck-wide (adjust_max_armor → 0); Ampule window: heal on use, segmented health (a hit costs exactly one
  segment, then a short invuln), kills restore segments, losing a segment heals teammates; a new PerkHooks.would_go_down veto
  (once per window) and use-while-downed temporary revive (no down refund ◇). HUD via PerkItems (kind ampule).
- **Copycat:** a PerkCopycat with PD2's 4 rotating behaviours (B's list) + per-card stat choices (B: choice UI + profile schema),
  and card 9 = mimic another deck's card 9. **Mimic scheme:** every deck carries a `mimic_grants` (its card-9 delta as standalone
  keys); Copycat card 9 grants the chosen deck's mimic_grants. A card 9 that only makes sense inside its own deck is marked
  non-mimicable or gets a standalone variant. Component params default to 0 / off so partial dicts are safe.
- Order: Leech first (self-contained), then Copycat. B proposes names first, as in D-163.

## D-165: Afterhours starts now, in parallel with Rolling Thunder's final-shot review (2026-10-23, LEAD; product owner)
PO: "no agents/environments stalled ... if only one suite is pending approval the other agents should work on what they can, or
begin Afterhours if applicable." Rolling Thunder has met every D-115 gate except the LEAD's review of C's 28 final shots (stage
final, validate --stage=final PASS on trunk r300; e2e = A's harness env_a.md -50 + P's windowed confirm pair; strings/VO = B's
slice; cast done; ghost gate n/a, loud-forced). That review is a single pending approval, so D-144 lifts now:
- **Afterhours is the active build** (docs/design/heists/afterhours.md, D-075 / D-143 rulings). It lands on trunk behind the
  readiness gate (heist_list hidden) until its own D-115 check.
- **Rolling Thunder** content is frozen except fixes from the shot review; B's RT un-hide lands with the LEAD's RT DONE line
  (written like D-152) once the shots pass.
- Lanes: A the mission + logic; C the def, map (G1 greybox → G2) and music; D the club cast build + wiring; B items 8-10 as C's
  def/map land (items 1-7 + achievements merge now); P the first real-input pass once C's greybox is playable, its RT
  follow-ups until then.

## D-166: Afterhours van: a captain-held assault does not block the escape (2026-10-23, LEAD; A done-check)
A's AH done-check table (env_a.md -60): loud Hazardous seeds 1 and 4242 soft-locked. Safe open and 3 bags secured, then no
end in 2400 s. Brandt (captain, wave 2) holds SUSTAIN (`AssaultDirector._tick_sustain` while `captain_active()`), so the 2nd
FADE never comes, and the AH van waits on it. In PD2 a Winters-held assault delays the next break, not the escape vehicle.
Ruling, both parts:
- **Product (A, `afterhours_mission.gd`; C amends afterhours.md Loud step 4):** the van rule is "at the second assault's FADE or
  300 s after `[secure]`'s first bag, whichever is later; **if a captain is active when the 300 s runs out, the van comes
  then**" (also if the captain arrives after the 300 s ran out: on `captain_arrived` the van comes then). Waiting for the 2nd FADE stays the normal case. A captain lock only waives it. The director is unchanged
  (the captain still holds the assault).
- **Harness (A):** once the required loot is secured, the pilot targets an active captain. This tests the human answer too.
- Re-run seeds 1 and 4242 on loud Hazardous with both parts. The other Hazardous losses (2 and 7: wave-1 wipes; 6501:
  old-map parcels) are bot skill, read the same as RT. Re-run 6501 on the fixed map. Routine and stealth are already PASS.

## D-167: police cuffing on Hazardous+: who cuffs, and when solo fails (2026-10-23, LEAD; P AH Hazardous read #3)
P's done-check read (env/p-play b81fb51a9, AH Hazardous, A's taser fix in): the specials are no longer the cause. The run
ended when a **Wrecker** cuffed the downed pilot seconds after its FIRST down (1/4), and the solo heist failed at once.
Rulings (L2.12 / D-108 / D-145 stand otherwise):
1. **Only regular police cuff.** Specials (Wrecker, Bulwark, Phantom, Stinger, Corpsman, Longshot) and Brandt/Aegis never
   start a police cuff; they fight. PD2's dozers and specials do not arrest (◇ where no source). A: a tested filter in the
   cuff-start check.
2. **Cuffed is not custody.** Per L2.12 a police-cuffed heister stays down with the bleed-out running; a teammate (bot
   included) uncuffs back to DOWNED. Custody comes only when the bleed-out ends. The solo "all humans in custody" fail must
   count custody, not cuffed. A: verify the fail check and the bots' uncuff path, with a test (solo human cuffed + bot alive
   → no fail until the bleed-out ends; a bot uncuffs).
3. **Solo custody = fail stays** (PD2 offline: no trade without another human).
4. Bot cuffer targeting: the D-158.7 levers measured worse on RT and stay off. Re-measure them only after 1 and 2; no change
   now.
P re-reads AH Hazardous (#4) after A's fix; that read is the done-check read.

## D-168: enemy target picking gets a threat term (2026-10-23, LEAD; P deck-feel observation, A analysis)
P saw 0 hits on the human in two Glasshouse legs (a peeking pilot behind cover; all fire on a forward bot). A: there is no bot
bias. PoliceBrain._pick_target is pure nearest-visible (distance² / PerkHooks.aggro_weight), with no threat term, so a human
shooting from cover never draws fire while a closer bot is visible. PD2 weighs attention by distance, visibility and threat
(who is hurting the unit), with stickiness. Ruling:
- A adds a **threat term**: a crew member who damaged this unit (or its squad) within ~3 s scores distance² × 0.5 (◇), plus a
  small retarget stickiness (◇). Both live in a tweak, with tests. Perk aggro weights are unchanged and still multiply.
- Balance guard: re-run the RT and AH Routine loud harness seeds after it lands. Expect at most a small change; if the
  win rate moves, report before tuning.
Also from A's AH co-op soak (PASS 3/3, 0 desync): A splits HeistNetSync._send_xforms into ≤ MTU chunks with a lower rate for
far or calm civilians (the AH crowd sent 4340 B unreliable packets), then gates per-peer NetSync sends until that peer's
runtime is ready (the join race behind the session-start "Node not found" spam).
- (Amendment 2026-10-23, LEAD) P retracted the trigger: in an open leg the human took hits on par with the bots, so the 0-hit legs were
  geometry (bots body-blocking the storefront spawn). The threat term stays on PD2-fidelity grounds; A's balance guard showed no
  win-rate move (RT 4/4, AH 5/5 with the 6501 A/B re-run; human intake 0.71 → 0.71 dmg/s).

## D-169: Rolling Thunder is DONE (2026-10-23 19:50, LEAD; D-115 gates)
All D-115 gates are met (docs/process/heist_completion.md):
- **Stage final, validate --stage=final PASS** on trunk (r307–r310) and on C's final map 62a16962 (regen byte-identical).
- **Final shots:** the LEAD reviewed all 28 (C a506ec73). 22 passed as shot. 6 were fixed and re-shot (C 75e302ad, reviewed):
  carpark stair lit (10 landing bulkheads; it is an escape route), the office sun leak (SUN_SKIP_ROOMS), the shared magenta
  neon 6.0 → 1.8 (diner + Vossberg signs read pink), and the east-arm and welfare reframes. Escort wheel hubs are painted
  metal (b85898ca).
- **e2e:** A's harness, Routine 9/10 and 4/4 after D-168 (env_a.md -50 + the D-168 balance guard). Hazardous losses are bot
  skill. P's windowed confirm pair (clean = truck + 3 bags; blown = harsh but fair) and traversal set are PASS on trunk
  (one-send lift 9.8 s, fences).
- **Co-op:** A's 4-client soak PASS (0 desync in 38/40 rounds; memory within limits).
- **Strings / VO:** B's slice is done. Board / select / briefing were reviewed (r307 shots); the pad-only flow has 0 issues.
- **Cast:** D's in-map reads in both phases; the seated escorts are holstered and grip the new wheel (2877b00f, 2af75541).
- **Ghost gate:** n/a (loud-forced, D-158).
B pushes the RT un-hide patch (rt_unhide_D160) now; it lands in the next round. **Afterhours stays the active build (D-165).**
- (Amendment 2026-10-24, LEAD) Un-hidden in round 311 (9f82f912f). P's windowed main-menu smoke on r311 PASS with real clicks: main menu →
  Board → Contract Broker → briefing → pre-planning → loadout → Start Heist → first-person start → a minute in (env/p-play 647caebe6). Cosmetic
  follow-ups: crew spawn lines (C 3fe9a5d6) and casing bots idling in front of the player (A).
