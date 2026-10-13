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
var _last_meter_note: float = -10.0


func play(flow: Node) -> int:
	f = flow
	p = flow.get(&"pilot") as Po5Pilot
	rt = flow.get(&"rt") as HeistRuntime
	crew = p.crew
	st = rt.stealth
	p.arrive_dy = 1.2
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
			return await fail("%s [step %s]" % [err, step.get_method()])
		f.note("STEP %s done t=%.0f at %s masked=%s pagers=%d" % [step.get_method(), rt.heist_time_s,
			Po5Pilot._v(crew.global_position), crew.masked, pagers_answered])
	return await escape()


# --- Setup / logging --------------------------------------------------------------------------

func _setup() -> void:
	EventBus.alarm_raised.connect(func(reason: StringName, src: int) -> void:
		alarm = reason
		f.note("EVENT alarm_raised %s by %s (t=%.0f) crew at %s" % [reason, _npc_name(src), rt.heist_time_s,
			Po5Pilot._v(crew.global_position)]))
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
	for wp: Vector3 in [Vector3(19.7, 0.0, 14.0), Vector3(19.6, 0.0, 2.6)]:
		if not await p.goto(wp, 0.6, 60.0, false, false):
			return "PO-5.stealth.approach: could not walk the street to %s" % Po5Pilot._v(wp)
	return ""


func _counter_keycard() -> String:
	var kc: InteractableComponent = comp_tagged(&"keycard")
	if not await p.goto(Vector3(11.25, 0.0, 10.8), 0.6, 60.0):
		return "PO-5.stealth.counter: could not walk into the shop"
	# Customer side of the counter, in front of the card (PUBLIC: nobody minds an unmasked customer).
	if not await p.goto(Vector3(3.2, 0.0, 8.15), 0.35, 40.0, false, false):
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
	await close_door(door_named(&"FireExit"))
	if not await p.goto(Vector3(15.3, UPPER_Y, 5.25), 0.6, 60.0):
		await f.shot("stair")
		return "PO-5.stealth.stair: could not reach the upper corridor"
	return ""


## Upstairs keycards are picked up unmasked (RESTRICTED: only guards / cameras notice, slowly).
func _keycard_upstairs() -> String:
	var v: StringName = _variant(&"keycard")
	if v != &"kc_manager" and v != &"kc_breakroom" and not (v == &"kc_security" and _operator_npc() == null):
		return ""
	return await take_keycard()


## The camera operator sits facing the west monitor wall: come in behind him, mask, knife, answer.
func _operator() -> String:
	var op: NpcBase = _operator_npc()
	if op == null:
		f.note("no camera operator (security room empty): cameras stay live")
		return ""
	var behind: Vector3 = op.global_position - _flat(op.look_forward()) * 1.3
	if not await p.goto(behind, 0.35, 60.0):
		await f.shot("operator_unreached")
		return "PO-5.stealth.operator: could not get behind the operator (at %s)" % Po5Pilot._v(op.global_position)
	if not await mask_up():
		return "PO-5.stealth.mask: could not mask up"
	if not await knife(op):
		return "PO-5.stealth.knife: the operator survived the knife"
	return await answer_pager(op)


func _keycard_masked() -> String:
	if _has_keycard() or _variant(&"keycard") != &"kc_security":
		return ""
	return await take_keycard()


## Guards whose patrol reaches where we work (back of house, upstairs, the loot path) die by the knife.
func _guards() -> String:
	if not await mask_up():
		return "PO-5.stealth.mask: could not mask up"
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
		var err: String = await hunt(target, 240.0)
		if err != "":
			return err
	return ""


## Lockpick the workshop door, then put the jeweler down and tie him.
func _workshop() -> String:
	var wdoor: InteractableComponent = comp_tagged(&"workshop_door")
	var door: Door = wdoor.owner_node() as Door
	if not await p.goto(p.stand_point(Vector3(7.5, 0.0, 5.3)), 0.5, 90.0):
		return "PO-5.stealth.workshop: could not reach the workshop door"
	if not door.is_open:
		await p.use(wdoor, 20.0, func() -> bool: return door.is_open)
	if not door.is_open:
		await f.shot("workshop_locked")
		return "PO-5.stealth.workshop: lockpicking the workshop door failed"
	var c5: SecurityCamera = live_camera("C5")
	if c5 != null:
		var err5: String = await smash_camera(c5)
		if err5 != "":
			return err5
	for c: NpcBase in civilians():
		if p.flat_dist(c.global_position, Vector3(7.75, 0.0, 2.25)) < 3.5 and _civ_brain(c).mode != CivilianBrain.Mode.TIED:
			await p.goto(Vector3(7.5, 0.0, 3.6), 0.4, 10.0, false, false)
			var err: String = await subdue(c)
			if err != "":
				return err
	await f.shot("workshop_open")
	return ""


