## Builds the firing range level from RangeLayout data (B1-05). Owner: ENV B.
## Floors and walls are instanced pieces of ENV C's greybox kit (arch_*.glb, with their own
## materials and trimesh collision); lines, the bench, signs and targets are range-owned.
class_name RangeBuilder
extends RefCounted

## Group of distance-marker nodes (meta `distance_m`); range-local.
const MARKER_GROUP: StringName = &"range_marker"
## D-111: the per-target labels (distance, dummy name, HP) fade out past this distance from the camera;
## far away they were unreadable specks that cluttered the view. Area titles and lane markers stay.
const LABEL_FADE_M: float = 30.0
## Lane line segment length (m): short enough that each piece gets its nearest lights.
const LANE_SEGMENT_M: float = 8.0


## Floors, walls, lane lines and the bench under `parent`. Returns {"floors": int, "walls": int}.
static func build_level(layout: RangeLayout, tweak: RangeTweak, parent: Node3D) -> Dictionary:
	var floors: int = 0
	var walls: int = 0
	var tile: float = layout.floor_piece_size_m
	var x0: float = -layout.width_m * 0.5
	var nx: int = ceili(layout.width_m / tile - RangeMath.EPS)
	var nz: int = ceili(layout.length_m() / tile - RangeMath.EPS)
	var floor_root: Node3D = _group_node(parent, "Floor")
	for i: int in range(nx):
		for j: int in range(nz):
			if _place(layout.floor_piece, floor_root, Vector3(x0 + float(i) * tile, 0.0, layout.back_z_m - float(j) * tile), 0.0):
				floors += 1
	var wall_root: Node3D = _group_node(parent, "Walls")
	var seg: float = layout.wall_piece_length_m
	var nside: int = ceili(layout.length_m() / seg - RangeMath.EPS)
	for j: int in range(nside):
		var z: float = layout.back_z_m - float(j) * seg
		# Rotated +90 deg about Y a wall runs toward -Z from its origin.
		walls += int(_place(layout.wall_piece, wall_root, Vector3(x0, 0.0, z), 90.0))
		walls += int(_place(layout.wall_piece, wall_root, Vector3(-x0, 0.0, z), 90.0))
	var nend: int = ceili(layout.width_m / seg - RangeMath.EPS)
	for i: int in range(nend):
		var x: float = x0 + float(i) * seg
		walls += int(_place(layout.wall_piece, wall_root, Vector3(x, 0.0, layout.back_z_m), 0.0))
		walls += int(_place(layout.wall_piece, wall_root, Vector3(x, 0.0, layout.far_z_m), 0.0))
	_build_lane_lines(layout, tweak, _group_node(parent, "LaneLines"))
	_build_bench(layout, tweak, parent)
	return {"floors": floors, "walls": walls}


