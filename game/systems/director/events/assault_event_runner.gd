## PO6-17 (D-114 §5) RNG assault events: rolls (AssaultEventScheduler on GameRng &"assault_events") and runs them.
## Owner: ENV A. Child `AssaultEvents` of the AssaultDirector; server only (the director ticks it while running).
## Rows come from AssaultEventsTweak.rows_for(heist_id) (until HeistDef carries them; options
## "assault_events_tweak" overrides the tweak, "assault_events": false turns events off).
## Kinds:
## * turret_van: AssaultTurretVan at a TurretVan_<n> marker (else the police spawn nearest the crew); its squad
##   dismounts at ExitPoint.
## * heli: AssaultHeli around HeliOrbit_<n> (else the map bounds' centre). Drop: a HeliDrop_<n> on the navmesh, or
##   one off it (GH roof) paired with an intact ceiling breach within PAIR_RADIUS_M (that breach is blown and the
##   squad walks to it and drops through); else the police spawn nearest the crew. Units spawn at the rope
##   anchors and are guided down (NpcMotor `rappelling` = the `rappel` clip). Sniper: a Longshot on the seat with
##   a moving SNIPER_PERCH (LongshotBrain perch rule), removed when the heli leaves.
## * breach: AssaultBreach at the intact Breach_<n> whose ExitPoint is nearest the crew (else an ENTRY point,
##   fx only); its squad walks in through the opened link (wall), swings in on a rope (window) or drops through
##   (ceiling).
## Event units go through AssaultDirector.spawn_enemy (assault force pool) and stop at the hard enemy_cap().
## Facts: signals event_started / event_ended here plus the entities' audio cues [R] (cue.assault_*); the
## EventBus fact `assault_event_started(kind, net_id, position)` [R] is a pending ask to the lead.
class_name AssaultEventRunner
extends Node

signal event_started(kind: StringName, entity: Node, position: Vector3)
signal event_ended(kind: StringName, entity: Node)
## A unit of an event spawned (tests / telemetry).
signal unit_spawned(kind: StringName, npc: NpcBase)

const RNG: StringName = &"assault_events"
const DEFAULT_TWEAK: String = "res://systems/director/assault_events_tweak.tres"
const PAIR_RADIUS_M: float = 12.0
const WALK_SPEED_MPS: float = 2.2

var director: AssaultDirector = null
var tweak: AssaultEventsTweak = null
var scheduler: AssaultEventScheduler = AssaultEventScheduler.new()
var enabled: bool = true
var begun: bool = false
var active: Array[AssaultEventEntity] = []
## {kind, t, wave, position, marker, net_id} of every event run.
var history: Array[Dictionary] = []
var units: Array[NpcBase] = []

var _rt: HeistRuntime = null
## Pending unit spawns: {t, id, xf, legs, kind, owner}.
var _queue: Array[Dictionary] = []
## Guided units: {npc, legs, i, owner}.
var _guides: Array[Dictionary] = []
## Breach marker paths blown / in use -> their AssaultBreach.
var _breach_used: Dictionary = {}
var _entry_used: Dictionary = {}
## Heli -> units still on its ropes.
var _heli_ropes: Dictionary = {}
var _clock: float = 0.0


func setup(dir: AssaultDirector) -> void:
	director = dir


func _ready() -> void:
	_rt = HeistRuntime.of(self)
	tweak = load(DEFAULT_TWEAK) as AssaultEventsTweak
	if _rt != null:
		var o: AssaultEventsTweak = _rt.options.get("assault_events_tweak") as AssaultEventsTweak
		if o != null:
			tweak = o
		enabled = bool(_rt.options.get("assault_events", true))


func rows() -> Array[Dictionary]:
	return tweak.rows_for(_rt.heist_id) if _rt != null and tweak != null else [] as Array[Dictionary]


