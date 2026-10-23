## PO-5 generic LOUD run for any heist: plays like a player who reads the HUD. It masks up, goes loud,
## then follows LocalHudModel.objective_markers (ui_hud 1.8): walks to the first marked objective, uses
## what is usable there (doors, drills, keypads, bags), defends while devices run (fixing jams), carries
## bags to a marked secure zone, and stands in the escape zone. Input only (Po5Pilot).
## Reports objectives that have no marker or nothing usable as findings (objective guidance gaps).
extends RefCounted

## A marker's prefab (its UsePoint is where to stand) lies within this of the marker.
## _doctor_bag: no enemy within this (m) to stop and heal; walk at most this far to a placed bag (m).
const DOCTOR_SAFE_M: float = 8.0
const DOCTOR_WALK_M: float = 40.0
const MARKER_PREFAB_M: float = 1.5
## Default heist-time cap of the loud loop (s); --po5-heist-cap=<s> overrides it (LEAD GPU-20b: OF Cataclysm reached
## escape_wait at t=1471 and the old 1500 s cap cut it 29 s later).
const LOOP_LIMIT_S: float = 2400.0
## Downed teammates within this flat distance get revived first (m).
const REVIVE_RANGE_M: float = 20.0
## An enemy the pilot can see within this range makes it fight before reviving (unless last stand) (m).
const REVIVE_THREAT_M: float = 25.0
## A loud player opens, drills or uses a keycard before picking a lock: lockpick ranks this much farther (m).
const LOCKPICK_PENALTY_M: float = 2.0
## Carrying a bag: an enemy in sight within this range makes the pilot put it down and clear the way (m).
const CLEAR_RANGE_M: float = 20.0
## Longest fight before picking the bag back up anyway, and the walk leg between threat checks (s).
const CLEAR_LIMIT_S: float = 40.0
const CARRY_LEG_S: float = 4.0
## _escort_mate_bag: close enough to the secure zone's stand to lead a carrying bot (it secures within its
## secure_seek_radius_m); the nav path ends at the van's rear corner, 3.25 m out (GPU-19 (c), no map snag).
const ESCORT_ARRIVE_M: float = 3.5
## _lift_bag: a hoist landing this close (m, on the crew's floor) takes a bag the route would carry up a ladder; failed
## tries in a row before the pilot gives up on the hoist.
const LIFT_NEAR_M: float = 15.0
const LIFT_TRIES_MAX: int = 6
## _is_unreachable: a target set aside for "no navmesh path" has its path re-tested this often (s).
const UNREACH_RECHECK_S: float = 10.0
## _deliver_tool: a burn point this close (m) to a marker is that marker's (RT: a truck's rear-door burn point, ~4 m
## from the truck marker at its origin).
const TRUCK_BURN_M: float = 6.0
## _open_gate_toward: a padlock this close (m) to where a short navmesh path ends is the gate in the way.
const GATE_LOCK_M: float = 10.0
## _open_gate_toward: longest stay at a gate whose device runs (a saw through a padlock with jams) (heist s).
const GATE_WAIT_S: float = 150.0
## Give up carrying one bag to the van after this long (s).
const CARRY_LIMIT_S: float = 300.0

## Objectives completed by walking near the marker (no interaction).
const AREA_OBJECTIVES: Array[StringName] = [&"find_canvases"]
## Objectives that unblock the others (GN loud hack: shutters up, vault doors open), tried first when marked.
const FIRST_OBJECTIVES: Array[StringName] = [&"hack"]
## A marker with nothing usable for this long (s) yields to the other active markers.
const STALL_SKIP_S: float = 30.0
## A code keypad ranks this much nearer than a drill / saw at the same spot: entering a known code is instant (m).
const CODE_BONUS_M: float = 2.0
## Pseudo objective: work on the door that blocks a FIRST_OBJECTIVES marker (GN loud: the coded ServerDoor in front
## of the Argus terminal: its keypad once the code is read, else its drill).
const UNBLOCK_ID: StringName = &"_unblock"
## Dockside Burn: the objective whose marker is the burn point (`place_thermite`, needs the thermite TOOL bag).
const BURN_ID: StringName = &"burn"
## Failed pick-ups of one loose bag before the pilot leaves it.
const BAG_FAIL_LIMIT: int = 3
## Longest the pilot leads one teammate-carried bag to the secure zone (s; CrewAiBrain secures within its
## secure_seek_radius_m of a known zone, following the leader).
const ESCORT_LIMIT_S: float = 120.0
## Lead (P's GN loud rerun on 04f79b18: 1200 s at the open BronzeDoorsE leaf): a target whose walk failed this many
## times in a row although a navmesh path exists (a body in the way, not a door) is set aside for WALK_SKIP_S of
## heist time, so the other markers go first; it comes back after.
const WALK_FAIL_LIMIT: int = 3
const WALK_SKIP_S: float = 90.0
## A walk with this many stuck recoveries and no progress gives up (Po5Pilot.stuck_give_up) and counts as a failed walk
## (P's GN loud rerun: STUCK x4 on the BronzeDoorsE LeafBody2 at (22.3, 30.0), then 1200 s on the same leg).
const STUCK_GIVE_UP: int = 6

var f: Node = null
var p: Po5Pilot = null
var rt: HeistRuntime = null
## --po5-doctor-bag: the pilot carries and uses a doctor bag (see _doctor_bag).
var doctor_bag: bool = "--po5-doctor-bag" in OS.get_cmdline_user_args()
## --po5-focus=<objective id> (LEAD OF-done: verify BondSafe): once that objective's marker is up, the pilot takes it
## before anything else that is up (see _is_focus).
var focus: StringName = _focus_arg()
## --po5-wait-convoy (RT P5 gate, LEAD): stay unmasked at the start until the convoy has stopped ([convoy] done), then
## go loud: the crash stop without the early alarm (police after police_delay_s, not at once).
var wait_convoy: bool = "--po5-wait-convoy" in OS.get_cmdline_user_args()
var _lift_tries: int = 0
## _is_unreachable: heist time of the last path re-test per "no navmesh path" target.
var _unreach_checked: Dictionary[int, float] = {}
var _ended: bool = false
var _stalls: Dictionary[StringName, float] = {}
var _bot_note_t: float = -INF
## GN probe 3 (handoff §A1): interactables the pilot failed to reach (instance id -> the closed door that stopped
## the walk, or null when the navmesh has no path), skipped for the run, or until that door is passable again (GN
## loud: the Calloway canvas behind the lockdown-BARRED shutter comes back once the hack lifts it).
var _unreachable: Dictionary[int, Door] = {}
## Markers whose walk was stopped by a door the crew cannot open (`_marker_key` -> that door): they yield like a
## stalled marker until the door is passable. Per marker, not per objective ([canvases] has one per slot).
var _marker_blocked: Dictionary[String, Door] = {}
## Failed pick-ups per loose bag (instance id); BAG_FAIL_LIMIT of them skip that bag for the run.
var _bag_fails: Dictionary[int, int] = {}
## Seconds spent leading each teammate-carried bag (bag instance id) to the secure zone.
var _escort_s: Dictionary[int, float] = {}
## Failed walks in a row per interactable (instance id) with a path and no blocking door, and the heist time until
## which such a target is set aside.
var _walk_fails: Dictionary[int, int] = {}
var _skip_until: Dictionary[int, float] = {}


