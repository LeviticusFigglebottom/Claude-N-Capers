## Teammate panels: name, health/armor bars, state, downs, carried bag. One per model.crew entry.
class_name TeammatePanels
extends HudWidget

## Info line (downs / state / bag) font size in canvas units: 21 = 14 px at 1280x720 (PQ-B-14).
const INFO_FONT_SIZE: int = 21

var list_box: VBoxContainer
## slot -> name Label (tests).
var name_labels: Dictionary = {}
## slot -> CrewStateBadge (lead queue b; hidden while the teammate is fine) (tests).
var badges: Dictionary = {}
## slot -> "PAIRED" Label, shown on the teammate your gas dispenser tagged (ui_hud v1.21 perk_item.partner_slot) (tests).
var paired_labels: Dictionary = {}
## slot -> heister id (Hud.set_crew_heisters); unknown slots use the model's name.
var heisters: Dictionary = {}

## Row key (slots + heisters) the rows were built for; slot -> {heister, name, armor, health, info, badge}.
var _rows_key: String = "-"
var _rows: Dictionary = {}


func build() -> void:
	list_box = UiBuild.vbox(6)
	add_child(list_box)


func watched_signals() -> Array[StringName]:
	return [&"crew_changed", &"perk_item_changed"]


func refresh() -> void:
	var crew: Array = prop(&"crew", []) as Array
	# Perf (lead, A's gh_stealth run): crew_changed fires whenever a teammate's health or bleedout ticks, so
	# rows are rebuilt only when the crew's slots / heisters change and updated in place otherwise.
	var sig: PackedStringArray = PackedStringArray()
	for m: Dictionary in crew:
		var slot: int = int(m.get("slot", -1))
		sig.append("%d:%s" % [slot, heisters.get(slot, &"")])
	var key: String = "%d|%s" % [tweak.get_instance_id() if tweak != null else 0, ",".join(sig)]  # a palette swap rebuilds
	if key != _rows_key:
		_rows_key = key
		for c: Node in list_box.get_children():
			list_box.remove_child(c)
			c.queue_free()
		name_labels.clear()
		badges.clear()
		paired_labels.clear()
		_rows.clear()
		for m: Dictionary in crew:
			list_box.add_child(_panel(m))
	var partner: int = int((prop(&"perk_item", {}) as Dictionary).get("partner_slot", -1))
	for m: Dictionary in crew:
		_update_row(m)
		var slot: int = int(m.get("slot", -1))
		if paired_labels.has(slot):
			(paired_labels[slot] as Label).visible = partner >= 0 and slot == partner


## PO-4 frameless row (lead note 1): the heister's colour as a thin edge, the heister's name (the model
## name when no heister is known), two thin bars, and an info line only when something needs
## attention (downed, custody, civilian, carrying a bag, last down) in the alert colour.
func _panel(m: Dictionary) -> PanelContainer:
	var slot: int = int(m.get("slot", -1))
	var heister: StringName = StringName(heisters.get(slot, &""))
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	var edge: ColorRect = ColorRect.new()
	edge.color = Heisters.accent(heister) if heister != &"" else tweak.ally_color
	edge.custom_minimum_size = Vector2(3, 0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(edge)
	var v: VBoxContainer = UiBuild.vbox(3)
	row.add_child(v)
	var name_label: Label = UiBuild.scrim_label(UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD)))
	name_label.add_theme_font_size_override(&"font_size", INFO_FONT_SIZE)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # the scrim hugs the name (r249 contrast)
	var name_row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)
	var paired: Label = UiBuild.scrim_label(UiBuild.float_text(UiBuild.label(&"ui.hud.paired", UiBuild.HUD)))
	paired.add_theme_font_size_override(&"font_size", INFO_FONT_SIZE)
	paired.add_theme_color_override(&"font_color", UiTokens.CYAN)
	paired.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	paired.visible = false
	name_row.add_child(paired)
	v.add_child(name_row)
	name_labels[slot] = name_label
	paired_labels[slot] = paired
	var armor_bar: ProgressBar = UiBuild.hud_bar(tweak.armor_color, Vector2(160, 3))
	v.add_child(armor_bar)
	var health_bar: ProgressBar = UiBuild.hud_bar(tweak.health_color, Vector2(160, 5))
	v.add_child(health_bar)
	# r266 B top-3 #1: the status line (Downed / In custody / Last down) sits on the label scrim, as the name does: red on
	# a bright scene measured 1.99:1 fill. Hidden when empty, so no empty scrim shows.
	var info_label: Label = UiBuild.scrim_label(UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD)),
			UiBuild.LABEL_SCRIM_STRONG_ALPHA)
	info_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# PQ-B-14: INFO_FONT_SIZE keeps >= 14 px at 720p; wraps instead of spilling out of the row.
	info_label.add_theme_font_size_override(&"font_size", INFO_FONT_SIZE)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(200, 0)
	v.add_child(info_label)
	var badge: CrewStateBadge = CrewStateBadge.new()
	badge.danger_color = tweak.low_health_color
	badge.ally_color = tweak.ally_color
	row.add_child(badge)
	badges[slot] = badge
	var p: PanelContainer = UiBuild.panel(row, UiBuild.HUD_PANEL)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_rows[slot] = {"heister": heister, "name": name_label, "armor": armor_bar, "health": health_bar, "info": info_label,
		"badge": badge}
	return p


## Writes crew entry `m` into its row (texts / values only change when they differ).
func _update_row(m: Dictionary) -> void:
	var slot: int = int(m.get("slot", -1))
	var r: Dictionary = _rows.get(slot, {}) as Dictionary
	if r.is_empty():
		return
	var heister: StringName = StringName(r["heister"])
	_set_text(r["name"] as Label, Heisters.display_name(heister) if heister != &"" else String(m.get("name", "")))
	(r["armor"] as ProgressBar).value = float(m.get("armor_frac", 0.0))
	(r["health"] as ProgressBar).value = float(m.get("health_frac", 0.0))
	var info: Array[String] = []
	var downs: int = int(m.get("downs_left", 0))
	var st: int = int(m.get("state", Enums.CrewState.NORMAL))
	if st == Enums.CrewState.CUSTODY:
		info.append(UiText.t(&"ui.hud.custody"))
	elif st != Enums.CrewState.NORMAL:
		var bleed: float = float(m.get("bleedout_s", -1.0))
		info.append(UiText.t(&"ui.hud.downed_seconds", {"seconds": ceili(bleed)}) if bleed > 0.0 else UiText.t(&"ui.hud.downed"))
	elif downs <= 1:
		info.append(UiText.t(&"ui.hud.downs_left", {"count": downs}))
	if StringName(m.get("mode", &"")) == &"civilian":
		info.append(UiText.t(&"ui.hud.civilian"))  # v1.6 (D-065)
	var loot: StringName = StringName(m.get("carried_loot_id", &""))
	if loot != &"":
		info.append(UiText.t(&"ui.hud.carrying", {"loot": UiText.t(UiText.item_key(loot))}))
	var info_label: Label = r["info"] as Label
	_set_text(info_label, "  ".join(info))
	info_label.visible = not info.is_empty()
	var col: Color = tweak.low_health_color if st != Enums.CrewState.NORMAL else UiTokens.PAPER_DIM
	if info_label.get_theme_color(&"font_color") != col:
		info_label.add_theme_color_override(&"font_color", col)
	(r["badge"] as CrewStateBadge).set_row(m)


static func _set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t
