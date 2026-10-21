# VO coverage (D-117 §6)

**Generated. Do not edit.** Regenerate with
`godot --headless --path game -s res://content/voice/tools/vo_coverage_cli.gd` (ENV B tool,
`content/voice/tools/vo_coverage.gd`; the test is `tests/b/test_vo_coverage.gd`).

A line is said when a trigger site can emit its id: a literal id in game code or data, a format builder
(`%s` = one identifier), or one of B's builders (ContactRadio from each heist's HeistDef and mission
objective calls; BriefingModel.voice_lines). Owner = whose code must say it (B: briefing / radio;
C: heist mission lines; A: barks, acks and system lines; B reserve: generic radio lines no current heist
reaches, kept for RadioTweak.speaker_overrides and new heists). Heists iterated: dev_sandbox, dockside_burn, gallery_night, glasshouse, night_deposit, ostrander_federal, shadow_ledger.

## Summary

| Group | Lines | Said | Unsaid | Unsaid A | Unsaid B | Unsaid B reserve | Unsaid C |
|---|---|---|---|---|---|---|---|
| glasshouse | 27 | 27 | 0 | 0 | 0 | 0 | 0 |
| night_deposit | 37 | 37 | 0 | 0 | 0 | 0 | 0 |
| shadow_ledger | 40 | 40 | 0 | 0 | 0 | 0 | 0 |
| dockside_burn | 47 | 47 | 0 | 0 | 0 | 0 | 0 |
| gallery_night | 65 | 65 | 0 | 0 | 0 | 0 | 0 |
| shared | 406 | 356 | 50 | 0 | 0 | 16 | 0 |

Missing (code can say it, the table has no such line): 0.

## Unsaid, owner A (0)

None.

## Unsaid, owner B (0)

None.

## Unsaid, owner B reserve (16)

| Line | Event | Why |
|---|---|---|
| `vo.mercer.abort` | stealth_abort | every STEALTH_ONLY heist says its own abort line (HeistMission.own_abort_line): shadow_ledger: vo.mercer.shadow_ledger_abort |
| `vo.vance.radio_objective_done_1` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_done_2` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_done_3` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_1` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_2` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_3` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.reyes.radio_objective_done_1` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_2` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_3` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_1` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_2` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_3` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.mercer.radio_objective_failed_1` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |
| `vo.mercer.radio_objective_failed_2` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |
| `vo.mercer.radio_objective_failed_3` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |

## Unsaid, owner C (0)

None.

## Unsaid, owner staged heist (34)

| Line | Event | Why |
|---|---|---|
| `vo.mercer.rolling_thunder_intro` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_eta_60` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_eta_30` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_marshal` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_signals_done` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_signals_remind` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_c4_found` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_thermite_found` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sighted` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_stopped` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_go` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_alerted` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_escort_down` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_police` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_saw_on` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_saw_jam` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_deadbolts` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_truck_open` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_c4_armed` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_thermite_burn` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_gold` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_bonds` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_lift_dead` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sniper_skyway` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sniper_rail` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sniper_crane` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_secured` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_van_eta` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_heli_eta` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_escape` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_crash` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_ready` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_boxed` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_payday` | mission | nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |

## glasshouse

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.vance.briefing_glasshouse_1` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.vance.briefing_glasshouse_2` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.vance.briefing_glasshouse_3` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.mercer.briefing_glasshouse_1` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.mercer.glasshouse_intro` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:49 |
| `vo.mercer.glasshouse_keycard_found` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:143 |
| `vo.mercer.glasshouse_workshop_open` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:127 |
| `vo.mercer.glasshouse_drill_jam` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:161 |
| `vo.mercer.glasshouse_last_pager` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:105 |
| `vo.mercer.glasshouse_lockdown` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:205 |
| `vo.mercer.glasshouse_van_eta` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:222 |
| `vo.mercer.glasshouse_escape` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:244 |
| `vo.mercer.glasshouse_code_found` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:150 |
| `vo.vance.glasshouse_radio_casing` | radio.objective_done | B | ContactRadio radio.objective_done [casing] via glasshouse |
| `vo.vance.glasshouse_radio_keycard` | radio.objective_done | B | ContactRadio radio.objective_done [keycard] via glasshouse |
| `vo.vance.glasshouse_radio_code` | radio.objective_done | B | ContactRadio radio.objective_done [code] via glasshouse |
| `vo.vance.glasshouse_radio_extra_bags` | radio.objective_done | B | ContactRadio radio.objective_done [extra_bags] via glasshouse |
| `vo.vance.glasshouse_radio_salon` | radio.objective_done | B | ContactRadio radio.objective_done [salon] via glasshouse |
| `vo.vance.glasshouse_radio_display_cases` | radio.objective_done | B | ContactRadio radio.objective_done [display_cases] via glasshouse |
| `vo.vance.glasshouse_radio_workshop_door` | radio.objective_done | B | ContactRadio radio.objective_done [workshop_door] via glasshouse |
| `vo.vance.glasshouse_radio_safe` | radio.objective_done | B | ContactRadio radio.objective_done [safe] via glasshouse |
| `vo.vance.glasshouse_radio_safe_loot_new` | radio.objective_new | B | ContactRadio radio.objective_new [safe_loot] via glasshouse |
| `vo.vance.glasshouse_radio_safe_loot` | radio.objective_done | B | ContactRadio radio.objective_done [safe_loot] via glasshouse |
| `vo.vance.glasshouse_radio_secure` | radio.objective_done | B | ContactRadio radio.objective_done [secure] via glasshouse |
| `vo.vance.glasshouse_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via glasshouse |
| `vo.vance.glasshouse_radio_loot_jewelry` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.jewelry) via glasshouse |
| `vo.vance.glasshouse_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.jewelry) via glasshouse |

