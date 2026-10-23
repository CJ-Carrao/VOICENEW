class_name AudioMix
extends RefCounted




const MUSIC: = &"Music"
const EFFECTS: = &"Effects"
const VOICES: = &"Voices"
const INTERFACE: = &"Interface"


const CHANNELS: = [
	["master", &"Master", "GERAL"], 
	["music", MUSIC, "MÚSICA"], 
	["effects", EFFECTS, "EFEITOS"], 
	["voices", VOICES, "VOZ DOS JOGADORES"], 
	["interface", INTERFACE, "INTERFACE"], 
]

static var _focused: = true
static var _hooked: = false



static func ensure_buses() -> void :
	for channel: Array in CHANNELS:
		var name: StringName = channel[1]
		if AudioServer.get_bus_index(name) >= 0:
			continue
		AudioServer.add_bus()
		var index: = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, &"Master")



static func bus(name: StringName) -> StringName:
	ensure_buses()
	return name


static func volume(key: String) -> float:
	return clampf(float(UserSettings.get_value("audio", key, 1.0)), 0.0, 1.0)


static func set_volume(key: String, value: float) -> void :
	UserSettings.set_value("audio", key, snappedf(clampf(value, 0.0, 1.0), 0.01))
	apply()


static func mute_unfocused() -> bool:
	return bool(UserSettings.get_value("audio", "mute_unfocused", false))


static func set_mute_unfocused(on: bool) -> void :
	UserSettings.set_value("audio", "mute_unfocused", on)
	apply()



static func to_db(value: float) -> float:
	return linear_to_db(maxf(value * value, 1e-05))



static func apply(tree: SceneTree = null) -> void :
	ensure_buses()
	if tree != null and not _hooked:
		_hooked = true
		tree.root.focus_entered.connect(Callable(AudioMix, "_on_focus").bind(true))
		tree.root.focus_exited.connect(Callable(AudioMix, "_on_focus").bind(false))
	for channel: Array in CHANNELS:
		var index: = AudioServer.get_bus_index(channel[1])
		var value: = volume(channel[0])
		AudioServer.set_bus_volume_db(index, to_db(value))
		var muted: = value <= 0.0
		if channel[0] == "master" and mute_unfocused() and not _focused:
			muted = true
		AudioServer.set_bus_mute(index, muted)


static func _on_focus(focused: bool) -> void :
	_focused = focused
	apply()
