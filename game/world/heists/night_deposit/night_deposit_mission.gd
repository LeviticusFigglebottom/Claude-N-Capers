## Night Deposit (Harbor Savings & Loan) mission flow. Owner: ENV C (C2).
## Design: docs/design/heists/night_deposit.md §Objectives / §Rare events / §Escape (D-040).
## Contract heist_map.md §6: uses only the HeistMission API, EventBus, Services and nodes of this map
## (prefabs found by objective_tag).
##
## Stealth: casing (optional) -> keycard -> time-lock code [code] or server hack [server] -> vault gate
## -> start the time lock at the TL panel (or finish the hack) -> hold `time_lock_s` -> bag the cage and
## the Co-op pallet -> (optional) depository safe / deposit boxes -> secure >= 4 bags -> escape.
## Loud (alarm): vault lockdown (TL panel + hack disabled, a running time lock is relocked), the
## thermal drill on the vault door opens it, police gates open, the escape leaves and returns at the
## second assault FADE or after 300 s, whichever is later (boat +60 s on `fog_lifts`).
extends HeistMission

const MIN_BAGS: int = 4
const ESCAPE_RETURN_S: float = 300.0
const FOG_BOAT_DELAY_S: float = 60.0
const FADES_FOR_ESCAPE: int = 2
const LAST_PAGER: int = 4
const CODE_GROUP: StringName = &"nd_time_lock"
const ITEM_KEYCARD: StringName = &"item.keycard"
const ITEM_CODE_NOTE: StringName = &"item.code_note"
const SVC_CODES: StringName = &"codes"
const TAG_VAULT_GATE: StringName = &"vault_gate"
const TAG_VAULT_DOOR: StringName = &"vault_door"
const TAG_VAULT_DRILL: StringName = &"vault_drill"
const TAG_TIME_LOCK: StringName = &"time_lock"
const TAG_SERVER_HACK: StringName = &"server_hack"
const TAG_VAULT_LOOT: StringName = &"vault_loot"
const TAG_DEPOSITORY: StringName = &"depository"
const TAG_DEPOSITORY_LOOT: StringName = &"depository_loot"
const TAG_DEPOSIT_BOX: StringName = &"deposit_box"
const TAG_POLICE_GATE: StringName = &"police_gate"
const TAG_ESCAPE_VAN: StringName = &"escape_van"
const TAG_ESCAPE_BOAT: StringName = &"escape_boat"
## PO-5 (D-089 markers): the rolled escape's secure zone (VanSecureE1 / BoatSecureE2).
const TAG_LOOT_SECURE: StringName = &"loot_secure"
const RARE_GLITCH: StringName = &"time_lock_glitch"
const RARE_ARMORED_CAR: StringName = &"armored_car_early"
const RARE_FOG: StringName = &"fog_lifts"
const RARE_COURIER: StringName = &"co_op_courier"
const GLITCH_TIME_LOCK_S: float = 10.0
const ARMORED_CAR_AT_S: float = 720.0
const FOG_LIFTS_AT_S: float = 480.0
const COURIER_BAGS: int = 2
const ARMORED_CAR_GUARDS: int = 2
const ARMORED_CAR_SPAWN_TAG: StringName = &"guard_armored_car"
## World static (layer 1), as the generator's prop_box bodies.
const CAR_COLLISION_LAYER: int = 1
const ARMORED_CAR_NODE: NodePath = ^"../Variants/Group_armored_car/Slot_armored_car_bay/ArmoredCar"

var _lockdown: bool = false
var _vault_open: bool = false
var _time_lock_running: bool = false
var _code_known: bool = false
var _escape_open: bool = false
var _fades: int = 0
var _escape_timer_done: bool = false


