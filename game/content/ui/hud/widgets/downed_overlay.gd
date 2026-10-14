## Downed state (lead queue a, PD2): while the local player is DOWNED (or cloaker-downed) the world goes
## grey and dim (screen shader, faded in over T_SLOW) and the centre shows a caption, the bleedout
## countdown as the big number (ALERT under URGENT_S) and, when a teammate is reviving
## (model `revive_progress` >= 0 and `reviver_slot`, asked of ENV A), "<name> is reviving you" with a bar.
## Without a revive the line reads "Hold on: your crew can revive you". The vitals panel no longer
## repeats the bleedout. Reduce Motion: no fade. Owner: ENV B.
class_name DownedOverlay
extends HudWidget

const URGENT_S: float = 10.0
const SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 d = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.25, 0.75, length(d * vec2(1.2, 1.0)));
	vec3 g = mix(c, vec3(l), 0.85) * (1.0 - 0.45 - 0.3 * edge);
	COLOR = vec4(mix(c, g, amount), 1.0);
}
"""

## slot -> heister id (Hud.set_crew_heisters) for the reviver's name.
var heisters: Dictionary = {}
var grey: ColorRect
var caption: Label
var timer_label: Label
var revive_label: Label
var revive_bar: ProgressBar
## Whether the overlay is up (tests).
var active: bool = false
var _mat: ShaderMaterial
var _fade: Tween = null


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grey = ColorRect.new()
	grey.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	grey.material = _mat
	add_child(grey)
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	# Above the crosshair (PD2): the band below it belongs to the interaction prompt and hint strip.
	v.alignment = BoxContainer.ALIGNMENT_END
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -400.0
	v.offset_right = 400.0
	v.offset_top = -300.0
	v.offset_bottom = -40.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	caption = UiBuild.float_text(UiBuild.caption(&"ui.hud.downed_title"))
	caption.add_theme_color_override(&"font_color", tweak.low_health_color)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(caption)
	timer_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD_BIG))
	timer_label.add_theme_font_override(&"font", UiTokens.font_display())
	timer_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_H1 + 16)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(timer_label)
	revive_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	revive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(revive_label)
	revive_bar = UiBuild.bar(tweak.ally_color, Vector2(320, 6))
	revive_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(revive_bar)
	visible = false


func watched_signals() -> Array[StringName]:
	return [&"vitals_changed", &"crew_changed"]


static func is_helpless(state: int) -> bool:
	return state == Enums.CrewState.DOWNED or state == Enums.CrewState.CLOAKER_DOWNED


func refresh() -> void:
	if grey == null:
		return
	var on: bool = model != null and is_helpless(int(prop(&"crew_state", Enums.CrewState.NORMAL)))
	if on != active:
		active = on
		_show(on)
	if not on:
		return
	var bleed: float = float(prop(&"bleedout_s", -1.0))
	timer_label.visible = bleed > 0.0
	timer_label.text = UiText.t(&"ui.hud.bleedout_big", {"seconds": ceili(bleed)})
	timer_label.add_theme_color_override(&"font_color", tweak.low_health_color if bleed <= URGENT_S else UiTokens.PAPER)
	var prog: float = float(prop(&"revive_progress", -1.0))
	var slot: int = int(prop(&"reviver_slot", -1))
	if prog >= 0.0 and slot >= 0:
		revive_label.text = UiText.t(&"ui.hud.being_revived", {"name": _name(slot)})
		revive_bar.visible = true
		revive_bar.value = clampf(prog, 0.0, 1.0)
	else:
		revive_label.text = UiText.t(&"ui.hud.downed_hint")
		revive_bar.visible = false


func _name(slot: int) -> String:
	if heisters.has(slot):
		return Heisters.display_name(StringName(heisters[slot]))
	for m: Dictionary in prop(&"crew", []) as Array:
		if int(m.get("slot", -1)) == slot:
			return String(m.get("name", ""))
	return UiText.t(&"ui.results.crew_slot", {"slot": slot + 1})


func _show(on: bool) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	visible = true
	var target: float = 1.0 if on else 0.0
	if not UiTokens.motion_ok() or not is_inside_tree():
		_set_amount(target)
		visible = on
		return
	_fade = create_tween()
	_fade.tween_method(_set_amount, 1.0 - target, target, UiTokens.T_SLOW)
	if not on:
		_fade.tween_callback(func() -> void: visible = false)


func _set_amount(a: float) -> void:
	_mat.set_shader_parameter(&"amount", a)
	modulate.a = a
