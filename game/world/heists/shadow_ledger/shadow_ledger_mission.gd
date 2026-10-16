## Shadow Ledger (Kessler & Moor penthouse) mission flow. Owner: ENV A (mission scripts, owners.json; ENV C built the first flow, C2).
## Design: docs/design/heists/shadow_ledger.md §Objectives / §Rare events / §Escape (D-042).
## Contract heist_map.md §6: uses only the HeistMission API, EventBus, Services and nodes of this map
## (prefabs found by objective_tag).
##
## Stealth only (HeistDef.mode STEALTH_ONLY): any alarm ends the heist through the runtime
## (S11.3, FAIL_STEALTH_ONLY_ALARM); the mission only plays Mercer's abort line (own_abort_line: it replaces the
## generic one). SL-6: after the alarm the mission stays quiet (no progress lines, no escape): the job is over.
## Required line: laptop + keycard (server door, unless srv_contractor) + cage code or saw + the 45 s
## hack + secure the laptop and 2 of 3 drive bags -> escape (heli 45 s approach, line, service lift).
## Optional: the study safe (keycard + time lock), the paintings, the archive safe, small loot.
extends HeistMission

const MIN_DRIVES: int = 2
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
## D-115 (SL-9): Mercer's lasers line on the first crew approach to the active M3 grid (the rolled laser_pattern
## slot's LaserGrid; within LASER_HINT_M of the grid, like Gallery Night), before the alarm.
const TAG_LASERS: StringName = &"art_hall_lasers"
const LASER_HINT_M: float = 4.0
const LASER_HINT_V_M: float = 1.0
const VO_LASERS: StringName = &"vo.mercer.shadow_ledger_lasers"
const TAG_PAINTINGS: StringName = &"paintings"
const TAG_ARCHIVE_SAFE: StringName = &"archive_safe"
const TAG_PRINTOUT: StringName = &"printout"
const TAG_ESCAPE_HELI: StringName = &"escape_heli"
const TAG_ESCAPE_LINE: StringName = &"escape_line"
const TAG_ESCAPE_SERVICE: StringName = &"escape_service"
const TAG_KEYCARD: StringName = &"keycard"
const TAG_CAGE_CODE: StringName = &"cage_code"
## PO-5 (D-089 markers): the rolled escape's secure zone (HeliNetE1 / LineSecureE2 / LiftSecureE3).
const TAG_LOOT_SECURE: StringName = &"loot_secure"
const RARE_PRINTOUT: StringName = &"ledger_printout"
const RARE_CAGE_OPEN: StringName = &"cage_left_open"
const RARE_TIMELOCK: StringName = &"timelock_extended"
## D-117 §6: Mercer's camera warning, the first time any camera's meter on any crew member reaches CAMERA_WARN_METER
## (before the "!" countdown, which is the point of no return here). Polled from the StealthDirector (server rows for
## every crew slot; detection_progress only reaches the local / owning peer).
const VO_CAMERA_WARNING: StringName = &"vo.mercer.shadow_ledger_camera_warning"
const CAMERA_WARN_METER: float = 0.5
const CAMERA_POLL_S: float = 0.25
## SL-6: the cage / archive safe are also watched for `opened` (the handheld saw, QC-37, opens a safe without an
## interaction or device fact).
const LOCK_POLL_S: float = 0.5
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
var _camera_warned: bool = false
var _archive_open: bool = false