func _on_mission_start() -> void:
	say(&"vo.mercer.night_deposit_intro")
	say(&"vo.accountant.night_deposit_contact_intro", {}, &"accountant")
	add_objective(&"casing", &"objective.night_deposit.casing", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"keycard", &"objective.night_deposit.keycard", Enums.ObjectiveState.ACTIVE, {"marker_tags": [&"keycard"]})
	require_items(&"keycard", ITEM_KEYCARD)
	add_objective(&"code", &"objective.night_deposit.code", Enums.ObjectiveState.ACTIVE,
		{"alternative": &"server", "marker_tags": [&"code_note"]})
	add_objective(&"server", &"objective.night_deposit.server", Enums.ObjectiveState.ACTIVE,
		{"alternative": &"code", "optional": true, "location": variant(&"server_room"),
			"marker_tags": [TAG_SERVER_HACK]})
	add_objective(&"vault_gate", &"objective.night_deposit.vault_gate", Enums.ObjectiveState.ACTIVE,
		{"marker_tags": [TAG_VAULT_GATE]})
	add_objective(&"time_lock", &"objective.night_deposit.time_lock", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [TAG_TIME_LOCK]})
	add_objective(&"time_lock_wait", &"objective.night_deposit.time_lock_wait", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [TAG_VAULT_DOOR]})
	add_objective(&"vault_drill", &"objective.night_deposit.vault_drill", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [TAG_VAULT_DRILL]})
	add_objective(&"vault_loot", &"objective.night_deposit.vault_loot", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [TAG_VAULT_LOOT]})
	add_objective(&"depository", &"objective.night_deposit.depository", Enums.ObjectiveState.ACTIVE,
		{"optional": true, "marker_tags": [TAG_DEPOSITORY]})
	add_objective(&"secure", &"objective.night_deposit.secure", Enums.ObjectiveState.ACTIVE,
		{"bags": MIN_BAGS, "count": 0, "total": MIN_BAGS, "optional_more": true, "marker_tags": [TAG_LOOT_SECURE]})
	require_loot(&"secure", MIN_BAGS)
	add_objective(&"escape", &"objective.night_deposit.escape", Enums.ObjectiveState.HIDDEN, {"marker_tags": [_escape_tag()]})
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"item_picked_up", _on_item_picked_up)
	on_event(&"loot_secured", _on_bag_secured)
	on_event(&"assault_phase_changed", _on_assault_phase_changed)
	on_event(&"civilian_tied", _on_nd_civilian_dominated)
	on_event(&"civilian_intimidated", _on_nd_civilian_dominated)
	_apply_scalars()
	_schedule_rare_events()


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING:
		complete(&"casing")
	if new_phase == Enums.HeistPhase.LOUD:
		_go_loud()


func _on_alarm(_reason: StringName) -> void:
	_go_loud()


func _on_pager_answered(total: int) -> void:
	if total == LAST_PAGER:
		say(&"vo.mercer.night_deposit_last_pager", {"answered": total})


# --- Setup ------------------------------------------------------------------------------------

## Scalars: deposit_boxes (keep the first N deposit_box prefabs; each locks its own loot until sawn),
## depository_bags (+2 on co_op_courier).
func _apply_scalars() -> void:
	var boxes: int = int(_scalar(&"deposit_boxes", 8))
	var drills: Array[Node] = find_tagged(TAG_DEPOSIT_BOX)
	drills.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for i: int in range(drills.size()):
		var target: Node = _target_of(drills[i])
		if target != null:
			_set_enabled(target, false)  # small loot unlocks when its box is sawn
		if i >= boxes:
			_set_enabled(drills[i], false)
			drills[i].remove_from_group(G.SAW_TARGET)  # deposit_box: the saw can't open a disabled box
			(drills[i] as Node3D).visible = false
	var bags: int = int(_scalar(&"depository_bags", 4))
	if _rare(RARE_COURIER):
		bags += COURIER_BAGS
	for ls: Node in find_tagged(TAG_DEPOSITORY_LOOT):
		ls.set(&"count", bags)
		ls.set(&"remaining", bags)
		_set_enabled(ls, false)  # night-drop bags: until the depository safe opens


func _schedule_rare_events() -> void:
	if _rare(RARE_FOG):
		start_timer(&"fog_lifts", FOG_LIFTS_AT_S, _on_fog_lifts)
	# armored_car_early is Brutal+ through the table's min_difficulty; the difficulty check stays as a guard.
	if _rare(RARE_ARMORED_CAR) and difficulty >= Enums.Difficulty.BRUTAL:
		_set_armored_car_present(false)
		schedule_at(ARMORED_CAR_AT_S, &"armored_car", _on_armored_car)


