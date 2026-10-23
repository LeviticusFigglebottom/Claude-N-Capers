## D-130 casts (Cataclysm: about +50 % guards and +35 % civilians on Gallery Night, Shadow Ledger and Night Deposit;
## GN-D1 standard, no twins): windowed review of one pool per run. Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_d130_cast_review.gd \
##     -- --pool=gn_guards
##
## Pools: gn_guards, sl_guards, nd_guards, civilians, gn_waitstaff, gn_attendants, sl_late_staff; OF-D1 (Ostrander
## Federal by day, written to _review/of_d1_cast/): of_tellers, of_officers, of_customers, of_skirts (the
## skirt looks in walk / run / cower, front and side: <pool>_clips.png, no lineup), of_guards (Halden a-j +
## npc_bank_guard + the bodyguard), of_vip; RT-D1 (written to _review/rt_d1_cast/): rt_vaultline (crew a-f, the route
## marshal, and the patrol officer and Halden officer he must not read as), rt_street_swaps (D-149 swaps); D-145.3: d145_police (written to
## _review/d145_police/: the armoured police looks next to their Routine/Tense duty looks; d145_specials,
## d145_factions the same for the specials and the faction TAC Lights).
## Writes to res://assets/characters/_review/d130_cast/ (or the pool's OUT_DIRS / of_ directory):
##   <pool>_sheet.png           per character: full body front (idle), three-quarter back mid-walk, head close-up
##   <pool>_lineup_30m.png      all of them side by side seen from 30 m (natural LOD switching, telephoto framing)
##   <pool>_silhouette_30m.png  the same view with every surface flat black (the 30 m silhouette read)
##   <pool>_pair.png            PAIRS pools only: the first character standing and seated (sit_chair, desk_work) on the
##                              npc office chair at its Seat (0.12 m forward of the pivot), the second standing by
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/d130_cast/"
const OF_OUT_DIR: String = "res://assets/characters/_review/of_d1_cast/"
## of_skirts: clip -> sample time (s), a peak knee bend each (test_skirt_drape FRAMES)
const CLIP_POSES: Array = [["walk", 0.38], ["run", 0.26], ["cower", 1.5]]
const OUT_DIRS: Dictionary = {
	"of_guards": "res://assets/characters/_review/of_d1_cast/",
	"of_vip": "res://assets/characters/_review/of_d1_cast/",
	"rt_vaultline": "res://assets/characters/_review/rt_d1_cast/",
	"rt_street_swaps": "res://assets/characters/_review/rt_d1_cast/",
	"rt_street": "res://assets/characters/_review/rt_g3_cast/",
	"d145_police": "res://assets/characters/_review/d145_police/",
	"d145_specials": "res://assets/characters/_review/d145_police/",
	"d145_factions": "res://assets/characters/_review/d145_police/",
}
## pool -> true: also render the seated/standing pair sheet (first id seated, second standing guard)
const PAIRS: Dictionary = {"of_vip": true}
const CHAIR: String = "res://world/props/office/prop_chair_office.tscn"
const SEAT_FWD: float = 0.12
const PAIR_TILE: Vector2i = Vector2i(420, 560)
const POOLS: Dictionary = {
	"gn_guards": [
		"char_gallery_guard", "char_gallery_guard_b", "char_gallery_guard_c", "char_gallery_guard_d",
		"char_gallery_guard_e", "char_gallery_guard_f", "char_gallery_guard_g", "char_gallery_guard_h",
		"char_gallery_guard_i", "char_gallery_guard_j", "char_gallery_guard_k", "char_gallery_guard_l",
	],
	"sl_guards": [
		"char_npc_northgate_guard", "char_npc_northgate_guard_b", "char_npc_northgate_guard_c",
		"char_npc_northgate_guard_d", "char_npc_northgate_guard_e", "char_npc_northgate_guard_f",
		"char_npc_northgate_guard_g", "char_npc_northgate_guard_h", "char_npc_northgate_guard_i",
	],
	"nd_guards": [
		"char_security_officer", "char_security_officer_b", "char_security_officer_c", "char_security_officer_d",
		"char_security_officer_e", "char_security_officer_f",
	],
	"civilians": [
		"char_npc_cleaner_sl", "char_npc_cleaner_sl_b", "char_npc_cleaner_sl_c", "char_npc_cleaner_sl_d",
		"char_npc_bank_cleaner", "char_npc_bank_cleaner_b", "char_gallery_patron", "char_gallery_patron_b",
		"char_gallery_patron_c", "char_gallery_patron_d", "char_gallery_patron_e", "char_gallery_patron_f",
		"char_gallery_patron_g", "char_gallery_patron_h", "char_gallery_patron_i", "char_gallery_patron_j",
		"char_npc_penthouse_guest_a", "char_npc_penthouse_guest_b",
	],
	# GN gala_extra (cloakroom waitstaff + drawings-cabinet attendant): the third look in each pool.
	"gn_waitstaff": ["char_npc_penthouse_staff", "char_gallery_waiter", "char_gallery_waiter_b"],
	"gn_attendants": ["char_gallery_attendant", "char_gallery_attendant_b", "char_gallery_attendant_c"],
	# SL late_staff (civ_assistant, civ_associate) next to the other K&M / tower civilians they must not resemble.
	"sl_late_staff": [
		"char_npc_km_assistant", "char_npc_km_associate", "char_npc_helena_moor", "char_npc_kessler",
		"char_npc_it_contractor",
	],
	# OF-D1: Ostrander Federal's day pools (3 tellers + 1 rotating, 1-3 officers, 4-8 hall + 2 plaza customers, x1.35)
	"of_tellers": [
		"char_npc_bank_teller", "char_npc_bank_teller_b", "char_npc_bank_teller_c", "char_npc_bank_teller_d",
		"char_npc_bank_teller_e",
	],
	"of_officers": ["char_bank_officer", "char_bank_officer_b", "char_bank_officer_c", "char_bank_officer_d"],
	"of_customers": [
		"char_bank_customer", "char_bank_customer_b", "char_civilian_customer_a", "char_civilian_customer_b",
		"char_bank_customer_c", "char_bank_customer_d", "char_bank_customer_e", "char_bank_customer_f",
		"char_bank_customer_g", "char_bank_customer_h", "char_bank_customer_i", "char_bank_customer_j",
	],
	"of_skirts": ["char_npc_bank_teller", "char_npc_bank_teller_d", "char_bank_officer", "char_bank_customer_c"],
	# OF-D1: the Ostrander Federal Halden day shift (no twins among a-j and the bare-headed npc_bank_guard), with the
	# plainclothes bodyguard last (a distinct silhouette).
	"of_guards": [
		"char_security_officer", "char_security_officer_b", "char_security_officer_c", "char_security_officer_d",
		"char_security_officer_e", "char_security_officer_f", "char_security_officer_g", "char_security_officer_h",
		"char_security_officer_i", "char_security_officer_j", "char_npc_bank_guard", "char_security_bodyguard",
	],
	# OF-D1 vip_client: the VIP next to the bank customers, officers and manager he must not resemble, and his bodyguard.
	"of_vip": [
		"char_bank_vip_client", "char_security_bodyguard", "char_bank_customer", "char_bank_customer_b",
		"char_civilian_customer_a", "char_civilian_customer_b", "char_bank_officer", "char_bank_officer_b",
		"char_bank_manager",
	],
	# D-145.3 (PO-18): Routine/Tense police without body armour (duty) next to the armoured base looks and the FRD agent.
	"d145_police": [
		"char_patrol_officer", "char_patrol_officer_duty", "char_tac_light", "char_tac_light_duty", "char_frd_agent",
	],
	# D-145.3: the Routine/Tense specials without body armour next to their armoured looks, and the Longshot (chest rig).
	"d145_specials": [
		"char_stinger", "char_stinger_duty", "char_bulwark", "char_bulwark_duty", "char_longshot",
	],
	# D-145.3: the faction TAC Lights (frd / sentinel / zero EnemyDefs) armoured next to their Routine/Tense duty looks.
	"d145_factions": [
		"char_tac_light_frd", "char_tac_light_frd_duty", "char_tac_light_sentinel", "char_tac_light_sentinel_duty",
		"char_tac_light_zero", "char_tac_light_zero_duty", "char_tac_light_duty",
	],
	# RT-D1: the Vaultline crew faces and the route marshal next to the police and Halden uniforms.
	"rt_vaultline": [
		"char_armored_car_crew", "char_armored_car_crew_b", "char_armored_car_crew_c", "char_armored_car_crew_d",
		"char_armored_car_crew_e", "char_armored_car_crew_f", "char_armored_car_marshal", "char_patrol_officer",
		"char_security_officer",
	],
	# D-149: the three finish-only street swaps, each beside the look it reuses the meshes of (a / g, b / h, f / i).
	"rt_street_swaps": [
		"char_street_pedestrian", "char_street_pedestrian_g", "char_street_pedestrian_b", "char_street_pedestrian_h",
		"char_street_pedestrian_f", "char_street_pedestrian_i",
	],
	# RT-G3 street polish: the nine street pedestrians and the car-park attendant
	"rt_street": [
		"char_street_pedestrian", "char_street_pedestrian_b", "char_street_pedestrian_c", "char_street_pedestrian_d",
		"char_street_pedestrian_e", "char_street_pedestrian_f", "char_street_pedestrian_g", "char_street_pedestrian_h",
		"char_street_pedestrian_i", "char_carpark_attendant",
	],
}
const COLS: int = 9
const TILE: Vector2i = Vector2i(200, 340)
const HEAD_TILE: Vector2i = Vector2i(200, 200)
const WALK_T: float = 0.3
const LINEUP_SIZE: Vector2i = Vector2i(2400, 420)
const LINEUP_SPACING: float = 1.3
const LINEUP_DIST: float = 30.0
const LINEUP_MIN_HALF_H: float = 1.25

