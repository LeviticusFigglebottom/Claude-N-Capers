## D-165 audit (LEAD 2026-10-24): every cosmetic that B's progression hands out (achievement rewards / unlocks,
## notoriety rank rewards, PAYDAY card table drops) resolves to a catalog entry whose art is built and loads. Reads
## B's data only through its class APIs (Achievements, Notoriety, PaydayCards, MaskCatalog, ContentDB):
##   mask_base.*      model_path glb loads and has a mesh (D: tools/blender/masks)
##   mask_pattern.*   texture_path loads as a Texture2D (D), else the mask shader draws `procedural` (P8 originals)
##   mask_material.*  library_material is set (D)
##   mask_colors.*    entry only (colours carry no art)
##   mask.*           preset mask model loads (D)
##   mod.*            weapon mod model loads (B's weapon art; reported, not D's)
## Ids from an afterhours / rolling_thunder achievement are tagged AH / RT. Prints one row per id
## ("[REWARD] ok|MISSING ...") and a summary; exits 1 when anything is missing.
##   /opt/godot/godot --headless --path game res://world/characters/_tools/audit_reward_cosmetics.tscn
## (a scene, not --script: B's classes need the autoloads, e.g. Log)
## Owner: ENV D.
extends Node

const KINDS: Array[String] = ["mask_base", "mask_pattern", "mask_material", "mask_colors", "mask", "mod"]
const TAGS: Dictionary = {&"afterhours": "AH", &"rolling_thunder": "RT"}

## id -> {"sources": Array[String], "tags": Array[String]}
var _refs: Dictionary = {}
## id -> a note printed with an ok row (e.g. a pattern the shader draws)
var _notes: Dictionary = {}


func _ready() -> void:
	for a: AchievementDef in Achievements.all():
		for id: StringName in Achievements.reward_ids(a):
			_add(id, String(a.id).trim_prefix("achievement."), String(TAGS.get(a.category, "")))
	for rank: int in range(1, Notoriety.max_rank() + 1):
		for id: StringName in Notoriety.rewards_for(rank):
			_add(id, "rank_%d" % rank, "")
	for id: Variant in PaydayCards.table().item_tiers.keys():
		_add(StringName(id), "card_table", "")
	var ids: Array = _refs.keys()
	ids.sort()
	var missing: int = 0
	var counts: Dictionary = {}
	for id: String in ids:
		var problem: String = _check(id)
		var r: Dictionary = _refs[id]
		var kind: String = id.get_slice(".", 0)
		counts[kind] = int(counts.get(kind, 0)) + 1
		if problem != "":
			missing += 1
		print("[REWARD] %s %-34s %-5s %s%s" % ["ok" if problem == "" else "MISSING", id, ",".join(r["tags"]),
			", ".join(r["sources"]), ("  (%s)" % _notes[id] if _notes.has(id) else "") if problem == "" else "  <- " + problem])
	print("[REWARD] SUMMARY ids=%d missing=%d by kind %s" % [ids.size(), missing, counts])
	get_tree().quit(1 if missing > 0 else 0)


## Records a cosmetic id (unlock ids, cash, xp and loot are not cosmetics and are skipped).
func _add(id: StringName, source: String, tag: String) -> void:
	var s: String = String(id)
	if not KINDS.has(s.get_slice(".", 0)) or not s.contains("."):
		return
	var r: Dictionary = _refs.get(s, {"sources": [], "tags": []})
	if not (r["sources"] as Array).has(source):
		(r["sources"] as Array).append(source)
	if tag != "" and not (r["tags"] as Array).has(tag):
		(r["tags"] as Array).append(tag)
	_refs[s] = r


## "" when the id resolves and its art loads, else what is wrong.
func _check(id: String) -> String:
	var kind: String = id.get_slice(".", 0)
	if kind == "mask" or kind == "mod":
		return _model_ok(ContentDB.mask(StringName(id)) if kind == "mask" else ContentDB.mod(StringName(id)))
	if not MaskCatalog.is_known(StringName(id)):
		return "no catalog entry"
	return _part_ok(kind, MaskCatalog.part(StringName(id)))


func _part_ok(kind: String, e: MaskPartDef) -> String:
	match kind:
		"mask_base":
			return _base_ok(e)
		"mask_pattern":
			return _pattern_ok(e)
		"mask_material":
			return "" if e.get("library_material") is Material else "library_material missing"
	return ""


func _model_ok(res: Resource) -> String:
	if res == null:
		return "no catalog entry"
	var model: Variant = res.get("model")
	return _scene_ok((model as PackedScene).resource_path) if model is PackedScene else "no model"


func _base_ok(e: Resource) -> String:
	var path: String = String(e.get("model_path"))
	if path == "":
		return "" if not bool(e.get("requires_model")) else "requires_model but no model_path"
	return _scene_ok(path)


## MaskPatternDef: a texture when texture_path exists, else the mask shader draws `procedural` (the P8 originals have
## no texture by design); only a missing texture with no shader pattern behind it (SOLID) is missing art.
func _pattern_ok(e: Resource) -> String:
	var tex: String = String(e.get("texture_path"))
	if tex != "" and ResourceLoader.exists(tex):
		return "" if load(tex) is Texture2D else "texture %s does not load" % tex
	if int(e.get("procedural")) > 0:
		_notes[String(e.get("id"))] = "shader pattern %d, no texture" % int(e.get("procedural"))
		return ""
	return "no texture and no shader pattern"


func _scene_ok(path: String) -> String:
	if not ResourceLoader.exists(path):
		return "%s not found" % path
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return "%s does not load" % path
	var n: Node = packed.instantiate()
	var meshes: int = n.find_children("*", "MeshInstance3D", true, false).size()
	n.free()
	return "" if meshes > 0 else "%s has no mesh" % path
