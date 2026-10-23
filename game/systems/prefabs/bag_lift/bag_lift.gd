## Cash / bag lift between floors (QC-11, D-040; "a vertical zipline"). Owner: ENV A.
## Landings: landing 0 is this prefab's own transform (where the car starts), landings 1..n are the
## `targets` Node3Ds (Marker3Ds placed at the car floor of each other floor, -Z = the car front).
## Visual nodes: `Car` (moves between landings; its rest transform relative to the prefab is the car
## transform at every landing), `DoorL` / `DoorR` (car doors; slide apart along their local X by
## door_travel() while the car stands at a landing: `door_open_m`, else the tweak's fixed
## bag_lift_door_open_m, else car_size_m.x / 2 - bag_lift_door_margin_m, so car-sized shafts work;
## `door_fold` also folds the leaves to bag_lift_door_fold_scale of their width, outer edge fixed, so
## they never leave the car's side walls), optional `Panel` (the call / send panel).
## Panel: `panel_path`, else a `Panel` Node3D child of the prefab root, else the visual's `Panel`. An
## external panel (outside the car visual, e.g. a wall plate beside the shaft door) hides the visual's
## `Panel`, moves landing 0's Interactable onto it and (`copy_panel`) is duplicated at every other
## landing as `LandingPanelVisual<i>` (same offset from the landing).
## `CarBody` floor slab: resized to car_size_m (x, z) at ready.
## Shaft (`return_fallen_bags`): a loose bag inside the car's footprint column that falls more than
## bag_lift_fall_m below the car floor (thrown into the open shaft while the car is away, or lying
## where the car comes down) is put back in front of the landing where it entered the shaft.
## Interaction: one panel per landing. `Interactable` is landing 0's panel; landings 1..n get runtime
## InteractableComponents `LandingPanel<i>` (direct children, so explicit targets find them).
## Hold (bag_lift_send_s) at the landing where the car stands = kind &"send_lift": the car goes to
## the next landing ((i + 1) % count). At another landing = kind &"call_lift": the car comes there.
## LEAD r304 (PD2 freight lifts pick the floor): with 3+ landings every landing's panel instead offers one send per
## other landing (`LandingSend<i>_<j>`, stacked SEND_BUTTON_STEP_M apart up the panel, prompt send_prompt_key(j)),
## active while the car stands there; that landing's own panel is then only the "call".
## Blocked while moving (BLOCK_STATE) and while more than `capacity` bags are in the car
## (BLOCK_LIFT_FULL). Bags in the car (not carried, origin inside the `car_size_m` box of the car)
## ride with it: frozen, without collision and not pick-up-able for `travel_s`, then released in
## place when the doors open (a SECURE_LOOT zone in the car at the far landing secures them as usual).
## Server-authoritative. Cues: cue.bag_lift_start (doors close, car leaves), cue.bag_lift_arrive.
## Clients (OF co-op parity): `landing` / `destination` / `trip_t` arrive through NetEntityCodec's generic props;
## mirror_car() places the car and its doors from them (advancing trip_t locally between snapshots).
## OF-A2 (QC-61): GameplayPrefab `set_enabled` / `enabled_at_start` (a hoist installed mid-heist): disabled =
## hidden, CarBody and every panel off, the car does not run; an external panel (`panel_path` outside the
## prefab) is hidden with it. Disabling it mid-trip completes the trip at once (no bag stays frozen in the car).
class_name BagLift
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/bag_lift/bag_lift_placeholder.tscn")
const BLOCK_LIFT_FULL: StringName = &"ui.blocked.lift_full"
const PANEL_PREFIX: String = "LandingPanel"
const SEND_PREFIX: String = "LandingSend"
## Vertical spacing of a landing's per-destination send buttons (m).
const SEND_BUTTON_STEP_M: float = 0.14
## Fallback prompt of the send to landing j (when `send_prompt_keys` names none): "ui.prompt.send_lift_to_<j>".
const SEND_PROMPT_FALLBACK: String = "ui.prompt.send_lift_to_%d"