var _pool: String = "gn_guards"
var _out: String = OUT_DIR
var _chars: Array[String] = []
var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_d130_cast_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pool="):
			_pool = arg.trim_prefix("--pool=")
	if not POOLS.has(_pool):
		push_error("render_d130_cast_review: unknown pool %s (%s)" % [_pool, POOLS.keys()])
		quit(2)
		return
	for id: Variant in POOLS[_pool]:
		if ResourceLoader.exists(Spec.scene_path(String(id))):
			_chars.append(String(id))
		else:
			_errors += 1
			push_error("render_d130_cast_review: no scene for %s" % id)
	_out = String(OUT_DIRS.get(_pool, OF_OUT_DIR if _pool.begins_with("of_") else OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_stage()
	if _pool == "of_skirts":
		await _clips_sheet()
	else:
		await _sheet()
		await _lineup()
		if PAIRS.has(_pool) and _chars.size() >= 2:
			await _pair()
	quit(1 if _errors > 0 else 0)


## The first character standing (front, three-quarter back) and seated on the npc office chair at its Seat (sit_chair
## front three-quarter, side, back; desk_work side), the second standing guard beside him in every tile.
func _pair() -> void:
	var cols: int = 3
	var sheet: Image = Image.create(PAIR_TILE.x * cols, PAIR_TILE.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.2))
	var who: Node3D = (load(Spec.scene_path(_chars[0])) as PackedScene).instantiate() as Node3D
	var guard: Node3D = (load(Spec.scene_path(_chars[1])) as PackedScene).instantiate() as Node3D
	CrowdLod.force_level(who, false)
	CrowdLod.force_level(guard, false)
	_vp.add_child(who)
	_vp.add_child(guard)
	guard.position = Vector3(0.85, 0.0, 0.35)   # at the client's right shoulder (+X), a step behind
	var p_who: AnimationPlayer = who.get_node("AnimationPlayer") as AnimationPlayer
	var p_guard: AnimationPlayer = guard.get_node("AnimationPlayer") as AnimationPlayer
	_pose(p_guard, "humanoid/idle", 0.0, _chars[1])
	_label.visible = false
	_vp.size = PAIR_TILE
	var c: Vector3 = Vector3(0.4, 0.85, 0.1)
	# standing
	_pose(p_who, "humanoid/idle", 0.0, _chars[0])
	var shots: Array[Image] = []
	shots.append(await _grab(_view(c + Vector3(0.6, 0.35, -3.6), c)))
	shots.append(await _grab(_view(c + Vector3(2.6, 0.5, 2.6), c)))
	# seated on the chair (Seat 0.12 m forward of the pivot: the chair sits SEAT_FWD behind the rig)
	var chair: Node3D = (load(CHAIR) as PackedScene).instantiate() as Node3D
	_vp.add_child(chair)
	chair.position = Vector3(0.0, 0.0, SEAT_FWD)
	_pose(p_who, "humanoid/sit_chair", 1.0, _chars[0])
	shots.append(await _grab(_view(c + Vector3(-1.4, 0.3, -3.0), c + Vector3(-0.2, -0.2, 0.0))))
	shots.append(await _grab(_view(Vector3(-2.6, 0.75, 0.05), Vector3(0.0, 0.65, 0.05))))
	shots.append(await _grab(_view(Vector3(-1.2, 1.2, 2.4), Vector3(0.0, 0.6, 0.0))))
	_pose(p_who, "humanoid/desk_work", 9.5, _chars[0])
	shots.append(await _grab(_view(Vector3(-2.6, 0.75, 0.05), Vector3(0.0, 0.65, 0.05))))
	for i: int in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, PAIR_TILE),
				Vector2i(PAIR_TILE.x * (i % cols), PAIR_TILE.y * (i / cols)))
	chair.queue_free()
	who.queue_free()
	guard.queue_free()
	await process_frame
	_save(sheet, _pool + "_pair.png")


