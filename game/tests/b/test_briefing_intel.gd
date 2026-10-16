## D-115: the briefing's "Known security" section. Every heist has exported intel that still matches a fresh
## scan of its map; every line resolves to a strings.csv key with the data's numbers; counts equal a brute-force
## enumeration of the variant table's slot picks at each difficulty; difficulty_add moves them; the section is
## the intel column's last one and the nav stays on screen at 1280x720.
extends TestCase

const SCENE: String = "res://content/ui/briefing/briefing_screen.tscn"
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
	&"gallery_night"]
const DIFFICULTIES: Array[int] = [0, 1, 2, 3, 4, 5]

var _strings: Dictionary = {}


func before_all() -> void:
	_strings = StringTable.parse_csv()


func _def(id: StringName) -> HeistDef:
	return HeistRegistry.get_def(id)


func test_every_heist_has_up_to_date_intel() -> void:
	for id: StringName in HEISTS:
		var def: HeistDef = _def(id)
		assert_true(def != null, "%s has a HeistDef" % id)
		var d: BriefingIntelData = BriefingIntel.data_for(id)
		assert_true(d != null, "%s has %s (run content/ui/briefing/tools/intel_export.gd)" % [id, BriefingIntel.data_path(id)])
		if d == null or def == null:
			continue
		var fresh: BriefingIntelData = BriefingIntel.scan(id, def.map_scene)
		var stale: String = "%s intel is stale: rerun intel_export.gd -- %s" % [id, id]
		assert_eq(d.map_path, def.map_scene, stale)
		assert_eq(d.variants_path, fresh.variants_path, stale)
		assert_true(d.variants_path != "" and ResourceLoader.exists(d.variants_path), "%s map names its variant table" % id)
		assert_eq(_canon(d.fixed), _canon(fresh.fixed), stale + " (fixed)")
		assert_eq(_canon(d.groups), _canon(fresh.groups), stale + " (groups)")
		assert_eq(var_to_str(d.time_locks_s), var_to_str(fresh.time_locks_s), stale + " (time locks)")


func test_section_lines_resolve_to_strings() -> void:
	assert_has(_strings, "ui.briefing.sec.title")
	for id: StringName in HEISTS:
		for diff: int in DIFFICULTIES:
			var lines: Array[Dictionary] = BriefingIntel.lines(id, diff, int(_def(id).mode))
			assert_true(lines.size() >= 2, "%s @%d has a security section (%d lines)" % [id, diff, lines.size()])
			var last: int = -1
			for l: Dictionary in lines:
				var key: String = String(l["key"])
				assert_true(BriefingIntel.KEYS.values().has(StringName(key)), "%s: %s is a security key" % [id, key])
				assert_has(_strings, key)
				# Not hand-written: the text is exactly the strings key formatted with the data's args.
				assert_eq(String(l["text"]), UiText.t(StringName(key), l["args"] as Dictionary), "%s %s text" % [id, key])
				assert_false(String(l["text"]).contains("{"), "%s %s fully formatted" % [id, key])
				var at: int = BriefingIntel.LINE_ORDER.find(StringName(l["id"]))
				assert_true(at > last, "%s @%d: %s in LINE_ORDER order, once" % [id, diff, l["id"]])
				last = at


func test_counts_match_a_brute_force_of_the_variant_rules() -> void:
	for id: StringName in HEISTS:
		var d: BriefingIntelData = BriefingIntel.data_for(id)
		var table: HeistVariantTable = load(d.variants_path) as HeistVariantTable
		for diff: int in DIFFICULTIES:
			var by_id: Dictionary = _by_id(BriefingIntel.lines(id, diff, int(_def(id).mode)))
			for lid: Variant in BriefingIntel.LINE_CATEGORIES:
				var want: Vector2i = _brute(d, table, BriefingIntel.LINE_CATEGORIES[lid] as Array, diff)
				if want.y <= 0:
					assert_false(by_id.has(lid), "%s @%d: no %s line without any on the map" % [id, diff, lid])
					continue
				assert_true(by_id.has(lid), "%s @%d: %s line (%s)" % [id, diff, lid, want])
				if not by_id.has(lid):
					continue
				var l: Dictionary = by_id[lid]
				assert_eq(Vector2i(int(l["min"]), int(l["max"])), want, "%s @%d %s range" % [id, diff, lid])
				if lid != &"operator":
					var txt: String = str(want.x) if want.x == want.y else "%d–%d" % [want.x, want.y]
					assert_true(String(l["text"]).contains(txt), "%s @%d %s shows %s: %s" % [id, diff, lid, txt, l["text"]])


