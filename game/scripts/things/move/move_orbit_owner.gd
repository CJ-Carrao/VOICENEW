class_name MoveOrbitOwner
extends ThingMove






const GOLDEN_ANGLE: = 2.39996


static var _joined: Dictionary = {}

static var _orbiters: Dictionary = {}

var _radius: float = 0.0
var _height: float = 0.0
var _angular: float = 0.0
var _catch_up: float = 0.0
var _angle: float = 0.0
var _anchor_point: Vector3 = Vector3.ZERO
var _started: bool = false


func _configure(lex: LexiconData) -> void :
	var size: = maxf(thing.bounds.size.x, thing.bounds.size.z)
	_radius = lex.balf("movement.orbit_radius") + size
	_height = lex.balf("movement.orbit_height")
	var speed: = thing.speed if thing.speed > 0.0 else lex.balf("movement.orbit_default_speed")
	_angular = speed / _radius
	_catch_up = lex.balf("movement.orbit_catch_up")


func hovers() -> bool:
	return true


func launch(_direction: Vector3, _launch_speed: float) -> void :
	thing.velocity = Vector3.ZERO


func step(delta: float) -> void :
	var center: = _center()
	if not _started:
		_started = true
		var count: = int(_joined.get(thing.owner_id, 0))
		_joined[thing.owner_id] = count + 1
		var offset: = _frame().transposed() * (thing.global_position - center)
		_angle = atan2(offset.z, offset.x) + GOLDEN_ANGLE * count
		var others: Array = _orbiters.get_or_add(thing.owner_id, [])
		others.assign(others.filter( func(other: Variant) -> bool: return is_instance_valid(other) and not (other as Thing).is_dead))
		for other: Thing in others:
			thing.add_collision_exception_with(other)
			other.add_collision_exception_with(thing)
		others.append(thing)
	if steering:
		travel(thing.velocity * delta)
		return
	_angle += _angular * delta

	var frame: = _frame()
	var goal: = center + frame * (Vector3(cos(_angle), 0.0, sin(_angle)) * _radius + Vector3.UP * _height)
	thing.velocity = (goal - thing.global_position) * _catch_up
	travel(thing.velocity * delta)
	var tangent: = frame * Vector3( - sin(_angle), 0.0, cos(_angle))
	thing.face(tangent, true)



func _frame() -> Basis:
	var owner: = thing.owner_player as Player
	if owner != null and is_instance_valid(owner):
		return owner.gravity_frame
	return Gravity.frame_for(Gravity.up_at(_anchor_point, thing.up()))



func _center() -> Vector3:
	var owner: = thing.owner_player
	if owner != null and is_instance_valid(owner) and ( not owner.has_method("is_alive") or owner.call("is_alive")):
		_anchor_point = owner.global_position
	elif _anchor_point == Vector3.ZERO:
		_anchor_point = thing.global_position
	return _anchor_point


func _react(_collision_info: KinematicCollision3D) -> void :
	if thing.impact == "destroy":
		thing.die()
