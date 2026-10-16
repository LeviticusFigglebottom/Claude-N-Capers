## PO-5 generic LOUD run for any heist: plays like a player who reads the HUD. It masks up, goes loud,
## then follows LocalHudModel.objective_markers (ui_hud 1.8): walks to the first marked objective, uses
## what is usable there (doors, drills, keypads, bags), defends while devices run (fixing jams), carries
## bags to a marked secure zone, and stands in the escape zone. Input only (Po5Pilot).
## Reports objectives that have no marker or nothing usable as findings (objective guidance gaps).
extends RefCounted

const LOOP_LIMIT_S: float = 1500.0
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

var f: Node = null
var p: Po5Pilot = null
var rt: HeistRuntime = null
var _ended: bool = false
var _stalls: Dictionary[StringName, float] = {}
## GN probe 3 (handoff §A1): interactables the pilot failed to reach (instance id -> the closed door that stopped
## the walk, or null when the navmesh has no path), skipped for the run, or until that door is passable again (GN
## loud: the Calloway canvas behind the lockdown-BARRED shutter comes back once the hack lifts it).
var _unreachable: Dictionary[int, Door] = {}
## Markers whose walk was stopped by a door the crew cannot open (`_marker_key` -> that door): they yield like a
## stalled marker until the door is passable. Per marker, not per objective ([canvases] has one per slot).
var _marker_blocked: Dictionary[String, Door] = {}


func play(flow: Node) -> int:
	f = flow
	p = flow.get(&"pilot") as Po5Pilot
	rt = flow.get(&"rt") as HeistRuntime
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		_ended = true
		f.note("EVENT heist_ended %s" % [r]))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		f.note("EVENT objective %s -> %d t=%.0f" % [id, st, rt.heist_time_s]))
	EventBus.loot_secured.connect(func(_b: int, l: StringName, v: int) -> void:
		f.note("EVENT loot_secured %s %d t=%.0f" % [l, v, rt.heist_time_s]))
	await p.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	p.combat = true
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
	while not _ended and rt.heist_time_s - t0 < LOOP_LIMIT_S:
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
		return fail("no heist end within %.0f s; markers %s" % [LOOP_LIMIT_S, _marker_summary()])
	return await f.payday_to_hub()


## One decision: the first marked active objective (HUD order).
func step() -> void:
	var markers: Array[Dictionary] = rt.hud_model.objective_markers
	if markers.is_empty():
		_note_once(&"_none", "no objective markers (HUD shows %s)" % [_objective_ids()])
		await p.hold_position(2.0)
		return
	if await _revive_teammate():
		return
	var m: Dictionary = _pick(markers)
	var id: StringName = StringName(m["id"])
	var pos: Vector3 = m["position"]
	if p.crew.is_carrying_bag():
		await _secure_bag()
		return
	var esc: EscapeZone = p.active_escape()
	if esc != null and id == &"escape":
		await p.goto(p.stand_point(esc.global_position), 1.0, 60.0)
		await p.hold_position(3.0, func() -> bool: return _ended)
		return
	var zone: SecureZone = p.secure_zone()
	if zone != null and zone.global_position.distance_to(pos) < 3.0:
		if not await _fetch_bag():
			await p.hold_position(3.0)
		return
	var comp: InteractableComponent = _usable_near(pos, 2.5)
	if comp != null:
		if id == UNBLOCK_ID:
			_stalls[id] = float(_stalls.get(id, 0.0))  # started: keep defending its drill after this (see _pick)
		p.watch_point = Vector3.INF
		await p.use(comp, 30.0, func() -> bool: return not comp.enabled or comp.availability(p.crew) != &"")
		if is_instance_valid(comp) and comp.enabled and comp.availability(p.crew) == &"":
			_mark_if_unreached(comp)  # still usable and still far: the walk failed (GN Slot_orchard_calloway)
		return
	# Nothing to do at the marker right now (a device running, a timer): go there and defend.
	if p.flat_dist(p.crew.global_position, pos) > 4.0:
		if not await p.goto(p.stand_point(pos), 2.5, 60.0):
			_note_once(id, "objective %s: marker at %s not reachable" % [id, Po5Pilot._v(pos)])
			if p.last_blocked_door != null:
				_marker_blocked[_marker_key(m)] = p.last_blocked_door  # GN probe 6: behind the BARRED shutter -> yield at once
			elif not _has_path(p.stand_point(pos)):
				_stalls[id] = maxf(float(_stalls.get(id, 0.0)), STALL_SKIP_S)  # GN probe 4: no path -> yield at once
	_stalls[id] = _stalls.get(id, 0.0) + 3.0
	if int(_stalls[id]) % 60 == 0:
		f.note("waiting at %s for %.0f s (nothing usable within 2.5 m)" % [id, _stalls[id]])
	await p.hold_position(3.0)