func _sheet() -> void:
	var band_h: int = TILE.y * 2 + HEAD_TILE.y
	var cols: int = mini(COLS, maxi(1, _chars.size()))   # a short pool gets a narrower canvas, no empty columns
	var bands: int = ceili(float(_chars.size()) / cols)
	var sheet: Image = Image.create(TILE.x * cols, band_h * bands, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.2))
	for c: int in range(_chars.size()):
		var x: int = TILE.x * (c % cols)
		var y0: int = band_h * (c / cols)
		var body: Node3D = (load(Spec.scene_path(_chars[c])) as PackedScene).instantiate() as Node3D
		CrowdLod.force_level(body, false)
		_vp.add_child(body)
		var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
		_pose(player, "humanoid/idle", 0.0, _chars[c])
		var head: Node3D = body.find_child("Head", true, false) as Node3D
		await process_frame
		var hz: Vector3 = head.global_position if head != null else Vector3(0.0, 1.6, 0.0)
		_label.text = _short(_chars[c])
		_label.visible = true
		_vp.size = TILE
		var front: Image = await _grab(_view(Vector3(0.0, 1.0, -3.6), Vector3(0.0, 0.9, 0.0)))
		sheet.blit_rect(front, Rect2i(Vector2i.ZERO, TILE), Vector2i(x, y0))
		_label.visible = false
		_pose(player, "humanoid/walk", WALK_T, _chars[c])
		var back: Image = await _grab(_view(Vector3(2.4, 1.3, 2.6), Vector3(0.0, 0.9, 0.0)))
		sheet.blit_rect(back, Rect2i(Vector2i.ZERO, TILE), Vector2i(x, y0 + TILE.y))
		_pose(player, "humanoid/idle", 0.0, _chars[c])
		_vp.size = HEAD_TILE
		var face: Image = await _grab(_view(hz + Vector3(-0.35, 0.05, -0.75), hz + Vector3(0.0, -0.05, 0.0)))
		sheet.blit_rect(face, Rect2i(Vector2i.ZERO, HEAD_TILE), Vector2i(x, y0 + TILE.y * 2))
		body.queue_free()
		await process_frame
	_save(sheet, _pool + "_sheet.png")


