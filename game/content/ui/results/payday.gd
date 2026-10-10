## Payday / results screen (pd2_fidelity C6, S10.4; D-020, D-022). Owner: ENV B.
##
## show_result(result) takes a HeistResult (contracts/events.md), runs PayoutCalculator.compute for
## the local crew slot with the profile's banked stealth bonus, lists the cash breakdown and the XP
## lines in C6 order with level progress (XpCurve), crew stats, then applies the payout to the
## profile (SaveService.apply_heist_payout + save_profile) once per shown result.
## With `listen_heist_ended` it shows itself on EventBus.heist_ended (in-heist use).
## Continue emits continue_pressed; if nobody listens it returns to the main menu scene.
class_name PaydayScreen
extends UiScreen

signal continue_pressed()

const MENU_SCENE: String = "res://content/ui/menus/menu_flow.tscn"

@export var listen_heist_ended: bool = false
@export var apply_to_profile: bool = true
@export var profile_slot: int = 0

var profile: PlayerProfile
## PayoutCalculator.compute output for the shown result.
var payout: Dictionary = {}
var result: Dictionary = {}
## Line id -> value Label (ids: contract, loot, small_loot, crew_alive, civilian_penalty, total,
## stash, spending, xp.<key>, xp_total, level).
var value_labels: Dictionary = {}
var level_bar: ProgressBar
var continue_button: Button
var xp_before: int = 0
var xp_after: int = 0
var _content: VBoxContainer
var _applied: bool = false


func setup(p: PlayerProfile) -> void:
	profile = p


func build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()  # opaque over the map when shown in-heist
	backdrop.color = Color(0.04, 0.045, 0.055, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var root: VBoxContainer = UiBuild.vbox(16)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.label(&"ui.results.title", UiBuild.HEADER))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_content = UiBuild.vbox(20)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	continue_button = UiBuild.button(&"ui.results.continue")
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	continue_button.pressed.connect(_on_continue)
	root.add_child(continue_button)
	focus_chain.append(continue_button)
	back_requested.connect(_on_continue)
	if listen_heist_ended and not EventBus.heist_ended.is_connected(_on_heist_ended):
		EventBus.heist_ended.connect(_on_heist_ended)
	if not result.is_empty():
		_render()


## Show a HeistResult. Computes the payout and (unless apply_to_profile is false) banks it.
func show_result(heist_result: Dictionary) -> void:
	result = heist_result
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	payout = compute_payout(result, profile, Net.local_slot())
	xp_before = profile.xp
	xp_after = xp_before + int(payout.get("xp_total", 0))
	_applied = false
	if apply_to_profile:
		_apply()
	if _content != null:
		_render()


## PayoutCalculator.compute for `crew_slot` with the profile's banked stealth multiplier (D-022).
static func compute_payout(heist_result: Dictionary, p: PlayerProfile, crew_slot: int) -> Dictionary:
	var banked: float = p.banked_stealth_mult if p != null else 1.0
	var xp_mult: float = 1.0
	if p != null:
		var mods: Dictionary = LoadoutResolver.resolve(p.loadout).modifiers
		xp_mult = float(mods.get(&"progression.xp_mult", 1.0))
	return PayoutCalculator.compute(heist_result, null, null, false, crew_slot, banked, xp_mult)


func _apply() -> void:
	if _applied:
		return
	_applied = true
	SaveService.apply_heist_payout(profile, payout, XpCurve.level_for_xp)
	profile.add_stat("heists_completed" if bool(payout.get("success", false)) else "heists_failed")
	SaveService.save_profile(profile, profile_slot)


func _render() -> void:
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	value_labels.clear()
	var success: bool = bool(payout.get("success", false))
	_content.add_child(UiBuild.label(&"ui.results.success" if success else &"ui.results.failure", UiBuild.SUBHEADER))
	var summary: Array[String] = [
		UiText.t(&"ui.results.stealth" if bool(result.get("stealth", false)) else &"ui.results.loud"),
		UiText.t(&"ui.results.time", {"time": UiText.clock(float(result.get("time_s", 0.0)))}),
		UiText.t(&"ui.results.pagers_answered", {"count": int(result.get("pagers_answered", 0))}),
		UiText.t(UiText.difficulty_key(int(result.get("difficulty", 0)))),
	]
	_content.add_child(UiBuild.label(StringName("  |  ".join(summary))))
	var cols: HBoxContainer = UiBuild.hbox(40)
	_content.add_child(cols)
	cols.add_child(UiBuild.panel(_build_cash()))
	cols.add_child(UiBuild.panel(_build_xp()))
	_content.add_child(UiBuild.panel(_build_stats()))
	focus_default()


