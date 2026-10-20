## PO6-17 (D-114 §5): RNG assault events (turret van, helicopter, breach points). Schedule determinism and the
## row rules over many seeds (AssaultEventScheduler, pure), each kind executed on a small map with ENV C-style
## markers, and Golden Hour firing an event in sustain. Every event unit wears a real character (no capsule), the
## ropes are single straight lines retracted on touch, and EventBus.assault_event_started / _ended [R] fire.
extends TestCase

const HEIST: StringName = &"unit_events"
const CREW_POS: Vector3 = Vector3(0.0, 0.05, -6.0)
const DIRECTOR_TWEAK: String = "res://systems/director/director_tweak.tres"
const EVENTS_TWEAK: String = "res://systems/director/assault_events_tweak.tres"
## C's CuePlayer plays these on assault_event_started / _ended: A must not request them too (doubles).
const C_OWNED_CUES: Array[StringName] = [&"cue.assault_van_arrive", &"cue.assault_heli_arrive", &"cue.assault_heli_leave",
	&"cue.assault_breach_warning"]

var _rt: HeistRuntime = null
var _started: Array[Array] = []
var _ended: Array[Array] = []
var _cues: Array[StringName] = []


func _on_cue(cue_id: StringName, _pos: Vector3, _src: int) -> void:
	_cues.append(cue_id)


func _on_started(kind: StringName, net_id: int, pos: Vector3) -> void:
	_started.append([kind, net_id, pos])
	var n: Node = Ids.lookup(net_id)
	assert_true(n is AssaultEventEntity and (n as AssaultEventEntity).kind == kind,
		"started net_id %d resolves (Ids.lookup) to the %s entity (C's loops follow it)" % [net_id, kind])


func _on_ended(kind: StringName, net_id: int) -> void:
	_ended.append([kind, net_id])


func _listen() -> void:
	_started.clear()
	_ended.clear()
	_cues.clear()
	if not EventBus.assault_event_started.is_connected(_on_started):
		EventBus.assault_event_started.connect(_on_started)
		EventBus.assault_event_ended.connect(_on_ended)
		EventBus.audio_cue_requested.connect(_on_cue)


func _has_fact(facts: Array[Array], kind: StringName, net_id: int) -> bool:
	return facts.any(func(f: Array) -> bool: return f[0] == kind and int(f[1]) == net_id)


## Lead review: every event unit resolves a real character visual (an animated rig), never the capsule placeholder.
func _assert_real_visuals(ev: AssaultEventRunner, what: String) -> void:
	var n: int = 0
	for u: NpcBase in ev.units:
		if not is_instance_valid(u):
			continue
		n += 1
		assert_true(u.visual_scene != null and AnimDriver.find_player(u) != null,
			"%s unit %s wears a character (%s), not a capsule" % [what, u.name, u.visual_scene.resource_path if u.visual_scene else "null"])
	assert_true(n > 0, "%s: units to check" % what)


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.assault_event_started.is_connected(_on_started):
		for c: StringName in C_OWNED_CUES:
			assert_false(_cues.has(c), "%s is C's (played on the started / ended fact), never requested by A" % c)
		EventBus.assault_event_started.disconnect(_on_started)
		EventBus.assault_event_ended.disconnect(_on_ended)
		EventBus.audio_cue_requested.disconnect(_on_cue)
	Modifiers.clear_source(0, &"po6_17.immune")
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


# --- Schedule (pure) -------------------------------------------------------------------------------

static func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"kind": &"turret_van", "weight": 1.0, "min_wave": 2, "cooldown_s": 150.0, "max_per_heist": 1})
	out.append({"kind": &"heli", "weight": 2.0, "min_wave": 1, "cooldown_s": 90.0, "max_per_heist": 2})
	out.append({"kind": &"breach", "weight": 3.0, "min_wave": 1, "cooldown_s": 45.0, "max_per_heist": 4})
	return out


static func _tw() -> AssaultEventsTweak:
	var tw: AssaultEventsTweak = (load(EVENTS_TWEAK) as AssaultEventsTweak).duplicate(true) as AssaultEventsTweak
	tw.first_event_wave = 1
	tw.first_event_delay_s = 8.0
	tw.roll_interval_s = 10.0
	tw.chance_per_roll = PackedFloat32Array([0.6])
	tw.min_gap_s = 20.0
	tw.max_active = 9
	return tw


