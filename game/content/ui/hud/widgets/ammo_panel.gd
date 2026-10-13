## Ammo (mag / reserve of the equipped slot) and equipment counts (deployable, throwable, cable
## ties, body bags) as glyph + count chips. Hidden until masked (civilian: no gear, S1.3 / D-065; casing: no weapon out).
class_name AmmoPanel
extends HudWidget

var ammo_label: Label
## Lead queue (d): one right-aligned row of [glyph count] chips (deployable, throwable, cable ties, body
## bags) instead of four text lines. chips: key -> {icon: EquipmentIcon, count: Label} (tests).
var equipment_row: HBoxContainer
var chips: Dictionary = {}


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(2)
	var p: PanelContainer = UiBuild.panel(v, UiBuild.HUD_PANEL)
	add_child(p)
	# PO-4: hug the bottom-right corner (the frameless text must line up with the screen margin).
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_label = UiBuild.label(&"", UiBuild.HUD_BIG)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(ammo_label)
	equipment_row = UiBuild.hbox(UiTokens.S4)
	equipment_row.alignment = BoxContainer.ALIGNMENT_END
	equipment_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(equipment_row)
	for key: StringName in [&"deployable", &"throwable", &"cable_ties", &"body_bags"]:
		_chip(key)


func watched_signals() -> Array[StringName]:
	return [&"ammo_changed", &"inventory_changed", &"player_mode_changed"]


func refresh() -> void:
	# PO-1 (P): no weapon is drawn until you mask up, so the weapon HUD shows only when masked (PD2);
	# models without a mode (pre-v1.6, loading) keep it visible.
	var mode: StringName = player_mode()
	visible = mode == &"masked" or mode == &""
	var slots: Dictionary = prop(&"ammo", {}) as Dictionary
	var slot: int = int(prop(&"equipped_slot", Enums.WeaponSlot.SECONDARY))
	var a: Dictionary = slots.get(slot, {}) as Dictionary
	ammo_label.text = UiText.t(&"ui.hud.ammo", {"mag": int(a.get("mag", 0)), "reserve": int(a.get("reserve", 0))})
	var dep: StringName = StringName(prop(&"deployable_id", &""))
	_set_chip(&"deployable", EquipmentIcon.kind_for(dep), int(prop(&"deployable_count", 0)), dep != &"",
			UiText.t(UiText.item_key(dep)) if dep != &"" else "")
	var thr: StringName = StringName(prop(&"throwable_id", &""))
	_set_chip(&"throwable", EquipmentIcon.kind_for(thr), int(prop(&"throwable_count", 0)), thr != &"",
			UiText.t(UiText.item_key(thr)) if thr != &"" else "")
	_set_chip(&"cable_ties", &"cable_tie", int(prop(&"cable_ties", 0)), true, UiText.t(&"ui.hud.cable_ties_name"))
	_set_chip(&"body_bags", &"body_bag", int(prop(&"body_bags", 0)), true, UiText.t(&"ui.hud.body_bags_name"))


func _chip(key: StringName) -> void:
	var h: HBoxContainer = UiBuild.hbox(UiTokens.S1)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: EquipmentIcon = EquipmentIcon.new()
	h.add_child(icon)
	var count: Label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(count)
	equipment_row.add_child(h)
	chips[key] = {"box": h, "icon": icon, "count": count}


## Shows chip `key` with glyph `kind` and `n`; an empty (0) chip is dimmed, a missing item hidden.
## `name` is the item's display name (tooltip-like `text` for tests and screen readers).
func _set_chip(key: StringName, kind: StringName, n: int, shown: bool, name: String) -> void:
	var c: Dictionary = chips[key] as Dictionary
	(c["box"] as Control).visible = shown
	var icon: EquipmentIcon = c["icon"] as EquipmentIcon
	if icon.kind != kind:
		icon.kind = kind
		icon.queue_redraw()
	var count: Label = c["count"] as Label
	count.text = str(n)
	(c["box"] as Control).tooltip_text = name
	var col: Color = UiTokens.PAPER if n > 0 else UiTokens.PAPER_DIM
	count.add_theme_color_override(&"font_color", col)
	icon.color = col
