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

## Stimuli
`register_stimulus(source: Node3D, kind, data) -> id`; kinds and presets are in
`StealthTweak.stimuli` (corpse, body_bag, bag, broken_glass, drill, alerted_npc, restrained, open_door).
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
`&"camera"`, `&"alarm_button"`, `&"gunshot"`, `&"laser"`.
