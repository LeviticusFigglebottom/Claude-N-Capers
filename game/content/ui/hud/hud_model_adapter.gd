## Translates ENV A's shipped LocalHudModel (A1-11 shape: `changed(property)` + `ammo_mag`,
## `detection_indicators`, `pager_timers`, `teammates`, ...; game/systems/hud_model/README.md) into
## the ui_hud.md v1.1 binding shape the HUD widgets read (`vitals_changed`, `ammo`, `detection`,
## `pagers`, `crew`, ...). Owner: ENV B. Read-only: it never writes to the source.
##
## STOPGAP: delete when LocalHudModel exposes the v1.1 table itself (reported to the lead). Hud.bind()
## wraps a model in this adapter only when it lacks the v1.1 signals (see `needs_adapter`).
## It does NOT join G.LOCAL_HUD_MODEL (the source is the one model per peer).
class_name HudModelAdapter
extends Node

signal vitals_changed()
signal ammo_changed()
signal inventory_changed()
signal carried_bag_changed()
signal interaction_changed()
signal detection_changed()
signal marked_targets_changed()
signal pagers_changed()
signal timers_changed()
signal objectives_changed()
signal assault_changed()
signal hostages_changed()
signal warnings_changed()
signal crew_changed()
signal masked_changed()

## Source property -> v1.1 group (signal) it feeds.
const GROUP_OF: Dictionary = {
	&"health": &"vitals", &"max_health": &"vitals", &"armor": &"vitals", &"max_armor": &"vitals",
	&"downs_left": &"vitals", &"crew_state": &"vitals", &"bleedout_time_left": &"vitals",
	&"ammo_mag": &"ammo", &"ammo_reserve": &"ammo", &"equipped_slot": &"ammo",
	&"deployable_count": &"inventory", &"throwable_count": &"inventory", &"cable_ties": &"inventory",
	&"body_bags": &"inventory",
	&"carried_bag_loot_id": &"carried_bag", &"carried_bag_weight": &"carried_bag",
	&"interaction_prompt_key": &"interaction", &"interaction_progress": &"interaction",
	&"interaction_blocked_reason": &"interaction", &"suspicious_action_blocked": &"interaction",
	&"suspicious_action_prompt_key": &"interaction",
	&"detection_indicators": &"detection", &"marked_targets": &"marked_targets",
	&"pager_timers": &"pagers", &"ecm_time_left": &"timers", &"camera_countdown": &"timers",
	&"objectives": &"objectives", &"assault_phase": &"assault", &"assault_wave": &"assault",
	&"hostages": &"hostages", &"phantom_warning": &"warnings", &"stinger_warning": &"warnings",
	&"teammates": &"crew", &"masked": &"masked", &"casing": &"masked",
}
const GROUPS: Array[StringName] = [
	&"vitals", &"ammo", &"inventory", &"carried_bag", &"interaction", &"detection", &"marked_targets",
	&"pagers", &"timers", &"objectives", &"assault", &"hostages", &"warnings", &"crew", &"masked",
]
const INTERACT_ACTION: StringName = &"interact"

var source: Node = null
var tweak: HudTweak = null

# v1.1 properties (ui_hud.md table).
var health: float = 0.0
var max_health: float = 1.0
var armor: float = 0.0
var max_armor: float = 0.0
var downs_left: int = 0
var crew_state: int = Enums.CrewState.NORMAL
var bleedout_s: float = -1.0
var ammo: Dictionary = {}
var equipped_slot: int = Enums.WeaponSlot.PRIMARY
var deployable_id: StringName = &""
var throwable_id: StringName = &""
var deployable_count: int = 0
var throwable_count: int = 0
var cable_ties: int = 0
var body_bags: int = 0
var carried_bag: Dictionary = {}
var interaction: Dictionary = {}
var detection: Array[Dictionary] = []
var marked_targets: Array[Dictionary] = []
var pagers: Array[Dictionary] = []
var pagers_answered: int = 0
var pagers_max: int = 0
var ecm_time_left_s: float = -1.0
var camera_alarm_s: float = -1.0
var objectives: Array[Dictionary] = []
var assault_phase: int = Enums.AssaultPhase.NONE
var assault_wave: int = 0
var hostages: int = 0
var warnings: Array[StringName] = []
var crew: Array[Dictionary] = []
var masked: bool = false
var casing: bool = true


