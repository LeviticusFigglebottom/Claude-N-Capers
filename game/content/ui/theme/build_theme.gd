## Writes caper_theme.tres from UiThemeFactory.build() (PO-4). Run after changing UiTokens:
##   /opt/godot/godot --headless --path game --script res://content/ui/theme/build_theme.gd
## Sub-resource ids are assigned from the theme item names, so the file is stable across runs.
extends SceneTree


func _initialize() -> void:
	var th: Theme = (load("res://content/ui/theme/ui_theme_factory.gd") as GDScript).call(&"build") as Theme
	var seen: Dictionary = {}
	var types: PackedStringArray = th.get_type_list()
	types.sort()
	for type: String in types:
		var names: PackedStringArray = th.get_stylebox_list(type)
		names.sort()
		for n: String in names:
			_name(th.get_stylebox(n, type), "sb_%s_%s" % [type, n], seen)
		var fonts: PackedStringArray = th.get_font_list(type)
		fonts.sort()
		for n: String in fonts:
			_name(th.get_font(n, type), "font_%s" % th.get_font(n, type).resource_name, seen)
	_name(th.default_font, "font_%s" % th.default_font.resource_name, seen)
	var err: Error = ResourceSaver.save(th, "res://content/ui/theme/caper_theme.tres")
	print("build_theme: ", error_string(err))
	quit(0 if err == OK else 1)


func _name(r: Resource, id: String, seen: Dictionary) -> void:
	if r == null or seen.has(r.get_instance_id()):
		return
	seen[r.get_instance_id()] = true
	r.resource_scene_unique_id = id
