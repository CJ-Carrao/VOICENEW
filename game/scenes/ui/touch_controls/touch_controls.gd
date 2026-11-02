class_name TouchControls
extends Control











const LAYOUT_PATH: = "res://scenes/ui/touch_controls/layout.json"
const DEVICE_ID: = 127
const STICK_ASSEMBLY_DURATION: = 0.28
const GROUP: = "touch_controls"

const EDIT_TOOLS: = ["smaller", "bigger", "hide", "reset", "done"]


var test_mode: = false
var layout: Dictionary = {}

var editing: = false
var _player: Node
var _console: Control
var _options: Control
var _enabled: = false
var _gameplay_allowed: = true
var _focused: = true
var _emulate_mouse_before: = true
var _owns_emulation: = false
var _fingers: Dictionary = {}
var _strengths: Dictionary = {}
var _joystick_finger: = -1
var _look_finger: = -1
var _stick: = Vector2.ZERO
var _joystick_origin: = Vector2.ZERO
var _stick_assembly: = 0.0
var _font: Font
var _refresh_input: Callable
var _restore_input_after_cancel: = false
var _cancel_until_physics_frame: = 0

var _press_glow: Dictionary = {}
var _aim_latched: = false
var _look: String = ""

var _edit_selected: = ""
var _edit_finger: = -1
var _edit_grab: = Vector2.ZERO
var _overrides: Dictionary = {}


func _ready() -> void :
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = HudSkin.font(800)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if parsed is Dictionary:
		layout = parsed
	_load_overrides()
	visible = OS.has_feature("mobile") or test_mode or MobileDev.args().has("--mobile")
	set_process(visible)
	set_process_input(visible)
	resized.connect(_on_resized)
	if test_mode:
		set_gameplay_enabled(true)


func bind(player: Node, console: Control, options: Control, refresh_input: Callable = Callable()) -> void :
	_player = player
	_refresh_input = refresh_input
	_console = console
	_options = options
	_console.connect("opened", _on_console_opened)
	_console.connect("closed", _on_console_closed)
	_console.anchor_top = 0.0
	_console.anchor_bottom = 0.0
	_place_console()
	_place_mobile_hud()
	_sync_enabled()




func _is_extracting() -> bool:
	return is_instance_valid(_player) and bool(_player.get("extracting"))


func _shaping() -> bool:
	if not is_instance_valid(_player):
		return false
	var shaper: Variant = _player.get("shaper")
	return shaper != null and bool(shaper.get("active"))


func _piloting() -> bool:
	return is_instance_valid(_player) and _player.get("piloting") != null



func _held() -> Dictionary:
	if not is_instance_valid(_player):
		return {}
	var hands: Variant = _player.get("hands")
	if hands == null or not hands.has_method("network_item_state"):
		return {}
	var data: Variant = hands.call("network_item_state")
	return data if data is Dictionary else {}



func main_mode() -> String:
	if _shaping():
		return "confirm"
	if _is_extracting():
		return "extract"
	if _piloting():
		return "command"
	var held: = _held()
	if held.is_empty():
		return "empty"
	if bool(held.get("melee", false)):
		return "strike"
	if bool(held.get("throwable", false)):
		return "throw"
	return "fire"


const MAIN_LABELS: = {"fire": "ATIRAR", "strike": "GOLPEAR", "throw": "ARREMESSAR", "extract": "EXTRAIR", 
	"confirm": "CONFIRMAR", "command": "COMANDO", "empty": "ATIRAR"}


func _reload_state() -> int:
	if _shaping():
		return 2
	var held: = _held()
	return 1 if int(held.get("magazine", 0)) > 0 else 0


func _process(delta: float) -> void :
	if not test_mode:
		_sync_enabled()
	var look: = "%s|%d|%s|%s|%s|%s" % [main_mode(), _reload_state(), _piloting(), Session.is_online(), _held().get("ammo", -1), _held().get("loading", false)]
	if look != _look:
		_look = look
		queue_redraw()
	if _joystick_finger >= 0 and _stick_assembly < STICK_ASSEMBLY_DURATION:
		_stick_assembly = minf(_stick_assembly + delta, STICK_ASSEMBLY_DURATION)
		queue_redraw()

	for id: String in _press_glow.keys():
		var held: = _is_pressed(id) or (id == "aim" and _aim_latched)
		var value: = move_toward(float(_press_glow[id]), 1.0 if held else 0.0, delta * (14.0 if held else 4.5))
		if value <= 0.0 and not held:
			_press_glow.erase(id)
		else:
			_press_glow[id] = value
		queue_redraw()


func _physics_process(_delta: float) -> void :
	if not _restore_input_after_cancel or not _focused or Engine.get_physics_frames() < _cancel_until_physics_frame:
		return
	_restore_input_after_cancel = false
	if _refresh_input.is_valid():
		_refresh_input.call()
	elif is_instance_valid(_player):
		_player.set("input_enabled", true)





func _cancel_player_use() -> void :
	if not is_instance_valid(_player):
		return
	if bool(_player.get("input_enabled")):
		_restore_input_after_cancel = true
		_cancel_until_physics_frame = Engine.get_physics_frames() + 2
		_player.set("input_enabled", false)
	_player.call("release_input")


func _sync_enabled() -> void :
	var menu_open: = (is_instance_valid(_console) and bool(_console.get("is_open")))\
	or (is_instance_valid(_options) and _options.visible)
	var available: = is_instance_valid(_player)
	var gameplay: = available and bool(_player.get("input_enabled"))
	if _gameplay_allowed != gameplay:
		_gameplay_allowed = gameplay
		release_all()

	set_gameplay_enabled(available and (editing or ( not menu_open and not get_tree().paused)) and _focused)


