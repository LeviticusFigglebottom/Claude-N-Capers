## Headless briefing-intel exporter (D-115). Owner: ENV B. Tool only, never loaded by the game.
##   /opt/godot/godot --headless --path game --script res://content/ui/briefing/tools/intel_export.gd -- <heist_id> [...]
## Text-scans each heist's map (HeistDef.map_scene, read-only, never instanced) with BriefingIntel.scan and
## writes res://content/data/briefing/intel/<heist>.tres (BriefingIntelData): counts, frame sensors, the room
## (RoomVolume) of each lock / device from the scene transforms, and the surprises (the variant table's rare
## events that pass BriefingIntel.is_surprise). Rerun it after a map changes its cameras, guard spawns, locks,
## rooms, variant slots or rare events; test_briefing_intel fails while a file is stale.
## The export itself is intel_export_run.gd, loaded at run time: a -s main script compiles before the autoloads exist.
extends SceneTree


func _initialize() -> void:
	var lib: GDScript = load("res://content/ui/briefing/tools/intel_export_run.gd") as GDScript
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	var failed: int = 0
	for id: String in ids:
		if not bool(lib.call(&"export_heist", StringName(id))):
			failed += 1
	quit(1 if failed > 0 or ids.is_empty() else 0)
