## Ostrander Federal burn-through set piece and the drill-drop vehicles (OF-C2 lane C, ENV C). Presentation only, built
## HIDDEN under Props/DressC; ENV A's mission (OF-A6) plays them. Nothing here has a collider, a nav obstruction or a
## gameplay role: the lid (the replicated prefab `Gameplay/Devices/Lid`, children Plug and Visual/LidPanel, which the
## mission set_enabled(false)s at the burn), the hole's permanent nav carve, the Hoist and the RopeLadder belong to the
## G1 contract / other lanes and are not touched. Nothing is ever put under Gameplay/Devices/Lid.
##
## Hooks (docs/levels/ostrander_federal/g2/c/burn_hooks.md):
##   Props/DressC/BurnThrough            Node3D, hidden. The scorched hole edge + cut faces (HoleEdge, with the ember
##                                       glow EmberGlow and the ScorchTW / ScorchVT decals), the fallen lid's plate and
##                                       rubble on the vault floor (Debris), the dust (DustBurst under the hole, DustPuff
##                                       over it in TW, DustHaze lingering).
##     BurnAnim (AnimationPlayer)        play(&"burn") on device_finished (the drill burns through): shows the root,
##                                       drops the debris (0.8 s), bursts the dust, cools the glow over 20 s, the haze
##                                       settles by 60 s. play(&"burnt") = the end state at once (late join / restore).
##   Props/DressC/DrillDropHeli          Node3D, hidden. Mercer's bird over the terrace drop (20, 8.6, 33).
##     DropAnim                          play(&"drop") when the drop_terrace delivery is called: flies in from the
##                                       south, hovers 6 s over the crate spot (the crate is A's spawned loot), leaves
##                                       north-east and hides itself (20 s).
##   Props/DressC/DrillDropVan           Node3D, hidden. Mercer's second van in Ledger Lane at the dock (14, 0, -4).
##     DropAnim                          play(&"arrive") for drop_dock: reverses in along the lane and parks with its
##                                       rear doors at the drop marker (6 s); play(&"parked") = parked at once.
## Every root carries meta `lc_ignore` (FX / cosmetic vehicles: no prop extent, floating or clipping checks; the heli
## hovers by design) and meta `fx_hook` naming its animation.
extends RefCounted

const FOLDER: String = "DressC"
const MAT_DIR: String = "res://world/materials/"
## The hole through SlabG (layout SLABS, the lid prefab's Plug): x 23.4-24.6, z 13.5-15.7, y -0.8..0.
const HOLE: Rect2 = Rect2(23.4, 13.5, 1.2, 2.2)
const SLAB_TOP: float = 0.0
const SLAB_BOTTOM: float = -0.8
const VAULT_FLOOR: float = -4.0
## The scorch ring on the TW floor (over the LidPanel's 2.4 x 2.4 m border) and under the vault ceiling.
const SCORCH_OUT: float = 0.6
## The projected scorch's reach past the cut on each side (m).
const SCORCH_DECAL_OUT: float = 0.9
const HELI_HOVER: Vector3 = Vector3(20.0, 22.0, 33.0)
const VAN_PARK: Vector3 = Vector3(14.0, 0.0, -6.75)

var report: PackedStringArray = []
var _root: Node3D
var _b: Object


func build(builder: Object, root: Node3D) -> void:
	_b = builder
	_root = root
	var parent: Node3D = root.get_node_or_null("Props/" + FOLDER) as Node3D
	if parent == null:
		report.append("ERROR burn: no Props/%s" % FOLDER)
		return
	_burn_through(parent)
	_drop_heli(parent)
	_drop_van(parent)
	report.append("burn: BurnThrough (burn / burnt), DrillDropHeli (drop), DrillDropVan (arrive / parked), all hidden")


func _own(parent: Node, n: Node) -> Node:
	parent.add_child(n)
	n.owner = _root
	return n


func _hook_root(parent: Node3D, nm: String, pos: Vector3, hook: String) -> Node3D:
	var r: Node3D = Node3D.new()
	r.name = nm
	r.position = pos
	r.visible = false
	r.set_meta(&"lc_ignore", true)
	r.set_meta(&"fx_hook", hook)
	_own(parent, r)
	return r