func _build_cash() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(6)
	v.custom_minimum_size = Vector2(560, 0)
	v.add_child(UiBuild.label(&"ui.results.cash_header", UiBuild.SUBHEADER))
	var grid: GridContainer = _grid(v)
	_line(grid, &"contract", UiText.t(&"ui.results.contract"), UiText.money(int(payout.get("contract", 0))))
	for line: Dictionary in _grouped_loot():
		var loot_name: String = UiText.t(UiText.item_key(StringName(line["loot_id"])))
		_line(grid, StringName("loot." + String(line["loot_id"])),
				UiText.t(&"ui.results.loot_line", {"loot": loot_name, "count": line["count"]}), UiText.money(int(line["value"])))
	_line(grid, &"small_loot", UiText.t(&"ui.results.small_loot"), UiText.money(int(payout.get("small_loot", 0))))
	var mult: float = float(payout.get("crew_alive_mult", 1.0))
	var bonus: int = int(payout.get("gross", 0)) - int(payout.get("subtotal", 0))
	_line(grid, &"crew_alive", UiText.t(&"ui.results.crew_alive", {"mult": "%.2f" % mult}), UiText.money(bonus))
	_line(grid, &"civilian_penalty", UiText.t(&"ui.results.civilian_penalty"),
			UiText.money(-int(payout.get("civilian_penalty", 0))))
	_line(grid, &"total", UiText.t(&"ui.results.total"), UiText.money(int(payout.get("total", 0))))
	_line(grid, &"stash", UiText.t(&"ui.results.stash"), UiText.money(int(payout.get("stash", 0))))
	_line(grid, &"spending", UiText.t(&"ui.results.spending"), UiText.money(int(payout.get("spending", 0))))
	return v


func _build_xp() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(6)
	v.custom_minimum_size = Vector2(560, 0)
	v.add_child(UiBuild.label(&"ui.results.xp_header", UiBuild.SUBHEADER))
	var grid: GridContainer = _grid(v)
	for line: Dictionary in payout.get("xp_lines", []) as Array:
		var key: StringName = StringName(line["key"])
		_line(grid, StringName("xp." + String(key)), UiText.t(key), UiText.group_digits(int(line["amount"])))
	_line(grid, &"xp_total", UiText.t(&"ui.results.xp_total"), UiText.group_digits(int(payout.get("xp_total", 0))))
	var banked: float = float(payout.get("stealth_bonus_banked", 0.0))
	if banked > 1.0:
		v.add_child(UiBuild.label(&"ui.results.stealth_bonus_banked", UiBuild.DIM,
				{"pct": roundi((banked - 1.0) * 100.0)}))
	var level_before: int = XpCurve.level_for_xp(xp_before)
	var level_after: int = XpCurve.level_for_xp(xp_after)
	var lvl: Label = UiBuild.label(&"ui.menu.level", &"", {"level": level_after})
	value_labels[&"level"] = lvl
	v.add_child(lvl)
	level_bar = UiBuild.bar(Color(1.0, 0.8, 0.35), Vector2(480, 16))
	level_bar.value = _level_progress(xp_after)
	v.add_child(level_bar)
	if level_after > level_before:
		v.add_child(UiBuild.label(&"ui.results.level_up", UiBuild.SUBHEADER, {"level": level_after}))
	return v


func _build_stats() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(6)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 36)
	v.add_child(grid)
	for key: StringName in [&"ui.results.crew", &"ui.results.kills", &"ui.results.specials_killed",
			&"ui.results.downs", &"ui.results.civilians_killed"]:
		grid.add_child(UiBuild.label(key, UiBuild.DIM))
	for member: Dictionary in result.get("crew", []) as Array:
		var slot: int = int(member.get("slot", 0))
		grid.add_child(UiBuild.label(StringName(_crew_name(slot, bool(member.get("is_ai", false))))))
		for k: String in ["kills", "specials_killed", "downs", "civilians_killed"]:
			grid.add_child(UiBuild.label(StringName(str(int(member.get(k, 0))))))
	return v


func _grid(parent: Container) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override(&"h_separation", 32)
	parent.add_child(g)
	return g


func _line(grid: GridContainer, id: StringName, caption: String, value: String) -> void:
	var c: Label = UiBuild.label()
	c.text = caption
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: Label = UiBuild.label()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(c)
	grid.add_child(v)
	value_labels[id] = v


## payout.loot_lines grouped by loot id in first-seen order: [{loot_id, count, value}].
func _grouped_loot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index: Dictionary = {}
	for line: Dictionary in payout.get("loot_lines", []) as Array:
		var id: StringName = StringName(line["loot_id"])
		if not index.has(id):
			index[id] = out.size()
			out.append({"loot_id": id, "count": 0, "value": 0})
		var g: Dictionary = out[int(index[id])]
		g["count"] = int(g["count"]) + 1
		g["value"] = int(g["value"]) + int(line["value"])
	return out


func _crew_name(slot: int, is_ai: bool) -> String:
	if Net.crew.has(slot):
		return String(Net.crew[slot].get("display_name", ""))
	return UiText.t(&"ui.results.crew_ai" if is_ai else &"ui.results.crew_slot", {"slot": slot + 1})


static func _level_progress(xp: int) -> float:
	var level: int = XpCurve.level_for_xp(xp)
	if level >= XpCurve.max_level():
		return 1.0
	var step: int = XpCurve.step_xp(level + 1)
	return clampf(float(xp - XpCurve.xp_for_level(level)) / float(maxi(step, 1)), 0.0, 1.0)


func _on_heist_ended(heist_result: Dictionary) -> void:
	show_result(heist_result)
	show()


func _on_continue() -> void:
	if continue_pressed.get_connections().is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	continue_pressed.emit()
