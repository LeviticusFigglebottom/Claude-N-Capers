## PO6-20 evidence (lead r213): real guard meshes (npc_bank_guard) with a live pager in Golden Hour: one behind the
## Breach_1 wall (G4 staff corridor, seen from the G5 sales floor), one in the open, one beyond 15 m. Windowed:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 \
##     --resolution 1280x720 res://world/vfx/tools/pager_outline_capture.tscn -- --out=<dir>
## Saves outline_a.png / outline_b.png half a pulse apart and outline_off.png (outline cleared: control). Owner: ENV C.
extends Node3D

const MAP: String = "res://world/heists/glasshouse/glasshouse.tscn"
const GUARD: String = "res://world/characters/npc_bank_guard/npc_bank_guard.tscn"
const SHOTS: Dictionary = {4: "outline_a.png", 7: "outline_b.png", 10: "outline_off.png"}

var _out: String = "user://po6_20"
var _frames: int = 0
var _po: PagerOutline = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	var map: Node3D = (load(MAP) as PackedScene).instantiate() as Node3D
	add_child(map)
	var mk: Node3D = map.get_node("AssaultEvents/Breach_1") as Node3D
	var xf: Transform3D = mk.global_transform
	var floor_y: float = mk.global_position.y - 1.1
	var po: PagerOutline = PagerOutline.new()
	add_child(po)
	_po = po
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	var cam_pos: Vector3 = xf * Vector3(0.6, 0.0, -6.5)
	cam.global_position = Vector3(cam_pos.x, floor_y + 1.7, cam_pos.z)
	var look: Vector3 = xf * Vector3(0.0, 0.0, 1.0)
	cam.look_at(Vector3(look.x, floor_y + 1.1, look.z))
	cam.current = true
	po.camera_override = cam
	var pid: int = 1
	for lp: Vector3 in [Vector3(-0.3, 0.0, 1.4), Vector3(1.8, 0.0, -3.0), Vector3(-2.0, 0.0, 14.0)]:
		var p: Vector3 = xf * lp
		var g: Node3D = _guard(Vector3(p.x, floor_y, p.z), cam.global_position)
		var id: int = Ids.next()
		Ids.register(id, g)
		po._on_pager_started(pid, id)
		pid += 1


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 8:
		_po.clear()  # control frame: the guard behind the wall disappears without the outline
	if SHOTS.has(_frames):
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = _out.path_join(String(SHOTS[_frames]))
		img.save_png(path)
		print("pager_outline_capture -> %s" % ProjectSettings.globalize_path(path))
	if _frames > 10:
		get_tree().quit()


func _guard(pos: Vector3, face: Vector3) -> Node3D:
	var g: Node3D = Node3D.new()
	add_child(g)
	g.global_position = pos
	g.look_at(Vector3(face.x, pos.y, face.z), Vector3.UP, true)
	var vis: Node3D = Node3D.new()
	vis.name = "Visual"
	g.add_child(vis)
	vis.add_child((load(GUARD) as PackedScene).instantiate())
	return g
