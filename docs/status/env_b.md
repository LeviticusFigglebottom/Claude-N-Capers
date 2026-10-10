# ENV B status: Content & Progression

Owner: ENV B. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-10 18:40 UTC — range on A's runtime, HUD adapter removed, D-034 follow-ups, B2-01/02/03
### Done
- Range on ENV A's crew and weapon runtime (6b7c1af).
  - `CrewController.spawn_for_range` + `set_loadout` on every swap. The WeaponVisual viewmodel is on the crew camera.
  - Last-shot readouts come from our targets' `damage_applied`, filtered to the crew's net id. Ammo is read from the crew's weapons.
  - Panel/aim mode pauses `PlayerInput.enabled`. The test camera and debug gun are FALLBACK ONLY.
  - A headless test drives a real CrewIntent shot and checks exactly one `damage_applied` for 35 damage.
- HUD binds LocalHudModel directly; HudModelAdapter deleted (dd1f97e). A new MarkedTargets widget was added. Tested against a real HeistRuntime on a test map (vitals, ammo, Stinger warning, masked).
- D-034 follow-ups (d1dae61).
  - `defense.post_revive_buff` LIST entries are granted per skill.
  - Plowman shell-by-shell reload: start 0.4, per round 0.5, end 0.4 ◇. Its full reload times are now derived from those.
  - Pellet display exponent 1 (Plowman shows 160).
  - `data/tweak/perk_points.tres` (500 XP per point).
- B2-02 briefing screen (38fd559).
  - ContactDef for vance, reyes, accountant and mercer, with drawn placeholder portrait silhouettes.
  - Shows objectives, loot at difficulty, contract pay and escape options.
  - "Play Briefing" emits local `voice_line_requested` with subtitles; 8 original Glasshouse briefing lines.
- B2-01 pre-planning (b149a9a).
  - 10 generic assets (drops, insider info, cable ties, body bags, alternate entry, voted van position). Cost ×1…×13 by difficulty, 10 favors.
  - PreplanPlan validation and `apply()` hand-off dict; PlanVote with host tie-break.
  - A blueprint drawn in code on a placeholder Glasshouse plan (shown with a banner until real map data exists). Doc: `content/docs/preplanning.md`.
- B2-03 mask customization (c110a03).
  - 5 bases, 9 materials (library refs), 10 colour pairs, 8 patterns. Custom masks go in 6 slots; owned parts are tracked.
  - `MaskComposer`/`MaskCatalog.resolve/descriptor/from_descriptor` for ENV A. Save format v4.
  - Mask screen with an orbit preview and an original pattern shader. Doc: `content/docs/masks.md`.
- Tests use a per-process SaveService root (8eeb53c). Parallel runs in several checkouts shared `user://test_profiles` and flaked.
- `check_all.sh --env b` @ 8eeb53c: PASS (551 tests, 0 failed, 8 skipped).
### In progress
- Wiring the flow heist select → briefing → pre-planning → loadout → launch, the Masks button, and the loadout mask-picker fix for custom masks.
### Blocked
- —
### Questions for lead
- For ENV A:
  - QB-46: Please document a way to pause and resume a crew member's input (the range sets `PlayerInput.enabled`), e.g. `CrewController.set_input_paused(bool)`.
  - QB-47: Who makes the crew camera current, and who attaches `CrewController.weapon_visual`? The range does both itself; heists need an owner.
  - QB-48: Could LocalHudModel track a crew member without a HeistRuntime (a `tracked_crew` node)?
  - QB-49: There is no gamepad look on `PlayerInput`.
- QB-PP1: PREPLAN_POINT node contract.
  - Proposal: a Marker3D in `G.PREPLAN_POINT`, named by point id, with metadata category/label/floor/params (spawn_tag, variant_group, variant_slot).
  - Who bakes the menu blueprint resource: ENV C via HeistRegistry, or B under `data/preplanning/blueprints/`?
