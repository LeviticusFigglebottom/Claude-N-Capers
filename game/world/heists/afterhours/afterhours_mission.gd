## Afterhours (The Velvet nightclub) mission flow (D-165, AH-A1). Owner: ENV A. Design: docs/design/heists/afterhours.md
## §Objectives / §Rare events / §Escape, D-075 / D-143 rulings. Contract: heist_map.md §6 (HeistMission API, EventBus and
## nodes of this map found by objective_tag; the tags below are agreed with ENV C).
##
## Stealth (civilian start, D-065: the runtime's rule, not the mission's): casing (optional) -> gear (the first
## item.gear pickup; Mercer names the rolled gear_drop slot) -> keycard -> office (the reader opens the office door)
## -> safe_code (skipped once the safe opens) -> safe (keypad or drill) -> safe_loot -> secure (3 cash bags at the
## van) -> escape. Optional: product (the parcels), count_room (the count's cash).
## Loud (alarm): the club sound cuts and the house lights come up (ClubSound / ClubLights, C's nodes), the safe locks
## down (keypad dead: drill or C4), the office door becomes breachable, the crowd stampedes (civilians_flee), the DJ
## calls the alarm; escape_wait: the van returns at the second assault's FADE or SECURE_WAIT_S after the first
## secured bag, whichever is later.
## Rare events: count_left_open (the safe starts open), extra_product (+2 parcels), off_duty_cop (a police observer in a
## VIP booth), co_op_pickup (two couriers at 14:00, stealth), rooftop_watch (the perch opens loud); vip_party is data
## (the variant table's slot effects).
extends HeistMission

const REQUIRED_BAGS: int = 3
## Loud: the van returns this long after the first secured bag (or at the second assault's FADE, whichever is later).
const SECURE_WAIT_S: float = 300.0
## co_op_pickup: the couriers arrive at 14:00 heist time.
const COURIER_TIME_S: float = 840.0
const COURIER_COUNT: int = 2
const COURIER_CHECK_S: float = 1.0
const COURIER_REACH_M: float = 4.0
## The DJ's shout-outs while the club plays (stealth, dj_on).
const DJ_SHOUTOUT_S: float = 180.0
## After the alarm: Mercer's "crowd's out" once the stampede had this long.
const CROWD_OUT_S: float = 25.0
const EXTRA_PRODUCT: int = 2
## Loud: C4 charges that open the office door (the keycard door becomes breachable).
const OFFICE_CHARGES: int = 1
const ITEM_GEAR: StringName = &"item.gear"
const ITEM_KEYCARD: StringName = &"item.keycard"
const ITEM_CODE_NOTE: StringName = &"item.code_note"
const LOOT_SAFE: StringName = &"loot.cash_bricks"
const LOOT_PRODUCT: StringName = &"loot.parcels"
const LOOT_COUNT: StringName = &"loot.cash"
const SPEAKER_DJ: StringName = &"dj"
const RNG_STREAM: StringName = &"afterhours"

## Objective tags on C's map (agreed contract).
const TAG_GEAR: StringName = &"gear"
const TAG_KEYCARD: StringName = &"keycard"
const TAG_OFFICE_DOOR: StringName = &"office_door"
const TAG_OFFICE_READER: StringName = &"office_reader"
const TAG_SAFE_CODE: StringName = &"safe_code"
const TAG_SAFE: StringName = &"safe"
const TAG_SAFE_DRILL: StringName = &"safe_drill"
const TAG_SAFE_LOOT: StringName = &"safe_loot"
const TAG_PRODUCT: StringName = &"product"
const TAG_COUNT: StringName = &"count_cash"
const TAG_LOOT_SECURE: StringName = &"loot_secure"
const TAG_ESCAPE: StringName = &"escape_van"
const TAG_COURIER: StringName = &"cartel_courier"
const TAG_OFF_DUTY: StringName = &"civ_offduty"
const TAG_ROOFTOP: StringName = &"rooftop_watch"
const TAG_FLEE: StringName = &"civ_flee"
## C's audio / lighting nodes (afterhours.md §Audio/lighting), found by name anywhere under the map root.
const CLUB_SOUND: String = "ClubSound"
const CLUB_LIGHTS: String = "ClubLights"
## The DJ's lines play at this node (objective_tag / meta; the stage).
const TAG_DJ_STAGE: StringName = &"dj_stage"
## The off-duty cop: a police-preset observer who radios the alarm (QC-76; no pager).
const OFF_DUTY_ENEMY: StringName = &"enemy.patrol_officer"

