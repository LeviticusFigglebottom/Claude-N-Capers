## PO-5 Glasshouse STEALTH run: a scripted player wins the heist without raising the alarm, through
## player input only (Po5Pilot / PlayerInputDriver: mouse look, WASD, F hold/tap, G hold, melee).
## The flow reads game state the way a player's eyes and casing would (NPC positions, facing and
## patrol routes, variants, objective states, the HUD detection meters); it never writes game state.
## Plan (adapts to rt.variants):
##   1. casing (unmasked): Harlow Ave -> Pell St -> fire exit -> G4 -> stair -> U4 (a counter keycard is
##      lifted from the customer side of the counter on the way; an upstairs keycard is picked up unmasked);
##   2. U2: come in behind the camera operator, mask, knife him (all cameras off), answer his pager;
##   3. hunt the guards whose patrol reaches the back of house / upstairs / our loot path with the knife:
##      from behind, or stand still when one spots us and knife him when he walks up to cuff us;
##      answer every pager;
##   4. civilians who start to notice us masked are shouted down and cable-tied (hook in the pilot);
##   5. lockpick the workshop, shout + tie the jeweler, keycard reader (or the safe code), bag 2 bags,
##      carry them to the van one by one, stand in the escape zone, payday -> hub.
extends RefCounted

const UPPER_Y: float = 4.2
const KEYCARD_AT: Dictionary = {
	&"kc_counter": Vector3(3.2, 0.9, 7.4), &"kc_manager": Vector3(9.2, 4.95, 8.75),
	&"kc_security": Vector3(10.15, 4.95, 3.4), &"kc_breakroom": Vector3(2.6, 4.94, 2.3),
	&"kc_jeweler": Vector3(9.75, 0.92, 0.75),
}

var f: Node = null
var p: Po5Pilot = null
var rt: HeistRuntime = null
var crew: CrewController = null
var st: StealthDirector = null
var alarm: StringName = &""
var pagers_answered: int = 0
## Civilians we shouted down and still have to keep down (no tie left for them).
var downed: Array[NpcBase] = []
var answered_guards: Array[NpcBase] = []
## Last spot (masked) no calm civilian could see.
var safe_spot: Vector3 = Vector3.INF
var _last_meter_note: float = -10.0
var _last_dash_note: float = -10.0


func play(flow: Node) -> int:
	f = flow
	p = flow.get(&"pilot") as Po5Pilot
	rt = flow.get(&"rt") as HeistRuntime
	crew = p.crew
	st = rt.stealth
	p.arrive_dy = 1.2
	p.no_blind_press = true  # a blind F press is a shout: it once put the whole sales floor down at the workshop door
	p.shout_blockers = false  # a shouted civilian gets up panicked 45 s later: never shout by accident
	p.hook_need = _hook_need
	p.hook = _hook
	_setup()
	for step: Callable in [_approach, _enter_boh, _keycard_upstairs, _operator, _keycard_masked, _corridor_camera,
			_guards, _workshop, _safe, _bags]:
		var err: String = await step.call()
		if err == "" and alarm != &"":
			err = "PO-5.stealth.alarm: alarm raised (%s)" % alarm
		if err != "":
			return await _fail("%s [step %s]" % [err, step.get_method()])
		f.note("STEP %s done t=%.0f at %s masked=%s pagers=%d" % [step.get_method(), rt.heist_time_s,
			Po5Pilot._v(crew.global_position), crew.masked, pagers_answered])
	return await _escape()


# --- Setup / logging --------------------------------------------------------------------------

func _setup() -> void:
	EventBus.alarm_raised.connect(func(reason: StringName, src: int) -> void:
		alarm = reason
		var src_n: Node = Ids.lookup(src)
		var gb: GuardBrain = src_n.get_node_or_null(^"Brain") as GuardBrain if src_n != null else null
		f.note("EVENT alarm_raised %s by %s cause %s focus %s (t=%.0f) crew at %s" % [reason, _npc_name(src),
			gb.alarm_cause if gb != null else &"-", Po5Pilot._v(gb.focus_position) if gb != null else "-",
			rt.heist_time_s, Po5Pilot._v(crew.global_position)]))
	EventBus.objective_updated.connect(func(id: StringName, s: int, _d: Dictionary) -> void:
		f.note("EVENT objective %s -> %d (t=%.0f)" % [id, s, rt.heist_time_s]))
	EventBus.pager_started.connect(func(pid: int, gid: int) -> void:
		f.note("EVENT pager_started %d guard %s (t=%.1f)" % [pid, _npc_name(gid), rt.heist_time_s]))
	EventBus.pager_answered.connect(func(pid: int, _s: int, total: int) -> void:
		pagers_answered = total
		f.note("EVENT pager_answered %d total %d (t=%.1f)" % [pid, total, rt.heist_time_s]))
	EventBus.pager_failed.connect(func(pid: int, why: StringName) -> void:
		f.note("EVENT pager_failed %d %s (t=%.1f)" % [pid, why, rt.heist_time_s]))
	EventBus.civilian_intimidated.connect(func(id: int, _s: int) -> void:
		f.note("EVENT civilian_intimidated %s at %s" % [_npc_name(id), _npc_pos(id)]))
	EventBus.civilian_tied.connect(func(id: int, _s: int) -> void:
		f.note("EVENT civilian_tied %s at %s" % [_npc_name(id), _npc_pos(id)]))
	EventBus.civilian_fled.connect(func(id: int) -> void:
		f.note("EVENT civilian PANICKED %s at %s (crew at %s)" % [_npc_name(id), _npc_pos(id), Po5Pilot._v(crew.global_position)]))
	EventBus.npc_killed.connect(func(id: int, _k: int, _i: Dictionary) -> void:
		f.note("EVENT npc_killed %s at %s" % [_npc_name(id), _npc_pos(id)]))
	EventBus.body_discovered.connect(func(body: int, by: int) -> void:
		f.note("EVENT body_discovered %s by %s" % [_npc_name(body), _npc_name(by)]))
	EventBus.cameras_loop_disabled.connect(func(_by: int) -> void: f.note("EVENT cameras disabled (operator down)"))
	EventBus.item_picked_up.connect(func(item: StringName, _s: int) -> void: f.note("EVENT picked up %s" % item))
	EventBus.loot_secured.connect(func(_b: int, lid: StringName, v: int) -> void:
		f.note("EVENT loot_secured %s $%d (t=%.0f)" % [lid, v, rt.heist_time_s]))
	EventBus.crew_masked.connect(func(slot: int) -> void:
		if slot == crew.slot:
			f.note("EVENT masked at %s (t=%.1f)" % [Po5Pilot._v(crew.global_position), rt.heist_time_s]))
	EventBus.crew_cuffed.connect(func(slot: int, by: int) -> void:
		f.note("EVENT crew %d CUFFED by %s" % [slot, _npc_name(by)]))
	st.crew_detected.connect(func(obs: Node, c: Node) -> void:
		if c == crew:
			f.note("EVENT crew SPOTTED by %s at %s (t=%.1f)" % [obs.name, Po5Pilot._v(crew.global_position), rt.heist_time_s]))
	f.note("variants: %s" % [rt.variants])
	var cams: PackedStringArray = PackedStringArray()
	for c: Node in f.get_tree().get_nodes_in_group(SecurityCamera.GROUP):
		var cam: SecurityCamera = c as SecurityCamera
		if cam != null and cam.is_inside_tree() and cam.active:
			cams.append("%s@%s" % [cam.name, Po5Pilot._v(cam.global_position)])
	f.note("live cameras: %s; operator: %s" % [cams, _operator_npc().name if _operator_npc() != null else "none"])
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		var route: String = ""
		var gb: GuardBrain = npc.get_node_or_null(^"Brain") as GuardBrain
		if gb != null:
			for rp: Vector3 in gb.route:
				route += " " + Po5Pilot._v(rp)
		f.note("NPC %s role %s at %s tags %s%s" % [npc.name, npc.role, Po5Pilot._v(npc.global_position),
			npc.spawn_info.get("tags", []), (" route" + route) if route != "" else ""])
	_watch()