# --- Burn-through --------------------------------------------------------------------------------

func _burn_through(parent: Node3D) -> void:
	var root: Node3D = _hook_root(parent, "BurnThrough", Vector3.ZERO,
		"BurnAnim.play(&\"burn\") at the burn-through; play(&\"burnt\") for the end state")
	var edge: MeshInstance3D = MeshInstance3D.new()
	edge.name = "HoleEdge"
	edge.mesh = _hole_mesh()
	edge.set_meta(&"fixture", true)  # the molten rim is the ember glow's fixture
	edge.add_to_group(&"fixture")
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(root, edge)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "EmberGlow"
	glow.position = Vector3(HOLE.get_center().x, -0.4, HOLE.get_center().y)
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 0.0
	glow.omni_range = 4.5
	glow.shadow_enabled = false
	glow.layers = 1 | (1 << 20)
	_own(edge, glow)
	_own(edge, _scorch_decal("ScorchTW", SLAB_TOP, false))
	_own(edge, _scorch_decal("ScorchVT", SLAB_BOTTOM, true))
	var debris: Node3D = Node3D.new()
	debris.name = "Debris"
	_own(root, debris)
	var pieces: Array[Array] = _debris_pieces()
	for p: Array in pieces:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = String(p[0])
		var bm: BoxMesh = BoxMesh.new()
		bm.size = p[1]
		bm.material = load(MAT_DIR + String(p[4]) + ".tres") as Material
		mi.mesh = bm
		mi.transform = p[2]
		_own(debris, mi)
	_own(root, _dust("DustBurst", Vector3(HOLE.get_center().x, -1.2, HOLE.get_center().y), 160, 2.6, true,
		Vector3(0.0, -1.0, 0.0), 1.6, Color(0.62, 0.6, 0.56, 0.55)))
	_own(root, _dust("DustPuff", Vector3(HOLE.get_center().x, 0.3, HOLE.get_center().y), 90, 2.2, true,
		Vector3(0.0, 1.0, 0.0), 1.2, Color(0.66, 0.63, 0.58, 0.5)))
	_own(root, _dust("DustHaze", Vector3(HOLE.get_center().x, -2.6, HOLE.get_center().y + 1.0), 24, 9.0, false,
		Vector3(0.0, 0.1, 0.0), 0.15, Color(0.7, 0.68, 0.64, 0.18)))
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "BurnAnim"
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation(&"burn", _burn_anim(pieces, false))
	lib.add_animation(&"burnt", _burn_anim(pieces, true))
	ap.add_animation_library(&"", lib)
	_own(root, ap)


## The fallen lid on the vault floor: the marble top plate cracked in two and concrete rubble, kept off the rope
## ladder's foot (24, 13.6) and the hoist's car (24, 15.2) so neither reads as blocked: [name, size, rest transform,
## fall start transform (in the hole), material].
func _debris_pieces() -> Array[Array]:
	var out: Array[Array] = []
	var c: Vector3 = Vector3(HOLE.get_center().x, 0.0, HOLE.get_center().y)
	var fy: float = VAULT_FLOOR
	out.append(["PlateW", Vector3(0.62, 0.06, 1.1), Transform3D(Basis.from_euler(Vector3(0.05, deg_to_rad(18.0),
		deg_to_rad(-6.0))), Vector3(22.55, fy + 0.07, 14.35)), Transform3D(Basis.IDENTITY, c + Vector3(-0.3, -0.05,
		-0.55)), "marble_cream"])
	out.append(["PlateE", Vector3(0.6, 0.06, 1.05), Transform3D(Basis.from_euler(Vector3(-0.04, deg_to_rad(-24.0),
		deg_to_rad(5.0))), Vector3(25.45, fy + 0.06, 14.9)), Transform3D(Basis.IDENTITY, c + Vector3(0.3, -0.05, 0.55)),
		"marble_cream"])
	var rocks: Array = [
		[Vector3(0.24, 0.12, 0.2), Vector3(22.75, fy, 15.45), 31.0], [Vector3(0.18, 0.1, 0.22), Vector3(25.2, fy, 13.75), 64.0],
		[Vector3(0.3, 0.14, 0.18), Vector3(25.7, fy, 15.85), 12.0], [Vector3(0.14, 0.08, 0.12), Vector3(22.4, fy, 13.5), 80.0],
		[Vector3(0.2, 0.1, 0.16), Vector3(23.05, fy, 16.3), 45.0], [Vector3(0.16, 0.09, 0.2), Vector3(24.95, fy, 16.35), 22.0],
		[Vector3(0.12, 0.07, 0.1), Vector3(25.9, fy, 14.3), 70.0], [Vector3(0.22, 0.11, 0.14), Vector3(22.25, fy, 14.95), 5.0],
	]
	for i: int in range(rocks.size()):
		var r: Array = rocks[i]
		var sz: Vector3 = r[0]
		var rest: Vector3 = r[1] + Vector3(0.0, sz.y * 0.5, 0.0)
		var start: Vector3 = c + Vector3((float(i % 3) - 1.0) * 0.35, -0.2, (float(i % 4) - 1.5) * 0.45)
		out.append(["Rubble%d" % (i + 1), sz, Transform3D(Basis(Vector3.UP, deg_to_rad(float(r[2]))), rest),
			Transform3D(Basis.IDENTITY, start), "concrete"])
	return out


