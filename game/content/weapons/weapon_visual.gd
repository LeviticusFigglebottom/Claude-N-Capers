## Assembles a weapon's visual: instances `WeaponDef.model` and attaches each equipped mod's model at
## the marker named for its ModType (contracts/data_schemas.md §Weapons, visual_slots.md). Owner: ENV B.
##
## Stock parts live in the base model as named children of their marker (`SightRail/StockSight`,
## `Magwell/StockMagazine`). Equipping the default mod of a slot keeps the stock part; any other mod of
## that type hides it and attaches the mod scene instead. Mod scenes may carry their own markers
## (a suppressor's `Muzzle`, a sight's `AimPoint`); `get_marker()` returns the outermost one, so ENV A
## can always ask for `Muzzle`/`AimPoint` and get the effective point.
##
## Akimbo (B4-12, D-050): a model with an `Offhand` marker is one gun of a pair. The visual instances the
## same model a second time as `offhand` (a sibling of `model`, placed at the marker's rest pose) and
## mirrors every mod onto it, so both guns show the same kit. `get_offhand_marker()` is the offhand's
## `get_marker()`. ENV A may reparent `offhand` to the left hand of the `akimbo` viewmodel set.
## Visual only: no gameplay, no collision.
class_name WeaponVisual
extends Node3D

## Contract markers every weapon model carries (visual_slots.md).
const MARKERS: Array[StringName] = [
	&"Muzzle", &"Eject", &"SightRail", &"Magwell", &"Underbarrel", &"SideRail", &"StockMount",
	&"GripMount", &"BarrelMount", &"LeftHandIK",
]
## Optional markers that mods may override (ADS alignment point).
const AIM_POINT: StringName = &"AimPoint"
## ModType -> marker name (data_schemas.md §Weapons). BOLT/BODY/AMMO/CHARM/SKIN have no marker.
const MARKER_FOR_MOD_TYPE: Dictionary = {
	Enums.ModType.BARREL: &"BarrelMount",
	Enums.ModType.BARREL_EXT: &"Muzzle",
	Enums.ModType.SUPPRESSOR: &"Muzzle",
	Enums.ModType.SIGHT: &"SightRail",
	Enums.ModType.GADGET: &"SideRail",
	Enums.ModType.GRIP: &"GripMount",
	Enums.ModType.FOREGRIP: &"Underbarrel",
	Enums.ModType.STOCK: &"StockMount",
	Enums.ModType.MAGAZINE: &"Magwell",
}
const MOD_NODE_PREFIX: String = "Mod_"
## Marker in an akimbo model: rest pose of the second (left-hand) gun relative to the first.
const OFFHAND_MARKER: StringName = &"Offhand"

var weapon: WeaponDef
var model: Node3D
## ModType -> attached mod scene instance (only non-default mods are instanced)
var attached: Dictionary = {}
## Akimbo only: the second gun (same model) and its attached mods (ModType -> instance).
var offhand: Node3D
var attached_offhand: Dictionary = {}


## Build the visual for `def` with `mods` equipped (missing slots use the stock parts).
func setup(def: WeaponDef, mods: Array[WeaponModDef]) -> void:
	clear()
	weapon = def
	if def == null or def.model == null:
		push_warning("WeaponVisual: %s has no model" % (def.id if def != null else &"<null>"))
		return
	model = def.model.instantiate() as Node3D
	model.name = &"Model"
	add_child(model)
	var hand: Node3D = model.find_child(String(OFFHAND_MARKER), true, false) as Node3D
	if hand != null:
		offhand = def.model.instantiate() as Node3D
		offhand.name = &"OffhandModel"
		add_child(offhand)
		offhand.transform = model.transform * _transform_to(model, hand)
	for mod: WeaponModDef in mods:
		if mod != null:
			_equip(mod)


## Convenience: resolve ids through ContentDB.
func setup_ids(weapon_id: StringName, mod_ids: Array[StringName]) -> void:
	var mods: Array[WeaponModDef] = []
	for id: StringName in mod_ids:
		var m: WeaponModDef = ContentDB.mod(id)
		if m != null:
			mods.append(m)
	setup(ContentDB.weapon(weapon_id), mods)


func clear() -> void:
	attached.clear()
	attached_offhand.clear()
	if offhand != null:
		remove_child(offhand)
		offhand.free()
	offhand = null
	if model != null:
		remove_child(model)
		model.free()
	model = null
	weapon = null


