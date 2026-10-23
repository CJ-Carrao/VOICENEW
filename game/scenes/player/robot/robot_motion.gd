class_name RobotMotion
extends RefCounted














var rig: RobotRig
var _lean_cfg: Dictionary
var _land_cfg: Dictionary
var _torso_cfg: Dictionary
var _accel: = Vector3.ZERO
var _last_velocity: = Vector3.ZERO
var _lean_x: = Vector2.ZERO
var _lean_z: = Vector2.ZERO
var _land: = Vector2.ZERO
var _exertion: float = 0.0
var _breath_phase: float = 0.0
var _head: = Quaternion.IDENTITY
var _head_ready: bool = false
var _dangle_cfg: Dictionary
var _dangle_clock: float = 0.0

var _dangle: = {}

var _fly_lean: = Vector2.ZERO


func _init(robot_rig: RobotRig) -> void :
	rig = robot_rig
	_lean_cfg = Lexicon.bal("robot.lean", {})
	_land_cfg = Lexicon.bal("robot.land", {})
	_torso_cfg = Lexicon.bal("robot.torso", {})
	_dangle_cfg = Lexicon.bal("robot.dangle", {})
	_reset_dangle()


func reset() -> void :
	_accel = Vector3.ZERO
	_lean_x = Vector2.ZERO
	_lean_z = Vector2.ZERO
	_land = Vector2.ZERO
	_exertion = 0.0
	_head_ready = false
	_reset_dangle()





func update(dt: float, world_velocity: Vector3, to_model: Basis, effort: float, on_floor: bool) -> void :
	if dt <= 0.0:
		return

	var flat: = world_velocity
	var raw: = to_model * ((flat - _last_velocity) / dt) if on_floor else Vector3.ZERO
	_last_velocity = flat
	_accel = RobotSpring.damp_v3(_accel, raw, _lf("accel_halflife_s"), dt)
	var target: = Vector2(_accel.x, _accel.z) * _lf("accel_deg_per_ms2")
	target = target.limit_length(_lf("max_deg"))
	_lean_x = RobotSpring.bouncy(_lean_x, target.x, _lf("frequency_hz"), _lf("damping"), dt)
	_lean_z = RobotSpring.bouncy(_lean_z, target.y, _lf("frequency_hz"), _lf("damping"), dt)
	_land = RobotSpring.bouncy(_land, 0.0, float(_land_cfg.get("frequency_hz", 4.0)), float(_land_cfg.get("damping", 0.6)), dt)
	var halflife: = float(_torso_cfg.get("exertion_rise_s" if effort > _exertion else "exertion_fall_s", 2.0))
	_exertion = RobotSpring.damp(_exertion, clampf(effort, 0.0, 1.0), halflife, dt)
	var breath: Dictionary = _torso_cfg.get("breath", {})
	_breath_phase = fposmod(_breath_phase + TAU * lerpf(float(breath.get("calm_hz", 0.25)), float(breath.get("exerted_hz", 0.6)), _exertion) * dt, TAU)



func land(fall_speed: float, moving: float) -> void :
	var depth: = minf(fall_speed * float(_land_cfg.get("compress_m_per_ms", 0.02)), float(_land_cfg.get("max_m", 0.18)))
	depth *= lerpf(float(_land_cfg.get("standing_mult", 0.4)), 1.0, clampf(moving, 0.0, 1.0))
	_land.y -= RobotSpring.bouncy_kick(depth, float(_land_cfg.get("frequency_hz", 4.0)), float(_land_cfg.get("damping", 0.6)))



func apply_head(pose: RobotRig.Pose, weight: float, dt: float) -> void :
	var head: = rig.bone("head")
	var g: = rig.globals(pose)
	var now: = g[head].basis.get_rotation_quaternion()
	_head = RobotSpring.damp_quat(_head, now, float(_torso_cfg.get("head_lowpass_halflife_s", 0.15)), dt) if _head_ready else now
	_head_ready = true
	var k: = clampf(float(_torso_cfg.get("head_stabilize", 0.5)) * weight, 0.0, 1.0)
	if k <= 0.0:
		return
	var parent_rot: = g[rig.parent[head]].basis.get_rotation_quaternion()
	pose.rot[head] = parent_rot.inverse() * now.slerp(_head, k)



func lean_deg() -> Vector2:
	return Vector2(_lean_x.x, _lean_z.x)



func exertion() -> float:
	return _exertion




func apply_body(pose: RobotRig.Pose, animator: RobotAnimator, procedural_lean: bool = true, procedural_breath: bool = true) -> void :
	var lean: = lean_deg()
	if procedural_lean and lean.length() > 0.01:
		var dir: = Vector3(lean.x, 0.0, lean.y).normalized()
		animator.turn_bones(pose, _lean_cfg.get("split", {}), Vector3.UP.cross(dir).normalized(), deg_to_rad(lean.length()))
	if procedural_breath:
		var breath: Dictionary = _torso_cfg.get("breath", {})
		var amp: = lerpf(float(breath.get("calm_deg", 0.4)), float(breath.get("exerted_deg", 2.5)), _exertion)
		animator.turn_bones(pose, {"chest": 1.0, "neck": -0.6}, Vector3.LEFT, sin(_breath_phase) * deg_to_rad(amp))
	var drop: = land_drop()
	if absf(drop) > 0.0005:
		animator.turn_bones(pose, {"spine": 0.5, "chest": 0.5}, Vector3.LEFT, deg_to_rad(float(_land_cfg.get("chest_deg_per_m", 60.0)) * drop))




