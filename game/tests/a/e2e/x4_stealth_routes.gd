## X-4 stealth routes, one list of steps per heist, played by X4StealthFlow (x4_stealth_flow.gd: the harness and its
## stated shortcuts). Each step drives the crew through real interactions and returns false (after a flow.check
## failure) to stop the route. Owner: ENV A (test support).
##   night_deposit (night_deposit_mission.gd "Stealth"): keycard -> time-lock code (the code note; code_on_manager:
##     the server hack instead) -> vault gate (keycard) -> past the antechamber lasers (their pattern's way) ->
##     time-lock panel (code) -> the time lock runs out, the vault opens -> 4 bags of the cage / Co-op cash, each out
##     past the lasers to the rolled escape's secure zone -> escape.
##   shadow_ledger (STEALTH_ONLY): keycard (unless srv_contractor) -> the ledger laptop, secured (lap_study: past the
##     M3 lasers) -> the cage code note -> server door (keycard reader) -> cage (code) -> the hack, every interruption
##     restarted -> 2 drive bags, secured -> escape (heli approach / line / lift).
##   gallery_night: the Argus hack first when a canvas we cut has a live frame sensor (code note -> server keypad ->
##     hack) -> the centrepiece's barrier (cp_store: keycard + art store vault reader; cp_treasury: keycard + Treasury
##     reader + lasers; the keycard: one lying in the map, else kc_curator's on Sorell's lanyard: shout her down,
##     cable-tie her, take the card off her) -> cut the Lantern Bearer and one listed canvas, each secured at the rolled escape -> escape.
##   ostrander_federal (the ghost line, doc §Stealth routes): the vault keycard (lying in the map, else on Ashgrove:
##     shout him down, cable-tie him, take it) -> the vault code: the right officer's PC hack (the planner first when it
##     is interactable) -> the vault gate (keycard) -> past the VC grid (its pattern's way) -> the code at the time-lock
##     console -> the time lock runs out, the vault opens -> the cash cage (the code at its keypad) -> 4 (Routine) cash
##     bags, each out past the grid to the rolled escape's secure zone -> escape. With the vault-control rack in the
##     basement (srv_basement) the route takes the other line instead: the gate, the laser controller (grid off,
##     [lasers]) and the rack hack (it starts the time lock), then the cash cage's padlock (no code).
class_name X4StealthRoutes
extends RefCounted

const KEYCARD: StringName = &"item.keycard"
const ND_BAGS: int = 4
const SL_DRIVES: int = 2
## Afterhours: the required bags and the safe's loot id (AfterhoursMission.REQUIRED_BAGS / LOOT_SAFE).
const AH_BAGS: int = 3
const AH_SAFE_LOOT: StringName = &"loot.cash_bricks"
const DONE: Enums.ObjectiveState = Enums.ObjectiveState.COMPLETED

var f: X4StealthFlow = null
var _gn_lantern: LootSpawn = null
var _gn_listed: LootSpawn = null


func _init(flow: X4StealthFlow) -> void:
	f = flow


## Play `flow.heist`'s route. True when every step passed.
static func play(flow: X4StealthFlow) -> bool:
	var r: X4StealthRoutes = X4StealthRoutes.new(flow)
	var steps: Array[Callable] = r.steps_for(flow.heist)
	if not flow.check(not steps.is_empty(), "a stealth route for %s" % flow.heist):
		return false
	for s: Callable in steps:
		if not await s.call():
			return false
	return true


func steps_for(heist: StringName) -> Array[Callable]:
	match heist:
		&"night_deposit":
			return [_start, _nd_keycard, _nd_code, _nd_gate, _nd_time_lock, _nd_vault_opens, _nd_bags, _nd_escape]
		&"shadow_ledger":
			return [_start, _sl_keycard, _sl_laptop, _sl_cage_code, _sl_server_door, _sl_cage, _sl_hack, _sl_drives,
				_sl_escape]
		&"gallery_night":
			return [_start, _gn_pick, _gn_sensors, _gn_barrier, _gn_canvases, _gn_escape]
		&"afterhours":
			return [_ah_start, _ah_keycard, _ah_office, _ah_code, _ah_safe, _ah_bags, _ah_escape]
		&"ostrander_federal":
			return [_start, _of_keycard, _of_code, _of_gate, _of_rack, _of_time_lock, _of_vault_opens, _of_cage, _of_bags,
				_of_escape]
	return []


