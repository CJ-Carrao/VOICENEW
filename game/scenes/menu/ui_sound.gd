class_name UiSound
extends RefCounted




const FALLBACK: = {
	"hover": ["click", 2.2, -38.0], 
	"navigate": ["click", 1.8, -30.0], 
	"confirm": ["thunk", 1.4, -22.0], 
	"back": ["thunk", 1.1, -28.0], 
}



static func play(player: AudioStreamPlayer, kind: String) -> void :
	if player == null or not player.is_inside_tree():
		return
	var id: = "ui/" + kind
	if not SoundBank.allow(id):
		return
	var file: = SoundBank.stream(id)
	if file != null:
		player.stream = file
		player.pitch_scale = SoundBank.pitch(id)
		player.volume_db = SoundBank.gain(file)
	else:
		var spec: Array = FALLBACK.get(kind, FALLBACK.navigate)
		player.stream = BuildSounds.thunk() if spec[0] == "thunk" else BuildSounds.click()
		player.pitch_scale = spec[1]
		player.volume_db = spec[2]
	player.bus = AudioMix.bus(AudioMix.INTERFACE)
	player.play()



static func play_at(node: Node, kind: String) -> void :
	var id: = "ui/" + kind
	var spec: Array = FALLBACK.get(kind, FALLBACK.navigate)
	if SoundBank.has(id):
		SoundBank.play_flat(node, id, 0.0, null, AudioMix.INTERFACE)
	else:
		SoundBank.play_flat(node, id, spec[2], BuildSounds.thunk() if spec[0] == "thunk" else BuildSounds.click(), 
			AudioMix.INTERFACE, spec[1])