- QB-PP2: should HeistLauncher take `options["preplan"] = PreplanPlan.apply()`? The shape is in `content/docs/preplanning.md`; applying it is A2-07.
- QB-PP3: who pays for a voted plan? The stub charges the host.
- QB-PP4: co-op plan votes need a lobby message relay in the Net API, e.g. `Net.lobby_send(kind, data)` plus a `lobby_message` signal. Until then: solo/host only.
- QB-PP5: should the `HeistDef.preplanning` merge format (favors, disable, `asset.<id>` overrides) be recorded in heist_def.gd and data_schemas.md? A Glasshouse sketch for ENV C is in the doc.
- QB-50 (art): contact portraits for ENV D/C go in `content/data/contacts/<name>.tres` `portrait_scene`/`portrait_texture`. The mask base meshes are `assets/masks/mask_base_<heron|visage|vulpine|bruiser|owl>.glb` (face-centre pivot, −Z, front-projected UV0), plus optional pattern textures. See `content/docs/masks.md`.
- QB-51: ENV A should rely on content classes `MaskCatalog.resolve/from_descriptor` + `MaskComposer.instantiate` to attach masks. Record this in characters.md?
### Ready for integration
- yes (everything up to 8eeb53c); `check_all.sh --env b` result: PASS

## 2026-10-10 17:30 UTC — B4-03, B4-04, D-031 key grants; state-tolerant tests for A-M2/M3
### Done
- State-tolerant tests (8554760). The range accepts either the real crew or the temporary camera; the HUD binds a v1.1 model directly or an A1-11 model through the adapter. Verified on a trial merge with origin/env/a-core.
- D-031 (1a48390). Every requested key is granted and `blocked_on_keys` is empty; the strict test is restored as `test_no_blocked_parts_and_every_requested_key_is_granted`.
  - LIST merge: see QB-38.
  - Routing: `team_perk.<deck>` for perk `team.*`; `team_skill.<id>` for skills; neither duplicated in personal modifiers.
  - Hustler vests are Light, Patrol and Heavy only.
  - The suppressed concealment qualifier counts once per suppressed weapon.
- B4-03 (d3796a1). Skill tree screen and perk deck screen, opened from the loadout screen.
  - Tiers, basic/aced, and a refund that is blocked if it would break a tier gate (PD2 style).
  - Free respec with confirmation; 3 skill sets.
  - Save format v3 (`skill_sets`, `active_skill_set`, `perk_cards`) with a 2→3 migration.
  - Perk points = floor(total XP / 500) ◇. Each deck keeps its own card progress, unlocked in order.
- B4-04 (59a7bdc..ac7447d). Six weapons with models and previews:
  - Warden .45 (pistol), Hornet 9 (SMG, secondary), Corsair (AR), Plowman 12 (pump shotgun, 10 pellets), Rampart (LMG), Heron .308 (bolt sniper: AP, shield and wall pierce, falloff min 1.35).
  - 30 mods (shared rail reflex and prism optics) and stock parts. Deterministic: 92/92 identical files.
  - Throwables `throwable.steady_flask` and `throwable.boss_injector` exist for the perk decks.
  - P9 previews re-rendered with the library materials.
- `check_all.sh --env b` on a fresh merge with trunk 5d1cc0f: PASS (326 tests, 0 failed, 7 skipped).
### In progress
- —
### Next (queued, ≥2 h)
- After A-M2/M3 land on trunk: switch the range to the real crew and weapon runtime (debug camera only as a fallback), delete HudModelAdapter, bind the HUD directly.
- Apply `progression.xp_mult` in PayoutCalculator.
- Pending lead answers below: shotgun per-shell reload, shotgun display damage.
### Blocked
- —
### Questions for lead
- QB-38 (LIST emit shape; core change needed). `Loadout.modifiers[key]` holds `Array[Dictionary]` for the LIST keys:
  - One deep-copied entry per granting skill or card, each tagged `"_source": StringName` (a skill id, or `perk.<deck>.card<n>`).
  - Entries are sorted by `ContentDB.id_less`; within one skill the aced dict replaces the basic one.
  - `Modifiers.list()` currently casts `values[key] as Dictionary`. Please make it accept an Array: append each entry and keep its own `_source`, setting `_source` to the source name only when the entry has none.
