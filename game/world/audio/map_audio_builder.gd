## Map generators' `Audio` node (D-117): the CuePlayer, the heist MusicDirector and the ambience beds
## (autoplaying CueEmitters, the "CueEmitter (map bed)" loop owners). Same layout as Golden Hour's
## gh_art.gd audio(). Used at generation time by the heist builders (--script), so the runtime audio
## scripts are attached with load() (they use autoloads, which a generator cannot compile against).
extends RefCounted

const CUE_PLAYER: String = "res://world/audio/cue_player.gd"
const MUSIC_DIRECTOR: String = "res://world/audio/music_director.gd"
const CUE_EMITTER: String = "res://world/audio/cue_emitter.gd"


## `beds`: [[node name, position, cue id, volume offset dB], ...]. `track_id` is the MusicDirector's
## fallback track (the running heist's HeistDef.music_track / launch option wins at runtime).
static func build(parent: Node3D, owner_root: Node, track_id: StringName, beds: Array) -> void:
	var player: Node = Node.new()
	player.set_script(load(CUE_PLAYER))
	player.name = "CuePlayer"
	parent.add_child(player)
	player.owner = owner_root
	var music: Node = Node.new()
	music.set_script(load(MUSIC_DIRECTOR))
	music.name = "MusicDirector"
	music.set(&"track_id", track_id)
	parent.add_child(music)
	music.owner = owner_root
	var emitter: Script = load(CUE_EMITTER)
	for b: Array in beds:
		var em: Node3D = Node3D.new()
		em.set_script(emitter)
		em.name = String(b[0])
		em.position = b[1]
		em.set(&"cue_id", b[2])
		em.set(&"autoplay", true)
		em.set(&"volume_offset_db", float(b[3]))
		parent.add_child(em)
		em.owner = owner_root
