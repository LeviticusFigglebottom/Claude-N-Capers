## Briefing "Known security" (D-115). Owner: ENV B.
## Two halves:
##  - scan(map_path) -> BriefingIntelData: a text scan of a heist map (.tscn): which security prefabs and
##    spawns it holds, outside any VariantSlot (fixed) and per VariantSlot. Tool/test only (exported games
##    ship binary scenes); intel_export.gd writes the result to res://content/data/briefing/intel/<heist>.tres.
##  - lines(...) -> Array[Dictionary]: the briefing lines for a difficulty, from that file, the heist's
##    HeistVariantTable (pick + difficulty_add + weights_by_difficulty, the scalars), StealthTweak (pager cap,
##    Titan cameras) and the HeistDef mode. Every number comes from that data; nothing is written by hand.
##
## Line: { "id": StringName, "key": StringName (strings.csv), "args": Dictionary, "text": String,
##         "min": int, "max": int (counts; 0 for flag lines) }. Order: LINE_ORDER.
##
## Counting (VariantResolver semantics): per slot group, a rule picks n in [pick.x, pick.y] + difficulty_add[d]
## slots (clamped to the slot count; 0 allowed when the rule has `requires`/`excludes`). Slots with weight 0
## at that difficulty are only taken once every weighted slot is. The range is the n_min smallest to the n_max
## largest slot counts. A group without a rule keeps every slot. Rare events and mission-scripted spawns
## (SpawnPoint tag &"scripted") are not counted: they are surprises, not intel.
##
## Follow-ups (D-115):
##  - Frame sensors: LootSpawn `alarm_on_take` nodes, category &"sensor.<alarm_group>"; the live zones are
##    every zone but the gate slot's `alarm_groups_off` (GN `sensor_net`), so the line is the min / max over
##    the gate slots that can roll at the difficulty.
##  - Locations: each LOCATED item's room (the RoomVolume box holding its scene position, from the .tscn
##    transforms); a located line appends up to MAX_ROOMS room names (ui.preplan.bp.<heist>.<room_id>) from
##    the slots that can roll, and stays a bare count when one of its items is in no named room.
##  - Possible surprises: the table's rare events that are bad and change the security (is_surprise), by name
##    (ui.briefing.sec.event.<heist>.<event_id>), from their min_difficulty on. No chances or counts.
class_name BriefingIntel
extends RefCounted

const DATA_DIR: String = "res://content/data/briefing/intel"
## Line key id -> strings.csv key (written out so the UI strings test can grep them).
const KEYS: Dictionary = {
	&"guards": &"ui.briefing.sec.guards", &"cartel": &"ui.briefing.sec.cartel",
	&"cameras": &"ui.briefing.sec.cameras", &"cameras_titan": &"ui.briefing.sec.cameras_titan",
	&"operator_always": &"ui.briefing.sec.operator_always", &"operator_maybe": &"ui.briefing.sec.operator_maybe",
	&"pagers": &"ui.briefing.sec.pagers", &"alarm_buttons": &"ui.briefing.sec.alarm_buttons",
	&"keycards": &"ui.briefing.sec.keycards", &"keypads": &"ui.briefing.sec.keypads",
	&"lasers": &"ui.briefing.sec.lasers", &"alarm_cases": &"ui.briefing.sec.alarm_cases",
	&"time_lock": &"ui.briefing.sec.time_lock", &"vault_doors": &"ui.briefing.sec.vault_doors",
	&"safes": &"ui.briefing.sec.safes", &"padlocks": &"ui.briefing.sec.padlocks",
	&"hack_terminals": &"ui.briefing.sec.hack_terminals", &"sensors": &"ui.briefing.sec.sensors",
	&"surprises": &"ui.briefing.sec.surprises", &"located": &"ui.briefing.sec.located",
	&"glass": &"ui.briefing.sec.glass",
}
## RT-B1: a heist's scripted convoy (trucks and escort the mission spawns or removes, so no scan counts them right):
## ui.briefing.sec.convoy.<heist>.<d>, the highest difficulty <= the briefed one that has a key; no key = no line.
const CONVOY_KEY_FMT: String = "ui.briefing.sec.convoy.%s.%d"
## Per-event display keys: ui.briefing.sec.event.<heist>.<event_id>.
const EVENT_KEY_FMT: String = "ui.briefing.sec.event.%s.%s"
## Room display keys (the blueprint's labels): ui.preplan.bp.<heist>.<room_id lowercase>.
const ROOM_KEY_FMT: String = "ui.preplan.bp.%s.%s"
const ROOMS_MORE_KEY: StringName = &"ui.briefing.sec.rooms_more"
const MAX_ROOMS: int = 3
## Categories whose room the scan records (special locks and devices; sensors by prefix SENSOR_PREFIX).
const LOCATED: Array[StringName] = [
	&"keycard_reader", &"keycard_door", &"keypad", &"code_door", &"code_safe", &"vault_door", &"safe", &"laser",
	&"hack_terminal", &"time_lock",
]
const SENSOR_PREFIX: String = "sensor."
## Lines that name their rooms (time lock and sensors included).
const LOCATED_LINES: Array[StringName] = [
	&"keycards", &"keypads", &"lasers", &"sensors", &"time_lock", &"vault_doors", &"safes", &"hack_terminals",
]
## Room purposes that are ways through, not places: a device on their wall belongs to the room beside it.
const PASSAGE_PURPOSES: Array[StringName] = [&"corridor", &"stair", &"exterior", &"elevator", &"shaft"]
## A wall-mounted device sits up to this far outside its room's box (m, horizontal).
const ROOM_REACH_M: float = 0.75
## Rare-event effect keys that add hostiles, move timers or harden devices (see is_surprise). RT-B1: also an armoured
## car's timed arrival (OF armored_car_early), a sniper perch (OF tower_sniper, RT crane_sniper), the route marshal or
## the convoy coming early, a Wrecker escort, and more civilians on the street (more witnesses). AH-B1: Afterhours'
## second rope bouncer and VIP guests (vip_party), the off-duty cop, and the Co-op couriers.
const THREAT_EFFECTS: Array[StringName] = [
	&"extra_guards", &"gunmen", &"timed_spawn", &"time_lock_add_s", &"police_delay_s", &"extra_hack_interruptions",
	&"timed_spawn_s", &"perch_s3", &"marshal_lead_s", &"convoy_eta_add_s", &"wrecker_escort", &"civilians",
	&"guard_extra", &"vip_patrons", &"off_duty_cop", &"couriers",
]
## SpawnPoint.Kind values that are hostile (GUARD, POLICE, SNIPER_PERCH, CAMERA_OPERATOR).
const HOSTILE_SPAWNS: Array[int] = [1, 3, 4, 5]
## SpawnPoint.Kind.CIVILIAN: a bad rare event that forces a civilian into play adds a witness, which stealth has to deal
## with like a guard (SL kessler_sleepover, LEAD r229), so it is a surprise too.
const SPAWN_CIVILIAN: int = 2
## TacticalPoint.Kind.SNIPER_PERCH (contracts/map/tactical_point.gd): a police sniper perch.
const TACTICAL_SNIPER_PERCH: int = 3

