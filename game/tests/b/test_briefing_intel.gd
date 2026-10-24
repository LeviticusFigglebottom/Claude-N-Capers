## D-115: the briefing's "Known security" section. Every heist has exported intel that still matches a fresh
## scan of its map; every line resolves to a strings.csv key with the data's numbers; counts equal a brute-force
## enumeration of the variant table's slot picks at each difficulty; difficulty_add moves them; the section is
## the intel column's last one and the nav stays on screen at 1280x720. Follow-ups: possible surprises by name
## (bad rare events that change the security), frame sensors per the sensor gate, and the rooms of the locks /
## devices (text-scan room boxes equal the blueprint exporter's, item positions equal the instanced map's).
extends TestCase

const SCENE: String = "res://content/ui/briefing/briefing_screen.tscn"
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
	&"gallery_night", &"ostrander_federal", &"rolling_thunder"]  # OF since round 245, RT since D-169 (offered)
const DIFFICULTIES: Array[int] = [0, 1, 2, 3, 4, 5]

var _strings: Dictionary = {}
## RT-B1: staged heists (RT) join the walk through the test-only fixture until they are offered.
var _fx: RefCounted = preload("res://tests/b/staged_heist_fixture.gd").new()


func before_all() -> void:
	_strings = StringTable.parse_csv()
	_fx.call(&"stage")


func after_all() -> void:
	_fx.call(&"unstage")


func _heists() -> Array[StringName]:
	var out: Array[StringName] = HEISTS.duplicate()
	out.append_array(_fx.get(&"staged") as Array[StringName])
	return out


func _def(id: StringName) -> HeistDef:
	return HeistRegistry.get_def(id)


func test_every_heist_has_up_to_date_intel() -> void:
	for id: StringName in _heists():
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
		assert_eq(_canon(d.fixed_rooms), _canon(fresh.fixed_rooms), stale + " (rooms)")
		assert_eq(_canon(d.sensor_gate), _canon(fresh.sensor_gate), stale + " (sensor gate)")
		assert_eq(var_to_str(d.surprises), var_to_str(fresh.surprises), stale + " (surprises)")


func test_section_lines_resolve_to_strings() -> void:
	assert_has(_strings, "ui.briefing.sec.title")
	for id: StringName in _heists():
		for diff: int in DIFFICULTIES:
			var lines: Array[Dictionary] = BriefingIntel.lines(id, diff, int(_def(id).mode))
			assert_true(lines.size() >= 2, "%s @%d has a security section (%d lines)" % [id, diff, lines.size()])
			var last: int = -1
			for l: Dictionary in lines:
				var key: String = String(l["key"])
				assert_true(BriefingIntel.KEYS.values().has(StringName(key)) or key == String(BriefingIntel.convoy_key(id, diff)),
						"%s: %s is a security key" % [id, key])
				assert_has(_strings, key)
				# Not hand-written: the text is exactly the strings key formatted with the data's args.
				assert_eq(String(l["text"]), UiText.t(StringName(key), l["args"] as Dictionary), "%s %s text" % [id, key])
				assert_false(String(l["text"]).contains("{"), "%s %s fully formatted" % [id, key])
				var at: int = BriefingIntel.LINE_ORDER.find(StringName(l["id"]))
				assert_true(at > last, "%s @%d: %s in LINE_ORDER order, once" % [id, diff, l["id"]])
				last = at


func test_counts_match_a_brute_force_of_the_variant_rules() -> void:
	for id: StringName in _heists():
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
	for id: StringName in _heists():
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
	for id: StringName in _heists():
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
			if want.y < 0 and not def.pager_max_by_difficulty.is_empty():  # LEAD: D-130 def value (C's GH row)
				var cap: int = def.pager_max_by_difficulty[clampi(diff, 0, def.pager_max_by_difficulty.size() - 1)]
				want = Vector2i(cap, cap)
			if want.y < 0:
				want = Vector2i(tw.pager_max_answers, tw.pager_max_answers)
			assert_eq(int(p["max"]), want.y, "%s pager answers from the data" % id)
			if by_id.has(&"cameras"):
				var titan_min: int = def.camera_titan_min_difficulty if def.camera_titan_min_difficulty >= 0 \
						else tw.camera_titan_min_difficulty  # LEAD: D-130 def threshold (GH: HAZARDOUS)
				var titan: bool = diff >= titan_min
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
	for id: StringName in _heists():
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


