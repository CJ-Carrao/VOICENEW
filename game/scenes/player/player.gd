class_name Player
extends CharacterBody3D













signal health_changed(current: float, maximum: float)
signal matter_changed(current: float, capacity: float)
signal extracting_changed(on: bool)
signal died(player: Player)

signal damaged(amount: float, source: Node)

signal revived
signal piloting_changed(thing: Thing)
signal abilities_changed
signal input_generated(frame: PlayerInputFrame)

@export var player_id: int = 1

@export var peer_id: int = 0
@export var team: int = 1
@export var is_local: bool = true
@export var display_name: String = "VOCÊ"
@export var body_color: Color = Color(0.25, 0.55, 0.95)

var paint_bytes: = PackedByteArray()


var input_enabled: bool = true:
	set(value):
		input_enabled = value
		if not value:
			release_input()

var frozen: bool = false:
	set(value):
		frozen = value
		if value:
			release_input()

var respawn_on_death: bool = true

var aiming: bool = false

var piloting: Thing = null
var health: float = 0.0
var max_health: float = 0.0

var matter: float = 0.0
var max_matter: float = 0.0


var matter_credit: float = 0.0

var extracting: bool = false
var extractor: Extractor

var shaper: Shaper

var robot: RobotBody

var view: ViewCamera


var move: FpsMove
var feel: FpsFeel


var eye_offset: = Vector3.ZERO

var orb_hand: Node3D


var view_yaw: float = 0.0



var gravity_frame: Basis = Basis.IDENTITY

var in_zero_g: bool = false

var _air_ticks: int = 0
const GROUND_GRACE_TICKS: = 4

var yaw: float = 0.0:
	set(value):
		yaw = value
		_orient()



var control_wish: Vector2 = Vector2.ZERO
var control_sprint: bool = false
var control_jump: bool = false
var control_climb: float = 0.0

var control_crouch: bool = false
var control_pilot_wish: Vector3 = Vector3.ZERO

var input_provider: PlayerInputProvider

const MAX_PREDICTION_FRAMES: = 180
const NETWORK_INTERPOLATION_SPEED: = 18.0
var network_role: String = "offline"
var network_active: bool = false
var network_epoch: int = 0
var network_corrections: int = 0
var last_correction_distance: float = 0.0
var _network_seq: int = 0
var _network_event_seq: int = 0
var _network_revision: int = 0
var _network_received_revision: int = -1
var _network_ack_input: int = 0
var _network_ack_event: int = 0
var _predicted_extract_event: int = 0
var _network_last_snapshot: int = -1
var _network_free_view: bool = false
var _network_use_held: bool = false
var _network_face_aim: bool = false
var _network_piloting: bool = false
var _network_rigid: bool = false
var _network_impulse_until: int = 0
var _network_ground: bool = false
var _network_target: Dictionary = {}
var _prediction_history: Array[PlayerInputFrame] = []

var _walk_speed: float = 0.0
var _sprint_speed: float = 0.0
var _jump_velocity: float = 0.0
var _accel_ground: float = 0.0
var _accel_air: float = 0.0
var _mouse_sensitivity: float = 0.0
var _aim_range: float = 0.0
var _gravity: float = 0.0
var _kill_y: float = 0.0
var _clock: float = 0.0

var _face_aim_until: float = 0.0
var _spawn: Transform3D = Transform3D.IDENTITY

var _abilities: Dictionary = {}

var _pending_ability: Dictionary = {}

var _base_fov: float = 0.0
var _hands_base: Vector3 = Vector3.ZERO
var _carry_w: float = 0.0
var _recoil_debt: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head / Camera3D
@onready var hands: Hands = $Head / Camera3D / Hands
@onready var body: MeshInstance3D = $Body


func _ready() -> void :
	_setup_input_provider()
	add_to_group(Combat.COMBATANTS_GROUP)
	_walk_speed = Lexicon.balf("player.walk_speed")
	_sprint_speed = Lexicon.balf("player.sprint_speed")
	_jump_velocity = Lexicon.balf("player.jump_velocity")
	_accel_ground = Lexicon.balf("player.accel_ground")
	_accel_air = Lexicon.balf("player.accel_air")
	_base_fov = camera.fov
	apply_user_settings()

	_hands_base = _v3(Lexicon.bal("player.hold.classes.rifle.hip", [0.2, -0.27, -0.16]))
	hands.transform = Transform3D(Basis.IDENTITY, _hands_base)
	orb_hand = Node3D.new()
	orb_hand.name = "OrbHand"
	camera.add_child(orb_hand)
	orb_hand.position = _v3(Lexicon.bal("player.hold.orb_hand.fp", [-0.2, -0.3, -0.3]))
	_aim_range = Lexicon.balf("player.aim_range")
	_kill_y = Lexicon.balf("arena.kill_y")
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	head.position.y = Lexicon.balf("player.eye_height")

	max_health = Lexicon.balf("player.max_health")
	max_matter = Lexicon.balf("matter.capacity")
	health = max_health
	matter = Lexicon.balf("matter.start")
	hands.setup(self, int(Lexicon.balf("player.slots")))
	extractor = Extractor.new()
	extractor.name = "Extractor"
	extractor.player = self
	add_child(extractor)
	shaper = Shaper.new()
	shaper.name = "Shaper"
	shaper.player = self
	add_child(shaper)
	move = FpsMove.new()
	add_child(move)
	move.setup(self)

	body.visible = false
	robot = RobotBody.new()
	add_child(robot)
	robot.setup(self)
	if is_local:
		view = ViewCamera.new()
		add_child(view)
		view.setup(self)
		feel = FpsFeel.new()
		add_child(feel)
		feel.setup(self)

	var paint: = StandardMaterial3D.new()
	paint.albedo_color = body_color
	paint.roughness = 0.7
	body.material_override = paint

	if is_local:
		camera.make_current()
	else:
		camera.current = false
		_set_visual_layer(body, 1)



