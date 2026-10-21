# Rolling Thunder: ENV B content plan (paper; D-148 next heist, reuse-first D-147)

LEAD 2026-10-21: paper start now; **no RT data on env/b-content until the OF done check**. Source of truth:
`docs/design/heists/rolling_thunder.md` (C's doc: Objectives, Loot path, Variable table, Rare events, Escape,
Pre-planning, HeistDef sections). Checklist = OF-B1 (§6 of next_heist_ostrander.md) and
`next_heist_prep_rt_ah.md`. "Reuse" = an existing id / file / pattern; "new" = B writes it.

## 1. Def values and variant data (B values; C's generator writes the files)

| Item | Value | Reuse / new |
|---|---|---|
| `base_payout` | $85,000 (doc, B6-01 placeholder; D-120 shape: bags should be ~60-80% of a full clear, as DB 81%) | check vs gold 14k / cash bricks 8k at 4-8 bags |
| Loot | `loot.cash_bricks`, `loot.gold`, `loot.bearer_bonds`; tool `loot.thermite` | **reuse, no new loot ids** |
| Contact | `contact.reyes` (51 lines, radio set exists) | reuse |
| Mode | STEALTH_OR_LOUD, label "Loud (ambush start)" (D-075) | reuse mode; new label string |
| D-148 XP | `base_xp_by_heist[&"rolling_thunder"]`: **2,500** (M-L: ambush + holdout) | new row in payout.tres |
| Stealth bonus | loud-ending job: `stealth_bonus_mult` 1.0 (as DB) | reuse pattern |
| Difficulty rows | special limits follow the D-145 rows (Routine/Tense Longshot 1); `pager_max_by_difficulty`: none (setup pagers = marshal only) | reuse |
| Variant / scalar values | convoy_route 0.55/0.45; cash_bags 4/5/6; gold_bags 3/4; controller 0.7/0.3; site_stores; guard_post / camera picks; cop_on_scene; marshal_walk; goods_lift 0.6/0.4; player_perch; escape 0.4/0.35/0.25; convoy_eta_s 150/180/210; police_delay_s; escape_eta_s; civilians 6/9/12 | values block to C (doc's table is the draft; B confirms per difficulty) |
| Rare events | bonds_courier 8%, informant_tip 6%, gold_rush 4%, marshal_early 8%, convoy_early 6%, crane_sniper 8% (Brutal+), armored_escort 6% (Lethal+), rush_hour 6% | names + briefing "surprises" strings (new) |

## 2. Strings (`strings.csv`)

| Group | Count | Status |
|---|---|---|
| `heist.rolling_thunder.*` (name, tagline, briefing, ...) | 4 | **exist**; briefing prose to re-read against the final doc (route, escapes, 4 bags) |
| `objective.rolling_thunder.*` | 13 = every doc tag (casing, signals, charges, thermite, marshal, convoy, ambush, escort, trucks, cargo, secure, escape_wait, escape) | **exist**; add `{opened}/{total}` to `trucks` and `{count}/{total}` to `secure` if missing (ALLOWED_ARGS has count/total) |
| `ui.briefing.step.rolling_thunder.*` | ~2 merges (setup "rig the signals / raid the stores", loud "open the trucks and bag the cargo") | new (OF pattern) |
| `ui.preplan.point.rolling_thunder.<point>` | 13 points (3 spawns, 4 drops, 3 escapes, 2 perches, signals) | new |
| Blueprint labels (rooms / streets / holdouts H1-H4) | ~20 from the G1 map | new (generated from the map, as OF) |
| Escape names | van (car park), van (underpass), helicopter (roof) | reuse `escape` keys if generic, else 3 new |
| Rare-event / surprise names | 8 (above) | new |
| Item / loot names | C4 (`item.item.c4.name` exists), thermite, cash bricks, gold, bonds | **reuse** |
| Interaction blocked reasons | "the convoy is locked down" (alerted trucks) if A adds a reason key; `ui.blocked.device_running` is drill-worded: a saw-neutral key (B's GPU-9 note) | new, on A's request |
| Mode label "Loud (ambush start)" | 1 | new |

## 3. Voice (Mercer + Reyes; `lines.tres` + `voice.vo.*` strings; `test_vo_coverage`)

From the doc's mission notes, by phase (each line said by the mission, or deleted; OF had 77):
- **Setup (Mercer):** intro, convoy ETA 60 / 30, marshal arriving, signals rigged, signals reminder, C4 found,
  thermite found. (~8)
- **The stop:** convoy sighted, stopped (clean), go, alerted (early alarm), crash, escort down, police called. (~7)
- **Devices / loot:** saw on, saw jam, truck open (per method: saw / C4 / thermite), C4 armed, thermite burning,
  gold found, bonds found, lift dead. (~10)
- **Snipers:** Skyway sniper, rail sniper (crane sniper on the rare event). (~3)
- **Endgame:** required secured, van ETA, heli ETA, escape. (~4)
- **Reyes (`SPEAKER reyes`):** in position, ram, boxed in, payday; plus the radio objective-new / secure lines
  (contact-radio pattern; DB already has Reyes radio lines to reuse the shape). (~6-8)
- **Reuse:** generic radio `radio.objective_new`, generic last-pager (`own_last_pager_line` false: the marshal is
  the only pager), generic assault / escape-arrived lines.
- Total ≈ **35-40 new lines** (fewer than OF's 77: one setup phase, no time lock).

## 4. Briefing and pre-planning

- **Briefing intel** (`briefing/intel/rolling_thunder.tres`): `intel_export.gd` on the G1 map (guards, cameras, the
  marshal, the convoy units per difficulty from the doc's Convoy table, trucks 2-3, surprises). Needs the map.
- **Blueprint** (`preplanning/blueprints/rolling_thunder.tres`): 4 floors (Underpass / Street / Upper / Roof); from
  C's plan render. Needs the map.
- **Pre-planning assets** (doc's `HeistDef.preplanning`): **all library assets exist** (ammo, doctor, body-bag case,
  thermite drop, sniper position, lift power, intel guard posts / cameras, extra cable ties, spare body bags,
  alternate entry, escape position) and **`asset.signal_insider` + `asset.intel_route` already exist**.
  **Missing: `asset.c4_drop`** (needs A's QC-84 item drop kind). Favors 5. Costs ◇ from the doc (c4 2,000 / 2,
  signal insider 1,500 / 1, intel route 1,500 / 1).

## 5. Achievements (+ mask-part rewards from ENV D's catalog; payday e2e copy of test_of_payday_e2e)

Proposed set (6, OF shape), conditions on existing achievement fields / HeistFacts:

| id | condition | fields |
|---|---|---|
| `achievement.rt_clean_stop` | clear with the signals rigged (clean stop, no crash) | `objectives_completed: [signals]` (exists) |
| `achievement.rt_no_escort` | clear with the escort taken down | `objectives_completed: [escort]` (exists); "before the trucks open" would need an order fact (new, A event) |
| `achievement.rt_heavy_haul` | secure ≥ 4 gold bags | `loot_min` (exists, as used by 4 achievements) |
| `achievement.rt_sky_high` | clear by the heli with the lift dead | **new condition**: a variant match (`goods_lift = lift_dead`, `escape = esc_heli_roof`); only `max_time_variant` reads variants today |
| `achievement.rt_quick` | clear in under N min (speed, as OF Bank Holiday) | `max_time_s` (exists) |
| `achievement.rt_cataclysm` | any clear on Cataclysm | `difficulty_min: 5` (exists) |

Rewards: one mask part each (pattern / material / base), names via `AchievementsScreen.reward_name`.

## 6. UI checks before / at G1 (no data)

- **Moving objective marker** (the convoy) and the escort count on the objective line: mock in the HUD contrast
  worker; check the marker clamp (r252 `label_x`) on a target that drives across the screen edge.
- **Trucks n/N** on the objective line and per-truck device timers (saw / thermite) at once: two device widgets
  stacked (OF had one time lock).
- **Heli secure zone** (bags thrown in) feedback: the "Secured: n bags" toast as on OF.
- Real-input menu pass 720p / 1080p and the payday e2e once A's phase-2 e2e is green; un-hide in heist_list then.

## 7. Order (once the OF done check clears)

1. Def values + variant values block to C (§1).
2. Strings not needing the map (§2 briefing steps, preplan point labels, rare events, mode label).
3. Voice lines (§3) + `test_vo_coverage` allowlist entries.
4. Achievements (§5) + tests, D's parts.
5. After C's G1: briefing intel, blueprint, blueprint labels, preplan wiring (`asset.c4_drop` after QC-84).
6. Extend the B tests (`test_heist_text_audit`, `test_heist_achievements`, `test_briefing_intel`,
   `test_heist_readiness`, `test_p5_catalogue`, `test_vo_coverage`) and the payday e2e.