## One marker node per layout.marker_distances entry (floor line + a sign on each side wall).
static func build_markers(layout: RangeLayout, tweak: RangeTweak, parent: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var root: Node3D = _group_node(parent, "Markers")
	var line_mat: StandardMaterial3D = _flat_mat(tweak.marker_line_color)
	var lanes_w: float = layout.lane_width_m * float(layout.lane_count())
	var sign_x: float = layout.width_m * 0.5 - layout.marker_sign_inset_m
	for d: float in layout.marker_distances:
		var m: Node3D = Node3D.new()
		m.name = "Marker_%dm" % roundi(d)
		m.position = Vector3(0.0, 0.0, -d)
		m.set_meta(&"distance_m", d)
		m.add_to_group(MARKER_GROUP)
		root.add_child(m)
		m.add_child(_strip(Vector3(lanes_w, 0.01, layout.marker_line_width_m), Vector3(0.0, 0.006, 0.0), line_mat))
		for side: float in [-1.0, 1.0]:
			# Wall signs are angled toward the shooting line (no billboard, so they never clip the wall).
			var s: Label3D = sign_label(UiText.t(&"ui.range.marker", {"m": roundi(d)}), tweak)
			s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			s.position = Vector3(side * sign_x, layout.marker_sign_height_m, 0.0)
			s.rotation.y = -side * deg_to_rad(layout.marker_sign_yaw_deg)
			m.add_child(s)
		out.append(m)
	return out


## Static targets, one per lane at its layout distance.
static func build_targets(layout: RangeLayout, dummy: RangeDummyDef, difficulty: int, tweak: RangeTweak,
		parent: Node3D) -> Array[RangeTarget]:
	var out: Array[RangeTarget] = []
	var root: Node3D = _group_node(parent, "Targets")
	for lane: int in range(layout.lane_count()):
		var d: float = layout.lane_target_distances[lane]
		var t: RangeTarget = RangeTarget.new()
		t.name = "Target_L%d_%dm" % [lane, roundi(d)]
		t.setup(dummy, difficulty, tweak, lane, d)
		t.position = Vector3(layout.lane_x(lane), 0.0, -d)
		root.add_child(t)
		var s: Label3D = sign_label(UiText.t(&"ui.range.marker", {"m": roundi(d)}), tweak)
		s.font_size = tweak.hp_font_size
		s.position = t.position + Vector3(0.0, layout.target_sign_height_m, 0.0)
		root.add_child(s)
		out.append(t)
	return out


## B4-13: the extra lanes (layout.extra_lanes), lane index continuing after the static lanes.
## Moving lanes put the target on a RangeTrack carriage over a floor rail; armory lanes stand still.
## Each gets a distance sign and its dummy name; every area gets one title sign.
static func build_extra_lanes(layout: RangeLayout, table: RangeDummyTable, difficulty: int, tweak: RangeTweak,
		parent: Node3D) -> Array[RangeTarget]:
	var out: Array[RangeTarget] = []
	var root: Node3D = _group_node(parent, "ExtraLanes")
	var rail_mat: StandardMaterial3D = _flat_mat(tweak.rail_color)
	var areas: Dictionary = {}   # area -> [min x, max x, min distance]
	var lane: int = layout.lane_count()
	for def: RangeLaneDef in layout.extra_lanes:
		var dummy: RangeDummyDef = table.dummy(def.dummy)
		var t: RangeTarget = RangeTarget.new()
		t.name = "Target_L%d_%s_%dm" % [lane, String(def.area), roundi(def.distance_m)]
		t.setup(dummy, difficulty, tweak, lane, def.distance_m)
		var base: Vector3 = Vector3(def.x_m, 0.0, -def.distance_m)
		if def.is_moving():
			var track: RangeTrack = RangeTrack.new()
			track.name = "Track_L%d" % lane
			track.position = base
			track.setup(def.speed_mps, def.track_half_m, def.phase_s)
			root.add_child(track)
			var rail_len: float = def.track_half_m * 2.0 + layout.track_rail_margin_m
			track.add_child(_strip(Vector3(rail_len, 0.02, layout.track_rail_depth_m), Vector3(0.0, 0.01, 0.0), rail_mat))
			track.carriage.add_child(t)
		else:
			t.position = base
			root.add_child(t)
		var s: Label3D = sign_label(UiText.t(&"ui.range.marker", {"m": roundi(def.distance_m)}), tweak)
		s.font_size = tweak.hp_font_size
		s.position = base + Vector3(0.0, layout.target_sign_height_m, 0.0)
		fade_far(s)
		root.add_child(s)
		if dummy != null:
			var n: Label3D = sign_label(UiText.t(dummy.name_key), tweak)
			n.font_size = tweak.dummy_sign_font_size
			fade_far(n)
			n.position = base + Vector3(0.0, layout.dummy_sign_height_m, 0.0)
			if def.is_moving():
				n.text = UiText.t(&"ui.range.moving_sign", {"name": n.text, "speed": snappedf(def.speed_mps, 0.1)})
			root.add_child(n)
		var a: Array = areas.get(def.area, [def.x_m, def.x_m, def.distance_m])
		areas[def.area] = [minf(a[0], def.x_m - def.track_half_m), maxf(a[1], def.x_m + def.track_half_m), minf(a[2], def.distance_m)]
		out.append(t)
		lane += 1
	for area: StringName in areas:
		var a: Array = areas[area]
		var title: Label3D = sign_label(UiText.t(StringName("ui.range.area.%s" % String(area))), tweak)
		title.position = Vector3((float(a[0]) + float(a[1])) * 0.5, layout.area_sign_height_m, -float(a[2]) + 2.0)
		root.add_child(title)
	return out


## Fades `l` out between LABEL_FADE_M and LABEL_FADE_M + 5 m (GPU visibility range, no script per frame).
static func fade_far(l: Label3D) -> void:
	l.visibility_range_end = LABEL_FADE_M + 5.0
	l.visibility_range_end_margin = 5.0
	l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func sign_label(text: String, tweak: RangeTweak) -> Label3D:
	var s: Label3D = Label3D.new()
	s.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	s.text = text
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.font_size = tweak.sign_font_size
	s.pixel_size = tweak.sign_pixel_size
	s.modulate = tweak.sign_color
	s.outline_size = 16
	return s


static func _build_lane_lines(layout: RangeLayout, tweak: RangeTweak, root: Node3D) -> void:
	var mat: StandardMaterial3D = _flat_mat(tweak.lane_line_color)
	var n: int = layout.lane_count()
	var len_m: float = -layout.far_z_m
	# ENV C (range dressing): one 100 m+ strip is lit by at most 8 lights in Compatibility, so it lit unevenly
	# under the per-lane strip lights; LANE_SEGMENT_M pieces each take their nearest lights.
	var segs: int = maxi(ceili(len_m / LANE_SEGMENT_M), 1)
	var seg_len: float = len_m / float(segs)
	for i: int in range(n + 1):
		var x: float = layout.lane_x(0) - layout.lane_width_m * 0.5 + float(i) * layout.lane_width_m
		for k: int in range(segs):
			var zc: float = -seg_len * (float(k) + 0.5)
			root.add_child(_strip(Vector3(layout.lane_line_width_m, 0.01, seg_len), Vector3(x, 0.005, zc), mat))


static func _build_bench(layout: RangeLayout, tweak: RangeTweak, parent: Node3D) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tweak.bench_color
	mat.roughness = 0.7
	var size: Vector3 = Vector3(layout.lane_width_m * float(layout.lane_count()), layout.bench_height_m, layout.bench_depth_m)
	var bench: MeshInstance3D = _strip(size, Vector3(0.0, size.y * 0.5, layout.bench_z_m), mat)
	bench.name = "Bench"
	parent.add_child(bench)


static func _place(piece: PackedScene, parent: Node3D, pos: Vector3, yaw_deg: float) -> bool:
	if piece == null:
		Log.error(&"range", "range layout is missing a greybox piece")
		return false
	var n: Node3D = piece.instantiate() as Node3D
	if n == null:
		return false
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(n)
	return true


static func _group_node(parent: Node3D, node_name: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = node_name
	parent.add_child(n)
	return n


static func _flat_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


static func _strip(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