const CATEGORIES: Array[StringName] = [
	&"camera", &"guard", &"cartel", &"operator", &"keycard_reader", &"keycard_door", &"keypad", &"code_door",
	&"code_safe", &"vault_door", &"safe", &"laser", &"padlock", &"alarm_button", &"alarm_case", &"hack_terminal",
]
## Line ids, in briefing order.
const LINE_ORDER: Array[StringName] = [
	&"guards", &"cartel", &"cameras", &"operator", &"pagers", &"alarm_buttons", &"keycards", &"keypads",
	&"lasers", &"sensors", &"alarm_cases", &"time_lock", &"vault_doors", &"safes", &"padlocks", &"hack_terminals",
	&"convoy", &"glass", &"surprises",
]

## Line id -> the scan categories it sums (pagers and the time lock come from the tweak / variant scalars).
const LINE_CATEGORIES: Dictionary = {
	&"guards": [&"guard"], &"cartel": [&"cartel"], &"cameras": [&"camera"], &"operator": [&"operator"],
	&"alarm_buttons": [&"alarm_button"], &"keycards": [&"keycard_reader", &"keycard_door"],
	&"keypads": [&"keypad", &"code_door", &"code_safe"], &"lasers": [&"laser"], &"alarm_cases": [&"alarm_case"],
	&"vault_doors": [&"vault_door"], &"safes": [&"safe"], &"padlocks": [&"padlock"],
	&"hack_terminals": [&"hack_terminal"],
}
## Prefab scene / script path -> category (the scan matches on the path's file name).
const PREFAB_CATEGORY: Dictionary = {
	"security_camera": &"camera", "keycard_reader": &"keycard_reader", "keypad": &"keypad", "safe": &"safe",
	"laser_grid": &"laser", "padlock": &"padlock", "alarm_button": &"alarm_button", "hack_terminal": &"hack_terminal",
	"camera_station": &"camera_station",
}
## SpawnPoint.Kind values (contracts/map/spawn_point.gd); GUARD is the default, so the scene omits it.
## CameraStation.STAFFED_GROUP (a literal: the scan runs in --script tools without autoloads).
const STAFFED_GROUP: StringName = &"security_room_staffed"
const SPAWN_GUARD: int = 1
const SPAWN_CAMERA_OPERATOR: int = 5
const SCRIPTED_TAG: String = "scripted"
const CARTEL_TAG: String = "cartel"
## Door.Lock values (systems/prefabs/door/door.gd).
const DOOR_KEYCARD: int = 2
const DOOR_CODE: int = 3
const DOOR_VAULT: int = 6

static var _attr_re: RegEx = null
static var _ext_re: RegEx = null
static var _sub_re: RegEx = null


# --- Lines (briefing) ---------------------------------------------------------------------------------

static func data_path(heist_id: StringName) -> String:
	return "%s/%s.tres" % [DATA_DIR, heist_id]


## The exported intel for `heist_id`, or null when there is none (heists without a map yet).
static func data_for(heist_id: StringName) -> BriefingIntelData:
	var p: String = data_path(heist_id)
	if heist_id == &"" or not ResourceLoader.exists(p):
		return null
	return load(p) as BriefingIntelData


