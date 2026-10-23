class_name ControlPlayer
extends Node






var thing: Thing
var pilot: Player = null

var _camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 0.0
var _height: float = 0.0
var _pitch_limit: float = deg_to_rad(80.0)


var frame: Basis = Basis.IDENTITY


func setup(owner_thing: Thing, lex: LexiconData) -> void :
	thing = owner_thing
	var size: = maxf(thing.bounds.size.x, maxf(thing.bounds.size.y, thing.bounds.size.z))
	_distance = lex.balf("pilot.camera_distance") + size
	_height = lex.balf("pilot.camera_height") + size * 0.3


func activate() -> void :
	var owner: = thing.owner_player as Player
	if owner != null and not thing.is_held:
		owner.start_piloting(thing)


func begin(player: Player) -> void :
	pilot = player
	frame = player.gravity_frame
	_yaw = player.yaw
	_pitch = player.head.rotation.x
	if not player.is_local:
		return
	_camera = Camera3D.new()
	_camera.name = "PilotCamera"
	_camera.fov = player.camera.fov
	Forge.fx_root(thing).add_child(_camera)
	_update_camera()
	_camera.make_current()


func end() -> void :
	pilot = null
	if is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	thing.move.steering = false
	if thing.move.hovers():
		thing.velocity = Vector3.ZERO


func look(relative: Vector2, sensitivity: float) -> void :
	_yaw -= relative.x * sensitivity
	_pitch = clampf(_pitch - relative.y * sensitivity, - _pitch_limit, _pitch_limit)


func apply_input(frame: PlayerInputFrame) -> void :
	if not thing.has_simulation_authority() or pilot == null:
		return
	_yaw = frame.yaw
	_pitch = clampf(frame.pitch, - _pitch_limit, _pitch_limit)
	pilot.control_pilot_wish = Vector3(frame.wish.x, frame.climb, frame.wish.y)


func look_direction() -> Vector3:
	return frame * Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Vector3.FORWARD



func _align_frame(delta: float) -> void :
	if not Gravity.active():
		frame = Basis.IDENTITY
		return
	var want: = Gravity.up_at(thing.center(), frame.y)
	var angle: = frame.y.angle_to(want)
	if angle < 0.0001:
		return
	var axis: = frame.y.cross(want)
	axis = axis.normalized() if axis.length() > 0.0001 else frame.x
	var halflife: = Lexicon.balf("space.gravity.air_align_halflife_s")
	var turn: = angle if halflife <= 0.0 else angle * (1.0 - pow(0.5, delta / halflife))
	frame = (Basis(axis, turn) * frame).orthonormalized()


func _physics_process(delta: float) -> void :
	if pilot == null or thing.is_dead:
		return
	_align_frame(delta)
	if not thing.has_simulation_authority():
		return
	var wish: = Vector3.ZERO
	if Session.is_online():
		wish = pilot.control_pilot_wish
	elif not pilot.is_local:
		wish = pilot.control_pilot_wish
	elif pilot.can_act():
		var keys: = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wish = Vector3(keys.x, 0.0, keys.y)
		if Input.is_action_pressed("jump"):
			wish.y += 1.0
		if Input.is_action_pressed("sprint"):
			wish.y -= 1.0
	thing.move.pilot(look_direction(), _yaw, wish, delta, frame)



func point_at(target: Vector3) -> void :
	var d: = frame.transposed() * (target - thing.center())
	_yaw = atan2( - d.x, - d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), - _pitch_limit, _pitch_limit)


func _process(_delta: float) -> void :
	if pilot != null and not thing.is_dead and is_instance_valid(_camera):
		_update_camera()


func _update_camera() -> void :
	var center: = thing.center()
	var direction: = look_direction()
	_camera.global_position = center - direction * _distance + frame.y * _height
	_camera.look_at(center + direction * 20.0, frame.y)