var safe_open: bool = false
var couriers: Array[NpcBase] = []
var off_duty_cop: NpcBase = null
var lockdown: bool = false
var escape_open: bool = false
var _van_fade: bool = false
var _secure_wait_done: bool = false
var _first_bag_t: float = -1.0
var _code_said: bool = false
var _gear_said: bool = false
var _keycard_said: bool = false
var _required_said: bool = false
var _assault_fades: int = 0


func _on_mission_start() -> void:
	own_last_pager_line = true
	say(&"vo.mercer.afterhours_intro")
	add_objective(&"casing", &"objective.afterhours.casing", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"gear", &"objective.afterhours.gear", Enums.ObjectiveState.ACTIVE, {"marker_tags": [TAG_GEAR]})
	add_objective(&"keycard", &"objective.afterhours.keycard", Enums.ObjectiveState.ACTIVE, {"marker_tags": [TAG_KEYCARD]})
	require_items(&"keycard", ITEM_KEYCARD)
	add_objective(&"office", &"objective.afterhours.office", Enums.ObjectiveState.ACTIVE,
		{"marker_tags": [TAG_OFFICE_DOOR, TAG_OFFICE_READER]})
	add_objective(&"safe_code", &"objective.afterhours.safe_code", Enums.ObjectiveState.ACTIVE,
		{"marker_tags": [TAG_SAFE_CODE], "alternative": &"safe", "optional": true})
	add_objective(&"safe", &"objective.afterhours.safe", Enums.ObjectiveState.ACTIVE,
		{"methods": [&"code", &"drill"], "marker_tags": [TAG_SAFE, TAG_SAFE_DRILL]})
	add_objective(&"safe_loot", &"objective.afterhours.safe_loot", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [TAG_SAFE_LOOT]})
	add_objective(&"secure", &"objective.afterhours.secure", Enums.ObjectiveState.ACTIVE,
		{"bags": REQUIRED_BAGS, "count": 0, "total": REQUIRED_BAGS, "optional_more": true, "marker_tags": [TAG_LOOT_SECURE]})
	require_loot(&"secure", REQUIRED_BAGS)
	add_objective(&"product", &"objective.afterhours.product", Enums.ObjectiveState.ACTIVE,
		{"optional": true, "side": true, "marker_tags": [TAG_PRODUCT]})
	var counting: bool = _slot_active(&"count_room", &"count_running")
	add_objective(&"count_room", &"objective.afterhours.count_room",
		Enums.ObjectiveState.ACTIVE if counting else Enums.ObjectiveState.HIDDEN,
		{"optional": true, "side": true, "marker_tags": [TAG_COUNT]})
	add_objective(&"escape_wait", &"objective.afterhours.escape_wait", Enums.ObjectiveState.HIDDEN, {})
	add_objective(&"escape", &"objective.afterhours.escape", Enums.ObjectiveState.HIDDEN, {"marker_tags": [TAG_ESCAPE]})
	on_event(&"item_picked_up", _on_item_picked_up)
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_started", _on_device_started)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"loot_secured", _on_bag_secured)
	on_event(&"loot_picked", _on_loot_picked)
	on_event(&"assault_phase_changed", _on_assault_phase_changed)
	_spawn_loot()
	_rare_start()
	if variant(&"dj_set") is Array and _slot_active(&"dj_set", &"dj_on"):
		start_timer(&"dj_shoutout", DJ_SHOUTOUT_S, _dj_shoutout)


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING:
		complete(&"casing")
	if new_phase == Enums.HeistPhase.LOUD:
		_go_loud()


func _on_alarm(_reason: StringName) -> void:
	_go_loud()


func _on_pager_answered(total: int) -> void:
	if total == pager_cap():
		say(&"vo.mercer.afterhours_last_pager", {"answered": total})


# --- Stealth flow ---------------------------------------------------------------------------