func set_gameplay_enabled(enabled: bool) -> void :
	enabled = enabled and (OS.has_feature("mobile") or test_mode or MobileDev.args().has("--mobile"))
	if _enabled == enabled:
		return
	_enabled = enabled
	visible = enabled
	if enabled:
		_emulate_mouse_before = Input.emulate_mouse_from_touch
		Input.emulate_mouse_from_touch = false
		_owns_emulation = true
	else:
		release_all()
		_restore_emulation()
	queue_redraw()


func _restore_emulation() -> void :
	if _owns_emulation:
		Input.emulate_mouse_from_touch = _emulate_mouse_before
		_owns_emulation = false


func _exit_tree() -> void :
	release_all()
	_restore_emulation()


func _notification(what: int) -> void :
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		set_gameplay_enabled(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true
		_sync_enabled()


func _input(event: InputEvent) -> void :
	if not _enabled:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()

		handle_touch.call_deferred(event)



func handle_touch(event: InputEvent) -> void :
	if not _enabled:
		return
	if editing:
		_edit_touch(event)
		queue_redraw()
		return
	if event is InputEventScreenTouch:
		var touch: = event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			_press(touch.index, touch.position)
		else:
			_release(touch.index, touch.canceled)
	elif event is InputEventScreenDrag:
		var drag: = event as InputEventScreenDrag
		if drag.index == _joystick_finger:
			_move_stick(drag.position)
		elif drag.index == _look_finger or _can_drag_aim(drag.index):
			_send_look_motion(drag)
	queue_redraw()


func _send_look_motion(drag: InputEventScreenDrag) -> void :
	var motion: = InputEventMouseMotion.new()
	motion.device = DEVICE_ID
	var relative: = drag.relative
	var screen_relative: = drag.screen_relative
	if bool(_setting("invert_y", false)):
		relative.y = - relative.y
		screen_relative.y = - screen_relative.y


	var window_transform: = get_viewport().get_final_transform()
	motion.relative = window_transform.basis_xform(relative)
	motion.position = window_transform * drag.position
	motion.global_position = motion.position
	motion.screen_relative = screen_relative
	Input.parse_input_event(motion)


func _can_drag_aim(index: int) -> bool:
	if not _fingers.has(index):
		return false
	return bool((_fingers[index] as Dictionary).get("drag_aim", false))


func _is_pressed(id: String) -> bool:
	for finger: Dictionary in _fingers.values():
		if String(finger.get("id", "")) == id:
			return true
	return false



func _is_button_active(button: Dictionary) -> bool:
	if not bool(button.get("active", true)):
		return false
	var id: = String(button.get("id", ""))
	if bool(_override(id).get("hidden", false)) and not test_mode:
		return false
	var context: = String(button.get("context", ""))
	if context.is_empty() or test_mode:
		return true
	if context.begins_with("setting:"):
		return _setting_flag(context.trim_prefix("setting:"))
	match context:
		"shaper":
			return _shaping()
		"reloadable":
			return _reload_state() == 1
		"pilot":
			return _piloting()
		"online":
			return Session.is_online()
		_:
			return true


func _press(index: int, point: Vector2) -> void :
	if _fingers.has(index):
		_release(index, true)
	if index == _joystick_finger:
		_joystick_finger = -1
	if index == _look_finger:
		_look_finger = -1
	for button: Dictionary in layout.get("buttons", []):
		if not _gameplay_allowed and String(button.id) not in ["menu", "jump"]:
			continue
		if not _is_button_active(button):
			continue
		if button_rect(String(button.id)).has_point(point):
			var id: = String(button.id)
			var action: = String(button.action)
			var drag_aim: = bool(button.get("drag_aim", false))
			_press_glow[id] = maxf(float(_press_glow.get(id, 0.0)), 0.01)
			_haptic(18 if bool(button.get("main", false)) else 10)

			if bool(button.get("pulse", false)):
				_fingers[index] = {"id": id, "action": "", "drag_aim": drag_aim}
				if not _strengths.has(action):
					_emit_action(action, 1.0)
					_emit_action(action, 0.0)
			elif action == "camera":

				_fingers[index] = {"id": id, "action": "", "drag_aim": false}
				_toggle_camera()
			elif action == "reload" and not test_mode and not bool(Lexicon.bal("weapons._reload.manual_key", false)):

				_fingers[index] = {"id": id, "action": "", "drag_aim": false}
				if is_instance_valid(_console) and _console.has_signal("submitted"):
					_console.emit_signal("submitted", String(button.get("phrase", "quero um pente")))
			elif action == "aim" and bool(_setting(String(button.get("toggle_setting", "")), false)):

				_fingers[index] = {"id": id, "action": "", "drag_aim": drag_aim}
				_aim_latched = not _aim_latched
				_set_strength("aim", 1.0 if _aim_latched else 0.0)
			else:
				_fingers[index] = {"id": id, "action": action, "drag_aim": drag_aim}
				_set_strength(action, 1.0)
			return
	if not _gameplay_allowed:
		return
	if _joystick_finger < 0 and _grabs_joystick(point):
		_joystick_finger = index
		_joystick_origin = point if not _fixed_stick() else _stick_home()
		_stick_assembly = 0.0 if not _fixed_stick() else STICK_ASSEMBLY_DURATION
		_fingers[index] = {"id": "joystick", "action": ""}
		_move_stick(point)
	elif _look_finger < 0 and _look_rect().has_point(point):
		_look_finger = index
		_fingers[index] = {"id": "look", "action": ""}


func _release(index: int, cancelled: bool = false) -> void :
	if not _fingers.has(index):
		if index == _joystick_finger:
			_joystick_finger = -1
			_stick = Vector2.ZERO
			_stick_assembly = 0.0
		if index == _look_finger:
			_look_finger = -1
		return
	var action: = String((_fingers[index] as Dictionary).get("action", ""))
	_fingers.erase(index)
	if index == _joystick_finger:
		_joystick_finger = -1
		_stick = Vector2.ZERO
		_stick_assembly = 0.0
		_move_stick(_joystick_origin)
	if index == _look_finger:
		_look_finger = -1
	if not action.is_empty():
		for finger: Dictionary in _fingers.values():
			if String(finger.get("action", "")) == action:
				return
		if cancelled and action == "use":
			_cancel_player_use()
		_set_strength(action, 0.0, cancelled)


func release_all() -> void :
	if _strengths.has("use"):
		_cancel_player_use()
	_fingers.clear()
	_joystick_finger = -1
	_look_finger = -1
	_stick = Vector2.ZERO
	_stick_assembly = 0.0
	_aim_latched = false
	_edit_finger = -1
	for action: String in _strengths.keys():
		_emit_action(action, 0.0, true)
	_strengths.clear()
	queue_redraw()


func _move_stick(point: Vector2) -> void :
	_stick = ((point - _joystick_origin) / maxf(joystick_radius(), 1.0)).limit_length()
	var stick_config: Dictionary = layout.get("joystick", {})
	var wish: = _stick if _stick.length() > float(stick_config.get("deadzone", 0.2)) else Vector2.ZERO
	_set_strength("move_left", maxf( - wish.x, 0.0))
	_set_strength("move_right", maxf(wish.x, 0.0))
	_set_strength("move_forward", maxf( - wish.y, 0.0))
	_set_strength("move_back", maxf(wish.y, 0.0))

	if bool(_setting("sprint_push", true)) or test_mode:
		_set_strength("sprint", 1.0 if _stick.length() >= float(stick_config.get("sprint_threshold", 0.92)) else 0.0)


func _set_strength(action: String, strength: float, cancelled: bool = false) -> void :
	if is_equal_approx(float(_strengths.get(action, 0.0)), strength):
		return
	if strength > 0.0:
		_strengths[action] = strength
	else:
		_strengths.erase(action)
	_emit_action(action, strength, cancelled)


func _emit_action(action: String, strength: float, cancelled: bool = false) -> void :
	if not InputMap.has_action(action):
		return
	var event: = InputEventAction.new()
	event.device = DEVICE_ID
	event.action = action
	event.pressed = strength > 0.0
	event.strength = strength
	if cancelled:
		event.set_meta("touch_cancelled", true)
	Input.parse_input_event(event)


func _toggle_camera() -> void :
	var view: = _player.get("view") as ViewCamera if is_instance_valid(_player) else null
	if view == null:
		return
	view.zoom_by_player(-100 if view.is_third_person() else 1)


func _haptic(ms: int) -> void :
	if bool(_setting("haptics", true)) and OS.has_feature("mobile") and not test_mode:
		Input.vibrate_handheld(ms)




func _setting(key: String, fallback: Variant) -> Variant:
	if key.is_empty():
		return fallback
	return UserSettings.get_value("touch", key, fallback)



func _setting_flag(key: String) -> bool:
	if key == "sprint_button":
		return not bool(_setting("sprint_push", true))
	return bool(_setting(key, false))


func _fixed_stick() -> bool:
	return String(_setting("joystick", "floating")) == "fixed"


func _load_overrides() -> void :
	var saved: Variant = UserSettings.get_value("touch", "layout", {})
	_overrides = (saved as Dictionary).duplicate(true) if saved is Dictionary else {}


func _override(id: String) -> Dictionary:
	var entry: Variant = _overrides.get(id, {})
	return entry if entry is Dictionary else {}


func _save_overrides() -> void :
	UserSettings.set_value("touch", "layout", _overrides.duplicate(true))



func refresh_settings() -> void :
	_load_overrides()
	_aim_latched = _aim_latched and bool(_setting("ads_toggle", false))
	queue_redraw()


func _reference_scale() -> float:
	var reference: = _vector(layout.get("reference_size", [1920, 1080]))
	return minf(size.x / reference.x, size.y / reference.y)


const TOP_BAR: = ["menu", "console", "camera", "chat"]

const SCALE_MIN: = 0.7
const SCALE_MAX: = 1.4


func _layout_scale() -> float:
	return _reference_scale() * clampf(float(_setting("scale", 1.0)), SCALE_MIN, SCALE_MAX)



func _fixed_size(id: String) -> bool:
	return id.begins_with("slot_") or id in TOP_BAR


func _button_scale(id: String) -> float:
	var base: = _reference_scale() if _fixed_size(id) else _layout_scale()
	return base * clampf(float(_override(id).get("scale", 1.0)), 0.6, 1.8)


func _center(definition: Dictionary, mirror: = true) -> Vector2:
	var id: = String(definition.get("id", ""))
	var anchor_scale: = _reference_scale() if _fixed_size(id) else _layout_scale()
	var shift: = Vector2(float(_override(id).get("dx", 0.0)), float(_override(id).get("dy", 0.0)))
	var point: = _vector(definition.get("anchor", [0, 0])) * size\
	+ (_vector(definition.get("offset", [0, 0])) + shift) * anchor_scale
	if mirror and bool(_setting("left_handed", false)):
		point.x = size.x - point.x
	return point


func button_rect(id: String) -> Rect2:
	if id == "joystick":
		var r: = joystick_radius()
		return Rect2(_stick_home() - Vector2.ONE * r, Vector2.ONE * r * 2.0)
	for button: Dictionary in layout.get("buttons", []):
		if String(button.id) == id:
			var extent: = _vector(button.size) * _button_scale(id)
			var mirror: = bool(button.get("mirror", true))
			var rect: = Rect2(_center(button, mirror) - extent * 0.5, extent)

			rect.position = rect.position.clamp(Vector2.ZERO, (size - rect.size).max(Vector2.ZERO))
			return rect
	return Rect2()



func _stick_home() -> Vector2:
	var stick: Dictionary = layout.get("joystick", {})
	var definition: = {"id": "joystick", "anchor": stick.get("anchor", [0, 1]), "offset": stick.get("offset", [270, -275])}
	return _center(definition)


func joystick_center() -> Vector2:
	return _joystick_origin if _joystick_finger >= 0 else _stick_home()


func joystick_radius() -> float:
	return float((layout.get("joystick", {}) as Dictionary).get("radius", 150)) * _layout_scale()\
	* clampf(float(_override("joystick").get("scale", 1.0)), 0.6, 1.8)


func _grabs_joystick(point: Vector2) -> bool:
	if _fixed_stick():
		return point.distance_to(_stick_home()) <= joystick_radius() * 1.45
	return _movement_rect().has_point(point)


func _look_rect() -> Rect2:
	var area: Array = layout.get("look_area", [0.5, 0, 0.5, 1])
	var rect: = Rect2(Vector2(float(area[0]), float(area[1])) * size, Vector2(float(area[2]), float(area[3])) * size)
	if bool(_setting("left_handed", false)):
		rect.position.x = size.x - rect.end.x
	return rect




func _movement_rect() -> Rect2:
	var area: Array = layout.get("movement_area", [0.0, 0.23, 0.47, 0.77])
	var rect: = Rect2(Vector2(float(area[0]), float(area[1])) * size, 
		Vector2(float(area[2]), float(area[3])) * size)
	if bool(_setting("left_handed", false)):
		rect.position.x = size.x - rect.end.x
	return rect


func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _on_resized() -> void :
	release_all()
	_place_console()
	_place_mobile_hud()






func begin_edit() -> void :
	release_all()
	editing = true
	_edit_selected = "use"
	if not test_mode:
		_sync_enabled()
	queue_redraw()


func end_edit() -> void :
	editing = false
	_edit_finger = -1
	_save_overrides()
	if not test_mode:
		_sync_enabled()
	queue_redraw()


func _editable_ids() -> Array[String]:
	var ids: Array[String] = ["joystick"]
	for button: Dictionary in layout.get("buttons", []):
		var id: = String(button.id)
		if bool(button.get("draw", true)) and not id.begins_with("slot_"):
			ids.append(id)
	return ids


func _tool_rect(tool: String) -> Rect2:
	var scale: = _reference_scale()
	var width: = 170.0 * scale
	var gap: = 14.0 * scale
	var total: = width * EDIT_TOOLS.size() + gap * (EDIT_TOOLS.size() - 1)
	var index: = EDIT_TOOLS.find(tool)
	return Rect2(Vector2((size.x - total) * 0.5 + index * (width + gap), 150.0 * scale), Vector2(width, 74.0 * scale))


func _edit_touch(event: InputEvent) -> void :
	var touch: = event as InputEventScreenTouch
	if touch != null:
		if not touch.pressed:
			if touch.index == _edit_finger:
				_edit_finger = -1
				_save_overrides()
			return
		for tool: String in EDIT_TOOLS:
			if _tool_rect(tool).has_point(touch.position):
				_haptic(10)
				_edit_tool(tool)
				return
		for id in _editable_ids():
			if button_rect(id).grow(8.0).has_point(touch.position):
				_edit_selected = id
				_edit_finger = touch.index
				_edit_grab = touch.position
				_haptic(10)
				return
		return
	var drag: = event as InputEventScreenDrag
	if drag == null or drag.index != _edit_finger or _edit_selected.is_empty():
		return
	var scale: = _reference_scale() if _fixed_size(_edit_selected) else _layout_scale()
	var delta: = drag.relative / maxf(scale, 0.01)
	if bool(_setting("left_handed", false)):
		delta.x = - delta.x
	var entry: = _override(_edit_selected).duplicate()
	entry["dx"] = float(entry.get("dx", 0.0)) + delta.x
	entry["dy"] = float(entry.get("dy", 0.0)) + delta.y
	_overrides[_edit_selected] = entry


func _edit_tool(tool: String) -> void :
	var entry: = _override(_edit_selected).duplicate()
	match tool:
		"smaller":
			entry["scale"] = clampf(float(entry.get("scale", 1.0)) - 0.1, 0.6, 1.8)
		"bigger":
			entry["scale"] = clampf(float(entry.get("scale", 1.0)) + 0.1, 0.6, 1.8)
		"hide":
			if _optional(_edit_selected):
				entry["hidden"] = not bool(entry.get("hidden", false))
		"reset":
			_overrides.clear()
			_save_overrides()
			return
		"done":
			end_edit()
			return
	_overrides[_edit_selected] = entry
	_save_overrides()


func _edit_name(id: String) -> String:
	if id == "joystick":
		return "ANALÓGICO"
	for button: Dictionary in layout.get("buttons", []):
		if String(button.id) == id:
			return String(button.get("label", id)).to_upper()
	return id.to_upper()


func _optional(id: String) -> bool:
	for button: Dictionary in layout.get("buttons", []):
		if String(button.id) == id:
			return bool(button.get("optional", false))
	return false






func _place_mobile_hud() -> void :
	if get_parent() == null:
		return
	var hud_scale: = _reference_scale()
	var vitals: = get_parent().get_node_or_null("Vitals") as Control
	if vitals == null:
		return
	var placement: Dictionary = (layout.get("hud", {}) as Dictionary).get("vitals", {})
	if placement.is_empty():
		return
	vitals.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	vitals.position = _vector(placement.offset) * hud_scale
	vitals.size = _vector(placement.size) * hud_scale
	var shape_banner: = get_parent().get_node_or_null("ShapeBanner") as Label
	if shape_banner != null:
		shape_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		shape_banner.offset_left = -330.0 * hud_scale
		shape_banner.offset_right = 410.0 * hud_scale
		shape_banner.offset_top = 120.0 * hud_scale
		shape_banner.offset_bottom = 156.0 * hud_scale
		shape_banner.add_theme_font_size_override("font_size", 12)
	var ammo: = get_parent().get_node_or_null("AmmoPanel") as Control
	if ammo != null:
		ammo.modulate.a = 0.0
	var right_column: = get_parent().get_node_or_null("RightColumn") as Control
	if right_column != null:
		right_column.offset_top = 110.0 * hud_scale
		right_column.offset_bottom = 314.0 * hud_scale
	var slots: = get_parent().get_node_or_null("Slots") as Control
	if slots != null:
		slots.offset_bottom = -28.0 * hud_scale
		slots.offset_top = -80.0 * hud_scale
	var status: = get_parent().get_node_or_null("Status") as Label
	if status != null:
		status.offset_bottom = -86.0 * hud_scale
		status.offset_top = -110.0 * hud_scale


func _place_console() -> void :
	if not is_instance_valid(_console):
		return
	var placement: Dictionary = layout.get("console", {})
	_console.offset_top = float(placement.get("top", 70)) * _reference_scale()
	_console.offset_bottom = _console.offset_top + float(placement.get("height", 130)) * _reference_scale()


func _on_console_opened() -> void :
	set_gameplay_enabled(false)
	_show_keyboard.call_deferred()


func _show_keyboard() -> void :
	if not is_instance_valid(_console) or not bool(_console.get("is_open")):
		return
	var line: = _console.get_node_or_null("VBox/Line") as LineEdit
	if line != null:
		line.virtual_keyboard_enabled = true
		line.grab_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_show(line.text)


func _on_console_closed() -> void :
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	_sync_enabled()




func _palette() -> Dictionary:
	var style: Dictionary = layout.get("style", {})
	var opacity: = clampf(float(_setting("opacity", 0.7)), 0.35, 1.0)
	return {"plate": Color(String(style.get("plate", "#121318")), float(style.get("base_alpha", 0.6)) * opacity), 
		"edge": Color(String(style.get("edge", "#f5f1e8")), 0.32 * opacity + 0.12), 
		"ink": Color(String(style.get("ink", "#f5f1e8")), 0.55 + 0.45 * opacity), 
		"accent": Color(String(style.get("accent", "#f2601a"))), 
		"gold": Color(String(style.get("gold", "#ffc65c"))), "opacity": opacity}


func _draw() -> void :
	if layout.is_empty() or not _enabled:
		return
	var colors: = _palette()
	var line: = maxf(1.2, 2.0 * _layout_scale())
	if editing:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07, 0.55))
	if _gameplay_allowed or editing:
		_draw_joystick(colors, line)
	for button: Dictionary in layout.get("buttons", []):
		var id: = String(button.id)
		if not editing and not _gameplay_allowed and id not in ["menu", "jump"]:
			continue
		if not bool(button.get("draw", true)):
			continue
		var shown: = _is_button_active(button)
		if not shown and not editing:
			continue
		_draw_button(button, button_rect(id), colors, line, shown)
	if editing:
		_draw_editor(colors, line)



