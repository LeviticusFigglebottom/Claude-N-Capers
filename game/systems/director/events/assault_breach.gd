## PO6-17 breach point (PD2 wall / window / ceiling breach). Owner: ENV A. Replicated dynamic entity placed at a
## `Breach_<n>` marker (docs/levels/_art/po6_17/README.md §4: -Z into the room, the marker's `Visual` child is
## ENV C's breach scene with Model/Intact (+ Intact/Collision), Model/Blown (hidden), Charge / EntryPoint /
## ExitPoint / RopeAnchor markers). `params.marker` = the marker's path under the map ("" = a fallback ENTRY
## point: blast + squad only, no geometry). A marker without `Visual` gets C's scene from G.PROPS_DIR or a
## placeholder with the same node names.
## Stages: WARNING (warning_s: a charge with a blinking red light at Charge, cue.assault_breach_warning) ->
## BLOWN: Intact hidden + its collision off, Blown shown; a wall breach enables a NavigationLink3D EntryPoint ->
## ExitPoint (both ways); then Explosion.apply at the charge (world attacker: hurts crew and NPCs, C4 fx, PO6-19
## pushes bodies). The runner sends the squad through (walk for a wall, rope for window / ceiling).
class_name AssaultBreach
extends AssaultEventEntity

signal blown(breach: AssaultBreach)

enum Stage { IDLE, WARNING, BLOWN }

const LINK_NAME: String = "BreachLink"

var map_marker: Node3D = null
var visual: Node3D = null
var intact: Node3D = null
var blown_node: Node3D = null
var charge_mesh: Node3D = null
var charge_light: OmniLight3D = null
var link: NavigationLink3D = null
var breach_kind: String = "wall"
var size: Vector2 = Vector2(1.0, 2.2)
## Window / ceiling rope (world ends, Vector3.INF = none), set by the runner on the server, replicated.
var rope_top: Vector3 = Vector3.INF
var rope_bottom: Vector3 = Vector3.INF
var rope_mesh: MeshInstance3D = null
## Server-set, replicated: the rope is drawn only while a unit still has to come down it.
var rope_shown: bool = false
## The charge appears this long into WARNING (a placer's breach_place `place` event; 0 = at once).
var charge_delay_s: float = 0.0
var _blink_t: float = 0.0


func _build() -> void:
	breach_kind = String(params.get("breach_kind", "wall"))
	size = params.get("size", Vector2(1.0, 2.2)) as Vector2
	var rt: HeistRuntime = HeistRuntime.of(self)
	var path: String = String(params.get("marker", ""))
	if rt != null and rt.map != null and path != "":
		map_marker = rt.map.get_node_or_null(NodePath(path)) as Node3D
	if map_marker != null:
		visual = map_marker.get_node_or_null(^"Visual") as Node3D
	if visual == null and not bool(params.get("fx_only", false)):
		visual = AssaultEventEntity.prop(String(params.get("breach_scene", AssaultEventsTweak.data().breach_scene)) % breach_kind)
		if visual == null:
			visual = _placeholder(breach_kind, size)
		visual.name = "Visual"
		add_child(visual)
	if visual != null:
		intact = AssaultEventEntity.find_named(visual, "Intact")
		blown_node = AssaultEventEntity.find_named(visual, "Blown")
	charge_mesh = AssaultEventEntity.box("Charge", Vector3(0.3, 0.22, 0.08), Color(0.25, 0.22, 0.15))
	add_child(charge_mesh)
	charge_light = OmniLight3D.new()
	charge_light.light_color = Color(1.0, 0.1, 0.05)
	charge_light.omni_range = 3.0
	charge_light.light_energy = 0.0
	charge_mesh.add_child(charge_light)
	charge_mesh.visible = false
	rope_mesh = AssaultEventEntity.cylinder("Rope", 0.02, 1.0, Color(0.1, 0.09, 0.08))
	rope_mesh.visible = false
	rope_mesh.top_level = true  # one straight world-space line, never inherits a parent basis
	add_child(rope_mesh)


