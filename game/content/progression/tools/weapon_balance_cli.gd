## Command line for the weapon balance audit (D-115). Owner: ENV B. Tool only; changes no data.
##   /opt/godot/godot --headless --path game -s res://content/progression/tools/weapon_balance_cli.gd -- [difficulty 0..5] [out.md]
## Prints the per-class STOCK tables + mechanical flags (default difficulty 5 = Cataclysm). Report: content/docs/weapon_balance.md.
## The audit is loaded at run time: a -s main script compiles before the autoloads exist.
extends SceneTree

const LIB_PATH: String = "res://content/progression/tools/weapon_balance.gd"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var diff: int = int(args[0]) if args.size() > 0 else 5
	var out_path: String = args[1] if args.size() > 1 else ""
	var lib: GDScript = load(LIB_PATH) as GDScript
	var md: String = str(lib.call(&"run", diff, out_path))
	print(md)
	quit(0 if md.contains("| ") else 1)
