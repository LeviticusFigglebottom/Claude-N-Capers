## ImpactFx.surface_of lookup rules (impact_fx.md 1.0 §1): metadata on the collider or up to 3 parents,
## default concrete, characters -> flesh, Wrecker plates -> armor, Bulwark shield -> shield. Headless.
extends TestCase

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)


func after_each() -> void:
	_root.free()
	_root = null


func _body(parent: Node, surface: Variant = null) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	if surface != null:
		b.set_meta(&"surface", surface)
	parent.add_child(b)
	return b


func test_default_and_null_are_concrete() -> void:
	assert_eq(ImpactFx.surface_of(null), &"concrete")
	assert_eq(ImpactFx.surface_of(_body(_root)), &"concrete")
	assert_eq(ImpactFx.surface_of(RefCounted.new()), &"concrete", "non-node object")


func test_metadata_on_collider() -> void:
	for s: StringName in ImpactFx.SURFACES:
		assert_eq(ImpactFx.surface_of(_body(_root, s)), s, String(s))
	assert_eq(ImpactFx.surface_of(_body(_root, "wood")), &"wood", "String metadata works too")
	assert_eq(ImpactFx.surface_of(_body(_root, &"lava")), &"concrete", "unknown id falls back to concrete")


func test_parent_walk_up_to_three() -> void:
	var chain: Array[Node3D] = []
	var p: Node3D = _root
	for i: int in range(4):
		var n: Node3D = RigidBody3D.new() if i == 0 else Node3D.new()
		p.add_child(n)
		chain.append(n)
		p = n
	var hit: StaticBody3D = _body(p)
	# chain[3] is the direct parent (1 up), chain[0] is 4 up.
	chain[1].set_meta(&"surface", &"brick")  # 3 parents up: found
	assert_eq(ImpactFx.surface_of(hit), &"brick")
	chain[1].remove_meta(&"surface")
	chain[0].set_meta(&"surface", &"metal")  # 4 parents up: out of range
	assert_eq(ImpactFx.surface_of(hit), &"concrete")
	chain[3].set_meta(&"surface", &"glass")  # nearest wins
	chain[2].set_meta(&"surface", &"tile")
	assert_eq(ImpactFx.surface_of(hit), &"glass")
	hit.set_meta(&"surface", &"wood")  # collider itself beats parents
	assert_eq(ImpactFx.surface_of(hit), &"wood")


func test_characters_are_flesh() -> void:
	var npc: CharacterBody3D = CharacterBody3D.new()
	npc.add_to_group(G.NPC)
	_root.add_child(npc)
	assert_eq(ImpactFx.surface_of(npc), &"flesh", "NPC body")
	var boxes: Node3D = Node3D.new()
	npc.add_child(boxes)
	var area: Area3D = Area3D.new()
	boxes.add_child(area)
	assert_eq(ImpactFx.surface_of(area), &"flesh", "area under an NPC")
	var crew: CharacterBody3D = CharacterBody3D.new()
	crew.add_to_group(G.CREW)
	_root.add_child(crew)
	assert_eq(ImpactFx.surface_of(crew), &"flesh", "crew body")
	var corpse: StaticBody3D = _body(_root)
	corpse.add_to_group(G.BODY)
	assert_eq(ImpactFx.surface_of(corpse), &"flesh", "corpse")
	npc.set_meta(&"surface", &"armor")
	assert_eq(ImpactFx.surface_of(npc), &"armor", "explicit metadata beats the character rule")


func test_hit_zones() -> void:
	var npc: CharacterBody3D = CharacterBody3D.new()
	_root.add_child(npc)
	var boxes: Node3D = Node3D.new()
	npc.add_child(boxes)
	var head: Hitbox = Hitbox.new()
	head.hit_zone = Enums.HitZone.HEAD
	boxes.add_child(head)
	var plate: Hitbox = Hitbox.new()
	plate.hit_zone = Enums.HitZone.WEAKPOINT
	boxes.add_child(plate)
	var body: Hitbox = Hitbox.new()
	boxes.add_child(body)
	assert_eq(ImpactFx.surface_of(head), &"flesh", "head")
	assert_eq(ImpactFx.surface_of(body), &"flesh", "body")
	assert_eq(ImpactFx.surface_of(plate), &"armor", "Wrecker plate (WEAKPOINT)")


func test_shield() -> void:
	var shield: AnimatableBody3D = AnimatableBody3D.new()
	shield.add_to_group(BulwarkShield.GROUP)
	_root.add_child(shield)
	assert_eq(ImpactFx.surface_of(shield), &"shield")
	var part: StaticBody3D = _body(shield)
	assert_eq(ImpactFx.surface_of(part), &"shield", "a body under the shield")


func test_every_surface_has_recipe_and_cue() -> void:
	assert_eq(ImpactFx.SURFACES.size(), 13)
	for s: StringName in ImpactFx.SURFACES:
		assert_true(not ImpactFx.profile(s).is_empty(), "recipe for %s" % s)
		assert_eq(ImpactFx.cue_id(s), StringName("cue.impact_%s" % s))
		if ImpactFx.has_decal(s):
			assert_true(VfxTextures.hole(s) != null, "decal texture for %s" % s)
	for s: StringName in [&"flesh", &"water", &"armor", &"shield"]:
		assert_false(ImpactFx.has_decal(s), "%s has no bullet hole" % s)
