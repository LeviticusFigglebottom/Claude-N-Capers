## PQ-B-22: HUD contrast check that needs a real renderer (not run by the headless runner).
## Renders the HUD (MockHudModel, typical stealth + loud state) over a dark, a mid and a bright
## backdrop at 1280x720 and, per visible HUD label, compares the brightest and darkest 3% of the
## pixels inside the label (text vs outline / panel): WCAG ratio >= MIN_RATIO passes.
## Run (no GPU needed, Mesa llvmpipe):
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game \
##     --rendering-driver opengl3 --resolution 1280x720 res://tests/b/render/hud_contrast_capture.tscn
## Prints "CONTRAST PASS" / "CONTRAST FAIL ..." lines, saves PNGs to user://hud_contrast_<bg>.png, exits 0/1.
extends CanvasLayer

const MIN_RATIO: float = 4.5
const BACKDROPS: Dictionary = {"dark": Color(0.05, 0.05, 0.06), "mid": Color(0.45, 0.45, 0.45),
		"bright": Color(0.92, 0.9, 0.85)}

var _fails: int = 0


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
	_run.call_deferred()


func _run() -> void:
	var back: ColorRect = ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
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
	for bg: String in BACKDROPS:
		back.color = BACKDROPS[bg] as Color
		for _i: int in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("user://hud_contrast_%s.png" % bg)
		var k: float = float(img.get_width()) / get_viewport().get_visible_rect().size.x
		for n: Node in hud.find_children("*", "Label", true, false):
			var l: Label = n as Label
			if not l.is_visible_in_tree() or l.text.strip_edges() == "":
				continue
			var gr: Rect2 = l.get_global_rect()
			var r: Rect2i = Rect2i(Vector2i(gr.position * k), Vector2i(gr.size * k))
			var ratio: float = label_ratio(img, r)
			if ratio < MIN_RATIO:
				_fails += 1
				print("CONTRAST FAIL bg=%s '%s' ratio=%.2f" % [bg, l.text.left(30), ratio])
	print("CONTRAST %s (%d failures, min %.1f:1)" % ["PASS" if _fails == 0 else "FAIL", _fails, MIN_RATIO])
	get_tree().quit(0 if _fails == 0 else 1)