## The briefing's "Known security" lines for `heist_id` at `difficulty` (see the header). `mode` is
## Enums.HeistMode (a loud-only heist shows no pagers). Empty when the heist has no exported intel.
static func lines(heist_id: StringName, difficulty: int, mode: int, data: BriefingIntelData = null,
		table: HeistVariantTable = null) -> Array[Dictionary]:
	var d: BriefingIntelData = data if data != null else data_for(heist_id)
	var out: Array[Dictionary] = []
	if d == null:
		return out
	var t: HeistVariantTable = table
	if t == null and d.variants_path != "" and ResourceLoader.exists(d.variants_path):
		t = load(d.variants_path) as HeistVariantTable
	var tw: StealthTweak = Tweak.stealth()
	var r: Dictionary = {}
	for id: Variant in LINE_CATEGORIES:
		r[id] = count_range(d, t, LINE_CATEGORIES[id] as Array, difficulty)
	var guards: Vector2i = r[&"guards"]
	var op: Vector2i = r[&"operator"]
	for id: StringName in LINE_ORDER:
		match id:
			&"cameras":
				var titan: bool = difficulty >= titan_min_difficulty(heist_id)
				_add_count(out, id, r[id], &"cameras_titan" if titan else &"cameras")
			&"operator":
				if op.y > 0:
					_add(out, id, &"operator_always" if op.x >= op.y else &"operator_maybe", {}, op)
			&"pagers":
				if mode != Enums.HeistMode.LOUD_ONLY and (guards.y > 0 or op.y > 0):
					# data_schemas v1.3 precedence (as PagerSystem.cap_for): a rolled pager_max_answers scalar, then the
					# def's per-difficulty row (D-130), then the tweak.
					var pagers: Vector2i = scalar_range(t, PagerSystem.MAX_ANSWERS_SCALAR, difficulty)
					if pagers.y < 0:
						var def_cap: int = pager_cap(heist_id, difficulty)
						pagers = Vector2i(def_cap, def_cap) if def_cap >= 0 \
								else Vector2i(tw.pager_max_answers, tw.pager_max_answers)
					_add(out, id, id, {"range": range_text(pagers)}, pagers)
			&"time_lock":
				var tl: Vector2i = time_lock_range(d, t, difficulty)
				if tl.y > 0:
					_add(out, id, id, {"range": range_text(tl)}, tl)
			&"sensors":
				_add_count(out, id, sensor_range(d, t, difficulty))
			&"glass":
				# D-142: a heist with notable glazing (heist_list.tres "glazing") warns that glass does not hide you.
				if mode != Enums.HeistMode.LOUD_ONLY and HudTweak.load_default().d142_glass_tips \
						and HeistCatalog.heist_list().has_glazing(heist_id):
					_add(out, id, id, {}, Vector2i.ZERO)
			&"convoy":
				var ek: StringName = convoy_key(heist_id, difficulty)
				if ek != &"":
					out.append({"id": id, "key": ek, "args": {}, "text": UiText.t(ek), "min": 0, "max": 0})
			&"surprises":
				var names: PackedStringArray = PackedStringArray()
				for ev: StringName in surprises_at(d, t, difficulty):
					names.append(UiText.t(event_key(heist_id, ev)))
				if not names.is_empty():
					_add(out, id, id, {"events": ", ".join(names)}, Vector2i.ZERO)
			_:
				_add_count(out, id, r[id])
	for l: Dictionary in out:
		if LOCATED_LINES.has(l["id"]):
			_locate(l, heist_id, room_counts(d, t, line_categories(d, StringName(l["id"])), difficulty))
	return out


## RT-B1: the convoy line's key for `heist_id` at `difficulty` (CONVOY_KEY_FMT, falling back to lower difficulties), or &"".
static func convoy_key(heist_id: StringName, difficulty: int) -> StringName:
	for d: int in range(difficulty, -1, -1):
		var k: StringName = StringName(CONVOY_KEY_FMT % [heist_id, d])
		if StringTable.has(k):
			return k
	return &""


## D-140: the pager carriers (guards + the camera operator) `heist_id` can field at `difficulty`, [min, max] over seeds;
## (-1, -1) when the heist has no exported intel.
static func guard_range(heist_id: StringName, difficulty: int) -> Vector2i:
	var d: BriefingIntelData = data_for(heist_id)
	if d == null:
		return Vector2i(-1, -1)
	var t: HeistVariantTable = null
	if d.variants_path != "" and ResourceLoader.exists(d.variants_path):
		t = load(d.variants_path) as HeistVariantTable
	var cats: Array = (LINE_CATEGORIES[&"guards"] as Array) + (LINE_CATEGORIES[&"operator"] as Array)
	return count_range(d, t, cats, difficulty)


## D-130: the difficulty from which `heist_id`'s cameras are Titan (the def's value when >= 0, else StealthTweak's).
static func titan_min_difficulty(heist_id: StringName) -> int:
	var def: HeistDef = HeistRegistry.get_def(heist_id) if heist_id != &"" else null
	if def != null and def.camera_titan_min_difficulty >= 0:
		return def.camera_titan_min_difficulty
	return Tweak.stealth().camera_titan_min_difficulty


## D-130: `heist_id`'s pager cap at `difficulty` from HeistDef.pager_max_by_difficulty, or -1 when the def sets none.
static func pager_cap(heist_id: StringName, difficulty: int) -> int:
	var def: HeistDef = HeistRegistry.get_def(heist_id) if heist_id != &"" else null
	if def == null or def.pager_max_by_difficulty.is_empty():
		return -1
	return def.pager_max_by_difficulty[clampi(difficulty, 0, def.pager_max_by_difficulty.size() - 1)]


## The scan categories a line's rooms come from (LINE_CATEGORIES, the time lock, every sensor zone).
static func line_categories(d: BriefingIntelData, line_id: StringName) -> Array:
	match line_id:
		&"time_lock":
			return [&"time_lock"]
		&"sensors":
			return sensor_zones(d)
	return LINE_CATEGORIES.get(line_id, []) as Array


## Display key of a rare event's name.
static func event_key(heist_id: StringName, event_id: StringName) -> StringName:
	return StringName(EVENT_KEY_FMT % [heist_id, event_id])


## Display key of a room (the pre-planning blueprint's label key).
static func room_key(heist_id: StringName, room_id: StringName) -> StringName:
	return StringName(ROOM_KEY_FMT % [heist_id, String(room_id).to_lower()])


