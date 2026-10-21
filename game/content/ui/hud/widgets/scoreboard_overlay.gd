## Tab scoreboard (B6-02; content/docs/scoreboard.md): one row per crew member, Crew AI included, with
## name, kills, specials, civilians, downs, accuracy and headshots. Owner: ENV B.
## Data: the model's `crew_stats` (+ `crew_stats_changed`; proposed to ENV A, MockHudModel has it). A
## counter missing from a row shows "—" (per row: shots / hits / headshots do not exist in ENV A yet).
## A model without `crew_stats` (ENV A's LocalHudModel today) still lists the crew: the local player plus
## `crew` teammates, every counter "—". The local player's row is marked (row `is_local`, else the slot
## of Net.local_slot()): "(you)" tag and the palette's interaction colour; teammates use the ally colour.
## Visibility follows the `scoreboard` InputMap action: shown while held, or flipped on each press when
## GameSettings `controls/scoreboard_mode` is "toggle" (is_toggle(&"scoreboard")).
class_name ScoreboardOverlay
extends HudWidget

const ACTION: StringName = &"scoreboard"
## Name column, then the stat columns in display order (CrewStats ids).
const NAME: StringName = &"name"
const COLUMNS: Array[StringName] = [CrewStats.KILLS, CrewStats.SPECIALS, CrewStats.CIVILIANS, CrewStats.DOWNS,
		CrewStats.ACCURACY, CrewStats.HEADSHOTS]
const HEADER_KEYS: Dictionary = {
	&"name": &"ui.scoreboard.name", &"kills": &"ui.scoreboard.kills", &"specials_killed": &"ui.scoreboard.specials",
	&"civilians_killed": &"ui.scoreboard.civilians", &"downs": &"ui.scoreboard.downs",
	&"accuracy": &"ui.scoreboard.accuracy", &"headshots": &"ui.scoreboard.headshots",
}

## Settings read for hold / toggle (null = GameSettings.current()).
var settings: GameSettings = null
## Whether the action was down at the last update_input() (edge detection for toggle mode).
var held: bool = false
## Rows shown, ordered by slot (CrewStats row dictionaries).
var rows: Array[Dictionary] = []
## slot -> {column id (NAME or a COLUMNS entry) -> Label} (tests).
var cells: Dictionary = {}
## Slot of the row marked as the local player (-1 = none).
var local_slot: int = -1
var grid: GridContainer
## PO-4: every visible objective with its state (the HUD shows only the current one).
var objectives_box: VBoxContainer
## slot -> heister id (Hud.set_crew_heisters): rows name the heister in their colour, like the crew rows.
var heisters: Dictionary = {}
## Lead round 64 (PD2 loot screen): bags secured this run, loot_id -> {count, value}, plus small loot
## (EventBus.loot_secured / small_loot_taken since the HUD was built), listed under the objectives.
var loot_secured: Dictionary = {}
var small_loot_value: int = 0
var loot_box: VBoxContainer
## The sheet panel (Hud keeps objective marker text off it).
var sheet: PanelContainer


func _init() -> void:
	super()
	visible = false


func build() -> void:
	# PO-4: an opaque Case File sheet (the HUD itself is frameless), crew table left, objectives right.
	# r261: tighter gaps (S3 columns, S4 row / sides) so the sheet fits its centred 1,260 box with the teammate panel clear.
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var title: Label = UiBuild.caption(&"ui.scoreboard.title")
	title.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	v.add_child(title)
	grid = GridContainer.new()
	grid.columns = 1 + COLUMNS.size()
	grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	grid.add_theme_constant_override(&"v_separation", UiTokens.S2)
	v.add_child(grid)
	var o: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	o.custom_minimum_size = Vector2(320, 0)
	o.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(o)
	var otitle: Label = UiBuild.caption(&"ui.scoreboard.objectives")
	otitle.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	o.add_child(otitle)
	objectives_box = UiBuild.vbox(UiTokens.S1)
	o.add_child(objectives_box)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.S3)
	o.add_child(gap)
	var ltitle: Label = UiBuild.caption(&"ui.scoreboard.loot")
	ltitle.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	o.add_child(ltitle)
	loot_box = UiBuild.vbox(UiTokens.S1)
	o.add_child(loot_box)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", UiThemeFactory.box(Color(UiTokens.INK_1, 0.94), UiTokens.LINE_STRONG, 1,
			UiTokens.CUT, Vector2(UiTokens.S4, UiTokens.S4)))
	p.add_child(row)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)  # as tall as its rows, no empty sheet
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	sheet = p