- QB-39. `defense.post_revive_buff` (PARAMS, last-wins) is granted by two skills, Back on Your Feet and Second Lease, so one overrides the other. Should it become LIST, or should we merge the grant?
- QB-40 (schema additions marked ◇ in skills.md; please confirm):
  - `weapon.kill_reload_buff.mag_falloff_from` (Run and Gun: "per round above 20").
  - Bulletstorm duration = lerp(base, max, fraction of the refill taken).
  - `weapon.melee_bloodthirst.max_mult` = 17.0 (+1600%).
- QB-41 (materials, ENV C). The new weapons also need `alu_anodized_black`, `polymer_tan`, `polymer_olive` and `glass_lens_coated`. Library `polymer_black`, `rubber_black` and `metal_matte` also render quite light on weapons.
- QB-42 (ENV D anim sets, ENV C cues). Viewmodel sets `smg`, `rifle`, `shotgun`, `lmg` and `sniper`, plus `cue.weapon_<set>_fire(_suppressed)` for each. Should the Warden .45 share the pistol set? Animated parts for ENV A: the shotgun `Pump` (slides +Z) and the sniper `Bolt`.
- QB-43. Shotgun reload is whole-tube today; PD2 loads shell by shell. Add `WeaponStats.reload_per_round_s` (or similar)? Separately, the display damage for pellets shows 16 instead of a PD2-style 160. B will set `damage_pellet_exponent = 1` in our display tweak unless you object.
- QB-44. Record in visual_slots.md: `Magwell` sits at the loading port on tube-fed weapons; bipods are a flat recoil bonus until a deploy mechanic exists.
- QB-45. Perk points: floor(XP / 500) from all XP (◇, about 23k points by level 100). Is that OK? The setting lives in `data/ui/progression_ui.tres`; move it to `data/tweak/`?
### Ready for integration
- yes (B4-03, B4-04, D-031 grants); `check_all.sh --env b` result: PASS

## 2026-10-10 16:30 UTC — B4-01 skills, B4-02 perk decks (P4 pulled forward, D-027)
### Done
- D-027 crit rule on range targets (crit ⇒ head mult on any zone; stacks on head), with a test.
- B4-02 (358df11): 14 perk decks × 9 cards in `data/perks/`.
  - Costs 200…4000, totalling 13,700.
  - Shared cards 2/4/6/8 are identical in every deck: Headhunter `weapon.headshot_mult.all` 1.25, Low Profile `stealth.concealment_add.all` 1, Go Bag `weapon.ammo_pickup_mult.all` 1.35, Hustle `weapon.damage_mult.all` 1.05.
  - Signature mechanics use their `perk.*` PARAMS key, with each upgrading card granting the FULL dict (last-wins).
  - Health/armor/dodge cards grant cumulative ratios so the running product equals PD2's additive total (e.g. Bulk = 2.0 health).
  - **Param schemas for review: `game/content/docs/perk_decks.md`.**
- B4-01 (53d0cec): 90 SkillDefs in `data/skills/<tree>/<subtree>/`, plus `SkillTreeDef` (`data/skills/trees.tres`).
  - Tiers 1/2/2/1; costs 1/3, 2/4, 3/6, 4/8 (46 per subtree, 138 per tree); gates 0/1/3/18 counted on lower tiers only; 120 points at level 100; free respec.
  - `SkillPoints.validate/can_unlock/is_legal` handle host legality (architecture §11).
  - Team skills: `team.*` grants are routed through `LoadoutResolver.team_modifier_sources()` as `team_skill.<id>` (non-stacking). `resolve_modifiers` excludes them.
  - Expressibility: 32 skills fully expressible, 29 partial, 29 blocked on keys. Every tier 3–4 skill has a "decision it changes" note.
  - **Full design, mapping conventions and requested keys: `game/content/docs/skills.md`.**
