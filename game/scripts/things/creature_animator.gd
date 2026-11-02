class_name CreatureAnimator
extends Node

const LEG_SUFFIXES: Array[String] = ["fl", "fr", "hl", "hr"]
const BIPED_SUFFIXES: Array[String] = ["l", "r"]

class GaitLeg extends RefCounted:
	var hip: Node3D
	var knee: Node3D
	var hip_pos: Vector3
	var knee_pos: Vector3
	var foot: Vector3
	var phase: = 0.0
	var front: = true
	var upper_len: = 0.0
	var lower_len: = 0.0
	var upper_rest: = 0.0
	var lower_rest: = 0.0

class CrawlLeg extends RefCounted:
	var hip: Node3D
	var knee: Node3D
	var hip_pos: Vector3
	var knee_pos: Vector3
	var foot: Vector3
	var phase: = 0.0
	var upper_len: = 0.0
	var lower_len: = 0.0
	var upper_rest: = Vector3.ZERO
	var lower_rest: = Vector3.ZERO

var thing: Thing
var rig: Dictionary = {}
var kind: = ""
var bones: Dictionary = {}
var pivots: Dictionary = {}
var rest_positions: Dictionary = {}
var gait_legs: Array[GaitLeg] = []
var biped_legs: Array[GaitLeg] = []
var tail_bones: Array[Node3D] = []
var spine_bones: Array[Node3D] = []
var crawl_legs: Array[CrawlLeg] = []
var biped_hips: Array[Node3D] = []
var biped_knees: Array[Node3D] = []
var arms: Array[Node3D] = []
var wings: Array[Node3D] = []
var fins: Array[Node3D] = []
var settings: Dictionary = {}
var active: = false
var distance: = 0.0
var last_position: = Vector3.ZERO
var last_yaw: = 0.0
var speed_smooth: = 0.0
var turn_smooth: = 0.0
var impact: = 0.0
var attack: = 0.0
var age: = 0.0
var dying: = false
var death_time: = 0.0


func setup(owner_thing: Thing, built: Dictionary) -> void :
	thing = owner_thing
	rig = built.get("rig", {})
	kind = String(rig.get("type", ""))
	bones = built.get("bones", {})
	settings = Lexicon.bal("creature_anim", {})
	var joints: Dictionary = rig.get("joints", {})
	for name: String in joints:
		pivots[name] = ModelBuilder._vec((joints[name] as Dictionary).get("pivot", [0, 0, 0]))
		if bones.has(name):
			rest_positions[name] = (bones[name] as Node3D).position
		if name.begins_with("spine_") and bones.has(name):
			spine_bones.append(bones[name])
	for name: String in joints:
		if name.begins_with("hip_") and name.count("_") == 2 and bones.has(name):
			var knee_name: = name.replace("hip_", "knee_")
			if not bones.has(knee_name):
				continue
			var leg: = CrawlLeg.new()
			leg.hip = bones[name]
			leg.knee = bones[knee_name]
			leg.hip_pos = pivots[name]
			leg.knee_pos = pivots[knee_name]
			leg.foot = ModelBuilder._vec((joints[name] as Dictionary).get("foot", [0, 0, 0]))
			leg.phase = float((joints[name] as Dictionary).get("phase", 0.0))
			leg.upper_rest = leg.knee_pos - leg.hip_pos
			leg.lower_rest = leg.foot - leg.knee_pos
			leg.upper_len = maxf(leg.upper_rest.length(), 0.001)
			leg.lower_len = maxf(leg.lower_rest.length(), 0.001)
			crawl_legs.append(leg)
	for i in 3:
		var tail: Node3D = bones.get("tail_" + str(i + 1))
		if tail != null:
			tail_bones.append(tail)
	for suffix: String in BIPED_SUFFIXES:
		biped_hips.append(bones.get("hip_" + suffix))
		biped_knees.append(bones.get("knee_" + suffix))
		arms.append(bones.get("arm_" + suffix))
		wings.append(bones.get("wing_" + suffix))
		fins.append(bones.get("fin_" + suffix))
	for suffix: String in LEG_SUFFIXES:
		var hip_name: = "hip_" + suffix
		var knee_name: = "knee_" + suffix
		var leg: = _cache_leg(hip_name, knee_name, suffix.begins_with("f"), joints)
		if leg != null:
			gait_legs.append(leg)
	if kind == "biped":
		for suffix: String in BIPED_SUFFIXES:
			var leg: = _cache_leg("hip_" + suffix, "knee_" + suffix, true, joints)
			if leg != null:
				biped_legs.append(leg)
	set_process(false)