# --- Shared ------------------------------------------------------------------------------------------

func _start() -> bool:
	f.hide_from_observers()
	return await f.mask_up()


func _done(id: StringName) -> Callable:
	return func() -> bool: return f.objective(id) == DONE


func _has_card() -> Callable:
	return func() -> bool: return f.crew.item_count(KEYCARD) > 0


func _tw() -> InteractionTweak:
	return Tweak.interaction()


# --- Nightfall Depository ------------------------------------------------------------------------------

func _nd_keycard() -> bool:
	return await f.take(f.tagged(&"keycard"), _has_card(), _tw().item_pickup_s, "take the keycard")


func _nd_code() -> bool:
	var n: Node3D = f.tagged(&"code_note")
	if n == null:
		f.note("code_on_manager: no code note, the server hack starts the time lock")
		return true
	return await f.take(n, _done(&"code"), _tw().read_note_s, "read the time-lock code")


func _nd_gate() -> bool:
	var gate: Door = f.tagged(&"vault_gate") as Door
	var panel: Node3D = f.tagged(&"time_lock")
	if not f.check(gate != null and panel != null, "vault gate and time-lock panel"):
		return false
	# The gate's corridor side: away from the vault (the panel is on the vault side).
	if not await f.go_to(gate, null, gate.global_position * 2.0 - panel.global_position):
		return false
	if not await f.use(gate, _done(&"vault_gate"), _tw().keycard_s + X4StealthFlow.MARGIN_S, "swipe the vault gate"):
		return false
	f.guard_lasers(&"antechamber_lasers", panel.global_position)
	# P's ghost-line loops: the vault guard's (b) / (c) loops walk out through this gate (he may open or shut it), so the
	# swipe's job is the unlock; the next leg passes the gate either way.
	return f.check(gate.is_open or not gate.locked, "the vault gate is unlocked (open %s)" % gate.is_open)


func _nd_time_lock() -> bool:
	if f.tagged(&"code_note") != null:
		return await f.take(f.tagged(&"time_lock"), _done(&"time_lock"), _tw().keypad_s, "enter the time-lock code")
	var ht: HackTerminal = f.tagged(&"server_hack") as HackTerminal
	if not f.check(ht != null, "ND server hack terminal") or not await f.run_hack(ht):
		return false
	return f.check(f.objective(&"server") == DONE and f.objective(&"time_lock") == DONE, "the hack started the time lock")


func _nd_vault_opens() -> bool:
	var v: Variant = f.rt.mission.variant(&"time_lock_s")
	var lock_s: float = float(v) if v != null else 90.0
	if not f.check(await f.fast_until(_done(&"time_lock_wait"), lock_s + 15.0), "the time lock runs out (%.0f s)" % lock_s):
		return false
	var vault: Door = f.tagged(&"vault_door") as Door
	return f.check(vault != null and vault.is_open, "the vault door is open")


func _nd_bags() -> bool:
	var zone: Area3D = f.secure_zone(&"loot_secure")
	if not f.check(zone != null, "the rolled escape's secure zone"):
		return false
	for taken: int in range(ND_BAGS):
		var src: LootSpawn = null
		for s: Node in f.all_tagged(&"vault_loot"):  # the fuller of the cage and the Co-op pallet
			var ls: LootSpawn = s as LootSpawn
			if ls != null and ls.remaining > 0 and (src == null or ls.remaining > src.remaining):
				src = ls
		if not f.check(src != null, "vault loot left to bag (%d taken)" % taken):
			return false
		if not await f.bag_and_secure(src, zone):
			return false
	return f.check(f.objective(&"secure") == DONE, "secure objective done")


