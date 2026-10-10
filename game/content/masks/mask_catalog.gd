## Mask lookup for every env (pd2_fidelity P8). Owner: ENV B. Static; caches on first use.
## Design: content/docs/masks.md.
##
## Mask ids in Loadout.mask:
##   `mask.<name>`       a preset MaskDef file in content/data/masks/ (ContentDB `masks`).
##   `mask.custom.<n>`   the player's custom slot n (PlayerProfile.custom_masks[n], a composition).
## A composition is `{"base": id, "material": id, "colors": id, "pattern": id}` (part ids, Strings).
##
## ENV A: `MaskCatalog.resolve(loadout.mask, profile) -> MaskDef` on the owning peer, or (for every
## other peer) send `descriptor(loadout.mask, profile)` (ids only) and call `from_descriptor(d)`.
## Then `MaskComposer.instantiate(def) -> Node3D` gives the visual (model or placeholder, material
## applied), pivot at the face centre, -Z forward, for the `Head` attachment (characters.md).
class_name MaskCatalog
extends RefCounted

const DATA_DIR: String = "res://content/data/masks"
const TWEAK_PATH: String = "res://content/data/masks/mask_tweak.tres"
const CUSTOM_PREFIX: String = "mask.custom."
## Composition keys = part kinds, in UI order.
const BASE: String = "base"
const MATERIAL: String = "material"
const COLORS: String = "colors"
const PATTERN: String = "pattern"
const KINDS: Array[String] = [BASE, MATERIAL, COLORS, PATTERN]
## kind -> part list file / id prefix.
const PART_FILES: Dictionary = {
	"base": "res://content/data/masks/parts/bases.tres",
	"material": "res://content/data/masks/parts/materials.tres",
	"colors": "res://content/data/masks/parts/colors.tres",
	"pattern": "res://content/data/masks/parts/patterns.tres",
}
const ID_PREFIX: Dictionary = {
	"base": "mask_base.", "material": "mask_material.", "colors": "mask_colors.", "pattern": "mask_pattern.",
}
const LOG_CHANNEL: StringName = &"masks"

## kind -> Array[MaskPartDef] (file order)
static var _lists: Dictionary = {}
## id -> MaskPartDef
static var _by_id: Dictionary = {}
static var _tweak: MaskTweak


static func tweak() -> MaskTweak:
	if _tweak == null:
		_tweak = load(TWEAK_PATH) as MaskTweak
		if _tweak == null:
			Log.error(LOG_CHANNEL, "missing %s" % TWEAK_PATH)
			_tweak = MaskTweak.new()
	return _tweak


## Parts of one kind (BASE / MATERIAL / COLORS / PATTERN) in data order.
static func parts(kind: String) -> Array[MaskPartDef]:
	_ensure()
	var out: Array[MaskPartDef] = []
	out.assign(_lists.get(kind, []))
	return out


## Part by id (any kind); null + Log.error when unknown.
static func part(id: StringName) -> MaskPartDef:
	_ensure()
	if not _by_id.has(id):
		Log.error(LOG_CHANNEL, "unknown mask part '%s'" % id)
		return null
	return _by_id[id]


static func has_part(id: StringName) -> bool:
	_ensure()
	return _by_id.has(id)


## Kind of a part id from its prefix ("" when it is not a part id).
static func kind_of(id: StringName) -> String:
	for k: String in KINDS:
		if String(id).begins_with(String(ID_PREFIX[k])):
			return k
	return ""


## The mask material wrapping library material `material_id` (MaskDef.material_id), or null.
static func material_for(material_id: StringName) -> MaskMaterialDef:
	for p: MaskPartDef in parts(MATERIAL):
		if (p as MaskMaterialDef).material_id == material_id:
			return p as MaskMaterialDef
	return null


## Preset MaskDefs (ContentDB `masks`), sorted by id.
static func presets() -> Array[MaskDef]:
	var out: Array[MaskDef] = []
	for r: Resource in ContentDB.all_of(ContentDB.MASKS):
		if r is MaskDef:
			out.append(r as MaskDef)
	return out


