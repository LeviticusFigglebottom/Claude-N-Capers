## Command line for the VO coverage audit (D-117 §6). Owner: ENV B.
##   godot --headless --path game -s res://content/voice/tools/vo_coverage_cli.gd
## Writes content/docs/vo_coverage.md and prints a summary; exit 1 when code can say an id the table lacks.
## The audit is loaded at run time: a -s main script compiles before the autoloads exist.
extends SceneTree

const LIB_PATH: String = "res://content/voice/tools/vo_coverage.gd"


func _initialize() -> void:
	var lib: GDScript = load(LIB_PATH) as GDScript
	var r: Dictionary = lib.call(&"write_report")
	print(lib.call(&"summary_text", r))
	quit(1 if not (r.get("missing", []) as Array).is_empty() else 0)
