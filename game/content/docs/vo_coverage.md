# VO coverage (D-117 §6)

**Generated. Do not edit.** Regenerate with
`godot --headless --path game -s res://content/voice/tools/vo_coverage_cli.gd` (ENV B tool,
`content/voice/tools/vo_coverage.gd`; the test is `tests/b/test_vo_coverage.gd`).

A line is said when a trigger site can emit its id: a literal id in game code or data, a format builder
(`%s` = one identifier), or one of B's builders (ContactRadio from each heist's HeistDef and mission
objective calls; BriefingModel.voice_lines). Owner = whose code must say it (B: briefing / radio;
C: heist mission lines; A: barks, acks and system lines; B reserve: generic radio lines no current heist
reaches, kept for RadioTweak.speaker_overrides and new heists). Heists iterated: dev_sandbox, dockside_burn, gallery_night, glasshouse, night_deposit, shadow_ledger.

## Summary

| Group | Lines | Said | Unsaid | Unsaid A | Unsaid B | Unsaid B reserve | Unsaid C |
|---|---|---|---|---|---|---|---|
| glasshouse | 29 | 26 | 3 | 0 | 0 | 0 | 3 |
| night_deposit | 39 | 39 | 0 | 0 | 0 | 0 | 0 |
| shadow_ledger | 41 | 41 | 0 | 0 | 0 | 0 | 0 |
| dockside_burn | 49 | 49 | 0 | 0 | 0 | 0 | 0 |
| gallery_night | 67 | 65 | 2 | 0 | 0 | 0 | 2 |
| shared | 295 | 87 | 208 | 166 | 0 | 42 | 0 |

Missing (code can say it, the table has no such line): 0.

## Unsaid, owner A (166)