func _on_fog_lifts() -> void:
	say(&"vo.mercer.night_deposit_fog_lifts")
	var we: WorldEnvironment = get_node_or_null(^"../Lighting/WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.fog_density *= 0.25


## Brutal+ bad event (doc §Rare events): at 12:00 elapsed the armoured car (forced variant slot
## `armored_car_bay`, hidden until now) pulls into the lot and 2 extra guards (pagers) step out at its
## rear, then walk graph `ArmoredCar` (lot -> G1 -> stair -> B1). Stealth only: once loud the police
## assault is the pressure, so neither the car nor the guards come.
func _on_armored_car() -> void:
	if went_loud:
		return
	_set_armored_car_present(true)
	say(&"vo.mercer.night_deposit_armored_car")
	var guards: Array[Node] = spawn_guards(ARMORED_CAR_GUARDS, ARMORED_CAR_SPAWN_TAG)
	update_objective_data(&"secure", {"armored_car": true, "extra_guards": guards.size()})


## The forced armoured car body: hidden and without collision until it arrives.
func _set_armored_car_present(on: bool) -> void:
	var car: Node3D = get_node_or_null(ARMORED_CAR_NODE) as Node3D
	if car == null:
		return
	car.visible = on
	var body: CollisionObject3D = car as CollisionObject3D
	if body != null:
		body.collision_layer = CAR_COLLISION_LAYER if on else 0


# --- Stealth flow -----------------------------------------------------------------------------

func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_VAULT_GATE):
		if objective_state(&"vault_gate") == Enums.ObjectiveState.ACTIVE:
			complete(&"vault_gate")
			say(&"vo.mercer.night_deposit_lasers")
			if not _lockdown and not _vault_open:
				activate(&"time_lock")
	elif _is_tagged(interactable_net_id, TAG_TIME_LOCK):
		if not _lockdown:
			_start_time_lock(&"code")
	elif _is_tagged(interactable_net_id, TAG_VAULT_LOOT):
		_check_vault_loot()


func _on_item_picked_up(item_id: StringName, _crew_slot: int) -> void:
	if item_id == ITEM_KEYCARD:
		say(&"vo.mercer.night_deposit_keycard_found")
	elif item_id == ITEM_CODE_NOTE:
		_code_found()


## code_on_manager: dominating the night manager makes him read out the code (cable tie + shout).
## The mission API cannot tell which civilian it was; any domination while he carries the code
## reveals it (the cleaner never carries one; tidy up when ENV A exposes spawn tags on the event).
func _on_nd_civilian_dominated(_npc_net_id: int, crew_slot: int) -> void:
	if _code_known or not _slot_active(&"code_note", &"code_on_manager"):
		return
	var codes: Object = Services.get_service(SVC_CODES)
	if codes != null and codes.has_method(&"reveal"):
		codes.call(&"reveal", CODE_GROUP, crew_slot)
	_code_found()


func _code_found() -> void:
	if _code_known:
		return
	_code_known = true
	say(&"vo.mercer.night_deposit_code_found")
	if objective_state(&"code") == Enums.ObjectiveState.ACTIVE:
		complete(&"code")


func _start_time_lock(method: StringName) -> void:
	if _time_lock_running or _vault_open:
		return
	_time_lock_running = true
	var seconds: float = float(_scalar(&"time_lock_s", 90.0))
	if _rare(RARE_GLITCH):
		seconds = GLITCH_TIME_LOCK_S
	if objective_state(&"time_lock") != Enums.ObjectiveState.COMPLETED:
		complete(&"time_lock")
	if objective_state(&"code") == Enums.ObjectiveState.ACTIVE and method == &"server":
		update_objective_data(&"code", {"skipped": true})
		complete(&"code")
	update_objective_data(&"time_lock_wait", {"seconds": seconds, "method": method})
	activate(&"time_lock_wait")
	say(&"vo.mercer.night_deposit_time_lock_started", {"seconds": seconds})
	start_timer(&"time_lock", seconds, _on_time_lock_done)
	if seconds > 30.0:
		start_timer(&"time_lock_30", seconds - 30.0, func() -> void:
			if _time_lock_running:
				say(&"vo.mercer.night_deposit_time_lock_30"))


func _on_time_lock_done() -> void:
	if not _time_lock_running or _lockdown:
		return
	_time_lock_running = false
	complete(&"time_lock_wait")
	say(&"vo.mercer.night_deposit_time_lock_open")
	_open_vault()


func _open_vault() -> void:
	if _vault_open:
		return
	_vault_open = true
	for d: Node in find_tagged(TAG_VAULT_DOOR):
		d.call(&"unlock")
		d.call(&"set_open", true)
	activate(&"vault_loot")


