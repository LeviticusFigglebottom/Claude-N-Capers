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
## GN-8 / QC-57: the Vaultline couriers (vaultline_early) walk to the centrepiece slot, take the Lantern Bearer as an
## NPC-carried bag and carry it to the AS rack, then walk back to LD (B3: moves, never destroys). Killed, intimidated
## or fighting, the carrier drops it where he stands; at an empty slot he radios the alarm.
## D-117 §6: every written mission line is said here, each at its moment (the VO_* constants and their handlers).
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
## Last call relabels the casing objective (B: "Stay out of sight: the gala's over").
const OBJ_CASING_LAST_CALL: StringName = &"objective.gallery_night.casing_last_call"
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
## D-117 §6 mission VO (lines.tres `event: mission`; doc §Audio). Once per heist unless the handler says otherwise.
const VO_KEYCARD: StringName = &"vo.mercer.gallery_night_keycard"
const VO_CURATOR_KEYCARD: StringName = &"vo.mercer.gallery_night_curator_keycard"
const VO_HACK_STARTED: StringName = &"vo.mercer.gallery_night_hack_started"
const VO_HACK_INTERRUPTED: StringName = &"vo.mercer.gallery_night_hack_interrupted"
const VO_SENSORS_WARNING: StringName = &"vo.mercer.gallery_night_sensors_warning"
const VO_LASERS: StringName = &"vo.mercer.gallery_night_lasers"
const VO_TREASURY_OPEN: StringName = &"vo.mercer.gallery_night_treasury_open"
const VO_ART_STORE_OPEN: StringName = &"vo.mercer.gallery_night_art_store_open"
const VO_LAST_PAGER: StringName = &"vo.mercer.gallery_night_last_pager"
const VO_SHUTTERS_UP: StringName = &"vo.mercer.gallery_night_shutters_up"
const VO_VAULT_DRILL: StringName = &"vo.mercer.gallery_night_vault_drill"
const VO_DRILL_JAM: StringName = &"vo.mercer.gallery_night_drill_jam"
const VO_SNIPER_HOTEL: StringName = &"vo.mercer.gallery_night_sniper_hotel"
const VO_CENTREPIECE: StringName = &"vo.vance.gallery_night_centrepiece"
const VO_PAYDAY: StringName = &"vo.vance.gallery_night_payday"
## Rare-event timed spawns -> Mercer's line when they walk in (doc §Rare events).
const RARE_SPAWN_VO: Dictionary = {
	&"insurance_inspection": &"vo.mercer.gallery_night_inspectors",
	&"vaultline_early": &"vo.mercer.gallery_night_vaultline",
}
const SPEAKER_VANCE: StringName = &"vance"
## Curator hint: the first crew member within this of Sorell while she still carries kc_curator (stealth).
const CURATOR_HINT_M: float = 5.0
const SPECIAL_LONGSHOT: StringName = &"longshot"
## Sniper perch markers (doc §Sniper perches: S1 = the Grand Wexley Hotel roof terrace).
const PERCH_HOTEL: NodePath = ^"Tactical/SniperHotel"
const PERCH_CONSERVATORY: NodePath = ^"Tactical/SniperConservatory"
## Rare-event timed spawns (QC-25): guards per spawn; `after` &"last_call" counts from last call.
const TIMED_SPAWN_COUNT: int = 2
const AFTER_LAST_CALL: StringName = &"last_call"
## QC-57 Vaultline couriers: the rare event's timer id, the poll period of their errand (s), how near a stop counts as
## reached (m), the escort's side offset from the carrier's stops (m), the AS rack they carry the canvas to (the
## cp_store slot: its canvas UsePoint in slot space; the slot node stays when the slot is not rolled) and the runtime
## tag of the moved canvas (the centrepiece marker follows the bag, QC-60).
const RARE_VAULTLINE_ID: StringName = &"rare_vaultline_early"
const COURIER_TICK_S: float = 0.5
const COURIER_REACH_M: float = 1.2
const COURIER_ESCORT_M: float = 1.0
const STORE_SLOT_PATH: String = "Variants/Group_centrepiece/Slot_cp_store"
const STORE_DROP_LOCAL: Vector3 = Vector3(0.9, 0.0, -0.06)
const TAG_LANTERN_MOVED: StringName = &"canvas_lantern_moved"
## The couriers' spawn tag, and the doors on their LD -> slot -> AS walk the map does not authorise them on yet (the
## KEYCARD LD art door; TR and the AS vault door list them already): authorised when they walk in.
const COURIER_SPAWN_TAG: StringName = &"guard_vaultline"
## Courier errand states (`courier_state`): walking to the slot, carrying to AS, the canvas put down on the AS rack
## (`stored`), the carrier stopped (killed / intimidated / fighting: `intercepted`), the slot found empty (`alarm`).
const COURIER_TO_SLOT: StringName = &"to_slot"
const COURIER_CARRYING: StringName = &"carrying"
const COURIER_STORED: StringName = &"stored"
const COURIER_INTERCEPTED: StringName = &"intercepted"
const COURIER_ALARM: StringName = &"alarm"
const COURIER_CAUSE_EMPTY: StringName = &"canvas_missing"

