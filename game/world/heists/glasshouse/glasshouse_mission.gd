## Glasshouse (Vossberg Jewelers) mission flow. Owner: ENV C (C1-03).
## Design: docs/design/heists/glasshouse.md §Objectives / §Escape. Contract: heist_map.md §6: uses
## only the HeistMission API, EventBus and nodes of this map (found by objective_tag).
##
## Stealth: casing (optional) -> keycard (skipped if `safe_left_open`) -> workshop door -> safe
## (keycard swipe or drill) -> bag the consignment -> secure >= 2 bags -> escape at the van.
## Loud (alarm): the safe reader locks down (drill only), the police gates open, the van leaves and
## returns at the first assault FADE or after 240 s, whichever is later; escape needs >= 2 bags.
extends HeistMission

const MIN_BAGS: int = 2
const VAN_RETURN_S: float = 240.0
const LAST_PAGER: int = 4
const ITEM_KEYCARD: StringName = &"item.keycard"
const TAG_SAFE: StringName = &"safe"
const TAG_SAFE_DRILL: StringName = &"safe_drill"
const TAG_SAFE_READER: StringName = &"safe_reader"
const TAG_SAFE_LOOT: StringName = &"safe_loot"
const TAG_WORKSHOP_DOOR: StringName = &"workshop_door"
const TAG_BACK_DOOR: StringName = &"back_door"
const TAG_SALON_DOOR: StringName = &"salon_door"
const TAG_POLICE_GATE: StringName = &"police_gate"
const TAG_ESCAPE: StringName = &"escape_van"

var _safe_open: bool = false
var _lockdown: bool = false
var _van_fade: bool = false
var _van_timer_done: bool = false
var _escape_open: bool = false


func _on_mission_start() -> void:
	say(&"vo.mercer.glasshouse_intro")
	add_objective(&"casing", &"objective.glasshouse.casing", Enums.ObjectiveState.ACTIVE, {"optional": true})
	if _slot_active(&"safe_state", &"safe_open"):
		add_objective(&"keycard", &"objective.glasshouse.keycard", Enums.ObjectiveState.COMPLETED, {"skipped": true})
	else:
		add_objective(&"keycard", &"objective.glasshouse.keycard")
		require_items(&"keycard", ITEM_KEYCARD)
	add_objective(&"workshop_door", &"objective.glasshouse.workshop_door")
	add_objective(&"safe", &"objective.glasshouse.safe", Enums.ObjectiveState.ACTIVE, {"methods": [&"keycard", &"drill"]})
	add_objective(&"safe_loot", &"objective.glasshouse.safe_loot", Enums.ObjectiveState.HIDDEN)
	add_objective(&"secure", &"objective.glasshouse.secure", Enums.ObjectiveState.ACTIVE,
		{"bags": MIN_BAGS, "count": 0, "total": MIN_BAGS, "optional_more": true})
	require_loot(&"secure", MIN_BAGS)
	add_objective(&"escape", &"objective.glasshouse.escape", Enums.ObjectiveState.HIDDEN)
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"item_picked_up", _on_item_picked_up)
	on_event(&"loot_secured", _on_bag_secured)
	on_event(&"assault_phase_changed", _on_assault_phase_changed)
	_apply_door_variants()
	if _slot_active(&"safe_state", &"safe_open"):
		_open_safe()


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING:
		complete(&"casing")
	if new_phase == Enums.HeistPhase.LOUD:
		_go_loud()


func _on_alarm(_reason: StringName) -> void:
	_go_loud()


func _on_pager_answered(total: int) -> void:
	if total >= LAST_PAGER:
		say(&"vo.mercer.glasshouse_last_pager", {"answered": total})


# --- Stealth flow ---------------------------------------------------------------------------

## back_door: propped (or the alley smoker wedged it: doc requires alley_smoker => back_propped);
## salon: unlocked when `salon_open`.
func _apply_door_variants() -> void:
	var smoker_propped: bool = _slot_active(&"guard_post", &"alley_smoker") and _group_empty(&"back_door")
	if _slot_active(&"back_door", &"back_propped") or smoker_propped:
		for d: Node in find_tagged(TAG_BACK_DOOR):
			d.call(&"unlock")
			d.call(&"set_open", true)
	if _slot_active(&"salon", &"salon_open"):
		for d2: Node in find_tagged(TAG_SALON_DOOR):
			d2.call(&"unlock")


