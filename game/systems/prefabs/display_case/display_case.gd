## Glass display case holding small loot (gameplay_prefabs.md `display_case`). Owner: ENV A.
## Break the glass (S9.9: loud stimulus + noise) or open it with a key to reach the loot.
## Visual: `Body`, `Glass` (MeshInstance3D(s); A hides them and spawns shatter), `LootAnchor`
## marker(s). Floor object: pivot bottom-centre, front -Z.
## Behaviour: the Interactable smashes the glass (kind &"break_glass", InteractionTweak.glass_break_s
## unless `interaction_time_s` is set) or, with `requires_item`, opens it with that key (kind
## &"open_case", no glass break). Shooting the case (`take_hit`, damage.md) also breaks the glass. Breaking:
## `Glass` hidden, glass_broken [R], 15 m noise, `broken_glass` stimulus; `glass_breaks_alarm` raises
## alarm_raised(&"glass_alarm"). Then the same Interactable takes the loot (kind &"take_loot",
## small_loot_s) -> small_loot_taken(value, slot) [R]; value = ContentDB.loot(loot_id).value, else
## LootTweak.display_case_default_value.
## D-142 (PD2: guards see through glass): at ready the case's box is split at the visual's `Glass` (merged mesh AABB):
## `GlassBody` (same layers and surface as `Collision`, group StealthDirector.GROUP_SEE_THROUGH) spans the glass band,
## `Collision/Shape` keeps the cabinet below it and `Collision/CapShape` any top above it (both block vision). Movement
## and bullets still stop at the whole case; a broken case keeps every body (as before), the glass band now open air for
## vision. Not split (whole box opaque) when the visual supplies its own `Collision` or has no Glass mesh in the box.
class_name DisplayCase
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/display_case/display_case_placeholder.tscn")

## LootDef id of the small loot inside.
@export var loot_id: StringName = &""
## Breaking the glass raises the alarm (alarmed case) in addition to the S9.9 stimulus.
@export var glass_breaks_alarm: bool = false
## Collision box size (m), placed on the pivot; ZERO = fit to the visual (or use the visual's own
## `Collision`), see GameplayPrefab "Collision fitting".
@export var collision_size_override: Vector3 = Vector3.ZERO
@export_group("Interaction")
## -1 = InteractionTweak.display_case_open_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var glass_broken: bool = false
## D-142: the see-through glass body (null when the case is not split).
var glass_body: StaticBody3D = null
var opened: bool = false
var taken: bool = false

var _glass_stim_id: int = 0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body", "Glass", "LootAnchor"])


func _default_interaction_time() -> float:
	return Tweak.interaction().display_case_open_s


func _prefab_ready() -> void:
	_route_hits(get_node_or_null(^"Collision"))
	_split_glass_body()
	interactable.completed.connect(_on_completed)
	_apply_state()


## D-142: split the fitted box at the visual's Glass band (see the header).
func _split_glass_body() -> void:
	if visual_collision != null:
		return
	var own: StaticBody3D = get_node_or_null(^"Collision") as StaticBody3D
	var cs: CollisionShape3D = get_node_or_null(^"Collision/Shape") as CollisionShape3D
	if own == null or cs == null or not (cs.shape is BoxShape3D) or cs.disabled:
		return
	var size: Vector3 = (cs.shape as BoxShape3D).size
	var box: AABB = AABB(xform_to_self(cs).origin - size * 0.5, size)
	var glass: AABB = merged_mesh_aabb(visual_node("Glass")).intersection(box)
	var lo_y: float = glass.position.y
	var hi_y: float = glass.end.y
	if glass.size.x <= 0.0 or glass.size.z <= 0.0 or hi_y - lo_y < COLLISION_MIN_EXTENT_M:
		return
	glass_body = StaticBody3D.new()
	glass_body.name = "GlassBody"
	glass_body.collision_layer = own.collision_layer
	glass_body.collision_mask = own.collision_mask
	inherit_surface(own, glass_body)
	add_child(glass_body)
	glass_body.add_to_group(StealthDirector.GROUP_SEE_THROUGH)
	_route_hits(glass_body)
	var c: Vector3 = glass.get_center()
	_box_shape(glass_body, "Shape", Vector3(maxf(glass.size.x, COLLISION_MIN_EXTENT_M), hi_y - lo_y,
		maxf(glass.size.z, COLLISION_MIN_EXTENT_M)), Vector3(c.x, (lo_y + hi_y) * 0.5, c.z))
	var base_h: float = lo_y - box.position.y
	if base_h >= COLLISION_MIN_EXTENT_M:
		_box_shape(own, "Shape", Vector3(size.x, base_h, size.z), Vector3(box.get_center().x, box.position.y + base_h * 0.5,
			box.get_center().z))
	else:
		cs.disabled = true
	var cap_h: float = box.end.y - hi_y
	if cap_h >= COLLISION_MIN_EXTENT_M:
		_box_shape(own, "CapShape", Vector3(size.x, cap_h, size.z), Vector3(box.get_center().x, hi_y + cap_h * 0.5,
			box.get_center().z))