## QC-57: the Vaultline couriers (the carrier first once he has the canvas), their errand state (&"" before they
## arrive), the canvas they carry or put down, and where each walked in (they walk back there).
var couriers: Array[NpcBase] = []
var courier_state: StringName = &""
var courier_bag: LootBag = null

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
## D-117: one-shot mission lines already said this heist.
var _said: Dictionary[StringName, bool] = {}
## QC-57: where each courier walked in (spawn order; they walk back there after the AS rack).
var _courier_home: Array[Vector3] = []
## B VO coverage: net_ids of lockers / list canvases / studies taken (the `lockers` and `extras` completions).
var _taken: Dictionary[int, bool] = {}


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
	on_event(&"item_picked_up", _on_item_picked_up)
	on_event(&"device_started", _on_device_started)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"loot_picked", _on_loot_picked)
	on_event(&"special_spawned", _on_special_spawned)
	own_last_pager_line = true
	_apply_scalars()
	_apply_curator_card()
	_apply_sensor_net()
	_set_curtain(false)
	_watch_canvases()
	_apply_intel_list()
	_watch_lasers()
	_watch_curator_card()
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


## D-117: the pager cap reached, Mercer's heist line (PagerSystem skips the generic one: own_last_pager_line).
func _on_pager_answered(total: int) -> void:
	if total == pager_cap():
		say(VO_LAST_PAGER, {"answered": total})


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
			area.body_entered.connect(_on_find_area.bind(tag, c))


func _on_find_area(body: Node, tag: StringName, canvas: Node = null) -> void:
	if not body.is_in_group(G.CREW):
		return
	_warn_sensors(canvas)
	if tag in _found:
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


## The Treasury grid: an approach Area3D on the active TR grid. The first crew approach before the alarm: Mercer's
## laser line (D-117), then his sweep hint when the rolled pattern is lz_sweep (B 778deea3).
func _watch_lasers() -> void:
	var picked: Variant = variant(&"laser_pattern")
	var sweep: bool = picked is Array and (picked as Array).has(LASER_SWEEP_SLOT)
	for g: Node in find_tagged(TAG_TR_LASERS):
		var area: Area3D = _proximity_area("HintArea", LASER_HINT_M)
		g.add_child(area)
		area.body_entered.connect(_on_laser_hint_area.bind(
			sweep and String(g.get_path()).contains("Slot_%s" % LASER_SWEEP_SLOT)))


func _on_laser_hint_area(body: Node, sweep: bool = true) -> void:
	if went_loud or not body.is_in_group(G.CREW):
		return
	_say_once(VO_LASERS)
	if sweep and not _laser_hint_done:
		_laser_hint_done = true
		say(VO_LASER_SWEEP)


