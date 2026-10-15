## PO6-17 windowed review (not a test): each RNG assault event in a seeded Golden Hour loud run, saved as contact
## sheets. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 960x540 res://tests/a/_review/po6_17_events_capture.tscn -- --out=<dir>
## Writes <out>/po6_17_turret_van.jpg (driving in / deployed and firing), po6_17_heli.jpg (rappel drop / sniper
## orbit), po6_17_breach.jpg (warning / blast / squad entering). Until ENV C's AssaultEvents markers reach trunk
## the van and heli markers are injected at C's GH positions (docs/levels/_art/po6_17/README.md §5); the breach
## uses the runtime fallback (an ENTRY point, fx only) when the map has no Breach_<n>.
extends Node

const TILE: Vector2i = Vector2i(480, 270)

var _out: String = "user://po6_17"
var _rt: HeistRuntime = null
var _cam: Camera3D = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 1617, Enums.Difficulty.HAZARDOUS, self,
		{"skip_casing": true, "crew_ai": false, "captain": false, "assault_events": false})
	for s: int in _rt.crew_members().size():
		Modifiers.set_source(s, &"po6_17.immune", {&"defense.damage_taken_mult": 0.0})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(5.0, 0.05, 10.5)))
	_inject_markers()
	for n: Node in _rt.find_children("*", "Node3D", true, false):
		if n is FpViewmodel:
			(n as Node3D).visible = false  # third-person review shots
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_rt.add_child(_cam)
	_rt.stealth.raise_alarm(&"capture", 0)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	while not dir.running:
		await get_tree().physics_frame
	var ev: AssaultEventRunner = dir.events
	RenderingServer.render_loop_enabled = false
	await _van(ev)
	await _heli(ev)
	await _breach(ev)
	print("po6_17_capture: done -> %s" % _out)
	get_tree().quit(0)


## C's GH van / heli markers (README §5) when the map does not have them yet.
func _inject_markers() -> void:
	if AssaultEventMarkers.root(_rt.map) != null:
		return
	var ae: Node3D = Node3D.new()
	ae.name = AssaultEventMarkers.ROOT_NAME
	_rt.map.add_child(ae)
	var van: Marker3D = Marker3D.new()
	van.name = "TurretVan_1"
	ae.add_child(van)
	van.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.0, -0.15, 21.2))
	var orbit: Marker3D = Marker3D.new()
	orbit.name = "HeliOrbit_1"
	orbit.set_meta(&"radius", 24.0)
	ae.add_child(orbit)
	orbit.global_position = Vector3(9.0, 30.0, 8.0)
	var drop: Marker3D = Marker3D.new()
	drop.name = "HeliDrop_2"
	ae.add_child(drop)
	drop.global_position = Vector3(11.0, 0.0, -3.6)
	print("po6_17_capture: injected C's GH van / heli markers (not on trunk yet)")


func _look(eye: Vector3, target: Vector3) -> void:
	_cam.global_transform = Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)
	_cam.current = true


func _wait(seconds: float) -> void:
	for i: int in range(maxi(roundi(seconds * Engine.physics_ticks_per_second), 1)):
		await get_tree().physics_frame


## Rendering is paused between grabs (llvmpipe frames are slow and the simulation is capped per frame).
func _grab() -> Image:
	RenderingServer.render_loop_enabled = true
	for i: int in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y)
	RenderingServer.render_loop_enabled = false
	return img


func _save(tiles: Array[Image], file: String) -> void:
	var sheet: Image = Image.create(TILE.x * tiles.size(), TILE.y, false, Image.FORMAT_RGB8)
	for i: int in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, 0))
	var path: String = _out.path_join(file)
	print("po6_17_capture: %s %s" % [path, error_string(sheet.save_jpg(path, 0.85))])


func _van(ev: AssaultEventRunner) -> void:
	var van: AssaultTurretVan = ev.run(&"turret_van", {"drive_in_s": 3.0}, "TurretVan_1") as AssaultTurretVan
	var tiles: Array[Image] = []
	_look(Vector3(5.0, 1.7, 11.0), Vector3(-3.0, 1.2, 21.0))
	await _wait(1.5)
	tiles.append(await _grab())
	while van.stage != AssaultTurretVan.Stage.ACTIVE:
		await get_tree().physics_frame
	var fill: OmniLight3D = OmniLight3D.new()  # review fill light (night street)
	fill.omni_range = 12.0
	fill.light_energy = 2.0
	_rt.add_child(fill)
	fill.global_position = van.global_transform * Vector3(3.0, 5.0, -2.0)
	_look(Vector3(6.5, 1.7, 15.0), van.global_position + Vector3(0, 2.0, 0))
	await _wait(2.5)
	tiles.append(await _grab())
	_look(van.global_transform * Vector3(5.0, 5.0, -7.0), van.turret.global_position + Vector3(0, 0.8, 0))
	await _wait(0.5)
	tiles.append(await _grab())
	fill.queue_free()
	print("po6_17_capture: turret shots %d hits %d, squad %d" % [van.turret.shots_fired, van.turret.hits_landed, ev.units.size()])
	_save(tiles, "po6_17_turret_van.jpg")


func _heli(ev: AssaultEventRunner) -> void:
	var heli: AssaultHeli = ev.run(&"heli", {"orbit_s": 2.0, "speed_mps": 28.0, "approach_m": 70.0, "sniper_s": 20.0},
		"HeliDrop_2") as AssaultHeli
	var tiles: Array[Image] = []
	var t0: int = Time.get_ticks_msec()
	while heli.stage < AssaultHeli.Stage.HOVER:
		await get_tree().physics_frame
		if Time.get_ticks_msec() - t0 > 5000:
			t0 = Time.get_ticks_msec()
			print("po6_17_capture: heli stage %d at %s" % [heli.stage, heli.global_position])
	await _wait(1.6)
	_look(Vector3(18.0, 2.0, -12.0), heli.global_position + Vector3(0, -4.0, 0))
	tiles.append(await _grab())
	while is_instance_valid(heli) and heli.passenger == null:
		await get_tree().physics_frame
	await _wait(3.0)
	if is_instance_valid(heli):
		var to_heli: Vector3 = heli.global_position - Vector3(9.0, 0.0, 8.0)
		_look(heli.global_position - to_heli.normalized() * 12.0 + Vector3(0, -2.0, 0), heli.global_position + Vector3(0, 1.0, 0))
	tiles.append(await _grab())
	_save(tiles, "po6_17_heli.jpg")


func _breach(ev: AssaultEventRunner) -> void:
	var b: AssaultBreach = ev.run(&"breach", {"warning_s": 3.0}) as AssaultBreach
	if b == null:
		print("po6_17_capture: no breach candidate")
		return
	var at: Vector3 = b.point("Charge")
	var room: Vector3 = b.global_transform * Vector3(0, 1.6, -5.0)
	if room.distance_to(Vector3(5.0, 1.6, 8.0)) > room.distance_to(b.global_transform * Vector3(0, 1.6, 5.0)):
		room = b.global_transform * Vector3(0, 1.6, 5.0)
	var tiles: Array[Image] = []
	_look(room, at)
	await _wait(1.5)
	tiles.append(await _grab())
	while not b.is_blown():
		await get_tree().physics_frame
	await _wait(0.1)
	tiles.append(await _grab())
	await _wait(2.0)
	tiles.append(await _grab())
	print("po6_17_capture: breach %s at %s, units %d" % [b.params.get("_marker", ""), b.global_position, ev.units.size()])
	_save(tiles, "po6_17_breach.jpg")
