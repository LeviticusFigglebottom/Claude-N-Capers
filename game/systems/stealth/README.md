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

## Stimuli
`register_stimulus(source: Node3D, kind, data) -> id`; kinds and presets are in
`StealthTweak.stimuli` (corpse, body_bag, bag, broken_glass, drill, alerted_npc, restrained, open_door).
Owners unregister when the stimulus stops existing (bagged body, secured bag, drill finished).

## Noise
`HeistRuntime.make_noise(pos, radius, kind, source_net_id)` → `noise_made` → director → observers
within radius (× `noise_no_los_mult` without LOS). **Movement never makes noise (S1.5).**

## Alarm
`raise_alarm(reason, source_net_id)` emits `alarm_raised` [R] once; HeistRuntime goes LOUD (S11.2).
Reasons used: `&"guard_radio"`, `&"civilian_call"`, `&"pager_failed"`, `&"pager_limit"`,
`&"camera"`, `&"alarm_button"`, `&"gunshot"`, `&"laser"`.
