class_name RobotRig
extends RefCounted








class Pose:
	var pos: = PackedVector3Array()
	var rot: Array[Quaternion] = []

	func duplicate_pose() -> Pose:
		var out: = Pose.new()
		out.pos = pos.duplicate()
		out.rot = rot.duplicate()
		return out


	func blend(other: Pose, w: float, bone_w: PackedFloat32Array = PackedFloat32Array()) -> void :
		if w <= 0.0:
			return
		for b in pos.size():
			var k: = w * (bone_w[b] if not bone_w.is_empty() else 1.0)
			if k <= 0.0:
				continue
			pos[b] = pos[b].lerp(other.pos[b], minf(k, 1.0))
			rot[b] = rot[b].slerp(other.rot[b], minf(k, 1.0))



class Blend:
	var pos_sum: = PackedVector3Array()
	var pos_w: = PackedFloat32Array()
	var rot_sum: Array[Quaternion] = []
	var rot_w: = PackedFloat32Array()

	func _init(count: int) -> void :
		pos_sum.resize(count)
		pos_w.resize(count)
		rot_w.resize(count)
		rot_sum.resize(count)
		for b in count:
			rot_sum[b] = Quaternion(0, 0, 0, 0)

	func add_pos(bone: int, value: Vector3, w: float) -> void :
		pos_sum[bone] += value * w
		pos_w[bone] += w

	func add_rot(bone: int, value: Quaternion, w: float, reference: Quaternion) -> void :

		var q: = value if value.dot(reference) >= 0.0 else - value
		rot_sum[bone] = rot_sum[bone] + q * w
		rot_w[bone] += w


	func resolve(into: Pose) -> void :
		for b in pos_sum.size():
			if pos_w[b] > 0.0:
				into.pos[b] = pos_sum[b] / pos_w[b]
			if rot_w[b] > 0.0:
				into.rot[b] = rot_sum[b].normalized()


const ROT: = 0
const POS: = 1
const MEAN_SAMPLES: = 24
const YAW_SAMPLES: = 40

var skeleton: Skeleton3D

var meta: Dictionary = {}
var bone_count: int = 0

var order: = PackedInt32Array()
var parent: = PackedInt32Array()
var rest: Pose
var _anims: Dictionary = {}

var _tracks: Dictionary = {}
var _means: Dictionary = {}
var _yaws: Dictionary = {}


func _init(model: Node, clip_meta: Dictionary) -> void :
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player: = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.active = false
	meta = clip_meta
	bone_count = skeleton.get_bone_count()
	parent.resize(bone_count)
	rest = Pose.new()
	rest.pos.resize(bone_count)
	rest.rot.resize(bone_count)
	for b in bone_count:
		parent[b] = skeleton.get_bone_parent(b)
		var t: = skeleton.get_bone_rest(b)
		rest.pos[b] = t.origin
		rest.rot[b] = t.basis.get_rotation_quaternion()
	var queue: Array[int] = []
	for b in bone_count:
		if parent[b] < 0:
			queue.append(b)
	while not queue.is_empty():
		var b: int = queue.pop_front()
		order.append(b)
		for c in skeleton.get_bone_children(b):
			queue.append(c)
	for clip: String in player.get_animation_list():
		var anim: = player.get_animation(clip)
		var mask: Array = (meta.get(clip, {}) as Dictionary).get("mask", [])
		var tracks: Array = []
		for t in anim.get_track_count():
			var bone: = skeleton.find_bone(String(anim.track_get_path(t).get_concatenated_subnames()))
			if bone < 0 or ( not mask.is_empty() and not mask.has(skeleton.get_bone_name(bone))):
				continue
			match anim.track_get_type(t):
				Animation.TYPE_ROTATION_3D:
					tracks.append([bone, t, ROT])
				Animation.TYPE_POSITION_3D:
					tracks.append([bone, t, POS])
		_anims[clip] = anim
		_tracks[clip] = tracks


func bone(bone_name: String) -> int:
	return skeleton.find_bone(bone_name)


func has_clip(clip: String) -> bool:
	return _anims.has(clip)


func length(clip: String) -> float:
	return (_anims[clip] as Animation).length if _anims.has(clip) else 0.0


func is_loop(clip: String) -> bool:
	return bool((meta.get(clip, {}) as Dictionary).get("loop", false))


func is_additive(clip: String) -> bool:
	return bool((meta.get(clip, {}) as Dictionary).get("additive", false))



func is_full_body(clip: String) -> bool:
	return ((meta.get(clip, {}) as Dictionary).get("mask", []) as Array).has("thigh.L")



func clip_time(clip: String, t: float) -> float:
	var span: = length(clip)
	return fposmod(t, span) if is_loop(clip) else clampf(t, 0.0, span)



func accumulate(clip: String, t: float, w: float, into: Blend, bone_w: PackedFloat32Array = PackedFloat32Array()) -> void :
	if w <= 0.0 or not _anims.has(clip):
		return
	var anim: Animation = _anims[clip]
	var at: = clip_time(clip, t)
	for entry: Array in _tracks[clip]:
		var b: int = entry[0]
		var k: = w * (bone_w[b] if not bone_w.is_empty() else 1.0)
		if k <= 0.0:
			continue
		if entry[2] == ROT:
			into.add_rot(b, anim.rotation_track_interpolate(entry[1], at), k, rest.rot[b])
		else:
			into.add_pos(b, anim.position_track_interpolate(entry[1], at), k)