- ContentDB now scans kind folders recursively (needed for the skills layout).
- `check_all.sh --env b` @ ea708fa: PASS (266 tests, 0 failed, 7 skipped).
### In progress
- B4-03 skill tree + perk deck UI (subagent).
- B4-04 armory expansion: 6 weapons + mods + models, the 2 deck throwables, and P9 re-render with ENV C's materials (subagent).
### Blocked
- —
### Questions for lead
- QB-31 (keys for skills): 71 requested keys, grouped with types, semantics and the skills that need them, in `content/docs/skills.md` "Requested keys". 29 skills stay inert until keys exist; a test fails as a reminder when a requested key gets registered. Two of them (`weapon.kill_reload_buff`, `weapon.hit_stack_buff`) are wanted by several skills, which a last-wins PARAMS key can't carry. They need a list-valued or per-source PARAMS design.
- QB-32 (keys for perks): `progression.xp_mult` (MULT), `movement.armor_penalty_mult` (MULT), `deploy.armor_bag` (FLAG), `interaction.doctor_bag_speed_mult` (MULT), `progression.card_drop_quality_add` (ADD), `ability.shout_range_mult` (MULT), optionally `team.armor_regen_delay_mult` (MULT). See `content/docs/perk_decks.md`.
- QB-33: perk param schemas (14 `perk.*` keys plus `team.damage_reduction_hostage`) are proposed in `content/docs/perk_decks.md` for review. ENV A implements them. The registry descriptions of `perk.rogue_dodge_stack` and `perk.crook` should be reworded to match the decks.
- QB-34 (stacking): PD2 adds skill and perk percentage bonuses; our MULT multiplies across sources. Keep multiplicative (the deck cards then use cumulative ratios), or switch some keys to additive semantics?
- QB-35: do `team.*` grants also apply to the granting player? Our TEAM source does apply to them, and we strip `team.*` from personal sources to avoid double counting. Perk-deck `team.*` grants (Foreman) currently stay on the personal source. Should they also go to a TEAM source, e.g. `team_perk.<deck>`?
- QB-36: is `interaction.revive_speed_mult` a time multiplier (lower = faster), like the other interaction keys? Rally Cry assumes so.
- QB-37: Hustler armor tiers: "mid vests only" (fidelity table) vs "all ballistic vests" (research). We used all vests except the suit.
### Ready for integration
- yes (B4-01, B4-02); `check_all.sh --env b` result: PASS

## 2026-10-10 15:40 UTC — D-026 review fixes (B1-03, B1-04, B1-05)
### Done
- StringName sort bug: every id sort now goes through `ContentDB.sort_ids()/id_less()` (by text; ints numerically). This covers `ContentDB.all_of`, the HeistCatalog, and the resolver's skill order (PARAMS last-wins is deterministic). Regression tests create `zz_` ids before `aa_` ids at runtime. The catalog test is now order-proof.
- damage.md: `RangeTarget.take_hit(info, attacker)` is the only hit path. HEAD = dummy zone mult × `info.headshot_bonus`. The target emits `damage_applied` itself and returns final_info. `apply_damage` and the `damage_applied` listener are removed. Targets join `G.RANGE_TARGET`. The debug gun uses `Damage.find_target/zone_of/info`.
- `weapon.kestrel_p9` headshot_mult = 1.0 (weapon bonus). Range golden unchanged: 35 × 2 × 1.0 = 70 at Routine.
- WeaponVisual stock parts follow the `Stock<ModType>` rule. The glbs already matched, so no rebuild.
- The HUD binds to ENV A's shipped `LocalHudModel` through `content/ui/hud/hud_model_adapter.gd` (stopgap; see QB-28). MenuFlow binds `runtime.hud_model` after launch.
- `check_all.sh --env b` on a fresh trunk merge, run twice: PASS both times (194 tests, 0 failed, 7 skipped). The 4 P1 gate tests skip waiting for ENV C's Glasshouse map; the direct-launch stub test skips now that HeistLauncher exists; 1 is the P4 stub; 1 other skip.
### In progress
- —
### Blocked
- B1-08 mask mesh (ENV C).
### Questions for lead
- QB-28: ENV A's `LocalHudModel` does not follow ui_hud.md v1.1.
  - It uses a single `changed(property)` signal.
  - It uses `ammo_mag/ammo_reserve`, `detection_indicators`, `pager_timers`, `teammates`, `ecm_time_left`, `camera_countdown`, `phantom_warning/stinger_warning` and `bleedout_time_left`.
  - It has no `deployable_id/throwable_id/pagers_max`, and `marked_targets` are bare net ids.
  - It never joins `G.LOCAL_HUD_MODEL`.
  - Our adapter bridges the gap for now. Our guesses: `pagers_max` = 4 from HudTweak; `pagers_answered` counted from EventBus; pager progress = 1 − time_left/answer_s; marked kind is empty.
  - Please have ENV A conform to v1.1 and join the group, so the adapter can be deleted, or amend the contract.
