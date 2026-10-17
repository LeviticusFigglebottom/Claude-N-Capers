## D-116 follow-up (organic, third person): how teammates and bots hold their weapons, windowed, in a lit heist.
## Two crew rigs stand in front of the player crew's spawn (the heist launched as the game does), a rifle and a pistol,
## at HandR/Socket exactly as AnimDriver.refresh_weapon does, posed at idle_alert, walk (mid stride), aim. A 3/4
## front view plus a close-up of the hands per pose.
## Writes <out>/<pose>.png, <out>/<pose>_close.png and <out>/crew_hold_sheet.png (rows = poses).
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_crew_hold_review.tscn -- --out=/abs/dir \
##     [--heist=glasshouse] [--after] [--bots=crew_rook:weapon.mule_12:rifle,...] [--poses=interact_low:0.6,...]
##     [--layer=crouch_walk]: each pose plays the locomotion clip and layers the pose clip's upper bones over it (the
##     bone filter A uses for hold_<kind>, SOURCE weapon_holds; a pose `walk>hold_%s_walk:0.3` sets its own);
##     [--turn=deg]: every rig turned further (90 = profile)
##     [--bags=light,medium,heavy]: per bot, that loot bag (world/props/loot_bag/prop_loot_bag_<size>.tscn) at
##     Back/Socket with character_spec.gd BACK_BAG_OFFSETS[size] (A's carried-bag visual)
##     [--props=book,...]: that hand prop (world/characters/_props/hand_<prop>.tscn, at its own socket) on every bot
##     [--chair=res://...tscn] [--chair_off=x,y,z]: a chair under every bot (its origin at the rig's, turned with it,
##     offset in the rig's space), for the seated clips
##     [--origin=x,y,z] [--yaw=deg]: stand the view there (floor point, facing yaw; 0 = -Z) instead of the crew spawn
##     (e.g. a dark corner of the map, D-132 lit / dark review)
## Owner: ENV D.
extends Node

const Spec = preload("res://world/characters/_tools/character_spec.gd")

## [character scene id, weapon id, weapon kind]
const BOTS: Array = [["crew_rook", &"weapon.corsair_ar", &"rifle"], ["crew_sable", &"weapon.kestrel_p9", &"pistol"]]
## the aim clip family per hold kind (AnimDriver: anything but a pistol aims as a rifle)
const PISTOL_KINDS: Array[String] = ["pistol", "akimbo"]
const ANIM_LIB: String = "humanoid/"
## m in front of the crew spawn (Glasshouse: short of the store window)
const DIST: float = 1.8
## m between the bots across the view
const SPACING: float = 0.95

## --after: the D-116 weapon-class holds idle_alert_<kind> / hold_<kind> instead of the shared idle_alert / walk
## (hold_* is the upper-body layer A blends over locomotion; shown here on its own stand)
const BEFORE_POSES: Array = [["idle_alert", "idle_alert", 0.5], ["walk", "walk", 0.3], ["aim", "aim", 0.5]]
const AFTER_POSES: Array = [["idle_alert", "idle_alert_%s", 0.5], ["hold", "hold_%s", 0.3], ["aim", "aim", 0.5]]

