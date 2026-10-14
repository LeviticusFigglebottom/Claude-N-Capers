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
## GN-A1 (ENV A): last call (zones, guests out, relocks), the curator's carried card, frame sensors, the lockdown
## (shutters BARRED, reader dead, loud hack), rare-event spawns, asset.intel_list and Mercer's sweep-laser hint.
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
const ASSET_INTEL_LIST: StringName = &"asset.intel_list"
## Doors the mission relocks / opens: objective tag first (ENV C to tag them), else these map paths.
const TAG_BRONZE: StringName = &"bronze_doors"
const TAG_COURT: StringName = &"court_doors"
const TAG_ART_DOOR: StringName = &"art_door"
const TAG_VAULT_DOOR: StringName = &"art_store_vault_door"
const TAG_TREASURY_LEAF: StringName = &"treasury_door_leaf"
const PATHS_BRONZE: Array[String] = ["Gameplay/Doors/BronzeDoorsW", "Gameplay/Doors/BronzeDoorsE"]
const PATHS_ART_DOOR: Array[String] = ["Gameplay/Doors/ArtDoorEG"]
const PATHS_VAULT_DOOR: Array[String] = ["Gameplay/Doors/ArtStoreVaultDoor"]
const PATHS_TREASURY_DOOR: Array[String] = ["Gameplay/Doors/TreasuryDoor"]
const COURT_OPEN_SLOT: String = "Variants/Group_court_doors/Slot_court_doors_open"
## C bff4dd40: the areaway ladder is climbable only while the rolled areaway grate (a Door laid flat) is open.
const AREAWAY_GROUP: String = "Variants/Group_areaway"
const AREAWAY_GRATE: String = "AreawayGrate"
const AREAWAY_LADDER: String = "Gameplay/Ladders/AreawayLadder"
## Last call: guests out by the portico (stragglers stay), waitstaff by the dock at +WAITSTAFF_OUT_S.
const EXIT_GUESTS: StringName = &"exit_guests"
const EXIT_STAFF: StringName = &"exit_staff"
const GUEST_TAGS: Array[StringName] = [&"civ_patron"]
const WAITSTAFF_TAGS: Array[StringName] = [&"civ_waitstaff"]
const WAITSTAFF_OUT_S: float = 120.0
## Mercer's sweep-laser hint (B 778deea3): once, the first time a crew member comes within LASER_HINT_M of the TR grid
## while the rolled laser_pattern is lz_sweep.
const TAG_TR_LASERS: StringName = &"treasury_lasers"
const LASER_SWEEP_SLOT: StringName = &"lz_sweep"
const LASER_HINT_M: float = 4.0
const VO_LASER_SWEEP: StringName = &"vo.mercer.gallery_night_lasers_sweep"
## Rare-event timed spawns (QC-25): guards per spawn; `after` &"last_call" counts from last call.
const TIMED_SPAWN_COUNT: int = 2
const AFTER_LAST_CALL: StringName = &"last_call"

var _escape: StringName = &"mews"
var _lantern_secured: bool = false
var _list_secured: bool = false
var _escape_open: bool = false
var _lockdown: bool = false
var _found: Array[StringName] = []
var _last_call: bool = false
var _laser_hint_done: bool = false
## argus_upgrade: extra hack interruptions (stealth and loud).
var _extra_interruptions: int = 0
## Rare timed spawns waiting for last call: [timer id, delay s, spawn tag].
var _after_last_call: Array[Array] = []


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
	_apply_intel_list()
	_watch_sweep_lasers()
	_tie_areaway_ladder()
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

## Scalars: keep the first `store_paintings` AS rack studies and `consignment_lockers` lockers (map order), and the
## first `patrons` patrons (thin_civilians; with fewer patron spawns than the roll, all of them stay). `stragglers`
## patrons stay on after last call (_on_last_call).
func _apply_scalars() -> void:
	_keep_first(find_tagged(TAG_STORE_STUDY), int(_scalar(&"store_paintings", 8)))
	_keep_first(find_tagged(TAG_LOCKERS), int(_scalar(&"consignment_lockers", 8)))
	thin_civilians(GUEST_TAGS[0], int(_scalar(&"patrons", 5)))


