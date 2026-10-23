## D-138.3: every placed device is visible. (1) Every prefab class that creates a DeviceRunner (discovered by
## scanning res://systems and res://world/heists for `DeviceRunner.new(`) shows a device node while its runner is
## RUNNING / JAMMED and removes it when done; a new runner class without a case here fails. (2) Audit of the five
## heist maps (instantiated, not entered): every drill / saw / thermal-capable prefab instance resolves a device
## scene. Prints AUDIT lines (which spots ran an own runner, i.e. had no visual before D-138.3).
extends TestCase

const SCAN_DIRS: Array[String] = ["res://systems", "res://world/heists"]
const NEEDLE: String = "DeviceRunner" + ".new("
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"gallery_night",
	&"dockside_burn"]

var _rt: HeistRuntime = null


func after_each() -> void:
	Modifiers.clear_source(Modifiers.TEAM, &"test_d138v")
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## class_name -> [[prefab id, setup, runner kind], ...]: one case per device kind the class can run.
func _cases() -> Dictionary:
	return {
		&"DrillPoint": [
			["drill_point", func(p: GameplayPrefab) -> void: (p as DrillPoint).device = DrillPoint.Device.DRILL, &"drill"],
			["drill_point", func(p: GameplayPrefab) -> void: (p as DrillPoint).device = DrillPoint.Device.THERMAL, &"thermal"],
			["drill_point", func(p: GameplayPrefab) -> void: (p as DrillPoint).device = DrillPoint.Device.SAW, &"saw"],
		],
		&"Safe": [
			["safe", func(p: GameplayPrefab) -> void: (p as Safe).methods = [&"drill"] as Array[StringName], &"drill"],
			["safe", func(p: GameplayPrefab) -> void: (p as Safe).methods = [&"saw"] as Array[StringName], &"saw"],
		],
		&"Padlock": [
			["padlock", func(p: GameplayPrefab) -> void: (p as Padlock).place_saw = true, &"saw"],
			["padlock", func(p: GameplayPrefab) -> void: (p as Padlock).place_drill = true, &"drill"],
		],
	}


func _runner_classes() -> Array[StringName]:
	var out: Array[StringName] = []
	var dirs: Array[String] = SCAN_DIRS.duplicate()
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		var da: DirAccess = DirAccess.open(d)
		if da == null:
			continue
		for sub: String in da.get_directories():
			dirs.append(d.path_join(sub))
		for f: String in da.get_files():
			if not f.ends_with(".gd"):
				continue
			var path: String = d.path_join(f)
			if not FileAccess.get_file_as_string(path).contains(NEEDLE):
				continue
			var s: Script = load(path) as Script
			var cn: StringName = s.get_global_name() if s != null else &""
			out.append(cn if cn != &"" else StringName(path))
	return out