## Background logger (no input): detection meters on us, and slow wall-clock stretches.
func _watch() -> void:
	var wall: int = Time.get_ticks_msec()
	while rt != null and is_instance_valid(rt) and rt.phase != Enums.HeistPhase.ENDED:
		await f.wait_s(0.5)
		var now: int = Time.get_ticks_msec()
		if now - wall > 8000:
			f.note("SLOW: 0.5 game s took %.1f wall s (t=%.1f)" % [(now - wall) / 1000.0, rt.heist_time_s])
		wall = now
		var rows: PackedStringArray = PackedStringArray()
		for e: Dictionary in st.detection_entries(crew.slot):
			if float(e["value"]) > 0.05:
				rows.append("%s=%.2f" % [_npc_name(int(e["observer_net_id"])), float(e["value"])])
		if not rows.is_empty() and rt.heist_time_s - _last_meter_note >= 1.0:
			_last_meter_note = rt.heist_time_s
			f.note("METER %s crew %s masked=%s" % [", ".join(rows), Po5Pilot._v(crew.global_position), crew.masked])


# --- Phases -----------------------------------------------------------------------------------

## Casing (unmasked, PUBLIC): Harlow Ave sidewalk; a counter keycard is lifted from the customer side.
func _approach() -> String:
	await f.shot("stealth_start")
	if _variant(&"keycard") == &"kc_counter":
		var err: String = await _counter_keycard()
		if err != "":
			return err
		# Back out the main entrance to the street.
		if not await p.goto(Vector3(11.25, 0.0, 13.4), 0.6, 60.0):
			return "PO-5.stealth.approach: could not leave the shop by the main entrance"
		p.block_shout_after = 4
	for wp: Vector3 in [Vector3(19.7, 0.0, 14.0), Vector3(19.6, 0.0, 2.6)]:
		if not await p.goto(wp, 0.6, 60.0, false, false):
			return "PO-5.stealth.approach: could not walk the street to %s" % Po5Pilot._v(wp)
	return ""


func _counter_keycard() -> String:
	p.block_shout_after = 1000  # never shout on the sales floor: the whole floor goes down, then panics
	var kc: InteractableComponent = _comp_tagged(&"keycard")
	if not await p.goto(Vector3(11.25, 0.0, 10.8), 0.6, 60.0):
		return "PO-5.stealth.counter: could not walk into the shop"
	# Customer side of the counter, by the card (PUBLIC: nobody minds an unmasked customer). The queue spot
	# right in front is usually taken; the card is within reach from the counter's end too.
	if not await p.goto(Vector3(4.2, 0.0, 8.2), 0.5, 25.0, false, false):
		f.note("counter front spot not reached (at %s)" % Po5Pilot._v(crew.global_position))
	var ok: bool = await p.use(kc, 6.0, func() -> bool: return not kc.enabled or _has_keycard(), false)
	await f.shot("counter_keycard")
	if not _has_keycard():
		return "PO-5.stealth.counter: could not take the counter keycard from the customer side (at %s)" % \
			Po5Pilot._v(crew.global_position)
	f.note("counter keycard taken unmasked (use ok=%s)" % ok)
	return ""


## Fire exit (unlocked, opens unmasked) -> G10 -> lobby door -> G4 -> stair -> U4.
func _enter_boh() -> String:
	if not await p.goto(Vector3(17.0, 0.0, 2.6), 0.6, 30.0):
		await f.shot("fire_exit")
		return "PO-5.stealth.fire_exit: could not get through the fire exit into G10"
	await _close_door(_door_named(&"FireExit"))
	if not await p.goto(Vector3(14.5, 2.1, 0.8), 0.6, 60.0):
		await f.shot("stair")
		return "PO-5.stealth.stair: could not reach the upper corridor"
	return ""


## Upstairs keycards are picked up unmasked (RESTRICTED: only guards / cameras notice, slowly).
func _keycard_upstairs() -> String:
	var v: StringName = _variant(&"keycard")
	if v != &"kc_manager" and v != &"kc_breakroom" and not (v == &"kc_security" and _operator_npc() == null):
		return ""
	await _wait_u4_clear()
	return await _take_keycard()


## The camera operator sits facing the west monitor wall: come in behind him, mask, knife, answer.
func _operator() -> String:
	var op: NpcBase = _operator_npc()
	if op == null:
		f.note("no camera operator (security room empty): cameras stay live")
		return ""
	# The upper corridor is 1.5 m wide: a rover standing in it blocks the way (and C6 watches it). Wait on
	# the stair landing, out of every view, until it is clear.
	await _wait_u4_clear()
	var behind: Vector3 = op.global_position - _flat(op.look_forward()) * 1.3
	if not await p.goto(behind, 0.35, 60.0):
		await f.shot("operator_unreached")
		return "PO-5.stealth.operator: could not get behind the operator (at %s)" % Po5Pilot._v(op.global_position)
	if not await _mask_up():
		return "PO-5.stealth.mask: could not mask up"
	if not await _knife(op):
		return "PO-5.stealth.knife: the operator survived the knife"
	return await _answer_pager(op)


func _wait_u4_clear() -> void:
	var t0: float = rt.heist_time_s
	while rt.heist_time_s - t0 < 90.0 and _u4_blocked():
		if p.flat_dist(crew.global_position, Vector3(14.5, 0.0, 0.8)) > 0.8:
			f.note("upper corridor blocked by a guard: waiting on the stair landing")
			await p.goto(Vector3(14.5, 2.1, 0.8), 0.6, 20.0)
		await f.wait_s(0.5)


func _u4_blocked() -> bool:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		var v: Vector3 = g.global_position
		if g != _operator_npc() and v.y > 3.0 and v.z > 4.3 and v.z < 6.2 and v.x > 7.0 and v.x < 16.0:
			return true
	return false