- QB-29 (damage.md): a crit off the head can't be expressed, because the target applies `headshot_bonus` only on HEAD. In PD2 a crit deals headshot damage on any zone. Should `crit` make the target apply its head multiplier regardless of zone?
- QB-30 (damage.md): WEAKPOINT on targets without plates. Range dummies now take ×1 for WEAKPOINT. Range dummies don't emit `npc_killed`, since they aren't NPCs. Please confirm both.
### Ready for integration
- yes; `check_all.sh --env b` result: PASS

## 2026-10-10 15:05 UTC — B1-03, B1-05, D-024 app shell (all P1 B tasks delivered)
### Done
- D-024 app shell (f50c21c):
  - Direct launch: `godot --path game -- --heist=<id> [--seed=n] [--difficulty=0..5]` (`LaunchArgs`). It skips the menus, launches solo with the saved loadout, and spawns the HUD and payday screen. Bad input logs an error and shows the main menu.
  - The HUD finds its model via `G.LOCAL_HUD_MODEL`, and the mock joins that group.
  - The heist list comes from `HeistRegistry`; the Glasshouse placeholder shows only while its def is missing. No `res://world` paths remain.
- B1-03 (9e6eb48): `tools/blender/weapons/kestrel_p9.py` and `kestrel_p9_mods.py` on ENV C's lib, built with Blender 4.5.14 and deterministic (12/12 identical).
  - Tris: pistol 8,510; suppressor 3,424; extended magazine 2,000; reflex sight 1,108; standard magazine 788; iron sights 224.
  - All 10 visual_slots markers, plus a moving `Slide` node.
  - `WeaponVisual` (content/weapons) attaches mods at their markers per ModType and hides replaced stock parts.
  - Data `model` fields are wired. Previews: `game/assets/weapons/kestrel_p9_preview_*.png`.
- B1-05 (ed3308e + 00307fd): firing range `content/range/firing_range.tscn`, opened from the main menu.
  - Hall built from arch_* pieces: 9 lanes, with signs and lines at 5/10/15/20/30/40/60/80/100 m (layout comes from data).
  - Silhouette targets with head and body hitboxes; HP per difficulty from a B-owned dummy table (light-TAC row) until EnemyDef ships.
  - Damage numbers; a stat panel; free weapon and mod swap; a difficulty selector; DPS and TTK readouts.
- `check_all.sh --env b` @ HEAD: PASS (155 tests, 0 failed, 5 skipped).
### Stopgaps to delete when ENV A lands A1-02/A1-08
- `content/range/range_spectator_input.gd` and `range_debug_gun.gd`: the temporary range camera and debug hitscan. The range uses ENV A's crew via `RangeCrewBridge` when it exists.
- `RangeDummyDef.health/headshot_mult`: a copy of the light-TAC row, to switch to `EnemyDef` (D-010). `RangeMath`: switch to ENV A's runtime as the reference.
### Target hit API
- Superseded by damage.md (D-026); see the entry above.
### In progress
- —
### Blocked
- B1-08 mask mesh (ENV C).
### Questions for lead
- QB-20 (contract precision, ui_hud.md v1.1): please state the types: `detection[].kind` = Enums.ObserverKind, `marked_targets[].kind` = StringName, `objectives[].state` = Enums.ObjectiveState, `carried_bag.weight` = Enums.LootWeight, `ammo` keys = int WeaponSlot. Also, interaction `args` formats `blocked_reason` too.
- QB-21 (materials, ENV C): the weapons use M_polymer_black, M_polymer_stipple, M_steel_blued, M_steel_bare, M_metal_matte, M_paint_white, M_brass_cartridge, M_glass_lens_tint (alpha 0.3) and M_emissive_reticle_red. None exists in world/materials yet, so they import with flat placeholder colours and a warning. Can ENV C add them? Is a library id OK for the emissive and transparent ones?
- QB-22 (viewmodel conventions, ENV A + visual_slots.md):
  - The weapon origin is the firing-hand pivot (grip centre plane, mid-grip, 20 mm below the grip top). Is that OK?
  - `Slide` cycles along local +Z.
  - Proposal: add an optional `AimPoint` marker (ADS alignment) and allow mods to carry their own `Muzzle` (suppressor tip). ENV A should then use `WeaponVisual.get_marker(&"Muzzle")`.
  - On pistols, `SideRail` and `Underbarrel` share the dust-cover rail.
  - Stock-part naming (`StockSight`, `StockMagazine`, ...) could go into data_schemas.md.
