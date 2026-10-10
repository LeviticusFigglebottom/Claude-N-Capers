# ENV B status: Content & Progression

Owner: ENV B. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

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