func place_at(spawn: Transform3D) -> void :
	if network_active and has_simulation_authority():
		_network_revision += 1
	_spawn = spawn
	global_position = spawn.origin
	if Gravity.active():

		gravity_frame = spawn.basis.orthonormalized()
		yaw = 0.0
	else:
		gravity_frame = Basis.IDENTITY
		yaw = spawn.basis.get_euler().y
	in_zero_g = false
	up_direction = gravity_frame.y
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	view_yaw = yaw
	if move != null:
		move.reset()



func reset_for_round() -> void :
	stop_piloting()
	clear_abilities()
	Status.clear(self)
	hands.clear()
	release_input()
	health = max_health
	matter = Lexicon.balf("matter.start")
	matter_credit = 0.0
	set_extracting(false)
	place_at(_spawn)
	health_changed.emit(health, max_health)
	matter_changed.emit(matter, max_matter)
	revived.emit()





func look_ray() -> Dictionary:
	var origin: = camera.global_position
	var direction: = - camera.global_basis.z
	if network_role == "authority" and not is_local and _network_free_view:
		direction = gravity_frame * Basis.from_euler(Vector3(head.rotation.x, view_yaw, 0.0)) * Vector3.FORWARD
	if view != null and view.is_third_person():
		var view_origin: = view.global_position
		var view_dir: = - view.global_basis.z
		var start: = view_origin + view_dir * maxf(0.0, (origin - view_origin).dot(view_dir))
		var query: = PhysicsRayQueryParameters3D.create(start, start + view_dir * _aim_range, PhysicsLayers.SOLID, [get_rid()])
		var hit: = get_world_3d().direct_space_state.intersect_ray(query)
		var target: Vector3 = hit["position"] if not hit.is_empty() else start + view_dir * _aim_range
		if target.distance_to(origin) > 0.05:
			direction = (target - origin).normalized()
	return {"origin": origin, "direction": direction}


func aim() -> Dictionary:
	var ray: = look_ray()
	var origin: Vector3 = ray["origin"]
	var direction: Vector3 = ray["direction"]
	var query: = PhysicsRayQueryParameters3D.create(origin, origin + direction * _aim_range, PhysicsLayers.SOLID, [get_rid()])
	var hit: = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"origin": origin, "direction": direction, "point": origin + direction * _aim_range, "collider": null, 
			"shape": -1}
	return {"origin": origin, "direction": direction, "point": hit["position"], "collider": hit["collider"], 
		"shape": int(hit.get("shape", -1))}



func look_at_point(point: Vector3) -> void :
	var d: = gravity_frame.transposed() * (point - camera.global_position)
	yaw = atan2( - d.x, - d.z)
	view_yaw = yaw
	head.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-89.0), deg_to_rad(89.0))

	_recoil_debt = 0.0


func center() -> Vector3:
	return global_position + gravity_frame.y * head.position.y * 0.6


func is_alive() -> bool:
	return health > 0.0




func apply_user_settings() -> void :
	_mouse_sensitivity = Lexicon.balf("input.mouse_sensitivity")
	if is_local:
		_mouse_sensitivity *= float(UserSettings.get_value("controls", "mouse_scale", 1.0))

		if _base_fov > 0.0:
			camera.fov *= VideoSettings.fov() / _base_fov
			_base_fov = VideoSettings.fov()


func can_act() -> bool:
	return is_alive() and not frozen and input_enabled


func has_simulation_authority() -> bool:
	return Session.has_authority() and (network_role == "authority" or (network_role == "offline" and not Session.is_online()))


func network_on_floor() -> bool:
	return _network_ground if network_role == "proxy" or (network_role == "predicted" and _network_rigid) else grounded()


func is_using_input() -> bool:
	return _network_use_held if network_role != "offline" else hands.is_using()




func release_input() -> void :
	control_wish = Vector2.ZERO
	control_sprint = false
	control_jump = false
	control_climb = 0.0
	control_crouch = false
	control_pilot_wish = Vector3.ZERO
	aiming = false
	_network_use_held = false
	if input_provider != null:
		input_provider.clear()
	if hands != null:
		hands.cancel_use()


func _setup_input_provider() -> void :
	if input_provider == null:
		input_provider = LocalPlayerInput.new() if is_local else ControlFieldsInput.new()




func read_input_frame() -> PlayerInputFrame:
	_setup_input_provider()
	var frame: = PlayerInputFrame.new()
	if not can_act():
		release_input()
		frame.yaw = wrapf(view_yaw if is_free_view() else yaw, - PI, PI)
		frame.pitch = head.rotation.x if head != null else 0.0
		frame.free_view = is_free_view()
	else:
		frame = input_provider.capture(self)
		if piloting != null and network_role == "offline":
			frame = PlayerInputFrame.new()

	control_jump = false
	control_crouch = false
	frame.tick = Engine.get_physics_frames()
	return frame


func take_damage(amount: float, _type: String, _source: Node) -> void :
	if not has_simulation_authority() or health <= 0.0:
		return
	if _blocks(_source):
		amount *= Lexicon.balf("actions.strike.block_damage_mult")
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	damaged.emit(amount, _source)
	if health <= 0.0:
		_die()



func is_blocking() -> bool:
	var item: = hands.network_item_state() if hands != null else {}
	return aiming and is_alive() and piloting == null and bool(item.get("melee", false)) and not bool(item.get("building", false))