func _nd_escape() -> bool:
	var tag: StringName = &"escape_boat" if f.slot(&"escape", &"esc_boat_quay") else &"escape_van"
	return await f.escape(f.tagged(tag) as EscapeZone)


# --- Shadow Ledger -------------------------------------------------------------------------------------

func _sl_laptop_spawn() -> LootSpawn:
	return f.tagged(&"laptop") as LootSpawn


func _sl_keycard() -> bool:
	if f.objective(&"keycard") == DONE:  # srv_contractor: the server door is propped
		return true
	var laptop: LootSpawn = _sl_laptop_spawn()
	var card: Node3D = null
	for k: Node in f.all_tagged(&"keycard"):  # the card nearest the laptop
		var n3: Node3D = k as Node3D
		if card == null or (laptop != null and n3.global_position.distance_to(laptop.global_position)
				< card.global_position.distance_to(laptop.global_position)):
			card = n3
	return await f.take(card, _has_card(), _tw().item_pickup_s + _tw().carried_item_s, "take the keycard")


func _sl_laptop() -> bool:
	var laptop: LootSpawn = _sl_laptop_spawn()
	if not f.check(laptop != null, "the ledger laptop"):
		return false
	if f.slot(&"laptop", &"lap_study"):
		f.guard_lasers(&"art_hall_lasers", laptop.global_position)  # M4, the study behind the M3 grid
	if not await f.bag_and_secure(laptop, f.secure_zone(&"loot_secure")):
		return false
	return f.check(f.objective(&"laptop") == DONE, "laptop objective done")


func _sl_cage_code() -> bool:
	if f.objective(&"cage") == DONE:  # cage_left_open
		return true
	return await f.take(f.tagged(&"cage_code"), _done(&"cage_code"), _tw().read_note_s, "read the cage code")


func _sl_server_door() -> bool:
	if f.objective(&"server_door") == DONE:
		return true
	return await f.take(f.tagged(&"server_reader"), _done(&"server_door"), _tw().keycard_s, "swipe the server door")


func _sl_cage() -> bool:
	if f.objective(&"cage") == DONE:
		return true
	var kp: Keypad = _sl_cage_keypad()
	if kp != null:  # D-138.4: the code goes in on the CageGate's CageKeypad
		if not f.check(kp.interactable.availability(f.crew) == InteractableComponent.BLOCK_NONE,
				"the cage keypad takes the code"):
			return false
		return await f.take(kp, _done(&"cage"), _tw().keypad_s, "open the cage with the code")
	# legacy: pre-D-138 maps, remove after C b4ad9153 is on trunk (the CageLock stand-in safe)
	var cage: Safe = f.tagged(&"cage") as Safe
	if not f.check(cage != null and cage.method_for(f.crew) == &"code", "the cage offers the code"):
		return false
	return await f.take(cage, _done(&"cage"), _tw().keypad_s, "open the cage with the code")


## D-138.4: the CageKeypad among the cage locks (null on a pre-D-138 map).
func _sl_cage_keypad() -> Keypad:
	for n: Node in f.all_tagged(&"cage"):
		if n is Keypad:
			return n as Keypad
	return null


func _sl_hack() -> bool:
	var ht: HackTerminal = f.tagged(&"hack") as HackTerminal
	if not f.check(ht != null, "the server hack terminal") or not await f.run_hack(ht):
		return false
	return f.check(f.objective(&"hack") == DONE, "hack objective done")


func _sl_drives() -> bool:
	var drives: int = 0
	for d: Node in f.all_tagged(&"drives"):
		var ls: LootSpawn = d as LootSpawn
		while ls != null and ls.remaining > 0 and drives < SL_DRIVES:
			if not await f.bag_and_secure(ls, f.secure_zone(&"loot_secure")):
				return false
			drives += 1
	return f.check(drives == SL_DRIVES and f.objective(&"drives") == DONE, "%d drive bags secured" % SL_DRIVES)


func _sl_escape() -> bool:
	var esc: EscapeZone = null
	for tag: StringName in [&"escape_heli", &"escape_line", &"escape_service"]:
		var z: EscapeZone = f.tagged(tag) as EscapeZone
		if z != null and z.active:
			esc = z
	return await f.escape(esc)


