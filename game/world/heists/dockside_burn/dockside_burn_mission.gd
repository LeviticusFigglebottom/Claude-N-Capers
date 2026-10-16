## Dockside Burn (Ortega Cold Storage) mission flow. Owner: ENV C (C3).
## Design: docs/design/heists/dockside_burn.md §Objectives / §Loud / §Rare events / §Escape (APPROVED,
## D-064). Contract heist_map.md §6: uses only the HeistMission API, EventBus, Services and nodes of
## this map (prefabs found by objective_tag or by their path under Gameplay / Variants).
##
## Loud only: cartel phase (the Co-op's gunmen) -> the police after `police_delay_s` (D-064 Q1) ->
## breach -> find the product -> burn it (fire shutters drop 5 s after the warning, D-064 Q6) -> cash
## (strongroom thermal drill or the count-room cage) and/or the weapons containers -> secure >= 4 bags
## (product and extra bags are a bonus, D-064 Q2) -> the escape is called when [burn] and [secure] are
## done, arrives after `escape_eta_s` -> escape.
## ENV A parts (G2): HeistMission.police_delay_s holds the director (QC-35); burn_point telegraphs
## (cue.burn_warning) and lights its fire volume (QC-38); padlocks on the roller doors and the
## container latches (QC-37). Timed cartel reinforcements use spawn_guards (QC-25).
extends HeistMission

const MIN_BAGS: int = 4
## D-115 (DB-2, doc §Loot path): only cash bricks and weapon crates count toward the MIN_BAGS; the product
## (loot.contraband) and anything else pays but does not count.
const REQUIRED_LOOT: Array[StringName] = [&"loot.cash_bricks", &"loot.weapon_crate"]
## The burn_point's telegraph (InteractionTweak.burn_warning_s): the shutters drop when it lights.
const SHUTTER_WARNING_S: float = 5.0
const FOG_BOAT_DELAY_S: float = 30.0
const REINFORCEMENTS_AT_S: float = 180.0
const REINFORCEMENT_GUNMEN: int = 4
const FOG_LIFTS_AT_S: float = 360.0
const TAG_BURN: StringName = &"burn"
const TAG_PRODUCT: StringName = &"product"
const TAG_STRONGROOM_DRILL: StringName = &"strongroom_drill"
const TAG_STRONGROOM_DOOR: StringName = &"strongroom_door"
const TAG_COUNT_CAGE: StringName = &"count_cage"
const TAG_CASH: StringName = &"cash_bricks"
const TAG_PADLOCK: StringName = &"padlock"
## D-115 (DB-4, doc §Loot path / §Stealth routes): the thermite bag starts at the crew's spawn. One loot_spawn per
## spawn, tagged `thermite_<spawn>` (THERMITE_SPAWNS); the pre-C map has only the gate bag, tagged TAG_THERMITE.
const TAG_THERMITE: StringName = &"thermite"
const THERMITE_SPAWNS: Array[StringName] = [&"gate", &"lane", &"pontoon"]
const TAG_LIFT: StringName = &"goods_lift"
const TAG_BREAKER: StringName = &"lift_breaker"
const TAG_POLICE_GATE: StringName = &"police_gate"
const TAG_ESCAPE_VAN: StringName = &"escape_van"
const TAG_ESCAPE_BOAT: StringName = &"escape_boat"
## PO-5 (D-089 markers): the rolled escape's secure zone (VanSecureE1 / VanSecureE2 / BoatSecureE3).
const TAG_LOOT_SECURE: StringName = &"loot_secure"
## A yard container's padlock (Props/Exterior/ContainerKn/Padlock): `padlock_k1` .. `padlock_k6`.
const TAG_CONTAINER_PADLOCK: String = "padlock_%s"
## warehouse_entry slot -> the door it opens (its objective_tag is the slot id).
const ENTRY_DOORS: Dictionary = {&"door_office": "O1Front", &"door_quay": "ANQuay", &"door_dock": "DockRoller"}
## Building doors whose first use is the breach (doc `[breach]`).
const ENTRY_TAGS: Array[StringName] = [&"door_office", &"door_quay", &"oc_west_door", &"pl_west_door", &"pk_quay_door",
	&"an_east_door", &"mc_west_door", &"padlock", &"hall_roller", &"an_roller", &"pk_roller", &"door_dock"]