- QB-23 (cues): beyond `cue.weapon_pistol_fire(_suppressed)`, do we want `cue.weapon_pistol_mag_out/mag_in/slide_release` for reloads?
- QB-24 (range group): add `G.RANGE_TARGET = &"range_target"` to ids.gd and groups.md? Range targets are kept out of `G.ENEMY` and `G.NPC` on purpose, so AI never treats them as enemies.
- QB-25 (range crew contract): proposed `CrewController.spawn_for_range(parent, xform, loadout) -> Node`, plus `set_loadout(loadout)` for instant swaps, for ENV A to implement. The range already looks these up dynamically.
- QB-26 (headshots): `WeaponStats.headshot_mult` (P9 = 2.0) and `EnemyDef.headshot_mult[difficulty]` overlap. The range uses the enemy value and treats the weapon one as a fallback; multiplying both would give ×4. Which is canonical? Should one be removed or redefined as a bonus?
- QB-27 (hit path): should ENV A call the target directly (`apply_damage`/`take_hit`) or only emit `damage_applied`? Either works, but never both. Also, consider putting the hitbox convention (layer 5 + `get_damage_target`/`get_hit_zone`) into a contract.
### Ready for integration
- yes (B1-03, B1-05, D-024 app shell); `check_all.sh --env b` result: PASS

## 2026-10-10 14:20 UTC — B1-04 (B-M2 UI), D-022 follow-ups
### Done
- D-022 follow-ups (d940c9e):
  - The strings test is un-skipped.
  - The mod-delta test now checks against `make_delta()`. It caught 5 mod files that weren't zeroing `falloff_min_mult`, `headshot_mult`, `noise_radius_m` and `magnification`; all are fixed.
  - `concealment_bonus()` is wired to `stealth.concealment_add`, added after the per-weapon 30 cap. A slot-qualified bonus counts only while that slot is filled.
  - Breacher Plate now has `unlock_skill` = `skill.juggernaut.plated`.
  - There is a test that special ids are canonical, and a TODO(P4) stub for empty weapon slots.
  - The stealth bonus is banked to the next payday (S11.1): `banked_stealth_mult` is in the profile, the save format is v2 with a 1→2 migration, and the payout outputs `stealth_bonus_banked/consumed`.
- B1-04 UI (470ee68 + 3d0fdc5):
  - Flow: `ui/menus/menu_flow.tscn` (main menu → heist select + difficulty (Routine/Brutal unlocked) → loadout with live display stats and DR → launch). It calls `HeistLauncher.launch` dynamically when present; otherwise it shows a stub with a sample payday.
  - HUD: `ui/hud/hud.tscn`, with 9 widgets (detection chevrons, interaction prompt and bar, vitals, ammo and inventory, pagers, objectives, assault banner, teammates, masked/casing). It binds to a `LocalHudModel` found at runtime, or to `ui/hud/mock/MockHudModel`. Demo: `ui/hud/mock/hud_demo.tscn`.
  - Payday: `ui/results/payday.tscn` shows cash lines, the 80/20 split, the C6 XP lines, the level bar, "stealth bonus banked", and crew stats. It applies and saves to the profile.
  - Shared theme in `ui/theme/`; gamepad/keyboard focus chains; every string comes from strings.csv (test-enforced).
  - Visually checked at 1920×1080 under xvfb (menu, loadout, HUD demo, payday).