## Keycard reader (or the safe's code when a note was read), then wait for the door to swing.
func _safe() -> String:
	var loot: InteractableComponent = comp_tagged(&"safe_loot")
	if loot != null and loot.enabled:
		return ""
	if not _has_keycard() and KEYCARD_AT.has(_variant(&"keycard")):
		var err: String = await take_keycard()
		if err != "":
			return err
	var reader: InteractableComponent = comp_tagged(&"safe_reader")
	if _has_keycard() and reader != null:
		await p.use(reader, 6.0, func() -> bool: return loot.enabled)
	var t: float = 0.0
	while not loot.enabled and t < 5.0:
		await p.tick()
		t += p.dt()
	if not loot.enabled:
		await f.shot("safe_closed")
		return "PO-5.stealth.safe: the safe did not open (keycard=%s)" % _has_keycard()
	await f.shot("safe_open")
	return ""


## Bag the consignment and carry it to the van, one bag at a time.
func _bags() -> String:
	var loot: InteractableComponent = comp_tagged(&"safe_loot")
	var zone: SecureZone = p.secure_zone()
	if zone == null:
		return "PO-5.stealth.van: no active secure zone"
	f.note("secure zone %s at %s" % [zone.get_path(), Po5Pilot._v(zone.global_position)])
	var c4: SecurityCamera = live_camera("C4")
	if c4 != null and _variant(&"escape") == &"esc_alley_west":
		await to_alley()
		var err4: String = await smash_camera(c4)
		if err4 != "":
			return err4
	var bags: int = 0
	var tries: int = 0
	while bags < 2 and tries < 5:
		tries += 1
		if not crew.is_carrying_bag():
			await p.use(loot, 10.0, func() -> bool: return crew.is_carrying_bag())
		if not crew.is_carrying_bag():
			f.note("could not bag the safe loot (try %d)" % tries)
			continue
		if alarm != &"":
			return "PO-5.stealth.alarm: alarm raised (%s) while bagging" % alarm
		if not inside(zone.global_position):
			await via_fire_exit(true)
			if zone.global_position.z < 0.0:
				await p.goto(Vector3(17.5, 0.0, -2.8), 0.8, 60.0)
		if await p.secure_carried_bag(zone):
			bags += 1
			f.note("bag %d secured t=%.0f" % [bags, rt.heist_time_s])
			if bags == 1:
				await f.shot("bag_1")
		if alarm != &"":
			return "PO-5.stealth.alarm: alarm raised (%s) while carrying" % alarm
		if bags < 2 and not inside(crew.global_position):
			if crew.global_position.z < 0.0:
				await p.goto(Vector3(17.5, 0.0, -2.8), 0.8, 60.0)
			await via_fire_exit(false)
	if bags < 2:
		return "PO-5.stealth.bags: only %d bags secured" % bags
	return ""


func escape() -> int:
	var ended: Array[bool] = [false]
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		ended[0] = true
		f.note("EVENT heist_ended success=%s went_loud=%s %s" % [r.get("success"), rt.went_loud, r]))
	var t0: float = rt.heist_time_s
	while p.active_escape() == null and rt.heist_time_s - t0 < 20.0:
		await f.wait_s(0.5)
	var ez: EscapeZone = p.active_escape()
	if ez == null:
		return await fail("PO-5.stealth.escape: escape never activated after 2 bags")
	f.note("escape active at %s" % Po5Pilot._v(ez.global_position))
	await p.goto(p.stand_point(ez.global_position), 1.0, 120.0)
	var t1: float = rt.heist_time_s
	while not ended[0] and rt.heist_time_s - t1 < 30.0:
		await f.wait_s(0.5)
		if not ended[0] and p.flat_dist(crew.global_position, ez.global_position) > 1.5:
			await p.goto(p.stand_point(ez.global_position), 0.8, 20.0)
	if not ended[0]:
		await f.shot("escape_stuck")
		return await fail("PO-5.stealth.escape: standing in the escape zone did not end the heist")
	if rt.went_loud or alarm != &"":
		return await fail("PO-5.stealth: the heist ended but it went loud (%s)" % alarm)
	f.note("STEALTH WIN: heist ended with no alarm, pagers answered %d" % pagers_answered)
	return await f.payday_to_hub()


# --- Cameras (no operator to kill) -----------------------------------------------------------

