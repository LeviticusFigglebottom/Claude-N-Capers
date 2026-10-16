## Night Deposit variant scan (for the route-aware stealth pass, ENV A's route notes 2026-10-16): launches ND headless
## per seed with the given dev preplanning and prints the camera set, guard rovers, vent and keycard / code rolls,
## so a stealth-friendly seed (cam_c: no C5 on the B5 spine; no exterior rover at the grate) can be picked.
##   /opt/godot/godot --headless --path game res://tests/p/_review/nd_variant_scan.tscn -- --from=1 --to=40 \
##     [--preplan=asset.alternate_entry:pp_spawn_lot,asset.propped_door:pp_vent]
## Owner: ENV P.
extends Node

var _from: int = 1
var _to: int = 20
var _preplan: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"from": _from = v.to_int()
			"to": _to = v.to_int()
			"preplan":
				for pair: String in v.split(",", false):
					var ap: PackedStringArray = pair.split(":")
					_preplan[StringName(ap[0])] = StringName(ap[1]) if ap.size() > 1 else true
	_run.call_deferred()


func _run() -> void:
	for s: int in range(_from, _to + 1):
		var opts: Dictionary = {"crew_ai": false}
		if not _preplan.is_empty():
			opts["preplanning"] = _preplan
		var rt: HeistRuntime = await HeistLauncher.launch(&"night_deposit", s, Enums.Difficulty.ROUTINE, self, opts)
		if rt == null:
			print("[NDSCAN] seed %d: no runtime" % s)
			continue
		var v: Dictionary = rt.variants
		var rovers: Array[String] = []
		for n: Node in rt.npcs(&"guard"):
			var info: Variant = (n as Node).get(&"spawn_info")
			var tags: Variant = (info as Dictionary).get("tags", []) if info is Dictionary else []
			rovers.append(str(tags))
		print("[NDSCAN] seed %d cameras=%s vent=%s keycard=%s code=%s guards=%s spawn_crew0=%s" % [s,
			v.get(&"cameras", v.get(&"camera_set", "?")), v.get(&"vent_open", v.get(&"vent", "?")),
			v.get(&"keycard", "?"), v.get(&"code", "?"), rovers,
			Po5Pilot._v((rt.crew_controller(0) as Node3D).global_position)])
		print("[NDSCAN] seed %d all=%s" % [s, v])
		rt.teardown()
		for _i: int in 3:
			await get_tree().process_frame
	get_tree().quit(0)
