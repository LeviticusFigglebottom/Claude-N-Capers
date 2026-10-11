## Shadow Ledger (Kessler & Moor penthouse) mission flow. Owner: ENV C (C2).
## Design: docs/design/heists/shadow_ledger.md §Objectives / §Rare events / §Escape (D-042).
## Contract heist_map.md §6: uses only the HeistMission API, EventBus, Services and nodes of this map
## (prefabs found by objective_tag).
##
## Stealth only (HeistDef.mode STEALTH_ONLY): any alarm ends the heist through the runtime
## (S11.3, FAIL_STEALTH_ONLY_ALARM); the mission only plays Mercer's abort line.
## Required line: laptop + keycard (server door, unless srv_contractor) + cage code or saw + the 45 s
## hack + secure the laptop and 2 of 3 drive bags -> escape (heli 45 s approach, line, service lift).
## Optional: the study safe (keycard + time lock), the paintings, the archive safe, small loot.
extends HeistMission

const MIN_DRIVES: int = 2
const LAST_PAGER: int = 4
const CAGE_GROUP: StringName = &"cage"
const ITEM_KEYCARD: StringName = &"item.keycard"
const ITEM_CODE_NOTE: StringName = &"item.code_note"
const LOOT_LAPTOP: StringName = &"loot.ledger_laptop"
const LOOT_DRIVES: StringName = &"loot.ledger_drives"
const TAG_SERVER_DOOR: StringName = &"server_door"
const TAG_SERVER_READER: StringName = &"server_reader"
const TAG_CAGE: StringName = &"cage"
const TAG_CAGE_GATE: StringName = &"cage_gate"
const TAG_HACK: StringName = &"hack"
const TAG_DRIVES: StringName = &"drives"
const TAG_LAPTOP: StringName = &"laptop"
const TAG_STUDY_SAFE: StringName = &"study_safe"
const TAG_STUDY_DOOR: StringName = &"study_door"
const TAG_PAINTINGS: StringName = &"paintings"
const TAG_ARCHIVE_SAFE: StringName = &"archive_safe"
const TAG_PRINTOUT: StringName = &"printout"
const TAG_ESCAPE_HELI: StringName = &"escape_heli"
const TAG_ESCAPE_LINE: StringName = &"escape_line"
const TAG_ESCAPE_SERVICE: StringName = &"escape_service"
const RARE_PRINTOUT: StringName = &"ledger_printout"
const RARE_CAGE_OPEN: StringName = &"cage_left_open"
const RARE_TIMELOCK: StringName = &"timelock_extended"
const TIMELOCK_EXTRA_S: float = 60.0
## Strings keys for the escape in Mercer's line (ENV B resolves them).
const ESCAPE_KEYS: Dictionary = {
	TAG_ESCAPE_HELI: &"ui.escape.heli", TAG_ESCAPE_LINE: &"ui.escape.line", TAG_ESCAPE_SERVICE: &"ui.escape.lift",
}

var _cage_open: bool = false
var _hacked: bool = false
var _laptop_secured: bool = false
var _drives_secured: int = 0
var _escape_open: bool = false
var _lasers_said: bool = false


func _on_mission_start() -> void:
	say(&"vo.mercer.shadow_ledger_intro")
	say(&"vo.accountant.shadow_ledger_contact_intro", {}, &"accountant")
	add_objective(&"casing", &"objective.shadow_ledger.casing", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"laptop", &"objective.shadow_ledger.laptop", Enums.ObjectiveState.ACTIVE, {"location": variant(&"laptop")})
	add_objective(&"keycard", &"objective.shadow_ledger.keycard")
	require_items(&"keycard", ITEM_KEYCARD)
	add_objective(&"server_door", &"objective.shadow_ledger.server_door")
	add_objective(&"cage_code", &"objective.shadow_ledger.cage_code", Enums.ObjectiveState.ACTIVE,
		{"optional": true, "alternative": &"saw"})
	add_objective(&"cage", &"objective.shadow_ledger.cage")
	add_objective(&"hack", &"objective.shadow_ledger.hack", Enums.ObjectiveState.HIDDEN)
	add_objective(&"drives", &"objective.shadow_ledger.drives", Enums.ObjectiveState.HIDDEN)
	add_objective(&"secure", &"objective.shadow_ledger.secure", Enums.ObjectiveState.ACTIVE,
		{"laptop": 1, "drives": MIN_DRIVES, "optional_more": true})
	add_objective(&"study_safe", &"objective.shadow_ledger.study_safe", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"paintings", &"objective.shadow_ledger.paintings", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"archive_safe", &"objective.shadow_ledger.archive_safe", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"escape", &"objective.shadow_ledger.escape", Enums.ObjectiveState.HIDDEN)
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_started", _on_device_started)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"item_picked_up", _on_item_picked_up)
	on_event(&"loot_secured", _on_bag_secured)
	_setup_variants()


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING:
		complete(&"casing")