func begin() -> void:
	if begun:
		return
	begun = true
	scheduler.setup(tweak, rows(), _rt.difficulty if _rt != null else 0)
	Log.info(&"director", "assault events: %d rows for %s" % [scheduler.rows.size(), _rt.heist_id if _rt else &""])


## Server, from the director's physics step.
func tick(delta: float) -> void:
	if _rt == null or _rt.map == null or not Net.is_authority():
		return
	if not begun:
		begin()
	_clock += delta
	_tick_queue(delta)
	_tick_guides(delta)
	if not enabled or scheduler.rows.is_empty():
		return
	var blocked: Array[StringName] = []
	if scheduler.roll_left <= delta and AssaultEventScheduler.eligible(tweak, director.assault_phase, director.wave_index):
		blocked = blocked_kinds()  # only when a roll is due (marker scans are not free)
	var i: int = scheduler.tick(delta, director.assault_phase, director.wave_index, active.size(), GameRng.stream(RNG), blocked)
	if i >= 0:
		var row: Dictionary = scheduler.rows[i]
		run(StringName(row.get("kind", &"")), tweak.params_for(row))


## Kinds that cannot run right now (no usable marker / one already on the map).
func blocked_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: AssaultEventEntity in active:
		if e.kind == AssaultEventsTweak.KIND_TURRET_VAN and not out.has(e.kind):
			out.append(e.kind)  # one van at a time
		if e.kind == AssaultEventsTweak.KIND_HELI and not out.has(e.kind):
			out.append(e.kind)
	if _breach_candidates().is_empty():
		out.append(AssaultEventsTweak.KIND_BREACH)
	return out


## Server: run an event of `kind` now (tests call it directly). `params` default to the tweak's kind defaults;
## `marker` picks a marker by name. Returns the entity (null when it could not run).
func run(kind: StringName, params: Dictionary = {}, marker: String = "") -> AssaultEventEntity:
	if _rt == null or not Net.is_authority():
		return null
	var p: Dictionary = tweak.params_for({"kind": kind})
	p.merge(params, true)
	p["difficulty"] = _rt.difficulty
	var e: AssaultEventEntity = null
	match kind:
		AssaultEventsTweak.KIND_TURRET_VAN:
			e = _run_van(p, marker)
		AssaultEventsTweak.KIND_HELI:
			e = _run_heli(p, marker)
		AssaultEventsTweak.KIND_BREACH:
			e = _run_breach(p, marker)
	if e == null:
		Log.warn(&"director", "assault event %s: nothing to run" % kind)
		return null
	var at: Vector3 = e.global_position
	if e is AssaultTurretVan:
		at = (e as AssaultTurretVan).park.origin
	elif e is AssaultHeli:
		at = (e as AssaultHeli).hover_point if (e as AssaultHeli).do_drop else (e as AssaultHeli).orbit_center
	history.append({"kind": kind, "t": _clock, "wave": director.wave_index if director else 0,
		"position": at, "marker": String(p.get("_marker", "")), "net_id": e.net_id})
	Log.info(&"director", "assault event %s at %s (%s)" % [kind, at, p.get("_marker", "fallback")])
	event_started.emit(kind, e, at)
	return e


func _add_entity(e: AssaultEventEntity, kind: StringName, p: Dictionary, xf: Transform3D) -> void:
	e.kind = kind
	e.params = _net_params(p)
	e.name = "AssaultEvent_%s_%d" % [kind, history.size()]
	_rt.dynamic_root.add_child(e, true)
	e.global_transform = xf
	NetIds.claim(e)
	active.append(e)
	e.ended.connect(_on_ended)
	e.tree_exiting.connect(_on_ended.bind(e))


