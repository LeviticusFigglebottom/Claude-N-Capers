## D-165 audit (LEAD 2026-10-24): every cosmetic that B's progression data hands out (achievement rewards / unlocks,
## notoriety rank rewards, PAYDAY card table drops) resolves to a catalog entry whose art is built and loads:
##   mask_base.*      MaskPartList bases.tres     model_path glb loads and has a mesh (D: tools/blender/masks)
##   mask_pattern.*   patterns.tres               texture_path loads as a Texture2D (D)
##   mask_material.*  materials.tres              library_material is set and loads (D)
##   mask_colors.*    colors.tres                 entry only (colours carry no art)
##   mask.*           content/data/masks/*.tres   model loads (D)
##   mod.*            content/data/mods/*.tres    model loads (B's weapon art; reported, not D's)
## Ids from an afterhours / rolling_thunder achievement (or an ah_ / rt_ file) are tagged AH / RT. Prints one row per
## id ("[REWARD] ok|MISSING ...") and a summary; exits 1 when anything is missing.
##   /opt/godot/godot --headless --path game --script res://world/characters/_tools/audit_reward_cosmetics.gd
## Owner: ENV D.
extends SceneTree

const SOURCES: Array[String] = ["res://content/data/achievements", "res://content/data/notoriety",
	"res://content/data/payday"]
const PARTS: Dictionary = {
	"mask_base": "res://content/data/masks/parts/bases.tres",
	"mask_pattern": "res://content/data/masks/parts/patterns.tres",
	"mask_material": "res://content/data/masks/parts/materials.tres",
	"mask_colors": "res://content/data/masks/parts/colors.tres",
}
const MASKS_DIR: String = "res://content/data/masks"
const MODS_DIR: String = "res://content/data/mods"
const KINDS: Array[String] = ["mask_base", "mask_pattern", "mask_material", "mask_colors", "mask", "mod"]

## id -> {"sources": Array[String], "tags": Array[String]}
var _refs: Dictionary = {}
var _entries: Dictionary = {}
## id -> a note printed with an ok row (e.g. a pattern the shader draws)
var _notes: Dictionary = {}


func _initialize() -> void:
	var re: RegEx = RegEx.create_from_string("&\"((?:%s)\\.[a-z0-9_]+)\"" % "|".join(KINDS))
	var cat_re: RegEx = RegEx.create_from_string("category = &\"([a-z_]+)\"")
	for dir: String in SOURCES:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".tres"):
				continue
			var text: String = FileAccess.get_file_as_string(dir.path_join(f))
			var cat: RegExMatch = cat_re.search(text)
			var tag: String = ""
			if (cat != null and cat.get_string(1) == "afterhours") or f.begins_with("ah_"):
				tag = "AH"
			elif (cat != null and cat.get_string(1) == "rolling_thunder") or f.begins_with("rt_"):
				tag = "RT"
			for m: RegExMatch in re.search_all(text):
				var id: String = m.get_string(1)
				var r: Dictionary = _refs.get(id, {"sources": [], "tags": []})
				if not (r["sources"] as Array).has(f.get_basename()):
					(r["sources"] as Array).append(f.get_basename())
				if tag != "" and not (r["tags"] as Array).has(tag):
					(r["tags"] as Array).append(tag)
				_refs[id] = r
	_index()
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
	quit(1 if missing > 0 else 0)


## id -> catalog entry (a MaskPartDef, a mask Resource or a mod Resource)
func _index() -> void:
	for kind: String in PARTS:
		var list: Resource = load(PARTS[kind])
		if list == null:
			push_error("audit_reward_cosmetics: cannot load %s" % PARTS[kind])
			continue
		for e: Resource in list.get("entries"):
			_entries[String(e.get("id"))] = e
	for dir: String in [MASKS_DIR, MODS_DIR]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".tres"):
				continue
			var res: Resource = load(dir.path_join(f))
			if res == null or res.get("id") == null:
				continue
			var id: String = String(res.get("id"))
			if not id.contains("."):
				id = ("mask." if dir == MASKS_DIR else "mod.") + id
			_entries[id] = res


## "" when the id resolves and its art loads, else what is wrong.
func _check(id: String) -> String:
	if not _entries.has(id):
		return "no catalog entry"
	var e: Resource = _entries[id]
	match id.get_slice(".", 0):
		"mask_base":
			return _base_ok(e)
		"mask_pattern":
			return _pattern_ok(e)
		"mask_material":
			return "" if e.get("library_material") is Material else "library_material missing"
		"mask", "mod":
			var model: Variant = e.get("model")
			return _scene_ok((model as PackedScene).resource_path) if model is PackedScene else "no model"
	return ""


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
		_notes[String(e.get("id"))] = "shader pattern %d (no texture)" % int(e.get("procedural"))
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
