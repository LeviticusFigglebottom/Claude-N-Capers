## Worker for hud_contrast_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const MIN_RATIO: float = 4.5
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
	if mode == "menus":
		await _menus()
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
		if not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		var gr: Rect2 = _visible_rect(l)
		if gr.size.x < 4.0 or gr.size.y < 4.0:
			continue  # scrolled out of view / clipped
		var ratio: float = label_ratio(img, Rect2i(Vector2i(gr.position), Vector2i(gr.size)))
		if ratio < MIN_RATIO:
			bad += 1
			print("CONTRAST FAIL shot=%s %s '%s' ratio=%.2f" % [shot, l.get_path(), l.text.left(30), ratio])
	print("SHOT %s: %d failures" % [shot, bad])
	_fails += bad


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
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
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