func play(flow: Node) -> int:
	f = flow
	p = flow.get(&"pilot") as Po5Pilot
	rt = flow.get(&"rt") as HeistRuntime
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		_ended = true
		f.note("EVENT heist_ended %s" % [r]))
	EventBus.interaction_cancelled.connect(_note_bot_interaction.bind(&"cancelled"))
	EventBus.interaction_started.connect(func(nid: int, slot: int, _k: StringName) -> void:
		_note_bot_interaction(nid, slot, &"started"))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		if is_instance_valid(rt):
			f.note("EVENT objective %s -> %d t=%.0f" % [id, st, rt.heist_time_s]))
	EventBus.loot_secured.connect(func(_b: int, l: StringName, v: int) -> void:
		if is_instance_valid(rt):
			f.note("EVENT loot_secured %s %d t=%.0f" % [l, v, rt.heist_time_s]))
	# RT-A6 "every VO line said": the lines a run plays, for the coverage over seeds (grep "EVENT vo ").
	EventBus.voice_line_requested.connect(func(speaker: StringName, line_id: StringName, _c: Dictionary) -> void:
		if is_instance_valid(rt):  # the payday / hub plays lines after the runtime is freed
			f.note("EVENT vo %s %s t=%.0f" % [speaker, line_id, rt.heist_time_s]))
	if doctor_bag:
		var ds: DeployableSystem = rt.service(DeployableSystem.SERVICE) as DeployableSystem
		if ds != null:
			ds.give(p.crew.slot, &"deployable.doctor_bag")
			f.note("harness: doctor bag in the pilot's deployable slot (%d)" % ds.deployable_count(p.crew.slot))
	if wait_convoy:
		await _wait_for_the_convoy()
	if not p.crew.masked:  # stores1001: masked, G throws the carried bag (rt_clean hands over masked with the thermite)
		await p.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	p.combat = true
	p.stuck_give_up = STUCK_GIVE_UP
	# GN probe 6: the pilot walked past three downed teammates on its way to the vault drill (t=275-288), then went
	# down itself with nobody left to revive it. A player turns to a downed teammate in range mid-walk / mid-hold.
	p.hook_need = func() -> bool: return _downed_mate() != null
	p.hook = _revive_teammate
	await p.face(p.crew.eye_position() + Vector3(0, 3, -5))
	for _i: int in 3:
		await p.inp.tap(&"fire")
		await p.inp.ticks(10)
	await f.wait_s(2.0)
	f.note("loud: phase=%d went_loud=%s" % [rt.phase, rt.went_loud])
	var t0: float = rt.heist_time_s
	var last_shot: float = -100.0
	var cap: float = _heist_cap_arg()
	while not _ended and rt.heist_time_s - t0 < cap:
		if p.crew.crew_state == Enums.CrewState.CUSTODY:
			return fail("player in custody at %.0f s" % rt.heist_time_s)
		if p.crew.crew_state != Enums.CrewState.NORMAL:
			await _act_while_down()  # shoot from the floor: police only cuff a downed player who isn't firing
			continue
		if rt.heist_time_s - last_shot > 90.0:
			last_shot = rt.heist_time_s
			await f.shot("auto_%d" % int(rt.heist_time_s))
		await step()
	if not _ended:
		return fail("no heist end within %.0f s; markers %s" % [cap, _marker_summary()])
	return await f.payday_to_hub()


## --po5-wait-convoy: unmasked, in place, until the convoy has stopped (RT _stop_done) or the crash's alarm is up
## (ETA 150-210 s; at most 300).
func _wait_for_the_convoy() -> void:
	f.note("harness: waiting unmasked for the convoy (--po5-wait-convoy)")
	var t0: float = rt.heist_time_s
	# The crash itself is the alarm (the mixer's impact raises the ambush): mask the moment it is loud, too.
	# [convoy] completes on the convoy's arrival, a few seconds BEFORE the stop resolves: masking then let a guard
	# radio the alarm first (RT Hazardous WAIT_CONVOY 1001-1003, all guard_radio). Wait for the stop itself.
	var m: RollingThunderMission = rt.mission as RollingThunderMission
	while rt.mission != null and not (m._stop_done if m != null else
			rt.mission.objective_state(&"convoy") == Enums.ObjectiveState.COMPLETED) \
			and not rt.went_loud and rt.heist_time_s - t0 < 300.0:
		await f.wait_s(1.0)
	f.note("the convoy stopped (%s) or the crash raised the alarm at %.0f s: going loud" % [
		m.layout_id if m != null else "", rt.heist_time_s])


## One decision: the first marked active objective (HUD order).
func step() -> void:
	var markers: Array[Dictionary] = rt.hud_model.objective_markers
	if markers.is_empty():
		_note_once(&"_none", "no objective markers (HUD shows %s)" % [_objective_ids()])
		await p.hold_position(2.0)
		return
	if await _revive_teammate() or await _doctor_bag() or await _unload_lift():
		return
	var m: Dictionary = _pick(markers)
	var id: StringName = StringName(m["id"])
	var pos: Vector3 = m["position"]
	if await _bag_work(markers, id, pos):
		return
	if await _to_the_ride(id, pos):
		return
	var zone: SecureZone = p.secure_zone()
	if zone != null and zone.global_position.distance_to(pos) < 3.0:
		if not await _fetch_bag():
			await p.hold_position(3.0)
		return
	var comp: InteractableComponent = _usable_near(pos, 2.5)
	if comp == null:
		comp = _usable_on_prefab_at(pos)
	if comp != null:
		if id == UNBLOCK_ID:
			_stalls[id] = float(_stalls.get(id, 0.0))  # started: keep defending its drill after this (see _pick)
		p.watch_point = Vector3.INF
		await p.use(comp, 30.0, func() -> bool: return not comp.enabled or comp.availability(p.crew) != &"")
		if is_instance_valid(comp) and comp.enabled and comp.availability(p.crew) == &"" \
				and not await _open_lock_near(comp.global_position, true):
			_mark_if_unreached(comp)  # still usable and still far: the walk failed (GN Slot_orchard_calloway)
		return
	# Nothing to do at the marker right now (a device running, a timer): go there and defend.
	if p.near(p.crew.global_position, pos, 4.0) or not await _walk_to_marker(m, id, pos):
		_stalls[id] = _stalls.get(id, 0.0) + 3.0
		if int(_stalls[id]) % 60 == 0:
			f.note("waiting at %s for %.0f s (nothing usable within 2.5 m)" % [id, _stalls[id]])
		await p.hold_position(3.0)


## Walk to marker `m`. True when the walk failed and a padlocked gate on the way was worked instead (RT-A6); a failed
## walk otherwise yields the marker (findings as before).
func _walk_to_marker(m: Dictionary, id: StringName, pos: Vector3) -> bool:
	# C (DB seed 2): an objective that ended during the walk (burn done -> its shutters barred) is no finding.
	if await p.goto(_marker_stand(pos), 2.5, 60.0) or not _marked(id):
		return false
	if await _open_gate_toward(_marker_stand(pos)):
		return true  # RT-A6 (LEAD): the padlocked site gate first, then the marker behind it
	_note_once(id, "objective %s: marker at %s not reachable" % [id, Po5Pilot._v(pos)])
	if p.last_blocked_door != null:
		_marker_blocked[_marker_key(m)] = p.last_blocked_door  # GN probe 6: behind the BARRED shutter -> yield at once
	elif not _has_path(_marker_stand(pos)) or p.last_goto_stuck:
		_stalls[id] = maxf(float(_stalls.get(id, 0.0)), STALL_SKIP_S)  # GN probe 4: no path -> yield at once
	return false


## RT-A6 (LEAD: the pilot opens padlocks, so auto_loud raids RT's site stores): the navmesh path to `stand` ends short
## (a padlocked gate: its door is off the crew's nav while locked), or runs through a shut locked door with a padlock
## (the magazine). The nearest padlock within GATE_LOCK_M of where the path ends (or that door's own padlock) that the
## pilot can work now (lockpick / saw / C4, Padlock picks the method) is used; the gate opens with it. True when it
## worked one (the next step retries the marker).
func _open_gate_toward(stand: Vector3) -> bool:
	var path: PackedVector3Array = p.nav_path(stand)
	if path.is_empty():
		return false
	var end: Vector3 = path[path.size() - 1]
	var door: Door = null
	if end.distance_to(stand) <= 1.5:
		# pad1002b: the path runs through a shut, padlocked door (the RT magazine: the walk stuck on its wall)
		door = _locked_on_path(stand)
		if door == null:
			return false
		end = door.global_position
	return await _work_lock(_lock_near(end, door, false), "where the path to %s ends" % Po5Pilot._v(stand))