## An open escape goes first (the ride only comes once the required objectives are done; GN probe 7 looped on the
## optional extras / lockers behind the art store vault door instead). Otherwise prefer objectives that are not the
## generic secure/escape when something else is still active. Walk-near (area)
## objectives (GN find_canvases) and markers that stalled STALL_SKIP_S with nothing usable come last, so the
## flow moves on to what it can act on (GN probe: stuck at a found, already cut canvas).
func _pick(markers: Array[Dictionary]) -> Dictionary:
	for me: Dictionary in markers:  # GN probe 7: the ride is here (required loot secured): leave, skip the extras
		if StringName(me["id"]) == &"escape":
			return me
	for m0: Dictionary in markers:  # GN probe 4: the loud hack lifts every shutter (Calloway), so it goes first
		if StringName(m0["id"]) in FIRST_OBJECTIVES and not _marker_blocked.has(_marker_key(m0)):
			# P's GN-P1 rerun (a): the navmesh runs through the closed CODE ServerDoor, so a path alone said "go" and
			# the pilot pressed the Argus terminal through the wall for 9 min. Check the doors on that path first.
			var on_path: Door = _path_blocker(p.stand_point(m0["position"] as Vector3))
			if on_path != null:
				_marker_blocked[_marker_key(m0)] = on_path
				f.note("marker %s: %s on the way cannot be opened now" % [_marker_key(m0), on_path.name])
		var gate: Door = _marker_blocked.get(_marker_key(m0)) as Door
		if StringName(m0["id"]) in FIRST_OBJECTIVES and _is_marker_blocked(m0) \
				and float(_stalls.get(UNBLOCK_ID, 0.0)) < STALL_SKIP_S * 4.0 \
				and (_stalls.has(UNBLOCK_ID) or _usable_near(gate.global_position, 2.5) != null):
			# GN probe 6: open the door in front of it first (then defend its drill there, up to 4 x STALL_SKIP_S)
			return {"id": UNBLOCK_ID, "position": gate.global_position}
		if StringName(m0["id"]) in FIRST_OBJECTIVES and float(_stalls.get(StringName(m0["id"]), 0.0)) < STALL_SKIP_S \
				and not _is_marker_blocked(m0) \
				and _has_path(p.stand_point(m0["position"] as Vector3)):  # probe 5: the Argus terminal sits behind
			return m0  # the coded ServerDoor; only first when reachable
	for m: Dictionary in markers:
		var mid: StringName = StringName(m["id"])
		if not (mid in [&"secure", &"escape", &"casing"] or mid in AREA_OBJECTIVES) \
				and float(_stalls.get(mid, 0.0)) < STALL_SKIP_S and not _is_marker_blocked(m):
			return m
	for m1: Dictionary in markers:
		if not (StringName(m1["id"]) in [&"secure", &"escape", &"casing"]):
			return m1
	return markers[0]


## Enabled interactables within `radius` of the marker the player can use now (not revive / tie / pager / body bags).
func _usable_near(pos: Vector3, radius: float) -> InteractableComponent:
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c):
			continue
		if c.kind in [&"revive", &"cable_tie", &"answer_pager", &"uncuff", &"break_window", &"break_glass", &"take_loot", &"bag_body"]:
			continue
		if c.availability(p.crew) != &"" or _is_unreachable(c):
			continue
		if _is_body_bag(c):
			continue  # ND attempt 11: a body bag by the drill marker sent the pilot up the stairs mid-wave
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
		if c == null or not c.enabled or not rt.is_ancestor_of(c) or not (c.kind in [&"bag_loot", &"carry_bag", &"pickup_bag"]):
			continue
		if c.availability(p.crew) != &"" or _is_body_bag(c) or _is_unreachable(c):
			continue
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
	return p.crew.is_carrying_bag()


## The first closed door on the navmesh path from the pilot to `to` the crew cannot open now (BARRED / CODE without
## the keypad / VAULT...), else null. The GN navmesh is baked through every doorway (heist_map.md §3).
func _path_blocker(to: Vector3) -> Door:
	var path: PackedVector3Array = p.nav_path(to)
	if path.size() < 2:
		return null
	var best: Door = null
	var best_i: int = path.size()
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var door: Door = c.owner_node() as Door if c != null else null
		if door == null or not rt.is_ancestor_of(door) or _passable(door):
			continue
		var half: float = maxf(door.width_m * 0.5, 0.6)
		var inv: Transform3D = door.global_transform.affine_inverse()
		for i: int in range(1, mini(path.size(), best_i + 1)):
			var a: Vector3 = inv * path[i - 1]
			var b: Vector3 = inv * path[i]
			if signf(a.z) == signf(b.z) or absf(a.z - b.z) < 0.001:
				continue  # this leg does not go through the door's plane
			var x: Vector3 = a.lerp(b, a.z / (a.z - b.z))  # where it crosses (door space)
			if absf(x.x) <= half + 0.2 and absf(x.y) <= 1.5:
				best = door
				best_i = i
				break
	return best


