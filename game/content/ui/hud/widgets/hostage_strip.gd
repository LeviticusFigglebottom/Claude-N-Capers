## Hostages + trade (lead round 64, PD2): top centre, right of the assault banner. A hostage glyph and
## the count while there are hostages, and under it the trade state while a crew member is in custody
## (any crew row in CrewState.CUSTODY, or the local player's custody.in_custody):
##   "Trade ready"           OK green  - hostages > 0 and no assault running (NONE / CONTROL)
##   "Trade after the assault" WARN    - hostages > 0 during an assault
##   "Take a hostage to trade" alert   - no hostages
## Owner: ENV B.
class_name HostageStrip
extends HudWidget

var icon: EquipmentIcon
var count_label: Label
var trade_label: Label
## &"" / &"ready" / &"wait" / &"need" (tests).
var trade: StringName = &""


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var h: HBoxContainer = UiBuild.hbox(UiTokens.S1)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	icon = EquipmentIcon.new(&"hostage", 30.0)
	h.add_child(icon)
	count_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	count_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	h.add_child(count_label)
	trade_label = UiBuild.float_text(UiBuild.caption())
	v.add_child(trade_label)


func watched_signals() -> Array[StringName]:
	return [&"hostages_changed", &"crew_changed", &"custody_changed", &"assault_changed"]


func someone_in_custody() -> bool:
	if bool((prop(&"custody", {}) as Dictionary).get("in_custody", false)):
		return true
	for m: Dictionary in prop(&"crew", []) as Array:
		if int(m.get("state", Enums.CrewState.NORMAL)) == Enums.CrewState.CUSTODY:
			return true
	return false


func refresh() -> void:
	if count_label == null:
		return
	var n: int = int(prop(&"hostages", 0))
	var custody: bool = someone_in_custody()
	var phase: int = int(prop(&"assault_phase", Enums.AssaultPhase.NONE))
	var assault: bool = phase != Enums.AssaultPhase.NONE and phase != Enums.AssaultPhase.CONTROL
	count_label.text = str(n)
	count_label.get_parent().visible = n > 0
	trade = &""
	if custody:
		trade = &"need" if n <= 0 else (&"wait" if assault else &"ready")
	trade_label.visible = trade != &""
	match trade:
		&"ready":
			trade_label.text = UiText.t(&"ui.hud.trade_ready")
			trade_label.add_theme_color_override(&"font_color", UiTokens.OK)
		&"wait":
			trade_label.text = UiText.t(&"ui.hud.trade_wait")
			trade_label.add_theme_color_override(&"font_color", UiTokens.WARN)
		&"need":
			trade_label.text = UiText.t(&"ui.hud.trade_need")
			trade_label.add_theme_color_override(&"font_color", UiTokens.ALERT)
	visible = n > 0 or trade != &""