## pad1002c: a target behind a shut padlocked door whose use stand snapped outside its wall (the RT magazine's C4
## boxes): the use failed on the wall. That door's padlock (within GATE_LOCK_M of the target) is worked. True when one was.
func _open_lock_near(pos: Vector3, door_only: bool) -> bool:
	return await _work_lock(_lock_near(pos, null, door_only), "the target at %s" % Po5Pilot._v(pos))


## The nearest workable padlock within GATE_LOCK_M of `pos` (of `door` when given; on a shut door when `door_only`).
func _lock_near(pos: Vector3, door: Door, door_only: bool) -> InteractableComponent:
	var best: InteractableComponent = null
	var best_d: float = GATE_LOCK_M
	for n: Node in rt.map.find_children("*", "Padlock", true, false):
		var lock: Padlock = n as Padlock
		if lock.opened or lock.interactable == null or not lock.interactable.enabled \
				or lock.interactable.availability(p.crew) != &"" or _is_unreachable(lock.interactable):
			continue
		if door != null and not door.is_ancestor_of(lock):
			continue
		var host: Door = lock.get_parent() as Door
		if door_only and (host == null or host.is_open):
			continue
		var d: float = lock.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = lock.interactable
	return best


## Work padlock `best` (null: false): use it, then stay with a placed saw / drill (defend, fix jams) until it is off.
func _work_lock(best: InteractableComponent, why: String) -> bool:
	if best == null:
		return false
	f.note("gate: %s near %s: opening it" % [best.owner_node().get_path(), why])
	p.watch_point = Vector3.INF
	var lock: Padlock = best.owner_node() as Padlock
	var t0: float = rt.heist_time_s
	# A placed saw / drill runs on: stay at the gate, defend it, fix its jams (pad1002: the saw jammed, the pilot had
	# walked off) until the lock is off.
	while is_instance_valid(lock) and not lock.opened and rt.heist_time_s - t0 < GATE_WAIT_S and not _ended:
		if best.enabled and best.availability(p.crew) == &"":
			await p.use(best, 45.0, func() -> bool: return lock.opened or best.availability(p.crew) != &"")
			if is_instance_valid(lock) and not lock.opened and best.availability(p.crew) == &"":
				_mark_if_unreached(best)  # nothing placed: the walk or the hold failed
				break
		else:
			await p.hold_position(3.0, func() -> bool: return lock.opened or _ended)
	if is_instance_valid(lock) and lock.opened:
		f.note("gate: %s open at %.0f s" % [lock.get_path(), rt.heist_time_s])
	return true


## Bags first: the thermite (a tool) goes to the burn point (DB), a [burn] marker without it fetches it, a carried
## loot bag goes to the van, a teammate's bag is led there. True when it acted.
func _bag_work(markers: Array[Dictionary], id: StringName, pos: Vector3) -> bool:
	if _carrying_tool():
		await _deliver_tool(markers)  # P's DB pass: the thermite bag went into the van as loot
		return true
	if id == BURN_ID and await _fetch_thermite(pos):
		return true
	if await _fetch_owed_tool():
		return true
	if p.crew.is_carrying_bag() or await _escort_mate_bag():
		if p.crew.is_carrying_bag():
			await _secure_bag()
		return true
	return false


## The escape marker: stand in the open escape zone. GN-8: `escape_wait` (required loot in, the ride is coming): walk to
## the escape and hold there, fighting from it, instead of the optional extras. True when it acted.
func _to_the_ride(id: StringName, pos: Vector3) -> bool:
	var esc: EscapeZone = p.active_escape()
	if esc != null and id == &"escape":
		await p.goto(p.stand_point(esc.global_position), 1.0, 60.0)
	elif id == &"escape_wait":
		if not p.near(p.crew.global_position, pos, 4.0):
			await p.goto(_marker_stand(pos), 2.5, 30.0)
	else:
		return false
	await p.hold_position(3.0, func() -> bool: return _ended)
	return true


## An open escape goes first (the ride only comes once the required objectives are done; GN probe 7 looped on the
## optional extras / lockers behind the art store vault door instead). Otherwise prefer objectives that are not the
## generic secure/escape when something else is still active. Walk-near (area)
## objectives (GN find_canvases) and markers that stalled STALL_SKIP_S with nothing usable come last, so the
## flow moves on to what it can act on (GN probe: stuck at a found, already cut canvas).
func _pick(markers: Array[Dictionary]) -> Dictionary:
	for me: Dictionary in markers:  # GN probe 7: the ride is here (required loot secured): leave, skip the extras
		# GN-8 (windowed seed 4242): the ride is on its way (escape_wait): wait and defend at the escape too; the
		# pilot went for the optional basement lockers and was downed and cuffed in Stair SS as the van arrived.
		if StringName(me["id"]) in [&"escape", &"escape_wait"] \
				or (StringName(me["id"]) == &"secure" and _loose_bag() != null) or _is_focus(me):
			return me  # probe 8: a dropped bag (put down to clear the way) is carried in before anything optional
	for m0: Dictionary in markers:  # GN probe 4: the loud hack lifts every shutter (Calloway), so it goes first
		if StringName(m0["id"]) in FIRST_OBJECTIVES and not _marker_blocked.has(_marker_key(m0)):
			# P's GN-P1 rerun (a): the navmesh runs through the closed CODE ServerDoor, so a path alone said "go" and
			# the pilot pressed the Argus terminal through the wall for 9 min. Check the doors on that path first.
			var on_path: Door = _path_blocker(p.stand_point(m0["position"] as Vector3))
			if on_path == null:  # D-122: a shut LOCKED door (the CODE ServerDoor, its drill running) blocks the crew
				on_path = _locked_on_path(p.stand_point(m0["position"] as Vector3))
			if on_path != null:
				_marker_blocked[_marker_key(m0)] = on_path
				f.note("marker %s: %s on the way cannot be opened now" % [_marker_key(m0), on_path.name])
		var gate: Door = _marker_blocked.get(_marker_key(m0)) as Door
		if StringName(m0["id"]) in FIRST_OBJECTIVES and _is_marker_blocked(m0) \
				and float(_stalls.get(UNBLOCK_ID, 0.0)) < STALL_SKIP_S * 4.0 \
				and (_stalls.has(UNBLOCK_ID) or _usable_near(gate.global_position, 2.5) != null):
			# GN probe 6: open the door in front of it first (then defend its drill there, up to 4 x STALL_SKIP_S)
			return {"id": UNBLOCK_ID, "position": gate.global_position}
		if StringName(m0["id"]) in FIRST_OBJECTIVES and not _stalled(m0) and not _is_marker_blocked(m0) \
				and _has_path(p.stand_point(m0["position"] as Vector3)):  # probe 5: the Argus terminal sits behind
			return m0  # the coded ServerDoor; only first when reachable
	for m: Dictionary in markers:
		var mid: StringName = StringName(m["id"])
		if not (mid in [&"secure", &"escape", &"casing"] or mid in AREA_OBJECTIVES) \
				and not _stalled(m) and not _is_marker_blocked(m) and not _blocked_on_path(m):
			return m
	return _fallback_marker(markers)


## _pick's last resort: a marker that is not stalled (hoist5: 9 min "waiting at deposit_boxes", the gold untouched), else
## `secure` (bags still to secure: _fetch_bag finds a loose one or a bag_loot source, the opened gold cage), else the first.
func _fallback_marker(markers: Array[Dictionary]) -> Dictionary:
	for m1: Dictionary in markers:
		if not (StringName(m1["id"]) in [&"secure", &"escape", &"casing"]) and not _stalled(m1):
			return m1
	for ms: Dictionary in markers:
		if StringName(ms["id"]) == &"secure":
			return ms
	return markers[0]


