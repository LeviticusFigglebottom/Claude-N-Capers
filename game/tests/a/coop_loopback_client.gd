## A3-07 loopback client process (launched by test_a3_07_coop_loopback.gd, never shipped):
## godot --headless --path game res://tests/a/coop_loopback_client.tscn -- --port=N [--timeout=S]
## Joins the host on localhost, builds the heist replica through `await HeistLauncher.launch_client()`
## (`--join=auto`: HeistLauncher.auto_join instead; `--join=dropin`: drops into the host's running heist through
## HeistDropIn.request_join, QB-B6-DROPIN), and
## answers the host's LoopbackProbe commands. Quits on "quit", on disconnect or after the timeout.
extends Node

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")

var _deadline_ms: int = 0
var _probe: Node = null


func _ready() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var port: int = int(args.get("port", str(Net.DEFAULT_PORT)))
	if args.has("no-interp"):
		NetInterp.enabled = false  # P6: the "before" measurement (transforms applied as they arrive)
	_deadline_ms = Time.get_ticks_msec() + int(float(args.get("timeout", "120")) * 1000.0)
	var probe: Node = PROBE.new()
	probe.name = PROBE.NODE_NAME
	_probe = probe
	get_tree().root.add_child.call_deferred(probe)
	multiplayer.server_disconnected.connect(_quit)
	multiplayer.connection_failed.connect(_quit)
	var auto: bool = String(args.get("join", "")) == "auto"
	var dropin: bool = String(args.get("join", "")) == "dropin"
	if auto:
		HeistLauncher.auto_join()
	if dropin:
		Net.connected_to_host.connect(_drop_in, CONNECT_ONE_SHOT)
	var err: Error = Net.join("127.0.0.1", port)
	if err != OK:
		Log.error(&"loopback", "client: join failed (%d)" % err)
		_quit()
		return
	Log.info(&"loopback", "client: joining 127.0.0.1:%d" % port)
	if not auto and not dropin:
		_launch_client()


func _launch_client() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch_client(null, {}, float(_deadline_ms - Time.get_ticks_msec()) / 1000.0)
	if rt == null:
		Log.warn(&"loopback", "client: launch_client() returned null")
		return
	if is_instance_valid(_probe):
		_probe.set(&"launched_rt", rt)
	Log.info(&"loopback", "client: launch_client() returned the replica")


func _drop_in() -> void:
	var svc: HeistDropIn = HeistDropIn.ensure(get_tree())
	svc.joined.connect(func(_slot: int) -> void:
		if is_instance_valid(_probe):
			_probe.set(&"launched_rt", HeistRuntime.current())
		Log.info(&"loopback", "client: dropped in"))
	svc.join_failed.connect(func(_p: int, r: StringName) -> void: Log.warn(&"loopback", "client: drop-in failed (%s)" % r))
	var l: Loadout = CrewWeapons.build_loadout(null)
	svc.request_join({"name": "Dropper", "level": 10, "notoriety": 0, "loadout": LobbyState.loadout_to_dict(l)})


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > _deadline_ms:
		Log.warn(&"loopback", "client: timeout, quitting")
		_quit()


func _quit() -> void:
	HeistLauncher.stop_auto_join()
	get_tree().quit(0)
