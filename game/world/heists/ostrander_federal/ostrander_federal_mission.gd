## Ostrander Federal mission flow. Owner: ENV A (mission scripts, owners.json); ENV C built the G1 stub (OF-C1), ENV A the
## flow (OF-A6). Design: docs/design/heists/ostrander_federal.md §Objectives / Mission script notes / Rare events / Escape
## (D-136 build notes), D-136 rulings (docs/process/next_heist_ostrander.md §3b). Contract heist_map.md §6: only the
## HeistMission API, EventBus and nodes of this map, found by objective_tag (never by node path: C may move them).
##
## Stealth: case (optional) -> the vault keycard (on Ashgrove, QC-52 carrier_tag, or a fallback spot) -> the vault code
## (hack the right officer's PC, reveals code group `vault`; `[code_hint]` names the PC) or the vault-control rack hack
## (starts the time lock itself) -> the vault gate (keycard) -> (optional) lasers off -> the code at the time-lock console
## -> hold `time_lock_s` (a mission timer, Night Deposit pattern, D-136.1) -> bag the cash cage (+ the padlocked bullion
## cage) -> secure 6 bags (4 on Routine; cash, gold and bonds count, tools and drives never) -> escape.
## Loud (alarm): LOCKDOWN (a running time lock is cancelled, the console and the rack die, the gate reader is dead and the
## gate BARRED unless crew stand inside it, the bronze doors shut and lock) -> the thermal drill comes in 2 tool bags
## `drill_eta_s` later at the rolled drop (respawning, D-136.9) -> both on the lid (DrillPoint requires_count 2) -> 360 s
## -> the burn-through enables the rope ladder, the hoist and the police rappel down the hole (QC-61) -> secure -> the
## escape opens `escape_eta_s` after [secure] (D-136.10). An alarm after the vault opened skips the drill.
## Fail reasons: custody / abort only (D-136.9): this script never ends the heist.
## D-117 §6: every mission line the doc writes is said here at its moment (the VO_* constants; ids per B's OF-B1 VO draft,
## content/docs/ostrander_federal_vo_draft.txt). Unknown ids are skipped by the subtitle overlay until B lands them.
## G1 compatibility (C's greybox predates OF-A1/A2/A3 on trunk): the drill's `requires_loot` / `requires_count`, the code
## PCs' `reveals_code_group` and the `starts_disabled` prefabs come as node metadata; _adopt_g1_metas applies them.
extends HeistMission

const REQUIRED_BAGS: int = 6
const REQUIRED_BAGS_ROUTINE: int = 4
## Doc §Loot path: cash, gold and bearer bonds count toward [secure]; server drives and small loot are bonus, tools never.
const REQUIRED_LOOT: Array[StringName] = [&"loot.cash_bricks", &"loot.gold", &"loot.bearer_bonds"]
const LOOT_DRILL_PART: StringName = &"loot.thermal_drill_part"
const LOOT_BONDS: StringName = &"loot.bearer_bonds"
const LOOT_DRIVES: StringName = &"loot.server_drives"
const DRILL_PARTS: int = 2
const ITEM_KEYCARD: StringName = &"item.keycard"
const CODE_GROUP: StringName = &"vault"
const ASSET_DRILL_DROP: StringName = &"asset.thermal_drill_drop"

const TAG_CASING: StringName = &"casing"
const TAG_KEYCARD: StringName = &"keycard"
const TAG_CODE_HINT: StringName = &"code_hint"
const TAG_CODE_PC: StringName = &"code_pc"
const TAG_SERVER: StringName = &"server"
const TAG_LASERS: StringName = &"lasers"
const TAG_LASER_GRID: StringName = &"laser_grid"
const TAG_VAULT_GATE: StringName = &"vault_gate"
const TAG_TIME_LOCK: StringName = &"time_lock"
const TAG_TIME_LOCK_WAIT: StringName = &"time_lock_wait"
const TAG_VAULT_DOOR: StringName = &"vault_door"
const TAG_VAULT_LOOT: StringName = &"vault_loot"
const TAG_GOLD_CAGE: StringName = &"gold_cage"
const TAG_SECURE: StringName = &"secure"
const TAG_ESCAPE: StringName = &"escape"
const TAG_ESCAPE_WAIT: StringName = &"escape_wait"
const TAG_DEPOSIT_BOXES: StringName = &"deposit_boxes"
const TAG_BOND_SAFE: StringName = &"bond_safe"
const TAG_PRESIDENT_SAFE: StringName = &"president_safe"
const TAG_SERVER_DRIVES: StringName = &"server_drives"
const TAG_DRILL_DELIVERY: StringName = &"drill_delivery"
const TAG_VAULT_DRILL: StringName = &"vault_drill"
const TAG_VAULT_BREACH: StringName = &"vault_breach"
const TAG_LID: StringName = &"lid"
const TAG_HOIST: StringName = &"hoist"
const TAG_BRONZE: StringName = &"bronze_doors"
## The rope ladder down the hole: C's G1 gives it no tag yet (ask: objective_tag `rope_ladder`); until then it is the
## Ladder carrying META_BURN_HEIGHT.
const TAG_ROPE_LADDER: StringName = &"rope_ladder"
## The police rappel down the hole (RAPPEL TacticalPoint tagged `hole_rappel` + `rappel_disabled`, OF-A2).
const TAG_HOLE_RAPPEL: StringName = &"hole_rappel"
## bond_delivery: +2 bond bags at markers tagged this (ask C), else beside the cash pallet's UsePoint.
const TAG_BOND_DELIVERY: StringName = &"bond_delivery"
const TAG_PERCH_TOWER: StringName = &"tower_sniper"
## C's G1 metadata (see the header).
const META_REQUIRES_LOOT: StringName = &"requires_loot"
const META_REQUIRES_COUNT: StringName = &"requires_count"
const META_REVEALS_CODE: StringName = &"reveals_code_group"
const META_STARTS_DISABLED: StringName = &"starts_disabled"
const META_BURN_HEIGHT: StringName = &"burn_height_m"
const META_BURN_LID: StringName = &"burn_lid"