func _on_mission_start() -> void:
	own_last_pager_line = true  # D-117: the heist's last-pager line replaces the generic one
	own_abort_line = true  # SL-6: "They're wiping the array" replaces the generic abort line
	say(&"vo.mercer.shadow_ledger_intro")
	say(&"vo.accountant.shadow_ledger_contact_intro", {}, &"accountant")
	add_objective(&"casing", &"objective.shadow_ledger.casing", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"laptop", &"objective.shadow_ledger.laptop", Enums.ObjectiveState.ACTIVE,
		{"location": variant(&"laptop"), "marker_tags": [TAG_LAPTOP]})
	# srv_contractor: the server door is propped, no keycard needed. B-SL audit: both steps are born COMPLETED (their
	# first sighting, which ContactRadio keeps silent), so the Accountant's keycard / server-room lines never fire.
	var contractor: bool = _slot_active(&"server_room", &"srv_contractor")
	var done: Enums.ObjectiveState = Enums.ObjectiveState.COMPLETED if contractor else Enums.ObjectiveState.ACTIVE
	add_objective(&"keycard", &"objective.shadow_ledger.keycard", done,
		{"marker_tags": [TAG_KEYCARD], "skipped": true} if contractor else {"marker_tags": [TAG_KEYCARD]})
	require_items(&"keycard", ITEM_KEYCARD)
	add_objective(&"server_door", &"objective.shadow_ledger.server_door", done, {"marker_tags": [TAG_SERVER_READER]})
	add_objective(&"cage_code", &"objective.shadow_ledger.cage_code", Enums.ObjectiveState.ACTIVE,
		{"optional": true, "alternative": &"saw", "marker_tags": [TAG_CAGE_CODE]})
	add_objective(&"cage", &"objective.shadow_ledger.cage", Enums.ObjectiveState.ACTIVE, {"marker_tags": [TAG_CAGE]})
	add_objective(&"hack", &"objective.shadow_ledger.hack", Enums.ObjectiveState.HIDDEN, {"marker_tags": [TAG_HACK]})
	add_objective(&"drives", &"objective.shadow_ledger.drives", Enums.ObjectiveState.HIDDEN, {"marker_tags": [TAG_DRIVES]})
	add_objective(&"secure", &"objective.shadow_ledger.secure", Enums.ObjectiveState.ACTIVE,
		{"laptop": 1, "drives": MIN_DRIVES, "optional_more": true, "marker_tags": [TAG_LOOT_SECURE]})
	add_objective(&"study_safe", &"objective.shadow_ledger.study_safe", Enums.ObjectiveState.ACTIVE,
		{"optional": true, "marker_tags": [TAG_STUDY_SAFE]})
	add_objective(&"paintings", &"objective.shadow_ledger.paintings", Enums.ObjectiveState.ACTIVE,
		{"optional": true, "marker_tags": [TAG_PAINTINGS]})
	add_objective(&"archive_safe", &"objective.shadow_ledger.archive_safe", Enums.ObjectiveState.ACTIVE,
		{"optional": true, "marker_tags": [TAG_ARCHIVE_SAFE]})
	add_objective(&"escape", &"objective.shadow_ledger.escape", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [_escape_tag()]})
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_started", _on_device_started)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"item_picked_up", _on_item_picked_up)
	on_event(&"loot_secured", _on_bag_secured)
	_setup_variants()
	_poll_cameras()
	_watch_lasers()
	_poll_locks()


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	# SL-6: the casing ends when the crew masks up (CASING -> STEALTH); an alarm while casing is the abort, not a step.
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING and not went_loud:
		complete(&"casing")


## STEALTH_ONLY: the runtime ends the heist after the abort window; Mercer calls it.
func _on_alarm(_reason: StringName) -> void:
	say(&"vo.mercer.shadow_ledger_abort")


func _on_pager_answered(total: int) -> void:
	if total == pager_cap():
		_vo(&"vo.mercer.shadow_ledger_last_pager", {"answered": total})


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
	# ledger_printout: the working copy on Kessler's desk exists only with the rare event. SL-6: without it the bag
	# is not on offer at all (remaining 0, as a variant-disabled spawn), so HeistResult.loot_available skips it.
	var printout: bool = _rare(RARE_PRINTOUT)
	for p: Node in find_tagged(TAG_PRINTOUT):
		_set_enabled(p, printout)
		(p as Node3D).visible = printout
		if not printout and p.get(&"remaining") != null:
			p.set(&"remaining", 0)
	# srv_contractor: the server door is propped (the reader's target starts open), no keycard needed.
	if _slot_active(&"server_room", &"srv_contractor"):
		for door: Node in find_tagged(TAG_SERVER_DOOR):
			door.call(&"unlock")
			door.call(&"set_open", true)
		if _rare(RARE_CAGE_OPEN):
			update_objective_data(&"cage", {"left_open": true})
			_open_cage(&"left_open")


# --- Stealth flow -----------------------------------------------------------------------------