## kc_curator is on Sorell's lanyard (QC-52: the map's `keycard` pickup carries `carrier_tag` civ_curator). The bar
## pickup (`keycard_bar`, GN-C1 step 2d) stands for the curator_tipsy case (her lanyard left on the bar at last call);
## until last call it is hidden.
func _apply_curator_card() -> void:
	for k: Node in find_tagged(TAG_KEYCARD_BAR):
		_set_enabled(k, false)
		(k as Node3D).visible = false


## GN-C1 step 2d (frame sensors, QC-54; through HeistMission.disable_alarm_group): the hung frames are LootSpawn
## `alarm_on_take` in one AlarmGroups zone each (argus_treasury / argus_upper / argus_ground); the active sensor_net
## slot's params name the zones this option leaves off, taken offline here. The prefab raises alarm_raised(&"sensor") on a live take.
func _apply_sensor_net() -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	var picked: Variant = variant(&"sensor_net")
	var group: Node = rt.map.get_node_or_null(^"Variants/Group_sensor_net") if rt != null and rt.map != null else null
	if group == null or not picked is Array:
		return
	for vs: Node in group.get_children():
		if vs is VariantSlot and (picked as Array).has((vs as VariantSlot).slot_id):
			for g: String in PackedStringArray((vs as VariantSlot).params.get("alarm_groups_off", [])):
				disable_alarm_group(StringName(g))


## find_canvases: an Area3D (FIND_RADIUS_M) per active list canvas; the first crew entry reveals the slot's own tag.
## `asset.intel_list` seeds the found list at start (_apply_intel_list).
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


## asset.intel_list: the crew knows where every listed canvas hangs before walking in (find_canvases seeded).
func _apply_intel_list() -> void:
	if not has_asset(ASSET_INTEL_LIST):
		return
	_found.assign([TAG_LANTERN] + LIST_TAGS)
	update_objective_data(&"find_canvases", {"marker_tags": _found.duplicate(), "found": _found.size()})
	complete(&"find_canvases")


## The areaway ladder follows its grate: usable only while the grate is open (C bff4dd40).
func _tie_areaway_ladder() -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null or rt.map == null:
		return
	var ladder: Ladder = rt.map.get_node_or_null(NodePath(AREAWAY_LADDER)) as Ladder
	var group: Node = rt.map.get_node_or_null(NodePath(AREAWAY_GROUP))
	if ladder == null or group == null:
		return
	var grates: Array[Door] = []
	for n: Node in group.find_children(AREAWAY_GRATE, "", true, false):
		if n is Door:
			grates.append(n as Door)
	if grates.is_empty():
		return
	var update: Callable = func(_open: bool = false, _by: int = 0) -> void:
		ladder.usable = grates.any(func(g: Door) -> bool: return is_instance_valid(g) and g.is_open)
	for g: Door in grates:
		g.open_changed.connect(update)
	update.call()


## Mercer's sweep-laser hint (B): an approach Area3D on the active lz_sweep Treasury grid.
func _watch_sweep_lasers() -> void:
	var picked: Variant = variant(&"laser_pattern")
	if not (picked is Array and (picked as Array).has(LASER_SWEEP_SLOT)):
		return
	for g: Node in find_tagged(TAG_TR_LASERS):
		if not String(g.get_path()).contains("Slot_%s" % LASER_SWEEP_SLOT):
			continue
		var area: Area3D = Area3D.new()
		area.name = "HintArea"
		area.collision_layer = 0
		area.collision_mask = 0xFFFFFFFF
		area.monitorable = false
		var shape: CollisionShape3D = CollisionShape3D.new()
		var sph: SphereShape3D = SphereShape3D.new()
		sph.radius = LASER_HINT_M
		shape.shape = sph
		area.add_child(shape)
		g.add_child(area)
		area.body_entered.connect(_on_laser_hint_area)