## Enabled interactables within `radius` of the marker the player can use now (not revive / tie / pager / body bags).
## Where to stand for a marker: the UsePoint of the nearest prefab within MARKER_PREFAB_M (enabled or not; e.g. a
## wall-mounted GN Locker whose marker sits on the wall 0.9 m up, ENV C), else the navmesh point nearest the marker
## (which for a wall marker can snap to the far side of the wall and read "not reachable").
func _marker_stand(pos: Vector3) -> Vector3:
	var best: InteractableComponent = null
	var best_d: float = MARKER_PREFAB_M
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not rt.is_ancestor_of(c) or c.owner_node() is Door:
			continue
		var d: float = c.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = c
	return p._use_stand(best) if best != null else p.stand_point(pos)


func _usable_near(pos: Vector3, radius: float) -> InteractableComponent:
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c):
			continue
		if c.kind in [&"revive", &"cable_tie", &"answer_pager", &"uncuff", &"break_window", &"break_glass", &"take_loot", &"bag_body",
				&"call_lift", &"send_lift"]:
			continue  # lifts: empty-handed here (bags go first); OF Cata 1037 called the vault hoist for 450 s at a box wall
		if c.availability(p.crew) != &"" or _is_unreachable(c):
			continue
		if _is_body_bag(c) or _is_tool_source(c):
			continue  # thermite: [burn] only. ND attempt 11: a body bag by the drill marker sent the pilot up the stairs mid-wave
		var door: Door = c.owner_node() as Door
		if door != null and door.is_open:
			continue  # using an open door closes it (ND: the pilot toggled the vault gate while drilling)
		var dd: float = c.global_position.distance_to(pos)
		if dd > radius:
			continue
		if c.kind == &"lockpick":
			dd += LOCKPICK_PENALTY_M  # ND attempt 15: two 30 s lockpick timeouts on a door it could simply open
		elif c.kind == &"enter_code":
			dd -= CODE_BONUS_M  # GN probe 6: the ServerDoor keypad (code read) beats its 60 s drill
		if dd < best_d:
			best = c
			best_d = dd
	return best


## RT G1 pilot: a marker on a large prefab (an armored_truck: the marker is its origin, the lock 3.8 m back at the rear
## doors) has its interactable beyond _usable_near's 2.5 m. The usable interactable of the prefab standing on `pos`.
func _usable_on_prefab_at(pos: Vector3) -> InteractableComponent:
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c):
			continue
		var o: Node3D = c.owner_node() as Node3D
		if o is GameplayPrefab and o.global_position.distance_to(pos) < 0.2 and c.availability(p.crew) == &"" \
				and not _is_unreachable(c):
			return c
	return null


## The revive interactable of the nearest downed teammate within REVIVE_RANGE_M the pilot can use, else null.
func _downed_mate() -> InteractableComponent:
	if p.crew.crew_state != Enums.CrewState.NORMAL:
		return null
	var best: InteractableComponent = null
	var best_d: float = REVIVE_RANGE_M
	for c: CrewController in rt.crew_members():
		if c == p.crew or c.crew_state != Enums.CrewState.DOWNED:
			continue
		var rev: InteractableComponent = c.get_node_or_null(^"ReviveInteractable") as InteractableComponent
		if rev == null or not rev.enabled or rev.availability(p.crew) != &"":
			continue
		var dd: float = p.flat_dist(p.crew.global_position, c.global_position)
		if dd < best_d:
			best = rev
			best_d = dd
	return best


## Like a PD2 player (L2.7): pick up a downed teammate within REVIVE_RANGE_M before anything else, but only when no
## enemy in sight of the pilot (else it fights first) or when it is the last one standing. True when it acted.
## Also the pilot's hook (p.hook): goto() / use() hand over to it whenever a teammate goes down in range.
func _revive_teammate() -> bool:
	var best: InteractableComponent = _downed_mate()
	if best == null:
		return false
	var best_d: float = p.flat_dist(p.crew.global_position, best.global_position)
	var mate: CrewController = best.get_parent() as CrewController
	var last_stand: bool = _last_standing()
	var foe: NpcBase = p.nearest_enemy(REVIVE_THREAT_M)
	if foe != null and not last_stand:
		await p.engage(foe, 1.5)  # clear the line of fire before kneeling
		return true
	f.note("revive slot %d at %.0f s (%.1f m%s)" % [mate.slot, rt.heist_time_s, best_d, ", last stand" if last_stand else ""])
	p.watch_point = Vector3.INF
	await p.use(best, 20.0, func() -> bool:
		return not is_instance_valid(mate) or mate.crew_state != Enums.CrewState.DOWNED \
			or (not last_stand and p.nearest_enemy(REVIVE_THREAT_M) != null))
	return true


## True when no other crew member is still up (everyone else downed or worse).
func _last_standing() -> bool:
	for c: CrewController in rt.crew_members():
		if c != p.crew and c.crew_state == Enums.CrewState.NORMAL:
			return false
	return true


## A bag source: a loose bag on the floor, else an enabled bag_loot spawn (closest).
func _fetch_bag() -> bool:
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c) or not (c.kind in [&"bag_loot", &"pick_bag"]):
			continue
		if c.availability(p.crew) != &"" or _is_body_bag(c) or _is_unreachable(c) or _is_tool_source(c):
			continue  # P's DB pass: the thermite bag went into the van as loot (a tool, D-068)
		var o: Node = c.owner_node()
		if o is Node3D and p.secure_zone() != null and (o as Node3D).global_position.distance_to(p.secure_zone().global_position) < 4.0:
			continue  # already in the van
		var dd: float = c.global_position.distance_to(p.crew.global_position)
		if dd < best_d:
			best = c
			best_d = dd
	if best == null:
		_note_once(&"_nobag", "secure is the only marked objective but no bag source is usable")
		return false
	await p.use(best, 20.0, func() -> bool: return p.crew.is_carrying_bag())
	_mark_if_unreached(best)
	if not p.crew.is_carrying_bag() and is_instance_valid(best) and best.kind == &"pick_bag":
		var key: int = best.get_instance_id()
		_bag_fails[key] = _bag_fails.get(key, 0) + 1
		if _bag_fails[key] >= BAG_FAIL_LIMIT:
			_unreachable[key] = null
			f.note("skipping bag %s for this run (%d failed pick-ups)" % [best.get_path(), _bag_fails[key]])
	return p.crew.is_carrying_bag()


## GN probe 9: a bot picked up the canvas the pilot had put down to fight (PO6-14 fetch), then followed the pilot
## around the optional extras: AI crew secure only near a zone they are led to. Like a player whose teammate holds
## the bag: lead the way to the secure zone and wait there a moment. True when it acted.
func _escort_mate_bag() -> bool:
	var zone: SecureZone = p.secure_zone()
	if zone == null:
		return false
	for c: CrewController in rt.crew_members():
		if c == p.crew or c.crew_state != Enums.CrewState.NORMAL or not c.is_carrying_bag():
			continue
		var bag: LootBag = c.carried_bag as LootBag
		if bag == null or bag.is_body_bag() or LootManager.is_tool_loot(bag.loot_id):
			continue
		var key: int = bag.get_instance_id()
		if float(_escort_s.get(key, 0.0)) >= ESCORT_LIMIT_S:
			continue
		var t0: float = rt.heist_time_s
		var stand: Vector3 = p.stand_point(zone.global_position)
		if not p.near(p.crew.global_position, stand, ESCORT_ARRIVE_M):
			_note_once(StringName("_escort_%d" % key), "slot %d carries %s: leading it to the secure zone" % [c.slot, bag.loot_id])
			p.quiet = true  # LEAD GPU-19 (c): "goto (3.5, 0.2, -4.3) FAILED at (4.6, 0.0, -1.2)" x5 was this leg ending
			await p.goto(stand, ESCORT_ARRIVE_M, 10.0)  # 3.25 m out at the van's rear corner, the bots crowding in
			p.quiet = false
		else:
			await p.hold_position(3.0)
		_escort_s[key] = float(_escort_s.get(key, 0.0)) + maxf(rt.heist_time_s - t0, 1.0)
		return true
	return false


