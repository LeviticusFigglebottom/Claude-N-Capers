## Ammo (mag / reserve of the equipped slot) and equipment counts (deployable, throwable, cable
## ties, body bags) as glyph + count chips. Hidden until masked (civilian: no gear, S1.3 / D-065; casing: no weapon out).
## D-161: with a Hacker pocket ECM (`pocket_ecm` non-empty) the throwable chip shows its charges and a caption: the
## jam / feedback seconds left while active, else the next charge's recharge.
## D-106 (ui_hud 1.12): while `reloading`, a RELOADING caption and a thin bar under the ammo line fill
## with `reload_progress` (read every frame while it runs; -1 / missing = an indeterminate full bar).
class_name AmmoPanel
extends HudWidget

var ammo_label: Label
## Lead queue (d): one right-aligned row of [glyph count] chips (deployable, throwable, cable ties, body
## bags) instead of four text lines. chips: key -> {icon: EquipmentIcon, count: Label} (tests).
var equipment_row: HBoxContainer
var chips: Dictionary = {}
## Reload indicator row (caption + bar), shown only while reloading (tests).
var reload_row: HBoxContainer
var reload_bar: ProgressBar
## D-161 pocket ECM caption inside the throwable chip (tests).
var pocket_label: Label


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
	reload_row = UiBuild.hbox(UiTokens.S2)
	reload_row.alignment = BoxContainer.ALIGNMENT_END
	reload_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reload_row.add_child(UiBuild.float_text(UiBuild.caption(&"ui.hud.reloading")))
	reload_bar = UiBuild.bar(UiTokens.PAPER, Vector2(160, 6))
	reload_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reload_bar.max_value = 1.0
	reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reload_row.add_child(reload_bar)
	reload_row.visible = false
	v.add_child(reload_row)
	equipment_row = UiBuild.hbox(UiTokens.S4)
	equipment_row.alignment = BoxContainer.ALIGNMENT_END
	equipment_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(equipment_row)
	for key: StringName in [&"deployable", &"throwable", &"cable_ties", &"body_bags"]:
		_chip(key)
	pocket_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	pocket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pocket_label.visible = false
	var gap: MarginContainer = MarginContainer.new()  # keeps the caption off the charge count
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.visible = false
	gap.add_theme_constant_override(&"margin_left", UiTokens.S2)
	gap.add_child(pocket_label)
	(chips[&"throwable"]["box"] as HBoxContainer).add_child(gap)


func watched_signals() -> Array[StringName]:
	return [&"ammo_changed", &"inventory_changed", &"player_mode_changed", &"pocket_ecm_changed"]


func refresh() -> void:
	# PO-1 (P): no weapon is drawn until you mask up, so the weapon HUD shows only when masked (PD2);
	# models without a mode (pre-v1.6, loading) keep it visible.
	var mode: StringName = player_mode()
	visible = mode == &"masked" or mode == &""
	var slots: Dictionary = prop(&"ammo", {}) as Dictionary
	var slot: int = int(prop(&"equipped_slot", Enums.WeaponSlot.SECONDARY))
	var a: Dictionary = slots.get(slot, {}) as Dictionary
	ammo_label.text = UiText.t(&"ui.hud.ammo", {"mag": int(a.get("mag", 0)), "reserve": int(a.get("reserve", 0))})
	reload_row.visible = bool(prop(&"reloading", false))
	set_process(reload_row.visible)
	_update_reload()
	var dep: StringName = StringName(prop(&"deployable_id", &""))
	_set_chip(&"deployable", EquipmentIcon.kind_for(dep), int(prop(&"deployable_count", 0)), dep != &"",
			UiText.t(UiText.item_key(dep)) if dep != &"" else "")
	var thr: StringName = StringName(prop(&"throwable_id", &""))
	var pocket: Dictionary = prop(&"pocket_ecm", {}) as Dictionary
	if pocket.is_empty():
		_set_chip(&"throwable", EquipmentIcon.kind_for(thr), int(prop(&"throwable_count", 0)), thr != &"",
				UiText.t(UiText.item_key(thr)) if thr != &"" else "")
		_show_pocket_caption(false)
	else:
		_set_chip(&"throwable", &"pocket_ecm", int(pocket.get("charges", 0)), true,
				UiText.t(UiText.item_key(&"throwable.pocket_ecm")))
		_update_pocket(pocket)
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


## Caption: "JAM 4 s" / "FEEDBACK 4 s" while a charge runs, else "+1 in 38 s" while one recharges, else nothing.
func _update_pocket(pocket: Dictionary) -> void:
	var active: float = float(pocket.get("active_left", 0.0))
	var mode: StringName = StringName(pocket.get("mode", &""))
	var recharge: float = float(pocket.get("recharge_left", 0.0))
	var text: String = ""
	if active > 0.0 and mode != &"":
		text = UiText.t(StringName("ui.hud.pocket_ecm." + String(mode)), {"s": ceili(active)})
	elif recharge > 0.0:
		text = UiText.t(&"ui.hud.pocket_ecm.recharge", {"s": ceili(recharge)})
	pocket_label.text = text
	_show_pocket_caption(text != "")
	pocket_label.add_theme_color_override(&"font_color", UiTokens.CYAN if active > 0.0 else UiTokens.PAPER_DIM)


func _show_pocket_caption(on: bool) -> void:
	pocket_label.visible = on
	(pocket_label.get_parent() as Control).visible = on


func _process(_delta: float) -> void:
	_update_reload()


func _update_reload() -> void:
	if not reload_row.visible:
		return
	var p: float = float(prop(&"reload_progress", -1.0))
	reload_bar.value = clampf(p, 0.0, 1.0) if p >= 0.0 else 1.0
