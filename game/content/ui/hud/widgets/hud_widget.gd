## Base for HUD widgets. Owner: ENV B. A widget reads ONLY the local HUD model (ENV A's
## LocalHudModel, or MockHudModel in the demo/tests; contracts/ui_hud.md v1.1) and EventBus. The model is duck-typed:
## properties are read with get(), change signals are connected by name, missing ones are skipped.
class_name HudWidget
extends Control

var model: Node = null
var tweak: HudTweak = null
var _connections: Dictionary = {}  # signal name -> Callable


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if tweak == null:
		tweak = HudTweak.load_default()
	build()
	refresh()


## Override: child controls.
func build() -> void:
	pass


## B5-01: switch to `t` (an accessibility palette applied to HudTweak, HudPaletteSet) and rebuild the
## child controls so every colour taken at build time follows.
func set_tweak(t: HudTweak) -> void:
	tweak = t if t != null else HudTweak.load_default()
	if not is_node_ready():
		return
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	build()
	refresh()
	queue_redraw()


## Override: model signal names that should trigger refresh().
func watched_signals() -> Array[StringName]:
	return []


## Override: re-read the model and update the controls.
func refresh() -> void:
	pass


func bind(m: Node) -> void:
	unbind()
	model = m
	if model != null:
		for s: StringName in watched_signals():
			if model.has_signal(s):
				# Signals may carry arguments on the real model; refresh() ignores them.
				var cb: Callable = refresh.unbind(_arg_count(model, s)) if _arg_count(model, s) > 0 else refresh
				model.connect(s, cb)
				_connections[s] = cb
	if is_node_ready():
		refresh()


func unbind() -> void:
	if model != null and is_instance_valid(model):
		for s: Variant in _connections:
			if model.is_connected(StringName(s), _connections[s] as Callable):
				model.disconnect(StringName(s), _connections[s] as Callable)
	_connections.clear()
	model = null


## Model property or `fallback` when unbound / missing.
func prop(name_id: StringName, fallback: Variant = null) -> Variant:
	if model == null or not is_instance_valid(model):
		return fallback
	var v: Variant = model.get(name_id)
	return fallback if v == null else v


static func _arg_count(obj: Object, signal_name: StringName) -> int:
	for sig: Dictionary in obj.get_signal_list():
		if StringName(sig["name"]) == signal_name:
			return (sig["args"] as Array).size()
	return 0