func _check_vault_loot() -> void:
	var left: int = 0
	for ls: Node in find_tagged(TAG_VAULT_LOOT):
		left += int(ls.get(&"remaining"))
	if left <= 0 and objective_state(&"vault_loot") == Enums.ObjectiveState.ACTIVE:
		complete(&"vault_loot")


func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_VAULT_DRILL):
		complete(&"vault_drill")
		_open_vault()
	elif _is_tagged(device_net_id, TAG_SERVER_HACK):
		# hack_terminal (QC-12): device_finished after the 60 s run and its reboots (device_jammed /
		# device_restarted in between). Starting the hack is only an interaction, never the finish.
		if not _lockdown:
			complete(&"server")
			_start_time_lock(&"server")
	elif _is_tagged(device_net_id, TAG_DEPOSITORY):
		complete(&"depository")
		for ls: Node in find_tagged(TAG_DEPOSITORY_LOOT):
			_set_enabled(ls, true)
	elif _is_tagged(device_net_id, TAG_DEPOSIT_BOX):
		for d: Node in find_tagged(TAG_DEPOSIT_BOX):
			if _net_id(d) == device_net_id:
				var target: Node = _target_of(d)
				if target != null:
					_set_enabled(target, true)


func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_VAULT_DRILL):
		say(&"vo.mercer.night_deposit_drill_jam")


func _on_bag_secured(_bag_net_id: int, _loot_id: StringName, _value: int) -> void:
	update_objective_data(&"secure", {"count": bags_secured, "total": MIN_BAGS})  # HUD: count / total bags
	_try_escape()


# --- Loud flow --------------------------------------------------------------------------------

func _go_loud() -> void:
	if _lockdown:
		return
	_lockdown = true
	say(&"vo.mercer.night_deposit_lockdown")
	for tag: StringName in [TAG_TIME_LOCK, TAG_SERVER_HACK]:
		for p: Node in find_tagged(tag):
			_set_enabled(p, false)
	if not _vault_open:
		if _time_lock_running:
			_time_lock_running = false
			cancel_timer(&"time_lock")
			cancel_timer(&"time_lock_30")
			fail(&"time_lock_wait")
		for oid: StringName in [&"code", &"server", &"time_lock"]:
			if objective_state(oid) == Enums.ObjectiveState.ACTIVE:
				update_objective_data(oid, {"disabled": true, "reason": &"lockdown"})
		activate(&"vault_drill")
	for g: Node in find_tagged(TAG_POLICE_GATE):
		g.call(&"unlock")
		g.call(&"set_open", true)
	if not _escape_open:
		var wait_s: float = ESCAPE_RETURN_S
		if _escape_tag() == TAG_ESCAPE_BOAT and _rare(RARE_FOG):
			wait_s += FOG_BOAT_DELAY_S
		say(&"vo.mercer.night_deposit_escape_eta", {"seconds": wait_s})
		start_timer(&"escape_return", wait_s, _on_escape_timer)


func _on_escape_timer() -> void:
	_escape_timer_done = true
	_try_escape()


func _on_assault_phase_changed(assault_phase: int, _wave_index: int) -> void:
	if assault_phase == Enums.AssaultPhase.FADE:
		_fades += 1
		_try_escape()


func _try_escape() -> void:
	if _escape_open or bags_secured < MIN_BAGS:
		return
	if went_loud and not (_fades >= FADES_FOR_ESCAPE and _escape_timer_done):
		return
	_escape_open = true
	activate(&"escape")
	say(&"vo.mercer.night_deposit_escape")
	activate_escape(_escape_tag())


# --- Helpers ----------------------------------------------------------------------------------

## The rolled escape (van E1 / boat E2); a pre-planned escape_position forces the slot.
func _escape_tag() -> StringName:
	return TAG_ESCAPE_BOAT if _slot_active(&"escape", &"esc_boat_quay") else TAG_ESCAPE_VAN


func _scalar(id: StringName, fallback: Variant) -> Variant:
	var v: Variant = variant(id)
	return fallback if v == null else v


func _rare(id: StringName) -> bool:
	var v: Variant = variant(&"rare")
	return v is Array and (v as Array).has(id)


func _slot_active(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = variant(group)
	return v is Array and (v as Array).has(slot_id)


func _target_of(device: Node) -> Node:
	var t: Variant = device.get(&"target")
	if t is NodePath and not (t as NodePath).is_empty():
		return device.get_node_or_null(t as NodePath)
	return null


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