## The scorched hole: a ring on the TW floor (y +0.008, over the lid border), the slab's four cut faces (charred,
## the molten rim glowing at the top and bottom edges) and a ring under the vault ceiling (y -0.802). One ArrayMesh,
## two surfaces (char, ember rim).
func _hole_mesh() -> ArrayMesh:
	var am: ArrayMesh = ArrayMesh.new()
	var ch: StandardMaterial3D = StandardMaterial3D.new()
	ch.resource_name = "of_burn_char"
	ch.albedo_color = Color.WHITE
	ch.roughness = 1.0
	ch.vertex_color_use_as_albedo = true
	ch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ch.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rim: StandardMaterial3D = StandardMaterial3D.new()
	rim.resource_name = "of_burn_ember"
	rim.albedo_color = Color(0.2, 0.08, 0.03)
	rim.emission_enabled = true
	rim.emission = Color(1.0, 0.38, 0.1)
	rim.emission_energy_multiplier = 2.5
	rim.roughness = 0.6
	rim.cull_mode = BaseMaterial3D.CULL_DISABLED
	var x0: float = HOLE.position.x
	var z0: float = HOLE.position.y
	var x1: float = HOLE.end.x
	var z1: float = HOLE.end.y
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring(st, x0, z0, x1, z1, SCORCH_OUT, SLAB_TOP + 0.008, Vector3.UP)
	_ring(st, x0, z0, x1, z1, SCORCH_OUT, SLAB_BOTTOM - 0.002, Vector3.DOWN)
	var yb: float = SLAB_BOTTOM + 0.04
	var yt: float = SLAB_TOP - 0.04
	var e: float = 0.004  # 4 mm proud of the cut (no z-fight with the slab's hole faces, if any)
	_quad(st, Vector3(x0 + e, yb, z0), Vector3(x0 + e, yb, z1), Vector3(x0 + e, yt, z1), Vector3(x0 + e, yt, z0),
		Vector3.RIGHT, Color(0.06, 0.055, 0.05, 1.0))
	_quad(st, Vector3(x1 - e, yb, z1), Vector3(x1 - e, yb, z0), Vector3(x1 - e, yt, z0), Vector3(x1 - e, yt, z1),
		Vector3.LEFT, Color(0.06, 0.055, 0.05, 1.0))
	_quad(st, Vector3(x1, yb, z0 + e), Vector3(x0, yb, z0 + e), Vector3(x0, yt, z0 + e), Vector3(x1, yt, z0 + e),
		Vector3.BACK, Color(0.06, 0.055, 0.05, 1.0))
	_quad(st, Vector3(x0, yb, z1 - e), Vector3(x1, yb, z1 - e), Vector3(x1, yt, z1 - e), Vector3(x0, yt, z1 - e),
		Vector3.FORWARD, Color(0.06, 0.055, 0.05, 1.0))
	st.set_material(ch)
	st.commit(am)
	var st2: SurfaceTool = SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: Array in [[SLAB_TOP - 0.04, SLAB_TOP + 0.002], [SLAB_BOTTOM - 0.002, SLAB_BOTTOM + 0.04]]:
		var a: float = float(band[0])
		var b: float = float(band[1])
		var w: Color = Color.WHITE
		_quad(st2, Vector3(x0 + e, a, z0), Vector3(x0 + e, a, z1), Vector3(x0 + e, b, z1), Vector3(x0 + e, b, z0), Vector3.RIGHT, w)
		_quad(st2, Vector3(x1 - e, a, z1), Vector3(x1 - e, a, z0), Vector3(x1 - e, b, z0), Vector3(x1 - e, b, z1), Vector3.LEFT, w)
		_quad(st2, Vector3(x1, a, z0 + e), Vector3(x0, a, z0 + e), Vector3(x0, b, z0 + e), Vector3(x1, b, z0 + e), Vector3.BACK, w)
		_quad(st2, Vector3(x0, a, z1 - e), Vector3(x1, a, z1 - e), Vector3(x1, b, z1 - e), Vector3(x0, b, z1 - e), Vector3.FORWARD, w)
	st2.set_material(rim)
	st2.commit(am)
	return am


