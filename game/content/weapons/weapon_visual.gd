## Assembles a weapon's visual: instances `WeaponDef.model` and attaches each equipped mod's model at
## the marker named for its ModType (contracts/data_schemas.md §Weapons, visual_slots.md). Owner: ENV B.
##
## Stock parts live in the base model as named children of their marker (`SightRail/StockSight`,
## `Magwell/StockMagazine`). Equipping the default mod of a slot keeps the stock part; any other mod of
## that type hides it and attaches the mod scene instead. Mod scenes may carry their own markers
## (a suppressor's `Muzzle`, a sight's `AimPoint`); `get_marker()` returns the outermost one, so ENV A
## can always ask for `Muzzle`/`AimPoint` and get the effective point.
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
## ModType -> stock part node (a child of the marker) hidden when a non-default mod is attached.
const STOCK_PART_FOR_MOD_TYPE: Dictionary = {
	Enums.ModType.SIGHT: &"StockSight",
	Enums.ModType.MAGAZINE: &"StockMagazine",
	Enums.ModType.BARREL: &"StockBarrel",
	Enums.ModType.GRIP: &"StockGrip",
	Enums.ModType.STOCK: &"StockStock",
}
const MOD_NODE_PREFIX: String = "Mod_"

var weapon: WeaponDef
var model: Node3D
## ModType -> attached mod scene instance (only non-default mods are instanced)
var attached: Dictionary = {}


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
	for t: int in attached:
		var inst: Node3D = attached[t]
		var own: Node3D = inst.find_child(String(marker), true, false) as Node3D
		if own != null:
			return own
	return get_base_marker(marker)


## All contract markers by name (effective, see get_marker).
func markers() -> Dictionary:
	var out: Dictionary = {}
	for m: StringName in MARKERS:
		out[m] = get_marker(m)
	return out


func stock_part(mod_type: Enums.ModType) -> Node3D:
	if not STOCK_PART_FOR_MOD_TYPE.has(mod_type) or not MARKER_FOR_MOD_TYPE.has(mod_type):
		return null
	var marker: Node3D = get_base_marker(MARKER_FOR_MOD_TYPE[mod_type])
	if marker == null:
		return null
	return marker.get_node_or_null(NodePath(String(STOCK_PART_FOR_MOD_TYPE[mod_type]))) as Node3D


func _equip(mod: WeaponModDef) -> void:
	var t: Enums.ModType = mod.mod_type
	var is_default: bool = weapon.default_mods.get(t, &"") == mod.id
	if is_default:
		return  # the stock part in the base model already shows it
	if not MARKER_FOR_MOD_TYPE.has(t):
		return  # model swap / material mods: decided per weapon, none on the P9 yet
	var marker: Node3D = get_base_marker(MARKER_FOR_MOD_TYPE[t])
	if marker == null:
		push_warning("WeaponVisual: %s has no marker %s for %s" % [weapon.id, MARKER_FOR_MOD_TYPE[t], mod.id])
		return
	if attached.has(t):
		var old: Node3D = attached[t]
		old.get_parent().remove_child(old)
		old.free()
		attached.erase(t)
	var stock: Node3D = stock_part(t)
	if stock != null:
		stock.visible = false
	if mod.model == null:
		return
	var inst: Node3D = mod.model.instantiate() as Node3D
	inst.name = StringName(MOD_NODE_PREFIX + String(mod.id).replace(".", "_"))
	marker.add_child(inst)
	attached[t] = inst
