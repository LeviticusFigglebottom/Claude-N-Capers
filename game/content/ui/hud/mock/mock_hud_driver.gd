## Scripted demo driver for MockHudModel: loops a ~40 s timeline through casing, detection, a
## pager, going loud, assault phases, Commander Brandt (captain), sprint stamina (drain, exhausted,
## recovery; ui_hud v1.4), damage and downs, and the B6-02 scoreboard tally, so every HUD widget is exercised.
## Deterministic (time-based, no RNG). Owner: ENV B. Used by hud_demo.tscn.
class_name MockHudDriver
extends Node

const LOOP_S: float = 40.0

@export var model_path: NodePath
@export var playing: bool = true

var model: MockHudModel
var t: float = 0.0
var _stage: int = -1


func _ready() -> void:
	model = get_node_or_null(model_path) as MockHudModel
	if model != null:
		setup_initial()


## Static loadout-ish state (also used by tests to fill every field once).
func setup_initial() -> void:
	model.max_health = 230.0
	model.health = 230.0
	model.max_armor = 30.0
	model.armor = 30.0
	model.downs_left = 3
	model.ammo = {Enums.WeaponSlot.SECONDARY: {"mag": 17, "reserve": 136}}
	model.equipped_slot = Enums.WeaponSlot.SECONDARY
	model.deployable_id = &"deployable.doctor_bag"
	model.deployable_count = 1
	model.cable_ties = 2
	model.body_bags = 1
	model.casing = true
	model.masked = false
	model.player_mode = &"casing"
	model.objectives = [
		{"id": &"casing", "text_key": &"objective.glasshouse.casing", "args": {}, "state": Enums.ObjectiveState.ACTIVE},
	]
	model.crew = [
		_mate(1, "crew.sable", 1.0, 1.0, Enums.CrewState.NORMAL),
		_mate(2, "crew.dutch", 0.8, 0.0, Enums.CrewState.NORMAL),
		_mate(3, "crew.wren", 1.0, 0.5, Enums.CrewState.NORMAL),
	]
	model.crew_stats = stats_rows(0)


## B6-02 scoreboard rows after `fights` loud stages: the local player (slot 0) has the full counter set;
## the Crew AI rows lack shots / hits / headshots, like ENV A's tree today (scoreboard shows "—").
static func stats_rows(fights: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"slot": 0, "name": UiText.t(&"ui.results.crew_slot", {"slot": 1}), "is_ai": false,
			"is_local": true, "kills": 3 * fights, "specials_killed": floori(fights / 2.0), "civilians_killed": 0, "downs": mini(fights, 1),
			"shots": 14 * fights, "hits": 9 * fights, "headshots": 2 * fights}]
	for slot: int in [1, 2, 3]:
		rows.append({"slot": slot, "name": UiText.t(StringName(["", "crew.sable", "crew.dutch", "crew.wren"][slot])),
				"is_ai": true, "is_local": false, "kills": fights * (4 - slot), "specials_killed": floori(fights / (slot + 1.0)),
				"civilians_killed": 1 if slot == 2 and fights > 1 else 0, "downs": 1 if slot == 2 and fights > 2 else 0})
	return rows


func _process(delta: float) -> void:
	if not playing or model == null:
		return
	t = fmod(t + delta, LOOP_S)
	var stage: int = int(t / 4.0)
	if stage != _stage:
		_stage = stage
		_enter_stage(stage)
	_continuous()