## The gear_drop slot's Mercer line (B: one line per slot, no text args).
func gear_line() -> StringName:
	for slot: StringName in [&"gear_wc", &"gear_cloak", &"gear_booth", &"gear_van"]:
		if _slot_active(&"gear_drop", slot):
			return StringName("vo.mercer.afterhours_%s" % slot)
	return &""


func _on_item_picked_up(item_id: StringName, _crew_slot: int) -> void:
	match item_id:
		ITEM_GEAR:
			if objective_state(&"gear") == Enums.ObjectiveState.ACTIVE:
				complete(&"gear")
			if not _gear_said:
				_gear_said = true
				say(&"vo.mercer.afterhours_gear_picked")
		ITEM_KEYCARD:
			if not _keycard_said and objective_state(&"office") == Enums.ObjectiveState.ACTIVE:
				_keycard_said = true  # require_items already completed [keycard] on this pickup
				say(&"vo.mercer.afterhours_keycard_found")
		ITEM_CODE_NOTE:
			if objective_state(&"safe_code") == Enums.ObjectiveState.ACTIVE:
				complete(&"safe_code")
			if not _code_said and not safe_open:
				_code_said = true
				say(&"vo.mercer.afterhours_code_found")


func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_OFFICE_READER) or _is_tagged(interactable_net_id, TAG_OFFICE_DOOR):
		_office_open()
	elif _is_tagged(interactable_net_id, TAG_SAFE):
		for sf: Node in find_tagged(TAG_SAFE):
			if bool(sf.get(&"opened")):
				open_safe(&"drill" if kind == &"drill" else &"code")


func _office_open() -> void:
	if objective_state(&"office") != Enums.ObjectiveState.ACTIVE:
		return
	complete(&"office")
	_skip_if_active(&"keycard")
	say(&"vo.mercer.afterhours_office_open")
	if _slot_active(&"product_location", &"prod_private"):
		say(&"vo.mercer.afterhours_lasers")


func _on_device_started(device_net_id: int, _kind: StringName, _seconds: float) -> void:
	if _is_tagged(device_net_id, TAG_SAFE_DRILL):
		say(&"vo.mercer.afterhours_drill_started")


func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_SAFE_DRILL):
		say(&"vo.mercer.afterhours_drill_jam")


func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_SAFE_DRILL):
		say(&"vo.mercer.afterhours_drill_done")
		open_safe(&"drill")


## Open the safe (`method` &"code" / &"drill" / &"left_open"; B's achievements read objective.safe.open_method:
## safe_code is not completed when drilled).
func open_safe(method: StringName) -> void:
	if safe_open:
		return
	safe_open = true
	update_objective_data(&"safe", {"open_method": method})
	for s: Node in find_tagged(TAG_SAFE):
		if s.has_method(&"swing_open"):
			s.call(&"swing_open")
		elif s.has_method(&"unlock"):
			s.call(&"unlock")
	complete(&"safe")
	_skip_if_active(&"safe_code")
	_spawn_safe_bags()
	activate(&"safe_loot")
	if method != &"left_open":
		say(&"vo.mercer.afterhours_safe_open")


func _on_loot_picked(bag_net_id: int, _crew_slot: int) -> void:
	var bag: LootBag = Ids.lookup(bag_net_id) as LootBag
	var loot_id: StringName = bag.loot_id if bag != null else &""
	if loot_id == LOOT_SAFE and objective_state(&"safe_loot") == Enums.ObjectiveState.ACTIVE:
		complete(&"safe_loot")
	elif loot_id == LOOT_PRODUCT and objective_state(&"product") == Enums.ObjectiveState.ACTIVE:
		complete(&"product")
		say(&"vo.mercer.afterhours_product_found")
	elif loot_id == LOOT_COUNT and objective_state(&"count_room") == Enums.ObjectiveState.ACTIVE:
		complete(&"count_room")
		say(&"vo.mercer.afterhours_count_room")


func _on_bag_secured(_bag_net_id: int, _loot_id: StringName, _value: int) -> void:
	if _first_bag_t < 0.0:
		_first_bag_t = elapsed_s
		if went_loud:
			start_timer(&"secure_wait", SECURE_WAIT_S, _on_secure_wait)
	update_objective_data(&"secure", {"count": bags_secured, "total": REQUIRED_BAGS})
	if bags_secured >= REQUIRED_BAGS and not _required_said:
		_required_said = true
		say(&"vo.mercer.afterhours_required_secured")
	_try_escape()