func _blocks(source: Node) -> bool:
	if not is_blocking() or not source is Node3D or not (source as Node3D).is_inside_tree():
		return false
	var origin: = (source as Node3D).global_position
	var holder: Variant = source.get("owner_player")
	if source is Thing and (source as Thing).is_held and holder is Node3D:
		origin = (holder as Node3D).global_position
	var to: = origin - global_position
	var flat_to: = Vector2(to.x, to.z)
	var facing: = - global_basis.z
	if flat_to.length() < 0.05:
		return true
	return rad_to_deg(absf(Vector2(facing.x, facing.z).angle_to(flat_to))) <= Lexicon.balf("actions.strike.block_arc_deg") * 0.5


func apply_knockback(impulse: Vector3) -> void :
	if not has_simulation_authority():
		return
	velocity += impulse
	if network_active and impulse.length() >= Lexicon.balf("player.impact.stagger_ms"):
		_network_revision += 1
		_network_impulse_until = Engine.get_physics_frames() + 18

	if move != null and is_alive():
		move.impact(impulse)



func try_spend(amount: float) -> bool:
	if not has_simulation_authority():
		return false
	if matter + 0.0001 < amount:
		return false
	matter = maxf(0.0, matter - amount)
	matter_changed.emit(matter, max_matter)
	return true




func take_matter(amount: float) -> float:
	if not has_simulation_authority():
		return 0.0
	var from_credit: = clampf(amount, 0.0, matter_credit)
	matter_credit -= from_credit
	var taken: = clampf(amount - from_credit, 0.0, matter)
	matter -= taken
	if from_credit + taken > 0.0:
		matter_changed.emit(matter, max_matter)
	return from_credit + taken




func transmute(amount: float, cost: float) -> void :
	if not has_simulation_authority():
		return
	var use: = clampf(cost, 0.0, amount)
	matter_credit += use
	store_or_spill(amount - use)
	matter_changed.emit(matter, max_matter)



func store_or_spill(amount: float) -> float:
	if not has_simulation_authority() or amount <= 0.0:
		return 0.0
	var stored: = add_matter(amount)
	if amount - stored > 0.0001 and is_inside_tree():
		Rubble.deposit(Forge.debris_root(), Forge.ground_point(global_position, up()), amount - stored, "scrap")
	return stored



func matter_spendable() -> float:
	return matter + matter_credit




func spill_all_matter() -> void :
	if not has_simulation_authority():
		return
	var total: = matter + matter_credit + hands.dissolve_all()
	matter = 0.0
	matter_credit = 0.0
	if total > 0.0001 and is_inside_tree():
		Rubble.deposit(Forge.debris_root(), Forge.ground_point(global_position, up()), total, "scrap")
	matter_changed.emit(matter, max_matter)



func add_matter(amount: float) -> float:
	if not has_simulation_authority():
		return 0.0
	var stored: = clampf(amount, 0.0, max_matter - matter)
	if stored > 0.0:
		matter += stored
		matter_changed.emit(matter, max_matter)
	return stored


func is_full_of_matter() -> bool:
	return matter >= max_matter - 0.0001



func set_extracting(on: bool) -> void :
	if on and not has_simulation_authority() and network_role != "predicted":
		return
	if extracting == on:
		return
	extracting = on
	hands.cancel_use()

	if on and shaper != null and shaper.active:
		shaper.cancel()
	extracting_changed.emit(on)




func start_piloting(thing: Thing) -> void :
	if not has_simulation_authority():
		return
	var control: = thing.control as ControlPlayer
	if control == null:
		return
	stop_piloting()
	piloting = thing
	aiming = false
	hands.use_released()
	thing.removed.connect(_on_piloted_removed)
	control.begin(self)
	piloting_changed.emit(thing)



func stop_piloting() -> void :
	if piloting == null:
		return
	var thing: = piloting
	piloting = null
	if thing.removed.is_connected(_on_piloted_removed):
		thing.removed.disconnect(_on_piloted_removed)
	(thing.control as ControlPlayer).end()
	if is_local:
		camera.make_current()
	piloting_changed.emit(null)



func pilot_command() -> void :
	if not has_simulation_authority() or piloting == null:
		return
	var control: = piloting.control as ControlPlayer
	piloting.command(ActionContext.make(piloting.center(), control.look_direction()))


func _on_piloted_removed(_thing: Thing) -> void :
	stop_piloting()






func queue_ability(id: String, duration: float, cost: float) -> bool:
	if not has_simulation_authority():
		return false
	if not (Lexicon.bal("abilities." + id) is Dictionary):
		return false
	_pending_ability = {"id": id, "duration": duration, "cost": cost}
	_try_pending_ability()
	abilities_changed.emit()
	return true



func apply_ability(id: String, duration: float) -> bool:
	if not has_simulation_authority():
		return false
	if not (Lexicon.bal("abilities." + id) is Dictionary):
		return false
	_abilities[id] = duration
	abilities_changed.emit()
	return true


func has_ability(id: String) -> bool:
	return _abilities.has(id)



func active_abilities() -> Dictionary:
	return _abilities.duplicate()



func pending_ability() -> Dictionary:
	return _pending_ability.duplicate()


func clear_abilities() -> void :
	_abilities.clear()
	_pending_ability = {}
	abilities_changed.emit()


func _try_pending_ability() -> void :
	if _pending_ability.is_empty() or not try_spend(float(_pending_ability["cost"])):
		return
	apply_ability(String(_pending_ability["id"]), float(_pending_ability["duration"]))
	_pending_ability = {}



func _ability_mult(key: String) -> float:
	var result: = 1.0
	for id: String in _abilities:
		result *= float(Lexicon.bal("abilities.%s.%s" % [id, key], 1.0))
	return result



