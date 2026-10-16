## ui_hud v1.16 check (LEAD 2026-10-16): loud Golden Hour, the Osprey 762 + 4x scope, B's real HUD, the workshop
## safe's drill placed and jammed; frames at the hip and scoped (full ADS) looking at the drill, so the JAMMED panel /
## fix prompt can be checked against the scope ring (B moves text out of LocalHudModel.scope_ring). Real input for
## mask, swap and aim (PInputDriver); the drill placement / jam is a harness shortcut. Prints the model fields.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 1280x720 --audio-driver Dummy \
##     res://tests/p/_review/scope_hud_capture.tscn -- --out=/abs/dir [--dist=1.6]
## Owner: ENV P.
extends Node

const HUD_SCENE: String = "res://content/ui/hud/hud.tscn"

var _out: String = "user://scope_hud_capture"
## Stand-off from the safe (m): inside the drill's interact range the HUD shows the fix prompt.
var _dist: float = 1.6


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--dist="):
			_dist = a.trim_prefix("--dist=").to_float()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, label])
	print("[SCOPEHUD] shot %s" % label)


## Po5Pilot's driver interface.
func note(msg: String) -> void:
	print("[SCOPEHUD] %s" % msg)


func shot(label: String) -> void:
	await _shot(label)


func _run() -> void:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = &"weapon.osprey_762"
	l.primary_mods = [&"mod.osprey_scope_4x"] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	var rt: HeistRuntime = await HeistLauncher.launch(&"glasshouse", 1792002290, Enums.Difficulty.ROUTINE, self,
		{"skip_casing": true, "crew_ai": false, "loadouts": {0: l}})
	var hud: Node = (load(HUD_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(hud)  # finds the local HUD model through its group (ui_hud.md v1.1)
	var c: CrewController = rt.crew_controller(0) as CrewController
	Modifiers.set_source(c.slot, &"test.scopehud", {&"defense.damage_taken_mult": 0.0})
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_primary")
	rt.stealth.raise_alarm(&"test", 0)
	var safe: Safe = rt.find_child("WorkshopSafe", true, false) as Safe
	var dp: DrillPoint = safe.find_child("SafeDrill", true, false) as DrillPoint if safe != null else null
	if dp == null:
		print("[SCOPEHUD] RESULT FAIL no WorkshopSafe drill")
		get_tree().quit(1)
		return
	dp.runner.place(0, dp.effective_duration())
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, safe.global_transform * Vector3(0, 0.05, -_dist)))
	await _ticks(30)
	var pilot: Po5Pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	await pilot.calibrate()
	await _ticks(10)
	dp.runner.call(&"_jam")  # jam it now (harness shortcut: DeviceRunner's own jam path, panel + prompt included)
	await _ticks(10)
	var target: Vector3 = dp.device_node.global_position if dp.device_node != null else dp.global_position
	await pilot.face(target, 0.01, 2.0)
	await _ticks(30)
	print("[SCOPEHUD] drill state %d (JAMMED %d)" % [dp.runner.state, DeviceRunner.State.JAMMED])
	await _shot("01_hip_drill_jammed")
	inp.press(&"aim")
	var cv: CrewView = CrewView.of(c)
	for _i: int in 600:
		if cv.ads_blend > 0.999:
			break
		await _ticks(1)
	await pilot.face(target, 0.003, 2.0)
	await _ticks(30)
	var hm: Object = rt.hud_model
	print("[SCOPEHUD] scoped_ads=%s scope_ring=%s drill=%d" % [hm.get(&"scoped_ads") if &"scoped_ads" in hm else "-",
		hm.get(&"scope_ring") if &"scope_ring" in hm else "-", dp.runner.state])
	await _shot("02_scoped_drill_jammed")
	inp.release_all()
	print("[SCOPEHUD] RESULT DONE out=%s" % _out)
	get_tree().quit(0)
