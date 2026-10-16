## B2-02: contact defs load, have their strings and voice speakers, and the briefing lines exist.
extends TestCase

const EXPECTED: Array[StringName] = [&"contact.accountant", &"contact.mercer", &"contact.reyes", &"contact.vance"]

var _strings: Dictionary = {}


func before_all() -> void:
	_strings = StringTable.parse_csv()


func test_all_contacts_load_sorted() -> void:
	var ids: Array[StringName] = []
	for c: ContactDef in ContactDef.all():
		ids.append(c.id)
	assert_eq(ids, EXPECTED)


func test_find_by_id_and_path() -> void:
	for cid: StringName in EXPECTED:
		var c: ContactDef = ContactDef.find(cid)
		assert_true(c != null, "loads %s" % cid)
		if c != null:
			assert_eq(c.id, cid)
	assert_eq(ContactDef.path_for(&"contact.vance"), "res://content/data/contacts/vance.tres")
	assert_eq(ContactDef.path_for(&"vance"), "", "ids need the contact. prefix")
	assert_eq(ContactDef.path_for(&"contact."), "")


func test_contact_strings_and_speakers() -> void:
	for c: ContactDef in ContactDef.all():
		assert_has(_strings, String(c.display_name_key), "name of %s" % c.id)
		assert_has(_strings, String(c.role_key), "role of %s" % c.id)
		assert_has(VoiceLineTable.SPEAKERS, c.voice_speaker, "speaker of %s" % c.id)
		assert_has(ContactPortrait.SILHOUETTES, c.silhouette, "silhouette of %s" % c.id)
		assert_true(c.accent_color.a > 0.0)
	assert_true(ContactDef.find(&"contact.mercer").is_handler, "Mercer is the handler")
	assert_false(ContactDef.find(&"contact.vance").is_handler)


## D-117 §6: each heist's briefing has lines from its own contact (HeistDef.contact) and Mercer. Briefing sets for
## a contact the heist does not have were never played (BriefingModel.voice_lines reads HeistDef.contact) and were
## removed by the VO coverage audit (tests/b/test_vo_coverage.gd).
func test_every_heist_contact_has_briefing_lines() -> void:
	var table: VoiceLineTable = load(BriefingModel.LINES_PATH) as VoiceLineTable
	for h: HeistDef in HeistRegistry.all():
		var c: ContactDef = ContactDef.find(h.contact)
		assert_true(c != null, "%s has a contact" % h.id)
		if c == null:
			continue
		for sp: StringName in [c.voice_speaker, &"mercer"]:
			var n: int = 0
			for l: Dictionary in table.lines_for(&"briefing", sp):
				if StringName(l.get("heist", &"")) == h.id and StringName(l["speaker"]) == sp:
					n += 1
					assert_has(_strings, String(l["text_key"]))
					assert_eq(typeof(l.get("order")), TYPE_INT, "order of %s" % l["id"])
			assert_true(n >= 1, "%s briefing has a %s line" % [h.id, sp])


func test_placeholder_portrait_draws_without_art() -> void:
	var p: ContactPortrait = ContactPortrait.new()
	p.size = Vector2(200, 200)
	add_child(p)
	p.set_contact(ContactDef.find(&"contact.mercer"))
	await wait_frames(1)
	assert_true(p.uses_placeholder(), "no portrait art yet: procedural silhouette")
	var art: ContactDef = ContactDef.find(&"contact.mercer").duplicate() as ContactDef
	art.portrait_texture = PlaceholderTexture2D.new()
	p.set_contact(art)
	assert_false(p.uses_placeholder(), "texture fills the slot")
	assert_true(p.art is TextureRect)
	p.queue_free()


## QB-50a: D's portraits (vance's Odile is provisional). Only portrait_texture is set.
func test_contact_portraits_assigned() -> void:
	var want: Dictionary = {
		&"contact.vance": "res://assets/characters/portraits/odile.png",
		&"contact.reyes": "res://assets/characters/portraits/hollis.png",
		&"contact.accountant": "res://assets/characters/portraits/accountant.png",
	}
	for id: StringName in want:
		var c: ContactDef = ContactDef.find(id)
		assert_true(c.portrait_texture != null, "%s has a portrait" % id)
		if c.portrait_texture != null:
			assert_eq(c.portrait_texture.resource_path, want[id], "%s portrait path" % id)
	assert_true(ContactDef.find(&"contact.mercer").portrait_texture == null, "Mercer keeps the silhouette")