## night_deposit

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.accountant.briefing_night_deposit_1` | briefing | B | BriefingModel.voice_lines via night_deposit (contact.accountant) |
| `vo.accountant.briefing_night_deposit_2` | briefing | B | BriefingModel.voice_lines via night_deposit (contact.accountant) |
| `vo.accountant.briefing_night_deposit_3` | briefing | B | BriefingModel.voice_lines via night_deposit (contact.accountant) |
| `vo.mercer.briefing_night_deposit_1` | briefing | B | BriefingModel.voice_lines via night_deposit (contact.accountant) |
| `vo.mercer.night_deposit_intro` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:64 |
| `vo.accountant.night_deposit_contact_intro` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:65 |
| `vo.mercer.night_deposit_keycard_found` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:205 |
| `vo.mercer.night_deposit_code_found` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:241 |
| `vo.mercer.night_deposit_lasers` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:193 |
| `vo.mercer.night_deposit_time_lock_started` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:260 |
| `vo.mercer.night_deposit_time_lock_30` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:265 |
| `vo.mercer.night_deposit_time_lock_open` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:273 |
| `vo.mercer.night_deposit_drill_jam` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:319 |
| `vo.mercer.night_deposit_last_pager` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:119 |
| `vo.mercer.night_deposit_lockdown` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:333 |
| `vo.mercer.night_deposit_armored_car` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:171 |
| `vo.mercer.night_deposit_fog_lifts` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:157 |
| `vo.mercer.night_deposit_escape_eta` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:354 |
| `vo.mercer.night_deposit_escape` | mission | C | world/heists/night_deposit/night_deposit_mission.gd:376 |
| `vo.accountant.night_deposit_radio_casing` | radio.objective_done | B | ContactRadio radio.objective_done [casing] via night_deposit |
| `vo.accountant.night_deposit_radio_keycard` | radio.objective_done | B | ContactRadio radio.objective_done [keycard] via night_deposit |
| `vo.accountant.night_deposit_radio_code` | radio.objective_done | B | ContactRadio radio.objective_done [code] via night_deposit |
| `vo.accountant.night_deposit_radio_server` | radio.objective_done | B | ContactRadio radio.objective_done [server] via night_deposit |
| `vo.accountant.night_deposit_radio_vault_gate` | radio.objective_done | B | ContactRadio radio.objective_done [vault_gate] via night_deposit |
| `vo.accountant.night_deposit_radio_time_lock_new` | radio.objective_new | B | ContactRadio radio.objective_new [time_lock] via night_deposit |
| `vo.accountant.night_deposit_radio_time_lock` | radio.objective_done | B | ContactRadio radio.objective_done [time_lock] via night_deposit |
| `vo.accountant.night_deposit_radio_time_lock_wait_new` | radio.objective_new | B | ContactRadio radio.objective_new [time_lock_wait] via night_deposit |
| `vo.accountant.night_deposit_radio_time_lock_wait` | radio.objective_done | B | ContactRadio radio.objective_done [time_lock_wait] via night_deposit |
| `vo.accountant.night_deposit_radio_vault_drill_new` | radio.objective_new | B | ContactRadio radio.objective_new [vault_drill] via night_deposit |
| `vo.accountant.night_deposit_radio_vault_drill` | radio.objective_done | B | ContactRadio radio.objective_done [vault_drill] via night_deposit |
| `vo.accountant.night_deposit_radio_vault_loot_new` | radio.objective_new | B | ContactRadio radio.objective_new [vault_loot] via night_deposit |
| `vo.accountant.night_deposit_radio_vault_loot` | radio.objective_done | B | ContactRadio radio.objective_done [vault_loot] via night_deposit |
| `vo.accountant.night_deposit_radio_depository` | radio.objective_done | B | ContactRadio radio.objective_done [depository] via night_deposit |
| `vo.accountant.night_deposit_radio_secure` | radio.objective_done | B | ContactRadio radio.objective_done [secure] via night_deposit |
| `vo.accountant.night_deposit_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via night_deposit |
| `vo.accountant.night_deposit_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit |
| `vo.accountant.night_deposit_radio_loot_cash_bricks` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit |

## shadow_ledger

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.accountant.briefing_shadow_ledger_1` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.accountant.briefing_shadow_ledger_2` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.accountant.briefing_shadow_ledger_3` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.mercer.briefing_shadow_ledger_1` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.mercer.shadow_ledger_intro` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:80 |
| `vo.accountant.shadow_ledger_contact_intro` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:81 |
| `vo.mercer.shadow_ledger_laptop_found` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:184 |
| `vo.mercer.shadow_ledger_keycard_found` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:197 |
| `vo.mercer.shadow_ledger_code_found` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:200 |
| `vo.mercer.shadow_ledger_camera_warning` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:55 |
| `vo.mercer.shadow_ledger_cage_open` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:314 |
| `vo.mercer.shadow_ledger_hack_started` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:205 |
| `vo.mercer.shadow_ledger_hack_interrupted` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:225 |
| `vo.mercer.shadow_ledger_hack_done` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:325 |
| `vo.mercer.shadow_ledger_lasers` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:38 |
| `vo.mercer.shadow_ledger_time_lock_started` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:207 |
| `vo.mercer.shadow_ledger_time_lock_open` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:218 |
| `vo.mercer.shadow_ledger_last_pager` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:135 |
| `vo.mercer.shadow_ledger_required_secured` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:360 |
| `vo.mercer.shadow_ledger_escape` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:363 |
| `vo.mercer.shadow_ledger_abort` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:130 |
| `vo.accountant.shadow_ledger_radio_casing` | radio.objective_done | B | ContactRadio radio.objective_done [casing] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_laptop` | radio.objective_done | B | ContactRadio radio.objective_done [laptop] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_keycard` | radio.objective_done | B | ContactRadio radio.objective_done [keycard] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_server_door` | radio.objective_done | B | ContactRadio radio.objective_done [server_door] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_cage_code` | radio.objective_done | B | ContactRadio radio.objective_done [cage_code] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_cage` | radio.objective_done | B | ContactRadio radio.objective_done [cage] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_hack_new` | radio.objective_new | B | ContactRadio radio.objective_new [hack] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_hack` | radio.objective_done | B | ContactRadio radio.objective_done [hack] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_drives_new` | radio.objective_new | B | ContactRadio radio.objective_new [drives] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_drives` | radio.objective_done | B | ContactRadio radio.objective_done [drives] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_secure` | radio.objective_done | B | ContactRadio radio.objective_done [secure] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_study_safe` | radio.objective_done | B | ContactRadio radio.objective_done [study_safe] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_paintings` | radio.objective_done | B | ContactRadio radio.objective_done [paintings] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_archive_safe` | radio.objective_done | B | ContactRadio radio.objective_done [archive_safe] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_escape` | radio.escape | B | ContactRadio radio.escape via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.small_valuables) via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_loot_laptop` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_loot_drives` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger |

## dockside_burn

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.reyes.briefing_dockside_burn_1` | briefing | B | BriefingModel.voice_lines via dockside_burn (contact.reyes) |
| `vo.reyes.briefing_dockside_burn_2` | briefing | B | BriefingModel.voice_lines via dockside_burn (contact.reyes) |
| `vo.reyes.briefing_dockside_burn_3` | briefing | B | BriefingModel.voice_lines via dockside_burn (contact.reyes) |
| `vo.mercer.briefing_dockside_burn_1` | briefing | B | BriefingModel.voice_lines via dockside_burn (contact.reyes) |
| `vo.mercer.briefing_dockside_burn_2` | briefing | B | BriefingModel.voice_lines via dockside_burn (contact.reyes) |
| `vo.mercer.dockside_burn_intro` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:108 |
| `vo.reyes.dockside_burn_contact_intro` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:109 |
| `vo.mercer.dockside_burn_cartel_awake` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:366 |
| `vo.mercer.dockside_burn_police_called` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:330 |
| `vo.mercer.dockside_burn_breach` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:554 |
| `vo.mercer.dockside_burn_product_found` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:563 |
| `vo.mercer.dockside_burn_thermite_reminder` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:564 |
| `vo.mercer.dockside_burn_burn_started` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:409 |
| `vo.mercer.dockside_burn_burn_done` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:623 |
| `vo.mercer.dockside_burn_strongroom_drill` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:414 |
| `vo.mercer.dockside_burn_drill_jam` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:440 |
| `vo.mercer.dockside_burn_strongroom_open` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:427 |
| `vo.mercer.dockside_burn_count_cage` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:417 |
| `vo.mercer.dockside_burn_lift_dead` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:719 |
| `vo.mercer.dockside_burn_containers_hint` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:230<br>world/heists/dockside_burn/dockside_burn_mission.gd:606 |
| `vo.mercer.dockside_burn_weapons_found` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:612 |
| `vo.mercer.dockside_burn_sniper_crane` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:78 |
| `vo.mercer.dockside_burn_sniper_roof` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:78 |
| `vo.mercer.dockside_burn_gangway` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:332 |
| `vo.mercer.dockside_burn_reinforcements` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:346 |
| `vo.mercer.dockside_burn_fog_lifts` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:352 |
| `vo.mercer.dockside_burn_required_secured` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:545 |
| `vo.mercer.dockside_burn_van_eta` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:668 |
| `vo.mercer.dockside_burn_boat_eta` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:668 |
| `vo.mercer.dockside_burn_escape` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:674 |
| `vo.reyes.dockside_burn_payday` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:72 |
| `vo.reyes.dockside_burn_radio_cartel` | radio.objective_done | B | ContactRadio radio.objective_done [cartel] via dockside_burn |
| `vo.reyes.dockside_burn_radio_breach` | radio.objective_done | B | ContactRadio radio.objective_done [breach] via dockside_burn |
| `vo.reyes.dockside_burn_radio_product` | radio.objective_done | B | ContactRadio radio.objective_done [product] via dockside_burn |
| `vo.reyes.dockside_burn_radio_burn_new` | radio.objective_new | B | ContactRadio radio.objective_new [burn] via dockside_burn |
| `vo.reyes.dockside_burn_radio_burn` | radio.objective_done | B | ContactRadio radio.objective_done [burn] via dockside_burn |
| `vo.reyes.dockside_burn_radio_strongroom` | radio.objective_done | B | ContactRadio radio.objective_done [strongroom] via dockside_burn |
| `vo.reyes.dockside_burn_radio_count_cage` | radio.objective_done | B | ContactRadio radio.objective_done [count_cage] via dockside_burn |
| `vo.reyes.dockside_burn_radio_containers` | radio.objective_done | B | ContactRadio radio.objective_done [containers] via dockside_burn |
| `vo.reyes.dockside_burn_radio_secure` | radio.objective_done | B | ContactRadio radio.objective_done [secure] via dockside_burn |
| `vo.reyes.dockside_burn_radio_escape_wait_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape_wait] via dockside_burn |
| `vo.reyes.dockside_burn_radio_escape_wait` | radio.objective_done | B | ContactRadio radio.objective_done [escape_wait] via dockside_burn |
| `vo.reyes.dockside_burn_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via dockside_burn |
| `vo.reyes.dockside_burn_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn<br>ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn<br>ContactRadio radio.loot_secured (loot.contraband) via dockside_burn |
| `vo.reyes.dockside_burn_radio_loot_weapons` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn |
| `vo.reyes.dockside_burn_radio_loot_cash` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn |
| `vo.reyes.dockside_burn_radio_loot_product` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.contraband) via dockside_burn |

