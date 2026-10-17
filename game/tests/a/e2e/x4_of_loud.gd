## X-4 / OF-A6: the Ostrander Federal loud line end-to-end (doc §Loud, §Objectives "Loud"), played by the X4StealthFlow
## harness (x4_stealth_flow.gd: its crew actions, travel shortcut and fast waits) through the real mission. Owner: ENV A
## (test support). One bot crew member (slot 0) does every objective, with 3 AI teammates (solo with bots, L6.1: they
## follow, fight and revive; every objective action is the bot's): masks up -> the alarm -> LOCKDOWN (the gate BARRED, the
## vault door sealed) -> waits for the thermal drill (2 tool bags at the rolled drop, drill_eta_s) -> carries both to the
## lid and places them (DrillPoint requires_count 2: the second starts the 360 s burn) -> fixes every jam -> the
## burn-through (the lid gone, the rope ladder and the hoist on) -> down into the vault -> the cash cage padlock -> per
## hoist trip 2 cash bags into the hoist car, sent up, carried from the teller line to the rolled escape's secure zone
## until [secure] (4 on Routine) -> the loud escape (escape_eta_s after [secure]) -> stands in the escape zone.
## Harness shortcuts on top of x4_stealth_flow.gd's (stated):
##   * the alarm is raised through the StealthDirector (StealthDirector.raise_alarm(&"x4_loud")): how the crew goes loud
##     is not what this flow tests;
##   * the rope ladder is travelled as a teleport (the flow checks it is usable first); bags never take it: every bag
##     comes up the hoist (S10.1b, doc §Loot path "the hoist cannot be bypassed");
##   * D-133: the run sets the harness-only dev option crew_damage_taken_mult 0.25 (HeistLauncher.dev_options, Routine,
##     assault events ON); the bot does not shoot back. Nothing else about the police is touched.
## Used by test_x4_of_loud.gd.
class_name X4OfLoud
extends RefCounted

const DONE: Enums.ObjectiveState = Enums.ObjectiveState.COMPLETED
const PART: StringName = &"loot.thermal_drill_part"
## D-133: the loud e2e gate's crew damage multiplier.
const CREW_DMG: float = 0.25
const HOIST_BAGS: int = 2
## Solo with the PD2 bots (L6.1): they hold the line, fight and revive the bot; they carry nothing for it.
const AI_TEAMMATES: int = 3

var f: X4StealthFlow = null
var downs: int = 0
var custody: int = 0
var jams_fixed: int = 0
var hoist_trips: int = 0
var drill: DrillPoint = null
var hoist: BagLift = null


func _init(flow: X4StealthFlow) -> void:
	f = flow


## Launch `seed_value` on Routine with the D-133 dev option (cleared again right after the launch).
static func launch(flow: X4StealthFlow, heist: StringName, seed_value: int) -> bool:
	HeistLauncher.dev_options["crew_damage_taken_mult"] = CREW_DMG
	flow.ai_teammates = AI_TEAMMATES
	var ok: bool = await flow.launch(heist, seed_value)
	HeistLauncher.dev_options.erase("crew_damage_taken_mult")
	if ok:
		flow.note("DEV OPTION crew_damage_taken_mult=%.2f (D-133 harness-only; assault events on)" % CREW_DMG)
	return ok


## Play the loud line. True when every step passed.
func play() -> bool:
	f._listen(EventBus.crew_downed, func(slot: int, _d: int) -> void:
		f.note("crew slot %d DOWNED" % slot)
		if slot == 0:
			downs += 1)
	f._listen(EventBus.crew_tased, func(slot: int, _by: int) -> void: f.note("crew slot %d TASED" % slot))
	f._listen(EventBus.crew_revived, func(slot: int, by: int) -> void: f.note("crew slot %d revived by %d" % [slot, by]))
	f._listen(EventBus.crew_custody, func(slot: int) -> void:
		f.note("crew slot %d in CUSTODY" % slot)
		if slot == 0:
			custody += 1)
	for s: Callable in [_start, _alarm, _drill_parts, _burn, _down_the_hole, _cage, _bags, _escape]:
		if not await s.call():
			return false
	return true


func _m() -> HeistMission:
	return f.rt.mission


func _tw() -> InteractionTweak:
	return Tweak.interaction()


func _start() -> bool:
	drill = f.tagged(&"vault_drill") as DrillPoint
	hoist = f.tagged(&"hoist") as BagLift
	if not f.check(drill != null and hoist != null, "the lid DrillPoint and the hoist"):
		return false
	if not f.check(not hoist.is_enabled(), "the hoist is not installed before the burn-through"):
		return false
	return await f.mask_up()


