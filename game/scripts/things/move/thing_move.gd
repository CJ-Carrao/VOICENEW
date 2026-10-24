class_name ThingMove
extends Node







var thing: Thing

var landed: bool = false

var steering: bool = false

var _gravity: float = 0.0
var _bounce_damping: float = 0.0
var _floor_min_y: float = 0.0
var _pilot_turn: float = 0.0
var _arena_half: float = 0.0
var _edge_margin: float = 0.0


func setup(owner_thing: Thing, lex: LexiconData) -> void :
	thing = owner_thing
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	_bounce_damping = lex.balf("movement.bounce_damping")
	_floor_min_y = lex.balf("movement.floor_normal_min_y")
	_pilot_turn = deg_to_rad(lex.balf("movement.pilot_turn_deg_per_s"))
	_arena_half = lex.balf("arena.size") * 0.5
	_edge_margin = lex.balf("movement.arrival_edge_margin")
	_configure(lex)



func launch(direction: Vector3, launch_speed: float) -> void :
	thing.velocity = direction.normalized() * launch_speed



func hovers() -> bool:
	return false




func arrive(target: Vector3, _heading: Vector3) -> void :
	thing.global_position = target
	thing.velocity = Vector3.ZERO





func pilot(look: Vector3, _yaw: float, _wish: Vector3, delta: float, _frame: Basis = Basis.IDENTITY) -> void :
	steering = true
	if thing.velocity.length_squared() > 0.01:
		thing.velocity = steer(thing.velocity, look, _pilot_turn * delta)



static func steer(velocity: Vector3, desired: Vector3, max_angle: float) -> Vector3:
	var speed: = velocity.length()
	if speed < 0.0001 or desired.length_squared() < 0.0001:
		return velocity
	var from: = velocity / speed
	var to: = desired.normalized()
	var angle: = from.angle_to(to)
	if angle < 0.0001:
		return to * speed
	return from.slerp(to, minf(1.0, max_angle / angle)) * speed




func gravity_accel() -> Vector3:
	return Gravity.direction_at(thing.global_position) * _gravity




func edge_start(target: Vector3, heading: Vector3) -> Vector3:
	if Gravity.active():
		var up: = Gravity.up_at(target)
		var back: = - Gravity.flat(heading, up)
		if back.length_squared() < 0.0001:
			back = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD)
		var box: = Gravity.world_half() - Vector3.ONE
		var start: = target + back.normalized() * Lexicon.balf("space.arrival_m")
		return start.clamp( - box, box) if box != - Vector3.ONE else start
	var dir: = Vector3(heading.x, 0.0, heading.z)
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.RIGHT
	var back: = - dir
	var t: = INF
	if absf(back.x) > 0.0001:
		t = minf(t, ((_arena_half if back.x > 0.0 else - _arena_half) - target.x) / back.x)
	if absf(back.z) > 0.0001:
		t = minf(t, ((_arena_half if back.z > 0.0 else - _arena_half) - target.z) / back.z)
	if t == INF:
		t = _arena_half
	return target + back * (maxf(t, 0.0) + _edge_margin)


func _configure(_lex: LexiconData) -> void :
	pass


func _physics_process(delta: float) -> void :
	if thing == null or not thing.has_simulation_authority()\
	or landed or not thing.is_active or thing.is_held or thing.is_dead or thing.ground_item:
		return
	if Status.movement_locked(thing):
		thing.velocity = Vector3.ZERO
		return
	var orders := thing.get_node_or_null("AnimalOrders")
	if orders != null and orders.active():
		orders.drive(delta)
		return
	step(delta)


func step(_delta: float) -> void :
	pass



func travel(motion: Vector3) -> void :
	if Status.movement_locked(thing):
		thing.velocity = Vector3.ZERO
		return
	if motion.length_squared() < 1e-10:
		return
	var collision_info: = thing.move_and_collide(motion * Status.speed_mult(thing))
	if collision_info == null:
		return
	thing.report_hit(collision_info)
	var surface: = collision_info.get_collider() as Thing
	if surface != null and not surface.is_dead:
		surface.surface_touch(thing, collision_info.get_position(), - collision_info.get_normal())
	if thing.is_dead or landed:
		return
	_react(collision_info)


func orient() -> void :
	if steering:
		return
	if thing.velocity.length_squared() > 0.01:
		thing.face(thing.velocity, thing.upright)


func _react(collision_info: KinematicCollision3D) -> void :
	var normal: = collision_info.get_normal()
	var floor_up: = thing.up()
	match thing.impact:
		"destroy":
			thing.die()
		"bounce":
			thing.velocity = thing.velocity.bounce(normal) * (1.0 - _bounce_damping)
		_:

			if normal.dot(floor_up) >= _floor_min_y:
				var surface: = collision_info.get_collider() as Thing
				if surface != null and surface.surface_friction < 1.0 and thing.velocity.length() > 0.1:
					thing.velocity = thing.velocity.slide(normal) * (1.0 - surface.surface_friction)
				else:
					thing.velocity = Vector3.ZERO
					landed = true
			else:
				thing.velocity = thing.velocity.bounce(normal) * _bounce_damping