## gallery_night

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.vance.briefing_gallery_night_1` | briefing | B | BriefingModel.voice_lines via gallery_night (contact.vance) |
| `vo.vance.briefing_gallery_night_2` | briefing | B | BriefingModel.voice_lines via gallery_night (contact.vance) |
| `vo.vance.briefing_gallery_night_3` | briefing | B | BriefingModel.voice_lines via gallery_night (contact.vance) |
| `vo.mercer.briefing_gallery_night_1` | briefing | B | BriefingModel.voice_lines via gallery_night (contact.vance) |
| `vo.mercer.briefing_gallery_night_2` | briefing | B | BriefingModel.voice_lines via gallery_night (contact.vance) |
| `vo.vance.gallery_night_contact_intro` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:195 |
| `vo.vance.gallery_night_centrepiece` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:104 |
| `vo.vance.gallery_night_payday` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:105 |
| `vo.mercer.gallery_night_intro` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:194 |
| `vo.mercer.gallery_night_canvas_found_saint` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:325 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_canvas_found_widow` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:325 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_canvas_found_orchard` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:325 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_canvas_found_lantern` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:325 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_last_call_soon` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:417 |
| `vo.mercer.gallery_night_last_call` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:425 |
| `vo.mercer.gallery_night_lasers_sweep` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:89 |
| `vo.mercer.gallery_night_guests_gone` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:453 |
| `vo.mercer.gallery_night_keycard` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:91 |
| `vo.mercer.gallery_night_code_found` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:728 |
| `vo.mercer.gallery_night_sensors_warning` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:95 |
| `vo.mercer.gallery_night_hack_started` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:93 |
| `vo.mercer.gallery_night_hack_interrupted` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:94 |
| `vo.mercer.gallery_night_sensors_off` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:761 |
| `vo.mercer.gallery_night_lasers` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:96 |
| `vo.mercer.gallery_night_treasury_open` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:97 |
| `vo.mercer.gallery_night_art_store_open` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:98 |
| `vo.mercer.gallery_night_curator_keycard` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:92 |
| `vo.mercer.gallery_night_inspectors` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:108 |
| `vo.mercer.gallery_night_vaultline` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:109 |
| `vo.mercer.gallery_night_last_pager` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:99 |
| `vo.mercer.gallery_night_lockdown` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:875 |
| `vo.mercer.gallery_night_shutters_up` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:100 |
| `vo.mercer.gallery_night_vault_drill` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:101 |
| `vo.mercer.gallery_night_drill_jam` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:102 |
| `vo.mercer.gallery_night_required_secured` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:828 |
| `vo.mercer.gallery_night_van_eta` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:845 (builder `vo.mercer.gallery_night_%s_eta`) |
| `vo.mercer.gallery_night_limo_eta` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:845 (builder `vo.mercer.gallery_night_%s_eta`) |
| `vo.mercer.gallery_night_sniper_hotel` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:103 |
| `vo.mercer.gallery_night_escape` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:856 |
| `vo.vance.gallery_night_radio_casing` | radio.objective_done | B | ContactRadio radio.objective_done [casing] via gallery_night |
| `vo.vance.gallery_night_radio_find_canvases` | radio.objective_done | B | ContactRadio radio.objective_done [find_canvases] via gallery_night |
| `vo.vance.gallery_night_radio_keycard` | radio.objective_done | B | ContactRadio radio.objective_done [keycard] via gallery_night |
| `vo.vance.gallery_night_radio_server_code` | radio.objective_done | B | ContactRadio radio.objective_done [server_code] via gallery_night |
| `vo.vance.gallery_night_radio_hack` | radio.objective_done | B | ContactRadio radio.objective_done [hack] via gallery_night |
| `vo.vance.gallery_night_radio_treasury` | radio.objective_done | B | ContactRadio radio.objective_done [treasury] via gallery_night |
| `vo.vance.gallery_night_radio_art_store` | radio.objective_done | B | ContactRadio radio.objective_done [art_store] via gallery_night |
| `vo.vance.gallery_night_radio_centrepiece` | radio.objective_done | B | ContactRadio radio.objective_done [centrepiece] via gallery_night |
| `vo.vance.gallery_night_radio_canvases` | radio.objective_done | B | ContactRadio radio.objective_done [canvases] via gallery_night |
| `vo.vance.gallery_night_radio_secure` | radio.objective_done | B | ContactRadio radio.objective_done [secure] via gallery_night |
| `vo.vance.gallery_night_radio_extras` | radio.objective_done | B | ContactRadio radio.objective_done [extras] via gallery_night |
| `vo.vance.gallery_night_radio_lockers` | radio.objective_done | B | ContactRadio radio.objective_done [lockers] via gallery_night |
| `vo.vance.gallery_night_radio_curator_safe` | radio.objective_done | B | ContactRadio radio.objective_done [curator_safe] via gallery_night |
| `vo.vance.gallery_night_radio_lockdown` | radio.objective_done | B | ContactRadio radio.objective_done [lockdown] via gallery_night |
| `vo.vance.gallery_night_radio_server_door` | radio.objective_done | B | ContactRadio radio.objective_done [server_door] via gallery_night |
| `vo.vance.gallery_night_radio_vault_drill_new` | radio.objective_new | B | ContactRadio radio.objective_new [vault_drill] via gallery_night |
| `vo.vance.gallery_night_radio_vault_drill` | radio.objective_done | B | ContactRadio radio.objective_done [vault_drill] via gallery_night |
| `vo.vance.gallery_night_radio_escape_wait_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape_wait] via gallery_night |
| `vo.vance.gallery_night_radio_escape_wait` | radio.objective_done | B | ContactRadio radio.objective_done [escape_wait] via gallery_night |
| `vo.vance.gallery_night_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via gallery_night |
| `vo.vance.gallery_night_radio_loot_lantern_bearer` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night |
| `vo.vance.gallery_night_radio_loot_study` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_study) via gallery_night |
| `vo.vance.gallery_night_radio_loot_salt_orchard` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night |
| `vo.vance.gallery_night_radio_loot_widow_in_blue` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night |
| `vo.vance.gallery_night_radio_loot_tidewater_saint` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night |
| `vo.vance.gallery_night_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night |