## The data's surprises that can happen at `difficulty` (the event's min_difficulty), in table order.
static func surprises_at(d: BriefingIntelData, t: HeistVariantTable, difficulty: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if t == null:
		return out
	for ev: Dictionary in t.rare_events:
		var id: StringName = StringName(ev.get("id", &""))
		if d.surprises.has(id) and difficulty >= int(ev.get("min_difficulty", 0)):
			out.append(id)
	return out


## True for a rare event the briefing warns about: a bad event (good == false) that adds hostiles, moves a
## timer or hardens a device (THREAT_EFFECTS), or forces a slot in `threat_slots` ({ group: [slot ids] }:
## slots holding security or hostile spawns, and the sensor gate's slots).
static func is_surprise(ev: Dictionary, threat_slots: Dictionary) -> bool:
	if bool(ev.get("good", true)):
		return false
	var fx: Dictionary = ev.get("effects", {}) as Dictionary
	for k: StringName in THREAT_EFFECTS:
		if fx.has(k):
			return true
	var fa: Variant = fx.get("force_active", {})
	if fa is Dictionary and not (fa as Dictionary).is_empty():
		var g: StringName = StringName((fa as Dictionary).get("group", &""))
		var slot: StringName = StringName((fa as Dictionary).get("slot", &""))
		return (threat_slots.get(g, []) as Array).has(slot)
	return false


## Every sensor zone category (&"sensor.<zone>") on the map, sorted.
static func sensor_zones(d: BriefingIntelData) -> Array:
	var zones: Array = []
	var all: Array = [d.fixed]
	for g: Variant in d.groups:
		for sid: Variant in d.groups[g]:
			all.append(((d.groups[g] as Dictionary)[sid] as Dictionary).get("counts", {}))
	for counts: Variant in all:
		for c: Variant in counts:
			if String(c).begins_with(SENSOR_PREFIX) and not zones.has(StringName(c)):
				zones.append(StringName(c))
	zones.sort()
	return zones


## Vector2i(min, max) live frame sensors at `difficulty`: per gate slot that can roll, the sensors outside
## its `off` zones (count_range); without a gate, every zone.
static func sensor_range(d: BriefingIntelData, t: HeistVariantTable, difficulty: int) -> Vector2i:
	var zones: Array = sensor_zones(d)
	if zones.is_empty():
		return Vector2i.ZERO
	if d.sensor_gate.is_empty():
		return count_range(d, t, zones, difficulty)
	var gate: StringName = StringName(d.sensor_gate.get("group", &""))
	var slots: Dictionary = d.sensor_gate.get("slots", {}) as Dictionary
	var out: Vector2i = Vector2i(1 << 30, -1)
	for sid: Variant in rollable_slots(t, gate, slots, difficulty):
		var off: Array = ((slots[sid] as Dictionary).get("off", []) as Array)
		var live: Array = []
		for z: Variant in zones:
			if not off.has(StringName(String(z).trim_prefix(SENSOR_PREFIX))):
				live.append(z)
		var r: Vector2i = count_range(d, t, live, difficulty)
		out = Vector2i(mini(out.x, r.x), maxi(out.y, r.y))
	return out if out.y >= 0 else count_range(d, t, zones, difficulty)


## The slot ids of `group` ({ slot_id: { "weight": float } }) that can roll at `difficulty`: every slot
## without a rule; else none when the rule picks 0, the weighted slots, and the zero-weight ones only when
## the pick can exceed the weighted slots.
static func rollable_slots(t: HeistVariantTable, group: StringName, slots: Dictionary, difficulty: int) -> Array:
	var rule: Dictionary = {}
	if t != null:
		for r: Dictionary in t.rules:
			if StringName(r.get("group", &"")) == group:
				rule = r
	if rule.is_empty():
		return slots.keys()
	var picks: Vector2i = pick_range(rule, difficulty, slots.size())
	var w_over: Dictionary = slot_weights(rule, difficulty)
	var weighted: Array = []
	var unweighted: Array = []
	for sid: Variant in slots:
		var w: float = float(w_over.get(String(sid), (slots[sid] as Dictionary).get("weight", 1.0)))
		if w > 0.0:
			weighted.append(sid)
		else:
			unweighted.append(sid)
	if picks.y <= 0:
		return []
	return weighted + unweighted if picks.y > weighted.size() else weighted


## { room_id: count } of `categories` over the fixed items and the slots that can roll at `difficulty`
## (the most each room can hold; &"" = an item in no room).
static func room_counts(d: BriefingIntelData, t: HeistVariantTable, categories: Array, difficulty: int) -> Dictionary:
	var out: Dictionary = {}
	_sum_rooms(d.fixed_rooms, categories, out)
	for g: Variant in d.groups:
		var slots: Dictionary = d.groups[g]
		for sid: Variant in rollable_slots(t, StringName(g), slots, difficulty):
			_sum_rooms((slots[sid] as Dictionary).get("rooms", {}) as Dictionary, categories, out)
	return out


## "Treasury, Art store" (most items first, then by name), or "A, B, C +2"; "" when an item is in no named room.
static func rooms_text(heist_id: StringName, rooms: Dictionary) -> String:
	var named: Dictionary = {}  # display name -> count
	for rid: Variant in rooms:
		var key: StringName = room_key(heist_id, StringName(rid))
		if StringName(rid) == &"" or not UiText.has(key):
			return ""
		var nm: String = UiText.t(key)
		named[nm] = int(named.get(nm, 0)) + int(rooms[rid])
	var names: Array = named.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(named[a]) > int(named[b]) or (int(named[a]) == int(named[b]) and String(a) < String(b)))
	var shown: PackedStringArray = PackedStringArray()
	for i: int in range(mini(MAX_ROOMS, names.size())):
		shown.append(String(names[i]))
	var txt: String = ", ".join(shown)
	if names.size() > MAX_ROOMS:
		txt = UiText.t(ROOMS_MORE_KEY, {"rooms": txt, "n": names.size() - MAX_ROOMS})
	return txt


static func _sum_rooms(by_cat: Dictionary, categories: Array, out: Dictionary) -> void:
	for c: Variant in categories:
		var rooms: Dictionary = by_cat.get(c, {}) as Dictionary
		for rid: Variant in rooms:
			out[StringName(rid)] = int(out.get(StringName(rid), 0)) + int(rooms[rid])


## Re-keys a line to ui.briefing.sec.located ("<line> (<rooms>)") when its rooms are all named.
static func _locate(l: Dictionary, heist_id: StringName, rooms: Dictionary) -> void:
	l["rooms"] = rooms
	var txt: String = rooms_text(heist_id, rooms) if not rooms.is_empty() else ""
	if txt == "":
		return
	l["base_key"] = l["key"]
	l["key"] = KEYS[&"located"]
	l["args"] = {"line": l["text"], "rooms": txt}
	l["text"] = UiText.t(l["key"], l["args"])


## Vector2i(min, max) seconds of the heist's time lock: the `time_lock_s` variant scalar (values that can roll
## at `difficulty`), else the map's safe time locks; Vector2i(-1, -1) without one.
static func time_lock_range(d: BriefingIntelData, t: HeistVariantTable, difficulty: int) -> Vector2i:
	var tl: Vector2i = scalar_range(t, &"time_lock_s", difficulty)
	if tl.y < 0 and not d.time_locks_s.is_empty():
		tl = Vector2i(roundi(d.time_locks_s[0]), roundi(d.time_locks_s[d.time_locks_s.size() - 1]))
	return tl


