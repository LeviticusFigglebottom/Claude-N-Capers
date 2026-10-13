## PO-5 generic LOUD run for any heist: plays like a player who reads the HUD. It masks up, goes loud,
## then follows LocalHudModel.objective_markers (ui_hud 1.8): walks to the first marked objective, uses
## what is usable there (doors, drills, keypads, bags), defends while devices run (fixing jams), carries
## bags to a marked secure zone, and stands in the escape zone. Input only (Po5Pilot).
## Reports objectives that have no marker or nothing usable as findings (objective guidance gaps).
extends RefCounted

const LOOP_LIMIT_S: float = 1500.0

var f: Node = null
var p: Po5Pilot = null
var rt: HeistRuntime = null
var _ended: bool = false
var _stalls: Dictionary[StringName, float] = {}


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
			await f.wait_s(1.0)
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
		p.watch_point = Vector3.INF
		await p.use(comp, 30.0, func() -> bool: return not comp.enabled or comp.availability(p.crew) != &"")
		return
	# Nothing to do at the marker right now (a device running, a timer): go there and defend.
	if p.flat_dist(p.crew.global_position, pos) > 4.0:
		if not await p.goto(p.stand_point(pos), 2.5, 60.0):
			_note_once(id, "objective %s: marker at %s not reachable" % [id, Po5Pilot._v(pos)])
	_stalls[id] = _stalls.get(id, 0.0) + 3.0
	if int(_stalls[id]) % 60 == 0:
		f.note("waiting at %s for %.0f s (nothing usable within 2.5 m)" % [id, _stalls[id]])
	await p.hold_position(3.0)


## Prefer objectives that are not the generic secure/escape when something else is still active.
func _pick(markers: Array[Dictionary]) -> Dictionary:
	for m: Dictionary in markers:
		if not (StringName(m["id"]) in [&"secure", &"escape", &"casing"]):
			return m
	for m2: Dictionary in markers:
		if StringName(m2["id"]) == &"escape":
			return m2
	return markers[0]


## Enabled interactables within `radius` of the marker the player can use now (not revive / tie / pager).
func _usable_near(pos: Vector3, radius: float) -> InteractableComponent:
	var best: InteractableComponent = null
	var best_d: float = radius
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c):
			continue
		if c.kind in [&"revive", &"cable_tie", &"answer_pager", &"uncuff", &"break_window", &"break_glass", &"take_loot"]:
			continue
		if c.availability(p.crew) != &"":
			continue
		var dd: float = c.global_position.distance_to(pos)
		if dd < best_d:
			best = c
			best_d = dd
	return best


## A bag source: a loose bag on the floor, else an enabled bag_loot spawn (closest).
func _fetch_bag() -> bool:
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c) or not (c.kind in [&"bag_loot", &"carry_bag", &"pickup_bag"]):
			continue
		if c.availability(p.crew) != &"":
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
	return p.crew.is_carrying_bag()


func _secure_bag() -> void:
	var zone: SecureZone = p.secure_zone()
	if zone == null:
		_note_once(&"_nozone", "carrying a bag but no secure zone")
		await p.hold_position(3.0)
		return
	await p.secure_carried_bag(zone)


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
