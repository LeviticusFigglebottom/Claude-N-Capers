## Ostrander Federal loud nav targets (LEAD round 254: GPU-10's loud run logged ~1,500 navmesh "most reachable
## polygon" errors, stealth 0; Godot 4.7 logs one per path query to an unreachable target). On the built map in a real
## HeistRuntime, loud, in the burn state (lid off, rope ladder and hoist on) and fully breached (every door unlocked
## and open), every loud-phase walk target is on the navmesh and reachable from a police spawn: the police spawns, the
## AssaultEvents markers (turret vans, heli drops, each breach's room-side approach and the street outside it), the
## Tactical points (SNIPER_POSTS excepted: snipers hold rooftop posts), the escape / secure zones and their wait
## markers, the ladder ends and the lift UsePoints. Off-mesh = the closest navmesh point is more than OFF_H_M away flat
## or OFF_V_M vertically; disconnected = the uncapped path from REF_SPAWN stops more than REACH_M short of it; each
## police spawn also reaches the street outside every wall / door breach. Owner: ENV C.
extends TestCase

const HEIST: StringName = &"ostrander_federal"
const SEED: int = 1002
## Paths are taken from this police spawn (the street network; the others connect to it, checked as targets).
const REF_SPAWN: NodePath = ^"Spawns/P1"
## Rooftop sniper posts: snipers spawn there and hold (no walk to or from the street by design).
const SNIPER_POSTS: Array[String] = ["SniperAssay", "SniperGarage", "SniperTower"]
const OFF_H_M: float = 0.6
const OFF_V_M: float = 1.2
const REACH_M: float = 0.5
## A breach's room-side approach: this far into the room along the marker's -Z.
const BREACH_IN_M: float = 1.0
## Police agents' layers in loud (NpcMotor D-122; the assault director queries the same): walkable + the breach layer,
## which carries the police-only rappel links (P5's roof island reaches the street only through them).
const POLICE_LAYERS: int = 1 | Door.NAV_LAYER_BREACH

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_loud_targets_on_nav_and_connected() -> void:
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % HEIST)
		return
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	_rt.isolate_npc(null)
	var lid: GameplayPrefab = _rt.map.get_node_or_null(^"Gameplay/Devices/Lid") as GameplayPrefab
	if lid != null:
		lid.set_enabled(false)
	for p: NodePath in [^"Gameplay/Ladders/RopeLadder", ^"Gameplay/Lifts/Hoist"]:
		var n: Node = _rt.map.get_node_or_null(p)
		if n != null and n.has_method(&"set_enabled"):
			n.call(&"set_enabled", true)
	_rt.stealth.raise_alarm(&"test", 0)
	for n: Node in _rt.map.find_children("*", "Door", true, false):
		var d: Door = n as Door
		if d.is_visible_in_tree():
			d.unlock()
			d.set_open(true, true)
			d.finish_swing()
	await wait_physics_frames(10)
	var nav: RID = c.get_world_3d().navigation_map
	var ref: Vector3 = NavigationServer3D.map_get_closest_point(nav, (_rt.map.get_node(REF_SPAWN) as Node3D).global_position)
	var bad: PackedStringArray = PackedStringArray()
	var targets: Array[Array] = _targets()
	for t: Array in targets:
		var label: String = String(t[0])
		var want: Vector3 = t[1]
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
		var flat: float = Vector2(p.x - want.x, p.z - want.z).length()
		if flat > OFF_H_M or absf(p.y - want.y) > OFF_V_M:
			bad.append("OFF-MESH %s at %s (closest nav %s, %.2f m flat, %.2f m up)" % [label, want, p, flat, p.y - want.y])
			continue
		if label.begins_with("Spawns/P"):
			continue   # police spawn islands join the street by one-way links: origins, checked below
		var end: Vector3 = _path_end(nav, ref, p)
		if end.distance_to(p) > REACH_M:
			bad.append("DISCONNECTED %s at %s (path from the police spawn ends at %s, %.1f m short)" % [label, p, end,
				end.distance_to(p)])
	var ae: Node = _rt.map.get_node_or_null(^"AssaultEvents")
	for sp: Array in targets:   # each police spawn reaches the street outside every wall / door breach
		if not String(sp[0]).begins_with("Spawns/P"):
			continue
		var from: Vector3 = NavigationServer3D.map_get_closest_point(nav, sp[1])
		for mk: Node in ae.get_children() if ae != null else []:
			if not String(mk.name).begins_with("Breach_") or String((mk as Node3D).get_meta(&"kind", "")) == "ceiling":
				continue
			var out_at: Vector3 = NavigationServer3D.map_get_closest_point(nav,
				(mk as Node3D).global_transform * Vector3(0.0, 0.0, 1.5))
			var e2: Vector3 = _path_end(nav, from, out_at)
			if e2.distance_to(out_at) > REACH_M:
				bad.append("POLICE %s cannot reach the street outside %s (%.1f m short)" % [sp[0], mk.name,
					e2.distance_to(out_at)])
	for line: String in bad:
		print("  loud nav: " + line)
	print("  loud nav: %d targets, %d bad" % [targets.size(), bad.size()])
	assert_true(targets.size() >= 40, "targets collected (%d)" % targets.size())
	assert_true(bad.is_empty(), "%d loud targets off the navmesh or disconnected (see the log)" % bad.size())