## Other landings (Node3D markers at the car floor), in order. Landing 0 = this prefab.
@export var targets: Array[NodePath] = []
## Seconds per trip between two landings.
@export var travel_s: float = 8.0
## Bags per trip.
@export var capacity: int = 2
## Inside of the car (m): x width, y height, z depth, centred on the car's origin (floor).
@export var car_size_m: Vector3 = Vector3(1.2, 1.2, 1.2)
## Door slide per leaf (m) when open. -1 = InteractionTweak.bag_lift_door_open_m when > 0, else
## car_size_m.x / 2 - bag_lift_door_margin_m.
@export var door_open_m: float = -1.0
## Doors also fold to bag_lift_door_fold_scale of their width (outer edge fixed) when open, so the
## leaves stay inside the car's side walls (tight shafts). The slide is then the fold distance.
@export var door_fold: bool = false
## Separate panel node outside the car visual (empty = a root `Panel` child, else the visual's).
@export var panel_path: NodePath = NodePath("")
## 3+ landings: the prompt key of the send to each landing, by landing index (e.g. ui.prompt.send_lift_roof).
@export var send_prompt_keys: Array[StringName] = []
## Duplicate an external panel at every other landing (LandingPanelVisual<i>).
@export var copy_panel: bool = true
## Loose bags that fall into the shaft are returned to the landing they fell in at.
@export var return_fallen_bags: bool = true
@export_group("Interaction")
## -1 = InteractionTweak.bag_lift_send_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
## Every panel's blocked reason while loud_only / stealth_only rules it out (InteractableComponent.phase_block_key).
@export var phase_block_key: StringName = &""
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

## RT goods_lift `lift_dead` (doc Variants): an unpowered lift stays in place and visible, but no panel works until
## the mission restores power (the plant-room breaker). Server sets it with set_powered(); mirrored to clients.
var powered: bool = true
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
## 3+ landings: landing -> {destination landing: its send button}.
var send_buttons: Dictionary = {}
## Panel mesh node (external or the visual's), or null.
var panel_node: Node3D = null
## True when the panel lives outside the car visual.
var panel_external: bool = false
## Bags put back after falling into the shaft (tests / debug).
var returned_bags: int = 0

var _car: Node3D = null
var _car_local: Transform3D = Transform3D.IDENTITY
var _door_l: Node3D = null
var _door_r: Node3D = null
var _door_l_rest: Vector3 = Vector3.ZERO
var _door_r_rest: Vector3 = Vector3.ZERO
var _car_body: AnimatableBody3D = null
var _shown_car: Transform3D = Transform3D()
var _shown_moving: bool = false
var _door_l_scale: Vector3 = Vector3.ONE
var _door_r_scale: Vector3 = Vector3.ONE
## Bag instance id -> landing it entered the shaft at.
var _shaft_landing: Dictionary = {}
var _shaft_check_left: float = 0.0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Car", "DoorL", "DoorR"])  # `Panel` is optional


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
		_door_l_scale = _door_l.scale
	if _door_r != null:
		_door_r_rest = _door_r.position
		_door_r_scale = _door_r.scale
	_car_body = get_node_or_null(^"CarBody") as AnimatableBody3D
	_fit_car_body()
	_resolve_panel()
	if targets.is_empty():
		Log.error(LOG_CHANNEL, "%s: bag_lift needs at least one landing in `targets`" % name)
	panels = [interactable]
	_setup_panel(interactable, 0)
	_spawn_landing_panels.call_deferred()
	_place_car(landing_transform(landing))
	_set_doors(true)


func _on_enabled_changed(on: bool) -> void:
	if panel_external and is_instance_valid(panel_node) and not is_ancestor_of(panel_node):
		panel_node.visible = on
	if not on and is_moving() and Net.is_authority():
		_arrive()


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


## Door slide per leaf (m) when open.
func door_travel() -> float:
	var tw: InteractionTweak = Tweak.interaction()
	if door_fold:
		return _leaf_width(_door_l) * 0.5 * (1.0 - clampf(tw.bag_lift_door_fold_scale, 0.0, 1.0))
	if door_open_m >= 0.0:
		return door_open_m
	if tw.bag_lift_door_open_m > 0.0:
		return tw.bag_lift_door_open_m
	return maxf(car_size_m.x * 0.5 - tw.bag_lift_door_margin_m, 0.0)


func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		mirror_car(delta)
		return
	if return_fallen_bags and landing_count() >= 2:
		_check_shaft(delta)
	if not is_moving():
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


