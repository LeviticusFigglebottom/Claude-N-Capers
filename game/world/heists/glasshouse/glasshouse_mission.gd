## Glasshouse (Vossberg Jewelers) mission flow. Owner: ENV C (C1-03).
## Design: docs/design/heists/glasshouse.md §Objectives / §Escape. Contract: heist_map.md §6: uses
## only the HeistMission API, EventBus and nodes of this map (found by objective_tag).
##
## Stealth: casing (optional) -> keycard OR the safe code (skipped if `safe_left_open`) -> workshop door
## -> safe (keycard swipe, code, slow lockpick or drill) -> bag the consignment -> secure >= 2 bags -> escape.
## PO6-04 (D-114 §1: stealth never needs the drill): the code note (`code_note` slot group) is its own
## objective with markers, the safe objective marks the keycard reader too, and the safe takes a slow,
## silent lockpick from anyone while the heist is quiet (Safe.lockpick_fallback). The drill is the loud path.
## Loud (alarm): the safe reader locks down (drill only), the police gates open, the van leaves and
## returns at the first assault FADE or after 240 s, whichever is later; escape needs >= 2 bags.
extends HeistMission

const MIN_BAGS: int = 2
const VAN_RETURN_S: float = 240.0
const ITEM_KEYCARD: StringName = &"item.keycard"
const ITEM_CODE_NOTE: StringName = &"item.code_note"
## PO6-04: tag given at runtime to the surviving code note (the map's notes carry no objective_tag).
const TAG_CODE_NOTE: StringName = &"code_note"
const CODE_NOTE_GROUP_PATH: NodePath = ^"Variants/Group_code_note"
const TAG_SAFE: StringName = &"safe"
const TAG_SAFE_DRILL: StringName = &"safe_drill"
const TAG_SAFE_READER: StringName = &"safe_reader"
const TAG_SAFE_LOOT: StringName = &"safe_loot"
const TAG_WORKSHOP_DOOR: StringName = &"workshop_door"
const TAG_BACK_DOOR: StringName = &"back_door"
const TAG_SALON_DOOR: StringName = &"salon_door"
const TAG_POLICE_GATE: StringName = &"police_gate"
const TAG_ESCAPE: StringName = &"escape_van"
const TAG_KEYCARD: StringName = &"keycard"
## PO-5 (D-089 markers): the van's secure zones (VanSecureE1 / VanSecureE2).
const TAG_LOOT_SECURE: StringName = &"loot_secure"

var _safe_open: bool = false
var _lockdown: bool = false
var _van_fade: bool = false
var _van_timer_done: bool = false
var _escape_open: bool = false
var _code_said: bool = false


func _on_mission_start() -> void:
	own_last_pager_line = true  # D-117: the heist's last-pager line replaces the generic one
	say(&"vo.mercer.glasshouse_intro")
	add_objective(&"casing", &"objective.glasshouse.casing", Enums.ObjectiveState.ACTIVE, {"optional": true})
	if _slot_active(&"safe_state", &"safe_open"):
		add_objective(&"keycard", &"objective.glasshouse.keycard", Enums.ObjectiveState.COMPLETED, {"skipped": true})
		add_objective(&"code", &"objective.glasshouse.code", Enums.ObjectiveState.COMPLETED, {"skipped": true})
	else:
		add_objective(&"keycard", &"objective.glasshouse.keycard", Enums.ObjectiveState.ACTIVE,
			{"marker_tags": [TAG_KEYCARD], "alternative": &"code"})
		require_items(&"keycard", ITEM_KEYCARD)
		_tag_code_notes()
		add_objective(&"code", &"objective.glasshouse.code", Enums.ObjectiveState.ACTIVE,
			{"marker_tags": [TAG_CODE_NOTE], "alternative": &"keycard", "optional": true})
	add_objective(&"workshop_door", &"objective.glasshouse.workshop_door", Enums.ObjectiveState.ACTIVE,
		{"marker_tags": [TAG_WORKSHOP_DOOR]})
	_enable_lockpick_fallback()
	add_objective(&"safe", &"objective.glasshouse.safe", Enums.ObjectiveState.ACTIVE,
		{"methods": [&"keycard", &"code", &"lockpick", &"drill"], "marker_tags": [TAG_SAFE, TAG_SAFE_READER]})
	add_objective(&"safe_loot", &"objective.glasshouse.safe_loot", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [TAG_SAFE_LOOT]})
	add_objective(&"secure", &"objective.glasshouse.secure", Enums.ObjectiveState.ACTIVE,
		{"bags": MIN_BAGS, "count": 0, "total": MIN_BAGS, "optional_more": true, "marker_tags": [TAG_LOOT_SECURE]})
	require_loot(&"secure", MIN_BAGS)
	add_objective(&"escape", &"objective.glasshouse.escape", Enums.ObjectiveState.HIDDEN, {"marker_tags": [TAG_ESCAPE]})
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
	if total == pager_cap():
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
		_skip_if_active(&"code")  # PO6-04: either one gets you into the safe
	elif item_id == ITEM_CODE_NOTE:
		if objective_state(&"code") == Enums.ObjectiveState.ACTIVE:
			complete(&"code")
		if not _code_said and not _safe_open:  # D-117: Mercer, the first time the safe code is read
			_code_said = true
			say(&"vo.mercer.glasshouse_code_found")
		_skip_if_active(&"keycard")


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
	_skip_if_active(&"keycard")
	_skip_if_active(&"code")
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
			# Board finding: the loud transition must move the objective on. The reader is dead, so the
			# keycard step is skipped (the drill is the way now); "skipped" as for safe_left_open.
			update_objective_data(&"keycard", {"disabled": true, "reason": &"lockdown", "skipped": true})
			complete(&"keycard")
		if objective_state(&"code") == Enums.ObjectiveState.ACTIVE:
			update_objective_data(&"code", {"disabled": true, "reason": &"lockdown", "skipped": true})
			complete(&"code")
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

## PO6-04: an objective the crew no longer needs (the other way in was found, or the safe is open).
func _skip_if_active(objective_id: StringName) -> void:
	if objective_state(objective_id) == Enums.ObjectiveState.ACTIVE:
		update_objective_data(objective_id, {"skipped": true})
		complete(objective_id)


## PO6-04: the code note(s) left by the `code_note` variant get the TAG_CODE_NOTE objective tag (marker
## and find_tagged), unless the map already tagged them.
func _tag_code_notes() -> void:
	var map_root: Node = get_parent()
	var group: Node = map_root.get_node_or_null(CODE_NOTE_GROUP_PATH) if map_root != null else null
	if group == null:
		return
	var stack: Array[Node] = [group]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get(&"code_group") != null and &"objective_tag" in n and StringName(n.get(&"objective_tag")) == &"":
			n.set(&"objective_tag", TAG_CODE_NOTE)
		for c: Node in n.get_children():
			stack.append(c)


## PO6-04 (D-114 §1): the safe takes a slow, silent lockpick from anyone while the heist is quiet.
func _enable_lockpick_fallback() -> void:
	for s: Node in find_tagged(TAG_SAFE):
		if not (&"lockpick_fallback" in s):
			continue
		s.set(&"lockpick_fallback", true)
		var m: Variant = s.get(&"methods")
		if m is Array and not (m as Array).has(&"lockpick"):
			(m as Array).append(&"lockpick")

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
