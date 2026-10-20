## (e) co-op FP / third-person FX check, the client window (spawned by coop_fx_capture.gd, never shipped).
## Joins the host on localhost, builds the replica, answers A's LoopbackProbe commands (intent, snapshot) and
## saves a PNG on every shot_fx it sees: `client_own_NN.png` for its own first-person shots (flag bit1: the
## viewmodel flash, smoke and tracer from FpViewmodelFx) and `client_remote_NN.png` for the host's shots
## (third person: VfxDirector at the host's world gun). Prints "FXC client ..." lines. Owner: ENV P.
extends Node

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")

var _out: String = ""
var _deadline_ms: int = 0
var _n: Dictionary = {"own": 0, "remote": 0}
var _busy: bool = false


func _ready() -> void:
	var port: int = Net.DEFAULT_PORT
	var timeout_s: float = 600.0
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"port": port = int(v)
			"out": _out = v
			"timeout": timeout_s = float(v)
	_deadline_ms = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	var probe: Node = PROBE.new()
	probe.name = PROBE.NODE_NAME
	get_tree().root.add_child.call_deferred(probe)
	multiplayer.server_disconnected.connect(_quit)
	multiplayer.connection_failed.connect(_quit)
	EventBus.shot_fx.connect(_on_shot_fx)
	if Net.join("127.0.0.1", port) != OK:
		print("FXC client join failed")
		_quit()
		return
	var rt: HeistRuntime = await HeistLauncher.launch_client(null, {}, timeout_s)
	if is_instance_valid(probe):
		probe.set(&"launched_rt", rt)
	print("FXC client replica=%s" % (rt != null))


func _on_shot_fx(_origin: Vector3, end: Vector3, _normal: Vector3, _surface: StringName, _weapon_class: StringName,
		shooter: int, flags: int) -> void:
	var kind: String = "own" if flags & FpViewmodelFx.FLAG_FIRST_PERSON != 0 else "remote"
	print("FXC client shot_fx shooter=%d flags=%d %s end=%s t=%d" % [shooter, flags, kind, end.snappedf(0.01),
		Time.get_ticks_msec()])
	if not _busy:
		_grab(kind)


func _grab(kind: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	_n[kind] = int(_n[kind]) + 1
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/client_%s_%02d.png" % [_out, kind, int(_n[kind])]))
	await RenderingServer.frame_post_draw  # the next frame too: a third-person flash may spawn a frame late
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/client_%s_%02d_next.png" % [_out, kind, int(_n[kind])]))
	_busy = false


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > _deadline_ms:
		_quit()


func _quit() -> void:
	get_tree().quit(0)
