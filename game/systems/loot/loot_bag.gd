## Loot bag (S6.3, S10.1, S10.2): a server-simulated RigidBody3D the crew carries, drops, throws
## and secures. Owner: ENV A. Spawned by LootManager (`spawn_bag`) or pre-placed in a map.
## Visual: `Visual` gets `visual_scene` (LootDef.bag_model) or `loot_bag_placeholder.tscn`, which
## has the `Bag` mesh (visual_slots.md: pivot bottom, size by weight class).
## Physics: layer loot (7), collides with world_static/world_dynamic only (never blocks the crew).
## Stealth: while it lies around it is a `bag` stimulus (`body_bag` for bagged bodies). Pre-placed
## bags have `moved == false` until their first pickup and are ignored (S4.1). Body bags in a
## BODY_HIDE zone / body_container set `hidden_from_stealth` (S6.3).
## Carrying: frozen, no collision, follows the carrier's back (LootManager.carry / drop_bag).
## QC-57: an NPC can carry a bag too (`npc_carrier`, LootManager.npc_carry / npc_drop: GN's Vaultline courier with the
## Lantern Bearer); it follows the NPC's back the same way and the crew cannot pick it up until he lets go.
class_name LootBag
extends RigidBody3D

const LAYER_LOOT: int = 1 << 6
const MASK_WORLD: int = (1 << 0) | (1 << 1)
const PLACEHOLDER: PackedScene = preload("res://systems/loot/loot_bag_placeholder.tscn")
## Size the placeholder `Bag` mesh is modelled at (m).
const PLACEHOLDER_SIZE_M: Vector3 = Vector3(0.6, 0.35, 0.35)

## LootDef id (&"loot.cash", &"loot.body_bag"...).
@export var loot_id: StringName = &""
## Enums.LootWeight (read by CrewController via `carried_bag.get(&"weight")`).
@export var weight: Enums.LootWeight = Enums.LootWeight.MEDIUM
## Base payout (integer dollars; difficulty multiplier applied at payout).
@export var value: int = 0
## S4.1: false for pre-placed bags until first pickup (NPCs ignore them).
@export var moved: bool = false
## Bag art (LootDef.bag_model). Null = placeholder.
@export var visual_scene: PackedScene

var net_id: int = 0
## Crew member carrying this bag, or null.
var carrier: CrewController = null
## QC-57: NPC carrying this bag (a Vaultline courier), or null. Exclusive with `carrier`.
var npc_carrier: NpcBase = null
## QC-57 / QC-60: objective tag for HUD markers (HeistRuntime.find_by_tag): a mission tags a moved required bag (GN:
## the Lantern Bearer the couriers took) so its objective marker follows the bag.
var objective_tag: StringName = &""
## S6.3: body bag inside a BODY_HIDE zone / body_container.
var hidden_from_stealth: bool = false
var secured: bool = false
## True between a throw and the first contact.
var in_flight: bool = false
## PO6-14: slot of the crew member who last threw this bag (-1 = not thrown / picked up since), and the
## seconds since that throw (INF when not thrown). Server only; AI teammates catch/pick up thrown bags.
var thrown_by_slot: int = -1
var since_thrown_s: float = INF
## Seconds at rest inside a SECURE_LOOT zone (LootManager).
var rest_time: float = 0.0
## BodyContainer currently hiding this bag, or null.
var container: Node = null
var visual_instance: Node3D = null

var _stim_id: int = 0
var _stim_kind: StringName = &""

@onready var interactable: InteractableComponent = get_node_or_null(^"Interactable") as InteractableComponent
@onready var visual_root: Node3D = get_node_or_null(^"Visual") as Node3D
@onready var collision: CollisionShape3D = get_node_or_null(^"Collision") as CollisionShape3D


func _ready() -> void:
	add_to_group(G.LOOT_BAG)
	NetIds.claim(self)
	collision_layer = LAYER_LOOT
	collision_mask = MASK_WORLD
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)
	_apply_weight()
	_build_visual()
	if interactable != null:
		interactable.kind = &"pick_bag"
		interactable.interaction_time_s = Tweak.interaction().bag_loot_s
		interactable.allowed_with_bag = false
		interactable.casing_allowed = false  # S1.1: no bags while casing
		interactable.completed.connect(_on_pick_completed)
	_update_stimulus()


func _exit_tree() -> void:
	_unregister_stimulus()


func is_body_bag() -> bool:
	return loot_id == LootTweak.get_default().body_bag_loot_id


func is_carried() -> bool:
	return (carrier != null and is_instance_valid(carrier)) or is_npc_carried()


## QC-57: carried by an NPC (not crew).
func is_npc_carried() -> bool:
	return npc_carrier != null and is_instance_valid(npc_carrier)


## Server (LootManager.npc_carry, QC-57): attach to an NPC's back. `moved` is left as it is (a courier's bag is not a
## crew-moved bag, S4.1).
func attach_npc(npc: NpcBase) -> void:
	carrier = null
	npc_carrier = npc
	in_flight = false
	thrown_by_slot = -1
	since_thrown_s = INF
	rest_time = 0.0
	set_hidden(false, null)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if interactable != null:
		interactable.enabled = false
	_follow_carrier()
	_update_stimulus()


## Server (LootManager): attach to `crew`'s back.
func attach(crew: CrewController) -> void:
	carrier = crew
	npc_carrier = null
	moved = true
	in_flight = false
	thrown_by_slot = -1
	since_thrown_s = INF
	rest_time = 0.0
	set_hidden(false, null)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if interactable != null:
		interactable.enabled = false
	_follow_carrier()
	_update_stimulus()


