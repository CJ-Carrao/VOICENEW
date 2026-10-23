class_name FpsFeel
extends Node














var player: Player

var fov_add: float = 0.0
var hand_pos: = Vector3.ZERO
var hand_rot: = Vector3.ZERO

var trauma: float = 0.0

var _cfg: Dictionary
var _clock: float = 0.0
var _bob_k: float = 0.0
var _sway_target: = Vector2.ZERO
var _sway: = Vector2.ZERO
var _tilt: float = 0.0
var _sprint_w: float = 0.0
var _slide_w: float = 0.0
var _dip: = Vector2.ZERO

var _hand_dip: = Vector2.ZERO
var _fov: float = 0.0
var _mantle_w: float = 0.0
var _noise: = FastNoiseLite.new()


func setup(owner_player: Player) -> void :
	player = owner_player
	name = "Feel"
	_cfg = Lexicon.bal("feel", {})
	_noise.seed = 1009
	_noise.frequency = 1.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	player.move.landed.connect(_on_landed)
	player.move.jumped.connect(_on_jumped)
	player.move.mantle_started.connect( func(_h: float, _d: float) -> void : _mantle_w = 1.0)
	player.damaged.connect( func(amount: float, _source: Node) -> void :
		add_trauma(amount * _sf("shake", "hurt_trauma_per_damage")))
	player.hands.used.connect(_on_used)
	Forge.explosion_at.connect(_on_exploded)



func look_input(relative: Vector2) -> void :
	var limit: = _sf("sway", "max_deg")
	_sway_target = (_sway_target + relative * _sf("sway", "deg_per_px")).limit_length(limit)


func add_trauma(amount: float) -> void :
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void :
	_clock += delta
	var move: = player.move
	var on_floor: = player.network_on_floor()
	var ads: = 1.0 if player.aiming and not player.hands.network_item_state().is_empty() else 0.0
	var flat: = player.planar_velocity()
	var local_v: = player.global_basis.inverse() * flat
	var speed: = flat.length()


	var bob: Dictionary = _cfg.get("bob", {})
	var walking: = player.robot.animator.move_weight * (1.0 if on_floor and not move.sliding else 0.0)
	var k: = walking * clampf(speed / float(bob.get("speed_ref_ms", 6.0)), 0.0, 1.8)
	if move.sprinting:
		k *= float(bob.get("sprint_mult", 1.4))
	if move.crouching:
		k *= float(bob.get("crouch_mult", 0.6))
	k *= lerpf(1.0, float(bob.get("ads_mult", 0.15)), ads)
	_bob_k = RobotSpring.damp(_bob_k, k, float(bob.get("halflife_s", 0.1)), delta)
	var phase: = player.robot.animator.phase * TAU
	var cam_pos: = Vector3(sin(phase) * float(bob.get("lateral_m", 0.012)), 
		- (0.5 + 0.5 * cos(2.0 * phase)) * float(bob.get("vertical_m", 0.022)), 0.0) * _bob_k
	var cam_rot: = Vector3(0.0, 0.0, sin(phase) * deg_to_rad(float(bob.get("roll_deg", 0.35))) * _bob_k)


	var wb: Dictionary = _cfg.get("weapon_bob", {})
	var wk: = _bob_k * (float(wb.get("sprint_mult", 1.6)) if move.sprinting else 1.0)
	var pos: = Vector3(sin(phase) * float(wb.get("lateral_m", 0.01)), 
		- absf(cos(phase)) * float(wb.get("vertical_m", 0.008)), 0.0) * wk
	var rot: = Vector3(0.0, sin(phase) * deg_to_rad(float(wb.get("yaw_deg", 1.2))) * wk, 0.0)
	var idle: = (1.0 - walking) * lerpf(1.0, 0.3, ads)
	pos.y += sin(_clock * TAU * float(wb.get("idle_hz", 0.3))) * float(wb.get("idle_m", 0.002)) * idle

	var sway: Dictionary = _cfg.get("sway", {})
	_sway_target = _sway_target.lerp(Vector2.ZERO, 1.0 - exp( - RobotSpring.LN2 * delta / maxf(float(sway.get("return_halflife_s", 0.08)), 0.001)))
	_sway = _sway.lerp(_sway_target, 1.0 - exp( - RobotSpring.LN2 * delta / maxf(float(sway.get("halflife_s", 0.05)), 0.001)))
	var sway_k: = lerpf(1.0, float(sway.get("ads_mult", 0.25)), ads)
	rot += Vector3(deg_to_rad(_sway.y), deg_to_rad(_sway.x), deg_to_rad(_sway.x * 0.6)) * sway_k
	pos += Vector3( - _sway.x, _sway.y, 0.0) * float(sway.get("pos_m_per_deg", 0.003)) * sway_k

	var tilt: Dictionary = _cfg.get("strafe_tilt", {})
	_tilt = RobotSpring.damp(_tilt, clampf(local_v.x / maxf(player.walk_speed(), 0.1), -1.5, 1.5), float(tilt.get("halflife_s", 0.1)), delta)
	cam_rot.z -= deg_to_rad(float(tilt.get("camera_deg", 1.2))) * _tilt * lerpf(1.0, 0.4, ads)
	rot.z -= deg_to_rad(float(tilt.get("weapon_deg", 4.0))) * _tilt * lerpf(1.0, 0.3, ads)

	var sprint_pose: Dictionary = _cfg.get("sprint_pose", {})
	_sprint_w = RobotSpring.damp(_sprint_w, 1.0 if move.sprinting else 0.0, float(sprint_pose.get("halflife_s", 0.07)), delta)
	rot += _deg3(sprint_pose.get("rot_deg", [-18, 35, 20])) * _sprint_w
	pos += _v3(sprint_pose.get("pos_m", [0.04, -0.06, 0.03])) * _sprint_w


	var slide: Dictionary = _cfg.get("slide", {})
	_slide_w = RobotSpring.damp(_slide_w, 1.0 if move.sliding else 0.0, float(slide.get("halflife_s", 0.08)), delta)
	cam_rot.z += deg_to_rad(float(slide.get("roll_deg", 5.0))) * _slide_w
	rot += _deg3(slide.get("weapon_rot_deg", [4, 8, 14])) * _slide_w


	var land: Dictionary = _cfg.get("land", {})
	_dip = RobotSpring.bouncy(_dip, 0.0, float(land.get("frequency_hz", 3.5)), float(land.get("damping", 0.55)), delta)
	_hand_dip = RobotSpring.bouncy(_hand_dip, 0.0, float(land.get("weapon_frequency_hz", 4.5)), float(land.get("damping", 0.55)), delta)
	cam_pos.y += _dip.x
	pos.y += _hand_dip.x
	rot.x += _hand_dip.x * deg_to_rad(float(land.get("weapon_pitch_deg_per_m", 60.0)))


	_mantle_w = move_toward(_mantle_w, 0.0, delta / maxf(_sf("mantle", "s"), 0.01))
	var m: = sin(_mantle_w * PI)
	cam_pos.y -= m * _sf("mantle", "dip_m")
	cam_rot.x -= m * deg_to_rad(_sf("mantle", "pitch_deg"))
	cam_rot.z += m * deg_to_rad(_sf("mantle", "roll_deg"))


	var fov: Dictionary = _cfg.get("fov", {})
	var want: = 0.0
	if move.sprinting:
		want = float(fov.get("sprint_deg", 6.0))
	if move.sliding:
		want = float(fov.get("slide_deg", 10.0))
	_fov = RobotSpring.damp(_fov, want * (1.0 - ads), float(fov.get("halflife_s", 0.12)), delta)
	fov_add = _fov


	var shake: Dictionary = _cfg.get("shake", {})
	trauma = maxf(0.0, trauma - float(shake.get("decay_per_s", 1.4)) * delta)
	var amount: = trauma * trauma
	if amount > 0.0001:
		var t: = _clock * float(shake.get("frequency_hz", 18.0))
		var max_deg: = _deg3(shake.get("max_deg", [2.5, 2.5, 4.0]))
		cam_rot += Vector3(max_deg.x * _noise.get_noise_2d(t, 11.0), max_deg.y * _noise.get_noise_2d(t, 37.0), 
			max_deg.z * _noise.get_noise_2d(t, 71.0)) * amount
		cam_pos += Vector3(_noise.get_noise_2d(t, 101.0), _noise.get_noise_2d(t, 131.0), 0.0) * float(shake.get("max_m", 0.04)) * amount

	player.camera.transform = Transform3D(Basis.from_euler(cam_rot), player.eye_offset + cam_pos)
	hand_pos = pos
	hand_rot = rot