## True when `m` does not expose the v1.1 binding shape but has A1-11's `changed(property)`.
static func needs_adapter(m: Object) -> bool:
	return m != null and not m.has_signal(&"vitals_changed") and m.has_signal(&"changed")


func setup(src: Node, hud_tweak: HudTweak = null) -> void:
	source = src
	tweak = hud_tweak if hud_tweak != null else HudTweak.load_default()
	pagers_max = tweak.pagers_max
	if source != null:
		source.connect(&"changed", _on_source_changed)
	if not EventBus.pager_answered.is_connected(_on_pager_answered):
		EventBus.pager_answered.connect(_on_pager_answered)
	for g: StringName in GROUPS:
		_pull(g)


func _exit_tree() -> void:
	if source != null and is_instance_valid(source) and source.is_connected(&"changed", _on_source_changed):
		source.disconnect(&"changed", _on_source_changed)
	if EventBus.pager_answered.is_connected(_on_pager_answered):
		EventBus.pager_answered.disconnect(_on_pager_answered)


func _on_source_changed(property: StringName) -> void:
	var g: Variant = GROUP_OF.get(property)
	if g != null:
		_pull(g as StringName)


func _on_pager_answered(_pager_id: int, _crew_slot: int, answered_total: int) -> void:
	pagers_answered = answered_total
	pagers_changed.emit()


func _src(name_id: StringName, fallback: Variant) -> Variant:
	if source == null or not is_instance_valid(source):
		return fallback
	var v: Variant = source.get(name_id)
	return fallback if v == null else v


