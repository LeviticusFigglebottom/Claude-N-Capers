## Entry scene. Owner: LEAD. Routes to the hub (ENV B) once it exists; supports CLI flags:
##   --heist=<id> --seed=<n> --solo   (direct heist launch, used by dev + tests)
extends Node

const HUB_SCENE: String = "res://content/ui/hub/hub.tscn"


func _ready() -> void:
	var args: Dictionary = parse_args(OS.get_cmdline_user_args())
	Log.info(&"boot", "CAPERWORKS boot, args=%s" % [args])
	if args.has("heist"):
		Net.start_solo()
		var heist_path: String = "res://world/heists/%s/%s.tscn" % [args["heist"], args["heist"]]
		if ResourceLoader.exists(heist_path):
			get_tree().change_scene_to_file.call_deferred(heist_path)
			return
		Log.error(&"boot", "heist scene missing: %s" % heist_path)
	elif ResourceLoader.exists(HUB_SCENE):
		get_tree().change_scene_to_file.call_deferred(HUB_SCENE)


static func parse_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in argv:
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out
