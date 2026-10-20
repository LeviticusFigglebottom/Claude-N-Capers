## Bakes every NPC-carried weapon to its merged third-person scene (NpcWeaponBake.bake_all).
##   godot --headless --path game -s res://content/weapons/tools/npc_weapon_bake_cli.gd
## The bake is loaded at run time: a -s main script compiles before the autoloads exist. Owner: ENV B.
extends SceneTree


func _initialize() -> void:
	var lib: GDScript = load("res://content/weapons/npc_weapon_bake.gd") as GDScript
	for line: String in lib.call(&"bake_all") as Array:
		print(line)
	quit()
