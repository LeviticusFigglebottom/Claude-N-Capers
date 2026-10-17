## D-116 first-person pistol / revolver (one-handed): the FIRING hand's thumb wraps the frame. Measured in the real
## game pose (heist launch, mask up, secondary drawn, real input), hip and settled ADS, on every pistol and revolver:
## the thumb skin (vertices whose strongest bone is thumb_0[1-3].R) goes at most MAX_DEPTH_MM into the gun (ENV P's
## PFingerClip test: nearest face side + ray parity) and the thumb tip (thumb_03.R skin) lies on the frame, its closest
## vertex at most MAX_GAP_MM from the gun surface. Prints "[THUMB]" report lines. Owner: ENV D.
extends TestCase

const PISTOLS: Array[StringName] = [&"weapon.kestrel_p9", &"weapon.marshal_357", &"weapon.sparrow_mp",
	&"weapon.warden_45", &"weapon.wren_380", &"weapon.akimbo_warden_45"]
## 2026-10-16: the thumb tips are on the frame and never inside; 1-9 base vertices go 1.7-4.0 mm in, all at the web of
## the hand against the tang / beavertail just above the grip (gun-local x -0.013..+0.002, z 0.01..0.04). That is the
## high grip's web pressed on the frame. LEAD ruling QD-1 (2026-10-17): accepted as skin compression on a high grip; the
## hand seat stays (the PO-approved D-116 sight picture). This bound guards today's worst (wren_380 ads 4.0 mm).
const MAX_DEPTH_MM: float = 4.5
const MAX_GAP_MM: float = 4.0

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(wid: StringName) -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = wid
	l.secondary_mods = [] as Array[StringName]
	l.resolved_secondary = LoadoutResolver.resolve_weapon(wid, l.secondary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await _inp.tap(&"slot_secondary")
	await wait_physics_frames(90)
	return c


func test_firing_thumb_on_the_frame() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	for w: StringName in PISTOLS:
		var c: CrewController = await _launch(w)
		var fp: FpViewmodel = CrewView.of(c).fp_viewmodel()
		for pose: String in ["hip", "ads"]:
			if pose == "ads":
				_inp.press(&"aim")
				await wait_physics_frames(60)
			var r: Dictionary = await _measure(fp, fp.weapon_visual as Node3D)
			assert_true(bool(r.get("ok", false)), "%s %s measured" % [w, pose])
			print("[THUMB] %s %s set=%s thumb verts=%d inside=%d depth=%.1fmm (tip %.1f, base %.1f) tip_gap=%.1fmm" % [w, pose,
				fp.anim_set, int(r.get("verts", 0)), int(r.get("inside", 0)), float(r.get("depth_mm", 0.0)),
				float(r.get("tip_depth_mm", 0.0)), float(r.get("base_depth_mm", 0.0)),
				float(r.get("gap_mm", INF))])
			assert_true(float(r.get("depth_mm", INF)) <= MAX_DEPTH_MM, "%s %s: thumb at most %.0f mm inside the gun (%.1f)"
				% [w, pose, MAX_DEPTH_MM, float(r.get("depth_mm", INF))])
			assert_true(float(r.get("gap_mm", INF)) <= MAX_GAP_MM, "%s %s: thumb tip on the frame (gap %.1f mm)"
				% [w, pose, float(r.get("gap_mm", INF))])
		await after_each()


## {"ok", "verts", "inside", "depth_mm", "gap_mm"} for the right thumb, sampled in Skeleton3D.skeleton_updated
## (the modifier-applied pose), as PFingerClip.measure.
func _measure(fp: FpViewmodel, gun: Node3D) -> Dictionary:
	var sk: Skeleton3D = fp.skeleton
	var arms: MeshInstance3D = sk.get_node_or_null(^"Arms") as MeshInstance3D if sk != null else null
	if arms == null or arms.skin == null or gun == null:
		return {"ok": false}
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func() -> void:
		if got[0].is_empty():
			got[0] = _measure_now(sk, arms, gun)
	sk.skeleton_updated.connect(cb)
	for _i: int in 4:
		if not got[0].is_empty():
			break
		await get_tree().process_frame
	sk.skeleton_updated.disconnect(cb)
	return got[0] if not got[0].is_empty() else {"ok": false}


func _measure_now(sk: Skeleton3D, arms: MeshInstance3D, gun: Node3D) -> Dictionary:
	var skin: Skin = arms.skin
	var bind_mats: Array[Transform3D] = []
	var bind_kind: PackedInt32Array = []   # 0 = other, 1 = thumb_01/02.R, 2 = thumb_03.R (the tip)
	for i: int in skin.get_bind_count():
		var b: int = skin.get_bind_bone(i)
		if b < 0:
			b = sk.find_bone(skin.get_bind_name(i))
		bind_mats.append(sk.global_transform * sk.get_bone_global_pose(b) * skin.get_bind_pose(i) if b >= 0
			else Transform3D.IDENTITY)
		var bn: String = sk.get_bone_name(b) if b >= 0 else ""
		bind_kind.append(2 if bn == "thumb_03.R" else (1 if bn.begins_with("thumb") and bn.ends_with(".R") else 0))
	var pts: PackedVector3Array = []
	var tip: PackedByteArray = []
	for s: int in arms.mesh.get_surface_count():
		var arr: Array = arms.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if verts.is_empty() or bones.is_empty():
			continue
		var k: int = bones.size() / verts.size()
		for v: int in verts.size():
			var best: int = -1
			var best_w: float = 0.0
			for j: int in k:
				if weights[v * k + j] > best_w:
					best_w = weights[v * k + j]
					best = bones[v * k + j]
			if best < 0 or bind_kind[best] == 0:
				continue
			var p: Vector3 = Vector3.ZERO
			var wsum: float = 0.0
			for j: int in k:
				var w: float = weights[v * k + j]
				if w > 0.0:
					p += (bind_mats[bones[v * k + j]] * verts[v]) * w
					wsum += w
			pts.append(p / maxf(wsum, 1e-6))
			tip.append(1 if bind_kind[best] == 2 else 0)
	if pts.is_empty():
		return {"ok": false}
	var tris: PackedVector3Array = PFingerClip._gun_triangles(gun)
	var out: Dictionary = {"ok": not tris.is_empty(), "verts": pts.size(), "inside": 0, "depth_mm": 0.0, "gap_mm": INF}
	for i: int in pts.size():
		var hit: Array = PFingerClip._nearest(pts[i], tris)
		if hit.is_empty():
			continue
		var d_mm: float = float(hit[0]) * 1000.0
		var inside: bool = float(hit[1]) < 0.0 and PFingerClip._inside_parity(pts[i], tris)
		if inside:
			out["inside"] = int(out["inside"]) + 1
			out["depth_mm"] = maxf(float(out["depth_mm"]), d_mm)
			var key: String = "tip_depth_mm" if tip[i] == 1 else "base_depth_mm"
			out[key] = maxf(float(out.get(key, 0.0)), d_mm)
			if OS.has_environment("D_THUMB_DEBUG"):
				print("[THUMB-V] tip=%d depth=%.1fmm gun-local %s" % [tip[i], d_mm, gun.global_transform.affine_inverse() * pts[i]])
		if tip[i] == 1:
			out["gap_mm"] = minf(float(out["gap_mm"]), 0.0 if inside else d_mm)
	return out
