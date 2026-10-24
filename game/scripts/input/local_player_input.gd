class_name LocalPlayerInput
extends PlayerInputProvider


var _pending: = {}
var _slot: = -1


func queue_action(action: String, pressed: bool = true, slot_index: int = -1) -> void :
	if action == "slot":
		_slot = slot_index
	elif action == "use":
		_pending["use_pressed" if pressed else "use_released"] = true
	elif action in ["reload", "exit_pilot", "toggle_extract", "pickup", "drop_item"] and pressed:
		_pending[action] = true


func clear() -> void :
	_pending.clear()
	_slot = -1


func capture(player: Player) -> PlayerInputFrame:
	var frame: = PlayerInputFrame.new()
	frame.wish = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	frame.sprint = Input.is_action_pressed("sprint")
	frame.jump_pressed = Input.is_action_just_pressed("jump")
	frame.jump_held = Input.is_action_pressed("jump")
	frame.crouch_pressed = Input.is_action_just_pressed("crouch")
	frame.climb = float(frame.jump_held) - float(frame.sprint)
	frame.yaw = wrapf(player.view_yaw if player.is_free_view() else player.yaw, - PI, PI)
	frame.pitch = player.head.rotation.x if player.head != null else 0.0
	if is_instance_valid(player.piloting) and player.piloting.control is ControlPlayer:
		var pilot: = player.piloting.control as ControlPlayer
		frame.yaw = wrapf(pilot._yaw, - PI, PI)
		frame.pitch = pilot._pitch
	frame.free_view = player.is_free_view()
	frame.aiming = Input.is_action_pressed("aim")
	frame.use_held = Input.is_action_pressed("use")
	frame.use_pressed = Input.is_action_just_pressed("use")
	frame.use_released = Input.is_action_just_released("use")
	frame.reload = Input.is_action_just_pressed("reload")
	frame.pickup = Input.is_action_just_pressed("pickup")
	frame.drop_item = Input.is_action_just_pressed("drop_item")
	frame.exit_pilot = Input.is_action_just_pressed("exit_pilot")
	for key: String in _pending:
		frame.set(key, true)
	frame.slot = _slot
	if frame.slot < 0:
		for i in 3:
			if Input.is_action_just_pressed("slot_%d" % (i + 1)):
				frame.slot = i
	clear()
	return frame
