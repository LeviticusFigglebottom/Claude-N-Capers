## Teammate panels: name, health/armor bars, state, downs, carried bag. One per model.crew entry.
class_name TeammatePanels
extends HudWidget

## Info line (downs / state / bag) font size in canvas units: 21 = 14 px at 1280x720 (PQ-B-14).
const INFO_FONT_SIZE: int = 21

var list_box: VBoxContainer
## slot -> name Label (tests).
var name_labels: Dictionary = {}


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
	for m: Dictionary in prop(&"crew", []) as Array:
		list_box.add_child(_panel(m))


## PO-4 compact row: name over two thin bars; the info line appears only when something needs
## attention (downed, custody, civilian, carrying a bag, last down).
func _panel(m: Dictionary) -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(3)
	var name_label: Label = UiBuild.label(&"", UiBuild.HUD)
	name_label.text = String(m.get("name", ""))
	name_label.add_theme_font_size_override(&"font_size", INFO_FONT_SIZE)
	name_label.add_theme_constant_override(&"outline_size", 0)
	v.add_child(name_label)
	name_labels[int(m.get("slot", -1))] = name_label
	var armor_bar: ProgressBar = UiBuild.bar(tweak.armor_color, Vector2(180, 4))
	armor_bar.value = float(m.get("armor_frac", 0.0))
	v.add_child(armor_bar)
	var health_bar: ProgressBar = UiBuild.bar(tweak.health_color, Vector2(180, 6))
	health_bar.value = float(m.get("health_frac", 0.0))
	v.add_child(health_bar)
	var info: Array[String] = []
	var downs: int = int(m.get("downs_left", 0))
	var st: int = int(m.get("state", Enums.CrewState.NORMAL))
	if st == Enums.CrewState.CUSTODY:
		info.append(UiText.t(&"ui.hud.custody"))
	elif st != Enums.CrewState.NORMAL:
		info.append(UiText.t(&"ui.hud.downed"))
	elif downs <= 1:
		info.append(UiText.t(&"ui.hud.downs_left", {"count": downs}))
	if StringName(m.get("mode", &"")) == &"civilian":
		info.append(UiText.t(&"ui.hud.civilian"))  # v1.6 (D-065)
	var loot: StringName = StringName(m.get("carried_loot_id", &""))
	if loot != &"":
		info.append(UiText.t(&"ui.hud.carrying", {"loot": UiText.t(UiText.item_key(loot))}))
	if not info.is_empty():
		var info_label: Label = UiBuild.label(&"", UiBuild.HUD)
		info_label.text = "  ".join(info)
		# PQ-B-14: INFO_FONT_SIZE keeps >= 14 px at 720p; wraps instead of spilling out of the panel.
		info_label.add_theme_font_size_override(&"font_size", INFO_FONT_SIZE)
		info_label.add_theme_constant_override(&"outline_size", 0)
		info_label.add_theme_color_override(&"font_color", tweak.low_health_color if st != Enums.CrewState.NORMAL else UiTokens.PAPER_DIM)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(info_label)
	var p: PanelContainer = UiBuild.panel(v, UiBuild.HUD_PANEL)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p
