class_name UserSettings
extends RefCounted




const PATH: = "user://settings.cfg"
const TALK_ACTION: = "talk"

const TALK_MOUSE_BUTTONS: = [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
const MOUSE_NAMES: = {
	MOUSE_BUTTON_LEFT: "clique esquerdo", 
	MOUSE_BUTTON_RIGHT: "clique direito", 
	MOUSE_BUTTON_MIDDLE: "botão do meio do mouse", 
	MOUSE_BUTTON_XBUTTON1: "botão lateral 1 do mouse", 
	MOUSE_BUTTON_XBUTTON2: "botão lateral 2 do mouse", 
}

const ACTION_NAMES: = {
	"move_forward": "andar pra frente", "move_back": "andar pra trás", "move_left": "andar pra esquerda", 
	"move_right": "andar pra direita", "jump": "pular", "sprint": "correr", "use": "usar", "aim": "mirar", 
	"slot_1": "slot 1", "slot_2": "slot 2", "slot_3": "slot 3", "slot_next": "próximo slot", 
	"slot_prev": "slot anterior", "console": "console", "reload": "recarregar", "exit_pilot": "parar de pilotar", 
	"debug": "debug", "voice_chat": "conversar sem criar (Caps Lock)", "command_talk": "dar comandos por voz (B)",
}

static var _cfg: ConfigFile


static func get_value(section: String, key: String, default: Variant = null) -> Variant:
	if not _file().has_section_key(section, key):
		return default
	return _cfg.get_value(section, key, default)


static func set_value(section: String, key: String, value: Variant) -> void :
	_file().set_value(section, key, value)
	_cfg.save(PATH)



static func apply_input() -> void :
	var saved: Variant = get_value("controls", "talk")
	if saved is Dictionary:
		var event: = event_from_dict(saved)
		if event != null and talk_event_problem(event).is_empty():
			_bind_talk(event)



static func set_talk_event(event: InputEvent) -> String:
	var why: = talk_event_problem(event)
	if not why.is_empty():
		return why
	_bind_talk(event)
	set_value("controls", "talk", event_to_dict(event))
	return ""



static func talk_event_problem(event: InputEvent) -> String:
	var mouse: = event as InputEventMouseButton
	if mouse != null:
		if mouse.button_index in TALK_MOUSE_BUTTONS:
			return ""
		if MOUSE_NAMES.has(mouse.button_index):
			return "o %s já é usado no jogo" % MOUSE_NAMES[mouse.button_index]
		return "esse botão do mouse não dá (a rodinha troca de slot)"
	var key: = event as InputEventKey
	if key == null:
		return "use uma tecla ou um botão do mouse"
	if key.physical_keycode == KEY_ESCAPE:
		return "Esc abre as opções"
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_") or action == TALK_ACTION:
			continue
		for other in InputMap.action_get_events(action):
			var other_key: = other as InputEventKey
			if other_key != null and other_key.physical_keycode == key.physical_keycode:
				return "%s já é %s" % [key_name(key), ACTION_NAMES.get(String(action), String(action))]
	return ""



static func talk_key_name() -> String:
	if not InputMap.has_action(TALK_ACTION) or InputMap.action_get_events(TALK_ACTION).is_empty():
		return "?"
	return key_name(InputMap.action_get_events(TALK_ACTION)[0])


static func key_name(event: InputEvent) -> String:
	var mouse: = event as InputEventMouseButton
	if mouse != null:
		return MOUSE_NAMES.get(mouse.button_index, "botão %d do mouse" % mouse.button_index)
	var key: = event as InputEventKey
	if key == null:
		return "?"
	var code: = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode

	if DisplayServer.get_name() != "headless":
		code = DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(code)


static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventMouseButton:
		return {"kind": "mouse", "button": (event as InputEventMouseButton).button_index}
	return {"kind": "key", "code": (event as InputEventKey).physical_keycode}


static func event_from_dict(data: Dictionary) -> InputEvent:
	match String(data.get("kind", "")):
		"mouse":
			var mouse: = InputEventMouseButton.new()
			mouse.button_index = int(data.get("button", 0)) as MouseButton
			return mouse
		"key":
			var key: = InputEventKey.new()
			key.physical_keycode = int(data.get("code", 0)) as Key
			return key
	return null


static func _bind_talk(event: InputEvent) -> void :
	if not InputMap.has_action(TALK_ACTION):
		InputMap.add_action(TALK_ACTION)
	InputMap.action_erase_events(TALK_ACTION)
	InputMap.action_add_event(TALK_ACTION, event)


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		if FileAccess.file_exists(PATH):
			_cfg.load(PATH)
	return _cfg
