class_name RobotAnimator
extends RefCounted

















const TORSO: = ["spine", "chest", "neck", "head"]
const ARMS: = ["upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R"]

var rig: RobotRig
var motion: RobotMotion

var phase: float = 0.0

var move_weight: float = 0.0

var stance: = {"L": 0.0, "R": 0.0}

var planted: = {"L": 1.0, "R": 1.0}

var ground_weight: float = 1.0

var body_yaw: float = 0.0

var foot_shift: = {"L": Vector3.ZERO, "R": Vector3.ZERO}


var pelvis_drop: float = 0.0

var _cfg: Dictionary
var _names: Dictionary

var _tiers: Array[Dictionary] = []

var _angles: Array[float] = []
var _clock: float = 0.0
var _idle_clock: float = 0.0
var _still_time: float = 0.0
var _fidget: String = ""
var _fidget_t: float = 0.0
var _next_fidget: float = 0.0
var _air: float = 0.0
var _air_time: float = 0.0
var _rise: float = 1.0
var _fly: float = 0.0
var _last_fall_speed: float = 0.0
var _was_airborne: bool = false
var _was_on_floor: bool = true
var _dir: float = 0.0
var _dir_prev: float = 0.0
var _dir_mix: float = 1.0
var _warp: float = 0.0
var _turn: Dictionary = {}
var _turn_w: float = 0.0
var _upper: String = ""
var _upper_prev: String = ""
var _upper_mix: float = 1.0
var _upper_w: float = 0.0
var _upper_bone_w: = PackedFloat32Array()
var _oneshots: Array[Dictionary] = []
var _seed: int = 0
var _crouch: float = 0.0
var _slide: float = 0.0
var _was_moving: bool = false

var _crouch_tier: Dictionary = {}
var _was_sliding: bool = false

var _gait_weights_cache: Dictionary = {}


func _init(robot_rig: RobotRig, names: Dictionary, seed_value: int) -> void :
	rig = robot_rig
	_names = names
	_cfg = Lexicon.bal("robot", {})
	_seed = seed_value
	motion = RobotMotion.new(rig)
	var by_gait: = {}
	var crouch_gait: = String(names.get("crouch_gait", "Crouch"))
	for clip: String in rig.meta:
		var m: Dictionary = rig.meta[clip]
		if not m.has("gait") or not rig.has_clip(clip):
			continue
		if String(m["gait"]) == crouch_gait:

			if _crouch_tier.is_empty():
				_crouch_tier = {"gait": crouch_gait, "speed": float(m["authoring_speed_mps"]), 
					"cycle": float(m["cycle_distance_m"]), "dirs": []}
			var cd: Array = m.get("direction_godot", [0, 0, -1])
			(_crouch_tier["dirs"] as Array).append({"angle": atan2(float(cd[0]), - float(cd[2])), "clip": clip})
			continue
		var tier: Dictionary = by_gait.get_or_add(String(m["gait"]), {"gait": m["gait"], "speed": float(m["authoring_speed_mps"]), 
			"cycle": float(m["cycle_distance_m"]), "dirs": []})
		var d: Array = m.get("direction_godot", [0, 0, -1])
		(tier["dirs"] as Array).append({"angle": atan2(float(d[0]), - float(d[2])), "clip": clip})
	for tier: Dictionary in by_gait.values():
		_tiers.append(tier)
	_tiers.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a["speed"]) < float(b["speed"]))
	for tier: Dictionary in _tiers:
		if (tier["dirs"] as Array).size() > _angles.size():
			_angles.clear()
			for entry: Dictionary in tier["dirs"]:
				_angles.append(float(entry["angle"]))
	_upper_bone_w.resize(rig.bone_count)
	for b in rig.bone_count:
		_upper_bone_w[b] = _f("torso_upper_weight") if TORSO.has(rig.skeleton.get_bone_name(b)) else 1.0
	_next_fidget = _fidget_wait(0)


func reset() -> void :
	body_yaw = 0.0
	_turn = {}
	_turn_w = 0.0
	_warp = 0.0
	ground_weight = 1.0
	motion.reset()