## One row per character: each CLIP_POSES clip at its knee-bend time, seen from the front and from the side.
func _clips_sheet() -> void:
	var cols: int = CLIP_POSES.size() * 2
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * _chars.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.2))
	_vp.size = TILE
	_label.position = Vector3(0.0, 1.95, 0.0)  # in frame for the lower camera
	_label.pixel_size = 0.0018
	for c: int in range(_chars.size()):
		var body: Node3D = (load(Spec.scene_path(_chars[c])) as PackedScene).instantiate() as Node3D
		CrowdLod.force_level(body, false)
		_vp.add_child(body)
		var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
		for i: int in range(CLIP_POSES.size()):
			var clip: String = String(CLIP_POSES[i][0])
			_pose(player, "humanoid/" + clip, float(CLIP_POSES[i][1]), _chars[c])
			_label.text = "%s %s" % [_short(_chars[c]), clip]
			_label.visible = true
			var front: Image = await _grab(_view(Vector3(0.0, 0.9, -3.4), Vector3(0.0, 0.75, 0.0)))
			sheet.blit_rect(front, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i * 2, TILE.y * c))
			_label.visible = false
			var side: Image = await _grab(_view(Vector3(3.4, 0.9, 0.0), Vector3(0.0, 0.75, 0.0)))
			sheet.blit_rect(side, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * (i * 2 + 1), TILE.y * c))
		body.queue_free()
		await process_frame
	_save(sheet, _pool + "_clips.png")


