## Third-person look of NPC weapons (EnemyDef.weapon ids like &"weapon.npc_rifle" are gameplay ids with no WeaponDef):
## which armory WeaponDef's model an NPC carries. Data: res://content/data/npc/npc_weapon_models.tres. Owner: ENV B.
## ENV A's AnimDriver asks `NpcWeaponModels.weapon_def(id)` (by class name) when ContentDB has no WeaponDef for the id;
## an unmapped id (e.g. &"weapon.npc_melee_kick") stays empty-handed.
class_name NpcWeaponModels
extends Resource

const PATH: String = "res://content/data/npc/npc_weapon_models.tres"

static var _data: NpcWeaponModels = null

## NPC weapon id -> armory WeaponDef id whose model (stock parts) the NPC holds.
@export var models: Dictionary[StringName, StringName] = {}


static func data() -> NpcWeaponModels:
	if _data == null:
		_data = load(PATH) as NpcWeaponModels if ResourceLoader.exists(PATH) else NpcWeaponModels.new()
	return _data


## The WeaponDef whose model an NPC with weapon `npc_weapon_id` holds: the id itself when it is an armory weapon,
## else the mapped one; null when unmapped.
static func weapon_def(npc_weapon_id: StringName) -> WeaponDef:
	if npc_weapon_id == &"":
		return null
	var own: WeaponDef = ContentDB.weapon(npc_weapon_id)
	if own != null:
		return own
	var mapped: StringName = data().models.get(npc_weapon_id, &"")
	return ContentDB.weapon(mapped) if mapped != &"" else null
