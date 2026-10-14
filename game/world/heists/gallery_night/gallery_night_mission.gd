## Gallery Night (Halberd Gallery) mission flow: G1 STUB. Owner: ENV C (GN-C1, map + stub); ENV A completes it (GN-A1,
## next_heist §3b.6; ENV A co-owns game/world/heists/**). Design: docs/design/heists/gallery_night.md §Objectives,
## Build rulings B3 (no stealth-only fail) and B5 (marker_tags); data contract: game/content/_drafts/gallery_night/
## README.md (objective table, rare-event effect keys). Contract heist_map.md §6: only the HeistMission API, EventBus
## and nodes of this map (found by objective_tag).
##
## Stealth: case (optional) -> find the listed canvases -> keycard / code + hack as needed -> cut the Lantern Bearer +
## 1 listed canvas -> secure both at the active escape (studies never count) -> escape.
## Loud (alarm): lockdown (completes at once) -> hack (120 s) or the vault drill -> secure -> escape after
## `escape_eta_s`. Fail reasons: custody / abort only (B3; HeistRuntime ends the heist, this script never fails it).
## Every `TODO(A §3b.6)` below needs an ENV A system API that does not exist yet.
extends HeistMission

const TAG_CASING: StringName = &"casing_hall"
const TAG_KEYCARD: StringName = &"keycard"
const TAG_CODE: StringName = &"code_note"
const TAG_HACK: StringName = &"hack"
const TAG_TREASURY: StringName = &"treasury_door"
const TAG_VAULT_READER: StringName = &"vault_reader"
const TAG_LANTERN: StringName = &"canvas_lantern"
const LIST_TAGS: Array[StringName] = [&"canvas_orchard", &"canvas_widow", &"canvas_saint"]
const TAG_LOCKERS: StringName = &"lockers"
const TAG_SAFE: StringName = &"curator_safe"
const TAG_SHUTTER: StringName = &"shutter"
const TAG_SERVER_DOOR: StringName = &"server_door"
const TAG_VAULT_DRILL: StringName = &"vault_drill"
const TAG_STORE_STUDY: StringName = &"store_study"
const TAG_CURTAIN: StringName = &"landing_curtain"
## GN-C1 step 2d: the curator_tipsy lanyard on the bar (kc_curator's carried card is the `keycard` one, QC-52).
const TAG_KEYCARD_BAR: StringName = &"keycard_bar"
const ITEM_KEYCARD: StringName = &"item.keycard"
const LOOT_LANTERN: StringName = &"loot.painting_lantern_bearer"
const LIST_LOOT: Array[StringName] = [&"loot.painting_salt_orchard", &"loot.painting_widow_in_blue",
	&"loot.painting_tidewater_saint"]
## Loud hack (doc §Loud): 120 s, 2-3 interruptions (stealth 60 s / 1-2 is the map's hack_terminal).
const HACK_LOUD_S: float = 120.0
const HACK_LOUD_INTERRUPTIONS: Vector2i = Vector2i(2, 3)
const LAST_CALL_WARNING_S: float = 60.0
const GUESTS_GONE_S: float = 60.0
## find_canvases: radius of the "walk within 4 m" check around each active list slot (doc §Objectives 2).
const FIND_RADIUS_M: float = 4.0
const RARE_CURATOR_TIPSY: StringName = &"curator_tipsy"

var _escape: StringName = &"mews"
var _lantern_secured: bool = false
var _list_secured: bool = false
var _escape_open: bool = false
var _lockdown: bool = false
var _found: Array[StringName] = []
var _last_call: bool = false