func test_every_runner_class_shows_its_device() -> void:
	_rt = await HeistLauncher.launch(&"unit_d138_visuals", 1383, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	Modifiers.set_source(Modifiers.TEAM, &"test_d138v", {&"interaction.device_jam_chance_mult": 0.0})
	await wait_physics_frames(2)
	var classes: Array[StringName] = _runner_classes()
	assert_true(classes.size() >= 3, "found the runner classes (%s)" % [classes])
	var cases: Dictionary = _cases()
	var x: float = -8.0
	for cn: StringName in classes:
		assert_true(cases.has(cn), "%s creates a DeviceRunner: add its device-visual case here (D-138.3)" % cn)
		for c: Array in cases.get(cn, []):
			x += 2.5
			var p: GameplayPrefab = ATestMaps.add_prefab(_rt, String(c[0]), Vector3(x, 0, -5), c[1] as Callable)
			await wait_physics_frames(1)
			var label: String = "%s/%s" % [cn, c[2]]
			var r: DeviceRunner = p.get(&"runner") as DeviceRunner
			assert_true(r != null, "%s has a runner" % label)
			if r == null:
				continue
			assert_eq(r.kind, c[2], "%s runner kind" % label)
			assert_true(p.get(&"device_node") == null, "%s: no device while idle" % label)
			r.place(-1, 30.0)
			await wait_physics_frames(1)
			var dn: Node3D = p.get(&"device_node") as Node3D
			assert_true(dn != null and dn.is_visible_in_tree(), "%s: the device is shown while running" % label)
			assert_true(dn != null and not dn.find_children("*", "MeshInstance3D", true, false).is_empty(),
				"%s: the device has meshes" % label)
			if p is Padlock and dn != null:  # PO-14 review (D cb022207): blade / bit stand off the door leaf
				var want: float = Padlock.SAW_OUT_M if c[2] == &"saw" else Padlock.DRILL_OUT_M
				assert_true(absf(dn.position.z - want) < 0.001, "%s: device %.2f m out of the lock" % [label, want])
			r.abort()
			await wait_physics_frames(1)
			assert_true(p.get(&"device_node") == null, "%s: removed when done" % label)


## [kind, scene override, label] device spots of one map prefab instance ([] = none).
static func _spots(n: Node) -> Array:
	var dp: DrillPoint = n as DrillPoint
	if dp != null:
		return [[dp.device_kind(), dp.device_scene, "drill_point"]]
	var pl: Padlock = n as Padlock
	if pl != null:
		var out: Array = []
		if pl.place_saw:
			out.append([&"saw", pl.device_scene, "padlock"])
		if pl.place_drill:
			out.append([&"drill", pl.device_scene, "padlock"])
		return out
	var s: Safe = n as Safe
	if s == null or not (s.methods.has(&"drill") or s.methods.has(&"saw")):
		return []
	var kind: StringName = &"drill" if s.methods.has(&"drill") else &"saw"
	for d: Node in s.find_children("*", "", true, false):
		var sdp: DrillPoint = d as DrillPoint
		if sdp != null and s.methods.has(sdp.device_kind()) and not sdp.target.is_empty() \
				and sdp.get_node_or_null(sdp.target) == s:
			return []  # PO6-01: the safe places its own drill_point's device (audited as that drill_point)
	return [[kind, s.device_scene, "safe own runner (no visual before D-138.3)"]]


func test_audit_heist_device_spots_resolve_a_device() -> void:
	var total: int = 0
	for h: StringName in HEISTS:
		var path: String = HeistLauncher.map_path(h)
		if not ResourceLoader.exists(path):
			print("AUDIT %s: no map at %s" % [h, path])
			continue
		var root: Node = (load(path) as PackedScene).instantiate()
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c: Node in n.get_children():
				stack.append(c)
			for spot: Array in _spots(n):
				total += 1
				var scene: PackedScene = DeviceVisual.scene_for(spot[0], spot[1])
				print("AUDIT %s %s %s kind=%s device=%s" % [h, root.get_path_to(n), spot[2], spot[0],
					scene.resource_path if scene != null else "NONE"])
				assert_true(scene != null, "%s %s (%s): resolvable %s device scene" % [h, root.get_path_to(n), spot[2], spot[0]])
		root.free()
	assert_true(total > 0, "audited some device spots")


## PO report (OF LidDrill): a spot whose map set the device art as its `visual_scene` showed the drill standing there
## before anyone placed it. The spot shows only its mark at rest; the art becomes the placed device, its bit axis
## (-Z, tip at the origin) along the spot's -Z into the target.
func test_device_art_as_a_spot_visual_shows_only_once_placed() -> void:
	_rt = await HeistLauncher.launch(&"unit_d138_visuals", 1384, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	Modifiers.set_source(Modifiers.TEAM, &"test_d138v", {&"interaction.device_jam_chance_mult": 0.0})
	await wait_physics_frames(2)
	var art: PackedScene = load(G.PROPS_DIR + DrillPoint.DEFAULT_THERMAL) as PackedScene
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1, -5), func(p: GameplayPrefab) -> void:
		(p as DrillPoint).device = DrillPoint.Device.THERMAL
		p.visual_scene = art
		p.rotation_degrees = Vector3(0, -90, 0)) as DrillPoint
	await wait_physics_frames(1)
	assert_true(dp.device_node == null, "no device before placement")
	assert_true(dp.visual_instance == null or dp.visual_instance.find_child("Model", true, false) == null,
		"the rest visual is the mark, not the drill art")
	assert_eq(dp.device_scene, art, "the art becomes the placed device")
	dp.runner.place(-1, 30.0)
	await wait_physics_frames(1)
	assert_true(dp.device_node != null and dp.device_node.is_visible_in_tree(), "shown once placed")
	if dp.device_node != null:
		var bit_axis: Vector3 = -dp.device_node.global_basis.z
		assert_true(bit_axis.dot(-dp.global_basis.z) > 0.999, "the bit points along the spot's -Z (%s)" % bit_axis)
		assert_true(dp.device_node.global_position.distance_to(dp.global_position) < 0.001, "tip at the spot")
	dp.runner.abort()


static func _xf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## PO report (OF drill): every map drill spot with a `target` faces it (its -Z, the placed device's bit axis, within
## 60 degrees of the direction to the target), and none uses device art as its rest visual. AUDIT lines list spots
## without a target (mission-opened: their facing is the map's call).
func test_audit_drill_spots_face_their_target() -> void:
	var heists: Array[StringName] = HEISTS.duplicate()
	heists.append_array([&"ostrander_federal", &"rolling_thunder", &"afterhours"])
	var checked: int = 0
	for h: StringName in heists:
		var path: String = HeistLauncher.map_path(h)
		if not ResourceLoader.exists(path):
			continue
		var root: Node = (load(path) as PackedScene).instantiate()
		for n: Node in root.find_children("*", "DrillPoint", true, false):
			var dp: DrillPoint = n as DrillPoint
			var at: Transform3D = _xf(dp)
			var label: String = "%s %s" % [h, root.get_path_to(dp)]
			if dp.visual_scene != null and DrillPoint._is_device_art(dp.visual_scene):
				print("AUDIT FINDING %s: device art as visual_scene (%s): set device_scene" % [label,
					dp.visual_scene.resource_path])
			var t: Node3D = dp.get_node_or_null(dp.target) as Node3D if not dp.target.is_empty() else null
			if t == null:
				print("AUDIT %s: no target; faces %s at %s" % [label, -at.basis.z.normalized(), at.origin])
				continue
			var bit: Vector3 = -at.basis.z.normalized()
			var cos_a: float = 1.0
			if t is Door:  # a door's origin is its hinge: the bit must cross the leaf (along the door's normal)
				cos_a = absf(bit.dot(_xf(t).basis.z.normalized()))
			else:
				var to: Vector3 = _xf(t).origin - at.origin
				to.y = 0.0
				cos_a = bit.dot(to.normalized()) if to.length() > 0.5 else 1.0  # ATM cash sits in the saw spot
			print("AUDIT %s -> %s cos %.2f" % [label, t.name, cos_a])
			assert_true(cos_a > 0.5, "%s faces its target %s (cos %.2f)" % [label, t.name, cos_a])
			checked += 1
		root.free()
	assert_true(checked > 3, "audited targeted drill spots (%d)" % checked)
