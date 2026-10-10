# LocalHudModel (A1-11). Owner: ENV A

Contract: `docs/contracts/ui_hud.md` v1.1, section "exact binding shape (D-024)", plus v1.2 (D-043: `custody`, `track()`).
Code: `local_hud_model.gd` (`class_name LocalHudModel`).

HeistRuntime creates one `LocalHudModel` child (named `LocalHudModel`, also `HeistRuntime.hud_model`)
on **every peer**. It joins group `G.LOCAL_HUD_MODEL` in `_ready` (exactly one per peer). ENV B's HUD
binds **only** to this node and EventBus: it reads properties with `get()` and connects the signals
below by name.

- Read-only: never assign the properties from outside.
- Every change **assigns a new Array/Dictionary** (never mutates in place), then the group signal
  fires **once** per batch. All contract signals take no arguments.
- Tracks the **local** crew member (`Net.local_slot()`). Set `tracked_slot` (int, -1 = local) for
  spectating or tests.
- **`tracked_crew` mode (QB-48, ui_hud v1.2)**: `track(crew: Node)` (a CrewController) (or set `tracked_crew`) binds one crew
  member directly, with or without a HeistRuntime, e.g. the firing range: add a `LocalHudModel` node
  anywhere in the range scene and call `track(crew)` with the node `CrewController.spawn_for_range()`
  returned. It wins over `tracked_slot`; `track(null)` returns to slot mode (a freed crew member does
  too). The binding shape (properties, signals, group `G.LOCAL_HUD_MODEL`) is unchanged. Without a
  runtime, vitals/ammo/inventory/mask/warnings update from the crew member; runtime-backed properties
  (objectives, crew, pagers, interaction, detection, assault) keep their defaults.
- Never reads Input and never mutates game state, so host and clients behave the same.
- `snapshot() -> Dictionary` returns every property (copies). `refresh()` polls now and emits.
- Extra debug signal `changed(property: StringName)` fires per changed property.
- Exports (presentation tuning): `poll_hz` (10), `detection_stale_s` (1), `special_warning_range_m` (25).

## Binding table

"poll" = read from HeistRuntime at `poll_hz` (~10 Hz). "event" = updated immediately from EventBus.
"stub" = the default you get until the source system lands.