## A loot bag lying loose (dropped, not a body bag, not already in the secure zone) the pilot can pick up, else null.
func _loose_bag() -> InteractableComponent:
	if p.crew.is_carrying_bag():
		return null
	var zone: SecureZone = p.secure_zone()
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or c.kind != &"pick_bag" or not c.enabled or not rt.is_ancestor_of(c) or _is_body_bag(c) \
				or _is_tool_source(c):
			continue
		if c.availability(p.crew) != &"" or _is_unreachable(c):
			continue
		if zone != null and c.global_position.distance_to(zone.global_position) < 4.0:
			continue
		return c
	return null


## A marker that waited STALL_SKIP_S with nothing usable, while that is still so. Something usable there again (GN
## probe 7: the Argus hack interrupted, `restart_hack`) clears the stall, so the pilot goes back to it.
func _stalled(m: Dictionary) -> bool:
	var id: StringName = StringName(m["id"])
	if float(_stalls.get(id, 0.0)) < STALL_SKIP_S:
		return false
	if _usable_near(m["position"] as Vector3, 2.5) == null and _usable_on_prefab_at(m["position"] as Vector3) == null:
		return true  # RT G1: a truck's jammed saw is fixed at its lock, 3.8 m from the truck's marker
	_stalls[id] = 0.0
	f.note("marker %s: usable again, back to it" % _marker_key(m))
	return false


## The first closed door on the navmesh path from the pilot to `to` the crew cannot open now, else null. Every Door
## of the map counts (Door.GROUP), not only the ones with an interactable: a lockdown shutter or a BARRED / VAULT leaf
## offers no usable prompt (P's GN loud rerun sat 80 s+ pushing into a closed leaf with no prompt). The GN navmesh is
## baked through every doorway (heist_map.md §3), so a path alone says nothing.
func _path_blocker(to: Vector3) -> Door:
	var path: PackedVector3Array = p.nav_path(to)
	if path.size() < 2:
		return null
	var best: Door = null
	var best_i: int = path.size()
	for n: Node in f.get_tree().get_nodes_in_group(Door.GROUP):
		var door: Door = n as Door
		if door == null or not rt.is_ancestor_of(door) or _passable(door):
			continue
		for i: int in range(1, mini(path.size(), best_i)):
			# Legs are lifted 0.5 m: navmesh points sit on the floor, doorway_crossing wants the opening's height.
			if door.doorway_crossing(path[i - 1] + Vector3.UP * 0.5, path[i] + Vector3.UP * 0.5) != Vector3.INF:
				best = door
				best_i = i
				break
	return best


## GN probe 4: a navmesh path from the pilot ends within 1.5 m of `to` (a long walk that timed out is not "unreachable").
## D-122: crew navigation layer 1 only (Po5Pilot.nav_path), so a breach link (layer 2) through a shut locked door is
## no path. Maps baked through every doorway still pass there: `_pick` checks the doors on the way (`_path_blocker`,
## `_locked_on_path`) before it sends the pilot to a FIRST objective.
func _has_path(to: Vector3) -> bool:
	var path: PackedVector3Array = p.nav_path(to)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) <= 1.5


## The first closed, LOCKED door whose doorway the crew's (layer 1) path to `to` crosses, else null. Stricter than
## `_path_blocker`: a lock the crew could work on (a drill to place, a keypad) still blocks the walk until it is open.
## P's GN-P1 rerun: `hack` went first through the CODE ServerDoor while its drill ran; the pilot pressed the Argus
## terminal through the wall t=597..1143.
func _locked_on_path(to: Vector3) -> Door:
	var path: PackedVector3Array = p.nav_path(to)
	if path.size() < 2:
		return null
	for i: int in range(1, path.size()):
		for n: Node in f.get_tree().get_nodes_in_group(Door.GROUP):
			var door: Door = n as Door
			if door == null or not _locked_shut(door) or not rt.is_ancestor_of(door):
				continue
			if door.doorway_crossing(path[i - 1] + Vector3.UP * 0.5, path[i] + Vector3.UP * 0.5) != Vector3.INF:
				return door
	return null


static func _locked_shut(door: Door) -> bool:
	return not door.is_open and door.locked


## GN probe 3: a target still out of reach after use() (the walk failed: no navmesh path, or a door the crew cannot
## open stopped it) is skipped, so the flow moves on instead of retrying the same slot. A long walk that only hit the
## leg timeout is retried (33bb7e51). Checked against the use stand (UsePoint), not the wall-hung canvas itself.
func _mark_if_unreached(c: InteractableComponent) -> void:
	if not is_instance_valid(c) or p.crew.is_carrying_bag():
		return
	var stand: Vector3 = p._use_stand(c)
	if p.flat_dist(stand, p.crew.global_position) <= 1.0 and absf(stand.y - p.crew.global_position.y) <= 1.5:
		_walk_fails.erase(c.get_instance_id())
		return  # it got there; the hold failed for another reason
	var door: Door = p.last_blocked_door
	if door == null and _has_path(stand):
		var key: int = c.get_instance_id()
		_walk_fails[key] = int(_walk_fails.get(key, 0)) + 1
		if _walk_fails[key] >= WALK_FAIL_LIMIT:
			_walk_fails.erase(key)
			_skip_until[key] = rt.heist_time_s + WALK_SKIP_S
			f.note("setting %s aside for %.0f s (%d failed walks with a path: a body in the way)" % [c.get_path(),
				WALK_SKIP_S, WALK_FAIL_LIMIT])
		return
	_unreachable[c.get_instance_id()] = door
	f.note("skipping unreachable %s (%s) %s" % [c.get_path(), c.kind,
		"until %s is passable" % door.name if door != null else "for this run (no navmesh path)"])


## A target `_mark_if_unreached` blacklisted: for the run when it had no path, else while its door still blocks.
func _is_unreachable(c: InteractableComponent) -> bool:
	var key: int = c.get_instance_id()
	if _skip_until.has(key):
		if rt.heist_time_s < _skip_until[key]:
			return true
		_skip_until.erase(key)
	if not _unreachable.has(key):
		return false
	var door: Door = _unreachable[key]
	if door == null:
		return _still_no_path(c, key)
	if is_instance_valid(door) and not _passable(door):
		return true
	_unreachable.erase(key)
	f.note("%s is passable again: retrying %s" % [door.name if is_instance_valid(door) else "door", c.get_path()])
	return false


## hoist6: VaultCash was marked "no navmesh path" with the cash cage shut; the padlock was sawn 6 s later and the cash
## never retried. A gate / cage opening changes the path: re-test it every UNREACH_RECHECK_S. False (and the mark
## cleared) once there is a path.
func _still_no_path(c: InteractableComponent, key: int) -> bool:
	if rt.heist_time_s < float(_unreach_checked.get(key, -INF)) + UNREACH_RECHECK_S:
		return true
	_unreach_checked[key] = rt.heist_time_s
	if not _has_path(p._use_stand(c)):
		return true
	_unreachable.erase(key)
	_unreach_checked.erase(key)
	f.note("%s has a navmesh path again: retrying" % c.get_path())
	return false


## The crew could walk through `door` now: open, or closed but usable now. Closed and blocked: a shutter (the crew
## never operates one), a locked BARRED / VAULT door (the GN lockdown relocks the art door BARRED; once lifted it is
## unlocked and open), or no enabled interactable the crew can use now (Po5Pilot._door_blocked: no card, no code,
## three failed tries, casing).
func _passable(door: Door) -> bool:
	if door.is_open:
		return true
	if door.shutter or (door.locked and door.lock in [Door.Lock.BARRED, Door.Lock.VAULT]):
		return false
	return not p._door_blocked(door)