## Same names / frame as C's breach scenes (opening on the room-side surface, -Z into the room).
static func _placeholder(k: String, sz: Vector2) -> Node3D:
	var root: Node3D = Node3D.new()
	var m: Node3D = Node3D.new()
	m.name = "Model"
	root.add_child(m)
	var it: Node3D = AssaultEventEntity.marker("Intact", Vector3.ZERO)
	m.add_child(it)
	var thick: float = 0.2
	var center: Vector3 = Vector3(0, sz.y * 0.5, thick * 0.5)
	var dims: Vector3 = Vector3(sz.x, sz.y, thick)
	if k == "ceiling":
		center = Vector3(0, 0, 0.3)
		dims = Vector3(sz.x, sz.y, 0.6)
	it.add_child(AssaultEventEntity.box("InfillMesh", dims, Color(0.72, 0.7, 0.64), center))
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "Collision"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = dims
	cs.shape = bs
	cs.position = center
	sb.add_child(cs)
	it.add_child(sb)
	var bl: Node3D = AssaultEventEntity.marker("Blown", Vector3.ZERO)
	bl.visible = false
	m.add_child(bl)
	var soot: Color = Color(0.09, 0.08, 0.07)
	if k == "ceiling":
		bl.add_child(AssaultEventEntity.box("BlownFrame", Vector3(sz.x + 0.3, sz.y + 0.3, 0.04), soot, Vector3(0, 0, -0.02)))
	else:
		for sx: float in [-1.0, 1.0]:
			bl.add_child(AssaultEventEntity.box("BlownFrameL" if sx < 0.0 else "BlownFrameR", Vector3(0.12, sz.y, thick + 0.04), soot,
				Vector3(sx * (sz.x * 0.5 + 0.06), sz.y * 0.5, thick * 0.5)))
		bl.add_child(AssaultEventEntity.box("Scorch", Vector3(sz.x + 1.2, 0.02, 1.4), soot, Vector3(0, 0.01, -0.7)))
	for i: int in range(5):
		var deb: MeshInstance3D = AssaultEventEntity.box("Debris%d" % i, Vector3(0.25, 0.08, 0.18), Color(0.6, 0.58, 0.52),
			Vector3(-0.5 + 0.25 * i, 0.04, -0.4 - 0.3 * (i % 3)))
		deb.rotation.y = 0.7 * i
		bl.add_child(deb)
	m.add_child(AssaultEventEntity.marker("Charge", _default_local(k, sz, "Charge")))
	m.add_child(AssaultEventEntity.marker("EntryPoint", _default_local(k, sz, "EntryPoint")))
	m.add_child(AssaultEventEntity.marker("ExitPoint", _default_local(k, sz, "ExitPoint")))
	if k != "wall":
		m.add_child(AssaultEventEntity.marker("RopeAnchor", _default_local(k, sz, "RopeAnchor")))
	return root


## README §4 marker positions (marker frame).
static func _default_local(k: String, sz: Vector2, which: String) -> Vector3:
	match k:
		"window":
			return {"Charge": Vector3(0, 1.0, 0.43), "EntryPoint": Vector3(0, 0, 1.0), "ExitPoint": Vector3(0, 0, -1.0),
				"RopeAnchor": Vector3(0, 4.6, 0.2)}.get(which, Vector3.ZERO)
		"ceiling":
			return {"Charge": Vector3(0, 0, 0.84), "EntryPoint": Vector3(0, 1.65, 0.6), "ExitPoint": Vector3(0, 0, -3.0),
				"RopeAnchor": Vector3(0, 0.7, 0.8)}.get(which, Vector3.ZERO)
	return {"Charge": Vector3(0, sz.y * 0.5, 0.23), "EntryPoint": Vector3(0, 0, 1.1), "ExitPoint": Vector3(0, 0, -1.0),
		"RopeAnchor": Vector3(0, sz.y + 2.0, 0.6)}.get(which, Vector3.ZERO)


## World position of a breach marker (Charge / EntryPoint / ExitPoint / RopeAnchor).
func point(which: String) -> Vector3:
	if bool(params.get("fx_only", false)):
		return global_position + (Vector3(0, 1.0, 0) if which == "Charge" else Vector3.ZERO)
	var n: Node3D = AssaultEventEntity.find_named(visual, which) if visual != null else null
	if n != null and n.is_inside_tree():
		return n.global_position
	return global_transform * _default_local(breach_kind, size, which)


func is_blown() -> bool:
	return stage == Stage.BLOWN


func _apply_stage(s: int) -> void:
	_update_charge()
	if s == Stage.BLOWN:
		if intact != null:
			intact.visible = false
			_disable_collision(intact)
		if blown_node != null:
			blown_node.visible = true


static func _disable_collision(n: Node) -> void:
	var co: CollisionObject3D = n as CollisionObject3D
	if co != null:
		co.collision_layer = 0
		co.collision_mask = 0
		co.process_mode = Node.PROCESS_MODE_DISABLED
	for c: Node in n.get_children():
		_disable_collision(c)


## The charge on the wall at Charge (C's Model/Charge, 1.1 m high on a wall) from charge_delay_s into WARNING.
func _update_charge() -> void:
	if charge_mesh == null:
		return
	var on: bool = stage == Stage.WARNING and stage_time >= charge_delay_s
	if on and not charge_mesh.visible and charge_mesh.is_inside_tree():
		charge_mesh.global_position = point("Charge")
	charge_mesh.visible = on