func _on_laser_hint_area(body: Node) -> void:
	if _laser_hint_done or went_loud or not body.is_in_group(G.CREW):
		return
	_laser_hint_done = true
	say(VO_LASER_SWEEP)


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
	# QC-51: the gala's PUBLIC rooms become RESTRICTED; guests walk out by the portico (stragglers stay on); the
	# bronze doors and an open court pair close and relock LOCKPICK; waitstaff leave by the dock later.
	set_zone_kinds(MapZone.Kind.PUBLIC, MapZone.Kind.RESTRICTED)
	civilians_leave(EXIT_GUESTS, GUEST_TAGS, int(_scalar(&"stragglers", 0)))
	for d: Door in _doors(TAG_BRONZE, PATHS_BRONZE) + _court_doors():
		d.relock(Door.Lock.LOCKPICK)
	start_timer(&"waitstaff_out", WAITSTAFF_OUT_S, func() -> void:
		if not went_loud:
			civilians_leave(EXIT_STAFF, WAITSTAFF_TAGS))
	for w: Array in _after_last_call:
		_start_spawn_timer(StringName(w[0]), float(w[1]), StringName(w[2]))
	_set_curtain(true)
	if _rare(RARE_CURATOR_TIPSY):
		for k: Node in find_tagged(TAG_KEYCARD):  # her carried card goes: the lanyard is on the bar now (one card)
			var kp: KeycardPickup = k as KeycardPickup
			if kp != null and kp.carrier_tag != &"":
				kp.discard()
		for k: Node in find_tagged(TAG_KEYCARD_BAR):
			_set_enabled(k, true)
			(k as Node3D).visible = true
		update_objective_data(&"keycard", {"marker_tags": [TAG_KEYCARD, TAG_KEYCARD_BAR]})
	start_timer(&"guests_gone", GUESTS_GONE_S, func() -> void:
		if not went_loud:
			say(&"vo.mercer.gallery_night_guests_gone"))


## Rare events (B README effect keys, read from the rolled events' effects): `timed_spawn` (QC-25:
## insurance_inspection = guard_inspection at last call + delay_s; vaultline_early = guard_vaultline at at_s, rolled
## only with the centrepiece on cp_landing / cp_treasury, VariantResolver `requires`) spawns TIMED_SPAWN_COUNT guards
## at the tagged scripted spawns, before the alarm only; `extra_hack_interruptions` (argus_upgrade) adds to both hack
## ranges. late_loan's studies are the xl_loan slot's own (force_active, no script).
func _schedule_rare_events() -> void:
	var fx_by_event: Dictionary = rare_effects()
	for ev: Variant in fx_by_event:
		var fx: Dictionary = fx_by_event[ev]
		_extra_interruptions += int(fx.get("extra_hack_interruptions", 0))
		var ts: Variant = fx.get("timed_spawn")
		if not ts is Dictionary:
			continue
		var d: Dictionary = ts as Dictionary
		var id: StringName = StringName("rare_%s" % ev)
		var tag: StringName = StringName(d.get("spawn_tag", &""))
		if StringName(d.get("after", &"")) == AFTER_LAST_CALL:
			_after_last_call.append([id, float(d.get("delay_s", 0.0)), tag])
		else:
			_start_spawn_timer(id, float(d.get("at_s", 0.0)), tag)
	if _extra_interruptions > 0:
		for h: Node in find_tagged(TAG_HACK):
			var ht: HackTerminal = h as HackTerminal
			if ht != null:
				ht.reconfigure(ht.duration_s, ht.interruptions + Vector2i(_extra_interruptions, _extra_interruptions))