func _keycard_masked() -> String:
	if _has_keycard() or _variant(&"keycard") != &"kc_security":
		return ""
	return await _take_keycard()


## Guards whose patrol reaches where we work (back of house, upstairs, the loot path) die by the knife.
## Civilians get stuck at the stair foot (game finding): coming down masked they would see us at once.
## From the stair top (another floor, no line of sight) the all-around shout still puts them down.
func _clear_stair_foot() -> void:
	if _floor_rule():
		return  # the shout no longer reaches down the stair; NPCs climb / yield now (PO-5 civilian lane)
	for c: NpcBase in _civilians():
		var b: CivilianBrain = _civ_brain(c)
		if c.global_position.y < 1.5 and p.flat_dist(c.global_position, Vector3(13.9, 0.0, 4.9)) < 2.5 \
				and (b.mode == CivilianBrain.Mode.IDLE or b.mode == CivilianBrain.Mode.WANDER):
			f.note("civilian %s at the stair foot %s: shout from upstairs" % [c.name, Po5Pilot._v(c.global_position)])
			if crew.global_position.y > 3.0:
				await p.goto(Vector3(15.3, UPPER_Y, 5.25), 0.5, 30.0)
			await _reshout(c)


func _guards() -> String:
	if not crew.masked:
		# Stair landing: off every camera cone (C3 looks down G4, C6 down U4) and every room.
		await p.goto(Vector3(14.5, 2.1, 0.8), 0.6, 60.0)
	if not await _mask_up():
		return "PO-5.stealth.mask: could not mask up"
	if crew.global_position.y > 3.0:
		await _clear_stair_foot()
	for _round: int in 4:
		var target: NpcBase = null
		var best: float = INF
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			if g == null or not g.is_alive() or not _guard_matters(g):
				continue
			var d: float = g.global_position.distance_to(crew.global_position)
			if d < best:
				best = d
				target = g
		if target == null:
			return ""
		var err: String = await _hunt(target, 240.0)
		if err != "":
			return err
	return ""


## Lockpick the workshop door, then put the jeweler down and tie him.
func _workshop() -> String:
	var wdoor: InteractableComponent = _comp_tagged(&"workshop_door")
	var door: Door = wdoor.owner_node() as Door
	if not await _back_inside():
		return "PO-5.stealth.workshop: could not get back inside from %s" % Po5Pilot._v(crew.global_position)
	if not await _sneak_to(p.stand_point(Vector3(7.5, 0.0, 5.3)), 0.5, 120.0):
		return "PO-5.stealth.workshop: could not reach the workshop door"
	if not door.is_open:
		await p.use(wdoor, 20.0, func() -> bool: return door.is_open)
	if not door.is_open:
		f.note("workshop door: availability '%s' masked=%s at %s" % [wdoor.availability(crew), crew.masked,
			Po5Pilot._v(crew.global_position)])
		await p.use(wdoor, 20.0, func() -> bool: return door.is_open)
	if not door.is_open:
		await f.shot("workshop_locked")
		return "PO-5.stealth.workshop: lockpicking the workshop door failed"
	var c5: SecurityCamera = _live_camera("C5")
	if c5 != null:
		var err5: String = await _smash_camera(c5)
		if err5 != "":
			return err5
	# The jeweler works at the bench with his back to the door: a knife from behind is silent and, unlike a
	# shout (which also puts the counter staff and customers down through the wall), leaves nobody to babysit.
	for c: NpcBase in _civilians():
		var cb: CivilianBrain = _civ_brain(c)
		if p.flat_dist(c.global_position, Vector3(7.75, 0.0, 2.25)) < 3.5 and c.global_position.y < 2.0 \
				and cb.mode != CivilianBrain.Mode.TIED:
			var behind: Vector3 = c.global_position - _flat(c.look_forward()) * 1.0
			await p.goto(p.stand_point(behind), 0.35, 10.0, false, false)
			if not await _knife(c, 0.0) and c.is_alive():
				var err: String = await _subdue(c)
				if err != "":
					return err
	await _close_door(door)
	await f.shot("workshop_open")
	return ""


## The safe's loot is there and takeable (its interactable only exists once the safe has opened).
func _safe_loot_ready() -> bool:
	var loot: InteractableComponent = _comp_tagged(&"safe_loot")
	return loot != null and loot.enabled


## Keycard reader (or the safe's code when a note was read), then wait for the door to swing.
func _safe() -> String:
	if _safe_loot_ready():
		return ""
	if not _has_keycard() and KEYCARD_AT.has(_variant(&"keycard")):
		var err: String = await _take_keycard()
		if err != "":
			return err
	var reader: InteractableComponent = _comp_tagged(&"safe_reader")
	if _has_keycard() and reader != null:
		await p.use(reader, 6.0, _safe_loot_ready)
	var t: float = 0.0
	while not _safe_loot_ready() and t < 5.0:
		await p.tick()
		t += p.dt()
	if not _safe_loot_ready():
		await f.shot("safe_closed")
		return "PO-5.stealth.safe: the safe did not open (keycard=%s)" % _has_keycard()
	await f.shot("safe_open")
	return ""


## Bag the consignment and carry it to the van, one bag at a time.
func _bags() -> String:
	var loot: InteractableComponent = _comp_tagged(&"safe_loot")
	var zone: SecureZone = p.secure_zone()
	if zone == null:
		return "PO-5.stealth.van: no active secure zone"
	f.note("secure zone %s at %s" % [zone.get_path(), Po5Pilot._v(zone.global_position)])
	var c4: SecurityCamera = _live_camera("C4")
	if c4 != null and _variant(&"escape") == &"esc_alley_west":
		await _to_alley()
		var err4: String = await _smash_camera(c4)
		if err4 != "":
			return err4
	var bags: int = 0
	var tries: int = 0
	while bags < 2 and tries < 5:
		tries += 1
		if not crew.is_carrying_bag():
			await _sneak_to(p.stand_point(loot.global_position), 0.8)
			await p.use(loot, 10.0, func() -> bool: return crew.is_carrying_bag())
		if not crew.is_carrying_bag():
			f.note("could not bag the safe loot (try %d)" % tries)
			continue
		if alarm != &"":
			return "PO-5.stealth.alarm: alarm raised (%s) while bagging" % alarm
		if not _inside(zone.global_position):
			await _refresh_downs(40.0)
			await _via_fire_exit(true)
			if zone.global_position.z < 0.0:
				await p.goto(Vector3(17.5, 0.0, -2.8), 0.8, 60.0)
		if await p.secure_carried_bag(zone):
			bags += 1
			f.note("bag %d secured t=%.0f" % [bags, rt.heist_time_s])
			if bags == 1:
				await f.shot("bag_1")
		if alarm != &"":
			return "PO-5.stealth.alarm: alarm raised (%s) while carrying" % alarm
		if bags < 2 and not _inside(crew.global_position):
			if crew.global_position.z < 0.0:
				await p.goto(Vector3(17.5, 0.0, -2.8), 0.8, 60.0)
			await _via_fire_exit(false)
	if bags < 2:
		return "PO-5.stealth.bags: only %d bags secured" % bags
	return ""


