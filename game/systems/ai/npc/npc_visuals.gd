## PO-5.7 (D-089): resolves an NPC's character visual when neither the NPC scene nor its EnemyDef sets one,
## so police, specials, guards and civilians wear ENV D's characters instead of placeholder capsules.
## Order (D-103 §3b.1: the tag beats the EnemyDef): SpawnPoint tag (NpcVisualTweak.heist_tag_characters for this
## heist, then tag_characters) -> EnemyDef id (`enemy.<id>` -> character <id>, or NpcVisualTweak.enemy_characters;
## faction variant from params.visual_variant, characters.md v1.6) -> role (role_characters).
## The pick among several ids hashes the NPC's node name (replicated), so every peer shows the same look.
## Missing scenes fall through (the capsule stays). Owner: ENV A.
class_name NpcVisuals
extends RefCounted

const TWEAK_PATH: String = "res://systems/ai/npc/npc_visual_tweak.tres"
const CHAR_DIR: String = G.CHARACTERS_DIR  # LEAD: contract path (characters.md), not a hard path into ENV D

## TEST / PERF HOOK (A4-02): true = never resolve (NPCs keep their scene's placeholder capsule).
static var disabled: bool = false
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
	if disabled:
		return null
	var tw: NpcVisualTweak = tweak()
	var by_tag: PackedScene = _by_tag(npc, tw)
	if by_tag != null:
		return by_tag
	var def: EnemyDef = npc.enemy_def
	if def != null and String(def.id).begins_with("enemy."):
		var cid: String = String(def.id).substr(6)
		if tw != null and tw.enemy_characters.has(def.id):
			cid = String(tw.enemy_characters[def.id])
		var variant: String = String(def.params.get("visual_variant", ""))
		for path: String in [scene_path(cid, variant), scene_path(cid)]:
			var ps: PackedScene = _load(path)
			if ps != null:
				return ps
	if tw != null and tw.role_characters.has(npc.role):
		return _pick(npc, tw.role_characters[npc.role])
	return null


## Character scene paths an NPC with EnemyDef `def` may wear (faction variant first), existing ones only. For warm-up.
static func def_scene_paths(def: EnemyDef) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if def == null or not String(def.id).begins_with("enemy."):
		return out
	var cid: String = String(def.id).substr(6)
	var tw: NpcVisualTweak = tweak()
	if tw != null and tw.enemy_characters.has(def.id):
		cid = String(tw.enemy_characters[def.id])
	var variant: String = String(def.params.get("visual_variant", ""))
	for path: String in [scene_path(cid, variant), scene_path(cid)]:
		if not out.has(path) and ResourceLoader.exists(path):
			out.append(path)
	return out


## The first SpawnPoint tag with a character: this heist's map (heist_tag_characters) before the shared one.
static func _by_tag(npc: NpcBase, tw: NpcVisualTweak) -> PackedScene:
	var tags: Variant = npc.spawn_info.get("tags", [])
	if tw == null or not (tags is Array) or (tags as Array).is_empty():
		return null
	var maps: Array[Dictionary] = []
	var rt: HeistRuntime = HeistRuntime.of(npc)
	if rt != null and tw.heist_tag_characters.get(rt.heist_id) is Dictionary:
		maps.append(tw.heist_tag_characters[rt.heist_id] as Dictionary)
	maps.append(tw.tag_characters)
	for m: Dictionary in maps:
		for t: Variant in tags as Array:
			if m.has(StringName(t)):
				var ps: PackedScene = _pick(npc, m[StringName(t)])
				if ps != null:
					return ps
	return null


## A prop scene of the NPC's character visual (characters.md v1.6: `<dir>/<cid>_<prop>.tscn` beside
## `<dir>/<cid>.tscn`, e.g. the Bulwark shields `bulwark_<v>/bulwark_<v>_shield.tscn`), or null.
static func prop_scene(npc: NpcBase, prop: String) -> PackedScene:
	if npc == null or npc.visual_scene == null:
		return null
	var path: String = npc.visual_scene.resource_path
	if not path.begins_with(CHAR_DIR) or not path.ends_with(".tscn"):
		return null
	return _load("%s_%s.tscn" % [path.trim_suffix(".tscn"), prop])


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