func set_upper(clip: String) -> void :
	if clip == _upper or ( not clip.is_empty() and not rig.has_clip(clip)):
		return
	_upper_prev = _upper
	_upper = clip
	_upper_mix = 0.0




func play_once(clip: String, speed: float = 1.0, force: bool = false) -> void :
	if not rig.has_clip(clip):
		return
	var kind: = "add" if rig.is_additive(clip) else "full" if rig.is_full_body(clip) else "upper"
	_oneshots = _oneshots.filter( func(o: Dictionary) -> bool: return o["kind"] != kind or kind == "add")
	_oneshots.append({"clip": clip, "t": 0.0, "kind": kind, "speed": speed, "force": force})



func has_crouch_clips() -> bool:
	return not _crouch_tier.is_empty() and rig.has_clip(String(_names.get("crouch_idle", "")))



func has_slide_clips() -> bool:
	return rig.has_clip(String(_names.get("slide_loop", "")))





func update(delta: float, input: Dictionary) -> RobotRig.Pose:
	_clock += delta
	var velocity: Vector3 = input.get("velocity", Vector3.ZERO)
	var speed: = Vector2(velocity.x, velocity.z).length()
	var on_floor: = bool(input.get("on_floor", true))
	var flying: = bool(input.get("flying", false))
	var vertical: = float(input.get("vertical_speed", 0.0))
	var blend: = _f("blend_s")


	_air_time = 0.0 if on_floor else _air_time + delta
	var in_air: = not on_floor and not flying and (_air_time > _f("air_delay_s") or vertical > 1.0)
	if _was_on_floor and not on_floor and vertical > 1.0 and not flying:
		play_once(String(_names.get("jump_start", "")))
	_was_on_floor = on_floor
	if not on_floor:
		_last_fall_speed = - vertical
	if in_air:
		_was_airborne = true
	elif on_floor and _was_airborne:
		_was_airborne = false
		var hard: = _last_fall_speed > _f("hard_landing_speed")
		var add: = String(_names.get("land_heavy_add" if hard else "land_add", ""))
		if move_weight > 0.5 and rig.has_clip(add):
			play_once(add)
		else:
			play_once(String(_names["land_hard"]) if hard else String(_names["land"]))
		motion.land(maxf(_last_fall_speed, 0.0), move_weight)
	_air = move_toward(_air, 1.0 if in_air else 0.0, delta / blend)
	_rise = move_toward(_rise, 1.0 if vertical > 0.5 else 0.0, delta / blend)
	_fly = move_toward(_fly, 1.0 if flying else 0.0, delta / blend)
	var ik: Dictionary = _cfg.get("ik", {})
	var ik_goal: = float(ik.get("air_weight", 0.0)) if in_air or flying else 1.0
	var ik_span: = float(ik.get("land_blend_in_s", 0.12)) if ik_goal > ground_weight else float(ik.get("air_fade_s", 0.05))
	ground_weight = move_toward(ground_weight, ik_goal, delta / maxf(ik_span, 0.001))


	_crouch = move_toward(_crouch, clampf(float(input.get("crouch", 0.0)), 0.0, 1.0), delta / blend)
	var sliding: = bool(input.get("sliding", false))
	_slide = move_toward(_slide, 1.0 if sliding else 0.0, delta / blend)


	if sliding != _was_sliding and has_slide_clips() and (sliding or not bool(input.get("crouched", false))):
		play_once(String(_names.get("slide_enter" if sliding else "slide_exit", "")), 1.0, true)
	_was_sliding = sliding


	var target_move: = smoothstep(_f("idle_speed"), _f("move_full_speed"), speed) * (1.0 - _slide) if on_floor else 0.0
	move_weight = move_toward(move_weight, target_move, delta / blend)
	var settle: Dictionary = _cfg.get("settle", {})
	if move_weight > float(settle.get("moving_min", 0.7)):
		_was_moving = true
	elif _was_moving and target_move <= 0.0 and move_weight < float(settle.get("stopped_max", 0.3)) and on_floor:
		_was_moving = false

		if not sliding and _crouch < 0.5:
			play_once(String(_names.get("settle", "")))
	var tiers: = _tier_weights(speed)
	_update_direction(velocity, speed, delta)

	var crouch_k: = _crouch if has_crouch_clips() else 0.0
	var slide_k: = _slide if has_slide_clips() else 0.0
	var stand_k: = (1.0 - crouch_k) * (1.0 - slide_k)
	crouch_k *= 1.0 - slide_k

	var loco: Array[Array] = []
	for i in _tiers.size():
		var source: = _source_tier(i, _dir)
		for pick: Array in [[_dir, _dir_mix], [_dir_prev, 1.0 - _dir_mix]]:
			var w: = float(tiers[i]) * float(pick[1]) * stand_k
			if w > 0.0:
				loco.append([_clip_for(_source_tier(i, float(pick[0])), float(pick[0])), w, float(source["cycle"])])
	if crouch_k > 0.0:
		for pick: Array in [[_dir, _dir_mix], [_dir_prev, 1.0 - _dir_mix]]:
			var w: = crouch_k * float(pick[1])
			if w > 0.0:
				loco.append([_clip_for(_crouch_tier, float(pick[0])), w, float(_crouch_tier["cycle"])])
	var cycle: = 0.0
	var duty: = 0.0
	var flat: = 0.0
	var heel_off: = 0.0
	var total: = 0.0
	for entry: Array in loco:
		var w: = float(entry[1])
		var contact: = _contact_of(String(entry[0]))
		cycle += w * float(entry[2])
		duty += w * contact.x
		flat += w * contact.y
		heel_off += w * contact.z
		total += w
	if total > 0.0:
		cycle /= total
		duty /= total
		flat /= total
		heel_off /= total
	if speed > _f("idle_speed") and cycle > 0.0:
		var walk: Dictionary = _tiers[0]
		var min_rate: = _f("min_cadence_mult") * float(walk["speed"]) / float(walk["cycle"])
		phase = fposmod(phase + maxf(speed / cycle, min_rate) * delta, 1.0)
	var ground: = (1.0 - _air) * (1.0 - _fly)
	for side: String in ["L", "R"]:
		var p: = fposmod(phase - (0.0 if side == "L" else 0.5), 1.0)
		var edge: = maxf(duty * 0.15, 0.001)

		var down: = smoothstep(0.0, edge, p) * (1.0 - smoothstep(duty - edge, duty, p)) if p <= duty else 0.0

		var lock_edge: = maxf((heel_off - flat) * 0.25, 0.001)
		var lock: = smoothstep(flat - lock_edge, flat, p) * (1.0 - smoothstep(heel_off - lock_edge, heel_off, p))\
		if p <= heel_off else 0.0
		stance[side] = lock * move_weight * ground
		planted[side] = lerpf(1.0, down, move_weight) * ground

	_update_turn(delta, float(input.get("yaw_delta", 0.0)), on_floor and not flying)
	_update_fidget(delta, on_floor)


	var acc: = RobotRig.Blend.new(rig.bone_count)
	var calm: = RobotRig.Blend.new(rig.bone_count)
	var idle_w: = ground * (1.0 - move_weight)
	var idle_clip: = String(_names["idle"]) if _fidget.is_empty() else _fidget
	var idle_t: = _idle_clock if _fidget.is_empty() else _fidget_t
	for into: RobotRig.Blend in [acc, calm]:
		rig.accumulate(idle_clip, idle_t, idle_w * stand_k, into)
		rig.accumulate(String(_names.get("crouch_idle", "")), _idle_clock, idle_w * crouch_k, into)
		rig.accumulate(String(_names.get("slide_loop", "")), _clock, ground * slide_k, into)
	for entry: Array in loco:
		var clip: = String(entry[0])
		var w: = ground * move_weight * float(entry[1])
		if w <= 0.0:
			continue
		rig.accumulate(clip, phase * rig.length(clip), w, acc)
		rig.accumulate_mean(clip, w, calm)
	var air_w: = _air * (1.0 - _fly)
	for into: RobotRig.Blend in [acc, calm]:
		rig.accumulate(String(_names["rise"]), _clock, air_w * _rise, into)
		rig.accumulate(String(_names["fall"]), _clock, air_w * (1.0 - _rise), into)
		rig.accumulate(String(_names["fly"]), _clock, _fly, into)
	var pose: = rig.rest.duplicate_pose()
	acc.resolve(pose)
	var gait: = pose.duplicate_pose()
	var gait_mean: = rig.rest.duplicate_pose()
	calm.resolve(gait_mean)


	if _turn_w > 0.0 and not _turn.is_empty():
		pose.blend(rig.sample(String(_turn["clip"]), float(_turn["t"]), pose), _turn_w)


	var upper_once: Dictionary = {}
	var adds: Array[Dictionary] = []
	for o: Dictionary in _oneshots:
		o["t"] = float(o["t"]) + delta * float(o["speed"])
		var clip: = String(o["clip"])
		var len_s: = rig.length(clip)
		var fade: = _f("oneshot_fade_s")
		var w: = minf(smoothstep(0.0, fade, float(o["t"])), 1.0 - smoothstep(len_s - fade, len_s, float(o["t"])))
		match String(o["kind"]):
			"full":


				var forced: = bool(o.get("force", false))
				var cut: = 0.0 if forced else move_weight * _f("land_moving_cut")
				pose.blend(rig.sample(clip, float(o["t"]), pose), w * (1.0 - cut) * (1.0 if forced else stand_k))
			"upper":
				upper_once = {"clip": clip, "t": o["t"], "w": w}
			"add":
				adds.append({"clip": clip, "t": o["t"], "w": w})
	_oneshots = _oneshots.filter( func(o: Dictionary) -> bool: return float(o["t"]) < rig.length(String(o["clip"])))


	_upper_mix = move_toward(_upper_mix, 1.0, delta / blend)
	_upper_w = move_toward(_upper_w, 0.0 if _upper.is_empty() else 1.0, delta / blend)
	if _upper_w > 0.0 or not _upper_prev.is_empty():
		var shown: = _upper if not _upper.is_empty() else _upper_prev
		var target: = rig.sample(shown, _clock, pose)
		if not _upper_prev.is_empty() and not _upper.is_empty() and _upper_mix < 1.0:
			var before: = rig.sample(_upper_prev, _clock, pose)
			before.blend(target, _upper_mix)
			target = before
		pose.blend(target, _upper_w, _upper_bone_w)
		if _upper_mix >= 1.0:
			_upper_prev = ""
		var sway: = _upper_w * move_weight * ground
		if sway > 0.0:
			rig.add_model_delta(pose, gait, gait_mean, _gait_weights(shown), sway)
	motion.update(delta, input.get("world_velocity", velocity), input.get("to_model", Basis.IDENTITY), 
		float(input.get("effort", 0.0)), on_floor)
	motion.apply_head(pose, move_weight * ground, delta)
	var lean_clips: = _apply_lean_clips(pose)
	var breath_clips: = _apply_breath_clips(pose)
	if not upper_once.is_empty():
		pose.blend(rig.sample(String(upper_once["clip"]), float(upper_once["t"]), pose), float(upper_once["w"]), _upper_bone_w)
	for a: Dictionary in adds:
		rig.add_delta(String(a["clip"]), float(a["t"]), float(a["w"]), pose)
	motion.apply_body(pose, self, not lean_clips, not breath_clips)
	_apply_low(pose)
	motion.update_dangle(delta, velocity + Vector3(0.0, vertical, 0.0), _fly)
	motion.apply_dangle(pose, self, _fly)


	var turn_cfg: Dictionary = _cfg.get("turn", {})
	var warp_cfg: Dictionary = _cfg.get("warp", {})

	var pivoting: = not _turn.is_empty() and bool(_turn.get("pivot", false))
	var leg_turn: = - _warp * move_weight * ground * ((1.0 - _turn_w) if pivoting else 1.0)
	if absf(leg_turn) > 0.0001:
		turn_bones(pose, {"pelvis": 1.0}, Vector3.UP, leg_turn)
	var turned: = body_yaw + leg_turn * float(warp_cfg.get("spine_counter", 1.0))
	if _turn_w > 0.0 and not _turn.is_empty():
		turned += rig.yaw_at(String(_turn["clip"]), float(_turn["t"])) * _turn_w
	var max_twist: = deg_to_rad(float(turn_cfg.get("max_twist_deg", 100.0)))
	turn_bones(pose, turn_cfg.get("twist_split", {"spine": 0.35, "chest": 0.35, "neck": 0.15, "head": 0.15}), Vector3.UP, 
		- clampf(turned, - max_twist, max_twist))
	return pose