func _escape() -> int:
	var ended: Array[bool] = [false]
	var escape_done: Array[bool] = [false]
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		ended[0] = true
		# events.md v1.7: [escape] completes before heist_ended.
		escape_done[0] = rt.mission.objective_state(&"escape") == Enums.ObjectiveState.COMPLETED
		f.note("EVENT heist_ended success=%s went_loud=%s %s" % [r.get("success"), rt.went_loud, r]))
	var t0: float = rt.heist_time_s
	while p.active_escape() == null and rt.heist_time_s - t0 < 20.0:
		await f.wait_s(0.5)
	var ez: EscapeZone = p.active_escape()
	if ez == null:
		return await _fail("PO-5.stealth.escape: escape never activated after 2 bags")
	f.note("escape active at %s" % Po5Pilot._v(ez.global_position))
	await p.goto(p.stand_point(ez.global_position), 1.0, 120.0)
	var t1: float = rt.heist_time_s
	while not ended[0] and rt.heist_time_s - t1 < 30.0:
		await f.wait_s(0.5)
		if not ended[0] and not p.near(crew.global_position, ez.global_position, 1.5):
			await p.goto(p.stand_point(ez.global_position), 0.8, 20.0)
	if not ended[0]:
		await f.shot("escape_stuck")
		return await _fail("PO-5.stealth.escape: standing in the escape zone did not end the heist")
	if rt.went_loud or alarm != &"":
		return await _fail("PO-5.stealth: the heist ended but it went loud (%s)" % alarm)
	if not escape_done[0]:
		return await _fail("PO-5.stealth.escape: [escape] was not completed before heist_ended (events.md v1.7)")
	f.note("STEALTH WIN: heist ended with no alarm, pagers answered %d" % pagers_answered)
	return await f.payday_to_hub()


# --- Cameras (no operator to kill) -----------------------------------------------------------

func _live_camera(cid: String) -> SecurityCamera:
	for c: Node in f.get_tree().get_nodes_in_group(SecurityCamera.GROUP):
		var cam: SecurityCamera = c as SecurityCamera
		if cam != null and cam.name == "Camera" + cid and cam.is_inside_tree() and cam.can_observe():
			return cam
	return null


## G4 corridor camera (C3, east end looking west): stand under it, mask, knife it.
func _corridor_camera() -> String:
	var cam: SecurityCamera = _live_camera("C3")
	if cam == null:
		return ""
	return await _smash_camera(cam)


## A wall camera is broken with one knife swing from right under its lens (outside its cone).
func _smash_camera(cam: SecurityCamera) -> String:
	var fl: float = 0.0 if cam.global_position.y < 4.0 else UPPER_Y
	var mount: Vector3 = Vector3(cam.global_position.x, fl, cam.global_position.z)
	var spot: Vector3 = p.stand_point(mount + _flat(cam.look_forward()) * 0.6)
	f.note("smash %s at %s from %s (fwd %s)" % [cam.name, Po5Pilot._v(cam.global_position), Po5Pilot._v(spot),
		Po5Pilot._v(cam.look_forward())])
	if not await _sneak_to(spot, 0.3, 90.0):
		return "PO-5.stealth.camera: could not get under %s" % cam.name
	if not await _mask_up():
		return "PO-5.stealth.mask: could not mask up"
	for i: int in 4:
		await p.face(cam.eye_position(), 0.03, 1.0)
		if i >= 2:
			p.inp.press(&"jump")
			await p.inp.ticks(6)
			p.inp.release(&"jump")
		await p.inp.tap(&"melee")
		await p.inp.ticks(int(0.8 * Engine.physics_ticks_per_second))
		if cam.destroyed:
			break
	f.note("smash %s -> destroyed=%s (eye dist %.2f)" % [cam.name, cam.destroyed, crew.eye_position().distance_to(cam.eye_position())])
	if not cam.destroyed:
		await f.shot("camera_smash_failed")
		return "PO-5.stealth.camera: the knife does not reach %s at %s from %s" % [cam.name,
			Po5Pilot._v(cam.global_position), Po5Pilot._v(crew.global_position)]
	return ""


# --- Routes -----------------------------------------------------------------------------------

## Ground-floor spots a masked crew member must not go: the sales floor and the G4 west end by the
## staff door (customers walk through it; the sales floor sees in when it stands open).
static func _exposed(v: Vector3) -> bool:
	if not _inside(v) or v.y > 2.0:
		return false
	return v.z > 6.0 or (v.z > 4.3 and v.x < 4.8)


static func _inside(v: Vector3) -> bool:
	return v.x > 0.0 and v.x < 18.0 and v.z > 0.0 and v.z < 12.0


## Leave or enter the building by the fire exit (G10 <-> Pell St): the back of house stays off the sales
## floor cameras' sightline through the staff door, and the street / alley have no civilians.
func _via_fire_exit(to_outside: bool) -> bool:
	if _inside(crew.global_position) != to_outside:
		return true
	if to_outside:
		if not await _sneak_to(Vector3(17.0, 0.0, 2.6), 0.6, 120.0):
			return false
		return await p.goto(Vector3(19.6, 0.0, 1.9), 0.6, 60.0)
	for wp: Vector3 in [Vector3(19.6, 0.0, 1.9), Vector3(17.0, 0.0, 2.6)]:
		if not await p.goto(wp, 0.6, 60.0):
			return false
	return true


## Back inside after the guard hunt (it can end in the alley). The smoker's BackDoor (LOCKPICK) is only on the
## navmesh route while it is open (its NavLink); closed, the nav path from the alley runs up the fire-escape ladder to
## the latched break-room window and the walk stalls there (PO6 rerun, seed 42: 120 s at (3.1, 4.2, -0.6)). Pick the
## BackDoor (masked: allowed), else go round by the fire exit.
func _back_inside() -> bool:
	if _inside(crew.global_position):
		return true
	var back: Door = _door_named(&"BackDoor")
	if back != null and not back.is_open and back.interactable != null and back.interactable.enabled:
		f.note("outside at %s: in by the BackDoor (%s)" % [Po5Pilot._v(crew.global_position), back.interactable.kind])
		await p.use(back.interactable, 40.0, func() -> bool: return back.is_open)
	if back != null and back.is_open:
		return await p.goto(Vector3(3.5, 0.0, 1.2), 0.6, 20.0)
	return await _via_fire_exit(false)


## From wherever we are to the alley (outside, by the Pell St mouth).
func _to_alley() -> bool:
	if not await _via_fire_exit(true):
		return false
	return await p.goto(Vector3(17.5, 0.0, -2.8), 0.8, 60.0)


# --- Guards -----------------------------------------------------------------------------------