static func _octagon(rect: Rect2, cut_ratio: float = 0.29) -> PackedVector2Array:
	var c: = minf(rect.size.x, rect.size.y) * cut_ratio
	var p: = rect.position
	var e: = rect.end
	return PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c), 
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])



static func _plate(rect: Rect2) -> PackedVector2Array:
	var c: = minf(rect.size.x, rect.size.y) * 0.24
	return PackedVector2Array([rect.position, Vector2(rect.end.x - c, rect.position.y), Vector2(rect.end.x, rect.position.y + c), 
		rect.end, Vector2(rect.position.x + c, rect.end.y), Vector2(rect.position.x, rect.end.y - c)])


func _draw_button(button: Dictionary, rect: Rect2, colors: Dictionary, line: float, shown: bool) -> void :
	var id: = String(button.id)
	var glow: = float(_press_glow.get(id, 0.0))
	var main: = bool(button.get("main", false)) or id == "use_left"
	var mode: = main_mode() if main else ""
	var accent: Color = colors.gold if (mode == "extract" or id == "extract") else colors.accent

	var squeeze: = rect.grow( - minf(rect.size.x, rect.size.y) * 0.05 * glow)
	var shape: = _plate(squeeze) if String(button.get("shape", "")) == "plate" else _octagon(squeeze)
	var outline: = shape.duplicate()
	outline.append(shape[0])
	if glow > 0.01:
		var halo: = _plate(squeeze.grow(line * 4.0)) if String(button.get("shape", "")) == "plate" else _octagon(squeeze.grow(line * 4.0))
		halo.append(halo[0])
		draw_polyline(halo, Color(accent, 0.55 * glow), line * 3.0, true)
	var plate: Color = colors.plate
	var latched: = (id == "aim" and _aim_latched) or (id == "crouch" and _crouched())
	if glow > 0.01 or latched:
		plate = plate.lerp(Color(accent, 0.92), maxf(glow * 0.85, 0.55 if latched else 0.0))
	elif mode == "extract":
		plate = plate.lerp(Color(colors.gold, plate.a), 0.18)
	draw_colored_polygon(shape, plate)
	var edge: Color = colors.edge
	if main or id == "talk":
		edge = Color(accent, 0.75 + 0.25 * glow)
	draw_polyline(outline, edge, line * (1.6 if main else 1.0), true)

	var top_a: = shape[0] + Vector2(line, line * 1.5)
	var top_b: = shape[1] + Vector2( - line, line * 1.5)
	draw_line(top_a, top_b, Color(1, 1, 1, 0.16 * colors.opacity), maxf(1.0, line * 0.7), true)
	var ink: Color = colors.ink
	if glow > 0.3 or latched:
		ink = Color(0.08, 0.06, 0.05, 0.95)
	var icon: = String(button.get("icon", id))
	if main:
		icon = "main_" + mode
		_draw_ammo_ring(rect, colors, line, accent)
	var icon_size: = minf(squeeze.size.x, squeeze.size.y) * (0.24 if main else 0.27)
	var caption_inside: = main and not bool(_setting("labels", false))
	var icon_center: = squeeze.get_center() - Vector2(0, icon_size * 0.28 if caption_inside else 0.0)
	_draw_icon(icon, icon_center, icon_size, ink, accent, maxf(1.6, line * 1.1))

	var caption: = tr(String(MAIN_LABELS.get(mode, button.get("label", ""))) if main else String(button.get("label", "")))
	if caption_inside:
		var fs: = clampi(roundi(squeeze.size.y * 0.1), 9, 18)
		draw_string(_font, Vector2(squeeze.position.x, squeeze.get_center().y + icon_size * 1.25), caption, 
			HORIZONTAL_ALIGNMENT_CENTER, squeeze.size.x, fs, Color(ink, 0.9))
	elif bool(_setting("labels", false)) or editing:
		var fs: = clampi(roundi(rect.size.y * 0.13), 9, 16)
		var at: = Vector2(rect.position.x - 20.0, rect.end.y + fs + 2.0)
		draw_string_outline(_font, at, caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 40.0, fs, 4, Color(0.05, 0.05, 0.07, 0.8))
		draw_string(_font, at, caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 40.0, fs, Color(colors.ink, 0.95))
	if editing:
		var selected: = id == _edit_selected
		var frame: = rect.grow(6.0)
		draw_rect(frame, Color(colors.accent if selected else Color(1, 1, 1, 0.35)), false, line * (1.6 if selected else 0.8))
		if not shown:
			draw_rect(rect, Color(0.05, 0.05, 0.07, 0.55))
			draw_string(_font, Vector2(rect.position.x, rect.get_center().y + 6.0), tr("OCULTO") if bool(_override(id).get("hidden", false)) else tr("SITUAÇÃO"), 
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color(1, 1, 1, 0.8))



