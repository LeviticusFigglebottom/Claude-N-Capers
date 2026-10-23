## LEAD r298 windowed review: the first-person perk-deck item use pose (FpViewmodelDeck), one frame per kind at the
## middle of its hold (the smoke bomb just before release@) on the dev_sandbox yard, plus the gun drawn back after.
## Writes <out>/<kind>.png and <out>/deck_items_sheet.png.
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://tests/p/_review/deck_items_capture.tscn -- --out=/abs/dir
## Owner: ENV P.
extends Node

const ITEMS: Array[Array] = [
	[&"throwable.boss_injector", &"injector"], [&"throwable.leech_ampule", &"leech_ampule"],
	[&"throwable.steady_flask", &"flask"], [&"throwable.pocket_ecm", &"pocket_ecm"],
	[&"throwable.gas_dispenser", &"gas_dispenser"], [&"throwable.smoke_bomb", &"smoke_bomb"],
]

var _out: String = "user://deck_items"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"dev_sandbox", 2981, Enums.Difficulty.ROUTINE, self,
		{"skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	rt.isolate_npc(null)
	var c: CrewController = rt.crew_controller(0) as CrewController
	c.set_masked(true)
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(6.0, 0.05, 11.0)))
	await _ticks(90)
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	var imgs: Array[Image] = []
	for it: Array in ITEMS:
		var kind: StringName = it[1]
		CrewThrowables.deck_item_fired(c, it[0], kind)
		await _ticks(1)
		var at: float = CombatTweak.data().throw_windup_s * 0.9 if kind == &"smoke_bomb" \
			else FpViewmodelDeck.DRAW_S + float(FpViewmodelDeck.POSES[kind]["hold_s"]) * 0.55
		while vm.action == FpViewmodel.Action.DECK and vm._seq_t < at:
			await _ticks(1)
		print("[DECK] %s action %d t %.2f offset %s rot %s" % [kind, vm.action, vm._seq_t, vm.deck.offset, vm.deck.rot_deg])
		imgs.append(await _shot(String(kind)))
		while vm.action != FpViewmodel.Action.NONE:
			await _ticks(1)
		await _ticks(20)
	imgs.append(await _shot("gun_back"))
	_sheet(imgs)
	print("[DECK] RESULT DONE %d frames %s/deck_items_sheet.png" % [imgs.size(), _out])
	rt.teardown()
	get_tree().quit(0)


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().process_frame


func _shot(nm: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(PCaptureName.safe_path("%s/%s.png" % [_out, nm]))
	return img


func _sheet(imgs: Array[Image]) -> void:
	var w: int = 320
	var h: int = 180
	var cols: int = 3
	var sheet: Image = Image.create(w * cols, h * ceili(imgs.size() / float(cols)), false, Image.FORMAT_RGBA8)
	for k: int in imgs.size():
		var img: Image = imgs[k].duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	sheet.save_png(PCaptureName.safe_path("%s/deck_items_sheet.png" % _out))