| Line | Event | Why |
|---|---|---|
| `vo.mercer.heist_start_casing_1` | heist_start_casing | nothing says it: no literal id or builder, and no code maps the `heist_start_casing` fact to its lines |
| `vo.mercer.heist_start_casing_2` | heist_start_casing | nothing says it: no literal id or builder, and no code maps the `heist_start_casing` fact to its lines |
| `vo.mercer.crew_masked_1` | crew_masked | nothing says it: no literal id or builder, and no code maps the `crew_masked` fact to its lines |
| `vo.mercer.crew_masked_2` | crew_masked | nothing says it: no literal id or builder, and no code maps the `crew_masked` fact to its lines |
| `vo.mercer.pager_started_1` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.mercer.pager_started_2` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.mercer.pager_answered_1` | pager_answered | nothing says it: no literal id or builder, and no code maps the `pager_answered` fact to its lines |
| `vo.mercer.pager_answered_2` | pager_answered | nothing says it: no literal id or builder, and no code maps the `pager_answered` fact to its lines |
| `vo.mercer.pager_last_answer_1` | pager_last_answer | nothing says it: no literal id or builder, and no code maps the `pager_last_answer` fact to its lines |
| `vo.mercer.pager_last_answer_2` | pager_last_answer | nothing says it: no literal id or builder, and no code maps the `pager_last_answer` fact to its lines |
| `vo.mercer.pager_limit_1` | pager_limit | nothing says it: no literal id or builder, and no code maps the `pager_limit` fact to its lines |
| `vo.mercer.pager_limit_2` | pager_limit | nothing says it: no literal id or builder, and no code maps the `pager_limit` fact to its lines |
| `vo.mercer.pager_failed_1` | pager_failed | nothing says it: no literal id or builder, and no code maps the `pager_failed` fact to its lines |
| `vo.mercer.pager_failed_2` | pager_failed | nothing says it: no literal id or builder, and no code maps the `pager_failed` fact to its lines |
| `vo.mercer.body_discovered_1` | body_discovered | nothing says it: no literal id or builder, and no code maps the `body_discovered` fact to its lines |
| `vo.mercer.body_discovered_2` | body_discovered | nothing says it: no literal id or builder, and no code maps the `body_discovered` fact to its lines |
| `vo.mercer.camera_spotted_1` | camera_spotted | nothing says it: no literal id or builder, and no code maps the `camera_spotted` fact to its lines |
| `vo.mercer.camera_spotted_2` | camera_spotted | nothing says it: no literal id or builder, and no code maps the `camera_spotted` fact to its lines |
| `vo.mercer.device_started_1` | device_started | nothing says it: no literal id or builder, and no code maps the `device_started` fact to its lines |
| `vo.mercer.device_started_2` | device_started | nothing says it: no literal id or builder, and no code maps the `device_started` fact to its lines |
| `vo.mercer.device_jammed_1` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.mercer.device_jammed_2` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.mercer.device_finished_1` | device_finished | nothing says it: no literal id or builder, and no code maps the `device_finished` fact to its lines |
| `vo.mercer.device_finished_2` | device_finished | nothing says it: no literal id or builder, and no code maps the `device_finished` fact to its lines |
| `vo.mercer.crew_downed_1` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.mercer.crew_downed_2` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.mercer.crew_custody_1` | crew_custody | nothing says it: no literal id or builder, and no code maps the `crew_custody` fact to its lines |
| `vo.mercer.crew_custody_2` | crew_custody | nothing says it: no literal id or builder, and no code maps the `crew_custody` fact to its lines |
| `vo.mercer.heist_success_1` | heist_success | nothing says it: no literal id or builder, and no code maps the `heist_success` fact to its lines |
| `vo.mercer.heist_success_2` | heist_success | nothing says it: no literal id or builder, and no code maps the `heist_success` fact to its lines |
| `vo.mercer.heist_failed_1` | heist_failed | nothing says it: no literal id or builder, and no code maps the `heist_failed` fact to its lines |
| `vo.mercer.heist_failed_2` | heist_failed | nothing says it: no literal id or builder, and no code maps the `heist_failed` fact to its lines |
| `vo.mercer.stealth_success_1` | stealth_success | nothing says it: no literal id or builder, and no code maps the `stealth_success` fact to its lines |
| `vo.mercer.stealth_success_2` | stealth_success | nothing says it: no literal id or builder, and no code maps the `stealth_success` fact to its lines |
| `vo.rook.pager_started_1` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.rook.pager_started_2` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.rook.reloading_1` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.rook.reloading_2` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.rook.device_jammed_1` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.rook.device_jammed_2` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.rook.bagging_body_1` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.rook.bagging_body_2` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.rook.going_loud_1` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.rook.going_loud_2` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.rook.crew_downed_1` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.rook.crew_downed_2` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.rook.reviving_1` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.rook.reviving_2` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.rook.cops_incoming_1` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.rook.cops_incoming_2` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.rook.loot_secured_1` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.rook.loot_secured_2` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.rook.guard_down_1` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.rook.guard_down_2` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.rook.civilian_killed_1` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.rook.civilian_killed_2` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.sable.pager_started_1` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.sable.pager_started_2` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.sable.reloading_1` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.sable.reloading_2` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.sable.device_jammed_1` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.sable.device_jammed_2` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.sable.bagging_body_1` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.sable.bagging_body_2` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.sable.going_loud_1` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.sable.going_loud_2` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.sable.crew_downed_1` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.sable.crew_downed_2` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.sable.reviving_1` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.sable.reviving_2` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.sable.cops_incoming_1` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.sable.cops_incoming_2` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.sable.loot_secured_1` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.sable.loot_secured_2` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.sable.guard_down_1` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.sable.guard_down_2` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.sable.civilian_killed_1` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.sable.civilian_killed_2` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.dutch.pager_started_1` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.dutch.pager_started_2` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.dutch.reloading_1` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.dutch.reloading_2` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.dutch.device_jammed_1` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.dutch.device_jammed_2` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.dutch.bagging_body_1` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.dutch.bagging_body_2` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.dutch.going_loud_1` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.dutch.going_loud_2` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.dutch.crew_downed_1` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.dutch.crew_downed_2` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.dutch.reviving_1` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.dutch.reviving_2` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.dutch.cops_incoming_1` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.dutch.cops_incoming_2` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.dutch.loot_secured_1` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.dutch.loot_secured_2` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.dutch.guard_down_1` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.dutch.guard_down_2` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.dutch.civilian_killed_1` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.dutch.civilian_killed_2` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.wren.pager_started_1` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.wren.pager_started_2` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.wren.reloading_1` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.wren.reloading_2` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.wren.device_jammed_1` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.wren.device_jammed_2` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.wren.bagging_body_1` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.wren.bagging_body_2` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.wren.going_loud_1` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.wren.going_loud_2` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.wren.crew_downed_1` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.wren.crew_downed_2` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.wren.reviving_1` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.wren.reviving_2` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.wren.cops_incoming_1` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.wren.cops_incoming_2` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.wren.loot_secured_1` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.wren.loot_secured_2` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.wren.guard_down_1` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.wren.guard_down_2` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.wren.civilian_killed_1` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.wren.civilian_killed_2` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.marten.pager_started_1` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.marten.pager_started_2` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.marten.reloading_1` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.marten.reloading_2` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.marten.device_jammed_1` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.marten.device_jammed_2` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.marten.bagging_body_1` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.marten.bagging_body_2` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.marten.going_loud_1` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.marten.going_loud_2` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.marten.crew_downed_1` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.marten.crew_downed_2` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.marten.reviving_1` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.marten.reviving_2` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.marten.cops_incoming_1` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.marten.cops_incoming_2` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.marten.loot_secured_1` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.marten.loot_secured_2` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.marten.guard_down_1` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.marten.guard_down_2` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.marten.civilian_killed_1` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.marten.civilian_killed_2` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.jay.pager_started_1` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.jay.pager_started_2` | pager_started | nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.jay.reloading_1` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.jay.reloading_2` | reloading | nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.jay.device_jammed_1` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.jay.device_jammed_2` | device_jammed | nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.jay.bagging_body_1` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.jay.bagging_body_2` | bagging_body | nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.jay.going_loud_1` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.jay.going_loud_2` | going_loud | nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.jay.crew_downed_1` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.jay.crew_downed_2` | crew_downed | nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.jay.reviving_1` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.jay.reviving_2` | reviving | nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.jay.cops_incoming_1` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.jay.cops_incoming_2` | cops_incoming | nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.jay.loot_secured_1` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.jay.loot_secured_2` | loot_secured | nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.jay.guard_down_1` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.jay.guard_down_2` | guard_down | nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.jay.civilian_killed_1` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.jay.civilian_killed_2` | civilian_killed | nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |

## Unsaid, owner B (0)

None.

## Unsaid, owner B reserve (42)

| Line | Event | Why |
|---|---|---|
| `vo.vance.radio_objective_done_1` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_done_2` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_done_3` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_1` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_2` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_objective_failed_3` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_available_1` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_available_2` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_available_3` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_1` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_2` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_3` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.reyes.radio_objective_done_1` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_2` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_3` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_1` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_2` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_3` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_failed_1` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_failed_2` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_failed_3` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_available_1` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_available_2` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_available_3` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_1` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_2` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_3` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.accountant.radio_objective_done_1` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_done_2` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_done_3` | radio.objective_done | generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_new_1` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_new_2` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_new_3` | radio.objective_new | generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_available_1` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_available_2` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_available_3` | radio.escape_available | generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_1` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_2` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_3` | radio.escape | generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.mercer.radio_objective_failed_1` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |
| `vo.mercer.radio_objective_failed_2` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |
| `vo.mercer.radio_objective_failed_3` | radio.objective_failed | generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with mercer on the radio has the fact |