## Client: show the replicated car state (landing, destination, trip_t). The server's snapshots overwrite trip_t;
## between them the trip runs on locally.
func mirror_car(delta: float = 0.0) -> void:
	if is_moving():
		trip_t = minf(trip_t + delta / maxf(travel_s, 0.01), 1.0)
	var xf: Transform3D = car_transform()
	var moving: bool = is_moving()
	if xf.is_equal_approx(_shown_car) and moving == _shown_moving:
		return
	_place_car(xf)
	if moving != _shown_moving:
		_set_doors(not moving)
	_shown_car = xf
	_shown_moving = moving


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
	var panel_rel: Transform3D = global_transform.affine_inverse() * panel_node.global_transform \
		if panel_external and copy_panel and is_instance_valid(panel_node) else Transform3D.IDENTITY
	for i: int in range(1, landing_count()):
		if panel_external and copy_panel and is_instance_valid(panel_node):
			var pv: Node3D = panel_node.duplicate() as Node3D
			pv.name = "LandingPanelVisual%d" % i
			add_child(pv)
			pv.global_transform = landing_transform(i) * panel_rel
		var p: InteractableComponent = InteractableComponent.new()
		p.name = "%s%d" % [PANEL_PREFIX, i]
		p.interaction_time_s = interactable.interaction_time_s
		p.requires_item = interactable.requires_item
		p.stealth_only = interactable.stealth_only
		p.loud_only = interactable.loud_only
		p.phase_block_key = interactable.phase_block_key
		p.casing_allowed = interactable.casing_allowed
		p.noise = interactable.noise
		add_child(p)
		p.global_transform = landing_transform(i) * rel
		_setup_panel(p, i)
		panels.append(p)
	if landing_count() > 2:
		for i2: int in range(landing_count()):
			_spawn_send_buttons(i2)
	_refresh_panels()


## 3+ landings: landing `i`'s panel gets one send button per other landing, stacked up from its own panel.
func _spawn_send_buttons(i: int) -> void:
	var base: InteractableComponent = panels[i] if i < panels.size() else null
	if base == null:
		return
	var row: Dictionary = {}
	var k: int = 0
	for j: int in range(landing_count()):
		if j == i:
			continue
		var b: InteractableComponent = InteractableComponent.new()
		b.name = "%s%d_%d" % [SEND_PREFIX, i, j]
		b.kind = &"send_lift"
		b.prompt_key = send_prompt_key(j)
		b.interaction_time_s = base.interaction_time_s
		b.requires_item = base.requires_item
		b.stealth_only = base.stealth_only
		b.loud_only = base.loud_only
		b.phase_block_key = base.phase_block_key
		b.casing_allowed = base.casing_allowed
		b.noise = base.noise
		add_child(b)
		b.global_transform = base.global_transform.translated(Vector3.UP * SEND_BUTTON_STEP_M * float(k + 1))
		b.extra_check = _send_availability.bind(i)
		b.completed.connect(_on_send_completed.bind(i, j))
		row[j] = b
		k += 1
	send_buttons[i] = row


## The prompt key of a send to landing `j` (send_prompt_keys, else SEND_PROMPT_FALLBACK).
func send_prompt_key(j: int) -> StringName:
	if j < send_prompt_keys.size() and send_prompt_keys[j] != &"":
		return send_prompt_keys[j]
	return StringName(SEND_PROMPT_FALLBACK % j)


func _send_availability(crew: Node, i: int) -> StringName:
	if i != landing:
		return InteractableComponent.BLOCK_STATE  # the car is not at this landing
	return _availability(crew, i)


func _on_send_completed(crew: Node, i: int, j: int) -> void:
	if not Net.is_authority() or i != landing:
		return
	send(j, int(crew.get(&"slot")) if crew != null else -1)
	_refresh_panels()


## Server: power the lift on or off (RT `lift_dead` / its breaker). A trip under way finishes.
func set_powered(on: bool) -> void:
	if Net.is_authority():
		powered = on


func _availability(_crew: Node, _i: int) -> StringName:
	if not powered:
		return InteractableComponent.BLOCK_DISABLED
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


## Panel kinds follow the car: "send" where it stands, "call" elsewhere. 3+ landings: the send buttons are on where
## the car stands and the landing's own panel (the call) is off there.
func _refresh_panels() -> void:
	var multi: bool = not send_buttons.is_empty()
	for i: int in range(panels.size()):
		var p: InteractableComponent = panels[i]
		if p == null:
			continue
		var here: bool = i == landing and not is_moving()
		p.kind = &"send_lift" if here else &"call_lift"
		p.prompt_key = &"ui.prompt.send_lift" if here else &"ui.prompt.call_lift"
		if multi:
			p.enabled = not here
			for b: Variant in (send_buttons.get(i, {}) as Dictionary).values():
				(b as InteractableComponent).enabled = here


func _place_car(xf: Transform3D) -> void:
	if _car != null:
		_car.global_transform = xf
	if _car_body != null:
		_car_body.global_transform = xf