const RARE_INFORMANT: StringName = &"informant_tip"
const RARE_EXTRA_CONTAINER: StringName = &"extra_container"
const RARE_POLICE_TIPPED: StringName = &"police_tipped"
const RARE_REINFORCEMENTS: StringName = &"cartel_reinforcements"
const RARE_FOG: StringName = &"fog_lifts"
const SPECIAL_LONGSHOT: StringName = &"longshot"
## D-115 (DB-13): Mercer's Longshot line by the SNIPER_PERCH tag of the perch the Longshot holds (doc §Loud: S1 the
## Pier 10 crane, S2 the Bellweather roof; S3 / S4 have no line).
const SNIPER_LINES: Dictionary = {
	&"s1": &"vo.mercer.dockside_burn_sniper_crane", &"s2": &"vo.mercer.dockside_burn_sniper_roof",
}
const CONTAINER_KEYS: Array[String] = ["k1", "k2", "k3", "k4", "k5", "k6"]
## Fire shutters (layout SHUTTERS): product slot -> doors under Gameplay/Doors.
const SHUTTERS: Dictionary = {
	"prod_chamber_a": ["ChamberANorth", "PKChamberA", "ChamberASpine"],
	"prod_chamber_b": ["ChamberBNorth", "SpineChamberB", "ChamberBSouth"],
	"prod_packing": ["PKChamberA", "PKRoller", "PKQuay", "PKPlant", "PKWorkshop"],
}
const DOORS: NodePath = ^"../Gameplay/Doors"
const CRATES: NodePath = ^"../Gameplay/Containers"

var _police_started: bool = false
var _burn_started: bool = false
var _burned: bool = false
var _escape_open: bool = false
var _cartel_awake: bool = false
var _gunmen_down: int = 0
var _weapons: Array[String] = []
var _weapons_found: bool = false
var _sniper_lines_said: Dictionary = {}
## DB-2: required bags secured (REQUIRED_LOOT only; HeistMission.bags_secured counts every bag).
var _required_secured: int = 0


func _on_mission_start() -> void:
	# D-117 §6: the briefing lines (lines.tres event `briefing`) play on the briefing screen only, never in-heist.
	say(&"vo.mercer.dockside_burn_intro")
	say(&"vo.reyes.dockside_burn_contact_intro", {}, &"reyes")
	# [cartel] covers the whole yard (thin out the gunmen): no marker, like casing.
	add_objective(&"cartel", &"objective.dockside_burn.cartel", Enums.ObjectiveState.ACTIVE, {"optional": true})
	add_objective(&"breach", &"objective.dockside_burn.breach", Enums.ObjectiveState.ACTIVE, {"marker_tags": _entry_tags()})
	add_objective(&"product", &"objective.dockside_burn.product", Enums.ObjectiveState.ACTIVE,
		{"location": variant(&"product_location"), "marker_tags": [TAG_PRODUCT]})
	add_objective(&"burn", &"objective.dockside_burn.burn", Enums.ObjectiveState.HIDDEN, {"marker_tags": [TAG_BURN]})
	var countroom: bool = _slot_active(&"cash_location", &"cash_countroom")
	add_objective(&"strongroom", &"objective.dockside_burn.strongroom",
		Enums.ObjectiveState.HIDDEN if countroom else Enums.ObjectiveState.ACTIVE,
		{"alternative": &"count_cage", "marker_tags": [TAG_STRONGROOM_DRILL]})
	# The cage and the cash stacks of the active location (the cage exists only with cash_countroom).
	add_objective(&"count_cage", &"objective.dockside_burn.count_cage",
		Enums.ObjectiveState.ACTIVE if countroom else Enums.ObjectiveState.HIDDEN,
		{"alternative": &"strongroom", "marker_tags": [TAG_COUNT_CAGE, TAG_CASH]})
	add_objective(&"containers", &"objective.dockside_burn.containers", Enums.ObjectiveState.ACTIVE,
		{"marker_tags": _container_tags(CONTAINER_KEYS)})
	add_objective(&"secure", &"objective.dockside_burn.secure", Enums.ObjectiveState.ACTIVE,
		{"bags": MIN_BAGS, "count": 0, "total": MIN_BAGS, "optional_more": true, "marker_tags": [TAG_LOOT_SECURE]})
	add_objective(&"escape_wait", &"objective.dockside_burn.escape_wait", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [_escape_tag()]})
	add_objective(&"escape", &"objective.dockside_burn.escape", Enums.ObjectiveState.HIDDEN,
		{"marker_tags": [_escape_tag()]})
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_started", _on_device_started)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"loot_secured", _on_bag_secured)
	on_event(&"npc_alert_state_changed", _on_npc_alert)
	on_event(&"npc_killed", _on_npc_killed)
	on_event(&"special_spawned", _on_special_spawned)
	_apply_thermite()
	_apply_cash(countroom)
	_apply_product()
	_apply_containers()
	_apply_lift()
	_apply_entry_and_perch()
	_watch_entry_doors()
	_schedule_police()
	_schedule_rare_events()


