## D-165 windowed check of character looks under a real map's lighting (no heist launched): instances the map scene,
## stands the characters side by side at --at (facing away from the camera with --back), and shoots them from --dists
## metres at eye height (1080p, 60 degree vertical FOV pixel density, natural LOD). One strip per distance:
## <out>/unit_in_map_<tag>_<d>m[_back].png. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --script res://world/characters/_tools/render_unit_in_map.gd -- --map=res://world/heists/rolling_thunder/rolling_thunder.tscn \
##     --ids=tac_heavy,tac_heavy_zero --at=18.25,0.18,-3.6 --along=x --dists=30,45 --back --tag=rt --out=/abs/dir
## --along=x|z: the camera looks along +X / +Z from `d` m before --at (down a road), characters stand across it.
extends SceneTree

const SPACING: float = 1.4
const TILE: Vector2i = Vector2i(480, 540)

var _map: String = ""
var _ids: PackedStringArray = []
var _at: Vector3 = Vector3.ZERO
var _dists: Array[float] = []
var _back: bool = false
var _tag: String = "map"
var _out: String = ""
var _along: String = "z"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"map":
				_map = kv[1]
			"ids":
				_ids = kv[1].split(",")
			"at":
				var p: PackedStringArray = kv[1].split(",")
				_at = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"dists":
				for d: String in kv[1].split(","):
					_dists.append(float(d))
			"back":
				_back = true
			"tag":
				_tag = kv[1]
			"out":
				_out = kv[1]
			"along":
				_along = kv[1]
	_run.call_deferred()


func _run() -> void:
	var map: Node = (load(_map) as PackedScene).instantiate()
	root.add_child(map)
	var fwd: Vector3 = Vector3.RIGHT if _along == "x" else Vector3.BACK      # the camera's view direction
	var side: Vector3 = fwd.cross(Vector3.UP)
	var x0: float = -0.5 * SPACING * float(_ids.size() - 1)
	for i: int in _ids.size():
		var ch: Node3D = (load("res://world/characters/%s/%s.tscn" % [_ids[i], _ids[i]]) as PackedScene).instantiate()
		root.add_child(ch)
		ch.global_position = _at + side * (x0 + SPACING * float(i))
		# a character's front is its local -Z: --back turns that front along `fwd` (away from the camera)
		var face: Vector3 = fwd if _back else -fwd
		ch.rotation.y = atan2(-face.x, -face.z)
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(_out)
	for d: float in _dists:
		var w: float = SPACING * float(_ids.size()) + 0.6
		var h_px: int = int(ceil(2.2 / (2.0 * d * tan(deg_to_rad(30.0))) * 1080.0))
		var w_px: int = int(ceil(w / 2.2 * float(h_px)))
		root.get_viewport().size = Vector2i(w_px, h_px)
		cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(30.0)) * float(h_px) / 1080.0))
		cam.look_at_from_position(_at - fwd * d + Vector3(0.0, 1.65, 0.0), _at + Vector3(0.0, 0.95, 0.0), Vector3.UP)
		for _f: int in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var scale: int = maxi(1, TILE.y / h_px)
		img.resize(w_px * scale, h_px * scale, Image.INTERPOLATE_NEAREST)
		var path: String = "%s/unit_in_map_%s_%dm%s.png" % [_out, _tag, int(d), "_back" if _back else ""]
		img.save_png(path)
		print("render_unit_in_map: wrote %s" % path)
	quit(0)
