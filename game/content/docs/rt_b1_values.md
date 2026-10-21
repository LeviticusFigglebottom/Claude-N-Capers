# RT-B1: Rolling Thunder values block (QB-2 shape, PAPER)

ENV B -> ENV C (cc LEAD), 2026-10-21. **Paper only (D-144 / D-148): nothing here is in data on env/b-content until the
Ostrander done check.** C's generator writes `rolling_thunder_def.tres` / `_variants.tres` from this block (QB-2, D-137);
B writes its own files (assets, strings, VO, achievements) when the gate opens. Sources: `docs/design/heists/
rolling_thunder.md` (G0 + RT-C0 fixes), `docs/process/next_heist_rolling_thunder.md` (§3 audit, D-149 rulings),
`game/content/docs/rt_content_plan.md`. Supersedes rt_content_plan.md §1 where they differ (**base_payout is $30k**,
D-141.1, not the G0 doc's $85k).

## 1. HeistDef values

| Field | Value | Why |
|---|---|---|
| `id` / display | `rolling_thunder` / "Rolling Thunder" (string exists) | — |
| `contact` | `contact.reyes` | exists, district `southfield` |
| `mode` | STEALTH_OR_LOUD, mode label "Loud (ambush start)" (string exists) | D-075 |
| `base_payout` | **30,000** (pinned by `test_p5_catalogue.gd`, D-141.1) | D-120 shape: 4 required cash bags = 32k unscaled, so the bags are >= 52% of a minimum clear and ~70-80% of a full one (6 cash + 4 gold = 104k) |
| `loot` | `[loot.cash_bricks, loot.gold, loot.bearer_bonds]`; tool `loot.thermite` | no new LootDef |
| `escape_options` | `[van, heli]` | doc §Escape |
| `music_track` | `rolling_thunder` (C's stems; until then the heist default) | — |
| `stealth_bonus_mult` | **1.0** (the job always ends loud; as DB) | S11.1 |
| `pager_max_by_difficulty` | none (only the marshal carries a pager; tweak default) | D-130 |
| `camera_titan_min_difficulty` | -1 (tweak default, Lethal) | — |
| `objectives` | `[casing, signals, charges, thermite, marshal, convoy, ambush, escort, trucks, cargo, secure, escape_wait, escape]` (13; every string exists) | doc |
| `briefing_objectives` | `[casing, ui.briefing.step.rolling_thunder.setup, convoy, ui.briefing.step.rolling_thunder.trucks, secure, escape]` | merged setup / truck steps (OF pattern, D-117 §4) |
| D-148 XP | `PayoutTweak.base_xp_by_heist[&"rolling_thunder"] = 2500` (B's payout.tres) | size M (D-149.3), ambush + holdout |

## 2. Variant rows (C writes them; B's values)

| Group | Slots / scalar | Weights (Routine / Tense / Hazardous / Brutal / Lethal / Cataclysm where they differ) |
|---|---|---|
| `convoy_route` | `route_north`, `route_east` | 0.55 / 0.45 |
| `truck_count` | `trucks_2`, `trucks_3` | R 0.7/0.3, T 0.7/0.3, H 0.4/0.6, B 0.4/0.6, L 0.2/0.8, C 0.2/0.8 |
| `cargo_t3` | `t3_cash`, `t3_bullion` | 0.5 / 0.5; `requires {truck_count: [trucks_3]}` |
| `cash_bags` (scalar) | 4, 5, 6 per cash van | R-H 0.3/0.5/0.2; B-C 0.2/0.4/0.4 |
| `gold_bags` (scalar) | 3, 4 per bullion truck | 0.5 / 0.5 |
| `controller` | `ctrl_locked`, `ctrl_open` | 0.7 / 0.3 (`asset.signal_insider` forces `ctrl_open`) |
| `site_stores` | `stores_c4`, `stores_thermite`, `stores_both` | 0.4 / 0.3 / 0.3 |
| `guard_post` (site) | `post_site_gate`, `post_site_frame`, `post_site_cabins` | pick 1, `difficulty_add` [0, 0, 1, 1, 1, 1] (1 Routine/Tense, 2 Hazardous+) |
| `camera` (site) | `cam_mast_cabins`, `cam_magazine`, `cam_gate` | pick 1, `difficulty_add` [0, 0, 0, 1, 1, 1] (2 Brutal+) |
| `cop_on_scene` | `cop_plaza`, `cop_diner`, `cop_none` | 0.4 / 0.3 / 0.3 |
| `marshal_walk` | `marshal_carpark`, `marshal_site_corner`, `marshal_plaza` | 1 / 1 / 1 (revealed by `asset.intel_route`) |
| `goods_lift` | `lift_powered`, `lift_dead` | 0.6 / 0.4 (no force_if; `asset.lift_power`) |
| `player_perch` | `perch_carpark_roof`, `perch_frame`, `perch_none` | 0.3 / 0.3 / 0.4 |
| `escape` | `esc_van_carpark`, `esc_van_underpass`, `esc_heli_roof` | 0.4 / 0.35 / 0.25 |
| `convoy_eta_s` (scalar) | 150, 180, 210 | uniform |
| `police_delay_s` (scalar) | 45, 60, 90 | R 0.1/0.3/0.6, T 0.2/0.4/0.4, H 0.3/0.5/0.2, B 0.5/0.4/0.1, L 0.7/0.3/0, C 1/0/0 |
| `escape_eta_s` (scalar) | 90, 120, 150 | R-H 0.4/0.4/0.2; B-C 0.2/0.4/0.4 |
| `civilians` (scalar) | 6, 9, 12 pedestrians | uniform |

Perches per difficulty (doc's convoy table): S1, S2 Routine/Tense; + S4 Hazardous+; + S3 only on `crane_sniper`.

## 3. Rare events (keys + values)

| id | good/bad | chance | min difficulty | effect (doc) | Briefing "surprise" string (bad only, `ui.briefing.sec.event.rolling_thunder.<id>`) |
|---|---|---|---|---|---|
| `bonds_courier` | good | 0.08 | — | T1 cab safe: 2 `loot.bearer_bonds` | — |
| `informant_tip` | good | 0.06 | — | reveals `convoy_route` + `marshal_walk` | — |
| `gold_rush` | good | 0.04 | — | forces `trucks_3` + `t3_bullion` | — |
| `marshal_early` | bad | 0.08 | — | marshal at ETA - 90 s, two checks | "the route marshal is early and walks two checks" |
| `convoy_early` | bad | 0.06 | — | convoy 45 s early | "the convoy runs 45 seconds early" |
| `crane_sniper` | bad | 0.08 | Brutal | S3 marksman from the first CONTROL | "a police marksman in the crane cab" |
| `armored_escort` | bad | 0.06 | Lethal | a Wrecker rides the rear escort | "a Wrecker rides with the rear escort" |
| `rush_hour` | bad | 0.06 | — | civilians 12, +2 diner customers | "rush hour: more people on the street" |

## 4. Pre-planning (HeistDef.preplanning; costs are Routine prices x PreplanTweak.cost_mult)

```gdscript
preplanning = {
    "favors": 5,
    "disable": [&"asset.intel_keycards", &"asset.intel_laptop"],
    "assets": {
        &"asset.ammo_bag_drop": {"point_ids": ["pp_drop_site", "pp_drop_carpark", "pp_drop_diner_yard", "pp_drop_underpass"]},
        &"asset.doctor_bag_drop": {"point_ids": ["pp_drop_site", "pp_drop_carpark", "pp_drop_diner_yard", "pp_drop_underpass"]},
        &"asset.body_bag_case_drop": {"point_ids": ["pp_drop_site", "pp_drop_diner_yard"]},
        &"asset.thermite_drop": {"point_ids": ["pp_drop_site", "pp_drop_carpark", "pp_drop_underpass"]},
        &"asset.sniper_position": {"point_ids": ["pp_perch_roof", "pp_perch_frame"]},
        &"asset.c4_drop": {"point_ids": ["pp_drop_carpark", "pp_drop_underpass"]},   # B asset, after RT-A3
        &"asset.signal_insider": {"point_ids": ["pp_signals"]},
        &"asset.intel_route": {},
    },
}
```

| Asset | cost | favors | max | category / tags | Status |
|---|---|---|---|---|---|
| `asset.signal_insider` | 1,500 | 1 | 1 | access / stealth; force_variant `controller = ctrl_open` | **exists**; add `heists = [&"rolling_thunder"]` (D-143.5 allow-list) |
| `asset.intel_route` | 1,500 | 1 | 1 | intel; reveals `[convoy_route, marshal_walk]` | **exists**; add `heists = [&"rolling_thunder"]` (D-143.5) |
| `asset.c4_drop` | 2,000 | 2 | 1 | loud; drop `item.c4`, `params {count: 4}` | **new, B**, after A's RT-A3 item drop kind (D-141.3); + HUD `item.c4` count (B) |
| library assets | as their defs | — | — | — | exist; points listed above |

Crew assets with no point that stay on: `intel_guard_posts`, `intel_cameras`, `extra_cable_ties`, `spare_body_bags`,
`lift_power`. Point labels `ui.preplan.point.rolling_thunder.<id>` (13) after G1 (D-141.5).

## 5. Briefing

- Prose (`heist.rolling_thunder.briefing`, exists): re-read once RT-C0's doc fixes land: Reyes, the Vaultline convoy
  through the Southfield junction, rig the signals for a clean stop or crash it, open the trucks (saw / C4 / thermite),
  **4 bags** of cash or gold, out by van (car park / underpass) or the roof helicopter.
- Steps (new strings): `ui.briefing.step.rolling_thunder.setup` "Rig the junction signals, raid the site stores if
  there is time", `ui.briefing.step.rolling_thunder.trucks` "Open the trucks and bag the cargo".
- Known security (BriefingIntel, after G1): guards (site posts), cameras (site), the marshal (1 pager), convoy units
  per difficulty (the doc's convoy table), trucks 2-3, surprises (§3).

## 6. Cast tag rows (A / D own `npc_visual_tweak.tres`; proposed rows)

```
heist_tag_characters[&"rolling_thunder"]:
    &"staff_diner": [&"diner_cook", &"diner_waitress"]     # D's looks (RT-D2)
    &"staff_booth": [&"carpark_attendant"]                  # D's look (RT-D2); or reuse a security_office look
```
`convoy_lead` / `convoy_rear` stay EnemyDef looks by difficulty (D-149.12): no row. Look ids are D's to name; B only
needs the tags to exist so the briefing intel counts staff as civilians.

## 7. Open for the LEAD

1. Approve the D-143.5 allow-list rows for `signal_insider` / `intel_route` now (two lines in existing B files), or
   with the rest after the OF gate.
2. `rt_content_plan.md` §1 said $85k: superseded here ($30k, D-141.1); B updates that file when the gate opens.