func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_WORKSHOP_DOOR):
		if objective_state(&"workshop_door") == Enums.ObjectiveState.ACTIVE:
			complete(&"workshop_door")
			say(&"vo.mercer.glasshouse_workshop_open")
	elif _is_tagged(interactable_net_id, TAG_SAFE_READER):
		if not _lockdown:
			_open_safe()
	elif _is_tagged(interactable_net_id, TAG_SAFE):
		# PO-5: the safe's own keypad (code from a code note) opened it.
		for sf: Node in find_tagged(TAG_SAFE):
			if bool(sf.get(&"opened")):
				_open_safe()
	elif _is_tagged(interactable_net_id, TAG_SAFE_LOOT):
		if objective_state(&"safe_loot") == Enums.ObjectiveState.ACTIVE:
			complete(&"safe_loot")


func _on_item_picked_up(item_id: StringName, _crew_slot: int) -> void:
	if item_id == ITEM_KEYCARD:
		say(&"vo.mercer.glasshouse_keycard_found")


func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_SAFE_DRILL):
		_open_safe()


func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_SAFE_DRILL):
		say(&"vo.mercer.glasshouse_drill_jam")


func _open_safe() -> void:
	if _safe_open:
		return
	_safe_open = true
	for s: Node in find_tagged(TAG_SAFE):
		# PO-5.8: swing the door AND enable the loot inside (Safe.swing_open). Setting `opened` directly
		# left the door shut and the bags disabled; this handler runs before the drill's own
		# finished -> open_by_device, which then saw `opened` and did nothing (the "drill never opens").
		if s.has_method(&"swing_open"):
			s.call(&"swing_open")
		elif s.has_method(&"unlock"):
			s.call(&"unlock")
	complete(&"safe")
	activate(&"safe_loot")


func _on_bag_secured(_bag_net_id: int, _loot_id: StringName, _value: int) -> void:
	update_objective_data(&"secure", {"count": bags_secured, "total": MIN_BAGS})  # HUD: count / total bags
	_try_escape()


# --- Loud flow --------------------------------------------------------------------------------

func _go_loud() -> void:
	if _lockdown:
		return
	_lockdown = true
	say(&"vo.mercer.glasshouse_lockdown")
	for r: Node in find_tagged(TAG_SAFE_READER):
		var it: Node = r.get_node_or_null(^"Interactable")
		if it != null:
			it.set(&"enabled", false)
	if not _safe_open:
		update_objective_data(&"safe", {"methods": [&"drill"], "lockdown": true})
		if objective_state(&"keycard") == Enums.ObjectiveState.ACTIVE:
			update_objective_data(&"keycard", {"disabled": true, "reason": &"lockdown"})
	for g: Node in find_tagged(TAG_POLICE_GATE):
		g.call(&"unlock")
		g.call(&"set_open", true)
	if not _escape_open:
		say(&"vo.mercer.glasshouse_van_eta", {"seconds": VAN_RETURN_S})
		start_timer(&"van_return", VAN_RETURN_S, _on_van_timer)


func _on_van_timer() -> void:
	_van_timer_done = true
	_try_escape()


func _on_assault_phase_changed(assault_phase: int, _wave_index: int) -> void:
	if assault_phase == Enums.AssaultPhase.FADE and not _van_fade:
		_van_fade = true
		_try_escape()


func _try_escape() -> void:
	if _escape_open or bags_secured < MIN_BAGS:
		return
	if went_loud and not (_van_fade and _van_timer_done):
		return
	_escape_open = true
	activate(&"escape")
	say(&"vo.mercer.glasshouse_escape")
	activate_escape(TAG_ESCAPE)


# --- Helpers ----------------------------------------------------------------------------------

func _slot_active(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = variant(group)
	return v is Array and (v as Array).has(slot_id)


func _group_empty(group: StringName) -> bool:
	var v: Variant = variant(group)
	return not (v is Array) or (v as Array).is_empty()


func _is_tagged(net_id: int, tag: StringName) -> bool:
	if net_id == 0:
		return false
	for n: Node in find_tagged(tag):
		var nid: Variant = n.get(&"net_id")
		if nid != null and int(nid) == net_id:
			return true
	return false