## Calm civilians that would see a masked crew member standing at `pos` (FOV, range, line of sight).
func _civ_watchers(pos: Vector3) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	var target: Vector3 = pos + Vector3(0.0, 1.0, 0.0)
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	for c: NpcBase in _civilians():
		var b: CivilianBrain = _civ_brain(c)
		if b.mode != CivilianBrain.Mode.IDLE and b.mode != CivilianBrain.Mode.WANDER:
			continue
		var eye: Vector3 = c.eye_position()
		var to: Vector3 = target - eye
		if to.length() > 20.0:
			continue
		var fw: Vector3 = c.look_forward()
		if Vector2(fw.x, fw.z).angle_to(Vector2(to.x, to.z)) > deg_to_rad(75.0) and Vector2(to.x, to.z).length() > 2.5:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target, StealthDirector.VISION_MASK)
		q.exclude = [c.get_rid(), crew.get_rid()]
		if space.intersect_ray(q).is_empty():
			out.append(c)
	return out


## A guard matters when his patrol (or post) reaches where we work: back of house / upstairs, or the
## alley when the van is there.
func _guard_matters(g: NpcBase) -> bool:
	var gb: GuardBrain = g.get_node_or_null(^"Brain") as GuardBrain
	if gb == null:
		return false
	var pts: Array[Vector3] = gb.route.duplicate()
	if pts.is_empty():
		pts.append(g.global_position)
	for rp: Vector3 in pts:
		if rp.y > 2.0 or (rp.z > 0.0 and rp.z < 6.0):
			return true
		if rp.z <= 0.0 and _variant(&"escape") == &"esc_alley_west":
			return true
	return false


## Stalk `g` and knife him: approach from behind; if he spots us, stand still and knife him when he
## walks up to cuff us. Then answer his pager.
func _hunt(g: NpcBase, timeout_s: float) -> String:
	var gb: GuardBrain = g.get_node_or_null(^"Brain") as GuardBrain
	f.note("hunt %s at %s (state %s)" % [g.name, Po5Pilot._v(g.global_position), gb.state_name()])
	await _refresh_downs(40.0)
	var t0: float = rt.heist_time_s
	if g.global_position.z < 0.0 and _inside(crew.global_position):
		await _to_alley()
	p.quiet = true
	while g.is_alive():
		if alarm != &"":
			p.quiet = false
			return "PO-5.stealth.alarm: alarm raised (%s) while hunting %s" % [alarm, g.name]
		if rt.heist_time_s - t0 > timeout_s:
			p.quiet = false
			await f.shot("hunt_timeout")
			return "PO-5.stealth.hunt: %s still alive after %.0f s (at %s, we at %s)" % [g.name, timeout_s,
				Po5Pilot._v(g.global_position), Po5Pilot._v(crew.global_position)]
		if _arresting_us(g):
			await _await_arrest(g)
			continue
		if _exposed(g.global_position):
			if _hook_need():
				await _hook()
			await f.wait_s(0.5)  # on the sales floor / by the staff door (customers, cameras): wait in the back
			continue
		var d: float = p.flat_dist(g.global_position, crew.global_position)
		if d <= 1.45 and absf(g.global_position.y - crew.global_position.y) < 1.0:
			await _knife(g, 0.0)
			continue
		if absf(g.global_position.y - crew.global_position.y) < 1.5 and not _civ_watchers(g.global_position).is_empty():
			# A civilian can see him: the kill (or his arrest of us) would happen in their view. Wait unseen.
			if _hook_need():
				await _hook()
			elif not _civ_watchers(crew.global_position).is_empty() and safe_spot != Vector3.INF:
				await p.goto(safe_spot, 0.4, 2.0)
			else:
				await f.wait_s(0.4)
			continue
		var goal: Vector3 = _via_stair(g.global_position - _flat(g.look_forward()) * 0.9)
		await _stealth_step(p.stand_point(goal), 0.6)
	p.quiet = false
	f.note("%s down t=%.0f" % [g.name, rt.heist_time_s])
	var err: String = await _answer_pager(g)
	if err == "":
		await _bag_if_seen(g)
	return err


## A body where the floor guard could see it (the G4 corridor, through the staff door) is bagged with our
## one body bag (guards only investigate a body bag; civilians ignore it).
func _bag_if_seen(body: NpcBase) -> void:
	var v: Vector3 = body.global_position
	if crew.body_bags <= 0 or not _inside(v) or v.y > 2.0 or v.z < 4.3 or v.z > 6.2:
		return
	var comp: InteractableComponent = body.get_node_or_null(^"BagBodyInteractable") as InteractableComponent
	if comp == null:
		return
	await p.use(comp, 6.0, func() -> bool: return crew.body_bags <= 0 or not is_instance_valid(body))
	f.note("bagged body %s -> bags left %d" % [body.name if is_instance_valid(body) else "?", crew.body_bags])


## Masked walk inside the building in short legs, holding (or backing off to the last unseen spot)
## while a calm civilian would see us. Arrives within `arrive_m`.
func _sneak_to(goal: Vector3, arrive_m: float = 0.6, timeout_s: float = 120.0) -> bool:
	if not crew.masked:
		return await p.goto(goal, arrive_m, timeout_s)
	var t0: float = rt.heist_time_s
	p.quiet = true
	while rt.heist_time_s - t0 < timeout_s and alarm == &"":
		if p.flat_dist(crew.global_position, goal) <= arrive_m and absf(crew.global_position.y - goal.y) < 1.2:
			p.quiet = false
			return true
		await _stealth_step(goal, arrive_m)
	p.quiet = false
	return p.flat_dist(crew.global_position, goal) <= arrive_m


## One masked move toward `goal`: deal with the hook first (arrest, civilians), walk on when no calm civilian
## would see us here or a step ahead, dash past watchers that are far and not noticing yet, else hold
## (or back off to the last unseen spot).
func _stealth_step(goal: Vector3, arrive_m: float) -> void:
	if _hook_need():
		await _hook()
		return
	var target: Vector3 = _via_stair(goal)
	var here_w: Array[NpcBase] = _civ_watchers(crew.global_position)
	var ws: Array[NpcBase] = here_w.duplicate()
	ws.append_array(_civ_watchers(_path_step(target, 1.5)))
	if here_w.is_empty():
		safe_spot = crew.global_position
	if ws.is_empty():
		await p.goto(target, arrive_m, 0.8)
		return
	var far: bool = true
	for c: NpcBase in ws:
		if p.flat_dist(c.global_position, crew.global_position) < 9.0 or st.detection_value(c, crew.slot) > 0.15:
			far = false
	if far:
		if rt.heist_time_s - _last_dash_note > 3.0:
			_last_dash_note = rt.heist_time_s
			f.note("dash past far civilians %s" % [ws.map(func(c: NpcBase) -> String: return String(c.name))])
		await p.goto(target, arrive_m, 1.2, true)
		return
	if not here_w.is_empty() and safe_spot != Vector3.INF and p.flat_dist(safe_spot, crew.global_position) > 0.5:
		await p.goto(safe_spot, 0.4, 2.0)
	else:
		await f.wait_s(0.3)


