class_name RobotLegIK
extends RefCounted












const SIDES: = ["L", "R"]

const EPS: = 0.001

var rig: RobotRig
var _cfg: Dictionary

var _ankle_h: float = 0.2
var _off: = {"L": 0.0, "R": 0.0}
var _normal: = {"L": Vector3.UP, "R": Vector3.UP}
var _pelvis: float = 0.0
var _lock: = {}


func _init(robot_rig: RobotRig) -> void :
	rig = robot_rig
	_cfg = Lexicon.bal("robot.ik", {})
	_ankle_h = rig.globals(rig.rest)[rig.bone("foot.L")].origin.y
	reset()



func reset() -> void :
	for side: String in SIDES:
		_lock[side] = {"on": false, "world": Vector3.ZERO, "release": 0.0, "out": Vector3.ZERO}
		_off[side] = 0.0
		_normal[side] = Vector3.UP
	_pelvis = 0.0





func solve(pose: RobotRig.Pose, to_world: Transform3D, stance: Dictionary, planted: Dictionary, weight: float, 
		probe: Callable, dt: float, shift: Dictionary = {}, extra_drop: float = 0.0) -> void :
	var to_model: = to_world.affine_inverse()
	var g: = rig.globals(pose)
	var targets: = {}
	var drop: = 0.0
	for side: String in SIDES:
		var ankle: Vector3 = g[rig.bone("foot." + side)].origin
		var world_ankle: = to_world * ankle
		var hit: Dictionary = probe.call(world_ankle)
		var dy: = 0.0
		var n: = Vector3.UP
		if not hit.is_empty():
			n = _limited(to_model.basis * Vector3(hit["normal"]))
			dy = (to_model * Vector3(hit.get("point", Vector3(world_ankle.x, float(hit["y"]), world_ankle.z)))).y

			dy = clampf(dy + _ankle_h * (1.0 / maxf(n.y, 0.5) - 1.0), - _f("max_drop_m"), _f("max_raise_m"))
		_off[side] = RobotSpring.damp(_off[side], dy * weight, _f("foot_halflife_s"), dt)
		var lay: = weight * clampf(float(planted.get(side, 0.0)), 0.0, 1.0)
		_normal[side] = RobotSpring.damp_v3(_normal[side], Vector3.UP.lerp(n, lay), _f("foot_align_halflife_s"), dt).normalized()
		var target: = ankle + Vector3(0.0, _off[side], 0.0) + Vector3(shift.get(side, Vector3.ZERO))
		target = _locked(side, target, float(stance.get(side, 0.0)) * weight, to_world, to_model, dt)
		targets[side] = target
		drop = maxf(drop, - _off[side])
	_pelvis = RobotSpring.damp(_pelvis, minf(drop, _f("max_pelvis_drop_m")), _f("pelvis_halflife_s"), dt)

	var lower: = _pelvis + extra_drop
	if absf(lower) > EPS:
		rig.lower_pelvis(pose, lower, g)
		g = rig.globals(pose)
	for side: String in SIDES:
		_two_bone(pose, g, side, targets[side], _normal[side])




func _locked(side: String, target: Vector3, stance: float, to_world: Transform3D, to_model: Transform3D, dt: float) -> Vector3:
	var lock: Dictionary = _lock[side]
	var out: = target
	if stance > 0.5 and not bool(lock["on"]):
		lock["on"] = true
		lock["release"] = 0.0
		lock["world"] = to_world * target
	elif stance < 0.2 and bool(lock["on"]):
		_release(lock)
	if bool(lock["on"]):
		var held: = to_model * Vector3(lock["world"])
		if Vector2(held.x - target.x, held.z - target.z).length() > _f("lock_max_m"):
			_release(lock)
		else:
			out = Vector3(lerpf(target.x, held.x, stance), target.y, lerpf(target.z, held.z, stance))
	if not bool(lock["on"]) and float(lock["release"]) > 0.0:
		var span: = _f("lock_release_s")
		lock["release"] = maxf(0.0, float(lock["release"]) - (dt / span if span > 0.0 else 1.0))
		var from: = to_model * Vector3(lock["world"])
		var k: = smoothstep(0.0, 1.0, float(lock["release"]))
		out = Vector3(lerpf(target.x, from.x, k), target.y, lerpf(target.z, from.z, k))
	lock["out"] = to_world * out
	return out



func _release(lock: Dictionary) -> void :
	lock["on"] = false
	lock["release"] = 1.0
	lock["world"] = lock["out"]



func _limited(n: Vector3) -> Vector3:
	if n.y <= 0.05:
		return Vector3.UP
	var pitch: = clampf(atan2(n.z, n.y), - deg_to_rad(_f("foot_align_max_pitch_deg")), deg_to_rad(_f("foot_align_max_pitch_deg")))
	var roll: = clampf(atan2(n.x, n.y), - deg_to_rad(_f("foot_align_max_roll_deg")), deg_to_rad(_f("foot_align_max_roll_deg")))
	return Vector3(tan(roll), 1.0, tan(pitch)).normalized()


func _two_bone(pose: RobotRig.Pose, g: Array[Transform3D], side: String, target: Vector3, normal: Vector3) -> void :
	var thigh: = rig.bone("thigh." + side)
	var shin: = rig.bone("shin." + side)
	var foot: = rig.bone("foot." + side)
	var hip: = g[thigh].origin
	var knee: = g[shin].origin
	var ankle: = g[foot].origin
	var tilt: = Quaternion(Vector3.UP, normal) if normal.dot(Vector3.UP) < 0.99999 else Quaternion.IDENTITY
	var foot_rot: = tilt * g[foot].basis.get_rotation_quaternion()
	if ankle.distance_to(target) < EPS:
		pose.rot[foot] = g[shin].basis.get_rotation_quaternion().inverse() * foot_rot
		return
	var a: = hip.distance_to(knee)
	var b: = knee.distance_to(ankle)
	var to_target: = target - hip
	var d: = clampf(to_target.length(), absf(a - b) + EPS, a + b - EPS)
	var n: = to_target.normalized()
	var bend: = (knee - hip) - n * (knee - hip).dot(n)
	if bend.length() < EPS:
		bend = Vector3.FORWARD - n * n.dot(Vector3.FORWARD)
	bend = bend.normalized()
	var cos_a: = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var new_knee: = hip + n * (a * cos_a) + bend * (a * sqrt(1.0 - cos_a * cos_a))
	var new_ankle: = hip + n * d
	var parent_rot: = g[rig.parent[thigh]].basis.get_rotation_quaternion()
	var turn_thigh: = Quaternion((knee - hip).normalized(), (new_knee - hip).normalized())
	var thigh_rot: = turn_thigh * g[thigh].basis.get_rotation_quaternion()
	pose.rot[thigh] = parent_rot.inverse() * thigh_rot
	var shin_rot: = thigh_rot * pose.rot[shin]
	var moved_ankle: = new_knee + turn_thigh * (ankle - knee)
	var turn_shin: = Quaternion((moved_ankle - new_knee).normalized(), (new_ankle - new_knee).normalized())
	shin_rot = turn_shin * shin_rot
	pose.rot[shin] = thigh_rot.inverse() * shin_rot

	pose.rot[foot] = shin_rot.inverse() * foot_rot


func _f(key: String) -> float:
	return float(_cfg.get(key, 0.0))