func is_free_view() -> bool:
	if network_role != "offline" and not is_local:
		return _network_free_view and piloting == null and not _network_piloting
	return is_local and view != null and view.distance > 0.0 and piloting == null




func simulates_free_view() -> bool:
	if network_role != "offline":
		return _network_free_view and piloting == null and not _network_piloting
	return is_free_view()




func faces_aim() -> bool:
	if network_role != "offline" and not is_local:

		return simulates_faces_aim() or extracting
	return aiming or is_using_input() or _faces_aim_locally()




func _faces_aim_locally() -> bool:
	return extracting or shaper.active or _clock < _face_aim_until




func simulates_faces_aim() -> bool:
	if network_role != "offline":
		return aiming or is_using_input() or _network_face_aim
	return faces_aim()



func _face_view_now() -> void :
	if not is_free_view():
		return
	yaw = view_yaw
	_face_aim_until = _clock + Lexicon.balf("player.camera.face_aim_after_use_s")




func is_flying() -> bool:
	return not _flight().is_empty()


func _flight() -> Dictionary:
	for id: String in _abilities:
		var data: Dictionary = Lexicon.bal("abilities." + id, {})
		if data.get("flight", false):
			return data
	return {}




func _unhandled_input(event: InputEvent) -> void :
	if not is_local or not input_enabled or frozen or not is_alive():
		return
	var motion: = event as InputEventMouseMotion
	var captured: = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if shaper.active and motion == null:
		_shaper_input(event)
		return
	if network_role != "offline" and motion == null and _queue_network_action(event):
		return
	if piloting != null:
		if motion != null and captured:
			(piloting.control as ControlPlayer).look(motion.relative, _mouse_sensitivity)
		elif event.is_action_pressed("use"):
			pilot_command()
		elif event.is_action_pressed("exit_pilot"):
			stop_piloting()
		return

	if motion != null and captured:
		_apply_mouse_look(motion)
		return
	if shaper.active:
		_shaper_input(event)
		return
	if event.is_action_pressed("use"):
		_face_view_now()
		hands.use_pressed()
	elif event.is_action_released("use"):
		hands.use_released()
	elif event.is_action_pressed("aim"):
		aiming = true
	elif event.is_action_released("aim"):
		aiming = false
	elif event.is_action_pressed("reload"):
		hands.reload()
	elif event.is_action_pressed("slot_next"):

		if view != null:
			view.zoom_by_player(1)
	elif event.is_action_pressed("slot_prev"):
		if view != null:
			view.zoom_by_player(-1)
	else:
		for i in hands.slot_count():
			if event.is_action_pressed("slot_%d" % (i + 1)):
				hands.select(i)
				return


func _apply_mouse_look(motion: InputEventMouseMotion) -> void :

	var sensitivity: = _mouse_sensitivity * camera.fov / maxf(_base_fov, 1.0)
	if is_free_view():
		view_yaw = wrapf(view_yaw - motion.relative.x * sensitivity, - PI, PI)
	else:

		yaw = wrapf(yaw - motion.relative.x * sensitivity, - PI, PI)
	if feel != null:
		feel.look_input(motion.relative)
	head.rotate_x( - motion.relative.y * sensitivity)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))



func _shaper_input(event: InputEvent) -> void :
	var button: = event as InputEventMouseButton
	if event.is_action_pressed("use"):
		_face_view_now()
		shaper.confirm()
	elif event.is_action_pressed("aim"):
		shaper.cancel()
	elif event.is_action_pressed("slot_prev"):
		shaper.adjust(1)
	elif event.is_action_pressed("slot_next"):
		shaper.adjust(-1)
	elif event.is_action_pressed("reload") or (button != null and button.pressed\
	and button.button_index == MOUSE_BUTTON_MIDDLE and not event.is_action("talk")):
		shaper.cycle_focus()



func carry_speed_mult() -> float:
	var over: = carried_weight() - Lexicon.balf("carry.free_kg")
	if over <= 0.0:
		return 1.0
	return maxf(Lexicon.balf("carry.min_speed_mult"), 1.0 - over * Lexicon.balf("carry.slow_per_kg"))



func carried_weight() -> float:
	if network_role in ["predicted", "proxy"]:
		return hands.network_carry_weight()
	var total: = 0.0
	for i in hands.slot_count():
		var item: = hands.item_at(i)
		if item != null:
			total += item.weight
	return total


func _physics_process(delta: float) -> void :
	_sync_yaw()
	if network_role != "offline":
		_network_physics(delta)
		return
	var frame: = read_input_frame()
	if piloting != null:
		hands.cancel_use()
	update_gravity(delta)
	move.step(delta, frame.movement())
	_tick_timers(delta, false)
	if out_of_world():
		release_input()
		place_at(_spawn)




func flight_data() -> Dictionary:
	return _flight()


func gravity() -> float:
	return 0.0 if in_zero_g else _gravity



func up() -> Vector3:
	return gravity_frame.y




func planar_velocity() -> Vector3:
	return velocity - gravity_frame.y * velocity.dot(gravity_frame.y)



func grounded() -> bool:
	return is_on_floor() or _air_ticks <= GROUND_GRACE_TICKS or (move != null and move.descending_step)




func _sync_yaw() -> void :
	if not Gravity.active() and gravity_frame == Basis.IDENTITY and not is_equal_approx(rotation.y, yaw):
		yaw = rotation.y



func _orient() -> void :
	basis = gravity_frame * Basis(Vector3.UP, yaw)