- B1-08: the default profile owns and wears `mask.gilded_heron`.
- `check_all.sh --env b` @ 3d0fdc5: PASS (116 tests, 0 failed, 5 skipped: 4 waiting on HeistLauncher, 1 is the P4 stub).
### For ENV A (LocalHudModel shape the HUD reads; please pass this on or put it in ui_hud.md)
- The HUD reads properties by `get()` and connects signals by name (signal args are ignored). Assign new Arrays/Dicts rather than editing them in place.
- `vitals_changed`: health, max_health, armor, max_armor (float); downs_left; crew_state (Enums.CrewState); bleedout_s (<0 = none).
- `ammo_changed`: ammo {WeaponSlot: {mag, reserve}}; equipped_slot.
- `inventory_changed`: deployable_id, throwable_id; deployable_count, throwable_count, cable_ties, body_bags.
- `carried_bag_changed`: carried_bag {} or {loot_id, weight}.
- `interaction_changed`: interaction {} or {text_key, args, progress 0..1, blocked_reason (strings key or &"")}.
- `detection_changed`: detection [{observer_net_id, world_pos, value, kind}].
- `marked_targets_changed`: marked_targets [{net_id, world_pos, kind}].
- `pagers_changed`: pagers [{pager_id, time_left_s, answering, progress}]; pagers_answered, pagers_max.
- `timers_changed`: ecm_time_left_s, camera_alarm_s (<0 = inactive).
- `objectives_changed`: objectives [{id, text_key, args, state}].
- `assault_changed`: assault_phase, assault_wave.
- `hostages_changed`: hostages.
- `warnings_changed`: warnings Array[StringName] (&"phantom", &"stinger").
- `crew_changed`: crew = teammates only [{slot, name, is_ai, health_frac, armor_frac, state, downs_left, carried_loot_id}].
- `masked_changed`: masked, casing.
### In progress
- —
### Blocked
- B1-03 weapon models on ENV C C1-01; B1-05 firing range on C1-02; B1-08 mask mesh on ENV C.
### Questions for lead
- QB-14: Who spawns the in-heist HUD? Today MenuFlow adds a CanvasLayer with the HUD and the payday screen next to itself. Should HeistRuntime instance a UI scene instead? That would need a path contract.
- QB-15: Could LocalHudModel join a group (e.g. `G.LOCAL_HUD_MODEL`)? Today the HUD searches the tree by class name every 0.5 s until it finds it.
- QB-16: After `heist_ended`, the UI calls `HeistRuntime.teardown()` and `Net.leave()` when the player presses Continue. Does that belong to ENV A instead?
- QB-17: The Firing Range and Settings buttons say "coming soon" for P1. OK?
- QB-18: `docs/contracts/ui_hud.md` still says `en.csv`; the file is `strings.csv` (D-021).
- QB-19: Heist list: `content/data/ui/heist_list.tres` points at `res://world/heists/glasshouse/glasshouse_def.tres` (data, not code). Until ENV C's def exists, it falls back to a placeholder with base payout 40000 ◇. Is that path convention right?
### Ready for integration
- yes (B1-04, D-022 follow-ups); `check_all.sh --env b` result: PASS