# --- Gallery Night -------------------------------------------------------------------------------------

func _gn_escape_name() -> String:
	return "parade" if f.slot(&"escape", &"esc_parade") else "mews"


## The Lantern Bearer and the listed canvas to cut: one whose frame sensor is offline when there is one.
func _gn_pick() -> bool:
	_gn_lantern = f.tagged(&"canvas_lantern") as LootSpawn
	for tag: StringName in [&"canvas_widow", &"canvas_orchard", &"canvas_saint"]:
		var c: LootSpawn = f.tagged(tag) as LootSpawn
		if c != null and (_gn_listed == null or (_sensor_live(_gn_listed) and not _sensor_live(c))):
			_gn_listed = c
	return f.check(_gn_lantern != null and _gn_listed != null, "the Lantern Bearer and a listed canvas")


func _sensor_live(ls: LootSpawn) -> bool:
	return ls.alarm_on_take and AlarmGroups.is_live(f.rt, ls.alarm_group)


## A live frame sensor on a canvas we cut: the Argus hack takes them offline (code note -> server keypad -> hack).
func _gn_sensors() -> bool:
	if not _sensor_live(_gn_lantern) and not _sensor_live(_gn_listed):
		return true
	if not await f.take(f.tagged(&"code_note"), _done(&"server_code"), _tw().read_note_s, "read the server code"):
		return false
	var keypad: Node3D = f.tagged(&"server_keypad")
	if keypad != null:
		var it: InteractableComponent = keypad.get_node_or_null(^"Interactable") as InteractableComponent
		await f.take(keypad, func() -> bool: return it == null or not it.enabled, _tw().keypad_s, "enter the server code")
	var ht: HackTerminal = f.tagged(&"hack") as HackTerminal
	if not f.check(ht != null, "the Argus terminal") or not await f.run_hack(ht):
		return false
	return f.check(not _sensor_live(_gn_lantern) and not _sensor_live(_gn_listed), "the frame sensors are offline")


func _gn_keycard() -> Node3D:
	for k: Node in f.all_tagged(&"keycard"):
		var kp: KeycardPickup = k as KeycardPickup
		if kp != null and kp.is_inside_tree() and kp.interactable != null and kp.interactable.enabled:
			return kp
	return null


## A keycard for the barrier: one lying in the map when there is one, else the one the curator carries (QC-52).
func _gn_get_card() -> bool:
	var card: Node3D = _gn_keycard()
	if card == null and _gn_carried_card() != null:
		return await _gn_curator_card(_gn_carried_card())
	return await f.take(card, _has_card(), _tw().item_pickup_s, "take the keycard")


## kc_curator's card while Sorell still has it on her lanyard (not released, not taken).
func _gn_carried_card() -> KeycardPickup:
	for k: Node in f.all_tagged(&"keycard"):
		var kp: KeycardPickup = k as KeycardPickup
		if kp != null and kp.carrier_tag != &"" and not kp.released and not kp.taken:
			return kp
	return null