func _draw_ammo_ring(rect: Rect2, colors: Dictionary, line: float, accent: Color) -> void :
	var held: = _held()
	var capacity: = int(held.get("capacity", held.get("magazine", 0)))
	if main_mode() != "fire" or capacity <= 0:
		return
	var ammo: = clampi(int(held.get("ammo", 0)), 0, capacity)
	var center: = rect.get_center()
	var radius: = minf(rect.size.x, rect.size.y) * 0.5 + line * 4.5
	var start: = PI * 0.75
	draw_arc(center, radius, start, start + PI * 1.5, 48, Color(1, 1, 1, 0.14 * colors.opacity + 0.08), line * 2.2, true)
	var loading: = bool(held.get("loading", false)) or float(held.get("reload_left", 0.0)) > 0.0
	var fraction: = float(ammo) / float(capacity)
	var tone: = Color(accent, 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.008))) if loading else accent
	if fraction > 0.0:
		draw_arc(center, radius, start, start + PI * 1.5 * fraction, 48, tone, line * 2.2, true)
	var text: = "%d" % ammo
	var fs: = clampi(roundi(rect.size.y * 0.11), 10, 20)
	var at: = center + Vector2(-30.0, radius + fs * 0.35)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, fs, 4, Color(0.05, 0.05, 0.07, 0.85))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, fs, Color(1, 1, 1, 0.95) if ammo > 0 else Color("#ff8a65"))