func update_gravity(delta: float) -> void :
	_air_ticks = 0 if is_on_floor() else mini(_air_ticks + 1, 1000)
	if not Gravity.active():
		in_zero_g = false
		floor_max_angle = deg_to_rad(45.0)
		return
	var cfg: Dictionary = Lexicon.bal("space.gravity", {})

	floor_snap_length = float(cfg.get("floor_snap_m", 0.35))

	floor_max_angle = deg_to_rad(float(cfg.get("floor_max_deg", 60.0)))
	var pull: = Gravity.direction_at(global_position + gravity_frame.y * float(cfg.get("probe_up_m", 0.9)))
	in_zero_g = pull == Vector3.ZERO
	if not in_zero_g:
		var current: = gravity_frame.y
		var want: = - pull
		var angle: = current.angle_to(want)
		if angle > 0.0001:
			var axis: = current.cross(want)
			axis = axis.normalized() if axis.length() > 0.0001 else gravity_frame.x
			var halflife: = float(cfg.get("align_halflife_s" if grounded() else "air_align_halflife_s", 0.08))


			var turn: = angle if halflife <= 0.0 or angle < 0.002 else angle * (1.0 - pow(0.5, delta / halflife))
			if halflife <= 0.0:


				turn = minf(turn, deg_to_rad(float(cfg.get("align_max_deg_s", 300.0))) * delta)



			var keep_look: = not grounded() and bool(cfg.get("air_keep_look", true))
			var look_world: = gravity_frame * (Basis(Vector3.UP, view_yaw) * Basis(Vector3.RIGHT, head.rotation.x) * Vector3.FORWARD)
			gravity_frame = (Basis(axis, turn) * gravity_frame).orthonormalized()
			if keep_look:
				_aim_world(look_world)
	up_direction = gravity_frame.y
	_orient()




func _aim_world(look_world: Vector3) -> void :
	var local: = gravity_frame.transposed() * look_world
	var new_view: = atan2( - local.x, - local.z)
	var turn: = angle_difference(view_yaw, new_view)
	view_yaw = wrapf(view_yaw + turn, - PI, PI)
	yaw = wrapf(yaw + turn, - PI, PI)
	head.rotation.x = clampf(atan2(local.y, Vector2(local.x, local.z).length()), deg_to_rad(-89.0), deg_to_rad(89.0))



func out_of_world() -> bool:
	if Gravity.active():
		return not Gravity.inside_world(global_position, Lexicon.balf("space.out_margin_m"))
	return global_position.y < _kill_y


func jump_speed() -> float:
	return _jump_velocity * _ability_mult("jump_mult")


func walk_speed() -> float:
	return _walk_speed


func sprint_speed() -> float:
	return _sprint_speed



func speed_mults() -> float:
	return _ability_mult("speed_mult") * carry_speed_mult()


func accel_ground() -> float:
	return _accel_ground


func accel_air() -> float:
	return _accel_air



func eye_height() -> float:
	return Lexicon.balf("player.eye_height")



func add_recoil(degrees: float) -> void :
	if degrees <= 0.0:
		return
	head.rotation.x = clampf(head.rotation.x + deg_to_rad(degrees), deg_to_rad(-89.0), deg_to_rad(89.0))
	_recoil_debt += deg_to_rad(degrees) * Lexicon.balf("aim.recoil_recover")



func is_scoped() -> bool:
	var zoom: = float(hands.network_item_state().get("zoom", 1.0))
	return is_local and is_aiming_down_sights() and zoom >= Lexicon.balf("aim.scope_overlay_zoom")\
	and camera.fov <= _base_fov / zoom * 1.15



func is_aiming_down_sights() -> bool:
	var item: = hands.network_item_state()
	return aiming and piloting == null and float(item.get("zoom", 1.0)) > 1.0 and not bool(item.get("building", false))



func _update_aim(delta: float) -> void :
	if _recoil_debt > 0.0:
		var back: = minf(_recoil_debt, deg_to_rad(Lexicon.balf("aim.recoil_recover_deg_s")) * delta)
		head.rotation.x -= back
		_recoil_debt -= back
	var ads: = is_aiming_down_sights()
	var weight: = 1.0 - exp( - Lexicon.balf("aim.ads_speed") * delta)
	if is_local:
		var target_fov: = _base_fov / (float(hands.network_item_state().get("zoom", 1.0)) if ads else 1.0) + (feel.fov_add if feel != null else 0.0)
		camera.fov = lerpf(camera.fov, target_fov, weight)
	_place_weapon(ads, weight, delta)






