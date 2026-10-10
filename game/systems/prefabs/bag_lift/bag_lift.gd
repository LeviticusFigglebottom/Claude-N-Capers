## Cash / bag lift between floors (QC-11, D-040; "a vertical zipline"). Owner: ENV A.
## Landings: landing 0 is this prefab's own transform (where the car starts), landings 1..n are the
## `targets` Node3Ds (Marker3Ds placed at the car floor of each other floor, -Z = the car front).
## Visual nodes: `Car` (moves between landings; its rest transform relative to the prefab is the car
## transform at every landing), `DoorL` / `DoorR` (car doors; slide apart along their local X by
## InteractionTweak.bag_lift_door_open_m while the car stands at a landing), `Panel` (the call /
## send panel beside the car; copied to every landing).
## Interaction: one panel per landing. `Interactable` is landing 0's panel; landings 1..n get runtime
## InteractableComponents `LandingPanel<i>` (direct children, so explicit targets find them).
## Hold (bag_lift_send_s) at the landing where the car stands = kind &"send_lift": the car goes to
## the next landing ((i + 1) % count). At another landing = kind &"call_lift": the car comes there.
## Blocked while moving (BLOCK_STATE) and while more than `capacity` bags are in the car
## (BLOCK_LIFT_FULL). Bags in the car (not carried, origin inside the `car_size_m` box of the car)
## ride with it: frozen, without collision and not pick-up-able for `travel_s`, then released in
## place when the doors open (a SECURE_LOOT zone in the car at the far landing secures them as usual).
## Server-authoritative. Cues: cue.bag_lift_start (doors close, car leaves), cue.bag_lift_arrive.
## P2 limitation: clients do not see the car move (no replicated car state yet).
class_name BagLift
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/bag_lift/bag_lift_placeholder.tscn")
const BLOCK_LIFT_FULL: StringName = &"ui.blocked.lift_full"
const PANEL_PREFIX: String = "LandingPanel"

## Other landings (Node3D markers at the car floor), in order. Landing 0 = this prefab.
@export var targets: Array[NodePath] = []
## Seconds per trip between two landings.
@export var travel_s: float = 8.0
## Bags per trip.
@export var capacity: int = 2
## Inside of the car (m): x width, y height, z depth, centred on the car's origin (floor).
@export var car_size_m: Vector3 = Vector3(1.2, 1.2, 1.2)
@export_group("Interaction")
## -1 = InteractionTweak.bag_lift_send_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

## Landing the car stands at (or left from while moving).
var landing: int = 0
## Landing the car is travelling to, -1 while it stands.
var destination: int = -1
## 0..1 progress of the current trip.
var trip_t: float = 0.0
## Bags riding: [{ "bag": LootBag, "offset": Transform3D (car space) }].
var riding: Array[Dictionary] = []
## Panel per landing (index = landing).
var panels: Array[InteractableComponent] = []

var _car: Node3D = null
var _car_local: Transform3D = Transform3D.IDENTITY
var _door_l: Node3D = null
var _door_r: Node3D = null
var _door_l_rest: Vector3 = Vector3.ZERO
var _door_r_rest: Vector3 = Vector3.ZERO
var _car_body: AnimatableBody3D = null


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Car", "DoorL", "DoorR", "Panel"])


func _default_interaction_time() -> float:
	return Tweak.interaction().bag_lift_send_s


func _prefab_ready() -> void:
	_car = visual_node("Car") as Node3D
	if _car != null:
		_car_local = global_transform.affine_inverse() * _car.global_transform
	_door_l = visual_node("DoorL") as Node3D
	_door_r = visual_node("DoorR") as Node3D
	if _door_l != null:
		_door_l_rest = _door_l.position
	if _door_r != null:
		_door_r_rest = _door_r.position
	_car_body = get_node_or_null(^"CarBody") as AnimatableBody3D
	if targets.is_empty():
		Log.error(LOG_CHANNEL, "%s: bag_lift needs at least one landing in `targets`" % name)
	panels = [interactable]
	_setup_panel(interactable, 0)
	_spawn_landing_panels.call_deferred()
	_place_car(landing_transform(landing))
	_set_doors(true)


## Number of landings (this prefab + targets).
func landing_count() -> int:
	return 1 + targets.size()


## World transform of landing `i` (0 = this prefab), car floor at its origin.
func landing_transform(i: int) -> Transform3D:
	if i <= 0 or i > targets.size():
		return global_transform
	var n: Node3D = get_node_or_null(targets[i - 1]) as Node3D
	return n.global_transform if n != null else global_transform


## Car transform (world) while standing at landing `i`.
func car_transform_at(i: int) -> Transform3D:
	return landing_transform(i) * _car_local


## Current car transform (world).
func car_transform() -> Transform3D:
	if destination < 0:
		return car_transform_at(landing)
	return car_transform_at(landing).interpolate_with(car_transform_at(destination), clampf(trip_t, 0.0, 1.0))


func is_moving() -> bool:
	return destination >= 0


## Seconds until the car arrives (0 while standing).
func travel_left() -> float:
	return maxf(1.0 - trip_t, 0.0) * maxf(travel_s, 0.0) if is_moving() else 0.0


