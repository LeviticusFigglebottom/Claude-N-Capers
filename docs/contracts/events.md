# Contract: EventBus events (v1.2)

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
| pager_started / answer_started / answered / failed | A: PagerSystem | [R] | B HUD, C audio, voice |
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
`&"pager_limit"`, `&"camera"`, `&"laser"`, `&"scripted"` (mission), `&"loud_action"` (e.g. C4 in view).
When the heist goes loud, pending pagers end with `pager_failed(pager_id, &"cancelled")`. That is not an alarm,
and audio/voice must ignore that reason.

## v1.2 (D-105): presentation events
`shot_fx(origin, end, normal, surface, weapon_class, shooter_net_id, flags)` and `explosion_fx(position, radius, kind)` are
**local presentation** signals: ENV A emits them on every peer from the existing shot/explosion replication; ENV C's
VfxDirector and ENV P's viewmodel consume them. Never used for gameplay decisions. Details: impact_fx.md 1.0.