## QC-52, PD2: shout the curator down (S7.1 intimidate, CrewIntent.shout through the ShoutSystem), cable-tie her
## (S7.2, her TieInteractable through the InteractionSystem), then take the card that shows on her (carried_item_s).
## stealth_hidden does not stop any of it: it only hides the bot from observers; shouts and ties are crew actions.
func _gn_curator_card(card: KeycardPickup) -> bool:
	var npc: NpcBase = Ids.lookup(card.carrier_id) as NpcBase if card.carrier_id != 0 else null
	if not f.check(npc != null and npc.alive, "the curator carrying %s" % card.name):
		return false
	var brain: CivilianBrain = npc.get_node_or_null(^"Brain") as CivilianBrain
	if not f.check(brain != null, "the curator's CivilianBrain"):
		return false
	f.facts[&"curator_net_id"] = npc.net_id
	f.facts[&"curator_card_carrier"] = card.carrier_id
	f.facts[&"curator_card_released_before_shout"] = card.released
	var on_take: Callable = func(by: Node) -> void:
		f.facts[&"curator_card_taken_by_slot"] = int(by.get(&"slot"))
		f.facts[&"curator_card_tied_at_take"] = brain.is_tied()
	card.interactable.completed.connect(on_take, CONNECT_ONE_SHOT)
	var route: Variant = f.rt.mission.variant(&"curator_route")
	if route == null:
		route = f.rt.mission.variant(&"manager_route")  # OF: Ashgrove carries kc_on_manager
	f.note("the only keycard is on the curator (%s, %s): intimidate + tie her" % [npc.name, route])
	await _catch_alone(npc)
	if not await f.go_to(npc) or not await _shout_down(brain):
		return false
	f.note("card released once she is down: %s" % card.released)
	if not await f.use(npc, func() -> bool: return brain.is_tied(),
			Tweak.stealth().cable_tie_s + X4StealthFlow.MARGIN_S, "cable-tie the curator"):
		return false
	f.facts[&"curator_tied"] = true
	if not f.check(await f.wait_until(func() -> bool: return card.released, 2.0), "the curator's card shows on her"):
		return false
	return await f.take(card, _has_card(), _tw().carried_item_s, "take the curator's keycard")


## OF-A4: a carrier on a CivilianRoute with an away window (OF's manager: mgr_away at the BM office with the door shut,
## CF / PR upstairs, the LK WC on mgr_vault) is caught alone: wait (fast) until his window is open AND he stands at the
## away stop (CivilianBrain opens the window when he LEAVES for that stop, so open alone can still be mid-walk past a
## camera), then go. A route without a window, or one he does not reach within one lap, goes as it is (noted).
func _catch_alone(npc: NpcBase) -> void:
	var route: CivilianRoute = CivilianRoute.for_civilian(f.rt, npc)
	if route == null:
		return
	var away_stops: Array[Vector3] = []
	var bound_s: float = 30.0
	for i: int in range(route.stop_count()):
		if route.window_of(i) != &"":
			away_stops.append(route.stop_at(i).global_position)
		bound_s += route.stop_at(i).pause_range.y + 30.0  # every dwell + a walk per stop: one lap
	if away_stops.is_empty():
		return
	var at_away_stop: Callable = func() -> bool:
		if not route.is_away() or not is_instance_valid(npc):
			return false
		for p: Vector3 in away_stops:
			if npc.global_position.distance_to(p) < 1.5:
				return true
		return false
	var away: bool = await f.fast_until(at_away_stop, bound_s)
	f.facts[&"carrier_caught_away"] = away
	f.note("%s on route %s: %s (%s)" % [npc.name, route.id(),
		"at his %s stop" % route.away_window() if away else "never at an away stop", npc.global_position])


## Shout at the civilian `brain` (CrewIntent.shout held a few frames looking at her chest, then released; the
## ShoutSystem decides who it reaches) until she is down (S7.1), a few tries one shout cooldown apart.
func _shout_down(brain: CivilianBrain) -> bool:
	var shouts: int = 0
	while not brain.is_down() and shouts < 4:
		shouts += 1
		var i: CrewIntent = BotUtil.look_at_intent(f.crew.eye_position(), brain.shout_target_point())
		i.shout = true
		for _pass: int in range(2):  # held, then released (the shout fires on the rising edge)
			f.rt.set_bot_intent(0, i)
			await f.wait_until(func() -> bool: return false, 0.05)
			i = BotUtil.look_at_intent(f.crew.eye_position(), brain.shout_target_point())
		await f.wait_until(func() -> bool: return brain.is_down(), Tweak.stealth().shout_cooldown_s + 0.2)
	f.facts[&"curator_shouts"] = shouts
	return f.check(brain.is_down(), "the curator is shouted down (%d shout(s))" % shouts)