## Follow-up 1: bad rare events that change the security, by name only, from their min_difficulty.
func test_surprises_listed_by_name() -> void:
	# Lead examples that must be listed, and bad events that only touch a device in play / the escape, never listed.
	# LEAD r229: an event that forces an extra civilian (a witness stealth must handle) is a surprise too.
	var must: Dictionary = {&"night_deposit": [&"armored_car_early"], &"dockside_burn": [&"cartel_reinforcements"],
		&"gallery_night": [&"insurance_inspection", &"vaultline_early", &"argus_upgrade", &"late_paperwork"],
		&"shadow_ledger": [&"timelock_extended", &"kessler_sleepover"], &"glasshouse": [&"nervous_manager"],
		&"ostrander_federal": [&"vip_client", &"armored_car_early", &"tower_sniper"],
		&"rolling_thunder": [&"marshal_early", &"convoy_early", &"crane_sniper", &"armored_escort", &"rush_hour"]}
	var never: Dictionary = {&"glasshouse": [&"drill_relock"], &"night_deposit": [&"fog_lifts"]}
	for id: StringName in _heists():
		var d: BriefingIntelData = BriefingIntel.data_for(id)
		var table: HeistVariantTable = load(d.variants_path) as HeistVariantTable
		for ev_id: StringName in must.get(id, []) as Array:
			assert_true(d.surprises.has(ev_id), "%s lists %s" % [id, ev_id])
		for ev_id: StringName in never.get(id, []) as Array:
			assert_false(d.surprises.has(ev_id), "%s does not list %s" % [id, ev_id])
		var events: Dictionary = {}
		for ev: Dictionary in table.rare_events:
			events[StringName(ev["id"])] = ev
		for ev_id: StringName in d.surprises:
			assert_true(events.has(ev_id), "%s surprise %s is a rare event of the table" % [id, ev_id])
			assert_false(bool((events.get(ev_id, {}) as Dictionary).get("good", true)), "%s %s is a bad event" % [id, ev_id])
			assert_has(_strings, String(BriefingIntel.event_key(id, ev_id)))
		for diff: int in DIFFICULTIES:
			var want: PackedStringArray = PackedStringArray()
			for ev: Dictionary in table.rare_events:
				if d.surprises.has(StringName(ev["id"])) and diff >= int(ev.get("min_difficulty", 0)):
					want.append(String(_strings[String(BriefingIntel.event_key(id, StringName(ev["id"])))]))
			var l: Dictionary = _by_id(BriefingIntel.lines(id, diff, int(_def(id).mode))).get(&"surprises", {}) as Dictionary
			if want.is_empty():
				assert_true(l.is_empty(), "%s @%d: no surprises line" % [id, diff])
				continue
			assert_eq(String(l.get("key", "")), "ui.briefing.sec.surprises", "%s @%d surprises key" % [id, diff])
			assert_eq(String(l.get("text", "")), UiText.t(&"ui.briefing.sec.surprises", {"events": ", ".join(want)}),
					"%s @%d surprises by name" % [id, diff])
			assert_false(String(l.get("text", "")).contains("%"), "%s: no chances" % id)
	# min_difficulty: Night Deposit's armoured car is Brutal+ only.
	assert_false(_by_id(BriefingIntel.lines(&"night_deposit", Enums.Difficulty.ROUTINE, 0)).has(&"surprises"), "ND Routine")
	assert_true(_by_id(BriefingIntel.lines(&"night_deposit", Enums.Difficulty.CATACLYSM, 0)).has(&"surprises"), "ND Cataclysm")


## RT-B1: Rolling Thunder's convoy (mission-spawned, so no scan finds it) gets its own line per difficulty: the patrol
## cars on Routine/Tense, the SUVs from Hazardous; heists without convoy keys get none.
func test_convoy_line_by_difficulty() -> void:
	if not _heists().has(&"rolling_thunder"):
		skip("RT neither offered nor staged")
		return
	for diff: int in DIFFICULTIES:
		var l: Dictionary = _by_id(BriefingIntel.lines(&"rolling_thunder", diff, 0)).get(&"convoy", {}) as Dictionary
		var want: String = "ui.briefing.sec.convoy.rolling_thunder.%d" % (0 if diff < Enums.Difficulty.HAZARDOUS else 2)
		assert_eq(String(l.get("key", "")), want, "RT @%d convoy line" % diff)
		assert_eq(String(l.get("text", "")), String(_strings.get(want, "?")), "RT @%d convoy text" % diff)
	for id: StringName in HEISTS:
		if id == &"rolling_thunder":
			continue
		assert_false(_by_id(BriefingIntel.lines(id, Enums.Difficulty.CATACLYSM, int(_def(id).mode))).has(&"convoy"),
				"%s has no convoy line" % id)