## Four PD2-shaped waves (CONTROL 20 / ANTICIPATION 30 / BUILD 35 / SUSTAIN 120 / FADE 15) at 0.5 s steps.
static func _simulate(seed_v: int, tw: AssaultEventsTweak, rows_in: Array[Dictionary]) -> AssaultEventScheduler:
	var s: AssaultEventScheduler = AssaultEventScheduler.new()
	s.setup(tw, rows_in, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([seed_v, "assault_events"])
	var plan: Array[Vector2] = [Vector2(Enums.AssaultPhase.CONTROL, 20), Vector2(Enums.AssaultPhase.ANTICIPATION, 30),
		Vector2(Enums.AssaultPhase.BUILD, 35), Vector2(Enums.AssaultPhase.SUSTAIN, 120), Vector2(Enums.AssaultPhase.FADE, 15)]
	for wave: int in range(1, 5):
		for ph: Vector2 in plan:
			for i: int in range(int(ph.y * 2.0)):
				s.tick(0.5, int(ph.x), wave, 0, rng)
	return s


func test_po6_17_same_seed_same_schedule() -> void:
	var tw: AssaultEventsTweak = _tw()
	var a: Array[Dictionary] = _simulate(1234, tw, _rows()).schedule
	var b: Array[Dictionary] = _simulate(1234, tw, _rows()).schedule
	assert_true(a.size() > 0, "events fired (%d)" % a.size())
	assert_eq(a, b, "same seed -> same schedule")
	var differs: int = 0
	for sd: int in range(1, 21):
		if _simulate(sd, tw, _rows()).schedule != a:
			differs += 1
	assert_true(differs >= 15, "other seeds give other schedules (%d / 20)" % differs)


func test_po6_17_rules_over_many_seeds() -> void:
	var tw: AssaultEventsTweak = _tw()
	var rows_in: Array[Dictionary] = _rows()
	var counts: Dictionary = {}
	var total: int = 0
	var bad: Array[String] = []
	# Wave 1 sustain starts at 20 + 30 + 35 = 85 s; one wave = 220 s.
	for sd: int in range(400):
		var sch: Array[Dictionary] = _simulate(sd, tw, rows_in).schedule
		var last_row: Dictionary = {}
		var last_any: float = -INF
		var per_row: Dictionary = {}
		for ev: Dictionary in sch:
			var row: Dictionary = rows_in[int(ev["row"])]
			var t: float = float(ev["t"])
			var wave: int = int(ev["wave"])
			var ph: int = int(ev["phase"])
			total += 1
			counts[ev["kind"]] = int(counts.get(ev["kind"], 0)) + 1
			per_row[ev["row"]] = int(per_row.get(ev["row"], 0)) + 1
			if wave < int(row["min_wave"]):
				bad.append("seed %d: %s in wave %d < min_wave" % [sd, ev["kind"], wave])
			if last_row.has(ev["row"]) and t - float(last_row[ev["row"]]) < float(row["cooldown_s"]) - 0.001:
				bad.append("seed %d: %s cooldown broken" % [sd, ev["kind"]])
			if t - last_any < tw.min_gap_s - 0.001:
				bad.append("seed %d: min gap broken" % sd)
			if int(per_row[ev["row"]]) > int(row["max_per_heist"]):
				bad.append("seed %d: %s over max_per_heist" % [sd, ev["kind"]])
			if not AssaultEventScheduler.eligible(tw, ph, wave):
				bad.append("seed %d: event in phase %d wave %d" % [sd, ph, wave])
			if wave == 1 and t < 85.0 + tw.first_event_delay_s - 0.001:
				bad.append("seed %d: first event before wave-1 sustain + delay (%.1f)" % [sd, t])
			last_row[ev["row"]] = t
			last_any = t
	print("[PO6-17] 400 seeds: %d events %s" % [total, counts])
	assert_true(bad.is_empty(), "rules hold: %s" % [bad.slice(0, 5)])
	for k: StringName in [&"turret_van", &"heli", &"breach"]:
		assert_true(int(counts.get(k, 0)) > 0, "%s fires on some seeds" % k)


func test_po6_17_pick_weights() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var rows_in: Array[Dictionary] = _rows()
	var fired: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var last: PackedFloat32Array = PackedFloat32Array([-INF, -INF, -INF])
	var n: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for i: int in range(30000):
		n[AssaultEventScheduler.pick_row(rng, rows_in, 3, 1000.0, fired, last)] += 1
	for i: int in range(3):
		var want: float = float(rows_in[i]["weight"]) / 6.0
		assert_near(float(n[i]) / 30000.0, want, 0.015, "row %d share ~ weight" % i)
	# min_wave / blocked / max / cooldown filter rows out.
	assert_eq(AssaultEventScheduler.pick_row(rng, rows_in, 1, 1000.0, fired, last, [&"heli", &"breach"] as Array[StringName]), -1,
		"van needs wave 2; others blocked")
	assert_eq(AssaultEventScheduler.pick_row(rng, rows_in, 2, 1000.0, PackedInt32Array([1, 2, 4]), last), -1, "all at max")
	assert_eq(AssaultEventScheduler.pick_row(rng, rows_in, 2, 100.0, fired, PackedFloat32Array([0.0, 50.0, 70.0])), -1,
		"all cooling down")


# --- Test map ------------------------------------------------------------------------------------

## basic() + a wall along X at z = 0 (crew room at z < 0) with a 1 m breach opening at x = 0 closed by a C-style
## breach scene (Visual/Model/Intact/Collision, Blown hidden, markers), a navmesh baked with the opening shut,
## police spawns behind the wall and AssaultEvents markers.
static func _map() -> PackedScene:
	var root: HeistMap = ATestMaps.basic(0, 0).instantiate() as HeistMap
	var geo: Node3D = root.get_node("Geometry")
	for side: float in [-1.0, 1.0]:
		var w: StaticBody3D = StaticBody3D.new()
		w.name = "Wall%s" % ("W" if side < 0.0 else "E")
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(14.5, 3.0, 0.2)
		cs.shape = bs
		w.add_child(cs)
		w.position = Vector3(side * (0.5 + 7.25), 1.5, 0.1)
		geo.add_child(w)
	# An upper slab (underside 3.0, top 3.2, off the navmesh) with a 1.2 m ceiling breach at (0, 3, -9).
	for spec: Array in [[Vector3(-2.3, 3.1, -9.0), Vector3(3.4, 0.2, 10.0)], [Vector3(2.3, 3.1, -9.0), Vector3(3.4, 0.2, 10.0)],
			[Vector3(0.0, 3.1, -11.8), Vector3(1.2, 0.2, 4.4)], [Vector3(0.0, 3.1, -6.2), Vector3(1.2, 0.2, 4.4)]]:
		var sl: StaticBody3D = StaticBody3D.new()
		sl.name = "Slab"
		var scs: CollisionShape3D = CollisionShape3D.new()
		var sbs: BoxShape3D = BoxShape3D.new()
		sbs.size = spec[1]
		scs.shape = sbs
		sl.add_child(scs)
		sl.position = spec[0]
		geo.add_child(sl, true)
	var plug: StaticBody3D = StaticBody3D.new()  # the bake sees the opening shut (C: infill = obstruction)
	plug.name = "BakePlug"
	var pcs: CollisionShape3D = CollisionShape3D.new()
	var pbs: BoxShape3D = BoxShape3D.new()
	pbs.size = Vector3(1.0, 3.0, 0.2)
	pcs.shape = pbs
	plug.add_child(pcs)
	plug.position = Vector3(0, 1.5, 0.1)
	geo.add_child(plug)
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	root.add_child(nav)
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.3
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.filter_baking_aabb = AABB(Vector3(-15.0, -1.0, -15.0), Vector3(30.0, 4.0, 30.0))
	var holder: Node3D = Node3D.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(holder)
	holder.add_child(root)
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, geo)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	holder.remove_child(root)
	holder.free()
	nav.navigation_mesh = nm
	geo.remove_child(plug)
	plug.free()
	var spawns: Node3D = root.get_node("Spawns")
	for x: float in [-9.0, 9.0]:
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = "Police%d" % int(x)
		sp.kind = SpawnPoint.Kind.POLICE
		sp.position = Vector3(x, 0.05, 12.0)
		spawns.add_child(sp)
	var ae: Node3D = Node3D.new()
	ae.name = "AssaultEvents"
	root.add_child(ae)
	var van: Marker3D = Marker3D.new()
	van.name = "TurretVan_1"
	van.position = Vector3(9.0, 0.0, -12.0)
	van.rotation.y = -PI * 0.5  # +Z (nose) = -X
	ae.add_child(van)
	var orbit: Marker3D = Marker3D.new()
	orbit.name = "HeliOrbit_1"
	orbit.position = Vector3(0.0, 18.0, -6.0)
	orbit.set_meta(&"radius", 12.0)
	ae.add_child(orbit)
	var drop: Marker3D = Marker3D.new()
	drop.name = "HeliDrop_1"
	drop.position = Vector3(-6.0, 0.0, -9.0)
	ae.add_child(drop)
	var br: Marker3D = Marker3D.new()
	br.name = "Breach_1"
	br.position = Vector3.ZERO  # -Z into the crew room
	br.set_meta(&"kind", "wall")
	br.set_meta(&"size", Vector2(1.0, 2.2))
	ae.add_child(br)
	var vis: Node3D = AssaultBreach._placeholder("wall", Vector2(1.0, 2.2))
	vis.name = "Visual"
	br.add_child(vis)
	var ceil: Marker3D = Marker3D.new()
	ceil.name = "Breach_2"
	ceil.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 3.0, -9.0))  # -Z down, +Y north
	ceil.set_meta(&"kind", "ceiling")
	ceil.set_meta(&"size", Vector2(1.2, 1.2))
	ae.add_child(ceil)
	var cvis: Node3D = AssaultBreach._placeholder("ceiling", Vector2(1.2, 1.2))
	cvis.name = "Visual"
	ceil.add_child(cvis)
	var roof_drop: Marker3D = Marker3D.new()
	roof_drop.name = "HeliDrop_2"
	roof_drop.position = Vector3(2.5, 3.2, -6.5)  # on the slab: off the navmesh (pairs with Breach_2)
	ae.add_child(roof_drop)
	for c: Node in root.get_children():
		_own(c, root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


static func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c: Node in n.get_children():
		_own(c, root)


func _launch(before_alarm: Callable = Callable()) -> AssaultEventRunner:
	var dt: DirectorTweak = (load(DIRECTOR_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	dt.first_control_s = 600.0
	dt.first_responder_groups = 0
	dt.control_special_groups = []
	dt.captain_chance = 0.0
	_rt = await HeistLauncher.launch(HEIST, 617, Enums.Difficulty.ROUTINE, self,
		{"map_packed": _map(), "ai_teammates": 0, "director_tweak": dt, "captain": false})
	assert_true(_rt != null, "launched")
	assert_true(await ATestMaps.await_nav_synced(_rt), "navmesh synced")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, CREW_POS))
	Modifiers.set_source(0, &"po6_17.immune", {&"defense.damage_taken_mult": 0.0})
	await wait_physics_frames(2)
	_listen()
	if before_alarm.is_valid():
		before_alarm.call()
	_rt.stealth.raise_alarm(&"test", 0)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(await wait_until(func() -> bool: return dir.running, 3.0), "director running")
	return dir.events


func test_po6_17_turret_van_deploys_shoots_and_can_be_destroyed() -> void:
	var ev: AssaultEventRunner = await _launch()
	var van: AssaultTurretVan = ev.run(&"turret_van", {"drive_in_s": 1.0, "deploy_s": 0.5, "aim_delay_s": 0.3,
		"squad": [&"enemy.tac_light"]}) as AssaultTurretVan
	assert_true(van != null, "van spawned")
	assert_true(van.net_id != 0 and van.get_parent() == _rt.dynamic_root, "replicated dynamic entity")
	var start: Vector3 = van.global_position
	var active: bool = await wait_until(func() -> bool: return van.stage == AssaultTurretVan.Stage.ACTIVE, 6.0)
	assert_true(active, "van parked, doors open, turret deployed")
	assert_true(van.global_position.distance_to(Vector3(9.0, 0.0, -12.0)) < 0.05, "parked on the marker")
	assert_true(start.distance_to(van.global_position) > 15.0, "drove in")
	assert_true(van.turret.position.y > -0.01, "turret raised")
	assert_true(van.door_l.rotation.y < -1.5, "rear door open")
	assert_true(ev.units.size() >= 1, "squad dismounted")
	assert_eq(ev.units[0].get_meta(AnimDriver.META_ANIM_OVERRIDE, &""), &"van_exit", "van_exit clip")
	assert_true(_has_fact(_started, &"turret_van", van.net_id), "assault_event_started(turret_van) %s" % [_started])
	var exit: Vector3 = van.exit_transform().origin
	var stepped: bool = await wait_until(func() -> bool:
		var u: NpcBase = ev.units[0]
		return is_instance_valid(u) and u.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"") == &"" \
			and Vector2(u.global_position.x - exit.x, u.global_position.z - exit.z).length() < 0.9, 3.0)
	assert_true(stepped, "van_exit carried the unit 0.6 m out onto the landing spot")
	_assert_real_visuals(ev, "van squad")
	var shot: bool = await wait_until(func() -> bool: return van.turret.hits_landed > 0, 8.0)
	print("[PO6-17] turret shots %d hits %d" % [van.turret.shots_fired, van.turret.hits_landed])
	assert_true(shot, "turret shoots the crew")
	assert_true(van.turret.target == _rt.crew_members()[0], "targets the crew member")
	# Armor first from the front; the rear weak spot skips armor.
	var body_hb: Hitbox = van.turret.find_child("HitBody", true, false) as Hitbox
	var weak_hb: Hitbox = van.turret.find_child("HitWeakSpot", true, false) as Hitbox
	var r: Dictionary = CombatSystem.deliver_hit(Damage.find_target(body_hb),
		Damage.info(100.0, Enums.DamageType.BULLET, Damage.zone_of(body_hb), &"t", Vector3.ZERO, Vector3.FORWARD, 0), 0)
	assert_true(bool(r.get("armor_hit", false)) and van.turret.health == van.turret.max_health, "front hit: armor")
	var guard: int = 0
	while not van.turret.destroyed and guard < 200:
		CombatSystem.deliver_hit(Damage.find_target(weak_hb), Damage.info(150.0, Enums.DamageType.BULLET,
			Damage.zone_of(weak_hb), &"t", Vector3.ZERO, Vector3.FORWARD, 0), 0)
		guard += 1
	assert_true(van.turret.destroyed, "destroyed through the weak spot (%d hits)" % guard)
	assert_true(van.turret.armor_hp > 0.0, "weak spot skipped the armor")
	assert_eq(van.stage, AssaultTurretVan.Stage.DESTROYED, "van stage DESTROYED")
	assert_false(ev.active.has(van), "event over")
	assert_true(_has_fact(_ended, &"turret_van", van.net_id), "assault_event_ended(turret_van)")
	var shots: int = van.turret.shots_fired
	await wait_physics_frames(20)
	assert_eq(van.turret.shots_fired, shots, "a dead turret does not fire")
	assert_true(NetEntityCodec.xform_of(van) is Transform3D, "van transform replicates")