func watched_signals() -> Array[StringName]:
	return [&"crew_stats_changed", &"crew_changed", &"objectives_changed"]


## Rebuilds the table; skipped while hidden (crew_changed fires often), update_input() refreshes on show.
func refresh() -> void:
	if grid == null or not visible:
		return
	for c: Node in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	cells.clear()
	rows = build_rows()
	local_slot = -1
	_header(NAME)
	for col: StringName in COLUMNS:
		_header(col)
	for r: Dictionary in rows:
		_row(r)
	_fill_objectives()
	_fill_loot()


func _enter_tree() -> void:
	if not EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.connect(_on_loot_secured)
		EventBus.small_loot_taken.connect(_on_small_loot)


func _exit_tree() -> void:
	if EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.disconnect(_on_loot_secured)
		EventBus.small_loot_taken.disconnect(_on_small_loot)


func _on_loot_secured(_bag_net_id: int, loot_id: StringName, value: int) -> void:
	var e: Dictionary = loot_secured.get(loot_id, {"count": 0, "value": 0}) as Dictionary
	e["count"] = int(e["count"]) + 1
	e["value"] = int(e["value"]) + value
	loot_secured[loot_id] = e
	if visible:
		_fill_loot()


func _on_small_loot(value: int, _crew_slot: int) -> void:
	small_loot_value += value
	if visible:
		_fill_loot()


## Bags by type ("Jewelry x2   $26,000"), small loot, then the total; "None yet" before the first bag.
func _fill_loot() -> void:
	if loot_box == null:
		return
	for c: Node in loot_box.get_children():
		loot_box.remove_child(c)
		c.queue_free()
	var ids: Array = loot_secured.keys()
	ids.sort()
	var total: int = small_loot_value
	for id: Variant in ids:
		var e: Dictionary = loot_secured[id] as Dictionary
		total += int(e["value"])
		_loot_line(UiText.t(&"ui.scoreboard.loot_line", {"loot": UiText.t(UiText.item_key(StringName(id))),
				"count": int(e["count"])}), int(e["value"]), UiTokens.PAPER)
	if small_loot_value > 0:
		_loot_line(UiText.t(&"ui.scoreboard.small_loot"), small_loot_value, UiTokens.PAPER)
	if total > 0:
		_loot_line(UiText.t(&"ui.scoreboard.loot_total"), total, UiTokens.BRASS_HI)
	else:
		var none: Label = UiBuild.label(&"ui.scoreboard.loot_none", UiBuild.HUD)
		none.add_theme_constant_override(&"outline_size", 0)
		none.add_theme_color_override(&"font_color", UiTokens.PAPER_DIM)
		loot_box.add_child(none)


func _loot_line(text: String, value: int, col: Color) -> void:
	var h: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	var name_l: Label = UiBuild.label(&"", UiBuild.HUD)
	name_l.text = text
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val: Label = UiBuild.label(&"", UiBuild.HUD)
	val.text = UiText.money(value)
	for l: Label in [name_l, val]:
		l.add_theme_constant_override(&"outline_size", 0)
		l.add_theme_color_override(&"font_color", col)
		h.add_child(l)
	loot_box.add_child(h)


