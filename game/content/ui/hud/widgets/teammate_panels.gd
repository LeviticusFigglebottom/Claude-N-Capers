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
## slot -> heister id (Hud.set_crew_heisters); unknown slots use the model's name.
var heisters: Dictionary = {}


func build() -> void:
	list_box = UiBuild.vbox(6)
	add_child(list_box)


func watched_signals() -> Array[StringName]:
	return [&"crew_changed"]


func refresh() -> void:
	for c: Node in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	name_labels.clear()
	badges.clear()
	for m: Dictionary in prop(&"crew", []) as Array:
		list_box.add_child(_panel(m))


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
	var name_label: Label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	name_label.text = Heisters.display_name(heister) if heister != &"" else String(m.get("name", ""))
	name_label.add_theme_font_size_override(&"font_size", INFO_FONT_SIZE)
	v.add_child(name_label)
	name_labels[slot] = name_label
	var armor_bar: ProgressBar = UiBuild.bar(tweak.armor_color, Vector2(160, 3))
	armor_bar.value = float(m.get("armor_frac", 0.0))
	v.add_child(armor_bar)
	var health_bar: ProgressBar = UiBuild.bar(tweak.health_color, Vector2(160, 5))
	health_bar.value = float(m.get("health_frac", 0.0))
	v.add_child(health_bar)
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
	if not info.is_empty():
		var info_label: Label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
		info_label.text = "  ".join(info)
		# PQ-B-14: INFO_FONT_SIZE keeps >= 14 px at 720p; wraps instead of spilling out of the row.
		info_label.add_theme_font_size_override(&"font_size", INFO_FONT_SIZE)
		info_label.add_theme_color_override(&"font_color", tweak.low_health_color if st != Enums.CrewState.NORMAL else UiTokens.PAPER_DIM)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_label.custom_minimum_size = Vector2(200, 0)
		v.add_child(info_label)
	var badge: CrewStateBadge = CrewStateBadge.new()
	badge.danger_color = tweak.low_health_color
	badge.ally_color = tweak.ally_color
	badge.set_row(m)
	row.add_child(badge)
	badges[slot] = badge
	var p: PanelContainer = UiBuild.panel(row, UiBuild.HUD_PANEL)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p
