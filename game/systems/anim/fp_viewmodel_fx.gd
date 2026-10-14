## D-105 / impact_fx.md 1.0 §4 (ENV P): first-person weapon effects of the local human. A child of FpViewmodel
## (under the world camera, so CrewView puts its meshes on the viewmodel layer):
##   flash(muzzle, suppressed)   muzzle burst (crossed additive quads, random roll/scale) + smoke puff
##   eject(port, kind, delay)    a casing out of the ejection port (pooled, ballistic, presentation only)
##   EventBus.shot_fx            for this peer's FP shots (flags bit1, shooter = our crew) a tracer streak from the
##                               muzzle as SEEN through the viewmodel camera to `end`, on the world layer
## ENV C's library (game/world/vfx/, impact_fx.md §3) replaces the placeholders scene by scene: when
## FpViewmodelTweak.vfx_*_scene exists it is instanced instead of the built-in mesh (same call sites).
## Presentation only; reads gameplay state, never writes it. Randomness: GameRng.stream(&"fp_fx").
class_name FpViewmodelFx
extends Node3D

const FLAG_SUPPRESSED: int = 1
const FLAG_FIRST_PERSON: int = 2
const SHELL_POOL: int = 12
const TRACER_POOL: int = 8

## Tests / capture: effects started since setup.
var flashes: int = 0
var shells_ejected: int = 0
var tracers_drawn: int = 0

var _vm: FpViewmodel = null
var _flash: Node3D = null
var _flash_left: float = 0.0
## Process frame the burst was shown on: it stays up through that frame's draw even on a slow frame.
var _flash_frame: int = 0
## The burst is ENV C's MuzzleFlash scene (flash/tick API) rather than the placeholder.
var _custom_flash: bool = false
## ENV C's TracerFx (one per world) when its scene exists.
var _c_tracer: Node3D = null
var _smoke: CPUParticles3D = null
var _shells: Array[Dictionary] = []
var _tracers: Array[Dictionary] = []
var _tracer_count: int = 0
var _pending: Array[Dictionary] = []


func setup(vm: FpViewmodel) -> void:
	_vm = vm
	name = "FpWeaponFx"


func _ready() -> void:
	if not EventBus.shot_fx.is_connected(_on_shot_fx):
		EventBus.shot_fx.connect(_on_shot_fx)


func _exit_tree() -> void:
	if EventBus.shot_fx.is_connected(_on_shot_fx):
		EventBus.shot_fx.disconnect(_on_shot_fx)
	for t: Dictionary in _tracers:
		var n: Variant = t["node"]  # untyped: a world-parented tracer may be freed already (between heists)
		if is_instance_valid(n):
			(n as Node).queue_free()
	_tracers.clear()


func _process(delta: float) -> void:
	tick(delta)


## Advance one presentation frame (tests may call it directly).
func tick(delta: float) -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if _flash != null and not is_instance_valid(_flash):
		_flash = null  # freed with its old parent (heist teardown): re-acquired on the next flash()
	if _custom_flash and _flash != null:
		if Engine.get_process_frames() > _flash_frame:  # drawn at least once before C's 0.05 s timer runs
			_flash.call(&"tick", delta)
	elif _flash != null and _flash.visible:
		_flash_left -= delta
		if _flash_left <= 0.0 and Engine.get_process_frames() > _flash_frame:  # drawn at least once
			_flash.visible = false
	for k: int in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[k]
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			_pending.remove_at(k)
			var port: Node3D = _live(p["port"])
			if port != null and port.is_inside_tree():
				_spawn_shell(port, StringName(p["kind"]), tw)
	_tick_shells(delta, tw)
	_tick_tracers(delta, tw)


# --- Muzzle --------------------------------------------------------------------------------------------