## GN probe 4: a navmesh path from the pilot ends within 1.5 m of `to` (a long walk that timed out is not "unreachable").
func _has_path(to: Vector3) -> bool:
	var map: RID = p.crew.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, p.crew.global_position, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) <= 1.5


## GN probe 3: a target still out of reach after use() (the walk failed: no navmesh path, or a door the crew cannot
## open stopped it) is skipped, so the flow moves on instead of retrying the same slot. A long walk that only hit the
## leg timeout is retried (33bb7e51). Checked against the use stand (UsePoint), not the wall-hung canvas itself.
func _mark_if_unreached(c: InteractableComponent) -> void:
	if not is_instance_valid(c) or p.crew.is_carrying_bag():
		return
	var stand: Vector3 = p._use_stand(c)
	if p.flat_dist(stand, p.crew.global_position) <= 1.0 and absf(stand.y - p.crew.global_position.y) <= 1.5:
		return  # it got there; the hold failed for another reason
	var door: Door = p.last_blocked_door
	if door == null and _has_path(stand):
		return
	_unreachable[c.get_instance_id()] = door
	f.note("skipping unreachable %s (%s) %s" % [c.get_path(), c.kind,
		"until %s is passable" % door.name if door != null else "for this run (no navmesh path)"])


## A target `_mark_if_unreached` blacklisted: for the run when it had no path, else while its door still blocks.
func _is_unreachable(c: InteractableComponent) -> bool:
	var key: int = c.get_instance_id()
	if not _unreachable.has(key):
		return false
	var door: Door = _unreachable[key]
	if door == null:
		return true
	if is_instance_valid(door) and not _passable(door):
		return true
	_unreachable.erase(key)
	f.note("%s is passable again: retrying %s" % [door.name if is_instance_valid(door) else "door", c.get_path()])
	return false


## The crew could walk through `door` now: open, or closed but usable (not BARRED / VAULT / no card).
func _passable(door: Door) -> bool:
	return door.is_open or not p._door_blocked(door)


## A marker whose walk a door the crew cannot open stopped (`_marker_blocked`), while that door still blocks.
func _is_marker_blocked(m: Dictionary) -> bool:
	var key: String = _marker_key(m)
	if not _marker_blocked.has(key):
		return false
	var door: Door = _marker_blocked[key]
	if is_instance_valid(door) and not _passable(door):
		return true
	_marker_blocked.erase(key)
	f.note("marker %s: %s is passable again" % [key, door.name if is_instance_valid(door) else "door"])
	return false


static func _marker_key(m: Dictionary) -> String:
	var pos: Vector3 = m["position"]
	return "%s@%d,%d,%d" % [m["id"], roundi(pos.x), roundi(pos.y), roundi(pos.z)]


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
	while p.crew.is_carrying_bag() and p.flat_dist(p.crew.global_position, stand) > 3.0 \
			and rt.heist_time_s - t0 < CARRY_LIMIT_S and p.crew.crew_state == Enums.CrewState.NORMAL:
		if p.nearest_enemy(CLEAR_RANGE_M) != null:
			await _clear_then_pick_up()
			continue
		await p.goto(stand, 3.0, CARRY_LEG_S)
	if p.crew.is_carrying_bag() and p.crew.crew_state == Enums.CrewState.NORMAL:
		await p.secure_carried_bag(zone)


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


func _objective_ids() -> Array:
	return rt.hud_model.objectives.map(func(o: Dictionary) -> String: return "%s:%d" % [o["id"], o["state"]])


func _marker_summary() -> String:
	return str(rt.hud_model.objective_markers.map(func(m: Dictionary) -> String: return String(m["id"])))


func fail(msg: String) -> int:
	f.note("FAIL " + msg)
	return 1


## While downed, keep shooting the nearest enemy in sight like a player (PD2 / L2.12: police only cuff a downed
## crew member who is NOT shooting); any other helpless state just waits. About 1 s per call.
func _act_while_down() -> void:
	if p.crew.crew_state == Enums.CrewState.DOWNED:
		var foe: NpcBase = p.nearest_enemy(25.0)
		if foe != null:
			await p.engage(foe, 1.0)
			return
	await f.wait_s(1.0)