func _alarm() -> bool:
	f.rt.stealth.raise_alarm(&"x4_loud", 0)
	if not f.check(await f.wait_until(func() -> bool: return bool(_m().get(&"lockdown")), 2.0), "LOCKDOWN"):
		return false
	var vault: Door = f.tagged(&"vault_door") as Door
	if not f.check(vault != null and not vault.is_open and vault.locked, "the vault door stays sealed"):
		return false
	for n: Node in f.all_tagged(&"vault_gate"):
		if n is Door and not f.check((n as Door).lock == Door.Lock.BARRED, "the vault gate is BARRED"):
			return false
	f.note("lockdown; the drill comes to %s in %s s" % [_m().variant(&"drill_delivery"), _m().variant(&"drill_eta_s")])
	return f.check(f.objective(&"drill_delivery") == Enums.ObjectiveState.ACTIVE, "[drill_delivery] active")


## The 2 parts arrive at the drop drill_eta_s after the alarm; each is carried to the lid and placed (3 s each).
func _drill_parts() -> bool:
	var eta: float = float(_m().variant(&"drill_eta_s"))
	if not f.check(await f.fast_until(func() -> bool: return _parts().size() >= 2, eta + 10.0), "the drill parts arrive (%.0f s)" % eta):
		return false
	for i: int in range(2):
		var parts: Array[LootBag] = _parts()
		if not f.check(not parts.is_empty(), "a drill part to carry (%d placed)" % i):
			return false
		var bag: LootBag = parts[0]
		if not await _pick_up(bag, "pick up drill part %d" % (i + 1)):
			return false
		var placed: int = drill.delivered
		if not await f.go_to(drill):
			return false
		var done: Callable = func() -> bool: return drill.delivered > placed or drill.device_state() != DeviceRunner.State.IDLE
		if not await f.use(drill, done, _tw().drill_place_s + 1.0 + X4StealthFlow.MARGIN_S, "place drill part %d" % (i + 1)):
			return false
	f.note("drill delivered %d/%d, state %d" % [drill.delivered, drill.requires_count, drill.device_state()])
	return f.check(drill.device_state() == DeviceRunner.State.RUNNING and f.objective(&"drill_delivery") == DONE,
		"the thermal drill runs, [drill_delivery] done")


## Hold the teller line (stand at the drill) and fix every jam until the burn-through.
func _burn() -> bool:
	var budget: float = drill.effective_duration() * 2.0 + 60.0
	var t0: float = f.rt.heist_time_s
	while not bool(_m().get(&"burned_through")) and f.rt.heist_time_s - t0 < budget:
		await f.fast_until(func() -> bool:
			return bool(_m().get(&"burned_through")) or drill.device_state() == DeviceRunner.State.JAMMED, budget)
		if drill.device_state() == DeviceRunner.State.JAMMED:
			jams_fixed += 1
			if not await f.go_to(drill) or not await f.use(drill, func() -> bool:
					return drill.device_state() != DeviceRunner.State.JAMMED,
					_tw().drill_fix_s + X4StealthFlow.MARGIN_S, "fix the drill (jam #%d)" % jams_fixed):
				return false
		if not f.check(custody == 0, "the bot is not in custody"):
			return false
	if not f.check(bool(_m().get(&"burned_through")), "the burn-through (%d jams fixed)" % jams_fixed):
		return false
	return f.check(f.objective(&"vault_drill") == DONE and f.objective(&"vault_breach") == DONE and hoist.is_enabled(),
		"[vault_drill] + [vault_breach] done, the hoist installed")


## Down the rope ladder (usable after the burn) into the vault.
func _down_the_hole() -> bool:
	var ladders: Array = _m().call(&"rope_ladders")
	if not f.check(not ladders.is_empty() and (ladders[0] as Ladder).usable, "the rope ladder is usable"):
		return false
	return await _vault_floor()


## Teleport to the vault floor at the hoist (the rope ladder's foot, stated shortcut).
func _vault_floor() -> bool:
	return await f.go_to(hoist, hoist.landing_transform(0).origin)