## The centrepiece's barrier: the art store vault (cp_store) or the Treasury door + lasers (cp_treasury); the landing
## (cp_landing) is open during the gala (its curtain is on from last call only).
func _gn_barrier() -> bool:
	var reader_tag: StringName = &""
	var objective_id: StringName = &""
	if f.slot(&"centrepiece", &"cp_store"):
		reader_tag = &"vault_reader"
		objective_id = &"art_store"
	elif f.slot(&"centrepiece", &"cp_treasury"):
		reader_tag = &"treasury_door"
		objective_id = &"treasury"
	f.guard_lasers(&"treasury_lasers" if objective_id == &"treasury" else &"landing_curtain", _gn_lantern.global_position)
	if reader_tag == &"":
		return true
	if not await _gn_get_card():
		return false
	return await f.take(f.tagged(reader_tag), _done(objective_id), _tw().keycard_s, "swipe the %s reader" % reader_tag)


func _gn_canvases() -> bool:
	var zone: Area3D = f.secure_zone(StringName("secure_%s" % _gn_escape_name()))
	if not f.check(zone != null, "the %s secure zone" % _gn_escape_name()):
		return false
	for c: LootSpawn in [_gn_lantern, _gn_listed]:
		if not await f.bag_and_secure(c, zone):
			return false
	return f.check(f.objective(&"centrepiece") == DONE and f.objective(&"canvases") == DONE
		and f.objective(&"secure") == DONE, "centrepiece, canvases and secure objectives done")


func _gn_escape() -> bool:
	return await f.escape(f.tagged(StringName("escape_%s" % _gn_escape_name())) as EscapeZone)


# --- Ostrander Federal ---------------------------------------------------------------------------------

## The rack line (see the header): the vault-control rack is in the basement next to the vault.
func _of_rack_line() -> bool:
	return f.slot(&"server_room", &"srv_basement")


## The guarded room behind the VC grid (x 21): the concourse east of it and the vault (basement, south of the gate).
func _of_behind_grid(p: Vector3) -> bool:
	return p.y < -2.0 and p.x > 21.0 and p.z > 9.0


## The card lying in the map, else Ashgrove's (kc_on_manager: shout him down, tie him, take it; QC-52 / QC-62).
func _of_keycard() -> bool:
	f.note("keycard slot %s, manager %s" % [f.rt.mission.variant(&"keycard"), f.rt.mission.variant(&"manager_route")])
	return await _gn_get_card()


## The vault code off the right officer's PC (45 s, 1 interruption; QC-63 reveals code group `vault`); the planner first
## when the map has an interactable one. The rack line skips this (the rack starts the time lock itself).
func _of_code() -> bool:
	if _of_rack_line():
		return true
	var planner: Node3D = f.tagged(&"code_hint")
	if planner != null and planner.get_node_or_null(^"Interactable") != null:
		if not await f.take(planner, _done(&"code_hint"), _tw().read_note_s, "read Ashgrove's planner"):
			return false
	else:
		f.note("map: [code_hint] is a bare marker (no interactable planner): the route goes to the rolled PC")
	var pc: HackTerminal = f.tagged(&"code_pc") as HackTerminal
	if not f.check(pc != null, "the rolled code PC") or not await f.run_hack(pc):
		return false
	return f.check(f.objective(&"code_pc") == DONE, "code_pc objective done")


func _of_gate() -> bool:
	var reader: Node3D = null
	var gate: Door = null
	for n: Node in f.all_tagged(&"vault_gate"):
		if n is KeycardReader:
			reader = n as Node3D
		elif n is Door:
			gate = n as Door
	if not f.check(reader != null and gate != null, "vault gate and its reader"):
		return false
	if not await f.take(reader, _done(&"vault_gate"), _tw().keycard_s, "swipe the vault gate"):
		return false
	var console: Node3D = f.tagged(&"time_lock")
	f.guard_lasers(&"laser_grid", console.global_position, _of_behind_grid)
	# P's ghost-line loops: the vault guard's (b) / (c) loops walk out through this gate (he may open or shut it), so the
	# swipe's job is the unlock; the next leg passes the gate either way.
	return f.check(gate.is_open or not gate.locked, "the vault gate is unlocked (open %s)" % gate.is_open)