const RARE_GLITCH: StringName = &"time_lock_glitch"
const RARE_BONDS: StringName = &"bond_delivery"
const RARE_VIP: StringName = &"vip_client"
const RARE_ARMORED_CAR: StringName = &"armored_car_early"
const RARE_TOWER: StringName = &"tower_sniper"
## Defaults when a rare event's effects omit the key (B's OF-B1 block: time_lock_s 30, extra_bonds 2, timed_spawn_s 900,
## heli_eta_add_s 30).
const GLITCH_TIME_LOCK_S: float = 30.0
const BOND_DELIVERY_BAGS: int = 2
const ARMORED_CAR_AT_S: float = 900.0
const TOWER_HELI_ADD_S: float = 30.0
const ARMORED_CAR_GUARDS: int = 2
const ARMORED_CAR_SPAWN_TAG: StringName = &"guard_vaultline"
const VIP_LINE_AT_S: float = 20.0
## Stealth heli (E3): called on [secure], lands after its zone's arrival_delay_s (45 s, doc §Escape).
const HELI_STEALTH_S: float = 45.0
const TIME_LOCK_WARN_S: float = 60.0
## Mercer's casing tips (doc §Mission script notes): [line, seconds into casing]. The operator tip only when he is in.
const CASE_TIPS: Array[Array] = [
	[&"vo.mercer.ostrander_federal_case_manager", 25.0],
	[&"vo.mercer.ostrander_federal_case_gallery", 50.0],
	[&"vo.mercer.ostrander_federal_case_operator", 75.0],
]
const CAMERA_WARN_METER: float = 0.5
const CAMERA_POLL_S: float = 0.25
## Safes / deposit boxes are opened by saws and drills without an interaction fact: polled.
const LOCK_POLL_S: float = 0.5
## A crew member counts as inside the vault gate when on its vault side within this height of the gate.
const GATE_SIDE_DY_M: float = 2.0
const SPECIAL_LONGSHOT: StringName = &"longshot"
## OF-A4 (D-136.4) civilian routes the mission expects C to place: route_id -> the spawn tags of the civilians it binds
## (CivilianRoute binds by its own bind_tags / patrol_graph; the mission binds any still-unbound match as a fallback).
## The officers' coffee runs are per desk (C fcc83280: CoffeeOfficerAO1 / OF / VO; `civ_officer` is the pre-fcc83280
## tag); teller_rotation is one route per side_door slot (only the rolled slot's is in the map, found by id).
## Away windows (CivilianRouteStop): `mgr_away` on the manager's isolated stops (BM door shut, CF/PR, the LK WC),
## `teller_away` on the rotating teller's BR / WC stops, `officer_away` on the coffee runs.
const ROUTES: Dictionary = {
	&"mgr_floor": [&"civ_manager_mgr_floor"],
	&"mgr_gallery": [&"civ_manager_mgr_gallery"],
	&"mgr_vault": [&"civ_manager_mgr_vault"],
	&"teller_rotation": [&"civ_teller_rotating"],
	&"officer_coffee": [&"civ_officer_ao1", &"civ_officer"],
	&"officer_coffee_of": [&"civ_officer_of"],
	&"officer_coffee_vo": [&"civ_officer_vo"],
}
const SPEAKER_ACCOUNTANT: StringName = &"accountant"

## D-117 §6 mission lines (B's OF-B1 draft ids; lines.tres event `mission` once B moves them in).
const VO_INTRO: StringName = &"vo.mercer.ostrander_federal_intro"
const VO_CONTACT_INTRO: StringName = &"vo.accountant.ostrander_federal_contact_intro"
const VO_PAYDAY: StringName = &"vo.accountant.ostrander_federal_payday"
const VO_KEYCARD: StringName = &"vo.mercer.ostrander_federal_keycard"
const VO_CODE_HINT: StringName = &"vo.mercer.ostrander_federal_code_hint"
const VO_PC_FOUND: StringName = &"vo.mercer.ostrander_federal_pc_found"
const VO_HACK_INTERRUPT: StringName = &"vo.mercer.ostrander_federal_hack_interrupt"
const VO_CODE: StringName = &"vo.mercer.ostrander_federal_code"
const VO_SERVER_HACK: StringName = &"vo.mercer.ostrander_federal_server_hack"
const VO_VAULT_GATE: StringName = &"vo.mercer.ostrander_federal_vault_gate"
const VO_LASERS_OFF: StringName = &"vo.mercer.ostrander_federal_lasers_off"
const VO_TIME_LOCK_STARTED: StringName = &"vo.mercer.ostrander_federal_time_lock_started"
const VO_TIME_LOCK_60: StringName = &"vo.mercer.ostrander_federal_time_lock_60"
const VO_TIME_LOCK_OPEN: StringName = &"vo.mercer.ostrander_federal_time_lock_open"
const VO_LAST_PAGER: StringName = &"vo.mercer.ostrander_federal_last_pager"
const VO_CAMERA_WARNING: StringName = &"vo.mercer.ostrander_federal_camera_warning"
const VO_VIP: StringName = &"vo.mercer.ostrander_federal_vip_client"
const VO_ARMORED_CAR: StringName = &"vo.mercer.ostrander_federal_armored_car"
const VO_LOCKDOWN: StringName = &"vo.mercer.ostrander_federal_lockdown"
const VO_LOCKDOWN_VAULT_OPEN: StringName = &"vo.mercer.ostrander_federal_lockdown_vault_open"
const VO_DRILL_INBOUND_TERRACE: StringName = &"vo.mercer.ostrander_federal_drill_inbound_terrace"
const VO_DRILL_INBOUND_DOCK: StringName = &"vo.mercer.ostrander_federal_drill_inbound_dock"
const VO_DRILL_DELIVERED_TERRACE: StringName = &"vo.mercer.ostrander_federal_drill_delivered_terrace"
const VO_DRILL_DELIVERED_DOCK: StringName = &"vo.mercer.ostrander_federal_drill_delivered_dock"
const VO_DRILL_PREPOSITIONED: StringName = &"vo.mercer.ostrander_federal_drill_prepositioned"
const VO_DRILL_STARTED: StringName = &"vo.mercer.ostrander_federal_drill_started"
const VO_DRILL_JAM: StringName = &"vo.mercer.ostrander_federal_drill_jam"
const VO_BURN_THROUGH: StringName = &"vo.mercer.ostrander_federal_burn_through"
const VO_HOIST: StringName = &"vo.mercer.ostrander_federal_hoist"
const VO_GOLD_CAGE: StringName = &"vo.mercer.ostrander_federal_gold_cage"
const VO_REQUIRED_SECURED: StringName = &"vo.mercer.ostrander_federal_required_secured"
const VO_VAN_ETA: StringName = &"vo.mercer.ostrander_federal_van_eta"
const VO_HELI_ETA: StringName = &"vo.mercer.ostrander_federal_heli_eta"
const VO_ESCAPE: StringName = &"vo.mercer.ostrander_federal_escape"
## Commander Brandt (the Aegis captain, L4.9) reaches the bank: B's OF-B1 row (Mercer, mission, priority 90).
const VO_CAPTAIN: StringName = &"vo.mercer.ostrander_federal_captain_arrived"
## Longshot lines by the SNIPER_PERCH tag of the perch he holds (C: s1 Assay Office, s2 garage deck, s3 Corvino window).
const SNIPER_LINES: Dictionary = {
	&"s1": &"vo.mercer.ostrander_federal_sniper_assay",
	&"s2": &"vo.mercer.ostrander_federal_sniper_garage",
	&"s3": &"vo.mercer.ostrander_federal_sniper_tower",
}
## Access steps moot once the lockdown hits (the time lock is dead): skipped so they leave the current-step slot.
const LOCKDOWN_SKIPPED: Array[StringName] = [&"keycard", &"code_hint", &"code_pc", &"server", &"vault_gate", &"lasers",
	&"time_lock"]
