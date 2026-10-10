# LocalHudModel (A1-11). Owner: ENV A

Contract: `docs/contracts/ui_hud.md`. Code: `local_hud_model.gd` (`class_name LocalHudModel`).

HeistRuntime creates one `LocalHudModel` child (named `LocalHudModel`, also `HeistRuntime.hud_model`)
on **every peer**. ENV B HUD scenes bind **only** to this node and to EventBus.

- Read-only: every property below is state for display. Do not assign to it (that skips notification).
- Tracks the **local** crew member (`Net.local_slot()`). Set `tracked_slot` (int, -1 = local) for
  spectating or tests; `tracked_slot_resolved` is the slot actually shown.
- Never reads Input and never mutates game state, so it works the same on host and clients.
- `snapshot() -> Dictionary` returns every property by name (copies). `refresh()` polls now.
- Exports (presentation tuning): `poll_hz` (10), `pager_window_s` (12), `pager_answer_s` (10),
  `detection_stale_s` (1), `special_warning_range_m` (25).

## Signals

| Signal | Fires when |
|---|---|
| `changed(property: StringName)` | any property below changed value (arrays/dicts compared deeply) |
| `health_changed(health: float, max_health: float)` | `health` or `max_health` changed |
| `armor_changed(armor: float, max_armor: float)` | `armor` or `max_armor` changed |
| `interaction_changed()` | prompt key, progress, blocked reason or suspicious flag changed |
| `detection_changed()` | `detection_indicators` changed |
| `objectives_changed()` | `objectives` changed |
| `pager_timers_changed()` | `pager_timers` changed (also every poll while a timer counts down) |
| `assault_changed(phase: int, wave: int)` | `assault_phase` or `assault_wave` changed |
| `teammates_changed()` | `teammates` changed |

Timers (`bleedout_time_left`, `pager_timers[].time_left`, `ecm_time_left`, `camera_countdown`) change
every poll while they run, so expect `changed` at ~10 Hz for them. Interpolate locally if you want
smoother bars.

## Properties

"poll" = read from HeistRuntime at `poll_hz` (~10 Hz). "event" = updated immediately by EventBus.
"stub" = the source system does not exist yet; the default shown is what you get today.