## The rack line: the laser controller (20 s, grid off, [lasers]) and the vault-control rack (90 s, 2 interruptions:
## it starts the time lock).
func _of_rack() -> bool:
	if not _of_rack_line():
		return true
	var lc: HackTerminal = f.tagged(&"lasers") as HackTerminal
	if not f.check(lc != null, "the laser controller") or not await f.run_hack(lc):
		return false
	for n: Node in f.all_tagged(&"laser_grid"):
		if not f.check(not (n as LaserGrid).active, "%s is off" % n.name):
			return false
	var rack: HackTerminal = f.tagged(&"server") as HackTerminal
	if not f.check(rack != null, "the vault-control rack") or not await f.run_hack(rack):
		return false
	return f.check(f.objective(&"server") == DONE and f.objective(&"time_lock") == DONE, "the rack started the time lock")


func _of_time_lock() -> bool:
	if f.objective(&"time_lock") == DONE:
		return true
	return await f.take(f.tagged(&"time_lock"), _done(&"time_lock"), _tw().keypad_s, "enter the code at the time lock")


func _of_vault_opens() -> bool:
	var v: Variant = f.rt.mission.variant(&"time_lock_s")
	var lock_s: float = float(v) if v != null else 210.0
	if not f.check(await f.fast_until(_done(&"time_lock_wait"), lock_s + 15.0), "the time lock runs out (%.0f s)" % lock_s):
		return false
	var vault: Door = f.tagged(&"vault_door") as Door
	return f.check(vault != null and vault.is_open, "the vault door is open")


## The cash cage: the code at its keypad (code known), else its padlock (lockpick).
func _of_cage() -> bool:
	var gate: Door = null
	var keypad: Node3D = null
	var padlock: Node3D = null
	for n: Node in f.all_tagged(&"cash_cage"):
		if n is Door:
			gate = n as Door
		elif n is Keypad:
			keypad = n as Node3D
		elif n is Padlock:
			padlock = n as Node3D
	if not f.check(gate != null, "the cash cage gate"):
		return false
	if gate.is_open:
		return true
	var opened: Callable = func() -> bool: return gate.is_open
	if f.objective(&"code_pc") == DONE and not _of_rack_line() and keypad != null:
		return await f.take(keypad, opened, _tw().keypad_s, "open the cash cage with the code")
	if not f.check(padlock != null, "the cash cage padlock"):
		return false
	var it: InteractableComponent = padlock.get_node_or_null(^"Interactable") as InteractableComponent
	var t: float = it.interaction_time_s if it != null else 8.0
	return await f.take(padlock, opened, t, "pick the cash cage padlock")


func _of_bags() -> bool:
	var zone: Area3D = f.secure_zone(&"secure")
	var cash: LootSpawn = f.tagged(&"vault_loot") as LootSpawn
	if not f.check(zone != null and cash != null, "the rolled escape's secure zone and the vault cash"):
		return false
	var need: int = int(f.rt.mission.call(&"required_bags"))
	for taken: int in range(need):
		if not f.check(cash.remaining > 0, "vault cash left to bag (%d taken)" % taken):
			return false
		if not await f.bag_and_secure(cash, zone):
			return false
	return f.check(f.objective(&"secure") == DONE, "secure objective done (%d bags)" % need)


func _of_escape() -> bool:
	return await f.escape(f.tagged(&"escape") as EscapeZone)


# --- Afterhours ------------------------------------------------------------------------------------------

## Civilian start (D-065): the rolled gear_drop bag first (only a civilian may use it), then the mask.
func _ah_start() -> bool:
	f.hide_from_observers()
	f.note("gear_drop %s, keycard %s, code_note %s" % [f.rt.mission.variant(&"gear_drop"),
		f.rt.mission.variant(&"keycard"), f.rt.mission.variant(&"code_note")])
	if f.crew.civilian:
		var gear: GearPickup = null
		for n: Node in f.all_tagged(&"gear"):
			var g: GearPickup = n as GearPickup
			if g != null and g.is_enabled() and g.interactable != null and g.interactable.enabled:
				gear = g
				break
		if not f.check(gear != null, "the rolled gear bag") or not await f.take(gear,
				func() -> bool: return not f.crew.civilian, _tw().item_pickup_s, "take the gear at %s" % gear.name):
			return false
		f.check(f.objective(&"gear") == DONE, "[gear] done")
	return await f.mask_up()