## Params replicated with the entity: plain values only (StringName arrays become String arrays).
static func _net_params(p: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in p:
		var v: Variant = p[k]
		if v is Object:
			continue
		out[k] = v
	return out


func _on_ended(e: AssaultEventEntity) -> void:
	if not active.has(e):
		return
	active.erase(e)
	event_ended.emit(e.kind, e)


# --- Turret van --------------------------------------------------------------------------------

func _run_van(p: Dictionary, marker: String) -> AssaultEventEntity:
	var xf: Transform3D = Transform3D.IDENTITY
	var ms: Array[Node3D] = _pick_markers(AssaultEventMarkers.VAN, marker)
	var taken: Array[Vector3] = []
	for e: AssaultEventEntity in active:
		if e is AssaultTurretVan:
			taken.append((e as AssaultTurretVan).park.origin)
	var free: Array[Node3D] = []
	for m: Node3D in ms:
		var used: bool = false
		for t: Vector3 in taken:
			used = used or t.distance_to(m.global_position) < 2.0
		if not used:
			free.append(m)
	if not free.is_empty():
		var m2: Node3D = free[GameRng.stream(RNG).randi_range(0, free.size() - 1)]
		xf = m2.global_transform.orthonormalized()
		p["_marker"] = String(m2.name)
	else:
		var sp: Node3D = _nearest_police_spawn([])
		if sp == null:
			return null
		var to_crew: Vector3 = _flat(_crew_centroid() - sp.global_position)
		var basis: Basis = Basis.IDENTITY
		if to_crew.length() > 0.1:
			basis = Basis.looking_at(-to_crew.normalized(), Vector3.UP)  # +Z (nose) toward the crew
		xf = Transform3D(basis, sp.global_position)
	var van: AssaultTurretVan = AssaultTurretVan.new()
	van.on_dismount = func(ids: Array, exit: Transform3D) -> void: _queue_squad(ids, exit, [], AssaultEventsTweak.KIND_TURRET_VAN,
		van, p.get("squad_interval_s", 0.7))
	_add_entity(van, AssaultEventsTweak.KIND_TURRET_VAN, p, xf)
	van.start(xf)
	return van


# --- Helicopter --------------------------------------------------------------------------------

func _run_heli(p: Dictionary, marker: String) -> AssaultEventEntity:
	var center: Vector3
	var radius: float = float(p.get("orbit_radius_m", 24.0))
	var orbits: Array[Node3D] = _pick_markers(AssaultEventMarkers.HELI_ORBIT, "")
	if not orbits.is_empty():
		var o: Node3D = orbits[GameRng.stream(RNG).randi_range(0, orbits.size() - 1)]
		center = o.global_position
		radius = float(o.get_meta(&"radius", radius))
	else:
		var b: AABB = AssaultEventMarkers.map_bounds(_rt.map)
		center = b.get_center()
		center.y = maxf(b.end.y + 8.0, float(p.get("orbit_height_m", 30.0)))
		center = Vector3(center.x, center.y, center.z)
	var drop: Dictionary = {}
	if bool(p.get("drop", true)):
		drop = _pick_drop(marker)
	var hover: Vector3 = Vector3.INF
	var floor_y: float = 0.0
	if not drop.is_empty():
		var dp: Vector3 = drop["pos"]
		hover = dp + Vector3(0, float(p.get("hover_height_m", 11.0)), 0)
		floor_y = dp.y
		p["_marker"] = String(drop.get("name", ""))
	var heli: AssaultHeli = AssaultHeli.new()
	_add_entity(heli, AssaultEventsTweak.KIND_HELI, p, Transform3D(Basis.IDENTITY, center))
	heli.start(center, radius, hover, floor_y, not drop.is_empty(), bool(p.get("sniper", true)))
	heli.hover_reached.connect(_on_heli_hover.bind(drop, p))
	heli.sniper_window.connect(_on_heli_sniper.bind(p))
	heli.tree_exiting.connect(_on_heli_gone.bind(heli))
	return heli


## {pos, name, breach (AssaultBreach marker path or "")} or {}.
func _pick_drop(marker: String) -> Dictionary:
	var cands: Array[Dictionary] = []
	for m: Node3D in _pick_markers(AssaultEventMarkers.HELI_DROP, marker):
		var pos: Vector3 = m.global_position
		if AssaultEventMarkers.nav_point(_rt.map, pos, 1.2) != Vector3.INF:
			cands.append({"pos": pos, "name": String(m.name), "breach": ""})
			continue
		var pair: Node3D = _pair_ceiling_breach(pos)
		if pair != null:
			cands.append({"pos": pos, "name": String(m.name), "breach": _map_path(pair)})
		else:
			Log.warn(&"director", "HeliDrop %s is off the navmesh and has no ceiling breach near it: skipped" % m.name)
	if not cands.is_empty():
		return cands[GameRng.stream(RNG).randi_range(0, cands.size() - 1)]
	var sp: Node3D = _nearest_police_spawn([])
	return {"pos": sp.global_position, "name": "", "breach": ""} if sp != null else {}


func _pair_ceiling_breach(pos: Vector3) -> Node3D:
	for m: Node3D in AssaultEventMarkers.list(_rt.map, AssaultEventMarkers.BREACH):
		if String(m.get_meta(&"kind", "wall")) == "ceiling" and m.global_position.distance_to(pos) <= PAIR_RADIUS_M:
			return m
	return null


func _on_heli_hover(heli: AssaultHeli, drop: Dictionary, p: Dictionary) -> void:
	var ids: Array = p.get("squad", []) as Array
	var anchors: Array[Vector3] = heli.rope_anchors()
	var breach: AssaultBreach = null
	var bpath: String = String(drop.get("breach", ""))
	if bpath != "" and _breach_used.has(bpath):
		breach = _breach_used[bpath] as AssaultBreach  # already blown (or blowing): drop through the open hole
		if breach != null and not is_instance_valid(breach):
			breach = null
	elif bpath != "":
		var bp: Dictionary = tweak.params_for({"kind": AssaultEventsTweak.KIND_BREACH})
		bp["squad"] = []  # the heli's squad goes through it
		breach = _run_breach(bp, String((_rt.map.get_node(NodePath(bpath)) as Node).name)) as AssaultBreach
		if breach != null:
			history.append({"kind": AssaultEventsTweak.KIND_BREACH, "t": _clock, "wave": director.wave_index,
				"position": breach.global_position, "marker": bpath, "net_id": breach.net_id})
			event_started.emit(AssaultEventsTweak.KIND_BREACH, breach, breach.global_position)
	_heli_ropes[heli] = 0
	var interval: float = float(p.get("drop_interval_s", 0.9))
	for i: int in range(ids.size()):
		var a: Vector3 = anchors[i % anchors.size()]
		var land: Vector3 = _floor_below(a, float(drop["pos"].y))
		var legs: Array[Dictionary] = [{"to": land, "rappel": true, "speed": float(p.get("rappel_speed_mps", 3.0)), "landed": true}]
		if breach != null:
			var above: Vector3 = breach.global_position + breach.global_basis.z.normalized() * 0.9
			legs.append({"to": breach.point("EntryPoint"), "rappel": false})
			legs.append({"to": above, "rappel": false, "wait_breach": breach})
			legs.append({"to": breach.point("ExitPoint"), "rappel": true, "speed": 3.5})
		_queue.append({"t": interval * i, "id": StringName(ids[i]),
			"xf": Transform3D(heli.global_basis, a - Vector3(0, 1.7, 0)), "legs": legs,
			"kind": AssaultEventsTweak.KIND_HELI, "owner": heli})
		_heli_ropes[heli] = int(_heli_ropes[heli]) + 1
	if ids.is_empty():
		heli.drop_done = true


func _on_heli_sniper(heli: AssaultHeli, on: bool, p: Dictionary) -> void:
	if not on:
		_clear_sniper(heli)
		return
	var def: EnemyDef = director.enemy_def_for(StringName(p.get("sniper_id", &"enemy.longshot")))
	if def == null or not _under_cap():
		return
	var perch: TacticalPoint = TacticalPoint.new()
	perch.name = "HeliPerch_%d" % heli.net_id
	perch.kind = TacticalPoint.Kind.SNIPER_PERCH
	perch.tags = [&"heli"] as Array[StringName]
	var parent: Node = _rt.map.get_node_or_null(^"Tactical")
	(parent if parent != null else _rt.map).add_child(perch)
	var seat: Transform3D = heli.seat_transform()
	perch.global_position = seat.origin
	var npc: NpcBase = director.spawn_enemy(def, Transform3D(seat.basis, seat.origin), null, {"assault_event": AssaultEventsTweak.KIND_HELI})
	if npc == null:
		perch.queue_free()
		return
	npc.global_position = seat.origin
	heli.passenger = npc
	heli.passenger_perch = perch
	units.append(npc)
	unit_spawned.emit(AssaultEventsTweak.KIND_HELI, npc)


func _clear_sniper(heli: AssaultHeli) -> void:
	if heli.passenger != null and is_instance_valid(heli.passenger):
		if heli.passenger.alive:
			heli.passenger.get_parent().remove_child(heli.passenger)  # leaves with the heli
			heli.passenger.queue_free()
	heli.passenger = null
	if heli.passenger_perch != null and is_instance_valid(heli.passenger_perch):
		heli.passenger_perch.queue_free()
	heli.passenger_perch = null


func _on_heli_gone(heli: AssaultHeli) -> void:
	_clear_sniper(heli)
	_heli_ropes.erase(heli)


# --- Breach ----------------------------------------------------------------------------------

## Intact Breach_<n> markers (not used yet), else unused ENTRY points (fx only).
func _breach_candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _rt == null or _rt.map == null:
		return out
	for m: Node3D in AssaultEventMarkers.list(_rt.map, AssaultEventMarkers.BREACH):
		if not _breach_used.has(_map_path(m)):
			out.append(m)
	if not out.is_empty() or not AssaultEventMarkers.list(_rt.map, AssaultEventMarkers.BREACH).is_empty():
		return out
	for n: Node in _rt.map.get_slots(G.ENTRY_POINT):
		var n3: Node3D = n as Node3D
		if n3 != null and not _entry_used.has(_map_path(n3)):
			out.append(n3)
	return out


func _run_breach(p: Dictionary, marker: String) -> AssaultEventEntity:
	var cands: Array[Node3D] = _breach_candidates()
	if marker != "":
		cands = cands.filter(func(m: Node3D) -> bool: return String(m.name) == marker)
	if cands.is_empty():
		return null
	var c: Vector3 = _crew_centroid()
	var best: Node3D = null
	var best_d: float = INF
	for m: Node3D in cands:
		var exit: Vector3 = m.global_transform * Vector3(0, 0, -1.0)
		var d: float = exit.distance_to(c)
		if d < best_d:
			best_d = d
			best = m
	var is_marker: bool = AssaultEventMarkers.list(_rt.map, AssaultEventMarkers.BREACH).has(best)
	var path: String = _map_path(best)
	var b: AssaultBreach = AssaultBreach.new()
	if is_marker:
		_breach_used[path] = b
		p["marker"] = path
		p["breach_kind"] = String(best.get_meta(&"kind", "wall"))
		p["size"] = best.get_meta(&"size", Vector2(1.0, 2.2))
	else:
		_entry_used[path] = true
		p["marker"] = ""
		p["fx_only"] = true
		p["breach_kind"] = "wall"
	p["_marker"] = String(best.name)
	_add_entity(b, AssaultEventsTweak.KIND_BREACH, p, best.global_transform.orthonormalized())
	b.blown.connect(_on_breach_blown.bind(p))
	b.start()
	return b


func _on_breach_blown(b: AssaultBreach, p: Dictionary) -> void:
	var ids: Array = p.get("squad", []) as Array
	if ids.is_empty():
		return
	var delay: float = float(p.get("squad_delay_s", 0.8))
	var interval: float = float(p.get("squad_interval_s", 0.5))
	var side: Vector3 = b.global_basis.x.normalized()
	for i: int in range(ids.size()):
		var off: Vector3 = side * 0.7 * ceilf(float(i) * 0.5) * (1.0 if i % 2 == 1 else -1.0)
		var legs: Array[Dictionary] = []
		var spawn: Vector3
		match b.breach_kind if not bool(p.get("fx_only", false)) else "fx":
			"window":
				var entry: Vector3 = b.point("EntryPoint")
				spawn = b.point("RopeAnchor") - Vector3(0, 1.7, 0)
				legs = [{"to": entry + Vector3(0, 2.0, 0), "rappel": true}, {"to": b.point("ExitPoint") + off * 0.5, "rappel": true}]
			"ceiling":
				spawn = b.global_position + b.global_basis.z.normalized() * 0.9
				legs = [{"to": b.point("ExitPoint") + off * 0.5, "rappel": true, "speed": 3.5}]
			"fx":
				spawn = b.global_position + off
			_:
				spawn = b.point("EntryPoint") + off
		_queue.append({"t": delay + interval * i, "id": StringName(ids[i]),
			"xf": Transform3D(b.global_basis, spawn), "legs": legs, "kind": AssaultEventsTweak.KIND_BREACH, "owner": b})


# --- Units ---------------------------------------------------------------------------------------

func _queue_squad(ids: Array, xf: Transform3D, legs: Array[Dictionary], kind: StringName, owner: Node, interval: float) -> void:
	var side: Vector3 = xf.basis.x.normalized()
	for i: int in range(ids.size()):
		var off: Vector3 = side * 0.8 * ceilf(float(i) * 0.5) * (1.0 if i % 2 == 1 else -1.0)
		_queue.append({"t": interval * i, "id": StringName(ids[i]), "xf": Transform3D(xf.basis, xf.origin + off),
			"legs": legs, "kind": kind, "owner": owner})


func _tick_queue(delta: float) -> void:
	for i: int in range(_queue.size() - 1, -1, -1):
		var q: Dictionary = _queue[i]
		q["t"] = float(q["t"]) - delta
		if float(q["t"]) > 0.0:
			continue
		_queue.remove_at(i)
		var npc: NpcBase = _spawn_unit(q["id"], q["xf"], q["kind"])
		var legs: Array[Dictionary] = []
		legs.assign(q["legs"] as Array)
		var owner: Node = q.get("owner") as Node
		if npc == null:
			_rope_done(owner)
			continue
		if not legs.is_empty():
			_guides.append({"npc": npc, "legs": legs, "i": 0, "owner": owner, "started": false})


func _under_cap() -> bool:
	return director.alive_count() < director.enemy_cap()


func _spawn_unit(id: StringName, xf: Transform3D, kind: StringName) -> NpcBase:
	if not _under_cap():
		return null
	var def: EnemyDef = director.enemy_def_for(id)
	if def == null or not director.roster.can_spawn_special(def):
		return null
	var npc: NpcBase = director.spawn_enemy(def, xf, null, {"assault_event": kind})
	if npc != null:
		units.append(npc)
		unit_spawned.emit(kind, npc)
	return npc


## Guided legs (rope descent / a short walk the navmesh cannot do). The unit's NpcMotor is paused and its
## `rappelling` flag drives the `rappel` clip on descending legs; the motor resumes at the last leg.
func _tick_guides(delta: float) -> void:
	for gi: int in range(_guides.size() - 1, -1, -1):
		var g: Dictionary = _guides[gi]
		var npc: NpcBase = g["npc"] as NpcBase
		var motor: NpcMotor = npc.get_node_or_null(^"Motor") as NpcMotor if is_instance_valid(npc) else null
		if not is_instance_valid(npc) or not npc.alive or motor == null:
			if motor != null:
				_release(npc, motor)
			_land(g)
			_guides.remove_at(gi)
			continue
		if not bool(g["started"]):
			g["started"] = true
			motor.set_physics_process(false)
		var legs: Array[Dictionary] = g["legs"]
		var leg: Dictionary = legs[int(g["i"])]
		var wait: AssaultBreach = leg.get("wait_breach") as AssaultBreach
		if wait != null and is_instance_valid(wait) and not wait.is_blown():
			motor.rappelling = false
			npc.velocity = Vector3.ZERO
			continue
		motor.rappelling = bool(leg.get("rappel", false))
		var to: Vector3 = leg["to"]
		var speed: float = float(leg.get("speed", 3.0 if motor.rappelling else WALK_SPEED_MPS))
		var d: Vector3 = to - npc.global_position
		var step: float = speed * delta
		npc.velocity = Vector3.ZERO
		if d.length() > step:
			npc.global_position += d.normalized() * step
			var flat: Vector3 = _flat(d)
			if not motor.rappelling and flat.length() > 0.05:
				npc.global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)
			continue
		npc.global_position = to
		if bool(leg.get("landed", false)):
			_land(g)
		g["i"] = int(g["i"]) + 1
		if int(g["i"]) >= legs.size():
			_release(npc, motor)
			_guides.remove_at(gi)