func _cache_leg(hip_name: String, knee_name: String, front: bool, joints: Dictionary) -> GaitLeg:
	if not bones.has(hip_name) or not bones.has(knee_name):
		return null
	var leg: = GaitLeg.new()
	leg.hip = bones[hip_name]
	leg.knee = bones[knee_name]
	leg.hip_pos = pivots[hip_name]
	leg.knee_pos = pivots[knee_name]
	leg.foot = ModelBuilder._vec((joints[knee_name] as Dictionary).get("foot", [0, 0, 0]))
	leg.phase = float((joints[hip_name] as Dictionary).get("phase", 0.0))
	leg.front = front
	var upper: = Vector2(leg.knee_pos.y - leg.hip_pos.y, leg.knee_pos.z - leg.hip_pos.z)
	var lower: = Vector2(leg.foot.y - leg.knee_pos.y, leg.foot.z - leg.knee_pos.z)
	leg.upper_len = maxf(upper.length(), 0.001)
	leg.lower_len = maxf(lower.length(), 0.001)
	leg.upper_rest = atan2( - upper.y, - upper.x)
	leg.lower_rest = atan2( - lower.y, - lower.x)
	return leg


func activate() -> void :
	if rig.is_empty():
		return
	active = true
	last_position = thing.global_position
	last_yaw = thing.global_rotation.y
	set_process(true)


func on_hit() -> void :
	impact = 1.0


func on_attack() -> void :
	attack = 1.0


func on_death() -> void :
	active = false
	dying = true
	death_time = 0.0
	set_process(thing != null)



func preview_step(travel_m: float, visual_speed: float, delta: float, striking: bool = false) -> void :
	if dying:
		_death_pose(delta)
		return
	if striking:
		on_attack()
	distance += maxf(travel_m, 0.0)
	_pose(delta, visual_speed, 0.0)


func _process(delta: float) -> void :
	if dying:
		_death_pose(delta)
		return
	if not active or thing == null or thing.is_building:
		return
	if thing.is_captured or Status.paralyzed(thing):
		last_position = thing.global_position
		last_yaw = thing.global_rotation.y
		return
	var now: = thing.global_position
	var flight: = kind == "flier" or kind == "swimmer"
	var traveled: = now.distance_to(last_position) if flight else Vector2(now.x - last_position.x, now.z - last_position.z).length()
	last_position = now
	var yaw: = thing.global_rotation.y
	var turn: = wrapf(yaw - last_yaw, - PI, PI) / maxf(delta, 0.0001)
	last_yaw = yaw
	if traveled < float(settings.get("teleport_limit_m", 3.0)):
		distance += traveled
	else:
		traveled = 0.0
	_pose(delta, traveled / maxf(delta, 0.0001), turn)