## Access steps moot once the escape is called (the loot is secured).
const ESCAPE_SKIPPED: Array[StringName] = [&"keycard", &"code_hint", &"code_pc", &"server", &"vault_gate", &"lasers",
	&"time_lock", &"drill_delivery", &"vault_drill", &"vault_breach"]

## Runtime facts (tests read them).
var lockdown: bool = false
var vault_open: bool = false
var time_lock_running: bool = false
var burned_through: bool = false
var escape_open: bool = false
var required_secured: int = 0
var drives_secured: int = 0

var _escape_called: bool = false
var _camera_warned: bool = false
## D-117: one-shot lines already said this heist.
var _said: Dictionary[StringName, bool] = {}
## Drill-part bag net_ids the crew has picked up ([drill_delivery] completes on both).
var _parts_picked: Dictionary[int, bool] = {}
var _drill_spawned: bool = false
## Kept (scalar-picked) deposit boxes: net_id -> DepositBox.
var _boxes: Dictionary[int, Node] = {}


func _on_mission_start() -> void:
	own_last_pager_line = true  # D-117: the heist's last-pager line replaces PagerSystem's generic one
	say(VO_INTRO)
	say(VO_CONTACT_INTRO, {}, SPEAKER_ACCOUNTANT)
	_add_objectives()
	on_event(&"interaction_completed", _on_interaction_completed)
	on_event(&"device_started", _on_device_started)
	on_event(&"device_jammed", _on_device_jammed)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"item_picked_up", _on_item_picked_up)
	on_event(&"loot_secured", _on_bag_secured)
	on_event(&"loot_picked", _on_loot_picked)
	on_event(&"small_loot_taken", _on_small_loot_taken)
	on_event(&"special_spawned", _on_special_spawned)
	on_event(&"captain_arrived", _on_captain_arrived)
	_adopt_g1_metas()
	_apply_scalars()
	_watch_gate()
	_watch_padlocks()
	_wire_routes()
	_schedule_rare_events()
	_schedule_casing_tips()
	if is_variant_revealed(TAG_CODE_PC):
		_on_variant_revealed(TAG_CODE_PC)  # asset.intel_code_pc: the PC is known from the start
	start_timer(&"camera_watch", CAMERA_POLL_S, _poll_cameras)
	start_timer(&"lock_watch", LOCK_POLL_S, _poll_locks)


func _add_objectives() -> void:
	# Literal states (B's VO coverage scan reads the HIDDEN -> ACTIVE reveals off `_add(&"id", ObjectiveState.X` + activate).
	_add(&"casing", Enums.ObjectiveState.ACTIVE, [TAG_CASING], {"optional": true})
	_add(&"keycard", Enums.ObjectiveState.ACTIVE, [TAG_KEYCARD])
	require_items(&"keycard", ITEM_KEYCARD)
	_add(&"code_hint", Enums.ObjectiveState.ACTIVE, [TAG_CODE_HINT], {"optional": true})
	# The code PC is unknown until [code_hint] (or asset.intel_code_pc) names it: the marker points at the planner first.
	_add(&"code_pc", Enums.ObjectiveState.ACTIVE, [TAG_CODE_HINT], {"alternative": &"server", "duration_s": 45.0})
	_add(&"server", Enums.ObjectiveState.ACTIVE, [TAG_SERVER],
		{"alternative": &"code_pc", "optional": true, "location": variant(&"server_room")})
	_add(&"vault_gate", Enums.ObjectiveState.ACTIVE, [TAG_VAULT_GATE])
	_add(&"lasers", Enums.ObjectiveState.ACTIVE, [TAG_LASERS], {"optional": true})
	_add(&"time_lock", Enums.ObjectiveState.HIDDEN, [TAG_TIME_LOCK])
	_add(&"time_lock_wait", Enums.ObjectiveState.HIDDEN, [TAG_TIME_LOCK_WAIT])
	_add(&"vault_loot", Enums.ObjectiveState.HIDDEN, [TAG_VAULT_LOOT])
	_add(&"gold_cage", Enums.ObjectiveState.HIDDEN, [TAG_GOLD_CAGE], {"optional": true})
	# ENV B (LEAD r245 1): the loud drill steps sit above `secure` so the HUD's first ACTIVE step reads the drill.
	_add(&"drill_delivery", Enums.ObjectiveState.HIDDEN, [TAG_DRILL_DELIVERY], {"count": 0, "total": DRILL_PARTS})
	_add(&"vault_drill", Enums.ObjectiveState.HIDDEN, [TAG_VAULT_DRILL])
	_add(&"vault_breach", Enums.ObjectiveState.HIDDEN, [TAG_VAULT_BREACH])
	_add(&"secure", Enums.ObjectiveState.ACTIVE, [TAG_SECURE], {"count": 0, "total": required_bags(), "optional_more": true})
	_add(&"deposit_boxes", Enums.ObjectiveState.ACTIVE, [TAG_DEPOSIT_BOXES], {"optional": true, "side": true})
	_add(&"bond_safe", Enums.ObjectiveState.ACTIVE, [TAG_BOND_SAFE], {"optional": true, "side": true})
	_add(&"president_safe", Enums.ObjectiveState.ACTIVE, [TAG_PRESIDENT_SAFE], {"optional": true, "side": true})
	_add(&"server_drives", Enums.ObjectiveState.ACTIVE, [TAG_SERVER_DRIVES], {"optional": true, "side": true})
	_add(&"escape_wait", Enums.ObjectiveState.HIDDEN, [TAG_ESCAPE_WAIT])
	_add(&"escape", Enums.ObjectiveState.HIDDEN, [TAG_ESCAPE])


## ui_hud 1.8 / D-089: every objective carries marker_tags (text key objective.ostrander_federal.<id>, B).
func _add(id: StringName, state: Enums.ObjectiveState, tags: Array, data: Dictionary = {}) -> void:
	var d: Dictionary = data.duplicate()
	d["marker_tags"] = tags
	add_objective(id, StringName("objective.ostrander_federal.%s" % id), state, d)


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING:
		_complete_once(&"casing")
	if new_phase == Enums.HeistPhase.LOUD:
		_go_loud()