## A marker whose walk a door the crew cannot open stopped (`_marker_blocked`), while that door still blocks. For a
## FIRST objective a shut locked door blocks until it is open (`_locked_on_path`; the `_unblock` pseudo objective
## works its keypad / drill meanwhile).
func _is_marker_blocked(m: Dictionary) -> bool:
	var key: String = _marker_key(m)
	if not _marker_blocked.has(key):
		return false
	var door: Door = _marker_blocked[key]
	if is_instance_valid(door) and (not _passable(door) or (StringName(m["id"]) in FIRST_OBJECTIVES and _locked_shut(door))):
		return true
	_marker_blocked.erase(key)
	f.note("marker %s: %s is passable again" % [key, door.name if is_instance_valid(door) else "door"])
	return false


## P's GN loud rerun (StudioDoor, 80 s+): any marker, not only the FIRST ones, whose walk would cross a closed door
## the crew cannot open now yields (recorded in `_marker_blocked`, back once that door is passable) before walking.
func _blocked_on_path(m: Dictionary) -> bool:
	var on_path: Door = _path_blocker(_marker_stand(m["position"] as Vector3))
	if on_path == null:
		return false
	_marker_blocked[_marker_key(m)] = on_path
	f.note("marker %s: %s on the way cannot be opened now" % [_marker_key(m), on_path.name])
	return true


static func _marker_key(m: Dictionary) -> String:
	var pos: Vector3 = m["position"]
	return "%s@%d,%d,%d" % [m["id"], roundi(pos.x), roundi(pos.y), roundi(pos.z)]


## A tool bag source (D-068, LootDef.is_tool: the DB thermite bag), a loose LootBag or a LootSpawn: never loot.
static func _is_tool_source(c: InteractableComponent) -> bool:
	var o: Node = c.owner_node()
	var lid: Variant = o.get(&"loot_id") if (o is LootBag or o is LootSpawn) else null
	return lid is StringName and LootManager.is_tool_loot(lid)


func _carrying_tool() -> bool:
	var bag: LootBag = p.crew.carried_bag as LootBag if p.crew.is_carrying_bag() else null
	return bag != null and LootManager.is_tool_loot(bag.loot_id)


## The enabled `place_thermite` interactable (BurnPoint) within 2.5 m of `pos`, else null.
func _burn_comp_near(pos: Vector3, radius: float = 2.5) -> InteractableComponent:
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c != null and c.kind == &"place_thermite" and c.enabled and rt.is_ancestor_of(c) \
				and c.global_position.distance_to(pos) <= radius:
			return c
	return null


## P's DB pass (env/p-play eb8817eb): the [burn] marker is up but the burn point wants the thermite bag (BLOCK_ITEM):
## fetch the nearest usable thermite bag (its loot spawn at the crew's spawn, or a dropped one) like a player. The
## carry and the placing follow (`_deliver_tool`). True when it acted.
func _fetch_thermite(pos: Vector3) -> bool:
	var bp: InteractableComponent = _burn_comp_near(pos)
	if bp == null or bp.availability(p.crew) == &"" or p.crew.is_carrying_bag():
		return false
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c) or not (c.kind in [&"bag_loot", &"pick_bag"]):
			continue
		if not _is_tool_source(c) or c.availability(p.crew) != &"" or _is_unreachable(c):
			continue
		var dd: float = c.global_position.distance_to(p.crew.global_position)
		if dd < best_d:
			best = c
			best_d = dd
	if best == null:
		_note_once(&"_nothermite", "burn is marked but no thermite bag is usable")
		return false
	f.note("burn: fetching the thermite bag %s (%.0f m)" % [best.get_path(), best_d])
	p.watch_point = Vector3.INF
	await p.use(best, 20.0, func() -> bool: return p.crew.is_carrying_bag())
	_mark_if_unreached(best)
	return true


## Carrying the thermite (a tool, D-068): with the [burn] marker up, carry it to the burn point and hold F there
## (place_thermite consumes it); without one, put it down (it is no loot: never thrown into the van).
func _deliver_tool(markers: Array[Dictionary]) -> void:
	var dp: DrillPoint = _owing_drill((p.crew.carried_bag as LootBag).loot_id)
	if dp != null:
		f.note("carrying %s to %s" % [(p.crew.carried_bag as LootBag).loot_id, dp.name])
		p.watch_point = Vector3.INF
		var placed: int = dp.delivered
		await p.use(dp.interactable, 30.0, func() -> bool: return dp.delivered > placed or not _carrying_tool())
		_mark_if_unreached(dp.interactable)
		return
	for m: Dictionary in markers:
		if StringName(m["id"]) != BURN_ID:
			continue
		var bp: InteractableComponent = _burn_comp_near(m["position"] as Vector3)
		if bp == null:
			break
		f.note("burn: carrying the thermite to %s" % Po5Pilot._v(bp.global_position))
		p.watch_point = Vector3.INF
		await p.use(bp, 30.0, func() -> bool: return not _carrying_tool() or not bp.enabled)
		return
	for m2: Dictionary in markers:  # RT: the burn point is the truck's own (its rear doors), under the [trucks] marker
		var bt: InteractableComponent = _burn_comp_near(m2["position"] as Vector3, TRUCK_BURN_M)
		if bt != null:
			f.note("burn: carrying the thermite to %s on %s" % [Po5Pilot._v(bt.global_position), m2["id"]])
			p.watch_point = Vector3.INF
			await p.use(bt, 30.0, func() -> bool: return not _carrying_tool() or not bt.enabled)
			return
	f.note("carrying a tool bag with no burn point marked: putting it down")
	await p.inp.tap(&"drop_bag")
	await p.inp.ticks(10)


## The enabled DrillPoint still owed a `loot_id` bag (QC-60, OF's thermal drill parts), else null.
func _owing_drill(loot_id: StringName) -> DrillPoint:
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var dp: DrillPoint = c.owner_node() as DrillPoint if c != null else null
		if dp != null and c.enabled and rt.is_ancestor_of(c) and dp.requires_loot == loot_id and dp.needs_delivery() \
				and not _is_unreachable(c):
			return dp
	return null


## OF-A6 (Haz seed 5 waited 1100 s at [drill_delivery]): a loose tool bag that an enabled DrillPoint is still owed
## (the thermal drill parts) is fetched like the DB thermite; _deliver_tool then carries it to the drill. True when
## it acted.
func _fetch_owed_tool() -> bool:
	if p.crew.is_carrying_bag():
		return false
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c) or c.kind != &"pick_bag" or not _is_tool_source(c):
			continue
		var bag: LootBag = c.owner_node() as LootBag
		if bag == null or bag.is_carried() or _owing_drill(bag.loot_id) == null:
			continue
		if c.availability(p.crew) != &"" or _is_unreachable(c):
			continue
		var dd: float = c.global_position.distance_to(p.crew.global_position)
		if dd < best_d:
			best = c
			best_d = dd
	if best == null:
		return false
	f.note("fetching the tool bag %s for its drill (%.0f m)" % [best.get_path(), best_d])
	p.watch_point = Vector3.INF
	await p.use(best, 30.0, func() -> bool: return p.crew.is_carrying_bag())
	_mark_if_unreached(best)
	return true


## Body bags are not loot (S6.2): the loud pilot never picks them up.
static func _is_body_bag(c: InteractableComponent) -> bool:
	var bag: LootBag = c.owner_node() as LootBag
	return bag != null and bag.is_body_bag()


func _secure_bag() -> void:
	var zone: SecureZone = p.secure_zone()
	if zone == null:
		_note_once(&"_nozone", "carrying a bag but no secure zone")
		await p.hold_position(3.0)
		return
	# Lead (ND attempt 14): a real player clears a held landing before carrying a heavy bag through it. Walk in
	# short legs; whenever an enemy is in sight, put the bag down, fight until the way is clear, pick it up again.
	var stand: Vector3 = p.stand_point(zone.global_position)
	var t0: float = rt.heist_time_s
	while p.crew.is_carrying_bag() and not p.near(p.crew.global_position, stand, 3.0) \
			and rt.heist_time_s - t0 < CARRY_LIMIT_S and p.crew.crew_state == Enums.CrewState.NORMAL:
		if p.nearest_enemy(CLEAR_RANGE_M) != null:
			await _clear_then_pick_up()
			continue
		p.quiet = true  # LEAD GPU-18: the 4 s carry legs read as "goto FAILED" lines while the bag moves on
		await p.goto(stand, 3.0, CARRY_LEG_S)
		p.quiet = false
		if p.last_ladder_with_bag != null:
			await _lift_bag()
			return
	if p.crew.is_carrying_bag() and p.crew.crew_state == Enums.CrewState.NORMAL:
		await p.secure_carried_bag(zone)