func _pose(delta: float, actual_speed: float, turn: float) -> void :
	var alpha: = 1.0 - exp(-0.69314718 * delta / maxf(float(settings.get("half_life_s", 0.09)), 0.001))
	var moving: = clampf(actual_speed / maxf(float(settings.get("full_gait_speed_mps", 1.5)), 0.01), 0.0, 1.0)
	speed_smooth = lerpf(speed_smooth, moving, alpha)
	turn_smooth = lerpf(turn_smooth, clampf(turn, -3.0, 3.0), alpha)
	impact = lerpf(impact, 0.0, 1.0 - exp(-0.69314718 * delta / maxf(float(settings.get("impact_half_life_s", 0.22)), 0.001)))
	attack = lerpf(attack, 0.0, 1.0 - exp(-0.69314718 * delta / maxf(float(settings.get("attack_half_life_s", 0.15)), 0.001)))
	age += delta
	var body: Node3D = bones.get("body")
	if body != null:
		var crouch: = float(rig.get("height_m", 1.0)) * float(settings.get("locomotion_crouch_height_mult", 0.07)) * speed_smooth if kind == "quadruped" or kind == "jumper" or kind == "biped" else 0.0
		body.position.y = lerpf(body.position.y, _pivot("body").y - crouch - impact * float(settings.get("impact_squash_m", 0.04)), alpha)
	var gait_alpha: = 1.0 - exp(-0.69314718 * delta / maxf(float(settings.get("gait_half_life_s", 0.018)), 0.001))
	match kind:
		"quadruped":
			_quadruped(gait_alpha)
		"jumper":
			_quadruped(gait_alpha)
		"biped":
			_biped(alpha, gait_alpha)
		"flier":
			_flier(alpha, gait_alpha)
		"swimmer":
			_swimmer(alpha)
		"serpentine":
			_serpentine(alpha)
		"arthropod":
			_arthropod(alpha, gait_alpha)
		_:
			_generic(alpha)
	if body != null:
		body.rotation.z = lerpf(body.rotation.z, - turn_smooth * float(settings.get("turn_lean_rad", 0.07)), alpha)
	var head: Node3D = bones.get("head")
	if head != null:
		var look_yaw: = turn_smooth * float(settings.get("head_lead_rad", 0.12))
		var look_pitch: = 0.0
		if thing != null and thing.move != null and is_instance_valid(thing.move.visual_target):
			var toward: = thing.global_transform.basis.inverse() * (Combat.center_of(thing.move.visual_target) - thing.center())
			look_yaw += atan2( - toward.x, - toward.z)
			look_pitch = atan2(toward.y, Vector2(toward.x, toward.z).length())
		head.rotation.y = lerp_angle(head.rotation.y, clampf(look_yaw, -0.55, 0.55), alpha)
		head.rotation.x = lerp_angle(head.rotation.x, clampf(look_pitch, -0.28, 0.28), alpha)
	var neck: Node3D = bones.get("neck")
	if neck != null:
		neck.rotation.x = lerpf(neck.rotation.x, - attack * float(settings.get("attack_nod_rad", 0.25)), alpha)
	var jaw: Node3D = bones.get("jaw")
	if jaw != null:
		jaw.rotation.x = lerpf(jaw.rotation.x, attack * float(settings.get("jaw_open_rad", 0.3)), alpha)
	if kind != "biped":
		for arm in arms:
			if arm != null:
				arm.rotation.x = lerpf(arm.rotation.x, attack * float(settings.get("attack_arm_rad", 0.55)), alpha)


func _death_pose(delta: float) -> void :
	death_time += delta
	var alpha: = 1.0 - exp(-0.69314718 * delta / maxf(float(settings.get("death_half_life_s", 0.1)), 0.001))
	var detach: = clampf(death_time / maxf(float(settings.get("death_hold_s", 0.4)), 0.01), 0.0, 1.0)
	var reach: = float(rig.get("height_m", 1.0)) * float(settings.get("death_detach_height_mult", 0.12)) * detach
	var body: Node3D = bones.get("body")
	if body != null:
		body.rotation.z = lerpf(body.rotation.z, float(settings.get("death_fall_rad", 1.1)), alpha)
		body.position.y = lerpf(body.position.y, _pivot("body").y - float(rig.get("height_m", 1.0)) * float(settings.get("death_drop_height_mult", 0.25)), alpha)
	for name: String in bones:
		var bone: Node3D = bones[name]
		if name.begins_with("hip_") or name.begins_with("wing_") or name.begins_with("arm_"):
			var side: = -1.0 if name.ends_with("l") or name.contains("_l_") else 1.0
			bone.rotation.x = lerpf(bone.rotation.x, float(settings.get("death_spread_rad", 0.65)) * side, alpha)
			bone.position = bone.position.lerp((rest_positions[name] as Vector3) + Vector3(side * reach, - reach * 0.4, 0.0), alpha)
		elif name == "head":
			bone.position = bone.position.lerp((rest_positions[name] as Vector3) + Vector3(0.0, reach * 0.5, - reach), alpha)
		elif name.begins_with("tail_"):
			bone.position = bone.position.lerp((rest_positions[name] as Vector3) + Vector3(0.0, reach * 0.25, reach * 0.6), alpha)


func _quadruped(alpha: float) -> void :
	_solve_legs(gait_legs, alpha)
	_tail(alpha)


