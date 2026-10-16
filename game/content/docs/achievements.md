# Achievements (B4-20 stub, B7-02 expansion)

Owner: ENV B. Data: `content/data/achievements/<name>.tres` (`AchievementDef`, id `achievement.<name>`).
Logic: `content/progression/achievements.gd` (`Achievements`). Screen: `content/ui/achievements/`
(`AchievementsScreen`, grouped by category with progress bars). State: `PlayerProfile.achievements` (save v5).
Strings: `achievement.<name>.name` / `.desc`, `ui.achievements.*`. All names are original.

## Conditions
* Event conditions (counted on the payday, `Achievements.record`): `heist_completed`, `heist_failed` (filters
  `heist`, `difficulty_min`, `stealth`, `loud`, `pro`), `stash_earned`, `level_reached`.
* State conditions (B7-02, `Achievements.sync` after every payday and every Notoriety rank-up; progress is
  the high-water mark of the live value, so career stats earned before an achievement existed count):
  * `career_stat`: a career counter (B7-01 `Career`, `content/docs/save_format.md`): `stat` = a totals key,
    optional `heist` (that heist's counter) or `bag` (a loot id's bags).
  * `notoriety_reached`: the Notoriety rank.
  * `heists_all`: offered heists (`HeistCatalog.ids()`) won at least once, with `difficulty_min` / `stealth` /
    `loud`; `count` 0 = all of them (the target grows when a heist is added; an unlocked achievement stays).
* Counters the HeistResult does not carry yet (D-071 `shots` / `hits` / `headshots`) are never counted, so
  `clean_lines`, `headhunter` and `trigger_discipline` stay locked (progress 0) until ENV A sends them.

## Rewards
On unlock: `unlock` is recorded (`MaskLocker.grant_unlock`), which owns every preset **and every available
mask part** whose `unlock` is that id (`MaskPartDef.unlock`, B7-02); `rewards` parts are granted
(`MaskLocker.grant_part`); `unlocks` ids (extra free-form unlock ids) are recorded as-is.
* **Weapon finishes (B7-04)**: six achievements carry a finish unlock id as their `unlock`, one each (the
  workshop names the granting achievement): `unlock.finish.arctic` (nobody_saw),
  `unlock.finish.cherry_polymer` (ten_alarms), `unlock.finish.carbon` (special_handling),
  `unlock.finish.urban_camo` (dock_work), `unlock.finish.midnight_chrome` (night_shift),
  `unlock.finish.copper_patina` (bag_man). Notoriety grants `case_hardened` (X), `brass_engraved` (XVIII) and
  `gilded_ledger` (XXV); no achievement duplicates them. The screen names a finish by B7-04's
  `item.finish.<id>.name` (the id in title case until that string is on the tree).
* **New presets** on shipped bases: `mask.silent_partner` (owl), `mask.dock_boss` (bruiser),
  `mask.grand_tourist` (vulpine), `mask.thousand_yard` (skull).
* **ENV D batch-3 bases (D3-03)**: 12 base slots in `parts/bases.tres` with `requires_model = true` (hidden until
  the glb lands; nothing fails while it is missing). An earned unlock is kept in `PlayerProfile.unlocks`, and
  `MaskLocker.apply_unlocks` (every load) owns the base once its model exists.

| Base | Unlock | Source |
|---|---|---|
| `mask_base.ram` | `unlock.achievement.riot_season` | achievement |
| `mask_base.stag` | `unlock.achievement.lethal_itinerary` | achievement |
| `mask_base.serpent` | `unlock.achievement.ghost_story` | achievement |
| `mask_base.moth` | `unlock.achievement.old_hand` | achievement |
| `mask_base.knight` | `unlock.achievement.career_criminal` | achievement |
| `mask_base.sunburst` | `unlock.achievement.offshore_ten_million` | achievement |
| `mask_base.robot` | `unlock.achievement.headhunter` | achievement |
| `mask_base.doll` | `unlock.notoriety.rank_7` | Notoriety VII |
| `mask_base.jester` | `unlock.notoriety.rank_15` | Notoriety XV |
| `mask_base.geo` | `unlock.notoriety.rank_20` | Notoriety XX |
| `mask_base.cat` | - | payday card drop |
| `mask_base.boar` | - | payday card drop |