## Vector2i(min, max) of the summed `categories` on the map at `difficulty` (see the header).
static func count_range(d: BriefingIntelData, table: HeistVariantTable, categories: Array,
		difficulty: int) -> Vector2i:
	var n: int = _sum_counts(d.fixed, categories)
	var out: Vector2i = Vector2i(n, n)
	var rules: Dictionary = {}
	if table != null:
		for rule: Dictionary in table.rules:
			rules[StringName(rule.get("group", &""))] = rule
	for g: Variant in d.groups:
		var slots: Dictionary = d.groups[g]
		var rule: Dictionary = rules.get(StringName(g), {}) as Dictionary
		var weighted: Array[int] = []
		var unweighted: Array[int] = []
		var w_over: Dictionary = slot_weights(rule, difficulty)
		var all_sum: int = 0
		for sid: Variant in slots:
			var s: Dictionary = slots[sid]
			var c: int = _sum_counts(s.get("counts", {}) as Dictionary, categories)
			all_sum += c
			var w: float = float(w_over.get(String(sid), s.get("weight", 1.0)))
			if w > 0.0:
				weighted.append(c)
			else:
				unweighted.append(c)
		if rule.is_empty():
			out += Vector2i(all_sum, all_sum)  # no rule: every slot stays active
			continue
		var picks: Vector2i = pick_range(rule, difficulty, slots.size())
		weighted.sort()
		unweighted.sort()
		out.x += _pick_sum(weighted, unweighted, picks.x, false)
		out.y += _pick_sum(weighted, unweighted, picks.y, true)
	return out


## Vector2i(n_min, n_max) slots a rule activates at `difficulty`, clamped to [0, slot_count].
static func pick_range(rule: Dictionary, difficulty: int, slot_count: int) -> Vector2i:
	var pick: Vector2i = rule.get("pick", Vector2i(1, 1))
	var add: int = 0
	var dadd: Array = rule.get("difficulty_add", [])
	if difficulty >= 0 and difficulty < dadd.size():
		add = int(dadd[difficulty])
	var lo: int = clampi(mini(pick.x, pick.y) + add, 0, slot_count)
	var hi: int = clampi(maxi(pick.x, pick.y) + add, 0, slot_count)
	if not (rule.get("requires", {}) as Dictionary).is_empty() or not (rule.get("excludes", {}) as Dictionary).is_empty():
		lo = 0  # the rule may pick nothing
	return Vector2i(lo, hi)


## A rule's weights_by_difficulty entry for `difficulty`: { String(slot_id): weight }.
static func slot_weights(rule: Dictionary, difficulty: int) -> Dictionary:
	var out: Dictionary = {}
	var by_diff: Variant = rule.get("weights_by_difficulty", {})
	if by_diff is Dictionary and (by_diff as Dictionary).has(difficulty):
		var e: Variant = (by_diff as Dictionary)[difficulty]
		if e is Dictionary:
			for k: Variant in e:
				out[String(k)] = float((e as Dictionary)[k])
	return out


## Vector2i(min, max) of a variant scalar's values that can roll at `difficulty` (weight > 0), rounded;
## Vector2i(-1, -1) when the table has no such scalar.
static func scalar_range(table: HeistVariantTable, id: StringName, difficulty: int) -> Vector2i:
	if table == null:
		return Vector2i(-1, -1)
	for sc: Dictionary in table.scalars:
		if StringName(sc.get("id", &"")) != id:
			continue
		var values: Array = sc.get("values", [])
		var weights: PackedFloat32Array = sc.get("weights", PackedFloat32Array())
		var by_diff: Variant = sc.get("weights_by_difficulty", {})
		if by_diff is Dictionary and (by_diff as Dictionary).has(difficulty):
			weights = (by_diff as Dictionary)[difficulty]
		var lo: int = 0
		var hi: int = -1
		for i: int in range(values.size()):
			if weights.size() == values.size() and weights[i] <= 0.0:
				continue
			var v: int = roundi(float(values[i]))
			lo = v if hi < 0 else mini(lo, v)
			hi = maxi(hi, v)
		return Vector2i(lo, hi) if hi >= 0 else Vector2i(-1, -1)
	return Vector2i(-1, -1)


## "3" or "2–4" (ui.briefing.sec.range).
static func range_text(r: Vector2i) -> String:
	if r.x == r.y:
		return str(r.x)
	return UiText.t(&"ui.briefing.sec.range", {"min": r.x, "max": r.y})


static func _sum_counts(counts: Dictionary, categories: Array) -> int:
	var n: int = 0
	for c: Variant in categories:
		n += int(counts.get(c, 0))
	return n


static func _pick_sum(weighted: Array[int], unweighted: Array[int], n: int, largest: bool) -> int:
	# VariantResolver takes weighted slots first; zero-weight slots only once those run out.
	var from_w: int = mini(n, weighted.size())
	var from_u: int = mini(n - from_w, unweighted.size())
	return _sum_end(weighted, from_w, largest) + _sum_end(unweighted, from_u, largest)


static func _sum_end(sorted: Array[int], k: int, largest: bool) -> int:
	var s: int = 0
	for i: int in range(k):
		s += sorted[sorted.size() - 1 - i] if largest else sorted[i]
	return s


static func _add_count(out: Array[Dictionary], id: StringName, r: Vector2i, key_id: StringName = &"") -> void:
	if r.y <= 0:
		return
	_add(out, id, key_id if key_id != &"" else id, {"range": range_text(r)}, r)


static func _add(out: Array[Dictionary], id: StringName, key_id: StringName, args: Dictionary, r: Vector2i) -> void:
	var key: StringName = KEYS[key_id]
	out.append({"id": id, "key": key, "args": args, "text": UiText.t(key, args), "min": r.x, "max": r.y})


# --- Scan (tool / test) -------------------------------------------------------------------------------

