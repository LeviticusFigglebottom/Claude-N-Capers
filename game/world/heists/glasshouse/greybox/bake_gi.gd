## Glasshouse VoxelGI bake (C1-08). Owner: ENV C. Needs a real renderer (the voxelizer returns an
## empty octree under --headless), so run it under xvfb after build_greybox.gd:
##   xvfb-run -a -s "-screen 0 640x480x24" /opt/godot/godot --path game \
##     --script res://world/heists/glasshouse/greybox/bake_gi.gd
## Voxelizes the building interior (Geometry visuals) into glasshouse_voxelgi.res, which the map's
## Lighting/VoxelGI node references. The bake is deterministic; the file keeps its previous uid
## (ResourceSaver.set_uid) so the scene's reference never churns.
## LightmapGI was evaluated too: its bake is editor-only (no script API), so it cannot be part of a
## reproducible scripted pipeline (style_guide.md §7 report).
extends SceneTree

const SCENE_PATH: String = "res://world/heists/glasshouse/glasshouse.tscn"
const GI_PATH: String = "res://world/heists/glasshouse/glasshouse_voxelgi.res"


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
	printerr("bake_gi: baking")
	var vg: VoxelGI = map.get_node("Lighting/VoxelGI") as VoxelGI
	var old_uid: int = ResourceLoader.get_resource_uid(GI_PATH)
	vg.bake(map.get_node("Geometry"), false)
	var baked: VoxelGIData = vg.data
	if baked == null or baked.get_octree_cells().is_empty():
		push_error("bake_gi: empty voxel octree (run under xvfb, not --headless)")
		quit(1)
		return
	baked.interior = true
	var err: int = ResourceSaver.save(baked, GI_PATH)
	if err == OK and old_uid != ResourceUID.INVALID_ID:
		err = ResourceSaver.set_uid(GI_PATH, old_uid)
	printerr("bake_gi: saved %s (%d octree bytes, err %d)" % [GI_PATH, baked.get_octree_cells().size(), err])
	quit(0 if err == OK else 1)