func flash(muzzle: Node3D, suppressed: bool, size_mult: float = 1.0) -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if muzzle == null or not muzzle.is_inside_tree():
		return
	var rng: RandomNumberGenerator = GameRng.stream(&"fp_fx")
	flashes += 1
	if not suppressed and tw.muzzle_flash_s > 0.0:
		if _flash == null or not is_instance_valid(_flash):
			_flash = _make_flash(tw)
			add_child(_flash)
		_flash.global_transform = _muzzle_frame(muzzle)
		_flash.rotate_object_local(Vector3.FORWARD, rng.randf_range(0.0, TAU))
		_flash.scale = Vector3.ONE * tw.muzzle_flash_size_m * size_mult * rng.randf_range(0.8, 1.2)
		_flash.visible = true
		_flash_left = tw.muzzle_flash_s
		_flash_frame = Engine.get_process_frames()
		if _custom_flash:
			_flash.call(&"flash", tw.vfx_muzzle_size, false)
			_hide_library_smoke()
	if tw.muzzle_smoke_amount > 0:
		if _smoke == null or not is_instance_valid(_smoke):
			_smoke = _make_smoke(tw)
			add_child(_smoke)
		_smoke.global_position = muzzle.global_position
		_smoke.amount = maxi(1, int(tw.muzzle_smoke_amount * (tw.muzzle_smoke_suppressed_mult if suppressed else 1.0)))
		_smoke.restart()
		_smoke.emitting = true


## ENV C's flash carries a world-space smoke emitter whose particle size ignores the root scale (metres at the
## viewmodel's ~0.5 m depth fill the screen); the FP smoke is ours (sized for the viewmodel), so C's stays hidden.
func _hide_library_smoke() -> void:
	var sm: Node3D = _flash.get_node_or_null(^"Smoke") as Node3D
	if sm != null:
		sm.visible = false


## The flash faces down the barrel: -Z along the camera forward (the Muzzle marker's own axes vary per model).
func _muzzle_frame(muzzle: Node3D) -> Transform3D:
	var cam: Node3D = get_parent_node_3d().get_parent_node_3d() if get_parent_node_3d() != null else null
	var b: Basis = cam.global_basis.orthonormalized() if cam != null else Basis.IDENTITY
	return Transform3D(b, muzzle.global_position)


func _make_flash(tw: FpViewmodelTweak) -> Node3D:
	var custom: Node3D = _instance(tw.vfx_muzzle_scene_path)
	if custom != null and custom.has_method(&"flash") and custom.has_method(&"tick"):
		custom.set(&"auto_tick", false)  # ticked from here so the burst survives one drawn frame
		custom.ready.connect(_alpha_blend.bind(custom), CONNECT_ONE_SHOT)
		_custom_flash = true
		return custom
	if custom != null:
		custom.free()
	var root: Node3D = Node3D.new()
	root.name = "MuzzleFlash"
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# MIX, not ADD: the viewmodel draws into a transparent SubViewport, and additive leaves its alpha at 0, so an
	# additive burst vanishes when the layer is composited over the world.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = tw.muzzle_flash_color
	mat.albedo_texture = _radial_texture()
	mat.no_depth_test = false
	# Three petals along the barrel (side view) and one disc facing the camera (end view).
	for k: int in 3:
		var petal: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.5, 1.6)
		petal.mesh = q
		petal.material_override = mat
		petal.rotation = Vector3(-PI * 0.5, 0.0, 0.0)  # quad +Y along -Z (down the barrel)
		petal.rotate_object_local(Vector3.UP, float(k) * PI / 3.0)
		petal.position = Vector3(0.0, 0.0, -0.75)
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(petal)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var dq: QuadMesh = QuadMesh.new()
	dq.size = Vector2(1.0, 1.0)
	disc.mesh = dq
	disc.material_override = mat
	disc.position = Vector3(0.0, 0.0, -0.35)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var core_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
	core_mat.albedo_color = tw.muzzle_flash_core_color
	var core: MeshInstance3D = MeshInstance3D.new()
	var cq: QuadMesh = QuadMesh.new()
	cq.size = Vector2(0.45, 0.45)
	core.mesh = cq
	core.material_override = core_mat
	core.position = Vector3(0.0, 0.0, -0.3)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	root.visible = false
	return root


func _make_smoke(tw: FpViewmodelTweak) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "MuzzleSmoke"
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.lifetime = tw.muzzle_smoke_life_s
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.gravity = Vector3(0.0, 0.15, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.75, 0.75, 0.72, 0.35))
	grad.set_color(1, Color(0.7, 0.7, 0.68, 0.0))
	p.color_ramp = grad
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _radial_texture()
	q.material = mat
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _radial_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.9))
	g.add_point(0.6, Color(1, 1, 1, 0.25))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


# --- Shells --------------------------------------------------------------------------------------------

