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
	var out: Array[Dictionary] = []
	var entry: Variant = heists.get(heist_id, heists.get(String(heist_id), {}))
	if not entry is Dictionary:
		return out
	for r: Variant in (entry as Dictionary).get("events", []):
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