func _set_doors(open: bool) -> void:
	var d: float = door_travel() if open else 0.0
	var fold: float = clampf(Tweak.interaction().bag_lift_door_fold_scale, 0.0, 1.0) if open and door_fold else 1.0
	if _door_l != null:
		_door_l.position = _door_l_rest + Vector3(-d, 0.0, 0.0)
		_door_l.scale = Vector3(_door_l_scale.x * maxf(fold, 0.001), _door_l_scale.y, _door_l_scale.z)
	if _door_r != null:
		_door_r.position = _door_r_rest + Vector3(d, 0.0, 0.0)
		_door_r.scale = Vector3(_door_r_scale.x * maxf(fold, 0.001), _door_r_scale.y, _door_r_scale.z)
	_refresh_panels()


## Leaf width (m, along its X) from its mesh, else half the car width.
func _leaf_width(door: Node3D) -> float:
	var mi: MeshInstance3D = door as MeshInstance3D
	if mi != null and mi.mesh != null:
		var w: float = mi.mesh.get_aabb().size.x * absf(_door_l_scale.x)
		if w > 0.001:
			return w
	return car_size_m.x * 0.5


## The CarBody floor slab follows car_size_m (x, z); its own shape resource per instance.
func _fit_car_body() -> void:
	if _car_body == null:
		return
	var cs: CollisionShape3D = _car_body.get_node_or_null(^"Shape") as CollisionShape3D
	if cs == null or not cs.shape is BoxShape3D:
		return
	var box: BoxShape3D = (cs.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size = Vector3(car_size_m.x, box.size.y, car_size_m.z)
	cs.shape = box
	cs.position = Vector3(0.0, -box.size.y * 0.5, 0.0)


## `panel_path`, else a root `Panel` child, else the visual's (optional) `Panel`.
func _resolve_panel() -> void:
	var ext: Node3D = null
	if not panel_path.is_empty():
		ext = get_node_or_null(panel_path) as Node3D
		if ext == null:
			Log.warn(LOG_CHANNEL, "%s: panel_path %s is not a Node3D" % [name, panel_path])
	if ext == null:
		ext = get_node_or_null(^"Panel") as Node3D
	var vis: Node3D = visual_node("Panel") as Node3D
	if ext == null or ext == vis:
		panel_node = vis
		panel_external = false
		return
	panel_node = ext
	panel_external = true
	if vis != null:
		vis.visible = false
	if interactable != null:
		interactable.global_position = ext.global_position


## Server: loose bags that fell into the shaft go back in front of the landing they entered at.
func _check_shaft(delta: float) -> void:
	_shaft_check_left -= delta
	if _shaft_check_left > 0.0:
		return
	var tw: InteractionTweak = Tweak.interaction()
	_shaft_check_left = tw.bag_lift_shaft_check_s
	var inv: Transform3D = car_transform().affine_inverse()
	var h: Vector3 = car_size_m * 0.5
	var lo: float = INF
	var hi: float = -INF
	for i: int in range(landing_count()):
		var y: float = car_transform_at(i).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	var seen: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b == null or b.is_queued_for_deletion() or b.secured or b.is_carried() or b.freeze \
				or b.container != null:
			continue
		var wy: float = b.global_position.y
		if wy < lo - tw.bag_lift_pit_depth_m or wy > hi + car_size_m.y:
			continue
		var p: Vector3 = inv * b.global_position
		if absf(p.x) > h.x or absf(p.z) > h.z or (p.y >= -0.15 and p.y <= car_size_m.y):
			continue
		var id: int = b.get_instance_id()
		seen[id] = true
		if not _shaft_landing.has(id):
			_shaft_landing[id] = _nearest_landing(b.global_position)
		if p.y < -tw.bag_lift_fall_m:
			_return_bag(b, int(_shaft_landing[id]))
			seen.erase(id)
	for k: Variant in _shaft_landing.keys():
		if not seen.has(k):
			_shaft_landing.erase(k)


func _nearest_landing(pos: Vector3) -> int:
	var best: int = 0
	var best_d: float = INF
	for i: int in range(landing_count()):
		var d: float = car_transform_at(i).origin.distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _return_bag(bag: LootBag, i: int) -> void:
	var front: float = car_size_m.z * 0.5 + Tweak.interaction().bag_lift_return_front_m
	var at: Vector3 = car_transform_at(i) * Vector3(0.0, 0.3, -front)
	bag.release(at, Vector3.ZERO, false)
	returned_bags += 1
	Log.info(LOG_CHANNEL, "%s: bag %d fell into the shaft, back at landing %d" % [name, bag.net_id, i])


## Frozen, no collision, not pick-up-able while riding.
func _hang(bag: LootBag) -> void:
	bag.freeze = true
	bag.collision_layer = 0
	bag.collision_mask = 0
	bag.linear_velocity = Vector3.ZERO
	bag.angular_velocity = Vector3.ZERO
	if bag.interactable != null:
		bag.interactable.enabled = false