## D-136.9: every alarm goes loud; nothing here fails the heist.
func _on_alarm(_reason: StringName) -> void:
	_go_loud()


func _on_pager_answered(total: int) -> void:
	if total == pager_cap():
		say(VO_LAST_PAGER, {"answered": total})


## QC-63: the planner (or bought intel) named the code PC: its marker now points at it.
func _on_variant_revealed(group: StringName) -> void:
	if group != TAG_CODE_PC:
		return
	update_objective_data(&"code_pc", {"marker_tags": [TAG_CODE_PC], "revealed": true})
	if objective_state(&"code_hint") == Enums.ObjectiveState.ACTIVE:
		complete(&"code_hint")
	if phase != Enums.HeistPhase.LOADING and elapsed_s > 0.0:
		_say_once(VO_CODE_HINT)


## Bags to secure: 6, 4 on Routine (doc §Loot path, D-075).
func required_bags() -> int:
	return REQUIRED_BAGS_ROUTINE if difficulty == Enums.Difficulty.ROUTINE else REQUIRED_BAGS


# --- Setup ---------------------------------------------------------------------------------------

## C's G1 carries the OF-A1/A2/A3 fields as metadata (see the header); the time-lock console and the vault-control rack
## also target the vault door, which would open it without the time lock: the mission owns the vault door (D-136.1).
func _adopt_g1_metas() -> void:
	for n: Node in find_tagged(TAG_VAULT_DRILL):
		var dp: DrillPoint = n as DrillPoint
		if dp != null and dp.requires_loot == &"" and dp.has_meta(META_REQUIRES_LOOT):
			dp.requires_loot = StringName(String(dp.get_meta(META_REQUIRES_LOOT)))
			dp.requires_count = int(dp.get_meta(META_REQUIRES_COUNT, DRILL_PARTS))
	for n: Node in find_tagged(TAG_CODE_PC):
		var ht: HackTerminal = n as HackTerminal
		if ht != null and ht.reveals_code_group == &"":
			ht.reveals_code_group = StringName(String(ht.get_meta(META_REVEALS_CODE, CODE_GROUP)))
	for tag: StringName in [TAG_TIME_LOCK, TAG_SERVER]:
		for n: Node in find_tagged(tag):
			if n is Keypad:
				(n as Keypad).targets = [] as Array[NodePath]
			elif n is HackTerminal:
				(n as HackTerminal).targets = [] as Array[NodePath]
	for p: GameplayPrefab in _burn_prefabs():
		if p.has_meta(META_STARTS_DISABLED) and p.is_enabled():
			p.set_enabled(false)


## The prefabs the burn-through switches on: the hoist, the rope ladder (tag, else the Ladder with META_BURN_HEIGHT).
func _burn_prefabs() -> Array[GameplayPrefab]:
	var out: Array[GameplayPrefab] = []
	for tag: StringName in [TAG_HOIST, TAG_ROPE_LADDER]:
		for n: Node in find_tagged(tag):
			if n is GameplayPrefab and not out.has(n):
				out.append(n as GameplayPrefab)
	for l: Ladder in rope_ladders():
		if not out.has(l):
			out.append(l)
	return out


## The rope ladder(s) down the hole.
func rope_ladders() -> Array[Ladder]:
	var out: Array[Ladder] = []
	for n: Node in find_tagged(TAG_ROPE_LADDER):
		if n is Ladder:
			out.append(n as Ladder)
	if out.is_empty() and _runtime != null and _runtime.map != null:
		for n: Node in _runtime.map.find_children("*", "", true, false):
			if n is Ladder and n.has_meta(META_BURN_HEIGHT):
				out.append(n as Ladder)
	return out


## OF-A4: each expected CivilianRoute present binds its civilians (fallback for routes without bind_tags); a missing
## route is logged once (the civilian keeps its one-floor wander, the §3b.4 fallback). Returns how many routes exist.
func _wire_routes() -> int:
	var found: int = 0
	for route_id: StringName in ROUTES:
		var route: CivilianRoute = CivilianRoute.find(_runtime, route_id)
		if route == null:
			Log.info(&"mission", "civilian route '%s' not placed: %s wander (D-136.4 fallback)" % [route_id, ROUTES[route_id]])
			continue
		found += 1
		for n: Node in _runtime.npcs(&"civilian"):
			var npc: NpcBase = n as NpcBase
			var tags: Array[StringName] = []
			tags.assign(ROUTES[route_id])
			if npc != null and _has_spawn_tag(npc, tags) \
					and CivilianRoute.for_civilian(_runtime, npc) == null:
				route.bind(npc)
	return found


## Scalars: cash_bags / gold_bags on the vault spawns, deposit_boxes kept on the vault walls (first N by name; the SD
## hall keeps its 8, doc §Loot table). Each kept box locks its small loot until sawn (DepositBox).
func _apply_scalars() -> void:
	_set_spawn_count(TAG_VAULT_LOOT, &"loot.cash_bricks", int(_scalar(&"cash_bags", 6)))
	_set_spawn_count(TAG_GOLD_CAGE, &"loot.gold", int(_scalar(&"gold_bags", 2)))
	var vault_boxes: Array[Node] = []
	var hall_boxes: Array[Node] = []
	for n: Node in find_tagged(TAG_DEPOSIT_BOXES):
		if n is DepositBox:
			(vault_boxes if String(n.name).begins_with("VaultBox") else hall_boxes).append(n)
	_keep_boxes(vault_boxes, int(_scalar(&"deposit_boxes", 9)))
	_keep_boxes(hall_boxes, 8)


func _set_spawn_count(tag: StringName, loot_id: StringName, count: int) -> void:
	for n: Node in find_tagged(tag):
		var ls: LootSpawn = n as LootSpawn
		if ls != null and ls.loot_id == loot_id:
			ls.count = count
			ls.remaining = count


func _keep_boxes(boxes: Array[Node], keep: int) -> void:
	boxes.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for i: int in range(boxes.size()):
		var box: DepositBox = boxes[i] as DepositBox
		if i < keep:
			_boxes[box.net_id] = box
			continue
		box.remove_from_group(G.SAW_TARGET)  # the saw cannot open a box that is not there
		box.set_enabled(false)


## The vault gate opened by its reader (interaction) or any other way (open_changed).
func _watch_gate() -> void:
	for n: Node in find_tagged(TAG_VAULT_GATE):
		if n is Door:
			(n as Door).open_changed.connect(func(open: bool, _by: int) -> void:
				if open:
					_gate_opened())