func _release(npc: NpcBase, motor: NpcMotor) -> void:
	motor.rappelling = false
	motor.set_physics_process(true)
	if is_instance_valid(npc):
		npc.velocity = Vector3.ZERO


## A heli rope unit is down (or gone): the heli leaves once all are.
func _land(g: Dictionary) -> void:
	if bool(g.get("landed_done", false)):
		return
	g["landed_done"] = true
	_rope_done(g.get("owner") as Node)


func _rope_done(owner: Node) -> void:
	var heli: AssaultHeli = owner as AssaultHeli
	if heli == null or not is_instance_valid(heli) or not _heli_ropes.has(heli):
		return
	_heli_ropes[heli] = int(_heli_ropes[heli]) - 1
	if int(_heli_ropes[heli]) <= 0:
		heli.drop_done = true


# --- Helpers -----------------------------------------------------------------------------------

func _pick_markers(prefix: String, marker: String) -> Array[Node3D]:
	var ms: Array[Node3D] = AssaultEventMarkers.list(_rt.map, prefix)
	if marker != "":
		ms = ms.filter(func(m: Node3D) -> bool: return String(m.name) == marker)
	return ms


func _map_path(n: Node) -> String:
	return String(_rt.map.get_path_to(n))


func _crew_centroid() -> Vector3:
	var s: Vector3 = Vector3.ZERO
	var n: int = 0
	for c: CrewController in _rt.crew_members():
		if c.crew_state != Enums.CrewState.CUSTODY:
			s += c.global_position
			n += 1
	return s / float(n) if n > 0 else Vector3.ZERO


func _nearest_police_spawn(skip: Array[Node3D]) -> Node3D:
	var c: Vector3 = _crew_centroid()
	var best: Node3D = null
	var best_d: float = INF
	for n: Node in _rt.map.get_slots(G.POLICE_SPAWN):
		var p: Node3D = n as Node3D
		if p == null or skip.has(p):
			continue
		var d: float = p.global_position.distance_to(c)
		if d < best_d:
			best_d = d
			best = p
	return best


## First world floor straight below `p` (at most down to min_y - 1), else (p.x, min_y, p.z).
func _floor_below(p: Vector3, min_y: float) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p - Vector3(0, 0.3, 0),
		Vector3(p.x, min_y - 1.0, p.z), RappelLinks.WORLD_MASK)
	var hit: Dictionary = _rt.map.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] as Vector3 if not hit.is_empty() else Vector3(p.x, min_y, p.z)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