func _on_mission_start() -> void:
	var esc: Variant = variant(&"escape")
	if esc is Array and (esc as Array).has(&"esc_parade"):
		_escape = &"parade"
	say(&"vo.mercer.gallery_night_intro")
	say(&"vo.vance.gallery_night_contact_intro", {}, &"vance")
	var secure_tag: StringName = StringName("secure_%s" % _escape)
	var escape_tag: StringName = StringName("escape_%s" % _escape)
	_add(&"casing", Enums.ObjectiveState.ACTIVE, [TAG_CASING], {"optional": true})
	# B5: no spoiler markers; grows per found slot (update_objective_data, QC-60). Area objective (readiness gate).
	_add(&"find_canvases", Enums.ObjectiveState.ACTIVE, [], {"found": 0, "total": 1 + LIST_TAGS.size()})
	_add(&"keycard", Enums.ObjectiveState.ACTIVE, [TAG_KEYCARD], {"optional": true})
	require_items(&"keycard", ITEM_KEYCARD)
	_add(&"server_code", Enums.ObjectiveState.ACTIVE, [TAG_CODE], {"optional": true})
	_add(&"hack", Enums.ObjectiveState.ACTIVE, [TAG_HACK], {"optional": true})
	_add(&"treasury", Enums.ObjectiveState.ACTIVE, [TAG_TREASURY], {"optional": true})
	_add(&"art_store", Enums.ObjectiveState.ACTIVE, [TAG_VAULT_READER], {"optional": true})
	_add(&"centrepiece", Enums.ObjectiveState.ACTIVE, [TAG_LANTERN])
	_add(&"canvases", Enums.ObjectiveState.ACTIVE, LIST_TAGS.duplicate())
	_add(&"secure", Enums.ObjectiveState.ACTIVE, [secure_tag], {"count": 0, "total": 2})
	_add(&"extras", Enums.ObjectiveState.ACTIVE, [TAG_LOCKERS, TAG_SAFE], {"optional": true})
	_add(&"lockers", Enums.ObjectiveState.ACTIVE, [TAG_LOCKERS], {"optional": true})
	_add(&"curator_safe", Enums.ObjectiveState.ACTIVE, [TAG_SAFE], {"optional": true})
	_add(&"lockdown", Enums.ObjectiveState.HIDDEN, [TAG_SHUTTER])
	_add(&"server_door", Enums.ObjectiveState.HIDDEN, [TAG_SERVER_DOOR])
	_add(&"vault_drill", Enums.ObjectiveState.HIDDEN, [TAG_VAULT_DRILL])
	_add(&"escape_wait", Enums.ObjectiveState.HIDDEN, [escape_tag])
	_add(&"escape", Enums.ObjectiveState.HIDDEN, [escape_tag])
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"loot_secured", _on_canvas_secured)
	_apply_scalars()
	_apply_curator_card()
	_apply_sensor_net()
	_set_curtain(false)
	_watch_canvases()
	_schedule_last_call()
	_schedule_rare_events()


func _add(id: StringName, state: Enums.ObjectiveState, tags: Array, data: Dictionary = {}) -> void:
	var d: Dictionary = data.duplicate()
	d["marker_tags"] = tags
	add_objective(id, StringName("objective.gallery_night.%s" % id), state, d)


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING:
		complete(&"casing")


## B3: every alarm goes loud; nothing here fails the heist.
func _on_alarm(_reason: StringName) -> void:
	_go_loud()


# --- Setup -------------------------------------------------------------------------------------

## Scalars: keep the first `store_paintings` AS rack studies and `consignment_lockers` lockers (map order).
## TODO(A §3b.6): the `patrons` / `stragglers` scalars need a civilian spawn-count hook (the map has 5 patron spawns).
func _apply_scalars() -> void:
	_keep_first(find_tagged(TAG_STORE_STUDY), int(_scalar(&"store_paintings", 8)))
	_keep_first(find_tagged(TAG_LOCKERS), int(_scalar(&"consignment_lockers", 8)))


## kc_curator is on Sorell's lanyard (QC-52: the map's `keycard` pickup carries `carrier_tag` civ_curator). The bar
## pickup (`keycard_bar`, GN-C1 step 2d) stands for the curator_tipsy case (her lanyard left on the bar at last call);
## until last call it is hidden.
func _apply_curator_card() -> void:
	for k: Node in find_tagged(TAG_KEYCARD_BAR):
		_set_enabled(k, false)
		(k as Node3D).visible = false


## GN-C1 step 2d (frame sensors, QC-54; A to review): the hung frames are LootSpawn `alarm_on_take` in one AlarmGroups
## zone each (argus_treasury / argus_upper / argus_ground); the active sensor_net slot's params name the zones this
## option leaves off, taken offline here. The prefab raises alarm_raised(&"sensor") on a live take.
func _apply_sensor_net() -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	var picked: Variant = variant(&"sensor_net")
	var group: Node = rt.map.get_node_or_null(^"Variants/Group_sensor_net") if rt != null and rt.map != null else null
	if group == null or not picked is Array:
		return
	for vs: Node in group.get_children():
		if vs is VariantSlot and (picked as Array).has((vs as VariantSlot).slot_id):
			for g: String in PackedStringArray((vs as VariantSlot).params.get("alarm_groups_off", [])):
				AlarmGroups.disable(rt, StringName(g))


## find_canvases: an Area3D (FIND_RADIUS_M) per active list canvas; the first crew entry reveals the slot's own tag.
## TODO(A §3b.6): `asset.intel_list` seeds the found list at start (preplan asset effect).
func _watch_canvases() -> void:
	for tag: StringName in [TAG_LANTERN] + LIST_TAGS:
		for c: Node in find_tagged(tag):
			var area: Area3D = Area3D.new()
			area.name = "FindArea"
			area.collision_layer = 0
			area.collision_mask = 0xFFFFFFFF
			area.monitorable = false
			var shape: CollisionShape3D = CollisionShape3D.new()
			var sph: SphereShape3D = SphereShape3D.new()
			sph.radius = FIND_RADIUS_M
			shape.shape = sph
			area.add_child(shape)
			c.add_child(area)
			area.body_entered.connect(_on_find_area.bind(tag))