Parts with an `unlock` never drop from payday cards. Reward parts without one (the colours and materials
below) can also drop.

## Table
| Order | Id | Category | Condition | Reward |
|---|---|---|---|---|
| 10 | `achievement.first_score` | career | `{"event": "heist_completed", "count": 1}` | - |
| 20 | `achievement.pro_closer` | career | `{"event": "heist_completed", "pro": true, "count": 1}` | - |
| 30 | `achievement.seasoned` | career | `{"event": "level_reached", "count": 25}` | - |
| 40 | `achievement.steady_work` | career | `{"event": "career_stat", "stat": "won", "count": 10}` | `mask_colors.moss_bark` |
| 50 | `achievement.hard_lessons` | career | `{"event": "heist_failed", "count": 1}` | - |
| 60 | `achievement.clocked_in` | career | `{"event": "career_stat", "stat": "time_played_s", "count": 36000}` | - |
| 70 | `achievement.career_criminal` | career | `{"event": "career_stat", "stat": "won", "count": 100}` | `unlock.achievement.career_criminal` |
| 80 | `achievement.top_of_the_ladder` | career | `{"event": "level_reached", "count": 100}` | `mask_material.chrome` |
| 110 | `achievement.glasshouse_regular` | heists | `{"event": "heist_completed", "heist": "glasshouse", "count": 3}` | - |
| 120 | `achievement.dock_work` | heists | `{"event": "heist_completed", "heist": "dockside_burn", "count": 5}` | `unlock.finish.urban_camo` |
| 130 | `achievement.harbour_master` | heists | `{"event": "heist_completed", "heist": "dockside_burn", "difficulty_min": 4, "count": 1}` | `unlock.achievement.harbour_master` |
| 140 | `achievement.night_shift` | heists | `{"event": "heist_completed", "heist": "night_deposit", "stealth": true, "count": 1}` | `unlock.finish.midnight_chrome` |
| 150 | `achievement.shattered_glass` | heists | `{"event": "heist_completed", "heist": "glasshouse", "loud": true, "difficulty_min": 5, "count": 1}` | `mask_colors.rose_cinder` |
| 160 | `achievement.cataclysm_clear` | heists | `{"event": "heist_completed", "difficulty_min": 5, "count": 1}` | `unlock.achievement.cataclysm_clear` |
| 170 | `achievement.grand_tour` | heists | `{"event": "heists_all", "count": 0}` | `unlock.achievement.grand_tour` |
| 180 | `achievement.lethal_itinerary` | heists | `{"event": "heists_all", "difficulty_min": 4, "count": 0}` | `unlock.achievement.lethal_itinerary` |
| 210 | `achievement.ghost_crew` | stealth | `{"event": "heist_completed", "stealth": true, "count": 5}` | - |
| 220 | `achievement.nobody_saw` | stealth | `{"event": "career_stat", "stat": "stealth_wins", "count": 10}` | `unlock.finish.arctic`, `mask_colors.jade_rust` |
| 230 | `achievement.ghost_story` | stealth | `{"event": "career_stat", "stat": "stealth_wins", "count": 25}` | `unlock.achievement.ghost_story` |
| 240 | `achievement.off_the_books` | stealth | `{"event": "heist_completed", "heist": "shadow_ledger", "stealth": true, "count": 1}` | `unlock.achievement.off_the_books` |
| 250 | `achievement.ledger_closed` | stealth | `{"event": "heist_completed", "heist": "shadow_ledger", "difficulty_min": 4, "count": 1}` | `mask_material.porcelain` |
| 310 | `achievement.make_some_noise` | loud | `{"event": "heist_completed", "loud": true, "difficulty_min": 2, "count": 1}` | - |
| 320 | `achievement.ten_alarms` | loud | `{"event": "career_stat", "stat": "loud_wins", "count": 10}` | `unlock.finish.cherry_polymer`, `mask_colors.cobalt_flare` |
| 330 | `achievement.riot_season` | loud | `{"event": "career_stat", "stat": "loud_wins", "count": 25}` | `unlock.achievement.riot_season` |
| 410 | `achievement.hundred_down` | combat | `{"event": "career_stat", "stat": "kills", "count": 100}` | - |
| 420 | `achievement.thousand_down` | combat | `{"event": "career_stat", "stat": "kills", "count": 1000}` | `unlock.achievement.thousand_down` |
| 430 | `achievement.special_handling` | combat | `{"event": "career_stat", "stat": "specials_killed", "count": 50}` | `unlock.finish.carbon`, `mask_colors.sulfur_ash` |
| 440 | `achievement.big_game` | combat | `{"event": "career_stat", "stat": "specials_killed", "count": 500}` | `mask_material.blued_steel` |
| 450 | `achievement.clean_lines` | combat | `{"event": "career_stat", "stat": "headshots", "count": 250}` | - |
| 460 | `achievement.headhunter` | combat | `{"event": "career_stat", "stat": "headshots", "count": 2500}` | `unlock.achievement.headhunter` |
| 470 | `achievement.trigger_discipline` | combat | `{"event": "career_stat", "stat": "hits", "count": 5000}` | `mask_material.walnut` |
| 480 | `achievement.back_on_your_feet` | combat | `{"event": "career_stat", "stat": "downs", "count": 25}` | - |
| 490 | `achievement.time_served` | combat | `{"event": "career_stat", "stat": "custody", "count": 5}` | - |
| 510 | `achievement.offshore_million` | wealth | `{"event": "stash_earned", "count": 1000000}` | - |
| 520 | `achievement.offshore_ten_million` | wealth | `{"event": "stash_earned", "count": 10000000}` | `unlock.achievement.offshore_ten_million` |
| 530 | `achievement.bag_man` | wealth | `{"event": "career_stat", "stat": "bags", "count": 100}` | `unlock.finish.copper_patina`, `mask_colors.saffron_plum` |
| 540 | `achievement.heavy_lifting` | wealth | `{"event": "career_stat", "stat": "bags", "count": 1000}` | `mask_material.marble` |
| 550 | `achievement.big_spender` | wealth | `{"event": "career_stat", "stat": "cash_spent", "count": 5000000}` | `mask_material.rubber` |
| 560 | `achievement.pocket_change` | wealth | `{"event": "career_stat", "stat": "small_loot", "count": 250000}` | `mask_material.ink_lacquer` |
| 610 | `achievement.clean_slate` | notoriety | `{"event": "notoriety_reached", "count": 1}` | `mask_colors.signal_white` |
| 620 | `achievement.old_hand` | notoriety | `{"event": "notoriety_reached", "count": 5}` | `unlock.achievement.old_hand` |