# --- Loud flow --------------------------------------------------------------------------------

func _go_loud() -> void:
	if lockdown:
		return
	lockdown = true
	_call_map(CLUB_SOUND, &"cut")
	_call_map(CLUB_LIGHTS, &"set_state", [&"house"])
	cancel_timer(&"dj_shoutout")
	say(&"vo.dj.afterhours_alarm", _dj_context(), SPEAKER_DJ)
	say(&"vo.mercer.afterhours_music_cut")
	if not safe_open:
		update_objective_data(&"safe", {"methods": [&"drill", &"c4"], "lockdown": true})
		_skip_if_active(&"safe_code")
		for s: Node in find_tagged(TAG_SAFE):
			if &"methods" in s:
				var m: Array = (s.get(&"methods") as Array).filter(func(x: Variant) -> bool: return StringName(x) != &"code")
				s.set(&"methods", m)
	for d: Node in find_tagged(TAG_OFFICE_DOOR):  # the keycard door takes C4 / a police breach loud (the reader still works)
		var door: Door = d as Door
		if door != null and door.locked:
			door.charges_required = maxi(door.charges_required, OFFICE_CHARGES)
			door.relock(Door.Lock.ELECTRONIC, false)
	civilians_flee(TAG_FLEE)
	start_timer(&"crowd_out", CROWD_OUT_S, func() -> void: say(&"vo.mercer.afterhours_crowd_out"))
	if _rare(&"rooftop_watch"):
		set_sniper_perches_open(TAG_ROOFTOP, true)
	if not escape_open:
		activate(&"escape_wait")
		if _first_bag_t >= 0.0:
			start_timer(&"secure_wait", maxf(SECURE_WAIT_S - (elapsed_s - _first_bag_t), 0.0), _on_secure_wait)


func _on_secure_wait() -> void:
	_secure_wait_done = true
	_try_escape()


## The van returns at the SECOND assault's FADE (afterhours.md §Escape).
func _on_assault_phase_changed(assault_phase: int, _wave_index: int) -> void:
	if assault_phase != Enums.AssaultPhase.FADE:
		return
	_assault_fades += 1
	if _assault_fades >= 2:
		_van_fade = true
		_try_escape()


func _try_escape() -> void:
	if escape_open or bags_secured < REQUIRED_BAGS:
		return
	if went_loud and not (_van_fade and _secure_wait_done):
		if objective_state(&"escape_wait") == Enums.ObjectiveState.ACTIVE:
			say(&"vo.mercer.afterhours_van_eta")
		return
	escape_open = true
	if objective_state(&"escape_wait") == Enums.ObjectiveState.ACTIVE:
		complete(&"escape_wait")
	activate(&"escape")
	say(&"vo.mercer.afterhours_escape")
	activate_escape(TAG_ESCAPE)


# --- Loot, rare events, DJ ------------------------------------------------------------------

## The product (scalar product_bags, +EXTRA_PRODUCT with the rare event) and the count's cash spawn at their tagged
## loot markers (the active variant slots' markers only) at the start; the safe's bags when it opens.
func _spawn_loot() -> void:
	var product_n: int = int(variant(&"product_bags")) if variant(&"product_bags") != null else 3
	if _rare(&"extra_product"):
		product_n += EXTRA_PRODUCT
	spawn_loot(LOOT_PRODUCT, TAG_PRODUCT, product_n)
	if _slot_active(&"count_room", &"count_running"):
		spawn_loot(LOOT_COUNT, TAG_COUNT, 2)


## The safe's cash (scalar safe_bags, +1 with count_done) at the safe_loot markers, when the safe opens (PD2: the
## loot is there once the door swings; nothing to grab through a shut safe; P's route 1 looked for it then).
func _spawn_safe_bags() -> void:
	var safe_n: int = int(variant(&"safe_bags")) if variant(&"safe_bags") != null else REQUIRED_BAGS + 1
	if _slot_active(&"count_room", &"count_done"):
		safe_n += 1
	spawn_loot(LOOT_SAFE, TAG_SAFE_LOOT, safe_n)