## STEALTH_ONLY: the runtime ends the heist after the abort window; Mercer calls it.
func _on_alarm(_reason: StringName) -> void:
	say(&"vo.mercer.shadow_ledger_abort")


func _on_pager_answered(total: int) -> void:
	if total == LAST_PAGER:
		say(&"vo.mercer.shadow_ledger_last_pager", {"answered": total})


# --- Setup ------------------------------------------------------------------------------------

func _setup_variants() -> void:
	# Inside the cage: the hack terminal waits for the cage, the drive sleds for the hack.
	for h: Node in find_tagged(TAG_HACK):
		_set_enabled(h, false)
	for d: Node in find_tagged(TAG_DRIVES):
		_set_enabled(d, false)
	# Study safe time lock (scalar; +60 s on timelock_extended, Brutal+ via min_difficulty).
	var lock_s: float = float(_scalar(&"time_lock_s", 90.0))
	if _rare(RARE_TIMELOCK):
		lock_s += TIMELOCK_EXTRA_S
	for s: Node in find_tagged(TAG_STUDY_SAFE):
		s.set(&"time_lock_s", lock_s)
	update_objective_data(&"study_safe", {"time_lock_s": lock_s})
	# ledger_printout: the working copy on Kessler's desk exists only with the rare event.
	for p: Node in find_tagged(TAG_PRINTOUT):
		_set_enabled(p, _rare(RARE_PRINTOUT))
		(p as Node3D).visible = _rare(RARE_PRINTOUT)
	# srv_contractor: the server door is propped (the reader's target starts open), no keycard needed.
	if _slot_active(&"server_room", &"srv_contractor"):
		for door: Node in find_tagged(TAG_SERVER_DOOR):
			door.call(&"unlock")
			door.call(&"set_open", true)
		update_objective_data(&"keycard", {"skipped": true})
		complete(&"keycard")
		complete(&"server_door")
		if _rare(RARE_CAGE_OPEN):
			update_objective_data(&"cage", {"left_open": true})
			_open_cage()


# --- Stealth flow -----------------------------------------------------------------------------

func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_SERVER_READER) or _is_tagged(interactable_net_id, TAG_SERVER_DOOR):
		if objective_state(&"server_door") == Enums.ObjectiveState.ACTIVE:
			complete(&"server_door")
	elif _is_tagged(interactable_net_id, TAG_CAGE):
		# The code path opens the lock at once (the saw reports device_finished).
		_open_cage()
	elif _is_tagged(interactable_net_id, TAG_STUDY_DOOR) and not _lasers_said:
		_lasers_said = true
		say(&"vo.mercer.shadow_ledger_lasers")
	elif _is_tagged(interactable_net_id, TAG_LAPTOP):
		if objective_state(&"laptop") == Enums.ObjectiveState.ACTIVE:
			complete(&"laptop")
			say(&"vo.mercer.shadow_ledger_laptop_found")
	elif _is_tagged(interactable_net_id, TAG_DRIVES):
		_check_drives()
	elif _is_tagged(interactable_net_id, TAG_PAINTINGS):
		var left: int = 0
		for p: Node in find_tagged(TAG_PAINTINGS):
			left += int(p.get(&"remaining"))
		if left <= 0:
			complete(&"paintings")


func _on_item_picked_up(item_id: StringName, _crew_slot: int) -> void:
	if item_id == ITEM_KEYCARD:
		say(&"vo.mercer.shadow_ledger_keycard_found")
	elif item_id == ITEM_CODE_NOTE and objective_state(&"cage_code") == Enums.ObjectiveState.ACTIVE:
		complete(&"cage_code")
		say(&"vo.mercer.shadow_ledger_code_found")


