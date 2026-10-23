## Load-time ReflectionProbe warm-up (LEAD r287, C's metal_reflection sweep). Owner: ENV A.
## An UPDATE_ONCE probe is rendered the first time it is in a camera's view, one capture step per frame and one probe
## at a time (RendererSceneCull: "busy"), so in a map with dozens of probes the metals near a probe read dark for
## ~14-20 frames the first time the player looks there. HeistLauncher calls warm(map) before handing the heist over:
## a temporary top-down orthographic camera (its own SubViewport on the map's World3D) covers the whole map, so every
## probe is in view, and the probes switch to UPDATE_ALWAYS (every capture step within one frame) PROBES_PER_FRAME at
## a time for one drawn frame, then back to UPDATE_ONCE. Each warmed probe gets META_WARMED. Rendering peers only
## (headless draws nothing); options.probe_prewarm forces it (tests). Generic: any subtree (SafehouseHost may call it).
class_name ProbeWarmup
extends RefCounted

const META_WARMED: StringName = &"probe_warmed"
## Probes switched to UPDATE_ALWAYS per drawn frame (each renders its 6 faces that frame: keep the spike bounded).
const PROBES_PER_FRAME: int = 6
## Frames drawn per batch (the probe joins the render list on the frame it is in view).
const FRAMES_PER_BATCH: int = 2
const VIEW_PX: int = 64


## Whether this peer should warm probes (`options`: a launch's options; "probe_prewarm" overrides the default).
static func wanted(options: Dictionary) -> bool:
	return bool(options.get("probe_prewarm", DisplayServer.get_name() != "headless"))


## Every UPDATE_ONCE ReflectionProbe under `root`.
static func probes(root: Node) -> Array[ReflectionProbe]:
	var out: Array[ReflectionProbe] = []
	if root == null:
		return out
	for n: Node in root.find_children("*", "ReflectionProbe", true, false):
		var p: ReflectionProbe = n as ReflectionProbe
		if p != null and p.update_mode == ReflectionProbe.UPDATE_ONCE:
			out.append(p)
	return out


## Render every UPDATE_ONCE probe under `root` once. Returns how many were warmed.
static func warm(root: Node3D) -> int:
	var list: Array[ReflectionProbe] = probes(root)
	if list.is_empty() or not root.is_inside_tree():
		return 0
	var tree: SceneTree = root.get_tree()
	var t0: int = Time.get_ticks_msec()
	var vp: SubViewport = SubViewport.new()
	vp.name = "ProbeWarmup"
	vp.size = Vector2i(VIEW_PX, VIEW_PX)
	vp.world_3d = root.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	root.add_child(vp)
	_frame_all(cam, list)
	var done: int = 0
	var i: int = 0
	while i < list.size():
		var batch: Array[ReflectionProbe] = list.slice(i, i + PROBES_PER_FRAME)
		for p: ReflectionProbe in batch:
			if is_instance_valid(p):
				p.update_mode = ReflectionProbe.UPDATE_ALWAYS
		for _f: int in FRAMES_PER_BATCH:
			await _drawn(tree)
		for p: ReflectionProbe in batch:
			if is_instance_valid(p):
				p.update_mode = ReflectionProbe.UPDATE_ONCE
				p.set_meta(META_WARMED, true)
				done += 1
		i += PROBES_PER_FRAME
	if is_instance_valid(vp):
		vp.queue_free()
	if tree != null:
		Log.info(&"heist", "probe warm-up: %d reflection probes in %d ms" % [done, Time.get_ticks_msec() - t0])
	return done


## One drawn frame (headless never draws, so its frame_post_draw never comes: a process frame stands in).
static func _drawn(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
	else:
		await RenderingServer.frame_post_draw


## Point the orthographic camera straight down over the probes' combined bounds, deep enough to contain them all.
static func _frame_all(cam: Camera3D, list: Array[ReflectionProbe]) -> void:
	var box: AABB = AABB(list[0].global_position, Vector3.ZERO)
	for p: ReflectionProbe in list:
		box = box.merge(AABB(p.global_position - p.size * 0.5, p.size))
	var top: Vector3 = box.get_center() + Vector3.UP * (box.size.y * 0.5 + 10.0)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), top)
	cam.size = maxf(box.size.x, box.size.z) + 20.0
	cam.near = 0.05
	cam.far = box.size.y + 40.0