func test_po6_17_heli_rappels_a_squad_at_the_drop_and_carries_a_sniper() -> void:
	var ev: AssaultEventRunner = await _launch()
	Engine.time_scale = 2.0
	var heli: AssaultHeli = ev.run(&"heli", {"orbit_s": 0.5, "speed_mps": 40.0, "approach_m": 40.0, "hover_height_m": 8.0,
		"sniper_s": 30.0, "squad": [&"enemy.tac_light", &"enemy.tac_light"], "drop_interval_s": 0.3,
		"rappel_speed_mps": 5.0}, "HeliDrop_1") as AssaultHeli
	assert_true(heli != null, "heli spawned")
	var hover: bool = await wait_until(func() -> bool: return heli.stage == AssaultHeli.Stage.HOVER, 10.0)
	assert_true(hover, "heli hovers over the drop")
	assert_true(heli.ropes.size() == 2 and heli.ropes[0].visible and heli.ropes[1].visible, "two ropes out")
	for i: int in range(2):
		var rope: MeshInstance3D = heli.ropes[i]
		var anchor: Vector3 = (heli.rope_l if i == 0 else heli.rope_r).global_position
		var top: Vector3 = rope.global_position + Vector3(0, (rope.mesh as CylinderMesh).height * 0.5, 0)
		assert_true(rope.global_basis.is_equal_approx(Basis.IDENTITY), "rope %d is one straight vertical line" % i)
		assert_true(top.distance_to(anchor) < 0.05, "rope %d hangs from its davit" % i)
		assert_near(rope.global_position.y - (rope.mesh as CylinderMesh).height * 0.5, 0.0, 0.05, "rope %d reaches the floor" % i)
	assert_true(_has_fact(_started, &"heli", heli.net_id), "assault_event_started(heli)")
	var roping: bool = await wait_until(func() -> bool:
		for u: NpcBase in ev.units:
			var m: NpcMotor = u.get_node_or_null(^"Motor") as NpcMotor
			if m != null and m.rappelling and u.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"") == &"rappel_descend":
				return true
		return false, 4.0)
	assert_true(roping, "a unit is on the rope (rappel_descend clip)")
	var down: bool = await wait_until(func() -> bool: return heli.drop_done, 8.0)
	assert_true(down, "squad down")
	var drop: Vector3 = Vector3(-6.0, 0.0, -9.0)
	var landing: bool = await wait_until(func() -> bool:
		return ev.units.any(func(u: NpcBase) -> bool: return u.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"") == &"rappel_land"), 1.0)
	assert_true(landing, "rappel_land on touchdown")
	# Condition-based: both rappellers on the drop's floor (within the rope spread) with their motor back on.
	var both: bool = await wait_until(func() -> bool: return _rappellers_down(ev, drop) == 2, 6.0)
	for u: NpcBase in ev.units:
		if is_instance_valid(u):
			var m2: NpcMotor = u.get_node_or_null(^"Motor") as NpcMotor
			print("[PO6-17] rappeller at %s (flat %.2f from drop) motor on %s" % [u.global_position,
				Vector2(u.global_position.x - drop.x, u.global_position.z - drop.z).length(), m2 != null and m2.is_physics_processing()])
	var landed: int = 2 if both else _rappellers_down(ev, drop)
	assert_eq(landed, 2, "both rappellers landed at the drop and walk on")
	if is_instance_valid(heli):
		assert_false(heli.ropes[0].visible or heli.ropes[1].visible, "ropes retracted once everyone touched down")
	# The sniper window is long (30 s) so a loaded batch cannot see the heli leave before the checks below.
	var sniping: bool = await wait_until(func() -> bool: return is_instance_valid(heli) and heli.passenger != null, 6.0)
	assert_true(sniping, "Longshot seated")
	if not sniping:
		return
	var sniper: NpcBase = heli.passenger
	assert_eq(sniper.enemy_def.id, &"enemy.longshot", "Longshot def")
	await wait_physics_frames(5)
	var brain: LongshotBrain = sniper.get_node(^"Brain") as LongshotBrain
	assert_true(brain.is_perched(), "perched on the heli perch")
	assert_true(String(sniper.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"")).begins_with("heli_door_"), "heli_door clip")
	var kneel: Vector3 = heli.seat_transform() * Vector3(0.5, -0.344, 0.15)
	assert_true(sniper.global_position.distance_to(kneel) < 0.05, "kneel root = SniperSeat x heli_door_sill offset")
	_assert_real_visuals(ev, "heli rope squad + Longshot")
	var heli_id: int = heli.net_id
	heli.stage_time = 999.0  # end the (long) sniper window now
	var wr: WeakRef = weakref(heli)
	var gone: bool = await wait_until(func() -> bool:
		var h: AssaultHeli = wr.get_ref() as AssaultHeli
		return h == null or h.stage >= AssaultHeli.Stage.LEAVE, 8.0)
	assert_true(gone, "heli leaves")
	var freed: bool = await wait_until(func() -> bool: return wr.get_ref() == null, 10.0)
	assert_true(freed and _has_fact(_ended, &"heli", heli_id), "assault_event_ended(heli) once it left (%s)" % [_ended])
	await wait_physics_frames(2)
	assert_false(is_instance_valid(sniper) and sniper.is_inside_tree(), "sniper leaves with it")


