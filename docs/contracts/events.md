# Contract: EventBus events (v1.0)

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
| crew_downed / revived / custody / traded / tased / cloaker_downed | A | [R] | B HUD, C audio/post-FX, voice |
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
  "contract_pay": int, "loot": [{ "loot_id": StringName, "value": int }], "small_loot": int,
  "crew": [{ "slot": int, "is_ai": bool, "kills": int, "specials_killed": int, "downs": int,
             "civilians_killed": int, "in_custody": bool, "escaped": bool }],
  "pagers_answered": int, "seed": int, "variants": Dictionary }
```

## DamageInfo dictionary
```
{ "amount": float, "type": int (Enums.DamageType), "zone": int (Enums.HitZone), "weapon_id": StringName,
  "position": Vector3, "direction": Vector3, "crit": bool, "pierced_armor": bool, "killed": bool }
```