# --- Setup ------------------------------------------------------------------------------------

## Cash: `cash_bags` split over the two stacks of the active location. The count-room stacks wait for
## the cage; with the cash in the count room the strongroom drill is off and its door stays shut.
func _apply_cash(countroom: bool) -> void:
	_split_count(find_tagged(TAG_CASH), int(_scalar(&"cash_bags", 6)))
	if countroom:
		for d: Node in find_tagged(TAG_STRONGROOM_DRILL):
			_set_enabled(d, false)
			(d as Node3D).visible = false
		for ls: Node in find_tagged(TAG_CASH):
			_set_enabled(ls, false)


## DB-4: only the thermite bag of the crew's spawn (crew_spawn_tag: preplan_spawn_lane / _pontoon, else the gate)
## is shown and usable; the other spawns' bags are hidden, disabled and emptied. Without a bag tagged for the
## chosen spawn (today's map) the gate bag stays.
func _apply_thermite() -> void:
	var spawn: StringName = &"gate"
	for key: StringName in THERMITE_SPAWNS:
		if String(crew_spawn_tag()).ends_with(String(key)):
			spawn = key
	var keep: Array[Node] = find_tagged(StringName("thermite_%s" % spawn))
	if keep.is_empty():
		keep = find_tagged(&"thermite_gate")
		keep.append_array(find_tagged(TAG_THERMITE))
	var all: Array[Node] = find_tagged(TAG_THERMITE)
	for key2: StringName in THERMITE_SPAWNS:
		all.append_array(find_tagged(StringName("thermite_%s" % key2)))
	for bag: Node in all:
		if keep.has(bag):
			continue
		_set_enabled(bag, false)
		if "remaining" in bag:
			bag.set(&"remaining", 0)
		if bag is Node3D:
			(bag as Node3D).visible = false


func _apply_product() -> void:
	_split_count(find_tagged(TAG_PRODUCT), int(_scalar(&"product_bags", 6)))


## Weapons containers: the rolled pair (+1 with `extra_container`: the Nth of the other four, N =
## the rolled `extra_container_pick`). Every crate stack waits for its container's padlock.
func _apply_containers() -> void:
	for k: Variant in variant(&"weapons_containers") if variant(&"weapons_containers") is Array else []:
		_weapons.append(String(k))
	if _rare(RARE_EXTRA_CONTAINER):
		var others: Array[String] = []
		for k2: String in CONTAINER_KEYS:
			if not _weapons.has(k2):
				others.append(k2)
		if not others.is_empty():
			_weapons.append(others[int(_scalar(&"extra_container_pick", 0)) % others.size()])
	for k3: String in CONTAINER_KEYS:
		var crates: Node3D = get_node_or_null(NodePath(String(CRATES) + "/Crates" + k3.to_upper())) as Node3D
		if crates == null:
			continue
		_set_enabled(crates, false)
		crates.visible = false
	for k4: String in CONTAINER_KEYS:
		var latch: Node = get_node_or_null(NodePath(String(CRATES) + "/Latch" + k4.to_upper()))
		if latch != null and latch.has_signal(&"opened"):
			latch.connect(&"opened", _open_container.bind(k4))
	update_objective_data(&"containers", {"count": _weapons.size()})
	if _rare(RARE_INFORMANT):
		update_objective_data(&"containers", {"revealed": _weapons.duplicate(), "marker_tags": _container_tags(_weapons)})
		say(&"vo.mercer.dockside_burn_containers_hint", {"informant": true})


## Goods lift: dead until the E1 breaker is reset (`lift_dead`).
func _apply_lift() -> void:
	if _slot_active(&"goods_lift", &"lift_dead"):
		_set_lift_enabled(false)