## shared

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.mercer.heist_start_casing_1` | heist_start_casing | A | systems/vo/bark_tweak.tres:8 (builder `vo.mercer.heist_start_casing_%d`) |
| `vo.mercer.heist_start_casing_2` | heist_start_casing | A | systems/vo/bark_tweak.tres:8 (builder `vo.mercer.heist_start_casing_%d`) |
| `vo.mercer.crew_masked_1` | crew_masked | A | systems/vo/bark_tweak.tres:9 (builder `vo.mercer.crew_masked_%d`) |
| `vo.mercer.crew_masked_2` | crew_masked | A | systems/vo/bark_tweak.tres:9 (builder `vo.mercer.crew_masked_%d`) |
| `vo.mercer.pager_started_1` | pager_started | A | systems/vo/bark_tweak.tres:10 (builder `vo.mercer.pager_started_%d`) |
| `vo.mercer.pager_started_2` | pager_started | A | systems/vo/bark_tweak.tres:10 (builder `vo.mercer.pager_started_%d`) |
| `vo.mercer.pager_answered_1` | pager_answered | A | systems/vo/bark_tweak.tres:11 (builder `vo.mercer.pager_answered_%d`) |
| `vo.mercer.pager_answered_2` | pager_answered | A | systems/vo/bark_tweak.tres:11 (builder `vo.mercer.pager_answered_%d`) |
| `vo.mercer.pager_last_answer_1` | pager_last_answer | A | systems/vo/bark_tweak.tres:12 (builder `vo.mercer.pager_last_answer_%d`) |
| `vo.mercer.pager_last_answer_2` | pager_last_answer | A | systems/vo/bark_tweak.tres:12 (builder `vo.mercer.pager_last_answer_%d`) |
| `vo.mercer.pager_limit_1` | pager_limit | A | systems/vo/bark_tweak.tres:13 (builder `vo.mercer.pager_limit_%d`) |
| `vo.mercer.pager_limit_2` | pager_limit | A | systems/vo/bark_tweak.tres:13 (builder `vo.mercer.pager_limit_%d`) |
| `vo.mercer.pager_failed_1` | pager_failed | A | systems/vo/bark_tweak.tres:14 (builder `vo.mercer.pager_failed_%d`) |
| `vo.mercer.pager_failed_2` | pager_failed | A | systems/vo/bark_tweak.tres:14 (builder `vo.mercer.pager_failed_%d`) |
| `vo.mercer.body_discovered_1` | body_discovered | A | systems/vo/bark_tweak.tres:15 (builder `vo.mercer.body_discovered_%d`) |
| `vo.mercer.body_discovered_2` | body_discovered | A | systems/vo/bark_tweak.tres:15 (builder `vo.mercer.body_discovered_%d`) |
| `vo.mercer.camera_spotted_1` | camera_spotted | A | systems/vo/bark_tweak.tres:16 (builder `vo.mercer.camera_spotted_%d`) |
| `vo.mercer.camera_spotted_2` | camera_spotted | A | systems/vo/bark_tweak.tres:16 (builder `vo.mercer.camera_spotted_%d`) |
| `vo.mercer.device_started_1` | device_started | A | systems/vo/bark_tweak.tres:17 (builder `vo.mercer.device_started_%d`) |
| `vo.mercer.device_started_2` | device_started | A | systems/vo/bark_tweak.tres:17 (builder `vo.mercer.device_started_%d`) |
| `vo.mercer.device_jammed_1` | device_jammed | A | systems/vo/bark_tweak.tres:18 (builder `vo.mercer.device_jammed_%d`) |
| `vo.mercer.device_jammed_2` | device_jammed | A | systems/vo/bark_tweak.tres:18 (builder `vo.mercer.device_jammed_%d`) |
| `vo.mercer.device_finished_1` | device_finished | A | systems/vo/bark_tweak.tres:19 (builder `vo.mercer.device_finished_%d`) |
| `vo.mercer.device_finished_2` | device_finished | A | systems/vo/bark_tweak.tres:19 (builder `vo.mercer.device_finished_%d`) |
| `vo.mercer.crew_downed_1` | crew_downed | A | systems/vo/bark_tweak.tres:20 (builder `vo.mercer.crew_downed_%d`) |
| `vo.mercer.crew_downed_2` | crew_downed | A | systems/vo/bark_tweak.tres:20 (builder `vo.mercer.crew_downed_%d`) |
| `vo.mercer.crew_custody_1` | crew_custody | A | systems/vo/bark_tweak.tres:21 (builder `vo.mercer.crew_custody_%d`) |
| `vo.mercer.crew_custody_2` | crew_custody | A | systems/vo/bark_tweak.tres:21 (builder `vo.mercer.crew_custody_%d`) |
| `vo.mercer.heist_success_1` | heist_success | A | systems/vo/bark_tweak.tres:22 (builder `vo.mercer.heist_success_%d`) |
| `vo.mercer.heist_success_2` | heist_success | A | systems/vo/bark_tweak.tres:22 (builder `vo.mercer.heist_success_%d`) |
| `vo.mercer.heist_failed_1` | heist_failed | A | systems/vo/bark_tweak.tres:23 (builder `vo.mercer.heist_failed_%d`) |
| `vo.mercer.heist_failed_2` | heist_failed | A | systems/vo/bark_tweak.tres:23 (builder `vo.mercer.heist_failed_%d`) |
| `vo.mercer.stealth_success_1` | stealth_success | A | systems/vo/bark_tweak.tres:24 (builder `vo.mercer.stealth_success_%d`) |
| `vo.mercer.stealth_success_2` | stealth_success | A | systems/vo/bark_tweak.tres:24 (builder `vo.mercer.stealth_success_%d`) |
| `vo.rook.pager_started_1` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.rook.pager_started_%d`) |
| `vo.rook.pager_started_2` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.rook.pager_started_%d`) |
| `vo.rook.reloading_1` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.rook.reloading_%d`) |
| `vo.rook.reloading_2` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.rook.reloading_%d`) |
| `vo.rook.device_jammed_1` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.rook.device_jammed_%d`) |
| `vo.rook.device_jammed_2` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.rook.device_jammed_%d`) |
| `vo.rook.bagging_body_1` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.rook.bagging_body_%d`) |
| `vo.rook.bagging_body_2` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.rook.bagging_body_%d`) |
| `vo.rook.going_loud_1` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.rook.going_loud_%d`) |
| `vo.rook.going_loud_2` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.rook.going_loud_%d`) |
| `vo.rook.crew_downed_1` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.rook.crew_downed_%d`) |
| `vo.rook.crew_downed_2` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.rook.crew_downed_%d`) |
| `vo.rook.reviving_1` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.rook.reviving_%d`) |
| `vo.rook.reviving_2` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.rook.reviving_%d`) |
| `vo.rook.cops_incoming_1` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.rook.cops_incoming_%d`) |
| `vo.rook.cops_incoming_2` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.rook.cops_incoming_%d`) |
| `vo.rook.loot_secured_1` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.rook.loot_secured_%d`) |
| `vo.rook.loot_secured_2` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.rook.loot_secured_%d`) |
| `vo.rook.guard_down_1` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.rook.guard_down_%d`) |
| `vo.rook.guard_down_2` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.rook.guard_down_%d`) |
| `vo.rook.civilian_killed_1` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.rook.civilian_killed_%d`) |
| `vo.rook.civilian_killed_2` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.rook.civilian_killed_%d`) |
| `vo.sable.pager_started_1` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.sable.pager_started_%d`) |
| `vo.sable.pager_started_2` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.sable.pager_started_%d`) |
| `vo.sable.reloading_1` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.sable.reloading_%d`) |
| `vo.sable.reloading_2` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.sable.reloading_%d`) |
| `vo.sable.device_jammed_1` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.sable.device_jammed_%d`) |
| `vo.sable.device_jammed_2` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.sable.device_jammed_%d`) |
| `vo.sable.bagging_body_1` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.sable.bagging_body_%d`) |
| `vo.sable.bagging_body_2` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.sable.bagging_body_%d`) |
| `vo.sable.going_loud_1` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.sable.going_loud_%d`) |
| `vo.sable.going_loud_2` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.sable.going_loud_%d`) |
| `vo.sable.crew_downed_1` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.sable.crew_downed_%d`) |
| `vo.sable.crew_downed_2` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.sable.crew_downed_%d`) |
| `vo.sable.reviving_1` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.sable.reviving_%d`) |
| `vo.sable.reviving_2` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.sable.reviving_%d`) |
| `vo.sable.cops_incoming_1` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.sable.cops_incoming_%d`) |
| `vo.sable.cops_incoming_2` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.sable.cops_incoming_%d`) |
| `vo.sable.loot_secured_1` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.sable.loot_secured_%d`) |
| `vo.sable.loot_secured_2` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.sable.loot_secured_%d`) |
| `vo.sable.guard_down_1` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.sable.guard_down_%d`) |
| `vo.sable.guard_down_2` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.sable.guard_down_%d`) |
| `vo.sable.civilian_killed_1` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.sable.civilian_killed_%d`) |
| `vo.sable.civilian_killed_2` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.sable.civilian_killed_%d`) |
| `vo.dutch.pager_started_1` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.dutch.pager_started_%d`) |
| `vo.dutch.pager_started_2` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.dutch.pager_started_%d`) |
| `vo.dutch.reloading_1` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.dutch.reloading_%d`) |
| `vo.dutch.reloading_2` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.dutch.reloading_%d`) |
| `vo.dutch.device_jammed_1` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.dutch.device_jammed_%d`) |
| `vo.dutch.device_jammed_2` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.dutch.device_jammed_%d`) |
| `vo.dutch.bagging_body_1` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.dutch.bagging_body_%d`) |
| `vo.dutch.bagging_body_2` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.dutch.bagging_body_%d`) |
| `vo.dutch.going_loud_1` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.dutch.going_loud_%d`) |
| `vo.dutch.going_loud_2` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.dutch.going_loud_%d`) |
| `vo.dutch.crew_downed_1` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.dutch.crew_downed_%d`) |
| `vo.dutch.crew_downed_2` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.dutch.crew_downed_%d`) |
| `vo.dutch.reviving_1` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.dutch.reviving_%d`) |
| `vo.dutch.reviving_2` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.dutch.reviving_%d`) |
| `vo.dutch.cops_incoming_1` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.dutch.cops_incoming_%d`) |
| `vo.dutch.cops_incoming_2` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.dutch.cops_incoming_%d`) |
| `vo.dutch.loot_secured_1` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.dutch.loot_secured_%d`) |
| `vo.dutch.loot_secured_2` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.dutch.loot_secured_%d`) |
| `vo.dutch.guard_down_1` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.dutch.guard_down_%d`) |
| `vo.dutch.guard_down_2` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.dutch.guard_down_%d`) |
| `vo.dutch.civilian_killed_1` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.dutch.civilian_killed_%d`) |
| `vo.dutch.civilian_killed_2` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.dutch.civilian_killed_%d`) |
| `vo.wren.pager_started_1` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.wren.pager_started_%d`) |
| `vo.wren.pager_started_2` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.wren.pager_started_%d`) |
| `vo.wren.reloading_1` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.wren.reloading_%d`) |
| `vo.wren.reloading_2` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.wren.reloading_%d`) |
| `vo.wren.device_jammed_1` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.wren.device_jammed_%d`) |
| `vo.wren.device_jammed_2` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.wren.device_jammed_%d`) |
| `vo.wren.bagging_body_1` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.wren.bagging_body_%d`) |
| `vo.wren.bagging_body_2` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.wren.bagging_body_%d`) |
| `vo.wren.going_loud_1` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.wren.going_loud_%d`) |
| `vo.wren.going_loud_2` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.wren.going_loud_%d`) |
| `vo.wren.crew_downed_1` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.wren.crew_downed_%d`) |
| `vo.wren.crew_downed_2` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.wren.crew_downed_%d`) |
| `vo.wren.reviving_1` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.wren.reviving_%d`) |
| `vo.wren.reviving_2` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.wren.reviving_%d`) |
| `vo.wren.cops_incoming_1` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.wren.cops_incoming_%d`) |
| `vo.wren.cops_incoming_2` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.wren.cops_incoming_%d`) |
| `vo.wren.loot_secured_1` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.wren.loot_secured_%d`) |
| `vo.wren.loot_secured_2` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.wren.loot_secured_%d`) |
| `vo.wren.guard_down_1` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.wren.guard_down_%d`) |
| `vo.wren.guard_down_2` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.wren.guard_down_%d`) |
| `vo.wren.civilian_killed_1` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.wren.civilian_killed_%d`) |
| `vo.wren.civilian_killed_2` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.wren.civilian_killed_%d`) |
| `vo.marten.pager_started_1` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.marten.pager_started_%d`) |
| `vo.marten.pager_started_2` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.marten.pager_started_%d`) |
| `vo.marten.reloading_1` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.marten.reloading_%d`) |
| `vo.marten.reloading_2` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.marten.reloading_%d`) |
| `vo.marten.device_jammed_1` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.marten.device_jammed_%d`) |
| `vo.marten.device_jammed_2` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.marten.device_jammed_%d`) |
| `vo.marten.bagging_body_1` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.marten.bagging_body_%d`) |
| `vo.marten.bagging_body_2` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.marten.bagging_body_%d`) |
| `vo.marten.going_loud_1` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.marten.going_loud_%d`) |
| `vo.marten.going_loud_2` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.marten.going_loud_%d`) |
| `vo.marten.crew_downed_1` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.marten.crew_downed_%d`) |
| `vo.marten.crew_downed_2` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.marten.crew_downed_%d`) |
| `vo.marten.reviving_1` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.marten.reviving_%d`) |
| `vo.marten.reviving_2` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.marten.reviving_%d`) |
| `vo.marten.cops_incoming_1` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.marten.cops_incoming_%d`) |
| `vo.marten.cops_incoming_2` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.marten.cops_incoming_%d`) |
| `vo.marten.loot_secured_1` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.marten.loot_secured_%d`) |
| `vo.marten.loot_secured_2` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.marten.loot_secured_%d`) |
| `vo.marten.guard_down_1` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.marten.guard_down_%d`) |
| `vo.marten.guard_down_2` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.marten.guard_down_%d`) |
| `vo.marten.civilian_killed_1` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.marten.civilian_killed_%d`) |
| `vo.marten.civilian_killed_2` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.marten.civilian_killed_%d`) |
| `vo.jay.pager_started_1` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.jay.pager_started_%d`) |
| `vo.jay.pager_started_2` | pager_started | A | systems/vo/bark_tweak.tres:25 (builder `vo.jay.pager_started_%d`) |
| `vo.jay.reloading_1` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.jay.reloading_%d`) |
| `vo.jay.reloading_2` | reloading | A | systems/vo/bark_tweak.tres:28 (builder `vo.jay.reloading_%d`) |
| `vo.jay.device_jammed_1` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.jay.device_jammed_%d`) |
| `vo.jay.device_jammed_2` | device_jammed | A | systems/vo/bark_tweak.tres:26 (builder `vo.jay.device_jammed_%d`) |
| `vo.jay.bagging_body_1` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.jay.bagging_body_%d`) |
| `vo.jay.bagging_body_2` | bagging_body | A | systems/vo/bark_tweak.tres:29 (builder `vo.jay.bagging_body_%d`) |
| `vo.jay.going_loud_1` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.jay.going_loud_%d`) |
| `vo.jay.going_loud_2` | going_loud | A | systems/vo/bark_tweak.tres:30 (builder `vo.jay.going_loud_%d`) |
| `vo.jay.crew_downed_1` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.jay.crew_downed_%d`) |
| `vo.jay.crew_downed_2` | crew_downed | A | systems/vo/bark_tweak.tres:27 (builder `vo.jay.crew_downed_%d`) |
| `vo.jay.reviving_1` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.jay.reviving_%d`) |
| `vo.jay.reviving_2` | reviving | A | systems/vo/bark_tweak.tres:31 (builder `vo.jay.reviving_%d`) |
| `vo.jay.cops_incoming_1` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.jay.cops_incoming_%d`) |
| `vo.jay.cops_incoming_2` | cops_incoming | A | systems/vo/bark_tweak.tres:32 (builder `vo.jay.cops_incoming_%d`) |
| `vo.jay.loot_secured_1` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.jay.loot_secured_%d`) |
| `vo.jay.loot_secured_2` | loot_secured | A | systems/vo/bark_tweak.tres:33 (builder `vo.jay.loot_secured_%d`) |
| `vo.jay.guard_down_1` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.jay.guard_down_%d`) |
| `vo.jay.guard_down_2` | guard_down | A | systems/vo/bark_tweak.tres:34 (builder `vo.jay.guard_down_%d`) |
| `vo.jay.civilian_killed_1` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.jay.civilian_killed_%d`) |
| `vo.jay.civilian_killed_2` | civilian_killed | A | systems/vo/bark_tweak.tres:35 (builder `vo.jay.civilian_killed_%d`) |
| `vo.mercer.abort` | stealth_abort | R | **UNSAID**: every STEALTH_ONLY heist says its own abort line (HeistMission.own_abort_line): shadow_ledger: vo.mercer.shadow_ledger_abort |
| `vo.mercer.pager_last` | pager_last_answer | A | systems/stealth/pager_system.gd:314<br>systems/vo/bark_tweak.tres:12 |
| `vo.mercer.dev_start` | dev_start | A | systems/dev/dev_sandbox_mission.gd:12 |
| `vo.guard.cuff_warning` | cuff_warning | A | systems/stealth/stealth_tweak.gd:309 |
| `vo.crew.ack_follow` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:176 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_hold` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:176 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_carry_bag` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:176 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_drop_bag` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:176 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_revive` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:176 (builder `vo.crew.ack_%s`) |
| `vo.vance.radio_objective_done_1` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_done_2` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_done_3` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_new_1` | radio.objective_new | B | ContactRadio radio.objective_new [lockdown] via gallery_night (generic)<br>ContactRadio radio.objective_new [server_door] via gallery_night (generic) |
| `vo.vance.radio_objective_new_2` | radio.objective_new | B | ContactRadio radio.objective_new [lockdown] via gallery_night (generic)<br>ContactRadio radio.objective_new [server_door] via gallery_night (generic) |
| `vo.vance.radio_objective_new_3` | radio.objective_new | B | ContactRadio radio.objective_new [lockdown] via gallery_night (generic)<br>ContactRadio radio.objective_new [server_door] via gallery_night (generic) |
| `vo.vance.radio_objective_failed_1` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_2` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_3` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_alarm_1` | radio.alarm | B | ContactRadio radio.alarm via gallery_night (generic)<br>ContactRadio radio.alarm via glasshouse (generic) |
| `vo.vance.radio_alarm_2` | radio.alarm | B | ContactRadio radio.alarm via gallery_night (generic)<br>ContactRadio radio.alarm via glasshouse (generic) |
| `vo.vance.radio_alarm_3` | radio.alarm | B | ContactRadio radio.alarm via gallery_night (generic)<br>ContactRadio radio.alarm via glasshouse (generic) |
| `vo.vance.radio_assault_build_1` | radio.assault_build | B | ContactRadio radio.assault_build via gallery_night (generic)<br>ContactRadio radio.assault_build via glasshouse (generic) |
| `vo.vance.radio_assault_build_2` | radio.assault_build | B | ContactRadio radio.assault_build via gallery_night (generic)<br>ContactRadio radio.assault_build via glasshouse (generic) |
| `vo.vance.radio_assault_build_3` | radio.assault_build | B | ContactRadio radio.assault_build via gallery_night (generic)<br>ContactRadio radio.assault_build via glasshouse (generic) |
| `vo.vance.radio_assault_sustain_1` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via gallery_night (generic)<br>ContactRadio radio.assault_sustain via glasshouse (generic) |
| `vo.vance.radio_assault_sustain_2` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via gallery_night (generic)<br>ContactRadio radio.assault_sustain via glasshouse (generic) |
| `vo.vance.radio_assault_sustain_3` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via gallery_night (generic)<br>ContactRadio radio.assault_sustain via glasshouse (generic) |
| `vo.vance.radio_assault_fade_1` | radio.assault_fade | B | ContactRadio radio.assault_fade via gallery_night (generic)<br>ContactRadio radio.assault_fade via glasshouse (generic) |
| `vo.vance.radio_assault_fade_2` | radio.assault_fade | B | ContactRadio radio.assault_fade via gallery_night (generic)<br>ContactRadio radio.assault_fade via glasshouse (generic) |
| `vo.vance.radio_assault_fade_3` | radio.assault_fade | B | ContactRadio radio.assault_fade via gallery_night (generic)<br>ContactRadio radio.assault_fade via glasshouse (generic) |
| `vo.vance.radio_escape_available_1` | radio.escape_available | B | ContactRadio radio.escape_available via gallery_night (generic)<br>ContactRadio radio.escape_available via glasshouse (generic) |
| `vo.vance.radio_escape_available_2` | radio.escape_available | B | ContactRadio radio.escape_available via gallery_night (generic)<br>ContactRadio radio.escape_available via glasshouse (generic) |
| `vo.vance.radio_escape_available_3` | radio.escape_available | B | ContactRadio radio.escape_available via gallery_night (generic)<br>ContactRadio radio.escape_available via glasshouse (generic) |
| `vo.vance.radio_escape_1` | radio.escape | B | ContactRadio radio.escape via gallery_night (generic)<br>ContactRadio radio.escape via glasshouse (generic) |
| `vo.vance.radio_escape_2` | radio.escape | B | ContactRadio radio.escape via gallery_night (generic)<br>ContactRadio radio.escape via glasshouse (generic) |
| `vo.vance.radio_escape_3` | radio.escape | B | ContactRadio radio.escape via gallery_night (generic)<br>ContactRadio radio.escape via glasshouse (generic) |
| `vo.vance.radio_loot_secured_1` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.jewelry) via glasshouse (generic) |
| `vo.vance.radio_loot_secured_2` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.jewelry) via glasshouse (generic) |
| `vo.vance.radio_loot_secured_3` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.jewelry) via glasshouse (generic) |
| `vo.reyes.radio_objective_done_1` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_2` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_3` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_1` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_2` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_3` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_failed_1` | radio.objective_failed | B | ContactRadio radio.objective_failed [cartel] via dockside_burn (generic) |
| `vo.reyes.radio_objective_failed_2` | radio.objective_failed | B | ContactRadio radio.objective_failed [cartel] via dockside_burn (generic) |
| `vo.reyes.radio_objective_failed_3` | radio.objective_failed | B | ContactRadio radio.objective_failed [cartel] via dockside_burn (generic) |
| `vo.reyes.radio_alarm_1` | radio.alarm | B | ContactRadio radio.alarm via dockside_burn (generic) |
| `vo.reyes.radio_alarm_2` | radio.alarm | B | ContactRadio radio.alarm via dockside_burn (generic) |
| `vo.reyes.radio_alarm_3` | radio.alarm | B | ContactRadio radio.alarm via dockside_burn (generic) |
| `vo.reyes.radio_assault_build_1` | radio.assault_build | B | ContactRadio radio.assault_build via dockside_burn (generic) |
| `vo.reyes.radio_assault_build_2` | radio.assault_build | B | ContactRadio radio.assault_build via dockside_burn (generic) |
| `vo.reyes.radio_assault_build_3` | radio.assault_build | B | ContactRadio radio.assault_build via dockside_burn (generic) |
| `vo.reyes.radio_assault_sustain_1` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via dockside_burn (generic) |
| `vo.reyes.radio_assault_sustain_2` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via dockside_burn (generic) |
| `vo.reyes.radio_assault_sustain_3` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via dockside_burn (generic) |
| `vo.reyes.radio_assault_fade_1` | radio.assault_fade | B | ContactRadio radio.assault_fade via dockside_burn (generic) |
| `vo.reyes.radio_assault_fade_2` | radio.assault_fade | B | ContactRadio radio.assault_fade via dockside_burn (generic) |
| `vo.reyes.radio_assault_fade_3` | radio.assault_fade | B | ContactRadio radio.assault_fade via dockside_burn (generic) |
| `vo.reyes.radio_escape_available_1` | radio.escape_available | B | ContactRadio radio.escape_available via dockside_burn (generic) |
| `vo.reyes.radio_escape_available_2` | radio.escape_available | B | ContactRadio radio.escape_available via dockside_burn (generic) |
| `vo.reyes.radio_escape_available_3` | radio.escape_available | B | ContactRadio radio.escape_available via dockside_burn (generic) |
| `vo.reyes.radio_escape_1` | radio.escape | B | ContactRadio radio.escape via dockside_burn (generic) |
| `vo.reyes.radio_escape_2` | radio.escape | B | ContactRadio radio.escape via dockside_burn (generic) |
| `vo.reyes.radio_escape_3` | radio.escape | B | ContactRadio radio.escape via dockside_burn (generic) |
| `vo.reyes.radio_loot_secured_1` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.contraband) via dockside_burn (generic) |
| `vo.reyes.radio_loot_secured_2` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.contraband) via dockside_burn (generic) |
| `vo.reyes.radio_loot_secured_3` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.contraband) via dockside_burn (generic) |
| `vo.accountant.radio_objective_done_1` | radio.objective_done | R | ContactRadio radio.objective_done [vault_drill] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_done_2` | radio.objective_done | R | ContactRadio radio.objective_done [vault_drill] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_done_3` | radio.objective_done | R | ContactRadio radio.objective_done [vault_drill] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_new_1` | radio.objective_new | R | ContactRadio radio.objective_new [bond_safe] via ostrander_federal (generic)<br>ContactRadio radio.objective_new [gold_cage] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_new_2` | radio.objective_new | R | ContactRadio radio.objective_new [bond_safe] via ostrander_federal (generic)<br>ContactRadio radio.objective_new [gold_cage] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_new_3` | radio.objective_new | R | ContactRadio radio.objective_new [bond_safe] via ostrander_federal (generic)<br>ContactRadio radio.objective_new [gold_cage] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_failed_1` | radio.objective_failed | B | ContactRadio radio.objective_failed [time_lock_wait] via night_deposit (generic)<br>ContactRadio radio.objective_failed [time_lock_wait] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_failed_2` | radio.objective_failed | B | ContactRadio radio.objective_failed [time_lock_wait] via night_deposit (generic)<br>ContactRadio radio.objective_failed [time_lock_wait] via ostrander_federal (generic) |
| `vo.accountant.radio_objective_failed_3` | radio.objective_failed | B | ContactRadio radio.objective_failed [time_lock_wait] via night_deposit (generic)<br>ContactRadio radio.objective_failed [time_lock_wait] via ostrander_federal (generic) |
| `vo.accountant.radio_alarm_1` | radio.alarm | B | ContactRadio radio.alarm via night_deposit (generic)<br>ContactRadio radio.alarm via ostrander_federal (generic) |
| `vo.accountant.radio_alarm_2` | radio.alarm | B | ContactRadio radio.alarm via night_deposit (generic)<br>ContactRadio radio.alarm via ostrander_federal (generic) |
| `vo.accountant.radio_alarm_3` | radio.alarm | B | ContactRadio radio.alarm via night_deposit (generic)<br>ContactRadio radio.alarm via ostrander_federal (generic) |
| `vo.accountant.radio_assault_build_1` | radio.assault_build | B | ContactRadio radio.assault_build via night_deposit (generic)<br>ContactRadio radio.assault_build via ostrander_federal (generic) |
| `vo.accountant.radio_assault_build_2` | radio.assault_build | B | ContactRadio radio.assault_build via night_deposit (generic)<br>ContactRadio radio.assault_build via ostrander_federal (generic) |
| `vo.accountant.radio_assault_build_3` | radio.assault_build | B | ContactRadio radio.assault_build via night_deposit (generic)<br>ContactRadio radio.assault_build via ostrander_federal (generic) |
| `vo.accountant.radio_assault_sustain_1` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via night_deposit (generic)<br>ContactRadio radio.assault_sustain via ostrander_federal (generic) |
| `vo.accountant.radio_assault_sustain_2` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via night_deposit (generic)<br>ContactRadio radio.assault_sustain via ostrander_federal (generic) |
| `vo.accountant.radio_assault_sustain_3` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via night_deposit (generic)<br>ContactRadio radio.assault_sustain via ostrander_federal (generic) |
| `vo.accountant.radio_assault_fade_1` | radio.assault_fade | B | ContactRadio radio.assault_fade via night_deposit (generic)<br>ContactRadio radio.assault_fade via ostrander_federal (generic) |
| `vo.accountant.radio_assault_fade_2` | radio.assault_fade | B | ContactRadio radio.assault_fade via night_deposit (generic)<br>ContactRadio radio.assault_fade via ostrander_federal (generic) |
| `vo.accountant.radio_assault_fade_3` | radio.assault_fade | B | ContactRadio radio.assault_fade via night_deposit (generic)<br>ContactRadio radio.assault_fade via ostrander_federal (generic) |
| `vo.accountant.radio_escape_available_1` | radio.escape_available | B | ContactRadio radio.escape_available via night_deposit (generic)<br>ContactRadio radio.escape_available via ostrander_federal (generic)<br>ContactRadio radio.escape_available via shadow_ledger (generic) |
| `vo.accountant.radio_escape_available_2` | radio.escape_available | B | ContactRadio radio.escape_available via night_deposit (generic)<br>ContactRadio radio.escape_available via ostrander_federal (generic)<br>ContactRadio radio.escape_available via shadow_ledger (generic) |
| `vo.accountant.radio_escape_available_3` | radio.escape_available | B | ContactRadio radio.escape_available via night_deposit (generic)<br>ContactRadio radio.escape_available via ostrander_federal (generic)<br>ContactRadio radio.escape_available via shadow_ledger (generic) |
| `vo.accountant.radio_escape_1` | radio.escape | B | ContactRadio radio.escape via night_deposit (generic)<br>ContactRadio radio.escape via ostrander_federal (generic) |
| `vo.accountant.radio_escape_2` | radio.escape | B | ContactRadio radio.escape via night_deposit (generic)<br>ContactRadio radio.escape via ostrander_federal (generic) |
| `vo.accountant.radio_escape_3` | radio.escape | B | ContactRadio radio.escape via night_deposit (generic)<br>ContactRadio radio.escape via ostrander_federal (generic) |
| `vo.accountant.radio_loot_secured_1` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.gold) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.bearer_bonds) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.server_drives) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via shadow_ledger (generic) |
| `vo.accountant.radio_loot_secured_2` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.gold) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.bearer_bonds) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.server_drives) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via shadow_ledger (generic) |
| `vo.accountant.radio_loot_secured_3` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.gold) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.bearer_bonds) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.server_drives) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via ostrander_federal (generic)<br>ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via shadow_ledger (generic) |
| `vo.mercer.radio_objective_done_1` | radio.objective_done | B | ContactRadio radio.objective_done [get_loot] via dev_sandbox (generic) |
| `vo.mercer.radio_objective_done_2` | radio.objective_done | B | ContactRadio radio.objective_done [get_loot] via dev_sandbox (generic) |
| `vo.mercer.radio_objective_done_3` | radio.objective_done | B | ContactRadio radio.objective_done [get_loot] via dev_sandbox (generic) |
| `vo.mercer.radio_objective_new_1` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via dev_sandbox (generic) |
| `vo.mercer.radio_objective_new_2` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via dev_sandbox (generic) |
| `vo.mercer.radio_objective_new_3` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via dev_sandbox (generic) |
| `vo.mercer.radio_objective_failed_1` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |
| `vo.mercer.radio_objective_failed_2` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |
| `vo.mercer.radio_objective_failed_3` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |
| `vo.mercer.radio_alarm_1` | radio.alarm | B | ContactRadio radio.alarm via dev_sandbox (generic) |
| `vo.mercer.radio_alarm_2` | radio.alarm | B | ContactRadio radio.alarm via dev_sandbox (generic) |
| `vo.mercer.radio_alarm_3` | radio.alarm | B | ContactRadio radio.alarm via dev_sandbox (generic) |
| `vo.mercer.radio_assault_build_1` | radio.assault_build | B | ContactRadio radio.assault_build via dev_sandbox (generic) |
| `vo.mercer.radio_assault_build_2` | radio.assault_build | B | ContactRadio radio.assault_build via dev_sandbox (generic) |
| `vo.mercer.radio_assault_build_3` | radio.assault_build | B | ContactRadio radio.assault_build via dev_sandbox (generic) |
| `vo.mercer.radio_assault_sustain_1` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via dev_sandbox (generic) |
| `vo.mercer.radio_assault_sustain_2` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via dev_sandbox (generic) |
| `vo.mercer.radio_assault_sustain_3` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via dev_sandbox (generic) |
| `vo.mercer.radio_assault_fade_1` | radio.assault_fade | B | ContactRadio radio.assault_fade via dev_sandbox (generic) |
| `vo.mercer.radio_assault_fade_2` | radio.assault_fade | B | ContactRadio radio.assault_fade via dev_sandbox (generic) |
| `vo.mercer.radio_assault_fade_3` | radio.assault_fade | B | ContactRadio radio.assault_fade via dev_sandbox (generic) |
| `vo.mercer.radio_escape_available_1` | radio.escape_available | B | ContactRadio radio.escape_available via dev_sandbox (generic) |
| `vo.mercer.radio_escape_available_2` | radio.escape_available | B | ContactRadio radio.escape_available via dev_sandbox (generic) |
| `vo.mercer.radio_escape_available_3` | radio.escape_available | B | ContactRadio radio.escape_available via dev_sandbox (generic) |
| `vo.mercer.radio_escape_1` | radio.escape | B | ContactRadio radio.escape via dev_sandbox (generic) |
| `vo.mercer.radio_escape_2` | radio.escape | B | ContactRadio radio.escape via dev_sandbox (generic) |
| `vo.mercer.radio_escape_3` | radio.escape | B | ContactRadio radio.escape via dev_sandbox (generic) |
| `vo.mercer.radio_loot_secured_1` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.jewelry) via dev_sandbox (generic) |
| `vo.mercer.radio_loot_secured_2` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.jewelry) via dev_sandbox (generic) |
| `vo.mercer.radio_loot_secured_3` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.jewelry) via dev_sandbox (generic) |
| `vo.accountant.briefing_ostrander_federal_1` | briefing | B | BriefingModel.voice_lines via ostrander_federal (contact.accountant) |
| `vo.accountant.briefing_ostrander_federal_2` | briefing | B | BriefingModel.voice_lines via ostrander_federal (contact.accountant) |
| `vo.accountant.briefing_ostrander_federal_3` | briefing | B | BriefingModel.voice_lines via ostrander_federal (contact.accountant) |
| `vo.mercer.briefing_ostrander_federal_1` | briefing | B | BriefingModel.voice_lines via ostrander_federal (contact.accountant) |
| `vo.mercer.briefing_ostrander_federal_2` | briefing | B | BriefingModel.voice_lines via ostrander_federal (contact.accountant) |
| `vo.accountant.ostrander_federal_contact_intro` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:131 |
| `vo.accountant.ostrander_federal_payday` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:132 |
| `vo.mercer.ostrander_federal_intro` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:130 |
| `vo.mercer.ostrander_federal_case_manager` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:101 |
| `vo.mercer.ostrander_federal_case_gallery` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:102 |
| `vo.mercer.ostrander_federal_case_operator` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:103<br>world/heists/ostrander_federal/ostrander_federal_mission.gd:505 |
| `vo.mercer.ostrander_federal_keycard` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:133 |
| `vo.mercer.ostrander_federal_code_hint` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:134 |
| `vo.mercer.ostrander_federal_pc_found` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:135 |
| `vo.mercer.ostrander_federal_hack_interrupt` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:136 |
| `vo.mercer.ostrander_federal_code` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:137 |
| `vo.mercer.ostrander_federal_server_hack` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:138 |
| `vo.mercer.ostrander_federal_vault_gate` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:139 |
| `vo.mercer.ostrander_federal_lasers_off` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:140 |
| `vo.mercer.ostrander_federal_time_lock_started` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:141 |
| `vo.mercer.ostrander_federal_time_lock_60` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:142 |
| `vo.mercer.ostrander_federal_time_lock_open` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:143 |
| `vo.mercer.ostrander_federal_last_pager` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:144 |
| `vo.mercer.ostrander_federal_camera_warning` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:145 |
| `vo.mercer.ostrander_federal_vip_client` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:146 |
| `vo.mercer.ostrander_federal_armored_car` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:147 |
| `vo.mercer.ostrander_federal_lockdown` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:148 |
| `vo.mercer.ostrander_federal_lockdown_vault_open` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:149 |
| `vo.mercer.ostrander_federal_drill_inbound_terrace` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:150 |
| `vo.mercer.ostrander_federal_drill_inbound_dock` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:151 |
| `vo.mercer.ostrander_federal_drill_delivered_terrace` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:152 |
| `vo.mercer.ostrander_federal_drill_delivered_dock` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:153 |
| `vo.mercer.ostrander_federal_drill_prepositioned` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:154 |
| `vo.mercer.ostrander_federal_drill_started` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:155 |
| `vo.mercer.ostrander_federal_drill_jam` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:156 |
| `vo.mercer.ostrander_federal_burn_through` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:157 |
| `vo.mercer.ostrander_federal_hoist` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:158 |
| `vo.mercer.ostrander_federal_gold_cage` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:159 |
| `vo.mercer.ostrander_federal_required_secured` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:160 |
| `vo.mercer.ostrander_federal_sniper_assay` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:168 |
| `vo.mercer.ostrander_federal_sniper_garage` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:169 |
| `vo.mercer.ostrander_federal_sniper_tower` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:170 |
| `vo.mercer.ostrander_federal_van_eta` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:161 |
| `vo.mercer.ostrander_federal_heli_eta` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:162 |
| `vo.mercer.ostrander_federal_escape` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:163 |
| `vo.mercer.ostrander_federal_captain_arrived` | mission | A | world/heists/ostrander_federal/ostrander_federal_mission.gd:165 |
| `vo.accountant.ostrander_federal_radio_casing` | radio.objective_done | B | ContactRadio radio.objective_done [casing] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_keycard` | radio.objective_done | B | ContactRadio radio.objective_done [keycard] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_code_hint` | radio.objective_done | B | ContactRadio radio.objective_done [code_hint] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_code_pc` | radio.objective_done | B | ContactRadio radio.objective_done [code_pc] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_server` | radio.objective_done | B | ContactRadio radio.objective_done [server] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_vault_gate` | radio.objective_done | B | ContactRadio radio.objective_done [vault_gate] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_lasers` | radio.objective_done | B | ContactRadio radio.objective_done [lasers] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_time_lock_new` | radio.objective_new | B | ContactRadio radio.objective_new [time_lock] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_time_lock` | radio.objective_done | B | ContactRadio radio.objective_done [time_lock] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_time_lock_wait_new` | radio.objective_new | B | ContactRadio radio.objective_new [time_lock_wait] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_time_lock_wait` | radio.objective_done | B | ContactRadio radio.objective_done [time_lock_wait] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_vault_loot_new` | radio.objective_new | B | ContactRadio radio.objective_new [vault_loot] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_vault_loot` | radio.objective_done | B | ContactRadio radio.objective_done [vault_loot] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_gold_cage` | radio.objective_done | B | ContactRadio radio.objective_done [gold_cage] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_secure` | radio.objective_done | B | ContactRadio radio.objective_done [secure] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_deposit_boxes` | radio.objective_done | B | ContactRadio radio.objective_done [deposit_boxes] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_bond_safe` | radio.objective_done | B | ContactRadio radio.objective_done [bond_safe] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_president_safe` | radio.objective_done | B | ContactRadio radio.objective_done [president_safe] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_server_drives` | radio.objective_done | B | ContactRadio radio.objective_done [server_drives] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_drill_delivery_new` | radio.objective_new | B | ContactRadio radio.objective_new [drill_delivery] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_drill_delivery` | radio.objective_done | B | ContactRadio radio.objective_done [drill_delivery] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_vault_drill_new` | radio.objective_new | B | ContactRadio radio.objective_new [vault_drill] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_vault_breach` | radio.objective_done | B | ContactRadio radio.objective_done [vault_breach] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_escape_wait_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape_wait] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_escape_wait` | radio.objective_done | B | ContactRadio radio.objective_done [escape_wait] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via ostrander_federal<br>ContactRadio radio.loot_secured (loot.gold) via ostrander_federal<br>ContactRadio radio.loot_secured (loot.bearer_bonds) via ostrander_federal<br>ContactRadio radio.loot_secured (loot.server_drives) via ostrander_federal<br>ContactRadio radio.loot_secured (loot.small_valuables) via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_loot_cash_bricks` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_loot_gold` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.gold) via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_loot_bearer_bonds` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.bearer_bonds) via ostrander_federal |
| `vo.accountant.ostrander_federal_radio_loot_server_drives` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.server_drives) via ostrander_federal |
| `vo.mercer.rolling_thunder_intro` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_eta_60` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_eta_30` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_marshal` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_signals_done` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_signals_remind` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_c4_found` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_thermite_found` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sighted` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_stopped` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_go` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_alerted` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_escort_down` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_police` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_saw_on` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_saw_jam` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_deadbolts` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_truck_open` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_c4_armed` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_thermite_burn` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_gold` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_bonds` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_lift_dead` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sniper_skyway` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sniper_rail` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_sniper_crane` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_secured` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_van_eta` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_heli_eta` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.mercer.rolling_thunder_escape` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_crash` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_ready` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_boxed` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
| `vo.reyes.rolling_thunder_payday` | mission | S | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `mission` fact to its lines |