## Heist achievements (D-115)
Five or six per heist, each in its own category (`category` = the heist id, after `heists`). All are
`heist_completed` with the heist filter plus **run conditions** (`progression/heist_conditions.gd`,
`HeistConditions.passes`, called from `Achievements.matches`). Every run condition fails closed: a result
without the field (no `time_s`, no `crew` rows, no `pagers_answered`) or a payday without a fact log never
unlocks it.
* HeistResult: `max_time_s`, `max_time_variant` (time_s <= a rolled scalar, e.g. `last_call_s`), `max_kills`,
  `max_civilian_kills`, `max_downs` (crew totals, AI included), `max_custody`, `max_pagers`, `min_bags`, `loot_all`,
  `loot_min` (secured bags; tool bags and `PayoutTweak.xp_loot_excluded_ids` (body bags) never count).
* In-heist fact log (`progression/heist_facts.gd`, `HeistFacts`): the in-heist `PaydayScreen` owns one
  (`facts`; MenuFlow calls `start_fact_log()` before the launch) and passes `facts.snapshot()` to
  `Achievements.on_payday(..., facts)`. It keeps every objective's last state + `skipped`, and the `[R]` facts in
  `HeistFacts.SIGNALS` as `[signal, args]`. Keys: `objectives_completed` / `objectives_not_completed` (COMPLETED
  and not `skipped`), `facts_seen` / `facts_not_seen` (`{"signal", "args": {index: value}}`), `all_loot_secured`
  (every counted `loot_spawned` bag was `loot_secured`; a future HeistResult `loot_available` replaces this).