## Re-read one v1.1 group from the source and emit its signal.
func _pull(g: StringName) -> void:
	match g:
		&"vitals":
			health = float(_src(&"health", 0.0))
			max_health = float(_src(&"max_health", 1.0))
			armor = float(_src(&"armor", 0.0))
			max_armor = float(_src(&"max_armor", 0.0))
			downs_left = int(_src(&"downs_left", 0))
			crew_state = int(_src(&"crew_state", Enums.CrewState.NORMAL))
			var bleed: float = float(_src(&"bleedout_time_left", 0.0))
			bleedout_s = bleed if crew_state == Enums.CrewState.DOWNED and bleed > 0.0 else -1.0
			vitals_changed.emit()
		&"ammo":
			var mags: Dictionary = _src(&"ammo_mag", {}) as Dictionary
			var reserves: Dictionary = _src(&"ammo_reserve", {}) as Dictionary
			var out: Dictionary = {}
			for slot: Variant in mags:
				out[int(slot)] = {"mag": int(mags[slot]), "reserve": int(reserves.get(slot, 0))}
			for slot: Variant in reserves:
				if not out.has(int(slot)):
					out[int(slot)] = {"mag": 0, "reserve": int(reserves[slot])}
			ammo = out
			equipped_slot = int(_src(&"equipped_slot", Enums.WeaponSlot.PRIMARY))
			ammo_changed.emit()
		&"inventory":
			deployable_count = int(_src(&"deployable_count", 0))
			throwable_count = int(_src(&"throwable_count", 0))
			cable_ties = int(_src(&"cable_ties", 0))
			body_bags = int(_src(&"body_bags", 0))
			inventory_changed.emit()
		&"carried_bag":
			var loot: StringName = StringName(_src(&"carried_bag_loot_id", &""))
			carried_bag = {} if loot == &"" else {"loot_id": loot, "weight": int(_src(&"carried_bag_weight", 0))}
			carried_bag_changed.emit()
		&"interaction":
			interaction = _interaction()
			interaction_changed.emit()
		&"detection":
			detection = (_src(&"detection_indicators", []) as Array).duplicate()
			detection_changed.emit()
		&"marked_targets":
			marked_targets = _marked()
			marked_targets_changed.emit()
		&"pagers":
			pagers = _pagers()
			pagers_changed.emit()
		&"timers":
			var ecm: float = float(_src(&"ecm_time_left", 0.0))
			ecm_time_left_s = ecm if ecm > 0.0 else -1.0
			camera_alarm_s = float(_src(&"camera_countdown", -1.0))
			timers_changed.emit()
		&"objectives":
			var objs: Array[Dictionary] = []
			for o: Dictionary in _src(&"objectives", []) as Array:
				objs.append({"id": o.get("id", &""), "text_key": o.get("text_key", &""),
						"args": o.get("data", {}), "state": int(o.get("state", Enums.ObjectiveState.ACTIVE))})
			objectives = objs
			objectives_changed.emit()
		&"assault":
			assault_phase = int(_src(&"assault_phase", Enums.AssaultPhase.NONE))
			assault_wave = int(_src(&"assault_wave", 0))
			assault_changed.emit()
		&"hostages":
			hostages = int(_src(&"hostages", 0))
			hostages_changed.emit()
		&"warnings":
			var w: Array[StringName] = []
			if bool(_src(&"phantom_warning", false)):
				w.append(&"phantom")
			if bool(_src(&"stinger_warning", false)):
				w.append(&"stinger")
			warnings = w
			warnings_changed.emit()
		&"crew":
			var c: Array[Dictionary] = []
			for m: Dictionary in _src(&"teammates", []) as Array:
				c.append({"slot": int(m.get("slot", -1)), "name": String(m.get("name", "")),
						"is_ai": bool(m.get("is_ai", false)), "health_frac": float(m.get("health_frac", 0.0)),
						"armor_frac": float(m.get("armor_frac", 0.0)),
						"state": int(m.get("state", Enums.CrewState.NORMAL)), "downs_left": int(m.get("downs_left", 0)),
						"carried_loot_id": StringName(m.get("carried_bag_loot_id", &""))})
			crew = c
			crew_changed.emit()
		&"masked":
			masked = bool(_src(&"masked", false))
			casing = bool(_src(&"casing", not masked))
			masked_changed.emit()


func _interaction() -> Dictionary:
	var key: StringName = StringName(_src(&"interaction_prompt_key", &""))
	var blocked: StringName = StringName(_src(&"interaction_blocked_reason", &""))
	if key == &"" and bool(_src(&"suspicious_action_blocked", false)):
		key = StringName(_src(&"suspicious_action_prompt_key", &""))
	if key == &"" and blocked == &"":
		return {}
	return {"text_key": key, "args": {"key": action_key_text(INTERACT_ACTION)},
			"progress": float(_src(&"interaction_progress", 0.0)), "blocked_reason": blocked}


func _marked() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in _src(&"marked_targets", []) as Array:
		var node: Node3D = Ids.lookup(int(id)) as Node3D
		var pos: Vector3 = node.global_position if node != null and node.is_inside_tree() else Vector3.ZERO
		out.append({"net_id": int(id), "world_pos": pos, "kind": &""})
	return out


func _pagers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var answer_s: float = float(_src(&"pager_answer_s", 0.0))
	for p: Dictionary in _src(&"pager_timers", []) as Array:
		var answering: bool = bool(p.get("answering", false))
		var left: float = float(p.get("time_left", 0.0))
		var progress: float = clampf(1.0 - left / answer_s, 0.0, 1.0) if answering and answer_s > 0.0 else 0.0
		out.append({"pager_id": int(p.get("pager_id", 0)), "time_left_s": left, "answering": answering,
				"progress": progress})
	return out


## Display text of the first keyboard binding of an InputMap action ("F"), or "" when unbound.
static func action_key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev: InputEvent in InputMap.action_get_events(action):
		var k: InputEventKey = ev as InputEventKey
		if k != null:
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
	return ""
