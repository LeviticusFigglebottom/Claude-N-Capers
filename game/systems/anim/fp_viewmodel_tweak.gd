## First-person viewmodel tunables for FpViewmodel (characters.md v1.3/v1.4, D-041/D-044). Owner: ENV A.
## Data: fp_viewmodel_tweak.tres. Presentation only: nothing here changes gameplay timing.
## `arms_scene`, `fps` and the part travels are ENV D's facts (char_arms_fp/SOURCE.txt); the clip event frames
## are parsed from SOURCE.txt at first use (`events_source`, cached statically), so a new ENV D clip set needs no
## edit here. `extra_events` are ENV A's own ◇ additions merged over them; the rest are ◇ presentation values.
class_name FpViewmodelTweak
extends Resource

const PATH: String = "res://systems/anim/fp_viewmodel_tweak.tres"

static var _cached: FpViewmodelTweak = null
## SOURCE.txt path -> parsed {clip: {event: frame}} (parsed once per path).
static var _parsed: Dictionary = {}
static var _gen: int = 0

@export_group("Arms rig (characters.md v1.3)")
## The `char_arms_fp` scene (root = camera origin, -Z forward). null = static viewmodel fallback.
@export var arms_scene: PackedScene = null
## Helper bones: the WeaponVisual hangs on `weapon_bone`; `magazine_bone` moves the weapon's Magwell.
@export var weapon_bone: StringName = &"weapon"
@export var magazine_bone: StringName = &"magazine"
## Clip frame rate of the event frames below.
@export var fps: float = 30.0
## The arms rig's SOURCE.txt (data reference; its `clip.<set>_<clip>: ... events=a@N,b@M` lines are parsed).
## Empty = "SOURCE.txt" next to `arms_scene`.
@export_file("*.txt") var events_source: String = ""
## Extra ◇ part events not in SOURCE.txt (pistol slide cycle inside fire), merged over the parsed ones:
## {"<set>_<clip>": {event: frame}}.
@export var extra_events: Dictionary = {}

## characters.md v1.8: heister -> sleeve variant scene (`char_arms_fp_<heister>`, mesh only: its `Arms` mesh and
## skin replace the rig's; no entry = the rig's own suit sleeves).
@export var sleeve_scenes: Dictionary[StringName, PackedScene] = {}

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

@export_group("Left hand IK (D-069, characters.md v1.7)")
## The FP left hand IKs (TwoBoneIK3D upper_arm.L -> forearm.L -> hand.L) to the weapon model's `LeftHandIK`
## marker while the clip leaves the left hand on the gun (not during reload / swap, nor for these sets).
@export var left_hand_ik_skip_sets: Array[StringName] = [&"bow", &"akimbo"]
## Elbow pole in skeleton space, relative to upper_arm.L (outward / down) ◇.
@export var left_hand_pole_offset: Vector3 = Vector3(-0.35, -0.45, 0.15)
## hand.L origin (wrist) relative to the LeftHandIK marker (palm contact), in marker space: measured from
## ENV D's baked rifle clip on its four guns (x -0.033..-0.038 constant; y -0.03..+0.017, z = per-gun fore-end).
@export var left_hand_grip_offset: Vector3 = Vector3(-0.035, -0.02, 0.0)
## IK influence blend rate (1/s) when the hand leaves / returns to the grip.
@export var left_hand_ik_rate: float = 8.0

@export_group("Shared reload clips (D-063)")
## A set's single reload / reload_empty clip plays at clip time / the weapon's reload_time_s (reload_empty_time_s).
## Outside this range (before skill multipliers) the weapon needs its own clip: FpViewmodel logs an error.
@export var reload_scale_min: float = 0.75
@export var reload_scale_max: float = 1.35

@export_group("Special parts (B4-18, D-055)")
## WeaponPartsAnimator (◇ presentation): `Breech` opens about local X during a reload.
@export var breech_open_deg: float = 40.0
@export var breech_ramp_s: float = 0.15
## `Lever` throw about local X after each shot, over `lever_cycle_s`.
@export var lever_throw_deg: float = 55.0
@export var lever_cycle_s: float = 0.35
## Bow `StringUpper`/`StringLower` limb flex about local X at full draw; `String` travel along +Z at full draw.
@export var bow_limb_deg: float = 10.0
@export var string_draw_m: float = 0.12
## D-070 crossbow: latched string halves (visual_slots.md): Upper -deg / Lower +deg about local X, both
## stretched along local Y; ramp time of the latch during the reload.
@export var crossbow_latch_deg: float = 18.74
@export var crossbow_latch_stretch: float = 1.3049
@export var crossbow_latch_s: float = 0.4
## `Arrow` / bolt on the Magwell hidden this long after a shot (until the next one is nocked).
@export var arrow_hidden_s: float = 0.3
## `Blade` spin (rev/s) while firing / idle; `Rotor` spin at full minigun spin.
@export var blade_rps_firing: float = 14.0
@export var blade_rps_idle: float = 1.0
@export var rotor_rps_max: float = 9.0

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
## PI-21: share of the camera's step smoothing offset (CrewController.step_offset) the arms add on top, so they
## trail the camera on stairs and curbs instead of riding it rigidly. 0 = off; ADS scales it by `ads_bob_mult`.
@export var step_lag_mult: float = 0.6
## While aimed, shift the arms so the weapon's `AimPoint` sits on the camera axis.
@export var ads_align_aim_point: bool = true
## Viewmodel meshes cast no world shadows.
@export var cast_shadows: bool = false