static func scan(heist_id: StringName, map_path: String) -> BriefingIntelData:
	var subs: Dictionary = {}
	var nodes: Array[Dictionary] = parse_scene(map_path, subs)
	var out: BriefingIntelData = BriefingIntelData.new()
	out.heist_id = heist_id
	out.map_path = map_path
	if not nodes.is_empty():
		out.variants_path = String((nodes[0]["props"] as Dictionary).get("variant_table", ""))
	var by_path: Dictionary = {}
	for n: Dictionary in nodes:
		by_path[n["path"]] = n
	var xf: Dictionary = {}  # node path -> scene-root Transform3D (memo)
	var rooms: Array[Dictionary] = scan_rooms(nodes, subs, by_path, xf)
	var slots: Dictionary = {}  # node path -> {group, id, weight, counts, rooms}
	var gate_group: StringName = &""
	var gate_slots: Dictionary = {}
	for n: Dictionary in nodes:
		if String(n["script"]).ends_with("/variant_slot.gd"):
			var props: Dictionary = n["props"] as Dictionary
			var s: Dictionary = {
				"group": StringName(_unquote(String(props.get("slot_group", "\"\"")))),
				"id": StringName(_unquote(String(props.get("slot_id", "\"\"")))),
				"weight": float(String(props.get("weight", "1.0"))), "counts": {}, "rooms": {}, "threat": false,
			}
			slots[n["path"]] = s
			var params: Variant = str_to_var(String(props.get("params", "{}")))
			if params is Dictionary and (params as Dictionary).has("alarm_groups_off"):
				gate_group = s["group"]
				var off: Array[StringName] = []
				for z: Variant in (params as Dictionary)["alarm_groups_off"]:
					off.append(StringName(z))
				gate_slots[s["id"]] = {"weight": s["weight"], "off": off}
	if gate_group != &"":
		out.sensor_gate = {"group": gate_group, "slots": gate_slots}
	var cats_at: Dictionary = {}  # node path -> Array[StringName]
	for n: Dictionary in nodes:
		var cats: Array[StringName] = categories_of(n)
		var props: Dictionary = n["props"] as Dictionary
		if slots.has(n["path"]) and props.has("prefab"):
			cats.append_array(categories_of({"instance": String(props["prefab"]), "script": "", "props": {}}))
		if not cats.is_empty():
			cats_at[n["path"]] = cats
	var fixed: Dictionary = {}
	var fixed_rooms: Dictionary = {}
	var locks: Array[float] = []
	var has_station: bool = false
	var has_operator: bool = false
	for n: Dictionary in nodes:
		if not cats_at.has(n["path"]):
			continue
		var cats: Array[StringName] = cats_at[n["path"]]
		var props: Dictionary = n["props"] as Dictionary
		# A reader / keypad that opens a keycard / code door is that door's lock: count the lock once.
		for pair: Array in [[&"keycard_reader", &"keycard_door"], [&"keypad", &"code_door"]]:
			if cats.has(pair[0]) and _targets_have(String(n["path"]), String(props.get("targets", "")), cats_at, pair[1]):
				cats.erase(pair[0])
		has_station = has_station or cats.has(&"camera_station")
		has_operator = has_operator or cats.has(&"operator")
		cats.erase(&"camera_station")
		cats.erase(&"operator")
		var tl: float = float(String(props.get("time_lock_s", "0")))
		if tl > 0.0 and not locks.has(tl):
			locks.append(tl)
		# A slot's own `prefab` belongs to that slot.
		var slot_path: String = String(n["path"]) if slots.has(n["path"]) else _slot_ancestor(String(n["path"]), slots)
		var into: Dictionary = fixed if slot_path == "" else (slots[slot_path] as Dictionary)["counts"] as Dictionary
		for c: StringName in cats:
			into[c] = int(into.get(c, 0)) + 1
		var located: Array[StringName] = []
		for c: StringName in cats:
			if LOCATED.has(c) or String(c).begins_with(SENSOR_PREFIX):
				located.append(c)
		if tl > 0.0 or _unquote(String(props.get("objective_tag", ""))) == "time_lock":
			located.append(&"time_lock")
		if located.is_empty():
			continue
		var room: StringName = room_at(rooms, _xform(String(n["path"]), by_path, xf).origin)
		var rinto: Dictionary = fixed_rooms if slot_path == "" else (slots[slot_path] as Dictionary)["rooms"] as Dictionary
		for c: StringName in located:
			if not rinto.has(c):
				rinto[c] = {}
			(rinto[c] as Dictionary)[room] = int((rinto[c] as Dictionary).get(room, 0)) + 1
	# Camera operator (CameraStation): a CAMERA_OPERATOR spawn and a station; when the map has the
	# security_room_staffed group, its slots whose id does not end in "empty" staff the room.
	if has_station and has_operator:
		var staffed: bool = false
		for sp: Variant in slots:
			var s: Dictionary = slots[sp]
			if StringName(s["group"]) == STAFFED_GROUP:
				staffed = true
				if not String(s["id"]).ends_with("empty"):
					(s["counts"] as Dictionary)[&"operator"] = 1
		if not staffed:
			fixed[&"operator"] = 1
	out.fixed = fixed
	out.fixed_rooms = fixed_rooms
	var groups: Dictionary = {}
	for sp: Variant in slots:
		var s: Dictionary = slots[sp]
		if not (s["counts"] as Dictionary).is_empty():
			groups[s["group"]] = {}
	for sp: Variant in slots:
		var s: Dictionary = slots[sp]
		if groups.has(s["group"]):
			(groups[s["group"]] as Dictionary)[s["id"]] = {"weight": s["weight"], "counts": s["counts"],
				"rooms": s["rooms"]}
	out.groups = groups
	locks.sort()
	out.time_locks_s = locks
	# Surprises: slots holding security, a hostile or a civilian spawn (scripted ones too), and the sensor gate's.
	var threat: Dictionary = {}  # group -> Array[StringName] slot ids
	for n: Dictionary in nodes:
		var sp2: String = _slot_ancestor(String(n["path"]), slots)
		var hostile: bool = false
		var base: String = String(n["instance"] if n["instance"] != "" else n["script"]).get_file().get_basename()
		var kind: String = String((n["props"] as Dictionary).get("kind", ""))
		if base == "spawn_point":
			var k: int = int(kind if kind != "" else str(SPAWN_GUARD))
			hostile = HOSTILE_SPAWNS.has(k) or k == SPAWN_CIVILIAN
		elif base == "tactical_point":
			hostile = kind == str(TACTICAL_SNIPER_PERCH)
		if sp2 != "" and (hostile or cats_at.has(n["path"])):
			(slots[sp2] as Dictionary)["threat"] = true
	for sp: Variant in slots:
		var s: Dictionary = slots[sp]
		if bool(s["threat"]) or (gate_group != &"" and StringName(s["group"]) == gate_group):
			if not threat.has(s["group"]):
				threat[s["group"]] = []
			(threat[s["group"]] as Array).append(s["id"])
	var table: HeistVariantTable = null
	if out.variants_path != "" and ResourceLoader.exists(out.variants_path):
		table = load(out.variants_path) as HeistVariantTable
	if table != null:
		for ev: Dictionary in table.rare_events:
			if is_surprise(ev, threat):
				out.surprises.append(StringName(ev.get("id", &"")))
	return out