## Unsaid, owner C (5)

| Line | Event | Why |
|---|---|---|
| `vo.vance.glasshouse_radio_extra_bags` | radio.objective_done | HeistDef objective `extra_bags` is never added by glasshouse's mission |
| `vo.vance.glasshouse_radio_salon` | radio.objective_done | HeistDef objective `salon` is never added by glasshouse's mission |
| `vo.vance.glasshouse_radio_display_cases` | radio.objective_done | HeistDef objective `display_cases` is never added by glasshouse's mission |
| `vo.vance.gallery_night_radio_extras` | radio.objective_done | the mission never completes objective `extras` |
| `vo.vance.gallery_night_radio_lockers` | radio.objective_done | the mission never completes objective `lockers` |

## glasshouse

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.vance.briefing_glasshouse_1` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.vance.briefing_glasshouse_2` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.vance.briefing_glasshouse_3` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.mercer.briefing_glasshouse_1` | briefing | B | BriefingModel.voice_lines via glasshouse (contact.vance) |
| `vo.mercer.glasshouse_intro` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:44 |
| `vo.mercer.glasshouse_keycard_found` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:129 |
| `vo.mercer.glasshouse_workshop_open` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:113 |
| `vo.mercer.glasshouse_drill_jam` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:147 |
| `vo.mercer.glasshouse_last_pager` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:91 |
| `vo.mercer.glasshouse_lockdown` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:182 |
| `vo.mercer.glasshouse_van_eta` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:201 |
| `vo.mercer.glasshouse_escape` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:223 |
| `vo.mercer.glasshouse_code_found` | mission | C | world/heists/glasshouse/glasshouse_mission.gd:136 |
| `vo.vance.glasshouse_radio_casing` | radio.objective_done | B | ContactRadio radio.objective_done [casing] via glasshouse |
| `vo.vance.glasshouse_radio_keycard` | radio.objective_done | B | ContactRadio radio.objective_done [keycard] via glasshouse |
| `vo.vance.glasshouse_radio_code` | radio.objective_done | B | ContactRadio radio.objective_done [code] via glasshouse |
| `vo.vance.glasshouse_radio_extra_bags` | radio.objective_done | C | **UNSAID**: HeistDef objective `extra_bags` is never added by glasshouse's mission |
| `vo.vance.glasshouse_radio_salon` | radio.objective_done | C | **UNSAID**: HeistDef objective `salon` is never added by glasshouse's mission |
| `vo.vance.glasshouse_radio_display_cases` | radio.objective_done | C | **UNSAID**: HeistDef objective `display_cases` is never added by glasshouse's mission |
| `vo.vance.glasshouse_radio_workshop_door` | radio.objective_done | B | ContactRadio radio.objective_done [workshop_door] via glasshouse |
| `vo.vance.glasshouse_radio_safe` | radio.objective_done | B | ContactRadio radio.objective_done [safe] via glasshouse |
| `vo.vance.glasshouse_radio_safe_loot_new` | radio.objective_new | B | ContactRadio radio.objective_new [safe_loot] via glasshouse |
| `vo.vance.glasshouse_radio_safe_loot` | radio.objective_done | B | ContactRadio radio.objective_done [safe_loot] via glasshouse |
| `vo.vance.glasshouse_radio_secure` | radio.objective_done | B | ContactRadio radio.objective_done [secure] via glasshouse |
| `vo.vance.glasshouse_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via glasshouse |
| `vo.vance.glasshouse_radio_escape_available` | radio.escape_available | B | ContactRadio radio.escape_available via glasshouse |
| `vo.vance.glasshouse_radio_escape` | radio.escape | B | ContactRadio radio.escape via glasshouse |
| `vo.vance.glasshouse_radio_loot_jewelry` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.jewelry) via glasshouse |
| `vo.vance.glasshouse_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.jewelry) via glasshouse<br>ContactRadio radio.loot_secured (loot.cash) via glasshouse |

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
| `vo.accountant.night_deposit_radio_escape_available` | radio.escape_available | B | ContactRadio radio.escape_available via night_deposit |
| `vo.accountant.night_deposit_radio_escape` | radio.escape | B | ContactRadio radio.escape via night_deposit |
| `vo.accountant.night_deposit_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit |
| `vo.accountant.night_deposit_radio_loot_cash_bricks` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit |

## shadow_ledger

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.accountant.briefing_shadow_ledger_1` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.accountant.briefing_shadow_ledger_2` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.accountant.briefing_shadow_ledger_3` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.mercer.briefing_shadow_ledger_1` | briefing | B | BriefingModel.voice_lines via shadow_ledger (contact.accountant) |
| `vo.mercer.shadow_ledger_intro` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:69 |
| `vo.accountant.shadow_ledger_contact_intro` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:70 |
| `vo.mercer.shadow_ledger_laptop_found` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:163 |
| `vo.mercer.shadow_ledger_keycard_found` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:176 |
| `vo.mercer.shadow_ledger_code_found` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:179 |
| `vo.mercer.shadow_ledger_camera_warning` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:49 |
| `vo.mercer.shadow_ledger_cage_open` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:218 |
| `vo.mercer.shadow_ledger_hack_started` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:184 |
| `vo.mercer.shadow_ledger_hack_interrupted` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:203 |
| `vo.mercer.shadow_ledger_hack_done` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:229 |
| `vo.mercer.shadow_ledger_lasers` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:32 |
| `vo.mercer.shadow_ledger_time_lock_started` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:186 |
| `vo.mercer.shadow_ledger_time_lock_open` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:196 |
| `vo.mercer.shadow_ledger_last_pager` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:116 |
| `vo.mercer.shadow_ledger_required_secured` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:263 |
| `vo.mercer.shadow_ledger_escape` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:266 |
| `vo.mercer.shadow_ledger_abort` | mission | C | world/heists/shadow_ledger/shadow_ledger_mission.gd:111 |
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
| `vo.accountant.shadow_ledger_radio_escape_available` | radio.escape_available | B | ContactRadio radio.escape_available via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_escape` | radio.escape | B | ContactRadio radio.escape via shadow_ledger |
| `vo.accountant.shadow_ledger_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger |
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
| `vo.mercer.dockside_burn_intro` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:89 |
| `vo.reyes.dockside_burn_contact_intro` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:90 |
| `vo.mercer.dockside_burn_cartel_awake` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:302 |
| `vo.mercer.dockside_burn_police_called` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:270 |
| `vo.mercer.dockside_burn_breach` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:397 |
| `vo.mercer.dockside_burn_product_found` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:404 |
| `vo.mercer.dockside_burn_thermite_reminder` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:405 |
| `vo.mercer.dockside_burn_burn_started` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:345 |
| `vo.mercer.dockside_burn_burn_done` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:429 |
| `vo.mercer.dockside_burn_strongroom_drill` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:350 |
| `vo.mercer.dockside_burn_drill_jam` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:377 |
| `vo.mercer.dockside_burn_strongroom_open` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:363 |
| `vo.mercer.dockside_burn_count_cage` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:353 |
| `vo.mercer.dockside_burn_lift_dead` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:518 |
| `vo.mercer.dockside_burn_containers_hint` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:204<br>world/heists/dockside_burn/dockside_burn_mission.gd:412 |
| `vo.mercer.dockside_burn_weapons_found` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:418 |
| `vo.mercer.dockside_burn_sniper_crane` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:62 |
| `vo.mercer.dockside_burn_sniper_roof` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:62 |
| `vo.mercer.dockside_burn_gangway` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:272 |
| `vo.mercer.dockside_burn_reinforcements` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:282 |
| `vo.mercer.dockside_burn_fog_lifts` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:288 |
| `vo.mercer.dockside_burn_required_secured` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:388 |
| `vo.mercer.dockside_burn_van_eta` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:474 |
| `vo.mercer.dockside_burn_boat_eta` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:474 |
| `vo.mercer.dockside_burn_escape` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:480 |
| `vo.reyes.dockside_burn_payday` | mission | C | world/heists/dockside_burn/dockside_burn_mission.gd:481 |
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
| `vo.reyes.dockside_burn_radio_escape_available` | radio.escape_available | B | ContactRadio radio.escape_available via dockside_burn |
| `vo.reyes.dockside_burn_radio_escape` | radio.escape | B | ContactRadio radio.escape via dockside_burn |
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
| `vo.vance.gallery_night_contact_intro` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:128 |
| `vo.vance.gallery_night_centrepiece` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:89 |
| `vo.vance.gallery_night_payday` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:90 |
| `vo.mercer.gallery_night_intro` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:127 |
| `vo.mercer.gallery_night_canvas_found_saint` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:258 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_canvas_found_widow` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:258 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_canvas_found_orchard` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:258 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_canvas_found_lantern` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:258 (builder `vo.mercer.gallery_night_canvas_found_%s`) |
| `vo.mercer.gallery_night_last_call_soon` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:350 |
| `vo.mercer.gallery_night_last_call` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:358 |
| `vo.mercer.gallery_night_lasers_sweep` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:74 |
| `vo.mercer.gallery_night_guests_gone` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:386 |
| `vo.mercer.gallery_night_keycard` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:76 |
| `vo.mercer.gallery_night_code_found` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:441 |
| `vo.mercer.gallery_night_sensors_warning` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:80 |
| `vo.mercer.gallery_night_hack_started` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:78 |
| `vo.mercer.gallery_night_hack_interrupted` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:79 |
| `vo.mercer.gallery_night_sensors_off` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:462 |
| `vo.mercer.gallery_night_lasers` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:81 |
| `vo.mercer.gallery_night_treasury_open` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:82 |
| `vo.mercer.gallery_night_art_store_open` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:83 |
| `vo.mercer.gallery_night_curator_keycard` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:77 |
| `vo.mercer.gallery_night_inspectors` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:93 |
| `vo.mercer.gallery_night_vaultline` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:94 |
| `vo.mercer.gallery_night_last_pager` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:84 |
| `vo.mercer.gallery_night_lockdown` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:571 |
| `vo.mercer.gallery_night_shutters_up` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:85 |
| `vo.mercer.gallery_night_vault_drill` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:86 |
| `vo.mercer.gallery_night_drill_jam` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:87 |
| `vo.mercer.gallery_night_required_secured` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:528 |
| `vo.mercer.gallery_night_van_eta` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:541 (builder `vo.mercer.gallery_night_%s_eta`) |
| `vo.mercer.gallery_night_limo_eta` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:541 (builder `vo.mercer.gallery_night_%s_eta`) |
| `vo.mercer.gallery_night_sniper_hotel` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:88 |
| `vo.mercer.gallery_night_escape` | mission | C | world/heists/gallery_night/gallery_night_mission.gd:552 |
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
| `vo.vance.gallery_night_radio_extras` | radio.objective_done | C | **UNSAID**: the mission never completes objective `extras` |
| `vo.vance.gallery_night_radio_lockers` | radio.objective_done | C | **UNSAID**: the mission never completes objective `lockers` |
| `vo.vance.gallery_night_radio_curator_safe` | radio.objective_done | B | ContactRadio radio.objective_done [curator_safe] via gallery_night |
| `vo.vance.gallery_night_radio_lockdown` | radio.objective_done | B | ContactRadio radio.objective_done [lockdown] via gallery_night |
| `vo.vance.gallery_night_radio_server_door` | radio.objective_done | B | ContactRadio radio.objective_done [server_door] via gallery_night |
| `vo.vance.gallery_night_radio_vault_drill_new` | radio.objective_new | B | ContactRadio radio.objective_new [vault_drill] via gallery_night |
| `vo.vance.gallery_night_radio_vault_drill` | radio.objective_done | B | ContactRadio radio.objective_done [vault_drill] via gallery_night |
| `vo.vance.gallery_night_radio_escape_wait_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape_wait] via gallery_night |
| `vo.vance.gallery_night_radio_escape_wait` | radio.objective_done | B | ContactRadio radio.objective_done [escape_wait] via gallery_night |
| `vo.vance.gallery_night_radio_escape_new` | radio.objective_new | B | ContactRadio radio.objective_new [escape] via gallery_night |
| `vo.vance.gallery_night_radio_escape_available` | radio.escape_available | B | ContactRadio radio.escape_available via gallery_night |
| `vo.vance.gallery_night_radio_escape` | radio.escape | B | ContactRadio radio.escape via gallery_night |
| `vo.vance.gallery_night_radio_loot_lantern_bearer` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night |
| `vo.vance.gallery_night_radio_loot_study` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_study) via gallery_night |
| `vo.vance.gallery_night_radio_loot_salt_orchard` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night |
| `vo.vance.gallery_night_radio_loot_widow_in_blue` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night |
| `vo.vance.gallery_night_radio_loot_tidewater_saint` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night |
| `vo.vance.gallery_night_radio_loot` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night |

## shared

| Line | Event | Owner | Trigger site(s) |
|---|---|---|---|
| `vo.mercer.heist_start_casing_1` | heist_start_casing | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `heist_start_casing` fact to its lines |
| `vo.mercer.heist_start_casing_2` | heist_start_casing | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `heist_start_casing` fact to its lines |
| `vo.mercer.crew_masked_1` | crew_masked | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_masked` fact to its lines |
| `vo.mercer.crew_masked_2` | crew_masked | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_masked` fact to its lines |
| `vo.mercer.pager_started_1` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.mercer.pager_started_2` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.mercer.pager_answered_1` | pager_answered | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_answered` fact to its lines |
| `vo.mercer.pager_answered_2` | pager_answered | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_answered` fact to its lines |
| `vo.mercer.pager_last_answer_1` | pager_last_answer | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_last_answer` fact to its lines |
| `vo.mercer.pager_last_answer_2` | pager_last_answer | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_last_answer` fact to its lines |
| `vo.mercer.pager_limit_1` | pager_limit | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_limit` fact to its lines |
| `vo.mercer.pager_limit_2` | pager_limit | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_limit` fact to its lines |
| `vo.mercer.pager_failed_1` | pager_failed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_failed` fact to its lines |
| `vo.mercer.pager_failed_2` | pager_failed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_failed` fact to its lines |
| `vo.mercer.body_discovered_1` | body_discovered | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `body_discovered` fact to its lines |
| `vo.mercer.body_discovered_2` | body_discovered | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `body_discovered` fact to its lines |
| `vo.mercer.camera_spotted_1` | camera_spotted | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `camera_spotted` fact to its lines |
| `vo.mercer.camera_spotted_2` | camera_spotted | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `camera_spotted` fact to its lines |
| `vo.mercer.device_started_1` | device_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_started` fact to its lines |
| `vo.mercer.device_started_2` | device_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_started` fact to its lines |
| `vo.mercer.device_jammed_1` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.mercer.device_jammed_2` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.mercer.device_finished_1` | device_finished | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_finished` fact to its lines |
| `vo.mercer.device_finished_2` | device_finished | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_finished` fact to its lines |
| `vo.mercer.crew_downed_1` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.mercer.crew_downed_2` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.mercer.crew_custody_1` | crew_custody | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_custody` fact to its lines |
| `vo.mercer.crew_custody_2` | crew_custody | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_custody` fact to its lines |
| `vo.mercer.heist_success_1` | heist_success | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `heist_success` fact to its lines |
| `vo.mercer.heist_success_2` | heist_success | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `heist_success` fact to its lines |
| `vo.mercer.heist_failed_1` | heist_failed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `heist_failed` fact to its lines |
| `vo.mercer.heist_failed_2` | heist_failed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `heist_failed` fact to its lines |
| `vo.mercer.stealth_success_1` | stealth_success | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `stealth_success` fact to its lines |
| `vo.mercer.stealth_success_2` | stealth_success | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `stealth_success` fact to its lines |
| `vo.rook.pager_started_1` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.rook.pager_started_2` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.rook.reloading_1` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.rook.reloading_2` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.rook.device_jammed_1` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.rook.device_jammed_2` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.rook.bagging_body_1` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.rook.bagging_body_2` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.rook.going_loud_1` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.rook.going_loud_2` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.rook.crew_downed_1` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.rook.crew_downed_2` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.rook.reviving_1` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.rook.reviving_2` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.rook.cops_incoming_1` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.rook.cops_incoming_2` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.rook.loot_secured_1` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.rook.loot_secured_2` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.rook.guard_down_1` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.rook.guard_down_2` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.rook.civilian_killed_1` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.rook.civilian_killed_2` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.sable.pager_started_1` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.sable.pager_started_2` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.sable.reloading_1` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.sable.reloading_2` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.sable.device_jammed_1` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.sable.device_jammed_2` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.sable.bagging_body_1` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.sable.bagging_body_2` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.sable.going_loud_1` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.sable.going_loud_2` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.sable.crew_downed_1` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.sable.crew_downed_2` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.sable.reviving_1` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.sable.reviving_2` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.sable.cops_incoming_1` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.sable.cops_incoming_2` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.sable.loot_secured_1` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.sable.loot_secured_2` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.sable.guard_down_1` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.sable.guard_down_2` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.sable.civilian_killed_1` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.sable.civilian_killed_2` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.dutch.pager_started_1` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.dutch.pager_started_2` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.dutch.reloading_1` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.dutch.reloading_2` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.dutch.device_jammed_1` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.dutch.device_jammed_2` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.dutch.bagging_body_1` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.dutch.bagging_body_2` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.dutch.going_loud_1` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.dutch.going_loud_2` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.dutch.crew_downed_1` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.dutch.crew_downed_2` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.dutch.reviving_1` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.dutch.reviving_2` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.dutch.cops_incoming_1` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.dutch.cops_incoming_2` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.dutch.loot_secured_1` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.dutch.loot_secured_2` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.dutch.guard_down_1` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.dutch.guard_down_2` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.dutch.civilian_killed_1` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.dutch.civilian_killed_2` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.wren.pager_started_1` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.wren.pager_started_2` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.wren.reloading_1` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.wren.reloading_2` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.wren.device_jammed_1` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.wren.device_jammed_2` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.wren.bagging_body_1` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.wren.bagging_body_2` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.wren.going_loud_1` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.wren.going_loud_2` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.wren.crew_downed_1` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.wren.crew_downed_2` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.wren.reviving_1` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.wren.reviving_2` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.wren.cops_incoming_1` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.wren.cops_incoming_2` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.wren.loot_secured_1` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.wren.loot_secured_2` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.wren.guard_down_1` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.wren.guard_down_2` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.wren.civilian_killed_1` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.wren.civilian_killed_2` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.marten.pager_started_1` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.marten.pager_started_2` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.marten.reloading_1` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.marten.reloading_2` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.marten.device_jammed_1` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.marten.device_jammed_2` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.marten.bagging_body_1` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.marten.bagging_body_2` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.marten.going_loud_1` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.marten.going_loud_2` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.marten.crew_downed_1` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.marten.crew_downed_2` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.marten.reviving_1` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.marten.reviving_2` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.marten.cops_incoming_1` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.marten.cops_incoming_2` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.marten.loot_secured_1` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.marten.loot_secured_2` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.marten.guard_down_1` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.marten.guard_down_2` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.marten.civilian_killed_1` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.marten.civilian_killed_2` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.jay.pager_started_1` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.jay.pager_started_2` | pager_started | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `pager_started` fact to its lines |
| `vo.jay.reloading_1` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.jay.reloading_2` | reloading | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reloading` fact to its lines |
| `vo.jay.device_jammed_1` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.jay.device_jammed_2` | device_jammed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `device_jammed` fact to its lines |
| `vo.jay.bagging_body_1` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.jay.bagging_body_2` | bagging_body | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `bagging_body` fact to its lines |
| `vo.jay.going_loud_1` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.jay.going_loud_2` | going_loud | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `going_loud` fact to its lines |
| `vo.jay.crew_downed_1` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.jay.crew_downed_2` | crew_downed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `crew_downed` fact to its lines |
| `vo.jay.reviving_1` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.jay.reviving_2` | reviving | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `reviving` fact to its lines |
| `vo.jay.cops_incoming_1` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.jay.cops_incoming_2` | cops_incoming | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `cops_incoming` fact to its lines |
| `vo.jay.loot_secured_1` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.jay.loot_secured_2` | loot_secured | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `loot_secured` fact to its lines |
| `vo.jay.guard_down_1` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.jay.guard_down_2` | guard_down | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `guard_down` fact to its lines |
| `vo.jay.civilian_killed_1` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.jay.civilian_killed_2` | civilian_killed | A | **UNSAID**: nothing says it: no literal id or builder, and no code maps the `civilian_killed` fact to its lines |
| `vo.mercer.abort` | stealth_abort | A | systems/heist/heist_runtime.gd:585<br>systems/heist/heist_runtime.gd:586 |
| `vo.mercer.pager_last` | pager_last_answer | A | systems/stealth/pager_system.gd:287 |
| `vo.mercer.dev_start` | dev_start | A | systems/dev/dev_sandbox_mission.gd:12 |
| `vo.guard.cuff_warning` | cuff_warning | A | systems/stealth/stealth_tweak.gd:264 |
| `vo.crew.ack_follow` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:153 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_hold` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:153 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_carry_bag` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:153 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_drop_bag` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:153 (builder `vo.crew.ack_%s`) |
| `vo.crew.ack_revive` | order_ack | A | systems/ai/crew_ai/crew_ai_brain.gd:153 (builder `vo.crew.ack_%s`) |
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
| `vo.vance.radio_escape_available_1` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_available_2` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_available_3` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_1` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_2` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_escape_3` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with vance on the radio has the fact |
| `vo.vance.radio_loot_secured_1` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.jewelry) via glasshouse (generic)<br>ContactRadio radio.loot_secured (loot.cash) via glasshouse (generic) |
| `vo.vance.radio_loot_secured_2` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.jewelry) via glasshouse (generic)<br>ContactRadio radio.loot_secured (loot.cash) via glasshouse (generic) |
| `vo.vance.radio_loot_secured_3` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.painting_lantern_bearer) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_salt_orchard) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_widow_in_blue) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_tidewater_saint) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.painting_study) via gallery_night (generic)<br>ContactRadio radio.loot_secured (loot.jewelry) via glasshouse (generic)<br>ContactRadio radio.loot_secured (loot.cash) via glasshouse (generic) |
| `vo.reyes.radio_objective_done_1` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_2` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_done_3` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_1` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_2` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_new_3` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_failed_1` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_failed_2` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_objective_failed_3` | radio.objective_failed | R | **UNSAID**: generic radio.objective_failed line: every radio.objective_failed fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
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
| `vo.reyes.radio_escape_available_1` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_available_2` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_available_3` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_1` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_2` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_escape_3` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with reyes on the radio has the fact |
| `vo.reyes.radio_loot_secured_1` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.contraband) via dockside_burn (generic) |
| `vo.reyes.radio_loot_secured_2` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.contraband) via dockside_burn (generic) |
| `vo.reyes.radio_loot_secured_3` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash_bricks) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.weapon_crate) via dockside_burn (generic)<br>ContactRadio radio.loot_secured (loot.contraband) via dockside_burn (generic) |
| `vo.accountant.radio_objective_done_1` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_done_2` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_done_3` | radio.objective_done | R | **UNSAID**: generic radio.objective_done line: every radio.objective_done fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_new_1` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_new_2` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_new_3` | radio.objective_new | R | **UNSAID**: generic radio.objective_new line: every radio.objective_new fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_objective_failed_1` | radio.objective_failed | B | ContactRadio radio.objective_failed [time_lock_wait] via night_deposit (generic) |
| `vo.accountant.radio_objective_failed_2` | radio.objective_failed | B | ContactRadio radio.objective_failed [time_lock_wait] via night_deposit (generic) |
| `vo.accountant.radio_objective_failed_3` | radio.objective_failed | B | ContactRadio radio.objective_failed [time_lock_wait] via night_deposit (generic) |
| `vo.accountant.radio_alarm_1` | radio.alarm | B | ContactRadio radio.alarm via night_deposit (generic) |
| `vo.accountant.radio_alarm_2` | radio.alarm | B | ContactRadio radio.alarm via night_deposit (generic) |
| `vo.accountant.radio_alarm_3` | radio.alarm | B | ContactRadio radio.alarm via night_deposit (generic) |
| `vo.accountant.radio_assault_build_1` | radio.assault_build | B | ContactRadio radio.assault_build via night_deposit (generic) |
| `vo.accountant.radio_assault_build_2` | radio.assault_build | B | ContactRadio radio.assault_build via night_deposit (generic) |
| `vo.accountant.radio_assault_build_3` | radio.assault_build | B | ContactRadio radio.assault_build via night_deposit (generic) |
| `vo.accountant.radio_assault_sustain_1` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via night_deposit (generic) |
| `vo.accountant.radio_assault_sustain_2` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via night_deposit (generic) |
| `vo.accountant.radio_assault_sustain_3` | radio.assault_sustain | B | ContactRadio radio.assault_sustain via night_deposit (generic) |
| `vo.accountant.radio_assault_fade_1` | radio.assault_fade | B | ContactRadio radio.assault_fade via night_deposit (generic) |
| `vo.accountant.radio_assault_fade_2` | radio.assault_fade | B | ContactRadio radio.assault_fade via night_deposit (generic) |
| `vo.accountant.radio_assault_fade_3` | radio.assault_fade | B | ContactRadio radio.assault_fade via night_deposit (generic) |
| `vo.accountant.radio_escape_available_1` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_available_2` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_available_3` | radio.escape_available | R | **UNSAID**: generic radio.escape_available line: every radio.escape_available fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_1` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_2` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_escape_3` | radio.escape | R | **UNSAID**: generic radio.escape line: every radio.escape fact has an always-ready heist line, or no heist with accountant on the radio has the fact |
| `vo.accountant.radio_loot_secured_1` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger (generic) |
| `vo.accountant.radio_loot_secured_2` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger (generic) |
| `vo.accountant.radio_loot_secured_3` | radio.loot_secured | B | ContactRadio radio.loot_secured (loot.cash) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.cash_bricks) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.small_valuables) via night_deposit (generic)<br>ContactRadio radio.loot_secured (loot.ledger_laptop) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_drives) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.ledger_books) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.painting) via shadow_ledger (generic)<br>ContactRadio radio.loot_secured (loot.cash) via shadow_ledger (generic) |
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