var _out: String = "user://crew_hold_review"
var _heist: String = "glasshouse"
## [pose name, clip (%s = the bot's hold kind; "aim" = aim_rifle / aim_pistol), time (s)]
var _poses: Array = BEFORE_POSES
## [[rig scene id, weapon id, hold kind]]; --bots=crew_rook:weapon.mule_12:rifle,crew_sable:weapon.hornet_9:smg
var _bots: Array = BOTS
## --layer=<clip>: the lower-body clip each pose's upper body is layered over ("" = none)
var _layer: String = ""
## --turn=<deg>: extra yaw of every rig (left), e.g. 90 for a profile view of the weapon against the knees
var _turn: float = 0.0
## --bags=<size>,...: a carried bag per bot ("" = none)
var _bags: PackedStringArray = []
## --props / --chair / --chair_off
var _props: PackedStringArray = []
var _chair: String = ""
var _chair_off: Vector3 = Vector3.ZERO
## --close_h=<m>: the close-up camera's height and look-at height (seated bodies: ~0.7)
var _close_h: float = 1.12
## --origin=x,y,z / --yaw=deg: the view's floor point and facing instead of the crew spawn's
var _origin: Variant = null
var _yaw: float = 0.0
## --debug_surfaces: every mesh surface of the rigs in its own flat colour (the legend is printed): find a stray piece
var _debug_surfaces: bool = false
## --grid=N [--grid_view=full|close]: the sheet is a grid of one view per pose, N per row (motion strips: list one clip at
## several times), instead of full + close rows
var _grid: int = 0
var _grid_view: String = "full"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"heist": _heist = v
			"layer": _layer = v
			"turn": _turn = float(v)
			"bags": _bags = v.split(",")
			"props": _props = v.split(",")
			"chair": _chair = v
			"close_h": _close_h = float(v)
			"debug_surfaces": _debug_surfaces = true
			"grid": _grid = int(v)
			"grid_view": _grid_view = v
			"chair_off":
				var c: PackedStringArray = v.split(",")
				_chair_off = Vector3(float(c[0]), float(c[1]), float(c[2]))
			"origin":
				var oc: PackedStringArray = v.split(",")
				_origin = Vector3(float(oc[0]), float(oc[1]), float(oc[2]))
			"yaw": _yaw = float(v)
			"after": _poses = AFTER_POSES
			"poses":   # --poses=interact_low:0.6,drill_place:0.8 (any clips, the same for every bot)
				_poses = []
				for e: String in v.split(","):
					var f2: PackedStringArray = e.split(":")
					_poses.append([f2[0], f2[0], float(f2[1]) if f2.size() > 1 else 0.5])
			"bots":
				_bots = []
				for b: String in v.split(","):
					var f: PackedStringArray = b.split(":")
					_bots.append([f[0], StringName(f[1]), StringName(f[2])])
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false   # llvmpipe: render only the saved frames (a lit heist is slow)
	# the heist as the game builds it (HeistLauncher), lit; the crew stands at its spawn, its view gives the frame
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	var rt: HeistRuntime = await HeistLauncher.launch(StringName(_heist), 1002, Enums.Difficulty.ROUTINE, self,
			{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
	rt.isolate_npc(null)
	for _i: int in 30:
		await get_tree().physics_frame
	var crew: Node3D = rt.crew_controller(0) as Node3D
	crew.visible = false   # the review camera stands where the player is
	var o: Vector3 = crew.global_position
	var fwd: Vector3 = -crew.global_basis.z
	if _origin != null:
		o = _origin as Vector3
		fwd = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_yaw))
	fwd.y = 0.0
	fwd = fwd.normalized()
	print("[CREWHOLD] view origin %s yaw %.0f" % [o, rad_to_deg(Vector3.FORWARD.signed_angle_to(fwd, Vector3.UP))])
	var side: Vector3 = fwd.cross(Vector3.UP).normalized()
	var rigs: Array[Node3D] = []
	for i: int in _bots.size():
		var spec: Array = _bots[i]
		var rig: Node3D = (load("res://world/characters/%s/%s.tscn" % [spec[0], spec[0]]) as PackedScene).instantiate()
		add_child(rig)
		var lane: float = (float(i) - (_bots.size() - 1) * 0.5) * -SPACING
		var p: Vector3 = o + fwd * DIST + side * lane
		rig.global_position = p
		rig.look_at(o + side * lane * 0.6, Vector3.UP)   # facing the camera, turned 3/4
		rig.rotate_y(deg_to_rad(28.0 * signf(lane) if lane != 0.0 else 0.0))
		rig.rotate_y(deg_to_rad(_turn))
		_attach(rig, StringName(spec[1]), ^"Skeleton3D/HandR/Socket")
		for prop: String in _props:
			_attach_prop(rig, prop)
		if not _chair.is_empty():
			var chair: Node3D = (load(_chair) as PackedScene).instantiate() as Node3D
			rig.add_child(chair)
			chair.position = _chair_off
		if i < _bags.size() and not _bags[i].is_empty():
			_attach_bag(rig, _bags[i])
		if spec[2] == &"akimbo":
			_attach(rig, StringName(spec[1]), ^"Skeleton3D/HandL/Socket")
		if _debug_surfaces:
			_paint_surfaces(rig)
		rigs.append(rig)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	var mid: Vector3 = o + fwd * DIST
	var rows: Array[Array] = []
	for pose: Array in _poses:
		for i: int in rigs.size():
			var kind: String = String(_bots[i][2])
			var clip: String = String(pose[1])
			if clip == "aim":
				clip = "aim_pistol" if PISTOL_KINDS.has(kind) else "aim_rifle"
			elif clip.contains("%s"):
				clip = clip % kind
			var lay: String = _layer
			if clip.contains(">"):   # --poses=walk>hold_%s_walk:0.3: this pose's own layer (base>overlay)
				lay = clip.get_slice(">", 0)
				clip = clip.get_slice(">", 1)
			if lay.is_empty():
				_pose(rigs[i], clip, float(pose[2]))
			else:
				_pose(rigs[i], lay, float(pose[2]))
				_overlay(rigs[i], clip, float(pose[2]))
		await get_tree().process_frame
		cam.global_position = o + Vector3.UP * 1.55 - fwd * 0.6
		cam.look_at(mid + Vector3.UP * 1.1)
		cam.current = true
		var full: Image = await _shot()
		full.save_png("%s/%s.png" % [_out, pose[0]])
		cam.global_position = mid + Vector3.UP * (_close_h + 0.13) - fwd * (1.45 + 0.75 * (rigs.size() - 2))
		cam.look_at(mid + Vector3.UP * _close_h)
		var close: Image = await _shot()
		close.save_png("%s/%s_close.png" % [_out, pose[0]])
		rows.append([full, close])
	if _grid > 0:
		_grid_sheet(rows)
	else:
		_sheet(rows)
	RenderingServer.render_loop_enabled = true
	rt.teardown()
	print("[CREWHOLD] RESULT DONE %s/crew_hold_sheet.png" % _out)
	get_tree().quit(0)