func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_SERVER_READER) or _is_tagged(interactable_net_id, TAG_SERVER_DOOR):
		if objective_state(&"server_door") == Enums.ObjectiveState.ACTIVE:
			complete(&"server_door")
	elif _is_tagged(interactable_net_id, TAG_CAGE):
		# SL-6: the code opens the lock at once; placing / fixing the saw (place_saw, fix_drill) only starts the 90 s
		# cut, which reports device_finished. The cage counts as open only when its lock really swung.
		_sync_cage()
	elif _is_tagged(interactable_net_id, TAG_LAPTOP):
		if objective_state(&"laptop") == Enums.ObjectiveState.ACTIVE:
			complete(&"laptop")
			_vo(&"vo.mercer.shadow_ledger_laptop_found")
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
		_vo(&"vo.mercer.shadow_ledger_keycard_found")
	elif item_id == ITEM_CODE_NOTE and objective_state(&"cage_code") == Enums.ObjectiveState.ACTIVE:
		complete(&"cage_code")
		_vo(&"vo.mercer.shadow_ledger_code_found")


func _on_device_started(device_net_id: int, kind: StringName, seconds: float) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		_vo(&"vo.mercer.shadow_ledger_hack_started", {"seconds": seconds})
	elif _is_tagged(device_net_id, TAG_STUDY_SAFE) and kind == &"time_lock":
		_vo(&"vo.mercer.shadow_ledger_time_lock_started", {"seconds": seconds})


func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_CAGE):
		_sync_cage()  # SL-6: also fires when a running saw is aborted (the cage opened another way)
	elif _is_tagged(device_net_id, TAG_HACK):
		_on_hack_done()
	elif _is_tagged(device_net_id, TAG_STUDY_SAFE):
		if objective_state(&"study_safe") == Enums.ObjectiveState.ACTIVE:
			complete(&"study_safe")
			_vo(&"vo.mercer.shadow_ledger_time_lock_open")
	elif _is_tagged(device_net_id, TAG_ARCHIVE_SAFE):
		_sync_archive()


func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		_vo(&"vo.mercer.shadow_ledger_hack_interrupted")


## SL-6: the cage lock (Safe, methods [code, saw]) swung open, however it was beaten: open the cage for the mission.
func _sync_cage() -> void:
	if _cage_open:
		return
	for c: Node in find_tagged(TAG_CAGE):
		if bool(c.get(&"opened")):
			_open_cage(_open_method(c))
			return


## The cage lock's `beaten_by` as the [cage] open_method: &"code", else &"saw" (a placed saw reports &"device").
static func _open_method(lock: Node) -> StringName:
	var how: Variant = lock.get(&"beaten_by")
	return &"code" if how != null and StringName(how) == &"code" else &"saw"


## SL-6: the archive safe (saw only) swung open: the placed saw's device_finished, or the handheld saw.
func _sync_archive() -> void:
	if _archive_open:
		return
	for a: Node in find_tagged(TAG_ARCHIVE_SAFE):
		if bool(a.get(&"opened")):
			_archive_open = true
			if objective_state(&"archive_safe") == Enums.ObjectiveState.ACTIVE:
				complete(&"archive_safe")
			return


func _poll_locks() -> void:
	_sync_cage()
	_sync_archive()
	if not (_cage_open and _archive_open):
		start_timer(&"lock_watch", LOCK_POLL_S, _poll_locks)


## `method` (B achievements, objective.cage.open_method): &"code" / &"saw", or &"left_open" (rare); set on the
## [cage] objective data before it completes.
func _open_cage(method: StringName) -> void:
	if _cage_open:
		return
	_cage_open = true
	update_objective_data(&"cage", {"open_method": method})
	for g: Node in find_tagged(TAG_CAGE_GATE):
		g.call(&"unlock")
		g.call(&"set_open", true)
	# left_open: the lock itself stops offering the code / saw (nothing is left to beat).
	for c: Node in find_tagged(TAG_CAGE):
		if not bool(c.get(&"opened")) and c.has_method(&"swing_open"):
			c.call(&"swing_open")
	# PO6-04: the code note is moot once the cage is open another way (saw, left open).
	if objective_state(&"cage_code") == Enums.ObjectiveState.ACTIVE:
		update_objective_data(&"cage_code", {"skipped": true})
		complete(&"cage_code")
	if objective_state(&"cage") != Enums.ObjectiveState.COMPLETED:
		complete(&"cage")
	_vo(&"vo.mercer.shadow_ledger_cage_open")
	for h: Node in find_tagged(TAG_HACK):
		_set_enabled(h, true)
	activate(&"hack")