## P OF-A6 run: rappellers freed mid-rope (police despawned) drop out of the guides cleanly; casting the freed
## reference logged "Trying to cast a freed object" every tick (12,891 times) and never cleared the guide.
func test_po6_17_guides_drop_freed_rappellers() -> void:
	var ev: AssaultEventRunner = await _launch()
	var heli: AssaultHeli = ev.run(&"heli", {"orbit_s": 0.5, "speed_mps": 40.0, "approach_m": 40.0, "hover_height_m": 8.0,
		"sniper_s": 30.0, "squad": [&"enemy.tac_light", &"enemy.tac_light"], "drop_interval_s": 0.3,
		"rappel_speed_mps": 1.0}, "HeliDrop_1") as AssaultHeli
	assert_true(heli != null, "heli spawned")
	var roping: bool = await wait_until(func() -> bool: return not ev._guides.is_empty(), 15.0)
	assert_true(roping, "a rappeller is guided")
	for u: NpcBase in ev.units:
		if is_instance_valid(u):
			u.queue_free()
	await wait_physics_frames(3)
	assert_true(ev._guides.is_empty(), "freed rappellers leave the guides (%d left)" % ev._guides.size())


func test_po6_17_breach_blows_open_and_squad_enters() -> void:
	var ev: AssaultEventRunner = await _launch()
	var marker: Node3D = _rt.map.get_node(^"AssaultEvents/Breach_1")
	var intact: Node3D = marker.get_node(^"Visual/Model/Intact")
	var blown: Node3D = marker.get_node(^"Visual/Model/Blown")
	var space: PhysicsDirectSpaceState3D = _rt.map.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, 1.5), Vector3(0, 1.0, -1.5), 1)
	assert_false(space.intersect_ray(ray).is_empty(), "intact: the opening blocks")
	var nav: RID = _rt.map.get_world_3d().navigation_map
	var outside: Vector3 = Vector3(0, 0, 3.0)
	var inside: Vector3 = Vector3(0, 0, -3.0)
	var p0: PackedVector3Array = NavigationServer3D.map_get_path(nav, outside, inside, true)
	assert_true(p0.is_empty() or p0[p0.size() - 1].distance_to(inside) > 1.0, "no nav path through the intact wall")
	var b: AssaultBreach = ev.run(&"breach", {"warning_s": 1.0, "squad": [&"enemy.tac_light", &"enemy.tac_light"]},
		"Breach_1") as AssaultBreach
	assert_true(b != null and b.stage == AssaultBreach.Stage.WARNING, "warning")
	assert_false(b.charge_mesh.visible, "no charge before the placer's `place` event")
	assert_true(intact.visible and not blown.visible, "still intact in the warning")
	assert_true(_has_fact(_started, &"breach", b.net_id), "assault_event_started(breach)")
	var placing: bool = await wait_until(func() -> bool:
		return ev.units.any(func(u: NpcBase) -> bool: return u.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"") == &"breach_place"), 0.8)
	assert_true(placing, "the first squad unit plants the charge (breach_place)")
	var placer: NpcBase = ev.units[0]
	var charge: Vector3 = b.point("Charge")
	assert_near(Vector2(placer.global_position.x - charge.x, placer.global_position.z - charge.z).length(), 0.45, 0.05,
		"palms on the wall: the placer stands 0.45 m from it")
	var armed: bool = await wait_until(func() -> bool: return b.charge_mesh.visible, 1.5)
	assert_true(armed and b.stage_time >= 0.9, "the charge appears at the `place` event (%.2f s)" % b.stage_time)
	assert_true(b.charge_mesh.global_position.distance_to(charge) < 0.01, "on the wall at Charge (1.1 m)")
	var went: bool = await wait_until(func() -> bool: return b.is_blown(), 3.0)
	assert_true(went, "blown")
	assert_false(intact.visible, "Intact hidden")
	assert_true(blown.visible, "Blown shown")
	assert_true(_has_fact(_ended, &"breach", b.net_id), "assault_event_ended(breach) on the blast")
	assert_true(_cues.has(&"cue.c4_explode"), "cue.c4_explode at the detonation")
	await wait_physics_frames(2)
	assert_true(space.intersect_ray(ray).is_empty(), "the opening is clear")
	NavigationServer3D.map_force_update(nav)
	await wait_physics_frames(2)
	var p1: PackedVector3Array = NavigationServer3D.map_get_path(nav, outside, inside, true)
	assert_true(p1.size() >= 2 and p1[p1.size() - 1].distance_to(inside) < 0.6, "nav path through the hole (%s)" % [p1])
	var entered: bool = await wait_until(func() -> bool:
		for u: NpcBase in ev.units:
			if is_instance_valid(u) and u.global_position.z < -0.6:
				return true
		return false, 15.0)
	print("[PO6-17] breach squad %s" % [ev.units.map(func(u: NpcBase) -> Vector3: return u.global_position)])
	assert_eq(ev.units.size(), 2, "squad spawned")
	_assert_real_visuals(ev, "breach squad")
	assert_true(entered, "a unit came through the breach")
	assert_false(ev._breach_candidates().has(marker), "a blown breach is not picked again")


