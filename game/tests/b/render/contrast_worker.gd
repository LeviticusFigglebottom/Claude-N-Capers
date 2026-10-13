## Worker for hud_contrast_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const MIN_RATIO: float = 4.5
const HUD_PATH: String = "res://content/ui/hud/hud.tscn"
const SIZE: Vector2i = Vector2i(1280, 720)
const BACKDROPS: Dictionary = {"dark": Color(0.05, 0.05, 0.06), "mid": Color(0.45, 0.45, 0.45),
		"bright": Color(0.92, 0.9, 0.85), "white": Color(1, 1, 1)}

var _fails: int = 0
var _vp: SubViewport = null


static func _lum(c: Color) -> float:
	var f: Callable = func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(f.call(c.r)) + 0.7152 * float(f.call(c.g)) + 0.0722 * float(f.call(c.b))


static func label_ratio(img: Image, r: Rect2i) -> float:
	var ls: PackedFloat32Array = PackedFloat32Array()
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			ls.append(_lum(img.get_pixel(x, y)))
	if ls.size() < 10:
		return 99.0
	ls.sort()
	var n: int = maxi(ls.size() / 33, 1)
	var lo: float = 0.0
	var hi: float = 0.0
	for i: int in range(n):
		lo += ls[i]
		hi += ls[ls.size() - 1 - i]
	return (hi / n + 0.05) / (lo / n + 0.05)


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "hud"
	OnboardingTips.persist = false  # never touch the player's save from a capture
	if mode != "onboarding":
		for id: StringName in OnboardingTips.ALL:
			OnboardingTips.mark_seen(id)  # the other shots stay as they were
	if mode == "menus":
		await _menus()
	elif mode == "loud":
		await _loud()
	elif mode == "onboarding":
		await _onboarding()
	elif mode == "feedback":
		await _feedback()
	elif mode == "loading":
		# The game's canvas stretched into the 1280x720 shot: look at the PNG; label rects are in canvas
		# units here, so this mode's contrast numbers do not apply.
		_vp.size_2d_override = Vector2i(1920, 1080)
		_vp.size_2d_override_stretch = true
		var l: LoadingScreen = LoadingScreen.new()
		l.setup(&"glasshouse", Enums.Difficulty.HAZARDOUS)
		_vp.add_child(l)
		await _shot("loading", l)
	else:
		await _hud()
	print("CONTRAST %s (%d failures, min %.1f:1)" % ["PASS" if _fails == 0 else "FAIL", _fails, MIN_RATIO])
	get_tree().quit(0 if _fails == 0 else 1)


## Waits ~8 frames + frame_post_draw, saves the PNG and checks every visible Label under `under`.
func _shot(shot: String, under: Node) -> void:
	for _i: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_png("user://contrast_%s.png" % shot)
	var bad: int = 0
	for n: Node in under.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if not l.is_visible_in_tree() or l.text.strip_edges() == "" or _alpha(l) < 0.05:
			continue  # faded-out labels (e.g. the crosshair while casing) are not on screen
		var gr: Rect2 = _visible_rect(l)
		if gr.size.x < 4.0 or gr.size.y < 4.0:
			continue  # scrolled out of view / clipped
		var ratio: float = label_ratio(img, Rect2i(Vector2i(gr.position), Vector2i(gr.size)))
		if ratio < MIN_RATIO:
			bad += 1
			print("CONTRAST FAIL shot=%s %s '%s' ratio=%.2f" % [shot, l.get_path(), l.text.left(30), ratio])
	print("SHOT %s: %d failures" % [shot, bad])
	_fails += bad


## Effective alpha of `c` (its modulate times every CanvasItem ancestor's).
static func _alpha(c: CanvasItem) -> float:
	var a: float = c.modulate.a * c.self_modulate.a
	var p: Node = c.get_parent()
	while p is CanvasItem:
		a *= (p as CanvasItem).modulate.a
		p = p.get_parent()
	return a


## The label's rect cut to its clipping ancestors (ScrollContainer etc.) and the viewport.
static func _visible_rect(l: Label) -> Rect2:
	var r: Rect2 = l.get_global_rect()
	var p: Node = l.get_parent()
	while p != null:
		if p is Control and ((p as Control).clip_contents or p is ScrollContainer):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r.intersection(Rect2(Vector2.ZERO, Vector2(SIZE)))


func _hud() -> void:
	var back: ColorRect = ColorRect.new()
	back.size = Vector2(SIZE)
	_vp.add_child(back)
	var model: MockHudModel = MockHudModel.new()
	_vp.add_child(model)
	var hud: Hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	_vp.add_child(hud)
	await get_tree().process_frame
	hud.bind(model)
	model.interaction = {"text_key": &"ui.prompt.interact", "args": {}, "progress": 0.4, "blocked_reason": &""}
	model.objectives = [{"id": &"secure", "text_key": &"objective.glasshouse.secure", "args": {"bags": 2},
			"state": Enums.ObjectiveState.ACTIVE}]
	model.dominate_window_s = 2.0
	model.dominate_target = 7
	model.assault_phase = Enums.AssaultPhase.BUILD
	model.assault_wave = 2
	model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
	hud.toast(&"ui.hud.casing_blocked.sprint", {"key": "Shift"}, 30.0)
	model.player_mode = &"casing"
	model.mask_progress = 0.55  # PO-1 mask-up ring
	for bg: String in BACKDROPS:
		back.color = BACKDROPS[bg] as Color
		await _shot("hud_" + bg, hud)