## D-138 cage padlocks: the bullion cage opened (any method) -> [gold_cage] and Mercer's gold line.
func _watch_padlocks() -> void:
	for n: Node in find_tagged(TAG_GOLD_CAGE):
		if n is Padlock:
			(n as Padlock).lock_opened.connect(func(_how: StringName) -> void: _gold_cage_opened())


## Rare events (B's OF-B1 effect keys): time_lock_glitch (time_lock_s, read at the time lock), bond_delivery
## (extra_bonds), vip_client (force_active vip_in: the resolver spawns them; Mercer names it), armored_car_early
## (timed_spawn_s, QC-25: 2 Vaultline crew at the dock walk to the vault gate), tower_sniper (perch_s3: S3 open for the
## director's Longshots; heli_eta_add_s on the loud heli).
func _schedule_rare_events() -> void:
	var fx: Dictionary = rare_effects()
	set_sniper_perches_open(TAG_PERCH_TOWER, fx.has(RARE_TOWER))
	if fx.has(RARE_BONDS):
		_deliver_bonds(int((fx[RARE_BONDS] as Dictionary).get("extra_bonds", BOND_DELIVERY_BAGS)))
	if fx.has(RARE_VIP):
		start_timer(&"vip_line", VIP_LINE_AT_S, func() -> void:
			if not went_loud:
				_say_once(VO_VIP))
	if fx.has(RARE_ARMORED_CAR) and difficulty >= Enums.Difficulty.BRUTAL:
		schedule_at(float((fx[RARE_ARMORED_CAR] as Dictionary).get("timed_spawn_s", ARMORED_CAR_AT_S)), &"armored_car",
			_on_armored_car)


## bond_delivery: +N bond bags in the vault (markers tagged bond_delivery, else by the cash pallet's UsePoint).
func _deliver_bonds(count: int) -> void:
	if count <= 0:
		return
	if not loot_markers(TAG_BOND_DELIVERY).is_empty():
		spawn_loot(LOOT_BONDS, TAG_BOND_DELIVERY, count)
		return
	var loot: LootManager = _runtime.service(G.SVC_LOOT) as LootManager if _runtime != null else null
	for n: Node in find_tagged(TAG_VAULT_LOOT):
		var ls: LootSpawn = n as LootSpawn
		if ls == null or loot == null:
			continue
		var at: Node3D = ls.use_point if ls.use_point != null else ls
		for i: int in range(count):
			var xf: Transform3D = Transform3D(Basis.IDENTITY, at.global_position + Vector3(0.6 * float(i) - 0.3, 0.3, 0.0))
			loot.spawn_bag(LOOT_BONDS, xf)
		return
	Log.warn(&"mission", "bond_delivery: no bond_delivery marker and no vault_loot spawn")


## armored_car_early (stealth only): two Vaultline crew (pagers) step out at the dock and walk to the vault gate (doc
## §Rare events: LD -> BC -> SA -> BB, by navmesh; NPCs cannot ride bag_lift).
func _on_armored_car() -> void:
	if went_loud:
		return
	var crew: Array[Node] = spawn_guards(ARMORED_CAR_GUARDS, ARMORED_CAR_SPAWN_TAG)
	if crew.is_empty():
		return
	say(VO_ARMORED_CAR)
	update_objective_data(&"secure", {"armored_car": true})
	var dest: Vector3 = _gate_stand()
	for n: Node in crew:
		var b: GuardBrain = n.get_node_or_null(^"Brain") as GuardBrain
		if b != null and dest != Vector3.INF:
			b.walk_to_post(dest)


## Where a visitor stands at the vault gate: the reader's UsePoint, else the gate.
func _gate_stand() -> Vector3:
	for n: Node in find_tagged(TAG_VAULT_GATE):
		if n is KeycardReader and (n as KeycardReader).use_point != null:
			return (n as KeycardReader).use_point.global_position
	for n: Node in find_tagged(TAG_VAULT_GATE):
		if n is Node3D:
			return (n as Node3D).global_position
	return Vector3.INF


## Mercer's casing tips while the crew is still casing (stealth only; the operator tip only when he is in).
func _schedule_casing_tips() -> void:
	for i: int in range(CASE_TIPS.size()):
		var line: StringName = CASE_TIPS[i][0]
		if line == &"vo.mercer.ostrander_federal_case_operator" and not _slot_active(&"security_room_staffed", &"sec_staffed"):
			continue
		start_timer(StringName("case_tip_%d" % i), float(CASE_TIPS[i][1]), func() -> void:
			if phase == Enums.HeistPhase.CASING and not went_loud:
				_say_once(line))


# --- Stealth flow --------------------------------------------------------------------------------

func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, _kind: StringName) -> void:
	if _is_tagged(interactable_net_id, TAG_VAULT_GATE):
		_gate_opened()
	elif _is_tagged(interactable_net_id, TAG_TIME_LOCK):
		if not lockdown:
			_start_time_lock(&"code")
	elif _is_tagged(interactable_net_id, TAG_CODE_HINT):
		# QC-63: a CodeNote with reveals_variant_group reveals itself; any other planner reveals here.
		if not is_variant_revealed(TAG_CODE_PC):
			reveal_variant_group(TAG_CODE_PC)
		_complete_once(&"code_hint")
	elif _is_tagged(interactable_net_id, TAG_HOIST):
		_say_once(VO_HOIST)
	elif _is_tagged(interactable_net_id, TAG_VAULT_LOOT):
		_check_spawn_emptied(&"vault_loot", TAG_VAULT_LOOT)


func _on_device_started(device_net_id: int, _kind: StringName, _duration: float) -> void:
	if _is_tagged(device_net_id, TAG_CODE_PC):
		_say_once(VO_PC_FOUND)
	elif _is_tagged(device_net_id, TAG_SERVER):
		_say_once(VO_SERVER_HACK)
	elif _is_tagged(device_net_id, TAG_VAULT_DRILL):
		_say_once(VO_DRILL_STARTED)
		_complete_once(&"drill_delivery")


## Every hack stall / drill jam (PD2: Bain calls each one); the lockdown's own pause is not a stall.
func _on_device_jammed(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_VAULT_DRILL):
		say(VO_DRILL_JAM)
	elif not lockdown and (_is_tagged(device_net_id, TAG_CODE_PC) or _is_tagged(device_net_id, TAG_SERVER)):
		say(VO_HACK_INTERRUPT)