func _ah_keycard() -> bool:
	return await f.take(f.tagged(&"keycard"), _has_card(), _tw().item_pickup_s, "take the keycard")


func _ah_office() -> bool:
	return await f.take(f.tagged(&"office_reader"), _done(&"office"), _tw().keycard_s, "swipe the office reader")


## The safe code off the rolled note (optional: the drill opens the safe without it).
func _ah_code() -> bool:
	var note: Node3D = f.tagged(&"safe_code")
	if note == null or f.rt.mission.get(&"safe_open"):
		f.note("no code note (or the safe is left open): the drill / nothing")
		return true
	return await f.take(note, _done(&"safe_code"), _tw().read_note_s, "read the safe code")


## The code at the safe when read, else the drill (fixing its jams) until the safe opens.
func _ah_safe() -> bool:
	if f.rt.mission.get(&"safe_open"):
		return f.check(true, "the safe was left open")
	var safe: Node3D = f.tagged(&"safe")
	if f.objective(&"safe_code") == DONE:
		return await f.take(safe, _done(&"safe"), _tw().keypad_s, "open the safe with the code")
	var drill: DrillPoint = f.tagged(&"safe_drill") as DrillPoint
	if not f.check(drill != null, "the safe drill") or not await f.take(drill,
			func() -> bool: return drill.runner != null and drill.runner.state != DeviceRunner.State.IDLE,
			_tw().drill_place_s, "place the safe drill"):
		return false
	var t0: float = f.rt.heist_time_s
	var budget: float = drill.runner.duration * 2.0 + 60.0
	while f.objective(&"safe") != DONE and f.rt.heist_time_s - t0 < budget:
		await f.fast_until(func() -> bool: return f.objective(&"safe") == DONE \
			or drill.runner.state == DeviceRunner.State.JAMMED, budget)
		if drill.runner.state == DeviceRunner.State.JAMMED and not await f.use(drill,
				func() -> bool: return drill.runner.state != DeviceRunner.State.JAMMED, _tw().drill_fix_s + 2.0,
				"fix the safe drill"):
			return false
	return f.check(f.objective(&"safe") == DONE, "the drill opened the safe")


## The safe's cash bricks (loose bags at the safe_loot markers), carried to the rolled van's secure zone.
func _ah_bags() -> bool:
	var zone: Area3D = f.secure_zone(&"loot_secure")
	if not f.check(zone != null, "the rolled van's secure zone"):
		return false
	var need: int = AH_BAGS
	var safe: GameplayPrefab = f.tagged(&"safe") as GameplayPrefab
	for taken: int in range(need):
		var bag: LootBag = null
		for n: Node in f.host.get_tree().get_nodes_in_group(G.LOOT_BAG):
			var b: LootBag = n as LootBag
			if b != null and b.loot_id == AH_SAFE_LOOT and not b.secured and not b.is_carried():
				bag = b
				break
		if not f.check(bag != null, "safe cash left to carry (%d taken)" % taken):
			return false
		# The bags stack 0.4 m apart at the one safe_loot marker: the upper ones are reached from the safe's front.
		var near: Variant = null
		if f._stand_spot(bag) == null and safe != null and safe.use_point != null:
			near = safe.use_point.global_position
			f.note("%s at %s: no floor spot under it, taken from the safe's UsePoint" % [bag.name, bag.global_position])
		if not await f.go_to(bag, near) or not await f.use(bag, func() -> bool: return f.crew.is_carrying_bag(),
				_tw().bag_loot_s + X4StealthFlow.MARGIN_S, "pick up %s" % bag.name) or not await f._secure_carried(zone):
			return false
	return f.check(f.objective(&"secure") == DONE, "[secure] done (%d bags)" % need)


func _ah_escape() -> bool:
	return await f.escape(f.tagged(&"escape_van") as EscapeZone)