## Between floors the navmesh may route through the break-room window and the fire-escape ladder, which
## a walking player cannot use: go by the stair landing instead.
func _via_stair(goal: Vector3) -> Vector3:
	var cy: float = crew.global_position.y
	if absf(cy - goal.y) < 1.5:
		return goal
	var landing: Vector3 = Vector3(14.5, 2.1, 0.8)
	if cy > 0.4 and cy < 3.8:  # on the stair already: the nav path is the stair
		return Vector3(13.9, 0.0, 4.6) if goal.y < cy else Vector3(15.3, UPPER_Y, 4.6)
	return landing


## The point `ahead_m` along the nav path to `goal`.
func _path_step(goal: Vector3, ahead_m: float) -> Vector3:
	var path: PackedVector3Array = p.nav_path(p.stand_point(goal))
	var left: float = ahead_m
	var prev: Vector3 = crew.global_position
	for q: Vector3 in path:
		var seg: float = prev.distance_to(q)
		if seg >= left:
			return prev.lerp(q, left / maxf(seg, 0.001))
		left -= seg
		prev = q
	return prev


func _arresting_us(g: NpcBase) -> bool:
	var gb: GuardBrain = g.get_node_or_null(^"Brain") as GuardBrain
	return gb != null and g.is_alive() and gb.cuff_phase != GuardBrain.CuffPhase.NONE and gb.cuff_target == crew


## S3.2 counterplay: a guard that spotted us yells, pauses and walks over to cuff: hold still (moving
## more than 1.7 m is the alarm) and knife him once he is in reach.
func _await_arrest(g: NpcBase) -> void:
	p.inp.release(&"move_forward")
	p.inp.release(&"sprint")
	f.note("arrest: %s spotted us at %s; holding still" % [g.name, Po5Pilot._v(crew.global_position)])
	var t: float = 0.0
	while g.is_alive() and t < 30.0 and alarm == &"":
		var d: float = p.flat_dist(g.global_position, crew.global_position)
		if d <= 1.7:
			if not await _knife(g, 0.0) and g.is_alive():
				await p.inp.hold(&"move_left", 0.15)  # a downed civilian in the swing: shift a step (< 1.7 m)
			t += 0.5
			continue
		var c: NpcBase = _civ_threat()
		if c != null and d > 3.0:
			# Pinned by the arrest (moving is the alarm): a shout does not move us.
			f.note("arrest hold: civilian %s noticing us: shout in place" % c.name)
			await p.face(c.global_position + Vector3(0.0, 1.3, 0.0), 0.05, 0.6)
			await p.inp.tap(&"shout")
			await p.inp.ticks(int(Tweak.stealth().shout_cooldown_s * Engine.physics_ticks_per_second) + 2)
			t += 1.0
			continue
		await p.face(g.head_position() - Vector3(0.0, 0.5, 0.0), 0.05, 0.25)
		await p.tick()
		t += 0.25 + p.dt()


## A guard on the radio about us (no cuffs): knife him within the 2 s call if he is close.
func _radioing(g: NpcBase) -> bool:
	var gb: GuardBrain = g.get_node_or_null(^"Brain") as GuardBrain
	return gb != null and g.is_alive() and gb.radio_time_left > 0.0


# --- Civilians (pilot hook) -------------------------------------------------------------------

func _civilians() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for n: Node in rt.npcs(&"civilian"):
		var c: NpcBase = n as NpcBase
		if c != null and c.is_alive() and _civ_brain(c) != null:
			out.append(c)
	return out


func _civ_brain(c: NpcBase) -> CivilianBrain:
	return c.get_node_or_null(^"Brain") as CivilianBrain


## The civilian we must deal with now (masked only): one noticing us with a clear line to shout, or one
## running to call. Civilians we already put down are handled by _down_soon().
func _civ_threat() -> NpcBase:
	if not crew.masked:
		return null
	var best: NpcBase = null
	var best_d: float = INF
	for c: NpcBase in _civilians():
		var b: CivilianBrain = _civ_brain(c)
		var d: float = crew.eye_position().distance_to(c.global_position + Vector3(0.0, 1.0, 0.0))
		if d > 11.0 or absf(c.global_position.y - crew.global_position.y) > 2.0:
			continue
		var want: bool = false
		match b.mode:
			CivilianBrain.Mode.IDLE, CivilianBrain.Mode.WANDER:
				# Noticing us (a preemptive shout at every civilian looking our way put so many down, through
				# walls, that renewing them all became the job).
				want = st.detection_value(c, crew.slot) > 0.3
			CivilianBrain.Mode.RUN_TO_CALL, CivilianBrain.Mode.CALLING:
				want = true
		if want and d < best_d and p.has_los(c.global_position + Vector3(0.0, 1.0, 0.0), c):
			best = c
			best_d = d
	return best


## A civilian we put down whose intimidation runs out soon (the shout must be renewed before they get up
## panicked and run for the phone / alarm button).
func _down_soon() -> NpcBase:
	var best: NpcBase = null
	for c: NpcBase in _civilians():
		var b: CivilianBrain = _civ_brain(c)
		if b.mode != CivilianBrain.Mode.DOWN or b.intimidate_left > 40.0:
			continue
		# Leave in time: walking there (~2.5 m/s with doors, stairs and sneaking) plus a margin.
		var need: float = 12.0
		if not _hears_here(c):
			need += _path_len(_reshout_spot(c)) / 2.5
		if b.intimidate_left < need and (best == null or b.intimidate_left < _civ_brain(best).intimidate_left):
			best = c
	return best


func _shout_reach() -> float:
	return Tweak.stealth().shout_all_within_m - 0.7


## The all-round shout reaches only the shouter's floor and needs line of sight or a short walk
## (ShoutSystem._hears_nearby, PO-5) when the tweak has shout_floor_dy_m; else it goes through everything.
func _floor_rule() -> bool:
	return &"shout_floor_dy_m" in Tweak.stealth()


## Would an all-round shout from standing at `from` reach downed civilian `c`?
func _hears_from(c: NpcBase, from: Vector3) -> bool:
	if p.flat_dist(c.global_position, from) > _shout_reach():
		return false
	if not _floor_rule():
		return true
	if absf(c.global_position.y - from.y) > float(Tweak.stealth().get(&"shout_floor_dy_m")) - 0.5:
		return false
	var eye: Vector3 = from + Vector3(0.0, 1.6, 0.0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, c.global_position + Vector3(0.0, 0.4, 0.0),
		StealthDirector.VISION_MASK)
	q.exclude = [c.get_rid(), crew.get_rid()]
	if crew.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return true
	var path: PackedVector3Array = NavPath.query(crew.get_world_3d().navigation_map, from, c.global_position, true)
	var n: float = 0.0
	for i: int in range(1, path.size()):
		n += path[i - 1].distance_to(path[i])
	return not path.is_empty() and n <= Tweak.stealth().shout_all_within_m * 1.1


func _hears_here(c: NpcBase) -> bool:
	return _hears_from(c, crew.global_position)