| Name | Type | Meaning | Source | Update |
|---|---|---|---|---|
| `tracked_slot_resolved` | int | crew slot shown, -1 = none | `tracked_slot` / `Net.local_slot()` | poll |
| `health` | float | current health (PD2 display units) | `crew.health.health`; stub `Tweak.crew().base_health` (230) | poll |
| `max_health` | float | max health | `crew.health.max_health`; stub 230 | poll |
| `armor` | float | current armor | `crew.health.armor`; stub `default_armor` (20) | poll |
| `max_armor` | float | max armor | `crew.health.max_armor`; stub 20 | poll |
| `downs_left` | int | downs before custody (L2.6) | `crew.health.downs_left`; stub `downs_before_custody` + `defense.downs_extra` | poll |
| `crew_state` | Enums.CrewState | NORMAL / DOWNED / TASED / ... | `CrewController.crew_state` | poll |
| `bleedout_time_left` | float | seconds of bleedout left (L2.5), 0 if not downed | `crew.health.bleedout_left`; stub 0 | poll |
| `ammo_mag` | Dictionary[int, int] | rounds in mag, keys `Enums.WeaponSlot.PRIMARY`/`SECONDARY` | `crew.weapons.mag(slot)`; stub 0 | poll |
| `ammo_reserve` | Dictionary[int, int] | reserve rounds, same keys | `crew.weapons.reserve(slot)`; stub 0 | poll |
| `equipped_slot` | Enums.WeaponSlot | equipped weapon slot | `crew.weapons.equipped_slot`; stub PRIMARY | poll |
| `deployable_count` | int | deployables left | `crew.weapons.deployable_count`; stub 0 | poll |
| `throwable_count` | int | throwables left | `crew.weapons.throwable_count`; stub 0 | poll |
| `cable_ties` | int | cable ties left | `CrewController.cable_ties` | poll |
| `body_bags` | int | body bags left | `CrewController.body_bags` | poll |
| `carried_bag_loot_id` | StringName | loot id of carried bag, `&""` = none | `crew.carried_bag.loot_id` | poll |
| `carried_bag_weight` | int | Enums.LootWeight of carried bag, -1 = none | `crew.carried_bag.weight` | poll |
| `interaction_prompt_key` | StringName | en.csv key of active or aimed interaction, `&""` = none | active session comp, else `InteractionSystem.aimed_component(crew).prompt_key` | poll |
| `interaction_progress` | float | 0..1 hold progress (S9.1) | `InteractionSystem.progress(slot)` | poll |
| `interaction_blocked_reason` | StringName | `InteractableComponent.BLOCK_*` key (`ui.blocked.*`), `&""` = ok | `InteractionSystem.blocked_reason(slot)`, else aimed comp `availability(crew)` | poll |
| `suspicious_action_blocked` | bool | S1.1 "Suspicious actions not allowed" should show | blocked reason == `ui.blocked.casing`, or casing and intent asks crouch/sprint/jump/deploy/throw/melee | poll |
| `suspicious_action_prompt_key` | StringName | `ui.prompt.suspicious_not_allowed` while blocked, else `&""` | constant | poll |
| `detection_indicators` | Array[Dictionary] | `{observer_net_id: int, world_pos: Vector3, value: float 0..1, kind: int Enums.ObserverKind}` sorted by observer id. Colors per S2.1: blue < 0.5, orange >= 0.5, red "!" at 1.0 | `detection_progress` filtered to the tracked slot; dropped at value 0 or after `detection_stale_s` without an update; `world_pos` refreshed each poll | event + poll |
| `marked_targets` | Array[int] | net ids of marked enemies/cameras | stealth service `marked_targets(slot)`; stub [] | poll |
| `pager_timers` | Array[Dictionary] | `{pager_id: int, guard_net_id: int, time_left: float, answering: bool, world_pos: Vector3}` (S5.2) | pager service `pager_entries()` if present, else `pager_started/answer_started/answered/failed` with a local countdown (12 s window, 10 s answer) | event + poll |
| `ecm_time_left` | float | longest running ECM, seconds (0 = none) | `ecm_started(duration)` / `ecm_ended`, local countdown | event + frame |
| `camera_countdown` | float | camera countdown seconds, < 0 = none | stealth service `camera_countdown()`; stub -1 | poll |
| `objectives` | Array[Dictionary] | `{id: StringName, text_key: StringName, state: int Enums.ObjectiveState, data: Dictionary, order: int}` in creation order | host: `HeistMission.objectives()` (+ `objectives_changed`); clients: `objective_updated` [R] | event + poll |
| `assault_phase` | Enums.AssaultPhase | NONE while stealth (L1.7 banner) | `assault_phase_changed` | event |
| `assault_wave` | int | wave index | `assault_phase_changed` | event |
| `hostages` | int | hostage count | `hostage_count_changed` | event |
| `phantom_warning` | bool | a living Phantom is within `special_warning_range_m` | `special_spawned(&"phantom")` / `npc_killed` + distance | poll |
| `stinger_warning` | bool | a living Stinger is within range, or the tracked crew is TASED | `special_spawned(&"stinger")` / `npc_killed` + distance | poll |
| `teammates` | Array[Dictionary] | other crew by slot: `{slot: int, name: String, health_frac: float, armor_frac: float, state: int Enums.CrewState, downs_left: int, carried_bag_loot_id: StringName, is_ai: bool}` | `HeistRuntime.crew_members()` (+ health component, stub 1.0) | poll |
| `masked` | bool | masked up (S1.2) | `CrewController.masked`, `crew_masked` | event + poll |
| `casing` | bool | casing mode (S1.1) = `not masked` | same | event + poll |
| `mask_progress` | float | 0..1 mask-up hold | `CrewController.mask_progress` | poll |
| `heist_phase` | Enums.HeistPhase | LOADING / CASING / STEALTH / LOUD / ESCAPE / ENDED | `HeistRuntime.phase`, `heist_phase_changed` | event + poll |

## Duck-typed sources (for the combat, weapons and stealth implementers)

The header of `local_hud_model.gd` is the authoritative list. In short:
`crew.health` {health, max_health, armor, max_armor, downs_left, bleedout_left},
`crew.weapons` {mag(slot), reserve(slot), equipped_slot, deployable_count, throwable_count},
`crew.carried_bag` {loot_id, weight}, pager service `pager_entries()`, stealth service
`marked_targets(slot)` and `camera_countdown()`. Members may be properties or methods.

## Known gaps

- Interaction progress/blocked reason come from server-side `InteractionSystem` state; on a remote
  client they stay 0/empty until per-crew interaction replication lands.
- Health, weapons, marked targets and camera countdown use the stub defaults until A1-08 and the
  stealth director provide the members above.