func _on_device_finished(device_net_id: int) -> void:
	if _is_tagged(device_net_id, TAG_CODE_PC):
		_code_found()
	elif _is_tagged(device_net_id, TAG_SERVER):
		if not lockdown:
			_complete_once(&"server")
			_start_time_lock(&"server")
	elif _is_tagged(device_net_id, TAG_LASERS):
		_lasers_off()
	elif _is_tagged(device_net_id, TAG_VAULT_DRILL):
		burn_through()


## The vault code off the right PC (HackTerminal.reveals_code_group `vault`, QC-63).
func _code_found() -> void:
	if objective_state(&"code_pc") == Enums.ObjectiveState.COMPLETED:
		return
	complete(&"code_pc")
	update_objective_data(&"code_pc", {"marker_tags": [TAG_CODE_PC]})
	_say_once(VO_CODE)
	if objective_state(&"server") == Enums.ObjectiveState.ACTIVE:
		update_objective_data(&"server", {"skipped": true})


func _on_item_picked_up(item_id: StringName, _crew_slot: int) -> void:
	if item_id == ITEM_KEYCARD:
		_say_once(VO_KEYCARD)


func _gate_opened() -> void:
	if objective_state(&"vault_gate") == Enums.ObjectiveState.COMPLETED:
		return
	complete(&"vault_gate")
	_say_once(VO_VAULT_GATE)
	if not lockdown and not vault_open and not time_lock_running:
		activate(&"time_lock")


## [lasers]: the laser controller hack switches the concourse grid off (ECM never does, S9.10).
func _lasers_off() -> void:
	for g: Node in find_tagged(TAG_LASER_GRID):
		if g is LaserGrid:
			(g as LaserGrid).set_enabled(false)
	_complete_once(&"lasers")
	_say_once(VO_LASERS_OFF)


## The time lock (Night Deposit pattern, D-136.1): a mission timer of `time_lock_s` (30 s on time_lock_glitch); the
## code at the console (`code`) or the finished rack hack (`server`) starts it.
func _start_time_lock(method: StringName) -> void:
	if time_lock_running or vault_open or lockdown:
		return
	time_lock_running = true
	var seconds: float = float(_scalar(&"time_lock_s", 210.0))
	var fx: Dictionary = rare_effects()
	if fx.has(RARE_GLITCH):
		seconds = float((fx[RARE_GLITCH] as Dictionary).get("time_lock_s", GLITCH_TIME_LOCK_S))
	if objective_state(&"time_lock") != Enums.ObjectiveState.COMPLETED:
		complete(&"time_lock")
	if method == &"server" and objective_state(&"code_pc") == Enums.ObjectiveState.ACTIVE:
		update_objective_data(&"code_pc", {"skipped": true})
		complete(&"code_pc")
	update_objective_data(&"time_lock_wait", {"seconds": seconds, "method": method})
	activate(&"time_lock_wait")
	say(VO_TIME_LOCK_STARTED, {"seconds": int(seconds)})
	start_timer(&"time_lock", seconds, _on_time_lock_done)
	if seconds > TIME_LOCK_WARN_S:
		start_timer(&"time_lock_60", seconds - TIME_LOCK_WARN_S, func() -> void:
			if time_lock_running:
				say(VO_TIME_LOCK_60))


func _on_time_lock_done() -> void:
	if not time_lock_running or lockdown:
		return
	time_lock_running = false
	complete(&"time_lock_wait")
	say(VO_TIME_LOCK_OPEN)
	open_vault()


## The vault door opens (time lock released); the cages are the next step.
func open_vault() -> void:
	if vault_open:
		return
	vault_open = true
	for d: Node in find_tagged(TAG_VAULT_DOOR):
		if d is Door:
			(d as Door).unlock()
			(d as Door).set_open(true)
	_vault_reachable()


func _vault_reachable() -> void:
	if objective_state(&"vault_loot") == Enums.ObjectiveState.HIDDEN:
		activate(&"vault_loot")
	if objective_state(&"gold_cage") == Enums.ObjectiveState.HIDDEN:
		activate(&"gold_cage")


func _gold_cage_opened() -> void:
	if objective_state(&"gold_cage") != Enums.ObjectiveState.COMPLETED:
		complete(&"gold_cage")
	_say_once(VO_GOLD_CAGE)


func _check_spawn_emptied(objective_id: StringName, tag: StringName) -> void:
	var left: int = 0
	var any: bool = false
	for n: Node in find_tagged(tag):
		if n is LootSpawn:
			any = true
			left += (n as LootSpawn).remaining
	if any and left <= 0:
		_complete_once(objective_id)


## Safes (bond / president) opened by a drill, a saw or a lockpick; every kept deposit box emptied.
func _poll_locks() -> void:
	if objective_state(&"bond_safe") == Enums.ObjectiveState.ACTIVE and _safe_opened(TAG_BOND_SAFE):
		_complete_once(&"bond_safe")
	if objective_state(&"president_safe") == Enums.ObjectiveState.ACTIVE and _safe_opened(TAG_PRESIDENT_SAFE):
		_complete_once(&"president_safe")
	start_timer(&"lock_watch", LOCK_POLL_S, _poll_locks)


func _safe_opened(tag: StringName) -> bool:
	for n: Node in find_tagged(tag):
		if n is Safe and (n as Safe).opened:
			return true
	return false


func _on_small_loot_taken(_value: int, _crew_slot: int) -> void:
	if objective_state(&"deposit_boxes") != Enums.ObjectiveState.ACTIVE or _boxes.is_empty():
		return
	for id: int in _boxes:
		var box: DepositBox = _boxes[id] as DepositBox
		if is_instance_valid(box) and not box.taken:
			return
	complete(&"deposit_boxes")


## D-117: Mercer's camera warning, once, the first time a camera's meter on any crew member reaches CAMERA_WARN_METER
## (StealthDirector rows: server, every slot), before the alarm.
func _poll_cameras() -> void:
	if _camera_warned or went_loud or _runtime == null:
		return
	var st: StealthDirector = _runtime.stealth
	if st != null:
		for slot: int in range(Net.MAX_CREW):
			for e: Dictionary in st.detection_entries(slot):
				if int(e.get("kind", -1)) == Enums.ObserverKind.CAMERA and float(e.get("value", 0.0)) >= CAMERA_WARN_METER:
					_camera_warned = true
					say(VO_CAMERA_WARNING)
					return
	start_timer(&"camera_watch", CAMERA_POLL_S, _poll_cameras)


## Brandt arrives (AegisCaptain, L4.9): Mercer names him each time he comes in (PD2: Bain on every Winters arrival).
func _on_captain_arrived(_npc_net_id: int) -> void:
	say(VO_CAPTAIN)