## AnimDriver.refresh_weapon: the WeaponDef's WeaponVisual (no mods) at HandR/Socket.
func _attach(rig: Node3D, wid: StringName, at: NodePath) -> void:
	var def: WeaponDef = ContentDB.weapon(wid)
	var socket: Node3D = rig.get_node_or_null(at) as Node3D
	if def == null or def.model == null or socket == null:
		push_warning("crew hold review: no weapon / socket for %s" % wid)
		return
	var wv: WeaponVisual = WeaponVisual.new()
	socket.add_child(wv)
	wv.setup(def, [] as Array[WeaponModDef])


## AnimDriver._update_bag_visual: the bag scene at Back/Socket, here with the per-size offset.
func _attach_bag(rig: Node3D, size: String) -> void:
	var socket: Node3D = rig.get_node_or_null(^"Skeleton3D/Back/Socket") as Node3D
	var ps: PackedScene = load("res://world/props/loot_bag/prop_loot_bag_%s.tscn" % size) as PackedScene
	if socket == null or ps == null:
		push_warning("crew hold review: no Back/Socket or bag %s" % size)
		return
	var bag: Node3D = ps.instantiate() as Node3D
	socket.add_child(bag)
	bag.position = Spec.BACK_BAG_OFFSETS.get(size, Vector3.ZERO) as Vector3


## --debug_surfaces: a flat colour per (mesh, surface), the legend printed as [SURF] mesh/surface material colour.
func _paint_surfaces(rig: Node3D) -> void:
	var palette: Array[Color] = [Color.RED, Color.LIME, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN,
		Color.ORANGE, Color.PURPLE, Color.WHITE, Color.BLACK, Color.DARK_GREEN, Color.PINK]
	var i: int = 0
	for n: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var col: Color = palette[i % palette.size()]
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = col
			var src: Material = mi.get_active_material(s)
			print("[SURF] %s/%d %s %s" % [mi.name, s, src.resource_path.get_file() if src != null else "-", col.to_html(false)])
			mi.set_surface_override_material(s, mat)
			i += 1