func _on_landed(fall_speed: float) -> void :
	var land: Dictionary = _cfg.get("land", {})
	var depth: = minf(fall_speed * float(land.get("camera_m_per_ms", 0.012)), float(land.get("max_m", 0.12)))
	if depth < 0.004:
		return
	_dip.y -= RobotSpring.bouncy_kick(depth, float(land.get("frequency_hz", 3.5)), float(land.get("damping", 0.55)))
	_hand_dip.y -= RobotSpring.bouncy_kick(depth * float(land.get("weapon_mult", 1.4)), float(land.get("weapon_frequency_hz", 4.5)), 
		float(land.get("damping", 0.55)))
	add_trauma(maxf(0.0, fall_speed - float(land.get("trauma_from_ms", 9.0))) * float(land.get("trauma_per_ms", 0.04)))


func _on_jumped() -> void :
	var land: Dictionary = _cfg.get("land", {})
	_hand_dip.y -= RobotSpring.bouncy_kick(float(land.get("jump_weapon_m", 0.02)), float(land.get("weapon_frequency_hz", 4.5)), 
		float(land.get("damping", 0.55)))


func _on_used(item: Thing, kind: String) -> void :
	if kind == "fire" and item != null:
		add_trauma(item.recoil_deg * _sf("shake", "fire_trauma_per_recoil_deg"))



func _on_exploded(at: Vector3, radius: float, damage: float) -> void :
	var shake: Dictionary = _cfg.get("shake", {})
	var reach: = radius * float(shake.get("explosion_reach_mult", 3.0))
	var distance: = player.center().distance_to(at)
	if distance >= reach:
		return
	var near: = 1.0 - distance / reach
	add_trauma(float(shake.get("explosion_trauma", 1.0)) * clampf(damage / float(shake.get("explosion_ref_damage", 50.0)), 0.2, 1.5) * near)


func _sf(section: String, key: String) -> float:
	return float((_cfg.get(section, {}) as Dictionary).get(key, 0.0))


static func _v3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func _deg3(values: Array) -> Vector3:
	return Vector3(deg_to_rad(float(values[0])), deg_to_rad(float(values[1])), deg_to_rad(float(values[2])))