## Bags lying in the car now (not carried, not secured), by net_id.
func bags_in_car() -> Array[LootBag]:
	var out: Array[LootBag] = []
	var inv: Transform3D = car_transform().affine_inverse()
	var h: Vector3 = car_size_m * 0.5
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b == null or b.is_queued_for_deletion() or b.secured or b.is_carried():
			continue
		var p: Vector3 = inv * b.global_position
		if absf(p.x) <= h.x and absf(p.z) <= h.z and p.y >= -0.15 and p.y <= car_size_m.y:
			out.append(b)
	out.sort_custom(func(a: LootBag, b: LootBag) -> bool: return a.net_id < b.net_id)
	return out


## Server: move the car (with the bags in it) to landing `to`. Returns false when not possible.
func send(to: int, by_slot: int = -1) -> bool:
	if not Net.is_authority() or is_moving() or to < 0 or to >= landing_count() or to == landing:
		return false
	var bags: Array[LootBag] = bags_in_car()
	if bags.size() > capacity:
		return false
	var car_inv: Transform3D = car_transform().affine_inverse()
	riding.clear()
	for b: LootBag in bags:
		riding.append({"bag": b, "offset": car_inv * b.global_transform})
		_hang(b)
	destination = to
	trip_t = 0.0
	_set_doors(false)
	_cue(&"cue.bag_lift_start", car_transform().origin)
	Log.info(LOG_CHANNEL, "%s: lift %d -> %d with %d bag(s) (slot %d)" % [name, landing, to, riding.size(), by_slot])
	if travel_s <= 0.0:
		_arrive()
	return true


func _physics_process(delta: float) -> void:
	if not is_moving() or not Net.is_authority():
		return
	trip_t = minf(trip_t + delta / maxf(travel_s, 0.01), 1.0)
	var xf: Transform3D = car_transform()
	_place_car(xf)
	for r: Dictionary in riding:
		var raw: Variant = r["bag"]
		var bag: LootBag = raw as LootBag if is_instance_valid(raw) else null
		if bag == null or bag.is_carried() or bag.secured:
			continue
		bag.global_transform = xf * (r["offset"] as Transform3D)
		bag.rest_time = 0.0
	if trip_t >= 1.0:
		_arrive()


func _arrive() -> void:
	landing = destination
	destination = -1
	trip_t = 0.0
	var xf: Transform3D = car_transform()
	_place_car(xf)
	for r: Dictionary in riding:
		var raw: Variant = r["bag"]
		var bag: LootBag = raw as LootBag if is_instance_valid(raw) else null
		if bag == null or bag.is_carried() or bag.secured:
			continue
		var at: Transform3D = xf * (r["offset"] as Transform3D)
		bag.release(at.origin, Vector3.ZERO, false)
	riding.clear()
	_set_doors(true)
	_cue(&"cue.bag_lift_arrive", xf.origin)


func _setup_panel(p: InteractableComponent, i: int) -> void:
	if p == null:
		return
	p.kind = &"send_lift"
	p.prompt_key = &"ui.prompt.send_lift"
	p.extra_check = _availability.bind(i)
	p.completed.connect(_on_panel_completed.bind(i))


## Landings 1..n get a copy of landing 0's panel (same offset from the landing).
func _spawn_landing_panels() -> void:
	if interactable == null:
		return
	var rel: Transform3D = global_transform.affine_inverse() * interactable.global_transform
	for i: int in range(1, landing_count()):
		var p: InteractableComponent = InteractableComponent.new()
		p.name = "%s%d" % [PANEL_PREFIX, i]
		p.interaction_time_s = interactable.interaction_time_s
		p.requires_item = interactable.requires_item
		p.stealth_only = interactable.stealth_only
		p.loud_only = interactable.loud_only
		p.casing_allowed = interactable.casing_allowed
		p.noise = interactable.noise
		add_child(p)
		p.global_transform = landing_transform(i) * rel
		_setup_panel(p, i)
		panels.append(p)
	_refresh_panels()


func _availability(_crew: Node, _i: int) -> StringName:
	if landing_count() < 2 or is_moving():
		return InteractableComponent.BLOCK_STATE
	if bags_in_car().size() > capacity:
		return BLOCK_LIFT_FULL
	return InteractableComponent.BLOCK_NONE


func _on_panel_completed(crew: Node, i: int) -> void:
	if not Net.is_authority():
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	if i == landing:
		send((landing + 1) % landing_count(), slot)
	else:
		send(i, slot)
	_refresh_panels()


## Panel kinds follow the car: "send" where it stands, "call" elsewhere.
func _refresh_panels() -> void:
	for i: int in range(panels.size()):
		var p: InteractableComponent = panels[i]
		if p == null:
			continue
		var here: bool = i == landing and not is_moving()
		p.kind = &"send_lift" if here else &"call_lift"
		p.prompt_key = &"ui.prompt.send_lift" if here else &"ui.prompt.call_lift"


func _place_car(xf: Transform3D) -> void:
	if _car != null:
		_car.global_transform = xf
	if _car_body != null:
		_car_body.global_transform = xf


func _set_doors(open: bool) -> void:
	var d: float = Tweak.interaction().bag_lift_door_open_m if open else 0.0
	if _door_l != null:
		_door_l.position = _door_l_rest + Vector3(-d, 0.0, 0.0)
	if _door_r != null:
		_door_r.position = _door_r_rest + Vector3(d, 0.0, 0.0)
	_refresh_panels()


## Frozen, no collision, not pick-up-able while riding.
func _hang(bag: LootBag) -> void:
	bag.freeze = true
	bag.collision_layer = 0
	bag.collision_mask = 0
	bag.linear_velocity = Vector3.ZERO
	bag.angular_velocity = Vector3.ZERO
	if bag.interactable != null:
		bag.interactable.enabled = false