## D-117: kc_curator rides on Sorell's lanyard (QC-52). The first crew member within CURATOR_HINT_M of her while she
## still has it hears Mercer's hint (before the alarm; once).
func _watch_curator_card() -> void:
	for k: Node in find_tagged(TAG_KEYCARD):
		var kp: KeycardPickup = k as KeycardPickup
		if kp == null or kp.carrier_tag == &"":
			continue
		var area: Area3D = _proximity_area("CuratorHintArea", CURATOR_HINT_M)
		kp.add_child(area)
		area.body_entered.connect(_on_curator_area.bind(kp))


func _on_curator_area(body: Node, card: KeycardPickup = null) -> void:
	if went_loud or not body.is_in_group(G.CREW):
		return
	if card != null and (not is_instance_valid(card) or card.released or card.taken):
		return
	_say_once(VO_CURATOR_KEYCARD)


## D-117: the first crew approach to a hung canvas whose frame sensor is live (QC-54), before the alarm.
func _warn_sensors(canvas: Node) -> void:
	var ls: LootSpawn = canvas as LootSpawn
	if went_loud or ls == null or not ls.alarm_on_take:
		return
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null and AlarmGroups.is_live(rt, ls.alarm_group):
		_say_once(VO_SENSORS_WARNING)


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
	# P's GN pass (b): the objective tells the player the halls are off limits now (B's string).
	if objective_state(&"casing") == Enums.ObjectiveState.ACTIVE:
		add_objective(&"casing", OBJ_CASING_LAST_CALL, Enums.ObjectiveState.ACTIVE,
			{"marker_tags": [TAG_CASING], "optional": true})
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
	start_timer(id, maxf(after_s, 0.01), _on_timed_spawn.bind(id, tag))


## A rare timed spawn walks in (before the alarm): Mercer names it (D-117: the inspectors / the Vaultline crew).
func _on_timed_spawn(id: StringName, tag: StringName) -> void:
	if went_loud or tag == &"":
		return
	var spawned: Array[Node] = spawn_guards(TIMED_SPAWN_COUNT, tag)
	var line: Variant = RARE_SPAWN_VO.get(StringName(String(id).trim_prefix("rare_")))
	if line != null and not spawned.is_empty():
		_say_once(StringName(line))
	if id == RARE_VAULTLINE_ID:
		_start_couriers(spawned)


# --- Vaultline couriers (QC-57) --------------------------------------------------------------------

## The couriers walk in: both head for the rolled centrepiece slot (the carrier's stop, the escort beside him).
func _start_couriers(spawned: Array[Node]) -> void:
	if courier_state != &"":
		return
	for n: Node in spawned:
		if n is NpcBase:
			couriers.append(n as NpcBase)
			_courier_home.append((n as NpcBase).global_position)
	var slot: LootSpawn = _lantern_slot()
	if couriers.is_empty() or slot == null:
		return
	for d: Door in _doors(TAG_ART_DOOR, PATHS_ART_DOOR):
		d.authorise_npc_tag(COURIER_SPAWN_TAG)
	courier_state = COURIER_TO_SLOT
	_couriers_walk(_stand_of(slot))
	start_timer(&"courier_tick", COURIER_TICK_S, _courier_tick)


## One errand step, every COURIER_TICK_S while the couriers walk to the slot or carry the canvas.
func _courier_tick() -> void:
	match courier_state:
		COURIER_TO_SLOT:
			_courier_at_slot()
		COURIER_CARRYING:
			_courier_carry()
	if courier_state in [COURIER_TO_SLOT, COURIER_CARRYING]:
		start_timer(&"courier_tick", COURIER_TICK_S, _courier_tick)


