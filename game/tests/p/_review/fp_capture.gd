## PT-03 first-person frame capture (run as a SCENE so autoloads load; under xvfb, never --headless):
## flock /workspace/cnc-team/render.lock xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot \
##   --audio-driver Dummy --path game res://tests/p/_review/fp_capture.tscn
## Saves PNGs of key moments to /workspace/cnc-team/p/renders/. Real input only (PInputDriver). Owner: ENV P.
extends Node

const OUT: String = "/workspace/cnc-team/p/renders/"

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = &"weapon.brute_12"  # PT-03: a primary so the swap / primary frames show a second gun
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	_rt = await HeistLauncher.launch(&"glasshouse", 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "loadouts": {0: l}})
	_rt.isolate_npc(null)
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	await _frames(30)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _shot("01_spawn_casing")
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s * 0.5)
	await _shot("02_mask_up_mid", false)
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await _frames(20)
	await _inp.tap(&"slot_secondary")
	await _frames(60)
	await _shot("03_masked_hip_secondary")
	_inp.press(&"aim")
	await _frames(40)
	await _shot("04_ads_secondary")
	_inp.release(&"aim")
	await _inp.tap(&"swap_weapon")
	await _frames(60)
	await _shot("05_hip_primary")
	_inp.press(&"aim")
	await _frames(40)
	await _shot("06_ads_primary")
	_inp.press(&"fire")
	await _frames(2)
	await _shot("07_ads_primary_firing", false)
	print("[PT-03] after fire: mag %d/%d" % [c.weapons.mag(c.weapons.equipped_slot), c.weapons.mag_size(c.weapons.equipped_slot)])
	_inp.release_all()
	await _frames(20)
	await _inp.tap(&"reload")
	await _frames(12)
	print("[PT-03] reloading=%s slot=%d" % [c.weapons.reloading, c.weapons.equipped_slot])
	await _shot("08_reload_mid", false)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await _frames(40)
	await _shot("09_sprint")
	_inp.release_all()
	_inp.press(&"crouch")
	await _frames(30)
	await _shot("10_crouch")
	print("[PT-03] crouched=%s" % c.crouched)
	_inp.release_all()
	print("[PT-03] crew at ", c.global_position, " done")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().process_frame


func _shot(name: String, settle: bool = true) -> void:
	# Wait for swaps/draws to finish in game time (llvmpipe frames are slow and long), then 8 frames.
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var vm: FpViewmodel = null
	for n: Node in c.find_children("*", "", true, false):
		if n is FpViewmodel:
			vm = n
	var t: int = 0
	while settle and vm != null and vm.action == FpViewmodel.Action.SWAP and t < 600:
		await get_tree().process_frame
		t += 1
	await _frames(8)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("[PT-03] saved ", OUT + name + ".png")