## Follow-up 2: frame sensors (LootSpawn alarm_on_take), live per the sensor gate's slots.
func test_frame_sensors_counted() -> void:
	for id: StringName in _heists():
		var d: BriefingIntelData = BriefingIntel.data_for(id)
		var text: String = FileAccess.get_file_as_string(d.map_path)
		var on_map: int = text.count("alarm_on_take = true")
		var scanned: int = 0
		var zones: Array = BriefingIntel.sensor_zones(d)
		scanned += _sum(d.fixed, zones)
		for g: Variant in d.groups:
			for sid: Variant in d.groups[g]:
				scanned += _sum(((d.groups[g] as Dictionary)[sid] as Dictionary)["counts"] as Dictionary, zones)
		assert_eq(scanned, on_map, "%s: every alarmed LootSpawn is a frame sensor" % id)
		var table: HeistVariantTable = load(d.variants_path) as HeistVariantTable
		for diff: int in DIFFICULTIES:
			var l: Dictionary = _by_id(BriefingIntel.lines(id, diff, int(_def(id).mode))).get(&"sensors", {}) as Dictionary
			if on_map == 0:
				assert_true(l.is_empty(), "%s: no frame sensors line" % id)
				continue
			# Brute force: per gate slot with weight at this difficulty, the live zones' sensors.
			var want: Vector2i = Vector2i(1 << 30, -1)
			var gate: StringName = StringName(d.sensor_gate.get("group", &""))
			var rule: Dictionary = {}
			for r: Dictionary in table.rules:
				if StringName(r["group"]) == gate:
					rule = r
			var by_diff: Dictionary = (rule.get("weights_by_difficulty", {}) as Dictionary).get(diff, {}) as Dictionary
			var slots: Dictionary = d.sensor_gate.get("slots", {}) as Dictionary
			for sid: Variant in slots:
				var w: float = float(by_diff.get(sid, (slots[sid] as Dictionary)["weight"]))
				if w <= 0.0:
					continue
				var live: Array = []
				for z: Variant in zones:
					if not ((slots[sid] as Dictionary)["off"] as Array).has(StringName(String(z).trim_prefix("sensor."))):
						live.append(z)
				var r2: Vector2i = _brute(d, table, live, diff)
				want = Vector2i(mini(want.x, r2.x), maxi(want.y, r2.y))
			assert_eq(Vector2i(int(l.get("min", -1)), int(l.get("max", -1))), want, "%s @%d frame sensors" % [id, diff])
			assert_true(String(l.get("text", "")).begins_with(UiText.t(&"ui.briefing.sec.sensors", {"range": ""})),
					"%s frame sensors line: %s" % [id, l.get("text", "")])
	assert_eq(String(BriefingIntel.data_for(&"gallery_night").sensor_gate.get("group", "")), "sensor_net", "GN gate")
	# More zones live -> more sensors: GN Cataclysm (sensors_all possible) tops Routine.
	var lo: Dictionary = _by_id(BriefingIntel.lines(&"gallery_night", Enums.Difficulty.ROUTINE, 0))[&"sensors"]
	var hi: Dictionary = _by_id(BriefingIntel.lines(&"gallery_night", Enums.Difficulty.CATACLYSM, 0))[&"sensors"]
	assert_true(int(hi["max"]) >= int(lo["max"]) and int(hi["max"]) > 0, "GN sensors %s / %s" % [lo["text"], hi["text"]])


## Follow-up 3: located lines name the RoomVolume rooms (the blueprint's rooms and labels).
func test_locations_from_the_room_mapping() -> void:
	for id: StringName in _heists():
		for diff: int in DIFFICULTIES:
			for l: Dictionary in BriefingIntel.lines(id, diff, int(_def(id).mode)):
				if not BriefingIntel.LOCATED_LINES.has(StringName(l["id"])):
					continue
				var rooms: Dictionary = l.get("rooms", {}) as Dictionary
				assert_false(rooms.is_empty(), "%s @%d %s has its rooms" % [id, diff, l["id"]])
				if String(l["key"]) != "ui.briefing.sec.located":
					assert_true(rooms.has(&""), "%s %s: count only when an item is in no room" % [id, l["id"]])
					continue
				var shown: String = String((l["args"] as Dictionary)["rooms"])
				var names: Array = []
				for rid: Variant in rooms:
					var key: String = String(BriefingIntel.room_key(id, StringName(rid)))
					assert_has(_strings, key)
					if not names.has(_strings.get(key, "")):
						names.append(_strings.get(key, ""))
				var listed: int = 0
				for nm: Variant in names:
					if shown.contains(String(nm)):
						listed += 1
				assert_eq(listed, mini(names.size(), BriefingIntel.MAX_ROOMS), "%s %s shows up to %d rooms: %s" % [
					id, l["id"], BriefingIntel.MAX_ROOMS, l["text"]])
				assert_eq(shown.contains("+"), names.size() > BriefingIntel.MAX_ROOMS, "%s %s +more" % [id, l["id"]])
	# Golden rooms (design docs): the Argus hack terminal in its server room, the Treasury keycard, the time locks.
	var gn: Dictionary = _by_id(BriefingIntel.lines(&"gallery_night", Enums.Difficulty.ROUTINE, 0))
	assert_true(String((gn[&"hack_terminals"] as Dictionary)["text"]).contains("Argus server"), "GN hack terminal room")
	assert_true(String((gn[&"keycards"] as Dictionary)["text"]).contains("Treasury"), "GN Treasury keycard")
	assert_true(String((gn[&"lasers"] as Dictionary)["text"]).contains("Treasury"), "GN Treasury lasers")
	var gh: Dictionary = _by_id(BriefingIntel.lines(&"glasshouse", Enums.Difficulty.ROUTINE, 0))
	assert_true(String((gh[&"safes"] as Dictionary)["text"]).contains("Workshop"), "GH safe in the workshop (G2)")
	var sl: Dictionary = _by_id(BriefingIntel.lines(&"shadow_ledger", Enums.Difficulty.ROUTINE, 0))
	assert_true(String((sl[&"time_lock"] as Dictionary)["text"]).contains("Private study"), "SL study-safe time lock")
	var nd: Dictionary = _by_id(BriefingIntel.lines(&"night_deposit", Enums.Difficulty.ROUTINE, 0))
	assert_true(String((nd[&"time_lock"] as Dictionary)["text"]).contains("Antechamber"), "ND TL panel in B8")