func _place_weapon(ads: bool, weight: float, delta: float) -> void :
	var hold: Dictionary = Lexicon.bal("player.hold", {})
	var held: = hands.current_item()
	var held_state: = hands.network_item_state()
	var classes: Dictionary = hold.get("classes", {})
	var pose: Dictionary = classes.get(String(held_state.get("hold_class", "none")), classes.get("rifle", {}))
	var spot: = _v3(pose.get("ads" if ads else "hip", [0.2, -0.27, -0.16]))
	if ads and held != null:

		var grip: Variant = held.grip_local("main")
		var sight: = held.model.transform * Vector3(0.0, held.sight_y, 0.0) if held.model != null else Vector3.ZERO
		spot.y -= sight.y - (Vector3(grip).y if grip != null else 0.0) + float(hold.get("ads_over_sight_m", 0.03))
	elif ads and not held_state.is_empty():
		var grip: Vector3 = held_state.get("grip_main", Vector3.ZERO)
		var sight: Vector3 = held_state.get("sight", Vector3.ZERO)
		spot.y -= sight.y - grip.y + float(hold.get("ads_over_sight_m", 0.03))
	_hands_base = _hands_base.lerp(spot, weight)
	var carry: = is_free_view() and not faces_aim() and not move.sliding
	_carry_w = RobotSpring.damp(_carry_w, 1.0 if carry else 0.0, float(hold.get("carry_halflife_s", 0.1)), delta)
	var base: = _hands_base.lerp(_v3(pose.get("carry", [0.24, -0.3, -0.1])), _carry_w)

	var carry_rot: = Basis(Vector3.UP, deg_to_rad(float(pose.get("carry_yaw_deg", 15.0))) * _carry_w) * Basis(Vector3.RIGHT, (deg_to_rad(float(pose.get("carry_pitch_deg", -20.0))) - head.rotation.x) * _carry_w)
	hands.position = base + (feel.hand_pos if feel != null else Vector3.ZERO)
	hands.basis = carry_rot * (Basis.from_euler(feel.hand_rot) if feel != null else Basis.IDENTITY)

	var orb_pose: Dictionary = hold.get("orb_hand", {})
	var orb_at: = _v3(orb_pose.get("fp", [-0.2, -0.3, -0.3])).lerp(_v3(orb_pose.get("carry", [-0.26, -0.34, -0.18])), _carry_w)
	var bob: = feel.hand_pos if feel != null else Vector3.ZERO
	orb_hand.position = orb_at + Vector3( - bob.x, bob.y, bob.z)
	orb_hand.basis = Basis(Vector3.RIGHT, - head.rotation.x * _carry_w)

	hands.visible = not extracting
	if is_local:
		var own: = 1 << (Hands.OWN_WEAPON_LAYER - 1)
		camera.cull_mask = (camera.cull_mask & ~ own) if is_scoped() else (camera.cull_mask | own)


static func _v3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _process(delta: float) -> void :
	_clock += delta
	_update_aim(delta)
	if not has_simulation_authority():
		return
	if Session.is_online() and ( not network_active or (Forge.world != null and not Forge.world.gameplay_available())):
		return
	if not _pending_ability.is_empty():
		_try_pending_ability()
		abilities_changed.emit()




func _tick_timers(delta: float, replaying: bool) -> void :
	Status.tick_for(self, delta)
	if _abilities.is_empty():
		return
	for id: String in _abilities.keys():
		_abilities[id] = float(_abilities[id]) - delta
		if float(_abilities[id]) <= 0.0:
			_abilities.erase(id)
	if not replaying:
		abilities_changed.emit()




func eliminate() -> void :
	if not has_simulation_authority() or health <= 0.0:
		return
	health = 0.0
	health_changed.emit(health, max_health)
	_die()


func _die() -> void :
	print("[Player] %s (p%d) morreu" % [display_name, player_id])
	stop_piloting()
	clear_abilities()
	release_input()
	spill_all_matter()
	died.emit(self)
	if respawn_on_death:
		health = max_health
		place_at(_spawn)
		health_changed.emit(health, max_health)
		revived.emit()


static func _set_visual_layer(node: Node, layer: int) -> void :
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << (layer - 1)
	for child in node.get_children():
		_set_visual_layer(child, layer)




func configure_network(role: String) -> void :
	assert (role in ["offline", "authority", "predicted", "proxy"])
	network_role = role
	input_provider = NetworkInputProvider.new() if role == "authority" and not is_local else\
	(LocalPlayerInput.new() if is_local else ControlFieldsInput.new())
	if input_provider is NetworkInputProvider and Session.replication != null:
		(input_provider as NetworkInputProvider).counters = Session.replication.stats
	set_network_active(false, network_epoch)


func set_network_active(active: bool, epoch: int = 0) -> void :
	if epoch != network_epoch or not active:
		release_input()
		_prediction_history.clear()
		_network_seq = 0
		_network_event_seq = 0
		_network_ack_input = 0
		_network_ack_event = 0
		_predicted_extract_event = 0
		_network_last_snapshot = -1
		_network_received_revision = -1
		_network_target.clear()
		_network_rigid = false
		if input_provider is NetworkInputProvider:
			(input_provider as NetworkInputProvider).reset()
	network_epoch = epoch
	network_active = active


func submit_network_input(frame: PlayerInputFrame) -> bool:
	if not network_active or network_role != "authority" or not input_provider is NetworkInputProvider:
		return false
	return (input_provider as NetworkInputProvider).submit(frame)


func submit_network_event(event_seq: int, frame: PlayerInputFrame) -> bool:
	if not network_active or network_role != "authority" or not input_provider is NetworkInputProvider:
		return false
	return (input_provider as NetworkInputProvider).submit_event(event_seq, frame)


func _queue_network_action(event: InputEvent) -> bool:
	var provider: = input_provider as LocalPlayerInput
	if provider == null:
		return false
	if event.is_action_pressed("use") or event.is_action_released("use"):
		provider.queue_action("use", event.is_action_pressed("use"))
		return true
	if event.is_action("aim"):
		return true
	for action in ["reload", "exit_pilot"]:
		if event.is_action_pressed(action):
			provider.queue_action(action)
			return true
	for i in 3:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			provider.queue_action("slot", true, i)
			return true
	return false


func _stamp_network_frame(frame: PlayerInputFrame) -> void :
	_network_seq += 1
	frame.seq = _network_seq
	frame.tick = Engine.get_physics_frames()
	frame.wish = frame.wish.limit_length(1.0)
	frame.face_aim = _faces_aim_locally()
	if frame.has_events():
		_network_event_seq += 1
		frame.event_seq = _network_event_seq


