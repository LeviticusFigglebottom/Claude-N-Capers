## Safehouse VoxelGI bake (C4-03; D-046, as rolling_thunder/greybox/bake_gi.gd). Owner: ENV C. Needs a real renderer
## (the voxelizer returns an empty octree under --headless), so run it under xvfb with the Vulkan driver after
## build_safehouse.gd:
##   xvfb-run -a -s "-screen 0 640x480x24" /opt/godot/godot --path game \
##     --script res://world/hub/safehouse/greybox/bake_safehouse_gi.gd
## Voxelizes the scene's Geometry into safehouse_voxelgi.res (Lighting/VoxelGI's data). Deterministic (generated
## geometry only); the file keeps its uid. Re-bake whenever the shell changes.
extends SceneTree

const L: GDScript = preload("res://world/hub/safehouse/greybox/safehouse_layout.gd")
const SCENE_PATH: String = "res://world/hub/safehouse/safehouse.tscn"
const OUT_DIR: String = "res://world/hub/safehouse/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map: Node3D = (load(SCENE_PATH) as PackedScene).instantiate() as Node3D
	get_root().add_child(map)
	await process_frame
	var path: String = OUT_DIR + String(L.GI_VOLUME[1])
	var vg: VoxelGI = map.get_node("Lighting/" + String(L.GI_VOLUME[0])) as VoxelGI
	var old_uid: int = ResourceLoader.get_resource_uid(path)
	vg.bake(map.get_node("Geometry"), false)
	var baked: VoxelGIData = vg.data
	if baked == null or baked.get_octree_cells().is_empty():
		push_error("bake_safehouse_gi: empty voxel octree (run under xvfb, not --headless)")
		quit(1)
		return
	baked.interior = true
	var err: int = ResourceSaver.save(baked, path)
	if err == OK and old_uid != ResourceUID.INVALID_ID:
		err = ResourceSaver.set_uid(path, old_uid)
	printerr("bake_safehouse_gi: saved %s (%d octree bytes, err %d)" % [path, baked.get_octree_cells().size(), err])
	quit(0 if err == OK else 1)