## Queue a casing out of `port` after `delay` s (pump / bolt / lever eject on the cycle, not the shot).
func eject(port: Node3D, kind: StringName, delay: float = 0.0) -> void:
	if port == null or kind == &"":
		return
	_pending.append({"port": port, "kind": kind, "t": maxf(delay, 0.0)})
	if delay <= 0.0:
		tick(0.0)


func _spawn_shell(port: Node3D, kind: StringName, tw: FpViewmodelTweak) -> void:
	var rng: RandomNumberGenerator = GameRng.stream(&"fp_fx")
	var s: Dictionary = {}
	if _shells.size() >= SHELL_POOL:
		s = _shells.pop_front()
	if s.is_empty() or _live(s["node"]) == null:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Shell"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		s = {"node": mi}
	var node: MeshInstance3D = s["node"]
	_apply_shell_look(node, kind, tw)
	node.visible = true
	var cam: Node3D = get_parent_node_3d().get_parent_node_3d() if get_parent_node_3d() != null else null
	var b: Basis = cam.global_basis.orthonormalized() if cam != null else Basis.IDENTITY
	# Camera space: out to the right, up, a little back, with spin; then world space (shells fall in world gravity).
	var v_local: Vector3 = Vector3(rng.randf_range(1.1, 1.6), rng.randf_range(0.7, 1.1), rng.randf_range(0.0, 0.3)) \
		* tw.shell_speed_mult
	s["pos"] = port.global_position
	s["vel"] = b * v_local
	s["spin"] = Vector3(rng.randf_range(-25.0, 25.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-25.0, 25.0))
	s["basis"] = b * Basis(Vector3.FORWARD, PI * 0.5)
	s["left"] = tw.shell_life_s
	node.top_level = true
	node.global_transform = Transform3D(s["basis"], s["pos"])
	_shells.append(s)
	shells_ejected += 1


func _apply_shell_look(node: MeshInstance3D, kind: StringName, tw: FpViewmodelTweak) -> void:
	var big: bool = kind == &"shotgun"
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.0105 if big else 0.0055
	c.bottom_radius = c.top_radius
	c.height = 0.06 if big else (0.045 if kind == &"rifle" else 0.022)
	c.radial_segments = 8
	c.rings = 1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tw.shell_color_shotgun if big else tw.shell_color
	mat.metallic = 0.0 if big else 0.85
	mat.roughness = 0.6 if big else 0.3
	c.material = mat
	node.mesh = c


func _tick_shells(delta: float, tw: FpViewmodelTweak) -> void:
	for s: Dictionary in _shells:
		var node: MeshInstance3D = _live(s["node"]) as MeshInstance3D
		if node == null or not node.visible:
			continue
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) <= 0.0:
			node.visible = false
			continue
		var v: Vector3 = s["vel"]
		v += Vector3.DOWN * tw.shell_gravity * delta
		s["vel"] = v
		s["pos"] = (s["pos"] as Vector3) + v * delta
		var spin: Vector3 = s["spin"]
		var b: Basis = s["basis"]
		if spin.length() > 0.0:
			b = (b * Basis(spin.normalized(), spin.length() * delta)).orthonormalized()
		s["basis"] = b
		node.global_transform = Transform3D(b, s["pos"])


# --- Tracers -------------------------------------------------------------------------------------------

func _on_shot_fx(origin: Vector3, end: Vector3, _normal: Vector3, _surface: StringName, _weapon_class: StringName,
		shooter_net_id: int, flags: int) -> void:
	if _vm == null or _vm.crew() == null or (flags & FLAG_FIRST_PERSON) == 0 or shooter_net_id != _vm.crew().net_id:
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if (flags & FLAG_SUPPRESSED) != 0 and not tw.tracer_when_suppressed:
		return
	_tracer_count += 1
	var every: int = maxi(int(tw.tracer_every.get(_vm.weapon_class_key(), 2)), 1)
	if (_tracer_count - 1) % every != 0:
		return
	var from: Vector3 = _vm.muzzle_world_apparent()
	if from == Vector3.INF:
		from = origin
	draw_tracer(from, end)


