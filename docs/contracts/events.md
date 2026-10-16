# Contract: EventBus events (v1.7)

Code: `game/core/event_bus.gd` (the signal list there is authoritative; this file adds emitter and
replication rules). Rules: architecture.md §5.

`[R]` = the emitter relays the event to clients with `Net.replicate_event(&"<name>", [args])`.
Unmarked events are server-only facts (clients learn the outcome through synced state).

| Signal | Emitter (owner) | Replicated | Typical consumers |
|---|---|---|---|
| heist_loaded | A: HeistRuntime | [R] | B UI, C music |
| heist_phase_changed | A: HeistRuntime | [R] | B HUD, C music/lighting |
| alarm_raised | A: StealthDirector | [R] | everyone |
| objective_updated | A: HeistMission | [R] | B HUD |
| heist_ended | A: HeistRuntime | [R] | B results |
| crew_member_joined/left | A: CrewManager | [R] | B HUD |
| crew_masked | A: CrewController | [R] | C audio, B HUD |
| crew_downed / revived / custody / traded / tased / cloaker_downed / cuffed / uncuffed | A | [R] | B HUD, C audio/post-FX, voice |
| detection_progress | A: StealthDirector | sent only to the observed crew member's peer (targeted RPC, not EventBus relay) | B HUD |
| npc_alert_state_changed | A | [R] (for "?"/"!" icons) | B HUD, C audio |
| camera_disabled, cameras_loop_disabled | A | [R] | B HUD |
| pager_started / answer_started / answered / failed / answer_released | A: PagerSystem | [R] | B HUD, C audio, voice |
| body_bagged / body_discovered | A | [R] | B HUD |
| ecm_started / ended / feedback_triggered | A | [R] | B HUD, C audio |
| civilian_* , guard_dominated, hostage_count_changed | A | [R] | B HUD, voice |
| interaction_started / cancelled / completed | A: InteractionSystem | [R] | B HUD, C audio |
| device_started / jammed / restarted / finished | A | [R] | B HUD, C audio, voice ("drill's jammed!") |
| item_picked_up, glass_broken, laser_tripped | A | [R] | B HUD, C audio/FX |
| loot_spawned / picked / dropped / secured, small_loot_taken | A: LootManager | [R] | B HUD/results |
| damage_applied | A: Combat | [R] (only for hit markers to attacker; others via sync) | B hitmarkers, C FX |
| npc_killed | A | [R] | B kill feed/stats |
| special_spawned | A: AssaultDirector | [R] | voice ("Wrecker!"), C audio |
| weapon_fired | A | no (audio is triggered locally from synced fire events) | C audio |
| assault_phase_changed | A: AssaultDirector | [R] | B banner, C music |
| captain_arrived / retreated | A | [R] | B HUD, C music |
| assault_event_started / ended | A: AssaultEventRunner | [R] | B HUD, C audio/music, voice |
| voice_line_requested | A/B (anyone) | emitter decides | C voice player, B subtitles |
| audio_cue_requested | anyone | emitter decides | C audio player |

## HeistResult dictionary (heist_ended)
```
{ "heist_id": StringName, "success": bool, "stealth": bool, "time_s": float, "difficulty": int,
  "contract_pay": int (HeistDef.base_payout, UNSCALED; ENV B applies all difficulty/bonus multipliers), "loot": [{ "loot_id": StringName, "value": int }], "small_loot": int,
  "crew": [{ "slot": int, "is_ai": bool, "name": String, "kills": int, "specials_killed": int, "downs": int,
             "civilians_killed": int, "shots": int, "hits": int, "headshots": int,
             "in_custody": bool, "escaped": bool }],   # v1.1 (D-071): name/shots/hits/headshots, ui_hud v1.7 rules
  "pagers_answered": int, "seed": int, "variants": Dictionary,
  "fail_reason": StringName }   # &"" on success; e.g. &"stealth_only_alarm", &"all_custody", &"abort" (D-038)
```

## DamageInfo dictionary
```
{ "amount": float, "type": int (Enums.DamageType), "zone": int (Enums.HitZone), "weapon_id": StringName,
  "position": Vector3, "direction": Vector3, "crit": bool, "pierced_armor": bool, "killed": bool }
```

## Alarm reasons (`alarm_raised(reason, source_net_id)`, D-032)
`&"guard_radio"`, `&"civilian_call"`, `&"phone_call"`, `&"alarm_button"`, `&"glass_alarm"`, `&"pager_failed"`,
`&"pager_limit"`, `&"camera"`, `&"laser"`, `&"scripted"` (mission), `&"loud_action"` (e.g. C4 in view), `&"sensor"` (frame sensors on alarmed loot taken while its AlarmGroups group is live; GN-A1, QC-54).
When the heist goes loud, pending pagers end with `pager_failed(pager_id, &"cancelled")`. That is not an alarm,
and audio/voice must ignore that reason.