* `AchievementDef.requires_facts`: facts a condition only approximates today (documentation for ENV A).

| Order | Id | Condition (besides `heist`) | Reward |
|---|---|---|---|
| 710 | `gh_velvet_gloves` | stealth, max_kills 0, max_civilian_kills 0 | `mask_pattern.dots` |
| 711 | `gh_before_closing` | max_time_s 360 | `mask_colors.mint_graphite` |
| 712 | `gh_whole_consignment` | objectives_completed [safe_loot], all_loot_secured, min_bags 4 | `mask_pattern.diamonds` |
| 713 | `gh_managers_combination` | objectives_completed [code, safe]; not seen: item_picked_up item.keycard, device_started drill | `mask_base.theatre` |
| 714 | `gh_window_shopping` | stealth; not seen: glass_broken | `mask_pattern.sash` |
| 715 | `gh_cataclysm` | stealth, difficulty_min 5 | `mask_base.demon` |
| 720 | `nd_quiet_deposit` | stealth, max_kills 0, max_civilian_kills 0 | `mask_pattern.stripes` |
| 721 | `nd_bankers_hours` | max_time_s 720 | `mask_colors.violet_static` |
| 722 | `nd_cleaned_out` | objectives_completed [vault_loot, depository], all_loot_secured, min_bags 9 | `mask_pattern.chevron` |
| 723 | `nd_clockwork` | objectives_completed [server, time_lock_wait] (time lock started by the hack) | `mask_pattern.circuit` |
| 724 | `nd_cataclysm` | difficulty_min 5 | `mask_base.owl` |
| 730 | `sl_silent_audit` | stealth, max_kills 0, max_civilian_kills 0 | `mask_pattern.scales` |
| 731 | `sl_express_elevator` | max_time_s 600 | `mask_colors.oxblood_brass` |
| 732 | `sl_every_page` | objectives_completed [study_safe, paintings, archive_safe], loot_all [laptop, books, cash], loot_min {drives 3, painting 2}, all_loot_secured | `mask_pattern.starburst` |
| 733 | `sl_measure_twice` | objectives_completed [cage_code, cage]; not seen: device_started saw | `mask_base.gasmask` |
| 734 | `sl_dead_air` | stealth, max_pagers 0 | `mask_pattern.prowl` |
| 735 | `sl_cataclysm` | difficulty_min 5 | `mask_base.skull` |
| 740 | `db_not_a_scratch` | max_downs 0, max_civilian_kills 0 (loud-only heist: no stealth clear) | `mask_pattern.crackle` |
| 741 | `db_before_sunrise` | max_time_s 840 | `mask_base.goalie` |
| 742 | `db_strip_the_pier` | loot_min {cash_bricks 4, weapon_crate 4, contraband 4}, min_bags 12, all_loot_secured | `mask_base.bruiser` |
| 743 | `db_buyers_discount` | objectives_completed [burn], loot_min {contraband 4} | - |
| 744 | `db_cataclysm` | difficulty_min 5 | `mask_base.shark` |
| 750 | `gn_gala_manners` | stealth, max_kills 0, max_civilian_kills 0 | - |
| 751 | `gn_quick_viewing` | max_time_s 540 | - |
| 752 | `gn_full_collection` | loot_all [the four listed canvases], loot_min {painting_study 1}, all_loot_secured | `mask_base.cat` |
| 753 | `gn_pulled_the_plug` | loud, objectives_completed [hack], objectives_not_completed [vault_drill] | `mask_base.boar` |
| 754 | `gn_last_call` | stealth, max_time_variant last_call_s | - |
| 755 | `gn_cataclysm` | difficulty_min 5 | `mask_base.welder` |

Rewards are mask parts with no other unlock (payday-card parts, like the colour/material rewards above), each
used by one heist achievement. `requires_facts`: the loot-everything set (`gh_whole_consignment`,
`nd_cleaned_out`, `sl_every_page`, `db_strip_the_pier`, `gn_full_collection`) wants
`heist_result.loot_available`; `gh_managers_combination` / `sl_measure_twice` want the safe / cage open method.