func _rare_start() -> void:
	if _rare(&"count_left_open"):
		open_safe(&"left_open")
	if _rare(&"off_duty_cop"):
		# QC-76: a police-role unit (no pager), CALM in the booth: a police-preset observer who radios the alarm on a
		# masked crew member (StealthDirector, as RT's convoy escorts); the look comes off the spawn tag (D).
		for u: NpcBase in spawn_units(OFF_DUTY_ENEMY, 1, TAG_OFF_DUTY):
			u.set_meta(StealthDirector.META_ALARM_REASON, &"off_duty_cop")
			off_duty_cop = u
		if off_duty_cop != null:
			say(&"vo.mercer.afterhours_off_duty_cop")
	if _rare(&"co_op_pickup"):
		schedule_at(COURIER_TIME_S, &"couriers", _couriers_arrive)


## co_op_pickup: the couriers walk in as calm guards on their patrol route (the SpawnPoints tagged TAG_COURIER and their
## patrol graph, C's G21 -> G13 -> the product room); a body or a masked crew member alarms them like any guard, and
## so does finding the product gone (_check_couriers).
func _couriers_arrive() -> void:
	if went_loud:
		return
	couriers.clear()
	for n: Node in spawn_guards(COURIER_COUNT, TAG_COURIER):
		couriers.append(n as NpcBase)
	if not couriers.is_empty():
		say(&"vo.mercer.afterhours_couriers")
		start_timer(&"courier_check", COURIER_CHECK_S, _check_couriers)


## A courier within COURIER_REACH_M of a product marker with no parcels left there raises the alarm (stealth only).
func _check_couriers() -> void:
	if went_loud:
		return
	for c: NpcBase in couriers:
		if not is_instance_valid(c) or not c.alive:
			continue
		for m: Node3D in loot_markers(TAG_PRODUCT):
			if m.is_visible_in_tree() and c.global_position.distance_to(m.global_position) <= COURIER_REACH_M \
					and _parcels_near(m.global_position) == 0:
				raise_alarm(&"couriers_product_gone", c.net_id)
				return
	start_timer(&"courier_check", COURIER_CHECK_S, _check_couriers)


func _parcels_near(pos: Vector3) -> int:
	var lm: LootManager = _runtime.service(G.SVC_LOOT) as LootManager if _runtime != null else null
	if lm == null:
		return 0
	return lm.bags().filter(func(b: LootBag) -> bool:
		return b.loot_id == LOOT_PRODUCT and b.global_position.distance_to(pos) <= COURIER_REACH_M).size()


func _dj_shoutout() -> void:
	if went_loud:
		return
	var n: int = GameRng.stream(RNG_STREAM).randi_range(1, 3)
	say(StringName("vo.dj.afterhours_shoutout_%d" % n), _dj_context(), SPEAKER_DJ)
	start_timer(&"dj_shoutout", DJ_SHOUTOUT_S, _dj_shoutout)


# --- Helpers ----------------------------------------------------------------------------------

func _call_map(node_name: String, method: StringName, args: Array = []) -> void:
	var map_root: Node = get_parent()
	var n: Node = map_root.find_child(node_name, true, false) if map_root != null else null
	if n != null and n.has_method(method):
		n.callv(method, args)


## {"position": the stage} for the DJ's positional lines ({} without a dj_stage node).
func _dj_context() -> Dictionary:
	var stage: Array[Node3D] = loot_markers(TAG_DJ_STAGE)
	return {"position": stage[0].global_position} if not stage.is_empty() else {}


func _skip_if_active(objective_id: StringName) -> void:
	if objective_state(objective_id) == Enums.ObjectiveState.ACTIVE:
		update_objective_data(objective_id, {"skipped": true})
		complete(objective_id)


func _rare(id: StringName) -> bool:
	return rare_effects().has(id)


func _slot_active(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = variant(group)
	return v is Array and (v as Array).has(slot_id)


func _is_tagged(net_id: int, tag: StringName) -> bool:
	if net_id == 0:
		return false
	for n: Node in find_tagged(tag):
		var nid: Variant = n.get(&"net_id")
		if nid != null and int(nid) == net_id:
			return true
	return false
