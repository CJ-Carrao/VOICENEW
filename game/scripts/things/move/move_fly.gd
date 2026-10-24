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

func _autonomous() -> bool:
	return thing.category in ["creature", "vehicle"] and not steering


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
	var ecology := thing.get_node_or_null("EcologyBehavior")
	var hunting := ecology != null and not String(ecology.diet).is_empty() and steering
	var up: = thing.up()
	var altitude: = Gravity.altitude(thing.global_position)
	var query := PhysicsRayQueryParameters3D.create(thing.center(), thing.center() - up * 40.0, PhysicsLayers.WORLD)
	var ground := thing.get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty():
		altitude = maxf(0.0, (thing.global_position - (ground.position as Vector3)).dot(up))
	if _autonomous():
		var target := Combat.nearest_enemy(thing.center(), thing.team, get_tree())
		var center := Combat.center_of(target) if target != null else (thing.owner_player.global_position if is_instance_valid(thing.owner_player) else thing.global_position)
		var orbit := Gravity.frame_for(up) * Vector3(cos(_time * 0.45 + thing.get_instance_id() % 13), 0, sin(_time * 0.45 + thing.get_instance_id() % 13)) * 4.0
		var direction := Gravity.flat(center + orbit - thing.global_position, up)
		if direction.length_squared() < 0.01:
			direction = Gravity.flat(-thing.global_basis.z, up)
		var desired := direction.normalized() * maxf(thing.speed, 0.8)
		var flat := Gravity.flat(thing.velocity, up).lerp(desired, 1.0 - exp(-3.0 * delta))
		var height := maxf(_min_altitude, thing.bounds.size.y * 0.55 + 1.0)
		thing.velocity = flat + up * clampf((height - altitude) * 2.0, -_climb_rate, _climb_rate)
	elif altitude < _min_altitude and not hunting:
		var vertical: = thing.velocity.dot(up)
		thing.velocity += up * (maxf(vertical, (_min_altitude - altitude) * _climb_rate) - vertical)
	var motion: = thing.velocity * delta
	if thing.velocity.length_squared() < 0.01:
		motion += up * cos(_time * HOVER_BOB_SPEED) * HOVER_BOB_SPEED * HOVER_BOB_HEIGHT * delta
	travel(motion)
	if hunting and thing.velocity.length_squared() > 0.01:
		thing.face(thing.velocity, true)
	elif steering:
		thing.face(_facing, true)
	orient()

func _react(collision_info: KinematicCollision3D) -> void:
	if thing.category not in ["creature", "vehicle"]:
		super._react(collision_info)
		return
	landed = false
	thing.velocity = thing.velocity.slide(collision_info.get_normal())
	if thing.velocity.length_squared() < 0.1:
		thing.velocity = (thing.up() + thing.global_basis.x).normalized() * maxf(thing.speed, 1.0)