## Everyone in a row (front towards -Z, the camera) seen from LINEUP_DIST metres: the meshes keep their visibility
## ranges, so each character shows the LOD it would show at 30 m in game.
func _lineup() -> void:
	var bodies: Array[Node3D] = []
	var x0: float = -0.5 * LINEUP_SPACING * float(_chars.size() - 1)
	for c: int in range(_chars.size()):
		var body: Node3D = (load(Spec.scene_path(_chars[c])) as PackedScene).instantiate() as Node3D
		body.position = Vector3(-(x0 + LINEUP_SPACING * c), 0.0, 0.0)  # the camera looks along +Z: a left to right
		_vp.add_child(body)
		var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
		_pose(player, "humanoid/idle", 0.0, _chars[c])
		bodies.append(body)
	_label.visible = false
	_vp.size = LINEUP_SIZE
	var half_w: float = -x0 + 0.8
	var vfov: float = rad_to_deg(2.0 * atan(half_w / LINEUP_DIST * float(LINEUP_SIZE.y) / float(LINEUP_SIZE.x)))
	vfov = maxf(vfov, rad_to_deg(2.0 * atan(LINEUP_MIN_HALF_H / LINEUP_DIST)))  # short pools: keep heads and feet in
	_cam.fov = vfov
	var eye: Vector3 = Vector3(0.0, 1.7, -LINEUP_DIST)
	var img: Image = await _grab(_view(eye, Vector3(0.0, 1.0, 0.0)))
	_save(img, _pool + "_lineup_30m.png")
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.0)
	for body: Node3D in bodies:
		for n: Node in body.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).material_override = black
	img = await _grab(_view(eye, Vector3(0.0, 1.0, 0.0)))
	_save(img, _pool + "_silhouette_30m.png")
	for body: Node3D in bodies:
		body.queue_free()
	_cam.fov = 40.0


func _short(id: String) -> String:
	var s: String = id.trim_prefix("char_").replace("npc_", "").replace("gallery_", "")
	return s.replace("northgate_guard", "ng").replace("security_officer", "sec")


func _save(img: Image, file: String) -> void:
	var err: Error = img.save_png(_out + file)
	if err != OK:
		_errors += 1
		push_error("render_d130_cast_review: could not save %s (%s)" % [file, error_string(err)])
	else:
		print("render_d130_cast_review: wrote %s%s" % [_out, file])


func _pose(player: AnimationPlayer, clip: String, t: float, who: String) -> void:
	if not player.has_animation(clip):
		_errors += 1
		push_error("render_d130_cast_review: %s has no %s" % [who, clip])
		return
	player.play(clip)
	player.seek(t, true)
	player.pause()


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -30.0, 0.0)
	fill.light_energy = 0.5
	_vp.add_child(fill)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 12.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.48, 0.5)
	vis.material_override = mat
	_vp.add_child(vis)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.02, 0.0)
	_label.pixel_size = 0.0025
	_label.font_size = 40
	_label.outline_size = 8
	_label.modulate = Color(1.0, 1.0, 1.0)
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.far = 200.0
	_vp.add_child(_cam)
	_cam.current = true


func _view(eye: Vector3, target: Vector3) -> Transform3D:
	return Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
