## PO-15 / D-140 windowed check (LEAD 2026-10-17): per heist and difficulty, the pager-carrying guards present at load,
## the pager cap (PagerSystem + the HUD model) against the D-140 table, and whether any two guards share a post
## (closer than DOUBLE_M for DOUBLE_S or more while the heist runs). Direct launch (stated shortcut: no menus),
## no crew AI, the player stands still unmasked at the spawn (casing) so nothing alerts; fast mode (render loop off
## between shots), screenshots at load and at the end with the HUD on.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/po15_check.tscn -- --heist=night_deposit --difficulty=tense --out=/abs/dir [--seed=N] [--secs=40]
## Prints "[PO15] ROW heist|difficulty|seed|guards N|cap N|hud_cap N|expect guards G cap C|doubled K|PASS/FAIL".
## Owner: ENV P.
extends Node

const DOUBLE_M: float = 1.0
const DOUBLE_S: float = 3.0
## D-140 tables (Routine, Tense, Hazardous, Brutal, Lethal, Cataclysm): guards are minimums for GUARDS maps.
const EXPECT: Dictionary = {
	&"night_deposit": {"guards": [4, 4, 4, 4, 4, 4], "fixed": true, "cap": [4, 3, 3, 2, 2, 1]},
	&"shadow_ledger": {"guards": [4, 4, 4, 4, 4, 4], "fixed": true, "cap": [4, 3, 3, 2, 2, 1]},
	&"gallery_night": {"guards": [4, 5, 5, 6, 6, 7], "fixed": false, "cap": [4, 4, 4, 4, 4, 4]},
}
const DIFFS: Dictionary = {"routine": 0, "tense": 1, "hazardous": 2, "brutal": 3, "lethal": 4, "cataclysm": 5}

var rt: HeistRuntime = null
var runner_out: String = ""
var _heist: StringName = &"night_deposit"
var _diff: int = 1
var _seed: int = 21
var _secs: float = 40.0
var _shot: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"heist": _heist = StringName(v)
			"difficulty": _diff = int(DIFFS.get(v, 1))
			"seed": _seed = v.to_int()
			"secs": _secs = v.to_float()
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/po15_check"
	DirAccess.make_dir_recursive_absolute(runner_out)
	_run.call_deferred()


func note(msg: String) -> void:
	print("[PO15 t=%.1f] %s" % [rt.heist_time_s if rt != null else -1.0, msg])


func shot(label: String) -> void:
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%s_%d_%02d_%s.png" % [runner_out, _heist, _diff, _shot, label])
	RenderingServer.render_loop_enabled = false


func _run() -> void:
	rt = await HeistLauncher.launch(_heist, _seed, _diff as Enums.Difficulty, self, {"crew_ai": false})
	if rt == null:
		print("[PO15] RESULT FAIL no runtime")
		get_tree().quit(1)
		return
	for _i: int in 30:
		await get_tree().physics_frame
	var guards: Array[NpcBase] = []
	for n: Node in rt.npcs(&"guard"):
		if n is NpcBase and (n as NpcBase).is_alive():
			guards.append(n as NpcBase)
	var ps: PagerSystem = HeistRuntime.get_service(G.SVC_PAGERS) as PagerSystem
	var cap: int = ps.pagers_max() if ps != null else -1
	var hud_cap: int = int(rt.hud_model.get(&"pagers_max")) if rt.hud_model != null else -1
	note("variants %s" % rt.variants)
	for g: NpcBase in guards:
		note("guard %s at %s" % [g.name, g.global_position])
	await shot("load")
	var close_s: Dictionary = {}  # "a|b" -> seconds closer than DOUBLE_M
	var doubled: Dictionary = {}
	var t0: float = rt.heist_time_s
	RenderingServer.render_loop_enabled = false
	while rt.heist_time_s - t0 < _secs:
		for i: int in guards.size():
			for j: int in range(i + 1, guards.size()):
				var a: NpcBase = guards[i]
				var b: NpcBase = guards[j]
				if not is_instance_valid(a) or not is_instance_valid(b):
					continue
				var key: String = "%s|%s" % [a.name, b.name]
				if a.global_position.distance_to(b.global_position) < DOUBLE_M:
					close_s[key] = float(close_s.get(key, 0.0)) + 0.5
					if float(close_s[key]) >= DOUBLE_S and not doubled.has(key):
						doubled[key] = true
						note("DOUBLED %s within %.1f m for %.1f s at %s" % [key, DOUBLE_M, close_s[key], a.global_position])
				else:
					close_s[key] = 0.0
		for _k: int in int(0.5 * Engine.physics_ticks_per_second):
			await get_tree().physics_frame
	await shot("end")
	var want: Dictionary = EXPECT.get(_heist, {})
	var want_g: int = int((want.get("guards", [0, 0, 0, 0, 0, 0]) as Array)[_diff])
	var want_c: int = int((want.get("cap", [0, 0, 0, 0, 0, 0]) as Array)[_diff])
	var guards_ok: bool = guards.size() == want_g if bool(want.get("fixed", false)) else guards.size() >= want_g
	var ok: bool = guards_ok and cap == want_c and hud_cap == want_c and doubled.is_empty() \
		and (_diff == 0 or guards.size() > cap)
	print("[PO15] ROW %s|%d|%d|guards %d|cap %d|hud_cap %d|expect guards %s%d cap %d|doubled %d|%s" % [_heist, _diff, _seed,
		guards.size(), cap, hud_cap, "" if bool(want.get("fixed", false)) else ">=", want_g, want_c, doubled.size(),
		"PASS" if ok else "FAIL"])
	RenderingServer.render_loop_enabled = true
	get_tree().quit(0 if ok else 1)