func _courier_at_slot() -> void:
	if _active_couriers().is_empty():
		courier_state = COURIER_INTERCEPTED  # stopped on the way (killed / intimidated / loud): the canvas still hangs
		return
	var slot: LootSpawn = _lantern_slot()
	var carrier: NpcBase = _first_courier(_stand_of(slot) if slot != null else _store_point())
	if carrier == null:
		return  # still walking
	if slot == null or slot.remaining <= 0:
		courier_state = COURIER_ALARM  # B3: the canvas is gone -> he radios it in (alarm, loud)
		var brain: GuardBrain = _brain(carrier)
		if brain != null:
			brain.report_alarm(slot.global_position if slot != null else carrier.global_position, COURIER_CAUSE_EMPTY)
		return
	var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
	var bag: LootBag = slot.take_for_npc() if mgr != null else null
	if bag == null:
		return
	if not mgr.npc_carry(bag, carrier):
		courier_state = COURIER_INTERCEPTED  # cannot carry it now: the bag stays at the slot, loose
		return
	courier_bag = bag
	bag.objective_tag = TAG_LANTERN_MOVED
	update_objective_data(&"centrepiece", {"marker_tags": [TAG_LANTERN_MOVED]})
	courier_state = COURIER_CARRYING
	couriers.erase(carrier)
	couriers.push_front(carrier)  # the carrier leads; the escort walks beside his stops
	_couriers_walk(_store_point())


func _courier_carry() -> void:
	if courier_bag == null or not is_instance_valid(courier_bag) or not courier_bag.is_npc_carried():
		courier_state = COURIER_INTERCEPTED  # killed / intimidated / fighting: the canvas lies where he stood
		return
	var carrier: NpcBase = courier_bag.npc_carrier
	if not _near(carrier.global_position, _store_point(), COURIER_REACH_M):
		return
	var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
	if mgr != null:
		mgr.npc_drop(carrier)
	courier_state = COURIER_STORED  # the canvas is on the AS rack now (still there to steal, B3); back to LD
	for i: int in range(couriers.size()):
		var b: GuardBrain = _brain(couriers[i])
		if b != null and i < _courier_home.size():
			b.walk_to_post(_courier_home[i])


## Each courier walks to `to`; the others stand COURIER_ESCORT_M apart to the side of the walk.
func _couriers_walk(to: Vector3) -> void:
	for i: int in range(couriers.size()):
		var b: GuardBrain = _brain(couriers[i])
		if b == null:
			continue
		var side: Vector3 = Vector3.ZERO
		var dir: Vector3 = to - couriers[i].global_position
		dir.y = 0.0
		if i > 0 and dir.length() > 0.01:
			side = dir.normalized().cross(Vector3.UP) * COURIER_ESCORT_M * float(i)
		b.walk_to_post(to + side)


## The first courier still on his errand standing within COURIER_REACH_M of `at` (same floor), else null.
func _first_courier(at: Vector3) -> NpcBase:
	for c: NpcBase in _active_couriers():
		if _near(c.global_position, at, COURIER_REACH_M):
			return c
	return null


## Couriers still on the errand: alive and not stopped (LootManager.NPC_DROP_STATES: intimidated, tied, fighting...).
func _active_couriers() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for c: NpcBase in couriers:
		if is_instance_valid(c) and c.alive and not LootManager.NPC_DROP_STATES.has(int(c.alert_state)):
			out.append(c)
	return out


static func _brain(npc: NpcBase) -> GuardBrain:
	return npc.get_node_or_null(^"Brain") as GuardBrain if is_instance_valid(npc) else null


