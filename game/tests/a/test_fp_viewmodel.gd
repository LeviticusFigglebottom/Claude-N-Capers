## characters.md v1.3/v1.4 (D-041/D-044): FpViewmodel drives the local human's first-person arms (presentation
## only). Uses a code-built fake arms rig (Skeleton3D with `weapon`/`magazine` bones + AnimationPlayer with
## "pistol" / "rifle" libraries of dummy clips at the real frame counts) swapped into FpViewmodelTweak.arms_scene,
## plus one smoke test against the real `char_arms_fp` when it exists.
extends TestCase

const FPS: float = 30.0
## Dummy clip lengths (frames) and loop flag, the same as char_arms_fp's pistol / rifle sets.
const PISTOL_CLIPS: Dictionary = {
	&"idle": [90, true], &"ads_idle": [90, true], &"sprint": [18, true], &"fire": [6, false],
	&"fire_ads": [6, false], &"reload": [45, false], &"reload_empty": [63, false], &"draw": [11, false],
	&"holster": [11, false],
}
const RIFLE_CLIPS: Dictionary = {
	&"idle": [90, true], &"fire": [3, false], &"reload": [72, false], &"draw": [17, false], &"holster": [17, false],
}

var _root: Node3D = null
var _saved_scene: PackedScene = null
var _saved: bool = false


func after_each() -> void:
	if _saved:
		FpViewmodelTweak.data().arms_scene = _saved_scene
		_saved = false
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	await wait_frames(1)


static func _fake_arms(sets: Dictionary) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "FakeArms"
	var skel: Skeleton3D = Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.add_bone("hand.R")
	skel.set_bone_parent(1, 0)
	skel.add_bone("weapon")
	skel.set_bone_parent(2, 1)
	skel.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0.15, -0.2, -0.35)))
	skel.add_bone("magazine")
	skel.set_bone_parent(3, 2)
	skel.reset_bone_poses()
	root.add_child(skel)
	skel.owner = root
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	for set_id: StringName in sets:
		var lib: AnimationLibrary = AnimationLibrary.new()
		var clips: Dictionary = sets[set_id]
		for c: StringName in clips:
			var a: Animation = Animation.new()
			a.length = float(clips[c][0]) / FPS
			a.loop_mode = Animation.LOOP_LINEAR if bool(clips[c][1]) else Animation.LOOP_NONE
			lib.add_animation(c, a)
		ap.add_animation_library(set_id, lib)
	root.add_child(ap)
	ap.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func _use_scene(ps: PackedScene) -> void:
	if not _saved:
		_saved_scene = FpViewmodelTweak.data().arms_scene
		_saved = true
	FpViewmodelTweak.data().arms_scene = ps


func _spawn(primary: StringName, secondary: StringName) -> CrewController:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	_root.name = "FpRoot"
	add_child(_root)
	await wait_frames(1)
	var l: Loadout = Loadout.new()
	l.primary = primary
	l.secondary = secondary
	var c: CrewController = CrewController.spawn_for_range(_root, Transform3D.IDENTITY, l) as CrewController
	await wait_frames(2)
	var fp: FpViewmodel = _fp(c)
	if fp != null:
		fp.set_process(false)
	return c


func _fp(c: CrewController) -> FpViewmodel:
	return CrewView.of(c).fp_viewmodel()


func _cam(c: CrewController) -> Camera3D:
	return c.get_node(^"Head/Camera") as Camera3D