func _solve_legs(legs: Array[GaitLeg], alpha: float) -> void :
	var body: Node3D = bones.get("body")
	var body_drop: = body.position.y - _pivot("body").y if body != null else 0.0
	for leg in legs:
		var leg_height: = maxf(leg.hip_pos.y - leg.foot.y, 0.03)
		var stride: = leg_height * float(settings.get("stride_leg_mult", 0.7))
		if kind == "jumper":
			stride = maxf(stride, float(rig.get("height_m", 0.1)) * float(settings.get("jumper_stride_height_mult", 1.2)))
		var phase: = fposmod(distance / maxf(stride, 0.02) + leg.phase, 1.0)
		var stance: = float(settings.get("jumper_stance_fraction", 0.33)) if kind == "jumper" else float(settings.get("stance_fraction", 0.62))
		var stance_span: = stride * stance
		var target_z: = leg.foot.z
		var lift: = 0.0
		if phase < stance:
			target_z += lerpf( - stance_span * 0.5, stance_span * 0.5, phase / stance)
		else:
			var swing: = (phase - stance) / (1.0 - stance)
			target_z += lerpf(stance_span * 0.5, - stance_span * 0.5, swing)
			lift = sin(swing * PI) * leg_height * float(settings.get("foot_lift_mult", 0.17))
		var goal: = Vector2(leg.foot.y + lift - leg.hip_pos.y - body_drop, target_z - leg.hip_pos.z)
		var reach: = clampf(goal.length(), absf(leg.upper_len - leg.lower_len) + 0.001, leg.upper_len + leg.lower_len - 0.001)
		var facing: = atan2( - goal.y, - goal.x)
		var elbow: = acos(clampf((leg.upper_len * leg.upper_len + reach * reach - leg.lower_len * leg.lower_len) / (2.0 * leg.upper_len * reach), -1.0, 1.0))
		var side: = 1.0 if leg.front else -1.0
		var upper_angle: = facing + elbow * side
		var knee_goal: = Vector2( - cos(upper_angle), - sin(upper_angle)) * leg.upper_len
		var lower_goal: = goal - knee_goal
		var lower_angle: = atan2( - lower_goal.y, - lower_goal.x)
		var activity: = clampf(speed_smooth / maxf(float(settings.get("gait_activity_threshold", 0.15)), 0.01), 0.0, 1.0)
		var hip_target: = wrapf(upper_angle - leg.upper_rest, - PI, PI) * activity
		var knee_target: = wrapf((lower_angle - upper_angle) - (leg.lower_rest - leg.upper_rest), - PI, PI) * activity
		leg.hip.rotation.x = lerp_angle(leg.hip.rotation.x, hip_target, alpha)
		leg.knee.rotation.x = lerp_angle(leg.knee.rotation.x, knee_target, alpha)


func _generic(alpha: float) -> void :
	if bool(rig.get("lab_adapted", false)):
		var body: Node3D = bones.get("body")
		if body != null:
			body.position.y = lerpf(body.position.y, _pivot("body").y + sin(age * 3.0) * float(rig.get("height_m", 1.0)) * .025, alpha)
	_tail(alpha)


func _biped(alpha: float, gait_alpha: float) -> void :
	_solve_legs(biped_legs, gait_alpha)
	var stride: = maxf(float(rig.get("height_m", 1.0)) * float(settings.get("biped_stride_height_mult", 0.42)), 0.025)
	for i in 2:
		var phase: = fposmod(distance / stride + float(i) * 0.5, 1.0)
		var swing: = sin(phase * TAU) * speed_smooth
		var arm: = arms[i]
		if arm != null:
			arm.rotation.x = lerp_angle(arm.rotation.x, swing * float(settings.get("arm_swing_rad", 0.2)) + attack * float(settings.get("attack_arm_rad", 0.55)), alpha)
	_tail(alpha)


func _flier(alpha: float, gait_alpha: float) -> void :
	var flap: = sin(distance * float(settings.get("flap_per_m", 8.0)) + age * float(settings.get("hover_flap_hz", 2.0)) * TAU)
	for i in 2:
		var bone: = wings[i]
		if bone != null:
			var side: = -1.0 if i == 0 else 1.0
			bone.rotation.z = lerpf(bone.rotation.z, side * flap * float(settings.get("wing_flap_rad", 0.42)), alpha)
		var hip: = biped_hips[i]
		if hip != null:
			hip.rotation.x = lerpf(hip.rotation.x, sin(distance * float(settings.get("biped_step_per_m", 5.0)) + float(i) * PI) * speed_smooth * float(settings.get("bird_leg_rad", 0.12)), alpha)
	if not crawl_legs.is_empty():
		_arthropod(alpha, gait_alpha)
	_generic(alpha) if bool(rig.get("lab_adapted", false)) else _tail(alpha)


