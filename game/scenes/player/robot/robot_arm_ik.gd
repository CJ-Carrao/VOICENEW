class_name RobotArmIK
extends RefCounted







var rig: RobotRig
var _weight: = {"L": 0.0, "R": 0.0}
var _last: = {"L": Transform3D.IDENTITY, "R": Transform3D.IDENTITY}

var _reference: = {}
var _clock: float = 0.0


func _init(robot_rig: RobotRig) -> void :
	rig = robot_rig




func reach(pose: RobotRig.Pose, side: String, target: Variant, dt: float) -> void :
	_clock += dt * 0.5
	var blend: = maxf(Lexicon.balf("robot.arm_ik.blend_s"), 0.001)
	_weight[side] = move_toward(float(_weight[side]), 0.0 if target == null else 1.0, dt / blend)
	if target != null:
		_last[side] = target
	if float(_weight[side]) > 0.0:
		_arm(pose, side, _last[side], float(_weight[side]))



func weapon_target(item: Thing, to_model: Transform3D, clip: String) -> Variant:
	var main: Variant = item.grip_local("main") if item != null and is_instance_valid(item) else null
	if main == null:
		return null
	return weapon_target_data(Vector3(main), item.global_transform, to_model, clip)



func weapon_target_data(main: Vector3, weapon_world: Transform3D, to_model: Transform3D, clip: String) -> Transform3D:
	var weapon: = to_model * weapon_world
	return Transform3D(Basis(weapon.basis.get_rotation_quaternion() * Quaternion(_reference_of(clip)["R"])), weapon * main)



func held_target(side: String, at: Vector3, basis_world: Basis, to_model: Transform3D, clip: String) -> Transform3D:
	var rot: = (to_model.basis * basis_world).get_rotation_quaternion()
	return Transform3D(Basis(rot * Quaternion(_reference_of(clip)[side])), to_model * at)



func pull_target(pose: RobotRig.Pose, at: Vector3, to_model: Transform3D, clip: String) -> Transform3D:
	var shoulder: = rig.globals(pose)[rig.bone("upper_arm.R")].origin
	var point: = to_model * at
	var dir: = (point - shoulder).normalized() if point.distance_to(shoulder) > 0.01 else Vector3.FORWARD
	var cfg: Dictionary = Lexicon.bal("robot.arm_ik", {})
	var shake: = float(cfg.get("pull_shake_m", 0.008))
	var hz: = float(cfg.get("pull_shake_hz", 18.0))
	var tremble: = Vector3(sin(_clock * TAU * hz), sin(_clock * TAU * hz * 1.3 + 1.0), sin(_clock * TAU * hz * 0.7 + 2.0)) * shake
	var palm: = shoulder + dir * _reach("R") * float(cfg.get("pull_reach", 0.85)) + tremble
	var basis: = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK)
	return Transform3D(Basis(basis.get_rotation_quaternion() * Quaternion(_reference_of(clip)["R"])), palm)


func _arm(pose: RobotRig.Pose, side: String, target: Transform3D, w: float) -> void :
	var upper: = rig.bone("upper_arm." + side)
	var fore: = rig.bone("forearm." + side)
	var hand: = rig.bone("hand." + side)
	var socket: = rig.bone("socket_hand." + side)
	var g: = rig.globals(pose)
	var shoulder: = g[upper].origin
	var elbow: = g[fore].origin
	var wrist: = g[hand].origin
	var target_rot: = target.basis.get_rotation_quaternion()
	var wrist_target: = target.origin - target_rot * rig.rest.pos[socket]
	var a: = shoulder.distance_to(elbow)
	var b: = elbow.distance_to(wrist)
	var to_target: = wrist_target - shoulder
	var d: = clampf(to_target.length(), absf(a - b) + 0.001, a + b - 0.001)
	var n: = to_target.normalized()

	var outward: = Vector3(0.3 if side == "R" else -0.3, -1.0, 0.2)
	var bend: = (elbow - shoulder) - n * (elbow - shoulder).dot(n)
	if bend.length() < 0.001:
		bend = outward - n * n.dot(outward)
	bend = bend.normalized()
	var cos_a: = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var new_elbow: = shoulder + n * (a * cos_a) + bend * (a * sqrt(1.0 - cos_a * cos_a))
	var new_wrist: = shoulder + n * d
	var parent_rot: = g[rig.parent[upper]].basis.get_rotation_quaternion()
	var turn_upper: = Quaternion((elbow - shoulder).normalized(), (new_elbow - shoulder).normalized())
	var upper_rot: = turn_upper * g[upper].basis.get_rotation_quaternion()
	var fore_rot: = upper_rot * pose.rot[fore]
	var moved_wrist: = new_elbow + turn_upper * (wrist - elbow)
	fore_rot = Quaternion((moved_wrist - new_elbow).normalized(), (new_wrist - new_elbow).normalized()) * fore_rot
	pose.rot[upper] = pose.rot[upper].slerp(parent_rot.inverse() * upper_rot, w)
	pose.rot[fore] = pose.rot[fore].slerp(upper_rot.inverse() * fore_rot, w)
	pose.rot[hand] = pose.rot[hand].slerp(fore_rot.inverse() * target_rot, w)



func _reach(side: String) -> float:
	var g: = rig.globals(rig.rest)
	return g[rig.bone("upper_arm." + side)].origin.distance_to(g[rig.bone("forearm." + side)].origin)\
	+ g[rig.bone("forearm." + side)].origin.distance_to(g[rig.bone("hand." + side)].origin)\
	+ g[rig.bone("hand." + side)].origin.distance_to(g[rig.bone("socket_hand." + side)].origin)



func _reference_of(clip: String) -> Dictionary:
	if _reference.has(clip):
		return _reference[clip]
	var g: = rig.globals(rig.sample(clip, 0.0, rig.rest) if rig.has_clip(clip) else rig.rest)
	var ref: = {"R": g[rig.bone("hand.R")].basis.get_rotation_quaternion(), "L": g[rig.bone("hand.L")].basis.get_rotation_quaternion()}
	_reference[clip] = ref
	return ref
