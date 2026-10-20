## Ostrander Federal VoxelGI bake (OF-C2 G2, as Night Deposit / Gallery Night; one data file per level band, of_gi.gd
## GI_BANDS). Owner: ENV C. Needs a real renderer (the voxelizer returns an empty octree under --headless), so run it
## under xvfb with the Vulkan driver (lavapipe works; opengl3 / Compatibility has no VoxelGI and also bakes empty)
## after build_greybox.gd (~30 s):
##   xvfb-run -a -s "-screen 0 640x480x24" /opt/godot/godot --path game \
##     --script res://world/heists/ostrander_federal/greybox/bake_gi.gd
## Voxelizes the map's Geometry visuals inside each band's box into ostrander_federal_voxelgi_<band>.res, which the
## band's Lighting/VoxelGI<Band> node references. The bake reads only the generated geometry (no RNG, no lights), so
## it is deterministic: re-baking an unchanged scene rewrites byte-identical files (checked 2026-10-20, sha256). Each
## file keeps its previous uid (ResourceSaver.set_uid) so the scene's references never churn. Re-bake whenever the shell / Geometry changes.
extends SceneTree

const SCENE_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const GI: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_gi.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map: Node3D = (load(SCENE_PATH) as PackedScene).instantiate() as Node3D
	var mission: Node = map.get_node_or_null("Mission")
	if mission != null:
		mission.set_script(null)
	get_root().add_child(map)
	printerr("bake_gi: map in tree")
	await process_frame
	var rc: int = 0
	for band: Array in GI.GI_BANDS:
		var path: String = GI.OUT_DIR + String(band[1])
		var vg: VoxelGI = map.get_node("Lighting/" + String(band[0])) as VoxelGI
		var old_uid: int = ResourceLoader.get_resource_uid(path)
		printerr("bake_gi: baking %s" % band[0])
		vg.bake(map.get_node("Geometry"), false)
		var baked: VoxelGIData = vg.data
		if baked == null or baked.get_octree_cells().is_empty():
			push_error("bake_gi: %s: empty voxel octree (run under xvfb, not --headless)" % band[0])
			rc = 1
			continue
		baked.interior = bool(band[5])
		var err: int = ResourceSaver.save(baked, path)
		if err == OK and old_uid != ResourceUID.INVALID_ID:
			err = ResourceSaver.set_uid(path, old_uid)
		printerr("bake_gi: saved %s (%d octree bytes, err %d)" % [path, baked.get_octree_cells().size(), err])
		if err != OK:
			rc = 1
	quit(rc)