func _swimmer(alpha: float) -> void :
	var wave: = distance * float(settings.get("swim_wave_per_m", 6.0))
	for i in tail_bones.size():
		var bone: = tail_bones[i]
		bone.rotation.y = lerpf(bone.rotation.y, sin(wave - float(i) * 0.7) * float(settings.get("swim_tail_rad", 0.16)), alpha)
	for i in 2:
		var fin: = fins[i]
		if fin != null:
			fin.rotation.x = lerpf(fin.rotation.x, sin(wave * 0.5 + float(i) * PI) * float(settings.get("swim_fin_rad", 0.12)), alpha)


func _serpentine(alpha: float) -> void :
	var phase: = distance * float(settings.get("snake_wave_per_m", 9.0))
	for i in spine_bones.size():
		var bone: = spine_bones[i]
		bone.rotation.y = lerpf(bone.rotation.y, sin(phase - float(i) * 0.42) * speed_smooth * float(settings.get("snake_joint_rad", 0.09)), alpha)


func _arthropod(alpha: float, gait_alpha: float) -> void :
	for leg in crawl_legs:
		var span: = Vector2(leg.foot.x - leg.hip_pos.x, leg.foot.z - leg.hip_pos.z).length()
		var stride: = maxf(float(rig.get("height_m", 0.1)) * float(settings.get("arthropod_stride_height_mult", 0.7)), span * float(settings.get("arthropod_stride_reach_mult", 0.4)))
		var phase: = fposmod(distance / maxf(stride, 0.01) + leg.phase, 1.0)
		var stance: = float(settings.get("stance_fraction", 0.62))
		var target_z: = leg.foot.z
		var lift: = 0.0
		if phase < stance:
			target_z += lerpf( - stride * stance * 0.5, stride * stance * 0.5, phase / stance)
		else:
			var swing: = (phase - stance) / (1.0 - stance)
			target_z += lerpf(stride * stance * 0.5, - stride * stance * 0.5, swing)
			lift = sin(swing * PI)
		var target: = Vector3(leg.foot.x, leg.foot.y + lift * float(rig.get("height_m", 0.1)) * float(settings.get("foot_lift_mult", 0.17)), target_z)
		var goal: = target - leg.hip_pos
		var reach: = clampf(goal.length(), absf(leg.upper_len - leg.lower_len) + 0.001, leg.upper_len + leg.lower_len - 0.001)
		var direction: = goal.normalized()
		var along: = (leg.upper_len * leg.upper_len - leg.lower_len * leg.lower_len + reach * reach) / (2.0 * reach)
		var across: = sqrt(maxf(leg.upper_len * leg.upper_len - along * along, 0.0))
		var bend: = leg.upper_rest - direction * leg.upper_rest.dot(direction)
		if bend.length_squared() < 1e-06:
			bend = Vector3.UP.cross(direction)
		var knee_target: = leg.hip_pos + direction * along + bend.normalized() * across
		var upper_target: = (knee_target - leg.hip_pos).normalized()
		var lower_target: = (target - knee_target).normalized()
		var hip_target: = Quaternion(leg.upper_rest.normalized(), upper_target)
		var knee_rotation: = Quaternion(leg.lower_rest.normalized(), hip_target.inverse() * lower_target)
		var activity: = clampf(speed_smooth / maxf(float(settings.get("gait_activity_threshold", 0.15)), 0.01), 0.0, 1.0)
		leg.hip.quaternion = leg.hip.quaternion.slerp(Quaternion.IDENTITY.slerp(hip_target, activity), gait_alpha)
		leg.knee.quaternion = leg.knee.quaternion.slerp(Quaternion.IDENTITY.slerp(knee_rotation, activity), gait_alpha)
	_tail(alpha)


func _tail(alpha: float) -> void :
	for i in tail_bones.size():
		var bone: = tail_bones[i]
		bone.rotation.y = lerpf(bone.rotation.y, sin(distance * float(settings.get("tail_wag_per_m", 4.0)) - float(i) * 0.55) * speed_smooth * float(settings.get("tail_wag_rad", 0.12)), alpha)


func _pivot(name: String) -> Vector3:
	return pivots.get(name, Vector3.ZERO)