func _on_hack_done() -> void:
	if _hacked:
		return
	_hacked = true
	complete(&"hack")
	_vo(&"vo.mercer.shadow_ledger_hack_done")
	for d: Node in find_tagged(TAG_DRIVES):
		_set_enabled(d, true)
	activate(&"drives")


## D-115 (SL-5, doc: 2 of 3 drive bags are required): [drives] completes once MIN_DRIVES bags are taken (or none
## are left, for a map with fewer sleds).
func _check_drives() -> void:
	var left: int = 0
	var taken: int = 0
	for d: Node in find_tagged(TAG_DRIVES):
		left += int(d.get(&"remaining"))
		taken += int(d.get(&"count")) - int(d.get(&"remaining"))
	if (taken >= MIN_DRIVES or left <= 0) and objective_state(&"drives") == Enums.ObjectiveState.ACTIVE:
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
## SL-6: never after the alarm (the abort window): the job is over, no escape opens.
func _try_escape() -> void:
	if _escape_open or went_loud:
		return
	_escape_open = true
	complete(&"secure")
	_vo(&"vo.mercer.shadow_ledger_required_secured")
	activate(&"escape")
	var tag: StringName = _escape_tag()
	_vo(&"vo.mercer.shadow_ledger_escape", {"escape": ESCAPE_KEYS.get(tag, &"ui.escape.heli")})
	activate_escape(tag)


# --- Camera warning (D-117) -------------------------------------------------------------------

func _poll_cameras() -> void:
	if _camera_warned or went_loud:
		return
	var rt: HeistRuntime = HeistRuntime.of(self)
	var st: StealthDirector = rt.stealth if rt != null else null
	if st != null:
		var top: float = 0.0
		for slot: int in range(Net.MAX_CREW):
			for e: Dictionary in st.detection_entries(slot):
				if int(e.get("kind", -1)) == Enums.ObserverKind.CAMERA:
					top = maxf(top, float(e.get("value", 0.0)))
		_on_camera_meter(top)
	if not _camera_warned:
		start_timer(&"camera_watch", CAMERA_POLL_S, _poll_cameras)


## The highest camera meter on the crew right now (0..1): Mercer warns once, before the alarm.
func _on_camera_meter(value: float) -> void:
	if _camera_warned or went_loud or value < CAMERA_WARN_METER:
		return
	_camera_warned = true
	_vo(VO_CAMERA_WARNING)


# --- Lasers line (SL-9) -----------------------------------------------------------------------

## A crew-detecting box around each active grid (the inactive laser_pattern slots are freed by the resolver): the grid
## extents grown by LASER_HINT_M horizontally, so the whole 6.8 m wide grid is covered, not just its centre.
func _watch_lasers() -> void:
	for g: Node in find_tagged(TAG_LASERS):
		var grid: Node3D = g as Node3D
		if grid == null:
			continue
		var size: Vector3 = Vector3(2.0, 2.0, 0.1)
		var s: Variant = grid.get(&"size_m")
		if s is Vector3:
			size = s
		var area: Area3D = Area3D.new()
		area.name = "LasersHintArea"
		area.collision_layer = 0
		area.collision_mask = 0xFFFFFFFF
		area.monitorable = false
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		# Horizontal reach LASER_HINT_M; vertically only LASER_HINT_V_M, so the floors above / below never trigger it.
		box.size = size + Vector3(2.0 * LASER_HINT_M, 2.0 * LASER_HINT_V_M, 2.0 * LASER_HINT_M)
		shape.shape = box
		shape.position = Vector3(0.0, size.y * 0.5, 0.0)  # LaserGrid: centred in x / z, beams from y 0 to size_m.y
		area.add_child(shape)
		grid.add_child(area)
		area.body_entered.connect(_on_lasers_area)


func _on_lasers_area(body: Node) -> void:
	if _lasers_said or went_loud or body == null or not body.is_in_group(G.CREW):
		return
	_lasers_said = true
	_vo(VO_LASERS)


# --- Helpers ----------------------------------------------------------------------------------

## SL-6: a progress line from Mercer, never after the alarm (his abort line is the last word).
func _vo(line_id: StringName, context: Dictionary = {}) -> void:
	if not went_loud:
		say(line_id, context)


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
