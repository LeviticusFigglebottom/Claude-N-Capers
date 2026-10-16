## X-4 windowed evidence (D-086): plays each heist's X4StealthFlow route (x4_stealth_flow.gd, the same route and
## seed as test_x4_<heist>_stealth.gd) with rendering on and saves one end-of-heist PNG per heist,
## x4_<heist>_stealth.png: a chase view of the bot in the rolled escape just after heist_ended(success, stealth).
## PNGs go to --cap-out. --x4-heists=a,b limits the heists. Exit code 0 = every route won in stealth. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 \
##     res://tests/a/e2e/x4_stealth_capture.tscn -- --cap-out=/abs/dir
extends Node

const RUNS: Array[Array] = [[&"night_deposit", 11], [&"shadow_ledger", 11], [&"gallery_night", 11]]

var _out: String = ""
var _only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cap-out="):
			_out = a.trim_prefix("--cap-out=")
		elif a.begins_with("--x4-heists="):
			_only = a.trim_prefix("--x4-heists=").split(",", false)
	if _out == "":
		_out = OS.get_user_data_dir() + "/x4"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var failed: int = 0
	for run: Array in RUNS:
		var heist: StringName = run[0]
		if not _only.is_empty() and not _only.has(String(heist)):
			continue
		var flow: X4StealthFlow = X4StealthFlow.new(self)
		# llvmpipe: the route runs without drawing (minutes instead of tens of minutes); the shot turns it back on.
		RenderingServer.render_loop_enabled = false
		var ok: bool = await flow.launch(heist, int(run[1]))
		if ok:
			ok = await X4StealthRoutes.play(flow)
		RenderingServer.render_loop_enabled = true
		var won: bool = ok and flow.alarms.is_empty() and flow.ended.size() == 1 \
			and bool(flow.ended[0].get("success", false)) and bool(flow.ended[0].get("stealth", false))
		print("[X4CAP] %s: %s alarms=%s objectives=%s secured=%s failures=%s" % [heist, "WON" if won else "FAILED",
			flow.alarms, flow.completed, flow.secured_loot, flow.failures])
		if flow.rt != null:
			await _shot(flow, "x4_%s_stealth" % heist)
		failed += 0 if won else 1
		await flow.teardown()
		await _wait(0.5)
	print("[X4CAP] done: %s (%d failed)" % [_out, failed])
	get_tree().quit(1 if failed > 0 else 0)


## A chase view of the bot in the escape: from the clearest of 8 directions around it (up to 5 m out, 2.5 m up, pulled
## in front of any wall), looking at it. The first-person viewmodel overlay and the HUD are hidden for the shot.
func _shot(flow: X4StealthFlow, tag: String) -> void:
	var c: CrewController = flow.crew
	var target: Vector3 = c.global_position + Vector3.UP * 1.0
	var space: PhysicsDirectSpaceState3D = c.get_world_3d().direct_space_state
	var best: Vector3 = target + Vector3(0, 2.0, 2.0)
	var best_d: float = -1.0
	for k: int in range(8):
		var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * float(k) / 8.0)
		var want: Vector3 = target + dir * 5.0 + Vector3.UP * 2.5
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target, want, 1 | 2)
		q.exclude = [c.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		var at: Vector3 = want if hit.is_empty() else target.lerp(hit["position"] as Vector3, 0.85)
		if at.distance_to(target) > best_d:
			best_d = at.distance_to(target)
			best = at
	var cam: Camera3D = Camera3D.new()
	flow.rt.add_child(cam)
	cam.global_position = best
	cam.look_at(target)
	cam.cull_mask &= ~(CrewView.VIEWMODEL_LAYER | CrewView.VIEWMODEL_LIT_LAYER)
	cam.current = true
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var fill: OmniLight3D = OmniLight3D.new()
	flow.rt.add_child(fill)
	fill.global_position = target + Vector3.UP * 2.5
	fill.omni_range = 12.0
	fill.light_energy = 1.2
	await _wait(1.5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, tag])
	print("[X4CAP] shot %s (camera %.1f m out)" % [tag, best_d])


## Game seconds (scaled physics time), not wall time: under llvmpipe a wall-clock timer can end well under 1 game s.
func _wait(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