## Inside the workshop while its door is still locked (the navmesh runs through doorways).
func _behind_locked(q: Vector3) -> bool:
	var wd: InteractableComponent = _comp_tagged(&"workshop_door")
	var door: Door = wd.owner_node() as Door if wd != null else null
	return door != null and door.locked and q.y < 2.0 and q.x > 5.0 and q.x < 10.5 and q.z > 0.0 and q.z < 4.4


## The nav path to `to` crosses the sales floor / the staff-door end of G4 (masked there = seen).
func _path_exposed(to: Vector3) -> bool:
	if not crew.masked:
		return false
	var path: PackedVector3Array = p.nav_path(to)
	for i: int in range(1, path.size()):
		for k: int in 4:
			if _exposed(path[i - 1].lerp(path[i], float(k) / 4.0)):
				return true
	return false


func _path_len(to: Vector3) -> float:
	var path: PackedVector3Array = p.nav_path(to)
	var n: float = 0.0
	var prev: Vector3 = crew.global_position
	for q: Vector3 in path:
		n += prev.distance_to(q)
		prev = q
	return n if not path.is_empty() else 999.0


## Where to stand to renew a shout on `c`: within the all-around radius (flat: it reaches through walls and
## floors), off the sales floor, the nearest by path among the corridor below/above, the street and the alley.
func _reshout_spot(c: NpcBase) -> Vector3:
	var cp: Vector3 = c.global_position
	var cands: Array[Vector3] = [
		p.stand_point(Vector3(cp.x, crew.global_position.y, cp.z)),
		p.stand_point(Vector3(clampf(cp.x, 1.0, 17.0), 0.0, minf(cp.z, 5.2))),
		p.stand_point(Vector3(clampf(cp.x, 1.0, 17.0), UPPER_Y, 5.2)),
		p.stand_point(Vector3(clampf(cp.x, -2.0, 18.0), 0.0, 12.8)),
		p.stand_point(Vector3(clampf(cp.x, -2.0, 16.0), 0.0, -1.0)),
	]
	# Same floor: a ring around them (inside the shout radius) gives spots with a view of them.
	var fy: float = 0.0 if cp.y < 2.0 else UPPER_Y
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		cands.append(p.stand_point(Vector3(cp.x, fy, cp.z) + Vector3(cos(a), 0.0, sin(a)) * 3.5))
	var best: Vector3 = cands[1]
	var best_len: float = INF
	for q: Vector3 in cands:
		if not _hears_from(c, q) or _exposed(q) or _path_exposed(q) or _behind_locked(q):
			continue
		var l: float = _path_len(q)
		if l < best_len:
			best_len = l
			best = q
	return best


## Calm civilians a shout from here would also put down (S7.1: everyone within shout_all_within_m, flat).
func _collateral(target: NpcBase) -> int:
	var n: int = 0
	for c: NpcBase in _civilians():
		var b: CivilianBrain = _civ_brain(c)
		if c != target and (b.mode == CivilianBrain.Mode.IDLE or b.mode == CivilianBrain.Mode.WANDER) \
				and p.flat_dist(c.global_position, crew.global_position) <= Tweak.stealth().shout_all_within_m:
			n += 1
	return n


func _hook_need() -> bool:
	if alarm != &"":
		return false
	for n: Node in rt.npcs(&"guard"):
		if _arresting_us(n as NpcBase):
			return true
	return _civ_threat() != null or _down_soon() != null


func _hook() -> bool:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if _arresting_us(g):
			await _await_arrest(g)
			if not g.is_alive():
				await _answer_pager(g)
			return true
	var c: NpcBase = _civ_threat()
	if c != null:
		var b: CivilianBrain = _civ_brain(c)
		var calm: bool = b.mode == CivilianBrain.Mode.IDLE or b.mode == CivilianBrain.Mode.WANDER
		if calm and _collateral(c) > 0 and safe_spot != Vector3.INF and p.flat_dist(safe_spot, crew.global_position) > 0.8 \
				and not _civ_watchers(safe_spot).has(c):
			f.note("civilian %s noticing us; a shout here would also hit %d more: back to %s" % [c.name, _collateral(c),
				Po5Pilot._v(safe_spot)])
			await p.goto(safe_spot, 0.4, 3.0)
			return true
		f.note("civilian %s mode %d meter %.2f at %s: shout" % [c.name, b.mode, st.detection_value(c, crew.slot),
			Po5Pilot._v(c.global_position)])
		await _subdue(c)
		return true
	var dn: NpcBase = _down_soon()
	if dn != null:
		await _reshout(dn)
		return true
	return false


## Before something long (a hunt, a trip outside): renew every intimidation with less than `min_left` s.
func _refresh_downs(min_left: float) -> void:
	for c: NpcBase in _civilians():
		var b: CivilianBrain = _civ_brain(c)
		if b.mode == CivilianBrain.Mode.DOWN and b.intimidate_left < min_left:
			await _reshout(c)


## Renew the intimidation of a downed civilian: get within shout_all_within_m (flat: the all-around shout
## reaches through walls and floors) and shout with nothing interactable in the aim.
func _reshout(c: NpcBase) -> void:
	var b: CivilianBrain = _civ_brain(c)
	if not _hears_here(c):
		var spot: Vector3 = _reshout_spot(c)
		f.note("re-shout %s (%.0f s left) from %s" % [c.name, b.intimidate_left, Po5Pilot._v(spot)])
		await p.goto(spot, 0.5, maxf(b.intimidate_left - 1.0, 2.0))
	await p.face(crew.eye_position() + Vector3(0.0, 4.0, -0.5).rotated(Vector3.UP, crew.look_yaw), 0.1, 0.5)
	await p.inp.tap(&"shout")
	await p.inp.ticks(int(Tweak.stealth().shout_cooldown_s * Engine.physics_ticks_per_second) + 2)
	f.note("re-shout %s -> %.0f s left (mode %d)" % [c.name, b.intimidate_left, b.mode])