## Base-model marker by name (null if absent).
func get_base_marker(marker: StringName) -> Node3D:
	if model == null:
		return null
	return model.find_child(String(marker), true, false) as Node3D


## Effective marker: an attached mod's own marker of that name wins (e.g. the suppressor's `Muzzle`,
## a reflex sight's `AimPoint`), else the base model's.
func get_marker(marker: StringName) -> Node3D:
	return _effective_marker(model, attached, marker)


## Akimbo: the offhand gun's effective marker (null when the weapon is not a pair).
func get_offhand_marker(marker: StringName) -> Node3D:
	return _effective_marker(offhand, attached_offhand, marker)


func is_akimbo() -> bool:
	return offhand != null


func _effective_marker(root: Node3D, mods: Dictionary, marker: StringName) -> Node3D:
	if root == null:
		return null
	for t: int in mods:
		var inst: Node3D = mods[t]
		var own: Node3D = inst.find_child(String(marker), true, false) as Node3D
		if own != null:
			return own
	return root.find_child(String(marker), true, false) as Node3D


## All contract markers by name (effective, see get_marker).
func markers() -> Dictionary:
	var out: Dictionary = {}
	for m: StringName in MARKERS:
		out[m] = get_marker(m)
	return out


## Stock (default) part name for a ModType, data_schemas.md §Weapons: `Stock<ModType>` in PascalCase
## (SIGHT -> `StockSight`, BARREL_EXT -> `StockBarrelExt`, STOCK -> `StockStock`).
static func stock_part_name(mod_type: Enums.ModType) -> StringName:
	return StringName("Stock" + String(Enums.ModType.keys()[mod_type]).to_lower().to_pascal_case())


## The stock part hidden when a non-default mod of `mod_type` is attached: preferably a child of the
## slot's marker (`SightRail/StockSight`), else anywhere in the base model; null when the model has none.
func stock_part(mod_type: Enums.ModType) -> Node3D:
	return _stock_part_in(model, mod_type)


## Akimbo: the offhand gun's stock part (null when the weapon is not a pair).
func offhand_stock_part(mod_type: Enums.ModType) -> Node3D:
	return _stock_part_in(offhand, mod_type)


func _stock_part_in(root: Node3D, mod_type: Enums.ModType) -> Node3D:
	if root == null:
		return null
	var part_name: String = String(stock_part_name(mod_type))
	if MARKER_FOR_MOD_TYPE.has(mod_type):
		var marker: Node3D = root.find_child(String(MARKER_FOR_MOD_TYPE[mod_type]), true, false) as Node3D
		if marker != null and marker.has_node(NodePath(part_name)):
			return marker.get_node(NodePath(part_name)) as Node3D
	return root.find_child(part_name, true, false) as Node3D


func _equip(mod: WeaponModDef) -> void:
	var t: Enums.ModType = mod.mod_type
	var is_default: bool = weapon.default_mods.get(t, &"") == mod.id
	if is_default:
		return  # the stock part in the base model already shows it
	if not MARKER_FOR_MOD_TYPE.has(t):
		return  # model swap / material mods: decided per weapon, none on the P9 yet
	if get_base_marker(MARKER_FOR_MOD_TYPE[t]) == null:
		push_warning("WeaponVisual: %s has no marker %s for %s" % [weapon.id, MARKER_FOR_MOD_TYPE[t], mod.id])
		return
	_attach(model, attached, mod)
	if offhand != null:
		_attach(offhand, attached_offhand, mod)


## Attach `mod` to one gun (`root`), replacing an earlier mod of its type and hiding the stock part.
func _attach(root: Node3D, mods: Dictionary, mod: WeaponModDef) -> void:
	var t: Enums.ModType = mod.mod_type
	var marker: Node3D = root.find_child(String(MARKER_FOR_MOD_TYPE[t]), true, false) as Node3D
	if mods.has(t):
		var old: Node3D = mods[t]
		old.get_parent().remove_child(old)
		old.free()
		mods.erase(t)
	var stock: Node3D = _stock_part_in(root, t)
	if stock != null:
		stock.visible = false
	if mod.model == null:
		return
	var inst: Node3D = mod.model.instantiate() as Node3D
	inst.name = StringName(MOD_NODE_PREFIX + String(mod.id).replace(".", "_"))
	marker.add_child(inst)
	mods[t] = inst


## Transform of `node` relative to its ancestor `root`.
static func _transform_to(root: Node3D, node: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