## Warehouse entry: the variant's door is unlocked and open; the roof perch opens the head-house door.
func _apply_entry_and_perch() -> void:
	for sid: StringName in ENTRY_DOORS:
		if _slot_active(&"warehouse_entry", sid):
			var d: Node = get_node_or_null(NodePath(String(DOORS) + "/" + String(ENTRY_DOORS[sid])))
			if d != null:
				d.call(&"unlock")
				d.call(&"set_open", true)
				var lock: Node = d.get_node_or_null(^"Padlock")
				if lock != null:
					_set_enabled(lock, false)
	if _slot_active(&"player_perch", &"perch_roof"):
		var rd: Node = get_node_or_null(NodePath(String(DOORS) + "/RoofDoor"))
		if rd != null:
			rd.call(&"unlock")


## A building entry door opening (lockpicked, its padlock picked or sawn, breached) is the breach.
## Connected after _apply_entry_and_perch so the variant's open door does not count.
func _watch_entry_doors() -> void:
	for tag: StringName in ENTRY_TAGS:
		for d: Node in find_tagged(tag):
			if d.has_signal(&"open_changed") and not d.is_connected(&"open_changed", _on_entry_door):
				d.connect(&"open_changed", _on_entry_door)


func _on_entry_door(open: bool, _by_net_id: int) -> void:
	if open:
		_breach()


## Cartel phase, then the police (D-064 Q1, QC-35): police_delay_s holds the assault director for the
## rolled delay; the same timer opens the closure gates (baked closed, D-073), says the lines and
## closes [cartel].
## A compressed director (launch option `director_tweak`, e.g. test_p3_loud) compresses the cartel
## hold by the same factor as its first CONTROL phase (first_control_s vs the shipped tweak); the
## shipped tweak keeps the rolled 60 / 90 / 120 s.
func _schedule_police() -> void:
	var delay: float = 0.0 if _rare(RARE_POLICE_TIPPED) else float(_scalar(&"police_delay_s", 90.0))
	delay *= _director_time_scale()
	police_delay_s = delay
	start_timer(&"police_delay", delay, _on_police_called)


func _schedule_rare_events() -> void:
	if _rare(RARE_REINFORCEMENTS) and difficulty >= Enums.Difficulty.HAZARDOUS:
		schedule_at(REINFORCEMENTS_AT_S, &"reinforcements", _on_reinforcements)
	if _rare(RARE_FOG):
		schedule_at(FOG_LIFTS_AT_S, &"fog_lifts", _on_fog_lifts)


func _on_police_called() -> void:
	if _police_started:
		return
	_police_started = true
	police_delay_s = 0.0
	say(&"vo.mercer.dockside_burn_police_called")
	if _slot_active(&"east_gangway", &"gangway_down"):
		say(&"vo.mercer.dockside_burn_gangway")
	for g: Node in find_tagged(TAG_POLICE_GATE):
		g.call(&"unlock")
		g.call(&"set_open", true)
	if objective_state(&"cartel") == Enums.ObjectiveState.ACTIVE:
		update_objective_data(&"cartel", {"gunmen_down": _gunmen_down})
		complete(&"cartel")


func _on_reinforcements() -> void:
	say(&"vo.mercer.dockside_burn_reinforcements")
	spawn_guards(REINFORCEMENT_GUNMEN, &"cartel_reinf")


