## P3 gate loopback client process (launched by test_coop_loopback.gd, never shipped). Owner: LEAD.
## godot --headless --path game res://tests/integration/bots/coop_client.tscn -- --port=N --timeout=S
## Joins the host on localhost, builds the heist replica through `await HeistLauncher.launch_client()`
## and answers the host's P3LoopbackProbe commands. Quits on "quit", on disconnect or after the timeout.
extends Node

const PROBE: GDScript = preload("res://tests/integration/bots/coop_probe.gd")

var _deadline_ms: int = 0
var _probe: Node = null


func _ready() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var port: int = int(args.get("port", "0"))
	_deadline_ms = Time.get_ticks_msec() + int(float(args.get("timeout", "60")) * 1000.0)
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child.call_deferred(_probe)
	multiplayer.server_disconnected.connect(_quit)
	multiplayer.connection_failed.connect(_quit)
	if port <= 0 or Net.join("127.0.0.1", port, "P3Client") != OK:
		Log.error(&"loopback", "p3 client: cannot join port %d" % port)
		_quit()
		return
	_launch_client()


func _launch_client() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch_client(null, {}, float(_deadline_ms - Time.get_ticks_msec()) / 1000.0)
	if rt == null:
		Log.warn(&"loopback", "p3 client: launch_client() returned null")
		return
	if is_instance_valid(_probe):
		_probe.set(&"launched_rt", rt)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > _deadline_ms:
		Log.warn(&"loopback", "p3 client: timeout, quitting")
		_quit()


func _quit() -> void:
	get_tree().quit(0)