## GPU-6 review (r253): the flat rings sit mm off the TW carpet / the VT soffit and lose the depth test at camera
## distance, so the burn read as an ember rim only. A projected scorch (procedural square-falloff gradient, no texture
## asset) over the floor around the hole (`up` = false, projecting down) or the soffit (`up`, projecting up): charcoal
## at the cut, fading out SCORCH_DECAL_OUT past it. Forward+ draws decals (Compatibility skips them).
func _scorch_decal(nm: String, y: float, up: bool) -> Decal:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
	g.colors = PackedColorArray([Color(0.03, 0.025, 0.02, 0.95), Color(0.03, 0.025, 0.02, 0.92),
		Color(0.08, 0.07, 0.06, 0.55), Color(0.12, 0.11, 0.1, 0.0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_SQUARE
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var d: Decal = Decal.new()
	d.name = nm
	d.texture_albedo = tex
	d.size = Vector3(HOLE.size.x + 2.0 * SCORCH_DECAL_OUT, 0.3, HOLE.size.y + 2.0 * SCORCH_DECAL_OUT)
	d.position = Vector3(HOLE.get_center().x, y, HOLE.get_center().y)
	if up:
		d.rotation = Vector3(PI, 0.0, 0.0)   # project upward onto the soffit
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.cull_mask = 1
	return d


## A flat scorch ring of width `w` around the hole at height `y`: charred black at the hole, fading out by vertex alpha.
func _ring(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float, w: float, y: float, nrm: Vector3) -> void:
	var inner: Array[Vector3] = [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	var outer: Array[Vector3] = [Vector3(x0 - w, y, z0 - w), Vector3(x1 + w, y, z0 - w), Vector3(x1 + w, y, z1 + w),
		Vector3(x0 - w, y, z1 + w)]
	var cin: Color = Color(0.05, 0.045, 0.04, 0.95)
	var cout: Color = Color(0.12, 0.11, 0.1, 0.0)
	for i: int in range(4):
		var j: int = (i + 1) % 4
		if nrm.y > 0.0:
			_quad_c(st, inner[i], inner[j], outer[j], outer[i], nrm, [cin, cin, cout, cout])
		else:
			_quad_c(st, inner[j], inner[i], outer[i], outer[j], nrm, [cin, cin, cout, cout])


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, col: Color) -> void:
	_quad_c(st, a, b, c, d, nrm, [col, col, col, col])


## Two triangles a-c-b, a-d-c (both materials draw double-sided, so the winding does not matter).
func _quad_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, cols: Array) -> void:
	var v: Array[Vector3] = [a, b, c, d]
	for idx: int in [0, 2, 1, 0, 3, 2]:
		st.set_normal(nrm)
		st.set_color(cols[idx])
		st.set_uv(Vector2(float(idx % 2), float(idx / 2)))
		st.add_vertex(v[idx])


## A soft dust emitter (procedural: a radial-gradient billboard, no texture asset). One-shot bursts or a slow haze.
func _dust(nm: String, pos: Vector3, amount: int, life: float, one_shot: bool, dir: Vector3, speed: float,
		col: Color) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = nm
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.85 if one_shot else 0.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(HOLE.size.x * 0.5, 0.1, HOLE.size.y * 0.5) if one_shot else Vector3(4.0, 0.8, 4.0)
	pm.direction = dir
	pm.spread = 55.0 if one_shot else 180.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0.0, -0.6 if one_shot else 0.02, 0.0)
	pm.damping_min = 1.2
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(col.r, col.g, col.b, 0.0))
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	ramp.add_point(0.15, col)
	ramp.add_point(0.6, Color(col.r, col.g, col.b, col.a * 0.5))
	var rt: GradientTexture1D = GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 1.0))
	var sct: CurveTexture = CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.9, 0.9) if one_shot else Vector2(2.4, 2.4)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = "of_burn_dust"
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var soft: Gradient = Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = soft
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	mat.albedo_texture = tex
	quad.material = mat
	p.draw_pass_1 = quad
	return p


