## D-113 evidence capture: blood (spray, wall splatter, pool) and muzzle flash sequences under the glasshouse
## lighting (env_glasshouse + sun_glasshouse). Owner: ENV C. Started by vfx_capture.gd with `--d113=<scene>`:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 \
##     --fixed-fps 60 --resolution 1280x720 res://world/vfx/tools/vfx_capture.tscn -- --d113=blood --out=<dir>
## Scenes: `blood` (a tac-light cop against a plaster wall: two body hits, a headshot, then death + pool),
## `flash` (rifle / shotgun / pistol / sniper / suppressed rifle side by side, four shots each, then the wisp).
## Saves small JPGs `<scene>_<frame>.jpg` and `<scene>_sheet.jpg` into --out. Drives the director only through
## EventBus (shot_fx, npc_killed) and, when present, its blood entry points (on_blood_hit / on_bleed_changed).
class_name VfxGoreCapture
extends Node3D

const JPG_W: int = 960
const JPG_Q: float = 0.85
const COP: String = "res://assets/characters/char_tac_light/char_tac_light.glb"
const FLASH_ROWS: Array[Array] = [
	[&"assault_rifle", false], [&"shotgun", false], [&"pistol", false], [&"sniper", false], [&"assault_rifle", true],
]
const BLOOD_CAPTURES: Array[int] = [12, 14, 22, 32, 34, 37, 52]
const FLASH_SHOTS: Array[int] = [10, 16, 22, 28]

var scene_id: StringName = &"blood"
var out_dir: String = "user://vfx_d113"
var _frame: int = 0
var _director: VfxDirector
var _cop: Node3D
var _shots: Array[Image] = []
var _captures: Array[int] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_lighting()
	_director = (load("res://world/vfx/vfx_director.tscn") as PackedScene).instantiate() as VfxDirector
	add_child(_director)
	if scene_id == &"flash":
		_build_flash_stage()
		for f: int in FLASH_SHOTS:
			_captures.append(f + 1)
		_captures.append(FLASH_SHOTS[-1] + 8)
		_captures.append(FLASH_SHOTS[-1] + 30)
	else:
		_build_blood_stage()
		_captures.assign(BLOOD_CAPTURES)


func _process(_delta: float) -> void:
	_frame += 1
	if scene_id == &"flash":
		_flash_step()
	else:
		_blood_step()
	if _frame in _captures:
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(JPG_W, JPG_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
		img.save_jpg(out_dir.path_join("%s_%03d.jpg" % [scene_id, _frame]), JPG_Q)
		_shots.append(img)
		if _frame == _captures[-1]:
			_save_sheet()
			print("vfx_gore_capture: %s -> %s stats %s" % [scene_id, ProjectSettings.globalize_path(out_dir),
				_director.stats()])
			get_tree().quit(0)


# --- blood -------------------------------------------------------------------------------------------------

func _blood_step() -> void:
	var shooter: Vector3 = Vector3(0.9, 1.45, 6.0)
	match _frame:
		10:
			_hit(shooter, Vector3(0.05, 1.25, 0.17), false)
		20:
			_hit(shooter, Vector3(-0.1, 1.1, 0.17), false)
		30:
			_hit(shooter, Vector3(0.0, 1.68, 0.1), true)
		38:
			_die(shooter)
	if _frame > 40 and _frame <= 50:
		_director.advance(1.0)  # ten seconds of pool growth in 10 frames


func _hit(origin: Vector3, point: Vector3, head: bool) -> void:
	var flags: int = VfxDirector.FLAG_HEADSHOT if head else 0
	EventBus.shot_fx.emit(origin, point, (origin - point).normalized(), &"flesh", &"assault_rifle", 7, flags)
	if EventBus.has_signal(&"blood_hit"):  # else the director's shot_fx fallback draws the blood
		var dir: Vector3 = (point - origin).normalized()
		EventBus.emit_signal(&"blood_hit", 900, point, dir, -dir, 0.8, head, point + dir * 0.3, &"npc")


func _die(origin: Vector3) -> void:
	_cop.rotation = Vector3(-PI * 0.5, PI, 0.0)
	_cop.position = Vector3(0.0, 0.12, -0.6)
	var pos: Vector3 = Vector3(0.35, 0.0, -0.2)  # torso side: the pool spreads out from under the body
	var hit_dir: Vector3 = (Vector3(0, 1.3, 0) - origin).normalized()
	EventBus.npc_killed.emit(900, 7, {"position": pos, "hit_dir": hit_dir})
	if EventBus.has_signal(&"bleed_changed"):
		EventBus.emit_signal(&"bleed_changed", 900, true, pos, 1.0)


func _build_blood_stage() -> void:
	_box(Vector3(0, -0.1, 1.0), Vector3(8, 0.2, 8), "concrete", 1)
	_box(Vector3(0, 1.5, -1.7), Vector3(8, 3.0, 0.2), "plaster_painted", 1)
	_cop = (load(COP) as PackedScene).instantiate() as Node3D
	_cop.rotation.y = PI  # faces the shooter (+Z)
	add_child(_cop)
	var ap: AnimationPlayer = _cop.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		for a: String in ap.get_animation_list():
			if a.to_lower().contains("idle"):
				ap.play(a)
				break
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1 << 3  # npcs: world-only blood rays ignore it
	body.add_to_group(G.NPC)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)
	_camera(Vector3(2.7, 1.55, 2.3), Vector3(-0.35, 0.95, -0.9), 58.0)


