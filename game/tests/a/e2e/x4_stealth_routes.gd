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
class_name X4StealthRoutes
extends RefCounted

const KEYCARD: StringName = &"item.keycard"
const ND_BAGS: int = 4
const SL_DRIVES: int = 2
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
	return f.check(gate.is_open, "the vault gate is open")


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
	var cage: Safe = f.tagged(&"cage") as Safe
	if not f.check(cage != null and cage.method_for(f.crew) == &"code", "the cage offers the code"):
		return false
	return await f.take(cage, _done(&"cage"), _tw().keypad_s, "open the cage with the code")


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
	f.note("the only keycard is on the curator (%s, %s): intimidate + tie her" % [npc.name, f.rt.mission.variant(&"curator_route")])
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