| Signal | Property | Type / shape | Source |
|---|---|---|---|
| `vitals_changed` | `health`, `max_health`, `armor`, `max_armor` | float (PD2 units) | `crew.health.*`; stub `Tweak.crew()` 230 / 20 (poll) |
| | `downs_left` | int | `crew.health.downs_left`; stub `downs_before_custody` + `defense.downs_extra` (poll) |
| | `crew_state` | Enums.CrewState | `CrewController.crew_state` (poll) |
| | `bleedout_s` | float, < 0 = not bleeding out | `crew.health.bleedout_left`; stub -1 (poll) |
| `ammo_changed` | `ammo` | `{Enums.WeaponSlot: {"mag": int, "reserve": int}}` for PRIMARY, SECONDARY | `crew.weapons.mag(slot)/reserve(slot)`; stub 0 (poll) |
| | `equipped_slot` | int (Enums.WeaponSlot) | `crew.weapons.equipped_slot`; stub PRIMARY (poll) |
| `inventory_changed` | `deployable_id`, `throwable_id` | StringName | `crew.weapons.*_id`, else `crew.loadout.deployable/throwable` (poll) |
| | `deployable_count`, `throwable_count` | int | `crew.weapons.*_count`; stub 0 (poll) |
| | `cable_ties`, `body_bags` | int | `CrewController` (poll) |
| `carried_bag_changed` | `carried_bag` | `{}` or `{"loot_id": StringName, "weight": int}` | `crew.carried_bag.loot_id/weight` (poll) |
| `interaction_changed` | `interaction` | `{}` or `{"text_key", "args": Dictionary, "progress": 0..1, "blocked_reason": StringName}` | active session or `InteractionSystem.aimed_component(crew)`: `prompt_key`, optional `prompt_args`, `progress(slot)`, `blocked_reason(slot)` / `availability(crew)`. S1.1: `ui.prompt.suspicious_not_allowed` as blocked_reason while casing and a casing-blocked interaction or crouch/sprint/jump/deploy/throw/melee intent (poll) |
| `detection_changed` | `detection` | `[{"observer_net_id", "world_pos": Vector3, "value": 0..1, "kind": Enums.ObserverKind}]`, value > 0, sorted by observer id | host: `StealthDirector.detection_entries(slot)` (poll); clients: `detection_progress` filtered to the tracked slot, dropped at 0 or after 1 s silence (event) |
| `marked_targets_changed` | `marked_targets` | `[{"net_id", "world_pos": Vector3, "kind": StringName}]` | stealth `marked_targets(slot)` (ids or dicts; kind defaults to the node's `role`); stub [] (poll) |
| `pagers_changed` | `pagers` | `[{"pager_id", "time_left_s", "answering", "progress": 0..1}]` | pager service `pager_entries()`; fallback `pager_started/answer_started/answered/failed` with a local countdown from `Tweak.stealth()` (12 s window, 10 s × `stealth.pager_answer_speed_mult` answer) (event + poll) |
| | `pagers_answered` | int | pager service `pagers_answered`, else `pager_answered` total (event) |
| | `pagers_max` | int | pager service `pagers_max`, else `Tweak.stealth().pager_max_answers` (4) |
| `timers_changed` | `ecm_time_left_s` | float, < 0 = none | `ecm_started(duration)` / `ecm_ended`, local countdown (event + frame) |
| | `camera_alarm_s` | float, < 0 = inactive | `StealthDirector.camera_countdown()` (poll) |
| `objectives_changed` | `objectives` | `[{"id", "text_key", "args": Dictionary, "state": Enums.ObjectiveState}]` in creation order, HIDDEN omitted | host: `HeistMission.objectives()` (`data` → `args`) + `objectives_changed`; clients: `objective_updated` [R] |
| `assault_changed` | `assault_phase`, `assault_wave` | int (Enums.AssaultPhase), int | `assault_phase_changed` (event) |
| `hostages_changed` | `hostages` | int | `hostage_count_changed` (event) |
| `warnings_changed` | `warnings` | Array[StringName] (`&"phantom"`, `&"stinger"`) | living special from `special_spawned` within 25 m; stinger also while TASED (poll) |
| `crew_changed` | `crew` | teammates only, by slot: `[{"slot", "name", "is_ai", "health_frac", "armor_frac", "state", "downs_left", "carried_loot_id"}]` | `HeistRuntime.crew_members()` + `crew.health` (stub fracs 1.0) (poll) |
| `masked_changed` | `masked`, `casing` | bool (`casing` = not masked) | `CrewController.masked`, `crew_masked` (event + poll) |
| `custody_changed` (v1.2) | `custody` | `{}` or `{"in_custody": true, "negotiation_left_s": float (0 = trade ready), "auto_release_left_s": float (< 0 = trade only), "highlighted_hostage_net_id": int (0 = none)}` | runtime service `&"custody"` (`CustodySystem.in_custody/negotiation_left/auto_release_left(slot)`, `highlighted_hostage().net_id`), server; clients without the service: `{in_custody: true, -1, -1, 0}` while `crew_state == CUSTODY` (poll) |

Extras (no contract signal, only `changed`): `tracked_slot_resolved`, `mask_progress`, `heist_phase`.

Timers (`bleedout_s`, `custody.*_left_s`, `pagers[].time_left_s`, `ecm_time_left_s`, `camera_alarm_s`) change every poll
while they run, so their signals fire at ~10 Hz. Interpolate locally for smooth bars.

## Duck-typed sources

The header of `local_hud_model.gd` is the authoritative list: `crew.health`, `crew.weapons`,
`crew.carried_bag`, `InteractableComponent.prompt_args`, the pager service (`pager_entries()`,
`pagers_answered`, `pagers_max`) and the stealth director (`detection_entries(slot)`,
`marked_targets(slot)`, `camera_countdown()`). Members may be properties or methods.

## Known gaps

- Co-op (A3-07): custody timers + the highlighted hostage, interaction progress/blocked reason per
  crew slot, known codes and crew vitals/inventory are mirrored to clients by `HeistNetSync`
  (heist/README.md "Co-op"), so the table above holds on clients too, at the 15 Hz sync rate. Remote
  clients still have no prompt for interactables the server adds at runtime (corpse bagging, hostage
  trade) and the deployable inventory rows come from `crew.weapons` only.
- `interaction.args` is `{}` unless the component exposes `prompt_args`; the input key name
  (e.g. `{"key": "F"}`) is presentation and left to ENV B.
