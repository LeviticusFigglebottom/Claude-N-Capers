## First-person viewmodel tunables for FpViewmodel (characters.md v1.3/v1.4, D-041/D-044). Owner: ENV A.
## Data: fp_viewmodel_tweak.tres. Presentation only: nothing here changes gameplay timing.
## `arms_scene`, `fps`, `clip_events` and the part travels are ENV D's facts (char_arms_fp/SOURCE.txt,
## test-checked against it); the rest are ◇ presentation values.
class_name FpViewmodelTweak
extends Resource

const PATH: String = "res://systems/anim/fp_viewmodel_tweak.tres"

static var _cached: FpViewmodelTweak = null

@export_group("Arms rig (characters.md v1.3)")
## The `char_arms_fp` scene (root = camera origin, -Z forward). null = static viewmodel fallback.
@export var arms_scene: PackedScene = null
## Helper bones: the WeaponVisual hangs on `weapon_bone`; `magazine_bone` moves the weapon's Magwell.
@export var weapon_bone: StringName = &"weapon"
@export var magazine_bone: StringName = &"magazine"
## Clip frame rate of the event frames below.
@export var fps: float = 30.0
## Event frames per glb clip name "<set>_<clip>" (SOURCE.txt `clip.*` lines): {event: frame}.
@export var clip_events: Dictionary = {}
## Extra ◇ part events not in SOURCE.txt (pistol slide cycle inside fire): same shape.
@export var extra_events: Dictionary = {}

@export_group("Part travel (characters.md v1.4)")
## Pistol `Slide` travel along its local +Z when locked back / cycling (◇, not in the contract).
@export var slide_travel_m: float = 0.028
## Shotgun `Pump` travel along local +Z.
@export var pump_travel_m: float = 0.075
## Sniper `Bolt`: handle lift about its local Z (bore axis), then slide along local +Z.
@export var bolt_lift_deg: float = 62.0
@export var bolt_travel_m: float = 0.075
## LMG `FeedCover`: opens about its local X (rear hinge pivot).
@export var feed_cover_deg: float = 78.0
## Frames a part takes to reach the position its event names (the ramp ends on the event frame).
@export var part_ramp_frames: float = 3.0

@export_group("Timing")
## Crossfade between idle / ads_idle / sprint.
@export var blend_s: float = 0.15
## Crossfade into one-shots (fire, reload, draw, holster).
@export var oneshot_blend_s: float = 0.04
## Share of the gameplay equip time spent on the old weapon's holster (the rest is the draw).
@export var holster_share: float = 0.4
## ADS weight rate (1/s toward the target).
@export var ads_rate: float = 10.0

@export_group("Motion")
## Horizontal speed (m/s) above which walk bob / sprint play.
@export var move_threshold_mps: float = 0.3
## Walk bob amplitude (m) at `bob_ref_speed_mps`, x = side, y = vertical; frequency of one step pair.
@export var bob_amplitude: Vector2 = Vector2(0.008, 0.006)
@export var bob_frequency_hz: float = 1.0
@export var bob_ref_speed_mps: float = 3.5
## Bob multiplier while fully aimed down sights.
@export var ads_bob_mult: float = 0.2
## Bob amplitude response rate (1/s) when starting / stopping.
@export var bob_rate: float = 8.0
## While aimed, shift the arms so the weapon's `AimPoint` sits on the camera axis.
@export var ads_align_aim_point: bool = true
## Viewmodel meshes cast no world shadows.
@export var cast_shadows: bool = false


static func data() -> FpViewmodelTweak:
	if _cached == null:
		_cached = load(PATH) as FpViewmodelTweak
		if _cached == null:
			_cached = FpViewmodelTweak.new()
	return _cached


## Seconds from the clip start to `event` of glb clip `full_name` ("<set>_<clip>"); -1 when unknown.
func event_s(full_name: StringName, event: StringName) -> float:
	for src: Dictionary in [clip_events, extra_events]:
		var ev: Dictionary = src.get(full_name, {})
		if ev.has(event):
			return float(ev[event]) / maxf(fps, 1.0)
	return -1.0


## Every event of a clip (SOURCE.txt + extras) as {event: seconds}.
func events_s(full_name: StringName) -> Dictionary:
	var out: Dictionary = {}
	for src: Dictionary in [clip_events, extra_events]:
		var ev: Dictionary = src.get(full_name, {})
		for k: Variant in ev:
			out[k] = float(ev[k]) / maxf(fps, 1.0)
	return out
