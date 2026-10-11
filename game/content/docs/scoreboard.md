# Tab scoreboard and payday awards (B6-02)

Owner: ENV B. Code: `progression/crew_stats.gd` (`CrewStats`), `progression/heist_awards.gd` (`HeistAwards`),
`progression/heist_award_table.gd` + `data/ui/heist_awards.tres` (`HeistAwardTable`),
`ui/hud/widgets/scoreboard_overlay.gd` (`ScoreboardOverlay`, `Hud.scoreboard`), payday section in
`ui/results/payday.gd`. Tests: `tests/b/test_heist_awards.gd`, `tests/b/test_ui_scoreboard.gd`.

## Crew stat rows
One row per crew member, Crew AI included. Keys are Strings named as in HeistResult.crew (events.md):

| Key | Type | Source today |
|---|---|---|
| `slot` | int | HeistResult / HeistRuntime |
| `name` | String | not in HeistResult (payday falls back to `Net.crew[slot].display_name`, then "Crew AI n" / "Heister n") |
| `is_ai` | bool | HeistResult |
| `is_local` | bool | scoreboard only (fallback: `slot == Net.local_slot()`) |
| `kills`, `specials_killed`, `civilians_killed`, `downs` | int | HeistRuntime `_stats` (server) -> HeistResult |
| `shots`, `hits`, `headshots` | int | **do not exist yet** (QB to ENV A) |

A missing key means "not tracked": the scoreboard shows "—" in that cell and the award over it is skipped.
It is detected per row (`CrewStats.has_stat`), so a mixed build (some rows with counters) works.
`accuracy` is derived = hits / shots, defined only when both exist and shots > 0.

## Fields expected from ENV A (QB)
`LocalHudModel.crew_stats: Array[Dictionary]` (rows above, every crew member, `is_local` on the tracked
member) + `signal crew_stats_changed()`, assigned as a new Array on change (ui_hud.md v1.1 rule), on every
peer (server counts, clients get the replicated values). HeistResult.crew rows gain `name`, `shots`, `hits`,
`headshots`. Counting rules proposed: a shot = one trigger pull of a firearm (a shotgun blast is 1 shot; melee,
throwables, deployables and sentries are not shots); a hit = a shot that damaged at least one enemy NPC (once
per shot, so hits <= shots; civilians, cameras and props do not count); a headshot = a shot whose hit landed on
`HitZone.HEAD` of an enemy NPC (once per shot). Until it lands `MockHudModel` carries `crew_stats` and the
overlay lists the local player + `crew` teammates with every counter "—" on the real model.

## Overlay
`ScoreboardOverlay` (a `HudWidget`): title, then Crew | Kills | Specials | Civilians | Downs | Accuracy |
Headshots. Rows by slot; the local row reads "{name} (you)" in the palette's `interaction_color`, teammates in
`ally_color`, AI rows get "[AI]". Visible while the `scoreboard` action is held; `controls/scoreboard_mode =
"toggle"` (Options > Controls) flips it per press instead. It rebuilds only while shown.

## Awards
`HeistAwards.compute(result.crew)` over `HeistAwardTable` entries `{id, stat, rule, threshold?, min_shots?}`:

| Id | Name (strings) | Rule |
|---|---|---|
| `most_kills` | Body Count | max `kills`, >= 1 |
| `most_specials` | Giant Slayer | max `specials_killed`, >= 1 |
| `most_accurate` | Steady Hand | max accuracy among rows with >= 20 shots |
| `most_headshots` | Between the Eyes | max `headshots`, >= 1 |
| `iron` | Iron Spine | min `downs`, <= 1 |
| `civilian_friendly` | Clean Hands | shared by every member with 0 `civilians_killed` |

* Candidates = rows carrying the stat; none -> no award (accuracy / headshots are skipped until A sends them).
* `max` / `min`: one winner. **Tie-break: human players before Crew AI, then the lowest crew slot**
  (`HeistAwards.tie_break_less`); input order never matters.
* `zero`: every candidate at 0 wins, listed by slot; nobody at 0 -> no award.
* Payday shows "Crew Honours": award name | winners | description with `{value}` (accuracy as %);
  "No honours handed out this time." when none.
Strings: `ui.scoreboard.*`, `ui.awards.title`, `ui.awards.none`, `ui.awards.<id>.name|desc`.