## OF (headless 1037: 3 min of "RopeLadder up -> FAILED" with a cash bag; ladders refuse a carried bag, S10.1b): like a
## player, the bag leaves the floor by the hoist. The enabled BagLift with a landing within LIFT_NEAR_M on the crew's
## floor: its car is called there (that landing's panel, call_lift), the bag dropped into the car, the car sent on
## (send_lift). The pilot then goes on empty-handed and carries the bag on from the far landing (a loose bag: _pick).
## True when the car left with the bag.
func _lift_bag() -> bool:
	var lift: BagLift = null
	var li: int = -1
	for n: Node in rt.find_children("*", "BagLift", true, false):
		var b: BagLift = n as BagLift
		for i: int in range(b.landing_count() if b != null and b.is_enabled() else 0):
			var o: Vector3 = b.landing_transform(i).origin
			if Po5Pilot.flat_dist(o, p.crew.global_position) <= LIFT_NEAR_M and absf(o.y - p.crew.global_position.y) <= 1.5:
				lift = b
				li = i
	if lift == null or _lift_tries >= LIFT_TRIES_MAX:
		_note_once(&"_nolift", "a bag to take up a ladder and no hoist landing within %.0f m (or %d tries spent)" % [
			LIFT_NEAR_M, LIFT_TRIES_MAX])
		await p.hold_position(3.0)
		return false
	_lift_tries += 1
	if not await _lift_car_to(lift, li):
		return false
	var before: int = lift.bags_in_car().size()
	var center: Vector3 = lift.car_transform().origin
	var fwd_m: float = LootTweak.get_default().drop_forward_m
	for deg: int in range(0, 360, 45):  # x4_of_loud._into_hoist: drop from the first free stand round the car
		if not p.crew.is_carrying_bag() and not await _pick_up_missed(center):
			break  # hoist5: 3 missed tosses fed a bot each (140 s at the rope ladder); pick it up, try the next spot
		if lift.bags_in_car().size() > before:
			break
		var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg)))
		var at: Vector3 = p.stand_point(center - dir * fwd_m)
		if Po5Pilot.flat_dist(at, center - dir * fwd_m) > 0.4 or not await p.goto(at, 0.3, 8.0, false, false):
			continue
		await p.face(center, 0.05, 1.5)  # G is a throw that follows the camera pitch: aim at the car floor (short toss)
		await p.inp.tap(&"drop_bag")
		await p.hold_position(0.8)
		if lift.bags_in_car().size() > before:
			break
	if lift.bags_in_car().size() <= before:
		f.note("hoist: the bag missed %s's car (try %d)" % [lift.name, _lift_tries])
		return false
	var panel: InteractableComponent = _lift_send(lift, li, _lift_top(lift))
	await p.use(panel, 10.0, func() -> bool: return lift.is_moving())
	f.note("hoist: %s sent from landing %d with %d bag(s) (t=%.0f)" % [lift.name, li, lift.bags_in_car().size(),
		rt.heist_time_s])
	if lift.is_moving():
		_lift_tries = 0  # the cap counts failed tries in a row, not trips
	return lift.is_moving()


## A tossed bag that missed the car, lying loose within 3 m of `center`: pick it straight back up (before a bot
## fetches it). True when carrying again.
func _pick_up_missed(center: Vector3) -> bool:
	var lm: LootManager = rt.service(G.SVC_LOOT) as LootManager
	if lm == null:
		return false
	for bag: LootBag in lm.bags():
		if bag.secured or bag.is_carried() or bag.in_flight or bag.interactable == null \
				or bag.global_position.distance_to(center) > 3.0:
			continue
		await p.use(bag.interactable, 6.0, func() -> bool: return p.crew.is_carrying_bag())
		return p.crew.is_carrying_bag()
	return false


## Bring `lift`'s car to landing `i` (its panel there: call_lift) and wait for it. True when it stands there. Never
## calls a car that still holds bags (they would ride back down: hoist3, 8 trips with the same 3 bags).
func _lift_car_to(lift: BagLift, i: int) -> bool:
	await p.hold_position(0.1, func() -> bool: return not lift.is_moving())
	var t0: float = rt.heist_time_s
	while lift.is_moving() and rt.heist_time_s - t0 < lift.travel_s + 5.0:
		await p.hold_position(0.5)
	if lift.landing == i and not lift.is_moving():
		return true
	if not lift.bags_in_car().is_empty():
		_note_once(&"_lift_loaded", "hoist: the car at landing %d still holds bags; unloading it first" % lift.landing)
		return false
	await p.use(_lift_panel(lift, i), 10.0, func() -> bool: return lift.is_moving())
	t0 = rt.heist_time_s
	while (lift.is_moving() or lift.landing != i) and rt.heist_time_s - t0 < lift.travel_s + 5.0:
		await p.hold_position(0.5)
	return lift.landing == i and not lift.is_moving()


## Empty-handed, a BagLift car standing at the landing on the secure zone's floor with bags in it: go there and carry
## one out (a player unloads the hoist up top; the bag is then secured like any carried bag). True when it acted.
func _unload_lift() -> bool:
	var zone: SecureZone = p.secure_zone()
	if p.crew.is_carrying_bag() or zone == null:
		return false
	for n: Node in rt.find_children("*", "BagLift", true, false):
		var lift: BagLift = n as BagLift
		if lift == null or (not lift.is_moving() and lift.bags_in_car().is_empty()):
			continue
		var top: int = 0
		for i: int in range(lift.landing_count()):
			if absf(lift.landing_transform(i).origin.y - zone.global_position.y) \
					< absf(lift.landing_transform(top).origin.y - zone.global_position.y):
				top = i
		if lift.is_moving() and lift.destination == top:
			# hoist4: just sent, the pilot bagged more cash while the car travelled, then found it loaded up top
			await p.hold_position(lift.travel_s + 1.0, func() -> bool: return not lift.is_moving())
			return true
		if lift.is_moving() or lift.landing != top or lift.bags_in_car().is_empty():
			continue
		var bag: LootBag = lift.bags_in_car()[0]
		var comp: InteractableComponent = bag.get_node_or_null(^"Interactable") as InteractableComponent
		if comp == null or not comp.enabled or comp.availability(p.crew) != &"" or _is_unreachable(comp):
			continue
		f.note("hoist: unloading %s at landing %d (%d bag(s) in the car)" % [lift.name, top, lift.bags_in_car().size()])
		await p.use(comp, 30.0, func() -> bool: return p.crew.is_carrying_bag())
		if is_instance_valid(comp) and not p.crew.is_carrying_bag():
			_mark_if_unreached(comp)  # a car the pilot cannot reach does not hold every step
		return true
	return false


## The landing of `lift` nearest the secure zone's floor (where the pilot unloads); the highest one without a zone.
func _lift_top(lift: BagLift) -> int:
	var zone: SecureZone = p.secure_zone()
	var top: int = 0
	for i: int in range(lift.landing_count()):
		var y: float = lift.landing_transform(i).origin.y
		var ty: float = lift.landing_transform(top).origin.y
		if (zone == null and y > ty) or (zone != null \
				and absf(y - zone.global_position.y) < absf(ty - zone.global_position.y)):
			top = i
	return top


