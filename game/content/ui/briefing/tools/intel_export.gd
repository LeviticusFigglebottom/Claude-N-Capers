## Headless briefing-intel exporter (D-115). Owner: ENV B. Tool only, never loaded by the game.
##   /opt/godot/godot --headless --path game --script res://content/ui/briefing/tools/intel_export.gd -- <heist_id> [...]
## Text-scans each heist's map (HeistDef.map_scene, read-only, never instanced) with BriefingIntel.scan and
## writes res://content/data/briefing/intel/<heist>.tres (BriefingIntelData): counts, frame sensors, the room
## (RoomVolume) of each lock / device from the scene transforms, and the surprises (the variant table's rare
## events that pass BriefingIntel.is_surprise). Rerun it after a map changes its cameras, guard spawns, locks,
## rooms, variant slots or rare events; test_briefing_intel fails while a file is stale.
extends SceneTree


func _init() -> void:
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	var failed: int = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BriefingIntel.DATA_DIR))
	for id: String in ids:
		if not export_heist(StringName(id)):
			failed += 1
	quit(1 if failed > 0 or ids.is_empty() else 0)


func export_heist(heist_id: StringName) -> bool:
	var path: String = HeistRegistry.map_scene_path(heist_id)
	if path == "" or not FileAccess.file_exists(path):
		printerr("intel_export: no map scene for %s" % heist_id)
		return false
	var d: BriefingIntelData = BriefingIntel.scan(heist_id, path)
	var out: String = BriefingIntel.data_path(heist_id)
	var err: int = ResourceSaver.save(d, out)
	print("intel_export: %s -> %s (%s) fixed=%s groups=%s" % [heist_id, out, error_string(err), d.fixed, d.groups.keys()])
	print("  rooms=%s surprises=%s sensor_gate=%s" % [d.fixed_rooms, d.surprises, d.sensor_gate.get("group", "-")])
	return err == OK