func _continuous() -> void:
	if _stage in [1, 2]:
		var local: float = fmod(t, 8.0) / 8.0
		model.detection = [
			{"observer_net_id": 11, "world_pos": Vector3(6.0 * sin(t), 0.0, -6.0 * cos(t)), "value": local, "kind": Enums.ObserverKind.GUARD},
			{"observer_net_id": 12, "world_pos": Vector3(-5.0, 0.0, 3.0), "value": minf(local * 1.4, 1.0), "kind": Enums.ObserverKind.CAMERA},
		]
	if _stage == 3:
		var p: float = fmod(t, 4.0) / 4.0
		model.pagers = [{"pager_id": 1, "time_left_s": 10.0 * (1.0 - p), "answering": true, "progress": p}]
		model.interaction = {"text_key": &"ui.prompt.answer_pager", "args": {}, "progress": p, "blocked_reason": &""}
	if _stage == 7 or _stage == 8:
		model.captain_resistance = minf(0.1 + 0.05 * floorf((t - 28.0) / 1.0), 0.5)  # 10% +5%/step, cap 50%
	if _stage == 6:
		model.stamina = 1.0 - fmod(t, 4.0) / 4.0  # sprinting
	if _stage == 8:
		model.stamina = 0.6 * fmod(t, 4.0) / 4.0  # recovering
	if _stage >= 6 and _stage <= 8:
		model.health = maxf(model.max_health * (1.0 - fmod(t, 4.0) / 4.0), 1.0)


func _enter_stage(stage: int) -> void:
	match stage:
		0:
			setup_initial()
			model.detection = []
			model.pagers = []
			model.assault_phase = Enums.AssaultPhase.NONE
			model.captain_present = false
			model.captain_resistance = 0.0
			model.stamina = 1.0
			model.exhausted = false
			model.crew_state = Enums.CrewState.NORMAL
			model.bleedout_s = -1.0
			model.interaction = {"text_key": &"ui.prompt.mask_up", "args": {}, "progress": 0.0, "blocked_reason": &""}
		1:
			model.casing = false
			model.masked = true
			model.player_mode = &"masked"
			model.interaction = {"text_key": &"ui.prompt.pick_lock", "args": {}, "progress": 0.0,
					"blocked_reason": &"ui.blocked.need_keycard"}
		2:
			model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
			model.hostages = 2
		3:
			model.detection = []
		4:
			model.pagers = []
			model.pagers_answered = 1
			model.interaction = {}
			model.camera_alarm_s = 7.0
		5:
			model.camera_alarm_s = -1.0
			model.assault_phase = Enums.AssaultPhase.ANTICIPATION
			model.objectives = [
				{"id": &"casing", "text_key": &"objective.glasshouse.casing", "args": {}, "state": Enums.ObjectiveState.COMPLETED},
				{"id": &"secure", "text_key": &"objective.glasshouse.secure", "args": {"count": 1, "total": 4},
						"state": Enums.ObjectiveState.ACTIVE},
			]
		6:
			model.crew_stats = stats_rows(1)
			model.assault_phase = Enums.AssaultPhase.BUILD
			model.assault_wave = 1
			model.warnings = [&"phantom"]
		7:
			model.assault_phase = Enums.AssaultPhase.SUSTAIN
			model.captain_resistance = 0.1
			model.captain_present = true
			model.warnings = [&"phantom", &"captain"]
			model.stamina = 0.0
			model.exhausted = true
			model.armor = 0.0
			model.ammo = {Enums.WeaponSlot.SECONDARY: {"mag": 4, "reserve": 60}}
		8:
			model.crew_stats = stats_rows(3)
			model.crew_state = Enums.CrewState.DOWNED
			model.downs_left = 2
			model.bleedout_s = 30.0
			model.exhausted = false
			model.warnings = []
			model.crew = [
				_mate(1, "crew.sable", 0.3, 0.0, Enums.CrewState.DOWNED),
				_mate(2, "crew.dutch", 0.0, 0.0, Enums.CrewState.CUSTODY),
				_mate(3, "crew.wren", 1.0, 0.5, Enums.CrewState.NORMAL),
			]
		9:
			model.assault_phase = Enums.AssaultPhase.FADE
			model.captain_present = false
			model.crew_state = Enums.CrewState.NORMAL
			model.bleedout_s = -1.0
			model.carried_bag = {}
			model.stamina = 1.0


static func _mate(slot: int, name_key: String, hp: float, ar: float, state: int) -> Dictionary:
	return {"slot": slot, "name": UiText.t(StringName(name_key)), "is_ai": true, "health_frac": hp,
			"armor_frac": ar, "state": state, "downs_left": 3, "carried_loot_id": &""}