func live_camera(cid: String) -> SecurityCamera:
	for c: Node in f.get_tree().get_nodes_in_group(SecurityCamera.GROUP):
		var cam: SecurityCamera = c as SecurityCamera
		if cam != null and cam.name == "Camera" + cid and cam.is_inside_tree() and cam.can_observe():
			return cam
	return null


## G4 corridor camera (C3, east end looking west): stand under it, mask, knife it.
func _corridor_camera() -> String:
	var cam: SecurityCamera = live_camera("C3")
	if cam == null:
		return ""
	return await smash_camera(cam)


## A wall camera is broken with one knife swing from right under its lens (outside its cone).
func smash_camera(cam: SecurityCamera) -> String:
	var fl: float = 0.0 if cam.global_position.y < 4.0 else UPPER_Y
	var mount: Vector3 = Vector3(cam.global_position.x, fl, cam.global_position.z)
	var spot: Vector3 = p.stand_point(mount + _flat(cam.look_forward()) * 0.6)
	f.note("smash %s at %s from %s (fwd %s)" % [cam.name, Po5Pilot._v(cam.global_position), Po5Pilot._v(spot),
		Po5Pilot._v(cam.look_forward())])
	if not await p.goto(spot, 0.3, 90.0):
		return "PO-5.stealth.camera: could not get under %s" % cam.name
	if not await mask_up():
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

static func inside(v: Vector3) -> bool:
	return v.x > 0.0 and v.x < 18.0 and v.z > 0.0 and v.z < 12.0


## Leave or enter the building by the fire exit (G10 <-> Pell St): the back of house stays off the sales
## floor cameras' sightline through the staff door, and the street / alley have no civilians.
func via_fire_exit(to_outside: bool) -> bool:
	if inside(crew.global_position) != to_outside:
		return true
	var pts: Array[Vector3] = [Vector3(17.0, 0.0, 2.6), Vector3(19.6, 0.0, 1.9)]
	if not to_outside:
		pts.reverse()
	for wp: Vector3 in pts:
		if not await p.goto(wp, 0.6, 60.0):
			return false
	return true


## From wherever we are to the alley (outside, by the Pell St mouth).
func to_alley() -> bool:
	if not await via_fire_exit(true):
		return false
	return await p.goto(Vector3(17.5, 0.0, -2.8), 0.8, 60.0)


# --- Guards -----------------------------------------------------------------------------------

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
func hunt(g: NpcBase, timeout_s: float) -> String:
	var gb: GuardBrain = g.get_node_or_null(^"Brain") as GuardBrain
	f.note("hunt %s at %s (state %s)" % [g.name, Po5Pilot._v(g.global_position), gb.state_name()])
	var t0: float = rt.heist_time_s
	if g.global_position.z < 0.0 and inside(crew.global_position):
		await to_alley()
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
		if inside(g.global_position) and g.global_position.z > 6.0 and g.global_position.y < 2.0:
			await f.wait_s(0.5)  # on the sales floor (customers, cameras): wait for him in the back
			continue
		var d: float = p.flat_dist(g.global_position, crew.global_position)
		if d <= 1.45 and absf(g.global_position.y - crew.global_position.y) < 1.0:
			await knife(g, 0.0)
			continue
		var goal: Vector3 = g.global_position - _flat(g.look_forward()) * 0.9
		await p.goto(p.stand_point(goal), 0.6, 0.6)
	p.quiet = false
	f.note("%s down t=%.0f" % [g.name, rt.heist_time_s])
	return await answer_pager(g)


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
			await knife(g, 0.0)
			t += 0.5
			continue
		await p.face(g.head_position() - Vector3(0.0, 0.5, 0.0), 0.05, 0.25)
		await p.tick()
		t += 0.25 + p.dt()


## A guard on the radio about us (no cuffs): knife him within the 2 s call if he is close.
func _radioing(g: NpcBase) -> bool:
	var gb: GuardBrain = g.get_node_or_null(^"Brain") as GuardBrain
	return gb != null and g.is_alive() and gb.radio_time_left > 0.0


# --- Civilians (pilot hook) -------------------------------------------------------------------

func civilians() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for n: Node in rt.npcs(&"civilian"):
		var c: NpcBase = n as NpcBase
		if c != null and c.is_alive() and _civ_brain(c) != null:
			out.append(c)
	return out


func _civ_brain(c: NpcBase) -> CivilianBrain:
	return c.get_node_or_null(^"Brain") as CivilianBrain