## The cash cage: in loud the code is never known (the console is dead): its padlock. Loud, the Padlock offers its
## placed saw first (D-115 DB-8: saw_duration_s, PD2 jams), the lockpick last: place it, fix every jam, wait it out.
func _cage() -> bool:
	var gate: Door = null
	var padlock: Padlock = null
	for n: Node in f.all_tagged(&"cash_cage"):
		if n is Door:
			gate = n as Door
		elif n is Padlock:
			padlock = n as Padlock
	if not f.check(gate != null and padlock != null, "the cash cage gate and its padlock"):
		return false
	var budget: float = 180.0
	var t0: float = f.rt.heist_time_s
	var tries: int = 0
	while not padlock.opened and f.rt.heist_time_s - t0 < budget:
		var idle: bool = padlock.runner == null or padlock.runner.state == DeviceRunner.State.IDLE
		var jammed: bool = padlock.runner != null and padlock.runner.state == DeviceRunner.State.JAMMED
		if idle or jammed:
			tries += 1
			if tries > 8:
				break
			var what: String = "fix the padlock saw" if jammed else "work the cash cage padlock"
			var moved: Callable = func() -> bool:
				return padlock.opened or (padlock.runner != null and padlock.runner.state == DeviceRunner.State.RUNNING)
			if not await f.take(padlock, moved, _tw().lockpick_door_s, what):
				return false
		await f.fast_until(func() -> bool:
			return padlock.opened or (padlock.runner != null and padlock.runner.state != DeviceRunner.State.RUNNING),
			budget)
	f.note("cash cage padlock beaten by %s" % padlock.beaten_by)
	return f.check(padlock.opened and gate.is_open, "the cash cage is open")


## Cash up the hoist (2 per trip) and to the secure zone until [secure].
func _bags() -> bool:
	var zone: Area3D = f.secure_zone(&"secure")
	var cash: LootSpawn = f.tagged(&"vault_loot") as LootSpawn
	if not f.check(zone != null and cash != null, "the rolled escape's secure zone and the vault cash"):
		return false
	var need: int = int(_m().call(&"required_bags"))
	var secured: int = 0
	while secured < need:
		var n: int = await _hoist_trip(cash, zone, mini(HOIST_BAGS, need - secured))
		if n <= 0:
			return false
		secured += n
	return f.check(f.objective(&"secure") == DONE, "[secure] done (%d bags up the hoist in %d trips)" % [need, hoist_trips])


## One hoist trip: `n_load` cash bags up the hoist, each carried from the teller line to `zone`. Returns the bags
## secured (0 on a failure).
func _hoist_trip(cash: LootSpawn, zone: Area3D, n_load: int) -> int:
	if not await _load_hoist(cash, n_load) or not await _send_hoist():
		return 0
	var done: int = 0
	for bag: LootBag in hoist.bags_in_car():
		if not await _pick_up(bag, "take %s off the hoist" % bag.name):
			return 0
		if not await f._secure_carried(zone):
			return 0
		done += 1
	return done if f.check(done == n_load, "%d bags came up the hoist (%d sent)" % [done, n_load]) else 0


## Down to the vault (after the first trip), the car called down, `n_load` cash bags bagged into it.
func _load_hoist(cash: LootSpawn, n_load: int) -> bool:
	if hoist_trips > 0 and not await _vault_floor():
		return false
	if not await _call_hoist(0):
		return false
	for _i: int in range(n_load):
		if not f.check(cash.remaining > 0, "vault cash left to bag"):
			return false
		if not await f._bag_from(cash) or not await _into_hoist():
			return false
	return true


## Bring the hoist car to landing `i` (call it from there) when it is elsewhere.
func _call_hoist(i: int) -> bool:
	await f.wait_until(func() -> bool: return not hoist.is_moving(), 15.0)
	if _car_at(i):
		return true
	if not await f.go_to(hoist, hoist.landing_transform(i).origin):
		return false
	if not await f.use(hoist, func() -> bool: return hoist.is_moving(), _tw().bag_lift_send_s + X4StealthFlow.MARGIN_S,
			"call the hoist to landing %d" % i):
		return false
	return f.check(await f.fast_until(func() -> bool: return not hoist.is_moving() and _car_at(i), hoist.travel_s + 5.0),
		"the hoist car at landing %d" % i)


func _car_at(i: int) -> bool:
	return hoist.car_transform().origin.distance_to(hoist.car_transform_at(i).origin) < 0.1