func test_difficulty_add_changes_the_lines() -> void:
	var moved: int = 0
	for id: StringName in HEISTS:
		var d: BriefingIntelData = BriefingIntel.data_for(id)
		var table: HeistVariantTable = load(d.variants_path) as HeistVariantTable
		var lo: Dictionary = _by_id(BriefingIntel.lines(id, Enums.Difficulty.ROUTINE, int(_def(id).mode)))
		var hi: Dictionary = _by_id(BriefingIntel.lines(id, Enums.Difficulty.CATACLYSM, int(_def(id).mode)))
		for lid: StringName in [&"guards", &"cameras", &"cartel"]:
			var cats: Array = BriefingIntel.LINE_CATEGORIES[lid] as Array
			var a: Vector2i = _brute(d, table, cats, Enums.Difficulty.ROUTINE)
			var b: Vector2i = _brute(d, table, cats, Enums.Difficulty.CATACLYSM)
			if a != b:
				moved += 1
				assert_ne(String((lo[lid] as Dictionary)["text"]), String((hi[lid] as Dictionary)["text"]),
						"%s %s changes Routine -> Cataclysm (%s -> %s)" % [id, lid, a, b])
	assert_true(moved >= 3, "difficulty_add moves guard/camera counts on several heists (%d)" % moved)
	# Golden Hour: camera pick (1, 3) + difficulty_add [0, 0, 0, 1, 1, 2] -> more cameras on Cataclysm.
	var gh: Dictionary = _by_id(BriefingIntel.lines(&"glasshouse", Enums.Difficulty.CATACLYSM, 0))
	var gr: Dictionary = _by_id(BriefingIntel.lines(&"glasshouse", Enums.Difficulty.ROUTINE, 0))
	assert_true(int((gh[&"cameras"] as Dictionary)["max"]) > int((gr[&"cameras"] as Dictionary)["max"]), "GH cameras grow")


func test_pagers_titan_and_loud_only() -> void:
	var tw: StealthTweak = Tweak.stealth()
	for id: StringName in HEISTS:
		var def: HeistDef = _def(id)
		for diff: int in DIFFICULTIES:
			var by_id: Dictionary = _by_id(BriefingIntel.lines(id, diff, int(def.mode)))
			if def.mode == Enums.HeistMode.LOUD_ONLY:
				assert_false(by_id.has(&"pagers"), "%s is loud-only: no pagers line" % id)
				continue
			assert_true(by_id.has(&"pagers"), "%s @%d lists pagers" % [id, diff])
			var p: Dictionary = by_id.get(&"pagers", {"max": -1})
			var want: Vector2i = BriefingIntel.scalar_range(load(BriefingIntel.data_for(id).variants_path) as HeistVariantTable,
					PagerSystem.MAX_ANSWERS_SCALAR, diff)
			if want.y < 0:
				want = Vector2i(tw.pager_max_answers, tw.pager_max_answers)
			assert_eq(int(p["max"]), want.y, "%s pager answers from the data" % id)
			if by_id.has(&"cameras"):
				var titan: bool = diff >= tw.camera_titan_min_difficulty
				assert_eq(StringName((by_id[&"cameras"] as Dictionary)["key"]),
						&"ui.briefing.sec.cameras_titan" if titan else &"ui.briefing.sec.cameras", "%s @%d titan" % [id, diff])
	assert_true(_def(&"dockside_burn").mode == Enums.HeistMode.LOUD_ONLY, "dockside is the loud-only case")


func test_time_lock_from_the_variant_scalar() -> void:
	for id: StringName in [&"night_deposit", &"shadow_ledger"]:
		var d: BriefingIntelData = BriefingIntel.data_for(id)
		var table: HeistVariantTable = load(d.variants_path) as HeistVariantTable
		var want: Vector2i = BriefingIntel.scalar_range(table, &"time_lock_s", Enums.Difficulty.ROUTINE)
		assert_true(want.y > 0, "%s has a time_lock_s scalar" % id)
		var l: Dictionary = _by_id(BriefingIntel.lines(id, 0, int(_def(id).mode))).get(&"time_lock", {}) as Dictionary
		assert_eq(Vector2i(int(l.get("min", -1)), int(l.get("max", -1))), want, "%s time lock" % id)