## The text-scan room boxes equal the pre-planning blueprint exporter's (instanced map) room shapes.
func test_room_boxes_match_the_blueprint_export() -> void:
	var checked: int = 0
	for id: StringName in _heists():
		var bp_path: String = "res://content/data/preplanning/blueprints/%s.tres" % id
		var bp: PreplanBlueprint = load(bp_path) as PreplanBlueprint
		if bp == null:
			continue
		var by_label: Dictionary = {}
		for s: Dictionary in bp.shapes:
			if StringName(s.get("kind", &"")) == &"room" and StringName(s.get("label", &"")) != &"":
				if not by_label.has(s["label"]):
					by_label[s["label"]] = []
				(by_label[s["label"]] as Array).append(s["rect"])
		for r: Dictionary in BriefingIntel.map_rooms(_def(id).map_scene):
			var key: StringName = BriefingIntel.room_key(id, StringName(r["id"]))
			if not by_label.has(key):
				continue  # exterior / hand-drawn blueprint (GN): no labelled room shape for it
			var big: Rect2 = Rect2()
			for b: AABB in r["boxes"]:
				var rc: Rect2 = Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
				if rc.get_area() > big.get_area():
					big = rc
			big = big.intersection(bp.bounds)
			var hit: bool = false
			for rc2: Rect2 in by_label[key]:
				hit = hit or (rc2.position.distance_to(big.position) < 0.06 and rc2.end.distance_to(big.end) < 0.06)
			assert_true(hit, "%s room %s box %s matches the blueprint %s" % [id, r["id"], big, by_label[key]])
			checked += 1
	assert_true(checked >= 40, "room boxes checked against the blueprints (%d)" % checked)


## The text transforms (parent chain) equal the instanced map's, for every located item.
func test_item_positions_match_the_instanced_map() -> void:
	for id: StringName in [&"gallery_night", &"night_deposit"]:
		var path: String = _def(id).map_scene
		var nodes: Array[Dictionary] = BriefingIntel.parse_scene(path)
		var root: Node = (load(path) as PackedScene).instantiate()
		var n_checked: int = 0
		for n: Dictionary in nodes:
			var located: bool = String((n["props"] as Dictionary).get("alarm_on_take", "")) == "true"
			for c: StringName in BriefingIntel.categories_of(n):
				located = located or BriefingIntel.LOCATED.has(c)
			if not located:
				continue
			var node: Node3D = root.get_node_or_null(NodePath(String(n["path"]))) as Node3D
			assert_true(node != null, "%s %s instanced" % [id, n["path"]])
			if node == null:
				continue
			var t: Transform3D = node.transform
			var p: Node = node.get_parent()
			while p != null:
				if p is Node3D:
					t = (p as Node3D).transform * t
				p = p.get_parent()
			var mine: Vector3 = BriefingIntel.node_transform(nodes, String(n["path"])).origin
			assert_true(mine.distance_to(t.origin) < 0.01, "%s %s at %s (map %s)" % [id, n["path"], mine, t.origin])
			n_checked += 1
		root.free()
		assert_true(n_checked >= 5, "%s located items checked (%d)" % [id, n_checked])


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
	if v is Array:
		var items: PackedStringArray = PackedStringArray()
		for e: Variant in v:
			items.append(_canon(e))
		return "[%s]" % ",".join(items)
	if v is float:
		return "%.4f" % v
	return var_to_str(v)


static func _sum(counts: Dictionary, cats: Array) -> int:
	var n: int = 0
	for c: Variant in cats:
		n += int(counts.get(c, 0))
	return n


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