## AnimDriver HandProps: the prop scene under its socket with an identity transform.
func _attach_prop(rig: Node3D, prop: String) -> void:
	var ps: PackedScene = load("res://world/characters/_props/hand_%s.tscn" % prop) as PackedScene
	if ps == null:
		push_warning("crew hold review: no hand prop %s" % prop)
		return
	var inst: Node3D = ps.instantiate() as Node3D
	var socket: Node3D = rig.get_node_or_null(NodePath("Skeleton3D/%s/Socket" % String(inst.get_meta("socket", "HandR"))))
	if socket == null:
		inst.free()
		return
	socket.add_child(inst)


func _pose(rig: Node3D, clip: String, t: float) -> void:
	var ap: AnimationPlayer = rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if ap == null or not ap.has_animation(ANIM_LIB + clip):
		push_warning("crew hold review: no clip %s" % clip)
		return
	ap.play(ANIM_LIB + clip)
	ap.seek(t, true)
	ap.pause()


## The upper bones of `clip` at `t` over whatever the rig is posed at (A's hold_<kind> layer: spine, chest, neck,
## head, clavicles, arms, hands and fingers in bone-local rotation).
func _overlay(rig: Node3D, clip: String, t: float) -> void:
	var ap: AnimationPlayer = rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var skel: Skeleton3D = rig.get_node_or_null(^"Skeleton3D") as Skeleton3D
	if ap == null or skel == null or not ap.has_animation(ANIM_LIB + clip):
		push_warning("crew hold review: no layer clip %s" % clip)
		return
	var anim: Animation = ap.get_animation(ANIM_LIB + clip)
	var t_loop: float = fmod(t, anim.length) if anim.loop_mode != Animation.LOOP_NONE else minf(t, anim.length)
	for tr: int in anim.get_track_count():
		if anim.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
			continue
		var bone: String = String(anim.track_get_path(tr).get_concatenated_subnames())
		if not _is_upper(bone):
			continue
		var idx: int = skel.find_bone(bone)
		if idx >= 0:
			skel.set_bone_pose_rotation(idx, anim.rotation_track_interpolate(tr, t_loop))


static func _is_upper(bone: String) -> bool:
	var base: String = bone.get_slice(".", 0)
	if bone in ["spine", "chest", "neck", "head"]:
		return true
	if base in ["clavicle", "upper_arm", "forearm", "hand"]:
		return true
	return base.contains("_0") and bone.contains(".")


func _shot() -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	return img


## --grid: one view per pose, _grid per row, at half size.
func _grid_sheet(rows: Array[Array]) -> void:
	var col: int = 1 if _grid_view == "close" else 0
	var w: int = (rows[0][col] as Image).get_width() / 2
	var h: int = (rows[0][col] as Image).get_height() / 2
	var lines: int = ceili(rows.size() / float(_grid))
	var sheet: Image = Image.create(w * _grid, h * lines, false, Image.FORMAT_RGB8)
	for i: int in rows.size():
		var img: Image = (rows[i][col] as Image).duplicate() as Image
		img.convert(Image.FORMAT_RGB8)
		img.resize(w, h)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((i % _grid) * w, (i / _grid) * h))
	sheet.save_png("%s/crew_hold_sheet.png" % _out)


func _sheet(rows: Array[Array]) -> void:
	var w: int = (rows[0][0] as Image).get_width() / 2
	var h: int = (rows[0][0] as Image).get_height() / 2
	var sheet: Image = Image.create(w * 2, h * rows.size(), false, Image.FORMAT_RGB8)
	for r: int in rows.size():
		for c: int in 2:
			var img: Image = (rows[r][c] as Image).duplicate() as Image
			img.convert(Image.FORMAT_RGB8)
			img.resize(w, h)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(c * w, r * h))
	sheet.save_png("%s/crew_hold_sheet.png" % _out)