func _gait_weights(clip: String) -> Dictionary:
	if _gait_weights_cache.has(clip):
		return _gait_weights_cache[clip]
	var out: = {}
	var authored: Dictionary = (rig.meta.get(clip, {}) as Dictionary).get("gait_additive_weights", {})
	var torso: Dictionary = _cfg.get("torso", {})
	for b in rig.bone_count:
		var bone_name: = rig.skeleton.get_bone_name(b)
		if authored.has(bone_name):
			out[b] = float(authored[bone_name])
		elif authored.is_empty() and TORSO.has(bone_name):
			out[b] = float(torso.get("gait_add_weight", 0.7))
		elif authored.is_empty() and ARMS.has(bone_name):
			out[b] = float(torso.get("gait_add_arms", 0.15))
	_gait_weights_cache[clip] = out
	return out




func _apply_lean_clips(pose: RobotRig.Pose) -> bool:
	var leans: Dictionary = _names.get("leans", {})
	if not rig.has_clip(String(leans.get("F", ""))):
		return false
	var lean: = motion.lean_deg()
	var top: = maxf(float((rig.meta.get(String(leans["F"]), {}) as Dictionary).get("lean_max_deg", 14.0)), 0.1)
	var weights: = {"F": - lean.y, "B": lean.y, "R": lean.x, "L": - lean.x}
	for side: String in weights:
		var w: = clampf(float(weights[side]) / top, 0.0, 1.0)
		if w > 0.0:
			rig.add_delta(String(leans.get(side, "")), 0.0, w, pose)
	return true