var _merged: Dictionary = {}
var _merged_path: String = ""
var _merged_extra: int = 0
var _merged_gen: int = -1


static func data() -> FpViewmodelTweak:
	if _cached == null:
		_cached = load(PATH) as FpViewmodelTweak
		if _cached == null:
			_cached = FpViewmodelTweak.new()
	return _cached


## Path of the SOURCE.txt the clip events come from ("" when none is known).
func events_path() -> String:
	if events_source != "":
		return events_source
	if arms_scene != null and arms_scene.resource_path != "":
		return arms_scene.resource_path.get_base_dir().path_join("SOURCE.txt")
	return ""


## Event frames per glb clip "<set>_<clip>": SOURCE.txt (parsed once, cached) with `extra_events` merged over
## it, {clip: {event: frame}}. Every `clip.*` line yields an entry (empty when it has no events).
func clip_events() -> Dictionary:
	var path: String = events_path()
	if _merged_gen == _gen and _merged_path == path and _merged_extra == extra_events.hash():
		return _merged
	var out: Dictionary = {}
	var src: Dictionary = source_events(path)
	for c: Variant in src:
		out[c] = (src[c] as Dictionary).duplicate()
	for c: Variant in extra_events:
		var ev: Dictionary = out.get(StringName(c), {})
		ev.merge(extra_events[c] as Dictionary, true)
		out[StringName(c)] = ev
	_merged = out
	_merged_path = path
	_merged_extra = extra_events.hash()
	_merged_gen = _gen
	return out


## Seconds from the clip start to `event` of glb clip `full_name` ("<set>_<clip>"); -1 when unknown.
func event_s(full_name: StringName, event: StringName) -> float:
	var ev: Dictionary = clip_events().get(full_name, {})
	return float(ev[event]) / maxf(fps, 1.0) if ev.has(event) else -1.0


## Every event of a clip (SOURCE.txt + extras) as {event: seconds}.
func events_s(full_name: StringName) -> Dictionary:
	var out: Dictionary = {}
	var ev: Dictionary = clip_events().get(full_name, {})
	for k: Variant in ev:
		out[k] = float(ev[k]) / maxf(fps, 1.0)
	return out


## Parsed SOURCE.txt at `path` (cached per path; {} when the file is missing).
static func source_events(path: String) -> Dictionary:
	if path == "":
		return {}
	if not _parsed.has(path):
		_parsed[path] = parse_events(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return _parsed[path]


## Parse SOURCE.txt text: each `clip.<name>: <N>f loop=<bool> [events=a@F,b@G]` line gives
## {&"<name>": {&"a": F, ...}} (frames as int, float when fractional). Unknown lines, unknown fields and
## malformed event tokens are ignored, so new sets and new SOURCE.txt keys need no parser change.
static func parse_events(text: String) -> Dictionary:
	var out: Dictionary = {}
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with("clip."):
			continue
		var colon: int = line.find(":")
		if colon <= 5:
			continue
		var clip_name: String = line.substr(5, colon - 5).strip_edges()
		if clip_name == "" or clip_name.contains(" "):
			continue
		var ev: Dictionary = {}
		for field: String in line.substr(colon + 1).split(" ", false):
			if not field.begins_with("events="):
				continue
			for tok: String in field.substr(7).split(",", false):
				var at: int = tok.rfind("@")
				if at <= 0:
					continue
				var frame: String = tok.substr(at + 1)
				if frame.is_valid_int():
					ev[StringName(tok.substr(0, at))] = frame.to_int()
				elif frame.is_valid_float():
					ev[StringName(tok.substr(0, at))] = frame.to_float()
		out[StringName(clip_name)] = ev
	return out


## Drop the parsed SOURCE.txt cache (tests; a rebuilt rig in the editor).
static func clear_event_cache() -> void:
	_parsed.clear()
	_gen += 1
