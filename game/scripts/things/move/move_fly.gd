class_name MoveFly
extends ThingMove




const HOVER_BOB_SPEED: = 3.0
const HOVER_BOB_HEIGHT: = 0.08

var _min_altitude: float = 0.0
var _max_pitch: float = 0.0
var _climb_rate: float = 0.0
var _pilot_climb: float = 0.0
var _time: float = 0.0
var _facing: Vector3 = Vector3.FORWARD


func _configure(lex: LexiconData) -> void :
	_min_altitude = lex.balf("movement.fly_min_altitude")
	_max_pitch = deg_to_rad(lex.balf("movement.fly_max_pitch_deg"))
	_climb_rate = lex.balf("movement.fly_climb_rate")
	_pilot_climb = lex.balf("movement.pilot_climb_factor")


func arrive(target: Vector3, heading: Vector3) -> void :
	var up: = Gravity.up_at(target, thing.up())
	thing.global_position = edge_start(target, heading) + up * _min_altitude * 2.0
	thing.velocity = Gravity.flat(heading, up).normalized() * thing.speed
	thing.face(thing.velocity, true)


func pilot(_look: Vector3, yaw: float, wish: Vector3, _delta: float, frame: Basis = Basis.IDENTITY) -> void :
	steering = true
	var turn: = frame * Basis(Vector3.UP, yaw)
	thing.velocity = turn * Vector3(wish.x, 0.0, wish.z) * thing.speed + frame.y * wish.y * thing.speed * _pilot_climb
	_facing = turn * Vector3.FORWARD


func hovers() -> bool:
	return true


func launch(direction: Vector3, launch_speed: float) -> void :
	var dir: = direction.normalized()
	var limit: = sin(_max_pitch)
	var up: = thing.up()
	var vertical: = dir.dot(up)
	dir += up * (clampf(vertical, - limit, limit) - vertical)
	thing.velocity = dir.normalized() * launch_speed


func step(delta: float) -> void :
	_time += delta
	var up: = thing.up()
	var altitude: = Gravity.altitude(thing.global_position)
	if altitude < _min_altitude:
		var vertical: = thing.velocity.dot(up)
		thing.velocity += up * (maxf(vertical, (_min_altitude - altitude) * _climb_rate) - vertical)
	var motion: = thing.velocity * delta
	if thing.velocity.length_squared() < 0.01:
		motion += up * cos(_time * HOVER_BOB_SPEED) * HOVER_BOB_SPEED * HOVER_BOB_HEIGHT * delta
	travel(motion)
	if steering:
		thing.face(_facing, true)
	orient()