## A streak from `from` to `to` (world layer, world space): ENV C's TracerFx when present (one per world, it
## advances itself), else the placeholder travelling at FpViewmodelTweak.tracer_speed_mps.
func draw_tracer(from: Vector3, to: Vector3) -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var dist: float = from.distance_to(to)
	if dist < 1.0:
		return
	var world: Node = _world_parent()
	if world == null:
		return
	if _c_tracer == null or not is_instance_valid(_c_tracer):
		_c_tracer = _instance(tw.vfx_tracer_scene_path)
		if _c_tracer != null and not _c_tracer.has_method(&"spawn"):
			_c_tracer.free()
			_c_tracer = null
		if _c_tracer != null:
			_c_tracer.name = "FpTracerFx"
			world.add_child(_c_tracer)
	if _c_tracer != null:
		_c_tracer.call(&"spawn", from, to)
		tracers_drawn += 1
		return
	var t: Dictionary = {}
	if _tracers.size() >= TRACER_POOL:
		t = _tracers.pop_front()
	if t.is_empty() or _live(t["node"]) == null:
		var node: Node3D = _make_tracer(tw)
		world.add_child(node)
		t = {"node": node}
	var n: Node3D = t["node"]
	t["from"] = from
	t["dir"] = (to - from) / dist
	t["dist"] = dist
	t["head"] = 0.0
	t["frame"] = Engine.get_process_frames()
	n.visible = true
	_place_tracer(t, tw)
	_tracers.append(t)
	tracers_drawn += 1


func _make_tracer(tw: FpViewmodelTweak) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "FpTracer"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(tw.tracer_width_m, tw.tracer_width_m, 1.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = tw.tracer_color
	box.material = mat
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 1
	return mi


func _tick_tracers(delta: float, tw: FpViewmodelTweak) -> void:
	for t: Dictionary in _tracers:
		var n: Node3D = _live(t["node"])
		if n == null or not n.visible:
			continue
		if Engine.get_process_frames() <= int(t["frame"]):
			continue  # the shot's own frame draws the streak leaving the muzzle
		t["head"] = float(t["head"]) + tw.tracer_speed_mps * delta
		if float(t["head"]) - tw.tracer_length_m >= float(t["dist"]):
			n.visible = false
			continue
		_place_tracer(t, tw)


## Stretch the unit-length streak between its tail and head (both clamped to the shot segment).
func _place_tracer(t: Dictionary, tw: FpViewmodelTweak) -> void:
	var n: Node3D = t["node"]
	var dist: float = float(t["dist"])
	var head: float = clampf(float(t["head"]) + tw.tracer_first_frame_m, 0.0, dist)
	var tail: float = clampf(float(t["head"]) + tw.tracer_first_frame_m - tw.tracer_length_m, 0.0, dist)
	var len: float = maxf(head - tail, 0.01)
	var dir: Vector3 = t["dir"]
	var mid: Vector3 = (t["from"] as Vector3) + dir * (tail + len * 0.5)
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var b: Basis = Basis.looking_at(dir, up)
	n.global_transform = Transform3D(b.scaled_local(Vector3(1.0, 1.0, len)), mid)


func _world_parent() -> Node:
	var crew: CrewController = _vm.crew() if _vm != null else null
	if crew != null and is_instance_valid(crew) and crew.get_parent() != null:
		return crew.get_parent()
	return get_tree().current_scene if is_inside_tree() else null


## The node in `v` when still alive, else null (pool entries and pending casings can outlive a heist teardown;
## assigning a freed instance to a typed variable is a script error).
static func _live(v: Variant) -> Node3D:
	return v as Node3D if is_instance_valid(v) else null


static func _instance(path: String) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


## The viewmodel draws into a transparent SubViewport: an additive material leaves alpha at 0 there and vanishes
## when the layer is composited, so every additive / billboard material of a library scene used on the viewmodel is
## re-made as MIX (and billboards keep the root's scale).
static func _alpha_blend(root: Node) -> void:
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = n as GeometryInstance3D
		var src: Material = g.material_override
		if src == null:
			var mesh: Mesh = null
			if g is MeshInstance3D:
				mesh = (g as MeshInstance3D).mesh
			elif g is CPUParticles3D:
				mesh = (g as CPUParticles3D).mesh
			elif g is GPUParticles3D:
				mesh = (g as GPUParticles3D).draw_pass_1
			if mesh != null and mesh.get_surface_count() > 0:
				src = mesh.surface_get_material(0)
		var bm: BaseMaterial3D = src as BaseMaterial3D
		if bm != null and (bm.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
				or bm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED):
			var mix: BaseMaterial3D = bm.duplicate() as BaseMaterial3D
			mix.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			mix.billboard_keep_scale = true  # a billboard ignores the root's FP scale otherwise (1 m at 0.5 m)
			g.material_override = mix