func _menus() -> void:
	SaveService.root_dir = "user://contrast_profiles"
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	_vp.add_child(f)
	await get_tree().process_frame
	f.show_hub()
	await _shot("menu_hub", f)
	f.open_station(&"armory")
	await _shot("menu_loadout", f)
	var pd: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	pd.setup(PlayerProfile.new_default())
	_vp.add_child(pd)
	await get_tree().process_frame
	pd.show_cards()
	await _shot("menu_payday", pd)
	SaveService.delete_profile(0)


## PP-B-7: loud state (assault, downed + bleedout, low ammo, bag, hostages) over the same backdrops.
func _loud() -> void:
	var back: ColorRect = ColorRect.new()
	back.size = Vector2(SIZE)
	_vp.add_child(back)
	var model: MockHudModel = MockHudModel.new()
	_vp.add_child(model)
	var hud: Hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	_vp.add_child(hud)
	await get_tree().process_frame
	hud.bind(model)
	InteractionPanel.pad_active = true  # lane 8: pad glyphs in the loud shots
	model.interaction = {"text_key": &"ui.prompt.revive", "args": {"name": "Dutch"}, "progress": 0.3, "blocked_reason": &""}
	model.masked = true
	model.casing = false
	model.assault_phase = Enums.AssaultPhase.SUSTAIN
	model.assault_wave = 3
	model.ammo = {Enums.WeaponSlot.PRIMARY: {"mag": 4, "reserve": 87}}
	model.equipped_slot = Enums.WeaponSlot.PRIMARY
	model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
	model.hostages = 3
	model.health = 0.0
	model.downs_left = 1
	model.crew_state = Enums.CrewState.DOWNED
	model.bleedout_s = 23.4
	for bg: String in BACKDROPS:
		back.color = BACKDROPS[bg] as Color
		await _shot("loud_" + bg, hud)
	# PO-4 scoreboard sheet (Tab) with the full objective list.
	model.objectives = [
		{"id": &"keycard", "text_key": &"objective.glasshouse.keycard", "args": {}, "state": Enums.ObjectiveState.COMPLETED},
		{"id": &"safe", "text_key": &"objective.glasshouse.safe", "args": {}, "state": Enums.ObjectiveState.ACTIVE},
		{"id": &"secure", "text_key": &"objective.glasshouse.secure", "args": {"bags": 2, "count": 1, "total": 2},
			"state": Enums.ObjectiveState.ACTIVE}]
	hud.scoreboard.set_process(false)  # no Tab held in a capture
	hud.scoreboard.set_shown(true)
	back.color = BACKDROPS["bright"] as Color
	model.crew_stats = [
		{"slot": 0, "name": "Sable", "is_ai": false, "is_local": true, "kills": 7, "specials_killed": 1, "civilians_killed": 0, "downs": 1},
		{"slot": 1, "name": "Dutch", "is_ai": true, "is_local": false, "kills": 4, "specials_killed": 0, "civilians_killed": 0, "downs": 0}]
	hud.scoreboard.refresh()
	await _shot("loud_scoreboard", hud.scoreboard)  # only the sheet: the HUD under it is covered on purpose


## PO-4 lane 11: the casing and stealth onboarding cards over the backdrops.
func _onboarding() -> void:
	var back: ColorRect = ColorRect.new()
	back.size = Vector2(SIZE)
	_vp.add_child(back)
	var model: MockHudModel = MockHudModel.new()
	_vp.add_child(model)
	var hud: Hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	_vp.add_child(hud)
	await get_tree().process_frame
	hud.onboarding.show_delay_s = 0.0
	model.objectives = [{"id": &"casing", "text_key": &"objective.glasshouse.casing", "args": {},
			"state": Enums.ObjectiveState.ACTIVE}]
	hud.bind(model)
	model.player_mode = &"casing"
	for bg: String in BACKDROPS:
		back.color = BACKDROPS[bg] as Color
		await _shot("card_casing_" + bg, hud.onboarding)
	hud.onboarding.dismiss()
	model.player_mode = &"masked"
	back.color = BACKDROPS["bright"] as Color
	await _shot("card_stealth", hud)
	hud.onboarding.dismiss()
	model.heist_phase = Enums.HeistPhase.LOUD
	await _shot("card_loud", hud.onboarding)
	hud.onboarding.dismiss()
	model.heist_phase = Enums.HeistPhase.ESCAPE
	await _shot("card_escape", hud.onboarding)


## Lead round 62: kill marker, two damage arcs (left = armor, behind-right = health) and the low-health
## vignette over the backdrops (a Camera3D looking down -Z gives the arcs their screen angle).
func _feedback() -> void:
	var back: ColorRect = ColorRect.new()
	back.size = Vector2(SIZE)
	_vp.add_child(back)
	var cam: Camera3D = Camera3D.new()
	_vp.add_child(cam)
	cam.make_current()
	var model: MockHudModel = MockHudModel.new()
	model.local_net_id = 501
	_vp.add_child(model)
	var hud: Hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	_vp.add_child(hud)
	await get_tree().process_frame
	hud.bind(model)
	model.masked = true
	model.casing = false
	model.max_health = 100.0
	model.health = 12.0
	for bg: String in BACKDROPS:
		back.color = BACKDROPS[bg] as Color
		hud.damage_direction.add_arc(Vector3(-1, 0, 0), false)
		hud.damage_direction.add_arc(Vector3(0.7, 0, 0.7).normalized(), true)
		hud.hit_feedback.show_marker(&"kill")
		hud.hit_feedback.set_process(false)  # hold the marker for the shot
		hud.damage_direction.set_process(false)
		await _shot("feedback_" + bg, hud.hit_feedback)
		hud.damage_direction.arcs.clear()