## The rooms of the map at `map_path` (scan_rooms).
static func map_rooms(map_path: String) -> Array[Dictionary]:
	var subs: Dictionary = {}
	var nodes: Array[Dictionary] = parse_scene(map_path, subs)
	var by_path: Dictionary = {}
	for n: Dictionary in nodes:
		by_path[n["path"]] = n
	return scan_rooms(nodes, subs, by_path, {})


## Scene-root transform of the node at `path` in parse_scene's `nodes` (tests).
static func node_transform(nodes: Array[Dictionary], path: String) -> Transform3D:
	var by_path: Dictionary = {}
	for n: Dictionary in nodes:
		by_path[n["path"]] = n
	return _xform(path, by_path, {})


## The map's rooms: [{ "id": StringName, "purpose": StringName, "boxes": Array[AABB] (scene-root space) }],
## from the RoomVolume nodes directly under `Rooms` and their CollisionShape3D box children (as
## blueprint_export.gd reads them from the instanced map).
static func scan_rooms(nodes: Array[Dictionary], subs: Dictionary, by_path: Dictionary, xf: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Dictionary = {}  # room node path -> entry
	for n: Dictionary in nodes:
		var p: String = String(n["path"])
		if String(n["script"]).ends_with("/room_volume.gd") and p.get_base_dir() == "Rooms":
			var props: Dictionary = n["props"] as Dictionary
			var e: Dictionary = {"id": StringName(_unquote(String(props.get("room_id", "\"\"")))),
				"purpose": StringName(_unquote(String(props.get("purpose", "\"\"")))), "boxes": []}
			at[p] = e
			out.append(e)
	for n: Dictionary in nodes:
		var p: String = String(n["path"])
		if not at.has(p.get_base_dir()):
			continue
		var shape: String = String((n["props"] as Dictionary).get("shape", ""))
		var a: int = shape.find("SubResource(\"")
		if a < 0:
			continue
		var sid: String = shape.substr(a + 13).get_slice("\"", 0)
		var sub: Dictionary = subs.get(sid, {}) as Dictionary
		if String(sub.get("type", "")) != "BoxShape3D":
			continue
		var size: Variant = str_to_var(String((sub["props"] as Dictionary).get("size", "Vector3(1, 1, 1)")))
		if not size is Vector3:
			continue
		var b: AABB = _xform(p, by_path, xf) * AABB(-(size as Vector3) * 0.5, size as Vector3)
		((at[p.get_base_dir()] as Dictionary)["boxes"] as Array).append(b)
	return out


## The room id holding `pos` (&"" = none): a box that holds it, else one within ROOM_REACH_M (wall devices);
## a room beats a passage (PASSAGE_PURPOSES), holding beats reaching, then the smallest box.
static func room_at(rooms: Array[Dictionary], pos: Vector3) -> StringName:
	var best: StringName = &""
	var best_rank: float = INF
	var reach: Vector3 = Vector3(ROOM_REACH_M, 0.1, ROOM_REACH_M)
	for r: Dictionary in rooms:
		var passage: bool = PASSAGE_PURPOSES.has(StringName(r["purpose"]))
		for b: AABB in r["boxes"]:
			var near: AABB = AABB(b.position - reach, b.size + reach * 2.0)
			if not near.has_point(pos):
				continue
			var tier: int = (2 if passage else 0) + (0 if b.grow(0.01).has_point(pos) else 1)
			var rank: float = float(tier) * 1.0e9 + b.get_volume()
			if rank < best_rank:
				best_rank = rank
				best = StringName(r["id"])
	return best


## Scene-root transform of the node at `path` (parents chained from the text; a node the text lacks is
## the identity, as an instanced sub-scene's root usually is).
static func _xform(path: String, by_path: Dictionary, memo: Dictionary) -> Transform3D:
	if memo.has(path):
		return memo[path]
	var local: Transform3D = Transform3D.IDENTITY
	if by_path.has(path):
		var v: Variant = str_to_var(String(((by_path[path] as Dictionary)["props"] as Dictionary).get("transform", "")))
		if v is Transform3D:
			local = v
	var t: Transform3D = local
	if path != ".":
		t = _xform(path.get_base_dir() if path.contains("/") else ".", by_path, memo) * local
	memo[path] = t
	return t


## Security categories of one scanned node ({instance, script, props}).
static func categories_of(n: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var props: Dictionary = n.get("props", {}) as Dictionary
	var inst: String = String(n.get("instance", "")).get_file().get_basename()
	var script: String = String(n.get("script", "")).get_file().get_basename()
	var base: String = inst if inst != "" else script
	if PREFAB_CATEGORY.has(base):
		out.append(PREFAB_CATEGORY[base])
	match base:
		"spawn_point":
			var kind: int = int(String(props.get("kind", str(SPAWN_GUARD))))
			var tags: String = String(props.get("tags", ""))
			if kind == SPAWN_CAMERA_OPERATOR:
				out.append(&"operator")
			elif kind == SPAWN_GUARD and not tags.contains("&\"%s\"" % SCRIPTED_TAG):
				out.append(&"cartel" if tags.contains("&\"%s\"" % CARTEL_TAG) else &"guard")
		"door":
			match int(String(props.get("lock", "0"))):
				DOOR_KEYCARD:
					out.append(&"keycard_door")
				DOOR_CODE:
					out.append(&"code_door")
				DOOR_VAULT:
					out.append(&"vault_door")
		"safe":
			if String(props.get("methods", "")).contains("&\"code\""):
				out.append(&"code_safe")
		"display_case":
			if String(props.get("glass_breaks_alarm", "false")) == "true":
				out.append(&"alarm_case")
		"loot_spawn":
			if String(props.get("alarm_on_take", "false")) == "true":
				out.append(StringName(SENSOR_PREFIX + _unquote(String(props.get("alarm_group", "\"\"")))))
	return out


## [{ "path": String (from the root, "." = root), "instance": res path or "", "script": res path or "",
##    "props": { name: raw value text } }] for every [node] of a text scene. A value that opens a `{` / `[` /
## `(` at its line end runs to the line that closes it. `subs` (optional) receives the sub-resources:
## { id: { "type": String, "props": { name: raw value text } } }.
static func parse_scene(path: String, subs: Dictionary = {}) -> Array[Dictionary]:
	_compile()
	var out: Array[Dictionary] = []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var ext: Dictionary = {}
	var cur: Dictionary = {}
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.begins_with("["):
			cur = {}
			if line.begins_with("[ext_resource"):
				var m: RegExMatch = _ext_re.search(line)
				if m != null:
					ext[m.get_string(2)] = m.get_string(1)
			elif line.begins_with("[node "):
				cur = _node_header(line, ext)
				out.append(cur)
			elif line.begins_with("[sub_resource"):
				var sm: RegExMatch = _sub_re.search(line)
				if sm != null:
					cur = {"type": sm.get_string(1), "props": {}}
					subs[sm.get_string(2)] = cur
			continue
		if cur.is_empty():
			continue
		var eq: int = line.find(" = ")
		if eq <= 0 or line.begins_with(" ") or line.begins_with("\t") or line.begins_with("\""):
			continue
		var key: String = line.substr(0, eq)
		var val: String = line.substr(eq + 3)
		if val.ends_with("{") or val.ends_with("[") or val.ends_with("("):
			var depth: int = _depth(val)
			while depth > 0 and not f.eof_reached():
				var more: String = f.get_line()
				val += "\n" + more
				depth += _depth(more)
		if key == "script":
			cur["script"] = _ext_path(val, ext)
		elif val.begins_with("ExtResource("):
			(cur["props"] as Dictionary)[key] = _ext_path(val, ext)
		else:
			(cur["props"] as Dictionary)[key] = val
	return out


## Net bracket depth a line opens (strings ignored).
static func _depth(s: String) -> int:
	var d: int = 0
	var in_str: bool = false
	for i: int in range(s.length()):
		var ch: String = s[i]
		if ch == "\"" and (i == 0 or s[i - 1] != "\\"):
			in_str = not in_str
		elif not in_str:
			if ch == "{" or ch == "[" or ch == "(":
				d += 1
			elif ch == "}" or ch == "]" or ch == ")":
				d -= 1
	return d


static func _node_header(line: String, ext: Dictionary) -> Dictionary:
	var attrs: Dictionary = {}
	for m: RegExMatch in _attr_re.search_all(line):
		attrs[m.get_string(1)] = m.get_string(2) if m.get_string(2) != "" else m.get_string(3)
	var name: String = String(attrs.get("name", ""))
	var path: String = "."
	if attrs.has("parent"):
		var parent: String = String(attrs["parent"])
		path = name if parent == "." else "%s/%s" % [parent, name]
	var inst: String = ""
	if attrs.has("instance"):
		inst = _ext_path(String(attrs["instance"]), ext)
	return {"path": path, "instance": inst, "script": "", "props": {}}


static func _ext_path(val: String, ext: Dictionary) -> String:
	var a: int = val.find("ExtResource(\"")
	if a < 0:
		return ""
	var b: int = val.find("\"", a + 13)
	return String(ext.get(val.substr(a + 13, b - a - 13), ""))


## True when one of a node's `targets` (raw `Array[NodePath]([NodePath("../X")])` text, relative to the node)
## is a scanned node of `category`.
static func _targets_have(path: String, raw: String, cats_at: Dictionary, category: StringName) -> bool:
	var parts: PackedStringArray = raw.split("NodePath(\"")
	for i: int in range(1, parts.size()):
		var rel: String = parts[i].get_slice("\"", 0)
		var base: PackedStringArray = path.split("/") if path != "." else PackedStringArray()
		for seg: String in rel.split("/"):
			if seg == "..":
				if not base.is_empty():
					base.remove_at(base.size() - 1)
			elif seg != "." and seg != "":
				base.append(seg)
		var target: String = "/".join(base) if not base.is_empty() else "."
		if cats_at.has(target) and (cats_at[target] as Array).has(category):
			return true
	return false


static func _slot_ancestor(path: String, slots: Dictionary) -> String:
	var p: String = path
	while p.contains("/"):
		p = p.get_base_dir()
		if slots.has(p):
			return p
	return ""


static func _unquote(v: String) -> String:
	return v.trim_prefix("&").trim_prefix("\"").trim_suffix("\"")


static func _compile() -> void:
	if _attr_re != null:
		return
	_attr_re = RegEx.create_from_string("(\\w+)=(?:\"([^\"]*)\"|(ExtResource\\(\"[^\"]*\"\\)))")
	_ext_re = RegEx.create_from_string("path=\"([^\"]+)\".*id=\"([^\"]+)\"")
	_sub_re = RegEx.create_from_string("type=\"([^\"]+)\".*id=\"([^\"]+)\"")
