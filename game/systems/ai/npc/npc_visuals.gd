## PO-5.7 (D-089): resolves an NPC's character visual when neither the NPC scene nor its EnemyDef sets one,
## so police, specials, guards and civilians wear ENV D's characters instead of placeholder capsules.
## Order (D-103 §3b.1: the tag beats the EnemyDef): SpawnPoint tag (NpcVisualTweak.heist_tag_characters for this
## heist, then tag_characters) -> EnemyDef id (`enemy.<id>` -> character <id>, or NpcVisualTweak.enemy_characters;
## faction variant from params.visual_variant, characters.md v1.6) -> role (role_characters).
## The pick among several ids (D-115 GN polish): the authority deals a tag's looks round-robin in spawn order from a
## per-run, per-tag offset (no twins while the tag's live count <= its looks), stores the index in
## spawn_info["look"] and replicates it with the spawn descriptor; without a heist it hashes the node name.
## Missing scenes fall through (the capsule stays). Owner: ENV A.
class_name NpcVisuals
extends RefCounted

const TWEAK_PATH: String = "res://systems/ai/npc/npc_visual_tweak.tres"
const CHAR_DIR: String = G.CHARACTERS_DIR  # LEAD: contract path (characters.md), not a hard path into ENV D

## TEST / PERF HOOK (A4-02): true = never resolve (NPCs keep their scene's placeholder capsule).
static var disabled: bool = false
static var _tweak: NpcVisualTweak = null
static var _cache: Dictionary[String, PackedScene] = {}
## Round-robin deal state: "<runtime iid>|<tag>" -> next count. Reset when a new run starts dealing.
static var _deal: Dictionary[String, int] = {}
static var _deal_run: int = 0
## ENV D cower_offsets.json `offsets` (character id -> m), loaded once; {} when the file is absent.
static var _cower_offsets: Variant = null


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
	var pools: Dictionary = tw.heist_tag_pools.get(rt.heist_id, {}) if rt != null else {}
	for m: Dictionary in maps:
		for t: Variant in tags as Array:
			if m.has(StringName(t)):
				var ps: PackedScene = _pick(npc, m[StringName(t)], String(pools.get(StringName(t), t)))
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


static func _pick(npc: NpcBase, ids: Variant, tag: String = "") -> PackedScene:
	if not (ids is Array) or (ids as Array).is_empty():
		return null
	# D-115: ids whose scene is not delivered yet (a cast entry ahead of ENV D's round) are skipped, not a miss.
	var arr: Array = []
	for id: Variant in ids as Array:
		if _load(scene_path(String(id))) != null:
			arr.append(id)
	if arr.is_empty():
		return null
	var i: int = look_index(npc, tag, arr.size())
	return _load(scene_path(String(arr[i])))


## The index among `n` looks: the replicated spawn_info["look"], else the authority's round-robin deal for `tag`
## (a tag, a shared pool, or an EnemyDef's alternates) in this run (stored in spawn_info["look"]), else a hash of
## the node name.
static func look_index(npc: NpcBase, tag: String, n: int) -> int:
	var look: int = int(npc.spawn_info.get("look", -1))
	if look >= 0:
		return look % n
	var rt: HeistRuntime = HeistRuntime.of(npc)
	if tag == "" or rt == null or not Net.is_authority() or bool(npc.spawn_info.get("replica", false)):
		return absi(hash(String(npc.name))) % n
	var run: int = rt.get_instance_id()
	if run != _deal_run:
		_deal.clear()
		_deal_run = run
	var key: String = "%d|%s" % [run, tag]
	var k: int = _deal.get(key, 0)
	_deal[key] = k + 1
	var i: int = (absi(hash("%d|%s" % [rt.run_seed, tag])) + k) % n
	npc.spawn_info["look"] = i
	return i


static func _load(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	# GN-8: WarmLoader, never beside the director's background loads of the same characters.
	var ps: PackedScene = WarmLoader.get_or_load(path) as PackedScene if ResourceLoader.exists(path) else null
	_cache[path] = ps
	return ps


## The character id an NPC wears (its visual scene's file name, characters.md layout), "" for a capsule.
static func character_id(npc: NpcBase) -> String:
	if npc == null or npc.visual_scene == null:
		return ""
	return npc.visual_scene.resource_path.get_file().get_basename()


## QC-67 (ENV D cower_offsets.json): how far (m) a look's root stands forward of a cower point so its back bag clears the
## wall (cower_stand wants the wall 0.21 m behind the root); 0 for looks not listed or without the file.
static func cower_offset(npc: NpcBase) -> float:
	if _cower_offsets == null:
		_cower_offsets = {}
		var path: String = CHAR_DIR + "cower_offsets.json"
		if FileAccess.file_exists(path):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				_cower_offsets = (data as Dictionary).get("offsets", {})
	return float((_cower_offsets as Dictionary).get(character_id(npc), 0.0))