func _on_fog_lifts() -> void:
	say(&"vo.mercer.dockside_burn_fog_lifts")
	var we: WorldEnvironment = get_node_or_null(^"../Lighting/WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.fog_density *= 0.3


# --- Events -----------------------------------------------------------------------------------

## First cartel gunman awake (TODO(QC-36): the mission cannot tell a gunman from a worker by net id;
## the night shift never reaches COMBAT, so COMBAT is the cartel's).
func _on_npc_alert(_npc_net_id: int, _old_state: int, new_state: int) -> void:
	if _cartel_awake or new_state != Enums.AlertState.COMBAT:
		return
	_cartel_awake = true
	say(&"vo.mercer.dockside_burn_cartel_awake")


## Longshots (L4.7, DB-13): the line names the perch the Longshot holds (its claimed SNIPER_PERCH, else the
## nearest; tag s1 = the crane, s2 = the roof), once per perch.
func _on_special_spawned(npc_net_id: int, special_type: StringName) -> void:
	if not String(special_type).contains(String(SPECIAL_LONGSHOT)):
		return
	var perch: TacticalPoint = sniper_perch_of(npc_net_id)
	if perch == null:
		return
	for tag: StringName in SNIPER_LINES:
		if perch.tags.has(tag) and not _sniper_lines_said.has(tag):
			_sniper_lines_said[tag] = true
			say(SNIPER_LINES[tag])


func _on_npc_killed(_npc_net_id: int, _killer_net_id: int, _info: Dictionary) -> void:
	if not _police_started:
		_gunmen_down += 1


func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	for tag: StringName in ENTRY_TAGS:
		if _is_tagged(interactable_net_id, tag):
			_breach()
			return
	if _is_tagged(interactable_net_id, TAG_PRODUCT):
		_product_found()


func _on_device_started(device_net_id: int, _kind: StringName, duration: float) -> void:
	if _is_tagged(device_net_id, TAG_BURN):
		_product_found()
		if not _burn_started:
			_burn_started = true
			say(&"vo.mercer.dockside_burn_burn_started")
			# The burn_point's telegraph starts when the burn ends: Mercer calls the shutters with it.
			start_timer(&"burn_warning", maxf(duration, 0.0), _on_burn_warning)
	elif _is_tagged(device_net_id, TAG_STRONGROOM_DRILL):
		_breach()
		say(&"vo.mercer.dockside_burn_strongroom_drill")
	elif _is_tagged(device_net_id, TAG_COUNT_CAGE):
		_breach()
		say(&"vo.mercer.dockside_burn_count_cage")


func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_BURN):
		_on_burn_done()
	elif _is_tagged(device_net_id, TAG_STRONGROOM_DRILL):
		for d: Node in find_tagged(TAG_STRONGROOM_DOOR):
			d.call(&"unlock")
			d.call(&"set_open", true)
		say(&"vo.mercer.dockside_burn_strongroom_open")
		complete(&"strongroom")
	elif _is_tagged(device_net_id, TAG_COUNT_CAGE):
		for ls: Node in find_tagged(TAG_CASH):
			_set_enabled(ls, true)
		complete(&"count_cage")
	elif _is_tagged(device_net_id, TAG_BREAKER):
		_set_lift_enabled(true)
	elif _is_tagged(device_net_id, TAG_PADLOCK):
		_breach()


func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_STRONGROOM_DRILL) or _is_tagged(device_net_id, TAG_COUNT_CAGE):
		say(&"vo.mercer.dockside_burn_drill_jam")


## DB-2: only REQUIRED_LOOT counts toward [secure] (HUD count / total); product and the rest pay only.
func _on_bag_secured(_bag_net_id: int, loot_id: StringName, _value: int) -> void:
	if not REQUIRED_LOOT.has(loot_id):
		return
	_required_secured += 1
	update_objective_data(&"secure", {"count": _required_secured, "total": MIN_BAGS})  # HUD: count / total bags
	if _required_secured == MIN_BAGS:
		complete(&"secure")
		say(&"vo.mercer.dockside_burn_required_secured")
	_try_escape()


# --- Flow -------------------------------------------------------------------------------------

func _breach() -> void:
	if objective_state(&"breach") == Enums.ObjectiveState.ACTIVE:
		complete(&"breach")
		say(&"vo.mercer.dockside_burn_breach")


func _product_found() -> void:
	if objective_state(&"product") == Enums.ObjectiveState.ACTIVE:
		complete(&"product")
		activate(&"burn")
		say(&"vo.mercer.dockside_burn_product_found")
		say(&"vo.mercer.dockside_burn_thermite_reminder")


## A container's padlock came off (picked or sawn; its latch opened): crates for a weapons container,
## nothing for the others.
func _open_container(k: String) -> void:
	if not _weapons.has(k):
		say(&"vo.mercer.dockside_burn_containers_hint")
		return
	var crates: Node3D = get_node_or_null(NodePath(String(CRATES) + "/Crates" + k.to_upper())) as Node3D
	if crates != null:
		crates.visible = true
		_set_enabled(crates, true)
	say(&"vo.mercer.dockside_burn_weapons_found")
	if not _weapons_found:
		_weapons_found = true
		complete(&"containers")


## The burn ended and the burn_point's telegraph runs (cue.burn_warning, burn_warning_s): Mercer
## calls the shutters.
func _on_burn_warning() -> void:
	if _burned:
		return
	say(&"vo.mercer.dockside_burn_burn_done", {"shutters_in_s": SHUTTER_WARNING_S})
	update_objective_data(&"burn", {"shutters_in_s": SHUTTER_WARNING_S})


