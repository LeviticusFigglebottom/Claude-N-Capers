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


func _init() -> void:
	super()
	visible = false


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(10)
	var title: Label = UiBuild.label(&"ui.scoreboard.title", UiBuild.HUD_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	grid = GridContainer.new()
	grid.columns = 1 + COLUMNS.size()
	grid.add_theme_constant_override(&"h_separation", 28)
	grid.add_theme_constant_override(&"v_separation", 6)
	v.add_child(grid)
	var p: PanelContainer = UiBuild.panel(v, UiBuild.HUD_PANEL)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)


func watched_signals() -> Array[StringName]:
	return [&"crew_stats_changed", &"crew_changed"]


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
	var l: Label = UiBuild.label(HEADER_KEYS[col] as StringName, UiBuild.HUD)
	l.add_theme_font_size_override(&"font_size", 18)
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
	name_label.text = _display_name(r, mine)
	name_label.add_theme_color_override(&"font_color", tweak.interaction_color if mine else tweak.ally_color)
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
