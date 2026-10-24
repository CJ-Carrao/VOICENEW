class_name MoveChaseEnemy
extends ThingMove





const AIRBORNE: = ["fly", "flyover", "straight", "follow_aim"]

const GROUND_PROBE: = 0.05

var _turn: float = 0.0
var _speed: float = 0.0
var _airborne: bool = false

var _grounded: bool = false
var _wander_time := 0.0


func _configure(lex: LexiconData) -> void :
	_turn = deg_to_rad(lex.balf("movement.chase_turn_deg_per_s"))
	_speed = thing.speed if thing.speed > 0.0 else lex.balf("movement.chase_default_speed") * float(
		(thing.node_data.get("mods", {}) as Dictionary).get("speed", 1.0))
	var def: = lex.thing_def(thing.thing_id)
	var role_def: Dictionary = (def.get("roles", {}) as Dictionary).get(thing.role, {})
	_airborne = String(role_def.get("movement", def.get("movement", "static"))) in AIRBORNE


func launch(direction: Vector3, launch_speed: float) -> void :
	thing.velocity = direction.normalized() * (launch_speed if launch_speed > 0.0 else 0.0)


func hovers() -> bool:
	return _airborne


func step(delta: float) -> void :
	_wander_time += delta
	var up: = thing.up()
	if not steering:
		var enemy: = Combat.nearest_enemy(thing.center(), thing.team, get_tree())
		var flat: = Gravity.flat(thing.velocity, up)
		if enemy == null:
			if thing.category in ["creature", "vehicle"]:
				var forward := Gravity.flat(-thing.global_basis.z, up).normalized()
				flat = forward.rotated(up, sin(_wander_time * 0.4 + thing.get_instance_id() % 7) * delta * 0.6) * _speed * 0.65
				if _airborne: thing.velocity = flat
			elif _airborne:
				thing.velocity = thing.velocity.move_toward(Vector3.ZERO, _speed * delta)
			else:
				flat = flat.move_toward(Vector3.ZERO, _speed * delta)
		else:
			var desired: = Combat.center_of(enemy) - thing.center()
			if _airborne:
				var current: = thing.velocity if thing.velocity.length_squared() > 0.01 else desired.normalized() * 0.1
				thing.velocity = steer(current, desired, _turn * delta).normalized() * _speed
			else:
				desired = Gravity.flat(desired, up)
				var current: = flat if flat.length_squared() > 0.01 else desired.normalized() * 0.1
				flat = steer(current, desired, _turn * delta).normalized() * _speed
		if not _airborne:
			thing.velocity = flat + up * thing.velocity.dot(up)
	if not _airborne:
		if _grounded and not thing.test_move(thing.global_transform, - up * GROUND_PROBE):
			_grounded = false
		var vertical: = thing.velocity.dot(up)
		thing.velocity = Gravity.flat(thing.velocity, up) + (Vector3.ZERO if _grounded else up * vertical + gravity_accel() * delta)
	travel(thing.velocity * delta)
	if not steering and thing.velocity.length_squared() > 0.01:
		thing.face(thing.velocity, not _airborne or thing.upright)


func _react(collision_info: KinematicCollision3D) -> void :
	if thing.impact == "destroy":
		thing.die()
		return
	var normal: = collision_info.get_normal()
	var up: = thing.up()
	if normal.dot(up) >= _floor_min_y:
		thing.velocity = Gravity.flat(thing.velocity, up)
		_grounded = not _airborne
	else:
		thing.velocity = thing.velocity.slide(normal)