func test_fire_plays_set_fire_per_shot() -> void:
	_use_scene(_fake_arms({&"pistol": PISTOL_CLIPS}))
	var c: CrewController = await _spawn(&"", &"weapon.kestrel_p9")
	var fp: FpViewmodel = _fp(c)
	assert_true(fp != null, "arms created for the local human")
	if fp == null:
		return
	assert_eq(fp.get_parent(), _cam(c), "arms under the camera")
	assert_true(c.weapon_visual is WeaponVisual, "WeaponVisual attached")
	assert_eq(c.weapon_visual.get_parent(), fp.weapon_attach, "on the weapon bone's BoneAttachment3D")
	assert_eq(fp.weapon_attach.bone_name, "weapon")
	fp.tick(0.016)
	assert_eq(String(fp.player.current_animation), "pistol/idle", "idle played as <anim_set>/<clip>")
	c.weapons.fired.emit({})
	fp.tick(0.016)
	assert_eq(String(fp.player.current_animation), "pistol/fire", "fire on the shot")
	assert_eq(fp.action, FpViewmodel.Action.FIRE)
	fp.player.advance(0.1)
	var pos_before: float = fp.player.current_animation_position
	c.weapons.fired.emit({})
	assert_true(fp.player.current_animation_position < pos_before, "fire restarted on the next shot")
	assert_eq(String(fp.player.current_animation), "pistol/fire")
	# Slide: back at frame 1, forward again at frame 4 (mag not empty).
	fp.tick((1.0 / FPS) / fp.action_speed + 0.0005)
	assert_true(float(fp.parts[&"slide"]) > 0.95, "slide back on frame 1 of the shot")
	fp.tick((4.0 / FPS) / fp.action_speed)
	assert_near(float(fp.parts[&"slide"]), 0.0, 0.001, "slide returned")
	var slide: Node3D = (c.weapon_visual as WeaponVisual).get_base_marker(&"Slide")
	c.weapons.set_ammo(c.weapons.equipped_slot, 1, 20)
	c.weapons.fired.emit({})
	fp.tick(8.0 / FPS)
	assert_near(float(fp.parts[&"slide"]), 1.0, 0.001, "last round: slide locked back")
	if slide != null:
		var rest: Transform3D = fp._part_nodes[&"Slide"][1]
		assert_near(slide.position.distance_to(rest.origin), FpViewmodelTweak.data().slide_travel_m, 0.0001,
			"Slide node moved by the travel")
	fp.tick(1.0)
	assert_eq(String(fp.player.current_animation), "pistol/idle", "back to idle after the clip")
	c.intent.aim = true
	fp.tick(0.5)
	assert_near(fp.ads_weight, 1.0, 0.001, "aimed")
	assert_eq(String(fp.player.current_animation), "pistol/ads_idle", "ads_idle while aiming")
	c.weapons.fired.emit({})
	assert_eq(String(fp.player.current_animation), "pistol/fire_ads", "fire_ads while aiming")


func test_reload_retimed_to_gameplay() -> void:
	_use_scene(_fake_arms({&"pistol": PISTOL_CLIPS}))
	var c: CrewController = await _spawn(&"", &"weapon.kestrel_p9")
	var fp: FpViewmodel = _fp(c)
	if fp == null:
		fail("no arms")
		return
	var ws: int = c.weapons.equipped_slot
	var got: Array[float] = [0.0]
	c.weapons.reload_started.connect(func(_w: int, d: float) -> void: got[0] = d)
	c.weapons.set_ammo(ws, 3, 50)
	assert_true(c.weapons.start_reload(), "tactical reload")
	assert_eq(String(fp.player.current_animation), "pistol/reload")
	var done_s: float = 38.0 / FPS
	assert_near(fp.action_speed, done_s / got[0], 0.0001, "done@38 lands on reload_finished")
	assert_near(fp.player.get_playing_speed(), done_s / got[0], 0.0001, "player speed")
	c.weapons.set_ammo(ws, 0, 50)
	c.weapons.reloading = false
	fp.tick(0.016)
	assert_eq(fp.action, FpViewmodel.Action.NONE, "a cancelled reload returns to idle")
	assert_true(c.weapons.start_reload(), "empty reload")
	assert_eq(String(fp.player.current_animation), "pistol/reload_empty")
	assert_near(fp.action_speed, (56.0 / FPS) / got[0], 0.0001, "done@56 of reload_empty")
	fp.tick(0.016)
	assert_near(float(fp.parts[&"slide"]), 0.0, 0.001, "slide forward (it was never locked in this test)")
	fp._key_start[&"slide"] = 1.0
	fp.tick((42.0 / FPS) / fp.action_speed - 0.026)
	assert_true(float(fp.parts[&"slide"]) > 0.99, "locked slide held until slide_release")
	fp.tick(0.1 / fp.action_speed + 0.02)
	assert_near(float(fp.parts[&"slide"]), 0.0, 0.001, "slide_release@45 sends it home")


