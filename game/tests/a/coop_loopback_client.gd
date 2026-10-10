## A3-07 loopback client process (launched by test_a3_07_coop_loopback.gd, never shipped):
## godot --headless --path game res://tests/a/coop_loopback_client.tscn -- --port=N [--timeout=S]
## Joins the host on localhost, builds the heist replica through HeistLauncher.auto_join, and
## answers the host's LoopbackProbe commands. Quits on "quit", on disconnect or after the timeout.
extends Node

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")

var _deadline_ms: int = 0


func _ready() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var port: int = int(args.get("port", str(Net.DEFAULT_PORT)))
	_deadline_ms = Time.get_ticks_msec() + int(float(args.get("timeout", "120")) * 1000.0)
	var probe: Node = PROBE.new()
	probe.name = PROBE.NODE_NAME
	get_tree().root.add_child.call_deferred(probe)
	multiplayer.server_disconnected.connect(_quit)
	multiplayer.connection_failed.connect(_quit)
	HeistLauncher.auto_join()
	var err: Error = Net.join("127.0.0.1", port)
	if err != OK:
		Log.error(&"loopback", "client: join failed (%d)" % err)
		_quit()
	Log.info(&"loopback", "client: joining 127.0.0.1:%d" % port)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > _deadline_ms:
		Log.warn(&"loopback", "client: timeout, quitting")
		_quit()


func _quit() -> void:
	HeistLauncher.stop_auto_join()
	get_tree().quit(0)
