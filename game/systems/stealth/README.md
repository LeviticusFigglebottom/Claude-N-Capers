# Stealth module (ENV A)

`StealthDirector` (service `G.SVC_STEALTH`, child of HeistRuntime) owns detection meters, stimuli,
noise propagation and the alarm. Fidelity rows: S1.1, S1.5, S2.1–S2.8, S3.x, S4.1–S4.4, S11.2.

## Observer protocol
Anything in group `G.OBSERVER` that implements:

| Method | Meaning |
|---|---|
| `observer_kind() -> int` | `Enums.ObserverKind` (GUARD, CIVILIAN, CAMERA, POLICE) |
| `detection_preset` (property) | key into `StealthTweak.observer_presets` |
| `can_observe() -> bool` | false when dead, tied, intimidated, dominated... |
| `eye_position() -> Vector3` | vision origin |
| `look_forward() -> Vector3` | unit view direction (centre of the FOV) |
| `notify_crew_spotted(crew)` | meter on `crew` reached 1.0 ("!") |
| `notify_stimulus(id, kind, pos)` | a stimulus was confirmed (S4.1) |
| `notify_noise(pos, kind, source_net_id)` | a NoiseEvent reached the observer (S4.3; cameras ignore) |

`NpcBase` implements all of these and re-emits them as signals (`crew_spotted`, `stimulus_spotted`,
`noise_heard`) for its brain. Cameras implement the same methods directly.

## Detection (A1-04, server only)
- Meters per (observer, crew slot) in `StealthObserverState` (`stealth_observer_state.gd`), ticked at
  `tick_hz` (10 Hz) with observers staggered across physics frames; each observer integrates its own
  elapsed time (capped at `max_tick_dt_s`).
- S2.1: starts at DR/100 when fill begins, decays `decay_per_s` without fill, stays at 1.0 once full.
  At 1.0: `observer.notify_crew_spotted(crew)`, `crew_detected(observer, crew)`, `crew.set_masked(true)` (S1.2).
- S2.2 rate = `1/min_time × dist_factor × angle_factor × stance × (1/DR_mult) × rule_mult × difficulty.detection_speed_mult`,
  `far' = far/sqrt(DR_mult)`; NPCs use a horizontal sector, cameras a 3D cone. Crouch ×0.75 except cameras (S2.5).
  LOS: rays from the eye to each `los_heights` point (clamped to the crew eye height) on `VISION_MASK`.
- Rules (`rule_mult`): masked → `Modifiers stealth.detection_rate_mult`, everyone fills (S1.4, S2.8).
  Unmasked (S1.1, S3.8) → civilians never; others only in RESTRICTED, or within `casing_too_close_m`
  of a GUARD observer **outside PUBLIC** (`casing_too_close_applies_in_public`, default false), at
  `casing_rate_mult × stealth.casing_detection_rate_mult`.
- Never observed: crew not in `CrewState.NORMAL`, AI crew with `stealth_hidden == true`.
  Observers skipped when `can_observe()` is false (their meters are cleared).
- LOUD (S11.2): all meters cleared, nothing ticks, noise is not propagated.
- `detection_progress(observer_net_id, slot, value, kind)`: EventBus on the peer that owns the crew
  member (host/local), targeted `_rpc_detection_progress` (unreliable_ordered) to a remote human's
  peer, only on change; never for AI. `detection_entries(slot)` gives the same rows on the server.
- Cameras (S3.5): a camera meter reaching 1.0 starts `camera_alarm_delay_s`; it cannot be stopped
  (camera destroyed etc.) and raises `&"camera"`. `camera_countdown()` (-1 = none) is replicated to clients.
- A2-02: observers may expose `detection_overrides() -> Dictionary` merged over their preset
  (SecurityCamera: `fov_deg`, `far` = `range_m`). `start_camera_alarm(camera_net_id)` starts the same
  countdown when a camera confirms a stimulus (S4.4; preset key `camera_alarm: false` opts a kind out).

## Stimuli
`register_stimulus(source: Node3D, kind, data) -> id`; kinds and presets are in
`StealthTweak.stimuli` (corpse, body_bag, bag, broken_glass, drill, alerted_npc, restrained, open_door, broken_camera).
Owners unregister when the stimulus stops existing (bagged body, secured bag, drill finished).
Each observer fills a per-stimulus meter over `fill_time` while range (and, for `los: true` kinds,
FOV + LOS) hold, then `notify_stimulus` + `stimulus_noticed` fire once. Cameras only see kinds with
`camera: true`. Ignored: the observer's own node, `data.hidden == true`, a source with
`hidden_from_stealth == true` (S6.3) or `moved == false` (pre-placed bags, S4.1).