func test_po6_17_rows_from_heist_def_then_tweak() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = HEIST
	def.assault_events = [{"kind": &"breach", "weight": 1.0, "min_wave": 1, "cooldown_s": 10.0, "max_per_heist": 1,
		"params": {"warning_s": 0.5}}, {"kind": &"nonsense", "weight": 5.0}] as Array[Dictionary]
	var ev: AssaultEventRunner = await _launch(func() -> void: _rt.map.heist_def = def)
	assert_true(await wait_until(func() -> bool: return ev.begun, 3.0), "events began")
	assert_eq(ev.rows_source, &"heist_def", "HeistDef.assault_events is read first")
	assert_eq(ev.scheduler.rows.size(), 1, "same schema; unknown kinds dropped")
	assert_eq(ev.scheduler.rows[0]["kind"], &"breach", "the HeistDef row")
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	var et: AssaultEventsTweak = (load(EVENTS_TWEAK) as AssaultEventsTweak).duplicate(true) as AssaultEventsTweak
	et.heists = {HEIST: {"events": [{"kind": &"heli", "weight": 1.0, "min_wave": 1, "cooldown_s": 10.0, "max_per_heist": 1}]}}
	var empty_def: HeistDef = HeistDef.new()
	empty_def.id = HEIST
	var dt: DirectorTweak = (load(DIRECTOR_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	dt.first_control_s = 600.0
	dt.first_responder_groups = 0
	_rt = await HeistLauncher.launch(HEIST, 618, Enums.Difficulty.ROUTINE, self,
		{"map_packed": _map(), "ai_teammates": 0, "director_tweak": dt, "captain": false, "assault_events_tweak": et})
	_rt.map.heist_def = empty_def
	_rt.stealth.raise_alarm(&"test", 0)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(await wait_until(func() -> bool: return dir.events.begun, 3.0), "events began")
	assert_eq(dir.events.rows_source, &"tweak", "empty HeistDef rows: AssaultEventsTweak.heists[heist_id]")
	assert_eq(dir.events.scheduler.rows.size(), 1, "the tweak row")
	assert_eq(dir.events.scheduler.rows[0]["kind"], &"heli", "the tweak's heli row")


## assault_event_ended fires exactly once per started event on every path: the entity freed / removed early,
## the heist ending, and teardown (C keys the van engine / heli rotor loops on it by net id).
func test_po6_17_event_ended_once_on_free_end_and_teardown() -> void:
	var ev: AssaultEventRunner = await _launch()
	var van: AssaultTurretVan = ev.run(&"turret_van", {"squad": []}) as AssaultTurretVan
	var heli: AssaultHeli = ev.run(&"heli", {"drop": false, "sniper": false, "orbit_s": 999.0}) as AssaultHeli
	var ids: Array[int] = [van.net_id, heli.net_id]
	assert_true(_has_fact(_started, &"turret_van", ids[0]) and _has_fact(_started, &"heli", ids[1]), "both started")
	van.queue_free()  # removed early (no finish)
	await wait_frames(2)
	assert_eq(_count_ended(ids[0]), 1, "freed van: ended once")
	_rt.end_heist(false)  # heist over: the heli still on station ends with it
	await wait_frames(2)
	assert_eq(_count_ended(ids[1]), 1, "heist end: heli ended once")
	_rt.teardown()
	_rt = null
	await wait_frames(3)
	assert_eq(_count_ended(ids[0]), 1, "teardown does not repeat the van")
	assert_eq(_count_ended(ids[1]), 1, "teardown does not repeat the heli")
	# Teardown while an event is still running ends it (once).
	var ev2: AssaultEventRunner = await _launch()
	var heli2: AssaultHeli = ev2.run(&"heli", {"drop": false, "sniper": false, "orbit_s": 999.0}) as AssaultHeli
	var id2: int = heli2.net_id
	_rt.teardown()
	_rt = null
	await wait_frames(3)
	assert_eq(_count_ended(id2), 1, "teardown: a running heli ends exactly once (%s)" % [_ended])


func _count_ended(net_id: int) -> int:
	return _ended.filter(func(f: Array) -> bool: return int(f[1]) == net_id).size()


# --- Golden Hour ----------------------------------------------------------------------------------

func test_po6_17_gh_seeded_loud_run_fires_an_event_in_sustain() -> void:
	var dt: DirectorTweak = (load(DIRECTOR_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	dt.first_control_s = 2.0
	dt.anticipation_s = 2.0
	dt.build_s = 6.0
	dt.sustain_by_stage_s = PackedFloat32Array([120.0, 120.0, 120.0])
	var et: AssaultEventsTweak = (load(EVENTS_TWEAK) as AssaultEventsTweak).duplicate(true) as AssaultEventsTweak
	et.first_event_delay_s = 3.0
	et.roll_interval_s = 5.0
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "director_tweak": dt, "captain": false, "assault_events_tweak": et})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(5)
	for s: int in _rt.crew_members().size():
		Modifiers.set_source(s, &"po6_17.immune", {&"defense.damage_taken_mult": 0.0})
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	_listen()
	_rt.stealth.raise_alarm(&"test", 0)
	Engine.time_scale = 3.0
	var fired: bool = await wait_until(func() -> bool: return not dir.events.history.is_empty(), 40.0)
	for s: int in _rt.crew_members().size():
		Modifiers.clear_source(s, &"po6_17.immune")
	assert_true(fired, "an event fired (schedule %s)" % [dir.events.scheduler.schedule])
	var first: Dictionary = dir.events.scheduler.schedule[0]
	print("[PO6-17] GH first event %s" % [first])
	assert_eq(int(first["phase"]), Enums.AssaultPhase.SUSTAIN, "in the wave-1 sustain window")
	assert_true(dir.events.active.size() >= 1 or not dir.events.history.is_empty(), "it ran")
	assert_eq(dir.events.rows_source, &"tweak", "GH's HeistDef has no rows yet: the tweak's glasshouse rows")
	assert_true(_has_fact(_started, StringName(first["kind"]), int(dir.events.history[0]["net_id"])),
		"assault_event_started for it (%s)" % [_started])
	# Every kind runs on GH today (fallback markers until C's AssaultEvents land on trunk).
	for k: StringName in [&"turret_van", &"heli", &"breach"]:
		if dir.events.blocked_kinds().has(k):
			continue
		var e: AssaultEventEntity = dir.events.run(k)
		assert_true(e != null, "%s runs on GH" % k)


static func _below_hole(ev: AssaultEventRunner) -> int:
	var n: int = 0
	for u: NpcBase in ev.units:
		if not is_instance_valid(u) or not u.alive:
			continue
		var m: NpcMotor = u.get_node_or_null(^"Motor") as NpcMotor
		if u.global_position.y < 0.5 and Vector2(u.global_position.x, u.global_position.z + 9.0).length() < 2.5 \
				and m != null and m.is_physics_processing():
			n += 1
	return n


func test_po6_17_ceiling_breach_squad_drops_through() -> void:
	var ev: AssaultEventRunner = await _launch()
	var intact: Node3D = _rt.map.get_node(^"AssaultEvents/Breach_2/Visual/Model/Intact")
	var b: AssaultBreach = ev.run(&"breach", {"warning_s": 2.5, "squad": [&"enemy.tac_light", &"enemy.tac_light"]},
		"Breach_2") as AssaultBreach
	assert_true(b != null and b.breach_kind == "ceiling", "ceiling breach")
	var hanging: bool = await wait_until(func() -> bool:
		return not b.is_blown() and ev.units.size() == 2 and ev.units.all(func(u: NpcBase) -> bool:
			return u.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"") == &"rappel_hang"), 2.4)
	assert_true(hanging, "the squad hangs on the rope above the hole until the blast (rappel_hang)")
	assert_true(b.rope_mesh.visible and b.rope_mesh.global_basis.is_equal_approx(Basis.IDENTITY), "one straight vertical rope")
	assert_true(await wait_until(func() -> bool: return b.is_blown(), 3.0), "blown")
	assert_false(intact.visible, "Intact hidden")
	assert_true(b.link == null, "no walk link for a ceiling (rope drop)")
	var down: bool = await wait_until(func() -> bool: return _below_hole(ev) == 2, 8.0)
	print("[PO6-17] ceiling squad %s" % [ev.units.map(func(u: NpcBase) -> Vector3: return u.global_position)])
	assert_true(down, "both dropped through the hole to the floor below and walk on")
	assert_false(b.rope_mesh.visible, "rope retracted after the last touchdown")


func test_po6_17_heli_roof_drop_pairs_ceiling_breach() -> void:
	var ev: AssaultEventRunner = await _launch()
	Engine.time_scale = 2.0
	var heli: AssaultHeli = ev.run(&"heli", {"orbit_s": 0.3, "speed_mps": 40.0, "approach_m": 40.0, "hover_height_m": 7.0,
		"sniper": false, "squad": [&"enemy.tac_light", &"enemy.tac_light"], "drop_interval_s": 0.3, "rappel_speed_mps": 5.0},
		"HeliDrop_2") as AssaultHeli
	assert_true(heli != null and heli.do_drop, "heli with a roof drop")
	var paired: bool = await wait_until(func() -> bool:
		return ev.history.any(func(h: Dictionary) -> bool: return h["kind"] == &"breach" and String(h["marker"]).ends_with("Breach_2")), 10.0)
	assert_true(paired, "the off-nav roof drop blows the ceiling breach next to it (%s)" % [ev.history])
	var down: bool = await wait_until(func() -> bool: return _below_hole(ev) == 2, 20.0)
	print("[PO6-17] roof drop squad %s" % [ev.units.map(func(u: NpcBase) -> Vector3: return u.global_position)])
	assert_true(down, "roped onto the roof, then down through the breach to the floor")
	var wr: WeakRef = weakref(heli)
	assert_true(await wait_until(func() -> bool:
		var h: AssaultHeli = wr.get_ref() as AssaultHeli
		return h == null or h.stage >= AssaultHeli.Stage.LEAVE, 6.0), "heli leaves once the squad is down")


## PO6-17b (PD2 breaches stagger): the blast stuns NPCs within stun_radius_m with LOS and flashes crew in range
## (CrewHealth.flashed_left, replicated; LocalHudModel.flashed_s), stronger near the charge; out of range: nothing.
func test_po6_17b_breach_blast_stuns_npcs_and_flashes_crew() -> void:
	var ev: AssaultEventRunner = await _launch()
	var marker: Node3D = _rt.map.get_node(^"AssaultEvents/Breach_1")
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, marker.global_position + Vector3(0, 0.05, 3.0)))
	var near: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, marker.global_position + Vector3(1.5, 0.05, 2.5)), {})
	var far: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, marker.global_position + Vector3(0, 0.05, 25.0)), {})
	for g: NpcBase in [near, far]:
		g.max_health = 5000.0
		g.health = 5000.0
	await wait_physics_frames(3)
	var b: AssaultBreach = ev.run(&"breach", {"warning_s": 0.3, "damage": 0.0, "squad": []}, "Breach_1") as AssaultBreach
	assert_true(b != null, "breach running")
	var went: bool = await wait_until(func() -> bool: return b.is_blown(), 3.0)
	assert_true(went, "blown")
	await wait_physics_frames(1)
	assert_true(near.is_stunned(), "a civilian 3 m from the charge with LOS is stunned")
	for u: NpcBase in ev.units:
		assert_false(u.is_stunned(), "the breaching police are never stunned by their own charge")
	assert_false(far.is_stunned(), "an NPC 25 m away is not")
	assert_true(crew.health.flashed_left > 1.0, "the crew member 3 m away is flashed (%.2f s)" % crew.health.flashed_left)
	var hud: LocalHudModel = LocalHudModel.new()
	_rt.add_child(hud)
	hud.track(crew)
	assert_true(hud.flashed_s > 1.0, "HUD flashed_s %.2f" % hud.flashed_s)
	hud.queue_free()
	var left: float = crew.health.flashed_left
	await wait_seconds(0.5)
	assert_true(crew.health.flashed_left < left, "the flash wears off")


