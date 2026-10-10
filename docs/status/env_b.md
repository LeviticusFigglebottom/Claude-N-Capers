# ENV B status: Content & Progression

Owner: ENV B. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

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