## Longshots (L4.7): the line names the perch he holds (s1 Assay Office, s2 garage deck, s3 Corvino), once per perch.
func _on_special_spawned(npc_net_id: int, special_type: StringName) -> void:
	if not String(special_type).contains(String(SPECIAL_LONGSHOT)):
		return
	var perch: TacticalPoint = sniper_perch_of(npc_net_id)
	if perch == null:
		return
	for tag: StringName in SNIPER_LINES:
		if perch.tags.has(tag):
			_say_once(SNIPER_LINES[tag])


# --- Loot / escape -------------------------------------------------------------------------------

## [secure]: cash, gold and bonds count (doc §Loot path); drives are bonus; tool bags are never secured (D-068).
func _on_bag_secured(_bag_net_id: int, loot_id: StringName, _value: int) -> void:
	if loot_id == LOOT_DRIVES:
		drives_secured += 1
		if drives_secured >= _drive_total():
			_complete_once(&"server_drives")
		return
	if not REQUIRED_LOOT.has(loot_id):
		return
	required_secured += 1
	update_objective_data(&"secure", {"count": required_secured, "total": required_bags()})
	if required_secured >= required_bags() and objective_state(&"secure") != Enums.ObjectiveState.COMPLETED:
		complete(&"secure")
		_complete_once(&"vault_loot")
		say(VO_REQUIRED_SECURED)
		_call_escape()


## [server_drives]: every drive bag of the SV racks secured (their spawns' count; 2 on G1).
func _drive_total() -> int:
	var total: int = 0
	for n: Node in find_tagged(TAG_SERVER_DRIVES):
		if n is LootSpawn:
			total += (n as LootSpawn).count
	return maxi(total, 1)


## One rule per heist (D-136.10). Stealth: the van escape opens at once; the heli (E3) is called and lands after its
## zone's arrival delay (45 s). Loud: the ride returns `escape_eta_s` after [secure] (+heli_eta_add_s on
## tower_sniper for the heli), whatever the assault phase.
func _call_escape() -> void:
	if _escape_called:
		return
	_escape_called = true
	for id: StringName in ESCAPE_SKIPPED:
		if objective_state(id) == Enums.ObjectiveState.ACTIVE:
			update_objective_data(id, {"disabled": true, "reason": &"escape", "skipped": true})
			complete(id)
	var heli: bool = is_heli_escape()
	if not went_loud:
		if heli:
			say(VO_HELI_ETA, {"seconds": int(_heli_zone_delay())})
		open_escape()
		return
	var eta: float = loud_escape_eta()
	update_objective_data(&"escape_wait", {"seconds": eta})  # ENV B HUD: "ESCAPE mm:ss" countdown
	activate(&"escape_wait")
	say(VO_HELI_ETA if heli else VO_VAN_ETA, {"seconds": int(eta)})
	start_timer(&"escape_eta", eta, open_escape)


## The loud ride's wait (s): escape_eta_s, +heli_eta_add_s for the heli on tower_sniper.
func loud_escape_eta() -> float:
	var eta: float = float(_scalar(&"escape_eta_s", 120.0))
	var fx: Dictionary = rare_effects()
	if is_heli_escape() and fx.has(RARE_TOWER):
		eta += float((fx[RARE_TOWER] as Dictionary).get("heli_eta_add_s", TOWER_HELI_ADD_S))
	return eta


func is_heli_escape() -> bool:
	return _slot_active(&"escape", &"esc_heli_terrace")


func open_escape() -> void:
	if escape_open:
		return
	escape_open = true
	if objective_state(&"escape_wait") == Enums.ObjectiveState.ACTIVE:
		complete(&"escape_wait")
	if went_loud:
		_set_escape_delay(0.0)  # the loud wait already ran: the ride is here
	activate(&"escape")
	say(VO_ESCAPE)
	_say_once(VO_PAYDAY, {}, SPEAKER_ACCOUNTANT)
	activate_escape(TAG_ESCAPE)


func _heli_zone_delay() -> float:
	for n: Node in find_tagged(TAG_ESCAPE):
		if n is EscapeZone:
			return (n as EscapeZone).arrival_delay_s
	return HELI_STEALTH_S


func _set_escape_delay(seconds: float) -> void:
	for n: Node in find_tagged(TAG_ESCAPE):
		if n is EscapeZone:
			(n as EscapeZone).arrival_delay_s = seconds


# --- Loud flow -----------------------------------------------------------------------------------

## LOCKDOWN (doc §Loud 1, D-136.1/7): a running time lock is cancelled ([time_lock_wait] fails), the console and the
## vault-control rack die (pause &"lockdown"), the gate reader is dead and the gate BARRED (left open and unlocked when
## it is open or crew stand inside it: no soft lock, D-093), the bronze doors shut and lock (breach layer, D-122).
## With the vault already open the drill is skipped; else the drill delivery is scheduled.
func _go_loud() -> void:
	if lockdown:
		return
	lockdown = true
	for n: Node in find_tagged(TAG_TIME_LOCK):
		_set_interactable(n, false)
	for n: Node in find_tagged(TAG_SERVER):
		if n is HackTerminal:
			(n as HackTerminal).pause(&"lockdown")
		_set_interactable(n, false)
	for n: Node in find_tagged(TAG_VAULT_GATE):
		if n is KeycardReader:
			(n as KeycardReader).set_disabled(true)
	for n: Node in find_tagged(TAG_BRONZE):
		if n is Door:
			(n as Door).relock(Door.Lock.LOCKPICK)
	if time_lock_running:
		time_lock_running = false
		cancel_timer(&"time_lock")
		cancel_timer(&"time_lock_60")
		fail(&"time_lock_wait")
	for id: StringName in LOCKDOWN_SKIPPED:
		if objective_state(id) == Enums.ObjectiveState.ACTIVE:
			update_objective_data(id, {"disabled": true, "reason": &"lockdown", "skipped": true})
			complete(id)
	if vault_open:
		say(VO_LOCKDOWN_VAULT_OPEN)
	else:
		say(VO_LOCKDOWN)
		_bar_gate()
		_schedule_drill()
	if objective_state(&"secure") == Enums.ObjectiveState.COMPLETED:
		_call_escape()


func _bar_gate() -> void:
	for n: Node in find_tagged(TAG_VAULT_GATE):
		var d: Door = n as Door
		if d == null:
			continue
		if d.is_open or crew_inside_gate(d):
			d.unlock()
			d.set_open(true)
		else:
			d.relock(Door.Lock.BARRED)