static func _near(a: Vector3, b: Vector3, r: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() <= r and absf(a.y - b.y) <= 1.5


## The rolled centrepiece LootSpawn (the one slot left after the variant strip), else null.
func _lantern_slot() -> LootSpawn:
	for n: Node in find_tagged(TAG_LANTERN):
		if n is LootSpawn:
			return n as LootSpawn
	return null


## Where to stand to take a hung canvas: its UsePoint (on the navmesh, heist_map.md §3), else the canvas itself.
static func _stand_of(n: Node3D) -> Vector3:
	var up: Node3D = n.get_node_or_null(^"UsePoint") as Node3D
	return up.global_position if up != null else n.global_position


## The AS rack the couriers carry the canvas to (STORE_DROP_LOCAL in the cp_store slot), else their walk-in point.
func _store_point() -> Vector3:
	var rt: HeistRuntime = HeistRuntime.of(self)
	var slot: Node3D = rt.map.get_node_or_null(NodePath(STORE_SLOT_PATH)) as Node3D if rt != null and rt.map != null else null
	if slot != null:
		return slot.global_transform * STORE_DROP_LOCAL
	return _courier_home[0] if not _courier_home.is_empty() else Vector3.ZERO


# --- Stealth flow --------------------------------------------------------------------------------

func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_TREASURY):
		_complete_once(&"treasury")
		_say_once(VO_TREASURY_OPEN)
	elif _is_tagged(interactable_net_id, TAG_VAULT_READER):
		_complete_once(&"art_store")
		_say_once(VO_ART_STORE_OPEN)
	elif _is_tagged(interactable_net_id, TAG_CODE):
		_complete_once(&"server_code")
		say(&"vo.mercer.gallery_night_code_found")
	elif _is_tagged(interactable_net_id, TAG_LANTERN):
		_complete_once(&"centrepiece")
	elif _is_tagged(interactable_net_id, TAG_SAFE):
		_complete_once(&"curator_safe")
	elif _is_tagged(interactable_net_id, TAG_LOCKERS):
		_taken[interactable_net_id] = true
		if _all_taken([TAG_LOCKERS]):
			_complete_once(&"lockers")  # Vance: "Friday's auction will be very short."
	elif _is_tagged(interactable_net_id, TAG_STORE_STUDY):
		_taken[interactable_net_id] = true
	else:
		for tag: StringName in LIST_TAGS:
			if _is_tagged(interactable_net_id, tag):
				_taken[interactable_net_id] = true
				_complete_once(&"canvases")
	_check_extras()
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
		_say_once(VO_ART_STORE_OPEN)
	elif _is_tagged(device_net_id, TAG_SERVER_DOOR):
		_complete_once(&"server_door")


## D-117: the Argus hack starts (once) / the vault drill goes on (once).
func _on_device_started(device_net_id: int, _kind: StringName, _duration: float) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		_say_once(VO_HACK_STARTED)
	elif _is_tagged(device_net_id, TAG_VAULT_DRILL):
		_say_once(VO_VAULT_DRILL)


## D-117: every Argus reboot / every drill jam (PD2: Bain calls each one).
func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_HACK):
		say(VO_HACK_INTERRUPTED)
	elif _is_tagged(device_net_id, TAG_VAULT_DRILL):
		say(VO_DRILL_JAM)


## D-117: the first keycard in the crew's hands (any card: lanyard, cabinet, desk, bar).
func _on_item_picked_up(item_id: StringName, _crew_slot: int) -> void:
	if item_id == ITEM_KEYCARD:
		_say_once(VO_KEYCARD)


## D-117: Vance, the first time a crew member carries the Lantern Bearer (cut, or taken from the Vaultline crew).
func _on_loot_picked(bag_net_id: int, _crew_slot: int) -> void:
	var bag: LootBag = Ids.lookup(bag_net_id) as LootBag
	if bag != null and bag.loot_id == LOOT_LANTERN:
		_say_once(VO_CENTREPIECE, {}, SPEAKER_VANCE)
		_complete_once(&"centrepiece")  # QC-57: taken back from the couriers (a pick_bag, not the slot's cut)


