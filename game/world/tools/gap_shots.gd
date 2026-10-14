## Close-up review shots of door / window junctions (PO-7 door_frame_gap evidence). Owner: ENV C.
## Windowed only (needs a renderer), e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 \
##     --resolution 1280x720 res://world/tools/gap_shots.tscn -- --heist=<id> --out=<dir> \
##     --shot=<file>:<node path>:<cam x,y,z>:<look x,y,z> [--shot=...]
## Camera and look-at points are in the node's local space (door: origin at the bottom-centre of the
## opening, -Z front). Door leaves are shown closed (rotation 0), as door_frame_gap measures them.
## Each shot is a 1280x720 JPEG (<= 400 KB, review_shots.gd save_jpg).
extends Node

const W: int = 1280
const H: int = 720
const REVIEW_SHOTS: GDScript = preload("res://world/tools/review_shots.gd")


func _ready() -> void:
	_main.call_deferred()


func _main() -> void:
	var heist: String = ""
	var out_dir: String = ""
	var shots: Array[PackedStringArray] = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--heist="):
			heist = a.substr(8)
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--shot="):
			shots.append(a.substr(7).split(":"))
	var ps: PackedScene = load("res://world/heists/%s/%s.tscn" % [heist, heist]) as PackedScene
	var map: HeistMap = ps.instantiate() as HeistMap if ps != null else null
	if map == null or out_dir == "":
		print("gap_shots: usage: --heist=<id> --out=<dir> --shot=<file>:<node>:<cam>:<look>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(W, H)
	var holder: Node = Node.new()
	add_child(holder)
	await LcRunner.prepare(map, holder)
	if map.find_children("*", "Light3D", true, false).is_empty():
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
		holder.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.near = 0.02
	cam.far = 500.0
	cam.fov = 60.0
	holder.add_child(cam)
	cam.make_current()
	# Review fill light riding on the camera (night maps; never saved).
	var fill: OmniLight3D = OmniLight3D.new()
	fill.omni_range = 8.0
	fill.light_energy = 0.6
	fill.shadow_enabled = true
	cam.add_child(fill)
	for s: PackedStringArray in shots:
		var n: Node3D = map.get_node_or_null(NodePath(s[1])) as Node3D
		if n == null:
			print("gap_shots: no node %s" % s[1])
			continue
		for ln: String in ["Leaf", "Leaf2"]:
			var leaf: Node3D = n.find_child(ln, true, false) as Node3D
			if leaf != null:
				leaf.rotation = Vector3(leaf.rotation.x, 0.0, leaf.rotation.z)
		var xf: Transform3D = n.global_transform
		cam.global_position = xf * _v(s[2])
		cam.look_at(xf * _v(s[3]), Vector3.UP)
		for i: int in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var size: int = REVIEW_SHOTS.save_jpg(img, out_dir.path_join(s[0]))
		print("gap_shots: %s -> %s (%d KB)" % [s[1], s[0], size / 1024])
	get_tree().quit(0)


static func _v(t: String) -> Vector3:
	var p: PackedStringArray = t.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