## Server (LootManager): let go at `pos` with `velocity` (thrown = flies until first contact).
func release(pos: Vector3, velocity: Vector3, thrown: bool) -> void:
	var yaw: float = rotation.y
	if carrier != null and is_instance_valid(carrier):
		yaw = carrier.look_yaw
	elif is_npc_carried():
		yaw = npc_carrier.global_rotation.y
	carrier = null
	npc_carrier = null
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	collision_layer = LAYER_LOOT
	collision_mask = MASK_WORLD
	freeze = false
	sleeping = false
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO
	in_flight = thrown
	since_thrown_s = 0.0 if thrown else INF
	if not thrown:
		thrown_by_slot = -1
	rest_time = 0.0
	if interactable != null:
		interactable.enabled = true
	_update_stimulus()


## S6.3: hide/unhide from stealth (BODY_HIDE zone or body_container).
func set_hidden(hidden: bool, by_container: Node) -> void:
	if container != null and container != by_container and is_instance_valid(container) \
			and container.has_method(&"release_bag"):
		container.call(&"release_bag", self)
	container = by_container if hidden else null
	hidden_from_stealth = hidden


## Server (LootManager): secured; stops being a stimulus. The manager frees it.
func mark_secured() -> void:
	secured = true
	set_hidden(false, null)
	if interactable != null:
		interactable.enabled = false
	_update_stimulus()


func _physics_process(_delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(_delta)
	FrameProf.end(&"loot_bag", fp)


func _physics_step(_delta: float) -> void:
	if npc_carrier != null:
		if not is_instance_valid(npc_carrier) or not npc_carrier.is_inside_tree():
			npc_carrier = null
			if Net.is_authority():
				release(global_position, Vector3.ZERO, false)
			return
		_follow_carrier()
		return
	if carrier == null:
		if since_thrown_s < INF:
			since_thrown_s += _delta
		return
	if not is_instance_valid(carrier) or not carrier.is_inside_tree():
		release(global_position, Vector3.ZERO, false)
		return
	_follow_carrier()


func _follow_carrier() -> void:
	var tw: LootTweak = LootTweak.get_default()
	if is_npc_carried():
		if not npc_carrier.is_inside_tree():
			return
		var basis_n: Basis = Basis(Vector3.UP, npc_carrier.global_rotation.y)
		global_transform = Transform3D(basis_n, npc_carrier.global_position + basis_n * tw.carry_offset)
		return
	if not is_carried() or not carrier.is_inside_tree():
		return
	var basis_y: Basis = Basis(Vector3.UP, carrier.look_yaw)
	global_transform = Transform3D(basis_y, carrier.global_position + basis_y * tw.carry_offset)


func _on_body_entered(_body: Node) -> void:
	if not in_flight:
		return
	in_flight = false
	var keep: float = LootTweak.get_default().landing_velocity_keep
	linear_velocity *= keep
	angular_velocity *= keep


func _on_pick_completed(crew: Node) -> void:
	if not Net.is_authority():
		return
	var c: CrewController = crew as CrewController
	var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
	if c == null or mgr == null:
		return
	mgr.carry(self, c)


func _apply_weight() -> void:
	var tw: LootTweak = LootTweak.get_default()
	var w: int = clampi(int(weight), 0, 3)
	if w < tw.bag_mass_kg.size():
		mass = tw.bag_mass_kg[w]
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = tw.friction
	pm.bounce = tw.bounce
	physics_material_override = pm
	if collision != null and w < tw.bag_size_m.size():
		var size: Vector3 = tw.bag_size_m[w]
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		collision.shape = box
		collision.position = Vector3(0.0, size.y * 0.5, 0.0)
		if interactable != null:
			interactable.position = Vector3(0.0, size.y * 0.7, 0.0)


func _build_visual() -> void:
	if visual_root == null:
		return
	var scene: PackedScene = visual_scene if visual_scene != null else PLACEHOLDER
	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:
		Log.error(&"loot", "%s: bag visual root must be a Node3D" % name)
		return
	visual_root.add_child(inst)
	visual_instance = inst
	if inst.find_child("Bag", true, false) == null:
		Log.error(&"loot", "%s: bag visual is missing required node `Bag` (visual_slots.md)" % name)
	var tw: LootTweak = LootTweak.get_default()
	var w: int = clampi(int(weight), 0, 3)
	if visual_scene == null and w < tw.bag_size_m.size():
		var s: Vector3 = tw.bag_size_m[w]
		inst.scale = Vector3(s.x / PLACEHOLDER_SIZE_M.x, s.y / PLACEHOLDER_SIZE_M.y, s.z / PLACEHOLDER_SIZE_M.z)


# --- Stealth stimulus (S4.1, S6.3, S10.1) -------------------------------------------------------

func _update_stimulus() -> void:
	if not Net.is_authority() or not is_inside_tree():
		return
	var want: bool = not secured and not is_carried()
	var kind: StringName = &"body_bag" if is_body_bag() else &"bag"
	if _stim_id != 0 and (not want or kind != _stim_kind):
		_unregister_stimulus()
	if want and _stim_id == 0:
		var st: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
		if st != null:
			_stim_id = st.register_stimulus(self, kind)
			_stim_kind = kind


func _unregister_stimulus() -> void:
	if _stim_id == 0:
		return
	var st: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	if st != null:
		st.unregister_stimulus(_stim_id)
	_stim_id = 0


## Current stimulus id (0 while carried/secured). Tests and debug.
func stimulus_id() -> int:
	return _stim_id