func _on_device_started(device_net_id: int, kind: StringName, seconds: float) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		say(&"vo.mercer.shadow_ledger_hack_started", {"seconds": seconds})
	elif _is_tagged(device_net_id, TAG_STUDY_SAFE) and kind == &"time_lock":
		say(&"vo.mercer.shadow_ledger_time_lock_started", {"seconds": seconds})


func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_CAGE):
		_open_cage()
	elif _is_tagged(device_net_id, TAG_HACK):
		_on_hack_done()
	elif _is_tagged(device_net_id, TAG_STUDY_SAFE):
		complete(&"study_safe")
		say(&"vo.mercer.shadow_ledger_time_lock_open")
	elif _is_tagged(device_net_id, TAG_ARCHIVE_SAFE):
		complete(&"archive_safe")


func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		say(&"vo.mercer.shadow_ledger_hack_interrupted")


func _open_cage() -> void:
	if _cage_open:
		return
	_cage_open = true
	for g: Node in find_tagged(TAG_CAGE_GATE):
		g.call(&"unlock")
		g.call(&"set_open", true)
	if objective_state(&"cage") != Enums.ObjectiveState.COMPLETED:
		complete(&"cage")
	say(&"vo.mercer.shadow_ledger_cage_open")
	for h: Node in find_tagged(TAG_HACK):
		_set_enabled(h, true)
	activate(&"hack")


func _on_hack_done() -> void:
	if _hacked:
		return
	_hacked = true
	complete(&"hack")
	say(&"vo.mercer.shadow_ledger_hack_done")
	for d: Node in find_tagged(TAG_DRIVES):
		_set_enabled(d, true)
	activate(&"drives")


func _check_drives() -> void:
	var left: int = 0
	for d: Node in find_tagged(TAG_DRIVES):
		left += int(d.get(&"remaining"))
	if left <= 0 and objective_state(&"drives") == Enums.ObjectiveState.ACTIVE:
		complete(&"drives")


func _on_bag_secured(_bag_net_id: int, loot_id: StringName, _value: int) -> void:
	if loot_id == LOOT_LAPTOP:
		_laptop_secured = true
	elif loot_id == LOOT_DRIVES:
		_drives_secured += 1
	update_objective_data(&"secure", {"laptop_secured": _laptop_secured, "drives_secured": _drives_secured})
	if _laptop_secured and _drives_secured >= MIN_DRIVES:
		_try_escape()


## Required loot secured: heli (the zone's 45 s approach runs in the prefab), line or service lift.
func _try_escape() -> void:
	if _escape_open:
		return
	_escape_open = true
	complete(&"secure")
	say(&"vo.mercer.shadow_ledger_required_secured")
	activate(&"escape")
	var tag: StringName = _escape_tag()
	say(&"vo.mercer.shadow_ledger_escape", {"escape": ESCAPE_KEYS.get(tag, &"ui.escape.heli")})
	activate_escape(tag)


# --- Helpers ----------------------------------------------------------------------------------

## The rolled escape (a pre-planned escape_position forces the slot).
func _escape_tag() -> StringName:
	if _slot_active(&"escape", &"esc_line"):
		return TAG_ESCAPE_LINE
	if _slot_active(&"escape", &"esc_service"):
		return TAG_ESCAPE_SERVICE
	return TAG_ESCAPE_HELI


func _scalar(id: StringName, fallback: Variant) -> Variant:
	var v: Variant = variant(id)
	return fallback if v == null else v


func _rare(id: StringName) -> bool:
	var v: Variant = variant(&"rare")
	return v is Array and (v as Array).has(id)


func _slot_active(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = variant(group)
	return v is Array and (v as Array).has(slot_id)


func _set_enabled(prefab: Node, on: bool) -> void:
	var it: Node = prefab.get_node_or_null(^"Interactable")
	if it != null:
		it.set(&"enabled", on)


func _net_id(n: Node) -> int:
	var nid: Variant = n.get(&"net_id")
	return int(nid) if nid != null else 0


func _is_tagged(net_id: int, tag: StringName) -> bool:
	if net_id == 0:
		return false
	for n: Node in find_tagged(tag):
		if _net_id(n) == net_id:
			return true
	return false