## The civilian we must deal with now (masked only): one noticing us, one running to call, or one of
## ours about to get up.
func _civ_threat() -> NpcBase:
	if not crew.masked:
		return null
	var best: NpcBase = null
	var best_d: float = INF
	for c: NpcBase in civilians():
		var b: CivilianBrain = _civ_brain(c)
		var d: float = crew.eye_position().distance_to(c.global_position + Vector3(0.0, 1.0, 0.0))
		if d > 11.0 or absf(c.global_position.y - crew.global_position.y) > 2.0:
			continue
		var want: bool = false
		match b.mode:
			CivilianBrain.Mode.IDLE, CivilianBrain.Mode.WANDER:
				want = st.detection_value(c, crew.slot) > 0.4
			CivilianBrain.Mode.RUN_TO_CALL, CivilianBrain.Mode.CALLING:
				want = true
			CivilianBrain.Mode.DOWN:
				want = b.intimidate_left < 12.0 and d < 6.0
		if want and d < best_d and p.has_los(c.global_position + Vector3(0.0, 1.0, 0.0), c):
			best = c
			best_d = d
	return best


func _hook_need() -> bool:
	if alarm != &"":
		return false
	for n: Node in rt.npcs(&"guard"):
		if _arresting_us(n as NpcBase):
			return true
	return _civ_threat() != null


func _hook() -> bool:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if _arresting_us(g):
			await _await_arrest(g)
			if not g.is_alive():
				await answer_pager(g)
			return true
	var c: NpcBase = _civ_threat()
	if c == null:
		return false
	var b: CivilianBrain = _civ_brain(c)
	f.note("civilian %s mode %d meter %.2f at %s: shout" % [c.name, b.mode, st.detection_value(c, crew.slot),
		Po5Pilot._v(c.global_position)])
	await subdue(c)
	return true


## Shout `c` down (aiming at the chest; nothing interactable in the way) and cable-tie them while we
## have ties; otherwise they stay on our list to re-shout.
func subdue(c: NpcBase) -> String:
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
	if crew.cable_ties > 0 and (stationary or crew.cable_ties > 1):
		var tie: InteractableComponent = c.get_node_or_null(^"TieInteractable") as InteractableComponent
		if tie != null:
			await p.use(tie, 5.0, func() -> bool: return b.mode == CivilianBrain.Mode.TIED)
	if b.mode == CivilianBrain.Mode.DOWN:
		# No tie to spare for a wanderer: it would get up panicked in 45 s. Knife it while it is down.
		await p.goto(p.stand_point(c.global_position), 1.1, 6.0, false, false)
		await p.face(c.global_position + Vector3(0.0, 0.3, 0.0), 0.05, 1.0)
		await p.inp.tap(&"melee")
		await p.inp.ticks(int(0.7 * Engine.physics_ticks_per_second))
		if c.is_alive():
			await knife(c, 0.0)
		f.note("civilian %s knifed while down -> alive=%s" % [c.name, c.is_alive()])
	if c.is_alive() and b.mode != CivilianBrain.Mode.TIED and not downed.has(c):
		downed.append(c)
	return ""


# --- Actions ----------------------------------------------------------------------------------

func mask_up() -> bool:
	if crew.masked:
		return true
	await p.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await p.inp.ticks(4)
	f.note("mask_up -> masked=%s at %s" % [crew.masked, Po5Pilot._v(crew.global_position)])
	return crew.masked


## Face the NPC's chest and swing the knife (charged when `charge_s` > 0). True when it died.
func knife(npc: NpcBase, charge_s: float = 1.05) -> bool:
	await p.face(npc.global_position + Vector3(0.0, 1.1, 0.0), 0.04, 1.0)
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
func answer_pager(guard: NpcBase) -> String:
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
	return ""


func take_keycard() -> String:
	var kc: InteractableComponent = comp_tagged(&"keycard")
	if kc == null:
		return "PO-5.stealth.keycard: no keycard pickup for %s" % _variant(&"keycard")
	await p.use(kc, 8.0, func() -> bool: return _has_keycard())
	if not _has_keycard():
		await f.shot("keycard_failed")
		return "PO-5.stealth.keycard: could not pick up the %s keycard at %s" % [_variant(&"keycard"),
			Po5Pilot._v(kc.global_position)]
	return ""


## Aim at an open door and press F to swing it shut (no-op when closed or missing).
func close_door(door: Door) -> void:
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


func comp_tagged(tag: StringName) -> InteractableComponent:
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var o: Node = c.owner_node()
		if o != null and o.get(&"objective_tag") == tag and o.is_inside_tree() and c.is_visible_in_tree():
			return c
	return null


func door_named(door_name: StringName) -> Door:
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


func fail(msg: String) -> int:
	f.note("FAIL " + msg)
	await f.shot("fail")
	return 1