## Every objective but hidden ones: done in OK green, failed in red, the live ones in paper. More than
## HudTweak.scoreboard_objectives_max lines: the done ones fold into one "N done" line, the live ones fill the rest
## and a muted "+N more" line closes the column (the sheet stays on screen). Folding, required steps get the room before
## `optional` ones (D-115 GN audit: six optional "as needed" steps hid Gallery Night's centrepiece / canvases / secure);
## the lines keep the mission's order.
func _fill_objectives() -> void:
	for c: Node in objectives_box.get_children():
		objectives_box.remove_child(c)
		c.queue_free()
	var shown: Array[Dictionary] = []
	var done: int = 0
	for ob: Dictionary in prop(&"objectives", []) as Array:
		var st: int = int(ob.get("state", Enums.ObjectiveState.ACTIVE))
		if st == Enums.ObjectiveState.HIDDEN:
			continue
		shown.append(ob)
		done += int(st == Enums.ObjectiveState.COMPLETED)
	shown = beside_alternatives(shown)
	var cap: int = maxi(tweak.scoreboard_objectives_max, 3) if tweak != null else 8
	var fold: bool = shown.size() > cap
	if fold and done > 0:
		_objective_line(UiText.t(&"ui.scoreboard.objectives_done", {"count": done}), UiTokens.OK)
	var room: int = cap - (1 if fold and done > 0 else 0) - (1 if fold else 0)
	var keep: Dictionary = {}  # index in `shown` -> true when it gets a line (fold only)
	for optional_pass: bool in [false, true]:
		for i: int in range(shown.size()):
			var o: Dictionary = shown[i]
			if room <= 0 or int(o.get("state", Enums.ObjectiveState.ACTIVE)) == Enums.ObjectiveState.COMPLETED:
				continue
			if bool((o.get("args", {}) as Dictionary).get("optional", false)) == optional_pass:
				keep[i] = true
				room -= 1
	var left: int = 0
	for i: int in range(shown.size()):
		var ob: Dictionary = shown[i]
		var st: int = int(ob.get("state", Enums.ObjectiveState.ACTIVE))
		if fold and st == Enums.ObjectiveState.COMPLETED:
			continue
		if fold and not keep.has(i):
			left += 1
			continue
		var disabled: bool = bool((ob.get("args", {}) as Dictionary).get("disabled", false))
		var col: Color = UiTokens.PAPER
		if st == Enums.ObjectiveState.COMPLETED:
			col = UiTokens.OK
		elif st == Enums.ObjectiveState.FAILED:
			col = UiTokens.ALERT
		elif disabled:
			col = UiTokens.PAPER_MUTE
		_objective_line(UiText.t(ObjectivesPanel._state_key(st), {"text": ObjectivesPanel.objective_text(ob)}), col)
	if left > 0:
		_objective_line(UiText.t(&"ui.scoreboard.objectives_more", {"count": left}), UiTokens.PAPER_MUTE)