func sample(clip: String, t: float, base: Pose) -> Pose:
	var out: = base.duplicate_pose()
	var acc: = Blend.new(bone_count)
	accumulate(clip, t, 1.0, acc)
	acc.resolve(out)
	return out



func add_delta(clip: String, t: float, w: float, pose: Pose) -> void :
	if w <= 0.0 or not _anims.has(clip):
		return
	var anim: Animation = _anims[clip]
	var at: = clip_time(clip, t)
	for entry: Array in _tracks[clip]:
		if entry[2] != ROT:
			continue
		var b: int = entry[0]
		var delta: Quaternion = rest.rot[b].inverse() * anim.rotation_track_interpolate(entry[1], at)
		pose.rot[b] = pose.rot[b] * Quaternion.IDENTITY.slerp(delta, clampf(w, 0.0, 1.0))



func mean_rot(clip: String) -> Array[Quaternion]:
	if _means.has(clip):
		return _means[clip]
	var out: Array[Quaternion] = rest.rot.duplicate()
	if _anims.has(clip):
		var sums: Array[Quaternion] = []
		sums.resize(bone_count)
		sums.fill(Quaternion(0, 0, 0, 0))
		var anim: Animation = _anims[clip]
		for i in MEAN_SAMPLES:
			var at: = length(clip) * i / MEAN_SAMPLES
			for entry: Array in _tracks[clip]:
				if entry[2] != ROT:
					continue
				var q: Quaternion = anim.rotation_track_interpolate(entry[1], at)
				sums[entry[0]] = sums[entry[0]] + (q if q.dot(rest.rot[entry[0]]) >= 0.0 else - q)
		for b in bone_count:
			if sums[b].length_squared() > 0.0:
				out[b] = sums[b].normalized()
	_means[clip] = out
	return out



func accumulate_mean(clip: String, w: float, into: Blend) -> void :
	if w <= 0.0 or not _anims.has(clip):
		return
	var m: = mean_rot(clip)
	for entry: Array in _tracks[clip]:
		if entry[2] == ROT:
			into.add_rot(entry[0], m[entry[0]], w, rest.rot[entry[0]])




func yaw_at(clip: String, t: float) -> float:
	if not _yaws.has(clip):
		var curve: = PackedFloat32Array()
		var pelvis: = bone("pelvis")
		var turned: = 0.0
		var last: = 0.0
		for i in YAW_SAMPLES + 1:
			var f: = - globals(sample(clip, length(clip) * i / YAW_SAMPLES, rest))[pelvis].basis.z
			var yaw: = atan2( - f.x, - f.z)
			if i == 0:
				last = yaw
			turned += wrapf(yaw - last, - PI, PI)
			last = yaw
			curve.append(turned)
		_yaws[clip] = curve
	var c: PackedFloat32Array = _yaws[clip]
	var x: = clampf(t / maxf(length(clip), 0.0001), 0.0, 1.0) * YAW_SAMPLES
	var i: = mini(floori(x), YAW_SAMPLES - 1)
	return lerpf(c[i], c[i + 1], x - i)





func add_model_delta(pose: Pose, moving: Pose, still: Pose, weights: Dictionary, k: float) -> void :
	if k <= 0.0 or weights.is_empty():
		return
	var gm: = globals(moving)
	var gs: = globals(still)
	var gp: = globals(pose)

	var model: Array[Quaternion] = []
	model.resize(bone_count)
	for b in order:
		var p: = parent[b]
		var parent_rot: Quaternion = model[p] if p >= 0 else Quaternion.IDENTITY
		if not weights.has(b):
			model[b] = parent_rot * pose.rot[b]
			continue
		var d: = gm[b].basis.get_rotation_quaternion() * gs[b].basis.get_rotation_quaternion().inverse()
		var target: = Quaternion.IDENTITY.slerp(d, clampf(float(weights[b]) * k, 0.0, 1.0)) * gp[b].basis.get_rotation_quaternion()
		model[b] = target
		pose.rot[b] = (parent_rot.inverse() * target).normalized()



func lower_pelvis(pose: Pose, amount: float, g: Array[Transform3D]) -> void :
	var pelvis: = bone("pelvis")
	var parent_g: Transform3D = g[parent[pelvis]] if parent[pelvis] >= 0 else Transform3D.IDENTITY
	pose.pos[pelvis] = parent_g.affine_inverse() * (g[pelvis].origin - Vector3(0.0, amount, 0.0))



func globals(pose: Pose) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(bone_count)
	for b in order:
		var local: = Transform3D(Basis(pose.rot[b]), pose.pos[b])
		out[b] = local if parent[b] < 0 else out[parent[b]] * local
	return out



func apply(pose: Pose) -> void :
	for b in bone_count:
		skeleton.set_bone_pose_position(b, pose.pos[b])
		skeleton.set_bone_pose_rotation(b, pose.rot[b])
