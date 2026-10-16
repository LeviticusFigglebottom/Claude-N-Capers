## PO6-17 (D-114 §5) RNG assault events: tunables + per-heist event rows. Owner: ENV A. Data:
## assault_events_tweak.tres. Until HeistDef carries rows (contract ask, data_schemas.md) this table is the
## source of truth: `heists[heist_id].events` = Array of rows
##   {kind: &"turret_van" | &"heli" | &"breach", weight: float, min_wave: int, cooldown_s: float,
##    max_per_heist: int, params: Dictionary}
## A row's params are merged over kind_defaults[kind] (row wins). ◇ = design value (PD2-shaped).
class_name AssaultEventsTweak
extends Resource

const KIND_TURRET_VAN: StringName = &"turret_van"
const KIND_HELI: StringName = &"heli"
const KIND_BREACH: StringName = &"breach"
const KINDS: Array[StringName] = [KIND_TURRET_VAN, KIND_HELI, KIND_BREACH]

@export_group("Timing")
## Events start in this wave's SUSTAIN (first_event_delay_s after it starts); later waves roll in BUILD and SUSTAIN.
@export var first_event_wave: int = 1
@export var first_event_delay_s: float = 8.0
## Seconds of eligible (BUILD/SUSTAIN) time between rolls.
@export var roll_interval_s: float = 20.0
## Chance an event fires on a roll, by Enums.Difficulty (◇).
@export var chance_per_roll: PackedFloat32Array = PackedFloat32Array([0.35, 0.4, 0.45, 0.5, 0.55, 0.6])
## Minimum seconds between any two events (heist clock).
@export var min_gap_s: float = 30.0
## Events allowed to run at once (a van with a live turret, a heli on station, a breach in its warning).
@export var max_active: int = 2

@export_group("Rope / clips (ENV D PO6-17 clips)")
## ENV D's rope clips hold both fists on a vertical rope at root-space (x 0, z -rope_hand_offset_m), 0.10 m in
## front of the sternum: root = rope point at (root height + sternum height) - facing x rope_hand_offset_m.
## Sternum height above the root: rope_chest_height_m while descending, rope_hang_chest_m while hanging.
@export var rope_chest_height_m: float = 1.4
@export var rope_hang_chest_m: float = 1.7
@export var rope_hand_offset_m: float = 0.225
## One-shot clips (s / m): rappel_land 30 f (touch @6; hands off by f17), van_exit 36 f with a 0.60 m root-motion
## step along -Z, breach_place 45 f (`place` @ 28 f = 0.93 s, palms on a wall 0.45 m ahead), breach_standback
## 30 f side step 0.80 m along -X into a braced crouch (ends on crouch_idle).
@export var rappel_land_s: float = 1.0
@export var van_exit_s: float = 1.2
@export var van_exit_step_m: float = 0.6
@export var breach_place_s: float = 1.5
@export var breach_place_event_s: float = 0.93
@export var breach_place_wall_m: float = 0.45
@export var breach_standback_s: float = 1.0
@export var breach_standback_side_m: float = 0.8
## ENV D root-motion curves (char_anim_humanoid SOURCE.txt `curve.<clip>: root_m=`, metres travelled at each frame
## at root_curve_fps): the guide moves the root along these so the planted feet stay put (P GN-P1 foot slide).
## test_po6_17_root_curves checks them against SOURCE.txt.
@export var root_curve_fps: float = 30.0
@export var breach_standback_curve: PackedFloat32Array = PackedFloat32Array([
	0.0, 0.0, 0.0, 0.0071, 0.0274, 0.0593, 0.101, 0.1509, 0.2074, 0.2689, 0.3336, 0.4, 0.4664, 0.5311, 0.5926,
	0.6491, 0.699, 0.7407, 0.7726, 0.7929, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8])
@export var van_exit_curve: PackedFloat32Array = PackedFloat32Array([
	0.0, 0.0, 0.0, 0.0, 0.0024, 0.0094, 0.0206, 0.0356, 0.0541, 0.0757, 0.1001, 0.1268, 0.1556, 0.1859, 0.2176,
	0.2502, 0.2833, 0.3167, 0.3498, 0.3824, 0.4141, 0.4444, 0.4732, 0.4999, 0.5243, 0.5459, 0.5644, 0.5794,
	0.5906, 0.5976, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6])
## ENV D heli_door_sill: the kneeling sniper's root = SniperSeat x this offset (SniperSeat local basis).
@export var heli_kneel_offset: Vector3 = Vector3(0.5, -0.344, 0.15)

@export_group("Rows")
## heist_id (StringName) -> {"events": Array[Dictionary]} (see the header).
@export var heists: Dictionary = {}
## kind -> default params.
@export var kind_defaults: Dictionary = {}

@export_group("Props")
## Prop scenes under G.PROPS_DIR (ENV C, docs/levels/_art/po6_17/README.md); placeholders are built in code
## when a scene is missing.
@export var van_scene: String = "assault_event/prop_turret_van.tscn"
@export var turret_scene: String = "assault_event/prop_sentry_turret.tscn"
@export var heli_scene: String = "assault_event/prop_police_helicopter.tscn"
## %s = breach kind (wall | window | ceiling).
@export var breach_scene: String = "assault_event/prop_breach_%s.tscn"


## Rows for `heist_id` (empty when the heist has no events).
func rows_for(heist_id: StringName) -> Array[Dictionary]:
	var entry: Variant = heists.get(heist_id, heists.get(String(heist_id), {}))
	if not entry is Dictionary:
		return [] as Array[Dictionary]
	return valid_rows((entry as Dictionary).get("events", []) as Array)


## The rows of `arr` with a known kind (HeistDef.assault_events and the tweak table share the schema).
static func valid_rows(arr: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in arr:
		if r is Dictionary and KINDS.has(StringName((r as Dictionary).get("kind", &""))):
			out.append(r as Dictionary)
	return out


func chance_for(difficulty: int) -> float:
	if chance_per_roll.is_empty():
		return 0.0
	return chance_per_roll[clampi(difficulty, 0, chance_per_roll.size() - 1)]


## kind_defaults[kind] with `row.params` merged over it.
func params_for(row: Dictionary) -> Dictionary:
	var kind: StringName = StringName(row.get("kind", &""))
	var p: Dictionary = (kind_defaults.get(kind, kind_defaults.get(String(kind), {})) as Dictionary).duplicate(true)
	p.merge(row.get("params", {}) as Dictionary, true)
	return p


static func data() -> AssaultEventsTweak:
	return load("res://systems/director/assault_events_tweak.tres") as AssaultEventsTweak