## Rope units (not the seated Longshot) standing on the floor within 2.5 m of `drop`, motor resumed.
static func _rappellers_down(ev: AssaultEventRunner, drop: Vector3) -> int:
	var n: int = 0
	for u: NpcBase in ev.units:
		if not is_instance_valid(u) or (u.enemy_def != null and u.enemy_def.id == &"enemy.longshot"):
			continue
		var m: NpcMotor = u.get_node_or_null(^"Motor") as NpcMotor
		var flat: float = Vector2(u.global_position.x - drop.x, u.global_position.z - drop.z).length()
		if flat < 2.5 and u.global_position.y < drop.y + 0.6 and m != null and m.is_physics_processing() and not m.rappelling:
			n += 1
	return n


## D-115 X-3: every loud heist has assault-event rows (turret van, heli, breach; OF per D-136.6); SL is stealth-only (N/A).
func test_po6_17_rows_for_every_loud_heist() -> void:
	var tw: AssaultEventsTweak = load("res://systems/director/assault_events_tweak.tres") as AssaultEventsTweak
	for h: StringName in [&"glasshouse", &"dockside_burn", &"night_deposit", &"gallery_night", &"ostrander_federal"]:
		assert_true(tw.heists.has(h), "%s has rows" % h)
		var kinds: Array = []
		for r: Dictionary in (tw.heists.get(h, {}) as Dictionary).get("events", []):
			kinds.append(r["kind"])
		for k: StringName in [&"turret_van", &"heli", &"breach"]:
			assert_true(kinds.has(k), "%s: %s row" % [h, k])
	assert_false(tw.heists.has(&"shadow_ledger"), "SL is stealth-only: no assault events (D-115)")