func _crouched() -> bool:
	if not is_instance_valid(_player):
		return false
	var move: Variant = _player.get("move")
	return move is FpsMove and (move as FpsMove).state in [FpsMove.State.CROUCH, FpsMove.State.SLIDE]


func _draw_joystick(colors: Dictionary, line: float) -> void :
	var active: = _joystick_finger >= 0
	var fixed: = _fixed_stick()
	var center: = _joystick_origin if active else _stick_home()
	var radius: = joystick_radius()

	if not active and not fixed and not editing:
		var ghost: = _octagon(Rect2(center - Vector2.ONE * radius * 0.62, Vector2.ONE * radius * 1.24), 0.29)
		ghost.append(ghost[0])
		draw_polyline(ghost, Color(colors.edge, 0.18), line, true)
		return
	var base: = _octagon(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), 0.29)
	var progress: = clampf(_stick_assembly / STICK_ASSEMBLY_DURATION, 0.0, 1.0) if active and not fixed else 1.0
	var fill: Color = colors.plate
	fill.a *= 0.85 * progress
	draw_colored_polygon(base, fill)
	var outline: = base.duplicate()
	outline.append(base[0])
	draw_polyline(outline, Color(colors.edge, colors.edge.a * progress), line, true)

	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var mark: = center + dir * radius * 0.78
		draw_rect(Rect2(mark - Vector2.ONE * radius * 0.05, Vector2.ONE * radius * 0.1), Color(colors.ink, 0.35 * progress))
	var sprinting: = _strengths.has("sprint")
	if sprinting:

		draw_polyline(PackedVector2Array([base[7], base[0], base[1], base[2]]), Color(colors.accent, 0.95), line * 2.4, true)
	var knob: = center + _stick * radius * 0.62
	var knob_rect: = Rect2(knob - Vector2.ONE * radius * 0.36, Vector2.ONE * radius * 0.72)
	var knob_shape: = _octagon(knob_rect, 0.29)
	draw_colored_polygon(knob_shape, Color(colors.accent, 0.92) if active else Color(colors.plate, 0.9))
	var knob_outline: = knob_shape.duplicate()
	knob_outline.append(knob_shape[0])
	draw_polyline(knob_outline, Color(colors.ink, 0.9), line * 1.2, true)
	draw_rect(Rect2(knob - Vector2.ONE * radius * 0.08, Vector2.ONE * radius * 0.16), Color(colors.ink, 0.9))
	if editing:
		var selected: = _edit_selected == "joystick"
		draw_rect(button_rect("joystick").grow(6.0), colors.accent if selected else Color(1, 1, 1, 0.35), false, line * (1.6 if selected else 0.8))


