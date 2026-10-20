## intel_export.gd's work, loaded at run time (a -s main script compiles before the autoloads exist, and
## BriefingIntel's dependencies need them). Owner: ENV B.
extends RefCounted


static func export_heist(heist_id: StringName) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BriefingIntel.DATA_DIR))
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