func _apply_breath_clips(pose: RobotRig.Pose) -> bool:
	var breath: Dictionary = _names.get("breath", {})
	var calm: = String(breath.get("calm", ""))
	if not rig.has_clip(calm):
		return false
	var e: = motion.exertion()
	rig.add_delta(calm, _clock, (1.0 - e) * _upper_w, pose)
	rig.add_delta(String(breath.get("exerted", "")), _clock, e, pose)
	return true




func start_pivot(side: float) -> void :
	if not _turn.is_empty():
		return
	for clip: String in _names.get("pivots", []):
		if rig.has_clip(clip) and signf(rig.yaw_at(clip, rig.length(clip))) == signf(side):
			_turn = {"clip": clip, "t": 0.0, "pivot": true}
			_turn_w = 0.0
			return




func _apply_low(pose: RobotRig.Pose) -> void :
	var low: Dictionary = _cfg.get("low", {})

	var crouch: = 0.0 if has_crouch_clips() else _crouch * (1.0 - _slide)
	var slide: = 0.0 if has_slide_clips() else _slide
	pelvis_drop = motion.land_drop() + float(low.get("crouch_drop_m", 0.38)) * crouch + float(low.get("slide_drop_m", 0.55)) * slide
	var lean: = float(low.get("crouch_lean_deg", 12.0)) * crouch - float(low.get("slide_lean_deg", 28.0)) * slide
	if absf(lean) > 0.01:
		turn_bones(pose, {"spine": 0.5, "chest": 0.5}, Vector3.LEFT, deg_to_rad(lean))
	var front: Array = low.get("slide_front_foot_m", [0.0, 0.05, -0.45])
	var back: Array = low.get("slide_back_foot_m", [0.0, 0.0, 0.15])
	foot_shift["L"] = Vector3(float(front[0]), float(front[1]), float(front[2])) * slide
	foot_shift["R"] = Vector3(float(back[0]), float(back[1]), float(back[2])) * slide