## [label, world point] for every loud-phase walk target.
func _targets() -> Array[Array]:
	var out: Array[Array] = []
	var m: Node = _rt.map
	var spawns: Node = m.get_node_or_null(^"Spawns")
	if spawns != null:
		for s: Node in spawns.get_children():
			if s is Marker3D and String(s.name).begins_with("P") and not String(s.name).begins_with("Player") \
					and not String(s.name).begins_with("Plaza"):
				out.append(["Spawns/" + String(s.name), (s as Node3D).global_position])
	var ae: Node = m.get_node_or_null(^"AssaultEvents")
	if ae != null:
		for mk: Node in ae.get_children():
			var n3: Node3D = mk as Node3D
			if n3 == null or String(mk.name).begins_with("HeliOrbit"):
				continue
			var at: Vector3 = n3.global_position
			if String(mk.name).begins_with("Breach_"):
				at = n3.global_transform * Vector3(0.0, 0.0, -BREACH_IN_M)
				if String(n3.get_meta(&"kind", "")) == "ceiling":
					at = Vector3(n3.global_position.x, n3.global_position.y - 3.0, n3.global_position.z)
			out.append(["AssaultEvents/" + String(mk.name), at])
			if String(mk.name).begins_with("Breach_") and String(n3.get_meta(&"kind", "")) != "ceiling":
				out.append(["AssaultEvents/%s outside" % mk.name, n3.global_transform * Vector3(0.0, 0.0, 1.5)])
	var tac: Node = m.get_node_or_null(^"Tactical")
	if tac != null:
		for t: Node in tac.find_children("*", "Node3D", true, false):
			if t.get_child_count() == 0 and not String(t.name) in SNIPER_POSTS:
				out.append([String(tac.get_path_to(t)), (t as Node3D).global_position])
	var esc: Node = m.get_node_or_null(^"Variants/Group_escape")
	if esc != null:
		for z: Node in esc.find_children("*", "Area3D", true, false):
			out.append([String(m.get_path_to(z)), (z as Node3D).global_position])
		for w: Node in esc.find_children("EscapeWait*", "Marker3D", true, false):
			out.append([String(m.get_path_to(w)), (w as Node3D).global_position])
	for p: String in ["Gameplay/Ladders", "Gameplay/Lifts"]:
		var g: Node = m.get_node_or_null(NodePath(p))
		if g == null:
			continue
		for n: Node in g.find_children("*", "Node3D", true, false):
			var nm: String = String(n.name)
			if nm in ["Bottom", "Top", "UsePoint"]:
				out.append([String(m.get_path_to(n)), (n as Node3D).global_position])
	return out


## The end of the police navmesh path a -> b (POLICE_LAYERS), searched without Godot's default 4096-polygon cap (OF's navmesh has ~4,165
## polygons, so a long capped search stops at the "most reachable" polygon; that is GPU-10's error, a query setting,
## not a map fault).
static func _path_end(nav: RID, a: Vector3, b: Vector3) -> Vector3:
	var qp: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
	qp.map = nav
	qp.start_position = a
	qp.target_position = b
	qp.navigation_layers = POLICE_LAYERS
	qp.path_search_max_polygons = 0
	var qr: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(qp, qr)
	return qr.path[qr.path.size() - 1] if not qr.path.is_empty() else a