## D-117: the first Longshot on the hotel perch (S1); the conservatory perch (S2) has no line.
func _on_special_spawned(npc_net_id: int, special_type: StringName) -> void:
	if not String(special_type).contains(String(SPECIAL_LONGSHOT)):
		return
	var npc: Node3D = Ids.lookup(npc_net_id) as Node3D
	var rt: HeistRuntime = HeistRuntime.of(self)
	if npc == null or rt == null or rt.map == null:
		return
	var hotel: Node3D = rt.map.get_node_or_null(PERCH_HOTEL) as Node3D
	var cons: Node3D = rt.map.get_node_or_null(PERCH_CONSERVATORY) as Node3D
	if hotel == null:
		return
	var p: Vector3 = npc.global_position
	if cons == null or p.distance_squared_to(hotel.global_position) <= p.distance_squared_to(cons.global_position):
		_say_once(VO_SNIPER_HOTEL)


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
	_say_once(VO_PAYDAY, {}, SPEAKER_VANCE)  # D-117: the Lantern Bearer and one more are secured, the ride is here
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
	# Doc §Objectives Loud: no finding in loud (P's GN pass (e): it led the list); the canvas markers stay on
	# [centrepiece] / [canvases].
	_complete_once(&"find_canvases")
	say(&"vo.mercer.gallery_night_lockdown")
	for n: Node in find_tagged(TAG_SHUTTER):
		_bar(n)
	for d: Door in _doors(TAG_ART_DOOR, PATHS_ART_DOOR):
		d.relock(Door.Lock.BARRED)
	# P GN loud rerun: after last call the bronze doors are locked LOCKPICK; loud links them for the police
	# (breachable), so crew paths ran into a shut leaf. Loud blows the front: unlocked and breached open.
	for b: Door in _doors(TAG_BRONZE, PATHS_BRONZE):
		b.unlock()
		if not b.is_open:
			b.set_open(true, false, true)
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
	_say_once(VO_SHUTTERS_UP)


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


## D-117: say `line_id` the first time only (per heist). Returns true when it was said.
func _say_once(line_id: StringName, context: Dictionary = {}, speaker: StringName = SPEAKER_MERCER) -> bool:
	if _said.has(line_id):
		return false
	_said[line_id] = true
	say(line_id, context, speaker)
	return true


## A crew-detecting sphere (all layers, not monitorable) for the mission's approach hints.
func _proximity_area(area_name: String, radius: float) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = area_name
	area.collision_layer = 0
	area.collision_mask = 0xFFFFFFFF
	area.monitorable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = radius
	shape.shape = sph
	area.add_child(shape)
	return area


## [extras] (doc §Objectives 9): the whole list, the studies, the consignment lockers and the curator's safe.
func _check_extras() -> void:
	if objective_state(&"extras") != Enums.ObjectiveState.ACTIVE:
		return
	if objective_state(&"lockers") != Enums.ObjectiveState.COMPLETED \
			or objective_state(&"curator_safe") != Enums.ObjectiveState.COMPLETED:
		return
	var tags: Array[StringName] = LIST_TAGS.duplicate()
	tags.append(TAG_LANTERN)
	tags.append(TAG_STORE_STUDY)
	if _all_taken(tags):
		complete(&"extras")  # Vance: "The whole list and the studies too."


## Every live node with one of `tags` (visible, Interactable not switched off by _keep_first) has been taken.
func _all_taken(tags: Array[StringName]) -> bool:
	for tag: StringName in tags:
		for n: Node in find_tagged(tag):
			if n.is_queued_for_deletion() or not (n is Node3D) or not (n as Node3D).visible:
				continue
			var it: Node = n.get_node_or_null(^"Interactable")
			if it != null and not bool(it.get(&"enabled")) and not _taken.has(int(n.get(&"net_id"))):
				if n is DepositBox and not (n as DepositBox).opened:
					return false  # a kept locker still shut (its take interaction waits for the saw)
				continue
			var nid: Variant = n.get(&"net_id")
			if nid == null or not _taken.has(int(nid)):
				return false
	return true


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