func _draw_editor(colors: Dictionary, line: float) -> void :
	var scale: = _reference_scale()
	var title: = tr("EDITAR BOTÕES  ·  ARRASTE PARA MOVER  ·  ") + tr(_edit_name(_edit_selected))
	var fs: = clampi(roundi(24.0 * scale), 12, 24)
	draw_string_outline(_font, Vector2(0, 110.0 * scale), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 5, Color(0.05, 0.05, 0.07, 0.9))
	draw_string(_font, Vector2(0, 110.0 * scale), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, colors.ink)
	var names: = {"smaller": "MENOR", "bigger": "MAIOR", "hide": "OCULTAR" if not bool(_override(_edit_selected).get("hidden", false)) else "MOSTRAR", 
		"reset": "PADRÃO", "done": "CONCLUIR"}
	for tool: String in EDIT_TOOLS:
		var rect: = _tool_rect(tool)
		var enabled: = tool != "hide" or _optional(_edit_selected)
		var shape: = _plate(rect)
		draw_colored_polygon(shape, Color(colors.accent, 0.95) if tool == "done" else Color(0.09, 0.09, 0.11, 0.92 if enabled else 0.5))
		var outline: = shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline, Color(colors.edge, 0.8 if enabled else 0.3), line, true)
		var tfs: = clampi(roundi(rect.size.y * 0.32), 10, 22)
		draw_string(_font, Vector2(rect.position.x, rect.get_center().y + tfs * 0.36), tr(String(names[tool])), HORIZONTAL_ALIGNMENT_CENTER, 
			rect.size.x, tfs, Color(0.08, 0.06, 0.05) if tool == "done" else Color(colors.ink, 1.0 if enabled else 0.4))