## Shout `c` down (aiming at the chest; nothing interactable in the way) and cable-tie them while we
## have ties; otherwise they stay on our list to re-shout.
func _subdue(c: NpcBase) -> String:
	var b: CivilianBrain = _civ_brain(c)
	for i: int in 3:
		if b.mode == CivilianBrain.Mode.DOWN or b.mode == CivilianBrain.Mode.TIED or not c.is_alive():
			break
		await p.face(c.global_position + Vector3(0.0, 1.3, 0.0), 0.04, 1.0)
		await p.inp.tap(&"shout")
		await p.inp.ticks(int(Tweak.stealth().shout_cooldown_s * Engine.physics_ticks_per_second) + 2)
	if b.mode != CivilianBrain.Mode.DOWN:
		return "" if b.mode == CivilianBrain.Mode.TIED else "PO-5.stealth.civilian: %s did not go down (mode %d)" % [c.name, b.mode]
	var stationary: bool = [&"desk_work", &"sit", &"queue", &"phone"].has(StringName(c.spawn_info.get("idle_activity", &"")))
	# Ties go to whoever stays in our way; the rest are kept down by re-shouts (_down_soon).
	# A tied civilian is a `restrained` stimulus (guards radio, cameras alarm, civilians panic): tie only
	# out of sight (workshop, receiving, upstairs rooms); in the corridor / on the floor keep them down.
	var v: Vector3 = c.global_position
	var hidden: bool = v.z < 4.3 or (v.y > 2.0 and (v.z < 4.4 or v.z > 6.1))
	if crew.cable_ties > 0 and hidden and (stationary or crew.cable_ties > 1 or v.z < 6.0):
		var tie: InteractableComponent = c.get_node_or_null(^"TieInteractable") as InteractableComponent
		if tie != null:
			await p.use(tie, 5.0, func() -> bool: return b.mode == CivilianBrain.Mode.TIED)
	if b.mode == CivilianBrain.Mode.DOWN and v.y < 2.0 and v.z < 6.0:
		# Down in the back of house: knife it (silent) rather than babysit a 45 s timer; bag it if it lies in
		# the corridor.
		await p.goto(p.stand_point(c.global_position), 1.1, 6.0, false, false)
		if await _knife(c, 0.0):
			await _bag_if_seen(c)
	if c.is_alive() and b.mode != CivilianBrain.Mode.TIED and not downed.has(c):
		downed.append(c)
	return ""


# --- Actions ----------------------------------------------------------------------------------

func _mask_up() -> bool:
	if crew.masked:
		return true
	await p.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await p.inp.ticks(4)
	f.note("mask_up -> masked=%s at %s" % [crew.masked, Po5Pilot._v(crew.global_position)])
	return crew.masked


## Face the NPC's chest and swing the knife (charged when `charge_s` > 0). True when it died.
func _knife(npc: NpcBase, charge_s: float = 1.05) -> bool:
	var cb: CivilianBrain = _civ_brain(npc) if npc.role == &"civilian" else null
	var low: bool = cb != null and (cb.mode == CivilianBrain.Mode.DOWN or cb.mode == CivilianBrain.Mode.TIED)
	await p.face(npc.global_position + Vector3(0.0, 0.35 if low else 1.1, 0.0), 0.04, 1.0)
	var nd: float = p.flat_dist(npc.global_position, crew.global_position)
	for c: NpcBase in _civilians():
		var to_c: Vector3 = c.global_position - crew.global_position
		var to_n: Vector3 = npc.global_position - crew.global_position
		var in_cone: bool = Vector2(to_c.x, to_c.z).angle_to(Vector2(to_n.x, to_n.z)) < deg_to_rad(30.0)
		if c != npc and in_cone and absf(to_c.y) < 1.2 and p.flat_dist(c.global_position, crew.global_position) < minf(nd + 0.2, 2.2):
			f.note("knife held: civilian %s is in the way of %s" % [c.name, npc.name])
			await f.wait_s(0.3)
			return false
	if charge_s > 0.0:
		await p.inp.hold(&"melee", charge_s)
	else:
		await p.inp.tap(&"melee")
	var t: float = 0.0
	while npc.is_alive() and t < 0.8:
		await p.tick()
		t += p.dt()
	f.note("knife %s -> alive=%s (dist %.2f)" % [npc.name, npc.is_alive(), p.flat_dist(npc.global_position, crew.global_position)])
	return not npc.is_alive()


## Wait for the dead guard's pager to beep, then hold F on the body until it is answered.
func _answer_pager(guard: NpcBase) -> String:
	if answered_guards.has(guard):
		return ""
	var comp: InteractableComponent = null
	var t: float = 0.0
	while t < 6.0:
		comp = guard.get_node_or_null(^"PagerInteractable") as InteractableComponent
		if comp != null and comp.enabled:
			break
		await p.tick()
		t += p.dt()
	if comp == null or not comp.enabled:
		return "PO-5.stealth.pager: no pager to answer on %s after %.1f s" % [guard.name, t]
	f.note("pager on %s beeping after %.1f s; answering" % [guard.name, t])
	var answered: Array[bool] = [false]
	var cb: Callable = func(_pid: int, _s: int, _total: int) -> void: answered[0] = true
	EventBus.pager_answered.connect(cb)
	await p.use(comp, 14.0, func() -> bool: return answered[0])
	EventBus.pager_answered.disconnect(cb)
	if not answered[0]:
		await f.shot("pager_failed")
		return "PO-5.stealth.pager: pager on %s not answered" % guard.name
	answered_guards.append(guard)
	return ""


func _take_keycard() -> String:
	var kc: InteractableComponent = _comp_tagged(&"keycard")
	if kc == null:
		return "PO-5.stealth.keycard: no keycard pickup for %s" % _variant(&"keycard")
	await p.use(kc, 8.0, func() -> bool: return _has_keycard())
	if not _has_keycard():
		await f.shot("keycard_failed")
		return "PO-5.stealth.keycard: could not pick up the %s keycard at %s" % [_variant(&"keycard"),
			Po5Pilot._v(kc.global_position)]
	return ""


## Aim at an open door and press F to swing it shut (no-op when closed or missing).
func _close_door(door: Door) -> void:
	if door == null or not door.is_open:
		return
	var comp: InteractableComponent = door.get_node_or_null(^"Interactable") as InteractableComponent
	if comp == null:
		return
	await p.use(comp, 3.0, func() -> bool: return not door.is_open, false)
	f.note("close %s -> open=%s" % [door.name, door.is_open])


# --- Queries ----------------------------------------------------------------------------------

func _variant(group: StringName) -> StringName:
	var v: Variant = rt.variants.get(group)
	return StringName((v as Array)[0]) if v is Array and not (v as Array).is_empty() else &""


func _has_keycard() -> bool:
	return crew.item_count(&"item.keycard") > 0


func _operator_npc() -> NpcBase:
	for n: Node in rt.npcs(&"guard"):
		var npc: NpcBase = n as NpcBase
		if npc != null and (npc.spawn_info.get("tags", []) as Array).has(&"security_operator"):
			return npc
	return null


func _comp_tagged(tag: StringName) -> InteractableComponent:
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var o: Node = c.owner_node()
		if o != null and o.get(&"objective_tag") == tag and o.is_inside_tree() and c.is_visible_in_tree():
			return c
	return null


func _door_named(door_name: StringName) -> Door:
	for n: Node in f.get_tree().get_nodes_in_group(Door.GROUP):
		if n.name == door_name and rt.is_ancestor_of(n):
			return n as Door
	return null


func _npc_name(net_id: int) -> String:
	var n: Node = Ids.lookup(net_id)
	return String(n.name) if n != null else str(net_id)


func _npc_pos(net_id: int) -> String:
	var n: Node3D = Ids.lookup(net_id) as Node3D
	return Po5Pilot._v(n.global_position) if n != null else "?"


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


func _fail(msg: String) -> int:
	f.note("FAIL " + msg)
	await f.shot("fail")
	return 1
