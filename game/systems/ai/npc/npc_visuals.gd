## PO-5.7 (D-089): resolves an NPC's character visual when neither the NPC scene nor its EnemyDef sets one,
## so police, specials, guards and civilians wear ENV D's characters instead of placeholder capsules.
## Order: EnemyDef id (`enemy.<id>` -> character <id>, faction variant from params.visual_variant,
## characters.md v1.6) -> SpawnPoint tag (NpcVisualTweak.tag_characters) -> role (role_characters).
## The pick among several ids hashes the NPC's node name (replicated), so every peer shows the same look.
## Missing scenes fall through (the capsule stays). Owner: ENV A.
class_name NpcVisuals
extends RefCounted

const TWEAK_PATH: String = "res://systems/ai/npc/npc_visual_tweak.tres"
const CHAR_DIR: String = G.CHARACTERS_DIR  # LEAD: contract path (characters.md), not a hard path into ENV D

static var _tweak: NpcVisualTweak = null
static var _cache: Dictionary[String, PackedScene] = {}


static func tweak() -> NpcVisualTweak:
	if _tweak == null:
		_tweak = load(TWEAK_PATH) as NpcVisualTweak
	return _tweak


## The character scene path for `char_id` in faction `variant` (&"" / &"tac" = base), as character_spec.gd.
static func scene_path(char_id: String, variant: String = "") -> String:
	var cid: String = char_id if variant.is_empty() or variant == "tac" else "%s_%s" % [char_id, variant]
	return "%s%s/%s.tscn" % [CHAR_DIR, cid, cid]


static func resolve(npc: NpcBase) -> PackedScene:
	var def: EnemyDef = npc.enemy_def
	if def != null and def.is_special:
		return null  # specials (shield grip, Wrecker plates...) need their own visual pass: scene visual stays
	if def != null and String(def.id).begins_with("enemy."):
		var cid: String = String(def.id).substr(6)
		var variant: String = String(def.params.get("visual_variant", ""))
		for path: String in [scene_path(cid, variant), scene_path(cid)]:
			var ps: PackedScene = _load(path)
			if ps != null:
				return ps
	var tw: NpcVisualTweak = tweak()
	if tw == null:
		return null
	var tags: Variant = npc.spawn_info.get("tags", [])
	if tags is Array:
		for t: Variant in tags as Array:
			if tw.tag_characters.has(StringName(t)):
				var ps2: PackedScene = _pick(npc, tw.tag_characters[StringName(t)])
				if ps2 != null:
					return ps2
	if tw.role_characters.has(npc.role):
		return _pick(npc, tw.role_characters[npc.role])
	return null


static func _pick(npc: NpcBase, ids: Variant) -> PackedScene:
	if not (ids is Array) or (ids as Array).is_empty():
		return null
	var arr: Array = ids as Array
	var i: int = absi(hash(String(npc.name))) % arr.size()
	return _load(scene_path(String(arr[i])))


static func _load(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_cache[path] = ps
	return ps