func apply_pitch(pose: RobotRig.Pose, pitch: float, split: Dictionary, axis: Vector3 = Vector3.RIGHT) -> void :
	turn_bones(pose, split, axis, pitch)



func apply_roll(pose: RobotRig.Pose, bone_name: String, angle: float) -> void :
	turn_bones(pose, {bone_name: 1.0}, Vector3.FORWARD, angle)



func turn_bones(pose: RobotRig.Pose, split: Dictionary, axis: Vector3, angle: float) -> void :
	if is_zero_approx(angle):
		return
	var g: = rig.globals(pose)
	for bone_name: String in split:
		var b: = rig.bone(bone_name)
		if b < 0:
			continue
		var parent_rot: = g[rig.parent[b]].basis.get_rotation_quaternion() if rig.parent[b] >= 0 else Quaternion.IDENTITY
		var turn: = parent_rot.inverse() * Quaternion(axis, angle * float(split[bone_name])) * parent_rot
		pose.rot[b] = turn * pose.rot[b]



func _update_direction(velocity: Vector3, speed: float, delta: float) -> void :
	var dir_cfg: Dictionary = _cfg.get("dir", {})
	var warp_cfg: Dictionary = _cfg.get("warp", {})
	_dir_mix = move_toward(_dir_mix, 1.0, delta / maxf(float(dir_cfg.get("crossfade_s", 0.2)), 0.001))
	if speed < _f("idle_speed") or _angles.is_empty():
		_warp = RobotSpring.damp_angle(_warp, 0.0, float(warp_cfg.get("halflife_s", 0.08)), delta)
		return
	var moving: = atan2(velocity.x, - velocity.z)
	var best: = _dir
	var best_cost: = _dir_cost(moving, _dir) - deg_to_rad(float(dir_cfg.get("hysteresis_deg", 15.0)))
	for a: float in _angles:
		var cost: = _dir_cost(moving, a)
		if cost < best_cost:
			best = a
			best_cost = cost

	if absf(wrapf(moving - _dir, - PI, PI)) > deg_to_rad(float(dir_cfg.get("force_nearest_deg", 180.0))):
		var nearest: = INF
		for a: float in _angles:
			var gap: = absf(wrapf(moving - a, - PI, PI))
			if gap < nearest:
				nearest = gap
				best = a
	if not is_equal_approx(best, _dir):
		_dir_prev = lerp_angle(_dir_prev, _dir, _dir_mix)
		_dir = best
		_dir_mix = 0.0
	var shown: = lerp_angle(_dir_prev, _dir, _dir_mix)
	var limit: = deg_to_rad(float(warp_cfg.get("max_deg", 60.0)))
	_warp = RobotSpring.damp_angle(_warp, clampf(wrapf(moving - shown, - PI, PI), - limit, limit), 
		float(warp_cfg.get("halflife_s", 0.08)), delta)