## Noise
`HeistRuntime.make_noise(pos, radius, kind, source_net_id)` → `noise_made` → director → observers
within radius (× `noise_no_los_mult` without LOS from the noise to the eye). Cameras are deaf (S4.4);
only delivered during stealth. **Movement never makes noise (S1.5).**

## Alarm
`raise_alarm(reason, source_net_id)` emits `alarm_raised` [R] once; HeistRuntime goes LOUD (S11.2).
Reasons used: `&"guard_radio"`, `&"civilian_call"`, `&"pager_failed"`, `&"pager_limit"`,
`&"camera"`, `&"alarm_button"`, `&"gunshot"`, `&"laser"`, `&"glass_alarm"` (alarmed display case),
`&"phone_call"` (phone prefab).

## Pagers (S5.2-S5.5)
`PagerSystem` (service `G.SVC_PAGERS`, pager_system.gd): a guard killed or dominated while
`is_stealth()` beeps after rand(2, 4) s (GameRng `&"pagers"`); `PagerInteractable` on the body
(kind `answer_pager`, priority 10, `allow_multiple`). 12 s to start answering (`timeout`), letting
go with nobody else holding (`released`) -> `pager_failed` + `alarm_raised(&"pager_failed")`. The
first completion counts (`pager_answered(id, slot, total)`); total > `max_answers` (4, or the
heist's `pager_max_answers` variant scalar) raises `&"pager_limit"` after completing; Mercer line
`vo.mercer.pager_last` on the last allowed answer. Going loud cancels pending/beeping pagers with
`pager_failed(&"cancelled")` (no extra alarm). `pager_entries()` feeds LocalHudModel;
`blocks_body(guard)` stops body bagging while a pager is pending/beeping.

## Guard cuffs (S3.2 P2, A2-05)
`StealthTweak.guard_cuffs_enabled` (default true; false = P1 radio straight away). A guard reaching
"!" on a crew member that `CrewCuffs.can_cuff` (NORMAL, no cooldown) stays ALARMED with
`GuardBrain.cuff_phase` PAUSE (voice line `cuff_yell_line`, `cuff_pause_s` 5 s) -> APPROACH (walk,
`cuff_approach_timeout_s`) -> CUFFING (`cuff_reach_m`, `cuff_action_s`) -> `CrewCuffs.cuff()` ->
the S3.3 radio call -> `raise_alarm(&"guard_radio")`. The target moving > `cuff_move_tolerance_m`
(1.7 m) from where it was spotted, or firing (`weapon_fired`), raises `&"guard_radio"` at once and the
guard goes to COMBAT. An alarm-reaction stimulus/noise mid-arrest switches to the radio call; killing
or dominating the guard cancels everything. `CrewCuffs` (crew_cuffs.gd, child `Cuffs` of the crew
member, created on first cuff): CrewState.CUFFED, `cuff_cooldown_s` (4 min) per crew member, frees
itself after `cuff_self_free_s` (60 s) or when a teammate holds `UncuffInteractable` (kind `uncuff`,
`uncuff_s`).

## Misfire (S3.7, A2-05)
A guard dying in stealth to a non-head BULLET hit from a non-shotgun weapon misfires with
`misfire_chance` (10%, `GameRng.stream(&"misfire")`): `weapon_fired` + `make_noise(pos,
gunshot_npc_radius_m, &"gunshot", guard net_id)`. Scripted `die()` (no DamageInfo type) never does.

## Marking (S2.9, A2-05)
`mark(target, by_slot)`, `is_marked(target)`, `marked_targets(slot)` -> crew-wide
`[{net_id, world_pos, kind}]` sorted by net_id (kind &"guard", &"special", &"camera"; HUD reads it).
Durations `mark_duration_guard_s` 4.5 / `mark_duration_camera_s` 8 / `mark_duration_special_s` ×
`stealth.mark_duration_mult` of the marker; marks drop when the target dies/is destroyed; works loud
too. Clients get `_rpc_mark`. ShoutSystem marks the target nearest the aim line (`mark_cone_half_deg`,
`mark_range_m`, LOS) when the shout affected no civilian; unmasked crew need
`stealth.casing_can_mark`. The director installs ShoutSystem itself (marking without civilians).
Sixth Sense (`stealth.sixth_sense`): standing still `sixth_sense_still_s` in stealth marks every
guard/special within `sixth_sense_radius_m` (no LOS), repeating while still.