func _process(delta: float) -> void:
	_update_charge()
	if charge_light == null:
		return
	if stage != Stage.WARNING:
		charge_light.light_energy = 0.0
		return
	_blink_t += delta
	var rate: float = 2.0 + 6.0 * clampf(stage_time / maxf(p_float("warning_s", 3.5), 0.01), 0.0, 1.0)
	charge_light.light_energy = 3.0 if fmod(_blink_t * rate, 1.0) < 0.5 else 0.2
	if not is_server():
		stage_time += delta


# --- Server -------------------------------------------------------------------------------------

func start() -> void:
	set_stage(Stage.WARNING)  # cue.assault_breach_warning: C's CuePlayer on assault_event_started


func _physics_process(delta: float) -> void:
	if not is_server() or stage != Stage.WARNING:
		return
	stage_time += delta
	if stage_time >= p_float("warning_s", 3.5):
		blow()


## Server: blow it now (idempotent).
func blow() -> void:
	if stage == Stage.BLOWN or not is_server():
		return
	var at: Vector3 = point("Charge")
	set_stage(Stage.BLOWN)
	if breach_kind == "wall" and visual != null:
		_open_link()
	Explosion.apply(self, at, p_float("radius_m", 4.5), p_float("damage", 60.0), 0, &"breach_c4")
	cue(&"cue.c4_explode", at)  # audio_cues.md v1.8 (Explosion.apply emits only the explosion_fx, no cue)
	_stun_around(at)
	blown.emit(self)
	end_event()


## PO6-17b (PD2 breaches stagger): every non-police NPC (civilians, hostages, guards; never the police that set the
## charge, roles police / special) within stun_radius_m with blast LOS is stunned npc_stun_s; every
## crew member in range with LOS is flashed crew_flash_s scaled by distance (full at the charge, half at the edge).
func _stun_around(at: Vector3) -> void:
	var r: float = p_float("stun_radius_m", 8.0)
	if r <= 0.0:
		return
	var mask: int = CombatTweak.data().explosion_los_mask
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null:
		return
	for n: Node in get_tree().get_nodes_in_group(G.NPC):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive or not rt.is_ancestor_of(npc) or npc.role in [&"police", &"special"]:
			continue
		var eye: Vector3 = npc.global_position + Vector3.UP * 1.5
		if eye.distance_to(at) <= r and CombatSystem.has_los(self, at, eye, [npc], mask):
			npc.stun(p_float("npc_stun_s", 3.0))
	for c: CrewController in rt.crew_members():
		var ce: Vector3 = c.eye_position()
		var d: float = ce.distance_to(at)
		if d > r or not CombatSystem.has_los(self, at, ce, [c], mask):
			continue
		var hp: CrewHealth = c.health as CrewHealth
		if hp != null:
			hp.flash(p_float("crew_flash_s", 2.5) * lerpf(1.0, 0.5, clampf(d / r, 0.0, 1.0)))


## Server: hang the rope between two world points (or clear it with Vector3.INF).
func set_rope(top: Vector3, bottom: Vector3) -> void:
	rope_top = top
	rope_bottom = bottom
	_show_rope()


func set_rope_shown(on: bool) -> void:
	rope_shown = on
	_show_rope()


func _show_rope() -> void:
	if rope_mesh == null:
		return
	rope_mesh.visible = rope_shown and rope_top != Vector3.INF and rope_bottom != Vector3.INF \
		and rope_top.distance_to(rope_bottom) > 0.2
	if not rope_mesh.visible:
		return
	var d: Vector3 = rope_top - rope_bottom
	(rope_mesh.mesh as CylinderMesh).height = d.length()
	rope_mesh.transform = Transform3D(rope_basis(d), (rope_top + rope_bottom) * 0.5)  # top_level: world space


## Orthonormal basis whose +Y runs along `d` (a CylinderMesh stands on its local Y axis).
static func rope_basis(d: Vector3) -> Basis:
	var y: Vector3 = d.normalized()
	if y.dot(Vector3.UP) > 0.9999:
		return Basis.IDENTITY
	if y.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, y))  # the shortest rotation taking +Y onto the rope


func _net_state() -> Dictionary:
	var d: Dictionary = {"stage": stage, "cd": charge_delay_s, "rs": rope_shown}
	if rope_top != Vector3.INF:
		d["rt"] = rope_top
		d["rb"] = rope_bottom
	return d


func _apply_net_state(d: Dictionary) -> void:
	super._apply_net_state(d)
	if d.has("cd"):
		charge_delay_s = float(d["cd"])
	if d.has("rt") or d.has("rb") or d.has("rs"):
		rope_top = d.get("rt", rope_top) as Vector3
		rope_bottom = d.get("rb", rope_bottom) as Vector3
		rope_shown = bool(d.get("rs", rope_shown))
		_show_rope()


func _open_link() -> void:
	link = NavigationLink3D.new()
	link.name = LINK_NAME
	link.bidirectional = true
	add_child(link)
	link.global_transform = Transform3D.IDENTITY
	link.start_position = point("EntryPoint")
	link.end_position = point("ExitPoint")