## Real-input GH run (r231): the model lists an ACTIVE optional step after the last required one (required_first), so
## "Or find the safe code" sat under "Secure two bags", far from the keycard step it replaces. A row whose args name an
## `alternative` that is also listed moves to just after that row; the rest keep their order.
static func beside_alternatives(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var placed: Dictionary = {}
	for r: Dictionary in rows:
		var id: StringName = StringName(r.get("id", &""))
		if placed.has(id):
			continue
		out.append(r)
		placed[id] = true
		var alt: StringName = _alternative_of(r)
		for o: Dictionary in rows:
			var oid: StringName = StringName(o.get("id", &""))
			if not placed.has(oid) and (_alternative_of(o) == id or oid == alt):
				out.append(o)
				placed[oid] = true
	return out


static func _alternative_of(row: Dictionary) -> StringName:
	return StringName((row.get("args", {}) as Dictionary).get("alternative", &""))


func _objective_line(text: String, col: Color) -> void:
	var l: Label = UiBuild.label(&"", UiBuild.HUD)
	l.add_theme_constant_override(&"outline_size", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	l.add_theme_color_override(&"font_color", col)
	objectives_box.add_child(l)


## Feed the `scoreboard` action state (from _process; tests call it directly). Hold: visible while
## pressed. Toggle: each press flips visibility.
func update_input(pressed: bool) -> void:
	var was: bool = visible
	if is_toggle_mode():
		if pressed and not held:
			visible = not visible
	else:
		visible = pressed
	held = pressed
	if visible and not was:
		refresh()


## Show / hide directly (tests, a future pause-menu tab); a shown overlay is refreshed.
func set_shown(on: bool) -> void:
	var was: bool = visible
	visible = on
	if on and not was:
		refresh()


func is_toggle_mode() -> bool:
	var s: GameSettings = settings if settings != null else GameSettings.current()
	return s.is_toggle(ACTION)


## Rows to show: the model's `crew_stats`, else the local player + `crew` teammates without counters.
func build_rows() -> Array[Dictionary]:
	var stats: Variant = prop(&"crew_stats")
	if stats is Array:
		return CrewStats.by_slot(stats as Array)
	if model == null:
		return []
	var me: int = Net.local_slot()
	var out: Array = [{"slot": me, "name": _net_name(me), "is_ai": false, "is_local": true}]
	for m: Dictionary in prop(&"crew", []) as Array:
		out.append({"slot": int(m.get("slot", -1)), "name": String(m.get("name", "")), "is_ai": bool(m.get("is_ai", false)),
				"is_local": false})
	return CrewStats.by_slot(out)


## Cell text of `column` for `row`: the number, "NN%" for accuracy, "—" when the counter is missing.
static func cell_text(row: Dictionary, column: StringName) -> String:
	if not CrewStats.has_stat(row, column):
		return UiText.t(&"ui.scoreboard.missing")
	if column == CrewStats.ACCURACY:
		return UiText.t(&"ui.scoreboard.pct", {"value": CrewStats.accuracy_pct(row)})
	return str(int(CrewStats.value(row, column)))


static func is_local_row(row: Dictionary) -> bool:
	if row.has("is_local"):
		return bool(row["is_local"])
	return CrewStats.slot_of(row) >= 0 and CrewStats.slot_of(row) == Net.local_slot()


func _process(_delta: float) -> void:
	if InputMap.has_action(ACTION):
		update_input(Input.is_action_pressed(ACTION))


func _header(col: StringName) -> void:
	var l: Label = UiBuild.caption(HEADER_KEYS[col] as StringName)
	if col != NAME:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(l)


func _row(r: Dictionary) -> void:
	var slot: int = CrewStats.slot_of(r)
	var mine: bool = is_local_row(r)
	if mine:
		local_slot = slot
	var row_cells: Dictionary = {}
	var name_label: Label = UiBuild.label(&"", UiBuild.HUD)
	var heister: StringName = StringName(heisters.get(slot, &""))
	if heister != &"":
		r = r.duplicate()
		r["name"] = Heisters.display_name(heister)
	name_label.text = _display_name(r, mine)
	var tint: Color = tweak.interaction_color if mine else tweak.ally_color
	name_label.add_theme_color_override(&"font_color", Heisters.accent(heister) if heister != &"" else tint)
	grid.add_child(name_label)
	row_cells[NAME] = name_label
	for col: StringName in COLUMNS:
		var l: Label = UiBuild.label(&"", UiBuild.HUD)
		l.text = cell_text(r, col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if mine:
			l.add_theme_color_override(&"font_color", tweak.interaction_color)
		grid.add_child(l)
		row_cells[col] = l
	cells[slot] = row_cells


static func _display_name(r: Dictionary, mine: bool) -> String:
	var n: String = String(r.get("name", ""))
	if n == "":
		n = UiText.t(&"ui.results.crew_ai" if CrewStats.is_ai(r) else &"ui.results.crew_slot", {"slot": CrewStats.slot_of(r) + 1})
	if mine:
		return UiText.t(&"ui.scoreboard.you", {"name": n})
	return UiText.t(&"ui.scoreboard.ai", {"name": n}) if CrewStats.is_ai(r) else n


static func _net_name(slot: int) -> String:
	if Net.crew.has(slot):
		return String(Net.crew[slot].get("display_name", ""))
	return ""