## 2026-10-10 14:30 UTC — B1-01, B1-02, B1-06, B1-07 (B-M1 done); B1-08 data; B1-04 in progress
### Done
- B1-01 data (c47c8db): `weapon.kestrel_p9` (Halvard Arms) + mods suppressor / reflex sight / extended mag (+ stock iron sights, standard mag); `melee.folding_knife`; all 7 armor tiers (L2.3 values; Tailored Suit + Patrol Vest are the P1 ones); doctor bag, ammo bag, body bag case; loot jewelry / cash / body bag; all 6 difficulties (loot ×1/2/2.6/4.2/7.2/9.2, XP ×1/2/5/10/11.5/14); concealment curve with every anchor from research §1.2 exact; provenance and ◇ list in `game/content/data/README.md`.
- B1-02 (5e18413): `LoadoutResolver` (stats, mod legality/conflicts, concealment, DR, modifier merge by key type), `StatCalculator` (PD2-style display numbers + green/red deltas), `ContentDB`. Golden tests: all curve anchors, the research §3.3 worked example (63 + 56 → 119 → DR 3), and the stock/vest/suppressor loadouts.
- B1-06 (03104f6): `SaveService` v1: versioned JSON, atomic write with .bak, corrupt→backup→default fallback, newer-version refusal, migration chain (0→1 scaffold), `apply_heist_payout`; default profile comes from data.
- B1-07 (5d904cd): `strings.csv` (380 keys, standard CSV import per D-021); 137 original voice lines (Mercer for 23 events, plus 4 heisters × 11 barks); `PayoutCalculator` applies every multiplier (D-020), with 80/20 stash split and C6 XP order; `XpCurve` 0–100 (PD2 shape ×0.5).
- B1-08 data: `mask.gilded_heron` on the contracts `MaskDef` (D-019); needs a mesh from ENV C.
- `check_all.sh --env b` @ 0ed1312: PASS (79 tests, 0 failed, 5 skipped: 4 waiting on HeistLauncher, 1 waiting on the translation registration).
### In progress
- B1-04 UI: menu → heist select/difficulty → loadout → launch (stub until A1-01), HUD against `MockHudModel` (ui/hud/mock), payday screen.
### Blocked
- B1-03 weapon models on ENV C C1-01; B1-05 firing range on C1-02; B1-08 mask mesh on ENV C.
### Questions for lead
- QB-4: Please register `res://content/data/strings/strings.en.translation` in project.godot (D-021). After that, the skipped StringTable test runs.
- QB-5: `WeaponStats` defaults are non-zero (pellets 1, falloff 20/40, equip 0.5, ads 0.25), and `plus()` adds them, so a mod delta silently adds a pellet and 20 m of falloff unless it zeroes them. Our deltas all zero them and a test enforces it. Can you add `WeaponStats.zero_delta()` or a separate delta schema?
- QB-6: P4 needs a concealment-bonus modifier key (Inner Pockets / Blending In / Optical Illusions analogs), e.g. `stealth.concealment_add` (ADD, qualifier melee/armor/weapon). `LoadoutResolver.concealment_bonus()` is the hook.
- QB-7: `ArmorDef` has no skill-unlock field, and Breacher Plate needs the Iron Man analog. Can you add `unlock_skill: StringName`?
- QB-8: What unit is `WeaponStats.ammo_pickup_min/max`? We used rounds per pickup.
- QB-9: `DifficultyDef.special_limits` uses ids `enemy.bulwark/stinger/corpsman/phantom/wrecker`. Please confirm ENV A's EnemyDef ids match.
- QB-10: Weapon cues `cue.weapon_pistol_fire` and `cue.weapon_pistol_fire_suppressed` are referenced by `weapon.kestrel_p9`. Can you pass them to ENV C via audio_cues.md?
- QB-11: P1 loadouts have no primary. We count an empty weapon/melee/armor slot as concealment 30 (data: `empty_slot_concealment`), so a stock loadout is 120 → DR 3. Is that OK, or should an empty primary count as 0 (forcing DR 75)?
- QB-12: Payout contract additions: `compute(result, diff, tweak, is_pro, crew_slot)` adds `crew_slot` (whose civilian kills/custody count; -1 = crew-wide) and a `gross` field. OK?
- QB-13: The civilian penalty comes only out of spending cash (PD2) and also applies on failure; the stealth XP bonus (×1.2 ◇) applies to the same heist, not the next one as in PD2; AI teammates count toward the crew-alive XP bonus. Confirm or overrule.
### Ready for integration
- yes (B1-01, B1-02, B1-06, B1-07, B1-08 data); `check_all.sh --env b` result: PASS

## 2026-10-10 00:00 UTC: (not started)
### Done
- Environment created by lead.
### In progress
- —
### Blocked
- —
### Questions for lead
- —
### Ready for integration
- no
