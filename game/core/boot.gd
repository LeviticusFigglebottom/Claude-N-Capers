## Entry scene. Owner: LEAD. Hands control to ENV B's app shell (menu flow), which owns the whole
## application flow incl. direct launch flags (D-024):
##   --heist=<id> [--seed=<n>] [--difficulty=<0..5>]   skip menus, launch solo, HUD + payday as normal
extends Node

const APP_SHELL: String = "res://content/ui/menus/menu_flow.tscn"


func _ready() -> void:
	var args: Dictionary = parse_args(OS.get_cmdline_user_args())
	Log.info(&"boot", "CAPERWORKS boot, args=%s" % [args])
	if ResourceLoader.exists(APP_SHELL):
		get_tree().change_scene_to_file.call_deferred(APP_SHELL)
	else:
		Log.error(&"boot", "app shell missing: %s" % APP_SHELL)


static func parse_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in argv:
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out