func _on_find_area(body: Node, tag: StringName) -> void:
	if tag in _found or not body.is_in_group(G.CREW):
		return
	_found.append(tag)
	update_objective_data(&"find_canvases", {"marker_tags": _found.duplicate(), "found": _found.size()})
	var short: String = "lantern" if tag == TAG_LANTERN else String(tag).trim_prefix("canvas_")
	say(StringName("vo.mercer.gallery_night_canvas_found_%s" % short))
	if _found.size() >= 1 + LIST_TAGS.size():
		complete(&"find_canvases")


## Last call (`last_call_s`): Mercer's warning 60 s before, then the gala ends. Before the alarm only.
func _schedule_last_call() -> void:
	var t: float = float(_scalar(&"last_call_s", 600))
	start_timer(&"last_call_soon", maxf(t - LAST_CALL_WARNING_S, 1.0), func() -> void:
		if not went_loud:
			say(&"vo.mercer.gallery_night_last_call_soon"))
	start_timer(&"last_call", t, _on_last_call)


func _on_last_call() -> void:
	if went_loud or _last_call:
		return
	_last_call = true
	say(&"vo.mercer.gallery_night_last_call")
	# TODO(A §3b.6, QC-51): guests path to the portico and despawn over GUESTS_GONE_S; flip the PUBLIC MapZones to
	# RESTRICTED; the hall guard closes the bronze doors and the mission relocks them LOCKPICK from outside (relock API);
	# court_doors_open relocks LOCKPICK; waitstaff leave by the LD personnel door at +120 s.
	_set_curtain(true)
	if _rare(RARE_CURATOR_TIPSY):
		# TODO(A §3b.6): free kc_curator's carried card (the lanyard is on the bar now, one card in all).
		for k: Node in find_tagged(TAG_KEYCARD_BAR):
			_set_enabled(k, true)
			(k as Node3D).visible = true
		update_objective_data(&"keycard", {"marker_tags": [TAG_KEYCARD, TAG_KEYCARD_BAR]})
	start_timer(&"guests_gone", GUESTS_GONE_S, func() -> void:
		if not went_loud:
			say(&"vo.mercer.gallery_night_guests_gone"))


## Rare events (B README effect keys). TODO(A §3b.6): insurance_inspection / vaultline_early timed spawns (QC-25:
## spawn_guards(2, &"guard_inspection") at last call + 180 s; guard_vaultline at 720 s, void unless the centrepiece is
## cp_landing / cp_treasury; the B3 G1 fallback moves the canvas to cp_store, TODO(QC-57)); argus_upgrade's extra hack
## interruption; late_loan's studies are the xl_loan slot's.
func _schedule_rare_events() -> void:
	pass


# --- Stealth flow --------------------------------------------------------------------------------

func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_TREASURY):
		_complete_once(&"treasury")
	elif _is_tagged(interactable_net_id, TAG_VAULT_READER):
		_complete_once(&"art_store")
	elif _is_tagged(interactable_net_id, TAG_CODE):
		_complete_once(&"server_code")
		say(&"vo.mercer.gallery_night_code_found")
	elif _is_tagged(interactable_net_id, TAG_LANTERN):
		_complete_once(&"centrepiece")
	elif _is_tagged(interactable_net_id, TAG_SAFE):
		_complete_once(&"curator_safe")
	else:
		for tag: StringName in LIST_TAGS:
			if _is_tagged(interactable_net_id, tag):
				_complete_once(&"canvases")
	# QC-54: an alarmed frame's LootSpawn raises alarm_raised(&"sensor") itself (alarm_on_take, map; GN-C1 step 2d).


## The Argus hack: stealth -> the frame sensors go offline (QC-54); loud -> every shutter up, the TR / LD art / AS vault
## doors open with no card (B3). TODO(A §3b.6): shutter BAR / lift and the door relock API.
func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		_complete_once(&"hack")
		_sensors_offline(device_net_id)
		say(&"vo.mercer.gallery_night_sensors_off")
	elif _is_tagged(device_net_id, TAG_VAULT_DRILL):
		_complete_once(&"vault_drill")
		_complete_once(&"art_store")
	elif _is_tagged(device_net_id, TAG_SERVER_DOOR):
		_complete_once(&"server_door")


