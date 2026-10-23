class_name FpsMove
extends Node



















signal stepped(rise: float)

var descending_step: = false

var _climb_hold: = 0.0
signal state_changed(from: State, to: State)
signal jumped
signal landed(fall_speed: float)
signal mantle_started(height: float, duration: float)


signal pivot_requested(side: float)

signal staggered(impulse: Vector3)

enum State{STAND, SPRINT, CROUCH, SLIDE, MANTLE, FLY}

var player: Player
var state: State = State.STAND

var height: float = 1.8
var crouch_amount: float = 0.0

var slide_speed: float = 0.0

var sprinting: bool:
	get:
		return state == State.SPRINT
var crouching: bool:
	get:
		return state == State.CROUCH or state == State.SLIDE
var sliding: bool:
	get:
		return state == State.SLIDE
var mantling: bool:
	get:
		return state == State.MANTLE

var _cfg: Dictionary

var _crouch_run: bool = false
var _shape: CapsuleShape3D
var _holder: CollisionShape3D
var _clock: float = 0.0
var _sprint_out_until: float = 0.0
var _slide_dir: = Vector3.FORWARD
var _slide_t: float = 0.0
var _slide_ready_at: float = 0.0
var _mantle: Dictionary = {}
var _fall_speed: float = 0.0
var _was_floor: bool = true
var _was_free: bool = false
var _pivot_ready_at: float = 0.0
var _replaying: bool = false
var _ground_override: int = -1
var _snapshot_floor_normal: = Vector3.UP
var _step_floor_normal: = Vector3.UP


var _friction_override: float = -1.0
var _step_friction: float = 1.0