func _start_spawn_timer(id: StringName, after_s: float, tag: StringName) -> void:
	start_timer(id, maxf(after_s, 0.01), func() -> void:
		if not went_loud and tag != &"":
			spawn_guards(TIMED_SPAWN_COUNT, tag))


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
## doors open with no card (B3).
func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		_complete_once(&"hack")
		_sensors_offline(device_net_id)
		if went_loud:
			_lift_lockdown()
		else:
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
## label key `…hack_loud`). The Calloway arch / TR / art-door shutters and the LD art door are BARRED, the AS keycard
## reader dies, and the hack terminal retargets to HACK_LOUD_S / HACK_LOUD_INTERRUPTIONS (QC-55; progress kept).
func _go_loud() -> void:
	if _lockdown:
		return
	_lockdown = true
	activate(&"lockdown")
	complete(&"lockdown")
	say(&"vo.mercer.gallery_night_lockdown")
	for n: Node in find_tagged(TAG_SHUTTER):
		_bar(n)
	for d: Door in _doors(TAG_ART_DOOR, PATHS_ART_DOOR):
		d.relock(Door.Lock.BARRED)
	for r: Node in find_tagged(TAG_VAULT_READER):
		if r is KeycardReader:
			(r as KeycardReader).set_disabled(true)
	var extra: Vector2i = Vector2i(_extra_interruptions, _extra_interruptions)
	for h: Node in find_tagged(TAG_HACK):
		if h is HackTerminal:
			(h as HackTerminal).reconfigure(HACK_LOUD_S, HACK_LOUD_INTERRUPTIONS + extra)
	if objective_state(&"hack") == Enums.ObjectiveState.ACTIVE:
		add_objective(&"hack", &"objective.gallery_night.hack_loud", Enums.ObjectiveState.ACTIVE,
			{"marker_tags": [TAG_HACK], "duration_s": HACK_LOUD_S, "interruptions": HACK_LOUD_INTERRUPTIONS})
	if objective_state(&"server_code") != Enums.ObjectiveState.COMPLETED:
		activate(&"server_door")
	if objective_state(&"art_store") != Enums.ObjectiveState.COMPLETED:
		activate(&"vault_drill")
	if objective_state(&"secure") == Enums.ObjectiveState.COMPLETED:
		_call_escape()


## Loud hack done: every shutter up, the TR / LD art / AS vault doors open with no card (B3).
func _lift_lockdown() -> void:
	for n: Node in find_tagged(TAG_SHUTTER):
		_lift(n)
	for d: Door in _doors(TAG_ART_DOOR, PATHS_ART_DOOR) + _doors(TAG_TREASURY_LEAF, PATHS_TREASURY_DOOR) \
			+ _doors(TAG_VAULT_DOOR, PATHS_VAULT_DOOR):
		_lift(d)
	for r: Node in find_tagged(TAG_VAULT_READER):
		if r is KeycardReader:
			(r as KeycardReader).set_disabled(false)
	_complete_once(&"treasury")
	_complete_once(&"art_store")


# --- Helpers -----------------------------------------------------------------------------------

## Shutters and doors: a Door (or any prefab with Door's relock / unlock / set_open, ENV C's shutter and grate
## prefabs) is BARRED and closed; Markers (G1 stand-ins) are skipped.
func _bar(n: Node) -> void:
	if n.has_method(&"relock"):
		n.call(&"relock", Door.Lock.BARRED, true)


func _lift(n: Node) -> void:
	if n.has_method(&"unlock"):
		n.call(&"unlock")
	if n.has_method(&"set_open"):
		n.call(&"set_open", true)


## Doors tagged `tag` in this map, else the ones at `paths` (relative to the map root).
func _doors(tag: StringName, paths: Array[String]) -> Array[Door]:
	var out: Array[Door] = []
	for n: Node in find_tagged(tag):
		if n is Door:
			out.append(n as Door)
	if out.is_empty():
		var rt: HeistRuntime = HeistRuntime.of(self)
		for p: String in paths:
			var d: Door = rt.map.get_node_or_null(NodePath(p)) as Door if rt != null and rt.map != null else null
			if d != null:
				out.append(d)
	return out


## court_doors: the pair tagged court_doors, else the Doors under the court_doors_open slot (when rolled).
func _court_doors() -> Array[Door]:
	var out: Array[Door] = _doors(TAG_COURT, [])
	var rt: HeistRuntime = HeistRuntime.of(self)
	var slot: Node = rt.map.get_node_or_null(NodePath(COURT_OPEN_SLOT)) if out.is_empty() and rt != null else null
	if slot != null and _slot_rolled(&"court_doors", &"court_doors_open"):
		for n: Node in slot.find_children("*", "", true, false):
			if n is Door:
				out.append(n as Door)
	return out


func _slot_rolled(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = variant(group)
	return v is Array and (v as Array).has(slot_id)


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
## meta `alarm_groups` go offline here (or set them in HackTerminal.clears_alarm_groups and drop the meta).
func _sensors_offline(device_net_id: int) -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	for n: Node in find_tagged(TAG_HACK):
		var nid: Variant = n.get(&"net_id")
		if rt != null and nid != null and int(nid) == device_net_id:
			for g: String in PackedStringArray(n.get_meta(&"alarm_groups", PackedStringArray())):
				disable_alarm_group(StringName(g))


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
