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
## ENV D PO6-17 clip names (characters.md; AnimDriver.FALLBACK_CLIPS until they land).
const CLIP_RAPPEL_HANG: StringName = &"rappel_hang"
const CLIP_RAPPEL_DESCEND: StringName = &"rappel_descend"
const CLIP_RAPPEL_LAND: StringName = &"rappel_land"
const CLIP_VAN_EXIT: StringName = &"van_exit"
const CLIP_BREACH_PLACE: StringName = &"breach_place"
const CLIP_BREACH_STANDBACK: StringName = &"breach_standback"

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
	var ms: Array[Node3D] = _pick_markers(AssaultEventMarkerScan.VAN, marker)
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
	var exit_legs: Array[Dictionary] = [{"hold_s": tweak.van_exit_s, "anim": CLIP_VAN_EXIT}]
	van.on_dismount = func(ids: Array, exit: Transform3D) -> void: _queue_squad(ids, exit, exit_legs,
		AssaultEventsTweak.KIND_TURRET_VAN, van, p.get("squad_interval_s", 0.7))
	_add_entity(van, AssaultEventsTweak.KIND_TURRET_VAN, p, xf)
	van.start(xf)
	return van


# --- Helicopter --------------------------------------------------------------------------------

func _run_heli(p: Dictionary, marker: String) -> AssaultEventEntity:
	var center: Vector3
	var radius: float = float(p.get("orbit_radius_m", 24.0))
	var orbits: Array[Node3D] = _pick_markers(AssaultEventMarkerScan.HELI_ORBIT, "")
	if not orbits.is_empty():
		var o: Node3D = orbits[GameRng.stream(RNG).randi_range(0, orbits.size() - 1)]
		center = o.global_position
		radius = float(o.get_meta(&"radius", radius))
	else:
		var b: AABB = AssaultEventMarkerScan.map_bounds(_rt.map)
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
	for m: Node3D in _pick_markers(AssaultEventMarkerScan.HELI_DROP, marker):
		var pos: Vector3 = m.global_position
		if AssaultEventMarkerScan.nav_point(_rt.map, pos, 1.2) != Vector3.INF:
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
	for m: Node3D in AssaultEventMarkerScan.list(_rt.map, AssaultEventMarkerScan.BREACH):
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
	var speed: float = float(p.get("rappel_speed_mps", 3.0))
	for i: int in range(ids.size()):
		var a: Vector3 = anchors[i % anchors.size()]
		var land: Vector3 = _floor_below(a, float(drop["pos"].y))
		var face: Vector3 = _flat(heli.global_position - a)  # hang outside the door, facing the rope / cabin
		face = face.normalized() if face.length() > 0.05 else -heli.global_basis.x
		var bottom: Vector3 = Vector3(a.x, land.y, a.z)
		var top_y: float = a.y - tweak.rope_chest_height_m - 0.3
		var legs: Array[Dictionary] = [{"to": _rope_root(a, bottom, top_y, face), "rappel": true, "speed": speed}]
		legs.append({"to": _rope_root(a, bottom, land.y, face), "rappel": true, "speed": speed, "landed": true})
		legs.append({"hold_s": tweak.rappel_land_s, "anim": CLIP_RAPPEL_LAND})
		if breach != null:
			legs.append_array(_ceiling_legs(breach, Vector3.ZERO, true))
		_queue.append({"t": interval * i, "id": StringName(ids[i]),
			"xf": Transform3D(Basis.looking_at(face, Vector3.UP), legs[0]["to"]), "legs": legs, "face": face,
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
	for m: Node3D in AssaultEventMarkerScan.list(_rt.map, AssaultEventMarkerScan.BREACH):
		if not _breach_used.has(_map_path(m)):
			out.append(m)
	if not out.is_empty() or not AssaultEventMarkerScan.list(_rt.map, AssaultEventMarkerScan.BREACH).is_empty():
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
	var is_marker: bool = AssaultEventMarkerScan.list(_rt.map, AssaultEventMarkerScan.BREACH).has(best)
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
	_queue_breach_placer(b, p)
	return b


## Ceiling: the rope hangs from above the hole down through it to ExitPoint; units (optionally walking over from
## the breach's roof EntryPoint first) clip on above the hole, wait for the blast, slide down, land.
func _ceiling_legs(b: AssaultBreach, off: Vector3, walk_in: bool) -> Array[Dictionary]:
	var up: Vector3 = b.global_basis.z.normalized()
	var face: Vector3 = b.global_basis.y.normalized()
	var top: Vector3 = b.global_position + up * (1.0 + tweak.rope_chest_height_m)
	var bottom: Vector3 = b.point("ExitPoint")
	b.set_rope(top, bottom)
	var hang_y: float = b.global_position.y + up.y * 0.7
	var legs: Array[Dictionary] = []
	if walk_in:
		legs.append({"to": b.point("EntryPoint"), "rappel": false})
	legs.append({"to": _rope_root(top, bottom, hang_y, face) + off, "rappel": false, "face": face})
	legs.append({"to": _rope_root(top, bottom, hang_y, face) + off, "wait_breach": b, "anim": CLIP_RAPPEL_HANG})
	legs.append({"to": _rope_root(top, bottom, bottom.y, face) + off, "rappel": true, "speed": 3.5})
	legs.append({"hold_s": tweak.rappel_land_s, "anim": CLIP_RAPPEL_LAND})
	return legs


func _on_breach_blown(b: AssaultBreach, p: Dictionary) -> void:
	var ids: Array = p.get("squad", []) as Array
	var kind: String = b.breach_kind if not bool(p.get("fx_only", false)) else "fx"
	if bool(p.get("_placer", false)) and not ids.is_empty():
		ids = ids.slice(1)  # the charge placer is already there (it walks in with the squad)
	if ids.is_empty():
		return
	var delay: float = float(p.get("squad_delay_s", 0.8))
	var interval: float = float(p.get("squad_interval_s", 0.5))
	var side: Vector3 = b.global_basis.x.normalized()
	var into: Vector3 = -b.global_basis.z.normalized()
	for i: int in range(ids.size()):
		var off: Vector3 = side * 0.7 * ceilf(float(i) * 0.5) * (1.0 if i % 2 == 1 else -1.0)
		var legs: Array[Dictionary] = []
		var spawn: Vector3
		var face: Vector3 = _flat(into).normalized() if _flat(into).length() > 0.05 else Vector3.FORWARD
		match kind:
			"window":
				# Down the rope from the parapet to sill height, then swing in through the opening.
				var anchor: Vector3 = b.point("RopeAnchor")
				var entry: Vector3 = b.point("EntryPoint")
				b.set_rope(anchor, entry)
				spawn = _rope_root(anchor, entry, anchor.y - tweak.rope_chest_height_m - 0.3, face)
				legs = [{"to": _rope_root(anchor, entry, entry.y + 2.0, face), "rappel": true},
					{"to": b.point("ExitPoint") + off * 0.5, "rappel": true},
					{"hold_s": tweak.rappel_land_s, "anim": CLIP_RAPPEL_LAND}]
			"ceiling":
				legs = _ceiling_legs(b, off * 0.4, false)
				face = b.global_basis.y.normalized()
				spawn = legs[0]["to"]
			"fx":
				spawn = b.global_position + off
			_:
				spawn = b.point("EntryPoint") + off
		_queue.append({"t": delay + interval * i, "id": StringName(ids[i]), "face": face,
			"xf": Transform3D(Basis.looking_at(_flat(face).normalized() if _flat(face).length() > 0.05 else Vector3.FORWARD,
				Vector3.UP), spawn), "legs": legs, "kind": AssaultEventsTweak.KIND_BREACH, "owner": b})


## A wall / fx breach: the squad's first unit plants the charge at warning start (breach_place, then crouches
## back in breach_standback until the blast; it walks in with the squad).
func _queue_breach_placer(b: AssaultBreach, p: Dictionary) -> void:
	var ids: Array = p.get("squad", []) as Array
	if ids.is_empty() or b.breach_kind != "wall":
		return
	var face: Vector3 = _flat(-b.global_basis.z)
	face = face.normalized() if face.length() > 0.05 else Vector3.FORWARD
	var stand: Vector3 = b.point("EntryPoint") if not bool(p.get("fx_only", false)) else b.global_position - face * 0.9
	var aside: Vector3 = stand + b.global_basis.x.normalized() * 0.9
	p["_placer"] = true
	var legs: Array[Dictionary] = [{"hold_s": tweak.breach_place_s, "anim": CLIP_BREACH_PLACE},
		{"to": aside, "rappel": false, "face": face},
		{"to": aside, "wait_breach": b, "anim": CLIP_BREACH_STANDBACK}]
	_queue.append({"t": 0.0, "id": StringName(ids[0]), "face": face,
		"xf": Transform3D(Basis.looking_at(face, Vector3.UP), stand), "legs": legs,
		"kind": AssaultEventsTweak.KIND_BREACH, "owner": b})


# --- Units ---------------------------------------------------------------------------------------

func _queue_squad(ids: Array, xf: Transform3D, legs: Array[Dictionary], kind: StringName, owner: Node, interval: float) -> void:
	var side: Vector3 = xf.basis.x.normalized()
	var face: Vector3 = _flat(-xf.basis.z)
	for i: int in range(ids.size()):
		var off: Vector3 = side * 0.8 * ceilf(float(i) * 0.5) * (1.0 if i % 2 == 1 else -1.0)
		_queue.append({"t": interval * i, "id": StringName(ids[i]), "xf": Transform3D(xf.basis, xf.origin + off),
			"legs": legs, "kind": kind, "owner": owner, "face": face.normalized() if face.length() > 0.05 else Vector3.ZERO})


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
			_guides.append({"npc": npc, "legs": legs, "i": 0, "owner": owner, "started": false,
				"face": q.get("face", Vector3.ZERO), "hold": 0.0})


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


## Guided legs (rope descent / a short walk the navmesh cannot do / a timed clip in place). The unit's NpcMotor
## is paused (its `rappelling` flag on descending legs); clips go through AnimDriver.META_ANIM_OVERRIDE (ENV D's
## PO6-17 names: rappel_hang / rappel_descend / rappel_land / van_exit / breach_place / breach_standback, with
## fallbacks in AnimDriver.FALLBACK_CLIPS). Leg keys: to, rappel, speed, landed, wait_breach, face, anim, hold_s.
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
			_face(npc, g.get("face", Vector3.ZERO) as Vector3)
		if _step_leg(g, npc, motor, delta):
			g["i"] = int(g["i"]) + 1
			g["hold"] = 0.0
			if int(g["i"]) >= (g["legs"] as Array).size():
				_release(npc, motor)
				_guides.remove_at(gi)


## Advance the current leg; true when it is done.
func _step_leg(g: Dictionary, npc: NpcBase, motor: NpcMotor, delta: float) -> bool:
	var leg: Dictionary = (g["legs"] as Array)[int(g["i"])]
	npc.velocity = Vector3.ZERO
	if leg.has("face"):
		_face(npc, leg["face"] as Vector3)
	if leg.has("hold_s"):
		motor.rappelling = false
		_set_anim(npc, StringName(leg.get("anim", &"")))
		g["hold"] = float(g["hold"]) + delta
		return float(g["hold"]) >= float(leg["hold_s"])
	var wait: AssaultBreach = leg.get("wait_breach") as AssaultBreach
	if wait != null and is_instance_valid(wait) and not wait.is_blown():
		motor.rappelling = false
		_set_anim(npc, StringName(leg.get("anim", &"")))
		return false
	if leg.has("wait_breach"):
		return true  # the wait is over (its position was reached by the leg before)
	var rope: bool = bool(leg.get("rappel", false))
	motor.rappelling = rope
	_set_anim(npc, CLIP_RAPPEL_DESCEND if rope else StringName(leg.get("anim", &"")))
	var to: Vector3 = leg["to"]
	var speed: float = float(leg.get("speed", 3.0 if rope else WALK_SPEED_MPS))
	var d: Vector3 = to - npc.global_position
	var step: float = speed * delta
	if d.length() > step:
		npc.global_position += d.normalized() * step
		if not rope:
			npc.velocity = d.normalized() * speed  # locomotion clip (the paused motor does not move it)
			if not leg.has("face"):
				_face(npc, d)
		return false
	npc.global_position = to
	if bool(leg.get("landed", false)):
		_land(g)
	return true


func _face(npc: NpcBase, dir: Vector3) -> void:
	var f: Vector3 = _flat(dir)
	if f.length() > 0.05:
		npc.global_basis = Basis.looking_at(f.normalized(), Vector3.UP)


## AnimDriver.META_ANIM_OVERRIDE (&"" clears it).
static func _set_anim(npc: NpcBase, clip: StringName) -> void:
	if clip == &"":
		if npc.has_meta(AnimDriver.META_ANIM_OVERRIDE):
			npc.remove_meta(AnimDriver.META_ANIM_OVERRIDE)
	elif npc.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"") != clip:
		npc.set_meta(AnimDriver.META_ANIM_OVERRIDE, clip)


## Root of a unit on the rope top -> bottom at root height `root_y`, facing `face`: chest + hand offset forward
## lies on the rope line (ENV D's rappel clips hold the hands rope_hand_offset_m in front of the chest).
func _rope_root(top: Vector3, bottom: Vector3, root_y: float, face: Vector3) -> Vector3:
	var chest_y: float = root_y + tweak.rope_chest_height_m
	var t: float = clampf((top.y - chest_y) / maxf(top.y - bottom.y, 0.001), 0.0, 1.0)
	var p: Vector3 = top.lerp(bottom, t)
	var f: Vector3 = _flat(face).normalized() if _flat(face).length() > 0.01 else Vector3.ZERO
	return Vector3(p.x, root_y, p.z) - f * tweak.rope_hand_offset_m


func _release(npc: NpcBase, motor: NpcMotor) -> void:
	motor.rappelling = false
	motor.set_physics_process(true)
	if is_instance_valid(npc):
		npc.velocity = Vector3.ZERO
		_set_anim(npc, &"")


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
	var ms: Array[Node3D] = AssaultEventMarkerScan.list(_rt.map, prefix)
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