func _network_physics(delta: float) -> void :
	if not network_active:
		return
	if network_role == "proxy":
		_interpolate_authority(delta)
		return
	if input_provider is NetworkInputProvider:
		_simulate_remote_frames(delta)
		return
	var frame: = read_input_frame()
	if is_local:
		_stamp_network_frame(frame)
		input_generated.emit(frame)
	if network_role == "predicted":
		_prediction_history.append(frame.copy())
		if _prediction_history.size() > MAX_PREDICTION_FRAMES:
			_prediction_history.pop_front()
		if _network_rigid:
			_interpolate_authority(delta)
			return
	_apply_network_frame(frame, delta, false)
	if has_simulation_authority() and out_of_world():
		release_input()
		place_at(_spawn)





func _simulate_remote_frames(delta: float) -> void :
	for frame in (input_provider as NetworkInputProvider).take_steps(self):
		var input: = frame
		if not can_act():
			release_input()
			input = frame.neutralized()
		_apply_network_frame(input, delta, false)
		if out_of_world():
			release_input()
			place_at(_spawn)


func _apply_network_frame(frame: PlayerInputFrame, delta: float, replaying: bool) -> void :
	_network_free_view = frame.free_view
	view_yaw = frame.yaw
	if not frame.free_view:
		yaw = frame.yaw
	head.rotation.x = frame.pitch
	aiming = frame.aiming and can_act()
	_network_use_held = frame.use_held and can_act()
	_network_face_aim = frame.face_aim and can_act()
	if not replaying:
		if frame.toggle_extract and (has_simulation_authority() or network_role == "predicted") and can_act() and piloting == null:
			set_extracting( not extracting)
			if network_role == "predicted": _predicted_extract_event = frame.event_seq
		if piloting != null and has_simulation_authority():
			(piloting.control as ControlPlayer).apply_input(frame)
			if frame.use_pressed:
				pilot_command()
		else:
			hands.apply_network_commands(frame, has_simulation_authority())
		if frame.exit_pilot and has_simulation_authority():
			stop_piloting()
	var movement: = frame.movement()
	if piloting != null or _network_piloting:
		movement = PlayerInputFrame.new().movement()
	update_gravity(delta)
	move.step(delta, movement, replaying)
	_tick_timers(delta, replaying)
	_network_ground = is_on_floor()


func export_network_state() -> Dictionary:
	var ack: = _network_seq
	var event_ack: = _network_event_seq
	if input_provider is NetworkInputProvider:
		ack = (input_provider as NetworkInputProvider).ack_input
		event_ack = (input_provider as NetworkInputProvider).ack_event
	return {"seq": ack, "ack_input": ack, "ack_event": event_ack, "tick": Engine.get_physics_frames(), 
		"position": global_position, "velocity": velocity, "yaw": yaw, "pitch": head.rotation.x, 
		"frame": Quaternion(gravity_frame), "zero_g": in_zero_g, 
		"view_yaw": view_yaw, "free_view": is_free_view(), "move": move.export_network_state(), 
		"aiming": aiming, "use_held": is_using_input(), "health": health, "matter": matter, 
		"matter_credit": matter_credit, "abilities": _abilities.duplicate(), "pending_ability": _pending_ability.duplicate(), "frozen": frozen, 
		"rigid": piloting != null or Engine.get_physics_frames() < _network_impulse_until, 
		"piloting": piloting != null, "pilot_ref": Session.creations.thing_reference(piloting), 
		"status": Status.snapshot(self), "revision": _network_revision, 
		"extraction": extractor.network_state(), "extracting": extracting, 
		"equipment": hands.export_network_state(), "robot": robot.export_network_state()}


func receive_authoritative_state(snapshot: Dictionary, baseline: bool = false) -> void :
	if network_role not in ["predicted", "proxy"] or not _valid_motion_snapshot(snapshot):
		return
	var order: = int(snapshot.get("snapshot_seq", snapshot.get("tick", 0)))
	if not baseline and order <= _network_last_snapshot:
		return
	_network_last_snapshot = order
	_network_ack_input = int(snapshot.get("ack_input", snapshot.get("seq", 0)))
	_network_ack_event = int(snapshot.get("ack_event", 0))
	var revision: = int(snapshot.get("revision", 0))
	var reset: = baseline or revision != _network_received_revision
	_network_received_revision = revision
	_network_rigid = bool(snapshot.get("rigid", false))
	_network_piloting = bool(snapshot.get("piloting", false))
	_network_target = snapshot.duplicate(true)
	if reset or _network_rigid:
		_prediction_history.clear()
	else:
		var pending: Array[PlayerInputFrame] = []
		for old in _prediction_history:
			if old.seq > _network_ack_input or (old.has_events() and old.event_seq > _network_ack_event):
				pending.append(old)
		_prediction_history = pending
	var abilities_before: = _abilities.keys()
	_apply_replicated_values(snapshot)
	if network_role == "proxy" or _network_rigid:
		if baseline or reset:
			_restore_motion(snapshot)
		else:
			move.apply_network_state(snapshot["move"])
		if _abilities.keys() != abilities_before:
			abilities_changed.emit()
		return
	var before: = global_position
	var local_yaw: = yaw
	var local_view_yaw: = view_yaw
	var local_pitch: = head.rotation.x
	_restore_motion(snapshot)
	_restore_floor_contact(bool((snapshot["move"] as Dictionary).get("on_floor", false)))
	var dt: = 1.0 / float(Engine.physics_ticks_per_second)
	var visual_input: = PlayerInputFrame.new()
	var pending_events: Array[PlayerInputFrame] = []
	for pending in _prediction_history:
		if pending.has_events() and pending.event_seq > _network_ack_event:
			pending_events.append(pending)
			if pending.slot >= 0:
				visual_input.slot = pending.slot
	for pending in _prediction_history:


		if pending.seq <= _network_ack_input:
			continue
		var replay: = pending.without_events()


		if not pending_events.is_empty() and pending_events[0].seq <= replay.seq:
			replay.merge_events(pending_events.pop_front())
		_apply_network_frame(replay, dt, true)

	if _abilities.keys() != abilities_before:
		abilities_changed.emit()


	visual_input.use_held = _network_use_held
	hands.apply_network_commands(visual_input, false)
	last_correction_distance = before.distance_to(global_position)
	if not baseline and last_correction_distance > 0.02:
		network_corrections += 1

	if is_local and not baseline:
		if not is_free_view():
			yaw = local_yaw
		view_yaw = local_view_yaw
		head.rotation.x = local_pitch