func _dir_cost(moving: float, a: float) -> float:
	var bias: = deg_to_rad(float((_cfg.get("dir", {}) as Dictionary).get("forward_bias_deg", 15.0)))
	return absf(wrapf(moving - a, - PI, PI)) - (bias if absf(cos(a)) > 0.9 else 0.0)




func _source_tier(i: int, angle: float) -> Dictionary:
	for k in range(i, -1, -1):
		for entry: Dictionary in _tiers[k]["dirs"]:
			if absf(wrapf(float(entry["angle"]) - angle, - PI, PI)) < 0.02:
				return _tiers[k]
	return _tiers[i]



func _contact_of(clip: String) -> Vector3:
	var m: Dictionary = rig.meta.get(clip, {})
	var duty: = float(m.get("duty_factor", 0.3))
	var c: Dictionary = (m.get("contacts", {}) as Dictionary).get("L", {})
	return Vector3(duty, float(c.get("flat", 0.0)), float(c.get("heel_off", duty)))


func _clip_for(tier: Dictionary, angle: float) -> String:
	var best: = ""
	var best_d: = INF
	for entry: Dictionary in tier["dirs"]:
		var d: = absf(wrapf(float(entry["angle"]) - angle, - PI, PI))
		if d < best_d:
			best_d = d
			best = String(entry["clip"])
	return best