## burn: 0 s show; 0-0.8 s the debris falls from the hole to the floor (ease-in, a 6 cm settle bounce at 0.9 s); the
## burst at 0.75 s, the TW puff at 0 s, the haze from 0.8 s to 60 s; the ember glow 3.0 -> 0.5 over 20 s.
## burnt: the end state in one key (debris at rest, glow 0.5, no dust).
func _burn_anim(pieces: Array[Array], end_state: bool) -> Animation:
	var a: Animation = Animation.new()
	a.length = 0.1 if end_state else 60.0
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:visible"))
	a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	a.track_insert_key(t, 0.0, true)
	var g: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(g, NodePath("HoleEdge/EmberGlow:light_energy"))
	if end_state:
		a.track_insert_key(g, 0.0, 0.5)
	else:
		a.track_insert_key(g, 0.0, 3.0)
		a.track_insert_key(g, 20.0, 0.5)
	for p: Array in pieces:
		var pt: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(pt, NodePath("Debris/%s:transform" % String(p[0])))
		var rest: Transform3D = p[2]
		if end_state:
			a.track_insert_key(pt, 0.0, rest)
			continue
		var start: Transform3D = p[3]
		a.track_insert_key(pt, 0.0, start, 2.0)  # ease-in: the fall accelerates
		var low: Transform3D = rest
		low.origin.y += 0.06
		a.track_insert_key(pt, 0.8, rest)
		a.track_insert_key(pt, 0.9, low)
		a.track_insert_key(pt, 1.0, rest)
	for d: Array in [["DustPuff", 0.0], ["DustBurst", 0.75], ["DustHaze", 0.8]]:
		var dt: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(dt, NodePath("%s:emitting" % String(d[0])))
		a.value_track_set_update_mode(dt, Animation.UPDATE_DISCRETE)
		if end_state:
			a.track_insert_key(dt, 0.0, false)
		else:
			a.track_insert_key(dt, float(d[1]), true)
			if String(d[0]) == "DustHaze":
				a.track_insert_key(dt, 59.0, false)
	return a


# --- The drill-drop vehicles ---------------------------------------------------------------------

func _vehicle(parent: Node3D, asset: String, nm: String) -> Node3D:
	var ps: PackedScene = _b.call(&"catalog_scene", asset) as PackedScene
	if ps == null:
		report.append("ERROR burn: no scene for %s" % asset)
		return null
	var v: Node3D = ps.instantiate() as Node3D
	v.name = nm
	_own(parent, v)
	return v


