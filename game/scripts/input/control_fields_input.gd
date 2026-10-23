class_name ControlFieldsInput
extends PlayerInputProvider




func capture(player: Player) -> PlayerInputFrame:
	var frame: = PlayerInputFrame.new()
	frame.wish = player.control_wish
	frame.sprint = player.control_sprint
	frame.jump_pressed = player.control_jump
	frame.jump_held = player.control_jump
	frame.crouch_pressed = player.control_crouch
	frame.climb = player.control_climb
	player.control_jump = false
	player.control_crouch = false
	return frame