## Box `shape_name` (created if missing) under `body`, `size` centred at `centre` in this prefab's space.
func _box_shape(body: StaticBody3D, shape_name: String, size: Vector3, centre: Vector3) -> void:
	var cs: CollisionShape3D = body.get_node_or_null(NodePath(shape_name)) as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new()
		cs.name = shape_name
		body.add_child(cs)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xform_to_self(body).affine_inverse() * Transform3D(Basis.IDENTITY, centre)


## Payout of the loot inside (integer dollars).
func loot_value() -> int:
	if loot_id != &"":
		var info: Dictionary = LootManager.loot_info(loot_id)
		if bool(info.get("known", false)):
			return int(info["value"])
	return LootTweak.get_default().display_case_default_value


## Client (A3-07, HeistNetSync): mirror `glass_broken` / `opened` / `taken` (glass, prompt).
func _apply_net_state(state: Dictionary) -> void:
	if bool(state.get("glass_broken", glass_broken)) and not glass_broken:
		glass_broken = true
		var glass: Node3D = visual_node("Glass") as Node3D
		if glass != null:
			glass.visible = false
	opened = bool(state.get("opened", opened))
	if bool(state.get("taken", taken)) and not taken:
		taken = true
		var anchor: Node3D = visual_node("LootAnchor") as Node3D
		if anchor != null:
			for c: Node in anchor.get_children():
				if c is Node3D:
					(c as Node3D).visible = false
	_apply_state()


## Server: smash the glass (interaction, gunfire, melee). S9.9.
func break_glass(by_net_id: int = 0) -> void:
	if not Net.is_authority() or glass_broken:
		return
	glass_broken = true
	var glass: Node3D = visual_node("Glass") as Node3D
	var pos: Vector3 = glass.global_position if glass != null else global_position + Vector3.UP
	if glass != null:
		glass.visible = false
	_glass_stim_id = _shatter_glass(pos)
	if glass_breaks_alarm:
		_raise_alarm(&"glass_alarm", by_net_id if by_net_id != 0 else net_id)
	_apply_state()


## Combat hook: any hit breaks the glass.
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	if Net.is_authority():
		break_glass(attacker_net_id)
	return _publish_hit(info, attacker_net_id)


## Deprecated alias of take_hit (pre-D-026 callers).
func apply_damage(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	return take_hit(info, attacker_net_id)


func _exit_tree() -> void:
	var st: StealthDirector = _stealth()
	if st != null and _glass_stim_id != 0:
		st.unregister_stimulus(_glass_stim_id)
	_glass_stim_id = 0


func _apply_state() -> void:
	var tw: InteractionTweak = Tweak.interaction()
	interactable.consumes_item = false
	if taken:
		interactable.enabled = false
	elif glass_broken or opened:
		interactable.kind = &"take_loot"
		interactable.prompt_key = &"ui.prompt.take_loot"
		interactable.interaction_time_s = tw.small_loot_s
		interactable.requires_item = &""
		interactable.noise = &"silent"
	elif requires_item != &"":
		interactable.kind = &"open_case"
		interactable.interaction_time_s = interaction_time_s if interaction_time_s >= 0.0 else tw.display_case_open_s
	else:
		interactable.kind = &"break_glass"
		interactable.prompt_key = &"ui.prompt.break_glass"
		interactable.interaction_time_s = interaction_time_s if interaction_time_s >= 0.0 else tw.glass_break_s


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or taken:
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	if glass_broken or opened:
		taken = true
		var anchor: Node3D = visual_node("LootAnchor") as Node3D
		if anchor != null:
			for c: Node in anchor.get_children():
				if c is Node3D:
					(c as Node3D).visible = false
		_emit_fact(&"small_loot_taken", [loot_value(), slot])
		_apply_state()
	elif requires_item != &"":
		opened = true
		_apply_state()
	else:
		var c: CrewController = crew as CrewController
		break_glass(c.net_id if c != null else 0)