func test_swap_plays_holster_then_draw() -> void:
	_use_scene(_fake_arms({&"pistol": PISTOL_CLIPS, &"rifle": RIFLE_CLIPS}))
	var c: CrewController = await _spawn(&"weapon.corsair_ar", &"weapon.kestrel_p9")
	var fp: FpViewmodel = _fp(c)
	if fp == null:
		fail("no arms")
		return
	assert_eq(fp.anim_set, &"rifle", "primary equipped")
	var old: WeaponVisual = c.weapon_visual as WeaponVisual
	assert_true(c.weapons.equip(Enums.WeaponSlot.SECONDARY), "swap")
	var t: float = ContentDB.weapon(&"weapon.kestrel_p9").base.equip_time_s
	var wv: WeaponVisual = c.weapon_visual as WeaponVisual
	assert_eq(wv.weapon.id, &"weapon.kestrel_p9", "crew.weapon_visual is the new weapon at once (muzzle)")
	assert_false(wv.visible, "hidden during the holster")
	assert_eq(String(fp.player.current_animation), "rifle/holster", "old set holsters")
	var share: float = FpViewmodelTweak.data().holster_share
	assert_near(fp.action_speed, (17.0 / FPS) / (t * share), 0.0001, "gone@17 at holster_share x equip time")
	fp.tick(t * share + 0.001)
	assert_eq(String(fp.player.current_animation), "pistol/draw", "new set draws")
	assert_near(fp.action_speed, (11.0 / FPS) / (t * (1.0 - share)), 0.0001, "ready@11 at the end of the equip time")
	assert_true(wv.visible, "new weapon shown")
	assert_eq(fp.anim_set, &"pistol")
	assert_true(not is_instance_valid(old) or old.is_queued_for_deletion() or old.get_parent() == null, "old freed")
	fp.tick(t)
	assert_eq(String(fp.player.current_animation), "pistol/idle", "idle after the draw")


func test_fallback_to_static_viewmodel() -> void:
	_use_scene(null)
	var c: CrewController = await _spawn(&"", &"weapon.kestrel_p9")
	assert_true(_fp(c) == null, "no arms scene: no FpViewmodel")
	assert_eq(c.weapon_visual.get_parent(), _cam(c), "static WeaponVisual under the camera")
	assert_eq(c.weapon_visual.position, Tweak.crew().viewmodel_offset)
	await after_each()
	_use_scene(_fake_arms({&"rifle": RIFLE_CLIPS}))
	c = await _spawn(&"", &"weapon.kestrel_p9")
	assert_true(_fp(c) == null, "no library for the anim_set: no FpViewmodel")
	assert_eq(c.weapon_visual.get_parent(), _cam(c), "static WeaponVisual")
	assert_true(FpViewmodel.create(c, _bare_scene()) == null, "a scene without the weapon bone is rejected")


static func _bare_scene() -> PackedScene:
	var root: Node3D = Node3D.new()
	var skel: Skeleton3D = Skeleton3D.new()
	skel.add_bone("root")
	root.add_child(skel)
	skel.owner = root
	var ap: AnimationPlayer = AnimationPlayer.new()
	root.add_child(ap)
	ap.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func test_events_match_source_txt() -> void:
	var path: String = "res://assets/characters/char_arms_fp/SOURCE.txt"
	if not FileAccess.file_exists(path):
		skip("char_arms_fp SOURCE.txt missing")
		return
	var rx: RegEx = RegEx.create_from_string("^clip\\.(\\w+): \\d+f loop=\\w+ events=(.*)$")
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var n: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var m: RegExMatch = rx.search(line.strip_edges())
		if m == null:
			continue
		for e: String in m.get_string(2).split(","):
			var kv: PackedStringArray = e.split("@")
			assert_near(tw.event_s(StringName(m.get_string(1)), StringName(kv[0])), float(kv[1]) / FPS, 0.0001,
				"%s %s" % [m.get_string(1), kv[0]])
			n += 1
	assert_true(n > 50, "events parsed (%d)" % n)