## secure: the Lantern Bearer AND one other list canvas (D-075); studies never count.
func _on_canvas_secured(_bag_net_id: int, loot_id: StringName, _value: int) -> void:
	if loot_id == LOOT_LANTERN:
		_lantern_secured = true
	elif loot_id in LIST_LOOT:
		_list_secured = true
	else:
		return
	update_objective_data(&"secure", {"count": int(_lantern_secured) + int(_list_secured), "total": 2})
	if _lantern_secured and _list_secured and objective_state(&"secure") != Enums.ObjectiveState.COMPLETED:
		complete(&"secure")
		say(&"vo.mercer.gallery_night_required_secured")
		_call_escape()


## Stealth: the escape opens at once. Loud: the van / limo returns after `escape_eta_s` (from [secure]).
func _call_escape() -> void:
	if _escape_open:
		return
	if not went_loud:
		_open_escape()
		return
	var eta: float = float(_scalar(&"escape_eta_s", 120))
	activate(&"escape_wait")
	say(StringName("vo.mercer.gallery_night_%s_eta" % ("van" if _escape == &"mews" else "limo")), {"seconds": int(eta)})
	start_timer(&"escape_eta", eta, _open_escape)


func _open_escape() -> void:
	if _escape_open:
		return
	_escape_open = true
	if objective_state(&"escape_wait") == Enums.ObjectiveState.ACTIVE:
		complete(&"escape_wait")
	activate(&"escape")
	say(&"vo.mercer.gallery_night_escape")
	activate_escape(StringName("escape_%s" % _escape))


# --- Loud flow ---------------------------------------------------------------------------------

## Lockdown: completes at once (it explains the shutters). The hack's loud label (B README ruling 7: same objective,
## label key `…hack_loud`). TODO(A §3b.6): BAR the Calloway arch shutter, the TR shutter and the LD art door, kill the AS
## keycard reader, retarget the hack terminal to HACK_LOUD_S / HACK_LOUD_INTERRUPTIONS (QC-55).
func _go_loud() -> void:
	if _lockdown:
		return
	_lockdown = true
	activate(&"lockdown")
	complete(&"lockdown")
	say(&"vo.mercer.gallery_night_lockdown")
	if objective_state(&"hack") == Enums.ObjectiveState.ACTIVE:
		add_objective(&"hack", &"objective.gallery_night.hack_loud", Enums.ObjectiveState.ACTIVE,
			{"marker_tags": [TAG_HACK], "duration_s": HACK_LOUD_S, "interruptions": HACK_LOUD_INTERRUPTIONS})
	if objective_state(&"server_code") != Enums.ObjectiveState.COMPLETED:
		activate(&"server_door")
	if objective_state(&"art_store") != Enums.ObjectiveState.COMPLETED:
		activate(&"vault_drill")
	if objective_state(&"secure") == Enums.ObjectiveState.COMPLETED:
		_call_escape()


# --- Helpers -----------------------------------------------------------------------------------

func _complete_once(id: StringName) -> void:
	if objective_state(id) != Enums.ObjectiveState.COMPLETED:
		complete(id)


## The cp_landing laser curtain is off during the gala (map: enabled_at_start false) and on from last call (doc
## §Mission script notes; QC-53, GN-C1 step 2d: LaserGrid.set_enabled).
func _set_curtain(on: bool) -> void:
	for g: Node in find_tagged(TAG_CURTAIN):
		var grid: LaserGrid = g as LaserGrid
		if grid != null:
			grid.set_enabled(on)


## GN-C1 step 2d: the Argus hack clears its own `clears_alarm_group` (argus_treasury); the other zones it lists in its
## meta `alarm_groups` go offline here (A to review; TODO(A §3b.6, QC-55): the loud reconfigure lives with A).
func _sensors_offline(device_net_id: int) -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	for n: Node in find_tagged(TAG_HACK):
		var nid: Variant = n.get(&"net_id")
		if rt != null and nid != null and int(nid) == device_net_id:
			for g: String in PackedStringArray(n.get_meta(&"alarm_groups", PackedStringArray())):
				AlarmGroups.disable(rt, StringName(g))


func _keep_first(nodes: Array[Node], count: int) -> void:
	for i: int in range(nodes.size()):
		if i >= count:
			_set_enabled(nodes[i], false)
			(nodes[i] as Node3D).visible = false


func _set_enabled(n: Node, on: bool) -> void:
	var it: Node = n.get_node_or_null(^"Interactable")
	if it != null:
		it.set(&"enabled", on)


func _scalar(id: StringName, fallback: Variant) -> Variant:
	var v: Variant = variant(id)
	return fallback if v == null else v


func _rare(ev: StringName) -> bool:
	var r: Variant = variant(&"rare")
	return r is Array and (r as Array).has(ev)


func _is_tagged(net_id: int, tag: StringName) -> bool:
	if net_id == 0:
		return false
	for n: Node in find_tagged(tag):
		var nid: Variant = n.get(&"net_id")
		if nid != null and int(nid) == net_id:
			return true
	return false