func setup(owner_player: Player) -> void :
	player = owner_player
	name = "Move"
	_cfg = Lexicon.bal("player.move", {})
	_holder = player.get_node("CollisionShape3D") as CollisionShape3D

	_shape = (_holder.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	_holder.shape = _shape
	height = _f("stand_height_m")
	_apply_height()



func reset() -> void :
	state = State.STAND
	_mantle = {}
	_sprint_out_until = 0.0
	height = _f("stand_height_m")
	_apply_height()



func weapon_ready() -> bool:
	return _clock >= _sprint_out_until and not state in [State.MANTLE, State.SPRINT]




func impact(impulse: Vector3) -> void :
	var cfg: Dictionary = Lexicon.bal("player.impact", {})
	if impulse.length() >= float(cfg.get("stagger_ms", 5.0)):
		staggered.emit(impulse)







func step(delta: float, input: Dictionary, replaying: bool = false) -> void :
	var frame: = player.gravity_frame
	player.velocity = frame.transposed() * player.velocity
	_step(delta, input, replaying)
	player.velocity = frame * player.velocity


func _step(delta: float, input: Dictionary, replaying: bool = false) -> void :
	_replaying = replaying
	_clock += delta
	var p: = player
	var on_floor: = bool(_ground_override) if _ground_override >= 0 else p.is_on_floor()
	_step_floor_normal = p.gravity_frame.transposed() * (_snapshot_floor_normal if _ground_override >= 0 else p.get_floor_normal())
	_step_friction = _friction_override if _friction_override >= 0.0 else Combat.floor_friction(p)
	_ground_override = -1
	_friction_override = -1.0
	if on_floor and Gravity.active() and p.velocity.y > - _f("space_stick_ms"):




		var speed: = Vector3(p.velocity.x, maxf(p.velocity.y, 0.0), p.velocity.z).length()
		var flat: = Vector3(p.velocity.x, 0.0, p.velocity.z)
		p.velocity = flat.normalized() * speed if flat.length() > 0.001 else Vector3.ZERO
		p.velocity.y = - _f("space_stick_ms")
	if on_floor and not _was_floor and not _replaying:
		landed.emit(_fall_speed)
	if not on_floor:
		_fall_speed = maxf(0.0, - p.velocity.y)
	_was_floor = on_floor

	if state == State.MANTLE:
		_step_mantle(delta)
		_update_height(delta)
		return
	var flying: = not p.flight_data().is_empty()
	if flying and state != State.FLY:
		_go(State.FLY)
	elif not flying and state == State.FLY:
		_go(State.STAND)

	var wish: Vector2 = input.get("wish", Vector2.ZERO)
	var wish_dir: = _wish_direction(wish, delta)
	if state != State.FLY:
		_transitions(input, wish, on_floor)
		_vertical(delta, input, wish, wish_dir, on_floor)
		if state == State.MANTLE:
			_update_height(delta)
			return
	else:
		p.velocity.y = float(input.get("climb", 0.0)) * float(p.flight_data().get("climb_speed", 0.0))

	if state == State.SLIDE:
		_step_slide(delta, wish_dir, on_floor)
	else:
		_step_walk(delta, wish_dir, on_floor)
	_update_height(delta)




func _transitions(input: Dictionary, wish: Vector2, on_floor: bool) -> void :
	var p: = player
	if bool(input.get("crouch_pressed", false)):
		match state:
			State.SLIDE:
				_go(State.STAND if _fits(_f("stand_height_m")) else State.CROUCH)
			State.SPRINT:
				var flat: = Vector2(p.velocity.x, p.velocity.z).length()
				_go(State.SLIDE if on_floor and flat >= _f("slide_min_start_ms") and _clock >= _slide_ready_at else State.CROUCH)
			State.CROUCH:
				if _fits(_f("stand_height_m")):
					_go(State.STAND)
			State.STAND:
				_go(State.CROUCH)
	var want_sprint: = bool(input.get("sprint", false)) and wish.length() > 0.1 and not p.aiming and not p.is_using_input()\
	and (p.simulates_free_view() or wish.y < - _f("sprint_forward_min"))

	_crouch_run = want_sprint and state == State.CROUCH
	if want_sprint and state == State.STAND:
		_go(State.SPRINT)
	elif not want_sprint and state == State.SPRINT:
		_go(State.STAND)




func _vertical(delta: float, input: Dictionary, wish: Vector2, wish_dir: Vector3, on_floor: bool) -> void :
	var p: = player
	if not on_floor:
		p.velocity.y -= p.gravity() * delta
	var forward: = wish_dir if wish_dir.length() > 0.1 else _local_forward()
	if bool(input.get("jump_pressed", false)) and (on_floor or state == State.SLIDE):
		if _try_mantle(forward):
			return

		var launch: = Gravity.active() and state == State.CROUCH and on_floor
		if state == State.SLIDE or state == State.CROUCH:
			if not _fits(_f("stand_height_m")):
				return
			_go(State.STAND)
		p.velocity.y = p.jump_speed()
		if launch:
			var cfg: Dictionary = Lexicon.bal("space.launch", {})
			var height: = Gravity.escape_height(p.global_position + p.gravity_frame.y * 0.9) + float(cfg.get("extra_m", 3.0))
			p.velocity.y = maxf(float(cfg.get("min_ms", 9.0)), sqrt(2.0 * p.gravity() * height))
			p.velocity += forward.normalized() * float(cfg.get("forward_ms", 3.0)) if forward.length() > 0.01 else Vector3.ZERO
		if not _replaying:
			jumped.emit()
	elif not on_floor and bool(input.get("jump_held", false)) and wish.y < -0.3:
		_try_mantle(forward)




func _go(to: State) -> void :
	if to == state:
		return
	var from: = state
	match from:
		State.SLIDE:
			_slide_ready_at = _clock + _f("slide_cooldown_s")
		State.SPRINT:

			var out: Dictionary = _cfg.get("sprint_out_s", {})
			var held_class: = String(player.hands.network_item_state().get("hold_class", "none"))
			_sprint_out_until = _clock + float(out.get(held_class, out.get("rifle", 0.15)))
	state = to
	match to:
		State.SLIDE:
			var flat: = Vector3(player.velocity.x, 0.0, player.velocity.z)
			_slide_dir = flat.normalized() if flat.length() > 0.1 else _local_forward()
			slide_speed = minf(flat.length() + _f("slide_boost_ms"), _f("slide_max_ms"))
			_slide_t = 0.0
		State.MANTLE:
			player.velocity = Vector3.ZERO
	if not _replaying:
		state_changed.emit(from, to)



func _wish_direction(wish: Vector2, delta: float) -> Vector3:
	var p: = player
	var free: = p.simulates_free_view()
	if _was_free and not free:
		p.yaw = p.view_yaw
	_was_free = free
	var basis: = Basis(Vector3.UP, p.view_yaw if free else p.yaw)
	var wish_dir: = basis * Vector3(wish.x, 0.0, wish.y)
	if free:
		var cam: Dictionary = Lexicon.bal("player.camera", {})
		_check_pivot(wish_dir)
		if p.simulates_faces_aim():
			p.yaw = RobotSpring.damp_angle(p.yaw, p.view_yaw, float(cam.get("face_aim_halflife_s", 0.04)), delta)
		elif wish_dir.length() > 0.1 and state != State.SLIDE:
			p.yaw = RobotSpring.damp_angle(p.yaw, atan2( - wish_dir.x, - wish_dir.z), float(cam.get("turn_halflife_s", 0.08)), delta)
	else:
		p.view_yaw = p.yaw
	return wish_dir



func _check_pivot(wish_dir: Vector3) -> void :
	var p: = player
	var flat: = Vector3(p.velocity.x, 0.0, p.velocity.z)
	var cfg: Dictionary = Lexicon.bal("robot.pivot", {})
	if _clock < _pivot_ready_at or p.simulates_faces_aim() or not p.is_on_floor() or wish_dir.length() < 0.1 or flat.length() < float(cfg.get("min_speed_ms", 2.0)) or state == State.SLIDE:
		return
	var turn: = flat.signed_angle_to(wish_dir, Vector3.UP)
	if absf(turn) >= deg_to_rad(float(cfg.get("start_deg", 120.0))):
		_pivot_ready_at = _clock + float(cfg.get("cooldown_s", 0.55))
		if not _replaying:
			pivot_requested.emit(signf(turn))


func _step_walk(delta: float, wish_dir: Vector3, on_floor: bool) -> void :
	var p: = player
	var speed: = p.walk_speed() * p.speed_mults()
	match state:
		State.SPRINT:
			speed = p.sprint_speed() * p.speed_mults()
		State.CROUCH:
			speed = _f("crouch_run_speed" if _crouch_run else "crouch_speed") * p.speed_mults()
		State.FLY:
			speed = float(p.flight_data().get("fly_speed", speed))
	var target: = wish_dir * speed * Status.speed_mult(p)
	var accel: = p.accel_ground() if on_floor or state == State.FLY else p.accel_air()
	if p.in_zero_g and not on_floor:
		accel = Lexicon.balf("space.air_accel_zero_g")
	if on_floor:
		accel *= _step_friction
	var horizontal: = Vector3(p.velocity.x, 0.0, p.velocity.z).move_toward(target, accel * delta)
	p.velocity.x = horizontal.x
	p.velocity.z = horizontal.z
	var before: = p.global_transform
	var rising: = p.velocity.y > 0.5
	_slide()
	if (on_floor or descending_step) and state != State.FLY:
		if on_floor:
			_step_up(before, horizontal, delta)


			var climbed: = (p.global_position - before.origin).dot(p.gravity_frame.y)
			if not rising and climbed > _f("step_smooth_min_m"):


				_climb_hold = _f("step_climb_hold_s")
				if not _replaying:
					stepped.emit(climbed)
		if _climb_hold > 0.0:
			_climb_hold -= delta
			descending_step = false
		else:
			_snap_step_down()
	else:
		descending_step = false
	if p.has_simulation_authority() and not _replaying:
		Combat.surface_contacts(p)




func _step_slide(delta: float, wish_dir: Vector3, on_floor: bool) -> void :
	var p: = player
	var push: = 0.0
	if on_floor:

		var n: = _step_floor_normal
		push = p.gravity() * Vector3(n.x, 0.0, n.z).dot(_slide_dir) * _f("slide_slope_mult")
		slide_speed += (push - _f("slide_friction_ms2") * _step_friction) * delta

	if push < _f("slide_friction_ms2"):
		_slide_t += delta
	if wish_dir.length() > 0.1:
		var turn: = clampf(_slide_dir.signed_angle_to(wish_dir.normalized(), Vector3.UP), -1.0, 1.0)\
		* deg_to_rad(_f("slide_steer_deg_s")) * delta
		_slide_dir = _slide_dir.rotated(Vector3.UP, turn).normalized()
	slide_speed = minf(slide_speed, _f("slide_downhill_max_ms"))
	p.velocity.x = _slide_dir.x * slide_speed
	p.velocity.z = _slide_dir.z * slide_speed
	_slide()
	if p.has_simulation_authority() and not _replaying:
		Combat.surface_contacts(p)

	slide_speed = minf(slide_speed, Vector2(p.velocity.x, p.velocity.z).length() + 0.01)
	if on_floor and (slide_speed < _f("slide_end_ms") or _slide_t > _f("slide_max_s")):
		_go(State.CROUCH)





func _try_mantle(forward: Vector3) -> bool:
	var p: = player
	var frame: = p.gravity_frame
	var fwd: = Vector3(forward.x, 0.0, forward.z)
	if fwd.length() < 0.01:
		return false
	fwd = fwd.normalized()
	var space: = p.get_world_3d().direct_space_state
	var mask: = PhysicsLayers.WORLD | PhysicsLayers.THINGS
	var feet: = frame.transposed() * p.global_position
	var reach: = _shape.radius + _f("mantle_reach_m")
	var wall: = {}
	for probe_h: float in [_f("mantle_min_m") * 0.8, 1.1]:
		var from: = feet + Vector3.UP * probe_h
		var query: = PhysicsRayQueryParameters3D.create(frame * from, frame * (from + fwd * reach), mask, [p.get_rid()])
		wall = space.intersect_ray(query)
		if not wall.is_empty() and absf((frame.transposed() * (wall["normal"] as Vector3)).y) < 0.5:
			break
		wall = {}
	if wall.is_empty():
		return false
	var hit: = frame.transposed() * (wall["position"] as Vector3)
	var over: = Vector3(hit.x, feet.y, hit.z) + fwd * (_shape.radius + 0.08)
	var down: = PhysicsRayQueryParameters3D.create(frame * (over + Vector3.UP * (_f("mantle_max_m") + 0.4)), 
		frame * (over + Vector3.UP * (_f("mantle_min_m") * 0.5)), mask, [p.get_rid()])
	var top: = space.intersect_ray(down)
	if top.is_empty() or (frame.transposed() * (top["normal"] as Vector3)).y < 0.7:
		return false
	var top_local: = frame.transposed() * (top["position"] as Vector3)
	var rise: = top_local.y - feet.y
	if rise < _f("mantle_min_m") or rise > _f("mantle_max_m"):
		return false
	var to: = Vector3(over.x, top_local.y + 0.02, over.z)
	var fit: = _f("stand_height_m") if _fits_at(frame * to, _f("stand_height_m")) else _f("crouch_height_m")
	if not _fits_at(frame * to, fit):
		return false
	_mantle = {"from": feet, "to": to, "t": 0.0, "crouch": fit < _f("stand_height_m"), "frame": frame, 
		"dur": lerpf(_f("mantle_min_s"), _f("mantle_max_s"), clampf(rise / _f("mantle_max_m"), 0.0, 1.0))}
	_go(State.MANTLE)
	if not _replaying:
		mantle_started.emit(rise, float(_mantle["dur"]))
	return true



func _step_mantle(delta: float) -> void :
	var p: = player
	var frame: Basis = _mantle.get("frame", p.gravity_frame)
	_mantle["t"] = float(_mantle["t"]) + delta / maxf(float(_mantle["dur"]), 0.01)
	var u: = clampf(float(_mantle["t"]), 0.0, 1.0)
	var from: Vector3 = _mantle["from"]
	var to: Vector3 = _mantle["to"]
	var up: = 1.0 - pow(1.0 - clampf(u / 0.7, 0.0, 1.0), 2.0)
	var ahead: = smoothstep(0.35, 1.0, u)
	var before: = frame.transposed() * p.global_position
	var now: = Vector3(lerpf(from.x, to.x, ahead), lerpf(from.y, to.y + 0.05, up), lerpf(from.z, to.z, ahead))
	p.global_position = frame * now

	p.velocity = p.gravity_frame.transposed() * (frame * ((now - before) / maxf(delta, 0.0001)))
	if u >= 1.0:
		var dir: Vector3 = to - from
		dir.y = 0.0
		p.velocity = p.gravity_frame.transposed() * (frame * (dir.normalized() * _f("mantle_exit_ms"))) if dir.length() > 0.01 else Vector3.ZERO
		_go(State.CROUCH if bool(_mantle["crouch"]) else State.STAND)
		_mantle = {}




func _update_height(delta: float) -> void :
	var target: = _f("stand_height_m")
	if state == State.SLIDE:
		target = _f("slide_height_m")
	elif state == State.CROUCH or (state == State.MANTLE and bool(_mantle.get("crouch", false))):
		target = _f("crouch_height_m")
	height = move_toward(height, target, _f("height_change_mps") * delta)
	_apply_height()


func _apply_height() -> void :
	var stand: = _f("stand_height_m")
	_shape.height = height
	_holder.position.y = height * 0.5
	player.head.position.y = player.eye_height() - (stand - height)
	crouch_amount = (stand - height) / maxf(stand - _f("crouch_height_m"), 0.01)



func _fits(h: float) -> bool:
	return h <= height + 0.001 or _fits_at(player.global_position, h)


func _fits_at(feet: Vector3, h: float) -> bool:
	var capsule: = CapsuleShape3D.new()
	capsule.radius = _shape.radius
	capsule.height = h
	var query: = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(player.gravity_frame, feet + player.gravity_frame.y * (h * 0.5 + 0.02))
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.THINGS
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()






func _step_up(before: Transform3D, horizontal_local: Vector3, delta: float) -> void :
	var p: = player
	var frame: = p.gravity_frame
	var up: = frame.y
	var want: = frame * horizontal_local * delta
	if want.length() < 0.0001 or not p.is_on_wall():
		return


	var kept: = Vector3(p.velocity.x, 0.0, p.velocity.z)
	if kept.length() >= horizontal_local.length() * 0.92:
		return
	var step: = _f("step_up_m")
	var dir: = want.normalized()
	var feet: = before.origin
	var space: = p.get_world_3d().direct_space_state

	var rise: = -1.0
	for turn: float in [0.0, 0.5, -0.5, 1.05, -1.05]:
		var probe: = feet + dir.rotated(up, turn) * (_shape.radius + 0.08)
		var query: = PhysicsRayQueryParameters3D.create(probe + up * (step + 0.05), probe - up * 0.05, 
			PhysicsLayers.WORLD | PhysicsLayers.THINGS, [p.get_rid()])
		var hit: = space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(up) < cos(p.floor_max_angle):
			continue
		var h: = ((hit.position as Vector3) - feet).dot(up)
		if h > 0.02 and h <= step + 0.01:
			rise = maxf(rise, h)
	if rise < 0.0:
		return


	var lifted: = false
	for lift: float in [rise + 0.02, minf(rise + 0.08, step + 0.04)]:
		var t: = before
		if p.test_move(t, up * lift):
			continue
		t.origin += up * lift
		for reach: float in [maxf(want.length(), 0.06), 0.06]:
			var ahead: = dir * reach
			if not p.test_move(t, ahead):
				p.global_position = t.origin + ahead
				lifted = true
				break
		if lifted:
			break
	if not lifted:
		return
	_refresh_floor(horizontal_local)




func _snap_step_down() -> void :
	var p: = player
	if p.is_on_floor() or p.velocity.y > 0.5:
		descending_step = false
		return
	var up: = p.gravity_frame.y
	var reach: = _f("step_down_m")
	var hit: = KinematicCollision3D.new()
	if p.test_move(p.global_transform, - up * reach, hit) and hit.get_normal().dot(up) >= cos(p.floor_max_angle):
		p.global_position += hit.get_travel()

		var fell: = - hit.get_travel().dot(up)
		if fell > _f("step_smooth_min_m") and not _replaying:
			stepped.emit( - fell)
		_refresh_floor(Vector3(p.velocity.x, 0.0, p.velocity.z))
		descending_step = false
		return


	var query: = PhysicsRayQueryParameters3D.create(p.global_position + up * 0.1, p.global_position - up * reach, 
		PhysicsLayers.WORLD | PhysicsLayers.THINGS, [p.get_rid()])
	var ground: = p.get_world_3d().direct_space_state.intersect_ray(query)
	descending_step = not ground.is_empty() and (ground.normal as Vector3).dot(up) >= cos(p.floor_max_angle)
	if descending_step:
		p.velocity.y = minf(p.velocity.y, - _f("step_drop_ms"))




func _refresh_floor(keep: Vector3) -> void :
	var p: = player
	p.velocity = Vector3(0.0, - maxf(_f("space_stick_ms"), 0.3), 0.0)
	_slide()
	p.velocity = Vector3(keep.x, 0.0, keep.z)



func _slide() -> void :
	var p: = player
	var frame: = p.gravity_frame
	p.velocity = frame * p.velocity
	p.move_and_slide()
	p.velocity = frame.transposed() * p.velocity



func _local_forward() -> Vector3:
	return Basis(Vector3.UP, player.yaw) * Vector3.FORWARD


func _f(key: String) -> float:
	return float(_cfg.get(key, 0.0))



func export_network_state() -> Dictionary:
	return {"state": state, "height": height, "crouch_amount": crouch_amount, "slide_speed": slide_speed, 
		"clock": _clock, "sprint_out_until": _sprint_out_until, "slide_dir": _slide_dir, 
		"slide_t": _slide_t, "slide_ready_at": _slide_ready_at, "mantle": _mantle.duplicate(true), 
		"fall_speed": _fall_speed, "was_floor": _was_floor, "was_free": _was_free, 
		"pivot_ready_at": _pivot_ready_at, "crouch_run": _crouch_run, "climb_hold": _climb_hold, "on_floor": player.is_on_floor(), 
		"floor_normal": player.get_floor_normal() if player.is_on_floor() else Vector3.UP, 
		"floor_friction": Combat.floor_friction(player)}



func apply_network_state(data: Dictionary) -> void :
	state = clampi(int(data.get("state", State.STAND)), State.STAND, State.FLY) as State
	height = clampf(float(data.get("height", _f("stand_height_m"))), _f("slide_height_m"), _f("stand_height_m"))
	slide_speed = float(data.get("slide_speed", 0.0))
	_clock = float(data.get("clock", 0.0))
	_sprint_out_until = float(data.get("sprint_out_until", 0.0))
	_slide_dir = data.get("slide_dir", Vector3.FORWARD)
	_slide_t = float(data.get("slide_t", 0.0))
	_slide_ready_at = float(data.get("slide_ready_at", 0.0))
	_mantle = (data.get("mantle", {}) as Dictionary).duplicate(true)
	_fall_speed = float(data.get("fall_speed", 0.0))
	_was_floor = bool(data.get("was_floor", true))
	_was_free = bool(data.get("was_free", false))
	_pivot_ready_at = float(data.get("pivot_ready_at", 0.0))
	_crouch_run = bool(data.get("crouch_run", false))
	_climb_hold = float(data.get("climb_hold", 0.0))
	_ground_override = int(bool(data.get("on_floor", false)))
	_snapshot_floor_normal = data.get("floor_normal", Vector3.UP)
	_friction_override = clampf(float(data.get("floor_friction", 1.0)), 0.0, 1.0)
	_apply_height()