static func is_custom_id(mask_id: StringName) -> bool:
	return String(mask_id).begins_with(CUSTOM_PREFIX)


static func custom_id(index: int) -> StringName:
	return StringName(CUSTOM_PREFIX + str(index))


## Slot index of `mask.custom.<n>`; -1 for anything else.
static func custom_index(mask_id: StringName) -> int:
	if not is_custom_id(mask_id):
		return -1
	var tail: String = String(mask_id).substr(CUSTOM_PREFIX.length())
	return int(tail) if tail.is_valid_int() and int(tail) >= 0 else -1


## THE lookup: Loadout.mask -> MaskDef. "" -> null (no mask, no error). Preset ids go through
## ContentDB; custom ids are composed from `profile.custom_masks` (null when the slot is empty or
## `profile` is null). Unknown ids -> Log.error + null. A fresh MaskDef per custom call.
static func resolve(mask_id: StringName, profile: PlayerProfile) -> MaskDef:
	if mask_id == &"":
		return null
	if is_custom_id(mask_id):
		var comp: Dictionary = MaskLocker.custom_composition(profile, custom_index(mask_id))
		if comp.is_empty():
			Log.error(LOG_CHANNEL, "custom mask '%s' is empty or has no profile" % mask_id)
			return null
		return MaskComposer.compose(comp, mask_id)
	return ContentDB.mask(mask_id) as MaskDef


## Net/replication-safe description of an equipped mask (ids only, JSON friendly):
## `{"preset": "mask.x"}` or `{"id": "mask.custom.n", "base": ..., "material": ..., "colors": ...,
## "pattern": ...}`. Empty dict for no mask / unresolvable.
static func descriptor(mask_id: StringName, profile: PlayerProfile) -> Dictionary:
	if mask_id == &"":
		return {}
	if not is_custom_id(mask_id):
		return {"preset": String(mask_id)} if ContentDB.mask(mask_id) is MaskDef else {}
	var comp: Dictionary = MaskLocker.custom_composition(profile, custom_index(mask_id))
	if comp.is_empty():
		return {}
	comp["id"] = String(mask_id)
	return comp


## MaskDef from descriptor() output (any peer, no profile needed). Empty/invalid -> null.
static func from_descriptor(d: Dictionary) -> MaskDef:
	if d.is_empty():
		return null
	if d.has("preset"):
		return ContentDB.mask(StringName(String(d["preset"]))) as MaskDef
	return MaskComposer.compose(d, StringName(String(d.get("id", CUSTOM_PREFIX + "0"))))


## UI name of a mask id: preset `item.<id>.name`, custom slot `ui.masks.custom_slot` (n is 1-based).
static func display_name(mask_id: StringName) -> String:
	if is_custom_id(mask_id):
		return UiText.t(&"ui.masks.custom_slot", {"n": custom_index(mask_id) + 1})
	return UiText.t(UiText.item_key(mask_id))


## UI name of a part id (`item.<id>.name`).
static func part_name(id: StringName) -> String:
	return UiText.t(UiText.item_key(id))


## Drop caches (tests, hot reload).
static func clear_cache() -> void:
	_lists.clear()
	_by_id.clear()
	_tweak = null


static func _ensure() -> void:
	if not _lists.is_empty():
		return
	for k: String in KINDS:
		var list: Array[MaskPartDef] = []
		var res: MaskPartList = load(String(PART_FILES[k])) as MaskPartList
		if res == null:
			Log.error(LOG_CHANNEL, "missing part list %s" % PART_FILES[k])
		else:
			for p: MaskPartDef in res.entries:
				if p == null or p.id == &"":
					continue
				if kind_of(p.id) != k:
					Log.error(LOG_CHANNEL, "part '%s' in %s has the wrong prefix" % [p.id, PART_FILES[k]])
					continue
				if _by_id.has(p.id):
					Log.error(LOG_CHANNEL, "duplicate mask part '%s'" % p.id)
					continue
				_by_id[p.id] = p
				list.append(p)
		_lists[k] = list