## Mercer's bird (veh_heli_escape) over the terrace drop: in from the south at 40 m, a 6 s hover 13 m over the crate
## spot, out to the north-east; the main / tail rotors spin (Model/Rotor, Model/TailRotor).
func _drop_heli(parent: Node3D) -> void:
	var root: Node3D = _hook_root(parent, "DrillDropHeli", Vector3.ZERO,
		"DropAnim.play(&\"drop\") when the drop_terrace delivery is called (the drill crate lands at 20, 8.6, 33)")
	var heli: Node3D = _vehicle(root, "veh_heli_escape", "Heli")
	if heli == null:
		return
	var start: Vector3 = HELI_HOVER + Vector3(0.0, 18.0, 70.0)
	var leave: Vector3 = HELI_HOVER + Vector3(60.0, 22.0, -70.0)
	heli.transform = Transform3D(Basis(Vector3.UP, 0.0), start)
	var a: Animation = Animation.new()
	a.length = 20.0
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:visible"))
	a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	a.track_insert_key(t, 0.0, true)
	a.track_insert_key(t, 20.0, false)
	var face_n: Basis = Basis(Vector3.UP, 0.0)  # nose -Z: north
	var tilt_in: Basis = face_n * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
	var face_ne: Basis = Basis(Vector3.UP, deg_to_rad(-40.0)) * Basis(Vector3.RIGHT, deg_to_rad(-10.0))
	var p: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(p, NodePath("Heli:transform"))
	a.track_insert_key(p, 0.0, Transform3D(tilt_in, start), 0.6)
	a.track_insert_key(p, 6.0, Transform3D(face_n, HELI_HOVER))
	a.track_insert_key(p, 12.0, Transform3D(face_n, HELI_HOVER + Vector3(0.0, 0.4, 0.0)), 2.0)
	a.track_insert_key(p, 20.0, Transform3D(face_ne, leave))
	for rp: Array in [["Heli/Model/Rotor", Vector3.UP], ["Heli/Model/TailRotor", Vector3.RIGHT]]:
		var rt: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(rt, NodePath("%s:rotation" % String(rp[0])))
		var ax: Vector3 = rp[1]
		for k: int in range(81):
			a.track_insert_key(rt, k * 0.25, ax * (float(k % 4) * PI * 0.5))
	_player(root, "DropAnim", {&"drop": a})


## Mercer's second van (veh_van_secure) reversing into Ledger Lane: from the lane's east end to its parking spot by
## the dock, rear doors at the drop marker (14, 0, -4); clear of the E1 secure zone (x 3-7) and the lane spawn.
func _drop_van(parent: Node3D) -> void:
	var root: Node3D = _hook_root(parent, "DrillDropVan", Vector3.ZERO,
		"DropAnim.play(&\"arrive\") for the drop_dock delivery; play(&\"parked\") for the end state")
	var van: Node3D = _vehicle(root, "veh_van_secure", "Van")
	if van == null:
		return
	var park: Transform3D = Transform3D(Basis(Vector3.UP, 0.0), VAN_PARK)  # nose -Z (north), rear to the dock
	var swing: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(22.0, 0.0, -6.0))
	var enter: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(44.0, 0.0, -6.0))
	van.transform = park
	var arrive: Animation = Animation.new()
	arrive.length = 6.0
	var t: int = arrive.add_track(Animation.TYPE_VALUE)
	arrive.track_set_path(t, NodePath(".:visible"))
	arrive.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	arrive.track_insert_key(t, 0.0, true)
	var p: int = arrive.add_track(Animation.TYPE_VALUE)
	arrive.track_set_path(p, NodePath("Van:transform"))
	arrive.track_insert_key(p, 0.0, enter)
	arrive.track_insert_key(p, 3.5, swing, 0.8)
	arrive.track_insert_key(p, 6.0, park)
	var parked: Animation = Animation.new()
	parked.length = 0.1
	var t2: int = parked.add_track(Animation.TYPE_VALUE)
	parked.track_set_path(t2, NodePath(".:visible"))
	parked.value_track_set_update_mode(t2, Animation.UPDATE_DISCRETE)
	parked.track_insert_key(t2, 0.0, true)
	var p2: int = parked.add_track(Animation.TYPE_VALUE)
	parked.track_set_path(p2, NodePath("Van:transform"))
	parked.track_insert_key(p2, 0.0, park)
	_player(root, "DropAnim", {&"arrive": arrive, &"parked": parked})


func _player(root: Node3D, nm: String, anims: Dictionary) -> void:
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = nm
	var lib: AnimationLibrary = AnimationLibrary.new()
	for k: StringName in anims:
		lib.add_animation(k, anims[k])
	ap.add_animation_library(&"", lib)
	_own(root, ap)