func _update_turn(delta: float, yaw_delta: float, grounded: bool) -> void :
	var cfg: Dictionary = _cfg.get("turn", {})
	var standing: = grounded and move_weight < float(cfg.get("max_move_weight", 0.2))
	var pivoting: = not _turn.is_empty() and bool(_turn.get("pivot", false))
	if standing or pivoting:

		body_yaw = wrapf(body_yaw - yaw_delta, - PI, PI)
	else:
		body_yaw = RobotSpring.damp_angle(body_yaw, 0.0, float(cfg.get("settle_halflife_s", 0.1)), delta)
	if not pivoting:
		var max_twist: = deg_to_rad(float(cfg.get("max_twist_deg", 100.0)))
		body_yaw = clampf(body_yaw, - max_twist, max_twist)
	if not _turn.is_empty():
		_turn["t"] = float(_turn["t"]) + delta
		var clip: = String(_turn["clip"])
		if (pivoting and not grounded) or ( not pivoting and not standing):
			_turn_w = move_toward(_turn_w, 0.0, delta / _f("blend_s"))
			if _turn_w <= 0.0:
				_turn = {}
		elif float(_turn["t"]) >= rig.length(clip):

			body_yaw = wrapf(body_yaw + rig.yaw_at(clip, rig.length(clip)), - PI, PI)
			_turn = {}
			_turn_w = 0.0
		else:
			_turn_w = move_toward(_turn_w, 1.0, delta / _f("oneshot_fade_s"))
		return
	if standing and absf(body_yaw) > deg_to_rad(float(cfg.get("start_deg", 70.0))):
		var best: = ""
		var best_d: = INF
		for clip: String in _names.get("crouch_turns" if _crouch > 0.5 and has_crouch_clips() else "turns", []):
			if not rig.has_clip(clip):
				continue
			var total: = rig.yaw_at(clip, rig.length(clip))
			if signf(total) != - signf(body_yaw):
				continue
			var d: = absf(absf(total) - absf(body_yaw))
			if d < best_d:
				best_d = d
				best = clip
		if not best.is_empty():
			_turn = {"clip": best, "t": 0.0}
			_turn_w = 0.0


func _update_fidget(delta: float, on_floor: bool) -> void :

	_still_time = _still_time + delta if move_weight < 0.05 and on_floor and _turn.is_empty() else 0.0
	if _fidget.is_empty() and _still_time > _next_fidget:
		var options: Array = _names.get("fidgets", [])
		if not options.is_empty():
			_fidget = String(options[_hash(int(_clock)) % options.size()])
			_fidget_t = 0.0
			_next_fidget = _still_time + rig.length(_fidget) + _fidget_wait(int(_clock) + 1)
	if not _fidget.is_empty():
		_fidget_t += delta
		if _fidget_t >= rig.length(_fidget) or move_weight > 0.05 or not _turn.is_empty():
			_fidget = ""
	_idle_clock += delta


func _tier_weights(speed: float) -> Array[float]:
	var out: Array[float] = []
	out.resize(_tiers.size())
	out.fill(0.0)
	if _tiers.is_empty():
		return out
	if speed <= float(_tiers[0]["speed"]):
		out[0] = 1.0
		return out
	for i in range(1, _tiers.size()):
		var lo: = float(_tiers[i - 1]["speed"])
		var hi: = float(_tiers[i]["speed"])
		if speed <= hi:
			var k: = (speed - lo) / maxf(hi - lo, 0.001)
			out[i - 1] = 1.0 - k
			out[i] = k
			return out
	out[_tiers.size() - 1] = 1.0
	return out


func _fidget_wait(index: int) -> float:
	var span: Array = _cfg.get("fidget_after_s", [6.0, 11.0])
	return lerpf(float(span[0]), float(span[1]), float(_hash(index) % 1000) / 1000.0)



func _hash(index: int) -> int:
	var x: = (index * 374761393 + _seed * 668265263) & 2147483647
	x = ((x ^ (x >> 13)) * 1274126177) & 2147483647
	return x


func _f(key: String) -> float:
	return float(_cfg.get(key, 0.0))