## The interaction that sends `lift`'s car from landing `i` to landing `to`: the per-destination send button on a
## lift with 3+ landings (LEAD r304: there the landing panel only calls the car), else that landing's panel.
static func _lift_send(lift: BagLift, i: int, to: int) -> InteractableComponent:
	var row: Dictionary = lift.send_buttons.get(i, {})
	return row.get(to, _lift_panel(lift, i)) as InteractableComponent


static func _lift_panel(lift: BagLift, i: int) -> InteractableComponent:
	return lift.interactable if i == 0 else lift.get_node_or_null(NodePath("%s%d" % [BagLift.PANEL_PREFIX, i])) \
		as InteractableComponent


## Drop the carried bag, fight until no enemy is in sight within CLEAR_RANGE_M (or CLEAR_LIMIT_S), pick it back up.
func _clear_then_pick_up() -> void:
	var bag: LootBag = p.crew.carried_bag as LootBag
	await p.inp.tap(&"drop_bag")
	await p.inp.ticks(10)
	f.note("carry: enemy in sight, bag down to clear the way (t=%.0f)" % rt.heist_time_s)
	var t0: float = rt.heist_time_s
	while rt.heist_time_s - t0 < CLEAR_LIMIT_S and p.crew.crew_state == Enums.CrewState.NORMAL:
		var foe: NpcBase = p.nearest_enemy(CLEAR_RANGE_M)
		if foe == null:
			break
		await p.engage(foe, 2.0)
	if bag != null and is_instance_valid(bag) and not bag.is_carried() and p.crew.crew_state == Enums.CrewState.NORMAL:
		await p.use(bag.interactable, 15.0, func() -> bool: return p.crew.is_carrying_bag())


func _note_once(key: StringName, msg: String) -> void:
	if _stalls.has(key):
		return
	_stalls[key] = 0.0
	f.note("FINDING " + msg)


## True while objective `id` still has a HUD marker (it is still to do).
func _marked(id: StringName) -> bool:
	for m: Dictionary in rt.hud_model.objective_markers:
		if StringName(m["id"]) == id:
			return true
	return false


func _objective_ids() -> Array:
	return rt.hud_model.objectives.map(func(o: Dictionary) -> String: return "%s:%d" % [o["id"], o["state"]])


func _marker_summary() -> String:
	return str(rt.hud_model.objective_markers.map(func(m: Dictionary) -> String: return String(m["id"])))


func fail(msg: String) -> int:
	f.note("FAIL " + msg)
	return 1


## P (GH Tense 4501: the pilot bled out with a bot 2 m away): while the pilot is down, each bot's mode, revive target,
## distance and interaction session, so a missed revive shows why. About every 3 s.
func _note_bot_revives() -> void:
	if rt.heist_time_s - _bot_note_t < 3.0:
		return
	_bot_note_t = rt.heist_time_s
	var parts: PackedStringArray = []
	for c: CrewController in rt.crew_members():
		var b: CrewAiBrain = CrewAiBrain.of(c) if c.is_ai else null
		if b == null:
			continue
		var tgt: CrewController = b.revive_target
		var sess: Dictionary = rt.interaction.session(c.slot) if rt.interaction != null else {}
		var comp: InteractableComponent = sess.get("comp") as InteractableComponent if not sess.is_empty() else null
		parts.append("%d:%s st%d tgt=%s %.1fm sess=%s" % [c.slot, CrewAiBrain.Mode.keys()[b.mode], c.crew_state,
			tgt.slot if tgt != null else -1, c.global_position.distance_to(p.crew.global_position),
			"-" if comp == null else "%s %.1f/%.1f" % [comp.kind, float(sess["progress"]), float(sess["duration"])]])
	f.note("bots while down: " + ", ".join(parts))


## --po5-focus: `m` is the focused objective's marker, not stalled or blocked. A verification flag: the focus can go
## before the escape (markers come in objective order; OF lists bond_safe above escape_wait / escape).
func _is_focus(m: Dictionary) -> bool:
	return focus != &"" and StringName(m["id"]) == focus and not _stalled(m) and not _is_marker_blocked(m)


## --po5-heist-cap=<s>: the loud loop's heist-time cap (default LOOP_LIMIT_S).
static func _heist_cap_arg() -> float:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-heist-cap="):
			return maxf(a.trim_prefix("--po5-heist-cap=").to_float(), 1.0)
	return LOOP_LIMIT_S


static func _focus_arg() -> StringName:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-focus="):
			return StringName(a.trim_prefix("--po5-focus="))
	return &""


## --po5-doctor-bag (LEAD D-145, DB Tense: 3 downs in a long heist): like a PD2 player on a long loud job, the pilot carries
## a doctor bag (L2.11: full heal + downs reset, 2 uses). With 2+ downs used and no enemy within DOCTOR_SAFE_M it walks to
## a placed bag with uses left (DOCTOR_WALK_M), else holds `deploy` to set its own down, then uses it. True when it acted.
func _doctor_bag() -> bool:
	if not doctor_bag or p.crew.health == null or p.crew.health.downs_used < 2 or p.nearest_enemy(DOCTOR_SAFE_M) != null:
		return false
	var ds: DeployableSystem = rt.service(DeployableSystem.SERVICE) as DeployableSystem
	if ds == null:
		return false
	var best: DeployablePrefab = null
	for n: Node in ds.placed(&"doctor_bag"):
		var bag: DeployablePrefab = n as DeployablePrefab
		if bag != null and bag.uses_left > 0 and bag.interactable != null and bag.interactable.enabled \
				and bag.global_position.distance_to(p.crew.global_position) <= DOCTOR_WALK_M:
			if best == null or bag.global_position.distance_to(p.crew.global_position) \
					< best.global_position.distance_to(p.crew.global_position):
				best = bag
	if best == null and ds.deployable_count(p.crew.slot) > 0:
		var before: int = ds.deployable_count(p.crew.slot)
		f.note("doctor bag: %d downs used, deploying one" % p.crew.health.downs_used)
		p.inp.press(&"deploy")
		var waited: float = 0.0
		while ds.deployable_count(p.crew.slot) >= before and waited < 6.0 and p.crew.crew_state == Enums.CrewState.NORMAL:
			await f.wait_s(0.1)
			waited += 0.1
		p.inp.release(&"deploy")
		await p.inp.ticks(5)
		return true  # the next step walks to it and uses it
	if best == null:
		return false
	f.note("doctor bag: %d downs used, using the bag at %s (%d uses left)" % [p.crew.health.downs_used,
		Po5Pilot._v(best.global_position), best.uses_left])
	var downs: int = p.crew.health.downs_used
	await p.use(best.interactable, 15.0, func() -> bool: return p.crew.health.downs_used < downs)
	return true


## While the pilot is down: every bot interaction start / cancel, with the bot's speed and mode (B's DB Tense: revive
## sessions open but never complete).
func _note_bot_interaction(nid: int, slot: int, what: StringName) -> void:
	if p == null or p.crew.crew_state == Enums.CrewState.NORMAL:
		return
	var c: CrewController = rt.crew_controller(slot) as CrewController
	var b: CrewAiBrain = CrewAiBrain.of(c) if c != null and c.is_ai else null
	if b == null:
		return
	f.note("bot %d interaction %s on %d: speed %.2f st%d %s" % [slot, what, nid,
		Vector2(c.velocity.x, c.velocity.z).length(), c.crew_state, CrewAiBrain.Mode.keys()[b.mode]])


## While downed, keep shooting the nearest enemy in sight like a player (PD2 / L2.12: police only cuff a downed
## crew member who is NOT shooting), where police cuff at all (Po5Pilot.shoots_from_floor); otherwise, and in any
## other helpless state, just wait. About 1 s per call.
func _act_while_down() -> void:
	_note_bot_revives()
	if p.crew.crew_state == Enums.CrewState.DOWNED and p.shoots_from_floor():
		var foe: NpcBase = p.nearest_enemy(25.0)
		if foe != null:
			await p.engage(foe, 1.0)
			return
	await f.wait_s(1.0)