## v1.2 (D-105): presentation events
`shot_fx(origin, end, normal, surface, weapon_class, shooter_net_id, flags)` and `explosion_fx(position, radius, kind)` are
**local presentation** signals: ENV A emits them on every peer from the existing shot/explosion replication; ENV C's
VfxDirector and ENV P's viewmodel consume them. Never used for gameplay decisions. Details: impact_fx.md 1.0.

**v1.3 (D-113): blood presentation events** (FX-only, ENV A emits on every peer, ENV C's BloodFx consumes; never gameplay):
`blood_hit(victim_net_id, point, direction, normal, strength, headshot, exit_point, victim_kind)`: a flesh hit after
`damage_applied` (crew: health hits only, not armour); `exit_point` is `Vector3.INF` when the bullet did not exit.
`bleed_changed(body_net_id, bleeding, position, rate)`: NPC death starts (stops when bagged); crew down starts (stops on
revive or custody). Both respect the `gameplay/gore` option (Full / Reduced / Off) on the consuming side.

**v1.4 (D-114 §4): `pager_answer_released(pager_id, crew_slot)` [R].** Only with the opt-in
`StealthTweak.pager_release_resumes = true` (the default is `false`: PO ruling 2026-10-15, an early release with nobody
else answering ends in `pager_failed(pager_id, &"released")` + `alarm_raised(&"pager_failed")`, S5.4). With the opt-in,
PagerSystem emits it when the set of answerers of a beeping pager becomes empty before completion (release, look-away,
going down, leaving) and the response window **resumes** from the value it froze at on `pager_answer_started`. It is not
an alarm and not a failure: the pager keeps beeping. Consumers: C audio swaps the `cue.pager_radio` loop back to
`cue.pager_beep`; B HUD / LocalHudModel show the window counting down again. `crew_slot` is the last answerer who let go.
Juggle emission: see v1.5.

**v1.5 (D-114 §4 as amended, PO6-08): `pager_answer_released` also on a juggle.** PagerSystem (env/a-core 124df071)
emits `pager_answer_released(pager_id, crew_slot)` [R] whenever a released pager **resumes** its window:
* **opt-in resume**: `StealthTweak.pager_release_resumes = true`, emitted at once when the last answerer lets go
  (`crew_slot` = that answerer, `-1` if unknown);
* **juggle resume** (default rules): when the last answerer lets go early, the pager waits `StealthTweak.pager_juggle_window_s`
  (**0.5 s**, window still frozen). If one of the released answerers starts answering **another** live pager inside that
  grace, the released pager resumes and the fact is emitted for it with `crew_slot` = the juggling player, just before
  `pager_answer_started` of the other pager. If nobody juggles, it fails as before (`pager_failed(&"released")` + alarm).
  Picking the **same** pager back up inside the grace just emits `pager_answer_started` (no release fact).
Consumers are unchanged (C audio radio → beep, B HUD window counts down again).
Also (PO6-19, damage.md v1.2): a shot on a corpse emits `blood_hit` with **no** preceding `damage_applied`.

**v1.6 (D-114 §5, PO6-17): RNG assault events.** `assault_event_started(kind, net_id, position)` [R] and
`assault_event_ended(kind, net_id)` [R], emitted by ENV A's AssaultEventRunner (host, child of the AssaultDirector)
when a rolled event begins and when its entity ends (`AssaultEventEntity.end_event()` or the entity leaving the tree),
mirroring the runner's local `event_started` / `event_ended`. A heli drop paired with a ceiling breach emits a second
`started` for that breach. `kind` is one of `AssaultEventsTweak.KINDS`: `&"turret_van"`, `&"heli"`, `&"breach"`. `net_id` is the
event's replicated dynamic entity (AssaultEventEntity; clients spawn it through NetEntityCodec, so the id resolves on every
peer); `position` = van park point / heli hover point (drop) or orbit centre (sniper only) / breach point. Facts only: the entities still emit their own
`audio_cue_requested` (cue.assault_*). Consumers: B HUD/voice callouts ("Turret!", "Chopper!"), C audio/music stingers.


## v1.7: achievement facts (D-115, B's per-heist achievements)
* `HeistResult["loot_available"]` (int, additive): every valued bag the run offered. That means bags that existed (taken
  from a LootSpawn, spawned by the mission or placed in the map) plus whatever is still left in LootSpawns, safe contents
  and unopened ones included. Variant-disabled spawns count 0. Body bags and value-0 tool bags (e.g. thermite) are excluded.
* `objective_updated` data carries `"open_method"` (StringName) before COMPLETED on:
  * GH `safe`: `&"keycard"` / `&"code"` / `&"lockpick"` / `&"drill"` / `&"left_open"` (safe_open variant).
  * SL `cage`: `&"code"` / `&"saw"` / `&"left_open"` (rare variant).
* Every mission completes its `escape` objective on the escape trigger, before `heist_ended`.