func update_dangle(dt: float, velocity: Vector3, weight: float) -> void :
	if weight <= 0.0:
		_reset_dangle()
		return
	var c: = _dangle_cfg
	_dangle_clock += dt
	var lean_goal: = (Vector2(velocity.x, velocity.z) * float(c.get("fly_lean_deg_per_ms", 1.5))).limit_length(float(c.get("fly_lean_max_deg", 16.0)))
	_fly_lean = _fly_lean.lerp(lean_goal, 1.0 - exp( - RobotSpring.LN2 * dt / maxf(float(c.get("fly_lean_halflife_s", 0.25)), 0.001)))
	var freqs: Array = c.get("frequency_hz", [1.9, 2.3])
	var flat: = Vector2(velocity.x, velocity.z).length()
	var top: = float(c.get("max_deg", 55.0))
	for i in 2:
		var side: = "L" if i == 0 else "R"
		var legs: Dictionary = _dangle[side]
		var freq: = float(freqs[i])
		var damping: = float(c.get("damping", 0.28))
		var sway: = sin(_dangle_clock * TAU * float(c.get("idle_hz", 0.45)) + i * 2.1) * float(c.get("idle_deg", 6.0))

		var pitch: = clampf( - velocity.z * float(c.get("drag_deg_per_ms", 5.0)) + sway, - top, top)
		var roll: = clampf(velocity.x * float(c.get("side_deg_per_ms", 4.0)) + sway * 0.4, - top, top)
		legs["pitch"] = RobotSpring.bouncy(legs["pitch"], pitch, freq, damping, dt)
		legs["roll"] = RobotSpring.bouncy(legs["roll"], roll, freq * 1.1, damping, dt)


		var knee: = float(c.get("knee_base_deg", 12.0)) + flat * float(c.get("knee_per_ms", 2.5)) + maxf(0.0, - velocity.y) * float(c.get("fall_knee_deg_per_ms", 4.0)) - maxf(0.0, velocity.y) * float(c.get("climb_knee_deg_per_ms", 3.0)) + (legs["pitch"] as Vector2).y * float(c.get("whip_s", 0.06))
		legs["knee"] = RobotSpring.bouncy(legs["knee"], clampf(knee, 0.0, float(c.get("knee_max_deg", 70.0))), freq * 1.3, damping, dt)

		var foot: = float(c.get("foot_hang_deg", 45.0)) + flat * float(c.get("foot_drag_deg_per_ms", 2.0)) + (legs["knee"] as Vector2).y * float(c.get("foot_whip_s", 0.05)) + sway * 0.5
		legs["foot"] = RobotSpring.bouncy(legs["foot"], clampf(foot, -10.0, float(c.get("foot_max_deg", 75.0))), freq * 1.8, 
			float(c.get("foot_damping", 0.22)), dt)
		var toe: = float(c.get("toe_hang_deg", 20.0)) + (legs["foot"] as Vector2).y * float(c.get("toe_whip_s", 0.03))
		legs["toe"] = RobotSpring.bouncy(legs["toe"], clampf(toe, -5.0, float(c.get("toe_max_deg", 40.0))), freq * 2.4, 
			float(c.get("foot_damping", 0.22)), dt)



func apply_dangle(pose: RobotRig.Pose, animator: RobotAnimator, weight: float) -> void :
	if weight <= 0.0:
		return
	if _fly_lean.length() > 0.05:
		var dir: = Vector3(_fly_lean.x, 0.0, _fly_lean.y).normalized()
		animator.turn_bones(pose, {"pelvis": 0.5, "spine": 0.25, "chest": 0.25}, Vector3.UP.cross(dir).normalized(), 
			deg_to_rad(_fly_lean.length()) * weight)
	var spread: = float(_dangle_cfg.get("spread_deg", 4.0))
	for side: String in ["L", "R"]:
		var legs: Dictionary = _dangle[side]
		var outward: = -1.0 if side == "L" else 1.0
		var pitch: = deg_to_rad((legs["pitch"] as Vector2).x) * weight
		var roll: = deg_to_rad((legs["roll"] as Vector2).x - outward * spread) * weight
		var knee: = deg_to_rad((legs["knee"] as Vector2).x) * weight

		animator.turn_bones(pose, {"thigh." + side: 1.0}, Vector3.RIGHT, - pitch)
		animator.turn_bones(pose, {"thigh." + side: 1.0}, Vector3.BACK, - roll)
		animator.turn_bones(pose, {"shin." + side: 1.0}, Vector3.RIGHT, - knee)
		animator.turn_bones(pose, {"foot." + side: 1.0}, Vector3.RIGHT, - deg_to_rad((legs["foot"] as Vector2).x) * weight)
		animator.turn_bones(pose, {"toe." + side: 1.0}, Vector3.RIGHT, - deg_to_rad((legs["toe"] as Vector2).x) * weight)


func _reset_dangle() -> void :
	_fly_lean = Vector2.ZERO
	for side: String in ["L", "R"]:
		_dangle[side] = {"pitch": Vector2.ZERO, "roll": Vector2.ZERO, "knee": Vector2.ZERO, "foot": Vector2.ZERO, "toe": Vector2.ZERO}



func land_drop() -> float:
	return - _land.x


func _lf(key: String) -> float:
	return float(_lean_cfg.get(key, 0.0))