func _draw_icon(icon: String, c: Vector2, s: float, ink: Color, accent: Color, w: float) -> void :
	match icon:
		"main_fire", "main_empty", "use":

			var faded: = ink if icon != "main_empty" else Color(ink, ink.a * 0.45)
			draw_arc(c, s * 0.82, 0.0, TAU, 40, faded, w * 1.2, true)
			for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + dir * s * 0.55, c + dir * s * 1.08, faded, w * 1.3, true)
			var bullet: = PackedVector2Array([c + Vector2(0, - s * 0.36), c + Vector2(s * 0.15, - s * 0.16), c + Vector2(s * 0.15, s * 0.3), 
				c + Vector2( - s * 0.15, s * 0.3), c + Vector2( - s * 0.15, - s * 0.16)])
			draw_colored_polygon(bullet, accent if icon != "main_empty" else Color(accent, 0.4))
		"main_strike":

			var a: = c + Vector2( - s * 0.7, s * 0.7)
			var b: = c + Vector2(s * 0.75, - s * 0.75)
			var n: = Vector2(0.7071, 0.7071) * s * 0.16
			draw_colored_polygon(PackedVector2Array([a + n * 0.4, b, a - n * 0.4 + Vector2(s * 0.18, - s * 0.18) - n]), ink)
			draw_line(c + Vector2( - s * 0.55, s * 0.2), c + Vector2( - s * 0.2, s * 0.55), accent, w * 2.2, true)
			draw_arc(c, s * 0.95, - PI * 0.15, PI * 0.65, 20, Color(accent, 0.85), w * 1.2, true)
		"main_throw":

			draw_arc(c + Vector2(s * 0.1, s * 0.75), s * 0.95, PI * 1.05, PI * 1.6, 18, Color(ink, 0.8), w * 1.2, true)
			draw_circle(c + Vector2(s * 0.2, s * 0.1), s * 0.42, ink)
			draw_rect(Rect2(c + Vector2(s * 0.05, - s * 0.48), Vector2(s * 0.32, s * 0.2)), accent)
			draw_line(c + Vector2(s * 0.36, - s * 0.42), c + Vector2(s * 0.62, - s * 0.62), accent, w * 1.4, true)
		"main_extract", "extract":
			_draw_cube_icon(c, s * 1.15, ink, w)
			if icon == "main_extract":

				for k in 3:
					var side: = float(k - 1)
					var at: = Vector2(c.x + side * s * 0.42, c.y - s * (1.02 if k == 1 else 0.86))
					var half: = s * (0.1 if k == 1 else 0.075)
					draw_colored_polygon(PackedVector2Array([at + Vector2(0, - half), at + Vector2(half, 0), at + Vector2(0, half), 
						at + Vector2( - half, 0)]), accent)
		"main_confirm":
			draw_polyline(PackedVector2Array([c + Vector2( - s * 0.6, 0), c + Vector2( - s * 0.15, s * 0.45), c + Vector2(s * 0.7, - s * 0.5)]), accent, w * 3.0, true)
		"main_command":
			draw_circle(c + Vector2(0, s * 0.45), s * 0.14, accent)
			for k in 3:
				draw_arc(c + Vector2(0, s * 0.45), s * (0.4 + k * 0.32), - PI * 0.8, - PI * 0.2, 16, ink, w * 1.3, true)
		"aim":
			draw_arc(c, s * 0.62, 0.0, TAU, 32, ink, w * 1.2, true)
			draw_circle(c, s * 0.12, accent)
			for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + dir * s * 0.32, c + dir * s * 0.92, ink, w * 1.3, true)
		"jump":
			for k in 2:
				var y: = c.y + s * (0.05 + k * 0.42) - s * 0.35
				draw_polyline(PackedVector2Array([Vector2(c.x - s * 0.55, y + s * 0.35), Vector2(c.x, y - s * 0.15), Vector2(c.x + s * 0.55, y + s * 0.35)]), 
					accent if k == 0 else ink, w * 2.2, true)
		"crouch":
			draw_polyline(PackedVector2Array([Vector2(c.x - s * 0.55, c.y - s * 0.45), Vector2(c.x, c.y + s * 0.05), Vector2(c.x + s * 0.55, c.y - s * 0.45)]), accent, w * 2.2, true)
			draw_rect(Rect2(c + Vector2( - s * 0.62, s * 0.35), Vector2(s * 1.24, s * 0.16)), ink)
		"reload":
			draw_arc(c, s * 0.62, - PI * 0.2, PI * 1.45, 28, ink, w * 1.6, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.42, - s * 0.72), c + Vector2(s * 0.86, - s * 0.36), c + Vector2(s * 0.36, - s * 0.2)]), accent)
		"talk":
			var mic: = Rect2(c + Vector2( - s * 0.2, - s * 0.72), Vector2(s * 0.4, s * 0.7))
			draw_colored_polygon(_octagon(mic, 0.45), accent)
			draw_arc(c + Vector2(0, - s * 0.18), s * 0.42, 0.0, PI, 18, ink, w * 1.4, true)
			draw_line(c + Vector2(0, s * 0.24), c + Vector2(0, s * 0.55), ink, w * 1.6, true)
			draw_line(c + Vector2( - s * 0.3, s * 0.58), c + Vector2(s * 0.3, s * 0.58), ink, w * 1.8, true)
		"sprint":
			for k in 3:
				var x: = c.x - s * 0.55 + k * s * 0.42
				draw_polyline(PackedVector2Array([Vector2(x, c.y - s * 0.45), Vector2(x + s * 0.32, c.y), Vector2(x, c.y + s * 0.45)]), accent if k == 2 else ink, w * 1.8, true)
		"plus", "minus":
			draw_line(c + Vector2( - s * 0.55, 0), c + Vector2(s * 0.55, 0), ink, w * 2.4, true)
			if icon == "plus":
				draw_line(c + Vector2(0, - s * 0.55), c + Vector2(0, s * 0.55), ink, w * 2.4, true)
		"console":
			draw_polyline(PackedVector2Array([c + Vector2( - s * 0.6, - s * 0.38), c + Vector2( - s * 0.15, 0), c + Vector2( - s * 0.6, s * 0.38)]), accent, w * 2.0, true)
			draw_line(c + Vector2(s * 0.05, s * 0.36), c + Vector2(s * 0.6, s * 0.36), ink, w * 2.0, true)
		"chat":
			var bubble: = Rect2(c + Vector2( - s * 0.7, - s * 0.5), Vector2(s * 1.4, s * 0.85))
			var shape: = _plate(bubble)
			shape.append(shape[0])
			draw_polyline(shape, ink, w * 1.3, true)
			draw_colored_polygon(PackedVector2Array([bubble.position + Vector2(s * 0.25, s * 0.85), bubble.position + Vector2(s * 0.12, s * 1.15), 
				bubble.position + Vector2(s * 0.55, s * 0.85)]), ink)
			for k in 3:
				draw_rect(Rect2(c + Vector2( - s * 0.42 + k * s * 0.32, - s * 0.12), Vector2(s * 0.14, s * 0.14)), accent)
		"camera":

			var body: = Rect2(c + Vector2( - s * 0.72, - s * 0.38), Vector2(s * 1.44, s * 0.92))
			var outline: = _plate(body)
			outline.append(outline[0])
			draw_polyline(outline, ink, w * 1.3, true)
			draw_rect(Rect2(c + Vector2( - s * 0.32, - s * 0.6), Vector2(s * 0.5, s * 0.22)), ink)
			draw_arc(c + Vector2(0, s * 0.08), s * 0.27, 0.0, TAU, 24, accent, w * 1.6, true)
			draw_circle(c + Vector2(0, s * 0.08), s * 0.1, accent)
		"menu":
			for row in 3:
				draw_rect(Rect2(c + Vector2( - s * 0.62, (float(row) - 1.0) * s * 0.42 - s * 0.08), Vector2(s * 1.24, s * 0.16)), accent if row == 1 else ink)
		"exit":
			draw_line(c + Vector2(s * 0.7, 0), c + Vector2( - s * 0.4, 0), accent, w * 2.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2( - s * 0.7, 0), c + Vector2( - s * 0.25, - s * 0.38), c + Vector2( - s * 0.25, s * 0.38)]), accent)