func test_screen_shows_the_section_last_and_keeps_the_nav_on_screen() -> void:
	var saved: Vector2i = get_window().size
	get_window().size = Vector2i(1280, 720)
	for id: StringName in HEISTS:
		for diff: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.CATACLYSM]:
			var s: BriefingScreen = (load(SCENE) as PackedScene).instantiate() as BriefingScreen
			s.setup(id, diff)
			add_child(s)
			await wait_frames(2)
			var want: Array[String] = []
			for l: Dictionary in s.model["security"] as Array:
				want.append(UiText.t(&"ui.briefing.optional_line", {"text": String(l["text"])}))
			assert_eq(s.security_texts(), want, "%s @%d security lines on screen" % [id, diff])
			assert_true(s.security_box.visible, "%s section visible" % id)
			var col: Node = s.security_box.get_parent()
			assert_eq(col.get_child(col.get_child_count() - 1), s.security_box, "%s: Known security is the last section" % id)
			var vis: Rect2 = get_viewport().get_visible_rect().grow(1.0)
			for b: Button in [s.back_button, s.continue_button, s.play_button]:
				assert_true(vis.encloses(b.get_global_rect()), "%s @%d: %s on screen at 720p" % [id, diff, b.text])
			s.queue_free()
			await wait_frames(1)
	get_window().size = saved


## Key-order-independent text of a nested Dictionary (a saved .tres sorts its keys).
func test_screen_follows_a_difficulty_change() -> void:
	var s: BriefingScreen = (load(SCENE) as PackedScene).instantiate() as BriefingScreen
	s.setup(&"glasshouse", Enums.Difficulty.ROUTINE)
	add_child(s)
	await wait_frames(1)
	var before: Array[String] = s.security_texts()
	s.setup(&"glasshouse", Enums.Difficulty.CATACLYSM)
	await wait_frames(1)
	var after: Array[String] = s.security_texts()
	assert_eq(after.size(), (s.model["security"] as Array).size(), "one label per line after refresh")
	assert_ne(before, after, "Golden Hour's guards/cameras move with the difficulty")
	s.queue_free()
	await wait_frames(1)


## Key-order-independent text of a nested Dictionary (a saved .tres sorts its keys).
static func _canon(v: Variant) -> String:
	if v is Dictionary:
		var keys: Array = (v as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		var parts: PackedStringArray = PackedStringArray()
		for k: Variant in keys:
			parts.append("%s:%s" % [k, _canon((v as Dictionary)[k])])
		return "{%s}" % ",".join(parts)
	if v is float:
		return "%.4f" % v
	return var_to_str(v)


static func _by_id(lines: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for l: Dictionary in lines:
		out[StringName(l["id"])] = l
	return out


## Independent re-derivation: enumerate every slot subset each rule can activate at `diff`.
static func _brute(d: BriefingIntelData, table: HeistVariantTable, cats: Array, diff: int) -> Vector2i:
	var base: int = 0
	for c: Variant in cats:
		base += int(d.fixed.get(c, 0))
	var out: Vector2i = Vector2i(base, base)
	for g: Variant in d.groups:
		var rule: Dictionary = {}
		for r: Dictionary in table.rules:
			if StringName(r.get("group", &"")) == StringName(g):
				rule = r
		var counts: Array[int] = []
		var zero_w: Array[bool] = []
		var by_diff: Dictionary = (rule.get("weights_by_difficulty", {}) as Dictionary).get(diff, {}) as Dictionary
		for sid: Variant in d.groups[g]:
			var s: Dictionary = (d.groups[g] as Dictionary)[sid]
			var n: int = 0
			for c: Variant in cats:
				n += int((s["counts"] as Dictionary).get(c, 0))
			counts.append(n)
			var w: float = float(s["weight"])
			for k: Variant in by_diff:
				if String(k) == String(sid):
					w = float(by_diff[k])
			zero_w.append(w <= 0.0)
		var size: int = counts.size()
		if rule.is_empty():
			var all: int = 0
			for n2: int in counts:
				all += n2
			out += Vector2i(all, all)
			continue
		var pick: Vector2i = rule["pick"]
		var dadd: Array = rule.get("difficulty_add", [])
		var add: int = int(dadd[diff]) if diff < dadd.size() else 0
		var n_lo: int = clampi(pick.x + add, 0, size)
		var n_hi: int = clampi(pick.y + add, 0, size)
		if rule.has("requires") or rule.has("excludes"):
			n_lo = 0
		var weighted: int = zero_w.count(false)
		var best: Vector2i = Vector2i(1 << 30, -1)
		for mask: int in range(1 << size):
			var k: int = 0
			var zeros: int = 0
			var sum: int = 0
			for i: int in range(size):
				if mask & (1 << i):
					k += 1
					sum += counts[i]
					if zero_w[i]:
						zeros += 1
			if k < n_lo or k > n_hi or zeros > maxi(0, k - weighted):
				continue
			best = Vector2i(mini(best.x, sum), maxi(best.y, sum))
		out += best
	return out