func test_real_arms_smoke() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if tw.arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _spawn(&"weapon.plowman_12", &"weapon.heron_308")
	var fp: FpViewmodel = _fp(c)
	assert_true(fp != null, "real arms bound")
	if fp == null:
		return
	for s: StringName in [&"pistol", &"smg", &"rifle", &"shotgun", &"lmg", &"sniper"]:
		assert_true(fp.supports(s), "set %s" % s)
	assert_eq(c.weapon_visual.get_parent(), fp.weapon_attach, "weapon on the weapon bone")
	fp.tick(0.016)
	assert_eq(String(fp.player.current_animation), "shotgun/idle")
	c.weapons.fired.emit({})
	assert_eq(String(fp.player.current_animation), "shotgun/fire", "pump inside fire")
	fp.tick(10.0 / FPS)
	assert_true(float(fp.parts[&"pump"]) > 0.9, "pump back after pump_back@9")
	fp.tick(1.0)
	assert_near(float(fp.parts[&"pump"]), 0.0, 0.001, "pump forward")
	var ws: int = c.weapons.equipped_slot
	c.weapons.set_ammo(ws, c.weapons.mag_size(ws) - 2, 20)
	var got: Array[float] = [0.0]
	c.weapons.reload_started.connect(func(_w: int, d: float) -> void: got[0] = d)
	assert_true(c.weapons.start_reload())
	assert_eq(String(fp.player.current_animation), "shotgun/reload_start", "shell-by-shell start")
	assert_eq(fp._segs.size(), 3, "start + loop + end")
	assert_eq(int(fp._segs[1]["loops"]), 2, "two shells missing")
	var native: float = 12.0 / FPS + 2.0 * 13.0 / FPS + 10.0 / FPS
	assert_near(fp.action_speed, native / got[0], 0.0001, "reload_end done lands on reload_finished")
	fp.tick(float(fp._segs[1]["start"]) + 0.001)
	assert_eq(String(fp.player.current_animation), "shotgun/reload_loop")
	fp.tick(float(fp._segs[1]["dur"]))
	assert_eq(String(fp.player.current_animation), "shotgun/reload_end", "tactical end")
	fp.tick(2.0)
	assert_true(c.weapons.equip(Enums.WeaponSlot.SECONDARY), "swap to the sniper")
	fp.tick(10.0)
	assert_eq(fp.anim_set, &"sniper")
	c.weapons.fired.emit({})
	assert_eq(String(fp.player.current_animation), "sniper/fire")
	fp.tick(9.0 / FPS + 0.001)
	assert_eq(String(fp.player.current_animation), "sniper/bolt", "bolt after the shot")
	fp.tick(8.0 / FPS)
	assert_true(float(fp.parts[&"bolt_lift"]) > 0.9, "bolt lifted (bolt_open@8)")
	fp.tick(1.0)
	assert_near(float(fp.parts[&"bolt_lift"]), 0.0, 0.001, "bolt closed")
	var muzzle: Node3D = (c.weapon_visual as WeaponVisual).get_marker(&"Muzzle")
	assert_true(muzzle != null and muzzle.is_inside_tree(), "Muzzle for CrewWeapons")
	c.intent.aim = true
	fp.tick(0.5)
	assert_near(fp.ads_weight, 1.0, 0.001, "aimed")
	var aim: Node3D = (c.weapon_visual as WeaponVisual).get_marker(WeaponVisual.AIM_POINT)
	if aim != null:
		var p: Vector3 = _cam(c).global_transform.affine_inverse() * aim.global_position
		assert_near(Vector2(p.x, p.y).length(), 0.0, 0.002, "AimPoint on the camera axis while aimed (%s)" % p)