## OF Breach_3/4 (D-141 QC-i; C bb7e28b1): a `door` breach marker names a real Door (meta `door`, a NodePath from the
## marker): no breach geometry is spawned, the charge goes on the door's face, and the blast unlocks the door and blows
## it open.
func test_door_breach_blows_the_named_door_open() -> void:
	var ev: AssaultEventRunner = await _launch()
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(6.0, 0.0, -3.0), func(n: Node) -> void:
		(n as Door).lock = Door.Lock.LOCKPICK) as Door
	var mk: Marker3D = Marker3D.new()
	mk.name = "Breach_3"
	_rt.map.get_node(^"AssaultEvents").add_child(mk)
	mk.global_position = door.global_position
	mk.set_meta(&"kind", "door")
	mk.set_meta(&"size", Vector2(1.0, 2.1))
	mk.set_meta(&"door", String(mk.get_path_to(door)))
	await wait_physics_frames(2)
	assert_true(door.locked and not door.is_open, "the door starts locked and shut")
	var b: AssaultBreach = ev.run(&"breach", {"warning_s": 0.3, "damage": 0.0, "squad": []}, "Breach_3") as AssaultBreach
	assert_true(b != null, "door breach runs at Breach_3")
	if b == null:
		return
	assert_eq(b.breach_kind, "door", "kind door")
	assert_true(b.door == door, "resolved the marker's door")
	assert_true(b.visual == null, "no breach geometry in the doorway")
	var went: bool = await wait_until(func() -> bool: return b.is_blown(), 3.0)
	assert_true(went, "blown")
	await wait_physics_frames(2)
	assert_false(door.locked, "the blast unlocked the door")
	assert_true(door.is_open, "the blast blew the door open")