## True when a crew member stands on the vault side of `gate` (the side the vault door is on), on the gate's floor.
func crew_inside_gate(gate: Door) -> bool:
	var vault: Node3D = null
	for n: Node in find_tagged(TAG_VAULT_DOOR):
		if n is Node3D:
			vault = n as Node3D
	if vault == null:
		return false
	var axis: Vector3 = gate.global_transform.basis.z
	var vault_side: float = signf(axis.dot(vault.global_position - gate.global_position))
	for c: Node in get_tree().get_nodes_in_group(G.CREW):
		var c3: Node3D = c as Node3D
		if c3 == null or not _runtime.is_ancestor_of(c3):
			continue
		var rel: Vector3 = c3.global_position - gate.global_position
		if absf(rel.y) <= GATE_SIDE_DY_M and signf(axis.dot(rel)) == vault_side:
			return true
	return false


## The thermal drill (doc §Loud 2): with asset.thermal_drill_drop the bags already wait at the drop (topped up to 2,
## respawning); else 2 bags spawn at the rolled drop `drill_eta_s` after the alarm (respawning, D-136.9).
func _schedule_drill() -> void:
	activate(&"drill_delivery")
	var where: StringName = &"terrace" if _slot_active(&"drill_delivery", &"drop_terrace") else &"dock"
	update_objective_data(&"drill_delivery", {"location": where})
	if has_asset(ASSET_DRILL_DROP):
		_preposition_drill()
		return
	var eta: float = float(_scalar(&"drill_eta_s", 60.0))
	say(VO_DRILL_INBOUND_TERRACE if where == &"terrace" else VO_DRILL_INBOUND_DOCK, {"seconds": int(eta)})
	start_timer(&"drill_delivery", eta, _deliver_drill.bind(where))


func _deliver_drill(where: StringName) -> void:
	if _drill_spawned or burned_through:
		return
	_drill_spawned = true
	var bags: Array = spawn_loot(LOOT_DRILL_PART, TAG_DRILL_DELIVERY, DRILL_PARTS, true)
	if bags.is_empty():
		Log.warn(&"mission", "drill delivery: no %s marker, the parts did not arrive" % TAG_DRILL_DELIVERY)
		return
	say(VO_DRILL_DELIVERED_TERRACE if where == &"terrace" else VO_DRILL_DELIVERED_DOCK)
	activate(&"vault_drill")


## asset.thermal_drill_drop (QC-66): PreplanAssets drops one bag at the point; the mission tops it up to 2 at the drop
## marker and watches every part for respawn.
func _preposition_drill() -> void:
	_drill_spawned = true
	var markers: Array[Node3D] = loot_markers(TAG_DRILL_DELIVERY)
	var have: int = 0
	if _runtime != null:
		for v: Variant in _runtime.preplan.drops.values():
			var bag: LootBag = v as LootBag
			if bag != null and is_instance_valid(bag) and bag.loot_id == LOOT_DRILL_PART:
				have += 1
				if not markers.is_empty():
					_watch_respawn(bag, markers[0])
	if have < DRILL_PARTS:
		spawn_loot(LOOT_DRILL_PART, TAG_DRILL_DELIVERY, DRILL_PARTS - have, true)
	say(VO_DRILL_PREPOSITIONED)
	activate(&"vault_drill")


## [drill_delivery] completes once the crew holds both parts (or the drill starts); the count follows each part.
func _on_loot_picked(bag_net_id: int, _crew_slot: int) -> void:
	var bag: LootBag = Ids.lookup(bag_net_id) as LootBag
	if bag == null or bag.loot_id != LOOT_DRILL_PART or _parts_picked.has(bag_net_id):
		return
	_parts_picked[bag_net_id] = true
	update_objective_data(&"drill_delivery", {"count": mini(_parts_picked.size(), DRILL_PARTS)})
	if _parts_picked.size() >= DRILL_PARTS:
		_complete_once(&"drill_delivery")


## The burn-through (doc §Loud 4, QC-61): the lid drops (hidden, no collision), the rope ladder takes its meta
## `burn_height_m` (lead: stowed at 3.2 m, 4.0 m to the vault floor) and becomes usable, the rope ladder and the hoist
## switch on (GameplayPrefab.set_enabled, replicated), the police rappel down the hole opens, and the
## vault is reachable. D-136.9: nothing here ever disables the hoist again.
func burn_through() -> void:
	if burned_through:
		return
	burned_through = true
	_drop_lid()
	for l: Ladder in rope_ladders():
		if l.has_meta(META_BURN_HEIGHT):  # stowed short on purpose (C); the burn drops it to the vault floor
			l.height_m = float(l.get_meta(META_BURN_HEIGHT))
		l.usable = true
	for p: GameplayPrefab in _burn_prefabs():
		p.set_enabled(true)
	if _runtime != null and _runtime.map != null:
		if RappelLinks.set_enabled(_runtime.map, TAG_HOLE_RAPPEL, true) == 0:
			Log.warn(&"mission", "burn-through: no %s RAPPEL link to enable" % TAG_HOLE_RAPPEL)
	_complete_once(&"drill_delivery")
	_complete_once(&"vault_drill")
	_complete_once(&"vault_breach")
	say(VO_BURN_THROUGH)
	_vault_reachable()


## The lid: prefabs tagged `lid` are switched off (replicated); C's G1 lid slab (meta burn_lid) is hidden and loses its
## collision (server-side only: ask C for a replicated prefab).
func _drop_lid() -> void:
	var lids: Array[Node] = []
	for n: Node in find_tagged(TAG_LID):
		if n is GameplayPrefab:
			(n as GameplayPrefab).set_enabled(false)
			lids.append(n)
	if _runtime == null or _runtime.map == null:
		return
	for n: Node in _runtime.map.find_children("*", "", true, false):
		if not n.has_meta(META_BURN_LID) or lids.has(n):  # a prefab lid (C fcc83280, meta kept) is off above, replicated
			continue
		if n is Node3D:
			(n as Node3D).visible = false
		if n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer = 0
		for s: Node in n.find_children("*", "CollisionShape3D", true, false):
			(s as CollisionShape3D).set_deferred(&"disabled", true)


# --- Helpers -------------------------------------------------------------------------------------

## D-117: say `line_id` the first time only (per heist). Returns true when it was said.
func _say_once(line_id: StringName, context: Dictionary = {}, speaker: StringName = SPEAKER_MERCER) -> bool:
	if _said.has(line_id):
		return false
	_said[line_id] = true
	say(line_id, context, speaker)
	return true


func _complete_once(id: StringName) -> void:
	if objective_state(id) != Enums.ObjectiveState.COMPLETED:
		complete(id)


func _set_interactable(n: Node, on: bool) -> void:
	var it: Node = n.get_node_or_null(^"Interactable")
	if it != null:
		it.set(&"enabled", on)


func _scalar(id: StringName, fallback: Variant) -> Variant:
	var v: Variant = variant(id)
	return fallback if v == null else v


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