## Drop the carried bag into the hoist car (a stand spot whose forward drop lands in the 1 m car); tries other spots.
func _into_hoist() -> bool:
	var tw: LootTweak = LootTweak.get_default()
	var center: Vector3 = hoist.car_transform().origin
	var n_before: int = hoist.bags_in_car().size()
	for deg: int in range(0, 360, 30):
		if not f.crew.is_carrying_bag():
			break
		var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg)))
		var p: Variant = BotUtil.nav_point_near(hoist, center - dir * tw.drop_forward_m, 0.25)
		if p == null:
			continue
		await f._move_to(p as Vector3, center)
		var d: CrewIntent = BotUtil.look_at_intent(f.crew.eye_position(), center + Vector3.UP * 0.3)
		d.drop_bag = true
		f.rt.set_bot_intent(0, d)
		await f._physics_frames(X4StealthFlow.RISE_FRAMES)
		f.rt.set_bot_intent(0, f._still())
		await f.wait_until(func() -> bool: return false, 0.6)
		if hoist.bags_in_car().size() > n_before:
			return true
		var loose: LootBag = _nearest_loose_bag(center)  # missed the car: pick it up again and try another spot
		if loose == null or not await f.use(loose, func() -> bool: return f.crew.is_carrying_bag(),
				_tw().bag_loot_s + X4StealthFlow.MARGIN_S, "pick the missed bag up again"):
			return false
	return f.check(hoist.bags_in_car().size() > n_before, "a bag dropped into the hoist car")


func _send_hoist() -> bool:
	if not await f.go_to(hoist, hoist.landing_transform(0).origin):
		return false
	if not await f.use(hoist, func() -> bool: return hoist.is_moving(), _tw().bag_lift_send_s + X4StealthFlow.MARGIN_S,
			"send the hoist up (%d bags)" % hoist.bags_in_car().size()):
		return false
	hoist_trips += 1
	# Up the rope ladder while the car travels (stated shortcut: a teleport to the teller line beside the hole).
	if not await f.go_to(hoist, hoist.landing_transform(1).origin):
		return false
	return f.check(await f.fast_until(func() -> bool: return not hoist.is_moving() and _car_at(1), hoist.travel_s + 5.0),
		"the hoist car up at the teller line")


## Walk up to `bag` and pick it up (interact held on it, released between tries); up to 3 tries from a fresh stand spot
## (in the fight a shove, a tase or a teammate in the way can cost a try). One check, on the last try.
func _pick_up(bag: LootBag, what: String) -> bool:
	for attempt: int in range(3):
		if not is_instance_valid(bag) or bag.is_carried():
			break
		if not await f.go_to(bag):
			return false
		var t: float = 0.0
		while t < _tw().bag_loot_s + X4StealthFlow.MARGIN_S and not f.crew.is_carrying_bag():
			var i: CrewIntent = BotUtil.look_at_intent(f.crew.eye_position(), bag.global_position)
			i.interact = t < _tw().bag_loot_s + 1.0 or f.rt.interaction.session(0).size() > 0
			i.interact_target_net_id = bag.net_id
			f.rt.set_bot_intent(0, i)
			await f._physics_frames(1)
			t += f.host.get_physics_process_delta_time()
		f.rt.set_bot_intent(0, f._still())
		await f._physics_frames(X4StealthFlow.RISE_FRAMES)
		if f.crew.is_carrying_bag():
			f.note("%s: done" % what)
			return true
		f.note("%s: try %d missed (crew at %s, bag at %s, state %d, blocked '%s')" % [what, attempt + 1,
			f.crew.global_position, bag.global_position, int(f.crew.crew_state), f.rt.interaction.blocked_reason(0)])
	return f.check(f.crew.is_carrying_bag(), what)


func _nearest_loose_bag(at: Vector3) -> LootBag:
	var best: LootBag = null
	for n: Node in f.host.get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b == null or b.is_carried() or b.secured or b.is_queued_for_deletion() or b.loot_id == PART:
			continue
		if best == null or b.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = b
	return best if best != null and best.global_position.distance_to(at) < 3.0 else null


func _parts() -> Array[LootBag]:
	var out: Array[LootBag] = []
	for n: Node in f.host.get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b != null and b.loot_id == PART and not b.is_carried() and not b.is_queued_for_deletion() \
				and not b.has_meta(LootManager.META_CONSUMED) and f.rt.is_ancestor_of(b):
			out.append(b)
	return out


## [escape_wait] escape_eta_s after [secure], then the escape zone.
func _escape() -> bool:
	if not f.check(f.objective(&"escape_wait") != Enums.ObjectiveState.HIDDEN or bool(_m().get(&"escape_open")),
			"[escape_wait] after [secure]"):
		return false
	var eta: float = float(_m().call(&"loud_escape_eta"))
	if not f.check(await f.fast_until(func() -> bool: return bool(_m().get(&"escape_open")), eta + 10.0),
			"the escape opens %.0f s after [secure]" % eta):
		return false
	return await f.escape(f.tagged(&"escape") as EscapeZone)