func _apply_replicated_values(snapshot: Dictionary) -> void :
	var old_health: = health
	var old_matter: = matter
	health = float(snapshot.get("health", health))
	matter = float(snapshot.get("matter", matter))
	matter_credit = float(snapshot.get("matter_credit", matter_credit))
	_abilities = (snapshot.get("abilities", {}) as Dictionary).duplicate()
	_pending_ability = (snapshot.get("pending_ability", {}) as Dictionary).duplicate()

	frozen = bool(snapshot.get("frozen", frozen)) or (Session.is_online() and Forge.world != null and not Forge.world.gameplay_available())
	if not is_local:
		aiming = bool(snapshot.get("aiming", false))
	if not is_local or network_role != "predicted":
		_network_use_held = bool(snapshot.get("use_held", false))
	_network_free_view = bool(snapshot.get("free_view", false))
	_network_ground = bool((snapshot["move"] as Dictionary).get("on_floor", false))
	_apply_pilot_replica(snapshot.get("pilot_ref", {}))
	Status.apply_snapshot(self, snapshot.get("status", {}))
	var was_extracting: = extracting
	if network_role != "predicted" or _network_ack_event >= _predicted_extract_event or frozen or not is_alive():
		extracting = bool(snapshot.get("extracting", false))
	if was_extracting != extracting: extracting_changed.emit(extracting)
	extractor.apply_network_state(snapshot.get("extraction", {}))
	hands.apply_network_state(snapshot.get("equipment", {}))
	robot.apply_network_state(snapshot.get("robot", {}))
	if not is_equal_approx(old_health, health):
		health_changed.emit(health, max_health)
		if old_health > 0.0 and health <= 0.0:
			died.emit(self)
		elif old_health <= 0.0 and health > 0.0:
			revived.emit()
	if not is_equal_approx(old_matter, matter):
		matter_changed.emit(matter, max_matter)
	abilities_changed.emit()


func _apply_pilot_replica(reference: Dictionary) -> void :
	var target: = Session.creations.resolve_reference(reference)
	if target == piloting:
		return
	stop_piloting()
	if target != null and target.control is ControlPlayer:
		piloting = target
		target.removed.connect(_on_piloted_removed)
		(target.control as ControlPlayer).begin(self)
		target.control.process_mode = Node.PROCESS_MODE_INHERIT
		piloting_changed.emit(target)


func _restore_motion(snapshot: Dictionary) -> void :
	global_position = snapshot["position"]
	velocity = snapshot["velocity"]
	_restore_frame(snapshot)
	yaw = float(snapshot.get("yaw", 0.0))
	head.rotation.x = float(snapshot.get("pitch", 0.0))
	view_yaw = float(snapshot.get("view_yaw", yaw))
	_network_free_view = bool(snapshot.get("free_view", false))
	move.apply_network_state(snapshot["move"])






func _restore_floor_contact(on_floor: bool) -> void :
	if on_floor == is_on_floor():
		return
	if on_floor:

		var exact: = global_position
		apply_floor_snap()
		global_position = exact
		return


	var exact: = global_position
	var keep_velocity: = velocity
	var keep_snap: = floor_snap_length
	velocity = Vector3.ZERO
	floor_snap_length = 0.0
	move_and_slide()
	floor_snap_length = keep_snap
	velocity = keep_velocity
	global_position = exact


func _interpolate_authority(delta: float) -> void :
	if _network_target.is_empty():
		return
	var weight: = 1.0 - exp( - NETWORK_INTERPOLATION_SPEED * delta)
	global_position = global_position.lerp(_network_target["position"], weight)
	velocity = _network_target["velocity"]
	if _network_target.get("frame") is Quaternion:
		gravity_frame = Basis(Quaternion(gravity_frame).slerp((_network_target["frame"] as Quaternion).normalized(), weight)).orthonormalized()
		up_direction = gravity_frame.y
		_orient()
	if not is_local or _network_rigid:
		yaw = lerp_angle(yaw, float(_network_target["yaw"]), weight)
		head.rotation.x = lerp_angle(head.rotation.x, float(_network_target["pitch"]), weight)
		view_yaw = lerp_angle(view_yaw, float(_network_target["view_yaw"]), weight)



func _restore_frame(snapshot: Dictionary) -> void :
	var quat: Variant = snapshot.get("frame")
	if quat is Quaternion and (quat as Quaternion).is_finite() and (quat as Quaternion).length() > 0.5:
		gravity_frame = Basis((quat as Quaternion).normalized()).orthonormalized()
	in_zero_g = bool(snapshot.get("zero_g", false))
	up_direction = gravity_frame.y


static func _valid_motion_snapshot(snapshot: Dictionary) -> bool:
	return snapshot.get("position") is Vector3 and (snapshot.position as Vector3).is_finite()\
	and snapshot.get("velocity") is Vector3 and (snapshot.velocity as Vector3).is_finite()\
	and snapshot.get("move") is Dictionary