## Burn done (D-064 Q6): the burn_point lit its fire volume (device_finished, after its telegraph):
## the burning room's fire shutters drop and bar now.
func _on_burn_done() -> void:
	if _burned:
		return
	_burned = true
	_drop_shutters()
	complete(&"burn")
	_try_escape()


func _drop_shutters() -> void:
	var slots: Variant = variant(&"product_location")
	if not (slots is Array) or (slots as Array).is_empty():
		return
	var sid: String = String((slots as Array)[0])
	for dn: Variant in SHUTTERS.get(sid, []):
		var d: Node = get_node_or_null(NodePath(String(DOORS) + "/" + String(dn)))
		if d == null:
			continue
		# Fire shutter: locked BARRED before it closes, so the close also drops its NavLink.
		d.set(&"lock", Door.Lock.BARRED)
		d.set(&"locked", true)
		d.call(&"set_open", false)
		_set_enabled(d, false)


## The escape is called when [burn] and [secure] are done; it arrives after `escape_eta_s` (+30 s
## for the boat with `fog_lifts`).
func _try_escape() -> void:
	if _escape_open or not _burned or _required_secured < MIN_BAGS:
		return
	_escape_open = true
	var tag: StringName = _escape_tag()
	var eta: float = float(_scalar(&"escape_eta_s", 120.0))
	if tag == TAG_ESCAPE_BOAT and _rare(RARE_FOG):
		eta += FOG_BOAT_DELAY_S
	for z: Node in find_tagged(tag):
		z.set(&"arrival_delay_s", eta)
	update_objective_data(&"escape_wait", {"seconds": eta})
	activate(&"escape_wait")
	say(&"vo.mercer.dockside_burn_boat_eta" if tag == TAG_ESCAPE_BOAT else &"vo.mercer.dockside_burn_van_eta",
		{"seconds": eta})
	activate_escape(tag)
	start_timer(&"escape_arrival", eta, func() -> void:
		complete(&"escape_wait")
		activate(&"escape")
		say(&"vo.mercer.dockside_burn_escape")
		say(&"vo.reyes.dockside_burn_payday", {}, &"reyes"))


# --- Helpers ----------------------------------------------------------------------------------

## The rolled escape (E3 is the Co-op launch, E1 / E2 the van).
func _escape_tag() -> StringName:
	return TAG_ESCAPE_BOAT if _slot_active(&"escape", &"esc_boat") else TAG_ESCAPE_VAN


## [breach] markers: the rolled warehouse entry's door (opened by _apply_entry_and_perch); every
## variant entry door when none rolled.
func _entry_tags() -> Array[StringName]:
	var out: Array[StringName] = []
	for sid: StringName in ENTRY_DOORS:
		if _slot_active(&"warehouse_entry", sid):
			out.append(sid)
	if out.is_empty():
		out.assign(ENTRY_DOORS.keys())
	return out


## [containers] markers: the padlocks of the given yard containers (k1 .. k6).
func _container_tags(keys: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in keys:
		out.append(StringName(TAG_CONTAINER_PADLOCK % String(k)))
	return out


func _set_lift_enabled(on: bool) -> void:
	for lift: Node in find_tagged(TAG_LIFT):
		_set_enabled(lift, on)
		for c: Node in lift.get_children():
			if String(c.name).begins_with("LandingPanel") and "enabled" in c:
				c.set(&"enabled", on)
	if not on:
		say(&"vo.mercer.dockside_burn_lift_dead")


## Spreads `total` bags over the given loot spawns (sorted by name for determinism).
func _split_count(spawns: Array[Node], total: int) -> void:
	spawns.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	if spawns.is_empty():
		return
	var left: int = total
	for i: int in range(spawns.size()):
		var c: int = int(ceil(float(left) / float(spawns.size() - i)))
		spawns[i].set(&"count", c)
		spawns[i].set(&"remaining", c)
		left -= c


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


func _director_time_scale() -> float:
	var d: AssaultDirector = _director()
	if d == null or d.tweak == null:
		return 1.0
	var base: DirectorTweak = load(AssaultDirector.DEFAULT_TWEAK) as DirectorTweak
	if base == null or base.first_control_s <= 0.0:
		return 1.0
	return clampf(d.tweak.first_control_s / base.first_control_s, 0.0, 1.0)