# --- flash -------------------------------------------------------------------------------------------------

func _flash_step() -> void:
	if not _frame in FLASH_SHOTS:
		return
	for i: int in range(FLASH_ROWS.size()):
		var row: Array = FLASH_ROWS[i]
		var o: Vector3 = _muzzle(i)
		var flags: int = VfxDirector.FLAG_SUPPRESSED if bool(row[1]) else 0
		EventBus.shot_fx.emit(o, o + Vector3(-40.0, 0.0, 0.0), Vector3.ZERO, &"", row[0], 300 + i, flags)
		if _frame == FLASH_SHOTS[-1] and _director.muzzles.has_method(&"burst_end"):
			_director.muzzles.call(&"burst_end")


func _muzzle(i: int) -> Vector3:
	return Vector3(0.0, 2.45 - 0.48 * float(i), 0.0)


func _build_flash_stage() -> void:
	_box(Vector3(0, -0.1, 0), Vector3(10, 0.2, 6), "concrete", 1)
	_box(Vector3(-1.0, 1.5, -2.6), Vector3(10, 4.0, 0.2), "concrete", 1)
	for i: int in range(FLASH_ROWS.size()):
		var o: Vector3 = _muzzle(i)
		var gun: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.7, 0.07, 0.05)
		gun.mesh = bm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.06, 0.065)
		m.roughness = 0.5
		gun.material_override = m
		gun.position = o + Vector3(0.36, 0.0, 0.0)
		add_child(gun)
		var label: Label3D = Label3D.new()
		var row: Array = FLASH_ROWS[i]
		label.text = String(row[0]) + (" (suppressed)" if bool(row[1]) else "")
		label.font_size = 24
		label.pixel_size = 0.004
		label.outline_size = 8
		label.position = o + Vector3(0.12, 0.11, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(label)
	# Inside the glasshouse: a tall west wall keeps the low sun off the stage (interior lighting).
	_box(Vector3(-4.5, 3.0, 0.0), Vector3(0.3, 6.0, 8.0), "concrete", 1)
	_camera(Vector3(-0.45, 1.55, 2.4), Vector3(-0.45, 1.55, 0.0), 55.0)


# --- shared ------------------------------------------------------------------------------------------------

func _build_lighting() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = load("res://world/lighting/env_glasshouse.tres") as Environment
	add_child(we)
	add_child((load("res://world/lighting/sun_glasshouse.tscn") as PackedScene).instantiate())
	var fill: OmniLight3D = OmniLight3D.new()  # a glasshouse interior fixture
	fill.position = Vector3(1.5, 2.8, 1.5)
	fill.omni_range = 9.0
	fill.light_energy = 0.9
	fill.light_color = Color(1.0, 0.86, 0.7)
	add_child(fill)


func _box(pos: Vector3, size: Vector3, mat_id: String, layer: int) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var path: String = "res://world/materials/%s.tres" % mat_id
	if ResourceLoader.exists(path):
		mi.material_override = load(path) as Material
	body.add_child(mi)
	body.position = pos
	add_child(body)


func _camera(pos: Vector3, target: Vector3, fov: float) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.position = pos
	cam.fov = fov
	add_child(cam)
	cam.look_at(target)
	cam.current = true


## Grid sheet of every capture (3 columns, half size).
func _save_sheet() -> void:
	var cols: int = 3
	var w: int = _shots[0].get_width() / 2
	var h: int = _shots[0].get_height() / 2
	var rows: int = ceili(float(_shots.size()) / float(cols))
	var sheet: Image = Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i: int in range(_shots.size()):
		var s: Image = _shots[i].duplicate() as Image
		s.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(s, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_jpg(out_dir.path_join("%s_sheet.jpg" % scene_id), JPG_Q)