func _draw_cube_icon(center: Vector2, size: float, light: Color, line_width: float) -> void :
	var r: = size * 0.5
	var w: = r * 0.8660254
	var top: = center + Vector2(0, - r)
	var upper_left: = center + Vector2( - w, - r * 0.5)
	var upper_right: = center + Vector2(w, - r * 0.5)
	var lower_left: = center + Vector2( - w, r * 0.5)
	var lower_right: = center + Vector2(w, r * 0.5)
	var bottom: = center + Vector2(0, r)
	draw_colored_polygon(PackedVector2Array([top, upper_right, center, upper_left]), Color("#ffe9a3"))
	draw_colored_polygon(PackedVector2Array([upper_left, center, bottom, lower_left]), Color("#ffc65c"))
	draw_colored_polygon(PackedVector2Array([center, upper_right, lower_right, bottom]), Color("#c98d2c"))
	var edge: = Color(light.r, light.g, light.b, light.a * 0.9)
	draw_polyline(PackedVector2Array([top, upper_right, lower_right, bottom, lower_left, upper_left, top]), edge, line_width, true)
	draw_polyline(PackedVector2Array([upper_left, center, upper_right]), edge, line_width, true)
	draw_line(center, bottom, edge, line_width, true)

	for corner: Vector2 in [top, upper_right, lower_right, bottom, lower_left, upper_left, center]:
		draw_circle(corner, line_width * 0.5, edge)
